-- RewardController  (Phase 13)
-- 출석판과 룰렛 화면. 왼쪽 아래 상점 위에 버튼 두 개(📅 출석 · 🎡 룰렛)가 생긴다.
--
--   · 무엇을 받는지 · 룰렛이 어디에 멈추는지는 전부 서버(RewardService)가 정한다. 여기서는 그리기만 한다.
--   · 받을 것이 있으면 버튼 위에 빨간 점. 들어오자마자 출석판이 한 번 열린다 (Attendance.AutoOpen).
--   · 출석판 버튼 그림은 ReleaseConfig.Images.Attendance (0 이면 코드로 그린 나무 버튼)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

local UIKit = require(Shared:WaitForChild("UIKit"))

local COLORS = {
	Gold = UIKit.Colors.Gold,
	Cream = UIKit.Colors.Cream,
	Ink = UIKit.Colors.White,
	Green = UIKit.Colors.Green,
	Red = UIKit.Colors.Red,
	Dim = UIKit.Colors.Dim,
}
local ICONS = { coins = "🪙", spin = "🎟", gem = "💎", chest = "🧰" }
-- 출석 칸 배경 (사진처럼 칸마다 다른 색)
local CELL_THEMES = { "green", "green", "blue", "blue", "purple", "purple", "gold" }

local state = nil

local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_Rewards"
gui.ResetOnSpawn = false
gui.DisplayOrder = 16
gui.Parent = player:WaitForChild("PlayerGui")

local function text(parent, value, size, position, textSize, color)
	return UIKit.label(parent, { text = value, size = size, position = position, textSize = textSize or 16, color = color or COLORS.Cream, wrap = true })
end

local function button(parent, value, size, position, themeName)
	return UIKit.button(parent, { text = value, size = size, position = position, theme = themeName or "green", textSize = 24 })
end

--------------------------------------------------
-- 출석판
--------------------------------------------------

local attend = UIKit.window(gui, { name = "Attendance", title = "출석 체크", theme = "purple", icon = "📅", size = Vector2.new(640, 440) })
local attendWindow, attendPaper = attend.frame, attend.body
local cells = {}
for index, reward in ipairs(ATTEND.Days) do
	local row = index <= 4 and 0 or 1
	local column = index <= 4 and (index - 1) or (index - 5)
	local cellWidth = 138
	local offsetX = row == 0 and 4 or 4 + (cellWidth + 12) * 0.5
	local cell = Instance.new("Frame")
	cell.Name = "Day" .. index
	cell.Position = UDim2.fromOffset(offsetX + column * (cellWidth + 12), 4 + row * 150)
	cell.Size = UDim2.fromOffset(cellWidth, 138)
	cell.BackgroundColor3 = Color3.new(1, 1, 1)
	cell.Parent = attendPaper
	UIKit.paint(cell, CELL_THEMES[index] or "blue")
	UIKit.corner(cell, 12)
	local glow = UIKit.outline(cell, 3.5)
	local amountLabel = UIKit.label(cell, { text = Utility.comma(reward.coins), size = UDim2.new(1, -10, 0, 30), position = UDim2.fromOffset(5, 6), textSize = 26, stroke = 3 })
	local icon = UIKit.label(cell, { text = ICONS[reward.icon] or "🪙", size = UDim2.new(1, 0, 0, 60), position = UDim2.fromOffset(0, 36), textSize = 52, stroke = 2 })
	icon.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
	UIKit.label(cell, { text = ("%d일"):format(index), size = UDim2.new(1, 0, 0, 30), position = UDim2.new(0, 0, 1, -34), textSize = 24, stroke = 3 })
	local check = UIKit.label(cell, { text = "✔", size = UDim2.fromScale(1, 1), textSize = 84, color = COLORS.Green, stroke = 4, zIndex = 6 })
	check.Visible = false
	cells[index] = { frame = cell, glow = glow, check = check, icon = icon, amount = amountLabel }
end

local attendNote = text(attendPaper, "", UDim2.new(1, -220, 0, 44), UDim2.new(0, 4, 1, -50), 20, COLORS.Gold)
attendNote.TextXAlignment = Enum.TextXAlignment.Left
local claimButton = button(attendPaper, "받기!", UDim2.fromOffset(190, 56), UDim2.new(1, -196, 1, -60), "green")
claimButton.Activated:Connect(function()
	rewardRequest:FireServer("attend")
end)

