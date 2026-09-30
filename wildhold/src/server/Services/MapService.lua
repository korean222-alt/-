-- 원정 맵 생성: 지형(Terrain) + 기지(말뚝 울타리, Core, 창고, 제작대, 모닥불, 펫 우리) + 3 길목 + 지역(초원·바위 협곡·고목의 숲·안개 늪)
-- + 자원 노드 + 야생 펫 자리 + 숲. 놀 수 있는 곳은 지름 약 1500 (MapConfig).
-- 다른 서비스가 쓰는 값: Lanes, Nodes, WildSpawns, Core, Warehouse, Campfire, Cage, Spawn, 각 폴더, CagePrompt, CookPrompt
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
	self.Lanes, self.Slots, self.Nodes, self.WildSpawns, self.Grid, self.Marks = {}, {}, {}, {}, {}, {}
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
	self:BuildNodes()
	self:BuildWild()
	self:BuildScenery()
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
	-- 건물 아래 흙 바닥
	for _, spot in ipairs({C.Warehouse, C.Cage}) do
		T:FillCylinder(CFrame.new(spot[1], -2, spot[3]), 4, 9, MAT.Ground)
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
	local toCore = function(x, z)
		return CFrame.lookAt(flat(x, z), Vector3.zero)
	end
	local _, coreHit = S.core(base, CFrame.new())
	self.Core = coreHit
	self.Core.Name = "Core"
	self:Mark(Vector3.zero, C.BaseRadius, "B")
	self:Mark(Vector3.zero, 5, "Q")
	for _, spot in ipairs({C.Warehouse, C.Cage}) do
		self:Mark(Vector3.new(spot[1], 0, spot[3]), 6, "K")
	end

	S.storehouse(base, toCore(C.Warehouse[1], C.Warehouse[3]))
	self.Warehouse = base.Storehouse.Hitbox
	self.Warehouse.Name = "Warehouse"
	local ring = base.Storehouse:FindFirstChild("DepositRing")
	if ring then
		ring.Size = Vector3.new(0.08, G.DepositRadius * 2, G.DepositRadius * 2)
		ring.CFrame = CFrame.new(self.Warehouse.Position.X, 0.1, self.Warehouse.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	end


	local _, penPad = S.pen(base, CFrame.new(C.Cage[1], 0, C.Cage[3]))
	self.Cage = penPad
	self.Cage.Name = "Cage"
	self.CagePrompt = U.prompt(self.Cage, "Register", L.M("prompt.register"), Enum.KeyCode.E, Vector3.new(0, 1.5, -5))
	L.tag(self.CagePrompt, "ObjectText", L.M("place.cage"))

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
	self.CookPrompt = U.prompt(flame, "Cook", L.M("prompt.cook"), Enum.KeyCode.E, Vector3.new(0, 1.5, 0))
	L.tag(self.CookPrompt, "ObjectText", L.M("place.campfire"))
	for i, off in ipairs({Vector3.new(-3.6, 0, 0.5), Vector3.new(3.4, 0, -0.6)}) do
		B.solid(B.cyl(fire, 3.4, 1, fpos * CFrame.new(off) * CFrame.Angles(0, math.rad(80 + i * 20), 0) + Vector3.new(0, 0.5, 0), "#8a5d36", MAT.Wood))
	end
end

-- ============================================================= 길목, 굴, 날개 울타리
function Map:BuildLanes()
	for _, lane in ipairs(self.Lanes) do
		local folder = self.LanesFolder["Lane" .. lane.Id]
		local mouth = lane.Dir * (C.LaneRadius + 6)
		Props.burrow(folder, CFrame.lookAt(mouth, Vector3.zero), self.Rng)
		self:Block(mouth, 14)
		self:Mark(mouth, 7, "U")
		-- 바깥 벽 자리 옆 울타리 날개: 길목이 "막히는 곳" 으로 읽히게 한다
		for _, radius in ipairs({57, 78}) do
			for _, s in ipairs({-1, 1}) do
				local center = lane.Dir * radius + lane.Side * s * (C.LaneWidth / 2 + 5)
				local frame = CFrame.lookAt(center, center + lane.Side)
				for k = -1, 1 do
					B.solid(B.cyl(folder, 3.4, 0.7, frame * CFrame.new(0, 1.7, k * 3.4), "#5e4b3b", MAT.Wood, true))
				end
				B.new("Part", folder, {Name = "FenceWall", Size = Vector3.new(0.5, 3.4, 7.4), CFrame = frame * CFrame.new(0, 1.7, 0), Transparency = 1,
					CanCollide = true, CastShadow = false})
				for _, y in ipairs({1.2, 2.7}) do
					B.block(folder, Vector3.new(0.4, 0.4, 7.4), frame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(4 * s)), "#54432f", MAT.Wood)
				end
				Props.rock(folder, frame * CFrame.new(0, 0, 6.5), self.Rng, 0.55)
			end
		end
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
--  H 바위 언덕 · D 고사목 · R 바위 · T 나무 · Q 수정/Core · P 길 · W 물 · B 기지 바닥 · U 괴물 굴 · K 건물 · X 말뚝 울타리
local GROUND = {Meadow = "G", Ancient = "A", Crags = "C", Swamp = "S"}
local PRIORITY = {N = 0, G = 0, A = 0, C = 0, S = 0, O = 0, H = 1, D = 2, R = 3, T = 4, Q = 5, P = 6, W = 7, B = 8, U = 9, K = 10, X = 11}

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
	-- 말뚝 울타리 고리 (길목 자리는 뚫린 길)
	for iz = 0, n - 1 do
		for ix = 0, n - 1 do
			local cx, cz = center(ix), center(iz)
			local r = math.sqrt(cx * cx + cz * cz)
			if math.abs(r - C.BaseRadius) < cell * 0.55 then
				local open = false
				for _, lane in ipairs(self.Lanes) do
					local d = Vector3.new(cx, 0, cz).Unit:Dot(lane.Dir)
					if d > math.cos((C.GapWidth / 2 + cell * 0.5) / C.BaseRadius) then
						open = true
					end
				end
				grid[iz * n + ix + 1] = open and "P" or "X"
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
