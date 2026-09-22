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

local Release = require(Shared.ReleaseConfig)
local SCHEMA = 3
local AUTOSAVE = 120 -- 초
local MAX_RETRY = 4

local ProfileService = {}
ProfileService._profiles = {} -- [Player] = profile
ProfileService._writable = {}
ProfileService._saving = {}
ProfileService._revisions = {}
ProfileService._receiptBusy = {}
ProfileService._session = game.JobId .. game:GetService("HttpService"):GenerateGUID(false)
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
	for kind, list in pairs({ Knife = SKINS.Knife, Barrel = SKINS.Barrel, Ghost = SKINS.Ghost, Chair=SKINS.Chair, Elimination=SKINS.Elimination, Victory=SKINS.Victory }) do
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
            Chair="classic", Elimination="classic", Victory="classic",
		},
		daily = { date = "", quests = {}, bonusTaken = false },
		achievements = {}, -- [id] = true (보상을 받은 것)
		settings = table.clone(Release.Settings),
        receipts = {}, consumables = {},
        weekly={week=-1,progress={},claimed={}},
        season={id=Release.Season.Id,xp=0,claimed={}},
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
		for key, default in pairs(Release.Settings) do
            if typeof(raw.settings[key])==typeof(default) then profile.settings[key]=raw.settings[key] end
        end
	end
	if typeof(raw.receipts)=="table" then profile.receipts=raw.receipts end
 if typeof(raw.consumables)=="table" then profile.consumables=raw.consumables end
 if typeof(raw.weekly)=="table" and typeof(raw.weekly.progress)=="table" and typeof(raw.weekly.claimed)=="table" then profile.weekly=raw.weekly end
 if typeof(raw.season)=="table" and raw.season.id==Release.Season.Id and typeof(raw.season.claimed)=="table" then profile.season=raw.season;profile.season.xp=tonumber(raw.season.xp) or 0 end
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
		local ok, result = pcall(function()
            local deadline=os.clock()+5
            while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)<1 do
                if os.clock()>deadline then error("DataStore request budget exhausted") end
                task.wait(0.25)
            end
            return action()
        end)
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
    self._revisions[player]=(self._revisions[player] or 0)+1
	publish(player, profile)
	self.ProfileChanged:Fire(player, profile)
end

--------------------------------------------------
-- 불러오기 / 저장
--------------------------------------------------

function ProfileService:Get(player)
	return self._profiles[player]
end

local function deepCopy(value)
 if typeof(value)~="table" then return value end
 local copy={};for k,v in pairs(value) do copy[k]=deepCopy(v) end;return copy
end
function ProfileService:CanPurchase(player)
 return self._writable[player]==true and self._profiles[player]~=nil and not self._closingPlayer[player]
end
ProfileService._closingPlayer={}
function ProfileService:_load(player)
 local profile=defaultProfile()
 local store=self:_getStore()
 local writable=false
 if store then
  local ok,raw=retry(function()
   local locked=false
   local result=store:UpdateAsync(keyOf(player.UserId),function(old)
    if typeof(old)=="table" and typeof(old.session)=="table" and old.session.id~=self._session and (tonumber(old.session.expires) or 0)>os.time() then locked=true;return nil end
    locked=false
    if typeof(old)=="table" and (tonumber(old.schema) or 0)>SCHEMA then error("Profile requires newer game version") end
    local data=migrate(old)
    data.session={id=self._session,expires=os.time()+300}
    return data
   end)
   if locked or not result then error("Profile session busy") end
   return result
  end)
  if ok then profile=migrate(raw);writable=true end
 end
 -- Never allow default fallback data to overwrite a real profile.
 if not writable and not RunService:IsStudio() then
  if player.Parent==Players then player:Kick("저장 데이터를 안전하게 불러오지 못했습니다. 잠시 후 다시 접속해 주세요. / Data unavailable; please rejoin.") end
  return
 end
 self._profiles[player]=profile
 self._writable[player]=writable
 if player.Parent~=Players then self:_release(player);return end
 player:SetAttribute("DataWritable",writable)
 self:_rollDaily(player,profile)
 self:_rollWeekly(profile)
 self:_touch(player)
end
function ProfileService:Save(player,reason,release)
 if not self._writable[player] then return false end
 local deadline=os.clock()+24
 while self._saving[player] do
  if os.clock()>deadline then return false end
  task.wait(0.05)
 end
 local profile=self._profiles[player];local store=self:_getStore()
 if not profile or not store then return false end
 self._saving[player]=true
 local revision=self._revisions[player] or 0
 local snapshot=deepCopy(profile);snapshot.updatedAt=os.time()
 if release then snapshot.session=nil else snapshot.session={id=self._session,expires=os.time()+300} end
 local lost=false
 local ok,result=retry(function()
  local saved=store:UpdateAsync(keyOf(player.UserId),function(old)
   if typeof(old)~="table" or typeof(old.session)~="table" or old.session.id~=self._session then lost=true;return nil end
   return snapshot
  end)
  return saved
 end)
 self._saving[player]=nil
 if lost then
  self._writable[player]=false
  if player.Parent==Players then player:SetAttribute("DataWritable",false);player:Kick("데이터 세션이 변경되었습니다. 다시 접속해 주세요.") end
  return false
 end
 if not ok or not result then
  warn("[CursedBarrel] Save failed: "..tostring(reason));return false
 end
 if (self._revisions[player] or 0)==revision then self._dirty[player]=nil end
 return true
