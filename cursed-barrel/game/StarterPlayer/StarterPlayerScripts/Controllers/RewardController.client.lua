-- RewardController  (Phase 13)
-- 출석판과 룰렛 화면. 왼쪽 아래 상점 위에 버튼 두 개(📅 출석 · 🎡 룰렛)가 생긴다.
--
--   · 무엇을 받는지 · 룰렛이 어디에 멈추는지는 전부 서버(RewardService)가 정한다. 여기서는 그리기만 한다.
--   · 받을 것이 있으면 버튼 위에 빨간 점. 들어오자마자 출석판이 한 번 열린다 (Attendance.AutoOpen).
--   · 출석판 버튼 그림은 ReleaseConfig.Images.Attendance (0 이면 코드로 그린 나무 버튼)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local package = ReplicatedStorage:WaitForChild("CursedBarrel")
local Shared = package:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Release = require(Shared:WaitForChild("ReleaseConfig"))
local Utility = require(Shared:WaitForChild("Utility"))
local Sfx = require(Shared:WaitForChild("Sfx"))

local remotes = package:WaitForChild(GameConfig.Remotes.Folder)
local rewardRequest = remotes:WaitForChild(GameConfig.Remotes.Reward)
local rewardCue = remotes:WaitForChild(GameConfig.Remotes.RewardCue)
local shopRequest = remotes:WaitForChild(GameConfig.Remotes.ShopRequest)
local shopResult = remotes:WaitForChild(GameConfig.Remotes.ShopResult)

local ATTEND = GameConfig.Attendance
local ROULETTE = GameConfig.Roulette

local COLORS = {
	Wood = Color3.fromRGB(104, 66, 36),
	WoodDark = Color3.fromRGB(62, 38, 20),
	Plank = Color3.fromRGB(128, 84, 46),
	Parchment = Color3.fromRGB(236, 212, 164),
	Cell = Color3.fromRGB(214, 180, 128),
	Slot = Color3.fromRGB(118, 82, 48),
	Gold = Color3.fromRGB(255, 206, 96),
	Cream = Color3.fromRGB(250, 238, 210),
	Ink = Color3.fromRGB(70, 44, 24),
	Green = Color3.fromRGB(70, 200, 90),
	Red = Color3.fromRGB(214, 52, 44),
	Robux = Color3.fromRGB(0, 176, 111),
	Dim = Color3.fromRGB(150, 130, 104),
}
local ICONS = { coins = "🪙", spin = "🎟", gem = "💎", chest = "🧰" }

local state = nil

local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_Rewards"
gui.ResetOnSpawn = false
gui.DisplayOrder = 16
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or COLORS.WoodDark
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function text(parent, value, size, position, textSize, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Text = value
	l.TextSize = textSize or 14
	l.TextColor3 = color or COLORS.Cream
	l.Font = font or Enum.Font.GothamBold
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function button(parent, value, size, position, color, textColor)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = color or COLORS.Plank
	b.Text = value
	b.TextSize = 16
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = textColor or COLORS.Cream
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 10)
	return b
end

