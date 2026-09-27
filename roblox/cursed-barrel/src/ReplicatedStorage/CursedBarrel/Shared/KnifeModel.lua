--[[
	KnifeModel  (Phase 14)
	상점 3D 미리보기 · 로비 전시대에 쓰는 칼 모형. 예전에는 네모 판 세 개(날 · 코등이 · 손잡이)였다.

	· 날은 끝이 뾰족하게 좁아지고(쐐기 두 장), 가운데 홈(fuller)과 밝은 날선이 있다.
	· 코등이 양 끝에 구슬, 손잡이는 둥근 자루에 감은 끈 네 줄, 끝에 폼멜.
	· 희귀 이상은 폼멜에 보석, 영웅 이상은 코등이 가운데에도 보석.
	· 스킨의 shape 로 모양이 바뀐다 : dagger(기본) · cutlass(곡도) · kris(물결 날) · harpoon(작살) · hook(갈고리) · fang(송곳니) · bone(톱니 뼈칼)

	3D 모델(메시)을 올렸다면 ReleaseConfig.Meshes.Knife[스킨 id] = { MeshId = 숫자, TextureId = 숫자, Scale = Vector3 } 로
	그 모델을 대신 쓴다. (이름이 Blade 인 파트 하나에 붙는다. 이펙트는 그대로 붙는다)

	좌표 : 칼끝이 +Y, 코등이가 원점. 반환한 모델의 WorldPivot 은 base (코등이 자리) 이다.

	Phase 17 : Blender 칼(assets/models/CursedBarrelSkins.fbx)을 가져왔으면 모양마다 그 메시를 쓴다.
	  날 · 날선 · 코등이 · 손잡이 · 감은 끈 · 폼멜 · 보석 조각을 스킨 색으로 칠한다 (MeshKit.knife).
	  모델에 MeshFrame(=base) · MeshScale 속성을 달아 둔다. 용 · 꽃잎 연출(SkinMotion)이 이 축을 따라 돈다.
]]

local KnifeModel = {}

local RARITY_RANK = { common = 1, rare = 2, epic = 3, legend = 4, mythic = 5 }

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- 날끝 반쪽 (쐐기). sign = 1 이면 오른쪽 반, -1 이면 왼쪽 반. 곧은 변이 가운데(x=0)에 온다.
local function tipHalf(parent, base, width, length, thickness, sign, color, material)
	local w = Instance.new("WedgePart")
	w.Name = "BladeTip"
	w.Size = Vector3.new(thickness, length, width)
	local right = base.ZVector * sign
	local center = base.Position + base.XVector * (sign * width * 0.5)
	w.CFrame = CFrame.fromMatrix(center, right, base.YVector)
	w.Color = color
	w.Material = material
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.CanQuery = false
	w.CastShadow = false
	w.Parent = parent
	return w
end

-- 곧은 날 한 조각 + 끝. from : 날이 시작하는 자리(코등이 위), 방향은 from 의 +Y.
local function straightBlade(model, from, width, length, tipLength, thickness, skin)
	local blade = part(model, "Blade", Vector3.new(width, length, thickness), from * CFrame.new(0, length * 0.5, 0), skin.blade, skin.bladeMaterial)
	blade.Reflectance = skin.glow and 0.25 or 0.12
	local tipBase = from * CFrame.new(0, length + tipLength * 0.5, 0)
	for _, sign in ipairs({ 1, -1 }) do
		tipHalf(model, tipBase, width * 0.5, tipLength, thickness, sign, skin.blade, skin.bladeMaterial).Reflectance = blade.Reflectance
	end
	-- 가운데 홈과 양쪽 날선
	part(model, "Fuller", Vector3.new(width * 0.16, length * 0.78, thickness + 0.012), from * CFrame.new(0, length * 0.45, 0),
		skin.blade:Lerp(Color3.new(0, 0, 0), 0.28), skin.bladeMaterial)
	for _, sign in ipairs({ 1, -1 }) do
		part(model, "Edge", Vector3.new(width * 0.1, length * 0.96, thickness * 0.7), from * CFrame.new(sign * width * 0.46, length * 0.5, 0),
			skin.blade:Lerp(Color3.new(1, 1, 1), 0.45), skin.bladeMaterial == Enum.Material.Neon and Enum.Material.Neon or Enum.Material.Metal)
	end
	return blade