end
function ProfileService:_release(player)
 if self._closingPlayer[player] then return end
 self._closingPlayer[player]=true
 -- Roster removal must break streaks before the final snapshot is taken.
 task.wait()
 local deadline=os.clock()+24
 while self._receiptBusy[player] and os.clock()<deadline do task.wait(0.05) end
 self:Save(player,"release",true)
 self._profiles[player]=nil;self._dirty[player]=nil;self._writable[player]=nil
 self._revisions[player]=nil;self._closingPlayer[player]=nil
end
function ProfileService:ProcessReceipt(player,receipt,grant)
 if not self:CanPurchase(player) or self._receiptBusy[player] then return false end
 self._receiptBusy[player]=true
 local ok,result=pcall(function()
  local profile=self._profiles[player];local id=tostring(receipt.PurchaseId)
  if not profile.receipts[id] then
   -- Registered grants are non-yielding profile mutations only.
   local draft=deepCopy(profile)
   if grant(draft,receipt)~=true then return false end
   draft.receipts[id]=true
   self._profiles[player]=draft
   self:_touch(player)
  end
  -- Includes both the grant and receipt ID in the same saved value.
  return self:Save(player,"receipt")
 end)
 self._receiptBusy[player]=nil
 if not ok then warn("[CursedBarrel] Receipt: "..tostring(result));return false end
 return result==true
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

	self:_rollDaily(player,profile)
    self:_rollWeekly(profile)
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
function ProfileService:RecordRound(gameTable, roster, winner, forfeited, bonuses)
	local scale = TableConfig.getRewardScale(gameTable and gameTable.typeName)
	local typeName = gameTable and gameTable.typeName

	for _, player in ipairs(roster or {}) do
		local profile = self._profiles[player]
		if profile and player.Parent == Players and not (forfeited and forfeited[player]) then
            self:_rollDaily(player,profile)
            self:_rollWeekly(profile)
			profile.games += 1
			if typeName == "Duo2" then
				profile.duoGames += 1
			elseif typeName == "Party6" or typeName == "PartyCards6" then
				profile.partyGames += 1
			end

			if player ~= winner then
				profile.coins += math.floor(ECONOMY.ParticipationReward * scale * (1 + ((bonuses or {})[player] or 0)))
				self:_advanceQuests(player, profile, "games", 1)
				if typeName == "Duo2" then
					self:_advanceQuests(player, profile, "duoGames", 1)
				elseif typeName == "Party6" or typeName == "PartyCards6" then
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
			profile.coins += math.floor(reward * scale * (1 + ((bonuses or {})[winner] or 0)))

			self:_advanceQuests(winner, profile, "games", 1)
			self:_advanceQuests(winner, profile, "wins", 1)
			self:_advanceQuests(winner, profile, "bestStreakToday", 0, profile.streak)
			if typeName == "Duo2" then
				self:_advanceQuests(winner, profile, "duoGames", 1)
			elseif typeName == "Party6" or typeName == "PartyCards6" then
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
 self:_rollDaily(player,profile);self:_rollWeekly(profile)
 for _, q in ipairs(Release.Weekly) do
  if q.metric==metric then profile.weekly.progress[q.id]=math.min(q.goal,(profile.weekly.progress[q.id] or 0)+(amount or 0)) end
 end
 if Release.seasonActive(os.time()) then
  local xp=({games=20,wins=35,catches=3})[metric] or 0
  profile.season.xp=profile.season.xp+xp*(amount or 0)
 end
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
	self:_rollDaily(player,profile)
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
    if profile then self:_rollDaily(player,profile) end
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

function ProfileService:_rollWeekly(profile)
 local week=math.floor((os.time()+3*86400)/604800) -- Monday 00:00 UTC
 if profile.weekly.week~=week then profile.weekly={week=week,progress={},claimed={}} end
end
function ProfileService:ClaimWeekly(player,id)
 local p=self:Get(player);if not p then return false end
 self:_rollWeekly(p)
 for _,q in ipairs(Release.Weekly) do
  if q.id==id and not p.weekly.claimed[id] and (p.weekly.progress[id] or 0)>=q.goal then
   p.weekly.claimed[id]=true;p.coins=p.coins+q.reward;self:_touch(player);return true
  end
 end
 return false
end
function ProfileService:ClaimSeason(player,index)
 local p=self:Get(player);local tier=Release.Season.Tiers[index]
 if not p or not tier or not Release.seasonActive(os.time()) or p.season.claimed[tostring(index)] or p.season.xp<tier.xp then return false end
 p.season.claimed[tostring(index)]=true
 if tier.coins then p.coins=p.coins+tier.coins end
 if tier.kind then p.owned[tier.kind][tier.skin]=true end
 self:_touch(player);return true
end
function ProfileService:Start()
 if self._started then return end;self._started=true
 local function join(player)
  task.spawn(function()
   local ok,err=pcall(function() self:_load(player) end)
   if not ok then warn("[CursedBarrel] Load: "..tostring(err));if player.Parent==Players then player:Kick("데이터 로딩 오류. 다시 접속해 주세요.") end end
   -- Renew locks even when no coins or stats have changed.
   task.wait(math.random(30,60))
   while player.Parent==Players and self._profiles[player] do self:Save(player,"autosave");task.wait(60) end
  end)
 end
 self._cleaner:add(Players.PlayerAdded:Connect(join))
 for _,p in ipairs(Players:GetPlayers()) do join(p) end
 self._cleaner:add(Players.PlayerRemoving:Connect(function(p) self:_release(p) end))
 game:BindToClose(function()
  local pending=0
  for p in pairs(self._profiles) do
   pending=pending+1
   task.spawn(function() self:_release(p);pending=pending-1 end)
  end
  local deadline=os.clock()+27
  while (pending>0 or next(self._saving)~=nil or next(self._closingPlayer)~=nil) and os.clock()<deadline do task.wait(0.05) end
 end)
end
return ProfileService
