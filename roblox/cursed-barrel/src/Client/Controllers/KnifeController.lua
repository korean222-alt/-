--[[
	KnifeController  (Phase 3)
	"내 차례일 때 자리를 고르는" 화면 UI.

	위치: StarterPlayer > StarterPlayerScripts > Controllers > KnifeController  (LocalScript)

	입력은 두 가지가 있고 둘 다 같은 서버 검사를 통과한다.
	  1. 통에 붙은 ProximityPrompt  : PC 는 E, 모바일은 화면의 버튼을 탭
	  2. 화면 아래 자리 버튼 (이 파일) : PC 는 클릭, 모바일은 탭
	     → RemoteEvent 로 (내 테이블 모델, 자리 번호) 를 보낸다.

	이 파일이 하는 일은 "보여주기"와 "요청 보내기"뿐이다.
	  - 어느 자리가 위험한지는 클라이언트가 알 방법이 없다 (서버 메모리에만 있다)
	  - 내 차례인지, 그 자리가 비었는지도 서버가 다시 검사한다
	  - 여기서 버튼을 숨기는 것은 편의일 뿐, 보안은 서버가 담당한다

	또 하나: 내 차례가 아닐 때는 통의 프롬프트를 "내 화면에서만" 숨긴다.
	(프롬프트 Enabled 를 클라이언트가 바꿔도 다른 사람 화면에는 영향이 없다)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TableConfig = require(Shared:WaitForChild("TableConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local Remotes = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild(GameConfig.Remotes.Folder)
local selectSlotRemote = Remotes:WaitForChild(GameConfig.Remotes.SelectSlot)

local TABLE_TAG = GameConfig.Tags.Table
local TABLE_ATTR = GameConfig.TableAttributes
local SLOT_ATTR = GameConfig.SlotAttributes
local STATES = GameConfig.States

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local PALETTE = {
	Wood = Color3.fromRGB(32, 22, 16),
	WoodLight = Color3.fromRGB(70, 47, 31),
	Gold = Color3.fromRGB(226, 178, 86),
	Cream = Color3.fromRGB(238, 223, 196),
	Ready = Color3.fromRGB(131, 209, 144),
	Danger = Color3.fromRGB(226, 122, 106),
	Used = Color3.fromRGB(58, 48, 40),
	Dim = Color3.fromRGB(150, 138, 118),
}

local CELL = 52
local CELL_PADDING = 6
local MAX_COLUMNS = 8

--------------------------------------------------
-- UI 만들기 (한 번만 만들고 계속 재사용한다)
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_KnifePicker"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 8
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 1)
-- 모바일은 아래쪽에 점프 버튼이 있으므로 조금 더 띄운다.
panel.Position = UDim2.new(0.5, 0, 1, UserInputService.TouchEnabled and -112 or -20)
panel.Size = UDim2.new(0, 480, 0, 168)
panel.BackgroundColor3 = PALETTE.Wood
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = PALETTE.Gold
panelStroke.Thickness = 2
panelStroke.Transparency = 0.25
panelStroke.Parent = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingTop = UDim.new(0, 10)
panelPadding.PaddingBottom = UDim.new(0, 10)
panelPadding.PaddingLeft = UDim.new(0, 12)
panelPadding.PaddingRight = UDim.new(0, 12)
panelPadding.Parent = panel

local header = Instance.new("TextLabel")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 22)
header.Font = Enum.Font.GothamBold
header.Text = "칼을 꽂을 자리를 고르세요"
header.TextColor3 = PALETTE.Gold
header.TextSize = 18
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = panel

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.BackgroundTransparency = 1
timerLabel.Size = UDim2.new(0, 120, 0, 22)
timerLabel.Position = UDim2.new(1, -120, 0, 0)
timerLabel.Font = Enum.Font.GothamBlack
timerLabel.Text = ""
timerLabel.TextColor3 = PALETTE.Cream
timerLabel.TextSize = 18
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
timerLabel.Parent = panel

local timerTrack = Instance.new("Frame")
timerTrack.Name = "TimerTrack"
timerTrack.Position = UDim2.new(0, 0, 0, 28)
timerTrack.Size = UDim2.new(1, 0, 0, 5)
timerTrack.BackgroundColor3 = PALETTE.WoodLight
timerTrack.BorderSizePixel = 0
timerTrack.Parent = panel

local timerTrackCorner = Instance.new("UICorner")
timerTrackCorner.CornerRadius = UDim.new(1, 0)
timerTrackCorner.Parent = timerTrack

local timerFill = Instance.new("Frame")
timerFill.Name = "Fill"
timerFill.Size = UDim2.fromScale(1, 1)
timerFill.BackgroundColor3 = PALETTE.Ready
timerFill.BorderSizePixel = 0
timerFill.Parent = timerTrack

local timerFillCorner = Instance.new("UICorner")
timerFillCorner.CornerRadius = UDim.new(1, 0)
timerFillCorner.Parent = timerFill

local grid = Instance.new("Frame")
grid.Name = "Grid"
grid.BackgroundTransparency = 1
grid.Position = UDim2.new(0, 0, 0, 40)
grid.Size = UDim2.new(1, 0, 1, -62)
grid.Parent = panel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(CELL, CELL)
gridLayout.CellPadding = UDim2.fromOffset(CELL_PADDING, CELL_PADDING)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.Parent = grid

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, 0)
toast.Size = UDim2.new(1, 0, 0, 18)
toast.BackgroundTransparency = 1
toast.Font = Enum.Font.GothamMedium
toast.Text = ""
toast.TextColor3 = PALETTE.Danger
toast.TextSize = 15
toast.Parent = panel

--------------------------------------------------
-- 상태
--------------------------------------------------

local currentModel = nil -- 내가 앉아 있는 테이블 모델
local buttons = {} -- [슬롯번호] = TextButton
local slotParts = {} -- [슬롯번호] = Part
local tableCleaner = Utility.Cleaner.new()
local toastToken = 0

local function showToast(message, color)
	toast.Text = message or ""
	toast.TextColor3 = color or PALETTE.Danger
	toast.TextTransparency = 0

	toastToken += 1
	local token = toastToken
	task.delay(2.4, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

--------------------------------------------------
-- 버튼 만들기 / 상태 반영
--------------------------------------------------

local function clearButtons()
	for _, button in pairs(buttons) do
		button:Destroy()
	end
	table.clear(buttons)
end

local function requestSlot(slotIndex)
	if not currentModel then
		return
	end
	-- 요청만 보낸다. 통과/거절은 서버가 정하고, 결과는 OnClientEvent 로 돌아온다.
	selectSlotRemote:FireServer(currentModel, slotIndex)
end

local function buildButtons(count)
	clearButtons()

	local columns = math.min(MAX_COLUMNS, math.max(1, count))
	local rows = math.ceil(count / columns)
	local width = columns * CELL + (columns - 1) * CELL_PADDING + 24
	panel.Size = UDim2.new(0, math.max(300, width), 0, 62 + rows * CELL + (rows - 1) * CELL_PADDING + 22)

	for index = 1, count do
		local button = Instance.new("TextButton")
		button.Name = ("Slot_%02d"):format(index)
		button.LayoutOrder = index
		button.Text = tostring(index)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 18
		button.TextColor3 = PALETTE.Cream
		button.BackgroundColor3 = PALETTE.WoodLight
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Parent = grid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Color = PALETTE.Gold
		stroke.Thickness = 1
		stroke.Transparency = 0.6
		stroke.Parent = button

		-- 클릭(PC)과 탭(모바일)이 모두 이 신호로 들어온다.
		button.Activated:Connect(function()
			requestSlot(index)
		end)

		buttons[index] = button
	end
end

-- 슬롯 하나의 버튼 모습을 서버 Attribute 에 맞춘다.
local function refreshButton(index)
	local button = buttons[index]
	if not button then
		return
	end

	local slot = slotParts[index]
	local used = slot and slot:GetAttribute(SLOT_ATTR.Used) == true

	button.Active = not used
	button.AutoButtonColor = not used
	button.BackgroundColor3 = used and PALETTE.Used or PALETTE.WoodLight
	button.TextColor3 = used and PALETTE.Dim or PALETTE.Cream
	button.TextTransparency = used and 0.35 or 0
end

local function refreshAllButtons()
	for index in pairs(buttons) do
		refreshButton(index)
	end
end

--------------------------------------------------
-- 통 프롬프트를 내 화면에서만 켜고 끈다
--------------------------------------------------

local function setPromptsEnabled(model, enabled)
	local folder = model and model:FindFirstChild(GameConfig.SlotLayout.FolderName)
	if not folder then
		return
	end

	for _, slot in ipairs(folder:GetChildren()) do
		local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local used = slot:GetAttribute(SLOT_ATTR.Used) == true
			prompt.Enabled = enabled and not used
		end
	end
end

-- 내가 앉지 않은 테이블의 프롬프트는 내 화면에서 항상 숨긴다.
-- (서버가 상태를 바꿀 때 다시 켜지므로 주기적으로 다시 적용한다)
local function hideOtherTablePrompts()
	for _, model in ipairs(CollectionService:GetTagged(TABLE_TAG)) do
		if model ~= currentModel then
			setPromptsEnabled(model, false)
		end
	end
end

--------------------------------------------------
-- 내 차례인가?
--------------------------------------------------

local function isMyTurn()
	if not currentModel or not currentModel.Parent then
		return false
	end
	if currentModel:GetAttribute(TABLE_ATTR.State) ~= STATES.Playing then
		return false
	end
	return currentModel:GetAttribute(TABLE_ATTR.CurrentTurnUserId) == localPlayer.UserId
end

local function refresh()
	local myTurn = isMyTurn()
	gui.Enabled = myTurn

	if currentModel then
		setPromptsEnabled(currentModel, myTurn)
	end
	hideOtherTablePrompts()

	if not myTurn then
		return
	end

	refreshAllButtons()

	local slotsLeft = currentModel:GetAttribute(TABLE_ATTR.SlotsRemaining) or 0
	header.Text = ("칼을 꽂을 자리를 고르세요 · 남은 자리 %d"):format(slotsLeft)
end

--------------------------------------------------
-- 테이블 붙이기 / 떼기
--------------------------------------------------

local function bindTable(model)
	if currentModel == model then
		refresh()
		return
	end

	tableCleaner:clean()
	table.clear(slotParts)
	currentModel = model

	if not model then
		clearButtons()
		refresh()
		return
	end

	local folder = model:FindFirstChild(GameConfig.SlotLayout.FolderName)
	local count = 0

	if folder then
		for _, slot in ipairs(folder:GetChildren()) do
			local index = slot:GetAttribute(SLOT_ATTR.SlotIndex)
			if index then
				slotParts[index] = slot
				count = math.max(count, index)

				tableCleaner:add(slot:GetAttributeChangedSignal(SLOT_ATTR.Used):Connect(function()
					refreshButton(index)
					if currentModel then
						setPromptsEnabled(currentModel, isMyTurn())
					end
				end))
			end
		end
	end

	buildButtons(count)

	for _, attributeName in ipairs({
		TABLE_ATTR.State,
		TABLE_ATTR.CurrentTurnUserId,
		TABLE_ATTR.SlotsRemaining,
		TABLE_ATTR.LastPickSlot,
	}) do
		tableCleaner:add(model:GetAttributeChangedSignal(attributeName):Connect(refresh))
	end

	tableCleaner:add(model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			bindTable(nil)
		end
	end))

	refresh()
end

-- 내가 앉은 좌석이 속한 테이블 모델을 위로 거슬러 올라가며 찾는다.
local function findTableFromSeat(seatPart)
	if not seatPart then
		return nil
	end

	local node = seatPart.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and CollectionService:HasTag(node, TABLE_TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

--------------------------------------------------
-- 내 캐릭터 감시
--------------------------------------------------

local characterCleaner = Utility.Cleaner.new()

local function watchCharacter(character)
	characterCleaner:clean()

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		bindTable(nil)
		return
	end

	local function onSeatChanged()
		bindTable(findTableFromSeat(humanoid.SeatPart))
	end

	characterCleaner:add(humanoid:GetPropertyChangedSignal("SeatPart"):Connect(onSeatChanged))
	characterCleaner:add(humanoid.Died:Connect(function()
		bindTable(nil)
	end))

	onSeatChanged()
end

localPlayer.CharacterAdded:Connect(watchCharacter)
localPlayer.CharacterRemoving:Connect(function()
	characterCleaner:clean()
	bindTable(nil)
end)

if localPlayer.Character then
	task.spawn(watchCharacter, localPlayer.Character)
end

--------------------------------------------------
-- 서버가 보내는 결과 / 거절 사유
--------------------------------------------------

selectSlotRemote.OnClientEvent:Connect(function(ok, payload)
	if ok then
		showToast(("%s번 자리에 칼을 꽂았습니다"):format(tostring(payload)), PALETTE.Ready)
	else
		showToast(tostring(payload), PALETTE.Danger)
	end
end)

--------------------------------------------------
-- 남은 시간 표시
--------------------------------------------------

local lastUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastUpdate < 0.05 then
		return
	end
	lastUpdate = now

	if not gui.Enabled or not currentModel or not currentModel.Parent then
		return
	end

	local endsAt = currentModel:GetAttribute(TABLE_ATTR.TurnEndsAt) or 0
	if endsAt <= 0 then
		timerLabel.Text = ""
		timerTrack.Visible = false
		return
	end

	local remaining = math.max(0, endsAt - GameConfig.now())

	timerTrack.Visible = true
	timerLabel.Text = Utility.formatSeconds(remaining)
	timerLabel.TextColor3 = remaining <= 2 and PALETTE.Danger or PALETTE.Cream

	-- 턴 전체 길이는 테이블 종류 설정값에서 읽는다.
	-- (서버가 매 초 값을 보내지 않아도 게이지가 부드럽게 줄어든다)
	local total = tonumber(TableConfig.get(currentModel:GetAttribute(TABLE_ATTR.TableType)).TurnDuration) or 0
	if total <= 0 then
		total = math.max(remaining, 1)
	end
	timerFill.Size = UDim2.fromScale(math.clamp(remaining / total, 0, 1), 1)
	timerFill.BackgroundColor3 = remaining <= 2 and PALETTE.Danger or PALETTE.Ready
end)

-- 다른 테이블 프롬프트는 서버가 상태를 바꿀 때 다시 켜질 수 있으므로 가끔 다시 정리한다.
task.spawn(function()
	while true do
		task.wait(1)
		hideOtherTablePrompts()
		if currentModel then
			setPromptsEnabled(currentModel, isMyTurn())
		end
	end
end)
