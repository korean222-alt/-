local RS = game:GetService("ReplicatedStorage")
local remotes = RS:WaitForChild("Remotes")
for _, name in ipairs({"State", "AttackRequest", "Notice", "FX", "PetAction", "CraftAction", "CaptureAction", "PetFX"}) do remotes:WaitForChild(name) end
require(script.Parent.Controllers.UIController):Init(remotes)
require(script.Parent.Controllers.CombatController):Init(remotes)
require(script.Parent.Controllers.PetController):Init(remotes)
require(script.Parent.Controllers.PetAnimator):Init()
require(script.Parent.Controllers.AudioController):Init(remotes)
