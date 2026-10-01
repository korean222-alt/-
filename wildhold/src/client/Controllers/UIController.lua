-- 메인 HUD (모바일 우선).
--  위 가운데 : 낮/밤 알약 + 남은 시간 + Core 체력
--  왼쪽 위   : 지금 할 일 (목표 카드)
--  왼쪽      : 출전 펫 3칸 (얼굴, 레벨, 체력, 확정 상태)
--  아래      : 가방 / 공용 창고 자원 (그 아래 핫바·체력·배고픔은 HotbarController)
--  가운데    : 알림, 밤 경고 배너, 결과 화면
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config.GameConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local P = require(RS.Shared.Config.PetConfig)
local M = require(RS.Shared.Config.MapConfig)
local Zones = require(RS.Shared.Modules.Zones)
local PR = require(RS.Shared.Modules.PetRules)
local EC = require(RS.Shared.Config.EggConfig)
local Portrait = require(script.Parent.Portrait)
local L = require(RS.Shared.Modules.Locale)

local UI = {}
local player = Players.LocalPlayer

local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamBold
local INK = Color3.fromHex("#f4f7fb")
local MUTED = Color3.fromHex("#b9c4d4")
local PANEL = Color3.fromHex("#16202e")
local ICON = R.Icons
local PHASE = {
	Waiting = {"🧭", "phase.Waiting", "#2f8f83", "#47b8a6"},
	Day = {"☀️", "phase.Day", "#e29a2e", "#f6c453"},
	Night = {"🌙", "phase.Night", "#3b3f8f", "#6a5acd"},
	Dawn = {"🌅", "phase.Dawn", "#c46b8a", "#f2a07b"},
	Result = {"🏁", "phase.Result", "#5b6474", "#8792a6"},
}

local function new(className, parent, props)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end

local function round(parent, r)
	return new("UICorner", parent, {CornerRadius = UDim.new(0, r or 12)})
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", parent, {Color = color or Color3.fromHex("#0b1018"), Thickness = thickness or 2, Transparency = transparency or 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
end

local function panel(parent, props)
	local f = new("Frame", parent, {BackgroundColor3 = PANEL, BackgroundTransparency = 0.12, BorderSizePixel = 0})
	for k, v in pairs(props or {}) do f[k] = v end
	round(f, 14)
	stroke(f, Color3.fromHex("#000000"), 2, 0.55)
	return f
end

local function text(parent, props)
	local t = new("TextLabel", parent, {BackgroundTransparency = 1, Font = BODY, TextColor3 = INK, TextSize = 15, TextWrapped = true})
	for k, v in pairs(props or {}) do t[k] = v end
	return t
end

local function gradient(parent, a, b, rotation)
	return new("UIGradient", parent, {Color = ColorSequence.new(Color3.fromHex(a), Color3.fromHex(b)), Rotation = rotation or 90})
end

