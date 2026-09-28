-- 효과음. AudioConfig 에 직접 올린 사운드 ID 가 있으면 그것을, 없으면 Roblox 기본 내장 사운드를 쓴다.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local C = require(RS.Shared.Config.AudioConfig)

local S = {}
local BUILTIN = {
	Attack = {"rbxasset://sounds/swordlunge.wav", 1.1, 0.35},
	Arrow = {"rbxasset://sounds/swordslash.wav", 1.6, 0.25},
	Capture = {"rbxasset://sounds/electronicpingshort.wav", 1.25, 0.6},
	Secured = {"rbxasset://sounds/electronicpingshort.wav", 0.9, 0.6},
	Fail = {"rbxasset://sounds/snap.wav", 0.8, 0.6},
	Build = {"rbxasset://sounds/clickfast.wav", 0.7, 0.6},
	Click = {"rbxasset://sounds/button.wav", 1, 0.4},
	Night = {"rbxasset://sounds/swordslash.wav", 0.35, 0.5},
}

function S:Play(key, position)
	if Players.LocalPlayer:GetAttribute("MutePets") then return end
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
	sound.SoundId, sound.Volume, sound.PlaybackSpeed = id, volume, pitch * (0.95 + math.random() * 0.1)
	if position then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = workspace.Terrain
		sound.RollOffMaxDistance = 120
		sound.Parent = holder
		Debris:AddItem(holder, 4)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 4)
	end
	sound:Play()
end

function S:Init(remotes)
	remotes.PetFX.OnClientEvent:Connect(function(kind)
		if kind == "Capture" or kind == "Secured" or kind == "Fail" then self:Play(kind) end
	end)
	remotes.FX.OnClientEvent:Connect(function(kind, a, b)
		if kind == "Spear" or kind == "Harvest" then
			self:Play("Attack", a)
		elseif kind == "Arrow" then
			self:Play("Arrow", a)
		elseif kind == "Build" or kind == "Repair" then
			self:Play("Build", a)
		elseif kind == "TrapResult" then
			self:Play(b and "Capture" or "Fail", a)
		end
	end)
	remotes.State.OnClientEvent:Connect(function(data)
		if data.Phase == "Night" and self.LastPhase ~= "Night" then self:Play("Night") end
		self.LastPhase = data.Phase
	end)
end

return S
