--[==[
  졸졸 동물 기차 - 설치 스크립트 (place 파일을 쓰지 않고 넣고 싶을 때)

  쓰는 방법
    1) Roblox Studio 에서 게임을 엽니다.
    2) VIEW 탭 → Command Bar 를 켭니다.
    3) 이 파일 전체를 복사해서 명령 바에 붙여넣고 Enter 를 누릅니다.
    4) 출력 창에 "설치 완료" 가 나오면 Play 를 누르세요.
]==]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function folder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA("Folder") then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = name
		existing.Parent = parent
	end
	return existing
end

local function script_(parent, class, name, source)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local made = Instance.new(class)
	made.Name = name
	made.Source = source
	made.Parent = parent
	return made
end

local roots = {
	ReplicatedStorage = ReplicatedStorage,
	ServerScriptService = ServerScriptService,
	StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts"),
}


script_(folder(roots.ReplicatedStorage, "Client"), "ModuleScript", "Arrow", [==[
-- 6단계 : 글자 없는 안내. 3D 공간에 통통 튀는 큰 화살표를 띄웁니다.
-- 기차가 비었으면 가장 가까운 동물, 3마리 이상이면 농장 입구를 가리킵니다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local Arrow = {}

local localPlayer = Players.LocalPlayer
local billboard
local arrowFrame
local currentState = nil
local nextScan = 0
local nextPath = 0

local function rootPosition()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function currentIslandKey(position)
	local bestKey, bestDistance = Config.StartIsland, math.huge
	for key, island in pairs(Config.Islands) do
		local flat = Vector3.new(island.Center.X - position.X, 0, island.Center.Z - position.Z)
		if flat.Magnitude < bestDistance then
			bestDistance = flat.Magnitude
			bestKey = key
		end
	end
	return bestKey
end

local function deliveryZone(islandKey)
	local world = workspace:FindFirstChild("World")
	local island = world and world:FindFirstChild(islandKey)
	local farm = island and island:FindFirstChild("Farm")
	return farm and farm:FindFirstChild("DeliveryZone")
end

local function nearestWildAnimal(position, islandKey)
	local folder = workspace:FindFirstChild("Animals")
	if not folder then
		return nil
	end
	local best, bestDistance = nil, 500
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("Owned") == false then
			if model:GetAttribute("Island") == islandKey then
				local part = model.PrimaryPart
				if part then
					local distance = (part.Position - position).Magnitude
					if distance < bestDistance then
						bestDistance = distance
						best = part
					end
				end
			end
		end
	end
	return best
end

--=========================================================
-- 화살표 그리기 (도형만 사용)
--=========================================================
local function buildArrow(parent)
	billboard = Instance.new("BillboardGui")
	billboard.Name = "HintArrow"
	billboard.Size = UDim2.fromScale(7, 7)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 400
	billboard.Enabled = false
	-- 다시 태어나도 화살표가 사라지지 않게
	pcall(function()
		billboard.ResetOnSpawn = false
	end)
	billboard.Parent = parent

	arrowFrame = UiKit.frame(billboard, "Arrow")
	arrowFrame.Size = UDim2.fromScale(1, 1)

	local function bar(name, size, position, rotation)
		local piece = UiKit.frame(arrowFrame, name)
		piece.BackgroundTransparency = 0
		piece.BackgroundColor3 = Color3.fromRGB(255, 214, 80)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = size
		piece.Position = position
		piece.Rotation = rotation
		UiKit.corner(piece, 0.45)
		UiKit.stroke(piece, Color3.fromRGB(255, 255, 255), 3)
		return piece
	end

	bar("Stem", UDim2.fromScale(0.22, 0.44), UDim2.fromScale(0.5, 0.26), 0)
	bar("WingL", UDim2.fromScale(0.62, 0.22), UDim2.fromScale(0.36, 0.63), 45)
	bar("WingR", UDim2.fromScale(0.62, 0.22), UDim2.fromScale(0.64, 0.63), -45)
end

--=========================================================
-- 가득 찼을 때 농장까지 빛나는 발자국 (6단계)
--=========================================================
function Arrow.showFootpath()
	local now = os.clock()
	if now < nextPath then
		return
	end
	nextPath = now + 6

	local position = rootPosition()
	if not position then
		return
	end
	local zone = deliveryZone(currentIslandKey(position))
	if not zone then
		return
	end

	local steps = 10
	for index = 1, steps do
		local alpha = index / (steps + 1)
		local point = position:Lerp(zone.Position, alpha)
		local step = Instance.new("Part")
		step.Name = "GuideStep"
		step.Shape = Enum.PartType.Cylinder
		step.Size = Vector3.new(0.25, 2.6, 2.6)
		step.CFrame = CFrame.new(point.X, 0.4, point.Z) * CFrame.Angles(0, 0, math.rad(90))
		step.Anchored = true
		step.CanCollide = false
		step.CanQuery = false
		step.CanTouch = false
		step.CastShadow = false
		step.Material = Enum.Material.Neon
		step.Color = Color3.fromRGB(255, 232, 140)
		step.Transparency = 1
		step.Parent = workspace

		task.delay(index * 0.07, function()
			if not step.Parent then
				return
			end
			TweenService:Create(step, TweenInfo.new(0.25), { Transparency = 0.25 }):Play()
			task.delay(1.4, function()
				if step.Parent then
					TweenService:Create(step, TweenInfo.new(0.8), { Transparency = 1 }):Play()
					task.delay(0.9, function()
						step:Destroy()
					end)
				end
			end)
		end)
	end
end

--=========================================================
function Arrow.init(parent)
	buildArrow(parent)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()

		if now >= nextScan then
			nextScan = now + 0.25
			local position = rootPosition()
			if not position or not currentState then
				billboard.Enabled = false
			else
				local islandKey = currentIslandKey(position)
				local train = currentState.train or 0
				local maxTrain = currentState.maxTrain or Config.Train.BaseMaxLength
				local adornee

				if train >= 3 or (maxTrain > 0 and train >= maxTrain) then
					adornee = deliveryZone(islandKey)
				else
					adornee = nearestWildAnimal(position, islandKey)
					if not adornee and train > 0 then
						adornee = deliveryZone(islandKey)
					end
				end

				if adornee then
					billboard.Adornee = adornee
					billboard.Enabled = true
				else
					billboard.Enabled = false
				end
			end
		end

		if billboard.Enabled then
			local bounce = math.abs(math.sin(now * 3.2)) * 1.6
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 5.2 + bounce, 0)
			arrowFrame.Rotation = math.sin(now * 2) * 5
		end
	end)
end

function Arrow.update(state)
	currentState = state
end

return Arrow
]==])

script_(folder(roots.ReplicatedStorage, "Client"), "ModuleScript", "ClientEffects", [==[
-- 서버가 보낸 연출 신호를 소리와 화면 연출로 바꿉니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))

local Client = script.Parent
local Hud = require(Client:WaitForChild("Hud"))
local Dex = require(Client:WaitForChild("Dex"))
local Arrow = require(Client:WaitForChild("Arrow"))
local ShopUi = require(Client:WaitForChild("ShopUi"))
local GateClient = require(Client:WaitForChild("GateClient"))

local ClientEffects = {}

function ClientEffects.handle(kind, payload)
	payload = payload or {}

	if kind == "full" then
		Sounds.play("Full")
		Hud.flashFull()
		Arrow.showFootpath()
	elseif kind == "deliver" then
		Sounds.play("StarUp", 0.12)
	elseif kind == "newAnimal" then
		Sounds.playTimes("NewAnimal", 3, 0.12)
		Dex.showNew(payload.species)
	elseif kind == "buyOk" then
		Sounds.play("BuyOk")
	elseif kind == "buyFail" then
		Sounds.play("BuyFail")
		ShopUi.shake(payload.kind)
	elseif kind == "buyMax" then
		Sounds.play("Click")
	elseif kind == "gateOpen" then
		Sounds.playTimes("Unlock", 2, 0.2)
		GateClient.celebrate()
	elseif kind == "gateLocked" then
		Sounds.play("BuyFail")
	elseif kind == "fell" then
		Sounds.play("Splash")
	elseif kind == "rareAppeared" then
		Sounds.play("ChirpAlt", 0.1)
	end
end

return ClientEffects
]==])

script_(folder(roots.ReplicatedStorage, "Client"), "ModuleScript", "Dex", [==[
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
]==])

script_(folder(roots.ReplicatedStorage, "Client"), "ModuleScript", "GateClient", [==[
-- 7단계 : 별 문의 "빛나는 막"은 사람마다 따로 보여야 하므로
-- 각자의 화면(클라이언트)에서 만듭니다. 문을 연 사람 화면에서만 사라집니다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))

local GateClient = {}

local LOCKED_ISLAND = "Snow"
local curtain
local sparkles
local opened = false

local function buildCurtain()
	local bridge = Config.Bridge
	curtain = Instance.new("Part")
	curtain.Name = "StarGateCurtain"
	curtain.Size = Vector3.new(bridge.GateWidth, bridge.GateHeight, 0.6)
	curtain.CFrame = CFrame.new(0, bridge.GateHeight / 2, bridge.GateZ - 1)
	curtain.Anchored = true
	curtain.CanCollide = false
	curtain.CanQuery = false
	curtain.CanTouch = false
	curtain.CastShadow = false
	curtain.Material = Enum.Material.Neon
	curtain.Color = Color3.fromRGB(190, 224, 255)
	curtain.Transparency = 0.62
	curtain.Parent = workspace

	sparkles = ModelFactory.addSparkles(curtain, Color3.fromRGB(255, 240, 180), 22)
	sparkles.SpreadAngle = Vector2.new(20, 20)
	sparkles.Speed = NumberRange.new(1, 3)
end

local function openCurtain()
	if not curtain or opened then
		return
	end
	opened = true
	if sparkles then
		sparkles.Rate = 0
	end
	TweenService:Create(curtain, TweenInfo.new(0.9), { Transparency = 1, Size = curtain.Size * 1.2 }):Play()
	task.delay(1.1, function()
		if curtain then
			curtain:Destroy()
			curtain = nil
		end
	end)
end

function GateClient.init()
	-- 막이는 첫 상태를 받은 뒤에 만듭니다.
	-- (이미 문을 연 사람 화면에는 아예 나타나지 않게)
end

function GateClient.update(state)
	if not state or not state.islands then
		return
	end
	if state.islands[LOCKED_ISLAND] then
		if curtain then
			openCurtain()
		end
		opened = true
		return
	end
	if not curtain and not opened then
		buildCurtain()
	end
end

-- 문이 열리는 순간 축하 폭죽 (내 화면)
function GateClient.celebrate()
	local bridge = Config.Bridge
	local center = Vector3.new(0, bridge.GateHeight * 0.7, bridge.GateZ)
	for index = 1, 5 do
		task.delay((index - 1) * 0.14, function()
			ModelFactory.burst(
				center + Vector3.new(math.random(-9, 9), math.random(0, 8), math.random(-3, 3)),
				Color3.fromHSV(math.random(), 0.5, 1),
				28
			)
		end)
	end
	openCurtain()
end

return GateClient
]==])

script_(folder(roots.ReplicatedStorage, "Client"), "ModuleScript", "Hud", [==[
-- 6단계 : 글 없이 알아보는 화면.
-- 왼쪽 위 = 별 개수, 위 가운데 = 기차 칸 (●●●○○○○○○○)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local Hud = {}

local starPanel, starNumber, starViewport
local trainBar, pipHolder, glow
local pips = {}
local shownStars = nil
local shownMax = 0
local shownTrain = 0
local flashUntil = 0

--=========================================================
-- 별 패널
--=========================================================
local function buildStarPanel(parent)
	starPanel = UiKit.panel(parent, "StarPanel", Color3.fromRGB(255, 252, 240))
	starPanel.AnchorPoint = Vector2.new(0, 0)
	starPanel.Position = UDim2.new(0.02, 0, 0.055, 0)
	starPanel.Size = UDim2.new(0.2, 0, 0.1, 0)
	starPanel.BackgroundTransparency = 0.08
	UiKit.aspect(starPanel, 2.1)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(120, 56)
	sizeConstraint.MaxSize = Vector2.new(260, 120)
	sizeConstraint.Parent = starPanel

	starViewport = UiKit.viewport(starPanel, ModelFactory.buildStar(), "StarIcon")
	starViewport.Size = UDim2.fromScale(0.42, 1)
	starViewport.Position = UDim2.fromScale(0.02, 0)

	starNumber = UiKit.number(starPanel, "0")
	starNumber.Size = UDim2.fromScale(0.52, 0.72)
	starNumber.Position = UDim2.fromScale(0.44, 0.14)
	starNumber.TextXAlignment = Enum.TextXAlignment.Left
	starNumber.TextColor3 = Color3.fromRGB(255, 188, 60)
	starNumber.TextStrokeColor3 = Color3.fromRGB(120, 82, 20)
end

--=========================================================
-- 기차 칸 표시
--=========================================================
local function layoutPips()
	if not pipHolder then
		return
	end
	local count = #pips
	if count == 0 then
		return
	end
	local area = pipHolder.AbsoluteSize
	if area.Y <= 0 then
		return
	end
	local gap = 4
	local size = math.min(area.Y, (area.X - gap * (count - 1)) / count)
	size = math.max(size, 8)
	for _, pip in ipairs(pips) do
		pip.Size = UDim2.fromOffset(size, size)
		pip:SetAttribute("BaseSize", pip.Size)
	end
end

local function buildPips(count)
	for _, pip in ipairs(pips) do
		pip:Destroy()
	end
	pips = {}
	for index = 1, count do
		local pip = UiKit.dot(pipHolder, false)
		pip.LayoutOrder = index
		table.insert(pips, pip)
	end
	layoutPips()
end

local function buildTrainBar(parent)
	trainBar = UiKit.frame(parent, "TrainBar")
	trainBar.AnchorPoint = Vector2.new(0.5, 0)
	trainBar.Position = UDim2.new(0.5, 0, 0.018, 0)
	trainBar.Size = UDim2.new(0.44, 0, 0.055, 0)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(160, 22)
	sizeConstraint.MaxSize = Vector2.new(620, 56)
	sizeConstraint.Parent = trainBar

	glow = UiKit.frame(trainBar, "Glow")
	glow.BackgroundColor3 = Color3.fromRGB(255, 240, 160)
	glow.BackgroundTransparency = 1
	glow.Size = UDim2.fromScale(1.06, 1.5)
	glow.Position = UDim2.fromScale(-0.03, -0.25)
	UiKit.corner(glow, 1)

	pipHolder = UiKit.frame(trainBar, "Pips")
	pipHolder.Size = UDim2.fromScale(1, 1)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pipHolder

	pipHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutPips)
end

--=========================================================
-- 밖에서 쓰는 함수들
--=========================================================
function Hud.init(parent)
	buildStarPanel(parent)
	buildTrainBar(parent)
	buildPips(Config.Train.BaseMaxLength)
	shownMax = Config.Train.BaseMaxLength

	-- 별 아이콘이 천천히 돕니다
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if starViewport then
			UiKit.aimViewport(starViewport, now * 0.8)
		end
		if glow then
			if now < flashUntil then
				glow.BackgroundTransparency = 0.35 + math.abs(math.sin(now * 8)) * 0.5
			elseif glow.BackgroundTransparency < 1 then
				glow.BackgroundTransparency = 1
			end
		end
	end)
end

function Hud.update(state)
	if not state then
		return
	end

	-- 별 개수 (늘면 통통 튀기)
	if starNumber then
		starNumber.Text = tostring(state.stars)
		if shownStars ~= nil and state.stars > shownStars then
			UiKit.pop(starPanel, 0.18)
			if starViewport then
				UiKit.pop(starViewport, 0.3)
			end
		end
		shownStars = state.stars
	end

	-- 칸 개수가 바뀌면 다시 그립니다 (기차 업그레이드)
	local maxTrain = state.maxTrain or Config.Train.BaseMaxLength
	if maxTrain ~= shownMax then
		shownMax = maxTrain
		buildPips(maxTrain)
		shownTrain = -1
	end

	local filled = math.clamp(state.train or 0, 0, maxTrain)
	if filled ~= shownTrain then
		for index, pip in ipairs(pips) do
			local on = index <= filled
			pip.BackgroundColor3 = on and Color3.fromRGB(255, 225, 110) or Color3.fromRGB(255, 255, 255)
			pip.BackgroundTransparency = on and 0 or 0.55
			local face = pip:FindFirstChild("EyeL")
			if on and not face then
				-- 모은 칸은 병아리 얼굴로 바꿉니다
				local eyeLeft = UiKit.frame(pip, "EyeL")
				eyeLeft.BackgroundTransparency = 0
				eyeLeft.BackgroundColor3 = Color3.fromRGB(60, 54, 66)
				eyeLeft.Size = UDim2.fromScale(0.17, 0.17)
				eyeLeft.Position = UDim2.fromScale(0.28, 0.34)
				UiKit.corner(eyeLeft, 1)

				local eyeRight = eyeLeft:Clone()
				eyeRight.Name = "EyeR"
				eyeRight.Position = UDim2.fromScale(0.55, 0.34)
				eyeRight.Parent = pip

				local beak = UiKit.frame(pip, "Beak")
				beak.BackgroundTransparency = 0
				beak.BackgroundColor3 = Color3.fromRGB(255, 163, 71)
				beak.Size = UDim2.fromScale(0.22, 0.15)
				beak.Position = UDim2.fromScale(0.39, 0.6)
				UiKit.corner(beak, 0.4)
			elseif not on and face then
				for _, name in ipairs({ "EyeL", "EyeR", "Beak" }) do
					local item = pip:FindFirstChild(name)
					if item then
						item:Destroy()
					end
				end
			end
			if on and index > shownTrain and shownTrain >= 0 then
				UiKit.pop(pip, 0.45)
			end
		end
		shownTrain = filled
	end

	if filled >= maxTrain and maxTrain > 0 then
		Hud.flashFull()
	end
end

-- 기차가 가득 차면 칸 표시가 반짝입니다 (6단계)
function Hud.flashFull()
	flashUntil = os.clock() + 2.5
end

return Hud
]==])

