-- The lobby itself is a traversable galleon. Run BEFORE table registration.
-- Functional instances and all TableIds are retained; obsolete dock decor is archived.
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Tags=game:GetService("CollectionService")
local Shared=RS.CursedBarrel.Shared
local Config=require(Shared.GameConfig)
local L=require(Shared.ShipLayout)
local Release=require(Shared.ReleaseConfig)
local MeshKit=require(Shared.MeshKit) -- Phase 15 : Blender 모델 (없으면 예전 파트 모양)
local S={}
local wood=Color3.fromRGB(87,51,30)
local dark=Color3.fromRGB(42,28,24)
local gold=Color3.fromRGB(191,142,67)
local iron=Color3.fromRGB(44,48,54)
local function block(parent,name,size,cf,color,collide,material)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color or wood
 p.Material=material or Enum.Material.WoodPlanks;p.Anchored=true;p.CanCollide=collide==true
 p.CanQuery=collide==true;p.CanTouch=false;p.CastShadow=false;p.Parent=parent
 return p
end
local function segment(parent,name,a,b,width,color,collide)
 return block(parent,name,Vector3.new(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)*0.5,b),color,collide,Enum.Material.Wood)
end
local function cylinder(parent,name,diameter,height,pos,color,collide,material)
 local p=block(parent,name,Vector3.new(height,diameter,diameter),CFrame.new(pos)*CFrame.Angles(0,0,math.pi/2),color,collide,material)
 p.Shape=Enum.PartType.Cylinder;return p
end
local function group(parent,name)
 local m=Instance.new("Model");m.Name=name;m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic;m.Parent=parent;return m
end
-- Phase 24.12 : Blender 소품(CursedBarrelProps)이 있으면 원래 파트는 부딪힘만 맡고 보이지 않는다
local function ghost(p)
 if p then p.Transparency=1;p.CastShadow=false end
 return p
end
-- 보이지 않는 벽 : 난간 · 계단 손잡이를 그냥 통과하던 문제 (보이는 난간은 부딪힘이 없었다)
local function wall(parent,name,size,cf)
 local p=block(parent,name,size,cf,dark,true);p.Transparency=1;return p
end
-- 오른쪽(+x) 소품은 그대로, 왼쪽(-x)은 반 바퀴 돌려 놓는다 (안쪽 면이 늘 배 가운데를 본다)
local function sideYaw(side) return side<0 and CFrame.Angles(0,math.pi,0) or CFrame.new() end
-- Phase 24.13 : 게시판 틀 (판자 · 틀 · 못). 새로 생긴 조각 중 이 이름들은 부딪힘만 남기고 숨긴다
local BOARD_PARTS={Plank=true,FrameTop=true,FrameBottom=true,FrameSide=true,Nail=true}
local BOARD_STYLE={Frame={color=Color3.fromRGB(46,30,24),material=Enum.Material.Wood},Planks={color=Color3.fromRGB(112,70,40),material=Enum.Material.WoodPlanks}}
local function snapshot(parent) local seen={};for _,c in ipairs(parent:GetChildren()) do seen[c]=true end;return seen end
local function ghostNew(parent,before)
 for _,c in ipairs(parent:GetChildren()) do
  if not before[c] and c:IsA("BasePart") and BOARD_PARTS[c.Name] then ghost(c) end
 end
end
-- 계단 양옆 손잡이 높이의 벽 (계단 모양 : props/assets.py 의 stair 와 같은 치수)
--   origin : 계단 기준 CFrame (첫 칸 앞 · 갑판 높이, 로컬 -Z 쪽으로 올라간다)
local function stairWalls(parent,origin,n,rise,run,tread,width)
 local k=rise/run;local nose=tread/2+0.12
 local zs,zt=nose-0.25,-run*(n-1)
 for _,sx in ipairs({-1,1}) do
  local x=sx*(width/2-0.2)
  local a=origin:PointToWorldSpace(Vector3.new(x,k*(nose-zs),zs))
  local b=origin:PointToWorldSpace(Vector3.new(x,k*(nose-zt),zt))
  local mid=(a+b)/2+Vector3.new(0,1.3,0)
  wall(parent,"StairRailWall",Vector3.new(0.45,3,(b-a).Magnitude+0.4),CFrame.lookAt(mid,mid+(b-a)))
 end
end
-- 등불은 전부 ShipLights 폴더 하나에 모으고 Persistent 로 둔다.
-- (Atomic 으로 두면 스트리밍이 등불을 늦게 보내서, 처음 들어와 스폰 단상에 서 있는 동안 배가 캄캄했다)
local lightFolder=nil
-- Phase 15 : 등불의 "빛"(PointLight)은 각자 화면(LightController)이 켠다. 여기서는 자리만 알려 준다.
--   예전에는 빛이 등불 모델과 함께 스트리밍으로 늦게 도착해서, 들어오고 몇 초 동안 배가 캄캄했다.
--   자리 목록(ReplicatedStorage > CursedBarrel > LanternSpots)은 접속하자마자 통째로 오므로 빛이 바로 켜진다.
local spotFolder=nil
local function lanternSpot(pos,range,brightness,fill)
 if not spotFolder then
  spotFolder=RS.CursedBarrel:FindFirstChild("LanternSpots") or Instance.new("Folder")
  spotFolder.Name="LanternSpots";spotFolder.Parent=RS.CursedBarrel
 end
 local spot=Instance.new("Vector3Value");spot.Name="Spot";spot.Value=pos
 spot:SetAttribute("Range",range or 20);spot:SetAttribute("Brightness",brightness or 1.8)
 if fill then spot:SetAttribute("Fill",true) end
 spot.Parent=spotFolder
end
local function light(_,pos,range,brightness)
 -- Every light has a cap, cage, chain and a visible structural attachment.
 local lamp=Instance.new("Model");lamp.Name="SupportedLantern";lamp.ModelStreamingMode=Enum.ModelStreamingMode.Persistent;lamp.Parent=lightFolder
 -- Phase 24.12 : Blender 등불 (쇠 테 · 지붕 · 고리 + 빛나는 유리)
 if MeshKit.prop("Lantern",CFrame.new(pos),lamp,{shadow=false}) then
  lanternSpot(pos,range,brightness)
  lamp:SetAttribute("StructurallySupported",true)
  return lamp
 end
 block(lamp,"Glass",Vector3.new(0.8,1.1,0.8),CFrame.new(pos),Color3.fromRGB(255,193,93),false,Enum.Material.Neon).Transparency=0.15
 for _,y in ipairs({-0.66,0.66}) do block(lamp,"Cap",Vector3.new(1.2,0.17,1.2),CFrame.new(pos+Vector3.new(0,y,0)),iron,false,Enum.Material.Metal) end
 for _,x in ipairs({-0.48,0.48}) do for _,z in ipairs({-0.48,0.48}) do
  block(lamp,"Cage",Vector3.new(0.08,1.3,0.08),CFrame.new(pos+Vector3.new(x,0,z)),iron,false,Enum.Material.Metal)
 end end
 lanternSpot(pos,range,brightness)
 lamp:SetAttribute("StructurallySupported",true)
 return lamp
