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
local gui=Instance.new("ScreenGui");gui.Name="CursedBarrel_Voyage";gui.DisplayOrder=22;gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.Parent=player.PlayerGui
local function button(parent,text,pos,size,callback)
 local b=Instance.new("TextButton");b.Text=text;b.Position=pos;b.Size=size;b.TextSize=14;b.Font=Enum.Font.GothamBold;b.TextColor3=Color3.fromRGB(244,231,198);b.BackgroundColor3=Color3.fromRGB(34,60,71);b.BorderSizePixel=0;b.TextWrapped=true;b.Selectable=true;b.Parent=parent
 Instance.new("UICorner",b).CornerRadius=UDim.new(0,8);b.Activated:Connect(callback);return b
end
local panel=Instance.new("Frame");panel.AnchorPoint=Vector2.new(0.5,0.5);panel.Position=UDim2.fromScale(0.5,0.5);panel.Size=UDim2.new(0.94,0,0.8,0);panel.BackgroundColor3=Color3.fromRGB(12,22,33);panel.Visible=false;panel.Parent=gui
 Instance.new("UICorner",panel).CornerRadius=UDim.new(0,16)
local cap=Instance.new("UISizeConstraint");cap.MaxSize=Vector2.new(660,640);cap.Parent=panel
local heading=Instance.new("TextLabel");heading.Size=UDim2.new(1,-80,0,38);heading.Position=UDim2.fromOffset(14,8);heading.BackgroundTransparency=1;heading.TextColor3=Color3.fromRGB(244,216,160);heading.TextSize=19;heading.Font=Enum.Font.GothamBold;heading.TextXAlignment=Enum.TextXAlignment.Left;heading.Text="DRAGON TIDE";heading.Parent=panel
button(panel,"×",UDim2.new(1,-46,0,8),UDim2.fromOffset(36,36),function() panel.Visible=false end)
local tabs=Instance.new("Frame");tabs.Position=UDim2.fromOffset(10,52);tabs.Size=UDim2.new(1,-20,0,40);tabs.BackgroundTransparency=1;tabs.Parent=panel
local scroll=Instance.new("ScrollingFrame");scroll.Position=UDim2.fromOffset(12,102);scroll.Size=UDim2.new(1,-24,1,-142);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=4;scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;scroll.CanvasSize=UDim2.new();scroll.Parent=panel
local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,8);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=scroll
local message=Instance.new("TextLabel");message.Position=UDim2.new(0,12,1,-34);message.Size=UDim2.new(1,-24,0,28);message.BackgroundTransparency=1;message.TextColor3=Color3.fromRGB(124,229,207);message.TextSize=12;message.TextWrapped=true;message.Parent=panel;message.Text=""
local order=0
local function row(text,height)
 order+=1;local r=Instance.new("Frame");r.Size=UDim2.new(1,-8,0,height or 64);r.BackgroundColor3=Color3.fromRGB(22,36,48);r.LayoutOrder=order;r.Parent=scroll;Instance.new("UICorner",r).CornerRadius=UDim.new(0,8)
 local l=Instance.new("TextLabel");l.Position=UDim2.fromOffset(10,5);l.Size=UDim2.new(1,-140,1,-10);l.BackgroundTransparency=1;l.Text=text;l.TextColor3=Color3.fromRGB(223,226,228);l.TextSize=14;l.Font=Enum.Font.Gotham;l.TextXAlignment=Enum.TextXAlignment.Left;l.TextWrapped=true;l.Parent=r;return r,l
end
local draw
local function refresh() request:FireServer("sync") end
local function action(r,text,fn) return button(r,text,UDim2.new(1,-124,0.5,-20),UDim2.fromOffset(114,40),fn) end
local function spectate(model)
 selected=model
 local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if h and h.SeatPart then return end
 player:SetAttribute("SpectateTableId",model:GetAttribute("TableId"));panel.Visible=false
end
local tabDefs={{"watch","관전","Watch"},{"weekly","의뢰","Quests"},{"party","파티","Party"},{"cards","카드","Cards"},{"settings","설정","Settings"}}
local tabButtons={}
for i,t in ipairs(tabDefs) do
 tabButtons[i]=button(tabs,t[2],UDim2.new((i-1)/5,2,0,0),UDim2.new(1/5,-4,1,0),function() tab=t[1];refresh();draw() end)
