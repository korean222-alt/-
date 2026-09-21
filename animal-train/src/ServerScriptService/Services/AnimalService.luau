-- 3·4단계 : 동물 스폰 / 돌아다니기 / 닿으면 줄지어 따라오기 (게임의 핵심)
-- 모든 판단은 서버에서 합니다. 동물은 Anchored 상태로 CFrame 만 움직여
-- 물리 계산을 쓰지 않습니다 (성능).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local DataService = require(script.Parent.DataService)
local Effects = require(script.Parent.Effects)

local AnimalService = {}

local animalsFolder
local records = {} -- [id] = rec
local owners = {} -- [ownerKey] = owner (플레이어와 여우 모두)
local trainCallbacks = {}
local nextId = 0
local pendingSpawn = {} -- [species] = 스폰 예정 시각
local rareReadyAt = {} -- [species] = 희귀 동물 다음 등장 시각

local UP = Vector3.new(0, 1, 0)

local function log(...)
	if Config.Debug then
		print("[동물]", ...)
	end
end

--=========================================================
-- 위치 계산 도우미
--=========================================================
local function islandOf(key)
	return Config.Islands[key]
end

-- 섬 안으로, 그리고 농장 밖으로 밀어 넣습니다
local function clampToIsland(islandKey, position)
	local island = islandOf(islandKey)
	if not island then
		return position
	end
	local center = island.Center
	local offset = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	local distance = offset.Magnitude
	local maxDistance = island.Radius - 6
	if distance > maxDistance then
		offset = offset.Unit * maxDistance
	end
	local result = Vector3.new(center.X + offset.X, 0, center.Z + offset.Z)

	-- 농장 안으로는 들어가지 않게 (농장 안 동물과 헷갈리지 않도록)
	local farm = island.FarmCenter
	local half = island.FarmSize / 2 + 3
	local dx = result.X - farm.X
	local dz = result.Z - farm.Z
	if math.abs(dx) < half and math.abs(dz) < half then
		if math.abs(dx) > math.abs(dz) then
			result = Vector3.new(farm.X + (dx >= 0 and half or -half), 0, result.Z)
		else
			result = Vector3.new(result.X, 0, farm.Z + (dz >= 0 and half or -half))
		end
	end
	return result
end

local function randomIslandPoint(islandKey, rng)
	local island = islandOf(islandKey)
	local band = island.WanderBand
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(band[1], band[2])
	local point = island.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	return clampToIsland(islandKey, point)
end

--=========================================================
-- 발자취 (앞 동물을 자연스럽게 따라가게 하는 길)
--=========================================================
local function trailReset(owner, position)
	owner.trail = { pts = { position }, seg = { 0 }, first = 1, last = 1, total = 0 }
end

local function trailPush(owner, position)
	local trail = owner.trail
	if not trail or trail.last < trail.first then
		trailReset(owner, position)
		return
	end
	local newest = trail.pts[trail.last]
	local delta = position - newest
	local length = delta.Magnitude
	if length < Config.Train.TrailStep then
		return
	end
	if length > Config.Train.SnapDistance then
		-- 순간이동(리스폰 등) : 길을 새로 시작하고 동물을 바로 붙입니다
		trailReset(owner, position)
		owner.snap = true
		return
	end
	trail.last += 1
	trail.pts[trail.last] = position
	trail.seg[trail.last] = length
	trail.total += length

	local needed = owner.maxLength() * Config.Train.Spacing + Config.Train.TrailExtra
	while trail.total > needed and trail.first < trail.last - 1 do
		trail.total -= (trail.seg[trail.first + 1] or 0)
		trail.pts[trail.first] = nil
		trail.seg[trail.first] = nil
		trail.first += 1
	end
end

