-- 내 상태(별, 기차 칸, 도감, 업그레이드)를 클라이언트로 보냅니다.
-- 클라이언트는 화면 표시만 하고, 값은 전부 서버가 정합니다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Net = require(Shared:WaitForChild("Net"))
local DataService = require(script.Parent.DataService)
local AnimalService = require(script.Parent.AnimalService)

local StateService = {}

local stateRemote
local dirty = {}

local function buildState(player)
	local data = DataService.get(player)
	if not data then
		return {
			loaded = false,
			stars = 0,
			total = 0,
			train = AnimalService.trainLength(player),
			maxTrain = Config.Train.BaseMaxLength,
			dex = {},
			islands = { [Config.StartIsland] = true },
			upgrades = { Speed = 0, Train = 0, Magnet = 0 },
			music = true,
			canSave = false,
		}
	end

	return {
		loaded = true,
		stars = data.stars,
		total = data.totalStars,
		train = AnimalService.trainLength(player),
		maxTrain = Rules.maxTrain(data.upgrades.Train or 0),
		dex = data.dex,
		islands = data.islands,
		upgrades = data.upgrades,
		bestTrain = data.bestTrain,
		music = data.prefs.music ~= false,
		canSave = DataService.canSave(player),
	}
end

function StateService.push(player)
	if not stateRemote or not player.Parent then
		return
	end
	stateRemote:FireClient(player, buildState(player))
end

function StateService.markDirty(player)
	dirty[player] = true
end

function StateService.Start()
	stateRemote = Net.event(Config.Remotes.StateUpdate)
	local requestRemote = Net.event(Config.Remotes.RequestState)
	local prefRemote = Net.event(Config.Remotes.SetPref)

	requestRemote.OnServerEvent:Connect(function(player)
		StateService.push(player)
	end)

	prefRemote.OnServerEvent:Connect(function(player, key, value)
		-- 클라이언트가 보낸 값은 음악 설정만 받습니다
		if key == "music" and type(value) == "boolean" then
			DataService.setPref(player, key, value)
		end
	end)

	DataService.onChanged(StateService.markDirty)
	AnimalService.onTrainChanged(StateService.markDirty)

	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)

	-- 바뀐 사람만 0.1초마다 갱신 (네트워크 절약)
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < 0.1 then
			return
		end
		clock = 0
		for player in pairs(dirty) do
			dirty[player] = nil
			if player.Parent then
				StateService.push(player)
			end
		end
	end)

	if Config.Debug then
		print("[상태] 시작")
	end
end

return StateService