local function drawAttendance()
	local attendance = state and state.attendance
	if not attendance then
		return
	end
	-- 이번 판에서 받은 칸 수. 7칸을 다 받은 날은 count 가 0 이 되므로 7칸 모두 체크로 보여 준다.
	local claimed = attendance.count
	if not attendance.ready and claimed == 0 then
		claimed = #ATTEND.Days
	end
	local nextIndex = attendance.ready and (attendance.count % #ATTEND.Days + 1) or nil
	local vipScale = attendance.vip and ATTEND.VipMultiplier or 1
	for index, cell in ipairs(cells) do
		local reward = ATTEND.Days[index]
		cell.check.Visible = index <= claimed and not (attendance.ready and attendance.count == 0)
		cell.icon.TextTransparency = cell.check.Visible and 0.6 or 0
		cell.glow.Color = index == nextIndex and COLORS.Gold or UIKit.Colors.Outline
		cell.glow.Thickness = index == nextIndex and 6 or 3.5
		cell.amount.Text = Utility.comma(math.floor(reward.coins * vipScale))
	end
	if attendance.ready then
		claimButton.Text = "받기!"
		UIKit.setTheme(claimButton, "green")
		claimButton.Active = true
	else
		claimButton.Text = "내일 또 와요"
		UIKit.setTheme(claimButton, "grey")
		claimButton.Active = false
	end
	attendNote.Text = attendance.vip and "👑 VIP ×2" or ""
end

-- 받은 칸이 통통 튀는 연출
local function celebrateCell(index)
	local cell = cells[index]
	if not cell then
		return
	end
	cell.check.Visible = true
	cell.check.TextTransparency = 1
	cell.check.TextSize = 130
	TweenService:Create(cell.check, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0, TextSize = 84 }):Play()
	Sfx.play("Coins", { volume = 0.7 })
end

--------------------------------------------------
-- 룰렛
--------------------------------------------------

local roulette = UIKit.window(gui, { name = "Roulette", title = "행운의 룰렛", theme = "orange", icon = "🎡", size = Vector2.new(660, 460) })
local rouletteWindow, roulettePaper = roulette.frame, roulette.body
local WHEEL = 340
local wheelHolder = Instance.new("Frame")
wheelHolder.Position = UDim2.fromOffset(6, 20)
wheelHolder.Size = UDim2.fromOffset(WHEEL, WHEEL)
wheelHolder.BackgroundTransparency = 1
wheelHolder.Parent = roulettePaper

local wheel = Instance.new("Frame")
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.5)
wheel.Size = UDim2.fromScale(1, 1)
wheel.BackgroundColor3 = UIKit.Colors.BodyDark
wheel.Parent = wheelHolder
UIKit.corner(wheel, UDim.new(0.5, 0))
UIKit.outline(wheel, 8, COLORS.Gold)

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
	spoke.Size = UDim2.new(0, 4, 0.5, -4)
	spoke.BackgroundColor3 = COLORS.Gold
	spoke.BorderSizePixel = 0
	spoke.Parent = pivot

	local radius = WHEEL * 0.32
	local radians = math.rad(angle)
	local tile = Instance.new("Frame")
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.new(0.5, math.sin(radians) * radius, 0.5, -math.cos(radians) * radius)
	tile.Size = UDim2.fromOffset(74, 54)
	tile.Rotation = angle
	tile.BackgroundColor3 = segment.color
	tile.Parent = wheel
	UIKit.corner(tile, 10)
	UIKit.outline(tile, 3)
	UIKit.gradient(tile, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200), 90)
	local icon = segment.kind == "coins" and "🪙" or ((segment.minPrice or 0) > 700 and "💎" or "🎁")
	UIKit.label(tile, { text = icon .. "\n" .. segment.label, size = UDim2.fromScale(1, 1), textSize = 17, stroke = 2.5, wrap = true })
end
local hub = Instance.new("Frame")
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, 0.5)
hub.Size = UDim2.fromOffset(72, 72)
hub.BackgroundColor3 = Color3.new(1, 1, 1)
hub.Parent = wheelHolder
UIKit.paint(hub, "gold")
UIKit.corner(hub, UDim.new(0.5, 0))
UIKit.outline(hub, 4)
UIKit.label(hub, { text = "☠", size = UDim2.fromScale(1, 1), textSize = 40, stroke = 3 })
local pointer = UIKit.label(wheelHolder, { text = "▼", size = UDim2.fromOffset(50, 50), position = UDim2.new(0.5, -25, 0, -36), textSize = 46, color = COLORS.Red, stroke = 4, zIndex = 5 })

