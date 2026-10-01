local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local Rules = require(RS.Shared.Modules.Rules)
local C = require(RS.Shared.Config.GameConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local I = require(RS.Shared.Config.ItemConfig)
local B = require(RS.Shared.Visuals.Build)
local S = {}
-- 반짝이는 황금 노드: 다 캐면 수확량 x3. 판이 시작될 때 기지 근처 몇 개 + 맵 곳곳, 다시 자랄 때도 가끔 황금이 된다
local GOLD = {Yield = 3, NearBase = 3, Scatter = 8, Max = 12, RegrowChance = 0.05, Color = "#ffd54a"}
S.Gold = GOLD

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
        self:SetGolden(node, false)
        self:ShowNode(node, true)
    end
    self:PickGolden()
end

-- 황금 노드 고르기: 스폰에서 걸어서 금방 닿는 곳(60~170) 몇 개 + 맵 전체에서 무작위
function S:PickGolden()
    local rng = Random.new()
    local near, far = {}, {}
    for _, node in ipairs(self.ctx.Map.Nodes) do
        local d = U.flat(node.Home.Position).Magnitude
        if d > 60 and d < 170 then table.insert(near, node) elseif d >= 170 then table.insert(far, node) end
    end
    for _, spec in ipairs({{near, GOLD.NearBase}, {far, GOLD.Scatter}}) do
        local list, want = spec[1], spec[2]
        for _ = 1, math.min(want, #list) do
            local i = rng:NextInteger(1, #list)
            self:SetGolden(table.remove(list, i), true)
        end
    end
end

function S:GoldenCount()
    local n = 0
    for _, node in ipairs(self.ctx.Map.Nodes) do if node.Golden then n = n + 1 end end
    return n
end

-- 황금 표시: 노드에 금빛 테두리(Highlight) + 반짝이 + 빛. 클라이언트는 Golden 속성으로 팝업을 띄운다
function S:SetGolden(node, on)
    if (node.Golden or false) == on then return end
    node.Golden = on or nil
    node.Part:SetAttribute("Golden", on or nil)
    if not on then
        if node.GoldFX then for _, fx in ipairs(node.GoldFX) do fx:Destroy() end end
        node.GoldFX = nil
        return
    end
    local glow = Instance.new("Highlight")
    glow.Name, glow.FillColor, glow.OutlineColor = "Golden", Color3.fromHex(GOLD.Color), Color3.fromHex("#fff3b0")
    glow.FillTransparency, glow.OutlineTransparency, glow.DepthMode = 0.55, 0.1, Enum.HighlightDepthMode.Occluded
    glow.Parent = node.Model
    local sparkle = Instance.new("ParticleEmitter")
    sparkle.Name = "GoldSparkle"
    sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparkle.Color = ColorSequence.new(Color3.fromHex("#fff3b0"), Color3.fromHex(GOLD.Color))
    sparkle.Size = NumberSequence.new(0.7, 0)
    sparkle.Rate, sparkle.Lifetime, sparkle.Speed = 10, NumberRange.new(0.8, 1.4), NumberRange.new(1, 3)
    sparkle.SpreadAngle, sparkle.LightEmission, sparkle.Acceleration = Vector2.new(180, 180), 1, Vector3.new(0, 2, 0)
    sparkle.Parent = node.Part
    local light = Instance.new("PointLight")
    light.Name, light.Color, light.Range, light.Brightness, light.Shadows = "GoldLight", Color3.fromHex(GOLD.Color), 14, 1.2, false
    light.Parent = node.Part
    node.GoldFX = {glow, sparkle, light}
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
-- from 을 주면 그 자리에서 튀어 올라 떨어지는 모습을 클라이언트가 그린다 (보물상자·쓰러진 나무)
function S:Drop(kind, amount, position, from)
    if amount <= 0 or #self.Drops >= C.DropLimit then return end
    local p = DROP_LOOK[kind](self.ctx.Map.DropsFolder, CFrame.new(position.X, 1.1, position.Z))
    p.Name = kind
    p:SetAttribute("Amount", amount)
    if from then p:SetAttribute("PopFrom", from) end
    -- 줍기는 잠깐 뒤부터 (튀어나오는 모습이 보이게)
    table.insert(self.Drops, {Part = p, Kind = kind, Amount = amount, Expires = os.clock() + C.DropLifetime, ReadyAt = os.clock() + (from and 0.7 or 0.25)})
end
-- 채집에 쓸 도구: 손에 든 것과 상관없이 가진 것 중 이 자원에 맞는 가장 좋은 도구 (없으면 손에 든 것)
function S:ToolFor(player, kind, held)
    local family = R.Types[kind].Tool
    if family and self.ctx.Crafting then
        local _, spec = self.ctx.Crafting:Best(player, family)
        if spec then return spec end
    end
    return held
end
-- 도구로 채집 배율을 정한다. 맞는 도구(도끼→나무, 곡괭이→돌·고철·수정)는 등급이 높을수록 빠르고 많이 나온다.
-- 반환: 배율, 수확량 배율 (캘 수 없으면 nil 과 이유)
function S:GatherRate(kind, tool)
    local spec = R.Types[kind]
    if not spec.Tool then return 1, 1 end
    if tool and tool.Family == spec.Tool then
        if spec.MinTier and (tool.Tier or 1) < spec.MinTier then return nil, {k = "gather.needBetterPick"} end
        return tool.Gather or 1, 1 + 0.25 * ((tool.Tier or 1) - 1)
    end
    if spec.MinTier then return nil, {k = "gather.needPick"} end
    return tool and I.WrongToolGather or I.HandGather, 1
end
function S:Harvest(player, node, held)
    if node.HP <= 0 or not U.near(player, node.Part.Position, C.SpearRange) then return false end
    local tool = self:ToolFor(player, node.Kind, held)
    local rate, bonus = self:GatherRate(node.Kind, tool)
    if not rate then
        if os.clock() >= (self.HintAt[player] or 0) then self.HintAt[player] = os.clock() + 3; self.ctx.Notify(player, bonus) end
        return false
    end
    if rate < 0.5 and os.clock() >= (self.HintAt[player] or 0) then
        self.HintAt[player] = os.clock() + 8
        self.ctx.Notify(player, {k = R.Types[node.Kind].Tool == "Axe" and "gather.useAxe" or "gather.usePick"})
    end
    node.HP = math.max(0, node.HP - C.HarvestDamage * rate)
    node.Part:SetAttribute("CurrentHealth", node.HP)
    node.Part:SetAttribute("HitAt", workspace:GetServerTimeNow())
    local depleted = node.HP == 0
    local root = U.aliveRoot(player)
    -- 흔들림·쓰러짐 연출은 모델이 치워지기 전에 보낸다 (클라이언트가 모델을 복제해서 쓰러뜨린다)
    self.ctx.FX:FireAllClients("Harvest", root and root.Position or node.Part.Position, node.Part.Position, node.Kind,
        {Model = node.Model, Done = depleted, Gold = node.Golden, O = player.UserId, HP = node.HP / R.Types[node.Kind].HP, Tool = tool and tool.Family})
    if depleted then
        local golden = node.Golden
        self:ShowNode(node, false)
        node.RespawnAt = os.clock() + R.Types[node.Kind].Respawn
        local yield = math.floor(R.Types[node.Kind].Yield * bonus * (golden and GOLD.Yield or 1) + 0.5)
        self:SetGolden(node, false)
        local pieces = golden and 5 or 2
        for n = 1, pieces do
            local amount = math.floor(yield / pieces) + (n <= yield % pieces and 1 or 0)
            local spread = CFrame.Angles(0, math.random() * math.pi * 2, 0) * CFrame.new(0, 0, 3 + math.random() * 2)
            self:Drop(node.Kind, amount, node.Part.Position + spread.Position, golden and node.Part.Position + Vector3.new(0, 3, 0) or nil)
        end
    end
    return true, depleted
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
            if math.random() < GOLD.RegrowChance and self:GoldenCount() < GOLD.Max then self:SetGolden(node, true) end
        end
    end
    -- No yield between claim and removal: a drop cannot be paid to two players.
    for i = #self.Drops, 1, -1 do
        local drop = self.Drops[i]
        for _, player in ipairs(Players:GetPlayers()) do
            local bag = self.Bags[player]
            if bag and now >= (drop.ReadyAt or 0) and U.near(player, drop.Part.Position, C.PickupRadius) then
                local amount = Rules.pickupAmount(bag, drop.Amount, self.ctx.Crafting and self.ctx.Crafting:Capacity(player) or C.CarryCapacity)
                bag[drop.Kind], drop.Amount = bag[drop.Kind] + amount, drop.Amount - amount
                -- 빨려 들어가는 모습 + "+8 🪵" (클라이언트)
                if amount > 0 then self.ctx.FX:FireAllClients("Pickup", drop.Part.Position, player, drop.Kind, amount) end
                if drop.Amount == 0 then break end
            end
        end
        if drop.Amount == 0 or now >= drop.Expires then drop.Part:Destroy(); table.remove(self.Drops, i) end
    end
end
function S:Spend(cost) return Rules.spend(self.Bank, cost) end
-- 플레이어가 낼 때: 가방 먼저, 모자라면 공용 창고(Bank). v2 는 창고 건물이 없어서 어디서나 낸다
-- (Bank 는 예전 저장/보상과의 호환용으로 남아 있다. 지금은 보통 비어 있다)
function S:SpendFor(player, cost)
    return Rules.spendMany({self.Bags[player] or self:Empty(), self.Bank}, cost)
end
return S
