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

-- 굵기 : u (0 = 바다 속 뿌리, 1 = 끝)
function K.radiusAt(arm, u)
	return arm.tipRadius + (arm.baseRadius - arm.tipRadius) * (1 - u) ^ 1.25
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

return K
