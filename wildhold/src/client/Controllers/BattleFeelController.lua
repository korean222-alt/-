-- 전투 손맛 (도파민 포인트). 서버 FX 를 받아 화면에서만 그린다:
--  · 피해 숫자 (보통 흰색 / 치명타 큰 노란 "!" / 상성 좋음 "효과 굉장!" / 상성 나쁨 회색)
--  · 필살기: 펫 머리 위에 기술 이름 + 내 펫이면 화면 흔들림
--  · 콤보: 내 펫·내 공격이 끊기지 않고 이어지면 "COMBO x12" (숫자가 클수록 크고 뜨겁게, 소리도 높아진다)
--  · KO!: 내 펫이 괴물을 쓰러뜨리면 경험치 구슬이 나에게 날아온다
--  · LEVEL UP!: 펫 위로 빛 기둥 + 큰 글자 / 포획 가능!: 야생 펫이 지치는 순간
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local P = require(RS.Shared.Config.PetConfig)
local L = require(RS.Shared.Modules.Locale)
local Audio = require(script.Parent.AudioController)

local F = {}
local player = Players.LocalPlayer
local TITLE = Enum.Font.FredokaOne
local ELEMENT_COLOR = {Leaf = Color3.fromHex("#9df07e"), Ember = Color3.fromHex("#ffb347"), Tide = Color3.fromHex("#8fe3ff")}
local MAX_POPUPS = 40

local function new(className, parent, props)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end

function F:Init(remotes)
	self.Folder = new("Folder", workspace, {Name = "BattlePopups"})
	self.Popups, self.Combo, self.ComboAt, self.Shake = 0, 0, 0, 0
	-- 콤보 표시 (화면 오른쪽 가운데 위)
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "BattleFeel", ResetOnSpawn = false, DisplayOrder = 12, IgnoreGuiInset = true})
	self.Gui = gui
	self.ComboLabel = new("TextLabel", gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.3), Size = UDim2.fromOffset(260, 70),
		BackgroundTransparency = 1, Font = TITLE, TextSize = 40, Text = "", TextColor3 = Color3.fromHex("#ffe066"), TextStrokeTransparency = 0.1,
		TextStrokeColor3 = Color3.fromHex("#3a1500"), Visible = false, Rotation = -6})
	self.ComboScale = new("UIScale", self.ComboLabel, {Scale = 1})
	-- 큰 가운데 글자 (포획 가능! 등)
	self.Big = new("TextLabel", gui, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(600, 80),
		BackgroundTransparency = 1, Font = TITLE, TextSize = 52, Text = "", TextColor3 = Color3.fromHex("#b6ff8a"),
		TextStrokeColor3 = Color3.fromHex("#10131c"), TextTransparency = 1})
	self.Big.TextStrokeTransparency = 1
	self.BigScale = new("UIScale", self.Big, {Scale = 1})

	remotes.FX.OnClientEvent:Connect(function(kind, a, b, c, d)
		if kind == "Pet" then self:OnPet(a, b, c, d)
		elseif kind == "Spear" then self:OnSpear(b, c)
		elseif kind == "LevelUp" then self:OnLevelUp(a, b, c, d)
		elseif kind == "WildReady" then self:OnWildReady(a, b, c) end
	end)
	-- 화면 흔들림: 카메라에 아주 짧게 덧입힌다
	local function shake(dt)
		if self.Shake <= 0 then return end
		local camera = workspace.CurrentCamera
		local s = self.Shake
		camera.CFrame = camera.CFrame * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
			* CFrame.Angles(0, 0, (math.random() - 0.5) * s * 0.02)
		self.Shake = math.max(0, self.Shake - dt * 6)
	end
	if not pcall(function() RunService:BindToRenderStep("WildholdShake", Enum.RenderPriority.Camera.Value + 1, shake) end) then
		RunService.RenderStepped:Connect(shake)
	end
	RunService.Heartbeat:Connect(function()
		if self.Combo > 0 and os.clock() - self.ComboAt > P.ComboWindow then self:EndCombo() end
	end)
