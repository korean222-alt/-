-- Client-only 3D shop inspection. The WorldModel uses the same PremiumFX geometry.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local Config=require(script.Parent.GameConfig)
local FX=require(script.Parent.PremiumFX)
local Preview={}
local current=nil
local spin=nil
local function p(parent,name,size,cf,color,material,shape)
 local x=Instance.new("Part");x.Name=name;x.Size=size;x.CFrame=cf;x.Color=color or Color3.new(1,1,1);x.Material=material or Enum.Material.Metal
 x.Anchored=true;x.CanCollide=false;x.CanTouch=false;x.CanQuery=false;x.CastShadow=false;if shape then x.Shape=shape end;x.Parent=parent;return x
end
function Preview.build(kind,skin,parent,live)
 local m=Instance.new("Model");m.Name="Skin";m.Parent=parent
 if kind=="Knife" then
  -- Phase 14 : 끝이 뾰족한 날 · 홈 · 코등이 구슬 · 감은 손잡이 · 폼멜 (스킨마다 모양이 다르다)
  m:Destroy();m=require(script.Parent.KnifeModel).build(skin,parent,CFrame.new(0,-0.9,0)*CFrame.Angles(0,0,math.rad(-8)),1);m.Name="Skin"
 elseif kind=="Barrel" then
  local body=p(m,"Body",Vector3.new(3.1,2.7,2.7),CFrame.Angles(0,0,math.pi/2),skin.body,skin.bodyMaterial,Enum.PartType.Cylinder);body.Reflectance=skin.reflectance or 0
  -- Phase 15 : Blender 통 · 드럼 메시가 있으면 그것으로 (게임 테이블과 같은 모양)
  local meshed=require(script.Parent.MeshKit).barrel(skin,m,body.CFrame,3.1,2.7,"BodyMesh")
  if meshed then body.Transparency=1 end
  if not skin.drum and not meshed then for _,y in ipairs({-1.15,1.15}) do p(m,"Hoop",Vector3.new(0.25,2.84,2.84),CFrame.new(0,y,0)*CFrame.Angles(0,0,math.pi/2),skin.hoop,skin.hoopMaterial,Enum.PartType.Cylinder) end end
  p(m,"Lid",Vector3.new(0.15,2.7,2.7),CFrame.new(0,1.6,0)*CFrame.Angles(0,0,math.pi/2),skin.lid,skin.hoopMaterial,Enum.PartType.Cylinder).Reflectance=skin.reflectance or 0
  -- Phase 13 : 철제 드럼 (굴림 테 · 주름 · 마개)
  if skin.drum then require(script.Parent.DrumStyle).build(m,body.CFrame,3.1,2.7,skin,"Drum",1.675,meshed~=nil) end
  -- Phase 14 : 나무 통은 판자 결 · 양 끝 쇠테
  if not meshed then require(script.Parent.BarrelStyle).decorate(m,body.CFrame,3.1,2.7,skin) end
 elseif kind=="Ghost" then
  -- Phase 17 : 게임에서 튀어나오는 해적과 같은 모델 (Blender 해적이 있으면 그것)
  local ok,rig=pcall(require(script.Parent.PirateModel).new,skin,script.Parent.Parent:FindFirstChild("Visuals"))
  if ok and rig then m:Destroy();m=rig.model;m.Name="Skin";m.Parent=parent end
 elseif kind=="Chair" then
  local seat=p(m,"Seat",Vector3.new(2,0.4,2),CFrame.new(0,-1,0),Color3.fromRGB(56,38,32))
  p(m,"Back",Vector3.new(2,2.6,0.3),CFrame.new(0,0.1,0.85),Color3.fromRGB(56,38,32));FX.chair(seat,skin)
  for _,x in ipairs({-0.8,0.8}) do for _,z in ipairs({-0.8,0.8}) do p(m,"Leg",Vector3.new(0.18,1.5,0.18),CFrame.new(x,-1.8,z),Color3.fromRGB(74,48,32)) end end
 else
  p(m,"Spirit",Vector3.new(1.2,2,1.2),CFrame.new(),skin.fx and skin.fx.emit or Color3.fromRGB(238,203,114),Enum.Material.Neon,Enum.PartType.Ball)
 end
 FX.decorate(m,skin,kind)
 -- Phase 17 : 전설 · 신화는 룬 고리 · 도는 Blender 용 · 꽃잎 (SkinMotion 이 이 창 안에서 움직인다)
 local SkinFX=require(script.Parent.SkinFX)
 local anchor=(kind=="Knife" and m:FindFirstChild("Blade",true)) or (kind=="Barrel" and m:FindFirstChild("Body",true)) or m:FindFirstChild("Coat",true)
 local marker=anchor and SkinFX.motion(m,skin,kind,anchor)
 if marker and not live then marker:SetAttribute("Static",true) end -- 상점 카드의 작은 그림은 한 번만 놓는다 (휴대폰 부담)
 local meshDragon=marker~=nil and require(script.Parent.MeshKit).has(kind=="Barrel" and "DragonRing" or "DragonCoil")
 if skin.fx and skin.fx.theme=="dragon" and not meshDragon then FX.previewDragon(m,skin) end
 return m
