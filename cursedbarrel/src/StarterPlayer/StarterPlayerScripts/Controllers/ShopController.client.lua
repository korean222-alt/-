--[[
	ShopController  (Phase 7 · 8)
	상점 · 인벤토리 · 일일 퀘스트 · 업적 · 방해 아이템 화면.

	이 파일은 그리기와 요청 보내기만 한다.
	  · 코인이 얼마인지, 무엇을 가지고 있는지는 전부 서버가 보내 준 값을 그대로 그린다.
	  · "살게요 / 장착할게요 / 방해할게요" 는 요청일 뿐이고, 되는지 안 되는지는 서버가 정한다.
	  · 여기서 버튼을 숨기는 것은 편의일 뿐, 보안은 서버가 담당한다.

	Phase 10
	  · 상점 맨 위에 VIP 패스 · 스타터 팩 (ID 가 비어 있으면 "준비 중")
	  · VIP · 스타터 전용 스킨은 코인 구매 대신 해당 상품으로 안내한다
	  · 전시대 프롬프트 글자를 내 상황에 맞게 바꾼다 (장착 / 구매 · 가격 / VIP 전용 …)
	  · 퀘스트 화면에 연속 출석
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local Remotes = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild(GameConfig.Remotes.Folder)
local shopRequest = Remotes:WaitForChild(GameConfig.Remotes.ShopRequest)
local shopResult = Remotes:WaitForChild(GameConfig.Remotes.ShopResult)
local sabotageRemote = Remotes:WaitForChild(GameConfig.Remotes.Sabotage)
local sabotageCue = Remotes:WaitForChild(GameConfig.Remotes.SabotageCue)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local UIKit = require(Shared:WaitForChild("UIKit"))

local PALETTE = {
	Gold = UIKit.Colors.Gold,
	Cream = UIKit.Colors.Cream,
	Dim = UIKit.Colors.Dim,
	Good = UIKit.Colors.Green,
	Bad = UIKit.Colors.Red,
}

local KINDS = { {"Knife","칼"},{"Barrel","통"},{"Ghost","해적"},{"Stab","모션"},{"Chair","의자"},{"Elimination","탈락"},{"Victory","승리"} }
local RARITY_THEME = { common = "grey", rare = "blue", epic = "purple", legend = "gold", mythic = "red" }

local state = nil -- 서버가 보내 준 마지막 상태
-- 상품 ID 를 아직 넣지 않은 것은 공개 서버에서 숨긴다. Studio 에서는 "준비 중"으로 보여 준다.
local IN_STUDIO = game:GetService("RunService"):IsStudio()
local sabotageState = { items = {}, opponents = {}, cooldown = 0 }
local currentTab = "shop"
local currentKind = "Knife"
local selectedTarget = nil

--------------------------------------------------
-- 기본 UI (Phase 14 : 만화풍 굵은 테두리 · 밝은 머리띠)
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_Shop"
gui.ResetOnSpawn = false
gui.DisplayOrder = 14
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local function label(parent, text, size, position, textSize, color)
	return UIKit.label(parent, {
		text = text, size = size, position = position, textSize = textSize or 16,
		color = color or PALETTE.Cream, alignX = Enum.TextXAlignment.Left, wrap = true,
	})
end

local function textButton(parent, text, size, position, themeName, textColor)
	return UIKit.button(parent, {
		text = text, size = size, position = position, theme = themeName or "blue",
		textColor = textColor, textSize = 18,
	})
end

--------------------------------------------------
-- 왼쪽 아래 코인 (크게) + 왼쪽 버튼
--------------------------------------------------

local launcher = Instance.new("Frame")
launcher.Name = "Coins"
launcher.AnchorPoint = Vector2.new(0, 0)
launcher.Position = UDim2.new(0, 14, 0.42, 3 * 96 / 2 + 18 + 24)
launcher.Size = UDim2.fromOffset(260, 64)
launcher.BackgroundTransparency = 1
launcher.Parent = gui
UIKit.registerHudIndicator(launcher)
-- Phase 16 : 휴대폰에서는 왼쪽 버튼 줄과 함께 줄어들고, 줄어든 버튼 줄 바로 아래에 붙는다
local launcherScale = UIKit.autoScale(launcher, UIKit.phoneFactor)
local function placeLauncher()
	local s = UIKit.railScale()
	launcher.Position = UDim2.new(0, 14, 0.42, math.floor((3 * 96 / 2 + 18 + 24) * s))
end
placeLauncher()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeLauncher)
end

-- Phase 16 : 코인 옆 돈 묶음 그림 (사진 속 게임처럼)
require(Shared:WaitForChild("MoneyIcon")).view(launcher, "cash", { size = UDim2.fromOffset(58, 58), position = UDim2.fromOffset(-4, -4) })
local coinLabel = UIKit.label(launcher, {
	text = "0", size = UDim2.new(1, -58, 0, 44), position = UDim2.fromOffset(56, 2),
	textSize = 38, color = PALETTE.Gold, stroke = 4, alignX = Enum.TextXAlignment.Left,
})
local levelLabel = UIKit.label(launcher, {
	text = "Lv.1", size = UDim2.new(1, -58, 0, 20), position = UDim2.fromOffset(58, 44),
	textSize = 17, color = PALETTE.Cream, stroke = 2.5, alignX = Enum.TextXAlignment.Left,
})

local tabButtons = {}
tabButtons.shop = UIKit.railButton({ name = "ShopButton", icon3D = "Shop", caption = "상점", theme = "green", order = 1 })
local questDot
tabButtons.quest, questDot = UIKit.railButton({ name = "QuestButton", icon3D = "Quest", caption = "퀘스트", theme = "blue", order = 2 })
tabButtons.sabotage = UIKit.railButton({ name = "SabotageButton", icon3D = "Sabotage", caption = "방해", theme = "purple", order = 5 })

-- Phase 15 : 다 채우고 아직 안 받은 퀘스트가 있으면 퀘스트 버튼 위에 빨간 동그라미 (개수)
local function refreshQuestDot()
	UIKit.setDot(questDot, localPlayer:GetAttribute("QuestReady") or 0)
end
localPlayer:GetAttributeChangedSignal("QuestReady"):Connect(refreshQuestDot)
refreshQuestDot()

--------------------------------------------------
-- 본 화면
--------------------------------------------------

local shopWindow = UIKit.window(gui, { name = "Window", title = "상점", theme = "green", size = Vector2.new(1010, 620), flexHeight = true }) -- Phase 17.2 : 카드 사이가 답답해서 넓혔다
local window = shopWindow.frame
local windowTitle = shopWindow.title
windowTitle.TextXAlignment = Enum.TextXAlignment.Left
windowTitle.Size = UDim2.new(1, -250, 1, 0)
windowTitle.Position = UDim2.fromOffset(28, 0)

-- 머리띠 오른쪽 코인 알약
local coinPill = Instance.new("Frame")
coinPill.Name = "CoinPill"
coinPill.AnchorPoint = Vector2.new(1, 0.5)
coinPill.Position = UDim2.new(1, -70, 0.5, 0)
coinPill.Size = UDim2.fromOffset(190, 42)
coinPill.ZIndex = 5
coinPill.Parent = shopWindow.header
UIKit.paint(coinPill, "gold")
UIKit.corner(coinPill, 21)
UIKit.outline(coinPill, 3)
local windowCoins = UIKit.label(coinPill, { text = "", size = UDim2.new(1, -12, 1, 0), position = UDim2.fromOffset(6, 0), textSize = 24, stroke = 3, scaled = true, zIndex = 6 })

local closeButton = shopWindow.close

local toast = UIKit.label(window, {
	name = "Toast", text = "", size = UDim2.new(1, -40, 0, 30), position = UDim2.new(0.5, 0, 1, -10),
	anchor = Vector2.new(0.5, 1), textSize = 22, color = PALETTE.Good, stroke = 3.5, zIndex = 20,
})

local scroller = Instance.new("ScrollingFrame")
scroller.Name = "List"
scroller.Position = UDim2.fromOffset(20, 126)
scroller.Size = UDim2.new(1, -40, 1, -146)
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.ScrollBarThickness = 8
scroller.ScrollBarImageColor3 = PALETTE.Gold
scroller.CanvasSize = UDim2.fromOffset(0, 0)
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.Parent = window

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent = scroller
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 10)
listPadding.Parent = scroller

