-- 알 규칙 (서버·클라이언트 공용, Roblox 의존 없음)
local E = {}

-- 가중치 목록에서 하나
function E.pick(pool, rng)
	local total = 0
	for _, entry in ipairs(pool) do total = total + entry[2] end
	local roll = rng:NextNumber() * total
	for _, entry in ipairs(pool) do
		roll = roll - entry[2]
		if roll <= 0 then return entry[1] end
	end
	return pool[#pool][1]
end

-- 부화: 새 펫 데이터 (Uid 는 부르는 쪽이 넣는다)
function E.hatch(kind, rng, eggConfig, petConfig, petRules)
	local spec = eggConfig.Kinds[kind]
	local pet = {SpeciesId = E.pick(spec.Pool, rng), Level = spec.Level, Exp = 0, Stage = 1, HatchedFrom = kind}
	for key, value in pairs(petRules.roll(petConfig, rng, {Weights = spec.Stars, MinStars = spec.MinStars, ShinyChance = spec.ShinyChance})) do
		pet[key] = value
	end
	return pet
end

-- 부화장에 들어 있는 알 수
function E.incubating(eggs)
	local n = 0
	for _, egg in pairs(eggs) do
		if egg.HatchAt then n = n + 1 end
	end
	return n
end

-- 원정 결과 → 받을 알 종류 (없으면 nil)
function E.reward(won, nights, eggConfig)
	if won then return "Rare" end
	if nights >= eggConfig.CommonNights then return "Common" end
	return nil
end

return E
