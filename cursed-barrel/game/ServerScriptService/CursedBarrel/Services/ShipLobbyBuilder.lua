-- The lobby itself is a traversable galleon. Run BEFORE table registration.
-- Functional instances and all TableIds are retained; obsolete dock decor is archived.
local RS=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Tags=game:GetService("CollectionService")
local Shared=RS.CursedBarrel.Shared
local Config=require(Shared.GameConfig)
local L=require(Shared.ShipLayout)
local Release=require(Shared.ReleaseConfig)
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
-- 등불은 전부 ShipLights 폴더 하나에 모으고 Persistent 로 둔다.
-- (Atomic 으로 두면 스트리밍이 등불을 늦게 보내서, 처음 들어와 스폰 단상에 서 있는 동안 배가 캄캄했다)
local lightFolder=nil
local function light(_,pos,range,brightness)
 -- Every light has a cap, cage, chain and a visible structural attachment.
 local lamp=Instance.new("Model");lamp.Name="SupportedLantern";lamp.ModelStreamingMode=Enum.ModelStreamingMode.Persistent;lamp.Parent=lightFolder
 block(lamp,"Glass",Vector3.new(0.8,1.1,0.8),CFrame.new(pos),Color3.fromRGB(255,193,93),false,Enum.Material.Neon).Transparency=0.15
 for _,y in ipairs({-0.66,0.66}) do block(lamp,"Cap",Vector3.new(1.2,0.17,1.2),CFrame.new(pos+Vector3.new(0,y,0)),iron,false,Enum.Material.Metal) end
 for _,x in ipairs({-0.48,0.48}) do for _,z in ipairs({-0.48,0.48}) do
  block(lamp,"Cage",Vector3.new(0.08,1.3,0.08),CFrame.new(pos+Vector3.new(x,0,z)),iron,false,Enum.Material.Metal)
 end end
 local p=lamp:FindFirstChild("Glass")
 local point=Instance.new("PointLight");point.Color=Color3.fromRGB(255,200,128);point.Range=range or 20;point.Brightness=brightness or 1.8;point.Shadows=false;point.Parent=p
 lamp:SetAttribute("StructurallySupported",true)
 return lamp
end
-- 기둥 위에 올린 등불 (갑판 · 후갑판 · 뱃머리)
local function postLight(parent,base,height)
 local top=base+Vector3.new(0,height,0)
 block(parent,"LampPost",Vector3.new(0.45,height,0.45),CFrame.new(base+Vector3.new(0,height/2,0)),dark,true,Enum.Material.Wood)
 block(parent,"LampPostFoot",Vector3.new(1.1,0.3,1.1),CFrame.new(base+Vector3.new(0,0.15,0)),iron,false,Enum.Material.Metal)
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
 local keep={Deck=true,HarborSea=true,RankingBoard=true,LobbySpawn=true,ShopDisplay=true}
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
  for _,side in ipairs({-1,1}) do
   block(section,"Bulwark",Vector3.new(0.8,3.5,length+0.04),CFrame.new(side*(half-0.4),2.5,z),wood,true)
   block(section,"RailCap",Vector3.new(1.1,0.25,length+0.08),CFrame.new(side*(half-0.4),4.4,z),gold,false,Enum.Material.Metal)
   if i%3==0 then block(section,"RailPost",Vector3.new(1.3,4.2,1.3),CFrame.new(side*(half-1),3.1,z),dark,true) end
  end
  -- Narrow deck seams communicate scale and direction without hundreds of boards.
  for _,x in ipairs({-36,-18,0,18,36}) do if math.abs(x)<half-2 then
   block(section,"PlankSeam",Vector3.new(0.04,0.018,length),CFrame.new(x,1.015,z),dark,false)
  end end
 end
 local stern=group(root,"SternTransom")
 block(stern,"Transom",Vector3.new(100,13,1.2),CFrame.new(0,-1,-158),wood,true)
 block(stern,"GoldSternTrim",Vector3.new(103,0.4,1.4),CFrame.new(0,4,-158),gold,false,Enum.Material.Metal)
 segment(stern,"Bowsprit",Vector3.new(0,5,136),Vector3.new(0,12,177),1.3,wood,false)
