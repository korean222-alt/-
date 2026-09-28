-- 초원 맵 생성: 지형(Terrain) + 기지(말뚝 울타리, Core, 창고, 제작대, 펫 우리) + 3 길목 + 자원 노드 + 숲/연못/알파의 숲.
-- 다른 서비스가 쓰는 값: Lanes, Slots, Nodes, Core, Warehouse, Workbench, Cage, Spawn, 각 폴더, CagePrompt, CraftPrompt
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local C = require(RS.Shared.Config.MapConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local P = require(RS.Shared.Config.PetConfig)
local G = require(RS.Shared.Config.GameConfig)
local B = require(RS.Shared.Visuals.Build)
local Props = require(RS.Shared.Visuals.Props)
local S = require(RS.Shared.Visuals.Structures)

local Map = {}
local MAT = Enum.Material

local function flat(x, z)
	return Vector3.new(x, 0, z)
end

function Map:Build()
	local old = workspace:FindFirstChild("WILDHOLD")
	if old then
		old:Destroy()
	end
	self.Root = U.folder(workspace, "WILDHOLD")
	self.Map = U.folder(self.Root, "Map")
	self.LanesFolder = U.folder(self.Map, "Lanes")
	self.SlotsFolder = U.folder(self.Map, "DefenseSlots")
	self.DecorFolder = U.folder(self.Map, "Decor")
	self.NodesFolder = U.folder(self.Root, "ResourceNodes")
	self.DropsFolder = U.folder(self.Root, "Drops")
	self.DefensesFolder = U.folder(self.Root, "Defenses")
	self.EnemiesFolder = U.folder(self.Root, "Enemies")
	self.FXFolder = U.folder(self.Root, "FX")
	self.PetsFolder = U.folder(self.Root, "Pets")
	self.WildFolder = U.folder(self.Root, "WildPets")
	self.Base = U.folder(self.Root, "Base")
	self.Lanes, self.Slots, self.Nodes, self.Blocked = {}, {}, {}, {}
	self.Rng = Random.new(20260928)

	for i, angle in ipairs(C.LaneAngles) do
		local rad = math.rad(angle)
		local dir = Vector3.new(math.sin(rad), 0, -math.cos(rad))
		local lane = {Id = i, Dir = dir, Side = Vector3.new(-dir.Z, 0, dir.X), Points = {}}
		local folder = U.folder(self.LanesFolder, "Lane" .. i)
		for n, radius in ipairs(C.WaypointRadii) do
			local pos = dir * radius + Vector3.new(0, 2, 0)
			table.insert(lane.Points, pos)
			local waypoint = U.part(folder, tostring(n), Vector3.new(1, 1, 1), pos)
			waypoint.Transparency, waypoint.CanCollide, waypoint.CanQuery, waypoint.CanTouch = 1, false, false, false
		end
		self.Lanes[i] = lane
	end

	self:BuildTerrain()
	self:BuildBase()
	self:BuildLanes()
	self:BuildSlots()
	self:BuildNodes()
	self:BuildScenery()
	return self
end

-- ============================================================= 지형
function Map:BuildTerrain()
	local T = workspace.Terrain
	T:Clear()
	pcall(function()
		T.Decoration = true
	end)
	-- 생존 톤: 채도를 낮춘 짙은 숲 바닥 (올리브색 풀, 낙엽 흙, 진흙)
	T:SetMaterialColor(MAT.Grass, Color3.fromHex("#4a573a"))
	T:SetMaterialColor(MAT.LeafyGrass, Color3.fromHex("#3d4a2f"))
	T:SetMaterialColor(MAT.Ground, Color3.fromHex("#5a4a3a"))
	T:SetMaterialColor(MAT.Mud, Color3.fromHex("#3d3228"))
	T:SetMaterialColor(MAT.Sand, Color3.fromHex("#9c8f6e"))
	T:SetMaterialColor(MAT.Cobblestone, Color3.fromHex("#77746c"))
	T:SetMaterialColor(MAT.Rock, Color3.fromHex("#62666b"))
	T.WaterColor = Color3.fromHex("#2c4f5c")
	T.WaterTransparency = 0.45
	T.WaterReflectance = 0.35
	T.WaterWaveSize = 0.08
	T.WaterWaveSpeed = 6

	local size = C.GroundSize
	T:FillBlock(CFrame.new(0, -6, 0), Vector3.new(size, 12, size), MAT.Grass)
	local rng = self.Rng
	-- 테두리 언덕과 바위 절벽: 맵 끝을 자연스럽게 가린다
	for i = 1, 84 do
		local a = i / 84 * math.pi * 2 + B.jitter(rng, 0.03)
		local r = C.PlayRadius + 26 + rng:NextNumber() * 34
		local radius = 16 + rng:NextNumber() * 16
		T:FillBall(Vector3.new(math.cos(a) * r, -4 + rng:NextNumber() * 8, math.sin(a) * r), radius, rng:NextNumber() < 0.25 and MAT.Rock or MAT.Grass)
	end
	for _ = 1, 28 do
		local a = rng:NextNumber() * math.pi * 2
		local r = C.PlayRadius + 55 + rng:NextNumber() * 20
		T:FillBall(Vector3.new(math.cos(a) * r, 10 + rng:NextNumber() * 12, math.sin(a) * r), 18 + rng:NextNumber() * 10, MAT.LeafyGrass)
	end
	-- 숲 바닥 얼룩: 풀밭이 한 가지 색으로 매끈하면 공원처럼 보인다 → 낙엽 흙·이끼·진흙 조각을 흩뿌린다
	for _ = 1, 70 do
		local a = rng:NextNumber() * math.pi * 2
		local r = C.BaseRadius + 4 + rng:NextNumber() * (C.PlayRadius + 30 - C.BaseRadius)
		local center = Vector3.new(math.cos(a) * r, -1.2, math.sin(a) * r)
		local roll = rng:NextNumber()
		local mat = roll < 0.45 and MAT.LeafyGrass or (roll < 0.85 and MAT.Ground or MAT.Mud)
		for _ = 1, 3 do
			local off = Vector3.new(B.jitter(rng, 6), 0, B.jitter(rng, 6))
			T:FillCylinder(CFrame.new(center + off), 2.6, 4 + rng:NextNumber() * 7, mat)
		end
	end
	-- 기지 바닥: 흙 광장 + Core 주변 돌바닥
	T:FillCylinder(CFrame.new(0, -2, 0), 4, C.BaseRadius - 2, MAT.LeafyGrass)
	T:FillCylinder(CFrame.new(0, -2, 0), 4, 13, MAT.Cobblestone)
	-- 길목: 괴물 굴에서 Core 까지 흙길
	for _, lane in ipairs(self.Lanes) do
		local from, to = 6, C.LaneRadius + 8
		local mid = lane.Dir * ((from + to) / 2)
		T:FillBlock(CFrame.lookAt(mid + Vector3.new(0, -2, 0), mid + lane.Dir + Vector3.new(0, -2, 0)), Vector3.new(C.LaneWidth, 4, to - from), MAT.Ground)
		for n = 1, 10 do
			local t = from + (to - from) * n / 11
			local side = (n % 2 == 0 and 1 or -1) * (C.LaneWidth / 2 + 1)
			T:FillBall(lane.Dir * t + lane.Side * side + Vector3.new(0, -2.5, 0), 3, MAT.Mud)
		end
	end
	-- 건물 아래 흙 바닥
	for _, spot in ipairs({C.Warehouse, C.Workbench, C.Cage}) do
		T:FillCylinder(CFrame.new(spot[1], -2, spot[3]), 4, 9, MAT.Ground)
	end
	-- 연못 (모래 둘레 → 파기 → 물)
	local px, pz, pr = table.unpack(C.Pond)
	T:FillCylinder(CFrame.new(px, -2, pz), 4, pr + 5, MAT.Sand)
	T:FillCylinder(CFrame.new(px, -5, pz), 10, pr, MAT.Air)
	T:FillCylinder(CFrame.new(px, -6, pz), 8, pr, MAT.Water)
	T:FillBlock(CFrame.new(px, -11, pz), Vector3.new(pr * 2 + 2, 2, pr * 2 + 2), MAT.Sand)
	-- 알파의 숲 바닥
	local gx, gz, gr = table.unpack(C.Grove)
	T:FillCylinder(CFrame.new(gx, -2, gz), 4, gr, MAT.LeafyGrass)
	self:Block(flat(px, pz), pr + 6)
	self:Block(flat(gx, gz), 9)
end

function Map:Block(pos, radius)
	table.insert(self.Blocked, {pos, radius})
end

function Map:Free(pos, radius)
	local r = pos.Magnitude
	if r < C.BaseRadius + 7 or r > C.PlayRadius + 4 then
		return false
	end
	for _, lane in ipairs(self.Lanes) do
		local t = pos:Dot(lane.Dir)
		if t > 0 and math.abs(pos:Dot(lane.Side)) < C.LaneWidth / 2 + 5 + radius then
			return false
		end
	end
	for _, b in ipairs(self.Blocked) do
		if (b[1] - pos).Magnitude < b[2] + radius then
			return false
		end
	end
	return true
end

-- ============================================================= 기지
function Map:BuildBase()
	local base = self.Base
	local toCore = function(x, z)
		return CFrame.lookAt(flat(x, z), Vector3.zero)
	end
	local _, coreHit = S.core(base, CFrame.new())
	self.Core = coreHit
	self.Core.Name = "Core"

	S.storehouse(base, toCore(C.Warehouse[1], C.Warehouse[3]))
	self.Warehouse = base.Storehouse.Hitbox
	self.Warehouse.Name = "공용 창고"
	local ring = base.Storehouse:FindFirstChild("DepositRing")
	if ring then
		ring.Size = Vector3.new(0.08, G.DepositRadius * 2, G.DepositRadius * 2)
		ring.CFrame = CFrame.new(self.Warehouse.Position.X, 0.1, self.Warehouse.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	end

	S.workbench(base, toCore(C.Workbench[1], C.Workbench[3]))
	self.Workbench = base.Workbench.Hitbox
	self.Workbench.Name = "제작대"
	self.CraftPrompt = U.prompt(self.Workbench, "Craft", "덫 · 먹이 · 간식 만들기", Enum.KeyCode.E, Vector3.new(0, 1.5, -2.5))
	self.CraftPrompt.ObjectText = "제작대"

	local _, penPad = S.pen(base, CFrame.new(C.Cage[1], 0, C.Cage[3]))
	self.Cage = penPad
	self.Cage.Name = "펫 우리"
	self.CagePrompt = U.prompt(self.Cage, "Register", "잡은 펫 등록", Enum.KeyCode.E, Vector3.new(0, 1.5, -5))
	self.CagePrompt.ObjectText = "펫 우리"

	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.Position = "ExpeditionSpawn", Vector3.new(6, 1, 6), Vector3.new(table.unpack(C.Spawn))
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Transparency, spawn.CanCollide = true, true, 3, 1, false
	spawn.Parent = base
	self.Spawn = spawn
	B.cyl(base, 0.3, 7, CFrame.new(spawn.Position.X, 0.15, spawn.Position.Z), "#7d776c", MAT.Slate, true)
	B.cyl(base, 0.32, 5.4, CFrame.new(spawn.Position.X, 0.17, spawn.Position.Z), "#8ff5e8", MAT.Neon, true, {Transparency = 0.8})

	-- 말뚝 울타리 (길목 구멍 3개)
	local palisade = B.model(base, "Palisade")
	local rng = Random.new(5)
	local step = 1.65 / C.BaseRadius
	local gapHalf = (C.GapWidth / 2 + 0.8) / C.BaseRadius
	local a = 0
	while a < math.pi * 2 do
		local open = false
		for _, lane in ipairs(self.Lanes) do
			local la = math.atan2(lane.Dir.Z, lane.Dir.X)
			local d = math.abs((a - la + math.pi) % (math.pi * 2) - math.pi)
			if d < gapHalf then
				open = true
			end
		end
		if not open then
			local pos = Vector3.new(math.cos(a) * C.BaseRadius, 0, math.sin(a) * C.BaseRadius)
			local h = 7.2 + rng:NextNumber() * 1.3
			Props.stake(palisade, CFrame.lookAt(pos, Vector3.zero) * CFrame.Angles(math.rad(rng:NextInteger(-3, 3)), 0, math.rad(rng:NextInteger(-3, 3))), h, rng)
		end
		a = a + step
	end
	for _, d in ipairs(palisade:GetDescendants()) do
		if d:IsA("BasePart") and math.max(d.Size.X, d.Size.Y) > 5 then
			d.CanCollide, d.CanQuery = true, true
		end
	end
	-- 안쪽 가로대 (걷는 발판처럼 보이게)
	for i = 0, 35 do
		local ang = i / 36 * math.pi * 2
		local blocked = false
		for _, lane in ipairs(self.Lanes) do
			local la = math.atan2(lane.Dir.Z, lane.Dir.X)
			if math.abs((ang - la + math.pi) % (math.pi * 2) - math.pi) < gapHalf + 0.08 then
				blocked = true
			end
		end
		if not blocked then
			local pos = Vector3.new(math.cos(ang), 0, math.sin(ang)) * (C.BaseRadius - 1.1)
			local len = 2 * math.pi * (C.BaseRadius - 1.1) / 36 + 0.3
			B.block(palisade, Vector3.new(len, 0.5, 0.5), CFrame.lookAt(pos, Vector3.zero) + Vector3.new(0, 5.2, 0), "#6b4423", MAT.Wood)
			B.block(palisade, Vector3.new(len, 0.5, 0.5), CFrame.lookAt(pos, Vector3.zero) + Vector3.new(0, 2.2, 0), "#6b4423", MAT.Wood)
		end
	end

	-- 광장 소품: 횃불, 깃발, 모닥불
	for i = 0, 5 do
		local ang = math.rad(i * 60 + 30)
		Props.torch(base, CFrame.new(math.cos(ang) * 11.5, 0, math.sin(ang) * 11.5), 5.5)
	end
	Props.banner(base, CFrame.new(-8, 0, 20), "#3fa9a0", 9)
	Props.banner(base, CFrame.new(8, 0, 20), "#f2c14e", 9)
	local fire = B.model(base, "Campfire")
	local fpos = CFrame.new(-12, 0, 20)
	for i = 0, 5 do
		B.block(fire, Vector3.new(1.2, 0.8, 1), fpos * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(0, 0.4, -1.6), "#8b8f94", MAT.Slate)
	end
	for i = 0, 2 do
		B.cyl(fire, 2.6, 0.6, fpos * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(12)), "#6e4a2c", MAT.Wood)
	end
	local flame = B.ball(fire, 1, fpos * CFrame.new(0, 1, 0), "#ffb347", MAT.Neon, {Transparency = 0.3})
	local fx = Instance.new("Fire")
	fx.Size, fx.Heat = 4, 9
	fx.Parent = flame
	B.light(flame, "PointLight", {Range = 20, Brightness = 1.8, Color = Color3.fromHex("#ffa860"), Shadows = true})
	for i, off in ipairs({Vector3.new(-3.6, 0, 0.5), Vector3.new(3.4, 0, -0.6)}) do
		B.cyl(fire, 3.4, 1, fpos * CFrame.new(off) * CFrame.Angles(0, math.rad(80 + i * 20), 0) + Vector3.new(0, 0.5, 0), "#8a5d36", MAT.Wood)
	end
end

-- ============================================================= 길목, 굴, 날개 울타리
function Map:BuildLanes()
	for _, lane in ipairs(self.Lanes) do
		local folder = self.LanesFolder["Lane" .. lane.Id]
		local mouth = lane.Dir * (C.LaneRadius + 6)
		Props.burrow(folder, CFrame.lookAt(mouth, Vector3.zero), self.Rng)
		self:Block(mouth, 14)
		-- 바깥 벽 자리 옆 울타리 날개: 길목이 "막히는 곳" 으로 읽히게 한다
		for _, radius in ipairs({57, 78}) do
			for _, s in ipairs({-1, 1}) do
				local center = lane.Dir * radius + lane.Side * s * (C.LaneWidth / 2 + 5)
				local frame = CFrame.lookAt(center, center + lane.Side)
				for k = -1, 1 do
					B.cyl(folder, 3.4, 0.7, frame * CFrame.new(0, 1.7, k * 3.4), "#5e4b3b", MAT.Wood, true)
				end
				for _, y in ipairs({1.2, 2.7}) do
					B.block(folder, Vector3.new(0.4, 0.4, 7.4), frame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(4 * s)), "#54432f", MAT.Wood)
				end
				Props.rock(folder, frame * CFrame.new(0, 0, 6.5), self.Rng, 0.55)
			end
		end
		-- 길 표지 돌 (길목 번호)
		local marker = lane.Dir * 46 + lane.Side * (C.LaneWidth / 2 + 2.5)
		local stone = B.block(folder, Vector3.new(1.6, 2.6, 0.9), CFrame.lookAt(marker, marker - lane.Dir) + Vector3.new(0, 1.3, 0), "#6f7376", MAT.Slate)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.CanvasSize, gui.LightInfluence = Enum.NormalId.Front, Vector2.new(100, 160), 1
		gui.Parent = stone
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency, text.TextScaled = UDim2.fromScale(1, 1), 1, true
		text.Font, text.Text, text.TextColor3 = Enum.Font.FredokaOne, tostring(lane.Id), Color3.fromHex("#2a2530")
		text.Parent = gui
	end
