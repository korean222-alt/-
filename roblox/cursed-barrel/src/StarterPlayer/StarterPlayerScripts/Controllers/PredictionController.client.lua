-- PredictionController  (Phase 12)
-- 관전 예측 : 남의 판을 구경할 때 "누가 살아남을까?"를 고른다. 맞히면 코인. (걸지 않는다)
--
--   · 관전 중(항해 → 관전)이거나, 서서 가까운 테이블(30 스터드)을 보고 있을 때 창이 뜬다.
--   · 판 초반(한 바퀴 전)에만 고를 수 있다. 테이블의 PredictOpen 이 꺼지면 창이 닫힌다.
--   · 판정 · 보상은 서버(PredictionService)가 한다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Tags = game:GetService("CollectionService")
local Tween = game:GetService("TweenService")

local player = Players.LocalPlayer
local package = RS:WaitForChild("CursedBarrel")
local config = require(package.Shared:WaitForChild("GameConfig"))
local remotes = package:WaitForChild("Remotes")
local predict = remotes:WaitForChild(config.Remotes.Predict)

local TABLE_ATTR = config.TableAttributes
local SEAT_ATTR = config.SeatAttributes
local gold = Color3.fromRGB(255, 206, 110)
local cream = Color3.fromRGB(244, 231, 198)
local teal = Color3.fromRGB(120, 255, 214)
local red = Color3.fromRGB(255, 96, 78)

local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_Predict"
gui.ResetOnSpawn = false
gui.DisplayOrder = 13
gui.Parent = player:WaitForChild("PlayerGui")
-- Phase 14 : 만화풍 굵은 테두리 · 글자 외곽선
local UIKit = require(RS:WaitForChild("CursedBarrel").Shared:WaitForChild("UIKit"))
UIKit.restyle(gui)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -12, 0.55, 0)
panel.Size = UDim2.fromOffset(230, 60)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
panel.BackgroundTransparency = 0.12
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
-- Phase 24 : 휴대폰에서는 버튼 줄처럼 같이 줄인다
UIKit.autoScale(panel, UIKit.phoneFactor)
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = panel

local heading = Instance.new("TextLabel")
heading.BackgroundTransparency = 1
heading.Size = UDim2.new(1, 0, 0, 36)
heading.Font = Enum.Font.GothamBold
heading.TextSize = 14
heading.TextColor3 = gold
heading.TextWrapped = true
heading.Text = "누가 살아남을까?"
heading.LayoutOrder = 0
heading.Parent = panel

local buttons = {}
local picked = {} -- [tableModel] = { roundId, name }
local watching = nil

local toast = Instance.new("TextLabel")
toast.BackgroundTransparency = 1
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0.3, 0)
-- Phase 24 : 폭을 520 으로 못 박지 않는다. 화면 폭 - 좌우 여백 16 씩, 넓은 화면에서도 520 까지만. 길면 줄을 바꾼다.
toast.Size = UDim2.new(1, -32, 0, 40)
toast.AutomaticSize = Enum.AutomaticSize.Y
toast.TextWrapped = true
local toastLimit = Instance.new("UISizeConstraint")
toastLimit.MaxSize = Vector2.new(520, math.huge)
toastLimit.Parent = toast
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 22
toast.TextStrokeTransparency = 0.4
toast.TextTransparency = 1
toast.Parent = gui
local function showToast(text, color)
	toast.Text = text
	toast.TextColor3 = color or gold
	toast.TextTransparency = 0
	task.delay(2.2, function()
		Tween:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end)
end

local function seatedTable()
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local node = h and h.SeatPart
	while node and node ~= workspace do
		if Tags:HasTag(node, config.Tags.Table) then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- 지금 예측할 수 있는 테이블
