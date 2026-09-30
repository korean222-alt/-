local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local Rules = require(RS.Shared.Modules.Rules)
local C = require(RS.Shared.Config.GameConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local I = require(RS.Shared.Config.ItemConfig)
local BC = require(RS.Shared.Config.BuildConfig)
local B = require(RS.Shared.Visuals.Build)
local S = {}

-- 떨어진 자원 모양 (밟으면 획득). 클라이언트가 둥실둥실 돌린다.
local DROP_LOOK = {
	Wood = function(parent, at) return B.cyl(parent, 1.6, 0.8, at, "#8a5d36", Enum.Material.Wood) end,
	Stone = function(parent, at) return B.block(parent, Vector3.new(1.1, 0.9, 1.0), at * CFrame.Angles(0.4, 0.6, 0.2), "#a3aab0", Enum.Material.Slate) end,
	Fiber = function(parent, at) return B.ellipsoid(parent, Vector3.new(0.6, 1.5, 0.6), at * CFrame.Angles(0, 0, 0.5), "#8cbf5a", Enum.Material.SmoothPlastic) end,
	Scrap = function(parent, at) return B.cyl(parent, 0.35, 1.3, at * CFrame.Angles(0, 0, math.rad(90)), "#b0763e", Enum.Material.CorrodedMetal) end,
	Berry = function(parent, at) return B.ball(parent, 0.9, at, "#e2385b", Enum.Material.SmoothPlastic) end,
	Mushroom = function(parent, at) return B.ellipsoid(parent, Vector3.new(1.2, 0.6, 1.2), at, "#c79a6e", Enum.Material.SmoothPlastic) end,
	Crystal = function(parent, at) return B.block(parent, Vector3.new(0.6, 1.4, 0.6), at * CFrame.Angles(0.3, 0.5, 0.2), "#7ff0ff", Enum.Material.Neon) end,
}
function S:Empty()
    local result = {}
    for _, kind in ipairs(R.Order) do result[kind] = 0 end
    return result
end
function S:Init(ctx)
    self.ctx, self.Bags, self.Bank, self.Drops, self.HintAt = ctx, {}, self:Empty(), {}, {}
    self:Reset()
end
function S:AddPlayer(player) self.Bags[player] = self:Empty() end
function S:RemovePlayer(player) self.Bags[player], self.HintAt[player] = nil, nil end
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
    -- 그루터기/잔해는 처음 다 캤을 때 만든다 (맵의 나무가 천 그루가 넘어서 미리 만들어 두면 파트가 너무 많다)
    if not node.Stump and not visible then
        local color = node.Kind == "Wood" and "#7a5230" or ((node.Kind == "Berry" or node.Kind == "Mushroom" or node.Kind == "Fiber") and "#3f5a34" or "#8d949a")
        local width = node.Kind == "Wood" and math.max(1.6, (node.Width or 1.6) * 1.15) or 2.2
        node.Stump = B.cyl(self.ctx.Map.NodesFolder, 0.8, width, node.Home * CFrame.new(0, 0.4, 0), color,
            node.Kind == "Wood" and Enum.Material.Wood or Enum.Material.Slate, true)
        node.Stump.Name = "Depleted"
    end
    if node.Stump then node.Stump.Transparency = visible and 1 or 0 end
    if visible and not wasVisible then self.ctx.FX:FireAllClients("Regrow", node.Home.Position, node.Kind) end
end
function S:Drop(kind, amount, position)
    if amount <= 0 or #self.Drops >= C.DropLimit then return end
    local p = DROP_LOOK[kind](self.ctx.Map.DropsFolder, CFrame.new(position.X, 1.1, position.Z))
    p.Name = kind
    p:SetAttribute("Amount", amount)
    table.insert(self.Drops, {Part = p, Kind = kind, Amount = amount, Expires = os.clock() + C.DropLifetime})
end
-- 손에 든 도구로 채집 배율을 정한다. 맞는 도구(도끼→나무, 곡괭이→돌·고철·수정)는 등급이 높을수록 빠르고 많이 나온다.
-- 반환: 배율, 수확량 배율 (캘 수 없으면 nil 과 이유)
function S:GatherRate(kind, tool)
    local spec = R.Types[kind]
    if not spec.Tool then return 1, 1 end
    if tool and tool.Family == spec.Tool then
        if spec.MinTier and (tool.Tier or 1) < spec.MinTier then return nil, "더 좋은 곡괭이가 필요합니다 (고철 곡괭이)" end
        return tool.Gather or 1, 1 + 0.25 * ((tool.Tier or 1) - 1)
    end
    if spec.MinTier then return nil, "곡괭이가 필요합니다 (고철 곡괭이부터 캘 수 있음)" end
    return tool and I.WrongToolGather or I.HandGather, 1
end
function S:Harvest(player, node, tool)
    if node.HP <= 0 or not U.near(player, node.Part.Position, C.SpearRange) then return false end
    local rate, bonus = self:GatherRate(node.Kind, tool)
    if not rate then
        if os.clock() >= (self.HintAt[player] or 0) then self.HintAt[player] = os.clock() + 3; self.ctx.Notify(player, bonus) end
        return false
    end
    if rate < 0.5 and os.clock() >= (self.HintAt[player] or 0) then
        self.HintAt[player] = os.clock() + 8
        self.ctx.Notify(player, (R.Types[node.Kind].Tool == "Axe" and "도끼" or "곡괭이") .. "를 들면 훨씬 빨리 캡니다 · 화면 아래 칸에서 골라 드세요")
    end
    node.HP = math.max(0, node.HP - C.HarvestDamage * rate)
    node.Part:SetAttribute("CurrentHealth", node.HP)
    node.Part:SetAttribute("HitAt", workspace:GetServerTimeNow())
    if node.HP == 0 then self:ShowNode(node, false) end
    if node.HP == 0 then
        node.RespawnAt = os.clock() + R.Types[node.Kind].Respawn
        local yield = math.floor(R.Types[node.Kind].Yield * bonus + 0.5)
        for n = 1, 2 do
            local amount = n == 1 and math.ceil(yield / 2) or math.floor(yield / 2)
            local spread = CFrame.Angles(0, math.random() * math.pi * 2, 0) * CFrame.new(0, 0, 3.5)
            self:Drop(node.Kind, amount, node.Part.Position + spread.Position)
        end
    end
    return true
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
                local amount = Rules.pickupAmount(bag, drop.Amount, self.ctx.Crafting and self.ctx.Crafting:Capacity(player) or C.CarryCapacity)
                bag[drop.Kind], drop.Amount = bag[drop.Kind] + amount, drop.Amount - amount
                if drop.Amount == 0 then break end
            end
        end
        if drop.Amount == 0 or now >= drop.Expires then drop.Part:Destroy(); table.remove(self.Drops, i) end
    end
    for player, bag in pairs(self.Bags) do
        if U.near(player, self.ctx.Map.Warehouse.Position, C.DepositRadius) then
            -- 먹을 열매 몇 개는 가방에 남긴다 (핫바에서 바로 먹을 수 있게)
            for kind, amount in pairs(bag) do
                local keep = kind == "Berry" and math.min(amount, C.KeepBerries) or 0
                self.Bank[kind], bag[kind] = self.Bank[kind] + amount - keep, keep
            end
        end
    end
end
function S:Spend(cost) return Rules.spend(self.Bank, cost) end
-- 플레이어가 낼 때: 가방 먼저, 기지 영역 안이면 공용 창고까지
function S:SpendFor(player, cost)
    local wallets = {self.Bags[player] or self:Empty()}
    local root = U.aliveRoot(player)
    if root and U.flat(root.Position).Magnitude <= BC.Radius + 10 then table.insert(wallets, self.Bank) end
    return Rules.spendMany(wallets, cost)
end
return S
