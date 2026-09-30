-- Pure rules: no Roblox dependencies; executable in tests and Luau.
local Rules = {}
function Rules.canAfford(wallet, cost)
    for kind, amount in pairs(cost) do
        if type(amount) ~= "number" or amount < 0 or amount ~= amount then return false end
        if (wallet[kind] or 0) < amount then return false end
    end
    return true
end
function Rules.spend(wallet, cost)
    if not Rules.canAfford(wallet, cost) then return false end
    for kind, amount in pairs(cost) do wallet[kind] = wallet[kind] - amount end
    return true
end
-- 여러 주머니(가방 → 공용 창고 순)에서 모자람 없이 낼 수 있으면 앞 주머니부터 쓴다
function Rules.spendMany(wallets, cost)
    for kind, amount in pairs(cost) do
        if type(amount) ~= "number" or amount < 0 or amount ~= amount then return false end
        local have = 0
        for _, wallet in ipairs(wallets) do have = have + (wallet[kind] or 0) end
        if have < amount then return false end
    end
    for kind, amount in pairs(cost) do
        local left = amount
        for _, wallet in ipairs(wallets) do
            local take = math.min(left, wallet[kind] or 0)
            if take > 0 then wallet[kind] = wallet[kind] - take; left = left - take end
        end
    end
    return true
end
function Rules.total(wallet)
    local total = 0
    for _, amount in pairs(wallet) do total = total + amount end
    return total
end
function Rules.pickupAmount(wallet, amount, capacity)
    return math.max(0, math.min(amount, capacity - Rules.total(wallet)))
end
function Rules.scaledCount(base, players, factor)
    return math.floor(base * (1 + (math.max(1, players) - 1) * factor))
end
function Rules.repairCost(cost, multiplier)
    local result = {}
    for kind, amount in pairs(cost) do result[kind] = math.ceil(amount * multiplier) end
    return result
end
function Rules.upgradeHP(hp, oldMax, newMax)
    return math.min(newMax, hp + newMax - oldMax)
end
function Rules.buildQueue(wave, players, factor)
    local buckets, queue = {}, {}
    for _, entry in ipairs(wave) do
        table.insert(buckets, {Kind = entry.Kind, Boss = entry.Boss == true,
            Left = entry.Boss and entry.Count or Rules.scaledCount(entry.Count, players, factor)})
    end
    local pending = true
    while pending do
        pending = false
        for _, bucket in ipairs(buckets) do
            if bucket.Left > 0 then
                table.insert(queue, {Kind = bucket.Kind, Boss = bucket.Boss})
                bucket.Left = bucket.Left - 1
                pending = true
            end
        end
    end
    return queue
end
return Rules
