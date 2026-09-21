-- 6단계 : 글 없이 알아보는 화면.
-- 왼쪽 위 = 별 개수, 위 가운데 = 기차 칸 (●●●○○○○○○○)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local Hud = {}

local starPanel, starNumber, starViewport
local trainBar, pipHolder, glow
local pips = {}
local shownStars = nil
local shownMax = 0
local shownTrain = 0
local flashUntil = 0

--=========================================================
-- 별 패널
--=========================================================
local function buildStarPanel(parent)
	starPanel = UiKit.panel(parent, "StarPanel", Color3.fromRGB(255, 252, 240))
	starPanel.AnchorPoint = Vector2.new(0, 0)
	starPanel.Position = UDim2.new(0.02, 0, 0.055, 0)
	starPanel.Size = UDim2.new(0.2, 0, 0.1, 0)
	starPanel.BackgroundTransparency = 0.08
	UiKit.aspect(starPanel, 2.1)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(120, 56)
	sizeConstraint.MaxSize = Vector2.new(260, 120)
	sizeConstraint.Parent = starPanel

	starViewport = UiKit.viewport(starPanel, ModelFactory.buildStar(), "StarIcon")
	starViewport.Size = UDim2.fromScale(0.42, 1)
	starViewport.Position = UDim2.fromScale(0.02, 0)

	starNumber = UiKit.number(starPanel, "0")
	starNumber.Size = UDim2.fromScale(0.52, 0.72)
	starNumber.Position = UDim2.fromScale(0.44, 0.14)
	starNumber.TextXAlignment = Enum.TextXAlignment.Left
	starNumber.TextColor3 = Color3.fromRGB(255, 188, 60)
	starNumber.TextStrokeColor3 = Color3.fromRGB(120, 82, 20)
end

--=========================================================
-- 기차 칸 표시
--=========================================================
local function layoutPips()
	if not pipHolder then
		return
	end
	local count = #pips
	if count == 0 then
		return
	end
	local area = pipHolder.AbsoluteSize
	if area.Y <= 0 then
		return
	end
	local gap = 4
	local size = math.min(area.Y, (area.X - gap * (count - 1)) / count)
	size = math.max(size, 8)
	for _, pip in ipairs(pips) do
		pip.Size = UDim2.fromOffset(size, size)
		pip:SetAttribute("BaseSize", pip.Size)
	end
end

local function buildPips(count)
	for _, pip in ipairs(pips) do
		pip:Destroy()
	end
	pips = {}
	for index = 1, count do
		local pip = UiKit.dot(pipHolder, false)
		pip.LayoutOrder = index
		table.insert(pips, pip)
	end
	layoutPips()
end

local function buildTrainBar(parent)
	trainBar = UiKit.frame(parent, "TrainBar")
	trainBar.AnchorPoint = Vector2.new(0.5, 0)
	trainBar.Position = UDim2.new(0.5, 0, 0.018, 0)
	trainBar.Size = UDim2.new(0.44, 0, 0.055, 0)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(160, 22)
	sizeConstraint.MaxSize = Vector2.new(620, 56)
	sizeConstraint.Parent = trainBar

	glow = UiKit.frame(trainBar, "Glow")
	glow.BackgroundColor3 = Color3.fromRGB(255, 240, 160)
	glow.BackgroundTransparency = 1
	glow.Size = UDim2.fromScale(1.06, 1.5)
	glow.Position = UDim2.fromScale(-0.03, -0.25)
	UiKit.corner(glow, 1)

	pipHolder = UiKit.frame(trainBar, "Pips")
	pipHolder.Size = UDim2.fromScale(1, 1)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pipHolder

	pipHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutPips)
end

--=========================================================
-- 밖에서 쓰는 함수들
--=========================================================
function Hud.init(parent)
	buildStarPanel(parent)
	buildTrainBar(parent)
	buildPips(Config.Train.BaseMaxLength)
	shownMax = Config.Train.BaseMaxLength

	-- 별 아이콘이 천천히 돕니다
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if starViewport then
			UiKit.aimViewport(starViewport, now * 0.8)
		end
		if glow then
			if now < flashUntil then
				glow.BackgroundTransparency = 0.35 + math.abs(math.sin(now * 8)) * 0.5
			elseif glow.BackgroundTransparency < 1 then
				glow.BackgroundTransparency = 1
			end
		end
	end)
end

function Hud.update(state)
	if not state then
		return
	end

	-- 별 개수 (늘면 통통 튀기)
	if starNumber then
		starNumber.Text = tostring(state.stars)
		if shownStars ~= nil and state.stars > shownStars then
			UiKit.pop(starPanel, 0.18)
			if starViewport then
				UiKit.pop(starViewport, 0.3)
			end
		end
		shownStars = state.stars
	end

	-- 칸 개수가 바뀌면 다시 그립니다 (기차 업그레이드)
	local maxTrain = state.maxTrain or Config.Train.BaseMaxLength
	if maxTrain ~= shownMax then
		shownMax = maxTrain
		buildPips(maxTrain)
		shownTrain = -1
	end

	local filled = math.clamp(state.train or 0, 0, maxTrain)
	if filled ~= shownTrain then
		for index, pip in ipairs(pips) do
			local on = index <= filled
			pip.BackgroundColor3 = on and Color3.fromRGB(255, 225, 110) or Color3.fromRGB(255, 255, 255)
			pip.BackgroundTransparency = on and 0 or 0.55
			local face = pip:FindFirstChild("EyeL")
			if on and not face then
				-- 모은 칸은 병아리 얼굴로 바꿉니다
				local eyeLeft = UiKit.frame(pip, "EyeL")
				eyeLeft.BackgroundTransparency = 0
				eyeLeft.BackgroundColor3 = Color3.fromRGB(60, 54, 66)
				eyeLeft.Size = UDim2.fromScale(0.17, 0.17)
				eyeLeft.Position = UDim2.fromScale(0.28, 0.34)
				UiKit.corner(eyeLeft, 1)

				local eyeRight = eyeLeft:Clone()
				eyeRight.Name = "EyeR"
				eyeRight.Position = UDim2.fromScale(0.55, 0.34)
				eyeRight.Parent = pip

				local beak = UiKit.frame(pip, "Beak")
				beak.BackgroundTransparency = 0
				beak.BackgroundColor3 = Color3.fromRGB(255, 163, 71)
				beak.Size = UDim2.fromScale(0.22, 0.15)
				beak.Position = UDim2.fromScale(0.39, 0.6)
				UiKit.corner(beak, 0.4)
			elseif not on and face then
				for _, name in ipairs({ "EyeL", "EyeR", "Beak" }) do
					local item = pip:FindFirstChild(name)
					if item then
						item:Destroy()
					end
				end
			end
			if on and index > shownTrain and shownTrain >= 0 then
				UiKit.pop(pip, 0.45)
			end
		end
		shownTrain = filled
	end

	if filled >= maxTrain and maxTrain > 0 then
		Hud.flashFull()
	end
end

-- 기차가 가득 차면 칸 표시가 반짝입니다 (6단계)
function Hud.flashFull()
	flashUntil = os.clock() + 2.5
end

return Hud
