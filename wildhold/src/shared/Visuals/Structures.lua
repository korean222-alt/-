-- 기지 건물과 방어 시설 모델. 모두 "바닥 중심" CFrame 을 받고, -Z 가 바깥(적이 오는 쪽)이다.
local CollectionService = game:GetService("CollectionService")
local B = require(script.Parent.Build)
local Props = require(script.Parent.Props)

local S = {}
local M = Enum.Material

-- 생존 톤: 비바람에 바랜 회갈색 나무, 이끼 낀 돌, 어두운 널지붕
local WOOD, WOOD_D, WOOD_L = "#6a5442", "#4d3d30", "#8c7a64"
local STONE, STONE_D, STONE_L = "#83878a", "#62676b", "#9da1a2"
local ROOF = "#4f4239"

-- ===================================================================== Core
function S.core(parent, at)
	local m = B.model(parent, "Core")
	-- 3단 제단
	B.solid(B.cyl(m, 1.2, 15, at * CFrame.new(0, 0.6, 0), STONE_D, M.Cobblestone, true),
		B.cyl(m, 1.2, 11, at * CFrame.new(0, 1.8, 0), STONE, M.Cobblestone, true),
		B.cyl(m, 1, 7.5, at * CFrame.new(0, 2.9, 0), STONE_L, M.Slate, true))
	for i = 0, 5 do
		local a = CFrame.Angles(0, math.rad(i * 60), 0)
		local rune = B.block(m, Vector3.new(1.2, 0.1, 0.5), at * a * CFrame.new(0, 3.42, -2.9), "#6ff3e0", M.Neon)
		rune.Name = "Rune"
	end
	-- 제단 위 성스러운 모닥불: 밤에 기지 전체를 비추는 유일한 큰 불빛 (99 Nights 의 캠프파이어 역할)
	local fire = B.model(m, "Bonfire")
	for i = 0, 7 do
		local a = math.rad(i * 45 + 10)
		local bottom = (at * CFrame.new(math.cos(a) * 3.1, 3.4, math.sin(a) * 3.1)).Position
		local top = (at * CFrame.new(math.cos(a) * 0.5, 7.4, math.sin(a) * 0.5)).Position
		B.cyl(fire, (top - bottom).Magnitude + 0.4, 0.75, CFrame.lookAt((bottom + top) / 2, top) * CFrame.Angles(0, math.rad(90), 0),
			i % 2 == 0 and "#4a3322" or "#5c4029", M.Wood)
	end
	local ember = B.ball(fire, 2.4, at * CFrame.new(0, 4.3, 0), "#ff8a2a", M.Neon, {Transparency = 0.15})
	ember.Name = "Ember"
	local flames = Instance.new("Fire")
	flames.Size, flames.Heat = 10, 14
	flames.Color, flames.SecondaryColor = Color3.fromHex("#ff7a2a"), Color3.fromHex("#ffd36b")
	flames.Parent = ember
	B.light(ember, "PointLight", {Range = 56, Brightness = 2.6, Color = Color3.fromHex("#ffb070"), Shadows = true})
	CollectionService:AddTag(fire, "NightLight")
	-- 불길 위에 떠 있는 수정 (클라이언트가 천천히 돌린다)
	local crystal = B.model(m, "Crystal")
	local center = at * CFrame.new(0, 11, 0)
	local main = B.block(crystal, Vector3.new(2.6, 5.2, 2.6), center * CFrame.Angles(0, math.rad(45), 0), "#79f2e4", M.Glass,
		{Transparency = 0.15, Reflectance = 0.1})
	main.Name = "Heart"
	B.block(crystal, Vector3.new(1.7, 3.6, 1.7), center * CFrame.Angles(0, math.rad(45), 0), "#b8fff6", M.Neon)
	B.wedge(crystal, Vector3.new(2.6, 1.8, 1.3), center * CFrame.Angles(0, math.rad(45), 0) * CFrame.new(0, 3.5, -0.65), "#79f2e4", M.Glass, {Transparency = 0.15})
	B.wedge(crystal, Vector3.new(2.6, 1.8, 1.3), center * CFrame.Angles(0, math.rad(225), 0) * CFrame.new(0, 3.5, -0.65), "#79f2e4", M.Glass, {Transparency = 0.15})
	B.wedge(crystal, Vector3.new(2.6, 1.8, 1.3), center * CFrame.Angles(math.pi, math.rad(45), 0) * CFrame.new(0, 3.5, -0.65), "#79f2e4", M.Glass, {Transparency = 0.15})
	B.wedge(crystal, Vector3.new(2.6, 1.8, 1.3), center * CFrame.Angles(math.pi, math.rad(225), 0) * CFrame.new(0, 3.5, -0.65), "#79f2e4", M.Glass, {Transparency = 0.15})
	B.light(main, "PointLight", {Range = 28, Brightness = 2.2, Color = Color3.fromHex("#6ff3e0"), Shadows = false})
	-- 제단 둘레 돌 기둥 (횃대)
	for i = 0, 4 do
		local a = CFrame.Angles(0, math.rad(i * 72 + 20), 0)
		local size = Vector3.new(1.1, 2.6 + (i % 2) * 1.2, 1.1)
		B.solid(B.block(m, size, at * a * CFrame.new(0, 1.2 + size.Y / 2, -6.2) * CFrame.Angles(math.rad(-8), math.rad(45), 0), "#5f646a", M.Slate))
	end
	local hit = B.hitbox(m, Vector3.new(7.5, 12, 7.5), at * CFrame.new(0, 6, 0), true)
	hit.Name = "CoreHitbox"
	CollectionService:AddTag(m, "CoreModel")
	return B.decorate(m), hit
