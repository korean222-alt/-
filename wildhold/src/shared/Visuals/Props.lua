-- 초원 소품: 나무, 바위, 덤불, 갈대, 폐허, 꽃, 횃불, 말뚝, 굴.
-- 모든 함수는 (parent, 위치 CFrame, rng, scale) 를 받고 Model 을 돌려준다. 바닥 기준점 = 위치.
local CollectionService = game:GetService("CollectionService")
local B = require(script.Parent.Build)

local P = {}
local M = Enum.Material

-- 생존 톤 팔레트: 채도를 낮춘 짙은 숲색. 자원(열매 등)만 선명한 색을 남겨 눈에 띄게 한다.
local LEAF = {"#4a6b3a", "#557a40", "#3f5f35", "#5e7f45", "#46663c"}
local PINE = {"#27402f", "#2e4a35", "#22392b"}
local ROCK = {"#6f7479", "#666b70", "#7a7f83", "#5e6368"}

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

local function yaw(rng)
	return CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
end

function P.tree(parent, at, rng, scale, name)
	scale = scale or 1
	local m = B.model(parent, name or "Tree")
	local base = at * yaw(rng)
	local h = (7 + rng:NextNumber() * 3) * scale
	local trunkCol = rng:NextNumber() < 0.5 and "#7a5230" or "#8a5d36"
	B.cyl(m, h, 1.5 * scale, base * CFrame.new(0, h / 2, 0), trunkCol, M.Wood, true)
	-- 뿌리
	for i = 0, 2 do
		local a = CFrame.Angles(0, math.rad(i * 120 + rng:NextInteger(0, 40)), 0)
		B.wedge(m, Vector3.new(0.7, 1.2, 1.4) * scale, base * a * CFrame.new(0, 0.6 * scale, -1.2 * scale), trunkCol, M.Wood)
	end
	-- 가지
	B.cyl(m, 3 * scale, 0.6 * scale, base * CFrame.new(0.9 * scale, h * 0.72, 0) * CFrame.Angles(0, 0, math.rad(35)), trunkCol, M.Wood)
	local leafCol = pick(rng, LEAF)
	local top = base * CFrame.new(0, h, 0)
	local blobs = {
		{Vector3.new(7, 5.5, 7), CFrame.new(0, 1.2, 0)},
		{Vector3.new(5, 4.2, 5), CFrame.new(2.4, 0.2, 1)},
		{Vector3.new(5, 4, 5), CFrame.new(-2.2, 0.4, -1.2)},
		{Vector3.new(4.4, 3.8, 4.4), CFrame.new(0.4, 3.2, -0.6)},
		{Vector3.new(4, 3.4, 4), CFrame.new(-0.8, -0.6, 2.3)},
	}
	for i, blob in ipairs(blobs) do
		local c = Color3.fromHex(leafCol):Lerp(Color3.fromHex("#8fa86a"), (i == 4) and 0.25 or rng:NextNumber() * 0.1)
		B.ellipsoid(m, blob[1] * scale, top * CFrame.new(blob[2].Position * scale), c, M.SmoothPlastic)
	end
	return B.decorate(m)
end

function P.pine(parent, at, rng, scale)
	scale = scale or 1
	local m = B.model(parent, "Pine")
	local base = at * yaw(rng)
	local h = (10 + rng:NextNumber() * 5) * scale
	B.cyl(m, h * 0.5, 1.2 * scale, base * CFrame.new(0, h * 0.25, 0), "#6e4a2c", M.Wood, true)
	local col = pick(rng, PINE)
	for i = 0, 3 do
		local t = i / 4
		local d = (8 - i * 1.7) * scale
		B.cone(m, d, h * 0.34, base * CFrame.new(0, h * (0.22 + t * 0.2), 0), Color3.fromHex(col):Lerp(Color3.fromHex("#4f6f4a"), t * 0.35), M.SmoothPlastic, 7)
	end
	return B.decorate(m)
end

