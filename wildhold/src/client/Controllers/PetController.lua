-- 펫 패널 (내 펫 / 야생 / 명령 / 제작 / 도감) + 빠른 명령 버튼 + 포획 카드.
-- 서버 액션은 기존과 같다: PetAction(Toggle/Favorite/Heal/Focus/Follow/Stay/Guard/Best/SaveTeam/LoadTeam/Register),
-- CaptureAction(wildId, "Trap"/"BetterTrap", bait), CraftAction(itemId)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local P = require(RS.Shared.Config.PetConfig)
local Recipes = require(RS.Shared.Config.RecipeConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local Portrait = require(script.Parent.Portrait)

local Controller = {}
local TITLE, BODY = Enum.Font.FredokaOne, Enum.Font.GothamBold
local COL = {Back = Color3.fromHex("#141d2a"), Card = Color3.fromHex("#1f2b3b"), Card2 = Color3.fromHex("#273548"), Text = Color3.fromHex("#f1f5fa"),
	Muted = Color3.fromHex("#aab6c6"), Mint = Color3.fromHex("#7be0b6"), Gold = Color3.fromHex("#ffd36b"), Red = Color3.fromHex("#ff8a8a")}
local ELEMENT = {Leaf = {"🌿 풀", "#7ed36a"}, Ember = {"🔥 불", "#ff9a4a"}, Tide = {"💧 물", "#6fc3ff"}}
local ICON = {Wood = "🪵", Stone = "🪨", Fiber = "🌿", Scrap = "⚙️", Berry = "🍓"}
local ITEM_ICON = {Trap = "🧺", BetterTrap = "🧺✨", Bait = "🍓", Snack = "🍪"}

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
	self.OpenButton = button(self.Gui, "🐾\n펫", UDim2.new(1, -96, 1, -270), UDim2.fromOffset(78, 78), function() self:Open("Pets") end, Color3.fromHex("#2f8f83"))
	self.OpenButton.TextSize = 18
	corner(self.OpenButton, 39)
	self.SaveBadge = label(self.OpenButton, "", UDim2.new(0, -40, 1, 2), UDim2.new(1, 80, 0, 16), {TextSize = 11, TextColor3 = COL.Gold,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4})
	self.Quick = create("Frame", self.Gui, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.45, 0), Size = UDim2.fromOffset(92, 190),
		BackgroundTransparency = 1})
	create("UIListLayout", self.Quick, {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right})
	self.QuickButtons = {}
	for _, spec in ipairs({{"Focus", "🎯 사냥", "#b0553a"}, {"Follow", "🐾 따라와", "#2f6f8f"}, {"Guard", "🛡 지켜", "#4f5f8f"}}) do
		local b = button(self.Quick, spec[2], UDim2.new(), UDim2.fromOffset(92, 52), function() self:QuickCommand(spec[1]) end, Color3.fromHex(spec[3]))
		b.TextSize = 15
		self.QuickButtons[spec[1]] = b
	end

	-- 패널
	self.Panel = create("Frame", self.Gui, {Name = "Panel", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.92, 0.84), BackgroundColor3 = COL.Back, BorderSizePixel = 0})
	create("UISizeConstraint", self.Panel, {MaxSize = Vector2.new(720, 640)})
	corner(self.Panel, 18)
	create("UIStroke", self.Panel, {Color = COL.Mint, Transparency = 0.6, Thickness = 2})
	self.Status = label(self.Panel, "내 펫", UDim2.fromOffset(16, 8), UDim2.new(1, -90, 0, 44), {Font = TITLE, TextSize = 18})
	button(self.Panel, "✕", UDim2.new(1, -56, 0, 8), UDim2.fromOffset(46, 42), function() self:Close() end, Color3.fromHex("#5b2f3a"))
	self.TabButtons = {}
	for index, tab in ipairs({{"Pets", "내 펫"}, {"Wild", "야생"}, {"Orders", "명령"}, {"Craft", "제작"}, {"Dex", "도감"}}) do
		self.TabButtons[tab[1]] = button(self.Panel, tab[2], UDim2.new((index - 1) * 0.2, 6, 0, 58), UDim2.new(0.2, -8, 0, 42), function()
			self.Tab = tab[1]
			self:Render()
		end)
	end
	self.Search = create("TextBox", self.Panel, {PlaceholderText = "🔍 이름 / 역할 / 속성", Text = "", ClearTextOnFocus = false, Position = UDim2.new(0, 10, 0, 108),
		Size = UDim2.new(1, -120, 0, 40), BackgroundColor3 = COL.Card, TextColor3 = COL.Text, PlaceholderColor3 = COL.Muted, TextSize = 14, Font = BODY})
	corner(self.Search, 10)
	self.Search:GetPropertyChangedSignal("Text"):Connect(function() self.Filter = string.lower(self.Search.Text); self:Render() end)
	self.FavButton = button(self.Panel, "☆ 즐겨찾기", UDim2.new(1, -104, 0, 108), UDim2.fromOffset(94, 40), function() self.Favorites = not self.Favorites; self:Render() end)
	self.Scroll = create("ScrollingFrame", self.Panel, {Position = UDim2.fromOffset(10, 156), Size = UDim2.new(1, -20, 1, -212), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarImageColor3 = COL.Mint})
	create("UIListLayout", self.Scroll, {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
	self.Footer = label(self.Panel, "", UDim2.new(0, 14, 1, -50), UDim2.new(1, -28, 0, 44), {TextColor3 = COL.Muted, TextSize = 13})

	remotes.State.OnClientEvent:Connect(function(data)
		self.Data = data
		self.OpenButton.Visible = data.Stage >= 5
		self.Quick.Visible = data.Stage >= 5 and not self.Panel.Visible
		local short = {Practice = "연습 모드", Saved = "저장 완료", Unsaved = "저장 대기", Saving = "저장 중…", Retrying = "저장 재시도"}
		self.SaveBadge.Text = short[data.SaveStatus] or "연결 중"
		local wild = data.Wild and data.Wild[1]
		self.QuickButtons.Focus.Visible = data.Phase == "Day" and wild ~= nil and wild.Distance < 60
		if self.Panel.Visible then self:Refresh() end
	end)
	remotes.PetFX.OnClientEvent:Connect(function(kind, name, seconds)
		if kind == "OpenCraft" then
			self:Open("Craft")
		elseif kind == "Shake" then
			self:Close()
			self:CaptureCard(name, seconds)
		elseif kind == "Capture" then
			task.delay(1.2, function() self:Open("Pets"); self.Footer.Text = "🎉 " .. (name or "") .. " 포획! 기지의 펫 우리에서 등록하세요" end)
		end
	end)
end

function Controller:QuickCommand(action)
	if action == "Focus" then
		local wild = self.Data and self.Data.Wild and self.Data.Wild[1]
		if wild then self:Send("Focus", wild.Id) end
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
	label(overlay, (name or "야생 펫") .. " 포획 시도!", UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 26), {Font = TITLE, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center})
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
			if (not self.Favorites or pet.Favorite) and string.find(string.lower(spec.Name .. spec.Role .. spec.Element), self.Filter, 1, true) then
				local row = self:Row(150)
				self:Face(row, pet.SpeciesId, 84)
				local info = label(row, "", UDim2.fromOffset(102, 6), UDim2.new(1, -110, 0, 84))
				local toggle = button(row, pet.Active and "출전 해제" or "⚔ 출전", UDim2.new(0, 8, 1, -50), UDim2.new(0.36, -10, 0, 42),
					function() self:Send("Toggle", pet.Uid) end, pet.Active and COL.Card2 or Color3.fromHex("#2f8f83"))
				button(row, pet.Favorite and "★ 즐겨찾기" or "☆ 즐겨찾기", UDim2.new(0.36, 2, 1, -50), UDim2.new(0.32, -6, 0, 42), function() self:Send("Favorite", pet.Uid) end)
				button(row, "🍪 간식", UDim2.new(0.68, 2, 1, -50), UDim2.new(0.32, -10, 0, 42), function() self:Send("Heal", pet.Uid) end)
				self.Rows[#self.Rows + 1] = {Key = pet.Uid, Info = info, Toggle = toggle}
			end
		end
	elseif self.Tab == "Wild" then
		for _, wild in ipairs(d.Wild or {}) do
			local row = self:Row(150)
			self:Face(row, wild.SpeciesId, 84)
			local info = label(row, "", UDim2.fromOffset(102, 4), UDim2.new(1, -110, 0, 88))
			button(row, "🎯 팀으로 약화", UDim2.new(0, 8, 1, -50), UDim2.new(0.36, -10, 0, 42), function() self:Send("Focus", wild.Id); self:Close() end, Color3.fromHex("#b0553a"))
			button(row, "🧺 일반 덫", UDim2.new(0.36, 2, 1, -50), UDim2.new(0.3, -6, 0, 42), function() self.Remotes.CaptureAction:FireServer(wild.Id, "Trap", false) end)
			button(row, "✨ 강화+먹이", UDim2.new(0.66, 2, 1, -50), UDim2.new(0.34, -10, 0, 42), function() self.Remotes.CaptureAction:FireServer(wild.Id, "BetterTrap", true) end,
				Color3.fromHex("#8a6a2a"))
			self.Rows[#self.Rows + 1] = {Key = wild.Id, Info = info}
		end
	elseif self.Tab == "Orders" then
		local actions = {{"Follow", "🐾 전원 따라와"}, {"Stay", "✋ 전원 대기"}, {"Guard", "🛡 지금 자리 방어"}, {"Best", "⚡ 공격력 순 자동 편성"}, {"Register", "🏠 펫 우리에서 일괄 등록"}}
		for _, a in ipairs(actions) do
			local row = self:Row(52)
			button(row, a[2], UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 44), function() self:Send(a[1]) end)
			self.Rows[#self.Rows + 1] = {}
		end
		for i = 1, 3 do
			local row = self:Row(52)
			button(row, "💾 팀 " .. i .. " 저장", UDim2.fromOffset(4, 4), UDim2.new(0.5, -8, 0, 44), function() self:Send("SaveTeam", i) end)
			button(row, "📂 팀 " .. i .. " 불러오기", UDim2.new(0.5, 4, 0, 4), UDim2.new(0.5, -8, 0, 44), function() self:Send("LoadTeam", i) end)
			self.Rows[#self.Rows + 1] = {}
		end
		local row = self:Row(52)
		button(row, "🔈 효과음 켜기 / 끄기", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 44), function()
			Players.LocalPlayer:SetAttribute("MutePets", not Players.LocalPlayer:GetAttribute("MutePets"))
		end)
		self.Rows[#self.Rows + 1] = {}
	elseif self.Tab == "Craft" then
		for _, id in ipairs(Recipes.Order) do
			local spec = Recipes.Recipes[id]
			local cost = {}
			for _, material in ipairs(R.Order) do
				if spec.Cost[material] then cost[#cost + 1] = ICON[material] .. " " .. spec.Cost[material] end
			end
			local row = self:Row(100)
			label(row, ITEM_ICON[id] or "", UDim2.fromOffset(10, 8), UDim2.fromOffset(60, 44), {TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center})
			local info = label(row, "", UDim2.fromOffset(76, 4), UDim2.new(1, -84, 0, 46))
			button(row, "🔨 만들기", UDim2.new(0, 8, 1, -48), UDim2.new(1, -16, 0, 40), function() self.Remotes.CraftAction:FireServer(id) end, Color3.fromHex("#2f8f83"))
			self.Rows[#self.Rows + 1] = {Key = id, Info = info, Cost = table.concat(cost, "  ")}
		end
	elseif self.Tab == "Dex" then
		for _, id in ipairs(P.Order) do
			local spec = P.Species[id]
			local row = self:Row(104)
			local entry = d.Dex[id]
			local caught = entry and entry.Caught
			self:Face(row, id, 86, not (entry and entry.Seen))
			local state = caught and "✅ 수집 완료" or (entry and entry.Seen and "👀 발견 · 아직 미확정" or "❔ 미발견")
			local element = ELEMENT[spec.Element]
			label(row, string.format("%s\n%s · %s\n%s\n기본 HP %d · 공격 %d", (entry and entry.Seen) and spec.Name or "???", element[1], spec.Role, state, spec.HP, spec.Damage),
				UDim2.fromOffset(104, 6), UDim2.new(1, -112, 1, -12))
			self.Rows[#self.Rows + 1] = {}
		end
	end
	if #self.Rows == 0 then
		local row = self:Row(90)
		label(row, self.Tab == "Wild" and "근처에 야생 펫이 없습니다.\n기지 밖 초원·바위지대·연못으로 가 보세요." or "표시할 펫이 없습니다.",
			UDim2.fromOffset(14, 6), UDim2.new(1, -28, 1, -12), {TextColor3 = COL.Muted})
	end
	self.Structure = self:Signature()
	self:Refresh(true)
end

function Controller:Signature()
	local pieces = {self.Tab}
	if self.Tab == "Pets" then
		for _, pet in ipairs(self.Data.Pets or {}) do pieces[#pieces + 1] = pet.Uid .. tostring(pet.Active) .. tostring(pet.Favorite) .. pet.Status end
	elseif self.Tab == "Wild" then
		local ids = {}
		for _, wild in ipairs(self.Data.Wild or {}) do ids[#ids + 1] = wild.Id end
		table.sort(ids)
		for _, id in ipairs(ids) do pieces[#pieces + 1] = id end
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
	local status = {Practice = "연습 모드 · 영구 저장 안 됨", Saved = "💾 저장 완료", Unsaved = "저장 대기", Saving = "저장 중…", Retrying = "저장 재시도", LockLost = "연결 종료"}
	self.Status.Text = string.format("🐾 출전 %d/3   🪙 %d   ·  %s", equipped, d.Coins or 0, status[d.SaveStatus] or "연결 중")
	for _, row in ipairs(self.Rows) do
		if row.Info and self.Tab == "Pets" then
			for _, pet in ipairs(d.Pets) do
				if pet.Uid == row.Key then
					local spec = P.Species[pet.SpeciesId]
					local element = ELEMENT[spec.Element]
					local statusIcon = {["영구"] = "💾 영구", ["저장 중"] = "⏳ 저장 중", ["밤 생존 대기"] = "🏠 등록 · 밤 생존 대기", ["미등록"] = "⚠ 미등록 (우리에 등록!)"}
					row.Info.Text = string.format("%s%s  Lv%d\n%s · %s · 초원 적용 Lv%d\nHP %d/%d  ·  %s\n%s", pet.Favorite and "★ " or "", spec.Name, pet.Level,
						element[1], spec.Role, pet.EffectiveLevel, pet.HP, pet.MaxHP, pet.HP == 0 and "💤 기절" or ({Follow = "따라가는 중", Stay = "대기", Guard = "방어 중", Focus = "사냥 중"})[pet.Mode] or pet.Mode,
						statusIcon[pet.Status] or pet.Status)
				end
			end
		elseif row.Info and self.Tab == "Wild" then
			for _, wild in ipairs(d.Wild) do
				if wild.Id == row.Key then
					local spec = P.Species[wild.SpeciesId]
					local state = wild.Busy and "🧺 포획 진행 중" or (not wild.CanClaim and ("🏹 " .. wild.Owner .. "의 포획 우선권")
						or (wild.Ready and "✨ 포획 가능! 16m 안에서 덫" or "HP 25% 이하로 약화하세요"))
					row.Info.Text = string.format("%s Lv%d  ·  %dm\n%s · %s  ·  HP %d/%d\n%s\n성공 확률  일반 %.0f%%  /  강화+먹이 %.0f%%", spec.Name, wild.Level, wild.Distance,
						ELEMENT[spec.Element][1], spec.Role, wild.HP, wild.MaxHP, state, wild.Ready and wild.Chance * 100 or 0, wild.Ready and wild.BetterChance * 100 or 0)
				end
			end
		elseif row.Info and self.Tab == "Craft" then
			row.Info.Text = Recipes.Recipes[row.Key].Name .. "   (보유 " .. tostring((d.Items or {})[row.Key] or 0) .. ")\n" .. row.Cost
		end
	end
	local items = d.Items or {}
	self.Footer.Text = string.format("🧺 덫 %d · ✨ 강화 %d · 🍓 먹이 %d · 🍪 간식 %d\n%s", items.Trap or 0, items.BetterTrap or 0, items.Bait or 0, items.Snack or 0,
		self.Tab == "Craft" and "낮에 기지 제작대 근처에서 만들 수 있어요 (재료는 공용 창고에서 사용)" or "잡은 펫: 펫 우리 등록 → 그 밤을 버티면 영구 확정")
end

return Controller
