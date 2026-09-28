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
    for _, old in ipairs(backpack:GetChildren()) do if old:GetAttribute("WildholdSpear") then old:Destroy() end end
    local tool = Instance.new("Tool")
    tool.Name, tool.CanBeDropped, tool.RequiresHandle = "창", false, true
    tool.ToolTip = "공격 · 채집"
    tool:SetAttribute("WildholdSpear", true)
    -- 손잡이(Handle) + 창날 + 천 감개. 창끝이 앞(-Z)으로 향하도록 GripForward 를 맞춘다.
    local handle = Instance.new("Part")
    handle.Name, handle.Size = "Handle", Vector3.new(0.32, 0.32, 5.6)
    handle.Color, handle.Material, handle.CanCollide, handle.Massless = Color3.fromRGB(150, 104, 62), Enum.Material.Wood, false, true
    handle.Parent = tool
    local function piece(size, offset, color, material, shape)
        local p = Instance.new("Part")
        p.Size, p.Color, p.Material, p.CanCollide, p.Massless = size, color, material, false, true
        if shape then p.Shape = shape end
        p.CFrame = handle.CFrame * offset
        local weld = Instance.new("WeldConstraint")
        weld.Part0, weld.Part1, weld.Parent = handle, p, p
        p.Parent = tool
        return p
    end
    piece(Vector3.new(0.12, 0.62, 1.3), CFrame.new(0, 0, -3.25), Color3.fromRGB(214, 226, 232), Enum.Material.Metal)
    piece(Vector3.new(0.12, 0.62, 0.62), CFrame.new(0, 0, -3.95) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(214, 226, 232), Enum.Material.Metal)
    piece(Vector3.new(0.42, 0.42, 0.7), CFrame.new(0, 0, -2.4), Color3.fromRGB(64, 170, 150), Enum.Material.Fabric)
    piece(Vector3.new(0.42, 0.42, 0.5), CFrame.new(0, 0, 0.6), Color3.fromRGB(120, 78, 44), Enum.Material.Fabric)
    tool.Grip = CFrame.new(0, 0, 0.9) * CFrame.Angles(0, 0, 0)
    tool.Parent = backpack
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
    -- 기본 Animate 스크립트가 "toolanim" 값을 보고 찌르기 동작을 재생한다
    local anim = Instance.new("StringValue")
    anim.Name, anim.Value, anim.Parent = "toolanim", "Lunge", tool
    game:GetService("Debris"):AddItem(anim, 0.3)
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