-- 숲 경계용 키 큰 전나무 (파트 10개로 가볍게). 99 Nights 같은 빽빽하고 어두운 숲 벽을 만든다.
function P.tallPine(parent, at, rng, scale)
	scale = scale or 1
	local m = B.model(parent, "TallPine")
	local base = at * yaw(rng)
	local h = (20 + rng:NextNumber() * 10) * scale
	B.cyl(m, h * 0.62, 1.4 * scale, base * CFrame.new(0, h * 0.31, 0), "#3e2c20", M.Wood, true)
	local col = Color3.fromHex(pick(rng, PINE))
	for i = 0, 2 do
		local t = i / 3
		B.cone(m, (9 - i * 2.2) * scale, h * 0.36, base * CFrame.new(0, h * (0.3 + t * 0.24), 0), col:Lerp(Color3.fromHex("#3d5a44"), t * 0.4), M.SmoothPlastic, 3)
	end
	return B.decorate(m)
end

-- 말라 죽은 나무: 가지만 남은 회갈색 줄기
function P.deadTree(parent, at, rng, scale)
	scale = scale or 1
	local m = B.model(parent, "DeadTree")
	local base = at * yaw(rng)
	local h = (8 + rng:NextNumber() * 5) * scale
	local col = "#5b5046"
	B.cyl(m, h, 1.1 * scale, base * CFrame.new(0, h / 2, 0) * CFrame.Angles(math.rad(rng:NextInteger(-6, 6)), 0, 0), col, M.Wood, true)
	for i = 1, 4 do
		local y = h * (0.45 + i * 0.12)
		local a = math.rad(i * 97 + rng:NextInteger(0, 40))
		local len = (3.4 - i * 0.5) * scale
		B.cyl(m, len, 0.35 * scale, base * CFrame.new(0, y, 0) * CFrame.Angles(0, a, math.rad(35 + i * 6)) * CFrame.new(len / 2, 0, 0), col, M.Wood)
	end
	return B.decorate(m)
end

-- 쓰러진 통나무 (이끼 조금)
function P.log(parent, at, rng, scale)
	scale = scale or 1
	local m = B.model(parent, "FallenLog")
	local base = at * yaw(rng)
	local len = (7 + rng:NextNumber() * 4) * scale
	B.cyl(m, len, 1.6 * scale, base * CFrame.new(0, 0.7 * scale, 0), "#4e3a2a", M.Wood)
	B.cyl(m, 0.3, 1.3 * scale, base * CFrame.new(len / 2, 0.7 * scale, 0), "#a88a62", M.Wood)
	B.ellipsoid(m, Vector3.new(len * 0.5, 0.5, 1.4) * scale, base * CFrame.new(-len * 0.1, 1.45 * scale, 0), "#4a6b3a", M.SmoothPlastic)
	return B.decorate(m)
end

-- 밤에 은은하게 빛나는 버섯 무리 (어둠 속 길잡이)
function P.mushrooms(parent, at, rng)
	local m = B.model(parent, "GlowShrooms")
	local cols = {"#62d9c4", "#8fb8ff", "#b58cff"}
	local col = pick(rng, cols)
	for _ = 1, 4 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber() * 1.3
		local h = 0.5 + rng:NextNumber() * 0.8
		local p = at * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
		B.cyl(m, h, 0.22, p * CFrame.new(0, h / 2, 0), "#d9d2c3", M.SmoothPlastic, true)
		B.ellipsoid(m, Vector3.new(0.8, 0.4, 0.8) * (0.8 + h * 0.4), p * CFrame.new(0, h, 0), col, M.Neon)
	end
	return B.decorate(m, false)
end

function P.rock(parent, at, rng, scale, name)
	scale = scale or 1
	local m = B.model(parent, name or "Rock")
	local base = at * yaw(rng)
	local col = Color3.fromHex(pick(rng, ROCK))
	local pieces = {
		{Vector3.new(5, 3.6, 4.2), CFrame.new(0, 1.4, 0)},
		{Vector3.new(3.4, 2.6, 3), CFrame.new(2.6, 0.9, 1)},
		{Vector3.new(2.6, 1.8, 2.4), CFrame.new(-2.4, 0.6, -1.2)},
	}
	for i, piece in ipairs(pieces) do
		local tilt = CFrame.Angles(math.rad(rng:NextInteger(-18, 18)), math.rad(rng:NextInteger(0, 90)), math.rad(rng:NextInteger(-18, 18)))
		local c = col:Lerp(Color3.new(1, 1, 1), i == 1 and 0.08 or 0)
		B.block(m, piece[1] * scale, base * CFrame.new(piece[2].Position * scale) * tilt, c, M.Slate)
	end
	-- 이끼 한 줌
	B.ellipsoid(m, Vector3.new(2.6, 0.6, 2) * scale, base * CFrame.new(-0.4 * scale, 3.1 * scale, 0.3 * scale), "#55703f", M.SmoothPlastic)
	return B.decorate(m)
