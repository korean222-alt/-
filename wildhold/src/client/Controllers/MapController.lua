-- 지도 (마인크래프트 지도처럼): 오른쪽 위 미니맵 + 누르면(또는 M 키) 큰 지도.
-- 가 본 곳만 그려진다. 안 가 본 곳은 빈 양피지. 지나간 자리 둘레(MapConfig.MapReveal)가 칸 단위로 채워진다.
-- 서버 MapService 가 맵을 만들 때 ReplicatedStorage.MapGrid 에 칸마다 글자 하나(풀·숲·길·물·바위…)를 적어 두고,
-- 여기서는 한 줄씩 같은 색이 이어지는 칸을 Frame 하나로 묶어 그린다 (칸마다 Frame 을 만들면 수천 개가 된다).
-- 북쪽(-Z)이 위. 표시: ▲ 나(보는 방향) · 🏠 기지 · ☠ 괴물 굴 · 👑 알파의 숲 · ★ 목표 · 파란 점 팀원
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local M = require(RS.Shared.Config.MapConfig)
local L = require(RS.Shared.Modules.Locale)

local Map = {}
local player = Players.LocalPlayer
local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamBold
local PAPER = Color3.fromHex("#d9c89d")
local EDGE = Color3.fromHex("#7a6240")
local MINI = 132 -- 미니맵 크기 (UIScale 전 픽셀)
local ZOOM = 6 -- 미니맵에서 한 칸의 픽셀 → 약 350 stud 가 보인다

-- 칸 글자 → 색 (두 번째 색은 숲·바위를 얼룩덜룩하게 섞는 데 쓴다)
local PALETTE = {
	G = {"#74814f"}, A = {"#56673f"}, C = {"#8b8577"}, S = {"#57634a"}, O = {"#2c4331", "#243a29"},
	H = {"#6f6c66"}, D = {"#76664f"}, R = {"#9d9d97", "#8b8b86"}, T = {"#36532f", "#2d4729"}, Q = {"#6fe3ef"},
	P = {"#a5885b"}, W = {"#4a7a99"}, B = {"#a8916a"}, U = {"#4d3663"}, K = {"#5a4232"}, X = {"#43301f"},
}
local COLORS = {}
for key, list in pairs(PALETTE) do
	COLORS[key] = {Color3.fromHex(list[1]), list[2] and Color3.fromHex(list[2]) or nil}
end

local function new(className, parent, props)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end

local function hidePlayerList()
	-- 컴퓨터에서는 기본 플레이어 목록이 오른쪽 위를 덮어 미니맵을 가린다
	for _ = 1, 20 do
		if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end) then return end
		task.wait(0.5)
	end
end

local function scaleOf()
	local size = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(size.X / 1100, size.Y / 700), 0.62, 1.15), size
end

function Map:Init(remotes)
	local grid = RS:WaitForChild("MapGrid", 30)
	assert(grid, "MapGrid missing (server MapService:BuildMapGrid)")
	self.Grid = grid.Value
	self.Cell, self.N, self.Origin = grid:GetAttribute("Cell"), grid:GetAttribute("Size"), grid:GetAttribute("Origin")
	self.Seen, self.Rows, self.Dirty, self.SeenCount = {}, {}, {}, 0
	self.Mates, self.Big = {}, false
	task.spawn(hidePlayerList)
	self:BuildGui()
	-- 기지 둘레는 처음부터 안다
	self:Reveal(Vector3.zero, M.BaseRadius + 50)
	self:Flush()
	remotes.State.OnClientEvent:Connect(function(data)
		self.GoalAt = data and data.GoalAt
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then self:Toggle() end
	end)
	self.NextReveal = 0
	RunService.RenderStepped:Connect(function() self:Step() end)
end

