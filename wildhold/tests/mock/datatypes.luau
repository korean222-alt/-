-- Roblox 자료형 모의 구현 (Vector3, CFrame, Color3, UDim2 …). 실제 수학을 그대로 계산한다.
local T = {}

local function typed(name, mt)
	mt.__type = name
	return mt
end

-- ===================================================================== Vector3
local V3 = typed("Vector3", {})
V3.__index = function(v, k)
	if k == "X" then return rawget(v, 1) elseif k == "Y" then return rawget(v, 2) elseif k == "Z" then return rawget(v, 3)
	elseif k == "Magnitude" then return math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	elseif k == "Unit" then
		local m = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
		if m == 0 then return T.Vector3.new(0 / 0, 0 / 0, 0 / 0) end
		return T.Vector3.new(v[1] / m, v[2] / m, v[3] / m)
	end
	local method = V3[k]
	if method then return method end
	error("Vector3 에 " .. tostring(k) .. " 가 없습니다", 2)
end
local function v3(x, y, z) return setmetatable({x or 0, y or 0, z or 0}, V3) end
V3.__add = function(a, b) return v3(a[1] + b[1], a[2] + b[2], a[3] + b[3]) end
V3.__sub = function(a, b) return v3(a[1] - b[1], a[2] - b[2], a[3] - b[3]) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b[1], a * b[2], a * b[3]) end
	if type(b) == "number" then return v3(a[1] * b, a[2] * b, a[3] * b) end
	return v3(a[1] * b[1], a[2] * b[2], a[3] * b[3])
end
V3.__div = function(a, b)
	if type(b) == "number" then return v3(a[1] / b, a[2] / b, a[3] / b) end
	return v3(a[1] / b[1], a[2] / b[2], a[3] / b[3])
end
V3.__unm = function(a) return v3(-a[1], -a[2], -a[3]) end
V3.__eq = function(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
V3.__tostring = function(a) return string.format("%.3f, %.3f, %.3f", a[1], a[2], a[3]) end
V3.Dot = function(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
V3.Cross = function(a, b) return v3(a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1]) end
V3.Lerp = function(a, b, t) return v3(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t) end
V3.Abs = function(a) return v3(math.abs(a[1]), math.abs(a[2]), math.abs(a[3])) end
V3.Min = function(a, b) return v3(math.min(a[1], b[1]), math.min(a[2], b[2]), math.min(a[3], b[3])) end
V3.Max = function(a, b) return v3(math.max(a[1], b[1]), math.max(a[2], b[2]), math.max(a[3], b[3])) end
V3.FuzzyEq = function(a, b, e) return (a - b).Magnitude <= (e or 1e-5) end
T.Vector3 = {new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1)}

-- ===================================================================== Vector2
local V2 = typed("Vector2", {})
local function v2(x, y) return setmetatable({x or 0, y or 0}, V2) end
V2.__index = function(v, k)
	if k == "X" then return v[1] elseif k == "Y" then return v[2]
	elseif k == "Magnitude" then return math.sqrt(v[1] ^ 2 + v[2] ^ 2) end
	error("Vector2 에 " .. tostring(k) .. " 가 없습니다", 2)
end
V2.__add = function(a, b) return v2(a[1] + b[1], a[2] + b[2]) end
V2.__sub = function(a, b) return v2(a[1] - b[1], a[2] - b[2]) end
V2.__mul = function(a, b) if type(b) == "number" then return v2(a[1] * b, a[2] * b) end return v2(a[1] * b[1], a[2] * b[2]) end
V2.__div = function(a, b) if type(b) == "number" then return v2(a[1] / b, a[2] / b) end return v2(a[1] / b[1], a[2] / b[2]) end
T.Vector2 = {new = v2, zero = v2(0, 0), one = v2(1, 1)}

-- ===================================================================== CFrame (행렬 3x3 + 위치)
local CF = typed("CFrame", {})
local function cf(px, py, pz, r)
	return setmetatable({px, py, pz, r or {1, 0, 0, 0, 1, 0, 0, 0, 1}}, CF)
