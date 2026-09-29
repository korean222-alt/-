local lighting = game:GetService("Lighting")
local gui = Instance.new("ScreenGui")
gui.Name,gui.ResetOnSpawn = "DomeDayNight",false
local button = Instance.new("TextButton")
button.Size,button.Position = UDim2.fromOffset(120,44),UDim2.new(1,-136,0,16)
button.BackgroundColor3,button.TextColor3 = Color3.fromRGB(33,42,47),Color3.new(1,1,1)
button.TextSize,button.Parent = 18,gui
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local night = false
local function update()
    lighting.ClockTime = if night then 0 else 14
    lighting.Brightness = if night then 0 else 2
    lighting.Ambient = if night then Color3.new(0,0,0) else Color3.fromRGB(80,85,95)
    lighting.OutdoorAmbient = if night then Color3.new(0,0,0) else Color3.fromRGB(130,140,155)
    lighting.EnvironmentDiffuseScale = if night then 0 else 1
    lighting.EnvironmentSpecularScale = if night then 0 else 1
    button.Text = if night then "☀ 낮으로" else "☾ 밤으로"
end
button.Activated:Connect(function() night = not night; update() end)
update()
