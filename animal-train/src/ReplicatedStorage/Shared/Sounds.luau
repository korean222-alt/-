-- 소리 재생 담당 (클라이언트 전용).
-- 파일을 못 찾아도 게임이 멈추지 않도록 전부 pcall 로 감쌉니다.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sounds = {}

local group: SoundGroup? = nil

local function getGroup()
	if group and group.Parent then
		return group
	end
	local made = Instance.new("SoundGroup")
	made.Name = "AnimalTrainSfx"
	made.Volume = 1
	made.Parent = SoundService
	group = made
	return made
end

-- name: Config.Sounds 의 키. pitchJitter: 음높이를 조금씩 흔들어 지겹지 않게.
function Sounds.play(name: string, pitchJitter: number?)
	local def = Config.Sounds[name]
	if not def or def.Id == "" then
		return
	end

	local ok = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = def.Id
		sound.Volume = def.Volume or 0.5
		local pitch = def.Pitch or 1
		if pitchJitter and pitchJitter > 0 then
			pitch += (math.random() - 0.5) * 2 * pitchJitter
		end
		sound.PlaybackSpeed = math.max(0.25, pitch)
		sound.SoundGroup = getGroup()
		sound.Parent = getGroup()
		sound:Play()
		task.delay(5, function()
			sound:Destroy()
		end)
	end)
	return ok
end

-- 같은 소리를 살짝 시간차로 여러 번 (축하 연출용)
function Sounds.playTimes(name: string, count: number, gap: number)
	for index = 1, count do
		task.delay((index - 1) * gap, function()
			Sounds.play(name, 0.08)
		end)
	end
end

return Sounds
