--[[
	Sfx  (Phase 12, 클라이언트 전용)
	효과음 한 곳. ReleaseConfig.Audio 에 음원 ID 가 있으면 그것을, 없으면 Roblox 기본 소리를 쓴다.
	음량은 설정의 "효과음" 값을 따른다.

	Sfx.play(kind, { pitch, volume, at = Vector3 (그 자리에서 들리는 소리), range })
	Sfx.loop(kind, volume) → Sound (반복 소리. 음원 ID 가 없으면 nil)
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Release = require(script.Parent.ReleaseConfig)

local Sfx = {}

-- 음원 ID 가 비어 있을 때 대신 쓰는 기본 소리 (Roblox 에 들어 있는 소리)
local FALLBACK = {
	Thunder = { "rbxasset://sounds/impact_explosion_03.mp3", 0.42 },
	Slam = { "rbxasset://sounds/impact_explosion_03.mp3", 0.62 },
	WoodCrack = { "rbxasset://sounds/action_jump_land.mp3", 0.45 },
	Cannon = { "rbxasset://sounds/impact_explosion_03.mp3", 1.15 },
	Splash = { "rbxasset://sounds/impact_water.mp3", 0.9 },
	Hit = { "rbxasset://sounds/action_jump_land.mp3", 0.75 },
	KrakenRoar = { "rbxasset://sounds/impact_explosion_03.mp3", 0.3 },
	Coins = { "rbxasset://sounds/volume_slider.ogg", 1.7 },
	Jackpot = { "rbxasset://sounds/volume_slider.ogg", 1.25 }, -- Phase 21 : jackpot.ogg 를 올리기 전까지
	-- Phase 24 : 버튼 누르는 소리 · 창 여는 소리 (ReleaseConfig.Audio.Click · Open 에 음원을 넣으면 그 소리)
	Click = { "rbxasset://sounds/volume_slider.ogg", 2.3 },
	Open = { "rbxasset://sounds/volume_slider.ogg", 1.35 },
}

local function volumeScale()
	local player = Players.LocalPlayer
	return player and (player:GetAttribute("Setting_sfx") or 0.65) or 0.65
end

local function idOf(kind)
	local id = tonumber(Release.Audio and Release.Audio[kind]) or 0
	if id > 0 then
		return "rbxassetid://" .. id, 1
	end
	local fallback = FALLBACK[kind]
	if fallback then
		return fallback[1], fallback[2]
	end
	return nil, 1
end

function Sfx.play(kind, opts)
	opts = opts or {}
	local soundId, basePitch = idOf(kind)
	if not soundId then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = basePitch * (opts.pitch or 1)
	sound.Volume = (opts.volume or 0.5) * volumeScale()
	local holder
	if opts.at then
		holder = Instance.new("Part")
		holder.Name = "SfxAt"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(opts.at)
		holder.Parent = workspace
		sound.RollOffMaxDistance = opts.range or 260
		sound.RollOffMinDistance = 20
		sound.Parent = holder
		Debris:AddItem(holder, 8)
	else
		sound.Parent = SoundService
	end
	sound:Play()
	Debris:AddItem(sound, 8)
	return sound
end

function Sfx.loop(kind, volume)
	local id = tonumber(Release.Audio and Release.Audio[kind]) or 0
	if id <= 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. id
	sound.Looped = true
	sound.Volume = (volume or 0.4) * volumeScale()
	sound.Parent = SoundService
	return sound
end

Sfx.volumeScale = volumeScale

return Sfx
