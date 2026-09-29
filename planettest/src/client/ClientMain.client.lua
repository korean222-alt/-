local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Lighting=game:GetService("Lighting")
-- PlayerScripts의 형제 폴더는 이 LocalScript보다 늦게 복제될 수 있습니다.
local modules=script.Parent:WaitForChild("Modules")
local Controller=require(modules:WaitForChild("GravityController"))
local player=Players.LocalPlayer
local active,generation=nil,0
local function cleanup()
    generation+=1
    if active then active:Destroy(); active=nil end
end
local function start(character)
    cleanup()
    local token=generation
    while character.Parent and not character:GetAttribute("PlanetPrepared") do
        if token~=generation then return end
        task.wait()
    end
    if token~=generation or not character.Parent then return end
    local controller=Controller.new(player,character,function() return token==generation and character.Parent~=nil end)
    if not controller then return end
    active=controller
    RS:WaitForChild("PlanetClientReady"):FireServer(character)
    character:WaitForChild("Humanoid").Died:Once(function()
        if active==controller then cleanup() end
    end)
    print("PlanetTest client ready: 중심 중력 / 기본 입력 / 행성 카메라")
end
player.CharacterAdded:Connect(start)
player.CharacterRemoving:Connect(cleanup)
if player.Character then task.spawn(start,player.Character) end
local gui=Instance.new("ScreenGui")
gui.Name,gui.ResetOnSpawn="PlanetDayNight",false
local button=Instance.new("TextButton")
button.Size,button.Position=UDim2.fromOffset(120,44),UDim2.new(1,-136,0,16)
button.BackgroundColor3,button.TextColor3,button.TextSize=Color3.fromRGB(32,42,47),Color3.new(1,1,1),18
button.Parent=gui
gui.Parent=player:WaitForChild("PlayerGui")
local night=false
local function update()
    Lighting.ClockTime=if night then 0 else 14
    Lighting.Brightness=if night then 0 else 2
    -- 낮에는 반대편에서도 걷기를 검사할 수 있게 약한 전체 조명을 둡니다.
    Lighting.Ambient=if night then Color3.new(0,0,0) else Color3.fromRGB(140,145,155)
    Lighting.OutdoorAmbient=Lighting.Ambient
    Lighting.EnvironmentDiffuseScale=if night then 0 else 0.6
    Lighting.EnvironmentSpecularScale=if night then 0 else 0.5
    button.Text=if night then "☀ 낮으로" else "☾ 밤으로"
end
button.Activated:Connect(function() night=not night; update() end)
update()
