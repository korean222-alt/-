--[[
	PirateModel  (Phase 11)
	통에서 튀어나오는 해적을 코드로 만든다. (클라이언트 전용 · 각자 화면에만 있다)

	Phase 10 까지의 해적은 파일에 저장된 블록 20개짜리 모형(Visuals.GhostCaptain)이었다.
	이제는 약 60개 부품으로 해골 선장을 만든다.
	  · 턱이 열린다 (비명) · 팔을 뻗는다 (움켜쥐기) · 몸을 앞으로 숙인다
	  · 삼각 모자 · 해골 문장 · 깃털 · 견장 · 쇠사슬 · 해초 수염 · 찢어진 옷자락 · 갈고리 손

	Phase 17 : Blender 해적 (assets/models/CursedBarrelSkins.fbx 의 SK_Pirate_ 조각)
	  · 가져왔으면 부품 대신 Blender 메시로 만든다. 관절 무리(body · head · jaw · armL · armR · tail)가 같아서
	    비명 · 움켜쥐기 · 숙이기 · 꼬리 흔들림이 그대로 움직인다.
	  · 스킨마다 색이 다르고, 테마 장식이 붙는다 : 좀비 요리사 = 요리사 모자, 크라켄 = 촉수 수염,
	    공허의 왕 = 가시 왕관, 잿불 망령 = 불꽃 왕관, 심해의 인어 = 지느러미 · 조개 장식, 용 세트 = 용뿔 · 갈기.
	  · Creator Store 에서 받은 해적(CustomPirate)은 더 쓰지 않는다. (Main 이 켜질 때 치운다)

	좌표 약속 (Phase4Controller 의 카메라가 이 값을 믿는다)
	  · 기준점(pivot) = 가슴 가운데. 정면 = -Z. 위 = +Y.
	  · 키는 모자 끝(+3.9)부터 안개 꼬리 끝(-3.4)까지 약 7.5 스터드.
]]

local PirateModel = {}
PirateModel.__index = PirateModel

local MeshKit = require(script.Parent.MeshKit)

local WHITE = Color3.fromRGB(240, 236, 220)
local IRON = Color3.fromRGB(96, 100, 106)

-- 부품이 속한 무리. 무리마다 기준 관절이 있고, 관절을 돌리면 딸린 부품이 같이 돈다.
local JOINTS = {
	body = CFrame.new(),
	head = CFrame.new(0, 1.4, 0),
	jaw = CFrame.new(0, 0.33, -0.35), -- 머리 관절 기준
	armL = CFrame.new(-1.25, 1.0, 0),
	armR = CFrame.new(1.25, 1.0, 0),
	tail = CFrame.new(0, -1.55, 0),
}

local function colorOf(skin, key, fallback)
	return (skin and skin[key]) or fallback
end