end
function S:rigging(root)
 for i,z in ipairs(L.Masts) do
  local rig=group(root,"MastRig_"..i)
  local height=i==1 and 58 or 66
  cylinder(rig,"Mast",2.8,height,Vector3.new(0,1+height/2,z),wood,true,Enum.Material.Wood)
  cylinder(rig,"MastFoot",4.5,1.1,Vector3.new(0,1.55,z),iron,true,Enum.Material.Metal)
  for _,y in ipairs({28,43}) do
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
  cylinder(rig,"CrowsNest",8,0.55,Vector3.new(0,height-4,z),dark,false)
  for _,side in ipairs({-1,1}) do
   for _,dz in ipairs({-16,16}) do
    segment(rig,"StandingRigging",Vector3.new(side*52,4,z+dz),Vector3.new(side*1.5,height-5,z),0.12,Color3.fromRGB(143,115,77),false)
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
  for _,side in ipairs({-1,1}) do
   block(frame,"Upright",Vector3.new(0.7,11,0.7),CFrame.new(side*11.5,6.5,z),wood,true)
   segment(frame,"KneeBrace",Vector3.new(side*11.5,9,z),Vector3.new(side*8.4,12,z),0.45,wood,false)
  end
  block(frame,"Crossbeam",Vector3.new(25,0.75,0.75),CFrame.new(0,12,z),wood,false)
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
 block(cabin,"QuarterdeckFloor",Vector3.new(107,0.8,54),CFrame.new(0,17.4,z),wood,true)
 block(cabin,"QuarterdeckSternRail",Vector3.new(106,3,0.7),CFrame.new(0,19,L.CabinBack),dark,true)
 for _,side in ipairs({-1,1}) do
  block(cabin,"QuarterdeckSideRail",Vector3.new(0.7,3,54),CFrame.new(side*53,19,z),dark,true)
  -- Broad stairs rise along the ship sides; no decorative, non-colliding ramp.
  for i=1,24 do
   block(cabin,"QuarterdeckStep",Vector3.new(7,0.7,1.65),CFrame.new(side*47,1+i*0.7-0.35,-65-i*1.62),wood,true)
  end
  segment(cabin,"StairHandrail",Vector3.new(side*51,4,-67),Vector3.new(side*51,20,-104),0.25,gold,false)
 end
 -- Ship's wheel on the raised quarterdeck, mounted to a pedestal.
 local wheel=Vector3.new(0,21,-112)
 block(cabin,"HelmStand",Vector3.new(1.8,3.4,1.8),CFrame.new(0,19.4,-112),wood,true)
 for i=1,12 do
  local a=i*math.pi/6;local b=(i+1)*math.pi/6
  local aPos=wheel+Vector3.new(math.cos(a)*2.6,math.sin(a)*2.6,0)
  local bPos=wheel+Vector3.new(math.cos(b)*2.6,math.sin(b)*2.6,0)
  segment(cabin,"WheelRim",aPos,bPos,0.24,wood,false)
  if i%2==0 then segment(cabin,"WheelSpoke",wheel,wheel+Vector3.new(math.cos(a)*3.1,math.sin(a)*3.1,0),0.18,gold,false) end
 end
 for _,x in ipairs({-47,-17,17,47}) do
  segment(cabin,"CabinLampBracket",Vector3.new(x,12,L.CabinFront),Vector3.new(x,12,L.CabinFront+2),0.18,iron,false)
  segment(cabin,"CabinLampChain",Vector3.new(x,12,L.CabinFront+2),Vector3.new(x,11.3,L.CabinFront+2),0.07,iron,false)
  light(cabin,Vector3.new(x,10.6,L.CabinFront+2))
 end
 local ranking=lobby:FindFirstChild("RankingBoard")
 if ranking then ranking.CFrame=CFrame.new(-34,9,-95);ranking.Size=Vector3.new(23,11,0.6) end
 -- The ranking board rests on posts instead of floating in front of the cabin.
 for _,x in ipairs({-43,-25}) do block(cabin,"BoardPost",Vector3.new(0.65,8,0.65),CFrame.new(x,5,-95),wood,true) end
end
function S:forecastle(root,lobby)
 local front=group(root,"Forecastle")
 block(front,"RaisedBowDeck",Vector3.new(36,0.7,18),CFrame.new(0,5.15,121),wood,true)
 for i=1,7 do block(front,"BowStep",Vector3.new(12,0.65,1.5),CFrame.new(0,1+i*0.64-0.325,101+i*1.5),wood,true) end
 local spawn=lobby:FindFirstChild("LobbySpawn")
 if spawn then spawn.CFrame=CFrame.new(0,6,118);spawn.Size=Vector3.new(8,1,8);spawn.Transparency=1 end
 cylinder(front,"AnchorCapstan",3.3,2.3,Vector3.new(0,6.65,126),iron,true,Enum.Material.Metal)
 segment(front,"CapstanBar",Vector3.new(-3,8,126),Vector3.new(3,8,126),0.3,wood,false)
 for _,side in ipairs({-1,1}) do
  segment(front,"BowRailing",Vector3.new(side*17.5,8,113),Vector3.new(side*17.5,8,129),0.35,wood,false)
  for _,z in ipairs({113,121,129}) do block(front,"BowRailPost",Vector3.new(0.35,2.7,0.35),CFrame.new(side*17.5,6.85,z),wood,true) end
 end