end

-- ===================================================================== 공용 창고
function S.storehouse(parent, at)
	local m = B.model(parent, "Storehouse")
	B.block(m, Vector3.new(12, 0.8, 9), at * CFrame.new(0, 0.4, 0), WOOD_D, M.WoodPlanks)
	for _, x in ipairs({-5.4, 5.4}) do
		for _, z in ipairs({-3.9, 3.9}) do
			B.block(m, Vector3.new(0.9, 7, 0.9), at * CFrame.new(x, 4, z), WOOD, M.Wood)
		end
	end
	B.block(m, Vector3.new(11, 5, 0.4), at * CFrame.new(0, 3.3, 3.9), WOOD_L, M.WoodPlanks)
	B.block(m, Vector3.new(0.4, 5, 7.6), at * CFrame.new(-5.4, 3.3, 0), WOOD_L, M.WoodPlanks)
	B.block(m, Vector3.new(0.4, 5, 7.6), at * CFrame.new(5.4, 3.3, 0), WOOD_L, M.WoodPlanks)
	-- 박공 지붕
	local roof = at * CFrame.new(0, 7.5, 0)
	B.spike(m, 10.5, 13.5, 3.2, roof * CFrame.Angles(0, 0, 0), ROOF, M.WoodPlanks)
	B.block(m, Vector3.new(13.6, 0.4, 0.6), roof * CFrame.new(0, 3.2, 0), "#3e342c", M.Wood)
	-- 짐: 상자, 통, 통나무, 돌
	Props.crate(m, at * CFrame.new(-3.2, 0.8, 1.6), 2.6)
	Props.crate(m, at * CFrame.new(-3.2, 3.4, 1.6), 2)
	Props.barrel(m, at * CFrame.new(3.2, 0.8, 1.8))
	Props.logPile(m, at * CFrame.new(0.6, 0.8, 1.8))
	Props.crate(m, at * CFrame.new(-7.4, 0, -2.4) * CFrame.Angles(0, math.rad(20), 0), 2.2)
	Props.barrel(m, at * CFrame.new(7.2, 0, -2.6))
	-- 간판: 상자 아이콘
	B.block(m, Vector3.new(5, 1.6, 0.3), at * CFrame.new(0, 6.6, -4.3), "#9c8c72", M.WoodPlanks)
	local sign = B.block(m, Vector3.new(1, 1, 0.1), at * CFrame.new(0, 6.6, -4.5), "#9c8c72", M.SmoothPlastic, {Transparency = 1})
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.CanvasSize, gui.LightInfluence = Enum.NormalId.Front, Vector2.new(400, 130), 1
	gui.Parent = sign
	sign.Size = Vector3.new(5, 1.6, 0.1)
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, "공용 창고"
	text.Font, text.TextScaled, text.TextColor3 = Enum.Font.FredokaOne, true, Color3.fromHex("#5a3a1e")
	text.Parent = gui
	-- 자동 입금 범위 표시 (바닥 원)
	local ring = B.cyl(m, 0.08, 18, at * CFrame.new(0, 0.9, -1), "#f6d27a", M.Neon, true, {Transparency = 0.82})
	ring.Name = "DepositRing"
	Props.lantern(m, at * CFrame.new(5.6, 5.8, -4.4))
	B.hitbox(m, Vector3.new(12, 8, 9), at * CFrame.new(0, 4, 0), true)
	return B.decorate(m)
