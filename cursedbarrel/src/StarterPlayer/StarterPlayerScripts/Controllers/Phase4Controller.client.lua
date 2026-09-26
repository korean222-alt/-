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
--     해적은 PirateModel 이 매번 새로 만듭니다. (Phase 17 : Blender 해적 모델이 있으면 그것)
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
local EliminationFX = require(package.Shared:WaitForChild("EliminationFX"))
local UIKit = require(package.Shared:WaitForChild("UIKit"))
local Utility = require(package.Shared:WaitForChild("Utility"))
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

local function textLabel(name, size, position, fontSize, parent)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = cream
	label.FontFace = UIKit.font(true)
	label.TextSize = fontSize
	label.TextWrapped = true
	label.Text = ""
	label.Parent = parent or gui
	UIKit.textStroke(label, UIKit.strokeFor(fontSize))
	return label
end

--[[
	Phase 15 : 게임 중 위쪽 가운데 알림판 하나 (예전에는 테이블 이름 · 상태 · 경고가 따로 떠서
	테이블 위 3D 현황판과 겹쳐 "뭐라는지 안 보였다")
	  윗줄   : 테이블 이름 ................ 라운드 2/3 (마지막은 "결승")
	  가운데 : 시작 3 · 내 차례! · ○○ 차례
	  아랫줄 : 👥 남은 사람    💰 현상금 (최후의 1인 테이블은 👑)
]]
local hud = Instance.new("Frame")
hud.Name = "Match"
hud.AnchorPoint = Vector2.new(0.5, 0)
hud.Position = UDim2.new(0.5, 0, 0, 50)
hud.Size = UDim2.fromOffset(430, 100)
hud.BackgroundColor3 = Color3.new(1, 1, 1)
hud.BackgroundTransparency = 0.05
hud.Visible = false
hud.ZIndex = 10
hud.Parent = gui
UIKit.gradient(hud, UIKit.Colors.Body, UIKit.Colors.BodyDark, 90)
UIKit.corner(hud, 16)
UIKit.outline(hud, 3.5)
local hudScale = Instance.new("UIScale")
hudScale.Parent = hud

local title = textLabel("Chapter", UDim2.new(1, -190, 0, 28), UDim2.fromOffset(16, 6), 20, hud)
title.TextColor3 = gold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 11
local roundChip = Instance.new("Frame")
roundChip.Name = "Round"
roundChip.AnchorPoint = Vector2.new(1, 0)
roundChip.Position = UDim2.new(1, -10, 0, 7)
roundChip.Size = UDim2.fromOffset(162, 28)
roundChip.BackgroundColor3 = Color3.new(1, 1, 1)
roundChip.ZIndex = 11
roundChip.Visible = false
roundChip.Parent = hud
UIKit.paint(roundChip, "purple")
UIKit.corner(roundChip, 14)
UIKit.outline(roundChip, 2.5)
local roundLabel = textLabel("RoundText", UDim2.fromScale(1, 1), UDim2.new(), 17, roundChip)
roundLabel.ZIndex = 12
local status = textLabel("Status", UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 32), 30, hud)
status.ZIndex = 11
local aliveLabel = textLabel("Alive", UDim2.new(0.5, -16, 0, 24), UDim2.fromOffset(16, 70), 19, hud)
aliveLabel.TextXAlignment = Enum.TextXAlignment.Left
aliveLabel.ZIndex = 11
local potLabel = textLabel("Pot", UDim2.new(0.5, -16, 0, 24), UDim2.new(0.5, 0, 0, 70), 19, hud)
potLabel.TextXAlignment = Enum.TextXAlignment.Right
potLabel.TextColor3 = gold
potLabel.ZIndex = 11
-- 꼭 알아야 하는 경고 한 줄 (분노한 해적) : 알림판 바로 아래
local detail = textLabel("Detail", UDim2.fromOffset(430, 28), UDim2.new(0.5, -215, 0, 154), 22)
detail.TextColor3 = red
local banner = textLabel("Result", UDim2.new(0.84, 0, 0, 90), UDim2.new(0.08, 0, 0.3, 40), 48)
banner.TextTransparency = 1

-- 작은 화면에서는 알림판을 줄인다
-- Phase 21 : 가로로 눕힌 휴대폰은 폭은 넉넉하지만 높이가 360~430 이라 알림판이 화면 위를 너무 가렸다 → 높이도 본다.
--   가운데 큰 글자(승리 · 안전! …)도 휴대폰에서는 작게, 알림판 바로 아래에 띄운다.
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
local function fitHud()
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local scale = math.clamp(math.min((view.X - 20) / 450, view.Y / 560), 0.6, 1)
	hudScale.Scale = scale
	local phone = math.min(view.X, view.Y) < 540
	bannerScale.Scale = phone and 0.72 or 1
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = phone and UDim2.new(0.5, 0, 0, 50 + math.floor(100 * scale) + 8) or UDim2.new(0.5, 0, 0.3, 40)
	detail.Position = UDim2.new(0.5, -215 * scale, 0, 50 + math.floor(104 * scale))
	detail.Size = UDim2.fromOffset(430 * scale, 28)