function UI:Init(remotes)
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "WildholdHUD", ResetOnSpawn = false, DisplayOrder = 10,
		IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	self.Gui = gui
	self.Scale = new("UIScale", gui, {Scale = 1})
	local function rescale()
		local size = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		self.Scale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 700), 0.62, 1.15)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- 위: 낮/밤 알약
	local pill = new("Frame", gui, {Name = "Phase", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(250, 46), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1)})
	round(pill, 23)
	stroke(pill, Color3.fromHex("#0b1018"), 2.5, 0.25)
	self.PillGradient = gradient(pill, "#e29a2e", "#f6c453", 0)
	self.PhaseIcon = text(pill, {Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(40, 46), Text = "☀️", TextSize = 26, Font = TITLE})
	self.PhaseText = text(pill, {Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -120, 1, 0), Text = L.t("ui.connecting"), TextSize = 20, Font = TITLE,
		TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.6})
	self.Timer = text(pill, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(74, 32), Text = "00:00",
		TextSize = 20, Font = TITLE, BackgroundTransparency = 0.55, BackgroundColor3 = Color3.fromHex("#0b1018")})
	round(self.Timer, 16)
	-- Core 체력 막대
	local coreBox = panel(gui, {Name = "Core", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(250, 30)})
	text(coreBox, {Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(24, 30), Text = "💎", TextSize = 18})
	local coreBack = new("Frame", coreBox, {Position = UDim2.fromOffset(36, 9), Size = UDim2.new(1, -110, 0, 12), BackgroundColor3 = Color3.fromHex("#2a3446"), BorderSizePixel = 0})
	round(coreBack, 6)
	self.CoreFill = new("Frame", coreBack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#6ff3e0"), BorderSizePixel = 0})
	round(self.CoreFill, 6)
	self.CoreText = text(coreBox, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(66, 30), Text = "1000",
		TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right})
	-- 지역 이름 + 기지까지 거리·방향 (넓은 맵에서 길을 잃지 않게)
	self.Compass = panel(gui, {Name = "Compass", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.fromOffset(250, 26)})
	self.ZoneText = text(self.Compass, {Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -110, 1, 0), Text = "🌿", TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left})
	self.HomeText = text(self.Compass, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 0), Size = UDim2.fromOffset(80, 26), Text = "🏠 0m",
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right})
	self.HomeArrow = text(self.Compass, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(20, 20), Text = "⬆",
		TextSize = 16, TextColor3 = Color3.fromHex("#7be0b6"), Font = TITLE})
	-- 목표 표시: 지금 가야 할 곳 위에 떠 있는 노란 화살표 (첫 판 안내)
	self.GoalPart = new("Part", workspace, {Name = "WildholdGoal", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2)})
	self.GoalGui = new("BillboardGui", self.GoalPart, {Size = UDim2.fromOffset(160, 64), AlwaysOnTop = true, LightInfluence = 0, Enabled = false,
		StudsOffsetWorldSpace = Vector3.new(0, 1, 0)})
	self.GoalLabel = text(self.GoalGui, {Size = UDim2.new(1, 0, 0, 22), Text = "", TextSize = 16, Font = TITLE, TextColor3 = Color3.fromHex("#ffe066"),
		TextStrokeTransparency = 0.2})
	self.GoalArrow = text(self.GoalGui, {Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 40), Text = "⬇", TextSize = 36, Font = TITLE,
		TextColor3 = Color3.fromHex("#ffe066"), TextStrokeTransparency = 0.2})
	self.EnemyChip = panel(gui, {Name = "Enemies", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 122), Size = UDim2.fromOffset(150, 26), Visible = false})
	self.EnemyText = text(self.EnemyChip, {Size = UDim2.fromScale(1, 1), Text = "", TextSize = 14, TextColor3 = Color3.fromHex("#ffb3b3")})

	-- 왼쪽 위: 목표 카드
	local goal = panel(gui, {Name = "Goal", Position = UDim2.fromOffset(12, 64), Size = UDim2.fromOffset(300, 64)})
	self.GoalCard = goal
	local chip = new("TextLabel", goal, {Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(46, 20), BackgroundColor3 = Color3.fromHex("#7be0b6"),
		Font = TITLE, TextSize = 13, TextColor3 = Color3.fromHex("#10302a"), BorderSizePixel = 0, TextScaled = true})
	L.bind(chip, "ui.goalChip")
	round(chip, 10)
	self.Goal = text(goal, {Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 1, -34), Text = L.t("ui.preparing"), TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top})
	self.Practice = text(goal, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(120, 20), Text = "",
		TextSize = 12, TextColor3 = Color3.fromHex("#ffd36b"), TextXAlignment = Enum.TextXAlignment.Right})

	-- 왼쪽: 팀 카드 3칸
	self.Team = new("Frame", gui, {Name = "Team", Position = UDim2.fromOffset(12, 138), Size = UDim2.fromOffset(210, 3 * 66), BackgroundTransparency = 1})
	new("UIListLayout", self.Team, {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
	self.Cards = {}
	for i = 1, 3 do
		self.Cards[i] = self:MakeCard(i)
	end

	-- 아래: 자원 (핫바와 체력·배고픔 막대 위)
	local bag = panel(gui, {Name = "Resources", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(#R.Order * 66 + 12, 58)})
	self.ResourceRows = {}
	local row = new("Frame", bag, {Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 34), BackgroundTransparency = 1})
	new("UIListLayout", row, {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center})
	for _, kind in ipairs(R.Order) do
		local cell = new("Frame", row, {Size = UDim2.fromOffset(60, 34), BackgroundColor3 = Color3.fromHex("#24303f"), BorderSizePixel = 0})
		round(cell, 10)
		text(cell, {Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(22, 34), Text = ICON[kind], TextSize = 16})
		local count = text(cell, {Position = UDim2.fromOffset(24, 1), Size = UDim2.new(1, -26, 0, 18), Text = "0", TextSize = 14, Font = TITLE,
			TextXAlignment = Enum.TextXAlignment.Left})
		local bank = text(cell, {Position = UDim2.fromOffset(24, 17), Size = UDim2.new(1, -26, 0, 14), Text = "🏠0", TextSize = 10,
			TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left})
		self.ResourceRows[kind] = {Count = count, Bank = bank}
	end
	local capBack = new("Frame", bag, {Position = UDim2.new(0, 12, 1, -13), Size = UDim2.new(1, -120, 0, 6), BackgroundColor3 = Color3.fromHex("#2a3446"), BorderSizePixel = 0})
	round(capBack, 3)
	self.CapFill = new("Frame", capBack, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromHex("#f6c453"), BorderSizePixel = 0})
	round(self.CapFill, 3)
	self.CapText = text(bag, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -3), Size = UDim2.fromOffset(100, 16), Text = "🎒 0/60",
		TextSize = 11, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right})

	-- 알림 (위에서 내려옴)
	self.Toast = panel(gui, {Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(420, 44), ZIndex = 20})
	self.ToastText = text(self.Toast, {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "", TextSize = 15,
		TextColor3 = Color3.fromHex("#ffe9a8"), ZIndex = 21})

	-- 큰 배너 (밤 경고, 밤 시작, 새벽)
	self.Banner = text(gui, {Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(700, 80),
		Font = TITLE, TextSize = 44, Text = "", TextStrokeTransparency = 0.2, TextTransparency = 1, TextStrokeColor3 = Color3.fromHex("#10131c"), ZIndex = 30})
	self.BannerSub = text(gui, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.36, 40), Size = UDim2.fromOffset(700, 30),
		TextSize = 18, Text = "", TextStrokeTransparency = 0.4, TextTransparency = 1, ZIndex = 30})
	-- 밤 가장자리 어둡게 (비네트)
	self.Vignette = {}
	for i, spec in ipairs({{UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0), 90}, {UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0.82), -90},
		{UDim2.new(0.14, 0, 1, 0), UDim2.fromScale(0, 0), 0}, {UDim2.new(0.14, 0, 1, 0), UDim2.fromScale(0.86, 0), 180}}) do
		local f = new("Frame", gui, {Size = spec[1], Position = spec[2], BackgroundColor3 = Color3.fromHex("#2a0f3a"), BorderSizePixel = 0,
			BackgroundTransparency = 1, ZIndex = 0})
		new("UIGradient", f, {Rotation = spec[3], Transparency = NumberSequence.new(0, 1)})
		self.Vignette[i] = f
	end

	-- 결과 화면
	self.Result = panel(gui, {Name = "Result", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(480, 300),
		Visible = false, ZIndex = 40})
	self.ResultTitle = text(self.Result, {Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 50), Font = TITLE, TextSize = 40, Text = "", ZIndex = 41})
	self.ResultBody = text(self.Result, {Position = UDim2.fromOffset(24, 80), Size = UDim2.new(1, -48, 1, -96), TextSize = 16, Text = "", TextColor3 = MUTED,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 41})

	remotes.State.OnClientEvent:Connect(function(data)
		local previous = self.Data
		self.Data = data
		self:Update(previous)
	end)
	remotes.Notice.OnClientEvent:Connect(function(message) self:Notify(L.text(message)) end)
	remotes.PetFX.OnClientEvent:Connect(function(kind, name)
		if kind == "Capture" then
			self:ShowBanner(L.t("banner.capture"), L.t("banner.captureSub", {name = name or ""}), Color3.fromHex("#b6ff8a"))
		elseif kind == "Evolve" then
			self:ShowBanner(L.t("banner.evolve"), L.t("banner.evolveSub", {name = name or ""}), Color3.fromHex("#ffe066"))
		elseif kind == "Secured" then
			self:ShowBanner(L.t("banner.secured"), L.t("banner.securedSub"), Color3.fromHex("#8ff5e8"))
		elseif kind == "Egg" then
			local egg = EC.Kinds[name]
			if egg then self:ShowBanner(L.t("banner.egg", {icon = egg.Icon, name = L.t("egg." .. name)}), L.t("banner.eggSub"), Color3.fromHex(egg.Color)) end
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 and self.Data then
			acc = 0
			self:UpdateTimer()
			self:UpdateCompass()
		end
	end)
