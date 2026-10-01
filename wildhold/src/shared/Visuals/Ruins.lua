-- 유적·지역 소품·보물상자 모델 (v2).
-- blender/ruin_kit.py → assets/ruins/RuinModels.fbx → Studio "3D 가져오기" → ReplicatedStorage.RuinModels 에 넣으면 메쉬로,
-- 없으면 아래의 파트 대체 모델로 나온다 (Props 의 숲 키트, Kit 의 건축 키트와 같은 방식).
-- 크기·중심은 Config/RuinSizes (블렌더 스크립트가 만든다). 원점 = 바닥 가운데, 앞 = -Z.
-- 충돌은 메쉬 대신 보이지 않는 상자(Colliders)로 한다 (아치 밑·탑 옆을 자연스럽게 지나가게).
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local B = require(script.Parent.Build)

local R = {}
local M = Enum.Material
local okSizes, Sizes = pcall(function() return require(RS.Shared.Config.RuinSizes) end)
if not okSizes then Sizes = {} end

local STONE = {"#9a958a", "#8d887d", "#a39e92", "#837e74"}
local MOSS = "#5f7a45"

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

-- ===================================================================== 메쉬
local function root()
	local r = RS:FindFirstChild("RuinModels")
	if not r then
		r = workspace:FindFirstChild("RuinModels")
		if r then r.Parent = RS end
	end
	return r
end

function R.part(name)
	local r = root()
	local found = r and r:FindFirstChild(name, true)
	if found and not found:IsA("BasePart") then found = found:FindFirstChildWhichIsA("BasePart", true) end
	return found
end

function R.has(name)
	return R.part(name) ~= nil
end

-- 메쉬를 at(바닥 가운데)에 놓는다. 가져올 때 배율이 달랐으면 RuinSizes 크기로 되돌린다. 없으면 nil
local function placeMesh(parent, name, at, scale)
	local src = R.part(name)
	if not src then return nil end
	local info = Sizes[name]
	local fix = 1
	if info then
		local want = info.Size[1] + info.Size[2] + info.Size[3]
		local have = src.Size.X + src.Size.Y + src.Size.Z
		if have > 0 then fix = want / have end
	end
	local rot = src.CFrame - src.Position
	local centre = info and Vector3.new(info.Center[1], info.Center[2], info.Center[3]) or Vector3.new(0, src.Size.Y * fix / 2, 0)
	local p = src:Clone()
	p.Size = src.Size * fix * scale
	p.CFrame = at * CFrame.new(centre * scale) * rot
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, true
	p:SetAttribute("RuinAsset", name)
	p.Parent = parent
	return p
end

-- ===================================================================== 파트 대체 모델 (메쉬가 없을 때)
local function stone(m, size, at, rng, extra)
	return B.block(m, size, at, pick(rng, STONE), M.Slate, extra)
end

local function mossCap(m, size, at)
	return B.block(m, size, at, MOSS, M.Grass)
end

-- 기둥 한 토막 (원기둥 + 세로 홈 느낌의 덧댄 판)
local function drum(m, at, height, radius, rng)
	B.cyl(m, height, radius * 2, at * CFrame.new(0, height / 2, 0), pick(rng, STONE), M.Slate, true)
	for i = 0, 7 do
		B.block(m, Vector3.new(0.3, height * 0.96, 0.3), at * CFrame.Angles(0, math.rad(i * 45), 0) * CFrame.new(0, height / 2, -radius * 0.93),
			"#b0aa9d", M.Slate)
	end
end

local FALLBACK = {}

FALLBACK.RuinPillar = function(m, at, rng, s)
	stone(m, Vector3.new(3.6, 0.8, 3.6) * s, at * CFrame.new(0, 0.4 * s, 0), rng)
	drum(m, at * CFrame.new(0, 0.8 * s, 0), 11.6 * s, 1.25 * s, rng)
	stone(m, Vector3.new(3.4, 0.9, 3.4) * s, at * CFrame.new(0, 12.85 * s, 0), rng)
	stone(m, Vector3.new(2.8, 0.5, 2.8) * s, at * CFrame.new(0, 12.15 * s, 0), rng)
	mossCap(m, Vector3.new(2.6, 0.25, 2.2) * s, at * CFrame.new(0.3 * s, 13.4 * s, 0.2 * s))
end

