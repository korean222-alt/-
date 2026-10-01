-- 원정 맵 생성: 지형(Terrain) + 기지(Core 모닥불, 요리 모닥불 — v2 는 울타리·창고·펫 우리 없이 빈 기지) + 3 길목
-- + 지역(초원·바위 협곡·고목의 숲·안개 늪) + 자원 노드 + 야생 펫 자리 + 숲 + 지역 소품·유적·보물상자(BuildRuins). 놀 수 있는 곳은 지름 약 1500 (MapConfig).
-- 다른 서비스가 쓰는 값: Lanes, Nodes, WildSpawns, Core, Warehouse, Campfire, Cage, Spawn, Chests, 각 폴더
--  (Warehouse·Cage 는 v2 에서 보이지 않는 기준 파트만 남았다: 예전 코드·테스트가 위치를 참조해도 깨지지 않게)
-- 제작대·벽·포탑은 고정 자리가 없다: 플레이어가 설치한다 (DefenseService, 시작 구조물은 BuildConfig.Starter)
-- 맵 가장자리에는 보이지 않는 경계 벽(WallRadius)이 있고, 지도(미니맵)용 격자를 ReplicatedStorage.MapGrid 로 내보낸다.
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local Zones = require(RS.Shared.Modules.Zones)
local C = require(RS.Shared.Config.MapConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local G = require(RS.Shared.Config.GameConfig)
local B = require(RS.Shared.Visuals.Build)
local Props = require(RS.Shared.Visuals.Props)
local S = require(RS.Shared.Visuals.Structures)
local Ruins = require(RS.Shared.Visuals.Ruins)
local ChestC = require(RS.Shared.Config.ChestConfig)
local L = require(RS.Shared.Modules.Locale)

local Map = {}
local MAT = Enum.Material
local CELL = 32 -- 자리 겹침 검사용 격자 크기

local function flat(x, z)
	return Vector3.new(x, 0, z)
end

-- 폴더만 만든다. 로비 전용 서버는 원정 맵 없이 이것만 (클라이언트가 같은 자리에서 펫·로비를 찾는다)
function Map:BuildShell()
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
	self.RuinsFolder = U.folder(self.Map, "Ruins")
	self.Lanes, self.Slots, self.Nodes, self.WildSpawns, self.Grid, self.Marks, self.Chests = {}, {}, {}, {}, {}, {}, {}
	self.Rng = Random.new(20260928)
	return self
end

function Map:Build()
	self:BuildShell()

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
	-- 맵이 넓어서 클라이언트는 가까운 곳만 받는다 (StreamingEnabled). 기지 건물은 항상 받게 한다.
	for _, model in ipairs(self.Base:GetChildren()) do
		if model:IsA("Model") then
			pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
		end
	end
	self:BuildLanes()
	-- 시작 구조물 자리 (길목 문·벽·포탑)는 나무·자원이 들어가지 않게 비워 둔다
	for _, spec in ipairs(require(RS.Shared.Config.BuildConfig).Starter) do
		local lane = self.Lanes[spec[2]]
		self:Block(lane.Dir * spec[3] + lane.Side * spec[4], 8)
	end
	-- 유적·보물상자는 나무·자원보다 먼저 자리를 잡는다 (유적 안이 비어 있게)
	self:BuildRuins()
	self:BuildNodes()
	self:BuildWild()
	self:BuildScenery()
	self:BuildRegionProps()
	self:BuildBoundary()
	self:BuildMapGrid()
	return self
end

-- 지도에 그릴 것 기록: 위치, 반지름, 종류(MapGrid 글자)
function Map:Mark(pos, radius, class)
	table.insert(self.Marks, {pos.X, pos.Z, radius, class})
end

-- ============================================================= 지형
-- 부채꼴/초원 안의 무작위 점. zone = "Meadow" 이면 기지 둘레 고리, 아니면 그 지역 부채꼴
function Map:RandomPoint(zone, margin)
	local rng = self.Rng
	margin = margin or 0
	if zone == "Meadow" then
		local a = rng:NextNumber() * math.pi * 2
		local minR, maxR = C.BaseRadius + 10 + margin, C.MeadowRadius - margin
		local r = math.sqrt(minR * minR + rng:NextNumber() * (maxR * maxR - minR * minR))
		return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	-- 면적이 고르게 퍼지도록 반지름은 제곱근 분포
	local minR, maxR = C.MeadowRadius, C.PlayRadius - 12
	local t = (math.sqrt(minR * minR + rng:NextNumber() * (maxR * maxR - minR * minR)) - minR) / (maxR - minR)
	return Zones.point(zone, t, rng:NextNumber() * 2 - 1, C, margin)
end

function Map:Paint(zone, count, materials, minSize, maxSize)
	local T, rng = workspace.Terrain, self.Rng
	for _ = 1, count do
		local center = self:RandomPoint(zone) + Vector3.new(0, -1.2, 0)
		local mat = materials[rng:NextInteger(1, #materials)]
		for _ = 1, 3 do
			local off = Vector3.new(B.jitter(rng, maxSize * 0.6), 0, B.jitter(rng, maxSize * 0.6))
			T:FillCylinder(CFrame.new(center + off), 2.6, minSize + rng:NextNumber() * (maxSize - minSize), mat)
		end
	end
end

function Map:BuildTerrain()
	local T = workspace.Terrain
	T:Clear()
	pcall(function()
		T.Decoration = true
	end)
	-- 생존 톤: 채도를 낮춘 짙은 숲 바닥 (올리브색 풀, 낙엽 흙, 진흙), 협곡은 잿빛 바위, 늪은 검은 진흙
	T:SetMaterialColor(MAT.Grass, Color3.fromHex("#4a573a"))
	T:SetMaterialColor(MAT.LeafyGrass, Color3.fromHex("#3d4a2f"))
	T:SetMaterialColor(MAT.Ground, Color3.fromHex("#5a4a3a"))
	T:SetMaterialColor(MAT.Mud, Color3.fromHex("#3d3228"))
	T:SetMaterialColor(MAT.Sand, Color3.fromHex("#9c8f6e"))
	T:SetMaterialColor(MAT.Cobblestone, Color3.fromHex("#77746c"))
	T:SetMaterialColor(MAT.Rock, Color3.fromHex("#62666b"))
	T:SetMaterialColor(MAT.Slate, Color3.fromHex("#55585c"))
	T:SetMaterialColor(MAT.Basalt, Color3.fromHex("#3a3a3e"))
	T.WaterColor = Color3.fromHex("#2c4f5c")
	T.WaterTransparency = 0.45
	T.WaterReflectance = 0.35
	T.WaterWaveSize = 0.08
	T.WaterWaveSpeed = 6

	local size = C.GroundSize
	T:FillBlock(CFrame.new(0, -6, 0), Vector3.new(size, 12, size), MAT.Grass)
	local rng = self.Rng
	-- 테두리 언덕과 바위 절벽: 맵 끝을 자연스럽게 가린다
	local ring = math.floor(2 * math.pi * C.PlayRadius / 11)
	for i = 1, ring do
		local a = i / ring * math.pi * 2 + B.jitter(rng, 0.006)
		local r = C.PlayRadius + 26 + rng:NextNumber() * 34
		T:FillBall(Vector3.new(math.cos(a) * r, -4 + rng:NextNumber() * 8, math.sin(a) * r), 16 + rng:NextNumber() * 16,
			rng:NextNumber() < 0.25 and MAT.Rock or MAT.Grass)
	end
	for _ = 1, math.floor(ring / 3) do
		local a = rng:NextNumber() * math.pi * 2
		local r = C.PlayRadius + 55 + rng:NextNumber() * 20
		T:FillBall(Vector3.new(math.cos(a) * r, 10 + rng:NextNumber() * 12, math.sin(a) * r), 18 + rng:NextNumber() * 10, MAT.LeafyGrass)
	end
	-- 숲 바닥 얼룩: 풀밭이 한 가지 색으로 매끈하면 공원처럼 보인다 → 지역마다 다른 흙·이끼·바위 조각을 흩뿌린다
	self:Paint("Meadow", 170, {MAT.LeafyGrass, MAT.LeafyGrass, MAT.Ground, MAT.Ground, MAT.Mud}, 4, 11)
	self:Paint("Ancient", 190, {MAT.LeafyGrass, MAT.LeafyGrass, MAT.Ground, MAT.Mud}, 6, 16)
	self:Paint("Crags", 210, {MAT.Rock, MAT.Slate, MAT.Basalt, MAT.Ground, MAT.Rock}, 8, 20)
	self:Paint("Swamp", 210, {MAT.Mud, MAT.Mud, MAT.LeafyGrass, MAT.Ground}, 8, 20)
	-- 협곡: 반쯤 묻힌 큰 바위 언덕 (길을 막는 장애물 겸 경치)
	for _ = 1, 46 do
		local pos = self:RandomPoint("Crags", 20)
		local radius = 9 + rng:NextNumber() * 13
		if self:Free(pos, radius + 6) then
			T:FillBall(pos + Vector3.new(0, -radius * 0.45, 0), radius, rng:NextNumber() < 0.5 and MAT.Rock or MAT.Basalt)
			self:Block(pos, radius + 2)
			self:Mark(pos, radius * 0.85, "H")
		end
	end
	-- 기지 바닥: 흙 광장 + Core 주변 돌바닥
	T:FillCylinder(CFrame.new(0, -2, 0), 4, C.BaseRadius - 2, MAT.LeafyGrass)
	T:FillCylinder(CFrame.new(0, -2, 0), 4, 13, MAT.Cobblestone)
	-- 길목: 괴물 굴에서 Core 까지 흙길. 굴 너머로는 각 지역 깊은 곳까지 좁은 오솔길
	for _, lane in ipairs(self.Lanes) do
		local from, to = 6, C.LaneRadius + 8
		local mid = lane.Dir * ((from + to) / 2)
		T:FillBlock(CFrame.lookAt(mid + Vector3.new(0, -2, 0), mid + lane.Dir + Vector3.new(0, -2, 0)), Vector3.new(C.LaneWidth, 4, to - from), MAT.Ground)
		for t = from, to, 8 do
			self:Mark(lane.Dir * t, C.LaneWidth / 2, "P")
		end
		for n = 1, 14 do
			local t = from + (to - from) * n / 15
			local side = (n % 2 == 0 and 1 or -1) * (C.LaneWidth / 2 + 1)
			T:FillBall(lane.Dir * t + lane.Side * side + Vector3.new(0, -2.5, 0), 3, MAT.Mud)
		end
		local step = 12
		for t = C.LaneRadius + 20, C.TrailLength, step do
			local pos = self:TrailPoint(lane, t)
			T:FillCylinder(CFrame.new(pos + Vector3.new(0, -2, 0)), 4, 4.5, math.floor(t / step) % 3 == 0 and MAT.Mud or MAT.Ground)
			self:Mark(pos, 4.5, "P")
		end
	end
	-- 연못: 기지 근처 1개 + 늪 여러 개 (모래·진흙 둘레 → 파기 → 물)
	self.Ponds = {{flat(C.Pond[1], C.Pond[2]), C.Pond[3]}}
	for _ = 1, C.SwampPonds do
		for _ = 1, 20 do
			local pos = self:RandomPoint("Swamp", 30)
			local radius = 10 + rng:NextNumber() * 12
			if self:Free(pos, radius + 8) then
				table.insert(self.Ponds, {pos, radius})
				self:Block(pos, radius + 6)
				break
			end
		end
	end
	for i, pond in ipairs(self.Ponds) do
		local pos, pr = pond[1], pond[2]
		self:Mark(pos, pr, "W")
		T:FillCylinder(CFrame.new(pos.X, -2, pos.Z), 4, pr + 5, i == 1 and MAT.Sand or MAT.Mud)
		T:FillCylinder(CFrame.new(pos.X, -5, pos.Z), 10, pr, MAT.Air)
		T:FillCylinder(CFrame.new(pos.X, -6, pos.Z), 8, pr, MAT.Water)
		T:FillBlock(CFrame.new(pos.X, -11, pos.Z), Vector3.new(pr * 2 + 2, 2, pr * 2 + 2), MAT.Mud)
	end
	self:Block(self.Ponds[1][1], self.Ponds[1][2] + 6)
	-- 알파의 숲 바닥
	local grove = self:GrovePosition()
	T:FillCylinder(CFrame.new(grove.X, -2, grove.Z), 4, C.Grove.Size, MAT.LeafyGrass)
	self:Block(grove, 9)
	self:Mark(grove, C.Grove.Size * 0.55, "T")
end

function Map:GrovePosition()
	local a = math.rad(C.Grove.Angle)
	return Vector3.new(math.sin(a), 0, -math.cos(a)) * C.Grove.Radius
end

-- 오솔길: 굴 너머로 살짝 굽이치며 지역 깊은 곳까지
function Map:TrailPoint(lane, t)
	local wobble = math.sin(t / 60 + lane.Id * 1.3) * 18
	return lane.Dir * t + lane.Side * wobble
end

-- 자리 겹침 검사: 격자 칸마다 막힌 원 목록을 둔다 (자리 수천 개에서도 빠르게)
function Map:Block(pos, radius)
	local entry = {pos, radius}
	for cx = math.floor((pos.X - radius) / CELL), math.floor((pos.X + radius) / CELL) do
		for cz = math.floor((pos.Z - radius) / CELL), math.floor((pos.Z + radius) / CELL) do
			local key = cx * 4096 + cz
			local list = self.Grid[key]
			if not list then
				list = {}
				self.Grid[key] = list
			end
			table.insert(list, entry)
		end
	end
end

function Map:Free(pos, radius)
	local r = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
	if r < C.BaseRadius + 7 or r > C.PlayRadius + 4 then
		return false
	end
	for _, lane in ipairs(self.Lanes) do
		local t = pos:Dot(lane.Dir)
		if t > 0 and t < C.LaneRadius + 16 and math.abs(pos:Dot(lane.Side)) < C.LaneWidth / 2 + 5 + radius then
			return false
		end
		if t >= C.LaneRadius + 16 and t < C.TrailLength + 10 then
			if (self:TrailPoint(lane, t) - flat(pos.X, pos.Z)).Magnitude < 7 + radius then
				return false
			end
		end
	end
	local seen = {}
	for cx = math.floor((pos.X - radius) / CELL), math.floor((pos.X + radius) / CELL) do
		for cz = math.floor((pos.Z - radius) / CELL), math.floor((pos.Z + radius) / CELL) do
			for _, b in ipairs(self.Grid[cx * 4096 + cz] or {}) do
				if not seen[b] then
					seen[b] = true
					if (b[1] - pos).Magnitude < b[2] + radius then
						return false
					end
				end
			end
		end
	end
	return true
end

-- ============================================================= 기지
function Map:BuildBase()
	local base = self.Base
	local _, coreHit = S.core(base, CFrame.new())
	self.Core = coreHit
	self.Core.Name = "Core"
	self:Mark(Vector3.zero, C.BaseRadius, "B")
	self:Mark(Vector3.zero, 5, "Q")
	-- 창고·펫 우리는 v2 에서 없앴다 (가방으로 어디서나 쓰고, 잡은 펫은 바로 등록). 위치 기준 파트만 남긴다.
	local function marker(name, spot)
		local p = U.part(base, name, Vector3.new(1, 1, 1), Vector3.new(spot[1], 0.5, spot[3]))
		p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch = 1, false, false, false
		return p
	end
	self.Warehouse = marker("Warehouse", C.Warehouse)
	self.Cage = marker("Cage", C.Cage)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.Position = "ExpeditionSpawn", Vector3.new(6, 1, 6), Vector3.new(table.unpack(C.Spawn))
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Transparency, spawn.CanCollide = true, true, 3, 1, false
	spawn.Parent = base
	self.Spawn = spawn
	B.cyl(base, 0.3, 7, CFrame.new(spawn.Position.X, 0.15, spawn.Position.Z), "#7d776c", MAT.Slate, true)
	B.cyl(base, 0.32, 5.4, CFrame.new(spawn.Position.X, 0.17, spawn.Position.Z), "#8ff5e8", MAT.Neon, true, {Transparency = 0.8})

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
		B.solid(B.block(fire, Vector3.new(1.2, 0.8, 1), fpos * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(0, 0.4, -1.6), "#8b8f94", MAT.Slate))
	end
	for i = 0, 2 do
		B.cyl(fire, 2.6, 0.6, fpos * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(12)), "#6e4a2c", MAT.Wood)
	end
	local flame = B.ball(fire, 1, fpos * CFrame.new(0, 1, 0), "#ffb347", MAT.Neon, {Transparency = 0.3})
	local fx = Instance.new("Fire")
	fx.Size, fx.Heat = 4, 9
	fx.Parent = flame
	B.light(flame, "PointLight", {Range = 20, Brightness = 1.8, Color = Color3.fromHex("#ffa860"), Shadows = true})
	flame.Name = "Campfire"
	self.Campfire = flame
	-- 요리 메뉴는 없다: 가까이 서 있으면 버섯이 저절로 구워진다 (CraftingService:AutoCook). 바닥에 따뜻한 원 + 머리 위 안내
	B.cyl(fire, 0.06, G.CookRadius * 2, fpos * CFrame.new(0, 0.08, 0), "#ffb347", MAT.Neon, true, {Transparency = 0.86, CanQuery = false})
	local sign = Instance.new("BillboardGui")
	sign.Name, sign.Size, sign.StudsOffset, sign.MaxDistance, sign.LightInfluence = "CookSign", UDim2.fromOffset(220, 40), Vector3.new(0, 5, 0), 60, 0
	sign.Parent = flame
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.TextScaled, label.Font = UDim2.fromScale(1, 1), 1, true, Enum.Font.FredokaOne
	label.TextColor3, label.TextStrokeTransparency = Color3.fromHex("#ffe2a8"), 0.3
	L.tag(label, "Text", L.M("sign.autoCook"))
	label.Parent = sign
	for i, off in ipairs({Vector3.new(-3.6, 0, 0.5), Vector3.new(3.4, 0, -0.6)}) do
		B.solid(B.cyl(fire, 3.4, 1, fpos * CFrame.new(off) * CFrame.Angles(0, math.rad(80 + i * 20), 0) + Vector3.new(0, 0.5, 0), "#8a5d36", MAT.Wood))
	end
end

-- ============================================================= 길목, 굴
function Map:BuildLanes()
	for _, lane in ipairs(self.Lanes) do
		local folder = self.LanesFolder["Lane" .. lane.Id]
		local mouth = lane.Dir * (C.LaneRadius + 6)
		Props.burrow(folder, CFrame.lookAt(mouth, Vector3.zero), self.Rng)
		self:Block(mouth, 14)
		self:Mark(mouth, 7, "U")
		-- 길 표지 돌 (길목 번호)
		local marker = lane.Dir * 46 + lane.Side * (C.LaneWidth / 2 + 2.5)
		local stone = B.solid(B.block(folder, Vector3.new(1.6, 2.6, 0.9), CFrame.lookAt(marker, marker - lane.Dir) + Vector3.new(0, 1.3, 0), "#6f7376", MAT.Slate))
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.CanvasSize, gui.LightInfluence = Enum.NormalId.Front, Vector2.new(100, 160), 1
		gui.Parent = stone
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency, text.TextScaled = UDim2.fromScale(1, 1), 1, true
		text.Font, text.Text, text.TextColor3 = Enum.Font.FredokaOne, tostring(lane.Id), Color3.fromHex("#2a2530")
		text.Parent = gui
	end
end

-- ============================================================= 채집 노드
local NODE_BUILDERS = {
	Wood = function(parent, at, rng)
		local model, width = Props.tree(parent, at, rng, 0.9, "WoodTree")
		return model, Vector3.new(3.4, 12, 3.4), width
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
	Mushroom = function(parent, at, rng)
		return Props.mushroomPatch(parent, at, rng, 1.1), Vector3.new(4, 3, 4)
	end,
	Crystal = function(parent, at, rng)
		return Props.crystals(parent, at, rng, 1.0), Vector3.new(5, 6, 5)
	end,
}

local NODE_MARK = {Wood = "T", Stone = "R", Scrap = "R", Crystal = "Q"}

-- 채집 노드. model 을 주면(숲의 나무·고사목) 그 모델을 그대로 노드로 쓴다 → 맵의 모든 나무를 도끼로 벨 수 있다.
-- 나무는 보이지 않는 줄기 기둥(Props.trunk)이 몸을 막고, 채집용 Hitbox 는 부딪히지 않는다.
function Map:AddNode(kind, pos, model, width)
	local spec = R.Types[kind]
	local n = #self.Nodes + 1
	local size
	local placed = model ~= nil
	if model then
		local w = math.max(3.4, (width or 1.6) * 2)
		size = Vector3.new(w, 12, w)
	else
		model, size, width = NODE_BUILDERS[kind](self.NodesFolder, CFrame.new(pos), self.Rng)
	end
	model.Name = kind .. n
	local hit = B.hitbox(model, size, CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)), kind ~= "Wood")
	hit.Name = kind .. n
	hit:SetAttribute("ResourceType", kind)
	hit:SetAttribute("MaxHealth", spec.HP)
	hit:SetAttribute("CurrentHealth", spec.HP)
	hit:SetAttribute("RespawnTime", spec.Respawn)
	hit:SetAttribute("Zone", Zones.id(pos, C))
	model.PrimaryPart = hit
	table.insert(self.Nodes, {Part = hit, Model = model, Kind = kind, Home = CFrame.new(pos), Width = width})
	if not placed then
		self:Block(pos, 7)
		if NODE_MARK[kind] then
			self:Mark(pos, 2, NODE_MARK[kind])
		end
	end
