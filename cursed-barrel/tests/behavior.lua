local count=0
local function check(name,fn)
 local ok,err=pcall(fn);if not ok then error("FAIL "..name..": "..tostring(err)) end
 count=count+1;print("PASS "..name)
end
local function copy(t)
 if type(t)~="table" then return t end
 local o={};for k,v in pairs(t) do o[k]=copy(v) end;return o
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
vectorMeta.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X^2+v.Y^2+v.Z^2) end end
Color3={fromRGB=function(...) return {...} end,new=function(...) return {...} end}
Enum=setmetatable({},{__index=function(t,k) local v=setmetatable({},{__index=function(_,s) return s end});rawset(t,k,v);return v end})
Random={new=function(seed) return {NextInteger=function(_,lo,hi) return lo end} end}
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
 local env=setmetatable({script={Parent=parent}}, {__index=_G})
 env.require=function(ref)
  local key=type(ref)=="table" and ref.Name or ref
  if cache[key] then return cache[key] end
  cache[key]=loadModule(key);return cache[key]
 end
 return assert(load(source or SOURCES[name],name,"t",env))()
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
 epoch=epoch+86400;Profiles:_rollDaily(p,d);assert(d.coins==old+Config.Economy.DailyBonus);epoch=epoch-86400
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
 local r=setmetatable({gameTable=t,participants={p1,p2},roundRoster={p1,p2},isParticipant={[p1]=true,[p2]=true},cards={[p1]={skip=true,rotate=true,seal=true},[p2]={skip=true,rotate=true,seal=true}},afk={},forfeited={},bonuses={},turnIndex=1,turnToken=1,roundId=1,dangerSlots={[2]=true,[6]=true},random=Random.new(),turnCut={},sabotageUses={},phaseToken=1,catchToken=1,catchCount=0,barrelCycle=1,pickLimiter=Utility.RateLimiter.new(.2)},Round)
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
check("sealed slot is rejected then cleared on the next pick",function()
 local r,p1=makeRound();assert(r:UseCard(p1,"seal",3,1,1));assert(r:ValidatePick(p1,3));assert(r.gameTable:GetSlot(3):GetAttribute("Sealed"));r:_resolvePick(p1,1,"click");assert(r.sealed==nil);assert(not r.gameTable:GetSlot(3):GetAttribute("Sealed"))
end)
check("seal cannot consume last two available slots",function()
 local r,p1,_,used=makeRound();for i=3,8 do used[i]=true end;assert(not r:UseCard(p1,"seal",1,1,1));assert(r.cards[p1].seal)
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