FALLBACK.RuinPillarBroken = function(m, at, rng, s)
	stone(m, Vector3.new(3.6, 0.8, 3.6) * s, at * CFrame.new(0, 0.4 * s, 0), rng)
	drum(m, at * CFrame.new(0, 0.8 * s, 0), 4.6 * s, 1.25 * s, rng)
	-- 부러진 윗부분: 비스듬히 잘린 조각
	B.wedge(m, Vector3.new(2.4, 1.6, 2.4) * s, at * CFrame.new(0, 6.2 * s, 0) * CFrame.Angles(0, rng:NextNumber() * 6, 0), pick(rng, STONE), M.Slate)
	stone(m, Vector3.new(1.4, 1.0, 1.2) * s, at * CFrame.new(2.2 * s, 0.5 * s, 1.0 * s) * CFrame.Angles(0.3, 0.6, 0.2), rng)
end

FALLBACK.RuinPillarFallen = function(m, at, rng, s)
	-- 쓰러진 기둥 토막 셋 (원기둥 길이 방향 = X)
	for i = -1, 1 do
		B.cyl(m, 3.5 * s, 2.5 * s, at * CFrame.new(i * 3.7 * s, 1.25 * s, i * 0.3 * s) * CFrame.Angles(0, math.rad(i * 6), 0), pick(rng, STONE), M.Slate)
	end
	mossCap(m, Vector3.new(6, 0.3, 1.6) * s, at * CFrame.new(-1 * s, 2.5 * s, 0))
end

FALLBACK.RuinArch = function(m, at, rng, s)
	for _, x in ipairs({-5.5, 5.5}) do
		stone(m, Vector3.new(3.4, 1, 3.4) * s, at * CFrame.new(x * s, 0.5 * s, 0), rng)
		for k = 0, 4 do
			stone(m, Vector3.new(3, 2, 3) * s, at * CFrame.new(x * s + B.jitter(rng, 0.1) * s, (2 + k * 2) * s, 0), rng)
		end
	end
	-- 아치 돌 (쐐기돌 7개)
	for k = 0, 6 do
		local a = math.rad(180 - k * 30)
		local pos = Vector3.new(math.cos(a) * 5.5, 11 + math.sin(a) * 1.8, 0) * s
		stone(m, Vector3.new(2.4, 2.2, 3) * s, at * CFrame.new(pos) * CFrame.Angles(0, 0, a - math.pi / 2), rng)
	end
	stone(m, Vector3.new(2.2, 2.6, 3.2) * s, at * CFrame.new(0, 12.9 * s, 0), rng)
	mossCap(m, Vector3.new(5, 0.3, 2.6) * s, at * CFrame.new(-2 * s, 13.2 * s, 0))
end

FALLBACK.RuinWall = function(m, at, rng, s)
	for row = 0, 2 do
		local count = 5 - row
		for k = 0, count - 1 do
			local x = (k - (count - 1) / 2) * 2.4 + (row % 2) * 0.6
			if rng:NextNumber() > 0.12 * row then
				stone(m, Vector3.new(2.3, 1.9, 2) * s, at * CFrame.new(x * s, (1 + row * 2) * s, B.jitter(rng, 0.08) * s), rng)
			end
		end
	end
	stone(m, Vector3.new(1.6, 1.2, 1.4) * s, at * CFrame.new(6.5 * s, 0.6 * s, -1.4 * s) * CFrame.Angles(0.2, 0.5, 0.1), rng)
end

FALLBACK.RuinStatueHead = function(m, at, _, s)
	local head = at * CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(math.rad(-12), 0, math.rad(9))
	B.ellipsoid(m, Vector3.new(4.6, 5.6, 4.8) * s, head, "#9a958a", M.Slate)
	B.block(m, Vector3.new(0.9, 1.6, 1.0) * s, head * CFrame.new(0, 0, -2.4 * s), "#8d887d", M.Slate) -- 코
	for _, x in ipairs({-1, 1}) do
		B.block(m, Vector3.new(1.0, 0.3, 0.3) * s, head * CFrame.new(x * 1.0 * s, 0.9 * s, -2.25 * s), "#4a463f", M.Slate) -- 감은 눈
	end
	B.block(m, Vector3.new(1.6, 0.25, 0.3) * s, head * CFrame.new(0, -1.3 * s, -2.2 * s), "#4a463f", M.Slate)
	B.block(m, Vector3.new(4.8, 0.8, 4.4) * s, head * CFrame.new(0, 2.8 * s, 0.2 * s), "#6f6a5f", M.Slate) -- 관
	mossCap(m, Vector3.new(3.4, 0.4, 3) * s, head * CFrame.new(0.4 * s, 3.3 * s, 0.4 * s))
