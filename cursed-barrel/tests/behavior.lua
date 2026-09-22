local count=0
local function check(name,fn)
 local ok,err=pcall(fn);if not ok then error("FAIL "..name..": "..tostring(err)) end
 count=count+1;print("PASS "..name)
end
local function copy(t)
 if type(t)~="table" then return t end
 local o={};for k,v in pairs(t) do o[k]=copy(v) end;return o
end
-- Luau 에서는 표준 라이브러리 표가 읽기 전용이다. 흉내 낼 함수를 덮어쓸 수 있게 사본으로 바꾼다.
if table.isfrozen and table.isfrozen(math) then
 local function thaw(lib) local copy={};for k,v in pairs(lib) do copy[k]=v end;return copy end
 math=thaw(math);table=thaw(table);os=thaw(os)
end
math.clamp=function(v,lo,hi) return math.max(lo,math.min(hi,v)) end
table.clone=function(t) local r={};for k,v in pairs(t) do r[k]=v end;return r end
table.clear=function(t) for k in pairs(t) do t[k]=nil end end
table.find=function(t,v) for i,x in ipairs(t) do if x==v then return i end end end
typeof=type
warn=function() end
local now=1000
os.clock=function() return now end
local epoch=1790000000
os.time=function() return epoch end
local realDate=os.date;os.date=function(fmt,t) return realDate(fmt,t or epoch) end
local delayed={}
task={wait=function(n) now=now+(n or .05) end,spawn=function(fn,...) return fn(...) end,defer=function(fn,...) return fn(...) end,delay=function(n,fn) delayed[#delayed+1]=fn end}
local vectorMeta={}
Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end}
vectorMeta.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__mul=function(a,b) if type(a)=="number" then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vectorMeta.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end}
Enum=setmetatable({},{__index=function(t,k) local v=setmetatable({},{__index=function(_,s) return s end});rawset(t,k,v);return v end})
Random={new=function(seed) return {NextInteger=function(_,lo,hi) return lo end,NextNumber=function() return 0.5 end} end}
local methods={}
local function node(name)
 local t={Name=name,attrs={},children={}}
 return setmetatable(t,{__index=function(o,k) if methods[k] then return methods[k] end;return o.children[k] end,__newindex=function(o,k,v) rawset(o,k,v);if k=="Parent" and v and v.children then v.children[o.Name]=o end end})