local function clearList()
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makeRow(order, height, themeName)
	return UIKit.card(scroller, { name = "Row" .. order, order = order, height = height or 64, theme = themeName or "grey" })
end

-- 목록 사이 제목 줄
local function headerRow(order, text)
	local row = Instance.new("Frame")
	row.Name = "Header" .. order
	row.Size = UDim2.new(1, -10, 0, 34)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = scroller
	UIKit.label(row, { text = text, size = UDim2.new(1, -8, 1, 0), position = UDim2.fromOffset(4, 0), textSize = 24, color = PALETTE.Gold, stroke = 3.5, alignX = Enum.TextXAlignment.Left })
	return row
end

local toastToken = 0
local function showToast(message, good)
	if not message or message == "" then
		return
	end
	toast.Text = message
	toast.TextColor3 = good and PALETTE.Good or PALETTE.Bad
	toast.TextTransparency = 0
	toastToken += 1
	local token = toastToken
	task.delay(3, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

--------------------------------------------------
-- 상점 그리기
--------------------------------------------------

-- Phase 16 : 상점은 왼쪽 큰 분류 버튼 + 오른쪽 그림 카드 칸 (인기 게임 상점처럼)
--   카드마다 : 이름 · 큰 그림(스킨 3D · 돈 그림) · 등급 · 값 버튼. 그림을 누르면 크게 돌려 본다.
local MoneyIcon = require(Shared:WaitForChild("MoneyIcon"))

local CATEGORIES = {
	{ id = "featured", icon = "⭐", name = "추천", theme = "gold" },
	{ id = "coins", icon = "💵", name = "코인", theme = "green" },
	{ id = "Knife", icon = "🗡", name = "칼", theme = "blue" },
	{ id = "Barrel", icon = "🛢", name = "통", theme = "blue" },
	{ id = "Ghost", icon = "👻", name = "해적", theme = "teal" },
	{ id = "Stab", icon = "🤺", name = "모션", theme = "purple" },
	{ id = "Chair", icon = "🪑", name = "의자", theme = "purple" },
	{ id = "Elimination", icon = "💥", name = "탈락", theme = "red" },
	{ id = "Victory", icon = "🏆", name = "승리", theme = "orange" },
}
currentKind = "featured"

local shopArea = Instance.new("Frame")
shopArea.Name = "ShopArea"
shopArea.BackgroundTransparency = 1
shopArea.Position = UDim2.fromOffset(14, 76)
shopArea.Size = UDim2.new(1, -28, 1, -118)
shopArea.Parent = window

local categoryList = Instance.new("ScrollingFrame")
categoryList.Name = "Categories"
categoryList.BackgroundTransparency = 1
categoryList.BorderSizePixel = 0
categoryList.Size = UDim2.new(0, 108, 1, 0)
categoryList.ScrollBarThickness = 0
categoryList.AutomaticCanvasSize = Enum.AutomaticSize.Y
categoryList.CanvasSize = UDim2.new()
categoryList.Parent = shopArea
local categoryLayout = Instance.new("UIListLayout")
categoryLayout.Padding = UDim.new(0, 14)
categoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
categoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
categoryLayout.Parent = categoryList
local categoryPad = Instance.new("UIPadding")
categoryPad.PaddingTop = UDim.new(0, 6)
categoryPad.PaddingBottom = UDim.new(0, 12)
categoryPad.Parent = categoryList

local grid = Instance.new("ScrollingFrame")
grid.Name = "Cards"
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.Position = UDim2.fromOffset(120, 0)
grid.Size = UDim2.new(1, -120, 1, 0)
grid.ScrollBarThickness = 8
grid.ScrollBarImageColor3 = PALETTE.Gold
grid.CanvasSize = UDim2.new()
grid.Parent = shopArea

local kindButtons = {}
for index, entry in ipairs(CATEGORIES) do
	local b = UIKit.iconButton(categoryList, { name = "Category_" .. entry.id, icon = entry.icon, caption = entry.name, theme = "grey", order = index, size = 84 })
	kindButtons[entry.id] = b
end

-- 카드 칸 크기 (창 기준 크기. 작은 화면에서는 창 전체가 함께 줄어든다)
local CARD_W, CARD_H, GAP = 164, 226, 24 -- Phase 17.2 : 카드 사이를 넓혔다
local COLUMNS = 4

local function clearGrid()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- 카드를 왼쪽 위부터 차례로 놓는다. span = 2 인 카드는 두 칸을 차지한다.
local flowColumn, flowRow = 0, 0
local function resetFlow()
	flowColumn, flowRow = 0, 0
end
local function card(span, themeName)
	span = math.clamp(span or 1, 1, COLUMNS)
	if flowColumn + span > COLUMNS then
		flowColumn = 0
		flowRow += 1
	end
	local t = UIKit.theme(themeName or "grey")
	local f = Instance.new("Frame")
	f.Name = "Card"
	f.Size = UDim2.fromOffset(span * CARD_W + (span - 1) * GAP, CARD_H)
	f.Position = UDim2.fromOffset(flowColumn * (CARD_W + GAP) + 10, flowRow * (CARD_H + GAP) + 16)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = grid
	UIKit.gradient(f, t[1]:Lerp(UIKit.Colors.Body, 0.3), t[2]:Lerp(UIKit.Colors.BodyDark, 0.5), 90)
	UIKit.corner(f, 14)
	UIKit.outline(f, 3.5)
	UIKit.gloss(f, 12)
	flowColumn += span
	grid.CanvasSize = UDim2.fromOffset(0, (flowRow + 1) * (CARD_H + GAP) + 28)
	return f
end
local function nextRow()
	if flowColumn > 0 then
		flowColumn = 0
		flowRow += 1
	end
end

local function cardTitle(f, text, color, x, width)
	return UIKit.label(f, {
		name = "Title", text = text, size = UDim2.new(0, width or (f.Size.X.Offset - 12), 0, 30), position = UDim2.fromOffset(x or 6, 6),
		textSize = 21, color = color or UIKit.Colors.White, stroke = 2.5, scaled = true, zIndex = f.ZIndex + 2,
	})
end

local function cardButton(f, text, themeName, x, width)
	return UIKit.button(f, {
		text = text, size = UDim2.fromOffset(width or (f.Size.X.Offset - 16), 46), position = UDim2.new(0, x or 8, 1, -54),
		theme = themeName, textSize = 21, zIndex = f.ZIndex + 2,
	})
end

-- 스킨 그림 (3D). 동작 · 연출 스킨은 아이콘. 누르면 크게 돌려 본다.
local SkinPreview = require(Shared:WaitForChild("SkinPreview"))
local spinning = {} -- Phase 17.2 : 돌아가는 카드 그림 { frame, camera, focus, distance, angle }
local THUMB_ICONS = { Stab = "🗡", Victory = "🏆", Elimination = "💥" }
local function skinImage(parent, kind, id, size, position)
	local skin = GameConfig.findSkin(kind, id)
	if not skin or skin.id ~= id then
		return nil
	end
	-- Phase 17 : Blender 로 그린 카드 그림을 올려 두었으면(ReleaseConfig.Images.Skins) 그 그림을 쓴다
	local pictures = require(Shared.ReleaseConfig).Images.Skins or {}
	local picture = tonumber(pictures[kind .. "/" .. id]) or 0
	if picture > 0 then
		local image = Instance.new("ImageButton")
		image.Name = "Thumb"
		image.Size = size
		image.Position = position
		image.AnchorPoint = Vector2.new(0.5, 0)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = "rbxassetid://" .. picture
		image.ZIndex = parent.ZIndex + 1
		image:SetAttribute("NoStyle", true)
		image.Parent = parent
		image.Activated:Connect(function()
			if kind == "Stab" then
				require(Shared.StabMotion).preview(localPlayer.Character, skin.style or "classic")
			else
				SkinPreview.show(kind, id)
			end
		end)
		return image
	end
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Thumb"
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.BackgroundColor3 = UIKit.Colors.BodyDark
	frame.BackgroundTransparency = 0.35
	frame.Ambient = Color3.fromRGB(175, 182, 205)
	frame.LightColor = Color3.fromRGB(255, 238, 210)
	frame.LightDirection = Vector3.new(-1, -1.2, -0.8)
	frame.ZIndex = parent.ZIndex + 1
	frame:SetAttribute("NoStyle", true)
	frame.Parent = parent
	UIKit.corner(frame, 12)
	local tap = Instance.new("TextButton")
	tap.Name = "Inspect"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = frame.ZIndex + 3
	tap:SetAttribute("NoStyle", true)
	tap.Parent = frame
	tap.Activated:Connect(function()
		if kind == "Stab" then
			require(Shared.StabMotion).preview(localPlayer.Character, skin.style or "classic")
		else
			SkinPreview.show(kind, id)
		end
	end)
	local icon = THUMB_ICONS[kind]
	if icon then
		local color = (skin.fx and skin.fx.emit) or skin.color
		if color then
			frame.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45)
			frame.BackgroundTransparency = 0.1
		end
		local l = UIKit.label(frame, { text = icon, size = UDim2.fromScale(1, 1), textSize = 64, stroke = 2, zIndex = frame.ZIndex + 1 })
		l.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
		return frame
	end
	-- Phase 17.1 : 해적은 밝은 살색 · 빛나는 손 · 안개 꼬리라 카드에서 너무 환했다 → 조명을 낮춘다
	if kind == "Ghost" then
		frame.Ambient = Color3.fromRGB(112, 116, 134)
		frame.LightColor = Color3.fromRGB(214, 198, 176)
	end
	local world = Instance.new("WorldModel")
	world.Parent = frame
	local ok, model = pcall(SkinPreview.build, kind, skin, world)
	if not ok or not model then
		return frame
	end
	local box, extent = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = frame
	frame.CurrentCamera = camera
	local radius = math.max(extent.X, extent.Y, extent.Z) * 0.5
	-- Phase 17.2 : 통은 카드에서 살짝 잘려서 조금 더 멀리서 본다. 돌아가도 안 잘리게 전부 여유를 둔다
	local distance = radius / math.tan(math.rad(15)) * (kind == "Barrel" and 1.38 or 1.18) + 0.4
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0.6, 0.38, 0.9).Unit * distance, box.Position)
	table.insert(spinning, { frame = frame, camera = camera, focus = box.Position, distance = distance, angle = math.atan2(0.6, 0.9) })
	return frame
