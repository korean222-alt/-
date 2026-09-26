-- Original procedural silhouettes. No external meshes or scripts.
-- All moving bursts are client-side, share one scheduler and have a hard lifetime/budget.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local Config=require(script.Parent.ReleaseConfig)
local FX={}
local jobs={}
local connection=nil
local function part(parent,name,size,cf,color,material,shape)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
 p.Material=material or Enum.Material.Neon;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 if shape then p.Shape=shape end;p.Parent=parent;return p
end
local function rod(parent,a,b,width,color,name)
 local d=(b-a).Magnitude
 return part(parent,name or "LightStroke",Vector3.new(width,width,math.max(d,0.02)),CFrame.lookAt((a+b)*0.5,b),color)
end
local function sphere(parent,name,size,cf,color)
 return part(parent,name,Vector3.new(size,size,size),cf,color,Enum.Material.Neon,Enum.PartType.Ball)
end
local function themeColors(skin)
 local f=skin and skin.fx or {}
 return f.emit or Color3.fromRGB(80,235,212),f.accent or f.halo or Color3.fromRGB(255,218,142),f.theme or "solar"
end
function FX.quality()
 local p=Players.LocalPlayer
 if not p then return "High" end
 if p:GetAttribute("Setting_reducedFX")==true then return "Low" end
 local q=p:GetAttribute("Setting_quality")
 if q=="Low" or q=="High" then return q end
 return game:GetService("UserInputService").TouchEnabled and "Low" or "High"
end
-- A recognisable eastern sea dragon: tapered serpentine spine, horns, jaw,
-- contrasting dorsal scales, luminous eyes, fangs and trailing whiskers.
function FX.dragon(parent,color,accent,segments)
 local model=Instance.new("Model");model.Name="SeaDragon";model.Parent=parent
 local bones={};segments=segments or 18
 for i=1,segments do
  local radius=0.12+0.46*(1-i/(segments+2))
  local node=Instance.new("Model");node.Name="Spine"..i;node.Parent=model
  local body=sphere(node,"ScaleBody",radius*2,CFrame.new(),color);body.Transparency=0.16
  node.PrimaryPart=body
  if i%2==0 then
   local fin=part(node,"GoldSpine",Vector3.new(radius*0.22,radius*1.25,radius*1.2),CFrame.new(0,radius*0.95,0)*CFrame.Angles(0,0,0.25),accent,Enum.Material.Metal)
   fin.Shape=Enum.PartType.Block
  end
  bones[i]=node
 end
 local head=Instance.new("Model");head.Name="DragonHead";head.Parent=model
 local skull=part(head,"Skull",Vector3.new(1.15,0.75,1.5),CFrame.new(),color,Enum.Material.SmoothPlastic,Enum.PartType.Ball);head.PrimaryPart=skull
 part(head,"LongMuzzle",Vector3.new(0.82,0.38,0.95),CFrame.new(0,-0.12,-0.92),color,Enum.Material.SmoothPlastic,Enum.PartType.Ball)
 part(head,"LowerJaw",Vector3.new(0.78,0.17,0.85),CFrame.new(0,-0.44,-0.82)*CFrame.Angles(-0.18,0,0),accent,Enum.Material.Metal)
 for _,side in ipairs({-1,1}) do
  sphere(head,"Eye",0.18,CFrame.new(side*0.48,0.17,-0.45),accent)
  rod(head,Vector3.new(side*0.4,0.25,0.28),Vector3.new(side*0.83,1.04,0.7),0.17,accent,"Antler")
  rod(head,Vector3.new(side*0.67,0.76,0.54),Vector3.new(side*1.02,0.9,0.2),0.1,accent,"AntlerBranch")
  rod(head,Vector3.new(side*0.33,-0.14,-1.12),Vector3.new(side*0.35,-0.46,-1.1),0.09,accent,"Fang")
  local a=Vector3.new(side*0.38,-0.18,-1.13)
  for j=1,4 do
   local b=Vector3.new(side*(0.38+j*0.3),-0.18+math.sin(j*0.9)*0.25,-1.13+j*0.25)
   rod(head,a,b,0.055,accent,"Whisker");a=b
  end
 end
 return {model=model,bones=bones,head=head}
