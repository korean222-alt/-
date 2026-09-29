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
local Portrait = require(script.Parent.Portrait)

local UI = {}
local player = Players.LocalPlayer

local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamBold
local INK = Color3.fromHex("#f4f7fb")
local MUTED = Color3.fromHex("#b9c4d4")
local PANEL = Color3.fromHex("#16202e")
local ICON = R.Icons
local PHASE = {
	Waiting = {"🧭", "출발 준비", "#2f8f83", "#47b8a6"},
	Day = {"☀️", "낮", "#e29a2e", "#f6c453"},
	Night = {"🌙", "밤", "#3b3f8f", "#6a5acd"},
	Dawn = {"🌅", "새벽", "#c46b8a", "#f2a07b"},
	Result = {"🏁", "결과", "#5b6474", "#8792a6"},
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
	self.PhaseText = text(pill, {Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -120, 1, 0), Text = "연결 중", TextSize = 20, Font = TITLE,
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
	self.EnemyChip = panel(gui, {Name = "Enemies", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), Size = UDim2.fromOffset(150, 26), Visible = false})
	self.EnemyText = text(self.EnemyChip, {Size = UDim2.fromScale(1, 1), Text = "", TextSize = 14, TextColor3 = Color3.fromHex("#ffb3b3")})

	-- 왼쪽 위: 목표 카드
	local goal = panel(gui, {Name = "Goal", Position = UDim2.fromOffset(12, 64), Size = UDim2.fromOffset(300, 64)})
	self.GoalCard = goal
	local chip = new("TextLabel", goal, {Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(46, 20), BackgroundColor3 = Color3.fromHex("#7be0b6"),
		Text = "목표", Font = TITLE, TextSize = 13, TextColor3 = Color3.fromHex("#10302a"), BorderSizePixel = 0})
	round(chip, 10)
	self.Goal = text(goal, {Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 1, -34), Text = "맵을 준비하고 있습니다", TextSize = 14,
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
	self.CapText = text(bag, {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -3), Size = UDim2.fromOffset(100, 16), Text = "가방 0/60",
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
	self.Result = panel(gui, {Name = "Result", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 250),
		Visible = false, ZIndex = 40})
	self.ResultTitle = text(self.Result, {Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 50), Font = TITLE, TextSize = 40, Text = "", ZIndex = 41})
	self.ResultBody = text(self.Result, {Position = UDim2.fromOffset(24, 80), Size = UDim2.new(1, -48, 1, -96), TextSize = 16, Text = "", TextColor3 = MUTED,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 41})

	remotes.State.OnClientEvent:Connect(function(data)
		local previous = self.Data
		self.Data = data
		self:Update(previous)
	end)
	remotes.Notice.OnClientEvent:Connect(function(message) self:Notify(message) end)
	remotes.PetFX.OnClientEvent:Connect(function(kind, name)
		if kind == "Capture" then
			self:ShowBanner("🎉 포획 성공!", (name or "") .. " 이(가) 동료가 되었어요 · 펫 우리에 등록하세요", Color3.fromHex("#b6ff8a"))
		elseif kind == "Secured" then
			self:ShowBanner("💾 영구 확정!", "이제 원정이 끝나도 내 펫이에요", Color3.fromHex("#8ff5e8"))
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 and self.Data then
			acc = 0
			self:UpdateTimer()
		end
	end)
end

-- ===================================================================== 팀 카드
function UI:MakeCard(i)
	local card = panel(self.Team, {Name = "Card" .. i, Size = UDim2.fromOffset(210, 60), LayoutOrder = i})
	local face = new("Frame", card, {Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = Color3.fromHex("#2a3a4f"), BorderSizePixel = 0})
	round(face, 24)
	local faceStroke = stroke(face, Color3.fromHex("#7be0b6"), 2, 0)
	local name = text(card, {Position = UDim2.fromOffset(60, 5), Size = UDim2.new(1, -66, 0, 18), Text = "빈 자리", TextSize = 14, Font = TITLE,
		TextXAlignment = Enum.TextXAlignment.Left})
	local back = new("Frame", card, {Position = UDim2.fromOffset(60, 26), Size = UDim2.new(1, -70, 0, 8), BackgroundColor3 = Color3.fromHex("#2a3446"), BorderSizePixel = 0})
	round(back, 4)
	local fill = new("Frame", back, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#7be08a"), BorderSizePixel = 0})
	round(fill, 4)
	local status = text(card, {Position = UDim2.fromOffset(60, 37), Size = UDim2.new(1, -66, 0, 16), Text = "야생 펫을 잡아 채우세요", TextSize = 11,
		TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left})
	local button = new("TextButton", card, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5})
	button.Activated:Connect(function()
		local controller = self.PetController
		if controller then controller:Open("Pets") end
	end)
	return {Frame = card, Face = face, FaceStroke = faceStroke, Name = name, Fill = fill, Status = status, Species = nil}
end

function UI:UpdateTeam(pets)
	local active = {}
	for _, pet in ipairs(pets or {}) do
		if pet.Active then table.insert(active, pet) end
	end
	for i, card in ipairs(self.Cards) do
		local pet = active[i]
		if pet then
			local spec = P.Species[pet.SpeciesId]
			if card.Species ~= pet.SpeciesId then
				card.Species = pet.SpeciesId
				for _, child in ipairs(card.Face:GetChildren()) do
					if child:IsA("ViewportFrame") then child:Destroy() end
				end
				Portrait.make(card.Face, pet.SpeciesId, {Size = UDim2.fromScale(1.25, 1.25), Position = UDim2.fromScale(-0.125, -0.2)})
			end
			card.Name.Text = string.format("%s  Lv%d", spec.Name, pet.Level)
			local ratio = math.clamp(pet.HP / math.max(1, pet.MaxHP), 0, 1)
			card.Fill.Size = UDim2.fromScale(ratio, 1)
			card.Fill.BackgroundColor3 = ratio > 0.5 and Color3.fromHex("#7be08a") or (ratio > 0.25 and Color3.fromHex("#f4d35e") or Color3.fromHex("#ef5b5b"))
			local statusText = {["영구"] = "💾 영구 확정", ["저장 중"] = "⏳ 저장 중", ["밤 생존 대기"] = "🏠 등록됨 · 밤을 버티면 확정", ["미등록"] = "⚠ 미등록 · 펫 우리로!"}
			card.Status.Text = pet.HP <= 0 and "💤 기절 · 곧 회복" or (statusText[pet.Status] or pet.Status)
			card.Status.TextColor3 = pet.Status == "영구" and Color3.fromHex("#8ff5e8") or (pet.Status == "미등록" and Color3.fromHex("#ffd36b") or MUTED)
			card.FaceStroke.Color = pet.Status == "영구" and Color3.fromHex("#7be0b6") or Color3.fromHex("#ffd36b")
			card.Frame.BackgroundTransparency = 0.12
		else
			if card.Species then
				card.Species = nil
				for _, child in ipairs(card.Face:GetChildren()) do
					if child:IsA("ViewportFrame") then child:Destroy() end
				end
			end
			card.Name.Text = "빈 자리"
			card.Fill.Size = UDim2.fromScale(0, 1)
			card.Status.Text = "야생 펫을 잡아 채우세요"
			card.Status.TextColor3 = MUTED
			card.Frame.BackgroundTransparency = 0.45
		end
	end
end

-- ===================================================================== 알림/배너
function UI:Notify(message)
	self.ToastText.Text = message
	self.ToastToken = (self.ToastToken or 0) + 1
	local token = self.ToastToken
	TweenService:Create(self.Toast, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0, 126)}):Play()
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
		self.ResultBody.Text = string.format("%s\n\n🌙 버틴 밤  %d / %d\n👥 함께한 대원  %d명\n\n%d초 뒤 같은 팀으로 새 원정을 준비합니다.\n(시설·자원은 판마다 초기화, 확정된 펫은 유지)",
			d.Result.Reason, d.Result.Nights, d.Target, d.Players, remaining)
	end
