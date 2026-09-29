-- 위치 → 지역 (MapConfig.Zones). 서버(맵 생성·야생 레벨)와 클라이언트(지역 이름 표시)가 같이 쓴다.
local Z = {}

-- 북(-Z) = 0°, 시계 방향. MapConfig 의 dir = (sin a, 0, -cos a) 와 같은 기준
function Z.angle(pos)
	return math.deg(math.atan2(pos.X, -pos.Z)) % 360
end

local function gap(a, b)
	return math.abs((a - b + 180) % 360 - 180)
end

function Z.id(pos, config)
	local r = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
	if r < config.MeadowRadius then
		return "Meadow"
	end
	local a, best, bestGap = Z.angle(pos), "Meadow", math.huge
	for id, zone in pairs(config.Zones) do
		if zone.Angle and gap(a, zone.Angle) < bestGap then
			best, bestGap = id, gap(a, zone.Angle)
		end
	end
	return best
end

-- 지역 부채꼴 안의 한 점 (t: 0~1 반지름 비율, s: -1~1 각도 비율)
function Z.point(id, t, s, config, margin)
	local zone = config.Zones[id]
	margin = margin or 0
	local minR, maxR = config.MeadowRadius + margin, config.PlayRadius - margin
	local r = minR + (maxR - minR) * t
	local a = math.rad(zone.Angle + s * (58 - margin * 0.02))
	return Vector3.new(math.sin(a) * r, 0, -math.cos(a) * r)
end

-- 기지에서 멀수록 1 에 가까워진다 (0 = 초원 끝)
function Z.depth(pos, config)
	local r = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
	return math.clamp((r - config.MeadowRadius) / (config.PlayRadius - config.MeadowRadius), 0, 1)
end

return Z
