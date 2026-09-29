local RS=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local P=require(RS.Shared.Config.PetConfig)
local G=require(RS.Shared.Config.GameConfig)
local R=require(RS.Shared.Modules.PetRules)
local U=require(RS.Shared.Modules.Utility)
local Shop=require(RS.Shared.Config.ShopConfig)
local S={}
-- 값이 바뀔 때만 속성을 복제한다 (0.2초마다 같은 값을 보내지 않도록)
local function attr(part,key,value) if part:GetAttribute(key)~=value then part:SetAttribute(key,value) end end
local function face(part,target)
    local pos=part.Position;local flat=Vector3.new(target.X,pos.Y,target.Z)
    if (flat-pos).Magnitude>0.1 then part.CFrame=CFrame.lookAt(pos,flat) end
end
function S:Init(ctx) self.ctx,self.Rosters,self.Teams,self.Active,self.LastAction=ctx,{},{},{},{} end
function S:Record(player,data,secured)
    local stats=R.stats(data,P)
    local rec={Data=data,Owner=player,HP=stats.HP,MaxHP=stats.HP,Secured=secured,Mode="Follow",NextAttack=0,LastCombat=-100}
    self.Rosters[player][data.Uid]=rec;return rec
end
function S:AddPlayer(player)
    self.Rosters[player],self.Teams[player]={},{}
    local profile=self.ctx.Data:Get(player)
    for _,data in pairs(profile.Pets) do self:Record(player,data,true) end
    if G.ActiveStage>=5 then self:SetTeam(player,profile.Party,true) end
end
function S:RemovePlayer(player)
    for _,rec in pairs(self.Rosters[player] or {}) do self:Unspawn(rec) end
    self.Rosters[player],self.Teams[player],self.LastAction[player]=nil,nil,nil
end
function S:Unspawn(rec)
    if rec.Part then rec.Part:Destroy();rec.Part=nil end
    self.Active[rec.Data.Uid]=nil;rec.Stand=nil
end
function S:Spawn(rec,index)
    local root=U.aliveRoot(rec.Owner)
    local pos=(root and root.Position or self.ctx.Map.Spawn.Position)+Vector3.new(index*3,0,5)
    local part=U.part(self.ctx.Map.PetsFolder,rec.Data.Uid,Vector3.new(2,2,2),Vector3.new(pos.X,2,pos.Z))
    part.Transparency,part.CanCollide,part.CanTouch=1,false,false
    part:SetAttribute("SpeciesId",rec.Data.SpeciesId);part:SetAttribute("OwnerId",rec.Owner.UserId)
    part:SetAttribute("OwnerName",rec.Owner.DisplayName);part:SetAttribute("Uid",rec.Data.Uid);part:SetAttribute("Stage",R.stage(rec.Data))
    rec.Part,rec.Index=part,index;self.Active[rec.Data.Uid]=rec
end
function S:SetTeam(player,ids,initial)
    local roster=self.Rosters[player]; if not roster then return false end
    ids=R.party(ids,roster,P.ActiveLimit); if not ids then return false end
    local phase=self.ctx.Clock.Phase
    if not initial then
        if phase~="Day" and phase~="Waiting" then self.ctx.Notify(player,"편성은 낮과 출발 대기에 가능합니다.");return false end
        for _,rec in pairs(roster) do if os.clock()-rec.LastCombat<P.SwapCooldown then self.ctx.Notify(player,"전투가 끝난 뒤 6초 후 교체할 수 있습니다.");return false end end
    end
    local occupied=R.count(self.Active)-#(self.Teams[player] or {})
    if occupied+#ids>P.ServerLimit then return false end
    for _,rec in pairs(roster) do self:Unspawn(rec) end
    self.Teams[player]=ids
    for index,uid in ipairs(ids) do self:Spawn(roster[uid],index) end
    self.ctx.Data:Mutate(player,function(profile)
        profile.Party={};for _,uid in ipairs(ids) do if profile.Pets[uid] then table.insert(profile.Party,uid) end end
    end)
    return true
end
function S:CanCapture(player)
    local roster=self.Rosters[player]; if not roster then return false end
    local pending=0;for _,rec in pairs(roster) do if not rec.Secured and not rec.PendingSave then pending=pending+1 end end
    return pending<P.PendingLimit and R.count(roster)<P.CollectionLimit
