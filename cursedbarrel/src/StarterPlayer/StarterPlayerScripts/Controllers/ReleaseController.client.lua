local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Tags=game:GetService("CollectionService")
local Input=game:GetService("UserInputService")
local SoundService=game:GetService("SoundService")
local Social=game:GetService("SocialService")
local player=Players.LocalPlayer
-- Phase 24 : 시작 직후에는 Shared 의 모듈이 아직 복제되지 않았을 수 있다. 하나씩 기다리고, 늦으면 경고를 남기며 계속 기다린다.
local function need(parent,name)
 local child=parent:WaitForChild(name,10)
 while not child do
  warn(("[CursedBarrel] %s.%s 를 기다리는 중…"):format(parent:GetFullName(),name))
  child=parent:WaitForChild(name,10)
 end
 return child
end
local package=need(RS,"CursedBarrel")
local sharedFolder=need(package,"Shared")
local Config=require(need(sharedFolder,"GameConfig"))
local Release=require(need(sharedFolder,"ReleaseConfig"))
local FX=require(need(sharedFolder,"PremiumFX"))
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
local UIKit=require(need(sharedFolder,"UIKit"))
local TableConfig=require(need(sharedFolder,"TableConfig"))
local gui=Instance.new("ScreenGui");gui.Name="CursedBarrel_Voyage";gui.DisplayOrder=22;gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.Parent=player.PlayerGui
-- Phase 14 : 만화풍 버튼 · 창 (UIKit)
local function button(parent,text,pos,size,callback,themeName)
 local b=UIKit.button(parent,{text=text,position=pos,size=size,theme=themeName or "blue",textSize=18})
 b.Activated:Connect(callback);return b
end
local voyage=UIKit.window(gui,{name="Voyage",title="항해 수첩",theme="teal",icon3D="Voyage",size=Vector2.new(660,520)})
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
local pendingClaim=nil -- Phase 21 : 방금 누른 보상 (받으면 "획득!" 창에 띄운다)
local function refresh() request:FireServer("sync") end
-- Phase 24 : 설정은 바로 보내지 않고 0.35초 동안 모았다가 마지막 값만 한 번에 보낸다.
--   서버가 확정한 값이 돌아오면(VoyageState) 그 값으로 다시 그린다. 보내기 전에 도착한 옛 상태는 모아 둔 값으로 덮어 보여 준다.
local pendingSettings={}
local settingsToken=0
local function queueSetting(key,value)
 if data and data.settings then data.settings[key]=value end
 pendingSettings[key]=value
 settingsToken+=1;local token=settingsToken
 task.delay(0.35,function()
  if token~=settingsToken or next(pendingSettings)==nil then return end
  local batch=pendingSettings;pendingSettings={}
  request:FireServer("settings",batch)
 end)
