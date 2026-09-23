-- 개인 테이블 무대, 카메라, 칼 꽂기, 해적 클로즈업, 해적 잡기, 해적 스킨, 방해 연출.
-- 이 파일은 시각/소리/입력만 처리합니다. 슬롯 판정과 잡기 판정은 전부 서버가 결정합니다.
--
-- Phase 6 에서 고친 것
--   · 해적이 튀어나올 때 카메라가 해적을 담지 못하던 문제
--     이전에는 통 뚜껑을 기준으로 2.3스터드까지 파고들었습니다. 그런데 해적은
--     통 중심에서 5.2스터드 위, 카메라보다 앞쪽에 서 있어서 화면 위로 벗어났습니다.
--     (화각만 94도로 벌어져 통 표면만 크게 보였습니다)
--     이제는 해적이 서는 지점을 직접 계산해서 그 지점을 바라보고,
--     해적의 실제 키를 재서 화면에 다 들어오는 거리까지만 다가갑니다.
--   · 통 스킨은 이제 서버가 테이블마다 하나를 골라 칠합니다. 여기서 덧칠하지 않습니다.
--   · 스킨 이펙트(SkinFX)가 해적에게도 붙습니다.
--   · "장착 중" 표시를 작게 줄이고, 가까이 갔을 때만 뜨게 했습니다.
--
-- Phase 10 에서 고친 것
--   · 잡기 안내가 "아무 키나"라서 스페이스를 누르면 의자에서 일어나 기권 처리됐습니다.
--     이제 잡는 동안에는 점프(스페이스 · 게임패드 A)가 잡기 입력으로만 쓰이고, 의자에서 일어나지 않습니다.
--   · 채팅을 치다가 눌린 키가 잡기로 들어가지 않습니다.
--   · 한 판에 한 번만 잡을 수 있다는 것, 현상금, 배짱("한 번 더")을 화면에 보여 줍니다.
--
-- Phase 11 에서 바뀐 것
--   · 칼 꽂기 모션 스킨 (StabMotion) : 꽂은 사람이 장착한 동작대로 칼과 팔이 움직입니다. AI 선원도 같습니다.
--   · 해적 등장 : 통이 덜컹거림 → (가끔) 가짜 손 → 뚜껑이 날아가며 섬광 → 입을 벌리고 팔을 뻗은 해적.
--     해적은 PirateModel 이 매번 새로 만듭니다. (Visuals.CustomPirate 가 있으면 그 모델을 씁니다)
--   · 해적이 나오기 전에 누르면 바로 탈락입니다. 잡을 때마다 다음 해적이 빨라집니다.
--   · 보물 폭발 · 이월 · AI 승리 · 기권승 절반 보상을 알려 줍니다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Run = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Tags = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local Input = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local package = RS:WaitForChild("CursedBarrel")
local config = require(package.Shared:WaitForChild("GameConfig"))
local SkinFX = require(package.Shared:WaitForChild("SkinFX"))
local remotes = package:WaitForChild("Remotes")
local cues = remotes:WaitForChild("PresentationCue")
local catchPrompt = remotes:WaitForChild(config.Remotes.CatchPrompt)
local catchInput = remotes:WaitForChild(config.Remotes.CatchInput)
local catchResult = remotes:WaitForChild(config.Remotes.CatchResult)
local sabotageCue = remotes:WaitForChild(config.Remotes.SabotageCue)
local visuals = package:WaitForChild("Visuals")
local StabMotion = require(package.Shared:WaitForChild("StabMotion"))
local PirateModel = require(package.Shared:WaitForChild("PirateModel"))
local SKIN_ATTR = config.Skins.PlayerAttributes
local TABLE_ATTR = config.TableAttributes

--------------------------------------------------
-- 연출 수치. 여기 숫자만 바꿔도 화면이 달라집니다.
--------------------------------------------------

-- 평소 카메라.
-- ★ 거리는 반드시 좁은 범위 안에 가둡니다. 개인 무대의 검은 벽이 29스터드 밖에 있어서
--   거리가 그보다 커지면 벽 바깥을 보게 되고 화면이 통째로 까맣게 됩니다.
local FRAME = {
	FOV = 68,
	Pitch = 13,
	Aim = 2.35, -- 통 중심에서 이만큼 위를 봅니다
	Need = 10.4, -- 화면에 담아야 하는 세로 높이(스터드)
	MinDistance = 11,
	MaxDistance = 19, -- ★ 무대 벽(29)보다 한참 안쪽
	MaxShift = 3.2,
	MinEyeLift = 1.2,
	TopReserve = 120,
	BottomReserve = 52,
	Follow = 5,
	TenseZoom = 0.9,
	TenseFOV = -6,
}

-- 해적 클로즈업.
-- ★ 해적이 서는 지점(GhostRise/GhostLunge)은 spawnPirate() 가 쓰는 값과 반드시 같아야 합니다.
--   이 둘이 어긋나면 카메라가 엉뚱한 허공을 봅니다. (Phase 5 의 증상이 정확히 그것이었습니다)
local SCARE = {
	Lead = 0.62, -- 파고들기
	Punch = 0.16, -- 들이닥치기
	Hold = 0.9,
	Release = 0.8,

	GhostRise = 5.2, -- 통 중심에서 해적이 서는 높이
	GhostLunge = 1.5, -- 해적이 카메라 쪽으로 나오는 거리
	GhostFallback = 7.2, -- 키를 재지 못했을 때 쓸 값
	Margin = 1.6, -- 해적 위아래로 남겨 둘 여백

	FarDistance = 15,
	NearDistance = 10.2,
	HitDistance = 7.4,
	Settle = 1.4, -- 들이닥친 뒤 다시 물러나는 거리

	FarFOV = 62,
	NearFOV = 68,
	HitFOV = 82,

	EyeLift = 1.1, -- 바라보는 지점보다 이만큼 위에서 봅니다
	AimLift = 0.5, -- 해적 중심보다 이만큼 위를 봅니다 (가슴~얼굴)
	MinEye = 1, -- 통 중심보다 이보다 낮게 내려가지 않습니다
	MaxDistance = 22, -- 무대 벽(29) 안쪽
}

local STAB = {
	Windup = 0.20,
	TenseWindup = 0.42,
	Thrust = 0.085,
	Settle = 0.12,
	Lift = 1.9,
	Pull = 2.6,
}

local active, lastTable, holdUntil, shakeUntil = nil, nil, 0, 0
local muted, reduced, cameraOn = false, false, true
local function persistSetting(key,value)
 local remote=remotes:FindFirstChild("VoyageRequest");if remote then remote:FireServer("setting",key,value) end
end
local function applySettings()
 muted=(player:GetAttribute("Setting_sfx") or 0.65)<=0
 reduced=player:GetAttribute("Setting_reducedFX")==true
 cameraOn=player:GetAttribute("Setting_camera")~=false
 FRAME.FOV=player:GetAttribute("Setting_wide")==false and 58 or 68
end
for _,key in ipairs({"sfx","reducedFX","camera","wide"}) do player:GetAttributeChangedSignal("Setting_"..key):Connect(applySettings) end
applySettings()
local cameraOwned, originalFOV, originalType, originalSubject = nil, nil, nil, nil
local stage, keyLight, grade = nil, nil, nil
local originalLighting, atmospheres = {}, {}
local lightingKeys = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "ExposureCompensation", "FogColor", "FogStart", "FogEnd" }
for _, key in ipairs(lightingKeys) do
	originalLighting[key] = Lighting[key]
end

local gold = Color3.fromRGB(240, 189, 93)
local cream = Color3.fromRGB(249, 239, 216)
local teal = Color3.fromRGB(101, 241, 211)
local red = Color3.fromRGB(242, 103, 93)

local fx = Instance.new("Folder")
fx.Name = "CursedBarrel_LocalEffects"
fx.Parent = workspace

