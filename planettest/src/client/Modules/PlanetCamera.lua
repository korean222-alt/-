local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local P = require(RS.Shared.PlanetMath)
local Camera = {}
Camera.__index = Camera
function Camera.new(character)
    local self = setmetatable({},Camera)
    self.Root = character:WaitForChild("HumanoidRootPart")
    self.Up = P.up(self.Root.Position)
    self.Forward = P.tangent(self.Root.CFrame.LookVector,self.Up)
    self.Pitch,self.Distance = math.rad(C.CameraPitch),C.CameraDistance
    self.ActualDistance = self.Distance
    self.Connections,self.Drag,self.Touch,self.Stick = {},false,nil,Vector2.new()
    self.Params = RaycastParams.new()
    self.Params.FilterType = Enum.RaycastFilterType.Exclude
    self.Params.FilterDescendantsInstances = {character}
    self.Params.RespectCanCollide = true
    local function connect(signal,fn) table.insert(self.Connections,signal:Connect(fn)) end
    connect(UIS.InputBegan,function(input,processed)
        if not processed and input.UserInputType==Enum.UserInputType.MouseButton2 then
            self.Drag=true
            UIS.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition
        end
    end)
    connect(UIS.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton2 then
            self.Drag=false; UIS.MouseBehavior=Enum.MouseBehavior.Default
        end
        if input==self.Touch then self.Touch=nil end
    end)
    connect(UIS.WindowFocusReleased,function()
        self.Drag,self.Touch=false,nil
        self.Stick=Vector2.new()
        UIS.MouseBehavior=Enum.MouseBehavior.Default
    end)
    connect(UIS.InputChanged,function(input,processed)
        if input.UserInputType==Enum.UserInputType.MouseMovement and self.Drag then
            self:Rotate(input.Delta.X,input.Delta.Y)
        elseif input.UserInputType==Enum.UserInputType.MouseWheel and not processed then
            self.Distance=math.clamp(self.Distance-input.Position.Z*C.CameraZoomStep,C.CameraMinDistance,C.CameraMaxDistance)
        elseif input.KeyCode==Enum.KeyCode.Thumbstick2 then
            self.Stick=Vector2.new(input.Position.X,-input.Position.Y)
        end
    end)
    connect(UIS.TouchStarted,function(input,processed)
        local camera = workspace.CurrentCamera
        if not processed and not self.Touch and input.Position.X>camera.ViewportSize.X*0.45 then
            self.Touch=input; self.LastTouch=input.Position
        end
    end)
    connect(UIS.TouchMoved,function(input)
        if input==self.Touch then
            local delta=input.Position-self.LastTouch
            self.LastTouch=input.Position
            self:Rotate(delta.X,delta.Y)
        end
    end)
    return self
end
function Camera:Rotate(dx,dy)
    self.Forward=CFrame.fromAxisAngle(self.Up,-dx*C.CameraSensitivity)*self.Forward
    self.Pitch=math.clamp(self.Pitch+dy*C.CameraSensitivity,math.rad(C.CameraMinPitch),math.rad(C.CameraMaxPitch))
end
function Camera:GetForward(up)
    return P.transport(self.Forward,self.Up,up)
end
function Camera:Update(dt)
    local up=P.up(self.Root.Position)
    self.Forward=self:GetForward(up)
    self.Up=up
    if self.Stick.Magnitude>0.15 then
        self:Rotate(self.Stick.X*dt*C.GamepadCameraSpeed/C.CameraSensitivity,self.Stick.Y*dt*C.GamepadCameraSpeed/C.CameraSensitivity)
    end
    local camera=workspace.CurrentCamera
    camera.CameraType=Enum.CameraType.Scriptable
    local focus=self.Root.Position+up*C.CameraFocusHeight
    local offset=-self.Forward*math.cos(self.Pitch)+up*math.sin(self.Pitch)
    local desired=offset*self.Distance
    local hit=workspace:Spherecast(focus,C.CameraCollisionRadius,desired,self.Params)
    local allowed=if hit then math.max(0.5,hit.Distance-C.CameraPadding) else self.Distance
    -- 막힐 때는 즉시 당기고, 다시 멀어질 때만 부드럽게 합니다.
    if allowed<self.ActualDistance then self.ActualDistance=allowed
    else self.ActualDistance+=(allowed-self.ActualDistance)*(1-math.exp(-C.CameraReturnResponse*dt)) end
    local position=focus+offset*self.ActualDistance
    local delta=position-P.Center
    if delta.Magnitude<C.Radius+C.CameraPadding then
        position=P.Center+delta.Unit*(C.Radius+C.CameraPadding)
    end
    camera.CFrame=CFrame.lookAt(position,focus,up)
    camera.Focus=CFrame.new(focus)
end
function Camera:Destroy()
    for _,connection in ipairs(self.Connections) do connection:Disconnect() end
    UIS.MouseBehavior=Enum.MouseBehavior.Default
    if workspace.CurrentCamera then workspace.CurrentCamera.CameraType=Enum.CameraType.Custom end
end
return Camera