end

function P.bush(parent, at, rng, scale, berries)
	scale = scale or 1
	local m = B.model(parent, berries and "BerryBush" or "Bush")
	local base = at * yaw(rng)
	local col = Color3.fromHex(berries and "#3f8f4a" or pick(rng, LEAF))
	local blobs = {
		{Vector3.new(4.2, 3.2, 4.2), Vector3.new(0, 1.5, 0)},
		{Vector3.new(3.2, 2.6, 3.2), Vector3.new(1.8, 1.1, 0.8)},
		{Vector3.new(3, 2.4, 3), Vector3.new(-1.6, 1.0, -0.9)},
		{Vector3.new(2.6, 2.2, 2.6), Vector3.new(-0.4, 1.0, 1.8)},
	}
	for i, blob in ipairs(blobs) do
		B.ellipsoid(m, blob[1] * scale, base * CFrame.new(blob[2] * scale), col:Lerp(Color3.fromHex("#9bd26a"), (i - 1) * 0.06), M.SmoothPlastic)
	end
	if berries then
		for i = 1, 14 do
			local a = rng:NextNumber() * math.pi * 2
			local r = 1.6 + rng:NextNumber() * 0.6
			local y = 0.8 + rng:NextNumber() * 2.2
			local ball = B.ball(m, 0.55 * scale, base * CFrame.new(math.cos(a) * r * scale, y * scale, math.sin(a) * r * scale),
				i % 3 == 0 and "#ff6b9a" or "#e2385b", M.SmoothPlastic)
			ball.Name = "Berry"
		end
	end
	return B.decorate(m)
end

function P.reeds(parent, at, rng, scale)
	scale = scale or 1
	local m = B.model(parent, "Reeds")
	local base = at * yaw(rng)
	for i = 1, 11 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber() * 1.8
		local h = (3.5 + rng:NextNumber() * 2.5) * scale
		local tilt = CFrame.Angles(math.rad(rng:NextInteger(-12, 12)), 0, math.rad(rng:NextInteger(-12, 12)))
		local stem = base * CFrame.new(math.cos(a) * r * scale, 0, math.sin(a) * r * scale) * tilt
		B.cyl(m, h, 0.28 * scale, stem * CFrame.new(0, h / 2, 0), "#7f9a52", M.SmoothPlastic, true)
		if i % 2 == 0 then
			B.ellipsoid(m, Vector3.new(0.55, 1.4, 0.55) * scale, stem * CFrame.new(0, h + 0.3, 0), "#c9a46a", M.SmoothPlastic)
		end
	end
	-- 풀 잎사귀
	for i = 1, 6 do
		local a = CFrame.Angles(0, math.rad(i * 60 + rng:NextInteger(0, 30)), 0)
		B.wedge(m, Vector3.new(0.2, 2.4 * scale, 1.2 * scale), base * a * CFrame.new(0, 1.2 * scale, -1 * scale), "#6b8a48", M.SmoothPlastic)
	end
	return B.decorate(m)
end

