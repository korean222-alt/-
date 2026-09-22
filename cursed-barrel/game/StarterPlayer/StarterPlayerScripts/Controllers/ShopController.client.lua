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
local UserInputService = game:GetService("UserInputService")

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

local PALETTE = {
	Back = Color3.fromRGB(22, 17, 13),
	Panel = Color3.fromRGB(34, 25, 18),
	Row = Color3.fromRGB(46, 33, 23),
	Gold = Color3.fromRGB(232, 186, 96),
	Cream = Color3.fromRGB(238, 226, 200),
	Dim = Color3.fromRGB(158, 144, 122),
	Good = Color3.fromRGB(131, 209, 144),
	Bad = Color3.fromRGB(230, 118, 104),
	Robux = Color3.fromRGB(0, 176, 111),
}

local TAB_NAMES = { { "shop", "상점" }, { "quest", "퀘스트" }, { "sabotage", "방해" } }
local KINDS = { {"Knife","칼"},{"Barrel","통"},{"Ghost","해적"},{"Chair","의자"},{"Elimination","탈락"},{"Victory","승리"} }

local state = nil -- 서버가 보내 준 마지막 상태
-- 상품 ID 를 아직 넣지 않은 것은 공개 서버에서 숨긴다. Studio 에서는 "준비 중"으로 보여 준다.
local IN_STUDIO = game:GetService("RunService"):IsStudio()
local sabotageState = { items = {}, opponents = {}, cooldown = 0 }
local currentTab = "shop"
local currentKind = "Knife"
local selectedTarget = nil

--------------------------------------------------
-- 기본 UI
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_Shop"
gui.ResetOnSpawn = false
gui.DisplayOrder = 14
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local function corner(parent, radius)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius or 10)
	instance.Parent = parent
	return instance
end

local function stroke(parent, color, thickness, transparency)
	local instance = Instance.new("UIStroke")
	instance.Color = color or PALETTE.Gold
	instance.Thickness = thickness or 1.5
	instance.Transparency = transparency or 0.4
	instance.Parent = parent
	return instance
end

local function label(parent, text, size, position, textSize, color, font)
	local instance = Instance.new("TextLabel")
	instance.Size = size
	instance.Position = position
	instance.BackgroundTransparency = 1
	instance.Font = font or Enum.Font.GothamBold
	instance.TextSize = textSize or 14
	instance.TextColor3 = color or PALETTE.Cream
	instance.TextXAlignment = Enum.TextXAlignment.Left
	instance.Text = text
	instance.Parent = parent
	return instance
end

local function textButton(parent, text, size, position, color, textColor)
	local instance = Instance.new("TextButton")
	instance.Size = size
	instance.Position = position
	instance.BackgroundColor3 = color or PALETTE.Row
	instance.BorderSizePixel = 0
	instance.AutoButtonColor = true
	instance.Font = Enum.Font.GothamBold
	instance.TextSize = 13
	instance.TextColor3 = textColor or PALETTE.Cream
	instance.Text = text
	instance.Parent = parent
	corner(instance, 8)
	return instance
end

--------------------------------------------------
-- 코인 표시 + 여는 버튼
--------------------------------------------------

local launcher = Instance.new("Frame")
launcher.Name = "Launcher"
launcher.AnchorPoint = Vector2.new(0, 1)
launcher.Position = UDim2.new(0, 14, 1, UserInputService.TouchEnabled and -108 or -16)
launcher.Size = UDim2.fromOffset(212, 76)
launcher.BackgroundColor3 = PALETTE.Back
launcher.BackgroundTransparency = 0.15
launcher.BorderSizePixel = 0
launcher.Parent = gui
corner(launcher, 12)
stroke(launcher, PALETTE.Gold, 1.5, 0.5)

local coinLabel = label(launcher, "0 코인", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(10, 6), 15, PALETTE.Gold)
local levelLabel = label(launcher, "Lv.1", UDim2.new(1, -16, 0, 16), UDim2.fromOffset(10, 24), 12, PALETTE.Dim)

local tabButtons = {}
for index, entry in ipairs(TAB_NAMES) do
	local button = textButton(launcher, entry[2], UDim2.fromOffset(62, 24), UDim2.fromOffset(10 + (index - 1) * 66, 44))
	tabButtons[entry[1]] = button
end

