--[[
	LobbyBuilder  (Phase 5 · Phase 6 · Phase 7)
	로비 간판 방향을 바로잡고, 쓰이지 않는 구조물을 걷어내고, 스킨 전시장을 세운다.

	Phase 6 에서 바뀐 것
	  · 구역 간판에서 설명 줄을 걷어냈다.
	    "칼 스킨" 밑에 붙어 있던 "내가 꽂는 칼은 모두에게 보인다" 같은 줄이
	    통 스킨 · 해적 스킨 간판에도 똑같이 있었는데, 바로 밑에 이름표가 줄줄이 서 있어서
	    읽을 이유가 없는 글자였다. 이제 간판에는 구역 이름만 남는다.
	  · 전시장 전체 안내판도 없앴다. 가까이 가면 프롬프트가 알아서 뜬다.
	  · 미리보기에 스킨 이펙트가 붙는다. (SkinFX)

	Phase 7 에서 바뀐 것
	  · 이름표에 희귀도와 가격이 뜬다.
	  · 프롬프트가 "가지고 있으면 장착, 없으면 구매"로 바뀐다. 판단은 서버가 한다.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))
local SkinFX = require(Shared:WaitForChild("SkinFX"))
local DrumStyle = require(Shared:WaitForChild("DrumStyle"))
local KnifeModel = require(Shared:WaitForChild("KnifeModel"))
local BarrelStyle = require(Shared:WaitForChild("BarrelStyle"))
local MeshKit = require(Shared:WaitForChild("MeshKit")) -- Phase 15 : Blender 통 · 드럼 메시
local ShipLayout = require(Shared:WaitForChild("ShipLayout")) -- Phase 16 : 좋아요 보상 받침대 자리
local PirateModel = require(Shared:WaitForChild("PirateModel")) -- Phase 17 : Blender 해적 전시

local ProfileService = require(script.Parent.ProfileService)
local ShopService = require(script.Parent.ShopService)

local SHOWCASE = GameConfig.Showcase
local SKINS = GameConfig.Skins

local PREVIEW_TAG = GameConfig.Tags.SkinPreview
local PEDESTAL_TAG = GameConfig.Tags.SkinPedestal

local LobbyBuilder = {}
LobbyBuilder._started = false

--------------------------------------------------
-- 작은 도구
--------------------------------------------------

local function makePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	Utility.makeDecor(part)
	part.Parent = parent
	return part
end

local function makeCylinder(parent, name, diameter, length, cframe, color, material)
	-- 원통 파트는 길이가 X, 지름이 Y/Z 다. 세워 두려면 Z 축으로 90도 돌린다.
	local part = makePart(parent, name, Vector3.new(length, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- 간판 하나. 언제나 보는 사람 쪽(+Z)을 향한다.
local function makeSign(parent, name, cframe, size, lines, color, textSize)
	local board = makePart(parent, name, size, cframe, Color3.fromRGB(22, 18, 15), Enum.Material.Wood)
	board.CanQuery = true

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Back -- +Z. 로비 안쪽에서 읽는다.
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color or Color3.fromRGB(240, 202, 104)
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = lines
	label.Parent = gui

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize or 90
	constraint.Parent = label

	return board
end

--------------------------------------------------
-- 1) 간판 방향 바로잡기
--------------------------------------------------

-- 얇은 축의 두 면 중, 로비 안쪽을 향하는 면을 고른다.
local function bestFace(part, focus)
	local size = part.Size
	local toward = focus - part.Position
	if toward.Magnitude < 0.01 then
		return nil
	end
	toward = toward.Unit

	local candidates
	if size.Z <= size.X and size.Z <= size.Y then
		candidates = {
			{ Enum.NormalId.Front, part.CFrame.LookVector },
			{ Enum.NormalId.Back, -part.CFrame.LookVector },
		}
	elseif size.X <= size.Y then
		candidates = {
			{ Enum.NormalId.Right, part.CFrame.RightVector },
			{ Enum.NormalId.Left, -part.CFrame.RightVector },
		}
	else
		candidates = {
			{ Enum.NormalId.Top, part.CFrame.UpVector },
			{ Enum.NormalId.Bottom, -part.CFrame.UpVector },
		}
	end

	local bestId, bestDot = nil, -math.huge
	for _, entry in ipairs(candidates) do
		local dot = entry[2]:Dot(toward)
		if dot > bestDot then
			bestId, bestDot = entry[1], dot
		end
	end
	return bestId
end

function LobbyBuilder:_fixSigns()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return 0
	end

	local spawnPart = lobby:FindFirstChild("LobbySpawn")
	local focus = spawnPart and (spawnPart.Position + Vector3.new(0, 6, 0)) or SHOWCASE.LobbyFocus
	local fixed = 0

	for _, gui in ipairs(lobby:GetDescendants()) do
		if gui:IsA("SurfaceGui") then
			local part = gui.Adornee or gui.Parent
			if part and part:IsA("BasePart") then
				local face = bestFace(part, focus)
				if face and gui.Face ~= face then
					gui.Face = face
					fixed += 1
				end
			end
		end
	end

	GameConfig.log(("간판 %d개의 방향을 바로잡음"):format(fixed))
	return fixed
end

--------------------------------------------------
-- 2) 쓰이지 않는 구조물 걷어내기
--------------------------------------------------