end

-- ===================================================================== 제작대
function S.workbench(parent, at)
	local m = B.model(parent, "Workbench")
	B.block(m, Vector3.new(8, 0.8, 4), at * CFrame.new(0, 3.2, 0), WOOD_L, M.WoodPlanks)
	for _, x in ipairs({-3.4, 3.4}) do
		for _, z in ipairs({-1.5, 1.5}) do
			B.block(m, Vector3.new(0.7, 3.2, 0.7), at * CFrame.new(x, 1.6, z), WOOD, M.Wood)
		end
	end
	-- 모루 그루터기, 망치, 톱, 밧줄, 덫 견본
	B.solid(B.cyl(m, 2.4, 2.6, at * CFrame.new(6, 1.2, 0.5), WOOD, M.Wood, true))
	B.block(m, Vector3.new(2, 0.9, 1), at * CFrame.new(6, 2.8, 0.5), "#5d646b", M.Metal)
	B.cyl(m, 1.8, 0.25, at * CFrame.new(-1.8, 3.8, -0.6) * CFrame.Angles(0, math.rad(30), 0), WOOD_D, M.Wood)
	B.block(m, Vector3.new(0.5, 0.5, 0.9), at * CFrame.new(-1.0, 3.8, -0.9) * CFrame.Angles(0, math.rad(30), 0), "#5d646b", M.Metal)
	B.cyl(m, 0.6, 1.2, at * CFrame.new(1.8, 3.9, 0.4), "#c9a86a", M.Fabric, true)
	local trap = B.model(m, "TrapSample")
	S.trapIcon(trap, at * CFrame.new(-0.2, 3.6, 0.8), 0.7)
	-- 뒤판 + 공구걸이
	B.block(m, Vector3.new(8, 4, 0.3), at * CFrame.new(0, 5.6, 1.9), WOOD_D, M.WoodPlanks)
	B.block(m, Vector3.new(0.3, 2, 0.2), at * CFrame.new(-2.5, 5.5, 1.6), "#5d646b", M.Metal)
	B.block(m, Vector3.new(1.4, 0.2, 0.2), at * CFrame.new(1.5, 6.2, 1.6), "#5d646b", M.Metal)
	Props.lantern(m, at * CFrame.new(3.6, 7.9, 1.5))
	B.hitbox(m, Vector3.new(8, 4, 4), at * CFrame.new(0, 2, 0), true)
	return B.decorate(m)
end

-- 다각형 고리 (얇은 판 여러 장). 원판 파트로는 속이 빈 고리를 만들 수 없어서 조각으로 잇는다.
local function hoop(parent, at, radius, thickness, col, material, segments)
	segments = segments or 10
	local side = 2 * radius * math.tan(math.pi / segments) + 0.05
	for i = 0, segments - 1 do
		local a = CFrame.Angles(0, math.rad(i * 360 / segments), 0)
		B.block(parent, Vector3.new(side, thickness, thickness), at * a * CFrame.new(0, 0, -radius), col, material)
	end
end
S.hoop = hoop