end

-- ===================================================================== 팀 카드
function UI:MakeCard(i)
	local card = panel(self.Team, {Name = "Card" .. i, Size = UDim2.fromOffset(210, 60), LayoutOrder = i})
	local face = new("Frame", card, {Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = Color3.fromHex("#2a3a4f"), BorderSizePixel = 0})
	round(face, 24)
	local faceStroke = stroke(face, Color3.fromHex("#7be0b6"), 2, 0)
	local name = text(card, {Position = UDim2.fromOffset(60, 5), Size = UDim2.new(1, -66, 0, 18), Text = L.t("team.empty"), TextSize = 14, Font = TITLE,
		TextXAlignment = Enum.TextXAlignment.Left})
	local back = new("Frame", card, {Position = UDim2.fromOffset(60, 26), Size = UDim2.new(1, -70, 0, 8), BackgroundColor3 = Color3.fromHex("#2a3446"), BorderSizePixel = 0})
	round(back, 4)
	local fill = new("Frame", back, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#7be08a"), BorderSizePixel = 0})
	round(fill, 4)
	-- 필살기 게이지 (가득 차면 다음 공격이 필살기) — 차오르는 걸 보는 기대감
	local energyBack = new("Frame", card, {Position = UDim2.fromOffset(60, 35), Size = UDim2.new(1, -70, 0, 3), BackgroundColor3 = Color3.fromHex("#2a3446"), BorderSizePixel = 0})
	local energy = new("Frame", energyBack, {Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromHex("#b18cff"), BorderSizePixel = 0})
	local status = text(card, {Position = UDim2.fromOffset(60, 37), Size = UDim2.new(1, -66, 0, 16), Text = L.t("team.emptySub"), TextSize = 11,
		TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left})
	local button = new("TextButton", card, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5})
	button.Activated:Connect(function()
		local controller = self.PetController
		if controller then controller:Open("Pets") end
	end)
	return {Frame = card, Face = face, FaceStroke = faceStroke, Name = name, Fill = fill, Status = status, Species = nil, Energy = energy}