-- 나무 판 창 (사진처럼 : 나무 틀 + 해골 머리판 + 양피지)
local function woodWindow(name, title, width, height)
	local window = Instance.new("Frame")
	window.Name = name
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromOffset(width, height)
	window.BackgroundColor3 = COLORS.Wood
	window.Visible = false
	window.Parent = gui
	corner(window, 18)
	stroke(window, COLORS.WoodDark, 4)
	local scale = Instance.new("UIScale")
	scale.Parent = window
	local grain = Instance.new("UIGradient")
	grain.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 190, 180))
	grain.Rotation = 90
	grain.Parent = window

	local header = Instance.new("Frame")
	header.AnchorPoint = Vector2.new(0.5, 0.5)
	header.Position = UDim2.new(0.5, 0, 0, 6)
	header.Size = UDim2.fromOffset(math.min(width - 60, 340), 50)
	header.BackgroundColor3 = COLORS.Plank
	header.Parent = window
	corner(header, 12)
	stroke(header, COLORS.WoodDark, 3)
	text(header, "☠  " .. title .. "  ☠", UDim2.fromScale(1, 1), UDim2.new(), 22, COLORS.Gold, Enum.Font.GothamBlack)

	-- 양쪽 붉은 깃발
	for _, side in ipairs({ -1, 1 }) do
		local flag = Instance.new("TextLabel")
		flag.AnchorPoint = Vector2.new(0.5, 0)
		flag.Position = UDim2.new(side < 0 and 0 or 1, side * -4, 0, 30)
		flag.Size = UDim2.fromOffset(34, 64)
		flag.BackgroundColor3 = COLORS.Red
		flag.Text = "☠"
		flag.TextSize = 20
		flag.TextColor3 = COLORS.Cream
		flag.Parent = window
		corner(flag, 4)
	end

	local paper = Instance.new("Frame")
	paper.Name = "Paper"
	paper.Position = UDim2.fromOffset(22, 44)
	paper.Size = UDim2.new(1, -44, 1, -62)
	paper.BackgroundColor3 = COLORS.Parchment
	paper.Parent = window
	corner(paper, 12)
	stroke(paper, Color3.fromRGB(170, 130, 84), 2)

	local close = button(window, "✕", UDim2.fromOffset(36, 36), UDim2.new(1, -28, 0, -8), COLORS.Red)
	close.Activated:Connect(function()
		window.Visible = false
	end)
	return window, paper, scale
end

-- 작은 화면에서는 창을 줄인다
local function fit(window, scale)
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local size = window.Size
	scale.Scale = math.min(1, (view.X - 24) / size.X.Offset, (view.Y - 70) / (size.Y.Offset + 30))
end

local function popIn(window, scale)
	fit(window, scale)
	local target = scale.Scale
	scale.Scale = target * 0.8
	window.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
end

--------------------------------------------------
-- 출석판
--------------------------------------------------

local attendWindow, attendPaper, attendScale = woodWindow("Attendance", "출석 체크", 600, 400)
local cells = {}
for index, reward in ipairs(ATTEND.Days) do
	local row = index <= 4 and 0 or 1
	local column = index <= 4 and (index - 1) or (index - 5)
	local cellWidth = 118
	local offsetX = row == 0 and 14 or 14 + cellWidth * 0.5 + 6
	local cell = Instance.new("Frame")
	cell.Position = UDim2.fromOffset(offsetX + column * (cellWidth + 12), 14 + row * 140)
	cell.Size = UDim2.fromOffset(cellWidth, 128)
	cell.BackgroundColor3 = COLORS.Cell
	cell.Parent = attendPaper
	corner(cell, 12)
	local glow = stroke(cell, COLORS.Gold, 0)
	local slot = Instance.new("Frame")
	slot.Position = UDim2.fromOffset(10, 26)
	slot.Size = UDim2.new(1, -20, 0, 62)
	slot.BackgroundColor3 = COLORS.Slot
	slot.Parent = cell
	corner(slot, 10)
	text(cell, ("%d일"):format(index), UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 3), 14, COLORS.Ink, Enum.Font.GothamBlack)
	local icon = text(slot, ICONS[reward.icon] or "🪙", UDim2.fromScale(1, 1), UDim2.new(), 34, COLORS.Cream)
	local amount = reward.coins .. (reward.spins and ("\n+🎟" .. reward.spins) or "")
	local amountLabel = text(cell, amount, UDim2.new(1, -8, 0, 34), UDim2.fromOffset(4, 90), 13, COLORS.Ink, Enum.Font.GothamBlack)
	local check = text(cell, "✔", UDim2.fromScale(1, 1), UDim2.new(), 64, COLORS.Green, Enum.Font.GothamBlack)
	check.TextStrokeTransparency = 0.2
	check.TextStrokeColor3 = Color3.fromRGB(20, 80, 30)
	check.Visible = false
	cells[index] = { frame = cell, glow = glow, check = check, icon = icon, amount = amountLabel, slot = slot }
end

local attendNote = text(attendPaper, "", UDim2.new(1, -170, 0, 34), UDim2.new(0, 14, 1, -44), 13, COLORS.Ink)
attendNote.TextXAlignment = Enum.TextXAlignment.Left
local claimButton = button(attendPaper, "받기!", UDim2.fromOffset(140, 40), UDim2.new(1, -154, 1, -48), COLORS.Green)
claimButton.Activated:Connect(function()
	rewardRequest:FireServer("attend")
end)

