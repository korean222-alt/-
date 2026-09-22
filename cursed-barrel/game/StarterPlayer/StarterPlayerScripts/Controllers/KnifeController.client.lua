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

	Phase 8 에서 더해진 것 — 방해 아이템이 이 패널에 걸린다.
	  흔들리는 손 : 버튼이 좌우로 흔들린다. 누르는 것은 여전히 가능하다.
	  뒤섞인 번호 : 버튼 위 숫자만 뒤섞인다.
	                ★ 누른 "버튼"의 자리에 정확히 꽂힌다. 숫자만 거짓말을 한다.
	                  (요청을 바꿔치기하지 않는다. 그건 조작이지 방해가 아니다)

	Phase 10 에서 더해진 것
	  · "한 번 더!" 버튼 : 안전한 자리를 뽑은 뒤 잠깐 뜬다. 누르면 같은 차례에 한 번 더 찌른다. (F · 게임패드 X)
	  · 파티 카드 버튼 : H 테이블에서 넘기기 · 회전 · 봉인을 이 패널에서 바로 쓴다.
	                     봉인은 버튼을 누른 뒤 봉인할 자리 번호를 누른다.
	  · 이번 판의 잡기 기회를 이미 썼으면 머리글이 붉게 경고한다.
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
local sabotageCue = Remotes:WaitForChild(GameConfig.Remotes.SabotageCue)
local GuiService = game:GetService("GuiService")
local SEAT_ATTR = GameConfig.SeatAttributes

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

-- Phase 5: 패널이 화면 아래 3분의 1을 덮고 있어서 카메라가 그만큼 물러나야 했다.
-- 칸을 줄이고 한 줄에 더 많이 넣어 패널 높이를 절반 가까이 낮춘다.
local CELL = 42
local CELL_PADDING = 5
local MAX_COLUMNS = 10

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
panel.Position = UDim2.new(0.5, 0, 1, UserInputService.TouchEnabled and -104 or -16)
panel.Size = UDim2.new(0, 460, 0, 132)
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
panelPadding.PaddingTop = UDim.new(0, 8)
panelPadding.PaddingBottom = UDim.new(0, 8)
panelPadding.PaddingLeft = UDim.new(0, 12)
panelPadding.PaddingRight = UDim.new(0, 12)
panelPadding.Parent = panel

local header = Instance.new("TextLabel")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 20)
header.Font = Enum.Font.GothamBold
header.Text = "칼을 꽂을 자리를 고르세요"
header.TextColor3 = PALETTE.Gold
header.TextSize = 16
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
timerLabel.TextSize = 16
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
timerLabel.Parent = panel

local timerTrack = Instance.new("Frame")
timerTrack.Name = "TimerTrack"
timerTrack.Position = UDim2.new(0, 0, 0, 25)
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
grid.Position = UDim2.new(0, 0, 0, 35)
grid.Size = UDim2.new(1, 0, 1, -52)
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
-- Phase 10 : 패널 위에 붙는 동작 줄 ("한 번 더!" · 파티 카드)
--------------------------------------------------

local actions = Instance.new("Frame")
actions.Name = "Actions"
actions.AnchorPoint = Vector2.new(0.5, 1)
actions.Position = UDim2.new(0.5, 0, 0, -16)
actions.Size = UDim2.new(1, 0, 0, 40)
actions.BackgroundTransparency = 1
actions.Parent = panel

local actionsLayout = Instance.new("UIListLayout")
actionsLayout.FillDirection = Enum.FillDirection.Horizontal
actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
actionsLayout.Padding = UDim.new(0, 6)
actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionsLayout.Parent = actions

local function actionButton(name, text, width, color, order)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(width, 36)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 15
	button.TextColor3 = PALETTE.Cream
	button.Text = text
	button.LayoutOrder = order
	button.Visible = false
	button.Selectable = true
	button.Parent = actions
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = PALETTE.Gold
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	return button
end

local braveButton = actionButton("Brave", "한 번 더!", 230, Color3.fromRGB(150, 60, 34), 1)
local braveFill = Instance.new("Frame")
braveFill.Name = "Time"
braveFill.AnchorPoint = Vector2.new(0, 1)
braveFill.Position = UDim2.fromScale(0, 1)
braveFill.Size = UDim2.new(1, 0, 0, 4)
braveFill.BackgroundColor3 = PALETTE.Gold
braveFill.BorderSizePixel = 0
braveFill.Parent = braveButton

