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
check("one early tap fails at once; the pick's own double tap is ignored",function()
 local r,p1=makeRound();r:_beginCatch(p1,2)
 local success,why=nil,nil;r._resolveCatch=function(_,result,reason) success=result;why=reason end
 r:HandleCatchInput(p1,now);assert(success==nil,"tap inside ArmDelay is ignored")
 now=now+Config.Catch.ArmDelay+0.05;assert(now<r.catch.opensAt-Config.Catch.EarlyTolerance)
 r:HandleCatchInput(p1,now);assert(success==false and why=="early","first early tap fails")
end)
check("late catch fails and a tap within the clock tolerance counts as on time",function()
 local r,p1=makeRound();r:_beginCatch(p1,2)
 local success,why=nil,nil;r._resolveCatch=function(_,result,reason) success=result;why=reason end
 now=r.catch.opensAt+r.catch.window+Config.Catch.Grace+1;r:HandleCatchInput(p1,now);assert(success==false and why=="late")
 local r2,q1=makeRound();r2:_beginCatch(q1,2);success=nil
 r2._resolveCatch=function(self,result) success=result;self.acc=self.catch.accuracy end
 now=r2.catch.opensAt-Config.Catch.EarlyTolerance*0.5;r2:HandleCatchInput(q1,now);assert(success==true and r2.acc==1)
end)
check("valid catch is accepted inside server window",function()
 local r,p1=makeRound();r:_beginCatch(p1,2);now=r.catch.opensAt+0.1;local success=nil
 r._resolveCatch=function(_,result) success=result end;r:HandleCatchInput(p1,now);assert(success==true)
end)
check("every catch speeds up that player's next pirate (window and lead)",function()
 local r,p1,p2=makeRound();assert(r:_catchesLeft(p1)==Config.Catch.MaxPerPlayer)
 r:_beginCatch(p1,2);local w1=r.catch.window;local lead1=r.catch.opensAt-r.catch.startedAt
 assert(r.catchesUsed[p1]==nil,"opening a window does not use a catch");now=r.catch.opensAt+0.05;r:HandleCatchInput(p1,now)
 assert(r.catchesUsed[p1]==1 and r:_catchesLeft(p1)==Config.Catch.MaxPerPlayer-1);assert(r:_catchesLeft(p2)==Config.Catch.MaxPerPlayer)
 assert(r.gameTable:GetSeats()[1]:GetAttribute("CatchLevel")==1,"seat shows the catch level")
 r.resolving=false;r:_beginCatch(p1,6);local w2=r.catch.window;local lead2=r.catch.opensAt-r.catch.startedAt
 assert(w2<w1*0.85,"window shrinks: "..w1.." -> "..w2);assert(lead2<lead1,"pirate comes out sooner")
 local personalOnly=Config.catchWindow(0,4,10,3);assert(personalOnly<Config.catchWindow(0,4,10,2))
end)
check("after MaxPerPlayer catches the next pirate is enraged: no window, eliminated",function()
 local r,p1,p2=makeRound();r.catchesUsed[p1]=Config.Catch.MaxPerPlayer;local before=#delayed
 r:_beginCatch(p1,2);assert(r.catch and r.catch.spent,"spent catch record");assert(r.catch.opensAt==math.huge)
 local token=r.catch.token;r:HandleCatchInput(p1,now);r:HandleCatchInput(p1,now);r:HandleCatchInput(p1,now);assert(r.catch and r.catch.token==token,"taps are ignored")
 assert(#delayed==before+1);delayed[#delayed]()
 assert(r.catch==nil);assert(not r.isParticipant[p1],"eliminated");assert(r.pirateOuts==1)
 local payload=services.ReplicatedStorage.CursedBarrel.Remotes.CatchResult.last[2];assert(payload.reason=="spent" and payload.success==false)
end)
check("catch window shrinks with every catch and never below the minimum",function()
 local last=math.huge
 for n=0,12 do local w=Config.catchWindow(n,4,10,n);assert(w<=last);assert(w>=Config.Catch.MinWindow);last=w end
 assert(Config.catchWindow(0,4,10)>Config.catchWindow(1,4,10))
 assert(Config.Catch.Grace<=0.15,"late grace must stay small")
 for n=0,10 do assert(Config.catchLead(n)>=Config.Catch.MinLead) end
 assert(Config.Catch.MinLead>=0.8,"the stab motion (<=0.75s) must land before the pirate")
 assert(Config.Catch.MaxPerPlayer>=2 and Config.Catch.MaxPerPlayer<=10)
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
-- AI 선원 흉내. RoundService 가 쓰는 만큼만 갖춘 표 (BotService.Bot 과 같은 모양)
local botId=0
local function makeBot(skill,brave)
 botId=botId+1
 local attrs={}
 return {IsBot=true,UserId=-botId,Name="AI_"..botId,DisplayName="AI "..botId,skill=skill or 0.5,brave=brave or 0.3,
  GetAttribute=function(_,k) return attrs[k] end,SetAttribute=function(_,k,v) attrs[k]=v end}
end
local function makeTable(n,typeName,slotCount,loadProfiles,botCount)
 local players={};local seats={};local seatOf={};local playerOf={}
 for i=1,n+(botCount or 0) do
  local q
  if i<=n then nextId=nextId+1;q=player(nextId);if loadProfiles then Profiles:_load(q) end else q=makeBot() end
  players[i]=q
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
 function t:_testSeat(q,seat)
  assert(not playerOf[seat],"seat taken");seatOf[q]=seat;playerOf[seat]=q;self.RosterChanged:Fire(self,q,true)
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
 assert(r:GetCurrentPlayer()==b);r.catchesUsed[b]=Config.Catch.MaxPerPlayer;table.clear(r.dangerSlots);r.dangerSlots[2]=true
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

check("forfeit win pays half the win reward and half the pot; the other half carries over",function() withScheduler(function()
 local r,t,players=makeTable(2,"Standard4",16,true)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 local a,b=r.participants[1],r.participants[2];local pa=Profiles:Get(a);local wins,games,streak,coins=pa.wins,pa.games,pa.streak,pa.coins
 local pot=r.pot;assert(pot>0)
 t:RemovePlayer(b);assert(t.state=="RoundEnding")
 assert(t.model:GetAttribute("WinForfeit")==true);assert(pa.wins==wins and pa.streak==streak);assert(pa.games==games+1)
 local share=Config.ForfeitWin.RewardShare;local half=math.floor(pot*share)
 assert(pa.coins==coins+math.floor(Config.Economy.WinReward*share)+half,("half reward: got %d, expected %d"):format(pa.coins-coins,math.floor(Config.Economy.WinReward*share)+half))
 assert(r.carry==pot-half,"the rest of the pot carries over")
 local payload=services.ReplicatedStorage.CursedBarrel.Remotes.PresentationCue.last
 assert(payload[1]=="Win" and payload[3].forfeit and payload[3].pot==half and payload[3].carry==pot-half)
 local pb=Profiles:Get(b);assert(pb.games==0,"the leaver gets no completion")
 -- 다음 판은 이월된 금액을 얹고 시작한다
 local c=player(nextId+1);nextId=nextId+1
 assert(runUntil(function() return t.state=="Waiting" end))
 local seat;for _,x in ipairs(t:GetSeats()) do if not t:GetPlayerOfSeat(x) then seat=x end end;t:_testSeat(c,seat)
 assert(runUntil(function() return playing(t) end));assert(r.pot>=Config.Pot.Base+(pot-half),"carried pot is added");assert(r.carry==0)
 assert(t.model:GetAttribute("PotCarry")==pot-half)
end) end)

check("pirate elimination gives a full win with pot",function() withScheduler(function()
 local r,t=makeTable(2,"Standard4",16,true)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 local a,b=r.participants[1],r.participants[2];table.clear(r.dangerSlots)
 assert(r:HandlePick(a,1,"test")==nil);assert(runUntil(function() return not r.resolving end))
 r.catchesUsed[b]=Config.Catch.MaxPerPlayer;table.clear(r.dangerSlots);r.dangerSlots[2]=true
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

local function simulate(trials,seed,catchRate,leaveRate,withBots)
 local random=rng(seed)
 local stats={rounds=0,catches=0,eliminated=0,brave=0,forfeits=0,cards=0,maxCatch=0,maxPicks=0}
 for trial=1,trials do
  local typeName=({"Standard4","Duo2","Party6","Blitz4","PartyCards6"})[trial%5+1]
  local preset=TableConfig.Types[typeName]
  local n=math.max(2,math.min(preset.SeatCount,2+trial%preset.SeatCount))
  local bots=0
  if withBots then bots=math.max(1,n-1);n=1 end
  local r,t,players,used=makeTable(n,typeName,preset.KnifeSlots,trial%4==0,bots)
  local started=false;local ended=false;local handled={}
  for iteration=1,6000 do
   if t.state=="Playing" then started=true end
   if started and (t.state=="RoundEnding" or t.state=="Resetting" or t.state=="Waiting") then ended=true;break end
   if playing(t) then
    -- 참가자 명단과 표가 서로 맞는지
    for _,q in ipairs(r.participants) do assert(r.isParticipant[q]) end
    for q,used in pairs(r.catchesUsed) do assert(used<=Config.Catch.MaxPerPlayer,"catch limit exceeded");if used>stats.maxCatch then stats.maxCatch=used end end
    assert(r.turnIndex>=0 and r.turnIndex<=#r.participants)
    local cur=r:GetCurrentPlayer()
    if r.catch and not r.catch.spent and not r.catch.resolved and not handled[r.catch] and not Config.isBot(r.catch.player) then
     handled[r.catch]=true
     if random()<catchRate then now=r.catch.opensAt+0.05;r:HandleCatchInput(r.catch.player,now);stats.catches=stats.catches+1 end
    elseif r.braveOffer and not handled[r.braveOffer] and not Config.isBot(r.braveOffer.player) then
     handled[r.braveOffer]=true
     if random()<0.5 then now=now+0.3;if r:AcceptBrave(r.braveOffer.player) then stats.brave=stats.brave+1 end end
    elseif cur and not r.resolving and not Config.isBot(cur) then
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
     local leaver=r.participants[1+math.floor(random()*#r.participants)]
     if not Config.isBot(leaver) then t:RemovePlayer(leaver);stats.forfeits=stats.forfeits+1 end
    end
    if withBots then assert(r.practice,"bot rounds are practice rounds") end
   end
   if not step() then break end
  end
  assert(ended,("round did not end (%s, %d players)"):format(typeName,n))
  stats.rounds=stats.rounds+1;stats.eliminated=stats.eliminated+(r.pirateOuts or 0)
  local winner=t.model:GetAttribute("WinnerUserId") or 0
  if winner<0 then stats.botWins=(stats.botWins or 0)+1 elseif winner>0 then stats.humanWins=(stats.humanWins or 0)+1 end
  if (r.picks or 0)>stats.maxPicks then stats.maxPicks=r.picks end
  table.clear(queue)
 end
 return stats
end

check("randomized full rounds always end (escalating catches, brave, cards, leavers)",function() withScheduler(function()
 local stats=simulate(160,20260922,0.75,0.01)
 assert(stats.maxCatch>=2 and stats.maxCatch<=Config.Catch.MaxPerPlayer);assert(stats.eliminated>0 and stats.brave>0 and stats.cards>0)
 print(("  simulated %d rounds · catches %d · pirate outs %d · brave %d · cards %d · leavers %d · longest %d picks"):format(stats.rounds,stats.catches,stats.eliminated,stats.brave,stats.cards,stats.forfeits,stats.maxPicks))
end) end)

check("reported bug: even if everyone always catches, every round still ends",function() withScheduler(function()
 local stats=simulate(120,77,1.0,0)
 assert(stats.rounds==120 and stats.maxCatch==Config.Catch.MaxPerPlayer)
 -- 한 사람이 MaxPerPlayer 번 잡은 뒤에는 다음 해적이 반드시 탈락시킨다. 그래서 판은 끝난다.
 assert(stats.maxPicks<400,"rounds must stay short, got "..stats.maxPicks)
 print(("  perfect catchers: %d rounds · catches %d · pirate outs %d · longest %d picks"):format(stats.rounds,stats.catches,stats.eliminated,stats.maxPicks))
end) end)

--------------------------------------------------
-- Phase 11 : 보물 폭발 · 이월 · AI 선원
--------------------------------------------------
check("treasure surge: pouch adds, kraken multiplies, pity resets",function()
 local r,p1=makeRound();r.pot=100;r.surgeMiss=5
 local rolls={0,0};r.random={NextNumber=function() return table.remove(rolls,1) or 0 end,NextInteger=function(_,lo) return lo end}
 local tier=r:_rollSurge(p1);assert(tier and tier.id=="pouch");assert(r.pot==100+math.floor(45*TableConfig.getRewardScale("PartyCards6")));assert(r.surgeMiss==0)
 local cue=services.ReplicatedStorage.CursedBarrel.Remotes.PresentationCue.last;assert(cue[1]=="Surge" and cue[3].amount>0 and cue[3].pot==r.pot)
 r.pot=200;rolls={0,0.999};tier=r:_rollSurge(p1);assert(tier.id=="kraken" and r.pot==500)
 r.pot=Config.Pot.Cap-10;rolls={0,0.999};r:_rollSurge(p1);assert(r.pot==Config.Pot.Cap,"surge respects the cap")
 rolls={0.99};local before=r.pot;assert(r:_rollSurge(p1)==nil and r.pot==before and r.surgeMiss==1,"a miss raises pity only")
end)
check("surge chance grows with pity but stays capped",function()
 local S=Config.Pot.Surge;assert(S.Chance<S.MaxChance)
 assert(S.Chance+S.PityStep*100>S.MaxChance,"pity reaches the cap");local w=0;for _,t in ipairs(S.Tiers) do w=w+t.weight end;assert(w>0)
end)
check("carry-over is capped and a round where everyone leaves carries the whole pot",function()
 local r=makeRound();r.carry=Config.Pot.CarryCap-5;r:_carryOver(100);assert(r.carry==Config.Pot.CarryCap)
 local r2=makeRound();r2.pot=77;r2.settled=false;r2.countdownToken=1;r2.gameTable.ClearSeatFlags=function() end;r2.gameTable.RefreshBarrelSkin=function() end
 r2:_finishRound("test");assert(r2.carry==77)
end)
check("AI crew cannot be sabotaged and are not listed as opponents",function()
 local r,p1,p2=makeRound();local bot=makeBot();table.insert(r.participants,bot);r.isParticipant[bot]=true
 local ok,why=r:CanSabotage(p1,bot);assert(not ok and why==Config.RejectMessages.NoTarget)
 for _,o in ipairs(r:GetOpponents(p1)) do assert(not Config.isBot(o)) end;assert(#r:GetOpponents(p1)==1)
end)
check("AI takes its own turn, picks a free slot and its catches use the server rules",function() withScheduler(function()
 local r,t,players=makeTable(1,"Standard4",16,true,2)
 assert(runUntil(function() return playing(t) and not r.resolving end));assert(r.practice and t.model:GetAttribute("Practice")==true)
 local human=players[1];local picks=0;local seen=0
 for _=1,400 do
  if t.state~="Playing" then break end
  local cur=r:GetCurrentPlayer()
  if cur==human and not r.resolving and not r.catch then table.clear(r.dangerSlots);r._ensureDanger=function() end;now=now+0.3;assert(r:HandlePick(human,t:GetFreeSlotIndices()[1],"t")==nil) end
  if cur and Config.isBot(cur) then seen=seen+1 end
  if not step() then break end
  picks=r.picks
 end
 assert(seen>0 and picks>1,"AI took turns")
end) end)
check("solo player + AI: every round ends; AI are practice rounds with reduced pay and no win record",function() withScheduler(function()
 local stats=simulate(60,4242,0.7,0.005,true)
 assert(stats.rounds==60);assert((stats.botWins or 0)>0 and (stats.humanWins or 0)>0,"both sides can win")
 print(("  solo+AI: %d rounds · AI wins %d · human wins %d · longest %d picks"):format(stats.rounds,stats.botWins or 0,stats.humanWins or 0,stats.maxPicks))
end) end)
check("practice win pays reduced coins and never touches wins, streak or ranking",function() withScheduler(function()
 local r,t,players=makeTable(1,"Standard4",16,true,1)
 assert(runUntil(function() return playing(t) and not r.resolving end))
 local human,bot=players[1],players[2];local pa=Profiles:Get(human);local wins,streak,coins=pa.wins,pa.streak,pa.coins
 local ranked="none";local old=cache.RankingService.RecordRound;cache.RankingService.RecordRound=function(_,_,_,winner) ranked=winner end
 local pot=r.pot;r:_eliminate(bot)
 assert(runUntil(function() return t.state=="RoundEnding" end));cache.RankingService.RecordRound=old
 assert(pa.wins==wins and pa.streak==streak,"no win record vs AI");assert(ranked==nil,"no ranking vs AI")
 local expected=math.floor(Config.Economy.WinReward*Config.Bots.RewardScale)+pot
 assert(pa.coins-coins==expected,("practice pay %d, expected %d"):format(pa.coins-coins,expected))
 assert(pot<=math.ceil(Config.Pot.Base*Config.Bots.RewardScale)+Config.Pot.PerPick,"pot is scaled too")
end) end)
check("if the human leaves, an AI-only table closes at once and half the pot carries over",function() withScheduler(function()
 local r,t,players=makeTable(1,"Standard4",16,true,2)
 assert(runUntil(function() return playing(t) end));local pot=r.pot
 t:RemovePlayer(players[1]);assert(t.state=="RoundEnding","closed immediately")
 assert((t.model:GetAttribute("WinnerUserId") or 0)<0,"an AI is shown as the winner");assert(r.carry==math.floor(pot*0.5))
end) end)
check("stab motions are cosmetic skins with a free default and a robux item",function()
 assert(Config.Skins.PlayerAttributes.Stab=="StabSkin");assert(Config.Skins.Stab[1].id=="classic" and Config.isFreeSkin(Config.Skins.Stab[1]))
 local robux=0;for _,skin in ipairs(Config.Skins.Stab) do assert(skin.style and skin.color);if skin.robux then robux=robux+1 end end;assert(robux>=1)
 local q=player(34);Profiles:_load(q);local d=Profiles:Get(q);assert(d.owned.Stab.classic and d.equipped.Stab=="classic");assert(not d.owned.Stab.ember_slam)
end)

check("every stab motion lands before the pirate can appear",function()
 local Stab=loadModule("StabMotion")
 for _,skin in ipairs(Config.Skins.Stab) do
  for _,w in ipairs({0.05,0.1,0.2,0.42,1}) do
   local plan=Stab.plan(skin.style,w);assert(plan.style==skin.style,"unknown style "..skin.style)
   assert(plan.total<=Stab.MaxDuration,("%s %.2f takes %.3f"):format(skin.style,w,plan.total))
   for i=2,#plan.hits do assert(plan.hits[i].t>plan.hits[i-1].t) end
  end
 end
 assert(Stab.MaxDuration<Config.Catch.MinLead)
end)
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