local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_Phase4"
gui.ResetOnSpawn = false
gui.DisplayOrder = 12
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function textLabel(name, size, position, fontSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = cream
	label.Font = Enum.Font.GothamBold
	label.TextSize = fontSize
	label.TextWrapped = true
	label.Text = ""
	label.Parent = gui
	return label
end

local title = textLabel("Chapter", UDim2.new(0.8, 0, 0, 32), UDim2.new(0.1, 0, 0, 46), 22)
title.TextColor3 = gold
local status = textLabel("Status", UDim2.new(0.86, 0, 0, 34), UDim2.new(0.07, 0, 0, 80), 16)
-- Phase 10 : 현상금 · 내 잡기 기회 · 배짱 단계
local detail = textLabel("Detail", UDim2.new(0.86, 0, 0, 22), UDim2.new(0.07, 0, 0, 112), 14)
detail.TextColor3 = teal
local banner = textLabel("Result", UDim2.new(0.84, 0, 0, 100), UDim2.new(0.08, 0, 0.24, 0), 32)
banner.TextStrokeTransparency = 0.5
banner.TextTransparency = 1

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.Position = UDim2.fromScale(0, 0)
flash.BackgroundColor3 = cream
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 20
flash.Active = false -- 화면을 덮지만 아래의 칼 선택 버튼 입력은 그대로 통과시킵니다.
flash.Parent = gui

local bannerToken = 0
local function announce(message, color, hold)
	bannerToken += 1
	local token = bannerToken
	banner.Text = message
	banner.TextColor3 = color or gold
	banner.TextTransparency = 0
	task.delay(hold or 1.8, function()
		if token == bannerToken then
			Tween:Create(banner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

local function blink(color, strength)
	if reduced then
		return
	end
	flash.BackgroundColor3 = color or cream
	flash.BackgroundTransparency = 1 - (strength or 0.5)
	Tween:Create(flash, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

--------------------------------------------------
-- 해적 잡기 UI
--------------------------------------------------
local catchGui = Instance.new("Frame")
catchGui.Name = "Catch"
catchGui.Size = UDim2.fromScale(1, 1)
catchGui.BackgroundTransparency = 1
catchGui.Visible = false
catchGui.ZIndex = 15
catchGui.Active = false
catchGui.Parent = gui

-- 화면 아무 곳이나 눌러도 잡히도록 전체를 덮는 버튼. 잡기 중에만 켭니다.
local catchButton = Instance.new("TextButton")
catchButton.Name = "Tap"
catchButton.Size = UDim2.fromScale(1, 1)
catchButton.BackgroundTransparency = 1
catchButton.Text = ""
catchButton.AutoButtonColor = false
catchButton.ZIndex = 16
catchButton.Parent = catchGui

local catchRing = Instance.new("Frame")
catchRing.Name = "Ring"
catchRing.AnchorPoint = Vector2.new(0.5, 0.5)
catchRing.Position = UDim2.fromScale(0.5, 0.44)
catchRing.Size = UDim2.fromOffset(320, 320)
catchRing.BackgroundTransparency = 1
catchRing.ZIndex = 17
catchRing.Parent = catchGui
Instance.new("UICorner", catchRing).CornerRadius = UDim.new(1, 0)
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 6
ringStroke.Color = teal
ringStroke.Parent = catchRing

local catchTarget = Instance.new("Frame")
catchTarget.Name = "Target"
catchTarget.AnchorPoint = Vector2.new(0.5, 0.5)
catchTarget.Position = UDim2.fromScale(0.5, 0.44)
catchTarget.Size = UDim2.fromOffset(150, 150)
catchTarget.BackgroundTransparency = 1
catchTarget.ZIndex = 17
catchTarget.Parent = catchGui
Instance.new("UICorner", catchTarget).CornerRadius = UDim.new(1, 0)
local targetStroke = Instance.new("UIStroke")
targetStroke.Thickness = 3
targetStroke.Color = gold
targetStroke.Transparency = 0.35
targetStroke.Parent = catchTarget

local catchText = Instance.new("TextLabel")
catchText.Name = "Prompt"
catchText.AnchorPoint = Vector2.new(0.5, 0.5)
catchText.Position = UDim2.fromScale(0.5, 0.44)
catchText.Size = UDim2.fromOffset(420, 72)
catchText.BackgroundTransparency = 1
catchText.Font = Enum.Font.GothamBlack
catchText.TextSize = 46
catchText.TextColor3 = cream
catchText.TextStrokeTransparency = 0.4
catchText.Text = ""
catchText.ZIndex = 18
catchText.Parent = catchGui

local catchHint = Instance.new("TextLabel")
catchHint.Name = "Hint"
catchHint.AnchorPoint = Vector2.new(0.5, 0)
catchHint.Position = UDim2.fromScale(0.5, 0.62)
catchHint.Size = UDim2.fromOffset(520, 30)
catchHint.BackgroundTransparency = 1
catchHint.Font = Enum.Font.GothamBold
catchHint.TextSize = 18
catchHint.TextColor3 = cream
catchHint.TextTransparency = 0.25
catchHint.Text = ""
catchHint.ZIndex = 18
catchHint.Parent = catchGui

--------------------------------------------------
-- 방해 아이템: 먹물 얼룩 (화면 가장자리만 덮습니다. 가운데는 가리지 않습니다)
--------------------------------------------------
local inkLayer = Instance.new("Frame")
inkLayer.Name = "Ink"
inkLayer.Size = UDim2.fromScale(1, 1)
inkLayer.BackgroundTransparency = 1
inkLayer.Visible = false
inkLayer.Active = false
inkLayer.ZIndex = 19
inkLayer.Parent = gui

local inkBlots = {}
for index = 1, 7 do
	local blot = Instance.new("Frame")
	blot.Name = "Blot" .. index
	blot.AnchorPoint = Vector2.new(0.5, 0.5)
	blot.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	blot.BackgroundTransparency = 0.12
	blot.BorderSizePixel = 0
	blot.ZIndex = 19
	blot.Parent = inkLayer
	Instance.new("UICorner", blot).CornerRadius = UDim.new(1, 0)
	inkBlots[index] = blot
end

local function showInk(duration)
	local camera = workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 1280
	local height = camera and camera.ViewportSize.Y or 720
	local spots = {
		Vector2.new(0.06, 0.12), Vector2.new(0.94, 0.18), Vector2.new(0.12, 0.86),
		Vector2.new(0.88, 0.8), Vector2.new(0.5, 0.06), Vector2.new(0.04, 0.5), Vector2.new(0.96, 0.52),
	}
	for index, blot in ipairs(inkBlots) do
		local spot = spots[index] or Vector2.new(0.5, 0.5)
		local size = math.min(width, height) * (0.22 + (index % 3) * 0.06)
		blot.Position = UDim2.fromScale(spot.X, spot.Y)
		blot.Size = UDim2.fromOffset(size, size)
		blot.BackgroundTransparency = 1
		Tween:Create(blot, TweenInfo.new(0.25), { BackgroundTransparency = 0.12 }):Play()
	end
	inkLayer.Visible = true
	task.delay(duration or 6, function()
		for _, blot in ipairs(inkBlots) do
			Tween:Create(blot, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		end
		task.delay(0.55, function()
			inkLayer.Visible = false
		end)
	end)
end

--------------------------------------------------
-- 설정
--------------------------------------------------
local settings = Instance.new("Frame")
settings.Name = "Settings"
settings.Size = UDim2.fromOffset(174, 184)
settings.Position = UDim2.new(1, -186, 0, 140)
settings.BackgroundColor3 = Color3.fromRGB(24, 28, 32)
settings.BackgroundTransparency = 0.12
settings.Visible = false
settings.Parent = gui
Instance.new("UICorner", settings).CornerRadius = UDim.new(0, 10)

local function button(parent, caption, position, size, callback)
	local b = Instance.new("TextButton")
	b.Text = caption
	b.Position = position
	b.Size = size
	b.BackgroundColor3 = Color3.fromRGB(38, 48, 53)
	b.TextColor3 = cream
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	b.Activated:Connect(function()
		callback(b)
	end)
	return b
end

button(gui, "설정", UDim2.new(1, -82, 0, 104), UDim2.fromOffset(70, 30), function()
	settings.Visible = not settings.Visible
end)
button(settings, "효과음: 켜짐", UDim2.fromOffset(8, 8), UDim2.fromOffset(158, 36), function(b)
	muted = not muted
    persistSetting("sfx",muted and 0 or 0.65)
	b.Text = muted and "효과음: 꺼짐" or "효과음: 켜짐"
end)
button(settings, "놀람 연출: 켜짐", UDim2.fromOffset(8, 52), UDim2.fromOffset(158, 36), function(b)
	-- 화면 흔들림 · 번쩍임 · 클로즈업을 한 번에 줄입니다. (빛 과민 사용자 배려)
	reduced = not reduced
    persistSetting("reducedFX",reduced)
	b.Text = reduced and "놀람 연출: 꺼짐" or "놀람 연출: 켜짐"
end)
button(settings, "테이블 카메라: 켜짐", UDim2.fromOffset(8, 96), UDim2.fromOffset(158, 36), function(b)
	cameraOn = not cameraOn
    persistSetting("camera",cameraOn)
	b.Text = cameraOn and "테이블 카메라: 켜짐" or "테이블 카메라: 꺼짐"
end)
button(settings, "화각 넓게: 켜짐", UDim2.fromOffset(8, 140), UDim2.fromOffset(158, 36), function(b)
	FRAME.FOV = (FRAME.FOV > 64) and 58 or 68
    persistSetting("wide",FRAME.FOV>64)
	b.Text = (FRAME.FOV > 64) and "화각 넓게: 켜짐" or "화각 넓게: 꺼짐"
end)

--------------------------------------------------
-- 첫 판 안내
--------------------------------------------------
local tutorial = Instance.new("Frame")
tutorial.Name = "Tutorial"
tutorial.AnchorPoint = Vector2.new(0, 0.5)
tutorial.Position = UDim2.new(0, 22, 0.5, 0)
tutorial.Size = UDim2.fromOffset(318, 290)
tutorial.BackgroundColor3 = Color3.fromRGB(24, 20, 16)
tutorial.BackgroundTransparency = 0.08
tutorial.BorderSizePixel = 0
tutorial.ZIndex = 14
tutorial.Parent = gui
Instance.new("UICorner", tutorial).CornerRadius = UDim.new(0, 14)
local tutorialStroke = Instance.new("UIStroke")
tutorialStroke.Color = gold
tutorialStroke.Thickness = 2
tutorialStroke.Transparency = 0.3
tutorialStroke.Parent = tutorial

local function tutorialLine(text, y, color, size)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(16, y)
	label.Size = UDim2.new(1, -32, 0, size and 24 or 22)
	label.Font = Enum.Font.GothamBold
	label.TextSize = size or 14
	label.TextColor3 = color or cream
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.ZIndex = 15
	label.Parent = tutorial
	return label
end
tutorialLine("처음이신가요?", 14, gold, 18)
tutorialLine("1.  의자에 다가가 E · 모바일은 탭", 48)
tutorialLine("2.  내 차례가 오면 아래에서 자리를 고르기", 74)
tutorialLine("3.  저주받은 자리를 뽑으면 해적이 튀어나옵니다", 100)
tutorialLine("     고리가 줄어들 때 눌러 잡으면 살아남아요", 124, teal)
tutorialLine("     나오기 전에 누르면 탈락! 잡을수록 점점 빨라져요", 148, red)
tutorialLine("4.  안전하면 「한 번 더」로 보너스 코인", 172)
tutorialLine("5.  마지막 생존자가 현상금을 가져갑니다", 196)
tutorialLine("바닥 화살표를 따라가면 빈 자리가 나옵니다", 222, Color3.fromRGB(168, 152, 128))
-- Phase 12 : AI 선원 둘과 연습 한 판 (처음 해적은 잡기 쉽다)
button(tutorial, "연습 한 판", UDim2.new(1, -196, 1, -34), UDim2.fromOffset(92, 26), function()
	tutorial.Visible = false
	local r = remotes:FindFirstChild("VoyageRequest")
	if r then
		r:FireServer("practice")
	end
end)
button(tutorial, "알겠어요", UDim2.new(1, -96, 1, -34), UDim2.fromOffset(84, 26), function()
	tutorial.Visible = false
    local r=remotes:FindFirstChild("VoyageRequest");if r then r:FireServer("tutorial") end
end)

--------------------------------------------------
-- 소리
--------------------------------------------------
player:GetAttributeChangedSignal("TutorialDone"):Connect(function() if player:GetAttribute("TutorialDone") then tutorial.Visible=false end end)
if player:GetAttribute("TutorialDone") then tutorial.Visible=false end

local function sound(kind, pitch, volume)
	if muted then
		return
	end
	local paths = {
		tick = "volume_slider.ogg", pick = "action_jump_land.mp3",
		danger = "impact_explosion_03.mp3", win = "volume_slider.ogg",
		riser = "action_falling.mp3", heart = "action_jump_land.mp3",
	}
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/" .. (paths[kind] or paths.tick)
	s.Volume = (volume or (kind == "danger" and 0.22 or 0.25))*(player:GetAttribute("Setting_sfx") or 0.65)
    local audio=require(package.Shared.ReleaseConfig).Audio
    local id=({danger=audio.Dragon,pick=audio.Impact,win=audio.Win})[kind]
    if id and id>0 then s.SoundId="rbxassetid://"..id end
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 6)
	return s
end

--------------------------------------------------
-- 테이블 찾기
--------------------------------------------------
local function tableOfCharacter()
	local char = player.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then
		return nil
	end
	local node = h.SeatPart
	while node and node ~= workspace do
		if node:IsA("Model") and Tags:HasTag(node, config.Tags.Table) then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- 이 테이블에서 내가 앉은(또는 앉았던) 좌석
local function seatOf(model)
	local seats = model and model:FindFirstChild("Seats")
	if not seats then
		return nil
	end
	for _, seat in ipairs(seats:GetDescendants()) do
		if seat:IsA("Seat") and seat:GetAttribute(config.SeatAttributes.OccupantUserId) == player.UserId then
			return seat
		end
	end
	return nil
end

local function center(model)
	local barrel = model and model:FindFirstChild("Barrel")
	local body = barrel and barrel:FindFirstChild("Body")
	return body and body.Position
end

local function lidTop(model)
	local barrel = model and model:FindFirstChild("Barrel")
	local lid = barrel and barrel:FindFirstChild("Lid")
	if lid then
		return lid.Position + Vector3.new(0, lid.Size.Y * 0.5, 0)
	end
	local pos = center(model)
	return pos and pos + Vector3.new(0, 2.4, 0)
end

local function tensionOf(model)
	if not model then
		return 0
	end
	local alive = model:GetAttribute(TABLE_ATTR.TurnCount) or 0
	local left = model:GetAttribute(TABLE_ATTR.SlotsRemaining) or 99
	local value = 0
	if alive == 2 then
		value = math.max(value, 0.75)
	end
	if left <= 1 then
		value = 1
	elseif left <= 2 then
		value = math.max(value, 0.9)
	elseif left <= 3 then
		value = math.max(value, 0.55)
	elseif left <= 5 then
		value = math.max(value, 0.3)
	end
	return value
end

--------------------------------------------------
-- 무대
--------------------------------------------------
local function restoreCamera()
	if cameraOwned then
		cameraOwned.CameraType = originalType or Enum.CameraType.Custom
		cameraOwned.FieldOfView = originalFOV or 70
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		cameraOwned.CameraSubject = h or originalSubject
		cameraOwned = nil
	end
end

local hiddenBoards = {}
local function leaveStage()
	if stage then
		stage:Destroy()
		stage = nil
		keyLight = nil
	end
	if grade then
		grade:Destroy()
		grade = nil
	end
	-- Phase 12 : 하늘(시간 · 밝기)은 WorldController 가 항해 시계대로 맡는다. 안개 값만 되돌린다.
	local weatherOwned = Lighting:GetAttribute("WeatherOwned") == true
	for _, key in ipairs(lightingKeys) do
		if not weatherOwned or key == "FogColor" or key == "FogStart" or key == "FogEnd" then
			Lighting[key] = originalLighting[key]
		end
	end
	for _, a in ipairs(atmospheres) do
		a.Parent = Lighting
	end
	table.clear(atmospheres)
	for board, wasEnabled in pairs(hiddenBoards) do
		if board.Parent then
			board.Enabled = wasEnabled
		end
	end
	table.clear(hiddenBoards)
	restoreCamera()
end

local function makePart(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function enterStage(model)
	leaveStage()
	local pos = center(model)
	if not pos then
		return
	end
	stage = Instance.new("Folder")
	stage.Name = "PrivateTableStage"
	stage.Parent = fx
	-- 같은 테이블 참가자의 각 기기에만 존재하는 검은 무대. 서버 맵은 변경하지 않습니다.
	local black = Color3.fromRGB(2, 4, 7)
	for _, v in ipairs({ Vector3.new(0, 0, -29), Vector3.new(0, 0, 29) }) do
		makePart(stage, "Backdrop", Vector3.new(60, 90, 1), CFrame.new(pos + v), black)
	end
	for _, v in ipairs({ Vector3.new(-29, 0, 0), Vector3.new(29, 0, 0) }) do
		makePart(stage, "Backdrop", Vector3.new(1, 90, 60), CFrame.new(pos + v), black)
	end
	makePart(stage, "Ceiling", Vector3.new(60, 1, 60), CFrame.new(pos + Vector3.new(0, 38, 0)), black)

	for _, a in ipairs(Lighting:GetChildren()) do
		if a:IsA("Atmosphere") then
			table.insert(atmospheres, a)
			a.Parent = nil
		end
	end
	Lighting.Ambient = Color3.fromRGB(52, 58, 65)
	Lighting.OutdoorAmbient = Color3.fromRGB(8, 12, 18)
	Lighting.Brightness = 0.35
	Lighting.ClockTime = 0
	Lighting.ExposureCompensation = 0.25
	-- 안개는 카메라가 가장 멀리 물러났을 때보다 뒤에서 시작해야 통이 흐려지지 않습니다.
	Lighting.FogColor = black
	Lighting.FogStart = 26
	Lighting.FogEnd = 46

	keyLight = makePart(stage, "SoftKey", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(0, 6, 0)), cream)
	keyLight.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 216, 159)
	light.Brightness = 3.2
	light.Range = 26
	light.Shadows = false
	light.Parent = keyLight

	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "CursedBarrel_Tension"
	grade.Saturation = 0
	grade.Contrast = 0
	grade.Brightness = 0
	grade.Parent = Lighting
end

local function animatePivot(model, from, to, duration, style, direction)
	local value = Instance.new("CFrameValue")
	value.Value = from
	model:PivotTo(from)
	local connection = value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Back, direction or Enum.EasingDirection.Out)
	local tween = Tween:Create(value, info, { Value = to })
	tween.Completed:Once(function()
		connection:Disconnect()
		value:Destroy()
	end)
	tween:Play()
	return tween
end

local function burst(pos, color, count)
	for i = 1, count do
		local angle = i * math.pi * 2 / count
		local p = makePart(fx, "Spark", Vector3.new(0.14, 0.3, 0.14), CFrame.new(pos), color)
		p.Material = Enum.Material.Neon
		local offset = Vector3.new(math.cos(angle) * 4, 1 + (i % 4), math.sin(angle) * 4)
		Tween:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(pos + offset) * CFrame.Angles(i, i, 0), Transparency = 1, Size = Vector3.new(0.03, 0.03, 0.03) }):Play()
		Debris:AddItem(p, 0.85)
	end
