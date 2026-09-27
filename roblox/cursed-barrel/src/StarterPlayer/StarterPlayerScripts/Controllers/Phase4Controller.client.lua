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
local ArtAtlas = require(package.Shared:WaitForChild("ArtAtlas")) -- Phase 32.1 : 타로 카드 · 해적 종류 아이콘 그림
local hands = require(package.Shared:WaitForChild("FirstPersonHands")).new(player) -- Phase 37 : 1인칭 전용 손
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
local firstPerson = false -- Phase 32 : 게임 중 1인칭 (설정 firstPerson)
local function applySettings()
 muted=(player:GetAttribute("Setting_sfx") or 0.65)<=0
 reduced=player:GetAttribute("Setting_reducedFX")==true
 cameraOn=player:GetAttribute("Setting_camera")~=false
 firstPerson=player:GetAttribute("Setting_firstPerson")==true
 FRAME.FOV=player:GetAttribute("Setting_wide")==false and 58 or 68
end
for _,key in ipairs({"sfx","reducedFX","camera","wide","firstPerson"}) do player:GetAttributeChangedSignal("Setting_"..key):Connect(applySettings) end
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
local showInk
do
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
	function showInk(duration)
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
local tutorial
do
	tutorial = Instance.new("Frame")
	tutorial.Name = "Tutorial"
	-- Phase 32.1 : 들어오면 먼저 뜨는 환영 창 (가운데). 「튜토리얼 시작」을 누르거나 WelcomeWait 초가 지나면 시작한다.
	--   예전에는 들어오자마자 2.5초 만에 튜토리얼 테이블에 앉혀서 무엇을 하는지 모른 채 판이 흘러갔다.
	tutorial.AnchorPoint = Vector2.new(0.5, 0.5)
	tutorial.Position = UDim2.fromScale(0.5, 0.5)
	tutorial.Size = UDim2.fromOffset(400, 262)
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
	UIKit.autoScale(tutorial, UIKit.phoneFactor)
	tutorialLine("어서 와요, 선원!", 12, gold, 26)
	tutorialLine("1. 차례가 오면 칼 꽂을 자리를 골라요", 52, cream, 19)
	tutorialLine("2. 해적이 튀어나오면 바로 눌러서 잡아요", 82, cream, 19)
	tutorialLine("3. 해적마다 잡는 법이 달라요. 튜토리얼에서 하나씩!", 112, teal, 19)
	-- Phase 12 : AI 선원 둘과 연습 한 판 (처음 해적은 잡기 쉽다)
	-- Phase 24 : 서버가 "앉혔다"고 답한 뒤에 안내를 닫는다. 실패하면 이유를 적고 버튼이 "다시 시도"로 바뀐다.
	local practiceStatus = tutorialLine("", 150, Color3.fromRGB(255, 150, 130), 16)
	practiceStatus.TextWrapped = true
	local practiceBusy = false
	local practiceSerial = 0
	button(tutorial, "튜토리얼 시작", UDim2.new(0.5, -90, 1, -58), UDim2.fromOffset(180, 46), function(b)
		if practiceBusy then
			return
		end
		local r = remotes:FindFirstChild("VoyageRequest")
		if r and player:GetAttribute("TutorialDone") ~= true then
			r:FireServer("tutorialGo") -- Phase 32.1 : 환영 창 대기를 끝낸다 (못 앉히면 서버가 곧 다시 찾는다)
		end
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
				b.Text = "튜토리얼 시작"
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
	local skipButton = button(tutorial, "알겠어요", UDim2.new(1, -112, 0, 12), UDim2.fromOffset(98, 36), function()
		tutorial.Visible = false
	    local r=remotes:FindFirstChild("VoyageRequest");if r then r:FireServer("tutorial") end
	end)
	-- Phase 32 : 튜토리얼은 필수다. 건너뛰기("알겠어요")는 연습 테이블을 못 찾아 필수가 풀린 사람에게만 보인다.
	--   서버(OnboardingService)가 곧 연습 테이블에 앉혀 준다. "연습 한 판"은 바로 앉는 버튼으로 남긴다.
	local function drawMandatory()
		local mandatory = config.Tutorial and config.Tutorial.Mandatory and player:GetAttribute("TutorialFree") ~= true
		skipButton.Visible = not mandatory
		if mandatory and player:GetAttribute("TutorialDone") ~= true and not practiceBusy then
			practiceStatus.TextColor3 = gold
			practiceStatus.Text = "놓쳐도 괜찮아요. 천천히 배워요"
		end
	end
	-- Phase 32.1 : 환영 창 대기 시간 (서버 OnboardingService 와 같은 WelcomeWait)
	task.spawn(function()
		local waitFor = tonumber(config.Tutorial and config.Tutorial.WelcomeWait) or 30
		local startedAt = nil
		while gui.Parent and player:GetAttribute("TutorialDone") ~= true do
			if player:GetAttribute("TutorialWelcome") == true then
				startedAt = startedAt or os.clock()
				if tutorial.Visible and not practiceBusy then
					local left = math.max(0, math.ceil(waitFor - (os.clock() - startedAt)))
					practiceStatus.TextColor3 = cream
					practiceStatus.Text = ("놓쳐도 괜찮아요 · %d초 뒤 자동으로 시작해요"):format(left)
				end
			elseif startedAt then
				drawMandatory()
				startedAt = nil
			end
			task.wait(0.25)
		end
	end)
	player:GetAttributeChangedSignal("TutorialFree"):Connect(drawMandatory)
	player:GetAttributeChangedSignal("TutorialActive"):Connect(drawMandatory)
	drawMandatory()

	--------------------------------------------------
	-- 소리
	--------------------------------------------------
	-- Phase 15 : 다른 창(상점 · 출석 …)이 열리면 이 안내도 닫힌다 (창은 한 번에 하나)
	UIKit.register(tutorial)
	player:GetAttributeChangedSignal("TutorialDone"):Connect(function() if player:GetAttribute("TutorialDone") then tutorial.Visible=false end end)
	if player:GetAttribute("TutorialDone") then tutorial.Visible=false end
end

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
    -- Phase 24.10 : 미리 불러오기는 통과했는데 실제로는 재생이 안 되는 음원이 있다 (심장 소리가 안 나던 원인).
    --   3초 안에 불러와지지 않으면 재생할 수 없는 음원으로 적고, 다음부터는 기본 소리로 대신한다.
    if id>0 and not Release.AudioFailed[key] then
     task.delay(3,function()
      if s.Parent and not s.IsLoaded and not Release.AudioFailed[key] then
       Release.AudioFailed[key]=true
       warn("[CursedBarrel] 재생되지 않는 음원이라 기본 소리로 바꿉니다: "..key.." "..id)
      end
     end)
    end
	Debris:AddItem(s, 6)
	return s
end

--------------------------------------------------
-- Phase 32 : 운명 카드 (라운드마다 한 장)
--   가운데에서 뒷면 → 뒤집혀 앞면(그림 · 이름 · 규칙) → 잠시 뒤 사라지고, 규칙은 알림판 아래 한 줄로 남는다.
--   누를 것이 없다 (아래 칼 고르는 창 · 잡기 입력을 가리지 않는다).
--   Phase 32.1 : Blender 로 렌더한 타로 카드 그림 (ArtAtlas). 그림을 올리기 전에는 같은 모양을 UI 로 그린다.
--   그 테이블에 앉은 사람 · 관전하는 사람 모두에게 같은 카드가 보인다.
--------------------------------------------------
local showFateCard
do
	local tarot = ArtAtlas.tarot(gui, { name = "FateCard", position = UDim2.fromScale(0.5, 0.45), zIndex = 40 })
	local fateCard = tarot.holder
	fateCard.Visible = false
	local fateScale = Instance.new("UIScale")
	fateScale.Parent = fateCard
	-- 위 : "N 라운드 · 운명 카드" · 아래 : 규칙 (카드 밖에 두어 뒤집을 때 함께 접히지 않는다)
	local fateTop = textLabel("Top", UDim2.new(1.4, 0, 0, 34), UDim2.new(-0.2, 0, 0, -42), 26, fateCard)
	fateTop.ZIndex = 49
	fateTop.TextColor3 = gold
	local fateRule = Instance.new("TextLabel")
	fateRule.Name = "Rule"
	fateRule.AnchorPoint = Vector2.new(0.5, 0)
	fateRule.Position = UDim2.new(0.5, 0, 1, 10)
	fateRule.Size = UDim2.fromOffset(330, 0)
	fateRule.AutomaticSize = Enum.AutomaticSize.Y
	fateRule.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
	fateRule.BackgroundTransparency = 0.08
	fateRule.FontFace = UIKit.font(true)
	fateRule.TextSize = 21
	fateRule.TextWrapped = true
	fateRule.TextColor3 = cream
	fateRule.ZIndex = 49
	fateRule.Parent = fateCard
	UIKit.corner(fateRule, 12)
	UIKit.textStroke(fateRule, 2)
	local ruleStroke = Instance.new("UIStroke")
	ruleStroke.Color = Color3.fromRGB(226, 178, 88)
	ruleStroke.Thickness = 2
	ruleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ruleStroke.Parent = fateRule
	local rulePad = Instance.new("UIPadding")
	rulePad.PaddingTop = UDim.new(0, 8)
	rulePad.PaddingBottom = UDim.new(0, 8)
	rulePad.PaddingLeft = UDim.new(0, 12)
	rulePad.PaddingRight = UDim.new(0, 12)
	rulePad.Parent = fateRule
	local fateToken = 0
	local function fitFate()
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		-- 카드(408) + 위 글자(42) + 아래 규칙(~70)
		return math.clamp(math.min((view.X - 24) / 340, (view.Y - 110) / 540), 0.42, 1)
	end
	local function fold(token, alpha, time, style)
		local value = Instance.new("NumberValue")
		value.Value = alpha == 0 and 1 or 0
		value.Changed:Connect(function(v)
			if token == fateToken then
				tarot.setWidth(v)
			end
		end)
		local tween = Tween:Create(value, TweenInfo.new(time, style, alpha == 0 and Enum.EasingDirection.In or Enum.EasingDirection.Out), { Value = alpha })
		tween:Play()
		tween.Completed:Connect(function()
			value:Destroy()
		end)
		return tween
	end
	function showFateCard(card, stage)
		fateToken += 1
		local token = fateToken
		local base = fitFate()
		fateTop.Text = ("%d 라운드 · 운명 카드"):format(stage or 1)
		fateRule.Text = ""
		fateRule.Visible = false
		tarot.paint(card, false)
		tarot.setWidth(1)
		fateCard.Visible = true
		fateCard.Rotation = -8
		fateScale.Scale = base * 0.3
		Tween:Create(fateScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
		Tween:Create(fateCard, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		sound("riser", 1.25, 0.16)
		-- 뒤집기 : 폭을 0 으로 접었다가 앞면으로 편다
		task.delay(0.75, function()
			if token ~= fateToken then
				return
			end
			fold(token, 0, 0.16, Enum.EasingStyle.Quad).Completed:Wait()
			if token ~= fateToken then
				return
			end
			tarot.paint(card, true)
			fold(token, 1, 0.24, Enum.EasingStyle.Back)
			fateRule.Text = card.text or ""
			fateRule.Visible = fateRule.Text ~= ""
			sound("win", 1.5, 0.25)
			blink(card.color or gold, 0.25)
		end)
		task.delay(3.05, function()
			if token ~= fateToken then
				return
			end
			Tween:Create(fateScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
			task.delay(0.32, function()
				if token == fateToken then
					fateCard.Visible = false
				end
			end)
		end)
	end
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
--------------------------------------------------
-- Phase 32 : "어둠이 몰려온다"
--   예전(Phase 22)에는 1초 동안 트윈 여러 개를 따로 돌리다가, 1초가 되는 순간에
--     · 하늘 안개(Atmosphere)를 치우고 (그러자 꺼져 있던 Fog 가 한꺼번에 켜졌다)
--     · 시간(ClockTime)을 자정으로 바꿨다 (해 · 하늘 · 그림자가 한 프레임에 바뀌었다)
--   게다가 검은 벽이 반투명을 거쳐 짙어지면서 앞뒤가 뒤섞여 깜빡였고, 날씨 색보정은 시작하자마자 꺼졌다.
--   → "스르륵"이 아니라 "뚝뚝 끊겨" 보였다.
--   이제는 값 하나(진행도)로 매 프레임 모든 것을 함께 움직인다.
--     1) 화면 가장자리에서 어둠이 스멀스멀 번져 들어오고, 먼 곳부터 안개(Atmosphere)가 까맣게 짙어지며 빛이 가라앉는다.
--     2) 화면이 완전히 까매진 아주 짧은 순간에 벽 · 안개 · 시간을 한꺼번에 바꾼다 (보이지 않으니 끊김도 없다).
--     3) 통 위 등불이 가물거리며 켜지고, 어둠은 화면 가장자리의 은은한 그늘로 물러난다.
--   무대를 떠날 때는 까만 화면에서 원래 빛이 천천히 돌아온다.
--------------------------------------------------
local leaveStage, makePart, enterStage
do
	local darkGui = Instance.new("ScreenGui")
	darkGui.Name = "CursedBarrel_Darkness"
	darkGui.ResetOnSpawn = false
	darkGui.IgnoreGuiInset = true
	-- Phase 33.1 : 휴대폰 노치 · 둥근 모서리 쪽(안전 영역 밖)까지 덮는다 (예전에는 화면 양옆에 어둠이 잘린 띠가 남았다)
	darkGui.ScreenInsets = Enum.ScreenInsets.None
	darkGui.DisplayOrder = 1 -- 알림판 · 칼 고르는 창 · 잡기 화면보다 아래 (3D 화면만 덮는다)
	darkGui.Parent = player:WaitForChild("PlayerGui")
	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(2, 3, 6)
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Active = false
	veil.ZIndex = 2
	veil.Parent = darkGui
	-- 가장자리 그늘 넷 (위 · 아래 · 왼쪽 · 오른쪽). 바깥이 까맣고 안쪽으로 갈수록 투명하다.
	local edges = {}
	for _, spec in ipairs({
		{ name = "Top", anchor = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), rot = 90, vertical = true },
		{ name = "Bottom", anchor = Vector2.new(0, 1), pos = UDim2.fromScale(0, 1), rot = -90, vertical = true },
		{ name = "Left", anchor = Vector2.new(0, 0), pos = UDim2.fromScale(0, 0), rot = 0, vertical = false },
		{ name = "Right", anchor = Vector2.new(1, 0), pos = UDim2.fromScale(1, 0), rot = 180, vertical = false },
	}) do
		local frame = Instance.new("Frame")
		frame.Name = spec.name
		frame.AnchorPoint = spec.anchor
		frame.Position = spec.pos
		frame.Size = UDim2.fromScale(spec.vertical and 1 or 0, spec.vertical and 0 or 1)
		frame.BackgroundColor3 = Color3.fromRGB(2, 3, 6)
		frame.BorderSizePixel = 0
		frame.Active = false
		frame.ZIndex = 1
		frame.Parent = darkGui
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec.rot
		gradient.Parent = frame
		table.insert(edges, { frame = frame, gradient = gradient, vertical = spec.vertical, phase = #edges * 1.7 })
	end
	-- extent : 화면의 몇 분의 몇까지 그늘이 들어오는가 · alpha : 그늘의 짙기 (0 ~ 1) · t : 일렁임 시각
	local function drawEdges(extent, alpha, t)
		for _, edge in ipairs(edges) do
			local wobble = reduced and 0 or math.sin(t * 2.3 + edge.phase) * 0.025 + math.sin(t * 5.1 + edge.phase * 2) * 0.012
			local e = math.clamp(extent + wobble * math.min(1, extent * 4), 0, 1)
			edge.frame.Size = edge.vertical and UDim2.fromScale(1, e) or UDim2.fromScale(e, 1)
			local a = math.clamp(alpha, 0, 1)
			edge.gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1 - a),
				NumberSequenceKeypoint.new(0.55, 1 - a * 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			edge.frame.Visible = e > 0.001 and a > 0.001
		end
	end
	drawEdges(0, 0, 0)

	local darkConn = nil -- 지금 돌고 있는 어둠 연출
	local veilToken = 0
	local function stopDarkness()
		if darkConn then
			darkConn:Disconnect()
			darkConn = nil
		end
	end

	function leaveStage(fade)
		stopDarkness()
		-- Phase 31 : 무대를 떠나면 보상 창을 다시 눌러서 닫을 수 있게 한다
		UIKit.passivePopups = false
		for _, t in ipairs(stageTweens) do
			t:Cancel()
		end
		table.clear(stageTweens)
		local hadStage = stage ~= nil
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
				a.Density, a.Haze, a.Glare, a.Color, a.Decay = saved[1], saved[2], saved[3], saved[4], saved[5]
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
		-- Phase 32 : 까만 화면에서 원래 빛이 천천히 돌아온다 (카메라가 캐릭터로 돌아가는 순간도 가려진다)
		veilToken += 1
		local token = veilToken
		if fade and hadStage and not reduced then
			veil.BackgroundTransparency = 0
			local fadeOut = Tween:Create(veil, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
			fadeOut:Play()
			local startedAt = os.clock()
			local conn
			conn = Run.RenderStepped:Connect(function()
				local a = math.clamp((os.clock() - startedAt) / 0.9, 0, 1)
				if token ~= veilToken or a >= 1 then
					conn:Disconnect()
					if token == veilToken then
						drawEdges(0, 0, 0)
					end
					return
				end
				drawEdges(0.22 * (1 - a), 0.8 * (1 - a), os.clock())
			end)
		else
			veil.BackgroundTransparency = 1
			drawEdges(0, 0, 0)
		end
	end

	function makePart(parent, name, size, cf, color)
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

	local STAGE_LIGHT = {
		Ambient = Color3.fromRGB(66, 72, 82),
		OutdoorAmbient = Color3.fromRGB(8, 12, 18),
		Brightness = 0.35,
		ExposureCompensation = 0.25,
	}
	local DARK = {
		creep = 1.25, -- 어둠이 번져 들어오는 시간
		hold = 0.08, -- 완전히 까만 순간 (여기서 벽 · 안개 · 시간을 바꾼다)
		reveal = 0.85, -- 등불이 켜지고 어둠이 가장자리로 물러나는 시간
		rest = 0.2, -- 게임 내내 남는 가장자리 그늘의 폭 (화면 비율)
	}

	function enterStage(model)
		leaveStage(false)
		local pos = center(model)
		if not pos then
			return
		end
		stage = Instance.new("Folder")
		stage.Name = "PrivateTableStage"
		stage.Parent = fx
		-- Phase 31 : 게임 중에는 퀘스트 · 보상 창이 터치를 가로채지 않는다 (해적 잡기 · 칼 꽂기가 한 번에 눌리게)
		UIKit.passivePopups = true
		-- 같은 테이블 참가자의 각 기기에만 존재하는 검은 무대. 서버 맵은 변경하지 않습니다.
		local myStage = stage
		local black = Color3.fromRGB(2, 4, 7)
		-- ★ 벽은 처음부터 불투명하지만 보이지 않는다(LocalTransparencyModifier 1). 화면이 까만 순간에 한꺼번에 세운다.
		--   (반투명 벽은 앞뒤 그리기 순서가 뒤섞여 깜빡였다)
		local walls = {}
		for _, v in ipairs({ Vector3.new(0, 0, -29), Vector3.new(0, 0, 29) }) do
			table.insert(walls, makePart(stage, "Backdrop", Vector3.new(60, 90, 1), CFrame.new(pos + v), black))
		end
		for _, v in ipairs({ Vector3.new(-29, 0, 0), Vector3.new(29, 0, 0) }) do
			table.insert(walls, makePart(stage, "Backdrop", Vector3.new(1, 90, 60), CFrame.new(pos + v), black))
		end
		table.insert(walls, makePart(stage, "Ceiling", Vector3.new(60, 1, 60), CFrame.new(pos + Vector3.new(0, 38, 0)), black))
		for _, wall in ipairs(walls) do
			wall.LocalTransparencyModifier = 1
		end

		keyLight = makePart(stage, "SoftKey", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(0, 6, 0)), cream)
		keyLight.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 216, 159)
		light.Brightness = 0
		light.Range = 34
		light.Shadows = false
		light.Parent = keyLight

		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "CursedBarrel_Tension"
		grade.Saturation = 0
		grade.Contrast = 0
		grade.Brightness = 0
		grade.Parent = Lighting

		-- 시작 값 (지금 하늘) → 무대 값
		local from = {}
		for key in pairs(STAGE_LIGHT) do
			from[key] = Lighting[key]
		end
		for _, a in ipairs(Lighting:GetChildren()) do
			if a:IsA("Atmosphere") then
				table.insert(atmospheres, a)
				atmoSaved[a] = { a.Density, a.Haze, a.Glare, a.Color, a.Decay }
			end
		end

		local function lerpLighting(e)
			for key, goal in pairs(STAGE_LIGHT) do
				local start = from[key]
				if typeof(goal) == "Color3" then
					Lighting[key] = start:Lerp(goal, e)
				else
					Lighting[key] = start + (goal - start) * e
				end
			end
			-- 먼 곳부터 어둠에 잠긴다 : 하늘 안개가 까맣게 짙어진다 (반짝임 · 뿌연 빛은 사라진다)
			for _, a in ipairs(atmospheres) do
				local saved = atmoSaved[a]
				if saved and a.Parent then
					a.Density = saved[1] + (math.max(saved[1], 0.62) - saved[1]) * e
					a.Haze = saved[2] * (1 - e)
					a.Glare = saved[3] * (1 - e)
					a.Color = saved[4]:Lerp(black, e)
					a.Decay = saved[5]:Lerp(black, e)
				end
			end
		end

		-- 화면이 완전히 까만 순간 : 보이지 않는 동안 한꺼번에 바꾼다
		local swapped = false
		local function swap()
			if swapped or stage ~= myStage then
				return
			end
			swapped = true
			for _, wall in ipairs(walls) do
				wall.LocalTransparencyModifier = 0
			end
			for _, a in ipairs(atmospheres) do
				a.Parent = nil
			end
			lerpLighting(1)
			Lighting.FogColor = black
			Lighting.FogStart = 26
			Lighting.FogEnd = 46
			Lighting.ClockTime = 0
			-- 날씨 색보정 · 내 발밑 불빛도 이 순간에 꺼진다 (WorldController 가 이 표시를 본다)
			stage:SetAttribute("Dark", true)
		end

		local reduce = reduced
		local creep = reduce and 0.45 or DARK.creep
		local hold = DARK.hold
		local reveal = reduce and 0.45 or DARK.reveal
		local startedAt = os.clock()
		veilToken += 1
		stopDarkness()
		darkConn = Run.RenderStepped:Connect(function()
			if stage ~= myStage then
				stopDarkness()
				return
			end
			local now = os.clock()
			local t = now - startedAt
			if t < creep then
				-- 1) 몰려온다 : 처음엔 느리게, 갈수록 빠르게 (가장자리 → 가운데)
				local a = t / creep
				local e = a * a * a
				lerpLighting(e * 0.9)
				drawEdges(0.08 + 0.55 * (a * a), 0.35 + 0.65 * a, now)
				veil.BackgroundTransparency = 1 - e
			elseif t < creep + hold then
				-- 2) 완전히 까맣다
				veil.BackgroundTransparency = 0
				drawEdges(0.63, 1, now)
				swap()
			elseif t < creep + hold + reveal then
				swap()
				-- 3) 등불이 가물거리며 켜지고 어둠은 가장자리로 물러난다
				local a = (t - creep - hold) / reveal
				local e = 1 - (1 - a) * (1 - a)
				local flicker = reduce and 1 or (0.82 + 0.18 * math.sin(now * 37) * math.sin(now * 11))
				light.Brightness = 3.2 * e * flicker
				veil.BackgroundTransparency = e
				drawEdges(0.63 + (DARK.rest - 0.63) * e, 1 - 0.2 * e, now)
			else
				swap()
				light.Brightness = 3.2
				veil.BackgroundTransparency = 1
				drawEdges(DARK.rest, 0.8, now)
				-- 게임 내내 가장자리 그늘이 아주 천천히 일렁인다 (연출 줄이기면 멈춘 채로)
				if reduce then
					stopDarkness()
				end
			end
		end)
	end
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
-- Phase 38 : 1인칭 고개 돌리기 (좌우 yaw · 위아래 pitch, 라디안). 3인칭의 yaw(통 둘레를 도는 카메라)와 따로 둔다
local fpLook = { yaw = 0, pitch = 0, padPitch = 0 }
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
			-- Phase 37 : 1인칭이면 내 칼은 1인칭 손이 직접 들어 올려 꽂는다 (날아가는 칼을 손이 움직인다)
			local byHand = userId == player.UserId and hands:takeStab(copy, ctx, plan, STAB.Settle)
			local follow
			follow = Run.RenderStepped:Connect(function()
				if byHand then
					follow:Disconnect()
					return
				end
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
						sound("pick", final and 1.55 or 2.1, final and 1.6 or 1.1) -- Phase 24.10 : 그래도 작았다 (0.6 · 0.42 → 1.6 · 1.1)
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
local liveGhosts = {} -- Phase 32 : 이번 잡기에 나온 해적 전부 (쌍둥이는 둘)

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

--------------------------------------------------
-- Phase 32 : 해적 종류 표시
--   해적 스킨은 그대로 두고, 그 위에 종류 색 테두리(Highlight) · 머리 위 표시 · (유령은) 반투명만 덧입힌다.
--   그래서 어떤 스킨(부품 해적 · Blender 해적 · 용 세트 …)이든 종류가 똑같이 알아보인다.
--------------------------------------------------
local KINDS = config.PirateKinds
local function kindLook(kindId)
	local def = KINDS and KINDS.List[kindId or "normal"] or nil
	if not def then
		return nil
	end
	return { id = kindId, color = def.color, label = def.short, name = def.name, ghostly = kindId == "skull" }
end

local function decorate(rig, look)
	if not look or not rig.model then
		return
	end
	local outline = Instance.new("Highlight")
	outline.Name = "KindOutline"
	outline.FillColor = look.color
	outline.FillTransparency = look.ghostly and 0.55 or 0.88
	outline.OutlineColor = look.color
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Adornee = rig.model
	outline.Parent = rig.model
	local anchor = rig.model.PrimaryPart
	if anchor then
		-- Phase 32.1 : 이모지 대신 종류 아이콘 그림 + 짧은 말
		local tag = Instance.new("BillboardGui")
		tag.Name = "KindTag"
		tag.Size = UDim2.fromOffset(176, 64)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 4.9, 0)
		tag.AlwaysOnTop = true
		tag.LightInfluence = 0
		tag.Adornee = anchor
		tag.Parent = rig.model
		ArtAtlas.icon(tag, look.id or "normal", { size = UDim2.fromOffset(60, 60), position = UDim2.new(0, 0, 0.5, 0), anchor = Vector2.new(0, 0.5) })
		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, -64, 0.8, 0)
		text.Position = UDim2.new(0, 64, 0.1, 0)
		text.BackgroundTransparency = 1
		text.FontFace = UIKit.font(true)
		text.TextScaled = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextColor3 = look.color
		text.Text = look.label or ""
		text.Parent = tag
		UIKit.textStroke(text, 3)
	end
