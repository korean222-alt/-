-- 5·9단계 : 농장 배달, 별 주기, 도감 기록.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DataService = require(script.Parent.DataService)
local AnimalService = require(script.Parent.AnimalService)
local WorldService = require(script.Parent.WorldService)
local Effects = require(script.Parent.Effects)

local FarmService = {}

local nextDeliveryAt = {} -- [player] = 다음 배달 가능 시각
local deliveredCount = {} -- [islandKey] = 지금까지 농장에 들어간 총 마리 수
local rng = Random.new()

local function log(...)
	if Config.Debug then
		print("[농장]", ...)
	end
end

local function visibleFarmCount(islandKey)
	local inside = WorldService.getFarmInside(islandKey)
	if not inside then
		return 0
	end
	return #inside:GetChildren()
end

-- 동물이 농장 안으로 폴짝폴짝 들어가는 연출
local function hopIntoFarm(rec, island)
	local inside = WorldService.getFarmInside(island.Key)
	local half = island.FarmSize / 2
	local target = Vector3.new(
		island.FarmCenter.X + rng:NextNumber(-half + 4, half - 4),
		0,
		island.FarmCenter.Z + rng:NextNumber(-half + 4, half - 4)
	)
	local from = rec.pos

	task.spawn(function()
		local duration = Config.Farm.HopInDuration
		local startedAt = os.clock()
		while rec.mode == "script" and rec.model do
			local alpha = (os.clock() - startedAt) / duration
			if alpha >= 1 then
				break
			end
			local position = from:Lerp(target, alpha)
			local hop = math.abs(math.sin(alpha * math.pi * 2.5)) * 1.6
			AnimalService.setPosition(rec, position, hop)
			task.wait()
		end

		if not rec.model then
			return
		end
		AnimalService.setPosition(rec, target, 0)

		if visibleFarmCount(island.Key) < Config.Farm.VisibleCapacity then
			if inside then
				rec.model.Parent = inside
			end
			AnimalService.setFarmMode(rec, island.FarmCenter, half)
		else
			-- 30마리가 넘으면 숫자로만 계산하고 모델은 지웁니다 (성능)
			AnimalService.destroyAnimal(rec)
		end
	end)
end

local function deliverOne(player, island, zone)
	local key = AnimalService.playerKey(player)
	local rec = AnimalService.takeFirst(key)
	if not rec then
		return false
	end

	local info = Config.Animals[rec.species]
	local reward = info and info.Reward or 1

	-- 별 주기는 서버에서만 (5단계)
	DataService.addStars(player, reward)
	deliveredCount[island.Key] = (deliveredCount[island.Key] or 0) + 1

	local isNew = DataService.markDex(player, rec.species)

	local character = player.Character
	if character then
		Effects.starPop(character)
	end
	Effects.starBurst(zone.Position + Vector3.new(0, 1.5, 0))
	Effects.sound3d(zone.Position, "Deliver", 0.08)
	Effects.toPlayer(player, "deliver", {
		reward = reward,
		species = rec.species,
		isNew = isNew,
	})
	if isNew then
		Effects.toPlayer(player, "newAnimal", { species = rec.species })
		log(player.Name, "도감 새 동물:", rec.species)
	end

	hopIntoFarm(rec, island)
	return true
end

function FarmService.getDeliveredCount(islandKey)
	return deliveredCount[islandKey] or 0
end

function FarmService.Start()
	Players.PlayerRemoving:Connect(function(player)
		nextDeliveryAt[player] = nil
	end)

	local checkClock = 0
	RunService.Heartbeat:Connect(function(dt)
		checkClock += dt
		if checkClock < 0.15 then
			return
		end
		checkClock = 0

		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			-- 데이터를 아직 못 불러왔으면 배달하지 않습니다 (8단계)
			if DataService.isLoaded(player) and (nextDeliveryAt[player] or 0) <= now then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and AnimalService.trainLength(player) > 0 then
					for _, islandKey in ipairs(Config.IslandOrder) do
						local island = Config.Islands[islandKey]
						local zone = WorldService.getDeliveryZone(islandKey)
						if zone then
							local flat = Vector3.new(
								root.Position.X - zone.Position.X,
								0,
								root.Position.Z - zone.Position.Z
							)
							if flat.Magnitude <= Config.Farm.ZoneRadius
								and math.abs(root.Position.Y - zone.Position.Y) < 12
							then
								if deliverOne(player, island, zone) then
									nextDeliveryAt[player] = now + Config.Farm.DeliveryInterval
								end
								break
							end
						end
					end
				end
			end
		end
	end)

	log("시작")
end

return FarmService
