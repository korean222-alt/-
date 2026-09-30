-- 배경음악 + 주변 소리. 지금 상황(로비 / 낮 / 해 질 녘 / 밤 / 마지막 밤 / 클리어 / 실패)에 맞는 곡을 겹쳐 바꾼다.
-- 곡 목록은 AudioConfig.Music (비어 있으면 조용히). 크기 = AudioConfig.MusicVolume × ⚙ 설정의 음악 크기 (속성 MusicVolume)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local C = require(RS.Shared.Config.AudioConfig)
local G = require(RS.Shared.Config.GameConfig)

local M = {}
local player = Players.LocalPlayer
local ONCE = {Victory = true, Defeat = true} -- 한 번만 틀고 멈춘다

local function list(value)
	if type(value) == "string" then return value ~= "" and {value} or {} end
	local out = {}
	for _, id in ipairs(value or {}) do if type(id) == "string" and id ~= "" then table.insert(out, id) end end
	return out
end

function M:Scale()
	local v = player:GetAttribute("MusicVolume")
	return type(v) == "number" and v or 1
end

-- 지금 틀어야 할 음악 상황
function M:Mood()
	if (player:GetAttribute("Place") or "Expedition") == "Lobby" then return "Lobby" end
	local d = self.Data
	if not d then return "Lobby" end
	if d.Phase == "Night" then return (d.Night or 0) >= (d.Target or G.TargetNights) and "FinalNight" or "Night" end
	if d.Phase == "Result" and d.Result then return d.Result.Won and "Victory" or "Defeat" end
	if d.Phase == "Day" and d.EndsAt and d.EndsAt - workspace:GetServerTimeNow() <= G.WarningSeconds then return "Dusk" end
	if d.Phase == "Waiting" then return "Lobby" end
	return "Day"
end

function M:AmbienceMood()
	if (player:GetAttribute("Place") or "Expedition") == "Lobby" then return "Lobby" end
	local d = self.Data
	return (d and (d.Phase == "Night" or d.Phase == "Dawn")) and "Night" or "Day"
end

-- 소리 하나를 서서히 줄여서 없앤다
local function fadeOut(sound, seconds)
	if not sound then return end
	local tween = TweenService:Create(sound, TweenInfo.new(seconds), {Volume = 0})
	tween:Play()
	task.delay(seconds + 0.1, function() if sound.Parent then sound:Stop(); sound:Destroy() end end)
end

function M:Start(mood)
	self.Playing, self.Index = mood, 0
	fadeOut(self.Current, C.MusicFade)
	self.Current = nil
	self:Next()
end

-- 목록의 다음 곡 (끝나면 또 다음 곡)
function M:Next()
	local tracks = list(C.Music[self.Playing])
	if #tracks == 0 then return end
	self.Index = self.Index % #tracks + 1
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. self.Playing
	sound.SoundId = tracks[self.Index]
	sound.Looped = #tracks == 1 and not ONCE[self.Playing]
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(C.MusicFade), {Volume = C.MusicVolume * self:Scale()}):Play()
	self.Current = sound
	local mood = self.Playing
	sound.Ended:Connect(function()
		if self.Current == sound and self.Playing == mood and not ONCE[mood] then
			sound:Destroy()
			self.Current = nil
			self:Next()
		end
	end)
end

function M:SetAmbience(mood)
	self.AmbienceKey = mood
	fadeOut(self.Ambience, C.MusicFade)
	self.Ambience = nil
	local id = C.Ambience and C.Ambience[mood]
	if type(id) ~= "string" or id == "" then return end
	local sound = Instance.new("Sound")
	sound.Name, sound.SoundId, sound.Looped, sound.Volume = "Ambience_" .. mood, id, true, 0
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(C.MusicFade), {Volume = C.AmbienceVolume * self:Scale()}):Play()
	self.Ambience = sound
end

function M:Update()
	local mood = self:Mood()
	if mood ~= self.Playing then self:Start(mood) end
	local ambience = self:AmbienceMood()
	if ambience ~= self.AmbienceKey then self:SetAmbience(ambience) end
end

function M:ApplyVolume()
	if self.Current then self.Current.Volume = C.MusicVolume * self:Scale() end
	if self.Ambience then self.Ambience.Volume = C.AmbienceVolume * self:Scale() end
end

function M:Init(remotes)
	remotes.State.OnClientEvent:Connect(function(data)
		self.Data = data
		self:Update()
	end)
	player:GetAttributeChangedSignal("Place"):Connect(function() self:Update() end)
	player:GetAttributeChangedSignal("MusicVolume"):Connect(function() self:ApplyVolume() end)
	-- 해 질 녘은 시간으로 바뀌므로 가끔 다시 본다
	task.spawn(function()
		while true do
			task.wait(1)
			self:Update()
		end
	end)
	self:Update()
end

return M