-- 포획 덫 모양 (엮은 나무 바구니 + 잎 매듭 + 청록 부적). 월드 FX 와 제작대 견본이 이 모양을 쓴다.
-- 몬스터볼 류와 겹치지 않도록 둥근 바구니 형태를 쓴다. 밑면 중심이 at, 높이 약 3.2 * scale.
function S.trapIcon(parent, at, scale)
	scale = scale or 1
	local staves, band = "#8a7152", "#5e4a38"
	B.cyl(parent, 0.3 * scale, 3.2 * scale, at * CFrame.new(0, 0.15 * scale, 0), band, M.Wood, true)
	for i = 0, 7 do
		local a = CFrame.Angles(0, math.rad(i * 45), 0)
		-- 아래는 넓고 위로 모이는 살
		B.block(parent, Vector3.new(0.26, 2.5, 0.26) * scale, at * a * CFrame.new(0, 1.35 * scale, -1.25 * scale) * CFrame.Angles(math.rad(16), 0, 0), staves, M.Wood)
	end
	hoop(parent, at * CFrame.new(0, 0.9 * scale, 0), 1.45 * scale, 0.22 * scale, band, M.Wood, 10)
	hoop(parent, at * CFrame.new(0, 2.0 * scale, 0), 1.1 * scale, 0.22 * scale, band, M.Wood, 10)
	B.ellipsoid(parent, Vector3.new(1.6, 0.7, 1.6) * scale, at * CFrame.new(0, 2.65 * scale, 0), staves, M.Wood)
	B.ellipsoid(parent, Vector3.new(1.0, 0.45, 0.5) * scale, at * CFrame.new(0.35 * scale, 3.0 * scale, 0) * CFrame.Angles(0, 0, math.rad(20)), "#6cc35a", M.SmoothPlastic)
	B.ellipsoid(parent, Vector3.new(1.0, 0.45, 0.5) * scale, at * CFrame.new(-0.35 * scale, 3.0 * scale, 0) * CFrame.Angles(0, math.rad(40), math.rad(-20)), "#86d46b", M.SmoothPlastic)
	local charm = B.ball(parent, 0.55 * scale, at * CFrame.new(0, 1.45 * scale, -1.45 * scale), "#7ee6d8", M.Neon)
	charm.Name = "Charm"
	return charm
end