end

-- 휘어진 날 (곡도 · 송곳니 · 갈고리). bend 가 클수록 많이 휜다.
local function curvedBlade(model, from, width, length, thickness, skin, bend, pieces, taper)
	local cf = from
	local step = length / pieces
	local main = nil
	for i = 1, pieces do
		local w = width * (1 - (taper or 0.35) * (i - 1) / pieces)
		local piece = part(model, i == 1 and "Blade" or "BladeCurve", Vector3.new(w, step * 1.08, thickness), cf * CFrame.new(0, step * 0.5, 0), skin.blade, skin.bladeMaterial)
		piece.Reflectance = skin.glow and 0.25 or 0.12
		-- 휘는 쪽(+X)이 등, 바깥으로 불룩한 쪽(-X)이 날이다
		part(model, "Edge", Vector3.new(w * 0.12, step * 1.02, thickness * 0.7), cf * CFrame.new(-w * 0.45, step * 0.5, 0),
			skin.blade:Lerp(Color3.new(1, 1, 1), 0.45), skin.bladeMaterial == Enum.Material.Neon and Enum.Material.Neon or Enum.Material.Metal)
		main = main or piece
		cf = cf * CFrame.new(0, step, 0) * CFrame.Angles(0, 0, bend / pieces)
	end
	local tipWidth = width * (1 - (taper or 0.35))
	local tipLength = tipWidth * 1.6
	local tipBase = cf * CFrame.new(0, tipLength * 0.5, 0)
	-- 등(+X)은 곧게, 날(-X)은 비스듬히 : 한쪽 쐐기 하나만
	tipHalf(model, tipBase * CFrame.new(tipWidth * 0.5, 0, 0), tipWidth, tipLength, thickness, -1, skin.blade, skin.bladeMaterial)
	return main
end

local function guard(model, at, skin, span, rank)
	local metal = skin.guard or Color3.fromRGB(126, 104, 62)
	part(model, "Guard", Vector3.new(span, 0.16, 0.26), at, metal, Enum.Material.Metal).Reflectance = 0.15
	for _, sign in ipairs({ 1, -1 }) do
		part(model, "GuardEnd", Vector3.new(0.24, 0.24, 0.24), at * CFrame.new(sign * span * 0.5, 0.03, 0), metal, Enum.Material.Metal, Enum.PartType.Ball).Reflectance = 0.15
	end
	part(model, "Langet", Vector3.new(0.34, 0.34, 0.3), at * CFrame.new(0, 0.08, 0), metal:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Metal)
	if rank >= 3 then
		local gem = part(model, "Gem", Vector3.new(0.16, 0.16, 0.08), at * CFrame.new(0, 0.08, 0.16), skin.trail or skin.blade, Enum.Material.Neon)
		gem.Shape = Enum.PartType.Ball
	end
end

local function handle(model, at, skin, length, rank)
	local wood = skin.handle or Color3.fromRGB(64, 42, 28)
	local grip = part(model, "Grip", Vector3.new(length, 0.3, 0.3), at * CFrame.new(0, -length * 0.5 - 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2),
		wood, skin.handleMaterial or Enum.Material.Wood, Enum.PartType.Cylinder)
	grip.Name = "Handle"
	local wrap = wood:Lerp(Color3.new(0, 0, 0), 0.45)
	for i = 1, 4 do
		local y = -0.08 - length * (i - 0.5) / 4
		part(model, "WrapRing", Vector3.new(0.09, 0.335, 0.335), at * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), wrap, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	local metal = skin.guard or Color3.fromRGB(126, 104, 62)
	local pommelAt = at * CFrame.new(0, -length - 0.24, 0)
	part(model, "Pommel", Vector3.new(0.4, 0.4, 0.4), pommelAt, metal, Enum.Material.Metal, Enum.PartType.Ball).Reflectance = 0.15
	if rank >= 2 then
		part(model, "Gem", Vector3.new(0.18, 0.18, 0.18), pommelAt * CFrame.new(0, 0, 0.16), skin.trail or skin.blade, Enum.Material.Neon, Enum.PartType.Ball)
	end
end

local SHAPES = {}

