--[[
	UIKit  (Phase 14)
	화면 UI 를 인기 시뮬레이터 게임처럼 그리는 공용 부품. (클라이언트 전용)

	모양 규칙 (사용자가 보내 준 사진 기준)
	  · 모든 판 · 버튼에 두꺼운 검은 테두리, 둥근 모서리, 위가 밝고 아래가 어두운 그러데이션
	  · 글자는 둥글고 굵은 글꼴(Fredoka One) + 두꺼운 검은 외곽선
	  · 창 머리띠는 밝은 색 띠 + 무늬(ReleaseConfig.UIImages.Pattern) + 가운데 큰 제목, 오른쪽 위 빨간 X
	  · 왼쪽에는 큰 네모 아이콘 버튼 (아이콘 아래에 이름이 겹쳐 붙는다)
	  · 누르면 살짝 눌렸다가 튀어 오른다

	UIKit.restyle(root) 는 예전 코드로 만든 화면에도 글꼴 · 외곽선 · 테두리를 입힌다.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = {}

local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"

UIKit.Colors = {
	Outline = Color3.fromRGB(20, 16, 24),
	White = Color3.new(1, 1, 1),
	Cream = Color3.fromRGB(255, 246, 226),
	Dim = Color3.fromRGB(190, 194, 210),
	Gold = Color3.fromRGB(255, 208, 64),
	GoldDark = Color3.fromRGB(232, 140, 20),
	Green = Color3.fromRGB(110, 222, 64),
	GreenDark = Color3.fromRGB(34, 150, 38),
	Red = Color3.fromRGB(240, 64, 56),
	RedDark = Color3.fromRGB(168, 22, 26),
	Purple = Color3.fromRGB(196, 96, 255),
	PurpleDark = Color3.fromRGB(116, 34, 196),
	Blue = Color3.fromRGB(70, 176, 255),
	BlueDark = Color3.fromRGB(28, 96, 214),
	Orange = Color3.fromRGB(255, 160, 50),
	OrangeDark = Color3.fromRGB(210, 84, 16),
	Teal = Color3.fromRGB(60, 220, 200),
	TealDark = Color3.fromRGB(18, 140, 150),
	Grey = Color3.fromRGB(150, 156, 170),
	GreyDark = Color3.fromRGB(86, 90, 104),
	Robux = Color3.fromRGB(64, 214, 110),
	RobuxDark = Color3.fromRGB(18, 142, 66),
	Body = Color3.fromRGB(46, 52, 70),
	BodyDark = Color3.fromRGB(26, 30, 42),
}
local C = UIKit.Colors

-- 이름 → { 밝은 색, 어두운 색 }
UIKit.Themes = {
	green = { C.Green, C.GreenDark },
	gold = { C.Gold, C.GoldDark },
	red = { C.Red, C.RedDark },
	purple = { C.Purple, C.PurpleDark },
	blue = { C.Blue, C.BlueDark },
	orange = { C.Orange, C.OrangeDark },
	teal = { C.Teal, C.TealDark },
	grey = { C.Grey, C.GreyDark },
	robux = { C.Robux, C.RobuxDark },
}

local function theme(name)
	if typeof(name) == "table" then
		return name
	end
	return UIKit.Themes[name or "blue"] or UIKit.Themes.blue
end
UIKit.theme = theme

-- Phase 15 : 한글이 뭉개지지 않게 굵기는 Bold 까지만 쓴다.
--   (Fredoka 에는 한글이 없어서 한글은 기본 한글 글꼴로 그려진다. Heavy 로 부풀리고 두꺼운 외곽선까지 두르면
--    획이 서로 붙어 "뭐라는지 안 보이는" 글자가 됐다)
function UIKit.font(_heavy)
	return Font.new(FREDOKA, Enum.FontWeight.Bold)
end

-- 글자 크기에 맞는 외곽선 두께. 작은 글자일수록 얇게 (한글 획 사이가 메워지지 않게)
function UIKit.strokeFor(textSize, wanted)
	local size = tonumber(textSize) or 20
	local thickness = tonumber(wanted) or size / 12
	return math.clamp(math.min(thickness, size / 9), 1, 3)
end

local patternId = 0
pcall(function()
	local release = require(script.Parent.ReleaseConfig)
	patternId = tonumber(release.UIImages and release.UIImages.Pattern) or 0
end)

--------------------------------------------------
-- 기본 장식
--------------------------------------------------

function UIKit.corner(parent, radius)
	local c = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 12)
	c.Parent = parent
	return c
end

-- 판 · 버튼 테두리
function UIKit.outline(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Name = "Outline"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Thickness = thickness or 3
	s.Color = color or C.Outline
	s.Parent = parent
	return s
end

-- 글자 외곽선. 글자가 흐려지면(TextTransparency) 외곽선도 같이 흐려진다.
function UIKit.textStroke(label, thickness, color)
	local s = label:FindFirstChild("TextOutline") or Instance.new("UIStroke")
	s.Name = "TextOutline"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Thickness = thickness or 2.5
	s.Color = color or C.Outline
	if not s.Parent then
		s.Parent = label
		s.Transparency = label.TextTransparency
		label:GetPropertyChangedSignal("TextTransparency"):Connect(function()
			s.Transparency = label.TextTransparency
		end)
	end
	return s
end

function UIKit.gradient(parent, top, bottom, rotation)
	local g = parent:FindFirstChild("Shade") or Instance.new("UIGradient")
	g.Name = "Shade"
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

-- 밝은 색 → 어두운 색 판 (버튼 · 머리띠 · 카드)
function UIKit.paint(frame, themeName)
	local t = theme(themeName)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	UIKit.gradient(frame, t[1], t[2], 90)
end

-- 윗부분의 반짝이는 광택
function UIKit.gloss(parent, radius)
	local g = Instance.new("Frame")
	g.Name = "Gloss"
	g.BackgroundColor3 = Color3.new(1, 1, 1)
	g.BackgroundTransparency = 0.78
	g.BorderSizePixel = 0
	g.Position = UDim2.new(0, 4, 0, 3)
	g.Size = UDim2.new(1, -8, 0.42, 0)
	g.Active = false
	g.ZIndex = parent.ZIndex
	g.Parent = parent
	UIKit.corner(g, radius or 8)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(0.2, 1)
	fade.Parent = g
	return g
end

-- 무늬 타일 (그림 ID 가 있을 때만)
function UIKit.pattern(parent, transparency)
	if patternId <= 0 then
		return nil
	end
	local p = Instance.new("ImageLabel")
	p.Name = "Pattern"
	p.BackgroundTransparency = 1
	p.Size = UDim2.fromScale(1, 1)
	p.Image = "rbxassetid://" .. patternId
	p.ImageTransparency = transparency or 0.82
	p.ScaleType = Enum.ScaleType.Tile
	p.TileSize = UDim2.fromOffset(46, 46)
	p.ZIndex = parent.ZIndex
	p.Parent = parent
	UIKit.corner(p, 10)
	return p
end

--------------------------------------------------
-- 글자
--------------------------------------------------

function UIKit.label(parent, props)
	props = props or {}
	local l = Instance.new("TextLabel")
	l.Name = props.name or "Label"
	l.BackgroundTransparency = 1
	l.Size = props.size or UDim2.fromScale(1, 1)
	l.Position = props.position or UDim2.new()
	l.AnchorPoint = props.anchor or Vector2.new()
	l.FontFace = UIKit.font(props.heavy ~= false)
	l.TextSize = props.textSize or 20
	l.TextColor3 = props.color or C.White
	l.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	l.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	l.TextWrapped = props.wrap == true
	l.TextScaled = props.scaled == true
	l.RichText = props.rich == true
	l.Text = props.text or ""
	l.ZIndex = props.zIndex or (parent:IsA("GuiObject") and parent.ZIndex or 1)
	l.Parent = parent
	if props.scaled then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = props.textSize or 20
		limit.Parent = l
	end
	UIKit.textStroke(l, UIKit.strokeFor(props.textSize or 20, props.stroke))
	return l
end

--------------------------------------------------
-- 버튼
--------------------------------------------------

-- Phase 24 : 버튼 소리. UIKit 로 만든 모든 버튼(상점 · 퀘스트 · 출석 · 룰렛 · 설정 · 창 닫기 …)이 누를 때 "딸깍" 한다.
--   아주 빨리 연달아 누르면 겹치지 않게 0.06초에 한 번만. 음량은 설정의 효과음을 따른다.
local lastClickAt = 0
function UIKit.click(kind)
	local now = os.clock()
	if now - lastClickAt < 0.06 then
		return
	end
	lastClickAt = now
	local ok, Sfx = pcall(require, script.Parent.Sfx)
	if ok then
		Sfx.play(kind or "Click", { volume = kind == "Open" and 0.35 or 0.45 })
	end
end

-- 누르면 살짝 작아졌다가 튀어 오른다
function UIKit.bounce(button)
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = button
	local function to(value, time)
		TweenService:Create(scale, TweenInfo.new(time or 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		if button.Active then
			to(1.05)
		end
	end)
	button.MouseLeave:Connect(function()
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.9, 0.06)
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	if button:IsA("GuiButton") then
		button.Activated:Connect(function()
			if button.Active then
				UIKit.click()
			end
		end)
	end
	return scale
end

--[[
	큰 만화풍 버튼. button.Text 를 바꾸면 겉에 보이는 글자(Label)도 같이 바뀐다.
	props : text · size · position · anchor · theme · textSize · textColor · icon · zIndex · name
]]
function UIKit.button(parent, props)
	props = props or {}
	local b = Instance.new("TextButton")
	b.Name = props.name or "Button"
	b.Size = props.size or UDim2.fromOffset(140, 48)
	b.Position = props.position or UDim2.new()
	b.AnchorPoint = props.anchor or Vector2.new()
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Text = props.text or ""
	b.TextTransparency = 1 -- 보이는 글자는 아래 Label 이 그린다 (두꺼운 외곽선을 위해)
	b.FontFace = UIKit.font(true)
	b.TextSize = props.textSize or 20
	b.ZIndex = props.zIndex or (parent:IsA("GuiObject") and parent.ZIndex or 1)
	b.Selectable = true
	b.Parent = parent
	UIKit.paint(b, props.theme or "blue")
	UIKit.corner(b, props.radius or 10)
	UIKit.outline(b, props.outline or 3)
	UIKit.gloss(b, (props.radius or 10) - 2)
	local text = UIKit.label(b, {
		name = "Label",
		text = (props.icon and (props.icon .. " ") or "") .. (props.text or ""),
		size = UDim2.new(1, -8, 1, 0),
		position = UDim2.fromOffset(4, 0),
		textSize = props.textSize or 20,
		color = props.textColor or C.White,
		scaled = true,
		zIndex = b.ZIndex + 1,
	})
	local icon = props.icon
	b:GetPropertyChangedSignal("Text"):Connect(function()
		text.Text = (icon and (icon .. " ") or "") .. b.Text
	end)
	b:GetPropertyChangedSignal("TextColor3"):Connect(function()
		text.TextColor3 = b.TextColor3
	end)
	b.TextColor3 = props.textColor or C.White
	UIKit.bounce(b)
	return b
end

-- 버튼 색 바꾸기 (살 수 있음 → 초록, 못 삼 → 회색 같은 경우)
function UIKit.setTheme(button, themeName)
	local t = theme(themeName)
	UIKit.gradient(button, t[1], t[2], 90)
end

--[[
	왼쪽 큰 네모 아이콘 버튼 (사진의 "상점" · "보상" 버튼)
	props : icon(이모지) · image(그림 ID) · caption · theme · order
	돌려주는 값 : 버튼, 빨간 점(badge)
]]
--[[
	Phase 21 : 버튼 · 창 머리띠 그림
	  · ReleaseConfig.Images.Buttons[kind] 에 그림 ID 가 있으면 그 그림 (roblox-cursed-barrel/ui/buttons/*.png 를 올린 것)
	  · 없으면 가운데 빛 + 큰 그림 문자(이모지). 예전 3D 파트 아이콘은 작은 화면에서 뭉개져 보여서 뺐다
]]
UIKit.IconGlyphs = {
	Shop = "🛒", Quest = "📜", Sabotage = "💣", Attendance = "📅", Roulette = "🎡", Code = "🎟️", Voyage = "🧭", Settings = "⚙️",
}
function UIKit.iconArt(parent, kind, props)
	props = props or {}
	local images = require(script.Parent.ReleaseConfig).Images.Buttons or {}
	local imageId = tonumber(props.image) or 0
	if imageId <= 0 then
		imageId = tonumber(images[kind]) or 0
	end
	local z = props.zIndex or (parent.ZIndex + 2)
	local holder = Instance.new("Frame")
	holder.Name = "IconArt"
	holder.BackgroundTransparency = 1
	holder.Size = props.size or UDim2.new(1, 0, 1, -10)
	holder.Position = props.position or UDim2.fromOffset(0, -3)
	holder.ZIndex = z
	holder.Parent = parent
	-- 뒤에서 은은하게 빛나는 동그라미
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.52)
	glow.Size = UDim2.fromScale(0.78, 0.78)
	glow.BackgroundColor3 = Color3.fromRGB(255, 252, 230)
	glow.BackgroundTransparency = 0.55
	glow.BorderSizePixel = 0
	glow.ZIndex = z
	glow.Parent = holder
	UIKit.corner(glow, UDim.new(1, 0))
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1),
	})
	fade.Rotation = 90
	fade.Parent = glow
	if imageId > 0 then
		local image = Instance.new("ImageLabel")
		image.Name = "Art"
		image.BackgroundTransparency = 1
		image.Image = "rbxassetid://" .. imageId
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromScale(1, 1)
		image.ZIndex = z + 1
		image.Parent = holder
		return holder
	end
	local glyph = UIKit.IconGlyphs[kind] or "⭐"
	-- 그림자 한 겹 + 그림 문자 (이모지는 외곽선을 두르면 지저분해져서 그림자만 둔다)
	for i, offset in ipairs({ Vector2.new(2, 3), Vector2.new(0, 0) }) do
		local t = Instance.new("TextLabel")
		t.Name = i == 1 and "Shadow" or "Glyph"
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		t.Size = UDim2.fromScale(0.86, 0.86)
		t.Text = glyph
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = i == 1 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
		t.TextTransparency = i == 1 and 0.65 or 0
		t.ZIndex = z + i
		t.Parent = holder
	end
	return holder
end

function UIKit.iconButton(parent, props)
	local size = props.size or 96
	local b = Instance.new("ImageButton")
	b.Name = props.name or "IconButton"
	b.Size = UDim2.fromOffset(size, size)
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.LayoutOrder = props.order or 0
	local buttonImages = require(script.Parent.ReleaseConfig).Images.Buttons or {}
	local imageId = tonumber(props.image) or 0
	if imageId <= 0 then imageId = tonumber(buttonImages[props.icon3D]) or 0 end
	b.Image = ""
	b.Parent = parent
	local tiles = {
		Shop = { Color3.fromRGB(255, 228, 115), Color3.fromRGB(226, 160, 45) },
		Quest = { Color3.fromRGB(139, 219, 255), Color3.fromRGB(56, 146, 226) },
		Sabotage = { Color3.fromRGB(239, 166, 250), Color3.fromRGB(168, 82, 208) },
		Attendance = { Color3.fromRGB(255, 195, 139), Color3.fromRGB(231, 110, 69) },
		Roulette = { Color3.fromRGB(157, 245, 160), Color3.fromRGB(57, 180, 102) },
		Code = { Color3.fromRGB(149, 237, 231), Color3.fromRGB(55, 165, 176) },
		Voyage = { Color3.fromRGB(181, 198, 255), Color3.fromRGB(93, 114, 206) },
		Settings = { Color3.fromRGB(214, 220, 232), Color3.fromRGB(120, 128, 150) },
	}
	local colors = tiles[props.icon3D] or theme(props.theme or "blue")
	b.BackgroundColor3 = colors[1]
	UIKit.gradient(b, colors[1], colors[2], 90)
	UIKit.corner(b, 13)
	UIKit.outline(b, 4, Color3.fromRGB(19, 21, 27))
	local inset = Instance.new("Frame")
	inset.Name = "LightRim"
	inset.BackgroundTransparency = 1
	inset.Position = UDim2.fromOffset(4, 4)
	inset.Size = UDim2.new(1, -8, 1, -8)
	inset.ZIndex = b.ZIndex + 1
	inset.Parent = b
	UIKit.corner(inset, 9)
	UIKit.outline(inset, 2.5, Color3.fromRGB(255, 247, 211))
	-- Phase 21 : 레고 같던 점무늬(TileStud)를 걷어내고, 가운데가 은은하게 빛나는 판 + 그림으로 바꿨다
	UIKit.gloss(b, 10)
	if props.icon3D then
		UIKit.iconArt(b, props.icon3D, { image = imageId, zIndex = b.ZIndex + 2 })
	elseif imageId > 0 then
		local art = Instance.new("ImageLabel")
		art.Name = "BlenderIcon"
		art.BackgroundTransparency = 1
		art.Image = "rbxassetid://" .. imageId
		art.ScaleType = Enum.ScaleType.Fit
		art.Position = UDim2.fromOffset(0, -4)
		art.Size = UDim2.new(1, 0, 1, -9)
		art.ZIndex = b.ZIndex + 2
		art.Parent = b
	else
		local icon = UIKit.label(b, {
			name = "Icon",
			text = props.icon or "?",
			size = UDim2.new(1, 0, 0.78, 0),
			position = UDim2.fromScale(0, 0.02),
			textSize = math.floor(size * 0.56),
			stroke = 2,
			zIndex = b.ZIndex + 2,
		})
		icon.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
	end
	local caption = UIKit.label(b, {
		name = "Caption",
		text = props.caption or "",
		size = UDim2.new(1, -4, 0, 24),
		position = UDim2.new(0.5, 0, 1, 0),
		anchor = Vector2.new(0.5, 1),
		textSize = 18,
		scaled = true,
		stroke = 3,
		zIndex = b.ZIndex + 4,
	})
	caption.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
	-- 받을 것이 있으면 뜨는 빨간 동그라미 (숫자를 적으면 개수가 보인다)
	local dot = Instance.new("TextLabel")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -6, 0, 6)
	dot.Size = UDim2.fromOffset(28, 28)
	dot.BackgroundColor3 = C.Red
	dot.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
	dot.TextSize = 17
	dot.TextColor3 = C.White
	dot.Text = "!"
	dot.Visible = false
	dot.ZIndex = b.ZIndex + 5
	dot.Parent = b
	UIKit.corner(dot, 14)
	UIKit.outline(dot, 2.5, C.White)
	UIKit.bounce(b)
	return b, dot
end

--------------------------------------------------
-- 왼쪽 버튼 줄 (여러 스크립트가 함께 쓴다)
--------------------------------------------------

--------------------------------------------------
-- Phase 16 : 휴대폰 화면 맞춤 (플레이어의 80% 가 휴대폰)
--   화면의 짧은 쪽이 720 이면 1배, 휴대폰(약 360~430)이면 0.62~0.73배.
--   버튼이 너무 작아지지 않게 0.62 아래로는 줄이지 않는다 (96 → 60 : 손가락으로 누르기 충분한 크기).
--------------------------------------------------
function UIKit.screenScale()
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local short = math.min(view.X, view.Y)
	return math.clamp(0.35 + 0.65 * short / 720, 0.62, 1)
end

-- Phase 21 : 휴대폰(화면의 짧은 쪽이 540 미만)에서는 로비 버튼 줄 · 코인을 30% 더 줄인다 (화면을 너무 가렸다)
function UIKit.phoneFactor()
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return math.min(view.X, view.Y) < 540 and 0.7 or 1
end
-- 버튼 줄 · 코인이 실제로 줄어드는 배율
function UIKit.railScale()
	return UIKit.screenScale() * UIKit.phoneFactor()
end

local autoScaled = {}
local autoConnected = false
local function extraOf(entry)
	return type(entry.extra) == "function" and entry.extra() or entry.extra
end
local function refreshAutoScale()
	local base = UIKit.screenScale()
	for i = #autoScaled, 1, -1 do
		local entry = autoScaled[i]
		if entry.scale.Parent then
			entry.scale.Scale = base * extraOf(entry)
		else
			table.remove(autoScaled, i)
		end
	end
end
-- object 에 화면 크기를 따라가는 UIScale 을 붙인다. (object 자리 · AnchorPoint 를 기준으로 줄어든다)
-- extra : 곱할 수 (함수를 주면 화면이 바뀔 때마다 다시 부른다)
function UIKit.autoScale(object, extra)
	local scale = object:FindFirstChild("AutoScale") or Instance.new("UIScale")
	scale.Name = "AutoScale"
	scale.Parent = object
	local entry = { scale = scale, extra = extra or 1 }
	table.insert(autoScaled, entry)
	scale.Scale = UIKit.screenScale() * extraOf(entry)
	if not autoConnected and workspace.CurrentCamera then
		autoConnected = true
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshAutoScale)
	end
	return scale
end

local hud = nil
function UIKit.hud()
	if hud and hud.Parent then
		return hud
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("CursedBarrel_HUD")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "CursedBarrel_HUD"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 9
		gui.IgnoreGuiInset = false
		gui.Parent = playerGui

		local rail = Instance.new("Frame")
		rail.Name = "Rail"
		rail.BackgroundTransparency = 1
		rail.AnchorPoint = Vector2.new(0, 0.5)
		rail.Position = UDim2.new(0, 14, 0.42, 0)
		rail.Size = UDim2.fromOffset(2 * 96 + 12, 3 * 96 + 2 * 18)
		rail.Parent = gui
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(96, 96)
		grid.CellPadding = UDim2.fromOffset(12, 18)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.FillDirectionMaxCells = 2
		grid.Parent = rail
		UIKit.autoScale(rail, UIKit.phoneFactor)

		-- Phase 15 : 오른쪽 버튼 줄 (출석 · 룰렛). 인기 게임처럼 매일 받는 보상은 오른쪽에 세로로 둔다.
		local right = Instance.new("Frame")
		right.Name = "RightRail"
		right.BackgroundTransparency = 1
		right.AnchorPoint = Vector2.new(1, 0.5)
		right.Position = UDim2.new(1, -14, 0.38, 0) -- 360px 높이 휴대폰에서도 점프 버튼 위에 끝난다
		right.Size = UDim2.fromOffset(96, 3 * 96 + 2 * 18) -- 출석 · 룰렛 · 코드
		right.Parent = gui
		UIKit.autoScale(right, UIKit.phoneFactor)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		list.Padding = UDim.new(0, 18)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = right
	end
	hud = gui
	return gui
end

-- 버튼 하나를 더한다. order 가 작을수록 위 · 왼쪽. props.side = "right" 면 오른쪽 줄
function UIKit.railButton(props)
	local gui = UIKit.hud()
	local rail = gui:WaitForChild(props.side == "right" and "RightRail" or "Rail")
	return UIKit.iconButton(rail, props)
end

-- 버튼 위 빨간 동그라미. count 가 0 이면 숨긴다. true 면 "!" 만.
function UIKit.setDot(dot, count)
	if not dot then
		return
	end
	if count == true then
		dot.Text = "!"
		dot.Visible = true
		return
	end
	local n = math.floor(tonumber(count) or 0)
	dot.Visible = n > 0
	dot.Text = n > 9 and "9+" or tostring(n)
end

--------------------------------------------------
-- Phase 15 : 창은 한 번에 하나만
--   출석 · 룰렛 · 상점 · 항해 수첩 … 중 하나가 열리면 나머지는 닫힌다.
--   어떻게 열었든(버튼 · 단축키 · 자동) Visible 이 켜지는 순간 나머지를 닫는다.
--   exclusive = false 인 창(3D 미리보기처럼 다른 창 위에 잠깐 뜨는 것)은 다른 창을 닫지 않고,
--   다른 창이 새로 열릴 때만 같이 닫힌다.
--------------------------------------------------
local windows = {}
local hudIndicators = {}

function UIKit.refreshHudIndicators()
	local windowOpen = false
	for _, entry in ipairs(windows) do
		if entry.frame.Parent and entry.frame.Visible then
			windowOpen = true
			break
		end
	end
	for _, frame in ipairs(hudIndicators) do
		if frame.Parent then
			frame.Visible = not windowOpen and frame:GetAttribute("HideForGame") ~= true
		end
	end
end

function UIKit.registerHudIndicator(frame)
	table.insert(hudIndicators, frame)
	frame:GetAttributeChangedSignal("HideForGame"):Connect(UIKit.refreshHudIndicators)
	frame.AncestryChanged:Connect(function()
		if not frame:IsDescendantOf(game) then
			local index = table.find(hudIndicators, frame)
			if index then table.remove(hudIndicators, index) end
			UIKit.refreshHudIndicators()
		end
	end)
	UIKit.refreshHudIndicators()
end

function UIKit.closeOthers(keep)
	local keepEntry = nil
	for _, entry in ipairs(windows) do
		if entry.frame == keep then
			keepEntry = entry
		end
	end
	if keepEntry and not keepEntry.exclusive then
		return
	end
	for _, entry in ipairs(windows) do
		if entry.frame ~= keep and entry.frame.Parent and entry.frame.Visible then
			pcall(entry.hide)
		end
	end
end

function UIKit.closeAll()
	for _, entry in ipairs(windows) do
		if entry.frame.Parent and entry.frame.Visible then
			pcall(entry.hide)
		end
	end
end

function UIKit.register(frame, hide, exclusive)
	local entry = { frame = frame, hide = hide or function()
		frame.Visible = false
	end, exclusive = exclusive ~= false }
	table.insert(windows, entry)
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			UIKit.closeOthers(frame)
		end
		UIKit.refreshHudIndicators()
	end)
	frame.AncestryChanged:Connect(function()
		if not frame:IsDescendantOf(game) then
			local index = table.find(windows, entry)
			if index then
				table.remove(windows, index)
			end
			UIKit.refreshHudIndicators()
		end
	end)
	UIKit.refreshHudIndicators()
	return entry
end

--------------------------------------------------
-- 창
--------------------------------------------------

--[[
	창 하나. props : title · theme · size(Vector2) · icon(이모지, 왼쪽 위에 걸친다) · parent
	돌려주는 값 : { frame, header, title, close, body, scale, open(), close() }
]]
function UIKit.window(parent, props)
	local t = theme(props.theme or "green")
	local size = props.size or Vector2.new(620, 440)
	local frame = Instance.new("Frame")
	frame.Name = props.name or "Window"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = props.position or UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Visible = false
	frame.Active = true
	frame.Parent = parent
	UIKit.gradient(frame, t[2]:Lerp(C.BodyDark, 0.62), C.BodyDark, 90)
	UIKit.corner(frame, 16)
	UIKit.outline(frame, 4.5)
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 62)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.ZIndex = 2
	header.Parent = frame
	UIKit.gradient(header, t[1]:Lerp(Color3.new(1, 1, 1), 0.18), t[2], 90)
	UIKit.corner(header, 14)
	UIKit.outline(header, 4)
	UIKit.pattern(header, 0.8)
	UIKit.gloss(header, 12)

	local title = UIKit.label(header, {
		name = "Title",
		text = props.title or "",
		size = UDim2.new(1, -150, 1, 0),
		position = UDim2.fromOffset(75, 0),
		textSize = 32,
		stroke = 4,
		scaled = true,
		zIndex = 4,
	})

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -9, 0.5, 0)
	close.Size = UDim2.fromOffset(48, 46)
	close.BackgroundColor3 = Color3.new(1, 1, 1)
	close.AutoButtonColor = false
	close.Text = ""
	close.ZIndex = 5
	close.Parent = header
	UIKit.gradient(close, C.Red, C.RedDark, 90)
	UIKit.corner(close, 8)
	UIKit.outline(close, 3)
	UIKit.gloss(close, 6)
	UIKit.label(close, { name = "X", text = "X", textSize = 32, stroke = 3.5, zIndex = 6 })
	UIKit.bounce(close)

	if props.icon3D then
		UIKit.iconArt(frame, props.icon3D, { size = UDim2.fromOffset(92, 92), position = UDim2.fromOffset(-30, -40), zIndex = 8 })
	elseif props.icon then
		local badge = UIKit.label(frame, {
			name = "Badge",
			text = props.icon,
			size = UDim2.fromOffset(92, 92),
			position = UDim2.fromOffset(-30, -40),
			textSize = 70,
			stroke = 3,
			zIndex = 8,
		})
		badge.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
		badge.Rotation = -10
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(14, 74)
	body.Size = UDim2.new(1, -28, 1, -86)
	body.ZIndex = 1
	body.Parent = frame

	local w = { frame = frame, header = header, title = title, close = close, body = body, scale = scale }

	-- 작은 화면에서는 창 전체를 줄인다 (글자 크기는 그대로 비율이 유지된다)
	-- Phase 16 : 위쪽 Roblox 메뉴 줄을 뺀 실제 화면(ScreenGui.AbsoluteSize)에 맞춘다.
	--   props.flexHeight 인 창(상점처럼 안이 스크롤되는 창)은 휴대폰에서 너무 작아지지 않게
	--   minScale(기본 0.72) 까지만 줄이고, 대신 창의 높이를 화면에 맞춰 낮춘다. (글자가 읽힐 크기로 남는다)
	function w.fit()
		local area = parent:IsA("GuiBase2d") and parent.AbsoluteSize or Vector2.zero
		if area.X <= 0 then
			local camera = workspace.CurrentCamera
			area = camera and camera.ViewportSize or Vector2.new(1280, 720)
		end
		local fit = math.min(1, (area.X - 16) / size.X, (area.Y - 28) / size.Y)
		if props.flexHeight then
			local want = math.min(1, (area.X - 16) / size.X, math.max(fit, props.minScale or 0.72))
			if want > fit then
				frame.Size = UDim2.fromOffset(size.X, math.floor((area.Y - 28) / want))
				return want
			end
			frame.Size = UDim2.fromOffset(size.X, size.Y)
		end
		return fit
	end
	function w.open()
		local target = w.fit()
		scale.Scale = target * 0.75
		if not frame.Visible then
			UIKit.click("Open")
		end
		frame.Visible = true
		TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	end
	function w.hide()
		frame.Visible = false
	end
	-- Phase 24 : 창이 열린 채 화면 크기가 바뀌면(휴대폰 회전 · 창 크기 조절) 그 자리에서 다시 맞춘다.
	--   예전에는 열 때만 맞춰서, 따로 처리하지 않은 창은 회전하면 화면 밖으로 나갔다.
	local function refit()
		if frame.Visible and frame.Parent then
			scale.Scale = w.fit()
		end
	end
	if parent:IsA("GuiBase2d") then
		parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	end
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(refit)
		end)
	end
	close.Activated:Connect(function()
		w.hide()
		if props.onClose then
			props.onClose()
		end
	end)
	-- 한 번에 창 하나만 (props.exclusive = false 면 다른 창 위에 잠깐 뜨는 창)
	UIKit.register(frame, function()
		w.hide()
		if props.onClose then
			props.onClose()
		end
	end, props.exclusive)
	return w
end

-- 창 안의 카드 (목록 한 줄). props : height · theme(테두리 색) · order · parent
function UIKit.card(parent, props)
	local t = theme(props.theme or "grey")
	local card = Instance.new("Frame")
	card.Name = props.name or "Card"
	card.Size = UDim2.new(1, -10, 0, props.height or 78)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.LayoutOrder = props.order or 0
	card.Parent = parent
	UIKit.gradient(card, t[1]:Lerp(C.Body, 0.55), t[2]:Lerp(C.BodyDark, 0.6), 90)
	UIKit.corner(card, 12)
	UIKit.outline(card, 3)
	-- 왼쪽 등급 색 띠
	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.Size = UDim2.new(0, 8, 1, -12)
	stripe.Position = UDim2.fromOffset(6, 6)
	stripe.BackgroundColor3 = t[1]
	stripe.BorderSizePixel = 0
	stripe.Parent = card
	UIKit.corner(stripe, 4)
	return card
end

-- 반짝이는 "NEW!" 같은 기울어진 딱지
function UIKit.tag(parent, text, color)
	local l = UIKit.label(parent, {
		name = "Tag",
		text = text,
		size = UDim2.fromOffset(90, 30),
		position = UDim2.fromOffset(-12, -14),
		textSize = 22,
		color = color or C.Gold,
		stroke = 3,
		zIndex = (parent.ZIndex or 1) + 5,
	})
	l.Rotation = -12
	return l
end

--------------------------------------------------
-- 예전 화면 다시 칠하기
--------------------------------------------------

local SKIP_NAMES = {
	Flash = true, Ink = true, Catch = true, Tap = true, Ring = true, Target = true, Gloss = true, Pattern = true,
	Stripe = true, Fill = true,
}

local function styleText(obj)
	if obj:GetAttribute("UIKitStyled") then
		return
	end
	obj:SetAttribute("UIKitStyled", true)
	local heavy = obj.Font == Enum.Font.GothamBlack or obj.TextSize >= 22
	pcall(function()
		obj.FontFace = UIKit.font(heavy)
	end)
	if obj:IsA("TextButton") then
		-- 버튼 글자는 예전 방식의 얇은 외곽선 (UIStroke 는 테두리에 쓴다)
		obj.TextStrokeTransparency = 0.25
		obj.TextStrokeColor3 = C.Outline
	elseif not obj:FindFirstChildOfClass("UIStroke") then
		local size = obj.TextScaled and 20 or obj.TextSize
		UIKit.textStroke(obj, UIKit.strokeFor(size))
	end
end

local function styleBox(obj)
	if obj:GetAttribute("UIKitBox") or SKIP_NAMES[obj.Name] or obj:GetAttribute("NoStyle") or string.sub(obj.Name, 1, 4) == "Blot" then
		return
	end
	if obj.BackgroundTransparency >= 0.6 then
		return
	end
	local size = obj.Size
	if size.X.Scale >= 0.98 and size.Y.Scale >= 0.98 then
		return -- 화면 전체를 덮는 판은 건드리지 않는다
	end
	obj:SetAttribute("UIKitBox", true)
	if not obj:FindFirstChildOfClass("UIStroke") then
		local stroke = UIKit.outline(obj, obj:IsA("GuiButton") and 2.5 or 3)
		stroke.Transparency = obj.BackgroundTransparency
		obj:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
			stroke.Transparency = obj.BackgroundTransparency
		end)
	else
		local stroke = obj:FindFirstChildOfClass("UIStroke")
		if stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border and stroke.Thickness < 2.5 then
			stroke.Thickness = 3
			stroke.Color = C.Outline
		end
	end
	if not obj:FindFirstChildOfClass("UICorner") then
		UIKit.corner(obj, 10)
	end
	if not obj:FindFirstChildOfClass("UIGradient") then
		local shade = Instance.new("UIGradient")
		shade.Name = "Shade"
		shade.Rotation = 90
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 206))
		shade.Parent = obj
	end
	if obj:IsA("GuiButton") and not obj:GetAttribute("UIKitBounce") then
		obj:SetAttribute("UIKitBounce", true)
		pcall(UIKit.bounce, obj)
	end
end

local function styleOne(obj)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		styleText(obj)
	end
	if (obj:IsA("Frame") or obj:IsA("GuiButton")) and not obj:IsA("ViewportFrame") then
		styleBox(obj)
	end
end

-- root 아래 모든 글자 · 판에 새 모양을 입힌다. 나중에 생기는 것도 따라간다.
function UIKit.restyle(root)
	for _, obj in ipairs(root:GetDescendants()) do
		styleOne(obj)
	end
	root.DescendantAdded:Connect(function(obj)
		task.defer(function()
			if obj.Parent then
				styleOne(obj)
			end
		end)
	end)
end

--------------------------------------------------
-- Phase 21 : 지금 게임 중인가 (앉은 테이블 또는 관전 중인 테이블)
--   돌려주는 값 : 테이블 모델(없으면 nil), 판이 진행 중인가(카운트다운 · 시작 · 진행 · 결과)
--------------------------------------------------
local CollectionService = game:GetService("CollectionService")
function UIKit.matchTable()
	local config = require(script.Parent.GameConfig)
	local player = Players.LocalPlayer
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local node = humanoid and humanoid.SeatPart
	local model = nil
	while node and node ~= workspace do
		if CollectionService:HasTag(node, config.Tags.Table) then
			model = node
			break
		end
		node = node.Parent
	end
	local watching = player:GetAttribute("SpectateTableId")
	if not model and watching then
		for _, t in ipairs(CollectionService:GetTagged(config.Tags.Table)) do
			if t:GetAttribute("TableId") == watching then
				model = t
				break
			end
		end
	end
	if not model then
		return nil, false
	end
	local state = model:GetAttribute(config.TableAttributes.State)
	return model, config.InGameStates[state] == true or state == config.States.Countdown
end

--------------------------------------------------
-- Phase 21 : "획득!" 알림
--   무엇을 받으면 화면 가운데에 크게 뜬다. 뒤에서 빛살이 돌고 별이 반짝인다. 누르면 바로 닫힌다.
--   UIKit.rewardPopup({ text = "1,500 코인", money = "cash" })        돈 그림 (MoneyIcon 종류)
--   UIKit.rewardPopup({ text = "「황금 칼」", emoji = "🗡" })
--   UIKit.rewardPopup({ title = "잭팟!", text = "+10,000", money = "chest", big = true, color = ... })
--   여러 개가 한꺼번에 오면 차례로 보여 준다.
--------------------------------------------------
local popupQueue = {}
local popupBusy = false
local popupGui = nil

local function popupRoot()
	if popupGui and popupGui.Parent then
		return popupGui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CursedBarrel_Reward"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	popupGui = gui
	return gui
end

local function showPopup(opts)
	local gui = popupRoot()
	local reduced = Players.LocalPlayer:GetAttribute("Setting_reducedFX") == true
	local big = opts.big == true
	local accent = opts.color or C.Gold
	local root = Instance.new("TextButton") -- 누르면 닫힌다
	root.Name = "Popup"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, big and 0.4 or 0.44)
	root.Size = UDim2.fromOffset(420, 360)
	root.ZIndex = 1
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = root
	local fit = UIKit.screenScale() * (big and 1.05 or 0.9)

	-- 빛살 (천천히 돈다)
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.42)
	rays.Size = UDim2.fromOffset(340, 340) -- Phase 22 : 460 → 340 (빛살이 창보다 너무 크게 퍼졌다)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 1
	rays.Parent = root
	for i = 0, 11 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(0, i % 2 == 0 and 46 or 26, 0.5, 0)
		ray.BackgroundColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.35)
		ray.BorderSizePixel = 0
		ray.Rotation = i * 30
		ray.ZIndex = 1
		ray.Parent = rays
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new(1, 0.25)
		g.Parent = ray
	end
	-- 가운데 빛 동그라미
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.42)
	glow.Size = UDim2.fromOffset(200, 200)
	glow.BackgroundColor3 = Color3.fromRGB(255, 250, 220)
	glow.BackgroundTransparency = 0.25
	glow.ZIndex = 2
	glow.Parent = root
	UIKit.corner(glow, UDim.new(1, 0))
	local glowFade = Instance.new("UIGradient")
	glowFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
	})
	glowFade.Rotation = 90
	glowFade.Parent = glow

	-- 그림 : 돈 모양(3D · 그림) 또는 이모지
	if opts.money then
		local ok = pcall(function()
			require(script.Parent.MoneyIcon).view(root, opts.money, {
				size = UDim2.fromOffset(190, 170), position = UDim2.new(0.5, -95, 0.42, -95), zIndex = 3, spin = true,
			})
		end)
		if not ok then
			opts.emoji = opts.emoji or "💰"
		end
	end
	if opts.emoji then
		UIKit.label(root, { text = opts.emoji, size = UDim2.fromOffset(170, 150), position = UDim2.new(0.5, -85, 0.42, -85), textSize = 120, scaled = true, stroke = 1, zIndex = 3 })
	end
	local title = UIKit.label(root, {
		name = "Title", text = opts.title or "획득!", size = UDim2.new(1, 0, 0, big and 78 or 62), position = UDim2.fromScale(0, 0),
		textSize = big and 72 or 56, color = accent, stroke = 5, scaled = true, zIndex = 5,
	})
	local line = UIKit.label(root, {
		name = "What", text = opts.text or "", size = UDim2.new(1, 0, 0, big and 60 or 48), position = UDim2.new(0, 0, 1, -(big and 66 or 56)),
		textSize = big and 54 or 40, color = C.White, stroke = 4, scaled = true, zIndex = 5,
	})
	title.Rotation = -4

	-- 튀어나오기
	TweenService:Create(scale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
	local alive = true
	task.spawn(function()
		local t0 = os.clock()
		while alive and root.Parent do
			local t = os.clock() - t0
			rays.Rotation = t * 40
			title.Rotation = -4 + math.sin(t * 5) * 3
			glow.BackgroundTransparency = 0.25 + 0.15 * math.sin(t * 7)
			task.wait()
		end
	end)
	-- 반짝이는 별
	if not reduced then
		task.spawn(function()
			for i = 1, (big and 26 or 14) do
				if not (alive and root.Parent) then
					break
				end
				local star = UIKit.label(root, {
					text = "★", size = UDim2.fromOffset(34, 34), textSize = 28, -- "✦" 는 글꼴에 없어 네모로 보였다
					position = UDim2.new(math.random() * 0.9, 0, 0.05 + math.random() * 0.75, 0),
					color = i % 2 == 0 and Color3.new(1, 1, 1) or accent, stroke = 2, zIndex = 6,
				})
				local s = Instance.new("UIScale")
				s.Scale = 0
				s.Parent = star
				TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 0.6 + math.random() * 0.4 }):Play()
				task.delay(0.45, function()
					if star.Parent then
						TweenService:Create(star, TweenInfo.new(0.35), { TextTransparency = 1, Rotation = 90 }):Play()
					end
				end)
				game:GetService("Debris"):AddItem(star, 1)
				task.wait(0.09)
			end
		end)
	end
	pcall(function()
		require(script.Parent.Sfx).play(opts.sound or "Coins", { volume = big and 1 or 0.8 })
	end)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		task.delay(0.25, function()
			alive = false
			root:Destroy()
		end)
	end
	root.Activated:Connect(close)
	task.delay(opts.hold or (big and 3 or 2.2), close)
	while not closed do
		task.wait(0.1)
	end
	task.wait(0.26)
end

function UIKit.rewardPopup(opts)
	table.insert(popupQueue, opts or {})
	if popupBusy then
		return
	end
	popupBusy = true
	task.spawn(function()
		while #popupQueue > 0 do
			local nextOne = table.remove(popupQueue, 1)
			local ok, err = pcall(showPopup, nextOne)
			if not ok then
				warn("[CursedBarrel] rewardPopup", err)
			end
		end
		popupBusy = false
	end)
end

UIKit.TouchEnabled = UserInputService.TouchEnabled

return UIKit
