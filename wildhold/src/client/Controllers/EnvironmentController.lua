-- 하늘·조명·안개를 낮 → 노을 → 밤 → 새벽으로 부드럽게 바꾸고, 기지 소품(수정, 횃불, 떨어진 자원)을 살아 움직이게 한다.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Env = {}

local function ensure(className, name, props)
	local o = Lighting:FindFirstChild(name) or Instance.new(className)
	o.Name = name
	for k, v in pairs(props) do o[k] = v end
	o.Parent = Lighting
	return o
end

-- 단계별 분위기 (생존 톤): 낮은 평범하게 밝은 숲, 밤은 짙은 안개 속 어둠. 낮과 밤의 대비가 긴장감을 만든다.
-- 밤에는 기지 불빛과 캐릭터가 든 등불만 안전하게 느껴지고, 괴물은 안개 속에서 빛나는 눈부터 보인다.
local LOOKS = {
	Day = {Clock = 13.2, Brightness = 2.3, Ambient = "#3d444a", Outdoor = "#868d86", Exposure = 0.05,
		Atmo = {Density = 0.3, Offset = 0.18, Haze = 1.8, Glare = 0.2, Color = "#b3c1b6", Decay = "#77867a"},
		Grade = {Brightness = 0.01, Contrast = 0.12, Saturation = -0.03, TintColor = "#f6f7ee"}, Bloom = 0.45},
	Dusk = {Clock = 17.8, Brightness = 1.4, Ambient = "#3a2c2c", Outdoor = "#8a5f52", Exposure = -0.05,
		Atmo = {Density = 0.44, Offset = 0.12, Haze = 2.6, Glare = 0.8, Color = "#d9895a", Decay = "#5e2f33"},
		Grade = {Brightness = -0.02, Contrast = 0.16, Saturation = -0.02, TintColor = "#ffd2b0"}, Bloom = 0.7},
	Night = {Clock = 0.2, Brightness = 0.35, Ambient = "#07090f", Outdoor = "#10152a", Exposure = -0.15,
		Atmo = {Density = 0.6, Offset = 0.05, Haze = 2.8, Glare = 0, Color = "#1a2130", Decay = "#090c14"},
		Grade = {Brightness = -0.02, Contrast = 0.2, Saturation = -0.32, TintColor = "#b6c4ff"}, Bloom = 1.3},
	Dawn = {Clock = 6.3, Brightness = 1.2, Ambient = "#2e2c36", Outdoor = "#6e6478", Exposure = -0.05,
		Atmo = {Density = 0.46, Offset = 0.1, Haze = 2.6, Glare = 0.4, Color = "#b99aa4", Decay = "#4b4058"},
		Grade = {Brightness = 0, Contrast = 0.14, Saturation = -0.12, TintColor = "#ffe6e6"}, Bloom = 0.7},
}

function Env:Init()
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	self.Atmo = ensure("Atmosphere", "WildAtmosphere", {Offset = 0.15})
	ensure("Sky", "WildSky", {StarCount = 1200, CelestialBodiesShown = true, SunAngularSize = 14, MoonAngularSize = 9})
	self.Bloom = ensure("BloomEffect", "WildBloom", {Intensity = 0.5, Size = 28, Threshold = 1.5})
	self.Grade = ensure("ColorCorrectionEffect", "WildGrade", {})
	ensure("SunRaysEffect", "WildSunRays", {Intensity = 0.05, Spread = 0.8})
	ensure("DepthOfFieldEffect", "WildDepth", {FarIntensity = 0.12, FocusDistance = 60, InFocusRadius = 70, NearIntensity = 0})
	self.Look = nil
	self:Apply("Day", 0)
	workspace:GetAttributeChangedSignal("Phase"):Connect(function() self:PhaseChanged() end)
	self:PhaseChanged()
	self.Drops = {}
	self.Lanterns = {}
	RunService.RenderStepped:Connect(function(dt) self:Step(dt) end)
end

function Env:Apply(name, seconds)
	if self.Look == name then return end
	self.Look = name
	local look = LOOKS[name]
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local clock = look.Clock
	-- 시간은 24 를 넘어 이어지게 돌린다 (노을 → 한밤)
	if clock < Lighting.ClockTime and name == "Night" then
		clock = clock + 24
	end
	if seconds <= 0 then
		Lighting.ClockTime = look.Clock
	else
		local tween = TweenService:Create(Lighting, info, {ClockTime = clock})
		tween.Completed:Connect(function() if Lighting.ClockTime >= 24 then Lighting.ClockTime = Lighting.ClockTime - 24 end end)
		tween:Play()
	end
	local function go(obj, props)
		if seconds <= 0 then
			for k, v in pairs(props) do obj[k] = v end
		else
			TweenService:Create(obj, info, props):Play()
		end
	end
	go(Lighting, {Brightness = look.Brightness, Ambient = Color3.fromHex(look.Ambient), OutdoorAmbient = Color3.fromHex(look.Outdoor),
		ExposureCompensation = look.Exposure})
	go(self.Atmo, {Density = look.Atmo.Density, Offset = look.Atmo.Offset, Haze = look.Atmo.Haze, Glare = look.Atmo.Glare,
		Color = Color3.fromHex(look.Atmo.Color), Decay = Color3.fromHex(look.Atmo.Decay)})
	go(self.Grade, {Brightness = look.Grade.Brightness, Contrast = look.Grade.Contrast, Saturation = look.Grade.Saturation,
		TintColor = Color3.fromHex(look.Grade.TintColor)})
	go(self.Bloom, {Intensity = look.Bloom})
	self.Dark = name == "Night" or name == "Dusk"
	self:SetNightLights(self.Dark)
