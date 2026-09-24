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
function Preview.build(kind,skin,parent)
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
  local t=script.Parent.Parent.Visuals:FindFirstChild("GhostCaptain")
  if t then
   m:Destroy();m=t:Clone();m.Parent=parent;m:PivotTo(CFrame.new())
   local colors={Coat=skin.coat,CollarL=skin.coat,CollarR=skin.coat,Arm=skin.coat,SpectralHead=skin.skin,GhostHand=skin.skin,MistTail=skin.skin,Cuff=skin.skin,HatBrim=skin.hat,HatCrown=skin.hat,Eye=skin.accent,HatBand=skin.accent}
   for _,v in ipairs(m:GetDescendants()) do if v:IsA("BasePart") and colors[v.Name] then v.Color=colors[v.Name] end end
  end
 elseif kind=="Chair" then
  local seat=p(m,"Seat",Vector3.new(2,0.4,2),CFrame.new(0,-1,0),Color3.fromRGB(56,38,32))
  p(m,"Back",Vector3.new(2,2.6,0.3),CFrame.new(0,0.1,0.85),Color3.fromRGB(56,38,32));FX.chair(seat,skin)
  for _,x in ipairs({-0.8,0.8}) do for _,z in ipairs({-0.8,0.8}) do p(m,"Leg",Vector3.new(0.18,1.5,0.18),CFrame.new(x,-1.8,z),Color3.fromRGB(74,48,32)) end end
 else
  p(m,"Spirit",Vector3.new(1.2,2,1.2),CFrame.new(),skin.fx and skin.fx.emit or Color3.fromRGB(238,203,114),Enum.Material.Neon,Enum.PartType.Ball)
 end
 FX.decorate(m,skin,kind)
 if skin.fx and skin.fx.theme=="dragon" then FX.previewDragon(m,skin) end
 return m
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
 local tag=UIKit.label(frame,{text=rarity.label,size=UDim2.new(1,-40,0,30),position=UDim2.fromOffset(20,76),textSize=24,color=rarity.color,stroke=3})
 tag.ZIndex=4
 local viewport=Instance.new("ViewportFrame");viewport.Size=UDim2.new(1,-40,1,-126);viewport.Position=UDim2.fromOffset(20,110);viewport.BackgroundColor3=Color3.fromRGB(34,40,58);viewport.Ambient=Color3.fromRGB(170,180,205);viewport.LightColor=Color3.fromRGB(255,236,200);viewport.LightDirection=Vector3.new(-1,-1,-1);viewport.Parent=frame
 UIKit.corner(viewport,14);UIKit.outline(viewport,3.5)
 w.open()
 local world=Instance.new("WorldModel");world.Parent=viewport
 local model=Preview.build(kind,skin,world)
 local box,size=model:GetBoundingBox();local focus=box.Position
 local camera=Instance.new("Camera");camera.FieldOfView=40;camera.Parent=viewport;viewport.CurrentCamera=camera
 local radius=math.max(size.X,size.Y,size.Z)*1.8+2
 local angle=0;local drag=false
 viewport.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true end end)
 viewport.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
 viewport.InputChanged:Connect(function(i) if drag then angle=angle+i.Delta.X*0.008 end end)
 spin=Run.RenderStepped:Connect(function(dt)
  if not drag then angle=angle+dt*0.28 end
  local aspect=math.max(0.4,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
  local distance=radius/math.min(1,aspect)
  camera.CFrame=CFrame.lookAt(focus+Vector3.new(math.sin(angle)*distance,distance*0.18,math.cos(angle)*distance),focus)
 end)
 w.close.Selectable=true;if Input.GamepadEnabled then game:GetService("GuiService").SelectedObject=w.close end
end
return Preview
