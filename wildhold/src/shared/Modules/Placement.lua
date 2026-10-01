-- 설치 자리 검사 (서버·클라이언트 공용, Roblox 의존 없음 — 숫자만 쓴다).
-- 바닥 사각형 = {X, Z, 가로축(ax, az), 세로축(bx, bz), 반폭 hx, 반깊이 hz}. 회전은 Y 축만.
local P = {}

-- CFrame 의 RightVector/LookVector 와 바닥 크기로 사각형
function P.rect(x, z, rightX, rightZ, size, pad)
	pad = pad or 0
	local len = math.sqrt(rightX * rightX + rightZ * rightZ)
	if len < 1e-6 then rightX, rightZ, len = 1, 0, 1 end
	rightX, rightZ = rightX / len, rightZ / len
	return {X = x, Z = z, AX = rightX, AZ = rightZ, BX = -rightZ, BZ = rightX, HX = size[1] / 2 + pad, HZ = size[2] / 2 + pad}
end

local function project(r, ax, az)
	local c = r.X * ax + r.Z * az
	local e = math.abs(r.AX * ax + r.AZ * az) * r.HX + math.abs(r.BX * ax + r.BZ * az) * r.HZ
	return c - e, c + e
end

-- 두 사각형이 겹치는가 (분리축 정리)
function P.overlap(a, b)
	for _, axis in ipairs({{a.AX, a.AZ}, {a.BX, a.BZ}, {b.AX, b.AZ}, {b.BX, b.BZ}}) do
		local amin, amax = project(a, axis[1], axis[2])
		local bmin, bmax = project(b, axis[1], axis[2])
		if amax <= bmin or bmax <= amin then return false end
	end
	return true
end

-- 점이 사각형(+여유) 안인가
function P.contains(r, x, z, pad)
	pad = pad or 0
	local dx, dz = x - r.X, z - r.Z
	return math.abs(dx * r.AX + dz * r.AZ) <= r.HX + pad and math.abs(dx * r.BX + dz * r.BZ) <= r.HZ + pad
end

-- 사각형 위에서 점에 가장 가까운 곳
function P.closest(r, x, z)
	local dx, dz = x - r.X, z - r.Z
	local u = math.clamp(dx * r.AX + dz * r.AZ, -r.HX, r.HX)
	local v = math.clamp(dx * r.BX + dz * r.BZ, -r.HZ, r.HZ)
	return r.X + r.AX * u + r.BX * v, r.Z + r.AZ * u + r.BZ * v
end

-- 기지 건물·스폰·Core 자리 (여기에는 못 놓는다)
function P.blocked(map)
	local list = {P.rect(0, 0, 1, 0, {20, 20})}
	local function add(spot, size) table.insert(list, P.rect(spot[1], spot[3], 1, 0, size)) end
	add({-12, 0, 20}, {8, 8}) -- 모닥불
	add(map.Spawn, {9, 9})
	return list
end

-- 놓을 수 있는가 (안 되면 이유 = 번역 메시지). rect = 놓을 자리, others = 이미 놓인 것들의 사각형, blocked = P.blocked(...)
function P.check(rect, others, blocked, build, playerX, playerZ)
	local r = math.sqrt(rect.X * rect.X + rect.Z * rect.Z)
	if r > build.Radius then return false, {k = "build.outside", a = {r = build.Radius}} end
	if playerX and math.sqrt((rect.X - playerX) ^ 2 + (rect.Z - playerZ) ^ 2) > build.Reach then return false, {k = "build.tooFar"} end
	for _, other in ipairs(blocked) do
		if P.overlap(rect, other) then return false, {k = "build.overlapBase"} end
	end
	for _, other in ipairs(others) do
		if P.overlap(rect, other) then return false, {k = "build.overlap"} end
	end
	return true
end

return P