script_(folder(roots.ReplicatedStorage, "Client"), "ModuleScript", "Music", [==[
-- 12단계 : 배경 음악과 스피커(끄기) 버튼.
-- Config.Music.AssetId 가 비어 있으면 버튼을 만들지 않습니다.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local Music = {}

local sound
local button
local slash
local enabled = true
local ready = false

local function setEnabled(value)
	enabled = value
	if sound then
		sound.Volume = value and Config.Music.Volume or 0
		if value and not sound.IsPlaying then
			pcall(function()
				sound:Play()
			end)
		end
	end
	if slash then
		slash.Visible = not value
	end
end

local function buildButton(parent)
	button = UiKit.panel(parent, "MusicButton", Color3.fromRGB(255, 252, 240))
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(0.975, 0, 0.055, 0)
	button.Size = UDim2.new(0.08, 0, 0.1, 0)
	button.BackgroundTransparency = 0.05
	UiKit.aspect(button, 1)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(54, 54)
	constraint.MaxSize = Vector2.new(96, 96)
	constraint.Parent = button

	-- 스피커 몸통
	local body = UiKit.frame(button, "Body")
	body.BackgroundTransparency = 0
	body.BackgroundColor3 = Color3.fromRGB(96, 104, 132)
	body.Size = UDim2.fromScale(0.2, 0.3)
	body.Position = UDim2.fromScale(0.22, 0.35)
	UiKit.corner(body, 0.25)

	local cone = UiKit.frame(button, "Cone")
	cone.BackgroundTransparency = 0
	cone.BackgroundColor3 = Color3.fromRGB(96, 104, 132)
	cone.Size = UDim2.fromScale(0.26, 0.56)
	cone.Position = UDim2.fromScale(0.36, 0.22)
	UiKit.corner(cone, 0.3)

	-- 소리 물결 2개
	for index = 1, 2 do
		local wave = UiKit.frame(button, "Wave" .. index)
		wave.BackgroundTransparency = 0
		wave.BackgroundColor3 = Color3.fromRGB(255, 196, 96)
		wave.Size = UDim2.fromScale(0.07, 0.16 + index * 0.12)
		wave.Position = UDim2.fromScale(0.64 + (index - 1) * 0.12, 0.5 - (0.08 + index * 0.06))
		UiKit.corner(wave, 0.5)
	end

	-- 꺼졌을 때 사선
	slash = UiKit.frame(button, "Slash")
	slash.BackgroundTransparency = 0
	slash.BackgroundColor3 = Color3.fromRGB(255, 110, 110)
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.fromScale(0.5, 0.5)
	slash.Size = UDim2.fromScale(0.95, 0.12)
	slash.Rotation = -35
	slash.Visible = false
	UiKit.corner(slash, 0.5)

	local hit = UiKit.hitButton(button)
	hit.MouseButton1Click:Connect(function()
		setEnabled(not enabled)
		UiKit.pop(button, 0.2)
		Net.event(Config.Remotes.SetPref):FireServer("music", enabled)
	end)
end

function Music.init(parent)
	if Config.Music.AssetId == "" then
		print("[음악] Config.Music.AssetId 가 비어 있어 음악을 켜지 않았습니다.")
		print("[음악] 로블록스에서 사용 허용된 음악 ID 를 Config 에 넣으면 스피커 버튼이 생깁니다.")
		return
	end

	sound = Instance.new("Sound")
	sound.Name = "BackgroundMusic"
	sound.SoundId = Config.Music.AssetId
	sound.Looped = true
	sound.Volume = Config.Music.Volume
	sound.Parent = SoundService
	pcall(function()
		sound:Play()
	end)

	buildButton(parent)
	ready = true
end

function Music.update(state)
	if not ready or not state then
		return
	end
	local want = state.music ~= false
	if want ~= enabled then
		setEnabled(want)
	end
end

return Music
]==])

script_(folder(roots.ReplicatedStorage, "Client"), "ModuleScript", "ShopUi", [==[
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
]==])

script_(folder(roots.ReplicatedStorage, "Client"), "ModuleScript", "UiKit", [==[
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
]==])

script_(folder(roots.ReplicatedStorage, "Shared"), "ModuleScript", "Config", [==[
--!strict
-- 졸졸 동물 기차 / 공용 설정값
-- 게임의 모든 숫자값은 이 파일 한 곳에서만 바꿉니다.

local Config = {}

--=========================================================
-- 저장 (8단계)
--=========================================================
Config.Data = {
	StoreName = "AnimalTrain_Player", -- DataStore 이름
	Version = 2, -- 저장 구조 버전 (구조가 바뀌면 올립니다)
	AutoSaveInterval = 120, -- 자동 저장 간격(초)
	MaxRetries = 4, -- 저장/불러오기 재시도 횟수
	RetryWait = 2, -- 재시도 대기 시간(초, 실패할수록 2배)
}

--=========================================================
-- 기차 (4단계)
--=========================================================
Config.Train = {
	BaseMaxLength = 10, -- 기차 최대 길이 (기본)
	Spacing = 4, -- 앞 동물과의 간격 (스터드)
	Smoothness = 9, -- 클수록 빠르게 따라붙음 (부드러움)
	TrailStep = 0.4, -- 발자취를 남기는 최소 거리
	TrailExtra = 10, -- 발자취를 여유있게 보관할 길이
	HopHeight = 0.55, -- 폴짝 뛰는 높이
	HopSpeed = 11, -- 폴짝 빈도
	RootHeight = 3, -- 플레이어 허리(HumanoidRootPart)가 땅에서 떠 있는 높이
	TurnSpeed = 9, -- 몸 방향이 도는 속도
	SnapDistance = 30, -- 이만큼 멀어지면(순간이동) 기차를 즉시 붙임
}

--=========================================================
-- 동물 줍기 (4·11단계)
--=========================================================
Config.Pickup = {
	BaseRadius = 4.2, -- 닿았다고 보는 거리
	MagnetBonusPerLevel = 3.5, -- 자석 업그레이드 1단계당 늘어나는 거리
	CheckInterval = 0.1, -- 줍기 검사 간격(초)
}

--=========================================================
-- 플레이어
--=========================================================
Config.Player = {
	BaseWalkSpeed = 16, -- 로블록스 기본값
	SpeedPerLevel = 3, -- 신발 업그레이드 1단계당 속도 증가
	JumpPower = 50,
}

--=========================================================
-- 동물 종류 (3·7·9단계)
--   Reward   : 배달 1마리당 받는 별
--   Count    : 섬에 돌아다닐 목표 마리 수
--   Rare     : 희귀 동물 (가끔 1마리만, 빠르게 도망)
--=========================================================
Config.Animals = {
	Chick = {
		Species = "Chick", Island = "Meadow", Order = 1,
		Reward = 1, Count = 8, Rare = false,
		MoveSpeed = 7, WanderIdle = { 2, 4 },
	},
	Duckling = {
		Species = "Duckling", Island = "Meadow", Order = 2,
		Reward = 2, Count = 4, Rare = false,
		MoveSpeed = 8, WanderIdle = { 2, 4 },
	},
	RainbowRabbit = {
		Species = "RainbowRabbit", Island = "Meadow", Order = 3,
		Reward = 5, Count = 1, Rare = true,
		MoveSpeed = 17, WanderIdle = { 0.4, 0.9 },
		RespawnDelay = 180, FleeRadius = 30,
	},
	Penguin = {
		Species = "Penguin", Island = "Snow", Order = 1,
		Reward = 2, Count = 6, Rare = false,
		MoveSpeed = 7, WanderIdle = { 2, 4 },
	},
	SnowBunny = {
		Species = "SnowBunny", Island = "Snow", Order = 2,
		Reward = 3, Count = 3, Rare = false,
		MoveSpeed = 9, WanderIdle = { 1.5, 3 },
	},
	GoldenPenguin = {
		Species = "GoldenPenguin", Island = "Snow", Order = 3,
		Reward = 5, Count = 1, Rare = true,
		MoveSpeed = 17, WanderIdle = { 0.4, 0.9 },
		RespawnDelay = 180, FleeRadius = 30,
	},
}

-- 도감에 보여줄 순서 (9단계: 섬마다 3칸)
Config.DexOrder = {
	Meadow = { "Chick", "Duckling", "RainbowRabbit" },
	Snow = { "Penguin", "SnowBunny", "GoldenPenguin" },
}

-- 같은 종이 한 섬에 최대 몇 마리까지 존재할 수 있는지 (성능 보호)
Config.MaxAnimalsPerSpecies = 3 -- Count 의 배수
Config.AnimalRespawnDelay = 5 -- 마리 수가 부족할 때 새로 태어나는 시간(초)

--=========================================================
-- 섬 (2·7단계)   * 모든 섬의 땅 높이(TopY)는 0 입니다.
--=========================================================
Config.Islands = {
	Meadow = {
		Key = "Meadow", Order = 1, UnlockCost = 0,
		Center = Vector3.new(0, 0, 0),
		Radius = 100,
		SpawnPoint = Vector3.new(0, 0, 62), -- 스폰 발판
		FarmCenter = Vector3.new(0, 0, 18), -- 농장 중심
		FarmSize = 36, -- 농장 한 변
		DeliveryPos = Vector3.new(0, 0, 37), -- 노란 배달 발판
		FirstAnimalPos = Vector3.new(0, 0, 50), -- 접속 직후 보이는 첫 동물
		FoxDen = Vector3.new(-48, 0, -14),
		ShopPos = Vector3.new(30, 0, 33),
		WanderBand = { 14, 90 }, -- 중심에서 이 거리 사이에 동물이 생김
		Ground = Color3.fromRGB(150, 216, 138),
		Beach = Color3.fromRGB(246, 228, 174),
	},
	Snow = {
		Key = "Snow", Order = 2, UnlockCost = 15, -- 두 번째 섬 해금 비용: 별 15개
		Center = Vector3.new(0, 0, -258),
		Radius = 72,
		SpawnPoint = Vector3.new(0, 0, -200),
		FarmCenter = Vector3.new(0, 0, -288),
		FarmSize = 24,
		DeliveryPos = Vector3.new(0, 0, -274),
		FirstAnimalPos = Vector3.new(0, 0, -214),
		FoxDen = Vector3.new(-42, 0, -246),
		ShopPos = nil,
		WanderBand = { 12, 62 },
		Ground = Color3.fromRGB(240, 247, 255),
		Beach = Color3.fromRGB(198, 226, 245),
	},
}
Config.IslandOrder = { "Meadow", "Snow" }
Config.StartIsland = "Meadow"

-- 다리와 별 문 (7단계)
Config.Bridge = {
	FromZ = -98, -- 초원 섬 끝
	ToZ = -190, -- 펭귄 섬 시작
	Width = 12,
	GateZ = -104, -- 별 문 위치
	GateWidth = 16,
	GateHeight = 15,
	BlockZ = -112, -- 잠긴 사람이 여기를 넘으면 되돌려 보냄
}

--=========================================================
-- 농장 (5단계)
--=========================================================
Config.Farm = {
	VisibleCapacity = 30, -- 농장 안에 눈에 보이는 최대 마리 수
	DeliveryInterval = 0.28, -- 한 마리씩 들어가는 간격(초)
	ZoneRadius = 7, -- 배달 발판 인식 범위
	HopInDuration = 0.7, -- 농장 안으로 폴짝 들어가는 시간
}

--=========================================================
-- 업그레이드 상점 (11단계)
--=========================================================
Config.Upgrades = {
	Order = { "Speed", "Train", "Magnet" },
	Speed = { MaxLevel = 3, Prices = { 8, 20, 40 } },
	Train = { MaxLevel = 3, Prices = { 12, 28, 55 }, LengthPerLevel = 5 },
	Magnet = { MaxLevel = 2, Prices = { 15, 35 } },
}

--=========================================================
-- NPC 여우 (10단계)
--=========================================================
Config.Fox = {
	PerIsland = { Meadow = 1, Snow = 1 },
	MaxTrain = 5,
	Speed = 11, -- 플레이어(16)보다 느리게
	ThinkInterval = 1.5, -- 목표를 다시 고르는 간격 (경로 계산 절약)
	CatchRadius = 3.6,
	WaveRadius = 14,
	WaveCooldown = 8,
	DenRadius = 6,
}

--=========================================================
-- 소리 (로블록스 클라이언트에 기본으로 들어있는 무료 사운드)
--   * 직접 구한 오디오 ID 를 쓰고 싶으면 Id 만 바꾸면 됩니다.
--=========================================================
Config.Sounds = {
	Chirp = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.95 },
	ChirpAlt = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 2.25 },
	Deliver = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.55, Pitch = 1.35 },
	StarUp = { Id = "rbxasset://sounds/snap.wav", Volume = 0.45, Pitch = 1.6 },
	Full = { Id = "rbxasset://sounds/switch3.wav", Volume = 0.5, Pitch = 1.4 },
	BuyOk = { Id = "rbxasset://sounds/snap.wav", Volume = 0.6, Pitch = 1.2 },
	BuyFail = { Id = "rbxasset://sounds/switch3.wav", Volume = 0.5, Pitch = 0.65 },
	Unlock = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.5, Pitch = 1.3 },
	NewAnimal = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.1 },
	Splash = { Id = "rbxasset://sounds/action_swim.mp3", Volume = 0.5, Pitch = 1 },
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Pitch = 1 },
}

-- 배경 음악 (12단계)
-- 로블록스 크리에이터 스토어에서 "사용 허용된" 음악의 ID 를 아래에 넣으면
-- 화면 오른쪽 아래에 스피커 버튼이 자동으로 생깁니다. 비워두면 음악 없이 동작합니다.
Config.Music = {
	AssetId = "", -- 예: "rbxassetid://1234567890"
	Volume = 0.2,
}

--=========================================================
-- 파티클 텍스처 (로블록스 클라이언트 기본 내장 무료 텍스처)
--=========================================================
Config.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

--=========================================================
-- 색 (파스텔)
--=========================================================
Config.Colors = {
	Water = Color3.fromRGB(137, 200, 240),
	Wood = Color3.fromRGB(197, 152, 106),
	WoodDark = Color3.fromRGB(160, 116, 78),
	Leaf = Color3.fromRGB(129, 205, 137),
	LeafAlt = Color3.fromRGB(160, 220, 150),
	Rock = Color3.fromRGB(196, 199, 206),
	Star = Color3.fromRGB(255, 221, 89),
	Snow = Color3.fromRGB(248, 252, 255),
	Ice = Color3.fromRGB(176, 222, 247),
	Pink = Color3.fromRGB(255, 176, 200),
	Sky = Color3.fromRGB(190, 228, 255),
}

--=========================================================
-- 리모트 이름 (서버 ↔ 클라이언트)
--=========================================================
Config.Remotes = {
	StateUpdate = "StateUpdate", -- 서버 → 클라 : 내 상태 전체
	Effect = "Effect", -- 서버 → 클라 : 소리/연출 신호
	RequestState = "RequestState", -- 클라 → 서버 : 접속 직후 상태 요청
	SetPref = "SetPref", -- 클라 → 서버 : 음악 켜기/끄기 저장
}

Config.Debug = true -- 출력 창에 진행 로그를 표시

return Config
]==])

