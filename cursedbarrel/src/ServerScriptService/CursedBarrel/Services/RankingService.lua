--[[
	RankingService  (Phase 3 · Phase 7 전 서버 랭킹 · Phase 16 명예의 문)
	스폰 앞 "명예의 문" 나무판자 셋에 순위를 그린다.

	  🔥 최고 연승   — 가장 길게 이어 이긴 판 수 (bestStreak)
	  💰 전체 부자   — 지금 가진 코인
	  🏆 전체 승리   — 이긴 판 수

	두 가지 자료를 쓴다.
	  · 전 서버 순위 — 판마다 OrderedDataStore 하나. 90초마다 다시 읽는다.
	  · 이 서버 순위 — 저장소를 못 열 때(Studio 에서 API 가 꺼져 있을 때 등)만 대신 보여 준다.

	올리기
	  · 승리 : 이긴 순간 (예전과 같다)
	  · 코인 · 연승 : 2분마다 값이 바뀐 사람만 (저장소 쓰기 한도를 아낀다)
	  · 개발자 시험 코드를 쓴 계정(devTester)은 순위에 올리지 않는다 (999,999 코인이 1등을 차지하지 않게)

	기록 자체는 ProfileService 가 맡는다. 여기서는 세고 그리기만 한다.
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
	Title = Color3.fromRGB(255, 214, 92),
	Name = Color3.fromRGB(255, 244, 222),
	Value = Color3.fromRGB(255, 226, 120),
	Outline = Color3.fromRGB(34, 20, 12),
	RowA = Color3.fromRGB(58, 34, 18),
	RowB = Color3.fromRGB(74, 44, 24),
	Empty = Color3.fromRGB(214, 190, 150),
	Medal = { Color3.fromRGB(255, 206, 60), Color3.fromRGB(214, 222, 236), Color3.fromRGB(226, 146, 84) },
}
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

local BOARDS = {}
for _, spec in ipairs(RANKING.Boards or {}) do
	BOARDS[spec.id] = spec
end
local DEFAULT_BOARD = "wins"

local RankingService = {}
RankingService._stats = {} -- [userId] = { name, wins, games, streak, bestStreak, coins, order }
RankingService._global = {} -- [boardId] = { { userId, name, value } }
RankingService._boards = {} -- [face part] = boardId
RankingService._stores = {} -- [boardId] = OrderedDataStore | false
RankingService._published = {} -- [userId] = { [boardId] = 마지막으로 올린 값 }
RankingService._names = {} -- [userId] = 이름 (한 번만 묻는다)
RankingService._cleaner = Utility.Cleaner.new()
RankingService._started = false
RankingService._orderCounter = 0
RankingService._refreshQueued = false

--------------------------------------------------
-- 이 서버 기록
--------------------------------------------------

local function isTester(player)
	local profile = ProfileService:Get(player)
	return profile ~= nil and profile.devTester == true
end

local function entryFor(self, player)
	local entry = self._stats[player.UserId]
	if not entry then
		self._orderCounter += 1
		entry = { name = player.Name, wins = 0, games = 0, streak = 0, bestStreak = 0, coins = 0, order = self._orderCounter }
		self._stats[player.UserId] = entry
	end
	entry.name = player.Name
	entry.tester = isTester(player)
	return entry
end

-- 라운드가 끝날 때 RoundService 가 부른다. (ProfileService 다음에 불린다)
function RankingService:RecordRound(gameTable, roster, winner)
	for _, player in ipairs(roster or {}) do
		if player and player.Parent == Players then
			local entry = entryFor(self, player)
			entry.games += 1
			entry.streak = player:GetAttribute(PLAYER_ATTR.Streak) or 0
			entry.bestStreak = math.max(entry.bestStreak, entry.streak)
		end
	end

	if winner and winner.Parent == Players then
		local entry = entryFor(self, winner)
		entry.wins += 1
		entry.streak = winner:GetAttribute(PLAYER_ATTR.Streak) or 0
		entry.bestStreak = math.max(entry.bestStreak, entry.streak)
		if not entry.tester then
			local profile = ProfileService:Get(winner)
			self:_publish(winner.UserId, "wins", profile and profile.wins or entry.wins)
		end
		GameConfig.log(("랭킹 기록 · %s 승리 %d회 (%s)")
			:format(winner.Name, entry.wins, tostring(gameTable and gameTable.tableId)))
	end

	self:Refresh()
end

-- 이 서버 순위. stat 이 큰 순 → 먼저 들어온 순 (승리는 판수 적은 순을 먼저 본다)
function RankingService:GetTop(count, boardId)
	local stat = (BOARDS[boardId or DEFAULT_BOARD] or { stat = "wins" }).stat
	local list = {}
	for userId, entry in pairs(self._stats) do
		if not entry.tester then
			table.insert(list, {
				userId = userId,
				name = entry.name,
				value = entry[stat] or 0,
				wins = entry.wins,
				games = entry.games,
				streak = entry.streak or 0,
				order = entry.order,
			})
		end
	end

	table.sort(list, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		if stat == "wins" and a.games ~= b.games then
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
-- 전 서버 랭킹 (판마다 OrderedDataStore 하나)
--------------------------------------------------

function RankingService:_store(boardId)
	if not RANKING.UseDataStore then
		return nil
	end
	local spec = BOARDS[boardId]
	if not spec then
		return nil
	end
	if self._stores[boardId] == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(spec.store)
		end)
		self._stores[boardId] = ok and store or false
		if not ok then
			warn("[CursedBarrel] 전체 순위를 열 수 없어 이 서버 순위만 보여줍니다. (" .. boardId .. ")")
		end
	end
	return self._stores[boardId] or nil
end

-- 한 사람의 값을 전 서버 순위에 올린다. 승리 · 연승은 줄어들지 않고, 코인은 지금 값 그대로.
function RankingService:_publish(userId, boardId, value)
	local store = self:_store(boardId)
	local spec = BOARDS[boardId]
	if not store or not spec then
		return
	end
	value = math.max(0, math.floor(tonumber(value) or 0))
	local seen = self._published[userId] or {}
	self._published[userId] = seen
	if seen[boardId] == value then
		return
	end
	seen[boardId] = value
	task.spawn(function()
		local ok, err = pcall(function()
			if spec.keepMax then
				store:UpdateAsync(tostring(userId), function(old)
					return math.max(tonumber(old) or 0, value)
				end)
			else
				store:SetAsync(tostring(userId), value)
			end
		end)
		if not ok then
			seen[boardId] = nil
			warn("[CursedBarrel] 전체 순위 기록 실패 (" .. boardId .. "): " .. tostring(err))
		end
	end)
end

-- 시험 계정은 순위에서 지운다 (예전에 올라가 있었어도)
function RankingService:_forget(userId)
	for boardId in pairs(BOARDS) do
		local store = self:_store(boardId)
		if store then
			task.spawn(function()
				pcall(function()
					store:RemoveAsync(tostring(userId))
				end)
			end)
		end
	end
	self._published[userId] = {}
end

function RankingService:_nameOf(userId)
	local cached = self._names[userId]
	if cached then
		return cached
	end
	local name = "선원 " .. tostring(userId)
	local ok, fetched = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and fetched then
		name = fetched
		self._names[userId] = fetched
	end
	return name
end

function RankingService:_pullGlobal()
	for boardId in pairs(BOARDS) do
		local store = self:_store(boardId)
		if store then
			local ok, page = pcall(function()
				return store:GetSortedAsync(false, RANKING.GlobalRows):GetCurrentPage()
			end)
			if ok then
				local list = {}
				for index, row in ipairs(page) do
					local userId = tonumber(row.key) or 0
					list[index] = { userId = userId, name = userId > 0 and self:_nameOf(userId) or tostring(row.key), value = tonumber(row.value) or 0 }
				end
				self._global[boardId] = list
			end
		end
	end
	self:Refresh()
end

-- 코인 · 연승은 모아 두었다가 한 번에 올린다
function RankingService:_flush()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = ProfileService:Get(player)
		if profile and not profile.devTester then
			for boardId, spec in pairs(BOARDS) do
				if boardId ~= "wins" then
					self:_publish(player.UserId, boardId, profile[spec.stat])
				end
			end
		end
	end
end

--------------------------------------------------
-- 판 그리기 (나무판자 위 금색 글씨)
--------------------------------------------------

-- 1,234 · 12.3만 · 1.2억 처럼 짧게
function RankingService.shortNumber(value)
	value = math.floor(tonumber(value) or 0)
	if value >= 100000000 then
		return (("%.1f억"):format(value / 100000000):gsub("%.0억", "억"))
	elseif value >= 100000 then
		return (("%.1f만"):format(value / 10000):gsub("%.0만", "만"))
	end
	return Utility.comma(value)
end

local function outlined(label, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = PALETTE.Outline
	stroke.Thickness = thickness or 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

local function textLabel(parent, name, text, color, size, position, alignX)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.new()
	label.FontFace = FONT
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextXAlignment = alignX or Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function ensureBoardGui(face, spec)
	local gui = face:FindFirstChild("RankingGui")
	if gui then
		return gui:FindFirstChild("Rows")
	end
	gui = Instance.new("SurfaceGui")
	gui.Name = "RankingGui"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.35
	gui.Brightness = 1.4
	gui.PixelsPerStud = 48
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.MaxDistance = 140
	gui.Parent = face

	local title = textLabel(gui, "Title", spec.title or "순위", PALETTE.Title, UDim2.new(0.94, 0, 0.15, 0), UDim2.fromScale(0.03, 0.02), Enum.TextXAlignment.Center)
	outlined(title, 3)

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0.03, 0.19)
	rows.Size = UDim2.fromScale(0.94, 0.79)
	rows.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.008, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
	return rows
end

local function buildRow(rows, index, entry, spec)
	local row = rows:FindFirstChild("Row_" .. index)
	if not row then
		row = Instance.new("Frame")
		row.Name = "Row_" .. index
		row.Size = UDim2.fromScale(1, 0.092)
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.BackgroundColor3 = index % 2 == 0 and PALETTE.RowB or PALETTE.RowA
		row.BackgroundTransparency = 0.25
		row.Parent = rows
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = row

		local rank = textLabel(row, "Rank", "#" .. index, PALETTE.Name, UDim2.fromScale(0.11, 0.86), UDim2.fromScale(0.01, 0.07), Enum.TextXAlignment.Center)
		outlined(rank, 1.5)
		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.BackgroundColor3 = PALETTE.Outline
		avatar.BackgroundTransparency = 0.3
		avatar.Size = UDim2.fromScale(0.09, 0.9)
		avatar.Position = UDim2.fromScale(0.125, 0.05)
		avatar.Parent = row
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.Parent = avatar
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = avatar
		outlined(textLabel(row, "PlayerName", "", PALETTE.Name, UDim2.fromScale(0.5, 0.78), UDim2.fromScale(0.235, 0.11)), 1.5)
		outlined(textLabel(row, "Score", "", PALETTE.Value, UDim2.fromScale(0.26, 0.82), UDim2.fromScale(0.73, 0.09), Enum.TextXAlignment.Right), 1.5)
	end

	local medal = PALETTE.Medal[index]
	row.Rank.TextColor3 = medal or PALETTE.Name
	row.Avatar.Visible = (entry.userId or 0) > 0
	if row.Avatar.Visible then
		row.Avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(entry.userId)
	end
	row.PlayerName.Text = entry.name or ""
	row.PlayerName.TextColor3 = medal and PALETTE.Title or PALETTE.Name
	row.Score.Text = RankingService.shortNumber(entry.value) .. (spec.suffix or "")
	return row
end

function RankingService:Refresh()
	for face, boardId in pairs(self._boards) do
		if face.Parent then
			local ok, err = pcall(function()
				local spec = BOARDS[boardId] or BOARDS[DEFAULT_BOARD] or { id = boardId, stat = "wins", title = "🏆 승리" }
				local rows = ensureBoardGui(face, spec)
				local global = self._global[boardId]
				local top = (global and #global > 0) and global or self:GetTop(RANKING.Rows, boardId)
				for index = 1, RANKING.Rows do
					local entry = top[index]
					if entry then
						buildRow(rows, index, entry, spec)
					else
						local row = rows:FindFirstChild("Row_" .. index)
						if row then
							row:Destroy()
						end
					end
				end
				local empty = rows:FindFirstChild("Empty")
				if #top == 0 and not empty then
					empty = textLabel(rows, "Empty", "첫 번째 주인공이 되어 보세요!", PALETTE.Empty, UDim2.fromScale(1, 0.14))
					empty.TextXAlignment = Enum.TextXAlignment.Center
					outlined(empty, 1.5)
				elseif #top > 0 and empty then
					empty:Destroy()
				end
			end)
			if not ok then
				warn("[CursedBarrel] 랭킹판 갱신 중 오류: " .. tostring(err))
			end
		else
			self._boards[face] = nil
		end
	end
end

--------------------------------------------------
-- 시작
--------------------------------------------------

function RankingService:_registerBoard(face)
	-- ServerStorage 로 치운 예전 판(태그가 남아 있다)은 그리지 않는다
	if not face:IsA("BasePart") or not face:IsDescendantOf(workspace) then
		return
	end
	self._boards[face] = face:GetAttribute("Board") or DEFAULT_BOARD
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

	-- 저장된 값을 읽어 이 서버 순위의 출발점으로 삼는다.
	-- ProfileChanged 는 코인이 오를 때마다 오므로, 판을 다시 그리는 것은 한 박자 묶는다.
	self._cleaner:add(ProfileService.ProfileChanged:Connect(function(player, profile)
		local entry = entryFor(self, player)
		entry.wins = math.max(entry.wins, profile.wins)
		entry.games = math.max(entry.games, profile.games)
		entry.streak = profile.streak
		entry.bestStreak = math.max(entry.bestStreak, profile.bestStreak or 0)
		entry.coins = profile.coins
		if profile.devTester and not entry.forgotten then
			entry.forgotten = true
			self:_forget(player.UserId)
		end

		if not self._refreshQueued then
			self._refreshQueued = true
			task.delay(1, function()
				self._refreshQueued = false
				self:Refresh()
			end)
		end
	end))

	self._cleaner:add(Players.PlayerRemoving:Connect(function(player)
		-- 나가기 전에 마지막 값을 올린다
		local profile = ProfileService:Get(player)
		if profile and not profile.devTester then
			for boardId, spec in pairs(BOARDS) do
				if boardId ~= "wins" then
					self:_publish(player.UserId, boardId, profile[spec.stat])
				end
			end
		end
		self._published[player.UserId] = nil
		task.defer(function()
			self:Refresh()
		end)
	end))

	self:Refresh()

	-- 전체 순위를 주기적으로 읽고, 코인 · 연승을 주기적으로 올린다.
	task.spawn(function()
		while true do
			self:_pullGlobal()
			task.wait(RANKING.GlobalRefresh)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(RANKING.PublishInterval or 120)
			self:_flush()
		end
	end)

	local count = 0
	for _ in pairs(self._boards) do
		count += 1
	end
	GameConfig.log(("RankingService 시작 완료 · 랭킹판 %d개"):format(count))
end

return RankingService
