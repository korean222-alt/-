-- Phase 9: settings, weekly/season claims, parties, rejoin and cards.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Badges=game:GetService("BadgeService")
local Analytics=game:GetService("AnalyticsService")
local Shared=RS.CursedBarrel.Shared
local Config=require(Shared.GameConfig)
local Release=require(Shared.ReleaseConfig)
local Utility=require(Shared.Utility)
local FX=require(Shared.PremiumFX)
local Profiles=require(script.Parent.ProfileService)
local Tables=require(script.Parent.TableService)
local Rounds=require(script.Parent.RoundService)
local Service={parties={},invites={},badgePending={},badgeDone={},limits=Utility.RateLimiter.new(0.25)}
local function remote(name)
 local r=RS.CursedBarrel.Remotes:FindFirstChild(name)
 if not r then r=Instance.new("RemoteEvent");r.Name=name;r.Parent=RS.CursedBarrel.Remotes end
 return r
end
local function safeId(value)
 return typeof(value)=="number" and value==value and value%1==0 and math.abs(value)<9e15
end
function Service:partyState(player)
 local id=player:GetAttribute("PartyId");local party=id and self.parties[id]
 local result={leader=party and party.leader.UserId or 0,members={},invitations={}}
 if party then for p in pairs(party.members) do if p.Parent==Players then table.insert(result.members,{id=p.UserId,name=p.DisplayName}) end end end
 for leader,expires in pairs(self.invites[player] or {}) do
  if leader.Parent==Players and expires>os.clock() then table.insert(result.invitations,{id=leader.UserId,name=leader.DisplayName}) end
 end
 return result
end
function Service:sync(player,message)
 if player.Parent~=Players then return end
 local p=Profiles:Get(player);if not p then return end
 Profiles:_rollWeekly(p)
 local list={};for _,other in ipairs(Players:GetPlayers()) do if other~=player then table.insert(list,{id=other.UserId,name=other.DisplayName}) end end
 self.state:FireClient(player,{
  settings=p.settings,tutorialDone=p.tutorialDone,weekly=p.weekly,season=p.season,
  party=self:partyState(player),players=list,message=message,writable=Profiles:CanPurchase(player),
  privateServer=game.PrivateServerId~="",version=Release.Version,
 })
end
function Service:leaveParty(player)
 local id=player:GetAttribute("PartyId");local party=id and self.parties[id]
 player:SetAttribute("PartyId",nil)
 if not party then return end
 party.members[player]=nil
 if party.leader==player then
  self.parties[id]=nil
  for p in pairs(party.members) do p:SetAttribute("PartyId",nil);self:sync(p,"파티장이 나가 파티가 종료되었습니다 / Party ended") end
 else
  for p in pairs(party.members) do self:sync(p) end
 end
end
function Service:invite(player,targetId)
 if not safeId(targetId) then return end
 local target=Players:GetPlayerByUserId(targetId)
 if not target or target==player or target:GetAttribute("PartyId") then return end
 local id=player:GetAttribute("PartyId")
 if not id then
  id=tostring(player.UserId);self.parties[id]={leader=player,members={[player]=true}};player:SetAttribute("PartyId",id)
 end
 local party=self.parties[id];if not party or party.leader~=player then return end
 self.invites[target]=self.invites[target] or {};self.invites[target][player]=os.clock()+60
 self:sync(target,"파티 초대가 왔습니다 / Party invitation");self:sync(player,"초대를 보냈습니다 / Invitation sent")
end
function Service:accept(player,leaderId)
 if not safeId(leaderId) or player:GetAttribute("PartyId") then return end
 local leader=Players:GetPlayerByUserId(leaderId);local expires=leader and (self.invites[player] or {})[leader]
 if not expires or expires<os.clock() then return end
 local party=self.parties[tostring(leaderId)];if not party then return end
 local count=0;for _ in pairs(party.members) do count+=1 end
 if count>=6 then self:sync(player,"파티가 가득 찼습니다 / Party full");return end
 party.members[player]=true;player:SetAttribute("PartyId",tostring(leaderId));self.invites[player]=nil
 for p in pairs(party.members) do self:sync(p) end
end
function Service:rejoin(player,model)
 local t=typeof(model)=="Instance" and Tables:GetTableFromModel(model)
 if not t or not t:IsJoinable() then return false end
 -- "다음 판 참가"를 직접 눌렀다면 자리를 비운 것이 아니다.
 if player:GetAttribute("AFK")==true then player:SetAttribute("AFK",false) end
 local h=Utility.getHumanoid(player);local root=h and h.RootPart
 if not root or h.Health<=0 or h.SeatPart then return false end
 local free=t:GetFreeSeats();local seat=free[1]
 if not seat or (root.Position-seat.Position).Magnitude>80 then return false end
 root.CFrame=seat.CFrame*CFrame.new(0,3,0);seat:Sit(h);return true
end
function Service:settings(player,key,value)
 local p=Profiles:Get(player);if not p or typeof(key)~="string" then return end
 local default=Release.Settings[key]
 if default==nil or typeof(value)~=typeof(default) then return end
 if typeof(value)=="number" then if value~=value then return end;value=math.clamp(value,0,1) end
 if key=="language" and value~="ko" and value~="en" and value~="Auto" then return end
 if key=="quality" and value~="Low" and value~="High" and value~="Auto" then return end
 p.settings[key]=value;player:SetAttribute("Setting_"..key,value);Profiles:_touch(player)
