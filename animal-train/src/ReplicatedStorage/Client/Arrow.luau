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