end
fitHud()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitHud)
end

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

-- Phase 15 : 판이 끝났을 때 알림판 가운데에 남기는 한 마디 (승리 / 패배 / ○○ 승리)
local resultText, resultColor = nil, nil
-- Phase 21 : 이 판에서 내가 탈락해 "패배 · N위" 를 이미 보여 준 테이블
local placeShown = setmetatable({}, { __mode = "k" })
local potPop = -10 -- Phase 21 : 마지막으로 잭팟이 터진 때 (현상금 숫자 튀기기)

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

-- Phase 24 : 고리 · 과녁 · 글자를 한 무대(catchStage)에 모아 화면 크기에 맞춰 통째로 줄인다.
--   예전에는 고리가 최대 740px · 안내가 520px 로 고정이라 휴대폰 세로 화면에서 잘리거나 다른 UI 를 덮었다.
--   (누르는 버튼 catchButton 은 무대 밖에 두어 여전히 화면 어디를 눌러도 잡힌다)
local catchStage = Instance.new("Frame")
catchStage.Name = "Stage"
catchStage.AnchorPoint = Vector2.new(0.5, 0.5)
catchStage.Position = UDim2.fromScale(0.5, 0.5)
catchStage.Size = UDim2.fromScale(1, 1)
catchStage.BackgroundTransparency = 1
catchStage.ZIndex = 17
catchStage.Parent = catchGui
local catchScale = Instance.new("UIScale")
catchScale.Parent = catchStage
local catchRingMax = 740 -- 무대 배율을 넣기 전 크기 기준. 화면의 짧은 쪽을 넘지 않게 fitCatch 가 줄인다
local function fitCatch()
	local area = gui.AbsoluteSize
	if area.X <= 0 or area.Y <= 0 then
		local camera = workspace.CurrentCamera
		area = camera and camera.ViewportSize or Vector2.new(1280, 720)
	end
	-- 안전 영역(노치 · 홈 막대)을 조금 비워 둔다
	local inset = GuiService:GetGuiInset()
	local short = math.max(200, math.min(area.X, area.Y - inset.Y) - 24)
	local s = math.clamp(short / 560, 0.45, 1)
	catchScale.Scale = s
	catchRingMax = math.min(740, short / s)
end

local catchRing = Instance.new("Frame")
catchRing.Name = "Ring"
catchRing.AnchorPoint = Vector2.new(0.5, 0.5)
catchRing.Position = UDim2.fromScale(0.5, 0.44)
catchRing.Size = UDim2.fromOffset(320, 320)
catchRing.BackgroundTransparency = 1
catchRing.ZIndex = 17
catchRing.Parent = catchStage
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
catchTarget.Parent = catchStage
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
catchText.FontFace = UIKit.font(true)
catchText.TextSize = 64
catchText.TextColor3 = cream
catchText.Text = ""
catchText.ZIndex = 18
catchText.Parent = catchStage
UIKit.textStroke(catchText, UIKit.strokeFor(64, 3))

local catchHint = Instance.new("TextLabel")
catchHint.Name = "Hint"
catchHint.AnchorPoint = Vector2.new(0.5, 0)
catchHint.Position = UDim2.fromScale(0.5, 0.62)
catchHint.Size = UDim2.new(0.96, 0, 0, 30)
catchHint.AutomaticSize = Enum.AutomaticSize.Y
catchHint.TextWrapped = true
local hintLimit = Instance.new("UISizeConstraint")
hintLimit.MaxSize = Vector2.new(520, math.huge)
hintLimit.Parent = catchHint
catchHint.BackgroundTransparency = 1
catchHint.Font = Enum.Font.GothamBold
catchHint.TextSize = 18
catchHint.TextColor3 = cream
catchHint.TextTransparency = 0.25
catchHint.Text = ""
catchHint.ZIndex = 18
catchHint.Parent = catchStage
fitCatch()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCatch)

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

-- Phase 24 : 먹물을 연달아 맞으면 앞 먹물의 "걷히는 예약"이 새 먹물까지 지웠다.
--   먹물마다 번호(inkToken)를 붙이고, 가장 최근 먹물의 예약만 화면을 걷는다.
local inkToken = 0
local function showInk(duration)
	inkToken += 1
	local token = inkToken
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
		if token ~= inkToken then
			return
		end
		for _, blot in ipairs(inkBlots) do
			Tween:Create(blot, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		end
		task.delay(0.55, function()
			if token == inkToken then
				inkLayer.Visible = false
			end
		end)
	end)