end

FALLBACK.RuinAltar = function(m, at, rng, s)
	stone(m, Vector3.new(6.4, 0.8, 6.4) * s, at * CFrame.new(0, 0.4 * s, 0), rng)
	stone(m, Vector3.new(5, 0.8, 5) * s, at * CFrame.new(0, 1.2 * s, 0), rng)
	stone(m, Vector3.new(3.6, 1.2, 3.6) * s, at * CFrame.new(0, 2.2 * s, 0), rng)
	B.cyl(m, 0.2, 2.4 * s, at * CFrame.new(0, 2.85 * s, 0), "#3a6f7a", M.Glass, true, {Transparency = 0.3})
end

FALLBACK.RuinObelisk = function(m, at, rng, s)
	stone(m, Vector3.new(3.4, 1.2, 3.4) * s, at * CFrame.new(0, 0.6 * s, 0), rng)
	B.block(m, Vector3.new(2.2, 13, 2.2) * s, at * CFrame.new(0, 7.7 * s, 0), "#5e5a66", M.Slate)
	B.spike(m, 2.2 * s, 2.2 * s, 2 * s, at * CFrame.new(0, 14.2 * s, 0), "#5e5a66", M.Slate)
	for k = 0, 4 do
		B.block(m, Vector3.new(0.9, 0.5, 0.1) * s, at * CFrame.new(0, (3 + k * 2.2) * s, -1.12 * s), "#8ff5e8", M.Neon)
	end
end

FALLBACK.RuinTower = function(m, at, rng, s)
	local tilt = at * CFrame.Angles(math.rad(7), 0, math.rad(-5))
	for k = 0, 7 do
		B.cyl(m, 2.2 * s, (9 - k * 0.15) * s, tilt * CFrame.new(0, (1.1 + k * 2.2) * s, 0), pick(rng, STONE), M.Slate, true)
	end
	for i = 0, 7 do
		if i % 2 == 0 then
			B.block(m, Vector3.new(1.6, 1.6, 1.4) * s, tilt * CFrame.Angles(0, math.rad(i * 45), 0) * CFrame.new(0, 18.4 * s, -3.6 * s), pick(rng, STONE), M.Slate)
		end
	end
	B.block(m, Vector3.new(1.4, 2.4, 0.3) * s, tilt * CFrame.new(0, 11 * s, -4.4 * s), "#1b1a18", M.Slate) -- 창문
	B.block(m, Vector3.new(2.4, 3.4, 0.3) * s, tilt * CFrame.new(0, 2.4 * s, -4.4 * s), "#1b1a18", M.Slate) -- 문
	mossCap(m, Vector3.new(6, 0.4, 5) * s, tilt * CFrame.new(0.5 * s, 17.7 * s, 0.4 * s))
end

FALLBACK.StandingStone = function(m, at, rng, s)
	stone(m, Vector3.new(2.2, 7, 1.4) * s, at * CFrame.new(0, 3.3 * s, 0) * CFrame.Angles(math.rad(B.jitter(rng, 4)), 0, math.rad(B.jitter(rng, 5))), rng)
	B.block(m, Vector3.new(0.3, 2.6, 0.1) * s, at * CFrame.new(0, 3.8 * s, -0.72 * s), "#b6ff8a", M.Neon)
end

FALLBACK.ObsidianSpire = function(m, at, rng, s)
	for i = 0, 2 do
		local h = (14 - i * 4) * s
		local off = CFrame.new((i == 0 and 0 or B.jitter(rng, 1.6)) * s, 0, (i == 0 and 0 or B.jitter(rng, 1.6)) * s)
		B.spike(m, (3.6 - i * 0.8) * s, (3.2 - i * 0.7) * s, h, at * off * CFrame.Angles(0, rng:NextNumber() * 3, math.rad(B.jitter(rng, 6))), "#1e1a26", M.Glass)
	end
	B.block(m, Vector3.new(0.3, 4 * s, 0.1), at * CFrame.new(0.6 * s, 3 * s, -0.9 * s) * CFrame.Angles(0, 0, 0.1), "#ff7a2a", M.Neon)
end

