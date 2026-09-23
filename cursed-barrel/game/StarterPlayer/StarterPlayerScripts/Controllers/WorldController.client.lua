-- WorldController  (Phase 12)
-- 항해 시계를 화면에 그린다. (내 화면에서만)
--
--   · 하늘 : 낮 → 노을 → 밤 → 안개 → 폭풍 → 새벽. 단계가 바뀌면 10초에 걸쳐 부드럽게 바뀐다.
--   · 폭풍 : 비가 쏟아지고 번개가 친다. 번개가 치면 하늘이 번쩍이고 조금 뒤 천둥이 울린다.
--   · 화면 오른쪽 위에 지금 단계와 판 규칙, 남은 시간을 보여 준다.
--   · 크라켄 습격 : 체력 막대와 남은 시간. 시작 · 승리 · 도망을 크게 알린다.
--
-- 테이블 게임 중(검은 개인 무대 안)에는 하늘을 건드리지 않는다. 무대가 조명을 따로 쓰기 때문이다.
-- 무대에서 나오면 곧바로 지금 단계의 하늘로 돌아온다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local package = RS:WaitForChild("CursedBarrel")
local config = require(package.Shared:WaitForChild("GameConfig"))
local Release = require(package.Shared:WaitForChild("ReleaseConfig"))
local CameraShake = require(package.Shared:WaitForChild("CameraShake"))
local Sfx = require(package.Shared:WaitForChild("Sfx"))
local remotes = package:WaitForChild("Remotes")
local worldCue = remotes:WaitForChild(config.Remotes.WorldCue)

local WORLD = config.World
local gold = Color3.fromRGB(255, 206, 110)
local cream = Color3.fromRGB(244, 231, 198)
local teal = Color3.fromRGB(120, 255, 214)
local red = Color3.fromRGB(255, 96, 78)

-- 하늘을 이 스크립트가 맡는다는 표시. Phase4Controller 는 무대에서 나올 때 조명을 되돌리지 않고 맡긴다.
Lighting:SetAttribute("WeatherOwned", true)

local function reduced()
	return player:GetAttribute("Setting_reducedFX") == true
end

local function insideStage()
	local effects = workspace:FindFirstChild("CursedBarrel_LocalEffects")
	return effects ~= nil and effects:FindFirstChild("PrivateTableStage") ~= nil
end

--------------------------------------------------
-- 화면
--------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_World"
gui.ResetOnSpawn = false
gui.DisplayOrder = 11
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, size, position, textSize, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextColor3 = color or cream
	l.TextStrokeTransparency = 0.5
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local pill = Instance.new("Frame")
pill.Name = "Phase"
pill.AnchorPoint = Vector2.new(1, 0)
pill.Position = UDim2.new(1, -10, 0, 6)
pill.Size = UDim2.fromOffset(300, 44)
pill.BackgroundColor3 = Color3.fromRGB(14, 20, 30)
pill.BackgroundTransparency = 0.25
pill.Parent = gui
Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 10)
local phaseTitle = label(pill, UDim2.new(1, -16, 0, 20), UDim2.fromOffset(10, 3), 15, gold)
phaseTitle.TextXAlignment = Enum.TextXAlignment.Left
local phaseBlurb = label(pill, UDim2.new(1, -16, 0, 16), UDim2.fromOffset(10, 23), 12, cream)
phaseBlurb.TextXAlignment = Enum.TextXAlignment.Left

local raidBox = Instance.new("Frame")
raidBox.Name = "Raid"
raidBox.AnchorPoint = Vector2.new(1, 0)
raidBox.Position = UDim2.new(1, -10, 0, 56)
raidBox.Size = UDim2.fromOffset(300, 62)
raidBox.BackgroundColor3 = Color3.fromRGB(40, 12, 30)
raidBox.BackgroundTransparency = 0.15
raidBox.Visible = false
raidBox.Parent = gui
Instance.new("UICorner", raidBox).CornerRadius = UDim.new(0, 10)
local raidStroke = Instance.new("UIStroke")
raidStroke.Color = red
raidStroke.Thickness = 2
raidStroke.Parent = raidBox
local raidTitle = label(raidBox, UDim2.new(1, -16, 0, 20), UDim2.fromOffset(10, 3), 15, Color3.fromRGB(255, 170, 200))
raidTitle.TextXAlignment = Enum.TextXAlignment.Left
local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(10, 26)
barBack.Size = UDim2.new(1, -20, 0, 12)
barBack.BackgroundColor3 = Color3.fromRGB(20, 8, 16)
barBack.Parent = raidBox
Instance.new("UICorner", barBack).CornerRadius = UDim.new(0, 6)
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Color3.fromRGB(196, 80, 180)
barFill.Parent = barBack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 6)
local raidHint = label(raidBox, UDim2.new(1, -16, 0, 16), UDim2.fromOffset(10, 42), 12, cream)
raidHint.TextXAlignment = Enum.TextXAlignment.Left

