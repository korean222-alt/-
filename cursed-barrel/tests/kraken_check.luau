-- 크라켄 다리가 배의 걸어 다니는 곳 · 테이블 · 소품과 겹치지 않는지 검사한다.
-- tests/run_luau.py 가 Vector3 대용품과 ShipLayout · KrakenLayout 을 붙여서 luau 로 실행한다.
local Ship = require({ __name = "ShipLayout" })
local K = require({ __name = "KrakenLayout" })

local failures = 0
local checks = 0
local function expect(ok, message)
	checks += 1
	if not ok then
		failures += 1
		print("FAIL " .. message)
	end
end

local CANNON_X = 50
local rigAnchors = {}
for _, mz in ipairs(Ship.Masts) do
	for _, side in ipairs({ -1, 1 }) do
		for _, dz in ipairs({ -16, 16 }) do
			table.insert(rigAnchors, Vector3.new(side * 52, 4, mz + dz))
		end
	end
end

local function distanceToSegment(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local times = { false, 0, 0.7, 1.9, 3.1, 4.4, 5.6, 7.3, 8.8, 10.2, 12.9, 15.5, 19.1 }
-- Phase 12 : 폭풍(1.6) · 습격(2.2) 때 더 크게 날뛰어도 배를 뚫지 않는다
for _, amp in ipairs({ 1, 1.6, 2.2 }) do
for _, arm in ipairs(K.Arms) do
	for _, quality in ipairs({ "High", "Low" }) do
		local count = K.Samples[quality]
		for _, t in ipairs(times) do
			local samples = K.sample(arm, t or nil, count, amp)
			expect(#samples == count, arm.name .. " sample count")
			local where = ("%s %s t=%s amp=%.1f"):format(arm.name, quality, tostring(t), amp)
			for index, s in ipairs(samples) do
				local p, r = s.p, s.r
				local ax = math.abs(p.X)
				local label = ("%s #%d (%.1f, %.1f, %.1f) r=%.2f"):format(where, index, p.X, p.Y, p.Z, r)
				-- 테이블 근처(의자 포함 반경 16)에는 절대 들어오지 않는다.
				for name, pos in pairs(Ship.Tables) do
					local dx, dz = p.X - pos[1], p.Z - pos[2]
					expect(math.sqrt(dx * dx + dz * dz) > 16 + r, label .. " too close to " .. name)
				end
				-- 돛대를 잡아 매는 밧줄 끝
				for _, anchor in ipairs(rigAnchors) do
					expect((p - anchor).Magnitude > r + 1, label .. " touches rigging anchor")
				end
				-- 주갑판 (선실 앞)
				if p.Z > Ship.CabinFront and p.Z < Ship.Bow then
					local half = Ship.halfWidth(p.Z)
					if ax > half - 1.2 and ax < half + 0.6 and p.Y < 12 then
						expect(p.Y - r >= K.RailTop - 0.05, label .. " cuts through the bulwark")
					end
					if ax < half - 1.2 and p.Y < 12 then
						expect(p.Y - r >= K.DeckTop - 0.2, label .. " sinks into the deck")
						expect(ax >= 49 - 0.01, label .. " reaches into the walkway (|x| < 49)")
						for _, cz in ipairs(Ship.CannonZ) do
							expect(not (math.abs(p.Z - cz) < 2.6 + r and ax > 47.3 - r), label .. " overlaps a cannon")
						end
						-- 계단 (후갑판으로 올라가는 계단)
						expect(not (p.Z < -60 and p.Z > -106 and ax > 42 - r), label .. " overlaps the stairs")
					end
				end
				-- 후갑판 (선실 지붕)
				if p.Z <= Ship.CabinFront + 0.5 and p.Z >= -159 and ax < 58 and p.Y > 5 then
					if ax > 52.4 or p.Z < -154.4 then
						expect(p.Y - r >= K.QuarterRailTop - 0.05, label .. " cuts through the quarterdeck rail")
					else
						expect(p.Y - r >= K.QuarterdeckTop - 0.2, label .. " sinks into the quarterdeck")
						expect(p.Z < -118 or ax > 44, label .. " reaches the helm area")
					end
				end
				-- 선미 판자(transom) 와 선실 뒷벽: z -158.6 ~ -154.4, 높이 20.5 까지 벽이다
				if p.Z > -158.6 and p.Z < -154.4 and ax < 53.5 then
					expect(p.Y - r >= K.QuarterRailTop - 0.05, label .. " cuts through the stern wall")
				end
				-- 뱃머리 사장
				if arm.name == "Bowsprit" then
					local d = distanceToSegment(p, Vector3.new(0, 5, 136), Vector3.new(0, 12, 177))
					expect(d >= r + 0.65 - 0.15, label .. (" pierces the bowsprit (%.2f)"):format(d))
					expect(p.Z > 150, label .. " reaches the bow deck")
				end
				-- 뿌리는 바다 속에서 시작한다
				if index == 1 then
					expect(p.Y + r < K.SeaY, label .. " root is not under water")
				end
			end
			-- 굵기는 끝으로 갈수록 가늘어진다
			for index = 2, #samples do
				expect(samples[index].r <= samples[index - 1].r + 1e-9, where .. " radius must taper")
			end
		end
	end
end
end

-- 머리는 배와 떨어져 있다
local head = K.Head
local hull = Vector3.new(-Ship.HalfBeam, head.center.Y, head.center.Z)
expect((head.center - hull).Magnitude > head.mantle / 2 + 12, "kraken head is clear of the hull")
expect(head.center.Y + head.mantle / 2 <= 16, "kraken head stays low (does not block the view)")
-- 눈은 물 위에 있고, 머리 표면 근처에 박혀 있다.
local eyeY = head.center.Y + head.eyeRise
expect(eyeY - head.eye / 2 > K.SeaY - 1.5, "kraken eyes are above the water")
local eyeDistance = math.sqrt(head.eyeSpread ^ 2 + head.eyeRise ^ 2 + head.eyeForward ^ 2)
expect(math.abs(eyeDistance - (head.mantle / 2 - 1)) < 1, ("kraken eyes sit on the head surface (%.2f)"):format(eyeDistance))

--------------------------------------------------
-- Phase 12 : 습격 때 갑판을 내려치는 다리 · 대포 과녁
--------------------------------------------------
local T = require({ __name = "KrakenTargets" })
local zones = {
	{ side = -1, z = 76 }, { side = -1, z = 23 }, { side = -1, z = -20 },
	{ side = 1, z = 74 }, { side = 1, z = 30 }, { side = 1, z = -28 },
}
for index, zone in ipairs(zones) do
	local slam = { id = index, side = zone.side, z = zone.z, at = 100, windup = 1.6, linger = 0.9, retract = 1.2, inset = 9 }
	local hit = T.slamPoints(slam)
	-- 내려치는 자리는 테이블 · 대포 · 계단 · 통로에서 떨어져 있다
	for name, pos in pairs(Ship.Tables) do
		local dx, dz = hit.X - pos[1], hit.Z - pos[2]
		expect(math.sqrt(dx * dx + dz * dz) > 16, ("slam %d lands too close to %s"):format(index, name))
	end
	for _, cz in ipairs(Ship.CannonZ) do
		expect(math.abs(hit.Z - cz) > 10, ("slam %d lands on a cannon (z %d)"):format(index, cz))
	end
	expect(not (hit.Z < -60 and hit.Z > -106), ("slam %d lands on the stairs"):format(index))
	expect(math.abs(hit.X) > 44, ("slam %d reaches into the walkway"):format(index))
	expect(math.abs(hit.Y - (Ship.DeckY + 0.7)) < 0.01, ("slam %d lands on the deck"):format(index))
	-- 시간 순서 : 나오기 전 nil → 치켜듦 → 내려침(정확히 그 자리) → 갑판 위 → 물러남 → 사라짐
	expect(T.slamTip(slam, 100 - 1.7) == nil, "slam hidden before windup")
	local tip, phase = T.slamTip(slam, 100 - 1.0)
	expect(tip ~= nil and phase == "rise" and tip.Y > 8, "slam rises")
	tip, phase = T.slamTip(slam, 100 - 0.0001)
	expect(phase == "strike" and (tip - hit).Magnitude < 0.2, "slam strikes the hit point")
	tip, phase = T.slamTip(slam, 100.4)
	expect(phase == "rest" and (tip - hit).Magnitude < 0.5, "slam rests on deck")
	tip, phase = T.slamTip(slam, 101.5)
	expect(phase == "retract", "slam retracts")
	expect(T.slamTip(slam, 103) == nil, "slam gone after retract")
	-- 등뼈 : 뿌리는 물속, 끝은 tip, 테이블과 떨어져 있다
	for _, when in ipairs({ 98.6, 99.3, 99.9, 100.4, 101.2, 102 }) do
		local t2 = T.slamTip(slam, when)
		if t2 then
			local spine = T.slamSpine(slam, t2, 14)
			expect(spine[1].Y < K.SeaY, "slam spine root under water")
			expect((spine[14] - t2).Magnitude < 1e-6, "slam spine ends at tip")
			for _, p in ipairs(spine) do
				for name, pos in pairs(Ship.Tables) do
					local dx, dz = p.X - pos[1], p.Z - pos[2]
					expect(math.sqrt(dx * dx + dz * dz) > 15, ("slam spine near %s at %.1f"):format(name, when))
				end
			end
		end
	end
	-- 막을 수 있는 때 : 치켜든 동안만
	expect(T.slamBlockable(slam, 99.0) and not T.slamBlockable(slam, 100.01) and not T.slamBlockable(slam, 98.3), "slam block window")
	local blocked = { id = index, side = zone.side, z = zone.z, at = 100, windup = 1.6, linger = 0.9, retract = 1.2, inset = 9, blockedAt = 99.2 }
	local recoil, how = T.slamTip(blocked, 99.4)
	expect(how == "recoil" and recoil.Y > 10, "blocked slam recoils")
	expect(T.slamTip(blocked, 101) == nil, "blocked slam sinks and never lands")
end

-- 대포 과녁 : 대포에서 약점을 겨누면 맞고, 하늘로 쏘면 빗나간다
for _, amp in ipairs({ 1, 2.2 }) do
	for _, target in ipairs(T.armTargets(12.3, amp)) do
		local side = target.pos.X < 0 and -1 or 1
		local best, bestDistance = nil, math.huge
		for _, cz in ipairs(Ship.CannonZ) do
			local muzzle = Vector3.new(side * 53.2, 3.2, cz)
			local d = (target.pos - muzzle).Magnitude
			if d < bestDistance then
				best, bestDistance = muzzle, d
			end
		end
		local dir = T.unit(target.pos - best)
		local hitInfo = T.findHit(best, dir, 12.3, { amp = amp })
		expect(hitInfo ~= nil, ("cannon can hit arm %d"):format(target.index))
		local up = T.findHit(best, Vector3.new(0, 1, 0), 12.3, { amp = amp })
		expect(up == nil, "shooting at the sky misses")
	end
end
for _, eye in ipairs(T.eyeTargets(5, 0)) do
	local muzzle = Vector3.new(-53.2, 3.2, -85)
	local hitInfo = T.findHit(muzzle, T.unit(eye.pos - muzzle), 5, {})
	expect(hitInfo ~= nil and hitInfo.kind == "eye" or (hitInfo and hitInfo.kind == "arm"), "port stern cannon can reach the eyes")
	expect(eye.pos.Y > K.SeaY, "eyes above water")
end
local splash = T.splashPoint(Vector3.new(53, 3, 0), T.unit(Vector3.new(1, -0.1, 0)), 200)
expect(math.abs(splash.Y - K.SeaY) < 0.01 and splash.X > 53, "missed shots splash into the sea")

print(("KRAKEN CHECKS: %d run, %d failed"):format(checks, failures))
if failures > 0 then
	error("kraken layout failed")
end
