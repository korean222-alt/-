local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Tags=game:GetService("CollectionService")
local Input=game:GetService("UserInputService")
local SoundService=game:GetService("SoundService")
local Social=game:GetService("SocialService")
local player=Players.LocalPlayer
local package=RS:WaitForChild("CursedBarrel")
local Config=require(package.Shared.GameConfig)
local Release=require(package.Shared.ReleaseConfig)
local FX=require(package.Shared.PremiumFX)
local remotes=package:WaitForChild("Remotes")
local request=remotes:WaitForChild("VoyageRequest")
local stateRemote=remotes:WaitForChild("VoyageState")
local data=nil
local tab="watch"
local selected=nil
local locale="ko"
local lastInput=os.clock()
local afkSent=false
local function lang(ko,en) return locale=="en" and en or ko end
local function currentTable()
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 local node=h and h.SeatPart
 while node and node~=workspace do if Tags:HasTag(node,Config.Tags.Table) then return node end;node=node.Parent end
 return nil
end
local UIKit=require(package.Shared.UIKit)
local gui=Instance.new("ScreenGui");gui.Name="CursedBarrel_Voyage";gui.DisplayOrder=22;gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.Parent=player.PlayerGui
-- Phase 14 : 만화풍 버튼 · 창 (UIKit)
local function button(parent,text,pos,size,callback,themeName)
 local b=UIKit.button(parent,{text=text,position=pos,size=size,theme=themeName or "blue",textSize=18})
 b.Activated:Connect(callback);return b
end
local voyage=UIKit.window(gui,{name="Voyage",title="항해 수첩",theme="teal",icon="🧭",size=Vector2.new(660,520)})
local panel=voyage.frame
local tabs=Instance.new("Frame");tabs.Position=UDim2.fromOffset(16,76);tabs.Size=UDim2.new(1,-32,0,44);tabs.BackgroundTransparency=1;tabs.Parent=panel
local scroll=Instance.new("ScrollingFrame");scroll.Position=UDim2.fromOffset(16,130);scroll.Size=UDim2.new(1,-32,1,-176);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=8;scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;scroll.CanvasSize=UDim2.new();scroll.Parent=panel
local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,10);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.HorizontalAlignment=Enum.HorizontalAlignment.Center;layout.Parent=scroll
local pad=Instance.new("UIPadding");pad.PaddingTop=UDim.new(0,6);pad.PaddingBottom=UDim.new(0,8);pad.Parent=scroll
local message=UIKit.label(panel,{text="",position=UDim2.new(0,16,1,-42),size=UDim2.new(1,-32,0,34),textSize=20,color=UIKit.Colors.Teal,stroke=3,zIndex=10})
local order=0
local function row(text,height)
 order+=1;local r=UIKit.card(scroll,{order=order,height=height or 70,theme="teal"})
 local l=UIKit.label(r,{text=text,position=UDim2.fromOffset(24,4),size=UDim2.new(1,-200,1,-8),textSize=19,alignX=Enum.TextXAlignment.Left,wrap=true});return r,l
end
local draw
local function refresh() request:FireServer("sync") end
local function action(r,text,fn) return button(r,text,UDim2.new(1,-160,0.5,-22),UDim2.fromOffset(146,44),fn,"blue") end
local function spectate(model)
 selected=model
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if h and h.SeatPart then return end
 player:SetAttribute("SpectateTableId",model:GetAttribute("TableId"));panel.Visible=false
end
-- Phase 15 : "카드" 탭은 걷어냈다 (파티 카드는 내 차례에 칼 고르는 창에서 바로 쓴다). 대신 짧은 "방법" 탭.
local tabDefs={{"watch","관전","Watch"},{"weekly","의뢰","Quests"},{"party","파티","Party"},{"guide","방법","How to"},{"settings","설정","Settings"}}
local tabButtons={}
for i,t in ipairs(tabDefs) do
 tabButtons[i]=button(tabs,t[2],UDim2.new((i-1)/5,3,0,0),UDim2.new(1/5,-6,1,0),function() tab=t[1];refresh();draw() end,"grey")
end
local function openVoyage()
 if panel.Visible then panel.Visible=false;return end
 voyage.open();refresh();draw()
