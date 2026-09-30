local Players = game:GetService("Players")
local Pathfinding = game:GetService("PathfindingService")
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local C = require(RS.Shared.Config.GameConfig)
local E = require(RS.Shared.Config.EnemyConfig)
local W = require(RS.Shared.Config.WaveConfig)
local P = require(RS.Shared.Config.PetConfig)
local S = {}
function S:Init(ctx) self.ctx, self.Units, self.NextId, self.PathJobs = ctx, {}, 0, 0 end
function S:Reset()
    for _, unit in pairs(self.Units) do unit.Dead = true end
    self.Units = {}
    self.ctx.Map.EnemiesFolder:ClearAllChildren()
end
function S:Count() local n = 0; for _ in pairs(self.Units) do n = n + 1 end; return n end
function S:Spawn(kind, laneId, night, boss)
    if self:Count() >= C.EnemyLimit then return false end
    self.NextId = self.NextId + 1
    local spec, lane = E[kind], self.ctx.Map.Lanes[laneId]
    -- 서버는 보이지 않는 기준 파트만 움직인다. 괴물 모양과 애니메이션은 클라이언트가 그린다.
    local p = U.part(self.ctx.Map.EnemiesFolder, kind .. self.NextId, Vector3.new(spec.Size, spec.Size, spec.Size), lane.Points[1], U.color(spec.Color))
    p.CanCollide, p.CanTouch, p.Transparency = false, false, 1
    local unit = {Id = self.NextId, Kind = kind, Part = p, Spec = spec, LaneId = laneId,
        HP = math.floor(spec.HP * (1 + (night - 1) * W.HealthPerNight) * (self.ctx.Waves.HealthScale or 1)),
        Damage = spec.Damage * (1 + (night - 1) * W.DamagePerNight),
        Waypoint = 2, NextAttack = 0, NextPath = 0, Boss = boss, Dead = false}
    unit.MaxHP = unit.HP
    p.Position = Vector3.new(p.Position.X, spec.Size / 2 + 0.2, p.Position.Z)
    p:SetAttribute("EnemyId", unit.Id)
    p:SetAttribute("Kind", kind)
    p:SetAttribute("Boss", boss == true)
    p:SetAttribute("CurrentHealth", unit.HP)
    p:SetAttribute("MaxHealth", unit.MaxHP)
    self.Units[unit.Id] = unit
    return true
end
function S:Damage(unit, amount)
    if unit.Dead or self.ctx.Clock.Phase ~= "Night" then return end
    unit.HP = math.max(0, unit.HP - amount)
    unit.Part:SetAttribute("CurrentHealth", unit.HP)
    unit.Part:SetAttribute("HitAt", workspace:GetServerTimeNow())
    if unit.HP <= 0 then
        self.ctx.FX:FireAllClients("EnemyDie", unit.Part.Position, unit.Kind)
        unit.Dead = true
        self.Units[unit.Id] = nil
        local position = unit.Part.Position
        unit.Part:Destroy()
        self.ctx.Resources:Drop("Scrap", unit.Spec.ScrapDrop, position)
        if self.ctx.Pets then
            for player in pairs(self.ctx.Run.Participants) do
                if U.near(player, position, 90) then self.ctx.Pets:Award(player, P.KillXP) end
            end
        end
        if unit.Boss then self.ctx.Waves.BossDefeated = true end
    end
end
function S:ClearShot(origin, destination, ignored)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    -- Only actual defense obstacles block combat rays; characters and FX never do.
    params.FilterDescendantsInstances = self.ctx.Defenses:Obstacles(ignored)
    return workspace:Raycast(origin, destination - origin, params) == nil
end
function S:Nearest(position, range, lineOfSight, ignored)
    local best, distance = nil, range
    for _, unit in pairs(self.Units) do
        local d = (unit.Part.Position - position).Magnitude
        if d < distance and (not lineOfSight or self:ClearShot(position, unit.Part.Position, ignored)) then best, distance = unit, d end
    end
    return best
end
function S:Move(unit, goal, dt)
    local pos = unit.Part.Position
    local delta = U.flat(goal - pos)
    if delta.Magnitude < 0.05 then return end
    local nextPos = pos + delta.Unit * math.min(delta.Magnitude, unit.Spec.Speed * dt)
    unit.Part.CFrame = CFrame.lookAt(nextPos, nextPos + delta.Unit)
    unit.Part:SetAttribute("State", "MoveToTarget")
end
function S:RequestPath(unit, goal)
    if unit.PathPending or os.clock() < unit.NextPath or self.PathJobs >= C.PathJobsLimit then return end
    unit.NextPath, unit.PathPending = os.clock() + C.PathInterval, true
    self.PathJobs = self.PathJobs + 1
    local from = unit.Part.Position
    task.spawn(function()
        local path = Pathfinding:CreatePath({AgentRadius = 2, AgentHeight = 4, AgentCanJump = false, WaypointSpacing = 4})
        local ok = pcall(function() path:ComputeAsync(from, goal) end)
        self.PathJobs = self.PathJobs - 1
        unit.PathPending = false
        if not unit.Dead then
            unit.Path = ok and path.Status == Enum.PathStatus.Success and path:GetWaypoints() or nil
            unit.PathIndex = 2
        end
        path:Destroy()
    end)
