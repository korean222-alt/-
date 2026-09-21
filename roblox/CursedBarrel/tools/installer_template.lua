-- 저주받은 통 · Phase 2 업데이트 설치
-- Play/Run을 멈춘 Studio 편집 모드의 Command Bar에 전체 내용을 한 번 붙여넣으세요.
-- 외부 다운로드, HTTP 허용, LoadStringEnabled, 플러그인이 필요하지 않습니다.
-- 같은 이름의 스크립트만 교체하고 기존 항목은 ServerStorage에 백업합니다.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "[CursedBarrel] Play/Run을 먼저 멈추고 Command Bar에서 실행하세요.")

--------------------------------------------------
-- 설치 옵션
--------------------------------------------------
local APPLY_LIGHTING = true -- 로비를 밝은 조명으로 바꾼다 (게임 시작 시 어두워지는 연출은 클라이언트가 담당)
local REBUILD_MAP = true -- 로비 맵 + 테이블 6개를 새로 만든다. false 면 스크립트만 갱신한다.
local REPLACE_SPAWN = true -- 기존 SpawnLocation 을 백업하고 로비 스폰을 사용한다
local LOBBY_ORIGIN = Vector3.new(0, 1, 0) -- 로비 바닥 윗면의 높이/위치

-- 한 게임방에 놓을 테이블 목록. 줄을 더하거나 지우면 그대로 반영된다.
local TABLE_LAYOUT = {
	{ name = "Table_A", tableType = "Standard4", seatCount = 4, offset = Vector3.new(-44, 0, -20) },
	{ name = "Table_B", tableType = "Standard4", seatCount = 4, offset = Vector3.new(0, 0, -20) },
	{ name = "Table_C", tableType = "Standard4", seatCount = 4, offset = Vector3.new(44, 0, -20) },
	{ name = "Table_D", tableType = "Standard4", seatCount = 4, offset = Vector3.new(-44, 0, 18) },
	{ name = "Table_E", tableType = "Duo2", seatCount = 2, offset = Vector3.new(0, 0, 18) },
	{ name = "Table_F", tableType = "Duo2", seatCount = 2, offset = Vector3.new(44, 0, 18) },
}

local SOURCES = {}
--@@SOURCES@@

--------------------------------------------------
-- 공용 파츠 도구
--------------------------------------------------
local PALETTE = {
	DarkWood = Color3.fromRGB(52, 34, 23),
	Wood = Color3.fromRGB(94, 62, 40),
	LightWood = Color3.fromRGB(131, 92, 58),
	Gold = Color3.fromRGB(198, 154, 74),
	Iron = Color3.fromRGB(70, 72, 77),
	Cursed = Color3.fromRGB(72, 132, 122),
	Floor = Color3.fromRGB(176, 146, 108),
	FloorTrim = Color3.fromRGB(129, 102, 72),
	Wall = Color3.fromRGB(214, 208, 196),
	WallTrim = Color3.fromRGB(198, 154, 74),
	Stone = Color3.fromRGB(188, 184, 176),
	SignBack = Color3.fromRGB(46, 33, 25),
	Cream = Color3.fromRGB(245, 238, 224),
}

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Wood
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local parent = props.Parent
	props.Parent = nil
	for key, value in pairs(props) do
		part[key] = value
	end
	if parent then
		part.Parent = parent
	end
	return part
end

-- 세로로 세운 원기둥. Cylinder 는 X축이 길이 방향이라 Z로 90도 눕힌다.
local function newCylinder(props, diameter, height, position)
	local part = newPart(props)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- 파츠 앞면(Front = -Z)에 글자를 붙인다. lookAt 으로 방향을 잡으면 글자가 정면을 본다.
