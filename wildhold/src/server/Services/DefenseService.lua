local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local Rules = require(RS.Shared.Modules.Rules)
local C = require(RS.Shared.Config.GameConfig)
local D = require(RS.Shared.Config.DefenseConfig)
local S = {}
function S:Init(ctx)
    self.ctx, self.Slots, self.LastAction = ctx, {}, {}
    for _, slot in ipairs(ctx.Map.Slots) do
        if D[slot.Kind] then
            self.Slots[slot.Id] = slot
            slot.Label = U.label(slot.Pad, "", 4)
            slot.BuildPrompt = U.prompt(slot.Pad, "Build", "건설", Enum.KeyCode.E, Vector3.new(0, 2, 0))
            slot.RepairPrompt = U.prompt(slot.Pad, "Repair", "수리", Enum.KeyCode.R, Vector3.new(0, 4, 0))
            slot.BuildPrompt.Triggered:Connect(function(player) self:Interact(player, slot, "Build") end)
            slot.RepairPrompt.Triggered:Connect(function(player) self:Interact(player, slot, "Repair") end)
        end
    end
    self:Reset()
end
function S:CostText(cost)
    local R = require(RS.Shared.Config.ResourceConfig)
    local parts = {}
    for _, kind in ipairs(R.Order) do
        if cost[kind] then table.insert(parts, R.Labels[kind] .. " " .. cost[kind]) end
    end
    return table.concat(parts, " · ")
end
function S:Reset()
    self.ctx.Map.DefensesFolder:ClearAllChildren()
    self.LastAction = {}
    for _, slot in pairs(self.Slots) do
        slot.Visual, slot.NextAttack, slot.LastMutation = nil, 0, -math.huge
        slot.Level = C.ActiveStage >= 3 and slot.InitialLevel or 0
        slot.HP = slot.Level > 0 and D[slot.Kind].Levels[slot.Level].HP or 0
        self:Render(slot)
    end
end
function S:Render(slot)
    if slot.Visual then slot.Visual:Destroy(); slot.Visual = nil end
    if slot.Level > 0 then
        local spec = D[slot.Kind]
        local size = Vector3.new(table.unpack(spec.Size))
        local p = U.part(self.ctx.Map.DefensesFolder, slot.Id, size, slot.Pad.Position + Vector3.new(0, size.Y / 2, 0))
        p.CFrame = slot.Pad.CFrame + Vector3.new(0, size.Y / 2, 0)
        p.Color = slot.Kind == "ArrowTower" and Color3.fromRGB(204, 186, 133) or Color3.fromRGB(116 + slot.Level * 15, 129 + slot.Level * 12, 133)
        p.CanCollide = slot.Kind ~= "Gate" and slot.Kind ~= "SpikeTrap"
        p:SetAttribute("SlotId", slot.Id)
        slot.Visual = p
    end
    self:Refresh(slot)
end
function S:Refresh(slot)
    local spec = D[slot.Kind]
    local stats = spec.Levels[slot.Level]
    local nextStats = spec.Levels[slot.Level + 1]
    local phase = self.ctx.Clock.Phase
    slot.Pad:SetAttribute("Level", slot.Level)
    slot.Pad:SetAttribute("CurrentHealth", slot.HP)
    if slot.Visual then slot.Visual:SetAttribute("CurrentHealth", slot.HP) end
    slot.Label.Text = spec.Name .. (stats and string.format(" Lv%d  %d/%d", slot.Level, slot.HP, stats.HP) or " · 빈 자리")
    slot.BuildPrompt.Enabled = C.ActiveStage >= 3 and phase == "Day" and nextStats ~= nil
    slot.BuildPrompt.ActionText = (slot.Level == 0 and "건설 " or "강화 ") .. (nextStats and self:CostText(nextStats.Cost) or "최대")
    slot.BuildPrompt.ObjectText = spec.Name
    slot.RepairPrompt.Enabled = C.ActiveStage >= 3 and (phase == "Day" or phase == "Night") and stats ~= nil and slot.HP < stats.HP
    local mult = phase == "Night" and C.NightRepairMultiplier or 1
    slot.RepairPrompt.ActionText = "수리 " .. (stats and self:CostText(Rules.repairCost(stats.Repair, mult)) or "")
    slot.RepairPrompt.ObjectText = spec.Name