local function candidateTable()
	if seatedTable() then
		return nil
	end
	local watchId = player:GetAttribute("SpectateTableId")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local best, bestDistance = nil, 30
	for _, model in ipairs(Tags:GetTagged(config.Tags.Table)) do
		if model:IsDescendantOf(workspace) and model:GetAttribute(TABLE_ATTR.PredictOpen) == true then
			if watchId and model:GetAttribute(TABLE_ATTR.TableId) == watchId then
				return model
			end
			if root then
				local distance = (model:GetPivot().Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = model, distance
				end
			end
		end
	end
	return best
end

local function participants(model)
	local list = {}
	local seats = model:FindFirstChild("Seats")
	if not seats then
		return list
	end
	for _, seat in ipairs(seats:GetDescendants()) do
		if seat:IsA("Seat") and (seat:GetAttribute(SEAT_ATTR.TurnOrder) or 0) > 0 and seat:GetAttribute(SEAT_ATTR.Alive) == true then
			table.insert(list, { userId = seat:GetAttribute(SEAT_ATTR.OccupantUserId) or 0, name = seat:GetAttribute(SEAT_ATTR.OccupantName) or "?" })
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

local function redraw(model)
	for _, b in ipairs(buttons) do
		b:Destroy()
	end
	table.clear(buttons)
	local roundId = model:GetAttribute(TABLE_ATTR.RoundId)
	local mine = picked[model]
	if mine and mine.roundId == roundId then
		heading.Text = ("예측: %s"):format(mine.name)
		return
	end
	heading.Text = "누가 살아남을까?"
	for index, entry in ipairs(participants(model)) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 30)
		b.BackgroundColor3 = Color3.fromRGB(34, 60, 71)
		b.TextColor3 = cream
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.Text = entry.name
		b.LayoutOrder = index
		b.Parent = panel
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		b.Activated:Connect(function()
			UIKit.click()
			predict:FireServer(model, entry.userId)
		end)
		table.insert(buttons, b)
	end
end

-- Phase 24 : 관전 중에는 오른쪽 가운데(같은 Y=0.55)에 "관전 종료 · 다음 판 참가" 묶음이 뜬다.
--   두 패널이 겹치지 않게, 그때는 예측 창을 화면 아래 가운데로 옮긴다 (아래를 붙이고 위로 자란다).
local function spectateBarShown()
	local voyage = player.PlayerGui:FindFirstChild("CursedBarrel_Voyage")
	local bar = voyage and voyage:FindFirstChild("SpectateBar")
	return bar ~= nil and bar:IsA("GuiObject") and bar.Visible
end
local function placePanel()
	if spectateBarShown() then
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -18)
	else
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -12, 0.55, 0)
	end
end

local signature = ""
local checkAt = 0
Run.Heartbeat:Connect(function()
	if os.clock() < checkAt then
		return
	end
	checkAt = os.clock() + 0.5
	placePanel()
	local model = config.Prediction.Enabled and candidateTable() or nil
	local list = model and participants(model) or {}
	panel.Visible = model ~= nil and #list > 1
	if not panel.Visible then
		watching = nil
		signature = ""
		return
	end
	local roundId = model:GetAttribute(TABLE_ATTR.RoundId) or 0
	local key = tostring(model) .. ":" .. roundId .. ":" .. #list .. ":" .. tostring(picked[model] and picked[model].roundId)
	if model ~= watching or key ~= signature then
		watching = model
		signature = key
		redraw(model)
	end
end)

predict.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	if data.kind == "ok" and typeof(data.table) == "Instance" then
		picked[data.table] = { roundId = data.table:GetAttribute(TABLE_ATTR.RoundId), name = data.name or "?" }
		signature = ""
	elseif data.kind == "deny" then
		showToast(data.message or "예측할 수 없습니다", red)
	elseif data.kind == "result" then
		if data.correct then
			showToast(data.coins and data.coins > 0 and ("예측 적중! %s 생존 · +%d 코인"):format(data.name or "", data.coins)
				or "예측 적중!", teal)
		else
			showToast(data.name ~= "" and ("아쉽다! %s 님이 살아남았다"):format(data.name) or "아쉽다! 예측이 빗나갔다", cream)
		end
	end
end)
