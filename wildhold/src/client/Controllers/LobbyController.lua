-- 로비 화면: 혼자 바로 출발 · 원정 수레(방) 카드 · 부화장 · 내 펫(출전 팀·이름) · 보급 상점 · 부화 연출.
-- 서버 LobbyService 가 0.5초마다 Lobby("State", 상태) 를 보내고, 버튼은 LobbyAction(동작, 값) 으로 보낸다.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local P = require(RS.Shared.Config.PetConfig)
local EC = require(RS.Shared.Config.EggConfig)
local LC = require(RS.Shared.Config.LobbyConfig)
local Shop = require(RS.Shared.Config.ShopConfig)
local PR = require(RS.Shared.Modules.PetRules)
local Portrait = require(script.Parent.Portrait)
local T = require(RS.Shared.Modules.Locale) -- 번역 (이 파일의 L 은 컨트롤러)

local L = {}
local player = Players.LocalPlayer
local TITLE, BODY = Enum.Font.FredokaOne, Enum.Font.GothamBold
local COL = {Panel = Color3.fromHex("#16202e"), Card = Color3.fromHex("#1f2b3b"), Card2 = Color3.fromHex("#273548"), Text = Color3.fromHex("#f1f5fa"),
	Muted = Color3.fromHex("#aab6c6"), Mint = Color3.fromHex("#7be0b6"), Gold = Color3.fromHex("#ffd36b"), Green = Color3.fromHex("#3fae6a"),
	Purple = Color3.fromHex("#5a4a8a"), Red = Color3.fromHex("#b0553a")}
local ELEMENT = {Leaf = "element.Leaf", Ember = "element.Ember", Tide = "element.Tide"}

local function new(className, parent, props)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end

local function corner(parent, r)
	return new("UICorner", parent, {CornerRadius = UDim.new(0, r or 12)})
end

local function panel(parent, props)
	local f = new("Frame", parent, {BackgroundColor3 = COL.Panel, BackgroundTransparency = 0.08, BorderSizePixel = 0})
	for k, v in pairs(props or {}) do f[k] = v end
	corner(f, 14)
	new("UIStroke", f, {Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.5})
	return f
end

local function label(parent, text, props)
	local t = new("TextLabel", parent, {BackgroundTransparency = 1, Font = BODY, TextSize = 15, TextColor3 = COL.Text, TextWrapped = true, Text = text})
	for k, v in pairs(props or {}) do t[k] = v end
	return t
end