end
-- 기둥 위에 올린 등불 (갑판 · 후갑판 · 뱃머리)
local function postLight(parent,base,height)
 local top=base+Vector3.new(0,height,0)
 local post=block(parent,"LampPost",Vector3.new(0.45,height,0.45),CFrame.new(base+Vector3.new(0,height/2,0)),dark,true,Enum.Material.Wood)
 if MeshKit.prop("LampPost",CFrame.new(base),parent,{scale=Vector3.new(1,height/3.2,1)}) then ghost(post) else
 block(parent,"LampPostFoot",Vector3.new(1.1,0.3,1.1),CFrame.new(base+Vector3.new(0,0.15,0)),iron,false,Enum.Material.Metal)
 end
 return light(parent,top+Vector3.new(0,0.7,0))
end
-- 천장(후갑판 바닥 밑)에 사슬로 매단 등불
local function hangingLight(parent,ceiling,drop)
 segment(parent,"LampChain",ceiling,ceiling-Vector3.new(0,drop,0),0.07,iron,false)
 return light(parent,ceiling-Vector3.new(0,drop+0.66,0))
end
function S:archive(lobby)
 local old=ServerStorage:FindFirstChild("Phase8_LobbyBackup")
 if not old then old=Instance.new("Folder");old.Name="Phase8_LobbyBackup";old.Parent=ServerStorage end
 -- 설명 게시판(Instructions)은 치운다. 게임 방법은 첫 접속 카드 한 장으로 충분하다.
 -- Phase 16 : 예전 선실 앞 랭킹판(RankingBoard)도 치운다. 랭킹은 스폰 앞 "명예의 문" 나무판자 셋이 보여 준다.
 local keep={Deck=true,HarborSea=true,LobbySpawn=true,ShopDisplay=true}
 for _,obj in ipairs(lobby:GetChildren()) do if not keep[obj.Name] and obj.Name~="PlayableGalleon" then obj.Parent=old end end
 local deck=lobby:FindFirstChild("Deck")
 if deck then deck.Transparency=1;deck.CanCollide=false;deck.CanQuery=false;deck.CanTouch=false end
end
function S:hull(root)
 local sections=51;local length=(L.Bow-L.Stern)/sections
 for i=1,sections do
  local z=L.Stern+(i-0.5)*length
  local half=L.halfWidth(z)
  local section=group(root,"HullSection_"..i)
  block(section,"MainDeck",Vector3.new(half*2,0.65,length+0.04),CFrame.new(0,L.DeckY-0.325,z),i%2==0 and Color3.fromRGB(133,88,49) or Color3.fromRGB(119,76,42),true)
  -- Three stepped hull strakes descend to the keel instead of a flat platform edge.
  for level=1,3 do
   local width=half*(1-(level-1)*0.13)
   for _,side in ipairs({-1,1}) do
    block(section,"HullStrake",Vector3.new(1.2,3.8,length+0.1),CFrame.new(side*width,0.7-level*3.3,z)*CFrame.Angles(0,0,-side*0.15),level==2 and dark or wood,false)
   end
  end
  -- Phase 24.14 : Blender 배 몸통 (판자 줄 · 굵은 띠 두 줄 · 놋쇠 줄). 원래 층층 판은 치운다
  local hullMeshed=false
  for _,side in ipairs({-1,1}) do
   if MeshKit.prop("HullSide",CFrame.new(0,1,z)*sideYaw(side),section,{scale=Vector3.new(half/57,1,(length+0.1)/5.9412),shadow=false}) then hullMeshed=true end
  end
  if hullMeshed then for _,c in ipairs(section:GetChildren()) do if c.Name=="HullStrake" then c:Destroy() end end end
  for _,side in ipairs({-1,1}) do
   local wallPart=block(section,"Bulwark",Vector3.new(0.8,3.5,length+0.04),CFrame.new(side*(half-0.4),2.5,z),wood,true)
   local cap=block(section,"RailCap",Vector3.new(1.1,0.25,length+0.08),CFrame.new(side*(half-0.4),4.4,z),gold,false,Enum.Material.Metal)
   -- Phase 24.13 : Blender 뱃전 (안팎 판자 · 나무 난간 머리 · 놋쇠 줄 · 물받이)
   if MeshKit.prop("Bulwark",CFrame.new(side*(half-0.4),1,z)*sideYaw(side),section,{scale=Vector3.new(1,1,(length+0.04)/5.9412),shadow=false}) then
    ghost(wallPart);cap:Destroy()
   end
   if i%3==0 then
    local post=block(section,"RailPost",Vector3.new(1.3,4.2,1.3),CFrame.new(side*(half-1),3.1,z),dark,true)
    if MeshKit.prop("RailPost",CFrame.new(side*(half-1),1,z)*sideYaw(side),section) then ghost(post) end
   end
  end
  -- Narrow deck seams communicate scale and direction without hundreds of boards.
  for _,x in ipairs({-36,-18,0,18,36}) do if math.abs(x)<half-2 then
   block(section,"PlankSeam",Vector3.new(0.04,0.018,length),CFrame.new(x,1.015,z),dark,false)
  end end
 end
 local stern=group(root,"SternTransom")
 -- Phase 24.14 : Blender 선미 (선실 뒷벽 창 다섯 · 발코니 · 선미판 띠 · 이름판). 부딪힘은 원래 판 · 벽이 맡는다
 MeshKit.prop("Stern",CFrame.new(0,1,L.CabinBack-0.4),stern,{shadow=false})
 block(stern,"Transom",Vector3.new(100,13,1.2),CFrame.new(0,-1,-158),wood,true)
 block(stern,"GoldSternTrim",Vector3.new(103,0.4,1.4),CFrame.new(0,4,-158),gold,false,Enum.Material.Metal)
 -- Phase 24.13 : Blender 뱃머리 돛대 (가늘어지는 둥근 기둥 · 쇠 띠 · 앞 돛대)
 if not MeshKit.prop("Bowsprit",CFrame.lookAt(Vector3.new(0,5,136),Vector3.new(0,12,177)),stern) then
  segment(stern,"Bowsprit",Vector3.new(0,5,136),Vector3.new(0,12,177),1.3,wood,false)
 end