end

--[[
	해적 (Phase 11)
	kind
	  "real" : 잡기 중인 진짜 해적. 결과가 오면 물러나거나(잡힘) 달려든다(탈락).
	  "rage" : 분노한 해적. 잡을 수 없다. 튀어나오자마자 달려든다.
	  "fake" : 방해 아이템 "해적의 포효". 잠깐 나왔다 사라진다.
	자세는 매 프레임 PirateModel:pose 로 잡는다. 서는 지점은 SCARE.GhostRise / GhostLunge 와 같다.
	Phase 32 : opts
	  offset : 옆으로 비켜 서는 거리(스터드 · 월드 벡터). 쌍둥이는 둘이 나란히, 갈고리 해적은 한쪽으로
	  look   : kindLook(종류) — 테두리 색 · 머리 위 표시 · 유령(반투명)
	  lean   : 옆으로 기울이는 각도 (갈고리 해적이 그쪽으로 몸을 내민다)
]]
local function spawnPirate(model, own, kind, opts)
	local pos = center(model)
	if not pos then
		return nil
	end
	kind = kind or "real"
	opts = opts or {}
	local skin = config.findSkin("Ghost", player:GetAttribute(SKIN_ATTR.Ghost))
	local rig = PirateModel.new(skin, visuals)
	rig.model.Parent = fx
	if skin then
		SkinFX.applyGhost(rig.model, skin)
	end
	rig:adopt(CFrame.new())
	ghostHeight = rig.height or SCARE.GhostFallback
	if kind == "rage" or kind == "angry" or kind == "spit" then -- Phase 24.10 : 분노한 해적(먹물)도 붉은 눈
		for _, item in ipairs(rig.items) do
			if item.part.Name == "Eye" or item.part.Name == "Claw" or item.part.Name == "Socket" or item.part.Name == "HandR" then
				item.part.Color = Color3.fromRGB(255, 60, 50)
				item.part.Material = Enum.Material.Neon
			end
		end
	end

	local direction = facing(pos)
	local base = CFrame.lookAt(pos, pos + direction)
	if typeof(opts.offset) == "Vector3" then
		base = base + opts.offset
	end
	if opts.lean then
		base = base * CFrame.Angles(0, 0, math.rad(opts.lean))
	end
	local lunge = (own and not reduced) and SCARE.GhostLunge or 0
	local ghost = { rig = rig, state = "erupt", bornAt = os.clock(), kind = kind, stateAt = os.clock(), fade = 0 }
	-- Phase 32 : 해골 유령은 반투명 (사라질 때도 이 값보다 진해지지 않는다)
	ghost.fadeFloor = (opts.look and opts.look.ghostly) and 0.5 or 0
	ghost.flickerAt = opts.flickerAt -- Phase 38 : 해골 유령이 이 시각에 사라지는 척한다
	decorate(rig, opts.look)
	if ghost.fadeFloor > 0 then
		rig:fade(ghost.fadeFloor)
	end
	local function fadeTo(a)
		rig:fade(math.max(ghost.fadeFloor, a))
	end

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
			fadeTo(a * 0.7)
			if a >= 1 then
				ghost.state = "gone"
			end
		elseif ghost.state == "lunge" then
			-- 달려든다 (카메라 쪽으로)
			local a = math.clamp(s / 0.22, 0, 1)
			local e = 1 - (1 - a) ^ 3
			place(rise - 0.4 * e, lunge + 2.6 * e, { lean = 16 + 22 * e, reach = 1, jaw = 1, claw = 25 * e, nod = -12 * e })
			if s > 0.55 then
				fadeTo(math.clamp((s - 0.55) / 0.4, 0, 1))
			end
			if s > 1 then
				ghost.state = "gone"
			end
		elseif ghost.state == "fading" then
			local a = math.clamp(s / 0.4, 0, 1)
			place(rise + 0.5 * a, lunge, { lean = 8, reach = 0.6, jaw = 0.3 })
			fadeTo(a)
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
			-- Phase 38 : 해골 유령 깜빡임 — 0.4초 동안 거의 사라졌다가 다시 나타난다 (그동안 눌러도 탈락)
			if ghost.flickerAt then
				local f = now - ghost.flickerAt
				if f >= 0 and f < 0.4 then
					fadeTo(0.94)
					ghost.flickered = true
				elseif ghost.flickered then
					fadeTo(0)
					ghost.flickerAt = nil
				end
			end
			if (kind == "fake" and t > (ghost.fadeAt or 1.1)) or (kind == "spit" and t > (ghost.fadeAt or 1.1)) then
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
	if kind == "real" or kind == "angry" then
		ghostLive = ghost
		table.insert(liveGhosts, ghost)
	end
	return ghost
