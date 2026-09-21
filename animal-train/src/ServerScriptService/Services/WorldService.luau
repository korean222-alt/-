-- 2·7단계 : 섬, 농장, 물, 다리, 조명, 장식을 파트로 만듭니다.
-- 만들어지는 위치는 모두 Config.Islands / Config.Bridge 에서 옵니다.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local DataService = require(script.Parent.DataService)

local WorldService = {}

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

local worldFolder
local islandInfo = {} -- [islandKey] = { folder, deliveryZone, farmFolder }

local function log(...)
	if Config.Debug then
		print("[월드]", ...)
	end
end

local function makePart(name, size, position, color, parent, options)
	options = options or {}
	local part = ModelFactory.newPart({
		Name = name,
		Size = size,
		Color = color,
		Shape = options.Shape,
		Material = options.Material,
		Transparency = options.Transparency,
		Reflectance = options.Reflectance,
		CanCollide = options.CanCollide ~= false, -- 월드 파트는 기본으로 충돌 있음
		CanTouch = options.CanTouch == true,
		CanQuery = options.CanQuery ~= false,
		CastShadow = options.CastShadow ~= false,
	})
	local cframe = CFrame.new(position)
	if options.Rot then
		cframe = cframe
			* CFrame.fromEulerAnglesXYZ(math.rad(options.Rot.X), math.rad(options.Rot.Y), math.rad(options.Rot.Z))
	end
	part.CFrame = cframe
	part.Parent = parent
	return part
end

--=========================================================
-- 조명 (밝고 귀여운 분위기)
--=========================================================
local function setupLighting()
	pcall(function()
		Lighting.Ambient = Color3.fromRGB(138, 142, 158)
		Lighting.OutdoorAmbient = Color3.fromRGB(172, 182, 202)
		Lighting.Brightness = 2.6
		Lighting.ClockTime = 14.2
		Lighting.GeographicLatitude = 20
		Lighting.ExposureCompensation = 0.1
		Lighting.GlobalShadows = true
		Lighting.FogColor = Color3.fromRGB(205, 232, 255)
		Lighting.FogEnd = 1500
		Lighting.FogStart = 400
	end)

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(216, 235, 255)
		atmosphere.Decay = Color3.fromRGB(188, 214, 240)
		atmosphere.Glare = 0.15
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
end

