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
local coinAndRobuxButtons -- Phase 13 (아래에서 정의)
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
launcher.Position = UDim2.new(0, 14, 0.42, 3 * 74 / 2 + 22 + 24)
launcher.Size = UDim2.fromOffset(260, 64)
launcher.BackgroundTransparency = 1
launcher.Parent = gui

local coinIcon = UIKit.label(launcher, { text = "🪙", size = UDim2.fromOffset(52, 52), position = UDim2.fromOffset(0, 0), textSize = 44, stroke = 2.5 })
coinIcon.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
local coinLabel = UIKit.label(launcher, {
	text = "0", size = UDim2.new(1, -58, 0, 44), position = UDim2.fromOffset(56, 2),
	textSize = 38, color = PALETTE.Gold, stroke = 4, alignX = Enum.TextXAlignment.Left,
})
local levelLabel = UIKit.label(launcher, {
	text = "Lv.1", size = UDim2.new(1, -58, 0, 20), position = UDim2.fromOffset(58, 44),
	textSize = 17, color = PALETTE.Cream, stroke = 2.5, alignX = Enum.TextXAlignment.Left,
})

local tabButtons = {}
tabButtons.shop = UIKit.railButton({ name = "ShopButton", icon = "🛒", caption = "상점", theme = "green", order = 1 })
tabButtons.quest = UIKit.railButton({ name = "QuestButton", icon = "📜", caption = "퀘스트", theme = "blue", order = 2 })
tabButtons.sabotage = UIKit.railButton({ name = "SabotageButton", icon = "😈", caption = "방해", theme = "purple", order = 5 })

--------------------------------------------------
-- 본 화면
--------------------------------------------------

local shopWindow = UIKit.window(gui, { name = "Window", title = "상점", theme = "green", icon = "🛒", size = Vector2.new(680, 500) })
local window = shopWindow.frame
local windowTitle = shopWindow.title
windowTitle.TextXAlignment = Enum.TextXAlignment.Left
windowTitle.Size = UDim2.new(1, -300, 1, 0)
windowTitle.Position = UDim2.fromOffset(78, 0)

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

-- 종류 탭 (칼 · 통 · 해적 …) — 상점 화면에서만 쓴다
local kindRow = Instance.new("Frame")
kindRow.Name = "Kinds"
kindRow.Position = UDim2.fromOffset(20, 78)
kindRow.Size = UDim2.new(1, -40, 0, 38)
kindRow.BackgroundTransparency = 1
kindRow.Parent = window

local kindButtons = {}
for index, entry in ipairs(KINDS) do
	kindButtons[entry[1]] = UIKit.button(kindRow, {
		text = entry[2], size = UDim2.fromOffset(84, 36), position = UDim2.fromOffset((index - 1) * 90, 0),
		theme = "grey", textSize = 18,
	})
end

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

-- VIP 패스 · 스타터 팩 한 줄. 이미 가졌으면 그리지 않는다.
local function premiumRow(order, offer, action, kind)
	-- 상품 ID 를 아직 넣지 않았으면 공개 서버에서는 줄 자체를 숨긴다. (Studio 에서는 "준비 중"으로 보인다)
	if not offer or offer.owned or not (offer.ready or IN_STUDIO) then
		return order
	end
	order += 1
	local row = makeRow(order, 84, action == "vip" and "gold" or (kind == "Booster" and "orange" or "teal"))
	label(row, "★ " .. offer.name, UDim2.new(1, -190, 0, 32), UDim2.fromOffset(24, 8), 24, PALETTE.Gold)
	label(row, offer.blurb or "", UDim2.new(1, -190, 0, 30), UDim2.fromOffset(24, 44), 17, PALETTE.Cream)
	local buy = textButton(row, offer.ready and ("R$ %d"):format(offer.robux) or "준비 중",
		UDim2.fromOffset(150, 52), UDim2.new(1, -166, 0.5, -26), offer.ready and "robux" or "grey")
	buy.Activated:Connect(function()
		shopRequest:FireServer(action, kind, kind)
	end)
	return order
end

-- Phase 13 : 스킨은 코인으로만 산다. 코인이 모자라면 아래에 "충전" 버튼이 생긴다.
-- (모자란 만큼을 채우는 가장 작은 코인 묶음을 권한다. 누르면 그 묶음의 로벅스 구매창)
coinAndRobuxButtons = function(row, entry)
	local affordable = state.coins >= entry.price
	local buy = textButton(row, "🪙 " .. Utility.comma(entry.price), UDim2.fromOffset(150, 40), UDim2.new(1, -166, 0, 10),
		affordable and "gold" or "grey")
	buy.Activated:Connect(function()
		if state.coins >= entry.price then
			shopRequest:FireServer("buy", entry.kind, entry.id)
		else
			showToast(("🪙 %s 부족"):format(Utility.comma(entry.price - state.coins)), false)
		end
	end)
	if affordable then
		return
	end
	local shortfall = entry.price - state.coins
	local pack = GameConfig.coinPackFor(shortfall, not IN_STUDIO)
	if not pack then
		return
	end
	local ready = (tonumber(pack.productId) or 0) > 0
	local topUp = textButton(row, ready and ("충전 R$ %d"):format(pack.robux) or "충전 준비 중",
		UDim2.fromOffset(150, 30), UDim2.new(1, -166, 0, 56), ready and "robux" or "grey")
	topUp.Activated:Connect(function()
		showToast(("🪙 %s  (R$ %d)"):format(Utility.comma(pack.coins), pack.robux), true)
		shopRequest:FireServer("robux", "coins", pack.id)
	end)