end

function Env:PhaseChanged()
	local phase = workspace:GetAttribute("Phase") or "Waiting"
	if phase == "Night" then
		self:Apply("Night", 4)
	elseif phase == "Dawn" then
		self:Apply("Dawn", 3)
	elseif phase == "Day" and self.Look == "Dawn" then
		task.delay(3, function() if workspace:GetAttribute("Phase") == "Day" then self:Apply("Day", 5) end end)
	elseif phase ~= "Night" then
		self:Apply("Day", 3)
	end
end

function Env:SetNightLights(on)
	self.Flicker = {}
	for _, model in ipairs(CollectionService:GetTagged("NightLight")) do
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("PointLight") then
				d.Enabled = on
				if not d:GetAttribute("BaseBrightness") then d:SetAttribute("BaseBrightness", d.Brightness) end
				table.insert(self.Flicker, d)
			end
		end
	end
	for _, burrow in ipairs(CollectionService:GetTagged("Burrow")) do
		local glow = burrow:FindFirstChild("Glow")
		if glow then
			glow.Transparency = on and 0.25 or 0.7
			local light = glow:FindFirstChildOfClass("PointLight")
			if light then light.Brightness = on and 4 or 1 end
		end
	end
end

function Env:Step()
	-- 해 지기 직전: 노을로 미리 바꿔 밤이 온다는 걸 보여준다
	local phase = workspace:GetAttribute("Phase")
	local endsAt = workspace:GetAttribute("PhaseEndsAt") or 0
	if phase == "Day" and endsAt - workspace:GetServerTimeNow() < 45 and self.Look == "Day" then
		self:Apply("Dusk", 8)
	end
	local t = os.clock()
	-- 불빛 흔들림 (횃불·모닥불이 살아 있는 느낌)
	if self.Dark and self.Flicker then
		for i, light in ipairs(self.Flicker) do
			local base = light:GetAttribute("BaseBrightness") or 1
			light.Brightness = base * (0.85 + 0.15 * math.sin(t * 9 + i * 1.7) * math.sin(t * 5.3 + i))
		end
	end
	self:UpdateLanterns()
	local root = workspace:FindFirstChild("WILDHOLD")
	local base = root and root:FindFirstChild("Base")
	-- Core 수정: 천천히 돌며 떠 있고, 체력이 줄면 붉게 물든다
	local core = base and base:FindFirstChild("Core")
	local crystal = core and core:FindFirstChild("Crystal")
	if crystal then
		if not self.CrystalHome then
			self.CrystalHome = crystal:GetPivot()
		end
		crystal:PivotTo(self.CrystalHome * CFrame.new(0, math.sin(t * 1.4) * 0.5, 0) * CFrame.Angles(0, t * 0.6, 0))
		local hit = core:FindFirstChild("Core")
		local hp, maxHP = hit and hit:GetAttribute("CurrentHealth"), hit and hit:GetAttribute("MaxHealth")
		if hp and maxHP and maxHP > 0 then
			local heart = crystal:FindFirstChild("Heart")
			local danger = 1 - hp / maxHP
			if heart then
				heart.Color = Color3.fromHex("#79f2e4"):Lerp(Color3.fromHex("#ff6b6b"), danger)
			end
		end
	end
	-- 떨어진 자원: 둥실둥실 돈다 (로컬에서만 움직이는 연출)
	local drops = root and root:FindFirstChild("Drops")
	if drops then
		for _, part in ipairs(drops:GetChildren()) do
			local home = self.Drops[part]
			if not home then
				home = part.CFrame
				self.Drops[part] = home
			end
			part.CFrame = CFrame.new(home.Position + Vector3.new(0, 0.4 + math.sin(t * 3 + home.Position.X) * 0.25, 0)) * CFrame.Angles(0, t * 2, 0) * home.Rotation
		end
		for part in pairs(self.Drops) do
			if not part.Parent then self.Drops[part] = nil end
		end
	end
end

-- 밤에는 모든 플레이어 캐릭터가 작은 등불을 든다 (어둠 속에서 서로를 찾을 수 있게)
function Env:UpdateLanterns()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local light = self.Lanterns[player]
			if not light or light.Parent ~= rootPart then
				light = Instance.new("PointLight")
				light.Name = "WildLantern"
				light.Range, light.Brightness, light.Shadows = 20, 1.2, false
				light.Color = Color3.fromHex("#ffc98a")
				light.Parent = rootPart
				self.Lanterns[player] = light
			end
			light.Enabled = self.Dark == true
		end
	end
	for player, light in pairs(self.Lanterns) do
		if not player.Parent then
			light:Destroy()
			self.Lanterns[player] = nil
		end
	end
end

return Env
