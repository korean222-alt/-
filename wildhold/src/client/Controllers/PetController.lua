-- 펫 패널 (내 펫 / 야생 / 명령 / 제작 / 도감) + 빠른 명령 버튼 + 포획 카드.
-- 서버 액션은 기존과 같다: PetAction(Toggle/Favorite/Heal/Focus/Follow/Stay/Guard/Best/SaveTeam/LoadTeam/Register),
-- CaptureAction(wildId, 덫ID, bait), CraftAction(아이템ID 또는 "BenchUpgrade")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local P = require(RS.Shared.Config.PetConfig)
local Recipes = require(RS.Shared.Config.RecipeConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local I = require(RS.Shared.Config.ItemConfig)
local PR = require(RS.Shared.Modules.PetRules)
local Shop = require(RS.Shared.Config.ShopConfig)
local Defense = require(RS.Shared.Config.DefenseConfig)
local Portrait = require(script.Parent.Portrait)
local L = require(RS.Shared.Modules.Locale)

local Controller = {}
local TITLE, BODY = Enum.Font.FredokaOne, Enum.Font.GothamBold
local COL = {Back = Color3.fromHex("#141d2a"), Card = Color3.fromHex("#1f2b3b"), Card2 = Color3.fromHex("#273548"), Text = Color3.fromHex("#f1f5fa"),
	Muted = Color3.fromHex("#aab6c6"), Mint = Color3.fromHex("#7be0b6"), Gold = Color3.fromHex("#ffd36b"), Red = Color3.fromHex("#ff8a8a")}
local ELEMENT = {Leaf = {"element.Leaf", "#7ed36a"}, Ember = {"element.Ember", "#ff9a4a"}, Tide = {"element.Tide", "#6fc3ff"}}
local ICON = R.Icons

local function create(kind, parent, props)
	local node = Instance.new(kind)
	for key, value in pairs(props) do node[key] = value end
	node.Parent = parent
	return node
end

local function corner(parent, r)
	create("UICorner", parent, {CornerRadius = UDim.new(0, r or 12)})
end

local function label(parent, text, pos, size, props)
	local l = create("TextLabel", parent, {Text = text, Position = pos, Size = size, Font = BODY, TextSize = 14, TextColor3 = COL.Text,
		TextWrapped = true, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left})
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

local function button(parent, text, pos, size, fn, color)
	local node = create("TextButton", parent, {Text = text, Position = pos, Size = size, TextSize = 14, Font = TITLE, TextColor3 = COL.Text,
		BackgroundColor3 = color or COL.Card2, BorderSizePixel = 0, AutoButtonColor = true})
	corner(node, 10)
	create("UIStroke", node, {Color = Color3.new(0, 0, 0), Transparency = 0.6, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	node.Activated:Connect(fn)
	return node
end

local function costText(cost)
	local parts = {}
	for _, material in ipairs(R.Order) do
		if cost[material] then parts[#parts + 1] = ICON[material] .. " " .. cost[material] end
	end
	return table.concat(parts, "  ")
end

function Controller:Init(remotes)
	self.Remotes, self.Tab, self.Filter, self.Rows = remotes, "Pets", "", {}
	local player = Players.LocalPlayer
	self.Gui = create("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "PetBook", ResetOnSpawn = false, DisplayOrder = 25})
	local scale = create("UIScale", self.Gui, {Scale = 1})
	local function rescale()
		local size = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 700), 0.62, 1.15)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- 오른쪽: 펫 버튼 + 빠른 명령
	self.OpenButton = button(self.Gui, "", UDim2.new(1, -96, 1, -270), UDim2.fromOffset(78, 78), function() self:Open("Pets") end, Color3.fromHex("#2f8f83"))
	self.OpenButton.TextSize = 18
	L.bind(self.OpenButton, "pets.open")
	corner(self.OpenButton, 39)
	self.SaveBadge = label(self.OpenButton, "", UDim2.new(0, -40, 1, 2), UDim2.new(1, 80, 0, 16), {TextSize = 11, TextColor3 = COL.Gold,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4})
	self.Quick = create("Frame", self.Gui, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.47, 0), Size = UDim2.fromOffset(92, 240),
		BackgroundTransparency = 1})
	create("UIListLayout", self.Quick, {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right})
	self.QuickButtons = {}
	for _, spec in ipairs({{"Focus", "quick.Focus", "#b0553a"}, {"Follow", "quick.Follow", "#2f6f8f"}, {"Guard", "quick.Guard", "#4f5f8f"}, {"Craft", "quick.Craft", "#8a5a2f"}}) do
		local b = button(self.Quick, "", UDim2.new(), UDim2.fromOffset(92, 52), function() self:QuickCommand(spec[1]) end, Color3.fromHex(spec[3]))
		b.TextSize, b.TextWrapped = 15, true
		L.bind(b, spec[2])
		self.QuickButtons[spec[1]] = b
	end

	-- 패널
	self.Panel = create("Frame", self.Gui, {Name = "Panel", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.92, 0.84), BackgroundColor3 = COL.Back, BorderSizePixel = 0})
	create("UISizeConstraint", self.Panel, {MaxSize = Vector2.new(720, 640)})
	corner(self.Panel, 18)
	create("UIStroke", self.Panel, {Color = COL.Mint, Transparency = 0.6, Thickness = 2})
	self.Status = label(self.Panel, "", UDim2.fromOffset(16, 8), UDim2.new(1, -90, 0, 44), {Font = TITLE, TextSize = 18})
	button(self.Panel, "✕", UDim2.new(1, -56, 0, 8), UDim2.fromOffset(46, 42), function() self:Close() end, Color3.fromHex("#5b2f3a"))
	self.TabButtons = {}
	local tabs = {"Pets", "Wild", "Orders", "Craft", "Dex", "Shop"}
	for index, tab in ipairs(tabs) do
		local w = 1 / #tabs
		self.TabButtons[tab] = button(self.Panel, "", UDim2.new((index - 1) * w, 6, 0, 58), UDim2.new(w, -8, 0, 42), function()
			self.Tab = tab
			self:Render()
		end)
		self.TabButtons[tab].TextScaled = true
		L.bind(self.TabButtons[tab], "tab." .. tab)
	end
	self.Search = create("TextBox", self.Panel, {PlaceholderText = "", Text = "", ClearTextOnFocus = false, Position = UDim2.new(0, 10, 0, 108),
		Size = UDim2.new(1, -120, 0, 40), BackgroundColor3 = COL.Card, TextColor3 = COL.Text, PlaceholderColor3 = COL.Muted, TextSize = 14, Font = BODY})
	corner(self.Search, 10)
	L.bind(self.Search, "pets.search", nil, "PlaceholderText")
	self.Search:GetPropertyChangedSignal("Text"):Connect(function() self.Filter = string.lower(self.Search.Text); self:Render() end)
	self.FavButton = button(self.Panel, "", UDim2.new(1, -104, 0, 108), UDim2.fromOffset(94, 40), function() self.Favorites = not self.Favorites; self:Render() end)
	self.FavButton.TextScaled = true
	L.bind(self.FavButton, "pets.favFilter")
	-- 언어를 바꾸면 열린 창을 다시 그린다
	L.onChanged(function() if self.Panel.Visible then self:Render() end end)
	self.Scroll = create("ScrollingFrame", self.Panel, {Position = UDim2.fromOffset(10, 156), Size = UDim2.new(1, -20, 1, -212), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarImageColor3 = COL.Mint})
	create("UIListLayout", self.Scroll, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
	self.Footer = label(self.Panel, "", UDim2.new(0, 14, 1, -50), UDim2.new(1, -28, 0, 44), {TextColor3 = COL.Muted, TextSize = 13})

	remotes.State.OnClientEvent:Connect(function(data)
		self.Data = data
		self.OpenButton.Visible = data.Stage >= 5
		self.Quick.Visible = data.Stage >= 5 and not self.Panel.Visible
		self.SaveBadge.Text = L.t(L.has("save.short." .. tostring(data.SaveStatus)) and ("save.short." .. data.SaveStatus) or "ui.connecting")
		local wild = data.Wild and data.Wild[1]
		self.QuickButtons.Focus.Visible = data.Phase == "Day" and wild ~= nil and wild.Distance < 60
		if self.Panel.Visible then self:Refresh() end
	end)
	remotes.PetFX.OnClientEvent:Connect(function(kind, name, seconds)
		if kind == "OpenCraft" then
			self.Station = name
			self:Open("Craft")
		elseif kind == "Shake" then
			self:Close()
			self:CaptureCard(name and L.text(name), seconds)
		elseif kind == "Capture" then
			task.delay(1.2, function() self:Open("Pets"); self.Footer.Text = L.t("pets.caughtFooter", {name = name or ""}) end)
		end
	end)
end

function Controller:QuickCommand(action)
	if action == "Focus" then
		local wild = self.Data and self.Data.Wild and self.Data.Wild[1]
		if wild then self:Send("Focus", wild.Id) end
	elseif action == "Craft" then
		self.Station = nil
		self:Open("Craft")
	else
		self:Send(action)
	end
end

-- 포획 카드: 바구니가 3번 흔들린다
function Controller:CaptureCard(name, seconds)
	if self.CaptureOverlay then self.CaptureOverlay:Destroy() end
	local overlay = create("Frame", self.Gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 130), Size = UDim2.fromOffset(300, 120),
		BackgroundColor3 = COL.Back, BorderSizePixel = 0})
	corner(overlay, 18)
	create("UIStroke", overlay, {Color = COL.Gold, Thickness = 2, Transparency = 0.2})
	label(overlay, L.t("capture.trying", {name = name or L.t("capture.wildPet")}), UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 26), {Font = TITLE, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center})
	local icon = label(overlay, "🧺", UDim2.new(0.5, -28, 0, 34), UDim2.fromOffset(56, 50), {TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center})
	local dots = label(overlay, "○ ○ ○", UDim2.new(0, 0, 1, -30), UDim2.new(1, 0, 0, 24), {Font = TITLE, TextSize = 18, TextColor3 = COL.Gold,
		TextXAlignment = Enum.TextXAlignment.Center})
	self.CaptureOverlay = overlay
	task.spawn(function()
		local duration = seconds or 2.4
		for i = 1, 3 do
			if not overlay.Parent then return end
			dots.Text = string.rep("● ", i) .. string.rep("○ ", 3 - i)
			TweenService:Create(icon, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true), {Rotation = i % 2 == 0 and -20 or 20}):Play()
			task.wait(duration / 3)
		end
		task.wait(0.4)
		if overlay.Parent then overlay:Destroy() end
	end)
