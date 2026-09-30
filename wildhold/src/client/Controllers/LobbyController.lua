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

local L = {}
local player = Players.LocalPlayer
local TITLE, BODY = Enum.Font.FredokaOne, Enum.Font.GothamBold
local COL = {Panel = Color3.fromHex("#16202e"), Card = Color3.fromHex("#1f2b3b"), Card2 = Color3.fromHex("#273548"), Text = Color3.fromHex("#f1f5fa"),
	Muted = Color3.fromHex("#aab6c6"), Mint = Color3.fromHex("#7be0b6"), Gold = Color3.fromHex("#ffd36b"), Green = Color3.fromHex("#3fae6a"),
	Purple = Color3.fromHex("#5a4a8a"), Red = Color3.fromHex("#b0553a")}
local ELEMENT = {Leaf = "🌿 풀", Ember = "🔥 불", Tide = "💧 물"}

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
	label(top, "🏕 WILDHOLD 캠프", {Size = UDim2.new(1, 0, 0, 30), Font = TITLE, TextSize = 22})
	self.TopInfo = label(top, "", {Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 22), TextSize = 13, TextColor3 = COL.Muted})

	-- 아래 가운데: 혼자 바로 출발 (1분 안에 놀기)
	self.SoloButton = button(gui, "▶ 혼자 바로 출발", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(300, 64),
		TextSize = 26, BackgroundColor3 = COL.Green}, function()
		if self.Data and self.Data.Solo then self:Send("CancelSolo") else self:Send("Solo") end
	end)
	self.SoloHint = label(gui, "친구와 가려면 북쪽의 🚚 원정 수레에 올라타세요", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -38),
		Size = UDim2.fromOffset(460, 22), TextSize = 14, TextStrokeTransparency = 0.4})
	self.Pulse = 0

	-- 방 카드 (수레에 타 있을 때)
	self.RoomCard = panel(gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -140), Size = UDim2.fromOffset(420, 132), Visible = false})
	self.RoomTitle = label(self.RoomCard, "", {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), Font = TITLE, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left})
	self.RoomNames = label(self.RoomCard, "", {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 20), TextSize = 13, TextColor3 = COL.Muted,
		TextXAlignment = Enum.TextXAlignment.Left})
	self.SizeRow = new("Frame", self.RoomCard, {Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 30), BackgroundTransparency = 1})
	new("UIListLayout", self.SizeRow, {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6)})
	label(self.SizeRow, "인원", {Size = UDim2.fromOffset(40, 30), TextSize = 14, LayoutOrder = 0})
	self.SizeButtons = {}
	for n = 1, LC.MaxSize do
		self.SizeButtons[n] = button(self.SizeRow, tostring(n), {Size = UDim2.fromOffset(40, 30), LayoutOrder = n, TextSize = 15}, function() self:Send("Size", n) end)
	end
	self.GoButton = button(self.RoomCard, "▶ 지금 출발", {Position = UDim2.new(0, 12, 1, -40), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = COL.Green, TextSize = 18},
		function() self:Send("Go") end)

	-- 왼쪽: 수레 목록
	self.RoomList = panel(gui, {Position = UDim2.fromOffset(12, 72), Size = UDim2.fromOffset(230, 44 + LC.Wagons * 26)})
	label(self.RoomList, "🚚 원정 수레", {Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 24), Font = TITLE, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left})
	self.RoomRows = {}
	for i = 1, LC.Wagons do
		self.RoomRows[i] = label(self.RoomList, "", {Position = UDim2.fromOffset(12, 32 + (i - 1) * 26), Size = UDim2.new(1, -24, 0, 24), TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COL.Muted})
	end

	-- 오른쪽: 부화장 · 내 펫 · 상점
	local side = new("Frame", gui, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.45, 0), Size = UDim2.fromOffset(120, 3 * 62), BackgroundTransparency = 1})
	new("UIListLayout", side, {Padding = UDim.new(0, 8)})
	self.EggButton = button(side, "🥚 부화장", {Size = UDim2.fromOffset(120, 54), BackgroundColor3 = Color3.fromHex("#8a6a2a")}, function() self:Open("Eggs") end)
	button(side, "🐾 내 펫", {Size = UDim2.fromOffset(120, 54), BackgroundColor3 = Color3.fromHex("#2f8f83")}, function() self:Open("Pets") end)
	button(side, "🪙 보급", {Size = UDim2.fromOffset(120, 54), BackgroundColor3 = Color3.fromHex("#5a4a8a")}, function() self:Open("Shop") end)

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
		if self.Gui.Enabled then self:Notify(message) end
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
	self.EggButton.Text = ready > 0 and ("🐣 부화장 (" .. ready .. ")") or ("🥚 부화장 " .. #d.Eggs)
	self.TopInfo.Text = string.format("🪙 %d  ·  🐾 펫 %d마리  ·  🥚 알 %d개%s", d.Coins or 0, #d.Pets, #d.Eggs, d.Practice and "  ·  연습 모드(저장 안 됨)" or "")
	-- 혼자 출발 버튼
	local inRoom = d.MyRoom ~= nil
	self.SoloButton.Visible = not inRoom and not d.Launching
	self.SoloButton.Text = d.Solo and string.format("출발 준비 %.0f… (취소)", math.ceil(d.Solo)) or "▶ 혼자 바로 출발"
	self.SoloHint.Visible = not inRoom
	-- 방 카드
	self.RoomCard.Visible = inRoom
	for i, room in ipairs(d.Rooms) do
		local row = self.RoomRows[i]
		if row then
			row.Text = room.Count == 0 and string.format("수레 %d · 비어 있음", room.Id)
				or string.format("수레 %d · 👥 %d/%d · %s", room.Id, room.Count, room.Size, room.Launching and "출발!" or (math.ceil(room.LaunchIn or 0) .. "초"))
			row.TextColor3 = room.Id == d.MyRoom and COL.Mint or (room.Count > 0 and COL.Text or COL.Muted)
		end
		if room.Id == d.MyRoom then
			self.RoomTitle.Text = string.format("🚚 원정 수레 %d · 👥 %d/%d · %s", room.Id, room.Count, room.Size,
				room.Launching and "출발!" or (math.ceil(room.LaunchIn or 0) .. "초 뒤 출발"))
			self.RoomNames.Text = table.concat(room.Names, ", ") .. (d.Host and "  ·  👑 방장" or "")
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
		self.PanelTitle.Text = string.format("🥚 부화장  ·  부화 중 %d/%d", incubating, d.Slots)
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
			label(row, "알이 없습니다.\n원정에서 " .. EC.CommonNights .. "밤을 버티면 🥚 보통 알, 5밤을 모두 버티면 🌟 희귀한 알!", {Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -24, 1, -12), TextColor3 = COL.Muted})
		end
		self:Tick()
	elseif self.Tab == "Pets" then
		self.PanelTitle.Text = string.format("🐾 내 펫 %d마리  ·  출전 팀 %d/%d (다음 원정에 데려감)", #d.Pets, #d.Party, P.ActiveLimit)
		for _, pet in ipairs(d.Pets) do
			local spec = P.Species[pet.SpeciesId]
			local trait = pet.Trait and P.Traits[pet.Trait]
			local row = self:Row(150)
			local face = new("Frame", row, {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = COL.Card2, BorderSizePixel = 0})
			corner(face, 42)
			Portrait.make(face, pet.SpeciesId, {Size = UDim2.fromScale(1.2, 1.2), Position = UDim2.fromScale(-0.1, -0.15)})
			local nick = (pet.Nickname and pet.Nickname ~= "") and (pet.Nickname .. " · ") or ""
			label(row, string.format("%s%s%s%s  Lv%d\n%s  %s\n%s · %s · ⚔ 전투력 %d", pet.InParty and "⚔ " or "", pet.Shiny and "✨빛나는 " or "", nick,
				PR.name(pet.SpeciesId, pet.Stage, P), pet.Level, PR.starText(pet.Stars), trait and (trait.Icon .. " " .. trait.Name .. " (" .. trait.Desc .. ")") or "",
				ELEMENT[spec.Element], spec.Role, pet.Power), {Position = UDim2.fromOffset(100, 6), Size = UDim2.new(1, -108, 0, 84), TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = pet.Shiny and COL.Gold or COL.Text})
			button(row, pet.InParty and "출전 해제" or "⚔ 출전 팀에", {Position = UDim2.new(0, 8, 1, -48), Size = UDim2.new(0.3, -8, 0, 40),
				BackgroundColor3 = pet.InParty and COL.Card2 or COL.Green, TextSize = 14}, function()
				local party = table.clone(d.Party)
				local at = table.find(party, pet.Uid)
				if at then table.remove(party, at) elseif #party < P.ActiveLimit then table.insert(party, pet.Uid) else self:Notify("출전 팀은 " .. P.ActiveLimit .. "마리까지 · 먼저 한 마리를 빼세요") return end
				self:Send("Party", party)
			end)
			local box = new("TextBox", row, {Position = UDim2.new(0.3, 4, 1, -48), Size = UDim2.new(0.44, -8, 0, 40), Text = "", PlaceholderText = "✏ 이름 (최대 " .. P.NicknameMax .. "자)",
				ClearTextOnFocus = false, Font = BODY, TextSize = 14, TextColor3 = COL.Text, PlaceholderColor3 = COL.Muted, BackgroundColor3 = COL.Card2, BorderSizePixel = 0})
			corner(box, 10)
			button(row, "✔ 이름", {Position = UDim2.new(0.74, 0, 1, -48), Size = UDim2.new(0.26, -8, 0, 40), BackgroundColor3 = COL.Purple, TextSize = 14}, function()
				self:Send("Rename", {Uid = pet.Uid, Name = box.Text})
			end)
		end
	else
		self.PanelTitle.Text = string.format("🪙 보급 상점  ·  🪙 %d", d.Coins or 0)
		local intro = self:Row(50)
		label(intro, "해금한 보급은 다음 원정부터 매번 받아요 · 코인은 원정에서 밤을 버티면 받아요", {Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 1, -8),
			TextColor3 = COL.Muted, TextSize = 13})
		for _, id in ipairs(Shop.Order) do
			local perk = Shop.Perks[id]
			local owned = d.Perks and d.Perks[id]
			local row = self:Row(64)
			label(row, perk.Icon, {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(48, 48), TextSize = 30})
			label(row, perk.Name .. "\n" .. (owned and "✅ 해금 완료" or ("🪙 " .. perk.Cost)), {Position = UDim2.fromOffset(64, 6), Size = UDim2.new(1, -240, 1, -12),
				TextXAlignment = Enum.TextXAlignment.Left})
			if not owned then
				button(row, "🪙 해금", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 44),
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
		if not egg.HatchAt then
			row.Info.Text = spec.Name .. "\n부화장에 넣으면 " .. clock(spec.HatchSeconds) .. " 뒤 깨어나요"
			row.Button.Text = incubating < d.Slots and "🪺 부화장에 넣기" or "부화장 가득"
			row.Button.BackgroundColor3 = incubating < d.Slots and Color3.fromHex("#8a6a2a") or COL.Card2
		elseif egg.HatchAt > now then
			row.Info.Text = spec.Name .. "\n🔥 따뜻하게 품는 중… 원정에 나가 있어도 시간이 흘러요"
			row.Button.Text = "⏳ " .. clock(egg.HatchAt - now)
			row.Button.BackgroundColor3 = COL.Card2
		else
			row.Info.Text = spec.Name .. "\n✨ 알이 흔들려요! 깨워 보세요"
			row.Button.Text = "🐣 깨우기!"
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
	self.RevealText.Text = egg.Name .. " 이(가) 흔들려요…"
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
		self.RevealText.Text = string.format("%s%s 이(가) 태어났어요!\n%s  ·  %s%s\n\n(누르면 닫기 · 🐾 내 펫에서 이름을 지어 주세요)",
			pet.Shiny and "✨ 빛나는 " or "", PR.name(pet.SpeciesId, 1, P), PR.starText(pet.Stars), trait and (trait.Icon .. " " .. trait.Name) or "",
			newSpecies and "  ·  📖 도감 새 종!" or "")
		self.RevealText.TextColor3 = pet.Shiny and COL.Gold or ((pet.Stars or 0) >= 4 and COL.Mint or COL.Text)
		self.RevealDone = true
	end)
end

return L
