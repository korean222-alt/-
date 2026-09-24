--[[
	RoundService
	테이블 하나마다 "라운드 진행 담당자(Round)"를 붙인다.

	Phase 2  카운트다운 · 턴 순서
	Phase 3  칼 슬롯 · 위험 자리 · 탈락 · 승리
	Phase 5  해적 잡기
	Phase 6  ★ 잡기 성공 뒤에도 통 안에 해적이 남아 있도록 고침
	Phase 7  코인 보상 · 테이블 통 스킨 결정
	Phase 8  연승 · 퀘스트 집계 · 방해 아이템 효과

	───────────────────────────────────────────────
	Phase 6 에서 고친 버그 (제보해 주신 것)

	  증상 : 해적이 튀어나와서 잡고 계속 이어가면, 그 판이 끝날 때까지 해적이 다시 안 나온다.
	         한참 뒤에 갑자기 통이 초기화되고, 그 뒤에도 해적이 안 나온다.

	  원인 : 위험 자리는 통을 채울 때 한 번만 뽑았고(4인 테이블은 한 자리),
	         잡기에 성공하면 통을 다시 채우지 않았다.
	         그런데 그 한 자리는 이미 칼이 꽂혀 "고를 수 없는 자리"가 되어 있었다.
	         → 통에 남은 자리가 전부 안전해진다. 칼을 다 뽑을 때까지 아무 일도 일어나지 않는다.
	         → 칼을 다 뽑으면 그제야 통을 새로 채우는데(이게 "갑자기 초기화"로 보였다),
	           그 사이에 이미 사람이 다 지쳐서 판이 늘어졌다.

	  고침 : 세 겹으로 막는다.
	         1. 잡기에 성공하면 아직 아무도 꽂지 않은 자리 중 하나에 해적을 새로 숨긴다.
	            (요청하신 "잡으면 해적이 하나 더, 안 꽂은 곳에")
	         2. 턴을 시작할 때마다 통 안에 살아 있는 해적이 몇인지 세고,
	            테이블 정원보다 적으면 그 자리에서 채워 넣는다. 어떤 경로로 새어도 복구된다.
	         3. 해적 수는 좌석 수를 따라간다. 6인 테이블은 두 마리.

	  ★ 여전히 지키는 것: 어느 자리가 위험한지는 서버 메모리에만 있다.
	    Attribute 로도 RemoteEvent 로도 나가지 않는다. 나가는 것은 "몇 마리인지"까지다.

	───────────────────────────────────────────────
	Phase 10 에서 고친 버그 (제보해 주신 것)

	  증상 : 해적을 잡고 나서 또 해적을 만나도 매번 잡기 타이밍이 떠서 판이 끝나지 않는다.

	  원인 : Phase 6 의 고침으로 잡을 때마다 해적이 다시 숨는 것은 맞았다.
	         그런데 해적을 만날 때마다 잡기 기회도 새로 열렸고, 창이 0.8초 + 여유 0.4초로 넉넉했다.
	         모두가 매번 잡을 수 있으니 아무도 탈락하지 않았다.

	  고침 : · 한 사람은 한 판에 한 번만 잡을 수 있다. (GameConfig.Catch.PerPlayer)
	           두 번째로 해적을 만나면 잡기 창 없이 탈락한다. 인원이 N 명이면 잡기는 많아야 N 번이다.
	         · 누가 잡을 때마다 다음 창이 좁아진다. 창이 열리는 순간도 매번 조금씩 달라서 박자를 외울 수 없다.
	         · 창이 닫힌 뒤의 여유를 0.4초 → 0.12초로 줄였다. (지연 보정은 따로 받는다)

	Phase 10 에서 늘어난 것
	  · 배짱 : 안전한 자리를 뽑은 뒤 "한 번 더" 찌를 수 있다. 살아남으면 보너스 코인.
	  · 현상금 : 판 동안 쌓이고, 마지막 생존자가 가져간다.
	  · 기권승 : 상대가 전부 스스로 나가서 이긴 짧은 판은 승리 · 연승 · 현상금을 주지 않는다.
	  · 누가 나가는 순간에 다음 차례가 한 명 건너뛰던 문제, 칼이 다 떨어진 통으로 턴이 시작되던 문제를 고쳤다.
	  · 봉인 카드가 "다음 사람"의 선택까지 유지된다. (전에는 봉인한 사람이 고르는 순간 풀려서 쓸모가 없었다)

───────────────────────────────────────────────
Phase 11 에서 바뀐 규칙 (요청하신 것)

  · 해적은 몇 번이든 잡을 수 있다. 대신 내가 잡을 때마다 내 다음 해적이 빨라진다.
    (창이 좁아지고, 튀어나오기까지의 시간도 짧아진다) GameConfig.Catch.MaxPerPlayer 번을 잡은 사람의
    다음 해적은 "분노한 해적"이라 잡을 수 없다. 그래서 판은 여전히 반드시 끝난다.
  · 해적이 나오기 전에 누르면 그 자리에서 실패다. (칼을 고른 직후 0.3초 안의 입력은 버린다)
  · 기권승은 승리 보상과 현상금을 절반 받는다. 남은 절반은 이 테이블의 다음 판으로 이월된다.
  · 보물 폭발 : 안전한 자리를 뽑을 때마다 작은 확률로 현상금이 크게 뛴다.
  · AI 선원 : BotService 가 앉힌 AI 도 사람과 같은 규칙으로 차례를 치른다. AI 가 낀 판은 연습 판이다.

Phase 12 에서 더한 것
  · 항해 시계의 판 규칙 (GameConfig.worldMods) : 현상금 배율 · 보물 폭발 배율 · 해적이 나오는 속도 · 해적 추가
  · 오늘의 행운 테이블 : 보물 폭발 확률 2배
  · 연습 판(Tutorial) : 처음 온 사람의 첫 해적은 창이 넓고 나오는 시간이 일정하다
  · 관전 예측 창(PredictOpen) · 탈락 순서(outOrder) · 판이 끝났다는 신호(RoundSettled)
    → PredictionService · TournamentService 가 이 신호를 듣는다
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TableConfig = require(Shared:WaitForChild("TableConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TableService = require(script.Parent.TableService)
local RankingService = require(script.Parent.RankingService)
local ProfileService = require(script.Parent.ProfileService)
local presentation = ReplicatedStorage.CursedBarrel.Remotes:WaitForChild("PresentationCue")

-- 나중 Phase 에서 늘어난 원격. 파일에 없으면 서버가 만들어 둔다.
local function ensureRemote(name)
	local folder = ReplicatedStorage.CursedBarrel:WaitForChild(GameConfig.Remotes.Folder)
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end
local catchPrompt = ensureRemote(GameConfig.Remotes.CatchPrompt)
local catchInput = ensureRemote(GameConfig.Remotes.CatchInput)
local catchResult = ensureRemote(GameConfig.Remotes.CatchResult)
local sabotageCue = ensureRemote(GameConfig.Remotes.SabotageCue)
local braveRemote = ensureRemote(GameConfig.Remotes.Brave)
local CATCH = GameConfig.Catch
local BRAVE = GameConfig.Brave
local POT = GameConfig.Pot

-- Phase 12 : 판이 끝날 때마다 한 번 (정산이 끝난 뒤). 관전 예측 · 토너먼트가 듣는다.
local RoundSettled = Utility.Signal.new()

local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes
local STATES = GameConfig.States
local TIMING = GameConfig.Timing
local REJECT = GameConfig.RejectMessages
local ECONOMY = GameConfig.Economy
local Release = require(Shared.ReleaseConfig)

--------------------------------------------------
-- Round : 테이블 하나의 라운드 상태
--------------------------------------------------
local Round = {}
Round.__index = Round

function Round.new(gameTable)
	local self = setmetatable({}, Round)

	self.gameTable = gameTable
	self.cleaner = Utility.Cleaner.new()
	self.random = Random.new() -- 턴 순서와 위험 자리를 뽑는 서버 전용 난수
	self.pickLimiter = Utility.RateLimiter.new(GameConfig.SelectCooldown) -- 연타 방지

	self.participants = {} -- 턴 순서대로 정렬된 "아직 살아 있는" 참가자 배열
	self.roundRoster = {} -- 이번 라운드를 시작한 전체 명단 (랭킹 기록용)
	self.isParticipant = {} -- [Player] = true (빠른 조회용)
	self.startingCount = 0
	self.turnIndex = 0
	self.roundId = 0
	self.destroyed = false

	-- Phase 3
	self.dangerSlots = {} -- [슬롯번호] = true  ★ 서버 안에서만 존재한다
	self.barrelCycle = 0
	self.resolving = false

	-- Phase 5 : 해적 잡기
	self.catch = nil
	self.catchToken = 0
	self.catchCount = 0

	-- Phase 8 : 방해 아이템
	self.turnCut = {} -- [Player] = 다음 턴을 깎을 비율
	self.sabotageUses = {} -- [Player] = 이번 라운드에 쓴 횟수

	-- Phase 10
	self.catchesUsed = {} -- [Player] = 이번 판에 쓴 잡기 기회
	self.braveLevel = 0 -- 지금 차례의 사람이 몇 번째로 더 찌르는 중인지
	self.braveOffer = nil -- { player, token } "한 번 더" 제안
	self.pot = 0
	self.carry = 0 -- Phase 11 : 다음 판으로 넘어갈 현상금 (테이블에 남는다)
	self.practice = false -- Phase 11 : AI 선원이 낀 연습 판인가
	self.picks = 0 -- 이번 판에 꽂힌 칼 수
	self.pirateOuts = 0 -- 이번 판에 해적에게 탈락한 사람 수 (스스로 나간 사람은 세지 않는다)
	self.afk = {}
	self.forfeited = {}
	self.bonuses = {}
	self.cards = {}

	-- 예약한 작업을 취소하는 대신 토큰을 하나 올린다.
	-- 늦게 도착한 task.delay 콜백은 토큰이 다르면 스스로 물러난다.
	self.countdownToken = 0
	self.turnToken = 0
	self.phaseToken = 0

	self.cleaner:add(gameTable.RosterChanged:Connect(function(_, player, joined)
		self:_onRosterChanged(player, joined)
	end))

	-- 슬롯 프롬프트(E / 탭)로 들어온 요청
	self.cleaner:add(gameTable.SlotTriggered:Connect(function(_, player, slotIndex)
		self:HandlePick(player, slotIndex, "prompt")
	end))

	self:_resetRoundAttributes()
	self.gameTable:ResetSlots()
	self.gameTable:RefreshBarrelSkin()
	self:_evaluate() -- 서버 시작 시 이미 앉아 있는 사람이 있을 수 있다

	return self
end

function Round:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.countdownToken += 1
	self.turnToken += 1
	self.phaseToken += 1
	self.catchToken += 1
	self.catch = nil

	self.cleaner:clean()
	table.clear(self.participants)
	table.clear(self.roundRoster)
	table.clear(self.isParticipant)
	table.clear(self.dangerSlots)
	table.clear(self.turnCut)
	table.clear(self.sabotageUses)
	table.clear(self.catchesUsed)
	self.braveOffer = nil
end

--------------------------------------------------
-- Attribute 기록 (클라이언트가 읽는 유일한 통로)
--------------------------------------------------

function Round:_set(name, value)
	self.gameTable:SetTableAttribute(name, value)
end

function Round:_minPlayers()
	return self.gameTable:GetMinPlayers()
end

-- 좌석마다 이번 라운드의 턴 순서를 적어둔다. (참가자가 아니면 0)
function Round:_writeSeatOrder()
	local orderOfPlayer = {}
	for index, player in ipairs(self.participants) do
		orderOfPlayer[player] = index
	end

	for _, seat in ipairs(self.gameTable:GetSeats()) do
		local player = self.gameTable:GetPlayerOfSeat(seat)
		local order = (player and orderOfPlayer[player]) or 0
		if seat:GetAttribute(SEAT_ATTR.TurnOrder) ~= order then
			seat:SetAttribute(SEAT_ATTR.TurnOrder, order)
		end
		local alive = order > 0
		if seat:GetAttribute(SEAT_ATTR.Alive) ~= alive then
			seat:SetAttribute(SEAT_ATTR.Alive, alive)
		end
		local left = (player and alive) and self:_catchesLeft(player) or 0
		if seat:GetAttribute(SEAT_ATTR.CatchesLeft) ~= left then
			seat:SetAttribute(SEAT_ATTR.CatchesLeft, left)
		end
		local level = (player and alive) and (self.catchesUsed[player] or 0) or 0
		if seat:GetAttribute(SEAT_ATTR.CatchLevel) ~= level then
			seat:SetAttribute(SEAT_ATTR.CatchLevel, level)
		end
	end
end

-- 이 사람이 이번 판에 앞으로 해적을 잡을 수 있는 횟수 (Phase 11 : 잡을 때마다 빨라지다가 끝에는 막힌다)
function Round:_catchesLeft(player)
	if not CATCH.Enabled then
		return 0
	end
	return math.max(0, (tonumber(CATCH.MaxPerPlayer) or 1) - (self.catchesUsed[player] or 0))
end

-- 아직 살아 있는 참가자 중에 사람이 있는가 (AI 끼리만 남으면 판을 접는다)
function Round:_hasHuman()
	for _, participant in ipairs(self.participants) do
		if not GameConfig.isBot(participant) then
			return true
		end
	end
	return false
end

function Round:_resetRoundAttributes()
	self:_set(TABLE_ATTR.CountdownEndsAt, 0)
	self:_set(TABLE_ATTR.CountdownDuration, tonumber(self.gameTable.config.CountdownDuration) or 0)
	self:_set(TABLE_ATTR.ParticipantCount, 0)
	self:_set(TABLE_ATTR.TurnCount, 0)
	self:_set(TABLE_ATTR.TurnIndex, 0)
	self:_set(TABLE_ATTR.CurrentTurnUserId, 0)
	self:_set(TABLE_ATTR.CurrentTurnName, "")
	self:_set(TABLE_ATTR.TurnEndsAt, 0)
	self:_set(TABLE_ATTR.BarrelCycle, 0)
	self:_set(TABLE_ATTR.LastPickSlot, 0)
	self:_set(TABLE_ATTR.LastPickUserId, 0)
	self:_set(TABLE_ATTR.LastPickName, "")
	self:_set(TABLE_ATTR.LastPickSafe, true)
	self:_set(TABLE_ATTR.WinnerUserId, 0)
	self:_set(TABLE_ATTR.WinnerName, "")
	self:_set(TABLE_ATTR.ResetEndsAt, 0)
	self:_set(TABLE_ATTR.PirateCount, 0)
	self:_set(TABLE_ATTR.Pot, 0)
	self:_set(TABLE_ATTR.BraveLevel, 0)
	self:_set(TABLE_ATTR.WinForfeit, false)
	self:_set(TABLE_ATTR.PotCarry, self.carry or 0)
	self:_set(TABLE_ATTR.Practice, false)
	self:_set(TABLE_ATTR.PredictOpen, false)
	self:_set(TABLE_ATTR.Stage, 0)
	self:_set(TABLE_ATTR.StageCount, 0)
	self:_set(TABLE_ATTR.WinnerTakesAll, self:_winnerTakesAll())
	self:_clearBraveOffer()
	self:_writeSeatOrder()
end

--------------------------------------------------
-- Phase 15 : 최후의 1인 · 라운드
--------------------------------------------------

-- 최후의 1인이 전부 가져가는 테이블인가 (4인 이상 테이블. 처음 온 사람의 연습 판은 빼 준다)
function Round:_winnerTakesAll()
	return self.gameTable.config.WinnerTakesAll == true and not self.tutorialPlayer
end

-- 판 도중 버는 코인. 보통 테이블은 그 자리에서 주고, 최후의 1인 테이블은 현상금에 쌓는다.
-- 어느 쪽이든 퀘스트 · 업적 진행(metric)은 그대로 오른다.
function Round:_earn(player, coins, metric, potExtra)
	coins = tonumber(coins) or 0
	potExtra = tonumber(potExtra) or 0
	if self:_winnerTakesAll() then
		ProfileService:Award(player, 0, metric)
		self:_addPot(coins + potExtra)
	else
		ProfileService:Award(player, coins * self:_rewardScale(), metric)
		if potExtra > 0 then
			self:_addPot(potExtra)
		end
	end
end

-- 지금 몇 라운드인가. 한 명이 떨어질 때마다 한 라운드 올라간다. (4명이면 1 → 2 → 3(결승))
function Round:_publishStage()
	local total = math.max(1, (self.startingCount or 1) - 1)
	local stage = math.clamp((self.startingCount or 1) - #self.participants + 1, 1, total)
	self:_set(TABLE_ATTR.Stage, stage)
	self:_set(TABLE_ATTR.StageCount, total)
	return stage, total
end

--------------------------------------------------
-- 상태 판단
--------------------------------------------------

function Round:_evaluate()
	if self.destroyed or self.gameTable.destroyed then
		return
	end

	local state = self.gameTable.state
	local seated = self.gameTable:GetPlayerCount()
	local minPlayers = self:_minPlayers()

	if state == STATES.Waiting then
		if seated >= minPlayers then
			self:_startCountdown()
		end
	elseif state == STATES.Countdown then
		if seated < minPlayers then
			self:_cancelCountdown()
		end
	end
	-- 게임 중의 인원 변화는 RemoveParticipant 가 따로 처리한다.
end

--------------------------------------------------
-- 카운트다운
--------------------------------------------------

function Round:_startCountdown()
	local duration = tonumber(self.gameTable.config.CountdownDuration) or 5
	if duration <= 0 then
		duration = 0.1
	end

	self.countdownToken += 1
	local token = self.countdownToken

	self.gameTable:SetState(STATES.Countdown)
	self:_set(TABLE_ATTR.CountdownDuration, duration)
	self:_set(TABLE_ATTR.CountdownEndsAt, GameConfig.now() + duration)

	GameConfig.log(("%s 카운트다운 시작 · %.1f초 · 인원 %d/%d")
		:format(self.gameTable.tableId, duration, self.gameTable:GetPlayerCount(), self:_minPlayers()))

	task.delay(duration, function()
		if self.destroyed or token ~= self.countdownToken then
			return
		end
		if self.gameTable.destroyed or self.gameTable.state ~= STATES.Countdown then
			return
		end
		if self.gameTable:GetPlayerCount() < self:_minPlayers() then
			self:_cancelCountdown()
			return
		end
		self:_beginRound()
	end)
end

function Round:_cancelCountdown()
	self.countdownToken += 1 -- 예약된 시작을 무효로 만든다
	self:_set(TABLE_ATTR.CountdownEndsAt, 0)

	if not self.gameTable.destroyed and self.gameTable.state == STATES.Countdown then
		self.gameTable:SetState(STATES.Waiting)
	end

	GameConfig.log(("%s 카운트다운 취소 · 인원 %d/%d")
		:format(self.gameTable.tableId, self.gameTable:GetPlayerCount(), self:_minPlayers()))
end

--------------------------------------------------
-- 통 채우기 / 해적 숨기기  (Phase 3 · Phase 6 에서 고침)
--------------------------------------------------

-- 이 테이블에 숨어 있어야 하는 해적 수. 좌석이 많으면 늘어난다.
function Round:_targetPirateCount()
	local base = TableConfig.getDangerCount(self.gameTable.typeName, #self.gameTable:GetSeats())
	-- Phase 12 : 폭풍(크라켄 습격) 동안 해적이 늘어난다. 통에 고를 자리는 넉넉히 남긴다.
	local extra = math.max(0, math.floor(tonumber(GameConfig.worldMods().extraPirate) or 0))
	local slots = TableConfig.getSlotCount(self.gameTable.typeName)
	return math.clamp(base + extra, 1, math.max(1, math.floor(slots / 3)))
end

-- 아직 아무도 꽂지 않은 자리 중에서 "살아 있는" 해적이 몇 마리인지.
-- 이미 칼이 꽂힌 자리의 해적은 잡혔거나 터졌으므로 세지 않는다.
function Round:_liveDangerCount()
	local count = 0
	for slotIndex in pairs(self.dangerSlots) do
		if not self.gameTable:IsSlotUsed(slotIndex) then
			count += 1
		end
	end
	return count
end

-- 아직 아무도 꽂지 않았고 해적도 없는 자리 목록
-- ★ 봉인된 자리는 빼고 센다. 봉인된 자리를 "남은 안전한 자리"로 셈하면,
--   고를 수 있는 마지막 한 칸에 해적이 숨어 다음 사람이 강제로 탈락할 수 있었다.
function Round:_hidableSlots()
	local list = {}
	for _, slotIndex in ipairs(self.gameTable:GetFreeSlotIndices()) do
		if not self.dangerSlots[slotIndex] and slotIndex ~= self.sealed then
			table.insert(list, slotIndex)
		end
	end
	return list
end

-- 지금 고를 수 있는 빈 자리 수 (봉인된 자리는 뺀다)
function Round:_pickableCount()
	local count = 0
	for _, slotIndex in ipairs(self.gameTable:GetFreeSlotIndices()) do
		if slotIndex ~= self.sealed then
			count += 1
		end
	end
	return count
end

-- ★ 안 꽂은 자리 중 하나에 해적을 새로 숨긴다. 실제로 숨긴 수를 돌려준다.
function Round:_armDanger(count)
	count = math.max(0, math.floor(tonumber(count) or 0))
	if count == 0 then
		return 0
	end

	local pool = self:_hidableSlots()
	-- 통에 고를 자리가 하나밖에 안 남았으면 숨기지 않는다.
	-- (마지막 한 칸이 무조건 해적이면 그건 게임이 아니라 처형이다)
	local room = #pool - CATCH.MinFreeSlotsToArm
	if room <= 0 then
		return 0
	end

	Utility.shuffle(pool, self.random)
	local armed = 0
	for index = 1, math.min(count, room) do
		local slotIndex = pool[index]
		if slotIndex then
			self.dangerSlots[slotIndex] = true
			armed += 1
		end
	end

	if armed > 0 then
		self:_publishPirateCount()
		-- 몇 번 자리인지는 로그에도 남기지 않는다. (방송·영상 대비)
		GameConfig.log(("%s 해적 %d마리를 새로 숨김 · 현재 %d마리")
			:format(self.gameTable.tableId, armed, self:_liveDangerCount()))
	end
	return armed
end

-- 통 안의 해적이 정원보다 적으면 그 자리에서 채운다.
-- 어떤 경로로 해적이 사라져도(잡기·탈락·이탈) 다음 턴에는 반드시 복구된다.
function Round:_ensureDanger()
	local target = self:_targetPirateCount()
	local live = self:_liveDangerCount()
	if live >= target then
		self:_publishPirateCount()
		return 0
	end
	return self:_armDanger(target - live)
end

-- 클라이언트에는 "몇 마리"까지만 알린다. 어느 자리인지는 절대 나가지 않는다.
function Round:_publishPirateCount()
	self:_set(TABLE_ATTR.PirateCount, self:_liveDangerCount())
end

-- 통을 새 칼로 채우고 해적을 다시 숨긴다.
function Round:_refillBarrel()
	self:_clearSeal()
	local gameTable = self.gameTable
	gameTable:ResetSlots()
	gameTable:ResetBarrelLook()

	local slotCount = gameTable:GetSlotCount()
	local dangerCount = math.min(self:_targetPirateCount(), math.max(1, slotCount - 1))

	local pool = {}
	for index = 1, slotCount do
		pool[index] = index
	end
	Utility.shuffle(pool, self.random)

	table.clear(self.dangerSlots)
	for index = 1, dangerCount do
		local slotIndex = pool[index]
		if slotIndex then
			self.dangerSlots[slotIndex] = true
		end
	end

	self.barrelCycle += 1
	self:_set(TABLE_ATTR.BarrelCycle, self.barrelCycle)
	self:_set(TABLE_ATTR.SlotsRemaining, slotCount)
	self:_publishPirateCount()

	-- 로그에도 위험 자리 번호는 남기지 않는다.
	GameConfig.log(("%s 통 %d번째 채움 · 칼 %d자루 · 해적 %d마리")
		:format(gameTable.tableId, self.barrelCycle, slotCount, dangerCount))
end

function Round:_freeSlotCount()
	return #self.gameTable:GetFreeSlotIndices()
end

--------------------------------------------------
-- 라운드 시작
--------------------------------------------------

function Round:_beginRound()
	-- 1) 이 순간 앉아 있는 사람들을 참가자로 확정한다.
	local participants = self.gameTable:GetPlayers()

	-- 2) 턴 순서는 서버에서 무작위로 섞는다. (좌석 순서를 알아도 예측할 수 없다)
	Utility.shuffle(participants, self.random)

	self.participants = participants
	self.forfeited = {}
	self.bonuses = {}
	self.cards = {}
	self.afk = {}
	self.sealed = nil
	self.sealedBy = nil
	self.settled = false
	self.roundStartedAt = os.clock()
	table.clear(self.catchesUsed)
	self.braveLevel = 0
	self.braveOffer = nil
	self.picks = 0
	self.pirateOuts = 0
	self.pot = 0
	self.surgeMiss = 0
	self.outOrder = {} -- Phase 12 : 해적에게 탈락한 순서 (토너먼트 순위)
	-- Phase 12 : 연습 판이면 그 사람의 첫 해적은 쉽다
	self.tutorialPlayer = nil
	local tutorialId = self.gameTable.model and self.gameTable.model:GetAttribute(TABLE_ATTR.Tutorial) or 0
	if tutorialId and tutorialId ~= 0 then
		for _, p in ipairs(participants) do
			if p.UserId == tutorialId then
				self.tutorialPlayer = p
			end
		end
	end
	-- Phase 11 : AI 선원이 한 명이라도 끼면 연습 판이다. (_rewardScale 이 이 값을 본다)
	self.practice = false
	for _, p in ipairs(participants) do
		if GameConfig.isBot(p) then
			self.practice = true
		end
	end
    for _, p in ipairs(participants) do
        self.cards[p]={skip=true,rotate=true,seal=true}
        local bonus=0
        for _,other in ipairs(participants) do
            if p~=other and p:GetAttribute("Friend_"..other.UserId)==true then bonus=Release.FriendBonus end
        end
        local party=p:GetAttribute("PartyId")
        if party then
            for _,other in ipairs(participants) do
                if other~=p and other:GetAttribute("PartyId")==party then bonus=bonus+Release.PartyBonus;break end
            end
        end
        self.bonuses[p]=bonus
    end
	self.roundRoster = table.clone(participants) -- 랭킹 기록용. 탈락해도 줄지 않는다.
	self.catch = nil
	self.catchToken += 1
	self.catchCount = 0
	self:_set(TABLE_ATTR.CatchCount, 0)
	table.clear(self.isParticipant)
	table.clear(self.turnCut)
	table.clear(self.sabotageUses)
	for _, player in ipairs(participants) do
		self.isParticipant[player] = true
	end

	self.roundId += 1
	self.turnIndex = 0
	self.startingCount = #participants
	self.barrelCycle = 0
	self.resolving = false

	self:_set(TABLE_ATTR.CountdownEndsAt, 0)
	self:_set(TABLE_ATTR.RoundId, self.roundId)
	self:_set(TABLE_ATTR.ParticipantCount, #participants)
	self:_set(TABLE_ATTR.TurnCount, #participants)
	self:_set(TABLE_ATTR.WinnerUserId, 0)
	self:_set(TABLE_ATTR.WinnerName, "")
	self:_set(TABLE_ATTR.WinForfeit, false)
	self:_set(TABLE_ATTR.ResetEndsAt, 0)
	self:_set(TABLE_ATTR.LastPickSlot, 0)
	self:_set(TABLE_ATTR.LastPickUserId, 0)
	self:_set(TABLE_ATTR.LastPickName, "")
	self:_set(TABLE_ATTR.LastPickSafe, true)
	self:_set(TABLE_ATTR.BraveLevel, 0)
	self:_set(TABLE_ATTR.Practice, self.practice)
	self:_set(TABLE_ATTR.PredictOpen, GameConfig.Prediction.Enabled == true)
	self:_set(TABLE_ATTR.WinnerTakesAll, self:_winnerTakesAll())
	self:_publishStage()
	self:_clearBraveOffer()
	self:_addPot(POT.Base)
	-- Phase 11 : 지난 판에서 넘어온 현상금을 얹는다. (이미 그때의 배율이 들어가 있다)
	local carry = math.max(0, math.floor(self.carry or 0))
	self.carry = 0
	if POT.Enabled and carry > 0 then
		self.pot = math.clamp((self.pot or 0) + carry, 0, POT.Cap)
		self:_set(TABLE_ATTR.Pot, self.pot)
	end
	self:_set(TABLE_ATTR.PotCarry, carry)
	self:_writeSeatOrder()

	-- 3) 상태를 Starting 으로. 이 순간부터 빈 의자에도 앉을 수 없다.
	self.gameTable:SetState(STATES.Starting)
	self:_refillBarrel()

	local names = {}
	for _, player in ipairs(participants) do
		table.insert(names, player.Name)
	end
	GameConfig.log(("%s 라운드 %d 시작 · 턴 순서: %s")
		:format(self.gameTable.tableId, self.roundId, table.concat(names, " → ")))

	-- 4) 짧은 시작 연출 뒤 첫 번째 차례
	self.phaseToken += 1
	local token = self.phaseToken
	task.delay(TIMING.StartingDuration, function()
		if self.destroyed or token ~= self.phaseToken then
			return
		end
		if self.gameTable.destroyed or self.gameTable.state ~= STATES.Starting then
			return
		end
		if #self.participants == 0 then
			self:_finishRound("참가자가 모두 자리를 떠남")
			return
		end
		self.gameTable:SetState(STATES.Playing)
		self:_beginTurn(1)
	end)
end

-- 승자 없이 라운드를 접는다. (참가자가 전부 사라진 경우)
-- Phase 11 : 아무도 가져가지 못한 현상금은 다음 판으로 이월된다.
function Round:_finishRound(reason)
	GameConfig.log(("%s 라운드 정리 (%s)"):format(self.gameTable.tableId, tostring(reason)))
	if not self.settled and (self.pot or 0) > 0 then
		self:_carryOver(self.pot)
	end
	self:_resetTable()
end

function Round:_carryOver(amount)
	local add = math.max(0, math.floor(tonumber(amount) or 0))
	self.carry = math.min(tonumber(POT.CarryCap) or 0, (self.carry or 0) + add)
	return add
end

--------------------------------------------------
-- 턴
--------------------------------------------------

-- braveContinue : "한 번 더"를 눌러 같은 사람이 다시 고르는 차례면 true
function Round:_beginTurn(index, braveContinue)
	if self.destroyed or self.gameTable.destroyed then
		return
	end

	local count = #self.participants
	if count == 0 then
		self:_finishRound("참가자가 모두 자리를 떠남")
		return
	end

	self:_clearBraveOffer()
	if not braveContinue then
		self.braveLevel = 0
	end

	if self.gameTable.state == STATES.Playing then
		-- ★ Phase 10 안전망. 칼이 한 자루도 남지 않은 통으로 차례를 시작하지 않는다.
		--   (누가 나가는 순간과 통 재충전이 겹치면 이런 통이 남아서 시간 초과만 반복됐다)
		if self:_freeSlotCount() == 0 then
			self:_refillBarrel()
		end

		-- ★ Phase 6 안전망.
		-- 어떤 경로로든 통 안의 해적이 정원보다 적으면 여기서 반드시 채워 넣는다.
		-- 이 한 줄이 "잡고 나면 끝까지 해적이 안 나오던" 증상의 마지막 방어선이다.
		self:_ensureDanger()
	end

	-- 목록 끝을 넘어가면 처음으로 돌아온다.
	index = ((index - 1) % count) + 1
	self.turnIndex = index
	self.resolving = false

	local player = self.participants[index]

	self.turnToken += 1
	local token = self.turnToken

	self:_set("TurnSerial", self.turnToken)
	local hand = self.cards and self.cards[player]
	self:_set("CardSkip", hand and hand.skip or false)
	self:_set("CardRotate", hand and hand.rotate or false)
	self:_set("CardSeal", hand and hand.seal or false)
	self:_set(TABLE_ATTR.BraveLevel, self.braveLevel)
	self:_set(TABLE_ATTR.TurnIndex, index)
	self:_set(TABLE_ATTR.TurnCount, count)
	self:_set(TABLE_ATTR.CurrentTurnUserId, player.UserId)
	self:_set(TABLE_ATTR.CurrentTurnName, player.DisplayName or player.Name)

	local duration = tonumber(self.gameTable.config.TurnDuration) or 0

	-- Phase 8 : "저주의 재촉"을 맞았으면 이번 턴만 짧아진다.
	local cut = self.turnCut[player]
	if cut and duration > 0 then
		self.turnCut[player] = nil
		duration = math.max(2, duration * (1 - math.clamp(cut, 0, 0.6)))
	end

	if self.gameTable.config.AutoAdvanceTurn and duration > 0 then
		self:_set(TABLE_ATTR.TurnEndsAt, GameConfig.now() + duration)
		task.delay(duration, function()
			if self.destroyed or token ~= self.turnToken then
				return
			end
			if self.gameTable.destroyed or self.gameTable.state ~= STATES.Playing then
				return
			end
			self:_onTurnTimeout(player)
		end)
	else
		self:_set(TABLE_ATTR.TurnEndsAt, 0)
	end

	GameConfig.log(("%s 턴 %d/%d · %s"):format(self.gameTable.tableId, index, count, player.Name))

	if GameConfig.isBot(player) and self.gameTable.state == STATES.Playing then
		self:_botThink(player, token)
	end
end

--------------------------------------------------
-- AI 선원 (Phase 11)
--
-- AI 도 통 안을 모른다. 봉인되지 않은 빈 자리 중에서 무작위로 고른다.
-- 잡기는 성격(skill)과 이번 창 길이로 성공 확률을 정하고, 실제 입력과 같은 길(HandleCatchInput)로 넣는다.
--------------------------------------------------

function Round:_botThink(bot, token)
	local config = GameConfig.Bots
	local delay = config.ThinkMin + self.random:NextNumber() * math.max(0, config.ThinkMax - config.ThinkMin)
	task.delay(delay, function()
		if self.destroyed or token ~= self.turnToken or self.resolving then
			return
		end
		if self.gameTable.destroyed or self.gameTable.state ~= STATES.Playing then
			return
		end
		if self.participants[self.turnIndex] ~= bot then
			return
		end
		local choices = {}
		for _, slotIndex in ipairs(self.gameTable:GetFreeSlotIndices()) do
			if slotIndex ~= self.sealed then
				table.insert(choices, slotIndex)
			end
		end
		local slotIndex = Utility.pickRandom(choices, self.random)
		if slotIndex then
			self.afk[bot] = 0
			self:_resolvePick(bot, slotIndex, "bot")
		end
	end)
end

function Round:_botBrave(bot, token, level)
	local nerve = tonumber(bot.brave) or 0.3
	if self.random:NextNumber() >= nerve * (1 - 0.25 * level) then
		return
	end
	task.delay(0.7 + self.random:NextNumber() * 0.6, function()
		if self.destroyed or not self.braveOffer or self.braveOffer.token ~= token then
			return
		end
		self:AcceptBrave(bot)
	end)
end

-- 이번 잡기에 AI 가 누를 시각을 정한다. 창이 좁을수록 성공 확률이 떨어진다.
function Round:_botCatch(bot, catch)
	local skill = tonumber(bot.skill) or 0.5
	local chance = math.clamp(skill + (catch.window - 0.45) * 1.6, 0.08, 0.92)
	local tapAt
	if self.random:NextNumber() < chance then
		tapAt = catch.opensAt + catch.window * (0.15 + self.random:NextNumber() * 0.7)
	elseif self.random:NextNumber() < 0.35 then
		-- 겁먹고 먼저 누른다 (사람도 가장 많이 하는 실수)
		tapAt = math.max(catch.startedAt + CATCH.ArmDelay + 0.05, catch.opensAt - 0.15 - self.random:NextNumber() * 0.3)
	else
		tapAt = catch.opensAt + catch.window + CATCH.Grace + 0.08 + self.random:NextNumber() * 0.3
	end
	local token = catch.token
	task.delay(math.max(0, tapAt - GameConfig.now()), function()
		if self.destroyed or token ~= self.catchToken then
			return
		end
		self:HandleCatchInput(bot, GameConfig.now())
	end)
end

-- 제한 시간 안에 고르지 못했다. 서버가 남은 자리 중 하나를 대신 고른다.
function Round:_onTurnTimeout(player)
	if self.resolving then
		return
	end
	if self.participants[self.turnIndex] ~= player then
		return
	end

	self.afk[player] = (self.afk[player] or 0) + 1
	if self.afk[player] >= Release.AFKTimeouts then
		-- 세 번 연속으로 고르지 않았다. 자리에서 일으켜 세운다. (이탈 처리는 RemoveParticipant 가 한다)
		self.gameTable:RemovePlayer(player)
		return
	end
	if self.gameTable.config.AutoPickOnTimeout then
		local free = self.gameTable:GetFreeSlotIndices()
		if self.sealed then
			local sealedAt = table.find(free, self.sealed)
			if sealedAt then
				table.remove(free, sealedAt)
			end
		end
		local slotIndex = Utility.pickRandom(free, self.random)
		if slotIndex and self:ValidatePick(player, slotIndex) == nil then
			GameConfig.log(("%s 시간 초과 · 서버가 대신 %d번 자리를 고릅니다"):format(player.Name, slotIndex))
			self:_resolvePick(player, slotIndex, "timeout")
			return
		end
	end

	self:AdvanceTurn()
end

function Round:AdvanceTurn()
	if self.destroyed or self.gameTable.destroyed then
		return
	end
	if self.gameTable.state ~= STATES.Playing then
		return
	end
	self:_beginTurn(self.turnIndex + 1)
end

--------------------------------------------------
-- 슬롯 선택 (Phase 3 의 입구)
--------------------------------------------------

-- 통과하면 nil, 막히면 거절 사유 문자열을 돌려준다.
function Round:ValidatePick(player, slotIndex)
	if self.destroyed or self.gameTable.destroyed then
		return REJECT.NotPlaying
	end
	if self.gameTable.state ~= STATES.Playing then
		return REJECT.NotPlaying
	end
	if not self.isParticipant[player] then
		return REJECT.NotParticipant
	end
	if not self.gameTable:HasPlayer(player) then
		return REJECT.Eliminated
	end
	if self.participants[self.turnIndex] ~= player then
		return REJECT.NotYourTurn
	end
	if self.resolving then
		return REJECT.TooFast
	end
	if typeof(slotIndex) ~= "number" or slotIndex ~= slotIndex or slotIndex==math.huge or slotIndex==-math.huge or slotIndex%1~=0 then
		return REJECT.BadSlot
	end

	if self.sealed==slotIndex then return "봉인된 자리입니다 / Sealed slot" end
 local h=Utility.getHumanoid(player)
 if not h or h.Health<=0 or not h.RootPart then return REJECT.NotParticipant end
 local seat=self.gameTable:GetSeatOfPlayer(player)
 if not seat or (h.RootPart.Position-seat.Position).Magnitude>18 then return REJECT.OtherTable end
 slotIndex = math.floor(slotIndex)
 local slot = self.gameTable:GetSlot(slotIndex)
	if not slot then
		return REJECT.BadSlot
	end
	if self.gameTable:IsSlotUsed(slotIndex) then
		return REJECT.SlotUsed
	end

	return nil
end

function Round:HandlePick(player, slotIndex, source)
	if not self.pickLimiter:check(player.UserId) then
		return REJECT.TooFast
	end

	local reason = self:ValidatePick(player, slotIndex)
	if reason then
		GameConfig.log(("%s 슬롯 요청 거절 (%s · %s): %s")
			:format(self.gameTable.tableId, tostring(player and player.Name), tostring(source), reason))
		return reason
	end

	self.afk[player]=0
	self:_resolvePick(player, math.floor(slotIndex), source)
	return nil
end

--------------------------------------------------
-- 선택 처리
--------------------------------------------------

function Round:_resolvePick(player, slotIndex, source)
	local gameTable = self.gameTable
	local isDanger = self.dangerSlots[slotIndex] == true
	-- 봉인은 "봉인한 사람 다음 차례의 선택"까지 유지된다.
	-- 봉인한 사람이 자기 칼을 꽂는 것으로는 풀리지 않는다. (Phase 9 에서는 여기서 바로 풀려 쓸모가 없었다)
	if self.sealed and self.sealedBy ~= player then
		self:_clearSeal()
	end

	self.resolving = true
	self.picks = (self.picks or 0) + 1
	self.turnToken += 1 -- 이번 턴의 제한 시간 타이머를 무효로 만든다
	-- Phase 12 : 한 바퀴를 돌면 관전 예측을 닫는다 (결과가 뻔해진 뒤에는 받지 않는다)
	if self.picks >= math.max(2, self.startingCount or 2) then
		self:_set(TABLE_ATTR.PredictOpen, false)
	end

	-- 해적을 밟았으면 그 자리의 해적은 여기서 소모된다.
	-- (칼이 꽂혀 다시 고를 수 없는 자리이므로 명단에 남겨두면 숫자가 어긋난다)
	if isDanger then
		self.dangerSlots[slotIndex] = nil
	end

	gameTable:MarkSlotUsed(slotIndex, player, isDanger)
	-- catchable : 이번 해적을 잡을 기회가 있는가. 이미 칼이 꽂혀 결과가 정해진 뒤라 알려도 된다.
	presentation:FireAllClients("Pick", gameTable.model, {
		slot = slotIndex, danger = isDanger, userId = player.UserId, name = player.DisplayName or player.Name,
		catchable = self:_catchesLeft(player) > 0,
		brave = self.braveLevel,
		bot = GameConfig.isBot(player) or nil,
		stab = player:GetAttribute(GameConfig.Skins.PlayerAttributes.Stab) or "classic",
		knife = player:GetAttribute(GameConfig.Skins.PlayerAttributes.Knife),
	})
	self:_set(TABLE_ATTR.SlotsRemaining, self:_freeSlotCount())
	self:_set(TABLE_ATTR.LastPickSlot, slotIndex)
	self:_set(TABLE_ATTR.LastPickUserId, player.UserId)
	self:_set(TABLE_ATTR.LastPickName, player.DisplayName or player.Name)
	self:_set(TABLE_ATTR.LastPickSafe, not isDanger)
	self:_set(TABLE_ATTR.TurnEndsAt, 0)
	self:_publishPirateCount()

	GameConfig.log(("%s · %s 가 %d번 자리 선택 (%s, %s)")
		:format(gameTable.tableId, player.Name, slotIndex, isDanger and "위험" or "안전", tostring(source)))

	if isDanger then
		gameTable:PlayDangerEffect()
		self:_beginCatch(player, slotIndex)
		return
	end

	-- 안전. 작은 보상을 주고, 잠깐 결과를 보여준 뒤 다음 사람 차례로 넘어간다.
	-- (Phase 15 : 최후의 1인 테이블은 보상이 현상금에 쌓인다)
	self:_earn(player, ECONOMY.SurviveTurnReward, "safePicks", POT.PerPick)
	self:_rollSurge(player)

	-- 배짱으로 더 찌른 자리에서 살아남았다. 단계만큼 바로 보상한다.
	local level = self.braveLevel or 0
	if level > 0 then
		self:_earn(player, BRAVE.Rewards[math.clamp(level, 1, #BRAVE.Rewards)] or 0, "bravePicks", POT.PerBravePick)
	end

	self.phaseToken += 1
	local token = self.phaseToken

	-- ★ Phase 10 : "한 번 더" 제안. 결과를 보여주는 동안(ResultHold)만 누를 수 있다.
	--   누르면 AcceptBrave 가 phaseToken 을 올려 아래의 "다음 사람 차례" 예약을 무효로 만든다.
	if BRAVE.Enabled and level < BRAVE.MaxChain and self:_pickableCount() >= BRAVE.MinPickable then
		self.braveOffer = { player = player, token = token }
		self:_set(TABLE_ATTR.BraveNextReward, self:_braveOfferValue(level + 1))
		self:_set(TABLE_ATTR.BraveOfferEndsAt, GameConfig.now() + TIMING.ResultHold)
		self:_set(TABLE_ATTR.BraveOfferUserId, player.UserId)
		if GameConfig.isBot(player) then
			self:_botBrave(player, token, level)
		end
	end

	task.delay(TIMING.ResultHold, function()
		if self.destroyed or token ~= self.phaseToken then
			return
		end
		if gameTable.destroyed or gameTable.state ~= STATES.Playing then
			return
		end

		-- 칼을 전부 뽑았으면 통을 새로 채운다.
		if self:_freeSlotCount() == 0 then
			self:_refillBarrel()
		end

		self:_beginTurn(self.turnIndex + 1)
	end)
end

--------------------------------------------------
-- 배짱 · 현상금 (Phase 10)
--------------------------------------------------

function Round:_braveReward(level)
	local list = BRAVE.Rewards
	local amount = list[math.clamp(level, 1, #list)] or 0
	return math.floor(amount * self:_rewardScale())
end

-- "한 번 더" 버튼에 적을 숫자. 최후의 1인 테이블은 현상금이 이만큼 커진다.
function Round:_braveOfferValue(level)
	if not self:_winnerTakesAll() then
		return self:_braveReward(level)
	end
	local list = BRAVE.Rewards
	local amount = (list[math.clamp(level, 1, #list)] or 0) + (tonumber(POT.PerBravePick) or 0) + (tonumber(POT.PerPick) or 0)
		+ (tonumber(ECONOMY.SurviveTurnReward) or 0)
	return math.floor(amount * self:_rewardScale() * (tonumber(GameConfig.worldMods().pot) or 1))
end

function Round:_clearBraveOffer()
	self.braveOffer = nil
	self:_set(TABLE_ATTR.BraveOfferUserId, 0)
	self:_set(TABLE_ATTR.BraveOfferEndsAt, 0)
	self:_set(TABLE_ATTR.BraveNextReward, 0)
end

function Round:_addPot(amount)
	if not POT.Enabled then
		return
	end
	local add = math.floor((tonumber(amount) or 0) * self:_rewardScale() * (tonumber(GameConfig.worldMods().pot) or 1))
	self.pot = math.clamp((self.pot or 0) + add, 0, POT.Cap)
	self:_set(TABLE_ATTR.Pot, self.pot)
end

-- Phase 11 : 보물 폭발. 안전한 자리를 뽑을 때마다 굴린다. 안 터질수록 확률이 오른다.
function Round:_rollSurge(player)
	local surge = POT.Surge
	if not (POT.Enabled and surge and surge.Enabled) then
		return nil
	end
	self.surgeMiss = (self.surgeMiss or 0) + 1
	-- Phase 12 : 노을(황금 시간)과 오늘의 행운 테이블은 확률이 커진다
	local boost = tonumber(GameConfig.worldMods().surge) or 1
	if GameConfig.Lucky.Enabled and self.gameTable.model and self.gameTable.model:GetAttribute(TABLE_ATTR.Lucky) == true then
		boost *= GameConfig.Lucky.SurgeScale
	end
	local cap = boost > 1 and math.max(surge.MaxChance, tonumber(surge.BoostedMaxChance) or surge.MaxChance) or surge.MaxChance
	local chance = math.min(cap, surge.MaxChance * boost, (surge.Chance + surge.PityStep * self.surgeMiss) * boost)
	if self.random:NextNumber() >= chance then
		return nil
	end
	self.surgeMiss = 0

	local total = 0
	for _, tier in ipairs(surge.Tiers) do
		total += tier.weight
	end
	local roll = self.random:NextNumber() * total
	local chosen = surge.Tiers[#surge.Tiers]
	for _, tier in ipairs(surge.Tiers) do
		roll -= tier.weight
		if roll < 0 then
			chosen = tier
			break
		end
	end

	local before = self.pot or 0
	local target = before + math.floor((chosen.add or 0) * self:_rewardScale())
	if chosen.mult then
		target = math.max(target, math.floor(before * chosen.mult))
	end
	self.pot = math.clamp(target, 0, POT.Cap)
	self:_set(TABLE_ATTR.Pot, self.pot)

	presentation:FireAllClients("Surge", self.gameTable.model, {
		tier = chosen.id,
		name = chosen.name,
		amount = self.pot - before,
		pot = self.pot,
		userId = player and player.UserId or 0,
	})
	GameConfig.log(("%s 보물 폭발 · %s · 현상금 %d → %d"):format(self.gameTable.tableId, chosen.name, before, self.pot))
	return chosen
end

-- 결과를 보여주는 동안 "한 번 더"를 눌렀다. 같은 사람이 곧바로 다시 고른다.
function Round:AcceptBrave(player)
	local offer = self.braveOffer
	if not offer or offer.player ~= player or offer.token ~= self.phaseToken then
		return false, "지금은 한 번 더 찌를 수 없습니다"
	end
	if self.destroyed or self.gameTable.destroyed or self.gameTable.state ~= STATES.Playing then
		return false, REJECT.NotPlaying
	end
	if not self.isParticipant[player] or self.participants[self.turnIndex] ~= player then
		return false, REJECT.NotYourTurn
	end
	if self:_pickableCount() < BRAVE.MinPickable then
		return false, "남은 자리가 너무 적습니다"
	end

	self.phaseToken += 1 -- "다음 사람 차례" 예약을 무효로 만든다
	self.braveLevel = (self.braveLevel or 0) + 1
	self.afk[player] = 0

	presentation:FireAllClients("Brave", self.gameTable.model, {
		userId = player.UserId,
		name = player.DisplayName or player.Name,
		level = self.braveLevel,
	})
	GameConfig.log(("%s · %s 배짱 %d단계"):format(self.gameTable.tableId, player.Name, self.braveLevel))

	self:_beginTurn(self.turnIndex, true)
	return true, nil
end

function Round:_rewardScale()
	local scale = TableConfig.getRewardScale(self.gameTable.typeName)
	if self.practice then
		scale *= tonumber(GameConfig.Bots.RewardScale) or 1
	end
	return scale
end

--------------------------------------------------
-- 해적 잡기 (Phase 5)
--------------------------------------------------

function Round:_beginCatch(player, slotIndex)
	local gameTable = self.gameTable

	if not CATCH.Enabled then
		self:_eliminate(player)
		return
	end

	self.catchToken += 1
	local token = self.catchToken
	local personal = self.catchesUsed[player] or 0

	-- ★ Phase 11 : 이미 MaxPerPlayer 번을 잡았다. 이번 해적은 "분노한 해적"이라 잡히지 않는다.
	--   잡기 창을 열지 않고, 해적이 튀어나오는 연출이 끝날 즈음 탈락시킨다.
	if self:_catchesLeft(player) <= 0 then
		self.catch = {
			token = token,
			player = player,
			slot = slotIndex,
			startedAt = GameConfig.now(),
			opensAt = math.huge,
			window = 0,
			resolved = false,
			spent = true,
		}
		GameConfig.log(("%s · %s 분노한 해적 (잡기 %d회) → 탈락"):format(gameTable.tableId, player.Name, personal))
		task.delay(CATCH.SpentReveal, function()
			if self.destroyed or token ~= self.catchToken then
				return
			end
			self:_resolveCatch(false, "spent")
		end)
		return
	end

	-- 잡을 때마다(personal) 창이 좁아지고, 해적이 더 빨리 튀어나온다.
	local window = GameConfig.catchWindow(self.catchCount, #self.participants, self:_freeSlotCount(), personal)
	-- 창이 열리는 순간을 조금씩 흔든다. 클라이언트는 opensAt 에 맞춰 연출하므로 화면과 어긋나지 않는다.
	-- Phase 12 : 밤에는 해적이 더 빨리 나온다 (MinLead 아래로는 안 내려간다)
	local lead = GameConfig.catchLead(personal, GameConfig.worldMods().lead) + self.random:NextNumber() * (tonumber(CATCH.LeadJitter) or 0)
	-- Phase 12 : 연습 판에서 처음 온 사람의 첫 해적은 넉넉하다
	if self.tutorialPlayer == player and personal == 0 and GameConfig.Tutorial.Enabled then
		window *= GameConfig.Tutorial.WindowScale
		lead = GameConfig.Tutorial.Lead
	end
	local startedAt = GameConfig.now()
	local opensAt = startedAt + lead

	self.catch = {
		token = token,
		player = player,
		slot = slotIndex,
		startedAt = startedAt,
		opensAt = opensAt,
		window = window,
		level = personal + 1,
		resolved = false,
	}

	-- 잡아야 하는 사람에게만 창 길이를 보낸다.
	if not GameConfig.isBot(player) then
		catchPrompt:FireClient(player, gameTable.model, {
			mine = true,
			opensAt = opensAt,
			window = window,
			index = self.catchCount + 1,
			level = personal + 1,
			max = CATCH.MaxPerPlayer,
			slot = slotIndex,
		})
	end

	-- 나머지는 "누가 잡으려 한다"만 안다. 창 길이는 알려주지 않는다.
	for _, other in ipairs(self.participants) do
		if other ~= player and not GameConfig.isBot(other) then
			catchPrompt:FireClient(other, gameTable.model, {
				mine = false,
				opensAt = opensAt,
				userId = player.UserId,
				name = player.DisplayName or player.Name,
				level = personal + 1,
				slot = slotIndex,
			})
		end
	end

	GameConfig.log(("%s · %s 잡기 시작 (%d번째 · 이 사람 %d단계 · 창 %.2f초)")
		:format(gameTable.tableId, player.Name, self.catchCount + 1, personal + 1, window))

	if GameConfig.isBot(player) then
		self:_botCatch(player, self.catch)
	end

	-- 응답이 없어도 판이 멈추지 않도록 서버가 끝을 낸다.
	task.delay(lead + window + CATCH.Timeout, function()
		if self.destroyed or token ~= self.catchToken then
			return
		end
		self:_resolveCatch(false, "timeout")
	end)
end

-- 클라이언트가 "지금 눌렀다"고 알려 왔을 때.
function Round:HandleCatchInput(player, tappedAt)
	local catch = self.catch
	if not catch or catch.resolved or catch.player ~= player or catch.spent then
		return
	end

	local now = GameConfig.now()

	-- 보내온 시각을 그대로 믿지 않는다.
	--   · 미래의 시각은 인정하지 않는다 (now 가 상한)
	--   · 왕복 지연 상한보다 더 과거도 인정하지 않는다
	local claimed = tonumber(tappedAt)
	if not claimed or claimed ~= claimed then
		claimed = now
	end
	claimed = math.clamp(claimed, now - CATCH.MaxLatency, now)

	if claimed < catch.opensAt then
		-- 칼을 고른 바로 그 손가락이 한 번 더 눌린 것은 버린다.
		if claimed < (catch.startedAt or 0) + (tonumber(CATCH.ArmDelay) or 0) then
			return
		end
		-- 시계 오차만큼은 "딱 맞춰 누른 것"으로 친다.
		if claimed >= catch.opensAt - (tonumber(CATCH.EarlyTolerance) or 0) then
			claimed = catch.opensAt
		else
			-- ★ Phase 11 : 해적이 나오기 전에 눌렀다. 그 자리에서 실패다.
			self:_resolveCatch(false, "early")
			return
		end
	end

	local limit = catch.opensAt + catch.window + CATCH.Grace
	if claimed <= limit then
		catch.accuracy = math.clamp(1 - (claimed - catch.opensAt) / math.max(catch.window, 0.01), 0, 1)
		self:_resolveCatch(true, "caught")
	else
		self:_resolveCatch(false, "late")
	end
end

function Round:_resolveCatch(success, reason)
	local catch = self.catch
	if not catch or catch.resolved then
		return
	end
	catch.resolved = true
	self.catch = nil
	self.catchToken += 1

	local gameTable = self.gameTable
	local player = catch.player

	-- ★ Phase 6 : 잡았으면 아직 아무도 꽂지 않은 자리에 해적을 새로 숨긴다.
	--   결과를 보내기 전에 숨기는 이유: 아래 payload 의 "남은 해적 수"가 맞아야 하기 때문이다.
	--   숨긴 자리 번호는 payload 에 넣지 않는다. 나가는 것은 마릿수까지다.
	local armed = 0
	if success and not gameTable.destroyed and gameTable.state == STATES.Playing then
		armed = self:_armDanger(CATCH.ArmOnCatch)
	end
	-- Phase 11 : 잡은 횟수는 성공했을 때만 오른다. 그만큼 이 사람의 다음 해적이 빨라진다.
	if success then
		self.catchesUsed[player] = (self.catchesUsed[player] or 0) + 1
		self:_writeSeatOrder()
	end

	local perfect = success and (catch.accuracy or 0) >= (CATCH.PerfectAccuracy or 1)

	catchResult:FireAllClients(gameTable.model, {
		userId = player.UserId,
		name = player.DisplayName or player.Name,
		success = success,
		reason = reason,
		index = self.catchCount + 1,
		accuracy = catch.accuracy or 0,
		perfect = perfect,
		-- 통 안에 아직 몇 마리가 있는지까지만 알린다. 어느 자리인지는 보내지 않는다.
		pirates = self:_liveDangerCount(),
		rearmed = armed > 0,
		-- 앞으로 몇 번 더 잡을 수 있는지 (0 이면 다음 해적은 분노한 해적)
		catchesLeft = self:_catchesLeft(player),
		level = self.catchesUsed[player] or 0,
		bot = GameConfig.isBot(player) or nil,
	})

	GameConfig.log(("%s · %s 잡기 %s (%s) · 남은 해적 %d마리")
		:format(gameTable.tableId, player.Name, success and "성공" or "실패", tostring(reason), self:_liveDangerCount()))

	if not success then
		if self.isParticipant[player] then
			self:_eliminate(player)
		elseif not self.gameTable.destroyed and self.gameTable.state == STATES.Playing then
			self:_beginTurn(self.turnIndex)
		end
		return
	end

	self.catchCount += 1
	self:_set(TABLE_ATTR.CatchCount, self.catchCount)
	self:_publishPirateCount()
	self:_earn(player, ECONOMY.CatchReward, "catches", POT.PerCatch)
	if perfect then
		self:_earn(player, ECONOMY.PerfectCatchBonus, "perfectCatches", POT.PerPerfect)
	end

	-- 살아남았다. 통은 새로 채우지 않는다.
	-- 대신 방금 숨긴 해적이 통 안에 남아 있으므로 긴장이 이어진다.
	if gameTable.destroyed or gameTable.state ~= STATES.Playing then
		return
	end

	self.phaseToken += 1
	local token = self.phaseToken
	task.delay(CATCH.Hold, function()
		if self.destroyed or token ~= self.phaseToken then
			return
		end
		if gameTable.destroyed or gameTable.state ~= STATES.Playing then
			return
		end

		-- 칼을 전부 뽑았을 때만 새로 채운다.
		if self:_freeSlotCount() == 0 then
			self:_refillBarrel()
		end

		self:_beginTurn(self.turnIndex + 1)
	end)
end

--------------------------------------------------
-- 방해 아이템 (Phase 8)
--
-- 결제 확인은 SabotageService 가 끝낸 뒤에 여기로 온다.
-- 여기서는 "지금 이 테이블에서 정말 쓸 수 있는 상황인가"만 다시 본다.
--------------------------------------------------

function Round:CanSabotage(actor, target)
	if self.destroyed or self.gameTable.destroyed then
		return false, REJECT.NotPlaying
	end
	if self.gameTable.state ~= STATES.Playing then
		return false, REJECT.NotPlaying
	end
	if not self.isParticipant[actor] then
		return false, REJECT.NotParticipant
	end
	if actor == target then
		return false, REJECT.NoTarget
	end
	-- AI 선원에게는 쓸 수 없다. (로벅스를 허공에 쓰게 두지 않는다)
	if GameConfig.isBot(target) then
		return false, REJECT.NoTarget
	end
	if GameConfig.Sabotage.TargetMustBeAlive and not self.isParticipant[target] then
		return false, REJECT.NoTarget
	end
	local used = self.sabotageUses[actor] or 0
	if used >= GameConfig.Sabotage.PerRoundLimit then
		return false, REJECT.SabotageCooldown
	end
	return true, nil
end

function Round:ApplySabotage(actor, target, item)
	local ok, reason = self:CanSabotage(actor, target)
	if not ok then
		return false, reason
	end

	self.sabotageUses[actor] = (self.sabotageUses[actor] or 0) + 1

	if item.turnCut then
		self.turnCut[target] = math.max(self.turnCut[target] or 0, item.turnCut)
	end

	-- 당한 사람에게는 효과를, 나머지에게는 "누가 누구에게 썼다"만 보낸다.
	sabotageCue:FireClient(target, self.gameTable.model, {
		id = item.id,
		mine = true,
		duration = item.duration,
		fromUserId = actor.UserId,
		fromName = actor.DisplayName or actor.Name,
	})
	for _, other in ipairs(self.participants) do
		if other ~= target and not GameConfig.isBot(other) then
			sabotageCue:FireClient(other, self.gameTable.model, {
				id = item.id,
				mine = false,
				fromUserId = actor.UserId,
				fromName = actor.DisplayName or actor.Name,
				toUserId = target.UserId,
				toName = target.DisplayName or target.Name,
			})
		end
	end

	GameConfig.log(("%s · %s → %s 방해(%s)")
		:format(self.gameTable.tableId, actor.Name, target.Name, item.id))
	return true, nil
end

function Round:GetOpponents(player)
	local list = {}
	for _, other in ipairs(self.participants) do
		if other ~= player and not GameConfig.isBot(other) then
			table.insert(list, other)
		end
	end
	return list
end

--------------------------------------------------
-- 탈락 / 승리
--------------------------------------------------

function Round:_eliminate(player)
	self.turnToken += 1
	self.resolving = true
	self:_clearBraveOffer()
	local gameTable = self.gameTable

	-- 잡기 도중에 탈락 처리가 들어오면(이탈 등) 진행 중인 잡기를 먼저 닫는다.
	if self.catch and self.catch.player == player then
		self.catch = nil
		self.catchToken += 1
	end

	local index = table.find(self.participants, player)
	if index then
		table.remove(self.participants, index)
		self.pirateOuts = (self.pirateOuts or 0) + 1
		table.insert(self.outOrder or {}, player)
	else
		index = self.turnIndex
	end
	-- ★ Phase 10 : "마지막으로 차례를 마친 자리"를 탈락한 사람 바로 앞으로 옮겨 둔다.
	--   아래 예약은 turnIndex + 1 로 다음 사람을 부른다. 기다리는 동안 누가 나가도
	--   RemoveParticipant 가 turnIndex 를 함께 당겨 주므로 한 명을 건너뛰지 않는다.
	--   (Phase 9 에서는 탈락한 자리 번호를 그대로 들고 있다가, 그 앞사람이 나가면 한 명을 건너뛰었다)
	self.turnIndex = index - 1
	self.isParticipant[player] = nil

	local remaining = #self.participants
	self:_set(TABLE_ATTR.TurnCount, remaining)
	self:_publishStage()

	gameTable:SetSeatAlive(player, false)
	ProfileService:BreakStreak(player)

	-- place : 이번 판 순위 (4명 중 처음 떨어지면 4위)
	presentation:FireAllClients("Eliminate", gameTable.model, {
		userId = player.UserId,
		name = player.DisplayName or player.Name,
		skin = player:GetAttribute("EliminationSkin") or "classic",
		place = remaining + 1,
		total = self.startingCount,
	})
 -- 탈락자는 자리에서 일어난다.
	gameTable:RemovePlayer(player)
 local root=(not GameConfig.isBot(player)) and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local body=gameTable.model:FindFirstChild("Body",true)
 if root and body then
  local direction=root.Position-body.Position
  if direction.Magnitude>0.01 then root.AssemblyLinearVelocity=direction.Unit*12+Vector3.new(0,9,0) end
 end
 self:_writeSeatOrder()

	GameConfig.log(("%s · %s 탈락 · 남은 인원 %d명"):format(gameTable.tableId, player.Name, remaining))

	self.phaseToken += 1
	local token = self.phaseToken
	task.delay(TIMING.ResultHold, function()
		if self.destroyed or token ~= self.phaseToken then
			return
		end
		if gameTable.destroyed then
			return
		end

		if #self.participants <= 1 then
			self:_declareWinner(self.participants[1])
			return
		end
		-- Phase 11 : 사람이 모두 떨어지고 AI 만 남았다. 더 볼 사람이 없으니 AI 의 승리로 접는다.
		if not self:_hasHuman() then
			self:_declareWinner(self.participants[1])
			return
		end

		-- 아직 둘 이상 남았다 → 통을 새로 채우고(해적도 새로 숨긴다) 다음 라운드로 올라간다.
		if gameTable.config.RefillOnElimination then
			self:_refillBarrel()
		end

		if gameTable.state ~= STATES.Playing then
			return
		end

		local stage, total = self:_publishStage()
		presentation:FireAllClients("Stage", gameTable.model, { stage = stage, total = total, alive = #self.participants })
		self:_beginTurn(self.turnIndex + 1)
	end)
end

-- 상대가 전부 스스로 나가서 이긴 짧은 판인가 (GameConfig.ForfeitWin)
function Round:_isFullWin()
	if (self.pirateOuts or 0) >= 1 then
		return true
	end
	local need = math.max(1, self.startingCount or 1) * (tonumber(GameConfig.ForfeitWin.MinPicksPerPlayer) or 2)
	return (self.picks or 0) >= need
end

function Round:_declareWinner(player)
	if self.settled or self.destroyed or self.gameTable.destroyed then
		return
	end
	self.settled = true
	self.turnToken += 1
	self.catchToken += 1
	self.catch = nil
	self.resolving = true
	self:_clearBraveOffer()
	local gameTable = self.gameTable

	-- ★ Phase 10 : 기권승은 승리로 기록하지 않는다.
	-- ★ Phase 11 : 대신 승리 보상과 현상금을 절반 받는다. 남은 현상금은 다음 판으로 이월된다.
	--             AI 가 이기면 현상금 절반이 이월된다. (AI 는 코인을 받지 않는다)
	local botWinner = player ~= nil and GameConfig.isBot(player)
	local fullWin = player ~= nil and not botWinner and self:_isFullWin()
	local credited = fullWin and player or nil
	local halfWinner = (player ~= nil and not botWinner and not fullWin) and player or nil
	local share = tonumber(GameConfig.ForfeitWin.RewardShare) or 0.5

	local potTotal = math.max(0, math.floor(self.pot or 0))
	local paid, carried = 0, 0
	if credited then
		paid = potTotal
	elseif halfWinner then
		paid = math.floor(potTotal * share)
		carried = self:_carryOver(potTotal - paid)
	else
		carried = self:_carryOver(botWinner and math.floor(potTotal * 0.5) or potTotal)
	end

	self:_set(TABLE_ATTR.WinForfeit, halfWinner ~= nil)
	if player then
		self:_set(TABLE_ATTR.WinnerUserId, player.UserId)
		self:_set(TABLE_ATTR.WinnerName, player.DisplayName or player.Name)
		GameConfig.log(("%s 라운드 %d 승자: %s%s"):format(gameTable.tableId, self.roundId, player.Name,
			(botWinner and " (AI)") or (fullWin and "") or " (기권승)"))
	else
		self:_set(TABLE_ATTR.WinnerUserId, 0)
		self:_set(TABLE_ATTR.WinnerName, "")
		GameConfig.log(("%s 라운드 %d 종료 · 승자 없음"):format(gameTable.tableId, self.roundId))
	end

	-- 기록과 보상 (Phase 7 : 승자뿐 아니라 참가자 전원의 판수가 저장된다)
	ProfileService:RecordRound(gameTable, self.roundRoster or {}, credited, self.forfeited, self.bonuses, paid, {
		halfWinner = halfWinner,
		practice = self.practice == true,
		winnerTakesAll = self:_winnerTakesAll(),
	})
	-- 연습 판(AI 동석)의 승리는 랭킹에 넣지 않는다.
	RankingService:RecordRound(gameTable, self.roundRoster or {}, (not self.practice) and credited or nil)
	if player and not botWinner then
		task.spawn(function()
			local analytics = game:GetService("AnalyticsService")
			pcall(analytics.LogCustomEvent, analytics, player, "RoundDuration", os.clock() - (self.roundStartedAt or os.clock()), { mode = gameTable.typeName })
		end)
	end

	local rosterIds = {}
	for _, member in ipairs(self.roundRoster or {}) do
		table.insert(rosterIds, member.UserId)
	end
	presentation:FireAllClients("Win", gameTable.model, {
		roster = rosterIds, -- Phase 15 : 이번 판에 참가한 사람 (진 사람 화면에는 "패배")
		winnerTakesAll = self:_winnerTakesAll() or nil,
		userId = player and player.UserId or 0,
		name = player and (player.DisplayName or player.Name) or "",
		streak = (credited and not self.practice) and (credited:GetAttribute(GameConfig.PlayerAttributes.Streak) or 0) or 0,
		skin = player and player:GetAttribute("VictorySkin") or "classic",
		duration = os.clock() - (self.roundStartedAt or os.clock()),
		forfeit = halfWinner ~= nil,
		pot = paid,
		carry = carried,
		bot = botWinner or nil,
		practice = self.practice or nil,
	})
	self:_set(TABLE_ATTR.PredictOpen, false)

	-- Phase 12 : 관전 예측 · 토너먼트 · 연습 판 마무리가 이 신호를 듣는다.
	RoundSettled:Fire({
		gameTable = gameTable,
		roundId = self.roundId,
		winner = player,
		credited = credited,
		halfWinner = halfWinner,
		botWinner = botWinner,
		practice = self.practice == true,
		roster = table.clone(self.roundRoster or {}),
		outOrder = table.clone(self.outOrder or {}),
		forfeited = table.clone(self.forfeited or {}),
		catches = table.clone(self.catchesUsed or {}),
		tutorialPlayer = self.tutorialPlayer,
	})
	-- 연습 판을 끝까지 했다 (이기든 지든)
	if self.tutorialPlayer and not GameConfig.isBot(self.tutorialPlayer) and not (self.forfeited or {})[self.tutorialPlayer] then
		ProfileService:MarkTutorialDone(self.tutorialPlayer)
	end

	self:_set(TABLE_ATTR.CurrentTurnUserId, 0)
	self:_set(TABLE_ATTR.CurrentTurnName, "")
	self:_set(TABLE_ATTR.TurnEndsAt, 0)
	self:_set(TABLE_ATTR.ResetEndsAt, GameConfig.now() + TIMING.RoundEndDuration)

	gameTable:SetState(STATES.RoundEnding)

	self.phaseToken += 1
	local token = self.phaseToken
	task.delay(TIMING.RoundEndDuration, function()
		if self.destroyed or token ~= self.phaseToken then
			return
		end
		self:_resetTable()
	end)
end

--------------------------------------------------
-- 초기화
--------------------------------------------------

function Round:_resetTable()
	self:_clearSeal()
	self:_clearBraveOffer()
	self.braveLevel = 0
	local gameTable = self.gameTable

	self.countdownToken += 1
	self.turnToken += 1
	self.phaseToken += 1
	local token = self.phaseToken

	table.clear(self.participants)
	table.clear(self.isParticipant)
	table.clear(self.dangerSlots)
	table.clear(self.turnCut)
	table.clear(self.sabotageUses)
	table.clear(self.catchesUsed)
	self.pot = 0
	self.picks = 0
	self.pirateOuts = 0
	self.outOrder = {}
	self.turnIndex = 0
	self.startingCount = 0
	-- Phase 12 : 연습 판은 한 판으로 끝난다
	if self.tutorialPlayer then
		self:_set(TABLE_ATTR.Tutorial, 0)
		self.tutorialPlayer = nil
	end
	self.barrelCycle = 0
	self.resolving = false
	self.catch = nil
	self.catchToken += 1
	self.catchCount = 0
	self:_set(TABLE_ATTR.CatchCount, 0)

	if gameTable.destroyed then
		return
	end

	gameTable:SetState(STATES.Resetting)
	gameTable:ResetSlots()
	gameTable:ResetBarrelLook()
	gameTable:ClearSeatFlags()
	self:_resetRoundAttributes()
	self:_set(TABLE_ATTR.SlotsRemaining, gameTable:GetSlotCount())

	task.delay(TIMING.ResetDuration, function()
		if self.destroyed or token ~= self.phaseToken then
			return
		end
		if gameTable.destroyed then
			return
		end

		gameTable:SetState(STATES.Waiting)
		gameTable:RefreshBarrelSkin()

		-- 아직 앉아 있는 사람이 있으면 곧바로 새 카운트다운이 시작된다.
		self:_evaluate()
	end)
end

--------------------------------------------------
-- 참가자 이탈 (퇴장 / 캐릭터 리셋 / 스스로 일어나기)
--------------------------------------------------

function Round:RemoveParticipant(player)
	if self.forfeited and self.isParticipant[player] then
		self.forfeited[player] = true
	end
	-- 잡는 도중에 나갔다. 잡기 결과를 기다리는 예약이 없으므로 아래에서 다음 차례를 직접 연다.
	local wasCatching = self.catch ~= nil and self.catch.player == player
	if wasCatching then
		self.catch = nil
		self.catchToken += 1
	end
	if self.braveOffer and self.braveOffer.player == player then
		self:_clearBraveOffer()
	end
	local index = table.find(self.participants, player)
	self.isParticipant[player] = nil
	self.turnCut[player] = nil

	if not index then
		self:_writeSeatOrder()
		return false
	end

	table.remove(self.participants, index)

	local count = #self.participants
	self:_set(TABLE_ATTR.TurnCount, count)
	self:_writeSeatOrder()
	if self.gameTable.state == STATES.Playing or self.gameTable.state == STATES.Starting then
		self:_publishStage()
	end

	GameConfig.log(("%s 참가자 이탈: %s · 남은 인원 %d명")
		:format(self.gameTable.tableId, player.Name, count))

	local state = self.gameTable.state
	if state ~= STATES.Playing and state ~= STATES.Starting then
		return true
	end

	task.spawn(function()
		local analytics = game:GetService("AnalyticsService")
		pcall(analytics.LogCustomEvent, analytics, player, "RoundForfeit", 1, { mode = self.gameTable.typeName })
	end)
	-- 게임 중에 스스로 나간 사람은 연승이 끊긴다. (나가서 연승을 지키는 짓 방지)
	ProfileService:BreakStreak(player)

	if count == 1 then
		self:_declareWinner(self.participants[1])
		return true
	end

	-- Phase 11 : 사람이 모두 나가고 AI 만 남았다.
	if count > 1 and not self:_hasHuman() then
		self:_declareWinner(self.participants[1])
		return true
	end

	if count == 0 then
		self:_finishRound("참가자가 모두 자리를 떠남")
		return true
	end

	if state ~= STATES.Playing then
		return true
	end

	if index < self.turnIndex then
		self.turnIndex -= 1
		self:_set(TABLE_ATTR.TurnIndex, self.turnIndex)
	elseif index == self.turnIndex then
		if self.resolving and not wasCatching then
			-- ★ Phase 10 : 결과를 보여주는 중(안전한 자리 · 탈락 연출)에 나갔다.
			--   곧 "turnIndex + 1" 로 다음 사람을 부르는 예약이 있으므로, 여기서 차례를 또 열지 않는다.
			--   (Phase 9 에서는 여기서 한 번, 예약에서 한 번 더 넘겨서 한 명을 건너뛰었다)
			self.turnIndex = index - 1
		else
			self.phaseToken += 1
			self:_beginTurn(index)
		end
	end

	return true
end

function Round:_onRosterChanged(player, joined)
	if self.destroyed or self.gameTable.destroyed then
		return
	end

	-- 누가 앉거나 일어날 때마다 이 테이블의 통 스킨을 다시 고른다. (Phase 7)
	self.gameTable:RefreshBarrelSkin()

	if joined then
		self:_writeSeatOrder()
		self:_evaluate()
		return
	end

	if self.isParticipant[player] then
		self:RemoveParticipant(player)
	else
		self:_writeSeatOrder()
	end

	self:_evaluate()
end

--------------------------------------------------
-- 조회 API
--------------------------------------------------

function Round:_clearSeal()
	if self.sealed then
		local slot = self.gameTable:GetSlot(self.sealed)
		if slot then
			slot:SetAttribute("Sealed", false)
		end
	end
	self.sealed = nil
	self.sealedBy = nil
	self:_set("SealedSlot", 0)
end
-- 파티 카드 (PartyCards6 테이블 전용). 한 판에 종류별로 한 번씩, 내 차례에만 쓴다.
--   skip   : 이번 차례를 넘긴다
--   rotate : 숨은 해적의 자리를 빈 자리 안에서 다시 섞는다 (마릿수는 그대로)
--   seal   : 빈 자리 하나를 봉인한다. 봉인은 "다음 사람"이 고를 때까지 유지된다.
function Round:UseCard(player, card, index, roundId, serial)
	if not self.gameTable.config.SpecialCards then
		return false, "일반 테이블에서는 카드를 쓰지 않습니다"
	end
	if roundId ~= self.roundId or serial ~= self.turnToken or self.resolving or self:GetCurrentPlayer() ~= player
		or not self.isParticipant[player] or self.gameTable.state ~= STATES.Playing then
		return false, "지금은 사용할 수 없습니다"
	end
	local hand = self.cards and self.cards[player]
	if not hand or not hand[card] then
		return false, "이미 사용한 카드입니다"
	end
	local free = self.gameTable:GetFreeSlotIndices()
	if card == "seal" then
		-- 봉인한 뒤에도 내가 하나 꽂고, 다음 사람에게 고를 자리가 둘 이상 남아야 한다. 그래서 4칸 이상.
		if typeof(index) ~= "number" or index ~= index or index % 1 ~= 0 or not table.find(free, index) or #free < 4 or self.sealed then
			return false, "봉인할 빈 자리를 고르세요 (빈 자리 4칸 이상일 때)"
		end
	end
	hand[card] = false
	self:_set("CardSkip", hand.skip)
	self:_set("CardRotate", hand.rotate)
	self:_set("CardSeal", hand.seal)
	if card == "skip" then
		self:AdvanceTurn()
	elseif card == "rotate" then
		local count = math.min(self:_liveDangerCount(), #free)
		Utility.shuffle(free, self.random)
		table.clear(self.dangerSlots)
		for i = 1, count do
			self.dangerSlots[free[i]] = true
		end
		self:_publishPirateCount()
	elseif card == "seal" then
		self.sealed = index
		self.sealedBy = player
		local slot = self.gameTable:GetSlot(index)
		if slot then
			slot:SetAttribute("Sealed", true)
		end
		self:_set("SealedSlot", index)
	end
	presentation:FireAllClients("Card", self.gameTable.model, { card = card, userId = player.UserId, name = player.DisplayName or player.Name })
	return true, "카드 사용 / Card used"
end

function Round:GetParticipants()
	return table.clone(self.participants)
end

function Round:GetCurrentPlayer()
	return self.participants[self.turnIndex]
end

function Round:IsPlayerTurn(player)
	return self:GetCurrentPlayer() == player
end

--------------------------------------------------
-- RoundService : 테이블마다 Round 를 하나씩 붙인다
--------------------------------------------------

local RoundService = {}
RoundService._rounds = {} -- [GameTable] = Round
RoundService._cleaner = Utility.Cleaner.new()
RoundService._started = false
RoundService._selectLimiter = Utility.RateLimiter.new(GameConfig.SelectCooldown)
RoundService._braveLimiter = Utility.RateLimiter.new(0.3)
RoundService.RoundSettled = RoundSettled -- Phase 12

function RoundService:_attach(gameTable)
	if self._rounds[gameTable] or gameTable.destroyed then
		return
	end

	local ok, result = pcall(Round.new, gameTable)
	if not ok then
		warn(("[CursedBarrel] 라운드 담당 생성 실패 (%s): %s"):format(tostring(gameTable.tableId), tostring(result)))
		return
	end

	self._rounds[gameTable] = result
	GameConfig.log(("라운드 담당 등록: %s"):format(tostring(gameTable.tableId)))
end

function RoundService:_detach(gameTable)
	local round = self._rounds[gameTable]
	if not round then
		return
	end

	self._rounds[gameTable] = nil

	local ok, err = pcall(function()
		round:Destroy()
	end)
	if not ok then
		warn("[CursedBarrel] 라운드 정리 중 오류: " .. tostring(err))
	end
end

--------------------------------------------------
-- RemoteEvent : 화면 버튼으로 들어오는 슬롯 선택
--
-- 클라이언트가 보내는 값은 전부 의심한다.
--------------------------------------------------

function RoundService:_ensureRemote()
	local root = ReplicatedStorage:FindFirstChild("CursedBarrel")
	if not root then
		root = Instance.new("Folder")
		root.Name = "CursedBarrel"
		root.Parent = ReplicatedStorage
	end

	local folder = root:FindFirstChild(GameConfig.Remotes.Folder)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = GameConfig.Remotes.Folder
		folder.Parent = root
	end

	local remote = folder:FindFirstChild(GameConfig.Remotes.SelectSlot)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = GameConfig.Remotes.SelectSlot
		remote.Parent = folder
	end

	return remote
end

function RoundService:_onSelectRequest(player, tableModel, slotIndex)
	local remote = self._remote

	local function reject(reason)
		if remote then
			remote:FireClient(player, false, reason)
		end
		return false
	end

	if not self._selectLimiter:check(player.UserId) then
		return reject(REJECT.TooFast)
	end
	if typeof(tableModel) ~= "Instance" or not tableModel:IsA("Model") then
		return reject(REJECT.OtherTable)
	end
	if typeof(slotIndex) ~= "number" or slotIndex ~= slotIndex or slotIndex==math.huge or slotIndex==-math.huge or slotIndex%1~=0 then
		return reject(REJECT.BadSlot)
	end

	local gameTable = TableService:GetTableFromModel(tableModel)
	if not gameTable then
		return reject(REJECT.OtherTable)
	end

	-- ★ "내가 앉아 있는 테이블"과 요청한 테이블이 같아야 한다.
	local seatedTable = TableService:GetTableOfPlayer(player)
	if seatedTable ~= gameTable then
		GameConfig.log(("%s 의 다른 테이블(%s) 요청 거부"):format(player.Name, tostring(gameTable.tableId)))
		return reject(REJECT.OtherTable)
	end

	local round = self._rounds[gameTable]
	if not round then
		return reject(REJECT.NotPlaying)
	end

	local reason = round:HandlePick(player, slotIndex, "remote")
	if reason then
		return reject(reason)
	end

	if remote then
		remote:FireClient(player, true, math.floor(slotIndex))
	end
	return true
end

function RoundService:Start()
	if self._started then
		return
	end
	self._started = true

	self._remote = self:_ensureRemote()

	-- 해적 잡기 입력. 판정은 전부 Round 안에서 다시 검사한다.
	self._cleaner:add(catchInput.OnServerEvent:Connect(function(player, tableModel, tappedAt)
		local ok, err = pcall(function()
			if typeof(tableModel) ~= "Instance" or not tableModel:IsA("Model") then
				return
			end
			local gameTable = TableService:GetTableFromModel(tableModel)
			if not gameTable or TableService:GetTableOfPlayer(player) ~= gameTable then
				return
			end
			local round = self._rounds[gameTable]
			if round then
				round:HandleCatchInput(player, tappedAt)
			end
		end)
		if not ok then
			warn("[CursedBarrel] 잡기 입력 처리 중 오류: " .. tostring(err))
		end
	end))

	-- Phase 10 : "한 번 더" 요청. 판정은 Round:AcceptBrave 가 다시 한다.
	self._cleaner:add(braveRemote.OnServerEvent:Connect(function(player, tableModel)
		local ok, err = pcall(function()
			if not self._braveLimiter:check(player.UserId) then
				return
			end
			if typeof(tableModel) ~= "Instance" or not tableModel:IsA("Model") then
				return
			end
			local gameTable = TableService:GetTableFromModel(tableModel)
			if not gameTable or TableService:GetTableOfPlayer(player) ~= gameTable then
				return
			end
			local round = self._rounds[gameTable]
			if round then
				local accepted, reason = round:AcceptBrave(player)
				if not accepted and reason and self._remote then
					self._remote:FireClient(player, false, reason)
				end
			end
		end)
		if not ok then
			warn("[CursedBarrel] 배짱 요청 처리 중 오류: " .. tostring(err))
		end
	end))

	self._cleaner:add(self._remote.OnServerEvent:Connect(function(player, tableModel, slotIndex)
		local ok, err = pcall(function()
			self:_onSelectRequest(player, tableModel, slotIndex)
		end)
		if not ok then
			warn("[CursedBarrel] 슬롯 요청 처리 중 오류: " .. tostring(err))
		end
	end))

	self._cleaner:add(TableService.TableAdded:Connect(function(gameTable)
		self:_attach(gameTable)
	end))

	self._cleaner:add(TableService.TableRemoved:Connect(function(gameTable)
		self:_detach(gameTable)
	end))

	self._cleaner:add(Players.PlayerRemoving:Connect(function(player)
		self._selectLimiter:forget(player.UserId)
		self._braveLimiter:forget(player.UserId)
		for _, round in pairs(self._rounds) do
			round.pickLimiter:forget(player.UserId)
		end
	end))

	for _, gameTable in ipairs(TableService:GetAllTables()) do
		self:_attach(gameTable)
	end

	GameConfig.log("RoundService 시작 완료")
end

function RoundService:GetRound(gameTable)
	return self._rounds[gameTable]
end

function RoundService:GetRoundOfPlayer(player)
	local gameTable = TableService:GetTableOfPlayer(player)
	if not gameTable then
		return nil
	end
	return self._rounds[gameTable]
end

return RoundService
