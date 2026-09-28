local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local Rules = require(RS.Shared.Modules.Rules)
local C = require(RS.Shared.Config.GameConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local S = {}
function S:Empty()
    local result = {}
    for _, kind in ipairs(R.Order) do result[kind] = 0 end
    return result
end
function S:Init(ctx)
    self.ctx, self.Bags, self.Bank, self.Drops = ctx, {}, self:Empty(), {}
    self:Reset()
end
function S:AddPlayer(player) self.Bags[player] = self:Empty() end
function S:RemovePlayer(player) self.Bags[player] = nil end
function S:Reset()
    self.Bank = self:Empty()
    self.Drops = {}
    self.ctx.Map.DropsFolder:ClearAllChildren()
    for player in pairs(self.Bags) do self.Bags[player] = self:Empty() end
    for _, node in ipairs(self.ctx.Map.Nodes) do
        node.HP, node.RespawnAt = R.Types[node.Kind].HP, nil
        self:ShowNode(node, true)
    end
end
function S:ShowNode(node, visible)
    node.Part.Transparency, node.Part.CanCollide = visible and 0 or 1, visible
    node.Part.CanQuery, node.Label.Parent.Enabled = visible, visible
    node.Part:SetAttribute("CurrentHealth", node.HP)
    node.Label.Text = string.format("%s  %d", R.Labels[node.Kind], node.HP)
end
function S:Drop(kind, amount, position)
    if amount <= 0 or #self.Drops >= C.DropLimit then return end
    local p = U.part(self.ctx.Map.DropsFolder, kind, Vector3.new(1.4, 1.4, 1.4), Vector3.new(position.X, 1.1, position.Z), U.color(R.Types[kind].Color))
    p.CanCollide, p.CanQuery, p.Material = false, false, Enum.Material.Neon
    table.insert(self.Drops, {Part = p, Kind = kind, Amount = amount, Expires = os.clock() + C.DropLifetime})
end
function S:Harvest(player, node)
    if node.HP <= 0 or not U.near(player, node.Part.Position, C.SpearRange) then return end
    node.HP = math.max(0, node.HP - C.HarvestDamage)
    self:ShowNode(node, node.HP > 0)
    if node.HP == 0 then
        node.RespawnAt = os.clock() + R.Types[node.Kind].Respawn
        for n = 1, 2 do
            local amount = n == 1 and math.ceil(R.Types[node.Kind].Yield / 2) or math.floor(R.Types[node.Kind].Yield / 2)
            self:Drop(node.Kind, amount, node.Part.Position + Vector3.new(n * 2 - 3, 0, 2))
        end
    end
end
function S:OnDeath(player, position)
    local bag = self.Bags[player]
    if not bag then return end
    for kind, amount in pairs(bag) do
        local lost = math.floor(amount * C.DeathDropFraction)
        bag[kind] = amount - lost
        self:Drop(kind, lost, position)
    end
end
function S:Tick()
    if C.ActiveStage < 2 then return end
    local phase = self.ctx.Clock.Phase
    if phase ~= "Day" and phase ~= "Night" then return end
    local now = os.clock()
    for _, node in ipairs(self.ctx.Map.Nodes) do
        if node.RespawnAt and now >= node.RespawnAt then
            node.HP, node.RespawnAt = R.Types[node.Kind].HP, nil
            self:ShowNode(node, true)
        end
    end
    -- No yield between claim and removal: a drop cannot be paid to two players.
    for i = #self.Drops, 1, -1 do
        local drop = self.Drops[i]
        for _, player in ipairs(Players:GetPlayers()) do
            local bag = self.Bags[player]
            if bag and U.near(player, drop.Part.Position, C.PickupRadius) then
                local amount = Rules.pickupAmount(bag, drop.Amount, C.CarryCapacity)
                bag[drop.Kind], drop.Amount = bag[drop.Kind] + amount, drop.Amount - amount
                if drop.Amount == 0 then break end
            end
        end
        if drop.Amount == 0 or now >= drop.Expires then drop.Part:Destroy(); table.remove(self.Drops, i) end
    end
    for player, bag in pairs(self.Bags) do
        if U.near(player, self.ctx.Map.Warehouse.Position, C.DepositRadius) then
            for kind, amount in pairs(bag) do self.Bank[kind], bag[kind] = self.Bank[kind] + amount, 0 end
        end
    end
end
function S:Spend(cost) return Rules.spend(self.Bank, cost) end
return S
