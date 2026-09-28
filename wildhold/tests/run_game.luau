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
print("▶ 서버 시작")
run(SSS.ServerMain, serverGlobals, serverRequire)
if #R.Errors > 0 then fail("ServerMain 시작") end
local root = workspace:FindFirstChild("WILDHOLD")
check("맵 생성", root ~= nil)
local partCount = 0
for _, d in ipairs(root:GetDescendants()) do if R.isA(d._class, "BasePart") then partCount = partCount + 1 end end
check("맵 파트 수", partCount > 800 and partCount < 12000, partCount)
check("지형 명령", #E.TerrainOps > 50, #E.TerrainOps)

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
-- 블렌더 FBX 를 Studio 로 가져온 것과 같은 구조의 가짜 모델 (MeshPart + Bone 계층)
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
	model.Parent = RS.PetModels
end
print("▶ 클라이언트 시작")
run(playerScripts.ClientMain, clientGlobals, clientRequire)
if not step(2) then fail("클라이언트 시작") end
for _, w in ipairs(R.Warnings) do
	if w:find("시작 실패") then fail("컨트롤러 시작 실패: " .. w) end
end
check("HUD 생성", playerGui:FindFirstChild("WildholdHUD") ~= nil)
check("펫 패널 생성", playerGui:FindFirstChild("PetBook") ~= nil)
check("스피어 장착", char:FindFirstChildOfClass("Tool") ~= nil)
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
for _, kind in ipairs({"Wood", "Wood", "Stone", "Fiber"}) do harvest(kind, 8) end
local bagTotal = 0
for _, v in pairs(latest.Bag) do bagTotal = bagTotal + v end
check("가방에 자원", bagTotal > 0, bagTotal)
teleport(21 * 0.7, -12 * 0.7)
if not step(1.5) then fail("입금") end
local bank = latest.Bank
check("공용 창고 입금", (bank.Wood or 0) > 0, "나무 " .. tostring(bank.Wood) .. " / 돌 " .. tostring(bank.Stone))
-- 벽 짓기: 길목 1 의 바깥 벽 자리
local wallSlot
for _, model in ipairs(root.Map.DefenseSlots:GetChildren()) do
	local pad = model:FindFirstChild(model.Name)
	if pad and pad:GetAttribute("SlotType") == "Wall" and pad:GetAttribute("Level") == 0 then wallSlot = pad; break end
end
check("빈 벽 자리", wallSlot ~= nil)
teleport(wallSlot.Position.X, wallSlot.Position.Z + 4)
if not step(0.5) then fail("벽 자리 이동") end
local buildPrompt = wallSlot:FindFirstChildOfClass("Attachment"):FindFirstChildOfClass("ProximityPrompt")
buildPrompt.Triggered:Fire(player)
if not step(1) then fail("건설") end
check("벽 건설", wallSlot:GetAttribute("Level") == 1, notices[#notices])
-- 제작
teleport(-21 * 0.75, -12 * 0.75)
if not step(0.5) then fail("제작대 이동") end
RS.Remotes.CraftAction:FireServer("Bait")
if not step(0.6) then fail("제작") end

local function exportScene()
	-- 맵 미리보기용 장면 내보내기
	local out = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if R.isA(d._class, "BasePart") and d._class ~= "Terrain" then
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
-- 펫 배치대
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
print("▶ 3밤까지 진행")
local result
for _ = 1, 1200 do
	if not step(0.5) then fail("원정 진행") end
	if latest.Result then result = latest.Result break end
end
check("원정 결과", result ~= nil, result and (tostring(result.Won) .. " · " .. result.Reason))
if not step(3) then fail("결과 화면") end

-- ===================================================================== 결과
print(string.format("\n가상 시간 %.0f초 · 프레임 %d · 경고 %d · 킥 %d", R.Now, frame, #R.Warnings, #R.Kicks))
for _, w in ipairs(R.Warnings) do print("  [warn] " .. w) end
for _, k in ipairs(R.Kicks) do print("  [kick] " .. k) end
local failed = 0
for _, c in ipairs(checks) do if not c[2] then failed = failed + 1 end end
if #R.Errors > 0 then fail("런타임 오류") end
print(failed == 0 and "\n✅ 모든 검사 통과" or string.format("\n❌ %d개 검사 실패", failed))


if failed > 0 then error("검사 실패") end