local cardButtons = {
	skip = actionButton("CardSkip", "넘기기", 84, Color3.fromRGB(58, 52, 96), 2),
	rotate = actionButton("CardRotate", "통 회전", 84, Color3.fromRGB(58, 52, 96), 3),
	seal = actionButton("CardSeal", "봉인", 84, Color3.fromRGB(58, 52, 96), 4),
}
local CARD_ATTR = { skip = "CardSkip", rotate = "CardRotate", seal = "CardSeal" }

--------------------------------------------------
-- 상태
--------------------------------------------------

local currentModel = nil -- 내가 앉아 있는 테이블 모델
local buttons = {} -- [슬롯번호] = TextButton
local slotParts = {} -- [슬롯번호] = Part
local tableCleaner = Utility.Cleaner.new()
local toastToken = 0

-- Phase 10 : 봉인 카드를 누른 뒤 "봉인할 자리"를 고르는 중인가
local sealMode = false

-- Phase 8 : 방해 아이템 상태
local shakeUntil = 0 -- 이 시각까지 버튼이 흔들린다
local scrambleUntil = 0 -- 이 시각까지 숫자가 뒤섞인다
local scrambleMap = {} -- [진짜 번호] = 화면에 보여줄 번호
local shaken = false -- 지난 프레임에 흔들리고 있었는가 (한 번만 되돌리려고)

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

local function useCard(card, slotIndex)
	local remote = Remotes:FindFirstChild("VoyageRequest")
	if not currentModel or not remote then
		return
	end
	-- 판 번호와 차례 번호를 같이 보낸다. 서버는 지난 차례에 눌린 요청을 거절한다.
	remote:FireServer("card", currentModel, card, slotIndex,
		currentModel:GetAttribute(TABLE_ATTR.RoundId), currentModel:GetAttribute("TurnSerial"))
end

local function requestSlot(slotIndex)
	if not currentModel then
		return
	end
	if sealMode then
		-- 봉인 카드: 이 자리를 봉인한다. 칼을 꽂는 것이 아니다.
		sealMode = false
		useCard("seal", slotIndex)
		return
	end
	-- 요청만 보낸다. 통과/거절은 서버가 정하고, 결과는 OnClientEvent 로 돌아온다.
	selectSlotRemote:FireServer(currentModel, slotIndex)
end

local function availableColumns()
	local camera=workspace.CurrentCamera
	local width=camera and camera.ViewportSize.X or 800
	return math.clamp(math.floor((width-40)/(CELL+CELL_PADDING)),3,MAX_COLUMNS)
end
local function buildButtons(count)
	gridLayout.FillDirectionMaxCells = availableColumns()
	clearButtons()

	local columns = math.min(availableColumns(), math.max(1, count))
	local rows = math.ceil(count / columns)
	local width = columns * CELL + (columns - 1) * CELL_PADDING + 24
	panel.Size = UDim2.new(0, math.max(280, width), 0, 50 + rows * CELL + (rows - 1) * CELL_PADDING + 18)

	for index = 1, count do
		local button = Instance.new("TextButton")
		button.Name = ("Slot_%02d"):format(index)
		button.LayoutOrder = index
		button.Text = tostring(index)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 16
		button.TextColor3 = PALETTE.Cream
		button.BackgroundColor3 = PALETTE.WoodLight
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
        button.Selectable=true
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

	local sealed=slot and slot:GetAttribute("Sealed")==true
    button.Active = not used and not sealed
	button.AutoButtonColor = not used and not sealed
	button.BackgroundColor3 = used and PALETTE.Used or PALETTE.WoodLight
	button.TextColor3 = used and PALETTE.Dim or PALETTE.Cream
	button.TextTransparency = used and 0.35 or 0

	-- 뒤섞인 번호를 맞고 있으면 숫자만 다른 것을 보여준다. 누르는 자리는 그대로다.
	local shown = (os.clock() < scrambleUntil) and (scrambleMap[index] or index) or index
	button.Text = used and ("× "..shown) or (sealed and ("◆ "..shown) or ("○ "..shown))
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
			prompt.Enabled = enabled and not used and slot:GetAttribute("Sealed")~=true
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

-- 이 테이블에서 내 좌석
local function mySeat()
	local seats = currentModel and currentModel:FindFirstChild("Seats")
	if not seats then
		return nil
	end
	for _, seat in ipairs(seats:GetDescendants()) do
		if seat:IsA("Seat") and seat:GetAttribute(SEAT_ATTR.OccupantUserId) == localPlayer.UserId then
			return seat
		end
	end
	return nil
end

