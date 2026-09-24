-- RewardController  (Phase 13)
-- 출석판과 룰렛 화면. 화면 오른쪽에 버튼 두 개(📅 출석 · 🎡 룰렛)가 세로로 선다. (Phase 15 : 왼쪽 → 오른쪽)
--   · Phase 15 : 룰렛 확률표를 걷어냈다. 룰렛은 하루 한 번 무료이고 로벅스로 사는 뽑기가 아니라서
--     Roblox 규정상 확률을 꼭 보여 줄 필요가 없다. (돈으로 돌리는 뽑기를 만들면 그때는 반드시 보여 줘야 한다)
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
local MoneyIcon = require(Shared:WaitForChild("MoneyIcon"))
local DAY_ICONS = { "cash", "cash", "cash2", "cash2", "cash3", "cash3", "chest" }
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
	-- Phase 16 : 칸마다 돈 모양 그림 (날이 갈수록 돈이 많아지고 7일째는 보물 상자)
	local icon = MoneyIcon.view(cell, DAY_ICONS[index] or "cash", { size = UDim2.new(1, -16, 0, 66), position = UDim2.fromOffset(8, 34), spin = index == #ATTEND.Days })
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
		cell.icon.ImageTransparency = cell.check.Visible and 0.6 or 0
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
local WHEEL = 350
local wheelHolder = Instance.new("Frame")
wheelHolder.Position = UDim2.fromOffset(0, 14)
wheelHolder.Size = UDim2.fromOffset(WHEEL, WHEEL)
wheelHolder.BackgroundTransparency = 1
wheelHolder.Parent = roulettePaper

-- Phase 16 : 진짜 3D 룰렛 판 (선명한 칸 · 금테 · 반짝이는 전구 · 돈 그림 · 빨간 바늘). RouletteWheel 참고
local SEGMENTS = ROULETTE.Segments
local STEP = 360 / #SEGMENTS
local wheel = require(Shared:WaitForChild("RouletteWheel")).new(wheelHolder, SEGMENTS, WHEEL)

-- 오른쪽 : 안내 한 줄 + 버튼 + 결과 (Phase 15 : 확률표는 걷어냈다)
local side = Instance.new("Frame")
side.Position = UDim2.new(0, WHEEL + 26, 0, 4)
side.Size = UDim2.new(1, -(WHEEL + 30), 1, -8)
side.BackgroundTransparency = 1
side.Parent = roulettePaper
text(side, "하루 한 번 무료!", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 40), 28, COLORS.Gold)
for i, kind in ipairs({ "cash2", "gift", "chest" }) do
	MoneyIcon.view(side, kind, { size = UDim2.new(1 / 3, -4, 0, 70), position = UDim2.new((i - 1) / 3, 2, 0, 88), spin = true })
end
local spinButton = button(side, "돌리기!", UDim2.new(1, 0, 0, 62), UDim2.fromOffset(0, 172), "green")
local resultLabel = text(side, "", UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, 250), 24, COLORS.Gold)

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
	local current = wheel.rotation % 360
	wheel:setRotation(current)
	local goal = current + 360 * 6 + ((360 - target - jitter) - current) % 360
	local angle = Instance.new("NumberValue")
	angle.Value = current
	local tween = TweenService:Create(angle, TweenInfo.new(4.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = goal })
	-- 칸을 지날 때마다 딸깍
	local last = math.floor((current + STEP / 2) / STEP)
	local changed = angle.Changed:Connect(function(value)
		wheel:setRotation(value)
		local now = math.floor((value + STEP / 2) / STEP)
		if now ~= last then
			last = now
			Sfx.play("Hit", { volume = 0.25, pitch = 2.2 })
		end
	end)
	wheel:setFast(true)
	tween:Play()
	tween.Completed:Wait()
	changed:Disconnect()
	angle:Destroy()
	wheel:setRotation(goal)
	wheel:setFast(false)
	spinning = false
	local message, big = resultText(result)
	resultLabel.Text = message
	resultLabel.TextColor3 = big and COLORS.Gold or COLORS.Ink
	Sfx.play("Coins", { volume = big and 1 or 0.6 })
	if big then
		wheel:celebrate()
	end
	drawRoulette()
end

--------------------------------------------------
-- 왼쪽 버튼 두 개 (📅 출석 · 🎡 룰렛)
--------------------------------------------------

local function launcher(name, emoji, caption, imageId, order, themeName, onClick)
	local b, dot = UIKit.railButton({ name = name, icon = emoji, caption = caption, image = imageId, order = order, theme = themeName, side = "right" })
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

