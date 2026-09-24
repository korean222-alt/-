--[[
	GameTable
	게임 테이블 하나를 담당하는 서버 측 객체.

	Phase 1  좌석 찾기 · 앉기 프롬프트 · 인원 Attribute
	Phase 2  카운트다운/턴 Attribute 자리 · 게임 중 빈 좌석 잠그기
	Phase 3  통 둘레의 칼 슬롯 · 칼 꽂기 연출
	Phase 7  ★ 통 스킨을 테이블 하나에 하나만 적용한다 (서버가 고른다)
	Phase 8  ★ TableType 이 요구하는 만큼 의자를 갖춘다 (6인 테이블)
	Phase 11 ★ AI 선원도 의자에 앉힌다 (BotRegistry 로 몸을 알아본다) · 통에 나뭇결 · 쇠징 장식

	판정(누가 언제 어느 자리를 고를 수 있는가)은 전부 RoundService 가 한다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TableConfig = require(Shared:WaitForChild("TableConfig"))
local Utility = require(Shared:WaitForChild("Utility"))
local SkinFX = require(Shared:WaitForChild("SkinFX"))
local DrumStyle = require(Shared:WaitForChild("DrumStyle"))
local ReleaseConfig = require(Shared:WaitForChild("ReleaseConfig"))

local SlotBuilder = require(script.Parent.SlotBuilder)
local BotRegistry = require(script.Parent.BotRegistry)
local TableBuilder = require(script.Parent.TableBuilder)

local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes
local SLOT_ATTR = GameConfig.SlotAttributes
local PLAYER_ATTR = GameConfig.PlayerAttributes
local SKIN_ATTR = GameConfig.Skins.PlayerAttributes

local GameTable = {}
GameTable.__index = GameTable

local autoIdCounter = 0
local playerTables = {} -- 한 플레이어는 한 테이블의 한 좌석만 소유

local LID_POP_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LID_BACK_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--------------------------------------------------
-- 생성 / 파괴
--------------------------------------------------

function GameTable.new(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn("[CursedBarrel] 테이블 태그는 Model 에만 붙일 수 있습니다: " .. tostring(model))
		return nil
	end

	local seatsFolder = model:FindFirstChild("Seats")
	if not seatsFolder then
		warn(("[CursedBarrel] '%s' 안에 Seats 폴더가 없어 등록하지 못했습니다."):format(model:GetFullName()))
		return nil
	end

	autoIdCounter += 1

	local self = setmetatable({}, GameTable)

	self.model = model
	self.tableId = model:GetAttribute(TABLE_ATTR.TableId) or ("Table_%02d"):format(autoIdCounter)
	-- 종류는 모델 이름으로 덮어쓸 수 있다. (6인 테이블 · 빠른 모드를 코드에서 배정한다)
	self.typeName = GameConfig.TableTypeByName[model.Name]
		or model:GetAttribute(TABLE_ATTR.TableType)
		or TableConfig.DefaultType
	self.config = TableConfig.get(self.typeName)
	self.state = GameConfig.States.Waiting

	self.seats = {}
	self.playerOfSeat = {}
	self.seatOfPlayer = {}
	self.seatOrder = {} -- [Player] = 앉은 순서 (통 스킨 동점 처리에 쓴다)
	self.seatCounter = 0
	self.seatedCount = 0
	self.occupantConnections = {}
	self.destroyed = false

	self.slots = {}
	self.slotOfIndex = {}

	self.barrelSkin = nil -- 지금 이 테이블에 적용 중인 통 스킨

	self.cleaner = Utility.Cleaner.new()
	self.promptLimiter = Utility.RateLimiter.new(GameConfig.PromptCooldown)

	self.RosterChanged = self.cleaner:add(Utility.Signal.new())
	self.SlotTriggered = self.cleaner:add(Utility.Signal.new())

	-- Phase 8 : TableType 이 요구하는 만큼 의자를 갖춘다. (6인 테이블은 여기서 만들어진다)
	pcall(function()
		TableBuilder.ensureSeats(model, tonumber(self.config.SeatCount) or 4)
	end)

	self:_collectSeats(seatsFolder)

	if #self.seats == 0 then
		warn(("[CursedBarrel] '%s' 의 Seats 폴더 안에 Seat 이 하나도 없습니다."):format(model:GetFullName()))
		self.cleaner:clean()
		return nil
	end

	self:_setupSlots()
	pcall(function()
		self:_decorateBarrel()
	end)
	self:_writeTableAttributes()
	self:_bindSeats()
	for _, seat in ipairs(self.seats) do
		self:_onOccupantChanged(seat)
	end
	self:_refresh()
	self:RefreshBarrelSkin()

	return self
end

function GameTable:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true

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
		if prompt then
			prompt:Destroy()
		end
		CollectionService:RemoveTag(seat, GameConfig.Tags.Seat)
	end

	for _, slot in ipairs(self.slots) do
		local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt:Destroy()
		end
		CollectionService:RemoveTag(slot, GameConfig.Tags.Slot)
	end

	table.clear(self.seats)
	table.clear(self.slots)
	table.clear(self.slotOfIndex)
	table.clear(self.playerOfSeat)
	table.clear(self.seatOfPlayer)
	table.clear(self.seatOrder)

	self.model = nil
end

--------------------------------------------------
-- 초기화 내부 함수
--------------------------------------------------

function GameTable:_collectSeats(seatsFolder)
	table.clear(self.seats)
	for _, descendant in ipairs(seatsFolder:GetDescendants()) do
		if descendant:IsA("Seat") then
			table.insert(self.seats, descendant)
		end
	end

	table.sort(self.seats, function(a, b)
		local indexA = a:GetAttribute(SEAT_ATTR.SeatIndex) or math.huge
		local indexB = b:GetAttribute(SEAT_ATTR.SeatIndex) or math.huge
		if indexA == indexB then
			return a.Name < b.Name
		end
		return indexA < indexB
	end)

	for index, seat in ipairs(self.seats) do
		seat:SetAttribute(SEAT_ATTR.SeatIndex, index)
		seat:SetAttribute(SEAT_ATTR.OccupantUserId, 0)
		seat:SetAttribute(SEAT_ATTR.OccupantName, "")
		seat:SetAttribute(SEAT_ATTR.OccupantBot, false)
		seat:SetAttribute(SEAT_ATTR.TurnOrder, 0)
		seat:SetAttribute(SEAT_ATTR.Alive, false)
		CollectionService:AddTag(seat, GameConfig.Tags.Seat)
	end
end

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

	model:SetAttribute(TABLE_ATTR.CountdownEndsAt, 0)
	model:SetAttribute(TABLE_ATTR.CountdownDuration, self.config.CountdownDuration or 0)
	model:SetAttribute(TABLE_ATTR.RoundId, 0)
	model:SetAttribute(TABLE_ATTR.ParticipantCount, 0)
	model:SetAttribute(TABLE_ATTR.TurnCount, 0)
	model:SetAttribute(TABLE_ATTR.TurnIndex, 0)
	model:SetAttribute(TABLE_ATTR.CurrentTurnUserId, 0)
	model:SetAttribute(TABLE_ATTR.CurrentTurnName, "")
	model:SetAttribute(TABLE_ATTR.TurnEndsAt, 0)

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
	model:SetAttribute(TABLE_ATTR.CatchCount, 0)
	model:SetAttribute(TABLE_ATTR.PirateCount, 0)
	model:SetAttribute(TABLE_ATTR.BarrelSkinId, "")
	model:SetAttribute(TABLE_ATTR.BarrelSkinOwnerId, 0)
	model:SetAttribute(TABLE_ATTR.BarrelSkinOwnerName, "")

	-- 현황판과 안내 화살표가 읽는 이름
	if model:GetAttribute("DisplayName") == nil then
		model:SetAttribute("DisplayName", self.config.DisplayName)
	end
end

function GameTable:_bindSeats()
	for _, seat in ipairs(self.seats) do
		local prompt = self:_ensurePrompt(seat)

		self.cleaner:add(prompt.Triggered:Connect(function(player)
			self:_onPromptTriggered(player, seat)
		end))

		self.cleaner:add(seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			self:_onOccupantChanged(seat)
		end))
	end
end

function GameTable:_ensurePrompt(seat)
	local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SitPrompt"
		prompt.Parent = seat
	end

	local settings = GameConfig.SeatPrompt
	prompt.ActionText = settings.ActionText
	prompt.ObjectText = "" -- 부제목 없음
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
	if player:GetAttribute("ProfileLoaded") ~= true then
		return
	end
	-- 스스로 "앉기"를 눌렀다면 자리를 비운 것이 아니다. 자리 비움 표시를 풀어 준다.
	-- (클라이언트의 "돌아왔음" 신호가 요청 제한에 걸려 사라지면, 영영 앉지 못하는 일이 있었다)
	if player:GetAttribute("AFK") == true then
		player:SetAttribute("AFK", false)
	end
	if not self.promptLimiter:check(player.UserId) then
		return
	end
	if self.destroyed or not self:IsJoinable() then
		return
	end
	if seat.Occupant ~= nil then
		return
	end

	local humanoid = Utility.getHumanoid(player)
	if not humanoid then
		return
	end
	if humanoid.SeatPart then
		return
	end

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
	if self.destroyed then
		return
	end
	local occupant = seat.Occupant
	local previousPlayer = self.playerOfSeat[seat]

	if not occupant then
		-- 바로 앉힌 AI 선원은 원래 Occupant 가 없다. 치우지 않는다.
		if previousPlayer and not GameConfig.isBot(previousPlayer) then
			self:_unseat(previousPlayer, seat)
		end
		self:_refresh()
		return
	end

	local character = occupant.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	-- Phase 11 : AI 선원. Players 에는 없지만 BotService 가 명부에 적어 두었다.
	local bot = (not player) and BotRegistry.fromCharacter(character) or nil
	if bot then
		player = bot
	end

	if not player or (not bot and (player.Parent ~= Players or player:GetAttribute("ProfileLoaded")~=true or player:GetAttribute("AFK")==true)) or occupant.Health <= 0 then
		if previousPlayer then
			self:_unseat(previousPlayer, seat)
		end
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
	self.seatCounter += 1
	self.seatOrder[player] = self.seatCounter
	seat:SetAttribute(SEAT_ATTR.OccupantUserId, player.UserId)
	seat:SetAttribute(SEAT_ATTR.OccupantName, player.DisplayName or player.Name)
	seat:SetAttribute(SEAT_ATTR.OccupantBot, GameConfig.isBot(player))

	local connections = {}
	self.occupantConnections[seat] = connections
	local humanoid = seat.Occupant
	if humanoid then
		table.insert(connections, humanoid.Died:Connect(function()
			self:RemovePlayer(player)
		end))
	end
	table.insert(connections, player.CharacterRemoving:Connect(function()
		self:RemovePlayer(player)
	end))

	GameConfig.log(("%s → %s %d번 자리에 앉음"):format(player.Name, self.tableId, seat:GetAttribute(SEAT_ATTR.SeatIndex)))

	self:_refresh()
	self.RosterChanged:Fire(self, player, true)
end

-- AI 선원은 의자 물리(Seat:Sit)에 기대지 않고 바로 앉힌다.
-- 막 만든 NPC 는 Seat:Sit 이 조용히 실패할 때가 있어서(몸이 갑판 아래로 떨어진다) AI 가 오지 않던 버그가 있었다.
-- 몸은 BotService 가 의자 위에 고정해 두고, 클라이언트는 좌석의 BotCharacter 로 몸을 찾는다.
function GameTable:SeatBot(bot, seat)
	if self.destroyed or not GameConfig.isBot(bot) or not self:IsJoinable() then
		return false
	end
	if self.playerOfSeat[seat] or seat.Occupant ~= nil or self.seatOfPlayer[bot] then
		return false
	end
	local link = seat:FindFirstChild("BotCharacter") or Instance.new("ObjectValue")
	link.Name = "BotCharacter"
	link.Value = bot.Character
	link.Parent = seat
	self:_seat(bot, seat)
	return true
end

function GameTable:_unseat(player, seat)
	if self.playerOfSeat[seat] ~= player then
		return
	end
	local link = seat:FindFirstChild("BotCharacter")
	if link then
		link:Destroy()
	end

	self.playerOfSeat[seat] = nil
	if self.seatOfPlayer[player] == seat then
		self.seatOfPlayer[player] = nil
		self.seatOrder[player] = nil
	end
	if playerTables[player] == self and not self.seatOfPlayer[player] then
		playerTables[player] = nil
	end
	for _, connection in ipairs(self.occupantConnections[seat] or {}) do
		connection:Disconnect()
	end
	self.occupantConnections[seat] = nil
	seat:SetAttribute(SEAT_ATTR.OccupantUserId, 0)
	seat:SetAttribute(SEAT_ATTR.OccupantName, "")
	seat:SetAttribute(SEAT_ATTR.OccupantBot, false)
	seat:SetAttribute(SEAT_ATTR.TurnOrder, 0)
	seat:SetAttribute(SEAT_ATTR.Alive, false)

	GameConfig.log(("%s → %s %d번 자리에서 일어남"):format(player.Name, self.tableId, seat:GetAttribute(SEAT_ATTR.SeatIndex)))

	self:_refresh()
	self.RosterChanged:Fire(self, player, false)
end

function GameTable:_refresh()
	if not self.model then
		return
	end

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
		-- AI 선원이 앉은 의자는 비어 보이지만(Occupant 가 없다) 사람이 앉을 수 없다.
		local botSeat = GameConfig.isBot(self.playerOfSeat[seat])
		local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = not self.destroyed and joinable and seat.Occupant == nil and not botSeat
		end

		local shouldDisable = botSeat or ((not joinable) and seat.Occupant == nil)
		if seat.Disabled ~= shouldDisable then
			seat.Disabled = shouldDisable
		end
	end

	self:_refreshSlotPrompts()
end

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
-- 공개 API
--------------------------------------------------

function GameTable:IsJoinable()
	return GameConfig.JoinableStates[self.state] == true
end

function GameTable:GetPlayerCount()
	return self.seatedCount
end

function GameTable:GetMinPlayers()
	local configured = tonumber(self.config.MinPlayers) or 2
	return math.max(1, math.min(configured, #self.seats))
end

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

-- 앉아 있는 사람 수 (AI 선원은 빼고)
function GameTable:GetHumanCount()
	local count = 0
	for _, seat in ipairs(self.seats) do
		local player = self.playerOfSeat[seat]
		if player and not GameConfig.isBot(player) then
			count += 1
		end
	end
	return count
end

-- 비어 있는 좌석 목록. 안내 화살표가 이걸 읽는다.
function GameTable:GetFreeSeats()
	local free = {}
	for _, seat in ipairs(self.seats) do
		if not self.playerOfSeat[seat] and seat.Occupant == nil then
			table.insert(free, seat)
		end
	end
	return free
end

--------------------------------------------------
-- 칼 슬롯
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

	-- 꽂는 사람의 칼 스킨을 먼저 입힌다.
	-- 위험한 자리면 markUsed 가 그 위에 붉은색을 덮어쓴다. (순서가 중요하다)
	local skinId = player and player:GetAttribute(SKIN_ATTR.Knife)
	local skin = GameConfig.findSkin("Knife", skinId)
	if skin then
		SlotBuilder.applyKnifeSkin(slot, skin)
	end

	SlotBuilder.markUsed(slot, player, isDanger)

	-- Phase 6 : 꽂힌 칼에만 이펙트를 붙인다. 위험한 자리는 붉은 연출이 우선이라 생략한다.
	local knife = slot:FindFirstChild("Knife")
	if knife then
		if isDanger then
			SkinFX.clear(knife)
		else
			SkinFX.applyKnife(knife, skin, true)
		end
	end

	self:_refreshSlotPrompts()
	return true
end

function GameTable:ResetSlots()
	for _, slot in ipairs(self.slots) do
		local knife = slot:FindFirstChild("Knife")
		if knife then
			SkinFX.clear(knife)
		end
		SlotBuilder.resetSlot(slot)
	end
	self:SetTableAttribute(TABLE_ATTR.SlotsRemaining, #self.slots)
	self:_refreshSlotPrompts()
end

--------------------------------------------------
-- 통 스킨 (Phase 7)
--
-- 한 테이블에 통은 하나뿐이다. 앉은 사람 둘이 서로 다른 통 스킨을 끼고 있으면
-- 하나만 보여야 한다. 누구 것을 보여줄지는 GameConfig.barrelSkinScore 가 정한다.
--   희귀도 → 레벨 → 연승 → 먼저 앉은 순서
-- (왜 레벨만으로 정하지 않았는지는 GameConfig 의 주석에 적어 두었다)
--------------------------------------------------

function GameTable:_barrelParts()
	local barrel = self.model and self.model:FindFirstChild(GameConfig.SlotLayout.BarrelName)
	if not barrel then
		return nil
	end
	return {
		model = barrel,
		body = barrel:FindFirstChild("Body"),
		hoopLower = barrel:FindFirstChild("HoopLower"),
		hoopUpper = barrel:FindFirstChild("HoopUpper"),
		lid = barrel:FindFirstChild("Lid"),
		glow = barrel:FindFirstChild("Glow"),
	}
end

function GameTable:_applyBarrelSkin(skin)
	local parts = self:_barrelParts()
	if not parts or not parts.body or not skin then
		return
	end

	-- ★ 크기는 절대 건드리지 않는다. 칼 슬롯 배치가 Body 크기에서 계산된다.
	local function paint(part, color, material, reflectance)
		if part and part:IsA("BasePart") then
			part.Color = color
			if material then
				part.Material = material
			end
			part.Reflectance = reflectance or 0
		end
	end

	paint(parts.body, skin.body, skin.bodyMaterial, skin.reflectance)
	paint(parts.hoopLower, skin.hoop, skin.hoopMaterial, skin.reflectance)
	paint(parts.hoopUpper, skin.hoop, skin.hoopMaterial, skin.reflectance)
	paint(parts.lid, skin.lid, skin.hoopMaterial, skin.reflectance)
	paint(parts.glow, skin.glow, skin.glowMaterial or Enum.Material.Neon)

	-- Phase 14 : 3D 모델(메시) ID 가 있으면 몸통을 그 모델로 바꾸고 쇠테 · 뚜껑 · 장식은 숨긴다.
	-- (몸통 크기는 그대로라 칼 슬롯 자리는 바뀌지 않는다)
	local meshSpec = ReleaseConfig.Meshes and ReleaseConfig.Meshes.Barrel and ReleaseConfig.Meshes.Barrel[skin.id]
	local useMesh = meshSpec ~= nil and (tonumber(meshSpec.MeshId) or 0) > 0
	local skinMesh = parts.body:FindFirstChild("SkinMesh")
	if useMesh then
		skinMesh = skinMesh or Instance.new("SpecialMesh")
		skinMesh.Name = "SkinMesh"
		skinMesh.MeshType = Enum.MeshType.FileMesh
		skinMesh.MeshId = "rbxassetid://" .. tostring(meshSpec.MeshId)
		skinMesh.TextureId = (tonumber(meshSpec.TextureId) or 0) > 0 and ("rbxassetid://" .. tostring(meshSpec.TextureId)) or ""
		skinMesh.Scale = meshSpec.Scale or Vector3.new(1, 1, 1)
		skinMesh.Offset = meshSpec.Offset or Vector3.new(0, 0, 0)
		skinMesh.Parent = parts.body
	elseif skinMesh then
		skinMesh:Destroy()
	end
	if parts.lid and parts.lid:IsA("BasePart") then
		parts.lid.Transparency = useMesh and 1 or 0
	end

	-- Phase 13 : 철제 드럼은 원래 쇠테 대신 DrumStyle 의 굴림 테 · 주름을 쓴다
	for _, hoop in ipairs({ parts.hoopLower, parts.hoopUpper }) do
		if hoop and hoop:IsA("BasePart") then
			hoop.Transparency = (skin.drum or useMesh) and 1 or 0
		end
	end

	local light = parts.glow and parts.glow:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = skin.glow
	end

	-- 드럼통의 가로 주름. 스킨이 바뀌면 다시 만든다.
	for _, child in ipairs(parts.model:GetChildren()) do
		if child.Name == "SkinRib" then
			child:Destroy()
		end
	end
	if useMesh then
		-- 메시가 모양을 다 그린다
	elseif skin.drum and parts.body:IsA("Part") and parts.body.Shape == Enum.PartType.Cylinder then
		-- 마개는 뚜껑 · 빛 원판 중 더 높은 면 위에 얹는다
		local top = nil
		local frame = DrumStyle.upright(parts.body.CFrame)
		for _, cover in ipairs({ parts.lid, parts.glow }) do
			if cover and cover:IsA("BasePart") then
				local height = frame:PointToObjectSpace(cover.Position).X + cover.Size.X * 0.5
				top = math.max(top or height, height)
			end
		end
		DrumStyle.build(parts.model, parts.body.CFrame, parts.body.Size.X, parts.body.Size.Y, skin, "SkinRib", top)
	elseif skin.ribbed then
		for _, offset in ipairs({ -0.75, 0, 0.75 }) do
			local rib = Instance.new("Part")
			rib.Name = "SkinRib"
			rib.Shape = Enum.PartType.Cylinder
			rib.Size = Vector3.new(0.16, parts.body.Size.Y * 1.03, parts.body.Size.Z * 1.03)
			rib.CFrame = parts.body.CFrame * CFrame.new(offset, 0, 0)
			rib.Color = skin.hoop
			rib.Material = skin.hoopMaterial or Enum.Material.Metal
			Utility.makeDecor(rib)
			rib.Parent = parts.model
		end
	end

	-- Phase 11 : 장식도 스킨 색을 따른다.
	local detail = parts.model:FindFirstChild("BarrelDetail")
	if detail then
		local wooden = skin.bodyMaterial == Enum.Material.Wood or skin.bodyMaterial == Enum.Material.WoodPlanks
		local plain = not skin.drum and not useMesh
		for _, piece in ipairs(detail:GetChildren()) do
			if piece:IsA("BasePart") then
				if piece.Name == "StaveSeam" then
					piece.Color = skin.body:Lerp(Color3.new(0, 0, 0), 0.45)
					piece.Transparency = (wooden and not skin.ribbed and not useMesh) and 0 or 1
				elseif piece.Name == "Stave" then
					-- 판자마다 조금씩 다른 나뭇결 색
					local shade = piece:GetAttribute("Shade") or 0
					piece.Color = skin.body:Lerp(shade > 0 and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), math.abs(shade))
					piece.Material = skin.bodyMaterial or Enum.Material.Wood
					piece.Transparency = (wooden and not skin.ribbed and not useMesh) and 0 or 1
				elseif piece.Name == "Rivet" or piece.Name == "ChimeHoop" then
					piece.Transparency = plain and 0 or 1
					piece.Color = piece.Name == "Rivet" and skin.hoop:Lerp(Color3.new(1, 1, 1), 0.2) or skin.hoop
					piece.Material = skin.hoopMaterial == Enum.Material.Neon and Enum.Material.Neon or (skin.hoopMaterial or Enum.Material.Metal)
				end
			end
		end
	end

	SkinFX.applyBarrel(parts.model, skin)

	self.barrelSkin = skin
	self:SetTableAttribute(TABLE_ATTR.BarrelSkinId, skin.id)
end

--[[
	Phase 11 : 통 장식. 나무통의 판자 이음새와 쇠테의 징을 덧붙인다.
	  · 크기 · 위치를 바꾸지 않는다. (칼 슬롯이 Body 크기에서 계산된다)
	  · 칼 슬롯과 겹치지 않게 이음새를 슬롯 사이 각도에 둔다.
	  · 스킨이 바뀌면 _applyBarrelSkin 이 색을 다시 칠한다. 쇠 드럼통(주름 있는 스킨)에서는 이음새를 숨긴다.
]]
function GameTable:_decorateBarrel()
	local parts = self:_barrelParts()
	if not parts or not parts.body or parts.model:FindFirstChild("BarrelDetail") then
		return
	end
	local body = parts.body
	if not (body:IsA("Part") and body.Shape == Enum.PartType.Cylinder) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "BarrelDetail"
	local radius = body.Size.Y * 0.5
	local length = body.Size.X
	local seams = 12
	for index = 1, seams do
		local angle = (index - 0.5) / seams * math.pi * 2
		local seam = Instance.new("Part")
		seam.Name = "StaveSeam"
		seam.Size = Vector3.new(length * 0.97, 0.04, 0.07)
		seam.CFrame = body.CFrame * CFrame.Angles(angle, 0, 0) * CFrame.new(0, radius + 0.005, 0)
		seam.Material = Enum.Material.Wood
		Utility.makeDecor(seam)
		seam.Parent = folder
	end
	-- Phase 14 : 판자 한 장 건너 한 장씩 결 색을 살짝 달리한다 (한 덩어리 원통이 아니라 판자를 이어 붙인 통으로 보인다)
	for index = 1, seams do
		if index % 2 == 0 then
			local angle = (index - 1) / seams * math.pi * 2
			local stave = Instance.new("Part")
			stave.Name = "Stave"
			stave.Size = Vector3.new(length * 0.95, 0.02, 2 * math.pi * radius / seams * 0.92)
			stave.CFrame = body.CFrame * CFrame.Angles(angle, 0, 0) * CFrame.new(0, radius + 0.003, 0)
			stave.Material = Enum.Material.Wood
			stave:SetAttribute("Shade", (index % 4 == 0) and 0.08 or -0.1)
			Utility.makeDecor(stave)
			stave.Parent = folder
		end
	end
	-- 통 양 끝의 얇은 쇠테 (chime hoop)
	for _, x in ipairs({ -0.46, 0.46 }) do
		local chime = Instance.new("Part")
		chime.Name = "ChimeHoop"
		chime.Shape = Enum.PartType.Cylinder
		chime.Size = Vector3.new(0.14, body.Size.Y * 1.025, body.Size.Z * 1.025)
		chime.CFrame = body.CFrame * CFrame.new(length * x, 0, 0)
		chime.Material = Enum.Material.Metal
		Utility.makeDecor(chime)
		chime.Parent = folder
	end
	for _, hoop in ipairs({ parts.hoopLower, parts.hoopUpper }) do
		if hoop and hoop:IsA("Part") and hoop.Shape == Enum.PartType.Cylinder then
			local hoopRadius = hoop.Size.Y * 0.5
			for index = 1, 10 do
				local angle = index / 10 * math.pi * 2
				local rivet = Instance.new("Part")
				rivet.Name = "Rivet"
				rivet.Shape = Enum.PartType.Ball
				rivet.Size = Vector3.new(0.16, 0.16, 0.16)
				rivet.CFrame = hoop.CFrame * CFrame.Angles(angle, 0, 0) * CFrame.new(0, hoopRadius, 0)
				rivet.Material = Enum.Material.Metal
				Utility.makeDecor(rivet)
				rivet.Parent = folder
			end
		end
	end
	folder.Parent = parts.model
end

-- 지금 앉아 있는 사람들 중에서 이 테이블의 통 스킨을 고른다.
function GameTable:RefreshBarrelSkin()
	if self.destroyed or not self.model then
		return
	end

	local bestPlayer, bestSkin, bestScore = nil, nil, -1

	for _, player in ipairs(self:GetPlayers()) do
		-- AI 선원은 통 스킨을 고르지 않는다. (사람의 통이 보여야 한다)
		local skin = (not GameConfig.isBot(player)) and GameConfig.findSkin("Barrel", player:GetAttribute(SKIN_ATTR.Barrel)) or nil
		if skin then
			local level = player:GetAttribute(PLAYER_ATTR.Level) or GameConfig.levelOf(0, 0)
			local streak = player:GetAttribute(PLAYER_ATTR.Streak) or 0
			local score = GameConfig.barrelSkinScore(skin, level, streak, self.seatOrder[player] or 99)
			if score > bestScore then
				bestPlayer, bestSkin, bestScore = player, skin, score
			end
		end
	end

	if not bestSkin then
		bestSkin = GameConfig.Skins.Barrel[1]
	end

	if self.barrelSkin and self.barrelSkin.id == bestSkin.id then
		-- 같은 스킨이면 주인 표시만 갱신한다
		self:SetTableAttribute(TABLE_ATTR.BarrelSkinOwnerId, bestPlayer and bestPlayer.UserId or 0)
		self:SetTableAttribute(TABLE_ATTR.BarrelSkinOwnerName, bestPlayer and (bestPlayer.DisplayName or bestPlayer.Name) or "")
		return
	end

	self:_applyBarrelSkin(bestSkin)
	self:SetTableAttribute(TABLE_ATTR.BarrelSkinOwnerId, bestPlayer and bestPlayer.UserId or 0)
	self:SetTableAttribute(TABLE_ATTR.BarrelSkinOwnerName, bestPlayer and (bestPlayer.DisplayName or bestPlayer.Name) or "")

	if bestPlayer then
		GameConfig.log(("%s 통 스킨 → %s (%s 님 것)"):format(self.tableId, bestSkin.name, bestPlayer.Name))
	end
end

--------------------------------------------------
-- 통 연출
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
		local popped = (self._lidHome + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, math.rad(24), math.rad(12))

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
		glow.Color = GameConfig.SlotLayout.DangerColor
		local light = glow:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = GameConfig.SlotLayout.DangerColor
		end

		task.delay(1.2, function()
			if glow.Parent then
				self:ResetBarrelLook()
			end
		end)
	end
end

-- 통을 원래 모습으로 되돌린다.
-- ★ "원래" 는 맵에 저장된 색이 아니라 지금 적용 중인 스킨의 색이다.
--   (Phase 5 에서는 여기서 스킨이 벗겨져 통이 참나무로 돌아가 보였다)
function GameTable:ResetBarrelLook()
	local lid = self:_findBarrelPart("Lid")
	if lid and self._lidHome then
		lid.CFrame = self._lidHome
	end

	local skin = self.barrelSkin or GameConfig.Skins.Barrel[1]
	local glow = self:_findBarrelPart("Glow")
	if glow then
		glow.Color = skin.glow
		local light = glow:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = skin.glow
		end
	end
end

--------------------------------------------------
-- 상태 / 좌석 표시
--------------------------------------------------

function GameTable:SetTableAttribute(name, value)
	if self.destroyed or not self.model then
		return false
	end
	self.model:SetAttribute(name, value)
	return true
end

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

function GameTable:RemovePlayer(player)
	local seat = self.seatOfPlayer[player]
	if not seat then
		return false
	end

	local humanoid = seat.Occupant
	if humanoid and (Players:GetPlayerFromCharacter(humanoid.Parent) == player
		or (GameConfig.isBot(player) and humanoid.Parent == player.Character)) then
		humanoid.Sit = false
	end

	self:_unseat(player, seat)
	return true
end

function GameTable:HandlePlayerRemoving(player)
	self.promptLimiter:forget(player.UserId)
	self:RemovePlayer(player)
	if playerTables[player] == self then
		playerTables[player] = nil
	end
end

return GameTable