-- ===================================================================== 펫 우리
function S.pen(parent, at)
	local m = B.model(parent, "PetPen")
	local w, d = 14, 10
	B.block(m, Vector3.new(w, 0.3, d), at * CFrame.new(0, 0.15, 0), "#8e7d5e", M.Sand)
	-- 울타리 (앞쪽 가운데는 입구)
	local function fence(from, to)
		local len = (to - from).Magnitude
		local mid = (from + to) / 2
		local look = CFrame.lookAt(mid, to)
		for _, y in ipairs({1.4, 2.6}) do
			B.block(m, Vector3.new(0.3, 0.35, len), at * look * CFrame.new(0, y, 0), WOOD_L, M.Wood)
		end
		-- 가로대 사이로 빠져나가지 않게 울타리 한 칸을 통째로 막는 보이지 않는 벽
		B.new("Part", m, {Name = "FenceWall", Size = Vector3.new(0.4, 3.2, len), CFrame = at * look * CFrame.new(0, 1.6, 0), Transparency = 1,
			CanCollide = true, CastShadow = false})
	end
	local corners = {Vector3.new(-w / 2, 0, -d / 2), Vector3.new(w / 2, 0, -d / 2), Vector3.new(w / 2, 0, d / 2), Vector3.new(-w / 2, 0, d / 2)}
	for i, c in ipairs(corners) do
		B.solid(B.block(m, Vector3.new(0.7, 3.4, 0.7), at * CFrame.new(c + Vector3.new(0, 1.7, 0)), WOOD, M.Wood))
		local nextC = corners[i % 4 + 1]
		if i == 1 then
			fence(c, c + Vector3.new(4.5, 0, 0))
			fence(nextC - Vector3.new(4.5, 0, 0), nextC)
			B.solid(B.block(m, Vector3.new(0.7, 4.6, 0.7), at * CFrame.new(-2.5, 2.3, -d / 2), WOOD, M.Wood),
				B.block(m, Vector3.new(0.7, 4.6, 0.7), at * CFrame.new(2.5, 2.3, -d / 2), WOOD, M.Wood))
			B.block(m, Vector3.new(6, 0.8, 0.5), at * CFrame.new(0, 4.6, -d / 2), WOOD_D, M.Wood)
		else
			fence(c, nextC)
		end
	end
	-- 짚 침대, 물그릇, 먹이통, 발자국 깃발
	B.ellipsoid(m, Vector3.new(5, 1, 3.6), at * CFrame.new(-3, 0.6, 2.2), "#a08c52", M.Fabric)
	B.ellipsoid(m, Vector3.new(4, 0.9, 3), at * CFrame.new(3.6, 0.55, 2.6), "#a8935a", M.Fabric)
	B.cyl(m, 0.6, 2.2, at * CFrame.new(4.4, 0.6, -2), "#8d949a", M.Slate, true)
	B.cyl(m, 0.1, 1.8, at * CFrame.new(4.4, 0.92, -2), "#5ec8f0", M.Glass, true, {Transparency = 0.2})
	B.block(m, Vector3.new(2.6, 0.8, 1.2), at * CFrame.new(-4.6, 0.7, -2.4), WOOD, M.WoodPlanks)
	for i = -1, 1 do
		B.ball(m, 0.5, at * CFrame.new(-4.6 + i * 0.7, 1.2, -2.4), i == 0 and "#e2385b" or "#ff6b9a", M.SmoothPlastic)
	end
	Props.banner(m, at * CFrame.new(-w / 2 - 0.2, 0, -d / 2 - 0.2), "#5bbf8a", 8)
	Props.lantern(m, at * CFrame.new(2.5, 4.4, -d / 2 - 0.5))
	-- 등록 표지판 (발바닥)
	local post = B.block(m, Vector3.new(3.4, 2, 0.3), at * CFrame.new(-4.6, 2.6, -d / 2 - 0.6), "#a39479", M.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.CanvasSize, gui.LightInfluence = Enum.NormalId.Front, Vector2.new(300, 180), 1
	gui.Parent = post
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, "🐾\n펫 우리"
	text.Font, text.TextScaled, text.TextColor3 = Enum.Font.FredokaOne, true, Color3.fromHex("#4b6b3a")
	text.Parent = gui
	B.solid(B.block(m, Vector3.new(0.4, 2.6, 0.4), at * CFrame.new(-4.6, 1.3, -d / 2 - 0.45), WOOD, M.Wood))
	local pad = B.hitbox(m, Vector3.new(w, 1, d), at * CFrame.new(0, 0.5, 0), false)
	pad.Name = "PenPad"
	return B.decorate(m), pad
end

-- ===================================================================== 방어 자리 바닥 + 청사진 표지
local SIGN_ICON = {Wall = "🧱", Gate = "🚪", ArrowTower = "🏹", SpikeTrap = "⚠", PetStand = "🐾"}

function S.slotBase(parent, at, kind)
	local m = B.model(parent, "SlotBase")
	local size = (kind == "Wall" or kind == "Gate") and Vector3.new(13, 0.4, 5) or Vector3.new(7, 0.4, 7)
	if kind == "PetStand" then
		size = Vector3.new(6, 0.4, 6)
	end
	-- 돌 테두리만 있는 기초 (빈 자리일 때 보이는 청사진 틀)
	local frame = B.model(m, "Blueprint")
	local hx, hz = size.X / 2, size.Z / 2
	for _, edge in ipairs({{Vector3.new(size.X, 0.35, 0.5), Vector3.new(0, 0.18, -hz)}, {Vector3.new(size.X, 0.35, 0.5), Vector3.new(0, 0.18, hz)},
		{Vector3.new(0.5, 0.35, size.Z), Vector3.new(-hx, 0.18, 0)}, {Vector3.new(0.5, 0.35, size.Z), Vector3.new(hx, 0.18, 0)}}) do
		B.block(frame, edge[1], at * CFrame.new(edge[2]), STONE_L, M.Cobblestone)
	end
	B.block(frame, Vector3.new(size.X - 0.6, 0.06, size.Z - 0.6), at * CFrame.new(0, 0.04, 0), "#8fd3ff", M.Neon, {Transparency = 0.85})
	if kind ~= "PetStand" then
		local stake = B.block(frame, Vector3.new(0.3, 2.6, 0.3), at * CFrame.new(hx - 0.6, 1.3, -hz + 0.6), WOOD, M.Wood)
		-- 표지는 기지 안쪽(+Z)에서 보이도록 뒷면에 그린다
		local sign = B.block(frame, Vector3.new(1.8, 1.4, 0.15), stake.CFrame * CFrame.new(0, 1.1, 0.2), "#a39479", M.WoodPlanks)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.CanvasSize, gui.LightInfluence = Enum.NormalId.Back, Vector2.new(120, 100), 1
		gui.Parent = sign
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency, text.Text, text.TextScaled = UDim2.fromScale(1, 1), 1, SIGN_ICON[kind] or "?", true
		text.Parent = gui
	end
	local pad = B.new("Part", m, {Name = "Pad", Size = size, CFrame = at * CFrame.new(0, 0.2, 0), Transparency = 1, CanQuery = true})
	return B.decorate(m, false), pad, frame
end

-- ===================================================================== 방어 시설
local function wallWood(m, at, width)
	local rng = Random.new(7)
	local n = math.floor(width / 1.6)
	for i = 0, n - 1 do
		local x = -width / 2 + 0.8 + i * (width - 1.6) / math.max(1, n - 1)
		local h = 6.2 + rng:NextNumber() * 0.9
		Props.stake(m, at * CFrame.new(x, 0, 0) * CFrame.Angles(math.rad(rng:NextInteger(-3, 3)), 0, math.rad(rng:NextInteger(-3, 3))), h, rng)
	end
	for _, y in ipairs({1.8, 4.6}) do
		B.block(m, Vector3.new(width, 0.5, 0.5), at * CFrame.new(0, y, 1.0), WOOD_D, M.Wood)
	end
end

local function wallStone(m, at, width, reinforced)
	local rows = reinforced and 4 or 3
	for r = 0, rows - 1 do
		local offset = (r % 2) * 1.1
		local x = -width / 2 + offset
		while x < width / 2 - 0.3 do
			local w = math.min(2.2, width / 2 - x)
			local shade = Color3.fromHex(STONE):Lerp(Color3.fromHex(STONE_D), ((math.floor(x * 7 + r * 3)) % 3) / 4)
			B.block(m, Vector3.new(w - 0.12, 1.6, 2.6), at * CFrame.new(x + w / 2, 0.8 + r * 1.62, 0), shade, M.Slate)
			x = x + w
		end
	end
	local top = 0.4 + rows * 1.62
	-- 윗단 나무 방책
	for i = 0, math.floor(width / 1.8) - 1 do
		local x = -width / 2 + 0.9 + i * 1.8
		B.block(m, Vector3.new(1.2, 1.6, 0.6), at * CFrame.new(x, top + 0.8, 0.8), WOOD, M.Wood)
		B.spike(m, 1.2, 0.6, 0.9, at * CFrame.new(x, top + 1.6, 0.8) * CFrame.Angles(0, math.rad(90), 0), WOOD, M.Wood)
	end
	if reinforced then
		for _, x in ipairs({-width / 2 + 1.4, 0, width / 2 - 1.4}) do
			B.block(m, Vector3.new(1.6, top, 0.3), at * CFrame.new(x, top / 2, -1.4), "#6b7780", M.DiamondPlate)
		end
		for i = 0, 5 do
			local x = -width / 2 + 1 + i * (width - 2) / 5
			B.spike(m, 0.5, 0.5, 2.2, at * CFrame.new(x, 1.3, -1.6) * CFrame.Angles(math.rad(-70), 0, 0), "#c8ced3", M.Metal)
		end
	end
	return top
end

local function gate(m, at, width)
	for _, x in ipairs({-width / 2 - 0.2, width / 2 + 0.2}) do
		B.solid(B.block(m, Vector3.new(1.6, 9, 1.6), at * CFrame.new(x, 4.5, 0), WOOD_D, M.Wood))
		B.spike(m, 1.6, 1.6, 1.2, at * CFrame.new(x, 9, 0), WOOD_D, M.Wood)
		Props.torch(m, at * CFrame.new(x, 0, -1.6), 5)
	end
	B.block(m, Vector3.new(width + 2, 1.2, 1.2), at * CFrame.new(0, 8.2, 0), WOOD, M.Wood)
	-- 반쯤 열린 두 짝 문 (플레이어·펫 통과, 적은 막힘)
	for _, side in ipairs({-1, 1}) do
		local hinge = at * CFrame.new(side * width / 2, 0, 0) * CFrame.Angles(0, math.rad(side * -55), 0)
		local door = B.model(m, "Door")
		for i = 0, 3 do
			B.block(door, Vector3.new(1.3, 6.2, 0.5), hinge * CFrame.new(-side * (0.8 + i * 1.35), 3.3, 0), WOOD_L, M.WoodPlanks)
		end
		B.block(door, Vector3.new(5.4, 0.5, 0.6), hinge * CFrame.new(-side * 2.8, 1.5, -0.1), WOOD_D, M.Wood)
		B.block(door, Vector3.new(5.4, 0.5, 0.6), hinge * CFrame.new(-side * 2.8, 5.0, -0.1), WOOD_D, M.Wood)
	end
	Props.banner(m, at * CFrame.new(-width / 2 - 1.4, 0, 1), "#3fa9a0", 10)
end

local function arrowTower(m, at, level)
	local h = ({8, 10, 12})[level]
	local stone = level >= 2
	if stone then
		B.cyl(m, h * 0.55, 6, at * CFrame.new(0, h * 0.275, 0), STONE, M.Cobblestone, true)
	end
	for _, x in ipairs({-2, 2}) do
		for _, z in ipairs({-2, 2}) do
			B.block(m, Vector3.new(0.8, h, 0.8), at * CFrame.new(x, h / 2, z) * CFrame.Angles(math.rad(z * -1.2), 0, math.rad(x * 1.2)), WOOD, M.Wood)
		end
	end
	if not stone then
		for _, y in ipairs({h * 0.3, h * 0.62}) do
			B.block(m, Vector3.new(4.6, 0.4, 0.4), at * CFrame.new(0, y, -2) * CFrame.Angles(0, 0, math.rad(28)), WOOD_D, M.Wood)
			B.block(m, Vector3.new(4.6, 0.4, 0.4), at * CFrame.new(0, y, 2) * CFrame.Angles(0, 0, math.rad(-28)), WOOD_D, M.Wood)
		end
	end
	-- 망루 발판 + 난간
	B.block(m, Vector3.new(6.4, 0.6, 6.4), at * CFrame.new(0, h, 0), WOOD_L, M.WoodPlanks)
	for i = 0, 3 do
		local a = CFrame.Angles(0, math.rad(i * 90), 0)
		B.block(m, Vector3.new(6.4, 1.4, 0.4), at * a * CFrame.new(0, h + 1, -3), WOOD, M.WoodPlanks)
	end
	-- 석궁 (바깥 -Z 를 겨눈다)
	local bow = at * CFrame.new(0, h + 1.6, -0.6)
	B.block(m, Vector3.new(0.6, 0.6, 3), bow, WOOD_D, M.Wood)
	B.block(m, Vector3.new(3.6, 0.3, 0.3), bow * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.rad(-8), 0), "#5d646b", M.Metal)
	B.block(m, Vector3.new(0.12, 0.12, 2.4), bow * CFrame.new(0, 0.35, -0.6), "#e9dcc1", M.SmoothPlastic)
	-- 지붕
	local roofCol = level == 3 and "#3f7f8c" or ROOF
	for _, x in ipairs({-2.8, 2.8}) do
		for _, z in ipairs({-2.8, 2.8}) do
			B.block(m, Vector3.new(0.4, 3.2, 0.4), at * CFrame.new(x, h + 2.2, z), WOOD, M.Wood)
		end
	end
	B.cone(m, 8.6, 3.6 + level * 0.4, at * CFrame.new(0, h + 3.8, 0), roofCol, M.WoodPlanks, 5)
	if level == 3 then
		Props.banner(m, at * CFrame.new(0, h + 6.8, 0), "#f2c14e", 4)
	end
	return h + 1.8
