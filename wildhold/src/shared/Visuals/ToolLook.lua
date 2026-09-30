-- 손에 드는 도구 모양 (Roblox Tool). 서버가 만들어 플레이어 Backpack 에 넣는다.
--
-- 쥐는 법: 도구를 들면 기본 Animate 가 오른팔을 앞으로 뻗는다(toolnone). 그때 손(RightGripAttachment) 기준으로
--   +Y = 위, -Z = 앞 이다. Tool.Grip 을 CFrame.new(쥐는 점) * 기울기 로 주면 Handle 의 그 점을 손이 쥔다.
--   · 도끼·곡괭이·횃불 : 자루를 Handle 의 Y 축으로 만들고 날/머리를 위(+Y)에 둔다 → 자루를 세워서 쥐고 날은 앞(-Z)을 본다
--   · 창                : 자루를 Z 축으로 만들고 창날을 앞(-Z)에 둔다 → 앞으로 겨누어 쥔다
-- 예전에는 도끼·곡괭이도 창처럼 앞으로 눕혀 들어서 "막대 끝에 돌덩이" 처럼 보였다.
local RS = game:GetService("ReplicatedStorage")
local I = require(RS.Shared.Config.ItemConfig)

local T = {}
local MAT = Enum.Material

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

-- 손잡이에 붙는 조각 (offset 은 Handle 기준)
local function piece(tool, handle, size, offset, color, material, className)
	local p = Instance.new(className or "Part")
	p.Size, p.Color, p.Material = size, color, material
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = handle, p
	weld.Parent = p
	p.Parent = tool
	return p
end

-- 쥐는 점(Handle 기준)과 앞으로 기울이는 각도(도) → Tool.Grip
local function grip(point, leanDeg)
	return CFrame.new(point) * CFrame.Angles(math.rad(leanDeg or 0), 0, 0)
end

-- 세운 자루 (Y 축)
local function upright(handle, length, look)
	handle.Size = Vector3.new(0.26, length, 0.26)
	handle.Color = hex(look.Wood)
	handle.Material = MAT.Wood
end

local function axe(tool, handle, look, headColor, headMat)
	upright(handle, 3.3, look)
	local top = 1.2
	-- 머리: 자루를 감싸는 쇠고리 + 앞으로 뻗은 뺨 + 위아래로 벌어진 날
	piece(tool, handle, Vector3.new(0.36, 0.62, 0.42), CFrame.new(0, top, 0), headColor, headMat)
	piece(tool, handle, Vector3.new(0.2, 0.5, 0.55), CFrame.new(0, top, -0.45), headColor, headMat)
	piece(tool, handle, Vector3.new(0.14, 1.05, 0.26), CFrame.new(0, top, -0.8), headColor, headMat)
	-- 날 끝을 날카롭게 (쐐기 두 개가 위아래로 벌어진 모양)
	-- (WedgePart: 세운 면이 +Z → Y 로 반 바퀴 돌리면 세운 면이 날 쪽(-Z), X 로 반 바퀴 돌리면 위아래도 뒤집힌다)
	piece(tool, handle, Vector3.new(0.14, 0.28, 0.4), CFrame.new(0, top + 0.39, -0.62) * CFrame.Angles(0, math.pi, 0), headColor, headMat, "WedgePart")
	piece(tool, handle, Vector3.new(0.14, 0.28, 0.4), CFrame.new(0, top - 0.39, -0.62) * CFrame.Angles(math.pi, 0, 0), headColor, headMat, "WedgePart")
	-- 뒤통수 (망치 쪽)
	piece(tool, handle, Vector3.new(0.3, 0.4, 0.26), CFrame.new(0, top, 0.3), headColor, headMat)
	-- 손잡이 감개 + 자루 끝
	piece(tool, handle, Vector3.new(0.32, 0.7, 0.32), CFrame.new(0, -1.05, 0), hex("#4a3322"), MAT.Fabric)
	piece(tool, handle, Vector3.new(0.34, 0.16, 0.34), CFrame.new(0, -1.6, 0), hex(look.Wood):Lerp(hex("#2a1c12"), 0.4), MAT.Wood)
	tool.Grip = grip(Vector3.new(0, -1.0, 0), 20)
end

local function pickaxe(tool, handle, look, headColor, headMat)
	upright(handle, 3.5, look)
	local top = 1.62
	-- 머리: 자루 끝을 앞뒤로 가로지르고, 양 끝이 아래로 휘어 뾰족해진다
	piece(tool, handle, Vector3.new(0.36, 0.4, 0.46), CFrame.new(0, top, 0), headColor, headMat)
	for _, side in ipairs({-1, 1}) do
		piece(tool, handle, Vector3.new(0.22, 0.3, 0.8), CFrame.new(0, top + 0.02, side * 0.58) * CFrame.Angles(math.rad(side * 8), 0, 0), headColor, headMat)
		piece(tool, handle, Vector3.new(0.18, 0.24, 0.62), CFrame.new(0, top - 0.14, side * 1.18) * CFrame.Angles(math.rad(side * 24), 0, 0), headColor, headMat)
		piece(tool, handle, Vector3.new(0.12, 0.16, 0.36), CFrame.new(0, top - 0.34, side * 1.55) * CFrame.Angles(math.rad(side * 42), 0, 0), headColor, headMat)
	end
	piece(tool, handle, Vector3.new(0.32, 0.7, 0.32), CFrame.new(0, -1.15, 0), hex("#4a3322"), MAT.Fabric)
	tool.Grip = grip(Vector3.new(0, -1.1, 0), 20)
end

