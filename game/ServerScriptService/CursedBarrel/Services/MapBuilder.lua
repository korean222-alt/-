--[[
	MapBuilder  (Phase 6)
	항구를 꾸민다. 커다란 해적선 한 척, 작은 배 두 척, 등대, 부둣가 짐과 등불.

	왜 파일에 직접 만들지 않고 서버가 세우나?
	  배 한 척이 파트 300개가 넘는다. .rbxl 에 그대로 넣으면 파일이 커지고,
	  나중에 "돛을 조금 키우자" 같은 수정을 Studio 에서 손으로 해야 한다.
	  여기서 숫자로 만들어 두면 GameConfig.Map 한 곳만 고치면 배가 다시 지어진다.

	성능 (Phase 6 점검표)
	  · 장식은 전부 CanCollide / CanTouch / CanQuery 를 끈다. 물리와 레이캐스트가 건드리지 않는다.
	  · 그림자도 끈다. 모바일에서 그림자 캐스터 수가 프레임을 가장 많이 먹는다.
	  · 파티클은 등불 몇 개에만 붙인다.
	  · 전부 하나의 Folder 아래 두어, 필요하면 통째로 껐다 켤 수 있다.

	기존 로비는 건드리지 않는다. 전부 Lobby > Harbor 폴더 안에 새로 세운다.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local MAP = GameConfig.Map
local SHIP = MAP.Ship
local SEA = MAP.Sea

local MapBuilder = {}
MapBuilder._started = false

--------------------------------------------------
-- 작은 도구
--------------------------------------------------

local function part(parent, name, size, cframe, color, material)
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Size = size
	instance.CFrame = cframe
	instance.Color = color
	instance.Material = material or Enum.Material.SmoothPlastic
	Utility.makeDecor(instance)
	CollectionService:AddTag(instance, GameConfig.Tags.Decor)
	instance.Parent = parent
	return instance
end

-- 원통은 길이가 X 축이다. 세로로 세우려면 Z 로 90도 돌린다.
local function cylinder(parent, name, diameter, length, cframe, color, material)
	local instance = part(parent, name, Vector3.new(length, diameter, diameter), cframe, color, material)
	instance.Shape = Enum.PartType.Cylinder
	return instance
end

local function upright(cframe)
	return cframe * CFrame.Angles(0, 0, math.rad(90))
end

local function wedge(parent, name, size, cframe, color, material)
	local instance = Instance.new("WedgePart")
	instance.Name = name
	instance.Size = size
	instance.CFrame = cframe
	instance.Color = color
	instance.Material = material or Enum.Material.Wood
	Utility.makeDecor(instance)
	CollectionService:AddTag(instance, GameConfig.Tags.Decor)
	instance.Parent = parent
	return instance
end

local function lantern(parent, cframe, color, brightness)
	local post = cylinder(parent, "LanternPost", 0.24, 1.2, upright(cframe * CFrame.new(0, 0.6, 0)), Color3.fromRGB(46, 36, 28), Enum.Material.Metal)
	local glass = part(parent, "LanternGlass", Vector3.new(0.7, 0.9, 0.7), cframe, color or Color3.fromRGB(255, 196, 120), Enum.Material.Neon)
	glass.Transparency = 0.25

	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 196, 120)
	light.Brightness = brightness or 1.6
	light.Range = 18
	light.Shadows = false
	light.Parent = glass

	return glass, post
end

-- 두 점을 잇는 원통. 원통의 긴 축은 X 이므로, lookAt 으로 맞춘 뒤 Y 로 90도 돌리면
-- 긴 축이 정확히 두 점을 잇는 방향을 향한다. 각도를 손으로 쌓다 보면 반드시 어긋난다.
local function strut(parent, name, fromPosition, toPosition, diameter, color, material)
	local delta = toPosition - fromPosition
	local length = delta.Magnitude
	if length < 0.2 then
		return nil
	end
	local middle = fromPosition + delta * 0.5
	local cframe = CFrame.lookAt(middle, toPosition) * CFrame.Angles(0, math.rad(90), 0)
	return cylinder(parent, name, diameter, length, cframe, color, material)
end

local function rope(parent, fromPosition, toPosition, thickness, color)
	return strut(parent, "Rope", fromPosition, toPosition, thickness or 0.16, color or SHIP.Rope, Enum.Material.Fabric)
end

--------------------------------------------------
-- 바다
--------------------------------------------------

function MapBuilder:_buildSea(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Sea"
	folder.Parent = parent

	-- 깊이감을 주려고 세 겹으로 깐다. 아래로 갈수록 어둡고 투명도가 낮다.
	local layers = {
		{ offset = 0.0, color = SEA.Color, transparency = 0.25, size = SEA.Size },
		{ offset = -1.4, color = SEA.Color:Lerp(Color3.new(0, 0, 0), 0.35), transparency = 0.1, size = SEA.Size * 1.1 },
		{ offset = -4.0, color = SEA.Color:Lerp(Color3.new(0, 0, 0), 0.6), transparency = 0, size = SEA.Size * 1.2 },
	}
	for index, layer in ipairs(layers) do
		local water = part(folder, "Water" .. index,
			Vector3.new(layer.size, 0.6, layer.size),
			CFrame.new(0, SEA.Level + layer.offset, 0),
			layer.color, Enum.Material.Glass)
		water.Transparency = layer.transparency
		water.Reflectance = index == 1 and 0.35 or 0
	end

	-- 부두에 부딪히는 흰 포말. 부두 테두리를 따라 얇은 네온 띠를 두른다.
	local deck = workspace.Lobby:FindFirstChild("Deck")
	if deck then
		local half = Vector3.new(deck.Size.X * 0.5, 0, deck.Size.Z * 0.5)
		local edges = {
			{ Vector3.new(0, 0, half.Z + 1.5), Vector3.new(deck.Size.X + 6, 0.3, 3) },
			{ Vector3.new(0, 0, -half.Z - 1.5), Vector3.new(deck.Size.X + 6, 0.3, 3) },
			{ Vector3.new(half.X + 1.5, 0, 0), Vector3.new(3, 0.3, deck.Size.Z + 6) },
			{ Vector3.new(-half.X - 1.5, 0, 0), Vector3.new(3, 0.3, deck.Size.Z + 6) },
		}
		for _, edge in ipairs(edges) do
			local foam = part(folder, "Foam", edge[2],
				CFrame.new(deck.Position + edge[1] + Vector3.new(0, SEA.Level - deck.Position.Y + 0.4, 0)),
				Color3.fromRGB(226, 240, 246), Enum.Material.Neon)
			foam.Transparency = 0.55
		end
	end

	return folder
end

--------------------------------------------------
-- 해적선
--
-- 선체는 "길이 방향으로 자른 단면"을 여러 장 늘어놓아 만든다.
-- 뱃머리와 고물로 갈수록 폭이 좁아지게 해서 배처럼 보이게 한다.
--------------------------------------------------

-- t : 0(고물) ~ 1(뱃머리). 가운데가 가장 넓다.
local function hullProfile(t)
	local centered = (t - 0.48) * 2
	local width = 1 - 0.78 * (centered * centered)
	-- 뱃머리는 더 뾰족하게, 고물은 조금 뭉툭하게
	if t > 0.8 then
		width *= 1 - (t - 0.8) * 3.2
	end
	return math.max(0.12, width)
end

function MapBuilder:_buildHull(parent, base, scale)
	local length = SHIP.Length * scale
	local beam = SHIP.Beam * scale
	local height = SHIP.HullHeight * scale
	local slabs = 22

	for index = 1, slabs do
		local t = (index - 0.5) / slabs
		local width = beam * hullProfile(t)
		local z = (t - 0.5) * length
		local sink = (1 - hullProfile(t)) * height * 0.22 -- 끝으로 갈수록 살짝 들린다

		part(parent, "HullSlab",
			Vector3.new(width, height, length / slabs + 0.1),
			base * CFrame.new(0, sink * 0.5, z),
			index % 2 == 0 and SHIP.Hull or SHIP.HullDark,
			Enum.Material.Wood)
	end

	-- 흘수선 띠 (물에 닿는 높이에 두르는 색선)
	for index = 1, slabs do
		local t = (index - 0.5) / slabs
		local width = beam * hullProfile(t) + 0.2
		local z = (t - 0.5) * length
		part(parent, "Waterline",
			Vector3.new(width, 0.9 * scale, length / slabs + 0.1),
			base * CFrame.new(0, -height * 0.32, z),
			SHIP.Trim, Enum.Material.Wood)
	end

	-- 뱃머리 쐐기
	wedge(parent, "Prow",
		Vector3.new(beam * 0.22, height * 0.9, length * 0.14),
		base * CFrame.new(0, 0, length * 0.55) * CFrame.Angles(0, math.rad(180), 0),
		SHIP.HullDark, Enum.Material.Wood)

	-- 용골
	part(parent, "Keel",
		Vector3.new(beam * 0.12, height * 0.3, length * 0.94),
		base * CFrame.new(0, -height * 0.52, 0),
		SHIP.HullDark, Enum.Material.Wood)
end

function MapBuilder:_buildDeck(parent, base, scale)
	local length = SHIP.Length * scale
	local beam = SHIP.Beam * scale
	local deckY = SHIP.DeckHeight * scale
	local slabs = 22

	-- 갑판 널빤지
	for index = 1, slabs do
		local t = (index - 0.5) / slabs
		local width = beam * hullProfile(t) - 0.6
		if width > 1 then
			local z = (t - 0.5) * length
			part(parent, "Plank",
				Vector3.new(width, 0.4, length / slabs + 0.05),
				base * CFrame.new(0, deckY, z),
				index % 2 == 0 and Color3.fromRGB(122, 88, 56) or Color3.fromRGB(104, 74, 46),
				Enum.Material.WoodPlanks)
		end
	end

	-- 뱃전(난간 벽). 갑판 양옆을 따라 세운다.
	for index = 1, slabs do
		local t = (index - 0.5) / slabs
		local width = beam * hullProfile(t)
		if width > 2 then
			local z = (t - 0.5) * length
			for _, side in ipairs({ -1, 1 }) do
				part(parent, "Bulwark",
					Vector3.new(0.5, 2.6 * scale, length / slabs + 0.05),
					base * CFrame.new(side * (width * 0.5 - 0.25), deckY + 1.4 * scale, z),
					SHIP.Hull, Enum.Material.Wood)
			end
		end
	end

	-- 고물 선루 (선장실). 창 세 개가 달린 상자.
	local sternZ = -length * 0.38
	local sternWidth = beam * hullProfile(0.12)
	part(parent, "SternCastle",
		Vector3.new(sternWidth * 0.92, 5.4 * scale, length * 0.16),
		base * CFrame.new(0, deckY + 3.4 * scale, sternZ),
		SHIP.Hull, Enum.Material.Wood)
	part(parent, "SternRail",
		Vector3.new(sternWidth * 0.96, 0.5, length * 0.17),
		base * CFrame.new(0, deckY + 6.2 * scale, sternZ),
		SHIP.Trim, Enum.Material.Wood)

	for offset = -1, 1 do
		local window = part(parent, "SternWindow",
			Vector3.new(1.8 * scale, 2 * scale, 0.3),
			base * CFrame.new(offset * 3 * scale, deckY + 3.6 * scale, sternZ - length * 0.081),
			Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
		window.Transparency = 0.2
	end

	-- 뱃머리 선수루
	part(parent, "Forecastle",
		Vector3.new(beam * hullProfile(0.86) * 0.9, 3.2 * scale, length * 0.1),
		base * CFrame.new(0, deckY + 2.2 * scale, length * 0.4),
		SHIP.Hull, Enum.Material.Wood)

	-- 키(조타륜)
	local wheelBase = base * CFrame.new(0, deckY + 6.6 * scale, sternZ + length * 0.07)
	cylinder(parent, "WheelHub", 0.7 * scale, 0.4, wheelBase * CFrame.Angles(0, math.rad(90), 0), SHIP.Trim, Enum.Material.Metal)
	for spoke = 1, 8 do
		local angle = spoke / 8 * math.pi * 2
		cylinder(parent, "WheelSpoke", 0.22 * scale, 2.6 * scale,
			wheelBase * CFrame.Angles(0, math.rad(90), angle),
			Color3.fromRGB(128, 92, 56), Enum.Material.Wood)
	end

	-- 승강구
	part(parent, "Hatch",
		Vector3.new(3.4 * scale, 0.5, 3.4 * scale),
		base * CFrame.new(0, deckY + 0.3, length * 0.08),
		Color3.fromRGB(58, 40, 26), Enum.Material.Wood)
end

function MapBuilder:_buildMasts(parent, base, scale)
	local length = SHIP.Length * scale
	local deckY = SHIP.DeckHeight * scale
	local count = math.max(1, SHIP.Masts)

	for index = 1, count do
		-- 가운데 돛대가 가장 높다.
		local t = index / (count + 1)
		local z = (t - 0.5) * length * 0.86
		local tall = (index == math.ceil(count / 2)) and 1.25 or 1
		local mastHeight = 34 * scale * tall
		local mastTop = deckY + mastHeight

		cylinder(parent, "Mast", 1.5 * scale, mastHeight,
			upright(base * CFrame.new(0, deckY + mastHeight * 0.5, z)),
			Color3.fromRGB(96, 66, 40), Enum.Material.Wood)

		-- 활대와 돛 두 장
		for level = 1, 2 do
			local y = deckY + mastHeight * (level == 1 and 0.42 or 0.72)
			local spread = (level == 1 and 22 or 16) * scale * tall
			cylinder(parent, "Yard", 0.8 * scale, spread,
				base * CFrame.new(0, y, z),
				Color3.fromRGB(86, 60, 36), Enum.Material.Wood)

			local sail = part(parent, "Sail",
				Vector3.new(spread * 0.94, (level == 1 and 11 or 8) * scale * tall, 0.3),
				base * CFrame.new(0, y - (level == 1 and 5.6 or 4.2) * scale * tall, z + 0.5),
				SHIP.Sail, Enum.Material.Fabric)
			sail.Transparency = 0.02

			-- 돛에 새긴 해골 문장 (가운데 돛대의 아래 돛에만)
			if index == math.ceil(count / 2) and level == 1 then
				local crest = part(parent, "SailCrest",
					Vector3.new(spread * 0.3, spread * 0.3, 0.1),
					base * CFrame.new(0, y - 5.6 * scale * tall, z + 0.72),
					Color3.fromRGB(34, 28, 24), Enum.Material.SmoothPlastic)
				crest.Transparency = 0.15
			end

			-- 활대 끝에서 갑판으로 내려오는 밧줄
			for _, side in ipairs({ -1, 1 }) do
				local top = (base * CFrame.new(side * spread * 0.5, y, z)).Position
				local bottom = (base * CFrame.new(side * 7 * scale, deckY + 1, z + side * 4 * scale)).Position
				rope(parent, top, bottom, 0.14 * scale)
			end
		end

		-- 가운데 돛대에는 망루와 깃발
		if index == math.ceil(count / 2) then
			local nestY = deckY + mastHeight * 0.86
			cylinder(parent, "CrowsNestFloor", 4.4 * scale, 0.4,
				upright(base * CFrame.new(0, nestY, z)),
				Color3.fromRGB(86, 60, 36), Enum.Material.Wood)
			for ring = 1, 8 do
				local angle = ring / 8 * math.pi * 2
				cylinder(parent, "CrowsNestPost", 0.26 * scale, 1.8 * scale,
					upright(base * CFrame.new(math.sin(angle) * 2 * scale, nestY + 0.9 * scale, z + math.cos(angle) * 2 * scale)),
					Color3.fromRGB(86, 60, 36), Enum.Material.Wood)
			end

			local flag = part(parent, "Flag",
				Vector3.new(6 * scale, 3.4 * scale, 0.18),
				base * CFrame.new(3 * scale, mastTop - 2 * scale, z),
				Color3.fromRGB(28, 24, 26), Enum.Material.Fabric)
			flag.Transparency = 0.05
			part(parent, "FlagMark",
				Vector3.new(1.6 * scale, 1.6 * scale, 0.1),
				base * CFrame.new(3 * scale, mastTop - 2 * scale, z + 0.14),
				Color3.fromRGB(238, 232, 214), Enum.Material.SmoothPlastic)
		end

		-- 돛대에서 뱃머리·고물로 이어지는 버팀 밧줄
		local topPosition = (base * CFrame.new(0, mastTop - 1, z)).Position
		rope(parent, topPosition, (base * CFrame.new(0, deckY + 2, length * 0.52)).Position, 0.18 * scale)
		rope(parent, topPosition, (base * CFrame.new(0, deckY + 6, -length * 0.46)).Position, 0.18 * scale)
	end
end

function MapBuilder:_buildShipDetails(parent, base, scale)
	local length = SHIP.Length * scale
	local beam = SHIP.Beam * scale
	local deckY = SHIP.DeckHeight * scale

	-- 뱃머리 사장(비스듬히 튀어나온 기둥)과 선수상
	strut(parent, "Bowsprit",
		(base * CFrame.new(0, deckY + 1.8 * scale, length * 0.44)).Position,
		(base * CFrame.new(0, deckY + 6 * scale, length * 0.76)).Position,
		1.1 * scale, Color3.fromRGB(96, 66, 40), Enum.Material.Wood)
	part(parent, "Figurehead",
		Vector3.new(1.6 * scale, 2.4 * scale, 3 * scale),
		base * CFrame.new(0, deckY + 1.2 * scale, length * 0.52),
		SHIP.Trim, Enum.Material.Marble)

	-- 대포. 양옆 포문에서 포신이 튀어나온다.
	for index = -2, 2 do
		if index ~= 0 then
			local z = index * length * 0.12
			local width = beam * hullProfile(0.5 + index * 0.12)
			for _, side in ipairs({ -1, 1 }) do
				local portCFrame = base * CFrame.new(side * width * 0.5, deckY - 2.2 * scale, z)
				local port = part(parent, "GunPort",
					Vector3.new(0.4, 1.8 * scale, 1.8 * scale),
					portCFrame,
					Color3.fromRGB(28, 22, 18), Enum.Material.Wood)
				port.Transparency = 0.05
				-- 원통의 긴 축은 이미 X(뱃전 바깥쪽)다. 더 돌리면 포신이 엉뚱한 곳을 본다.
				cylinder(parent, "Cannon", 0.9 * scale, 3 * scale,
					portCFrame * CFrame.new(side * 1.2 * scale, 0, 0),
					Color3.fromRGB(42, 42, 48), Enum.Material.Metal)
			end
		end
	end

	-- 닻
	local anchorBase = base * CFrame.new(beam * 0.34, deckY - 1, length * 0.36)
	cylinder(parent, "AnchorShank", 0.6 * scale, 4.4 * scale, upright(anchorBase), Color3.fromRGB(52, 52, 58), Enum.Material.Metal)
	cylinder(parent, "AnchorStock", 0.5 * scale, 3.4 * scale, anchorBase * CFrame.new(0, 1.6 * scale, 0), Color3.fromRGB(52, 52, 58), Enum.Material.Metal)
	rope(parent, (anchorBase * CFrame.new(0, 2.4 * scale, 0)).Position, (base * CFrame.new(beam * 0.3, deckY + 2, length * 0.44)).Position, 0.24 * scale)

	-- 갑판 위 짐과 등불
	local cargo = {
		{ CFrame.new(-5, 0, 6), Vector3.new(3, 3, 3) },
		{ CFrame.new(-5, 3, 6), Vector3.new(2.4, 2.4, 2.4) },
		{ CFrame.new(5.5, 0, -4), Vector3.new(3.2, 3.2, 3.2) },
		{ CFrame.new(-6, 0, -12), Vector3.new(2.6, 2.6, 2.6) },
	}
	for _, entry in ipairs(cargo) do
		local offset = entry[1]
		local size = entry[2] * scale
		part(parent, "Crate", size,
			base * CFrame.new(offset.X * scale, deckY + size.Y * 0.5 + 0.2, offset.Z * scale) * CFrame.Angles(0, math.rad(math.random(-25, 25)), 0),
			Color3.fromRGB(122, 88, 52), Enum.Material.WoodPlanks)
	end

	for _, offset in ipairs({ Vector3.new(0, 0, -length * 0.44), Vector3.new(4 * scale, 0, length * 0.3), Vector3.new(-4 * scale, 0, length * 0.3) }) do
		lantern(parent, base * CFrame.new(offset.X, deckY + 3.4 * scale, offset.Z), Color3.fromRGB(255, 190, 110), 2.2)
	end

	-- 그물
	for _, side in ipairs({ -1, 1 }) do
		for step = 0, 5 do
			local top = (base * CFrame.new(side * beam * 0.34, deckY + 12 * scale, -length * 0.1)).Position
			local bottom = (base * CFrame.new(side * beam * 0.46, deckY + 1, -length * 0.26 + step * 2.6 * scale)).Position
			rope(parent, top, bottom, 0.1 * scale)
		end
	end
end

function MapBuilder:_buildShip(parent, name, base, scale)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	self:_buildHull(model, base, scale)
	self:_buildDeck(model, base, scale)
	self:_buildMasts(model, base, scale)
	self:_buildShipDetails(model, base, scale)

	return model
end

-- 작은 어선. 큰 배와 같은 규칙으로 만들되 돛대 하나에 돛 한 장.
function MapBuilder:_buildSkiff(parent, name, base, scale)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local length = 22 * scale
	local beam = 7 * scale
	local height = 4.4 * scale

	for index = 1, 10 do
		local t = (index - 0.5) / 10
		local width = beam * hullProfile(t)
		part(model, "HullSlab",
			Vector3.new(width, height, length / 10 + 0.05),
			base * CFrame.new(0, 0, (t - 0.5) * length),
			index % 2 == 0 and SHIP.Hull or SHIP.HullDark,
			Enum.Material.Wood)
	end

	cylinder(model, "Mast", 0.7 * scale, 14 * scale,
		upright(base * CFrame.new(0, height * 0.5 + 7 * scale, 0)),
		Color3.fromRGB(96, 66, 40), Enum.Material.Wood)
	part(model, "Sail",
		Vector3.new(7 * scale, 8 * scale, 0.25),
		base * CFrame.new(0, height * 0.5 + 7 * scale, 0.4),
		SHIP.Sail, Enum.Material.Fabric)
	lantern(model, base * CFrame.new(0, height * 0.6, -length * 0.4), Color3.fromRGB(255, 190, 110), 1.2)

	return model
end

--------------------------------------------------
-- 부둣가
--------------------------------------------------

function MapBuilder:_buildDocks(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Docks"
	folder.Parent = parent

	local deck = workspace.Lobby:FindFirstChild("Deck")
	local top = deck and (deck.Position.Y + deck.Size.Y * 0.5) or 1
	local random = Random.new(20260922)

	-- 짐 상자 무더기. 통로(x 가 -10~10)와 테이블 주변은 피한다.
	local function safeSpot()
		for _ = 1, 30 do
			local x = random:NextNumber(-118, 118)
			local z = random:NextNumber(-115, 110)
			if math.abs(x) > 14 and math.abs(z + 35) > 16 and math.abs(z - 20) > 16
				and math.abs(z - 72) > 14 and math.abs(z + 95) > 20 and math.abs(z - 100) > 16 then
				return Vector3.new(x, top, z)
			end
		end
		return nil
	end

	for _ = 1, MAP.Props.Crates do
		local spot = safeSpot()
		if spot then
			local size = random:NextNumber(2.2, 3.6)
			local stack = random:NextInteger(1, 3)
			for level = 1, stack do
				local levelSize = size * (1 - (level - 1) * 0.16)
				part(folder, "Crate",
					Vector3.new(levelSize, levelSize, levelSize),
					CFrame.new(spot + Vector3.new(0, size * (level - 0.5), 0))
						* CFrame.Angles(0, math.rad(random:NextNumber(0, 360)), 0),
					Color3.fromRGB(random:NextInteger(104, 134), random:NextInteger(74, 96), random:NextInteger(44, 60)),
					Enum.Material.WoodPlanks)
			end
		end
	end

	for _ = 1, MAP.Props.Barrels do
		local spot = safeSpot()
		if spot then
			local diameter = random:NextNumber(2.2, 3.1)
			local height = diameter * 1.25
			cylinder(folder, "DockBarrel", diameter, height,
				upright(CFrame.new(spot + Vector3.new(0, height * 0.5, 0))),
				Color3.fromRGB(116, 76, 44), Enum.Material.Wood)
			cylinder(folder, "DockBarrelHoop", diameter + 0.14, 0.24,
				upright(CFrame.new(spot + Vector3.new(0, height * 0.28, 0))),
				Color3.fromRGB(58, 48, 42), Enum.Material.Metal)
			cylinder(folder, "DockBarrelHoop", diameter + 0.14, 0.24,
				upright(CFrame.new(spot + Vector3.new(0, height * 0.75, 0))),
				Color3.fromRGB(58, 48, 42), Enum.Material.Metal)
		end
	end

	-- 통로를 따라 매달린 등불. 밤에도 길이 보인다.
	for index = -6, 6 do
		local z = index * 16
		for _, side in ipairs({ -1, 1 }) do
			local base = CFrame.new(side * 9, top + 7.4, z)
			lantern(folder, base, Color3.fromRGB(255, 186, 96), 2)
			rope(folder, base.Position + Vector3.new(0, 1.2, 0), base.Position + Vector3.new(0, 3.4, 0), 0.1)
		end
	end

	-- 밧줄 더미
	for _ = 1, MAP.Props.Ropes do
		local spot = safeSpot()
		if spot then
			-- 바닥에 납작하게 깔린 밧줄 더미. 지름이 크고 두께가 얇아야 한다.
			for ring = 1, 3 do
				cylinder(folder, "RopeCoil", 3.4 - ring * 0.7, 0.3,
					upright(CFrame.new(spot + Vector3.new(0, 0.18 * ring, 0))),
					SHIP.Rope, Enum.Material.Fabric)
			end
		end
	end

	-- 갈매기. 난간과 상자 위에 앉아 있다. (움직이지 않아서 비용이 없다)
	for index = 1, MAP.Props.Gulls do
		local x = random:NextNumber(-110, 110)
		local z = random:NextNumber(-110, 108)
		local y = top + random:NextNumber(6, 16)
		local body = part(folder, "Gull", Vector3.new(0.5, 0.45, 1.1),
			CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(random:NextNumber(0, 360)), 0),
			Color3.fromRGB(240, 240, 236), Enum.Material.SmoothPlastic)
		part(folder, "GullWing", Vector3.new(1.6, 0.14, 0.5), body.CFrame * CFrame.new(0, 0.1, 0),
			Color3.fromRGB(216, 216, 212), Enum.Material.SmoothPlastic)
		part(folder, "GullBeak", Vector3.new(0.14, 0.14, 0.34), body.CFrame * CFrame.new(0, 0.02, 0.6),
			Color3.fromRGB(246, 176, 72), Enum.Material.SmoothPlastic)
		if index % 3 == 0 then
			body.CFrame = body.CFrame * CFrame.Angles(math.rad(-8), 0, 0)
		end
	end

	return folder
end

-- 배로 건너가는 건널판. 배가 정말 정박해 있는 것처럼 보이게 한다.
function MapBuilder:_buildGangway(parent, fromPosition, toPosition)
	local folder = Instance.new("Folder")
	folder.Name = "Gangway"
	folder.Parent = parent

	local delta = toPosition - fromPosition
	local length = delta.Magnitude
	local middle = fromPosition + delta * 0.5
	local plank = part(folder, "Gangplank",
		Vector3.new(5, 0.5, length),
		CFrame.lookAt(middle, toPosition),
		Color3.fromRGB(122, 88, 52), Enum.Material.WoodPlanks)

	for _, side in ipairs({ -1, 1 }) do
		rope(folder,
			(plank.CFrame * CFrame.new(side * 2.4, 2.6, -length * 0.45)).Position,
			(plank.CFrame * CFrame.new(side * 2.4, 2.6, length * 0.45)).Position,
			0.14)
	end

	return folder
end

function MapBuilder:_buildLighthouse(parent, position)
	local folder = Instance.new("Folder")
	folder.Name = "Lighthouse"
	folder.Parent = parent

	-- 바위섬
	for index = 1, 4 do
		local size = 26 - index * 4
		part(folder, "Rock",
			Vector3.new(size, 6, size),
			CFrame.new(position + Vector3.new(0, index * 2.4 - 4, 0)) * CFrame.Angles(0, math.rad(index * 23), 0),
			Color3.fromRGB(64, 64, 68), Enum.Material.Rock)
	end

	-- 탑. 위로 갈수록 좁아지는 띠 무늬.
	local baseY = position.Y + 6
	for index = 1, 9 do
		local diameter = 12 - index * 0.8
		cylinder(folder, "Tower", diameter, 4,
			upright(CFrame.new(position.X, baseY + index * 4, position.Z)),
			index % 2 == 0 and Color3.fromRGB(226, 226, 220) or Color3.fromRGB(196, 72, 60),
			Enum.Material.Concrete)
	end

	local lampY = baseY + 40
	local lamp = part(folder, "Lamp", Vector3.new(6, 5, 6),
		CFrame.new(position.X, lampY, position.Z),
		Color3.fromRGB(255, 226, 150), Enum.Material.Neon)
	lamp.Transparency = 0.12

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 226, 150)
	light.Brightness = 6
	light.Range = 70
	light.Shadows = false
	light.Parent = lamp

	cylinder(folder, "LampRoof", 8, 2, upright(CFrame.new(position.X, lampY + 3.4, position.Z)),
		Color3.fromRGB(58, 52, 48), Enum.Material.Metal)

	return folder
end

--------------------------------------------------
-- 시작
--------------------------------------------------

function MapBuilder:Start()
	if self._started or not MAP.Enabled then
		return
	end
	self._started = true

	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		warn("[CursedBarrel] Lobby 폴더가 없어 항구를 꾸미지 못했습니다.")
		return
	end

	local previous = lobby:FindFirstChild("Harbor")
	if previous then
		previous:Destroy()
	end

	local harbor = Instance.new("Folder")
	harbor.Name = "Harbor"
	harbor.Parent = lobby

	local ok, err = pcall(function()
		self:_buildSea(harbor)

		-- 큰 해적선은 부두 오른쪽에 뱃머리를 입구 쪽으로 대고 정박해 있다.
		local flagship = CFrame.new(162, 3, 6) * CFrame.Angles(0, math.rad(SHIP.Facing), 0)
		self:_buildShip(harbor, "Flagship", flagship, 1)
		self:_buildGangway(harbor, Vector3.new(124, 1.2, 6), Vector3.new(150, 10.5, 6))

		-- 반대쪽에는 작은 배 두 척
		self:_buildSkiff(harbor, "Skiff_A", CFrame.new(-152, 0, -34) * CFrame.Angles(0, math.rad(24), 0), 1)
		self:_buildSkiff(harbor, "Skiff_B", CFrame.new(-168, 0, 40) * CFrame.Angles(0, math.rad(-38), 0), 1.2)

		-- 멀리 등대
		self:_buildLighthouse(harbor, Vector3.new(-240, SEA.Level, -190))

		self:_buildDocks(harbor)
	end)

	if not ok then
		warn("[CursedBarrel] 항구를 세우는 중 오류: " .. tostring(err))
	end

	local count = 0
	for _, descendant in ipairs(harbor:GetDescendants()) do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	GameConfig.log(("MapBuilder 시작 완료 · 장식 파트 %d개"):format(count))
end

return MapBuilder
