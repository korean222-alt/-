-- TutorialController  (Phase 12 · Phase 32)
-- 연습 판 안내. 처음 온 사람이 AI 선원과 한 판을 하며 한 단계씩 안내를 받는다.
--
-- Phase 32 : 튜토리얼은 필수다 (서버 OnboardingService 가 처음 온 사람을 연습 테이블에 앉힌다).
--   · 해적 종류 다섯을 하나씩 잡아 봐야 끝난다. 왼쪽에 체크 목록 (테이블 Attribute TutorialStep)
--   · 튜토리얼 동안 내 칼은 늘 해적 자리에 꽂힌다. 놓쳐도 탈락하지 않고 같은 해적이 다시 나온다.
--   · 해적이 나오기 전에 설명 카드가 뜬다 (Phase4Controller)
--   · 튜토리얼을 마치기 전에 다른 테이블에 앉으려 하면 서버가 되돌리고 SeatBlocked 로 알린다

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Tags = game:GetService("CollectionService")

local player = Players.LocalPlayer
local package = RS:WaitForChild("CursedBarrel")
local config = require(package.Shared:WaitForChild("GameConfig"))
local UIKit = require(package.Shared:WaitForChild("UIKit"))
local remotes = package:WaitForChild("Remotes")
local catchPrompt = remotes:WaitForChild(config.Remotes.CatchPrompt)

local TABLE_ATTR = config.TableAttributes
local STATES = config.States
local KINDS = config.PirateKinds
local TUTORIAL = config.Tutorial

local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_Tutorial"
gui.ResetOnSpawn = false
gui.DisplayOrder = 13
gui.Parent = player:WaitForChild("PlayerGui")
-- Phase 14 : 만화풍 굵은 테두리 · 글자 외곽선
UIKit.restyle(gui)

-- Phase 15 : 알림판 바로 아래, 읽기 쉬운 흰 글씨 (예전에는 옅은 청록 글씨가 반투명 판 위에 떠서 안 보였다)
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

-- Phase 21 : 위 알림판 바로 아래에 붙인다 (예전 196px 고정이라 가로 휴대폰에서는 칼 고르는 창 위를 덮었다)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card
local function fitCard()
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local s = math.clamp(math.min((view.X - 20) / 450, view.Y / 560), 0.6, 1)
	cardScale.Scale = math.min(1, s + 0.15)
	card.Position = UDim2.new(0.5, 0, 0, 50 + math.floor(100 * s) + 6)
end
fitCard()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitCard)
end

--------------------------------------------------
-- Phase 32 : 왼쪽 체크 목록 (해적 다섯 종류)
--------------------------------------------------
local list = Instance.new("Frame")
list.Name = "TutorialChecklist"
list.AnchorPoint = Vector2.new(0, 0.5)
list.Position = UDim2.new(0, 14, 0.52, 0)
list.Size = UDim2.fromOffset(270, 60)
list.AutomaticSize = Enum.AutomaticSize.Y
list.BackgroundColor3 = Color3.new(1, 1, 1)
list.Visible = false
list.Active = false
list.Parent = gui
UIKit.gradient(list, UIKit.Colors.Body, UIKit.Colors.BodyDark, 90)
UIKit.corner(list, 14)
UIKit.outline(list, 3.5)
UIKit.autoScale(list, UIKit.phoneFactor)
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 10)
listPadding.PaddingBottom = UDim.new(0, 10)
listPadding.PaddingLeft = UDim.new(0, 12)
listPadding.PaddingRight = UDim.new(0, 12)
listPadding.Parent = list
local listTitle = UIKit.label(list, { text = "🎓 튜토리얼 · 해적 잡기", size = UDim2.new(1, 0, 0, 30), textSize = 20, color = UIKit.Colors.Gold, stroke = 2.5 })
listTitle.LayoutOrder = 0
listTitle.TextXAlignment = Enum.TextXAlignment.Left
local rows = {}
for index, kindId in ipairs(TUTORIAL.Kinds or {}) do
	local def = KINDS.List[kindId] or {}
	local row = UIKit.label(list, { text = "", size = UDim2.new(1, 0, 0, 30), textSize = 18, color = UIKit.Colors.Cream, stroke = 2 })
	row.LayoutOrder = index
	row.TextXAlignment = Enum.TextXAlignment.Left
	rows[index] = { label = row, def = def }
