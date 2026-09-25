--[[
	MeshKit  (Phase 15)
	Blender 로 만든 3D 모델을 게임에 놓는다.

	모델 파일 : assets/models/CursedBarrelModels.fbx (tools/blender/build_models.py 가 만든다)
	넣는 법   : Studio → 홈 → 3D 가져오기 → 그 파일 → 가져오기. 그리고 저장(Publish).
	            CB_ 로 시작하는 MeshPart 가 가득 든 모델이 Workspace 에 생긴다. 그대로 두면 된다.
	            (서버가 켜질 때 ReplicatedStorage 로 옮겨 보이지 않는 보관함으로 쓴다: MeshKit.adopt)

	· 조각마다 크기 · 자리는 MeshCatalog(자동 생성)에 있다. 가져오기 창의 단위 설정이 무엇이든
	  Size · CFrame 을 그 값으로 다시 맞추므로 제자리 · 제 크기에 놓인다.
	· 모델을 아직 안 넣었으면 모든 함수가 nil / false 를 돌려준다. 부르는 쪽은 예전(파트로 만든) 모양을 그대로 쓴다.
	  그래서 모델이 없어도 게임은 똑같이 돌아간다.
	· 색 · 재질은 부르는 쪽이 정한다 (통 스킨 색, 크라켄 색 …). 가져온 텍스처 · SurfaceAppearance 는 떼어 낸다.

	Phase 17 : 스킨 모델 파일이 하나 더 생겼다.
	  assets/models/CursedBarrelSkins.fbx (roblox-cursed-barrel/blender/build_all.py 가 만든다)
	  칼 7모양 · 통 장식 6종 · 해적 한 벌(+테마 장식 6) · 용 2종 · 꽃잎 · 룬 고리 · 크라켄 마디. SK_ 로 시작한다.
	  가져오는 법은 같다 (3D 가져오기 · "단일 메시로 가져오기" 끄기). 두 파일 모두 서버가 켜질 때 ReplicatedStorage 로 옮긴다.
	  크기 · 자리는 SkinMeshCatalog(자동 생성)에 있고 MeshCatalog 와 합쳐서 쓴다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseCatalog = require(script.Parent:WaitForChild("MeshCatalog"))
local SkinCatalog = require(script.Parent:WaitForChild("SkinMeshCatalog"))

-- 두 카탈로그를 하나로 합친다 (조각 이름이 CB_ / SK_ 로 달라서 겹치지 않는다)
local Catalog = { File = BaseCatalog.File, Digest = BaseCatalog.Digest, Pieces = {}, Assets = {}, PirateJoints = SkinCatalog.PirateJoints }
for _, source in ipairs({ BaseCatalog, SkinCatalog }) do
	for name, info in pairs(source.Pieces) do
		Catalog.Pieces[name] = info
	end
	for name, list in pairs(source.Assets) do
		Catalog.Assets[name] = list
	end
end

local MeshKit = {}
MeshKit.LibraryName = "CursedBarrelModels"
MeshKit.SkinLibraryName = "CursedBarrelSkins"
MeshKit.LibraryNames = { MeshKit.LibraryName, MeshKit.SkinLibraryName }
MeshKit.Catalog = Catalog

local libraries = {} -- [이름] = Model
local templates = {}

-- 파일마다 들어 있어야 하는 조각 (이것으로 어느 파일을 가져온 모델인지 알아본다)
local MARKERS = {
	CursedBarrelModels = { "CB_Cannon_Tube", "CB_Cask_Staves", "CB_Kraken_Mantle" },
	CursedBarrelSkins = { "SK_Knife_dagger_Blade", "SK_Pirate_Coat", "SK_DragonCoil_Scales" },
}

local function isLibrary(instance, libraryName)
	if not instance or not (instance:IsA("Model") or instance:IsA("Folder")) then
		return false
	end
	for _, marker in ipairs(MARKERS[libraryName or MeshKit.LibraryName]) do
		if instance:FindFirstChild(marker, true) ~= nil then
			return true
		end
	end
	return false
end

--[[
	Phase 17.1 : 가져온 방향 바로잡기
	  Studio 3D 가져오기는 Blender 파일을 세로축(Y)으로 180° 돌려서 넣는다.
	  (가져온 조각의 자리가 카탈로그의 (-x, y, -z) 에 있다 → 메시도 조각 안에서 180° 돌아가 있다)
	  둥근 통 · 드럼은 티가 안 나지만, 누운 크라켄 다리는 살이 선실 쪽으로 뒤집히고 빨판만 2층에 떠 있었다.
	  두 조각의 가져온 자리를 카탈로그와 비교해서 파일마다 돌림을 알아내고, 놓을 때 되돌린다.
]]
local IDENTITY = CFrame.new()
local HALF_TURN = CFrame.Angles(0, math.pi, 0)
local PROBES = {
	CursedBarrelModels = { "CB_Kraken_Mantle", "CB_Cask_Hoops" },
	CursedBarrelSkins = { "SK_DragonCoil_Eyes", "SK_Kraken_Capsule" },
}
local fixes = {} -- [라이브러리 이름] = CFrame

local function detectFix(libraryName, root)
	local probe = PROBES[libraryName]
	local a = probe and root:FindFirstChild(probe[1], true)
	local b = probe and root:FindFirstChild(probe[2], true)
	local ia = probe and Catalog.Pieces[probe[1]]
	local ib = probe and Catalog.Pieces[probe[2]]
	if not (a and b and ia and ib and a:IsA("BasePart") and b:IsA("BasePart")) then
		return IDENTITY
	end
	local imported = b.CFrame:PointToObjectSpace(a.CFrame.Position)
	local expected = ia.center - ib.center
	local turned = Vector3.new(-expected.X, expected.Y, -expected.Z)
	if (imported - turned).Magnitude + 1e-3 < (imported - expected).Magnitude then
		return HALF_TURN
	end
	return IDENTITY
end

function MeshKit.isLibraryName(name)
	return name == MeshKit.LibraryName or name == MeshKit.SkinLibraryName
end

-- 서버 : Studio 에서 가져온 모델(Workspace)을 ReplicatedStorage 로 옮긴다. 테이블 · 배를 세우기 전에 한 번 부른다.
local function adoptOne(libraryName)
	local existing = ReplicatedStorage:FindFirstChild(libraryName)
	if isLibrary(existing, libraryName) then
		libraries[libraryName] = existing
		fixes[libraryName] = detectFix(libraryName, existing)
		return existing
	end
	local places = { workspace, game:GetService("ServerStorage"), ReplicatedStorage }
	local packageRoot = ReplicatedStorage:FindFirstChild("CursedBarrel")
	if packageRoot then
		table.insert(places, packageRoot)
	end
	for _, place in ipairs(places) do
		for _, child in ipairs(place:GetChildren()) do
			if child ~= existing and isLibrary(child, libraryName) then
				child.Name = libraryName
				-- 보관함의 조각은 보이지도 부딪히지도 않는다 (Workspace 에 있을 때 잠깐이라도)
				for _, piece in ipairs(child:GetDescendants()) do
					if piece:IsA("BasePart") then
						piece.Anchored = true
						piece.CanCollide = false
						piece.CanTouch = false
						piece.CanQuery = false
					end
				end
				child.Parent = ReplicatedStorage
				libraries[libraryName] = child
				fixes[libraryName] = detectFix(libraryName, child)
				table.clear(templates)
				print(("[CursedBarrel] Blender 3D 모델을 찾았습니다: %s (%s)"):format(libraryName, place.Name))
				return child
			end
		end
	end
	return nil
end

function MeshKit.adopt()
	if not RunService:IsServer() then
		return MeshKit.library()
	end
	local found = nil
	for _, libraryName in ipairs(MeshKit.LibraryNames) do
		found = adoptOne(libraryName) or found
	end
	return found
end

local function libraryOf(libraryName)
	local cached = libraries[libraryName]
	if cached and cached.Parent then
		return cached
	end
	local found = ReplicatedStorage:FindFirstChild(libraryName)
	if isLibrary(found, libraryName) then
		libraries[libraryName] = found
		fixes[libraryName] = detectFix(libraryName, found)
		table.clear(templates)
		return found
	end
	return nil
end

-- 이 조각을 놓을 때 곱할 돌림 (가져오기가 180° 돌려 넣었으면 되돌린다)
function MeshKit.fixOf(name)
	local libraryName = name:sub(1, 3) == "SK_" and MeshKit.SkinLibraryName or MeshKit.LibraryName
	if not libraryOf(libraryName) then
		return IDENTITY
	end
	return fixes[libraryName] or IDENTITY
end

function MeshKit.library()
	return libraryOf(MeshKit.LibraryName)
end

function MeshKit.skinLibrary()
	return libraryOf(MeshKit.SkinLibraryName)
end

function MeshKit.template(name)
	local cached = templates[name]
	if cached and cached.Parent then
		return cached
	end
	local root = libraryOf(name:sub(1, 3) == "SK_" and MeshKit.SkinLibraryName or MeshKit.LibraryName)
	if not root then
		return nil
	end
	local piece = root:FindFirstChild(name, true)
	if piece and piece:IsA("MeshPart") then
		templates[name] = piece
		return piece
	end
	return nil
end

-- 이 묶음(Catalog.Assets)의 조각이 전부 있는가
function MeshKit.has(asset)
	local names = Catalog.Assets[asset]
	if not names then
		return false
	end
	for _, name in ipairs(names) do
		if not (Catalog.Pieces[name] and MeshKit.template(name)) then
			return false
		end
	end
	return true
end

local function scaleOf(value)
	if typeof(value) == "Vector3" then
		return value
	end
	local n = tonumber(value) or 1
	return Vector3.new(n, n, n)
end

--[[
	조각 하나를 놓는다.
	  origin : 묶음의 기준 CFrame (world 조각은 무시하고 월드 좌표 그대로)
	  opts   : parent · name · scale(숫자 또는 Vector3) · color · material · reflectance · transparency · shadow
]]
function MeshKit.place(name, origin, opts)
	opts = opts or {}
	local template = MeshKit.template(name)
	local info = Catalog.Pieces[name]
	if not template or not info then
		return nil
	end
	local part = template:Clone()
	for _, child in ipairs(part:GetChildren()) do
		-- 가져올 때 붙은 텍스처 · 표면 · 이음새는 쓰지 않는다 (색은 부르는 쪽이 칠한다)
		if child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture") or child:IsA("JointInstance")
			or child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	pcall(function()
		part.TextureID = ""
	end)
	local scale = scaleOf(opts.scale)
	part.Name = opts.name or name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = opts.shadow == true
	part.Size = info.size * scale
	local fix = MeshKit.fixOf(name)
	if info.world then
		part.CFrame = CFrame.new(info.center) * fix
	else
		part.CFrame = (origin or CFrame.new()) * CFrame.new(info.center * scale) * fix
	end
	if opts.color then
		part.Color = opts.color
	end
	if opts.material then
		part.Material = opts.material
	end
	part.Reflectance = opts.reflectance or 0
	part.Transparency = opts.transparency or 0
	part:SetAttribute("MeshKit", name)
	part.Parent = opts.parent
	return part
end

-- 묶음 하나를 통째로 놓는다. styles[조각 이름] = opts (없으면 base 를 쓴다). 조각 목록을 돌려준다.
function MeshKit.build(asset, origin, base, styles)
	if not MeshKit.has(asset) then
		return nil
	end
	local made = {}
	for _, name in ipairs(Catalog.Assets[asset]) do
		local opts = table.clone(base or {})
		for key, value in pairs((styles and styles[name]) or {}) do
			opts[key] = value
		end
		local part = MeshKit.place(name, origin, opts)
		if part then
			table.insert(made, part)
		end
	end
	return made
end

-- 통 스킨에 맞는 몸통 모양 : 드럼통 스킨(drum · ribbed)은 철제 드럼, 나머지는 나무통
function MeshKit.barrelAsset(skin)
	if skin and (skin.drum or skin.ribbed) then
		return "Drum"
	end
	return "Cask"
end

--[[
	통 몸통 메시 (게임 테이블 · 전시대 · 상점 미리보기가 같이 쓴다)
	  bodyCFrame : 원통 파트의 CFrame (원통의 X 축이 세로)
	  length · diameter : 원통 파트의 길이 · 지름. 메시는 높이 4 · 지름 3.5 기준으로 만들어져 있어서 비율대로 늘린다.
	돌려주는 값 : 만든 조각 목록 (메시가 없으면 nil)
]]
function MeshKit.barrel(skin, parent, bodyCFrame, length, diameter, name)
	local asset = MeshKit.barrelAsset(skin)
	if not MeshKit.has(asset) or not skin then
		return nil
	end
	-- 원통 파트의 +X 를 위로 세운 좌표계
	local up = bodyCFrame.RightVector
	if up.Y < 0 then
		up = -up
	end
	local look = bodyCFrame.LookVector - up * bodyCFrame.LookVector:Dot(up)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	local origin = CFrame.lookAt(bodyCFrame.Position, bodyCFrame.Position + look.Unit, up)
	local scale = Vector3.new(diameter / 3.5, length / 4, diameter / 3.5)
	local body = { color = skin.body, material = skin.bodyMaterial, reflectance = skin.reflectance, parent = parent, scale = scale }
	local hoop = { color = skin.hoop, material = skin.hoopMaterial or Enum.Material.Metal, reflectance = skin.reflectance }
	local styles = {
		CB_Cask_Staves = { name = name or "MeshBody" },
		CB_Cask_Hoops = hoop,
		CB_Drum_Shell = { name = name or "MeshBody" },
		CB_Drum_Rings = hoop,
	}
	local made = MeshKit.build(asset, origin, body, styles)
	if made then
		-- Phase 17 : 스킨별 장식 (보물 · 김치통 · 화산 · 유빙 · 심연 · 용의 봉인)
		for _, part in ipairs(MeshKit.barrelDecor(skin, parent, origin, scale)) do
			table.insert(made, part)
		end
		-- 용 · 룬 고리 연출(SkinMotion)이 도는 축과 크기
		if parent then
			parent:SetAttribute("MeshFrame", origin)
			parent:SetAttribute("MeshScale", math.min(scale.X, scale.Y))
		end
	end
	return made
end


--------------------------------------------------
-- Phase 17 : Blender 스킨 조각
--------------------------------------------------

local RANK = { common = 1, rare = 2, epic = 3, legend = 4, mythic = 5 }
MeshKit.Rank = RANK
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- 조각 이름의 마지막 토막 (SK_Knife_dagger_Blade → Blade)
local function slotOf(name)
	local info = Catalog.Pieces[name]
	return info and info.slot or name:match("_([^_]+)$")
end
MeshKit.slotOf = slotOf

-- 칼 : KnifeModel 과 같은 약속 (base = 코등이 자리, 칼끝 = base 의 +Y). 스킨 색을 조각마다 칠한다.
function MeshKit.knifeStyles(skin)
	local blade = skin.blade or Color3.fromRGB(206, 210, 214)
	local bladeMaterial = skin.bladeMaterial or Enum.Material.Metal
	local guard = skin.guard or Color3.fromRGB(126, 104, 62)
	local handle = skin.handle or Color3.fromRGB(64, 42, 28)
	local neon = bladeMaterial == Enum.Material.Neon
	return {
		Blade = { color = blade, material = bladeMaterial, reflectance = skin.glow and 0.25 or 0.12 },
		Edge = { color = blade:Lerp(WHITE, 0.45), material = neon and Enum.Material.Neon or Enum.Material.Metal, reflectance = 0.2 },
		Guard = { color = guard, material = Enum.Material.Metal, reflectance = 0.15 },
		Pommel = { color = guard, material = Enum.Material.Metal, reflectance = 0.15 },
		Handle = { color = handle, material = skin.handleMaterial or Enum.Material.Wood },
		Wrap = { color = handle:Lerp(BLACK, 0.45), material = Enum.Material.Fabric },
		Gem = { color = skin.trail or blade, material = Enum.Material.Neon },
	}
end

function MeshKit.hasKnife(skin)
	return skin ~= nil and MeshKit.has("Knife_" .. tostring(skin.shape or "dagger"))
end

-- 칼 조각을 놓는다. 조각 이름은 칸 이름(Blade · Edge · Guard …)이 된다. 돌려주는 값 : 조각 목록, Blade 조각
function MeshKit.knife(skin, parent, base, scale)
	if not MeshKit.hasKnife(skin) then
		return nil
	end
	local rank = RANK[skin.rarity or "common"] or 1
	local styles = MeshKit.knifeStyles(skin)
	local made, blade = {}, nil
	for _, name in ipairs(Catalog.Assets["Knife_" .. tostring(skin.shape or "dagger")]) do
		local slot = slotOf(name)
		if slot ~= "Gem" or rank >= 2 then
			local opts = table.clone(styles[slot] or {})
			opts.parent = parent
			opts.name = slot
			opts.scale = scale or 1
			local part = MeshKit.place(name, base, opts)
			if part then
				table.insert(made, part)
				if slot == "Blade" then
					blade = part
				end
			end
		end
	end
	return made, blade
end

-- 통 장식 (Blender) : 칼이 꽂히는 가운데 띠는 비워 두고 위 테두리 · 발치 · 뚜껑 둘레만 꾸민다
MeshKit.BarrelDecor = {
	treasure = "treasure", kimchi = "kimchi", volcano = "volcano", frost = "frost", abyss = "abyss",
	tide_dragon = "dragon", crimson_dragon = "dragon", moon_dragon = "dragon",
}

function MeshKit.barrelDecorStyles(skin)
	local hoop = skin.hoop or Color3.fromRGB(58, 48, 42)
	local body = skin.body or Color3.fromRGB(122, 78, 44)
	local glow = skin.glow or hoop
	local emit = (skin.fx and skin.fx.emit) or glow
	return {
		Gold = { color = hoop, material = Enum.Material.Metal, reflectance = 0.2 },
		Coin = { color = Color3.fromRGB(255, 214, 90), material = Enum.Material.Metal, reflectance = 0.25 },
		Gem = { color = emit, material = Enum.Material.Neon },
		Latch = { color = hoop, material = Enum.Material.Plastic },
		Rock = { color = body, material = Enum.Material.Basalt },
		Glow = { color = skin.hoopMaterial == Enum.Material.Neon and hoop or emit, material = Enum.Material.Neon },
		Crystal = { color = hoop, material = Enum.Material.Glass, transparency = 0.15 },
		Ice = { color = skin.lid or hoop, material = Enum.Material.Ice },
		Tentacle = { color = body:Lerp(Color3.fromRGB(96, 60, 150), 0.55), material = Enum.Material.SmoothPlastic },
		Claw = { color = hoop, material = Enum.Material.Metal, reflectance = 0.2 },
		Chain = { color = Color3.fromRGB(70, 74, 80), material = Enum.Material.Metal },
		Seal = { color = Color3.fromRGB(245, 230, 190), material = Enum.Material.SmoothPlastic },
	}
end

function MeshKit.barrelDecor(skin, parent, origin, scale)
	local theme = skin and MeshKit.BarrelDecor[skin.id]
	if not theme or not MeshKit.has("BarrelDecor_" .. theme) then
		return {}
	end
	local styles = MeshKit.barrelDecorStyles(skin)
	local made = {}
	for _, name in ipairs(Catalog.Assets["BarrelDecor_" .. theme]) do
		local slot = slotOf(name)
		local opts = table.clone(styles[slot] or {})
		opts.parent = parent
		opts.name = "Decor" .. slot
		opts.scale = scale
		local part = MeshKit.place(name, origin, opts)
		if part then
			table.insert(made, part)
		end
	end
	return made
end

return MeshKit
