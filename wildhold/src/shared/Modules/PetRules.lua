local P = {}
function P.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k,v in pairs(value) do result[k] = P.copy(v) end; return result
end
function P.count(value) local n=0; for _ in pairs(value) do n=n+1 end; return n end
function P.element(a,b)
    local beats={Ember="Leaf",Leaf="Tide",Tide="Ember"}
    if beats[a]==b then return 1.5 elseif beats[b]==a then return 0.75 end
    return 1
end
-- 성장 단계: 1 = 새끼, 2 = 성체
function P.stage(pet)
    return pet.Stage==2 and 2 or 1
end
function P.name(speciesId,stage,config)
    local spec=config.Species[speciesId]
    return (stage==2 and spec.Adult) and spec.Adult.Name or spec.Name
end
function P.stats(pet,config)
    local spec=config.Species[pet.SpeciesId]
    local level=math.min(pet.Level,config.RegionCap)
    local scale=1+(level-1)*config.Growth
    local adult=P.stage(pet)==2 and spec.Adult
    local hp,damage=spec.HP*scale*(adult and adult.HP or 1),spec.Damage*scale*(adult and adult.Damage or 1)
    return {HP=math.floor(hp),Damage=damage,Range=spec.Range,Level=level}
end
-- 레벨이 EvolveLevel 이상이고 성체가 있는 종이면 성체로. 진화했으면 true
function P.evolve(pet,config)
    local spec=config.Species[pet.SpeciesId]
    if P.stage(pet)==1 and spec.Adult and pet.Level>=config.EvolveLevel then pet.Stage=2;return true end
    return false
end
-- trap: 덫 배율(숫자) 또는 true = 강화 덫(1.35)
function P.chance(base,hp,maxHP,trap,bait,failures,config)
    if hp/maxHP>config.CaptureHP then return 0 end
    local health=1+(1-hp/maxHP/config.CaptureHP)*0.25
    local trapMult=type(trap)=="number" and trap or (trap and 1.35 or 1)
    return math.min(config.ChanceCap,base*health*trapMult*(bait and 1.2 or 1)+failures*config.FailBonus)
end
function P.addXP(pet,amount,config)
    pet.Exp=pet.Exp+amount
    while pet.Level<config.MaxLevel and pet.Exp>=pet.Level*40 do
        pet.Exp=pet.Exp-pet.Level*40; pet.Level=pet.Level+1
    end
    if pet.Level>=config.MaxLevel then pet.Exp=0 end
    return P.evolve(pet,config)
end
function P.party(ids,pets,limit)
    if type(ids)~="table" or #ids>limit then return nil end
    local seen,result={},{}
    for _,uid in ipairs(ids) do
        if type(uid)~="string" or not pets[uid] or seen[uid] then return nil end
        seen[uid]=true; table.insert(result,uid)
    end
    return result
end
function P.canAcquire(lock,token,now)
    return lock==nil or (type(lock)=="table" and (lock.Token==token or (type(lock.Expires)=="number" and lock.Expires<=now)))
end
return P
