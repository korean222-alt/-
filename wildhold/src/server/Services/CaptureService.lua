local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local P=require(RS.Shared.Config.PetConfig)
local G=require(RS.Shared.Config.GameConfig)
local R=require(RS.Shared.Modules.PetRules)
local U=require(RS.Shared.Modules.Utility)
local I=require(RS.Shared.Config.ItemConfig)
local M=require(RS.Shared.Config.MapConfig)
local L=require(RS.Shared.Modules.Locale)
local S={}
local function attr(part,key,value) if part:GetAttribute(key)~=value then part:SetAttribute(key,value) end end
function S:Init(ctx) self.ctx,self.Wild,self.Attempts,self.Last,self.Respawns,self.HintAt=ctx,{},{},{},{},{};self.Rng=Random.new();self:Reset() end
function S:Reset()
    self.Wild,self.Attempts,self.Respawns={},{},{}
    self.ctx.Map.WildFolder:ClearAllChildren()
    if G.ActiveStage<6 then return end
    for index in ipairs(self.ctx.Map.WildSpawns) do self:SpawnWild(index) end
end
-- 맵의 야생 펫 자리(MapService.WildSpawns)에 한 마리를 둔다. 잡히면 WildRespawn 초 뒤 같은 자리에 새로 나타난다.
function S:SpawnWild(index)
    local spawn=self.ctx.Map.WildSpawns[index]
    local uid=Http:GenerateGUID(false)
    local data={SpeciesId=spawn.SpeciesId,Level=math.random(spawn.MinLevel,spawn.MaxLevel)};R.evolve(data,P)
    -- 개체 차이: 재능 별 · 빛나는 변종 · 특성 (잡으면 그대로 내 펫이 된다)
    for key,value in pairs(R.roll(P,self.Rng)) do data[key]=value end
    local stats=R.stats(data,P)
    local pos=spawn.Pos+Vector3.new(0,2,0)
    local part=U.part(self.ctx.Map.WildFolder,uid,Vector3.new(3,3,3),pos)
    part.CanCollide,part.CanTouch,part.Transparency=false,false,1
    part.CFrame=CFrame.new(pos)*CFrame.Angles(0,math.random()*math.pi*2,0)
    part:SetAttribute("SpeciesId",data.SpeciesId);part:SetAttribute("WildId",uid)
    part:SetAttribute("Level",data.Level);part:SetAttribute("MaxHP",stats.HP);part:SetAttribute("HP",stats.HP);part:SetAttribute("Stage",R.stage(data))
    part:SetAttribute("Stars",data.Stars);part:SetAttribute("Shiny",data.Shiny);part:SetAttribute("Trait",data.Trait);part:SetAttribute("Power",R.power(data,P))
    local wild={Id=uid,SpeciesId=data.SpeciesId,Level=data.Level,Stage=R.stage(data),Part=part,Home=pos,HP=stats.HP,MaxHP=stats.HP,
        Damage=stats.Damage,NextAttack=0,Failures=0,Contributors={},SpawnIndex=index,Data=data,Power=R.power(data,P)}
    self.Wild[uid]=wild
    local prompt=U.prompt(part,"Hunt",L.M("wild.hunt"),Enum.KeyCode.E,Vector3.new(0,2,0))
    wild.PromptKey="wild.hunt"
    L.tag(prompt,"ObjectText",L.C(data.Shiny and "✨" or "",R.name(data.SpeciesId,R.stage(data),P)," Lv"..data.Level.." "..R.starText(data.Stars)))
    prompt.MaxActivationDistance=P.CaptureRange
    wild.Prompt=prompt
    prompt.Triggered:Connect(function(player)
        if wild.HP/wild.MaxHP>P.CaptureHP then self.ctx.Pets:Action(player,"Focus",uid)
        else
            local items=self.ctx.Crafting.Items[player] or {}
            local trap=(items.CrystalTrap or 0)>0 and "CrystalTrap" or ((items.BetterTrap or 0)>0 and "BetterTrap" or "Trap")
            self:Attempt(player,uid,trap,trap~="Trap" and (items.Bait or 0)>0)
        end
    end)
    return wild
end
function S:CanFight(player,wild)
    return not wild.Owner or wild.Owner==player or not wild.Owner.Parent or os.clock()>(wild.ClaimUntil or 0)
        or (self.ctx.Run:IsParticipant(player) and wild.Owner and self.ctx.Run:IsParticipant(wild.Owner))