function LobbyBuilder:_removeUnused()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end

	local names = {}
	for _, name in ipairs(SHOWCASE.RemoveNames) do
		names[name] = true
	end

	local removed = 0
	for _, child in ipairs(lobby:GetChildren()) do
		if names[child.Name] then
			child:Destroy()
			removed += 1
		end
	end

	GameConfig.log(("쓰이지 않는 구조물 %d개 제거"):format(removed))
end

--------------------------------------------------
-- 3) 스킨 미리보기
--------------------------------------------------

local function finishPreview(model, spinCenter)
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new(spinCenter)
	return model
end

local function previewGhost(skin, parent, base)
	-- Phase 17 : Blender 해적이 있으면 게임에서 튀어나오는 해적과 똑같은 모델을 세운다
	if MeshKit.has("Pirate") then
		local ok, rig = pcall(PirateModel.new, skin, nil)
		if ok and rig and rig.model then
			local model = rig.model
			model.Name = "Preview"
			-- Phase 17.1 : 전시대 해적이 너무 환하다 → 몸에서 나오는 빛을 줄인다
			if rig.light then
				rig.light.Brightness = 0.7
				rig.light.Range = 8
			end
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					Utility.makeDecor(part)
				end
			end
			model.Parent = parent
			-- 기준점은 가슴 가운데. 안개 꼬리 끝(-3.4)이 받침대 바로 위에 오게 세운다
			model:PivotTo(base * CFrame.new(0, 3.5, 0))
			return finishPreview(model, model:GetPivot().Position)
		end
	end
	local template = ReplicatedStorage.CursedBarrel:FindFirstChild("Visuals")
	template = template and template:FindFirstChild("GhostCaptain")
	if not template then
		return nil
	end

	local model = template:Clone()
	model.Name = "Preview"

	local byName = {
		Coat = skin.coat, CollarL = skin.coat, CollarR = skin.coat, Arm = skin.coat,
		SpectralHead = skin.skin, GhostHand = skin.skin, MistTail = skin.skin, Cuff = skin.skin,
		HatBrim = skin.hat, HatCrown = skin.hat,
		HatBand = skin.accent, Buckle = skin.accent, Belt = skin.hat, EyePatch = skin.hat,
		Eye = skin.accent, Grin = skin.accent,
	}

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local color = byName[part.Name]
			if color then
				part.Color = color
			end
			Utility.makeDecor(part)
		end
	end

	model.Parent = parent
	model.PrimaryPart = nil
	local _, size = model:GetBoundingBox()
	model:PivotTo(base * CFrame.new(0, size.Y * 0.5 + 0.1, 0))
	return finishPreview(model, base.Position + Vector3.new(0, size.Y * 0.5 + 0.1, 0))
end