end
function S:RunnerTarget(unit)
    if (U.flat(unit.Part.Position - self.ctx.Map.Lanes[unit.LaneId].Dir * U.flat(unit.Part.Position):Dot(self.ctx.Map.Lanes[unit.LaneId].Dir))).Magnitude > C.RunnerLeash then return nil end
    local best, distance = nil, unit.Spec.Aggro
    for _, player in ipairs(Players:GetPlayers()) do
        local root, humanoid = U.aliveRoot(player)
        if root and self.ctx.Run:IsParticipant(player) and not player.Character:FindFirstChildOfClass("ForceField") then
            local d = (root.Position - unit.Part.Position).Magnitude
            if d < distance then best, distance = {Root = root, Humanoid = humanoid}, d end
        end
    end
    return best
end
function S:TryAttack(unit, position, radius, fn)
    if U.flat(unit.Part.Position - position).Magnitude > radius then return false end
    unit.Part:SetAttribute("State", "Attack")
    local here = unit.Part.Position
    local look = Vector3.new(position.X, here.Y, position.Z)
    if (look - here).Magnitude > 0.1 then unit.Part.CFrame = CFrame.lookAt(here, look) end
    if os.clock() >= unit.NextAttack then
        unit.NextAttack = os.clock() + unit.Spec.Interval
        unit.Part:SetAttribute("AttackAt", workspace:GetServerTimeNow())
        local multiplier = 1
        for _, other in pairs(self.Units) do
            if other.Kind == "Howler" and other ~= unit and (other.Part.Position - unit.Part.Position).Magnitude <= other.Spec.AuraRange then multiplier = other.Spec.AuraMultiplier; break end
        end
        fn(math.ceil(unit.Damage * multiplier))
    end
    return true
end
function S:Tick(dt)
    if C.ActiveStage < 4 or self.ctx.Clock.Phase ~= "Night" then return end
    for _, unit in pairs(self.Units) do
        if self.ctx.Clock.Phase ~= "Night" then break end
        self:UpdateUnit(unit, dt)
    end
end
function S:UpdateUnit(unit, dt)
    local pet = self.ctx.Pets and self.ctx.Pets:Nearest(unit.Part.Position, unit.Kind == "Runner" and unit.Spec.Aggro or 6)
    -- Tank taunts force nearby lane enemies to engage it when in line of sight.
    if self.ctx.Pets then
        for _,candidate in pairs(self.ctx.Pets.Active) do
            if candidate.Data.SpeciesId == "Shellbub" and candidate.HP > 0 and (candidate.Part.Position-unit.Part.Position).Magnitude<18 then pet=candidate;break end
        end
    end
    if pet and self:ClearShot(unit.Part.Position,pet.Part.Position) then
        if not self:TryAttack(unit,pet.Part.Position,unit.Spec.Range+2,function(d) self.ctx.Pets:Damage(pet,d) end) then self:Move(unit,pet.Part.Position,dt) end
        return
    end
    local target = unit.Kind == "Runner" and self:RunnerTarget(unit) or nil
    if target then
        local clear = self:ClearShot(unit.Part.Position, target.Root.Position)
        if clear then
            unit.Path = nil
            if not self:TryAttack(unit, target.Root.Position, unit.Spec.Range, function(d)
                if (target.Root.Position - unit.Part.Position).Magnitude <= unit.Spec.Range then target.Humanoid:TakeDamage(d) end
            end) then self:Move(unit, target.Root.Position, dt) end
            return
        end
        self:RequestPath(unit, target.Root.Position)
        local waypoint = unit.Path and unit.Path[unit.PathIndex]
        if waypoint then
            if U.flat(waypoint.Position - unit.Part.Position).Magnitude < 2 then unit.PathIndex = unit.PathIndex + 1 end
            if self:ClearShot(unit.Part.Position, Vector3.new(waypoint.Position.X, unit.Part.Position.Y, waypoint.Position.Z)) then self:Move(unit, waypoint.Position, dt); return end
        end
        -- Failed/pending path falls back to attacking the lane barrier, never stalls.
    end
    local lane = self.ctx.Map.Lanes[unit.LaneId]
    -- A destroyed wall may leave us past a waypoint. Never backtrack outward.
    local radius = U.flat(unit.Part.Position):Dot(lane.Dir)
    while unit.Waypoint < #lane.Points and U.flat(lane.Points[unit.Waypoint]):Dot(lane.Dir) > radius + 1 do unit.Waypoint = unit.Waypoint + 1 end
    -- 가는 길을 막은 벽·문(플레이어가 놓은 것)을 부순다. 브루트는 가까운 구조물이면 무엇이든 노린다
    local barrier, contact = self.ctx.Defenses:Barrier(unit.Part.Position, lane.Points[unit.Waypoint], unit.Spec.Size / 2 + 0.5, unit.Spec.Range + 6)
    if unit.Kind == "Brute" then
        local nearby, point = self.ctx.Defenses:Nearest(unit.Part.Position, unit.Spec.Aggro)
        if nearby and (not barrier or U.flat(point - unit.Part.Position).Magnitude < U.flat(contact - unit.Part.Position).Magnitude) then barrier, contact = nearby, point end
    end
    if barrier then
        if not self:TryAttack(unit, contact, unit.Spec.Range, function(d) self.ctx.Defenses:Damage(barrier, d) end) then self:Move(unit, contact, dt) end
        return
    end
    local core = self.ctx.Map.Core.Position
    if self:TryAttack(unit, core, unit.Spec.Range + 4, function(d) self.ctx.Core:Damage(d) end) then return end
    local goal = lane.Points[unit.Waypoint]
    if U.flat(goal - unit.Part.Position).Magnitude < 2 and unit.Waypoint < #lane.Points then unit.Waypoint = unit.Waypoint + 1 end
    self:Move(unit, lane.Points[unit.Waypoint], dt)
end
return S