local function button(parent, text, props, fn)
	local b = new("TextButton", parent, {Text = text, Font = TITLE, TextSize = 16, TextColor3 = COL.Text, BackgroundColor3 = COL.Card2,
		BorderSizePixel = 0, AutoButtonColor = true})
	for k, v in pairs(props or {}) do b[k] = v end
	corner(b, 10)
	new("UIStroke", b, {Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	b.Activated:Connect(fn)
	return b
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function L:Init(remotes)
	self.Remotes, self.Tab = remotes, "Eggs"
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "Lobby", ResetOnSpawn = false, DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	self.Gui = gui
	local scale = new("UIScale", gui, {Scale = 1})
	local function rescale()
		local size = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 700), 0.62, 1.15)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- 위: 캠프 이름 + 코인
	local top = panel(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(360, 56)})
	T.bind(label(top, "", {Size = UDim2.new(1, 0, 0, 30), Font = TITLE, TextSize = 22}), "lobby.title")
	self.TopInfo = label(top, "", {Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 22), TextSize = 13, TextColor3 = COL.Muted})

	-- 아래 가운데: 혼자 바로 출발 (1분 안에 놀기)
	self.SoloButton = button(gui, T.t("lobby.solo"), {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(300, 64),
		TextSize = 26, TextScaled = true, BackgroundColor3 = COL.Green}, function()
		if self.Data and self.Data.Solo then self:Send("CancelSolo") else self:Send("Solo") end
	end)
	self.SoloHint = label(gui, "", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -38),
		Size = UDim2.fromOffset(460, 22), TextSize = 14, TextStrokeTransparency = 0.4})
	T.bind(self.SoloHint, "lobby.soloHint")
	self.Pulse = 0

	-- 방 카드 (수레에 타 있을 때)
	self.RoomCard = panel(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -140), Size = UDim2.fromOffset(420, 132), Visible = false})
	self.RoomTitle = label(self.RoomCard, "", {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), Font = TITLE, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left})
	self.RoomNames = label(self.RoomCard, "", {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 20), TextSize = 13, TextColor3 = COL.Muted,
		TextXAlignment = Enum.TextXAlignment.Left})
	self.SizeRow = new("Frame", self.RoomCard, {Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 30), BackgroundTransparency = 1})
	new("UIListLayout", self.SizeRow, {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)})
	T.bind(label(self.SizeRow, "", {Size = UDim2.fromOffset(40, 30), TextSize = 14, LayoutOrder = 0, TextScaled = true}), "lobby.size")
	self.SizeButtons = {}
	for n = 1, LC.MaxSize do
		self.SizeButtons[n] = button(self.SizeRow, tostring(n), {Size = UDim2.fromOffset(40, 30), LayoutOrder = n, TextSize = 15}, function() self:Send("Size", n) end)
	end
	self.GoButton = button(self.RoomCard, "", {Position = UDim2.new(0, 12, 1, -40), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = COL.Green, TextSize = 18},
		function() self:Send("Go") end)
	T.bind(self.GoButton, "lobby.goNow")

	-- 왼쪽: 수레 목록
	self.RoomList = panel(gui, {Position = UDim2.fromOffset(12, 72), Size = UDim2.fromOffset(230, 44 + LC.Wagons * 26)})
	T.bind(label(self.RoomList, "", {Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 24), Font = TITLE, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left}), "lobby.wagons")
	self.RoomRows = {}
	for i = 1, LC.Wagons do
		self.RoomRows[i] = label(self.RoomList, "", {Position = UDim2.fromOffset(12, 32 + (i - 1) * 26), Size = UDim2.new(1, -24, 0, 24), TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.Muted})
	end

	-- 오른쪽: 부화장 · 내 펫 · 상점
	local side = new("Frame", gui, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.45, 0), Size = UDim2.fromOffset(120, 3 * 62), BackgroundTransparency = 1})
	new("UIListLayout", side, {Padding = UDim.new(0, 8)})
	self.EggButton = button(side, T.t("lobby.eggsButton", {n = 0}), {Size = UDim2.fromOffset(120, 54), BackgroundColor3 = Color3.fromHex("#8a6a2a"), TextScaled = true}, function() self:Open("Eggs") end)
	T.bind(button(side, "", {Size = UDim2.fromOffset(120, 54), BackgroundColor3 = Color3.fromHex("#2f8f83"), TextScaled = true}, function() self:Open("Pets") end), "lobby.petsButton")
	T.bind(button(side, "", {Size = UDim2.fromOffset(120, 54), BackgroundColor3 = Color3.fromHex("#5a4a8a"), TextScaled = true}, function() self:Open("Shop") end), "lobby.shopButton")
	-- 언어를 바꾸면 열린 창을 다시 그린다
	T.onChanged(function() self:Refresh(); if self.Panel.Visible then self:Render() end end)

	-- 패널
	self.Panel = panel(gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 470), Visible = false, ZIndex = 5})
	self.PanelTitle = label(self.Panel, "", {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 32), Font = TITLE, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left})
	button(self.Panel, "✕", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(34, 32)}, function() self.Panel.Visible = false end)
	self.Scroll = new("ScrollingFrame", self.Panel, {Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 1, -58), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new()})
	new("UIListLayout", self.Scroll, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})

	-- 알림 (로비에서는 원정 HUD 가 꺼져 있다)
	self.Toast = label(gui, "", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(520, 30), TextSize = 16,
		BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromHex("#0b1018"), Visible = false, ZIndex = 8})
	corner(self.Toast, 10)

	-- 부화 연출
	self.Reveal = new("TextButton", gui, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Text = "",
		AutoButtonColor = false, Visible = false, ZIndex = 20})
	self.RevealEgg = label(self.Reveal, "🥚", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(200, 200),
		TextSize = 150, ZIndex = 21})
	self.RevealFace = new("Frame", self.Reveal, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(240, 240),
		BackgroundColor3 = COL.Card, Visible = false, ZIndex = 21})
	corner(self.RevealFace, 120)
	self.RevealText = label(self.Reveal, "", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(560, 120),
		Font = TITLE, TextSize = 24, ZIndex = 21, TextStrokeTransparency = 0.3})
	self.Reveal.Activated:Connect(function() if self.RevealDone then self.Reveal.Visible = false end end)

	remotes.Lobby.OnClientEvent:Connect(function(kind, value)
		if kind == "State" then
			self.Data = value
			self:Refresh()
		elseif kind == "Open" then
			self:Open(value)
		end
	end)
	remotes.Notice.OnClientEvent:Connect(function(message)
		if self.Gui.Enabled then self:Notify(T.text(message)) end
	end)
	remotes.PetFX.OnClientEvent:Connect(function(kind, pet, newSpecies)
		if kind == "Hatched" and type(pet) == "table" then self:PlayHatch(pet, newSpecies) end
	end)
	RunService.RenderStepped:Connect(function(dt) self:Step(dt) end)