--=========================================================
-- 물 (섬 밖은 파란 바닥처럼 보이게)
--=========================================================
local function buildWater()
	local water = makePart(
		"Water",
		Vector3.new(1600, 4, 1600),
		Vector3.new(0, -7, -130),
		Config.Colors.Water,
		worldFolder,
		{
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Transparency = 0.28,
			Reflectance = 0.18,
		}
	)
	water.Name = "Water"

	-- 물 아래 더 짙은 바닥 (깊이감)
	makePart("DeepWater", Vector3.new(1600, 4, 1600), Vector3.new(0, -26, -130), Color3.fromRGB(92, 150, 200), worldFolder, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
end

--=========================================================
-- 섬 땅
--=========================================================
local function buildIslandGround(island, folder)
	local center = island.Center
	local radius = island.Radius

	makePart("Beach", Vector3.new(5, (radius + 9) * 2, (radius + 9) * 2), center + Vector3.new(0, -2.8, 0), island.Beach, folder, {
		Shape = CYL,
		Rot = Vector3.new(0, 0, 90),
	})
	makePart("Base", Vector3.new(30, (radius - 4) * 2, (radius - 4) * 2), center + Vector3.new(0, -18, 0), Color3.fromRGB(150, 128, 104), folder, {
		Shape = CYL,
		Rot = Vector3.new(0, 0, 90),
	})
	local ground = makePart("Ground", Vector3.new(8, radius * 2, radius * 2), center + Vector3.new(0, -4, 0), island.Ground, folder, {
		Shape = CYL,
		Rot = Vector3.new(0, 0, 90),
	})
	return ground
end

--=========================================================
-- 농장 (나무 울타리 + 노란 배달 발판)
--=========================================================
local function buildFarm(island, folder)
	local farmFolder = Instance.new("Folder")
	farmFolder.Name = "Farm"
	farmFolder.Parent = folder

	local center = island.FarmCenter
	local half = island.FarmSize / 2
	local gapHalf = 5 -- 입구 너비의 절반

	-- 농장 바닥 (밝은 흙색)
	makePart("Floor", Vector3.new(island.FarmSize, 0.6, island.FarmSize), center + Vector3.new(0, -0.2, 0), Color3.fromRGB(226, 205, 162), farmFolder, {
		CanCollide = false,
		CastShadow = false,
	})

	-- 울타리 만들기
	local function fenceRun(fromPos, toPos)
		local delta = toPos - fromPos
		local length = delta.Magnitude
		if length < 0.5 then
			return
		end
		local direction = delta.Unit
		local middle = fromPos + delta * 0.5
		local yaw = math.atan2(-direction.X, -direction.Z)

		-- 가로 막대 2개
		for _, height in ipairs({ 1.1, 2.1 }) do
			local rail = makePart("Rail", Vector3.new(0.35, 0.35, length), middle + Vector3.new(0, height, 0), Config.Colors.Wood, farmFolder, {
				CanCollide = false,
				CastShadow = false,
			})
			rail.CFrame = CFrame.new(middle + Vector3.new(0, height, 0)) * CFrame.Angles(0, yaw, 0)
		end

		-- 기둥
		local count = math.max(2, math.floor(length / 4))
		for index = 0, count do
			local position = fromPos + direction * (length * (index / count))
			makePart("Post", Vector3.new(0.6, 3, 0.6), position + Vector3.new(0, 1.5, 0), Config.Colors.WoodDark, farmFolder, {
				CanCollide = true,
			})
		end
	end

	local northZ = center.Z - half -- 농장 뒤쪽
	local southZ = center.Z + half -- 입구 쪽 (스폰에서 보이는 면)
	local westX = center.X - half
	local eastX = center.X + half
	local y = 0

	fenceRun(Vector3.new(westX, y, northZ), Vector3.new(eastX, y, northZ))
	fenceRun(Vector3.new(westX, y, northZ), Vector3.new(westX, y, southZ))
	fenceRun(Vector3.new(eastX, y, northZ), Vector3.new(eastX, y, southZ))
	-- 입구가 있는 면은 가운데를 비웁니다
	fenceRun(Vector3.new(westX, y, southZ), Vector3.new(center.X - gapHalf, y, southZ))
	fenceRun(Vector3.new(center.X + gapHalf, y, southZ), Vector3.new(eastX, y, southZ))

	-- 입구 기둥 (조금 더 크게)
	for _, side in ipairs({ -1, 1 }) do
		makePart("GatePost", Vector3.new(1, 4.5, 1), Vector3.new(center.X + side * gapHalf, 2.25, southZ), Config.Colors.WoodDark, farmFolder, {
			CanCollide = true,
		})
		makePart("GatePostTop", Vector3.new(1.4, 0.5, 1.4), Vector3.new(center.X + side * gapHalf, 4.7, southZ), Color3.fromRGB(255, 208, 120), farmFolder, {
			CanCollide = false,
		})
	end

	-- 밝게 빛나는 노란 배달 발판 (5단계)
	local zonePos = island.DeliveryPos + Vector3.new(0, 0.25, 0)
	local zone = makePart("DeliveryZone", Vector3.new(12, 0.5, 8), zonePos, Color3.fromRGB(255, 226, 110), farmFolder, {
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = true,
		CastShadow = false,
	})
	zone:SetAttribute("Island", island.Key)

	-- 발판 위 반짝임
	ModelFactory.addSparkles(zone, Color3.fromRGB(255, 240, 170), 10)

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 18
	light.Color = Color3.fromRGB(255, 230, 150)
	light.Parent = zone

	local inside = Instance.new("Folder")
	inside.Name = "Inside" -- 농장에 들어간 동물들이 사는 곳
	inside.Parent = farmFolder

	return farmFolder, zone
end

--=========================================================
-- 장식 (나무, 꽃, 바위)
--=========================================================
local function buildDecor(island, folder)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	local rng = Random.new(island.Order * 7919)
	local center = island.Center
	local isSnow = island.Key == "Snow"

	-- 이 구역에는 장식을 놓지 않습니다 (길을 막지 않도록)
	local function blocked(position)
		local farm = island.FarmCenter
		local half = island.FarmSize / 2 + 6
		if math.abs(position.X - farm.X) < half and math.abs(position.Z - farm.Z) < half then
			return true
		end
		-- 스폰 → 농장 통로
		local spawn = island.SpawnPoint
		local minZ = math.min(spawn.Z, farm.Z) - 4
		local maxZ = math.max(spawn.Z, farm.Z) + 12
		if math.abs(position.X - spawn.X) < 16 and position.Z > minZ and position.Z < maxZ then
			return true
		end
		-- 다리 통로
		if math.abs(position.X) < 14 and position.Z < Config.Bridge.FromZ + 22 and position.Z > Config.Bridge.ToZ - 22 then
			return true
		end
		-- 여우 굴 주변
		if (position - island.FoxDen).Magnitude < 12 then
			return true
		end
		-- 상점 주변
		if island.ShopPos and (position - island.ShopPos).Magnitude < 14 then
			return true
		end
		return false
	end

	local function scatter(count, builder, minRadius, maxRadius)
		local placed = 0
		local tries = 0
		while placed < count and tries < count * 14 do
			tries += 1
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(minRadius, maxRadius)
			local position = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			if not blocked(position) then
				local model = builder(rng)
				ModelFactory.offsetModel(model, position, rng:NextNumber(0, 360))
				model.Parent = decor
				placed += 1
			end
		end
	end

	if isSnow then
		scatter(12, ModelFactory.buildPine, island.Radius * 0.3, island.Radius * 0.9)
		scatter(10, ModelFactory.buildSnowMound, island.Radius * 0.25, island.Radius * 0.92)
		scatter(8, ModelFactory.buildRock, island.Radius * 0.3, island.Radius * 0.9)
	else
		scatter(14, ModelFactory.buildTree, island.Radius * 0.28, island.Radius * 0.92)
		scatter(34, ModelFactory.buildFlower, island.Radius * 0.15, island.Radius * 0.94)
		scatter(10, ModelFactory.buildRock, island.Radius * 0.3, island.Radius * 0.92)
	end
end

--=========================================================
-- 여우 굴 (10단계)
--=========================================================
local function buildFoxDen(island, folder)
	local position = island.FoxDen
	local den = Instance.new("Folder")
	den.Name = "FoxDen"
	den.Parent = folder

	makePart("Mound", Vector3.new(14, 8, 14), position + Vector3.new(0, 1, 0), Color3.fromRGB(176, 148, 116), den, {
		Shape = BALL,
		CanCollide = false,
	})
	makePart("Hole", Vector3.new(5, 4.5, 3), position + Vector3.new(0, 1.6, 6.2), Color3.fromRGB(72, 58, 48), den, {
		Shape = BALL,
		CanCollide = false,
	})
	makePart("Marker", Vector3.new(1.2, 0.4, 1.2), position + Vector3.new(0, 0.2, 9), Color3.fromRGB(255, 200, 120), den, {
		Shape = CYL,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Rot = Vector3.new(0, 0, 90),
	})
	den:SetAttribute("Island", island.Key)
	return den
end

--=========================================================
-- 스폰 발판
--=========================================================
local function buildSpawn(island, folder)
	local existing = workspace:FindFirstChild("MainSpawn", true)
	local spawn = existing
	if not spawn or not spawn:IsA("SpawnLocation") then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "MainSpawn"
	end
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(255, 236, 168)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.CFrame = CFrame.lookAt(island.SpawnPoint + Vector3.new(0, 0.5, 0), island.FarmCenter + Vector3.new(0, 0.5, 0))
	spawn.Parent = folder

	-- 스폰 발판 테두리 (예쁘게)
	makePart("SpawnRing", Vector3.new(0.6, 15, 15), island.SpawnPoint + Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 214, 120), folder, {
		Shape = CYL,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Rot = Vector3.new(0, 0, 90),
	})
	return spawn
