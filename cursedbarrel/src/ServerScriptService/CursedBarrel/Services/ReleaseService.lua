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
local Bots=require(script.Parent.BotService)
local Service={parties={},invites={},badgePending={},badgeDone={},limits=Utility.RateLimiter.new(0.25),practiceLimits=Utility.RateLimiter.new(1),settingLimits=Utility.RateLimiter.new(0.2)}
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
-- Phase 24 : "연습 한 판" 은 결과를 반드시 돌려준다 (요청 제한 · 자료 로딩 중이어도). 안내창은 이 답을 보고 닫힌다.
function Service:practice(player)
 local reply=self.practiceResult
 if not self.practiceLimits:check(player.UserId) then reply:FireClient(player,false,"잠시 후 다시 눌러 주세요 / Please try again in a moment");return end
 if not Profiles:Get(player) then reply:FireClient(player,false,"자료를 불러오는 중이에요. 잠시 후 다시 눌러 주세요 / Loading your data, try again soon");return end
 local ok,why=Bots:SeatForPractice(player)
 reply:FireClient(player,ok==true,why)
 self:sync(player,why)
end
-- Phase 24 : 설정은 화면에서 모아 둔 마지막 값들을 한 번에 받는다 (연타한 음량이 요청 제한에 버려져 화면과 저장값이 어긋나던 문제).
--   다른 요청과 제한을 따로 세고, 처리한 뒤 확정된 값을 돌려보낸다(sync). 화면은 그 값으로 다시 그린다.
function Service:settingsBatch(player,batch)
 if typeof(batch)~="table" or not self.settingLimits:check(player.UserId) or not Profiles:Get(player) then return end
 local count=0
 for key,value in pairs(batch) do
  count+=1;if count>12 then break end
  if typeof(key)=="string" then self:settings(player,key,value) end
 end
 self:sync(player)
end
function Service:onRequest(player,action,a,b,c,d,e)
 if action=="practice" then self:practice(player);return end
 if action=="settings" then self:settingsBatch(player,a);return end
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
-- Phase 12 : 친구 초대 보상. 초대 링크로 처음 들어온 사람과 초대한 사람이 같은 서버에 있으면 둘 다 받는다.
-- (한 사람을 두 번 초대해도 한 번만 · 초대한 사람은 하루 GameConfig.Referral.DailyCap 번까지)
-- Phase 24 : 들어올 때 한 번만 보던 것을 "대기 → 두 사람 자료가 다 읽히면 처리"로 바꿨다.
--   초대한 사람이 아직 자료를 읽는 중이면 기다렸다가, 그 사람의 자료가 준비되는 순간 다시 처리한다.
--   (한 사람에게 두 번 주지 않는 기록 host.referrals · newcomer.referralClaimed 는 그대로 쓴다)
Service.referralPending={} -- [새로 온 Player] = 초대한 사람 UserId
function Service:referral(player)
 local R=Config.Referral;if not R or not R.Enabled then return end
 local ok,join=pcall(player.GetJoinData,player)
 local refId=ok and typeof(join)=="table" and tonumber(join.ReferredByPlayerId) or 0
 if not refId or refId<=0 or refId==player.UserId then return end
 local newcomer=Profiles:Get(player)
 if not newcomer or newcomer.referralClaimed or (newcomer.games or 0)>0 then return end
 self.referralPending[player]=refId
 self:tryReferral(player)
end
function Service:tryReferral(player)
 local R=Config.Referral;local refId=self.referralPending[player]
 if not R or not R.Enabled or not refId then return end
 local newcomer=Profiles:Get(player)
 if not newcomer or newcomer.referralClaimed or player.Parent~=Players then self.referralPending[player]=nil;return end
 local inviter=Players:GetPlayerByUserId(refId);local host=inviter and Profiles:Get(inviter)
 if not host then return end -- 초대한 사람이 없거나 아직 자료를 읽는 중 : 준비되면 다시 부른다
 self.referralPending[player]=nil
 local key=tostring(player.UserId)
 if host.referrals[key] then return end
 local today=Utility.today()
 if host.inviteDay~=today then host.inviteDay=today;host.inviteCount=0 end
 newcomer.referralClaimed=true;newcomer.coins+=R.NewcomerCoins;Profiles:_touch(player)
 self:sync(player,("친구의 초대로 오셨네요! 환영 선물 +%d 코인"):format(R.NewcomerCoins))
 if host.inviteCount>=R.DailyCap then return end
 host.referrals[key]=true;host.inviteCount+=1;host.coins+=R.InviterCoins;Profiles:_touch(inviter)
 self:sync(inviter,("%s 님이 초대를 받고 왔습니다! +%d 코인"):format(player.DisplayName,R.InviterCoins))
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
 self.request=remote("VoyageRequest");self.state=remote("VoyageState");self.practiceResult=remote("PracticeResult")
 self.request.OnServerEvent:Connect(function(player,...)
  local ok,err=pcall(self.onRequest,self,player,...);if not ok then warn("[CursedBarrel] Voyage: "..tostring(err)) end
 end)
 Profiles.ProfileChanged:Connect(function(player,p)
  -- Phase 24 : 이 사람을 기다리던 친구 초대 보상이 있으면 지금 처리한다
  for newcomer,refId in pairs(self.referralPending) do
   if refId==player.UserId then task.spawn(function() pcall(self.tryReferral,self,newcomer) end) end
  end
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
  -- Phase 12 : 자료를 다 읽은 뒤 친구 초대 보상을 확인한다
  task.spawn(function()
   for _=1,60 do if p.Parent~=Players or p:GetAttribute("ProfileLoaded")==true then break end;task.wait(0.5) end
   if p.Parent==Players then pcall(self.referral,self,p) end
  end)
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
  self:leaveParty(p);self.invites[p]=nil;self.referralPending[p]=nil;self.badgePending[p]=nil;self.badgeDone[p]=nil;self.limits:forget(p.UserId);self.practiceLimits:forget(p.UserId);self.settingLimits:forget(p.UserId)
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
