local RS = game:GetService("ReplicatedStorage")
local remotes = RS:WaitForChild("Remotes")
for _, name in ipairs({"State", "AttackRequest", "Notice", "FX", "PetAction", "CraftAction", "CaptureAction", "PetFX"}) do remotes:WaitForChild(name) end
local Controllers = script.Parent:WaitForChild("Controllers")
local function start(name, ...)
	local ok, result = pcall(function(...)
		local controller = require(Controllers:WaitForChild(name))
		controller:Init(...)
		return controller
	end, ...)
	if not ok then
		warn("[WILDHOLD] " .. name .. " 시작 실패: " .. tostring(result))
		return nil
	end
	return result
end
-- 화면 연출이 하나 실패해도 게임 진행(입력, HUD)은 계속되도록 따로 시작한다
start("EnvironmentController")
local ui = start("UIController", remotes)
local pets = start("PetController", remotes)
if ui and pets then ui.PetController = pets end
start("CombatController", remotes)
start("CreatureController")
start("FXController", remotes)
start("WorldUI")
start("AudioController", remotes)
