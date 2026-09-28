local CAS = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local C = require(RS.Shared.Config.GameConfig)
local Controller = {}
function Controller:Init(remotes)
    local last = 0
    CAS:BindAction("WildholdAttack", function(_, state)
        if game:GetService("Players").LocalPlayer:GetAttribute("PetMenuOpen") then return Enum.ContextActionResult.Pass end
        if state == Enum.UserInputState.Begin and os.clock() - last >= C.SpearCooldown then
            last = os.clock()
            remotes.AttackRequest:FireServer()
        end
        return Enum.ContextActionResult.Sink
    end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
    CAS:SetTitle("WildholdAttack", "공격\n채집")
    CAS:SetPosition("WildholdAttack", UDim2.new(1, -90, 1, -175))
    remotes.FX.OnClientEvent:Connect(function(kind, from, to)
        local distance = (to - from).Magnitude
        if distance < 0.01 then return end
        local p = Instance.new("Part")
        p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = "LocalStrike", true, false, false, false
        p.Material, p.Size = Enum.Material.Neon, Vector3.new(0.15, 0.15, distance)
        p.Color = kind == "Arrow" and Color3.fromRGB(252, 216, 125) or Color3.fromRGB(206, 243, 229)
        p.CFrame, p.Parent = CFrame.lookAt((from + to) / 2, to), workspace
        Debris:AddItem(p, C.FXLifetime)
    end)
end
return Controller