local function previewBarrel(skin, parent, base)
	local model = Instance.new("Model")
	model.Name = "Preview"
	model.Parent = parent

	local pivot = base * CFrame.new(0, 1.8, 0)
	local body = makeCylinder(model, "Body", 3, 3.4, pivot, skin.body, skin.bodyMaterial)
	body.Reflectance = skin.reflectance or 0
	-- Phase 15 : Blender 통 · 드럼이 있으면 몸통 · 테는 메시가 그린다
	local meshed = MeshKit.barrel(skin, model, body.CFrame, body.Size.X, body.Size.Y, "BodyMesh")
	if meshed then
		body.Transparency = 1
	end

	if not skin.drum and not meshed then
		makeCylinder(model, "HoopLower", 3.18, 0.3, pivot * CFrame.new(0, -1.1, 0), skin.hoop, skin.hoopMaterial)
		makeCylinder(model, "HoopUpper", 3.18, 0.3, pivot * CFrame.new(0, 1.1, 0), skin.hoop, skin.hoopMaterial)
	end
	makeCylinder(model, "Lid", 2.9, 0.22, pivot * CFrame.new(0, 1.76, 0), skin.lid, skin.hoopMaterial).Reflectance = skin.reflectance or 0

	if meshed then
		DrumStyle.build(model, body.CFrame, 3.4, 3, skin, "Drum", 1.87, true)
	elseif skin.drum then
		-- Phase 13 : 철제 드럼 (굴림 테 · 주름 · 마개)
		DrumStyle.build(model, body.CFrame, 3.4, 3, skin, "Drum", 1.87)
	elseif BarrelStyle.isWooden(skin) then
		-- Phase 14 : 판자 결 · 양 끝 얇은 쇠테
		BarrelStyle.decorate(model, body.CFrame, 3.4, 3, skin)
	elseif skin.ribbed then
		for _, offset in ipairs({ -0.5, 0.1, 0.7 }) do
			makeCylinder(model, "Rib", 3.1, 0.14, pivot * CFrame.new(0, offset, 0), skin.hoop, skin.hoopMaterial)
		end
	end

	local glow = makeCylinder(model, "Glow", 2.7, 0.1, pivot * CFrame.new(0, 1.66, 0), skin.glow, skin.glowMaterial or Enum.Material.Neon)
	glow.Transparency = 0.25

	local light = Instance.new("PointLight")
	light.Color = skin.glow
	light.Brightness = 1.4
	light.Range = 10
	light.Shadows = false
	light.Parent = glow

	return finishPreview(model, pivot.Position)
end

local function previewKnife(skin, parent, base)
	-- 전시용이라 실제 칼보다 크게 만든다. 게임 안의 칼 크기는 건드리지 않는다.
	-- Phase 14 : 상점 3D 미리보기와 같은 KnifeModel (끝이 뾰족한 날 · 홈 · 코등이 구슬 · 감은 손잡이)
	local pivot = base * CFrame.new(0, 3.2, 0)
	local pose = pivot * CFrame.Angles(math.rad(-22), 0, math.rad(12)) * CFrame.new(0, -0.9, 0)
	local model = KnifeModel.build(skin, parent, pose, 1.05)
	model.Name = "Preview"
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			Utility.makeDecor(piece)
		end
	end
	return finishPreview(model, pivot.Position)
end

local PREVIEW_BUILDERS = {
	Ghost = previewGhost,
	Barrel = previewBarrel,
	Knife = previewKnife,
}

--------------------------------------------------
-- 4) 전시장 세우기
--------------------------------------------------

local function priceText(skin)
	local rarity = GameConfig.rarityOf(skin)
	local price = tonumber(skin.price) or 0
	if skin.vip then
		return ("%s  ·  %s  ·  VIP 패스 전용"):format(skin.name, rarity.label)
	end
	if skin.pack then
		return ("%s  ·  %s  ·  스타터 팩 전용"):format(skin.name, rarity.label)
	end
	if skin.reward == "like" then
		return ("%s  ·  %s  ·  🎟 코드 love"):format(skin.name, rarity.label)
	end
	if skin.robux then
		return ("%s  ·  %s  ·  R$ %d"):format(skin.name, rarity.label, skin.robux)
	end
	if price <= 0 then
		return ("%s  ·  %s  ·  기본 지급"):format(skin.name, rarity.label)
	end
	return ("%s  ·  %s  ·  %s 코인"):format(skin.name, rarity.label, Utility.comma(price))
end