script_(folder(roots.ReplicatedStorage, "Shared"), "ModuleScript", "ModelFactory", [==[
-- 파트만 조합해서 만드는 모델 공장.
-- 툴박스 무료 모델은 쓰지 않습니다 (CLAUDE.md 기술 규칙).
-- 서버(동물 스폰)와 클라이언트(도감·HUD 아이콘) 양쪽에서 씁니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ModelFactory = {}

local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local DARK = Color3.fromRGB(48, 46, 58)
local WHITE = Color3.fromRGB(252, 252, 255)
local ORANGE = Color3.fromRGB(255, 163, 71)
local PINK = Color3.fromRGB(255, 168, 196)

-- 동물 몸 중심을 땅에서 얼마나 띄울지 (발이 땅에 닿게)
ModelFactory.Lift = {
	Chick = 1.2,
	Duckling = 1.25,
	Penguin = 1.5,
	SnowBunny = 1.15,
	RainbowRabbit = 1.15,
	GoldenPenguin = 1.5,
	Fox = 1.75,
}

--=========================================================
-- 기본 도구
--=========================================================
local function newPart(def)
	local instance = Instance.new(def.Class or "Part")
	instance.Name = def.Name or "Piece"
	instance.Anchored = true
	instance.CanCollide = def.CanCollide == true
	instance.CanQuery = def.CanQuery == true
	instance.CanTouch = def.CanTouch == true
	instance.CastShadow = def.CastShadow == true
	instance.Material = def.Material or SMOOTH
	instance.Size = def.Size
	instance.Color = def.Color or WHITE
	instance.Transparency = def.Transparency or 0
	instance.Reflectance = def.Reflectance or 0
	if instance:IsA("Part") then
		if def.Shape then
			instance.Shape = def.Shape
		end
		instance.TopSurface = Enum.SurfaceType.Smooth
		instance.BottomSurface = Enum.SurfaceType.Smooth
		instance.LeftSurface = Enum.SurfaceType.Smooth
		instance.RightSurface = Enum.SurfaceType.Smooth
		instance.FrontSurface = Enum.SurfaceType.Smooth
		instance.BackSurface = Enum.SurfaceType.Smooth
	end
	return instance
end
ModelFactory.newPart = newPart

-- 파트 목록을 하나의 Model 로 조립합니다. Primary = true 인 파트가 기준점.
local function assemble(name, pieces)
	local model = Instance.new("Model")
	model.Name = name

	local primary = nil
	for _, def in ipairs(pieces) do
		local piece = newPart(def)
		local cframe = CFrame.new(def.Pos or Vector3.zero)
		if def.Rot then
			cframe = cframe
				* CFrame.fromEulerAnglesXYZ(math.rad(def.Rot.X), math.rad(def.Rot.Y), math.rad(def.Rot.Z))
		end
		piece.CFrame = cframe
		piece.Parent = model
		if def.Primary then
			primary = piece
		end
	end

	if primary then
		model.PrimaryPart = primary
		model.WorldPivot = primary.CFrame
	end
	return model
end
ModelFactory.assemble = assemble

-- 반짝임 파티클 (멀리서도 눈에 띄게)
function ModelFactory.addSparkles(parent: Instance, color: Color3, rate: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = Config.Textures.Sparkle
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.9
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Rate = rate or 7
	emitter.Speed = NumberRange.new(1.2, 2.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 2.5, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = parent
	return emitter
end

-- 한 번 터지는 파티클 (하트/별/폭죽)
function ModelFactory.burst(position: Vector3, color: Color3, count: number, parentTo: Instance?)
	local anchor = newPart({
		Name = "Burst",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Color = color,
		Transparency = 1,
	})
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = parentTo or workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Config.Textures.Sparkle
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(7, 13)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = anchor
	emitter:Emit(count)

	task.delay(1.4, function()
		anchor:Destroy()
	end)
	return anchor
end

--=========================================================
-- 동물 : 병아리 / 오리
--=========================================================
local function buildChickLike(name, opts)
	local body = opts.Body
	local scale = opts.Scale or 1
	local pieces = {
		{ Name = "Body", Primary = true, Shape = BALL, Size = Vector3.new(2.2, 2.2, 2.2) * scale, Pos = Vector3.zero, Color = body },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(1.5, 1.5, 1.5) * scale, Pos = Vector3.new(0, 1.25, 0.3) * scale, Color = body },
		{ Name = "Beak", Size = opts.BeakSize * scale, Pos = Vector3.new(0, 1.12, 1.0) * scale, Color = ORANGE },
		{ Name = "EyeL", Shape = BALL, Size = Vector3.new(0.3, 0.3, 0.3) * scale, Pos = Vector3.new(-0.36, 1.48, 0.9) * scale, Color = DARK },
		{ Name = "EyeR", Shape = BALL, Size = Vector3.new(0.3, 0.3, 0.3) * scale, Pos = Vector3.new(0.36, 1.48, 0.9) * scale, Color = DARK },
		{ Name = "WingL", Shape = BALL, Size = Vector3.new(0.3, 0.85, 1.0) * scale, Pos = Vector3.new(-1.05, 0.05, 0) * scale, Color = opts.Wing or body },
		{ Name = "WingR", Shape = BALL, Size = Vector3.new(0.3, 0.85, 1.0) * scale, Pos = Vector3.new(1.05, 0.05, 0) * scale, Color = opts.Wing or body },
		{ Name = "Tuft", Shape = BALL, Size = Vector3.new(0.5, 0.5, 0.5) * scale, Pos = Vector3.new(0, 1.95, 0.15) * scale, Color = opts.Tuft or body },
		{ Name = "FootL", Size = Vector3.new(0.32, 0.2, 0.68) * scale, Pos = Vector3.new(-0.4, -1.05, 0.2) * scale, Color = ORANGE },
		{ Name = "FootR", Size = Vector3.new(0.32, 0.2, 0.68) * scale, Pos = Vector3.new(0.4, -1.05, 0.2) * scale, Color = ORANGE },
	}
	return assemble(name, pieces)
end

--=========================================================
-- 동물 : 펭귄
--=========================================================
local function buildPenguinLike(name, opts)
	local body = opts.Body
	local belly = opts.Belly or WHITE
	local shine = opts.Reflectance or 0
	local pieces = {
		{ Name = "Body", Primary = true, Shape = BALL, Size = Vector3.new(2.3, 2.7, 2.1), Pos = Vector3.zero, Color = body, Reflectance = shine },
		{ Name = "Belly", Shape = BALL, Size = Vector3.new(1.7, 2.0, 1.2), Pos = Vector3.new(0, -0.1, 0.7), Color = belly },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(1.55, 1.55, 1.55), Pos = Vector3.new(0, 1.5, 0.05), Color = body, Reflectance = shine },
		{ Name = "FaceL", Shape = BALL, Size = Vector3.new(0.55, 0.6, 0.4), Pos = Vector3.new(-0.38, 1.55, 0.66), Color = belly },
		{ Name = "FaceR", Shape = BALL, Size = Vector3.new(0.55, 0.6, 0.4), Pos = Vector3.new(0.38, 1.55, 0.66), Color = belly },
		{ Name = "EyeL", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(-0.38, 1.6, 0.84), Color = DARK },
		{ Name = "EyeR", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(0.38, 1.6, 0.84), Color = DARK },
		{ Name = "Beak", Size = Vector3.new(0.42, 0.3, 0.6), Pos = Vector3.new(0, 1.24, 0.82), Color = ORANGE },
		{ Name = "FlipperL", Shape = BALL, Size = Vector3.new(0.3, 1.3, 0.9), Pos = Vector3.new(-1.15, -0.15, 0), Color = body, Reflectance = shine },
		{ Name = "FlipperR", Shape = BALL, Size = Vector3.new(0.3, 1.3, 0.9), Pos = Vector3.new(1.15, -0.15, 0), Color = body, Reflectance = shine },
		{ Name = "FootL", Size = Vector3.new(0.5, 0.2, 0.78), Pos = Vector3.new(-0.44, -1.35, 0.3), Color = ORANGE },
		{ Name = "FootR", Size = Vector3.new(0.5, 0.2, 0.78), Pos = Vector3.new(0.44, -1.35, 0.3), Color = ORANGE },
	}
	return assemble(name, pieces)
end

--=========================================================
-- 동물 : 토끼
--=========================================================
local function buildBunnyLike(name, opts)
	local body = opts.Body
	local ear = opts.EarTip or opts.Body
	local pieces = {
		{ Name = "Body", Primary = true, Shape = BALL, Size = Vector3.new(2.1, 2.0, 2.3), Pos = Vector3.zero, Color = body },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(1.4, 1.4, 1.4), Pos = Vector3.new(0, 1.1, 0.35), Color = body },
		{ Name = "EarL", Size = Vector3.new(0.36, 1.4, 0.3), Pos = Vector3.new(-0.36, 2.2, 0.2), Color = body, Rot = Vector3.new(-8, 0, -6) },
		{ Name = "EarR", Size = Vector3.new(0.36, 1.4, 0.3), Pos = Vector3.new(0.36, 2.2, 0.2), Color = body, Rot = Vector3.new(-8, 0, 6) },
		{ Name = "EarTipL", Size = Vector3.new(0.34, 0.45, 0.28), Pos = Vector3.new(-0.42, 2.85, 0.15), Color = ear, Rot = Vector3.new(-8, 0, -6) },
		{ Name = "EarTipR", Size = Vector3.new(0.34, 0.45, 0.28), Pos = Vector3.new(0.42, 2.85, 0.15), Color = ear, Rot = Vector3.new(-8, 0, 6) },
		{ Name = "EyeL", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(-0.34, 1.28, 0.94), Color = DARK },
		{ Name = "EyeR", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(0.34, 1.28, 0.94), Color = DARK },
		{ Name = "Nose", Shape = BALL, Size = Vector3.new(0.24, 0.2, 0.2), Pos = Vector3.new(0, 1.06, 1.04), Color = PINK },
		{ Name = "Tail", Shape = BALL, Size = Vector3.new(0.62, 0.62, 0.62), Pos = Vector3.new(0, 0.25, -1.15), Color = opts.Tail or WHITE },
		{ Name = "FootL", Size = Vector3.new(0.42, 0.24, 0.8), Pos = Vector3.new(-0.42, -0.98, 0.3), Color = body },
		{ Name = "FootR", Size = Vector3.new(0.42, 0.24, 0.8), Pos = Vector3.new(0.42, -0.98, 0.3), Color = body },
	}
	local model = assemble(name, pieces)

	-- 무지개 토끼: 등에 무지개 줄무늬
	if opts.Rainbow then
		local rainbow = {
			Color3.fromRGB(255, 138, 138),
			Color3.fromRGB(255, 196, 120),
			Color3.fromRGB(255, 242, 140),
			Color3.fromRGB(152, 226, 160),
			Color3.fromRGB(150, 196, 255),
			Color3.fromRGB(198, 168, 245),
		}
		for index, color in ipairs(rainbow) do
			local stripe = newPart({
				Name = "Stripe" .. index,
				Shape = BALL,
				Size = Vector3.new(0.5, 0.5, 0.5),
				Color = color,
				Material = NEON,
			})
			stripe.CFrame = CFrame.new(0, 1.05 - index * 0.04, 0.65 - index * 0.32)
			stripe.Parent = model
		end
	end
	return model
end

--=========================================================
-- 동물 : 여우 (10단계 NPC)
--=========================================================
function ModelFactory.buildFox()
	local fur = Color3.fromRGB(238, 152, 98)
	local pieces = {
		{ Name = "Body", Primary = true, Shape = BALL, Size = Vector3.new(2.4, 2.2, 3.2), Pos = Vector3.zero, Color = fur },
		{ Name = "Chest", Shape = BALL, Size = Vector3.new(1.5, 1.4, 1.5), Pos = Vector3.new(0, -0.2, 1.1), Color = WHITE },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(1.7, 1.7, 1.7), Pos = Vector3.new(0, 1.05, 1.3), Color = fur },
		{ Name = "Snout", Size = Vector3.new(0.7, 0.55, 0.85), Pos = Vector3.new(0, 0.78, 2.2), Color = WHITE },
		{ Name = "Nose", Shape = BALL, Size = Vector3.new(0.3, 0.28, 0.28), Pos = Vector3.new(0, 0.86, 2.62), Color = DARK },
		{ Name = "EarL", Size = Vector3.new(0.5, 0.85, 0.26), Pos = Vector3.new(-0.58, 1.95, 1.15), Color = fur, Rot = Vector3.new(-10, 0, -10) },
		{ Name = "EarR", Size = Vector3.new(0.5, 0.85, 0.26), Pos = Vector3.new(0.58, 1.95, 1.15), Color = fur, Rot = Vector3.new(-10, 0, 10) },
		{ Name = "EyeL", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(-0.5, 1.25, 2.0), Color = DARK },
		{ Name = "EyeR", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(0.5, 1.25, 2.0), Color = DARK },
		{ Name = "TailA", Shape = BALL, Size = Vector3.new(1.2, 1.2, 1.4), Pos = Vector3.new(0, 0.45, -2.0), Color = fur },
		{ Name = "TailB", Shape = BALL, Size = Vector3.new(0.95, 0.95, 1.1), Pos = Vector3.new(0, 0.95, -2.8), Color = fur },
		{ Name = "TailTip", Shape = BALL, Size = Vector3.new(0.7, 0.7, 0.7), Pos = Vector3.new(0, 1.35, -3.35), Color = WHITE },
		{ Name = "WaveArm", Size = Vector3.new(0.42, 1.1, 0.42), Pos = Vector3.new(1.2, -0.25, 0.95), Color = fur },
		{ Name = "ArmL", Size = Vector3.new(0.42, 1.1, 0.42), Pos = Vector3.new(-1.2, -0.25, 0.95), Color = fur },
		{ Name = "LegL", Size = Vector3.new(0.46, 1.0, 0.52), Pos = Vector3.new(-0.85, -1.2, -1.0), Color = fur },
		{ Name = "LegR", Size = Vector3.new(0.46, 1.0, 0.52), Pos = Vector3.new(0.85, -1.2, -1.0), Color = fur },
	}
	return assemble("Fox", pieces)
end

--=========================================================
-- 동물 만들기 (종류 이름으로)
--=========================================================
local builders = {
	Chick = function()
		return buildChickLike("Chick", {
			Body = Color3.fromRGB(255, 233, 128),
			Tuft = Color3.fromRGB(255, 214, 92),
			BeakSize = Vector3.new(0.4, 0.3, 0.55),
		})
	end,
	Duckling = function()
		return buildChickLike("Duckling", {
			Body = Color3.fromRGB(252, 247, 226),
			Wing = Color3.fromRGB(240, 233, 205),
			Tuft = Color3.fromRGB(240, 233, 205),
			BeakSize = Vector3.new(0.8, 0.26, 0.7),
			Scale = 1.05,
		})
	end,
	Penguin = function()
		return buildPenguinLike("Penguin", { Body = Color3.fromRGB(78, 86, 118) })
	end,
	GoldenPenguin = function()
		local model = buildPenguinLike("GoldenPenguin", {
			Body = Color3.fromRGB(255, 205, 74),
			Belly = Color3.fromRGB(255, 240, 190),
			Reflectance = 0.25,
		})
		ModelFactory.addSparkles(model.PrimaryPart, Color3.fromRGB(255, 232, 150), 16)
		return model
	end,
	SnowBunny = function()
		return buildBunnyLike("SnowBunny", {
			Body = Color3.fromRGB(246, 250, 255),
			EarTip = Color3.fromRGB(186, 224, 247),
			Tail = Color3.fromRGB(255, 255, 255),
		})
	end,
	RainbowRabbit = function()
		local model = buildBunnyLike("RainbowRabbit", {
			Body = Color3.fromRGB(255, 244, 250),
			EarTip = Color3.fromRGB(255, 168, 196),
			Tail = Color3.fromRGB(255, 240, 246),
			Rainbow = true,
		})
		ModelFactory.addSparkles(model.PrimaryPart, Color3.fromRGB(255, 190, 230), 18)
		return model
	end,
}

function ModelFactory.buildAnimal(species: string)
	local builder = builders[species]
	if not builder then
		return nil
	end
	local model = builder()
	local info = Config.Animals[species]
	if info and not info.Rare then
		-- 평범한 동물도 멀리서 보이게 작은 반짝임 (3단계)
		ModelFactory.addSparkles(model.PrimaryPart, Color3.fromRGB(255, 252, 220), 5)
	end
	model:SetAttribute("Species", species)
	model:SetAttribute("Lift", ModelFactory.Lift[species] or 1.2)
	return model
end

function ModelFactory.hasSpecies(species: string): boolean
	return builders[species] ~= nil
end

--=========================================================
-- 별 (반짝 별 모양)
--=========================================================
function ModelFactory.buildStar(color: Color3?)
	local starColor = color or Config.Colors.Star
	local pieces = {
		{ Name = "Core", Primary = true, Size = Vector3.new(1.6, 0.46, 0.3), Pos = Vector3.zero, Color = starColor, Material = NEON },
		{ Name = "Cross", Size = Vector3.new(0.46, 1.6, 0.3), Pos = Vector3.zero, Color = starColor, Material = NEON },
		{ Name = "DiagA", Size = Vector3.new(1.1, 0.3, 0.28), Pos = Vector3.zero, Color = starColor, Material = NEON, Rot = Vector3.new(0, 0, 45) },
		{ Name = "DiagB", Size = Vector3.new(1.1, 0.3, 0.28), Pos = Vector3.zero, Color = starColor, Material = NEON, Rot = Vector3.new(0, 0, -45) },
		{ Name = "Middle", Shape = BALL, Size = Vector3.new(0.62, 0.62, 0.62), Pos = Vector3.zero, Color = starColor, Material = NEON },
	}
	return assemble("Star", pieces)
end

--=========================================================
-- 업그레이드 아이콘 (11단계) : 신발 / 기차 / 자석
--=========================================================
local iconBuilders = {
	Speed = function()
		return assemble("ShoeIcon", {
			{ Name = "Sole", Primary = true, Size = Vector3.new(1.8, 0.3, 0.8), Pos = Vector3.zero, Color = WHITE },
			{ Name = "Upper", Shape = BALL, Size = Vector3.new(1.0, 0.85, 0.8), Pos = Vector3.new(-0.32, 0.4, 0), Color = Color3.fromRGB(122, 190, 255) },
			{ Name = "Toe", Shape = BALL, Size = Vector3.new(0.8, 0.6, 0.78), Pos = Vector3.new(0.6, 0.2, 0), Color = WHITE },
			{ Name = "Lace", Size = Vector3.new(0.5, 0.12, 0.6), Pos = Vector3.new(-0.1, 0.72, 0), Color = Color3.fromRGB(255, 240, 160) },
		})
	end,
	Train = function()
		return assemble("TrainIcon", {
			{ Name = "Body", Primary = true, Size = Vector3.new(1.7, 0.9, 0.95), Pos = Vector3.zero, Color = Color3.fromRGB(255, 142, 142) },
			{ Name = "Cabin", Size = Vector3.new(0.65, 0.65, 0.9), Pos = Vector3.new(-0.5, 0.75, 0), Color = Color3.fromRGB(255, 190, 190) },
			{ Name = "Chimney", Shape = CYL, Size = Vector3.new(0.6, 0.38, 0.38), Pos = Vector3.new(0.6, 0.72, 0), Color = Color3.fromRGB(255, 236, 160), Rot = Vector3.new(0, 0, 90) },
			{ Name = "WheelA", Shape = CYL, Size = Vector3.new(0.24, 0.62, 0.62), Pos = Vector3.new(-0.5, -0.52, 0), Color = Color3.fromRGB(96, 104, 132) },
			{ Name = "WheelB", Shape = CYL, Size = Vector3.new(0.24, 0.62, 0.62), Pos = Vector3.new(0.5, -0.52, 0), Color = Color3.fromRGB(96, 104, 132) },
		})
	end,
	Magnet = function()
		return assemble("MagnetIcon", {
			{ Name = "Arch", Primary = true, Size = Vector3.new(1.5, 0.45, 0.5), Pos = Vector3.new(0, 0.75, 0), Color = Color3.fromRGB(255, 122, 122) },
			{ Name = "LegL", Size = Vector3.new(0.45, 1.2, 0.5), Pos = Vector3.new(-0.52, 0.0, 0), Color = Color3.fromRGB(255, 122, 122) },
			{ Name = "LegR", Size = Vector3.new(0.45, 1.2, 0.5), Pos = Vector3.new(0.52, 0.0, 0), Color = Color3.fromRGB(255, 122, 122) },
			{ Name = "TipL", Size = Vector3.new(0.45, 0.35, 0.52), Pos = Vector3.new(-0.52, -0.78, 0), Color = Color3.fromRGB(226, 232, 240) },
			{ Name = "TipR", Size = Vector3.new(0.45, 0.35, 0.52), Pos = Vector3.new(0.52, -0.78, 0), Color = Color3.fromRGB(226, 232, 240) },
		})
	end,
}

function ModelFactory.buildIcon(kind: string)
	local builder = iconBuilders[kind]
	if not builder then
		return nil
	end
	return builder()
end

-- 원점 기준으로 만든 모델의 크기를 바꿉니다 (별 문의 큰 별 등).
function ModelFactory.scaleModel(model: Model, scale: number)
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			local cframe = piece.CFrame
			piece.Size = piece.Size * scale
			piece.CFrame = CFrame.new(cframe.Position * scale) * (cframe - cframe.Position)
		end
	end
	if model.PrimaryPart then
		model.WorldPivot = model.PrimaryPart.CFrame
	end
	return model
end

-- 원점 기준으로 만든 모델을 한 번에 옮깁니다 (장식용).
function ModelFactory.offsetModel(model: Model, position: Vector3, yawDegrees: number?)
	local target = CFrame.new(position)
	if yawDegrees then
		target = target * CFrame.fromEulerAnglesXYZ(0, math.rad(yawDegrees), 0)
	end
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.CFrame = target * piece.CFrame
		end
	end
	return model
end

--=========================================================
-- 섬 장식 (2·7단계)
--=========================================================
function ModelFactory.buildTree(rng: Random)
	local height = rng:NextNumber(5, 8)
	local leaf = rng:NextInteger(1, 2) == 1 and Config.Colors.Leaf or Config.Colors.LeafAlt
	local pieces = {
		{ Name = "Trunk", Primary = true, Shape = CYL, Size = Vector3.new(height, 1.3, 1.3), Pos = Vector3.new(0, height / 2, 0), Color = Config.Colors.Wood, Rot = Vector3.new(0, 0, 90), CastShadow = true, CanCollide = true },
		{ Name = "LeafA", Shape = BALL, Size = Vector3.new(6, 5.2, 6), Pos = Vector3.new(0, height + 1.2, 0), Color = leaf, CastShadow = true },
		{ Name = "LeafB", Shape = BALL, Size = Vector3.new(4.2, 3.8, 4.2), Pos = Vector3.new(1.4, height + 2.6, 0.7), Color = leaf, CastShadow = true },
		{ Name = "LeafC", Shape = BALL, Size = Vector3.new(3.6, 3.2, 3.6), Pos = Vector3.new(-1.5, height + 2.2, -0.6), Color = leaf, CastShadow = true },
	}
	return assemble("Tree", pieces)
end

function ModelFactory.buildPine(rng: Random)
	local height = rng:NextNumber(5, 7.5)
	local pieces = {
		{ Name = "Trunk", Primary = true, Shape = CYL, Size = Vector3.new(height * 0.5, 1.1, 1.1), Pos = Vector3.new(0, height * 0.25, 0), Color = Config.Colors.WoodDark, Rot = Vector3.new(0, 0, 90), CanCollide = true },
		{ Name = "LayerA", Shape = CYL, Size = Vector3.new(1.6, 5.4, 5.4), Pos = Vector3.new(0, height * 0.5, 0), Color = Color3.fromRGB(122, 186, 150), Rot = Vector3.new(0, 0, 90), CastShadow = true },
		{ Name = "LayerB", Shape = CYL, Size = Vector3.new(1.5, 4.0, 4.0), Pos = Vector3.new(0, height * 0.5 + 1.4, 0), Color = Color3.fromRGB(140, 200, 164), Rot = Vector3.new(0, 0, 90), CastShadow = true },
		{ Name = "LayerC", Shape = CYL, Size = Vector3.new(1.4, 2.6, 2.6), Pos = Vector3.new(0, height * 0.5 + 2.7, 0), Color = Config.Colors.Snow, Rot = Vector3.new(0, 0, 90), CastShadow = true },
		{ Name = "Top", Shape = BALL, Size = Vector3.new(1.3, 1.3, 1.3), Pos = Vector3.new(0, height * 0.5 + 3.7, 0), Color = Config.Colors.Snow },
	}
	return assemble("Pine", pieces)
end

function ModelFactory.buildFlower(rng: Random)
	local petals = {
		Color3.fromRGB(255, 176, 200),
		Color3.fromRGB(255, 226, 138),
		Color3.fromRGB(198, 176, 255),
		Color3.fromRGB(180, 226, 255),
	}
	local color = petals[rng:NextInteger(1, #petals)]
	local pieces = {
		{ Name = "Stem", Primary = true, Shape = CYL, Size = Vector3.new(1.3, 0.16, 0.16), Pos = Vector3.new(0, 0.65, 0), Color = Color3.fromRGB(140, 200, 140), Rot = Vector3.new(0, 0, 90) },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(0.85, 0.5, 0.85), Pos = Vector3.new(0, 1.35, 0), Color = color },
		{ Name = "Middle", Shape = BALL, Size = Vector3.new(0.35, 0.4, 0.35), Pos = Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(255, 246, 190) },
	}
	return assemble("Flower", pieces)
end

function ModelFactory.buildRock(rng: Random)
	local size = rng:NextNumber(1.6, 3.4)
	local pieces = {
		{ Name = "RockA", Primary = true, Shape = BALL, Size = Vector3.new(size, size * 0.8, size * 1.1), Pos = Vector3.new(0, size * 0.3, 0), Color = Config.Colors.Rock, CastShadow = true, CanCollide = true },
		{ Name = "RockB", Shape = BALL, Size = Vector3.new(size * 0.6, size * 0.5, size * 0.7), Pos = Vector3.new(size * 0.5, size * 0.15, size * 0.2), Color = Color3.fromRGB(210, 213, 219) },
	}
	return assemble("Rock", pieces)
end

function ModelFactory.buildSnowMound(rng: Random)
	local size = rng:NextNumber(3, 6)
	local pieces = {
		{ Name = "Mound", Primary = true, Shape = BALL, Size = Vector3.new(size, size * 0.55, size), Pos = Vector3.new(0, size * 0.18, 0), Color = Config.Colors.Snow, CastShadow = true },
	}
	return assemble("SnowMound", pieces)
end

return ModelFactory
]==])