--------------------------------------------------
-- 본 화면
--------------------------------------------------

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(620, 430)
window.BackgroundColor3 = PALETTE.Back
window.BackgroundTransparency = 0.04
window.BorderSizePixel = 0
window.Visible = false
window.Parent = gui
corner(window, 16)
stroke(window, PALETTE.Gold, 2, 0.3)

local windowTitle = label(window, "상점", UDim2.new(1, -120, 0, 28), UDim2.fromOffset(20, 14), 20, PALETTE.Gold)
local windowCoins = label(window, "", UDim2.fromOffset(180, 20), UDim2.new(1, -206, 0, 18), 14, PALETTE.Gold)
windowCoins.TextXAlignment = Enum.TextXAlignment.Right

local closeButton = textButton(window, "✕", UDim2.fromOffset(30, 26), UDim2.new(1, -44, 0, 14), PALETTE.Row)

local toast = label(window, "", UDim2.new(1, -40, 0, 18), UDim2.fromOffset(20, 44), 13, PALETTE.Good)

-- 종류 탭 (칼 · 통 · 해적) — 상점 화면에서만 쓴다
local kindRow = Instance.new("Frame")
kindRow.Name = "Kinds"
kindRow.Position = UDim2.fromOffset(20, 66)
kindRow.Size = UDim2.new(1, -40, 0, 26)
kindRow.BackgroundTransparency = 1
kindRow.Parent = window

local kindButtons = {}
for index, entry in ipairs(KINDS) do
	kindButtons[entry[1]] = textButton(kindRow, entry[2], UDim2.fromOffset(88, 26), UDim2.fromOffset((index - 1) * 94, 0))
end

local scroller = Instance.new("ScrollingFrame")
scroller.Name = "List"
scroller.Position = UDim2.fromOffset(20, 100)
scroller.Size = UDim2.new(1, -40, 1, -120)
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.ScrollBarThickness = 5
scroller.ScrollBarImageColor3 = PALETTE.Gold
scroller.CanvasSize = UDim2.fromOffset(0, 0)
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.Parent = window

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroller

local function clearList()
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makeRow(order, height)
	local row = Instance.new("Frame")
	row.Name = "Row" .. order
	row.Size = UDim2.new(1, -8, 0, height or 52)
	row.BackgroundColor3 = PALETTE.Row
	row.BackgroundTransparency = 0.15
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = scroller
	corner(row, 8)
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
	local row = makeRow(order, 62)
	row.BackgroundColor3 = Color3.fromRGB(64, 44, 20)
	label(row, "★ " .. offer.name, UDim2.new(1, -140, 0, 22), UDim2.fromOffset(12, 6), 15, PALETTE.Gold)
	local blurb = label(row, offer.blurb or "", UDim2.new(1, -140, 0, 30), UDim2.fromOffset(12, 28), 12, PALETTE.Cream)
	blurb.TextWrapped = true
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	local buy = textButton(row, offer.ready and ("R$ %d"):format(offer.robux) or "준비 중",
		UDim2.fromOffset(110, 34), UDim2.new(1, -122, 0, 14),
		offer.ready and PALETTE.Robux or PALETTE.Panel,
		offer.ready and Color3.new(1, 1, 1) or PALETTE.Dim)
	buy.Activated:Connect(function()
		shopRequest:FireServer(action, kind, kind)
	end)
	return order
end

