local RS=game:GetService("ReplicatedStorage")
local Engine=game:GetService("RunService")
local Http=game:GetService("HttpService")
local C=require(RS.Shared.Config.DataConfig)
local G=require(RS.Shared.Config.GameConfig)
local P=require(RS.Shared.Config.PetConfig)
local R=require(RS.Shared.Modules.PetRules)
local EC=require(RS.Shared.Config.EggConfig)
local S={}
function S:Init(ctx)
    self.ctx,self.Sessions,self.MemoryRecords=ctx,{},{}
    self.Memory=G.ActiveStage<7 or (Engine:IsStudio() and C.StudioMemory)
    if not self.Memory then self.Store=game:GetService("DataStoreService"):GetDataStore(Engine:IsStudio() and C.StudioStoreName or C.StoreName) end
end
function S:NewProfile()
    local uid=Http:GenerateGUID(false)
    return {Version=C.Version,Coins=0,Pets={[uid]={Uid=uid,SpeciesId="Mossling",Level=1,Exp=0,Favorite=true,CaughtAt=os.time(),CaughtRegion="Grassland",
            Stars=3,Shiny=false,Trait="Loyal"}},
        Party={uid},Loadouts={},Dex={Mossling={Seen=true,Caught=true}},UnlockedRegions={Grassland=true},ClearedRegions={},
        Stats={NightsSurvived=0,Clears=0},Tutorial={},Receipts={},Perks={},Eggs={}}