end

-- ============================================================= 방어 자리
function Map:BuildSlots()
	for _, spec in ipairs(C.Slots) do
		local kind, laneId, radius, side, initial = table.unpack(spec)
		local lane = self.Lanes[math.max(1, laneId)]
		local pos = lane.Dir * radius + lane.Side * side
		local frame = CFrame.lookAt(pos, pos + lane.Dir)
		local id = string.format("S%02d", #self.Slots + 1)
		local model, pad, blueprint = S.slotBase(self.SlotsFolder, frame, kind)
		model.Name = id
		pad.Name = id
		pad:SetAttribute("SlotId", id)
		pad:SetAttribute("SlotType", kind)
		pad:SetAttribute("LaneId", lane.Id)
		local width = (radius == C.BaseRadius) and C.GapWidth or C.LaneWidth
		table.insert(self.Slots, {Id = id, Kind = kind, LaneId = lane.Id, Pad = pad, CFrame = frame, Width = width,
			Blueprint = blueprint, InitialLevel = initial})
		self:Block(pos, 7)
		if kind == "PetStand" then
			local stand = S.defense(model, "PetStand", 1, frame)
			stand.Name = "Stand"
			blueprint:Destroy()
			pad.Size = Vector3.new(5.6, 0.4, 5.6)
		end
	end
end

-- ============================================================= 채집 노드
local NODE_BUILDERS = {
	Wood = function(parent, at, rng)
		return Props.tree(parent, at, rng, 0.9, "WoodTree"), Vector3.new(3.4, 12, 3.4)
	end,
	Stone = function(parent, at, rng)
		return Props.rock(parent, at, rng, 1.05, "StoneRock"), Vector3.new(7, 5, 6)
	end,
	Fiber = function(parent, at, rng)
		return Props.reeds(parent, at, rng, 1.1), Vector3.new(4.5, 7, 4.5)
	end,
	Scrap = function(parent, at, rng)
		return Props.scrap(parent, at, rng, 1.1), Vector3.new(6, 5, 5)
	end,
	Berry = function(parent, at, rng)
		return Props.bush(parent, at, rng, 1.05, true), Vector3.new(5.5, 5, 5.5)
	end,
}

function Map:BuildNodes()
	local rng = self.Rng
	for _, kind in ipairs(R.Order) do
		local spec = R.Types[kind]
		for n, xz in ipairs(C.Nodes[kind] or {}) do
			local pos = flat(xz[1], xz[2])
			local model, size = NODE_BUILDERS[kind](self.NodesFolder, CFrame.new(pos), rng)
			model.Name = kind .. n
			local hit = B.hitbox(model, size, CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)), true)
			hit.Name = kind .. n
			hit:SetAttribute("ResourceType", kind)
			hit:SetAttribute("MaxHealth", spec.HP)
			hit:SetAttribute("CurrentHealth", spec.HP)
			hit:SetAttribute("RespawnTime", spec.Respawn)
			model.PrimaryPart = hit
			table.insert(self.Nodes, {Part = hit, Model = model, Kind = kind, Home = CFrame.new(pos)})
			self:Block(pos, 7)
		end
	end
	for _, spawn in ipairs(P.Spawns) do
		self:Block(flat(spawn[3], spawn[4]), 8)
	end
