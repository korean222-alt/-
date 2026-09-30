-- 로비 캠프: 숲속 공터 + 가운데 모닥불 + 북쪽에 원정 수레(방) + 동쪽 부화장 + 서쪽 보급 게시판.
-- 99 Nights 로비처럼 "여기서 모여서 출발한다" 가 한눈에 보이게. 바닥 기준점 = origin.
-- 반환: {Spawn, Pads = {파트}, Signs = {TextLabel}, Incubator = 파트, Shop = 파트, Center = Vector3}
local CollectionService = game:GetService("CollectionService")
local B = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local L = {}
local M = Enum.Material

local function sign(parent, size, at, title, face)
	local board = B.solid(B.block(parent, size, at, "#6b5236", M.WoodPlanks))
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.CanvasSize, gui.LightInfluence = face or Enum.NormalId.Front, Vector2.new(size.X * 60, size.Y * 60), 0.6
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.TextScaled = UDim2.fromScale(1, 1), 1, true
	text.Font, text.Text, text.TextColor3 = Enum.Font.FredokaOne, title, Color3.fromHex("#f2e6cf")
	text.Parent = gui
	return board, text
end

-- 원정 수레: 나무 짐칸 + 바퀴 4개 + 천막 + 등불. at 의 -Z 가 캠프 가운데를 본다
local function wagon(parent, at, index)
	local m = B.model(parent, "Wagon" .. index)
	B.solid(B.block(m, Vector3.new(7, 0.6, 11), at * CFrame.new(0, 2.2, 0), "#6a5442", M.WoodPlanks))
	for _, x in ipairs({-3.4, 3.4}) do
		B.solid(B.block(m, Vector3.new(0.4, 1.6, 11), at * CFrame.new(x, 3.2, 0), "#5a4535", M.WoodPlanks))
		for _, z in ipairs({-3.6, 3.6}) do
			B.cyl(m, 0.5, 3.4, at * CFrame.new(x + (x > 0 and 0.45 or -0.45), 1.7, z), "#4d3d30", M.Wood)
			B.cyl(m, 0.62, 1, at * CFrame.new(x + (x > 0 and 0.5 or -0.5), 1.7, z), "#3a3d42", M.Metal)
		end
	end
	-- 천막 (둥근 지붕을 판 여러 장으로)
	for i = -3, 3 do
		local a = math.rad(i * 22)
		B.block(m, Vector3.new(2.2, 0.2, 9.6), at * CFrame.new(math.sin(a) * 3.6, 4 + math.cos(a) * 3.2, 0.3) * CFrame.Angles(0, 0, -a), "#cfc3a4", M.Fabric)
	end
	for _, z in ipairs({-4.6, 5.2}) do
		B.block(m, Vector3.new(7.4, 0.35, 0.35), at * CFrame.new(0, 7.1, z), "#5a4535", M.Wood)
	end
	-- 끌채 (앞으로 뻗은 막대)
	B.block(m, Vector3.new(0.35, 0.35, 5), at * CFrame.new(-1, 2, -7.6) * CFrame.Angles(math.rad(-8), 0, 0), "#5a4535", M.Wood)
	B.block(m, Vector3.new(0.35, 0.35, 5), at * CFrame.new(1, 2, -7.6) * CFrame.Angles(math.rad(-8), 0, 0), "#5a4535", M.Wood)
	-- 짐: 상자 · 통 · 자루
	Props.crate(m, at * CFrame.new(-1.6, 2.5, 3), 1.8)
	Props.barrel(m, at * CFrame.new(1.6, 2.5, 3.2))
	B.ellipsoid(m, Vector3.new(1.8, 1.4, 1.4), at * CFrame.new(1.4, 3.2, 0.4), "#b8a47c", M.Fabric)
	Props.lantern(m, at * CFrame.new(3.8, 6.2, -5))
	-- 표지판: 방 번호 + 인원 (서버가 글자를 바꾼다)
	local post = B.solid(B.block(m, Vector3.new(0.4, 5.4, 0.4), at * CFrame.new(-4.6, 2.7, -6.2), "#5a4535", M.Wood))
	local _, text = sign(m, Vector3.new(5, 2.2, 0.3), post.CFrame * CFrame.new(0, 2, -0.3), "원정 수레 " .. index)
	-- 올라타는 자리: 바닥의 빛나는 원
	local pad = B.cyl(m, 0.12, 13, at * CFrame.new(0, 0.1, -8.5), "#8ff5e8", M.Neon, true, {Transparency = 0.7, CanQuery = true})
	pad.Name = "WagonPad"
	pad:SetAttribute("Room", index)
	return B.decorate(m), pad, text
