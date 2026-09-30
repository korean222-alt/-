local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:WaitForChild("Remotes")
for _, name in ipairs({"State", "AttackRequest", "Notice", "FX", "PetAction", "CraftAction", "CaptureAction", "PetFX", "Lobby", "LobbyAction", "BuildRequest", "Settings"}) do remotes:WaitForChild(name) end
local Controllers = script.Parent:WaitForChild("Controllers")
local player = Players.LocalPlayer
-- 언어: ⚙ 설정에서 고른 것(속성 Lang, 서버 저장) → 없으면 Roblox 계정 언어. 컨트롤러보다 먼저 정한다
local Locale = require(RS.Shared.Modules.Locale)
local function language()
	local chosen = player:GetAttribute("Lang")
	if type(chosen) == "string" and Locale.Tables[chosen] then return chosen end
	local ok, id = pcall(function() return game:GetService("LocalizationService").RobloxLocaleId end)
	if not ok or type(id) ~= "string" or id == "" then ok, id = pcall(function() return player.LocaleId end) end
	return Locale.pick(ok and id or "")
end
Locale.set(language())
player:GetAttributeChangedSignal("Lang"):Connect(function() Locale.set(language()) end)
local function start(name, ...)
	local ok, result = pcall(function(...)
		local controller = require(Controllers:WaitForChild(name))
		controller:Init(...)
		return controller
	end, ...)
	if not ok then
		warn("[WILDHOLD] " .. name .. " failed to start: " .. tostring(result))
		return nil
	end
	return result
end
-- 서버 종류 (ServerMain): Lobby = 로비 캠프만, Expedition = 원정 맵만, Both = Studio (둘 다, 그 사이를 오간다)
local mode = workspace:GetAttribute("ServerMode")
for _ = 1, 50 do
	if mode then break end
	task.wait(0.1)
	mode = workspace:GetAttribute("ServerMode")
end
mode = mode or "Expedition"
-- 화면 연출이 하나 실패해도 게임 진행(입력, HUD)은 계속되도록 따로 시작한다
start("EnvironmentController")
if mode ~= "Lobby" then
	local ui = start("UIController", remotes)
	local pets = start("PetController", remotes)
	if ui and pets then ui.PetController = pets end
	start("SwingController", remotes)
	start("BuildController", remotes)
	start("CombatController", remotes)
	start("HotbarController", remotes)
	start("CreatureController")
	start("FXController", remotes)
	start("WorldUI")
	start("MapController", remotes)
else
	start("SwingController", remotes)
	start("CreatureController")
end
start("AudioController", remotes)
start("MusicController", remotes)
start("SettingsController", remotes)
if mode ~= "Expedition" then start("LobbyController", remotes) end

-- 지금 있는 곳(서버가 정하는 Place 속성)에 맞는 화면만 켠다
local EXPEDITION_GUIS = {"WildholdHUD", "Hotbar", "Minimap", "PetBook", "BuildHint"}
local function apply()
	local place = player:GetAttribute("Place") or (mode == "Lobby" and "Lobby" or "Expedition")
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return end
	for _, name in ipairs(EXPEDITION_GUIS) do
		local screen = gui:FindFirstChild(name)
		if screen then screen.Enabled = place == "Expedition" end
	end
	local world = gui:FindFirstChild("WorldMap")
	if world and place ~= "Expedition" then world.Enabled = false end
	local lobby = gui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = place == "Lobby" end
end
player:GetAttributeChangedSignal("Place"):Connect(apply)
apply()