function PirateModel.new(skin, visuals)
	local self = setmetatable({}, PirateModel)
	self.items = {} -- { part, group, rest, base }

	-- Phase 17 : Blender 해적이 있으면 그것으로
	if MeshKit.has("Pirate") then
		local ok, err = pcall(PirateModel._buildMesh, self, skin)
		if ok then
			return self
		end
		warn("[CursedBarrel] Blender 해적을 만들지 못해 부품 해적을 씁니다: " .. tostring(err))
		if self.model then
			self.model:Destroy()
		end
		self.items = {}
	end

	local coat = colorOf(skin, "coat", Color3.fromRGB(58, 132, 122))
	local flesh = colorOf(skin, "skin", Color3.fromRGB(176, 246, 230))
	local hat = colorOf(skin, "hat", Color3.fromRGB(28, 36, 42))
	local accent = colorOf(skin, "accent", Color3.fromRGB(240, 202, 104))
	local aura = colorOf(skin, "aura", Color3.fromRGB(101, 241, 211))
	local dark = hat:Lerp(Color3.new(0, 0, 0), 0.4)
	local coatDark = coat:Lerp(Color3.new(0, 0, 0), 0.35)
	local kelp = flesh:Lerp(Color3.fromRGB(40, 90, 60), 0.55)

	local model = Instance.new("Model")
	model.Name = "GhostCaptain"
	self.model = model

	-- group 무리의 관절 기준 offset 에 크기 size 의 부품을 둔다.
	local function add(group, name, size, offset, color, material, shape, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Shape = shape or Enum.PartType.Block
		p.Transparency = transparency or 0
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		table.insert(self.items, { part = p, group = group, rest = offset, base = p.Transparency })
		return p
	end
	local rad = math.rad
	local Block, Ball, Cyl = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
	local Fabric, Metal, Neon = Enum.Material.Fabric, Enum.Material.Metal, Enum.Material.Neon

	-- 몸통 · 외투
	local torso = add("body", "Coat", Vector3.new(2.3, 2.5, 1.2), CFrame.new(), coat, Fabric)
	model.PrimaryPart = torso
	add("body", "Vest", Vector3.new(1.2, 2.2, 0.1), CFrame.new(0, -0.05, -0.61), dark, Fabric)
	add("body", "CollarL", Vector3.new(0.38, 1.3, 0.16), CFrame.new(-0.55, 0.7, -0.66) * CFrame.Angles(0, 0, rad(-14)), coatDark, Fabric)
	add("body", "CollarR", Vector3.new(0.38, 1.3, 0.16), CFrame.new(0.55, 0.7, -0.66) * CFrame.Angles(0, 0, rad(14)), coatDark, Fabric)
	for i = 0, 2 do
		add("body", "Button", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0, 0.45 - i * 0.42, -0.68), accent, Metal, Ball)
	end
	add("body", "Sash", Vector3.new(0.28, 2.9, 0.08), CFrame.new(0.1, 0.05, -0.64) * CFrame.Angles(0, 0, rad(36)), accent:Lerp(Color3.fromRGB(150, 30, 40), 0.6), Fabric)
	add("body", "Belt", Vector3.new(2.45, 0.3, 1.28), CFrame.new(0, -0.65, 0), hat, Enum.Material.Leather)
	add("body", "Buckle", Vector3.new(0.55, 0.4, 0.15), CFrame.new(0, -0.65, -0.72), accent, Metal)
	add("body", "Neck", Vector3.new(0.7, 0.45, 0.7), CFrame.new(0, 1.35, 0), flesh, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		add("body", "Epaulette", Vector3.new(0.95, 0.22, 0.95), CFrame.new(side * 1.28, 1.22, 0), accent, Metal)
		for f = -1, 1 do
			add("body", "Fringe", Vector3.new(0.09, 0.4, 0.09), CFrame.new(side * (1.28 + side * 0.4), 0.95, f * 0.3), accent, Metal)
		end
		-- 외투 자락 (뒤로 벌어진다)
		add("body", "Coat", Vector3.new(1.05, 1.9, 0.22), CFrame.new(side * 0.6, -1.85, 0.42) * CFrame.Angles(rad(14), 0, side * rad(6)), coat, Fabric)
	end
	-- 허리의 쇠사슬
	for i = 0, 6 do
		local t = i / 6
		local x = -0.95 + t * 1.9
		local y = -0.95 - math.sin(t * math.pi) * 0.35
		add("body", "Chain", Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, y, -0.66), IRON, Metal, Ball)
	end

	-- 머리 (해골 유령)
	add("head", "SpectralHead", Vector3.new(1.7, 1.8, 1.5), CFrame.new(0, 0.65, 0), flesh, Neon, Ball, 0.08)
	add("head", "Socket", Vector3.new(0.5, 0.46, 0.12), CFrame.new(0.38, 0.86, -0.66), dark, Enum.Material.SmoothPlastic)
	add("head", "Eye", Vector3.new(0.22, 0.26, 0.14), CFrame.new(0.38, 0.85, -0.74), accent, Neon)
	add("head", "EyePatch", Vector3.new(0.62, 0.5, 0.15), CFrame.new(-0.4, 0.85, -0.7), hat, Fabric)
	add("head", "PatchStrap", Vector3.new(1.76, 0.1, 1.56), CFrame.new(0, 0.98, 0) * CFrame.Angles(0, 0, rad(-18)), hat, Fabric)
	add("head", "Brow", Vector3.new(0.58, 0.13, 0.12), CFrame.new(0.38, 1.13, -0.7) * CFrame.Angles(0, 0, rad(22)), dark, Enum.Material.SmoothPlastic)
	add("head", "Nose", Vector3.new(0.2, 0.24, 0.1), CFrame.new(0, 0.6, -0.76), dark, Enum.Material.SmoothPlastic)
	add("head", "Teeth", Vector3.new(0.74, 0.14, 0.12), CFrame.new(0, 0.34, -0.72), WHITE, Enum.Material.SmoothPlastic)
	self.mouth = add("head", "Mouth", Vector3.new(0.62, 0.14, 0.08), CFrame.new(0, 0.26, -0.69), Color3.fromRGB(8, 10, 12), Enum.Material.SmoothPlastic)

	-- 턱 (열리면 비명)
	add("jaw", "Grin", Vector3.new(0.8, 0.2, 0.3), CFrame.new(0, -0.1, -0.24), flesh:Lerp(accent, 0.25), Enum.Material.SmoothPlastic)
	add("jaw", "LowerTeeth", Vector3.new(0.7, 0.1, 0.1), CFrame.new(0, 0.02, -0.36), WHITE, Enum.Material.SmoothPlastic)
	for i = -2, 2 do
		local length = 1.1 + (2 - math.abs(i)) * 0.25
		add("jaw", "Kelp", Vector3.new(0.12, length, 0.12), CFrame.new(i * 0.15, -0.2 - length * 0.5, -0.3) * CFrame.Angles(0, 0, rad(i * 5)), kelp, Enum.Material.SmoothPlastic, Block, 0.1)
	end

	-- 삼각 모자
	add("head", "HatBrim", Vector3.new(3.15, 0.22, 1.95), CFrame.new(0, 1.56, 0), hat, Fabric)
	add("head", "HatBrim", Vector3.new(0.22, 0.85, 1.9), CFrame.new(-1.45, 1.86, 0) * CFrame.Angles(0, 0, rad(-22)), hat, Fabric)
	add("head", "HatBrim", Vector3.new(0.22, 0.85, 1.9), CFrame.new(1.45, 1.86, 0) * CFrame.Angles(0, 0, rad(22)), hat, Fabric)
	add("head", "HatBrim", Vector3.new(3.0, 0.85, 0.22), CFrame.new(0, 1.86, 0.9) * CFrame.Angles(rad(-22), 0, 0), hat, Fabric)
	add("head", "HatCrown", Vector3.new(2.15, 0.8, 1.4), CFrame.new(0, 1.96, 0), hat, Fabric)
	add("head", "HatBand", Vector3.new(2.2, 0.18, 1.45), CFrame.new(0, 1.69, 0), accent, Fabric)
	add("head", "HatSkull", Vector3.new(0.44, 0.42, 0.2), CFrame.new(0, 2.02, -0.72), WHITE, Enum.Material.SmoothPlastic, Ball)
	add("head", "HatBone", Vector3.new(0.78, 0.09, 0.06), CFrame.new(0, 1.84, -0.74) * CFrame.Angles(0, 0, rad(32)), WHITE, Enum.Material.SmoothPlastic)
	add("head", "HatBone", Vector3.new(0.78, 0.09, 0.06), CFrame.new(0, 1.84, -0.74) * CFrame.Angles(0, 0, rad(-32)), WHITE, Enum.Material.SmoothPlastic)
	add("head", "Feather", Vector3.new(0.12, 1.7, 0.36), CFrame.new(0.95, 2.55, 0.35) * CFrame.Angles(rad(10), 0, rad(-38)), accent, Fabric)

	-- 팔 (어깨 관절 기준. 가만히 있을 때는 아래로 늘어뜨린다)
	for _, side in ipairs({ -1, 1 }) do
		local group = side < 0 and "armL" or "armR"
		add(group, "Arm", Vector3.new(0.66, 1.8, 0.7), CFrame.new(0, -0.85, 0), coat, Fabric)
		add(group, "Cuff", Vector3.new(0.8, 0.28, 0.8), CFrame.new(0, -1.72, 0), accent, Fabric)
		add(group, "Lace", Vector3.new(0.9, 0.14, 0.9), CFrame.new(0, -1.9, 0), WHITE, Fabric, Block, 0.15)
		if side < 0 then
			-- 왼손은 갈고리
			add(group, "HookBase", Vector3.new(0.34, 0.3, 0.34), CFrame.new(0, -2.05, 0), IRON, Metal, Cyl)
			add(group, "Hook", Vector3.new(0.1, 0.55, 0.1), CFrame.new(0, -2.42, 0), IRON, Metal)
			add(group, "Hook", Vector3.new(0.1, 0.1, 0.42), CFrame.new(0, -2.66, -0.16), IRON, Metal)
			add(group, "Hook", Vector3.new(0.1, 0.28, 0.1), CFrame.new(0, -2.55, -0.36), IRON, Metal)
		else
			add(group, "GhostHand", Vector3.new(0.65, 0.65, 0.65), CFrame.new(0, -2.15, 0), flesh, Neon, Ball)
			for f = -1, 1 do
				add(group, "Claw", Vector3.new(0.09, 0.5, 0.09), CFrame.new(f * 0.18, -2.55, -0.12) * CFrame.Angles(rad(-18), 0, rad(f * 8)), flesh:Lerp(WHITE, 0.4), Neon)
			end
		end
	end

	-- 안개 꼬리와 찢어진 옷자락
	add("tail", "MistTail", Vector3.new(1.9, 0.8, 1.1), CFrame.new(0, -0.45, 0), aura, Neon, Block, 0.42)
	add("tail", "MistTail", Vector3.new(0.95, 0.8, 0.55), CFrame.new(0, -0.95, 0), aura, Neon, Block, 0.54)
	add("tail", "MistTail", Vector3.new(0.63, 0.8, 0.37), CFrame.new(0, -1.45, 0), aura, Neon, Block, 0.66)
	for i = -2, 2 do
		add("tail", "Rag", Vector3.new(0.34, 0.8 + (i % 2) * 0.35, 0.08), CFrame.new(i * 0.42, -0.3, -0.62) * CFrame.Angles(0, 0, rad(i * 6)), coatDark, Fabric, Block, 0.2)
	end

	local light = Instance.new("PointLight")
	light.Color = aura
	light.Brightness = 2
	light.Range = 12
	light.Shadows = false
	light.Parent = torso
	self.light = light

	self.height = 8 -- 안개 꼬리 끝(-3.4)부터 깃털 끝(+4.6)까지
	self:pose(CFrame.new(), {})
	return self
