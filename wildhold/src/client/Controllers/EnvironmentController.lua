-- 하늘·조명·안개를 낮 → 노을 → 밤 → 새벽으로 부드럽게 바꾸고, 기지 소품(수정, 횃불, 떨어진 자원)을 살아 움직이게 한다.
local Lighting = game:GetService("Lighting")
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

-- 단계별 분위기
local LOOKS = {
	Day = {Clock = 14.2, Brightness = 2.4, Ambient = "#4a5566", Outdoor = "#8a93a3", Exposure = 0.1,
		Atmo = {Density = 0.28, Haze = 1.2, Glare = 0.3, Color = "#c7dcef", Decay = "#9fb6c9"},
		Grade = {Brightness = 0.02, Contrast = 0.08, Saturation = 0.14, TintColor = "#ffffff"}, Bloom = 0.5},
	Dusk = {Clock = 17.6, Brightness = 2.0, Ambient = "#5a4a5c", Outdoor = "#a07a74", Exposure = 0.05,
		Atmo = {Density = 0.33, Haze = 2.2, Glare = 0.9, Color = "#ffc59a", Decay = "#b0687a"},
		Grade = {Brightness = 0, Contrast = 0.1, Saturation = 0.18, TintColor = "#ffe6d2"}, Bloom = 0.7},
	Night = {Clock = 0.2, Brightness = 1.1, Ambient = "#2c3150", Outdoor = "#3e4a78", Exposure = 0.25,
		Atmo = {Density = 0.38, Haze = 1.6, Glare = 0.1, Color = "#3b3f6b", Decay = "#1d2140"},
		Grade = {Brightness = 0.02, Contrast = 0.12, Saturation = -0.05, TintColor = "#c8d4ff"}, Bloom = 1.0},
	Dawn = {Clock = 6.4, Brightness = 1.8, Ambient = "#51475e", Outdoor = "#9a8aa6", Exposure = 0.1,
		Atmo = {Density = 0.3, Haze = 2.0, Glare = 0.6, Color = "#ffd0c2", Decay = "#9a86b8"},
		Grade = {Brightness = 0.02, Contrast = 0.08, Saturation = 0.12, TintColor = "#fff0f0"}, Bloom = 0.7},
}

function Env:Init()
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	self.Atmo = ensure("Atmosphere", "WildAtmosphere", {Offset = 0.2})
	ensure("Sky", "WildSky", {StarCount = 3500, CelestialBodiesShown = true, SunAngularSize = 18, MoonAngularSize = 14})
	self.Bloom = ensure("BloomEffect", "WildBloom", {Intensity = 0.5, Size = 28, Threshold = 1.5})
	self.Grade = ensure("ColorCorrectionEffect", "WildGrade", {})
	ensure("SunRaysEffect", "WildSunRays", {Intensity = 0.05, Spread = 0.8})
	ensure("DepthOfFieldEffect", "WildDepth", {FarIntensity = 0.12, FocusDistance = 60, InFocusRadius = 70, NearIntensity = 0})
	self.Look = nil
	self:Apply("Day", 0)
	workspace:GetAttributeChangedSignal("Phase"):Connect(function() self:PhaseChanged() end)
	self:PhaseChanged()
	self.Drops = {}
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
	go(self.Atmo, {Density = look.Atmo.Density, Haze = look.Atmo.Haze, Glare = look.Atmo.Glare, Color = Color3.fromHex(look.Atmo.Color),
		Decay = Color3.fromHex(look.Atmo.Decay)})
	go(self.Grade, {Brightness = look.Grade.Brightness, Contrast = look.Grade.Contrast, Saturation = look.Grade.Saturation,
		TintColor = Color3.fromHex(look.Grade.TintColor)})
	go(self.Bloom, {Intensity = look.Bloom})
	self:SetNightLights(name == "Night" or name == "Dusk")
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
	for _, model in ipairs(CollectionService:GetTagged("NightLight")) do
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("PointLight") then
				d.Enabled = on
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

return Env