local function addSign(part, guiName, text, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Name = guiName
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0 -- 게임 중 조명이 어두워져도 글씨는 읽힌다
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = textColor or PALETTE.Cream
	label.Text = text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.Name = "Padding"
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = label

	return gui
end

--------------------------------------------------
-- 테이블 한 개 만들기
--------------------------------------------------
local function buildTable(parent, options)
	local CollectionService = game:GetService("CollectionService")

	local tableName = options.name
	local tableType = options.tableType or "Standard4"
	local seatCount = options.seatCount or 4
	local origin = options.origin

	local isSmall = seatCount <= 2
	local TABLE_TOP_RADIUS = isSmall and 3.6 or 4.6
	local TABLE_TOP_HEIGHT = 3.2
	local SEAT_RADIUS = isSmall and 5.6 or 6.6
	local SEAT_HEIGHT = 2.0

	local tableModel = Instance.new("Model")
	tableModel.Name = tableName
	tableModel.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	newCylinder({ Name = "Foot", Color = PALETTE.DarkWood, Parent = tableModel }, 3.4, 0.5, origin + Vector3.new(0, 0.25, 0))
	newCylinder({ Name = "Pillar", Color = PALETTE.Wood, Parent = tableModel }, 1.7, TABLE_TOP_HEIGHT - 0.5, origin + Vector3.new(0, (TABLE_TOP_HEIGHT - 0.5) / 2 + 0.3, 0))
	newCylinder({ Name = "Rim", Color = PALETTE.Gold, Material = Enum.Material.Metal, Parent = tableModel }, TABLE_TOP_RADIUS * 2 + 0.45, 0.3, origin + Vector3.new(0, TABLE_TOP_HEIGHT - 0.28, 0))

	local tableTop = newCylinder({
		Name = "TableTop",
		Color = PALETTE.LightWood,
		Material = Enum.Material.WoodPlanks,
		Parent = tableModel,
	}, TABLE_TOP_RADIUS * 2, 0.55, origin + Vector3.new(0, TABLE_TOP_HEIGHT, 0))

	tableModel.PrimaryPart = tableTop

	-- 저주받은 통 (Phase 3 에서 칼 슬롯이 붙을 자리)
	local barrel = Instance.new("Model")
	local barrelBottom = TABLE_TOP_HEIGHT + 0.28
	local barrelHeight = 4.0

	local barrelBody = newCylinder({
		Name = "Body",
		Color = PALETTE.Wood,
		Material = Enum.Material.WoodPlanks,
		Parent = barrel,
	}, 3.5, barrelHeight, origin + Vector3.new(0, barrelBottom + barrelHeight / 2, 0))

	newCylinder({ Name = "HoopLower", Color = PALETTE.Iron, Material = Enum.Material.Metal, Parent = barrel }, 3.7, 0.35, origin + Vector3.new(0, barrelBottom + 0.9, 0))
	newCylinder({ Name = "HoopUpper", Color = PALETTE.Iron, Material = Enum.Material.Metal, Parent = barrel }, 3.7, 0.35, origin + Vector3.new(0, barrelBottom + barrelHeight - 0.9, 0))
	newCylinder({ Name = "Lid", Color = PALETTE.DarkWood, Parent = barrel }, 3.3, 0.3, origin + Vector3.new(0, barrelBottom + barrelHeight + 0.15, 0))

	local glow = newCylinder({
		Name = "Glow",
		Color = PALETTE.Cursed,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = barrel,
	}, 2.9, 0.12, origin + Vector3.new(0, barrelBottom + barrelHeight + 0.34, 0))

	local glowLight = Instance.new("PointLight")
	glowLight.Color = PALETTE.Cursed
	glowLight.Brightness = 1.4
	glowLight.Range = 10
	glowLight.Parent = glow

	barrel.Name = "Barrel"
	barrel.PrimaryPart = barrelBody
	barrel.Parent = tableModel

	newPart({
		Name = "StatusAnchor",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = tableModel,
		CFrame = CFrame.new(origin + Vector3.new(0, barrelBottom + barrelHeight + 3.2, 0)),
	})

	local seatsFolder = Instance.new("Folder")
	seatsFolder.Name = "Seats"
	seatsFolder.Parent = tableModel

	for index = 1, seatCount do
		local angle = (index - 1) * (math.pi * 2 / seatCount)
		local offset = Vector3.new(math.sin(angle) * SEAT_RADIUS, SEAT_HEIGHT, math.cos(angle) * SEAT_RADIUS)
		local seatPosition = origin + offset

		-- 의자가 테이블 중앙을 바라보게 한다 → 앉은 캐릭터도 중앙을 본다
		local lookTarget = Vector3.new(origin.X, seatPosition.Y, origin.Z)
		local seatCFrame = CFrame.lookAt(seatPosition, lookTarget)

		local chair = Instance.new("Model")
		chair.Name = ("Chair_%02d"):format(index)
		chair.Parent = seatsFolder

		local seat = Instance.new("Seat")
		seat.Name = ("Seat_%02d"):format(index)
		seat.Size = Vector3.new(2.4, 0.5, 2.4)
		seat.Anchored = true
		seat.Color = PALETTE.LightWood
		seat.Material = Enum.Material.Wood
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth
		seat.CFrame = seatCFrame
		seat:SetAttribute("SeatIndex", index)
		seat:SetAttribute("OccupantUserId", 0)
		seat:SetAttribute("TurnOrder", 0)
		CollectionService:AddTag(seat, "CursedBarrel_Seat")
		seat.Parent = chair

		chair.PrimaryPart = seat

		local back = newPart({
			Name = "Back",
			Size = Vector3.new(2.4, 2.4, 0.35),
			Color = PALETTE.Wood,
			Parent = chair,
		})
		back.CFrame = seatCFrame * CFrame.new(0, 1.0, 1.05)

		local crest = newPart({
			Name = "Crest",
			Size = Vector3.new(2.4, 0.25, 0.42),
			Color = PALETTE.Gold,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = chair,
		})
		crest.CFrame = seatCFrame * CFrame.new(0, 2.25, 1.05)

		local legHeight = SEAT_HEIGHT - 0.25
		local legPosition = seatPosition - Vector3.new(0, 0.25 + legHeight / 2, 0)
		newCylinder({ Name = "Leg", Color = PALETTE.DarkWood, Parent = chair }, 0.9, legHeight, legPosition)
		newCylinder({ Name = "LegFoot", Color = PALETTE.DarkWood, Parent = chair }, 2.0, 0.3, Vector3.new(seatPosition.X, origin.Y + 0.15, seatPosition.Z))
	end

	-- 테이블 위 랜턴. 로비에서는 장식이지만 게임이 시작돼 어두워지면 조명 역할을 한다.
	local lanternHeight = 11
	local lanternRope = newPart({
		Name = "LanternRope",
		Size = Vector3.new(0.18, 4, 0.18),
		Color = PALETTE.DarkWood,
		CanCollide = false,
		Parent = tableModel,
	})
	lanternRope.CFrame = CFrame.new(origin + Vector3.new(0, lanternHeight + 2, 0))

	local lantern = newPart({
		Name = "Lantern",
		Size = Vector3.new(1.4, 1.8, 1.4),
		Color = PALETTE.Gold,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = tableModel,
	})
	lantern.CFrame = CFrame.new(origin + Vector3.new(0, lanternHeight, 0))

	local flame = newPart({
		Name = "Flame",
		Size = Vector3.new(0.9, 1.1, 0.9),
		Color = Color3.fromRGB(255, 196, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = tableModel,
	})
	flame.CFrame = lantern.CFrame

	local lanternLight = Instance.new("PointLight")
	lanternLight.Color = Color3.fromRGB(255, 186, 120)
	lanternLight.Brightness = 2.4
	lanternLight.Range = 32
	lanternLight.Shadows = true
	lanternLight.Parent = flame

	tableModel:SetAttribute("TableId", tableName)
	tableModel:SetAttribute("TableType", tableType)
	tableModel:SetAttribute("SeatCount", seatCount)
	tableModel:SetAttribute("SeatedCount", 0)
	tableModel:SetAttribute("MinPlayers", 1)
	tableModel:SetAttribute("State", "Waiting")
	-- Phase 2 Attribute (서버가 부팅하면서 다시 채운다. Explorer 에서 미리 보이게 만들어 둔다)
	tableModel:SetAttribute("CountdownEndsAt", 0)
	tableModel:SetAttribute("CountdownDuration", 5)
	tableModel:SetAttribute("RoundId", 0)
	tableModel:SetAttribute("ParticipantCount", 0)
	tableModel:SetAttribute("TurnCount", 0)
	tableModel:SetAttribute("TurnIndex", 0)
	tableModel:SetAttribute("CurrentTurnUserId", 0)
	tableModel:SetAttribute("CurrentTurnName", "")
	tableModel:SetAttribute("TurnEndsAt", 0)

	tableModel.Parent = parent
	CollectionService:AddTag(tableModel, "CursedBarrel_Table")

	return tableModel
end

--------------------------------------------------
-- 로비 (밝은 전시장 + 게임방)
--------------------------------------------------
local function buildLobby(parent, origin)
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"

	local floor = newPart({
		Name = "Floor",
		Size = Vector3.new(160, 4, 140),
		Color = PALETTE.Floor,
		Material = Enum.Material.WoodPlanks,
		Parent = lobby,
	})
	floor.CFrame = CFrame.new(origin + Vector3.new(0, -2, 0))

	-- 테이블 구역과 전시 구역을 나누는 바닥 띠
	local divider = newPart({
		Name = "FloorStripe",
		Size = Vector3.new(160, 0.1, 3),
		Color = PALETTE.FloorTrim,
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
		Parent = lobby,
	})
	divider.CFrame = CFrame.new(origin + Vector3.new(0, 0.05, -48))

	local function wall(name, size, position)
		local part = newPart({
			Name = name,
			Size = size,
			Color = PALETTE.Wall,
			Material = Enum.Material.Concrete,
			Parent = lobby,
		})
		part.CFrame = CFrame.new(origin + position)
		return part
	end

	local function trim(name, size, position)
		local part = newPart({
			Name = name,
			Size = size,
			Color = PALETTE.WallTrim,
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = lobby,
		})
		part.CFrame = CFrame.new(origin + position)
		return part
	end

	wall("Wall_North", Vector3.new(164, 16, 4), Vector3.new(0, 8, -72))
	wall("Wall_South", Vector3.new(164, 16, 4), Vector3.new(0, 8, 72))
	wall("Wall_West", Vector3.new(4, 16, 148), Vector3.new(-82, 8, 0))
	wall("Wall_East", Vector3.new(4, 16, 148), Vector3.new(82, 8, 0))

	trim("Trim_North", Vector3.new(164, 0.9, 4.4), Vector3.new(0, 16.4, -72))
	trim("Trim_South", Vector3.new(164, 0.9, 4.4), Vector3.new(0, 16.4, 72))
	trim("Trim_West", Vector3.new(4.4, 0.9, 148), Vector3.new(-82, 16.4, 0))
	trim("Trim_East", Vector3.new(4.4, 0.9, 148), Vector3.new(82, 16.4, 0))

	--------------------------------------------------
	-- 스킨/디자인 전시 구역 (Phase 4 에서 상점으로 연결할 자리)
	--------------------------------------------------
	local shop = Instance.new("Folder")
	shop.Name = "ShopDisplay"
	shop.Parent = lobby

	local stage = newPart({
		Name = "Stage",
		Size = Vector3.new(80, 3, 16),
		Color = PALETTE.Stone,
		Material = Enum.Material.Marble,
		Parent = shop,
	})
	stage.CFrame = CFrame.new(origin + Vector3.new(0, 1.5, -60))

	for index = 1, 5 do
		local x = -30 + (index - 1) * 15
		local base = origin + Vector3.new(x, 3, -60)

		newCylinder({ Name = ("Pedestal_%02d"):format(index), Color = PALETTE.Stone, Material = Enum.Material.Marble, Parent = shop }, 6, 2.4, base + Vector3.new(0, 1.2, 0))
		newCylinder({ Name = ("PedestalTop_%02d"):format(index), Color = PALETTE.Gold, Material = Enum.Material.Metal, Parent = shop }, 6.6, 0.4, base + Vector3.new(0, 2.6, 0))

		-- 전시할 의자/스킨 모델을 여기에 올리면 된다. 위치 기준점만 남겨 둔다.
		local anchor = newPart({
			Name = ("DisplayAnchor_%02d"):format(index),
			Size = Vector3.new(1, 1, 1),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = shop,
		})
		anchor.CFrame = CFrame.new(base + Vector3.new(0, 3.3, 0))
	end

	local shopSign = newPart({
		Name = "ShopSign",
		Size = Vector3.new(44, 9, 1),
		Color = PALETTE.SignBack,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = shop,
	})
	shopSign.CFrame = CFrame.lookAt(origin + Vector3.new(0, 12, -69), origin + Vector3.new(0, 12, 0))
	addSign(shopSign, "ShopLabel", "의자 스킨 전시장\n(구매 기능은 준비 중)", PALETTE.Gold)

	--------------------------------------------------
	-- 안내판 + 스폰
	--------------------------------------------------
	local howToPlay = newPart({
		Name = "HowToPlay",
		Size = Vector3.new(26, 10, 1),
		Color = PALETTE.SignBack,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = lobby,
	})
	howToPlay.CFrame = CFrame.lookAt(origin + Vector3.new(-40, 8, 68), origin + Vector3.new(-40, 8, 0))
	addSign(
		howToPlay,
		"Instructions",
		"저주받은 통 · PHASE 2\n의자 가까이에서 E (모바일은 탭)\n5초 뒤 게임이 시작됩니다\n게임이 시작되면 조명이 어두워져요",
		PALETTE.Cream
	)

	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "LobbySpawn"
	spawnPart.Size = Vector3.new(16, 1, 16)
	spawnPart.Anchored = true
	spawnPart.CanCollide = true
	spawnPart.Neutral = true
	spawnPart.AllowTeamChangeOnTouch = false
	spawnPart.Color = PALETTE.Gold
	spawnPart.Material = Enum.Material.Neon
	spawnPart.Transparency = 0.6
	spawnPart.TopSurface = Enum.SurfaceType.Smooth
	spawnPart.BottomSurface = Enum.SurfaceType.Smooth
	spawnPart.CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 52))
	spawnPart.Parent = lobby

	lobby.Parent = parent
	return lobby