end

local function shockRing(cf, color)
	local ring = makePart(fx, "Shock", Vector3.new(0.6, 0.6, 0.08), cf, color or gold)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.15
	Tween:Create(ring, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = Vector3.new(4.2, 4.2, 0.02), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
end

--------------------------------------------------
-- 카메라
--------------------------------------------------
local shot = nil
local ghostHeight = SCARE.GhostFallback -- 해적 모형의 실제 키. 처음 한 번 재고 기억합니다.

local function pickerReserve()
	local picker = player.PlayerGui:FindFirstChild("CursedBarrel_KnifePicker")
	local panel = picker and picker:FindFirstChild("Panel")
	if not (picker and picker.Enabled and panel and panel.Visible) then
		return FRAME.BottomReserve
	end
	local camera = workspace.CurrentCamera
	local height = camera and camera.ViewportSize.Y or 720
	return math.clamp(height - panel.AbsolutePosition.Y + 12, FRAME.BottomReserve, height * 0.5)
end

local function framing(camera, tension)
	local height = camera.ViewportSize.Y
	local usable = math.clamp(height - FRAME.TopReserve - pickerReserve(), 150, height)
	local fov = math.clamp(FRAME.FOV + FRAME.TenseFOV * tension, 45, 100)
	local distance = (FRAME.Need * height / usable) / (2 * math.tan(math.rad(fov) * 0.5))
	distance = math.clamp(distance, FRAME.MinDistance, FRAME.MaxDistance)
	distance *= (1 - (1 - FRAME.TenseZoom) * tension)
	local bandCenter = (FRAME.TopReserve + usable * 0.5) / height
	local viewHeight = 2 * distance * math.tan(math.rad(fov) * 0.5)
	local shift = math.clamp((bandCenter - 0.5) * viewHeight, -FRAME.MaxShift, FRAME.MaxShift)
	return distance, shift, fov
end

local function facing(pos)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local delta = root and Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z) or Vector3.new(0, 0, 1)
	if delta.Magnitude < 0.1 then
		delta = Vector3.new(0, 0, 1)
	end
	return delta.Unit
end

local function standardShot(camera, pos, tension)
	local distance, shift, fov = framing(camera, tension)
	local direction = facing(pos)
	local subject = pos + Vector3.new(0, FRAME.Aim, 0)
	local pitch = math.rad(FRAME.Pitch)
	local eye = subject + direction * (distance * math.cos(pitch)) + Vector3.new(0, distance * math.sin(pitch), 0)
	local cf = CFrame.lookAt(eye, subject)
	cf = cf + cf.UpVector * shift
	if cf.Position.Y < pos.Y + FRAME.MinEyeLift then
		cf = CFrame.lookAt(Vector3.new(cf.Position.X, pos.Y + FRAME.MinEyeLift, cf.Position.Z), subject)
	end
	return cf, fov
end