function LobbyBuilder:_buildShowcase()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end

	local old = lobby:FindFirstChild("ShopDisplay")
	if old then
		old:Destroy()
	end
	local previous = lobby:FindFirstChild("SkinShowcase")
	if previous then
		previous:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "SkinShowcase"
	root.Parent = lobby

	self._pedestals = {}

	for _, zone in ipairs(SHOWCASE.Zones) do
		local list = SKINS[zone.kind]
		if list and #list > 0 then
			local builder = PREVIEW_BUILDERS[zone.kind]
			local count = #list
			local columns=math.min(SHOWCASE.Columns or 5,count)
            local span = (columns - 1) * SHOWCASE.Spacing
			local startX = zone.x - span * 0.5

			local folder = Instance.new("Folder")
			folder.Name = zone.kind .. "Zone"
			folder.Parent = root

			-- ★ 구역 간판에는 이름만. 설명 줄은 넣지 않는다.
			makeSign(folder, "ZoneSign",
				CFrame.new(zone.x, 12, SHOWCASE.SignZ),
				Vector3.new(span + 4, 5.2, 0.4),
				zone.title,
				zone.color, 150)

			-- 바닥 띠. 구역이 어디서 어디까지인지 한눈에 보이게.
			local stripe = makePart(folder, "Stripe",
				Vector3.new(span + 7, 0.2, 15),
				CFrame.new(zone.x, 0.6, SHOWCASE.Z),
				zone.color, Enum.Material.Neon)
			stripe.Transparency = 0.82

			for index, skin in ipairs(list) do
				local x = startX + ((index - 1)%columns) * SHOWCASE.Spacing
                local z = SHOWCASE.Z + math.floor((index-1)/columns)*(SHOWCASE.RowSpacing or 12)
				local base = CFrame.new(x, 3.35, z) -- 받침대 윗면

				local pedestal = makeCylinder(folder, "Pedestal", 6.4, 2.6,
					CFrame.new(x, 1.8, z), Color3.fromRGB(38, 28, 22), Enum.Material.Slate)
				pedestal.CanCollide = true
				pedestal.CanQuery = true
				CollectionService:AddTag(pedestal, PEDESTAL_TAG)
				pedestal:SetAttribute("SkinKind", zone.kind)
				pedestal:SetAttribute("SkinId", skin.id)
				pedestal:SetAttribute("SkinName", skin.name)
				pedestal:SetAttribute("SkinPrice", tonumber(skin.price) or 0)
				pedestal:SetAttribute("SkinRobux", tonumber(skin.robux) or 0)
				pedestal:SetAttribute("SkinRarity", skin.rarity or "common")

				local rarity = GameConfig.rarityOf(skin)
				makeCylinder(folder, "Rim", 6.7, 0.25,
					CFrame.new(x, 3.2, z), rarity.color, Enum.Material.Neon)

				if builder then
					local preview = builder(skin, folder, base)
					if preview then
						CollectionService:AddTag(preview, PREVIEW_TAG)
						preview:SetAttribute("SkinKind", zone.kind)
						preview:SetAttribute("SkinId", skin.id)
						preview:SetAttribute("SpinSpeed", zone.kind == "Knife" and 34 or 22)
						SkinFX.applyPreview(preview, skin, zone.kind)
					end
				end

				-- 이름표 : 이름 · 등급 · 값. 설명 문장은 넣지 않는다.
				makeSign(folder, "Plate",
					CFrame.new(x, 3.9, z + 3.3),
					Vector3.new(7.6, 1.5, 0.3),
					priceText(skin),
					rarity.color, 38)

				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "Equip"
				-- 가진 스킨이면 장착, 아니면 구매. 글자는 각자 화면에서 ShopController 가 바꿔 준다.
				-- 지나가다 잘못 눌러 비싼 스킨을 사지 않도록 잠깐 누르고 있어야 한다.
				prompt.ActionText = "장착 · 구매"
				prompt.ObjectText = skin.name
				prompt.HoldDuration = 0.6
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.Parent = pedestal

				table.insert(self._pedestals, pedestal)
			end
		end
	end

	GameConfig.log(("스킨 전시장 완성 · 전시대 %d개"):format(#self._pedestals))
end

--------------------------------------------------
-- Phase 16 : 스폰 옆 그룹 가입 보상 받침대 (파란 철제 드럼이 빙글빙글)
--   누르면 각자 화면(RewardController)이 창을 띄우고 Roblox 그룹 가입 창을 연다.
--   주는 것은 RewardService:ClaimLike (서버가 그룹 가입을 직접 확인한다).
--------------------------------------------------

function LobbyBuilder:_buildLikeReward()
	local like = GameConfig.LikeReward
	local spot = ShipLayout.LikeReward
	local lobby = workspace:FindFirstChild("Lobby")
	if not (like and like.Enabled and spot and lobby) then
		return
	end
	local skin = GameConfig.findSkin(like.Kind, like.Skin)
	if not skin or skin.id ~= like.Skin then
		return
	end
	local old = lobby:FindFirstChild("LikeReward")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "LikeReward"
	folder.Parent = lobby

	-- Phase 17 : 계단을 내려오자마자 오른쪽 앞 (주 갑판). 계단 폭(x ±6) 밖이라 지나는 길을 막지 않는다
	local deck = spot.y or (ShipLayout.HallOfFame and ShipLayout.HallOfFame.Base) or 5.5
	local x, z = spot.x, spot.z
	local blue = Color3.fromRGB(60, 150, 255)
	local pedestal = makeCylinder(folder, "Pedestal", 5.6, 2.2, CFrame.new(x, deck + 1.1, z), Color3.fromRGB(40, 30, 24), Enum.Material.Slate)
	pedestal.CanCollide = true
	pedestal.CanQuery = true
	makeCylinder(folder, "Step", 6.6, 0.4, CFrame.new(x, deck + 0.2, z), Color3.fromRGB(88, 56, 32), Enum.Material.Wood)
	makeCylinder(folder, "Rim", 5.9, 0.25, CFrame.new(x, deck + 2.15, z), blue, Enum.Material.Neon)
	local base = CFrame.new(x, deck + 2.45, z)
	local preview = previewBarrel(skin, folder, base)
	if preview then
		CollectionService:AddTag(preview, PREVIEW_TAG)
		preview:SetAttribute("SkinKind", like.Kind)
		preview:SetAttribute("SkinId", skin.id)
		preview:SetAttribute("SpinSpeed", 30)
		SkinFX.applyPreview(preview, skin, like.Kind)
	end

	-- 멀리서도 보이는 머리 위 글자 (항상 보는 사람 쪽)
	local sign = Instance.new("BillboardGui")
	sign.Name = "LikeSign"
	sign.Size = UDim2.fromScale(10, 4.2)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 7.6, 0)
	sign.MaxDistance = 110
	sign.LightInfluence = 0
	sign.Parent = pedestal
	local function line(text, y, h, color)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, h)
		label.Position = UDim2.fromScale(0, y)
		label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.Parent = sign
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(16, 22, 40)
		stroke.Parent = label
		return label
	end
	-- Phase 22 : 그룹 대신 출시 기념 코드로 준다 (🎟 코드에 love)
	line("🎁 출시 기념 선물!", 0, 0.4, Color3.fromRGB(255, 255, 255))
	line("🎟 코드에 love 를 입력하세요", 0.4, 0.34, Color3.fromRGB(255, 226, 120))
	line("파란 철제 드럼 무료!", 0.76, 0.24, Color3.fromRGB(120, 200, 255))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LikeReward"
	prompt.ActionText = "받기"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = pedestal
	CollectionService:AddTag(prompt, GameConfig.Tags.LikeReward)