end

function Controller:Open(tab)
	self.Tab = tab or self.Tab
	self.Panel.Visible = true
	self.Quick.Visible = false
	Players.LocalPlayer:SetAttribute("PetMenuOpen", true)
	self.Panel.Size = UDim2.fromScale(0.86, 0.78)
	TweenService:Create(self.Panel, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Size = UDim2.fromScale(0.92, 0.84)}):Play()
	self:Render()
end

function Controller:Close()
	self.Panel.Visible = false
	self.Quick.Visible = self.Data ~= nil and self.Data.Stage >= 5
	Players.LocalPlayer:SetAttribute("PetMenuOpen", false)
end

function Controller:Send(action, value) self.Remotes.PetAction:FireServer(action, value) end

function Controller:Row(height)
	local row = create("Frame", self.Scroll, {Size = UDim2.new(1, -8, 0, height or 120), BackgroundColor3 = COL.Card, BorderSizePixel = 0, LayoutOrder = #self.Rows + 1})
	corner(row, 14)
	return row
end

function Controller:Face(row, species, size, silhouette)
	local face = create("Frame", row, {Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(size, size), BackgroundColor3 = COL.Card2, BorderSizePixel = 0})
	corner(face, size / 2)
	Portrait.make(face, species, {Size = UDim2.fromScale(1.2, 1.2), Position = UDim2.fromScale(-0.1, -0.15)}, silhouette)
	return face
end

function Controller:Render()
	if not self.Scroll or not self.Data then return end
	for _, child in ipairs(self.Scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	self.Rows = {}
	for key, b in pairs(self.TabButtons) do
		b.BackgroundColor3 = key == self.Tab and Color3.fromHex("#2f8f83") or COL.Card2
	end
	local searching = self.Tab == "Pets"
	self.Search.Visible, self.FavButton.Visible = searching, searching
	self.Scroll.Position = UDim2.fromOffset(10, searching and 156 or 108)
	self.Scroll.Size = UDim2.new(1, -20, 1, searching and -212 or -164)
	local d = self.Data
	if self.Tab == "Pets" then
		for _, pet in ipairs(d.Pets or {}) do
			local spec = P.Species[pet.SpeciesId]
			local searchable = (pet.Nickname or "") .. L.text(PR.name(pet.SpeciesId, pet.Stage, P)) .. L.t("role." .. spec.Role) .. L.t(ELEMENT[spec.Element][1])
			if (not self.Favorites or pet.Favorite) and string.find(string.lower(searchable), self.Filter, 1, true) then
				local row = self:Row(196)
				self:Face(row, pet.SpeciesId, 84)
				local info = label(row, "", UDim2.fromOffset(102, 6), UDim2.new(1, -110, 0, 100))
				-- 이름 짓기 (서버가 Roblox 필터를 거친다)
				local nameBox = create("TextBox", row, {Position = UDim2.new(0, 8, 1, -96), Size = UDim2.new(0.64, -10, 0, 38), Text = "",
					PlaceholderText = L.t("pets.namePlaceholder", {n = P.NicknameMax}), ClearTextOnFocus = false, Font = BODY, TextSize = 14,
					TextColor3 = COL.Text, PlaceholderColor3 = COL.Muted, BackgroundColor3 = COL.Card2, BorderSizePixel = 0})
				corner(nameBox, 10)
				button(row, L.t("pets.saveName"), UDim2.new(0.64, 2, 1, -96), UDim2.new(0.36, -10, 0, 38), function()
					self:Send("Rename", {Uid = pet.Uid, Name = nameBox.Text})
				end, Color3.fromHex("#5a4a8a"))
				local toggle = button(row, L.t(pet.Active and "pets.bench" or "pets.deploy"), UDim2.new(0, 8, 1, -50), UDim2.new(0.36, -10, 0, 42),
					function() self:Send("Toggle", pet.Uid) end, pet.Active and COL.Card2 or Color3.fromHex("#2f8f83"))
				button(row, L.t(pet.Favorite and "pets.faved" or "pets.fav"), UDim2.new(0.36, 2, 1, -50), UDim2.new(0.32, -6, 0, 42), function() self:Send("Favorite", pet.Uid) end)
				button(row, L.t("pets.snack"), UDim2.new(0.68, 2, 1, -50), UDim2.new(0.32, -10, 0, 42), function() self:Send("Heal", pet.Uid) end)
				self.Rows[#self.Rows + 1] = {Key = pet.Uid, Info = info, Toggle = toggle}
			end
		end
	elseif self.Tab == "Wild" then
		for _, wild in ipairs(d.Wild or {}) do
			local row = self:Row(168)
			self:Face(row, wild.SpeciesId, 84)
			local info = label(row, "", UDim2.fromOffset(102, 4), UDim2.new(1, -110, 0, 108))
			button(row, L.t("wildtab.weaken"), UDim2.new(0, 8, 1, -50), UDim2.new(0.36, -10, 0, 42), function() self:Send("Focus", wild.Id); self:Close() end, Color3.fromHex("#b0553a"))
			button(row, L.t("wildtab.trap"), UDim2.new(0.36, 2, 1, -50), UDim2.new(0.3, -6, 0, 42), function() self.Remotes.CaptureAction:FireServer(wild.Id, "Trap", false) end)
			button(row, L.t("wildtab.better"), UDim2.new(0.66, 2, 1, -50), UDim2.new(0.34, -10, 0, 42), function() self.Remotes.CaptureAction:FireServer(wild.Id, "BetterTrap", true) end,
				Color3.fromHex("#8a6a2a"))
			self.Rows[#self.Rows + 1] = {Key = wild.Id, Info = info}
		end
	elseif self.Tab == "Orders" then
		for _, a in ipairs({"Follow", "Stay", "Guard", "Best", "Register"}) do
			local row = self:Row(52)
			button(row, L.t("order." .. a), UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 44), function() self:Send(a) end)
			self.Rows[#self.Rows + 1] = {}
		end
		for i = 1, 3 do
			local row = self:Row(52)
			button(row, L.t("order.saveTeam", {n = i}), UDim2.fromOffset(4, 4), UDim2.new(0.5, -8, 0, 44), function() self:Send("SaveTeam", i) end)
			button(row, L.t("order.loadTeam", {n = i}), UDim2.new(0.5, 4, 0, 4), UDim2.new(0.5, -8, 0, 44), function() self:Send("LoadTeam", i) end)
			self.Rows[#self.Rows + 1] = {}
		end
	elseif self.Tab == "Craft" then
		-- 제작대 레벨 + 업그레이드 (팀 공용)
		local level = d.Bench or 0
		local nextBench = level > 0 and Defense.Workbench.Levels[level + 1]
		local head = self:Row(nextBench and 100 or 64)
		label(head, "🔨", UDim2.fromOffset(10, 6), UDim2.fromOffset(60, 44), {TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center})
		label(head, level == 0 and L.t("craft.noBench")
			or L.t("craft.benchLevel", {lv = level, next = nextBench and L.t("craft.benchNext", {lv = level + 1, cost = costText(nextBench.Cost)}) or L.t("craft.benchMax")}),
			UDim2.fromOffset(76, 4), UDim2.new(1, -84, 0, 54))
		if nextBench then
			button(head, L.t("craft.upgradeBench"), UDim2.new(0, 8, 1, -48), UDim2.new(1, -16, 0, 40), function() self.Remotes.CraftAction:FireServer("BenchUpgrade") end,
				Color3.fromHex("#8a5a2f"))
		end
		self.Rows[#self.Rows + 1] = {}
		-- 모닥불에서 열면 요리를 먼저 보여준다
		local order = {}
		for _, id in ipairs(Recipes.Order) do
			if self.Station == "Campfire" and Recipes.Recipes[id].Station == "Campfire" then table.insert(order, 1, id) else table.insert(order, id) end
		end
		for _, id in ipairs(order) do
			local recipe, spec = Recipes.Recipes[id], I.Items[id]
			local row = self:Row(100)
			label(row, spec.Icon, UDim2.fromOffset(10, 8), UDim2.fromOffset(60, 44), {TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center})
			local info = label(row, "", UDim2.fromOffset(76, 4), UDim2.new(1, -84, 0, 46))
			local verb = L.t(recipe.Station == "Campfire" and "craft.cook" or (spec.Kind == "Build" and "craft.makeKit" or "craft.make"))
			local makeButton = button(row, verb, UDim2.new(0, 8, 1, -48), UDim2.new(1, -16, 0, 40), function() self.Remotes.CraftAction:FireServer(id) end, Color3.fromHex("#2f8f83"))
			self.Rows[#self.Rows + 1] = {Key = id, Info = info, Button = makeButton, Cost = costText(recipe.Cost)}
		end
	elseif self.Tab == "Shop" then
		local intro = self:Row(56)
		label(intro, L.t("shop.intro", {coins = d.Coins or 0, dex = Shop.DexReward}),
			UDim2.fromOffset(12, 4), UDim2.new(1, -24, 1, -8), {TextColor3 = COL.Muted})
		self.Rows[#self.Rows + 1] = {}
		for _, id in ipairs(Shop.Order) do
			local perk = Shop.Perks[id]
			local owned = d.Perks and d.Perks[id]
			local row = self:Row(100)
			label(row, perk.Icon, UDim2.fromOffset(10, 8), UDim2.fromOffset(60, 44), {TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center})
			label(row, string.format("%s\n%s", L.t("perk." .. id), owned and L.t("shop.owned") or ("🪙 " .. perk.Cost)), UDim2.fromOffset(76, 4), UDim2.new(1, -84, 0, 46))
			if not owned then
				button(row, L.t("shop.unlock"), UDim2.new(0, 8, 1, -48), UDim2.new(1, -16, 0, 40), function() self.Remotes.CraftAction:FireServer("Perk:" .. id) end,
					(d.Coins or 0) >= perk.Cost and Color3.fromHex("#8a6a2a") or COL.Card2)
			end
			self.Rows[#self.Rows + 1] = {}
		end
	elseif self.Tab == "Dex" then
		for _, id in ipairs(P.Order) do
			local spec = P.Species[id]
			local row = self:Row(104)
			local entry = d.Dex[id]
			local caught = entry and entry.Caught
			self:Face(row, id, 86, not (entry and entry.Seen))
			local state = L.t(caught and "dex.caught" or (entry and entry.Seen and "dex.seen" or "dex.unknown"))
			local element = ELEMENT[spec.Element]
			local seen = entry and entry.Seen
			local grows = spec.Adult and ("  →  🌟 " .. L.t("adult." .. id) .. " (Lv" .. P.EvolveLevel .. ")") or ""
			label(row, string.format("%s%s\n%s · %s\n%s\n%s", seen and L.t("species." .. id) or "???", seen and grows or "", L.t(element[1]), L.t("role." .. spec.Role), state,
				L.t("dex.stats", {hp = spec.HP, dmg = spec.Damage})),
				UDim2.fromOffset(104, 6), UDim2.new(1, -112, 1, -12))
			self.Rows[#self.Rows + 1] = {}
		end
	end
	if #self.Rows == 0 then
		local row = self:Row(90)
		label(row, L.t(self.Tab == "Wild" and "wildtab.none" or "pets.none"),
			UDim2.fromOffset(14, 6), UDim2.new(1, -28, 1, -12), {TextColor3 = COL.Muted})
	end
	self.Structure = self:Signature()
	self:Refresh(true)
end

function Controller:Signature()
	local pieces = {self.Tab}
	if self.Tab == "Pets" then
		for _, pet in ipairs(self.Data.Pets or {}) do pieces[#pieces + 1] = pet.Uid .. tostring(pet.Active) .. tostring(pet.Favorite) .. pet.Status .. tostring(pet.Nickname) end
	elseif self.Tab == "Wild" then
		local ids = {}
		for _, wild in ipairs(self.Data.Wild or {}) do ids[#ids + 1] = wild.Id end
		table.sort(ids)
		for _, id in ipairs(ids) do pieces[#pieces + 1] = id end
	elseif self.Tab == "Craft" then
		pieces[#pieces + 1] = tostring(self.Data.Bench) .. tostring(self.Station)
	elseif self.Tab == "Shop" then
		pieces[#pieces + 1] = tostring(self.Data.Coins)
		for _, id in ipairs(Shop.Order) do pieces[#pieces + 1] = tostring(self.Data.Perks and self.Data.Perks[id]) end
	elseif self.Tab == "Dex" then
		for _, id in ipairs(P.Order) do
			local e = self.Data.Dex[id]
			pieces[#pieces + 1] = id .. tostring(e and e.Caught) .. tostring(e and e.Seen)
		end
	end
	return table.concat(pieces, "|")
end

function Controller:Refresh(skip)
	if not skip and self.Structure ~= self:Signature() then self:Render(); return end
	local d = self.Data
	local equipped = 0
	for _, pet in ipairs(d.Pets or {}) do if pet.Active then equipped = equipped + 1 end end
	local saveKey = "save.long." .. tostring(d.SaveStatus)
	self.Status.Text = L.t("pets.header", {n = equipped, max = P.ActiveLimit, coins = d.Coins or 0, save = L.t(L.has(saveKey) and saveKey or "ui.connecting")})
	for _, row in ipairs(self.Rows) do
		if row.Info and self.Tab == "Pets" then
			for _, pet in ipairs(d.Pets) do
				if pet.Uid == row.Key then
					local spec = P.Species[pet.SpeciesId]
					local element = ELEMENT[spec.Element]
					local growth = pet.Stage == 2 and L.t("pets.adult") or (spec.Adult and L.t("pets.baby", {lv = P.EvolveLevel}) or "")
					local trait = pet.Trait and P.Traits[pet.Trait]
					local nick = (pet.Nickname and pet.Nickname ~= "") and (pet.Nickname .. " · ") or ""
					row.Info.Text = L.t("pets.info", {fav = pet.Favorite and "♥ " or "", shiny = pet.Shiny and L.t("pets.shiny") or "", nick = nick,
						name = L.text(PR.name(pet.SpeciesId, pet.Stage, P)), lv = pet.Level, growth = growth, stars = PR.starText(pet.Stars),
						trait = trait and (trait.Icon .. " " .. L.t("trait." .. pet.Trait) .. " (" .. L.t("traitDesc." .. pet.Trait) .. ")") or L.t("pets.noTrait"),
						power = pet.Power or 0, element = L.t(element[1]), role = L.t("role." .. spec.Role), cap = pet.EffectiveLevel, hp = pet.HP, maxhp = pet.MaxHP,
						mode = pet.HP == 0 and L.t("pets.fainted") or L.t("mode." .. tostring(pet.Mode)), status = L.t("pets.status." .. tostring(pet.Status))})
				end
			end
		elseif row.Info and self.Tab == "Wild" then
			for _, wild in ipairs(d.Wild) do
				if wild.Id == row.Key then
					local spec = P.Species[wild.SpeciesId]
					local state = wild.Busy and L.t("wildtab.busy") or (not wild.CanClaim and L.t("wildtab.claimed", {name = wild.Owner})
						or (wild.Ready and L.t("wildtab.ready", {m = P.CaptureRange}) or L.t("wildtab.weakenTo", {pct = math.floor(P.CaptureHP * 100)})))
					local trait = wild.Trait and P.Traits[wild.Trait]
					local ratio = (wild.Power or 0) > 0 and (wild.TeamPower or 0) / wild.Power or 1
					local verdict = L.t(ratio < P.PowerGate and "power.tooStrongLong" or (ratio < 1 and "power.hardLong" or "power.fair"))
					row.Info.Text = L.t("wildtab.info", {shiny = wild.Shiny and "✨" or "", name = L.text(PR.name(wild.SpeciesId, wild.Stage, P)), lv = wild.Level,
						stars = PR.starText(wild.Stars), m = wild.Distance, element = L.t(ELEMENT[spec.Element][1]), role = L.t("role." .. spec.Role),
						trait = trait and (trait.Icon .. " " .. L.t("trait." .. wild.Trait)) or "", power = wild.Power or 0, team = wild.TeamPower or 0, verdict = verdict,
						state = state, hp = wild.HP, maxhp = wild.MaxHP, chance = string.format("%.0f", wild.Ready and wild.Chance * 100 or 0),
						better = string.format("%.0f", wild.Ready and wild.BetterChance * 100 or 0)})
				end
			end
		elseif row.Info and self.Tab == "Craft" then
			local recipe, spec = Recipes.Recipes[row.Key], I.Items[row.Key]
			local have = (d.Items or {})[row.Key] or 0
			local locked = recipe.Station == "Workbench" and recipe.Bench > (d.Bench or 0)
			local owned = (spec.Kind == "Tool" or spec.Kind == "Bag") and (have > 0 and L.t("craft.owned") or "") or L.t("craft.have", {n = have})
			local place = L.t("station." .. recipe.Station)
			row.Info.Text = string.format("%s  %s\n%s%s · %s", L.t("item." .. row.Key), owned,
				locked and ((d.Bench or 0) == 0 and L.t("craft.lockedNoBench") or L.t("craft.lockedLv", {lv = recipe.Bench})) or "", place, row.Cost)
			row.Info.TextColor3 = locked and COL.Muted or COL.Text
			row.Button.BackgroundColor3 = locked and COL.Card2 or Color3.fromHex("#2f8f83")
		end
	end
	local items = d.Items or {}
	self.Footer.Text = L.t("pets.footer", {trap = items.Trap or 0, better = items.BetterTrap or 0, crystal = items.CrystalTrap or 0,
		bait = items.Bait or 0, snack = items.Snack or 0, hint = L.t(self.Tab == "Craft" and "pets.footerCraft" or "pets.footerPets")})
end

return Controller