end

local function spikeTrap(m, at, level)
	B.cyl(m, 0.3, 8.6, at * CFrame.new(0, 0.1, 0), "#6b5236", M.Ground, true)
	local metal = level >= 2
	local rng = Random.new(3)
	local count = metal and 16 or 11
	for _ = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		local r = math.sqrt(rng:NextNumber()) * 3.4
		local h = 1.2 + rng:NextNumber() * (metal and 1.4 or 0.9)
		local c = at * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(math.rad(rng:NextInteger(-12, 12)), rng:NextNumber() * 6, 0)
		if metal then
			B.spike(m, 0.55, 0.55, h, c, "#c9d0d6", M.Metal)
		else
			B.cyl(m, h, 0.4, c * CFrame.new(0, h / 2, 0), WOOD_L, M.Wood, true)
			B.spike(m, 0.4, 0.4, 0.5, c * CFrame.new(0, h, 0), "#e2c79a", M.Wood)
		end
	end
	B.cyl(m, 0.35, 9, at * CFrame.new(0, 0.2, 0), metal and "#5d646b" or WOOD_D, metal and M.Metal or M.Wood, true, {Transparency = 0.0})
end

local function petStand(m, at)
	B.cyl(m, 1.2, 5.6, at * CFrame.new(0, 0.6, 0), STONE_D, M.Cobblestone, true)
	B.cyl(m, 0.8, 4.6, at * CFrame.new(0, 1.6, 0), STONE_L, M.Slate, true)
	local ring = B.cyl(m, 0.1, 4, at * CFrame.new(0, 2.05, 0), "#8ff5e8", M.Neon, true, {Transparency = 0.35})
	ring.Name = "StandRing"
	for i = 0, 3 do
		local a = CFrame.Angles(0, math.rad(i * 90 + 45), 0)
		Props.lantern(m, at * a * CFrame.new(0, 1.9, -2.6))
	end
	return 2.1
