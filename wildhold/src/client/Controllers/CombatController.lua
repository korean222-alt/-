-- 공격/채집 입력. 클라이언트는 "공격하고 싶다"는 의도만 보낸다. 대상과 피해는 서버가 정한다.
local CAS = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config.GameConfig)
local I = require(RS.Shared.Config.ItemConfig)
local Inv = require(RS.Shared.Modules.Inventory)
local Swing = require(script.Parent.SwingController)

local Controller = {}

function Controller:Init(remotes)
	local last = 0
	local player = Players.LocalPlayer
	CAS:BindAction("WildholdAttack", function(_, state)
		if player:GetAttribute("PetMenuOpen") then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Begin and os.clock() - last >= C.SpearCooldown then
			last = os.clock()
			remotes.AttackRequest:FireServer()
			-- 팔 동작은 서버를 기다리지 않고 바로 (든 것에 맞게: 도끼 내려찍기, 창 찌르기, 음식 먹기 …)
			local character = player.Character
			local tool = character and character:FindFirstChildOfClass("Tool")
			Swing:Play(character, Inv.motion(tool and I.Items[tool:GetAttribute("ItemId")]), true)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	CAS:SetTitle("WildholdAttack", "공격")
	CAS:SetPosition("WildholdAttack", UDim2.new(1, -150, 1, -150))
	local button = CAS:GetButton("WildholdAttack")
	if button then
		button.Size = UDim2.fromOffset(84, 84)
	end
end

return Controller