-- ===================================================================== 화면
function Map:BuildGui()
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "Minimap", ResetOnSpawn = false, DisplayOrder = 11,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	local big = new("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "WorldMap", ResetOnSpawn = false, DisplayOrder = 30, Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	self.Gui, self.BigGui = gui, big
	local scales = {new("UIScale", gui, {Scale = 1}), new("UIScale", big, {Scale = 1})}
	local function rescale()
		local s = scaleOf()
		for _, ui in ipairs(scales) do ui.Scale = s end
		if self.Big then self:Layout() end
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- 오른쪽 위 미니맵: 양피지 액자
	local holder = new("Frame", gui, {Name = "Holder", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6),
		Size = UDim2.fromOffset(MINI + 10, MINI + 10), BackgroundColor3 = EDGE, BorderSizePixel = 0})
	new("UICorner", holder, {CornerRadius = UDim.new(0, 8)})
	new("UIStroke", holder, {Color = Color3.fromHex("#1c140c"), Thickness = 2, Transparency = 0.3})
	self.Mini = new("Frame", holder, {Name = "Window", Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(MINI, MINI),
		BackgroundColor3 = PAPER, BorderSizePixel = 0, ClipsDescendants = true})
	new("TextLabel", holder, {Name = "North", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.fromOffset(16, 14),
		BackgroundTransparency = 1, Font = TITLE, TextSize = 13, Text = "N", TextColor3 = Color3.fromHex("#3a2a18"), ZIndex = 5,
		TextStrokeTransparency = 0.6, TextStrokeColor3 = PAPER})
	new("TextLabel", holder, {Name = "Hint", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, 2), Size = UDim2.fromOffset(MINI + 10, 14),
		BackgroundTransparency = 1, Font = BODY, TextSize = 11, Text = L.t("map.hint"), TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4, TextXAlignment = Enum.TextXAlignment.Right})
	local open = new("TextButton", holder, {Name = "Open", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6})
	open.Activated:Connect(function() self:Toggle() end)

	-- 그림판(Canvas): 맵 전체 크기. 미니맵에서는 나를 가운데 두고 움직이고, 큰 지도에서는 창에 꽉 맞춘다.
	-- 칸·표시는 모두 비율(Scale) 좌표라 크기만 바꾸면 그대로 따라온다.
	self.Canvas = new("Frame", self.Mini, {Name = "Canvas", Size = UDim2.fromOffset(self.N * ZOOM, self.N * ZOOM), BackgroundTransparency = 1})
	self.Cells = new("Frame", self.Canvas, {Name = "Cells", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
	self.Marks = new("Frame", self.Canvas, {Name = "Marks", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
	local function icon(text, color, size)
		return new("TextLabel", self.Marks, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size or 16, size or 16), BackgroundTransparency = 1,
			Font = TITLE, TextSize = size or 16, Text = text, TextColor3 = color or Color3.new(1, 1, 1), TextStrokeTransparency = 0.35})
	end
	self.Icons = {}
	local home = icon("🏠", nil, 15)
	home.Position = self:ToCanvas(0, 0)
	for _, angle in ipairs(M.LaneAngles) do
		local a = math.rad(angle)
		local pos = Vector3.new(math.sin(a), 0, -math.cos(a)) * (M.LaneRadius + 6)
		local skull = icon("☠", Color3.fromHex("#ff7a7a"), 14)
		skull.Position = self:ToCanvas(pos.X, pos.Z)
		table.insert(self.Icons, {Label = skull, Pos = pos})
	end
	local ga = math.rad(M.Grove.Angle)
	local grove = Vector3.new(math.sin(ga), 0, -math.cos(ga)) * M.Grove.Radius
	local crown = icon("👑", nil, 15)
	crown.Position = self:ToCanvas(grove.X, grove.Z)
	table.insert(self.Icons, {Label = crown, Pos = grove})
	self.GoalIcon = icon("★", Color3.fromHex("#ffe066"), 16)
	self.GoalIcon.Visible = false
	self.Me = icon("▲", Color3.new(1, 1, 1), 15)
	self.Me.ZIndex = 3
	self.Me.TextStrokeTransparency = 0

	-- 큰 지도
	local backdrop = new("TextButton", big, {Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false})
	backdrop.Activated:Connect(function() self:Toggle(false) end)
	self.Panel = new("Frame", big, {Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 470), BackgroundColor3 = EDGE, BorderSizePixel = 0})
	new("UICorner", self.Panel, {CornerRadius = UDim.new(0, 12)})
	new("UIStroke", self.Panel, {Color = Color3.fromHex("#1c140c"), Thickness = 3, Transparency = 0.2})
	new("TextLabel", self.Panel, {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -60, 0, 28), BackgroundTransparency = 1, Font = TITLE,
		TextSize = 20, Text = L.t("map.title"), TextColor3 = Color3.fromHex("#fff3d6"), TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.5})
	local close = new("TextButton", self.Panel, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(30, 28),
		BackgroundColor3 = Color3.fromHex("#3a2a18"), Text = "✕", Font = TITLE, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0})
	new("UICorner", close, {CornerRadius = UDim.new(0, 8)})
	close.Activated:Connect(function() self:Toggle(false) end)
	self.BigWindow = new("Frame", self.Panel, {Name = "Window", Position = UDim2.fromOffset(10, 40), Size = UDim2.fromOffset(400, 400),
		BackgroundColor3 = PAPER, BorderSizePixel = 0, ClipsDescendants = true})
	self.Legend = new("TextLabel", self.Panel, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -4), Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1, Font = BODY, TextSize = 13, TextColor3 = Color3.fromHex("#fff3d6"), TextXAlignment = Enum.TextXAlignment.Left,
		Text = L.t("map.legend"), TextStrokeTransparency = 0.5})