function SHAPES.dagger(model, base, skin, s, rank)
	local blade = straightBlade(model, base * CFrame.new(0, 0.12 * s, 0), 0.42 * s, 2.3 * s, 0.75 * s, 0.12 * s, skin)
	guard(model, base, skin, 1.2 * s, rank)
	handle(model, base, skin, 1.3 * s, rank)
	return blade
end

function SHAPES.bone(model, base, skin, s, rank)
	local blade = straightBlade(model, base * CFrame.new(0, 0.12 * s, 0), 0.5 * s, 2.1 * s, 0.7 * s, 0.14 * s, skin)
	-- 등쪽 톱니
	for i = 1, 5 do
		local tooth = Instance.new("WedgePart")
		tooth.Name = "Tooth"
		tooth.Size = Vector3.new(0.12 * s, 0.22 * s, 0.18 * s)
		tooth.CFrame = base * CFrame.new(-0.29 * s, (0.45 + i * 0.32) * s, 0) * CFrame.Angles(0, math.pi / 2, 0)
		tooth.Color = skin.blade
		tooth.Material = skin.bladeMaterial or Enum.Material.Sand
		tooth.Anchored = true
		tooth.CanCollide = false
		tooth.CanQuery = false
		tooth.CanTouch = false
		tooth.Parent = model
	end
	guard(model, base, skin, 0.9 * s, rank)
	handle(model, base, skin, 1.2 * s, rank)
	return blade
end

function SHAPES.cutlass(model, base, skin, s, rank)
	local blade = curvedBlade(model, base * CFrame.new(0, 0.12 * s, 0), 0.5 * s, 3.0 * s, 0.12 * s, skin, math.rad(-26), 6, 0.2)
	guard(model, base, skin, 1.1 * s, rank)
	-- 손을 감싸는 D 자 손잡이 보호대
	local metal = skin.guard or Color3.fromRGB(126, 104, 62)
	part(model, "KnuckleBow", Vector3.new(0.09 * s, 1.35 * s, 0.12 * s), base * CFrame.new(0.52 * s, -0.72 * s, 0), metal, Enum.Material.Metal)
	part(model, "KnuckleBow", Vector3.new(0.5 * s, 0.09 * s, 0.12 * s), base * CFrame.new(0.28 * s, -1.4 * s, 0), metal, Enum.Material.Metal)
	handle(model, base, skin, 1.3 * s, rank)
	return blade
end

function SHAPES.fang(model, base, skin, s, rank)
	local blade = curvedBlade(model, base * CFrame.new(0, 0.12 * s, 0), 0.62 * s, 2.7 * s, 0.16 * s, skin, math.rad(-38), 6, 0.62)
	guard(model, base, skin, 1.3 * s, rank)
	handle(model, base, skin, 1.3 * s, rank)
	return blade
end

function SHAPES.hook(model, base, skin, s, rank)
	local blade = curvedBlade(model, base * CFrame.new(0, 0.12 * s, 0), 0.32 * s, 2.6 * s, 0.14 * s, skin, math.rad(-150), 7, 0.4)
	guard(model, base, skin, 0.8 * s, rank)
	handle(model, base, skin, 1.4 * s, rank)
	return blade
end

function SHAPES.kris(model, base, skin, s, rank)
	-- 물결치는 날 : 조각을 번갈아 비튼다
	local cf = base * CFrame.new(0, 0.12 * s, 0)
	local step = 0.42 * s
	local main = nil
	for i = 1, 6 do
		local angle = (i % 2 == 0) and math.rad(14) or math.rad(-14)
		local w = 0.44 * s * (1 - 0.35 * (i - 1) / 6)
		local piece = part(model, i == 1 and "Blade" or "BladeCurve", Vector3.new(w, step * 1.12, 0.12 * s), cf * CFrame.Angles(0, 0, angle) * CFrame.new(0, step * 0.5, 0), skin.blade, skin.bladeMaterial)
		piece.Reflectance = skin.glow and 0.25 or 0.12
		main = main or piece
		cf = cf * CFrame.new(0, step, 0)
	end
	local tipBase = cf * CFrame.new(0, 0.3 * s, 0)
	for _, sign in ipairs({ 1, -1 }) do
		tipHalf(model, tipBase, 0.14 * s, 0.6 * s, 0.12 * s, sign, skin.blade, skin.bladeMaterial)
	end
	guard(model, base, skin, 1.25 * s, rank)
	handle(model, base, skin, 1.3 * s, rank)
	return main
end