local function drawAttendance()
	local attend = state and state.attendance
	if not attend then
		return
	end
	-- 이번 판에서 받은 칸 수. 7칸을 다 받은 날은 count 가 0 이 되므로 7칸 모두 체크로 보여 준다.
	local claimed = attend.count
	if not attend.ready and claimed == 0 then
		claimed = #ATTEND.Days
	end
	local nextIndex = attend.ready and (attend.count % #ATTEND.Days + 1) or nil
	local vipScale = attend.vip and ATTEND.VipMultiplier or 1
	for index, cell in ipairs(cells) do
		local reward = ATTEND.Days[index]
		cell.check.Visible = index <= claimed and not (attend.ready and attend.count == 0)
		cell.icon.TextTransparency = cell.check.Visible and 0.6 or 0
		cell.glow.Thickness = index == nextIndex and 4 or 0
		cell.frame.BackgroundColor3 = index == nextIndex and Color3.fromRGB(255, 226, 150) or COLORS.Cell
		cell.amount.Text = ("%s%s"):format(Utility.comma(math.floor(reward.coins * vipScale)), reward.spins and ("\n+🎟" .. reward.spins) or "")
	end
	if attend.ready then
		claimButton.Text = "받기!"
		claimButton.BackgroundColor3 = COLORS.Green
		claimButton.AutoButtonColor = true
	else
		claimButton.Text = "내일 또 와요"
		claimButton.BackgroundColor3 = COLORS.Dim
		claimButton.AutoButtonColor = false
	end
	attendNote.Text = attend.vip and "👑 VIP 코인 2배 적용 중!  빠진 날이 있어도 이어서 받아요."
		or "👑 VIP 패스가 있으면 출석 코인 2배!  빠진 날이 있어도 이어서 받아요."
end

-- 받은 칸이 통통 튀는 연출
local function celebrateCell(index)
	local cell = cells[index]
	if not cell then
		return
	end
	cell.check.Visible = true
	cell.check.TextTransparency = 1
	cell.check.TextSize = 110
	TweenService:Create(cell.check, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0, TextSize = 64 }):Play()
	Sfx.play("Coins", { volume = 0.7 })
end

--------------------------------------------------
-- 룰렛
--------------------------------------------------

local rouletteWindow, roulettePaper, rouletteScale = woodWindow("Roulette", "행운의 룰렛", 620, 420)
local WHEEL = 300
local wheelHolder = Instance.new("Frame")
wheelHolder.Position = UDim2.fromOffset(16, 34)
wheelHolder.Size = UDim2.fromOffset(WHEEL, WHEEL)
wheelHolder.BackgroundTransparency = 1
wheelHolder.Parent = roulettePaper

local wheel = Instance.new("Frame")
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.5)
wheel.Size = UDim2.fromScale(1, 1)
wheel.BackgroundColor3 = COLORS.WoodDark
wheel.Parent = wheelHolder
local wheelRound = corner(wheel, 0)
wheelRound.CornerRadius = UDim.new(0.5, 0)
stroke(wheel, COLORS.Gold, 5)

local SEGMENTS = ROULETTE.Segments
local STEP = 360 / #SEGMENTS
for index, segment in ipairs(SEGMENTS) do
	local angle = (index - 1) * STEP
	-- 칸 사이 칸막이 : 바퀴 크기의 투명 틀을 돌리고, 그 안에 가운데에서 위로 뻗는 선을 둔다
	local pivot = Instance.new("Frame")
	pivot.AnchorPoint = Vector2.new(0.5, 0.5)
	pivot.Position = UDim2.fromScale(0.5, 0.5)
	pivot.Size = UDim2.fromScale(1, 1)
	pivot.BackgroundTransparency = 1
	pivot.Rotation = angle + STEP / 2
	pivot.Parent = wheel
	local spoke = Instance.new("Frame")
	spoke.AnchorPoint = Vector2.new(0.5, 1)
	spoke.Position = UDim2.fromScale(0.5, 0.5)
	spoke.Size = UDim2.new(0, 3, 0.5, -4)
	spoke.BackgroundColor3 = COLORS.Gold
	spoke.BorderSizePixel = 0
	spoke.Parent = pivot

	local radius = WHEEL * 0.32
	local radians = math.rad(angle)
	local tile = Instance.new("TextLabel")
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.new(0.5, math.sin(radians) * radius, 0.5, -math.cos(radians) * radius)
	tile.Size = UDim2.fromOffset(64, 44)
	tile.Rotation = angle
	tile.BackgroundColor3 = segment.color
	tile.TextColor3 = COLORS.Cream
	tile.Font = Enum.Font.GothamBlack
	tile.TextSize = 15
	tile.TextWrapped = true
	if segment.kind == "coins" then
		tile.Text = "🪙\n" .. segment.label
	elseif segment.kind == "spins" then
		tile.Text = "🎟\n" .. segment.label
	else
		tile.Text = "🎁\n" .. segment.label
	end
	tile.Parent = wheel
	corner(tile, 8)
