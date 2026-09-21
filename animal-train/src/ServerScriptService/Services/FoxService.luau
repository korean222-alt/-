-- 10단계 : NPC 여우 기차. 혼자 플레이해도 맵이 북적이게 만듭니다.
-- 플레이어의 동물은 절대 빼앗지 않습니다 (주인 없는 동물만 모음).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local AnimalService = require(script.Parent.AnimalService)

local FoxService = {}

local foxes = {}
local foxFolder
local rng = Random.new(20240521)

local function log(...)
	if Config.Debug then
		print("[여우]", ...)
	end
end

local function clampToIsland(islandKey, position)
	local island = Config.Islands[islandKey]
	local offset = Vector3.new(position.X - island.Center.X, 0, position.Z - island.Center.Z)
	local distance = offset.Magnitude
	local maxDistance = island.Radius - 8
	if distance > maxDistance then
		offset = offset.Unit * maxDistance
	end
	return Vector3.new(island.Center.X + offset.X, 0, island.Center.Z + offset.Z)
end

local function applyFox(fox, hop)
	local look = fox.facing
	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, 1)
	else
		look = look.Unit
	end
	local base = fox.pos + Vector3.new(0, fox.lift + hop, 0)
	local pivot = CFrame.lookAt(base, base + look)
	fox.model:PivotTo(pivot)

	-- 손 흔들기 (플레이어 근처에서)
	-- 팔은 매 프레임 기준 위치에서 다시 계산합니다 (PivotTo 와 어긋나지 않게)
	if fox.arm and fox.armOffset then
		local now = os.clock()
		if fox.waveUntil and now < fox.waveUntil then
			local swing = math.sin(now * 14)
			fox.arm.CFrame = pivot * fox.armOffset * CFrame.Angles(0, 0, -1.2 + swing * 0.5)
		else
			fox.arm.CFrame = pivot * fox.armOffset
		end
	end
end

local function spawnFox(islandKey, index)
	local island = Config.Islands[islandKey]
	local model = ModelFactory.buildFox()
	model.Name = "Fox_" .. islandKey .. "_" .. index
	model.Parent = foxFolder

	local fox = {
		key = "F_" .. islandKey .. "_" .. index,
		island = islandKey,
		model = model,
		arm = model:FindFirstChild("WaveArm"),
		lift = ModelFactory.Lift.Fox,
		pos = clampToIsland(islandKey, island.FoxDen + Vector3.new(6, 0, 10)),
		facing = Vector3.new(0, 0, 1),
		state = "seek",
		target = nil,
		targetRec = nil,
		nextThink = 0,
		nextWave = 0,
		waveUntil = nil,
	}
	if fox.arm then
		fox.armOffset = CFrame.new(fox.arm.Position) -- 원점 기준 위치 (조립 직후라 그대로 씀)
	end

	-- 여우도 동물 기차의 주인이 됩니다
	AnimalService.registerOwner(fox.key, {
		player = nil,
		getPosition = function()
			return fox.pos + Vector3.new(0, Config.Train.RootHeight, 0)
		end,
		maxLength = function()
			return Config.Fox.MaxTrain
		end,
	})

	applyFox(fox, 0)
	table.insert(foxes, fox)
	return fox
end

local function think(fox)
	local owner = AnimalService.getOwner(fox.key)
	local trainSize = owner and #owner.train or 0

	if fox.state == "seek" and trainSize >= Config.Fox.MaxTrain then
		fox.state = "return"
	end

	if fox.state == "return" then
		fox.target = Config.Islands[fox.island].FoxDen
		fox.targetRec = nil
		return
	end

	-- 주인 없는 동물 중 가장 가까운 것
	local rec = AnimalService.findNearestWild(fox.pos, fox.island, 200)
	if rec then
		fox.targetRec = rec
		fox.target = rec.pos
	else
		fox.targetRec = nil
		local island = Config.Islands[fox.island]
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(island.WanderBand[1], island.WanderBand[2])
		fox.target = clampToIsland(fox.island, island.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
	end
end

local function updateFox(fox, dt, now)
	-- 목표는 자주 계산하지 않습니다 (성능)
	if now >= fox.nextThink then
		fox.nextThink = now + Config.Fox.ThinkInterval
		think(fox)
	end

	-- 쫓던 동물을 누가 먼저 데려갔으면 다시 고릅니다
	if fox.targetRec then
		if fox.targetRec.mode ~= "wander" then
			fox.targetRec = nil
			fox.nextThink = 0
		else
			fox.target = fox.targetRec.pos
		end
	end

	local target = fox.target
	if target then
		local flat = Vector3.new(target.X - fox.pos.X, 0, target.Z - fox.pos.Z)
		local distance = flat.Magnitude
		if distance > 0.6 then
			local step = math.min(distance, Config.Fox.Speed * dt)
			local direction = flat.Unit
			fox.pos = clampToIsland(fox.island, fox.pos + direction * step)
			fox.facing = fox.facing:Lerp(direction, math.min(1, 6 * dt))
			if fox.facing.Magnitude < 0.05 then
				fox.facing = direction
			end
			fox.moving = true
		else
			fox.moving = false
		end

		-- 동물 잡기
		if fox.targetRec and distance <= Config.Fox.CatchRadius then
			AnimalService.claimFor(fox.key, fox.targetRec)
			fox.targetRec = nil
			fox.nextThink = 0
		end

		-- 굴에 도착하면 동물을 내려놓습니다
		if fox.state == "return" then
			local den = Config.Islands[fox.island].FoxDen
			if (Vector3.new(den.X - fox.pos.X, 0, den.Z - fox.pos.Z)).Magnitude <= Config.Fox.DenRadius then
				AnimalService.releaseOwnerTrain(fox.key)
				fox.state = "seek"
				fox.nextThink = 0
			end
		end
	end

	-- 플레이어 근처를 지나가면 손을 흔듭니다
	if now >= fox.nextWave then
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - fox.pos).Magnitude < Config.Fox.WaveRadius then
				fox.nextWave = now + Config.Fox.WaveCooldown
				fox.waveUntil = now + 1.4
				break
			end
		end
	end

	local hop = 0
	if fox.moving then
		hop = math.abs(math.sin(now * 8)) * 0.35
	end
	applyFox(fox, hop)
end

function FoxService.Start()
	foxFolder = workspace:FindFirstChild("Foxes")
	if foxFolder then
		foxFolder:Destroy()
	end
	foxFolder = Instance.new("Folder")
	foxFolder.Name = "Foxes"
	foxFolder.Parent = workspace

	for islandKey, count in pairs(Config.Fox.PerIsland) do
		if Config.Islands[islandKey] then
			for index = 1, count do
				spawnFox(islandKey, index)
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, fox in ipairs(foxes) do
			updateFox(fox, dt, now)
		end
	end)

	log("시작. 마리 수", #foxes)
end

return FoxService