-- 뒤로 distance 만큼 떨어진 지점과 그때의 진행 방향
local function trailSample(owner, distance)
	local trail = owner.trail
	if not trail or trail.last < trail.first then
		return nil, nil
	end
	if trail.last == trail.first then
		return trail.pts[trail.first], nil
	end

	local remaining = distance
	for index = trail.last, trail.first + 1, -1 do
		local length = trail.seg[index] or 0
		if length > 0 then
			if length >= remaining then
				local newer = trail.pts[index]
				local older = trail.pts[index - 1]
				return newer:Lerp(older, remaining / length), newer - older
			end
			remaining -= length
		end
	end
	local oldest = trail.pts[trail.first]
	local next1 = trail.pts[trail.first + 1]
	return oldest, next1 and (next1 - oldest) or nil
end

--=========================================================
-- 동물 만들기 / 없애기
--=========================================================
local function applyCFrame(rec, hopHeight)
	local look = rec.facing
	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, 1)
	else
		look = look.Unit
	end
	local base = rec.pos + UP * (rec.lift + (hopHeight or 0))
	rec.model:PivotTo(CFrame.lookAt(base, base + look))
end

local function newRecord(species, position, islandKey, leash)
	local model = ModelFactory.buildAnimal(species)
	if not model then
		return nil
	end
	local info = Config.Animals[species]
	nextId += 1

	local rec = {
		id = nextId,
		species = species,
		island = islandKey,
		model = model,
		lift = ModelFactory.Lift[species] or 1.2,
		pos = Vector3.new(position.X, 0, position.Z),
		-- 처음 자리에서 이만큼 안에서만 돌아다닙니다 (섬 한쪽으로 몰리지 않게)
		home = Vector3.new(position.X, 0, position.Z),
		leash = leash or Config.Animals[species].Leash or 22,
		facing = Vector3.new(0, 0, 1),
		mode = "wander",
		idle = math.random() * 2,
		hopTo = nil,
		ownerKey = nil,
		consumed = false,
		speed = info.MoveSpeed or 8,
	}

	model.Name = species
	model:SetAttribute("Owned", false)
	model:SetAttribute("Island", islandKey)
	model:SetAttribute("Rare", info.Rare == true)
	model:SetAttribute("Reward", info.Reward or 1)
	model:SetAttribute("AnimalId", rec.id)
	applyCFrame(rec, 0)
	model.Parent = animalsFolder

	records[rec.id] = rec
	return rec
end

local function removeRecord(rec)
	rec.mode = "gone"
	records[rec.id] = nil
	if rec.model then
		rec.model:Destroy()
		rec.model = nil
	end
end

--=========================================================
-- 기차 (따라오기)
--=========================================================
local function fireTrainChanged(owner)
	if not owner.player then
		return
	end
	for _, callback in ipairs(trainCallbacks) do
		task.spawn(callback, owner.player)
	end
end

local function ownerKeyForPlayer(player)
	return "P" .. player.UserId
end
AnimalService.playerKey = ownerKeyForPlayer