end

--=========================================================
-- 다리 (7단계)
--=========================================================
local function buildBridge()
	local bridge = Instance.new("Folder")
	bridge.Name = "Bridge"
	bridge.Parent = worldFolder

	local fromZ = Config.Bridge.FromZ
	local toZ = Config.Bridge.ToZ
	local length = math.abs(toZ - fromZ) + 14
	local middleZ = (fromZ + toZ) / 2
	local width = Config.Bridge.Width

	makePart("Deck", Vector3.new(width, 1.2, length), Vector3.new(0, -0.6, middleZ), Config.Colors.Wood, bridge, {})

	-- 판자 무늬
	local planks = math.floor(length / 4)
	for index = 0, planks do
		local z = (middleZ - length / 2) + index * 4
		makePart("Plank", Vector3.new(width + 0.4, 0.25, 1.2), Vector3.new(0, 0.05, z), Config.Colors.WoodDark, bridge, {
			CanCollide = false,
			CastShadow = false,
		})
	end

	-- 난간
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (width / 2 + 0.2)
		makePart("Rail", Vector3.new(0.4, 0.4, length), Vector3.new(x, 2.6, middleZ), Config.Colors.WoodDark, bridge, {
			CanCollide = false,
			CastShadow = false,
		})
		local posts = math.floor(length / 8)
		for index = 0, posts do
			local z = (middleZ - length / 2) + index * 8
			makePart("RailPost", Vector3.new(0.5, 3, 0.5), Vector3.new(x, 1.3, z), Config.Colors.WoodDark, bridge, {
				CanCollide = true,
			})
		end
	end

	-- 물속 기둥
	local pillars = math.floor(length / 16)
	for index = 0, pillars do
		local z = (middleZ - length / 2) + index * 16
		makePart("Pillar", Vector3.new(14, 1.6, 1.6), Vector3.new(0, -8, z), Config.Colors.WoodDark, bridge, {
			Shape = CYL,
			CanCollide = false,
			Rot = Vector3.new(0, 0, 90),
		})
	end
	return bridge
