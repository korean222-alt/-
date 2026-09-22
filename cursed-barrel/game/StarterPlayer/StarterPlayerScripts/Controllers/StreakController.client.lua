--[[
	StreakController  (Phase 8)
	연승 기록을 플레이어 머리 위에 띄운다. 불꽃 안에 숫자가 들어간다.

	요청하신 그대로입니다.
	  "연승기록도 플레이어 위에 숫자로 띄워줘 불 표시 안에"

	· 2연승부터 보인다. 1연승은 그냥 한 판 이긴 것이라 표시가 시끄럽기만 하다.
	· 연승이 쌓이면 불꽃 색이 바뀐다. (주황 → 붉은 → 보라 → 청록)
	· 서버가 Player 의 Streak Attribute 를 갱신하면 자동으로 따라간다.
	  RemoteEvent 가 필요 없고, 늦게 접속한 사람에게도 그대로 보인다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local PLAYER_ATTR = GameConfig.PlayerAttributes
local STREAK = GameConfig.Streak

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local badges = {} -- [Player] = { gui, flame, count, glow, connections }
local vipTags = {} -- [Player] = BillboardGui  (Phase 10 : VIP 패스 표시)

--------------------------------------------------
-- 배지 만들기
--------------------------------------------------

local function buildBadge(player, head)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CursedBarrel_Streak"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(66, 78)
	gui.StudsOffset = Vector3.new(0, 2.9, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = STREAK.MaxDistance
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	-- 불꽃. 이모지 한 글자가 가장 또렷하고 가볍다.
	local flame = Instance.new("TextLabel")
	flame.Name = "Flame"
	flame.Size = UDim2.fromScale(1, 1)
	flame.BackgroundTransparency = 1
	flame.Font = Enum.Font.GothamBlack
	flame.Text = "🔥"
	flame.TextSize = 62
	flame.TextColor3 = Color3.new(1, 1, 1)
	flame.Parent = gui

	-- 불꽃 뒤에 깔리는 은은한 빛
	local glow = Instance.new("UIStroke")
	glow.Color = STREAK.Tiers[1].color
	glow.Thickness = 2
	glow.Transparency = 0.5
	glow.Parent = flame

	-- 숫자. 불꽃 가운데보다 살짝 아래에 둔다. (불꽃의 넓은 부분)
	local count = Instance.new("TextLabel")
	count.Name = "Count"
	count.AnchorPoint = Vector2.new(0.5, 0.5)
	count.Position = UDim2.fromScale(0.5, 0.62)
	count.Size = UDim2.fromOffset(60, 30)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBlack
	count.TextSize = 22
	count.TextColor3 = Color3.fromRGB(28, 20, 14)
	count.TextStrokeTransparency = 0.25
	count.TextStrokeColor3 = Color3.fromRGB(255, 240, 210)
	count.Text = ""
	count.Parent = gui

	return { gui = gui, flame = flame, count = count, glow = glow }
end

local function destroyBadge(player)
	local badge = badges[player]
	if not badge then
		return
	end
	if badge.gui then
		badge.gui:Destroy()
	end
	badges[player] = nil
end

--------------------------------------------------
-- VIP 표시 (Phase 10)
-- 서버가 게임패스 소유를 확인하고 Player 의 VIP Attribute 를 켠다. 여기서는 보여 주기만 한다.
--------------------------------------------------

local function destroyVipTag(player)
	local tag = vipTags[player]
	if tag then
		tag:Destroy()
		vipTags[player] = nil
	end
end

local function refreshVip(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if player:GetAttribute(PLAYER_ATTR.VIP) ~= true or not head then
		destroyVipTag(player)
		return
	end
	local tag = vipTags[player]
	if tag and tag.Parent and tag.Adornee == head then
		return
	end
	destroyVipTag(player)

	tag = Instance.new("BillboardGui")
	tag.Name = "CursedBarrel_VIP"
	tag.Adornee = head
	tag.Size = UDim2.fromOffset(52, 20)
	tag.StudsOffset = Vector3.new(0, 1.7, 0)
	tag.AlwaysOnTop = false
	tag.MaxDistance = 60
	tag.LightInfluence = 0
	tag.ResetOnSpawn = false
	tag.Parent = playerGui

	local plate = Instance.new("TextLabel")
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Color3.fromRGB(44, 28, 8)
	plate.BackgroundTransparency = 0.15
	plate.Font = Enum.Font.GothamBlack
	plate.TextSize = 13
	plate.TextColor3 = Color3.fromRGB(255, 214, 120)
	plate.Text = "VIP"
	plate.Parent = tag
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = plate
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 214, 120)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = plate

	vipTags[player] = tag
end

--------------------------------------------------
-- 갱신
--------------------------------------------------

local function refresh(player)
	local streak = tonumber(player:GetAttribute(PLAYER_ATTR.Streak)) or 0
	local character = player.Character
	local head = character and character:FindFirstChild("Head")

	if streak < STREAK.MinToShow or not head then
		destroyBadge(player)
		return
	end

	local badge = badges[player]
	if not badge or not badge.gui.Parent then
		badge = buildBadge(player, head)
		badges[player] = badge
	elseif badge.gui.Adornee ~= head then
		badge.gui.Adornee = head
	end

	local tier = GameConfig.streakTier(streak)
	badge.count.Text = tostring(streak)
	badge.glow.Color = tier.color
	badge.flame.TextColor3 = tier.color

	-- 새 연승이 붙으면 한 번 튀어오른다.
	if badge.lastStreak and streak > badge.lastStreak then
		badge.gui.Size = UDim2.fromOffset(92, 108)
		TweenService:Create(badge.gui, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(66, 78) }):Play()
	end
	badge.lastStreak = streak
end

--------------------------------------------------
-- 감시
--------------------------------------------------

local function watch(player)
	player:GetAttributeChangedSignal(PLAYER_ATTR.Streak):Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal(PLAYER_ATTR.VIP):Connect(function()
		refreshVip(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		task.wait(0.2)
		refresh(player)
		refreshVip(player)
	end)
	player.CharacterRemoving:Connect(function()
		destroyBadge(player)
		destroyVipTag(player)
	end)
	refresh(player)
	refreshVip(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(player)
	destroyBadge(player)
	destroyVipTag(player)
end)

-- 불꽃이 천천히 숨 쉰다. 초당 20번이면 충분하다.
local pulseAt = 0
RunService.Heartbeat:Connect(function()
	if os.clock() - pulseAt < 0.05 then
		return
	end
	pulseAt = os.clock()

	local wave = 0.5 + 0.5 * math.sin(os.clock() * 3.2)
	for player, badge in pairs(badges) do
		if badge.gui.Parent and player.Parent == Players then
			badge.glow.Transparency = 0.25 + 0.4 * wave
			badge.flame.Rotation = math.sin(os.clock() * 2.4 + player.UserId % 10) * 4
		else
			destroyBadge(player)
		end
	end
end)