end

--------------------------------------------------
-- 설정은 항해 수첩(🧭) > 설정 한 곳에만 있다. (예전의 작은 설정 창은 걷어냈다)
--------------------------------------------------
local function button(parent, caption, position, size, callback)
	local b = UIKit.button(parent, { text = caption, position = position, size = size, theme = "green", textSize = 18, zIndex = 15 })
	b.Activated:Connect(function()
		callback(b)
	end)
	return b
end

--------------------------------------------------
-- 첫 판 안내
--------------------------------------------------
local tutorial = Instance.new("Frame")
tutorial.Name = "Tutorial"
tutorial.AnchorPoint = Vector2.new(0, 0.5)
tutorial.Position = UDim2.new(0, 22, 0.5, 0)
tutorial.Size = UDim2.fromOffset(340, 236)
tutorial.BackgroundColor3 = Color3.new(1, 1, 1)
tutorial.BorderSizePixel = 0
tutorial.ZIndex = 14
tutorial.Parent = gui
UIKit.gradient(tutorial, UIKit.Colors.Body, UIKit.Colors.BodyDark, 90)
UIKit.corner(tutorial, 16)
UIKit.outline(tutorial, 4)

local function tutorialLine(text, y, color, size)
	return UIKit.label(tutorial, {
		text = text, position = UDim2.fromOffset(18, y), size = UDim2.new(1, -36, 0, (size or 14) + 10),
		textSize = size or 14, color = color or cream, alignX = Enum.TextXAlignment.Left, zIndex = 15,
	})
end
tutorialLine("게임 방법", 12, gold, 26)
tutorialLine("① 의자에 앉기", 52, cream, 20)
tutorialLine("② 내 차례에 칼 꽂을 자리 고르기", 84, cream, 20)
tutorialLine("③ 해적이 나오면 눌러서 잡기!", 116, teal, 20)
-- Phase 12 : AI 선원 둘과 연습 한 판 (처음 해적은 잡기 쉽다)
-- Phase 24 : 서버가 "앉혔다"고 답한 뒤에 안내를 닫는다. 실패하면 이유를 적고 버튼이 "다시 시도"로 바뀐다.
local practiceStatus = tutorialLine("", 148, Color3.fromRGB(255, 150, 130), 14)
practiceStatus.TextWrapped = true
local practiceBusy = false
local practiceSerial = 0
button(tutorial, "연습 한 판", UDim2.new(1, -250, 1, -54), UDim2.fromOffset(118, 42), function(b)
	if practiceBusy then
		return
	end
	local r = remotes:FindFirstChild("VoyageRequest")
	local reply = remotes:WaitForChild("PracticeResult", 5)
	if not r or not reply then
		practiceStatus.Text = "서버 준비 중이에요. 잠시 후 다시 눌러 주세요"
		b.Text = "다시 시도"
		return
	end
	practiceBusy = true
	practiceSerial += 1
	local serial = practiceSerial
	b.Text = "입장 중…"
	practiceStatus.TextColor3 = cream
	practiceStatus.Text = "빈 테이블을 찾는 중…"
	local answered = false
	local connection
	connection = reply.OnClientEvent:Connect(function(ok, why)
		if serial ~= practiceSerial or answered then
			return
		end
		answered = true
		connection:Disconnect()
		practiceBusy = false
		if ok then
			practiceStatus.Text = ""
			b.Text = "연습 한 판"
			tutorial.Visible = false
		else
			practiceStatus.TextColor3 = Color3.fromRGB(255, 150, 130)
			practiceStatus.Text = typeof(why) == "string" and why or "지금은 연습 판을 열 수 없어요"
			b.Text = "다시 시도"
		end
	end)
	r:FireServer("practice")
	task.delay(8, function()
		if answered or serial ~= practiceSerial then
			return
		end
		answered = true
		connection:Disconnect()
		practiceBusy = false
		practiceStatus.TextColor3 = Color3.fromRGB(255, 150, 130)
		practiceStatus.Text = "응답이 없어요. 다시 눌러 주세요"
		b.Text = "다시 시도"
	end)
end)
button(tutorial, "알겠어요", UDim2.new(1, -124, 1, -54), UDim2.fromOffset(110, 42), function()
	tutorial.Visible = false
    local r=remotes:FindFirstChild("VoyageRequest");if r then r:FireServer("tutorial") end
end)

