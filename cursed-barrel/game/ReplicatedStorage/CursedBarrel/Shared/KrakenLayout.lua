--[[
	KrakenLayout  (Phase 10)
	배를 삼키려는 크라켄. 다리 모양과 움직임을 숫자로만 정의한다.

	· 이 모듈은 인스턴스를 만들지 않는다. 좌표 계산만 한다.
	  (클라이언트 KrakenController 가 이 값으로 다리를 세우고 흔든다. 검사 코드도 같은 식을 쓴다)
	· 다리는 전부 배의 바깥 바다에서 올라와 난간을 넘어 갑판 가장자리에 걸친다.
	  테이블 · 의자 · 대포 · 화물 · 계단 · 조타륜 쪽으로는 들어오지 않는다.
	· 장식이라 부딪히지 않는다. (CanCollide/CanTouch/CanQuery 전부 꺼짐)

	다리 하나 = 지나가는 점(waypoint) 여러 개.
	  점 사이는 centripetal Catmull-Rom 으로 이어서 넘치거나 꺾이지 않게 한다.
	  그다음 길이를 따라 고르게 다시 나눠 마디(sample)를 만든다. 마디마다 굵기가 끝으로 갈수록 가늘어진다.

	움직임 : 점마다 옆으로 흔들리는 폭(sway)과 위로 들리는 폭(lift)이 있다.
	  갑판 위에 놓인 점은 옆으로 조금만 움직이고, 위로만 들린다. (갑판이나 난간을 뚫지 않는다)
]]

local ShipLayout = require(script.Parent.ShipLayout)

local K = {}

K.SeaY = -2.2 -- MapBuilder 가 까는 바다 높이 (GameConfig.Map.Sea.Level)
K.DeckTop = ShipLayout.DeckY -- 갑판 윗면
K.RailTop = 4.55 -- 뱃전 위 금색 테두리의 윗면
K.QuarterdeckTop = 17.8 -- 선미 후갑판 윗면
K.QuarterRailTop = 20.5 -- 후갑판 난간 윗면

K.Colors = {
	-- 뿌리(SkinDark) → 몸(Skin) → 끝(Tip) 으로 부드럽게 바뀐다. 안쪽은 Belly, 빨판은 Sucker 테두리 + SuckerCup 속.
	Skin = Color3.fromRGB(122, 40, 70),
	SkinDark = Color3.fromRGB(58, 20, 44),
	Tip = Color3.fromRGB(186, 78, 96),
	Belly = Color3.fromRGB(226, 150, 150),
	Sucker = Color3.fromRGB(244, 196, 184),
	SuckerCup = Color3.fromRGB(168, 84, 98),
	Foam = Color3.fromRGB(228, 240, 246),
	EyeWhite = Color3.fromRGB(236, 214, 120),
	Iris = Color3.fromRGB(255, 150, 40),
	Pupil = Color3.fromRGB(12, 8, 10),
}

-- 마디 수. 품질이 낮으면 줄인다. (마디가 촘촘해야 다리가 매끈한 곡선으로 보인다)
K.Samples = { High = 26, Low = 14 }

--------------------------------------------------
-- 다리 정의
--------------------------------------------------

local function v(x, y, z)
	return Vector3.new(x, y, z)
end

--[[
	뱃전(옆구리) 난간을 넘어 주갑판 가장자리에 걸치는 다리.
	side  : -1 (좌현) / 1 (우현)
	z     : 난간을 넘는 위치
	reach : 난간 안쪽으로 얼마나 들어오는가 (스터드)
	lean  : 바다에서 올라오는 방향이 앞뒤로 얼마나 비스듬한가
]]
local function railArm(name, side, z, opts)
	opts = opts or {}
	local half = ShipLayout.halfWidth(z)
	local reach = opts.reach or 5
	local lean = opts.lean or 6
	local apex = opts.apex or 10
	local rail = K.RailTop
	return {
		name = name,
		baseRadius = opts.baseRadius or 2.9,
		tipRadius = 0.32,
		speed = opts.speed or 0.62,
		phase = opts.phase or 0,
		waypoints = {
			{ p = v(side * (half + 17), K.SeaY - 7, z + lean), sway = 0, lift = 0 },
			{ p = v(side * (half + 12), K.SeaY + 2, z + lean * 0.7), sway = 0.6, lift = 0.4 },
			{ p = v(side * (half + 6.5), rail + apex, z + lean * 0.3), sway = 1.6, lift = 1.2 },
			{ p = v(side * (half + 1.2), rail + 2.6, z + lean * 0.08), sway = 0.5, lift = 0.5 },
			-- 난간 금테 바로 위를 누르고 지나간다
			{ p = v(side * (half - 0.6), rail + 1.7, z), sway = 0.3, lift = 0.3 },
			{ p = v(side * (half - 1.9), rail + 0.4, z - 0.3), sway = 0.2, lift = 0.25 },
			{ p = v(side * (half - reach * 0.65), K.DeckTop + 0.8, z - 0.8), sway = 0.25, lift = 0.25, rest = true },
			{ p = v(side * (half - reach), K.DeckTop + 0.55, z - 1.4), sway = 0.3, lift = 0.35, rest = true, curl = true },
		},
	}
