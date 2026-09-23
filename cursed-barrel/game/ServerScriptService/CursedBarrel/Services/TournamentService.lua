--[[
	TournamentService  (Phase 12)
	토너먼트 테이블 (TableConfig.Types.Tournament4, GameConfig.TableTypeByName 에서 배정).

	· 토너먼트 테이블에서 연달아 치른 4판의 점수를 더한다. (시리즈)
	    생존(1등) 10 · 2등 6 · 3등 4 · 4등 2 점 + 그 판에 잡은 해적 1번마다 1점 (최대 3)
	    기권승은 점수 절반, 스스로 나간 판은 0점이고 시리즈가 끊긴다.
	· 시리즈를 마치면 점수 × 5 코인, 시즌 최고 점수가 전 서버 순위(OrderedDataStore)에 오른다.
	· 34점 이상이면 "토너먼트 챔피언" 칭호 (업적 tourney34).
	· 테이블 옆 순위판에 이번 시즌 상위 10명이 보인다.
	· AI 선원은 이 테이블에 앉지 않는다. (연습 판은 점수가 없다)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Release = require(Shared:WaitForChild("ReleaseConfig"))

local ProfileService = require(script.Parent.ProfileService)
local TableService = require(script.Parent.TableService)
local RoundService = require(script.Parent.RoundService)

local TOURNEY = GameConfig.Tournament
local PLAYER_ATTR = GameConfig.PlayerAttributes

local TournamentService = {}
TournamentService._started = false
TournamentService.series = {} -- [Player] = { rounds, score, lastAt }
TournamentService.top = {}
TournamentService._store = nil
TournamentService._boards = {}

--------------------------------------------------
-- 점수
--------------------------------------------------

-- 한 판의 등수 : 생존자 1등, 나중에 탈락한 사람일수록 앞 등수. 스스로 나간 사람은 nil.
function TournamentService.placements(info)
	local places = {}
	local nextPlace = 1
	local winner = info.credited or info.halfWinner
	if winner then
		places[winner] = 1
		nextPlace = 2
	end
	local order = info.outOrder or {}
	for index = #order, 1, -1 do
		local player = order[index]
		if places[player] == nil then
			places[player] = nextPlace
			nextPlace += 1
		end
	end
	return places
end

function TournamentService.pointsFor(place, catches, half)
	if not place then
		return 0
	end
	local points = TOURNEY.Placement[place] or TOURNEY.Placement[#TOURNEY.Placement] or 1
	points += math.min(TOURNEY.CatchPointCap, catches or 0) * TOURNEY.CatchPoint
	if half then
		points = math.floor(points * 0.5)
	end
	return points
end

function TournamentService:_publish(player, entry)
	if player.Parent ~= Players then
		return
	end
	player:SetAttribute(PLAYER_ATTR.TourneyRounds, entry and entry.rounds or 0)
	player:SetAttribute(PLAYER_ATTR.TourneyScore, entry and entry.score or 0)
end

function TournamentService:OnSettled(info, now)
	if not TOURNEY.Enabled or info.practice or not info.gameTable or not info.gameTable.config.Tournament then
		return
	end
	now = now or os.clock()
	local places = TournamentService.placements(info)
	for _, player in ipairs(info.roster or {}) do
		if not GameConfig.isBot(player) and player.Parent == Players then
			if info.forfeited and info.forfeited[player] then
				-- 스스로 나갔다 : 시리즈가 끊긴다
				self.series[player] = nil
				self:_publish(player, nil)
			else
				local entry = self.series[player]
				if not entry or now - entry.lastAt > TOURNEY.SeriesTimeout then
					entry = { rounds = 0, score = 0, lastAt = now }
					self.series[player] = entry
				end
				local points = TournamentService.pointsFor(places[player], (info.catches or {})[player], player == info.halfWinner)
				entry.rounds += 1
				entry.score += points
				entry.lastAt = now
				self:_publish(player, entry)
				if entry.rounds >= TOURNEY.SeriesLength then
					self:_finish(player, entry.score)
					self.series[player] = nil
					self:_publish(player, nil)
				end
			end
		end
	end
end

function TournamentService:_finish(player, score)
	ProfileService:Award(player, score * TOURNEY.CoinsPerPoint)
	ProfileService:Bump(player, "bestSeries", 0, score)
	local store = self:_getStore()
	if store then
		task.spawn(function()
			pcall(function()
				store:UpdateAsync(tostring(player.UserId), function(old)
					return math.max(tonumber(old) or 0, score)
				end)
			end)
			self:_pull()
		end)
	end
	local cue = ReplicatedStorage.CursedBarrel.Remotes:FindFirstChild(GameConfig.Remotes.WorldCue)
	if cue then
		cue:FireClient(player, "Tourney", { score = score, coins = score * TOURNEY.CoinsPerPoint })
	end
end

--------------------------------------------------
-- 시즌 순위
--------------------------------------------------

function TournamentService:_getStore()
	if not GameConfig.Ranking.UseDataStore then
		return nil
	end
	if self._store == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(TOURNEY.StoreName .. "_" .. tostring(Release.Season.Id))
		end)
		self._store = ok and store or false
	end
	return self._store or nil
end

function TournamentService:_pull()
	local store = self:_getStore()
	if not store then
		self:_draw()
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, TOURNEY.BoardRows):GetCurrentPage()
	end)
	if ok and page then
		local list = {}
		for index, row in ipairs(page) do
			local userId = tonumber(row.key)
			local name = "선원 " .. tostring(row.key)
			if userId then
				local okName, fetched = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				if okName and fetched then
					name = fetched
				end
			end
			list[index] = { name = name, score = tonumber(row.value) or 0 }
		end
		self.top = list
	end
	self:_draw()