end

function Map:BuildNodes()
	for _, zone in ipairs(C.ZoneOrder) do
		for _, kind in ipairs(R.Order) do
			local want = (C.Nodes[zone] or {})[kind] or 0
			local placed, tries = 0, 0
			while placed < want and tries < want * 40 do
				tries = tries + 1
				local pos = self:RandomPoint(zone, 8)
				if self:Free(pos, 7) then
					self:AddNode(kind, pos)
					placed = placed + 1
				end
			end
		end
	end
end

-- ============================================================= 야생 펫 자리
-- 서버 CaptureService 가 이 자리에 야생 펫을 두고, 잡히면 같은 자리에 새로 나타나게 한다.
function Map:BuildWild()
	local rng = self.Rng
	for _, spec in ipairs(C.StarterWild) do
		local pos = flat(spec[3], spec[4])
		table.insert(self.WildSpawns, {SpeciesId = spec[1], MinLevel = spec[2], MaxLevel = spec[2], Pos = pos, Zone = "Meadow"})
		self:Block(pos, 8)
	end
	for _, zone in ipairs(C.ZoneOrder) do
		for _, entry in ipairs(C.Wild[zone] or {}) do
			local species, count, minLevel, maxLevel = table.unpack(entry)
			local placed, tries = 0, 0
			while placed < count and tries < count * 60 do
				tries = tries + 1
				local pos = self:RandomPoint(zone, 16)
				-- 초원의 엠버펍·셸버브는 기지에서 조금 떨어진 곳 (첫 모슬링보다 한 단계 위)
				if (zone ~= "Meadow" or species == "Mossling" or pos.Magnitude > 120) and self:Free(pos, 10) then
					-- 멀리 갈수록 높은 레벨
					local depth = zone == "Meadow" and (pos.Magnitude / C.MeadowRadius) or Zones.depth(pos, C)
					local level = math.clamp(math.floor(minLevel + (maxLevel - minLevel) * depth + rng:NextNumber() * 0.99), minLevel, maxLevel)
					table.insert(self.WildSpawns, {SpeciesId = species, MinLevel = level, MaxLevel = level, Pos = pos, Zone = zone})
					self:Block(pos, 10)
					placed = placed + 1
				end
			end
		end
	end
	-- 알파의 숲 한가운데 브라이어혼 α
	table.insert(self.WildSpawns, {SpeciesId = "Briarhorn", MinLevel = C.Grove.Level, MaxLevel = C.Grove.Level, Pos = self:GrovePosition(), Zone = "Ancient"})