local function claim(owner, rec)
	if rec.mode ~= "wander" or rec.consumed then
		return false
	end
	if #owner.train >= owner.maxLength() then
		return false
	end

	local position = owner.getPosition()
	if not position then
		return false
	end
	if not owner.trail or owner.trail.last < owner.trail.first then
		trailReset(owner, position)
	end

	rec.mode = "train"
	rec.ownerKey = owner.key
	rec.hopTo = nil
	table.insert(owner.train, rec)
	rec.model:SetAttribute("Owned", true)

	-- 삐약 소리 + 하트 파티클 (4단계)
	Effects.sound3d(rec.pos + UP * 2, rec.species == "Duckling" and "ChirpAlt" or "Chirp", 0.12)
	Effects.hearts(rec.pos + UP * (rec.lift + 1.2))

	if owner.player then
		DataService.noteTrainLength(owner.player, #owner.train)
		local full = #owner.train >= owner.maxLength()
		Effects.toPlayer(owner.player, "pickup", { count = #owner.train, full = full })
		if full then
			Effects.toPlayer(owner.player, "full", {})
		end
	end
	fireTrainChanged(owner)
	return true
end

local function releaseRecord(rec, position)
	rec.mode = "wander"
	rec.ownerKey = nil
	rec.idle = math.random() * 1.2
	rec.hopTo = nil
	if position then
		rec.pos = Vector3.new(position.X, 0, position.Z)
	end
	rec.pos = clampToIsland(rec.island, rec.pos)
	rec.home = rec.pos
	if rec.model then
		rec.model:SetAttribute("Owned", false)
	end
end

local function releaseTrain(owner)
	for _, rec in ipairs(owner.train) do
		releaseRecord(rec, rec.pos)
	end
	owner.train = {}
	fireTrainChanged(owner)
end

--=========================================================
-- 돌아다니기
--=========================================================
local function nearestPlayerPosition(position, maxDistance)
	local best, bestDistance = nil, maxDistance or math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = root.Position
			end
		end
	end
	return best, bestDistance
end

local wanderRng = Random.new(os.clock() * 1000)

local function pickWanderTarget(rec)
	local info = Config.Animals[rec.species]
	local target

	if info.Rare then
		-- 희귀 동물은 사람이 가까이 오면 반대로 도망갑니다 (9단계)
		local playerPosition = nearestPlayerPosition(rec.pos, info.FleeRadius or 28)
		if playerPosition then
			local away = rec.pos - playerPosition
			if away.Magnitude < 0.5 then
				away = Vector3.new(1, 0, 0)
			end
			away = Vector3.new(away.X, 0, away.Z).Unit
			target = rec.pos + away * wanderRng:NextNumber(10, 16)
		else
			target = rec.pos
				+ Vector3.new(wanderRng:NextNumber(-14, 14), 0, wanderRng:NextNumber(-14, 14))
		end
	else
		target = rec.pos + Vector3.new(wanderRng:NextNumber(-6, 6), 0, wanderRng:NextNumber(-6, 6))
	end

	if rec.mode == "farm" and rec.farm then
		-- 농장 안 동물은 울타리 안에서만
		local half = rec.farm.half - 2
		target = Vector3.new(
			math.clamp(target.X, rec.farm.center.X - half, rec.farm.center.X + half),
			0,
			math.clamp(target.Z, rec.farm.center.Z - half, rec.farm.center.Z + half)
		)
	else
		-- 처음 있던 자리(home) 주변을 벗어나지 않게 (희귀 동물은 조금 더 멀리)
		local leash = rec.leash or 22
		if info.Rare then
			leash *= 2.5
		end
		local away = Vector3.new(target.X - rec.home.X, 0, target.Z - rec.home.Z)
		if away.Magnitude > leash then
			away = away.Unit * leash
			target = Vector3.new(rec.home.X + away.X, 0, rec.home.Z + away.Z)
		end
		target = clampToIsland(rec.island, target)
	end

	local distance = (target - rec.pos).Magnitude
	if distance < 0.6 then
		return
	end
	rec.hopFrom = rec.pos
	rec.hopTo = target
	rec.hopTime = 0
	rec.hopDuration = math.clamp(distance / math.max(1, rec.speed), 0.25, 1.2)
	local flat = Vector3.new(target.X - rec.pos.X, 0, target.Z - rec.pos.Z)
	if flat.Magnitude > 0.05 then
		rec.facing = flat.Unit
	end
end

local function updateWanderer(rec, dt)
	if rec.hopTo then
		rec.hopTime += dt
		local alpha = math.min(1, rec.hopTime / rec.hopDuration)
		rec.pos = rec.hopFrom:Lerp(rec.hopTo, alpha)
		local hop = math.sin(alpha * math.pi) * (Config.Train.HopHeight + 0.25)
		applyCFrame(rec, hop)
		if alpha >= 1 then
			rec.hopTo = nil
			local info = Config.Animals[rec.species]
			local idleRange = info.WanderIdle or { 2, 4 }
			rec.idle = wanderRng:NextNumber(idleRange[1], idleRange[2])
		end
		return
	end

	rec.idle -= dt
	if rec.idle <= 0 then
		pickWanderTarget(rec)
	end
end

--=========================================================
-- 매 프레임 갱신
--=========================================================
local function updateTrains(dt, clock)
	for _, owner in pairs(owners) do
		local position = owner.getPosition()
		if position and #owner.train > 0 then
			trailPush(owner, position)
			local snap = owner.snap
			owner.snap = false

			local alpha = snap and 1 or (1 - math.exp(-Config.Train.Smoothness * dt))
			local turn = math.min(1, Config.Train.TurnSpeed * dt)

			for index, rec in ipairs(owner.train) do
				local target, direction = trailSample(owner, index * Config.Train.Spacing)
				if target then
					-- 발자취는 플레이어 허리 높이이므로 땅 높이로 내려 줍니다
					local goal = Vector3.new(target.X, target.Y - Config.Train.RootHeight, target.Z)
					local previous = rec.pos
					rec.pos = previous:Lerp(goal, alpha)

					if direction and direction.Magnitude > 0.01 then
						local flat = Vector3.new(direction.X, 0, direction.Z)
						if flat.Magnitude > 0.01 then
							local blended = rec.facing:Lerp(flat.Unit, turn)
							if blended.Magnitude > 0.05 then
								rec.facing = blended.Unit
							else
								rec.facing = flat.Unit
							end
						end
					end

					local moved = (rec.pos - previous).Magnitude / math.max(dt, 1 / 240)
					local hop = 0
					if moved > 1.2 then
						hop = math.abs(math.sin(clock * Config.Train.HopSpeed + index * 0.8))
							* Config.Train.HopHeight
					end
					applyCFrame(rec, hop)
				end
			end
		elseif position then
			trailPush(owner, position)
		end
	end
end

local function updateWanderers(dt)
	for _, rec in pairs(records) do
		if rec.mode == "wander" or rec.mode == "farm" then
			updateWanderer(rec, dt)
		end
	end
end

--=========================================================
-- 줍기 (4·11단계)
--=========================================================
local function checkPickups()
	for _, player in ipairs(Players:GetPlayers()) do
		local owner = owners[ownerKeyForPlayer(player)]
		if owner then
			local position = owner.getPosition()
			if position and #owner.train < owner.maxLength() then
				local radius = DataService.pickupRadius(player)
				local best, bestDistance = nil, radius
				for _, rec in pairs(records) do
					if rec.mode == "wander" and not rec.consumed then
						local dy = math.abs(rec.pos.Y + rec.lift - position.Y)
						if dy < 10 then
							local flat = Vector3.new(rec.pos.X - position.X, 0, rec.pos.Z - position.Z)
							local distance = flat.Magnitude
							if distance <= bestDistance then
								bestDistance = distance
								best = rec
							end
						end
					end
				end
				if best then
					claim(owner, best)
				end
			end
		end
	end
end

--=========================================================
-- 마리 수 유지 (3·9단계)
--=========================================================
local function countSpecies(species)
	local wander, total = 0, 0
	for _, rec in pairs(records) do
		if rec.species == species then
			if rec.mode == "wander" then
				wander += 1
			end
			if rec.mode ~= "farm" and rec.mode ~= "gone" then
				total += 1
			end
		end
	end
	return wander, total
end

local function spawnSpecies(species, position, leash)
	local info = Config.Animals[species]
	local islandKey = info.Island
	local point = position or randomIslandPoint(islandKey, wanderRng)
	local rec = newRecord(species, point, islandKey, leash)
	if rec and info.Rare then
		Effects.toAll("rareAppeared", { species = species, island = islandKey })
		log("희귀 동물 등장:", species)
	end
	return rec
end

-- 스폰 정면에는 항상 동물 1마리가 보이게 합니다 (3단계)
local welcomeReadyAt = {}
local function maintainWelcomeAnimal(now)
	for _, islandKey in ipairs(Config.IslandOrder) do
		local island = Config.Islands[islandKey]
		local species = Config.DexOrder[islandKey] and Config.DexOrder[islandKey][1]
		if island.FirstAnimalPos and species then
			local found = false
			for _, rec in pairs(records) do
				if rec.mode == "wander" and rec.island == islandKey then
					if (rec.pos - island.FirstAnimalPos).Magnitude < 11 then
						found = true
						break
					end
				end
			end
			if found then
				welcomeReadyAt[islandKey] = nil
			else
				local readyAt = welcomeReadyAt[islandKey]
				local _, total = countSpecies(species)
				if not readyAt then
					welcomeReadyAt[islandKey] = now + 3
				elseif now >= readyAt and total < Config.Animals[species].Count * Config.MaxAnimalsPerSpecies then
					welcomeReadyAt[islandKey] = nil
					spawnSpecies(species, island.FirstAnimalPos, 7)
				end
			end
		end
	end
end

local function maintainPopulation()
	local now = os.clock()
	maintainWelcomeAnimal(now)
	for species, info in pairs(Config.Animals) do
		local wander, total = countSpecies(species)
		if info.Rare then
			if total == 0 then
				local readyAt = rareReadyAt[species]
				if not readyAt then
					rareReadyAt[species] = now + (info.RespawnDelay or 180)
				elseif now >= readyAt then
					rareReadyAt[species] = nil
					spawnSpecies(species)
				end
			else
				rareReadyAt[species] = nil
			end
		else
			local limit = info.Count * Config.MaxAnimalsPerSpecies
			if wander < info.Count and total < limit then
				local readyAt = pendingSpawn[species]
				if not readyAt then
					pendingSpawn[species] = now + Config.AnimalRespawnDelay
				elseif now >= readyAt then
					pendingSpawn[species] = nil
					spawnSpecies(species)
				end
			else
				pendingSpawn[species] = nil
			end
		end
	end
end

--=========================================================
-- 밖에서 쓰는 함수들
--=========================================================
function AnimalService.registerOwner(key, spec)
	local owner = {
		key = key,
		player = spec.player,
		getPosition = spec.getPosition,
		maxLength = spec.maxLength,
		train = {},
		snap = true,
	}
	trailReset(owner, spec.getPosition() or Vector3.zero)
	owners[key] = owner
	return owner
end

function AnimalService.unregisterOwner(key)
	local owner = owners[key]
	if not owner then
		return
	end
	releaseTrain(owner)
	owners[key] = nil
end

function AnimalService.getOwner(key)
	return owners[key]
end

function AnimalService.getTrain(player)
	local owner = owners[ownerKeyForPlayer(player)]
	return owner and owner.train or {}
end

function AnimalService.trainLength(player)
	return #AnimalService.getTrain(player)
end

function AnimalService.onTrainChanged(callback)
	table.insert(trainCallbacks, callback)
end

-- 기차 맨 앞 동물을 꺼냅니다 (배달용). 꺼낸 즉시 consumed 로 표시해
-- 같은 동물로 별을 두 번 받는 일이 없게 합니다 (5단계).
function AnimalService.takeFirst(ownerKey)
	local owner = owners[ownerKey]
	if not owner or #owner.train == 0 then
		return nil
	end
	local rec = table.remove(owner.train, 1)
	if not rec then
		return nil
	end
	rec.mode = "script"
	rec.ownerKey = nil
	rec.consumed = true
	if rec.model then
		rec.model:SetAttribute("Owned", false)
	end
	fireTrainChanged(owner)
	return rec
end

function AnimalService.setFarmMode(rec, center, half)
	rec.mode = "farm"
	rec.consumed = false
	rec.farm = { center = center, half = half }
	rec.idle = math.random() * 2
	rec.hopTo = nil
end

function AnimalService.releaseToWild(rec, position)
	rec.consumed = false
	releaseRecord(rec, position)
end

function AnimalService.destroyAnimal(rec)
	removeRecord(rec)
end

function AnimalService.setPosition(rec, position, hopHeight)
	rec.pos = Vector3.new(position.X, position.Y, position.Z)
	applyCFrame(rec, hopHeight or 0)
end

function AnimalService.findNearestWild(position, islandKey, maxDistance)
	local best, bestDistance = nil, maxDistance or math.huge
	for _, rec in pairs(records) do
		if rec.mode == "wander" and rec.island == islandKey and not rec.consumed then
			local distance = (rec.pos - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = rec
			end
		end
	end
	return best, bestDistance
end

function AnimalService.claimFor(ownerKey, rec)
	local owner = owners[ownerKey]
	if not owner then
		return false
	end
	return claim(owner, rec)
end

function AnimalService.releaseOwnerTrain(ownerKey)
	local owner = owners[ownerKey]
	if owner then
		releaseTrain(owner)
	end
end

function AnimalService.Start()
	animalsFolder = workspace:FindFirstChild("Animals")
	if animalsFolder then
		animalsFolder:Destroy()
	end
	animalsFolder = Instance.new("Folder")
	animalsFolder.Name = "Animals"
	animalsFolder.Parent = workspace

	-- 3단계 요구사항 : 모델 원본을 ServerStorage/AnimalModels 에 보관
	local templates = ServerStorage:FindFirstChild("AnimalModels")
	if templates then
		templates:Destroy()
	end
	templates = Instance.new("Folder")
	templates.Name = "AnimalModels"
	templates.Parent = ServerStorage
	for species in pairs(Config.Animals) do
		local model = ModelFactory.buildAnimal(species)
		if model then
			model.Name = species
			model.Parent = templates
		end
	end

	-- 플레이어를 기차 주인으로 등록
	local function addPlayer(player)
		local key = ownerKeyForPlayer(player)
		AnimalService.registerOwner(key, {
			player = player,
			getPosition = function()
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				return root and root.Position or nil
			end,
			maxLength = function()
				return DataService.maxTrain(player)
			end,
		})
		player.CharacterAdded:Connect(function()
			local owner = owners[key]
			if owner then
				owner.snap = true
			end
		end)
	end

	Players.PlayerAdded:Connect(addPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		addPlayer(player)
	end

	-- 나간 플레이어의 동물은 주인 없는 상태로 되돌립니다 (4단계)
	Players.PlayerRemoving:Connect(function(player)
		AnimalService.unregisterOwner(ownerKeyForPlayer(player))
	end)

	-- 첫 동물은 스폰 정면에 (접속하자마자 보이도록)
	for _, key in ipairs(Config.IslandOrder) do
		local island = Config.Islands[key]
		local first = Config.DexOrder[key] and Config.DexOrder[key][1]
		if island.FirstAnimalPos and first then
			newRecord(first, island.FirstAnimalPos, key, 7)
		end
	end

	-- 나머지 동물 채우기
	for species, info in pairs(Config.Animals) do
		if not info.Rare then
			local _, total = countSpecies(species)
			for _ = total + 1, info.Count do
				spawnSpecies(species)
			end
		else
			rareReadyAt[species] = os.clock() + (info.RespawnDelay or 180)
		end
	end

	-- 갱신 루프
	local pickupClock = 0
	local wanderClock = 0
	local maintainClock = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		updateTrains(dt, now)

		wanderClock += dt
		if wanderClock >= 1 / 15 then
			updateWanderers(wanderClock)
			wanderClock = 0
		end

		pickupClock += dt
		if pickupClock >= Config.Pickup.CheckInterval then
			pickupClock = 0
			checkPickups()
		end

		maintainClock += dt
		if maintainClock >= 1 then
			maintainClock = 0
			maintainPopulation()
		end
	end)

	log("시작. 동물 수", (function()
		local count = 0
		for _ in pairs(records) do
			count += 1
		end
		return count
	end)())
end

return AnimalService