end

-- 선미 후갑판 옆 난간을 넘어 후갑판 위에 걸치는 다리
local function quarterArm(name, side, z, opts)
	opts = opts or {}
	local lean = opts.lean or -5
	return {
		name = name,
		baseRadius = opts.baseRadius or 3.3,
		tipRadius = 0.34,
		speed = opts.speed or 0.55,
		phase = opts.phase or 0,
		waypoints = {
			{ p = v(side * 76, K.SeaY - 8, z + lean), sway = 0, lift = 0 },
			{ p = v(side * 69, K.SeaY + 4, z + lean * 0.7), sway = 0.6, lift = 0.4 },
			{ p = v(side * 62, 25, z + lean * 0.35), sway = 1.8, lift = 1.3 },
			{ p = v(side * 56.5, 26.5, z + lean * 0.1), sway = 1.2, lift = 0.9 },
			{ p = v(side * 53.2, K.QuarterRailTop + 1.9, z), sway = 0.4, lift = 0.4 },
			{ p = v(side * 50.6, K.QuarterdeckTop + 0.7, z - 0.8), sway = 0.25, lift = 0.25, rest = true },
			{ p = v(side * 48.2, K.QuarterdeckTop + 0.5, z - 2), sway = 0.3, lift = 0.35, rest = true, curl = true },
		},
	}
end

-- 배 꼬리(선미) 뒤에서 올라와 후갑판 뒤 난간을 넘는 다리
local function sternArm(name, x, opts)
	opts = opts or {}
	local drift = opts.drift or 0
	return {
		name = name,
		baseRadius = opts.baseRadius or 3.4,
		tipRadius = 0.34,
		speed = opts.speed or 0.5,
		phase = opts.phase or 0,
		-- 선미 벽 바로 위로 넘어오므로 습격 때도 조금만 더 날뛴다 (벽을 스치지 않게)
		wildScale = 0.35,
		waypoints = {
			{ p = v(x + drift, K.SeaY - 8, -182), sway = 0, lift = 0 },
			{ p = v(x + drift * 0.7, K.SeaY + 4, -174), sway = 0.6, lift = 0.4 },
			{ p = v(x + drift * 0.3, 27, -165), sway = 1.8, lift = 1.3 },
			{ p = v(x, 23, -156.9), sway = 0.4, lift = 0.4 },
			{ p = v(x * 0.97, K.QuarterdeckTop + 0.7, -151.5), sway = 0.25, lift = 0.25, rest = true },
			{ p = v(x * 0.93, K.QuarterdeckTop + 0.5, -147.5), sway = 0.3, lift = 0.35, rest = true, curl = true },
		},
	}
end

-- 뱃머리 앞 사장(bowsprit)을 감아 넘는 다리
local function bowspritArm(name)
	return {
		name = name,
		baseRadius = 2.6,
		tipRadius = 0.3,
		speed = 0.7,
		phase = 1.7,
		waypoints = {
			{ p = v(22, K.SeaY - 7, 176), sway = 0, lift = 0 },
			{ p = v(15, K.SeaY + 3, 172), sway = 0.6, lift = 0.4 },
			{ p = v(6.5, 16.5, 168.5), sway = 1.4, lift = 1 },
			{ p = v(0, 12.6, 167), sway = 0.35, lift = 0.35 },
			{ p = v(-3.4, 9.6, 166.4), sway = 0.9, lift = 0.4 },
			{ p = v(-4.6, 5.6, 166), sway = 1.4, lift = 0.6, curl = true },
		},
	}