local function spear(tool, handle, look, headColor, headMat)
	handle.Size = Vector3.new(0.24, 0.24, 5.6)
	handle.Color = hex(look.Wood)
	handle.Material = MAT.Wood
	-- 창날: 납작한 나뭇잎 모양 (세로로 선 날)
	piece(tool, handle, Vector3.new(0.1, 0.5, 0.9), CFrame.new(0, 0, -3.15), headColor, headMat)
	piece(tool, handle, Vector3.new(0.1, 0.36, 0.36), CFrame.new(0, 0, -3.62) * CFrame.Angles(math.rad(45), 0, 0), headColor, headMat)
	piece(tool, handle, Vector3.new(0.3, 0.3, 0.5), CFrame.new(0, 0, -2.6), hex("#3a5a50"), MAT.Fabric)
	piece(tool, handle, Vector3.new(0.3, 0.3, 0.6), CFrame.new(0, 0, 0.9), hex("#784e2c"), MAT.Fabric)
	-- 가운데보다 조금 뒤를 쥐고 창끝을 살짝 위로
	tool.Grip = grip(Vector3.new(0, 0, 0.9), -8)
end

local function torch(tool, handle, look)
	upright(handle, 2.5, look)
	local head = piece(tool, handle, Vector3.new(0.44, 0.6, 0.44), CFrame.new(0, 1.3, 0), hex("#3b2a1c"), MAT.Fabric)
	piece(tool, handle, Vector3.new(0.5, 0.14, 0.5), CFrame.new(0, 0.98, 0), hex("#5d646b"), MAT.Metal)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 2.2, 6, hex("#ff9a3c"), hex("#ffd27a")
	fire.Parent = head
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Shadows = 22, 1.6, hex("#ffae5c"), true
	light.Parent = head
	-- 불꽃이 위로 서도록 거의 세워서 쥔다
	tool.Grip = grip(Vector3.new(0, -0.7, 0), 12)
end

local function trap(tool, handle, id, spec)
	handle.Size = Vector3.new(1.1, 0.8, 1.1)
	handle.Color = id == "CrystalTrap" and hex("#7ff0ff") or (spec.Better and hex("#c9a45c") or hex("#9a7a4a"))
	handle.Material = id == "CrystalTrap" and MAT.Glass or MAT.Fabric
	piece(tool, handle, Vector3.new(1.2, 0.12, 1.2), CFrame.new(0, 0.44, 0), hex("#6b4a2c"), MAT.Wood)
	-- 바구니 손잡이 (고리)
	piece(tool, handle, Vector3.new(0.12, 0.5, 0.12), CFrame.new(0, 0.74, -0.4), hex("#6b4a2c"), MAT.Wood)
	piece(tool, handle, Vector3.new(0.12, 0.5, 0.12), CFrame.new(0, 0.74, 0.4), hex("#6b4a2c"), MAT.Wood)
	piece(tool, handle, Vector3.new(0.12, 0.12, 0.92), CFrame.new(0, 1.0, 0), hex("#6b4a2c"), MAT.Wood)
	-- 손잡이를 쥐고 바구니는 손 아래에 매단다
	tool.Grip = grip(Vector3.new(0, 1.0, 0), 0)
end

local function food(tool, handle, id)
	local colors = {Berry = "#c8304e", RoastMushroom = "#b07a4a", Stew = "#8a5a3a", Snack = "#d9a55c"}
	if id == "Stew" then
		-- 나무 그릇
		handle.Shape = Enum.PartType.Cylinder
		handle.Size = Vector3.new(0.5, 1.1, 1.1)
		handle.Color = hex("#7a5230")
		handle.Material = MAT.Wood
		piece(tool, handle, Vector3.new(0.06, 0.9, 0.9), CFrame.new(0.26, 0, 0), hex(colors.Stew), MAT.SmoothPlastic).Shape = Enum.PartType.Cylinder
		-- 원기둥은 X 축이 길이 방향 → 그릇이 위를 보게 세운다
		tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
		return
	elseif id == "RoastMushroom" then
		handle.Size = Vector3.new(0.14, 1.4, 0.14)
		handle.Color = hex("#8a6242")
		handle.Material = MAT.Wood
		piece(tool, handle, Vector3.new(0.7, 0.45, 0.7), CFrame.new(0, 0.55, 0), hex(colors.RoastMushroom), MAT.SmoothPlastic)
		piece(tool, handle, Vector3.new(0.6, 0.4, 0.6), CFrame.new(0, 0.1, 0), hex("#9a6a3e"), MAT.SmoothPlastic)
		tool.Grip = grip(Vector3.new(0, -0.5, 0), 10)
		return
	end
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(0.7, 0.7, 0.7)
	handle.Color = hex(colors[id] or "#c8a060")
	handle.Material = MAT.SmoothPlastic
	if id == "Berry" then
		piece(tool, handle, Vector3.new(0.08, 0.3, 0.08), CFrame.new(0, 0.42, 0), hex("#4f7a3a"), MAT.SmoothPlastic)
	end
	tool.Grip = CFrame.new(0, 0, 0)
end

function T.make(id)
	local spec = I.Items[id]
	if not spec then return nil end
	local tool, handle = makeTool(id, spec)
	local look = I.TierLook[spec.Tier or 1]
	local headColor, headMat = hex(look.Head), MAT[look.Material]
	if spec.Family == "Spear" then
		spear(tool, handle, look, headColor, headMat)
	elseif spec.Family == "Axe" then
		axe(tool, handle, look, headColor, headMat)
	elseif spec.Family == "Pickaxe" then
		pickaxe(tool, handle, look, headColor, headMat)
	elseif spec.Family == "Torch" then
		torch(tool, handle, look)
	elseif spec.Kind == "Trap" then
		trap(tool, handle, id, spec)
	else
		food(tool, handle, id)
	end
	return tool
end

return T
