--[[
	GameTable
	게임 테이블 하나를 담당하는 서버 측 객체.

	Phase 1 담당 범위
	  - 모델 안의 Seat 을 찾아 좌석 목록을 만든다
	  - 좌석마다 "앉기" ProximityPrompt 를 붙인다
	  - 누가 앉고 일어나는지 서버가 직접 감시해 참가자 명단을 관리한다
	  - 현재 인원을 테이블 Attribute 로 기록한다 (클라이언트 UI 가 이걸 읽는다)

	Phase 2 에서 더해진 것
	  - 카운트다운/턴 Attribute 자리를 미리 만들어 둔다 (값은 RoundService 가 채운다)
	  - GetSeats / GetPlayerOfSeat / GetMinPlayers / SetTableAttribute 같은 조회용 API
	  - 게임이 시작되면 "빈 좌석"만 잠근다 (앉아 있는 참가자는 건드리지 않는다)

	Phase 3 에서 더해진 것
	  - 통 둘레의 칼 슬롯을 갖추고(SlotBuilder), 슬롯마다 "칼 꽂기" 프롬프트를 붙인다
	  - 슬롯 프롬프트는 게임 중 + 아직 비어 있는 자리에서만 켜진다
	  - 칼을 꽂는 연출(칼 등장 / 뚜껑 튀어오름 / 통 빛 색)을 담당한다
	  - 판정(누가 언제 어느 자리를 고를 수 있는가)은 전부 RoundService 가 한다

	테이블마다 독립된 객체이므로 한 테이블의 일이 다른 테이블에 영향을 주지 않는다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TableConfig = require(Shared:WaitForChild("TableConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local SlotBuilder = require(script.Parent.SlotBuilder)

local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes
local SLOT_ATTR = GameConfig.SlotAttributes

local GameTable = {}
GameTable.__index = GameTable

-- TableId Attribute 가 없는 모델에 붙여줄 자동 번호
local autoIdCounter = 0
local playerTables = {} -- 한 플레이어는 한 테이블의 한 좌석만 소유

local LID_POP_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LID_BACK_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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
	local seatsFolder = model:FindFirstChild("Seats")
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
	self.occupantConnections = {}
	self.destroyed = false

	self.slots = {} -- SlotIndex 순서로 정렬된 슬롯 Part 배열
	self.slotOfIndex = {} -- [번호] = Part

	self.cleaner = Utility.Cleaner.new()
	self.promptLimiter = Utility.RateLimiter.new(GameConfig.PromptCooldown)

	-- 인원이 바뀔 때마다 발생. RoundService 가 여기에 붙어 카운트다운을 켜고 끈다.
	-- (gameTable, player, joined) 형태로 전달된다.
	self.RosterChanged = self.cleaner:add(Utility.Signal.new())

	-- Phase 3 : 슬롯 프롬프트를 눌렀을 때 발생. (gameTable, player, slotIndex)
	-- 실제 판정은 RoundService 가 한다.
	self.SlotTriggered = self.cleaner:add(Utility.Signal.new())

	self:_collectSeats(seatsFolder)

	if #self.seats == 0 then
		warn(("[CursedBarrel] '%s' 의 Seats 폴더 안에 Seat 이 하나도 없습니다."):format(model:GetFullName()))
		self.cleaner:clean()
		return nil
	end

	self:_setupSlots()
	self:_writeTableAttributes()
	self:_bindSeats()
	for _, seat in ipairs(self.seats) do self:_onOccupantChanged(seat) end
	self:_refresh()

	return self
end

function GameTable:Destroy()
	if self.destroyed then return end
	self.destroyed = true
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
	for _, seat in ipairs(self.seats) do
		local prompt = seat:FindFirstChild("SitPrompt")
		if prompt then prompt:Destroy() end
		CollectionService:RemoveTag(seat, GameConfig.Tags.Seat)
	end

	for _, slot in ipairs(self.slots) do
		local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
		if prompt then prompt:Destroy() end
		CollectionService:RemoveTag(slot, GameConfig.Tags.Slot)
	end

	table.clear(self.seats)
	table.clear(self.slots)
	table.clear(self.slotOfIndex)
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
		seat:SetAttribute(SEAT_ATTR.TurnOrder, 0)
		seat:SetAttribute(SEAT_ATTR.Alive, false)
		CollectionService:AddTag(seat, GameConfig.Tags.Seat)
	end
end

-- Phase 3 : 통 둘레에 칼 슬롯을 갖춘다.
function GameTable:_setupSlots()
	local count = TableConfig.getSlotCount(self.typeName)
	local slots = SlotBuilder.ensure(self.model, count)

	self.slots = slots
	table.clear(self.slotOfIndex)

	for _, slot in ipairs(slots) do
		local index = slot:GetAttribute(SLOT_ATTR.SlotIndex)
		if index then
			self.slotOfIndex[index] = slot
		end

		local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			self.cleaner:add(prompt.Triggered:Connect(function(player)
				self:_onSlotPromptTriggered(player, slot)
			end))
		end
	end
end

function GameTable:_writeTableAttributes()
	local model = self.model
	model:SetAttribute(TABLE_ATTR.TableId, self.tableId)
	model:SetAttribute(TABLE_ATTR.TableType, self.typeName)
	model:SetAttribute(TABLE_ATTR.SeatCount, #self.seats)
	model:SetAttribute(TABLE_ATTR.MinPlayers, self:GetMinPlayers())
	model:SetAttribute(TABLE_ATTR.SeatedCount, 0)
	model:SetAttribute(TABLE_ATTR.State, self.state)

	-- Phase 2 : 값은 RoundService 가 채우지만, 자리는 여기서 미리 만들어 둔다.
	-- 클라이언트가 첫 프레임부터 nil 검사 없이 읽을 수 있다.
	model:SetAttribute(TABLE_ATTR.CountdownEndsAt, 0)
	model:SetAttribute(TABLE_ATTR.CountdownDuration, self.config.CountdownDuration or 0)
	model:SetAttribute(TABLE_ATTR.RoundId, 0)
	model:SetAttribute(TABLE_ATTR.ParticipantCount, 0)
	model:SetAttribute(TABLE_ATTR.TurnCount, 0)
	model:SetAttribute(TABLE_ATTR.TurnIndex, 0)
	model:SetAttribute(TABLE_ATTR.CurrentTurnUserId, 0)
	model:SetAttribute(TABLE_ATTR.CurrentTurnName, "")
	model:SetAttribute(TABLE_ATTR.TurnEndsAt, 0)

	-- Phase 3 : 칼 슬롯 / 승패
	model:SetAttribute(TABLE_ATTR.KnifeSlotCount, #self.slots)
	model:SetAttribute(TABLE_ATTR.SlotsRemaining, #self.slots)
	model:SetAttribute(TABLE_ATTR.BarrelCycle, 0)
	model:SetAttribute(TABLE_ATTR.LastPickSlot, 0)
	model:SetAttribute(TABLE_ATTR.LastPickUserId, 0)
	model:SetAttribute(TABLE_ATTR.LastPickName, "")
	model:SetAttribute(TABLE_ATTR.LastPickSafe, true)
	model:SetAttribute(TABLE_ATTR.WinnerUserId, 0)
	model:SetAttribute(TABLE_ATTR.WinnerName, "")
	model:SetAttribute(TABLE_ATTR.ResetEndsAt, 0)
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
	if self.destroyed or not self:IsJoinable() then
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

-- Phase 3 : 슬롯 프롬프트는 "요청"만 전달한다. 통과/거절은 RoundService 가 정한다.
function GameTable:_onSlotPromptTriggered(player, slot)
	if self.destroyed then
		return
	end

	local index = slot:GetAttribute(SLOT_ATTR.SlotIndex)
	if not index then
		return
	end

	self.SlotTriggered:Fire(self, player, index)
end

function GameTable:_onOccupantChanged(seat)
	if self.destroyed then return end
	local occupant = seat.Occupant
	local previousPlayer = self.playerOfSeat[seat]

	-- 자리가 비었다 → 앉아 있던 사람을 명단에서 뺀다
	if not occupant then
		if previousPlayer then
			self:_unseat(previousPlayer, seat)
		end
		self:_refresh()
		return
	end

	local character = occupant.Parent
	local player = character and Players:GetPlayerFromCharacter(character)

	-- 플레이어가 아닌 Humanoid(NPC 등)는 참가자로 세지 않는다
	if not player or player.Parent ~= Players or occupant.Health <= 0 then
		if previousPlayer then self:_unseat(previousPlayer, seat) end
		occupant.Sit = false
		self:_refresh()
		return
	end

	if previousPlayer == player then
		return
	end

	if previousPlayer then
		self:_unseat(previousPlayer, seat)
	end

	-- 진행 중인 테이블에는 난입할 수 없다 (익스플로잇으로 순간이동해 앉아도 튕겨낸다)
	if self.destroyed or not self:IsJoinable() then
		GameConfig.log(("%s 진행 중이라 %s 의 착석을 되돌립니다."):format(self.tableId, player.Name))
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
	local previousTable = playerTables[player]
	if previousTable then
		local previousSeat = previousTable.seatOfPlayer[player]
		if previousSeat and (previousTable ~= self or previousSeat ~= seat) then
			previousTable:_unseat(player, previousSeat)
		end
	end
	playerTables[player] = self
	self.playerOfSeat[seat] = player
	self.seatOfPlayer[player] = seat
	seat:SetAttribute(SEAT_ATTR.OccupantUserId, player.UserId)
	local connections = {}
	self.occupantConnections[seat] = connections
	local humanoid = seat.Occupant
	if humanoid then
		table.insert(connections, humanoid.Died:Connect(function() self:RemovePlayer(player) end))
	end
	table.insert(connections, player.CharacterRemoving:Connect(function() self:RemovePlayer(player) end))

	GameConfig.log(("%s → %s %d번 자리에 앉음"):format(player.Name, self.tableId, seat:GetAttribute(SEAT_ATTR.SeatIndex)))

	self:_refresh()
	self.RosterChanged:Fire(self, player, true)
end

function GameTable:_unseat(player, seat)
	if self.playerOfSeat[seat] ~= player then
		return
	end

	self.playerOfSeat[seat] = nil
	if self.seatOfPlayer[player] == seat then self.seatOfPlayer[player] = nil end
	if playerTables[player] == self and not self.seatOfPlayer[player] then playerTables[player] = nil end
	for _, connection in ipairs(self.occupantConnections[seat] or {}) do connection:Disconnect() end
	self.occupantConnections[seat] = nil
	seat:SetAttribute(SEAT_ATTR.OccupantUserId, 0)
	seat:SetAttribute(SEAT_ATTR.TurnOrder, 0)
	seat:SetAttribute(SEAT_ATTR.Alive, false)

	GameConfig.log(("%s → %s %d번 자리에서 일어남"):format(player.Name, self.tableId, seat:GetAttribute(SEAT_ATTR.SeatIndex)))

	self:_refresh()
	self.RosterChanged:Fire(self, player, false)
end

-- 인원 수를 다시 세고 Attribute 와 Prompt 상태를 맞춘다.
function GameTable:_refresh()
	if not self.model then return end

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
			prompt.Enabled = not self.destroyed and joinable and seat.Occupant == nil
		end

		-- 참가 불가 상태에서는 '걸어가서 부딪혀 앉는' 것도 막는다.
		-- 단, 이미 앉아 있는 좌석은 건드리지 않는다.
		--   (게임 중인 참가자의 좌석을 Disabled 로 만들 필요가 없고,
		--    일어설 때의 기본 쿨다운도 방해하지 않는다)
		local shouldDisable = (not joinable) and seat.Occupant == nil
		if seat.Disabled ~= shouldDisable then
			seat.Disabled = shouldDisable
		end
	end

	self:_refreshSlotPrompts()
end

-- 칼 꽂기 프롬프트는 "게임 중" + "아직 비어 있는 자리"에서만 켜진다.
-- 내 차례가 아닐 때 프롬프트를 숨기는 것은 각자의 화면(KnifeController)이 한다.
-- 눌렀을 때 통과시킬지는 어차피 서버가 다시 판단한다.
function GameTable:_refreshSlotPrompts()
	local playing = (not self.destroyed) and self.state == GameConfig.States.Playing

	for _, slot in ipairs(self.slots) do
		local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local used = slot:GetAttribute(SLOT_ATTR.Used) == true
			local enabled = playing and not used
			if prompt.Enabled ~= enabled then
				prompt.Enabled = enabled
			end
		end
	end
end

--------------------------------------------------
-- 공개 API (RoundService 가 사용한다)
--------------------------------------------------

function GameTable:IsJoinable()
	return GameConfig.JoinableStates[self.state] == true
end

function GameTable:GetPlayerCount()
	return self.seatedCount
end

-- 이 테이블에서 카운트다운을 시작/유지하는 데 필요한 인원.
-- 좌석 수보다 큰 값이 설정돼 있으면 영원히 시작되지 않으므로 좌석 수로 잘라준다.
function GameTable:GetMinPlayers()
	local configured = tonumber(self.config.MinPlayers) or 2
	return math.max(1, math.min(configured, #self.seats))
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

function GameTable:GetSeats()
	return self.seats
end

function GameTable:GetPlayerOfSeat(seat)
	return self.playerOfSeat[seat]
end

function GameTable:HasPlayer(player)
	return self.seatOfPlayer[player] ~= nil
end

function GameTable:GetSeatOfPlayer(player)
	return self.seatOfPlayer[player]
end

--------------------------------------------------
-- Phase 3 : 칼 슬롯
--------------------------------------------------

function GameTable:GetSlots()
	return self.slots
end

function GameTable:GetSlotCount()
	return #self.slots
end

function GameTable:GetSlot(index)
	return self.slotOfIndex[index]
end

function GameTable:IsSlotUsed(index)
	local slot = self.slotOfIndex[index]
	return slot ~= nil and slot:GetAttribute(SLOT_ATTR.Used) == true
end

-- 아직 아무도 고르지 않은 슬롯 번호 목록
function GameTable:GetFreeSlotIndices()
	local free = {}
	for _, slot in ipairs(self.slots) do
		if slot:GetAttribute(SLOT_ATTR.Used) ~= true then
			table.insert(free, slot:GetAttribute(SLOT_ATTR.SlotIndex))
		end
	end
	return free
end

-- 칼을 꽂은 모습으로 바꾼다. (판정은 이미 RoundService 가 끝냈다)
function GameTable:MarkSlotUsed(index, player, isDanger)
	local slot = self.slotOfIndex[index]
	if not slot then
		return false
	end

	SlotBuilder.markUsed(slot, player, isDanger)
	self:_refreshSlotPrompts()
	return true
end

-- 통을 새 칼로 다시 채운다. (라운드 시작 / 누군가 탈락한 뒤)
function GameTable:ResetSlots()
	for _, slot in ipairs(self.slots) do
		SlotBuilder.resetSlot(slot)
	end
	self:SetTableAttribute(TABLE_ATTR.SlotsRemaining, #self.slots)
	self:_refreshSlotPrompts()
end

--------------------------------------------------
-- Phase 3 : 통 연출
--------------------------------------------------

function GameTable:_findBarrelPart(name)
	local barrel = self.model and self.model:FindFirstChild(GameConfig.SlotLayout.BarrelName)
	if not barrel then
		return nil
	end
	local part = barrel:FindFirstChild(name, true)
	return (part and part:IsA("BasePart")) and part or nil
end

-- 위험한 자리를 골랐을 때: 뚜껑이 튀어오르고 통이 붉게 빛난다.
function GameTable:PlayDangerEffect()
	local lid = self:_findBarrelPart("Lid")
	if lid then
		local original = lid.CFrame
		self._lidHome = self._lidHome or original
		local popped = self._lidHome * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.rad(24), math.rad(12))

		local up = TweenService:Create(lid, LID_POP_TWEEN, { CFrame = popped })
		up:Play()
		up.Completed:Connect(function()
			if lid.Parent then
				TweenService:Create(lid, LID_BACK_TWEEN, { CFrame = self._lidHome }):Play()
			end
		end)
	end

	local glow = self:_findBarrelPart("Glow")
	if glow then
		self._glowHome = self._glowHome or glow.Color
		glow.Color = GameConfig.SlotLayout.DangerColor
		local light = glow:FindFirstChildOfClass("PointLight")
		if light then
			self._lightHome = self._lightHome or light.Color
			light.Color = GameConfig.SlotLayout.DangerColor
		end

		task.delay(1.2, function()
			if glow.Parent and self._glowHome then
				glow.Color = self._glowHome
				local pointLight = glow:FindFirstChildOfClass("PointLight")
				if pointLight and self._lightHome then
					pointLight.Color = self._lightHome
				end
			end
		end)
	end
end

-- 통을 원래 모습으로 되돌린다.
function GameTable:ResetBarrelLook()
	local lid = self:_findBarrelPart("Lid")
	if lid and self._lidHome then
		lid.CFrame = self._lidHome
	end

	local glow = self:_findBarrelPart("Glow")
	if glow and self._glowHome then
		glow.Color = self._glowHome
		local light = glow:FindFirstChildOfClass("PointLight")
		if light and self._lightHome then
			light.Color = self._lightHome
		end
	end
end

--------------------------------------------------
-- 상태 / 좌석 표시
--------------------------------------------------

-- 파괴된 뒤에 늦게 도착한 호출이 있어도 오류가 나지 않도록 감싼다.
function GameTable:SetTableAttribute(name, value)
	if self.destroyed or not self.model then
		return false
	end
	self.model:SetAttribute(name, value)
	return true
end

-- 좌석에 "아직 살아 있는 참가자" 표시를 남긴다. (의자 색을 바꾸는 등 연출에 쓰인다)
function GameTable:SetSeatAlive(player, alive)
	local seat = self.seatOfPlayer[player]
	if not seat then
		return false
	end
	seat:SetAttribute(SEAT_ATTR.Alive, alive and true or false)
	return true
end

function GameTable:ClearSeatFlags()
	for _, seat in ipairs(self.seats) do
		seat:SetAttribute(SEAT_ATTR.TurnOrder, 0)
		seat:SetAttribute(SEAT_ATTR.Alive, false)
	end
end

function GameTable:SetState(newState)
	if self.state == newState then
		return
	end

	self.state = newState
	if self.model then
		self.model:SetAttribute(TABLE_ATTR.State, newState)
	end
	self:_refresh()

	GameConfig.log(("%s 상태 → %s"):format(self.tableId, newState))
end

-- 플레이어를 자리에서 강제로 일으켜 세운다.
function GameTable:RemovePlayer(player)
	local seat = self.seatOfPlayer[player]
	if not seat then
		return false
	end

	local humanoid = seat.Occupant
	if humanoid and Players:GetPlayerFromCharacter(humanoid.Parent) == player then
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
	if playerTables[player] == self then
		playerTables[player] = nil
	end
end

return GameTable
