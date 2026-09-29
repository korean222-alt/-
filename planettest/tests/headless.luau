-- 기존 wildhold/tests의 API 검사 모의 엔진을 읽기 전용으로 재사용합니다.
-- 충돌 해결, 실제 네트워크와 렌더링은 이 검사에 포함되지 않습니다.
local API=source("mock/api.lua")()
local D=source("mock/mock/datatypes.luau")()
local V,CF=D.Vector3,D.CFrame
local function near(a,b,epsilon) assert(math.abs(a-b)<(epsilon or 1e-5),tostring(a).." ~= "..tostring(b)) end
local function vec(a,b,epsilon) near((a-b).Magnitude,0,epsilon) end
local function scenario(imported)
    local R=source("mock/mock/roblox.luau")(API,D)
    local E=source("mock/mock/env.luau")(R,D,API)
    local game=E.build()
    local workspace=E.workspace
    local RS=game:GetService("ReplicatedStorage")
    local function folder(parent,name)
        local f=parent:FindFirstChild(name)
        if not f then f=E.Instance.new("Folder",parent); f.Name=name end
        return f
    end
    local globals={game=game,workspace=workspace,Instance=E.Instance,Enum=R.Enum,task=R.task,
        typeof=R.typeof,Vector3=V,Vector2=D.Vector2,CFrame=CF,Color3=D.Color3,UDim2=D.UDim2,
        PhysicalProperties=D.PhysicalProperties,RaycastParams=D.RaycastParams,print=print,warn=print,
        os={clock=function() return R.Now end}}
    setmetatable(globals,{__index=getfenv()})
    local scripts={}
    for path,code in pairs(FILES) do
        if not path:match("^mock/") then
            local pieces=string.split(path,"/")
            local parent=if pieces[1]=="shared" then folder(RS,"Shared") else folder(RS,pieces[1])
            for i=2,#pieces-1 do parent=folder(parent,pieces[i]) end
            local inst=E.Instance.new("ModuleScript",parent)
            inst.Name=pieces[#pieces]:gsub("%.lua$",""):gsub("%.server$",""):gsub("%.client$","")
            rawset(inst,"_source",code)
            scripts[path]=inst
        end
    end
    local cache={}
    local function req(inst)
        if cache[inst] then return cache[inst] end
        local fn=assert(loadstring(rawget(inst,"_source"),inst.Name))
        setfenv(fn,setmetatable({script=inst,require=req},{__index=globals}))
        local result=fn()
        cache[inst]=result
        return result
    end
    local C=req(scripts["shared/Config.lua"])
    local P=req(scripts["shared/PlanetMath.lua"])
    local L=req(scripts["shared/Layout.lua"])
    -- 두 번째 시나리오는 원점이 아닌 행성도 검사합니다.
    if imported then
        C.CenterX,C.CenterY,C.CenterZ=31,52,-18
        P.Center=V.new(31,52,-18)
        local env=folder(RS,"EnvModels")
        local nested=E.Instance.new("Model",env); nested.Name="ImportedKit"
        for name,size in pairs({Spruce1=V.new(7,17,8),Boulder1=V.new(5,3,4)}) do
            local mesh=E.Instance.new("MeshPart",nested)
            mesh.Name,mesh.Size,mesh.CFrame=name,size,CF.new(100,size.Y/2,20)
        end
    end
    local function noErrors() assert(#R.Errors==0,table.concat(R.Errors,"\n")) end
    R.task.spawn(function() req(scripts["server/PlanetTest.server.lua"]) end)
    noErrors()
    local world=workspace:FindFirstChild("PlanetTest")
    assert(world and world.Planet.Shape==R.Enum.PartType.Ball)
    near(world.Planet.Size.X,2*C.Radius)
    assert(#E.TerrainOps==0)
    local trees,rocks,flags=0,0,0
    for _,object in ipairs(world:GetDescendants()) do
        if object:IsA("BasePart") and (object.Name=="TreeTrunk" or object.Name=="Rock" or object.Name=="FlagPole" or object.Name=="Spruce1" or object.Name=="Boulder1") then
            local bottom=object.CFrame*V.new(0,-object.Size.Y/2,0)
            near((bottom-P.Center).Magnitude,C.Radius-C.Embed)
            vec(object.CFrame.UpVector,P.up(bottom))
            if object.Name=="TreeTrunk" or object.Name=="Spruce1" then trees+=1
            elseif object.Name=="FlagPole" then flags+=1 else rocks+=1 end
        end
    end
    assert(trees>20 and rocks>5 and flags==#C.FlagDistances+C.RouteFlagCount)
    for _,entry in ipairs(L.flags()) do
        near((entry.frame.Position-P.Center).Magnitude,C.Radius-C.Embed)
    end
    local Y,Z=V.new(0,1,0),V.new(0,0,1)
    local forward,oldUp=Z,Y
    for i=1,3600 do
        local up,tangent=P.arc(Y,Z,i*2*math.pi/3600)
        forward=P.transport(forward,oldUp,up)
        vec(forward,tangent)
        near(forward:Dot(up),0)
        local force=P.gravityForce(P.Center+up*C.Radius,12,196.2)
        vec(force/12-V.new(0,196.2,0),-up*C.Gravity)
        oldUp=up
    end
    vec(oldUp,Y); vec(forward,Z)
    vec(P.rotationBetween(Y,-Y,Z)*Y,-Y)
    vec(P.transport(Z,Y,-Y),Z)
    local period=2*(math.pi*C.Radius*C.MonsterFarFraction-C.MonsterNear)/C.MonsterSpeed
    local before=P.monster(0)
    for i=1,12000 do
        local cf=P.monster(i*period/6000)
        near((cf.Position-P.Center).Magnitude,C.Radius)
        vec(cf.UpVector,P.up(cf.Position))
        near(cf.LookVector:Dot(cf.UpVector),0)
        assert((cf.Position-before.Position).Magnitude<=C.MonsterSpeed*period/6000+1e-5)
        before=cf
    end
    vec(P.monster(period).Position,P.monster(0).Position)
    for i=1,600 do E.Heartbeat:Fire(0.1); noErrors() end
    local monster=world.WalkingMonster
    near((monster.Root.Position-P.Center).Magnitude,C.Radius)
    vec(monster.Root.CFrame.UpVector,P.up(monster.Root.Position))

    -- 실제 서버의 양쪽 스폰·준비 완료·소유권 전달 경로를 실행합니다.
    local characters={}
    for i=1,2 do
        local player=R.newInstance("Player"); player.Parent=E.players; player.Name="Player"..i
        rawset(player,"_custom",{HasAppearanceLoaded=function() return true end})
        local char=E.Instance.new("Model",workspace); char.Name=player.Name
        local hrp=E.Instance.new("Part",char); hrp.Name="HumanoidRootPart"; hrp.Size=V.new(2,2,1); hrp.CFrame=CF.new()
        rawset(hrp,"_custom",{SetNetworkOwner=function(_,owner) assert(owner==player); rawset(hrp,"_owner",owner) end})
        local hum=E.Instance.new("Humanoid",char); hum.Name="Humanoid"; hum.HipHeight=2
        hum.RigType=if i==1 then R.Enum.HumanoidRigType.R15 else R.Enum.HumanoidRigType.R6
        if i==2 then local leg=E.Instance.new("Part",char); leg.Name="Left Leg"; leg.Size=V.new(1,2,1) end
        char.PrimaryPart=hrp
        player.Character=char
        E.players.PlayerAdded:Fire(player)
        noErrors()
        assert(char:GetAttribute("PlanetPrepared") and hrp.Anchored)
        local expected=if i==1 then 1 else -1
        assert(hrp.CFrame.UpVector.Y*expected>0.99)
        RS.PlanetClientReady.OnServerEvent:Fire(player,char)
        noErrors()
        assert(not hrp.Anchored and rawget(hrp,"_owner")==player and char:GetAttribute("PlanetActive"))
        assert(not hum.EvaluateStateMachine and not hum.AutoRotate)
        table.insert(characters,char)
    end
    -- Controller.Step를 실제 실행. 물리 적분 대신 힘·점프·접선 조건을 검사합니다.
    local Controller=req(scripts["client/Modules/GravityController.lua"])
    local char=characters[2]
    local hrp=char.HumanoidRootPart
    rawget(hrp,"_props").AssemblyMass=12
    local custom=rawget(workspace,"_custom")
    local slopeNormal=nil
    custom.Raycast=function(_,origin,dir)
        local up=P.up(origin)
        return {Position=P.Center+up*C.Radius,Normal=slopeNormal or up,Instance=world.Planet,Distance=1}
    end
    local input=V.new()
    local self=setmetatable({Character=char,Root=hrp,Humanoid=char.Humanoid,Collider=char.PlanetCollider,
        Force=hrp.PlanetForce,Align=hrp.PlanetOrientation,Up=P.up(hrp.Position),Forward=Z,
        LastJump=-math.huge,JumpQueued=false,Params={},
        Controls={GetMoveVector=function() return input end},
        Camera={GetForward=function(_,up) return P.tangent(Z,up) end},
        Animation={Update=function() end}},Controller)
    rawset(game:GetService("UserInputService"),"_custom",{GetFocusedTextBox=function() return nil end})
    for _,up in ipairs({Y,-Y,V.new(1,0,0),V.new(-1,0,0),Z,-Z}) do
        hrp.CFrame=P.frame(up,3)
        hrp.AssemblyLinearVelocity=V.new()
        self.Collider.CFrame=P.frame(up,1)
        input=V.new(1,0,-1)
        self:Step(1/60)
        local net=self.Force.Force/12-V.new(0,workspace.Gravity,0)
        near(net:Dot(up),-C.Gravity)
        vec(self.Align.CFrame.UpVector,up)
    end
    input=V.new(); hrp.CFrame=P.frame(-Y,3); self.Collider.CFrame=P.frame(-Y,1)
    hrp.AssemblyLinearVelocity=V.new()
    self.JumpQueued=true; self:Step(1/60)
    vec(hrp.AssemblyLinearVelocity,-Y*C.JumpSpeed)
    -- 벽면과 접촉해도 점프를 허용하거나 그 법선을 중력으로 쓰지 않습니다.
    R.Now+=1; slopeNormal=Z; hrp.AssemblyLinearVelocity=V.new()
    self.JumpQueued=true; self:Step(1/60)
    vec(hrp.AssemblyLinearVelocity,V.new())
    vec(self.Align.CFrame.UpVector,-Y)
    -- 실제 카메라와 Controller 생성/정리 코드. 입력·렌더·애니메이터만 모의 처리.
    local player=E.players:FindFirstChild("Player2")
    local playerScripts=R.newInstance("PlayerScripts"); playerScripts.Name="PlayerScripts"; playerScripts.Parent=player
    local playerModule=E.Instance.new("ModuleScript",playerScripts); playerModule.Name="PlayerModule"
    cache[playerModule]={GetControls=function() return self.Controls end}
    local animate=E.Instance.new("LocalScript",char); animate.Name="Animate"
    local animator=char.Humanoid:FindFirstChildOfClass("Animator")
    rawset(animator,"_custom",{
        GetPlayingAnimationTracks=function() return {} end,
        LoadAnimation=function() return {Play=function() end,Stop=function() end,Destroy=function() end,AdjustSpeed=function() end} end,
    })
    local bindings={}
    local run=game:GetService("RunService")
    rawget(run,"_custom").BindToRenderStep=function(_,name,_,fn) bindings[name]=fn end
    rawget(run,"_custom").UnbindFromRenderStep=function(_,name) bindings[name]=nil end
    local blocked=false
    custom.Spherecast=function() return if blocked then {Distance=3} else nil end
    local controller=Controller.new(player,char)
    assert(bindings.PlanetCamera)
    local camera=workspace.CurrentCamera
    rawget(camera,"_props").ViewportSize=D.Vector2.new(1280,720)
    local lastLook=nil
    for i=1,1800 do
        local up=P.arc(-Y,Z,i*2*math.pi/1800)
        hrp.CFrame=P.frame(up,3)
        bindings.PlanetCamera(1/60)
        assert((camera.CFrame.Position-P.Center).Magnitude>C.Radius)
        assert(camera.CFrame.UpVector:Dot(up)>0.9)
        if lastLook then assert(lastLook:Dot(camera.CFrame.LookVector)>0.999) end
        lastLook=camera.CFrame.LookVector
    end
    blocked=true; bindings.PlanetCamera(1/60)
    near(controller.Camera.ActualDistance,3-C.CameraPadding)
    blocked=false; bindings.PlanetCamera(1/60)
    assert(controller.Camera.ActualDistance>3-C.CameraPadding)
    local uis=game:GetService("UserInputService")
    local touch={Position=V.new(900,200,0)}
    uis.TouchStarted:Fire(touch,false)
    assert(controller.Camera.Touch==touch)
    local oldForward=controller.Camera.Forward
    touch.Position=V.new(980,200,0)
    uis.TouchMoved:Fire(touch)
    assert((oldForward-controller.Camera.Forward).Magnitude>0.1)
    uis.InputEnded:Fire(touch)
    assert(controller.Camera.Touch==nil)
    uis.TouchStarted:Fire({Position=V.new(100,200,0)},false)
    assert(controller.Camera.Touch==nil) -- 왼쪽 이동 영역을 카메라가 가로채지 않음
    controller:Destroy()
    assert(not bindings.PlanetCamera)
    for _,connection in ipairs(controller.Connections) do assert(not connection.Connected) end
    for _,connection in ipairs(controller.Camera.Connections) do assert(not connection.Connected) end
    local reloads=0
    rawget(player,"_custom").LoadCharacterAsync=function() reloads+=1 end
    E.players.RespawnTime=2
    char.Humanoid.HealthChanged:Fire(0)
    char.Humanoid.HealthChanged:Fire(0)
    R.runUntil(R.Now+2.1)
    assert(reloads==1,"Reset must schedule exactly one respawn")
    noErrors()
    print("PASS scenario",if imported then "imported meshes / translated center" else "fallback props",trees,"trees",rocks,"rocks",flags,"flags")
    print("PASS: 3600-step lap/camera transport, 12000 monster samples, server animation, R15/R6 opposite spawns, ownership handshake, gravity/jump/slope force checks")
    print("PASS: actual camera 1800 frames, obstruction return, touch input separation, controller cleanup")
end
scenario(false)
scenario(true)