end
local hub = Instance.new("TextLabel")
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, 0.5)
hub.Size = UDim2.fromOffset(62, 62)
hub.BackgroundColor3 = COLORS.Plank
hub.Text = "☠"
hub.TextSize = 32
hub.TextColor3 = COLORS.Cream
hub.Parent = wheelHolder
corner(hub, 31)
stroke(hub, COLORS.Gold, 3)
local pointer = text(wheelHolder, "▼", UDim2.fromOffset(40, 40), UDim2.new(0.5, -20, 0, -30), 38, COLORS.Red, Enum.Font.GothamBlack)
pointer.TextStrokeTransparency = 0
pointer.ZIndex = 5

-- 오른쪽 : 확률표 + 버튼
local side = Instance.new("Frame")
side.Position = UDim2.new(0, WHEEL + 32, 0, 12)
side.Size = UDim2.new(1, -(WHEEL + 44), 1, -24)
side.BackgroundTransparency = 1
side.Parent = roulettePaper
local oddsTitle = text(side, "확률표 (모든 돌리기 동일)", UDim2.new(1, 0, 0, 20), UDim2.new(), 13, COLORS.Ink, Enum.Font.GothamBlack)
oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
local total = GameConfig.rouletteTotalWeight()
for index, segment in ipairs(SEGMENTS) do
	local name
	if segment.kind == "coins" then
		name = Utility.comma(segment.amount) .. " 코인"
	elseif segment.kind == "spins" then
		name = "이용권 +1"
	else
		name = "스킨 (없는 것 중 하나)"
	end
	local line = text(side, ("%s  ·  %.1f%%"):format(name, segment.weight / total * 100),
		UDim2.new(1, 0, 0, 17), UDim2.fromOffset(0, 20 + (index - 1) * 17), 12, COLORS.Ink, Enum.Font.Gotham)
	line.TextXAlignment = Enum.TextXAlignment.Left
end
local spinsLabel = text(side, "", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 162), 14, COLORS.Ink, Enum.Font.GothamBlack)
spinsLabel.TextXAlignment = Enum.TextXAlignment.Left
local spinButton = button(side, "돌리기!", UDim2.new(1, 0, 0, 46), UDim2.fromOffset(0, 188), COLORS.Green)
local buyButton = button(side, "", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 242), COLORS.Robux)
buyButton.TextSize = 13
local resultLabel = text(side, "", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 284), 14, COLORS.Ink, Enum.Font.GothamBlack)

local spinning = false
local spinToken = 0
local IN_STUDIO = game:GetService("RunService"):IsStudio()

local function drawRoulette()
	local info = state and state.roulette
	if not info then
		return
	end
	spinsLabel.Text = ("🎟 이용권 %d장%s"):format(info.spins, info.free and "  ·  오늘 무료 1회!" or "")
	if spinning then
		spinButton.Text = "돌아가는 중…"
	elseif info.free then
		spinButton.Text = "무료로 돌리기!"
	elseif info.spins > 0 then
		spinButton.Text = "이용권 1장 쓰기"
	else
		spinButton.Text = "내일 무료 1회"
	end
	spinButton.BackgroundColor3 = (not spinning and (info.free or info.spins > 0)) and COLORS.Green or COLORS.Dim
	local pack = info.pack
	buyButton.Visible = not info.restricted and (pack.ready or IN_STUDIO)
	buyButton.Text = pack.ready and ("R$ %d · 이용권 %d장"):format(pack.robux, pack.spins) or "이용권 판매 준비 중"
	buyButton.BackgroundColor3 = pack.ready and COLORS.Robux or COLORS.Dim
