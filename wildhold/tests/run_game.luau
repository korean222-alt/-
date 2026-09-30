-- 헤드리스 플레이 테스트: 실제 서버/클라이언트 스크립트를 모의 엔진에서 돌리며 한 판을 진행한다.
-- 실행: tests/run.sh  (Luau VM + tests/api.lua 필요)
local ROOT = ROOT_DIR
local API = loadsource(readfile(ROOT .. "/tests/api.lua"), "api")()

local builtinTypeof = typeof
typeof = function(v)
	local mt = type(v) == "table" and getmetatable(v)
	if mt and rawget(mt, "__type") then return mt.__type end
	return builtinTypeof(v)
end
local D = loadsource(readfile(ROOT .. "/tests/mock/datatypes.luau"), "datatypes")()
local R = loadsource(readfile(ROOT .. "/tests/mock/roblox.luau"), "roblox")(API, D)
local E = loadsource(readfile(ROOT .. "/tests/mock/env.luau"), "env")(R, D, API)
local task = R.task

local game = E.build()
local workspace = E.workspace
local Players = E.players
local function svc(name) return game:GetService(name) end

-- ===================================================================== 소스 트리 → DataModel
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then return f end
	f = E.Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function scriptInst(cls, parent, name, path)
	local s = E.Instance.new(cls)
	s.Name = name
	rawset(s, "_source", readfile(ROOT .. "/src/" .. path))
	s.Parent = parent
	return s
end
local RS = svc("ReplicatedStorage")
local shared = folder(RS, "Shared")
folder(RS, "PetModels")
-- 숲 키트: Studio 에서 EnvModels.fbx 를 가져온 것과 같은 구조 (Model 안에 에셋 이름의 MeshPart).
-- 일부러 작업 공간(workspace)에 둔다 → 코드가 ReplicatedStorage 로 옮기는지도 검사한다.
local ENV_SIZES = loadsource(readfile(ROOT .. "/assets/env/sizes.lua"), "sizes")()
do
	local env = E.Instance.new("Model")
	env.Name = "EnvModels"
	local names = {}
	for name in pairs(ENV_SIZES) do table.insert(names, name) end
	table.sort(names)
	local x = 0
	for _, name in ipairs(names) do
		local dims = ENV_SIZES[name]
		local mp = E.Instance.new("MeshPart")
		mp.Name = name
		mp.Size = D.Vector3.new(dims[1], dims[2], dims[3])
		mp.CFrame = D.CFrame.new(x, dims[2] / 2, 0)
		mp.Parent = env
		x = x + dims[1] + 2
	end
	env.Parent = workspace