end
local launcher,voyageDot=UIKit.railButton({name="VoyageButton",icon="🧭",caption="항해",theme="teal",order=6})
launcher.Activated:Connect(openVoyage)
-- Phase 15 : 받을 수 있는 주간 의뢰 · 시즌 보상이 있으면 항해 버튼 위에 빨간 동그라미
local function refreshVoyageDot() UIKit.setDot(voyageDot,player:GetAttribute("VoyageReady") or 0) end
player:GetAttributeChangedSignal("VoyageReady"):Connect(refreshVoyageDot);refreshVoyageDot()
local spectateExit=button(gui,"관전 종료",UDim2.new(1,-196,0.5,-60),UDim2.fromOffset(180,50),function() player:SetAttribute("SpectateTableId",nil);selected=nil end,"red");spectateExit.Visible=false
local rejoin=button(gui,"다음 판 참가",UDim2.new(1,-196,0.5,0),UDim2.fromOffset(180,50),function() if selected then request:FireServer("rejoin",selected) end end,"green");rejoin.Visible=false
function draw()
 for _,v in ipairs(scroll:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end;order=0
 for i,t in ipairs(tabDefs) do tabButtons[i].Text=lang(t[2],t[3]);UIKit.setTheme(tabButtons[i],t[1]==tab and "gold" or "grey") end
 if not data then local _,l=row(lang("자료를 불러오는 중…","Loading…"));l.Size=UDim2.new(1,-20,1,-10);return end
 if tab=="watch" then
  for _,t in ipairs(Tags:GetTagged(Config.Tags.Table)) do
   if t:IsDescendantOf(workspace) then
    local r=row((t:GetAttribute("DisplayName") or t.Name).."  👥 "..tostring(t:GetAttribute("SeatedCount") or 0).."/"..tostring(t:GetAttribute("SeatCount") or 0))
    action(r,lang("관전","Spectate"),function() spectate(t) end)
   end
  end
 elseif tab=="weekly" then
  for _,q in ipairs(Release.Weekly) do
   local progress=(data.weekly.progress or {})[q.id] or 0
   local r=row(lang(q.text,q.en).."\n"..progress.." / "..q.goal.." · +"..q.reward)
   action(r,data.weekly.claimed[q.id] and "✓" or lang("받기","Claim"),function() request:FireServer("weekly",q.id) end)
  end
  local _,l=row(lang("시즌: 용의 항로","Season: Dragon Tide").." · "..(data.season.xp or 0).." XP",54);l.Size=UDim2.new(1,-30,1,-8)
  for i,tier in ipairs(Release.Season.Tiers) do
   local reward=tier.coins and (tier.coins..lang(" 코인"," coins")) or Config.findSkin(tier.kind,tier.skin).name
   local rr=row(tier.xp.." XP\n"..reward)
   action(rr,data.season.claimed[tostring(i)] and "✓" or lang("받기","Claim"),function() request:FireServer("season",i) end)
  end
 elseif tab=="party" then
  local r=row(lang("친구 +10% · 파티 +5%","Friend +10% · Party +5%"),70)
  action(r,lang("친구 초대","Invite friends"),function() task.spawn(function() pcall(Social.PromptGameInvite,Social,player) end) end)
  for _,invite in ipairs(data.party.invitations) do
   local rr=row(invite.name..lang(" 님의 파티 초대"," invited you"));action(rr,lang("수락","Accept"),function() request:FireServer("accept",invite.id) end)
  end
  for _,member in ipairs(data.party.members) do local _,l=row("✓ "..member.name,38);l.Size=UDim2.new(1,-20,1,-10) end
  if data.party.leader~=0 then local rr=row(lang("현재 파티","Current party"));action(rr,lang("나가기","Leave"),function() request:FireServer("leaveParty") end) end
  for _,other in ipairs(data.players) do local rr=row(other.name);action(rr,lang("파티 초대","Invite to party"),function() request:FireServer("invite",other.id) end) end
 elseif tab=="guide" then
  -- 게임 방법 · 방해 · 카드 · 수첩 쓰는 법 (한 줄씩)
  for _,line in ipairs({
   {"🎯 내 차례에 칼 꽂을 자리를 고르세요","🎯 On your turn, pick a slot"},
   {"☠ 해적이 나오면 눌러서 잡기! 먼저 누르면 탈락","☠ Tap when the pirate pops out! Too early = out"},
   {"🔥 한 번 더 : 더 찌를수록 현상금이 커져요","🔥 Once more: every extra stab grows the bounty"},
   {"👑 4인 이상 테이블은 마지막 1명이 전부 가져가요","👑 4+ seat tables: the last survivor takes it all"},
   {"😈 방해 : 게임 중 왼쪽 😈 버튼 → 상대 고르기 → 사용","😈 Sabotage: in a game, tap 😈 → pick a rival → use"},
   {"🃏 카드 : 카드 테이블에서 내 차례에 칼 고르는 창 위 버튼","🃏 Cards: on your turn at the card table, above the slot picker"},
   {"🧭 수첩 : 관전 · 주간 의뢰 · 파티 · 설정","🧭 Voyage: spectate · weekly quests · party · settings"},
  }) do local _,l=row(lang(line[1],line[2]),52);l.Size=UDim2.new(1,-30,1,-8) end
 elseif tab=="settings" then
  local set=data.settings
  for _,def in ipairs({{"music","음악","Music"},{"sfx","효과음","Effects"}}) do
   local value=set[def[1]] or 0;local r=row(lang(def[2],def[3]).." "..math.floor(value*100).."%")
   action(r,"+25% / 0",function() request:FireServer("setting",def[1],value>=1 and 0 or math.min(1,value+0.25)) end)
  end
  for _,def in ipairs({{"shake","화면 흔들림","Camera shake"},{"reducedFX","번쩍임·연출 줄이기","Reduce effects"},{"camera","테이블 카메라","Table camera"},{"wide","화각 넓게","Wide view"}}) do
   local key=def[1];local r=row(lang(def[2],def[3]));action(r,set[key] and "ON" or "OFF",function() request:FireServer("setting",key,not set[key]) end)
  end
  local q=row(lang("이펙트 품질","Effect quality"));action(q,set.quality,function() request:FireServer("setting","quality",({Auto="High",High="Low",Low="Auto"})[set.quality] or "Auto") end)
  local l=row(lang("언어","Language"));action(l,set.language,function() request:FireServer("setting","language",locale=="ko" and "en" or "ko") end)
  local a=row(lang("자리 비움","AFK"));action(a,player:GetAttribute("AFK") and "ON" or "OFF",function() request:FireServer("afk",not player:GetAttribute("AFK")) end)
 end
end
stateRemote.OnClientEvent:Connect(function(new)
 if typeof(new)~="table" then return end;data=new
 local chosen=new.settings.language;locale=chosen=="Auto" and (player.LocaleId:sub(1,2)=="ko" and "ko" or "en") or chosen
 message.Text=new.message or "";if panel.Visible then draw() end
end)
-- 자리 비움 해제. 서버 요청 제한에 걸려 한 번 사라져도, 돌아온 뒤 계속 입력이 있으면 다시 보낸다.
-- (설정에서 직접 켠 자리 비움은 건드리지 않는다. autoAfk 는 이 스크립트가 켠 경우에만 참이다)
local autoAfk=false
local afkClearAt=0
local function backFromAfk()
 lastInput=os.clock()
 if not autoAfk or os.clock()-afkClearAt<1 then return end
 if not afkSent and player:GetAttribute("AFK")~=true then autoAfk=false;return end
 afkClearAt=os.clock();afkSent=false;request:FireServer("afk",false)
end
Input.InputChanged:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Gamepad1 or input.UserInputType==Enum.UserInputType.Touch then backFromAfk() end
end)
Input.InputBegan:Connect(function(input,processed)
 backFromAfk()
 if not processed and (input.KeyCode==Enum.KeyCode.M or input.KeyCode==Enum.KeyCode.ButtonY) then openVoyage();if panel.Visible then game:GetService("GuiService").SelectedObject=tabButtons[1] end end
 if input.KeyCode==Enum.KeyCode.ButtonB and panel.Visible then panel.Visible=false end
end)
-- Presentation receives public, completed outcomes only.
remotes.PresentationCue.OnClientEvent:Connect(function(event,model,payload)
 if typeof(model)~="Instance" or not model.Parent or typeof(payload)~="table" then return end
 local body=model:FindFirstChild("Body",true);if not body then return end
 local actor=Players:GetPlayerByUserId(payload.userId or 0)
 -- Phase 11 : AI 선원은 Players 에 없다. 좌석에 적힌 UserId 로 몸을 찾는다.
 local actorCharacter=actor and actor.Character
 if not actorCharacter and (payload.userId or 0)<0 then
  for _,seat in ipairs(model:GetDescendants()) do
   if seat:IsA("Seat") and seat:GetAttribute("OccupantUserId")==payload.userId then
    local link=seat:FindFirstChild("BotCharacter")
    actorCharacter=(link and link.Value) or (seat.Occupant and seat.Occupant.Parent)
    if actorCharacter then break end
   end
  end
 end
 if event=="Pick" and not payload.danger then
  local skin=Config.findSkin("Knife",payload.knife or (actor and actor:GetAttribute("KnifeSkin")))
  if skin and skin.fx and skin.fx.theme then FX.burst(body.Position,skin,"Pick") end
 elseif event=="Win" then
  local skin=Config.findSkin("Victory",payload.skin)
  FX.burst(body.Position,skin,"Win")
  if actorCharacter then
   local head=actorCharacter:FindFirstChild("Head")
   if head then
    local character=actorCharacter
    local shoulder=character:FindFirstChild("RightShoulder",true) or character:FindFirstChild("Right Shoulder",true)
    if shoulder and shoulder:IsA("Motor6D") then
     local original=shoulder.C0
     game:GetService("TweenService"):Create(shoulder,TweenInfo.new(0.35),{C0=original*CFrame.Angles(0,0,math.rad(115))}):Play()
     task.delay(1.4,function() if shoulder.Parent then game:GetService("TweenService"):Create(shoulder,TweenInfo.new(0.4),{C0=original}):Play() end end)
    end
    local crown=Instance.new("BillboardGui");crown.Size=UDim2.fromOffset(90,58);crown.StudsOffset=Vector3.new(0,2,0);crown.MaxDistance=90;crown.Parent=head
    local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.Text="♛";text.TextSize=48;text.TextColor3=Color3.fromRGB(255,210,110);text.Parent=crown;game:GetService("Debris"):AddItem(crown,4)
   end
  end
 elseif event=="Eliminate" then
  FX.burst(body.Position,Config.findSkin("Elimination",payload.skin),"Eliminate")
  if payload.userId==player.UserId then selected=model;player:SetAttribute("SpectateTableId",model:GetAttribute("TableId")) end
 elseif event=="Card" then FX.burst(body.Position,Config.findSkin("Barrel",model:GetAttribute("BarrelSkinId")),"Card") end
end)
remotes.CatchResult.OnClientEvent:Connect(function(model,payload)
 if not model or not model.Parent or not payload.success then return end
 local body=model:FindFirstChild("Body",true)
 local skin=Config.findSkin("Barrel",model:GetAttribute("BarrelSkinId"))
 if body and skin.fx and skin.fx.theme then FX.burst(body.Position,skin,"Catch") end
end)
-- Music and effects are separate channels. Asset IDs are set in ReleaseConfig.
local music=Instance.new("Sound");music.Name="VoyageMusic";music.Looped=true;music.Parent=SoundService
local emitters=setmetatable({},{__mode="k"})
local function track(x)
 if x:IsA("ParticleEmitter") and x.Name:sub(1,7)=="SkinFX_" then emitters[x]=x.Rate end
