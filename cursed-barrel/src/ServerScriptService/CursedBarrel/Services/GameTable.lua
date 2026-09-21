--[[
	GameTable
	게임 테이블 하나를 담당하는 서버 측 객체.

	Phase 1 담당 범위
	  - 모델 안의 Seat 을 찾아 좌석 목록을 만든다
	  - 좌석마다 "앉기" ProximityPrompt 를 붙인다
	  - 누가 앉고 일어나는지 서버가 직접 감시해 참가자 명단을 관리한다
	  - 현재 인원을 테이블 Attribute 로 기록한다 (클라이언트 UI 가 이걸 읽는다)

	테이블마다 독립된 객체이므로 한 테이블의 일이 다른 테이블에 영향을 주지 않는다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local TableConfig = require(Shared.TableConfig)
local Utility = require(Shared.Utility)

local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes

local GameTable = {}
GameTable.__index = GameTable

-- TableId Attribute 가 없는 모델에 붙여줄 자동 번호
local autoIdCounter = 0

--------------------------------------------------
-- 생성 / 파괴
--------------------------------------------------

-- 구조가 잘못된 모델이면 경고만 남기고 nil 을 돌려준다. (게임 전체가 멈추지 않게)
function GameTable.new(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn("[CursedBarrel] 테이블 태그는 Model 에만 붙일 수 있습니다: " .. tostring(model))
		return nil
	end

	-- 런타임에 복제된 테이블은 자식이 아직 도착하지 않았을 수 있다.
	local seatsFolder = model:FindFirstChild("Seats") or model:WaitForChild("Seats", 5)
	if not seatsFolder then
		warn(("[CursedBarrel] '%s' 안에 Seats 폴더가 없어 등록하지 못했습니다."):format(model:GetFullName()))
		return nil
	end

	autoIdCounter += 1

	local self = setmetatable({}, GameTable)

	self.model = model
	self.tableId = model:GetAttribute(TABLE_ATTR.TableId) or ("Table_%02d"):format(autoIdCounter)
	self.typeName = model:GetAttribute(TABLE_ATTR.TableType) or TableConfig.DefaultType
	self.config = TableConfig.get(self.typeName)
	self.state = GameConfig.States.Waiting

	self.seats = {} -- SeatIndex 순서로 정렬된 Seat 배열
	self.playerOfSeat = {} -- [Seat]   = Player
	self.seatOfPlayer = {} -- [Player] = Seat
	self.seatedCount = 0

	self.cleaner = Utility.Cleaner.new()
	self.promptLimiter = Utility.RateLimiter.new(GameConfig.PromptCooldown)

	-- 인원이 바뀔 때마다 발생. Phase 2 의 카운트다운이 여기에 붙는다.
	-- (gameTable, player, joined) 형태로 전달된다.
	self.RosterChanged = self.cleaner:add(Utility.Signal.new())

	self:_collectSeats(seatsFolder)

	if #self.seats == 0 then
		warn(("[CursedBarrel] '%s' 의 Seats 폴더 안에 Seat 이 하나도 없습니다."):format(model:GetFullName()))
		self.cleaner:clean()
		return nil
	end

	self:_writeTableAttributes()
	self:_bindSeats()
	self:_refresh()

	return self
end

function GameTable:Destroy()
	-- 앉아 있던 사람들을 먼저 일으켜 세운다.
	-- 순회 중에 명단이 바뀌므로 목록을 복사해 두고 돈다.
	local seatedPlayers = {}
	for player in pairs(self.seatOfPlayer) do
		table.insert(seatedPlayers, player)
	end
	for _, player in ipairs(seatedPlayers) do
		self:RemovePlayer(player)
	end

	self.cleaner:clean()

	table.clear(self.seats)
	table.clear(self.playerOfSeat)
	table.clear(self.seatOfPlayer)

	self.model = nil
end

--------------------------------------------------
-- 초기화 내부 함수
--------------------------------------------------

function GameTable:_collectSeats(seatsFolder)
	for _, descendant in ipairs(seatsFolder:GetDescendants()) do
		if descendant:IsA("Seat") then
			table.insert(self.seats, descendant)
		end
	end

	-- SeatIndex Attribute 가 있으면 그 순서, 없으면 이름 순서로 정렬한다.
	table.sort(self.seats, function(a, b)
		local indexA = a:GetAttribute(SEAT_ATTR.SeatIndex) or math.huge
		local indexB = b:GetAttribute(SEAT_ATTR.SeatIndex) or math.huge
		if indexA == indexB then
			return a.Name < b.Name
		end
		return indexA < indexB
	end)

	-- 정렬 결과대로 번호를 다시 매긴다. (모델을 손으로 만들어도 항상 1..N 이 된다)
	for index, seat in ipairs(self.seats) do
		seat:SetAttribute(SEAT_ATTR.SeatIndex, index)
		seat:SetAttribute(SEAT_ATTR.OccupantUserId, 0)
		CollectionService:AddTag(seat, GameConfig.Tags.Seat)
	end
end

function GameTable:_writeTableAttributes()
	local model = self.model
	model:SetAttribute(TABLE_ATTR.TableId, self.tableId)
	model:SetAttribute(TABLE_ATTR.TableType, self.typeName)
	model:SetAttribute(TABLE_ATTR.SeatCount, #self.seats)
	model:SetAttribute(TABLE_ATTR.MinPlayers, math.min(self.config.MinPlayers, #self.seats))
	model:SetAttribute(TABLE_ATTR.SeatedCount, 0)
	model:SetAttribute(TABLE_ATTR.State, self.state)
end

function GameTable:_bindSeats()
	for _, seat in ipairs(self.seats) do
		local prompt = self:_ensurePrompt(seat)

		self.cleaner:add(prompt.Triggered:Connect(function(player)
			self:_onPromptTriggered(player, seat)
		end))

		-- 앉기/일어서기 판단은 오직 서버의 이 신호만 믿는다.
		self.cleaner:add(seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			self:_onOccupantChanged(seat)
		end))
	end
end

-- Prompt 는 서버가 직접 만들어 붙인다.
-- 손으로 만든 모델이든 복제한 모델이든 설정이 항상 똑같이 맞춰진다.
function GameTable:_ensurePrompt(seat)
	local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SitPrompt"
		prompt.Parent = seat
	end

	local settings = GameConfig.SeatPrompt
	prompt.ActionText = settings.ActionText
	prompt.ObjectText = ("%s · %d번 자리"):format(self.config.DisplayName, seat:GetAttribute(SEAT_ATTR.SeatIndex) or 0)
	prompt.HoldDuration = settings.HoldDuration
	prompt.MaxActivationDistance = settings.MaxActivationDistance
	prompt.RequiresLineOfSight = settings.RequiresLineOfSight
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton

	return prompt
end

--------------------------------------------------
-- 좌석 이벤트
--------------------------------------------------

function GameTable:_onPromptTriggered(player, seat)
	-- 1) 연타 방지
	if not self.promptLimiter:check(player.UserId) then
		return
	end

	-- 2) 지금 참가 가능한 상태인가
	if not self:IsJoinable() then
		return
	end

	-- 3) 이미 누가 앉아 있는 자리인가
	if seat.Occupant ~= nil then
		return
	end

	-- 4) 캐릭터가 멀쩡한가
	local humanoid = Utility.getHumanoid(player)
	if not humanoid then
		return
	end

	-- 5) 이미 어딘가에 앉아 있는가
	if humanoid.SeatPart then
		return
	end

	-- 6) 정말 자리 근처에 있는가 (클라이언트 거리 판정을 서버가 한 번 더 확인)
	local rootPart = humanoid.RootPart
	if not rootPart then
		return
	end

	local allowedDistance = GameConfig.SeatPrompt.MaxActivationDistance + 6
	if (rootPart.Position - seat.Position).Magnitude > allowedDistance then
		return
	end

	seat:Sit(humanoid)
