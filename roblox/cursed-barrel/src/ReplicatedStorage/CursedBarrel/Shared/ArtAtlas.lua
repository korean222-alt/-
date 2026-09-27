-- ArtAtlas  (Phase 32.1)
-- Blender 로 렌더한 운명 카드(타로) · 해적 종류 아이콘 묶음 그림.
--   art/render_art.py → art/pack_sheets.py → art/sheets/*.png
--   cards_1 · cards_2 · cards_3 : 900x1020, 한 칸 300x510 (가로 3 · 세로 2)
--   icons                      : 1024x512, 한 칸 256x256 (가로 4 · 세로 2)
-- 그림은 Roblox 에 올린 뒤 ReleaseConfig.Images.FateCards · PirateIcons 에 이미지 ID 를 적는다.
-- ID 가 0 인 동안에는 같은 모양(남색 카드 · 금테 · 로마 숫자 · 둥근 휘장)을 UI 로 그려 대신 보여 준다.
-- 이모지는 쓰지 않는다 (기기마다 모양이 다르고 두부 네모로 보이기도 한다).

local ReleaseConfig = require(script.Parent:WaitForChild("ReleaseConfig"))
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local ArtAtlas = {}

-- 시트 안 순서 (pack_sheets.py 와 같아야 한다)
ArtAtlas.CardOrder = {
	"gold", "sleepy", "storm", "twins", "ghosts", "hooks",
	"greed", "lucky", "blades", "brave", "drift", "hurry",
	"calm", "back",
}
ArtAtlas.IconOrder = { "normal", "twin", "side", "skull", "mash", "angry", "lifebuoy", "lock" }

local CARD_CELL = Vector2.new(300, 510)
local ICON_CELL = Vector2.new(256, 256)
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII" }

-- 카드 그림 속 이름판 자리 (카드 크기에 대한 비율)
ArtAtlas.Plaque = { y = 0.848, height = 0.1, width = 0.76 }

local cardIndex, iconIndex = {}, {}
for index, id in ipairs(ArtAtlas.CardOrder) do
	cardIndex[id] = index
end
for index, id in ipairs(ArtAtlas.IconOrder) do
	iconIndex[id] = index
end

local function assetId(value)
	value = tonumber(value) or 0
	return value > 0 and ("rbxassetid://" .. value) or nil
end

-- 운명 카드 그림 칸. 아직 올리지 않았으면 nil
function ArtAtlas.cardCell(id)
	local index = cardIndex[id or ""]
	local sheets = ReleaseConfig.Images and ReleaseConfig.Images.FateCards
	if not index or type(sheets) ~= "table" then
		return nil
	end
	local sheet = math.floor((index - 1) / 6) + 1
	local image = assetId(sheets[sheet])
	if not image then
		return nil
	end
	local cell = (index - 1) % 6
	return { image = image, offset = Vector2.new((cell % 3) * CARD_CELL.X, math.floor(cell / 3) * CARD_CELL.Y), size = CARD_CELL }
end

-- 아이콘 그림 칸. 아직 올리지 않았으면 nil
function ArtAtlas.iconCell(id)
	local index = iconIndex[id or ""]
	local image = assetId(ReleaseConfig.Images and ReleaseConfig.Images.PirateIcons)
	if not index or not image then
		return nil
	end
	local cell = index - 1
	return { image = image, offset = Vector2.new((cell % 4) * ICON_CELL.X, math.floor(cell / 4) * ICON_CELL.Y), size = ICON_CELL }
end

function ArtAtlas.numeral(id)
	return ROMAN[cardIndex[id or ""] or 0] or ""
end

local function paintCell(image, cell)
	image.Image = cell.image
	image.ImageRectOffset = cell.offset
	image.ImageRectSize = cell.size
end

-- Phase 33.1 : 그림 ID 가 있어도 그림이 실제로 불러와지기 전(심사 중 · 권한 없음 · 느린 휴대폰)에는 빈칸이었다.
--   이제 그림이 다 불러와질 때까지 대신 그린 모양을 보여 주고, 불러오지 못하면 개발자 콘솔(F9)에 까닭을 한 번 남긴다.
local ContentProvider = game:GetService("ContentProvider")
local checked = {}
local function report(image)
	if checked[image] then
		return
	end
	checked[image] = true
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ image }, function(content, status)
				if status ~= Enum.AssetFetchStatus.Success then
					warn(("[CursedBarrel] 그림을 불러오지 못했어요 : %s (%s). 에셋 관리자에서 심사가 끝났는지, "
						.. "게임이 그룹 소유라면 그림도 그 그룹으로 올렸는지 확인해 주세요"):format(tostring(content), tostring(status)))
				end
			end)
		end)
	end)
end

-- art 가 불러와지면 fallback 을 숨긴다 (그 전에는 fallback 이 보인다)
local function showWhenLoaded(art, fallback)
	if art:GetAttribute("LoadWatch") ~= true then
		art:SetAttribute("LoadWatch", true)
		art:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			local target = art:FindFirstChild("Fallback")
			if art.IsLoaded and art.Visible and target and target.Value then
				target.Value.Visible = false
			end
		end)
	end
	local link = art:FindFirstChild("Fallback") or Instance.new("ObjectValue")
	link.Name = "Fallback"
	link.Value = fallback
	link.Parent = art
	fallback.Visible = not art.IsLoaded
	report(art.Image)
end

--------------------------------------------------
-- 아이콘
--------------------------------------------------
-- 그림이 없을 때 쓰는 글자 (한 글자 · 이모지 아님)
local GLYPH = { normal = "해", twin = "쌍", side = "갈", skull = "유", mash = "욕", angry = "분", lifebuoy = "신", lock = "잠" }
local ICON_COLOR = {
	normal = Color3.fromRGB(101, 241, 211), twin = Color3.fromRGB(255, 150, 70), side = Color3.fromRGB(120, 180, 255),
	skull = Color3.fromRGB(210, 222, 255), mash = Color3.fromRGB(255, 206, 80), angry = Color3.fromRGB(255, 70, 60),
	lifebuoy = Color3.fromRGB(255, 96, 78), lock = Color3.fromRGB(255, 206, 80),
}

-- 아이콘 틀을 만든다. props : size(UDim2) · position · anchor · zIndex · name
function ArtAtlas.icon(parent, id, props)
	props = props or {}
	local holder = Instance.new("Frame")
	holder.Name = props.name or "ArtIcon"
	holder.BackgroundTransparency = 1
	holder.Size = props.size or UDim2.fromOffset(48, 48)
	holder.Position = props.position or UDim2.new()
	holder.AnchorPoint = props.anchor or Vector2.zero
	holder.ZIndex = props.zIndex or 1
	holder.Active = false
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = holder

	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.ScaleType = Enum.ScaleType.Fit
	art.ZIndex = holder.ZIndex + 2
	art.Parent = holder

	-- 대신 그리는 휘장 : 둥근 판 · 금테 · 한 글자
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.5)
	badge.Size = UDim2.fromScale(0.86, 0.86)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.ZIndex = holder.ZIndex
	badge.Parent = holder
	Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Parent = badge
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.fromRGB(226, 178, 88)
	ring.Thickness = 2.5
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = badge
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.BackgroundTransparency = 1
	glyph.FontFace = UIKit.font(true)
	glyph.TextScaled = true
	glyph.TextColor3 = Color3.new(1, 1, 1)
	glyph.ZIndex = holder.ZIndex
	glyph.Parent = badge
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.2, 0)
	pad.PaddingBottom = UDim.new(0.2, 0)
	pad.Parent = glyph
	UIKit.textStroke(glyph, 2)

	holder.Parent = parent
	ArtAtlas.setIcon(holder, id)
	return holder
end

function ArtAtlas.setIcon(holder, id)
	if not holder then
		return
	end
	local art = holder:FindFirstChild("Art")
	local badge = holder:FindFirstChild("Badge")
	local cell = ArtAtlas.iconCell(id)
	if art then
		art.Visible = cell ~= nil
		if cell then
			paintCell(art, cell)
		end
	end
	if badge then
		badge.Visible = cell == nil
		if cell and art then
			showWhenLoaded(art, badge)
		end
		local color = ICON_COLOR[id] or Color3.fromRGB(226, 178, 88)
		local fill = badge:FindFirstChildOfClass("UIGradient")
		if fill then
			fill.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.5))
		end
		local glyph = badge:FindFirstChild("Glyph")
		if glyph then
			glyph.Text = GLYPH[id] or ""
		end
	end
end

--------------------------------------------------
-- 타로 카드
--------------------------------------------------
local GOLD = Color3.fromRGB(226, 178, 88)
local NAVY_TOP = Color3.fromRGB(46, 46, 62)
local NAVY_BOTTOM = Color3.fromRGB(20, 20, 30)
local SERIF = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

local function frame(parent, name, props)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = props.color or Color3.new(1, 1, 1)
	f.BackgroundTransparency = props.transparency or 0
	f.AnchorPoint = props.anchor or Vector2.zero
	f.Position = props.position or UDim2.new()
	f.Size = props.size or UDim2.fromScale(1, 1)
	f.Rotation = props.rotation or 0
	f.ZIndex = props.zIndex or 1
	f.Active = false
	if props.radius then
		Instance.new("UICorner", f).CornerRadius = props.radius
	end
	if props.stroke then
		local s = Instance.new("UIStroke")
		s.Color = props.strokeColor or GOLD
		s.Thickness = props.stroke
		s.Transparency = props.strokeTransparency or 0
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
	end
	f.Parent = parent
	return f
end

local function vertical(parent, top, bottom)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
	return g
end

-- 둥근 윗머리 창 (원 + 사각형 두 조각. 금테는 같은 모양을 조금 크게 뒤에 깐다)
local function arch(parent, name, rect, zIndex, grow)
	local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
	local holder = frame(parent, name, { transparency = 1, position = UDim2.new(x, -grow, y, -grow), size = UDim2.new(w, grow * 2, h, grow * 2), zIndex = zIndex })
	local cap = frame(holder, "Cap", { size = UDim2.fromScale(1, 1), zIndex = zIndex, radius = UDim.new(1, 0) })
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.DominantAxis = Enum.DominantAxis.Width
	ratio.Parent = cap
	-- 사각형은 원의 가운데 높이부터 (카드 240x408 · 창 0.8x0.63 → 폭/높이 0.75 → 반지름 = 높이의 0.37)
	local body = frame(holder, "Body", { position = UDim2.fromScale(0, 0.37), size = UDim2.fromScale(1, 0.63), zIndex = zIndex })
	return holder, cap, body
end

-- 카드를 만든다. 돌려주는 표 : holder(Frame · 크기 고정) · face(뒤집을 때 폭이 줄어드는 Frame) · paint(card, faceUp) · setWidth(0~1)
function ArtAtlas.tarot(parent, props)
	props = props or {}
	local z = props.zIndex or 40
	local holder = Instance.new("Frame")
	holder.Name = props.name or "Tarot"
	holder.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	holder.Position = props.position or UDim2.fromScale(0.5, 0.5)
	holder.Size = props.size or UDim2.fromOffset(240, 408)
	holder.BackgroundTransparency = 1
	holder.Active = false
	holder.ZIndex = z

	local face = frame(holder, "Face", { transparency = 1, anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.5), zIndex = z })

	-- 올린 그림
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.ScaleType = Enum.ScaleType.Stretch
	art.ZIndex = z + 7 -- 대신 그린 카드(z+1 ~ z+6) 위 · 이름(z+8) 아래
	art.Parent = face

	-- 그림이 없을 때 : 남색 카드 · 금테 두 줄 · 로마 숫자 · 둥근 창 · 휘장 · 이름판
	local plain = frame(face, "Plain", { transparency = 1, zIndex = z + 1 })
	local body = frame(plain, "Body", { zIndex = z + 1, radius = UDim.new(0.06, 0), stroke = 4, strokeColor = GOLD })
	vertical(body, NAVY_TOP, NAVY_BOTTOM)
	frame(plain, "Inner", { transparency = 1, position = UDim2.new(0, 9, 0, 9), size = UDim2.new(1, -18, 1, -18), zIndex = z + 2, radius = UDim.new(0.04, 0), stroke = 1.5, strokeTransparency = 0.25 })
	local numeral = Instance.new("TextLabel")
	numeral.Name = "Numeral"
	numeral.BackgroundTransparency = 1
	numeral.Position = UDim2.fromScale(0.2, 0.025)
	numeral.Size = UDim2.fromScale(0.6, 0.075)
	numeral.FontFace = SERIF
	numeral.TextScaled = true
	numeral.TextColor3 = GOLD
	numeral.ZIndex = z + 3
	numeral.Parent = plain
	for side = 0, 1 do
		frame(plain, "Rule" .. side, { color = GOLD, anchor = Vector2.new(side, 0.5), position = UDim2.fromScale(side == 0 and 0.1 or 0.9, 0.062), size = UDim2.new(0.18, 0, 0, 2), zIndex = z + 3 })
	end
	local rect = { 0.1, 0.13, 0.8, 0.63 }
	local rim = arch(plain, "Rim", rect, z + 2, 3)
	for _, piece in ipairs(rim:GetChildren()) do
		piece.BackgroundColor3 = GOLD
	end
	local window, windowCap, windowBody = arch(plain, "Window", rect, z + 3, 0)
	local capFill = vertical(windowCap, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local bodyFill = vertical(windowBody, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	-- 휘장 : 금테 원 · 가운데 네 갈래 별 (마름모 두 개)
	local medal = frame(window, "Medal", { anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.48), size = UDim2.fromScale(0.62, 0.62), zIndex = z + 4, radius = UDim.new(1, 0), stroke = 3, transparency = 0.35 })
	local medalRatio = Instance.new("UIAspectRatioConstraint")
	medalRatio.Parent = medal
	for index, size in ipairs({ { 0.2, 0.62 }, { 0.62, 0.2 } }) do
		frame(medal, "Star" .. index, { color = GOLD, anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.5), size = UDim2.fromScale(size[1], size[2]), zIndex = z + 5, radius = UDim.new(1, 0) })
	end
	frame(medal, "Gem", { color = Color3.fromRGB(255, 244, 214), anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.5), size = UDim2.fromScale(0.16, 0.16), rotation = 45, zIndex = z + 6 })
	for index = 1, 4 do
		local angle = math.rad(index * 90 - 45)
		frame(window, "Spark" .. index, { color = GOLD, anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5 + math.cos(angle) * 0.4, 0.48 + math.sin(angle) * 0.3), size = UDim2.fromOffset(7, 7), rotation = 45, zIndex = z + 4 })
	end
	local P = ArtAtlas.Plaque
	local plaque = frame(plain, "Plaque", { color = Color3.fromRGB(34, 32, 38), anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, P.y), size = UDim2.fromScale(P.width + 0.02, P.height), zIndex = z + 3, radius = UDim.new(0.25, 0), stroke = 2 })
	frame(plain, "Pip", { color = Color3.fromRGB(190, 50, 60), anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.945), size = UDim2.fromOffset(9, 9), rotation = 45, zIndex = z + 3 })

	-- 이름 (그림 · 대신 그린 카드 모두 이름판 위)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, P.y)
	title.Size = UDim2.fromScale(P.width - 0.06, P.height * 0.72)
	title.FontFace = UIKit.font(true)
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 236, 190)
	title.ZIndex = z + 8
	title.Parent = face
	UIKit.textStroke(title, 2)

	local object = { holder = holder, face = face, title = title }
	function object.paint(card, faceUp)
		local id = faceUp and card and card.id or "back"
		local cell = ArtAtlas.cardCell(id)
		art.Visible = cell ~= nil
		plain.Visible = cell == nil
		if cell then
			paintCell(art, cell)
			showWhenLoaded(art, plain)
		end
		title.Visible = faceUp == true
		title.Text = faceUp and card and card.name or ""
		plaque.Visible = faceUp == true
		numeral.Text = faceUp and ArtAtlas.numeral(id) or ""
		local color = faceUp and card and card.color or Color3.fromRGB(120, 80, 190)
		capFill.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.1), color:Lerp(Color3.new(0, 0, 0), 0.35))
		bodyFill.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.8))
		medal.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55)
	end
	function object.setWidth(alpha)
		face.Size = UDim2.fromScale(alpha, 1)
	end
	holder.Parent = parent
	object.paint(nil, false)
	return object
end

return ArtAtlas
