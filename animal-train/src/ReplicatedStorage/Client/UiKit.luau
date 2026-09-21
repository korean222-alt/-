-- 화면 만들기 도우미. 글자는 숫자만 쓰고, 나머지는 도형과 3D 모델로 표현합니다.
local TweenService = game:GetService("TweenService")

local UiKit = {}

function UiKit.corner(parent: Instance, scale: number?, offset: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(scale or 1, offset or 0)
	corner.Parent = parent
	return corner
end

function UiKit.stroke(parent: Instance, color: Color3, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UiKit.frame(parent: Instance, name: string)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function UiKit.panel(parent: Instance, name: string, color: Color3?)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UiKit.corner(frame, 0.32)
	UiKit.stroke(frame, Color3.fromRGB(255, 255, 255), 3)
	return frame
end

function UiKit.number(parent: Instance, text: string)
	local label = Instance.new("TextLabel")
	label.Name = "Number"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(96, 76, 40)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = parent
	return label
end

-- 동그라미 (기차 칸, 업그레이드 단계 표시용)
function UiKit.dot(parent: Instance, filled: boolean)
	local dot = Instance.new("Frame")
	dot.Name = filled and "DotOn" or "DotOff"
	dot.BackgroundColor3 = filled and Color3.fromRGB(255, 225, 110) or Color3.fromRGB(255, 255, 255)
	dot.BackgroundTransparency = filled and 0 or 0.55
	dot.BorderSizePixel = 0
	dot.Parent = parent
	UiKit.corner(dot, 1)
	UiKit.stroke(dot, Color3.fromRGB(255, 255, 255), 2)
	return dot
end

-- 병아리 얼굴 동그라미 (6단계 : 기차 칸 표시)
function UiKit.chickDot(parent: Instance)
	local dot = UiKit.dot(parent, true)
	local eyeLeft = UiKit.frame(dot, "EyeL")
	eyeLeft.BackgroundTransparency = 0
	eyeLeft.BackgroundColor3 = Color3.fromRGB(60, 54, 66)
	eyeLeft.Size = UDim2.fromScale(0.16, 0.16)
	eyeLeft.Position = UDim2.fromScale(0.3, 0.36)
	UiKit.corner(eyeLeft, 1)

	local eyeRight = eyeLeft:Clone()
	eyeRight.Name = "EyeR"
	eyeRight.Position = UDim2.fromScale(0.56, 0.36)
	eyeRight.Parent = dot

	local beak = UiKit.frame(dot, "Beak")
	beak.BackgroundTransparency = 0
	beak.BackgroundColor3 = Color3.fromRGB(255, 163, 71)
	beak.Size = UDim2.fromScale(0.2, 0.14)
	beak.Position = UDim2.fromScale(0.4, 0.6)
	UiKit.corner(beak, 0.4)
	return dot
end

function UiKit.tween(instance: Instance, properties: {}, duration: number, style: Enum.EasingStyle?)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, properties)
	tween:Play()
	return tween
end

-- 통통 튀는 느낌
function UiKit.pop(guiObject: GuiObject, strength: number?)
	local amount = strength or 0.25
	local base = guiObject:GetAttribute("BaseSize")
	if typeof(base) ~= "UDim2" then
		base = guiObject.Size
		guiObject:SetAttribute("BaseSize", base)
	end
	guiObject.Size = UDim2.new(
		base.X.Scale * (1 + amount),
		base.X.Offset,
		base.Y.Scale * (1 + amount),
		base.Y.Offset
	)
	UiKit.tween(guiObject, { Size = base }, 0.28, Enum.EasingStyle.Back)
end

-- 3D 모델을 화면에 그려 주는 창 (도감, 별 아이콘 등)
function UiKit.viewport(parent: Instance, model: Model?, name: string?)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = name or "Viewport"
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(220, 220, 230)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.5)
	viewport.Parent = parent

	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	if model then
		UiKit.setViewportModel(viewport, model)
	end
	return viewport
end

function UiKit.setViewportModel(viewport: ViewportFrame, model: Model, angle: number?)
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("Model") and child ~= model then
			child:Destroy()
		end
	end
	model.Parent = viewport

	local cframe, size = model:GetBoundingBox()
	viewport:SetAttribute("OrbitCenter", cframe.Position)
	viewport:SetAttribute("OrbitDistance", math.max(size.Magnitude * 1.15, 3))
	UiKit.aimViewport(viewport, angle)
end

-- 카메라 각도만 바꿉니다 (모델을 다시 만들지 않음 → 매 프레임 써도 안전)
function UiKit.aimViewport(viewport: ViewportFrame, angle: number?)
	local camera = viewport.CurrentCamera
	if not camera then
		return
	end
	local center = viewport:GetAttribute("OrbitCenter")
	local distance = viewport:GetAttribute("OrbitDistance")
	if typeof(center) ~= "Vector3" or type(distance) ~= "number" then
		return
	end
	local yaw = angle or math.rad(28)
	local direction = Vector3.new(math.sin(yaw), 0.35, math.cos(yaw)).Unit
	camera.CFrame = CFrame.lookAt(center + direction * distance, center)
end

-- 도감에서 아직 못 만난 동물은 검은 실루엣으로 (9단계)
function UiKit.silhouette(model: Model)
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.Color = Color3.fromRGB(38, 38, 48)
			piece.Material = Enum.Material.SmoothPlastic
			piece.Reflectance = 0
		elseif piece:IsA("ParticleEmitter") then
			piece:Destroy()
		end
	end
	return model
end

function UiKit.aspect(parent: Instance, ratio: number)
	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.AspectRatio = ratio
	constraint.Parent = parent
	return constraint
end

-- 버튼처럼 누를 수 있는 투명 버튼 (그림 위에 겹칩니다)
function UiKit.hitButton(parent: Instance)
	local button = Instance.new("TextButton")
	button.Name = "Hit"
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 20
	button.Parent = parent
	return button
end

return UiKit
