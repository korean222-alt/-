-- 소지품 규칙 (서버·클라이언트 공용, Roblox 의존 없음).
-- items = {아이템ID = 개수}, bag = 가방 자원 {Berry = 3, ...}
local I = {}

-- 계열(창·도끼·곡괭이·횃불)에서 가진 것 중 가장 높은 등급
function I.best(items, family, config)
	local bestId, bestTier = nil, 0
	for id, spec in pairs(config.Items) do
		if spec.Family == family and (items[id] or 0) > 0 and spec.Tier > bestTier then
			bestId, bestTier = id, spec.Tier
		end
	end
	return bestId, bestId and config.Items[bestId] or nil
end

-- 가진 것 중 가장 큰 가방 용량
function I.capacity(items, config)
	local cap = config.BaseCapacity
	for id, spec in pairs(config.Items) do
		if spec.Kind == "Bag" and (items[id] or 0) > 0 then
			cap = math.max(cap, spec.Capacity)
		end
	end
	return cap
end

-- 개수: 가방에서 바로 먹는 음식(열매)은 가방 자원 수
function I.count(items, bag, id, config)
	local spec = config.Items[id]
	if spec and spec.FromBag then
		return bag and bag[id] or 0
	end
	return items[id] or 0
end

-- 화면 아래 핫바에 보일 아이템 ID 목록 (순서 고정, 최대 9칸)
function I.hotbar(items, bag, config)
	local list = {}
	for _, key in ipairs(config.Order) do
		local id
		if table.find(config.Families, key) then
			id = I.best(items, key, config)
		elseif I.count(items, bag, key, config) > 0 then
			id = key
		end
		if id then
			table.insert(list, id)
		end
		if #list >= 9 then
			break
		end
	end
	return list
end

return I
