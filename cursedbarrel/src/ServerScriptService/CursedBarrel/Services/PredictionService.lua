--[[
	PredictionService  (Phase 12)
	관전 예측 : 판을 구경하는 사람이 "누가 마지막까지 살아남을까"를 고른다. 맞히면 코인.

	· 로벅스나 코인을 거는 도박이 아니다. 걸지 않고 고르기만 한다. 맞히면 서버가 코인을 준다.
	· 그 판에 참가한 사람은 고를 수 없다. 한 판에 한 번만 고른다.
	· 판 초반(한 바퀴 돌기 전, 테이블 PredictOpen)에만 받는다. 결과가 뻔해진 뒤에는 받지 않는다.
	· 하루에 보상을 받는 적중 횟수에 상한이 있다. (GameConfig.Prediction.DailyCap)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local ProfileService = require(script.Parent.ProfileService)
local TableService = require(script.Parent.TableService)
local RoundService = require(script.Parent.RoundService)

local PREDICT = GameConfig.Prediction
local STATES = GameConfig.States
local TABLE_ATTR = GameConfig.TableAttributes

local PredictionService = {}
PredictionService._started = false
PredictionService.byTable = {} -- [GameTable] = { roundId, picks = { [Player] = userId } }
PredictionService._remote = nil

local function remote(name)
	local folder = ReplicatedStorage.CursedBarrel:WaitForChild(GameConfig.Remotes.Folder)
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r
end

function PredictionService:_reply(player, data)
	if self._remote and player.Parent == Players then
		self._remote:FireClient(player, data)
	end
end

-- 통과하면 nil, 막히면 이유
function PredictionService:Validate(player, gameTable, round, targetUserId)
	if not PREDICT.Enabled then
		return "지금은 예측을 받지 않습니다"
	end
	if not gameTable or not round then
		return "테이블을 찾을 수 없습니다"
	end
	local state = gameTable.state
	if (state ~= STATES.Starting and state ~= STATES.Playing) or gameTable.model:GetAttribute(TABLE_ATTR.PredictOpen) ~= true then
		return "예측 시간이 지났습니다"
	end
	if round.isParticipant[player] or gameTable:HasPlayer(player) then
		return "참가 중인 판은 예측할 수 없습니다"
	end
	if typeof(targetUserId) ~= "number" or targetUserId ~= targetUserId then
		return "고를 사람을 다시 누르세요"
	end
	local found = false
	for _, participant in ipairs(round.participants) do
		if participant.UserId == targetUserId then
			found = true
		end
	end
	if not found then
		return "지금 살아 있는 참가자를 고르세요"
	end
	local entry = self.byTable[gameTable]
	if entry and entry.roundId == round.roundId and entry.picks[player] then
		return "이 판은 이미 예측했습니다"
	end
	return nil
end

function PredictionService:Predict(player, tableModel, targetUserId)
	local gameTable = typeof(tableModel) == "Instance" and TableService:GetTableFromModel(tableModel) or nil
	local round = gameTable and RoundService:GetRound(gameTable)
	local why = self:Validate(player, gameTable, round, targetUserId)
	if why then
		self:_reply(player, { kind = "deny", message = why })
		return false
	end
	local entry = self.byTable[gameTable]
	if not entry or entry.roundId ~= round.roundId then
		entry = { roundId = round.roundId, picks = {} }
		self.byTable[gameTable] = entry
	end
	entry.picks[player] = targetUserId
	local name = ""
	for _, participant in ipairs(round.participants) do
		if participant.UserId == targetUserId then
			name = participant.DisplayName or participant.Name
		end
	end
	self:_reply(player, { kind = "ok", table = tableModel, userId = targetUserId, name = name })
	return true
end

-- 판이 끝났다 (RoundService.RoundSettled)
function PredictionService:OnSettled(info)
	local entry = self.byTable[info.gameTable]
	if not entry or entry.roundId ~= info.roundId then
		return
	end
	self.byTable[info.gameTable] = nil
	-- Phase 24 : 무효 판(진행 없이 상대가 전부 나간 기권승)은 예측을 정산하지 않는다.
	local winnerId = (not info.noContest) and info.winner and info.winner.UserId or 0
	local count = #(info.roster or {})
	local coins = math.min(PREDICT.MaxCoins, PREDICT.BaseCoins + PREDICT.PerPlayer * count)
	for player, pick in pairs(entry.picks) do
		if player.Parent == Players then
			if winnerId ~= 0 and pick == winnerId then
				local profile = ProfileService:Get(player)
				local paid = 0
				if profile then
					local today = Utility.today()
					if profile.predictDay ~= today then
						profile.predictDay = today
						profile.predictCount = 0
					end
					if (profile.predictCount or 0) < PREDICT.DailyCap then
						profile.predictCount = (profile.predictCount or 0) + 1
						paid = coins
					end
				end
				ProfileService:Award(player, paid, "predictWins")
				self:_reply(player, { kind = "result", correct = true, coins = paid, name = info.winner.DisplayName or info.winner.Name })
			else
				self:_reply(player, { kind = "result", correct = false, name = info.winner and (info.winner.DisplayName or info.winner.Name) or "" })
			end
		end
	end
end

function PredictionService:Start()
	if self._started then
		return
	end
	self._started = true
	self._remote = remote(GameConfig.Remotes.Predict)
	local limiter = Utility.RateLimiter.new(0.4)
	self._remote.OnServerEvent:Connect(function(player, tableModel, targetUserId)
		if not limiter:check(player.UserId) then
			return
		end
		local ok, err = pcall(self.Predict, self, player, tableModel, targetUserId)
		if not ok then
			warn("[CursedBarrel] 예측 처리 오류: " .. tostring(err))
		end
	end)
	RoundService.RoundSettled:Connect(function(info)
		local ok, err = pcall(self.OnSettled, self, info)
		if not ok then
			warn("[CursedBarrel] 예측 정산 오류: " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player.UserId)
		for _, entry in pairs(self.byTable) do
			entry.picks[player] = nil
		end
	end)
end

return PredictionService