script_(folder(roots.ReplicatedStorage, "Shared"), "ModuleScript", "Net", [==[
-- 서버 ↔ 클라이언트 통신 통로.
-- 모든 RemoteEvent 는 ReplicatedStorage/Remotes 안에만 있습니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}
local cache = {}

local function getFolder()
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild("Remotes", 30)
end

function Net.event(name)
	local cached = cache[name]
	if cached then
		return cached
	end

	local folder = getFolder()
	local event
	if RunService:IsServer() then
		event = folder:FindFirstChild(name)
		if not event then
			event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	else
		event = folder:WaitForChild(name, 30)
	end

	cache[name] = event
	return event
end

return Net
]==])

script_(folder(roots.ReplicatedStorage, "Shared"), "ModuleScript", "Rules", [==[
--!strict
-- 규칙 계산 (서버·클라이언트 공용). 값 자체는 Config 에 있습니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Rules = {}

function Rules.maxTrain(trainLevel: number): number
	return Config.Train.BaseMaxLength + trainLevel * Config.Upgrades.Train.LengthPerLevel
end

function Rules.pickupRadius(magnetLevel: number): number
	return Config.Pickup.BaseRadius + magnetLevel * Config.Pickup.MagnetBonusPerLevel
end

function Rules.walkSpeed(speedLevel: number): number
	return Config.Player.BaseWalkSpeed + speedLevel * Config.Player.SpeedPerLevel
end

function Rules.maxLevel(kind: string): number
	local info = Config.Upgrades[kind]
	return info and info.MaxLevel or 0
end

-- 다음 단계 가격. 더 살 수 없으면 nil.
function Rules.nextPrice(kind: string, currentLevel: number): number?
	local info = Config.Upgrades[kind]
	if not info then
		return nil
	end
	if currentLevel >= info.MaxLevel then
		return nil
	end
	return info.Prices[currentLevel + 1]
end

function Rules.islandReward(species: string): number
	local info = Config.Animals[species]
	return info and info.Reward or 1
end

return Rules
]==])

script_(folder(roots.ReplicatedStorage, "Shared"), "ModuleScript", "Sounds", [==[
-- 소리 재생 담당 (클라이언트 전용).
-- 파일을 못 찾아도 게임이 멈추지 않도록 전부 pcall 로 감쌉니다.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sounds = {}

local group: SoundGroup? = nil

local function getGroup()
	if group and group.Parent then
		return group
	end
	local made = Instance.new("SoundGroup")
	made.Name = "AnimalTrainSfx"
	made.Volume = 1
	made.Parent = SoundService
	group = made
	return made
end

-- name: Config.Sounds 의 키. pitchJitter: 음높이를 조금씩 흔들어 지겹지 않게.
function Sounds.play(name: string, pitchJitter: number?)
	local def = Config.Sounds[name]
	if not def or def.Id == "" then
		return
	end

	local ok = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = def.Id
		sound.Volume = def.Volume or 0.5
		local pitch = def.Pitch or 1
		if pitchJitter and pitchJitter > 0 then
			pitch += (math.random() - 0.5) * 2 * pitchJitter
		end
		sound.PlaybackSpeed = math.max(0.25, pitch)
		sound.SoundGroup = getGroup()
		sound.Parent = getGroup()
		sound:Play()
		task.delay(5, function()
			sound:Destroy()
		end)
	end)
	return ok
end

-- 같은 소리를 살짝 시간차로 여러 번 (축하 연출용)
function Sounds.playTimes(name: string, count: number, gap: number)
	for index = 1, count do
		task.delay((index - 1) * gap, function()
			Sounds.play(name, 0.08)
		end)
	end
end

return Sounds
]==])