end
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
local launcher,voyageDot=UIKit.railButton({name="VoyageButton",icon3D="Voyage",caption="항해",theme="teal",order=6})
launcher.Activated:Connect(openVoyage)
-- Phase 22 : ⚙ 설정 버튼 (음악 · 효과음 크기를 바로 바꾸게. 예전에는 항해 수첩 안 마지막 탭에 숨어 있었다)
local settingsButton=UIKit.railButton({name="SettingsButton",icon3D="Settings",caption="설정",theme="grey",order=7})
settingsButton.Activated:Connect(function()
 if panel.Visible and tab=="settings" then panel.Visible=false;return end
 tab="settings";voyage.open();refresh();draw()
end)
-- Phase 15 : 받을 수 있는 주간 의뢰 · 시즌 보상이 있으면 항해 버튼 위에 빨간 동그라미
local function refreshVoyageDot() UIKit.setDot(voyageDot,player:GetAttribute("VoyageReady") or 0) end
player:GetAttributeChangedSignal("VoyageReady"):Connect(refreshVoyageDot);refreshVoyageDot()
-- Phase 21 : 관전 버튼은 "👀 관전 중 · 테이블" 이름표와 한 묶음으로 오른쪽에 둔다 (휴대폰에서는 작게)
local spectateBar=Instance.new("Frame");spectateBar.Name="SpectateBar";spectateBar.AnchorPoint=Vector2.new(1,0.5);spectateBar.Position=UDim2.new(1,-12,0.55,0)
spectateBar.Size=UDim2.fromOffset(190,150);spectateBar.BackgroundTransparency=1;spectateBar.Visible=false;spectateBar.Parent=gui
UIKit.autoScale(spectateBar,UIKit.phoneFactor)
local spectateTitle=UIKit.label(spectateBar,{text="👀 관전 중",position=UDim2.fromOffset(0,0),size=UDim2.new(1,0,0,34),textSize=20,color=UIKit.Colors.Gold,stroke=3,scaled=true})
local function stopSpectate() player:SetAttribute("SpectateTableId",nil);selected=nil end
local spectateExit=button(spectateBar,"관전 종료",UDim2.fromOffset(5,40),UDim2.fromOffset(180,50),stopSpectate,"red")
local rejoin=button(spectateBar,"다음 판 참가",UDim2.fromOffset(5,98),UDim2.fromOffset(180,50),function() if selected then request:FireServer("rejoin",selected) end end,"green")
-- Phase 24 : 테이블에 앉아 사람을 기다리는 동안 화면 아래 가운데에 "🤖 AI 선원 켬/끔" 버튼.
--   (오른쪽 · 왼쪽은 버튼 줄, 휴대폰은 아래 양 끝에 이동 · 점프 버튼이 있어 가운데 아래를 쓴다)
--   누르면 설정(aiCrew)이 저장되어 다시 바꿀 때까지 어느 테이블에서나 그대로 간다. (설정 탭에도 같은 항목이 있다)
--   앉은 사람 중 한 명이라도 끄면 그 테이블에는 AI 가 오지 않는다.
local aiBar=Instance.new("Frame");aiBar.Name="AiCrewBar";aiBar.AnchorPoint=Vector2.new(0.5,1);aiBar.Position=UDim2.new(0.5,0,1,-18)
aiBar.Size=UDim2.fromOffset(440,94);aiBar.BackgroundTransparency=1;aiBar.Visible=false;aiBar.Parent=gui
UIKit.autoScale(aiBar,UIKit.phoneFactor)
local aiHint=UIKit.label(aiBar,{text="",position=UDim2.fromOffset(0,0),size=UDim2.new(1,0,0,30),textSize=16,color=UIKit.Colors.Cream,stroke=2,wrap=true})
local function aiCrewOn() return player:GetAttribute("Setting_aiCrew")~=false end
local aiButton,startButton
local barTable=nil -- 지금 버튼 막대가 보고 있는 테이블
local barLook={} -- 마지막으로 칠한 모양 (같으면 다시 칠하지 않는다)
local function paint(b,text,theme)
 if barLook[b]~=text..theme then barLook[b]=text..theme;b.Text=text;UIKit.setTheme(b,theme) end
end
-- Phase 24 : 🤖 AI 선원 버튼 + 👑 방장의 「▶ 시작」 버튼
--   방장 = 먼저 앉은 사람. 시작 인원(AI 포함)이 차면 방장이 눌러 바로 시작. 안 누르면 30초 뒤 자동 시작.
local function drawAiBar()
 local t=barTable
 local on=aiCrewOn()
 if data and data.settings and data.settings.aiCrew~=nil then on=data.settings.aiCrew~=false end
 local tableType=t and t:GetAttribute(Config.TableAttributes.TableType)
 local tourney=tableType and TableConfig.Types[tableType] and TableConfig.Types[tableType].Tournament
 paint(aiButton,on and "🤖 AI 선원 켬" or "🤖 AI 선원 끔",on and "green" or "grey")
 local hint=on and (tourney and "AI 와 한 판은 토너먼트 점수가 없어요" or "혼자면 잠시 뒤 AI 가 와요") or "사람만 기다려요"
 local hostId=t and t:GetAttribute(Config.TableAttributes.HostUserId) or 0
 local seated=t and t:GetAttribute(Config.TableAttributes.SeatedCount) or 0
 local need=t and t:GetAttribute(Config.TableAttributes.MinPlayers) or 2
 startButton.Visible=hostId~=0
 if hostId==player.UserId then
  local ready=seated>=need
  paint(startButton,ready and "▶ 시작" or ("▶ %d명부터"):format(need),ready and "gold" or "grey")
  startButton.Active=ready
  hint=hint.."  ·  👑 내가 방장"
 elseif hostId~=0 then
  local host=Players:GetPlayerByUserId(hostId)
  paint(startButton,"👑 "..(host and host.DisplayName or "방장"),"grey")
  startButton.Active=false
  hint=hint.."  ·  방장이 시작해요"
 end
 aiHint.Text=hint
