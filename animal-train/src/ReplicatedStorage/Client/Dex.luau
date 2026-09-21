-- 9단계 : 동물 도감. 데려온 동물은 컬러, 아직 못 만난 동물은 검은 실루엣.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local Dex = {}

local bookButton
local window
local slots = {} -- [species] = { viewport = ViewportFrame, unlocked = boolean? }
local popup
local popupHideAt = 0
local isOpen = false

local islandDotColor = {
	Meadow = Color3.fromRGB(150, 216, 138),
	Snow = Color3.fromRGB(198, 226, 245),
}

--=========================================================
-- 오른쪽 책 버튼
--=========================================================
local function buildBookButton(parent)
	bookButton = UiKit.panel(parent, "DexButton", Color3.fromRGB(196, 142, 96))
	bookButton.AnchorPoint = Vector2.new(1, 0.5)
	bookButton.Position = UDim2.new(0.975, 0, 0.42, 0)
	bookButton.Size = UDim2.new(0.1, 0, 0.14, 0)
	bookButton.BackgroundTransparency = 0
	UiKit.aspect(bookButton, 0.86)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(62, 72)
	constraint.MaxSize = Vector2.new(120, 140)
	constraint.Parent = bookButton

	local pages = UiKit.frame(bookButton, "Pages")
	pages.BackgroundTransparency = 0
	pages.BackgroundColor3 = Color3.fromRGB(255, 250, 238)
	pages.Size = UDim2.fromScale(0.72, 0.78)
	pages.Position = UDim2.fromScale(0.2, 0.11)
	UiKit.corner(pages, 0.12)

	local spine = UiKit.frame(bookButton, "Spine")
	spine.BackgroundTransparency = 0
	spine.BackgroundColor3 = Color3.fromRGB(160, 108, 68)
	spine.Size = UDim2.fromScale(0.16, 0.9)
	spine.Position = UDim2.fromScale(0.04, 0.05)
	UiKit.corner(spine, 0.3)

	local face = UiKit.viewport(pages, ModelFactory.buildAnimal("Chick"), "Face")
	face.Size = UDim2.fromScale(1, 1)

	local hit = UiKit.hitButton(bookButton)
	hit.MouseButton1Click:Connect(function()
		Dex.toggle()
	end)
	return bookButton
end

--=========================================================
-- 도감 창
--=========================================================
local function buildSlot(parent, species, order)
	local info = Config.Animals[species]
	local slot = UiKit.panel(parent, "Slot_" .. species, Color3.fromRGB(255, 252, 245))
	slot.LayoutOrder = order
	slot.Size = UDim2.fromScale(0.3, 0.86)
	slot.BackgroundTransparency = 0.05

	local viewport = UiKit.viewport(slot, nil, "Animal")
	viewport.Size = UDim2.fromScale(0.9, 0.7)
	viewport.Position = UDim2.fromScale(0.05, 0.03)

	local rewardRow = UiKit.frame(slot, "Reward")
	rewardRow.Size = UDim2.fromScale(0.9, 0.24)
	rewardRow.Position = UDim2.fromScale(0.05, 0.73)

	local starIcon = UiKit.viewport(rewardRow, ModelFactory.buildStar(), "Star")
	starIcon.Size = UDim2.fromScale(0.4, 1)

	local number = UiKit.number(rewardRow, tostring(info and info.Reward or 1))
	number.Size = UDim2.fromScale(0.55, 0.9)
	number.Position = UDim2.fromScale(0.42, 0.05)
	number.TextColor3 = Color3.fromRGB(255, 188, 60)
	number.TextXAlignment = Enum.TextXAlignment.Left

	slots[species] = { viewport = viewport, unlocked = nil }
	return slot
end

