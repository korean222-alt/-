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
-- 이름표에 보이는 이름: 지어 준 이름이 있으면 그것
function P.display(pet,config)
    if type(pet.Nickname)=="string" and pet.Nickname~="" then return pet.Nickname end
    return P.name(pet.SpeciesId,P.stage(pet),config)
end
function P.starText(stars)
    stars=stars or 2
    return string.rep("★",stars)..string.rep("☆",5-stars)
end
-- 재능 별 · 특성 · 레벨 · 성장 단계가 모두 들어간 능력치. 예전 저장(별 없음)은 별 2개(배율 1)로 본다
function P.stats(pet,config)
    local spec=config.Species[pet.SpeciesId]
    local level=math.min(pet.Level,config.RegionCap)
    local scale=1+(level-1)*config.Growth
    local adult=P.stage(pet)==2 and spec.Adult
    local star=config.Stars and config.Stars.Mult[pet.Stars or 2] or 1
    local trait=config.Traits and config.Traits[pet.Trait] or {}
    local hp=spec.HP*scale*(adult and adult.HP or 1)*star*(trait.HP or 1)
    local damage=spec.Damage*scale*(adult and adult.Damage or 1)*star*(trait.Damage or 1)
    return {HP=math.floor(hp),Damage=damage,Range=spec.Range,Level=level,Interval=spec.Interval*(trait.Interval or 1)}
end
-- 전투력: 버티는 힘(체력) + 때리는 힘(초당 피해). 포획 조건과 화면 표시에 쓴다
function P.power(pet,config)
    local stats=P.stats(pet,config)
    return math.floor(stats.HP*0.25+stats.Damage/stats.Interval*2+0.5)
end
-- 우리 팀 전투력 / 야생 전투력 → 포획 확률 배율 (0 = 너무 강해서 불가)
function P.powerFactor(team,wild,config)
    if wild<=0 then return 1 end
    local ratio=team/wild
    if ratio<config.PowerGate then return 0 end
    return math.clamp(ratio^config.PowerExponent,config.PowerMin,config.PowerMax)
end
-- 개체 차이 굴리기 (야생 등장 · 알 부화). opts = {Weights, ShinyChance, MinStars}
function P.roll(config,rng,opts)
    opts=opts or {}
    local weights=opts.Weights or config.Stars.Weights
    local total=0;for _,w in ipairs(weights) do total=total+w end
    local pick,stars=rng:NextNumber()*total,#weights
    for i,w in ipairs(weights) do pick=pick-w;if pick<=0 then stars=i;break end end
    stars=math.max(stars,opts.MinStars or 1)
    return {Stars=stars,Shiny=rng:NextNumber()<(opts.ShinyChance or config.ShinyChance),Trait=config.TraitOrder[rng:NextInteger(1,#config.TraitOrder)]}
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
    local trait=config.Traits and config.Traits[pet.Trait]
    pet.Exp=pet.Exp+math.floor(amount*(trait and trait.XP or 1)+0.5)
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