end
function S:rigging(root)
 for i,z in ipairs(L.Masts) do
  local rig=group(root,"MastRig_"..i)
  local height=i==1 and 58 or 66
  local mastPart=cylinder(rig,"Mast",2.8,height,Vector3.new(0,1+height/2,z),wood,true,Enum.Material.Wood)
  local foot=cylinder(rig,"MastFoot",4.5,1.1,Vector3.new(0,1.55,z),iron,true,Enum.Material.Metal)
  -- Phase 24.13 : Blender 돛대 (쇠 띠 · 꼭대기 모자 · 밑동 깃 · 밧줄걸이 난간). 밧줄걸이 난간에도 부딪힌다
  if MeshKit.prop("Mast",CFrame.new(0,1,z),rig,{scale=Vector3.new(1,height/60,1)}) then
   ghost(mastPart);ghost(foot)
   wall(rig,"FifeRailWall",Vector3.new(6.3,3.1,6.3),CFrame.new(0,1+1.55,z))
  end
  for _,y in ipairs({28,43}) do
   -- Phase 24.12 : Blender 돛 (부푼 돛천 · 솔기 · 테두리 밧줄 · 활대 두 개)
   if MeshKit.prop("Sail",CFrame.new(0,y,z),rig,{shadow=false}) then continue end
   segment(rig,"Yardarm",Vector3.new(-24,y,z),Vector3.new(24,y,z),0.65,wood,false)
   -- Faceted cloth has a billowed profile, with seams and a lower scalloped edge.
   for j=1,8 do
    local x=(j-4.5)*5.8
    local bulge=math.cos(x/25*math.pi/2)*3.4
    local sail=block(rig,"SailCloth",Vector3.new(5.85,10.8,0.14),CFrame.new(x,y+5.5,z+bulge),Color3.fromRGB(224,210,177),false,Enum.Material.Fabric)
    sail:SetAttribute("DecorativeCloth",true)
    segment(rig,"SailSeam",Vector3.new(x-2.8,y,z+bulge),Vector3.new(x-2.8,y+11,z+bulge),0.045,gold,false)
   end
  end
  local nest=cylinder(rig,"CrowsNest",8,0.55,Vector3.new(0,height-4,z),dark,false)
  if MeshKit.prop("CrowsNest",CFrame.new(0,height-4,z),rig,{shadow=false}) then ghost(nest) end
  for _,side in ipairs({-1,1}) do
   for _,dz in ipairs({-16,16}) do
    segment(rig,"StandingRigging",Vector3.new(side*52,4,z+dz),Vector3.new(side*1.5,height-5,z),0.12,Color3.fromRGB(143,115,77),false)
    -- Phase 24.14 : 밧줄 발치의 데드아이 (쇠 띠 · 나무 도르래 둘 · 조임줄)
    MeshKit.prop("Deadeye",CFrame.new(side*52,4.4,z+dz)*sideYaw(side),rig,{shadow=false})
   end
   for j=1,9 do
    local t=j/10
    segment(rig,"Ratline",Vector3.new(side*(52*(1-t)),4+t*(height-9),z-16*(1-t)),Vector3.new(side*(52*(1-t)),4+t*(height-9),z+16*(1-t)),0.065,Color3.fromRGB(143,115,77),false)
   end
  end
  local flag=block(rig,"PirateFlag",Vector3.new(9,5,0.12),CFrame.new(4.5,height-0.5,z),Color3.fromRGB(22,24,28),false,Enum.Material.Fabric)
  local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Back;gui.Parent=flag
  local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.Text="☠";text.TextScaled=true;text.TextColor3=Color3.fromRGB(237,224,196);text.Parent=gui
 end
end
function S:lighting(root)
 for _,z in ipairs(L.LanternFrames) do
  local frame=group(root,"LanternArch_"..z)
  -- Phase 24.13 : Blender 등불 아치 (받침 · 기둥 · 둥근 버팀 · 들보 · 쇠 이음쇠 · 고리)
  local archMeshed=MeshKit.prop("Arch",CFrame.new(0,1,z),frame,{slotScale={Iron=Vector3.new(1,1,1.15)}}) -- 24.17 : 쇠띠가 가로대 앞뒤 면과 딱 겹쳐 깨져 보였다 → 쇠띠를 조금 두껍게
  for _,side in ipairs({-1,1}) do
   local up=block(frame,"Upright",Vector3.new(0.7,11,0.7),CFrame.new(side*11.5,6.5,z),wood,true)
   if archMeshed then ghost(up) else
   segment(frame,"KneeBrace",Vector3.new(side*11.5,9,z),Vector3.new(side*8.4,12,z),0.45,wood,false)
   end
  end
  if not archMeshed then block(frame,"Crossbeam",Vector3.new(25,0.75,0.75),CFrame.new(0,12,z),wood,false) end
  for _,side in ipairs({-1,1}) do
   local x=side*8.2
   segment(frame,"IronChain",Vector3.new(x,11.6,z),Vector3.new(x,9.9,z),0.08,iron,false)
   light(frame,Vector3.new(x,9.2,z))
  end
 end
