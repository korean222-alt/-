-- 서버가 보낸 연출 신호를 소리와 화면 연출로 바꿉니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))

local Client = script.Parent
local Hud = require(Client:WaitForChild("Hud"))
local Dex = require(Client:WaitForChild("Dex"))
local Arrow = require(Client:WaitForChild("Arrow"))
local ShopUi = require(Client:WaitForChild("ShopUi"))
local GateClient = require(Client:WaitForChild("GateClient"))

local ClientEffects = {}

function ClientEffects.handle(kind, payload)
	payload = payload or {}

	if kind == "full" then
		Sounds.play("Full")
		Hud.flashFull()
		Arrow.showFootpath()
	elseif kind == "deliver" then
		Sounds.play("StarUp", 0.12)
	elseif kind == "newAnimal" then
		Sounds.playTimes("NewAnimal", 3, 0.12)
		Dex.showNew(payload.species)
	elseif kind == "buyOk" then
		Sounds.play("BuyOk")
	elseif kind == "buyFail" then
		Sounds.play("BuyFail")
		ShopUi.shake(payload.kind)
	elseif kind == "buyMax" then
		Sounds.play("Click")
	elseif kind == "gateOpen" then
		Sounds.playTimes("Unlock", 2, 0.2)
		GateClient.celebrate()
	elseif kind == "gateLocked" then
		Sounds.play("BuyFail")
	elseif kind == "fell" then
		Sounds.play("Splash")
	elseif kind == "rareAppeared" then
		Sounds.play("ChirpAlt", 0.1)
	end
end

return ClientEffects