end

spinButton.Activated:Connect(function()
	if spinning then
		return
	end
	local info = state and state.roulette
	if info and (info.free or info.spins > 0) then
		spinning = true
		spinToken += 1
		local token = spinToken
		resultLabel.Text = ""
		drawRoulette()
		rewardRequest:FireServer("spin")
		-- 서버 답이 오지 않으면 풀어 준다
		task.delay(6, function()
			if spinning and token == spinToken then
				spinning = false
				drawRoulette()
			end
		end)
	end
end)
buyButton.Activated:Connect(function()
	rewardRequest:FireServer("buySpins")
end)

local function resultText(result)
	if result.kind == "coins" then
		return ("🪙 %s 코인!"):format(Utility.comma(result.amount)), result.amount >= 1000
	elseif result.kind == "spins" then
		return "🎟 이용권 +1! 한 번 더!", false
	elseif result.kind == "skin" then
		return ("🎁 스킨 「%s」!"):format(result.skinName or "?"), true
	end
	return "", false
end

local function spinTo(result)
	spinToken += 1
	local target = (result.index - 1) * STEP
	-- 칸 안에서 조금 흔들리게 (가운데에만 멈추면 조작처럼 보인다)
	local jitter = (math.random() - 0.5) * STEP * 0.6
	local current = wheel.Rotation % 360
	wheel.Rotation = current
	local goal = current + 360 * 6 + ((360 - target - jitter) - current) % 360
	local tween = TweenService:Create(wheel, TweenInfo.new(4.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = goal })
	tween:Play()
	-- 칸을 지날 때마다 딸깍
	task.spawn(function()
		local last = math.floor(wheel.Rotation / STEP)
		while tween.PlaybackState == Enum.PlaybackState.Playing do
			local now = math.floor(wheel.Rotation / STEP)
			if now ~= last then
				last = now
				Sfx.play("Hit", { volume = 0.25, pitch = 2.2 })
			end
			task.wait()
		end
	end)
	tween.Completed:Wait()
	spinning = false
	local message, big = resultText(result)
	resultLabel.Text = message
	resultLabel.TextColor3 = big and COLORS.Red or COLORS.Ink
	Sfx.play("Coins", { volume = big and 1 or 0.6 })
	if big then
		pointer.TextSize = 54
		TweenService:Create(pointer, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { TextSize = 38 }):Play()
	end
	drawRoulette()
end

--------------------------------------------------
-- 왼쪽 아래 버튼 두 개
--------------------------------------------------

local baseY = UserInputService.TouchEnabled and -108 or -16
local function launcher(name, emoji, caption, imageId, index, onClick)
	local b
	local size = 66
	if imageId and imageId > 0 then
		b = Instance.new("ImageButton")
		b.Image = "rbxassetid://" .. imageId
		b.ScaleType = Enum.ScaleType.Crop
		b.BackgroundColor3 = COLORS.Wood
	else
		local t = Instance.new("TextButton")
		t.Text = emoji .. "\n" .. caption
		t.TextSize = 13
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = COLORS.Gold
		t.BackgroundColor3 = COLORS.Wood
		b = t
	end
	b.Name = name
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(0, 14 + (index - 1) * (size + 8), 1, baseY - 76 - 10)
	b.Size = UDim2.fromOffset(size, size)
	b.BorderSizePixel = 0
	b.Parent = gui
	corner(b, 14)
	stroke(b, COLORS.Gold, 2)
	local dot = Instance.new("TextLabel")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -4, 0, 4)
	dot.Size = UDim2.fromOffset(22, 22)
	dot.BackgroundColor3 = COLORS.Red
	dot.TextColor3 = COLORS.Cream
	dot.Font = Enum.Font.GothamBlack
	dot.TextSize = 12
	dot.Text = "!"
	dot.Visible = false
	dot.Parent = b
	corner(dot, 11)
	b.Activated:Connect(onClick)
	return b, dot