end

-- ============================================================= 숲, 소품, 연못, 알파의 숲
function Map:BuildScenery()
	local decor, rng = self.DecorFolder, self.Rng
	-- 바깥 숲 벽: 키 큰 가문비나무 세 줄. 기지 밖 어디서 봐도 빽빽한 숲에 갇힌 느낌을 준다.
	-- 굴 앞 길목만 비우고 굴 뒤쪽은 다시 숲으로 막는다. 뒷줄은 가벼운 메쉬를 쓴다.
	local function onLane(pos, width)
		if pos.Magnitude > C.LaneRadius + 14 then
			return false
		end
		for _, lane in ipairs(self.Lanes) do
			if pos:Dot(lane.Dir) > 0 and math.abs(pos:Dot(lane.Side)) < width then
				return true
			end
		end
		return false
	end
	for row, spec in ipairs({{110, 2, 12}, {95, 17, 18}, {80, 36, 26}}) do
		local count, inner, spread = table.unpack(spec)
		for i = 1, count do
			local a = i / count * math.pi * 2 + B.jitter(rng, 0.025)
			local r = C.PlayRadius + inner + rng:NextNumber() * spread
			local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			if not onLane(pos, 16) then
				Props.tallPine(decor, CFrame.new(pos), rng, 1.0 + rng:NextNumber() * 0.45 + row * 0.08, false, row > 1)
			end
		end
	end
	-- 안쪽 흩뿌림 도우미 (길목·기지·자원 자리를 피한다)
	local function scatter(n, radius, build, minR, maxR)
		local placed, tries = 0, 0
		minR, maxR = minR or C.BaseRadius + 8, maxR or C.PlayRadius
		while placed < n and tries < n * 30 do
			tries = tries + 1
			local a = rng:NextNumber() * math.pi * 2
			local r = minR + rng:NextNumber() * (maxR - minR)
			local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			if self:Free(pos, radius) then
				build(CFrame.new(pos), pos)
				self:Block(pos, radius)
				placed = placed + 1
			end
		end
	end
	-- 숲 가장자리 덤불: 숲 벽과 풀밭 사이를 고사리·바위·쓰러진 나무로 자연스럽게 잇는다
	scatter(40, 2.5, function(at)
		Props.fern(decor, at, rng, 0.9 + rng:NextNumber() * 0.5)
	end, C.PlayRadius - 18, C.PlayRadius + 3)
	scatter(10, 4, function(at)
		Props.rock(decor, at, rng, 0.7 + rng:NextNumber() * 0.7)
	end, C.PlayRadius - 20, C.PlayRadius + 3)
	-- 나무 무리: 가문비나무 3~6그루가 모여 선 작은 숲. 발밑엔 고사리, 그루터기, 쓰러진 통나무
	scatter(16, 11, function(_, center)
		for _ = 1, rng:NextInteger(3, 6) do
			local a = rng:NextNumber() * math.pi * 2
			local pos = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (2 + rng:NextNumber() * 7)
			Props.tallPine(decor, CFrame.new(pos), rng, 0.62 + rng:NextNumber() * 0.3, true)
		end
		for _ = 1, rng:NextInteger(2, 4) do
			local a = rng:NextNumber() * math.pi * 2
			Props.fern(decor, CFrame.new(center + Vector3.new(math.cos(a), 0, math.sin(a)) * (4 + rng:NextNumber() * 6)), rng, 0.8 + rng:NextNumber() * 0.4)
		end
		local roll = rng:NextNumber()
		local a = rng:NextNumber() * math.pi * 2
		local spot = CFrame.new(center + Vector3.new(math.cos(a), 0, math.sin(a)) * 8)
		if roll < 0.4 then
			Props.log(decor, spot, rng, 0.9 + rng:NextNumber() * 0.4)
		elseif roll < 0.7 then
			Props.stump(decor, spot, rng, 0.9 + rng:NextNumber() * 0.4)
		else
			Props.rock(decor, spot, rng, 0.6 + rng:NextNumber() * 0.5)
		end
	end)
	scatter(12, 4, function(at)
		Props.deadTree(decor, at, rng, 0.8 + rng:NextNumber() * 0.5)
	end)
	scatter(10, 5, function(at)
		Props.log(decor, at, rng, 0.8 + rng:NextNumber() * 0.4)
	end)
	scatter(12, 3, function(at)
		Props.stump(decor, at, rng, 0.8 + rng:NextNumber() * 0.4)
	end)
	scatter(18, 3, function(at)
		Props.rock(decor, at, rng, 0.4 + rng:NextNumber() * 0.6)
	end)
	scatter(60, 1.8, function(at)
		Props.fern(decor, at, rng, 0.7 + rng:NextNumber() * 0.5)
	end)
	scatter(22, 1.5, function(at)
		Props.mushrooms(decor, at, rng)
	end)

	-- 연못 가장자리: 갈대, 바위, 수련 잎
	local px, pz, pr = table.unpack(C.Pond)
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2 + B.jitter(rng, 0.2)
		local pos = Vector3.new(px + math.cos(a) * (pr + 2.5), 0, pz + math.sin(a) * (pr + 2.5))
		if i % 3 == 0 then
			Props.rock(decor, CFrame.new(pos), rng, 0.45)
		else
			Props.reeds(decor, CFrame.new(pos), rng, 0.7)
		end
	end
	for i = 1, 6 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber() * (pr - 3)
		local pad = B.cyl(decor, 0.15, 2.4 + rng:NextNumber(), CFrame.new(px + math.cos(a) * r, -1.95, pz + math.sin(a) * r), "#3f6a3c", MAT.SmoothPlastic, true)
		pad.Name = "LilyPad"
		if i % 2 == 0 then
			B.ball(decor, 0.5, pad.Position + Vector3.new(0.3, 0.2, 0), "#8fb8ff", MAT.Neon)
		end
	end

	-- 알파의 숲: 오래된 거대 나무 + 꽃 + 선돌
	local gx, gz, gr = table.unpack(C.Grove)
	local grove = B.model(decor, "AlphaGrove")
	Props.tree(grove, CFrame.new(gx, 0, gz + 14), rng, 2.1, "AncientTree")
	for i = 1, 7 do
		local a = math.rad(i * (360 / 7) + 10)
		local pos = Vector3.new(gx + math.cos(a) * (gr - 3), 0, gz + math.sin(a) * (gr - 3))
		if (pos - Vector3.new(gx, 0, gz + 14)).Magnitude > 7 then
			local stone = B.block(grove, Vector3.new(2, 5 + rng:NextNumber() * 2, 1.4), CFrame.lookAt(pos, Vector3.new(gx, 0, gz)) + Vector3.new(0, 2.6, 0), "#a3a8ad", MAT.Slate)
			B.block(grove, Vector3.new(0.3, 2, 0.1), stone.CFrame * CFrame.new(0, 0.5, -0.72), "#b6ff8a", MAT.Neon)
		end
	end
	for _ = 1, 10 do
		local a = rng:NextNumber() * math.pi * 2
		local r = 4 + rng:NextNumber() * (gr - 6)
		Props.mushrooms(grove, CFrame.new(gx + math.cos(a) * r, 0, gz + math.sin(a) * r), rng)
	end
	B.light(B.block(grove, Vector3.new(1, 1, 1), CFrame.new(gx, 6, gz), "#ffffff", MAT.SmoothPlastic, {Transparency = 1}), "PointLight",
		{Range = 26, Brightness = 1.2, Color = Color3.fromHex("#c9ff9a"), Shadows = false})
end

return Map
