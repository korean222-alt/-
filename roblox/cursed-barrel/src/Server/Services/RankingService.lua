--[[
	RankingService  (Phase 3)
	누가 몇 번 이겼는지 세고, 로비의 랭킹판에 그려 넣는다.

	- 기록은 서버가 한다. 클라이언트는 만들어진 글자를 보기만 한다.
	- 랭킹판은 CollectionService 태그(CursedBarrel_RankingBoard)로 찾는다.
	  판을 복제해서 여러 개 놓아도 전부 같은 내용으로 갱신된다.
	- 기본은 "이 서버가 켜져 있는 동안"의 기록이다.
	  서버를 껐다 켜도 남기고 싶으면 GameConfig.Ranking.UseDataStore 를 true 로 바꾼다.
	  (Studio 에서는 '게임 설정 > 보안 > Studio의 API 서비스 접근 허용'이 필요하다.
	   꺼져 있어도 저장만 조용히 건너뛰고 게임은 그대로 돌아간다.)
]]

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local RANKING = GameConfig.Ranking
local BOARD_TAG = GameConfig.Tags.RankingBoard

local PALETTE = {
	Panel = Color3.fromRGB(30, 21, 16),
	PanelLight = Color3.fromRGB(58, 40, 27),
	Gold = Color3.fromRGB(226, 178, 86),
	Cream = Color3.fromRGB(238, 223, 196),
	Dim = Color3.fromRGB(150, 138, 118),
	RowEven = Color3.fromRGB(44, 31, 23),
	RowOdd = Color3.fromRGB(36, 25, 19),
}

local RankingService = {}
RankingService._stats = {} -- [userId] = { name = string, wins = number, games = number, order = number }
RankingService._boards = {} -- [Part] = true
RankingService._cleaner = Utility.Cleaner.new()
RankingService._started = false
RankingService._orderCounter = 0
RankingService._store = nil

--------------------------------------------------
-- 기록
--------------------------------------------------

local function entryFor(self, player)
	local entry = self._stats[player.UserId]
	if not entry then
		self._orderCounter += 1
		entry = { name = player.DisplayName or player.Name, wins = 0, games = 0, order = self._orderCounter }
		self._stats[player.UserId] = entry
	end
	entry.name = player.DisplayName or player.Name
	return entry
end

local function updateLeaderstats(player, wins)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	local value = stats:FindFirstChild(RANKING.LeaderstatsName)
	if not value then
		value = Instance.new("IntValue")
		value.Name = RANKING.LeaderstatsName
		value.Parent = stats
	end

	value.Value = wins
end

-- 라운드가 끝날 때 RoundService 가 부른다.
--   roster : 이번 라운드를 시작한 전체 명단
--   winner : 마지막 생존자 (없으면 nil)
function RankingService:RecordRound(gameTable, roster, winner)
	for _, player in ipairs(roster or {}) do
		if player and player.Parent == Players then
			local entry = entryFor(self, player)
			entry.games += 1
		end
	end

	if winner and winner.Parent == Players then
		local entry = entryFor(self, winner)
		entry.wins += 1
		updateLeaderstats(winner, entry.wins)
		self:_save(winner.UserId, entry)
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

-- 판 하나에 필요한 GUI 를 갖춘다. (이미 있으면 그대로 쓴다)
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
		subtitle = makeLabel(panel, "Subtitle", "저주받은 통 · 승리 순위", PALETTE.Dim, UDim2.fromScale(1, 0.07), 0)
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

	return rows, footer
end

local function buildRow(rows, index, text, wins, highlight)
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

		local playerName = makeLabel(row, "PlayerName", "", PALETTE.Cream, UDim2.fromScale(0.72, 0.8), 0)
		playerName.Position = UDim2.fromScale(0, 0.1)

		local score = makeLabel(row, "Score", "", PALETTE.Gold, UDim2.fromScale(0.26, 0.8), 0)
		score.Position = UDim2.fromScale(0.74, 0.1)
		score.TextXAlignment = Enum.TextXAlignment.Right
	end

	row.BackgroundColor3 = (index % 2 == 0) and PALETTE.RowEven or PALETTE.RowOdd
	row.BackgroundTransparency = 0.15

	-- row.Name 은 Frame 의 이름 속성이므로 자식 라벨은 반드시 FindFirstChild 로 찾는다.
	local nameLabel = row:FindFirstChild("PlayerName")
	local scoreLabel = row:FindFirstChild("Score")
	if nameLabel then
		nameLabel.Text = text
		nameLabel.TextColor3 = highlight and PALETTE.Gold or PALETTE.Cream
	end
	if scoreLabel then
		scoreLabel.Text = wins
	end

	return row
end

function RankingService:Refresh()
	local top = self:GetTop(RANKING.Rows)

	for board in pairs(self._boards) do
		if board.Parent then
			local ok, err = pcall(function()
				local rows, footer = ensureBoardGui(board)

				for index = 1, RANKING.Rows do
					local entry = top[index]
					if entry then
						buildRow(rows, index, ("%d위   %s"):format(index, entry.name), ("%d승 / %d판"):format(entry.wins, entry.games), index <= 3)
					else
						local row = rows:FindFirstChild("Row_" .. index)
						if row then
							row:Destroy()
						end
					end
				end

				if #top == 0 then
					buildRow(rows, 1, "아직 승자가 없습니다", "0승 / 0판", false)
				end

				footer.Text = ("현재 서버 기준 · 접속 %d명"):format(#Players:GetPlayers())
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
-- DataStore (선택)
--------------------------------------------------

function RankingService:_getStore()
	if not RANKING.UseDataStore then
		return nil
	end
	if self._store == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore(RANKING.DataStoreName)
		end)
		self._store = ok and store or false
		if not ok then
			warn("[CursedBarrel] DataStore 를 열 수 없어 랭킹을 이 서버 안에서만 기록합니다.")
		end
	end
	return self._store or nil
end

function RankingService:_load(player)
	local store = self:_getStore()
	if not store then
		return
	end

	local ok, data = pcall(function()
		return store:GetAsync("u_" .. player.UserId)
	end)

	if ok and typeof(data) == "table" then
		local entry = entryFor(self, player)
		entry.wins = math.max(entry.wins, tonumber(data.wins) or 0)
		entry.games = math.max(entry.games, tonumber(data.games) or 0)
		updateLeaderstats(player, entry.wins)
		self:Refresh()
	end
end

function RankingService:_save(userId, entry)
	local store = self:_getStore()
	if not store then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync("u_" .. userId, { wins = entry.wins, games = entry.games, name = entry.name })
		end)
		if not ok then
			warn("[CursedBarrel] 랭킹 저장 실패: " .. tostring(err))
		end
	end)
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

	self._cleaner:add(Players.PlayerAdded:Connect(function(player)
		updateLeaderstats(player, 0)
		task.spawn(function()
			self:_load(player)
		end)
		self:Refresh()
	end))

	self._cleaner:add(Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:Refresh()
		end)
	end))

	for _, player in ipairs(Players:GetPlayers()) do
		updateLeaderstats(player, 0)
	end

	self:Refresh()

	local count = 0
	for _ in pairs(self._boards) do
		count += 1
	end
	GameConfig.log(("RankingService 시작 완료 · 랭킹판 %d개"):format(count))
end

return RankingService