end

function GameTable:_onOccupantChanged(seat)
	local occupant = seat.Occupant
	local previousPlayer = self.playerOfSeat[seat]

	-- 자리가 비었다 → 앉아 있던 사람을 명단에서 뺀다
	if not occupant then
		if previousPlayer then
			self:_unseat(previousPlayer, seat)
		end
		return
	end

	local character = occupant.Parent
	local player = character and Players:GetPlayerFromCharacter(character)

	-- 플레이어가 아닌 Humanoid(NPC 등)는 참가자로 세지 않는다
	if not player then
		return
	end

	if previousPlayer == player then
		return
	end

	if previousPlayer then
		self:_unseat(previousPlayer, seat)
	end

	-- 진행 중인 테이블에는 난입할 수 없다 (익스플로잇으로 순간이동해 앉아도 튕겨낸다)
	if not self:IsJoinable() then
		task.defer(function()
			if seat.Occupant == occupant then
				occupant.Sit = false
			end
		end)
		return
	end

	self:_seat(player, seat)
end

function GameTable:_seat(player, seat)
	self.playerOfSeat[seat] = player
	self.seatOfPlayer[player] = seat
	seat:SetAttribute(SEAT_ATTR.OccupantUserId, player.UserId)

	GameConfig.log(("%s → %s %d번 자리에 앉음"):format(player.Name, self.tableId, seat:GetAttribute(SEAT_ATTR.SeatIndex)))

	self:_refresh()
	self.RosterChanged:Fire(self, player, true)