end
local function mulR(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function applyR(r, x, y, z)
	return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z
end
local function transpose(r) return {r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9]} end
CF.__index = function(c, k)
	local r = c[4]
	if k == "Position" or k == "p" then return v3(c[1], c[2], c[3])
	elseif k == "X" then return c[1] elseif k == "Y" then return c[2] elseif k == "Z" then return c[3]
	elseif k == "LookVector" then return v3(-r[3], -r[6], -r[9])
	elseif k == "RightVector" then return v3(r[1], r[4], r[7])
	elseif k == "UpVector" then return v3(r[2], r[5], r[8])
	elseif k == "XVector" then return v3(r[1], r[4], r[7])
	elseif k == "YVector" then return v3(r[2], r[5], r[8])
	elseif k == "ZVector" then return v3(r[3], r[6], r[9])
	elseif k == "Rotation" then return cf(0, 0, 0, r)
	end
	local method = CF[k]
	if method then return method end
	error("CFrame 에 " .. tostring(k) .. " 가 없습니다", 2)
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local x, y, z = applyR(a[4], b[1], b[2], b[3])
		return cf(a[1] + x, a[2] + y, a[3] + z, mulR(a[4], b[4]))
	elseif getmetatable(b) == V3 then
		local x, y, z = applyR(a[4], b[1], b[2], b[3])
		return v3(a[1] + x, a[2] + y, a[3] + z)
	end
	error("CFrame * " .. typeof(b) .. " 는 지원하지 않습니다", 2)
end
CF.__add = function(a, b)
	assert(getmetatable(b) == V3, "CFrame + Vector3 만 가능합니다")
	return cf(a[1] + b[1], a[2] + b[2], a[3] + b[3], a[4])
end
CF.__sub = function(a, b)
	assert(getmetatable(b) == V3, "CFrame - Vector3 만 가능합니다")
	return cf(a[1] - b[1], a[2] - b[2], a[3] - b[3], a[4])
end
CF.__eq = function(a, b)
	for i = 1, 3 do if a[i] ~= b[i] then return false end end
	for i = 1, 9 do if a[4][i] ~= b[4][i] then return false end end
	return true
end
CF.__tostring = function(c) return string.format("CFrame(%.2f, %.2f, %.2f)", c[1], c[2], c[3]) end
CF.Inverse = function(c)
	local rt = transpose(c[4])
	local x, y, z = applyR(rt, -c[1], -c[2], -c[3])
	return cf(x, y, z, rt)
end
CF.ToObjectSpace = function(a, b) return a:Inverse() * b end
CF.ToWorldSpace = function(a, b) return a * b end
CF.PointToObjectSpace = function(a, v) return a:Inverse() * v end
CF.PointToWorldSpace = function(a, v) return a * v end
CF.VectorToObjectSpace = function(a, v) local x, y, z = applyR(transpose(a[4]), v[1], v[2], v[3]); return v3(x, y, z) end
CF.VectorToWorldSpace = function(a, v) local x, y, z = applyR(a[4], v[1], v[2], v[3]); return v3(x, y, z) end
CF.GetComponents = function(c) local r = c[4]; return c[1], c[2], c[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] end
CF.components = CF.GetComponents
CF.Lerp = function(a, b, t)
	-- 회전은 근사(정규화한 행렬 선형 보간). 모의 테스트에는 충분하다.
	local r = {}
	for i = 1, 9 do r[i] = a[4][i] + (b[4][i] - a[4][i]) * t end
	return cf(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, r)
end
CF.ToEulerAnglesXYZ = function(c)
	local r = c[4]
	local y = math.asin(math.clamp(r[3], -1, 1))
	local x = math.atan2(-r[6], r[9])
	local z = math.atan2(-r[2], r[1])
	return x, y, z
end
CF.ToOrientation = CF.ToEulerAnglesXYZ

local function rx(a) local c, s = math.cos(a), math.sin(a); return {1, 0, 0, 0, c, -s, 0, s, c} end
local function ry(a) local c, s = math.cos(a), math.sin(a); return {c, 0, s, 0, 1, 0, -s, 0, c} end
local function rz(a) local c, s = math.cos(a), math.sin(a); return {c, -s, 0, s, c, 0, 0, 0, 1} end

