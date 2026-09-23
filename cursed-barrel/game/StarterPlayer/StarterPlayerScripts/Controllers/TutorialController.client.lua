-- TutorialController  (Phase 12)
-- 연습 판 안내. 처음 온 사람이 "연습 한 판"을 누르면 AI 선원 둘과 한 판을 하며 한 단계씩 안내를 받는다.
-- (연습 판의 첫 해적은 잡기 쉽다 : 서버 RoundService 가 창을 넓혀 준다)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Tags = game:GetService("CollectionService")

local player = Players.LocalPlayer
local package = RS:WaitForChild("CursedBarrel")
local config = require(package.Shared:WaitForChild("GameConfig"))
local remotes = package:WaitForChild("Remotes")
local catchPrompt = remotes:WaitForChild(config.Remotes.CatchPrompt)

local TABLE_ATTR = config.TableAttributes
local STATES = config.States

local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_Tutorial"
gui.ResetOnSpawn = false
gui.DisplayOrder = 13
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("TextLabel")
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 150)
card.Size = UDim2.fromOffset(460, 54)
card.BackgroundColor3 = Color3.fromRGB(20, 44, 40)
card.BackgroundTransparency = 0.1
card.TextColor3 = Color3.fromRGB(200, 255, 236)
card.Font = Enum.Font.GothamBold
card.TextSize = 15
card.TextWrapped = true
card.Visible = false
card.Parent = gui
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
local cap = Instance.new("UISizeConstraint")
cap.MaxSize = Vector2.new(460, 54)
cap.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(120, 255, 214)
stroke.Thickness = 2
stroke.Parent = card

local catchHintUntil = 0
local finishedUntil = 0
local lastTable = nil

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

catchPrompt.OnClientEvent:Connect(function(model, data)
	if typeof(data) == "table" and data.mine and model == lastTable then
		catchHintUntil = os.clock() + 3.5
	end
end)

local checkAt = 0
Run.Heartbeat:Connect(function()
	if os.clock() < checkAt then
		return
	end
	checkAt = os.clock() + 0.2
	local model = seatedTable() or lastTable
	local mine = model and model:GetAttribute(TABLE_ATTR.Tutorial) == player.UserId
	if mine then
		lastTable = model
	end
	local text = nil
	if mine then
		local state = model:GetAttribute(TABLE_ATTR.State)
		if state == STATES.Waiting or state == STATES.Countdown or state == STATES.Starting then
			text = "연습 판이에요!  AI 선원 둘과 함께합니다. 처음 해적은 잡기 쉬워요"
		elseif state == STATES.Playing then
			if os.clock() < catchHintUntil then
				text = "③ 해적이 튀어나오면 그때 누르세요!  가짜 손에 속아 먼저 누르면 탈락"
			elseif model:GetAttribute(TABLE_ATTR.BraveOfferUserId) == player.UserId then
				text = "「한 번 더」를 누르면 보너스 코인!  대신 통이 더 위험해져요"
			elseif model:GetAttribute(TABLE_ATTR.CurrentTurnUserId) == player.UserId then
				text = "① 내 차례!  아래에서 칼 자리를 하나 누르세요 (해적이 숨어 있을 수도)"
			else
				text = "② AI 선원이 고르는 중…  위험한 자리를 뽑으면 해적이 튀어나와요"
			end
		elseif state == STATES.RoundEnding then
			finishedUntil = os.clock() + 6
		end
	elseif lastTable and lastTable:GetAttribute(TABLE_ATTR.Tutorial) ~= player.UserId then
		if lastTable:GetAttribute(TABLE_ATTR.State) == STATES.RoundEnding or os.clock() < finishedUntil then
			finishedUntil = math.max(finishedUntil, os.clock() + 5)
		end
		lastTable = nil
	end
	if not text and os.clock() < finishedUntil then
		text = "연습 끝!  이제 다른 사람들과 해 보세요 · 오른쪽 위 날씨에 따라 규칙이 바뀌어요"
	end
	card.Visible = text ~= nil
	if text then
		card.Text = text
	end
end)
