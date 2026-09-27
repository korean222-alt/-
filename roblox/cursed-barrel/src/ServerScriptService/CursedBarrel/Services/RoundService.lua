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

Phase 32 에서 바뀐 것 (요청하신 것)
  · 해적 종류 : 보통 · 쌍둥이(두 번) · 갈고리(방향) · 해골 유령(참기) · 욕심쟁이(연타) · 분노한 해적.
    라운드가 오를수록 새 종류가 풀린다 (GameConfig.PirateKinds). 판정은 전부 여기서 한다.
  · 운명 카드 : 라운드(통)가 새로 시작될 때마다 카드 한 장. 그 라운드의 규칙이 바뀐다 (GameConfig.FateCards).
    카드를 보여 주는 동안(RevealTime) 다음 차례를 미룬다 (holdTurnsUntil).
  · 끝없는 라운드 : 16번 잡은 뒤 "분노한 해적만" 나오던 벽을 없앴다. 창의 바닥은 0.30초. 5라운드마다 보너스.
  · 신입 보호 : 판 수가 적은 사람은 한 판에 한 번, 놓쳐도 같은 해적이 다시 나온다.
  · 필수 튜토리얼 : 처음 온 사람의 연습 판에서는 내 칼이 항상 해적 자리에 꽂히고(AI 는 항상 안전),
    종류를 하나씩 모두 잡아야 끝난다. 놓쳐도 다시 나온다. 다 잡으면 이 판은 내 승리로 끝난다.
  · 판을 끝까지 하면(탈락 포함 · 스스로 나가면 제외) 오늘 판 수를 센다 → GamesToUnlock(3) 판이면 룰렛이 열린다.

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
local RewardService = require(script.Parent.RewardService) -- Phase 32 : 판을 끝까지 하면 룰렛까지 몇 판 남았는지 알린다
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
local startRemote = ensureRemote("TableStart") -- Phase 24 : 방장의 「▶ 시작」
local braveRemote = ensureRemote(GameConfig.Remotes.Brave)
local CATCH = GameConfig.Catch
local BRAVE = GameConfig.Brave
local POT = GameConfig.Pot
local KINDS = GameConfig.PirateKinds -- Phase 32 : 해적 종류

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
	self.turnCutFrom = {} -- Phase 24 : [Player] = { actor, onVoid } 재촉을 건 사람 (발동 전에 판이 끝나면 돌려준다)
	self.pendingSabotage = {} -- Phase 24 : [Player] = { { item, actor, onVoid } } 그 사람 차례가 오면 발동할 방해
	self.sabotageUses = {} -- [Player] = 이번 라운드에 쓴 횟수

	-- Phase 10
	self.catchesUsed = {} -- [Player] = 이번 판에 쓴 잡기 기회
	self.hardSteps = {} -- Phase 21 : [Player] = 어려운 경지에 들어선 뒤 잡은 횟수
	self.braveLevel = 0 -- 지금 차례의 사람이 몇 번째로 더 찌르는 중인지
	self.braveOffer = nil -- { player, token } "한 번 더" 제안
	self.pot = 0
	self.carry = 0 -- Phase 11 : 다음 판으로 넘어갈 현상금 (테이블에 남는다)
	self.practice = false -- Phase 11 : AI 선원이 낀 연습 판인가
	self.picks = 0 -- 이번 판에 꽂힌 칼 수
	self.playerPicks = {} -- Phase 24 : [Player] = 이번 판에 직접 꽂은 칼 수 (기권승 보상 조건)
	self.pirateOuts = 0 -- 이번 판에 해적에게 탈락한 사람 수 (스스로 나간 사람은 세지 않는다)
	self.afk = {}
	self.forfeited = {}
	self.bonuses = {}
	self.cards = {}
	-- Phase 32
	self.card = nil -- 이번 라운드의 운명 카드 (GameConfig.FateCards 의 항목)
	self.holdTurnsUntil = 0 -- 카드를 보여 주는 동안 차례를 미룬다 (서버 시각)
	self.rookieSaved = {} -- [Player] = true (이번 판에 신입 보호를 썼다)
	self.angryCaught = {} -- [Player] = 이번 판에 잡은 분노한 해적 수
	self.gameCounted = {} -- [Player] = true (이번 판을 오늘 판 수에 셌다)
	self.tutorial = nil -- { player, step, idle, finished, ended } 필수 튜토리얼

	-- 예약한 작업을 취소하는 대신 토큰을 하나 올린다.
	-- 늦게 도착한 task.delay 콜백은 토큰이 다르면 스스로 물러난다.
	self.countdownToken = 0
	self.turnToken = 0
	self.phaseToken = 0
	self.seatedAt = {} -- Phase 24 : [Player] = 앉은 순서 (방장 = 가장 먼저 앉은 사람)
	self.seatSerial = 0
	for _, occupant in ipairs(gameTable:GetPlayers()) do
		self.seatSerial += 1
		self.seatedAt[occupant] = self.seatSerial
	end

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
	self:_voidAllSabotage()
	table.clear(self.participants)
	table.clear(self.roundRoster)
	table.clear(self.isParticipant)
	table.clear(self.dangerSlots)
	table.clear(self.turnCut)
	table.clear(self.sabotageUses)
	table.clear(self.catchesUsed)
	table.clear(self.hardSteps)
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
	self:_set(TABLE_ATTR.FinalRound, false)
	self:_set(TABLE_ATTR.WinnerTakesAll, self:_winnerTakesAll())
	self:_clearBraveOffer()
	self:_writeSeatOrder()
end

--------------------------------------------------
-- Phase 15 : 최후의 1인 · 라운드
--------------------------------------------------

-- 최후의 1인이 전부 가져가는 테이블인가 (3인 이상 테이블 · TableConfig. 처음 온 사람의 연습 판은 빼 준다)
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

-- 지금 몇 라운드인가.
-- Phase 24 : 통 하나가 한 라운드다. 칼을 다 꽂아 통을 새로 채우면(누가 탈락해 새로 채울 때도) 다음 라운드.
--   (예전에는 한 명이 떨어질 때마다 올라가서 칼을 다 꽂아도 라운드가 그대로였다)
--   3명 이상으로 시작한 판에서 둘만 남으면 "결승" (FinalRound).
function Round:_publishStage()
	local stage = math.max(1, self.barrelCycle or 1)
	local final = (self.startingCount or 0) >= 3 and #self.participants == 2
	self:_set(TABLE_ATTR.Stage, stage)
	self:_set(TABLE_ATTR.StageCount, 0)
	self:_set(TABLE_ATTR.FinalRound, final)
	-- Phase 24.10 : 이 라운드까지 살아 있는 사람의 최고 라운드 기록 (최고 라운드 순위판)
	local state = self.gameTable.state
	if state == STATES.Playing or state == STATES.Starting then
		for _, participant in ipairs(self.participants) do
			if not GameConfig.isBot(participant) then
				ProfileService:Bump(participant, "bestRound", 0, stage)
			end
		end
	end
	return stage, final
end

--------------------------------------------------
-- 상태 판단
--------------------------------------------------

-- Phase 24 : 방장 = 지금 앉아 있는 사람(AI 제외) 중 가장 먼저 앉은 사람
function Round:_host()
	local best, bestOrder = nil, math.huge
	for _, occupant in ipairs(self.gameTable:GetPlayers()) do
		local order = self.seatedAt[occupant]
		if not GameConfig.isBot(occupant) and order and order < bestOrder then
			best, bestOrder = occupant, order
		end
	end
	return best
end

function Round:_publishHost()
	local host = self:_host()
	self:_set(TABLE_ATTR.HostUserId, host and host.UserId or 0)
end

-- 대기 중 카운트다운 길이 (Phase 24)
function Round:_lobbyCountdown()
	local lobby = GameConfig.Lobby
	local tutorialId = self.gameTable.model and self.gameTable.model:GetAttribute(TABLE_ATTR.Tutorial) or 0
	if not (lobby and lobby.HostStart) or (tutorialId and tutorialId ~= 0) then
		return nil -- 예전처럼 테이블 설정의 CountdownDuration
	end
	if self.gameTable:GetPlayerCount() >= #self.gameTable:GetSeats() then
		return lobby.FullCountdown
	end
	return lobby.WaitForHost
end

-- 방장이 「▶ 시작」을 눌렀다
function Round:HostStart(player)
	local lobby = GameConfig.Lobby
	if not (lobby and lobby.HostStart) or self.destroyed or self.gameTable.destroyed then
		return false
	end
	local state = self.gameTable.state
	if state ~= STATES.Waiting and state ~= STATES.Countdown then
		return false
	end
	if self:_host() ~= player or self.gameTable:GetPlayerCount() < self:_minPlayers() then
		return false
	end
	local left = (tonumber(self.gameTable.model and self.gameTable.model:GetAttribute(TABLE_ATTR.CountdownEndsAt)) or 0) - GameConfig.now()
	if state == STATES.Countdown and left <= lobby.HostCountdown then
		return true
	end
	self:_startCountdown(lobby.HostCountdown)
	return true