end
function S:nightLights(root)
 local extra=group(root,"NightLights")
 -- 스폰 단상 (뱃머리 높은 갑판)
 for _,x in ipairs({-12,12}) do for _,z in ipairs({114,127}) do postLight(extra,Vector3.new(x,5.5,z),3.4) end end
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
  block(extra,"RailLampPost",Vector3.new(0.35,1.6,0.35),CFrame.new(x,5.3,z),dark,false,Enum.Material.Wood)
  segment(extra,"RailLampArm",Vector3.new(x,6.1,z),Vector3.new(x-side*1.4,6.1,z),0.18,iron,false)
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
 if meshes and (tonumber(meshes.MeshId) or 0)>0 then
  for _,piece in ipairs(barrel:GetChildren()) do if piece~=tube and piece:IsA("BasePart") then piece.Transparency=1 end end
  local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.FileMesh
  mesh.MeshId="rbxassetid://"..meshes.MeshId
  if (tonumber(meshes.TextureId) or 0)>0 then mesh.TextureId="rbxassetid://"..meshes.TextureId end
  mesh.Scale=meshes.Scale or Vector3.new(1,1,1);mesh.Offset=meshes.Offset or Vector3.new();mesh.Parent=tube
 end
 return model
end
function S:props(root)
 for _,side in ipairs({-1,1}) do
  for _,z in ipairs(L.CannonZ) do
   S:cannon(root,side,z)
  end
  for i,z in ipairs({-80,-58,-20,24,72}) do
   local cargo=group(root,"SecuredCargo_"..side.."_"..i)
   local x=side*42
   block(cargo,"Crate",Vector3.new(3.2,3.2,3.2),CFrame.new(x,2.6,z),wood,true)
   for _,dy in ipairs({-1.1,1.1}) do block(cargo,"CrateBand",Vector3.new(3.3,0.16,3.3),CFrame.new(x,2.6+dy,z),iron,false) end
   cylinder(cargo,"CargoBarrel",2.6,3.3,Vector3.new(x+side*4,2.65,z+2),wood,true)
   for _,y in ipairs({1.6,3.6}) do cylinder(cargo,"IronHoop",2.75,0.18,Vector3.new(x+side*4,y,z+2),iron,false,Enum.Material.Metal) end
   segment(cargo,"TieDown",Vector3.new(x-2,1.2,z-2),Vector3.new(x+2,4.3,z+2),0.1,gold,false)
  end
 end
 -- Flush central grating and ship furniture occupy gaps, never chair access rings.
 for _,z in ipairs({-6,-77}) do
  local hatch=group(root,"CargoHatch_"..z)
  block(hatch,"HatchFrame",Vector3.new(9,0.2,7),CFrame.new(0,1.1,z),iron,true)
  for i=-3,3 do block(hatch,"HatchGrate",Vector3.new(0.35,0.16,6.6),CFrame.new(i,1.27,z),gold,false) end
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
   local offset=Vector3.new(position[1]-top.Position.X,0,position[2]-top.Position.Z)
   model:PivotTo(model:GetPivot()+offset)
  end
 end
 Config.Showcase.Z=L.Showcase.Z;Config.Showcase.SignZ=L.Showcase.SignZ
 Config.Showcase.Columns=L.Showcase.Columns;Config.Showcase.RowSpacing=L.Showcase.RowSpacing
 for _,zone in ipairs(Config.Showcase.Zones) do zone.x=L.Showcase.Centers[zone.kind] end
 local root=Instance.new("Folder");root.Name="PlayableGalleon";root.Parent=lobby
 lightFolder=Instance.new("Folder");lightFolder.Name="ShipLights";lightFolder.Parent=root
 self:hull(root);self:rigging(root);self:lighting(root);self:cabin(root,lobby);self:forecastle(root,lobby);self:nightLights(root);self:props(root)
 workspace:SetAttribute("ShipLobbyReady",true)
 print("[CursedBarrel] Playable galleon ready: 10 tables, supported lights, cabin and quarterdeck")
end
return S
