--[[
	RoundService
	Phase 2 의 핵심.

	테이블 하나마다 "라운드 진행 담당자(Round)"를 붙여서 아래를 처리한다.
	  1. 최소 인원이 앉으면 카운트다운 시작
	  2. 인원이 최소 인원 밑으로 떨어지면 카운트다운 즉시 취소
	  3. 남은 시간은 테이블 Attribute(CountdownEndsAt)로 알려준다 → 현황판이 읽어 그린다
	  4. 카운트다운이 끝나면 참가자를 확정하고 상태를 Playing 으로 바꾼다
	  5. 턴 순서는 서버가 무작위로 섞어서 정한다
	  6. 현재 차례인 사람을 테이블 Attribute 로 알린다
	  7. Playing 이 되는 순간부터 새 참가자는 앉을 수 없다 (GameTable:IsJoinable)
	  8. 참가자가 나가거나 캐릭터가 리셋돼도 명단과 턴 순서를 조용히 정리한다

	판정과 상태 변경은 전부 서버(이 파일)에서만 일어난다.
	클라이언트는 Attribute 를 읽어 보여주기만 하므로 조작할 수 있는 통로가 없다.

	테이블마다 Round 객체가 따로 있으므로, 테이블을 복제해도 서로 간섭하지 않는다.

	Phase 3 예고
	  - 칼 슬롯 선택 / 위험 판정 / 탈락 / 승리는 아직 없다.
	  - 준비된 연결 고리: Round:AdvanceTurn(), Round:RemoveParticipant(player)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TableService = require(script.Parent.TableService)

local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes
local STATES = GameConfig.States

--------------------------------------------------
-- Round : 테이블 하나의 라운드 상태
--------------------------------------------------
local Round = {}
Round.__index = Round

function Round.new(gameTable)
	local self = setmetatable({}, Round)

	self.gameTable = gameTable
	self.cleaner = Utility.Cleaner.new()
	self.random = Random.new() -- 턴 순서를 섞을 때 쓰는 서버 전용 난수

	self.participants = {} -- 턴 순서대로 정렬된 참가자 배열
	self.isParticipant = {} -- [Player] = true (빠른 조회용)
	self.turnIndex = 0
	self.roundId = 0
	self.destroyed = false

	-- 예약한 작업을 취소하는 대신 토큰을 하나 올린다.
	-- 늦게 도착한 task.delay 콜백은 토큰이 다르면 스스로 물러난다.
	-- (타이머를 직접 취소할 수 없는 Roblox 에서 가장 오류가 적은 방식)
	self.countdownToken = 0
	self.turnToken = 0

	self.cleaner:add(gameTable.RosterChanged:Connect(function(_, player, joined)
		self:_onRosterChanged(player, joined)
	end))

	self:_resetRoundAttributes()
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

	self.cleaner:clean()
	table.clear(self.participants)
	table.clear(self.isParticipant)
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
	-- Playing 중의 인원 변화는 _removeParticipant 가 따로 처리한다.
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
-- 라운드 시작
--------------------------------------------------

function Round:_beginRound()
	-- 1) 이 순간 앉아 있는 사람들을 참가자로 확정한다.
	local participants = self.gameTable:GetPlayers()

	-- 2) 턴 순서는 서버에서 무작위로 섞는다. (좌석 순서를 알아도 예측할 수 없다)
	Utility.shuffle(participants, self.random)

	self.participants = participants
	table.clear(self.isParticipant)
	for _, player in ipairs(participants) do
		self.isParticipant[player] = true
	end

	self.roundId += 1
	self.turnIndex = 0

	self:_set(TABLE_ATTR.CountdownEndsAt, 0)
	self:_set(TABLE_ATTR.RoundId, self.roundId)
	self:_set(TABLE_ATTR.ParticipantCount, #participants)
	self:_set(TABLE_ATTR.TurnCount, #participants)
	self:_writeSeatOrder()

	-- 3) 상태를 Playing 으로. 이 순간부터 빈 의자에도 앉을 수 없다.
	self.gameTable:SetState(STATES.Playing)

	local names = {}
	for _, player in ipairs(participants) do
		table.insert(names, player.Name)
	end
	GameConfig.log(("%s 라운드 %d 시작 · 턴 순서: %s")
		:format(self.gameTable.tableId, self.roundId, table.concat(names, " → ")))

	-- 4) 첫 번째 차례
	self:_beginTurn(1)
end

-- Phase 2 에는 승리 판정이 없다. 여기서는 "테이블을 다시 쓸 수 있게 정리"만 한다.
-- Phase 3 에서 이 자리가 승자 발표 / RoundEnding 연출로 바뀐다.
function Round:_finishRound(reason)
	self.countdownToken += 1
	self.turnToken += 1

	table.clear(self.participants)
	table.clear(self.isParticipant)
	self.turnIndex = 0

	self:_resetRoundAttributes()

	if not self.gameTable.destroyed then
		self.gameTable:SetState(STATES.Waiting)
	end

	GameConfig.log(("%s 라운드 정리 (%s)"):format(self.gameTable.tableId, tostring(reason)))

	-- 아직 앉아 있는 사람이 있으면 곧바로 새 카운트다운이 시작된다.
	self:_evaluate()
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
			-- Phase 3 에서는 "제한 시간 안에 칼을 고르지 못함" 처리가 여기에 들어간다.
			self:AdvanceTurn()
		end)
	else
		self:_set(TABLE_ATTR.TurnEndsAt, 0)
	end

	GameConfig.log(("%s 턴 %d/%d · %s"):format(self.gameTable.tableId, index, count, player.Name))
end

-- 다음 사람에게 차례를 넘긴다. (Phase 3 에서 칼을 뽑은 뒤 호출하게 된다)
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
-- 참가자 이탈 (퇴장 / 캐릭터 리셋 / 강제 일어나기)
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
	self:_set(TABLE_ATTR.ParticipantCount, count)
	self:_set(TABLE_ATTR.TurnCount, count)
	self:_writeSeatOrder()

	GameConfig.log(("%s 참가자 이탈: %s · 남은 인원 %d명")
		:format(self.gameTable.tableId, player.Name, count))

	if self.gameTable.state ~= STATES.Playing then
		return true
	end

	if count < self:_minPlayers() then
		-- 남은 인원으로는 게임을 이어갈 수 없다.
		-- Phase 2 에는 승리 판정이 없으므로 테이블이 잠기지 않도록 정리만 한다.
		self:_finishRound("남은 인원이 최소 인원보다 적음")
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

function RoundService:Start()
	if self._started then
		return
	end
	self._started = true

	self._cleaner:add(TableService.TableAdded:Connect(function(gameTable)
		self:_attach(gameTable)
	end))

	self._cleaner:add(TableService.TableRemoved:Connect(function(gameTable)
		self:_detach(gameTable)
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