end
for _,v in ipairs(workspace:GetDescendants()) do track(v) end
local descendant=workspace.DescendantAdded:Connect(track)
local tickAt=0
local heartbeat=Run.Heartbeat:Connect(function()
 if os.clock()-tickAt<0.5 then return end;tickAt=os.clock()
 local t=currentTable()
 if t then player:SetAttribute("SpectateTableId",nil) end
 if selected and not selected:IsDescendantOf(workspace) then selected=nil;player:SetAttribute("SpectateTableId",nil) end
 local watching=player:GetAttribute("SpectateTableId")~=nil
 spectateExit.Visible=watching;rejoin.Visible=watching
 local camera=workspace.CurrentCamera
 local q=FX.quality();local reduced=player:GetAttribute("Setting_reducedFX")==true
 for e,rate in pairs(emitters) do
  if not e.Parent then emitters[e]=nil
  else
   local anchor=e:FindFirstAncestorWhichIsA("BasePart")
   local near=anchor and camera and (anchor.Position-camera.CFrame.Position).Magnitude<(q=="Low" and 55 or 95)
   e.Enabled=near and not reduced or false;e.Rate=rate*(q=="Low" and 0.3 or 1)
  end
 end
 local id=(t or watching) and Release.Audio.Match or Release.Audio.Lobby
 -- Phase 12 : 로비 음악은 항해 시계를 따른다 (밤 · 안개 / 폭풍 · 습격)
 if not (t or watching) then
  local phase=workspace:GetAttribute("WorldPhase")
  if (workspace:GetAttribute("RaidActive")==true or phase=="storm") and (Release.Audio.Storm or 0)>0 then id=Release.Audio.Storm
  elseif (phase=="night" or phase=="fog") and (Release.Audio.Night or 0)>0 then id=Release.Audio.Night end
 end
 local sid=id>0 and ("rbxassetid://"..id) or ""
 music.Volume=player:GetAttribute("Setting_music") or 0.35
 if music.SoundId~=sid then music:Stop();music.SoundId=sid;if sid~="" then music:Play() end end
 if os.clock()-lastInput>180 and not afkSent then afkSent=true;autoAfk=true;request:FireServer("afk",true) end
end)
player.CharacterRemoving:Connect(function() player:SetAttribute("SpectateTableId",nil);selected=nil end)
script.Destroying:Connect(function() heartbeat:Disconnect();descendant:Disconnect();music:Destroy();FX.stop();gui:Destroy() end)
refresh()
player:GetAttributeChangedSignal("ProfileLoaded"):Connect(refresh)
