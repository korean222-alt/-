-- 8단계 : 플레이어 데이터 저장/불러오기.
-- 별, 열린 섬, 도감, 최고 기차 길이, 업그레이드 단계를 저장합니다.
-- 현재 기차에 달린 동물은 저장하지 않습니다 (다시 접속하면 빈 기차).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))

local DataService = {}

local store = nil
local profiles = {} -- [Player] = profile
local changedCallbacks = {}
local apiWarned = false

local function log(...)
	if Config.Debug then
		print("[데이터]", ...)
	end
end

local function defaultData()
	return {
		version = Config.Data.Version,
		stars = 0, -- 지금 가진 별 (업그레이드로 씁니다)
		totalStars = 0, -- 지금까지 모은 총 별 (섬 해금 기준, 11단계)
		islands = { [Config.StartIsland] = true },
		dex = {},
		bestTrain = 0,
		upgrades = { Speed = 0, Train = 0, Magnet = 0 },
		prefs = { music = true },
	}
end

-- 저장 구조가 바뀌어도 안전하게 (빠진 값은 기본값으로 채움)
local function migrate(data)
	local base = defaultData()
	if type(data) ~= "table" then
		return base
	end

	for key, value in pairs(base) do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) ~= "table" then
			data[key] = value
		end
	end

	for key, value in pairs(base.upgrades) do
		if type(data.upgrades[key]) ~= "number" then
			data.upgrades[key] = value
		end
	end
	if type(data.prefs.music) ~= "boolean" then
		data.prefs.music = true
	end
	-- 1버전에는 totalStars 가 없었으므로 현재 별을 총 별로 인정해 줍니다.
	if (data.version or 1) < 2 then
		data.totalStars = math.max(data.totalStars or 0, data.stars or 0)
	end
	data.version = Config.Data.Version
	return data
end

local function warnAboutApi(err)
	if apiWarned then
		return
	end
	apiWarned = true
	warn("[데이터] 저장 기능을 쓸 수 없습니다: " .. tostring(err))
	warn("[데이터] Studio 에서 테스트 중이라면 다음을 켜 주세요:")
	warn("[데이터]   Studio 상단 HOME → Game Settings → Security →")
	warn("[데이터]   'Enable Studio Access to API Services' 를 켜고 저장(Save)")
	warn("[데이터] 켜지 않아도 게임은 돌아가지만, 나갔다 오면 별이 0이 됩니다.")
end

local function fireChanged(player)
	for _, callback in ipairs(changedCallbacks) do
		task.spawn(callback, player)
	end
end

local function keyFor(player)
	return "P_" .. player.UserId
end

local function pushLeaderstats(player, profile)
	local stars = profile.starValue
	if stars then
		stars.Value = profile.data.stars
	end
end

local function loadProfile(player)
	local profile = {
		data = defaultData(),
		loaded = false,
		noSave = false,
		dirty = false,
	}
	profiles[player] = profile

	-- leaderstats (5단계 : 별 표시)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local stars = Instance.new("IntValue")
	stars.Name = "⭐"
	stars.Value = 0
	stars.Parent = leaderstats
	leaderstats.Parent = player
	profile.starValue = stars

	local loaded = nil
	if store then
		for attempt = 1, Config.Data.MaxRetries do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				loaded = result
				break
			end
			warnAboutApi(result)
			profile.noSave = true
			task.wait(Config.Data.RetryWait * attempt)
		end
	else
		profile.noSave = true
	end

	if not profiles[player] then
		return -- 불러오는 동안 나갔음
	end

	profile.data = migrate(loaded)
	profile.loaded = true
	pushLeaderstats(player, profile)
	log(player.Name, "불러오기 완료. 별", profile.data.stars, "총", profile.data.totalStars)
	fireChanged(player)
end

local function saveProfile(player, isFinal)
	local profile = profiles[player]
	if not profile or not profile.loaded or profile.noSave or not store then
		return false
	end
	if profile.saving then
		return false
	end
	profile.saving = true

	local snapshot = profile.data
	local saved = false
	for attempt = 1, Config.Data.MaxRetries do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function()
				return snapshot
			end)
		end)
		if ok then
			saved = true
			break
		end
		warn("[데이터] 저장 실패(" .. attempt .. "회): " .. tostring(err))
		if not isFinal then
			task.wait(Config.Data.RetryWait * attempt)
		end
	end

	profile.saving = false
	if saved then
		log(player.Name, "저장 완료")
	end
	return saved
end

--=========================================================
-- 밖에서 쓰는 함수들
--=========================================================
function DataService.get(player)
	local profile = profiles[player]
	if profile and profile.loaded then
		return profile.data
	end
	return nil
end

function DataService.isLoaded(player)
	local profile = profiles[player]
	return profile ~= nil and profile.loaded
end

function DataService.canSave(player)
	local profile = profiles[player]
	return profile ~= nil and profile.loaded and not profile.noSave
end

function DataService.onChanged(callback)
	table.insert(changedCallbacks, callback)
end

function DataService.addStars(player, amount)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return false
	end
	data.stars += amount
	data.totalStars += amount
	pushLeaderstats(player, profiles[player])
	fireChanged(player)
	return true
end

function DataService.spendStars(player, amount)
	local data = DataService.get(player)
	if not data or data.stars < amount then
		return false
	end
	data.stars -= amount
	pushLeaderstats(player, profiles[player])
	fireChanged(player)
	return true
end

function DataService.markDex(player, species)
	local data = DataService.get(player)
	if not data then
		return false
	end
	if data.dex[species] then
		return false
	end
	data.dex[species] = true
	fireChanged(player)
	return true -- 처음 데려온 동물
end

function DataService.hasIsland(player, islandKey)
	local data = DataService.get(player)
	if not data then
		return false
	end
	return data.islands[islandKey] == true
end

function DataService.unlockIsland(player, islandKey)
	local data = DataService.get(player)
	if not data or data.islands[islandKey] then
		return false
	end
	data.islands[islandKey] = true
	fireChanged(player)
	return true
end

function DataService.getUpgrade(player, kind)
	local data = DataService.get(player)
	if not data then
		return 0
	end
	return data.upgrades[kind] or 0
end

function DataService.setUpgrade(player, kind, level)
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.upgrades[kind] = level
	fireChanged(player)
	return true
end

function DataService.noteTrainLength(player, length)
	local data = DataService.get(player)
	if not data then
		return
	end
	if length > (data.bestTrain or 0) then
		data.bestTrain = length
		fireChanged(player)
	end
end

function DataService.setPref(player, key, value)
	local data = DataService.get(player)
	if not data then
		return
	end
	if key == "music" and type(value) == "boolean" then
		data.prefs.music = value
		fireChanged(player)
	end
end

function DataService.maxTrain(player)
	return Rules.maxTrain(DataService.getUpgrade(player, "Train"))
end

function DataService.pickupRadius(player)
	return Rules.pickupRadius(DataService.getUpgrade(player, "Magnet"))
end

function DataService.walkSpeed(player)
	return Rules.walkSpeed(DataService.getUpgrade(player, "Speed"))
end

function DataService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warnAboutApi(result)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player, false)
		profiles[player] = nil
	end)

	-- 2분마다 자동 저장
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutoSaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(saveProfile, player, false)
			end
		end
	end)

	-- 서버가 닫힐 때
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			saveProfile(player, true)
		end
		task.wait(1)
	end)

	log("시작")
end

return DataService