end
function S:AddCapture(player,wild)
    if not self:CanCapture(player) then return false end
    local uid=Http:GenerateGUID(false)
    local data={Uid=uid,SpeciesId=wild.SpeciesId,Level=wild.Level,Exp=0,CaughtAt=os.time(),CaughtRegion="Grassland",Stage=wild.Stage}
    self:Record(player,data,false)
    if #self.Teams[player]<P.ActiveLimit then
        -- A catch joins an open slot without dismissing/rehealing existing companions.
        table.insert(self.Teams[player],uid);self:Spawn(self.Rosters[player][uid],#self.Teams[player])
    end
    self.ctx.Data:Mutate(player,function(profile) profile.Tutorial.Captured=true;profile.Dex[wild.SpeciesId]=profile.Dex[wild.SpeciesId] or {Seen=true} end)
    self:Award(player,P.CaptureXP)
    return true
end
function S:Award(player,amount)
    if not self.ctx.Data:Ready(player) then return end
    local evolved={}
    self.ctx.Data:Mutate(player,function()
        for _,uid in ipairs(self.Teams[player] or {}) do
            local rec=self.Rosters[player][uid]
            if R.addXP(rec.Data,amount,P) then table.insert(evolved,rec) end
            local stats=R.stats(rec.Data,P);rec.MaxHP=stats.HP
        end
    end)
    -- 진화: 커지고 강해진 모습으로 바뀌고 체력이 가득 찬다
    for _,rec in ipairs(evolved) do
        rec.HP=rec.MaxHP
        if rec.Part then rec.Part:SetAttribute("Stage",2);self.ctx.FX:FireAllClients("Evolve",rec.Part.Position,rec.Data.SpeciesId) end
        local name=R.name(rec.Data.SpeciesId,2,P)
        self.ctx.Notify(player,"✨ "..P.Species[rec.Data.SpeciesId].Name.." 이(가) "..name.." (으)로 진화했습니다!")
        self.ctx.PetFX:FireClient(player,"Evolve",name)
    end
end
function S:Saved(player,snapshot)
    for uid,rec in pairs(self.Rosters[player] or {}) do
        if rec.PendingSave and snapshot.Pets[uid] then
            rec.PendingSave,rec.Secured=false,true
            self.ctx.Notify(player,"영구 확정: "..R.name(rec.Data.SpeciesId,R.stage(rec.Data),P)..(self.ctx.Data.Memory and " (연습 모드)" or ""))
            self.ctx.PetFX:FireClient(player,"Secured")
        end
    end
end
function S:NightSurvived(night,cleared)
    for player in pairs(self.ctx.Run.Participants) do
        local key=self.ctx.SessionId..":"..self.ctx.Run.RoundId..":"..night
        local profile=self.ctx.Data:Get(player)
        if profile and not profile.Receipts[key] then
            local newSpecies={}
            local granted=self.ctx.Data:Mutate(player,function(data)
                data.Receipts[key]=true
                -- Bound receipt history. Same run has only three nightly receipts.
                local keys={};for k in pairs(data.Receipts) do table.insert(keys,k) end
                if #keys>60 then for _,k in ipairs(keys) do if k~=key then data.Receipts[k]=nil;break end end end
                for uid,rec in pairs(self.Rosters[player] or {}) do
                    if rec.Registered and not rec.Secured and not rec.PendingSave then
                        data.Pets[uid]=rec.Data;rec.PendingSave=true
                        -- 도감 보상: 새 종을 처음 영구 확정하면 코인
                        local entry=data.Dex[rec.Data.SpeciesId]
                        if not (entry and entry.Caught) then data.Coins=data.Coins+Shop.DexReward;table.insert(newSpecies,rec.Data.SpeciesId) end
                        data.Dex[rec.Data.SpeciesId]={Seen=true,Caught=true}
                    end
                    rec.HP,rec.RecoverAt=rec.MaxHP,nil
                end
                data.Party={};for _,uid in ipairs(self.Teams[player] or {}) do if data.Pets[uid] then table.insert(data.Party,uid) end end
                data.Coins=data.Coins+P.NightCoins+(cleared and P.ClearCoins or 0)
                data.Stats.NightsSurvived=data.Stats.NightsSurvived+1
                if cleared then data.Stats.Clears=data.Stats.Clears+1;data.ClearedRegions.Grassland=true;data.UnlockedRegions.Swamp=true end
                data.Tutorial.Survived=true
            end)
            if granted then
                self:Award(player,P.NightXP);self.ctx.Data:Save(player)
                for _,id in ipairs(newSpecies) do self.ctx.Notify(player,"📖 도감 새 종! "..P.Species[id].Name.." · 🪙 +"..Shop.DexReward) end
            end
        end
    end
end
function S:Reset()
    for player,roster in pairs(self.Rosters) do
        local selected={}
        for _,uid in ipairs(self.Teams[player]) do
            local rec=roster[uid];if rec and (rec.Secured or rec.PendingSave) then table.insert(selected,uid) end
        end
        for uid,rec in pairs(roster) do
            self:Unspawn(rec)
            if not rec.Secured and not rec.PendingSave then roster[uid]=nil else rec.HP,rec.Mode,rec.Target,rec.RecoverAt=rec.MaxHP,"Follow",nil,nil end
        end
        self:SetTeam(player,selected,true)
    end
end
function S:Command(player,command,target)
    for _,uid in ipairs(self.Teams[player] or {}) do
        local rec=self.Rosters[player][uid]
        rec.Mode,rec.Target,rec.Stand=command,target,nil
        if command=="Guard" or command=="Stay" then rec.Guard=rec.Part.Position end
    end
end
function S:Action(player,action,value)
    if G.ActiveStage<5 or not self.ctx.Data:Ready(player) or not self.ctx.Run:IsParticipant(player) then return end
    if type(action)~="string" or os.clock()-(self.LastAction[player] or -100)<0.25 then return end
    self.LastAction[player]=os.clock()
    local roster,profile=self.Rosters[player],self.ctx.Data:Get(player)
    if action=="Toggle" and type(value)=="string" and roster[value] then
        local ids=R.copy(self.Teams[player]);local found=table.find(ids,value)
        if found then table.remove(ids,found) else table.insert(ids,value) end
        self:SetTeam(player,ids)
    elseif action=="Favorite" and type(value)=="string" and roster[value] then
        self.ctx.Data:Mutate(player,function() roster[value].Data.Favorite=not roster[value].Data.Favorite end)
    elseif action=="Best" then
        local choices={};for uid,rec in pairs(roster) do table.insert(choices,{Uid=uid,Score=R.stats(rec.Data,P).Damage/P.Species[rec.Data.SpeciesId].Interval}) end
        table.sort(choices,function(a,b) return a.Score>b.Score end)
        local ids={};for i=1,math.min(P.ActiveLimit,#choices) do ids[i]=choices[i].Uid end
        self:SetTeam(player,ids)
    elseif (action=="SaveTeam" or action=="LoadTeam") and type(value)=="number" and value%1==0 and value>=1 and value<=3 then
        local slot=tostring(value)
        if action=="SaveTeam" then
            self.ctx.Data:Mutate(player,function(data) data.Loadouts[slot]=R.copy(data.Party) end)
            self.ctx.Notify(player,"팀 "..slot.." 저장 · 영구 펫만 포함됩니다.")
        elseif profile.Loadouts[slot] then self:SetTeam(player,profile.Loadouts[slot]) end
    elseif action=="Follow" or action=="Stay" or action=="Guard" then self:Command(player,action)
    elseif action=="Focus" and type(value)=="string" then
        local wild=self.ctx.Capture.Wild[value]
        if wild and self.ctx.Clock.Phase=="Day" and U.near(player,wild.Part.Position,80) and self.ctx.Capture:CanFight(player,wild) then self:Command(player,"Focus",value) end
    elseif action=="Register" and U.near(player,self.ctx.Map.Cage.Position,G.InteractionRange) then
        local n=0;for _,rec in pairs(roster) do if not rec.Secured and not rec.PendingSave then rec.Registered=true;n=n+1 end end
        self.ctx.Notify(player,n.."마리 등록 · 다음 밤을 버티면 저장됩니다.")
    elseif action=="Heal" and type(value)=="string" and roster[value] then
        local rec=roster[value]
        local near=U.near(player,self.ctx.Map.Cage.Position,G.InteractionRange) or (rec.Part~=nil and U.near(player,rec.Part.Position,G.SnackRange))
        if rec.HP>0 and rec.HP<rec.MaxHP and near and self.ctx.Crafting:Use(player,"Snack") then rec.HP=math.min(rec.MaxHP,rec.HP+rec.MaxHP*0.5) end
    end
end
-- 간식을 들고 공격 버튼: 가까이 있는 내 펫 중 가장 많이 다친 펫을 회복
function S:FeedNearest(player)
    local best,ratio=nil,1
    for _,rec in pairs(self.Rosters[player] or {}) do
        if rec.Part and rec.HP>0 and rec.HP<rec.MaxHP and U.near(player,rec.Part.Position,G.SnackRange) and rec.HP/rec.MaxHP<ratio then best,ratio=rec,rec.HP/rec.MaxHP end
    end
    if not best then self.ctx.Notify(player,"가까이에 다친 펫이 없습니다.");return end
    if self.ctx.Crafting:Use(player,"Snack") then
        best.HP=math.min(best.MaxHP,best.HP+best.MaxHP*0.5)
        self.ctx.FX:FireAllClients("Eat",best.Part.Position,"Snack")
    end
end
function S:Damage(rec,amount)
    if not rec.Part or rec.HP<=0 then return end
    rec.HP=math.max(0,rec.HP-amount);rec.LastCombat=os.clock()
    if rec.HP==0 then rec.RecoverAt=os.clock()+P.DayRecovery;rec.Target=nil end
end
function S:Nearest(position,range)
    local best,distance=nil,range
    for _,rec in pairs(self.Active) do
        local d=(rec.Part.Position-position).Magnitude
        if rec.HP>0 and self.ctx.Data:Ready(rec.Owner) and d<distance then best,distance=rec,d end
    end
    return best
end
function S:Move(rec,goal,dt)
    local delta=U.flat(goal-rec.Part.Position)
    if delta.Magnitude>1 then
        local pos=rec.Part.Position+delta.Unit*math.min(delta.Magnitude,P.FollowSpeed*dt)
        -- Companions float over prototype barriers; no per-pet pathfinding jobs.
        rec.Part.CFrame=CFrame.lookAt(Vector3.new(pos.X,goal.Y,pos.Z),Vector3.new(pos.X,goal.Y,pos.Z)+delta.Unit)
    end
end
function S:Tick(dt)
    if G.ActiveStage<5 then return end
    local phase=self.ctx.Clock.Phase
    for _,rec in pairs(self.Active) do
        if self.ctx.Data:Ready(rec.Owner) then
            local root=U.aliveRoot(rec.Owner)
            local spec,stats=P.Species[rec.Data.SpeciesId],R.stats(rec.Data,P)
            if rec.HP<=0 and phase=="Day" and os.clock()>=(rec.RecoverAt or math.huge) then rec.HP,rec.RecoverAt=rec.MaxHP,nil end
            local target,isWild=nil,false
            if rec.HP>0 and rec.Mode~="Stay" then
                if phase=="Day" and rec.Mode=="Focus" then
                    local wild=self.ctx.Capture.Wild[rec.Target]
                    if wild and wild.HP/wild.MaxHP>P.CaptureHP and self.ctx.Capture:CanFight(rec.Owner,wild) then target,isWild=wild,true end
                elseif phase=="Night" then target=self.ctx.Enemies:Nearest(rec.Part.Position,math.max(P.Aggro,stats.Range),true) end
            end
            if root and (rec.Part.Position-root.Position).Magnitude>P.Leash and rec.Mode~="Guard" and rec.Mode~="Stay" then
                rec.Part.Position=Vector3.new(root.Position.X+rec.Index*3,2,root.Position.Z+5);target=nil
            end
            if not root then
                rec.Mode,rec.Target,rec.Stand="Follow",nil,nil
                self:Move(rec,self.ctx.Map.Spawn.Position+Vector3.new(rec.Index*3,1,5),dt)
            elseif rec.HP>0 then
                local range=stats.Range*(rec.Stand and P.StandRange or 1)
                if target then
                    local pos=target.Part.Position
                    if (pos-rec.Part.Position).Magnitude<=range then
                        if os.clock()>=rec.NextAttack then
                            rec.NextAttack,rec.LastCombat=os.clock()+spec.Interval,os.clock()
                            face(rec.Part,pos)
                            rec.Part:SetAttribute("AttackAt",workspace:GetServerTimeNow())
                            self.ctx.FX:FireAllClients("Pet",rec.Part.Position,pos,rec.Data.SpeciesId)
                            local damage=stats.Damage*(rec.Stand and P.StandDamage or 1)
                            if isWild then self.ctx.Capture:Damage(target,damage*R.element(spec.Element,P.Species[target.SpeciesId].Element),rec.Owner)
                            else
                                self.ctx.Enemies:Damage(target,damage)
                                if spec.Splash then
                                    local targets={};for _,enemy in pairs(self.ctx.Enemies.Units) do if enemy~=target and (enemy.Part.Position-pos).Magnitude<spec.Splash then table.insert(targets,enemy) end end
                                    for _,enemy in ipairs(targets) do self.ctx.Enemies:Damage(enemy,damage*0.45) end
                                end
                            end
                        end
                    elseif rec.Mode~="Guard" then self:Move(rec,Vector3.new(pos.X,2,pos.Z),dt) end
                elseif rec.Mode=="Follow" or rec.Mode=="Focus" then
                    local goal=root.Position+root.CFrame.RightVector*((rec.Index-2)*4)-root.CFrame.LookVector*5
                    self:Move(rec,Vector3.new(goal.X,2,goal.Z),dt)
                end
            end
            attr(rec.Part,"Fainted",rec.HP<=0)
            attr(rec.Part,"Level",stats.Level);attr(rec.Part,"HP",math.ceil(rec.HP));attr(rec.Part,"MaxHP",rec.MaxHP)
            attr(rec.Part,"Mode",rec.Mode);attr(rec.Part,"Standing",rec.Stand~=nil)
            attr(rec.Part,"Status",rec.Secured and "영구" or (rec.PendingSave and "저장 중" or (rec.Registered and "등록됨" or "미등록")))
        end
    end
end
function S:AssignStand(player,slot)
    local phase=self.ctx.Clock.Phase
    if phase~="Day" and phase~="Night" and phase~="Waiting" then return end
    if os.clock()-(self.LastAction[player] or -100)<0.35 then return end
    self.LastAction[player]=os.clock()
    if not self.ctx.Data:Ready(player) or not U.near(player,slot.Pad.Position,G.InteractionRange) then return end
    for _,other in pairs(self.Active) do if other.Stand==slot.Id then self.ctx.Notify(player,"이미 펫이 지키고 있습니다.");return end end
    for _,uid in ipairs(self.Teams[player] or {}) do
        local rec=self.Rosters[player][uid]
        if rec.HP>0 and not rec.Stand then
            rec.Mode,rec.Stand,rec.Target="Guard",slot.Id,nil
            rec.Part.Position=slot.Pad.Position+Vector3.new(0,3,0)
            self.ctx.Notify(player,"배치 완료 · 공격력/사거리 보정");return
        end
    end
end
function S:Snapshot(player)
    local list={}
    for uid,rec in pairs(self.Rosters[player] or {}) do
        list[#list+1]={Uid=uid,SpeciesId=rec.Data.SpeciesId,Stage=R.stage(rec.Data),Level=rec.Data.Level,EffectiveLevel=math.min(rec.Data.Level,P.RegionCap),
            Exp=rec.Data.Exp,HP=math.ceil(rec.HP),MaxHP=rec.MaxHP,Favorite=rec.Data.Favorite==true,Active=rec.Part~=nil,
            Status=rec.Secured and "영구" or (rec.PendingSave and "저장 중" or (rec.Registered and "밤 생존 대기" or "미등록")),Mode=rec.Mode}
    end
    table.sort(list,function(a,b) if a.Active~=b.Active then return a.Active end;if a.Favorite~=b.Favorite then return a.Favorite end;return a.Uid<b.Uid end)
    return list
end
return S
