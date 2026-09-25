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
			list[index] = { name = name, score = tonumber(row.value) or 0, userId = userId or 0 }
		end
		self.top = list
	end
	self:_draw()
end

--------------------------------------------------
-- 순위판 (토너먼트 테이블 옆)
-- Phase 17 : 네모 판 하나 → 나무 게시판 (명예의 문과 같은 나무판자 · 굵은 틀 · 금 못 · 등불)
--   위에 트로피 간판 · 깃발 줄, 판에는 규칙 한 줄과 순위 10줄 (1~3등 금 · 은 · 동, 얼굴 사진, 점수).
--   앞뒤 양쪽에 똑같이 그린다.
--------------------------------------------------

local DARK = Color3.fromRGB(42, 28, 24)
local GOLD = Color3.fromRGB(214, 164, 72)
local PLANKS = { Color3.fromRGB(112, 70, 40), Color3.fromRGB(98, 60, 34), Color3.fromRGB(121, 77, 44), Color3.fromRGB(104, 64, 37) }
local MEDAL = { Color3.fromRGB(255, 214, 90), Color3.fromRGB(216, 224, 236), Color3.fromRGB(226, 150, 92) }
local BOARD_W, BOARD_H = 9, 8.4

local function piece(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function label(parent, name, text, color, size, position, align, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.FontFace = font or Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(26, 16, 10)
	stroke.Parent = l
	return l
end

-- 게시판 한 면의 글자 (SurfaceGui). 줄은 _draw 가 채운다.
local function boardFace(face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TourneyGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.3
	gui.Brightness = 1.4
	gui.MaxDistance = 120
	gui.Parent = face
	local season = Release.Season and Release.Season.Name or ""
	label(gui, "Rules", "4판 점수 합산  ·  생존 10 · 2등 6 · 3등 4 · 4등 2  ·  해적 잡기 +1", Color3.fromRGB(255, 236, 190),
		UDim2.fromScale(0.94, 0.07), UDim2.fromScale(0.03, 0.02), Enum.TextXAlignment.Center)
	label(gui, "Season", season ~= "" and ("시즌 · " .. season .. "  ·  34점 이상 = 토너먼트 챔피언") or "34점 이상 = 토너먼트 챔피언",
		Color3.fromRGB(255, 206, 110), UDim2.fromScale(0.94, 0.055), UDim2.fromScale(0.03, 0.095), Enum.TextXAlignment.Center)
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0.03, 0.17)
	rows.Size = UDim2.fromScale(0.94, 0.81)
	rows.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.01, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
	return rows
end

local function drawRows(rows, top)
	for index = 1, TOURNEY.BoardRows do
		local entry = top[index]
		local row = rows:FindFirstChild("Row_" .. index)
		if entry and not row then
			row = Instance.new("Frame")
			row.Name = "Row_" .. index
			row.LayoutOrder = index
			row.Size = UDim2.fromScale(1, 0.09)
			row.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(58, 36, 22) or Color3.fromRGB(72, 46, 28)
			row.BackgroundTransparency = 0.2
			row.BorderSizePixel = 0
			row.Parent = rows
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.3, 0)
			corner.Parent = row
			label(row, "Rank", "#" .. index, MEDAL[index] or Color3.fromRGB(240, 228, 206), UDim2.fromScale(0.12, 0.84), UDim2.fromScale(0.01, 0.08), Enum.TextXAlignment.Center)
			local avatar = Instance.new("ImageLabel")
			avatar.Name = "Avatar"
			avatar.BackgroundColor3 = Color3.fromRGB(30, 20, 14)
			avatar.Size = UDim2.fromScale(0.09, 0.9)
			avatar.Position = UDim2.fromScale(0.14, 0.05)
			avatar.Parent = row
			local aspect = Instance.new("UIAspectRatioConstraint")
			aspect.AspectRatio = 1
			aspect.Parent = avatar
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = avatar
			label(row, "PlayerName", "", Color3.fromRGB(245, 236, 220), UDim2.fromScale(0.5, 0.78), UDim2.fromScale(0.25, 0.11))
			label(row, "Score", "", Color3.fromRGB(255, 214, 110), UDim2.fromScale(0.22, 0.8), UDim2.fromScale(0.76, 0.1), Enum.TextXAlignment.Right)
		end
		if entry then
			row.PlayerName.Text = entry.name
			row.PlayerName.TextColor3 = MEDAL[index] and Color3.fromRGB(255, 244, 214) or Color3.fromRGB(245, 236, 220)
			row.Score.Text = ("%d점"):format(entry.score)
			row.Avatar.Visible = (entry.userId or 0) > 0
			if row.Avatar.Visible then
				row.Avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(entry.userId)
			end
		elseif row then
			row:Destroy()
		end
	end
	local empty = rows:FindFirstChild("Empty")
	if #top == 0 and not empty then
		empty = label(rows, "Empty", "첫 번째 챔피언이 되어 보세요!", Color3.fromRGB(255, 236, 190), UDim2.fromScale(1, 0.12), UDim2.new(), Enum.TextXAlignment.Center)
	elseif #top > 0 and empty then
		empty:Destroy()
	end
end

function TournamentService:_ensureBoard(gameTable)
	if self._boards[gameTable] or not gameTable.model then
		return
	end
	local top = gameTable.model:FindFirstChild("TableTop", true)
	local center = top and top.CFrame.Position or gameTable.model:GetPivot().Position
	local side = center.X >= 0 and 1 or -1
	local deckY = 1
	local foot = Vector3.new(center.X + side * 19, deckY, center.Z + 9)
	-- 게시판 앞면(+Z 로컬의 반대, 즉 LookVector)이 테이블을 본다
	local frame = CFrame.lookAt(foot, Vector3.new(center.X, deckY, center.Z))
	local board = Instance.new("Model")
	board.Name = "TournamentBoard"
	board.Parent = gameTable.model.Parent

	local w, h = BOARD_W, BOARD_H
	local bottom = 2.4
	local cy = bottom + h / 2
	local function at(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	-- 세로 판자
	local count = 6
	for i = 1, count do
		local x = -w / 2 + (i - 0.5) * w / count
		piece(board, "Plank", Vector3.new(w / count - 0.05, h, 0.4), at(x, cy, 0), PLANKS[i % #PLANKS + 1], Enum.Material.WoodPlanks).CanCollide = true
	end
	-- 굵은 틀 · 금 못
	piece(board, "FrameTop", Vector3.new(w + 1.2, 0.7, 0.7), at(0, bottom + h + 0.3, 0), DARK)
	piece(board, "FrameBottom", Vector3.new(w + 1.2, 0.6, 0.7), at(0, bottom - 0.25, 0), DARK)
	for _, sx in ipairs({ -1, 1 }) do
		piece(board, "FrameSide", Vector3.new(0.6, h + 0.6, 0.7), at(sx * (w / 2 + 0.3), cy, 0), DARK)
		for _, sz in ipairs({ -1, 1 }) do
			for _, y in ipairs({ bottom - 0.25, bottom + h + 0.3 }) do
				piece(board, "Nail", Vector3.new(0.3, 0.3, 0.3), at(sx * (w / 2 + 0.3), y, sz * 0.38), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
			end
		end
		-- 땅에 박은 기둥 · 금 모자
		local postH = bottom + h + 2.2
		piece(board, "Post", Vector3.new(0.8, postH, 0.8), at(sx * (w / 2 + 0.95), postH / 2, 0), DARK).CanCollide = true
		piece(board, "PostCap", Vector3.new(1.15, 0.3, 1.15), at(sx * (w / 2 + 0.95), postH + 0.15, 0), GOLD, Enum.Material.Metal)
		piece(board, "PostKnob", Vector3.new(0.6, 0.6, 0.6), at(sx * (w / 2 + 0.95), postH + 0.55, 0), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
		-- 기둥 옆 등불 (앞 · 뒤)
		for _, sz in ipairs({ -1, 1 }) do
			local lamp = at(sx * (w / 2 + 0.95), postH - 1.2, sz * 1.3)
			piece(board, "LampArm", Vector3.new(0.14, 0.14, 1.2), at(sx * (w / 2 + 0.95), postH - 0.6, sz * 0.7), Color3.fromRGB(44, 48, 54), Enum.Material.Metal)
			local glass = piece(board, "LampGlass", Vector3.new(0.6, 0.8, 0.6), lamp, Color3.fromRGB(255, 193, 93), Enum.Material.Neon)
			glass.Transparency = 0.15
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 196, 120)
			light.Range = 14
			light.Brightness = 1.3
			light.Shadows = false
			light.Parent = glass
		end
	end
	-- 트로피 간판 (위)
	local signY = bottom + h + 1.45
	local sign = piece(board, "HeaderPlaque", Vector3.new(6.4, 1.6, 0.5), at(0, signY, 0), Color3.fromRGB(128, 34, 30))
	piece(board, "HeaderTrim", Vector3.new(6.7, 1.9, 0.4), at(0, signY, 0), GOLD, Enum.Material.Metal)
	for _, sz in ipairs({ -1, 1 }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = sz < 0 and Enum.NormalId.Front or Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0.2
		gui.Parent = sign
		label(gui, "Title", "🏆 토너먼트 챔피언", Color3.fromRGB(255, 226, 130), UDim2.fromScale(0.94, 0.8), UDim2.fromScale(0.03, 0.1), Enum.TextXAlignment.Center)
	end
	-- 금 트로피 장식 (간판 위)
	local cupY = signY + 1.3
	piece(board, "TrophyBase", Vector3.new(0.3, 1, 1), at(0, cupY - 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.Material.Wood, Enum.PartType.Cylinder)
	piece(board, "TrophyStem", Vector3.new(0.5, 0.25, 0.25), at(0, cupY - 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece(board, "TrophyCup", Vector3.new(1.1, 1.0, 1.1), at(0, cupY + 0.35, 0), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	piece(board, "TrophyRim", Vector3.new(0.12, 1.15, 1.15), at(0, cupY + 0.62, 0) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, sx in ipairs({ -1, 1 }) do
		piece(board, "TrophyHandle", Vector3.new(0.14, 0.55, 0.14), at(sx * 0.62, cupY + 0.4, 0) * CFrame.Angles(0, 0, sx * 0.4), GOLD, Enum.Material.Metal)
	end
	local star = piece(board, "TrophyGem", Vector3.new(0.35, 0.35, 0.35), at(0, cupY + 0.4, -0.5), Color3.fromRGB(255, 92, 150), Enum.Material.Neon, Enum.PartType.Ball)
	star.Transparency = 0.05
	-- 깃발 줄 (기둥 사이에 늘어진 삼각 깃발)
	local flags = { Color3.fromRGB(214, 52, 52), GOLD, Color3.fromRGB(40, 110, 200), GOLD }
	local span = w + 1.9
	local topY = bottom + h + 2.0
	for i = 1, 9 do
		local t = (i - 0.5) / 9
		local x = -span / 2 + span * t
		local sag = math.sin(t * math.pi) * 0.55
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Pennant"
		wedge.Size = Vector3.new(0.05, 0.75, 0.6)
		wedge.CFrame = at(x, topY - sag - 0.45, 0) * CFrame.Angles(math.pi, math.pi / 2, 0)
		wedge.Color = flags[i % #flags + 1]
		wedge.Material = Enum.Material.Fabric
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.CastShadow = false
		wedge.Parent = board
	end
	for i = 0, 8 do
		local t0, t1 = i / 9, (i + 1) / 9
		local a = at(-span / 2 + span * t0, topY - math.sin(t0 * math.pi) * 0.55, 0).Position
		local b = at(-span / 2 + span * t1, topY - math.sin(t1 * math.pi) * 0.55, 0).Position
		piece(board, "PennantRope", Vector3.new(0.06, 0.06, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(150, 120, 80), Enum.Material.Fabric)
	end
	-- 글자 면 : 앞 · 뒤
	local faces = {}
	for _, sz in ipairs({ -1, 1 }) do
		local face = piece(board, "TourneyFace", Vector3.new(w - 0.3, h - 0.3, 0.05), at(0, cy, sz * 0.23) * CFrame.Angles(0, sz < 0 and 0 or math.pi, 0), DARK, Enum.Material.SmoothPlastic)
		face.Transparency = 1
		table.insert(faces, boardFace(face))
	end
	self._boards[gameTable] = { model = board, rows = faces }
end

function TournamentService:_draw()
	for gameTable, board in pairs(self._boards) do
		if gameTable.destroyed or not board.model.Parent then
			self._boards[gameTable] = nil
		else
			for _, rows in ipairs(board.rows) do
				pcall(drawRows, rows, self.top)
			end
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