end

--------------------------------------------------
-- Phase 38 : 칼 던지기 — 해적을 잡는 누름이 이제 "칼을 던져 맞히기"로 보인다 (판정은 그대로 : 타이밍 · 방향 · 연타)
--   내 누름 : 누르는 순간 던진다 (1인칭이면 1인칭 손이 휙, 3인칭이면 내 캐릭터 손에서). 맞는 때면 해적에 꽂히고, 아니면 빗나간다.
--   다른 사람 : 잡았다는 결과가 오면 그 사람 손에서 해적마다 한 자루씩 날아간다.
--------------------------------------------------
local throwKnife, aimThird
do
	local function handOf(character)
		if not character then
			return nil
		end
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("Head")
		return hand and hand:IsA("BasePart") and hand or nil
	end
	-- Phase 38.1 : 3인칭 던질 준비 — 해적을 기다리는 동안 팔을 머리 뒤로 젖히고, 손에 칼을 쥐고 있다
	local heldKnife, heldConn, heldHideUntil, swingUntil = nil, nil, 0, 0
	function aimThird(on, swing, keep)
		local character = player.Character
		if swing then
			-- 휘두름이 끝나면 StabMotion 이 스스로 다시 젖히거나(keep) 제자리로 돌린다
			StabMotion.throwSwing(character, keep)
			heldHideUntil = os.clock() + 0.22 -- 던진 칼은 손을 떠났다 (잠시 뒤 새 칼)
			swingUntil = os.clock() + 0.2
			if not keep and heldKnife then
				heldHideUntil = math.huge
			end
			return
		end
		if on then
			StabMotion.throwReady(character, true)
			if not heldKnife then
				heldKnife = hands.makeKnife(config.findSkin("Knife", player:GetAttribute(SKIN_ATTR.Knife) or "classic"))
				pcall(heldKnife.ScaleTo, heldKnife, 0.7)
				heldKnife.Parent = fx
				heldConn = Run.RenderStepped:Connect(function()
					local hand = handOf(player.Character)
					if not hand or not heldKnife or not heldKnife.Parent then
						return
					end
					local hidden = os.clock() < heldHideUntil
					heldKnife:PivotTo(hidden and CFrame.new(0, -500, 0) or hand.CFrame * CFrame.new(0, -0.25, 0) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, 0, -0.8))
				end)
			end
		else
			if heldConn then
				heldConn:Disconnect()
				heldConn = nil
			end
			if heldKnife then
				heldKnife:Destroy()
				heldKnife = nil
			end
			heldHideUntil = 0
			if os.clock() >= swingUntil then
				StabMotion.throwReady(character, false) -- 휘두르는 중이면 휘두름이 끝나고 스스로 돌아온다
			end
		end
	end

	-- from : CFrame(1인칭 손의 칼) · Model(캐릭터) · nil(내 캐릭터) / ghost : 맞힐 해적 (없으면 통 뚜껑 쪽으로 빗나간다)
	function throwKnife(model, from, ghost, hit, skinId)
		local fromCF = typeof(from) == "CFrame" and from or nil
		if not fromCF then
			local hand = handOf(typeof(from) == "Instance" and from or player.Character)
			if not hand then
				return
			end
			fromCF = hand.CFrame
		end
		local ghostPart = ghost and ghost.rig and ghost.rig.model and ghost.rig.model.PrimaryPart
		local target = ghostPart and (ghostPart.Position + Vector3.new(0, 0.6, 0)) or (lidTop(model) or fromCF.Position + fromCF.LookVector * 5)
		local knife = hands.makeKnife(config.findSkin("Knife", skinId or "classic"))
		pcall(knife.ScaleTo, knife, 0.7)
		knife.Parent = fx
		local start = fromCF.Position
		local dir = target - start
		if dir.Magnitude < 0.1 then
			knife:Destroy()
			return
		end
		local flight = math.clamp(dir.Magnitude / 40, 0.08, 0.2)
		local born = os.clock()
		local stuck, stuckAt, rel = false, 0, nil
		local conn
		conn = Run.RenderStepped:Connect(function()
			if not knife.Parent then
				conn:Disconnect()
				return
			end
			local now = os.clock()
			if not stuck then
				local a = math.clamp((now - born) / flight, 0, 1)
				local extra = hit and 0 or 0.6 * a -- 빗나가면 조금 더 날아가며 떨어진다
				local pos = start:Lerp(target, a) + dir.Unit * (extra * 3) + Vector3.new(0, math.sin(a * math.pi) * 0.35 - extra * 1.5, 0)
				-- 날끝(-Z)이 날아가는 쪽 · 끝으로 두 바퀴 돌고 도착할 때 날끝이 앞
				knife:PivotTo(CFrame.lookAt(pos, pos + dir.Unit) * CFrame.Angles(-a * math.pi * 4, 0, 0))
				if a >= 1 then
					stuck, stuckAt = true, now
					if hit then
						burst(target, gold, reduced and 4 or 12)
						sound("pick", 1.9, 0.9)
						if ghostPart and ghostPart.Parent then
							rel = ghostPart.CFrame:ToObjectSpace(knife:GetPivot())
						end
					else
						sound("tick", 0.8, 0.3)
					end
				end
			else
				local s = now - stuckAt
				if rel and ghostPart and ghostPart.Parent then
					knife:PivotTo(ghostPart.CFrame * rel) -- 맞은 해적을 따라 통 속으로 끌려 들어간다
				end
				if s > (hit and 0.55 or 0.25) then
					conn:Disconnect()
					knife:Destroy()
				end
			end
		end)
	end
