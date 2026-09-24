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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(script.Parent:WaitForChild("MeshCatalog"))

local MeshKit = {}
MeshKit.LibraryName = "CursedBarrelModels"
MeshKit.Catalog = Catalog

local library = nil
local templates = {}

local function isLibrary(instance)
	if not instance or not (instance:IsA("Model") or instance:IsA("Folder")) then
		return false
	end
	return instance:FindFirstChild("CB_Cannon_Tube", true) ~= nil or instance:FindFirstChild("CB_Cask_Staves", true) ~= nil
		or instance:FindFirstChild("CB_Kraken_Mantle", true) ~= nil
end

-- 서버 : Studio 에서 가져온 모델(Workspace)을 ReplicatedStorage 로 옮긴다. 테이블 · 배를 세우기 전에 한 번 부른다.
function MeshKit.adopt()
	if not RunService:IsServer() then
		return MeshKit.library()
	end
	local existing = ReplicatedStorage:FindFirstChild(MeshKit.LibraryName)
	if isLibrary(existing) then
		library = existing
		return existing
	end
	local places = { workspace, game:GetService("ServerStorage"), ReplicatedStorage }
	local packageRoot = ReplicatedStorage:FindFirstChild("CursedBarrel")
	if packageRoot then
		table.insert(places, packageRoot)
	end
	for _, place in ipairs(places) do
		for _, child in ipairs(place:GetChildren()) do
			if child ~= existing and isLibrary(child) then
				child.Name = MeshKit.LibraryName
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
				library = child
				table.clear(templates)
				print(("[CursedBarrel] Blender 3D 모델을 찾았습니다 (%s)"):format(place.Name))
				return child
			end
		end
	end
	return nil
end

function MeshKit.library()
	if library and library.Parent then
		return library
	end
	local found = ReplicatedStorage:FindFirstChild(MeshKit.LibraryName)
	if isLibrary(found) then
		library = found
		table.clear(templates)
		return found
	end
	return nil
end

function MeshKit.template(name)
	local cached = templates[name]
	if cached and cached.Parent then
		return cached
	end
	local root = MeshKit.library()
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
	if info.world then
		part.CFrame = CFrame.new(info.center)
	else
		part.CFrame = (origin or CFrame.new()) * CFrame.new(info.center * scale)
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
	return MeshKit.build(asset, origin, body, styles)
end

return MeshKit