end

function GameTable:_unseat(player, seat)
	if self.playerOfSeat[seat] ~= player then
		return
	end

	self.playerOfSeat[seat] = nil
	self.seatOfPlayer[player] = nil
	seat:SetAttribute(SEAT_ATTR.OccupantUserId, 0)

	GameConfig.log(("%s → %s %d번 자리에서 일어남"):format(player.Name, self.tableId, seat:GetAttribute(SEAT_ATTR.SeatIndex)))

	self:_refresh()
	self.RosterChanged:Fire(self, player, false)
end

-- 인원 수를 다시 세고 Attribute 와 Prompt 상태를 맞춘다.
function GameTable:_refresh()
	local count = 0
	for _, seat in ipairs(self.seats) do
		if self.playerOfSeat[seat] then
			count += 1
		end
	end

	self.seatedCount = count
	self.model:SetAttribute(TABLE_ATTR.SeatedCount, count)

	local joinable = self:IsJoinable()
	for _, seat in ipairs(self.seats) do
		local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = joinable and self.playerOfSeat[seat] == nil
		end

		-- 참가 불가 상태에서는 '걸어가서 부딪혀 앉는' 것도 막는다.
		-- 값이 실제로 달라질 때만 건드린다 (일어설 때의 기본 쿨다운을 방해하지 않기 위해).
		local shouldDisable = not joinable
		if seat.Disabled ~= shouldDisable then
			seat.Disabled = shouldDisable
		end
	end
end

--------------------------------------------------
-- 공개 API (다음 Phase 의 RoundService 가 사용한다)
--------------------------------------------------

function GameTable:IsJoinable()
	return GameConfig.JoinableStates[self.state] == true
end

function GameTable:GetPlayerCount()
	return self.seatedCount
end

-- 좌석 번호 순서대로 정렬된 참가자 목록
function GameTable:GetPlayers()
	local list = {}
	for _, seat in ipairs(self.seats) do
		local player = self.playerOfSeat[seat]
		if player then
			table.insert(list, player)
		end
	end
	return list
end

function GameTable:HasPlayer(player)
	return self.seatOfPlayer[player] ~= nil
end

function GameTable:GetSeatOfPlayer(player)
	return self.seatOfPlayer[player]
end

function GameTable:SetState(newState)
	if self.state == newState then
		return
	end

	self.state = newState
	self.model:SetAttribute(TABLE_ATTR.State, newState)
	self:_refresh()

	GameConfig.log(("%s 상태 → %s"):format(self.tableId, newState))
end

-- 플레이어를 자리에서 강제로 일으켜 세운다.
function GameTable:RemovePlayer(player)
	local seat = self.seatOfPlayer[player]
	if not seat then
		return false
	end

	local humanoid = Utility.getHumanoid(player)
	if humanoid and humanoid.SeatPart == seat then
		-- Occupant 변경 신호가 뒷정리를 대신 해준다.
		humanoid.Sit = false
	end

	-- 캐릭터가 이미 사라진 경우를 대비해 직접 정리도 해둔다.
	self:_unseat(player, seat)
	return true
end

-- 플레이어가 게임을 나갈 때 호출된다.
function GameTable:HandlePlayerRemoving(player)
	self.promptLimiter:forget(player.UserId)
	self:RemovePlayer(player)
end

return GameTable
