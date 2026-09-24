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
function UIKit.iconButton(parent, props)
	local size = props.size or 74
	local b = Instance.new("ImageButton")
	b.Name = props.name or "IconButton"
	b.Size = UDim2.fromOffset(size, size)
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.LayoutOrder = props.order or 0
	b.Image = (props.image and props.image > 0) and ("rbxassetid://" .. props.image) or ""
	b.ScaleType = Enum.ScaleType.Fit
	b.Parent = parent
	UIKit.paint(b, props.theme or "blue")
	UIKit.corner(b, 16)
	UIKit.outline(b, 3.5)
	UIKit.gloss(b, 12)
	if b.Image == "" then
		local icon = UIKit.label(b, {
			name = "Icon",
			text = props.icon or "?",
			size = UDim2.new(1, 0, 0.78, 0),
			position = UDim2.fromScale(0, 0.02),
			textSize = math.floor(size * 0.56),
			stroke = 2,
			zIndex = b.ZIndex + 1,
		})
		icon.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
	end
	UIKit.label(b, {
		name = "Caption",
		text = props.caption or "",
		size = UDim2.new(1, 8, 0, 24),
		position = UDim2.new(0.5, 0, 1, 4),
		anchor = Vector2.new(0.5, 1),
		textSize = 19,
		stroke = 3,
		zIndex = b.ZIndex + 2,
	})
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
	dot.ZIndex = b.ZIndex + 3
	dot.Parent = b
	UIKit.corner(dot, 14)
	UIKit.outline(dot, 2.5, C.White)
	UIKit.bounce(b)
	return b, dot
end

--------------------------------------------------
-- 왼쪽 버튼 줄 (여러 스크립트가 함께 쓴다)
--------------------------------------------------

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
		rail.Size = UDim2.fromOffset(2 * 74 + 14, 3 * 74 + 2 * 22)
		rail.Parent = gui
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(74, 74)
		grid.CellPadding = UDim2.fromOffset(14, 22)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.FillDirectionMaxCells = 2
		grid.Parent = rail

		-- Phase 15 : 오른쪽 버튼 줄 (출석 · 룰렛). 인기 게임처럼 매일 받는 보상은 오른쪽에 세로로 둔다.
		local right = Instance.new("Frame")
		right.Name = "RightRail"
		right.BackgroundTransparency = 1
		right.AnchorPoint = Vector2.new(1, 0.5)
		right.Position = UDim2.new(1, -14, 0.42, 0)
		right.Size = UDim2.fromOffset(84, 2 * 74 + 26)
		right.Parent = gui
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		list.Padding = UDim.new(0, 26)
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
	end)
	frame.AncestryChanged:Connect(function()
		if not frame:IsDescendantOf(game) then
			local index = table.find(windows, entry)
			if index then
				table.remove(windows, index)
			end
		end
	end)
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
	frame.Position = props.position or UDim2.fromScale(0.5, 0.52)
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

	if props.icon then
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
	function w.fit()
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
		return math.min(1, (view.X - 24) / size.X, (view.Y - 60) / (size.Y + 40))
	end
	function w.open()
		local target = w.fit()
		scale.Scale = target * 0.75
		frame.Visible = true
		TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	end
	function w.hide()
		frame.Visible = false
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

UIKit.TouchEnabled = UserInputService.TouchEnabled

return UIKit