end

-- 큰 지도 창 크기: 화면 짧은 쪽의 80% 쯤
function Map:Layout()
	local s, vp = scaleOf()
	local side = math.floor(math.max(220, math.min(vp.X, vp.Y) / s * 0.8 - 70))
	self.Panel.Size = UDim2.fromOffset(side + 20, side + 72)
	self.BigWindow.Size = UDim2.fromOffset(side, side)
	self.Canvas.Size = UDim2.fromOffset(side, side)
	self.Canvas.Position = UDim2.fromOffset(0, 0)
end

function Map:Toggle(want)
	if want == nil then want = not self.Big end
	if want == self.Big then return end
	self.Big = want
	self.BigGui.Enabled = want
	if want then
		self.Canvas.Parent = self.BigWindow
		self:Layout()
	else
		self.Canvas.Parent = self.Mini
		self.Canvas.Size = UDim2.fromOffset(self.N * ZOOM, self.N * ZOOM)
	end
end

-- 월드 좌표 → 그림판 비율 좌표
function Map:ToCanvas(x, z)
	local span = self.N * self.Cell
	return UDim2.fromScale((x - self.Origin) / span, (z - self.Origin) / span)
end

-- ===================================================================== 칸 밝히기 / 그리기
function Map:Index(ix, iz)
	return iz * self.N + ix + 1
end

function Map:IsSeen(x, z)
	local ix, iz = math.floor((x - self.Origin) / self.Cell), math.floor((z - self.Origin) / self.Cell)
	if ix < 0 or iz < 0 or ix >= self.N or iz >= self.N then return false end
	return self.Seen[self:Index(ix, iz)] == true
end

function Map:Reveal(pos, radius)
	local cell, n, o = self.Cell, self.N, self.Origin
	for iz = math.max(0, math.floor((pos.Z - radius - o) / cell)), math.min(n - 1, math.floor((pos.Z + radius - o) / cell)) do
		for ix = math.max(0, math.floor((pos.X - radius - o) / cell)), math.min(n - 1, math.floor((pos.X + radius - o) / cell)) do
			local dx, dz = o + (ix + 0.5) * cell - pos.X, o + (iz + 0.5) * cell - pos.Z
			local i = self:Index(ix, iz)
			if not self.Seen[i] and dx * dx + dz * dz <= radius * radius then
				self.Seen[i] = true
				self.SeenCount = self.SeenCount + 1
				self.Dirty[iz] = true
			end
		end
	end