local function buildWindow(parent)
	window = UiKit.frame(parent, "DexWindow")
	window.Size = UDim2.fromScale(1, 1)
	window.Visible = false
	window.ZIndex = 30

	local backdrop = UiKit.frame(window, "Backdrop")
	backdrop.BackgroundTransparency = 0.45
	backdrop.BackgroundColor3 = Color3.fromRGB(40, 44, 62)
	backdrop.Size = UDim2.fromScale(1, 1)
	local backdropHit = UiKit.hitButton(backdrop)
	backdropHit.ZIndex = 1
	backdropHit.MouseButton1Click:Connect(function()
		Dex.close()
	end)

	local panel = UiKit.panel(window, "Panel", Color3.fromRGB(255, 249, 234))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.86, 0.72)
	panel.BackgroundTransparency = 0
	panel.ZIndex = 5

	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(900, 620)
	constraint.Parent = panel

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0.03, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	-- 섬마다 한 줄
	for order, islandKey in ipairs(Config.IslandOrder) do
		local row = UiKit.frame(panel, "Row_" .. islandKey)
		row.Size = UDim2.fromScale(0.94, 0.4)
		row.LayoutOrder = order

		local dot = UiKit.frame(row, "IslandDot")
		dot.BackgroundTransparency = 0
		dot.BackgroundColor3 = islandDotColor[islandKey] or Color3.fromRGB(220, 220, 220)
		dot.Size = UDim2.fromScale(0.05, 0.16)
		dot.Position = UDim2.fromScale(0.0, 0.42)
		UiKit.corner(dot, 1)
		UiKit.aspect(dot, 1)

		local holder = UiKit.frame(row, "Slots")
		holder.Size = UDim2.fromScale(0.92, 1)
		holder.Position = UDim2.fromScale(0.07, 0)

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.Padding = UDim.new(0.02, 0)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = holder

		for index, species in ipairs(Config.DexOrder[islandKey] or {}) do
			buildSlot(holder, species, index)
		end
	end

	-- 닫기 버튼 (X 모양)
	local close = UiKit.panel(panel, "Close", Color3.fromRGB(255, 150, 150))
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.fromScale(0.99, 0.02)
	close.Size = UDim2.fromScale(0.09, 0.12)
	close.BackgroundTransparency = 0
	close.ZIndex = 10
	UiKit.aspect(close, 1)
	for _, rotation in ipairs({ 45, -45 }) do
		local bar = UiKit.frame(close, "Bar")
		bar.BackgroundTransparency = 0
		bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(0.62, 0.16)
		bar.Rotation = rotation
		UiKit.corner(bar, 0.5)
	end
	local closeHit = UiKit.hitButton(close)
	closeHit.MouseButton1Click:Connect(function()
		Dex.close()
	end)
end

--=========================================================
-- 새 동물 등장 연출
--=========================================================
local function buildPopup(parent)
	popup = UiKit.panel(parent, "NewAnimal", Color3.fromRGB(255, 252, 240))
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.44)
	popup.Size = UDim2.fromScale(0.42, 0.42)
	popup.BackgroundTransparency = 0.05
	popup.Visible = false
	popup.ZIndex = 40
	UiKit.aspect(popup, 0.9)

	local rays = UiKit.frame(popup, "Rays")
	rays.Size = UDim2.fromScale(1.4, 1.4)
	rays.Position = UDim2.fromScale(-0.2, -0.2)
	rays.ZIndex = -1
	for index = 1, 8 do
		local ray = UiKit.frame(rays, "Ray" .. index)
		ray.BackgroundTransparency = 0.25
		ray.BackgroundColor3 = Color3.fromRGB(255, 228, 140)
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(1.3, 0.09)
		ray.Rotation = index * 22.5
		UiKit.corner(ray, 0.5)
	end

	local viewport = UiKit.viewport(popup, nil, "Animal")
	viewport.Size = UDim2.fromScale(0.86, 0.68)
	viewport.Position = UDim2.fromScale(0.07, 0.04)

	local label = Instance.new("TextLabel")
	label.Name = "NewText"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "NEW!"
	label.TextColor3 = Color3.fromRGB(255, 120, 150)
	label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Size = UDim2.fromScale(0.7, 0.22)
	label.Position = UDim2.fromScale(0.15, 0.73)
	label.Rotation = -8
	label.Parent = popup
end

--=========================================================
-- 밖에서 쓰는 함수들
--=========================================================
function Dex.init(parent)
	buildBookButton(parent)
	buildWindow(parent)
	buildPopup(parent)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if popup and popup.Visible then
			local viewport = popup:FindFirstChild("Animal")
			if viewport and viewport:IsA("ViewportFrame") then
				UiKit.aimViewport(viewport, now)
			end
			local rays = popup:FindFirstChild("Rays")
			if rays then
				rays.Rotation = now * 20
			end
			if now >= popupHideAt then
				popup.Visible = false
			end
		end
		if isOpen then
			for _, slot in pairs(slots) do
				UiKit.aimViewport(slot.viewport, now * 0.6)
			end
		end
	end)
end

function Dex.update(state)
	if not state then
		return
	end
	for species, slot in pairs(slots) do
		local unlocked = state.dex and state.dex[species] == true
		if slot.unlocked ~= unlocked then
			slot.unlocked = unlocked
			local model = ModelFactory.buildAnimal(species)
			if model then
				if not unlocked then
					UiKit.silhouette(model)
				end
				UiKit.setViewportModel(slot.viewport, model)
			end
		end
	end
end

function Dex.toggle()
	if isOpen then
		Dex.close()
	else
		Dex.open()
	end
end

function Dex.open()
	isOpen = true
	window.Visible = true
	local panel = window:FindFirstChild("Panel")
	if panel then
		UiKit.pop(panel, 0.12)
	end
end

function Dex.close()
	isOpen = false
	window.Visible = false
end

function Dex.showNew(species)
	if not popup then
		return
	end
	local model = ModelFactory.buildAnimal(species)
	if not model then
		return
	end
	local viewport = popup:FindFirstChild("Animal")
	if viewport and viewport:IsA("ViewportFrame") then
		UiKit.setViewportModel(viewport, model)
	end
	popup.Visible = true
	popupHideAt = os.clock() + 2.6
	UiKit.pop(popup, 0.35)
end

return Dex
