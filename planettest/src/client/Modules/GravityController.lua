-- Adapted from EgoMoose/Rbx-Gravity-Controller (MIT), Copyright (c) 2020 EgoMoose.
-- Upstream 95e2a79596052bc36b2bf3290d92390b10db7210.
-- See ReplicatedStorage.ThirdPartyNotices and planettest/third_party/EgoMoose-LICENSE.txt.
-- 중력 보정력/접선 속도 분해/구형 충돌체 방식에서 출발한 작은 행성 전용 개정판.
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("ReplicatedStorage")
local shared=RS:WaitForChild("Shared")
local C=require(shared:WaitForChild("Config"))
local P=require(shared:WaitForChild("PlanetMath"))
local PlanetCamera=require(script.Parent:WaitForChild("PlanetCamera"))
local Animation=require(script.Parent:WaitForChild("AvatarAnimation"))
local Controller={}
Controller.__index=Controller
function Controller.new(player,character,isCurrent)
    local self=setmetatable({},Controller)
    self.Character,self.Root,self.Humanoid=character,character:WaitForChild("HumanoidRootPart"),character:WaitForChild("Humanoid")
    self.Collider=character:WaitForChild("PlanetCollider")
    self.Force,self.Align=self.Root:WaitForChild("PlanetForce"),self.Root:WaitForChild("PlanetOrientation")
    self.Controls=require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
    self.Humanoid.AutoRotate,self.Humanoid.EvaluateStateMachine=false,false
    self.Animation=Animation.new(character)
    if isCurrent and not isCurrent() then self.Animation:Destroy(); return nil end
    self.Camera=PlanetCamera.new(character)
    self.Forward=P.tangent(self.Root.CFrame.LookVector,P.up(self.Root.Position))
    self.Up=P.up(self.Root.Position)
    self.LastJump=-math.huge
    self.JumpQueued=false
    self.Params=RaycastParams.new()
    -- 바위/나무에 서기는 가능하지만 법선은 중력에 사용하지 않습니다.
    self.Params.FilterType=Enum.RaycastFilterType.Include
    self.Params.FilterDescendantsInstances={workspace:WaitForChild("PlanetTest")}
    self.Params.RespectCanCollide=true
    self.Connections={}
    local function connect(signal,fn) table.insert(self.Connections,signal:Connect(fn)) end
    connect(UIS.JumpRequest,function()
        if not UIS:GetFocusedTextBox() then self.JumpQueued=true end
    end)
    -- Roblox 기본 휴대폰 점프 버튼은 Humanoid.Jump로 전달합니다.
    connect(self.Humanoid:GetPropertyChangedSignal("Jump"),function()
        if self.Humanoid.Jump then self.JumpQueued=true; self.Humanoid.Jump=false end
    end)
    connect(RunService.PreSimulation,function(dt) self:Step(dt) end)
    RunService:BindToRenderStep("PlanetCamera",Enum.RenderPriority.Camera.Value+1,function(dt) self.Camera:Update(dt) end)
    self:Step(1/60)
    self.Camera:Update(1/60)
    return self
end
function Controller:Step(dt)
    if not self.Root.Parent or self.Humanoid.Health<=0 then return end
    local up=P.up(self.Root.Position)
    self.Forward=P.transport(self.Forward,self.Up,up)
    self.Up=up
    local camForward=self.Camera:GetForward(up)
    local right=camForward:Cross(up)
    local input=self.Controls:GetMoveVector()
    if UIS:GetFocusedTextBox() then input=Vector3.new() end
    local worldMove=right*input.X-camForward*input.Z
    if worldMove.Magnitude>1 then worldMove=worldMove.Unit end
    local velocity=self.Root.AssemblyLinearVelocity
    local radial=velocity:Dot(up)
    local horizontal=velocity-up*radial
    local hit=workspace:Raycast(self.Collider.Position,-up*(C.ColliderRadius+C.GroundProbe),self.Params)
    local grounded=hit~=nil and hit.Normal:Dot(up)>C.GroundNormalMin and radial<4
    local time=os.clock()
    if self.JumpQueued and grounded and time-self.LastJump>C.JumpCooldown then
        self.Root.AssemblyLinearVelocity=horizontal+up*C.JumpSpeed
        self.LastJump=time
        radial=C.JumpSpeed; grounded=false
    end
    self.JumpQueued=false
    if time-self.LastJump<0.15 then grounded=false end
    if worldMove.Magnitude>0.01 then
        local turn=P.rotationBetween(self.Forward,worldMove.Unit,up)
        self.Forward=P.tangent(CFrame.new():Lerp(turn,1-math.exp(-C.TurnResponse*dt))*self.Forward,up)
    end
    -- EgoMoose 방식: 기본 아래 중력을 상쇄하고 중심 방향 중력을 더합니다.
    local mass=self.Root.AssemblyMass
    if mass==math.huge or mass<=0 then return end -- 서버 준비 중 Anchored 상태
    local gravityForce=P.gravityForce(self.Root.Position,mass,workspace.Gravity)
    local deltaVelocity=C.WalkSpeed*worldMove-horizontal
    local acceleration=deltaVelocity*C.MoveResponse*(if grounded then 1 else C.AirControl)
    if acceleration.Magnitude>C.MaxMoveAcceleration then acceleration=acceleration.Unit*C.MaxMoveAcceleration end
    self.Force.Force=gravityForce+mass*acceleration
    self.Align.CFrame=P.frame(up,0,self.Forward).Rotation
    self.Animation:Update(grounded,horizontal.Magnitude,radial)
end
function Controller:Destroy()
    RunService:UnbindFromRenderStep("PlanetCamera")
    for _,connection in ipairs(self.Connections) do connection:Disconnect() end
    self.Camera:Destroy()
    self.Animation:Destroy()
    if self.Force.Parent then self.Force.Force=Vector3.new() end
end
return Controller