script_(roots.ServerScriptService, "Script", "GameBootstrap", [==[
-- 서버 시작점. 서비스들을 정해진 순서로 켭니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent:WaitForChild("Services")

local order = {
	"Effects", -- 리모트와 연출 먼저
	"DataService", -- 저장 (다른 서비스가 별을 주기 전에)
	"WorldService", -- 섬과 농장
	"AnimalService", -- 동물과 기차
	"FarmService", -- 배달과 별
	"GateService", -- 별 문
	"ShopService", -- 업그레이드
	"FoxService", -- NPC 여우
	"StateService", -- 화면에 보낼 상태
	"MetricsService", -- 시간 측정 (Studio 확인용)
}

print("[졸졸 동물 기차] 서버 시작")

local loaded = {}
for _, name in ipairs(order) do
	local moduleScript = Services:FindFirstChild(name)
	if not moduleScript then
		warn("[졸졸 동물 기차] 스크립트를 찾을 수 없음: " .. name)
	else
		local service = require(moduleScript)
		loaded[name] = service
		if type(service.Start) == "function" then
			local ok, err = xpcall(service.Start, function(message)
				return tostring(message) .. "\n" .. debug.traceback()
			end)
			if not ok then
				warn("[졸졸 동물 기차] " .. name .. " 시작 실패:\n" .. tostring(err))
			end
		end
	end
end

-- 물에 빠질 때 소리 (WorldService ↔ Effects 연결)
if loaded.WorldService and loaded.Effects then
	loaded.WorldService.onFall = function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			loaded.Effects.sound3d(root.Position, "Splash")
		end
		loaded.Effects.toPlayer(player, "fell", {})
	end
end

print("[졸졸 동물 기차] 준비 완료")
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "AnimalService", [==[
-- 3·4단계 : 동물 스폰 / 돌아다니기 / 닿으면 줄지어 따라오기 (게임의 핵심)
-- 모든 판단은 서버에서 합니다. 동물은 Anchored 상태로 CFrame 만 움직여
-- 물리 계산을 쓰지 않습니다 (성능).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local DataService = require(script.Parent.DataService)
local Effects = require(script.Parent.Effects)

local AnimalService = {}

local animalsFolder
local records = {} -- [id] = rec
local owners = {} -- [ownerKey] = owner (플레이어와 여우 모두)
local trainCallbacks = {}
local nextId = 0
local pendingSpawn = {} -- [species] = 스폰 예정 시각
local rareReadyAt = {} -- [species] = 희귀 동물 다음 등장 시각

local UP = Vector3.new(0, 1, 0)

local function log(...)
	if Config.Debug then
		print("[동물]", ...)
	end
end

--=========================================================
-- 위치 계산 도우미
--=========================================================
local function islandOf(key)
	return Config.Islands[key]
end

-- 섬 안으로, 그리고 농장 밖으로 밀어 넣습니다
local function clampToIsland(islandKey, position)
	local island = islandOf(islandKey)
	if not island then
		return position
	end
	local center = island.Center
	local offset = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	local distance = offset.Magnitude
	local maxDistance = island.Radius - 6
	if distance > maxDistance then
		offset = offset.Unit * maxDistance
	end
	local result = Vector3.new(center.X + offset.X, 0, center.Z + offset.Z)

	-- 농장 안으로는 들어가지 않게 (농장 안 동물과 헷갈리지 않도록)
	local farm = island.FarmCenter
	local half = island.FarmSize / 2 + 3
	local dx = result.X - farm.X
	local dz = result.Z - farm.Z
	if math.abs(dx) < half and math.abs(dz) < half then
		if math.abs(dx) > math.abs(dz) then
			result = Vector3.new(farm.X + (dx >= 0 and half or -half), 0, result.Z)
		else
			result = Vector3.new(result.X, 0, farm.Z + (dz >= 0 and half or -half))
		end
	end
	return result
end

local function randomIslandPoint(islandKey, rng)
	local island = islandOf(islandKey)
	local band = island.WanderBand
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(band[1], band[2])
	local point = island.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	return clampToIsland(islandKey, point)
end

--=========================================================
-- 발자취 (앞 동물을 자연스럽게 따라가게 하는 길)
--=========================================================
local function trailReset(owner, position)
	owner.trail = { pts = { position }, seg = { 0 }, first = 1, last = 1, total = 0 }
end

local function trailPush(owner, position)
	local trail = owner.trail
	if not trail or trail.last < trail.first then
		trailReset(owner, position)
		return
	end
	local newest = trail.pts[trail.last]
	local delta = position - newest
	local length = delta.Magnitude
	if length < Config.Train.TrailStep then
		return
	end
	if length > Config.Train.SnapDistance then
		-- 순간이동(리스폰 등) : 길을 새로 시작하고 동물을 바로 붙입니다
		trailReset(owner, position)
		owner.snap = true
		return
	end
	trail.last += 1
	trail.pts[trail.last] = position
	trail.seg[trail.last] = length
	trail.total += length

	local needed = owner.maxLength() * Config.Train.Spacing + Config.Train.TrailExtra
	while trail.total > needed and trail.first < trail.last - 1 do
		trail.total -= (trail.seg[trail.first + 1] or 0)
		trail.pts[trail.first] = nil
		trail.seg[trail.first] = nil
		trail.first += 1
	end
end

-- 뒤로 distance 만큼 떨어진 지점과 그때의 진행 방향
local function trailSample(owner, distance)
	local trail = owner.trail
	if not trail or trail.last < trail.first then
		return nil, nil
	end
	if trail.last == trail.first then
		return trail.pts[trail.first], nil
	end

	local remaining = distance
	for index = trail.last, trail.first + 1, -1 do
		local length = trail.seg[index] or 0
		if length > 0 then
			if length >= remaining then
				local newer = trail.pts[index]
				local older = trail.pts[index - 1]
				return newer:Lerp(older, remaining / length), newer - older
			end
			remaining -= length
		end
	end
	local oldest = trail.pts[trail.first]
	local next1 = trail.pts[trail.first + 1]
	return oldest, next1 and (next1 - oldest) or nil
end

--=========================================================
-- 동물 만들기 / 없애기
--=========================================================
local function applyCFrame(rec, hopHeight)
	local look = rec.facing
	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, 1)
	else
		look = look.Unit
	end
	local base = rec.pos + UP * (rec.lift + (hopHeight or 0))
	rec.model:PivotTo(CFrame.lookAt(base, base + look))
end

local function newRecord(species, position, islandKey, leash)
	local model = ModelFactory.buildAnimal(species)
	if not model then
		return nil
	end
	local info = Config.Animals[species]
	nextId += 1

	local rec = {
		id = nextId,
		species = species,
		island = islandKey,
		model = model,
		lift = ModelFactory.Lift[species] or 1.2,
		pos = Vector3.new(position.X, 0, position.Z),
		-- 처음 자리에서 이만큼 안에서만 돌아다닙니다 (섬 한쪽으로 몰리지 않게)
		home = Vector3.new(position.X, 0, position.Z),
		leash = leash or Config.Animals[species].Leash or 22,
		facing = Vector3.new(0, 0, 1),
		mode = "wander",
		idle = math.random() * 2,
		hopTo = nil,
		ownerKey = nil,
		consumed = false,
		speed = info.MoveSpeed or 8,
	}

	model.Name = species
	model:SetAttribute("Owned", false)
	model:SetAttribute("Island", islandKey)
	model:SetAttribute("Rare", info.Rare == true)
	model:SetAttribute("Reward", info.Reward or 1)
	model:SetAttribute("AnimalId", rec.id)
	applyCFrame(rec, 0)
	model.Parent = animalsFolder

	records[rec.id] = rec
	return rec
end

local function removeRecord(rec)
	rec.mode = "gone"
	records[rec.id] = nil
	if rec.model then
		rec.model:Destroy()
		rec.model = nil
	end
end

--=========================================================
-- 기차 (따라오기)
--=========================================================
local function fireTrainChanged(owner)
	if not owner.player then
		return
	end
	for _, callback in ipairs(trainCallbacks) do
		task.spawn(callback, owner.player)
	end
end

local function ownerKeyForPlayer(player)
	return "P" .. player.UserId
end
AnimalService.playerKey = ownerKeyForPlayer

local function claim(owner, rec)
	if rec.mode ~= "wander" or rec.consumed then
		return false
	end
	if #owner.train >= owner.maxLength() then
		return false
	end

	local position = owner.getPosition()
	if not position then
		return false
	end
	if not owner.trail or owner.trail.last < owner.trail.first then
		trailReset(owner, position)
	end

	rec.mode = "train"
	rec.ownerKey = owner.key
	rec.hopTo = nil
	table.insert(owner.train, rec)
	rec.model:SetAttribute("Owned", true)

	-- 삐약 소리 + 하트 파티클 (4단계)
	Effects.sound3d(rec.pos + UP * 2, rec.species == "Duckling" and "ChirpAlt" or "Chirp", 0.12)
	Effects.hearts(rec.pos + UP * (rec.lift + 1.2))

	if owner.player then
		DataService.noteTrainLength(owner.player, #owner.train)
		local full = #owner.train >= owner.maxLength()
		Effects.toPlayer(owner.player, "pickup", { count = #owner.train, full = full })
		if full then
			Effects.toPlayer(owner.player, "full", {})
		end
	end
	fireTrainChanged(owner)
	return true
end

local function releaseRecord(rec, position)
	rec.mode = "wander"
	rec.ownerKey = nil
	rec.idle = math.random() * 1.2
	rec.hopTo = nil
	if position then
		rec.pos = Vector3.new(position.X, 0, position.Z)
	end
	rec.pos = clampToIsland(rec.island, rec.pos)
	rec.home = rec.pos
	if rec.model then
		rec.model:SetAttribute("Owned", false)
	end
end

local function releaseTrain(owner)
	for _, rec in ipairs(owner.train) do
		releaseRecord(rec, rec.pos)
	end
	owner.train = {}
	fireTrainChanged(owner)
end

--=========================================================
-- 돌아다니기
--=========================================================
local function nearestPlayerPosition(position, maxDistance)
	local best, bestDistance = nil, maxDistance or math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = root.Position
			end
		end
	end
	return best, bestDistance
end

local wanderRng = Random.new(os.clock() * 1000)

local function pickWanderTarget(rec)
	local info = Config.Animals[rec.species]
	local target

	if info.Rare then
		-- 희귀 동물은 사람이 가까이 오면 반대로 도망갑니다 (9단계)
		local playerPosition = nearestPlayerPosition(rec.pos, info.FleeRadius or 28)
		if playerPosition then
			local away = rec.pos - playerPosition
			if away.Magnitude < 0.5 then
				away = Vector3.new(1, 0, 0)
			end
			away = Vector3.new(away.X, 0, away.Z).Unit
			target = rec.pos + away * wanderRng:NextNumber(10, 16)
		else
			target = rec.pos
				+ Vector3.new(wanderRng:NextNumber(-14, 14), 0, wanderRng:NextNumber(-14, 14))
		end
	else
		target = rec.pos + Vector3.new(wanderRng:NextNumber(-6, 6), 0, wanderRng:NextNumber(-6, 6))
	end

	if rec.mode == "farm" and rec.farm then
		-- 농장 안 동물은 울타리 안에서만
		local half = rec.farm.half - 2
		target = Vector3.new(
			math.clamp(target.X, rec.farm.center.X - half, rec.farm.center.X + half),
			0,
			math.clamp(target.Z, rec.farm.center.Z - half, rec.farm.center.Z + half)
		)
	else
		-- 처음 있던 자리(home) 주변을 벗어나지 않게 (희귀 동물은 조금 더 멀리)
		local leash = rec.leash or 22
		if info.Rare then
			leash *= 2.5
		end
		local away = Vector3.new(target.X - rec.home.X, 0, target.Z - rec.home.Z)
		if away.Magnitude > leash then
			away = away.Unit * leash
			target = Vector3.new(rec.home.X + away.X, 0, rec.home.Z + away.Z)
		end
		target = clampToIsland(rec.island, target)
	end

	local distance = (target - rec.pos).Magnitude
	if distance < 0.6 then
		return
	end
	rec.hopFrom = rec.pos
	rec.hopTo = target
	rec.hopTime = 0
	rec.hopDuration = math.clamp(distance / math.max(1, rec.speed), 0.25, 1.2)
	local flat = Vector3.new(target.X - rec.pos.X, 0, target.Z - rec.pos.Z)
	if flat.Magnitude > 0.05 then
		rec.facing = flat.Unit
	end
end

local function updateWanderer(rec, dt)
	if rec.hopTo then
		rec.hopTime += dt
		local alpha = math.min(1, rec.hopTime / rec.hopDuration)
		rec.pos = rec.hopFrom:Lerp(rec.hopTo, alpha)
		local hop = math.sin(alpha * math.pi) * (Config.Train.HopHeight + 0.25)
		applyCFrame(rec, hop)
		if alpha >= 1 then
			rec.hopTo = nil
			local info = Config.Animals[rec.species]
			local idleRange = info.WanderIdle or { 2, 4 }
			rec.idle = wanderRng:NextNumber(idleRange[1], idleRange[2])
		end
		return
	end

	rec.idle -= dt
	if rec.idle <= 0 then
		pickWanderTarget(rec)
	end
end

--=========================================================
-- 매 프레임 갱신
--=========================================================
local function updateTrains(dt, clock)
	for _, owner in pairs(owners) do
		local position = owner.getPosition()
		if position and #owner.train > 0 then
			trailPush(owner, position)
			local snap = owner.snap
			owner.snap = false

			local alpha = snap and 1 or (1 - math.exp(-Config.Train.Smoothness * dt))
			local turn = math.min(1, Config.Train.TurnSpeed * dt)

			for index, rec in ipairs(owner.train) do
				local target, direction = trailSample(owner, index * Config.Train.Spacing)
				if target then
					-- 발자취는 플레이어 허리 높이이므로 땅 높이로 내려 줍니다
					local goal = Vector3.new(target.X, target.Y - Config.Train.RootHeight, target.Z)
					local previous = rec.pos
					rec.pos = previous:Lerp(goal, alpha)

					if direction and direction.Magnitude > 0.01 then
						local flat = Vector3.new(direction.X, 0, direction.Z)
						if flat.Magnitude > 0.01 then
							local blended = rec.facing:Lerp(flat.Unit, turn)
							if blended.Magnitude > 0.05 then
								rec.facing = blended.Unit
							else
								rec.facing = flat.Unit
							end
						end
					end

					local moved = (rec.pos - previous).Magnitude / math.max(dt, 1 / 240)
					local hop = 0
					if moved > 1.2 then
						hop = math.abs(math.sin(clock * Config.Train.HopSpeed + index * 0.8))
							* Config.Train.HopHeight
					end
					applyCFrame(rec, hop)
				end
			end
		elseif position then
			trailPush(owner, position)
		end
	end
end

local function updateWanderers(dt)
	for _, rec in pairs(records) do
		if rec.mode == "wander" or rec.mode == "farm" then
			updateWanderer(rec, dt)
		end
	end
end

--=========================================================
-- 줍기 (4·11단계)
--=========================================================
local function checkPickups()
	for _, player in ipairs(Players:GetPlayers()) do
		local owner = owners[ownerKeyForPlayer(player)]
		if owner then
			local position = owner.getPosition()
			if position and #owner.train < owner.maxLength() then
				local radius = DataService.pickupRadius(player)
				local best, bestDistance = nil, radius
				for _, rec in pairs(records) do
					if rec.mode == "wander" and not rec.consumed then
						local dy = math.abs(rec.pos.Y + rec.lift - position.Y)
						if dy < 10 then
							local flat = Vector3.new(rec.pos.X - position.X, 0, rec.pos.Z - position.Z)
							local distance = flat.Magnitude
							if distance <= bestDistance then
								bestDistance = distance
								best = rec
							end
						end
					end
				end
				if best then
					claim(owner, best)
				end
			end
		end
	end
end

--=========================================================
-- 마리 수 유지 (3·9단계)
--=========================================================
local function countSpecies(species)
	local wander, total = 0, 0
	for _, rec in pairs(records) do
		if rec.species == species then
			if rec.mode == "wander" then
				wander += 1
			end
			if rec.mode ~= "farm" and rec.mode ~= "gone" then
				total += 1
			end
		end
	end
	return wander, total
end

local function spawnSpecies(species, position, leash)
	local info = Config.Animals[species]
	local islandKey = info.Island
	local point = position or randomIslandPoint(islandKey, wanderRng)
	local rec = newRecord(species, point, islandKey, leash)
	if rec and info.Rare then
		Effects.toAll("rareAppeared", { species = species, island = islandKey })
		log("희귀 동물 등장:", species)
	end
	return rec
end

-- 스폰 정면에는 항상 동물 1마리가 보이게 합니다 (3단계)
local welcomeReadyAt = {}
local function maintainWelcomeAnimal(now)
	for _, islandKey in ipairs(Config.IslandOrder) do
		local island = Config.Islands[islandKey]
		local species = Config.DexOrder[islandKey] and Config.DexOrder[islandKey][1]
		if island.FirstAnimalPos and species then
			local found = false
			for _, rec in pairs(records) do
				if rec.mode == "wander" and rec.island == islandKey then
					if (rec.pos - island.FirstAnimalPos).Magnitude < 11 then
						found = true
						break
					end
				end
			end
			if found then
				welcomeReadyAt[islandKey] = nil
			else
				local readyAt = welcomeReadyAt[islandKey]
				local _, total = countSpecies(species)
				if not readyAt then
					welcomeReadyAt[islandKey] = now + 3
				elseif now >= readyAt and total < Config.Animals[species].Count * Config.MaxAnimalsPerSpecies then
					welcomeReadyAt[islandKey] = nil
					spawnSpecies(species, island.FirstAnimalPos, 7)
				end
			end
		end
	end
end

local function maintainPopulation()
	local now = os.clock()
	maintainWelcomeAnimal(now)
	for species, info in pairs(Config.Animals) do
		local wander, total = countSpecies(species)
		if info.Rare then
			if total == 0 then
				local readyAt = rareReadyAt[species]
				if not readyAt then
					rareReadyAt[species] = now + (info.RespawnDelay or 180)
				elseif now >= readyAt then
					rareReadyAt[species] = nil
					spawnSpecies(species)
				end
			else
				rareReadyAt[species] = nil
			end
		else
			local limit = info.Count * Config.MaxAnimalsPerSpecies
			if wander < info.Count and total < limit then
				local readyAt = pendingSpawn[species]
				if not readyAt then
					pendingSpawn[species] = now + Config.AnimalRespawnDelay
				elseif now >= readyAt then
					pendingSpawn[species] = nil
					spawnSpecies(species)
				end
			else
				pendingSpawn[species] = nil
			end
		end
	end
end

--=========================================================
-- 밖에서 쓰는 함수들
--=========================================================
function AnimalService.registerOwner(key, spec)
	local owner = {
		key = key,
		player = spec.player,
		getPosition = spec.getPosition,
		maxLength = spec.maxLength,
		train = {},
		snap = true,
	}
	trailReset(owner, spec.getPosition() or Vector3.zero)
	owners[key] = owner
	return owner
end

function AnimalService.unregisterOwner(key)
	local owner = owners[key]
	if not owner then
		return
	end
	releaseTrain(owner)
	owners[key] = nil
end

function AnimalService.getOwner(key)
	return owners[key]
end

function AnimalService.getTrain(player)
	local owner = owners[ownerKeyForPlayer(player)]
	return owner and owner.train or {}
end

function AnimalService.trainLength(player)
	return #AnimalService.getTrain(player)
end

function AnimalService.onTrainChanged(callback)
	table.insert(trainCallbacks, callback)
end

-- 기차 맨 앞 동물을 꺼냅니다 (배달용). 꺼낸 즉시 consumed 로 표시해
-- 같은 동물로 별을 두 번 받는 일이 없게 합니다 (5단계).
function AnimalService.takeFirst(ownerKey)
	local owner = owners[ownerKey]
	if not owner or #owner.train == 0 then
		return nil
	end
	local rec = table.remove(owner.train, 1)
	if not rec then
		return nil
	end
	rec.mode = "script"
	rec.ownerKey = nil
	rec.consumed = true
	if rec.model then
		rec.model:SetAttribute("Owned", false)
	end
	fireTrainChanged(owner)
	return rec
end

function AnimalService.setFarmMode(rec, center, half)
	rec.mode = "farm"
	rec.consumed = false
	rec.farm = { center = center, half = half }
	rec.idle = math.random() * 2
	rec.hopTo = nil
end

function AnimalService.releaseToWild(rec, position)
	rec.consumed = false
	releaseRecord(rec, position)
end

function AnimalService.destroyAnimal(rec)
	removeRecord(rec)
end

function AnimalService.setPosition(rec, position, hopHeight)
	rec.pos = Vector3.new(position.X, position.Y, position.Z)
	applyCFrame(rec, hopHeight or 0)
end

function AnimalService.findNearestWild(position, islandKey, maxDistance)
	local best, bestDistance = nil, maxDistance or math.huge
	for _, rec in pairs(records) do
		if rec.mode == "wander" and rec.island == islandKey and not rec.consumed then
			local distance = (rec.pos - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = rec
			end
		end
	end
	return best, bestDistance
end

function AnimalService.claimFor(ownerKey, rec)
	local owner = owners[ownerKey]
	if not owner then
		return false
	end
	return claim(owner, rec)
end

function AnimalService.releaseOwnerTrain(ownerKey)
	local owner = owners[ownerKey]
	if owner then
		releaseTrain(owner)
	end
end

function AnimalService.Start()
	animalsFolder = workspace:FindFirstChild("Animals")
	if animalsFolder then
		animalsFolder:Destroy()
	end
	animalsFolder = Instance.new("Folder")
	animalsFolder.Name = "Animals"
	animalsFolder.Parent = workspace

	-- 3단계 요구사항 : 모델 원본을 ServerStorage/AnimalModels 에 보관
	local templates = ServerStorage:FindFirstChild("AnimalModels")
	if templates then
		templates:Destroy()
	end
	templates = Instance.new("Folder")
	templates.Name = "AnimalModels"
	templates.Parent = ServerStorage
	for species in pairs(Config.Animals) do
		local model = ModelFactory.buildAnimal(species)
		if model then
			model.Name = species
			model.Parent = templates
		end
	end

	-- 플레이어를 기차 주인으로 등록
	local function addPlayer(player)
		local key = ownerKeyForPlayer(player)
		AnimalService.registerOwner(key, {
			player = player,
			getPosition = function()
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				return root and root.Position or nil
			end,
			maxLength = function()
				return DataService.maxTrain(player)
			end,
		})
		player.CharacterAdded:Connect(function()
			local owner = owners[key]
			if owner then
				owner.snap = true
			end
		end)
	end

	Players.PlayerAdded:Connect(addPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		addPlayer(player)
	end

	-- 나간 플레이어의 동물은 주인 없는 상태로 되돌립니다 (4단계)
	Players.PlayerRemoving:Connect(function(player)
		AnimalService.unregisterOwner(ownerKeyForPlayer(player))
	end)

	-- 첫 동물은 스폰 정면에 (접속하자마자 보이도록)
	for _, key in ipairs(Config.IslandOrder) do
		local island = Config.Islands[key]
		local first = Config.DexOrder[key] and Config.DexOrder[key][1]
		if island.FirstAnimalPos and first then
			newRecord(first, island.FirstAnimalPos, key, 7)
		end
	end

	-- 나머지 동물 채우기
	for species, info in pairs(Config.Animals) do
		if not info.Rare then
			local _, total = countSpecies(species)
			for _ = total + 1, info.Count do
				spawnSpecies(species)
			end
		else
			rareReadyAt[species] = os.clock() + (info.RespawnDelay or 180)
		end
	end

	-- 갱신 루프
	local pickupClock = 0
	local wanderClock = 0
	local maintainClock = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		updateTrains(dt, now)

		wanderClock += dt
		if wanderClock >= 1 / 15 then
			updateWanderers(wanderClock)
			wanderClock = 0
		end

		pickupClock += dt
		if pickupClock >= Config.Pickup.CheckInterval then
			pickupClock = 0
			checkPickups()
		end

		maintainClock += dt
		if maintainClock >= 1 then
			maintainClock = 0
			maintainPopulation()
		end
	end)

	log("시작. 동물 수", (function()
		local count = 0
		for _ in pairs(records) do
			count += 1
		end
		return count
	end)())
end

return AnimalService
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "DataService", [==[
-- 8단계 : 플레이어 데이터 저장/불러오기.
-- 별, 열린 섬, 도감, 최고 기차 길이, 업그레이드 단계를 저장합니다.
-- 현재 기차에 달린 동물은 저장하지 않습니다 (다시 접속하면 빈 기차).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))

local DataService = {}

local store = nil
local profiles = {} -- [Player] = profile
local changedCallbacks = {}
local apiWarned = false

local function log(...)
	if Config.Debug then
		print("[데이터]", ...)
	end
end

local function defaultData()
	return {
		version = Config.Data.Version,
		stars = 0, -- 지금 가진 별 (업그레이드로 씁니다)
		totalStars = 0, -- 지금까지 모은 총 별 (섬 해금 기준, 11단계)
		islands = { [Config.StartIsland] = true },
		dex = {},
		bestTrain = 0,
		upgrades = { Speed = 0, Train = 0, Magnet = 0 },
		prefs = { music = true },
	}
end

-- 저장 구조가 바뀌어도 안전하게 (빠진 값은 기본값으로 채움)
local function migrate(data)
	local base = defaultData()
	if type(data) ~= "table" then
		return base
	end

	for key, value in pairs(base) do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) ~= "table" then
			data[key] = value
		end
	end

	for key, value in pairs(base.upgrades) do
		if type(data.upgrades[key]) ~= "number" then
			data.upgrades[key] = value
		end
	end
	if type(data.prefs.music) ~= "boolean" then
		data.prefs.music = true
	end
	-- 1버전에는 totalStars 가 없었으므로 현재 별을 총 별로 인정해 줍니다.
	if (data.version or 1) < 2 then
		data.totalStars = math.max(data.totalStars or 0, data.stars or 0)
	end
	data.version = Config.Data.Version
	return data
end

local function warnAboutApi(err)
	if apiWarned then
		return
	end
	apiWarned = true
	warn("[데이터] 저장 기능을 쓸 수 없습니다: " .. tostring(err))
	warn("[데이터] Studio 에서 테스트 중이라면 다음을 켜 주세요:")
	warn("[데이터]   Studio 상단 HOME → Game Settings → Security →")
	warn("[데이터]   'Enable Studio Access to API Services' 를 켜고 저장(Save)")
	warn("[데이터] 켜지 않아도 게임은 돌아가지만, 나갔다 오면 별이 0이 됩니다.")
end

local function fireChanged(player)
	for _, callback in ipairs(changedCallbacks) do
		task.spawn(callback, player)
	end
end

local function keyFor(player)
	return "P_" .. player.UserId
end

local function pushLeaderstats(player, profile)
	local stars = profile.starValue
	if stars then
		stars.Value = profile.data.stars
	end
end

local function loadProfile(player)
	local profile = {
		data = defaultData(),
		loaded = false,
		noSave = false,
		dirty = false,
	}
	profiles[player] = profile

	-- leaderstats (5단계 : 별 표시)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local stars = Instance.new("IntValue")
	stars.Name = "⭐"
	stars.Value = 0
	stars.Parent = leaderstats
	leaderstats.Parent = player
	profile.starValue = stars

	local loaded = nil
	if store then
		for attempt = 1, Config.Data.MaxRetries do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				loaded = result
				break
			end
			warnAboutApi(result)
			profile.noSave = true
			task.wait(Config.Data.RetryWait * attempt)
		end
	else
		profile.noSave = true
	end

	if not profiles[player] then
		return -- 불러오는 동안 나갔음
	end

	profile.data = migrate(loaded)
	profile.loaded = true
	pushLeaderstats(player, profile)
	log(player.Name, "불러오기 완료. 별", profile.data.stars, "총", profile.data.totalStars)
	fireChanged(player)
end

local function saveProfile(player, isFinal)
	local profile = profiles[player]
	if not profile or not profile.loaded or profile.noSave or not store then
		return false
	end
	if profile.saving then
		return false
	end
	profile.saving = true

	local snapshot = profile.data
	local saved = false
	for attempt = 1, Config.Data.MaxRetries do
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function()
				return snapshot
			end)
		end)
		if ok then
			saved = true
			break
		end
		warn("[데이터] 저장 실패(" .. attempt .. "회): " .. tostring(err))
		if not isFinal then
			task.wait(Config.Data.RetryWait * attempt)
		end
	end

	profile.saving = false
	if saved then
		log(player.Name, "저장 완료")
	end
	return saved
end

--=========================================================
-- 밖에서 쓰는 함수들
--=========================================================
function DataService.get(player)
	local profile = profiles[player]
	if profile and profile.loaded then
		return profile.data
	end
	return nil
end

function DataService.isLoaded(player)
	local profile = profiles[player]
	return profile ~= nil and profile.loaded
end

function DataService.canSave(player)
	local profile = profiles[player]
	return profile ~= nil and profile.loaded and not profile.noSave
end

function DataService.onChanged(callback)
	table.insert(changedCallbacks, callback)
end

function DataService.addStars(player, amount)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return false
	end
	data.stars += amount
	data.totalStars += amount
	pushLeaderstats(player, profiles[player])
	fireChanged(player)
	return true
end

function DataService.spendStars(player, amount)
	local data = DataService.get(player)
	if not data or data.stars < amount then
		return false
	end
	data.stars -= amount
	pushLeaderstats(player, profiles[player])
	fireChanged(player)
	return true
end

function DataService.markDex(player, species)
	local data = DataService.get(player)
	if not data then
		return false
	end
	if data.dex[species] then
		return false
	end
	data.dex[species] = true
	fireChanged(player)
	return true -- 처음 데려온 동물
end

function DataService.hasIsland(player, islandKey)
	local data = DataService.get(player)
	if not data then
		return false
	end
	return data.islands[islandKey] == true
end

function DataService.unlockIsland(player, islandKey)
	local data = DataService.get(player)
	if not data or data.islands[islandKey] then
		return false
	end
	data.islands[islandKey] = true
	fireChanged(player)
	return true
end

function DataService.getUpgrade(player, kind)
	local data = DataService.get(player)
	if not data then
		return 0
	end
	return data.upgrades[kind] or 0
end

function DataService.setUpgrade(player, kind, level)
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.upgrades[kind] = level
	fireChanged(player)
	return true
end

function DataService.noteTrainLength(player, length)
	local data = DataService.get(player)
	if not data then
		return
	end
	if length > (data.bestTrain or 0) then
		data.bestTrain = length
		fireChanged(player)
	end
end

function DataService.setPref(player, key, value)
	local data = DataService.get(player)
	if not data then
		return
	end
	if key == "music" and type(value) == "boolean" then
		data.prefs.music = value
		fireChanged(player)
	end
end

function DataService.maxTrain(player)
	return Rules.maxTrain(DataService.getUpgrade(player, "Train"))
end

function DataService.pickupRadius(player)
	return Rules.pickupRadius(DataService.getUpgrade(player, "Magnet"))
end

function DataService.walkSpeed(player)
	return Rules.walkSpeed(DataService.getUpgrade(player, "Speed"))
end

function DataService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warnAboutApi(result)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player, false)
		profiles[player] = nil
	end)

	-- 2분마다 자동 저장
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutoSaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(saveProfile, player, false)
			end
		end
	end)

	-- 서버가 닫힐 때
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			saveProfile(player, true)
		end
		task.wait(1)
	end)

	log("시작")
end

return DataService
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "Effects", [==[
-- 연출 담당 : 파티클, 소리, 별 튀어오르기.
-- 클라이언트에서 처리할 것은 Effect 리모트로 신호만 보냅니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))

local Effects = {}
local remote

function Effects.toPlayer(player, kind, payload)
	if remote and player and player.Parent then
		remote:FireClient(player, kind, payload or {})
	end
end

function Effects.toAll(kind, payload)
	if remote then
		remote:FireAllClients(kind, payload or {})
	end
end

-- 그 자리에서 들리는 소리 (근처 사람 모두 들림)
function Effects.sound3d(position: Vector3, name: string, pitchJitter: number?)
	local def = Config.Sounds[name]
	if not def or def.Id == "" then
		return
	end
	local anchor = ModelFactory.newPart({
		Name = "SoundAnchor",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
	})
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume or 0.5
	local pitch = def.Pitch or 1
	if pitchJitter then
		pitch += (math.random() - 0.5) * 2 * pitchJitter
	end
	sound.PlaybackSpeed = math.max(0.25, pitch)
	sound.RollOffMaxDistance = 90
	sound.RollOffMinDistance = 8
	sound.PlayOnRemove = true -- 지우는 순간 그 자리에서 재생됩니다
	sound.Parent = anchor
	sound:Destroy()

	task.delay(4, function()
		anchor:Destroy()
	end)
end

function Effects.hearts(position: Vector3)
	ModelFactory.burst(position, Config.Colors.Pink, 12)
end

function Effects.starBurst(position: Vector3)
	ModelFactory.burst(position, Config.Colors.Star, 18)
end

function Effects.fireworks(position: Vector3)
	for index = 1, 4 do
		task.delay((index - 1) * 0.16, function()
			local offset = Vector3.new(math.random(-8, 8), math.random(4, 11), math.random(-4, 4))
			ModelFactory.burst(position + offset, Color3.fromHSV(math.random(), 0.55, 1), 26)
		end)
	end
end

-- 머리 위로 별이 통통 튀어 오르는 연출 (5단계)
function Effects.starPop(character: Model)
	local head = character:FindFirstChild("Head") or character.PrimaryPart
	if not head then
		return
	end
	local star = ModelFactory.buildStar()
	star.Name = "PopStar"
	local startCFrame = CFrame.new(head.Position + Vector3.new(math.random(-1, 1), 1.6, 0))
	star:PivotTo(startCFrame)
	star.Parent = workspace

	task.spawn(function()
		local duration = 0.85
		local startedAt = os.clock()
		while true do
			local alpha = (os.clock() - startedAt) / duration
			if alpha >= 1 or not star.Parent then
				break
			end
			local height = math.sin(alpha * math.pi) * 5.5 + alpha * 1.5
			star:PivotTo(
				startCFrame
					* CFrame.new(0, height, 0)
					* CFrame.Angles(0, alpha * math.pi * 3, alpha * math.pi)
			)
			for _, piece in ipairs(star:GetChildren()) do
				if piece:IsA("BasePart") then
					piece.Transparency = math.max(0, (alpha - 0.6) / 0.4)
				end
			end
			task.wait()
		end
		star:Destroy()
	end)
end

function Effects.Start()
	remote = Net.event(Config.Remotes.Effect)
end

return Effects
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "FarmService", [==[
-- 5·9단계 : 농장 배달, 별 주기, 도감 기록.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local DataService = require(script.Parent.DataService)
local AnimalService = require(script.Parent.AnimalService)
local WorldService = require(script.Parent.WorldService)
local Effects = require(script.Parent.Effects)

local FarmService = {}

local nextDeliveryAt = {} -- [player] = 다음 배달 가능 시각
local deliveredCount = {} -- [islandKey] = 지금까지 농장에 들어간 총 마리 수
local rng = Random.new()

local function log(...)
	if Config.Debug then
		print("[농장]", ...)
	end
end

local function visibleFarmCount(islandKey)
	local inside = WorldService.getFarmInside(islandKey)
	if not inside then
		return 0
	end
	return #inside:GetChildren()
end

-- 동물이 농장 안으로 폴짝폴짝 들어가는 연출
local function hopIntoFarm(rec, island)
	local inside = WorldService.getFarmInside(island.Key)
	local half = island.FarmSize / 2
	local target = Vector3.new(
		island.FarmCenter.X + rng:NextNumber(-half + 4, half - 4),
		0,
		island.FarmCenter.Z + rng:NextNumber(-half + 4, half - 4)
	)
	local from = rec.pos

	task.spawn(function()
		local duration = Config.Farm.HopInDuration
		local startedAt = os.clock()
		while rec.mode == "script" and rec.model do
			local alpha = (os.clock() - startedAt) / duration
			if alpha >= 1 then
				break
			end
			local position = from:Lerp(target, alpha)
			local hop = math.abs(math.sin(alpha * math.pi * 2.5)) * 1.6
			AnimalService.setPosition(rec, position, hop)
			task.wait()
		end

		if not rec.model then
			return
		end
		AnimalService.setPosition(rec, target, 0)

		if visibleFarmCount(island.Key) < Config.Farm.VisibleCapacity then
			if inside then
				rec.model.Parent = inside
			end
			AnimalService.setFarmMode(rec, island.FarmCenter, half)
		else
			-- 30마리가 넘으면 숫자로만 계산하고 모델은 지웁니다 (성능)
			AnimalService.destroyAnimal(rec)
		end
	end)
end

local function deliverOne(player, island, zone)
	local key = AnimalService.playerKey(player)
	local rec = AnimalService.takeFirst(key)
	if not rec then
		return false
	end

	local info = Config.Animals[rec.species]
	local reward = info and info.Reward or 1

	-- 별 주기는 서버에서만 (5단계)
	DataService.addStars(player, reward)
	deliveredCount[island.Key] = (deliveredCount[island.Key] or 0) + 1

	local isNew = DataService.markDex(player, rec.species)

	local character = player.Character
	if character then
		Effects.starPop(character)
	end
	Effects.starBurst(zone.Position + Vector3.new(0, 1.5, 0))
	Effects.sound3d(zone.Position, "Deliver", 0.08)
	Effects.toPlayer(player, "deliver", {
		reward = reward,
		species = rec.species,
		isNew = isNew,
	})
	if isNew then
		Effects.toPlayer(player, "newAnimal", { species = rec.species })
		log(player.Name, "도감 새 동물:", rec.species)
	end

	hopIntoFarm(rec, island)
	return true
end

function FarmService.getDeliveredCount(islandKey)
	return deliveredCount[islandKey] or 0
end

function FarmService.Start()
	Players.PlayerRemoving:Connect(function(player)
		nextDeliveryAt[player] = nil
	end)

	local checkClock = 0
	RunService.Heartbeat:Connect(function(dt)
		checkClock += dt
		if checkClock < 0.15 then
			return
		end
		checkClock = 0

		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			-- 데이터를 아직 못 불러왔으면 배달하지 않습니다 (8단계)
			if DataService.isLoaded(player) and (nextDeliveryAt[player] or 0) <= now then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and AnimalService.trainLength(player) > 0 then
					for _, islandKey in ipairs(Config.IslandOrder) do
						local island = Config.Islands[islandKey]
						local zone = WorldService.getDeliveryZone(islandKey)
						if zone then
							local flat = Vector3.new(
								root.Position.X - zone.Position.X,
								0,
								root.Position.Z - zone.Position.Z
							)
							if flat.Magnitude <= Config.Farm.ZoneRadius
								and math.abs(root.Position.Y - zone.Position.Y) < 12
							then
								if deliverOne(player, island, zone) then
									nextDeliveryAt[player] = now + Config.Farm.DeliveryInterval
								end
								break
							end
						end
					end
				end
			end
		end
	end)

	log("시작")
end

return FarmService
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "FoxService", [==[
-- 10단계 : NPC 여우 기차. 혼자 플레이해도 맵이 북적이게 만듭니다.
-- 플레이어의 동물은 절대 빼앗지 않습니다 (주인 없는 동물만 모음).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local AnimalService = require(script.Parent.AnimalService)

local FoxService = {}

local foxes = {}
local foxFolder
local rng = Random.new(20240521)

local function log(...)
	if Config.Debug then
		print("[여우]", ...)
	end
end

local function clampToIsland(islandKey, position)
	local island = Config.Islands[islandKey]
	local offset = Vector3.new(position.X - island.Center.X, 0, position.Z - island.Center.Z)
	local distance = offset.Magnitude
	local maxDistance = island.Radius - 8
	if distance > maxDistance then
		offset = offset.Unit * maxDistance
	end
	return Vector3.new(island.Center.X + offset.X, 0, island.Center.Z + offset.Z)
end

local function applyFox(fox, hop)
	local look = fox.facing
	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, 1)
	else
		look = look.Unit
	end
	local base = fox.pos + Vector3.new(0, fox.lift + hop, 0)
	local pivot = CFrame.lookAt(base, base + look)
	fox.model:PivotTo(pivot)

	-- 손 흔들기 (플레이어 근처에서)
	-- 팔은 매 프레임 기준 위치에서 다시 계산합니다 (PivotTo 와 어긋나지 않게)
	if fox.arm and fox.armOffset then
		local now = os.clock()
		if fox.waveUntil and now < fox.waveUntil then
			local swing = math.sin(now * 14)
			fox.arm.CFrame = pivot * fox.armOffset * CFrame.Angles(0, 0, -1.2 + swing * 0.5)
		else
			fox.arm.CFrame = pivot * fox.armOffset
		end
	end
end

local function spawnFox(islandKey, index)
	local island = Config.Islands[islandKey]
	local model = ModelFactory.buildFox()
	model.Name = "Fox_" .. islandKey .. "_" .. index
	model.Parent = foxFolder

	local fox = {
		key = "F_" .. islandKey .. "_" .. index,
		island = islandKey,
		model = model,
		arm = model:FindFirstChild("WaveArm"),
		lift = ModelFactory.Lift.Fox,
		pos = clampToIsland(islandKey, island.FoxDen + Vector3.new(6, 0, 10)),
		facing = Vector3.new(0, 0, 1),
		state = "seek",
		target = nil,
		targetRec = nil,
		nextThink = 0,
		nextWave = 0,
		waveUntil = nil,
	}
	if fox.arm then
		fox.armOffset = CFrame.new(fox.arm.Position) -- 원점 기준 위치 (조립 직후라 그대로 씀)
	end

	-- 여우도 동물 기차의 주인이 됩니다
	AnimalService.registerOwner(fox.key, {
		player = nil,
		getPosition = function()
			return fox.pos + Vector3.new(0, Config.Train.RootHeight, 0)
		end,
		maxLength = function()
			return Config.Fox.MaxTrain
		end,
	})

	applyFox(fox, 0)
	table.insert(foxes, fox)
	return fox
end

local function think(fox)
	local owner = AnimalService.getOwner(fox.key)
	local trainSize = owner and #owner.train or 0

	if fox.state == "seek" and trainSize >= Config.Fox.MaxTrain then
		fox.state = "return"
	end

	if fox.state == "return" then
		fox.target = Config.Islands[fox.island].FoxDen
		fox.targetRec = nil
		return
	end

	-- 주인 없는 동물 중 가장 가까운 것
	local rec = AnimalService.findNearestWild(fox.pos, fox.island, 200)
	if rec then
		fox.targetRec = rec
		fox.target = rec.pos
	else
		fox.targetRec = nil
		local island = Config.Islands[fox.island]
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(island.WanderBand[1], island.WanderBand[2])
		fox.target = clampToIsland(fox.island, island.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
	end
end

local function updateFox(fox, dt, now)
	-- 목표는 자주 계산하지 않습니다 (성능)
	if now >= fox.nextThink then
		fox.nextThink = now + Config.Fox.ThinkInterval
		think(fox)
	end

	-- 쫓던 동물을 누가 먼저 데려갔으면 다시 고릅니다
	if fox.targetRec then
		if fox.targetRec.mode ~= "wander" then
			fox.targetRec = nil
			fox.nextThink = 0
		else
			fox.target = fox.targetRec.pos
		end
	end

	local target = fox.target
	if target then
		local flat = Vector3.new(target.X - fox.pos.X, 0, target.Z - fox.pos.Z)
		local distance = flat.Magnitude
		if distance > 0.6 then
			local step = math.min(distance, Config.Fox.Speed * dt)
			local direction = flat.Unit
			fox.pos = clampToIsland(fox.island, fox.pos + direction * step)
			fox.facing = fox.facing:Lerp(direction, math.min(1, 6 * dt))
			if fox.facing.Magnitude < 0.05 then
				fox.facing = direction
			end
			fox.moving = true
		else
			fox.moving = false
		end

		-- 동물 잡기
		if fox.targetRec and distance <= Config.Fox.CatchRadius then
			AnimalService.claimFor(fox.key, fox.targetRec)
			fox.targetRec = nil
			fox.nextThink = 0
		end

		-- 굴에 도착하면 동물을 내려놓습니다
		if fox.state == "return" then
			local den = Config.Islands[fox.island].FoxDen
			if (Vector3.new(den.X - fox.pos.X, 0, den.Z - fox.pos.Z)).Magnitude <= Config.Fox.DenRadius then
				AnimalService.releaseOwnerTrain(fox.key)
				fox.state = "seek"
				fox.nextThink = 0
			end
		end
	end

	-- 플레이어 근처를 지나가면 손을 흔듭니다
	if now >= fox.nextWave then
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - fox.pos).Magnitude < Config.Fox.WaveRadius then
				fox.nextWave = now + Config.Fox.WaveCooldown
				fox.waveUntil = now + 1.4
				break
			end
		end
	end

	local hop = 0
	if fox.moving then
		hop = math.abs(math.sin(now * 8)) * 0.35
	end
	applyFox(fox, hop)
end

function FoxService.Start()
	foxFolder = workspace:FindFirstChild("Foxes")
	if foxFolder then
		foxFolder:Destroy()
	end
	foxFolder = Instance.new("Folder")
	foxFolder.Name = "Foxes"
	foxFolder.Parent = workspace

	for islandKey, count in pairs(Config.Fox.PerIsland) do
		if Config.Islands[islandKey] then
			for index = 1, count do
				spawnFox(islandKey, index)
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, fox in ipairs(foxes) do
			updateFox(fox, dt, now)
		end
	end)

	log("시작. 마리 수", #foxes)
end

return FoxService
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "GateService", [==[
-- 7단계 : 별 문. 지금까지 모은 총 별이 기준이고, 별은 차감하지 않습니다.
-- 문은 플레이어마다 따로 열립니다 (충돌 그룹으로 그 사람만 통과).
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local DataService = require(script.Parent.DataService)
local Effects = require(script.Parent.Effects)

local GateService = {}

local GROUP_BLOCK = "StarGateBlock"
local GROUP_PASS = "StarGatePass"
local LOCKED_ISLAND = "Snow"

local gateFolder
local gatePosition

local function log(...)
	if Config.Debug then
		print("[별문]", ...)
	end
end

local function registerGroups()
	local function register(name)
		local ok = pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
		if not ok then
			pcall(function()
				PhysicsService:CreateCollisionGroup(name)
			end)
		end
	end
	register(GROUP_BLOCK)
	register(GROUP_PASS)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP_BLOCK, GROUP_PASS, false)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP_BLOCK, "Default", true)
	end)
end

local function buildGate()
	local bridge = Config.Bridge
	local halfWidth = bridge.GateWidth / 2
	gatePosition = Vector3.new(0, 0, bridge.GateZ)

	gateFolder = Instance.new("Folder")
	gateFolder.Name = "StarGate"
	gateFolder.Parent = workspace:WaitForChild("World")
	gateFolder:SetAttribute("Island", LOCKED_ISLAND)
	gateFolder:SetAttribute("Cost", Config.Islands[LOCKED_ISLAND].UnlockCost)

	local function piece(name, size, position, color, options)
		options = options or {}
		local part = ModelFactory.newPart({
			Name = name,
			Size = size,
			Color = color,
			Material = options.Material,
			Shape = options.Shape,
			Transparency = options.Transparency,
			CanCollide = options.CanCollide == true,
			CastShadow = true,
		})
		part.CFrame = CFrame.new(position)
		part.Parent = gateFolder
		return part
	end

	-- 기둥 2개 + 위 아치
	for _, side in ipairs({ -1, 1 }) do
		piece("Pillar", Vector3.new(3, bridge.GateHeight, 3), Vector3.new(side * halfWidth, bridge.GateHeight / 2, bridge.GateZ), Config.Colors.WoodDark, { CanCollide = true })
		piece("PillarTop", Vector3.new(4, 1, 4), Vector3.new(side * halfWidth, bridge.GateHeight + 0.5, bridge.GateZ), Color3.fromRGB(255, 214, 140))
	end
	piece("Beam", Vector3.new(bridge.GateWidth + 6, 2.4, 3), Vector3.new(0, bridge.GateHeight + 1.8, bridge.GateZ), Config.Colors.Wood)
	piece("BeamTrim", Vector3.new(bridge.GateWidth + 8, 0.8, 3.6), Vector3.new(0, bridge.GateHeight + 3.2, bridge.GateZ), Color3.fromRGB(255, 226, 150))

	-- 가운데 큰 별
	local star = ModelFactory.buildStar()
	ModelFactory.scaleModel(star, 3.4)
	star:PivotTo(CFrame.new(0, bridge.GateHeight + 6.2, bridge.GateZ))
	star.Name = "GateStar"
	star.Parent = gateFolder
	if star.PrimaryPart then
		ModelFactory.addSparkles(star.PrimaryPart, Config.Colors.Star, 14)
	end

	-- 필요한 별 개수 (숫자만)
	local signPart = piece("Sign", Vector3.new(1, 1, 1), Vector3.new(0, bridge.GateHeight + 1.8, bridge.GateZ), Color3.new(1, 1, 1), { Transparency = 1 })
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CostGui"
	billboard.Size = UDim2.fromScale(9, 6)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 260
	billboard.Adornee = signPart
	billboard.Parent = signPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = tostring(Config.Islands[LOCKED_ISLAND].UnlockCost)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(120, 92, 40)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard

	-- 보이지 않는 막이 : 못 여는 사람만 막습니다
	local barrier = piece("Barrier", Vector3.new(bridge.GateWidth, 16, 2), Vector3.new(0, 8, bridge.GateZ - 1), Color3.new(1, 1, 1), {
		CanCollide = true,
		Transparency = 1,
	})
	pcall(function()
		barrier.CollisionGroup = GROUP_BLOCK
	end)
	barrier.CastShadow = false
end

local function setCharacterGroup(character, groupName)
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("BasePart") then
			pcall(function()
				item.CollisionGroup = groupName
			end)
		end
	end
end

local function applyPass(player)
	local character = player.Character
	if not character then
		return
	end
	local unlocked = DataService.hasIsland(player, LOCKED_ISLAND)
	setCharacterGroup(character, unlocked and GROUP_PASS or "Default")
end

-- 총 별이 충분하면 문을 엽니다 (별은 쓰지 않습니다)
local function evaluate(player)
	if not DataService.isLoaded(player) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end

	for _, islandKey in ipairs(Config.IslandOrder) do
		local island = Config.Islands[islandKey]
		if island.UnlockCost > 0 and not data.islands[islandKey] then
			if data.totalStars >= island.UnlockCost then
				if DataService.unlockIsland(player, islandKey) then
					applyPass(player)
					Effects.fireworks(gatePosition + Vector3.new(0, Config.Bridge.GateHeight, 0))
					Effects.sound3d(gatePosition + Vector3.new(0, 6, 0), "Unlock")
					Effects.toPlayer(player, "gateOpen", { island = islandKey })
					log(player.Name, islandKey, "섬 열림")
				end
			end
		end
	end
	applyPass(player)
end

function GateService.Start()
	registerGroups()
	buildGate()

	local function hookPlayer(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			applyPass(player)
			character.DescendantAdded:Connect(function(item)
				if item:IsA("BasePart") and DataService.hasIsland(player, LOCKED_ISLAND) then
					pcall(function()
						item.CollisionGroup = GROUP_PASS
					end)
				end
			end)
		end)
		if player.Character then
			applyPass(player)
		end
		task.delay(1, function()
			evaluate(player)
		end)
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end

	-- 별이 늘어날 때마다 문 조건을 다시 봅니다
	DataService.onChanged(function(player)
		evaluate(player)
	end)

	-- 혹시 막이를 통과했더라도 서버가 되돌려 보냅니다 (서버가 최종 판단)
	task.spawn(function()
		while true do
			task.wait(0.4)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Z < Config.Bridge.BlockZ then
					if not DataService.hasIsland(player, LOCKED_ISLAND) then
						character:PivotTo(CFrame.new(0, 4, Config.Bridge.GateZ + 10))
						Effects.toPlayer(player, "gateLocked", {})
					end
				end
			end
		end
	end)

	log("시작")
end

return GateService
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "MetricsService", [==[
-- 12단계 : "10초 테스트" 자동 측정.
-- Studio 에서 플레이할 때 출력 창에 걸린 시간을 찍어 줍니다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local DataService = require(script.Parent.DataService)
local AnimalService = require(script.Parent.AnimalService)

local MetricsService = {}

local marks = {}

local function cheapestUpgradePrice()
	local cheapest = math.huge
	for _, kind in ipairs(Config.Upgrades.Order) do
		local price = Rules.nextPrice(kind, 0)
		if price and price < cheapest then
			cheapest = price
		end
	end
	return cheapest
end

local function report(player, label, target)
	local mark = marks[player]
	if not mark then
		return
	end
	local seconds = os.clock() - mark.joined
	local elapsed = string.format("%.1f초", seconds)
	local judge = seconds <= target and "목표 안에 들어옴 ✅" or ("목표(" .. target .. "초) 초과 ⚠️")
	print(string.format("[측정] %s · %s: %s (%s)", player.Name, label, elapsed, judge))
end

function MetricsService.Start()
	local function watch(player)
		marks[player] = { joined = os.clock() }
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		marks[player] = nil
	end)

	AnimalService.onTrainChanged(function(player)
		local mark = marks[player]
		if mark and not mark.firstAnimal and AnimalService.trainLength(player) > 0 then
			mark.firstAnimal = true
			report(player, "첫 동물 만나기", 10)
		end
	end)

	DataService.onChanged(function(player)
		local mark = marks[player]
		local data = DataService.get(player)
		if not mark or not data then
			return
		end
		if not mark.firstStar and data.totalStars > 0 then
			mark.firstStar = true
			report(player, "첫 별 받기", 60)
		end
		if not mark.firstUpgrade and data.stars >= cheapestUpgradePrice() then
			mark.firstUpgrade = true
			report(player, "첫 업그레이드 가능", 180)
		end
	end)

	if Config.Debug then
		print("[측정] 시작 (접속 → 첫 동물 / 첫 별 / 첫 업그레이드 시간을 잽니다)")
	end
end

return MetricsService
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "ShopService", [==[
-- 11단계 : 별로 사는 업그레이드 가판대 (신발 / 기차 / 자석)
-- 구매 판단은 모두 서버에서 하고, 단계는 저장 데이터에 남습니다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local DataService = require(script.Parent.DataService)
local Effects = require(script.Parent.Effects)

local ShopService = {}

local padColors = {
	Speed = Color3.fromRGB(150, 205, 255),
	Train = Color3.fromRGB(255, 175, 190),
	Magnet = Color3.fromRGB(255, 226, 140),
}

local icons = {}
local cooldown = {}

local function log(...)
	if Config.Debug then
		print("[상점]", ...)
	end
end

local function makePart(name, size, position, color, parent, options)
	options = options or {}
	local part = ModelFactory.newPart({
		Name = name,
		Size = size,
		Color = color,
		Material = options.Material,
		Shape = options.Shape,
		CanCollide = options.CanCollide == true,
		CanTouch = options.CanTouch == true,
		CastShadow = options.CastShadow ~= false,
	})
	part.CFrame = CFrame.new(position)
	part.Parent = parent
	return part
end

local function applyToCharacter(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = DataService.walkSpeed(player)
	humanoid.JumpPower = Config.Player.JumpPower
	humanoid.UseJumpPower = true
end
ShopService.applyToCharacter = applyToCharacter

local function refreshSpeed(player)
	local character = player.Character
	if character then
		applyToCharacter(player, character)
	end
end

local function tryBuy(player, kind, pad)
	local now = os.clock()
	local perPlayer = cooldown[player]
	if not perPlayer then
		perPlayer = {}
		cooldown[player] = perPlayer
	end
	-- 발판을 밟고 있는 동안 Touched 가 여러 번 오므로 발판마다 잠깐 막습니다
	if (perPlayer[kind] or 0) > now then
		return
	end
	perPlayer[kind] = now + 0.7

	if not DataService.isLoaded(player) then
		return
	end

	local level = DataService.getUpgrade(player, kind)
	local price = Rules.nextPrice(kind, level)
	if not price then
		Effects.toPlayer(player, "buyMax", { kind = kind })
		return
	end

	if not DataService.spendStars(player, price) then
		-- 별이 모자라면 아무 일도 일어나지 않습니다 (잃는 것 없음)
		Effects.toPlayer(player, "buyFail", { kind = kind, price = price })
		Effects.sound3d(pad.Position + Vector3.new(0, 2, 0), "BuyFail")
		return
	end

	DataService.setUpgrade(player, kind, level + 1)
	if kind == "Speed" then
		refreshSpeed(player)
	end

	Effects.toPlayer(player, "buyOk", { kind = kind, level = level + 1 })
	Effects.starBurst(pad.Position + Vector3.new(0, 2.5, 0))
	Effects.sound3d(pad.Position + Vector3.new(0, 2, 0), "BuyOk")
	log(player.Name, kind, "→", level + 1, "단계")
end

local function buildStand()
	local island = Config.Islands[Config.StartIsland]
	if not island.ShopPos then
		return
	end
	local parent = workspace:WaitForChild("World"):WaitForChild(Config.StartIsland)

	local folder = Instance.new("Folder")
	folder.Name = "Shop"
	folder.Parent = parent

	local base = island.ShopPos

	-- 가판대 (뒤쪽 나무 카운터)
	makePart("Counter", Vector3.new(20, 3, 3), base + Vector3.new(0, 1.5, -1.5), Config.Colors.Wood, folder, { CanCollide = true })
	makePart("CounterTop", Vector3.new(21, 0.6, 4), base + Vector3.new(0, 3.2, -1.5), Config.Colors.WoodDark, folder, { CanCollide = true })
	for _, side in ipairs({ -1, 1 }) do
		makePart("Roof", Vector3.new(1, 6, 1), base + Vector3.new(side * 9.5, 3, -1.5), Config.Colors.WoodDark, folder, { CanCollide = true })
	end
	makePart("Awning", Vector3.new(22, 0.8, 7), base + Vector3.new(0, 6.2, 0), Color3.fromRGB(255, 190, 190), folder, { CanCollide = false })
	makePart("AwningStripe", Vector3.new(22, 0.9, 1.6), base + Vector3.new(0, 6.25, 3), Color3.fromRGB(255, 244, 244), folder, { CanCollide = false })

	for index, kind in ipairs(Config.Upgrades.Order) do
		local offset = (index - 2) * 6.5
		local padPosition = base + Vector3.new(offset, 0.3, 4)

		local pad = makePart("Pad", Vector3.new(4.4, 0.6, 4.4), padPosition, padColors[kind], folder, {
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanTouch = true,
			CastShadow = false,
		})
		pad.Name = "Pad_" .. kind
		pad:SetAttribute("UpgradeKind", kind)
		pad:SetAttribute("SlotIndex", index)

		makePart("PadRim", Vector3.new(5.2, 0.3, 5.2), padPosition + Vector3.new(0, -0.2, 0), Config.Colors.WoodDark, folder, {
			CanCollide = false,
			CastShadow = false,
		})

		local icon = ModelFactory.buildIcon(kind)
		if icon then
			ModelFactory.scaleModel(icon, 1.9)
			icon:PivotTo(CFrame.new(padPosition + Vector3.new(0, 3.6, 0)))
			icon.Name = "Icon_" .. kind
			icon.Parent = folder
			table.insert(icons, { model = icon, center = padPosition + Vector3.new(0, 3.6, 0) })
		end

		pad.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				tryBuy(player, kind, pad)
			end
		end)
	end
end

function ShopService.Start()
	buildStand()

	local function hookPlayer(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.1)
			applyToCharacter(player, character)
		end)
		if player.Character then
			applyToCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		cooldown[player] = nil
	end)

	-- 아이콘이 천천히 돌면서 위아래로 움직입니다
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for index, entry in ipairs(icons) do
			local bob = math.sin(now * 1.6 + index) * 0.35
			entry.model:PivotTo(
				CFrame.new(entry.center + Vector3.new(0, bob, 0)) * CFrame.Angles(0, now * 1.1, 0)
			)
		end
	end)

	log("시작")
end

return ShopService
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "StateService", [==[
-- 내 상태(별, 기차 칸, 도감, 업그레이드)를 클라이언트로 보냅니다.
-- 클라이언트는 화면 표시만 하고, 값은 전부 서버가 정합니다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent.DataService)
local AnimalService = require(script.Parent.AnimalService)

local StateService = {}

local stateRemote
local dirty = {}

local function buildState(player)
	local data = DataService.get(player)
	if not data then
		return {
			loaded = false,
			stars = 0,
			total = 0,
			train = AnimalService.trainLength(player),
			maxTrain = Config.Train.BaseMaxLength,
			dex = {},
			islands = { [Config.StartIsland] = true },
			upgrades = { Speed = 0, Train = 0, Magnet = 0 },
			music = true,
			canSave = false,
		}
	end

	return {
		loaded = true,
		stars = data.stars,
		total = data.totalStars,
		train = AnimalService.trainLength(player),
		maxTrain = Rules.maxTrain(data.upgrades.Train or 0),
		dex = data.dex,
		islands = data.islands,
		upgrades = data.upgrades,
		bestTrain = data.bestTrain,
		music = data.prefs.music ~= false,
		canSave = DataService.canSave(player),
	}
end

function StateService.push(player)
	if not stateRemote or not player.Parent then
		return
	end
	stateRemote:FireClient(player, buildState(player))
end

function StateService.markDirty(player)
	dirty[player] = true
end

function StateService.Start()
	stateRemote = Net.event(Config.Remotes.StateUpdate)
	local requestRemote = Net.event(Config.Remotes.RequestState)
	local prefRemote = Net.event(Config.Remotes.SetPref)

	requestRemote.OnServerEvent:Connect(function(player)
		StateService.push(player)
	end)

	prefRemote.OnServerEvent:Connect(function(player, key, value)
		-- 클라이언트가 보낸 값은 음악 설정만 받습니다
		if key == "music" and type(value) == "boolean" then
			DataService.setPref(player, key, value)
		end
	end)

	DataService.onChanged(StateService.markDirty)
	AnimalService.onTrainChanged(StateService.markDirty)

	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)

	-- 바뀐 사람만 0.1초마다 갱신 (네트워크 절약)
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < 0.1 then
			return
		end
		clock = 0
		for player in pairs(dirty) do
			dirty[player] = nil
			if player.Parent then
				StateService.push(player)
			end
		end
	end)

	if Config.Debug then
		print("[상태] 시작")
	end
end

return StateService
]==])