end

-- 칸 색 (없으면 그리지 않는 칸)
function Map:ColorAt(ix, iz)
	local i = self:Index(ix, iz)
	if not self.Seen[i] then return nil end
	local key = string.sub(self.Grid, i, i)
	local colors = COLORS[key]
	if not colors then return nil end
	if colors[2] and (ix * 7 + iz * 13) % 3 == 0 then
		return key .. "2", colors[2]
	end
	return key, colors[1]
end

-- 한 줄을 다시 그린다: 같은 색이 이어지는 칸은 Frame 하나로
function Map:BuildRow(iz)
	for _, frame in ipairs(self.Rows[iz] or {}) do frame:Destroy() end
	local n, frames = self.N, {}
	local startX, runKey, runColor = nil, nil, nil
	local function flush(endX)
		if startX then
			-- 1픽셀 겹쳐서 칸 사이 틈이 안 보이게
			frames[#frames + 1] = new("Frame", self.Cells, {BorderSizePixel = 0, BackgroundColor3 = runColor,
				Position = UDim2.fromScale(startX / n, iz / n), Size = UDim2.new((endX - startX) / n, 1, 1 / n, 1)})
		end
	end
	for ix = 0, n do
		local key, color = nil, nil
		if ix < n then key, color = self:ColorAt(ix, iz) end
		if key ~= runKey then
			flush(ix)
			startX, runKey, runColor = key and ix or nil, key, color
		end
	end
	self.Rows[iz] = frames
end

function Map:Flush()
	for iz in pairs(self.Dirty) do
		self:BuildRow(iz)
	end
	self.Dirty = {}
end

-- ===================================================================== 매 프레임
function Map:Step()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local pos = root.Position
		local now = os.clock()
		if now >= self.NextReveal then
			self.NextReveal = now + 0.25
			self:Reveal(pos, M.MapReveal)
			self:Flush()
		end
		local look = root.CFrame.LookVector
		self.Me.Position = self:ToCanvas(pos.X, pos.Z)
		self.Me.Rotation = math.deg(math.atan2(look.X, -look.Z))
		if not self.Big then
			local span = self.N * self.Cell
			local px, pz = (pos.X - self.Origin) / span * self.N * ZOOM, (pos.Z - self.Origin) / span * self.N * ZOOM
			self.Canvas.Position = UDim2.fromOffset(math.floor(MINI / 2 - px), math.floor(MINI / 2 - pz))
		end
	end
	-- 괴물 굴·알파의 숲은 그 자리를 가 봐야 보인다
	for _, entry in ipairs(self.Icons) do
		entry.Label.Visible = self:IsSeen(entry.Pos.X, entry.Pos.Z)
	end
	local goal = self.GoalAt
	self.GoalIcon.Visible = goal ~= nil
	if goal then self.GoalIcon.Position = self:ToCanvas(goal.X, goal.Z) end
	-- 팀원
	local alive = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot then
			alive[other] = true
			local dot = self.Mates[other]
			if not dot then
				dot = new("Frame", self.Marks, {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0,
					BackgroundColor3 = Color3.fromHex("#5cb8ff")})
				new("UICorner", dot, {CornerRadius = UDim.new(0.5, 0)})
				new("UIStroke", dot, {Color = Color3.new(0, 0, 0), Thickness = 1.5})
				self.Mates[other] = dot
			end
			dot.Position = self:ToCanvas(otherRoot.Position.X, otherRoot.Position.Z)
		end
	end
	for other, dot in pairs(self.Mates) do
		if not alive[other] then
			dot:Destroy()
			self.Mates[other] = nil
		end
	end
end

return Map