end
-- byPet = 펫이 때린 것. 사람 도구로는 HP 를 HuntFloor(60%) 아래로 못 깎는다 → 펫으로 약화시켜야 한다
-- 반환: 피해가 들어갔으면 true (도구가 더 못 깎으면 false → 공격이 옆의 나무·돌로 넘어간다)
function S:Damage(wild,amount,player,byPet)
    if self.ctx.Clock.Phase~="Day" or self.Wild[wild.Id]~=wild or wild.Busy or wild.ExhaustUntil then return false end
    if not self.ctx.Data:Ready(player) or not self:CanFight(player,wild) then return false end
    if not wild.Owner or not wild.Owner.Parent or os.clock()>(wild.ClaimUntil or 0) then wild.Owner=player end
    wild.ClaimUntil=os.clock()+45
    wild.Contributors[player]=(wild.Contributors[player] or 0)+amount
    if not byPet then
        local floor=wild.MaxHP*P.HuntFloor
        if wild.HP<=floor then
            if os.clock()>=(self.HintAt[player] or 0) then
                self.HintAt[player]=os.clock()+6
                self.ctx.Notify(player,L.M("wild.toolFloor"))
            end
            return false
        end
        amount=math.min(amount,wild.HP-floor)
    end
    wild.HP=math.max(1,wild.HP-amount) -- deliberate nonlethal hunt state
    if wild.HP/wild.MaxHP<=P.CaptureHP then wild.ExhaustUntil=os.clock()+P.ExhaustSeconds end
    return true
end
function S:Nearest(position,range)
    local best,distance=nil,range
    for _,wild in pairs(self.Wild) do
        local d=(wild.Part.Position-position).Magnitude
        if d<distance and not wild.Busy and not wild.ExhaustUntil then best,distance=wild,d end
    end
    return best
end
-- 우리 팀 전투력: 내 출전 펫 전부 + 이 야생 펫을 같이 사냥 중인 동료들의 펫
function S:TeamPower(player,wild)
    local total,counted=0,{}
    local pets=self.ctx.Pets
    for _,uid in ipairs(pets.Teams[player] or {}) do
        local rec=pets.Rosters[player][uid]
        if rec then counted[rec]=true;total=total+R.power(rec.Data,P) end
    end
    for _,rec in pairs(pets.Active) do
        if not counted[rec] and rec.Owner~=player and rec.Mode=="Focus" and rec.Target==wild.Id and rec.Part
            and (rec.Part.Position-wild.Part.Position).Magnitude<=P.HelpRange then
            total=total+R.power(rec.Data,P)
        end
    end
    return total
end
-- trap: 덫 배율(ItemConfig 의 Catch). 팀 전투력이 약하면 확률이 떨어지고, 너무 약하면 0
function S:Chance(player,wild,trap,bait)
    local profile=self.ctx.Data:Get(player)
    if P.FirstCaptureGuaranteed and profile and not profile.Tutorial.Captured and wild.SpeciesId=="Mossling" then return 1 end
    local factor=R.powerFactor(self:TeamPower(player,wild),wild.Power,P)
    return math.min(P.ChanceCap,R.chance(P.Species[wild.SpeciesId].Capture,wild.HP,wild.MaxHP,trap,bait,wild.Failures,P)*factor)
end
function S:TooStrong(player,wild)
    local profile=self.ctx.Data:Get(player)
    if P.FirstCaptureGuaranteed and profile and not profile.Tutorial.Captured and wild.SpeciesId=="Mossling" then return false end
    return R.powerFactor(self:TeamPower(player,wild),wild.Power,P)==0
end
-- 덫을 들고 공격 버튼: 가장 가까운 "지친" 야생 펫에게 던진다. 강화·수정 덫은 먹이가 있으면 같이 쓴다.
function S:Throw(player,trap)
    local spec=I.Items[trap];if not spec or spec.Kind~="Trap" then return end
    local root=U.aliveRoot(player);if not root then return end
    local best,distance,weak=nil,P.CaptureRange,nil
    for _,wild in pairs(self.Wild) do
        local d=(wild.Part.Position-root.Position).Magnitude
        if d<=P.CaptureRange and not wild.Busy then
            if wild.HP/wild.MaxHP<=P.CaptureHP then if d<distance then best,distance=wild,d end else weak=wild end
        end
    end
    if not best then
        self.ctx.Notify(player,L.M(weak and "wild.weakenFirst" or "wild.noneTired"))
        return
    end
    local items=self.ctx.Crafting.Items[player]
    self:Attempt(player,best.Id,trap,spec.Better==true and items~=nil and (items.Bait or 0)>0)