end
function S:cabin(root,lobby)
 local cabin=group(root,"SternCabinAndQuarterdeck")
 local z=(L.CabinBack+L.CabinFront)/2
 block(cabin,"RearWall",Vector3.new(104,16,0.8),CFrame.new(0,9,L.CabinBack),wood,true)
 for _,side in ipairs({-1,1}) do
  block(cabin,"CabinSide",Vector3.new(0.8,16,52),CFrame.new(side*52,9,z),wood,true)
  block(cabin,"DoorPier",Vector3.new(39,16,0.8),CFrame.new(side*32.5,9,L.CabinFront),wood,true)
  for _,wx in ipairs({21,42}) do
   block(cabin,"FrontWindow",Vector3.new(12,6,0.22),CFrame.new(side*wx,10,L.CabinFront+0.55),Color3.fromRGB(90,161,159),false,Enum.Material.Glass).Transparency=0.25
   for _,dx in ipairs({-5.9,0,5.9}) do block(cabin,"WindowMullion",Vector3.new(0.2,6,0.3),CFrame.new(side*wx+dx,10,L.CabinFront+0.7),gold,false) end
   block(cabin,"WindowCrossbar",Vector3.new(12,0.2,0.3),CFrame.new(side*wx,10,L.CabinFront+0.7),gold,false)
  end
 end
 block(cabin,"DoorLintel",Vector3.new(26,4,1),CFrame.new(0,15,L.CabinFront),wood,true)
 -- Phase 24.14 : Blender 선실 안쪽 벽 (아래 판넬 · 허리 몰딩 · 세로 판자 · 기둥 · 처마). 전시장 안이 휑했다
 if MeshKit.has("CabinPanel") then
  for x=-45.5,45.5,13 do MeshKit.prop("CabinPanel",CFrame.new(x,1,L.CabinBack+0.4),cabin,{shadow=false}) end
  for _,side in ipairs({-1,1}) do
   for _,pz in ipairs({-148.5,-135.5,-122.5,-109.5}) do
    MeshKit.prop("CabinPanel",CFrame.new(side*51.6,1,pz)*CFrame.Angles(0,-side*math.pi/2,0),cabin,{shadow=false})
   end
  end
 end
 block(cabin,"QuarterdeckFloor",Vector3.new(107,0.8,54),CFrame.new(0,17.4,z),wood,true)
 local sternRail=block(cabin,"QuarterdeckSternRail",Vector3.new(106,3,0.7),CFrame.new(0,19,L.CabinBack),dark,true)
 local railed=MeshKit.has("Rail16") and MeshKit.has("Rail4")
 for _,side in ipairs({-1,1}) do
  local sideRail=block(cabin,"QuarterdeckSideRail",Vector3.new(0.7,3,54),CFrame.new(side*53,19,z),dark,true)
  -- Broad stairs rise along the ship sides; no decorative, non-colliding ramp.
  -- Phase 24.12 : Blender 계단 (디딤판 · 챌판 · 옆판 · 받침 기둥 · 양옆 난간)
  local origin=CFrame.new(side*47,1,-65)
  -- Phase 24.16 : 맨 윗칸 디딤판이 2층 바닥과 같은 높이라 겹쳐 깜빡였다 → 계단 메시만 0.06 내린다 (밟는 칸은 그대로)
  local meshed=MeshKit.prop("StairQ",origin*CFrame.new(0,-0.06,0),cabin)
  for i=1,24 do
   local step=block(cabin,"QuarterdeckStep",Vector3.new(7,0.7,1.65),CFrame.new(side*47,1+i*0.7-0.35,-65-i*1.62),wood,true)
   if meshed then ghost(step) end
  end
  if meshed then
   stairWalls(cabin,origin,24,0.7,1.62,1.65,7)
  else
   segment(cabin,"StairHandrail",Vector3.new(side*51,4,-67),Vector3.new(side*51,20,-104),0.25,gold,false)
   -- 손잡이를 그냥 통과하던 문제 : 손잡이 아래에 보이지 않는 벽
   local a,b=Vector3.new(side*51,2.6,-67),Vector3.new(side*51,18.6,-104)
   wall(cabin,"StairRailWall",Vector3.new(0.45,3,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b))
  end
  -- 후갑판 옆 난간 : 난간 기둥 · 난간동자 (부딪힘은 원래 난간 벽이 맡는다)
  if railed then
   ghost(sideRail)
   for _,rz in ipairs({-110,-126,-142}) do MeshKit.prop("Rail16",CFrame.new(side*53,17.8,rz),cabin) end
   MeshKit.prop("Rail4",CFrame.new(side*53,17.8,-152),cabin)
  end
 end
 if railed then
  ghost(sternRail)
  for _,rx in ipairs({-40,-24,-8,8,24,40}) do MeshKit.prop("Rail16",CFrame.new(rx,17.8,L.CabinBack)*CFrame.Angles(0,math.pi/2,0),cabin) end
  for _,side in ipairs({-1,1}) do
   MeshKit.prop("Rail4",CFrame.new(side*50,17.8,L.CabinBack)*CFrame.Angles(0,math.pi/2,0),cabin)
   -- 후갑판 앞 끝 (16 스터드 낭떠러지) : 계단 자리(x 43.5 ~ 50.5)만 비우고 난간을 두른다
   MeshKit.prop("Rail4",CFrame.new(side*41.5,17.8,-102.3)*CFrame.Angles(0,math.pi/2,0),cabin)
   MeshKit.prop("Rail4",CFrame.new(side*52,17.8,-102.3)*CFrame.Angles(0,math.pi/2,0),cabin,{scale=Vector3.new(1,1,0.75)})
   wall(cabin,"QuarterdeckFrontWall",Vector3.new(3,3,0.45),CFrame.new(side*52,19.3,-102.3))
  end
  for _,rx in ipairs({-32,-16,0,16,32}) do MeshKit.prop("Rail16",CFrame.new(rx,17.8,-102.3)*CFrame.Angles(0,math.pi/2,0),cabin) end
  wall(cabin,"QuarterdeckFrontWall",Vector3.new(87,3,0.45),CFrame.new(0,19.3,-102.3))
 end
 -- Ship's wheel on the raised quarterdeck, mounted to a pedestal.
 local wheel=Vector3.new(0,21,-112)
 local helmStand=block(cabin,"HelmStand",Vector3.new(1.8,3.4,1.8),CFrame.new(0,19.4,-112),wood,true)
 -- Phase 24.12 : Blender 조타륜 (손잡이 달린 바퀴 · 놋쇠 축 · 받침대). 받침대는 바퀴 앞(+Z)에 선다
 local helmMeshed=MeshKit.prop("Helm",CFrame.new(wheel),cabin)
 if helmMeshed then helmStand.Size=Vector3.new(1.4,3.4,1.4);helmStand.CFrame=CFrame.new(0,19.4,-111.25);ghost(helmStand) end
 for i=1,(helmMeshed and 0 or 12) do
  local a=i*math.pi/6;local b=(i+1)*math.pi/6
  local aPos=wheel+Vector3.new(math.cos(a)*2.6,math.sin(a)*2.6,0)
  local bPos=wheel+Vector3.new(math.cos(b)*2.6,math.sin(b)*2.6,0)
  segment(cabin,"WheelRim",aPos,bPos,0.24,wood,false)
  if i%2==0 then segment(cabin,"WheelSpoke",wheel,wheel+Vector3.new(math.cos(a)*3.1,math.sin(a)*3.1,0),0.18,gold,false) end
 end
 -- Phase 24.13 : Blender 선실 정면 (판자 · 기둥 · 처마 · 창틀 · 문 위 현판). 원래 벽은 부딪힘을 맡는다
 if MeshKit.prop("CabinFront",CFrame.new(0,1,L.CabinFront+0.4),cabin) then
  for _,c in ipairs(cabin:GetChildren()) do
   if c:IsA("BasePart") and (c.Name=="WindowMullion" or c.Name=="WindowCrossbar") then c:Destroy() end
  end
 end
 for _,x in ipairs({-47,-17,17,47}) do
  if not MeshKit.prop("WallLamp",CFrame.new(x,12,L.CabinFront+0.4),cabin) then
  segment(cabin,"CabinLampBracket",Vector3.new(x,12,L.CabinFront),Vector3.new(x,12,L.CabinFront+2),0.18,iron,false)
  segment(cabin,"CabinLampChain",Vector3.new(x,12,L.CabinFront+2),Vector3.new(x,11.3,L.CabinFront+2),0.07,iron,false)
  end
  light(cabin,Vector3.new(x,10.6,L.CabinFront+2))
 end
end
function S:forecastle(root,lobby)
 local front=group(root,"Forecastle")
 block(front,"RaisedBowDeck",Vector3.new(36,0.7,18),CFrame.new(0,5.15,121),wood,true)
 -- Phase 24.12 : Blender 계단 (뱃머리 갑판으로 올라가는 넓은 계단 · 양옆 난간)
 local bowOrigin=CFrame.new(0,1,101)*CFrame.Angles(0,math.pi,0)
 local bowMeshed=MeshKit.prop("StairB",bowOrigin*CFrame.new(0,-0.06,0),front) -- Phase 24.16 : 윗칸이 뱃머리 갑판과 겹치지 않게
 for i=1,7 do
  local step=block(front,"BowStep",Vector3.new(12,0.65,1.5),CFrame.new(0,1+i*0.64-0.325,101+i*1.5),wood,true)
  if bowMeshed then ghost(step) end
 end
 if bowMeshed then stairWalls(front,bowOrigin,7,0.64,1.5,1.5,12) end
 local spawn=lobby:FindFirstChild("LobbySpawn")
 if spawn then spawn.CFrame=CFrame.new(0,6,118);spawn.Size=Vector3.new(8,1,8);spawn.Transparency=1 end
 local capstan=cylinder(front,"AnchorCapstan",3.3,2.3,Vector3.new(0,6.65,126),iron,true,Enum.Material.Metal)
 -- Phase 24.12 : Blender 권양기 (드럼 · 갈빗대 · 막대 넷). 막대에도 부딪힌다
 if MeshKit.prop("Capstan",CFrame.new(0,5.5,126),front) then
  ghost(capstan)
  for _,a in ipairs({math.pi/4,-math.pi/4}) do wall(front,"CapstanBarWall",Vector3.new(7.4,0.35,0.35),CFrame.new(0,7.62,126)*CFrame.Angles(0,a,0)) end
 else
  segment(front,"CapstanBar",Vector3.new(-3,8,126),Vector3.new(3,8,126),0.3,wood,false)
 end
 for _,side in ipairs({-1,1}) do
  -- Phase 24.12 : Blender 난간. 예전 가로대는 부딪힘이 없어 그냥 통과했다 → 난간 높이의 보이지 않는 벽
  if not MeshKit.prop("Rail16",CFrame.new(side*17.5,5.5,121),front) then
   segment(front,"BowRailing",Vector3.new(side*17.5,8,113),Vector3.new(side*17.5,8,129),0.35,wood,false)
   for _,z in ipairs({113,121,129}) do block(front,"BowRailPost",Vector3.new(0.35,2.7,0.35),CFrame.new(side*17.5,6.85,z),wood,true) end
  end
  wall(front,"BowRailWall",Vector3.new(0.5,2.9,16.4),CFrame.new(side*17.5,5.5+1.45,121))
 end