end

function UI:UpdateTeam(pets)
	local active = {}
	for _, pet in ipairs(pets or {}) do
		if pet.Active then table.insert(active, pet) end
	end
	for i, card in ipairs(self.Cards) do
		local pet = active[i]
		if pet then
			if card.Species ~= pet.SpeciesId then
				card.Species = pet.SpeciesId
				for _, child in ipairs(card.Face:GetChildren()) do
					if child:IsA("ViewportFrame") then child:Destroy() end
				end
				Portrait.make(card.Face, pet.SpeciesId, {Size = UDim2.fromScale(1.25, 1.25), Position = UDim2.fromScale(-0.125, -0.2)})
			end
			local name = (pet.Nickname and pet.Nickname ~= "") and pet.Nickname or L.text(PR.name(pet.SpeciesId, pet.Stage, P))
			card.Name.Text = string.format("%s%s  Lv%d %s", pet.Shiny and "✨" or "", name, pet.Level, string.rep("★", pet.Stars or 2))
			local ratio = math.clamp(pet.HP / math.max(1, pet.MaxHP), 0, 1)
			card.Fill.Size = UDim2.fromScale(ratio, 1)
			card.Fill.BackgroundColor3 = ratio > 0.5 and Color3.fromHex("#7be08a") or (ratio > 0.25 and Color3.fromHex("#f4d35e") or Color3.fromHex("#ef5b5b"))
			local charge = math.clamp((pet.Energy or 0) / P.Energy.Max, 0, 1)
			TweenService:Create(card.Energy, TweenInfo.new(0.25), {Size = UDim2.fromScale(charge, 1)}):Play()
			card.Energy.BackgroundColor3 = charge >= 0.99 and Color3.fromHex("#ffe066") or Color3.fromHex("#b18cff")
			card.Status.Text = pet.HP <= 0 and L.t("team.fainted") or L.t("team.status." .. tostring(pet.Status))
			card.Status.TextColor3 = pet.Status == "Secured" and Color3.fromHex("#8ff5e8") or (pet.Status == "Unregistered" and Color3.fromHex("#ffd36b") or MUTED)
			card.FaceStroke.Color = pet.Status == "Secured" and Color3.fromHex("#7be0b6") or Color3.fromHex("#ffd36b")
			card.Frame.BackgroundTransparency = 0.12
		else
			if card.Species then
				card.Species = nil
				for _, child in ipairs(card.Face:GetChildren()) do
					if child:IsA("ViewportFrame") then child:Destroy() end
				end
			end
			card.Name.Text = L.t("team.empty")
			card.Fill.Size = UDim2.fromScale(0, 1)
			card.Energy.Size = UDim2.fromScale(0, 1)
			card.Status.Text = L.t("team.emptySub")
			card.Status.TextColor3 = MUTED
			card.Frame.BackgroundTransparency = 0.45
		end
	end