end

--------------------------------------------------
-- 5) 장착 / 구매 처리
--
-- 가진 스킨이면 장착, 아니면 구매를 시도한다. 판단은 전부 서버가 한다.
--------------------------------------------------

function LobbyBuilder:_bindEquip()
	for _, pedestal in ipairs(self._pedestals or {}) do
		local prompt = pedestal:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				local kind = pedestal:GetAttribute("SkinKind")
				local id = pedestal:GetAttribute("SkinId")
				if not kind or not id then
					return
				end

				if ProfileService:Owns(player, kind, id) then
					local ok, message = ShopService:Equip(player, kind, id)
					ShopService:Sync(player, message, ok)
					return
				end

				local ok, message = ShopService:Buy(player, kind, id)
				if ok then
					-- 사면 바로 장착까지 해 준다. 두 번 누르게 하지 않는다.
					local okEquip, equipMessage = ShopService:Equip(player, kind, id)
					ShopService:Sync(player, okEquip and equipMessage or message, true)
				else
					ShopService:Sync(player, message, false)
				end
			end)
		end
	end
end

--------------------------------------------------

function LobbyBuilder:Start()
	if self._started then
		return
	end
	self._started = true

	self:_fixSigns()
	self:_removeUnused()
	self:_buildShowcase()
	self:_bindEquip()
	self:_buildLikeReward()

	GameConfig.log("LobbyBuilder 시작 완료")
end

return LobbyBuilder