function P.scrap(parent, at, rng, scale)
	scale = scale or 1
	local m = B.model(parent, "Scrap")
	local base = at * yaw(rng)
	-- 부서진 옛 기계: 녹슨 판, 톱니, 파이프, 볼트
	B.block(m, Vector3.new(4.6, 0.5, 3.4) * scale, base * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(14), 0, math.rad(-8)), "#8a5a3a", M.CorrodedMetal)
	B.block(m, Vector3.new(2.4, 3.2, 0.4) * scale, base * CFrame.new(-1.4 * scale, 1.6 * scale, 1 * scale) * CFrame.Angles(0, math.rad(20), math.rad(12)), "#6f7c86", M.DiamondPlate)
	local gear = B.cyl(m, 0.6 * scale, 3.2 * scale, base * CFrame.new(1.6 * scale, 1.7 * scale, -0.6 * scale) * CFrame.Angles(0, math.rad(70), math.rad(-20)), "#b0763e", M.CorrodedMetal)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		B.block(m, Vector3.new(0.6, 0.7, 0.7) * scale, gear.CFrame * CFrame.Angles(a, 0, 0) * CFrame.new(0, 1.75 * scale, 0), "#b0763e", M.CorrodedMetal)
	end
	B.cyl(m, 4 * scale, 0.9 * scale, base * CFrame.new(0.4 * scale, 0.5 * scale, 1.8 * scale) * CFrame.Angles(0, math.rad(-15), 0), "#7c8b95", M.Metal)
	B.ball(m, 0.8 * scale, base * CFrame.new(-2 * scale, 0.4 * scale, -1.4 * scale), "#c28a4a", M.CorrodedMetal)
	return B.decorate(m)
end

function P.flowers(parent, at, rng)
	local m = B.model(parent, "Flowers")
	local cols = {"#ffd1e8", "#fff3a8", "#ffffff", "#c7b6ff", "#ffb07a"}
	local col = pick(rng, cols)
	for _ = 1, 5 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber() * 1.6
		local h = 0.8 + rng:NextNumber() * 0.7
		local p = at * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
		B.cyl(m, h, 0.12, p * CFrame.new(0, h / 2, 0), "#6aa84f", M.SmoothPlastic, true)
		B.ellipsoid(m, Vector3.new(0.7, 0.3, 0.7), p * CFrame.new(0, h, 0), col, M.SmoothPlastic)
		B.ball(m, 0.25, p * CFrame.new(0, h + 0.1, 0), "#ffcf3a", M.SmoothPlastic)
	end
	return B.decorate(m, false)
end

function P.stake(parent, at, height, rng)
	local m = parent
	local col = Color3.fromHex("#8a5d36"):Lerp(Color3.fromHex("#6e4a2c"), rng:NextNumber())
	B.cyl(m, height, 1.7, at * CFrame.new(0, height / 2, 0), col, M.Wood, true)
	B.spike(m, 1.7, 1.5, 1.4, at * CFrame.new(0, height, 0), col, M.Wood)
end

function P.torch(parent, at, height)
	height = height or 6
	local m = B.model(parent, "Torch")
	B.cyl(m, height, 0.5, at * CFrame.new(0, height / 2, 0), "#6e4a2c", M.Wood, true)
	B.cyl(m, 0.9, 1.1, at * CFrame.new(0, height + 0.2, 0), "#4b4f55", M.Metal, true)
	local flame = B.ball(m, 0.9, at * CFrame.new(0, height + 0.9, 0), "#ffb347", M.Neon)
	flame.Name = "Flame"
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 2.2, 6, Color3.fromHex("#ff9a3c"), Color3.fromHex("#ffd36b")
	fire.Parent = flame
	B.light(flame, "PointLight", {Range = 22, Brightness = 1.6, Color = Color3.fromHex("#ffb066"), Shadows = false})
	CollectionService:AddTag(m, "NightLight")
	return B.decorate(m)
end

function P.lantern(parent, at)
	local m = B.model(parent, "Lantern")
	B.block(m, Vector3.new(0.9, 1.2, 0.9), at, "#3c3f44", M.Metal)
	local glow = B.block(m, Vector3.new(0.7, 0.8, 0.7), at, "#ffd27a", M.Neon)
	B.light(glow, "PointLight", {Range = 14, Brightness = 1.2, Color = Color3.fromHex("#ffc070"), Shadows = false})
	CollectionService:AddTag(m, "NightLight")
	return m
end