end

-- Phase 17.2 : 상점 카드의 스킨이 천천히 돈다 (상점이 열려 있을 때만, 초당 약 24번)
do
	local acc = 0
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 24 or #spinning == 0 then
			return
		end
		local step = acc
		acc = 0
		if not shopWindow.frame.Visible then
			return
		end
		for i = #spinning, 1, -1 do
			local s = spinning[i]
			if not s.frame.Parent then
				table.remove(spinning, i)
			else
				s.angle += step * 0.7
				local h = s.distance * 0.93
				local eye = s.focus + Vector3.new(math.sin(s.angle) * h, s.distance * 0.35, math.cos(s.angle) * h)
				s.camera.CFrame = CFrame.lookAt(eye, s.focus)
			end
		end
	end)
end

local KIND_NAMES = {}
for _, entry in ipairs(KINDS) do
	KIND_NAMES[entry[1]] = entry[2]
end

local redrawShop
local function jumpToCoins(shortfall)
	showToast(("🪙 %s 부족 · 코인 충전"):format(Utility.comma(shortfall)), false)
	currentKind = "coins"
	task.defer(function()
		redrawShop()
	end)
end

-- 스킨 카드 아래 버튼 : 장착 중 · 장착 · 코인 · 로벅스 · VIP · 스타터 · 시즌 · 좋아요
local function skinButton(f, entry, x, width)
	if entry.equipped then
		cardButton(f, "장착 중", "teal", x, width).Active = false
	elseif entry.owned then
		cardButton(f, "장착", "blue", x, width).Activated:Connect(function()
			shopRequest:FireServer("equip", entry.kind, entry.id)
		end)
	elseif entry.season then
		cardButton(f, "시즌 보상", "grey", x, width).Active = false
	elseif entry.reward == "like" then
		cardButton(f, "👥 그룹 보상", "blue", x, width).Activated:Connect(function()
			showToast("계단 아래 파란 드럼에서 그룹에 가입하면 받아요!", true)
		end)
	elseif entry.vip or entry.pack then
		local offer = entry.vip and state.vip or state.starter
		local ready = offer and offer.ready and not offer.owned
		cardButton(f, entry.vip and "👑 VIP" or "🎁 스타터", ready and "robux" or "grey", x, width).Activated:Connect(function()
			if entry.vip then
				shopRequest:FireServer("vip", "vip", "vip")
			else
				shopRequest:FireServer("robux", "starter", "starter")
			end
		end)
	elseif entry.robux > 0 and entry.price <= 0 then
		cardButton(f, ("R$ %d"):format(entry.robux), "robux", x, width).Activated:Connect(function()
			shopRequest:FireServer("robux", entry.kind, entry.id)
		end)
	else
		local affordable = state.coins >= entry.price
		cardButton(f, "🪙 " .. Utility.comma(entry.price), affordable and "gold" or "grey", x, width).Activated:Connect(function()
			if state.coins >= entry.price then
				shopRequest:FireServer("buy", entry.kind, entry.id)
			else
				jumpToCoins(entry.price - state.coins)
			end
		end)
	end