local function drawShop()
	clearList()
	if not state then
		label(makeRow(1), "자료를 불러오는 중…", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 14, PALETTE.Dim)
		return
	end

	local order = 0
	order = premiumRow(order, state.starter, "robux", "starter")
	order = premiumRow(order, state.vip, "vip", "vip")
	for _, entry in ipairs(state.catalog[currentKind] or {}) do
		order += 1
		local row = makeRow(order,78)

		label(row, entry.name, UDim2.new(1,-178,0,38), UDim2.fromOffset(12, 4), 14,
			entry.rarityColor or PALETTE.Cream).TextWrapped=true

		local detail
		if entry.owned then
			detail = entry.equipped and "장착 중" or "보유 중"
		elseif entry.vip then
			detail = "VIP 패스 전용"
		elseif entry.pack then
			detail = "스타터 팩 전용"
		elseif entry.robux > 0 and entry.price <= 0 then
			detail = ("R$ %d"):format(entry.robux)
		else
			detail = ("%s 코인"):format(Utility.comma(entry.price))
		end
		label(row, ("%s  ·  %s"):format(entry.rarityLabel, detail),
			UDim2.new(1,-178,0,28), UDim2.fromOffset(12, 42), 12, PALETTE.Dim).TextWrapped=true

		local inspect=textButton(row,"3D",UDim2.fromOffset(42,30),UDim2.new(1,-160,0,11),PALETTE.Panel,PALETTE.Gold)
        inspect.Activated:Connect(function() require(Shared.SkinPreview).show(entry.kind,entry.id) end)
		if entry.equipped then
			local badge = textButton(row, "장착 중", UDim2.fromOffset(96, 30), UDim2.new(1, -110, 0, 11), PALETTE.Panel, PALETTE.Good)
			badge.AutoButtonColor = false
			badge.Active = false
		elseif entry.owned then
			local equip = textButton(row, "장착", UDim2.fromOffset(96, 30), UDim2.new(1, -110, 0, 11), PALETTE.Row, PALETTE.Gold)
			equip.Activated:Connect(function()
				shopRequest:FireServer("equip", entry.kind, entry.id)
			end)
		elseif entry.vip or entry.pack then
			-- 코인으로 살 수 없다. 해당 상품으로 안내한다.
			local offer = entry.vip and state.vip or state.starter
			local ready = offer and offer.ready and not offer.owned
			local buy = textButton(row, entry.vip and "VIP 패스" or "스타터 팩", UDim2.fromOffset(96, 30), UDim2.new(1, -110, 0, 11),
				ready and PALETTE.Robux or PALETTE.Panel, ready and Color3.new(1, 1, 1) or PALETTE.Dim)
			buy.Activated:Connect(function()
				if entry.vip then
					shopRequest:FireServer("vip", "vip", "vip")
				else
					shopRequest:FireServer("robux", "starter", "starter")
				end
			end)
		elseif entry.robux > 0 and entry.price <= 0 then
			local buy = textButton(row, ("R$ %d"):format(entry.robux), UDim2.fromOffset(96, 30), UDim2.new(1, -110, 0, 11), PALETTE.Robux, Color3.new(1, 1, 1))
			buy.Activated:Connect(function()
				shopRequest:FireServer("robux", entry.kind, entry.id)
			end)
		else
			local affordable = state.coins >= entry.price
			local buy = textButton(row, affordable and "구매" or "코인 부족",
				UDim2.fromOffset(96, 30), UDim2.new(1, -110, 0, 11),
				affordable and PALETTE.Row or PALETTE.Panel,
				affordable and PALETTE.Gold or PALETTE.Dim)
			buy.Activated:Connect(function()
				shopRequest:FireServer("buy", entry.kind, entry.id)
			end)
		end
	end

	-- 통 스킨 탭에는 우선순위 규칙을 한 줄로 알려준다.
	if currentKind == "Barrel" then
		order += 1
		local note = makeRow(order, 40)
		note.BackgroundTransparency = 0.6
		label(note, "한 테이블에는 통이 하나뿐입니다. 등급이 높은 통이 보이고, 같은 등급이면 레벨이 높은 사람 것이 보입니다.",
			UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 12, PALETTE.Dim).TextWrapped = true
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
		local header = makeRow(order, 28)
		header.BackgroundTransparency = 1
		label(header, "코인 충전", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(4, 0), 15, PALETTE.Gold)
	end

	for _, pack in ipairs(packs) do
		order += 1
		local row = makeRow(order, 44)
		label(row, pack.name, UDim2.fromOffset(240, 20), UDim2.fromOffset(12, 12), 14, PALETTE.Cream)
		local buy = textButton(row, pack.ready and ("R$ %d"):format(pack.robux) or "준비 중",
			UDim2.fromOffset(96, 26), UDim2.new(1, -110, 0, 9),
			pack.ready and PALETTE.Robux or PALETTE.Panel,
			pack.ready and Color3.new(1, 1, 1) or PALETTE.Dim)
		buy.Activated:Connect(function()
			shopRequest:FireServer("robux", "coins", pack.id)
		end)
	end
end

--------------------------------------------------
-- 퀘스트 · 업적 그리기
--------------------------------------------------

local function progressBar(parent, ratio, color)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -130, 0, 6)
	track.Position = UDim2.fromOffset(12, 36)
	track.BackgroundColor3 = PALETTE.Panel
	track.BorderSizePixel = 0
	track.Parent = parent
	corner(track, 3)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	fill.BackgroundColor3 = color or PALETTE.Gold
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 3)

	return track
end