end

-- ===================================================================== 지역 · 기지 방향
function UI:UpdateCompass()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then return end
	local pos = root.Position
	local zoneId = Zones.id(pos, M)
	local zone = M.Zones[zoneId]
	self.ZoneText.Text = zone.Icon .. " " .. L.t("zone." .. zoneId) .. string.rep("★", zone.Danger)
	-- 목표가 있으면 화살표가 목표를, 없으면 기지를 가리킨다
	local goal = self.Data and self.Data.GoalAt
	local toHome = goal and Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z) or Vector3.new(-pos.X, 0, -pos.Z)
	local distance = toHome.Magnitude
	self.HomeText.Text = string.format(goal and "🎯 %dm" or "🏠 %dm", math.floor(distance))
	self.HomeArrow.TextColor3 = goal and Color3.fromHex("#ffe066") or Color3.fromHex("#7be0b6")
	self.GoalGui.Enabled = goal ~= nil and distance > 6
	if goal then
		self.GoalPart.CFrame = CFrame.new(goal + Vector3.new(0, 5 + math.sin(os.clock() * 4) * 0.6, 0))
		self.GoalLabel.Text = string.format("%s · %dm", self.Data.GoalName and L.text(self.Data.GoalName) or L.t("ui.goalChip"), math.floor(distance))
	end
	-- 화살표: 카메라가 보는 방향 기준으로 기지 쪽
	local look = camera.CFrame.LookVector
	local heading = math.atan2(look.X, -look.Z)
	local bearing = math.atan2(toHome.X, -toHome.Z)
	self.HomeArrow.Rotation = math.deg(bearing - heading)
	self.HomeArrow.Visible = distance > 30
	-- 새 지역에 들어서면 한 번 알려준다
	if self.Zone ~= zoneId then
		if self.Zone ~= nil then
			self:ShowBanner(zone.Icon .. " " .. L.t("zone." .. zoneId), zoneId == "Meadow" and L.t("zone.safeSub") or L.t("zone.dangerSub", {stars = string.rep("★", zone.Danger)}),
				Color3.fromHex("#e9f2d0"))
		end
		self.Zone = zoneId
	end