end

local function skinCard(entry)
	local f = card(1, RARITY_THEME[entry.rarity or "common"] or "grey")
	cardTitle(f, entry.name, UIKit.Colors.White)
	skinImage(f, entry.kind, entry.id, UDim2.fromOffset(CARD_W - 28, 112), UDim2.new(0.5, 0, 0, 40))
	local rarity = UIKit.label(f, {
		text = (entry.rarityLabel or "") .. ((entry.deal and not entry.owned) and "  🔥" or ""), size = UDim2.new(1, -12, 0, 20),
		position = UDim2.fromOffset(6, 154), textSize = 17, color = entry.rarityColor or PALETTE.Dim, stroke = 2, zIndex = f.ZIndex + 2,
	})
	rarity.Name = "Rarity"
	skinButton(f, entry)
	return f
end

local PACK_ICONS = { "cash", "cash2", "cash3", "chest", "vault" }
local function coinCard(pack, index)
	local f = card(1, pack.highlight and "gold" or "green")
	local amount = state.firstPurchase and pack.coins * GameConfig.FirstPurchase.CoinMultiplier or pack.coins
	cardTitle(f, "🪙 " .. Utility.comma(amount), pack.highlight and PALETTE.Gold or UIKit.Colors.White)
	MoneyIcon.view(f, PACK_ICONS[index] or "cash3", { size = UDim2.fromOffset(CARD_W - 20, 118), position = UDim2.new(0.5, 0, 0, 36), anchor = Vector2.new(0.5, 0), spin = pack.highlight })
	if state.firstPurchase then
		local old = UIKit.label(f, { text = "<s>" .. Utility.comma(pack.coins) .. "</s>  2배!", rich = true, size = UDim2.new(1, -12, 0, 20),
			position = UDim2.fromOffset(6, 154), textSize = 17, color = PALETTE.Gold, stroke = 2, zIndex = f.ZIndex + 2 })
		old.Name = "Double"
	end
	if pack.badge then
		local tag = UIKit.tag(f, pack.badge, pack.highlight and PALETTE.Gold or UIKit.Colors.Cream)
		tag.Size = UDim2.fromOffset(130, 28)
	end
	cardButton(f, pack.ready and ("R$ %d"):format(pack.robux) or "준비 중", pack.ready and "robux" or "grey").Activated:Connect(function()
		shopRequest:FireServer("robux", "coins", pack.id)
	end)
	return f