end
local function poseDragon(dragon,base,time,phase,radius,rise)
 local function point(t)
  local angle=t*1.8+phase
  return base:PointToWorldSpace(Vector3.new(math.cos(angle)*radius,rise+math.sin(t*2.2+phase)*0.5,math.sin(angle)*radius))
 end
 local h=point(time);dragon.head:PivotTo(CFrame.lookAt(h,point(time+0.09)))
 for i,bone in ipairs(dragon.bones) do
  local t=time-i*0.11
  bone:PivotTo(CFrame.lookAt(point(t),point(t+0.06)))
 end
end
-- Phase 24 : 우승 · 탈락 대형 연출에서 용이 나선을 그리며 하늘로 솟는다 (dive 면 위에서 내리꽂는다)
local function poseAscend(dragon,origin,time,life,phase,height,dive)
 local function point(t)
  local r=math.clamp(t/life,0,1)
  local y=dive and height*(1-r) or height*r^1.15
  local radius=dive and (1.2+2.6*(1-r)) or (3.4-2.1*r)
  local angle=t*3.2+phase
  return origin+Vector3.new(math.cos(angle)*radius,y+0.8,math.sin(angle)*radius)
 end
 dragon.head:PivotTo(CFrame.lookAt(point(time),point(time+0.05)))
 for i,bone in ipairs(dragon.bones) do
  local t=time-i*0.06
  bone:PivotTo(CFrame.lookAt(point(t),point(t+0.04)))
 end
end
function FX.previewDragon(parent,skin)
 local color,accent=themeColors(skin)
 local d=FX.dragon(parent,color,accent,16)
 poseDragon(d,CFrame.new(),0,0,2.5,1)
 return d
