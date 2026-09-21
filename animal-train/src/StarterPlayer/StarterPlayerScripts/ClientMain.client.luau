-- 클라이언트 시작점. 화면을 만들고 서버 신호를 연결합니다.
-- 클라이언트는 화면 표시와 입력만 담당합니다 (값은 서버가 정함).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = ReplicatedStorage:WaitForChild("Client")

local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Hud = require(Client:WaitForChild("Hud"))
local Arrow = require(Client:WaitForChild("Arrow"))
local Dex = require(Client:WaitForChild("Dex"))
local Music = require(Client:WaitForChild("Music"))
local ShopUi = require(Client:WaitForChild("ShopUi"))
local GateClient = require(Client:WaitForChild("GateClient"))
local ClientEffects = require(Client:WaitForChild("ClientEffects"))

local screen = Instance.new("ScreenGui")
screen.Name = "AnimalTrainHud"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

Hud.init(screen)
Dex.init(screen)
Music.init(screen)
ShopUi.init()
GateClient.init()
Arrow.init(playerGui) -- 3D 화살표는 PlayerGui 에 바로 넣습니다

local stateRemote = Net.event(Config.Remotes.StateUpdate)
local effectRemote = Net.event(Config.Remotes.Effect)
local requestRemote = Net.event(Config.Remotes.RequestState)

stateRemote.OnClientEvent:Connect(function(state)
	Hud.update(state)
	Dex.update(state)
	Music.update(state)
	ShopUi.update(state)
	GateClient.update(state)
	Arrow.update(state)
end)

effectRemote.OnClientEvent:Connect(function(kind, payload)
	ClientEffects.handle(kind, payload)
end)

-- 접속 직후 상태 요청 (서버가 데이터를 불러오는 중이면 조금 뒤 한 번 더)
requestRemote:FireServer()
task.delay(2, function()
	requestRemote:FireServer()
end)
task.delay(6, function()
	requestRemote:FireServer()
end)

print("[졸졸 동물 기차] 화면 준비 완료")