end
-- Phase 16 : 명예의 문. 스폰에서 계단으로 내려가는 입구에 선 나무판자 랭킹판 셋 (연승 · 부자 · 승리)
--   판마다 세로 판자 여러 장 + 굵은 틀 + 금색 못 + 등불. 글자는 RankingService 가 RankingFace 에 그린다.
local planks={Color3.fromRGB(112,70,40),Color3.fromRGB(98,60,34),Color3.fromRGB(121,77,44),Color3.fromRGB(104,64,37)}
function S:hallOfFame(root)
 local hall=group(root,"HallOfFame")
 local H=L.HallOfFame
 local z=H.Z
 local back=z-0.55 -- 판자 뒷면
 -- 앞면이 +Z (스폰 쪽) 를 보는 방향
 local facing=CFrame.Angles(0,math.pi,0)
 local function nail(pos) local n=block(hall,"Nail",Vector3.new(0.34,0.34,0.34),CFrame.new(pos),gold,false,Enum.Material.Metal);n.Shape=Enum.PartType.Ball end
 local function board(spec)
  local w,h=spec.w,spec.h
  local cy=spec.bottom+h/2
  local before=snapshot(hall)
  local count=math.max(4,math.floor(w/1.7))
  for i=1,count do
   local x=spec.x-w/2+(i-0.5)*w/count
   block(hall,"Plank",Vector3.new(w/count-0.06,h,0.42),CFrame.new(x,cy,back+0.21),planks[i%#planks+1],true,Enum.Material.WoodPlanks)
  end
  -- 굵은 틀 (위 · 아래 · 양옆)
  block(hall,"FrameTop",Vector3.new(w+1.3,0.75,0.8),CFrame.new(spec.x,spec.bottom+h+0.3,back+0.35),dark,false,Enum.Material.Wood)
  block(hall,"FrameBottom",Vector3.new(w+1.3,0.6,0.8),CFrame.new(spec.x,spec.bottom-0.25,back+0.35),dark,false,Enum.Material.Wood)
  for _,side in ipairs({-1,1}) do
   block(hall,"FrameSide",Vector3.new(0.6,h+0.6,0.8),CFrame.new(spec.x+side*(w/2+0.35),cy,back+0.35),dark,false,Enum.Material.Wood)
   nail(Vector3.new(spec.x+side*(w/2+0.35),spec.bottom+h+0.3,back+0.8))
   nail(Vector3.new(spec.x+side*(w/2+0.35),spec.bottom-0.25,back+0.8))
  end
  -- 글자를 그리는 얇은 면 (보이지 않는 파트 · SurfaceGui 만 보인다)
  local face=block(hall,"RankingFace",Vector3.new(w-0.2,h-0.2,0.05),CFrame.new(spec.x,cy,back+0.47)*facing,dark,false,Enum.Material.SmoothPlastic)
  face.Transparency=1
  face:SetAttribute("Board",spec.id)
  Tags:AddTag(face,Config.Tags.RankingBoard)
  -- Phase 17 : 뒷면에도 같은 순위를 그린다 (주 갑판 · 계단 아래에서 올려다봐도 보이게)
  local backFace=block(hall,"RankingFace",Vector3.new(w-0.2,h-0.2,0.05),CFrame.new(spec.x,cy,back-0.08),dark,false,Enum.Material.SmoothPlastic)
  backFace.Transparency=1
  backFace:SetAttribute("Board",spec.id)
  backFace:SetAttribute("Side","Back")
  Tags:AddTag(backFace,Config.Tags.RankingBoard)
  for _,side in ipairs({-1,1}) do
   nail(Vector3.new(spec.x+side*(w/2+0.35),spec.bottom+h+0.3,back-0.12))
   nail(Vector3.new(spec.x+side*(w/2+0.35),spec.bottom-0.25,back-0.12))
  end
  -- Phase 24.13 : Blender 게시판 틀 (앞면이 +Z 를 보도록 반 바퀴)
  if MeshKit.prop(w>12 and "Board13" or "Board10",CFrame.new(spec.x,cy,back+0.21)*CFrame.Angles(0,math.pi,0),hall,{styles=BOARD_STYLE}) then ghostNew(hall,before) end
  return face
 end
 local left,center,right=H.Boards[1],H.Boards[2],H.Boards[3]
 -- 양옆 판 : 땅에 박은 기둥 두 개가 받친다
 for _,spec in ipairs({left,right}) do
  board(spec)
  for _,side in ipairs({-1,1}) do
   local x=spec.x+side*(spec.w/2+0.35)
   local top=spec.bottom+spec.h+1.1
   -- 가운데 쪽 기둥은 들보를 받치는 큰 기둥(ArchPost)이 대신한다
   if not (center and spec.x*side<0) then
   block(hall,"GatePost",Vector3.new(0.9,top-H.Base,0.9),CFrame.new(x,(H.Base+top)/2,back-0.2),dark,true,Enum.Material.Wood)
   block(hall,"PostCap",Vector3.new(1.3,0.35,1.3),CFrame.new(x,top+0.17,back-0.2),gold,false,Enum.Material.Metal)
   end
  end
 end
 -- 가운데 판 : 계단 입구 위에 가로 들보로 매단다 (아래로 지나다닐 수 있다)
 if center then
  board(center)
  local beamY=center.bottom+center.h+1.5
  local inner=left.x+left.w/2+0.35 -- 왼쪽 판의 안쪽 기둥 x
  for _,side in ipairs({-1,1}) do
   local x=side*math.abs(inner)
   block(hall,"ArchPost",Vector3.new(0.9,beamY-H.Base+0.4,0.9),CFrame.new(x,(H.Base+beamY+0.4)/2,back-0.2),dark,true,Enum.Material.Wood)
   segment(hall,"HangRope",Vector3.new(side*(center.w/2-0.8),beamY,back+0.1),Vector3.new(side*(center.w/2-0.8),center.bottom+center.h+0.5,back+0.1),0.16,Color3.fromRGB(150,120,80),false)
  end
  block(hall,"ArchBeam",Vector3.new(math.abs(inner)*2+1.6,0.9,1.1),CFrame.new(0,beamY+0.2,back-0.2),dark,false,Enum.Material.Wood)
  block(hall,"ArchTrim",Vector3.new(math.abs(inner)*2+1.8,0.2,1.2),CFrame.new(0,beamY+0.75,back-0.2),gold,false,Enum.Material.Metal)
  -- 들보 양 끝 등불
  for _,side in ipairs({-1,1}) do
   segment(hall,"LampArm",Vector3.new(side*(math.abs(inner)+0.2),beamY-0.4,back+0.2),Vector3.new(side*(math.abs(inner)+0.2),beamY-0.4,back+1.6),0.16,iron,false)
   light(hall,Vector3.new(side*(math.abs(inner)+0.2),beamY-1.2,back+1.6),22,1.8)
  end
 end
 MeshKit.dressPosts(hall) -- Phase 24.14 : Blender 기둥 · 들보
 -- 바깥 기둥 꼭대기 등불 (판을 비춘다) · Phase 17 : 뒷면 쪽에도 하나씩
 for _,spec in ipairs({left,right}) do
  local x=spec.x+(spec.x>0 and 1 or -1)*(spec.w/2+0.35)
  local top=spec.bottom+spec.h+1.1
  segment(hall,"LampArm",Vector3.new(x,top-0.6,back+0.2),Vector3.new(x,top-0.6,back+1.5),0.16,iron,false)
  light(hall,Vector3.new(x,top-1.35,back+1.5),20,1.7)
  segment(hall,"LampArm",Vector3.new(x,top-0.6,back-0.6),Vector3.new(x,top-0.6,back-1.9),0.16,iron,false)
  light(hall,Vector3.new(x,top-1.35,back-1.9),20,1.7)
 end
end
function S:nightLights(root)
 local extra=group(root,"NightLights")
 -- Phase 21 : 밤에 어둡던 곳 (테이블이 있는 양옆 줄 x ±20~40 · 등불 아치 사이) 을 높이 뜬 은은한 빛으로 채운다.
 --   등불 모양은 없고 빛만 있다 (LightController 가 밤 · 안개 · 폭풍에만 켠다). 등불 자리 지도로 빈 곳을 재서 골랐다
 for _,x in ipairs({-30,30}) do for _,z in ipairs({88,50,12,-26,-64}) do lanternSpot(Vector3.new(x,15,z),32,1.1,true) end end
 for _,z in ipairs({96,43,-11,-64}) do lanternSpot(Vector3.new(0,15,z),30,1,true) end
 -- 스폰 단상 (뱃머리 높은 갑판)
 -- (Phase 16 : 앞쪽 두 개는 "명예의 문" 기둥에 매단 등불로 바뀌었다. 판 앞을 가리지 않게)
 for _,x in ipairs({-12,12}) do postLight(extra,Vector3.new(x,5.5,127),3.4) end
 -- 뱃머리 끝
 postLight(extra,Vector3.new(0,5.5,129.2),2.6)
 -- 후갑판 (조타륜이 있는 2층) : 조타륜 양옆 · 양쪽 난간 · 선미 끝
 for _,x in ipairs({-7,7}) do postLight(extra,Vector3.new(x,17.8,-110),3.2) end
 -- 계단이 올라오는 길(x 43.5 ~ 50.5)을 막지 않게 난간 바로 안쪽에 세운다
 for _,side in ipairs({-1,1}) do for _,z in ipairs({-108,-141}) do postLight(extra,Vector3.new(side*51.6,17.8,z),3.2) end end
 for _,x in ipairs({-16,0,16}) do postLight(extra,Vector3.new(x,17.8,-150),3.2) end
 -- 선실 안 (전시장) : 후갑판 바닥 밑에 매단다
 for _,x in ipairs({-34,0,34}) do for _,z in ipairs({-113,-138}) do hangingLight(extra,Vector3.new(x,16.95,z),2.6) end end
 -- 뱃전 난간 (대포 쪽 가장자리)
 for _,side in ipairs({-1,1}) do for _,z in ipairs({72,24,-20,-66}) do
  local x=side*(L.halfWidth(z)-0.4)
  -- Phase 24.13 : Blender 난간 등불 걸이 (깎은 기둥 · 휘어진 쇠 팔 · 고리)
  if not MeshKit.prop("RailLamp",CFrame.new(x,4.525,z)*sideYaw(side),extra) then
  block(extra,"RailLampPost",Vector3.new(0.35,1.6,0.35),CFrame.new(x,5.3,z),dark,false,Enum.Material.Wood)
  segment(extra,"RailLampArm",Vector3.new(x,6.1,z),Vector3.new(x-side*1.4,6.1,z),0.18,iron,false)
  end
  light(extra,Vector3.new(x-side*1.4,5.3,z),18,1.6)
 end end
end
-- 함포 한 문. 바깥(side 방향)을 겨눈다.
-- ★ CannonTube 의 자리 · 길이(5.5)는 그대로다. 포구 위치(대포 판정 · 조준)가 여기서 나온다.
-- 포신 장식은 Barrel 모델 안에 함께 있어서 쏠 때 같이 뒤로 밀린다(반동).
local gunIron=Color3.fromRGB(40,42,48)
local gunRing=Color3.fromRGB(62,64,72)
local carriageWood=Color3.fromRGB(112,60,34)
local rope=Color3.fromRGB(150,120,80)
function S:cannon(root,side,z)
 local model=group(root,"Cannon_"..side.."_"..z)
 local x=side*50
 local y=3.2
 local function along(dx,length,diameter,name,color,material,parent)
  local p=block(parent or model,name,Vector3.new(length,diameter,diameter),CFrame.new(x+side*dx,y,z),color or gunIron,false,material or Enum.Material.Metal)
  p.Shape=Enum.PartType.Cylinder;p.Reflectance=0.12;return p
 end
 -- 포신
 local barrel=Instance.new("Model");barrel.Name="Barrel";barrel.Parent=model
 local tube=along(0,5.5,1.36,"CannonTube",gunIron,nil,barrel)
 barrel.PrimaryPart=tube
 -- Phase 15 : Blender 로 만든 대포가 있으면 그 모델을 쓴다. CannonTube 는 보이지 않게 남겨 둔다
 --   (대포 잡기 프롬프트 · 포구 위치 · 반동이 CannonTube 를 기준으로 한다)
 if MeshKit.has("Cannon") then
  tube.Transparency=1
  local origin=CFrame.new(x,y,z)*CFrame.Angles(0,side>0 and 0 or math.pi,0)
  MeshKit.place("CB_Cannon_Tube",origin,{parent=barrel,color=gunIron,material=Enum.Material.Metal,reflectance=0.12})
  MeshKit.place("CB_Cannon_Bore",origin,{parent=barrel,color=Color3.fromRGB(8,8,10),material=Enum.Material.SmoothPlastic})
  MeshKit.place("CB_Cannon_Carriage",origin,{parent=model,color=carriageWood,material=Enum.Material.Wood})
  MeshKit.place("CB_Cannon_Trucks",origin,{parent=model,color=Color3.fromRGB(74,42,24),material=Enum.Material.Wood})
  MeshKit.place("CB_Cannon_Iron",origin,{parent=model,color=iron,material=Enum.Material.Metal,reflectance=0.08})
 else
  along(-1.65,2.2,1.72,"Reinforce",gunIron,nil,barrel)
  along(-2.72,0.32,1.95,"BreechRing",gunRing,nil,barrel)
  along(-0.55,0.24,1.86,"TrunnionRing",gunRing,nil,barrel)
  along(0.95,0.2,1.56,"ChaseRing",gunRing,nil,barrel)
  along(2.45,0.72,1.66,"MuzzleSwell",gunIron,nil,barrel)
  along(2.8,0.2,1.84,"MuzzleLip",gunRing,nil,barrel)
  along(2.86,0.12,0.86,"Bore",Color3.fromRGB(8,8,10),Enum.Material.SmoothPlastic,barrel).Reflectance=0
  along(-3.0,0.46,0.5,"CascabelNeck",gunIron,nil,barrel)
  local knob=block(barrel,"Cascabel",Vector3.new(0.78,0.78,0.78),CFrame.new(x-side*3.35,y,z),gunIron,false,Enum.Material.Metal)
  knob.Shape=Enum.PartType.Ball;knob.Reflectance=0.12
  local trunnion=block(barrel,"Trunnions",Vector3.new(2.7,0.52,0.52),CFrame.new(x-side*0.2,y,z)*CFrame.Angles(0,math.pi/2,0),gunIron,false,Enum.Material.Metal)
  trunnion.Shape=Enum.PartType.Cylinder
  -- 포가 (계단 모양 옆판 · 굴대 · 바퀴 넷)
  for _,dz in ipairs({-1.05,1.05}) do
   block(model,"Cheek",Vector3.new(2.4,1.38,0.34),CFrame.new(x+side*0.7,2.58,z+dz),carriageWood,false)
   block(model,"CheekStep",Vector3.new(1.2,0.95,0.34),CFrame.new(x-side*1.1,2.37,z+dz),carriageWood,false)
   block(model,"CheekStep",Vector3.new(0.7,0.55,0.34),CFrame.new(x-side*2.05,2.17,z+dz),carriageWood,false)
   block(model,"CapSquare",Vector3.new(0.9,0.14,0.4),CFrame.new(x-side*0.2,3.5,z+dz),iron,false,Enum.Material.Metal)
   for _,dx in ipairs({-0.9,0.3,1.5}) do
    block(model,"Bolt",Vector3.new(0.14,0.14,0.38),CFrame.new(x+side*dx,2.3,z+dz),iron,false,Enum.Material.Metal)
   end
  end
  block(model,"Bed",Vector3.new(4.1,0.3,2.1),CFrame.new(x-side*0.2,1.9,z),carriageWood,false)
  local quoin=Instance.new("WedgePart");quoin.Name="Quoin";quoin.Size=Vector3.new(1.4,0.55,0.9)
  quoin.CFrame=CFrame.new(x-side*2.1,2.32,z)*CFrame.Angles(0,side>0 and math.pi/2 or -math.pi/2,0)
  quoin.Color=carriageWood;quoin.Material=Enum.Material.Wood;quoin.Anchored=true;quoin.CanCollide=false;quoin.CanQuery=false;quoin.CanTouch=false;quoin.CastShadow=false;quoin.Parent=model
  for _,axle in ipairs({{1.45,1.2},{-1.9,1.02}}) do
   local dx,wheelSize=axle[1],axle[2]
   local wy=1+wheelSize/2
   block(model,"AxleTree",Vector3.new(0.5,0.42,3.0),CFrame.new(x+side*dx,wy,z),carriageWood,false)
   for _,dz in ipairs({-1.5,1.5}) do
    local wheel=block(model,"Truck",Vector3.new(0.34,wheelSize,wheelSize),CFrame.new(x+side*dx,wy,z+dz)*CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(74,42,24),false,Enum.Material.Wood)
    wheel.Shape=Enum.PartType.Cylinder
    local hub=block(model,"TruckHub",Vector3.new(0.4,0.34,0.34),CFrame.new(x+side*dx,wy,z+dz)*CFrame.Angles(0,math.pi/2,0),iron,false,Enum.Material.Metal)
    hub.Shape=Enum.PartType.Cylinder
   end
  end
 end
 -- 부딪힘은 보이지 않는 상자 하나로 (장식 파트는 전부 부딪히지 않는다)
 local hit=block(model,"CarriageCollision",Vector3.new(5.2,2.4,3.4),CFrame.new(x,2.2,z),wood,true);hit.Transparency=1;hit.CanQuery=false
 -- 뱃전 쪽 포문과 고정 밧줄
 local half=L.halfWidth(z)
 block(model,"GunPort",Vector3.new(0.08,1.5,1.8),CFrame.new(side*(half-0.84),3.1,z),Color3.fromRGB(12,10,10),false,Enum.Material.SmoothPlastic)
 for _,edge in ipairs({{0,0.84,1.9,0.14},{0,-0.84,1.9,0.14},{0.97,0,0.14,1.82},{-0.97,0,0.14,1.82}}) do
  block(model,"GunPortFrame",Vector3.new(0.1,edge[4],edge[3]),CFrame.new(side*(half-0.88),3.1+edge[2],z+edge[1]),gold,false,Enum.Material.Metal)
 end
 for _,dz in ipairs({-2.6,2.6}) do
  local ring=Vector3.new(side*(half-0.9),3.0,z+dz)
  block(model,"RingBolt",Vector3.new(0.3,0.3,0.3),CFrame.new(ring),iron,false,Enum.Material.Metal)
  local a,b=ring,Vector3.new(x-side*1.9,2.5,z+dz*0.42)
  block(model,"BreechingRope",Vector3.new(0.16,0.16,(b-a).Magnitude),CFrame.lookAt((a+b)*0.5,b),rope,false,Enum.Material.Fabric)
 end
 -- 옆에 쌓아 둔 포탄
 local pile=Vector3.new(x-side*0.9,1,z+3.3)
 for _,o in ipairs({{-0.36,-0.36},{0.36,-0.36},{-0.36,0.36},{0.36,0.36}}) do
  local ball=block(model,"Shot",Vector3.new(0.72,0.72,0.72),CFrame.new(pile+Vector3.new(o[1],0.36,o[2])),Color3.fromRGB(28,28,32),false,Enum.Material.Metal)
  ball.Shape=Enum.PartType.Ball;ball.Reflectance=0.1
 end
 local top=block(model,"Shot",Vector3.new(0.72,0.72,0.72),CFrame.new(pile+Vector3.new(0,0.92,0)),Color3.fromRGB(28,28,32),false,Enum.Material.Metal)
 top.Shape=Enum.PartType.Ball
 -- 사용자 3D 모델 (ReleaseConfig.Meshes.Cannon 에 MeshId 를 넣으면 포신을 그 모델로 바꾼다)
 local meshes=Release.Meshes and Release.Meshes.Cannon
 if meshes and (tonumber(meshes.MeshId) or 0)>0 and not MeshKit.has("Cannon") then
  for _,piece in ipairs(barrel:GetChildren()) do if piece~=tube and piece:IsA("BasePart") then piece.Transparency=1 end end
  local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.FileMesh
  mesh.MeshId="rbxassetid://"..meshes.MeshId
  if (tonumber(meshes.TextureId) or 0)>0 then mesh.TextureId="rbxassetid://"..meshes.TextureId end
  mesh.Scale=meshes.Scale or Vector3.new(1,1,1);mesh.Offset=meshes.Offset or Vector3.new();mesh.Parent=tube
 end
 return model
end
-- Phase 24.10 : 최고 라운드 순위판. 토너먼트 게시판(F 테이블 오른쪽 옆)과 좌우 대칭으로 E 테이블 왼쪽 옆에 선다.
--   글자는 RankingService 가 RankingFace(Board = "round")에 그린다.
function S:roundBoard(root)
 local spot=L.Tables.Table_E;if not spot then return end
 local cx,cz=spot[1],spot[2]
 local side=cx>=0 and 1 or -1
 local foot=Vector3.new(cx+side*19,L.DeckY,cz+9)
 local frame=CFrame.lookAt(foot,Vector3.new(cx,L.DeckY,cz)) -- 앞면(LookVector)이 테이블을 본다
 local board=group(root,"RoundBoard")
 local w,h,bottom=9,8.4,2.4
 local before=snapshot(board)
 local cy=bottom+h/2
 local function at(x,y,z) return frame*CFrame.new(x,y,z) end
 for i=1,6 do
  local x=-w/2+(i-0.5)*w/6
  block(board,"Plank",Vector3.new(w/6-0.05,h,0.4),at(x,cy,0),planks[i%#planks+1],true,Enum.Material.WoodPlanks)
 end
 block(board,"FrameTop",Vector3.new(w+1.2,0.7,0.7),at(0,bottom+h+0.3,0),dark,false,Enum.Material.Wood)
 block(board,"FrameBottom",Vector3.new(w+1.2,0.6,0.7),at(0,bottom-0.25,0),dark,false,Enum.Material.Wood)
 local postH=bottom+h+0.9
 for _,sx in ipairs({-1,1}) do
  block(board,"FrameSide",Vector3.new(0.6,h+0.6,0.7),at(sx*(w/2+0.3),cy,0),dark,false,Enum.Material.Wood)
  block(board,"Post",Vector3.new(0.8,postH,0.8),at(sx*(w/2+0.95),postH/2,0),dark,true,Enum.Material.Wood)
  block(board,"PostCap",Vector3.new(1.15,0.3,1.15),at(sx*(w/2+0.95),postH+0.15,0),gold,false,Enum.Material.Metal)
 end
 -- 머리 현판 (파도 색)
 block(board,"HeaderPlaque",Vector3.new(6.4,1.4,0.5),at(0,bottom+h+1.3,0),Color3.fromRGB(28,78,110),false,Enum.Material.Wood)
 block(board,"HeaderTrim",Vector3.new(6.7,1.7,0.4),at(0,bottom+h+1.3,0),gold,false,Enum.Material.Metal)
 -- Phase 24.13 : 글자판은 판의 양면에 하나씩. 각 면의 앞(SurfaceGui Front)이 바깥을 보도록 CFrame.lookAt 으로 직접 세운다
 --   (한 면만 · 반대로 보인다는 제보. 판자 · 틀 메시보다 바깥(±0.3)에 둔다)
 local centre=at(0,cy,0).Position
 local normal=frame.LookVector
 local function face(sign)
  local pos=centre+normal*(sign*0.3)
  local f=block(board,"RankingFace",Vector3.new(w-0.3,h-0.3,0.05),CFrame.lookAt(pos,pos+normal*sign),dark,false,Enum.Material.SmoothPlastic)
  f.Transparency=1;f:SetAttribute("Board","round")
  if sign<0 then f:SetAttribute("Side","Back") end
  Tags:AddTag(f,Config.Tags.RankingBoard)
 end
 MeshKit.dressPosts(board) -- Phase 24.14 : Blender 기둥
 face(1) -- 테이블 쪽
 face(-1) -- 뱃전 쪽
 if MeshKit.prop("Board9",at(0,cy,0),board,{styles=BOARD_STYLE}) then ghostNew(board,before) end
end
function S:props(root)
 for _,side in ipairs({-1,1}) do
  for _,z in ipairs(L.CannonZ) do
   S:cannon(root,side,z)
   -- Phase 24.13 : 포신이 뱃전을 지나는 자리의 포문 (나무 틀 · 어두운 구멍 · 위로 열린 뚜껑)
   MeshKit.prop("GunPort",CFrame.new(side*(L.halfWidth(z)-0.4),3.2,z)*sideYaw(side),root)
  end
  for i,z in ipairs({-80,-58,-20,24,72}) do
   -- Phase 24.10 : z -20 짐(나무통 · 상자)은 게시판 아래에 겹쳐서 뺀다
   --   오른쪽 = 토너먼트 게시판(F 테이블 옆 x 44~48, z -12~-22) · 왼쪽 = 최고 라운드 게시판(E 테이블 옆, 좌우 대칭)
   if z==-20 then continue end
   local cargo=group(root,"SecuredCargo_"..side.."_"..i)
   local x=side*42
   local crate=block(cargo,"Crate",Vector3.new(3.2,3.2,3.2),CFrame.new(x,2.6,z),wood,true)
   -- Phase 24.12 : Blender 짐 상자 (판자 · 모서리 각목 · 쇠 모서리 · 밧줄 묶음)
   local crateMeshed=MeshKit.prop("Crate",CFrame.new(x,2.6,z),cargo)
   if crateMeshed then ghost(crate) else
   for _,dy in ipairs({-1.1,1.1}) do block(cargo,"CrateBand",Vector3.new(3.3,0.16,3.3),CFrame.new(x,2.6+dy,z),iron,false) end
   end
   local cask=cylinder(cargo,"CargoBarrel",2.6,3.3,Vector3.new(x+side*4,2.65,z+2),wood,true)
   -- Phase 15 : Blender 나무통 (부딪힘은 원래 원통이 맡고 보이지 않게 된다)
   local meshed=MeshKit.has("Cask") and MeshKit.build("Cask",CFrame.new(x+side*4,2.65,z+2)*CFrame.Angles(0,z*0.37,0),
    {parent=cargo,scale=Vector3.new(2.6/3.5,3.3/4,2.6/3.5),color=wood,material=Enum.Material.Wood},
    {CB_Cask_Hoops={color=iron,material=Enum.Material.Metal}})
   if meshed then cask.Transparency=1 else
    for _,y in ipairs({1.6,3.6}) do cylinder(cargo,"IronHoop",2.75,0.18,Vector3.new(x+side*4,y,z+2),iron,false,Enum.Material.Metal) end
   end
   if not crateMeshed then segment(cargo,"TieDown",Vector3.new(x-2,1.2,z-2),Vector3.new(x+2,4.3,z+2),0.1,gold,false) end
  end
 end
 -- Flush central grating and ship furniture occupy gaps, never chair access rings.
 for _,z in ipairs({-6,-77}) do
  local hatch=group(root,"CargoHatch_"..z)
  local frame=block(hatch,"HatchFrame",Vector3.new(9,0.2,7),CFrame.new(0,1.1,z),iron,true)
  -- Phase 24.12 : Blender 화물 창 (나무 턱 · 격자 · 쇠 모서리 · 손잡이 고리)
  if MeshKit.prop("Hatch",CFrame.new(0,1,z),hatch) then ghost(frame) else
  for i=-3,3 do block(hatch,"HatchGrate",Vector3.new(0.35,0.16,6.6),CFrame.new(i,1.27,z),gold,false) end
  end
 end
end
function S:Prepare()
 if self.started then return end;self.started=true
 local lobby=workspace:WaitForChild("Lobby")
 self:archive(lobby)
 for _,model in ipairs(Tags:GetTagged(Config.Tags.Table)) do
  local position=L.Tables[model.Name]
  local top=model:FindFirstChild("TableTop",true)
  if position and top then
   local offset=Vector3.new(position[1]-top.Position.X,(position[3] or top.Position.Y)-top.Position.Y,position[2]-top.Position.Z)
   model:PivotTo(model:GetPivot()+offset)
  end
 end
 Config.Showcase.Z=L.Showcase.Z;Config.Showcase.SignZ=L.Showcase.SignZ
 Config.Showcase.Columns=L.Showcase.Columns;Config.Showcase.RowSpacing=L.Showcase.RowSpacing
 for _,zone in ipairs(Config.Showcase.Zones) do zone.x=L.Showcase.Centers[zone.kind] end
 local root=Instance.new("Folder");root.Name="PlayableGalleon";root.Parent=lobby
 lightFolder=Instance.new("Folder");lightFolder.Name="ShipLights";lightFolder.Parent=root
 self:hull(root);self:rigging(root);self:lighting(root);self:cabin(root,lobby);self:forecastle(root,lobby);self:hallOfFame(root);self:roundBoard(root);self:nightLights(root);self:props(root)
 workspace:SetAttribute("ShipLobbyReady",true)
 print("[CursedBarrel] Playable galleon ready: 9 tables, supported lights, cabin and quarterdeck")
end
return S
