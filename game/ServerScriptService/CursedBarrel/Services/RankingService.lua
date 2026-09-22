--[[
	RankingService  (Phase 3 · Phase 7 에서 전 서버 랭킹이 붙는다)
	누가 몇 번 이겼는지 세고, 로비의 랭킹판에 그려 넣는다.

	두 가지를 보여준다.
	  · 이 서버 순위   — 지금 이 서버에서 벌어진 일. 바로바로 갱신된다.
	  · 전체 순위      — OrderedDataStore 에 쌓인 모든 서버의 기록. 90초마다 다시 읽는다.

	기록 자체는 ProfileService 가 맡는다. 여기서는 세고 그리기만 한다.
	(Phase 3 에서는 이 파일이 직접 DataStore 에 썼는데, 승자만 저장되고 충돌에도 약했다)
]]

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local ProfileService = require(script.Parent.ProfileService)

local RANKING = GameConfig.Ranking
local BOARD_TAG = GameConfig.Tags.RankingBoard
local PLAYER_ATTR = GameConfig.PlayerAttributes

local PALETTE = {
	Panel = Color3.fromRGB(30, 21, 16),
	PanelLight = Color3.fromRGB(58, 40, 27),
	Gold = Color3.fromRGB(226, 178, 86),
	Cream = Color3.fromRGB(238, 223, 196),
	Dim = Color3.fromRGB(150, 138, 118),
	Flame = Color3.fromRGB(255, 146, 70),
	RowEven = Color3.fromRGB(44, 31, 23),
	RowOdd = Color3.fromRGB(36, 25, 19),
}

local RankingService = {}
RankingService._stats = {} -- [userId] = { name, wins, games, streak, order }
RankingService._global = {} -- 전 서버 상위 목록
RankingService._boards = {}
RankingService._cleaner = Utility.Cleaner.new()
RankingService._started = false
RankingService._orderCounter = 0
RankingService._ordered = nil
RankingService._refreshQueued = false

--------------------------------------------------
-- 이 서버 기록
--------------------------------------------------

local function entryFor(self, player)
	local entry = self._stats[player.UserId]
	if not entry then
		self._orderCounter += 1
		entry = { name = player.DisplayName or player.Name, wins = 0, games = 0, streak = 0, order = self._orderCounter }
		self._stats[player.UserId] = entry
	end
	entry.name = player.DisplayName or player.Name
	return entry
end

-- 라운드가 끝날 때 RoundService 가 부른다. (ProfileService 다음에 불린다)
function RankingService:RecordRound(gameTable, roster, winner)
	for _, player in ipairs(roster or {}) do
		if player and player.Parent == Players then
			local entry = entryFor(self, player)
			entry.games += 1
			entry.streak = player:GetAttribute(PLAYER_ATTR.Streak) or 0
		end
	end

	if winner and winner.Parent == Players then
		local entry = entryFor(self, winner)
		entry.wins += 1
		entry.streak = winner:GetAttribute(PLAYER_ATTR.Streak) or 0
		self:_publishGlobal(winner)
		GameConfig.log(("랭킹 기록 · %s 승리 %d회 (%s)")
			:format(winner.Name, entry.wins, tostring(gameTable and gameTable.tableId)))
	end

	self:Refresh()
end

-- 승리 순 → 판수 적은 순 → 먼저 들어온 순
function RankingService:GetTop(count)
	local list = {}
	for userId, entry in pairs(self._stats) do
		table.insert(list, {
			userId = userId,
			name = entry.name,
			wins = entry.wins,
			games = entry.games,
			streak = entry.streak or 0,
			order = entry.order,
		})
	end

	table.sort(list, function(a, b)
		if a.wins ~= b.wins then
			return a.wins > b.wins
		end
		if a.games ~= b.games then
			return a.games < b.games
		end
		return a.order < b.order
	end)

	local top = {}
	for index = 1, math.min(count or RANKING.Rows, #list) do
		top[index] = list[index]
	end
	return top
end

--------------------------------------------------
-- 전 서버 랭킹 (OrderedDataStore)
--------------------------------------------------

function RankingService:_getOrdered()
	if not RANKING.UseDataStore then
		return nil
	end
	if self._ordered == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(RANKING.OrderedStoreName)
		end)
		self._ordered = ok and store or false
		if not ok then
			warn("[CursedBarrel] 전체 순위를 열 수 없어 이 서버 순위만 보여줍니다.")
		end
	end
	return self._ordered or nil
