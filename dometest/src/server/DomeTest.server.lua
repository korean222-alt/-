local RS = game:GetService("ReplicatedStorage")
local D = require(RS.Shared.Dome)
local C = D.Config
local terrain = workspace.Terrain
local world = Instance.new("Folder")
world.Name = "DomeTest"
world.Parent = workspace
local function part(name, size, position, color, parent)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Position = name, size, position
    p.Anchored = true
    p.Color = color
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent or world
    return p
end

-- 원형 언덕의 윗껍질만 4 stud 높이 층으로 기록합니다.
local extent = math.ceil((C.PlayRadius + C.ForestWidth)/4)*4
local bottom = math.floor((D.height(C.PlayRadius+C.ForestWidth, 0)-C.SoilDepth)/4)*4
local top = math.ceil((C.TopY+4)/4)*4
local n = extent/2
for y = bottom, top-4, 4 do
    local materials, occupancy = {}, {}
    for ix = 1, n do
        materials[ix], occupancy[ix] = {{}}, {{}}
        for iz = 1, n do
            local x, z = -extent+(ix-0.5)*4, -extent+(iz-0.5)*4
            local value = D.occupancy(x, y+2, z)
            materials[ix][1][iz] = if value > 0 then Enum.Material.Grass else Enum.Material.Air
            occupancy[ix][1][iz] = value
        end
    end
    terrain:WriteVoxels(Region3.new(Vector3.new(-extent,y,-extent), Vector3.new(extent,y+4,extent)), 4, materials, occupancy)
end
-- 실제 Terrain 표면에 맞춰 놓습니다. 수식 높이는 비상 대체값입니다.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = {terrain}
local function ground(x,z)
    local hit = workspace:Raycast(Vector3.new(x, C.TopY+50,z), Vector3.new(0,-(C.SphereRadius+100),0), params)
    return if hit then hit.Position.Y else D.height(x,z)
end
local wood = Color3.fromRGB(100,65,37)
local function standing(name, size, x,z,color)
    return part(name,size,Vector3.new(x,ground(x,z)+size.Y/2-C.Embed,z),color)
end
local fireBase = standing("Campfire",Vector3.new(4,1,4),0,0,wood)
fireBase.Material = Enum.Material.Wood
local fire = Instance.new("Fire")
fire.Size, fire.Heat, fire.Parent = 5,6,fireBase
local light = Instance.new("PointLight")
light.Color,light.Brightness,light.Range = Color3.fromRGB(255,164,75),4,55
light.Shadows,light.Parent = true,fireBase
for i=0,11 do
    local a = i*math.pi/6
    -- 앞뒤로 넓은 출입구를 남깁니다.
    if math.abs(math.cos(a)) > 0.3 then
        standing("FenceStake",Vector3.new(0.8,3,0.8),math.cos(a)*9,math.sin(a)*9,wood)
    end
end
local spawn = Instance.new("SpawnLocation")
spawn.Name,spawn.Size = "SummitSpawn",Vector3.new(5,1,5)
spawn.Position = Vector3.new(0,ground(0,6)-0.4,6)
spawn.Anchored,spawn.Transparency,spawn.CanCollide = true,1,false
spawn.Neutral,spawn.Duration,spawn.Parent = true,0,world
for _, distance in ipairs(C.MarkerDistances) do
    if distance < C.PlayRadius then
        local pole = standing(tostring(distance).." stud",Vector3.new(0.6,7,0.6),0,distance,Color3.fromRGB(240,210,100))
        local flag = part("DistanceFlag",Vector3.new(3,1.5,0.2),pole.Position+Vector3.new(1.5,2.6,0),Color3.fromRGB(255,185,45))
        local label = Instance.new("SurfaceGui")
        label.Face, label.AlwaysOnTop, label.Parent = Enum.NormalId.Back,false,flag
        local text = Instance.new("TextLabel")
        text.Size,text.BackgroundTransparency = UDim2.fromScale(1,1),1
        text.Text,text.TextScaled,text.TextColor3 = tostring(distance),true,Color3.new(0,0,0)
        text.Parent = label
        local back = label:Clone()
        back.Face,back.Parent = Enum.NormalId.Front,flag
    end
end