end
function Service:onRequest(player,action,a,b,c,d,e)
 if not self.limits:check(player.UserId) or typeof(action)~="string" then return end
 local p=Profiles:Get(player);if not p then return end
 local message=nil
 if action=="sync" then
 elseif action=="setting" then self:settings(player,a,b)
 elseif action=="tutorial" then p.tutorialDone=true;player:SetAttribute("TutorialDone",true);Profiles:_touch(player)
 elseif action=="weekly" and typeof(a)=="string" then message=Profiles:ClaimWeekly(player,a) and "보상 지급 / Reward claimed" or "조건 미달 또는 이미 지급 / Not claimable"
 elseif action=="season" and safeId(a) then message=Profiles:ClaimSeason(player,a) and "시즌 보상 지급 / Season reward claimed" or "조건 미달 또는 이미 지급 / Not claimable"
 elseif action=="invite" then self:invite(player,a);return
 elseif action=="accept" then self:accept(player,a);return
 elseif action=="leaveParty" then self:leaveParty(player)
 elseif action=="afk" and typeof(a)=="boolean" then
  player:SetAttribute("AFK",a);if a then local t=Tables:GetTableOfPlayer(player);if t then t:RemovePlayer(player) end end
 elseif action=="rejoin" then message=self:rejoin(player,a) and "참가했습니다 / Joined" or "테이블이 대기 상태일 때 가까이에서 눌러 주세요 / Join a nearby waiting table"
 elseif action=="card" then
  local t=typeof(a)=="Instance" and Tables:GetTableFromModel(a)
  local r=t and Rounds:GetRound(t)
  if r and typeof(b)=="string" and Release.Cards[b] then
   local ok,why=r:UseCard(player,b,c,d,e);message=why
  end
 else return end
 self:sync(player,message)
end
function Service:badges(player,p)
 self.badgePending[player]=self.badgePending[player] or {};self.badgeDone[player]=self.badgeDone[player] or {}
 for key,id in pairs(Release.Badges) do
  if id>0 and p.achievements[key] and not self.badgePending[player][key] and not self.badgeDone[player][key] then
   self.badgePending[player][key]=true
   task.spawn(function()
    local ok,has=pcall(Badges.UserHasBadgeAsync,Badges,player.UserId,id)
    if ok and not has then ok,has=pcall(Badges.AwardBadgeAsync,Badges,player.UserId,id) end
    if self.badgePending[player] then self.badgePending[player][key]=nil end
    if ok and has and self.badgeDone[player] then self.badgeDone[player][key]=true end
   end)
  end
 end
end
function Service:bindTable(t)
 local function chairs()
  for _,seat in ipairs(t:GetSeats()) do
   local p=t:GetPlayerOfSeat(seat)
   local id=p and p:GetAttribute("ChairSkin") or "classic"
   if seat:GetAttribute("RenderedChair")~=id then
    seat:SetAttribute("RenderedChair",id);FX.chair(seat,Config.findSkin("Chair",id))
   end
  end
 end
 t.cleaner:add(t.RosterChanged:Connect(chairs));chairs()
end
function Service:Start()
 self.request=remote("VoyageRequest");self.state=remote("VoyageState")
 self.request.OnServerEvent:Connect(function(player,...)
  local ok,err=pcall(self.onRequest,self,player,...);if not ok then warn("[CursedBarrel] Voyage: "..tostring(err)) end
 end)
 Profiles.ProfileChanged:Connect(function(player,p)
  for k,v in pairs(p.settings) do if Release.Settings[k]~=nil then player:SetAttribute("Setting_"..k,v) end end
  player:SetAttribute("TutorialDone",p.tutorialDone)
  self:badges(player,p)
  local t=Tables:GetTableOfPlayer(player)
  if t then local seat=t:GetSeatOfPlayer(player);local id=p.equipped.Chair
   if seat and seat:GetAttribute("RenderedChair")~=id then seat:SetAttribute("RenderedChair",id);FX.chair(seat,Config.findSkin("Chair",id)) end
  end
 end)
 Tables.TableAdded:Connect(function(t) self:bindTable(t) end)
 for _,t in ipairs(Tables:GetAllTables()) do self:bindTable(t) end
 local joinedAt={}
 local function join(p)
  joinedAt[p]=os.clock()
  task.spawn(function()
   for _,other in ipairs(Players:GetPlayers()) do
    if other~=p then
     local ok,friends=pcall(p.IsFriendsWithAsync,p,other.UserId)
     if ok and p.Parent==Players and other.Parent==Players then p:SetAttribute("Friend_"..other.UserId,friends);other:SetAttribute("Friend_"..p.UserId,friends) end
    end
   end
  end)
 end
 Players.PlayerAdded:Connect(join);for _,p in ipairs(Players:GetPlayers()) do join(p) end
 Players.PlayerRemoving:Connect(function(p)
  local duration=os.clock()-(joinedAt[p] or os.clock());joinedAt[p]=nil
  task.spawn(function() pcall(Analytics.LogCustomEvent,Analytics,p,"SessionDuration",duration) end)
  self:leaveParty(p);self.invites[p]=nil;self.badgePending[p]=nil;self.badgeDone[p]=nil;self.limits:forget(p.UserId)
  for _,other in ipairs(Players:GetPlayers()) do other:SetAttribute("Friend_"..p.UserId,nil);if self.invites[other] then self.invites[other][p]=nil end end
 end)
 -- Server-owned completion metrics; no personal text or raw client event ingestion.
 local lastGames={}
 Profiles.ProfileChanged:Connect(function(p,data)
  local prior=lastGames[p];lastGames[p]=data.games
  if prior and data.games>prior then task.spawn(function()
   pcall(Analytics.LogCustomEvent,Analytics,p,"RoundCompleted",1,{mode="all",version=Release.Version})
   if data.games==1 then pcall(Analytics.LogCustomEvent,Analytics,p,"FirstRoundCompleted",1) end
  end) end
 end)
 Players.PlayerRemoving:Connect(function(p) lastGames[p]=nil end)
end
return Service