end

local KIND_NAMES = {}
for _, entry in ipairs(KINDS) do
	KIND_NAMES[entry[1]] = entry[2]
end

-- Phase 13 : 오늘의 특가 한 줄 (상점 맨 위)
local function dealRow(order)
	local entry = state.deal
	if not entry or entry.owned then
		return order
	end
	order += 1
	local row = makeRow(order, 96, "red")
	UIKit.tag(row, ("-%d%%"):format(math.floor(GameConfig.DailyDeal.Discount * 100 + 0.5)), UIKit.Colors.Gold)
	label(row, ("🔥 오늘의 특가  ·  %s"):format(KIND_NAMES[entry.kind] or entry.kind), UDim2.new(1, -190, 0, 26), UDim2.fromOffset(24, 10), 18, PALETTE.Gold)
	label(row, entry.name, UDim2.new(1, -190, 0, 30), UDim2.fromOffset(24, 38), 24, entry.rarityColor or PALETTE.Cream)
	local old = label(row, ("%s"):format(Utility.comma(entry.originalPrice or entry.price)), UDim2.new(1, -190, 0, 20), UDim2.fromOffset(24, 68), 16, PALETTE.Dim)
	old.Text = "<s>" .. old.Text .. "</s>"
	old.RichText = true
	coinAndRobuxButtons(row, entry)
	return order
end

local function drawShop()
	clearList()
	if not state then
		label(makeRow(1), "…", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(24, 0), 20, PALETTE.Dim)
		return
	end

	local order = 0
	order = premiumRow(order, state.starter, "robux", "starter")
	order = premiumRow(order, state.vip, "vip", "vip")
	order = premiumRow(order, state.booster, "pass", "Booster")
	order = dealRow(order)
	for _, entry in ipairs(state.catalog[currentKind] or {}) do
		order += 1
		local row = makeRow(order, 96, RARITY_THEME[entry.rarity or "common"] or "grey")

		label(row, entry.name, UDim2.new(1, -250, 0, 34), UDim2.fromOffset(24, 10), 24, UIKit.Colors.White)
		-- 등급만 짧게 (설명 줄은 두지 않는다)
		local rarity = label(row, entry.rarityLabel or "", UDim2.new(1, -250, 0, 24), UDim2.fromOffset(24, 50), 18, entry.rarityColor or PALETTE.Dim)
		if entry.deal and not entry.owned then
			rarity.Text = rarity.Text .. "  🔥"
		end

		-- Phase 11 : 칼 꽂기 모션은 3D 모형 대신 내 캐릭터로 동작을 보여 준다. (내 화면에서만)
		local isMotion = entry.kind == "Stab"
		local inspect = textButton(row, isMotion and "▶" or "3D", UDim2.fromOffset(62, 40), UDim2.new(1, -240, 0, 10), "purple")
		inspect.Activated:Connect(function()
			if isMotion then
				local skin = GameConfig.findSkin("Stab", entry.id)
				require(Shared.StabMotion).preview(localPlayer.Character, skin and skin.style or "classic")
			else
				require(Shared.SkinPreview).show(entry.kind, entry.id)
			end
		end)
		if entry.equipped then
			local badge = textButton(row, "장착 중", UDim2.fromOffset(150, 40), UDim2.new(1, -166, 0, 10), "teal")
			badge.Active = false
		elseif entry.owned then
			local equip = textButton(row, "장착", UDim2.fromOffset(150, 40), UDim2.new(1, -166, 0, 10), "blue")
			equip.Activated:Connect(function()
				shopRequest:FireServer("equip", entry.kind, entry.id)
			end)
		elseif entry.season then
			local badge = textButton(row, "시즌 보상", UDim2.fromOffset(150, 40), UDim2.new(1, -166, 0, 10), "grey")
			badge.Active = false
		elseif entry.vip or entry.pack then
			-- 코인으로 살 수 없다. 해당 상품으로 안내한다.
			local offer = entry.vip and state.vip or state.starter
			local ready = offer and offer.ready and not offer.owned
			local buy = textButton(row, entry.vip and "VIP 패스" or "스타터 팩", UDim2.fromOffset(150, 40), UDim2.new(1, -166, 0, 10),
				ready and "robux" or "grey")
			buy.Activated:Connect(function()
				if entry.vip then
					shopRequest:FireServer("vip", "vip", "vip")
				else
					shopRequest:FireServer("robux", "starter", "starter")
				end
			end)
		elseif entry.robux > 0 and entry.price <= 0 then
			local buy = textButton(row, ("R$ %d"):format(entry.robux), UDim2.fromOffset(150, 40), UDim2.new(1, -166, 0, 10), "robux")
			buy.Activated:Connect(function()
				shopRequest:FireServer("robux", entry.kind, entry.id)
			end)
		else
			coinAndRobuxButtons(row, entry)
		end
	end

	-- 코인 묶음
	local packs = {}
	for _, pack in ipairs(state.coinPacks or {}) do
		if pack.ready or IN_STUDIO then
			table.insert(packs, pack)
		end
	end
	if #packs > 0 then
		order += 1
		headerRow(order, state.firstPurchase and "🪙 코인 충전  ·  🎁 첫 충전 2배!" or "🪙 코인 충전")
	end

	for _, pack in ipairs(packs) do
		order += 1
		-- Phase 13 : 영화관 팝콘처럼 "대"를 크게 · 금색으로
		local row = makeRow(order, pack.highlight and 92 or 74, pack.highlight and "gold" or "green")
		if pack.badge then
			UIKit.tag(row, pack.badge, pack.highlight and UIKit.Colors.Gold or UIKit.Colors.Cream).Size = UDim2.fromOffset(150, 30)
		end
		local coinsText = ("🪙 %s"):format(Utility.comma(pack.coins))
		if state.firstPurchase then
			coinsText = ("🪙 %s → %s"):format(Utility.comma(pack.coins), Utility.comma(pack.coins * GameConfig.FirstPurchase.CoinMultiplier))
		end
		label(row, coinsText, UDim2.new(1, -200, 1, 0), UDim2.fromOffset(24, 0), pack.highlight and 30 or 24,
			pack.highlight and PALETTE.Gold or UIKit.Colors.White)
		local buy = textButton(row, pack.ready and ("R$ %d"):format(pack.robux) or "준비 중",
			UDim2.fromOffset(150, 48), UDim2.new(1, -166, 0.5, -24), pack.ready and "robux" or "grey")
		buy.Activated:Connect(function()
			shopRequest:FireServer("robux", "coins", pack.id)
		end)
	end
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
		order += 1
		label(makeRow(order, 56), "—", UDim2.new(1, -30, 1, 0), UDim2.fromOffset(24, 0), 22, PALETTE.Dim)
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