end


--------------------------------------------------
-- Phase 17 : Blender 해적
--------------------------------------------------

-- 스킨마다 붙는 장식 · 숨기는 기본 조각 (build_all.py 의 pirate.THEME 과 같다)
local THEME = {
	cook = { add = { "ChefHat" }, hide = { "Hat", "HatTrim", "HatSkull", "Feather" } },
	kraken = { add = { "TentacleBeard" }, hide = { "Beard" } },
	voidking = { add = { "VoidCrown" }, hide = { "Feather" } },
	ember = { add = { "FlameCrown" }, hide = { "Feather" } },
	siren = { add = { "FinCrown" }, hide = {} },
	tide_dragon = { add = { "DragonHorns" }, hide = { "Feather" } },
	crimson_dragon = { add = { "DragonHorns" }, hide = { "Feather" } },
	moon_dragon = { add = { "DragonHorns" }, hide = { "Feather" } },
}
PirateModel.Theme = THEME

-- 조각 칸마다 색 · 재질 · 투명도 (build_all.py 의 pirate_colors.slots 와 같다)
function PirateModel.meshStyles(skin)
	local coat = colorOf(skin, "coat", Color3.fromRGB(58, 132, 122))
	local flesh = colorOf(skin, "skin", Color3.fromRGB(176, 246, 230))
	local hat = colorOf(skin, "hat", Color3.fromRGB(28, 36, 42))
	local accent = colorOf(skin, "accent", Color3.fromRGB(240, 202, 104))
	local aura = colorOf(skin, "aura", Color3.fromRGB(101, 241, 211))
	local dark = hat:Lerp(Color3.new(0, 0, 0), 0.4)
	local coatDark = coat:Lerp(Color3.new(0, 0, 0), 0.35)
	local kelp = flesh:Lerp(Color3.fromRGB(40, 90, 60), 0.55)
	local M = Enum.Material
	local function st(color, material, transparency, reflectance)
		return { color = color, material = material, transparency = transparency or 0, reflectance = reflectance or 0 }
	end
	return {
		Coat = st(coat, M.Fabric), CoatTrim = st(accent, M.Metal, 0, 0.15), Vest = st(dark, M.Fabric),
		Sash = st(accent:Lerp(Color3.fromRGB(150, 30, 40), 0.6), M.Fabric), Belt = st(hat, M.Leather), Buckle = st(accent, M.Metal, 0, 0.2),
		Epaulette = st(accent, M.Metal, 0, 0.15), Neck = st(flesh, M.SmoothPlastic), Iron = st(IRON, M.Metal),
		Head = st(flesh, M.SmoothPlastic), FaceDark = st(dark, M.SmoothPlastic), MouthDark = st(Color3.fromRGB(8, 10, 12), M.SmoothPlastic),
		Eye = st(accent, M.Neon), Patch = st(hat, M.Fabric), Teeth = st(WHITE, M.SmoothPlastic),
		Hat = st(hat, M.Fabric), HatTrim = st(accent, M.Metal, 0, 0.15), HatSkull = st(WHITE, M.SmoothPlastic), Feather = st(accent, M.Fabric),
		Jaw = st(flesh, M.SmoothPlastic), JawTeeth = st(WHITE, M.SmoothPlastic), Beard = st(kelp, M.SmoothPlastic, 0.1),
		SleeveL = st(coat, M.Fabric), CuffL = st(accent, M.Fabric), LaceL = st(WHITE, M.Fabric, 0.1), Hook = st(IRON, M.Metal, 0, 0.15),
		SleeveR = st(coat, M.Fabric), CuffR = st(accent, M.Fabric), LaceR = st(WHITE, M.Fabric, 0.1), HandR = st(flesh, M.Neon),
		Mist = st(aura, M.Neon, 0.45), Rags = st(coatDark, M.Fabric, 0.2),
		ChefHat = st(hat, M.SmoothPlastic), TentacleBeard = st(flesh:Lerp(Color3.new(0, 0, 0), 0.2), M.SmoothPlastic),
		VoidCrown = st(accent, M.Metal, 0, 0.2), FlameCrown = st(aura, M.Neon, 0.1), FinCrown = st(accent, M.SmoothPlastic, 0, 0.1),
		DragonHorns = st(accent, M.Metal, 0, 0.2),
	}
