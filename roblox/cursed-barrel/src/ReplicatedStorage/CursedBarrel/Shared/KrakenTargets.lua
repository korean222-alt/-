--[[
	KrakenTargets  (Phase 12)
	대포로 맞힐 수 있는 크라켄의 과녁과, 습격 때 갑판을 내려치는 다리의 궤적.

	★ 서버(CannonService · WorldService)와 모든 클라이언트(KrakenController · CannonController)가
	  이 모듈의 같은 식을 쓴다. 시각은 workspace:GetServerTimeNow() 로 맞춘다.
	  그래서 내 화면에서 다리의 빛나는 약점을 맞히면 서버도 맞았다고 본다.

	이 모듈은 인스턴스를 만들지 않는다. 좌표 계산만 한다. (CFrame 없이 Vector3 만 쓴다 → 검사에서도 돈다)
]]

local K = require(script.Parent.KrakenLayout)
local ShipLayout = require(script.Parent.ShipLayout)

local T = {}

T.WeakPoint = 3 -- 다리마다 바다 위로 가장 높이 솟은 점이 약점이다 (곡선이 반드시 지나는 점)
T.HeadRaidRise = 6 -- 습격 때 머리가 이만큼 더 떠오른다

local UP = Vector3.new(0, 1, 0)

local function cross(a, b)
	return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
local function dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
local function unit(v)
	local m = math.sqrt(dot(v, v))
	if m < 1e-6 then
		return Vector3.new(0, 0, 1)
	end
	return Vector3.new(v.X / m, v.Y / m, v.Z / m)
end
local function lerp(a, b, t)
	return a + (b - a) * t
end
T.unit = unit
T.dot = dot

-- 크라켄이 얼마나 날뛰는가 (KrakenLayout.waypointsAt 의 amp)
function T.agitation(phaseId, raidActive)
	if raidActive then
		return 2.2
	end
	if phaseId == "storm" then
		return 1.6
	end
	if phaseId == "night" or phaseId == "fog" then
		return 1.2
	end
	return 1
end

-- 다리 약점들 : { kind="arm", index, pos }
function T.armTargets(t, amp)
	local list = {}
	for index, arm in ipairs(K.Arms) do
		local points = K.waypointsAt(arm, t, amp)
		list[index] = { kind = "arm", index = index, pos = points[T.WeakPoint], name = arm.name }
	end
	return list
end

-- 머리의 방향 (KrakenController 의 머리와 같은 식)
function T.headBasis(t, rise)
	local spec = K.Head
	local bob = t and (math.sin(t * 0.35) * 0.7) or 0
	local center = spec.center + Vector3.new(0, bob + (rise or 0), 0)
	local look = unit(Vector3.new(spec.lookAt.X - spec.center.X, 0, spec.lookAt.Z - spec.center.Z))
	local right = unit(cross(look, UP))
	local up = cross(right, look)
	return center, look, right, up
end

-- 두 눈 : { kind="eye", index=1|2, pos }
function T.eyeTargets(t, rise)
	local spec = K.Head
	local center, look, right, up = T.headBasis(t, rise)
	local list = {}
	for index, side in ipairs({ -1, 1 }) do
		local pos = center + right * (side * spec.eyeSpread) + up * spec.eyeRise + look * spec.eyeForward
		list[index] = { kind = "eye", index = index, pos = pos }
	end
	return list
end

--------------------------------------------------
-- 내려치기 (습격)
-- slam = { id, side, z, at, windup, linger, retract, inset, blockedAt }
--------------------------------------------------

function T.slamPoints(slam)
	local half = ShipLayout.halfWidth(slam.z)
	local side = slam.side
	local hit = Vector3.new(side * (half - (slam.inset or 9)), ShipLayout.DeckY + 0.7, slam.z)
	local raised = Vector3.new(side * (half + 3), 19, slam.z + 2)
	local rail = Vector3.new(side * (half + 1), 7, slam.z + 1)
	local base = Vector3.new(side * (half + 17), K.SeaY - 6, slam.z + 7)
	return hit, raised, rail, base
end

local function easeOut(a)
	return 1 - (1 - a) * (1 - a)
end