FALLBACK.CrystalCluster = function(m, at, rng, s)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local h = (i == 0 and 5 or 2 + rng:NextNumber() * 2.4) * s
		local base = i == 0 and at or at * CFrame.new(math.cos(a) * 1.3 * s, 0, math.sin(a) * 1.3 * s)
		B.block(m, Vector3.new(0.8 * s, h, 0.8 * s), base * CFrame.Angles(math.rad(B.jitter(rng, 25)), a, math.rad(B.jitter(rng, 25))) * CFrame.new(0, h / 2, 0),
			"#7ff0ff", M.Neon, {Transparency = 0.15})
	end
	stone(m, Vector3.new(3, 0.8, 3) * s, at * CFrame.new(0, 0.2 * s, 0), rng)
end

FALLBACK.GiantMushroom = function(m, at, rng, s)
	local lean = at * CFrame.Angles(math.rad(B.jitter(rng, 6)), 0, math.rad(B.jitter(rng, 6)))
	B.cyl(m, 13 * s, 3 * s, lean * CFrame.new(0, 6.5 * s, 0), "#e3d6bd", M.SmoothPlastic, true)
	B.ellipsoid(m, Vector3.new(14, 5, 14) * s, lean * CFrame.new(0, 14 * s, 0), "#b5523b", M.SmoothPlastic)
	B.ellipsoid(m, Vector3.new(12.6, 1, 12.6) * s, lean * CFrame.new(0, 12.4 * s, 0), "#efe3c6", M.SmoothPlastic)
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2 + rng:NextNumber()
		B.ball(m, (0.9 + rng:NextNumber() * 0.8) * s, lean * CFrame.new(math.cos(a) * 4.3 * s, 15.7 * s, math.sin(a) * 4.3 * s), "#8ff5e8", M.Neon)
	end
end

FALLBACK.GiantRoot = function(m, at, _, s)
	local prev = at * CFrame.new(-8 * s, -0.5 * s, 0)
	for k = 1, 8 do
		local t = k / 8
		local pos = at * CFrame.new((-8 + 16 * t) * s, (math.sin(t * math.pi) * 5.2 - 0.5) * s, math.sin(t * 6) * 0.8 * s)
		local from, to = prev.Position, pos.Position
		local d = (1.9 - math.abs(t - 0.5) * 1.2) * s
		B.cyl(m, (to - from).Magnitude + d * 0.6, d, CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), "#4d3a2a", M.Wood)
		prev = pos
	end
	mossCap(m, Vector3.new(3, 0.4, 1.4) * s, at * CFrame.new(0, 5.2 * s, 0))
end

FALLBACK.GlowPlant = function(m, at, rng, s)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + rng:NextNumber()
		local h = (1.6 + rng:NextNumber() * 1.4) * s
		B.block(m, Vector3.new(0.12, h, 0.12), at * CFrame.Angles(math.cos(a) * 0.35, 0, math.sin(a) * 0.35) * CFrame.new(0, h / 2, 0), "#3f6a3c", M.SmoothPlastic)
		B.ball(m, 0.55 * s, at * CFrame.Angles(math.cos(a) * 0.35, 0, math.sin(a) * 0.35) * CFrame.new(0, h, 0), "#b6ff8a", M.Neon)
	end
end

FALLBACK.MossTree = function(m, at, rng, s)
	B.cyl(m, 9 * s, 1.5 * s, at * CFrame.new(0, 4.5 * s, 0) * CFrame.Angles(0, 0, math.rad(B.jitter(rng, 5))), "#4a4036", M.Wood, true)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber()
		local arm = at * CFrame.new(0, (6 + i * 0.8) * s, 0) * CFrame.Angles(0, a, math.rad(55))
		B.cyl(m, 4.5 * s, 0.6 * s, arm * CFrame.new(0, 2 * s, 0), "#4a4036", M.Wood, true)
		-- 가지 끝에 늘어진 이끼 두 가닥
		local tip = (arm * CFrame.new(0, 3.6 * s, 0)).Position
		for _ = 1, 2 do
			local strand = tip + Vector3.new(B.jitter(rng, 0.8), 0, B.jitter(rng, 0.8)) * s
			local len = (2 + rng:NextNumber() * 2.4) * s
			B.block(m, Vector3.new(0.35 * s, len, 0.12 * s), CFrame.new(strand - Vector3.new(0, len / 2, 0)), "#6f8a4a", M.Grass)
		end
	end
end