end
local launcher=button(gui,"항해 / Voyage",UDim2.new(1,-142,0,144),UDim2.fromOffset(130,36),function() panel.Visible=not panel.Visible;if panel.Visible then refresh();draw() end end)
local spectateExit=button(gui,"관전 종료 / Exit",UDim2.new(1,-172,0,188),UDim2.fromOffset(160,34),function() player:SetAttribute("SpectateTableId",nil);selected=nil end);spectateExit.Visible=false
local rejoin=button(gui,"다음 판 / Rejoin",UDim2.new(1,-172,0,228),UDim2.fromOffset(160,34),function() if selected then request:FireServer("rejoin",selected) end end);rejoin.Visible=false
function draw()
 for _,v in ipairs(scroll:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end;order=0
 for i,t in ipairs(tabDefs) do tabButtons[i].Text=lang(t[2],t[3]) end
 if not data then local _,l=row(lang("자료를 불러오는 중…","Loading…"));l.Size=UDim2.new(1,-20,1,-10);return end
 if tab=="watch" then
  for _,t in ipairs(Tags:GetTagged(Config.Tags.Table)) do
   if t:IsDescendantOf(workspace) then
    local r=row((t:GetAttribute("DisplayName") or t.Name).."\n"..tostring(t:GetAttribute("State")).." · "..tostring(t:GetAttribute("SeatedCount") or 0).."/"..tostring(t:GetAttribute("SeatCount") or 0))
    action(r,lang("관전","Spectate"),function() spectate(t) end)
   end
  end
  local r=row(lang("개인 서버에서도 같은 규칙과 저장을 사용합니다.","Private servers share these rules and saved progress."));r:FindFirstChildOfClass("TextLabel").Size=UDim2.new(1,-20,1,-10)
 elseif tab=="weekly" then
  for _,q in ipairs(Release.Weekly) do
   local progress=(data.weekly.progress or {})[q.id] or 0
   local r=row(lang(q.text,q.en).."\n"..progress.." / "..q.goal.." · +"..q.reward)
   action(r,data.weekly.claimed[q.id] and "✓" or lang("받기","Claim"),function() request:FireServer("weekly",q.id) end)
  end
  local r,l=row(lang("시즌: 용의 항로","Season: Dragon Tide").." · "..(data.season.xp or 0).." XP",44);l.Size=UDim2.new(1,-20,1,-10)
  for i,tier in ipairs(Release.Season.Tiers) do
   local reward=tier.coins and (tier.coins..lang(" 코인"," coins")) or Config.findSkin(tier.kind,tier.skin).name
   local rr=row(tier.xp.." XP\n"..reward)
   action(rr,data.season.claimed[tostring(i)] and "✓" or lang("받기","Claim"),function() request:FireServer("season",i) end)
  end
 elseif tab=="party" then
  local r=row(lang("같은 판: 친구 +10%, 파티 +5% 코인","Same round: friend +10%, party +5% coins"),70)
  action(r,lang("친구 초대","Invite friends"),function() task.spawn(function() pcall(Social.PromptGameInvite,Social,player) end) end)
  for _,invite in ipairs(data.party.invitations) do
   local rr=row(invite.name..lang(" 님의 파티 초대"," invited you"));action(rr,lang("수락","Accept"),function() request:FireServer("accept",invite.id) end)
  end
  for _,member in ipairs(data.party.members) do local _,l=row("✓ "..member.name,38);l.Size=UDim2.new(1,-20,1,-10) end
  if data.party.leader~=0 then local rr=row(lang("현재 파티","Current party"));action(rr,lang("나가기","Leave"),function() request:FireServer("leaveParty") end) end
  for _,other in ipairs(data.players) do local rr=row(other.name);action(rr,lang("파티 초대","Invite to party"),function() request:FireServer("invite",other.id) end) end
 elseif tab=="cards" then
  local model=currentTable()
  local _,l=row(lang("H 테이블에서 각 카드 1회 무료. 내 차례에만 사용합니다. 봉인은 다음 선택까지 유지됩니다.","Free at table H: one of each card per round, on your turn. Seal lasts until the next pick."),92);l.Size=UDim2.new(1,-20,1,-10)
  local inputRow=row(lang("봉인할 슬롯 번호","Slot number to seal"))
  local input=Instance.new("TextBox");input.Size=UDim2.fromOffset(110,36);input.Position=UDim2.new(1,-120,0.5,-18);input.Text="1";input.TextSize=18;input.ClearTextOnFocus=false;input.Parent=inputRow
  for _,id in ipairs({"skip","rotate","seal"}) do
   local def=Release.Cards[id];local r=row(lang(def.name,def.en))
   action(r,lang("사용","Use"),function()
    if model then request:FireServer("card",model,id,tonumber(input.Text),model:GetAttribute("RoundId"),model:GetAttribute("TurnSerial")) end
   end)
  end
 elseif tab=="settings" then
  local set=data.settings
  for _,def in ipairs({{"music","음악","Music"},{"sfx","효과음","Effects"}}) do
   local value=set[def[1]] or 0;local r=row(lang(def[2],def[3]).." "..math.floor(value*100).."%")
   action(r,"+25% / 0",function() request:FireServer("setting",def[1],value>=1 and 0 or math.min(1,value+0.25)) end)
  end
  for _,def in ipairs({{"shake","화면 흔들림","Camera shake"},{"reducedFX","번쩍임·연출 줄이기","Reduce effects"},{"camera","테이블 카메라","Table camera"}}) do
   local key=def[1];local r=row(lang(def[2],def[3]));action(r,set[key] and "ON" or "OFF",function() request:FireServer("setting",key,not set[key]) end)
  end
  local q=row(lang("이펙트 품질","Effect quality"));action(q,set.quality,function() request:FireServer("setting","quality",({Auto="High",High="Low",Low="Auto"})[set.quality] or "Auto") end)
  local l=row(lang("언어","Language"));action(l,set.language,function() request:FireServer("setting","language",locale=="ko" and "en" or "ko") end)
  local a=row(lang("자리 비움 (진행 중이면 이탈)","AFK (leaves current round)"));action(a,player:GetAttribute("AFK") and "ON" or "OFF",function() request:FireServer("afk",not player:GetAttribute("AFK")) end)
  if not data.writable then local _,txt=row(lang("Studio 임시 플레이: 저장·구매 비활성","Studio temporary play: saving and purchases disabled"));txt.Size=UDim2.new(1,-20,1,-10) end
 end
end
stateRemote.OnClientEvent:Connect(function(new)
 if typeof(new)~="table" then return end;data=new
 local chosen=new.settings.language;locale=chosen=="Auto" and (player.LocaleId:sub(1,2)=="ko" and "ko" or "en") or chosen
 message.Text=new.message or "";if panel.Visible then draw() end
end)
Input.InputBegan:Connect(function(input,processed)
 lastInput=os.clock()
 if afkSent then afkSent=false;request:FireServer("afk",false) end
 if not processed and (input.KeyCode==Enum.KeyCode.M or input.KeyCode==Enum.KeyCode.ButtonY) then panel.Visible=not panel.Visible;if panel.Visible then refresh();draw();game:GetService("GuiService").SelectedObject=tabButtons[1] end end
 if input.KeyCode==Enum.KeyCode.ButtonB and panel.Visible then panel.Visible=false end
end)
-- Presentation receives public, completed outcomes only.
remotes.PresentationCue.OnClientEvent:Connect(function(event,model,payload)
 if typeof(model)~="Instance" or not model.Parent or typeof(payload)~="table" then return end
 local body=model:FindFirstChild("Body",true);if not body then return end
 local actor=Players:GetPlayerByUserId(payload.userId or 0)
 if event=="Pick" and not payload.danger then
  local skin=Config.findSkin("Knife",actor and actor:GetAttribute("KnifeSkin"))
  if skin and skin.fx and skin.fx.theme then FX.burst(body.Position,skin,"Pick") end
 elseif event=="Win" then
  local skin=Config.findSkin("Victory",payload.skin)
  FX.burst(body.Position,skin,"Win")
  if actor then
   local head=actor.Character and actor.Character:FindFirstChild("Head")
   if head then
    local character=actor.Character
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
 local sid=id>0 and ("rbxassetid://"..id) or ""
 music.Volume=player:GetAttribute("Setting_music") or 0.35
 if music.SoundId~=sid then music:Stop();music.SoundId=sid;if sid~="" then music:Play() end end
 if os.clock()-lastInput>180 and not afkSent then afkSent=true;request:FireServer("afk",true) end
end)
player.CharacterRemoving:Connect(function() player:SetAttribute("SpectateTableId",nil);selected=nil end)
script.Destroying:Connect(function() heartbeat:Disconnect();descendant:Disconnect();music:Destroy();FX.stop();gui:Destroy() end)
refresh()
player:GetAttributeChangedSignal("ProfileLoaded"):Connect(refresh)