end
local listFoot = UIKit.label(list, { text = "놓쳐도 괜찮아요! 다시 나와요", size = UDim2.new(1, 0, 0, 24), textSize = 15, color = UIKit.Colors.Cream, stroke = 2 })
listFoot.LayoutOrder = 99
listFoot.TextXAlignment = Enum.TextXAlignment.Left

local function drawList(step)
	for index, row in ipairs(rows) do
		local def = row.def
		local done = index < step
		local now = index == step
		row.label.Text = ("%s %s %s  %s"):format(done and "✔" or (now and "▶" or "·"), def.icon or "", def.name or "", now and ("— " .. (def.short or "")) or "")
		row.label.TextColor3 = done and UIKit.Colors.Green or (now and (def.color or UIKit.Colors.Gold) or UIKit.Colors.Cream)
		row.label.TextTransparency = (done or now) and 0 or 0.35
	end
end

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

-- Phase 32 : 튜토리얼을 마치기 전에 다른 테이블에 앉으려 했다 (서버가 되돌렸다)
player:GetAttributeChangedSignal("SeatBlocked"):Connect(function()
	local why = tostring(player:GetAttribute("SeatBlocked") or ""):match("^(%a+)")
	if why == "tutorial" then
		UIKit.toast("🎓 먼저 튜토리얼을 끝내 주세요! 곧 튜토리얼 테이블로 안내해요", UIKit.Colors.Gold, 3)
	elseif why == "busy" then
		UIKit.toast("다른 선원이 튜토리얼 중인 테이블이에요", UIKit.Colors.Cream, 2.4)
	end
end)
player:GetAttributeChangedSignal("TutorialFree"):Connect(function()
	if player:GetAttribute("TutorialFree") == true then
		UIKit.toast("빈 연습 테이블이 없어서 바로 시작해요! 처음 몇 판은 🛟 신입 보호가 있어요", UIKit.Colors.Gold, 3.4)
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
	local step = mine and (model:GetAttribute("TutorialStep") or 0) or 0
	local total = #(TUTORIAL.Kinds or {})
	if mine then
		local state = model:GetAttribute(TABLE_ATTR.State)
		if state == STATES.Waiting or state == STATES.Countdown or state == STATES.Starting then
			text = total > 0 and "🎓 튜토리얼! 해적 다섯 종류를 잡아 봐요" or "연습 판!"
		elseif state == STATES.Playing then
			if os.clock() < catchHintUntil then
				text = nil -- 해적 설명 카드 · 잡기 안내가 대신한다
			elseif model:GetAttribute(TABLE_ATTR.CurrentTurnUserId) == player.UserId and step >= 1 and step <= total then
				text = "🗡 칼 꽂을 자리를 골라요 (튜토리얼에서는 늘 해적이 나와요)"
			elseif model:GetAttribute(TABLE_ATTR.BraveOfferUserId) == player.UserId then
				text = "자리를 또 누르면 계속 꽂기 = 보너스 코인" -- Phase 24.10 : "한 번 더" 버튼 없음
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
		text = player:GetAttribute("TutorialDone") == true and "🎓 튜토리얼 끝! 이제 다른 선원들과 겨뤄 봐요" or "연습 끝!"
	end
	-- Phase 32 : 아직 안 앉았는데 튜토리얼을 기다리는 중
	if not mine and not seatedTable() and player:GetAttribute("TutorialActive") == true and player:GetAttribute("TutorialDone") ~= true then
		text = "🎓 곧 튜토리얼 테이블로 안내해요…"
	end
	card.Visible = text ~= nil
	if text then
		card.Text = text
	end
	-- 체크 목록 : 튜토리얼 판이 진행 중일 때만
	local showList = mine and step >= 1 and total > 0 and model:GetAttribute(TABLE_ATTR.State) ~= STATES.Waiting
	list.Visible = showList == true and player:GetAttribute("PirateFocus") ~= true
	if list.Visible then
		drawList(step)
	end
end)