local TAB_TITLES = { shop = { "상점", "🛒", "green" }, quest = { "퀘스트", "📜", "blue" }, sabotage = { "방해", "😈", "purple" } }

local function redraw()
	windowCoins.Text = state and ("🪙 %s"):format(Utility.comma(state.coins)) or ""
	kindRow.Visible = currentTab == "shop"
	local top = currentTab == "shop" and (kindRow.Size.Y.Offset > 40 and 170 or 126) or 82
	scroller.Position = UDim2.fromOffset(20, top)
	scroller.Size = UDim2.new(1, -40, 1, -top - 16)

	for kind, button in pairs(kindButtons) do
		UIKit.setTheme(button, kind == currentKind and "gold" or "grey")
	end

	local titleInfo = TAB_TITLES[currentTab] or TAB_TITLES.shop
	windowTitle.Text = titleInfo[1]
	local badge = window:FindFirstChild("Badge")
	if badge then
		badge.Text = titleInfo[2]
	end
	UIKit.gradient(shopWindow.header, UIKit.theme(titleInfo[3])[1]:Lerp(Color3.new(1, 1, 1), 0.18), UIKit.theme(titleInfo[3])[2], 90)
	if currentTab == "shop" then
		drawShop()
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
for kind, button in pairs(kindButtons) do
	button.Activated:Connect(function()
		currentKind = kind
		redraw()
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

-- 작은 화면에서는 종류 탭을 두 줄로 나눈다 (창 크기는 UIKit 가 화면에 맞춰 줄인다)
local function fitWindow()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local columns = camera.ViewportSize.X < 700 and 4 or 7
	kindRow.Size = UDim2.new(1, -40, 0, columns == 4 and 80 or 38)
	for i, entry in ipairs(KINDS) do
		local b = kindButtons[entry[1]]
		b.Size = UDim2.new(1 / columns, -6, 0, 36)
		b.Position = UDim2.new(((i - 1) % columns) / columns, 0, 0, math.floor((i - 1) / columns) * 42)
	end
	if window.Visible then
		shopWindow.scale.Scale = shopWindow.fit()
	end
	redraw()
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
		local pop = launcher:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		pop.Parent = launcher
		pop.Scale = 1.12
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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
	task.spawn(function()
		local wasBusy = false
		while gui.Parent do
			local picker = playerGui:FindFirstChild("CursedBarrel_KnifePicker")
			local busy = picker ~= nil and picker.Enabled
			if busy ~= wasBusy then
				wasBusy = busy
				local hud = playerGui:FindFirstChild("CursedBarrel_HUD")
				if hud then
					hud.Enabled = not busy
				end
				launcher.Visible = not busy
				if busy and window.Visible then
					window.Visible = false
				end
			end
			task.wait(0.25)
		end
	end)
end