end

-- 우승한 사람의 누적 승수를 전체 순위에 올린다.
function RankingService:_publishGlobal(player)
	local store = self:_getOrdered()
	if not store then
		return
	end
	local profile = ProfileService:Get(player)
	local wins = profile and profile.wins or player:GetAttribute(PLAYER_ATTR.Wins) or 0

	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(tostring(player.UserId), math.floor(wins))
		end)
		if not ok then
			warn("[CursedBarrel] 전체 순위 기록 실패: " .. tostring(err))
		end
	end)
end

function RankingService:_pullGlobal()
	local store = self:_getOrdered()
	if not store then
		return
	end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, RANKING.GlobalRows)
	end)
	if not ok then
		return
	end

	local ok2, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 then
		return
	end

	local list = {}
	for index, row in ipairs(page) do
		local userId = tonumber(row.key)
		local name = "플레이어 " .. tostring(row.key)
		if userId then
			-- 이름은 캐시가 있으면 바로 오고, 없으면 한 번만 물어본다.
			local okName, fetched = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if okName and fetched then
				name = fetched
			end
		end
		list[index] = { userId = userId or 0, name = name, wins = tonumber(row.value) or 0 }
	end

	self._global = list
	self:Refresh()
end

--------------------------------------------------
-- 랭킹판 그리기
--------------------------------------------------

local function makeLabel(parent, name, text, color, size, order)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.LayoutOrder = order or 0
	label.Parent = parent
	return label
end

local function ensureBoardGui(board)
	local gui = board:FindFirstChild("RankingGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "RankingGui"
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.PixelsPerStud = 50
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = board
	end

	local panel = gui:FindFirstChild("Panel")
	if not panel then
		panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.Size = UDim2.fromScale(1, 1)
		panel.BackgroundColor3 = PALETTE.Panel
		panel.BackgroundTransparency = 0.05
		panel.BorderSizePixel = 0
		panel.Parent = gui

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.05, 0)
		padding.PaddingBottom = UDim.new(0.05, 0)
		padding.PaddingLeft = UDim.new(0.05, 0)
		padding.PaddingRight = UDim.new(0.05, 0)
		padding.Parent = panel
	end

	local title = panel:FindFirstChild("Title")
	if not title then
		title = makeLabel(panel, "Title", "명예의 전당", PALETTE.Gold, UDim2.fromScale(1, 0.13), 0)
		title.Position = UDim2.fromScale(0, 0)
		title.TextXAlignment = Enum.TextXAlignment.Center
	end

	local subtitle = panel:FindFirstChild("Subtitle")
	if not subtitle then
		subtitle = makeLabel(panel, "Subtitle", "", PALETTE.Dim, UDim2.fromScale(1, 0.07), 0)
		subtitle.Position = UDim2.fromScale(0, 0.135)
		subtitle.Font = Enum.Font.GothamMedium
		subtitle.TextXAlignment = Enum.TextXAlignment.Center
	end

	local rows = panel:FindFirstChild("Rows")
	if not rows then
		rows = Instance.new("Frame")
		rows.Name = "Rows"
		rows.BackgroundTransparency = 1
		rows.Position = UDim2.fromScale(0, 0.22)
		rows.Size = UDim2.fromScale(1, 0.72)
		rows.Parent = panel

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0.012, 0)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = rows
	end

	local footer = panel:FindFirstChild("Footer")
	if not footer then
		footer = makeLabel(panel, "Footer", "", PALETTE.Dim, UDim2.fromScale(1, 0.055), 0)
		footer.Position = UDim2.fromScale(0, 0.945)
		footer.Font = Enum.Font.GothamMedium
		footer.TextXAlignment = Enum.TextXAlignment.Center
	end

	return rows, footer, subtitle
end

