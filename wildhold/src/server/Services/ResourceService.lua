local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local Rules = require(RS.Shared.Modules.Rules)
local C = require(RS.Shared.Config.GameConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local B = require(RS.Shared.Visuals.Build)
local S = {}

-- 떨어진 자원 모양 (밟으면 획득). 클라이언트가 둥실둥실 돌린다.
local DROP_LOOK = {
	Wood = function(parent, at) return B.cyl(parent, 1.6, 0.8, at, "#8a5d36", Enum.Material.Wood) end,
	Stone = function(parent, at) return B.block(parent, Vector3.new(1.1, 0.9, 1.0), at * CFrame.Angles(0.4, 0.6, 0.2), "#a3aab0", Enum.Material.Slate) end,
	Fiber = function(parent, at) return B.ellipsoid(parent, Vector3.new(0.6, 1.5, 0.6), at * CFrame.Angles(0, 0, 0.5), "#8cbf5a", Enum.Material.SmoothPlastic) end,
	Scrap = function(parent, at) return B.cyl(parent, 0.35, 1.3, at * CFrame.Angles(0, 0, math.rad(90)), "#b0763e", Enum.Material.CorrodedMetal) end,
	Berry = function(parent, at) return B.ball(parent, 0.9, at, "#e2385b", Enum.Material.SmoothPlastic) end,
}
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
-- 다 캔 노드는 모델을 치우고 작은 그루터기/잔해만 남긴다. 시간이 지나면 다시 자란다.
function S:ShowNode(node, visible)
    local wasVisible = node.Model.Parent ~= nil
    node.Model.Parent = visible and self.ctx.Map.NodesFolder or nil
    node.Part.CanQuery = visible
    node.Part:SetAttribute("CurrentHealth", node.HP)
    if not node.Stump then
        local color = node.Kind == "Wood" and "#7a5230" or (node.Kind == "Berry" and "#3f8f4a" or "#8d949a")
        node.Stump = B.cyl(self.ctx.Map.NodesFolder, 0.8, node.Kind == "Wood" and 1.6 or 2.2, node.Home * CFrame.new(0, 0.4, 0), color,
            node.Kind == "Wood" and Enum.Material.Wood or Enum.Material.Slate, true)
        node.Stump.Name = "Depleted"
    end
    node.Stump.Transparency = visible and 1 or 0
    if visible and not wasVisible then self.ctx.FX:FireAllClients("Regrow", node.Home.Position, node.Kind) end
end
function S:Drop(kind, amount, position)
    if amount <= 0 or #self.Drops >= C.DropLimit then return end
    local p = DROP_LOOK[kind](self.ctx.Map.DropsFolder, CFrame.new(position.X, 1.1, position.Z))
    p.Name = kind
    p:SetAttribute("Amount", amount)
    table.insert(self.Drops, {Part = p, Kind = kind, Amount = amount, Expires = os.clock() + C.DropLifetime})
end
function S:Harvest(player, node)
    if node.HP <= 0 or not U.near(player, node.Part.Position, C.SpearRange) then return end
    node.HP = math.max(0, node.HP - C.HarvestDamage)
    node.Part:SetAttribute("CurrentHealth", node.HP)
    node.Part:SetAttribute("HitAt", workspace:GetServerTimeNow())
    if node.HP == 0 then self:ShowNode(node, false) end
    if node.HP == 0 then
        node.RespawnAt = os.clock() + R.Types[node.Kind].Respawn
        for n = 1, 2 do
            local amount = n == 1 and math.ceil(R.Types[node.Kind].Yield / 2) or math.floor(R.Types[node.Kind].Yield / 2)
            local spread = CFrame.Angles(0, math.random() * math.pi * 2, 0) * CFrame.new(0, 0, 3.5)
            self:Drop(node.Kind, amount, node.Part.Position + spread.Position)
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