--------------------------------------------------
-- 소리
--------------------------------------------------
-- Phase 15 : 다른 창(상점 · 출석 …)이 열리면 이 안내도 닫힌다 (창은 한 번에 하나)
UIKit.register(tutorial)
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
		heartbeat = "action_jump_land.mp3", jackpot = "volume_slider.ogg",
	}
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/" .. (paths[kind] or paths.tick)
	s.Volume = (volume or (kind == "danger" and 0.22 or 0.25))*(player:GetAttribute("Setting_sfx") or 0.65)
    -- Phase 24 : 재생할 수 없는 음원(권한 · 심사)이면 기본 소리를 그대로 쓴다 (예전에는 소리가 아예 안 났다)
    local Release=require(package.Shared:WaitForChild("ReleaseConfig"))
    local key=({danger="Dragon",pick="Impact",win="Win",heartbeat="Heartbeat",jackpot="Jackpot"})[kind]
    local id=key and Release.audioId(key) or 0
    if id>0 then s.SoundId="rbxassetid://"..id end
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
local stageTweens = {} -- Phase 22 : 무대가 서서히 어두워지는 트윈 (나가면 멈춘다)
local atmoSaved = {} -- [Atmosphere] = 원래 { Density, Haze, Glare }
local function stageTween(target, info, goal)
	local t = Tween:Create(target, info, goal)
	table.insert(stageTweens, t)
	t:Play()
	return t
end
local function leaveStage()
	for _, t in ipairs(stageTweens) do
		t:Cancel()
	end
	table.clear(stageTweens)
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
		local saved = atmoSaved[a]
		if saved then
			a.Density, a.Haze, a.Glare = saved[1], saved[2], saved[3]
		end
		a.Parent = Lighting
	end
	table.clear(atmospheres)
	table.clear(atmoSaved)
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
	-- Phase 22 : 한 번에 "팍" 어두워지지 않고 1초 동안 서서히 (벽 · 천장이 짙어지고 빛 · 하늘이 함께 가라앉는다)
	local FADE = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local myStage = stage
	local black = Color3.fromRGB(2, 4, 7)
	local walls = {}
	for _, v in ipairs({ Vector3.new(0, 0, -29), Vector3.new(0, 0, 29) }) do
		table.insert(walls, makePart(stage, "Backdrop", Vector3.new(60, 90, 1), CFrame.new(pos + v), black))
	end
	for _, v in ipairs({ Vector3.new(-29, 0, 0), Vector3.new(29, 0, 0) }) do
		table.insert(walls, makePart(stage, "Backdrop", Vector3.new(1, 90, 60), CFrame.new(pos + v), black))
	end
	table.insert(walls, makePart(stage, "Ceiling", Vector3.new(60, 1, 60), CFrame.new(pos + Vector3.new(0, 38, 0)), black))
	for _, wall in ipairs(walls) do
		wall.Transparency = 1
		stageTween(wall, FADE, { Transparency = 0 })
	end

	-- 하늘 안개(Atmosphere)는 옅어진 뒤에 치운다 (leaveStage 가 되돌린다)
	for _, a in ipairs(Lighting:GetChildren()) do
		if a:IsA("Atmosphere") then
			table.insert(atmospheres, a)
			atmoSaved[a] = { a.Density, a.Haze, a.Glare }
			stageTween(a, FADE, { Density = 0, Haze = 0, Glare = 0 })
		end
	end
	task.delay(1, function()
		if stage == myStage then
			for _, a in ipairs(atmospheres) do
				a.Parent = nil
			end
		end
	end)
	stageTween(Lighting, FADE, {
		Ambient = Color3.fromRGB(66, 72, 82),
		OutdoorAmbient = Color3.fromRGB(8, 12, 18),
		Brightness = 0.35,
		ExposureCompensation = 0.25,
		FogColor = black,
		FogStart = 26,
		FogEnd = 46,
	})
	-- ClockTime 은 돌리면 해가 하늘을 가로지르므로 벽이 다 짙어진 뒤에 바꾼다
	task.delay(1, function()
		if stage == myStage then
			Lighting.ClockTime = 0
		end
	end)

	keyLight = makePart(stage, "SoftKey", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(0, 6, 0)), cream)
	keyLight.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 216, 159)
	light.Brightness = 0
	light.Range = 34
	light.Shadows = false
	light.Parent = keyLight
	stageTween(light, FADE, { Brightness = 3.2 })

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

