--[[
	WorldService  (Phase 12)
	항해 시계 · 크라켄 습격 · 오늘의 행운 테이블.

	항해 시계
	  · 15분마다 한 바퀴 : 낮 → 노을 → 밤 → 안개 → 폭풍 → 새벽 (GameConfig.World.Phases)
	  · 지금 단계를 workspace Attribute 로 알린다. 클라이언트(WorldController)가 하늘 · 비 · 번개를 그린다.
	  · 단계마다 판 규칙(mods)이 바뀐다. RoundService 가 GameConfig.worldMods() 로 읽는다.

	크라켄 습격 (폭풍 단계)
	  · 크라켄이 몇 초마다 다리로 갑판을 내려친다. 어디를 언제 칠지는 서버가 정해 모두에게 알린다.
	    (그래서 모든 사람이 같은 자리 같은 순간에 "쾅"을 본다)
	  · 대포(CannonService)로 맞히면 체력이 깎인다. 0 이 되면 물러나고, 참여한 사람 모두 코인을 받는다.
	  · 내려치기는 연출이다. 사람을 밀거나 다치게 하지 않는다.

	행운의 테이블
	  · 날짜(UTC)마다 테이블 하나를 고른다. 그 테이블은 보물 폭발 확률 2배. 토너먼트 테이블은 빼고 고른다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))
local KrakenTargets = require(Shared:WaitForChild("KrakenTargets"))

local ProfileService = require(script.Parent.ProfileService)
local TableService = require(script.Parent.TableService)

local WORLD = GameConfig.World
local RAID = GameConfig.Raid
local TABLE_ATTR = GameConfig.TableAttributes

local WorldService = {}
WorldService._started = false
WorldService.origin = 0
WorldService.scale = 1
WorldService.phase = nil
WorldService.lap = -1
WorldService.raid = nil
WorldService.slams = {} -- [id] = slam
WorldService.luckyDay = nil
WorldService._random = Random.new()
WorldService._cue = nil

local function remote(name)
	local folder = ReplicatedStorage.CursedBarrel:WaitForChild(GameConfig.Remotes.Folder)
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r
end

local function setWorld(name, value)
	if workspace:GetAttribute(name) ~= value then
		workspace:SetAttribute(name, value)
	end
end

function WorldService:_fire(kind, data)
	if self._cue then
		self._cue:FireAllClients(kind, data)
	end
end

--------------------------------------------------
-- 시계
--------------------------------------------------

-- 시계가 흐른 "게임 속 초" (Studio 에서 TimeScale 을 줄이면 빨리 흐른다)
function WorldService:Elapsed(now)
	return ((now or GameConfig.now()) - self.origin) / self.scale
end

function WorldService:CurrentPhase()
	return self.phase or WORLD.Phases[1]
end

function WorldService:_applyPhase(phase, into, duration, lap, now)
	self.phase = phase
	self.lap = lap
	WORLD.current = phase
	local startedAt = now - into * self.scale
	local endsAt = startedAt + duration * self.scale
	setWorld("WorldPhase", phase.id)
	setWorld("WorldPhaseStartedAt", startedAt)
	setWorld("WorldPhaseEndsAt", endsAt)
	setWorld("WorldTimeScale", self.scale)
	self:_fire("Phase", { id = phase.id, name = phase.name, icon = phase.icon, blurb = phase.blurb, endsAt = endsAt })
	GameConfig.log(("항해 시계 → %s (%d초)"):format(phase.name, duration))

	if phase.mods.raid and RAID.Enabled then
		-- 지난 폭풍의 습격 기록은 치운다
		if self.raid and self.raid.result then
			self.raid = nil
		end
		self.raidStartAt = startedAt + RAID.StartDelay * self.scale
		self.raidEndAt = endsAt - RAID.EndBefore * self.scale
	else
		self.raidStartAt = nil
		if self.raid and not self.raid.result then
			self:_endRaid("escaped")
		end
	end
end