--------------------------------------------------
-- Phase 16 : 🎟 코드 입력 · 👍 좋아요 보상
--------------------------------------------------

local codeWin = UIKit.window(gui, { name = "Codes", title = "코드 입력", theme = "teal", icon = "🎟", size = Vector2.new(500, 300) })
local codeBox = Instance.new("TextBox")
codeBox.Name = "CodeBox"
codeBox.Size = UDim2.new(1, -8, 0, 64)
codeBox.Position = UDim2.fromOffset(4, 14)
codeBox.BackgroundColor3 = UIKit.Colors.Cream
codeBox.ClearTextOnFocus = false
codeBox.PlaceholderText = "코드를 적어 주세요"
codeBox.PlaceholderColor3 = Color3.fromRGB(140, 130, 120)
codeBox.Text = ""
codeBox.TextColor3 = UIKit.Colors.Outline
codeBox.FontFace = UIKit.font()
codeBox.TextSize = 30
codeBox.Parent = codeWin.body
UIKit.corner(codeBox, 12)
UIKit.outline(codeBox, 3.5)
local codeButton = button(codeWin.body, "확인", UDim2.new(1, -8, 0, 62), UDim2.fromOffset(4, 92), "green")
local codeResult = text(codeWin.body, "", UDim2.new(1, -8, 0, 44), UDim2.fromOffset(4, 162), 24, COLORS.Gold)
local codeBusy = false
local function sendCode()
	if codeBusy then
		return
	end
	local value = codeBox.Text
	if value:gsub("%s", "") == "" then
		codeResult.Text = "코드를 적어 주세요"
		codeResult.TextColor3 = COLORS.Red
		return
	end
	codeBusy = true
	codeResult.Text = "…"
	rewardRequest:FireServer("code", value)
	task.delay(4, function()
		codeBusy = false
	end)
end
codeButton.Activated:Connect(sendCode)
codeBox.FocusLost:Connect(function(enter)
	if enter then
		sendCode()
	end
end)

-- Phase 16.1 : 그룹 가입을 서버가 직접 확인하고 준다 (좋아요는 Roblox 가 게임에 알려 주지 않아서 "부탁"만 한다)
local GROUP = tonumber(Release.GroupId) or 0
local IN_STUDIO = game:GetService("RunService"):IsStudio()
local likeWin = UIKit.window(gui, { name = "LikeReward", title = "그룹 가입 보상", theme = "blue", icon = "👥", size = Vector2.new(600, 360) })
local likeView = Instance.new("ViewportFrame")
likeView.Name = "Drum"
likeView.Size = UDim2.fromOffset(210, 230)
likeView.Position = UDim2.fromOffset(4, 8)
likeView.BackgroundColor3 = UIKit.Colors.BodyDark
likeView.Ambient = Color3.fromRGB(170, 180, 205)
likeView.LightColor = Color3.fromRGB(255, 240, 220)
likeView.LightDirection = Vector3.new(-1, -1.3, -0.8)
likeView.Parent = likeWin.body
UIKit.corner(likeView, 14)
UIKit.outline(likeView, 3)
task.spawn(function()
	local like = GameConfig.LikeReward
	local skin = like and GameConfig.findSkin(like.Kind, like.Skin)
	if not skin then
		return
	end
	local world = Instance.new("WorldModel")
	world.Parent = likeView
	local ok, model = pcall(function()
		return require(Shared:WaitForChild("SkinPreview")).build(like.Kind, skin, world)
	end)
	if not ok or not model then
		return
	end
	local box, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = likeView
	likeView.CurrentCamera = camera
	local distance = math.max(size.X, size.Y, size.Z) * 0.5 / math.tan(math.rad(15)) * 1.1 + 0.5
	local angle = 0
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, 0.35, 1).Unit * distance, box.Position)
	while likeView.Parent do
		if likeWin.frame.Visible then
			angle += 0.03
			camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(math.sin(angle), 0.35, math.cos(angle)).Unit * distance, box.Position)
			task.wait(1 / 30)
		else
			task.wait(0.5)
		end
	end