end
function S:Attempt(player,uid,trap,bait)
    if G.ActiveStage<6 or type(uid)~="string" or type(trap)~="string" or type(bait)~="boolean" then return end
    local trapSpec=I.Items[trap];if not trapSpec or trapSpec.Kind~="Trap" then return end
    if not self.ctx.Data:Ready(player) or not self.ctx.Run:IsParticipant(player) or self.ctx.Clock.Phase~="Day" then return end
    if os.clock()-(self.Last[player] or -100)<0.5 then return end;self.Last[player]=os.clock()
    if self.Attempts[player] then return end
    local wild=self.Wild[uid]
    if not wild or wild.Busy or wild.HP/wild.MaxHP>P.CaptureHP or not U.near(player,wild.Part.Position,P.CaptureRange) then return end
    -- First contributor has capture priority. Teammates may assist without stealing.
    if wild.Owner and wild.Owner~=player and wild.Owner.Parent and os.clock()<(wild.ClaimUntil or 0) then
        self.ctx.Notify(player,L.M("wild.claimed"));return
    end
    if not self.ctx.Pets:CanCapture(player) then self.ctx.Notify(player,L.M("wild.full"));return end
    if self:TooStrong(player,wild) then
        self.ctx.Notify(player,L.M("wild.tooStrong",{team=math.floor(self:TeamPower(player,wild)),wild=math.floor(wild.Power)}))
        return
    end
    local items=self.ctx.Crafting.Items[player]
    if not items or (items[trap] or 0)<=0 or (bait and (items.Bait or 0)<=0) then self.ctx.Notify(player,L.M("wild.noTrap"));return end
    self.ctx.Crafting:Use(player,trap);if bait then self.ctx.Crafting:Use(player,"Bait") end
    wild.Busy=player
    self.Attempts[player]={Wild=wild,EndsAt=os.clock()+P.CaptureSeconds,Chance=self:Chance(player,wild,trapSpec.Catch or 1,bait)}
    self.ctx.PetFX:FireClient(player,"Shake",R.name(wild.SpeciesId,wild.Stage,P),P.CaptureSeconds)
    self.ctx.FX:FireAllClients("TrapStart",wild.Part.Position,P.CaptureSeconds,trapSpec.Better==true,wild.Id)
end
function S:Finish(player,attempt)
    local wild=attempt.Wild
    self.Attempts[player]=nil;wild.Busy=nil
    if self.Wild[wild.Id]~=wild then return end
    if not self.ctx.Data:Ready(player) or self.ctx.Clock.Phase~="Day" or not U.near(player,wild.Part.Position,P.CaptureRange) then
        if player.Parent then self.ctx.Notify(player,L.M("wild.interrupted")) end;return
    end
    if math.random()<attempt.Chance and self.ctx.Pets:AddCapture(player,wild) then
        self.ctx.FX:FireAllClients("TrapResult",wild.Part.Position,true,wild.SpeciesId,wild.Id)
        self.Wild[wild.Id]=nil;wild.Part:Destroy()
        if wild.SpawnIndex then self.Respawns[wild.SpawnIndex]=os.clock()+M.WildRespawn end
        for helper in pairs(wild.Contributors) do if helper~=player then self.ctx.Pets:Award(helper,P.CaptureXP) end end
        self.ctx.Notify(player,L.M("wild.caught"))
        self.ctx.PetFX:FireClient(player,"Capture",R.name(wild.SpeciesId,wild.Stage,P))
    else
        self.ctx.FX:FireAllClients("TrapResult",wild.Part.Position,false,wild.SpeciesId,wild.Id)
        wild.Failures=wild.Failures+1;wild.ExhaustUntil=os.clock()+P.ExhaustSeconds
        self.ctx.Notify(player,L.M("wild.escaped"))
        self.ctx.PetFX:FireClient(player,"Fail")
    end
end
function S:RemovePlayer(player)
    local attempt=self.Attempts[player]
    if attempt then attempt.Wild.Busy=nil end
    self.Attempts[player],self.Last[player],self.HintAt[player]=nil,nil,nil
    for _,wild in pairs(self.Wild) do wild.Contributors[player]=nil;if wild.Owner==player then wild.Owner=nil end end
