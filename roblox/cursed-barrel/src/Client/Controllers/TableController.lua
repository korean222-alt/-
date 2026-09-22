--[[
	TableController
	테이블 위에 떠 있는 현황판을 그린다.

	위치: StarterPlayer > StarterPlayerScripts > Controllers > TableController  (LocalScript)

	서버는 테이블 모델의 Attribute 만 바꾸고, 클라이언트는 그 값을 읽어 UI 를 만든다.
	→ RemoteEvent 가 필요 없고, UI 연산은 각자 기기에서만 일어난다.

	Phase 2 에서 늘어난 표시
	  - 남은 카운트다운 시간 (큰 숫자 + 게이지)
	  - 현재 차례인 플레이어 이름 / 내 차례 강조
	  - 턴 제한 시간 게이지

	Phase 3 에서 늘어난 표시
	  - 통에 남은 칼 수 (게임 중에는 이게 큰 숫자가 된다)
	  - 생존 인원 / 시작 인원
	  - 방금 누가 몇 번 자리를 골랐고 안전했는지 / 탈락했는지
	  - 승자 발표와 초기화까지 남은 시간

	현황판은 통 위쪽(StatusAnchor)에 붙는다.
	등불은 현황판보다 위에 매달려 있어서 글자를 가리지 않는다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TableConfig = require(Shared:WaitForChild("TableConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TABLE_TAG = GameConfig.Tags.Table
local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes
local STATES = GameConfig.States

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
	Danger = Color3.fromRGB(226, 122, 106),
	Dim = Color3.fromRGB(168, 152, 128),
}

local COUNT_SIZE = UDim2.fromScale(1, 0.3)
local COUNT_POP = UDim2.fromScale(1.14, 0.36)
local POP_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local STATE_TEXT = {
	[STATES.Starting] = "게임 시작!",
	[STATES.Playing] = "게임 진행 중",
	[STATES.RoundEnding] = "라운드 종료",
	[STATES.Resetting] = "정리하는 중...",
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

-- 카운트다운 / 턴 제한시간을 보여주는 가느다란 게이지
local function createTimerBar(parent)
	local track = Instance.new("Frame")
	track.Name = "TimerTrack"
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.575)
	track.Size = UDim2.fromScale(0.74, 0.055)
	track.BackgroundColor3 = PALETTE.Wood
	track.BackgroundTransparency = 0.35
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = parent

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0, 0.5)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = PALETTE.Gold
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	return track, fill
end

local function buildBoard(adornee)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CursedBarrel_TableBoard"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromScale(9.2, 4.4) -- 스터드 기준 크기 (가로만 넓혔다. 세로를 키우면 등불에 닿는다)
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
	padding.PaddingTop = UDim.new(0.05, 0)
	padding.PaddingBottom = UDim.new(0.05, 0)
	padding.Parent = frame

	local title = createLabel(frame, "Title", UDim2.fromScale(0.92, 0.15), UDim2.fromScale(0.5, 0.105), 22)
	title.Font = Enum.Font.GothamMedium
	title.TextColor3 = PALETTE.Gold
	title.TextTransparency = 0.1

	local count = createLabel(frame, "Count", COUNT_SIZE, UDim2.fromScale(0.5, 0.36), 52)
	count.Font = Enum.Font.GothamBlack

	local track, fill = createTimerBar(frame)

	local status = createLabel(frame, "Status", UDim2.fromScale(0.92, 0.14), UDim2.fromScale(0.5, 0.71), 20)
	status.Font = Enum.Font.GothamMedium

	local turn = createLabel(frame, "Turn", UDim2.fromScale(0.92, 0.13), UDim2.fromScale(0.5, 0.85), 19)
	turn.Font = Enum.Font.GothamBold
	turn.Visible = false

	local info = createLabel(frame, "Info", UDim2.fromScale(0.92, 0.11), UDim2.fromScale(0.5, 0.96), 17)
	info.Font = Enum.Font.GothamMedium
	info.TextColor3 = PALETTE.Dim

	return {
		billboard = billboard,
		frame = frame,
		stroke = stroke,
		title = title,
		count = count,
		status = status,
		turn = turn,
		info = info,
		timerTrack = track,
		timerFill = fill,
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

-- 방금 일어난 일 한 줄. (누가 몇 번 자리를 골랐고 어떻게 됐는지)
local function lastPickText(model)
	local slot = model:GetAttribute(TABLE_ATTR.LastPickSlot) or 0
	if slot == 0 then
		return nil, nil
	end

	local name = model:GetAttribute(TABLE_ATTR.LastPickName) or ""
	local safe = model:GetAttribute(TABLE_ATTR.LastPickSafe) ~= false
	local who = (model:GetAttribute(TABLE_ATTR.LastPickUserId) == localPlayer.UserId) and "나" or name

	if safe then
		return ("%s · %d번 자리 안전!"):format(who, slot), PALETTE.Ready
	end
	return ("%s · %d번 자리에서 탈락!"):format(who, slot), PALETTE.Danger
end

-- Attribute 가 바뀔 때만 부르는 "느린" 갱신
local function updateBoard(entry)
	local model = entry.model
	if not model or not model.Parent then
		return
	end

	local seated = model:GetAttribute(TABLE_ATTR.SeatedCount) or 0
	local capacity = model:GetAttribute(TABLE_ATTR.SeatCount) or 0
	local minPlayers = model:GetAttribute(TABLE_ATTR.MinPlayers) or 1
	local state = model:GetAttribute(TABLE_ATTR.State) or STATES.Waiting

	local slotCount = model:GetAttribute(TABLE_ATTR.KnifeSlotCount) or 0
	local slotsLeft = model:GetAttribute(TABLE_ATTR.SlotsRemaining) or slotCount
	local alive = model:GetAttribute(TABLE_ATTR.TurnCount) or 0
	local started = model:GetAttribute(TABLE_ATTR.ParticipantCount) or 0

	entry.state = state
	entry.seated = seated
	entry.capacity = capacity

	local preset = TableConfig.get(model:GetAttribute(TABLE_ATTR.TableType))
	entry.title.Text = preset.DisplayName

	local statusText, statusColor
	local infoText = ""

	if state == STATES.Countdown then
		-- 남은 시간(숫자/게이지)은 updateTimer 가 매 프레임 채운다
		statusText = ("%d명 참가 · 곧 시작합니다"):format(seated)
		statusColor = PALETTE.Gold
		infoText = ("칼 %d자루 중 하나가 통을 터뜨립니다"):format(slotCount)
	elseif state == STATES.Starting then
		entry.count.Text = "준비!"
		entry.count.TextColor3 = PALETTE.Gold
		statusText, statusColor = STATE_TEXT[state], PALETTE.Gold
		infoText = ("참가 %d명 · 칼 %d자루"):format(started, slotCount)
	elseif state == STATES.Playing then
		entry.count.Text = ("칼 %d"):format(slotsLeft)
		entry.count.TextColor3 = slotsLeft <= 3 and PALETTE.Danger or PALETTE.Cream

		local pickText, pickColor = lastPickText(model)
		statusText = pickText or STATE_TEXT[state]
		statusColor = pickColor or PALETTE.Cream
		infoText = ("생존 %d / %d명 · 통에 칼 %d자루 남음"):format(alive, math.max(started, alive), slotsLeft)
	elseif state == STATES.RoundEnding then
		local winnerName = model:GetAttribute(TABLE_ATTR.WinnerName) or ""
		local winnerId = model:GetAttribute(TABLE_ATTR.WinnerUserId) or 0

		entry.count.Text = winnerId == 0 and "무승부" or "승리!"
		entry.count.TextColor3 = PALETTE.Gold

		if winnerId == localPlayer.UserId then
			statusText, statusColor = "내가 마지막까지 살아남았다!", PALETTE.Mine
		elseif winnerId ~= 0 then
			statusText, statusColor = ("%s 님 우승"):format(winnerName), PALETTE.Gold
		else
			statusText, statusColor = "남은 참가자가 없습니다", PALETTE.Dim
		end
		-- 초기화까지 남은 시간은 updateTimer 가 채운다
	elseif state == STATES.Resetting then
		entry.count.Text = "정리 중"
		entry.count.TextColor3 = PALETTE.Dim
		statusText, statusColor = STATE_TEXT[state], PALETTE.Dim
		infoText = "곧 다시 앉을 수 있습니다"
	else
		entry.count.Text = ("%d / %d"):format(seated, capacity)
		entry.count.TextColor3 = PALETTE.Cream
		if seated == 0 then
			statusText, statusColor = "빈 테이블 · 앉으면 참가", PALETTE.Cream
		elseif seated < minPlayers then
			statusText, statusColor = ("%d명 더 필요"):format(minPlayers - seated), PALETTE.Cream
		else
			statusText, statusColor = "시작 준비 완료", PALETTE.Ready
		end
		infoText = ("칼 %d자루 · 마지막 한 명이 승리"):format(slotCount)
	end

	entry.status.Text = statusText
	entry.status.TextColor3 = statusColor
	if state ~= STATES.RoundEnding then
		entry.info.Text = infoText
	end

	-- 현재 차례 표시
	local turnUserId = model:GetAttribute(TABLE_ATTR.CurrentTurnUserId) or 0
	local turnName = model:GetAttribute(TABLE_ATTR.CurrentTurnName) or ""
	local turnIndex = model:GetAttribute(TABLE_ATTR.TurnIndex) or 0
	local turnCount = model:GetAttribute(TABLE_ATTR.TurnCount) or 0
	local showTurn = state == STATES.Playing and turnUserId ~= 0 and turnName ~= ""

	entry.turn.Visible = showTurn
	if showTurn then
		if turnUserId == localPlayer.UserId then
			entry.turn.Text = ("▶ 내 차례! 자리를 고르세요 (%d/%d)"):format(turnIndex, turnCount)
			entry.turn.TextColor3 = PALETTE.Mine
		else
			entry.turn.Text = ("▶ %s 님의 차례 (%d/%d)"):format(turnName, turnIndex, turnCount)
			entry.turn.TextColor3 = PALETTE.Cream
		end
	end

	-- 내가 앉아 있는 테이블은 테두리를 금색으로 밝혀 구분한다
	local mine = isLocalPlayerSeated(entry)
	local myTurn = mine and turnUserId == localPlayer.UserId
	local highlight = myTurn and "turn" or (mine and "mine" or "none")
	if entry.highlight ~= highlight then
		entry.highlight = highlight
		TweenService:Create(entry.stroke, FADE_TWEEN, {
			Thickness = (highlight == "turn" and 5) or (highlight == "mine" and 3.5) or 2,
			Transparency = highlight == "none" and 0.3 or 0,
			Color = highlight == "none" and PALETTE.Gold or PALETTE.Mine,
		}):Play()
	end

	-- 숫자가 바뀌면 살짝 튀어오른다 (카운트다운 중에는 타이머가 따로 연출한다)
	local pulseValue = (state == STATES.Playing) and slotsLeft or seated
	if entry.lastCount ~= pulseValue then
		entry.lastCount = pulseValue
		if state ~= STATES.Countdown then
			entry.count.Size = COUNT_POP
			TweenService:Create(entry.count, POP_TWEEN, { Size = COUNT_SIZE }):Play()
		end
	end
end

-- 남은 시간을 그리는 "빠른" 갱신. 서버 시계를 기준으로 계산하므로
-- 서버가 매 초 Attribute 를 갱신하지 않아도 화면은 부드럽게 흐른다.
local function updateTimer(entry)
	local model = entry.model
	if not model or not model.Parent then
		return
	end

	local state = entry.state
	local now = GameConfig.now()

	if state == STATES.Countdown then
		local endsAt = model:GetAttribute(TABLE_ATTR.CountdownEndsAt) or 0
		local duration = model:GetAttribute(TABLE_ATTR.CountdownDuration) or 0
		local remaining = math.max(0, endsAt - now)

		entry.count.Text = Utility.formatSeconds(remaining)
		entry.count.TextColor3 = PALETTE.Gold
		entry.timerTrack.Visible = true
		entry.timerFill.BackgroundColor3 = PALETTE.Gold
		entry.timerFill.Size = UDim2.fromScale(duration > 0 and math.clamp(remaining / duration, 0, 1) or 0, 1)

		-- 1초가 넘어갈 때마다 숫자가 한 번씩 뛴다
		local tick = math.ceil(remaining)
		if entry.lastTick ~= tick then
			entry.lastTick = tick
			entry.count.Size = COUNT_POP
			TweenService:Create(entry.count, POP_TWEEN, { Size = COUNT_SIZE }):Play()
		end
		return
	end

	entry.lastTick = nil

	if state == STATES.RoundEnding then
		local resetAt = model:GetAttribute(TABLE_ATTR.ResetEndsAt) or 0
		local remaining = math.max(0, resetAt - now)
		entry.info.Text = ("%s 뒤 테이블이 초기화됩니다"):format(Utility.formatSeconds(remaining))
		entry.timerTrack.Visible = true
		entry.timerFill.BackgroundColor3 = PALETTE.Gold
		local total = GameConfig.Timing.RoundEndDuration
		entry.timerFill.Size = UDim2.fromScale(total > 0 and math.clamp(remaining / total, 0, 1) or 0, 1)
		return
	end

	if state == STATES.Playing then
		local turnEndsAt = model:GetAttribute(TABLE_ATTR.TurnEndsAt) or 0
		local turnDuration = TableConfig.get(model:GetAttribute(TABLE_ATTR.TableType)).TurnDuration or 0
		if turnEndsAt > 0 and turnDuration > 0 then
			local remaining = math.max(0, turnEndsAt - now)
			entry.timerTrack.Visible = true
			entry.timerFill.BackgroundColor3 = remaining <= 2 and PALETTE.Danger or PALETTE.Ready
			entry.timerFill.Size = UDim2.fromScale(math.clamp(remaining / turnDuration, 0, 1), 1)
			return
		end
	end

	entry.timerTrack.Visible = false
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
	if boards[model] or not model:IsA("Model") or not model:IsDescendantOf(workspace) then
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
		TABLE_ATTR.TableType,
		TABLE_ATTR.SeatCount,
		TABLE_ATTR.SeatedCount,
		TABLE_ATTR.MinPlayers,
		TABLE_ATTR.State,
		TABLE_ATTR.CountdownEndsAt,
		TABLE_ATTR.CountdownDuration,
		TABLE_ATTR.RoundId,
		TABLE_ATTR.ParticipantCount,
		TABLE_ATTR.TurnCount,
		TABLE_ATTR.TurnIndex,
		TABLE_ATTR.CurrentTurnUserId,
		TABLE_ATTR.CurrentTurnName,
		TABLE_ATTR.KnifeSlotCount,
		TABLE_ATTR.SlotsRemaining,
		TABLE_ATTR.LastPickSlot,
		TABLE_ATTR.LastPickSafe,
		TABLE_ATTR.WinnerUserId,
		TABLE_ATTR.WinnerName,
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
	updateTimer(entry)
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
workspace.DescendantAdded:Connect(function(instance)
	local model = instance:IsA("Model") and instance or instance:FindFirstAncestorOfClass("Model")
	while model and model ~= workspace do
		if model:IsA("Model") and CollectionService:HasTag(model, TABLE_TAG) then
			task.defer(function()
				if model:IsDescendantOf(workspace) and CollectionService:HasTag(model, TABLE_TAG) then
					unregisterTable(model)
					registerTable(model)
				end
			end)
			break
		end
		model = model.Parent
	end
end)
workspace.DescendantRemoving:Connect(function(instance)
	if boards[instance] then unregisterTable(instance) end
end)

-- 남은 시간 표시는 초당 20번이면 충분하다. (테이블이 몇 개든 가벼운 계산만 한다)
local lastTimerUpdate = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTimerUpdate < 0.05 then
		return
	end
	lastTimerUpdate = now

	for _, entry in pairs(boards) do
		updateTimer(entry)
	end
end)