end

K.Arms = {
	-- 좌현 (x < 0). 선미 쪽에 머리가 있다.
	railArm("Port_Bow", -1, 94, { reach = 4.5, lean = 7, apex = 9, phase = 0.3 }),
	railArm("Port_Waist", -1, 40, { reach = 5.5, lean = -5, apex = 11, phase = 2.1, baseRadius = 3.1 }),
	railArm("Port_Aft", -1, -36, { reach = 5, lean = -7, apex = 12, phase = 4.0, baseRadius = 3.2 }),
	quarterArm("Port_Quarter", -1, -128, { phase = 5.2 }),
	-- 우현 (x > 0)
	railArm("Starboard_Bow", 1, 88, { reach = 4.5, lean = 6, apex = 10, phase = 1.1 }),
	railArm("Starboard_Mid", 1, -6, { reach = 5.5, lean = 5, apex = 11, phase = 3.3, baseRadius = 3.0 }),
	quarterArm("Starboard_Quarter", 1, -122, { phase = 0.9, lean = 5 }),
	-- 선미 뒤
	sternArm("Stern_Port", -33, { drift = -6, phase = 2.6 }),
	sternArm("Stern_Starboard", 36, { drift = 7, phase = 4.6 }),
	-- 뱃머리
	bowspritArm("Bowsprit"),
}

--[[
	Phase 15 : 갑판 위에 가로로 길게 누운 다리 (움직이지 않는다 · 대포 과녁이 아니다)
	  "배에 살짝 걸쳐 두지 말고 어느 쪽은 아예 가로로 누워 있게" 라는 요청.
	  바다에서 올라와 난간을 넘은 뒤 갑판(또는 후갑판) 위에 몸통째 드러누운 다리 셋.
	    · 우현 주갑판 : 난간을 넘어 뱃전을 따라 길게 눕는다 (화물 · 대포 · 돛대 밧줄 사이의 빈 자리)
	    · 후갑판 양쪽 : 난간을 넘어 조타륜 뒤 후갑판을 가로질러 눕는다 (가운데 길은 비워 둔다)
	  Blender 모델(assets/models)이 이 곡선을 그대로 따라 만들어진다. 모델이 없으면 KrakenController 가 같은 곡선으로 파트를 세운다.
	  taper 가 작아서(0.72) 끝까지 굵다. 누운 몸이 가늘면 무게감이 없다.
]]
K.Resting = {
	{
		name = "Rest_Starboard_Deck",
		baseRadius = 3.3,
		tipRadius = 0.36,
		taper = 0.72,
		lieFrom = 0.84, -- 이 지점부터 갑판에 몸을 붙이고 눕는다
		curlFrom = 0.93, -- 끝이 말리기 시작하는 곳 (없으면 K.RestCurlFrom)
		waypoints = {
			{ p = v(80, K.SeaY - 8, 64) },
			{ p = v(70.5, K.SeaY + 1.5, 59.4) },
			{ p = v(62.8, 7, 54.8) },
			{ p = v(59.8, 8.4, 52.4) },
			{ p = v(57.6, 8.5, 50.4) },
			{ p = v(55.8, 7.8, 48.6) },
			{ p = v(54.2, 6.2, 46.6) },
			{ p = v(53.4, 4.6, 44.8) },
			{ p = v(52.7, 2.7, 42.2) },
			{ p = v(52, 2.09, 38.6) },
			{ p = v(52.2, 1.69, 35.2) },
			{ p = v(51.8, 1.6, 31.8) },
			{ p = v(52.1, 1.5, 29.4) },
		},
	},
	{
		name = "Rest_Starboard_Quarter",
		baseRadius = 3.5,
		tipRadius = 0.4,
		taper = 0.6,
		lieFrom = 0.76,
		waypoints = {
			{ p = v(86, K.SeaY - 8, -131.5) },
			{ p = v(75, K.SeaY + 4, -132.6) },
			{ p = v(66.5, 17, -133.6) },
			{ p = v(61.2, 24.6, -134.2) },
			{ p = v(57.8, 26.8, -134.4) },
			{ p = v(54.2, 26.2, -134.4) },
			{ p = v(51.6, 23.6, -134.2) },
			{ p = v(49.4, 21.2, -134.0) },
			{ p = v(46.6, 19.67, -133.2) },
			{ p = v(41.2, 19.45, -132.4) },
			{ p = v(35.2, 19.16, -133.4) },
			{ p = v(29.4, 18.75, -133.1) },
			{ p = v(24.6, 18.75, -132.4) },
		},
	},
	{
		name = "Rest_Port_Quarter",
		baseRadius = 3.4,
		tipRadius = 0.4,
		taper = 0.6,
		lieFrom = 0.76,
		waypoints = {
			{ p = v(-86, K.SeaY - 8, -139.4) },
			{ p = v(-75, K.SeaY + 4, -138.6) },
			{ p = v(-66.5, 17, -137.8) },
			{ p = v(-61.2, 24.6, -137.3) },
			{ p = v(-57.8, 26.8, -137.1) },
			{ p = v(-54.2, 26.2, -137.1) },
			{ p = v(-51.6, 23.6, -137.2) },
			{ p = v(-49.4, 21.2, -137.5) },
			{ p = v(-46.6, 19.63, -138.2) },
			{ p = v(-41.2, 19.42, -139.4) },
			{ p = v(-35.2, 19.13, -138.2) },
			{ p = v(-29.4, 18.74, -138.8) },
			{ p = v(-24.6, 18.74, -139.4) },
		},
	},
}
-- 누운 다리 끝이 말리는 곳과 각도 (위로 말려 올라간다)
K.RestCurlFrom = 0.9
K.RestCurlAngle = math.rad(250)