end

function Round:_evaluate()
	if self.destroyed or self.gameTable.destroyed then
		return
	end

	local state = self.gameTable.state
	local seated = self.gameTable:GetPlayerCount()
	local minPlayers = self:_minPlayers()
	self:_publishHost()

	if state == STATES.Waiting then
		if seated >= minPlayers then
			self:_startCountdown(self:_lobbyCountdown())
		end
	elseif state == STATES.Countdown then
		if seated < minPlayers then
			self:_cancelCountdown()
		else
			-- Phase 24 : 기다리는 중에 자리가 다 찼으면 짧게 줄인다
			local want = self:_lobbyCountdown()
			local left = (tonumber(self.gameTable.model and self.gameTable.model:GetAttribute(TABLE_ATTR.CountdownEndsAt)) or 0) - GameConfig.now()
			if want and left > want + 0.5 then
				self:_startCountdown(want)
			end
		end
	end
	-- 게임 중의 인원 변화는 RemoveParticipant 가 따로 처리한다.
end

--------------------------------------------------
-- 카운트다운
--------------------------------------------------

function Round:_startCountdown(override)
	local duration = tonumber(override) or tonumber(self.gameTable.config.CountdownDuration) or 5
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
-- stage : 몇 라운드 통인가 (없으면 지금 라운드)
function Round:_targetPirateCount(stage)
	local base = TableConfig.getDangerCount(self.gameTable.typeName, #self.gameTable:GetSeats())
	-- Phase 12 : 폭풍(크라켄 습격) 동안 해적이 늘어난다. 통에 고를 자리는 넉넉히 남긴다.
	local extra = math.max(0, math.floor(tonumber(GameConfig.worldMods().extraPirate) or 0))
	local slots = TableConfig.getSlotCount(self.gameTable.typeName)
	-- Phase 24.10 : 라운드가 올라갈수록 해적이 늘어난다 (1 · 2라운드 1~2마리 → 최대 5마리)
	local ramp = GameConfig.RoundPirates
	if ramp and ramp.Enabled then
		local list = ramp.ByStage
		stage = math.max(1, math.floor(tonumber(stage) or self.barrelCycle or 1))
		local count = list[math.min(stage, #list)] or 1
		local cap = math.min(ramp.Max or 5, math.max(1, math.floor(slots * (ramp.MaxShare or 0.4))))
		-- Phase 32 : 운명 카드 (황금 통 +1 · 행운의 통 -1)
		local delta = math.floor(tonumber(self.card and self.card.pirates) or 0)
		return math.clamp(count + extra + delta, 1, math.max(1, cap + math.max(0, delta)))
	end
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
	-- Phase 32 : 새 라운드의 운명 카드를 먼저 뽑는다 (카드가 해적 수를 바꿀 수 있다)
	self:_drawCard(self.barrelCycle + 1)
	local dangerCount = math.min(self:_targetPirateCount(self.barrelCycle + 1), math.max(1, slotCount - 1)) -- 이제 채우는 통의 라운드

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
	-- Phase 24 : 새 통 = 새 라운드. 게임 중에 채울 때만 "N 라운드!" 를 알린다 (첫 통은 "시작!" 이 대신한다)
	local stage, final = self:_publishStage()
	if gameTable.state == STATES.Playing and self.barrelCycle > 1 then
		presentation:FireAllClients("Stage", gameTable.model, { stage = stage, final = final, alive = #self.participants })
		-- Phase 32 : 끝없는 라운드. 5라운드마다 살아 있는 사람에게 보너스
		local endless = GameConfig.Endless
		local every = endless and math.floor(tonumber(endless.MilestoneEvery) or 0) or 0
		if every > 0 and stage % every == 0 then
			local coins = tonumber(endless.MilestoneCoins) or 0
			for _, participant in ipairs(self.participants) do
				if not GameConfig.isBot(participant) and coins > 0 then
					self:_earn(participant, coins, nil)
				end
			end
			presentation:FireAllClients("Milestone", gameTable.model, { stage = stage, coins = coins, pot = self:_winnerTakesAll() or nil })
		end
	end

	-- 로그에도 위험 자리 번호는 남기지 않는다.
	GameConfig.log(("%s 통 %d번째 채움 · 칼 %d자루 · 해적 %d마리")
		:format(gameTable.tableId, self.barrelCycle, slotCount, dangerCount))
end

function Round:_freeSlotCount()
	return #self.gameTable:GetFreeSlotIndices()
end

--------------------------------------------------
-- Phase 32 : 운명 카드 · 판 수 세기
--------------------------------------------------

-- 이번 라운드 카드의 배율 (카드가 없거나 그 항목이 없으면 1)
function Round:_cardValue(key)
	local card = self.card
	return card and tonumber(card[key]) or 1
end

-- 새 라운드의 카드를 뽑아 모두에게 보여 준다. 보여 주는 동안 다음 차례를 미룬다.
function Round:_drawCard(stage)
	local cards = GameConfig.FateCards
	local card = nil
	if cards and cards.Enabled then
		-- Phase 32.1 : 튜토리얼 판에는 카드가 없다 (해적 종류만 배운다 · 한꺼번에 읽을 것을 줄인다)
		if not self.tutorial then
			card = GameConfig.drawFateCard(stage, self.card and self.card.id, self.random)
		end
	end
	self.card = card
	self:_set("FateCard", card and card.id or "")
	if card then
		presentation:FireAllClients("FateCard", self.gameTable.model, { card = card.id, stage = stage })
		self.holdTurnsUntil = GameConfig.now() + (tonumber(cards.RevealTime) or 2.6)
		GameConfig.log(("%s %d라운드 운명 카드 · %s"):format(self.gameTable.tableId, stage, card.name))
	end
end

-- "떠도는 해적" 카드 : 차례마다 해적이 아직 안 꽂은 빈 자리 안에서 자리를 옮긴다 (마릿수는 그대로 · 봉인된 자리는 건드리지 않는다)
function Round:_driftPirates()
	local moving = {}
	for slotIndex in pairs(self.dangerSlots) do
		if not self.gameTable:IsSlotUsed(slotIndex) and slotIndex ~= self.sealed then
			table.insert(moving, slotIndex)
		end
	end
	if #moving == 0 then
		return
	end
	local free = {} -- 옮겨 갈 수 있는 자리 = 봉인되지 않은 빈 자리 (지금 해적이 있는 자리 포함)
	for _, slotIndex in ipairs(self.gameTable:GetFreeSlotIndices()) do
		if slotIndex ~= self.sealed then
			table.insert(free, slotIndex)
		end
	end
	-- 고를 자리가 해적보다 넉넉할 때만 옮긴다 (마지막 한 칸이 무조건 해적이 되지 않게)
	if #free <= #moving + (CATCH.MinFreeSlotsToArm or 1) - 1 then
		return
	end
	for _, slotIndex in ipairs(moving) do
		self.dangerSlots[slotIndex] = nil
	end
	Utility.shuffle(free, self.random)
	for index = 1, #moving do
		self.dangerSlots[free[index]] = true
	end
end

-- 이 사람이 이번 판을 끝까지 했다 (탈락했거나 판이 끝났다). 오늘 판 수를 센다 → GamesToUnlock(3) 판이면 룰렛이 열린다.
function Round:_countGame(player)
	if GameConfig.isBot(player) or player.Parent ~= Players or self.gameCounted[player] then
		return
	end
	self.gameCounted[player] = true
	local games, unlockedNow, comebackNow = ProfileService:CountGame(player)
	pcall(RewardService.OnGameCounted, RewardService, player, games, unlockedNow, comebackNow)
	local profile = ProfileService:Get(player)
	if profile and profile.tutorialDone then
		ProfileService:Funnel(player, 5, "FirstGameFinished")
		if games >= 2 then
			ProfileService:Funnel(player, 6, "SecondGameFinished")
		end
	end
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
	self.jackpotStage = nil -- Phase 21 : 새 판은 1라운드 잭팟부터 다시 굴린다
	self.jackpot = nil
	self.cards = {}
	self.afk = {}
	self.sealed = nil
	self.sealedBy = nil
	self.settled = false
	self.roundStartedAt = os.clock()
	table.clear(self.catchesUsed)
	table.clear(self.hardSteps)
	self.braveLevel = 0
	self.braveOffer = nil
	self.picks = 0
	self.playerPicks = {}
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
	-- Phase 32 : 필수 튜토리얼 (아직 튜토리얼을 마치지 않았거나 "튜토리얼 다시 보기"로 앉았다)
	self.tutorial = nil
	self.card = nil
	self.holdTurnsUntil = 0
	self.rookieSaved = {}
	self.angryCaught = {}
	self.gameCounted = {}
	if self.tutorialPlayer and GameConfig.Tutorial.Mandatory and not GameConfig.isBot(self.tutorialPlayer) then
		local profile = ProfileService:Get(self.tutorialPlayer)
		local replay = self.gameTable.model and self.gameTable.model:GetAttribute("TutorialReplay") == true
		if (profile and not profile.tutorialDone) or replay then
			self.tutorial = { player = self.tutorialPlayer, step = 1, idle = 0 }
			ProfileService:Funnel(self.tutorialPlayer, 2, "TutorialStarted")
		end
	end
	self:_set("TutorialStep", self.tutorial and 1 or 0)
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
	self:_voidAllSabotage()
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

	-- Phase 32 : 운명 카드를 보여 주는 동안은 차례를 미룬다.
	--   미루는 동안 누가 나가면 RemoveParticipant 가 turnIndex 를 당겨 두므로, "지금 번호에서 몇 칸 뒤"로 기억한다.
	local hold = (self.holdTurnsUntil or 0) - GameConfig.now()
	if hold > 0.05 and self.gameTable.state == STATES.Playing then
		local delta = index - self.turnIndex
		self.phaseToken += 1
		local token = self.phaseToken
		task.delay(hold, function()
			if self.destroyed or token ~= self.phaseToken or self.gameTable.destroyed or self.gameTable.state ~= STATES.Playing then
				return
			end
			self:_beginTurn(self.turnIndex + delta, braveContinue)
		end)
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

		-- Phase 32 : "떠도는 해적" 카드 : 차례마다 해적이 자리를 옮긴다
		if self.card and self.card.shuffle and not braveContinue then
			self:_driftPirates()
		end
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
	-- Phase 32 : "급한 물살" 카드
	if duration > 0 and self.card and self.card.turn then
		duration = math.max(4, duration * self.card.turn)
	end

	-- Phase 8 : "저주의 재촉"을 맞았으면 이번 턴만 짧아진다.
	local cut = self.turnCut[player]
	if cut and duration > 0 then
		self.turnCut[player] = nil
		self.turnCutFrom[player] = nil
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

	-- Phase 24 : 이 사람에게 예약돼 있던 방해(흔들기 · 뒤섞기 · 먹물 · 포효)는 이 사람 차례가 열린 지금 발동한다.
	if self.gameTable.state == STATES.Playing then
		self:_flushSabotage(player)
	end

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
	-- Phase 32.1 : 튜토리얼 판의 AI 는 천천히 고른다 (방금 본 것을 읽을 틈)
	if self:_tutorialActive() then
		delay += tonumber(GameConfig.Tutorial.BotThinkExtra) or 0
	end
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
-- Phase 32 : 해적 종류마다 사람과 같은 방법으로 누른다 (쌍둥이 두 번 · 갈고리 방향 · 해골은 참기 · 연타)
local BOT_KIND_SCALE = { twin = 0.8, side = 0.9, skull = 0.85, mash = 0.9 }
function Round:_botCatch(bot, catch)
	local skill = tonumber(bot.skill) or 0.5
	local kind = catch.kind or "normal"
	local steps = catch.steps or { { opensAt = catch.opensAt, window = catch.window } }
	local first = steps[1]
	local chance = math.clamp(skill + (first.window - 0.45) * 1.6, 0.08, 0.92)
	if kind == "skull" or kind == "mash" then
		chance = math.clamp(skill + 0.2, 0.2, 0.9) -- 창 길이가 박자가 아니라 버티는 시간이다
	end
	if catch.angry then
		chance *= tonumber(CATCH.AngryBotScale) or 0.45
	end
	chance *= BOT_KIND_SCALE[kind] or 1
	local token = catch.token
	local function tapAt(at, side)
		task.delay(math.max(0, at - GameConfig.now()), function()
			if self.destroyed or token ~= self.catchToken then
				return
			end
			self:HandleCatchInput(bot, GameConfig.now(), true, side)
		end)
	end
	local success = self.random:NextNumber() < chance
	if kind == "skull" then
		-- 참으면 서버가 스스로 살려 준다. 못 참으면 유령을 누른다
		if not success then
			tapAt(first.opensAt + 0.1 + self.random:NextNumber() * 0.4)
		end
		return
	end
	if not success then
		local roll = self.random:NextNumber()
		if roll < 0.35 then
			-- 겁먹고 먼저 누른다 (사람도 가장 많이 하는 실수)
			tapAt(math.max(catch.startedAt + CATCH.ArmDelay + 0.05, first.opensAt - 0.15 - self.random:NextNumber() * 0.3))
		elseif kind == "side" and roll < 0.7 then
			tapAt(first.opensAt + first.window * 0.4, catch.side == "L" and "R" or "L") -- 반대쪽을 누른다
		elseif kind == "mash" then
			-- 모자라게 누른다 (시간이 다 되면 놓친 것이 된다)
			for index = 1, math.max(1, (catch.need or 5) - 2) do
				tapAt(first.opensAt + 0.2 + index * 0.3)
			end
		else
			local last = steps[#steps]
			tapAt(last.opensAt + last.window + CATCH.Grace + 0.08 + self.random:NextNumber() * 0.3)
		end
		return
	end
	if kind == "mash" then
		local need = catch.need or 5
		local span = first.window * (0.45 + self.random:NextNumber() * 0.35)
		for index = 1, need do
			tapAt(first.opensAt + 0.12 + span * (index - 1) / math.max(1, need - 1))
		end
		return
	end
	for _, step in ipairs(steps) do
		tapAt(step.opensAt + step.window * (0.15 + self.random:NextNumber() * 0.7), catch.side)
	end
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

	-- Phase 24.10 : "한 번 더" 버튼 없이 이어 꽂기. 제안이 와 있는 동안 자리를 누르면 받아들인 것으로 친다.
	local offer = self.braveOffer
	if BRAVE.AutoContinue and offer and offer.player == player and offer.token == self.phaseToken then
		-- Phase 24.13 : 방금 꽂은 칼에서 쿨타임(0.5초)이 지나야 이어 꽂는다 (화면도 같은 시간만큼 막는다. 전파 흔들림 0.05초는 봐준다)
		if GameConfig.now() - (self.lastPickAt or 0) < (tonumber(BRAVE.ContinueCooldown) or 0) - 0.05 then
			return REJECT.TooFast
		end
		self:AcceptBrave(player)
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
	self.lastPickAt = GameConfig.now() -- Phase 24.13 : 이어 꽂기 쿨타임 기준
	local isDanger = self.dangerSlots[slotIndex] == true
	-- Phase 32 : 필수 튜토리얼. 튜토리얼하는 사람의 칼은 항상 해적 자리에, AI 의 칼은 항상 안전한 자리에 꽂힌다.
	--   (어느 자리가 위험한지는 여전히 서버 안에만 있다. 마릿수는 그대로 둔다)
	if self:_tutorialActive() then
		if player == self.tutorial.player and not isDanger then
			for other in pairs(self.dangerSlots) do
				if not gameTable:IsSlotUsed(other) then
					self.dangerSlots[other] = nil
					break
				end
			end
			self.dangerSlots[slotIndex] = true
			isDanger = true
		elseif player ~= self.tutorial.player and isDanger then
			self.dangerSlots[slotIndex] = nil
			isDanger = false
			local pool = self:_hidableSlots()
			local here = table.find(pool, slotIndex)
			if here then
				table.remove(pool, here)
			end
			local moved = Utility.pickRandom(pool, self.random)
			if moved then
				self.dangerSlots[moved] = true
			end
		end
	end
	-- 봉인은 "봉인한 사람 다음 차례의 선택"까지 유지된다.
	-- 봉인한 사람이 자기 칼을 꽂는 것으로는 풀리지 않는다. (Phase 9 에서는 여기서 바로 풀려 쓸모가 없었다)
	if self.sealed and self.sealedBy ~= player then
		self:_clearSeal()
	end

	self.resolving = true
	self.picks = (self.picks or 0) + 1
	self.playerPicks = self.playerPicks or {}
	self.playerPicks[player] = (self.playerPicks[player] or 0) + 1
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
		catchable = self:_catchesLeft(player) > 0 or CATCH.AngryCatchable == true,
		angry = isDanger and self:_catchesLeft(player) <= 0 or nil, -- Phase 24.10 : 이번 해적은 분노한 해적 (먹물)
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
	self:_earn(player, ECONOMY.SurviveTurnReward * self:_cardValue("safe"), "safePicks", POT.PerPick) -- Phase 32 : "불꽃 칼날" 카드
	self:_rollSurge(player)
	self:_rollJackpot(player)

	-- 배짱으로 더 찌른 자리에서 살아남았다. 단계만큼 바로 보상한다.
	local level = self.braveLevel or 0
	if level > 0 then
		self:_earn(player, (BRAVE.Rewards[math.clamp(level, 1, #BRAVE.Rewards)] or 0) * self:_cardValue("brave"), "bravePicks", POT.PerBravePick)
	end

	self.phaseToken += 1
	local token = self.phaseToken

	-- ★ Phase 10 : "한 번 더" 제안. 결과를 보여주는 동안(ResultHold)만 누를 수 있다.
	--   누르면 AcceptBrave 가 phaseToken 을 올려 아래의 "다음 사람 차례" 예약을 무효로 만든다.
	if BRAVE.Enabled and level < BRAVE.MaxChain and self:_pickableCount() >= BRAVE.MinPickable and not self:_tutorialActive(player) then
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
	return math.floor(amount * self:_rewardScale() * self:_cardValue("brave"))
end

-- "한 번 더" 버튼에 적을 숫자. 최후의 1인 테이블은 현상금이 이만큼 커진다.
function Round:_braveOfferValue(level)
	if not self:_winnerTakesAll() then
		return self:_braveReward(level)
	end
	local list = BRAVE.Rewards
	local amount = (list[math.clamp(level, 1, #list)] or 0) * self:_cardValue("brave") + (tonumber(POT.PerBravePick) or 0) + (tonumber(POT.PerPick) or 0)
		+ (tonumber(ECONOMY.SurviveTurnReward) or 0) * self:_cardValue("safe")
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
	local add = math.floor((tonumber(amount) or 0) * self:_rewardScale() * (tonumber(GameConfig.worldMods().pot) or 1) * self:_cardValue("pot")) -- Phase 32 : 운명 카드
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
	local boost = (tonumber(GameConfig.worldMods().surge) or 1) * self:_cardValue("surge") -- Phase 32 : "행운의 통" 카드
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

-- Phase 21 : 잭팟 (GameConfig.Jackpot). 라운드가 바뀐 뒤 첫 안전한 자리에서 이번 라운드의 잭팟을 굴린다.
--   뽑혔으면 몇 번째 안전한 자리에서 터질지도 정해 두고, 그 자리에서 현상금에 한 번에 더한다.
function Round:_rollJackpot(player)
	local J = GameConfig.Jackpot
	if not (J and J.Enabled and POT.Enabled) then
		return nil
	end
	local model = self.gameTable.model
	local stage = math.max(1, tonumber(model and model:GetAttribute(TABLE_ATTR.Stage)) or 1)
	if self.jackpotStage ~= stage then
		self.jackpotStage = stage
		self.jackpot = nil
		local bigChance = math.min(J.Big.MaxChance, J.Big.Chance + J.Big.PerRound * (stage - 1))
		local tier = nil
		if self.random:NextNumber() < bigChance then
			tier = J.Big
		elseif self.random:NextNumber() < J.Small.Chance then
			tier = J.Small
		end
		if tier then
			self.jackpot = { tier = tier, left = self.random:NextInteger(1, math.max(1, J.TriggerWithin or 1)) }
		end
	end
	local armed = self.jackpot
	if not armed then
		return nil
	end
	armed.left -= 1
	if armed.left > 0 then
		return nil
	end
	self.jackpot = nil
	local scale = self.practice and (tonumber(GameConfig.Bots.RewardScale) or 1) or 1
	local before = self.pot or 0
	self.pot = math.clamp(before + math.floor(armed.tier.Amount * scale), 0, POT.Cap)
	self:_set(TABLE_ATTR.Pot, self.pot)
	presentation:FireAllClients("Jackpot", model, {
		tier = armed.tier.Id,
		name = armed.tier.Name,
		amount = self.pot - before,
		pot = self.pot,
		stage = stage,
		userId = player and player.UserId or 0,
		who = player and (player.DisplayName or player.Name) or "",
	})
	GameConfig.log(("%s %s · %d라운드 · 현상금 %d → %d"):format(self.gameTable.tableId, armed.tier.Name, stage, before, self.pot))
	return armed.tier
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

-- Phase 32 : 신입(판 수가 적은 사람)인가. 신입은 한 판에 한 번 놓쳐도 해적이 다시 나온다 (CATCH.RookieGames)
local function isRookie(player)
	if GameConfig.isBot(player) then
		return false
	end
	return (tonumber(player:GetAttribute(GameConfig.PlayerAttributes.Games)) or 0) < (tonumber(CATCH.RookieGames) or 0)
end

-- Phase 32 : 튜토리얼이 진행 중인가 (player 를 주면 그 사람이 튜토리얼 중인가)
function Round:_tutorialActive(player)
	local tutorial = self.tutorial
	if not tutorial or tutorial.finished then
		return false
	end
	return player == nil or tutorial.player == player
end

-- Phase 32 : 이번 해적의 종류 (튜토리얼은 정해진 순서 · 운명 카드가 종류를 정하거나 확률을 바꾼다)
function Round:_pickKind(player, stage)
	if self:_tutorialActive(player) then
		return (GameConfig.Tutorial.Kinds or {})[self.tutorial.step] or "normal"
	end
	local card = self.card
	if card and card.kind then
		return card.kind
	end
	return GameConfig.pickPirateKind(stage, card and card.kindBoost or nil, self.random)
end

-- Phase 32 : 잡기에서 놓쳤다. 살려 줄 수 있으면 그 까닭("tutorial" · "rookie"), 아니면 nil
function Round:_saveKind(player, reason)
	if GameConfig.isBot(player) or reason == "spent" then
		return nil
	end
	if self:_tutorialActive(player) then
		-- 아무것도 안 누르고 놓치기만 하면(자리 비움) 몇 번 뒤에는 끝낸다
		if reason == "timeout" or reason == "late" then
			self.tutorial.idle = (self.tutorial.idle or 0) + 1
			if self.tutorial.idle >= (tonumber(GameConfig.Tutorial.MaxIdleMisses) or 3) then
				return nil
			end
		else
			self.tutorial.idle = 0
		end
		return "tutorial"
	end
	if isRookie(player) and not self.rookieSaved[player] then
		self.rookieSaved[player] = true
		return "rookie"
	end
	return nil
end

-- Phase 32 : 잡기 실패를 분석 이벤트로 남긴다 (까닭 · 해적 종류 · 신입 여부). 첫 판에 왜 지는지 본다.
function Round:_logCatchFail(player, catch, reason, saved)
	if GameConfig.isBot(player) then
		return
	end
	local rookie = isRookie(player)
	task.spawn(function()
		local analytics = game:GetService("AnalyticsService")
		local K = Enum.AnalyticsCustomFieldKeys
		pcall(analytics.LogCustomEvent, analytics, player, saved and "CatchSaved" or "CatchFail", 1, {
			[K.CustomField01.Name] = tostring(reason),
			[K.CustomField02.Name] = tostring(catch.kind or "normal"),
			[K.CustomField03.Name] = rookie and "rookie" or "veteran",
		})
	end)
end

-- forcedKind : 살려 준 뒤 같은 종류로 다시 나올 때 · retry : 다시 나오는 해적인가
function Round:_beginCatch(player, slotIndex, forcedKind, retry)
	local gameTable = self.gameTable

	if not CATCH.Enabled then
		self:_eliminate(player)
		return
	end

	self.catchToken += 1
	local token = self.catchToken
	local personal = self.catchesUsed[player] or 0
	local stage = math.max(1, self.barrelCycle or 1)
	local tutorial = self:_tutorialActive(player)
	local kind = forcedKind or self:_pickKind(player, stage)

	-- ★ Phase 11 : 이미 MaxPerPlayer 번을 잡았다. 이번 해적은 "분노한 해적"이다.
	--   (Phase 32 : MaxPerPlayer 가 매우 커서 사실상 오지 않는다. 분노한 해적은 7라운드부터 가끔 섞여 나오는 종류다)
	if self:_catchesLeft(player) <= 0 then
		kind = "angry"
	end
	if kind == "angry" and CATCH.AngryCatchable ~= true then
		self.catch = {
			token = token,
			player = player,
			slot = slotIndex,
			kind = kind,
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

	local def = KINDS.List[kind] or KINDS.List.normal
	local angry = kind == "angry"
	-- 잡을 때마다(personal) 창이 좁아지고, 해적이 더 빨리 튀어나온다.
	-- Phase 21 : 어려운 경지(0.40초 아래)부터는 천천히 빨라진다 (Phase 32 : 바닥 0.30초)
	local window, hard = GameConfig.catchWindow(self.catchCount, #self.participants, self:_freeSlotCount(), personal, self.hardSteps[player])
	-- 창이 열리는 순간을 조금씩 흔든다. 클라이언트는 opensAt 에 맞춰 연출하므로 화면과 어긋나지 않는다.
	-- Phase 12 : 밤에는 해적이 더 빨리 나온다 (MinLead 아래로는 안 내려간다)
	local lead = GameConfig.catchLead(personal, GameConfig.worldMods().lead) + self.random:NextNumber() * (tonumber(CATCH.LeadJitter) or 0)
	-- Phase 24.10 : 분노한 해적 : 창이 더 좁고(잡을수록 더), 나오는 순간이 더 크게 흔들린다
	if angry then
		local angryCaught = self.angryCaught[player] or 0
		window = math.max(CATCH.AngryMinWindow or 0.26, math.min(window, CATCH.AngryWindow or 0.3) - (CATCH.AngryStep or 0.005) * angryCaught)
		hard = false -- 어려운 경지 단계는 더 올리지 않는다 (창은 위 값이 정한다)
		lead = GameConfig.catchLead(personal, GameConfig.worldMods().lead) + self.random:NextNumber() * (tonumber(CATCH.AngryLeadJitter) or 0.9)
			+ (tonumber(CATCH.AngryPreRise) or 0.9)
	end
	-- ★ Phase 38 : 빨라지는 것은 보통 해적뿐이다. 나머지 종류는 창 · 나오는 박자를 처음 그대로 두고,
	--   라운드가 오를수록 그 종류만의 능력이 세진다 (kindLevel = 라운드 - 그 종류가 풀린 라운드).
	--     쌍둥이 : 둘째가 나오는 간격이 들쭉날쭉해지고, 나중에는 셋(세쌍둥이)
	--     갈고리 : 반대쪽으로 먼저 고개를 내미는 속임수
	--     해골 유령 : 더 오래 떠 있고, 사라지는 척 깜빡인다
	--     욕심쟁이 : 눌러야 하는 횟수가 늘어난다 (시간은 줄지 않고 조금 늘어난다)
	local kindLevel = math.max(0, stage - (def.unlock or 1))
	if kind ~= "normal" and not angry then
		window = CATCH.BaseWindow or window
		hard = false
		lead = GameConfig.catchLead(0, GameConfig.worldMods().lead) + self.random:NextNumber() * (tonumber(CATCH.LeadJitter) or 0)
	end
	-- Phase 32 : 종류 · 운명 카드가 창을 넓히거나 좁힌다
	window *= tonumber(def.windowScale) or 1
	window *= self:_cardValue("window")
	local intro = false
	if tutorial then
		-- 튜토리얼 : 설명 카드를 보여 준 뒤에 넉넉한 창으로 나온다
		window *= tonumber(GameConfig.Tutorial.TutorialWindowScale) or 2
		lead = tonumber(GameConfig.Tutorial.IntroLead) or 3.4
		intro = true
	elseif self.tutorialPlayer == player and personal == 0 and GameConfig.Tutorial.Enabled then
		-- Phase 12 : 연습 판에서 처음 온 사람의 첫 해적은 넉넉하다
		window *= GameConfig.Tutorial.WindowScale
		lead = GameConfig.Tutorial.Lead
	end
	-- Phase 32 : 처음 만나는 종류는 설명 카드를 보여 줄 만큼 늦게 나온다 (사람만 · 튜토리얼 밖 · 한 번만)
	if not tutorial and not retry and not GameConfig.isBot(player) and ProfileService:SeeKind(player, kind) then
		intro = true
		lead = math.max(lead, tonumber(KINDS.FirstSightLead) or 2.0) -- Phase 34.1 : 더하지 않고 "최소"로 (카드 1.5초 뒤 바로 나온다)
	end
	-- 살려 준 뒤 다시 나오는 해적은 박자를 넉넉히 둔다 (배우는 중이다)
	if retry and not tutorial then
		lead = math.max(lead, 1.6)
	end

	local startedAt = GameConfig.now()
	local opensAt = startedAt + lead
	-- 잡는 순간들. 쌍둥이는 둘, 나머지는 하나.
	local steps = { { opensAt = opensAt, window = window } }
	local side, need, feint, flicker = nil, nil, nil, nil
	if kind == "twin" then
		-- Phase 38 : 간격이 라운드마다 들쭉날쭉해지고(0.45~0.85 → 0.25~1.6), tripleFrom 단계부터는 가끔 셋
		local low = math.max(0.25, (tonumber(def.gapMin) or 0.45) - 0.03 * kindLevel)
		local high = math.min(1.6, (tonumber(def.gapMax) or 0.85) + 0.08 * kindLevel)
		local count = 2
		local tripleFrom = tonumber(def.tripleFrom) or 4
		if not tutorial and kindLevel >= tripleFrom and self.random:NextNumber() < math.min(0.6, 0.35 + 0.05 * (kindLevel - tripleFrom)) then
			count = 3
		end
		local following = math.max(CATCH.MinWindow, window * (tonumber(def.secondScale) or 0.9))
		for _ = 2, count do
			local gap = low + self.random:NextNumber() * math.max(0, high - low)
			if tutorial then
				gap = math.max(gap, 1.0)
			end
			local prev = steps[#steps]
			table.insert(steps, { opensAt = prev.opensAt + prev.window + gap, window = following })
		end
	elseif kind == "side" then
		side = self.random:NextNumber() < 0.5 and "L" or "R"
		-- Phase 38 : 반대쪽으로 먼저 고개를 내미는 속임수 (feintFrom 단계부터 · 확률이 오른다)
		local feintFrom = tonumber(def.feintFrom) or 2
		if not tutorial and kindLevel >= feintFrom and self.random:NextNumber() < math.min(0.7, 0.3 + 0.07 * (kindLevel - feintFrom)) then
			feint = true
		end
	elseif kind == "skull" then
		-- 창 = 유령이 떠 있는 시간. 이 동안 누르면 탈락, 다 참으면 산다
		-- Phase 38 : 라운드마다 0.1초씩 더 오래 (최대 maxShow) · flickerFrom 단계부터 사라지는 척 깜빡인다
		local show = math.min(tonumber(def.maxShow) or 2.2, (tonumber(def.show) or 1.2) + 0.1 * kindLevel)
		steps[1].window = show * (tutorial and 1.3 or 1)
		if not tutorial and kindLevel >= (tonumber(def.flickerFrom) or 2) then
			flicker = true
		end
	elseif kind == "mash" then
		-- Phase 38 : 라운드가 오를수록 눌러야 하는 횟수만 는다. 시간은 줄지 않고 횟수에 맞춰 조금 는다
		--   (잡을수록 시간이 줄던 0.985^personal 은 뺐다)
		local baseTaps = tonumber(def.taps) or 5
		local extra = math.floor(kindLevel / math.max(1, tonumber(def.tapsEvery) or 2))
		need = math.min(tonumber(def.maxTaps) or 12, baseTaps + extra)
		local span = math.max(tonumber(def.minWindow) or 1.3, tonumber(def.window) or 1.8) * (need / baseTaps) ^ (tonumber(def.spanGrowth) or 0.7) * self:_cardValue("window")
		if tutorial then
			need = baseTaps
			span = math.max(tonumber(def.minWindow) or 1.3, tonumber(def.window) or 1.8) * 1.4
		end
		steps[1].window = span
	end
	local last = steps[#steps]

	self.catch = {
		token = token,
		player = player,
		slot = slotIndex,
		kind = kind,
		startedAt = startedAt,
		opensAt = opensAt,
		window = steps[1].window,
		steps = steps,
		step = 1,
		side = side,
		need = need,
		taps = 0,
		level = personal + 1,
		hard = hard,
		angry = angry or nil,
		resolved = false,
	}

	local stepTimes = {}
	for index, entry in ipairs(steps) do
		stepTimes[index] = { opensAt = entry.opensAt, window = entry.window }
	end
	local rookie = isRookie(player) and not self.rookieSaved[player]

	-- 잡아야 하는 사람에게만 창 길이를 보낸다.
	if not GameConfig.isBot(player) then
		catchPrompt:FireClient(player, gameTable.model, {
			mine = true,
			kind = kind,
			opensAt = opensAt,
			window = steps[1].window,
			steps = stepTimes,
			side = side,
			need = need,
			index = self.catchCount + 1,
			level = personal + 1,
			max = CATCH.MaxPerPlayer,
			slot = slotIndex,
			angry = angry or nil,
			ink = angry and (CATCH.AngryInk or 2.4) or nil,
			intro = intro or nil,
			tutorial = tutorial or nil,
			retry = retry or nil,
			kindLevel = kindLevel, -- Phase 38 : 이 종류가 몇 단계 세졌는가 (화면 안내)
			feint = feint, -- Phase 38 : 갈고리 해적 속임수
			flicker = flicker, -- Phase 38 : 해골 유령 깜빡임
			-- 신입 보호가 남아 있다 (화면에 구명환 표시) · 판 수 (신입에게는 가짜 손 속임수를 보여 주지 않는다)
			rookie = (rookie or tutorial) or nil,
			games = player:GetAttribute(GameConfig.PlayerAttributes.Games) or 0,
		})
		if tutorial and self.tutorial.step == 1 and not retry then
			ProfileService:Funnel(player, 3, "FirstPirate")
		end
	end

	-- 나머지(참가자 · 이 테이블을 관전하는 사람)는 "누가 잡으려 한다"만 안다. 창 길이는 알려주지 않는다.
	local told = {}
	local function tell(other)
		if other == player or told[other] or GameConfig.isBot(other) or other.Parent ~= Players then
			return
		end
		told[other] = true
		catchPrompt:FireClient(other, gameTable.model, {
			mine = false,
			kind = kind,
			opensAt = opensAt,
			steps = stepTimes,
			side = side,
			need = need,
			userId = player.UserId,
			name = player.DisplayName or player.Name,
			level = personal + 1,
			slot = slotIndex,
			angry = angry or nil,
			kindLevel = kindLevel,
			feint = feint,
			flicker = flicker,
		})
	end
	for _, other in ipairs(self.participants) do
		tell(other)
	end
	local tableId = gameTable.tableId
	for _, other in ipairs(Players:GetPlayers()) do
		local watching = other:GetAttribute("SpectateTableId")
		if watching ~= nil and (watching == tableId or watching == (gameTable.model and gameTable.model:GetAttribute(TABLE_ATTR.TableId))) then
			tell(other)
		end
	end

	GameConfig.log(("%s · %s 잡기 시작 (%d번째 · 이 사람 %d단계 · %s · 창 %.2f초)")
		:format(gameTable.tableId, player.Name, self.catchCount + 1, personal + 1, kind, steps[1].window))

	if GameConfig.isBot(player) then
		self:_botCatch(player, self.catch)
	end

	local finishAt = last.opensAt + last.window + CATCH.Grace
	if kind == "skull" then
		-- 참았다 : 유령이 사라질 때까지 누르지 않았으면 산다 (늦게 도착하는 입력을 기다려 지연 상한만큼 더 본다)
		task.delay(math.max(0, finishAt + CATCH.MaxLatency - GameConfig.now()), function()
			if self.destroyed or token ~= self.catchToken then
				return
			end
			local current = self.catch
			if current and not current.resolved then
				current.accuracy = 1
				self:_resolveCatch(true, "held")
			end
		end)
	elseif kind == "mash" then
		-- 연타 : 시간 안에 다 못 누르면 놓친 것이다
		task.delay(math.max(0, finishAt + CATCH.MaxLatency - GameConfig.now()), function()
			if self.destroyed or token ~= self.catchToken then
				return
			end
			self:_resolveCatch(false, "late")
		end)
	else
		-- 응답이 없어도 판이 멈추지 않도록 서버가 끝을 낸다.
		task.delay(math.max(0, finishAt - GameConfig.now()) + CATCH.Timeout, function()
			if self.destroyed or token ~= self.catchToken then
				return
			end
			self:_resolveCatch(false, "timeout")
		end)
	end
end

-- Phase 24 : 이 사람의 한쪽 방향 지연(초). 서버가 잰 왕복 지연(GetNetworkPing)의 절반, MaxLatency 이하.
local function oneWayLatency(player)
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and typeof(ping) == "number" and ping == ping and ping > 0 then
		return math.clamp(ping * 0.5, 0, CATCH.MaxLatency)
	end
	return 0
end

-- 클라이언트가 "지금 눌렀다"고 알려 왔을 때.
-- trusted : 서버가 만든 입력 (AI 선원). 사람의 입력은 항상 false.
-- side : Phase 32 갈고리 해적용 방향 ("L" · "R" · 없으면 nil)
function Round:HandleCatchInput(player, tappedAt, trusted, side)
	local catch = self.catch
	if not catch or catch.resolved or catch.player ~= player or catch.spent then
		return
	end

	local now = GameConfig.now()

	-- 보내온 시각을 그대로 믿지 않는다.
	--   · 미래의 시각은 인정하지 않는다 (now 가 상한)
	--   · Phase 24 : 과거로는 "서버가 잰 이 사람의 지연 + 약간의 여유" 만큼만 인정한다.
	local claimed = tonumber(tappedAt)
	if not claimed or claimed ~= claimed then
		claimed = now
	end
	if not trusted then
		local allowance = math.min(CATCH.MaxLatency, oneWayLatency(player) + (tonumber(CATCH.LatencySlack) or 0.08))
		claimed = math.clamp(claimed, now - allowance, now)
	end

	-- 칼을 고른 바로 그 손가락이 한 번 더 눌린 것은 버린다.
	if claimed < (catch.startedAt or 0) + (tonumber(CATCH.ArmDelay) or 0) then
		return
	end

	local kind = catch.kind or "normal"
	local steps = catch.steps or { { opensAt = catch.opensAt, window = catch.window } }
	local step = steps[catch.step or 1]

	if claimed < step.opensAt then
		-- 시계 오차만큼은 "딱 맞춰 누른 것"으로 친다.
		if claimed >= step.opensAt - (tonumber(CATCH.EarlyTolerance) or 0) then
			claimed = step.opensAt
		else
			-- ★ Phase 11 : 해적이 나오기 전에 눌렀다. 그 자리에서 실패다. (Phase 32 : 쌍둥이는 둘째가 나오기 전도)
			self:_resolveCatch(false, "early")
			return
		end
	end

	local limit = step.opensAt + step.window + CATCH.Grace
	if kind == "skull" then
		-- 해골 유령을 눌렀다 (참아야 했다)
		if claimed <= limit then
			self:_resolveCatch(false, "grabbed")
		end
		return
	end

	if claimed > limit then
		self:_resolveCatch(false, "late")
		return
	end

	if kind == "mash" then
		-- 연타 : 너무 촘촘한 입력(매크로 · 한 번 누름이 두 번 들어옴)은 한 번으로 친다
		if claimed - (catch.lastTapAt or -math.huge) < (tonumber((KINDS.List.mash or {}).minGap) or 0.045) then
			return
		end
		catch.lastTapAt = claimed
		catch.taps = (catch.taps or 0) + 1
		if catch.taps >= (catch.need or 5) then
			catch.reaction = claimed - step.opensAt
			catch.accuracy = math.clamp(1 - (claimed - step.opensAt) / math.max(step.window, 0.01), 0, 1)
			self:_resolveCatch(true, "caught")
		end
		return
	end

	if kind == "side" and side ~= catch.side then
		self:_resolveCatch(false, "wrong")
		return
	end

	-- Phase 24 : 정확도도 위에서 서버 지연 기준으로 잘라 낸 시각(claimed)으로 잰다.
	local accuracy = math.clamp(1 - (claimed - step.opensAt) / math.max(step.window, 0.01), 0, 1)
	catch.accuracy = math.min(catch.accuracy or 1, accuracy)
	-- Phase 32 : 몇 초 만에 잡았는가 (화면에 "0.42초 만에 잡았다!"). 쌍둥이는 더 늦었던 쪽
	catch.reaction = math.max(catch.reaction or 0, claimed - step.opensAt)
	if (catch.step or 1) < #steps then
		-- 쌍둥이 : 첫째를 잡았다. 둘째를 기다린다
		catch.step = (catch.step or 1) + 1
		return
	end
	self:_resolveCatch(true, "caught")
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

	-- ★ Phase 32 : 신입 보호 · 튜토리얼. 놓치거나 먼저 눌러도 탈락하지 않고 같은 해적이 한 번 더 나온다.
	if not success and self.isParticipant[player] and not gameTable.destroyed and gameTable.state == STATES.Playing then
		local save = self:_saveKind(player, reason)
		if save then
			catchResult:FireAllClients(gameTable.model, {
				userId = player.UserId,
				name = player.DisplayName or player.Name,
				success = false,
				saved = save,
				reason = reason,
				kind = catch.kind,
				index = self.catchCount + 1,
				pirates = self:_liveDangerCount(),
				catchesLeft = self:_catchesLeft(player),
				level = self.catchesUsed[player] or 0,
			})
			self:_logCatchFail(player, catch, reason, true)
			GameConfig.log(("%s · %s 잡기 실패 (%s) → %s 보호로 다시"):format(gameTable.tableId, player.Name, tostring(reason), save))
			self.phaseToken += 1
			local token = self.phaseToken
			task.delay(tonumber(CATCH.SaveDelay) or 1.7, function()
				if self.destroyed or token ~= self.phaseToken or gameTable.destroyed or gameTable.state ~= STATES.Playing then
					return
				end
				if not self.isParticipant[player] then
					-- 기다리는 동안 나갔다 : RemoveParticipant 가 차례 번호를 당겨 두었다
					self:_beginTurn(self.turnIndex + 1)
					return
				end
				self:_beginCatch(player, catch.slot, catch.kind, true)
			end)
			return
		end
	end

	-- ★ Phase 6 : 잡았으면 아직 아무도 꽂지 않은 자리에 해적을 새로 숨긴다.
	--   결과를 보내기 전에 숨기는 이유: 아래 payload 의 "남은 해적 수"가 맞아야 하기 때문이다.
	--   숨긴 자리 번호는 payload 에 넣지 않는다. 나가는 것은 마릿수까지다.
	local armed = 0
	if success and not gameTable.destroyed and gameTable.state == STATES.Playing and not self:_tutorialActive(player) then
		armed = self:_armDanger(CATCH.ArmOnCatch)
	end
	-- Phase 11 : 잡은 횟수는 성공했을 때만 오른다. 그만큼 이 사람의 다음 해적이 빨라진다.
	if success then
		self.catchesUsed[player] = (self.catchesUsed[player] or 0) + 1
		if catch.hard then
			self.hardSteps[player] = (self.hardSteps[player] or 0) + 1
		end
		if catch.kind == "angry" then
			self.angryCaught[player] = (self.angryCaught[player] or 0) + 1
		end
		self:_writeSeatOrder()
	end

	local perfect = success and reason ~= "held" and (catch.accuracy or 0) >= (CATCH.PerfectAccuracy or 1)

	-- Phase 32 : 튜토리얼 한 단계를 마쳤다
	local tutorialStep, tutorialDone = nil, false
	if success and self:_tutorialActive(player) then
		self.tutorial.step += 1
		self.tutorial.idle = 0
		tutorialStep = self.tutorial.step
		self:_set("TutorialStep", tutorialStep)
		if tutorialStep > #(GameConfig.Tutorial.Kinds or {}) then
			self.tutorial.finished = true
			tutorialDone = true
		end
	end

	catchResult:FireAllClients(gameTable.model, {
		userId = player.UserId,
		name = player.DisplayName or player.Name,
		success = success,
		reason = reason,
		kind = catch.kind,
		index = self.catchCount + 1,
		accuracy = catch.accuracy or 0,
		perfect = perfect,
		-- Phase 32 : 해적이 나온 뒤 몇 초 만에 잡았는가 (서버가 지연을 보정한 시각 기준)
		reaction = success and catch.reaction or nil,
		-- 통 안에 아직 몇 마리가 있는지까지만 알린다. 어느 자리인지는 보내지 않는다.
		pirates = self:_liveDangerCount(),
		rearmed = armed > 0,
		catchesLeft = self:_catchesLeft(player),
		level = self.catchesUsed[player] or 0,
		bot = GameConfig.isBot(player) or nil,
		tutorialStep = tutorialStep,
	})

	GameConfig.log(("%s · %s 잡기 %s (%s · %s) · 남은 해적 %d마리")
		:format(gameTable.tableId, player.Name, success and "성공" or "실패", tostring(reason), tostring(catch.kind), self:_liveDangerCount()))

	if not success then
		self:_logCatchFail(player, catch, reason, false)
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
	-- Phase 24.15 : 한 판에서 보상을 주는 잡기 수 상한 (자동 입력 · 끝없이 긴 판 방지)
	if (self.catchesUsed[player] or 0) <= (tonumber(CATCH.RewardedPerRound) or math.huge) then
		self:_earn(player, ECONOMY.CatchReward * self:_cardValue("catchCoins"), "catches", POT.PerCatch)
		if perfect then
			self:_earn(player, ECONOMY.PerfectCatchBonus, "perfectCatches", POT.PerPerfect)
		end
	end

	if tutorialDone then
		-- Phase 32 : 튜토리얼을 다 마쳤다. 보상을 주고, 잠시 뒤 AI 가 배에서 뛰어내린다 (승리)
		local reward = tonumber(GameConfig.Tutorial.Reward) or 0
		ProfileService:MarkTutorialDone(player)
		if reward > 0 then
			ProfileService:Award(player, reward)
		end
		ProfileService:Funnel(player, 4, "TutorialDone")
		presentation:FireAllClients("TutorialDone", gameTable.model, { userId = player.UserId, coins = reward })
	end

	-- 살아남았다. 통은 새로 채우지 않는다.
	-- 대신 방금 숨긴 해적이 통 안에 남아 있으므로 긴장이 이어진다.
	if gameTable.destroyed or gameTable.state ~= STATES.Playing then
		return
	end

	self.phaseToken += 1
	local token = self.phaseToken
	-- Phase 32.1 : 튜토리얼에서 한 종류를 잡을 때마다 잠깐 쉰다 (체크 목록이 넘어가는 것을 보게)
	local hold = CATCH.Hold
	if tutorialDone then
		hold += 1.2
	elseif tutorialStep then
		hold += tonumber(GameConfig.Tutorial.StepPause) or 0
	end
	task.delay(hold, function()
		if self.destroyed or token ~= self.phaseToken then
			return
		end
		if gameTable.destroyed or gameTable.state ~= STATES.Playing then
			return
		end

		-- Phase 32 : 튜토리얼이 끝났으면 판을 접는다 (튜토리얼한 사람의 승리)
		if self.tutorial and self.tutorial.finished and not self.tutorial.ended then
			self.tutorial.ended = true
			if self.isParticipant[self.tutorial.player] then
				self:_declareWinner(self.tutorial.player)
				return
			end
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

function Round:CanSabotage(actor, target, item)
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
	-- Phase 24 : 같은 상대에게 같은 방해가 이미 걸려(예약돼) 있으면 받지 않는다. (겹치면 효과 없이 사용권만 사라진다)
	if item then
		if item.turnCut and self.turnCut[target] then
			return false, "이미 재촉을 받은 상대입니다 / Already hurried"
		end
		for _, entry in ipairs(self.pendingSabotage[target] or {}) do
			if entry.item.id == item.id then
				return false, "이미 같은 방해가 예약돼 있어요 / Already queued"
			end
		end
	end
	return true, nil
end

-- 지금 target 이 칼을 고르는 중인가 (시간이 정해진 방해를 바로 걸어도 되는가)
function Round:_isPicking(target)
	return self.gameTable.state == STATES.Playing and not self.resolving and self.participants[self.turnIndex] == target
end

function Round:_fireSabotage(actor, target, item)
	-- 당한 사람에게는 효과를, 나머지에게는 "누가 누구에게 썼다"만 보낸다.
	if target.Parent == Players then
		sabotageCue:FireClient(target, self.gameTable.model, {
			id = item.id,
			mine = true,
			duration = item.duration,
			fromUserId = actor.UserId,
			fromName = actor.DisplayName or actor.Name,
		})
	end
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
end

function Round:_flushSabotage(target)
	local list = self.pendingSabotage[target]
	if not list then
		return
	end
	self.pendingSabotage[target] = nil
	for _, entry in ipairs(list) do
		self:_fireSabotage(entry.actor, target, entry.item)
		GameConfig.log(("%s · %s 차례에 예약된 방해(%s) 발동"):format(self.gameTable.tableId, target.Name, entry.item.id))
	end
end

-- 발동하지 못하고 사라지는 방해는 onVoid 로 알린다 (SabotageService 가 사용권을 돌려준다).
function Round:_voidSabotage(target)
	local list = self.pendingSabotage[target]
	self.pendingSabotage[target] = nil
	for _, entry in ipairs(list or {}) do
		if entry.onVoid then
			task.spawn(entry.onVoid, entry.item)
		end
	end
	local cutFrom = self.turnCutFrom[target]
	self.turnCutFrom[target] = nil
	self.turnCut[target] = nil
	if cutFrom and cutFrom.onVoid then
		task.spawn(cutFrom.onVoid, cutFrom.item)
	end
end

-- Phase 24.15 : 이 사람이 "건" 방해 중 아직 발동하지 않은 것을 거두고 사용권을 돌려준다.
--   (사용한 사람이 먼저 나가면 대상의 차례가 와도 돌려받을 길이 없었다) 나가는 순간 · 퇴장 저장 전에 부른다.
function Round:_voidSabotageBy(actor)
	for target, list in pairs(self.pendingSabotage) do
		local keep = {}
		for _, entry in ipairs(list) do
			if entry.actor == actor then
				if entry.onVoid then
					task.spawn(entry.onVoid, entry.item)
				end
			else
				table.insert(keep, entry)
			end
		end
		self.pendingSabotage[target] = #keep > 0 and keep or nil
	end
end

function Round:_voidAllSabotage()
	local targets = {}
	for target in pairs(self.pendingSabotage) do
		targets[target] = true
	end
	for target in pairs(self.turnCutFrom) do
		targets[target] = true
	end
	for target in pairs(targets) do
		self:_voidSabotage(target)
	end
end

-- Phase 24 : 세 번째 반환값 queued 가 참이면 "상대 차례가 오면 발동"으로 예약된 것이다.
--   시간이 정해진 방해(흔들기 · 뒤섞기 · 먹물 · 포효)는 상대가 칼을 고르는 동안에만 의미가 있다.
--   예전에는 바로 걸려서, 상대 차례가 오기 전에 끝나 버리면 사용권만 사라졌다.
--   onVoid(item) : 발동하기 전에 상대가 떨어지거나 판이 끝나면 불린다 (사용권 환불용)
function Round:ApplySabotage(actor, target, item, onVoid)
	local ok, reason = self:CanSabotage(actor, target, item)
	if not ok then
		return false, reason
	end

	self.sabotageUses[actor] = (self.sabotageUses[actor] or 0) + 1

	if item.turnCut then
		self.turnCut[target] = math.max(self.turnCut[target] or 0, item.turnCut)
		self.turnCutFrom[target] = { actor = actor, item = item, onVoid = onVoid }
		self:_fireSabotage(actor, target, item)
		GameConfig.log(("%s · %s → %s 방해(%s)"):format(self.gameTable.tableId, actor.Name, target.Name, item.id))
		return true, nil, false
	end

	if item.duration and not self:_isPicking(target) then
		self.pendingSabotage[target] = self.pendingSabotage[target] or {}
		table.insert(self.pendingSabotage[target], { item = item, actor = actor, onVoid = onVoid })
		GameConfig.log(("%s · %s → %s 방해(%s) 예약 (상대 차례에 발동)"):format(self.gameTable.tableId, actor.Name, target.Name, item.id))
		return true, nil, true
	end

	self:_fireSabotage(actor, target, item)
	GameConfig.log(("%s · %s → %s 방해(%s)")
		:format(self.gameTable.tableId, actor.Name, target.Name, item.id))
	return true, nil, false
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
	if not self.practice then -- Phase 24.15 : 연습 판 탈락은 연승을 끊지 않는다
		ProfileService:BreakStreak(player)
	end
	self:_voidSabotage(player)
	-- Phase 32 : 해적에게 탈락했어도 끝까지 한 판이다 (룰렛까지 몇 판 남았는지 바로 알린다)
	self:_countGame(player)

	-- place : 이번 판 순위 (4명 중 처음 떨어지면 4위)
	local defeatedRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	presentation:FireAllClients("Eliminate", gameTable.model, {
		userId = player.UserId,
		name = player.DisplayName or player.Name,
		skin = player:GetAttribute("EliminationSkin") or "classic",
		position = defeatedRoot and defeatedRoot.Position,
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

		-- 아직 둘 이상 남았다 → 통을 새로 채우고(해적도 새로 숨긴다) 다음 라운드로 올라간다. (알림은 _refillBarrel 이 한다)
		if gameTable.config.RefillOnElimination then
			self:_refillBarrel()
		end

		if gameTable.state ~= STATES.Playing then
			return
		end

		if not gameTable.config.RefillOnElimination then
			-- 통을 그대로 쓰는 테이블 : 라운드는 그대로, 결승이 되었을 때만 알린다
			local stage, final = self:_publishStage()
			if final then
				presentation:FireAllClients("Stage", gameTable.model, { stage = stage, final = true, alive = #self.participants })
			end
		end
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

-- Phase 24 : 기권승에 보상을 줄 만큼 판이 진행됐는가.
--   아무도(또는 이긴 사람이) 칼을 꽂지 않은 채 상대가 전부 나간 판은 "무효 판"이다.
--   여러 계정으로 앉았다 나가기를 반복해 보상 · 판수 · 퀘스트를 쌓는 것을 막는다.
function Round:_forfeitEarned(player)
	local rule = GameConfig.ForfeitWin
	local perPlayer = tonumber(rule.MinPicksForReward) or 1
	local own = tonumber(rule.MinOwnPicksForReward) or 1
	local need = math.max(1, self.startingCount or 1) * perPlayer
	return (self.picks or 0) >= need and ((self.playerPicks or {})[player] or 0) >= own
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
	-- Phase 24 : 진행이 거의 없던 기권승은 무효 판. 보상 · 판수 · 퀘스트 · 랭킹 · 토너먼트 · 예측 모두 없다. 현상금은 전부 이월.
	local noContest = halfWinner ~= nil and not self:_forfeitEarned(halfWinner)
	if noContest then
		halfWinner = nil
	end

	local potTotal = math.max(0, math.floor(self.pot or 0))
	local paid, carried = 0, 0
	if credited then
		paid = potTotal
	elseif noContest then
		carried = self:_carryOver(potTotal)
	elseif halfWinner then
		paid = math.floor(potTotal * share)
		carried = self:_carryOver(potTotal - paid)
	else
		carried = self:_carryOver(botWinner and math.floor(potTotal * 0.5) or potTotal)
	end

	self:_set(TABLE_ATTR.WinForfeit, halfWinner ~= nil or noContest)
	if player then
		self:_set(TABLE_ATTR.WinnerUserId, player.UserId)
		self:_set(TABLE_ATTR.WinnerName, player.DisplayName or player.Name)
		GameConfig.log(("%s 라운드 %d 승자: %s%s"):format(gameTable.tableId, self.roundId, player.Name,
			(botWinner and " (AI)") or (fullWin and "") or (noContest and " (무효 판 · 보상 없음)") or " (기권승)"))
	else
		self:_set(TABLE_ATTR.WinnerUserId, 0)
		self:_set(TABLE_ATTR.WinnerName, "")
		GameConfig.log(("%s 라운드 %d 종료 · 승자 없음"):format(gameTable.tableId, self.roundId))
	end

	-- 기록과 보상 (Phase 7 : 승자뿐 아니라 참가자 전원의 판수가 저장된다)
	-- Phase 24 : 무효 판은 기록하지 않는다.
	local recordOptions = {
		halfWinner = halfWinner,
		practice = self.practice == true,
		winnerTakesAll = self:_winnerTakesAll(),
	}
	if not noContest then
		ProfileService:RecordRound(gameTable, self.roundRoster or {}, credited, self.forfeited, self.bonuses, paid, recordOptions)
		-- Phase 32 : 끝까지 남은 사람도 오늘 판 수에 센다 (스스로 나간 사람은 빼고)
		for _, member in ipairs(self.roundRoster or {}) do
			if not (self.forfeited or {})[member] then
				self:_countGame(member)
			end
		end
		-- 연습 판(AI 동석)의 승리는 랭킹에 넣지 않는다.
		RankingService:RecordRound(gameTable, self.roundRoster or {}, (not self.practice) and credited or nil)
	end
	if player and not botWinner then
		task.spawn(function()
			local analytics = game:GetService("AnalyticsService")
			pcall(analytics.LogCustomEvent, analytics, player, "RoundDuration", os.clock() - (self.roundStartedAt or os.clock()), GameConfig.analyticsFields(gameTable.typeName))
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
		forfeit = halfWinner ~= nil or noContest,
		noContest = noContest or nil,
		pot = paid,
		carry = carried,
		bot = botWinner or nil,
		practice = self.practice or nil,
		-- Phase 32 : 바로 전에 연승이 오른 판과 같은 상대에게 이겨서 연승이 그대로다
		sameFoes = recordOptions.sameFoes or nil,
		tutorial = (self.tutorial and self.tutorial.finished) or nil,
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
		noContest = noContest,
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
	self:_voidAllSabotage()
	table.clear(self.turnCut)
	table.clear(self.sabotageUses)
	table.clear(self.catchesUsed)
	table.clear(self.hardSteps)
	self.pot = 0
	self.picks = 0
	self.playerPicks = {}
	self.pirateOuts = 0
	self.outOrder = {}
	self.turnIndex = 0
	self.startingCount = 0
	-- Phase 12 : 연습 판은 한 판으로 끝난다
	if self.tutorialPlayer then
		self:_set(TABLE_ATTR.Tutorial, 0)
		self.tutorialPlayer = nil
	end
	-- Phase 32
	self.tutorial = nil
	self:_set("TutorialStep", 0)
	self:_set("TutorialReplay", false)
	self.card = nil
	self.holdTurnsUntil = 0
	self:_set("FateCard", "")
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
	self:_voidSabotage(player)

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
		pcall(analytics.LogCustomEvent, analytics, player, "RoundForfeit", 1, GameConfig.analyticsFields(self.gameTable.typeName))
	end)
	-- 게임 중에 스스로 나간 사람은 연승이 끊긴다. (나가서 연승을 지키는 짓 방지)
	-- Phase 24.15 : 연습 판(AI)은 승리도 연승에 들어가지 않으므로, 지거나 나가도 진짜 연승을 끊지 않는다
	if not self.practice then
		ProfileService:BreakStreak(player)
	end

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
	-- Phase 24 : 앉은 순서 (방장)
	if joined then
		self.seatSerial = (self.seatSerial or 0) + 1
		self.seatedAt[player] = self.seatSerial
	else
		self.seatedAt[player] = nil
	end
	self:_publishHost()

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
	self._cleaner:add(catchInput.OnServerEvent:Connect(function(player, tableModel, tappedAt, side)
		local ok, err = pcall(function()
			if typeof(tableModel) ~= "Instance" or not tableModel:IsA("Model") then
				return
			end
			local gameTable = TableService:GetTableFromModel(tableModel)
			if not gameTable or TableService:GetTableOfPlayer(player) ~= gameTable then
				return
			end
			-- Phase 32 : 갈고리 해적의 방향은 "L" · "R" 둘 중 하나만 받는다
			if side ~= "L" and side ~= "R" then
				side = nil
			end
			local round = self._rounds[gameTable]
			if round then
				round:HandleCatchInput(player, tappedAt, false, side)
			end
		end)
		if not ok then
			warn("[CursedBarrel] 잡기 입력 처리 중 오류: " .. tostring(err))
		end
	end))

	-- Phase 24 : 방장의 「▶ 시작」
	local startLimiter = Utility.RateLimiter.new(0.5)
	self._cleaner:add(startRemote.OnServerEvent:Connect(function(player)
		local ok, err = pcall(function()
			if not startLimiter:check(player.UserId) then
				return
			end
			local gameTable = TableService:GetTableOfPlayer(player)
			local round = gameTable and self._rounds[gameTable]
			if round then
				round:HostStart(player)
			end
		end)
		if not ok then
			warn("[CursedBarrel] 시작 요청 처리 중 오류: " .. tostring(err))
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
			-- Phase 24.15 : 나가는 사람이 걸어 둔 미발동 방해는 퇴장 저장 전에 환불
			round:_voidSabotageBy(player)
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