local function drawQuests()
	clearList()
	if not state then
		label(makeRow(1), "자료를 불러오는 중…", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 14, PALETTE.Dim)
		return
	end

	local order = 1
	-- Phase 10 : 연속 출석
	local streak = state.loginStreak or 0
	if streak > 0 then
		local today = GameConfig.dailyBonusFor(streak)
		local tomorrow, day = GameConfig.dailyBonusFor(streak + 1)
		local attendance = makeRow(order, 40)
		attendance.BackgroundColor3 = Color3.fromRGB(40, 52, 36)
		label(attendance, ("출석 %d일째 · 오늘 +%s 코인 · 내일(%d일째) 오면 +%s"):format(streak, Utility.comma(today), day, Utility.comma(tomorrow)),
			UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 13, PALETTE.Good).TextWrapped = true
		order += 1
	end

	local header = makeRow(order, 26)
	header.BackgroundTransparency = 1
	label(header, "오늘의 퀘스트", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(4, 0), 15, PALETTE.Gold)

	for _, quest in ipairs(state.quests or {}) do
		order += 1
		local row = makeRow(order, 52)
		label(row, quest.text, UDim2.fromOffset(300, 20), UDim2.fromOffset(12, 8), 14, PALETTE.Cream)
		label(row, ("%d / %d  ·  %s 코인"):format(quest.progress, quest.goal, Utility.comma(quest.reward)),
			UDim2.fromOffset(240, 16), UDim2.new(1, -250, 0, 8), 12, PALETTE.Dim).TextXAlignment = Enum.TextXAlignment.Right
		progressBar(row, quest.progress / math.max(1, quest.goal))

		if quest.claimed then
			local done = textButton(row, "받음", UDim2.fromOffset(84, 28), UDim2.new(1, -98, 0, 12), PALETTE.Panel, PALETTE.Dim)
			done.AutoButtonColor = false
			done.Active = false
		elseif quest.progress >= quest.goal then
			local claim = textButton(row, "보상 받기", UDim2.fromOffset(84, 28), UDim2.new(1, -98, 0, 12), PALETTE.Row, PALETTE.Good)
			claim.Activated:Connect(function()
				shopRequest:FireServer("claimQuest", quest.id)
			end)
		end
	end

	if #(state.quests or {}) == 0 then
		order += 1
		label(makeRow(order, 40), "오늘 받은 퀘스트가 없습니다. 잠시 뒤 다시 확인해 주세요.",
			UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 13, PALETTE.Dim)
	end

	order += 1
	local achievementHeader = makeRow(order, 26)
	achievementHeader.BackgroundTransparency = 1
	label(achievementHeader, "업적", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(4, 0), 15, PALETTE.Gold)

	for _, entry in ipairs(state.achievements or {}) do
		order += 1
		local row = makeRow(order, 46)
		label(row, entry.text, UDim2.fromOffset(280, 20), UDim2.fromOffset(12, 6), 14,
			entry.done and PALETTE.Good or PALETTE.Cream)
		label(row, ("%d / %d  ·  %s 코인"):format(entry.progress, entry.goal, Utility.comma(entry.reward)),
			UDim2.fromOffset(220, 16), UDim2.new(1, -232, 0, 6), 12, PALETTE.Dim).TextXAlignment = Enum.TextXAlignment.Right
		progressBar(row, entry.progress / math.max(1, entry.goal), entry.done and PALETTE.Good or PALETTE.Gold).Position = UDim2.fromOffset(12, 32)
	end
end

--------------------------------------------------
-- 방해 아이템 그리기
--------------------------------------------------