end

--------------------------------------------------
-- 라이팅 (로비 = 밝음. 어두워지는 연출은 게임 중에만 클라이언트가 적용한다)
-- 값은 GameConfig.Lighting.Lobby 와 같게 맞춰져 있다.
--------------------------------------------------
local function applyLighting(setLighting, replace)
	local Lighting = game:GetService("Lighting")

	setLighting("Ambient", Color3.fromRGB(122, 120, 116))
	setLighting("OutdoorAmbient", Color3.fromRGB(154, 158, 168))
	setLighting("Brightness", 2.8)
	setLighting("ClockTime", 14.3)
	setLighting("GeographicLatitude", 12)
	setLighting("ExposureCompensation", 0)
	setLighting("EnvironmentDiffuseScale", 0.6)
	setLighting("EnvironmentSpecularScale", 0.5)
	setLighting("GlobalShadows", true)
	setLighting("FogColor", Color3.fromRGB(206, 214, 224))
	setLighting("FogEnd", 100000)

	local function ensure(className, name)
		local instance = Instance.new(className)
		instance.Name = name
		replace(Lighting, name, instance)
		return instance
	end

	local atmosphere = ensure("Atmosphere", "Atmosphere")
	atmosphere.Density = 0.26
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(226, 226, 220)
	atmosphere.Decay = Color3.fromRGB(150, 165, 185)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6

	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.3
	bloom.Size = 22
	bloom.Threshold = 1.3

	local colorCorrection = ensure("ColorCorrectionEffect", "ColorCorrection")
	colorCorrection.Brightness = 0.01
	colorCorrection.Contrast = 0.06
	colorCorrection.Saturation = 0.1
	colorCorrection.TintColor = Color3.fromRGB(255, 252, 246)

	print("[CursedBarrel] 로비 조명(밝음) 설정 완료")
