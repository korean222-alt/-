--[[
	RouletteWheel  (Phase 16)
	룰렛 판. "너무 조잡하다"를 고친다. (클라이언트 전용)

	진짜 3D 판을 ViewportFrame 안에 세운다. 그림을 올릴 필요가 없다.
	  · 칸마다 선명한 색 부채꼴 (삼각형 여러 장으로 둥글게) · 칸 사이 금색 칸막이
	  · 두꺼운 금테 + 짙은 나무 뒷판 + 테두리를 따라 반짝이는 전구 16개
	  · 가운데 금색 축 · 칸마다 큰 금액 글자 + 돈 그림(MoneyIcon) 또는 선물 상자
	  · Phase 16.1 : 평면(2D)처럼 보이게 고른 빛만 쓴다 (음영 · 그림자 없음). 기울인 3D 그림은 뺐다
	  · 위쪽에 고정된 빨간 3D 바늘

	돌리기는 판을 움직이지 않고 카메라를 굴린다 (파트 수백 개를 매 프레임 옮기지 않는다 · 휴대폰에서도 가볍다).
	칸 글자 · 그림은 화면 위에 따로 얹고, 돌아간 각도만큼 자리(글자는 기울기도)를 맞춘다.

	RouletteWheel.new(parent, segments, pixels) → wheel
	  wheel.frame            : 판 전체 (Frame)
	  wheel:setRotation(deg) : 시계 방향 각도 (예전 Frame.Rotation 과 같은 뜻)
	  wheel.rotation         : 지금 각도
	  wheel:setFast(bool)    : 도는 동안 전구가 빨리 반짝인다
	  wheel:celebrate()      : 멈춘 뒤 바늘이 통통 튄다
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MoneyIcon = require(script.Parent:WaitForChild("MoneyIcon"))

local RouletteWheel = {}
RouletteWheel.__index = RouletteWheel

-- 칸 색 (차례대로 돌아가며)
local PALETTE = {
	Color3.fromRGB(236, 62, 62),
	Color3.fromRGB(255, 190, 40),
	Color3.fromRGB(60, 146, 255),
	Color3.fromRGB(70, 200, 90),
	Color3.fromRGB(168, 86, 255),
	Color3.fromRGB(255, 136, 36),
	Color3.fromRGB(36, 196, 196),
	Color3.fromRGB(255, 96, 170),
}
local GOLD = Color3.fromRGB(255, 200, 60)
local GOLD_DARK = Color3.fromRGB(196, 124, 24)
local BACK = Color3.fromRGB(70, 26, 22)
local RADIUS = 10
local FIELD_OF_VIEW = 30

local function part(model, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- 세 점을 잇는 삼각형 (쐐기 파트 둘). 판 앞(+Z)을 향한다.
local function triangle(model, a, b, c, color, thickness)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	for index, info in ipairs({ { a + b, right, back, ab }, { a + c, -right, -back, ac } }) do
		local w = Instance.new("WedgePart")
		w.Name = "Slice" .. index
		w.Size = Vector3.new(thickness, height, math.abs(info[4]:Dot(back)))
		w.CFrame = CFrame.fromMatrix(info[1] / 2, info[2], up, info[3])
		w.Color = color
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CastShadow = false
		w.Parent = model
	end
end

-- 시계 방향 각도(도, 위가 0) → 판 위의 점 (x 오른쪽 · y 위)
local function onWheel(degrees, radius, z)
	local a = math.rad(degrees)
	return Vector3.new(math.sin(a) * radius, math.cos(a) * radius, z or 0)
end

local function iconFor(segment)
	if segment.kind == "skin" then
		return "gift"
	end
	local amount = tonumber(segment.amount) or 0
	if amount >= 5000 then
		return "chest"
	elseif amount >= 2000 then
		return "cash3"
	elseif amount >= 500 then
		return "cash2"
	elseif amount >= 120 then
		return "cash"
	end
	return "coins"
end

function RouletteWheel.new(parent, segments, pixels)
	local self = setmetatable({}, RouletteWheel)
	self.segments = segments
	self.step = 360 / #segments
	self.rotation = 0
	self.fast = false

	local frame = Instance.new("Frame")
	frame.Name = "RouletteWheel"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(pixels, pixels)
	frame:SetAttribute("NoStyle", true)
	frame.Parent = parent
	self.frame = frame

	local view = Instance.new("ViewportFrame")
	view.Name = "Wheel3D"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	-- 평면(2D) 느낌 : 빛 방향 없이 고른 빛만. 음영 · 그림자가 없어 칸 색이 그대로 선명하다
	--   (ViewportFrame 은 원래 그림자를 그리지 않는다)
	view.Ambient = Color3.fromRGB(255, 255, 255)
	view.LightColor = Color3.fromRGB(0, 0, 0)
	view.LightDirection = Vector3.new(0, 0, -1)
	view:SetAttribute("NoStyle", true)
	view.Parent = frame
	self.view = view

	local model = Instance.new("Model")
	model.Name = "Wheel"
	model.Parent = view

	-- 뒷판 · 금테
	local face = CFrame.Angles(0, math.pi / 2, 0) -- 원통 축(X)을 앞(Z)으로
	-- 앞면 높이(z) : 뒷판 -0.4 < 금테 -0.05 < 테 그림자 0 < 칸 0.15 < 밝은 띠 0.2 < 칸막이 0.5 < 축 · 전구 · 그림
	part(model, "Back", Vector3.new(0.8, (RADIUS + 1.9) * 2, (RADIUS + 1.9) * 2), CFrame.new(0, 0, -0.8) * face, BACK, Enum.Material.Wood, Enum.PartType.Cylinder)
	part(model, "GoldRim", Vector3.new(0.9, (RADIUS + 1.15) * 2, (RADIUS + 1.15) * 2), CFrame.new(0, 0, -0.5) * face, GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder).Reflectance = 0.1
	part(model, "RimShadow", Vector3.new(0.9, (RADIUS + 0.25) * 2, (RADIUS + 0.25) * 2), CFrame.new(0, 0, -0.45) * face, GOLD_DARK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)

	-- 칸 (부채꼴 = 가는 삼각형 여러 장)
	local slices = 6
	for index = 1, #segments do
		local color = PALETTE[(index - 1) % #PALETTE + 1]
		local from = (index - 1) * self.step - self.step / 2
		for k = 0, slices - 1 do
			local a0 = from + self.step * k / slices
			local a1 = from + self.step * (k + 1) / slices
			triangle(model, Vector3.new(0, 0, 0), onWheel(a0, RADIUS), onWheel(a1, RADIUS), color, 0.3)
		end
		-- 안쪽이 조금 밝은 띠 (입체감)
		for k = 0, slices - 1 do
			local a0 = from + self.step * k / slices
			local a1 = from + self.step * (k + 1) / slices
			triangle(model, onWheel(a0, RADIUS * 0.28, 0.05), onWheel(a0, RADIUS * 0.52, 0.05), onWheel(a1, RADIUS * 0.52, 0.05), color:Lerp(Color3.new(1, 1, 1), 0.18), 0.3)
			triangle(model, onWheel(a0, RADIUS * 0.28, 0.05), onWheel(a1, RADIUS * 0.52, 0.05), onWheel(a1, RADIUS * 0.28, 0.05), color:Lerp(Color3.new(1, 1, 1), 0.18), 0.3)
		end
		-- 칸막이
		local edge = onWheel(from, RADIUS * 0.5, 0.35)
		part(model, "Divider", Vector3.new(0.26, RADIUS, 0.3), CFrame.new(edge) * CFrame.Angles(0, 0, -math.rad(from)), GOLD, Enum.Material.SmoothPlastic)
	end

	-- 전구
	self.bulbs = {}
	for i = 1, 16 do
		local bulb = part(model, "Bulb", Vector3.new(0.7, 0.7, 0.7), CFrame.new(onWheel((i - 0.5) * 22.5, RADIUS + 1.2, 0.35)), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
		table.insert(self.bulbs, bulb)
	end

	-- 가운데 축
	part(model, "Hub", Vector3.new(0.9, 4.2, 4.2), CFrame.new(0, 0, 0.35) * face, GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder).Reflectance = 0.12
	part(model, "HubIn", Vector3.new(1, 3, 3), CFrame.new(0, 0, 0.45) * face, Color3.fromRGB(220, 44, 44), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(model, "HubCap", Vector3.new(1.1, 1.3, 1.3), CFrame.new(0, 0, 0.55) * face, GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)

	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	camera.Parent = view
	view.CurrentCamera = camera
	self.camera = camera
	self.distance = (RADIUS + 2.1) / math.tan(math.rad(FIELD_OF_VIEW / 2))

	-- 칸 이름 (화면 위 글자)
	self.labels = {}
	self.icons = {}
	for index, segment in ipairs(segments) do
		local label = Instance.new("TextLabel")
		label.Name = "Label" .. index
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromScale(0.19, 0.078)
		label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = tostring(segment.label or "")
		label.ZIndex = 3
		label:SetAttribute("NoStyle", true)
		label.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(30, 16, 12)
		stroke.Parent = label
		self.labels[index] = label
		-- 칸 그림 (돈 · 선물). 판과 함께 돌지만 늘 똑바로 서 있다
		self.icons[index] = MoneyIcon.view(frame, iconFor(segment), {
			name = "Icon" .. index, size = UDim2.fromScale(0.12, 0.12), anchor = Vector2.new(0.5, 0.5), zIndex = 3,
		})
	end

	-- 바늘 (위에 고정 · 판과 함께 돌지 않는다)
	local pin = Instance.new("ViewportFrame")
	pin.Name = "Pointer"
	pin.BackgroundTransparency = 1
	pin.AnchorPoint = Vector2.new(0.5, 0)
	pin.Position = UDim2.new(0.5, 0, 0, -pixels * 0.06)
	pin.Size = UDim2.fromScale(0.2, 0.2)
	pin.Ambient = Color3.fromRGB(255, 255, 255)
	pin.LightColor = Color3.fromRGB(0, 0, 0)
	pin.ZIndex = 4
	pin:SetAttribute("NoStyle", true)
	pin.Parent = frame
	local pinModel = Instance.new("Model")
	pinModel.Parent = pin
	triangle(pinModel, Vector3.new(-1.25, 1.1, -0.1), Vector3.new(1.25, 1.1, -0.1), Vector3.new(0, -1.6, -0.1), GOLD, 0.3)
	triangle(pinModel, Vector3.new(-0.95, 0.92, 0.2), Vector3.new(0.95, 0.92, 0.2), Vector3.new(0, -1.2, 0.2), Color3.fromRGB(230, 40, 40), 0.3)
	part(pinModel, "Stud", Vector3.new(0.3, 0.8, 0.8), CFrame.new(0, 0.6, 0.45) * face, GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local pinCamera = Instance.new("Camera")
	pinCamera.FieldOfView = 30
	pinCamera.CFrame = CFrame.new(0, -0.1, 11)
	pinCamera.Parent = pin
	pin.CurrentCamera = pinCamera
	self.pin = pin

	self:setRotation(0)

	-- 전구 반짝임 (창이 보일 때만)
	local phase, clock = 0, 0
	self.connection = RunService.Heartbeat:Connect(function(dt)
		if not frame.Parent then
			self.connection:Disconnect()
			return
		end
		if not MoneyIcon.shown(frame) then
			return
		end
		clock += dt
		if clock < (self.fast and 0.09 or 0.4) then
			return
		end
		clock = 0
		phase = 1 - phase
		for i, bulb in ipairs(self.bulbs) do
			local on = (i % 2 == phase)
			bulb.Color = on and Color3.fromRGB(255, 244, 170) or Color3.fromRGB(255, 120, 60)
		end
	end)
	return self
end

function RouletteWheel:setRotation(degrees)
	self.rotation = degrees
	-- 카메라를 반대로 굴리면 판이 시계 방향으로 돈 것처럼 보인다
	self.camera.CFrame = CFrame.new(0, 0, self.distance) * CFrame.Angles(0, 0, math.rad(degrees))
	for index, label in ipairs(self.labels) do
		local angle = (index - 1) * self.step + degrees
		local a = math.rad(angle)
		-- 금액 글자는 바깥쪽(판 둘레 가까이)에 반지름 방향으로, 그림은 안쪽 밝은 띠 위에
		label.Position = UDim2.fromScale(0.5 + math.sin(a) * 0.325, 0.5 - math.cos(a) * 0.325)
		-- 아래쪽 반에 있는 글자는 뒤집어서 늘 바로 읽히게 ("900" 이 "006" 으로 보이지 않게)
		local turned = angle % 360
		label.Rotation = (turned > 90 and turned < 270) and angle + 180 or angle
		local icon = self.icons[index]
		if icon then
			icon.Position = UDim2.fromScale(0.5 + math.sin(a) * 0.19, 0.5 - math.cos(a) * 0.19)
		end
	end
end

function RouletteWheel:setFast(fast)
	self.fast = fast == true
end

function RouletteWheel:celebrate()
	local scale = self.pin:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = self.pin
	scale.Scale = 1.4
	TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
end

return RouletteWheel