local function drawSabotage()
	clearList()

	local order = 1
	local note = makeRow(order, 56)
	note.BackgroundTransparency = 0.55
	local noteLabel = label(note,
		"같은 테이블에 앉은 상대만 방해할 수 있습니다. 위험한 자리를 알려주거나 잡기 창을 늘려 주는 물건은 팔지 않습니다.",
		UDim2.new(1, -20, 1, -8), UDim2.fromOffset(12, 4), 12, PALETTE.Dim)
	noteLabel.TextWrapped = true

	-- 상대 고르기
	order += 1
	local targetHeader = makeRow(order, 26)
	targetHeader.BackgroundTransparency = 1
	label(targetHeader, "상대 고르기", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(4, 0), 15, PALETTE.Gold)

	if #sabotageState.opponents == 0 then
		order += 1
		label(makeRow(order, 38), "지금은 방해할 상대가 없습니다. 테이블에 앉아 게임이 시작되면 이름이 나옵니다.",
			UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 13, PALETTE.Dim).TextWrapped = true
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
			local row = makeRow(order, 38)
			local chosen = opponent.userId == selectedTarget
			row.BackgroundColor3 = chosen and PALETTE.Panel or PALETTE.Row
			label(row, opponent.name, UDim2.fromOffset(300, 20), UDim2.fromOffset(12, 9), 14,
				chosen and PALETTE.Gold or PALETTE.Cream)
			local pick = textButton(row, chosen and "고름" or "고르기", UDim2.fromOffset(84, 26),
				UDim2.new(1, -98, 0, 6), chosen and PALETTE.Row or PALETTE.Panel,
				chosen and PALETTE.Gold or PALETTE.Cream)
			pick.Activated:Connect(function()
				selectedTarget = opponent.userId
				drawSabotage()
			end)
		end
	end

	order += 1
	local itemHeader = makeRow(order, 26)
	itemHeader.BackgroundTransparency = 1
	label(itemHeader, "방해 아이템", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(4, 0), 15, PALETTE.Gold)

	local items = {}
	for _, item in ipairs(sabotageState.items) do
		if item.ready or (item.owned or 0) > 0 or IN_STUDIO then
			table.insert(items, item)
		end
	end
	for _, item in ipairs(items) do
		order += 1
		local row = makeRow(order, 62)
		label(row, ("%s  %s"):format(item.icon or "", item.name),
			UDim2.fromOffset(300, 20), UDim2.fromOffset(12, 6), 14, item.color or PALETTE.Cream)
		local detail = label(row, item.detail or item.blurb or "",
			UDim2.new(1, -130, 0, 30), UDim2.fromOffset(12, 26), 11, PALETTE.Dim)
		detail.TextWrapped = true
		detail.TextYAlignment = Enum.TextYAlignment.Top

		local usable = (item.ready or (item.owned or 0)>0) and selectedTarget ~= nil
		local buy = textButton(row, (item.owned or 0)>0 and ("사용 ×%d"):format(item.owned) or (item.ready and ("R$ %d"):format(item.robux) or "준비 중"),
			UDim2.fromOffset(96, 30), UDim2.new(1, -110, 0, 16),
			usable and PALETTE.Robux or PALETTE.Panel,
			usable and Color3.new(1, 1, 1) or PALETTE.Dim)
		buy.Activated:Connect(function()
			if not usable then
				showToast((item.ready or (item.owned or 0)>0) and "먼저 상대를 골라 주세요" or "이 아이템은 아직 준비 중입니다", false)
				return
			end
			sabotageRemote:FireServer("use", item.id, selectedTarget)
		end)
	end
	if #items == 0 then
		order += 1
		label(makeRow(order, 38), "방해 아이템은 아직 준비 중입니다.",
			UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), 13, PALETTE.Dim)
	end
end

--------------------------------------------------
-- 탭 전환
--------------------------------------------------

local function redraw()
	windowCoins.Text = state and ("%s 코인"):format(Utility.comma(state.coins)) or ""
	kindRow.Visible = currentTab == "shop"
	local top=currentTab=="shop" and (window.AbsoluteSize.X<520 and 134 or 100) or 70
    scroller.Position = UDim2.fromOffset(12,top)
    scroller.Size=UDim2.new(1,-24,1,-top-16)

	for kind, button in pairs(kindButtons) do
		button.BackgroundColor3 = (kind == currentKind) and PALETTE.Panel or PALETTE.Row
		button.TextColor3 = (kind == currentKind) and PALETTE.Gold or PALETTE.Cream
	end
	for name, button in pairs(tabButtons) do
		button.BackgroundColor3 = (name == currentTab and window.Visible) and PALETTE.Panel or PALETTE.Row
	end

	if currentTab == "shop" then
		windowTitle.Text = "상점"
		drawShop()
	elseif currentTab == "quest" then
		windowTitle.Text = "퀘스트와 업적"
		drawQuests()
	else
		windowTitle.Text = "방해 아이템"
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
	window.Visible = true
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
		prompt.ActionText = ("R$ %d · 상점에서"):format(entry.robux)
	else
		prompt.ActionText = ("구매 · %s 코인"):format(Utility.comma(entry.price))
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
		coinLabel.Text = ("%s 코인"):format(Utility.comma(state.coins))
		levelLabel.Text = ("Lv.%d  ·  %d승 %d판  ·  최고 %d연승")
			:format(state.level or 1, state.wins or 0, state.games or 0, state.bestStreak or 0)
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