end

--------------------------------------------------
-- 설치
--------------------------------------------------
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerScriptService")
local SP = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local Storage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local Editor = game:GetService("ScriptEditorService")
local History = game:GetService("ChangeHistoryService")

local stage = Instance.new("Folder")
stage.Name = "CursedBarrel_Staging"
stage.Parent = Storage

local created, replacements, lightingBefore = {}, {}, {}
local backup = Instance.new("Folder")
backup.Name = "CursedBarrel_Backup_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. game:GetService("HttpService"):GenerateGUID(false):sub(1, 8)

local function folder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), existing:GetFullName() .. " must be a Folder; nothing at this path was overwritten.")
		return existing
	end
	local result = Instance.new("Folder")
	result.Name = name
	table.insert(created, result)
	result.Parent = parent
	return result
end

local function disableScriptsIn(root, record)
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, item in ipairs(all) do
		if item:IsA("BaseScript") then
			record.enabled[item] = item.Enabled
			item:SetAttribute("CB_BackupWasEnabled", item.Enabled)
			item.Enabled = false
		end
	end
end

local function replace(parent, name, fresh)
	local old = parent:FindFirstChild(name)
	local record = { parent = parent, old = old, fresh = fresh, enabled = {} }
	table.insert(replacements, record)
	if old then
		local slot = Instance.new("Folder")
		slot.Name = ("%02d_%s"):format(#replacements, name)
		slot:SetAttribute("OriginalParent", parent:GetFullName())
		slot.Parent = backup
		disableScriptsIn(old, record)
		old.Parent = slot
	end
	fresh.Name = name
	fresh.Parent = parent
end

-- 교체할 새 항목 없이 기존 항목만 백업으로 옮긴다. (옛 장식/스폰 정리용)
local function stash(instance)
	if not instance or not instance.Parent then
		return
	end
	local record = { parent = instance.Parent, old = instance, fresh = nil, enabled = {} }
	table.insert(replacements, record)
	local slot = Instance.new("Folder")
	slot.Name = ("%02d_%s"):format(#replacements, instance.Name)
	slot:SetAttribute("OriginalParent", instance.Parent:GetFullName())
	slot.Parent = backup
	disableScriptsIn(instance, record)
	instance.Parent = slot
end

local function setLighting(property, value)
	if lightingBefore[property] == nil then
		lightingBefore[property] = Lighting[property]
		backup:SetAttribute("Lighting_" .. property, Lighting[property])
	end
	Lighting[property] = value
end

local function preflightPath(root, path)
	local parent = root
	for _, name in ipairs(path) do
		local found = parent:FindFirstChild(name)
		if not found then return end
		assert(found:IsA("Folder"), found:GetFullName() .. " must be a Folder. Installation stopped.")
		parent = found
	end
end

local ok, err = xpcall(function()
	preflightPath(RS, {"CursedBarrel", "Shared"})
	preflightPath(SS, {"CursedBarrel", "Services"})
	preflightPath(SP, {"Controllers"})
	preflightPath(workspace, {"GameTables"})

	local definitions = {
		{"GameConfig", "ModuleScript"}, {"TableConfig", "ModuleScript"},
		{"Utility", "ModuleScript"}, {"GameTable", "ModuleScript"},
		{"TableService", "ModuleScript"}, {"RoundService", "ModuleScript"},
		{"Main", "Script"},
		{"TableController", "LocalScript"}, {"LightingController", "LocalScript"},
	}

	-- 모든 소스를 먼저 준비하고 확인한 후 실제 경로에 설치합니다.
	local scripts = {}
	for _, definition in ipairs(definitions) do
		local name, className = definition[1], definition[2]
		assert(SOURCES[name], "Missing source: " .. name)
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = stage
		Editor:UpdateSourceAsync(instance, function() return SOURCES[name] end)
		assert(Editor:GetEditorSource(instance) == SOURCES[name], "Source verification failed: " .. name)
		scripts[name] = instance
	end

	-- 테이블과 로비를 미리 만들어 검사한다.
	local builtTables, lobby = {}, nil
	if REBUILD_MAP then
		for _, layout in ipairs(TABLE_LAYOUT) do
			local model = buildTable(stage, {
				name = layout.name,
				tableType = layout.tableType,
				seatCount = layout.seatCount,
				origin = LOBBY_ORIGIN + layout.offset,
			})

			local seatCount = 0
			for _, descendant in ipairs(model.Seats:GetDescendants()) do
				if descendant:IsA("Seat") then
					seatCount += 1
					assert(descendant.Anchored and descendant:GetAttribute("SeatIndex"), "Invalid seat in " .. layout.name)
				end
			end
			assert(seatCount == layout.seatCount, "Seat count mismatch: " .. layout.name)
			assert(model.PrimaryPart and model:FindFirstChild("StatusAnchor"), "Table validation failed: " .. layout.name)

			table.insert(builtTables, model)
		end

		lobby = buildLobby(stage, LOBBY_ORIGIN)
		assert(lobby:FindFirstChild("Floor") and lobby:FindFirstChildWhichIsA("SpawnLocation"), "Lobby validation failed")
	end

	-- 백업은 서버 전용 저장소에 보관됩니다. 기존 소스의 편집 중 버퍼도 저장합니다.
	backup.Parent = Storage

	local shared = folder(folder(RS, "CursedBarrel"), "Shared")
	local serverRoot = folder(SS, "CursedBarrel")
	local services = folder(serverRoot, "Services")
	local controllers = folder(SP, "Controllers")
	local gameTables = folder(workspace, "GameTables")

	local destinations = {
		GameConfig = shared, TableConfig = shared, Utility = shared,
		GameTable = services, TableService = services, RoundService = services,
		Main = serverRoot,
		TableController = controllers, LightingController = controllers,
	}

	for _, definition in ipairs(definitions) do
		local name = definition[1]
		local old = destinations[name]:FindFirstChild(name)
		if old and old:IsA("LuaSourceContainer") then
			local draft = Instance.new("StringValue")
			draft.Name = name .. "_EditorSource"
			draft.Value = Editor:GetEditorSource(old)
			draft:SetAttribute("OriginalPath", old:GetFullName())
			draft.Parent = backup
		end
		replace(destinations[name], name, scripts[name])
	end

	if REBUILD_MAP then
		for _, model in ipairs(builtTables) do
			replace(gameTables, model.Name, model)
		end
		replace(workspace, "Lobby", lobby)

		-- Phase 1 때 놓였던 바닥/안내판은 새 로비와 겹치므로 백업으로 옮긴다.
		stash(workspace:FindFirstChild("TavernFloor"))
		stash(workspace:FindFirstChild("HowToPlay"))

		if REPLACE_SPAWN then
			-- 스폰이 여러 개면 플레이어가 아무 곳에나 나타난다. 로비 스폰만 남긴다.
			for _, descendant in ipairs(workspace:GetDescendants()) do
				-- 목록은 미리 찍어둔 사본이라, 이미 백업으로 옮겨진 것은 건너뛴다.
				if descendant:IsA("SpawnLocation")
					and descendant:IsDescendantOf(workspace)
					and not descendant:IsDescendantOf(lobby)
				then
					stash(descendant)
				end
			end
		end
	end

	if APPLY_LIGHTING then
		applyLighting(setLighting, replace)
	end

	for _, definition in ipairs(definitions) do
		local name = definition[1]
		assert(destinations[name]:FindFirstChild(name) == scripts[name], "Install verification failed: " .. name)
	end

	local CollectionService = game:GetService("CollectionService")
	local taggedCount = 0
	for _, model in ipairs(CollectionService:GetTagged("CursedBarrel_Table")) do
		if model:IsDescendantOf(workspace) then
			taggedCount += 1
		end
	end
	if REBUILD_MAP then
		assert(taggedCount >= #TABLE_LAYOUT, "Missing table tags")
	end

	stage:Destroy()
	pcall(function() History:SetWaypoint("CursedBarrel Phase 2 installed") end)
	pcall(function()
		if REBUILD_MAP then
			game:GetService("Selection"):Set({ gameTables })
		end
	end)

	print(("[CursedBarrel] 설치 완료 · 스크립트 %d개 / 테이블 %d개 / 조명 %s")
		:format(#definitions, REBUILD_MAP and #TABLE_LAYOUT or 0, APPLY_LIGHTING and "밝은 로비" or "변경 없음"))
	print("[CursedBarrel] 점검 1 · 의자 근처 E → 5초 카운트다운 → 게임 시작 (혼자서도 됩니다)")
	print("[CursedBarrel] 점검 2 · 카운트다운 중 점프로 일어나면 즉시 취소, 다시 앉으면 새 카운트다운")
	print("[CursedBarrel] 점검 3 · 게임이 시작되면 다른 빈 의자에는 앉을 수 없고 내 화면만 어두워집니다")
	print("[CursedBarrel] 점검 4 · 테이블마다 따로 진행됩니다 (Table_A ~ Table_F)")
	print("[CursedBarrel] 2명 이상 모여야 시작하게 하려면 Shared/TableConfig 의 MinPlayers 를 2로 바꾸세요.")
	print("[CursedBarrel] 기존 항목 백업: " .. backup:GetFullName())
end, debug.traceback)

if not ok then
	-- 설치 실패 시 새 항목을 제거하고 이동했던 원본과 조명 값을 되돌립니다.
	for index = #replacements, 1, -1 do
		local record = replacements[index]
		pcall(function()
			if record.fresh then
				record.fresh:Destroy()
			end
			if record.old then
				record.old.Parent = record.parent
				for item, enabled in pairs(record.enabled) do
					item.Enabled = enabled
					item:SetAttribute("CB_BackupWasEnabled", nil)
				end
			end
		end)
	end
	for property, value in pairs(lightingBefore) do pcall(function() Lighting[property] = value end) end
	for index = #created, 1, -1 do pcall(function() created[index]:Destroy() end) end
	stage:Destroy()
	-- 복구에 실패한 원본이 있을 가능성에 대비해 백업은 남깁니다.
	if backup.Parent == nil then backup.Parent = Storage end
	error("[CursedBarrel] 설치 실패. 기존 항목 복구를 시도했습니다. 오류: " .. tostring(err), 0)
end