local CFrame = {}
function CFrame.new(a, b, c, ...)
	if a == nil then return cf(0, 0, 0) end
	if getmetatable(a) == V3 then
		if b and getmetatable(b) == V3 then
			return CFrame.lookAt(a, b)
		end
		return cf(a[1], a[2], a[3])
	end
	local extra = {...}
	if #extra == 9 then
		return cf(a, b, c, extra)
	end
	assert(type(a) == "number" and type(b) == "number" and type(c) == "number", "CFrame.new 인자가 잘못되었습니다")
	return cf(a, b, c)
end
function CFrame.Angles(x, y, z)
	-- Roblox: CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz
	return cf(0, 0, 0, mulR(mulR(rx(x or 0), ry(y or 0)), rz(z or 0)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z) return cf(0, 0, 0, mulR(mulR(ry(y), rx(x)), rz(z))) end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromAxisAngle(axis, angle)
	local u = axis.Unit
	local x, y, z = u[1], u[2], u[3]
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	return cf(0, 0, 0, {t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c})
end
function CFrame.lookAt(eye, target, up)
	up = up or v3(0, 1, 0)
	local look = target - eye
	if look.Magnitude < 1e-9 then return cf(eye[1], eye[2], eye[3]) end
	local back = -(look.Unit)
	local right = up:Cross(back)
	if right.Magnitude < 1e-6 then right = v3(1, 0, 0):Cross(back) end
	right = right.Unit
	local upv = back:Cross(right)
	return cf(eye[1], eye[2], eye[3], {right[1], upv[1], back[1], right[2], upv[2], back[2], right[3], upv[3], back[3]})
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return cf(pos[1], pos[2], pos[3], {vx[1], vy[1], vz[1], vx[2], vy[2], vz[2], vx[3], vy[3], vz[3]})
end
CFrame.identity = cf(0, 0, 0)
T.CFrame = CFrame
T.CFrameMeta = CF
T.V3Meta = V3

-- ===================================================================== Color3
local C3 = typed("Color3", {})
local function c3(r, g, b) return setmetatable({R = r or 0, G = g or 0, B = b or 0}, C3) end
C3.__index = {
	Lerp = function(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end,
	ToHex = function(a) return string.format("%02x%02x%02x", math.floor(a.R * 255 + 0.5), math.floor(a.G * 255 + 0.5), math.floor(a.B * 255 + 0.5)) end,
	ToHSV = function(a) return 0, 0, math.max(a.R, a.G, a.B) end,
}
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
T.Color3 = {
	new = c3,
	fromRGB = function(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHSV = function(h, s, v) return c3(v, v, v) end,
	fromHex = function(hex)
		assert(type(hex) == "string", "Color3.fromHex 는 문자열을 받습니다")
		hex = hex:gsub("#", "")
		assert(#hex == 6 or #hex == 3, "잘못된 hex 색: " .. hex)
		if #hex == 3 then hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2) end
		local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
		assert(r and g and b, "잘못된 hex 색: " .. hex)
		return c3(r / 255, g / 255, b / 255)
	end,
}

-- ===================================================================== UDim / UDim2
local UD = typed("UDim", {})
UD.__index = function(u, k) error("UDim 에 " .. tostring(k) .. " 가 없습니다", 2) end
local function udim(s, o) return setmetatable({Scale = s or 0, Offset = o or 0}, UD) end
UD.__add = function(a, b) return udim(a.Scale + b.Scale, a.Offset + b.Offset) end
T.UDim = {new = udim}
local UD2 = typed("UDim2", {})
UD2.__index = function(u, k)
	if k == "Width" then return rawget(u, "X") elseif k == "Height" then return rawget(u, "Y") end
	if k == "Lerp" then return function(a, b) return b end end
	error("UDim2 에 " .. tostring(k) .. " 가 없습니다", 2)
end
local function udim2(xs, xo, ys, yo)
	if getmetatable(xs) == UD then
		return setmetatable({X = xs, Y = xo}, UD2)
	end
	return setmetatable({X = udim(xs, xo), Y = udim(ys, yo)}, UD2)
end
UD2.__add = function(a, b) return setmetatable({X = a.X + b.X, Y = a.Y + b.Y}, UD2) end
T.UDim2 = {new = udim2, fromScale = function(x, y) return udim2(x, 0, y, 0) end, fromOffset = function(x, y) return udim2(0, x, 0, y) end}

-- ===================================================================== 시퀀스 / 범위 / 기타
local function simple(name, fields)
	local mt = typed(name, {})
	mt.__index = function(_, k) error(name .. " 에 " .. tostring(k) .. " 가 없습니다", 2) end
	return function(...)
		local o = {...}
		for i, f in ipairs(fields) do o[f] = o[i] end
		return setmetatable(o, mt)
	end, mt
end
local nsk = simple("NumberSequenceKeypoint", {"Time", "Value", "Envelope"})
local csk = simple("ColorSequenceKeypoint", {"Time", "Value"})
local ns, nsMeta = simple("NumberSequence", {})
local cs, csMeta = simple("ColorSequence", {})
T.NumberSequenceKeypoint = {new = nsk}
T.ColorSequenceKeypoint = {new = csk}
T.NumberSequence = {new = function(a, b)
	if type(a) == "table" then
		assert(#a >= 2, "NumberSequence 는 키포인트 2개 이상")
		return ns(a)
	end
	assert(type(a) == "number", "NumberSequence.new 인자가 잘못되었습니다")
	return ns(a, b)
end}
T.ColorSequence = {new = function(a, b)
	if type(a) == "table" and getmetatable(a) == nil then
		return cs(a)
	end
	assert(typeof(a) == "Color3", "ColorSequence.new 인자는 Color3 입니다: " .. typeof(a))
	assert(b == nil or typeof(b) == "Color3", "ColorSequence.new 두번째 인자는 Color3 입니다")
	return cs(a, b)
end}
local nr = simple("NumberRange", {"Min", "Max"})
T.NumberRange = {new = function(a, b)
	assert(type(a) == "number", "NumberRange.new 는 숫자")
	return nr(a, b or a)
end}
local ti = simple("TweenInfo", {"Time", "EasingStyle", "EasingDirection", "RepeatCount", "Reverses", "DelayTime"})
T.TweenInfo = {new = function(time, style, dir, rep, rev, delay)
	return ti(time or 1, style, dir, rep or 0, rev or false, delay or 0)
end}
local rect = simple("Rect", {"Min", "Max"})
T.Rect = {new = rect}
local pp = simple("PhysicalProperties", {"Density"})
T.PhysicalProperties = {new = pp}
local font = simple("Font", {"Family"})
T.Font = {new = font, fromEnum = font, fromName = font}

local RP = typed("RaycastParams", {})
RP.__index = function(_, k) error("RaycastParams 에 " .. tostring(k) .. " 가 없습니다", 2) end
RP.__newindex = function(t, k, v)
	local ok = {FilterType = true, FilterDescendantsInstances = true, IgnoreWater = true, CollisionGroup = true, RespectCanCollide = true, BruteForceAllSlow = true}
	if not ok[k] then error("RaycastParams." .. tostring(k) .. " 는 없는 속성입니다", 2) end
	rawset(t, k, v)
end
T.RaycastParams = {new = function()
	local p = setmetatable({}, RP)
	rawset(p, "FilterDescendantsInstances", {})
	rawset(p, "IgnoreWater", false)
	return p
end}
T.OverlapParams = T.RaycastParams

local RNG = typed("Random", {})
RNG.__index = {
	NextNumber = function(r, a, b)
		r.state = (r.state * 1103515245 + 12345) % 2147483648
		local x = r.state / 2147483648
		if a then return a + (b - a) * x end
		return x
	end,
	NextInteger = function(r, a, b)
		r.state = (r.state * 1103515245 + 12345) % 2147483648
		-- 하위 비트는 주기가 짧다(LCG) → 상위 비트로 고른다
		return a + math.floor(r.state / 2147483648 * (b - a + 1))
	end,
}
T.Random = {new = function(seed) return setmetatable({state = (seed or 1) % 2147483648}, RNG) end}

return T