--[[
	해적 클로즈업.

	★ 고친 핵심
	  해적이 실제로 서는 지점을 먼저 구합니다.  spawnPirate() 와 같은 식을 씁니다.
	     ghostCenter = 통 중심 + 나를 향한 방향 * GhostLunge + (0, GhostRise, 0)
	  그리고 해적의 키를 재서, 화면에 다 들어오는 최소 거리를 계산합니다.
	     needed = (키 + 여백) / (2 * tan(화각/2))
	  이 거리보다 가까이는 절대 붙지 않습니다. 그래서
	     - 해적이 화면 밖으로 벗어나지 않고
	     - 카메라가 해적을 뚫고 지나가지도 않습니다.
]]
local function closeShot(model, pos, elapsed)
	local lidPoint = lidTop(model) or (pos + Vector3.new(0, 2.4, 0))
	local direction = facing(pos)
	local ghostCenter = pos + direction * SCARE.GhostLunge + Vector3.new(0, SCARE.GhostRise, 0)
	local ghostAim = ghostCenter + Vector3.new(0, SCARE.AimLift, 0)

	local lead, punch, hold = SCARE.Lead, SCARE.Punch, SCARE.Hold
	local distance, fov, aim

	if elapsed < lead then
		-- 통 쪽으로 천천히 파고듭니다. 아직 해적은 나오지 않았습니다.
		local a = math.clamp(elapsed / lead, 0, 1)
		a = a * a * (3 - 2 * a)
		distance = SCARE.FarDistance + (SCARE.NearDistance - SCARE.FarDistance) * a
		fov = SCARE.FarFOV + (SCARE.NearFOV - SCARE.FarFOV) * a
		aim = lidPoint:Lerp(ghostAim, a * 0.55)
	elseif elapsed < lead + punch then
		-- 들이닥치는 순간. 시선이 해적에게 완전히 옮겨갑니다.
		local a = (elapsed - lead) / punch
		distance = SCARE.NearDistance + (SCARE.HitDistance - SCARE.NearDistance) * a
		fov = SCARE.NearFOV + (SCARE.HitFOV - SCARE.NearFOV) * a
		aim = lidPoint:Lerp(ghostAim, 0.55 + 0.45 * a)
	elseif elapsed < lead + punch + hold then
		-- 해적을 정면으로 두고 천천히 물러납니다. 잡기 창이 열려 있는 구간입니다.
		local a = (elapsed - lead - punch) / hold
		distance = SCARE.HitDistance + SCARE.Settle * a
		fov = SCARE.HitFOV + (SCARE.NearFOV - SCARE.HitFOV) * a
		aim = ghostAim
	else
		distance, fov, aim = SCARE.HitDistance + SCARE.Settle, SCARE.NearFOV, ghostAim
	end

	-- ★ 해적이 화면에 다 들어오는 최소 거리. 이보다 가까이 붙지 않습니다.
	--   바라보는 지점(ghostAim)은 해적 중심보다 AimLift 만큼 위에 있고,
	--   눈높이는 거기서 EyeLift 만큼 더 위에 있습니다. 그만큼 머리끝이 화면 위로 밀리므로
	--   "해적 키의 절반"이 아니라 그 두 값까지 더한 높이를 담을 수 있어야 합니다.
	local halfNeeded = ghostHeight * 0.5 + SCARE.AimLift + SCARE.EyeLift + SCARE.Margin * 0.5
	local needed = halfNeeded / math.tan(math.rad(fov) * 0.5)
	distance = math.clamp(math.max(distance, needed), 3, SCARE.MaxDistance)

	local eye = aim + direction * distance + Vector3.new(0, SCARE.EyeLift, 0)
	if eye.Y < pos.Y + SCARE.MinEye then
		eye = Vector3.new(eye.X, pos.Y + SCARE.MinEye, eye.Z)
	end

	return CFrame.lookAt(eye, aim), fov
end

--------------------------------------------------
-- 칼 꽂기
--------------------------------------------------
-- 칼을 꽂은 사람의 몸. 사람은 Players 에서, AI 선원은 좌석에 적힌 UserId 로 찾는다.
local function characterOfUser(model, userId)
	local picker = Players:GetPlayerByUserId(userId or 0)
	if picker then
		return picker.Character
	end
	local seats = model and model:FindFirstChild("Seats")
	if seats and userId and userId ~= 0 then
		for _, seat in ipairs(seats:GetDescendants()) do
			if seat:IsA("Seat") and seat:GetAttribute(config.SeatAttributes.OccupantUserId) == userId and seat.Occupant then
				return seat.Occupant.Parent
			end
		end
	end
	return nil
end

-- 칼날이 지나간 자리에 남는 빛 (모션 스킨 색)
local function addTrail(copy, color)
	local blade = copy:FindFirstChild("Blade")
	if not blade or not color then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -0.7)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, 0.7)
	a1.Parent = blade
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Lifetime = 0.2
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.FaceCamera = true
	trail.Parent = blade
end

--[[
	칼 꽂기 (Phase 11 : 모션 스킨)
	꽂은 사람이 장착한 모션(StabSkin)대로 칼이 움직이고 팔 · 허리가 따라 움직인다.
	칼이 닿는 순간마다 충격 고리가 퍼진다. (세 번 찌르기는 작은 고리 둘 + 큰 고리 하나)
	돌려주는 값 = 칼이 완전히 꽂히기까지 걸리는 시간.
]]
local function stab(model, index, own, tension, userId, styleId)
	local slots = model:FindFirstChild("KnifeSlots")
	if not slots then
		return 0
	end
	for _, slot in ipairs(slots:GetChildren()) do
		if slot:GetAttribute(config.SlotAttributes.SlotIndex) == index then
			local source = slot:FindFirstChild("Knife")
			if not source then
				return 0
			end
			local motion = config.findSkin("Stab", styleId) or config.Skins.Stab[1]
			local windup = own and (STAB.Windup + (STAB.TenseWindup - STAB.Windup) * tension) or STAB.Windup * 0.5
			local plan = StabMotion.plan(motion.style, windup, motion.color)
			local copy = source:Clone()
			copy.Parent = fx
			local restore = {}
			for _, p in ipairs(source:GetDescendants()) do
				if p:IsA("BasePart") then
					restore[p] = p.LocalTransparencyModifier
					p.LocalTransparencyModifier = 1
				end
			end
			for _, p in ipairs(copy:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Transparency = 0
					p.LocalTransparencyModifier = 0
					p.CanQuery = false
					p.CanTouch = false
					p.CanCollide = false
				end
			end
			if plan.style ~= "classic" and not reduced then
				addTrail(copy, plan.color)
			end

			local ctx = { target = copy:GetPivot(), look = slot.CFrame.LookVector, center = center(model) }
			copy:PivotTo(StabMotion.knifeAt(plan, 0, ctx))
			StabMotion.playBody(characterOfUser(model, userId), plan)
			if own then
				sound("tick", 1.5 + 0.4 * tension, 0.12)
			end

			local started = os.clock()
			local follow
			follow = Run.RenderStepped:Connect(function()
				if not copy.Parent then
					follow:Disconnect()
					return
				end
				local t = os.clock() - started
				if t >= plan.total then
					copy:PivotTo(ctx.target)
					follow:Disconnect()
					return
				end
				copy:PivotTo(StabMotion.knifeAt(plan, t, ctx))
			end)

			for i, hit in ipairs(plan.hits) do
				local final = i == #plan.hits
				task.delay(hit.t, function()
					if not copy.Parent then
						return
					end
					local color = (final and plan.style == "classic") and gold or (plan.color or gold)
					shockRing(slot.CFrame, color)
					burst(slot.Position, color, reduced and 4 or math.floor(6 + 6 * hit.power))
					if own then
						sound("pick", final and 1.55 or 2.1, final and 0.3 or 0.14)
						if not reduced and final then
							shakeUntil = math.max(shakeUntil, os.clock() + 0.12 + 0.06 * hit.power)
						end
					end
					if not final then
						return
					end
					if plan.style == "bolt" and not reduced then
						-- 번개 한 줄기가 칼을 따라 내리꽂힌다
						local bolt = makePart(fx, "StabBolt", Vector3.new(0.35, 12, 0.35), CFrame.new(slot.Position + Vector3.new(0, 6, 0)), plan.color or cream)
						bolt.Material = Enum.Material.Neon
						Tween:Create(bolt, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.05, 12, 0.05) }):Play()
						Debris:AddItem(bolt, 0.35)
						if own then
							blink(Color3.fromRGB(220, 235, 255), 0.35)
						end
					end
					if hit.power >= 1.4 and not reduced then
						-- 강한 모션은 충격 고리가 한 겹 더 퍼진다
						task.delay(0.06, function()
							shockRing(slot.CFrame * CFrame.new(0, 0, -0.2), gold)
						end)
					end
					task.delay(STAB.Settle, function()
						for p, value in pairs(restore) do
							if p.Parent then
								p.LocalTransparencyModifier = value
							end
						end
						if copy.Parent then
							copy:Destroy()
						end
					end)
				end)
			end
			return plan.total
		end
	end
	return 0
end

--------------------------------------------------
-- 해적
--
-- ★ 서는 지점은 SCARE.GhostRise / GhostLunge 를 씁니다.
--   카메라(closeShot)가 같은 값으로 바라보기 때문에 둘을 따로 고치면 안 됩니다.
--------------------------------------------------
local ghostLive = nil -- 지금 잡기 중인 진짜 해적 (결과가 오면 물러나거나 달려든다)

local function outBack(x)
	local c1, c3 = 1.9, 2.9
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- 이 테이블 통의 뚜껑. (서버 것이다. 내 화면에서만 잠깐 흔들거나 숨긴다)
local function lidOf(model)
	local barrel = model and model:FindFirstChild("Barrel")
	local lid = barrel and barrel:FindFirstChild("Lid")
	return (lid and lid:IsA("BasePart")) and lid or nil
end

local lidBusy = setmetatable({}, { __mode = "k" }) -- [lid] = { home, joltUntil }
-- 뚜껑의 제자리. 게임 전(대기 · 카운트다운)에 본 자리를 기억한다.
-- 서버가 뚜껑을 튕기는 중에(위험 자리 연출) 잰 자리를 제자리로 믿으면, 뚜껑이 공중에 남을 수 있다.
local lidRest = setmetatable({}, { __mode = "k" })
local function restOf(model, lid)
	local rest = lidRest[lid]
	if rest then
		return rest
	end
	local state = model:GetAttribute(TABLE_ATTR.State)
	if state ~= "Playing" and state ~= "Starting" then
		lidRest[lid] = lid.CFrame
		return lid.CFrame
	end
	return nil
end

-- 해적이 나오기 전 : 통이 덜컹거린다. 점점 세진다.
local function rattle(model, fromClock, toClock)
	local lid = lidOf(model)
	if not lid or reduced or toClock - fromClock < 0.25 then
		return
	end
	task.delay(math.max(0, fromClock - os.clock()), function()
		if not lid.Parent or lidBusy[lid] then
			return
		end
		local home = restOf(model, lid) or lid.CFrame
		lidBusy[lid] = { home = home }
		local knock = 0
		local conn
		conn = Run.RenderStepped:Connect(function()
			local now = os.clock()
			if now >= toClock or not lid.Parent then
				conn:Disconnect()
				-- 뚜껑이 날아가지 않았으면(연출을 줄였거나 분노한 해적) 원래 자리로 돌려놓는다.
				if lid.Parent and lidBusy[lid] and lidBusy[lid].home == home and lid.LocalTransparencyModifier < 1 then
					lid.CFrame = home
					lidBusy[lid] = nil
				end
				return
			end
			local busy = lidBusy[lid]
			if not busy or busy.home ~= home then
				conn:Disconnect()
				return
			end
			local a = math.clamp((now - fromClock) / math.max(0.01, toClock - fromClock), 0, 1)
			local amp = 0.04 + 0.22 * a * a
			local jolt = (busy.joltUntil or 0) > now and 0.45 or 0
			lid.CFrame = home * CFrame.new(0, math.abs(math.sin(now * 38)) * amp + jolt, 0)
				* CFrame.Angles(math.sin(now * 51) * amp * 0.35, 0, math.cos(now * 47) * amp * 0.35)
			if now > knock then
				knock = now + 0.32 - 0.2 * a
				sound("heart", 0.5 + 0.3 * a, 0.08 + 0.12 * a)
			end
		end)
	end)