-- 오른쪽 : 확률표 + 버튼
local side = Instance.new("Frame")
side.Position = UDim2.new(0, WHEEL + 26, 0, 4)
side.Size = UDim2.new(1, -(WHEEL + 30), 1, -8)
side.BackgroundTransparency = 1
side.Parent = roulettePaper
local oddsTitle = text(side, "확률", UDim2.new(1, 0, 0, 30), UDim2.new(), 24, COLORS.Gold)
oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
local total = GameConfig.rouletteTotalWeight()
for index, segment in ipairs(SEGMENTS) do
	local name
	if segment.kind == "coins" then
		name = "🪙 " .. Utility.comma(segment.amount)
	elseif (segment.minPrice or 0) > 700 then
		name = "💎 희귀 스킨"
	else
		name = "🎁 평범한 스킨"
	end
	local line = text(side, ("%s  %.1f%%"):format(name, segment.weight / total * 100),
		UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 32 + (index - 1) * 22), 17, COLORS.Cream)
	line.TextXAlignment = Enum.TextXAlignment.Left
end
local spinButton = button(side, "돌리기!", UDim2.new(1, 0, 0, 62), UDim2.fromOffset(0, 222), "green")
local resultLabel = text(side, "", UDim2.new(1, 0, 0, 60), UDim2.fromOffset(0, 292), 24, COLORS.Gold)

local spinning = false
local spinToken = 0

local function drawRoulette()
	local info = state and state.roulette
	if not info then
		return
	end
	if spinning then
		spinButton.Text = "…"
	elseif info.free then
		spinButton.Text = "돌리기!"
	else
		spinButton.Text = "내일 또!"
	end
	UIKit.setTheme(spinButton, (not spinning and info.free) and "green" or "grey")
end

spinButton.Activated:Connect(function()
	if spinning then
		return
	end
	local info = state and state.roulette
	if info and info.free then
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

local function resultText(result)
	if result.kind == "coins" then
		return ("🪙 %s 코인!"):format(Utility.comma(result.amount)), result.amount >= 1000
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
	resultLabel.TextColor3 = big and COLORS.Gold or COLORS.Ink
	Sfx.play("Coins", { volume = big and 1 or 0.6 })
	if big then
		pointer.TextSize = 64
		TweenService:Create(pointer, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { TextSize = 46 }):Play()
	end
	drawRoulette()
end

--------------------------------------------------
-- 왼쪽 버튼 두 개 (📅 출석 · 🎡 룰렛)
--------------------------------------------------

local function launcher(name, emoji, caption, imageId, order, themeName, onClick)
	local b, dot = UIKit.railButton({ name = name, icon = emoji, caption = caption, image = imageId, order = order, theme = themeName })
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
	attend.open()
end

local function openRoulette()
	closeOthers(rouletteWindow)
	drawRoulette()
	roulette.open()
end

local attendButton, attendDot = launcher("AttendanceButton", "📅", "출석", tonumber(Release.Images and Release.Images.Attendance) or 0, 3, "purple", function()
	if attendWindow.Visible then
		attendWindow.Visible = false
	else
		openAttendance()
	end
end)
local rouletteButton, rouletteDot = launcher("RouletteButton", "🎡", "룰렛", tonumber(Release.Images and Release.Images.Roulette) or 0, 4, "orange", function()
	if rouletteWindow.Visible then
		rouletteWindow.Visible = false
	else
		openRoulette()
	end
end)

local function refreshDots()
	attendDot.Visible = player:GetAttribute("AttendReady") == true
	rouletteDot.Visible = player:GetAttribute("FreeSpin") == true
end
for _, name in ipairs({ "AttendReady", "FreeSpin" }) do
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
			attendNote.Text = ("🪙 +%s%s"):format(Utility.comma(result.coins), result.vip and "  👑×2" or "")
			claimButton.Text = "내일 또 와요"
			UIKit.setTheme(claimButton, "grey")
			-- 오늘 룰렛을 아직 안 돌렸으면 이어서 룰렛을 보여 준다
			if player:GetAttribute("FreeSpin") == true then
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