script_(folder(roots.ServerScriptService, "Services"), "ModuleScript", "WorldService", [==[
-- 2·7단계 : 섬, 농장, 물, 다리, 조명, 장식을 파트로 만듭니다.
-- 만들어지는 위치는 모두 Config.Islands / Config.Bridge 에서 옵니다.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local DataService = require(script.Parent.DataService)

local WorldService = {}

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

local worldFolder
local islandInfo = {} -- [islandKey] = { folder, deliveryZone, farmFolder }

local function log(...)
	if Config.Debug then
		print("[월드]", ...)
	end
end

local function makePart(name, size, position, color, parent, options)
	options = options or {}
	local part = ModelFactory.newPart({
		Name = name,
		Size = size,
		Color = color,
		Shape = options.Shape,
		Material = options.Material,
		Transparency = options.Transparency,
		Reflectance = options.Reflectance,
		CanCollide = options.CanCollide ~= false, -- 월드 파트는 기본으로 충돌 있음
		CanTouch = options.CanTouch == true,
		CanQuery = options.CanQuery ~= false,
		CastShadow = options.CastShadow ~= false,
	})
	local cframe = CFrame.new(position)
	if options.Rot then
		cframe = cframe
			* CFrame.fromEulerAnglesXYZ(math.rad(options.Rot.X), math.rad(options.Rot.Y), math.rad(options.Rot.Z))
	end
	part.CFrame = cframe
	part.Parent = parent
	return part
end

--=========================================================
-- 조명 (밝고 귀여운 분위기)
--=========================================================
local function setupLighting()
	pcall(function()
		Lighting.Ambient = Color3.fromRGB(138, 142, 158)
		Lighting.OutdoorAmbient = Color3.fromRGB(172, 182, 202)
		Lighting.Brightness = 2.6
		Lighting.ClockTime = 14.2
		Lighting.GeographicLatitude = 20
		Lighting.ExposureCompensation = 0.1
		Lighting.GlobalShadows = true
		Lighting.FogColor = Color3.fromRGB(205, 232, 255)
		Lighting.FogEnd = 1500
		Lighting.FogStart = 400
	end)

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.2
		atmosphere.Color = Color3.fromRGB(216, 235, 255)
		atmosphere.Decay = Color3.fromRGB(188, 214, 240)
		atmosphere.Glare = 0.15
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
end

--=========================================================
-- 물 (섬 밖은 파란 바닥처럼 보이게)
--=========================================================
local function buildWater()
	local water = makePart(
		"Water",
		Vector3.new(1600, 4, 1600),
		Vector3.new(0, -7, -130),
		Config.Colors.Water,
		worldFolder,
		{
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Transparency = 0.28,
			Reflectance = 0.18,
		}
	)
	water.Name = "Water"

	-- 물 아래 더 짙은 바닥 (깊이감)
	makePart("DeepWater", Vector3.new(1600, 4, 1600), Vector3.new(0, -26, -130), Color3.fromRGB(92, 150, 200), worldFolder, {
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
end

--=========================================================
-- 섬 땅
--=========================================================
local function buildIslandGround(island, folder)
	local center = island.Center
	local radius = island.Radius

	makePart("Beach", Vector3.new(5, (radius + 9) * 2, (radius + 9) * 2), center + Vector3.new(0, -2.8, 0), island.Beach, folder, {
		Shape = CYL,
		Rot = Vector3.new(0, 0, 90),
	})
	makePart("Base", Vector3.new(30, (radius - 4) * 2, (radius - 4) * 2), center + Vector3.new(0, -18, 0), Color3.fromRGB(150, 128, 104), folder, {
		Shape = CYL,
		Rot = Vector3.new(0, 0, 90),
	})
	local ground = makePart("Ground", Vector3.new(8, radius * 2, radius * 2), center + Vector3.new(0, -4, 0), island.Ground, folder, {
		Shape = CYL,
		Rot = Vector3.new(0, 0, 90),
	})
	return ground
end

--=========================================================
-- 농장 (나무 울타리 + 노란 배달 발판)
--=========================================================
local function buildFarm(island, folder)
	local farmFolder = Instance.new("Folder")
	farmFolder.Name = "Farm"
	farmFolder.Parent = folder

	local center = island.FarmCenter
	local half = island.FarmSize / 2
	local gapHalf = 5 -- 입구 너비의 절반

	-- 농장 바닥 (밝은 흙색)
	makePart("Floor", Vector3.new(island.FarmSize, 0.6, island.FarmSize), center + Vector3.new(0, -0.2, 0), Color3.fromRGB(226, 205, 162), farmFolder, {
		CanCollide = false,
		CastShadow = false,
	})

	-- 울타리 만들기
	local function fenceRun(fromPos, toPos)
		local delta = toPos - fromPos
		local length = delta.Magnitude
		if length < 0.5 then
			return
		end
		local direction = delta.Unit
		local middle = fromPos + delta * 0.5
		local yaw = math.atan2(-direction.X, -direction.Z)

		-- 가로 막대 2개
		for _, height in ipairs({ 1.1, 2.1 }) do
			local rail = makePart("Rail", Vector3.new(0.35, 0.35, length), middle + Vector3.new(0, height, 0), Config.Colors.Wood, farmFolder, {
				CanCollide = false,
				CastShadow = false,
			})
			rail.CFrame = CFrame.new(middle + Vector3.new(0, height, 0)) * CFrame.Angles(0, yaw, 0)
		end

		-- 기둥
		local count = math.max(2, math.floor(length / 4))
		for index = 0, count do
			local position = fromPos + direction * (length * (index / count))
			makePart("Post", Vector3.new(0.6, 3, 0.6), position + Vector3.new(0, 1.5, 0), Config.Colors.WoodDark, farmFolder, {
				CanCollide = true,
			})
		end
	end

	local northZ = center.Z - half -- 농장 뒤쪽
	local southZ = center.Z + half -- 입구 쪽 (스폰에서 보이는 면)
	local westX = center.X - half
	local eastX = center.X + half
	local y = 0

	fenceRun(Vector3.new(westX, y, northZ), Vector3.new(eastX, y, northZ))
	fenceRun(Vector3.new(westX, y, northZ), Vector3.new(westX, y, southZ))
	fenceRun(Vector3.new(eastX, y, northZ), Vector3.new(eastX, y, southZ))
	-- 입구가 있는 면은 가운데를 비웁니다
	fenceRun(Vector3.new(westX, y, southZ), Vector3.new(center.X - gapHalf, y, southZ))
	fenceRun(Vector3.new(center.X + gapHalf, y, southZ), Vector3.new(eastX, y, southZ))

	-- 입구 기둥 (조금 더 크게)
	for _, side in ipairs({ -1, 1 }) do
		makePart("GatePost", Vector3.new(1, 4.5, 1), Vector3.new(center.X + side * gapHalf, 2.25, southZ), Config.Colors.WoodDark, farmFolder, {
			CanCollide = true,
		})
		makePart("GatePostTop", Vector3.new(1.4, 0.5, 1.4), Vector3.new(center.X + side * gapHalf, 4.7, southZ), Color3.fromRGB(255, 208, 120), farmFolder, {
			CanCollide = false,
		})
	end

	-- 밝게 빛나는 노란 배달 발판 (5단계)
	local zonePos = island.DeliveryPos + Vector3.new(0, 0.25, 0)
	local zone = makePart("DeliveryZone", Vector3.new(12, 0.5, 8), zonePos, Color3.fromRGB(255, 226, 110), farmFolder, {
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = true,
		CastShadow = false,
	})
	zone:SetAttribute("Island", island.Key)

	-- 발판 위 반짝임
	ModelFactory.addSparkles(zone, Color3.fromRGB(255, 240, 170), 10)

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 18
	light.Color = Color3.fromRGB(255, 230, 150)
	light.Parent = zone

	local inside = Instance.new("Folder")
	inside.Name = "Inside" -- 농장에 들어간 동물들이 사는 곳
	inside.Parent = farmFolder

	return farmFolder, zone
end

--=========================================================
-- 장식 (나무, 꽃, 바위)
--=========================================================
local function buildDecor(island, folder)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder

	local rng = Random.new(island.Order * 7919)
	local center = island.Center
	local isSnow = island.Key == "Snow"

	-- 이 구역에는 장식을 놓지 않습니다 (길을 막지 않도록)
	local function blocked(position)
		local farm = island.FarmCenter
		local half = island.FarmSize / 2 + 6
		if math.abs(position.X - farm.X) < half and math.abs(position.Z - farm.Z) < half then
			return true
		end
		-- 스폰 → 농장 통로
		local spawn = island.SpawnPoint
		local minZ = math.min(spawn.Z, farm.Z) - 4
		local maxZ = math.max(spawn.Z, farm.Z) + 12
		if math.abs(position.X - spawn.X) < 16 and position.Z > minZ and position.Z < maxZ then
			return true
		end
		-- 다리 통로
		if math.abs(position.X) < 14 and position.Z < Config.Bridge.FromZ + 22 and position.Z > Config.Bridge.ToZ - 22 then
			return true
		end
		-- 여우 굴 주변
		if (position - island.FoxDen).Magnitude < 12 then
			return true
		end
		-- 상점 주변
		if island.ShopPos and (position - island.ShopPos).Magnitude < 14 then
			return true
		end
		return false
	end

	local function scatter(count, builder, minRadius, maxRadius)
		local placed = 0
		local tries = 0
		while placed < count and tries < count * 14 do
			tries += 1
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(minRadius, maxRadius)
			local position = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			if not blocked(position) then
				local model = builder(rng)
				ModelFactory.offsetModel(model, position, rng:NextNumber(0, 360))
				model.Parent = decor
				placed += 1
			end
		end
	end

	if isSnow then
		scatter(12, ModelFactory.buildPine, island.Radius * 0.3, island.Radius * 0.9)
		scatter(10, ModelFactory.buildSnowMound, island.Radius * 0.25, island.Radius * 0.92)
		scatter(8, ModelFactory.buildRock, island.Radius * 0.3, island.Radius * 0.9)
	else
		scatter(14, ModelFactory.buildTree, island.Radius * 0.28, island.Radius * 0.92)
		scatter(34, ModelFactory.buildFlower, island.Radius * 0.15, island.Radius * 0.94)
		scatter(10, ModelFactory.buildRock, island.Radius * 0.3, island.Radius * 0.92)
	end
end

--=========================================================
-- 여우 굴 (10단계)
--=========================================================
local function buildFoxDen(island, folder)
	local position = island.FoxDen
	local den = Instance.new("Folder")
	den.Name = "FoxDen"
	den.Parent = folder

	makePart("Mound", Vector3.new(14, 8, 14), position + Vector3.new(0, 1, 0), Color3.fromRGB(176, 148, 116), den, {
		Shape = BALL,
		CanCollide = false,
	})
	makePart("Hole", Vector3.new(5, 4.5, 3), position + Vector3.new(0, 1.6, 6.2), Color3.fromRGB(72, 58, 48), den, {
		Shape = BALL,
		CanCollide = false,
	})
	makePart("Marker", Vector3.new(1.2, 0.4, 1.2), position + Vector3.new(0, 0.2, 9), Color3.fromRGB(255, 200, 120), den, {
		Shape = CYL,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Rot = Vector3.new(0, 0, 90),
	})
	den:SetAttribute("Island", island.Key)
	return den
end

--=========================================================
-- 스폰 발판
--=========================================================
local function buildSpawn(island, folder)
	local existing = workspace:FindFirstChild("MainSpawn", true)
	local spawn = existing
	if not spawn or not spawn:IsA("SpawnLocation") then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "MainSpawn"
	end
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(255, 236, 168)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.CFrame = CFrame.lookAt(island.SpawnPoint + Vector3.new(0, 0.5, 0), island.FarmCenter + Vector3.new(0, 0.5, 0))
	spawn.Parent = folder

	-- 스폰 발판 테두리 (예쁘게)
	makePart("SpawnRing", Vector3.new(0.6, 15, 15), island.SpawnPoint + Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 214, 120), folder, {
		Shape = CYL,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Rot = Vector3.new(0, 0, 90),
	})
	return spawn
end

--=========================================================
-- 다리 (7단계)
--=========================================================
local function buildBridge()
	local bridge = Instance.new("Folder")
	bridge.Name = "Bridge"
	bridge.Parent = worldFolder

	local fromZ = Config.Bridge.FromZ
	local toZ = Config.Bridge.ToZ
	local length = math.abs(toZ - fromZ) + 14
	local middleZ = (fromZ + toZ) / 2
	local width = Config.Bridge.Width

	makePart("Deck", Vector3.new(width, 1.2, length), Vector3.new(0, -0.6, middleZ), Config.Colors.Wood, bridge, {})

	-- 판자 무늬
	local planks = math.floor(length / 4)
	for index = 0, planks do
		local z = (middleZ - length / 2) + index * 4
		makePart("Plank", Vector3.new(width + 0.4, 0.25, 1.2), Vector3.new(0, 0.05, z), Config.Colors.WoodDark, bridge, {
			CanCollide = false,
			CastShadow = false,
		})
	end

	-- 난간
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (width / 2 + 0.2)
		makePart("Rail", Vector3.new(0.4, 0.4, length), Vector3.new(x, 2.6, middleZ), Config.Colors.WoodDark, bridge, {
			CanCollide = false,
			CastShadow = false,
		})
		local posts = math.floor(length / 8)
		for index = 0, posts do
			local z = (middleZ - length / 2) + index * 8
			makePart("RailPost", Vector3.new(0.5, 3, 0.5), Vector3.new(x, 1.3, z), Config.Colors.WoodDark, bridge, {
				CanCollide = true,
			})
		end
	end

	-- 물속 기둥
	local pillars = math.floor(length / 16)
	for index = 0, pillars do
		local z = (middleZ - length / 2) + index * 16
		makePart("Pillar", Vector3.new(14, 1.6, 1.6), Vector3.new(0, -8, z), Config.Colors.WoodDark, bridge, {
			Shape = CYL,
			CanCollide = false,
			Rot = Vector3.new(0, 0, 90),
		})
	end
	return bridge
end

--=========================================================
-- 물에 빠지면 스폰으로 (2단계)
--=========================================================
local function startFallGuard()
	task.spawn(function()
		while true do
			task.wait(0.35)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < -9 then
					local target = Config.Islands[Config.StartIsland]
					-- 열어 둔 섬 중 가장 가까운 섬으로 돌려보냅니다
					local best = math.huge
					for _, key in ipairs(Config.IslandOrder) do
						local island = Config.Islands[key]
						if island and (key == Config.StartIsland or DataService.hasIsland(player, key)) then
							local distance = (island.Center - root.Position).Magnitude
							if distance < best then
								best = distance
								target = island
							end
						end
					end
					character:PivotTo(CFrame.new(target.SpawnPoint + Vector3.new(0, 5, 0)))
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:ChangeState(Enum.HumanoidStateType.Landed)
					end
					WorldService.onFall(player)
				end
			end
		end
	end)
end

-- Effects 가 연결해 주는 자리 (물에 빠졌을 때 소리)
WorldService.onFall = function(_player) end

--=========================================================
-- 밖에서 쓰는 함수들
--=========================================================
function WorldService.getDeliveryZone(islandKey)
	local info = islandInfo[islandKey]
	return info and info.deliveryZone
end

function WorldService.getFarmInside(islandKey)
	local info = islandInfo[islandKey]
	return info and info.farmFolder and info.farmFolder:FindFirstChild("Inside")
end

function WorldService.getIslandFolder(islandKey)
	local info = islandInfo[islandKey]
	return info and info.folder
end

function WorldService.Start()
	-- 기존 Baseplate 와 낡은 월드를 지웁니다 (2단계)
	for _, name in ipairs({ "Baseplate", "World" }) do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "Baseplate" then
			child:Destroy()
		end
	end

	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = workspace

	setupLighting()
	buildWater()

	for _, key in ipairs(Config.IslandOrder) do
		local island = Config.Islands[key]
		local folder = Instance.new("Folder")
		folder.Name = key
		folder.Parent = worldFolder

		buildIslandGround(island, folder)
		local farmFolder, zone = buildFarm(island, folder)
		buildDecor(island, folder)
		buildFoxDen(island, folder)
		if key == Config.StartIsland then
			buildSpawn(island, folder)
		end

		islandInfo[key] = { folder = folder, farmFolder = farmFolder, deliveryZone = zone }
		log(key, "섬 완성")
	end

	buildBridge()
	startFallGuard()

	pcall(function()
		Players.RespawnTime = 1.5
	end)

	log("월드 준비 끝")
end

return WorldService
]==])

script_(roots.StarterPlayerScripts, "LocalScript", "ClientMain", [==[
-- 클라이언트 시작점. 화면을 만들고 서버 신호를 연결합니다.
-- 클라이언트는 화면 표시와 입력만 담당합니다 (값은 서버가 정함).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = ReplicatedStorage:WaitForChild("Client")

local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Hud = require(Client:WaitForChild("Hud"))
local Arrow = require(Client:WaitForChild("Arrow"))
local Dex = require(Client:WaitForChild("Dex"))
local Music = require(Client:WaitForChild("Music"))
local ShopUi = require(Client:WaitForChild("ShopUi"))
local GateClient = require(Client:WaitForChild("GateClient"))
local ClientEffects = require(Client:WaitForChild("ClientEffects"))

local screen = Instance.new("ScreenGui")
screen.Name = "AnimalTrainHud"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

Hud.init(screen)
Dex.init(screen)
Music.init(screen)
ShopUi.init()
GateClient.init()
Arrow.init(playerGui) -- 3D 화살표는 PlayerGui 에 바로 넣습니다

local stateRemote = Net.event(Config.Remotes.StateUpdate)
local effectRemote = Net.event(Config.Remotes.Effect)
local requestRemote = Net.event(Config.Remotes.RequestState)

stateRemote.OnClientEvent:Connect(function(state)
	Hud.update(state)
	Dex.update(state)
	Music.update(state)
	ShopUi.update(state)
	GateClient.update(state)
	Arrow.update(state)
end)

effectRemote.OnClientEvent:Connect(function(kind, payload)
	ClientEffects.handle(kind, payload)
end)

-- 접속 직후 상태 요청 (서버가 데이터를 불러오는 중이면 조금 뒤 한 번 더)
requestRemote:FireServer()
task.delay(2, function()
	requestRemote:FireServer()
end)
task.delay(6, function()
	requestRemote:FireServer()
end)

print("[졸졸 동물 기차] 화면 준비 완료")
]==])

print("[졸졸 동물 기차] 설치 완료. Play 를 눌러 보세요.")