end

function L:Send(action, value)
	self.Remotes.LobbyAction:FireServer(action, value)
end

function L:Notify(message)
	self.Toast.Text = message
	self.Toast.Visible = true
	self.ToastToken = (self.ToastToken or 0) + 1
	local token = self.ToastToken
	task.delay(3, function() if self.ToastToken == token then self.Toast.Visible = false end end)
end

-- ===================================================================== 매 상태
function L:Refresh()
	local d = self.Data
	if not d then return end
	local ready = 0
	local elapsed = os.time() - d.Now
	for _, egg in ipairs(d.Eggs) do
		if egg.HatchAt and egg.HatchAt - (d.Now + elapsed) <= 0 then ready = ready + 1 end
	end
	self.EggButton.Text = ready > 0 and T.t("lobby.eggsReady", {n = ready}) or T.t("lobby.eggsButton", {n = #d.Eggs})
	self.TopInfo.Text = T.t("lobby.topInfo", {coins = d.Coins or 0, pets = #d.Pets, eggs = #d.Eggs, practice = d.Practice and T.t("lobby.practice") or ""})
	-- 혼자 출발 버튼
	local inRoom = d.MyRoom ~= nil
	self.SoloButton.Visible = not inRoom and not d.Launching
	self.SoloButton.Text = d.Solo and T.t("lobby.soloWait", {s = math.ceil(d.Solo)}) or T.t("lobby.solo")
	self.SoloHint.Visible = not inRoom
	-- 방 카드
	self.RoomCard.Visible = inRoom
	for i, room in ipairs(d.Rooms) do
		local row = self.RoomRows[i]
		if row then
			row.Text = room.Count == 0 and T.t("lobby.rowEmpty", {n = room.Id})
				or T.t("lobby.row", {n = room.Id, have = room.Count, size = room.Size,
					time = room.Launching and T.t("lobby.go") or T.t("fmt.seconds", {s = math.ceil(room.LaunchIn or 0)})})
			row.TextColor3 = room.Id == d.MyRoom and COL.Mint or (room.Count > 0 and COL.Text or COL.Muted)
		end
		if room.Id == d.MyRoom then
			self.RoomTitle.Text = T.t("lobby.roomTitle", {n = room.Id, have = room.Count, size = room.Size,
				time = room.Launching and T.t("lobby.go") or T.t("lobby.leavesIn", {s = math.ceil(room.LaunchIn or 0)})})
			self.RoomNames.Text = table.concat(room.Names, ", ") .. (d.Host and T.t("lobby.hostTag") or "")
			for n, b in ipairs(self.SizeButtons) do
				b.BackgroundColor3 = n == room.Size and COL.Green or COL.Card2
				b.Active, b.AutoButtonColor = d.Host, d.Host
			end
			self.SizeRow.Visible = d.Host
			self.GoButton.Visible = d.Host
		end
	end
	if self.Panel.Visible then
		local signature = self:Signature()
		if signature ~= self.Built then self:Render() else self:Tick() end
	end
end

function L:Step(dt)
	self.Pulse = self.Pulse + dt
	if self.SoloButton.Visible and not (self.Data and self.Data.Solo) then
		self.SoloButton.Size = UDim2.fromOffset(300 + math.sin(self.Pulse * 3) * 8, 64 + math.sin(self.Pulse * 3) * 2)
	end
	if self.Panel.Visible and self.Tab == "Eggs" then
		self.TickAcc = (self.TickAcc or 0) + dt
		if self.TickAcc > 0.5 then self.TickAcc = 0; self:Tick() end
	end
end

-- ===================================================================== 패널
function L:Open(tab)
	self.Tab = tab or self.Tab
	self.Panel.Visible = true
	self:Render()
end

function L:Signature()
	local d = self.Data
	local parts = {self.Tab}
	if self.Tab == "Eggs" then
		for _, egg in ipairs(d.Eggs) do table.insert(parts, egg.Id .. tostring(egg.HatchAt)) end
	elseif self.Tab == "Pets" then
		for _, pet in ipairs(d.Pets) do table.insert(parts, pet.Uid .. tostring(pet.InParty) .. tostring(pet.Nickname) .. tostring(pet.Favorite)) end
	else
		table.insert(parts, tostring(d.Coins))
		for _, id in ipairs(Shop.Order) do table.insert(parts, tostring(d.Perks and d.Perks[id])) end
	end
	return table.concat(parts, "|")
end

function L:Row(height)
	local row = new("Frame", self.Scroll, {Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = COL.Card, BorderSizePixel = 0, LayoutOrder = #self.Rows + 1})
	corner(row, 12)
	table.insert(self.Rows, row)
	return row
end

function L:Render()
	local d = self.Data
	if not d then return end
	for _, child in ipairs(self.Scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	self.Rows, self.EggRows = {}, {}
	if self.Tab == "Eggs" then
		local incubating = 0
		for _, egg in ipairs(d.Eggs) do if egg.HatchAt then incubating = incubating + 1 end end
		self.PanelTitle.Text = T.t("eggs.title", {n = incubating, slots = d.Slots})
		for _, egg in ipairs(d.Eggs) do
			local spec = EC.Kinds[egg.Kind]
			local row = self:Row(76)
			local icon = label(row, spec.Icon, {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(60, 60), TextSize = 40, BackgroundTransparency = 0,
				BackgroundColor3 = Color3.fromHex(spec.Color):Lerp(COL.Card, 0.6)})
			corner(icon, 30)
			local info = label(row, "", {Position = UDim2.fromOffset(78, 6), Size = UDim2.new(1, -250, 1, -12), TextXAlignment = Enum.TextXAlignment.Left})
			local act = button(row, "", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 48), TextSize = 16}, function()
				local now = d.Now + (os.time() - d.Now)
				if not egg.HatchAt then self:Send("Incubate", egg.Id)
				elseif egg.HatchAt <= now then self:Send("Hatch", egg.Id) end
			end)
			table.insert(self.EggRows, {Egg = egg, Info = info, Button = act, Spec = spec})
		end
		if #d.Eggs == 0 then
			local row = self:Row(90)
			label(row, T.t("eggs.none", {n = EC.CommonNights}), {Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -24, 1, -12), TextColor3 = COL.Muted})
		end
		self:Tick()
	elseif self.Tab == "Pets" then
		self.PanelTitle.Text = T.t("lobbypets.title", {n = #d.Pets, party = #d.Party, max = P.ActiveLimit})
		for _, pet in ipairs(d.Pets) do
			local spec = P.Species[pet.SpeciesId]
			local trait = pet.Trait and P.Traits[pet.Trait]
			local row = self:Row(150)
			local face = new("Frame", row, {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = COL.Card2, BorderSizePixel = 0})
			corner(face, 42)
			Portrait.make(face, pet.SpeciesId, {Size = UDim2.fromScale(1.2, 1.2), Position = UDim2.fromScale(-0.1, -0.15)})
			local nick = (pet.Nickname and pet.Nickname ~= "") and (pet.Nickname .. " · ") or ""
			label(row, T.t("lobbypets.info", {party = pet.InParty and "⚔ " or "", shiny = pet.Shiny and T.t("pets.shiny") or "", nick = nick,
				name = T.text(PR.name(pet.SpeciesId, pet.Stage, P)), lv = pet.Level, stars = PR.starText(pet.Stars),
				trait = trait and (trait.Icon .. " " .. T.t("trait." .. pet.Trait) .. " (" .. T.t("traitDesc." .. pet.Trait) .. ")") or "",
				element = T.t(ELEMENT[spec.Element]), role = T.t("role." .. spec.Role), power = pet.Power}), {Position = UDim2.fromOffset(100, 6), Size = UDim2.new(1, -108, 0, 84), TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = pet.Shiny and COL.Gold or COL.Text})
			button(row, T.t(pet.InParty and "pets.bench" or "lobbypets.deploy"), {Position = UDim2.new(0, 8, 1, -48), Size = UDim2.new(0.3, -8, 0, 40),
				BackgroundColor3 = pet.InParty and COL.Card2 or COL.Green, TextSize = 14}, function()
				local party = table.clone(d.Party)
				local at = table.find(party, pet.Uid)
				if at then table.remove(party, at) elseif #party < P.ActiveLimit then table.insert(party, pet.Uid) else self:Notify(T.t("lobbypets.partyFull", {n = P.ActiveLimit})) return end
				self:Send("Party", party)
			end)
			local box = new("TextBox", row, {Position = UDim2.new(0.3, 4, 1, -48), Size = UDim2.new(0.44, -8, 0, 40), Text = "", PlaceholderText = T.t("pets.namePlaceholder", {n = P.NicknameMax}),
				ClearTextOnFocus = false, Font = BODY, TextSize = 14, TextColor3 = COL.Text, PlaceholderColor3 = COL.Muted, BackgroundColor3 = COL.Card2, BorderSizePixel = 0})
			corner(box, 10)
			button(row, T.t("lobbypets.saveName"), {Position = UDim2.new(0.74, 0, 1, -48), Size = UDim2.new(0.26, -8, 0, 40), BackgroundColor3 = COL.Purple, TextSize = 14}, function()
				self:Send("Rename", {Uid = pet.Uid, Name = box.Text})
			end)
		end
	else
		self.PanelTitle.Text = T.t("lobbyshop.title", {coins = d.Coins or 0})
		local intro = self:Row(50)
		label(intro, T.t("lobbyshop.intro"), {Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 1, -8),
			TextColor3 = COL.Muted, TextSize = 13})
		for _, id in ipairs(Shop.Order) do
			local perk = Shop.Perks[id]
			local owned = d.Perks and d.Perks[id]
			local row = self:Row(64)
			label(row, perk.Icon, {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(48, 48), TextSize = 30})
			label(row, T.t("perk." .. id) .. "\n" .. (owned and T.t("shop.owned") or ("🪙 " .. perk.Cost)), {Position = UDim2.fromOffset(64, 6), Size = UDim2.new(1, -240, 1, -12),
				TextXAlignment = Enum.TextXAlignment.Left})
			if not owned then
				button(row, T.t("shop.unlock"), {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 44),
					BackgroundColor3 = (d.Coins or 0) >= perk.Cost and Color3.fromHex("#8a6a2a") or COL.Card2}, function() self:Send("Perk", id) end)
			end
		end
	end
	self.Built = self:Signature()
end

-- 부화 타이머 글자만 새로 쓴다
function L:Tick()
	local d = self.Data
	if not d or self.Tab ~= "Eggs" or not self.EggRows then return end
	local now = d.Now + (os.time() - d.Now)
	local incubating = 0
	for _, egg in ipairs(d.Eggs) do if egg.HatchAt then incubating = incubating + 1 end end
	for _, row in ipairs(self.EggRows) do
		local egg, spec = row.Egg, row.Spec
		local name = T.t("egg." .. egg.Kind)
		if not egg.HatchAt then
			row.Info.Text = T.t("eggs.idle", {name = name, time = clock(spec.HatchSeconds)})
			row.Button.Text = T.t(incubating < d.Slots and "eggs.put" or "eggs.full")
			row.Button.BackgroundColor3 = incubating < d.Slots and Color3.fromHex("#8a6a2a") or COL.Card2
		elseif egg.HatchAt > now then
			row.Info.Text = T.t("eggs.warming", {name = name})
			row.Button.Text = "⏳ " .. clock(egg.HatchAt - now)
			row.Button.BackgroundColor3 = COL.Card2
		else
			row.Info.Text = T.t("eggs.ready", {name = name})
			row.Button.Text = T.t("eggs.hatch")
			row.Button.BackgroundColor3 = COL.Green
		end
	end
end

-- ===================================================================== 부화 연출: 알이 흔들리다 깨지고 펫이 나온다
function L:PlayHatch(pet, newSpecies)
	self.Panel.Visible = false
	self.Reveal.Visible, self.RevealDone = true, false
	local egg = EC.Kinds[pet.HatchedFrom] or EC.Kinds.Common
	self.RevealEgg.Text, self.RevealEgg.Visible, self.RevealFace.Visible = egg.Icon, true, false
	self.RevealText.Text = T.t("hatch.shaking", {name = T.t("egg." .. (EC.Kinds[pet.HatchedFrom] and pet.HatchedFrom or "Common"))})
	self.RevealText.TextColor3 = COL.Text
	task.spawn(function()
		for i = 1, 14 do
			self.RevealEgg.Rotation = math.sin(i * 1.7) * (8 + i * 1.2)
			task.wait(0.07 + i * 0.004)
		end
		self.RevealEgg.Rotation = 0
		self.RevealEgg.Visible = false
		for _, child in ipairs(self.RevealFace:GetChildren()) do
			if not child:IsA("UICorner") then child:Destroy() end
		end
		Portrait.make(self.RevealFace, pet.SpeciesId, {Size = UDim2.fromScale(1.2, 1.2), Position = UDim2.fromScale(-0.1, -0.15)})
		self.RevealFace.Visible = true
		self.RevealFace.Size = UDim2.fromOffset(40, 40)
		TweenService:Create(self.RevealFace, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(240, 240)}):Play()
		local trait = pet.Trait and P.Traits[pet.Trait]
		self.RevealText.Text = T.t("hatch.born", {shiny = pet.Shiny and T.t("hatch.shiny") or "", name = T.text(PR.name(pet.SpeciesId, 1, P)),
			stars = PR.starText(pet.Stars), trait = trait and (trait.Icon .. " " .. T.t("trait." .. pet.Trait)) or "",
			new = newSpecies and T.t("hatch.newDex") or ""})
		self.RevealText.TextColor3 = pet.Shiny and COL.Gold or ((pet.Stars or 0) >= 4 and COL.Mint or COL.Text)
		self.RevealDone = true
	end)
end

return L
