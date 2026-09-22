--[[
	RoundService
	Phase 2 · 3 의 핵심. 테이블 하나마다 "라운드 진행 담당자(Round)"를 붙인다.

	Phase 2 에서 하던 일
	  1. 최소 인원이 앉으면 카운트다운 시작
	  2. 인원이 최소 인원 밑으로 떨어지면 카운트다운 즉시 취소
	  3. 남은 시간은 테이블 Attribute(CountdownEndsAt)로 알려준다 → 현황판이 읽어 그린다
	  4. 카운트다운이 끝나면 참가자를 확정하고 턴 순서를 무작위로 섞는다
	  5. 현재 차례인 사람을 테이블 Attribute 로 알린다
	  6. 참가자가 나가거나 캐릭터가 리셋돼도 명단과 턴 순서를 조용히 정리한다

	Phase 3 에서 더해진 일
	  7. 라운드를 시작할 때 통에 칼을 채우고, "위험한 자리"를 서버가 무작위로 뽑는다
	     → 위험한 자리 번호는 서버 메모리에만 있다. Attribute 로도, RemoteEvent 로도 나가지 않는다.
	  8. 슬롯 선택 요청(프롬프트 · 화면 버튼)을 한 곳에서 검사한다
	     - 지금 이 테이블이 게임 중인가
	     - 요청한 사람이 이 테이블의 참가자인가  ← 다른 테이블을 누른 요청은 여기서 거절된다
	     - 지금이 그 사람의 차례인가
	     - 그 번호의 자리가 실제로 있는가 / 이미 누가 꽂지 않았는가
	  9. 안전하면 다음 사람에게 차례를 넘기고, 위험하면 그 사람을 탈락시킨다
	 10. 탈락자가 나오면 통을 새로 채우고(위험 자리도 새로 뽑는다) 남은 사람끼리 계속한다
	 11. 마지막 한 명이 남으면 승리 → 5초 뒤 테이블이 초기화된다

	판정과 상태 변경은 전부 서버(이 파일)에서만 일어난다.
	클라이언트는 Attribute 를 읽어 보여주고, 버튼을 눌러 "요청"만 보낼 수 있다.

	테이블마다 Round 객체가 따로 있으므로, 테이블을 복제해도 서로 간섭하지 않는다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TableConfig = require(Shared:WaitForChild("TableConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TableService = require(script.Parent.TableService)
local RankingService = require(script.Parent.RankingService)

local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes
local STATES = GameConfig.States
local TIMING = GameConfig.Timing
local REJECT = GameConfig.RejectMessages

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
	self.startingCount = 0 -- 이번 라운드를 시작한 인원
	self.turnIndex = 0
	self.roundId = 0
	self.destroyed = false

	-- Phase 3
	self.dangerSlots = {} -- [슬롯번호] = true  ★ 서버 안에서만 존재한다
	self.barrelCycle = 0 -- 이번 라운드에서 통을 몇 번째로 채웠는지
	self.resolving = false -- 결과 연출 중에는 다음 요청을 받지 않는다

	-- 예약한 작업을 취소하는 대신 토큰을 하나 올린다.
	-- 늦게 도착한 task.delay 콜백은 토큰이 다르면 스스로 물러난다.
	-- (타이머를 직접 취소할 수 없는 Roblox 에서 가장 오류가 적은 방식)
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

	self.cleaner:clean()
	table.clear(self.participants)
	table.clear(self.roundRoster)
	table.clear(self.isParticipant)
	table.clear(self.dangerSlots)
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
	end
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
	self:_writeSeatOrder()
end

--------------------------------------------------
-- 상태 판단
--------------------------------------------------

-- 인원이 바뀔 때마다 "지금 뭘 해야 하는지"를 한 곳에서 결정한다.
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
		-- 그 사이 취소됐거나(토큰 변경), 테이블이 사라졌거나, 상태가 바뀌었으면 아무것도 하지 않는다.
		if self.destroyed or token ~= self.countdownToken then
			return
		end
		if self.gameTable.destroyed or self.gameTable.state ~= STATES.Countdown then
			return
		end

		-- 마지막으로 한 번 더 인원을 확인한다. (같은 프레임에 빠져나간 경우 대비)
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
-- 통 채우기 / 위험 자리 뽑기  (Phase 3)
--------------------------------------------------

-- 통을 새 칼로 채우고 위험한 자리를 다시 뽑는다.
-- 이 함수가 뽑은 번호는 서버 메모리(self.dangerSlots)에만 들어간다.
function Round:_refillBarrel()
	local gameTable = self.gameTable
	gameTable:ResetSlots()
	gameTable:ResetBarrelLook()

	local slotCount = gameTable:GetSlotCount()
	local dangerCount = math.min(TableConfig.getDangerCount(gameTable.typeName), math.max(1, slotCount - 1))

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

	-- 로그에도 위험 자리 번호는 남기지 않는다. (서버 로그를 보여주는 방송/영상 대비)
	GameConfig.log(("%s 통 %d번째 채움 · 칼 %d자루 · 위험 %d자리")
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
	self.roundRoster = table.clone(participants) -- 랭킹 기록용. 탈락해도 줄지 않는다.
	table.clear(self.isParticipant)
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
	self:_set(TABLE_ATTR.ResetEndsAt, 0)
	self:_set(TABLE_ATTR.LastPickSlot, 0)
	self:_set(TABLE_ATTR.LastPickUserId, 0)
	self:_set(TABLE_ATTR.LastPickName, "")
	self:_set(TABLE_ATTR.LastPickSafe, true)
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
function Round:_finishRound(reason)
	GameConfig.log(("%s 라운드 정리 (%s)"):format(self.gameTable.tableId, tostring(reason)))
	self:_resetTable()
end

--------------------------------------------------
-- 턴
--------------------------------------------------

function Round:_beginTurn(index)
	if self.destroyed or self.gameTable.destroyed then
		return
	end

	local count = #self.participants
	if count == 0 then
		self:_finishRound("참가자가 모두 자리를 떠남")
		return
	end

	-- 목록 끝을 넘어가면 처음으로 돌아온다.
	index = ((index - 1) % count) + 1
	self.turnIndex = index
	self.resolving = false

	local player = self.participants[index]

	self.turnToken += 1
	local token = self.turnToken

	self:_set(TABLE_ATTR.TurnIndex, index)
	self:_set(TABLE_ATTR.TurnCount, count)
	self:_set(TABLE_ATTR.CurrentTurnUserId, player.UserId)
	self:_set(TABLE_ATTR.CurrentTurnName, player.DisplayName or player.Name)

	local duration = tonumber(self.gameTable.config.TurnDuration) or 0
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
end

-- 제한 시간 안에 고르지 못했다.
-- 기본 설정은 "서버가 남은 자리 중 하나를 대신 고른다" 이다. (턴을 그냥 넘기면 버티는 게 이득이 된다)
function Round:_onTurnTimeout(player)
	if self.resolving then
		return
	end

	-- 같은 프레임에 자리에서 일어났을 수도 있다. 여전히 이 사람 차례인지 확인한다.
	if self.participants[self.turnIndex] ~= player then
		return
	end

	if self.gameTable.config.AutoPickOnTimeout then
		local free = self.gameTable:GetFreeSlotIndices()
		local slotIndex = Utility.pickRandom(free, self.random)
		-- 사람이 눌렀을 때와 똑같은 검사를 통과해야 한다.
		if slotIndex and self:ValidatePick(player, slotIndex) == nil then
			GameConfig.log(("%s 시간 초과 · 서버가 대신 %d번 자리를 고릅니다"):format(player.Name, slotIndex))
			self:_resolvePick(player, slotIndex, "timeout")
			return
		end
	end

	self:AdvanceTurn()
end

-- 다음 사람에게 차례를 넘긴다.
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
--
-- 프롬프트(E/탭)로 들어오든, 화면 버튼(RemoteEvent)으로 들어오든
-- 반드시 이 함수를 거친다. 검사 순서를 한 곳에 모아 두면 빠뜨릴 일이 없다.
--------------------------------------------------

-- 통과하면 nil, 막히면 거절 사유 문자열을 돌려준다.
function Round:ValidatePick(player, slotIndex)
	if self.destroyed or self.gameTable.destroyed then
		return REJECT.NotPlaying
	end

	if self.gameTable.state ~= STATES.Playing then
		return REJECT.NotPlaying
	end

	-- 이 테이블의 참가자인가 (다른 테이블 사람이 눌렀다면 여기서 걸린다)
	if not self.isParticipant[player] then
		return REJECT.NotParticipant
	end

	-- 아직 앉아 있는가 (탈락했거나 일어났으면 참가자가 아니다)
	if not self.gameTable:HasPlayer(player) then
		return REJECT.Eliminated
	end

	-- 지금이 이 사람 차례인가
	if self.participants[self.turnIndex] ~= player then
		return REJECT.NotYourTurn
	end

	-- 결과 연출 중에는 다음 요청을 받지 않는다 (연타로 두 자리를 고르는 것 방지)
	if self.resolving then
		return REJECT.TooFast
	end

	if typeof(slotIndex) ~= "number" or slotIndex ~= slotIndex then
		return REJECT.BadSlot
	end

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

-- 검사 → 통과하면 실제 처리. 거절 사유 문자열 또는 nil 을 돌려준다.
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

	self:_resolvePick(player, math.floor(slotIndex), source)
	return nil
end

--------------------------------------------------
-- 선택 처리
--------------------------------------------------

function Round:_resolvePick(player, slotIndex, source)
	local gameTable = self.gameTable
	local isDanger = self.dangerSlots[slotIndex] == true

	self.resolving = true
	self.turnToken += 1 -- 이번 턴의 제한 시간 타이머를 무효로 만든다

	gameTable:MarkSlotUsed(slotIndex, player, isDanger)
	self:_set(TABLE_ATTR.SlotsRemaining, self:_freeSlotCount())
	self:_set(TABLE_ATTR.LastPickSlot, slotIndex)
	self:_set(TABLE_ATTR.LastPickUserId, player.UserId)
	self:_set(TABLE_ATTR.LastPickName, player.DisplayName or player.Name)
	self:_set(TABLE_ATTR.LastPickSafe, not isDanger)
	self:_set(TABLE_ATTR.TurnEndsAt, 0)

	GameConfig.log(("%s · %s 가 %d번 자리 선택 (%s, %s)")
		:format(gameTable.tableId, player.Name, slotIndex, isDanger and "위험" or "안전", tostring(source)))

	if isDanger then
		gameTable:PlayDangerEffect()
		self:_eliminate(player)
		return
	end

	-- 안전. 잠깐 결과를 보여준 뒤 다음 사람 차례로 넘어간다.
	self.phaseToken += 1
	local token = self.phaseToken
	task.delay(TIMING.ResultHold, function()
		if self.destroyed or token ~= self.phaseToken then
			return
		end
		if gameTable.destroyed or gameTable.state ~= STATES.Playing then
			return
		end

		-- 아주 드문 경우: 위험 자리를 아무도 밟지 않았는데 통이 비었다. 새로 채운다.
		if self:_freeSlotCount() == 0 then
			self:_refillBarrel()
		end

		self:_beginTurn(self.turnIndex + 1)
	end)
end

--------------------------------------------------
-- 탈락 / 승리
--------------------------------------------------

function Round:_eliminate(player)
	local gameTable = self.gameTable

	local index = table.find(self.participants, player)
	if index then
		table.remove(self.participants, index)
	else
		index = self.turnIndex
	end
	self.isParticipant[player] = nil

	local remaining = #self.participants
	self:_set(TABLE_ATTR.TurnCount, remaining)

	gameTable:SetSeatAlive(player, false)

	-- 탈락자는 자리에서 일어난다. (일어나는 동작은 RosterChanged 로 돌아오지만
	--  isParticipant 에서 이미 지웠기 때문에 "라운드 도중 이탈"로 처리되지 않는다)
	gameTable:RemovePlayer(player)
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

		-- 아직 둘 이상 남았다 → 통을 새로 채우고(위험 자리도 새로 뽑는다) 계속한다.
		if gameTable.config.RefillOnElimination then
			self:_refillBarrel()
		end

		if gameTable.state ~= STATES.Playing then
			return
		end

		-- 탈락한 사람이 있던 자리로 다음 사람이 당겨졌다. 그 사람부터 이어서 진행한다.
		self:_beginTurn(index)
	end)
end

function Round:_declareWinner(player)
	local gameTable = self.gameTable

	if player then
		self:_set(TABLE_ATTR.WinnerUserId, player.UserId)
		self:_set(TABLE_ATTR.WinnerName, player.DisplayName or player.Name)
		GameConfig.log(("%s 라운드 %d 승자: %s"):format(gameTable.tableId, self.roundId, player.Name))
	else
		self:_set(TABLE_ATTR.WinnerUserId, 0)
		self:_set(TABLE_ATTR.WinnerName, "")
		GameConfig.log(("%s 라운드 %d 종료 · 승자 없음"):format(gameTable.tableId, self.roundId))
	end

	-- 랭킹 기록 (승자가 없으면 참가 기록만 남는다)
	RankingService:RecordRound(gameTable, self.roundRoster or {}, player)

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
	local gameTable = self.gameTable

	self.countdownToken += 1
	self.turnToken += 1
	self.phaseToken += 1
	local token = self.phaseToken

	table.clear(self.participants)
	table.clear(self.isParticipant)
	table.clear(self.dangerSlots)
	self.turnIndex = 0
	self.startingCount = 0
	self.barrelCycle = 0
	self.resolving = false

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

		-- 아직 앉아 있는 사람이 있으면 곧바로 새 카운트다운이 시작된다.
		self:_evaluate()
	end)
end

--------------------------------------------------
-- 참가자 이탈 (퇴장 / 캐릭터 리셋 / 스스로 일어나기)
--------------------------------------------------

function Round:RemoveParticipant(player)
	local index = table.find(self.participants, player)
	self.isParticipant[player] = nil

	if not index then
		self:_writeSeatOrder()
		return false
	end

	table.remove(self.participants, index)

	local count = #self.participants
	self:_set(TABLE_ATTR.TurnCount, count)
	self:_writeSeatOrder()

	GameConfig.log(("%s 참가자 이탈: %s · 남은 인원 %d명")
		:format(self.gameTable.tableId, player.Name, count))

	local state = self.gameTable.state
	if state ~= STATES.Playing and state ~= STATES.Starting then
		return true
	end

	if count == 1 then
		-- 혼자 남았다 → 그 사람이 승자다.
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
		-- 내 앞 순서가 빠졌으니 현재 차례의 번호가 하나 당겨진다.
		self.turnIndex -= 1
		self:_set(TABLE_ATTR.TurnIndex, self.turnIndex)
	elseif index == self.turnIndex then
		-- 차례이던 사람이 나갔다 → 그 자리로 밀려온 다음 사람부터 이어서 진행
		self:_beginTurn(index)
	end

	return true
end

function Round:_onRosterChanged(player, joined)
	if self.destroyed or self.gameTable.destroyed then
		return
	end

	if joined then
		-- 게임 중의 착석은 GameTable 이 이미 막는다.
		-- 여기서는 대기/카운트다운 상태만 다시 판단하면 된다.
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
--   - 타입이 맞는가
--   - 그 모델이 정말 등록된 테이블인가
--   - 요청한 사람이 지금 "그 테이블"에 앉아 있는가  ← 다른 테이블 요청 거부
-- 여기를 통과해도 Round:ValidatePick 이 차례/슬롯을 한 번 더 검사한다.
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

	if typeof(slotIndex) ~= "number" or slotIndex ~= slotIndex then
		return reject(REJECT.BadSlot)
	end

	local gameTable = TableService:GetTableFromModel(tableModel)
	if not gameTable then
		return reject(REJECT.OtherTable)
	end

	-- ★ 다른 테이블을 누른 요청은 여기서 끝난다.
	--    "내가 앉아 있는 테이블"과 요청한 테이블이 같아야 한다.
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
		for _, round in pairs(self._rounds) do
			round.pickLimiter:forget(player.UserId)
		end
	end))

	-- TableService 가 먼저 시작됐더라도 빠뜨리지 않도록 이미 등록된 테이블을 훑는다.
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