end)
local likeSide = Instance.new("Frame")
likeSide.BackgroundTransparency = 1
likeSide.Position = UDim2.fromOffset(230, 0)
likeSide.Size = UDim2.new(1, -232, 1, 0)
likeSide.Parent = likeWin.body
text(likeSide, "파란 철제 드럼 무료!", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 6), 30, UIKit.Colors.Blue)
local likeHow = text(likeSide, "", UDim2.new(1, 0, 0, 74), UDim2.fromOffset(0, 50), 21, COLORS.Cream)
local likeButton = button(likeSide, "👥 그룹 가입하고 받기", UDim2.new(1, -4, 0, 64), UDim2.fromOffset(0, 136), "blue")
local likeResult = text(likeSide, "", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 210), 22, COLORS.Gold)
local likeBusy = false
local function drawLike()
	local claimed = player:GetAttribute("LikeClaimed") == true
	local ready = GROUP > 0
	if claimed then
		likeButton.Text = "받았어요 ✔"
		likeHow.Text = "고마워요! 통 스킨에서 장착할 수 있어요"
	elseif not ready then
		likeButton.Text = "준비 중"
		likeHow.Text = IN_STUDIO and "ReleaseConfig.GroupId 에 그룹 번호를 넣어 주세요" or "곧 열려요!"
	else
		likeButton.Text = "👥 그룹 가입하고 받기"
		likeHow.Text = "그룹에 가입하면 바로 받아요 (가입을 확인해요)\n👍 게임 좋아요도 부탁해요!"
	end
	local active = ready and not claimed and not likeBusy
	UIKit.setTheme(likeButton, active and "blue" or "grey")
	likeButton.Active = active
end
likeButton.Activated:Connect(function()
	if likeBusy or GROUP <= 0 or player:GetAttribute("LikeClaimed") == true then
		return
	end
	likeBusy = true
	likeResult.Text = "…"
	drawLike()
	task.spawn(function()
		-- 아직 안 들어갔으면 Roblox 그룹 가입 창을 띄운다. 가입했는지는 서버가 다시 확인한다
		local okMember, member = pcall(function()
			return player:IsInGroup(GROUP)
		end)
		if not (okMember and member) then
			pcall(function()
				game:GetService("GroupService"):PromptJoinAsync(GROUP)
			end)
		end
		rewardRequest:FireServer("like")
		task.delay(3, function()
			if likeBusy then
				likeBusy = false
				drawLike()
			end
		end)
	end)
end)
local function openLike()
	drawLike()
	likeResult.Text = ""
	likeWin.open()
end

-- 받침대 프롬프트 (스폰 옆 파란 드럼)
local CollectionService = game:GetService("CollectionService")
local function bindLikePrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function label()
		prompt.ActionText = player:GetAttribute("LikeClaimed") == true and "받음 ✔" or "받기"
	end
	label()
	player:GetAttributeChangedSignal("LikeClaimed"):Connect(label)
	prompt.Triggered:Connect(openLike)
end
for _, prompt in ipairs(CollectionService:GetTagged(GameConfig.Tags.LikeReward)) do
	bindLikePrompt(prompt)
end
CollectionService:GetInstanceAddedSignal(GameConfig.Tags.LikeReward):Connect(bindLikePrompt)
player:GetAttributeChangedSignal("LikeClaimed"):Connect(function()
	if likeWin.frame.Visible then
		drawLike()
	end
end)

launcher("CodeButton", "🎟", "코드", 0, 5, "teal", function()
	if codeWin.frame.Visible then
		codeWin.hide()
	else
		codeResult.Text = ""
		codeWin.open()
	end
end)

local function refreshDots()
	UIKit.setDot(attendDot, player:GetAttribute("AttendReady") == true and 1 or 0)
	UIKit.setDot(rouletteDot, player:GetAttribute("FreeSpin") == true and 1 or 0)
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
	elseif kind == "code" then
		codeBusy = false
		local info = typeof(result) == "table" and result or {}
		codeResult.Text = tostring(info.message or "")
		codeResult.TextColor3 = ok and COLORS.Gold or COLORS.Red
		if ok then
			codeBox.Text = ""
			Sfx.play("Coins", { volume = 0.9 })
			shopRequest:FireServer("sync")
		end
	elseif kind == "like" then
		if ok and typeof(result) == "table" then
			likeResult.Text = ("🎉 「%s」 받았어요! (장착됨)"):format(tostring(result.skinName))
			likeResult.TextColor3 = COLORS.Gold
			Sfx.play("Coins", { volume = 0.9 })
			shopRequest:FireServer("sync")
		elseif result == "group" then
			likeResult.Text = "그룹에 가입해야 받을 수 있어요"
			likeResult.TextColor3 = COLORS.Red
		elseif result == "notready" then
			likeResult.Text = "준비 중이에요"
			likeResult.TextColor3 = COLORS.Red
		else
			likeResult.Text = tostring(result)
			likeResult.TextColor3 = COLORS.Red
		end
		likeBusy = false
		drawLike()
	end
end)

shopRequest:FireServer("sync")