end
-- Phase 24 : "이게 뭐고 어디에 쓰는지" 를 한 줄로. 상점 분류 머리말 · 미리보기 창에 같이 쓴다.
Preview.Usage={
 Knife="내 차례에 통에 꽂는 칼 모양이에요. 테이블의 모두에게 보여요.",
 Barrel="테이블 가운데 통 모양이에요. 앉은 사람 중 한 명의 통이 그 판에 쓰여요.",
 Ghost="통에서 튀어나오는 해적 모양이에요.",
 Stab="내 차례에 칼을 꽂을 때 내 캐릭터가 하는 동작이에요. 테이블의 모두가 봐요.",
 Chair="테이블에 앉으면 내 자리 의자가 이 모양으로 바뀌어요. 모두에게 보여요.",
 Elimination="내가 해적에게 잡혀 탈락할 때 내 자리에서 터지는 연출이에요.",
 Victory="판에서 이기면 테이블 위에서 터지는 우승 연출이에요.",
}
-- Phase 24 : 동작 · 연출 스킨은 예전에 빛나는 공 하나만 보여서 무엇인지 알 수 없었다.
--   이제 작은 선원 인형(R6 관절)을 세우고 그 동작 · 연출을 되풀이해 보여 준다.
--   관절은 매 프레임 직접 계산해 놓는다 (창 안의 WorldModel 이 관절을 풀어 주지 않아도 움직이게).
local function motor(name,p0,p1,c0,c1) local m=Instance.new("Motor6D");m.Name=name;m.Part0=p0;m.Part1=p1;m.C0=c0;m.C1=c1;m.Parent=p0;return m end
local function dummy(parent,base)
 local m=Instance.new("Model");m.Name="Dummy";m.Parent=parent
 local skinTone=Color3.fromRGB(236,204,164);local coat=Color3.fromRGB(58,74,112);local dark=Color3.fromRGB(34,30,34)
 local root=p(m,"HumanoidRootPart",Vector3.new(2,2,1),base,skinTone,Enum.Material.SmoothPlastic);root.Transparency=1
 local torso=p(m,"Torso",Vector3.new(2,2,1),base,coat,Enum.Material.Fabric)
 local head=p(m,"Head",Vector3.new(1.25,1.25,1.25),base,skinTone,Enum.Material.SmoothPlastic,Enum.PartType.Ball)
 local ra=p(m,"Right Arm",Vector3.new(1,2,1),base,coat,Enum.Material.Fabric)
 local la=p(m,"Left Arm",Vector3.new(1,2,1),base,coat,Enum.Material.Fabric)
 local rl=p(m,"Right Leg",Vector3.new(1,2,1),base,dark,Enum.Material.Fabric)
 local ll=p(m,"Left Leg",Vector3.new(1,2,1),base,dark,Enum.Material.Fabric)
 local hat=p(m,"Hat",Vector3.new(0.2,2.2,2.2),base,dark,Enum.Material.Fabric,Enum.PartType.Cylinder)
 local R=CFrame.new(0,0,0,-1,0,0,0,0,1,0,1,0)
 local motors={
  motor("RootJoint",root,torso,R,R),
  motor("Neck",torso,head,CFrame.new(0,1,0)*R,CFrame.new(0,-0.6,0)*R),
  motor("Right Shoulder",torso,ra,CFrame.new(1,0.5,0,0,0,1,0,1,0,-1,0,0),CFrame.new(-0.5,0.5,0,0,0,1,0,1,0,-1,0,0)),
  motor("Left Shoulder",torso,la,CFrame.new(-1,0.5,0,0,0,-1,0,1,0,1,0,0),CFrame.new(0.5,0.5,0,0,0,-1,0,1,0,1,0,0)),
  motor("Right Hip",torso,rl,CFrame.new(1,-1,0,0,0,1,0,1,0,-1,0,0),CFrame.new(0.5,1,0,0,0,1,0,1,0,-1,0,0)),
  motor("Left Hip",torso,ll,CFrame.new(-1,-1,0,0,0,-1,0,1,0,1,0,0),CFrame.new(-0.5,1,0,0,0,-1,0,1,0,1,0,0)),
 }
 local extras={{part=hat,to=head,offset=CFrame.new(0,0.62,0)*CFrame.Angles(0,0,math.pi/2)}}
 local function pose()
  for _,j in ipairs(motors) do if j.Part0 and j.Part1 then j.Part1.CFrame=j.Part0.CFrame*j.C0*j.C1:Inverse() end end
  for _,e in ipairs(extras) do if e.part.Parent then e.part.CFrame=e.to.CFrame*e.offset end end
 end
 pose()
 return m,pose,extras,ra,torso