end
local SSS = svc("ServerScriptService")
local SPS = svc("StarterPlayer").StarterPlayerScripts
for line in readfile(ROOT .. "/tests/.manifest"):gmatch("[^\n]+") do
	local parts = string.split(line, "/")
	local file = parts[#parts]
	if parts[1] == "shared" then
		local parent = shared
		for i = 2, #parts - 1 do parent = folder(parent, parts[i]) end
		scriptInst("ModuleScript", parent, file:gsub("%.lua$", ""), line)
	elseif parts[1] == "server" then
		if #parts == 2 then
			scriptInst("Script", SSS, file:gsub("%.server%.lua$", ""), line)
		else
			scriptInst("ModuleScript", folder(SSS, parts[2]), file:gsub("%.lua$", ""), line)
		end
	elseif parts[1] == "client" then
		if #parts == 2 then
			scriptInst("LocalScript", SPS, file:gsub("%.client%.lua$", ""), line)
		else
			scriptInst("ModuleScript", folder(SPS, parts[2]), file:gsub("%.lua$", ""), line)
		end
	end
end

-- ===================================================================== 스크립트 전역
local function makeGlobals()
	return setmetatable({
		game = game, workspace = workspace, Instance = E.Instance, Enum = R.Enum, task = task, typeof = R.typeof,
		Vector3 = D.Vector3, Vector2 = D.Vector2, CFrame = D.CFrame, Color3 = D.Color3, UDim = D.UDim, UDim2 = D.UDim2,
		NumberSequence = D.NumberSequence, NumberSequenceKeypoint = D.NumberSequenceKeypoint, ColorSequence = D.ColorSequence,
		ColorSequenceKeypoint = D.ColorSequenceKeypoint, NumberRange = D.NumberRange, TweenInfo = D.TweenInfo, RaycastParams = D.RaycastParams,
		OverlapParams = D.OverlapParams, Random = D.Random, Rect = D.Rect, PhysicalProperties = D.PhysicalProperties, Font = D.Font,
		tick = function() return R.Now end, time = function() return R.Now end, wait = task.wait, delay = task.delay, spawn = task.spawn,
		os = setmetatable({clock = function() return R.Now end, time = function() return 1700000000 + math.floor(R.Now) end}, {__index = os}),
		warn = function(...)
			local t = {}
			for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
			table.insert(R.Warnings, table.concat(t, " "))
		end,
		print = function(...)
			local t = {}
			for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
			table.insert(R.Log, table.concat(t, " "))
		end,
	}, {__index = _G})
end

local function requirer(globals)
	local cache, loading = {}, {}
	local function req(inst)
		assert(typeof(inst) == "Instance" and inst._class == "ModuleScript", "require 에 ModuleScript 가 아닌 값")
		if cache[inst] ~= nil then return cache[inst] end
		assert(not loading[inst], "순환 require: " .. inst:GetFullName())
		loading[inst] = true
		local fn = loadsource(rawget(inst, "_source"), inst:GetFullName())
		local env = setmetatable({script = inst, require = req}, {__index = globals})
		setfenv(fn, env)
		local result = fn()
		assert(result ~= nil, "모듈이 값을 돌려주지 않음: " .. inst:GetFullName())
		cache[inst] = result
		loading[inst] = nil
		return result
	end
	return req
end

local serverGlobals, clientGlobals = makeGlobals(), makeGlobals()
local serverRequire, clientRequire = requirer(serverGlobals), requirer(clientGlobals)

-- 테스트용 시간 단축 (서버 설정 모듈만)
local GameConfig = serverRequire(shared.Config.GameConfig)
GameConfig.StudioTimeScale = 4
GameConfig.FirstDaySeconds = 600 -- 첫 낮에 검사할 것이 많다 (시간 배율 4 → 150초)

local function run(scriptInstance, globals, req)
	local fn = loadsource(rawget(scriptInstance, "_source"), scriptInstance:GetFullName())
	setfenv(fn, setmetatable({script = scriptInstance, require = req}, {__index = globals}))
	return task.spawn(fn)
end

-- ===================================================================== 진행 도우미
local frame = 0
local function step(seconds, dt)
	dt = dt or 1 / 10
	local target = R.Now + seconds
	while R.Now < target - 1e-9 do
		frame = frame + 1
		R.runUntil(R.Now + dt)
		E.Stepped:Fire(R.Now, dt)
		E.Heartbeat:Fire(dt)
		E.RenderStepped:Fire(dt)
		if #R.Errors > 0 then return false end
	end
	return true
end

local function fail(msg)
	print("\n❌ 실패: " .. msg)
	for i, e in ipairs(R.Errors) do print(string.format("  [오류 %d] %s", i, e)) end
	for _, w in ipairs(R.Warnings) do print("  [warn] " .. w) end
	error("테스트 실패")
end
local checks = {}
local function check(name, ok, detail)
	table.insert(checks, {name, ok, detail})
	print((ok and "  ✅ " or "  ❌ ") .. name .. (detail and ("  · " .. tostring(detail)) or ""))
end

-- ===================================================================== 서버 시작
-- 블렌더 FBX 를 Studio 로 가져온 것과 같은 구조의 가짜 모델 (MeshPart + Bone 계층).
-- 일부러 작업 공간에 둔다 → 서버가 PetModels 로 옮기는지도 검사한다.
do
	local model = E.Instance.new("Model")
	model.Name = "Mossling"
	local mesh = E.Instance.new("MeshPart")
	mesh.Name = "Mossling"
	mesh.Size = D.Vector3.new(0.9, 1.29, 1.0)
	mesh.CFrame = D.CFrame.new(0, 0.645, 0) * D.CFrame.Angles(0, math.pi, 0)
	mesh.Parent = model
	local function bone(name, parent, pos)
		local b = E.Instance.new("Bone")
		b.Name = name
		b.Parent = parent
		b.WorldPosition = pos
		return b
	end
	local rootBone = bone("Root", mesh, D.Vector3.new(0, 0, -0.05))
	local body = bone("Body", rootBone, D.Vector3.new(0, 0.3, -0.2))
	local head = bone("Head", body, D.Vector3.new(0, 0.52, 0.05))
	bone("EarL", head, D.Vector3.new(-0.19, 0.86, 0))
	bone("EarR", head, D.Vector3.new(0.19, 0.86, 0))
	bone("Front", head, D.Vector3.new(0, 0.55, 0.4))
	for _, n in ipairs({"LegFL", "LegFR", "LegBL", "LegBR"}) do bone(n, body, D.Vector3.new(0, 0.25, 0)) end
	model.Parent = workspace
end
print("▶ 서버 시작")
run(SSS.ServerMain, serverGlobals, serverRequire)
if #R.Errors > 0 then fail("ServerMain 시작") end
check("펫 모델 작업 공간 → PetModels 로 옮김", RS.PetModels:FindFirstChild("Mossling") ~= nil and workspace:FindFirstChild("Mossling") == nil)
local root = workspace:FindFirstChild("WILDHOLD")
check("맵 생성", root ~= nil)
local partCount = 0
for _, d in ipairs(root:GetDescendants()) do if R.isA(d._class, "BasePart") then partCount = partCount + 1 end end
check("맵 파트 수", partCount > 800 and partCount < 20000, partCount) -- 지름 1500 맵 (클라이언트는 스트리밍으로 가까운 곳만)
check("지형 명령", #E.TerrainOps > 50, #E.TerrainOps)
do
	local used, kinds = 0, {}
	for _, d in ipairs(root:GetDescendants()) do
		local name = R.isA(d._class, "BasePart") and d:GetAttribute("EnvAsset")
		if name then
			used = used + 1
			kinds[name] = true
		end
	end
	local nkinds = 0
	for _ in pairs(kinds) do nkinds = nkinds + 1 end
	local missing = {}
	for name in pairs(ENV_SIZES) do
		if not kinds[name] then table.insert(missing, name) end
	end
	table.sort(missing)
	check("숲 키트 메쉬 사용", used > 300 and #missing == 0, used .. "개 · " .. nkinds .. "종" .. (#missing > 0 and (" · 안 쓰임: " .. table.concat(missing, ", ")) or ""))
	check("EnvModels → ReplicatedStorage 로 옮김", RS:FindFirstChild("EnvModels") ~= nil and workspace:FindFirstChild("EnvModels") == nil)
	-- 에셋이 없을 때는 파트로 만든 대체 모델
	local Props = serverRequire(shared.Visuals.Props)
	local env = RS.EnvModels
	env.Parent = nil
	local tmp = folder(workspace, "_FallbackTest")
	local pine = Props.tallPine(tmp, D.CFrame.new(0, 0, 0), D.Random.new(1), 1)
	local plain = 0
	for _, d in ipairs(pine:GetDescendants()) do
		if R.isA(d._class, "BasePart") and not d:GetAttribute("EnvAsset") then plain = plain + 1 end
	end
	check("에셋 없을 때 파트 대체 모델", plain >= 5 and not Props.hasEnv(), plain)
	tmp:Destroy()
	env.Parent = RS
end

-- ===================================================================== 플레이어 입장
local player = R.newInstance("Player")
player.Name = "Tester"
rawget(player, "_props").UserId = 1001
rawget(player, "_props").DisplayName = "테스터"
E.decorate(player)
rawset(player, "_custom", {Kick = function(_, msg) table.insert(R.Kicks, msg) end})
local playerGui = R.newInstance("PlayerGui", player)
playerGui.Name = "PlayerGui"
local backpack = R.newInstance("Backpack", player)
backpack.Name = "Backpack"
local playerScripts = R.newInstance("PlayerScripts")
playerScripts.Name = "PlayerScripts"
playerScripts.Parent = player
E.LocalPlayer = player
rawget(Players, "_props").LocalPlayer = player

local function makeCharacter()
	local char = E.Instance.new("Model")
	char.Name = "Tester"
	local hrp = E.Instance.new("Part", char)
	hrp.Name = "HumanoidRootPart"
	hrp.Size = D.Vector3.new(2, 2, 1)
	hrp.Anchored = true
	hrp.CFrame = D.CFrame.new(0, 3, 15)
	local human = E.Instance.new("Humanoid", char)
	char.PrimaryPart = hrp
	char.Parent = workspace
	return char, hrp, human
end
local char, hrp = makeCharacter()
player.Parent = Players
rawget(player, "_props").Character = char
Players.PlayerAdded:Fire(player)
step(1)
player.CharacterAdded:Fire(char)
-- 클라이언트 스크립트
for _, child in ipairs(SPS:GetChildren()) do
	local copy = child:Clone()
	local function copySource(src, dst)
		rawset(dst, "_source", rawget(src, "_source"))
		for i, c in ipairs(src:GetChildren()) do copySource(c, dst:GetChildren()[i]) end
	end
	copySource(child, copy)
	copy.Parent = playerScripts
end
local latest
RS.Remotes.State.OnClientEvent:Connect(function(data) latest = data end)
local notices = {}
RS.Remotes.Notice.OnClientEvent:Connect(function(msg) table.insert(notices, msg) end)
local fxCount = {}
RS.Remotes.FX.OnClientEvent:Connect(function(kind) fxCount[kind] = (fxCount[kind] or 0) + 1 end)
print("▶ 클라이언트 시작")
run(playerScripts.ClientMain, clientGlobals, clientRequire)
if not step(2) then fail("클라이언트 시작") end
for _, w in ipairs(R.Warnings) do
	if w:find("시작 실패") then fail("컨트롤러 시작 실패: " .. w) end
end
-- ===================================================================== 로비 → 혼자 바로 출발
local lobbyState
RS.Remotes.Lobby.OnClientEvent:Connect(function(kind, value) if kind == "State" then lobbyState = value end end)
if not step(1) then fail("로비 상태") end
local LCfg = serverRequire(shared.Config.LobbyConfig)
local lobbyOrigin = D.Vector3.new(table.unpack(LCfg.StudioOrigin))
check("로비에서 시작 (Studio: 로비+원정)", workspace:GetAttribute("ServerMode") == "Both" and player:GetAttribute("Place") == "Lobby"
	and (hrp.Position - lobbyOrigin).Magnitude < 90 and root:FindFirstChild("Lobby", true) ~= nil, player:GetAttribute("Place"))
check("로비 화면 · 상태", playerGui:FindFirstChild("Lobby") ~= nil and playerGui.Lobby.Enabled and lobbyState ~= nil and #lobbyState.Rooms == LCfg.Wagons
	and not playerGui.WildholdHUD.Enabled, lobbyState and (#lobbyState.Pets .. "마리 · 수레 " .. #lobbyState.Rooms))
local lobbyPets = 0
for _, a in ipairs(root.Pets:GetChildren()) do if string.sub(a.Name, 1, 6) == "Lobby_" then lobbyPets = lobbyPets + 1 end end
check("로비에서 출전 펫이 따라다님", lobbyPets == 1, lobbyPets)
RS.Remotes.LobbyAction:FireServer("Solo")
if not step(2.5) then fail("혼자 출발") end
check("혼자 바로 출발 → 원정", player:GetAttribute("Place") == "Expedition" and (hrp.Position - lobbyOrigin).Magnitude > 500 and playerGui.WildholdHUD.Enabled
	and not playerGui.Lobby.Enabled, player:GetAttribute("Place"))
if not step(0.6) then fail("원정 준비") end
check("HUD 생성", playerGui:FindFirstChild("WildholdHUD") ~= nil)
check("펫 패널 생성", playerGui:FindFirstChild("PetBook") ~= nil)
local held = char:FindFirstChildOfClass("Tool")
check("창 장착 (첫 칸 자동)", held ~= nil and held:GetAttribute("ItemId") == "OldSpear", held and held:GetAttribute("ItemId"))
local function toolOf(id)
	for _, container in ipairs({char, player:FindFirstChildOfClass("Backpack")}) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:GetAttribute("ItemId") == id then return t end
			end
		end
	end
	return nil
end
check("핫바 도구 (창·도끼·덫)", toolOf("OldAxe") ~= nil and toolOf("Trap") ~= nil and toolOf("Snack") ~= nil)
check("핫바 UI", playerGui:FindFirstChild("Hotbar") ~= nil)
-- 도구 쥐는 법: 팔을 앞으로 뻗은 손(기준 CFrame) 에서 도끼·곡괭이 머리가 손보다 위, 창끝은 앞
do
	local function extremes(id)
		local tool = toolOf(id) or serverRequire(shared.Visuals.ToolLook).make(id)
		local handle = tool:FindFirstChild("Handle")
		local placed = tool.Grip:Inverse() -- 손 = 원점, 앞 = -Z, 위 = +Y
		local top, front = -math.huge, math.huge
		for _, part in ipairs(tool:GetDescendants()) do
			if R.isA(part._class, "BasePart") then
				local p = placed * handle.CFrame:ToObjectSpace(part.CFrame).Position
				top, front = math.max(top, p.Y), math.min(front, p.Z)
			end
		end
		return top, front
	end
	local axeTop = extremes("OldAxe")
	local pickTop = extremes("StonePick")
	local _, spearFront = extremes("OldSpear")
	check("도구 쥐는 법 (도끼·곡괭이는 세워서, 창은 앞으로)", axeTop > 1.5 and pickTop > 1.5 and spearFront < -3,
		string.format("도끼 머리 %.1f · 곡괭이 머리 %.1f · 창끝 %.1f", axeTop, pickTop, spearFront))
end
-- 휘두르기 동작: 어깨 관절에 내려찍기를 덧입히고 끝나면 원래대로
do
	local Swing = clientRequire(playerScripts.Controllers.SwingController)
	local arm = E.Instance.new("Part", char)
	arm.Name = "RightUpperArm"
	local shoulder = E.Instance.new("Motor6D", arm)
	shoulder.Name = "RightShoulder"
	shoulder.Transform = D.CFrame.identity
	local played = Swing:Play(char, "Chop", true)
	if not step(0.15) then fail("휘두르기") end
	local mid = shoulder.Transform
	if not step(0.6) then fail("휘두르기 끝") end
	check("도끼 내려찍기 동작 (어깨 관절)", played and mid ~= D.CFrame.identity and shoulder.Transform == D.CFrame.identity)
	arm:Destroy()
end
-- 지도: 서버가 만든 격자, 처음엔 기지 둘레만 보인다
local MapC = clientRequire(playerScripts.Controllers.MapController)
local gridValue = RS:FindFirstChild("MapGrid")
local gridSize = gridValue and gridValue:GetAttribute("Size")
check("지도 격자", gridValue ~= nil and #gridValue.Value == gridSize * gridSize and gridValue.Value:find("T") ~= nil and gridValue.Value:find("W") ~= nil,
	gridSize and (gridSize .. "칸"))
local seenStart = MapC.SeenCount
check("미니맵 (처음엔 기지 둘레만)", playerGui:FindFirstChild("Minimap") ~= nil and seenStart > 0 and seenStart < 200 and #MapC.Cells:GetChildren() > 0,
	seenStart .. "칸")
check("기본 펫 소환", #root.Pets:GetChildren() == 1, #root.Pets:GetChildren())
local visuals = workspace:FindFirstChild("ClientVisuals")
check("펫 모델 표시(클라이언트)", visuals ~= nil and #visuals:GetChildren() >= 2, visuals and #visuals:GetChildren())
local meshRig = visuals and visuals:FindFirstChild("Mossling")
local meshPart = meshRig and meshRig:FindFirstChildOfClass("MeshPart")
check("블렌더 모델 경로 (MeshPart + 뼈)", meshPart ~= nil)
if not step(0.5) then fail("뼈 애니메이션") end
local head = meshPart and meshPart:FindFirstChild("Head", true)
check("뼈 애니메이션 적용", head ~= nil and head.Transform ~= D.CFrame.identity)
check("펫 키 맞춤 (2.9 stud)", math.abs(meshPart.Size.Y - 2.9) < 0.05, string.format("%.2f", meshPart.Size.Y))

-- ===================================================================== 낮 1: 사냥 → 포획
print("▶ 출발 대기 → 낮")
if not step(15.5) then fail("출발 대기") end
check("낮 시작", latest and latest.Phase == "Day", latest and latest.Phase)
check("목표 표시 (첫 판: 야생 모슬링)", latest.GoalAt ~= nil and latest.GoalName == "야생 모슬링", latest.GoalName)
local function teleport(x, z)
	hrp.CFrame = D.CFrame.new(x, 3, z)
end
local function nearestWild(species)
	local best, bd
	for _, a in ipairs(root.WildPets:GetChildren()) do
		if a:GetAttribute("SpeciesId") == species then
			local d = (a.Position - hrp.Position).Magnitude
			if not bd or d < bd then best, bd = a, d end
		end
	end
	return best
end
teleport(6, 48)
if not step(1) then fail("이동") end
local target = nearestWild("Mossling")
check("야생 모슬링 존재", target ~= nil)
local wildId = target:GetAttribute("WildId")
RS.Remotes.PetAction:FireServer("Focus", wildId)
for _ = 1, 60 do
	teleport(target.Position.X, target.Position.Z - 8)
	RS.Remotes.AttackRequest:FireServer()
	if not step(0.6) then fail("사냥") end
	if target:GetAttribute("Exhausted") then break end
end
check("약화 → 포획 가능", target:GetAttribute("Exhausted") == true, target:GetAttribute("HP"))
RS.Remotes.CaptureAction:FireServer(wildId, "Trap", false)
if not step(3.5) then fail("포획") end
check("포획 성공 (첫 모슬링 보장)", latest and #latest.Pets == 2, latest and #latest.Pets)
check("포획 FX", (fxCount.TrapStart or 0) >= 1 and (fxCount.TrapResult or 0) >= 1)
check("잡은 펫 즉시 출전", #root.Pets:GetChildren() == 2, #root.Pets:GetChildren())
-- 개체 차이: 재능 별 · 특성 · 빛나는 변종 · 이름 짓기
do
	local caught
	for _, pet in ipairs(latest.Pets) do if pet.Status == "미등록" then caught = pet end end
	check("잡은 펫의 재능 별·특성", caught ~= nil and caught.Stars >= 1 and caught.Stars <= 5 and caught.Trait ~= nil and caught.Power > 0,
		caught and string.format("★%d · %s · 전투력 %d", caught.Stars, tostring(caught.Trait), caught.Power))
	local withStars, shiny = 0, 0
	for _, a in ipairs(root.WildPets:GetChildren()) do
		if a:GetAttribute("Stars") and a:GetAttribute("Power") then withStars = withStars + 1 end
		if a:GetAttribute("Shiny") then shiny = shiny + 1 end
	end
	check("야생 펫마다 별·전투력", withStars == #root.WildPets:GetChildren(), withStars .. "마리 · 빛나는 " .. shiny)
	local PRt = serverRequire(shared.Modules.PetRules)
	local Pc = serverRequire(shared.Config.PetConfig)
	local low = PRt.stats({SpeciesId = "Mossling", Level = 5, Stars = 1}, Pc)
	local high = PRt.stats({SpeciesId = "Mossling", Level = 5, Stars = 5, Trait = "Brave"}, Pc)
	check("별 5개 + 용감함이 더 강함", high.Damage > low.Damage * 1.5 and high.HP > low.HP, string.format("공격 %.1f → %.1f", low.Damage, high.Damage))
	RS.Remotes.PetAction:FireServer("Rename", {Uid = caught.Uid, Name = "나쁜말 친구"})
	if not step(1) then fail("이름 짓기") end
	local renamed
	for _, pet in ipairs(latest.Pets) do if pet.Uid == caught.Uid then renamed = pet.Nickname end end
	check("이름 짓기 (필터 거침)", renamed == "### 친구", renamed)
end
-- 포획 전투력: 도구만으로는 HP 60% 아래로 못 깎고, 너무 강한 야생은 덫을 못 던진다
do
	local Cap = serverRequire(SSS.Services.CaptureService)
	local Pc = serverRequire(shared.Config.PetConfig)
	RS.Remotes.PetAction:FireServer("Stay")
	if not step(0.4) then fail("대기") end
	local lone
	for _, wild in pairs(Cap.Wild) do
		if not lone and wild.SpeciesId == "Mossling" and not wild.Owner and (wild.Part.Position - hrp.Position).Magnitude < 150 then lone = wild end
	end
	if lone then
		for _ = 1, 14 do
			teleport(lone.Part.Position.X, lone.Part.Position.Z - 6)
			RS.Remotes.AttackRequest:FireServer()
			if not step(0.6) then fail("도구 사냥") end
		end
	end
	check("도구만으로는 HP 60%까지", lone ~= nil and lone.HP / lone.MaxHP >= Pc.HuntFloor - 0.01 and lone.HP < lone.MaxHP,
		lone and string.format("%.0f%%", lone.HP / lone.MaxHP * 100))
	local alpha
	for _, wild in pairs(Cap.Wild) do if wild.SpeciesId == "Briarhorn" then alpha = wild end end
	check("알파는 너무 강함 (전투력 비교)", alpha ~= nil and Cap:TooStrong(player, alpha),
		alpha and string.format("우리 %d vs 알파 %d", Cap:TeamPower(player, alpha), alpha.Power))
	-- 멀리 떨어지면 화난 야생 펫이 제자리로 돌아간다
	teleport(0, 10)
	RS.Remotes.PetAction:FireServer("Follow")
	if not step(1) then fail("따라와") end
end

-- ===================================================================== 채집 → 창고 → 건설
print("▶ 채집 · 창고 · 건설")
local function harvest(kind, times)
	for _, model in ipairs(root.ResourceNodes:GetChildren()) do
		local hit = model:IsA("Model") and model.PrimaryPart
		if hit and hit:GetAttribute("ResourceType") == kind then
			for _ = 1, times do
				teleport(hit.Position.X, hit.Position.Z - 5)
				RS.Remotes.AttackRequest:FireServer()
				if not step(0.6) then fail("채집 " .. kind) end
				if hit:GetAttribute("CurrentHealth") == 0 then break end
			end
			-- 떨어진 자원 밟기
			for _ = 1, 6 do
				for _, drop in ipairs(root.Drops:GetChildren()) do
					teleport(drop.Position.X, drop.Position.Z)
					if not step(0.3) then fail("줍기") end
				end
			end
			return true
		end
	end
end
-- 나무는 도끼로 (창으로 치면 느리다)
char:FindFirstChildOfClass("Humanoid"):EquipTool(toolOf("OldAxe"))
if not step(0.3) then fail("도끼 들기") end
check("도끼 들기", char:FindFirstChildOfClass("Tool") and char:FindFirstChildOfClass("Tool"):GetAttribute("ItemId") == "OldAxe")
for _, kind in ipairs({"Wood", "Wood", "Wood", "Stone", "Fiber", "Berry"}) do harvest(kind, 12) end
local bagTotal = 0
for _, v in pairs(latest.Bag) do bagTotal = bagTotal + v end
check("가방에 자원", bagTotal > 0, bagTotal)
-- 숲의 나무·고사목도 벨 수 있다 (예전에는 장식이라 도끼가 안 먹혔다)
do
	local woodNodes, withTrunk, deadHit = 0, 0, nil
	for _, model in ipairs(root.ResourceNodes:GetChildren()) do
		local hit = model:IsA("Model") and model.PrimaryPart
		if hit and hit:GetAttribute("ResourceType") == "Wood" then
			woodNodes = woodNodes + 1
			local trunk = model:FindFirstChild("Trunk")
			if trunk and trunk.CanCollide and not hit.CanCollide then withTrunk = withTrunk + 1 end
			for _, d in ipairs(model:GetChildren()) do
				if not deadHit and tostring(d:GetAttribute("EnvAsset") or ""):find("DeadTree") then deadHit = hit end
			end
		end
	end
	check("맵의 모든 나무가 채집 노드 (줄기에 부딪힘)", woodNodes > 500 and withTrunk == woodNodes, woodNodes .. "그루 · 줄기 " .. withTrunk)
	local before = deadHit and deadHit:GetAttribute("CurrentHealth")
	if deadHit then
		teleport(deadHit.Position.X, deadHit.Position.Z - 4)
		RS.Remotes.AttackRequest:FireServer()
		if not step(0.7) then fail("고사목 베기") end
	end
	check("고사목 도끼로 베기", deadHit ~= nil and deadHit:GetAttribute("CurrentHealth") < before, before and (before .. " → " .. deadHit:GetAttribute("CurrentHealth")))
end
-- 경계: 맵 밖으로 나가면 안으로 되돌린다 + 보이지 않는 벽
do
	local M = serverRequire(shared.Config.MapConfig)
	local walls = root.Map:FindFirstChild("Boundary")
	check("경계 벽", walls ~= nil and #walls:GetChildren() > 100, walls and #walls:GetChildren())
	teleport(M.WallRadius + 60, 0)
	if not step(0.5) then fail("경계 밖") end
	local r = math.sqrt(hrp.Position.X ^ 2 + hrp.Position.Z ^ 2)
	check("맵 밖 → 안으로 되돌림", r < M.WallRadius, string.format("%.0f", r))
	-- 지도는 지나간 곳만 밝혀진다
	check("지도: 가 본 곳이 넓어짐", MapC.SeenCount > seenStart and MapC:IsSeen(M.WallRadius - 30, 0) and not MapC:IsSeen(-(M.WallRadius - 30), 0),
		seenStart .. " → " .. MapC.SeenCount .. "칸")
	-- 지도 미리보기용 (tests/render_map.py)
	local seen = {}
	for i = 1, gridSize * gridSize do seen[i] = MapC.Seen[i] and "1" or "0" end
	writefile(ROOT .. "/tests/.map_grid.txt", gridValue.Value .. "\n" .. table.concat(seen))
	MapC:Toggle(true)
	check("큰 지도 열기", playerGui.WorldMap.Enabled and MapC.Canvas.Parent == MapC.BigWindow)
	MapC:Toggle(false)
end
teleport(21 * 0.7, -12 * 0.7)
if not step(1.5) then fail("입금") end
local bank = latest.Bank
check("공용 창고 입금", (bank.Wood or 0) > 0, "나무 " .. tostring(bank.Wood) .. " / 돌 " .. tostring(bank.Stone))
local lane2Dir = D.Vector3.new(math.sin(math.rad(120)), 0, -math.cos(math.rad(120)))
-- ===================================================================== 설치형 건축: 제작대 → 벽
local Def = serverRequire(SSS.Services.DefenseService)
local function structureCount(kind)
	local n = 0
	for _, slot in pairs(Def.Slots) do if not kind or slot.Kind == kind then n = n + 1 end end
	return n
end
check("시작 구조물 (길목 문·벽·포탑) · 제작대 없음", structureCount() == 4 and Def:BenchLevel() == 0, structureCount() .. "개")
-- ① 제작대 설치 도구: 어디서나 (가방 + 기지 안에서는 공용 창고)
RS.Remotes.CraftAction:FireServer("WorkbenchKit")
if not step(0.6) then fail("제작대 도구") end
check("제작대 설치 도구 (손 제작, 나무 8)", toolOf("WorkbenchKit") ~= nil, notices[#notices])
char:FindFirstChildOfClass("Humanoid"):EquipTool(toolOf("WorkbenchKit"))
teleport(-21, -2)
if not step(0.5) then fail("제작대 자리") end
-- ② 들고 설치 (기지 영역 밖은 안 됨)
RS.Remotes.BuildRequest:FireServer("WorkbenchKit", D.CFrame.new(300, 0, 5))
if not step(0.6) then fail("영역 밖 설치") end
check("기지 영역 밖에는 설치 불가", Def:BenchLevel() == 0 and string.find(notices[#notices] or "", "기지 영역 밖") ~= nil, notices[#notices])
RS.Remotes.BuildRequest:FireServer("WorkbenchKit", D.CFrame.new(-21, 0, -12))
if not step(1) then fail("제작대 설치") end
check("제작대 설치 → 제작대 Lv1", Def:BenchLevel() == 1 and latest.Bench == 1 and toolOf("WorkbenchKit") == nil, notices[#notices])
local ghost = workspace:FindFirstChild("BuildGhost")
check("설치 미리보기 (들고 있을 때만)", ghost ~= nil and #ghost:GetChildren() == 0)
-- ③ 제작대 근처에서 벽 설치 도구 → 길목 2 바깥에 설치
teleport(-21, -5)
if not step(0.4) then fail("제작대 근처") end
RS.Remotes.CraftAction:FireServer("WallKit")
if not step(0.6) then fail("벽 도구") end
check("벽 설치 도구 (제작대 근처)", toolOf("WallKit") ~= nil, notices[#notices])
char:FindFirstChildOfClass("Humanoid"):EquipTool(toolOf("WallKit"))
local wallAt = lane2Dir * 62
teleport(wallAt.X - lane2Dir.X * 10, wallAt.Z - lane2Dir.Z * 10)
if not step(0.5) then fail("벽 자리") end
check("벽 미리보기 모델", ghost and #ghost:GetChildren() == 1)
RS.Remotes.BuildRequest:FireServer("WallKit", D.CFrame.lookAt(wallAt, wallAt + lane2Dir))
if not step(1) then fail("벽 설치") end
local wallSlot
for _, slot in pairs(Def.Slots) do
	if slot.Kind == "Wall" and (slot.CFrame.Position - wallAt).Magnitude < 2 then wallSlot = slot end
end
check("벽 건설", wallSlot ~= nil and wallSlot.Level == 1, notices[#notices])
-- 벽 Lv2 는 제작대 Lv2 가 있어야 한다
local buildPrompt = wallSlot.Pad:FindFirstChildOfClass("Attachment"):FindFirstChildOfClass("ProximityPrompt")
buildPrompt.Triggered:Fire(player)
if not step(1) then fail("강화 시도") end
check("강화는 제작대 레벨 필요", wallSlot.Level == 1 and string.find(notices[#notices] or "", "제작대 Lv2") ~= nil, notices[#notices])
-- 괴물이 오는 길을 막은 벽을 알아본다
local blocker = Def:Barrier(lane2Dir * 80, lane2Dir * 40, 1.5, 30)
check("괴물 길을 막은 벽 찾기", blocker == wallSlot, blocker and blocker.Kind)
-- 제작: 횃불 → 핫바에 새 칸 (제작대 근처)
teleport(-21, -5)
if not step(0.5) then fail("제작대 이동") end
RS.Remotes.CraftAction:FireServer("Torch")
if not step(1.2) then fail("제작") end
check("횃불 제작 → 핫바", toolOf("Torch") ~= nil, notices[#notices])
-- 배고픔: 시간이 지나면 줄고, 열매를 먹으면 오른다
check("배고픔 감소", latest.Hunger < 100, latest.Hunger)
local berryTool = toolOf("Berry")
if berryTool then
	local before = latest.Hunger
	char:FindFirstChildOfClass("Humanoid"):EquipTool(berryTool)
	if not step(0.3) then fail("열매 들기") end
	RS.Remotes.AttackRequest:FireServer()
	if not step(1) then fail("먹기") end
	check("열매 먹기", latest.Hunger > before, string.format("%.1f → %.1f", before, latest.Hunger))
else
	check("열매 먹기", false, "가방에 열매 없음")
end
char:FindFirstChildOfClass("Humanoid"):EquipTool(toolOf("OldSpear"))
if not step(0.3) then fail("창 들기") end

local function exportScene()
	-- 맵 미리보기용 장면 내보내기
	local out = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		-- 숲 키트 메쉬는 이름·위치·크기만 내보내고 렌더러가 실제 블렌더 에셋으로 바꿔 넣는다.
		-- 그 밖의 MeshPart 는 테스트가 넣은 가짜 블렌더 펫(회색 상자)이라 뺀다
		local asset = d._class == "MeshPart" and d:GetAttribute("EnvAsset")
		if asset then
			local c = d._props.CFrame
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
			local s = d._props.Size
			table.insert(out, string.format("Asset %s %.3f %.3f %.3f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.3f %.3f %.3f 0 0 0 0",
				asset, x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22, s.X, s.Y, s.Z))
		elseif d._class == "PointLight" and d.Parent and R.isA(d.Parent._class, "BasePart") and d.Parent._props.CFrame then
			local p = d.Parent._props.CFrame.Position
			local col = d._props.Color or D.Color3.new(1, 1, 1)
			table.insert(out, string.format("Light %.2f %.2f %.2f %.2f %.2f %.3f %.3f %.3f",
				p.X, p.Y, p.Z, d._props.Range or 8, d._props.Brightness or 1, col.R, col.G, col.B))
		elseif R.isA(d._class, "BasePart") and d._class ~= "Terrain" and d._class ~= "MeshPart" then
			local t = d._props.Transparency or 0
			if t < 0.95 then
				local c = d._props.CFrame or D.CFrame.new()
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
				local s = d._props.Size or D.Vector3.new(4, 1.2, 2)
				local col = d._props.Color or D.Color3.new(0.64, 0.64, 0.65)
				local shape = "Block"
				if d._class == "WedgePart" then shape = "Wedge" elseif d._class == "CornerWedgePart" then shape = "Corner"
				elseif d._props.Shape then shape = d._props.Shape.Name end
				local mesh = d:FindFirstChildOfClass("SpecialMesh")
				if mesh then shape = "Sphere" end
				local mat = d._props.Material and d._props.Material.Name or "Plastic"
				table.insert(out, string.format("%s %s %.3f %.3f %.3f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.3f %.3f %.3f %.3f %.3f %.3f %.2f",
					shape, mat, x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22, s.X, s.Y, s.Z, col.R, col.G, col.B, t))
			end
		end
	end
	local terrain = {}
	for _, op in ipairs(E.TerrainOps) do
		local name = op[1]
		if name == "FillBlock" then
			local c, size, mat = op[2], op[3], op[4]
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
			table.insert(terrain, string.format("Block %s %.2f %.2f %.2f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.2f %.2f %.2f", mat.Name, x, y, z,
				r00, r01, r02, r10, r11, r12, r20, r21, r22, size.X, size.Y, size.Z))
		elseif name == "FillBall" then
			local p, r, mat = op[2], op[3], op[4]
			table.insert(terrain, string.format("Ball %s %.2f %.2f %.2f %.2f", mat.Name, p.X, p.Y, p.Z, r))
		elseif name == "FillCylinder" then
			local c, h, r, mat = op[2], op[3], op[4], op[5]
			table.insert(terrain, string.format("Cylinder %s %.2f %.2f %.2f %.2f %.2f", mat.Name, c.X, c.Y, c.Z, h, r))
		end
	end
	writefile(ROOT .. "/tests/.scene_parts.txt", table.concat(out, "\n"))
	writefile(ROOT .. "/tests/.scene_terrain.txt", table.concat(terrain, "\n"))
	print(string.format("장면 내보냄: 파트 %d · 지형 %d", #out, #terrain))
end
exportScene()

-- ===================================================================== 등록 → 배치 → 밤
print("▶ 등록 · 배치 · 밤")
teleport(0, 29 - 7)
if not step(0.5) then fail("우리 이동") end
local cage = root.Base:FindFirstChild("펫 우리", true)
cage:FindFirstChildOfClass("Attachment"):FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(player)
if not step(1) then fail("등록") end
local registered = false
for _, pet in ipairs(latest.Pets) do if pet.Status == "밤 생존 대기" then registered = true end end
check("펫 등록", registered, notices[#notices])
-- 펫 배치대 (설치형: 여기서는 바로 놓는다)
Def:Place("PetStand", D.CFrame.new(-14, 0, -32), 1, player)
for _, model in ipairs(root.Map.DefenseSlots:GetChildren()) do
	local pad = model:FindFirstChild(model.Name)
	if pad and pad:GetAttribute("SlotType") == "PetStand" then
		teleport(pad.Position.X, pad.Position.Z + 3)
		if not step(0.5) then fail("배치대 이동") end
		for _, att in ipairs(pad:GetChildren()) do
			local prompt = att:IsA("Attachment") and att:FindFirstChildOfClass("ProximityPrompt")
			if prompt and prompt.Name == "PlacePet" then prompt.Triggered:Fire(player) end
		end
		break
	end
end
if not step(0.5) then fail("배치") end
-- 밤에는 길목 2 안쪽에서 펫과 함께 싸운다
teleport(0, 10)
local sawNight, maxEnemies, coreStart = false, 0, nil
local lane2 = D.Vector3.new(math.sin(math.rad(120)), 0, -math.cos(math.rad(120)))
for _ = 1, 400 do
	if not step(0.5) then fail("밤 진행") end
	if latest.Phase == "Night" then
		if not sawNight then
			RS.Remotes.PetAction:FireServer("Follow")
		end
		local spot = lane2 * 46
		teleport(spot.X, spot.Z)
		RS.Remotes.AttackRequest:FireServer()
		sawNight = true
		coreStart = coreStart or latest.CoreHP
		maxEnemies = math.max(maxEnemies, latest.Enemies)
	end
	if sawNight and latest.Phase == "Day" then break end
end
check("밤 도래", sawNight)
check("괴물 등장", maxEnemies > 0, maxEnemies)
check("괴물 처치", (fxCount.EnemyDie or 0) > 0, "쓰러짐 " .. tostring(fxCount.EnemyDie))
local enemyVisuals = 0
for _, m in ipairs(visuals:GetChildren()) do if m.Name == "Crawler" or m.Name == "Runner" or m.Name == "Brute" then enemyVisuals = enemyVisuals + 1 end end
check("포탑 사격", (fxCount.Arrow or 0) > 0, fxCount.Arrow)
check("펫 공격", (fxCount.Pet or 0) > 0, fxCount.Pet)
local secured = 0
for _, pet in ipairs(latest.Pets) do if pet.Status == "영구" then secured = secured + 1 end end
check("밤 생존 → 영구 확정", secured == 2, secured)
check("2일차 낮", latest.Phase == "Day" and latest.Night == 2, latest.Phase .. " " .. latest.Night)

-- ===================================================================== 끝까지 (3밤)
print("▶ 끝까지 진행 (5밤 또는 Core 파괴)")
local result
for _ = 1, 1200 do
	if not step(0.5) then fail("원정 진행") end
	if latest.Result then result = latest.Result break end
end
check("원정 결과", result ~= nil, result and (tostring(result.Won) .. " · " .. result.Reason))
if not step(3) then fail("결과 화면") end

-- ===================================================================== 규칙: 성장·새 펫·지역
do
	local P = serverRequire(shared.Config.PetConfig)
	local PR = serverRequire(shared.Modules.PetRules)
	local pet = {SpeciesId = "Mossling", Level = P.EvolveLevel - 1, Exp = 0}
	local baby = PR.stats(pet, P).HP
	PR.addXP(pet, (P.EvolveLevel - 1) * 40, P)
	check("레벨 오르면 성체로 진화", pet.Level == P.EvolveLevel and pet.Stage == 2 and PR.stats(pet, P).HP > baby * 1.4,
		string.format("Lv%d Stage%s %s", pet.Level, tostring(pet.Stage), PR.name(pet.SpeciesId, 2, P)))
	local Creatures = serverRequire(shared.Visuals.Creatures)
	local missing = {}
	for _, id in ipairs(P.Order) do
		if not Creatures.build(id) or not P.Heights[id] then table.insert(missing, id) end
	end
	check("모든 펫 종 모델·키", #missing == 0, table.concat(missing, ", "))
	local zones, adults = {}, 0
	for _, wild in ipairs(root.WildPets:GetChildren()) do
		if wild:GetAttribute("Stage") == 2 then adults = adults + 1 end
	end
	local M = serverRequire(shared.Config.MapConfig)
	local Z = serverRequire(shared.Modules.Zones)
	for _, model in ipairs(root.ResourceNodes:GetChildren()) do
		local hit = model:IsA("Model") and model.PrimaryPart
		if hit then zones[Z.id(hit.Position, M)] = true end
	end
	check("지역 4곳에 자원", zones.Meadow and zones.Crags and zones.Ancient and zones.Swamp, nil)
	check("야생 펫 (성체 포함)", #root.WildPets:GetChildren() > 40 and adults > 0, #root.WildPets:GetChildren() .. "마리 · 성체 " .. adults)
end

-- ===================================================================== 원정 끝 → 로비 · 알 · 부화
print("▶ 로비로 돌아가기 · 알 · 부화")
for _ = 1, 40 do
	if player:GetAttribute("Place") == "Lobby" then break end
	if not step(0.5) then fail("로비 복귀") end
end
if not step(1) then fail("로비 상태") end
check("원정이 끝나면 로비로", player:GetAttribute("Place") == "Lobby" and (hrp.Position - lobbyOrigin).Magnitude < 90 and playerGui.Lobby.Enabled,
	player:GetAttribute("Place"))
do
	local Eggs = serverRequire(SSS.Services.EggService)
	local before = #lobbyState.Eggs
	Eggs:Grant(player, "Rare", "테스트")
	if not step(1) then fail("알 받기") end
	local egg
	for _, e in ipairs(lobbyState.Eggs) do if e.Kind == "Rare" and not e.HatchAt then egg = e end end
	check("희귀한 알 받기", #lobbyState.Eggs == before + 1 and egg ~= nil, #lobbyState.Eggs .. "개")
	RS.Remotes.LobbyAction:FireServer("Incubate", egg.Id)
	if not step(1) then fail("부화장") end
	local hatchAt
	for _, e in ipairs(lobbyState.Eggs) do if e.Id == egg.Id then hatchAt = e.HatchAt end end
	check("부화장에 넣기 (타이머)", hatchAt ~= nil and hatchAt > lobbyState.Now, hatchAt and (hatchAt - lobbyState.Now .. "초"))
	RS.Remotes.LobbyAction:FireServer("Hatch", egg.Id)
	if not step(0.6) then fail("이른 부화") end
	check("시간 전에는 안 깨어남", #lobbyState.Eggs == before + 1)
	local hatched
	RS.Remotes.PetFX.OnClientEvent:Connect(function(kind, pet) if kind == "Hatched" then hatched = pet end end)
	local petsBefore = #lobbyState.Pets
	if not step((hatchAt or 0) - lobbyState.Now + 1, 0.25) then fail("부화 기다리기") end
	RS.Remotes.LobbyAction:FireServer("Hatch", egg.Id)
	if not step(1) then fail("부화") end
	check("희귀한 알 부화 (별 3개 이상)", hatched ~= nil and hatched.Stars >= 3 and #lobbyState.Pets == petsBefore + 1,
		hatched and string.format("%s ★%d%s", hatched.SpeciesId, hatched.Stars, hatched.Shiny and " 빛나는" or ""))
	if not step(1.5) then fail("부화 연출") end
	local LobbyUI = clientRequire(playerScripts.Controllers.LobbyController)
	check("부화 연출 화면", LobbyUI.Reveal.Visible and LobbyUI.RevealFace.Visible, LobbyUI.RevealText.Text)
	-- 출전 팀 바꾸기 (다음 원정에 데려감)
	local party = {}
	for _, pet in ipairs(lobbyState.Pets) do if #party < 2 then table.insert(party, pet.Uid) end end
	RS.Remotes.LobbyAction:FireServer("Party", party)
	if not step(0.6) then fail("출전 팀") end
	check("로비에서 출전 팀 편성", #lobbyState.Party == 2, #lobbyState.Party)
	-- 코인 보급: 코인이 모자라면 해금되지 않는다
	RS.Remotes.LobbyAction:FireServer("Perk", "StartBag")
	if not step(0.6) then fail("보급 해금 시도") end
	check("보급 해금은 코인 필요", not (lobbyState.Perks and lobbyState.Perks.StartBag) and string.find(notices[#notices] or "", "코인") ~= nil, notices[#notices])
end
-- 원정 수레(방): 올라타면 방장, 내리면 나감, 인원 1명이면 곧 출발
do
	local pad = root.Lobby:FindFirstChild("Wagon1"):FindFirstChild("WagonPad")
	teleport(pad.Position.X, pad.Position.Z)
	if not step(0.8) then fail("수레 타기") end
	check("원정 수레에 타면 방장", lobbyState.MyRoom == 1 and lobbyState.Host, lobbyState.MyRoom)
	teleport(lobbyOrigin.X, lobbyOrigin.Z + 20)
	if not step(0.8) then fail("수레 내리기") end
	check("수레에서 내리면 방에서 나감", lobbyState.MyRoom == nil)
	teleport(pad.Position.X, pad.Position.Z)
	if not step(0.8) then fail("다시 타기") end
	RS.Remotes.LobbyAction:FireServer("Size", 1)
	if not step(LCfg.FullWait + 1.5) then fail("방 출발") end
	check("정원이 차면 출발 → 원정", player:GetAttribute("Place") == "Expedition", player:GetAttribute("Place"))
end

-- ===================================================================== 결과
print(string.format("\n가상 시간 %.0f초 · 프레임 %d · 경고 %d · 킥 %d", R.Now, frame, #R.Warnings, #R.Kicks))
for _, w in ipairs(R.Warnings) do print("  [warn] " .. w) end
for _, k in ipairs(R.Kicks) do print("  [kick] " .. k) end
local failed = 0
for _, c in ipairs(checks) do if not c[2] then failed = failed + 1 end end
if #R.Errors > 0 then fail("런타임 오류") end
print(failed == 0 and "\n✅ 모든 검사 통과" or string.format("\n❌ %d개 검사 실패", failed))


if failed > 0 then error("검사 실패") end
