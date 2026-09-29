local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local C = require(RS.Shared.Config)
local P = require(RS.Shared.PlanetMath)
local L = require(RS.Shared.Layout)
-- 낙사 삭제 높이는 스크립트 권한으로 수정할 수 없어 빌더에서 -50000으로 저장합니다.
local world = Instance.new("Folder")
world.Name,world.Parent = "PlanetTest",workspace
local function part(name,size,cf,color,parent)
    local p = Instance.new("Part")
    p.Name,p.Size,p.CFrame,p.Color = name,size,cf,color
    p.Anchored = true
    p.TopSurface,p.BottomSurface = Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
    p.Parent = parent or world
    return p
end
local planet = part("Planet",Vector3.new(1,1,1)*C.Radius*2,CFrame.new(P.Center),Color3.fromRGB(74,110,72))
planet.Shape,planet.Material = Enum.PartType.Ball,Enum.Material.Grass
planet.CustomPhysicalProperties = PhysicalProperties.new(1,0.4,0,1,100)
local wood = Color3.fromRGB(103,66,39)
local base = P.frame(Vector3.new(0,1,0),-C.Embed)
local logs = part("Campfire",Vector3.new(4,1,4),base*CFrame.new(0,0.5,0),wood)
local fire = Instance.new("Fire")
fire.Size,fire.Heat,fire.Parent = 5,6,logs
local light = Instance.new("PointLight")
light.Brightness,light.Range,light.Color,light.Shadows = 4,65,Color3.fromRGB(255,170,75),true
light.Parent = logs

local templates = {Tree={},Rock={}}
local env = RS:FindFirstChild("EnvModels")
if env then
    for _,candidate in ipairs(env:GetDescendants()) do
        local kind = if candidate.Name:match("^Spruce") then "Tree" elseif candidate.Name:match("^Boulder") then "Rock" else nil
        if kind and (candidate:IsA("Model") or candidate:IsA("BasePart")) then
            local ancestor,nested = candidate.Parent,false
            while ancestor and ancestor~=env do
                if ancestor.Name:match("^Spruce") or ancestor.Name:match("^Boulder") then nested = true end
                ancestor = ancestor.Parent
            end
            if not nested then table.insert(templates[kind],candidate) end
        end
    end