end

-- 추천 칸의 넓은 카드 (VIP · 스타터 · 부스터 · 오늘의 특가)
local function wideCard(themeName, title, blurb, image, buttonText, buttonTheme, onClick)
	local f = card(2, themeName)
	local w = f.Size.X.Offset
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromOffset(150, 150)
	art.Position = UDim2.fromOffset(8, 30)
	art.ZIndex = f.ZIndex + 1
	art.Parent = f
	image(art)
	cardTitle(f, title, PALETTE.Gold, 10, w - 20)
	UIKit.label(f, { name = "Blurb", text = blurb or "", size = UDim2.new(0, w - 176, 0, 96), position = UDim2.fromOffset(166, 44),
		textSize = 19, color = PALETTE.Cream, wrap = true, alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, stroke = 2, zIndex = f.ZIndex + 2 })
	local b = cardButton(f, buttonText, buttonTheme, 166, w - 176)
	if onClick then
		b.Activated:Connect(onClick)
	else
		b.Active = false
	end
	return f
end

local function premiumCard(offer, action, kind, themeName, icon)
	-- 상품 ID 를 아직 넣지 않았으면 공개 서버에서는 숨긴다. (Studio 에서는 "준비 중"으로 보인다)
	if not offer or offer.owned or not (offer.ready or IN_STUDIO) then
		return
	end
	wideCard(themeName, "★ " .. offer.name, offer.blurb, function(art)
		MoneyIcon.view(art, icon, { size = UDim2.fromScale(1, 1), spin = true })
	end, offer.ready and ("R$ %d"):format(offer.robux) or "준비 중", offer.ready and "robux" or "grey", function()
		shopRequest:FireServer(action, kind, kind)
	end)
end

local function dealCard()
	local entry = state.deal
	if not entry or entry.owned then
		return
	end
	local off = math.floor(GameConfig.DailyDeal.Discount * 100 + 0.5)
	local f = card(2, "red")
	local w = f.Size.X.Offset
	UIKit.tag(f, ("-%d%%"):format(off), PALETTE.Gold)
	cardTitle(f, ("🔥 오늘의 특가 · %s"):format(KIND_NAMES[entry.kind] or entry.kind), PALETTE.Gold, 10, w - 20)
	skinImage(f, entry.kind, entry.id, UDim2.fromOffset(150, 150), UDim2.fromOffset(83, 36))
	UIKit.label(f, { name = "Name", text = entry.name, size = UDim2.new(0, w - 176, 0, 34), position = UDim2.fromOffset(166, 50),
		textSize = 24, color = entry.rarityColor or PALETTE.Cream, alignX = Enum.TextXAlignment.Left, scaled = true, zIndex = f.ZIndex + 2 })
	UIKit.label(f, { name = "Old", text = "<s>🪙 " .. Utility.comma(entry.originalPrice or entry.price) .. "</s>", rich = true,
		size = UDim2.new(0, w - 176, 0, 24), position = UDim2.fromOffset(166, 92), textSize = 19, color = PALETTE.Dim,
		alignX = Enum.TextXAlignment.Left, zIndex = f.ZIndex + 2 })
	skinButton(f, entry, 166, w - 176)
end