-- 시각 t 에서 다리 끝의 자리. 아직 안 나왔거나 다 들어갔으면 nil.
-- 두 번째 값 = 지금 무엇을 하는 중인지 ("rise" · "strike" · "rest" · "retract" · "recoil")
function T.slamTip(slam, t)
	local hit, raised, rail, base = T.slamPoints(slam)
	local windup = slam.windup or 1.6
	local start = slam.at - windup
	if t < start then
		return nil, nil
	end
	local blockedAt = slam.blockedAt
	if blockedAt and t >= blockedAt then
		-- 대포에 맞아 움찔 물러났다가 바다로 빠진다
		local from = T.slamTip({ side = slam.side, z = slam.z, at = slam.at, windup = windup, linger = slam.linger, retract = slam.retract, inset = slam.inset }, blockedAt) or raised
		local out = Vector3.new(slam.side * 9, 5, 0)
		local s = t - blockedAt
		if s < 0.35 then
			return lerp(from, raised + out, easeOut(s / 0.35)), "recoil"
		elseif s < 1.25 then
			return lerp(raised + out, base, (s - 0.35) / 0.9), "recoil"
		end
		return nil, nil
	end
	local strike = 0.2
	if t < slam.at - strike then
		local a = math.clamp((t - start) / math.max(0.05, windup - strike), 0, 1)
		local wobble = Vector3.new(0, math.sin(t * 7) * 0.8, math.sin(t * 9.3) * 1.4) * a
		return lerp(base, raised, easeOut(a)) + wobble, "rise"
	elseif t < slam.at then
		local a = (t - (slam.at - strike)) / strike
		return lerp(raised, hit, a * a * a), "strike"
	end
	local linger = slam.linger or 0.9
	if t < slam.at + linger then
		return hit + Vector3.new(0, math.abs(math.sin((t - slam.at) * 6)) * 0.3, 0), "rest"
	end
	local retract = slam.retract or 1.2
	local s = t - slam.at - linger
	if s < retract then
		local a = s / retract
		-- 갑판 → 뱃전 → 바다 (2차 베지어)
		local p = lerp(lerp(hit, rail, a), lerp(rail, base, a), a)
		return p, "retract"
	end
	return nil, nil
end

-- 지금 대포로 막을 수 있는가 (치켜든 동안만)
function T.slamBlockable(slam, t)
	local start = slam.at - (slam.windup or 1.6)
	return slam.blockedAt == nil and t >= start + 0.25 and t < slam.at - 0.05
end

-- 다리의 등뼈 : 바다 속 뿌리에서 끝(tip)까지 count 개의 점. (클라이언트가 이 점들로 다리를 그린다)
function T.slamSpine(slam, tip, count)
	local hit, raised, rail, base = T.slamPoints(slam)
	local root = base + Vector3.new(slam.side * 6, -6, 4)
	-- 굽는 점 : 끝이 높을수록 위로, 갑판에 닿으면 뱃전 위로
	local bend = Vector3.new(rail.X + slam.side * 5, math.max(rail.Y + 6, tip.Y * 0.6 + 8), (rail.Z + tip.Z) * 0.5)
	local points = {}
	for i = 1, count do
		local u = (i - 1) / (count - 1)
		points[i] = lerp(lerp(root, bend, u), lerp(bend, tip, u), u)
	end
	return points
end

--------------------------------------------------
-- 포탄 판정
--------------------------------------------------

-- 광선이 공에 닿으면 닿는 거리, 아니면 nil
function T.rayDistance(origin, dir, center, radius)
	local oc = center - origin
	local proj = dot(oc, dir)
	if proj < 0 then
		return nil
	end
	local d2 = dot(oc, oc) - proj * proj
	local r2 = radius * radius
	if d2 > r2 then
		return nil
	end
	return proj - math.sqrt(r2 - d2)
end

--[[
	포탄이 무엇을 맞혔는가. 가장 가까운 것 하나.
	opts = { amp, rise, slams = {slam...}, armRadius, eyeRadius, slamRadius, range }
	돌려주는 값 : { kind = "arm"|"eye"|"slam", index, slam, point, distance } 또는 nil
]]
function T.findHit(origin, dir, t, opts)
	opts = opts or {}
	local range = opts.range or 200
	local best = nil
	local function consider(kind, index, center, radius, slam)
		local d = T.rayDistance(origin, dir, center, radius)
		if d and d <= range and (not best or d < best.distance) then
			best = { kind = kind, index = index, slam = slam, point = origin + dir * d, distance = d, center = center }
		end
	end
	for _, target in ipairs(T.armTargets(t, opts.amp)) do
		consider("arm", target.index, target.pos, opts.armRadius or 4.4)
	end
	for _, target in ipairs(T.eyeTargets(t, opts.rise)) do
		consider("eye", target.index, target.pos, opts.eyeRadius or 4.2)
	end
	for _, slam in ipairs(opts.slams or {}) do
		if T.slamBlockable(slam, t) then
			local tip = T.slamTip(slam, t)
			if tip then
				consider("slam", slam.id, tip, opts.slamRadius or 5.5, slam)
			end
		end
	end
	return best
end

-- 맞히지 못한 포탄이 떨어지는 바다 위 자리
function T.splashPoint(origin, dir, range)
	if dir.Y < -0.01 then
		local d = (K.SeaY - origin.Y) / dir.Y
		if d > 0 and d < (range or 200) then
			return origin + dir * d
		end
	end
	local p = origin + dir * (range or 200)
	return Vector3.new(p.X, K.SeaY, p.Z)
end

return T
