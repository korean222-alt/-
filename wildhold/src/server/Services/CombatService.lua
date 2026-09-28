local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local C = require(RS.Shared.Config.GameConfig)
local S = {}
function S:Init(ctx)
    self.ctx, self.LastAttack = ctx, {}
    ctx.Attack.OnServerEvent:Connect(function(player) self:Attack(player) end)
end
function S:Equip(player, character)
    local human = character:WaitForChild("Humanoid", 10)
    local backpack = player:WaitForChild("Backpack", 10)
    if not human or not backpack or not character.Parent then return end
    character:PivotTo(self.ctx.Map.Spawn.CFrame + Vector3.new(0, 4, 0))
    local tool = Instance.new("Tool")
    tool.Name, tool.CanBeDropped, tool.RequiresHandle = "Spear", false, true
    tool:SetAttribute("WildholdSpear", true)
    local handle = Instance.new("Part")
    handle.Name, handle.Size = "Handle", Vector3.new(0.3, 5, 0.3)
    handle.Color, handle.CanCollide, handle.Massless = Color3.fromRGB(187, 157, 104), false, true
    handle.Parent, tool.Parent = tool, backpack
    human:EquipTool(tool)
    human.Died:Connect(function()
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then self.ctx.Resources:OnDeath(player, root.Position) end
    end)
end
function S:Attack(player)
    if C.ActiveStage < 2 or not self.ctx.Run:IsParticipant(player) then return end
    local phase = self.ctx.Clock.Phase
    if phase ~= "Day" and phase ~= "Night" then return end
    local root = U.aliveRoot(player)
    if not root or (self.ctx.Data and not self.ctx.Data:Ready(player)) then return end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    if not tool or tool:GetAttribute("WildholdSpear") ~= true then return end
    local now = os.clock()
    if now - (self.LastAttack[player] or -math.huge) < C.SpearCooldown then return end
    self.LastAttack[player] = now
    -- Client sends intent only. Server chooses a nearby valid target and damage.
    local enemy = self.ctx.Enemies:Nearest(root.Position, C.SpearRange, true)
    if enemy then
        self.ctx.FX:FireAllClients("Spear", root.Position, enemy.Part.Position)
        self.ctx.Enemies:Damage(enemy, C.SpearDamage)
        return
    end
    if C.ActiveStage >= 6 and self.ctx.Clock.Phase == "Day" then
        local wild = self.ctx.Capture:Nearest(root.Position, C.SpearRange)
        if wild and self.ctx.Enemies:ClearShot(root.Position, wild.Part.Position) then
            self.ctx.Capture:Damage(wild, C.SpearDamage, player)
            self.ctx.FX:FireAllClients("Spear", root.Position, wild.Part.Position)
            return
        end
    end
    local best, distance = nil, C.SpearRange
    for _, node in ipairs(self.ctx.Map.Nodes) do
        local d = (node.Part.Position - root.Position).Magnitude
        if node.HP > 0 and d < distance and self.ctx.Enemies:ClearShot(root.Position, node.Part.Position) then best, distance = node, d end
    end
    if best then
        self.ctx.FX:FireAllClients("Harvest", root.Position, best.Part.Position)
        self.ctx.Resources:Harvest(player, best)
    end
end
return S