FALLBACK.ChestBase = function(m, at, _, s)
	B.block(m, Vector3.new(4.4, 2.2, 3) * s, at * CFrame.new(0, 1.1 * s, 0), "#7a5230", M.WoodPlanks)
	for _, x in ipairs({-1.9, 1.9}) do
		B.block(m, Vector3.new(0.35, 2.3, 3.1) * s, at * CFrame.new(x * s, 1.12 * s, 0), "#d9a83a", M.Metal)
	end
	B.block(m, Vector3.new(0.9, 0.9, 0.2) * s, at * CFrame.new(0, 1.7 * s, -1.55 * s), "#f2c14e", M.Metal) -- 자물쇠
end

-- 뚜껑: 원점 = 경첩 (뒤 위 모서리). 뚜껑은 경첩에서 앞(-Z)으로 3 만큼
FALLBACK.ChestLid = function(m, at, _, s)
	B.block(m, Vector3.new(4.4, 0.9, 3) * s, at * CFrame.new(0, 0.45 * s, -1.5 * s), "#8a5d36", M.WoodPlanks)
	B.ellipsoid(m, Vector3.new(4.4, 1.4, 3.0) * s, at * CFrame.new(0, 0.85 * s, -1.5 * s), "#8a5d36", M.WoodPlanks)
	for _, x in ipairs({-1.9, 1.9}) do
		B.block(m, Vector3.new(0.35, 1.5, 3.1) * s, at * CFrame.new(x * s, 0.7 * s, -1.5 * s), "#d9a83a", M.Metal)
	end
end

-- ===================================================================== 에셋 정보
-- Colliders: {크기, 원점 기준 위치} (stud, scale 1 기준). Light: {높이, 색, 범위, 밝기}
local SPEC = {
	RuinPillar = {Colliders = {{Vector3.new(2.8, 14, 2.8), Vector3.new(0, 7, 0)}}},
	RuinPillarBroken = {Colliders = {{Vector3.new(2.8, 7, 2.8), Vector3.new(0, 3.5, 0)}}},
	RuinPillarFallen = {Colliders = {{Vector3.new(11, 2.5, 2.8), Vector3.new(0, 1.25, 0)}}},
	-- 아치: 기둥 둘 + 윗부분 (가운데 밑은 지나갈 수 있다. 메쉬 높이 약 18)
	RuinArch = {Colliders = {{Vector3.new(3.2, 11.4, 3.2), Vector3.new(-5.5, 5.7, 0)}, {Vector3.new(3.2, 11.4, 3.2), Vector3.new(5.5, 5.7, 0)},
		{Vector3.new(14.4, 4.6, 3.2), Vector3.new(0, 15.4, 0)}}},
	RuinWall = {Colliders = {{Vector3.new(11.5, 5, 2), Vector3.new(0, 2.5, 0)}}},
	RuinStatueHead = {Colliders = {{Vector3.new(4.6, 5, 4.6), Vector3.new(0, 2.5, 0)}}},
	RuinAltar = {Colliders = {{Vector3.new(6.2, 2.4, 6.2), Vector3.new(0, 1.2, 0)}}},
	RuinObelisk = {Colliders = {{Vector3.new(2.6, 16, 2.6), Vector3.new(0, 8, 0)}}, Light = {9, "#8ff5e8", 14, 0.8}},
	RuinTower = {Colliders = {{Vector3.new(8, 18, 8), Vector3.new(0, 9, 0)}}},
	StandingStone = {Colliders = {{Vector3.new(2, 7, 1.3), Vector3.new(0, 3.5, 0)}}},
	ObsidianSpire = {Colliders = {{Vector3.new(3, 10, 3), Vector3.new(0, 5, 0)}}},
	CrystalCluster = {Colliders = {{Vector3.new(2.6, 3, 2.6), Vector3.new(0, 1.5, 0)}}, Light = {2.5, "#7ff0ff", 12, 0.9}},
	GiantMushroom = {Colliders = {{Vector3.new(3, 12, 3), Vector3.new(0, 6, 0)}}, Light = {12.5, "#8ff5e8", 20, 0.8}},
	GiantRoot = {Colliders = {}},
	GlowPlant = {Colliders = {}, Light = {2, "#b6ff8a", 9, 0.7}},
	MossTree = {Colliders = {{Vector3.new(1.6, 8, 1.6), Vector3.new(0, 4, 0)}}},
	ChestBase = {Colliders = {{Vector3.new(4.4, 2.2, 3), Vector3.new(0, 1.1, 0)}}},
	ChestLid = {Colliders = {}},
}
R.Spec = SPEC