end

--=========================================================
-- 물에 빠지면 스폰으로 (2단계)
--=========================================================
local function startFallGuard()
	task.spawn(function()
		while true do
			task.wait(0.35)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < -9 then
					local target = Config.Islands[Config.StartIsland]
					-- 열어 둔 섬 중 가장 가까운 섬으로 돌려보냅니다
					local best = math.huge
					for _, key in ipairs(Config.IslandOrder) do
						local island = Config.Islands[key]
						if island and (key == Config.StartIsland or DataService.hasIsland(player, key)) then
							local distance = (island.Center - root.Position).Magnitude
							if distance < best then
								best = distance
								target = island
							end
						end
					end
					character:PivotTo(CFrame.new(target.SpawnPoint + Vector3.new(0, 5, 0)))
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:ChangeState(Enum.HumanoidStateType.Landed)
					end
					WorldService.onFall(player)
				end
			end
		end
	end)
end

-- Effects 가 연결해 주는 자리 (물에 빠졌을 때 소리)
WorldService.onFall = function(_player) end

--=========================================================
-- 밖에서 쓰는 함수들
--=========================================================
function WorldService.getDeliveryZone(islandKey)
	local info = islandInfo[islandKey]
	return info and info.deliveryZone
end

function WorldService.getFarmInside(islandKey)
	local info = islandInfo[islandKey]
	return info and info.farmFolder and info.farmFolder:FindFirstChild("Inside")
end

function WorldService.getIslandFolder(islandKey)
	local info = islandInfo[islandKey]
	return info and info.folder
end

function WorldService.Start()
	-- 기존 Baseplate 와 낡은 월드를 지웁니다 (2단계)
	for _, name in ipairs({ "Baseplate", "World" }) do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "Baseplate" then
			child:Destroy()
		end
	end

	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = workspace

	setupLighting()
	buildWater()

	for _, key in ipairs(Config.IslandOrder) do
		local island = Config.Islands[key]
		local folder = Instance.new("Folder")
		folder.Name = key
		folder.Parent = worldFolder

		buildIslandGround(island, folder)
		local farmFolder, zone = buildFarm(island, folder)
		buildDecor(island, folder)
		buildFoxDen(island, folder)
		if key == Config.StartIsland then
			buildSpawn(island, folder)
		end

		islandInfo[key] = { folder = folder, farmFolder = farmFolder, deliveryZone = zone }
		log(key, "섬 완성")
	end

	buildBridge()
	startFallGuard()

	pcall(function()
		Players.RespawnTime = 1.5
	end)

	log("월드 준비 끝")
end

return WorldService