function WorldService:Tick(now)
	now = now or GameConfig.now()
	if WORLD.Enabled then
		local phase, into, duration, lap = GameConfig.worldPhaseAt(self:Elapsed(now))
		if phase ~= self.phase or lap ~= self.lap then
			self:_applyPhase(phase, into, duration, lap, now)
		end
		if self.raidStartAt and now >= self.raidStartAt and not self.raid then
			self:_startRaid(now, self.raidEndAt)
		end
		self:_raidTick(now)
	end
	self:_luckyTick()
end

--------------------------------------------------
-- 크라켄 습격
--------------------------------------------------

function WorldService:_startRaid(now, endsAt)
	local count = math.max(1, #Players:GetPlayers())
	local hp = RAID.BaseHP + RAID.HPPerPlayer * count
	self.raid = {
		hp = hp,
		max = hp,
		startedAt = now,
		endsAt = endsAt,
		hits = {}, -- [Player] = 맞힌 횟수
		nextSlamAt = now + 2.5,
		slamId = 0,
		lastZone = 0,
		result = nil,
	}
	table.clear(self.slams)
	setWorld("RaidActive", true)
	setWorld("RaidHP", hp)
	setWorld("RaidMaxHP", hp)
	setWorld("RaidEndsAt", endsAt)
	setWorld("RaidResult", "")
	self:_fire("Raid", { state = "start", hp = hp, max = hp, endsAt = endsAt })
	GameConfig.log(("크라켄 습격 시작 · 체력 %d"):format(hp))
end

function WorldService:_slam(now)
	local raid = self.raid
	local zones = RAID.SlamZones
	local pick = self._random:NextInteger(1, #zones)
	if pick == raid.lastZone and #zones > 1 then
		pick = pick % #zones + 1
	end
	raid.lastZone = pick
	raid.slamId += 1
	local zone = zones[pick]
	local slam = {
		id = raid.slamId,
		side = zone.side,
		z = zone.z,
		at = now + RAID.SlamWindup,
		windup = RAID.SlamWindup,
		linger = RAID.SlamLinger,
		retract = RAID.SlamRetract,
		inset = RAID.SlamInset,
	}
	self.slams[slam.id] = slam
	local every = RAID.SlamEvery
	raid.nextSlamAt = now + every[1] + self._random:NextNumber() * (every[2] - every[1])
	self:_fire("Slam", slam)
	return slam
end

function WorldService:_raidTick(now)
	local raid = self.raid
	if not raid then
		return
	end
	-- 끝난 내려치기는 지운다
	for id, slam in pairs(self.slams) do
		if now > slam.at + slam.linger + slam.retract + 3 then
			self.slams[id] = nil
		end
	end
	if raid.result then
		return
	end
	if now >= raid.endsAt then
		self:_endRaid("escaped")
		return
	end
	if now >= raid.nextSlamAt then
		self:_slam(now)
	end
end

function WorldService:IsRaidActive()
	return self.raid ~= nil and self.raid.result == nil
end

function WorldService:RaidRise()
	return self:IsRaidActive() and KrakenTargets.HeadRaidRise or 0
end

function WorldService:Agitation()
	return KrakenTargets.agitation(self:CurrentPhase().id, self:IsRaidActive())
end

-- 지금 대포로 막을 수 있는 내려치기들
function WorldService:ActiveSlams()
	local list = {}
	if not self:IsRaidActive() then
		return list
	end
	for _, slam in pairs(self.slams) do
		table.insert(list, slam)
	end
	return list
end

-- 대포가 크라켄을 맞혔다. (CannonService 가 판정을 끝낸 뒤 부른다)
function WorldService:Damage(player, kind, slamId)
	local raid = self.raid
	if not raid or raid.result then
		return 0
	end
	local amount = RAID.HitDamage
	if kind == "eye" then
		amount = RAID.EyeDamage
	elseif kind == "slam" then
		amount = RAID.BlockDamage
		local slam = self.slams[slamId]
		if slam and not slam.blockedAt then
			slam.blockedAt = GameConfig.now()
			self:_fire("SlamBlocked", { id = slam.id, blockedAt = slam.blockedAt, userId = player.UserId, name = player.DisplayName or player.Name })
		end
	end
	raid.hits[player] = (raid.hits[player] or 0) + 1
	raid.hp = math.max(0, raid.hp - amount)
	setWorld("RaidHP", raid.hp)
	if raid.hp <= 0 then
		self:_endRaid("victory")
	end
	return amount
end

function WorldService:_endRaid(result)
	local raid = self.raid
	if not raid or raid.result then
		return
	end
	raid.result = result
	setWorld("RaidActive", false)
	setWorld("RaidResult", result)
	-- 아직 내려치지 않은 다리는 물러난다
	local now = GameConfig.now()
	for _, slam in pairs(self.slams) do
		if not slam.blockedAt and now < slam.at then
			slam.blockedAt = now
			self:_fire("SlamBlocked", { id = slam.id, blockedAt = now, userId = 0 })
		end
	end

	local rewards = {}
	for player, hits in pairs(raid.hits) do
		if player.Parent == Players then
			local coins = 0
			if result == "victory" then
				coins = math.min(RAID.WinCoinsCap, RAID.WinCoins + hits * RAID.CoinsPerHit)
				ProfileService:Award(player, coins, "raidWins")
			elseif hits > 0 then
				coins = RAID.EscapeCoins
				ProfileService:Award(player, coins)
			end
			rewards[player.UserId] = coins
		end
	end
	self:_fire("Raid", { state = result, rewards = rewards })
	GameConfig.log(("크라켄 습격 종료 · %s"):format(result))
	-- 다음 폭풍까지 비운다 (단계가 바뀔 때 새로 만든다)
	self.raidStartAt = nil
end

--------------------------------------------------
-- 오늘의 행운 테이블
--------------------------------------------------

function WorldService.luckyIndex(day, count)
	if count <= 0 then
		return 0
	end
	local hash = 0
	for index = 1, #day do
		hash = (hash * 31 + day:byte(index)) % 1000003
	end
	return hash % count + 1
end

function WorldService:_luckyTick()
	if not GameConfig.Lucky.Enabled then
		return
	end
	local tables = {}
	for _, gameTable in ipairs(TableService:GetAllTables()) do
		if not gameTable.destroyed and not gameTable.config.Tournament then
			table.insert(tables, gameTable)
		end
	end
	local day = Utility.today()
	local key = day .. ":" .. #tables
	if key == self.luckyDay then
		return
	end
	self.luckyDay = key
	table.sort(tables, function(a, b)
		return tostring(a.tableId) < tostring(b.tableId)
	end)
	local chosen = WorldService.luckyIndex(day, #tables)
	for index, gameTable in ipairs(tables) do
		gameTable:SetTableAttribute(TABLE_ATTR.Lucky, index == chosen)
	end
	if tables[chosen] then
		GameConfig.log(("오늘의 행운 테이블: %s"):format(tostring(tables[chosen].tableId)))
	end
end

--------------------------------------------------
-- 시작
--------------------------------------------------

function WorldService:Start()
	if self._started then
		return
	end
	self._started = true
	self._cue = remote(GameConfig.Remotes.WorldCue)

	local studio = RunService:IsStudio()
	self.scale = studio and math.max(0.05, tonumber(WORLD.StudioTimeScale) or 1) or 1
	local cycle = GameConfig.worldCycleLength()
	local offset = self._random:NextNumber() * cycle -- 서버마다 시작 단계를 흔든다
	if studio and WORLD.StudioStartPhase then
		offset = 0
		for _, phase in ipairs(WORLD.Phases) do
			if phase.id == WORLD.StudioStartPhase then
				offset += 1
				break
			end
			offset += phase.duration
		end
	end
	self.origin = GameConfig.now() - offset * self.scale
	setWorld("RaidActive", false)
	setWorld("RaidResult", "")

	self:Tick()
	task.spawn(function()
		while self._started do
			task.wait(0.25)
			local ok, err = pcall(self.Tick, self)
			if not ok then
				warn("[CursedBarrel] 항해 시계 오류: " .. tostring(err))
			end
		end
	end)

	-- 새로 들어온 사람에게 지금 습격 중인 내려치기를 알려 준다
	Players.PlayerAdded:Connect(function(player)
		for _, slam in pairs(self.slams) do
			self._cue:FireClient(player, "Slam", slam)
		end
	end)

	GameConfig.log("WorldService 시작 완료")
end

return WorldService