function SHAPES.harpoon(model, base, skin, s, rank)
	-- 긴 자루 끝의 미늘 달린 촉
	local shaft = part(model, "Blade", Vector3.new(2.2 * s, 0.16 * s, 0.16 * s), base * CFrame.new(0, 1.2 * s, 0) * CFrame.Angles(0, 0, math.pi / 2),
		skin.blade:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Metal, Enum.PartType.Cylinder)
	local headBase = base * CFrame.new(0, 2.3 * s, 0)
	part(model, "HarpoonNeck", Vector3.new(0.26 * s, 0.3 * s, 0.14 * s), headBase * CFrame.new(0, 0.15 * s, 0), skin.blade, skin.bladeMaterial)
	for _, sign in ipairs({ 1, -1 }) do
		tipHalf(model, headBase * CFrame.new(0, 0.75 * s, 0), 0.28 * s, 0.9 * s, 0.12 * s, sign, skin.blade, skin.bladeMaterial)
		-- 거꾸로 달린 미늘
		local barb = tipHalf(model, headBase * CFrame.new(sign * 0.3 * s, 0.35 * s, 0) * CFrame.Angles(0, 0, math.pi), 0.16 * s, 0.4 * s, 0.1 * s, -sign, skin.blade, skin.bladeMaterial)
		barb.Name = "Barb"
	end
	for i = 1, 3 do
		part(model, "RopeWrap", Vector3.new(0.1 * s, 0.2 * s, 0.2 * s), base * CFrame.new(0, (0.3 + i * 0.12) * s, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(176, 150, 104), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	handle(model, base, skin, 1.1 * s, rank)
	return shaft
end

-- 메시(3D 모델) 설정이 있으면 { MeshId, TextureId, Scale } 을 돌려준다.
function KnifeModel.meshFor(skin)
	local ok, release = pcall(require, script.Parent.ReleaseConfig)
	local meshes = ok and release.Meshes and release.Meshes.Knife
	local entry = meshes and meshes[skin.id]
	if entry and (tonumber(entry.MeshId) or 0) > 0 then
		return entry
	end
	return nil
end

--[[
	skin   : GameConfig.Skins.Knife 의 한 줄
	parent : 모델을 넣을 곳
	base   : 코등이 자리 CFrame (칼끝은 base 의 +Y)
	scale  : 크기 배율 (기본 1 : 칼끝까지 약 3.3 스터드)
]]
function KnifeModel.build(skin, parent, base, scale)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Knife"
	local rank = RARITY_RANK[skin.rarity or "common"] or 1
	local mesh = KnifeModel.meshFor(skin)
	local blade
	local blender = nil
	if not mesh then
		local okKit, MeshKit = pcall(require, script.Parent.MeshKit)
		if okKit and MeshKit.hasKnife(skin) then
			local made, main = MeshKit.knife(skin, model, base, s)
			if made and main then
				blender = made
				blade = main
				model:SetAttribute("MeshFrame", base)
				model:SetAttribute("MeshScale", s)
				for _, piece in ipairs(made) do
					piece.CastShadow = false
				end
			end
		end
	end
	if blender then
		-- Blender 칼 (위에서 놓았다)
	elseif mesh then
		blade = part(model, "Blade", Vector3.new(1, 1, 1) * s, base * CFrame.new(0, 1 * s, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		local special = Instance.new("SpecialMesh")
		special.MeshType = Enum.MeshType.FileMesh
		special.MeshId = "rbxassetid://" .. tostring(mesh.MeshId)
		if (tonumber(mesh.TextureId) or 0) > 0 then
			special.TextureId = "rbxassetid://" .. tostring(mesh.TextureId)
		end
		special.Scale = (mesh.Scale or Vector3.new(1, 1, 1)) * s
		special.Parent = blade
	else
		local builder = SHAPES[skin.shape or "dagger"] or SHAPES.dagger
		blade = builder(model, base, skin, s, rank)
	end
	if skin.glow and skin.glow > 0 and blade then
		local light = Instance.new("PointLight")
		light.Color = skin.trail or skin.blade
		light.Brightness = 2.2 * skin.glow
		light.Range = 10 * s
		light.Shadows = false
		light.Parent = blade
	end
	model.PrimaryPart = blade
	model.WorldPivot = base
	model.Parent = parent
	return model
end

return KnifeModel