end

-- ============================================================= 숲, 소품, 연못, 알파의 숲
function Map:BuildScenery()
	local decor, rng = self.DecorFolder, self.Rng
	-- 바깥 숲 벽: 키 큰 가문비나무 세 줄. 어디서 봐도 빽빽한 숲에 갇힌 느낌을 준다. 뒷줄은 가벼운 메쉬를 쓴다.
	for row, spec in ipairs({{2, 12, 11}, {17, 18, 13}, {36, 26, 16}}) do
		local inner, spread, spacing = table.unpack(spec)
		local count = math.floor(2 * math.pi * (C.PlayRadius + inner) / spacing)
		for i = 1, count do
			local a = i / count * math.pi * 2 + B.jitter(rng, 0.004)
			local r = C.PlayRadius + inner + rng:NextNumber() * spread
			-- 첫 줄은 경계 벽 안쪽이라 줄기에 부딪혀야 한다 (뒷줄은 벽 너머라 필요 없음)
			Props.tallPine(decor, CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), rng, 1.0 + rng:NextNumber() * 0.45 + row * 0.08, row == 1, row > 1)
		end
	end
	-- 흩뿌림 도우미: 지역 안에서 길목·기지·자원·다른 소품을 피해 놓는다
	local function scatter(zone, n, radius, build)
		local placed, tries = 0, 0
		while placed < n and tries < n * 25 do
			tries = tries + 1
			local pos = self:RandomPoint(zone)
			if self:Free(pos, radius) then
				build(CFrame.new(pos), pos)
				self:Block(pos, radius)
				placed = placed + 1
			end
		end
	end
	-- 나무 무리: 가문비나무 여러 그루가 모여 선 숲. 발밑엔 고사리, 그루터기, 쓰러진 통나무
	local function grove(zone, n, minTrees, maxTrees, scaleMin, scaleSpan)
		scatter(zone, n, 11, function(_, center)
			for _ = 1, rng:NextInteger(minTrees, maxTrees) do
				local a = rng:NextNumber() * math.pi * 2
				local pos = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (2 + rng:NextNumber() * 7)
				local model, width = Props.tallPine(self.NodesFolder, CFrame.new(pos), rng, scaleMin + rng:NextNumber() * scaleSpan, true)
				self:AddNode("Wood", pos, model, width)
				self:Mark(pos, 2, "T")
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
				self:Mark(spot.Position, 2, "R")
			end
		end)
	end
	local function props(zone, counts)
		scatter(zone, counts.Dead or 0, 4, function(at, pos)
			local model, width = Props.deadTree(self.NodesFolder, at, rng, 0.8 + rng:NextNumber() * 0.5)
			self:AddNode("Wood", pos, model, width)
			self:Mark(pos, 2, "D")
		end)
		scatter(zone, counts.Log or 0, 5, function(at) Props.log(decor, at, rng, 0.8 + rng:NextNumber() * 0.4) end)
		scatter(zone, counts.Stump or 0, 3, function(at) Props.stump(decor, at, rng, 0.8 + rng:NextNumber() * 0.4) end)
		scatter(zone, counts.Rock or 0, 3, function(at, pos)
			local scale = (counts.RockScale or 0.4) + rng:NextNumber() * 0.7
			Props.rock(decor, at, rng, scale)
			if scale >= 0.7 then
				self:Mark(pos, 2, "R")
			end
		end)
		scatter(zone, counts.Fern or 0, 1.8, function(at) Props.fern(decor, at, rng, 0.7 + rng:NextNumber() * 0.5) end)
		scatter(zone, counts.Glow or 0, 1.5, function(at) Props.mushrooms(decor, at, rng) end)
		scatter(zone, counts.Reeds or 0, 2, function(at) Props.reeds(decor, at, rng, 0.7 + rng:NextNumber() * 0.4) end)
	end
	-- 초원: 탁 트인 풀밭에 작은 나무 무리
	grove("Meadow", 30, 3, 6, 0.62, 0.3)
	props("Meadow", {Dead = 16, Log = 14, Stump = 18, Rock = 28, Fern = 110, Glow = 26})
	-- 고목의 숲: 가장 빽빽하고 어두운 숲, 발밑에 빛나는 버섯
	grove("Ancient", 110, 4, 7, 0.8, 0.35)
	props("Ancient", {Dead = 15, Log = 40, Stump = 40, Rock = 30, Fern = 240, Glow = 60})
	-- 잿빛 바위 협곡: 나무가 드물고 바위와 죽은 나무
	grove("Crags", 20, 2, 4, 0.6, 0.3)
	props("Crags", {Dead = 45, Log = 10, Stump = 16, Rock = 150, RockScale = 0.6, Fern = 30})
	-- 안개 늪: 앙상한 나무, 갈대, 쓰러진 나무, 빛나는 버섯
	grove("Swamp", 40, 2, 4, 0.55, 0.25)
	props("Swamp", {Dead = 70, Log = 45, Stump = 35, Rock = 22, Fern = 70, Glow = 50, Reeds = 110})

	-- 연못 가장자리: 갈대, 바위, 수련 잎
	for n, pond in ipairs(self.Ponds) do
		local center, pr = pond[1], pond[2]
		local px, pz = center.X, center.Z
		for i = 1, 9 do
			local a = i / 9 * math.pi * 2 + B.jitter(rng, 0.2)
			local pos = Vector3.new(px + math.cos(a) * (pr + 2.5), 0, pz + math.sin(a) * (pr + 2.5))
			if i % 3 == 0 then
				Props.rock(decor, CFrame.new(pos), rng, 0.45)
			else
				Props.reeds(decor, CFrame.new(pos), rng, 0.7)
			end
		end
		for i = 1, n == 1 and 6 or 3 do
			local a = rng:NextNumber() * math.pi * 2
			local r = rng:NextNumber() * (pr - 3)
			local pad = B.cyl(decor, 0.15, 2.4 + rng:NextNumber(), CFrame.new(px + math.cos(a) * r, -1.95, pz + math.sin(a) * r), "#3f6a3c", MAT.SmoothPlastic, true)
			pad.Name = "LilyPad"
			if i % 2 == 0 then
				B.ball(decor, 0.5, pad.Position + Vector3.new(0.3, 0.2, 0), "#8fb8ff", MAT.Neon)
			end
		end
	end

	-- 알파의 숲: 오래된 거대 나무 + 선돌 + 빛나는 버섯
	local center = self:GrovePosition()
	local gx, gz, gr = center.X, center.Z, C.Grove.Size
	local groveModel = B.model(decor, "AlphaGrove")
	local toward = -center.Unit * 14
	Props.tree(groveModel, CFrame.new(gx - toward.X, 0, gz - toward.Z), rng, 2.1, "AncientTree")
	for i = 1, 7 do
		local a = math.rad(i * (360 / 7) + 10)
		local pos = Vector3.new(gx + math.cos(a) * (gr - 3), 0, gz + math.sin(a) * (gr - 3))
		if (pos - Vector3.new(gx - toward.X, 0, gz - toward.Z)).Magnitude > 7 then
			local stone = B.solid(B.block(groveModel, Vector3.new(2, 5 + rng:NextNumber() * 2, 1.4), CFrame.lookAt(pos, Vector3.new(gx, 0, gz)) + Vector3.new(0, 2.6, 0), "#a3a8ad", MAT.Slate))
			B.block(groveModel, Vector3.new(0.3, 2, 0.1), stone.CFrame * CFrame.new(0, 0.5, -0.72), "#b6ff8a", MAT.Neon)
		end
	end
	for _ = 1, 10 do
		local a = rng:NextNumber() * math.pi * 2
		local r = 4 + rng:NextNumber() * (gr - 6)
		Props.mushrooms(groveModel, CFrame.new(gx + math.cos(a) * r, 0, gz + math.sin(a) * r), rng)
	end
	B.light(B.block(groveModel, Vector3.new(1, 1, 1), CFrame.new(gx, 6, gz), "#ffffff", MAT.SmoothPlastic, {Transparency = 1}), "PointLight",
		{Range = 26, Brightness = 1.2, Color = Color3.fromHex("#c9ff9a"), Shadows = false})
	-- 오솔길 표지: 굴 너머 각 지역 입구에 이정표 (지역 이름)
	for _, lane in ipairs(self.Lanes) do
		local zoneId = Zones.id(lane.Dir * (C.MeadowRadius + 30), C)
		local zone = C.Zones[zoneId]
		local at = self:TrailPoint(lane, C.MeadowRadius + 24) + lane.Side * 9
		local post = B.solid(B.block(decor, Vector3.new(0.6, 5, 0.6), CFrame.new(at + Vector3.new(0, 2.5, 0)), "#5e4b3b", MAT.Wood))
		local sign = B.block(decor, Vector3.new(5.2, 1.6, 0.3), CFrame.lookAt(at + Vector3.new(0, 4.4, 0), at + Vector3.new(0, 4.4, 0) - lane.Dir), "#6b5236", MAT.WoodPlanks)
		post.Name = "ZoneSign"
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.CanvasSize, gui.LightInfluence = Enum.NormalId.Back, Vector2.new(260, 80), 1
		gui.Parent = sign
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency, text.TextScaled = UDim2.fromScale(1, 1), 1, true
		text.Font, text.TextColor3 = Enum.Font.FredokaOne, Color3.fromHex("#f2e6cf")
		L.tag(text, "Text", L.C(zone.Icon .. " ", L.M("zone." .. zoneId)))
		text.Parent = gui
	end