-- 머리 : 좌현 선미 쪽 바다에서 반쯤 떠올라 배를 노려본다.
-- 눈은 머리 표면에 반쯤 박혀 물 위로 올라와 있다. (머리 중심에서 눈까지 거리 ≈ 반지름 - 1)
K.Head = {
	center = v(-106, -10, -96),
	lookAt = v(-40, 2, -80),
	mantle = 48, -- 가장 큰 공의 지름
	eyeSpread = 9.5, -- 눈 사이 간격의 절반
	eyeRise = 13, -- 눈 높이 (머리 중심 기준)
	eyeForward = 16.4, -- 눈이 머리 중심에서 앞으로 나온 거리
	eye = 8,
}

--------------------------------------------------
-- 곡선 계산
--------------------------------------------------

-- centripetal Catmull-Rom (Barry–Goldman). 점 간격이 고르지 않아도 넘치지 않는다.
local function knot(t, a, b)
	local d = (b - a).Magnitude
	return t + math.max(math.sqrt(d), 1e-3)
end

local function catmull(p0, p1, p2, p3, u)
	local t0 = 0
	local t1 = knot(t0, p0, p1)
	local t2 = knot(t1, p1, p2)
	local t3 = knot(t2, p2, p3)
	local t = t1 + (t2 - t1) * u
	local a1 = p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
	local a2 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
	local a3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
	local b1 = a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
	local b2 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
	return b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1))
end