end

local function closeOthers(keep)
	for _, window in ipairs({ attendWindow, rouletteWindow }) do
		if window ~= keep then
			window.Visible = false
		end
	end
end

local function openAttendance()
	closeOthers(attendWindow)
	drawAttendance()
	popIn(attendWindow, attendScale)
end

local function openRoulette()
	closeOthers(rouletteWindow)
	drawRoulette()
	popIn(rouletteWindow, rouletteScale)
end

local attendButton, attendDot = launcher("AttendanceButton", "📅", "출석", tonumber(Release.Images and Release.Images.Attendance) or 0, 1, function()
	if attendWindow.Visible then
		attendWindow.Visible = false
	else
		openAttendance()
	end
end)
local rouletteButton, rouletteDot = launcher("RouletteButton", "🎡", "룰렛", tonumber(Release.Images and Release.Images.Roulette) or 0, 2, function()
	if rouletteWindow.Visible then
		rouletteWindow.Visible = false
	else
		openRoulette()
	end
end)

local function refreshDots()
	attendDot.Visible = player:GetAttribute("AttendReady") == true
	local spins = player:GetAttribute("Spins") or 0
	local free = player:GetAttribute("FreeSpin") == true
	rouletteDot.Visible = free or spins > 0
	rouletteDot.Text = free and "!" or tostring(math.min(spins, 99))
end
for _, name in ipairs({ "AttendReady", "Spins", "FreeSpin" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshDots)
end
refreshDots()

-- 버튼이 살짝 흔들려 눈길을 끈다 (받을 것이 있을 때만)
task.spawn(function()
	while gui.Parent do
		task.wait(3)
		for _, pair in ipairs({ { attendButton, attendDot }, { rouletteButton, rouletteDot } }) do
			if pair[2].Visible and not player:GetAttribute("Setting_reducedFX") then
				local b = pair[1]
				TweenService:Create(b, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), { Rotation = 8 }):Play()
			end
		end
	end
end)

--------------------------------------------------
-- 서버 소식
--------------------------------------------------

local autoOpened = false
local function seated()
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.SeatPart ~= nil
end

shopResult.OnClientEvent:Connect(function(_, _, payload)
	if typeof(payload) ~= "table" then
		return
	end
	state = payload
	if attendWindow.Visible then
		drawAttendance()
	end
	if rouletteWindow.Visible and not spinning then
		drawRoulette()
	end
	-- 들어오자마자 받을 출석이 있으면 한 번 열어 준다
	-- (처음 온 사람은 안내 창을 먼저 본다. 안내를 마친 뒤에 연다)
	if ATTEND.AutoOpen and not autoOpened and state.attendance and state.attendance.ready then
		autoOpened = true
		task.spawn(function()
			if player:GetAttribute("TutorialDone") ~= true then
				player:GetAttributeChangedSignal("TutorialDone"):Wait()
			end
			task.wait(3)
			if not seated() and state.attendance.ready then
				openAttendance()
			end
		end)
	end
end)

rewardCue.OnClientEvent:Connect(function(kind, ok, result)
	if kind == "attend" then
		if ok and typeof(result) == "table" then
			if state and state.attendance then
				state.attendance.ready = false
			end
			celebrateCell(result.day)
			attendNote.Text = ("+%s 코인%s%s"):format(Utility.comma(result.coins), (result.spins or 0) > 0 and (" · 룰렛 이용권 +" .. result.spins) or "",
				result.vip and " (VIP 2배)" or "")
			claimButton.Text = "내일 또 와요"
			claimButton.BackgroundColor3 = COLORS.Dim
			if (result.spins or 0) > 0 then
				task.delay(1.6, function()
					if attendWindow.Visible then
						openRoulette()
					end
				end)
			end
		else
			attendNote.Text = tostring(result)
		end
	elseif kind == "spin" then
		if ok and typeof(result) == "table" then
			spinTo(result)
		else
			spinning = false
			resultLabel.Text = tostring(result)
			drawRoulette()
		end
	elseif kind == "notice" then
		resultLabel.Text = tostring(result)
	end
end)

shopRequest:FireServer("sync")
