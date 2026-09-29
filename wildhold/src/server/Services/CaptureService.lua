local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local P=require(RS.Shared.Config.PetConfig)
local G=require(RS.Shared.Config.GameConfig)
local R=require(RS.Shared.Modules.PetRules)
local U=require(RS.Shared.Modules.Utility)
local I=require(RS.Shared.Config.ItemConfig)
local S={}
local function attr(part,key,value) if part:GetAttribute(key)~=value then part:SetAttribute(key,value) end end
function S:Init(ctx) self.ctx,self.Wild,self.Attempts,self.Last=ctx,{},{},{};self:Reset() end
function S:Reset()
    self.Wild,self.Attempts={},{}
    self.ctx.Map.WildFolder:ClearAllChildren()
    if G.ActiveStage<6 then return end
    for _,spawn in ipairs(P.Spawns) do
        local uid=Http:GenerateGUID(false)
        local data={SpeciesId=spawn[1],Level=spawn[2]};local stats=R.stats(data,P)
        local pos=Vector3.new(spawn[3],2,spawn[4])
        local part=U.part(self.ctx.Map.WildFolder,uid,Vector3.new(3,3,3),pos)
        part.CanCollide,part.CanTouch,part.Transparency=false,false,1
        part.CFrame=CFrame.new(pos)*CFrame.Angles(0,math.random()*math.pi*2,0)
        part:SetAttribute("SpeciesId",data.SpeciesId);part:SetAttribute("WildId",uid)
        part:SetAttribute("Level",data.Level);part:SetAttribute("MaxHP",stats.HP);part:SetAttribute("HP",stats.HP)
        local wild={Id=uid,SpeciesId=data.SpeciesId,Level=data.Level,Part=part,Home=pos,HP=stats.HP,MaxHP=stats.HP,
            Damage=stats.Damage,NextAttack=0,Failures=0,Contributors={}}
        self.Wild[uid]=wild
        local prompt=U.prompt(part,"Hunt","펫들과 사냥 시작",Enum.KeyCode.E,Vector3.new(0,2,0))
        prompt.ObjectText=P.Species[data.SpeciesId].Name.." Lv"..data.Level
        prompt.MaxActivationDistance=P.CaptureRange
        wild.Prompt=prompt
        prompt.Triggered:Connect(function(player)
            if wild.HP/wild.MaxHP>P.CaptureHP then self.ctx.Pets:Action(player,"Focus",uid)
            else self:Attempt(player,uid,"Trap",false) end
        end)
    end
end
function S:CanFight(player,wild)
    return not wild.Owner or wild.Owner==player or not wild.Owner.Parent or os.clock()>(wild.ClaimUntil or 0)
        or (self.ctx.Run:IsParticipant(player) and wild.Owner and self.ctx.Run:IsParticipant(wild.Owner))
end
function S:Damage(wild,amount,player)
    if self.ctx.Clock.Phase~="Day" or self.Wild[wild.Id]~=wild or wild.Busy or wild.ExhaustUntil then return end
    if not self.ctx.Data:Ready(player) or not self:CanFight(player,wild) then return end
    if not wild.Owner or not wild.Owner.Parent or os.clock()>(wild.ClaimUntil or 0) then wild.Owner=player end
    wild.ClaimUntil=os.clock()+45
    wild.Contributors[player]=(wild.Contributors[player] or 0)+amount
    wild.HP=math.max(1,wild.HP-amount) -- deliberate nonlethal hunt state
    if wild.HP/wild.MaxHP<=P.CaptureHP then wild.ExhaustUntil=os.clock()+P.ExhaustSeconds end
end
function S:Nearest(position,range)
    local best,distance=nil,range
    for _,wild in pairs(self.Wild) do
        local d=(wild.Part.Position-position).Magnitude
        if d<distance and not wild.Busy and not wild.ExhaustUntil then best,distance=wild,d end
    end
    return best