end

--------------------------------------------------
-- Phase 24.10 : 분노한 해적의 먹물
--   입에서 먹물 덩어리가 카메라 쪽으로 날아온다. 내가 잡을 차례면 맞은 순간 화면이 먹물로 얼룩진다.
--------------------------------------------------
local INK_COLOR = Color3.fromRGB(28, 10, 44)
local function inkSpray(ghost, mine, duration)
	local rig = ghost and ghost.rig
	if not rig or not rig.model.Parent then
		return
	end
	local eyes, count = Vector3.zero, 0
	for _, item in ipairs(rig.items) do
		if item.part.Name == "Eye" and item.part.Parent then
			eyes += item.part.Position
			count += 1
		end
	end
	local mouth = count > 0 and (eyes / count - Vector3.new(0, 0.45, 0)) or (rig.model:GetPivot().Position + Vector3.new(0, 1.5, 0))
	local camera = workspace.CurrentCamera
	local flight = 0.28
	sound("pick", 0.42, 0.9) -- 퉤!
	if not reduced and camera then
		local target = camera.CFrame.Position + camera.CFrame.LookVector * 1.6
		for i = 1, 7 do
			local blob = Instance.new("Part")
			blob.Name = "InkBlob"
			blob.Shape = Enum.PartType.Ball
			blob.Size = Vector3.one * (0.35 + math.random() * 0.35)
			blob.Color = INK_COLOR
			blob.Material = Enum.Material.SmoothPlastic
			blob.Anchored, blob.CanCollide, blob.CanQuery, blob.CanTouch, blob.CastShadow = true, false, false, false, false
			blob.CFrame = CFrame.new(mouth)
			blob.Parent = fx
			local spread = camera.CFrame.RightVector * (math.random() - 0.5) * 2.2 + camera.CFrame.UpVector * (math.random() - 0.5) * 1.4
			local delay = (i - 1) * 0.025
			task.delay(delay, function()
				if blob.Parent then
					Tween:Create(blob, TweenInfo.new(flight, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(target + spread), Size = blob.Size * 2.4 }):Play()
				end
			end)
			Debris:AddItem(blob, flight + delay + 0.05)
		end
	end
	if mine then
		task.delay(flight, function()
			showInk(duration or 2.4)
			sound("pick", 0.3, 0.7) -- 철퍼덕
			if not reduced then
				shakeUntil = math.max(shakeUntil, os.clock() + 0.25)
			end
		end)
	end
end

local function setGhostState(ghost, state)
	if ghost and ghost.rig and ghost.rig.model.Parent and ghost.state ~= "gone" then
		ghost.state = state
		ghost.stateAt = os.clock()
	end
end

-- 튀어나오는 순간 한꺼번에 : 뚜껑 폭발 · 섬광 · 비명 · 흔들림
-- Phase 32 : opts 는 spawnPirate 와 같다 (종류 표시 · 옆으로 비켜 서기). second = 쌍둥이의 둘째 (뚜껑은 이미 날아갔다)
local function erupt(model, own, kind, opts)
	if not (opts and opts.second) then
		blowLid(model, SCARE.Hold + SCARE.Release + 1.2)
	end
	local ghost = spawnPirate(model, own, kind, opts)
	if own then
		local red2 = kind == "rage" or kind == "angry"
		local look = opts and opts.look
		sound("danger", red2 and 0.5 or (look and look.ghostly and 1.1 or 0.72), 0.34)
		sound("riser", 1.6, 0.12)
		blink(red2 and red or (look and look.color) or ((config.findSkin("Ghost", player:GetAttribute(SKIN_ATTR.Ghost)) or {}).aura or teal), 0.6)
		if not reduced then
			shakeUntil = os.clock() + 0.55
		end
	end
	return ghost
end

--------------------------------------------------
-- 해적 잡기 (입력 · 연출)
--------------------------------------------------
local catch = nil -- { model, mine, kind, steps, step, side, need, taps, done, opensLocal, armUntil, rookie }
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

--------------------------------------------------
-- Phase 32 : 해적 종류 설명 카드 · 갈고리 해적 방향 표시
--   처음 만나는 종류(또는 튜토리얼)는 해적이 나오기 전에 "무엇을 · 어떻게" 카드를 보여 준다.
--   카드는 누를 수 없다 (아래의 잡기 입력을 가리지 않는다).
--------------------------------------------------
local showIntro, hideIntro, showChip
do
	-- Phase 32.1 : 540x180 → 460x150 (85%) · 알림판 바로 아래로 올려 잡기 고리를 덜 가린다 · 이모지 대신 아이콘 그림
	local introCard = Instance.new("Frame")
	introCard.Name = "KindIntro"
	introCard.AnchorPoint = Vector2.new(0.5, 0)
	introCard.Position = UDim2.new(0.5, 0, 0, 186)
	introCard.Size = UDim2.fromOffset(460, 118) -- Phase 33.1 : 150 → 118 (아래 절반이 비어 있었다)
	introCard.BackgroundColor3 = Color3.new(1, 1, 1)
	introCard.Visible = false
	introCard.Active = false
	introCard.ZIndex = 30
	introCard.Parent = gui
	UIKit.gradient(introCard, UIKit.Colors.Body, UIKit.Colors.BodyDark, 90)
	UIKit.corner(introCard, 16)
	local introStroke = UIKit.outline(introCard, 4)
	local introScale = Instance.new("UIScale")
	introScale.Parent = introCard
	local introIcon = ArtAtlas.icon(introCard, "normal", { size = UDim2.fromOffset(96, 96), position = UDim2.new(0, 12, 0.5, 0), anchor = Vector2.new(0, 0.5), zIndex = 31 })
	local introName = textLabel("Name", UDim2.new(1, -134, 0, 38), UDim2.fromOffset(118, 10), 30, introCard)
	introName.ZIndex = 31
	introName.TextXAlignment = Enum.TextXAlignment.Left
	local introHow = textLabel("How", UDim2.new(1, -134, 0, 62), UDim2.fromOffset(118, 50), 20, introCard)
	introHow.ZIndex = 31
	introHow.TextXAlignment = Enum.TextXAlignment.Left
	introHow.TextYAlignment = Enum.TextYAlignment.Top
	local introToken = 0
	local function fitIntro()
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		introScale.Scale = math.clamp(math.min((view.X - 24) / 480, view.Y / 560), 0.5, 1)
		-- Phase 33.1 : 잡는 동안에는 알림판이 숨으므로 화면 맨 위(Roblox 메뉴 줄 바로 아래)에 붙인다.
		--   예전(알림판 아래)에는 가로 휴대폰에서 화면 가운데 = 잡기 고리 한가운데를 덮었다.
		introCard.Position = UDim2.new(0.5, 0, 0, math.floor(GuiService:GetGuiInset().Y + 8))
	end
	fitIntro()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitIntro)
	end
	function showIntro(kindId, untilClock, tutorial)
		local def = KINDS and KINDS.List[kindId or "normal"]
		if not def then
			return
		end
		introToken += 1
		local token = introToken
		ArtAtlas.setIcon(introIcon, kindId or "normal")
		introName.Text = tutorial and (def.name or "해적") or ("처음 보는 해적 · " .. (def.name or "해적"))
		introName.TextColor3 = def.color or gold
		introHow.Text = def.how or ""
		if introStroke then
			introStroke.Color = def.color or gold
		end
		fitIntro()
		local full = introScale.Scale
		introScale.Scale = full * 0.85
		Tween:Create(introScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = full }):Play()
		introCard.Visible = true
		sound("riser", 1.4, 0.14)
		task.delay(math.max(0.6, untilClock - os.clock()), function()
			if token == introToken then
				introCard.Visible = false
				-- Phase 35.1 : 큰 카드가 사라지면 위의 작은 띠로 남는다 (잡기가 끝날 때까지)
				showChip(kindId)
			end
		end)
	end

	-- Phase 35.1 : 화면 맨 위의 작은 띠 (아이콘 · 이름 · 잡는 법 한마디). 누를 수 없다(잡기 입력을 막지 않는다).
	--   처음 보는 종류는 큰 카드 → 띠, 이미 본 종류는 띠만, 보통 해적은 띠도 없다.
	local chip = Instance.new("Frame")
	chip.Name = "KindChip"
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Size = UDim2.fromOffset(330, 42)
	chip.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
	chip.BackgroundTransparency = 0.25
	chip.Visible = false
	chip.Active = false
	chip.ZIndex = 29
	chip.Parent = gui
	UIKit.corner(chip, 21)
	local chipStroke = Instance.new("UIStroke")
	chipStroke.Thickness = 2
	chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	chipStroke.Parent = chip
	local chipScale = Instance.new("UIScale")
	chipScale.Parent = chip
	local chipIcon = ArtAtlas.icon(chip, "normal", { size = UDim2.fromOffset(38, 38), position = UDim2.new(0, 4, 0.5, 0), anchor = Vector2.new(0, 0.5), zIndex = 30 })
	local chipText = textLabel("Text", UDim2.new(1, -54, 1, 0), UDim2.fromOffset(46, 0), 19, chip)
	chipText.TextXAlignment = Enum.TextXAlignment.Left
	chipText.TextWrapped = false
	chipText.ZIndex = 30
	function showChip(kindId)
		local def = KINDS and KINDS.List[kindId or "normal"]
		if not def or kindId == "normal" or not catch or not catch.mine or catch.done then
			chip.Visible = false
			return
		end
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		chipScale.Scale = math.clamp(math.min((view.X - 24) / 360, view.Y / 560), 0.6, 1)
		chip.Position = UDim2.new(0.5, 0, 0, math.floor(GuiService:GetGuiInset().Y + 6))
		ArtAtlas.setIcon(chipIcon, kindId)
		-- Phase 38 : 라운드가 올라 세진 능력을 띠에 적는다
		local line = ("%s · %s"):format(def.name or "", def.short or "")
		if kindId == "twin" and #(catch.steps or {}) >= 3 then
			line = "세쌍둥이 해적 · 셋 다 잡기!"
		elseif kindId == "mash" and catch.need then
			line = ("%s · 연타 %d번!"):format(def.name or "", catch.need)
		elseif kindId == "side" and catch.feint then
			line = ("%s · 속임수 조심! 튀어나온 쪽"):format(def.name or "")
		elseif kindId == "skull" and catch.flicker then
			line = ("%s · 깜빡여도 참아!"):format(def.name or "")
		end
		chipText.Text = line
		chipText.TextColor3 = def.color or gold
		chipStroke.Color = def.color or gold
		chip.Visible = true
		local full = chipScale.Scale
		chipScale.Scale = full * 0.6
		Tween:Create(chipScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = full }):Play()
	end
	function hideIntro()
		introToken += 1
		introCard.Visible = false
		chip.Visible = false
	end