end
for i,entry in ipairs(L.props()) do
    local list = templates[entry.kind]
    if #list>0 then
        local model = Instance.new("Model")
        model.Name = entry.kind
        local clone = list[(i-1)%#list+1]:Clone()
        clone.Parent = model
        for _,child in ipairs(model:GetDescendants()) do
            if child:IsA("BasePart") then child.Anchored = true end
            if child:IsA("LuaSourceContainer") then child:Destroy() end
        end
        local box,size = model:GetBoundingBox()
        local bottom = box*CFrame.new(0,-size.Y/2,0)
        model:PivotTo(entry.frame*bottom:Inverse()*model:GetPivot())
        model.Parent = world
    elseif entry.kind=="Tree" then
        part("TreeTrunk",Vector3.new(2,10,2),entry.frame*CFrame.new(0,5,0),wood)
        local crown = part("TreeCrown",Vector3.new(8,11,8),entry.frame*CFrame.new(0,12,0),Color3.fromRGB(30,70,44))
        crown.Shape,crown.CanCollide = Enum.PartType.Ball,false
    else
        local rock = part("Rock",Vector3.new(5,3,4),entry.frame*CFrame.new(0,1.5,0),Color3.fromRGB(115,119,125))
        rock.Shape,rock.Material = Enum.PartType.Ball,Enum.Material.Slate
    end
end
-- 기지 옆 기울어진 바위: 벽면에 닿아도 중력 방향이 바뀌지 않는지 시험.
local slopeUp = (Vector3.new(0,1,0)+Vector3.new(18/C.Radius,0,15/C.Radius)).Unit
part("SlopedRock",Vector3.new(8,3,9),P.frame(slopeUp,0.5)*CFrame.Angles(0,0,math.rad(28)),Color3.fromRGB(130,132,140))
for _,entry in ipairs(L.flags()) do
    part("FlagPole",Vector3.new(0.5,6,0.5),entry.frame*CFrame.new(0,3,0),wood)
    local flag = part("Flag",Vector3.new(3,1.5,0.15),entry.frame*CFrame.new(1.5,5.2,0),Color3.fromRGB(252,192,61))
    flag.CanCollide = false
    for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
        local gui = Instance.new("SurfaceGui")
        gui.Face,gui.AlwaysOnTop,gui.Parent = face,false,flag
        local label = Instance.new("TextLabel")
        label.Size,label.BackgroundTransparency = UDim2.fromScale(1,1),1
        label.Text,label.TextScaled,label.TextColor3 = entry.name,true,Color3.new(0,0,0)
        label.Parent = gui
    end
end
local monster = Instance.new("Model")
monster.Name,monster.Parent = "WalkingMonster",world
local root = part("Root",Vector3.new(0.2,0.2,0.2),CFrame.new(),Color3.new(),monster)
root.Transparency,root.CanCollide = 1,false
monster.PrimaryPart = root
local dark = Color3.fromRGB(42,37,53)
part("Body",Vector3.new(3,3,2),CFrame.new(0,3.2,0),dark,monster)
part("Head",Vector3.new(2.5,2,2),CFrame.new(0,5.5,0),dark,monster)
local legs = {}
for _,side in ipairs({-1,1}) do
    table.insert(legs,part("Leg",Vector3.new(0.9,2,1),CFrame.new(side*0.8,1,0),dark,monster))
    local eye = part("Eye",Vector3.new(0.4,0.4,0.15),CFrame.new(side*0.6,5.6,-1.05),Color3.fromRGB(255,80,35),monster)
    eye.Material = Enum.Material.Neon
end
local monsterOffsets = {}
for _,p in ipairs(monster:GetChildren()) do
    p.CanCollide = false
    monsterOffsets[p] = p.CFrame
end
local elapsed = 0
local function animateMonster(dt)
    elapsed += dt
    local cf = P.monster(elapsed)
    -- 매번 원래 로컬 좌표에서 계산해 누적 이동 오차를 만들지 않습니다.
    for p,offset in pairs(monsterOffsets) do p.CFrame = cf*offset end
    for i,leg in ipairs(legs) do
        local side = if i==1 then -1 else 1
        leg.CFrame = cf*CFrame.new(side*0.8,1,0)*CFrame.Angles(math.sin(elapsed*6)*0.3*side,0,0)
    end
end
animateMonster(0)
RunService.Heartbeat:Connect(animateMonster)

local ready = Instance.new("RemoteEvent")
ready.Name,ready.Parent = "PlanetClientReady",RS
local nextSlot,slots = 0,{}
local function setupCharacter(player,character)
    local hrp = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")
    hrp.Anchored = true -- 클라이언트 준비 전에는 추락하지 않습니다.
    local waited = 0
    while not player:HasAppearanceLoaded() and waited<C.AppearanceWaitSeconds do
        if player.Character~=character or not character.Parent then return end
        waited+=task.wait(0.1)
    end
    if player.Character~=character or not character.Parent then return end
    humanoid.AutoRotate,humanoid.EvaluateStateMachine = false,false
    humanoid.WalkSpeed,humanoid.UseJumpPower,humanoid.JumpPower = C.WalkSpeed,true,C.JumpSpeed
    if not humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator",humanoid) end
    local function noCollision(p)
        if p:IsA("BasePart") and p.Name~="PlanetCollider" then p.CanCollide = false end
    end
    for _,p in ipairs(character:GetDescendants()) do noCollision(p) end
    local added = character.DescendantAdded:Connect(noCollision)
    local respawning = false
    -- EvaluateStateMachine=false에서도 Reset/낙사 후 다시 시작할 수 있게 명시적으로 처리.
    local health = humanoid.HealthChanged:Connect(function(value)
        if value>0 or respawning then return end
        respawning = true
        task.delay(Players.RespawnTime,function()
            if player.Parent==Players and player.Character==character then player:LoadCharacterAsync() end
        end)
    end)
    character.Destroying:Once(function() added:Disconnect(); health:Disconnect() end)
    local height = humanoid.HipHeight+hrp.Size.Y/2
    if humanoid.RigType==Enum.HumanoidRigType.R6 then
        height = hrp.Size.Y/2+character:WaitForChild("Left Leg").Size.Y
    end
    local collider = Instance.new("Part")
    collider.Name,collider.Shape,collider.Size = "PlanetCollider",Enum.PartType.Ball,Vector3.new(1,1,1)*C.ColliderRadius*2
    collider.Transparency,collider.Massless,collider.CanCollide = 1,true,true
    collider.CustomPhysicalProperties = PhysicalProperties.new(0.7,0,0,100,100)
    collider.CFrame = hrp.CFrame*CFrame.new(0,-height+C.ColliderRadius,0)
    collider.Parent = character
    local weld = Instance.new("WeldConstraint")
    weld.Part0,weld.Part1,weld.Parent = hrp,collider,collider
    local attach = Instance.new("Attachment")
    attach.Name,attach.Parent = "PlanetAttachment",hrp
    local force = Instance.new("VectorForce")
    force.Name,force.Attachment0 = "PlanetForce",attach
    force.RelativeTo,force.ApplyAtCenterOfMass = Enum.ActuatorRelativeTo.World,true
    force.Parent = hrp
    local align = Instance.new("AlignOrientation")
    align.Name,align.Attachment0,align.Mode = "PlanetOrientation",attach,Enum.OrientationAlignmentMode.OneAttachment
    align.MaxTorque,align.MaxAngularVelocity,align.Responsiveness = 1000000,100,C.OrientationResponse
    align.Parent = hrp
    local opposite = C.OppositeSpawns and slots[player]%2==0
    local up = Vector3.new(0,if opposite then -1 else 1,0)
    up = (up+Vector3.new(0,0,-8/C.Radius)).Unit
    local frame = P.frame(up,height+C.SpawnClearance)
    character:PivotTo(frame*(hrp.CFrame:Inverse()*character:GetPivot()))
    align.CFrame = frame.Rotation
    character:SetAttribute("PlanetPrepared",true)
    print("PlanetTest spawn",player.Name,if opposite then "opposite" else "base")
end
ready.OnServerEvent:Connect(function(player,character)
    if typeof(character)~="Instance" or character~=player.Character or not character:GetAttribute("PlanetPrepared") or character:GetAttribute("PlanetActive") then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.Anchored = false
    hrp:SetNetworkOwner(player)
    character:SetAttribute("PlanetActive",true)
end)
local function addPlayer(player)
    nextSlot+=1; slots[player]=nextSlot
    player.CharacterAdded:Connect(function(character) setupCharacter(player,character) end)
    if player.Character then task.spawn(setupCharacter,player,player.Character) end
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player) slots[player]=nil end)
for _,player in ipairs(Players:GetPlayers()) do addPlayer(player) end
-- 튕겨나감/관통 시 작은 시험판을 리셋으로 복구합니다.
local checkElapsed = 0
RunService.Heartbeat:Connect(function(dt)
    checkElapsed+=dt
    if checkElapsed<1 then return end
    checkElapsed=0
    for _,player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChild("Humanoid")
        if hrp and humanoid and character:GetAttribute("PlanetActive") then
            local radius = (hrp.Position-P.Center).Magnitude
            if radius<C.Radius-8 or radius>C.Radius+C.RespawnDistance then
                warn("PlanetTest recovery: 행성 이탈",player.Name,radius)
                humanoid.Health=0
            end
        end
    end
end)
print("PlanetTest ready; radius",C.Radius,"ideal lap seconds",2*math.pi*C.Radius/C.WalkSpeed)