end

function UI:Update(previous)
	local d = self.Data
	local look = PHASE[d.Phase] or PHASE.Waiting
	self.PhaseIcon.Text = look[1]
	if d.Phase == "Day" or d.Phase == "Night" or d.Phase == "Dawn" then
		self.PhaseText.Text = string.format("%s %d / %d", look[2], d.Night, d.Target)
	else
		self.PhaseText.Text = look[2]
	end
	self.PillGradient.Color = ColorSequence.new(Color3.fromHex(look[3]), Color3.fromHex(look[4]))
	local ratio = math.clamp(d.CoreHP / math.max(1, d.CoreMaxHP), 0, 1)
	TweenService:Create(self.CoreFill, TweenInfo.new(0.3), {Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = ratio > 0.35 and Color3.fromHex("#6ff3e0") or Color3.fromHex("#ff6b6b")}):Play()
	self.CoreText.Text = tostring(math.floor(d.CoreHP))
	self.EnemyChip.Visible = d.Phase == "Night"
	self.EnemyText.Text = string.format("👾 괴물 %d · 등장 %d/%d", d.Enemies, d.Spawned, d.Total)

	-- 자원
	local total = 0
	for _, kind in ipairs(R.Order) do
		local row = self.ResourceRows[kind]
		local amount = d.Bag and d.Bag[kind] or 0
		total = total + amount
		row.Count.Text = tostring(amount)
		row.Bank.Text = "🏠" .. tostring(d.Bank and d.Bank[kind] or 0)
	end
	local capacity = d.Capacity or C.CarryCapacity
	self.CapFill.Size = UDim2.fromScale(math.clamp(total / capacity, 0, 1), 1)
	self.CapFill.BackgroundColor3 = total >= capacity and Color3.fromHex("#ff8a8a") or Color3.fromHex("#f6c453")
	self.CapText.Text = string.format("🎒 %d/%d", total, capacity)

	-- 목표
	local goal
	if d.Phase == "Waiting" then
		goal = string.format("원정대 %d명 모이는 중 · 곧 출발 · 화면 아래 칸(1~9)에서 창·도끼를 골라 들고 클릭 / F / 공격 버튼", d.Players)
	elseif total >= capacity and d.Phase == "Day" then
		goal = "가방이 가득! 기지의 공용 창고 앞으로 가면 자동으로 넣어요"
	elseif d.Phase == "Result" then
		goal = "원정 종료 · 잠시 뒤 같은 팀으로 다시 시작합니다"
	else
		goal = d.Objective or "야생 펫을 잡고, 자원을 모아 기지를 지키세요"
	end
	self.Goal.Text = goal
	self.Practice.Text = d.Practice and "연습 모드 · 저장 안 됨" or ""
	self:UpdateTeam(d.Pets)

	-- 단계가 바뀔 때 배너
	local was = previous and previous.Phase
	if was ~= d.Phase then
		if d.Phase == "Day" and d.Night == 1 and was == "Waiting" then
			self:ShowBanner("🌿 원정 시작!", "문 밖 초원의 야생 모슬링부터 잡아 동료를 늘리세요", Color3.fromHex("#b6ff8a"))
		elseif d.Phase == "Night" then
			self:ShowBanner(string.format("🌙 밤 %d", d.Night), "괴물들이 굴에서 나온다! Core 를 지키세요", Color3.fromHex("#c9b8ff"))
			self:SetVignette(0.35)
		elseif d.Phase == "Dawn" then
			self:ShowBanner("🌅 밤을 버텼다!", "등록한 펫이 영구 저장됩니다", Color3.fromHex("#ffd0c2"))
			self:SetVignette(1)
		elseif d.Phase == "Day" then
			self:ShowBanner(string.format("☀️ %d일차", d.Night), "기지를 강화하고 더 강한 펫에 도전하세요", Color3.fromHex("#ffe9a8"))
			self:SetVignette(1)
		end
	end
	if d.Phase == "Day" and previous and previous.Phase == "Day" then
		local left = d.EndsAt - workspace:GetServerTimeNow()
		if left <= C.WarningSeconds and not self.Warned then
			self.Warned = true
			self:ShowBanner("⚠ 곧 밤이 옵니다", "기지로 돌아와 펫을 배치하세요", Color3.fromHex("#ffb38a"))
			self:SetVignette(0.7)
		end
	end
	if d.Phase ~= "Day" then
		self.Warned = false
	end

	self.Result.Visible = d.Result ~= nil and d.Phase == "Result"
	if d.Result then
		self.ResultTitle.Text = d.Result.Won and "🏆 방어 성공!" or "💥 원정 실패"
		self.ResultTitle.TextColor3 = d.Result.Won and Color3.fromHex("#ffe066") or Color3.fromHex("#ff8a8a")
	end
	self:UpdateTimer()
end

return UI