end
function S:Validate(data)
    if type(data)~="table" or type(data.Version)~="number" or data.Version<1 or data.Version>C.Version then return nil end
    for _,key in ipairs({"Pets","Party","Dex","UnlockedRegions","ClearedRegions","Stats"}) do if type(data[key])~="table" then return nil end end
    local function integer(n) return type(n)=="number" and n==n and n>=0 and n%1==0 and n<1e12 end
    if not integer(data.Coins) or not integer(data.Stats.NightsSurvived) or not integer(data.Stats.Clears) then return nil end
    if R.count(data.Pets)>P.CollectionLimit then return nil end
    for uid,pet in pairs(data.Pets) do
        if type(uid)~="string" or type(pet)~="table" or pet.Uid~=uid or not P.Species[pet.SpeciesId]
            or not integer(pet.Level) or pet.Level<1 or pet.Level>P.MaxLevel or not integer(pet.Exp)
            or (pet.Stage~=nil and pet.Stage~=1 and pet.Stage~=2)
            or (pet.Stars~=nil and (not integer(pet.Stars) or pet.Stars<1 or pet.Stars>5))
            or (pet.Shiny~=nil and type(pet.Shiny)~="boolean")
            or (pet.Trait~=nil and not P.Traits[pet.Trait])
            or (pet.Nickname~=nil and (type(pet.Nickname)~="string" or #pet.Nickname>80)) then return nil end
    end
    local output=R.copy(data)
    -- Version 1 migration preserves every pet and only normalizes selected slots.
    -- Version 3: pets may carry Stage (nil = 새끼). Older saves need no change.
    -- Version 4: Stars/Shiny/Trait/Nickname (없으면 별 2개·보통·특성 없음으로 본다), Eggs(알) 목록
    local selected,seen={},{}
    for _,uid in ipairs(output.Party) do if output.Pets[uid] and not seen[uid] and #selected<P.ActiveLimit then selected[#selected+1]=uid;seen[uid]=true end end
    output.Party=selected
    if output.Eggs~=nil then
        if type(output.Eggs)~="table" or R.count(output.Eggs)>EC.Limit then return nil end
        for id,egg in pairs(output.Eggs) do
            if type(id)~="string" or type(egg)~="table" or egg.Id~=id or not EC.Kinds[egg.Kind] or type(egg.GotAt)~="number"
                or (egg.HatchAt~=nil and type(egg.HatchAt)~="number") then return nil end
        end
    end
    for _,key in ipairs({"Loadouts","Tutorial","Receipts","Perks","Eggs"}) do
        if output[key]~=nil and type(output[key])~="table" then return nil end
        output[key]=output[key] or {}
    end
    output.Version=C.Version
    return output
end
function S:Transform(key,fn)
    if self.Memory then
        local result=fn(R.copy(self.MemoryRecords[key]))
        if result then self.MemoryRecords[key]=R.copy(result) end
        return R.copy(result)
    end
    return self.Store:UpdateAsync(key,fn)
end
function S:Load(player)
    if self.Sessions[player] then return false end
    local token,key,starter=Http:GenerateGUID(false),"u_"..player.UserId,self:NewProfile()
    local locked
    local function acquire()
        return pcall(function() return self:Transform(key,function(old)
            locked=false
            if old~=nil and (type(old)~="table" or old.Schema~=1) then return nil end
            if old and not R.canAcquire(old.Lock,token,os.time()) then locked=true;return nil end
            local data
            if old then data=self:Validate(old.Data) else data=R.copy(starter) end
            if not data then return nil end
            return {Schema=1,Data=data,Lock={Token=token,Expires=os.time()+C.LeaseSeconds}}
        end) end)
    end
    local ok,record
    local waitUntil=os.clock()+C.LockWait
    for attempt=1,C.Retries do
        ok,record=acquire()
        -- 로비에서 막 넘어왔으면 로비 서버가 아직 저장을 푸는 중일 수 있다 → 잠깐 기다렸다 다시
        while ok and not record and locked and os.clock()<waitUntil and player.Parent do
            task.wait(C.RetrySeconds)
            ok,record=acquire()
        end
        if ok then break end
        task.wait(C.RetrySeconds)
    end
    if not ok or not record then
        if player.Parent then player:Kick("저장 데이터가 사용 중이거나 불러오지 못했습니다. 잠시 후 다시 접속해 주세요.") end
        return false
    end
    self.Sessions[player]={Key=key,Token=token,Profile=R.copy(record.Data),Ready=true,Revision=0,Ack=0,
        Status=self.Memory and "Practice" or "Saved",LeaseUntil=record.Lock.Expires,NextSave=os.clock()+C.SaveInterval}
    return true
end
function S:Ready(player) local s=self.Sessions[player]; return s and s.Ready and not s.Closing end
function S:Get(player) local s=self.Sessions[player]; return s and s.Profile end
function S:Mutate(player,fn)
    local s=self.Sessions[player]
    if not self:Ready(player) then return false end
    fn(s.Profile) -- callbacks MUST NOT yield
    s.Revision=s.Revision+1; s.Status=self.Memory and "Practice" or "Unsaved"
    return true
end
function S:Save(player,release)
    local s=self.Sessions[player]; if not s then return end
    if release then s.Closing,s.Ready,s.Release=true,false,true end
    if s.Busy then s.Again=true;return end
    s.Busy=true
    task.spawn(function()
        repeat
            s.Again=false
            local snapshot,revision,releasing=R.copy(s.Profile),s.Revision,s.Release
            s.Status="Saving"
            local ok,result
            for attempt=1,C.Retries do
                ok,result=pcall(function() return self:Transform(s.Key,function(old)
                    if not old or old.Schema~=1 or not old.Lock or old.Lock.Token~=s.Token or old.Lock.Expires<=os.time() then return nil end
                    return {Schema=1,Data=snapshot,Lock=not releasing and {Token=s.Token,Expires=os.time()+C.LeaseSeconds} or nil}
                end) end)
                if ok then break end
                task.wait(C.RetrySeconds)
            end
            if ok and result then
                s.Ack=revision;s.LeaseUntil=result.Lock and result.Lock.Expires or 0
                s.Status=self.Memory and "Practice" or (s.Revision==revision and "Saved" or "Unsaved")
                if self.ctx.Pets then self.ctx.Pets:Saved(player,snapshot) end
                if releasing then self.Sessions[player]=nil;break end
                s.NextSave=os.clock()+C.SaveInterval
                if s.Release then s.Again=true end
            elseif ok then
                s.Ready,s.Closing,s.Status=false,true,"LockLost"
                self.Sessions[player]=nil
                player:Kick("데이터 세션이 만료되었습니다. 안전한 재접속이 필요합니다.")
                break
            else
                s.Status,s.NextSave="Retrying",os.clock()+C.RetrySeconds
                if player.Parent then self.ctx.Notify(player,"저장 재시도 중입니다. 확정 표시를 확인해 주세요.") end
                break
            end
        until not s.Again
        s.Busy=false
    end)
end
function S:Tick()
    for player,s in pairs(self.Sessions) do
        if s.Ready and os.time()>=s.LeaseUntil-C.LeaseSafety then
            player:Kick("저장 연결을 복구하지 못했습니다. 잠시 후 다시 접속해 주세요."); self:Save(player,true)
        elseif not s.Busy and (s.Release or os.clock()>=s.NextSave) then self:Save(player,s.Release) end
    end
end
function S:Close()
    for player in pairs(self.Sessions) do self:Save(player,true) end
    local stop=os.clock()+C.ShutdownSeconds
    while next(self.Sessions) and os.clock()<stop do self:Tick();task.wait(0.1) end
end
return S