end

function PirateModel._buildMesh(self, skin)
	local catalog = MeshKit.Catalog
	local joints = catalog.PirateJoints
	local styles = PirateModel.meshStyles(skin)
	local theme = THEME[skin and skin.id or ""] or { add = {}, hide = {} }
	local hidden = {}
	for _, slot in ipairs(theme.hide) do
		hidden[slot] = true
	end
	local names = table.clone(catalog.Assets.Pirate)
	for _, extra in ipairs(theme.add) do
		for _, name in ipairs(catalog.Assets["PirateExtra_" .. extra] or {}) do
			table.insert(names, name)
		end
	end

	local model = Instance.new("Model")
	model.Name = "GhostCaptain"
	model:SetAttribute("Meshed", true)
	self.model = model
	local torso = nil
	for _, name in ipairs(names) do
		local slot = MeshKit.slotOf(name)
		local info = catalog.Pieces[name]
		if info and not hidden[slot] then
			local opts = table.clone(styles[slot] or {})
			opts.parent = model
			opts.name = slot
			local part = MeshKit.place(name, CFrame.new(), opts)
			if part then
				part.CastShadow = false
				local joint = joints[info.group or "body"] or Vector3.zero
				-- fixOf : 가져오기가 180° 돌려 넣은 메시를 되돌린다 (MeshKit.place 와 같은 약속)
				table.insert(self.items, { part = part, group = info.group or "body", rest = CFrame.new(info.center - joint) * MeshKit.fixOf(name), base = part.Transparency })
				if slot == "Coat" then
					torso = part
				end
			end
		end
	end
	assert(torso, "SK_Pirate_Coat 없음")
	model.PrimaryPart = torso
	self:pose(CFrame.new(), {})
	-- 모델의 기준점(pivot)은 가슴 가운데 (부품 해적과 같은 약속)
	torso.PivotOffset = torso.CFrame:ToObjectSpace(CFrame.new())

	local aura = colorOf(skin, "aura", Color3.fromRGB(101, 241, 211))
	local light = Instance.new("PointLight")
	light.Color = aura
	light.Brightness = 2
	light.Range = 12
	light.Shadows = false
	light.Parent = torso
	self.light = light
	self.height = 8
	self.meshed = true