local function buildRow(rows, index, text, wins, highlight, streak)
	local row = rows:FindFirstChild("Row_" .. index)
	if not row then
		row = Instance.new("Frame")
		row.Name = "Row_" .. index
		row.Size = UDim2.fromScale(1, 0.092)
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Parent = rows

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = row

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.02, 0)
		padding.PaddingRight = UDim.new(0.02, 0)
		padding.Parent = row

		local playerName = makeLabel(row, "PlayerName", "", PALETTE.Cream, UDim2.fromScale(0.58, 0.8), 0)
		playerName.Position = UDim2.fromScale(0, 0.1)

		local flame = makeLabel(row, "Streak", "", PALETTE.Flame, UDim2.fromScale(0.16, 0.8), 0)
		flame.Position = UDim2.fromScale(0.58, 0.1)
		flame.TextXAlignment = Enum.TextXAlignment.Center

		local score = makeLabel(row, "Score", "", PALETTE.Gold, UDim2.fromScale(0.24, 0.8), 0)
		score.Position = UDim2.fromScale(0.76, 0.1)
		score.TextXAlignment = Enum.TextXAlignment.Right
	end

	row.BackgroundColor3 = (index % 2 == 0) and PALETTE.RowEven or PALETTE.RowOdd
	row.BackgroundTransparency = 0.15

	local nameLabel = row:FindFirstChild("PlayerName")
	local scoreLabel = row:FindFirstChild("Score")
	local streakLabel = row:FindFirstChild("Streak")
	if nameLabel then
		nameLabel.Text = text
		nameLabel.TextColor3 = highlight and PALETTE.Gold or PALETTE.Cream
	end
	if scoreLabel then
		scoreLabel.Text = wins
	end
	if streakLabel then
		streakLabel.Text = (streak and streak >= GameConfig.Streak.MinToShow) and ("🔥 " .. streak) or ""
	end

	return row
end

function RankingService:Refresh()
	local useGlobal = #self._global > 0
	local top = useGlobal and self._global or self:GetTop(RANKING.Rows)

	for board in pairs(self._boards) do
		if board.Parent then
			local ok, err = pcall(function()
				local rows, footer, subtitle = ensureBoardGui(board)

				subtitle.Text = useGlobal and "저주받은 통 · 전체 서버 승리 순위" or "저주받은 통 · 이 서버 승리 순위"

				for index = 1, RANKING.Rows do
					local entry = top[index]
					if entry then
						buildRow(
							rows,
							index,
							("%d위   %s"):format(index, entry.name),
							entry.games and ("%d승 / %d판"):format(entry.wins, entry.games) or ("%d승"):format(entry.wins),
							index <= 3,
							entry.streak
						)
					else
						local row = rows:FindFirstChild("Row_" .. index)
						if row then
							row:Destroy()
						end
					end
				end

				if #top == 0 then
					buildRow(rows, 1, "아직 승자가 없습니다", "0승 / 0판", false, 0)
				end

				footer.Text = ("접속 %d명 · 불꽃 숫자는 현재 연승"):format(#Players:GetPlayers())
			end)

			if not ok then
				warn("[CursedBarrel] 랭킹판 갱신 중 오류: " .. tostring(err))
			end
		else
			self._boards[board] = nil
		end
	end
end

--------------------------------------------------
-- 시작
--------------------------------------------------

function RankingService:_registerBoard(board)
	if not board:IsA("BasePart") then
		return
	end
	self._boards[board] = true
	self:Refresh()
end

function RankingService:Start()
	if self._started then
		return
	end
	self._started = true

	for _, board in ipairs(CollectionService:GetTagged(BOARD_TAG)) do
		self:_registerBoard(board)
	end

	self._cleaner:add(CollectionService:GetInstanceAddedSignal(BOARD_TAG):Connect(function(board)
		self:_registerBoard(board)
	end))

	self._cleaner:add(CollectionService:GetInstanceRemovedSignal(BOARD_TAG):Connect(function(board)
		self._boards[board] = nil
	end))

	-- 저장된 승수를 읽어 이 서버 순위의 출발점으로 삼는다.
	-- ProfileChanged 는 코인이 오를 때마다 오므로, 판을 다시 그리는 것은 한 박자 묶는다.
	self._cleaner:add(ProfileService.ProfileChanged:Connect(function(player, profile)
		local entry = entryFor(self, player)
		entry.wins = math.max(entry.wins, profile.wins)
		entry.games = math.max(entry.games, profile.games)
		entry.streak = profile.streak

		if not self._refreshQueued then
			self._refreshQueued = true
			task.delay(1, function()
				self._refreshQueued = false
				self:Refresh()
			end)
		end
	end))

	self._cleaner:add(Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:Refresh()
		end)
	end))

	self:Refresh()

	-- 전체 순위를 주기적으로 읽는다.
	task.spawn(function()
		while true do
			self:_pullGlobal()
			task.wait(RANKING.GlobalRefresh)
		end
	end)

	local count = 0
	for _ in pairs(self._boards) do
		count += 1
	end
	GameConfig.log(("RankingService 시작 완료 · 랭킹판 %d개"):format(count))
end

return RankingService