end

function L.build(parent, origin, config)
	local root = B.model(parent, "Lobby")
	local base = CFrame.new(origin)
	local T = workspace.Terrain
	local R = config.Radius
	-- 땅: 풀밭 원판 + 흙 얼룩 + 수레·부화장으로 가는 흙길
	T:FillCylinder(base * CFrame.new(0, -6, 0), 12, R + 40, M.Grass)
	T:FillCylinder(base * CFrame.new(0, -1.9, 0), 4, 16, M.Ground)
	local rng = Random.new(77)
	for _ = 1, 40 do
		local a, r = rng:NextNumber() * math.pi * 2, rng:NextNumber() * R
		T:FillCylinder(base * CFrame.new(math.cos(a) * r, -2.2, math.sin(a) * r), 4, 3 + rng:NextNumber() * 6, rng:NextNumber() < 0.5 and M.LeafyGrass or M.Ground)
	end
	-- 가장자리: 가문비나무 두 줄 + 보이지 않는 벽
	for row, spec in ipairs({{4, 10}, {16, 13}}) do
		local ring, spacing = spec[1], spec[2]
		local count = math.floor(2 * math.pi * (R + ring) / spacing)
		for i = 1, count do
			local a = i / count * math.pi * 2 + (rng:NextNumber() - 0.5) * 0.05
			local r = R + ring + rng:NextNumber() * 6
			Props.tallPine(root, base * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), rng, 0.9 + rng:NextNumber() * 0.4, row == 1, row > 1)
		end
	end
	local walls = B.model(root, "Boundary")
	local segments = 48
	for i = 1, segments do
		local a = i / segments * math.pi * 2
		local pos = (base * CFrame.new(math.cos(a) * (R + 2), 30, math.sin(a) * (R + 2))).Position
		B.new("Part", walls, {Name = "Wall", Size = Vector3.new(2 * math.pi * (R + 2) / segments + 2, 80, 3),
			CFrame = CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z)), Transparency = 1, CanCollide = true, CastShadow = false})
	end
	-- 가운데 모닥불 + 통나무 의자
	local fire = B.model(root, "Campfire")
	for i = 0, 7 do
		B.solid(B.block(fire, Vector3.new(1.4, 0.9, 1.1), base * CFrame.Angles(0, math.rad(i * 45), 0) * CFrame.new(0, 0.45, -2.2), "#8b8f94", M.Slate))
	end
	for i = 0, 2 do
		B.cyl(fire, 3.2, 0.7, base * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(14)), "#6e4a2c", M.Wood)
	end
	local flame = B.ball(fire, 1.2, base * CFrame.new(0, 1.2, 0), "#ffb347", M.Neon, {Transparency = 0.3})
	local fx = Instance.new("Fire")
	fx.Size, fx.Heat = 6, 11
	fx.Parent = flame
	B.light(flame, "PointLight", {Range = 34, Brightness = 2.2, Color = Color3.fromHex("#ffa860"), Shadows = true})
	CollectionService:AddTag(fire, "NightLight")
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		B.solid(B.cyl(fire, 5, 1.3, base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.65, -7.5) * CFrame.Angles(0, math.rad(90), 0), "#5e4a38", M.Wood))
	end
	-- 스폰 (캠프 남쪽)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size = "LobbySpawn", Vector3.new(8, 1, 8)
	spawn.CFrame = base * CFrame.new(0, 0.5, 26)
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Transparency, spawn.CanCollide = true, true, 0, 1, false
	spawn.Parent = root
	-- 원정 수레 (북쪽 반원)
	local pads, signs = {}, {}
	local angles = {-66, -22, 22, 66}
	for i = 1, config.Wagons do
		local a = math.rad(angles[i] or (i * 30))
		local pos = (base * CFrame.new(math.sin(a) * 48, 0, -math.cos(a) * 48)).Position
		local _, pad, text = wagon(root, CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z)), i)
		pads[i], signs[i] = pad, text
		T:FillCylinder(CFrame.new((pos + origin) / 2 + Vector3.new(0, -2, 0)), 4, 5, M.Ground)
	end
	-- 부화장 (동쪽): 기둥 네 개 위 지붕 + 짚 둥지 + 따뜻한 등불 + 알 두 개
	local hut = B.model(root, "Incubator")
	local hat = CFrame.lookAt((base * CFrame.new(40, 0, 6)).Position, origin)
	for _, x in ipairs({-5, 5}) do
		for _, z in ipairs({-4, 4}) do
			B.solid(B.block(hut, Vector3.new(0.7, 7, 0.7), hat * CFrame.new(x, 3.5, z), "#5a4535", M.Wood))
		end
	end
	B.spike(hut, 12, 10, 3, hat * CFrame.new(0, 7, 0) * CFrame.Angles(0, math.rad(90), 0), "#7a6a4a", M.Fabric)
	local nest = B.ellipsoid(hut, Vector3.new(7, 1.6, 5), hat * CFrame.new(0, 0.7, 0), "#b8a060", M.Grass)
	B.solid(nest)
	local eggColors = {{"#e8dcc0", "#a8916a"}, {"#bfe8ff", "#7a5cff"}}
	for i, col in ipairs(eggColors) do
		local egg = B.ellipsoid(hut, Vector3.new(1.5, 2, 1.5), hat * CFrame.new(i == 1 and -1.5 or 1.5, 2.2, 0), col[1], M.SmoothPlastic)
		B.ellipsoid(hut, Vector3.new(0.5, 0.35, 0.2), egg.CFrame * CFrame.new(0.3, 0.35, -0.65), col[2], M.SmoothPlastic)
		B.ellipsoid(hut, Vector3.new(0.35, 0.3, 0.2), egg.CFrame * CFrame.new(-0.35, -0.2, -0.66), col[2], M.SmoothPlastic)
	end
	local lamp = B.ball(hut, 0.8, hat * CFrame.new(0, 6, 0), "#ffd27a", M.Neon)
	B.light(lamp, "PointLight", {Range = 18, Brightness = 1.6, Color = Color3.fromHex("#ffcf8a"), Shadows = false})
	CollectionService:AddTag(hut, "NightLight")
	local incubator = B.hitbox(hut, Vector3.new(8, 4, 6), hat * CFrame.new(0, 2, 0), false)
	incubator.Name = "부화장"
	sign(hut, Vector3.new(6, 1.6, 0.3), hat * CFrame.new(0, 5.6, -4.3), "🥚 부화장")
	-- 보급 게시판 (서쪽)
	local shop = B.model(root, "ShopBoard")
	local sat = CFrame.lookAt((base * CFrame.new(-40, 0, 6)).Position, origin)
	for _, x in ipairs({-3, 3}) do
		B.solid(B.block(shop, Vector3.new(0.6, 6, 0.6), sat * CFrame.new(x, 3, 0), "#5a4535", M.Wood))
	end
	local board = sign(shop, Vector3.new(7, 3.4, 0.4), sat * CFrame.new(0, 4, 0), "🪙 보급 상점\n펫 도감")
	board.Name = "보급 상점"
	Props.crate(shop, sat * CFrame.new(-4.5, 0, 1.5), 2.2)
	Props.barrel(shop, sat * CFrame.new(4.5, 0, 1.2))
	-- 환영 표지 (스폰 앞)
	sign(root, Vector3.new(10, 2.4, 0.4), base * CFrame.new(0, 5, 36) * CFrame.Angles(0, math.pi, 0), "WILDHOLD 캠프")
	B.solid(B.block(root, Vector3.new(0.5, 5, 0.5), base * CFrame.new(-4.6, 2.5, 36), "#5a4535", M.Wood),
		B.block(root, Vector3.new(0.5, 5, 0.5), base * CFrame.new(4.6, 2.5, 36), "#5a4535", M.Wood))
	-- 둘레 소품
	for _ = 1, 26 do
		local a, r = rng:NextNumber() * math.pi * 2, 55 + rng:NextNumber() * (R - 58)
		local at = base * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
		local roll = rng:NextNumber()
		if roll < 0.4 then Props.fern(root, at, rng, 0.9) elseif roll < 0.6 then Props.rock(root, at, rng, 0.5) elseif roll < 0.8 then Props.stump(root, at, rng, 1)
		else Props.mushrooms(root, at, rng) end
	end
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		Props.torch(root, base * CFrame.new(math.cos(a) * 20, 0, math.sin(a) * 20), 5)
	end
	return {Model = root, Spawn = spawn, Pads = pads, Signs = signs, Incubator = incubator, Shop = board, Center = origin}
end

return L