-- Responsive layout keeps text at readable sizes instead of shrinking the whole UI.
local function fitWindow()
 local camera=workspace.CurrentCamera;if not camera then return end
 local width=math.min(620,camera.ViewportSize.X-20)
 window.Size=UDim2.fromOffset(width,math.min(600,camera.ViewportSize.Y-80))
 local columns=width<520 and 3 or 6
 kindRow.Size=UDim2.new(1,-40,0,columns==3 and 60 or 26)
 for i,entry in ipairs(KINDS) do
  local b=kindButtons[entry[1]]
  b.Size=UDim2.new(1/columns,-4,0,26)
  b.Position=UDim2.new(((i-1)%columns)/columns,0,0,math.floor((i-1)/columns)*30)
 end
 redraw()
end
fitWindow()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow) end
local previousCoins=localPlayer:GetAttribute("Coins") or 0
localPlayer:GetAttributeChangedSignal("Coins"):Connect(function()
 local now=localPlayer:GetAttribute("Coins") or 0
 if now>previousCoins then
  local reward=label(launcher,"+"..Utility.comma(now-previousCoins),UDim2.fromOffset(130,24),UDim2.fromOffset(80,-20),18,PALETTE.Good)
  TweenService:Create(reward,TweenInfo.new(1.1),{Position=UDim2.fromOffset(80,-64),TextTransparency=1}):Play()
  game:GetService("Debris"):AddItem(reward,1.2)
 end
 previousCoins=now
end)

-- User's third image is the shop launcher. Preserve its square aspect ratio.
-- An image asset ID is the only owner-side step; JPEGs cannot be embedded as an Image URI.
do
 local brand=require(Shared.ReleaseConfig).Branding
 local shopIcon=Instance.new("ImageButton")
 shopIcon.Name="UserShopImage"
 shopIcon.AnchorPoint=Vector2.new(0,1)
 shopIcon.Position=UDim2.new(0,14,1,UserInputService.TouchEnabled and -108 or -16)
 shopIcon.Size=UDim2.fromOffset(84,84)
 shopIcon.ScaleType=Enum.ScaleType.Fit
 shopIcon.BackgroundColor3=PALETTE.Back
 shopIcon.BorderSizePixel=0
 shopIcon.Image=(tonumber(brand.ShopImage) or 0)>0 and ("rbxassetid://"..brand.ShopImage) or ""
 shopIcon.Selectable=true
 shopIcon.Parent=gui
 corner(shopIcon,12)
 stroke(shopIcon,PALETTE.Gold,2,0.2)
 if shopIcon.Image=="" then
  local fallback=label(shopIcon,"SHOP",UDim2.fromScale(1,1),UDim2.new(),18,PALETTE.Gold)
  fallback.TextXAlignment=Enum.TextXAlignment.Center
 end
 launcher.Position=UDim2.new(0,106,1,UserInputService.TouchEnabled and -108 or -16)
 tabButtons.shop.Visible=false
 tabButtons.quest.Position=UDim2.fromOffset(10,44)
 tabButtons.quest.Size=UDim2.fromOffset(92,24)
 tabButtons.sabotage.Position=UDim2.fromOffset(110,44)
 tabButtons.sabotage.Size=UDim2.fromOffset(92,24)
 -- 내 차례에는 칼 고르는 창이 화면 아래를 쓴다. 작은 화면에서 왼쪽 자리 버튼을 가리지 않도록 잠시 숨긴다.
 task.spawn(function()
  while gui.Parent do
   local picker=playerGui:FindFirstChild("CursedBarrel_KnifePicker")
   local busy=picker~=nil and picker.Enabled
   if shopIcon.Visible==busy then
    shopIcon.Visible=not busy;launcher.Visible=not busy
    -- 내 차례가 오면 열려 있던 상점 창도 닫는다. (칼 고르는 창을 가리지 않게)
    if busy and window.Visible then window.Visible=false;redraw() end
   end
   task.wait(0.25)
  end
 end)
 shopIcon.Activated:Connect(function()
  -- 다른 탭이 열려 있으면 상점으로 바꾸고, 상점이 열려 있으면 닫는다.
  if window.Visible and currentTab=="shop" then window.Visible=false
  else currentTab="shop";window.Visible=true;shopRequest:FireServer("sync") end
  redraw()
 end)
end
