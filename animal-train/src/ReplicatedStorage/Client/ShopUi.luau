-- 11단계 : 업그레이드 가판대 위에 뜨는 가격표 (사람마다 다르게 보입니다).
-- 가격과 단계는 내 상태를 기준으로 그리므로 각 플레이어 화면에서만 만듭니다.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local ShopUi = {}

local tags = {} -- [kind] = { billboard, number, dots = {}, shakeUntil }

local function buildTag(pad, kind)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PriceTag_" .. kind
	billboard.Size = UDim2.fromScale(6.5, 4.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7.4, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 160
	billboard.Adornee = pad
	billboard.Parent = pad

	local panel = UiKit.panel(billboard, "Panel", Color3.fromRGB(255, 252, 240))
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundTransparency = 0.05

	local priceRow = UiKit.frame(panel, "Price")
	priceRow.Size = UDim2.fromScale(0.9, 0.56)
	priceRow.Position = UDim2.fromScale(0.05, 0.04)

	local star = UiKit.viewport(priceRow, ModelFactory.buildStar(), "Star")
	star.Size = UDim2.fromScale(0.38, 1)

	local number = UiKit.number(priceRow, "0")
	number.Size = UDim2.fromScale(0.58, 0.9)
	number.Position = UDim2.fromScale(0.4, 0.05)
	number.TextColor3 = Color3.fromRGB(255, 176, 48)
	number.TextXAlignment = Enum.TextXAlignment.Left

	local dotRow = UiKit.frame(panel, "Dots")
	dotRow.Size = UDim2.fromScale(0.86, 0.26)
	dotRow.Position = UDim2.fromScale(0.07, 0.64)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.04, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dotRow

	local dots = {}
	for index = 1, Rules.maxLevel(kind) do
		local dot = UiKit.dot(dotRow, false)
		dot.Size = UDim2.fromScale(0.16, 0.8)
		dot.LayoutOrder = index
		UiKit.aspect(dot, 1)
		table.insert(dots, dot)
	end

	tags[kind] = { billboard = billboard, panel = panel, number = number, dots = dots, shakeUntil = 0 }
end

function ShopUi.init()
	task.spawn(function()
		local world = workspace:WaitForChild("World", 30)
		if not world then
			return
		end
		local island = world:WaitForChild(Config.StartIsland, 30)
		local shop = island and island:WaitForChild("Shop", 30)
		if not shop then
			return
		end
		for _, pad in ipairs(shop:GetChildren()) do
			local kind = pad:GetAttribute("UpgradeKind")
			if kind then
				buildTag(pad, kind)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, tag in pairs(tags) do
			local star = tag.panel:FindFirstChild("Price") and tag.panel.Price:FindFirstChild("Star")
			if star and star:IsA("ViewportFrame") then
				UiKit.aimViewport(star, now * 0.9)
			end
			if now < tag.shakeUntil then
				tag.panel.Rotation = math.sin(now * 40) * 9
			elseif tag.panel.Rotation ~= 0 then
				tag.panel.Rotation = 0
			end
		end
	end)
end

function ShopUi.update(state)
	if not state then
		return
	end
	for kind, tag in pairs(tags) do
		local level = (state.upgrades and state.upgrades[kind]) or 0
		local price = Rules.nextPrice(kind, level)
		if price then
			tag.number.Text = tostring(price)
			local affordable = (state.stars or 0) >= price
			tag.number.TextColor3 = affordable and Color3.fromRGB(96, 200, 120) or Color3.fromRGB(255, 176, 48)
			tag.number.Visible = true
		else
			tag.number.Text = ""
			tag.number.Visible = false
		end
		for index, dot in ipairs(tag.dots) do
			local on = index <= level
			dot.BackgroundColor3 = on and Color3.fromRGB(255, 225, 110) or Color3.fromRGB(255, 255, 255)
			dot.BackgroundTransparency = on and 0 or 0.55
		end
	end
end

-- 별이 모자랄 때 가격표가 흔들립니다
function ShopUi.shake(kind)
	local tag = tags[kind]
	if tag then
		tag.shakeUntil = os.clock() + 0.45
	end
end

return ShopUi
