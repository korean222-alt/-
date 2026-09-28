local U = {}
function U.folder(parent, name)
    local f = Instance.new("Folder")
    f.Name, f.Parent = name, parent
    return f
end
function U.part(parent, name, size, position, color)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Position = name, size, position
    p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Color = color or Color3.fromRGB(135, 147, 145)
    p.Parent = parent
    return p
end
function U.label(part, text, offset)
    local gui = Instance.new("BillboardGui")
    gui.Name, gui.Size, gui.StudsOffset = "Label", UDim2.fromOffset(210, 46), Vector3.new(0, offset or 5, 0)
    gui.MaxDistance, gui.AlwaysOnTop, gui.Parent = 100, false, part
    local label = Instance.new("TextLabel")
    label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
    label.Text, label.TextSize, label.TextColor3 = text, 14, Color3.fromRGB(246, 249, 244)
    label.TextStrokeTransparency, label.Font, label.Parent = 0.3, Enum.Font.GothamBold, gui
    return label
end
function U.prompt(part, name, text, key, offset)
    local attach = Instance.new("Attachment")
    attach.Position, attach.Parent = offset or Vector3.new(), part
    local p = Instance.new("ProximityPrompt")
    p.Name, p.ActionText, p.ObjectText = name, text, part.Name
    p.KeyboardKeyCode, p.MaxActivationDistance = key or Enum.KeyCode.E, 12
    p.RequiresLineOfSight, p.HoldDuration = false, 0
    p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
    p.Parent = attach
    return p
end
function U.aliveRoot(player)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local human = char and char:FindFirstChildOfClass("Humanoid")
    if root and human and human.Health > 0 then return root, human end
    return nil
end
function U.near(player, position, range)
    local root = U.aliveRoot(player)
    return root ~= nil and (root.Position - position).Magnitude <= range
end
function U.flat(v) return Vector3.new(v.X, 0, v.Z) end
function U.color(rgb) return Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end
return U