function P.crate(parent, at, size)
	size = size or 2.6
	local m = B.model(parent, "Crate")
	B.block(m, Vector3.one * size, at * CFrame.new(0, size / 2, 0), "#b07b45", M.WoodPlanks)
	for _, dir in ipairs({CFrame.new(), CFrame.Angles(0, math.rad(90), 0)}) do
		B.block(m, Vector3.new(size + 0.1, 0.35, 0.35), at * CFrame.new(0, size / 2, 0) * dir * CFrame.new(0, 0, size / 2) * CFrame.Angles(0, 0, math.rad(45)), "#7a5230", M.Wood)
	end
	return B.decorate(m)
end

function P.barrel(parent, at)
	local m = B.model(parent, "Barrel")
	B.cyl(m, 3, 2.2, at * CFrame.new(0, 1.5, 0), "#9a6a3c", M.WoodPlanks, true)
	B.cyl(m, 0.25, 2.3, at * CFrame.new(0, 0.6, 0), "#4b4f55", M.Metal, true)
	B.cyl(m, 0.25, 2.3, at * CFrame.new(0, 2.4, 0), "#4b4f55", M.Metal, true)
	return B.decorate(m)
end

function P.logPile(parent, at)
	local m = B.model(parent, "Logs")
	for i, off in ipairs({Vector3.new(-0.8, 0.7, 0), Vector3.new(0.8, 0.7, 0), Vector3.new(0, 1.9, 0)}) do
		B.cyl(m, 4, 1.4, at * CFrame.new(off) * CFrame.Angles(0, math.rad(90 + i * 4), 0), "#8a5d36", M.Wood)
	end
	return B.decorate(m)
end

function P.banner(parent, at, col, height)
	height = height or 8
	local m = B.model(parent, "Banner")
	B.cyl(m, height, 0.4, at * CFrame.new(0, height / 2, 0), "#6e4a2c", M.Wood, true)
	B.block(m, Vector3.new(2.2, 3.2, 0.12), at * CFrame.new(1.2, height - 1.8, 0), col or "#3fa9a0", M.Fabric)
	B.wedge(m, Vector3.new(0.12, 0.8, 2.2), at * CFrame.new(1.2, height - 3.8, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), col or "#3fa9a0", M.Fabric)
	return B.decorate(m)
end

-- 밤의 괴물이 기어 나오는 굴. 입구는 기지를 향한다(-Z 가 기지 쪽).
function P.burrow(parent, at, rng)
	local m = B.model(parent, "Burrow")
	local ring = {
		{Vector3.new(7, 7, 6), Vector3.new(-6, 2.6, 1)}, {Vector3.new(7, 8, 6), Vector3.new(6, 3, 1)},
		{Vector3.new(12, 5, 7), Vector3.new(0, 7, 2)}, {Vector3.new(6, 4, 5), Vector3.new(-9, 1.5, 3)},
		{Vector3.new(6, 4, 5), Vector3.new(9, 1.5, 3)}, {Vector3.new(16, 6, 8), Vector3.new(0, 3, 6)},
	}
	for _, piece in ipairs(ring) do
		local tilt = CFrame.Angles(math.rad(rng:NextInteger(-12, 12)), math.rad(rng:NextInteger(-20, 20)), math.rad(rng:NextInteger(-12, 12)))
		B.block(m, piece[1], at * CFrame.new(piece[2]) * tilt, "#4d4a55", M.Slate)
	end
	local hole = B.block(m, Vector3.new(7.5, 6.5, 0.4), at * CFrame.new(0, 3.2, 0.6), "#120c1c", M.SmoothPlastic)
	hole.Name = "Mouth"
	local glow = B.block(m, Vector3.new(6, 5, 0.2), at * CFrame.new(0, 3, 0.3), "#6a2fb0", M.Neon, {Transparency = 0.55})
	glow.Name = "Glow"
	B.light(glow, "PointLight", {Range = 18, Brightness = 2, Color = Color3.fromHex("#9a5cff"), Shadows = false})
	-- 가시 덩굴
	for i = 1, 5 do
		local x = -7 + i * 2.6
		B.spike(m, 0.8, 0.6, 2 + rng:NextNumber() * 1.5, at * CFrame.new(x, 8.8 + rng:NextNumber(), 2), "#2f2438", M.SmoothPlastic)
	end
	CollectionService:AddTag(m, "Burrow")
	return B.decorate(m)
end

return P