end
local function ring(parent,center,radius,color,n)
 local list={}
 for i=1,n do
  local a=(i-1)*math.pi*2/n;local b=i*math.pi*2/n
  local p=rod(parent,center+Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius),center+Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius),0.075,color,"RuneArc")
  list[#list+1]=p
 end
 return list
end
function FX.decorate(model,skin,kind)
 if not model or not skin or not skin.fx or not skin.fx.theme then return end
 local previous=model:FindFirstChild("SkinFX_Sculpture");if previous then previous:Destroy() end
 local root=model:IsA("BasePart") and model or model:FindFirstChild(kind=="Knife" and "Blade" or "Body",true) or model:FindFirstChildWhichIsA("BasePart",true)
 if not root then return end
 local folder=Instance.new("Model");folder.Name="SkinFX_Sculpture";folder.Parent=model
 local c,a,theme=themeColors(skin)
 -- Phase 17 : Blender 칼(용 발톱 코등이) · 통(용의 발톱 · 사슬 · 부적) · 해적(용뿔)이 있으면 부품 장식은 두지 않는다
 local meshed=model:GetAttribute("MeshFrame")~=nil or model:GetAttribute("Meshed")==true
 if meshed then return end
 if kind=="Knife" then
  -- Profile-independent decorative guard: preserves blade collision and slot position.
  for _,side in ipairs({-1,1}) do
   local cf=root.CFrame*CFrame.new(side*0.25,0,-0.25)
   local p=part(folder,"FangGuard",Vector3.new(0.1,0.22,0.65),cf*CFrame.Angles(0,side*0.5,side*0.5),a,Enum.Material.Metal)
   p.Transparency=0.08
  end
 elseif kind=="Barrel" then
  local pos=root.Position
  ring(folder,pos+Vector3.new(0,1.7,0),1.9,a,12)
  for i=1,6 do
   local angle=i*math.pi/3
   local cf=CFrame.new(pos+Vector3.new(math.cos(angle)*2,2.15,math.sin(angle)*2))*CFrame.Angles(0,-angle,math.pi/4)
   part(folder,"FloatingSeal",Vector3.new(0.22,0.5,0.12),cf,c)
  end
 elseif kind=="Ghost" then
  for _,side in ipairs({-1,1}) do
   part(folder,"SpiritAntler",Vector3.new(0.15,1.1,0.18),root.CFrame*CFrame.new(side*0.65,1.1,0)*CFrame.Angles(0,0,-side*0.45),a)
  end
 end
 -- Weld decoration if the target moves with a character.
 if not root.Anchored then
  for _,p in ipairs(folder:GetDescendants()) do
   if p:IsA("BasePart") then p.Anchored=false;p.Massless=true;local w=Instance.new("WeldConstraint");w.Part0=root;w.Part1=p;w.Parent=p end
  end
 end
end
local function schedule(job)
 jobs[#jobs+1]=job
 if connection then return end
 connection=Run.RenderStepped:Connect(function(dt)
  for i=#jobs,1,-1 do
   local j=jobs[i];j.elapsed=j.elapsed+dt
   if not j.root.Parent or j.elapsed>=j.life then j.root:Destroy();table.remove(jobs,i)
   else
    local ok=pcall(j.update,j.elapsed,dt)
    if not ok then j.root:Destroy();table.remove(jobs,i) end
   end
  end
  if #jobs==0 then connection:Disconnect();connection=nil end
 end)
end
function FX.burst(position,skin,event,parent)
 if not Run:IsClient() then return end
 local camera=workspace.CurrentCamera
 if not parent and camera and (camera.CFrame.Position-position).Magnitude>Config.FX.MaxDistance then return end
 if #jobs>=Config.FX.MaxBursts then return end
 local color,accent,theme=themeColors(skin)
 local quality=FX.quality();local low=quality=="Low"
 local reduced=Players.LocalPlayer:GetAttribute("Setting_reducedFX")==true
 local root=Instance.new("Model");root.Name="PremiumBurst_"..theme;root.Parent=parent or workspace
 local anchor=part(root,"Emitter",Vector3.new(0.1,0.1,0.1),CFrame.new(position),color);anchor.Transparency=1
 local emitter=Instance.new("ParticleEmitter");emitter.Texture="rbxasset://textures/particles/sparkles_main.dds";emitter.Rate=0
 emitter.Color=ColorSequence.new(color,accent);emitter.Lifetime=NumberRange.new(0.45,0.9);emitter.Speed=NumberRange.new(3,9);emitter.Drag=4
 emitter.SpreadAngle=Vector2.new(180,180);emitter.LightEmission=0.7;emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(1,0)})
 emitter.Parent=anchor;emitter:Emit(reduced and 4 or (low and 12 or 32))
 local rings=ring(root,position+Vector3.new(0,0.2,0),1.5,accent,low and 12 or 24)
 local dragons={};local shards={}
 local life=event=="Win" and 3.6 or (event=="Pick" and 1.25 or 2.2)
 if reduced then life=0.8 end
 -- Phase 24 : 우승 · 탈락 스킨(기본 제외)의 대형 연출
 --   하늘로 뻗는 빛기둥 + 바닥 충격파 + 나선을 그리며 솟는 용 (쌍룡은 두 마리, 탈락의 용은 위에서 내리꽂힌다)
 local grand=(event=="Win" or event=="Eliminate") and skin~=nil and skin.fx~=nil and skin.fx.theme~=nil and not reduced
 local height=parent and 9 or (event=="Win" and 34 or 16) -- 상점 미리보기 창 안에서는 낮게
 local ascending={}
 local pillar,shock
 if grand then
  life=event=="Win" and 4.6 or 3.2
  pillar=part(root,"SkyPillar",Vector3.new(0.2,1.6,1.6),CFrame.new(position)*CFrame.Angles(0,0,math.pi/2),color,Enum.Material.Neon,Enum.PartType.Cylinder);pillar.Transparency=0.35
  shock=part(root,"ShockRing",Vector3.new(0.12,2,2),CFrame.new(position)*CFrame.Angles(0,0,math.pi/2),accent,Enum.Material.Neon,Enum.PartType.Cylinder);shock.Transparency=0.2
  if event=="Win" or theme=="dragon" then
   local n=(event=="Win" and theme=="dragon" and not low) and 2 or 1
   for i=1,n do
    ascending[i]=FX.dragon(root,i==1 and color or accent,i==1 and accent or color,low and Config.FX.LowSegments or Config.FX.HighSegments)
   end
  end
 end
 if theme=="dragon" and not reduced and not grand then
  for i=1,((event=="Win" and not low) and 2 or 1) do dragons[i]=FX.dragon(root,color,accent,low and Config.FX.LowSegments or Config.FX.HighSegments) end
 else
  local n=low and 8 or 16
  for i=1,n do
   local shard=part(root,theme=="phoenix" and "Feather" or "Rune",Vector3.new(0.12,0.55,1.3),CFrame.new(position),i%2==0 and color or accent)
   shards[i]=shard
  end
 end
 local all={};for _,p in ipairs(root:GetDescendants()) do if p:IsA("BasePart") then all[#all+1]={p=p,t=p.Transparency} end end
 local initial={};for _,p in ipairs(rings) do initial[p]=CFrame.new(position):ToObjectSpace(p.CFrame) end
 schedule({root=root,life=life,elapsed=0,update=function(t)
  local ratio=t/life;local expand=1+ratio*2
  for p,cf in pairs(initial) do
   p.CFrame=CFrame.new(position)*CFrame.Angles(0,t*0.6,0)*CFrame.new(cf.Position*expand)*cf.Rotation
  end
  for i,d in ipairs(dragons) do
   local rise=1.5+(event=="Win" and ratio*6 or math.sin(ratio*math.pi)*2)
   poseDragon(d,CFrame.new(position),t*1.6,(i-1)*math.pi,2.5+math.sin(ratio*math.pi)*1.5,rise)
  end
  if pillar then
   local h=math.max(0.2,height*math.clamp(ratio*2.2,0,1))
   local w=1.6*(1-ratio*0.6)
   pillar.Size=Vector3.new(h,w,w)
   pillar.CFrame=CFrame.new(position+Vector3.new(0,h*0.5,0))*CFrame.Angles(0,0,math.pi/2)
   local s=2+ratio*(parent and 6 or 16)
   shock.Size=Vector3.new(0.12,s,s)
  end
  for i,d in ipairs(ascending) do
   poseAscend(d,position,t,life,(i-1)*math.pi,height,event=="Eliminate")
  end
  for i,p in ipairs(shards) do
   local angle=i/#shards*math.pi*2+t
   local radius=1.5+ratio*3
   local y=math.sin(ratio*math.pi)*2
   if theme=="phoenix" then y=math.abs(math.sin(angle))*3+ratio*2 end
   if theme=="kraken" then y=math.sin(i+t*5)*1.4+1 end
   p.CFrame=CFrame.new(position+Vector3.new(math.cos(angle)*radius,y,math.sin(angle)*radius))*CFrame.Angles(ratio*2,angle,t*1.4)
  end
  local fade=math.clamp((ratio-0.65)/0.35,0,1)
  for _,v in ipairs(all) do v.p.Transparency=v.t+(1-v.t)*fade end
 end})
 return root
end
function FX.chair(seat,skin)
 local old=seat:FindFirstChild("CosmeticChair");if old then old:Destroy() end
 if not skin or skin.id=="classic" then return end
 local model=Instance.new("Model");model.Name="CosmeticChair";model.Parent=seat
 local c,a=themeColors(skin)
 local frame=seat.CFrame
 for _,side in ipairs({-1,1}) do
  local p=part(model,"ThroneFin",Vector3.new(0.22,3.5,0.28),frame*CFrame.new(side*1.1,1.1,0.6)*CFrame.Angles(0,0,-side*0.15),a,Enum.Material.Metal)
  sphere(model,"DragonEye",0.28,frame*CFrame.new(side*1.1,2.8,0.6),c)
 end
 part(model,"RoyalBack",Vector3.new(1.8,2.8,0.16),frame*CFrame.new(0,1.7,0.85),c,Enum.Material.Metal).Transparency=0.25
end
function FX.stop()
 for _,job in ipairs(jobs) do job.root:Destroy() end;table.clear(jobs)
 if connection then connection:Disconnect();connection=nil end
end
return FX