local shownKind = nil
redrawShop = function()
	-- 분류를 바꿀 때만 맨 위로 (사고 나서 다시 그릴 때는 보던 자리 그대로)
	local keepScroll = shownKind == currentKind
	shownKind = currentKind
	local scroll = grid.CanvasPosition
	clearGrid()
	resetFlow()
	for id, b in pairs(kindButtons) do
		UIKit.setTheme(b, id == currentKind and "gold" or "grey")
	end
	if not state then
		UIKit.label(grid, { text = "…", size = UDim2.fromOffset(200, 40), position = UDim2.fromOffset(10, 10), textSize = 24 })
		return
	end
	if currentKind == "featured" then
		dealCard()
		premiumCard(state.starter, "robux", "starter", "teal", "gift")
		premiumCard(state.vip, "vip", "vip", "gold", "crown")
		premiumCard(state.booster, "pass", "Booster", "orange", "potion")
		nextRow()
	end
	if currentKind == "featured" or currentKind == "coins" then
		local index = 0
		for i, pack in ipairs(state.coinPacks or {}) do
			if pack.ready or IN_STUDIO then
				index += 1
				coinCard(pack, i)
			end
		end
		if index == 0 and currentKind == "coins" then
			UIKit.label(grid, { text = "준비 중", size = UDim2.fromOffset(300, 40), position = UDim2.fromOffset(10, 10), textSize = 24, color = PALETTE.Dim })
		end
	else
		for _, entry in ipairs(state.catalog[currentKind] or {}) do
			skinCard(entry)
		end
	end
	grid.CanvasPosition = keepScroll and scroll or Vector2.zero
end

for id, b in pairs(kindButtons) do
	b.Activated:Connect(function()
		currentKind = id
		redrawShop()
	end)
end

--------------------------------------------------
-- 퀘스트 · 업적 그리기
--------------------------------------------------

local function progressBar(parent, ratio, color, y)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -220, 0, 16)
	track.Position = UDim2.fromOffset(24, y or 50)
	track.BackgroundColor3 = UIKit.Colors.BodyDark
	track.BorderSizePixel = 0
	track.Parent = parent
	UIKit.corner(track, 8)
	UIKit.outline(track, 2.5)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	UIKit.corner(fill, 8)
	UIKit.gradient(fill, color or PALETTE.Gold, (color or PALETTE.Gold):Lerp(Color3.new(0, 0, 0), 0.3), 90)
	return track
end

local function drawQuests()
	clearList()
	if not state then
		label(makeRow(1), "…", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(24, 0), 20, PALETTE.Dim)
		return
	end

	local order = 1
	-- Phase 13 : 출석은 왼쪽 출석판에서 받는다
	local attend = state.attendance
	if attend then
		local attendance = makeRow(order, 56, attend.ready and "green" or "grey")
		label(attendance, attend.ready and ("📅 출석 보상 받기! (%d/7)"):format(attend.count)
			or ("📅 출석 완료 (%d/7)"):format(attend.count == 0 and 7 or attend.count),
			UDim2.new(1, -30, 1, 0), UDim2.fromOffset(24, 0), 20, attend.ready and PALETTE.Good or PALETTE.Cream)
		order += 1
	end

	headerRow(order, "📜 오늘의 퀘스트")

	for _, quest in ipairs(state.quests or {}) do
		order += 1
		local done = quest.progress >= quest.goal
		local row = makeRow(order, 80, quest.claimed and "grey" or (done and "green" or "blue"))
		label(row, quest.text, UDim2.new(1, -220, 0, 30), UDim2.fromOffset(24, 10), 20, UIKit.Colors.White)
		progressBar(row, quest.progress / math.max(1, quest.goal), done and PALETTE.Good or PALETTE.Gold, 48)
		label(row, ("%d/%d"):format(quest.progress, quest.goal), UDim2.fromOffset(120, 16), UDim2.new(1, -330, 0, 48), 15, UIKit.Colors.White)
			.TextXAlignment = Enum.TextXAlignment.Right

		if quest.claimed then
			local claimed = textButton(row, "✔", UDim2.fromOffset(150, 44), UDim2.new(1, -166, 0.5, -22), "grey")
			claimed.Active = false
		elseif done then
			local claim = textButton(row, ("🪙 %s 받기"):format(Utility.comma(quest.reward)), UDim2.fromOffset(150, 44), UDim2.new(1, -166, 0.5, -22), "green")
			claim.Activated:Connect(function()
				shopRequest:FireServer("claimQuest", quest.id)
			end)
		else
			local reward = textButton(row, ("🪙 %s"):format(Utility.comma(quest.reward)), UDim2.fromOffset(150, 44), UDim2.new(1, -166, 0.5, -22), "gold")
			reward.Active = false
		end
	end

	order += 1
	headerRow(order, "🏅 업적")

	for _, entry in ipairs(state.achievements or {}) do
		order += 1
		local row = makeRow(order, 76, entry.done and "green" or "purple")
		label(row, entry.text, UDim2.new(1, -220, 0, 30), UDim2.fromOffset(24, 8), 19, entry.done and PALETTE.Good or UIKit.Colors.White)
		progressBar(row, entry.progress / math.max(1, entry.goal), entry.done and PALETTE.Good or PALETTE.Gold, 46)
		local reward = textButton(row, entry.done and "✔" or ("🪙 %s"):format(Utility.comma(entry.reward)), UDim2.fromOffset(150, 42), UDim2.new(1, -166, 0.5, -21), entry.done and "grey" or "gold")
		reward.Active = false
	end
end

--------------------------------------------------
-- 방해 아이템 그리기
--------------------------------------------------