end
function S:RefreshAll() for _, slot in pairs(self.Slots) do self:Refresh(slot) end end
function S:Interact(player, slot, action)
    if C.ActiveStage < 3 or not self.ctx.Run:IsParticipant(player) then return end
    if not U.near(player, slot.Pad.Position, C.InteractionRange) then return end
    local now = os.clock()
    if now - (self.LastAction[player] or -math.huge) < C.InteractionCooldown then return end
    self.LastAction[player] = now
    if now - (slot.LastMutation or -math.huge) < C.InteractionCooldown then return end
    local phase, spec = self.ctx.Clock.Phase, D[slot.Kind]
    if action == "Build" then
        if phase ~= "Day" then return end
        local nextStats = spec.Levels[slot.Level + 1]
        if not nextStats then return end
        if not self.ctx.Resources:Spend(nextStats.Cost) then self.ctx.Notify(player, "공용 창고의 자원이 부족합니다"); return end
        -- No yielding in validation, spend, mutation: simultaneous requests serialize.
        local oldHP = slot.Level > 0 and spec.Levels[slot.Level].HP or 0
        slot.HP = Rules.upgradeHP(slot.HP, oldHP, nextStats.HP)
        slot.Level = slot.Level + 1
        slot.LastMutation = now
        self:Render(slot)
        self.ctx.Notify(player, spec.Name .. " Lv" .. slot.Level .. " 완성")
    elseif action == "Repair" then
        if phase ~= "Day" and phase ~= "Night" then return end
        local stats = spec.Levels[slot.Level]
        if not stats or slot.HP >= stats.HP then return end
        local cost = Rules.repairCost(stats.Repair, phase == "Night" and C.NightRepairMultiplier or 1)
        if not self.ctx.Resources:Spend(cost) then self.ctx.Notify(player, "수리 자원이 부족합니다"); return end
        slot.HP = math.min(stats.HP, slot.HP + math.ceil(stats.HP * C.RepairFraction))
        slot.LastMutation = now
        self:Refresh(slot)
    end
end
function S:Damage(slot, amount)
    if slot.Level == 0 or slot.HP <= 0 then return end
    slot.HP = math.max(0, slot.HP - amount)
    if slot.HP == 0 then slot.Level = 0; self:Render(slot) else self:Refresh(slot) end
end
function S:Barrier(laneId, position)
    local closest, distance = nil, math.huge
    local dir = self.ctx.Map.Lanes[laneId].Dir
    local radius = U.flat(position):Dot(dir)
    for _, slot in pairs(self.Slots) do
        if slot.LaneId == laneId and slot.Level > 0 and D[slot.Kind].Blocks then
            local r = U.flat(slot.Pad.Position):Dot(dir)
            local delta = radius - r
            if delta >= -2 and delta < distance then closest, distance = slot, delta end
        end
    end
    return closest
end
function S:Nearest(position, radius)
    local closest, distance = nil, radius
    for _, slot in pairs(self.Slots) do
        if slot.Level > 0 and slot.Kind ~= "SpikeTrap" then
            local d = U.flat(slot.Pad.Position - position).Magnitude
            if d < distance then closest, distance = slot, d end
        end
    end
    return closest
end
function S:Tick()
    if C.ActiveStage < 3 or self.ctx.Clock.Phase ~= "Night" then return end
    local now = os.clock()
    for _, slot in pairs(self.Slots) do
        local stats = D[slot.Kind].Levels[slot.Level]
        if stats and stats.Damage and now >= slot.NextAttack then
            local origin = slot.Visual.Position + Vector3.new(0, slot.Visual.Size.Y / 2, 0)
            local target = self.ctx.Enemies:Nearest(origin, stats.Range, slot.Kind == "ArrowTower", slot.Visual)
            if target then
                slot.NextAttack = now + stats.Interval
                if slot.Kind == "SpikeTrap" then
                    for _, enemy in pairs(self.ctx.Enemies.Units) do
                        if U.flat(enemy.Part.Position - slot.Pad.Position).Magnitude <= stats.Range then self.ctx.Enemies:Damage(enemy, stats.Damage) end
                    end
                else
                    self.ctx.FX:FireAllClients("Arrow", origin, target.Part.Position)
                    self.ctx.Enemies:Damage(target, stats.Damage * (C.ActiveStage >= 5 and C.TowerDamageScale or 1))
                end
            end
        end
    end
end
return S