end

-- 가짜 손 : 뚜껑 틈으로 뼈 손이 튀어나왔다가 들어간다. 여기에 속아 누르면 "너무 빨랐다".
local function feint(model, atClock)
	local top = lidTop(model)
	if not top or reduced then
		return
	end
	task.delay(math.max(0, atClock - os.clock()), function()
		local skin = config.findSkin("Ghost", player:GetAttribute(SKIN_ATTR.Ghost)) or {}
		local hand = Instance.new("Model")
		hand.Name = "FeintHand"
		local palm = makePart(hand, "Palm", Vector3.new(0.6, 0.5, 0.6), CFrame.new(), skin.skin or teal)
		palm.Shape = Enum.PartType.Ball
		palm.Material = Enum.Material.Neon
		hand.PrimaryPart = palm
		for f = -1, 1 do
			local bone = makePart(hand, "Finger", Vector3.new(0.1, 0.55, 0.1), CFrame.new(f * 0.18, 0.45, 0) * CFrame.Angles(0, 0, math.rad(f * 12)), Color3.fromRGB(240, 236, 220))
			bone.Material = Enum.Material.SmoothPlastic
		end
		hand.Parent = fx
		local side = facing(top) * 0.6
		local low = CFrame.new(top + side - Vector3.new(0, 0.6, 0))
		local high = CFrame.new(top + side + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, 0, math.rad(-15))
		animatePivot(hand, low, high, 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		sound("pick", 0.55, 0.22)
		local lid = lidOf(model)
		if lid and lidBusy[lid] then
			-- 뚜껑이 한 번 크게 들썩인다 (덜컹거리는 쪽이 이 값을 보고 들어 올린다)
			lidBusy[lid].joltUntil = os.clock() + 0.14
		end
		task.delay(0.22, function()
			if hand.Parent then
				animatePivot(hand, hand:GetPivot(), low, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
		Debris:AddItem(hand, 0.45)
	end)
end

-- 뚜껑이 날아가고 섬광이 터진다. 진짜 뚜껑은 잠깐 숨겼다가 되돌린다.
local function blowLid(model, hold)
	local lid = lidOf(model)
	local top = lidTop(model)
	if top then
		local flashBall = makePart(fx, "Burst", Vector3.new(1, 1, 1), CFrame.new(top), Color3.fromRGB(210, 255, 240))
		flashBall.Shape = Enum.PartType.Ball
		flashBall.Material = Enum.Material.Neon
		flashBall.Transparency = 0.1
		local light = Instance.new("PointLight")
		light.Brightness = 9
		light.Range = 22
		light.Color = Color3.fromRGB(150, 255, 220)
		light.Parent = flashBall
		Tween:Create(flashBall, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(7, 7, 7), Transparency = 1 }):Play()
		Tween:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
		Debris:AddItem(flashBall, 0.45)

		local mist = makePart(fx, "Mist", Vector3.new(0.2, 0.2, 0.2), CFrame.new(top), cream)
		mist.Transparency = 1
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(120, 255, 214), Color3.fromRGB(40, 60, 70))
		emitter.Size = NumberSequence.new(1.2, 4)
		emitter.Transparency = NumberSequence.new(0.3, 1)
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Speed = NumberRange.new(6, 12)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Rate = 0
		emitter.Parent = mist
		emitter:Emit(reduced and 8 or 28)
		Debris:AddItem(mist, 1.4)
	end
	if not lid then
		return
	end
	local busy = lidBusy[lid]
	local home = (busy and busy.home) or restOf(model, lid) or lid.CFrame
	lidBusy[lid] = { home = home }
	local flying = lid:Clone()
	flying.Anchored = true
	flying.CanCollide = false
	flying.CanQuery = false
	flying.CanTouch = false
	flying:ClearAllChildren()
	flying.Parent = fx
	lid.LocalTransparencyModifier = 1
	local away = facing(lid.Position) * -2.5
	local goal = CFrame.new(home.Position + Vector3.new(away.X, 6.5, away.Z)) * home.Rotation * CFrame.Angles(math.rad(150), 0, math.rad(40))
	Tween:Create(flying, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal }):Play()
	task.delay(0.35, function()
		Tween:Create(flying, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(flying, 0.8)
	task.delay(hold, function()
		if lid.Parent then
			lid.CFrame = home
			lid.LocalTransparencyModifier = 0
		end
		if lidBusy[lid] and lidBusy[lid].home == home then
			lidBusy[lid] = nil
		end
	end)
end

--[[
	해적 (Phase 11)
	kind
	  "real" : 잡기 중인 진짜 해적. 결과가 오면 물러나거나(잡힘) 달려든다(탈락).
	  "rage" : 분노한 해적. 잡을 수 없다. 튀어나오자마자 달려든다.
	  "fake" : 방해 아이템 "해적의 포효". 잠깐 나왔다 사라진다.
	자세는 매 프레임 PirateModel:pose 로 잡는다. 서는 지점은 SCARE.GhostRise / GhostLunge 와 같다.
]]
local function spawnPirate(model, own, kind)
	local pos = center(model)
	if not pos then
		return nil
	end
	kind = kind or "real"
	local skin = config.findSkin("Ghost", player:GetAttribute(SKIN_ATTR.Ghost))
	local rig = PirateModel.new(skin, visuals)
	rig.model.Parent = fx
	if skin then
		SkinFX.applyGhost(rig.model, skin)
	end
	rig:adopt(CFrame.new())
	ghostHeight = rig.height or SCARE.GhostFallback
	if kind == "rage" then
		for _, item in ipairs(rig.items) do
			if item.part.Name == "Eye" or item.part.Name == "Claw" or item.part.Name == "Socket" then
				item.part.Color = Color3.fromRGB(255, 60, 50)
				item.part.Material = Enum.Material.Neon
			end
		end
	end

	local direction = facing(pos)
	local base = CFrame.lookAt(pos, pos + direction)
	local lunge = (own and not reduced) and SCARE.GhostLunge or 0
	local ghost = { rig = rig, state = "erupt", bornAt = os.clock(), kind = kind, stateAt = os.clock(), fade = 0 }

	local function place(y, forward, pose)
		rig:pose(base * CFrame.new(0, y, -forward), pose)
	end
	place(-2.4, 0, { reach = 0, jaw = 0 })

	local conn
	conn = Run.RenderStepped:Connect(function()
		if not rig.model.Parent then
			conn:Disconnect()
			return
		end
		local now = os.clock()
		local t = now - ghost.bornAt
		local s = now - ghost.stateAt
		local rise = SCARE.GhostRise
		if ghost.state == "caught" then
			-- 붙잡혀 통 속으로 끌려 들어간다
			local a = math.clamp(s / 0.3, 0, 1)
			place(rise + (-3 - rise) * a * a, lunge * (1 - a), { lean = 10 * (1 - a), reach = 0.8 * (1 - a), jaw = 0.6, spread = 30 * a, sway = 20 * a })
			rig:fade(a * 0.7)
			if a >= 1 then
				ghost.state = "gone"
			end
		elseif ghost.state == "lunge" then
			-- 달려든다 (카메라 쪽으로)
			local a = math.clamp(s / 0.22, 0, 1)
			local e = 1 - (1 - a) ^ 3
			place(rise - 0.4 * e, lunge + 2.6 * e, { lean = 16 + 22 * e, reach = 1, jaw = 1, claw = 25 * e, nod = -12 * e })
			if s > 0.55 then
				rig:fade(math.clamp((s - 0.55) / 0.4, 0, 1))
			end
			if s > 1 then
				ghost.state = "gone"
			end
		elseif ghost.state == "fading" then
			local a = math.clamp(s / 0.4, 0, 1)
			place(rise + 0.5 * a, lunge, { lean = 8, reach = 0.6, jaw = 0.3 })
			rig:fade(a)
			if a >= 1 then
				ghost.state = "gone"
			end
		elseif ghost.state == "gone" then
			conn:Disconnect()
			rig:Destroy()
			return
		elseif t < 0.2 then
			-- 튀어나온다 (위로 치솟았다가 살짝 되돌아온다)
			local a = t / 0.2
			local y = -2.4 + (rise + 2.4) * outBack(a)
			place(y, lunge * a, { lean = 28 * a, reach = a, jaw = a, spread = 40 * (1 - a), nod = -15 * a })
		elseif t < 0.5 then
			local a = (t - 0.2) / 0.3
			place(rise, lunge, { lean = 28 - 14 * a, reach = 1 - 0.2 * a, jaw = 1 - 0.45 * a, nod = -15 + 15 * a, claw = 20 * a })
		else
			-- 떠 있다. 몸이 출렁이고 턱이 딱딱거린다.
			local bob = math.sin(t * 5.2) * 0.18
			place(rise + bob, lunge, {
				lean = 12 + math.sin(t * 3.1) * 3,
				reach = 0.78 + math.sin(t * 6.3) * 0.08,
				jaw = 0.35 + 0.25 * math.abs(math.sin(t * 13)),
				claw = 12 + math.sin(t * 9) * 10,
				sway = math.sin(t * 4) * 10,
				nod = math.sin(t * 2.4) * 4,
			})
			if kind == "fake" and t > 1.1 then
				ghost.state, ghost.stateAt = "fading", now
			elseif kind == "rage" and t > 0.75 then
				ghost.state, ghost.stateAt = "lunge", now
			end
		end
		-- 너무 오래 남지 않게 (결과가 끝내 오지 않아도 사라진다)
		if t > SCARE.Hold + SCARE.Release + 2.4 and ghost.state ~= "gone" and ghost.state ~= "fading" then
			ghost.state, ghost.stateAt = "fading", now
		end
	end)

	burst(pos + Vector3.new(0, 2, 0), (skin and skin.aura) or teal, reduced and 8 or 22)
	if kind == "real" then
		ghostLive = ghost
	end
	return ghost
end

local function setGhostState(ghost, state)
	if ghost and ghost.rig and ghost.rig.model.Parent and ghost.state ~= "gone" then
		ghost.state = state
		ghost.stateAt = os.clock()
	end
end

-- 튀어나오는 순간 한꺼번에 : 뚜껑 폭발 · 섬광 · 비명 · 흔들림
local function erupt(model, own, kind)
	blowLid(model, SCARE.Hold + SCARE.Release + 1.2)
	local ghost = spawnPirate(model, own, kind)
	if own then
		sound("danger", kind == "rage" and 0.5 or 0.72, 0.34)
		sound("riser", 1.6, 0.12)
		blink(kind == "rage" and red or ((config.findSkin("Ghost", player:GetAttribute(SKIN_ATTR.Ghost)) or {}).aura or teal), 0.6)
		if not reduced then
			shakeUntil = os.clock() + 0.55
		end
	end
	return ghost
end

--------------------------------------------------
-- 해적 잡기 (입력 · 연출)
--------------------------------------------------
local catch = nil -- {opensAt, window, mine, sent, model}
local dangerPending = {}
local catchSeen = {}

--------------------------------------------------
-- 잡는 동안 의자에서 일어나지 않게 (Phase 10)
--
-- 스페이스 · 게임패드 A 는 원래 "점프 = 의자에서 일어나기"다. 잡기 안내가 "아무 키나"였으므로
-- 스페이스를 누른 사람은 의자에서 일어나 기권 처리됐다. 잡는 동안에는 이 두 키를 가로채서
-- 잡기 입력으로만 쓰고, 혹시 모를 점프 상태 전환도 잠시 막는다.
--------------------------------------------------
local SEAT_LOCK_ACTION = "CursedBarrel_CatchSeatLock"
local seatLocked = false
local seatLockUntil = 0
local lockedHumanoid = nil
local sendCatch -- 아래에서 정의한다

local function setSeatLock(on, untilClock)
	if on then
		seatLockUntil = math.max(seatLockUntil, untilClock or (os.clock() + 6))
	end
	if on == seatLocked then
		return
	end
	seatLocked = on
	if on then
		ContextActionService:BindActionAtPriority(SEAT_LOCK_ACTION, function(_, inputState)
			if inputState == Enum.UserInputState.Begin and sendCatch then
				sendCatch()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			lockedHumanoid = humanoid
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
	else
		ContextActionService:UnbindAction(SEAT_LOCK_ACTION)
		if lockedHumanoid and lockedHumanoid.Parent then
			lockedHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
		lockedHumanoid = nil
	end
end

local function endCatchUI()
	catch = nil
	catchGui.Visible = false
	catchButton.Active = false
	catchText.Text = ""
	catchHint.Text = ""
	setSeatLock(false)
end

local lastTapAt = 0
local eruptKind = setmetatable({}, { __mode = "k" }) -- [테이블] = 곧 튀어나올 해적의 종류
function sendCatch()
	if not catch or not catch.mine or catch.sent then
		return
	end
	-- 버튼 Activated 와 InputBegan 이 같은 탭으로 둘 다 들어옵니다. 한 번만 셉니다.
	if os.clock() - lastTapAt < 0.12 then
		return
	end
	lastTapAt = os.clock()
	-- 칼 자리를 고른 손가락이 한 번 더 눌린 것은 버립니다. (서버도 같은 시간만큼 버립니다)
	if os.clock() < (catch.armUntil or 0) then
		return
	end
	local now = workspace:GetServerTimeNow()
	catch.sent = true
	catchButton.Active = false
	catchInput:FireServer(catch.model, now)
	if now < catch.opensAt - (config.Catch.EarlyTolerance or 0) then
		-- ★ Phase 11 : 해적이 나오기 전에 눌렀다. 서버가 실패로 판정합니다.
		catchText.Text = "너무 빨랐다!"
		catchText.TextColor3 = red
		return
	end
	catchText.Text = "잡았다!"
	catchText.TextColor3 = teal
end

catchButton.Activated:Connect(sendCatch)
Input.InputBegan:Connect(function(input, processed)
	if not catch or not catch.mine then
		return
	end
	-- 채팅 입력 · 버튼 클릭(→ Activated) · 가로챈 스페이스(→ 위의 잠금 동작)는 여기서 세지 않는다.
	if processed or Input:GetFocusedTextBox() then
		return
	end
	-- 게임패드 스틱을 살짝 건드린 것은 누른 것으로 치지 않는다. ("너무 빨랐다" 오판 방지)
	local stick = input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2
	if input.UserInputType == Enum.UserInputType.Keyboard
		or input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or (input.UserInputType == Enum.UserInputType.Gamepad1 and not stick) then
		sendCatch()
	end
end)

catchPrompt.OnClientEvent:Connect(function(model, data)
	if typeof(model) ~= "Instance" or typeof(data) ~= "table" then
		return
	end
	dangerPending[model] = nil
	catchSeen[model] = os.clock()

	-- 서버 시계를 내 시계로 옮깁니다.
	local offset = os.clock() - workspace:GetServerTimeNow()
	local opensLocal = data.opensAt + offset
	local level = tonumber(data.level) or 1

	-- 클로즈업이 "들이닥치는" 순간과 창이 열리는 순간을 맞춥니다.
	if not reduced then
		shot = {
			model = model,
			startedAt = opensLocal - (SCARE.Lead + SCARE.Punch),
			total = SCARE.Lead + SCARE.Punch + SCARE.Hold + SCARE.Release,
		}
	end
	lastTable = model
	holdUntil = math.max(holdUntil, opensLocal + SCARE.Hold + SCARE.Release + 1.6)

	-- ★ Phase 11 : 나오기 전 — 통이 덜컹거리고, 가끔 가짜 손이 튀어나왔다 들어간다.
	--   가짜 손에 속아 누르면 "너무 빨랐다"로 탈락이다. 잡을수록(단계가 오를수록) 더 자주 속인다.
	local rattleFrom = os.clock() + 0.75
	rattle(model, rattleFrom, opensLocal)
	local lead = opensLocal - os.clock()
	if lead > 0.95 and math.random() < math.min(0.75, 0.3 + 0.12 * (level - 1)) then
		feint(model, os.clock() + math.max(0.8, lead - 0.35 - math.random() * 0.25))
	end

	task.delay(math.max(0, opensLocal - os.clock() - SCARE.Lead), function()
		sound("riser", 0.75, 0.18)
	end)
	eruptKind[model] = "real"
	task.delay(math.max(0, opensLocal - os.clock()), function()
		local kind = eruptKind[model] or "real"
		eruptKind[model] = nil
		erupt(model, true, kind)
	end)

	if not data.mine then
		task.delay(math.max(0, opensLocal - os.clock()), function()
			announce(("%s 님이 해적을 잡는 중!%s"):format(data.name or "", level > 1 and ("  (%d단계)"):format(level) or ""), gold, 1.2)
		end)
		return
	end

	catch = {
		model = model, mine = true, sent = false,
		opensAt = data.opensAt, window = data.window,
		opensLocal = opensLocal, index = data.index or 1,
		level = level, max = data.max,
		armUntil = os.clock() + (config.Catch.ArmDelay or 0.3),
	}
	catchGui.Visible = true
	catchButton.Active = true
	catchText.Text = ""
	catchHint.Text = ("해적이 튀어나온 뒤에 눌러라!  먼저 누르면 탈락   ·   %d단계 · 창 %.2f초%s")
		:format(level, data.window or 0, level > 1 and " (점점 빨라진다)" or "")
	-- 잡기 창이 닫히고 서버 판정이 올 때까지 의자를 붙잡아 둔다. 결과가 오면 풀린다.
	setSeatLock(true, opensLocal + (data.window or 0.6) + 4)
	-- 게임패드로 칼 자리 버튼이 선택돼 있으면 A 가 그 버튼으로 먹힌다. 잡기 입력이 되도록 선택을 푼다.
	if GuiService.SelectedObject then
		GuiService.SelectedObject = nil
	end
end)

catchResult.OnClientEvent:Connect(function(model, data)
	local own = tableOfCharacter() == model or active == model or lastTable == model
	if not own then
		return
	end
	local mine = data.userId == player.UserId
	if mine then
		endCatchUI()
	end

	if data.success then
		local grade_ = data.perfect and "완벽! 보너스 코인" or "아슬아슬!"
		-- 잡으면 통 안에 해적이 새로 숨고, 이 사람의 다음 해적은 더 빨라진다.
		local tail
		if (data.catchesLeft or 0) <= 0 then
			tail = "  다음 해적은 분노한 해적!"
		else
			tail = ("  다음 해적은 더 빠르다 (%d단계)"):format((data.level or 1) + 1)
		end
		announce(mine and ("잡았다!  " .. grade_ .. tail) or ((data.name or "") .. " 님이 해적을 잡았습니다!"), teal, 2)
		blink(teal, 0.35)
		sound("win", 1.4, 0.3)
		-- 해적이 통으로 끌려 들어갑니다.
		setGhostState(ghostLive, "caught")
	else
		local reason = data.reason
		local why = (reason == "late" and "놓쳤다…") or (reason == "early" and "해적이 나오기도 전에 눌렀다…")
			or (reason == "timeout" and "반응하지 못했다…")
			or (reason == "spent" and "분노한 해적은 잡을 수 없다…") or "놓쳤다…"
		announce(mine and (why .. "  탈락") or ((data.name or "") .. (reason == "early" and " · 너무 서둘렀다 · 탈락" or " · 탈락")), red, 1.8)
		blink(red, 0.4)
		sound("danger", 0.6, 0.3)
		-- 해적이 달려든다. (먼저 눌러서 아직 안 나왔다면, 나오자마자 달려든다)
		if eruptKind[model] then
			eruptKind[model] = "rage"
		else
			setGhostState(ghostLive, "lunge")
		end
		if not reduced then
			shakeUntil = os.clock() + 0.45
		end
	end
	ghostLive = nil
end)

--------------------------------------------------
-- 방해 아이템 연출 (Phase 8)
-- 버튼 흔들림 · 번호 뒤섞기는 칼 선택 패널이 담당합니다 (KnifeController).
-- 여기서는 화면 전체에 걸리는 것만 처리합니다.
--------------------------------------------------
sabotageCue.OnClientEvent:Connect(function(model, data)
	if typeof(data) ~= "table" then
		return
	end

	if data.id == "deny" or data.id == "done" then
		if data.message then
			announce(data.message, data.id == "done" and teal or red, 1.8)
		end
		return
	end
	if data.id == "list" then
		return -- 상점 UI 가 받습니다
	end

	if not data.mine then
		if data.toName and data.fromName then
			announce(("%s → %s 방해!"):format(data.fromName, data.toName), Color3.fromRGB(226, 150, 255), 1.4)
		end
		return
	end

	local from = data.fromName or "누군가"
	if data.id == "ink" then
		announce(from .. " 님이 먹물을 끼얹었다!", Color3.fromRGB(196, 150, 255), 1.6)
		showInk(data.duration or 6)
	elseif data.id == "hurry" then
		announce(from .. " 님의 저주 · 다음 턴이 짧아진다!", Color3.fromRGB(255, 160, 70), 1.8)
	elseif data.id == "roar" then
		announce(from .. " 님이 가짜 해적을 보냈다!", red, 1.4)
		local target = model or lastTable or tableOfCharacter()
		if target then
			spawnPirate(target, true, "fake")
			sound("danger", 0.8, 0.28)
			blink(red, 0.4)
			if not reduced then
				shakeUntil = os.clock() + 0.4
			end
		end
	elseif data.id == "shake" then
		announce(from .. " 님의 방해 · 손이 흔들린다!", Color3.fromRGB(120, 180, 226), 1.6)
	elseif data.id == "scramble" then
		announce(from .. " 님의 방해 · 번호가 뒤섞였다!", Color3.fromRGB(196, 130, 255), 1.8)
	end
end)

--------------------------------------------------
-- 서버 연출 신호
--------------------------------------------------
cues.OnClientEvent:Connect(function(kind, model, data)
	if typeof(model) ~= "Instance" or not model:IsDescendantOf(workspace) then
		return
	end
	local own = tableOfCharacter() == model or active == model or (lastTable == model and os.clock() < holdUntil)
	local pos = center(model)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	-- 다른 게임에 참가한 사람에게 옆 테이블의 효과를 전달하지 않습니다.
	if not own and (active or not root or not pos or (root.Position - pos).Magnitude > 35) then
		return
	end

	if kind == "Pick" then
		local tension = own and tensionOf(model) or 0
		local hitAt = stab(model, data.slot, own, tension, data.userId, data.stab)
		if data.danger and data.catchable == false then
			-- ★ Phase 11 : 잡을 만큼 다 잡은 사람이 또 해적을 만났다. 분노한 해적이라 잡기 창은 열리지 않는다.
			local popAt = os.clock() + hitAt + 0.1
			if own then
				lastTable = model
				holdUntil = math.max(holdUntil, popAt + SCARE.Hold + SCARE.Release + 1.6)
				if not reduced then
					shot = {
						model = model,
						startedAt = popAt - (SCARE.Lead + SCARE.Punch),
						total = SCARE.Lead + SCARE.Punch + SCARE.Hold + SCARE.Release,
					}
				end
			end
			if own then
				rattle(model, os.clock() + 0.75, popAt)
			end
			task.delay(math.max(0, popAt - os.clock()), function()
				erupt(model, own, "rage")
				if own then
					announce(data.userId == player.UserId and "분노한 해적! 이번엔 잡을 수 없다" or ((data.name or "") .. " · 분노한 해적!"), red, 1.4)
				end
			end)
		elseif data.danger then
			-- 잡기가 꺼져 있는 서버라면 CatchPrompt 가 오지 않습니다. 그때만 예전 연출로 대신합니다.
			dangerPending[model] = true
			task.delay(hitAt + 0.25, function()
				if not dangerPending[model] then
					return
				end
				if catchSeen[model] and os.clock() - catchSeen[model] < 3 then
					dangerPending[model] = nil
					return
				end
				dangerPending[model] = nil
				erupt(model, own, "rage")
				if own then
					announce(data.userId == player.UserId and "저주에 걸렸습니다!" or (data.name .. " · 탈락"), red)
				end
			end)
		elseif own then
			task.delay(hitAt, function()
				local mineNow = data.userId == player.UserId
				local canBrave = mineNow and model:GetAttribute(TABLE_ATTR.BraveOfferUserId) == player.UserId
				announce(canBrave and "안전!  「한 번 더」로 보너스를 노릴 수 있어요" or "안전!  다음 차례로", teal)
			end)
		end
	elseif kind == "Brave" then
		if own then
			local mineNow = data.userId == player.UserId
			announce(mineNow and ("배짱 %d단계!  한 번 더 찌르세요"):format(data.level or 1)
				or ("%s 님이 한 번 더 찌릅니다!  (배짱 %d단계)"):format(data.name or "", data.level or 1),
				Color3.fromRGB(255, 160, 70), 1.6)
			sound("riser", 1.2, 0.14)
		end
	elseif kind == "Card" then
		if own then
			local names = { skip = "한 번 넘기기", rotate = "통 회전", seal = "슬롯 봉인" }
			announce(("%s 님의 카드 · %s"):format(data.name or "", names[data.card] or tostring(data.card)), Color3.fromRGB(196, 150, 255), 1.6)
		end
	elseif kind == "Surge" then
		-- Phase 11 : 보물 폭발. 금화 비는 TreasureController 가 뿌린다.
		if own then
			local big = data.tier == "kraken"
			announce(("%s!  현상금 +%d  (총 %d)"):format(data.name or "보물", data.amount or 0, data.pot or 0),
				big and Color3.fromRGB(196, 130, 255) or gold, big and 2.6 or 1.8)
			for i, pitch in ipairs(big and { 1, 1.2, 1.45, 1.7 } or { 1.3, 1.6 }) do
				task.delay((i - 1) * 0.1, function()
					sound("win", pitch, 0.22)
				end)
			end
			blink(gold, big and 0.45 or 0.25)
		end
	elseif kind == "Win" then
		burst(pos + Vector3.new(0, 3, 0), gold, reduced and 10 or 28)
		if own then
			local streakText = (data.streak and data.streak >= 2) and ("  ·  %d연승!"):format(data.streak) or ""
			local potText = (data.pot and data.pot > 0) and ("  ·  현상금 %d 코인"):format(data.pot) or ""
			local carryText = (data.carry and data.carry > 0) and ("  ·  다음 판 이월 +%d"):format(data.carry) or ""
			local practiceText = data.practice and "  ·  AI 연습 판" or ""
			local text
			if data.userId == 0 then
				text = "이번 판은 승자 없음" .. carryText
			elseif data.bot then
				text = (data.name or "AI") .. " 승리…" .. carryText
			elseif data.forfeit then
				text = data.name .. " 생존!  상대가 모두 나가서 보상 절반" .. potText .. carryText
			else
				text = data.name .. " 승리!" .. streakText .. potText .. practiceText
			end
			announce(text, data.bot and red or gold, (data.forfeit or data.bot) and 2.4 or 1.8)
			blink(gold, 0.3)
			for i, pitch in ipairs({ 1, 1.25, 1.5 }) do
				task.delay((i - 1) * 0.15, function()
					sound("win", pitch)
				end)
			end
		end
	end
end)

--------------------------------------------------
-- 매 틱 갱신
--------------------------------------------------
local highlight = Instance.new("Highlight")
highlight.Name = "CurrentTurn"
highlight.FillTransparency = 0.88
highlight.OutlineColor = gold
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Parent = fx

local lastCountdown, lastTurn = nil, nil
local tickAt, heartAt, tension = 0, 0, 0

Run.Heartbeat:Connect(function()
	if os.clock() - tickAt < 0.1 then
		return
	end
	tickAt = os.clock()

	-- 서버 판정이 끝내 오지 않아도 의자 잠금이 남지 않게 한다.
	if seatLocked and os.clock() > seatLockUntil then
		endCatchUI()
	end

	local seated = tableOfCharacter()
	if seated and tutorial.Visible then
		tutorial.Visible = false
	end
	-- 앉아서 기다리는 동안 뚜껑의 제자리를 기억해 둔다. (덜컹거림 · 폭발 뒤에 돌려놓을 자리)
	if seated then
		local lid = lidOf(seated)
		if lid then
			restOf(seated, lid)
		end
	end
	local candidate = seated
 local watching=player:GetAttribute("SpectateTableId")
 if not candidate and watching then
  for _,t in ipairs(Tags:GetTagged(config.Tags.Table)) do if t:GetAttribute("TableId")==watching then candidate=t;break end end
 end
	if not candidate and lastTable and os.clock() < holdUntil and lastTable.Parent then
		candidate = lastTable
	end
	local state = candidate and candidate:GetAttribute(TABLE_ATTR.State)
	local inGame = candidate and (config.InGameStates[state] or (candidate == lastTable and os.clock() < holdUntil))
	local desired = inGame and candidate or nil
	if desired ~= active then
		active = desired
		lastTurn = nil
		shot = nil
		if active then
			enterStage(active)
		else
			leaveStage()
		end
	end

	local model = active or seated
	local wanted = (active and active:GetAttribute(TABLE_ATTR.State) == "Playing") and tensionOf(active) or 0
	tension += (wanted - tension) * 0.12
	if grade then
		grade.Saturation = -0.4 * tension
		grade.Contrast = 0.14 * tension
	end

	if model then
		local current = model:GetAttribute(TABLE_ATTR.State)
		title.Text = "저주받은 통  /  " .. (model:GetAttribute("DisplayName") or model.Name)
		if current == "Countdown" then
			local remaining = math.max(0, math.ceil((model:GetAttribute(TABLE_ATTR.CountdownEndsAt) or 0) - workspace:GetServerTimeNow()))
			status.Text = ("%d초 후 시작 · 자리를 떠나면 참가가 취소됩니다"):format(remaining)
			if lastCountdown ~= remaining then
				sound("tick", remaining <= 2 and 1.4 or 1)
				lastCountdown = remaining
			end
		elseif current == "Playing" then
			local id = model:GetAttribute(TABLE_ATTR.CurrentTurnUserId)
			highlight.Adornee = characterOfUser(model, id)
			local mine = id == player.UserId
			local duel = (model:GetAttribute(TABLE_ATTR.TurnCount) or 0) == 2
			local left = model:GetAttribute(TABLE_ATTR.SlotsRemaining) or 0
			local caught = model:GetAttribute(TABLE_ATTR.CatchCount) or 0
			local pirates = model:GetAttribute(TABLE_ATTR.PirateCount) or 0
			local edge = (left > 0 and left <= 3) and ("남은 자리 " .. left .. "칸  ·  ") or ""
			local caughtText = (caught > 0) and ("잡기 " .. caught .. "회  ·  ") or ""
			-- 몇 마리가 숨어 있는지만 보여 줍니다. 어느 자리인지는 서버만 압니다.
			local pirateText = (pirates > 1) and ("해적 " .. pirates .. "마리  ·  ") or ""
			status.Text = edge .. pirateText .. caughtText .. (duel and "최후의 2인  ·  " or "")
				.. (mine and "내 차례! 아래에서 칼 자리를 선택하세요" or ((model:GetAttribute(TABLE_ATTR.CurrentTurnName) or "") .. " 님의 선택을 지켜보세요"))
			-- 현상금 · 내 잡기 기회 · 배짱 단계
			local parts = {}
			local pot = model:GetAttribute(TABLE_ATTR.Pot) or 0
			if pot > 0 then
				table.insert(parts, ("현상금 %d 코인"):format(pot))
			end
			local mySeat = seatOf(model)
			if mySeat and (mySeat:GetAttribute(config.SeatAttributes.TurnOrder) or 0) > 0 then
				local left = mySeat:GetAttribute(config.SeatAttributes.CatchesLeft) or 0
				local level = mySeat:GetAttribute(config.SeatAttributes.CatchLevel) or 0
				if left <= 0 then
					table.insert(parts, "다음 해적은 분노한 해적 · 만나면 탈락")
				elseif level > 0 then
					table.insert(parts, ("잡기 %d회 · 다음 해적 %d단계"):format(level, level + 1))
				end
			end
			local brave = model:GetAttribute(TABLE_ATTR.BraveLevel) or 0
			if brave > 0 then
				table.insert(parts, ("배짱 %d단계"):format(brave))
			end
			detail.Text = table.concat(parts, "   ·   ")
			if id ~= lastTurn then
				lastTurn = id
				if mine then
					sound("tick", 1.3)
				end
			end
			-- 위험할수록 빨라지고 커지는 심장 소리
			if tension > 0.2 and os.clock() > heartAt then
				heartAt = os.clock() + (1.25 - 0.75 * tension)
				sound("heart", 0.38 + 0.1 * tension, 0.05 + 0.22 * tension)
			end
		elseif current == "Starting" then
			status.Text = "저주가 깨어납니다…"
		elseif current == "RoundEnding" then
			status.Text = "5초 뒤 새로운 게임이 시작됩니다"
		else
			status.Text = "다른 참가자를 기다리는 중"
		end
		if current ~= "Playing" then
			detail.Text = ""
		end
		if current ~= "Playing" then
			highlight.Adornee = nil
		end
	else
		title.Text = "THE CURSED HARBOR"
		status.Text = "가까운 의자에서 E · 모바일은 앉기 버튼  |  전시장에서 스킨을 바꿀 수 있어요"
		detail.Text = ""
		highlight.Adornee = nil
		lastCountdown = nil
	end

	if active then
		for _, board in ipairs(player.PlayerGui:GetChildren()) do
			if board:IsA("BillboardGui") and board.Adornee and not board.Adornee:IsDescendantOf(active) then
				if hiddenBoards[board] == nil then
					hiddenBoards[board] = board.Enabled
				end
				board.Enabled = false
			end
		end
	end
end)

--------------------------------------------------
-- 카메라 그리기
--------------------------------------------------
Run:BindToRenderStep("CursedBarrel_TableCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera
	local pos = center(active)
	if not pos or not cameraOn or not camera then
		restoreCamera()
		return
	end
	if cameraOwned ~= camera then
		restoreCamera()
		cameraOwned = camera
		originalFOV = camera.FieldOfView
		originalType = camera.CameraType
		originalSubject = camera.CameraSubject
	end
	camera.CameraType = Enum.CameraType.Scriptable

	local target, fov = standardShot(camera, pos, tension)
	if shot then
		if shot.model ~= active or not shot.model.Parent then
			shot = nil
		else
			local elapsed = os.clock() - shot.startedAt
			if elapsed >= shot.total then
				shot = nil
			elseif elapsed >= 0 then
				local closeCF, closeFOV = closeShot(shot.model, pos, elapsed)
				local tail = shot.total - SCARE.Release
				if elapsed > tail then
					local a = math.clamp((elapsed - tail) / SCARE.Release, 0, 1)
					a = a * a * (3 - 2 * a)
					closeCF = closeCF:Lerp(target, a)
					closeFOV = closeFOV + (fov - closeFOV) * a
				end
				target, fov = closeCF, closeFOV
			end
		end
	end

	local rayParams=RaycastParams.new()
 rayParams.FilterType=Enum.RaycastFilterType.Exclude
 local exclude={active,fx};if player.Character then table.insert(exclude,player.Character) end
 rayParams.FilterDescendantsInstances=exclude
 local focus=pos+Vector3.new(0,2,0)
 local hit=workspace:Raycast(focus,target.Position-focus,rayParams)
 if hit and (hit.Position-focus).Magnitude>4 then target=CFrame.lookAt(hit.Position+hit.Normal*0.5,focus) end
 local alpha = 1 - math.exp(-dt * (shot and 22 or FRAME.Follow))
	camera.CFrame = camera.CFrame:Lerp(target, alpha)
	camera.FieldOfView += (fov - camera.FieldOfView) * alpha
	if not reduced and player:GetAttribute("Setting_shake")~=false and os.clock() < shakeUntil then
		local amp = (shakeUntil - os.clock()) * 0.4
		camera.CFrame *= CFrame.new(math.sin(os.clock() * 70) * amp, math.cos(os.clock() * 53) * amp, 0)
	end
end)

-- 잡기 고리는 매 프레임 줄어듭니다.
Run:BindToRenderStep("CursedBarrel_CatchRing", Enum.RenderPriority.Last.Value, function()
	if not catch or not catch.mine then
		return
	end
	local now = workspace:GetServerTimeNow()
	local window = catch.window or 0.6
	if now < catch.opensAt then
		local wait = math.clamp((catch.opensAt - now) / 0.9, 0, 1)
		catchRing.Size = UDim2.fromOffset(320 + wait * 420, 320 + wait * 420)
		ringStroke.Color = gold
		ringStroke.Transparency = 0.15 + wait * 0.5
		if catchText.Text == "" or catchText.Text == "…" then
			catchText.Text = "기다려…"
		end
		catchText.TextColor3 = cream
	elseif not catch.sent then
		local left = math.clamp(1 - (now - catch.opensAt) / window, 0, 1)
		catchRing.Size = UDim2.fromOffset(150 + left * 330, 150 + left * 330)
		ringStroke.Color = left > 0.35 and teal or red
		ringStroke.Transparency = 0
		catchText.Text = "지금!"
		catchText.TextColor3 = cream
		if left <= 0 then
			catchText.Text = "놓쳤다…"
			catchText.TextColor3 = red
		end
	end
end)

--------------------------------------------------
-- 전시장 (미리보기 회전 · 장착 표시)
--
-- Phase 6 : "장착 중" 표시가 너무 커서 로비 어디서나 크게 보였습니다.
--   글자 크기를 고정하고, 표시 거리를 두고, 가까이 갔을 때만 만듭니다.
--------------------------------------------------
local EQUIP_TAG_RANGE = 24
local equippedTags = {}
local spinAt = 0

Run.Heartbeat:Connect(function(dt)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	for _, model in ipairs(Tags:GetTagged(config.Tags.SkinPreview)) do
		if model:IsA("Model") and model.Parent then
			local pivot = model:GetPivot()
			if (pivot.Position - root.Position).Magnitude < 140 then
				model:PivotTo(pivot * CFrame.Angles(0, math.rad((model:GetAttribute("SpinSpeed") or 24)) * dt, 0))
			end
		end
	end

	if os.clock() - spinAt < 0.4 then
		return
	end
	spinAt = os.clock()
    for pedestal,tag in pairs(equippedTags) do if not pedestal:IsDescendantOf(workspace) then tag:Destroy();equippedTags[pedestal]=nil end end

	for _, pedestal in ipairs(Tags:GetTagged(config.Tags.SkinPedestal)) do
		local kind = pedestal:GetAttribute("SkinKind")
		local attribute = kind and SKIN_ATTR[kind]
		local near = (pedestal.Position - root.Position).Magnitude <= EQUIP_TAG_RANGE
		local mineNow = near and attribute and player:GetAttribute(attribute) == pedestal:GetAttribute("SkinId")
		local tag = equippedTags[pedestal]

		if mineNow and not tag then
			tag = Instance.new("BillboardGui")
			tag.Name = "Equipped"
			tag.Adornee = pedestal
			tag.AlwaysOnTop = true
			tag.Size = UDim2.fromOffset(84, 20) -- 작게. 예전에는 150x34 에 TextScaled 였습니다.
			tag.StudsOffset = Vector3.new(0, 1.2, 0)
			tag.MaxDistance = EQUIP_TAG_RANGE
			tag.Parent = player.PlayerGui

			local plate = Instance.new("Frame")
			plate.Size = UDim2.fromScale(1, 1)
			plate.BackgroundColor3 = Color3.fromRGB(16, 26, 24)
			plate.BackgroundTransparency = 0.25
			plate.BorderSizePixel = 0
			plate.Parent = tag
			Instance.new("UICorner", plate).CornerRadius = UDim.new(0, 6)

			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextSize = 13 -- 고정 크기. TextScaled 를 쓰면 멀리서도 화면을 덮습니다.
			label.TextColor3 = teal
			label.Text = "장착 중"
			label.Parent = plate

			equippedTags[pedestal] = tag
		elseif not mineNow and tag then
			tag:Destroy()
			equippedTags[pedestal] = nil
		end
	end
end)

--------------------------------------------------
-- 스킨 변경 반영
--------------------------------------------------
player:GetAttributeChangedSignal(SKIN_ATTR.Ghost):Connect(function()
	local skin = config.findSkin("Ghost", player:GetAttribute(SKIN_ATTR.Ghost))
	if skin then
		announce(skin.name .. " 장착", gold, 1.2)
	end
end)
player:GetAttributeChangedSignal(SKIN_ATTR.Knife):Connect(function()
	local skin = config.findSkin("Knife", player:GetAttribute(SKIN_ATTR.Knife))
	if skin then
		announce(skin.name .. " 장착", gold, 1.2)
	end
end)
player:GetAttributeChangedSignal(SKIN_ATTR.Stab):Connect(function()
	local skin = config.findSkin("Stab", player:GetAttribute(SKIN_ATTR.Stab))
	if skin then
		announce(skin.name .. " 모션 장착  ·  칼을 꽂을 때 모두가 봅니다", gold, 1.6)
	end
end)
player:GetAttributeChangedSignal(SKIN_ATTR.Barrel):Connect(function()
	local skin = config.findSkin("Barrel", player:GetAttribute(SKIN_ATTR.Barrel))
	if skin then
		-- 통은 테이블마다 한 명의 것만 적용됩니다. 그 사실을 같이 알려 줍니다.
		announce(skin.name .. " 장착  ·  테이블에서는 등급이 높은 통이 보입니다", gold, 2)
	end
end)

player.CharacterRemoving:Connect(function()
	active = nil
	lastTable = nil
	holdUntil = 0
	shot = nil
	endCatchUI()
	leaveStage()
end)

script.Destroying:Connect(function()
	Run:UnbindFromRenderStep("CursedBarrel_TableCamera")
	Run:UnbindFromRenderStep("CursedBarrel_CatchRing")
	leaveStage()
	fx:Destroy()
	gui:Destroy()
end)