R.Names = {"RuinPillar", "RuinPillarBroken", "RuinPillarFallen", "RuinArch", "RuinWall", "RuinStatueHead", "RuinAltar", "RuinObelisk",
	"RuinTower", "StandingStone", "ObsidianSpire", "CrystalCluster", "GiantMushroom", "GiantRoot", "GlowPlant", "MossTree", "ChestBase", "ChestLid"}

-- 에셋 하나를 놓는다 (메쉬 → 없으면 파트). at = 바닥 가운데 CFrame (돌림 포함), light = 빛을 달지 (밤에 보이는 곳만)
function R.build(parent, name, at, rng, scale, light)
	scale = scale or 1
	local m = B.model(parent, name)
	if not placeMesh(m, name, at, scale) then
		FALLBACK[name](m, at, rng, scale)
	end
	local spec = SPEC[name]
	for _, box in ipairs(spec.Colliders) do
		B.new("Part", m, {Name = "Collider", Size = box[1] * scale, CFrame = at * CFrame.new(box[2] * scale), Transparency = 1,
			CanCollide = true, CanQuery = false, CastShadow = false})
	end
	if light and spec.Light then
		local l = spec.Light
		local holder = B.new("Part", m, {Name = "Glow", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = at * CFrame.new(0, l[1] * scale, 0), Transparency = 1})
		B.light(holder, "PointLight", {Color = Color3.fromHex(l[2]), Range = l[3] * scale, Brightness = l[4], Shadows = false})
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Collider" and d.Name ~= "Glow" then d.CastShadow = true end
	end
	return m
end

-- ===================================================================== 보물상자
R.ChestHinge = Vector3.new(0, 2.2, 1.5) -- 상자 바닥 가운데 → 뚜껑 경첩 (뒤 위 모서리)
R.ChestOpenAngle = 105 -- 뚜껑이 열리는 각도 (경첩 X 축)

-- 상자 모델: Base(몸통·자물쇠·충돌 + 프롬프트를 다는 Hitbox), Lid(Model, PrimaryPart = Hinge), Beam(하늘로 솟은 빛기둥)
-- 클라이언트 ChestController 가 "WildChest" 태그로 찾아 뚜껑을 열고 닫고 빛기둥을 숨긴다.
function R.chest(parent, at, tier, color, rng)
	local m = B.model(parent, "Chest")
	m:SetAttribute("Tier", tier)
	R.build(m, "ChestBase", at, rng, 1).Name = "Base"
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = m
	local hingeAt = at * CFrame.new(R.ChestHinge)
	local hinge = B.new("Part", lid, {Name = "Hinge", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = hingeAt, Transparency = 1})
	lid.PrimaryPart = hinge
	if not placeMesh(lid, "ChestLid", hingeAt, 1) then FALLBACK.ChestLid(lid, hingeAt, rng, 1) end
	-- 등급 색 장식 (뚜껑 위 보석 + 안쪽 빛)
	B.block(lid, Vector3.new(0.7, 0.35, 0.7), hingeAt * CFrame.new(0, 1.35, -1.5) * CFrame.Angles(0, math.rad(45), 0), color, M.Neon).Name = "Gem"
	local hit = B.hitbox(m, Vector3.new(5, 4, 4), at * CFrame.new(0, 2, 0), false)
	hit.Name = "Hitbox"
	local glow = B.new("Part", m, {Name = "InnerGlow", Size = Vector3.new(3.6, 0.2, 2.4), CFrame = at * CFrame.new(0, 2.0, 0), Transparency = 1})
	B.light(glow, "PointLight", {Color = Color3.fromHex(color), Range = 12, Brightness = 1.4, Shadows = false})
	-- 빛기둥: 멀리서도 보이는 하늘로 솟은 기둥 (바깥은 흐리게, 안쪽은 밝게)
	local beam = B.model(m, "Beam")
	B.cyl(beam, 140, 3.2, at * CFrame.new(0, 72, 0), color, M.Neon, true, {Transparency = 0.78, CastShadow = false})
	B.cyl(beam, 140, 1.1, at * CFrame.new(0, 72, 0), "#ffffff", M.Neon, true, {Transparency = 0.45, CastShadow = false})
	B.cyl(beam, 0.1, 9, at * CFrame.new(0, 0.12, 0), color, M.Neon, true, {Transparency = 0.5, CastShadow = false})
	CollectionService:AddTag(m, "WildChest")
	m.PrimaryPart = hit
	return m, hit
end

return R