end
function methods:WaitForChild(n) if not self.children[n] then self.children[n]=node(n) end;return self.children[n] end
function methods:FindFirstChild(n) return self.children[n] end
function methods:FindFirstChildOfClass(n) return self.children[n] end
function methods:SetAttribute(k,v) self.attrs[k]=v end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:GetChildren() local r={};for _,v in pairs(self.children) do r[#r+1]=v end;return r end
function methods:GetPlayers() return self.list or {} end
function methods:GetPlayerByUserId(id) for _,p in ipairs(self:GetPlayers()) do if p.UserId==id then return p end end end
function methods:FireAllClients(...) self.last={...} end
function methods:FireClient(...) self.last={...} end
function methods:IsA(class) return self.Name==class end
function methods:Kick(message) self.kicked=message end
Instance={new=function(class) return node(class) end}
local services={}
local storage={};local fail=false;local faultCount=0;local hook=nil
local store={UpdateAsync=function(_,key,fn)
 if fail then faultCount=faultCount+1;error("datastore unavailable") end
 if hook then local f=hook;hook=nil;f() end
 local result=fn(copy(storage[key]));if result then storage[key]=copy(result) end;return copy(result)
end}
services.DataStoreService={GetDataStore=function() return store end,GetRequestBudgetForRequestType=function() return 100 end}
services.Players=node("Players");services.Players.list={}
services.RunService={IsStudio=function() return false end}
services.HttpService={GenerateGUID=function() return "test-session" end}
services.ReplicatedStorage=node("ReplicatedStorage")
local pkg=services.ReplicatedStorage:WaitForChild("CursedBarrel");local shared=pkg:WaitForChild("Shared")
local remotes=pkg:WaitForChild("Remotes");remotes:WaitForChild("PresentationCue")
for _,n in ipairs({"GameConfig","ReleaseConfig","Utility","TableConfig"}) do shared:WaitForChild(n) end
game={JobId="server-A",GetService=function(_,name) services[name]=services[name] or node(name);return services[name] end}
workspace={GetServerTimeNow=function() return now end}
local cache={TableService={},RankingService={RecordRound=function() end}}
local function loadModule(name,source)
 local parent=node("Services")
 for _,n in ipairs({"TableService","RankingService","ProfileService","PurchaseService","GameConfig","ReleaseConfig"}) do parent:WaitForChild(n) end
 local env=setmetatable({script={Parent=parent}}, {__index=(getfenv and getfenv(1)) or _G})
 env.require=function(ref)
  local key=type(ref)=="table" and ref.Name or ref
  if cache[key] then return cache[key] end
  cache[key]=loadModule(key);return cache[key]
 end
 local src=source or SOURCES[name]
 if loadstring then local fn=assert(loadstring(src,name));setfenv(fn,env);return fn() end
 return assert(load(src,name,"t",env))()
end
local Config=loadModule("GameConfig");cache.GameConfig=Config
local Release=loadModule("ReleaseConfig");cache.ReleaseConfig=Release
local Utility=loadModule("Utility");cache.Utility=Utility
local TableConfig=loadModule("TableConfig");cache.TableConfig=TableConfig
local Profiles=loadModule("ProfileService");cache.ProfileService=Profiles
local function player(id)
 local p=node("P"..id);p.UserId=id;p.DisplayName=p.Name;p.Parent=services.Players;services.Players.list[#services.Players.list+1]=p
 p.Character=node("Character");local h=node("Humanoid");h.Health=100;h.RootPart={Position=Vector3.new(0,0,0)};h.Parent=p.Character
 return p
end
local p=player(1)
check("rarity lookup does not mutate or duplicate the skin catalog",function()
 local counts={};local lists={}
 for kind in pairs(Config.Skins.PlayerAttributes) do counts[kind]=#Config.Skins[kind];lists[kind]=Config.Skins[kind] end
 for i=1,100 do assert(Config.rarityOf({rarity="legend"})==Config.Rarity.legend) end
 assert(Config.rarityOf(nil)==Config.Rarity.common)
 for kind,n in pairs(counts) do
  assert(#Config.Skins[kind]==n and Config.Skins[kind]==lists[kind])
  local seen={};for _,skin in ipairs(Config.Skins[kind]) do assert(not seen[skin.id]);seen[skin.id]=true end
 end
end)
check("new profile acquires an atomic session",function() Profiles:_load(p);assert(Profiles:CanPurchase(p));assert(storage.u_1.session.id==Profiles._session) end)
check("six inventory categories and defaults",function() local d=Profiles:Get(p);for k in pairs(Config.Skins.PlayerAttributes) do assert(d.owned[k][d.equipped[k]]) end end)
check("release presets require two players",function() for _,v in pairs(TableConfig.Types) do assert(v.MinPlayers==2) end;assert(TableConfig.Types.PartyCards6.SpecialCards) end)
check("skin schema and unique IDs",function()
 for kind in pairs(Config.Skins.PlayerAttributes) do
  local seen={};for _,skin in ipairs(Config.Skins[kind]) do assert(not seen[skin.id]);seen[skin.id]=true
   if kind=="Barrel" then assert(skin.hoop and skin.body and skin.glow) end
   if kind=="Ghost" then assert(skin.skin and skin.accent and skin.aura) end
  end
 end
end)
check("failed load cannot overwrite existing money",function()
 storage.u_2={coins=8300};fail=true;local q=player(2);Profiles:_load(q);assert(q.kicked);assert(not Profiles:CanPurchase(q));assert(not Profiles:Save(q,"test"));assert(storage.u_2.coins==8300);fail=false
end)
check("active foreign session is refused",function()
 storage.u_3={coins=5000,session={id="other",expires=epoch+999}};local q=player(3);Profiles:_load(q);assert(q.kicked);assert(storage.u_3.coins==5000)
end)
check("expired session can be acquired",function()
 storage.u_4={coins=5000,session={id="other",expires=epoch-1}};local q=player(4);Profiles:_load(q);assert(Profiles:CanPurchase(q));assert(Profiles:Get(q).coins>=5000)
end)
check("coin spend persists a decrease",function() local old=Profiles:Get(p).coins;assert(Profiles:Spend(p,100));assert(Profiles:Save(p,"spend"));assert(storage.u_1.coins==old-100) end)
check("receipt failed save is retried without double reward",function()
 local old=Profiles:Get(p).coins;local grants=0
 local function grant(d) grants=grants+1;d.coins=d.coins+1000;return true end
 fail=true;assert(not Profiles:ProcessReceipt(p,{PurchaseId="one"},grant));assert(Profiles:Get(p).coins==old+1000);fail=false
 assert(Profiles:ProcessReceipt(p,{PurchaseId="one"},grant));assert(grants==1);assert(storage.u_1.receipts.one);assert(storage.u_1.coins==old+1000)
 assert(Profiles:ProcessReceipt(p,{PurchaseId="one"},grant));assert(grants==1)
end)
check("receipt handler error rolls back its draft",function()
 local old=Profiles:Get(p).coins
 assert(not Profiles:ProcessReceipt(p,{PurchaseId="bad"},function(d) d.coins=999999;error("grant failed") end));assert(Profiles:Get(p).coins==old);assert(not Profiles:Get(p).receipts.bad)
end)
check("receipt grant and ID survive reconnect",function()
 Profiles:_release(p);assert(storage.u_1.session==nil)
 Profiles:_load(p);local called=false
 assert(Profiles:ProcessReceipt(p,{PurchaseId="one"},function() called=true;return true end));assert(not called)
end)
check("changes during save remain dirty",function()
 hook=function() Profiles:Award(p,3) end
 assert(Profiles:Save(p,"concurrent mutation"));assert(Profiles._dirty[p]);assert(Profiles:Save(p,"next"));assert(storage.u_1.coins==Profiles:Get(p).coins)
end)
check("weekly claims pay exactly once",function()
 local d=Profiles:Get(p);Profiles:_advanceQuests(p,d,"games",20);local old=d.coins
 assert(Profiles:ClaimWeekly(p,"week_games"));assert(not Profiles:ClaimWeekly(p,"week_games"));assert(d.coins==old+1800)
end)
check("weekly rollover removes old progress",function()
 local d=Profiles:Get(p);local saved=epoch;epoch=epoch+604800;Profiles:_rollWeekly(d);assert(next(d.weekly.progress)==nil);assert(next(d.weekly.claimed)==nil);epoch=saved;Profiles:_rollWeekly(d)
end)
check("daily reward only once per UTC day",function()
 local d=Profiles:Get(p);local old=d.coins;Profiles:_rollDaily(p,d);Profiles:_rollDaily(p,d);assert(d.coins==old)
 local streak=d.loginStreak
 epoch=epoch+86400;Profiles:_rollDaily(p,d);assert(d.coins==old+Config.dailyBonusFor(streak+1));assert(d.loginStreak==streak+1)
 Profiles:_rollDaily(p,d);assert(d.coins==old+Config.dailyBonusFor(streak+1));epoch=epoch-86400
end)
check("login streak grows day by day, caps at a 7-day cycle and resets after a missed day",function()
 local q=player(21);Profiles:_load(q);local d=Profiles:Get(q);assert(d.loginStreak==1)
 local saved=epoch
 for day=2,8 do epoch=saved+(day-1)*86400;local before=d.coins;Profiles:_rollDaily(q,d);assert(d.loginStreak==day);assert(d.coins-before==Config.dailyBonusFor(day)) end
 assert(Config.dailyBonusFor(7)==700 and Config.dailyBonusFor(8)==Config.dailyBonusFor(1))
 epoch=saved+10*86400;Profiles:_rollDaily(q,d);assert(d.loginStreak==1)
 epoch=saved
end)
check("empty quest pool cannot pay the daily bonus twice",function()
 local q=player(22);Profiles:_load(q);local d=Profiles:Get(q);local before=d.coins
 d.daily.quests={};Profiles:_rollDaily(q,d);Profiles:_rollDaily(q,d);assert(d.coins==before)
end)
check("season thresholds, uniqueness and expiry",function()
 local d=Profiles:Get(p);d.season.xp=500
 assert(Profiles:ClaimSeason(p,3));assert(d.owned.Chair.dragon_throne);assert(not Profiles:ClaimSeason(p,3));assert(not Profiles:ClaimSeason(p,4))
 local saved=epoch;epoch=Release.Season.EndsAt;assert(not Profiles:ClaimSeason(p,1));epoch=saved
end)
check("forfeits get no participation reward or completion",function()
 local q=player(6);Profiles:_load(q);local d=Profiles:Get(q);local g=d.games;local c=d.coins
 Profiles:RecordRound({typeName="Standard4"},{q},nil,{[q]=true},{});assert(d.games==g and d.coins==c)
end)
check("all non-forfeit players receive completion",function()
 local q=player(7);Profiles:_load(q);local d=Profiles:Get(q);local g=d.games
 Profiles:RecordRound({typeName="PartyCards6"},{q},nil,{},{});assert(d.games==g+1 and d.partyGames==1)
end)
check("lost session refuses a stale server write",function()
 local q=player(8);Profiles:_load(q);storage.u_8.session={id="new server",expires=epoch+500};local old=storage.u_8.coins
 Profiles:Award(q,1000);assert(not Profiles:Save(q,"stale"));assert(storage.u_8.coins==old);assert(q.kicked)
end)
local Purchase=loadModule("PurchaseService")
check("duplicate product IDs are rejected",function() assert(Purchase:Register(123,function()end));assert(not pcall(function() Purchase:Register(123,function()end) end));assert(not Purchase:Register(0,function()end)) end)
check("unknown receipts remain pending",function() Purchase:Start();assert(services.MarketplaceService.ProcessReceipt({PlayerId=1,ProductId=777,PurchaseId="none"})=="NotProcessedYet") end)
local Round=loadModule("RoundService",SOURCES.RoundService:gsub("return RoundService%s*$","return Round"))
local function makeRound()
 local p1,p2=player(101),player(102)
 local seats={node("Seat1"),node("Seat2")};for _,seat in ipairs(seats) do seat.Position=Vector3.new(0,0,0) end
 local t={model=node("Table"),state="Playing",config=table.clone(TableConfig.Types.PartyCards6),typeName="PartyCards6",tableId="test",destroyed=false}
 t.config.AutoAdvanceTurn=false
 local used={};local slots={};for i=1,8 do slots[i]=node("Slot"..i) end
 function t:GetFreeSlotIndices() local a={};for i=1,8 do if not used[i] then a[#a+1]=i end end;return a end
 function t:IsSlotUsed(i) return used[i] end
 function t:GetSlot(i) return slots[i] end
 function t:GetSlotCount() return 8 end
 function t:GetSeats() return seats end
 function t:GetPlayerOfSeat(seat) return seat==seats[1] and p1 or p2 end
 function t:GetSeatOfPlayer(p) return p==p1 and seats[1] or seats[2] end
 function t:HasPlayer(p) return p==p1 or p==p2 end
 function t:SetTableAttribute(k,v) self.model:SetAttribute(k,v) end
 function t:ResetSlots() table.clear(used) end
 function t:ResetBarrelLook() end
 function t:MarkSlotUsed(i,p) used[i]=true end
 function t:PlayDangerEffect() end
 function t:SetState(s) self.state=s end
 function t:SetSeatAlive() end
 function t:RemovePlayer() end
 local r=setmetatable({gameTable=t,participants={p1,p2},roundRoster={p1,p2},isParticipant={[p1]=true,[p2]=true},cards={[p1]={skip=true,rotate=true,seal=true},[p2]={skip=true,rotate=true,seal=true}},afk={},forfeited={},bonuses={},turnIndex=1,turnToken=1,roundId=1,dangerSlots={[2]=true,[6]=true},random=Random.new(),turnCut={},sabotageUses={},phaseToken=1,catchToken=1,catchCount=0,barrelCycle=1,pickLimiter=Utility.RateLimiter.new(.2),catchesUsed={},braveLevel=0,pot=0,picks=0,pirateOuts=0,startingCount=2,countdownToken=1},Round)
 return r,p1,p2,used
end
check("bad pick types, fractions, infinities and NaN rejected",function()
 local r,p1=makeRound()
 for _,v in ipairs({"1",{},1.5,math.huge,-math.huge,0/0,0,99}) do assert(r:ValidatePick(p1,v)~=nil) end
 assert(r:ValidatePick(p1,1)==nil)
end)
check("dead and distant players cannot choose",function()
 local r,p1=makeRound();local h=p1.Character.Humanoid;h.Health=0;assert(r:ValidatePick(p1,1));h.Health=100;h.RootPart.Position=Vector3.new(500,0,0);assert(r:ValidatePick(p1,1))
end)
check("non-turn, resolving and already-used requests rejected",function()
 local r,p1,p2,used=makeRound();assert(r:ValidatePick(p2,1));used[1]=true;assert(r:ValidatePick(p1,1));r.resolving=true;assert(r:ValidatePick(p1,3))
end)
check("card pass advances exactly once",function()
 local r,p1,p2=makeRound();assert(r:UseCard(p1,"skip",nil,1,1));assert(r:GetCurrentPlayer()==p2);assert(not r.cards[p1].skip);assert(not r:UseCard(p1,"skip",nil,1,1))
end)
check("card only accepts current round and turn serial",function()
 local r,p1=makeRound();assert(not r:UseCard(p1,"rotate",nil,0,1));assert(not r:UseCard(p1,"rotate",nil,1,0));assert(r.cards[p1].rotate)
end)
check("cards disabled on standard tables",function() local r,p1=makeRound();r.gameTable.config.SpecialCards=false;assert(not r:UseCard(p1,"skip",nil,1,1)) end)
check("rotation preserves pirate count and avoids used slots",function()
 local r,p1,_,used=makeRound();used[1]=true;used[3]=true
 assert(r:UseCard(p1,"rotate",nil,1,1));assert(r:_liveDangerCount()==2);for index in pairs(r.dangerSlots) do assert(not used[index]) end
 assert(not r:UseCard(p1,"rotate",nil,1,1))
end)
check("sealed slot blocks the NEXT player and clears after that pick",function()
 local r,p1,p2=makeRound();assert(r:UseCard(p1,"seal",3,1,1));assert(r:ValidatePick(p1,3));assert(r.gameTable:GetSlot(3):GetAttribute("Sealed"))
 r:_resolvePick(p1,1,"click");assert(r.sealed==3,"sealer's own pick must not break the seal")
 r.resolving=false;r.turnIndex=2;assert(r:ValidatePick(p2,3),"next player cannot pick the sealed slot")
 r:_resolvePick(p2,4,"click");assert(r.sealed==nil);assert(not r.gameTable:GetSlot(3):GetAttribute("Sealed"))
end)
check("seal needs four empty slots so the next player keeps two choices",function()
 local r,p1,_,used=makeRound();for i=3,8 do used[i]=true end;assert(not r:UseCard(p1,"seal",1,1,1));assert(r.cards[p1].seal)
 local r2,q1,_,used2=makeRound();for i=4,8 do used2[i]=true end;assert(not r2:UseCard(q1,"seal",1,1,1),"3 free slots are not enough")
 local r3,s1,_,used3=makeRound();for i=5,8 do used3[i]=true end;assert(r3:UseCard(s1,"seal",1,1,1),"4 free slots are enough")
end)
check("pirates are never re-hidden in the sealed slot",function()
 local r,p1,_,used=makeRound();table.clear(r.dangerSlots);for i=5,8 do used[i]=true end
 assert(r:UseCard(p1,"seal",1,1,1));for _=1,20 do table.clear(r.dangerSlots);r:_ensureDanger();assert(not r.dangerSlots[1]) end
end)
check("rearming leaves one safe empty slot",function()
 local r,p1,_,used=makeRound();table.clear(r.dangerSlots);for i=3,8 do used[i]=true end;r:_ensureDanger();assert(r:_liveDangerCount()==1)
end)
check("captured pirate can be rearmed repeatedly",function()
 local r,p1,_,used=makeRound();used[2]=true;r.dangerSlots[2]=nil;r:_ensureDanger();assert(r:_liveDangerCount()==2);assert(not r.dangerSlots[2])
end)
check("leaving during catch cancels stale catch work",function()
 local r,p1,p2=makeRound();r.catch={player=p1};r._declareWinner=function(self,winner) self.winner=winner end
 r:RemoveParticipant(p1);assert(r.catch==nil and r.forfeited[p1]);assert(r.winner==p2)
end)
check("round reward settlement happens once",function()
 local r,p1,p2=makeRound();local n=0;local old=Profiles.RecordRound;Profiles.RecordRound=function() n=n+1 end
 r:_declareWinner(p1);r:_declareWinner(p1);Profiles.RecordRound=old;assert(n==1);assert(r.settled)
end)
check("seal survives a pass and resets cleanly",function()
 local r,p1,p2=makeRound();assert(r:UseCard(p1,"seal",3,1,1));assert(r:UseCard(p1,"skip",nil,1,1));assert(r.sealed==3)
 r.countdownToken=1;r.gameTable.ClearSeatFlags=function() end
 r:_resetTable();assert(r.sealed==nil and not r.gameTable:GetSlot(3):GetAttribute("Sealed"))
end)
check("dead turn timer cannot act after a successful pick",function()
 local r,p1=makeRound();r:_resolvePick(p1,1,"click");local token=r.turnToken;r:_onTurnTimeout(p1);assert(r.turnToken==token)
end)
check("early spam catch and late catch fail",function()
 local r,p1=makeRound();r:_beginCatch(p1,2)
 local success=nil;r._resolveCatch=function(_,result) success=result end
 r:HandleCatchInput(p1,now);r:HandleCatchInput(p1,now);r:HandleCatchInput(p1,now);assert(success==false)
 r.catch.earlyTaps=0;success=nil;now=r.catch.opensAt+r.catch.window+Config.Catch.Grace+1;r:HandleCatchInput(p1,now);assert(success==false)
end)
check("valid catch is accepted inside server window",function()
 local r,p1=makeRound();r:_beginCatch(p1,2);now=r.catch.opensAt+0.1;local success=nil
 r._resolveCatch=function(_,result) success=result end;r:HandleCatchInput(p1,now);assert(success==true)
end)
check("a catch uses up the player's one chance for the round",function()
 local r,p1,p2=makeRound();assert(r:_catchesLeft(p1)==Config.Catch.PerPlayer)
 r:_beginCatch(p1,2);assert(r.catchesUsed[p1]==1 and r:_catchesLeft(p1)==0);assert(r:_catchesLeft(p2)==1)
 assert(r.gameTable:GetSeats()[1]:GetAttribute("CatchesLeft")==0,"seat shows no chance left")
end)
check("second pirate for the same player opens no catch window and eliminates",function()
 local r,p1,p2=makeRound();r.catchesUsed[p1]=1;local before=#delayed
 r:_beginCatch(p1,2);assert(r.catch and r.catch.spent,"spent catch record");assert(r.catch.opensAt==math.huge)
 local token=r.catch.token;r:HandleCatchInput(p1,now);r:HandleCatchInput(p1,now);r:HandleCatchInput(p1,now);assert(r.catch and r.catch.token==token,"taps are ignored")
 assert(#delayed==before+1);delayed[#delayed]()
 assert(r.catch==nil);assert(not r.isParticipant[p1],"eliminated");assert(r.pirateOuts==1)
 local payload=services.ReplicatedStorage.CursedBarrel.Remotes.CatchResult.last[2];assert(payload.reason=="spent" and payload.success==false)
end)
check("catch window shrinks with every catch at the table and never below the minimum",function()
 local last=math.huge
 for n=0,12 do local w=Config.catchWindow(n,4,10);assert(w<=last);assert(w>=Config.Catch.MinWindow);last=w end
 assert(Config.catchWindow(0,4,10)>Config.catchWindow(1,4,10))
 assert(Config.Catch.Grace<=0.15,"late grace must stay small")
end)

--------------------------------------------------
-- Phase 10 : 시간 순서대로 예약을 실행하는 스케줄러와, 실제 Round.new 로 만든 테이블
--------------------------------------------------
local queue={};local seq=0
local function schedule(delay,fn) seq=seq+1;queue[#queue+1]={at=now+(delay or 0),fn=fn,seq=seq} end
local function step()
 if #queue==0 then return false end
 table.sort(queue,function(a,b) if a.at==b.at then return a.seq<b.seq end;return a.at<b.at end)
 local job=table.remove(queue,1);if job.at>now then now=job.at end;job.fn();return true
end
local function withScheduler(fn)
 local oldDelay=task.delay;task.delay=schedule;table.clear(queue)
 local ok,err=pcall(fn);task.delay=oldDelay;table.clear(queue)
 if not ok then error(err,0) end
end
local nextId=5000
local function rng(seed)
 local state=seed
 return function() state=(state*1103515245+12345)%2147483648;return state/2147483648 end
end
-- 좌석 · 슬롯 · 인원 변화를 흉내 내는 테이블. RemovePlayer 는 진짜처럼 RosterChanged 를 쏜다.
local function makeTable(n,typeName,slotCount,loadProfiles)
 local players={};local seats={};local seatOf={};local playerOf={}
 for i=1,n do
  nextId=nextId+1;local q=player(nextId);players[i]=q
  if loadProfiles then Profiles:_load(q) end
  local seat=node("Seat"..i);seat.Position=Vector3.new(0,0,0);seats[i]=seat;seatOf[q]=seat;playerOf[seat]=q
 end
 local t={model=node("Table"),state="Waiting",config=table.clone(TableConfig.Types[typeName]),typeName=typeName,tableId="sim",destroyed=false}
 t.RosterChanged=Utility.Signal.new();t.SlotTriggered=Utility.Signal.new()
 local used={};local slots={};for i=1,slotCount do slots[i]=node("Slot"..i) end
 function t:GetFreeSlotIndices() local a={};for i=1,slotCount do if not used[i] then a[#a+1]=i end end;return a end
 function t:IsSlotUsed(i) return used[i]==true end
 function t:GetSlot(i) return slots[i] end
 function t:GetSlotCount() return slotCount end
 function t:GetSeats() return seats end
 function t:GetPlayerOfSeat(seat) return playerOf[seat] end
 function t:GetSeatOfPlayer(q) return seatOf[q] end
 function t:HasPlayer(q) return seatOf[q]~=nil end
 function t:GetPlayers() local a={};for _,seat in ipairs(seats) do if playerOf[seat] then a[#a+1]=playerOf[seat] end end;return a end
 function t:GetPlayerCount() return #self:GetPlayers() end
 function t:GetMinPlayers() return 2 end
 function t:SetTableAttribute(k,v) self.model:SetAttribute(k,v) end
 function t:ResetSlots() table.clear(used) end
 function t:ResetBarrelLook() end
 function t:RefreshBarrelSkin() end
 function t:ClearSeatFlags() end
 function t:MarkSlotUsed(i) assert(not used[i],"slot used twice");used[i]=true end
 function t:PlayDangerEffect() end
 function t:SetState(state) self.state=state;self.model:SetAttribute("State",state) end
 function t:SetSeatAlive() end
 function t:RemovePlayer(q)
  local seat=seatOf[q];if not seat then return false end
  seatOf[q]=nil;playerOf[seat]=nil;self.RosterChanged:Fire(self,q,false);return true
 end
 local r=Round.new(t)
 return r,t,players,used
end
local function runUntil(predicate,limit)
 for _=1,(limit or 200) do if predicate() then return true end;if not step() then break end end
 return predicate()
end
local function playing(t) return t.state=="Playing" end

check("round starts from a real countdown and the first turn opens",function() withScheduler(function()
 local r,t=makeTable(3,"Standard4",16)
 assert(t.state=="Countdown");assert(runUntil(function() return playing(t) and not r.resolving end))
 assert(r:GetCurrentPlayer()~=nil and #r.participants==3);assert(r.pot>0,"pot starts with the base amount")
end) end)

check("leaving during the safe-pick pause does not skip the next player",function() withScheduler(function()
 local r,t=makeTable(3,"Standard4",16)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 table.clear(r.dangerSlots)
 local a,b=r.participants[1],r.participants[2];assert(r:GetCurrentPlayer()==a)
 assert(r:HandlePick(a,1,"test")==nil);assert(r.resolving)
 t:RemovePlayer(a)
 assert(runUntil(function() return not r.resolving end));assert(r:GetCurrentPlayer()==b,"B must get the next turn")
end) end)

check("leaving during an elimination pause does not skip the next player",function() withScheduler(function()
 local r,t=makeTable(4,"Standard4",16)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 local order=r:GetParticipants();local a,b,c=order[1],order[2],order[3]
 table.clear(r.dangerSlots);assert(r:HandlePick(a,1,"test")==nil);assert(runUntil(function() return not r.resolving end))
 assert(r:GetCurrentPlayer()==b);r.catchesUsed[b]=1;table.clear(r.dangerSlots);r.dangerSlots[2]=true
 assert(r:HandlePick(b,2,"test")==nil);assert(runUntil(function() return not r.isParticipant[b] end),"B eliminated")
 t:RemovePlayer(a)
 assert(runUntil(function() return playing(t) and not r.resolving end));assert(r:GetCurrentPlayer()==c,"C must be next")
end) end)

check("current player leaving mid-catch hands the turn to the next player",function() withScheduler(function()
 local r,t=makeTable(3,"Standard4",16)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 local order=r:GetParticipants();table.clear(r.dangerSlots);r.dangerSlots[5]=true
 assert(r:HandlePick(order[1],5,"test")==nil);assert(r.catch and not r.catch.spent)
 t:RemovePlayer(order[1]);assert(r.catch==nil);assert(not r.resolving);assert(r:GetCurrentPlayer()==order[2])
end) end)

check("brave: accept keeps the turn, pays per level, then passes on",function() withScheduler(function()
 local r,t=makeTable(3,"Standard4",16,true)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 local a,b=r.participants[1],r.participants[2];table.clear(r.dangerSlots)
 r._ensureDanger=function() end
 assert(r:HandlePick(a,1,"test")==nil);assert(r.braveOffer and r.braveOffer.player==a)
 assert(t.model:GetAttribute("BraveOfferUserId")==a.UserId)
 local ok=r:AcceptBrave(b);assert(not ok,"only the picker may accept")
 local potBefore=r.pot;local coins=Profiles:Get(a).coins
 assert(r:AcceptBrave(a));assert(r:GetCurrentPlayer()==a and r.braveLevel==1 and not r.resolving)
 assert(not r:AcceptBrave(a),"offer is consumed")
 local rejectedTooFast=r:HandlePick(a,2,"test");assert(rejectedTooFast==Config.RejectMessages.TooFast,"same-instant repeat is rate limited")
 now=now+0.3;local why=r:HandlePick(a,2,"test");assert(why==nil,tostring(why))
 assert(Profiles:Get(a).coins>=coins+Config.Brave.Rewards[1]+Config.Economy.SurviveTurnReward,"brave reward paid")
 assert(Profiles:Get(a).bravePicks==1);assert(r.pot>potBefore)
 assert(runUntil(function() return not r.resolving end));assert(r:GetCurrentPlayer()==b and r.braveLevel==0)
end) end)

check("brave offer stops at the chain limit and when the barrel is nearly empty",function() withScheduler(function()
 local r,t,_,used=makeTable(2,"Standard4",16)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 local a=r.participants[1];table.clear(r.dangerSlots);r._ensureDanger=function() end
 local slot=0
 for level=0,Config.Brave.MaxChain do
  slot=slot+1;now=now+0.3;local why=r:HandlePick(a,slot,"test");assert(why==nil,tostring(why))
  if level<Config.Brave.MaxChain then assert(r.braveOffer,"offer at level "..level);now=now+0.3;assert(r:AcceptBrave(a)) else assert(r.braveOffer==nil,"no offer past the limit") end
 end
 for i=1,16 do used[i]=true end;used[15]=nil;used[16]=nil
 r.resolving=false;r.braveLevel=0;r.turnIndex=1;now=now+1
 assert(r:HandlePick(a,15,"test")==nil);assert(r.braveOffer==nil,"one slot left: no offer")
end) end)

check("forfeit win (opponent leaves at once) gives no win, streak or pot",function() withScheduler(function()
 local r,t,players=makeTable(2,"Standard4",16,true)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 local a,b=r.participants[1],r.participants[2];local pa=Profiles:Get(a);local wins,games,streak=pa.wins,pa.games,pa.streak
 t:RemovePlayer(b);assert(t.state=="RoundEnding")
 assert(t.model:GetAttribute("WinForfeit")==true);assert(pa.wins==wins and pa.streak==streak);assert(pa.games==games+1)
 local pb=Profiles:Get(b);assert(pb.games==0,"the leaver gets no completion")
end) end)

check("pirate elimination gives a full win with pot",function() withScheduler(function()
 local r,t=makeTable(2,"Standard4",16,true)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 local a,b=r.participants[1],r.participants[2];table.clear(r.dangerSlots)
 assert(r:HandlePick(a,1,"test")==nil);assert(runUntil(function() return not r.resolving end))
 r.catchesUsed[b]=1;table.clear(r.dangerSlots);r.dangerSlots[2]=true
 local pa=Profiles:Get(a);local wins,coins=pa.wins,pa.coins;local pot=r.pot;assert(pot>0)
 assert(r:HandlePick(b,2,"test")==nil);assert(runUntil(function() return t.state=="RoundEnding" end))
 assert(t.model:GetAttribute("WinForfeit")==false);assert(pa.wins==wins+1);assert(pa.coins>=coins+pot+Config.Economy.WinReward)
end) end)

check("VIP multiplies earned coins but not quest rewards",function()
 local q=player(31);Profiles:_load(q);local d=Profiles:Get(q)
 local before=d.coins;Profiles:Award(q,100);assert(d.coins==before+100)
 q:SetAttribute("VIP",true);before=d.coins;Profiles:Award(q,100);assert(d.coins==before+math.floor(100*(1+Config.Products.GamePasses.VIP.coinBonus)))
 assert(Profiles:GainScale(q)>1);q:SetAttribute("VIP",nil);assert(Profiles:GainScale(q)==1)
end)

check("VIP and starter skins are never free or coin-buyable",function()
 local found=0
 for kind in pairs(Config.Skins.PlayerAttributes) do for _,skin in ipairs(Config.Skins[kind]) do
  if skin.vip or skin.pack then found=found+1;assert(not Config.isFreeSkin(skin));assert((skin.price or 0)==0) end
 end end
 assert(found==2)
 local q=player(32);Profiles:_load(q);local d=Profiles:Get(q)
 assert(not d.owned.Knife.vip_cutlass and not d.owned.Knife.starter_hook)
 local kind,id=Config.Products.Starter.skin:match("^(%a+)/(.+)$");assert(Config.findSkin(kind,id).id==id)
 kind,id=Config.Products.GamePasses.VIP.skin:match("^(%a+)/(.+)$");assert(Config.findSkin(kind,id).id==id)
end)

check("new profile fields survive a save and reload",function()
 local q=player(33);Profiles:_load(q);local d=Profiles:Get(q)
 d.bravePicks=4;d.perfectCatches=2;d.starterBought=true;Profiles:_touch(q);assert(Profiles:Save(q,"t"))
 Profiles:_release(q);Profiles:_load(q);d=Profiles:Get(q)
 assert(d.bravePicks==4 and d.perfectCatches==2 and d.starterBought==true and d.loginStreak>=1)
end)

local function simulate(trials,seed,catchRate,leaveRate)
 local random=rng(seed)
 local stats={rounds=0,catches=0,eliminated=0,brave=0,forfeits=0,cards=0,maxCatch=0,maxPicks=0}
 for trial=1,trials do
  local typeName=({"Standard4","Duo2","Party6","Blitz4","PartyCards6"})[trial%5+1]
  local preset=TableConfig.Types[typeName]
  local n=math.max(2,math.min(preset.SeatCount,2+trial%preset.SeatCount))
  local r,t,players,used=makeTable(n,typeName,preset.KnifeSlots,trial%4==0)
  local started=false;local ended=false;local handled={}
  for iteration=1,6000 do
   if t.state=="Playing" then started=true end
   if started and (t.state=="RoundEnding" or t.state=="Resetting" or t.state=="Waiting") then ended=true;break end
   if playing(t) then
    -- 참가자 명단과 표가 서로 맞는지
    for _,q in ipairs(r.participants) do assert(r.isParticipant[q]) end
    for q,used in pairs(r.catchesUsed) do assert(used<=Config.Catch.PerPlayer,"catch limit exceeded");if used>stats.maxCatch then stats.maxCatch=used end end
    assert(r.turnIndex>=0 and r.turnIndex<=#r.participants)
    local cur=r:GetCurrentPlayer()
    if r.catch and not r.catch.spent and not r.catch.resolved and not handled[r.catch] then
     handled[r.catch]=true
     if random()<catchRate then now=r.catch.opensAt+0.05;r:HandleCatchInput(r.catch.player,now);stats.catches=stats.catches+1 end
    elseif r.braveOffer and not handled[r.braveOffer] then
     handled[r.braveOffer]=true
     if random()<0.5 then now=now+0.3;if r:AcceptBrave(r.braveOffer.player) then stats.brave=stats.brave+1 end end
    elseif cur and not r.resolving then
     now=now+0.3
     if typeName=="PartyCards6" and random()<0.15 then
      local cards={"skip","rotate","seal"};local free=t:GetFreeSlotIndices()
      if r:UseCard(cur,cards[1+math.floor(random()*3)],free[1+math.floor(random()*#free)],r.roundId,r.turnToken) then stats.cards=stats.cards+1 end
     end
     if not r.resolving and r:GetCurrentPlayer()==cur then
      local choices={};for _,i in ipairs(t:GetFreeSlotIndices()) do if i~=r.sealed then choices[#choices+1]=i end end
      assert(#choices>0,"a turn started with nothing to pick")
      if random()<0.97 then assert(r:HandlePick(cur,choices[1+math.floor(random()*#choices)],"sim")==nil,"valid pick rejected") end
     end
    end
    if random()<leaveRate and #r.participants>0 then
     local leaver=r.participants[1+math.floor(random()*#r.participants)];t:RemovePlayer(leaver);stats.forfeits=stats.forfeits+1
    end
   end
   if not step() then break end
  end
  assert(ended,("round did not end (%s, %d players)"):format(typeName,n))
  stats.rounds=stats.rounds+1;stats.eliminated=stats.eliminated+(r.pirateOuts or 0)
  if (r.picks or 0)>stats.maxPicks then stats.maxPicks=r.picks end
  table.clear(queue)
 end
 return stats
end

check("randomized full rounds always end (catch limit, brave, cards, leavers)",function() withScheduler(function()
 local stats=simulate(160,20260922,0.75,0.01)
 assert(stats.maxCatch==1);assert(stats.eliminated>0 and stats.brave>0 and stats.cards>0)
 print(("  simulated %d rounds · catches %d · pirate outs %d · brave %d · cards %d · leavers %d · longest %d picks"):format(stats.rounds,stats.catches,stats.eliminated,stats.brave,stats.cards,stats.forfeits,stats.maxPicks))
end) end)

check("reported bug: even if everyone always catches, every round still ends",function() withScheduler(function()
 local stats=simulate(120,77,1.0,0)
 assert(stats.rounds==120 and stats.maxCatch==1)
 -- 한 판은 잡기 없이는 끝나지 않는다: 인원수만큼 잡은 뒤에는 다음 해적이 반드시 탈락시킨다.
 assert(stats.maxPicks<400,"rounds must stay short, got "..stats.maxPicks)
 print(("  perfect catchers: %d rounds · catches %d · pirate outs %d · longest %d picks"):format(stats.rounds,stats.catches,stats.eliminated,stats.maxPicks))
end) end)

local Ship=loadModule("ShipLayout")
check("all ten tables fit the ship with chair clearance",function()
 local total=0
 for name,pos in pairs(Ship.Tables) do total=total+1;assert(math.abs(pos[1])+11<Ship.halfWidth(pos[2]));assert(pos[2]-11>Ship.CabinFront);assert(pos[2]+11<101) end
 assert(total==10)
end)
check("table pairs preserve at least 26 studs center separation",function()
 for a,p in pairs(Ship.Tables) do for b,q in pairs(Ship.Tables) do if a~=b then
  assert(math.sqrt((p[1]-q[1])^2+(p[2]-q[2])^2)>=26)
 end end end
end)
check("lantern posts are outside chair access rings",function()
 for _,z in ipairs(Ship.LanternFrames) do for _,side in ipairs({-1,1}) do for _,p in pairs(Ship.Tables) do
  assert(math.sqrt((p[1]-side*11.5)^2+(p[2]-z)^2)>12)
 end end end
end)
check("showcase rows fit inside the stern cabin",function()
 for _,kind in ipairs({"Knife","Barrel","Ghost"}) do
  local rows=math.ceil(#Config.Skins[kind]/Ship.Showcase.Columns)
  local last=Ship.Showcase.Z+(rows-1)*Ship.Showcase.RowSpacing
  assert(last+3.4<Ship.CabinFront);assert(Ship.Showcase.Z-3.4>Ship.CabinBack)
  assert(math.abs(Ship.Showcase.Centers[kind])+8+3.4<52)
 end
end)
print("BEHAVIOR CHECKS: "..count.." passed")