end

-- SkinFX 처럼 나중에 붙은 부품도 몸통에 딸려 움직이게 한다. (지금 자세 기준으로 기억한다)
function PirateModel:adopt(pivot)
	local known = {}
	for _, item in ipairs(self.items) do
		known[item.part] = true
	end
	for _, p in ipairs(self.model:GetDescendants()) do
		if p:IsA("BasePart") and not known[p] then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			table.insert(self.items, { part = p, group = "body", rest = pivot:ToObjectSpace(p.CFrame), base = p.Transparency })
		end
	end
end

--[[
	자세를 잡는다. pose 의 값 (모두 생략 가능)
	  lean  : 몸을 앞으로 숙이는 각도(도)
	  reach : 0 = 팔을 늘어뜨림, 1 = 앞으로 쭉 뻗음
	  spread: 팔을 옆으로 벌리는 추가 각도(도)
	  jaw   : 0 = 다문 입, 1 = 크게 벌림
	  nod   : 고개를 숙이는 각도(도, 음수면 젖힌다)
	  sway  : 꼬리 · 옷자락 흔들림 각도(도)
	  claw  : 손가락 오므림 (팔 끝을 조금 더 굽힌다)
]]
function PirateModel:pose(pivot, pose)
	local rad = math.rad
	local lean = pose.lean or 0
	local body = pivot * CFrame.Angles(rad(-lean), 0, 0)

	local reach = pose.reach or 0
	local spread = pose.spread or 0
	local jaw = pose.jaw or 0
	local head = body * JOINTS.head * CFrame.Angles(rad(-(pose.nod or 0)), 0, 0)
	local frames = {
		body = body,
		head = head,
		jaw = head * JOINTS.jaw * CFrame.Angles(rad(-38 * jaw), 0, 0),
		armL = body * JOINTS.armL * CFrame.Angles(rad(95 * reach + (pose.claw or 0)), 0, rad(-(28 * (1 - reach) + 8 + spread))),
		armR = body * JOINTS.armR * CFrame.Angles(rad(95 * reach + (pose.claw or 0)), 0, rad(28 * (1 - reach) + 8 + spread)),
		tail = body * JOINTS.tail * CFrame.Angles(rad((pose.sway or 0) * 0.4), 0, rad(pose.sway or 0)),
	}
	-- 입 안쪽(검은 부분)은 턱이 벌어지는 만큼 길어진다.
	if self.mouth then
		self.mouth.Size = Vector3.new(0.62, 0.14 + 0.5 * jaw, 0.08)
		for _, item in ipairs(self.items) do
			if item.part == self.mouth then
				item.rest = CFrame.new(0, 0.26 - 0.25 * jaw, -0.69)
				break
			end
		end
	end

	local parts, cframes = {}, {}
	for _, item in ipairs(self.items) do
		table.insert(parts, item.part)
		table.insert(cframes, frames[item.group] * item.rest)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- 0 = 원래 투명도, 1 = 완전히 사라짐
function PirateModel:fade(alpha)
	for _, item in ipairs(self.items) do
		if item.part.Parent then
			item.part.Transparency = item.base + (1 - item.base) * math.clamp(alpha, 0, 1)
		end
	end
	if self.light then
		self.light.Brightness = 2 * (1 - math.clamp(alpha, 0, 1))
	end
end

function PirateModel:Destroy()
	if self.model then
		self.model:Destroy()
	end
	table.clear(self.items)
end

return PirateModel