end

-- 갈고리 해적 : 화면 왼쪽 · 오른쪽 반쪽 안내 (누르는 곳을 보여 준다. 누르는 것은 catchButton 이 받는다)
local sideGuide = Instance.new("Frame")
sideGuide.Name = "SideGuide"
sideGuide.Size = UDim2.fromScale(1, 1)
sideGuide.BackgroundTransparency = 1
sideGuide.Visible = false
sideGuide.Active = false
sideGuide.ZIndex = 16
sideGuide.Parent = catchGui
local sideHalves = {}
for index, key in ipairs({ "L", "R" }) do
	local half = Instance.new("Frame")
	half.Name = key
	half.Size = UDim2.fromScale(0.5, 1)
	half.Position = UDim2.fromScale((index - 1) * 0.5, 0)
	half.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
	half.BackgroundTransparency = 1
	half.BorderSizePixel = 0
	half.Active = false
	half.ZIndex = 16
	half.Parent = sideGuide
	local arrow = textLabel("Arrow", UDim2.fromOffset(220, 140), UDim2.new(0.5, -110, 0.62, -70), 110, half)
	arrow.Text = key == "L" and "←" or "→"
	arrow.TextTransparency = 0.7
	arrow.ZIndex = 17
	sideHalves[key] = { frame = half, arrow = arrow }
end
local function drawSides(popped)
	for key, entry in pairs(sideHalves) do
		local lit = popped ~= nil and key == popped
		entry.frame.BackgroundTransparency = lit and 0.8 or 1
		entry.arrow.TextTransparency = popped == nil and 0.7 or (lit and 0 or 0.85)
		entry.arrow.TextColor3 = lit and Color3.fromRGB(150, 205, 255) or cream
	end
end

-- 해적이 나오기 전 통 틈에서 새어 나오는 빛. 종류마다 색이 달라서, 잘 보면 무슨 해적인지 미리 안다.
local function telegraph(model, color, fromClock, toClock)
	local top = lidTop(model)
	if not top or toClock - fromClock < 0.3 then
		return
	end
	local glow = makePart(fx, "KindGlow", Vector3.new(0.2, 0.2, 0.2), CFrame.new(top + Vector3.new(0, 0.3, 0)), color)
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 0
	light.Shadows = false
	light.Parent = glow
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(color)
	mist.LightEmission = 0.6
	mist.Size = NumberSequence.new(0.5, 1.6)
	mist.Transparency = NumberSequence.new(0.55, 1)
	mist.Lifetime = NumberRange.new(0.5, 0.9)
	mist.Speed = NumberRange.new(1.5, 3)
	mist.SpreadAngle = Vector2.new(35, 35)
	mist.Rate = 0
	mist.Enabled = not reduced
	mist.Parent = glow
	local conn
	conn = Run.RenderStepped:Connect(function()
		local now = os.clock()
		if now >= toClock or not glow.Parent then
			conn:Disconnect()
			if glow.Parent then
				glow:Destroy()
			end
			return
		end
		local a = math.clamp((now - fromClock) / math.max(0.05, toClock - fromClock), 0, 1)
		light.Brightness = 3 * a * (0.75 + 0.25 * math.sin(now * 20))
		mist.Rate = 18 * a
	end)
end

local function endCatchUI()
	catch = nil
	catchGui.Visible = false
	catchButton.Active = false
	catchText.Text = ""
	catchHint.Text = ""
	sideGuide.Visible = false
	hideIntro()
	setSeatLock(false)
	aimThird(false) -- Phase 38.1 : 던질 준비 자세를 푼다
end

-- 해적 종류마다 화면 아래 한 줄 안내
-- Phase 32.1 : 한 줄만 (예전에는 신입 보호 · 먼저 누르면 탈락까지 세 줄이 겹쳐 떴다). 신입 보호는 작은 구명환 표시로.
local kindHint
do
	local rookieBadge = Instance.new("Frame")
	rookieBadge.Name = "Rookie"
	rookieBadge.AnchorPoint = Vector2.new(0.5, 1)
	rookieBadge.Position = UDim2.new(0.5, 0, 0.62, -6)
	rookieBadge.Size = UDim2.fromOffset(190, 40)
	rookieBadge.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
	rookieBadge.BackgroundTransparency = 0.25
	rookieBadge.Visible = false
	rookieBadge.ZIndex = 18
	rookieBadge.Parent = catchStage
	UIKit.corner(rookieBadge, 20)
	ArtAtlas.icon(rookieBadge, "lifebuoy", { size = UDim2.fromOffset(36, 36), position = UDim2.new(0, 4, 0.5, 0), anchor = Vector2.new(0, 0.5), zIndex = 19 })
	local rookieText = textLabel("Text", UDim2.new(1, -48, 1, 0), UDim2.fromOffset(44, 0), 18, rookieBadge)
	rookieText.Text = "신입 보호 : 한 번 봐줘요"
	rookieText.TextXAlignment = Enum.TextXAlignment.Left
	rookieText.TextColor3 = gold
	rookieText.ZIndex = 19
	function kindHint(data)
		local kind = data.kind or "normal"
		local touch = Input.TouchEnabled and not Input.KeyboardEnabled
		local line
		if kind == "twin" then
			line = "두 마리 모두 잡아요! 나올 때마다 한 번씩 (한 마리만 잡으면 놓친 거예요)"
		elseif kind == "side" then
			line = touch and "튀어나온 쪽 화면(왼쪽 · 오른쪽)을 눌러요" or "튀어나온 쪽 : ← → 또는 A D"
		elseif kind == "skull" then
			line = "해골 유령은 누르면 탈락! 사라질 때까지 참아요"
		elseif kind == "mash" then
			line = ("칼을 붙잡았다! %d번 빠르게 연타"):format(data.need or 5)
		elseif kind == "angry" then
			line = "먹물을 뚫고 튀어나올 때 눌러요"
		elseif (tonumber(data.games) or 99) < 5 then
			line = touch and "해적이 튀어나오면 화면을 탭! (먼저 누르면 탈락)" or "해적이 튀어나오면 스페이스 · E · 클릭! (먼저 누르면 탈락)"
		else
			line = touch and "해적이 튀어나오면 화면을 탭!" or "해적이 튀어나오면 스페이스 · E · 클릭!"
		end
		rookieBadge.Visible = data.rookie == true and data.tutorial ~= true
		-- Phase 35.1 : 아래 한 줄 안내는 처음 5판 · 튜토리얼 · 신입 보호 중에만 (그 뒤로는 위의 작은 띠가 알려 준다)
		if (tonumber(data.games) or 99) >= 5 and not data.tutorial and not data.rookie then
			return ""
		end
		return line
	end
end