end

function F:Mine(ownerId) return ownerId == player.UserId end

-- ===================================================================== 떠오르는 글자
function F:Popup(position, text, color, size, rise, life)
	if self.Popups >= MAX_POPUPS then return end
	self.Popups = self.Popups + 1
	local anchor = new("Part", self.Folder, {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position + Vector3.new((math.random() - 0.5) * 1.6, 2.5, (math.random() - 0.5) * 1.6))})
	local gui = new("BillboardGui", anchor, {Size = UDim2.fromOffset(220, 60), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 140,
		StudsOffsetWorldSpace = Vector3.new(0, 0, 0)})
	local label = new("TextLabel", gui, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = TITLE, TextSize = size or 26, Text = text,
		TextColor3 = color or Color3.new(1, 1, 1), TextStrokeTransparency = 0.15, TextStrokeColor3 = Color3.fromHex("#14100c")})
	local scale = new("UIScale", label, {Scale = 0.4})
	life = life or 0.9
	TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	TweenService:Create(gui, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffsetWorldSpace = Vector3.new(0, rise or 3, 0)}):Play()
	task.delay(life * 0.55, function()
		TweenService:Create(label, TweenInfo.new(life * 0.45), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	end)
	task.delay(life + 0.05, function() self.Popups = self.Popups - 1 end)
	Debris:AddItem(anchor, life + 0.1)
	return label
end

function F:BigText(text, color, hold)
	self.Big.Text, self.Big.TextColor3 = text, color or Color3.fromHex("#b6ff8a")
	self.Big.TextTransparency, self.Big.TextStrokeTransparency = 0, 0.1
	self.BigScale.Scale = 1.6
	TweenService:Create(self.BigScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
	self.BigToken = (self.BigToken or 0) + 1
	local token = self.BigToken
	task.delay(hold or 1.2, function()
		if self.BigToken ~= token then return end
		TweenService:Create(self.Big, TweenInfo.new(0.4), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	end)
end

-- ===================================================================== 콤보
function F:Hit()
	local now = os.clock()
	if now - self.ComboAt > P.ComboWindow then self.Combo = 0 end
	self.Combo, self.ComboAt = self.Combo + 1, now
	if self.Combo < 3 then return end
	local n = self.Combo
	local label = self.ComboLabel
	label.Visible = true
	label.Text = L.t("battle.combo", {n = n})
	-- 콤보가 클수록 크고 뜨거운 색
	local heat = math.clamp((n - 3) / 30, 0, 1)
	label.TextColor3 = Color3.fromHex("#ffe066"):Lerp(Color3.fromHex("#ff4d2e"), heat)
	label.TextSize = 36 + heat * 22
	self.ComboScale.Scale = 1.35
	TweenService:Create(self.ComboScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Scale = 1}):Play()
	if n % 10 == 0 then
		Audio:Play("Combo", nil, 0.1, 1 + math.min(0.6, n / 100))
		self:BigText(L.t("battle.comboMilestone", {n = n}), label.TextColor3, 0.8)
	end
end

function F:EndCombo()
	if self.Combo >= 3 then
		local label = self.ComboLabel
		TweenService:Create(label, TweenInfo.new(0.35), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		task.delay(0.4, function()
			if self.Combo == 0 then label.Visible, label.TextTransparency, label.TextStrokeTransparency = false, 0, 0.1 end
		end)
	end
	self.Combo = 0
end

-- ===================================================================== 이벤트
function F:OnPet(from, to, species, info)
	if type(info) ~= "table" then return end
	local mine = self:Mine(info.O)
	local spec = P.Species[species or ""]
	local color = spec and ELEMENT_COLOR[spec.Element] or Color3.new(1, 1, 1)
	if info.S then
		-- 필살기: 펫 머리 위에 기술 이름
		self:Popup(from + Vector3.new(0, 2, 0), L.t("skill." .. tostring(species)), color, mine and 34 or 26, 4, 1.4)
		Audio:Play("Skill", from, 0.15)
		if mine then self.Shake = math.max(self.Shake, 1.1) end
	end
	if (info.D or 0) > 0 then
		local text, numberColor, size = tostring(info.D), Color3.new(1, 1, 1), mine and 26 or 20
		if info.C then
			text, numberColor, size = text .. "!", Color3.fromHex("#ffe066"), size + 12
			if mine then self.Shake = math.max(self.Shake, 0.45); Audio:Play("Crit", to, 0.08) end
		end
		if info.S then numberColor, size = color, size + 8 end
		self:Popup(to, text, numberColor, size)
		if info.E and info.E > 1 then
			self:Popup(to + Vector3.new(0, 1.2, 0), L.t("battle.superEffective"), Color3.fromHex("#7cff6b"), mine and 22 or 18, 3.6, 1.1)
		elseif info.E and info.E < 1 then
			self:Popup(to + Vector3.new(0, 1.2, 0), L.t("battle.notEffective"), Color3.fromHex("#a7b0bd"), 16, 3, 1)
		end
		if mine then self:Hit() end
	end
	if info.K then self:OnKO(to, mine) end
end

function F:OnSpear(to, info)
	if type(info) ~= "table" or typeof(to) ~= "Vector3" then return end
	local mine = self:Mine(info.O)
	if (info.D or 0) > 0 then
		self:Popup(to, tostring(info.D), Color3.fromHex("#e8fbff"), mine and 22 or 16)
		if mine then self:Hit() end
	end
	if info.K then self:OnKO(to, mine) end
end

function F:OnKO(position, mine)
	self:Popup(position + Vector3.new(0, 1.5, 0), L.t("battle.ko"), Color3.fromHex("#ff6b6b"), mine and 40 or 28, 4.5, 1.1)
	if not mine then return end
	Audio:Play("KO", position, 0.1)
	-- 경험치 구슬이 나에게 날아온다
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	for i = 1, 6 do
		local orb = new("Part", self.Folder, {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon, Color = Color3.fromHex("#8ff5e8"), Size = Vector3.new(0.5, 0.5, 0.5),
			CFrame = CFrame.new(position + Vector3.new((math.random() - 0.5) * 3, 1 + math.random() * 2, (math.random() - 0.5) * 3))})
		task.delay(0.15 + i * 0.05, function()
			if not orb.Parent then return end
			local target = (root.Parent and root.Position or position) + Vector3.new(0, 1, 0)
			TweenService:Create(orb, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = CFrame.new(target), Size = Vector3.new(0.2, 0.2, 0.2)}):Play()
		end)
		Debris:AddItem(orb, 0.8 + i * 0.05)
	end
end

function F:OnLevelUp(position, _, level, ownerId)
	if typeof(position) ~= "Vector3" then return end
	local mine = self:Mine(ownerId)
	self:Popup(position + Vector3.new(0, 1, 0), L.t("battle.levelUp", {lv = level or 0}), Color3.fromHex("#ffe066"), mine and 36 or 24, 5, 1.6)
	-- 빛 기둥
	local beam = new("Part", self.Folder, {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon, Color = Color3.fromHex("#ffe9a8"), Transparency = 0.3, Size = Vector3.new(14, 3, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90))})
	TweenService:Create(beam, TweenInfo.new(0.8), {Transparency = 1, Size = Vector3.new(16, 0.3, 0.3)}):Play()
	Debris:AddItem(beam, 0.9)
	if mine then Audio:Play("LevelUp", position, 0.2) end
end

function F:OnWildReady(position, _, ownerId)
	if typeof(position) ~= "Vector3" then return end
	local mine = self:Mine(ownerId)
	self:Popup(position + Vector3.new(0, 2, 0), L.t("battle.ready"), Color3.fromHex("#b6ff8a"), mine and 32 or 22, 4, 1.4)
	if mine then
		self:BigText(L.t("battle.readyBig"), Color3.fromHex("#b6ff8a"), 1.4)
		Audio:Play("WildReady", position, 0.2)
	end
end

return F