end
function S:Tick(dt)
    if G.ActiveStage<6 then return end
    for player,attempt in pairs(self.Attempts) do if os.clock()>=attempt.EndsAt then self:Finish(player,attempt) end end
    if self.ctx.Clock.Phase=="Day" then
        for index,at in pairs(self.Respawns) do
            if os.clock()>=at then self.Respawns[index]=nil;self:SpawnWild(index) end
        end
    end
    for _,wild in pairs(self.Wild) do
        local spec=P.Species[wild.SpeciesId]
        if wild.ExhaustUntil and not wild.Busy and os.clock()>wild.ExhaustUntil then
            wild.ExhaustUntil,wild.Owner,wild.Failures,wild.Contributors=nil,nil,0,{};wild.HP=wild.MaxHP
            wild.Part.Position=wild.Home
        end
        if self.ctx.Clock.Phase=="Day" and wild.Owner and not wild.ExhaustUntil and not wild.Busy then
            local pet=self.ctx.Pets:Nearest(wild.Part.Position,18)
            local root,human=U.aliveRoot(wild.Owner)
            local target=pet and pet.Part or root
            if target and (target.Position-wild.Home).Magnitude<32 then
                local delta=U.flat(target.Position-wild.Part.Position)
                if delta.Magnitude>6 then
                    local nextPos=wild.Part.Position+delta.Unit*math.min(delta.Magnitude,10*dt)
                    wild.Part.CFrame=CFrame.lookAt(nextPos,nextPos+delta.Unit)
                elseif os.clock()>=wild.NextAttack then
                    wild.NextAttack=os.clock()+1.4;wild.Part:SetAttribute("AttackAt",workspace:GetServerTimeNow())
                    local here=wild.Part.Position
                    wild.Part.CFrame=CFrame.lookAt(here,Vector3.new(target.Position.X,here.Y,target.Position.Z))
                    if pet then self.ctx.Pets:Damage(pet,wild.Damage*R.element(spec.Element,P.Species[pet.Data.SpeciesId].Element))
                    elseif human then human:TakeDamage(wild.Damage) end
                end
            else
                wild.Owner,wild.ExhaustUntil,wild.Contributors=nil,nil,{};wild.HP=wild.MaxHP;wild.Part.Position=wild.Home
            end
        end
        attr(wild.Part,"Exhausted",wild.ExhaustUntil~=nil)
        attr(wild.Part,"HP",math.ceil(wild.HP));attr(wild.Part,"Busy",wild.Busy~=nil)
        attr(wild.Part,"Hunter",wild.Owner and wild.Owner.DisplayName or "")
        local ready=wild.HP/wild.MaxHP<=P.CaptureHP
        local key=wild.Busy and "wild.capturing" or (ready and "wild.throwTrap" or "wild.hunt")
        if wild.PromptKey~=key then wild.PromptKey=key;L.tag(wild.Prompt,"ActionText",L.M(key)) end
        wild.Prompt.Enabled=self.ctx.Clock.Phase=="Day" and not wild.Busy
    end
end
function S:Snapshot(player)
    local list={};local root=U.aliveRoot(player);if not root then return list end
    for uid,wild in pairs(self.Wild) do
        local distance=(root.Position-wild.Part.Position).Magnitude
        if distance<90 then
            list[#list+1]={Id=uid,SpeciesId=wild.SpeciesId,Stage=wild.Stage,Level=wild.Level,HP=math.ceil(wild.HP),MaxHP=wild.MaxHP,
                Distance=math.floor(distance),Chance=self:Chance(player,wild,1,false),BetterChance=self:Chance(player,wild,I.Items.BetterTrap.Catch,true),
                Ready=wild.HP/wild.MaxHP<=P.CaptureHP,Busy=wild.Busy~=nil,Stars=wild.Data.Stars,Shiny=wild.Data.Shiny,Trait=wild.Data.Trait,
                Power=wild.Power,TeamPower=self:TeamPower(player,wild),Owner=wild.Owner and wild.Owner.DisplayName or "",CanClaim=not wild.Owner or wild.Owner==player or os.clock()>(wild.ClaimUntil or 0)}
        end
    end
    table.sort(list,function(a,b) return a.Distance<b.Distance end);return list
end
return S