local lastTapAt = 0
local eruptKind = setmetatable({}, { __mode = "k" }) -- [테이블] = 곧 튀어나올 해적의 종류
local pendingPop = setmetatable({}, { __mode = "k" }) -- Phase 32 : [테이블] = 이번 잡기의 표 (결과가 오면 지워서 남은 해적이 나오지 않게)
-- side : 갈고리 해적 방향 ("L" · "R"). 없으면 방향 없는 누름 (스페이스 · E · 게임패드 A)
function sendCatch(side)
	if not catch or not catch.mine or catch.done then
		return
	end
	local kind = catch.kind or "normal"
	-- 버튼과 키가 같은 누름으로 두 번 들어오는 것은 한 번으로 친다 (연타 해적은 더 촘촘하게 받는다)
	local gap = kind == "mash" and 0.05 or 0.12
	if os.clock() - lastTapAt < gap then
		return
	end
	-- 칼 자리를 고른 손가락이 한 번 더 눌린 것은 버립니다. (서버도 같은 시간만큼 버립니다)
	if os.clock() < (catch.armUntil or 0) then
		return
	end
	if kind == "side" and side == nil then
		-- 방향이 없는 누름은 보내지 않는다 (먼저 누른 것으로 치지 않는다)
		catchHint.Text = "방향을 눌러요!  ← 왼쪽 · 오른쪽 →"
		return
	end
	lastTapAt = os.clock()
	local now = workspace:GetServerTimeNow()
	catchInput:FireServer(catch.model, now, side)
	local stepInfo = catch.steps[catch.step] or catch.steps[1]
	-- Phase 38 : 누를 때마다 칼을 던진다. 맞는 때(창 안 · 맞는 쪽 · 유령이 아님)면 해적에 꽂힌다
	do
		local tol = config.Catch.EarlyTolerance or 0
		local inWindow = now >= stepInfo.opensAt - tol and now <= stepInfo.opensAt + (stepInfo.window or 0.6) + (config.Catch.Grace or 0.05)
		local onTarget = inWindow and kind ~= "skull" and not (kind == "side" and side ~= catch.side)
		local ghost = liveGhosts[math.min(catch.step or 1, #liveGhosts)]
		local from = hands:toss()
		if not from then
			-- 3인칭 : 젖혀 둔 팔을 휘둘러 던진다. 쌍둥이 다음 마리 · 연타가 남았으면 다시 젖힌다
			local keep = (kind == "mash" and (catch.taps or 0) + 1 < (catch.need or 5))
				or (kind == "twin" and onTarget and (catch.step or 1) < #catch.steps)
			aimThird(true, true, keep)
		end
		throwKnife(catch.model, from, inWindow and ghost or nil, onTarget, player:GetAttribute(SKIN_ATTR.Knife))
	end
	if now < stepInfo.opensAt - (config.Catch.EarlyTolerance or 0) then
		-- ★ Phase 11 : 해적이 나오기 전에 눌렀다. 서버가 실패로 판정합니다.
		catch.done = true
		catchButton.Active = false
		catchText.Text = "너무 빨랐다!"
		catchText.TextColor3 = red
		return
	end
	if kind == "skull" then
		catch.done = true
		catchButton.Active = false
		catchText.Text = "앗! 유령을 눌렀다"
		catchText.TextColor3 = red
		return
	end
	if kind == "mash" then
		catch.taps = (catch.taps or 0) + 1
		local need = catch.need or 5
		catchText.Text = ("연타! %d/%d"):format(math.min(catch.taps, need), need)
		catchText.TextColor3 = gold
		sound("pick", 1.2 + 0.1 * catch.taps, 0.5)
		if catch.taps >= need then
			catch.done = true
			catchButton.Active = false
			catchText.Text = "잡았다!"
			catchText.TextColor3 = teal
		end
		return
	end
	if kind == "side" and side ~= catch.side then
		catch.done = true
		catchButton.Active = false
		catchText.Text = "반대쪽!"
		catchText.TextColor3 = red
		return
	end
	if (catch.step or 1) < #catch.steps then
		-- 쌍둥이 : 첫째를 잡았다
		catch.step += 1
		catchText.Text = ("%d/%d 잡았다! 하나 더…"):format(catch.step - 1, #catch.steps)
		catchText.TextColor3 = teal
		sound("win", 1.6, 0.2)
		local first = liveGhosts[catch.step - 1]
		if first then
			first.state, first.stateAt = "caught", os.clock()
		end
		return
	end
	catch.done = true
	catchButton.Active = false
	catchText.Text = "잡았다!"
	catchText.TextColor3 = teal
end

-- Phase 32 : 화면을 누른 자리(왼쪽 · 오른쪽 반)가 갈고리 해적의 방향이 된다. 누르는 순간 받는다 (떼는 순간이 아니라)
catchButton.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local width = catchButton.AbsoluteSize.X
	local x = input.Position.X - catchButton.AbsolutePosition.X
	sendCatch(width > 0 and (x < width * 0.5 and "L" or "R") or nil)
end)
-- Phase 32 : 키보드 · 게임패드는 정해진 키만 잡기로 친다 (예전에는 아무 키나 → W 로 걷거나 다른 키를 누르다 탈락했다)
--   스페이스 · 게임패드 A 는 위의 의자 잠금이 받는다. 방향 키는 갈고리 해적일 때만 잡기로 친다.
do
	local TAP_KEYS = { [Enum.KeyCode.E] = true, [Enum.KeyCode.Return] = true, [Enum.KeyCode.KeypadEnter] = true, [Enum.KeyCode.ButtonX] = true }
	local LEFT_KEYS = { [Enum.KeyCode.A] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.DPadLeft] = true, [Enum.KeyCode.ButtonL1] = true }
	local RIGHT_KEYS = { [Enum.KeyCode.D] = true, [Enum.KeyCode.Right] = true, [Enum.KeyCode.DPadRight] = true, [Enum.KeyCode.ButtonR1] = true }
	Input.InputBegan:Connect(function(input, processed)
		if not catch or not catch.mine then
			return
		end
		-- 채팅 입력 · 화면 버튼(→ 위 InputBegan) · 가로챈 스페이스(→ 의자 잠금)는 여기서 세지 않는다.
		if processed or Input:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		if TAP_KEYS[key] then
			sendCatch(nil)
		elseif catch.kind == "side" and LEFT_KEYS[key] then
			sendCatch("L")
		elseif catch.kind == "side" and RIGHT_KEYS[key] then
			sendCatch("R")
		end
	end)
end

catchPrompt.OnClientEvent:Connect(function(model, data)
	if typeof(model) ~= "Instance" or typeof(data) ~= "table" then
		return
	end
	dangerPending[model] = nil
	catchSeen[model] = os.clock()
	table.clear(liveGhosts)

	-- 서버 시계를 내 시계로 옮깁니다.
	local offset = os.clock() - workspace:GetServerTimeNow()
	local opensLocal = data.opensAt + offset
	local level = tonumber(data.level) or 1
	local kind = data.kind or (data.angry and "angry" or "normal")
	local look = kindLook(kind)
	local steps = typeof(data.steps) == "table" and data.steps or { { opensAt = data.opensAt, window = data.window } }

	-- 클로즈업이 "들이닥치는" 순간과 창이 열리는 순간을 맞춥니다.
	if not reduced then
		local lastStep = steps[#steps]
		local extra = math.max(0, (lastStep.opensAt or data.opensAt) - data.opensAt)
		shot = {
			model = model,
			startedAt = opensLocal - (SCARE.Lead + SCARE.Punch),
			total = SCARE.Lead + SCARE.Punch + SCARE.Hold + SCARE.Release + extra,
		}
	end
	lastTable = model
	holdUntil = math.max(holdUntil, opensLocal + SCARE.Hold + SCARE.Release + 1.6)

	-- ★ Phase 11 : 나오기 전 — 통이 덜컹거리고, 가끔 가짜 손이 튀어나왔다 들어간다.
	--   가짜 손에 속아 누르면 "너무 빨랐다"로 탈락이다. 잡을수록(단계가 오를수록) 더 자주 속인다.
	-- ★ Phase 32 : 가짜 손은 보통 해적에만, 그리고 신입(판 수 5 미만) · 튜토리얼 · 신입 보호 중에는 보여 주지 않는다.
	--   (처음 온 사람이 첫 해적부터 속아서 바로 지고 나가던 원인)
	local rattleFrom = os.clock() + 0.75
	rattle(model, rattleFrom, opensLocal)
	if look then
		telegraph(model, look.color, rattleFrom, opensLocal)
	end
	local lead = opensLocal - os.clock()
	-- Phase 24.10 : 분노한 해적은 먼저 반쯤 올라와 먹물을 뿜는다. 진짜 "지금!"은 그 뒤 통이 터지는 순간이다.
	--   (먹물 뿜을 때 누르면 너무 빨랐다) 가짜 손 속임수는 이때 넣지 않는다.
	local angry = kind == "angry"
	local pre = math.min(0.9, math.max(0, lead - 0.15))
	local veteran = (tonumber(data.games) or 99) >= 5 and not data.rookie and not data.tutorial
	if angry then
		task.delay(math.max(0, opensLocal - pre - os.clock()), function()
			local spitter = spawnPirate(model, true, "spit", { look = look })
			if spitter then
				spitter.fadeAt = math.max(0.3, pre - 0.12)
				task.delay(0.22, function()
					inkSpray(spitter, data.mine == true, data.ink)
				end)
			end
			sound("danger", 0.4, 0.3)
			if data.mine then
				announce("분노한 해적! 먹물을 뚫고 잡아라", red, 1.2)
			else
				announce(("%s · 분노한 해적!"):format(data.name or ""), red, 1.2)
			end
		end)
	elseif kind == "normal" and (veteran or not data.mine) and lead > 0.95 and math.random() < math.min(0.75, 0.3 + 0.12 * (level - 1)) then
		feint(model, os.clock() + math.max(0.8, lead - 0.35 - math.random() * 0.25))
	end

	task.delay(math.max(0, opensLocal - os.clock() - SCARE.Lead), function()
		sound("riser", 0.75, 0.18)
	end)

	-- 튀어나오기. 쌍둥이는 둘이 나란히 차례로, 갈고리 해적은 한쪽으로 비켜서 몸을 내민다.
	local camera = workspace.CurrentCamera
	local right = camera and Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z) or Vector3.new(1, 0, 0)
	if right.Magnitude > 0.01 then
		right = right.Unit
	end
	eruptKind[model] = angry and "angry" or "real"
	local popToken = {}
	pendingPop[model] = popToken
	-- Phase 38 : 갈고리 해적 속임수 — 진짜가 나오기 직전 반대쪽으로 고개를 쑥 내밀었다 들어간다 (그때 누르면 너무 빨랐다)
	if kind == "side" and data.feint and data.side and lead > 0.9 then
		local sign = data.side == "L" and 1 or -1 -- 반대쪽
		task.delay(math.max(0, opensLocal - 0.62 - os.clock()), function()
			if pendingPop[model] ~= popToken then
				return
			end
			local peek = spawnPirate(model, true, "fake", { look = look, offset = right * (2.3 * sign), lean = -14 * sign })
			if peek then
				peek.fadeAt = 0.5
			end
		end)
	end
	for index, stepInfo in ipairs(steps) do
		local at = stepInfo.opensAt + offset
		local opts = { look = look, second = index > 1 }
		if kind == "twin" then
			-- Phase 38 : 세쌍둥이는 셋째가 가운데
			opts.offset = right * (({ -1.6, 1.6, 0 })[index] or 0)
		elseif kind == "side" then
			local sign = data.side == "L" and -1 or 1
			opts.offset = right * (2.3 * sign)
			opts.lean = -14 * sign
		end
		task.delay(math.max(0, at - os.clock()), function()
			if pendingPop[model] ~= popToken then
				-- 결과가 먼저 왔다 : 먼저 눌러 탈락했으면 첫째만 달려들고(rage), 살려 준 경우 · 둘째는 나오지 않는다
				if index == 1 and eruptKind[model] == "rage" then
					eruptKind[model] = nil
					erupt(model, true, "rage", opts)
				end
				return
			end
			local eruptAs = index == 1 and (eruptKind[model] or "real") or "real"
			if index == 1 then
				eruptKind[model] = nil
			end
			if kind == "skull" and data.flicker then
				opts.flickerAt = os.clock() + (stepInfo.window or 1.2) * (0.35 + math.random() * 0.2)
			end
			erupt(model, true, eruptAs, opts)
			if catch and catch.model == model and catch.mine then
				if kind == "side" then
					drawSides(data.side)
				end
			end
		end)
	end

	if not data.mine then
		if not angry then
			task.delay(math.max(0, opensLocal - os.clock()), function()
				announce(("%s 잡는 중!"):format(data.name or ""), look and look.color or gold, 1.2)
			end)
		end
		return
	end

	catch = {
		model = model, mine = true, done = false,
		kind = kind, steps = steps, step = 1, side = data.side, need = data.need, taps = 0,
		opensAt = data.opensAt, window = data.window,
		opensLocal = opensLocal, index = data.index or 1,
		level = level, max = data.max, rookie = data.rookie,
		feint = data.feint, flicker = data.flicker, kindLevel = data.kindLevel,
		armUntil = os.clock() + (config.Catch.ArmDelay or 0.3),
	}
	catchGui.Visible = true
	catchButton.Active = true
	catchText.Text = ""
	catchHint.Text = kindHint(data)
	-- Phase 38.1 : 기다리는 동안 칼을 뒤로 젖혀 던질 준비 (1인칭은 1인칭 손이 한다)
	-- (해골 유령도 똑같이 든다 : 자세만 보고 유령인지 알 수 없게. 참는 것은 사람 몫)
	if not hands.shown then
		aimThird(true)
	end
	sideGuide.Visible = kind == "side"
	drawSides(nil)
	-- 처음 보는 종류 · 튜토리얼 : 해적이 나오기 0.5초 전까지 설명 카드
	if data.intro then
		-- Phase 34.1 : 카드는 IntroShow(1.5초)만 · 해적이 그보다 빨리 나오면 나오기 0.5초 전까지
		-- Phase 35.1 : 튜토리얼은 Tutorial.IntroShow(3초). 카드가 사라지면 위의 작은 띠로 남는다
		local showFor = data.tutorial and (tonumber(config.Tutorial.IntroShow) or 3) or (tonumber(KINDS and KINDS.IntroShow) or 1.5)
		showIntro(kind, math.min(os.clock() + showFor, opensLocal - 0.5), data.tutorial)
	else
		showChip(kind)
	end
	-- 잡기 창이 닫히고 서버 판정이 올 때까지 의자를 붙잡아 둔다. 결과가 오면 풀린다.
	local lastStep = steps[#steps]
	setSeatLock(true, (lastStep.opensAt + offset) + (lastStep.window or 0.6) + 4)
	-- 게임패드로 칼 자리 버튼이 선택돼 있으면 A 가 그 버튼으로 먹힌다. 잡기 입력이 되도록 선택을 푼다.
	if GuiService.SelectedObject then
		GuiService.SelectedObject = nil
	end
end)

do
	-- Phase 32 : 실패 까닭 · 살려 줄 때 한 마디
	local FAIL_TEXT = {
		early = "너무 빨랐다!",
		late = "놓쳤다…",
		timeout = "놓쳤다…",
		wrong = "반대쪽이었다!",
		grabbed = "유령을 잡아 버렸다!",
		spent = "분노한 해적!",
	}
	local SAVE_TIP = {
		early = "해적이 튀어나온 뒤에 눌러요",
		late = "조금 더 빨리!",
		timeout = "해적이 나오면 바로 눌러요",
		wrong = "튀어나온 쪽을 눌러요",
		grabbed = "유령은 누르면 안 돼요. 참아요!",
	}

	catchResult.OnClientEvent:Connect(function(model, data)
		local own = tableOfCharacter() == model or active == model or lastTable == model
		if not own then
			return
		end
		local mine = data.userId == player.UserId
		if mine then
			endCatchUI()
		end
		local ghosts = table.clone(liveGhosts)
		table.clear(liveGhosts)
		ghostLive = nil
		pendingPop[model] = nil

		if data.saved then
			-- Phase 32 : 신입 보호 · 튜토리얼 : 탈락하지 않고 같은 해적이 한 번 더 나온다
			local tip = SAVE_TIP[data.reason] or "다시 해 봐요"
			if data.kind == "mash" and (data.reason == "late" or data.reason == "timeout") then
				tip = "더 빠르게 연타!"
			end
			if mine then
				announce((data.saved == "tutorial" and "다시! " or "한 번 봐줄게요! ") .. tip, gold, 2.2)
			else
				announce(("%s · 다시 한 번!"):format(data.name or ""), gold, 1.4)
			end
			for _, ghost in ipairs(ghosts) do
				setGhostState(ghost, "fading")
			end
			eruptKind[model] = nil
			return
		end

		if data.success then
			local reaction = tonumber(data.reaction)
			local text
			if data.reason == "held" then
				text = mine and "참았다! 유령이 사라졌다" or ((data.name or "") .. " 참았다!")
			elseif mine then
				local timing = reaction and ("%.2f초 만에 "):format(math.max(0, reaction)) or ""
				text = timing .. (data.kind == "mash" and "연타 성공!" or "잡았다!") .. (data.perfect and " 퍼펙트!" or "")
			else
				text = (data.name or "") .. " 잡았다!" .. (reaction and (" (%.2f초)"):format(math.max(0, reaction)) or "")
			end
			announce(text, data.perfect and gold or teal, 1.8)
			-- Phase 38 : 다른 사람이 잡았으면 그 사람 손에서 해적마다 칼이 날아간다 (내 칼은 누를 때 이미 던졌다)
			if not mine and data.reason ~= "held" then
				local thrower = characterOfUser(model, data.userId)
				local who = Players:GetPlayerByUserId(data.userId or 0)
				for index, ghost in ipairs(ghosts) do
					task.delay((index - 1) * 0.12, function()
						throwKnife(model, thrower, ghost, true, who and who:GetAttribute(SKIN_ATTR.Knife) or nil)
					end)
				end
			end
			blink(data.perfect and gold or teal, 0.35)
			sound("win", data.perfect and 1.7 or 1.4, 0.3)
			-- 해적이 통으로 끌려 들어갑니다. (유령은 스르르 사라진다)
			for _, ghost in ipairs(ghosts) do
				setGhostState(ghost, data.kind == "skull" and "fading" or "caught")
			end
		else
			local why = FAIL_TEXT[data.reason] or "놓쳤다…"
			announce(mine and why or ((data.name or "") .. " 탈락"), red, 1.6)
			blink(red, 0.4)
			sound("danger", 0.6, 0.3)
			-- 해적이 달려든다. (먼저 눌러서 아직 안 나왔다면, 나오자마자 달려든다)
			if eruptKind[model] then
				eruptKind[model] = "rage"
			end
			for _, ghost in ipairs(ghosts) do
				setGhostState(ghost, "lunge")
			end
			if not reduced then
				shakeUntil = os.clock() + 0.45
			end
		end
	end)
end

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
		-- Phase 21 : 잭팟! 알림판의 현상금 숫자도 통통 튄다
		-- Phase 31 : 가운데 "획득" 창(누르면 닫히는 버튼)을 없앴다. 창이 해적 잡기 버튼 위에 떠서
		--   첫 터치가 창을 닫는 데 쓰이고 잡기가 늦어 탈락했다. 이제 안내 글자 · 금화 불꽃 · 소리만 (누를 것 없음)
		if own then
			local big = data.tier == "big"
			local pink = Color3.fromRGB(255, 120, 190)
			local who = data.userId == player.UserId and "" or ((data.who or "") .. " · ")
			announce(("%s%s +%s"):format(who, big and "💰 대박 잭팟!" or "💰 잭팟!", Utility.comma(data.amount or 0)),
				big and pink or gold, big and 2.6 or 2)
			for i, pitch in ipairs(big and { 1, 1.25, 1.5, 1.8 } or { 1.2, 1.5 }) do
				task.delay((i - 1) * 0.1, function()
					sound(i == 1 and "jackpot" or "win", pitch, 0.24)
				end)
			end
			blink(gold, big and 0.55 or 0.4)
			burst(pos + Vector3.new(0, 4, 0), gold, reduced and 12 or (big and 60 or 40))
			if not reduced then
				-- 한 박자 뒤 더 높이 한 번 더 터진다 (대박은 분홍 불꽃)
				task.delay(0.22, function()
					burst(pos + Vector3.new(0, 7, 0), big and pink or cream, big and 44 or 26)
				end)
			end
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
			if won then
				hands:cheer() -- Phase 37 : 1인칭 손이 칼을 치켜든다
			end
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
			-- Phase 32 : 같은 상대에게 또 이겨서 연승이 그대로다 (다른 사람이 낀 판에서 이겨야 오른다)
			if won and data.sameFoes then
				task.delay(2.8, function()
					announce("같은 상대라 연승은 그대로! 다른 선원과 이기면 올라요", cream, 2.8)
				end)
			end
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
			hands:drop() -- Phase 37 : 1인칭 손이 힘없이 떨어진다
			placeShown[model] = true
			local place = tonumber(data.place)
			task.delay(1.1, function()
				announce(place and ("패배 · %d위"):format(place) or "패배", red, 2.4)
			end)
			resultText, resultColor = "패배", red
		end
	elseif kind == "FateCard" then
		-- Phase 32 : 라운드마다 운명 카드
		local card = config.findFateCard(data.card)
		if own and card then
			showFateCard(card, tonumber(data.stage) or 1)
		end
	elseif kind == "Milestone" then
		-- Phase 32 : 끝없는 라운드 · 5라운드마다 보너스
		if own then
			local coins = tonumber(data.coins) or 0
			announce(("%d 라운드 돌파!%s"):format(tonumber(data.stage) or 0, coins > 0 and ((data.pot and "  현상금 +%s" or "  +%s"):format(Utility.comma(coins))) or ""), gold, 2.4)
			burst(pos + Vector3.new(0, 5, 0), gold, reduced and 10 or 36)
			sound("jackpot", 1.2, 0.22)
		end
	elseif kind == "TutorialDone" then
		-- Phase 32 : 튜토리얼 완료 (그 사람 화면에서만 크게)
		if data.userId == player.UserId then
			UIKit.rewardPopup({ title = "튜토리얼 완료!", text = ("%s 코인"):format(Utility.comma(tonumber(data.coins) or 0)), money = "chest", big = true })
			announce("튜토리얼 완료! 이제 다른 선원들과 겨뤄 봐요", gold, 3)
		end
	elseif kind == "Stage" then
		-- Phase 15 : 한 명이 떨어지고 다음 라운드가 시작된다
		-- Phase 24 : 통을 새로 채울 때마다 (칼을 다 꽂았거나 누가 탈락해서) 다음 라운드
		if own and model:GetAttribute(TABLE_ATTR.Stage) then
			local stage = tonumber(data.stage) or 1
			local final = data.final == true
			announce(("%d 라운드!"):format(stage), final and gold or teal, 1.6)
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
-- Phase 24 : 라운드(통)가 더 자주 바뀌므로 라운드마다 +8, 결승은 +14
local function heartRate(stage, final, danger)
	local round = math.max(1, tonumber(stage) or 1)
	local bpm = 64 + 8 * (round - 1)
	if final then
		bpm += 14
	end
	return math.min(156, bpm + 28 * danger)
end
local function heartbeatSound(danger, mine)
	-- Phase 24.10 : 게임 음악에 묻혀 거의 안 들렸다 (0.16 → 0.4). 위험할수록 더 커진다
	local volume = 0.4 + 0.35 * danger + (mine and 0.1 or 0)
	local Release = require(package.Shared:WaitForChild("ReleaseConfig"))
	if Release.audioId("Heartbeat") > 0 then
		sound("heartbeat", 1 + 0.06 * danger, volume * 1.6)
	else
		-- 기본 소리로 "쿵-쿵" 두 번 (낮은 음으로 늦춘 소리는 작게 들려서 더 키운다)
		sound("heart", 0.4, volume * 2.2)
		task.delay(0.19, function()
			sound("heart", 0.48, volume * 1.6)
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
		fpLook.yaw, fpLook.pitch = 0, 0
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
			leaveStage(true) -- Phase 32 : 까만 화면에서 원래 빛이 천천히 돌아온다
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
		-- 라운드 : Phase 24 부터 통 하나가 한 라운드 (칼을 다 꽂으면 다음 라운드). 셋 이상 시작해 둘이 남으면 "결승"
		local stage = model:GetAttribute(TABLE_ATTR.Stage) or 0
		local stages = model:GetAttribute(TABLE_ATTR.FinalRound) == true -- heartRate 에 넘기는 결승 여부
		local inRound = current == "Playing" or current == "Starting"
		roundChip.Visible = (inRound or current == "RoundEnding") and stage >= 1
		if roundChip.Visible then
			roundLabel.Text = ("라운드 %d"):format(stage) -- Phase 24 : "· 결승" 꼬리는 붙이지 않는다 (결승 음악 · 심장 박동만 바뀐다)
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
			detail.TextColor3 = red
			-- Phase 32 : 경고가 없으면 이번 라운드의 운명 카드를 한 줄로
			local card = warning == "" and config.findFateCard(model:GetAttribute("FateCard")) or nil
			if card then
				warning = ("%s · %s"):format(card.name or "", card.text or "")
				detail.TextColor3 = card.color or gold
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
		fpLook.padPitch = math.abs(input.Position.Y) > 0.2 and input.Position.Y or 0
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
		if firstPerson and tableOfCharacter() == active then
			-- Phase 38 : 1인칭 = 내 고개를 돌린다 (좌우는 끝없이 · 위아래는 -63도 ~ +57도)
			fpLook.yaw -= delta.X * 0.006
			fpLook.pitch = math.clamp(fpLook.pitch - delta.Y * 0.005, -1.1, 1.0)
		else
			yaw -= delta.X * 0.008
		end
	end
end)
Input.InputEnded:Connect(function(input)
	if dragInput and (input == dragInput or input.UserInputType == dragInput.UserInputType) then
		dragInput, dragLast = nil, nil
	end
end)

--------------------------------------------------
-- Phase 32 : 1인칭
--   내 자리에 앉아 게임 중일 때만 (관전 · 탈락 뒤에는 원래 카메라). 내 머리 · 모자 · 얼굴 장식은 내 화면에서만 숨긴다.
--------------------------------------------------
local showHead, firstPersonEye, drawViewButton
local FP_LIFT = 1.1 -- Phase 35.1 : 1인칭 시선을 이만큼(스터드) 올린다
do
	local hiddenHead = {} -- [BasePart] = 원래 LocalTransparencyModifier
	local bodyTouched = {} -- Phase 35.1 : 1인칭에서 보이게 · 숨기게 바꾼 팔 · 몸통 (3인칭으로 돌아가면 다시 보이게)
	function showHead()
		for part, value in pairs(hiddenHead) do
			if part.Parent then
				part.LocalTransparencyModifier = value
			end
		end
		table.clear(hiddenHead)
		for part in pairs(bodyTouched) do
			if part.Parent then
				part.LocalTransparencyModifier = 0
			end
		end
		table.clear(bodyTouched)
	end
	local function hideHead(character)
		local head = character:FindFirstChild("Head")
		for _, item in ipairs(character:GetDescendants()) do
			if item:IsA("BasePart") and (item == head or item:FindFirstAncestorOfClass("Accessory") ~= nil) then
				if hiddenHead[item] == nil then
					hiddenHead[item] = item.LocalTransparencyModifier
				end
				item.LocalTransparencyModifier = 1
			end
		end
	end
	-- Phase 37 : 1인칭에서는 진짜 몸(팔 포함)을 모두 숨기고, 1인칭 전용 손(FirstPersonHands)이 칼을 쥐고 꽂는다.
	--   (Phase 35.1 에서는 진짜 팔을 보였는데, 머리에 붙은 카메라에서는 팔이 화면 아래 끝에 걸려 잘 안 보였다)
	local function showArms(character)
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Name ~= "Head" then
				item.LocalTransparencyModifier = 1
				bodyTouched[item] = true
			end
		end
	end
	function firstPersonEye(model)
		if not firstPerson or not model or tableOfCharacter() ~= model then
			showHead()
			return nil
		end
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not head then
			showHead()
			return nil
		end
		hideHead(character)
		showArms(character)
		return head.Position + head.CFrame.LookVector * 0.35 + Vector3.new(0, 0.4, 0)
	end

	-- 게임 중 오른쪽 위 「1인칭」 버튼 (누를 때마다 3인칭 ↔ 1인칭 · 설정에 저장된다)
	local viewButton = UIKit.button(gui, { text = "1인칭", position = UDim2.new(1, -162, 0, 58), size = UDim2.fromOffset(150, 44), theme = "blue", textSize = 18, zIndex = 12 })
	viewButton.Name = "ViewToggle"
	viewButton.Visible = false
	viewButton.Activated:Connect(function()
		local want = not firstPerson
		player:SetAttribute("Setting_firstPerson", want) -- 바로 바뀌게 (서버가 저장하고 같은 값을 돌려준다)
		local request = remotes:FindFirstChild("VoyageRequest")
		if request then
			request:FireServer("settings", { firstPerson = want })
		end
		yaw = 0
	end)
	function drawViewButton()
		local show = active ~= nil and cameraOn and tableOfCharacter() == active and player:GetAttribute("PirateFocus") ~= true
		viewButton.Visible = show
		viewButton.Text = firstPerson and "3인칭" or "1인칭"
	end
end

--------------------------------------------------
-- 카메라 그리기
--------------------------------------------------
Run:BindToRenderStep("CursedBarrel_TableCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = workspace.CurrentCamera
	local pos = center(active)
	hands.want = false -- Phase 37 : 1인칭일 때만 아래에서 true
	drawViewButton()
	if not pos or not cameraOn or not camera then
		showHead() -- Phase 32 : 1인칭에서 숨긴 머리를 되돌린다
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
		local fpNow = firstPerson and tableOfCharacter() == active
		if fpNow then
			-- Phase 38 : 1인칭 고개 : ← → · A D 좌우, ↑ ↓ · W S 위아래, 게임패드 오른쪽 스틱
			local tilt = fpLook.padPitch
			if not Input:GetFocusedTextBox() then
				if Input:IsKeyDown(Enum.KeyCode.Up) or Input:IsKeyDown(Enum.KeyCode.W) then
					tilt += 1
				end
				if Input:IsKeyDown(Enum.KeyCode.Down) or Input:IsKeyDown(Enum.KeyCode.S) then
					tilt -= 1
				end
			end
			fpLook.yaw += turn * YAW_SPEED * dt
			fpLook.pitch = math.clamp(fpLook.pitch + tilt * YAW_SPEED * 0.7 * dt, -1.1, 1.0)
		elseif turn ~= 0 then
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

	-- Phase 32 : 1인칭. 내 머리에서 통을 내려다본다. 해적이 튀어나오면 저절로 해적을 올려다본다.
	--   내 팔(칼 꽂기 모션)은 보이고, 머리 · 모자는 내 화면에서만 숨긴다. 관전 중에는 쓰지 않는다.
	local fpEye = firstPersonEye(active)
	if fpEye then
		yaw = 0 -- 1인칭에서는 통 둘레를 돌지 않는다 (해적이 늘 나를 향해 튀어나오게)
		-- Phase 35.1 : 조금 더 위를 본다 (통 뚜껑과 해적이 튀어나오는 높이가 화면 가운데쯤. 예전에는 통 몸통을 내려다봤다)
		local look = pos + Vector3.new(0, FRAME.Aim * 0.55 + FP_LIFT, 0)
		-- Phase 38 : 내가 돌린 고개 (끌기 · 키 · 스틱). 해적이 튀어나오면 잠깐 해적을 보고 다시 돌린 곳으로 돌아온다
		local free = look - fpEye
		local reach = free.Magnitude
		if (fpLook.yaw ~= 0 or fpLook.pitch ~= 0) and reach > 0.01 then
			free = CFrame.Angles(0, fpLook.yaw, 0):VectorToWorldSpace(free)
			local flat = Vector3.new(free.X, 0, free.Z)
			if flat.Magnitude > 0.01 then
				local tilted = math.clamp(math.atan2(free.Y, flat.Magnitude) + fpLook.pitch, -1.35, 1.35)
				free = flat.Unit * math.cos(tilted) + Vector3.new(0, math.sin(tilted), 0)
			end
			look = fpEye + free.Unit * reach
		end
		local lookFov = 74
		if shot and shot.model == active then
			local elapsed = os.clock() - shot.startedAt
			if elapsed >= 0 then
				local ghostAim = pos + facing(pos) * SCARE.GhostLunge + Vector3.new(0, SCARE.GhostRise + SCARE.AimLift, 0)
				local a = math.clamp(elapsed / (SCARE.Lead + SCARE.Punch), 0, 1)
				a = a * a * (3 - 2 * a)
				local tail = shot.total - SCARE.Release
				if elapsed > tail then
					local b = math.clamp((elapsed - tail) / SCARE.Release, 0, 1)
					a *= 1 - b * b * (3 - 2 * b)
				end
				look = look:Lerp(ghostAim, a)
				lookFov = 74 + 10 * a
			end
		end
		local toward = look - fpEye
		-- Phase 37 : 1인칭 손이 칼을 찌르는 동안 몸이 슬롯 쪽으로 숙여진다 (팔이 슬롯에 닿을 만큼)
		hands.want = true
		hands.ready = active:GetAttribute(TABLE_ATTR.CurrentTurnUserId) == player.UserId
		-- Phase 38.1 : 해적을 기다리는 동안 칼을 젖혀 던질 준비 (해골 유령도 똑같이 든다 : 자세로 알아채지 못하게)
		hands.aiming = catch ~= nil and catch.mine and not catch.done and catch.model == active
		if hands.aiming then
			local stepInfo = catch.steps[catch.step or 1] or catch.steps[1]
			hands.tension = math.clamp(1 - (stepInfo.opensAt - workspace:GetServerTimeNow()) / 1.5, 0, 1)
		end
		fpEye += hands.leanVector
		local fpTarget = CFrame.lookAt(fpEye, fpEye + toward)
		local alpha = 1 - math.exp(-dt * 14)
		camera.CFrame = camera.CFrame:Lerp(fpTarget, alpha)
		camera.FieldOfView += (lookFov - camera.FieldOfView) * alpha
		if not reduced and player:GetAttribute("Setting_shake")~=false and os.clock() < shakeUntil then
			local amp = (shakeUntil - os.clock()) * 0.25
			camera.CFrame *= CFrame.new(math.sin(os.clock() * 70) * amp, math.cos(os.clock() * 53) * amp, 0)
		end
		return
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

-- Phase 37 : 1인칭 손 (카메라가 자리를 잡은 뒤에 그린다)
Run:BindToRenderStep("CursedBarrel_FPHands", Enum.RenderPriority.Camera.Value + 2, function(dt)
	hands:update(dt)
end)

-- 잡기 고리는 매 프레임 줄어듭니다.
-- Phase 32 : 해적 종류마다 글자가 다르다 (쌍둥이 "하나 · 둘" · 갈고리 "◀ 왼쪽!" · 유령 "참아!" · 연타 "연타! 0/5")
do
	local WAIT_TEXT = { skull = "…", mash = "기다려…", twin = "기다려… (둘!)", side = "기다려… (방향!)" }
	Run:BindToRenderStep("CursedBarrel_CatchRing", Enum.RenderPriority.Last.Value, function()
		if not catch or not catch.mine then
			return
		end
		local now = workspace:GetServerTimeNow()
		local kind = catch.kind or "normal"
		local stepInfo = catch.steps[catch.step] or catch.steps[1]
		local opensAt = stepInfo.opensAt
		local window = stepInfo.window or 0.6
		if now < opensAt then
			local wait = math.clamp((opensAt - now) / 0.9, 0, 1)
			local ringSize = math.min(catchRingMax, 320 + wait * 420)
			catchRing.Size = UDim2.fromOffset(ringSize, ringSize)
			ringStroke.Color = gold
			ringStroke.Transparency = 0.15 + wait * 0.5
			if not catch.done and (catch.step or 1) == 1 then
				catchText.Text = (kind == "twin" and #catch.steps >= 3) and "기다려… (셋!)" or (WAIT_TEXT[kind] or "기다려…")
				catchText.TextColor3 = cream
			end
		elseif not catch.done then
			local left = math.clamp(1 - (now - opensAt) / window, 0, 1)
			local ringSize = math.min(catchRingMax, 150 + left * 330)
			catchRing.Size = UDim2.fromOffset(ringSize, ringSize)
			ringStroke.Transparency = 0
			if kind == "skull" then
				-- 참는 시간 : 고리가 다 줄면 산다
				ringStroke.Color = Color3.fromRGB(230, 236, 255)
				catchText.Text = "참아!"
				catchText.TextColor3 = Color3.fromRGB(230, 236, 255)
				return
			end
			ringStroke.Color = left > 0.35 and teal or red
			if kind == "mash" then
				local need = catch.need or 5
				catchText.Text = ("연타! %d/%d"):format(math.min(catch.taps or 0, need), need)
				catchText.TextColor3 = gold
			elseif kind == "side" then
				catchText.Text = catch.side == "L" and "← 왼쪽!" or "오른쪽! →"
				catchText.TextColor3 = Color3.fromRGB(150, 205, 255)
			elseif kind == "twin" then
				catchText.Text = ({ "하나!", "둘!", "셋!" })[catch.step or 1] or "지금!"
				catchText.TextColor3 = cream
			else
				catchText.Text = "지금!"
				catchText.TextColor3 = cream
			end
			if left <= 0 then
				catchText.Text = "놓쳤다…"
				catchText.TextColor3 = red
			end
		end
	end)
end

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
