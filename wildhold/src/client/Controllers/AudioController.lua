-- 효과음. AudioConfig 에 사운드 ID 가 있으면 그것을, 없으면 Roblox 기본 내장 사운드를 쓴다.
-- 크기 = AudioConfig.Volume × ⚙ 설정의 효과음 크기 (플레이어 속성 SfxVolume, 0~1)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local C = require(RS.Shared.Config.AudioConfig)

local S = {}
local player = Players.LocalPlayer
-- 내장 소리: {파일, 높낮이, 크기}
local BUILTIN = {
	Attack = {"rbxasset://sounds/swordlunge.wav", 1.1, 0.35},
	Swing = {"rbxasset://sounds/swoosh.wav", 1.2, 0.2},
	Chop = {"rbxasset://sounds/swordlunge.wav", 0.7, 0.35},
	Mine = {"rbxasset://sounds/clickfast.wav", 0.55, 0.5},
	Gather = {"rbxasset://sounds/swoosh.wav", 1.5, 0.25},
	Hurt = {"rbxasset://sounds/uuhhh.mp3", 1, 0.35},
	EnemyDie = {"rbxasset://sounds/splat.wav", 0.9, 0.4},
	Arrow = {"rbxasset://sounds/swordslash.wav", 1.6, 0.25},
	Spikes = {"rbxasset://sounds/snap.wav", 1.2, 0.35},
	Build = {"rbxasset://sounds/clickfast.wav", 0.7, 0.6},
	Upgrade = {"rbxasset://sounds/electronicpingshort.wav", 0.7, 0.5},
	Repair = {"rbxasset://sounds/clickfast.wav", 0.9, 0.45},
	Break = {"rbxasset://sounds/glassbreak.wav", 0.6, 0.4},
	Craft = {"rbxasset://sounds/electronicpingshort.wav", 1.1, 0.4},
	Eat = {"rbxasset://sounds/splat.wav", 1.5, 0.3},
	TrapThrow = {"rbxasset://sounds/swoosh.wav", 0.9, 0.35},
	Capture = {"rbxasset://sounds/electronicpingshort.wav", 1.25, 0.6},
	Secured = {"rbxasset://sounds/electronicpingshort.wav", 0.9, 0.6},
	Fail = {"rbxasset://sounds/snap.wav", 0.8, 0.6},
	Evolve = {"rbxasset://sounds/victory.wav", 1.2, 0.4},
	EggGet = {"rbxasset://sounds/electronicpingshort.wav", 1.4, 0.5},
	Hatch = {"rbxasset://sounds/victory.wav", 1, 0.5},
	Night = {"rbxasset://sounds/swordslash.wav", 0.35, 0.5},
	Dawn = {"rbxasset://sounds/electronicpingshort.wav", 0.8, 0.5},
	Victory = {"rbxasset://sounds/victory.wav", 1, 0.6},
	Defeat = {"rbxasset://sounds/uuhhh.mp3", 0.7, 0.5},
	Click = {"rbxasset://sounds/button.wav", 1, 0.4},
}
local RESOURCE_SOUND = {Wood = "Chop", Stone = "Mine", Scrap = "Mine", Crystal = "Mine"}

function S:Volume()
	local v = player:GetAttribute("SfxVolume")
	return type(v) == "number" and v or 1
end

-- 같은 소리가 한 프레임에 여러 번 겹치지 않게 (화살 여러 발 등)
local lastPlayed = {}
function S:Play(key, position, gap)
	local now = os.clock()
	if now - (lastPlayed[key] or -1) < (gap or 0.05) then return end
	lastPlayed[key] = now
	local scale = self:Volume()
	if scale <= 0 then return end
	local custom = C[key]
	local id, pitch, volume
	if type(custom) == "string" and custom ~= "" then
		id, pitch, volume = custom, 1, C.Volume
	elseif BUILTIN[key] then
		id, pitch, volume = BUILTIN[key][1], BUILTIN[key][2], BUILTIN[key][3] * (C.Volume / 0.35)
	else
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId, sound.Volume, sound.PlaybackSpeed = id, volume * scale, pitch * (0.95 + math.random() * 0.1)
	if typeof(position) == "Vector3" then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = workspace.Terrain
		sound.RollOffMaxDistance = 120
		sound.Parent = holder
		Debris:AddItem(holder, 6)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 6)
	end
	sound:Play()
end

function S:Init(remotes)
	remotes.PetFX.OnClientEvent:Connect(function(kind)
		if kind == "Capture" or kind == "Secured" or kind == "Fail" or kind == "Evolve" then self:Play(kind)
		elseif kind == "Egg" then self:Play("EggGet")
		elseif kind == "Hatched" then task.delay(1.3, function() self:Play("Hatch") end) end
	end)
	remotes.FX.OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "Spear" then
			self:Play("Attack", b)
		elseif kind == "Harvest" then
			self:Play(RESOURCE_SOUND[c] or "Gather", b)
		elseif kind == "Swing" then
			if a == player then self:Play("Swing") end
		elseif kind == "Arrow" then
			self:Play("Arrow", a, 0.12)
		elseif kind == "Spikes" then
			self:Play("Spikes", a, 0.2)
		elseif kind == "EnemyDie" then
			self:Play("EnemyDie", a, 0.08)
		elseif kind == "Build" then
			self:Play((c or 1) > 1 and "Upgrade" or "Build", a)
		elseif kind == "Repair" then
			self:Play("Repair", a)
		elseif kind == "Break" then
			self:Play("Break", a)
		elseif kind == "Craft" then
			self:Play("Craft", a)
		elseif kind == "Eat" then
			self:Play("Eat", a)
		elseif kind == "TrapStart" then
			self:Play("TrapThrow", a)
		elseif kind == "TrapResult" then
			self:Play(b and "Capture" or "Fail", a)
		end
	end)
	remotes.State.OnClientEvent:Connect(function(data)
		if data.Phase ~= self.LastPhase then
			if data.Phase == "Night" then self:Play("Night")
			elseif data.Phase == "Dawn" then self:Play("Dawn")
			elseif data.Phase == "Result" and data.Result then self:Play(data.Result.Won and "Victory" or "Defeat") end
		end
		self.LastPhase = data.Phase
	end)
	-- 내가 맞으면 (0.4초에 한 번)
	local function watch(character)
		local human = character:WaitForChild("Humanoid", 10)
		if not human then return end
		local last = human.Health
		human.HealthChanged:Connect(function(health)
			if health < last - 0.5 then self:Play("Hurt", nil, 0.4) end
			last = health
		end)
	end
	if player.Character then task.spawn(watch, player.Character) end
	player.CharacterAdded:Connect(watch)
	-- 모든 화면 버튼에 딸깍 소리
	local gui = player:WaitForChild("PlayerGui")
	local function hook(obj)
		if obj:IsA("GuiButton") then obj.Activated:Connect(function() self:Play("Click", nil, 0.03) end) end
	end
	for _, obj in ipairs(gui:GetDescendants()) do hook(obj) end
	gui.DescendantAdded:Connect(hook)
end

return S