-- "한 번 더" 제안이 지금 나에게 와 있는가
local function braveOffered()
	if not currentModel or currentModel:GetAttribute(TABLE_ATTR.BraveOfferUserId) ~= localPlayer.UserId then
		return false
	end
	return (currentModel:GetAttribute(TABLE_ATTR.BraveOfferEndsAt) or 0) > GameConfig.now()
end

local function refreshActions(myTurn)
	local offered = myTurn == true and braveOffered()
	braveButton.Visible = offered
	if offered then
		local reward = currentModel:GetAttribute(TABLE_ATTR.BraveNextReward) or 0
		local keyHint = UserInputService.GamepadEnabled and "X" or (UserInputService.KeyboardEnabled and "F" or "")
		braveButton.Text = ("한 번 더!  +%d 코인%s"):format(reward, keyHint ~= "" and ("  (" .. keyHint .. ")") or "")
	end

	-- 파티 카드는 내 차례이고 아직 고르기 전(제한 시간이 흐르는 중)에만 쓸 수 있다.
	local preset = currentModel and TableConfig.get(currentModel:GetAttribute(TABLE_ATTR.TableType))
	local choosing = myTurn and not offered and (currentModel:GetAttribute(TABLE_ATTR.TurnEndsAt) or 0) > 0
	local cardsOn = choosing and preset ~= nil and preset.SpecialCards == true
	for card, button in pairs(cardButtons) do
		local ready = cardsOn == true and currentModel:GetAttribute(CARD_ATTR[card]) == true
		button.Visible = cardsOn == true
		button.Active = ready
		button.AutoButtonColor = ready
		button.TextTransparency = ready and 0 or 0.55
		if card == "seal" then
			button.Text = sealMode and "봉인 취소" or "봉인"
		end
	end
	if not cardsOn then
		sealMode = false
	end
end

local function refresh()
	local myTurn = isMyTurn()
	if myTurn and not gui.Enabled and UserInputService.GamepadEnabled then
		for i, b in ipairs(buttons) do
			if not (slotParts[i] and slotParts[i]:GetAttribute(SLOT_ATTR.Used)) then
				GuiService.SelectedObject = b
				break
			end
		end
	end
	gui.Enabled = myTurn

	if currentModel then
		setPromptsEnabled(currentModel, myTurn)
	end
	hideOtherTablePrompts()
	refreshActions(myTurn)

	if not myTurn then
		sealMode = false
		return
	end

	refreshAllButtons()

	if sealMode then
		header.Text = "봉인할 자리를 누르세요 · 다음 사람은 그 자리를 고를 수 없습니다"
		header.TextColor3 = Color3.fromRGB(196, 150, 255)
		return
	end

	local slotsLeft = currentModel:GetAttribute(TABLE_ATTR.SlotsRemaining) or 0
	local pirates = currentModel:GetAttribute(TABLE_ATTR.PirateCount) or 0
	-- 몇 마리가 숨어 있는지만 보여준다. 어느 자리인지는 서버만 안다.
	local pirateText = (pirates > 0) and ("  ·  해적 %d마리"):format(pirates) or ""
	local seat = mySeat()
	local noChance = seat ~= nil and (seat:GetAttribute(SEAT_ATTR.CatchesLeft) or 1) <= 0
	if noChance then
		-- 이번 판의 잡기 기회를 이미 썼다. 해적을 만나면 바로 탈락이다.
		header.Text = ("⚠ 잡기 기회 없음 · 해적을 만나면 탈락 · 남은 자리 %d%s"):format(slotsLeft, pirateText)
		header.TextColor3 = PALETTE.Danger
	else
		local brave = currentModel:GetAttribute(TABLE_ATTR.BraveLevel) or 0
		local braveText = brave > 0 and ("  ·  배짱 %d단계"):format(brave) or ""
		header.Text = ("칼을 꽂을 자리를 고르세요 · 남은 자리 %d%s%s"):format(slotsLeft, pirateText, braveText)
		header.TextColor3 = PALETTE.Gold
	end
end

local function requestBrave()
	if currentModel and braveOffered() then
		local remote = Remotes:FindFirstChild(GameConfig.Remotes.Brave)
		if remote then
			remote:FireServer(currentModel)
		end
		braveButton.Visible = false
	end
end

braveButton.Activated:Connect(requestBrave)
for card, button in pairs(cardButtons) do
	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		if card == "seal" then
			sealMode = not sealMode
			refresh()
			return
		end
		sealMode = false
		useCard(card, nil)
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
		requestBrave()
	end