end
-- 미리보기 무대. 돌려주는 값 : 모델, 매 프레임 부를 함수(dt), 되풀이 간격(초), 되풀이할 때 부를 함수
local function scene(kind,skin,parent)
 local m=Instance.new("Model");m.Name="Skin";m.Parent=parent
 local floor=p(m,"Floor",Vector3.new(0.3,7,7),CFrame.new(0,-3.15,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(86,58,38),Enum.Material.Wood,Enum.PartType.Cylinder)
 floor.Transparency=0.05
 local base=CFrame.new(0,0,1.2)
 local rig,pose,extras,rightArm,torso=dummy(m,base)
 local StabMotion=require(script.Parent.StabMotion)
 if kind=="Stab" then
  -- 앞에 작은 통, 손에는 지금 장착한 칼
  local barrel=p(m,"Barrel",Vector3.new(2.2,2.4,2.4),CFrame.new(0,-1.9,-1.9)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(122,78,44),Enum.Material.Wood,Enum.PartType.Cylinder)
  barrel.Transparency=0
  local knifeSkin=Config.findSkin("Knife",Players.LocalPlayer:GetAttribute(Config.Skins.PlayerAttributes.Knife) or "classic")
  local ok,knife=pcall(require(script.Parent.KnifeModel).build,knifeSkin,m,CFrame.new(),0.8)
  if ok and knife then
   table.insert(extras,{part=knife,to=rightArm,offset=CFrame.new(0,-1.05,0)*CFrame.Angles(math.pi,0,0),model=true})
  end
  local function play()
   local plan=StabMotion.plan(skin.style or "classic",0.32,skin.color)
   StabMotion.playBody(rig,plan)
  end
  return m,function()
   pose()
   for _,e in ipairs(extras) do if e.model and e.part.Parent then e.part:PivotTo(e.to.CFrame*e.offset) end end
  end,2.2,play
 end
 local event=kind=="Victory" and "Win" or "Eliminate"
 local shoulder=rig:FindFirstChild("Right Shoulder",true)
 local rootJoint=rig:FindFirstChild("RootJoint",true)
 local shoulderHome=shoulder and shoulder.C0
 local rootHome=rootJoint and rootJoint.C0
 local TweenService=game:GetService("TweenService")
 local function play()
  local at=(kind=="Victory" and CFrame.new(0,1.2,0.6) or CFrame.new(0,0,1.2)).Position
  pcall(FX.burst,at,skin,event,m)
  if kind=="Victory" and shoulder then
   -- 이긴 사람은 팔을 번쩍 든다 (게임에서와 같은 동작)
   TweenService:Create(shoulder,TweenInfo.new(0.35),{C0=shoulderHome*CFrame.Angles(0,0,math.rad(115))}):Play()
   task.delay(1.6,function() if shoulder.Parent then TweenService:Create(shoulder,TweenInfo.new(0.4),{C0=shoulderHome}):Play() end end)
  elseif rootJoint then
   -- 탈락한 사람은 뒤로 넘어졌다가 일어난다
   TweenService:Create(rootJoint,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{C0=rootHome*CFrame.Angles(math.rad(-70),0,0)}):Play()
   task.delay(1.8,function() if rootJoint.Parent then TweenService:Create(rootJoint,TweenInfo.new(0.5),{C0=rootHome}):Play() end end)
  end
 end
 return m,pose,kind=="Victory" and 4 or 3,play
end
function Preview.close()
 if spin then spin:Disconnect();spin=nil end
 if current then current:Destroy();current=nil end
end
function Preview.show(kind,id)
 Preview.close()
 local skin=Config.findSkin(kind,id);if not skin then return end
 local gui=Instance.new("ScreenGui");gui.Name="SkinPreview";gui.DisplayOrder=40;gui.ResetOnSpawn=false;gui.Parent=Players.LocalPlayer.PlayerGui;current=gui
 -- Phase 14 : 상점과 같은 만화풍 창 (이름 · 등급만, 설명 줄 없음)
 local UIKit=require(script.Parent.UIKit)
 local rarity=Config.rarityOf(skin)
 local themes={common="grey",rare="blue",epic="purple",legend="gold",mythic="red"}
 local w=UIKit.window(gui,{name="Preview",title=skin.name,theme=themes[skin.rarity or "common"] or "blue",size=Vector2.new(640,540),onClose=Preview.close,exclusive=false})
 local frame=w.frame
 local tag=UIKit.label(frame,{text=rarity.label,size=UDim2.new(0,150,0,30),position=UDim2.fromOffset(20,76),textSize=24,color=rarity.color,stroke=3})
 tag.ZIndex=4
 -- Phase 24 : 어디에 쓰는지 한 줄
 local usage=UIKit.label(frame,{text=Preview.Usage[kind] or "",size=UDim2.new(1,-190,0,40),position=UDim2.fromOffset(170,72),textSize=16,color=UIKit.Colors.Cream,stroke=2,wrap=true})
 usage.ZIndex=4
 local viewport=Instance.new("ViewportFrame");viewport.Size=UDim2.new(1,-40,1,-126);viewport.Position=UDim2.fromOffset(20,110);viewport.BackgroundColor3=Color3.fromRGB(34,40,58);viewport.Ambient=Color3.fromRGB(170,180,205);viewport.LightColor=Color3.fromRGB(255,236,200);viewport.LightDirection=Vector3.new(-1,-1,-1);viewport.Parent=frame
 if kind=="Ghost" then viewport.Ambient=Color3.fromRGB(110,116,136);viewport.LightColor=Color3.fromRGB(214,198,176) end -- Phase 17.1 : 해적은 조명을 낮춘다
 UIKit.corner(viewport,14);UIKit.outline(viewport,3.5)
 w.open()
 local world=Instance.new("WorldModel");world.Parent=viewport
 local model,step,every,replay
 if kind=="Stab" or kind=="Victory" or kind=="Elimination" then
  local ok,a,b,c,d=pcall(scene,kind,skin,world)
  if ok then model,step,every,replay=a,b,c,d else warn("[CursedBarrel] 미리보기 무대: "..tostring(a)) end
 end
 if not model then model=Preview.build(kind,skin,world,true) end
 local box,size=model:GetBoundingBox();local focus=box.Position
 local camera=Instance.new("Camera");camera.FieldOfView=40;camera.Parent=viewport;viewport.CurrentCamera=camera
 local radius=math.max(size.X,size.Y,size.Z)*1.8+2
 if step then radius=math.max(size.X,size.Y,size.Z)*1.35+2 end
 local nextReplay=0.4
 local angle=step and math.pi*0.8 or 0;local drag=false -- Phase 24 : 인형은 앞모습부터
 viewport.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true end end)
 viewport.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
 viewport.InputChanged:Connect(function(i) if drag then angle=angle+i.Delta.X*0.008 end end)
 spin=Run.RenderStepped:Connect(function(dt)
  if step then
   pcall(step,dt)
   nextReplay-=dt
   if replay and nextReplay<=0 then nextReplay=every or 3;task.spawn(pcall,replay) end
  end
  if not drag then angle=angle+dt*(step and 0.12 or 0.28) end
  local aspect=math.max(0.4,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
  local distance=radius/math.min(1,aspect)
  camera.CFrame=CFrame.lookAt(focus+Vector3.new(math.sin(angle)*distance,distance*0.18,math.cos(angle)*distance),focus)
 end)
 w.close.Selectable=true;if Input.GamepadEnabled then game:GetService("GuiService").SelectedObject=w.close end
end
return Preview
