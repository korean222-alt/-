--[[
	ProfileService  (Phase 7 · 8)
	한 사람의 저장 자료를 통째로 맡는다.

	  코인 · 승수 · 판수 · 연승 · 가진 스킨 · 장착 중인 스킨
	  일일 퀘스트 · 업적 · 설정 · 튜토리얼 완료 여부

	Phase 3 의 랭킹 저장은 "승자만, SetAsync 로, 그 자리에서" 저장했다.
	그래서 진 사람의 늘어난 판수는 사라졌고, 두 서버가 같은 사람을 동시에 저장하면 한쪽이 덮였다.
	여기서 고친 것

	  · UpdateAsync 를 쓴다 — 읽고 고치고 쓰는 것이 한 번에 일어나 충돌에 강하다
	  · 참가자 전원의 판수를 저장한다
	  · PlayerRemoving 과 BindToClose 에서 반드시 저장한다
	  · 주기적으로도 저장한다 (서버가 갑자기 죽어도 잃는 양이 적다)
	  · 실패하면 시간을 늘려가며 다시 시도한다
	  · schema 버전을 넣어 두어 나중에 항목이 바뀌어도 옛 자료를 읽을 수 있다

	API 서비스 접근이 꺼져 있거나 DataStore 가 막혀 있어도 게임은 그대로 돌아간다.
	그때는 "이 서버가 켜져 있는 동안"의 기록으로만 남는다.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TableConfig = require(Shared:WaitForChild("TableConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local RANKING = GameConfig.Ranking
local SKINS = GameConfig.Skins
local SKIN_ATTR = SKINS.PlayerAttributes
local PLAYER_ATTR = GameConfig.PlayerAttributes
local ECONOMY = GameConfig.Economy

local SCHEMA = 2
local AUTOSAVE = 120 -- 초
local MAX_RETRY = 4

local ProfileService = {}
ProfileService._profiles = {} -- [Player] = profile
ProfileService._dirty = {} -- [Player] = true
ProfileService._store = nil
ProfileService._started = false
ProfileService._cleaner = Utility.Cleaner.new()

ProfileService.ProfileChanged = Utility.Signal.new() -- (player, profile)

--------------------------------------------------
-- 기본값
--------------------------------------------------

local function defaultInventory()
	local owned = {}
	for kind, list in pairs({ Knife = SKINS.Knife, Barrel = SKINS.Barrel, Ghost = SKINS.Ghost }) do
		owned[kind] = {}
		for _, skin in ipairs(list) do
			if GameConfig.isFreeSkin(skin) then
				owned[kind][skin.id] = true
			end
		end
	end
	return owned
end

local function defaultProfile()
	return {
		schema = SCHEMA,
		coins = 300, -- 처음 시작하는 사람도 싼 스킨 하나는 살 수 있게
		wins = 0,
		games = 0,
		streak = 0,
		bestStreak = 0,
		bestStreakToday = 0, -- 오늘 만든 최고 연승 (일일 퀘스트용, 날짜가 바뀌면 0)
		catches = 0,
		safePicks = 0,
		duoGames = 0,
		partyGames = 0,
		owned = defaultInventory(),
		equipped = {
			Knife = SKINS.Knife[1].id,
			Barrel = SKINS.Barrel[1].id,
			Ghost = SKINS.Ghost[1].id,
		},
		daily = { date = "", quests = {}, bonusTaken = false },
		achievements = {}, -- [id] = true (보상을 받은 것)
		settings = {},
		tutorialDone = false,
		updatedAt = 0,
	}
end

-- 저장된 자료를 지금 구조에 맞춘다. 없는 항목은 기본값으로 채운다.
local function migrate(raw)
	local profile = defaultProfile()
	if typeof(raw) ~= "table" then
		return profile
	end

	for _, key in ipairs({ "coins", "wins", "games", "streak", "bestStreak", "bestStreakToday", "catches", "safePicks", "duoGames", "partyGames" }) do
		local value = tonumber(raw[key])
		if value then
			profile[key] = math.max(0, math.floor(value))
		end
	end

	if typeof(raw.owned) == "table" then
		for kind, list in pairs(profile.owned) do
			local saved = raw.owned[kind]
			if typeof(saved) == "table" then
				for id, has in pairs(saved) do
					-- 목록에서 사라진 스킨 id 는 버린다
					if has and GameConfig.findSkin(kind, id) and GameConfig.findSkin(kind, id).id == id then
						list[id] = true
					end
				end
			end
		end
	end

	if typeof(raw.equipped) == "table" then
		for kind in pairs(profile.equipped) do
			local id = raw.equipped[kind]
			local skin = id and GameConfig.findSkin(kind, id)
			if skin and skin.id == id and profile.owned[kind][id] then
				profile.equipped[kind] = id
			end
		end
	end

	if typeof(raw.daily) == "table" then
		profile.daily.date = tostring(raw.daily.date or "")
		profile.daily.bonusTaken = raw.daily.bonusTaken == true
		if typeof(raw.daily.quests) == "table" then
			for _, entry in ipairs(raw.daily.quests) do
				if typeof(entry) == "table" and entry.id then
					table.insert(profile.daily.quests, {
						id = tostring(entry.id),
						progress = math.max(0, math.floor(tonumber(entry.progress) or 0)),
						claimed = entry.claimed == true,
					})
				end
			end
		end
	end

	if typeof(raw.achievements) == "table" then
		for id, done in pairs(raw.achievements) do
			if done then
				profile.achievements[tostring(id)] = true
			end
		end
	end

	if typeof(raw.settings) == "table" then
		profile.settings = raw.settings
	end
	profile.tutorialDone = raw.tutorialDone == true
	profile.schema = SCHEMA
	return profile
end

--------------------------------------------------
-- DataStore
--------------------------------------------------

function ProfileService:_getStore()
	if not RANKING.UseDataStore then
		return nil
	end
	if self._store == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore(RANKING.DataStoreName)
		end)
		self._store = ok and store or false
		if not ok then
			warn("[CursedBarrel] DataStore 를 열 수 없어 이 서버 안에서만 기록합니다.")
		end
	end
	return self._store or nil
end

local function keyOf(userId)
	return "u_" .. tostring(userId)
end

-- 실패하면 2초 · 4초 · 8초 … 로 늘려가며 다시 시도한다.
local function retry(action)
	local wait = 2
	for attempt = 1, MAX_RETRY do
		local ok, result = pcall(action)
		if ok then
			return true, result
		end
		if attempt == MAX_RETRY then
			return false, result
		end
		task.wait(wait)
		wait *= 2
	end
	return false, nil
end

--------------------------------------------------
-- 플레이어에게 보이는 값 맞추기
--------------------------------------------------

local function publish(player, profile)
	if not player or player.Parent ~= Players then
		return
	end
	player:SetAttribute(PLAYER_ATTR.Coins, profile.coins)
	player:SetAttribute(PLAYER_ATTR.Wins, profile.wins)
	player:SetAttribute(PLAYER_ATTR.Games, profile.games)
	player:SetAttribute(PLAYER_ATTR.Level, GameConfig.levelOf(profile.wins, profile.games))
	player:SetAttribute(PLAYER_ATTR.Streak, profile.streak)
	player:SetAttribute(PLAYER_ATTR.BestStreak, profile.bestStreak)
	player:SetAttribute(PLAYER_ATTR.Loaded, true)

	for kind, attribute in pairs(SKIN_ATTR) do
		local id = profile.equipped[kind]
		if id and player:GetAttribute(attribute) ~= id then
			player:SetAttribute(attribute, id)
		end
	end

	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local function stat(name, value)
		local entry = stats:FindFirstChild(name)
		if not entry then
			entry = Instance.new("IntValue")
			entry.Name = name
			entry.Parent = stats
		end
		entry.Value = value
	end
	stat(RANKING.LeaderstatsName, profile.wins)
	stat(RANKING.StreakStatName, profile.streak)
end

function ProfileService:_touch(player)
	local profile = self._profiles[player]
	if not profile then
		return
	end
	self._dirty[player] = true
	publish(player, profile)
	self.ProfileChanged:Fire(player, profile)
end

--------------------------------------------------
-- 불러오기 / 저장
--------------------------------------------------

function ProfileService:Get(player)
	return self._profiles[player]
end

function ProfileService:_load(player)
	local profile = defaultProfile()
	local store = self:_getStore()

	if store then
		local ok, raw = retry(function()
			return store:GetAsync(keyOf(player.UserId))
		end)
		if ok then
			profile = migrate(raw)
		else
			warn(("[CursedBarrel] %s 의 저장 자료를 읽지 못했습니다. 기본값으로 시작합니다."):format(player.Name))
		end
	end

	if player.Parent ~= Players then
		return -- 읽는 사이에 나갔다
	end

	self._profiles[player] = profile
	self:_rollDaily(player, profile)
	publish(player, profile)
	self.ProfileChanged:Fire(player, profile)
	GameConfig.log(("%s 자료 불러옴 · 코인 %d · %d승 %d판")
		:format(player.Name, profile.coins, profile.wins, profile.games))
end

function ProfileService:Save(player, reason)
	local profile = self._profiles[player]
	local store = self:_getStore()
	if not profile or not store then
		self._dirty[player] = nil
		return false
	end

	profile.updatedAt = os.time()
	local snapshot = profile

	-- ★ UpdateAsync : 다른 서버가 방금 쓴 값을 읽고 그 위에 덮는다.
	--   같은 사람이 서버를 옮겨 다녀도 코인이 사라지지 않는다.
	local ok = retry(function()
		store:UpdateAsync(keyOf(player.UserId), function(stored)
			if typeof(stored) == "table" and tonumber(stored.updatedAt) and tonumber(stored.updatedAt) > (tonumber(snapshot.updatedAt) or 0) then
				-- 저장된 쪽이 더 최신이면(다른 서버가 방금 썼다) 코인만 큰 쪽을 남긴다.
				snapshot.coins = math.max(snapshot.coins, tonumber(stored.coins) or 0)
				snapshot.wins = math.max(snapshot.wins, tonumber(stored.wins) or 0)
				snapshot.games = math.max(snapshot.games, tonumber(stored.games) or 0)
			end
			return snapshot
		end)
	end)

	if not ok then
		warn(("[CursedBarrel] %s 의 자료를 저장하지 못했습니다 (%s)"):format(player.Name, tostring(reason)))
		return false
	end

	self._dirty[player] = nil
	GameConfig.log(("%s 자료 저장 (%s)"):format(player.Name, tostring(reason)))
	return true
end

function ProfileService:_release(player)
	self:Save(player, "퇴장")
	self._profiles[player] = nil
	self._dirty[player] = nil
end

--------------------------------------------------
-- 코인과 기록
--------------------------------------------------

-- 코인을 주고, 지정한 통계를 1 올린다. (퀘스트 · 업적이 이 통계를 본다)
function ProfileService:Award(player, coins, metric, metricAmount)
	local profile = self._profiles[player]
	if not profile then
		return
	end

	local amount = math.floor(tonumber(coins) or 0)
	if amount ~= 0 then
		profile.coins = math.max(0, profile.coins + amount)
	end

	if metric and profile[metric] ~= nil then
		profile[metric] += math.floor(tonumber(metricAmount) or 1)
	end

	if metric then
		self:_advanceQuests(player, profile, metric, math.floor(tonumber(metricAmount) or 1))
		self:_checkAchievements(player, profile)
	end

	self:_touch(player)
end

function ProfileService:Spend(player, coins)
	local profile = self._profiles[player]
	if not profile then
		return false
	end
	local amount = math.floor(tonumber(coins) or 0)
	if amount <= 0 then
		return true
	end
	if profile.coins < amount then
		return false
	end
	profile.coins -= amount
	self:_touch(player)
	return true
end

function ProfileService:BreakStreak(player)
	local profile = self._profiles[player]
	if not profile or profile.streak == 0 then
		return
	end
	profile.streak = 0
	self:_touch(player)
end

-- 라운드가 끝났다. 참가자 전원의 판수가 오르고, 승자는 승수와 연승이 오른다.
function ProfileService:RecordRound(gameTable, roster, winner)
	local scale = TableConfig.getRewardScale(gameTable and gameTable.typeName)
	local typeName = gameTable and gameTable.typeName

	for _, player in ipairs(roster or {}) do
		local profile = self._profiles[player]
		if profile and player.Parent == Players then
			profile.games += 1
			if typeName == "Duo2" then
				profile.duoGames += 1
			elseif typeName == "Party6" then
				profile.partyGames += 1
			end

			if player ~= winner then
				profile.coins += math.floor(ECONOMY.ParticipationReward * scale)
				self:_advanceQuests(player, profile, "games", 1)
				if typeName == "Duo2" then
					self:_advanceQuests(player, profile, "duoGames", 1)
				elseif typeName == "Party6" then
					self:_advanceQuests(player, profile, "partyGames", 1)
				end
				self:_checkAchievements(player, profile)
				self:_touch(player)
			end
		end
	end

	if winner and winner.Parent == Players then
		local profile = self._profiles[winner]
		if profile then
			profile.wins += 1
			profile.streak += 1
			profile.bestStreak = math.max(profile.bestStreak, profile.streak)
			profile.bestStreakToday = math.max(profile.bestStreakToday or 0, profile.streak)

			local bonusSteps = math.min(profile.streak - 1, ECONOMY.StreakBonusCap)
			local reward = ECONOMY.WinReward + ECONOMY.StreakBonus * math.max(0, bonusSteps)
			profile.coins += math.floor(reward * scale)

			self:_advanceQuests(winner, profile, "games", 1)
			self:_advanceQuests(winner, profile, "wins", 1)
			self:_advanceQuests(winner, profile, "bestStreakToday", 0, profile.streak)
			if typeName == "Duo2" then
				self:_advanceQuests(winner, profile, "duoGames", 1)
			elseif typeName == "Party6" then
				self:_advanceQuests(winner, profile, "partyGames", 1)
			end
			self:_checkAchievements(winner, profile)
			self:_touch(winner)
		end
	end
end

--------------------------------------------------
-- 인벤토리
--------------------------------------------------

function ProfileService:Owns(player, kind, id)
	local profile = self._profiles[player]
	if not profile or not profile.owned[kind] then
		return false
	end
	return profile.owned[kind][id] == true
end

function ProfileService:Grant(player, kind, id)
	local profile = self._profiles[player]
	local skin = GameConfig.findSkin(kind, id)
	if not profile or not skin or skin.id ~= id or not profile.owned[kind] then
		return false
	end
	profile.owned[kind][id] = true
	self:_touch(player)
	return true
end

function ProfileService:Equip(player, kind, id)
	local profile = self._profiles[player]
	if not profile or not profile.equipped[kind] then
		return false, GameConfig.RejectMessages.BadSlot
	end
	local skin = GameConfig.findSkin(kind, id)
	if not skin or skin.id ~= id then
		return false, GameConfig.RejectMessages.BadSlot
	end
	if not profile.owned[kind][id] then
		return false, GameConfig.RejectMessages.NotOwned
	end
	profile.equipped[kind] = id
	self:_touch(player)
	return true, nil
end

function ProfileService:GetOwnedList(player, kind)
	local profile = self._profiles[player]
	if not profile or not profile.owned[kind] then
		return {}
	end
	return profile.owned[kind]
end

--------------------------------------------------
-- 일일 퀘스트 (Phase 8)
--------------------------------------------------

function ProfileService:_rollDaily(player, profile)
	if not GameConfig.Quests.Enabled then
		return
	end
	local today = Utility.today()
	if profile.daily.date == today and #profile.daily.quests > 0 then
		return
	end

	local pool = table.clone(GameConfig.Quests.Pool)
	-- UserId 와 날짜를 섞은 씨앗을 쓴다. 같은 사람에게는 하루 내내 같은 퀘스트가 나온다.
	local seed = 0
	for index = 1, #today do
		seed += today:byte(index) * index
	end
	local random = Random.new(player.UserId % 1000000 + seed)
	Utility.shuffle(pool, random)

	profile.daily = { date = today, quests = {}, bonusTaken = false }
	for index = 1, math.min(GameConfig.Quests.DailyCount, #pool) do
		table.insert(profile.daily.quests, { id = pool[index].id, progress = 0, claimed = false })
	end

	-- 하루 한 번 접속 보상
	profile.coins += ECONOMY.DailyBonus
	profile.daily.bonusTaken = true

	-- 어제의 "오늘 최고 연승" 기록은 새 날이 되면 0 부터 다시 센다.
	profile.bestStreakToday = 0
	self._dirty[player] = true
end

local function questDefinition(id)
	for _, entry in ipairs(GameConfig.Quests.Pool) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function ProfileService:_advanceQuests(player, profile, metric, amount, absolute)
	if not GameConfig.Quests.Enabled then
		return
	end
	for _, entry in ipairs(profile.daily.quests or {}) do
		local definition = questDefinition(entry.id)
		if definition and definition.metric == metric and not entry.claimed then
			if absolute then
				entry.progress = math.max(entry.progress, math.floor(absolute))
			else
				entry.progress += math.floor(amount or 1)
			end
			entry.progress = math.min(entry.progress, definition.goal)
		end
	end
end

function ProfileService:ClaimQuest(player, questId)
	local profile = self._profiles[player]
	if not profile then
		return false, "자료를 아직 읽지 못했습니다"
	end
	for _, entry in ipairs(profile.daily.quests or {}) do
		if entry.id == questId then
			local definition = questDefinition(questId)
			if not definition then
				return false, "없는 퀘스트입니다"
			end
			if entry.claimed then
				return false, "이미 받았습니다"
			end
			if entry.progress < definition.goal then
				return false, "아직 다 하지 못했습니다"
			end
			entry.claimed = true
			profile.coins += definition.reward
			self:_touch(player)
			return true, definition.reward
		end
	end
	return false, "없는 퀘스트입니다"
end

function ProfileService:GetQuests(player)
	local profile = self._profiles[player]
	if not profile then
		return {}
	end
	local list = {}
	for _, entry in ipairs(profile.daily.quests or {}) do
		local definition = questDefinition(entry.id)
		if definition then
			table.insert(list, {
				id = entry.id,
				text = definition.text,
				goal = definition.goal,
				reward = definition.reward,
				progress = entry.progress,
				claimed = entry.claimed,
			})
		end
	end
	return list
end

--------------------------------------------------
-- 업적 (Phase 8)
-- 조건을 채우면 그 자리에서 코인이 들어온다. 따로 받을 필요가 없다.
--------------------------------------------------

function ProfileService:_checkAchievements(player, profile)
	for _, entry in ipairs(GameConfig.Achievements) do
		if not profile.achievements[entry.id] then
			local value = tonumber(profile[entry.metric]) or 0
			if value >= entry.goal then
				profile.achievements[entry.id] = true
				profile.coins += entry.reward
				GameConfig.log(("%s 업적 달성: %s (+%d)"):format(player.Name, entry.text, entry.reward))
			end
		end
	end
end

function ProfileService:GetAchievements(player)
	local profile = self._profiles[player]
	if not profile then
		return {}
	end
	local list = {}
	for _, entry in ipairs(GameConfig.Achievements) do
		table.insert(list, {
			id = entry.id,
			text = entry.text,
			goal = entry.goal,
			reward = entry.reward,
			progress = math.min(tonumber(profile[entry.metric]) or 0, entry.goal),
			done = profile.achievements[entry.id] == true,
		})
	end
	return list
end

--------------------------------------------------
-- 시작
--------------------------------------------------

function ProfileService:Start()
	if self._started then
		return
	end
	self._started = true

	local function join(player)
		task.spawn(function()
			local ok, err = pcall(function()
				self:_load(player)
			end)
			if not ok then
				warn("[CursedBarrel] 자료 불러오기 실패: " .. tostring(err))
				self._profiles[player] = defaultProfile()
				publish(player, self._profiles[player])
			end
		end)
	end

	self._cleaner:add(Players.PlayerAdded:Connect(join))
	for _, player in ipairs(Players:GetPlayers()) do
		join(player)
	end

	self._cleaner:add(Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end))

	-- 주기적 저장. 서버가 갑자기 죽어도 잃는 양이 적다.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in pairs(self._dirty) do
				if player.Parent == Players then
					self:Save(player, "자동 저장")
				end
			end
		end
	end)

	-- 서버가 닫힐 때. Roblox 는 여기서 최대 30초를 준다.
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = {}
		for player in pairs(self._profiles) do
			table.insert(pending, player)
		end
		for _, player in ipairs(pending) do
			task.spawn(function()
				self:Save(player, "서버 종료")
			end)
		end
		task.wait(math.min(6, #pending * 0.6 + 1))
	end)

	GameConfig.log("ProfileService 시작 완료")
end

return ProfileService