end)

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

				tableCleaner:add(slot:GetAttributeChangedSignal("Sealed"):Connect(function() refreshButton(index) end))
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
		TABLE_ATTR.PirateCount,
		-- Phase 10
		TABLE_ATTR.TurnEndsAt,
		TABLE_ATTR.BraveOfferUserId,
		TABLE_ATTR.BraveOfferEndsAt,
		TABLE_ATTR.BraveNextReward,
		TABLE_ATTR.BraveLevel,
		"CardSkip",
		"CardRotate",
		"CardSeal",
		"TurnSerial",
	}) do
		tableCleaner:add(model:GetAttributeChangedSignal(attributeName):Connect(refresh))
	end

	-- 내 좌석의 남은 잡기 기회가 바뀌면 머리글을 다시 그린다.
	local seatsFolder = model:FindFirstChild("Seats")
	if seatsFolder then
		for _, seat in ipairs(seatsFolder:GetDescendants()) do
			if seat:IsA("Seat") then
				tableCleaner:add(seat:GetAttributeChangedSignal(SEAT_ATTR.CatchesLeft):Connect(refresh))
			end
		end
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

	-- "한 번 더" 제안이 남은 시간을 줄여 보여 주고, 끝나면 버튼을 거둔다.
	if braveButton.Visible then
		local offerEnds = currentModel:GetAttribute(TABLE_ATTR.BraveOfferEndsAt) or 0
		local left = offerEnds - GameConfig.now()
		if left <= 0 then
			braveButton.Visible = false
		else
			braveFill.Size = UDim2.new(math.clamp(left / GameConfig.Timing.ResultHold, 0, 1), 0, 0, 4)
		end
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
-- Screen orientation changes rebuild only layout; input connections stay intact.
local lastWidth = 0
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 800
	if width == lastWidth then return end
	lastWidth = width
	local count = #buttons
	if count == 0 then return end
	local columns = math.min(availableColumns(), count)
	gridLayout.FillDirectionMaxCells = columns
	local rows = math.ceil(count / columns)
	panel.Size = UDim2.fromOffset(math.max(220, columns*CELL+(columns-1)*CELL_PADDING+24), 68+rows*CELL+(rows-1)*CELL_PADDING)
end)

--------------------------------------------------
-- Phase 8 : 방해 아이템이 이 패널에 걸린다
--
-- 어느 쪽도 "내가 누른 자리"를 바꾸지 않는다.
-- 흔들림은 버튼의 화면 위치만, 뒤섞기는 버튼에 적힌 숫자만 건드린다.
--------------------------------------------------

local function beginScramble(duration)
	local order = {}
	for index in pairs(buttons) do
		table.insert(order, index)
	end
	table.sort(order)

	local shuffled = table.clone(order)
	Utility.shuffle(shuffled)

	table.clear(scrambleMap)
	for position, index in ipairs(order) do
		scrambleMap[index] = shuffled[position]
	end

	scrambleUntil = os.clock() + (duration or 9)
	refreshAllButtons()
end

sabotageCue.OnClientEvent:Connect(function(_, data)
	if typeof(data) ~= "table" or not data.mine then
		return
	end
	if data.id == "shake" then
		shakeUntil = os.clock() + (data.duration or 7)
		showToast("손이 흔들린다! 자리를 잘 노려보세요", PALETTE.Danger)
	elseif data.id == "scramble" then
		beginScramble(data.duration)
		showToast("번호가 뒤섞였다! 누른 자리에 그대로 꽂힙니다", PALETTE.Danger)
	end
end)

-- 흔들림과 뒤섞임은 매 프레임 그린다. 둘 다 안 걸려 있으면 아무 일도 하지 않는다.
--
-- ★ 버튼 하나하나의 Position 은 건드릴 수 없다. UIGridLayout 이 매 프레임 되돌린다.
--   그래서 격자 전체를 흔들고, 버튼은 Rotation 으로 따로 기울인다.
--   (Rotation 은 레이아웃이 건드리지 않는다)
local gridHome = grid.Position

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local shaking = now < shakeUntil

	if shaking then
		local strength = math.clamp((shakeUntil - now) / 1.5, 0.35, 1) * 8
		grid.Position = gridHome + UDim2.fromOffset(
			math.sin(now * 19) * strength,
			math.cos(now * 14) * strength * 0.5
		)
		for index, button in pairs(buttons) do
			button.Rotation = math.sin(now * 16 + index * 1.7) * strength * 0.9
		end
	elseif shaken then
		grid.Position = gridHome
		for _, button in pairs(buttons) do
			button.Rotation = 0
		end
	end
	shaken = shaking

	-- 뒤섞임이 끝나면 숫자를 되돌린다
	if next(scrambleMap) and now >= scrambleUntil then
		table.clear(scrambleMap)
		refreshAllButtons()
	end
end)
