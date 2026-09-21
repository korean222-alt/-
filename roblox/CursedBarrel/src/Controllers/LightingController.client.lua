--[[
	LightingController
	로비는 밝게, 내가 앉은 테이블의 게임이 시작되면 어둡게.

	위치: StarterPlayer > StarterPlayerScripts > Controllers > LightingController  (LocalScript)

	왜 클라이언트에서 하나?
	  로비는 구매한 스킨/디자인을 전시하는 곳이라 밝아야 하고,
	  어두운 연출은 "게임에 참가한 사람" 화면에서만 필요하기 때문이다.
	  조명을 서버에서 바꾸면 로비에 있는 사람 화면까지 같이 어두워진다.
	  Lighting 을 클라이언트에서 바꾸면 내 화면에만 적용된다.

	프리셋 값은 GameConfig.Lighting 에 모여 있다. (설치 스크립트의 로비 조명과 같은 값)
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TABLE_TAG = GameConfig.Tags.Table
local TABLE_ATTR = GameConfig.TableAttributes
local PRESETS = GameConfig.Lighting

local localPlayer = Players.LocalPlayer

local LIGHTING_KEYS = {
	"Ambient",
	"OutdoorAmbient",
	"Brightness",
	"ClockTime",
	"ExposureCompensation",
	"FogColor",
	"FogEnd",
}

local TWEEN = TweenInfo.new(PRESETS.TweenTime or 1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--------------------------------------------------
-- 프리셋 적용
--------------------------------------------------

-- 설치 스크립트가 만들어 둔 효과를 찾고, 없으면 내 화면에만 하나 만든다.
local function ensureEffect(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end

	existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end

	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

local function tweenProperties(instance, properties)
	local goal = {}
	local hasAny = false
	for key, value in pairs(properties) do
		goal[key] = value
		hasAny = true
	end
	if not hasAny then
		return
	end

	local ok, err = pcall(function()
		TweenService:Create(instance, TWEEN, goal):Play()
	end)
	if not ok then
		warn("[CursedBarrel] 조명 전환 실패: " .. tostring(err))
	end
end

local function applyPreset(preset)
	local base = {}
	for _, key in ipairs(LIGHTING_KEYS) do
		if preset[key] ~= nil then
			base[key] = preset[key]
		end
	end
	tweenProperties(Lighting, base)

	if preset.Atmosphere then
		tweenProperties(ensureEffect("Atmosphere", "Atmosphere"), preset.Atmosphere)
	end
	if preset.Bloom then
		tweenProperties(ensureEffect("BloomEffect", "Bloom"), preset.Bloom)
	end
	if preset.ColorCorrection then
		tweenProperties(ensureEffect("ColorCorrectionEffect", "ColorCorrection"), preset.ColorCorrection)
	end
end

--------------------------------------------------
-- 지금 어떤 조명이어야 하는가
--------------------------------------------------

local currentMode = nil
local currentTable = nil
local tableCleaner = Utility.Cleaner.new()

local function setMode(mode)
	if currentMode == mode then
		return
	end
	currentMode = mode

	applyPreset(mode == "Game" and PRESETS.Game or PRESETS.Lobby)
	GameConfig.log("조명 전환 → " .. mode)
end

local function refresh()
	local model = currentTable
	if model and not model.Parent then
		model = nil
	end

	local state = model and model:GetAttribute(TABLE_ATTR.State)
	local inGame = state ~= nil and GameConfig.InGameStates[state] == true
	setMode(inGame and "Game" or "Lobby")
end

local function bindTable(model)
	if currentTable == model then
		refresh()
		return
	end

	tableCleaner:clean()
	currentTable = model

	if model then
		tableCleaner:add(model:GetAttributeChangedSignal(TABLE_ATTR.State):Connect(refresh))
		tableCleaner:add(model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				bindTable(nil)
			end
		end))
	end

	refresh()
end

-- 내가 앉은 좌석이 속한 "테이블 모델"을 위로 거슬러 올라가며 찾는다.
local function findTableFromSeat(seatPart)
	if not seatPart then
		return nil
	end

	local node = seatPart.Parent
	while node and node ~= workspace do
		if node:IsA("Model") and CollectionService:HasTag(node, TABLE_TAG) then
			return node
		end
		node = node.Parent
	end
	return nil
end

--------------------------------------------------
-- 내 캐릭터 감시
--------------------------------------------------

local characterCleaner = Utility.Cleaner.new()

local function watchCharacter(character)
	characterCleaner:clean()

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		bindTable(nil)
		return
	end

	local function onSeatChanged()
		bindTable(findTableFromSeat(humanoid.SeatPart))
	end

	characterCleaner:add(humanoid:GetPropertyChangedSignal("SeatPart"):Connect(onSeatChanged))
	characterCleaner:add(humanoid.Died:Connect(function()
		bindTable(nil)
	end))

	onSeatChanged()
end

localPlayer.CharacterAdded:Connect(watchCharacter)
localPlayer.CharacterRemoving:Connect(function()
	characterCleaner:clean()
	bindTable(nil)
end)

if localPlayer.Character then
	task.spawn(watchCharacter, localPlayer.Character)
end

--------------------------------------------------
-- 시작
--------------------------------------------------

if PRESETS.ApplyLobbyOnJoin then
	-- 첫 적용은 트윈 없이 즉시. (접속하자마자 밝은 로비를 보게 된다)
	currentMode = "Lobby"
	for _, key in ipairs(LIGHTING_KEYS) do
		if PRESETS.Lobby[key] ~= nil then
			pcall(function()
				Lighting[key] = PRESETS.Lobby[key]
			end)
		end
	end
	applyPreset(PRESETS.Lobby)
end
