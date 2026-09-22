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
for _, arm in ipairs(K.Arms) do
	for _, quality in ipairs({ "High", "Low" }) do
		local count = K.Samples[quality]
		for _, t in ipairs(times) do
			local samples = K.sample(arm, t or nil, count)
			expect(#samples == count, arm.name .. " sample count")
			local where = ("%s %s t=%s"):format(arm.name, quality, tostring(t))
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

print(("KRAKEN CHECKS: %d run, %d failed"):format(checks, failures))
if failures > 0 then
	error("kraken layout failed")
end
