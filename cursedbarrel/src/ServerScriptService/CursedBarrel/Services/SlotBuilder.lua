--[[
	SlotBuilder  (Phase 3)
	통 둘레의 "칼 슬롯"을 만들고, 칼을 보이게/숨기게 하는 일만 담당한다.

	왜 서버가 직접 만드나?
	  테이블 모델을 복제하거나 손으로 만들어도 슬롯 수와 배치가 항상 같아야 하기 때문이다.
	  모델 안에 이미 KnifeSlots 폴더가 있고 개수가 맞으면 그대로 쓰고,
	  없거나 개수가 다르면 그 자리에서 다시 만든다.

	배치 규칙
	  - 통 몸통(Barrel > Body) 파트의 실제 크기를 재서 반지름/높이를 얻는다
	  - 슬롯이 8개를 넘으면 두 줄, 16개를 넘으면 세 줄로 두른다
	  - 줄마다 반 칸씩 어긋나게 배치해 칼이 서로 겹치지 않는다

	★ "위험 슬롯"은 여기서 다루지 않는다.
	   이 모듈이 만드는 것은 눈에 보이는 슬롯/칼뿐이고,
	   어느 자리가 터지는지는 RoundService 의 서버 메모리에만 있다.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MeshKit = require(Shared:WaitForChild("MeshKit")) -- Phase 17 : Blender 칼

local LAYOUT = GameConfig.SlotLayout
-- Phase 17 : Blender 칼을 슬롯에 꽂을 때. 코등이가 통 겉면에서 이만큼 떨어지고, 이 배율로 줄인다
--   (손잡이 약 0.7 · 날은 통 안으로 들어간다. 예전 네모 칼과 같은 자리 · 같은 크기)
local SLOT_GUARD_Z = 1.05
local SLOT_KNIFE_SCALE = 0.55
local SLOT_ATTR = GameConfig.SlotAttributes

local SlotBuilder = {}

--------------------------------------------------
-- 통 크기 재기
--------------------------------------------------

local function findBarrelBody(model)
	local barrel = model:FindFirstChild(LAYOUT.BarrelName)
	if barrel then
		local body = barrel:FindFirstChild(LAYOUT.BodyName, true)
		if body and body:IsA("BasePart") then
			return body
		end
		if barrel:IsA("Model") and barrel.PrimaryPart then
			return barrel.PrimaryPart
		end
	end

	local body = model:FindFirstChild(LAYOUT.BodyName, true)
	if body and body:IsA("BasePart") then
		return body
	end

	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

-- 원통 파트는 길이가 X, 지름이 Y/Z 다. 상자면 가로/세로 중 큰 쪽을 지름으로 본다.
local function measureBarrel(body)
	local size = body.Size
	if body:IsA("Part") and body.Shape == Enum.PartType.Cylinder then
		return size.Y * 0.5, size.X
	end
	return math.max(size.X, size.Z) * 0.5, size.Y
end

--------------------------------------------------
-- 슬롯 위치 계산
-- 같은 입력이면 항상 같은 결과가 나온다. (설치 파일과 런타임이 어긋나지 않는다)
--------------------------------------------------

function SlotBuilder.layout(count, center, radius, height)
	local rings = math.max(1, math.ceil(count / LAYOUT.MaxPerRing))
	local perRing = {}
	local base = math.floor(count / rings)
	local extra = count % rings
	for ring = 1, rings do
		perRing[ring] = base + (ring <= extra and 1 or 0)
	end

	local spread = height * LAYOUT.RingSpread
	local result = {}
	local index = 0

	for ring = 1, rings do
		local ringCount = perRing[ring]
		if ringCount > 0 then
			local t = (rings == 1) and 0.5 or (ring - 1) / (rings - 1)
			local offsetY = (rings == 1) and 0 or (spread - t * spread * 2)
			local angleOffset = (ring - 1) * math.pi / ringCount -- 줄마다 반 칸씩 어긋나게

			for slot = 1, ringCount do
				index += 1
				local angle = (slot - 1) / ringCount * math.pi * 2 + angleOffset
				local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
				local position = center + outward * (radius + LAYOUT.SurfaceGap) + Vector3.new(0, offsetY, 0)

				result[index] = {
					index = index,
					ring = ring,
					angle = angle,
					-- 정면(LookVector)이 통 안쪽을 향한다. 칼은 이 방향으로 들어간다.
					cframe = CFrame.new(position) * CFrame.Angles(0, angle, 0),
				}
			end
		end
	end

	return result
end

--------------------------------------------------
-- 인스턴스 만들기
--------------------------------------------------

local function makePart(name, size, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- 슬롯 하나 = 표시용 홈 + (평소에는 투명한) 칼 한 자루
local function buildSlot(folder, spot)
	local marker = Instance.new("Part")
	marker.Name = ("Slot_%02d"):format(spot.index)
	marker.Size = LAYOUT.MarkerSize
	marker.Color = LAYOUT.MarkerColor
	marker.Material = Enum.Material.SmoothPlastic
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = true
	marker.TopSurface = Enum.SurfaceType.Smooth
	marker.BottomSurface = Enum.SurfaceType.Smooth
	marker.CFrame = spot.cframe
	marker.Parent = folder

	local knife = Instance.new("Model")
	knife.Name = "Knife"
	knife.Parent = marker

	local knifeBase = spot.cframe * CFrame.Angles(math.rad(-LAYOUT.KnifeTilt), 0, 0)

	local blade = makePart("Blade", LAYOUT.BladeSize, LAYOUT.BladeColor, Enum.Material.Metal, knife)
	blade.CFrame = knifeBase * CFrame.new(0, 0, 0.2)
	blade.Transparency = 1

	local handle = makePart("Handle", LAYOUT.HandleSize, LAYOUT.HandleColor, Enum.Material.Wood, knife)
	handle.CFrame = knifeBase * CFrame.new(0, 0, 1.35)
	handle.Transparency = 1

	knife.PrimaryPart = blade
	SlotBuilder.ensureDetail(marker)

	return marker
end

--[[
	Phase 11 : 칼 장식. 날 광택 · 손잡이 끈 · 폼멜(손잡이 끝 구슬)을 덧붙인다.
	파일에 이미 저장된 슬롯(예전 칼)에도 붙이도록 따로 둔다. 이미 있으면 건너뛴다.
	장식도 칼과 똑같이 숨겨졌다가(Transparency 1) 꽂히면 드러난다.
]]
local DETAIL_DEFAULTS = {
	Edge = { color = Color3.fromRGB(236, 240, 244), material = Enum.Material.Metal },
	Wrap = { color = Color3.fromRGB(38, 26, 20), material = Enum.Material.Fabric },
	Pommel = { color = Color3.fromRGB(126, 104, 62), material = Enum.Material.Metal },
	Guard = { color = Color3.fromRGB(126, 104, 62), material = Enum.Material.Metal },
}
SlotBuilder.DetailDefaults = DETAIL_DEFAULTS

function SlotBuilder.ensureDetail(slot)
	local knife = slot and slot:FindFirstChild("Knife")
	local blade = knife and knife:FindFirstChild("Blade")
	local handle = knife and knife:FindFirstChild("Handle")
	if not blade or not handle then
		return
	end
	local hidden = blade.Transparency
	local function detail(name, size, cf, shape)
		if knife:FindFirstChild(name) then
			return
		end
		local d = DETAIL_DEFAULTS[name]
		local part = makePart(name, size, d.color, d.material, knife)
		if shape then
			part.Shape = shape
		end
		part.CFrame = cf
		part.Transparency = hidden
	end
	-- 날 한쪽을 따라 밝은 날선. 칼날(두께 X, 폭 Y, 길이 Z) 위쪽 가장자리에 붙는다.
	detail("Edge", Vector3.new(blade.Size.X + 0.02, 0.07, blade.Size.Z * 0.86), blade.CFrame * CFrame.new(0, blade.Size.Y * 0.5 - 0.03, -blade.Size.Z * 0.04))
	detail("Wrap", Vector3.new(handle.Size.X + 0.03, handle.Size.Y + 0.03, 0.12), handle.CFrame * CFrame.new(0, 0, -0.12))
	detail("Pommel", Vector3.new(0.34, 0.34, 0.34), handle.CFrame * CFrame.new(0, 0, handle.Size.Z * 0.5 + 0.1), Enum.PartType.Ball)
end

--------------------------------------------------
-- 칼 스킨 (Phase 5)
--
-- 꽂히는 칼에 그 사람의 스킨을 입힌다. 서버가 바꾸므로 같은 테이블 모두에게 보인다.
-- 크기는 건드리지 않는다. 슬롯 배치가 크기에서 계산되기 때문이다.
--------------------------------------------------

function SlotBuilder.applyKnifeSkin(slot, skin)
	if not slot or not skin then
		return
	end
	local knife = slot:FindFirstChild("Knife")
	if not knife then
		return
	end

	local blade = knife:FindFirstChild("Blade")
	if blade then
		blade.Color = skin.blade or LAYOUT.BladeColor
		blade.Material = skin.bladeMaterial or Enum.Material.Metal
		blade.Reflectance = skin.glow and 0.2 or 0
	end

	local handle = knife:FindFirstChild("Handle")
	if handle then
		handle.Color = skin.handle or LAYOUT.HandleColor
		handle.Material = skin.handleMaterial or Enum.Material.Wood
	end

	-- 손잡이와 칼날 사이의 코등이. 스킨마다 색이 다르고, 없으면 만들어 둔다.
	local guard = knife:FindFirstChild("Guard")
	if not guard and blade then
		guard = makePart("Guard", Vector3.new(0.42, 0.12, 0.2), skin.guard or LAYOUT.HandleColor, Enum.Material.Metal, knife)
		guard.CFrame = blade.CFrame * CFrame.new(0, 0, 0.92)
		guard.Transparency = blade.Transparency
	elseif guard then
		guard.Color = skin.guard or LAYOUT.HandleColor
	end

	-- Phase 11 장식도 스킨 색을 따른다.
	local edge = knife:FindFirstChild("Edge")
	if edge then
		edge.Color = (skin.blade or LAYOUT.BladeColor):Lerp(Color3.new(1, 1, 1), 0.45)
		edge.Material = skin.bladeMaterial == Enum.Material.Neon and Enum.Material.Neon or Enum.Material.Metal
	end
	local pommel = knife:FindFirstChild("Pommel")
	if pommel then
		pommel.Color = skin.guard or DETAIL_DEFAULTS.Pommel.color
	end
	local wrap = knife:FindFirstChild("Wrap")
	if wrap then
		wrap.Color = (skin.handle or LAYOUT.HandleColor):Lerp(Color3.new(0, 0, 0), 0.45)
	end

	-- Phase 17 : Blender 칼 조각 (가져왔으면). 네모 칼은 그대로 두고 꽂힐 때 숨긴다 (markUsed).
	--   조각은 SkinMesh 모델에 모은다. 크기 · 판정 · 슬롯 자리는 네모 칼 그대로라 게임 규칙은 바뀌지 않는다.
	local oldMesh = knife:FindFirstChild("SkinMesh")
	if oldMesh then
		oldMesh:Destroy()
	end
	knife:SetAttribute("MeshFrame", nil)
	knife:SetAttribute("MotionFrame", nil)
	knife:SetAttribute("MeshScale", nil)
	if blade and MeshKit.hasKnife(skin) then
		local knifeBase = blade.CFrame * CFrame.new(0, 0, -0.2)
		-- 칼끝(메시의 +Y)이 통 안쪽(-Z)을, 날 폭(메시의 X)이 슬롯의 Y 를 향한다
		local frame = knifeBase * CFrame.new(0, 0, SLOT_GUARD_Z) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
		local holder = Instance.new("Model")
		holder.Name = "SkinMesh"
		holder.Parent = knife
		local made = MeshKit.knife(skin, holder, frame, SLOT_KNIFE_SCALE)
		if made and #made > 0 then
			for _, piece in ipairs(made) do
				piece:SetAttribute("SkinColor", piece.Color)
				piece:SetAttribute("SkinMaterial", piece.Material.Name)
				piece.Transparency = blade.Transparency
			end
			knife:SetAttribute("MeshFrame", frame)
			-- 날은 통 속에 들어가 있으니 용은 손잡이 쪽(바깥)을 감고 돈다
			knife:SetAttribute("MotionFrame", frame * CFrame.Angles(math.pi, 0, 0))
			knife:SetAttribute("MeshScale", SLOT_KNIFE_SCALE)
		else
			holder:Destroy()
		end
	end

	-- 빛나는 스킨은 슬롯 주변도 살짝 물들인다.
	-- ★ 빛은 칼날(Blade) 안에 붙는다. Phase 9 까지는 칼 모델에서 찾아서 한 번도 찾지 못했고,
	--   빛나는 칼을 꽂을 때마다 새 빛이 쌓였으며 칼을 숨긴 뒤에도 빛이 남았다.
	local light = blade and blade:FindFirstChildOfClass("PointLight")
	if skin.glow and skin.glow > 0 then
		if not light and blade then
			light = Instance.new("PointLight")
			light.Parent = blade
		end
		if light then
			light.Color = skin.trail or skin.blade
			light.Brightness = 2 * skin.glow
			light.Range = 7
			light.Shadows = false
		end
	elseif light then
		light:Destroy()
	end
end

--------------------------------------------------
-- 슬롯 조회 / 정리
--------------------------------------------------

function SlotBuilder.getSlots(folder)
	local slots = {}
	if not folder then
		return slots
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute(SLOT_ATTR.SlotIndex) ~= nil then
			table.insert(slots, child)
		end
	end

	table.sort(slots, function(a, b)
		return (a:GetAttribute(SLOT_ATTR.SlotIndex) or 0) < (b:GetAttribute(SLOT_ATTR.SlotIndex) or 0)
	end)

	return slots
end

local function ensurePrompt(slot)
	local prompt = slot:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SlotPrompt"
		prompt.Parent = slot
	end

	local settings = GameConfig.SlotPrompt
	prompt.ActionText = settings.ActionText
	prompt.ObjectText = "" -- 부제목 없음
	prompt.HoldDuration = settings.HoldDuration
	prompt.MaxActivationDistance = settings.MaxActivationDistance
	prompt.RequiresLineOfSight = settings.RequiresLineOfSight
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Enabled = false -- 게임이 시작되면 GameTable 이 켠다

	return prompt
end

-- 칼을 숨기고 슬롯을 빈 상태로 되돌린다.
function SlotBuilder.resetSlot(slot)
	slot:SetAttribute(SLOT_ATTR.Used, false)
	slot:SetAttribute(SLOT_ATTR.UsedByUserId, 0)
	slot.Color = LAYOUT.MarkerColor
	slot.Material = Enum.Material.SmoothPlastic

	local knife = slot:FindFirstChild("Knife")
	if not knife then
		return
	end

	-- Phase 17 : Blender 칼 조각은 지운다 (다음에 꽂는 사람의 스킨으로 다시 만든다)
	local mesh = knife:FindFirstChild("SkinMesh")
	if mesh then
		mesh:Destroy()
	end
	knife:SetAttribute("MeshFrame", nil)
	knife:SetAttribute("MotionFrame", nil)
	knife:SetAttribute("MeshScale", nil)

	-- 숨긴 칼의 빛도 끈다. (보이지 않는 칼이 통 둘레를 비추지 않게)
	for _, light in ipairs(knife:GetDescendants()) do
		if light:IsA("PointLight") then
			light:Destroy()
		end
	end

	for _, part in ipairs(knife:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
			local default = DETAIL_DEFAULTS[part.Name]
			if part.Name == "Blade" then
				part.Color = LAYOUT.BladeColor
				part.Material = Enum.Material.Metal
			elseif default then
				part.Color = default.color
				part.Material = default.material
			else
				part.Color = LAYOUT.HandleColor
				part.Material = Enum.Material.Wood
			end
		end
	end
end

-- 누군가 이 자리를 골랐다. 칼을 드러내고, 위험한 자리였으면 붉게 물들인다.
function SlotBuilder.markUsed(slot, player, isDanger)
	slot:SetAttribute(SLOT_ATTR.Used, true)
	slot:SetAttribute(SLOT_ATTR.UsedByUserId, player and player.UserId or 0)

	local knife = slot:FindFirstChild("Knife")
	if not knife then
		return
	end

	-- Phase 17 : Blender 칼이 있으면 그것을 보이고 네모 칼은 숨긴다. 위험한 자리면 Blender 칼을 붉게 물들인다.
	local mesh = knife:FindFirstChild("SkinMesh")
	local meshed = mesh ~= nil and #mesh:GetChildren() > 0
	for _, part in ipairs(knife:GetChildren()) do
		if part:IsA("BasePart") then
			part.Transparency = meshed and 1 or 0
			if isDanger then
				part.Color = LAYOUT.DangerColor
				part.Material = Enum.Material.Neon
			end
		end
	end
	if meshed then
		for _, piece in ipairs(mesh:GetChildren()) do
			if piece:IsA("BasePart") then
				piece.Transparency = 0
				if isDanger then
					piece.Color = LAYOUT.DangerColor
					piece.Material = Enum.Material.Neon
				end
			end
		end
	end

	if isDanger then
		slot.Color = LAYOUT.DangerColor
		slot.Material = Enum.Material.Neon
	end
end

--------------------------------------------------
-- 모델에 슬롯 갖추기
--------------------------------------------------

-- 이미 알맞은 개수가 있으면 그대로 쓰고, 아니면 새로 만든다.
function SlotBuilder.ensure(model, count)
	local folder = model:FindFirstChild(LAYOUT.FolderName)
	local existing = folder and SlotBuilder.getSlots(folder) or {}

	if folder and #existing == count then
		for _, slot in ipairs(existing) do
			CollectionService:AddTag(slot, GameConfig.Tags.Slot)
			ensurePrompt(slot)
			SlotBuilder.ensureDetail(slot)
			SlotBuilder.resetSlot(slot)
		end
		return existing
	end

	local body = findBarrelBody(model)
	if not body then
		warn(("[CursedBarrel] '%s' 에서 통 파트를 찾지 못해 칼 슬롯을 만들 수 없습니다."):format(model:GetFullName()))
		return {}
	end

	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = LAYOUT.FolderName
	folder.Parent = model

	local radius, height = measureBarrel(body)
	local spots = SlotBuilder.layout(count, body.Position, radius, height)

	local slots = {}
	for _, spot in ipairs(spots) do
		local slot = buildSlot(folder, spot)
		slot:SetAttribute(SLOT_ATTR.SlotIndex, spot.index)
		slot:SetAttribute(SLOT_ATTR.Used, false)
		slot:SetAttribute(SLOT_ATTR.UsedByUserId, 0)
		CollectionService:AddTag(slot, GameConfig.Tags.Slot)
		ensurePrompt(slot)
		table.insert(slots, slot)
	end

	GameConfig.log(("%s 칼 슬롯 %d개 생성"):format(model.Name, #slots))

	return slots
end

return SlotBuilder