local banner = label(gui, UDim2.new(0.8, 0, 0, 70), UDim2.new(0.1, 0, 0.14, 0), 30, gold)
banner.TextTransparency = 1
banner.TextStrokeTransparency = 1
local bannerToken = 0
local function announce(text, color, hold)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.TextColor3 = color or gold
	banner.TextTransparency = 0
	banner.TextStrokeTransparency = 0.4
	task.delay(hold or 3, function()
		if token == bannerToken then
			Tween:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 0
flash.Parent = gui

--------------------------------------------------
-- 하늘
--------------------------------------------------
local weatherCC = Lighting:FindFirstChild("CursedBarrel_Weather") or Instance.new("ColorCorrectionEffect")
weatherCC.Name = "CursedBarrel_Weather"
weatherCC.Parent = Lighting

local function atmosphere()
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if not air and not insideStage() then
		air = Instance.new("Atmosphere")
		air.Name = "CursedBarrel_Air"
		air.Parent = Lighting
	end
	return air
end

local function lerpNumber(a, b, t)
	return a + (b - a) * t
end

-- 하루 시간은 24시를 넘어 앞으로만 돈다 (노을 17.9 → 밤 0.2 은 6시간 앞으로)
local function lerpClock(a, b, t)
	local d = (b - a) % 24
	return (a + d * t) % 24
end

local function blend(from, to, t)
	local out = {}
	for key, value in pairs(to) do
		local start = from[key]
		if typeof(value) == "Color3" then
			out[key] = (start or value):Lerp(value, t)
		elseif key == "ClockTime" then
			out[key] = lerpClock(start or value, value, t)
		elseif typeof(value) == "number" then
			out[key] = lerpNumber(start or value, value, t)
		else
			out[key] = value
		end
	end
	return out
end

local function previousPhaseId(id)
	for index, phase in ipairs(WORLD.Phases) do
		if phase.id == id then
			local previous = WORLD.Phases[(index - 2) % #WORLD.Phases + 1]
			return previous.id
		end
	end
	return id
end

local flashPower = 0
local seaPart = nil
local function findSea()
	if seaPart and seaPart.Parent then
		return seaPart
	end
	local sea = workspace:FindFirstChild("Sea", true)
	seaPart = sea and sea:FindFirstChild("Water1") or nil
	return seaPart
end

local current = nil -- 지금 적용 중인 하늘 값
local function currentSky()
	local id = workspace:GetAttribute("WorldPhase") or "day"
	local to = WORLD.Sky[id] or WORLD.Sky.day
	local from = WORLD.Sky[previousPhaseId(id)] or to
	local startedAt = workspace:GetAttribute("WorldPhaseStartedAt") or 0
	local t = math.clamp((workspace:GetServerTimeNow() - startedAt) / math.max(1, WORLD.Transition), 0, 1)
	t = t * t * (3 - 2 * t)
	return blend(from, to, t)
end

local function applySky(sky)
	local boost = flashPower
	Lighting.Ambient = sky.Ambient:Lerp(Color3.new(1, 1, 1), boost * 0.5)
	Lighting.OutdoorAmbient = sky.OutdoorAmbient:Lerp(Color3.new(1, 1, 1), boost * 0.5)
	Lighting.Brightness = sky.Brightness + boost * 3
	Lighting.ClockTime = sky.ClockTime
	Lighting.ExposureCompensation = sky.Exposure + boost * 0.8
	local air = atmosphere()
	if air then
		air.Density = sky.Density
		air.Offset = sky.Offset
		air.Color = sky.AirColor
		air.Decay = sky.Decay
		air.Glare = sky.Glare
		air.Haze = sky.Haze
	end
	weatherCC.Enabled = true
	weatherCC.TintColor = sky.Tint
	weatherCC.Saturation = sky.Saturation
	weatherCC.Contrast = sky.Contrast
	weatherCC.Brightness = boost * 0.15
	local sea = findSea()
	if sea then
		sea.Color = sky.Sea
	end
end

--------------------------------------------------
-- 비
--------------------------------------------------
local rainPart = Instance.new("Part")
rainPart.Name = "CursedBarrel_Rain"
rainPart.Anchored = true
rainPart.CanCollide = false
rainPart.CanQuery = false
rainPart.CanTouch = false
rainPart.Transparency = 1
rainPart.Size = Vector3.new(150, 1, 150)
rainPart.Parent = workspace
local rain = Instance.new("ParticleEmitter")
local rainTexture = tonumber(Release.Textures and Release.Textures.Rain) or 0
if rainTexture > 0 then
	rain.Texture = "rbxassetid://" .. rainTexture
end
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Speed = NumberRange.new(85, 110)
rain.Lifetime = NumberRange.new(0.9, 1.2)
rain.SpreadAngle = Vector2.new(6, 6)
rain.Size = NumberSequence.new(0.16)
rain.Color = ColorSequence.new(Color3.fromRGB(190, 210, 230))
rain.Transparency = NumberSequence.new(0.35)
rain.LightEmission = 0.2
rain.Orientation = Enum.ParticleOrientation.VelocityParallel
rain.Rate = 0
rain.Parent = rainPart
pcall(function()
	rain.Squash = NumberSequence.new(3) -- 빗줄기처럼 길게
end)
local rainSound = Sfx.loop("Rain", 0)
local wavesSound = Sfx.loop("Waves", 0.25)
if wavesSound then
	wavesSound:Play()
end
if rainSound then
	rainSound:Play()
end

--------------------------------------------------
-- 번개
--------------------------------------------------
local nextBolt = os.clock() + 4

local function bolt()
	local camera = workspace.CurrentCamera
	local angle = math.random() * math.pi * 2
	local distance = 140 + math.random() * 320
	local base = Vector3.new(math.cos(angle) * distance, -2, math.sin(angle) * distance)
	local folder = Instance.new("Folder")
	folder.Name = "Lightning"
	folder.Parent = workspace
	local top = base + Vector3.new((math.random() - 0.5) * 40, 230, (math.random() - 0.5) * 40)
	local points = { top }
	local steps = 9
	for i = 1, steps do
		local t = i / steps
		local p = top:Lerp(base, t)
		if i < steps then
			p += Vector3.new((math.random() - 0.5) * 26, 0, (math.random() - 0.5) * 26)
		end
		points[#points + 1] = p
	end
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(215, 230, 255)
		segment.Size = Vector3.new(1.4, 1.4, (b - a).Magnitude)
		segment.CFrame = CFrame.lookAt((a + b) * 0.5, b)
		segment.Parent = folder
		Tween:Create(segment, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	end
	Debris:AddItem(folder, 0.45)
	flashPower = 1
	if not reduced() then
		flash.BackgroundTransparency = 0.75
		Tween:Create(flash, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
	end
	local near = camera and (camera.CFrame.Position - base).Magnitude or distance
	task.delay(math.clamp(near / 500, 0.2, 1.6), function()
		Sfx.play("Thunder", { pitch = 0.85 + math.random() * 0.3, volume = math.clamp(1 - near / 700, 0.25, 0.9) })
		if near < 260 then
			CameraShake.add(0.25, 0.6, 0.4)
		end
	end)
end

--------------------------------------------------
-- 매 틱
--------------------------------------------------
local tickAt = 0
Run.Heartbeat:Connect(function(dt)
	flashPower = math.max(0, flashPower - dt * 5)
	if os.clock() < tickAt then
		return
	end
	tickAt = os.clock() + 1 / 20

	local sky = currentSky()
	current = sky
	local stage = insideStage()
	if not stage then
		applySky(sky)
	else
		weatherCC.Enabled = false
	end

	-- 비는 카메라 위에서 쏟아진다
	local camera = workspace.CurrentCamera
	local amount = (not stage) and (sky.Rain or 0) or 0
	if camera then
		rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
	end
	rain.Rate = amount * (reduced() and 140 or 520)
	if rainSound then
		rainSound.Volume = amount * 0.55 * Sfx.volumeScale()
	end

	-- 번개 (습격 중에는 더 자주)
	local raid = workspace:GetAttribute("RaidActive") == true
	if (sky.Lightning or 0) > 0.5 and os.clock() > nextBolt then
		nextBolt = os.clock() + (raid and (3 + math.random() * 4) or (6 + math.random() * 8))
		if not stage then
			bolt()
		else
			-- 무대 안에서도 천둥은 들린다
			Sfx.play("Thunder", { pitch = 0.8 + math.random() * 0.3, volume = 0.4 })
		end
	end

	-- 오른쪽 위 안내
	local phase = config.findPhase(workspace:GetAttribute("WorldPhase") or "day")
	local endsAt = workspace:GetAttribute("WorldPhaseEndsAt") or 0
	local left = math.max(0, endsAt - workspace:GetServerTimeNow())
	phaseTitle.Text = ("%s %s  ·  %d:%02d"):format(phase.icon or "", phase.name, math.floor(left / 60), math.floor(left % 60))
	phaseBlurb.Text = phase.blurb or ""

	raidBox.Visible = raid
	if raid then
		local hp = workspace:GetAttribute("RaidHP") or 0
		local max = math.max(1, workspace:GetAttribute("RaidMaxHP") or 1)
		local raidLeft = math.max(0, (workspace:GetAttribute("RaidEndsAt") or 0) - workspace:GetServerTimeNow())
		raidTitle.Text = ("🐙 크라켄 습격!  체력 %d / %d  ·  %d:%02d"):format(hp, max, math.floor(raidLeft / 60), math.floor(raidLeft % 60))
		barFill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
		raidHint.Text = stage and "판을 마치고 뱃전의 대포로 크라켄을 쫓아내세요" or "뱃전의 대포(E)로 빛나는 약점 · 눈 · 내려치는 다리를 쏘세요"
		raidStroke.Transparency = 0.5 + 0.5 * math.sin(os.clock() * 6)
	end
end)

--------------------------------------------------
-- 서버 알림
--------------------------------------------------
worldCue.OnClientEvent:Connect(function(kind, data)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "Phase" then
		local phase = config.findPhase(data.id)
		local color = data.id == "storm" and red or (data.id == "night" and Color3.fromRGB(170, 190, 255) or gold)
		announce(("%s %s  —  %s"):format(phase.icon or "", phase.name, phase.blurb or ""), color, 3.5)
		if data.id == "storm" then
			nextBolt = os.clock() + 1.5
		end
	elseif kind == "Raid" then
		if data.state == "start" then
			announce("🐙 크라켄 습격!  배를 지켜라 — 대포로 쫓아내면 보상", red, 4)
			Sfx.play("KrakenRoar", { volume = 0.8 })
			CameraShake.add(0.6, 1.4, 1.2)
		elseif data.state == "victory" then
			local coins = data.rewards and data.rewards[player.UserId]
			announce(coins and ("크라켄을 물리쳤다!  +%d 코인"):format(coins) or "크라켄을 물리쳤다!", teal, 4)
			Sfx.play("Coins", { volume = 0.6 })
		elseif data.state == "escaped" then
			local coins = data.rewards and data.rewards[player.UserId]
			announce(coins and ("크라켄이 바다로 돌아갔다…  참여 보상 +%d"):format(coins) or "크라켄이 바다로 돌아갔다…", cream, 3.5)
		end
	elseif kind == "SlamBlocked" and data.userId == player.UserId then
		announce("내려치기를 막았다!", teal, 1.6)
	elseif kind == "Tourney" then
		announce(("🏆 토너먼트 시리즈 완료!  %d점 · +%d 코인"):format(data.score or 0, data.coins or 0), gold, 4)
		Sfx.play("Coins", { volume = 0.6 })
	end
end)

script.Destroying:Connect(function()
	gui:Destroy()
	rainPart:Destroy()
	Lighting:SetAttribute("WeatherOwned", nil)
end)