end
aiButton=button(aiBar,"🤖 AI 선원 켬",UDim2.fromOffset(10,38),UDim2.fromOffset(205,52),function()
 local on=aiCrewOn()
 if data and data.settings and data.settings.aiCrew~=nil then on=data.settings.aiCrew~=false end
 queueSetting("aiCrew",not on);drawAiBar()
end,"green")
startButton=button(aiBar,"▶ 시작",UDim2.fromOffset(225,38),UDim2.fromOffset(205,52),function()
 if not startButton.Active then return end
 local r=remotes:FindFirstChild("TableStart")
 if r then r:FireServer() end
end,"gold")
player:GetAttributeChangedSignal("Setting_aiCrew"):Connect(drawAiBar)
local function tableById(id)
 if not id then return nil end
 for _,t in ipairs(Tags:GetTagged(Config.Tags.Table)) do if t:GetAttribute("TableId")==id then return t end end
 return nil
end
local function isLive(t)
 local state=t and t:GetAttribute(Config.TableAttributes.State)
 return state~=nil and (Config.InGameStates[state]==true or state==Config.States.Countdown)
end
function draw()
 for _,v in ipairs(scroll:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end;order=0
 for i,t in ipairs(tabDefs) do tabButtons[i].Text=lang(t[2],t[3]);UIKit.setTheme(tabButtons[i],t[1]==tab and "gold" or "grey") end
 if not data then local _,l=row(lang("자료를 불러오는 중…","Loading…"));l.Size=UDim2.new(1,-20,1,-10);return end
 if tab=="watch" then
  -- Phase 21 : 지금 게임이 진행 중인 테이블만 보여 준다 (예전에는 빈 테이블까지 전부 떠서 "없는 게임"을 관전할 수 있었다)
  local shown=0
  local mine=currentTable()
  for _,t in ipairs(Tags:GetTagged(Config.Tags.Table)) do
   if t:IsDescendantOf(workspace) and t~=mine and isLive(t) and (t:GetAttribute("SeatedCount") or 0)>0 then
    shown+=1
    local state=t:GetAttribute(Config.TableAttributes.State)
    local stage,final=t:GetAttribute(Config.TableAttributes.Stage) or 0,t:GetAttribute(Config.TableAttributes.FinalRound)==true
    local info=state==Config.States.Countdown and lang("곧 시작","Starting soon") or (stage>0 and (lang("라운드 ","Round ")..stage..(final and lang(" · 결승"," · Final") or "")) or lang("진행 중","In progress"))
    local r=row((t:GetAttribute("DisplayName") or t.Name).."  👥 "..tostring(t:GetAttribute("SeatedCount") or 0).."/"..tostring(t:GetAttribute("SeatCount") or 0).."\n"..info)
    action(r,lang("관전","Spectate"),function() spectate(t) end)
   end
  end
  if shown==0 then local _,l=row(lang("지금 진행 중인 게임이 없어요","No games in progress right now"),60);l.Size=UDim2.new(1,-30,1,-8) end
 elseif tab=="weekly" then
  for _,q in ipairs(Release.Weekly) do
   local progress=(data.weekly.progress or {})[q.id] or 0
   local r=row(lang(q.text,q.en).."\n"..progress.." / "..q.goal.." · +"..q.reward)
   action(r,data.weekly.claimed[q.id] and "✓" or lang("받기","Claim"),function() pendingClaim={text=q.reward.." 코인",money="cash2"};request:FireServer("weekly",q.id) end)
  end
  local _,l=row(lang("시즌: 용의 항로","Season: Dragon Tide").." · "..(data.season.xp or 0).." XP",54);l.Size=UDim2.new(1,-30,1,-8)
  for i,tier in ipairs(Release.Season.Tiers) do
   local reward=tier.coins and (tier.coins..lang(" 코인"," coins")) or Config.findSkin(tier.kind,tier.skin).name
   local rr=row(tier.xp.." XP\n"..reward)
   action(rr,data.season.claimed[tostring(i)] and "✓" or lang("받기","Claim"),function() pendingClaim=tier.coins and {text=tier.coins.." 코인",money="chest"} or {text="「"..reward.."」",skin={kind=tier.kind,id=tier.skin}};request:FireServer("season",i) end)
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
   {"👑 3인 이상 테이블은 마지막 1명이 전부 가져가요","👑 3+ seat tables: the last survivor takes it all"},
   {"😈 방해 : 게임 중 왼쪽 😈 버튼 → 상대 고르기 → 사용","😈 Sabotage: in a game, tap 😈 → pick a rival → use"},
   {"🃏 카드 : 카드 테이블에서 내 차례에 칼 고르는 창 위 버튼","🃏 Cards: on your turn at the card table, above the slot picker"},
   {"🧭 수첩 : 관전 · 주간 의뢰 · 파티 · 설정","🧭 Voyage: spectate · weekly quests · party · settings"},
  }) do local _,l=row(lang(line[1],line[2]),52);l.Size=UDim2.new(1,-30,1,-8) end
 elseif tab=="settings" then
  local set=data.settings
  for _,def in ipairs({{"music","음악","Music"},{"sfx","효과음","Effects"}}) do
   -- Phase 22 : − / + 로 10% 씩 (예전에는 +25% 만 눌러서 돌아가는 버튼 하나였다)
   local value=set[def[1]] or 0;local r=row((def[1]=="music" and "🎵 " or "🔊 ")..lang(def[2],def[3]).."  "..math.floor(value*100+0.5).."%")
   local key=def[1]
   local function set01(v) v=math.clamp(math.floor(v*10+0.5)/10,0,1);queueSetting(key,v);draw() end
   button(r,"−",UDim2.new(1,-236,0.5,-22),UDim2.fromOffset(70,44),function() set01(value-0.1) end,"red")
   button(r,"+",UDim2.new(1,-160,0.5,-22),UDim2.fromOffset(70,44),function() set01(value+0.1) end,"green")
   button(r,value>0 and "🔇" or "🔈",UDim2.new(1,-84,0.5,-22),UDim2.fromOffset(70,44),function() set01(value>0 and 0 or 0.5) end,"grey")
  end
  for _,def in ipairs({{"aiCrew","🤖 AI 선원 채우기","🤖 AI crew fill-in"},{"shake","화면 흔들림","Camera shake"},{"reducedFX","번쩍임·연출 줄이기","Reduce effects"},{"camera","테이블 카메라","Table camera"},{"wide","화각 넓게","Wide view"}}) do
   local key=def[1];local r=row(lang(def[2],def[3]));action(r,set[key] and "ON" or "OFF",function() queueSetting(key,not set[key]);draw() end)
  end
  local q=row(lang("이펙트 품질","Effect quality"));action(q,set.quality,function() queueSetting("quality",({Auto="High",High="Low",Low="Auto"})[set.quality] or "Auto");draw() end)
  local l=row(lang("언어","Language"));action(l,set.language,function() queueSetting("language",locale=="ko" and "en" or "ko");draw() end)
  local a=row(lang("자리 비움","AFK"));action(a,player:GetAttribute("AFK") and "ON" or "OFF",function() request:FireServer("afk",not player:GetAttribute("AFK")) end)
 end
