--[[
	TableController
	테이블 위에 떠 있는 현황판(0/4, 1/4 ...)을 그린다.

	위치: StarterPlayer > StarterPlayerScripts > Controllers > TableController  (LocalScript)

	서버는 테이블 모델의 Attribute 만 바꾸고, 클라이언트는 그 값을 읽어 UI 를 만든다.
	→ RemoteEvent 가 필요 없고, UI 연산은 각자 기기에서만 일어난다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local TableConfig = require(Shared.TableConfig)
local Utility = require(Shared.Utility)

local TABLE_TAG = GameConfig.Tags.Table
local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

--------------------------------------------------
-- 색상 팔레트 (해적 선술집: 어두운 나무 + 금색 포인트)
--------------------------------------------------
local PALETTE = {
	Wood = Color3.fromRGB(38, 25, 18),
	WoodLight = Color3.fromRGB(74, 49, 32),
	Gold = Color3.fromRGB(226, 178, 86),
	Cream = Color3.fromRGB(238, 223, 196),
	Ready = Color3.fromRGB(131, 209, 144),
	Mine = Color3.fromRGB(255, 214, 122),
}

local COUNT_SIZE = UDim2.fromScale(1, 0.44)
local COUNT_POP = UDim2.fromScale(1.14, 0.52)
local POP_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Phase 2 이후 상태에서 보여줄 문구
local STATE_TEXT = {
	[GameConfig.States.Countdown] = "곧 시작합니다",
	[GameConfig.States.Starting] = "게임 시작!",
	[GameConfig.States.Playing] = "게임 진행 중",
	[GameConfig.States.RoundEnding] = "라운드 종료",
	[GameConfig.States.Resetting] = "정리하는 중...",
}

local boards = {} -- [Model] = entry

--------------------------------------------------
-- UI 만들기
--------------------------------------------------

local function createLabel(parent, name, size, position, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = PALETTE.Cream
	label.Text = ""
	label.Parent = parent

	-- TextScaled 가 너무 커지지 않도록 상한을 둔다
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize
	constraint.Parent = label

	return label
end

local function buildBoard(adornee)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CursedBarrel_TableBoard"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromScale(7.2, 3.4) -- 스터드 기준 크기
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = PALETTE.Wood
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.16, 0)
	corner.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(PALETTE.WoodLight, PALETTE.Wood)
	gradient.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Edge"
	stroke.Color = PALETTE.Gold
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = frame

	local title = createLabel(frame, "Title", UDim2.fromScale(0.92, 0.22), UDim2.fromScale(0.5, 0.16), 22)
	title.Font = Enum.Font.GothamMedium
	title.TextColor3 = PALETTE.Gold
	title.TextTransparency = 0.1

	local count = createLabel(frame, "Count", COUNT_SIZE, UDim2.fromScale(0.5, 0.5), 54)
	count.Font = Enum.Font.GothamBlack

	local status = createLabel(frame, "Status", UDim2.fromScale(0.92, 0.2), UDim2.fromScale(0.5, 0.85), 20)
	status.Font = Enum.Font.GothamMedium

	return {
		billboard = billboard,
		frame = frame,
		stroke = stroke,
		title = title,
		count = count,
		status = status,
	}
end

--------------------------------------------------
-- 갱신
--------------------------------------------------

local function isLocalPlayerSeated(entry)
	for _, seat in ipairs(entry.seats) do
		if seat:GetAttribute(SEAT_ATTR.OccupantUserId) == localPlayer.UserId then
			return true
		end
	end
	return false
end

local function updateBoard(entry)
	local model = entry.model
	if not model or not model.Parent then
		return
	end

	local seated = model:GetAttribute(TABLE_ATTR.SeatedCount) or 0
	local capacity = model:GetAttribute(TABLE_ATTR.SeatCount) or 0
	local minPlayers = model:GetAttribute(TABLE_ATTR.MinPlayers) or 2
	local state = model:GetAttribute(TABLE_ATTR.State) or GameConfig.States.Waiting

	local preset = TableConfig.get(model:GetAttribute(TABLE_ATTR.TableType))
	entry.title.Text = preset.DisplayName
	entry.count.Text = ("%d / %d"):format(seated, capacity)

	-- 상황 문구: 글자를 늘리지 않고 색으로도 구분해 준다
	local statusText, statusColor
	if STATE_TEXT[state] then
		statusText, statusColor = STATE_TEXT[state], PALETTE.Gold
	elseif seated == 0 then
		statusText, statusColor = "빈 테이블 · 앉으면 참가", PALETTE.Cream
	elseif seated < minPlayers then
		statusText, statusColor = ("%d명 더 필요"):format(minPlayers - seated), PALETTE.Cream
	else
		statusText, statusColor = "시작 준비 완료", PALETTE.Ready
	end

	entry.status.Text = statusText
	entry.status.TextColor3 = statusColor

	-- 내가 앉아 있는 테이블은 테두리를 금색으로 밝혀 구분한다
	local mine = isLocalPlayerSeated(entry)
	if entry.mine ~= mine then
		entry.mine = mine
		TweenService:Create(entry.stroke, FADE_TWEEN, {
			Thickness = mine and 3.5 or 2,
			Transparency = mine and 0 or 0.3,
			Color = mine and PALETTE.Mine or PALETTE.Gold,
		}):Play()
	end

	-- 인원이 바뀌면 숫자가 살짝 튀어오른다
	if entry.lastCount ~= seated then
		entry.lastCount = seated
		entry.count.Size = COUNT_POP
		TweenService:Create(entry.count, POP_TWEEN, { Size = COUNT_SIZE }):Play()
	end
end

--------------------------------------------------
-- 테이블 등록 / 해제
--------------------------------------------------

local function findAdornee(model)
	return model:FindFirstChild("StatusAnchor", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function registerTable(model)
	if boards[model] then
		return
	end

	local adornee = findAdornee(model)
	if not adornee then
		warn(("[CursedBarrel] '%s' 에 현황판을 붙일 Part 가 없습니다."):format(model:GetFullName()))
		return
	end

	local entry = buildBoard(adornee)
	entry.model = model
	entry.seats = {}
	entry.cleaner = Utility.Cleaner.new()
	entry.cleaner:add(entry.billboard)

	boards[model] = entry

	-- 테이블 Attribute 변화 구독
	for _, attributeName in ipairs({
		TABLE_ATTR.TableId,
		TABLE_ATTR.SeatCount,
		TABLE_ATTR.SeatedCount,
		TABLE_ATTR.MinPlayers,
		TABLE_ATTR.State,
	}) do
		entry.cleaner:add(model:GetAttributeChangedSignal(attributeName):Connect(function()
			updateBoard(entry)
		end))
	end

	-- 좌석 점유 변화 구독 (내가 앉은 테이블 강조용)
	local seatsFolder = model:FindFirstChild("Seats")
	if seatsFolder then
		for _, descendant in ipairs(seatsFolder:GetDescendants()) do
			if descendant:IsA("Seat") then
				table.insert(entry.seats, descendant)
				entry.cleaner:add(descendant:GetAttributeChangedSignal(SEAT_ATTR.OccupantUserId):Connect(function()
					updateBoard(entry)
				end))
			end
		end
	end

	updateBoard(entry)
end

local function unregisterTable(model)
	local entry = boards[model]
	if not entry then
		return
	end

	boards[model] = nil
	entry.cleaner:clean()
end

--------------------------------------------------
-- 시작
--------------------------------------------------

for _, model in ipairs(CollectionService:GetTagged(TABLE_TAG)) do
	registerTable(model)
end

CollectionService:GetInstanceAddedSignal(TABLE_TAG):Connect(registerTable)
CollectionService:GetInstanceRemovedSignal(TABLE_TAG):Connect(unregisterTable)