local function drawSabotage()
	clearList()

	local order = 1
	headerRow(order, "🎯 상대")

	if #sabotageState.opponents == 0 then
		-- Phase 15 : 테이블에서 게임 중일 때만 쓸 수 있다는 것만 짧게
		order += 1
		label(makeRow(order, 56), "테이블에서 게임 중일 때 쓸 수 있어요", UDim2.new(1, -30, 1, 0), UDim2.fromOffset(24, 0), 20, PALETTE.Dim)
		selectedTarget = nil
	else
		-- 고른 상대가 사라졌으면 첫 번째로 되돌린다
		local stillThere = false
		for _, opponent in ipairs(sabotageState.opponents) do
			if opponent.userId == selectedTarget then
				stillThere = true
			end
		end
		if not stillThere then
			selectedTarget = sabotageState.opponents[1].userId
		end

		for _, opponent in ipairs(sabotageState.opponents) do
			order += 1
			local chosen = opponent.userId == selectedTarget
			local row = makeRow(order, 60, chosen and "gold" or "grey")
			label(row, opponent.name, UDim2.new(1, -220, 1, 0), UDim2.fromOffset(24, 0), 22, chosen and PALETTE.Gold or UIKit.Colors.White)
			local pick = textButton(row, chosen and "✔" or "고르기", UDim2.fromOffset(150, 40), UDim2.new(1, -166, 0.5, -20), chosen and "gold" or "blue")
			pick.Activated:Connect(function()
				selectedTarget = opponent.userId
				drawSabotage()
			end)
		end
	end

	order += 1
	headerRow(order, "😈 방해 아이템")

	local items = {}
	for _, item in ipairs(sabotageState.items) do
		if item.ready or (item.owned or 0) > 0 or IN_STUDIO then
			table.insert(items, item)
		end
	end
	for _, item in ipairs(items) do
		order += 1
		local row = makeRow(order, 84, "purple")
		label(row, ("%s  %s"):format(item.icon or "", item.name), UDim2.new(1, -220, 0, 30), UDim2.fromOffset(24, 8), 22, item.color or UIKit.Colors.White)
		label(row, item.blurb or "", UDim2.new(1, -220, 0, 30), UDim2.fromOffset(24, 44), 16, PALETTE.Cream)

		local usable = (item.ready or (item.owned or 0) > 0) and selectedTarget ~= nil
		local buy = textButton(row, (item.owned or 0) > 0 and ("사용 ×%d"):format(item.owned) or (item.ready and ("R$ %d"):format(item.robux) or "준비 중"),
			UDim2.fromOffset(150, 48), UDim2.new(1, -166, 0.5, -24), usable and "robux" or "grey")
		buy.Activated:Connect(function()
			if not usable then
				showToast((item.ready or (item.owned or 0) > 0) and "먼저 상대를 골라 주세요" or "준비 중", false)
				return
			end
			sabotageRemote:FireServer("use", item.id, selectedTarget)
		end)
	end
	if #items == 0 then
		order += 1
		label(makeRow(order, 56), "준비 중", UDim2.new(1, -30, 1, 0), UDim2.fromOffset(24, 0), 22, PALETTE.Dim)
	end
end

--------------------------------------------------
-- 탭 전환
--------------------------------------------------

local TAB_TITLES = { shop = { "상점", "green" }, quest = { "퀘스트", "blue" }, sabotage = { "방해", "purple" } }

local function redraw()
	windowCoins.Text = state and ("🪙 %s"):format(Utility.comma(state.coins)) or ""
	shopArea.Visible = currentTab == "shop"
	scroller.Visible = currentTab ~= "shop"
	scroller.Position = UDim2.fromOffset(20, 82)
	scroller.Size = UDim2.new(1, -40, 1, -128)

	local titleInfo = TAB_TITLES[currentTab] or TAB_TITLES.shop
	windowTitle.Text = titleInfo[1]
	UIKit.gradient(shopWindow.header, UIKit.theme(titleInfo[2])[1]:Lerp(Color3.new(1, 1, 1), 0.18), UIKit.theme(titleInfo[2])[2], 90)
	if currentTab == "shop" then
		redrawShop()
	elseif currentTab == "quest" then
		drawQuests()
	else
		drawSabotage()
	end
end

local function openTab(name)
	if window.Visible and currentTab == name then
		window.Visible = false
		redraw()
		return
	end
	currentTab = name
	shopWindow.open()
	if name == "sabotage" then
		sabotageRemote:FireServer("list")
	else
		shopRequest:FireServer("sync")
	end
	redraw()
end

for name, button in pairs(tabButtons) do
	button.Activated:Connect(function()
		openTab(name)
	end)
end
closeButton.Activated:Connect(function()
	window.Visible = false
	redraw()
end)

--------------------------------------------------
-- 서버가 보내는 값
--------------------------------------------------

--------------------------------------------------
-- 전시대 프롬프트 글자 (Phase 10)
-- 프롬프트는 서버 것이지만 글자는 각자 화면에서만 바꿀 수 있다. 판단은 여전히 서버가 한다.
--------------------------------------------------
local function findEntry(kind, id)
	for _, entry in ipairs((state and state.catalog[kind]) or {}) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

local function refreshPedestal(pedestal)
	local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt")
	local entry = findEntry(pedestal:GetAttribute("SkinKind"), pedestal:GetAttribute("SkinId"))
	if not prompt or not entry then
		return
	end
	if entry.equipped then
		prompt.ActionText = "장착 중"
	elseif entry.owned then
		prompt.ActionText = "장착"
	elseif entry.vip then
		prompt.ActionText = "VIP 패스 전용"
	elseif entry.pack then
		prompt.ActionText = "스타터 팩 전용"
	elseif entry.reward == "like" then
		prompt.ActionText = "👥 그룹 가입 보상"
	elseif entry.robux > 0 and entry.price <= 0 then
		prompt.ActionText = ("R$ %d"):format(entry.robux)
	else
		prompt.ActionText = ("🪙 %s"):format(Utility.comma(entry.price))
	end
end

