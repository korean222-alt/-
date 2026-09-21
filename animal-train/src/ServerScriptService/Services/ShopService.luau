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
