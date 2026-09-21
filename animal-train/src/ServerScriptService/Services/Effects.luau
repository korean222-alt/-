-- 연출 담당 : 파티클, 소리, 별 튀어오르기.
-- 클라이언트에서 처리할 것은 Effect 리모트로 신호만 보냅니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))

local Effects = {}
local remote

function Effects.toPlayer(player, kind, payload)
	if remote and player and player.Parent then
		remote:FireClient(player, kind, payload or {})
	end
end

function Effects.toAll(kind, payload)
	if remote then
		remote:FireAllClients(kind, payload or {})
	end
end

-- 그 자리에서 들리는 소리 (근처 사람 모두 들림)
function Effects.sound3d(position: Vector3, name: string, pitchJitter: number?)
	local def = Config.Sounds[name]
	if not def or def.Id == "" then
		return
	end
	local anchor = ModelFactory.newPart({
		Name = "SoundAnchor",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
	})
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume or 0.5
	local pitch = def.Pitch or 1
	if pitchJitter then
		pitch += (math.random() - 0.5) * 2 * pitchJitter
	end
	sound.PlaybackSpeed = math.max(0.25, pitch)
	sound.RollOffMaxDistance = 90
	sound.RollOffMinDistance = 8
	sound.PlayOnRemove = true -- 지우는 순간 그 자리에서 재생됩니다
	sound.Parent = anchor
	sound:Destroy()

	task.delay(4, function()
		anchor:Destroy()
	end)
end

function Effects.hearts(position: Vector3)
	ModelFactory.burst(position, Config.Colors.Pink, 12)
end

function Effects.starBurst(position: Vector3)
	ModelFactory.burst(position, Config.Colors.Star, 18)
end

function Effects.fireworks(position: Vector3)
	for index = 1, 4 do
		task.delay((index - 1) * 0.16, function()
			local offset = Vector3.new(math.random(-8, 8), math.random(4, 11), math.random(-4, 4))
			ModelFactory.burst(position + offset, Color3.fromHSV(math.random(), 0.55, 1), 26)
		end)
	end
end

-- 머리 위로 별이 통통 튀어 오르는 연출 (5단계)
function Effects.starPop(character: Model)
	local head = character:FindFirstChild("Head") or character.PrimaryPart
	if not head then
		return
	end
	local star = ModelFactory.buildStar()
	star.Name = "PopStar"
	local startCFrame = CFrame.new(head.Position + Vector3.new(math.random(-1, 1), 1.6, 0))
	star:PivotTo(startCFrame)
	star.Parent = workspace

	task.spawn(function()
		local duration = 0.85
		local startedAt = os.clock()
		while true do
			local alpha = (os.clock() - startedAt) / duration
			if alpha >= 1 or not star.Parent then
				break
			end
			local height = math.sin(alpha * math.pi) * 5.5 + alpha * 1.5
			star:PivotTo(
				startCFrame
					* CFrame.new(0, height, 0)
					* CFrame.Angles(0, alpha * math.pi * 3, alpha * math.pi)
			)
			for _, piece in ipairs(star:GetChildren()) do
				if piece:IsA("BasePart") then
					piece.Transparency = math.max(0, (alpha - 0.6) / 0.4)
				end
			end
			task.wait()
		end
		star:Destroy()
	end)
end

function Effects.Start()
	remote = Net.event(Config.Remotes.Effect)
end

return Effects
