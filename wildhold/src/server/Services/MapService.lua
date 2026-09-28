local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local C = require(RS.Shared.Config.MapConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local Map = {}
function Map:Build()
    -- Only replace objects belonging to this prototype.
    local old = workspace:FindFirstChild("WILDHOLD")
    if old then old:Destroy() end
    self.Root = U.folder(workspace, "WILDHOLD")
    self.Map = U.folder(self.Root, "Map")
    self.LanesFolder = U.folder(self.Map, "Lanes")
    self.SlotsFolder = U.folder(self.Map, "DefenseSlots")
    self.NodesFolder = U.folder(self.Root, "ResourceNodes")
    self.DropsFolder = U.folder(self.Root, "Drops")
    self.DefensesFolder = U.folder(self.Root, "Defenses")
    self.EnemiesFolder = U.folder(self.Root, "Enemies")
    self.FXFolder = U.folder(self.Root, "FX")
    self.PetsFolder = U.folder(self.Root, "Pets")
    self.WildFolder = U.folder(self.Root, "WildPets")
    self.Base = U.folder(self.Root, "Base")
    self.Lanes, self.Slots, self.Nodes = {}, {}, {}
    U.part(self.Map, "Grassland", Vector3.new(C.GroundSize, 2, C.GroundSize), Vector3.new(0, -1, 0), Color3.fromRGB(100, 122, 112))
    self.Core = U.part(self.Base, "Core", Vector3.new(8, 10, 8), Vector3.new(0, 5, 0), Color3.fromRGB(117, 220, 201))
    self.Core.Material = Enum.Material.Neon
    self.CoreLabel = U.label(self.Core, "CORE", 8)
    self.Warehouse = U.part(self.Base, "팀 공용 창고", Vector3.new(6, 4, 6), Vector3.new(table.unpack(C.Warehouse)), Color3.fromRGB(168, 145, 105))
    U.label(self.Warehouse, "공용 창고\n가까이 오면 자동 입금", 5)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name, spawn.Size, spawn.Position = "ExpeditionSpawn", Vector3.new(8, 1, 8), Vector3.new(table.unpack(C.Spawn))
    spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Parent = true, true, 3, self.Base
    self.Spawn = spawn
    self.Cage = U.part(self.Base, "펫 우리", Vector3.new(7,2,7), Vector3.new(16,1,16), Color3.fromRGB(145,210,159))
    U.label(self.Cage, "펫 우리 · 등록 후 밤 생존", 4)
    self.CagePrompt = U.prompt(self.Cage, "Register", "미확정 펫 등록")
    self.Workbench = U.part(self.Base, "제작대", Vector3.new(5,3,4), Vector3.new(-16,1.5,16), Color3.fromRGB(199,167,122))
    U.label(self.Workbench, "덫 · 먹이 · 회복 제작", 4)
    self.CraftPrompt = U.prompt(self.Workbench, "Craft", "제작 열기")
    for i, angle in ipairs(C.LaneAngles) do
        local rad = math.rad(angle)
        local dir = Vector3.new(math.sin(rad), 0, -math.cos(rad))
        local side = Vector3.new(-dir.Z, 0, dir.X)
        local folder = U.folder(self.LanesFolder, "Lane" .. i)
        local lane = {Id = i, Dir = dir, Side = side, Points = {}}
        for n, radius in ipairs(C.WaypointRadii) do
            local pos = dir * radius + Vector3.new(0, 2, 0)
            table.insert(lane.Points, pos)
            local waypoint = U.part(folder, tostring(n), Vector3.new(1, 1, 1), pos)
            waypoint.Transparency, waypoint.CanCollide, waypoint.CanQuery = 1, false, false
        end
        local road = U.part(self.Map, "LaneRoad" .. i, Vector3.new(12, 0.1, C.LaneRadius), dir * (C.LaneRadius / 2) + Vector3.new(0, 0.06, 0), Color3.fromRGB(145, 147, 139))
        road.CFrame = CFrame.lookAt(road.Position, road.Position + dir)
        road.CanCollide = false
        local sign = U.part(folder, "Entry", Vector3.new(1, 1, 1), dir * (C.LaneRadius - 5) + Vector3.new(0, 5, 0))
        sign.Transparency, sign.CanCollide, sign.CanQuery = 1, false, false
        U.label(sign, "진입로 " .. i, 4)
        self.Lanes[i] = lane
        for _, radius in ipairs(C.WallRadii) do self:AddSlot("Wall", i, dir * radius, 0) end
        self:AddSlot("ArrowTower", i, dir * C.TowerRadius + side * 10, i == 1 and 1 or 0)
        self:AddSlot("SpikeTrap", i, dir * C.TrapRadius, 0)
        self:AddSlot("PetStand", i, dir * 21 + side * -10, 0)
    end
    self.Slots[1].InitialLevel, self.Slots[6].InitialLevel = 1, 1
    self:AddSlot("Wall", 1, self.Lanes[1].Dir * 78, 0)
    self:AddSlot("Wall", 2, self.Lanes[2].Dir * 78, 0)
    for i = 1, 2 do self:AddSlot("Gate", i, self.Lanes[i].Dir * 26, 0) end
    self:AddSlot("ArrowTower", 3, self.Lanes[3].Dir * 43 - self.Lanes[3].Side * 10, 0)
    self:AddSlot("SpikeTrap", 3, self.Lanes[3].Dir * 83, 0)
    self:AddSlot("PetStand", 1, Vector3.new(-14, 0, 12), 0)
    for k, kind in ipairs(R.Order) do
        local spec = R.Types[kind]
        for n = 1, C.NodesPerResource do
            local angle = math.rad(k * 67 + n * 6)
            local radius = C.ResourceRadius + (n % 3) * 12
            local pos = Vector3.new(math.cos(angle) * radius, 2.5, math.sin(angle) * radius)
            local p = U.part(self.NodesFolder, kind .. n, Vector3.new(4, 5, 4), pos, U.color(spec.Color))
            p:SetAttribute("ResourceType", kind)
            p:SetAttribute("MaxHealth", spec.HP)
            p:SetAttribute("CurrentHealth", spec.HP)
            p:SetAttribute("RespawnTime", spec.Respawn)
            local label = U.label(p, R.Labels[kind], 4)
            table.insert(self.Nodes, {Part = p, Kind = kind, Label = label})
        end
    end
    return self
end
function Map:AddSlot(kind, laneId, pos, initialLevel)
    local id = string.format("S%02d", #self.Slots + 1)
    local p = U.part(self.SlotsFolder, id, Vector3.new(7, 0.25, 7), pos + Vector3.new(0, 0.2, 0), Color3.fromRGB(157, 171, 169))
    p.CFrame = CFrame.lookAt(p.Position, p.Position + self.Lanes[laneId].Dir)
    p.CanCollide = false
    p:SetAttribute("SlotId", id)
    p:SetAttribute("SlotType", kind)
    p:SetAttribute("LaneId", laneId)
    table.insert(self.Slots, {Id = id, Kind = kind, LaneId = laneId, Pad = p, InitialLevel = initialLevel})
    if kind == "PetStand" then U.label(p, "펫 배치대 · E로 배치", 2) end
end
return Map