-- 다리가 놓인 세로 평면의 법선 (옆으로 흔들리는 방향)
function K.planeNormal(arm)
	local first = arm.waypoints[1].p
	local last = arm.waypoints[#arm.waypoints].p
	local flat = Vector3.new(last.X - first.X, 0, last.Z - first.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, 1)
	end
	return flat.Unit:Cross(Vector3.new(0, 1, 0)).Unit
end

-- 시각 t 에서 점들의 위치. t 가 nil 이면 쉬는 자세.
-- amp (Phase 12) : 얼마나 날뛰는가. 1 이 평소. 폭풍 · 습격 때 커진다.
--   바다 위로 솟은 점(sway 0.6 이상)만 크게 흔든다. 난간 · 갑판에 걸친 점은 그대로라 배를 뚫지 않는다.
function K.waypointsAt(arm, t, amp)
	local normal = K.planeNormal(arm)
	local up = Vector3.new(0, 1, 0)
	local wild = math.max(1, tonumber(amp) or 1)
	local list = {}
	for index, point in ipairs(arm.waypoints) do
		local position = point.p
		if t and (point.sway > 0 or point.lift > 0) then
			local w = arm.speed * t + arm.phase + index * 0.8
			local free = point.sway >= 0.6 and (1 + (wild - 1) * (arm.wildScale or 1)) or 1
			local side = math.sin(w) * point.sway * free
			local lift = (0.5 + 0.5 * math.sin(w * 0.73 + index * 1.1)) * point.lift * free
			if free > 1 then
				-- 날뛸 때는 빠른 떨림이 더해진다
				side += math.sin(t * 2.3 + index * 1.7 + arm.phase) * 0.45 * (free - 1)
				lift += (0.5 + 0.5 * math.sin(t * 1.9 + index)) * 0.6 * (free - 1)
			end
			position = position + normal * side + up * lift
		end
		list[index] = position
	end
	return list
end

-- 굵기 : u (0 = 바다 속 뿌리, 1 = 끝). taper 가 작을수록 끝까지 굵다 (Phase 15 누운 다리는 0.72)
function K.radiusAt(arm, u)
	return arm.tipRadius + (arm.baseRadius - arm.tipRadius) * (1 - u) ^ (arm.taper or 1.25)
end

--[[
	다리 하나의 마디 위치와 굵기.
	count 개의 점이 길이를 따라 고르게 놓인다.
	돌려주는 값 : { {p = Vector3, r = number, u = number}, ... }
]]
function K.sample(arm, t, count, amp)
	local points = K.waypointsAt(arm, t, amp)
	local n = #points
	-- 양 끝에 가상의 점을 하나씩 더해 첫 구간과 마지막 구간도 곡선이 되게 한다.
	local padded = { points[1] * 2 - points[2] }
	for i = 1, n do
		padded[i + 1] = points[i]
	end
	padded[n + 2] = points[n] * 2 - points[n - 1]

	-- 촘촘하게 찍고 길이를 잰다.
	local dense = { points[1] }
	local lengths = { 0 }
	local steps = 10
	for span = 1, n - 1 do
		local p0, p1, p2, p3 = padded[span], padded[span + 1], padded[span + 2], padded[span + 3]
		for step = 1, steps do
			local point = catmull(p0, p1, p2, p3, step / steps)
			lengths[#dense + 1] = lengths[#dense] + (point - dense[#dense]).Magnitude
			dense[#dense + 1] = point
		end
	end

	-- 길이를 따라 고르게 다시 나눈다.
	local total = lengths[#lengths]
	local result = {}
	local cursor = 1
	for index = 1, count do
		local u = (index - 1) / (count - 1)
		local want = u * total
		while cursor < #dense - 1 and lengths[cursor + 1] < want do
			cursor += 1
		end
		local span = math.max(lengths[cursor + 1] - lengths[cursor], 1e-6)
		local alpha = math.clamp((want - lengths[cursor]) / span, 0, 1)
		local position = dense[cursor]:Lerp(dense[cursor + 1], alpha)
		result[index] = { p = position, r = K.radiusAt(arm, u), u = u }
	end
	return result
end

-- 빨판이 붙는 쪽 (곡선의 안쪽). 쉬는 자세에서 가장 높은 곳이 아래를 보도록 부호를 정한다.
function K.innerSign(arm, count)
	local samples = K.sample(arm, nil, count)
	local normal = K.planeNormal(arm)
	local top = 2
	for index = 2, #samples - 1 do
		if samples[index].p.Y > samples[top].p.Y then
			top = index
		end
	end
	local tangent = samples[math.min(top + 1, #samples)].p - samples[math.max(top - 1, 1)].p
	local inner = normal:Cross(tangent)
	return inner.Y > 0 and -1 or 1
end

--------------------------------------------------
-- Phase 15 : 누운 다리
--------------------------------------------------

-- (x, z) 바로 아래에서 가장 높은 딛는 면의 높이. 배 밖(바다)이면 nil.
-- 후갑판 옆 띠(|x| 52.4 ~ 58)는 난간 높이로 친다. (크라켄 검사와 같은 기준)
function K.floorAt(x, z, reach)
	local ax = math.abs(x) + (reach or 0)
	if z <= ShipLayout.CabinFront + 0.5 and z >= -159 and ax < 58 then
		return ax < 52.4 and K.QuarterdeckTop or K.QuarterRailTop
	end
	if z > -159 and z < ShipLayout.Bow then
		local half = ShipLayout.halfWidth(z)
		if ax < half - 1.2 then
			return K.DeckTop
		end
		if ax < half + 0.6 then
			return K.RailTop
		end
	end
	return nil
end

local UP = Vector3.new(0, 1, 0)

-- 두 방향 벡터를 섞어 tangent 에 수직으로 만든다
local function perpendicular(vector, tangent)
	local out = vector - tangent * vector:Dot(tangent)
	if out.Magnitude < 1e-4 then
		return nil
	end
	return out.Unit
end

--[[
	누운 다리 하나의 마디. 돌려주는 값 : { {p, r, u, inner}, ... }
	  · 곡선은 K.sample 과 같다 (쉬는 자세). lieFrom 부터는 딛는 면에 몸을 붙인다(무게감).
	    어디서든 딛는 면 아래로 파고드는 마디는 면 위로 올린다.
	  · 끝은 위로 말린다 (RestCurlFrom 부터 RestCurlAngle 만큼).
	  · inner : 빨판이 보는 쪽 = 곡선의 오목한 쪽. 뱃전을 기어오를 때는 배 쪽, 난간 위에서는 아래,
	    난간을 넘어 내려올 때는 난간 쪽, 누운 곳에서는 갑판(아래). 말린 끝에서는 말리는 만큼 같이 돈다.
]]
local function smoothstep(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function K.restingSample(arm, count)
	local samples = K.sample(arm, nil, count)
	local n = #samples
	local curlAt = math.floor((n - 1) * (arm.curlFrom or K.RestCurlFrom)) + 1
	local lieFrom = arm.lieFrom or 1
	for index, s in ipairs(samples) do
		local floor = K.floorAt(s.p.X, s.p.Z)
		if floor then
			local rest = floor + s.r + 0.06
			local y = s.p.Y
			if index <= curlAt then
				y += (rest - y) * smoothstep((s.u - (lieFrom - 0.08)) / 0.08)
			end
			s.p = Vector3.new(s.p.X, math.max(y, rest), s.p.Z)
		end
	end

	-- 곡선이 놓인 세로 평면 (뿌리 → 난간 위 꼭대기)
	local first = samples[1].p
	local apex = 1
	for i = 2, math.floor(n * 0.7) do
		if samples[i].p.Y > samples[apex].p.Y then
			apex = i
		end
	end
	local flat = Vector3.new(samples[apex].p.X - first.X, 0, samples[apex].p.Z - first.Z)
	local normal = flat.Magnitude > 1e-3 and flat.Unit:Cross(UP).Unit or Vector3.new(0, 0, 1)
	local function tangentAt(i)
		local a = samples[math.max(i - 1, 1)].p
		local b = samples[math.min(i + 1, n)].p
		return (b - a).Magnitude > 1e-4 and (b - a).Unit or Vector3.new(0, 0, 1)
	end
	-- 꼭대기에서 빨판이 아래를 보도록 부호를 정한다
	local sign = normal:Cross(tangentAt(apex)).Y > 0 and -1 or 1
	for i = 1, n do
		local tangent = tangentAt(i)
		local planar = perpendicular(normal:Cross(tangent) * sign, tangent)
		local down = perpendicular(Vector3.new(0, -1, 0), tangent)
		local across = math.clamp((math.abs(tangent:Dot(normal)) - 0.3) / 0.4, 0, 1)
		local mixed = (planar or down or Vector3.new(0, -1, 0)):Lerp(down or planar or Vector3.new(0, -1, 0), across)
		samples[i].inner = perpendicular(mixed, tangent) or Vector3.new(0, -1, 0)
	end

	-- 끝을 위로 만다 (길이는 그대로)
	local k = curlAt
	if k >= 2 and k < n - 1 then
		local d = samples[k].p - samples[k - 1].p
		d = d.Magnitude > 1e-4 and d.Unit or Vector3.new(0, 0, 1)
		local up = perpendicular(UP, d) or Vector3.new(1, 0, 0)
		local total = 0
		local lengths = {}
		for j = k + 1, n do
			lengths[j] = (samples[j].p - samples[j - 1].p).Magnitude
			total += lengths[j]
		end
		if total > 1e-3 then
			local walked = 0
			local position = samples[k].p
			for j = k + 1, n do
				local theta = K.RestCurlAngle * ((walked + lengths[j] * 0.5) / total) ^ 1.6
				position += (d * math.cos(theta) + up * math.sin(theta)) * lengths[j]
				samples[j].p = position
				samples[j].inner = d * math.sin(theta) - up * math.cos(theta)
				walked += lengths[j]
			end
		end
	end
	return samples
end

return K