end

--------------------------------------------------
-- 순위판 (토너먼트 테이블 옆)
--------------------------------------------------

function TournamentService:_ensureBoard(gameTable)
	if self._boards[gameTable] or not gameTable.model then
		return
	end
	local top = gameTable.model:FindFirstChild("TableTop", true)
	local center = top and top.Position or gameTable.model:GetPivot().Position
	local side = center.X >= 0 and 1 or -1
	local position = Vector3.new(center.X + side * 21, 5.6, center.Z + 10)
	local board = Instance.new("Part")
	board.Name = "TournamentBoard"
	board.Anchored = true
	board.CanCollide = true
	board.CanQuery = true
	board.CanTouch = false
	board.Size = Vector3.new(10, 7, 0.4)
	board.Color = Color3.fromRGB(42, 28, 20)
	board.Material = Enum.Material.Wood
	board.CFrame = CFrame.lookAt(position, Vector3.new(center.X, 5.6, center.Z))
	board.Parent = gameTable.model.Parent

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local list = Instance.new("TextLabel")
	list.Name = "Rows"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundColor3 = Color3.fromRGB(26, 18, 14)
	list.TextColor3 = Color3.fromRGB(238, 223, 196)
	list.Font = Enum.Font.GothamBold
	list.TextSize = 20
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextWrapped = true
	list.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingTop = UDim.new(0, 12)
	padding.Parent = list
	self._boards[gameTable] = list
end

function TournamentService:_draw()
	local lines = { "🏆 토너먼트 · 시즌 순위 (4판 합계)", "" }
	if #self.top == 0 then
		table.insert(lines, "아직 기록이 없습니다. 4판을 연달아 해 보세요!")
	end
	for index, row in ipairs(self.top) do
		table.insert(lines, ("%2d.  %s   %d점"):format(index, row.name, row.score))
	end
	table.insert(lines, "")
	table.insert(lines, "생존 10 · 2등 6 · 3등 4 · 4등 2 · 잡기 +1 (최대 3)")
	local text = table.concat(lines, "\n")
	for gameTable, label in pairs(self._boards) do
		if gameTable.destroyed or not label.Parent then
			self._boards[gameTable] = nil
		else
			label.Text = text
		end
	end
end

function TournamentService:Start()
	if self._started then
		return
	end
	self._started = true
	if not TOURNEY.Enabled then
		return
	end
	RoundService.RoundSettled:Connect(function(info)
		local ok, err = pcall(self.OnSettled, self, info)
		if not ok then
			warn("[CursedBarrel] 토너먼트 정산 오류: " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.series[player] = nil
	end)
	local function watch(gameTable)
		if gameTable.config.Tournament then
			pcall(self._ensureBoard, self, gameTable)
		end
	end
	TableService.TableAdded:Connect(watch)
	for _, gameTable in ipairs(TableService:GetAllTables()) do
		watch(gameTable)
	end
	task.spawn(function()
		while self._started do
			self:_pull()
			task.wait(GameConfig.Ranking.GlobalRefresh or 90)
		end
	end)
end

return TournamentService
