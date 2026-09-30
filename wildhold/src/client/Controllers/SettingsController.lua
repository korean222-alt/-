-- ⚙ 설정: 언어 (자동 = Roblox 계정 언어) · 음악 크기 · 효과음 크기. 로비와 원정 어디서나 왼쪽 위 ⚙ 버튼.
-- 바꾸면 바로 적용하고 서버에 저장한다 (Settings 리모트 → DataService:SetSetting → 다음 접속에도 유지).
-- 번역 속성이 붙은 글자(서버가 만든 간판·프롬프트)를 계속 번역하는 Locale.watch 도 여기서 켠다.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local L = require(RS.Shared.Modules.Locale)

local S = {}
local player = Players.LocalPlayer
local TITLE, BODY = Enum.Font.FredokaOne, Enum.Font.GothamBold
local COL = {Panel = Color3.fromHex("#16202e"), Card = Color3.fromHex("#1f2b3b"), Card2 = Color3.fromHex("#273548"), Text = Color3.fromHex("#f1f5fa"),
	Muted = Color3.fromHex("#aab6c6"), Mint = Color3.fromHex("#2f8f83")}
local STEPS = 10

local function new(className, parent, props)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end

local function corner(parent, r) new("UICorner", parent, {CornerRadius = UDim.new(0, r or 10)}) end

local function button(parent, props, fn)
	local b = new("TextButton", parent, {Font = TITLE, TextSize = 16, TextColor3 = COL.Text, BackgroundColor3 = COL.Card2, BorderSizePixel = 0,
		AutoButtonColor = true, Text = ""})
	for k, v in pairs(props or {}) do b[k] = v end
	corner(b)
	b.Activated:Connect(fn)
	return b
end

function S:Init(remotes)
	self.Remotes = remotes
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "Settings", ResetOnSpawn = false, DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	self.Gui = gui
	self.Open = button(gui, {Name = "Open", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(44, 44), Text = "⚙", TextSize = 24,
		BackgroundColor3 = COL.Panel, BackgroundTransparency = 0.15}, function() self:Toggle() end)
	corner(self.Open, 22)

	local panel = new("Frame", gui, {Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 330),
		BackgroundColor3 = COL.Panel, BorderSizePixel = 0, Visible = false})
	corner(panel, 16)
	new("UIStroke", panel, {Color = Color3.fromHex("#7be0b6"), Transparency = 0.6, Thickness = 2})
	self.Panel = panel
	L.bind(new("TextLabel", panel, {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 34), BackgroundTransparency = 1, Font = TITLE, TextSize = 22,
		TextColor3 = COL.Text, TextXAlignment = Enum.TextXAlignment.Left}), "settings.title")
	button(panel, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(36, 34), Text = "✕",
		BackgroundColor3 = Color3.fromHex("#5b2f3a")}, function() self:Toggle(false) end)

	-- 언어: 자동 + 지원 언어
	L.bind(new("TextLabel", panel, {Position = UDim2.fromOffset(16, 50), Size = UDim2.new(1, -32, 0, 22), BackgroundTransparency = 1, Font = BODY, TextSize = 15,
		TextColor3 = COL.Muted, TextXAlignment = Enum.TextXAlignment.Left}), "settings.language")
	local langRow = new("Frame", panel, {Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 84), BackgroundTransparency = 1})
	new("UIGridLayout", langRow, {CellSize = UDim2.new(1 / 3, -6, 0, 38), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder})
	self.LangButtons = {}
	local choices = {"Auto"}
	for _, code in ipairs(L.Languages) do table.insert(choices, code) end
	for i, code in ipairs(choices) do
		local b = button(langRow, {LayoutOrder = i, TextScaled = true, Text = code == "Auto" and "" or L.Names[code]}, function()
			self.Remotes.Settings:FireServer("Lang", code ~= "Auto" and code or nil)
			-- 서버 저장을 기다리지 않고 바로 바꾼다
			player:SetAttribute("Lang", code ~= "Auto" and code or nil)
			self:Paint()
		end)
		new("UIPadding", b, {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)})
		if code == "Auto" then L.bind(b, "settings.auto") end
		self.LangButtons[code] = b
	end

	-- 음악 · 효과음 크기 (− 막대 +)
	self.Sliders = {}
	for i, spec in ipairs({{"Music", "MusicVolume", "settings.music"}, {"Sfx", "SfxVolume", "settings.sfx"}}) do
		local y = 170 + (i - 1) * 74
		L.bind(new("TextLabel", panel, {Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 22), BackgroundTransparency = 1, Font = BODY, TextSize = 15,
			TextColor3 = COL.Muted, TextXAlignment = Enum.TextXAlignment.Left}), spec[3])
		local row = new("Frame", panel, {Position = UDim2.fromOffset(16, y + 26), Size = UDim2.new(1, -32, 0, 38), BackgroundTransparency = 1})
		local function set(delta)
			local value = math.clamp(math.floor(self:Value(spec[2]) * STEPS + 0.5) + delta, 0, STEPS) / STEPS
			player:SetAttribute(spec[2], value)
			self.Remotes.Settings:FireServer(spec[1], value)
			self:Paint()
		end
		button(row, {Size = UDim2.fromOffset(44, 38), Text = "−", TextSize = 22}, function() set(-1) end)
		local back = new("Frame", row, {Position = UDim2.fromOffset(52, 13), Size = UDim2.new(1, -150, 0, 12), BackgroundColor3 = COL.Card2, BorderSizePixel = 0})
		corner(back, 6)
		local fill = new("Frame", back, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#7be0b6"), BorderSizePixel = 0})
		corner(fill, 6)
		local value = new("TextLabel", row, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -50, 0, 0), Size = UDim2.fromOffset(46, 38),
			BackgroundTransparency = 1, Font = TITLE, TextSize = 15, TextColor3 = COL.Text})
		button(row, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(44, 38), Text = "+", TextSize = 22}, function() set(1) end)
		self.Sliders[spec[2]] = {Fill = fill, Value = value}
	end

	for _, attr in ipairs({"Lang", "MusicVolume", "SfxVolume"}) do
		player:GetAttributeChangedSignal(attr):Connect(function() self:Paint() end)
	end
	L.onChanged(function() self:Paint() end)
	-- 서버가 만든 글자(간판·프롬프트)와 모든 화면: 내 언어로 + Roblox 자동 번역 끄기
	L.watch({workspace, player:WaitForChild("PlayerGui")})
	self:Paint()
end

function S:Value(attr)
	local v = player:GetAttribute(attr)
	return type(v) == "number" and v or 1
end

function S:Toggle(open)
	if open == nil then open = not self.Panel.Visible end
	self.Panel.Visible = open
	player:SetAttribute("SettingsOpen", open)
	self:Paint()
end

function S:Paint()
	local chosen = player:GetAttribute("Lang")
	for code, b in pairs(self.LangButtons) do
		local on = (code == "Auto" and chosen == nil) or code == chosen
		b.BackgroundColor3 = on and COL.Mint or COL.Card2
	end
	for attr, slider in pairs(self.Sliders) do
		local v = self:Value(attr)
		slider.Fill.Size = UDim2.fromScale(v, 1)
		slider.Value.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
	end
end

return S