local function refreshPedestals()
	for _, pedestal in ipairs(CollectionService:GetTagged(GameConfig.Tags.SkinPedestal)) do
		refreshPedestal(pedestal)
	end
end
CollectionService:GetInstanceAddedSignal(GameConfig.Tags.SkinPedestal):Connect(function(pedestal)
	task.defer(refreshPedestal, pedestal)
end)

shopResult.OnClientEvent:Connect(function(ok, message, payload)
	if typeof(payload) == "table" then
		state = payload
		coinLabel.Text = Utility.comma(state.coins)
		levelLabel.Text = ("Lv.%d  ·  🏆 %d"):format(state.level or 1, state.wins or 0)
		refreshPedestals()
	end
	if message then
		showToast(message, ok)
		-- Phase 21 : 사거나 받으면 화면 가운데에 "획득!" (빛살 · 반짝임)
		if ok then
			local coins = message:match("^([%d,]+) 코인 구매 완료")
			local name = message:match("^(.-) 구매 완료") or message:match("^(.-) 을%(를%) 받았습니다")
			if coins then
				UIKit.rewardPopup({ text = coins .. " 코인", money = "cash3" })
			elseif name then
				UIKit.rewardPopup({ text = "「" .. name .. "」", emoji = "🎁" })
			end
		end
	end
	if window.Visible then
		redraw()
	end
end)

sabotageCue.OnClientEvent:Connect(function(_, data)
	if typeof(data) ~= "table" then
		return
	end
	if data.id == "list" then
		sabotageState = {
			items = data.items or {},
			opponents = data.opponents or {},
			cooldown = data.cooldown or 0,
		}
		if window.Visible and currentTab == "sabotage" then
			redraw()
		end
		return
	end
	if data.id == "deny" or data.id == "done" then
		if window.Visible and currentTab == "sabotage" then
			showToast(data.message, data.id == "done")
			sabotageRemote:FireServer("list")
		end
	end
end)

-- 처음 한 번 받아 온다. 서버가 자료를 다 읽으면 알아서 한 번 더 보내 준다.
task.defer(function()
	task.wait(1)
	shopRequest:FireServer("sync")
end)

-- 작은 화면에서는 창 전체를 화면에 맞춰 줄인다 (UIKit.window 의 fit)
local function fitWindow()
	if window.Visible then
		shopWindow.scale.Scale = shopWindow.fit()
	end
end
fitWindow()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)
end

-- 코인이 들어오면 숫자 위로 "+얼마"가 튀어 오른다
local previousCoins = localPlayer:GetAttribute("Coins") or 0
localPlayer:GetAttributeChangedSignal("Coins"):Connect(function()
	local now = localPlayer:GetAttribute("Coins") or 0
	if now > previousCoins then
		local reward = UIKit.label(launcher, {
			text = "+" .. Utility.comma(now - previousCoins), size = UDim2.fromOffset(200, 34), position = UDim2.fromOffset(60, -24),
			textSize = 30, color = PALETTE.Good, stroke = 3.5, alignX = Enum.TextXAlignment.Left,
		})
		TweenService:Create(reward, TweenInfo.new(1.1), { Position = UDim2.fromOffset(60, -70), TextTransparency = 1 }):Play()
		game:GetService("Debris"):AddItem(reward, 1.2)
		local base = UIKit.screenScale()
		launcherScale.Scale = base * 1.12
		TweenService:Create(launcherScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = base }):Play()
	end
	previousCoins = now
end)

-- 상점 버튼 그림 (ReleaseConfig.Branding.ShopImage 를 넣으면 🛒 대신 그 그림)
do
	local brand = require(Shared.ReleaseConfig).Branding
	local image = tonumber(brand.ShopImage) or 0
	if image > 0 then
		tabButtons.shop.Image = "rbxassetid://" .. image
		local icon = tabButtons.shop:FindFirstChild("Icon")
		if icon then
			icon.Visible = false
		end
	end
	-- 내 차례에는 칼 고르는 창이 화면 아래를 쓴다. 열려 있던 상점 창은 닫는다. (칼 고르는 창을 가리지 않게)
	-- Phase 21 : 게임 중(카운트다운부터 결과까지 · 관전 포함)에는 상점 · 출석 · 룰렛 버튼과 코인을 숨긴다.
	--   게임 중에 쓰는 😈 방해 버튼만 남긴다. 내 차례 · 해적이 튀어나오는 동안에는 버튼 줄 전체를 숨긴다
	task.spawn(function()
		local wasMode = nil
		while gui.Parent do
			local picker = playerGui:FindFirstChild("CursedBarrel_KnifePicker")
			local _, inMatch = UIKit.matchTable()
			local focus = localPlayer:GetAttribute("PirateFocus") == true
			local mode = ((picker ~= nil and picker.Enabled) or focus) and "hidden" or (inMatch and "match" or "lobby")
			local hud = playerGui:FindFirstChild("CursedBarrel_HUD")
			if mode ~= wasMode or (hud and hud:GetAttribute("RailMode") ~= mode) then
				wasMode = mode
				if hud then
					hud:SetAttribute("RailMode", mode)
					hud.Enabled = mode ~= "hidden"
					for _, railName in ipairs({ "Rail", "RightRail" }) do
						local rail = hud:FindFirstChild(railName)
						for _, b in ipairs(rail and rail:GetChildren() or {}) do
							if b:IsA("GuiButton") then
								b.Visible = mode == "lobby" or b.Name == "SabotageButton"
							end
						end
					end
				end
				launcher:SetAttribute("HideForGame", mode ~= "lobby")
				if mode ~= "lobby" and window.Visible then
					window.Visible = false
				end
			end
			task.wait(0.25)
		end
	end)
end