end

-- kind, level → Model (+ 충돌 Hitbox) , 사격 높이
function S.defense(parent, kind, level, at, width)
	local m = B.model(parent, kind)
	local muzzle = 4
	if kind == "Wall" then
		width = width or 12
		if level == 1 then
			wallWood(m, at, width)
			muzzle = 6
		else
			muzzle = wallStone(m, at, width, level >= 3)
		end
		B.hitbox(m, Vector3.new(width, 7, 3), at * CFrame.new(0, 3.5, 0), true)
	elseif kind == "Gate" then
		width = width or 12
		gate(m, at, width - 2)
		B.hitbox(m, Vector3.new(width, 8, 2), at * CFrame.new(0, 4, 0), false)
	elseif kind == "ArrowTower" then
		muzzle = arrowTower(m, at, level)
		B.hitbox(m, Vector3.new(6.4, muzzle, 6.4), at * CFrame.new(0, muzzle / 2, 0), true)
	elseif kind == "SpikeTrap" then
		spikeTrap(m, at, level)
		muzzle = 1
		B.hitbox(m, Vector3.new(8.6, 1, 8.6), at * CFrame.new(0, 0.5, 0), false)
	elseif kind == "PetStand" then
		muzzle = petStand(m, at)
		B.hitbox(m, Vector3.new(5.6, 2, 5.6), at * CFrame.new(0, 1, 0), true)
	end
	B.decorate(m, kind ~= "SpikeTrap")
	return m, muzzle
end

return S