-- Phase 15 : 시점을 좌우로 돌린 만큼 (라디안). 카메라 · 해적 · 가짜 손이 모두 이 방향을 따른다.
local yaw = 0
local YAW_SPEED = math.rad(110)
local dragInput, dragLast, padTurn = nil, nil, 0
local yawHintShown = false
-- Phase 21 : 0.6 → 0.42 (칼 고르는 창 위를 덮던 자리에서 통 위쪽으로)
local yawHint = textLabel("YawHint", UDim2.fromOffset(440, 28), UDim2.new(0.5, -220, 0.42, 0), 19)
yawHint.TextTransparency = 1
local function facing(pos)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local delta = root and Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z) or Vector3.new(0, 0, 1)
	if delta.Magnitude < 0.1 then
		delta = Vector3.new(0, 0, 1)
	end
	local direction = delta.Unit
	if yaw ~= 0 then
		direction = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(direction)
	end
	return direction
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
			if seat:IsA("Seat") and seat:GetAttribute(config.SeatAttributes.OccupantUserId) == userId then
				local link = seat:FindFirstChild("BotCharacter")
				if link and link.Value then
					return link.Value
				elseif seat.Occupant then
					return seat.Occupant.Parent
				end
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
			-- Phase 17 : Blender 칼(SkinMesh)이 있으면 그것만 날아가고 네모 칼은 숨긴다
			local meshCopy = copy:FindFirstChild("SkinMesh")
			if meshCopy and #meshCopy:GetChildren() > 0 then
				for _, p in ipairs(copy:GetChildren()) do
					if p:IsA("BasePart") then
						p.Transparency = 1
					end
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
						sound("pick", final and 1.55 or 2.1, final and 0.6 or 0.42) -- Phase 24 : 칼 꽂는 소리가 작았다 (0.3 · 0.14 → 0.6 · 0.42)
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
		sound("pick", 0.55, 0.4)
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
			if item.part.Name == "Eye" or item.part.Name == "Claw" or item.part.Name == "Socket" or item.part.Name == "HandR" then
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
			announce(("%s 잡는 중!"):format(data.name or ""), gold, 1.2)
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
	catchHint.Text = ""
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
		announce(mine and (data.perfect and "완벽!" or "잡았다!") or ((data.name or "") .. " 잡았다!"), teal, 1.6)
		blink(teal, 0.35)
		sound("win", 1.4, 0.3)
		-- 해적이 통으로 끌려 들어갑니다.
		setGhostState(ghostLive, "caught")
	else
		local reason = data.reason
		local why = (reason == "early" and "너무 빨랐다!") or (reason == "spent" and "분노한 해적!") or "놓쳤다…"
		announce(mine and why or ((data.name or "") .. " 탈락"), red, 1.6)
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

	if data.id == "deny" or data.id == "done" or data.id == "refund" then
		if data.message then
			announce(data.message, data.id == "deny" and red or teal, 1.8)
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
				announce("안전!", teal, 1.2)
			end)
		end
	elseif kind == "Brave" then
		if own then
			local mineNow = data.userId == player.UserId
			announce(mineNow and ("배짱 %d단계!"):format(data.level or 1)
				or ("%s 배짱 %d단계!"):format(data.name or "", data.level or 1),
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
			announce(("💰 +%d"):format(data.amount or 0),
				big and Color3.fromRGB(196, 130, 255) or gold, big and 2.6 or 1.8)
			for i, pitch in ipairs(big and { 1, 1.2, 1.45, 1.7 } or { 1.3, 1.6 }) do
				task.delay((i - 1) * 0.1, function()
					sound("win", pitch, 0.22)
				end)
			end
			blink(gold, big and 0.45 or 0.25)
		end
	elseif kind == "Jackpot" then
		-- Phase 21 : 잭팟! 화면 가운데에 크게 · 빛살 · 별 · 팡파르. 알림판의 현상금 숫자도 통통 튄다
		if own then
			local big = data.tier == "big"
			local who = data.userId == player.UserId and "" or ((data.who or "") .. " · ")
			UIKit.rewardPopup({
				title = big and "💰 대박 잭팟! 💰" or "💰 잭팟! 💰",
				text = who .. "현상금 +" .. Utility.comma(data.amount or 0),
				money = big and "vault" or "chest",
				big = true,
				color = big and Color3.fromRGB(255, 120, 190) or gold,
				sound = "Jackpot",
				hold = big and 3.4 or 2.8,
			})
			blink(gold, big and 0.55 or 0.4)
			burst(pos + Vector3.new(0, 4, 0), gold, reduced and 12 or (big and 60 or 40))
			potPop = os.clock()
		end
	elseif kind == "Win" then
		burst(pos + Vector3.new(0, 3, 0), gold, reduced and 10 or 28)
		if own then
			-- Phase 15 : 이기면 "승리", 진 사람(이번 판 참가자)은 누가 이겼든 "패배". 구경한 사람만 "○○ 승리".
			local wasIn = false
			for _, id in ipairs(typeof(data.roster) == "table" and data.roster or {}) do
				if id == player.UserId then
					wasIn = true
				end
			end
			local won = data.userId ~= 0 and data.userId == player.UserId
			local text, color
			if won and data.noContest then
				-- Phase 24 : 아무도 제대로 꽂기 전에 상대가 전부 나간 판. 보상 없이 끝난다
				text, color = "무효 판 · 보상 없음", cream
			elseif won then
				local potText = (data.pot and data.pot > 0) and ("  +%s"):format(Utility.comma(data.pot)) or ""
				local streakText = (data.streak and data.streak >= 2) and ("  🔥%d"):format(data.streak) or ""
				text, color = "승리!" .. potText .. streakText, gold
			elseif wasIn and placeShown[model] then
				-- Phase 21 : 탈락할 때 이미 "패배 · 3위" 를 보여 줬다. 또 "패배" 를 띄우지 않는다
				text, color = nil, red
			elseif wasIn then
				text, color = "패배", red
			elseif data.userId == 0 then
				text, color = "승자 없음", cream
			else
				text, color = ("%s 승리"):format(data.name or ""), gold
			end
			resultText, resultColor = (won and not data.noContest) and "승리!" or (wasIn and not won and "패배" or text), color
			local alreadyOut = placeShown[model] == true
			placeShown[model] = nil
			if text then
				announce(text, color, won and 2.6 or 2)
			end
			if not alreadyOut then
				blink(won and gold or (wasIn and red or gold), won and 0.35 or 0.2)
			end
			if alreadyOut then
				-- 소리도 한 번만
			elseif won or not wasIn then
				for i, pitch in ipairs({ 1, 1.25, 1.5 }) do
					task.delay((i - 1) * 0.15, function()
						sound("win", pitch)
					end)
				end
			else
				sound("danger", 0.55, 0.25)
			end
		end
	elseif kind == "Eliminate" then
		if data.position then
			EliminationFX.play(data.position, config.findSkin("Ghost", player:GetAttribute(SKIN_ATTR.Ghost)), reduced)
		end
		-- Phase 15 : 탈락한 사람 화면에는 "패배 · 4위". 이유(놓쳤다 · 너무 빨랐다)를 먼저 보여 주고 이어서 뜬다.
		if data.userId == player.UserId then
			placeShown[model] = true
			local place = tonumber(data.place)
			task.delay(1.1, function()
				announce(place and ("패배 · %d위"):format(place) or "패배", red, 2.4)
			end)
			resultText, resultColor = "패배", red
		end
	elseif kind == "Stage" then
		-- Phase 15 : 한 명이 떨어지고 다음 라운드가 시작된다
		if own and model:GetAttribute(TABLE_ATTR.Stage) then
			local stage, total = tonumber(data.stage) or 1, tonumber(data.total) or 1
			announce(stage >= total and "결승!" or ("%d 라운드!"):format(stage), stage >= total and gold or teal, 1.6)
			sound("riser", 1.1, 0.12)
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
local potBase = potLabel.TextSize

--------------------------------------------------
-- Phase 21 : 심장 소리
--   게임 내내 뛴다. 라운드가 올라갈수록 빨라지고(분당 64 → 라운드마다 +14, 결승은 +10 더),
--   남은 자리가 적을수록(위험할수록) 더 빠르고 크게 뛴다. heartbeat.ogg(ReleaseConfig.Audio.Heartbeat)가 있으면 그 소리.
--------------------------------------------------
local AUDIO = require(package.Shared:WaitForChild("ReleaseConfig")).Audio
local function heartRate(stage, stages, danger)
	local round = math.max(1, tonumber(stage) or 1)
	local bpm = 64 + 14 * (round - 1)
	if (tonumber(stages) or 0) >= 2 and round >= stages then
		bpm += 10
	end
	return math.min(156, bpm + 28 * danger)
end
local function heartbeatSound(danger, mine)
	local volume = 0.16 + 0.24 * danger + (mine and 0.06 or 0) -- Phase 24 : 조금 크게
	local Release = require(package.Shared:WaitForChild("ReleaseConfig"))
	if Release.audioId("Heartbeat") > 0 then
		sound("heartbeat", 1 + 0.06 * danger, volume * 1.6)
	else
		-- 기본 소리로 "쿵-쿵" 두 번
		sound("heart", 0.4, volume)
		task.delay(0.19, function()
			sound("heart", 0.48, volume * 0.7)
		end)
	end
end

--------------------------------------------------
-- Phase 21 : 해적에 집중
--   해적이 튀어나오는 동안(클로즈업 · 잡기 창)은 위 알림판 · 경고 · 날씨 · 예측 · 관전 버튼 · 버튼 줄을 숨긴다.
--   (휴대폰에서 화면이 다 가려져 해적이 안 보였다) player 의 PirateFocus Attribute 를 다른 화면들도 본다.
--------------------------------------------------
local FOCUS_HIDE = { "CursedBarrel_World", "CursedBarrel_Predict", "CursedBarrel_Streak", "CursedBarrel_Cannon", "CursedBarrel_Voyage" } -- 연습 안내("해적이 나오면 누르세요!")는 남긴다
local focusSaved = {}
local function setFocusHidden(on)
	for _, name in ipairs(FOCUS_HIDE) do
		local g = player.PlayerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") then
			if on then
				if focusSaved[g] == nil then
					focusSaved[g] = g.Enabled
				end
				g.Enabled = false
			elseif focusSaved[g] ~= nil then
				g.Enabled = focusSaved[g]
				focusSaved[g] = nil
			end
		end
	end
end

Run.Heartbeat:Connect(function()
	if os.clock() - tickAt < 0.1 then
		return
	end
	tickAt = os.clock()

	local focusNow = shot ~= nil or catch ~= nil
	if focusNow ~= (player:GetAttribute("PirateFocus") == true) then
		player:SetAttribute("PirateFocus", focusNow or nil)
		setFocusHidden(focusNow)
	end

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
		yaw = 0 -- 새 판은 정면에서 시작한다
		dragInput, dragLast = nil, nil
		if active then
			enterStage(active)
			if not yawHintShown and cameraOn then
				yawHintShown = true
				yawHint.Text = Input.TouchEnabled and "↔ 화면을 끌어서 시점 돌리기" or "↔ 드래그 · ← → 로 시점 돌리기"
				yawHint.TextTransparency = 0
				task.delay(4, function()
					Tween:Create(yawHint, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
				end)
			end
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
		hud.Visible = not focusNow
		detail.Visible = not focusNow
		title.Text = model:GetAttribute("DisplayName") or model.Name
		-- 라운드 : 한 명이 떨어질 때마다 올라간다. 마지막 둘이 겨루면 "결승"
		local stage = model:GetAttribute(TABLE_ATTR.Stage) or 0
		local stages = model:GetAttribute(TABLE_ATTR.StageCount) or 0
		local inRound = current == "Playing" or current == "Starting"
		roundChip.Visible = (inRound or current == "RoundEnding") and stages >= 1 and stage >= 1
		if roundChip.Visible then
			roundLabel.Text = ("라운드 %d/%d%s"):format(stage, stages, stages > 1 and stage >= stages and " · 결승" or "")
		end
		-- 남은 사람 · 현상금
		local alive = model:GetAttribute(TABLE_ATTR.TurnCount) or 0
		local started = model:GetAttribute(TABLE_ATTR.ParticipantCount) or 0
		if inRound and started > 0 then
			aliveLabel.Text = ("👥 %d/%d"):format(alive, started)
		else
			aliveLabel.Text = ("👥 %d/%d"):format(model:GetAttribute(TABLE_ATTR.SeatedCount) or 0, model:GetAttribute(TABLE_ATTR.SeatCount) or 0)
		end
		local pot = model:GetAttribute(TABLE_ATTR.Pot) or 0
		local takesAll = model:GetAttribute(TABLE_ATTR.WinnerTakesAll) == true
		potLabel.Text = (pot > 0 or takesAll) and ((takesAll and "👑 " or "💰 ") .. Utility.comma(pot)) or ""
		-- 잭팟이 터지면 현상금 숫자가 2초 동안 크게 통통 튄다
		local sincePop = os.clock() - potPop
		potLabel.TextSize = sincePop < 2 and math.floor(potBase * (1.25 + 0.2 * math.abs(math.sin(sincePop * 9)))) or potBase
		if current == "Countdown" then
			local remaining = math.max(0, math.ceil((model:GetAttribute(TABLE_ATTR.CountdownEndsAt) or 0) - workspace:GetServerTimeNow()))
			status.Text = ("시작 %d"):format(remaining)
			status.TextColor3 = cream
			if lastCountdown ~= remaining then
				sound("tick", remaining <= 2 and 1.4 or 1)
				lastCountdown = remaining
			end
		elseif current == "Playing" then
			local id = model:GetAttribute(TABLE_ATTR.CurrentTurnUserId)
			highlight.Adornee = characterOfUser(model, id)
			local mine = id == player.UserId
			status.Text = mine and "내 차례!" or ((model:GetAttribute(TABLE_ATTR.CurrentTurnName) or "") .. " 차례")
			status.TextColor3 = mine and gold or cream
			-- 부제목은 두지 않는다. 꼭 알아야 하는 경고(분노한 해적)만 한 줄.
			local warning = ""
			local mySeat = seatOf(model)
			if mySeat and (mySeat:GetAttribute(config.SeatAttributes.TurnOrder) or 0) > 0
				and (mySeat:GetAttribute(config.SeatAttributes.CatchesLeft) or 0) <= 0 then
				warning = "⚠ 분노한 해적"
			end
			detail.Text = warning
			if id ~= lastTurn then
				lastTurn = id
				if mine then
					sound("tick", 1.3)
				end
			end
			-- 심장 소리 (Phase 21 : 라운드마다 빨라진다)
			if os.clock() > heartAt then
				heartAt = os.clock() + 60 / heartRate(stage, stages, tension)
				heartbeatSound(tension, mine)
			end
		elseif current == "Starting" then
			status.Text = "시작!"
			status.TextColor3 = gold
			resultText, resultColor = nil, nil
		elseif current == "RoundEnding" then
			status.Text = resultText or ""
			status.TextColor3 = resultColor or gold
		else
			status.Text = "대기 중"
			status.TextColor3 = cream
		end
		if current ~= "Playing" then
			detail.Text = ""
		end
		if current ~= "Playing" then
			highlight.Adornee = nil
		end
	else
		hud.Visible = false
		title.Text = ""
		status.Text = ""
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
-- Phase 15 : 시점 좌우로 돌리기 ("시점 고정 말고 좌우로 움직일 수 있게")
--   · PC : 마우스 드래그(왼쪽 · 오른쪽 버튼), ← → 또는 A D
--   · 휴대폰 : 화면을 손가락으로 끌기
--   · 게임패드 : 오른쪽 스틱
--   해적이 튀어나오는 클로즈업과 잡기 중에는 돌지 않는다. 새 판이 시작되면 정면으로 돌아온다.
--------------------------------------------------
local function canTurn()
	return active ~= nil and cameraOn and not catch and not shot
end
Input.InputBegan:Connect(function(input, processed)
	if processed or not canTurn() then
		return
	end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2 or kind == Enum.UserInputType.Touch then
		dragInput, dragLast = input, input.Position
	end
end)
Input.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		padTurn = math.abs(input.Position.X) > 0.2 and -input.Position.X or 0
		return
	end
	if not dragInput or not canTurn() then
		return
	end
	local follows = input == dragInput
		or (input.UserInputType == Enum.UserInputType.MouseMovement and dragInput.UserInputType ~= Enum.UserInputType.Touch)
	if follows and dragLast then
		local delta = input.Position - dragLast
		dragLast = input.Position
		yaw -= delta.X * 0.008
	end
end)
Input.InputEnded:Connect(function(input)
	if dragInput and (input == dragInput or input.UserInputType == dragInput.UserInputType) then
		dragInput, dragLast = nil, nil
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

	if canTurn() then
		local turn = padTurn
		if not Input:GetFocusedTextBox() then
			if Input:IsKeyDown(Enum.KeyCode.Left) or Input:IsKeyDown(Enum.KeyCode.A) then
				turn += 1
			end
			if Input:IsKeyDown(Enum.KeyCode.Right) or Input:IsKeyDown(Enum.KeyCode.D) then
				turn -= 1
			end
		end
		if turn ~= 0 then
			yaw += turn * YAW_SPEED * dt
		end
	end
	if yaw > math.pi then
		yaw -= math.pi * 2
	elseif yaw < -math.pi then
		yaw += math.pi * 2
	end

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
		local ringSize = math.min(catchRingMax, 320 + wait * 420)
		catchRing.Size = UDim2.fromOffset(ringSize, ringSize)
		ringStroke.Color = gold
		ringStroke.Transparency = 0.15 + wait * 0.5
		if catchText.Text == "" or catchText.Text == "…" then
			catchText.Text = "기다려…"
		end
		catchText.TextColor3 = cream
	elseif not catch.sent then
		local left = math.clamp(1 - (now - catch.opensAt) / window, 0, 1)
		local ringSize = math.min(catchRingMax, 150 + left * 330)
		catchRing.Size = UDim2.fromOffset(ringSize, ringSize)
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
		announce(skin.name .. " 장착", gold, 1.2)
	end
end)
player:GetAttributeChangedSignal(SKIN_ATTR.Barrel):Connect(function()
	local skin = config.findSkin("Barrel", player:GetAttribute(SKIN_ATTR.Barrel))
	if skin then
		-- 통은 테이블마다 한 명의 것만 적용됩니다. 그 사실을 같이 알려 줍니다.
		announce(skin.name .. " 장착", gold, 1.2)
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