end
-- trap: 덫 배율(ItemConfig 의 Catch)
function S:Chance(player,wild,trap,bait)
    local profile=self.ctx.Data:Get(player)
    if P.FirstCaptureGuaranteed and profile and not profile.Tutorial.Captured and wild.SpeciesId=="Mossling" then return 1 end
    return R.chance(P.Species[wild.SpeciesId].Capture,wild.HP,wild.MaxHP,trap,bait,wild.Failures,P)
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
        self.ctx.Notify(player,weak and "먼저 사냥해서 HP를 25% 이하로 낮추세요 · 그다음 덫을 던지세요" or "덫을 던질 지친 야생 펫이 근처에 없습니다.")
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
        self.ctx.Notify(player,"먼저 사냥을 시작한 동료에게 포획 우선권이 있습니다.");return
    end
    if not self.ctx.Pets:CanCapture(player) then self.ctx.Notify(player,"보유 공간이나 임시 펫 공간이 가득 찼습니다.");return end
    local items=self.ctx.Crafting.Items[player]
    if not items or (items[trap] or 0)<=0 or (bait and (items.Bait or 0)<=0) then self.ctx.Notify(player,"덫 또는 먹이가 부족합니다. 제작대를 이용하세요.");return end
    self.ctx.Crafting:Use(player,trap);if bait then self.ctx.Crafting:Use(player,"Bait") end
    wild.Busy=player
    self.Attempts[player]={Wild=wild,EndsAt=os.clock()+P.CaptureSeconds,Chance=self:Chance(player,wild,trapSpec.Catch or 1,bait)}
    self.ctx.PetFX:FireClient(player,"Shake",P.Species[wild.SpeciesId].Name,P.CaptureSeconds)
    self.ctx.FX:FireAllClients("TrapStart",wild.Part.Position,P.CaptureSeconds,trapSpec.Better==true,wild.Id)
end
function S:Finish(player,attempt)
    local wild=attempt.Wild
    self.Attempts[player]=nil;wild.Busy=nil
    if self.Wild[wild.Id]~=wild then return end
    if not self.ctx.Data:Ready(player) or self.ctx.Clock.Phase~="Day" or not U.near(player,wild.Part.Position,P.CaptureRange) then
        if player.Parent then self.ctx.Notify(player,"포획 중단 · 사거리나 생존 상태를 확인하세요. 사용한 덫은 소모됩니다.") end;return
    end
    if math.random()<attempt.Chance and self.ctx.Pets:AddCapture(player,wild) then
        self.ctx.FX:FireAllClients("TrapResult",wild.Part.Position,true,wild.SpeciesId,wild.Id)
        self.Wild[wild.Id]=nil;wild.Part:Destroy()
        for helper in pairs(wild.Contributors) do if helper~=player then self.ctx.Pets:Award(helper,P.CaptureXP) end end
        self.ctx.Notify(player,"포획 성공! 즉시 전투 가능 · 우리 등록 후 밤 생존으로 영구 확정")
        self.ctx.PetFX:FireClient(player,"Capture",P.Species[wild.SpeciesId].Name)
    else
        self.ctx.FX:FireAllClients("TrapResult",wild.Part.Position,false,wild.SpeciesId,wild.Id)
        wild.Failures=wild.Failures+1;wild.ExhaustUntil=os.clock()+P.ExhaustSeconds
        self.ctx.Notify(player,"빠져나왔습니다! 다음 시도의 성공 확률이 올랐습니다.")
        self.ctx.PetFX:FireClient(player,"Fail")
    end
end
function S:RemovePlayer(player)
    local attempt=self.Attempts[player]
    if attempt then attempt.Wild.Busy=nil end
    self.Attempts[player],self.Last[player]=nil,nil
    for _,wild in pairs(self.Wild) do wild.Contributors[player]=nil;if wild.Owner==player then wild.Owner=nil end end
end
function S:Tick(dt)
    if G.ActiveStage<6 then return end
    for player,attempt in pairs(self.Attempts) do if os.clock()>=attempt.EndsAt then self:Finish(player,attempt) end end
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
        wild.Prompt.ActionText=wild.Busy and "포획 중…" or (ready and "덫 던지기 (포획)" or "펫들과 사냥 시작")
        wild.Prompt.Enabled=self.ctx.Clock.Phase=="Day" and not wild.Busy
    end
end
function S:Snapshot(player)
    local list={};local root=U.aliveRoot(player);if not root then return list end
    for uid,wild in pairs(self.Wild) do
        local distance=(root.Position-wild.Part.Position).Magnitude
        if distance<90 then
            list[#list+1]={Id=uid,SpeciesId=wild.SpeciesId,Level=wild.Level,HP=math.ceil(wild.HP),MaxHP=wild.MaxHP,
                Distance=math.floor(distance),Chance=self:Chance(player,wild,1,false),BetterChance=self:Chance(player,wild,I.Items.BetterTrap.Catch,true),
                Ready=wild.HP/wild.MaxHP<=P.CaptureHP,Busy=wild.Busy~=nil,Owner=wild.Owner and wild.Owner.DisplayName or "",CanClaim=not wild.Owner or wild.Owner==player or os.clock()>(wild.ClaimUntil or 0)}
        end
    end
    table.sort(list,function(a,b) return a.Distance<b.Distance end);return list
end
return S