end

-- ===================================================================== 알림/배너
function UI:Notify(message)
	self.ToastText.Text = message
	self.ToastToken = (self.ToastToken or 0) + 1
	local token = self.ToastToken
	TweenService:Create(self.Toast, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0, 156)}):Play()
	task.delay(3.6, function()
		if self.ToastToken == token then
			TweenService:Create(self.Toast, TweenInfo.new(0.25), {Position = UDim2.new(0.5, 0, 0, -80)}):Play()
		end
	end)
end

function UI:ShowBanner(title, sub, color)
	self.Banner.Text, self.BannerSub.Text = title, sub or ""
	self.Banner.TextColor3 = color or INK
	self.BannerToken = (self.BannerToken or 0) + 1
	local token = self.BannerToken
	self.Banner.TextTransparency, self.BannerSub.TextTransparency = 0, 0
	self.Banner.TextStrokeTransparency, self.BannerSub.TextStrokeTransparency = 0.2, 0.4
	self.Banner.Size = UDim2.fromOffset(500, 60)
	TweenService:Create(self.Banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(700, 80)}):Play()
	task.delay(2.6, function()
		if self.BannerToken ~= token then return end
		local info = TweenInfo.new(0.6)
		TweenService:Create(self.Banner, info, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		TweenService:Create(self.BannerSub, info, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	end)
end

function UI:SetVignette(alpha)
	for _, f in ipairs(self.Vignette) do
		TweenService:Create(f, TweenInfo.new(1.2), {BackgroundTransparency = alpha}):Play()
	end
end

-- ===================================================================== 갱신
function UI:UpdateTimer()
	local d = self.Data
	local remaining = math.max(0, math.ceil((d.EndsAt or 0) - workspace:GetServerTimeNow()))
	self.Timer.Text = string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60)
	if d.Phase == "Day" and remaining <= 45 then
		self.Timer.TextColor3 = (remaining % 2 == 0) and Color3.fromHex("#ffb3b3") or INK
	else
		self.Timer.TextColor3 = INK
	end
	if d.Phase == "Result" and d.Result then
		local egg = d.Result.Egg and EC.Kinds[d.Result.Egg]
		self.ResultBody.Text = L.t("result.body", {why = L.text(d.Result.Reason), nights = d.Result.Nights, target = d.Target, players = d.Players,
			reward = egg and L.t("result.reward", {icon = egg.Icon, name = L.t("egg." .. d.Result.Egg)}) or L.t("result.noReward", {n = EC.CommonNights}),
			s = remaining})
	end
end

function UI:Update(previous)
	local d = self.Data
	local look = PHASE[d.Phase] or PHASE.Waiting
	self.PhaseIcon.Text = look[1]
	if d.Phase == "Day" or d.Phase == "Night" or d.Phase == "Dawn" then
		self.PhaseText.Text = string.format("%s %d / %d", L.t(look[2]), d.Night, d.Target)
	else
		self.PhaseText.Text = L.t(look[2])
	end
	self.PillGradient.Color = ColorSequence.new(Color3.fromHex(look[3]), Color3.fromHex(look[4]))
	local ratio = math.clamp(d.CoreHP / math.max(1, d.CoreMaxHP), 0, 1)
	TweenService:Create(self.CoreFill, TweenInfo.new(0.3), {Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = ratio > 0.35 and Color3.fromHex("#6ff3e0") or Color3.fromHex("#ff6b6b")}):Play()
	self.CoreText.Text = tostring(math.floor(d.CoreHP))
	self.EnemyChip.Visible = d.Phase == "Night"
	self.EnemyText.Text = L.t("ui.enemies", {n = d.Enemies, spawned = d.Spawned, total = d.Total})

	-- 자원
	local total = 0
	for _, kind in ipairs(R.Order) do
		local row = self.ResourceRows[kind]
		local amount = d.Bag and d.Bag[kind] or 0
		total = total + amount
		-- 늘어나면 숫자가 잠깐 금빛으로 커진다 (v2)
		if row.Last and amount > row.Last then
			row.Count.TextColor3, row.Count.TextSize = Color3.fromHex("#ffe066"), 18
			TweenService:Create(row.Count, TweenInfo.new(0.45), {TextColor3 = Color3.new(1, 1, 1), TextSize = 14}):Play()
		end
		row.Last = amount
		row.Count.Text = tostring(amount)
		-- v2: 창고 건물이 없어서 공용 창고(Bank)는 보통 비어 있다 → 있을 때만 보인다
		local banked = d.Bank and d.Bank[kind] or 0
		row.Bank.Text = banked > 0 and ("🏠" .. tostring(banked)) or ""
	end
	local capacity = d.Capacity or C.CarryCapacity
	self.CapFill.Size = UDim2.fromScale(math.clamp(total / capacity, 0, 1), 1)
	self.CapFill.BackgroundColor3 = total >= capacity and Color3.fromHex("#ff8a8a") or Color3.fromHex("#f6c453")
	self.CapText.Text = string.format("🎒 %d/%d", total, capacity)

	-- 목표
	local goal
	if d.Phase == "Waiting" then
		goal = L.t("goal.waiting", {n = d.Players})
	elseif total >= capacity and d.Phase == "Day" then
		goal = L.t("goal.bagFull")
	elseif d.Phase == "Result" then
		goal = L.t("goal.result")
	else
		goal = d.Objective and L.text(d.Objective) or L.t("goal.default")
	end
	self.Goal.Text = goal
	self.Practice.Text = d.Practice and L.t("ui.practice") or ""
	self:UpdateTeam(d.Pets)
	-- 우리 팀 전투력 (출전 펫 합): 야생 이름표가 "해볼 만함 / 너무 강함" 을 보여줄 때 쓴다
	local power = 0
	for _, pet in ipairs(d.Pets or {}) do
		if pet.Active then power = power + (pet.Power or 0) end
	end
	if player:GetAttribute("TeamPower") ~= power then player:SetAttribute("TeamPower", power) end

	-- 단계가 바뀔 때 배너
	local was = previous and previous.Phase
	if was ~= d.Phase then
		if d.Phase == "Day" and d.Night == 1 and was == "Waiting" then
			self:ShowBanner(L.t("banner.start"), L.t("banner.startSub"), Color3.fromHex("#b6ff8a"))
		elseif d.Phase == "Night" then
			self:ShowBanner(L.t("banner.night", {n = d.Night}), L.t("banner.nightSub"), Color3.fromHex("#c9b8ff"))
			self:SetVignette(0.35)
		elseif d.Phase == "Dawn" then
			self:ShowBanner(L.t("banner.dawn"), L.t("banner.dawnSub"), Color3.fromHex("#ffd0c2"))
			self:SetVignette(1)
		elseif d.Phase == "Day" then
			self:ShowBanner(L.t("banner.day", {n = d.Night}), L.t("banner.daySub"), Color3.fromHex("#ffe9a8"))
			self:SetVignette(1)
		end
	end
	if d.Phase == "Day" and previous and previous.Phase == "Day" then
		local left = d.EndsAt - workspace:GetServerTimeNow()
		if left <= C.WarningSeconds and not self.Warned then
			self.Warned = true
			self:ShowBanner(L.t("banner.dusk"), L.t("banner.duskSub"), Color3.fromHex("#ffb38a"))
			self:SetVignette(0.7)
		end
	end
	if d.Phase ~= "Day" then
		self.Warned = false
	end

	self.Result.Visible = d.Result ~= nil and d.Phase == "Result"
	if d.Result then
		self.ResultTitle.Text = L.t(d.Result.Won and "result.won" or "result.lost")
		self.ResultTitle.TextColor3 = d.Result.Won and Color3.fromHex("#ffe066") or Color3.fromHex("#ff8a8a")
	end
	self:UpdateTimer()
end

return UI