end

-- ============================================================= 유적 · 보물상자 (v2)
-- 스폰 근처 빛기둥 보물상자 작은 유적 1곳 + 지역마다 유적 2~3곳 (무너진 신전·아치·반쯤 잠긴 탑·선돌 원). 가운데에 보물상자.
-- 유적의 앞(-Z)은 기지 쪽을 본다 (기지에서 걸어오면 입구가 보이게).
local FLOOR = {
	Meadow = {MAT.Cobblestone, MAT.Cobblestone, MAT.Ground},
	Crags = {MAT.Slate, MAT.Basalt, MAT.Cobblestone},
	Ancient = {MAT.Cobblestone, MAT.LeafyGrass, MAT.Ground},
	Swamp = {MAT.Mud, MAT.Cobblestone, MAT.Mud},
}

function Map:AddChest(at, tier, zone, perPlayer)
	local color = ChestC.Colors[tier]
	local model, hit = Ruins.chest(self.RuinsFolder, at, tier, color, self.Rng)
	local id = "Chest" .. (#self.Chests + 1)
	model.Name = id
	model:SetAttribute("PerPlayer", perPlayer == true)
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	table.insert(self.Chests, {Id = id, Model = model, Hit = hit, Tier = tier, PerPlayer = perPlayer == true, Pos = at.Position, Zone = zone})
	self:Mark(at.Position, 3, "J")
	return model
end

-- 유적 바닥: 깨진 돌바닥 조각을 여러 개 겹쳐 칠한다
function Map:RuinFloor(center, radius, zone)
	local T, rng = workspace.Terrain, self.Rng
	local mats = FLOOR[zone] or FLOOR.Meadow
	T:FillCylinder(CFrame.new(center + Vector3.new(0, -2, 0)), 4, radius * 0.7, mats[1])
	for _ = 1, 9 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber() * radius * 0.8
		T:FillCylinder(CFrame.new(center + Vector3.new(math.cos(a) * r, -2, math.sin(a) * r)), 4, 2 + rng:NextNumber() * radius * 0.35,
			mats[rng:NextInteger(1, #mats)])
	end
end

-- 유적 한 곳. kind = Temple · Arch · Tower · Circle, frame = 가운데 바닥 (-Z = 기지 쪽)
function Map:BuildRuinSite(kind, frame, zone, tier, perPlayer)
	local rng, folder = self.Rng, self.RuinsFolder
	local function put(name, x, z, yawDeg, scale, light, sink)
		return Ruins.build(folder, name, frame * CFrame.new(x, -(sink or 0), z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0), rng, scale, light)
	end
	local chestAt = frame * CFrame.new(0, 0, -1)
	if kind == "Temple" then
		for k = 0, 5 do
			local a = math.rad(k * 60 + 30)
			local x, z = math.cos(a) * 10, math.sin(a) * 10
			local roll = rng:NextNumber()
			if roll < 0.4 then
				put("RuinPillar", x, z, rng:NextNumber() * 90)
			elseif roll < 0.8 then
				put("RuinPillarBroken", x, z, rng:NextNumber() * 90)
			else
				put("RuinPillarFallen", x * 1.25, z * 1.25, math.deg(a) + 90 + B.jitter(rng, 20))
			end
		end
		put("RuinAltar", 0, 5, 0)
		put("RuinStatueHead", 9, 9, -140 + B.jitter(rng, 30), 1 + rng:NextNumber() * 0.25, false, 1.2)
	elseif kind == "Arch" then
		put("RuinArch", 0, -7, 0)
		put("RuinWall", -9, 1, 70)
		put("RuinWall", 9.5, 2, -64, 0.9)
		put("RuinObelisk", 0, 8, 0, 1, true)
		put("RuinPillarBroken", -6, -12, 20)
		put("RuinPillarBroken", 6, -12, 50)
		chestAt = frame * CFrame.new(0, 0, 1)
	elseif kind == "Tower" then
		-- 늪의 탑은 반쯤 잠겨 있다
		local sunk = zone == "Swamp" and 4 or 0
		put("RuinTower", 0, 7, rng:NextNumber() * 360, 1, false, sunk)
		put("RuinWall", -9, 0, 80)
		put("RuinWall", 8, -4, -30, 0.85)
		put("RuinStatueHead", -7, -9, 30, 0.9, false, 1.5)
		put("RuinPillarFallen", 9, 7, 40)
		chestAt = frame * CFrame.new(0, 0, -3)
	else -- Circle: 선돌 원
		for k = 0, 8 do
			local a = k / 9 * math.pi * 2
			if k ~= 4 or rng:NextNumber() < 0.5 then
				local stoneAt = frame * CFrame.new(math.cos(a) * 9, 0, math.sin(a) * 9)
				Ruins.build(folder, "StandingStone", CFrame.lookAt(stoneAt.Position, frame.Position) * CFrame.Angles(0, math.pi, 0), rng, 0.9 + rng:NextNumber() * 0.35)
			end
		end
		put("RuinAltar", 0, 3, 0, 0.7)
		chestAt = frame * CFrame.new(0, 0, -3)
	end
	self:AddChest(chestAt, tier, zone, perPlayer)
end

function Map:BuildRuins()
	-- ① 스폰 근처 첫 보물상자: 기지에서 북동쪽으로 조금 걸어가면 빛기둥이 보인다 (대원마다 한 번씩)
	local a = math.rad(62)
	local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
	local pos = dir * ChestC.Starter.Distance
	local frame = CFrame.lookAt(pos, Vector3.zero)
	self:RuinFloor(pos, 10, "Meadow")
	local rng, folder = self.Rng, self.RuinsFolder
	Ruins.build(folder, "RuinPillarBroken", frame * CFrame.new(-5.5, 0, 3), rng)
	Ruins.build(folder, "RuinPillar", frame * CFrame.new(5, 0, 3.5), rng, 0.8)
	Ruins.build(folder, "RuinPillarFallen", frame * CFrame.new(7, 0, -4) * CFrame.Angles(0, math.rad(60), 0), rng, 0.8)
	Ruins.build(folder, "StandingStone", frame * CFrame.new(-6, 0, -5) * CFrame.Angles(0, math.rad(20), 0), rng, 0.8)
	self.StarterChest = self:AddChest(frame, ChestC.Starter.Tier, "Meadow", true)
	self:Block(pos, 13)
	self:Mark(pos, 8, "J")
	-- ② 지역 유적: 지역 안 무작위 자리. 가장 멀리 있는 유적의 상자는 한 단계 좋은 등급
	for _, zone in ipairs(C.ZoneOrder) do
		local spec = ChestC.Ruins[zone]
		local sites = {}
		for i = 1, spec.Count do
			for _ = 1, 80 do
				local p = self:RandomPoint(zone, 30)
				local okDistance = zone ~= "Meadow" or (p.Magnitude > 110 and (p - pos).Magnitude > 80)
				if okDistance and self:Free(p, 24) then
					local apart = true
					for _, other in ipairs(sites) do
						if (other.Pos - p).Magnitude < 140 then apart = false end
					end
					if apart then
						table.insert(sites, {Pos = p, Kind = spec.Kinds[(i - 1) % #spec.Kinds + 1]})
						self:Block(p, 24)
						break
					end
				end
			end
		end
		local far = 0
		for _, site in ipairs(sites) do far = math.max(far, site.Pos.Magnitude) end
		for _, site in ipairs(sites) do
			local tier = (site.Pos.Magnitude >= far and spec.Far) or spec.Tier
			self:RuinFloor(site.Pos, 16, zone)
			self:BuildRuinSite(site.Kind, CFrame.lookAt(site.Pos, Vector3.zero), zone, tier, false)
			self:Mark(site.Pos, 12, "J")
		end
	end
end

-- ============================================================= 지역 소품 (v2)
-- 협곡: 흑요석 첨탑·용암 균열·수정 무리 / 고목의 숲: 거대 버섯·거대 뿌리·빛나는 식물 / 늪: 이끼 늘어진 나무·수련·반딧불 / 초원: 선돌 원
function Map:Scatter(zone, n, radius, build)
	local placed, tries = 0, 0
	while placed < n and tries < n * 25 do
		tries = tries + 1
		local pos = self:RandomPoint(zone)
		if self:Free(pos, radius) then
			build(CFrame.new(pos) * CFrame.Angles(0, self.Rng:NextNumber() * math.pi * 2, 0), pos, placed + 1)
			self:Block(pos, radius)
			placed = placed + 1
		end
	end
	return placed
end

function Map:BuildRegionProps()
	local folder, rng = U.folder(self.Map, "RegionProps"), self.Rng
	-- 🌋 잿빛 바위 협곡
	self:Scatter("Crags", 36, 5, function(at, pos)
		Ruins.build(folder, "ObsidianSpire", at, rng, 0.7 + rng:NextNumber() * 0.7)
		self:Mark(pos, 3, "H")
	end)
	self:Scatter("Crags", 28, 3.5, function(at, _, i)
		Ruins.build(folder, "CrystalCluster", at, rng, 0.8 + rng:NextNumber() * 0.5, i % 3 == 0)
	end)
	self:Scatter("Crags", 24, 6, function(at, _, i)
		-- 용암 균열: 땅에 붙은 주황 빛 갈라진 틈 (지그재그 조각) + 가끔 빛
		local crack = B.model(folder, "LavaCrack")
		local p = at
		for _ = 1, 5 do
			local len = 1.6 + rng:NextNumber() * 2.4
			B.block(crack, Vector3.new(0.5 + rng:NextNumber() * 0.4, 0.12, len), p * CFrame.new(0, 0.04, -len / 2), "#ff7a2a", MAT.Neon)
			B.block(crack, Vector3.new(1.4, 0.1, len + 0.3), p * CFrame.new(0, 0.02, -len / 2), "#2a2422", MAT.Basalt)
			p = p * CFrame.new(0, 0, -len) * CFrame.Angles(0, math.rad(B.jitter(rng, 45)), 0)
		end
		if i % 3 == 0 then
			B.light(B.block(crack, Vector3.new(0.2, 0.2, 0.2), at * CFrame.new(0, 1, -4), "#ffffff", MAT.SmoothPlastic, {Transparency = 1}), "PointLight",
				{Range = 14, Brightness = 1.3, Color = Color3.fromHex("#ff7a2a"), Shadows = false})
		end
	end)
	-- 🌲 고목의 숲
	self:Scatter("Ancient", 22, 8, function(at, pos)
		Ruins.build(folder, "GiantMushroom", at, rng, 0.75 + rng:NextNumber() * 0.5, true)
		self:Mark(pos, 5, "T")
	end)
	self:Scatter("Ancient", 24, 9, function(at)
		Ruins.build(folder, "GiantRoot", at, rng, 0.8 + rng:NextNumber() * 0.5)
	end)
	self:Scatter("Ancient", 60, 2, function(at, _, i)
		Ruins.build(folder, "GlowPlant", at, rng, 0.8 + rng:NextNumber() * 0.6, i % 5 == 0)
	end)
	-- 💧 안개 늪: 이끼 늘어진 나무, 반딧불, 연못마다 수련 더
	self:Scatter("Swamp", 42, 4, function(at, pos)
		Ruins.build(folder, "MossTree", at, rng, 0.8 + rng:NextNumber() * 0.5)
		self:Mark(pos, 2, "D")
	end)
	self:Scatter("Swamp", 28, 3, function(at)
		local holder = B.new("Part", folder, {Name = "Fireflies", Size = Vector3.new(10, 4, 10), CFrame = at * CFrame.new(0, 3, 0), Transparency = 1})
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromHex("#e9ff8a"))
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0)})
		e.Rate, e.Lifetime, e.Speed = 4, NumberRange.new(3, 6), NumberRange.new(0.3, 1)
		e.LightEmission, e.Drag, e.RotSpeed = 1, 1, NumberRange.new(-40, 40)
		e.SpreadAngle, e.Acceleration = Vector2.new(180, 180), Vector3.new(0, 0.2, 0)
		e.Parent = holder
	end)
	for n, pond in ipairs(self.Ponds) do
		if n > 1 then
			local center, pr = pond[1], pond[2]
			for _ = 1, 5 do
				local a, r = rng:NextNumber() * math.pi * 2, rng:NextNumber() * (pr - 2)
				local pad = B.cyl(folder, 0.15, 1.8 + rng:NextNumber() * 1.4, CFrame.new(center.X + math.cos(a) * r, -1.95, center.Z + math.sin(a) * r),
					"#4f7a3c", MAT.SmoothPlastic, true)
				pad.Name = "LilyPad"
				if rng:NextNumber() < 0.4 then
					B.ball(folder, 0.6, pad.Position + Vector3.new(0.2, 0.25, 0), "#ffd1e8", MAT.SmoothPlastic)
				end
			end
		end
	end
	-- 🌿 초원: 작은 선돌 원 (가운데에 빛나는 버섯)
	self:Scatter("Meadow", 5, 10, function(at, pos)
		local count = rng:NextInteger(6, 8)
		for k = 1, count do
			local a = k / count * math.pi * 2
			local stoneAt = at * CFrame.new(math.cos(a) * 6.5, 0, math.sin(a) * 6.5)
			Ruins.build(folder, "StandingStone", CFrame.lookAt(stoneAt.Position, pos) * CFrame.Angles(0, math.pi, 0), rng, 0.6 + rng:NextNumber() * 0.3)
		end
		Props.mushrooms(folder, at, rng)
		self:Mark(pos, 6, "J")
	end)
end

-- ============================================================= 경계
-- 숲 벽 첫 줄 바로 뒤를 두르는 보이지 않는 벽. 언덕을 타고 넘거나 나무 사이로 빠져나가 맵 밖으로 떨어지지 않게 한다.
function Map:BuildBoundary()
	local folder = U.folder(self.Map, "Boundary")
	local radius = C.WallRadius
	local count = math.ceil(2 * math.pi * radius / 24)
	local length = 2 * math.pi * radius / count + 2
	for i = 1, count do
		local a = i / count * math.pi * 2
		local pos = Vector3.new(math.cos(a) * radius, 60, math.sin(a) * radius)
		B.new("Part", folder, {Name = "Wall", Size = Vector3.new(length, 220, 4), CFrame = CFrame.lookAt(pos, Vector3.new(0, 60, 0)),
			Transparency = 1, CanCollide = true, CastShadow = false})
	end
	self.GroundRay = RaycastParams.new()
	self.GroundRay.FilterType = Enum.RaycastFilterType.Include
	self.GroundRay.FilterDescendantsInstances = {workspace.Terrain}
end

-- 안전장치: 벽을 뚫었거나(순간이동·끼임) 떨어진 캐릭터를 맵 안으로 되돌린다 (서버 틱마다)
function Map:Contain(player)
	local root = U.aliveRoot(player)
	if not root then
		return false
	end
	local p = root.Position
	local r = math.sqrt(p.X * p.X + p.Z * p.Z)
	if p.Y > -60 and r <= C.WallRadius + 6 then
		return false
	end
	local back
	if p.Y <= -60 or r < 1 then
		back = self.Spawn.Position + Vector3.new(0, 4, 0)
	else
		local flatBack = Vector3.new(p.X, 0, p.Z) / r * (C.WallRadius - 24)
		local hit = workspace:Raycast(flatBack + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), self.GroundRay)
		back = flatBack + Vector3.new(0, (hit and hit.Position.Y or 0) + 4, 0)
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.Parent:PivotTo(CFrame.new(back))
	return true
end

-- ============================================================= 지도 격자
-- 미니맵(클라이언트 MapController)이 그릴 격자. 한 칸 = MapCell stud, 한 글자 = 그 칸의 모습. 북쪽(-Z)이 첫 줄.
--  G 초원 · A 고목의 숲 바닥 · C 협곡 · S 늪 · O 경계 숲 · N 맵 밖 (안 그림)
--  H 바위 언덕 · D 고사목 · R 바위 · T 나무 · Q 수정/Core · P 길 · W 물 · B 기지 바닥 · U 괴물 굴 · K 건물 · X 말뚝 울타리 · J 유적
local GROUND = {Meadow = "G", Ancient = "A", Crags = "C", Swamp = "S"}
local PRIORITY = {N = 0, G = 0, A = 0, C = 0, S = 0, O = 0, H = 1, D = 2, R = 3, T = 4, Q = 5, P = 6, W = 7, B = 8, U = 9, K = 10, X = 11, J = 12}

function Map:BuildMapGrid()
	local cell = C.MapCell
	local n = math.ceil((C.WallRadius + 24) * 2 / cell)
	local origin = -n * cell / 2
	local limit = n * cell / 2
	local grid, prio = table.create(n * n, "N"), table.create(n * n, 0)
	local function center(i)
		return origin + (i + 0.5) * cell
	end
	for iz = 0, n - 1 do
		for ix = 0, n - 1 do
			local cx, cz = center(ix), center(iz)
			local r = math.sqrt(cx * cx + cz * cz)
			local class = "N"
			if r <= limit then
				class = r > C.PlayRadius + 2 and "O" or GROUND[Zones.id(Vector3.new(cx, 0, cz), C)]
			end
			grid[iz * n + ix + 1] = class
		end
	end
	local function stamp(ix, iz, class)
		if ix < 0 or iz < 0 or ix >= n or iz >= n then
			return
		end
		local i = iz * n + ix + 1
		if grid[i] ~= "N" and PRIORITY[class] >= prio[i] then
			grid[i], prio[i] = class, PRIORITY[class]
		end
	end
	for _, mark in ipairs(self.Marks) do
		local x, z, r, class = mark[1], mark[2], mark[3], mark[4]
		if r < cell * 0.5 then
			-- 작은 것(나무 한 그루·길 한 토막)은 그 점이 든 칸 하나
			stamp(math.floor((x - origin) / cell), math.floor((z - origin) / cell), class)
		else
			local reach = r + cell * 0.3
			for iz = math.floor((z - reach - origin) / cell), math.floor((z + reach - origin) / cell) do
				for ix = math.floor((x - reach - origin) / cell), math.floor((x + reach - origin) / cell) do
					local dx, dz = center(ix) - x, center(iz) - z
					if dx * dx + dz * dz <= reach * reach then
						stamp(ix, iz, class)
					end
				end
			end
		end
	end
	local old = RS:FindFirstChild("MapGrid")
	if old then
		old:Destroy()
	end
	local value = Instance.new("StringValue")
	value.Name = "MapGrid"
	value.Value = table.concat(grid)
	value:SetAttribute("Cell", cell)
	value:SetAttribute("Size", n)
	value:SetAttribute("Origin", origin)
	value.Parent = RS
	self.MapGrid = value
	return value
end

return Map
