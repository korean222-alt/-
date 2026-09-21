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
