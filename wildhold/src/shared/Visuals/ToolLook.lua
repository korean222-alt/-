-- 손에 드는 도구 모양 (Roblox Tool). 서버가 만들어 플레이어 Backpack 에 넣는다.
-- Handle 의 -Z 쪽이 앞(손을 뻗은 방향)이다. Grip 으로 손이 잡는 위치를 정한다.
local RS = game:GetService("ReplicatedStorage")
local I = require(RS.Shared.Config.ItemConfig)

local T = {}

local function hex(value)
	return Color3.fromHex(value)
end

local function makeTool(id, spec)
	local tool = Instance.new("Tool")
	tool.Name = spec.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = spec.Name
	tool:SetAttribute("ItemId", id)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, true
	handle.TopSurface, handle.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	handle.Parent = tool
	return tool, handle
end

-- 손잡이에 붙는 조각
local function piece(tool, handle, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Size, p.Color, p.Material = size, color, material
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = handle, p
	weld.Parent = p
	p.Parent = tool
	return p
end

local function shaft(handle, length, look)
	handle.Size = Vector3.new(0.3, 0.3, length)
	handle.Color = hex(look.Wood)
	handle.Material = Enum.Material.Wood
end

function T.make(id)
	local spec = I.Items[id]
	if not spec then return nil end
	local tool, handle = makeTool(id, spec)
	local look = I.TierLook[spec.Tier or 1]
	local headColor, headMat = hex(look.Head), Enum.Material[look.Material]
	if spec.Family == "Spear" then
		shaft(handle, 5.6, look)
		piece(tool, handle, Vector3.new(0.12, 0.62, 1.3), CFrame.new(0, 0, -3.25), headColor, headMat)
		piece(tool, handle, Vector3.new(0.12, 0.62, 0.62), CFrame.new(0, 0, -3.95) * CFrame.Angles(math.rad(45), 0, 0), headColor, headMat)
		piece(tool, handle, Vector3.new(0.42, 0.42, 0.7), CFrame.new(0, 0, -2.4), hex("#40aa96"), Enum.Material.Fabric)
		piece(tool, handle, Vector3.new(0.42, 0.42, 0.5), CFrame.new(0, 0, 0.6), hex("#784e2c"), Enum.Material.Fabric)
		tool.Grip = CFrame.new(0, 0, 0.9)
	elseif spec.Family == "Axe" then
		shaft(handle, 3.2, look)
		-- 도끼날: 손잡이 끝에서 위로 솟은 쐐기
		piece(tool, handle, Vector3.new(0.22, 1.1, 0.9), CFrame.new(0, 0.45, -1.35), headColor, headMat)
		piece(tool, handle, Vector3.new(0.16, 0.5, 1.2), CFrame.new(0, 1.05, -1.35), headColor, headMat)
		piece(tool, handle, Vector3.new(0.36, 0.36, 0.5), CFrame.new(0, 0, 1.2), hex("#4a3322"), Enum.Material.Fabric)
		tool.Grip = CFrame.new(0, 0, 1.0)
	elseif spec.Family == "Pickaxe" then
		shaft(handle, 3.4, look)
		-- 곡괭이 머리: 손잡이 끝을 가로지르는 뾰족한 막대
		piece(tool, handle, Vector3.new(0.26, 2.4, 0.3), CFrame.new(0, 0, -1.5), headColor, headMat)
		piece(tool, handle, Vector3.new(0.2, 0.5, 0.2), CFrame.new(0, 1.35, -1.45) * CFrame.Angles(math.rad(-25), 0, 0), headColor, headMat)
		piece(tool, handle, Vector3.new(0.2, 0.5, 0.2), CFrame.new(0, -1.35, -1.45) * CFrame.Angles(math.rad(25), 0, 0), headColor, headMat)
		tool.Grip = CFrame.new(0, 0, 1.1)
	elseif spec.Family == "Torch" then
		shaft(handle, 2.6, look)
		local head = piece(tool, handle, Vector3.new(0.5, 0.5, 0.6), CFrame.new(0, 0, -1.4), hex("#3b2a1c"), Enum.Material.Fabric)
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 2.2, 6, hex("#ff9a3c"), hex("#ffd27a")
		fire.Parent = head
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color, light.Shadows = 22, 1.6, hex("#ffae5c"), true
		light.Parent = head
		-- 앞으로 들되 불꽃이 위를 향하게 기울인다
		tool.Grip = CFrame.new(0, 0, 0.8) * CFrame.Angles(math.rad(-35), 0, 0)
	elseif spec.Kind == "Trap" then
		handle.Size = Vector3.new(1.1, 0.7, 1.1)
		handle.Color = id == "CrystalTrap" and hex("#7ff0ff") or (spec.Better and hex("#c9a45c") or hex("#9a7a4a"))
		handle.Material = id == "CrystalTrap" and Enum.Material.Glass or Enum.Material.Fabric
		piece(tool, handle, Vector3.new(1.2, 0.12, 1.2), CFrame.new(0, 0.36, 0), hex("#6b4a2c"), Enum.Material.Wood)
		tool.Grip = CFrame.new(0, 0, 0.2)
	else
		-- 음식·간식: 손에 쥔 작은 덩어리
		local colors = {Berry = "#c8304e", RoastMushroom = "#b07a4a", Stew = "#8a5a3a", Snack = "#d9a55c"}
		handle.Shape = Enum.PartType.Ball
		handle.Size = Vector3.new(0.8, 0.8, 0.8)
		handle.Color = hex(colors[id] or "#c8a060")
		handle.Material = Enum.Material.SmoothPlastic
		tool.Grip = CFrame.new(0, 0, 0.1)
	end
	return tool
end

return T