local templates = {}
local env = RS:FindFirstChild("EnvModels")
if env then
    for _, candidate in ipairs(env:GetDescendants()) do
        if candidate.Name:match("^Spruce") and (candidate:IsA("Model") or candidate:IsA("BasePart")) then
            local ancestor, nested = candidate.Parent,false
            while ancestor and ancestor ~= env do
                if ancestor.Name:match("^Spruce") then nested = true end
                ancestor = ancestor.Parent
            end
            if not nested then table.insert(templates,candidate) end
        end
    end
end
for row=0,1 do
    local radius = C.PlayRadius+row*C.ForestWidth/2
    local count = math.ceil(2*math.pi*radius/C.TreeSpacing)
    for i=1,count do
        local a = (i+row*0.5)*2*math.pi/count
        local x,z = math.cos(a)*radius,math.sin(a)*radius
        if #templates > 0 then
            local model = Instance.new("Model")
            model.Name,model.Parent = "ForestTree",world
            local clone = templates[(i-1)%#templates+1]:Clone()
            clone.Parent = model
            for _, p in ipairs(model:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored = true end
                if p:IsA("LuaSourceContainer") then p:Destroy() end
            end
            local box,size = model:GetBoundingBox()
            local target = Vector3.new(x,ground(x,z)+size.Y/2-C.Embed,z)
            model:PivotTo(model:GetPivot() + (target-box.Position))
        else
            standing("TreeTrunk",Vector3.new(2,11,2),x,z,wood)
            local crown = part("TreeCrown",Vector3.new(9,12,9),Vector3.new(x,ground(x,z)+12,z),Color3.fromRGB(29,69,43))
            crown.Shape,crown.CanCollide = Enum.PartType.Ball,false
        end
    end
end
-- 나무 사이로 빠져나가지 않도록 숲 속에 연속된 투명 경계.
local segments = 96
local boundaryRadius = C.PlayRadius+C.ForestWidth*0.55
for i=1,segments do
    local a = i*2*math.pi/segments
    local x,z = math.cos(a)*boundaryRadius,math.sin(a)*boundaryRadius
    local wall = standing("ForestBoundary",Vector3.new(2*boundaryRadius*math.tan(math.pi/segments)+1,60,2),x,z,wood)
    wall.CFrame = CFrame.new(wall.Position)*CFrame.Angles(0,math.pi/2-a,0)
    wall.Transparency = 1
end

local monster = Instance.new("Model")
monster.Name,monster.Parent = "WalkingMonster",world
local body = part("Body",Vector3.new(3,3,2),Vector3.new(0,3.4,0),Color3.fromRGB(43,38,54),monster)
part("Head",Vector3.new(2.6,2,2.2),Vector3.new(0,5.8,0),body.Color,monster)
local legs = {}
for _, side in ipairs({-1,1}) do
    table.insert(legs,part("Leg",Vector3.new(0.9,2.2,1),Vector3.new(side*0.85,1,0),body.Color,monster))
    local eye = part("Eye",Vector3.new(0.4,0.4,0.15),Vector3.new(side*0.65,6,-1.15),Color3.fromRGB(255,77,40),monster)
    eye.Material = Enum.Material.Neon
end
for _, p in ipairs(monster:GetChildren()) do p.CanCollide = false end
monster.WorldPivot = CFrame.new()
local started = os.clock()
local function move(t)
    local radius = D.monsterRadius(t)
    local outward = D.monsterRadius(t+0.01) > radius
    -- 북쪽 경로. 남쪽 깃발 쪽에서 보면 꼭대기 너머로 출현합니다.
    local root = CFrame.new(0,ground(0,-radius)-0.15,-radius)*CFrame.Angles(0,if outward then 0 else math.pi,0)
    monster:PivotTo(root)
    for i,leg in ipairs(legs) do
        local side = if i==1 then -1 else 1
        leg.CFrame = root*CFrame.new(side*0.85,1,0)*CFrame.Angles(math.sin(t*5)*0.3*side,0,0)
    end
end
move(0)
game:GetService("RunService").Heartbeat:Connect(function() move(os.clock()-started) end)
print("DomeTest ready: 기본 중력 / 기본 캐릭터 / 기본 카메라")