end
stateRemote.OnClientEvent:Connect(function(new)
 if typeof(new)~="table" then return end;data=new
 -- 아직 보내지 않은(모으는 중인) 설정은 화면에서 그대로 유지한다
 if typeof(new.settings)=="table" then for k,v in pairs(pendingSettings) do new.settings[k]=v end end
 local chosen=new.settings.language;locale=chosen=="Auto" and (player.LocaleId:sub(1,2)=="ko" and "ko" or "en") or chosen
 message.Text=new.message or "";if panel.Visible then draw() end
 local said=new.message or ""
 if pendingClaim and (said:find("^보상 지급") or said:find("^시즌 보상 지급")) then UIKit.rewardPopup(pendingClaim);pendingClaim=nil
 elseif pendingClaim and said~="" then pendingClaim=nil end
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
    local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.Text="👑";text.TextSize=48;text.TextColor3=Color3.fromRGB(255,210,110);text.Parent=crown;game:GetService("Debris"):AddItem(crown,4)
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
-- Phase 21 : 음악 채널 두 개를 번갈아 쓰며 부드럽게 넘긴다 (로비 뱃노래 ↔ 게임 중 긴장 음악 ↔ 결승 음악).
--   해적이 튀어나오는 동안에는 음악을 줄여서 해적 소리가 잘 들리게 한다.
local channels={}
for i=1,2 do
 local s=Instance.new("Sound");s.Name="VoyageMusic"..i;s.Looped=true;s.Volume=0;s.Parent=SoundService
 channels[i]={sound=s,level=0}
end
local front=1
-- Phase 24 : 올린 음원이 이 게임에서 재생되는지 처음에 한 번 확인한다.
--   음원은 올린 계정(또는 그룹)의 게임에서만 재생되고, 다른 곳이면 "권한 없음"으로 조용히 안 나온다.
--   안 되는 음원은 Release.AudioFailed 에 적어 두고 기본 소리 · 다른 곡으로 대신한다. F9(개발자 콘솔)에 목록이 뜬다.
task.spawn(function()
 local list={}
 for key,id in pairs(Release.Audio) do
  if (tonumber(id) or 0)>0 then local s=Instance.new("Sound");s.Name=key;s.SoundId="rbxassetid://"..id;table.insert(list,s) end
 end
 local failed={}
 pcall(function()
  game:GetService("ContentProvider"):PreloadAsync(list,function(assetId,status)
   if status==Enum.AssetFetchStatus.Failure then
    for _,s in ipairs(list) do
     if s.SoundId==assetId and not Release.AudioFailed[s.Name] then Release.AudioFailed[s.Name]=true;table.insert(failed,s.Name.." "..assetId) end
    end
   end
  end)
 end)
 if #failed>0 then
  warn("[CursedBarrel] 이 게임에서 재생할 수 없는 음원 (Creator Hub → 오디오 → 권한에서 이 게임을 허용하거나, 게임 주인 계정 · 그룹으로 다시 올려 주세요): "..table.concat(failed,", "))
 end
 for _,s in ipairs(list) do s:Destroy() end
end)
local function chooseMusic(t,watching)
 local A={} -- 재생할 수 없는 음원은 0 으로 본다
 for key in pairs(Release.Audio) do A[key]=Release.audioId(key) end
 local model=t or (watching and tableById(player:GetAttribute("SpectateTableId")))
 if model and isLive(model) then
  -- Phase 24 : 게임 음악을 재생할 수 없으면 로비 음악을 조금 빠르게라도 튼다 (아예 조용하지 않게)
  local match,speed=A.Match or 0,1
  if match<=0 then match,speed=A.Lobby or 0,1.06 end
  -- Phase 24 : 라운드(통)가 올라갈수록 음악이 조금씩 빨라진다 (라운드마다 +4%, 최대 +28%)
  local stage=model:GetAttribute(Config.TableAttributes.Stage) or 1
  speed=speed*(1+math.min(0.28,0.04*math.max(0,stage-1)))
  -- Phase 24 : 결승(셋 이상 시작해 둘이 남음)이면 결승 음악
  if model:GetAttribute(Config.TableAttributes.FinalRound)==true then
   if (A.MatchFinal or 0)>0 then return A.MatchFinal,1+math.min(0.12,0.02*math.max(0,stage-1)) end
   return match,speed+0.08 -- 결승 음악이 없으면 게임 음악을 조금 빠르게
  end
  return match,speed
 end
 -- Phase 12 : 로비 음악은 항해 시계를 따른다 (밤 · 안개 / 폭풍 · 습격)
 local phase=workspace:GetAttribute("WorldPhase")
 if (workspace:GetAttribute("RaidActive")==true or phase=="storm") and (A.Storm or 0)>0 then return A.Storm,1 end
 if (phase=="night" or phase=="fog") and (A.Night or 0)>0 then return A.Night,1 end
 return A.Lobby or 0,1
end
local function setMusic(id,speed)
 local sid=(tonumber(id) or 0)>0 and ("rbxassetid://"..id) or ""
 local current=channels[front].sound
 if current.SoundId==sid then current.PlaybackSpeed=speed;return end
 front=3-front
 local nextSound=channels[front].sound
 nextSound:Stop();nextSound.SoundId=sid;nextSound.PlaybackSpeed=speed;channels[front].level=0
 if sid~="" then nextSound.TimePosition=0;nextSound:Play() end
end
local musicFade=Run.RenderStepped:Connect(function(dt)
 local base=(player:GetAttribute("Setting_music") or 0.35)*(player:GetAttribute("PirateFocus")==true and 0.4 or 1)
 for i,ch in ipairs(channels) do
  local goal=(i==front and ch.sound.SoundId~="") and 1 or 0
  ch.level+=(goal-ch.level)*math.min(1,dt*1.8)
  if goal==0 and ch.level<0.01 and ch.sound.IsPlaying then ch.sound:Stop() end
  ch.sound.Volume=base*ch.level
 end
end)
local emitters=setmetatable({},{__mode="k"})
local function track(x)
 if x:IsA("ParticleEmitter") and x.Name:sub(1,7)=="SkinFX_" then emitters[x]=x.Rate end
end
for _,v in ipairs(workspace:GetDescendants()) do track(v) end
local descendant=workspace.DescendantAdded:Connect(track)
local tickAt=0
local idleSince=nil
local heartbeat=Run.Heartbeat:Connect(function()
 if os.clock()-tickAt<0.5 then return end;tickAt=os.clock()
 local t=currentTable()
 if t then player:SetAttribute("SpectateTableId",nil) end
 if selected and not selected:IsDescendantOf(workspace) then selected=nil;player:SetAttribute("SpectateTableId",nil) end
 -- Phase 21 : 관전하던 판이 끝나면(대기로 돌아가고 4초) 관전을 저절로 끝낸다.
 --   예전에는 탈락해서 자동 관전이 된 뒤 판이 끝나도 "관전 종료 · 다음 판 참가" 가 계속 떠 있었다
 local watchId=player:GetAttribute("SpectateTableId")
 if watchId then
  local m=(selected and selected:GetAttribute("TableId")==watchId and selected) or tableById(watchId)
  if isLive(m) then idleSince=nil else idleSince=idleSince or os.clock() end
  if not m or os.clock()-(idleSince or os.clock())>4 then stopSpectate();idleSince=nil end
  if m then spectateTitle.Text="👀 관전 중 · "..(m:GetAttribute("DisplayName") or m.Name) end
 else idleSince=nil end
 local watching=player:GetAttribute("SpectateTableId")~=nil
 spectateBar.Visible=watching and player:GetAttribute("PirateFocus")~=true
 -- Phase 24 : 앉아서 기다리는 동안(대기 · 카운트다운)만 AI 선원 버튼을 보인다. AI 가 오지 않는 토너먼트 테이블은 뺀다
 local waitingAt=t and t:GetAttribute(Config.TableAttributes.State)
 local tableType=t and t:GetAttribute(Config.TableAttributes.TableType)
 local botsAllowed=t~=nil and not (tableType and TableConfig.Types[tableType] and TableConfig.Types[tableType].NoBots)
 local showBar=t~=nil and (waitingAt==Config.States.Waiting or waitingAt==Config.States.Countdown) and (t:GetAttribute(Config.TableAttributes.Tutorial) or 0)==0
 aiButton.Visible=botsAllowed
 barTable=t
 if showBar then drawAiBar() end
 aiBar.Visible=showBar
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
 setMusic(chooseMusic(t,watching))
 if os.clock()-lastInput>180 and not afkSent then afkSent=true;autoAfk=true;request:FireServer("afk",true) end
end)
player.CharacterRemoving:Connect(function() player:SetAttribute("SpectateTableId",nil);selected=nil end)
script.Destroying:Connect(function() heartbeat:Disconnect();descendant:Disconnect();musicFade:Disconnect();for _,ch in ipairs(channels) do ch.sound:Destroy() end;FX.stop();gui:Destroy() end)
refresh()
player:GetAttributeChangedSignal("ProfileLoaded"):Connect(refresh)
