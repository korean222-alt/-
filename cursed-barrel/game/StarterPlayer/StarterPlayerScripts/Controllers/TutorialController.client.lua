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
-- Phase 14 : 만화풍 굵은 테두리 · 글자 외곽선
require(package.Shared:WaitForChild("UIKit")).restyle(gui)

-- Phase 15 : 알림판 바로 아래, 읽기 쉬운 흰 글씨 (예전에는 옅은 청록 글씨가 반투명 판 위에 떠서 안 보였다)
local UIKit = require(package.Shared:WaitForChild("UIKit"))
local card = Instance.new("TextLabel")
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 196)
card.Size = UDim2.fromOffset(430, 44)
card.BackgroundColor3 = Color3.fromRGB(18, 40, 38)
card.BackgroundTransparency = 0.05
card.TextColor3 = Color3.new(1, 1, 1)
card.FontFace = UIKit.font(true)
card.TextSize = 20
card.TextWrapped = true
card.Visible = false
card.Parent = gui
card:SetAttribute("UIKitStyled", true)
card:SetAttribute("UIKitBox", true)
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
local cap = Instance.new("UISizeConstraint")
cap.MaxSize = Vector2.new(430, 44)
cap.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(120, 255, 214)
stroke.Thickness = 2.5
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
			text = "연습 판!"
		elseif state == STATES.Playing then
			if os.clock() < catchHintUntil then
				text = "해적이 나오면 누르세요!"
			elseif model:GetAttribute(TABLE_ATTR.BraveOfferUserId) == player.UserId then
				text = "「한 번 더」 = 보너스 코인"
			elseif model:GetAttribute(TABLE_ATTR.CurrentTurnUserId) == player.UserId then
				text = "내 차례! 자리를 고르세요"
			else
				text = nil
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
		text = "연습 끝!"
	end
	card.Visible = text ~= nil
	if text then
		card.Text = text
	end
end)
