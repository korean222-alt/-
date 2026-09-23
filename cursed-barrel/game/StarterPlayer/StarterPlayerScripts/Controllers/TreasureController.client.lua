-- TreasureController  (Phase 11)
-- 현상금을 눈으로 보여 준다. (각자 화면에만 있는 장식 · 판정과 무관)
--
--   · 테이블 위, 통 둘레에 금화 더미가 쌓인다. 현상금이 오를수록 더미가 늘어난다.
--   · 보물 폭발(Surge)이 터지면 통 위에서 금화가 비처럼 쏟아진다. 크라켄의 보물은 보석까지 섞인다.
--   · 승자가 정해지면 더미가 승자에게 날아간다. 가져가지 못한 몫(이월)은 테이블 위에 남는다.
--   · 기다리는 테이블에도 이월된 금화가 쌓여 보인다. ("저 테이블엔 금화가 쌓여 있네" → 앉고 싶어진다)
--
-- 성능 : 카메라에서 가까운 테이블(NEAR)만 만든다. 한 테이블에 금화는 많아야 MAX_COINS 개.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Tags = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local package = RS:WaitForChild("CursedBarrel")
local config = require(package.Shared:WaitForChild("GameConfig"))
local remotes = package:WaitForChild("Remotes")
local cues = remotes:WaitForChild("PresentationCue")
local TABLE_ATTR = config.TableAttributes
local STATES = config.States

local NEAR = 80
local MAX_COINS = 60
local GOLD = Color3.fromRGB(255, 204, 72)
local GEMS = { Color3.fromRGB(255, 80, 90), Color3.fromRGB(90, 220, 255), Color3.fromRGB(150, 110, 255), Color3.fromRGB(110, 255, 150) }

local folder = Instance.new("Folder")
folder.Name = "CursedBarrel_Treasure"
folder.Parent = workspace

local piles = {} -- [table model] = { coins = {}, shown = 0, override = nil }

local function reduced()
	return player:GetAttribute("Setting_reducedFX") == true
end

local function geometry(model)
	local top = model:FindFirstChild("TableTop", true)
	local barrel = model:FindFirstChild("Barrel")
	local body = barrel and barrel:FindFirstChild("Body")
	if not (top and top:IsA("BasePart") and body and body:IsA("BasePart")) then
		return nil
	end
	local topRadius = (top:IsA("Part") and top.Shape == Enum.PartType.Cylinder) and top.Size.Y * 0.5 or math.max(top.Size.X, top.Size.Z) * 0.5
	local topHeight = (top:IsA("Part") and top.Shape == Enum.PartType.Cylinder) and top.Size.X or top.Size.Y
	local barrelRadius = (body:IsA("Part") and body.Shape == Enum.PartType.Cylinder) and body.Size.Y * 0.5 or math.max(body.Size.X, body.Size.Z) * 0.5
	return {
		center = Vector3.new(body.Position.X, top.Position.Y + topHeight * 0.5, body.Position.Z),
		inner = barrelRadius + 0.55,
		outer = math.max(barrelRadius + 1, topRadius - 0.45),
		lid = body.Position + Vector3.new(0, 2.6, 0),
	}
end

local function makeCoin(cf, gem)
	local p = Instance.new("Part")
	p.Name = gem and "Gem" or "Coin"
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	if gem then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.34, 0.34, 0.34)
		p.Material = Enum.Material.Neon
		p.Color = gem
	else
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.1, 0.52, 0.52)
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.25
		p.Color = GOLD
	end
	p.CFrame = cf
	p.Parent = folder
	return p
end

-- i 번째 금화가 놓일 자리. 같은 i 는 항상 같은 자리 (더미가 들썩이지 않는다)
local function slotCFrame(geo, i, seed)
	local stack = math.floor((i - 1) / 4)
	local level = (i - 1) % 4
	local angle = seed + stack * 2.39996
	local span = geo.outer - geo.inner
	local radius = geo.inner + span * (((stack * 0.618) % 1) * 0.85 + 0.1)
	local pos = geo.center + Vector3.new(math.cos(angle) * radius, 0.05 + level * 0.1, math.sin(angle) * radius)
	-- 동전은 원통의 축(X)을 세워 눕힌다. 쌓일수록 살짝 어긋난다.
	return CFrame.new(pos + Vector3.new(math.sin(i * 1.7) * 0.05, 0, math.cos(i * 2.3) * 0.05)) * CFrame.Angles(0, i * 0.7, math.pi / 2)
end

local function coinCount(amount)
	if amount <= 0 then
		return 0
	end
	return math.clamp(math.floor(math.sqrt(amount) * 1.3), 1, MAX_COINS)
end

local function amountOf(model)
	local entry = piles[model]
	if entry and entry.override then
		return entry.override
	end
	local state = model:GetAttribute(TABLE_ATTR.State)
	if state == STATES.Starting or state == STATES.Playing or state == STATES.RoundEnding then
		return model:GetAttribute(TABLE_ATTR.Pot) or 0
	end
	return model:GetAttribute(TABLE_ATTR.PotCarry) or 0
end

local function clear(entry)
	for _, coin in ipairs(entry.coins) do
		coin:Destroy()
	end
	table.clear(entry.coins)
	entry.shown = 0
end

local function refresh(model, animate)
	local entry = piles[model]
	if not entry then
		return
	end
	local geo = entry.geo
	local want = coinCount(amountOf(model))
	if want < entry.shown then
		for i = entry.shown, want + 1, -1 do
			local coin = entry.coins[i]
			if coin then
				coin:Destroy()
			end
			entry.coins[i] = nil
		end
		entry.shown = want
		return
	end
	for i = entry.shown + 1, want do
		local gem = (i % 9 == 0) and GEMS[(i // 9 - 1) % #GEMS + 1] or nil
		local cf = slotCFrame(geo, i, entry.seed)
		local final = gem and CFrame.new(cf.Position + Vector3.new(0, 0.12, 0)) or cf
		local coin = makeCoin((animate and not reduced()) and (final + Vector3.new(0, 1.8, 0)) or final, gem)
		if animate and not reduced() then
			Tween:Create(coin, TweenInfo.new(0.35 + (i % 5) * 0.04, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = final }):Play()
		end
		entry.coins[i] = coin
	end
	entry.shown = want
end

local function track(model)
	if piles[model] then
		return
	end
	local geo = geometry(model)
	if not geo then
		return
	end
	local seed = 0
	for _, byte in ipairs({ string.byte(model:GetAttribute(TABLE_ATTR.TableId) or model.Name, 1, -1) }) do
		seed += byte
	end
	piles[model] = { coins = {}, shown = 0, geo = geo, seed = seed % 7, connections = {} }
	local entry = piles[model]
	for _, name in ipairs({ TABLE_ATTR.Pot, TABLE_ATTR.PotCarry, TABLE_ATTR.State }) do
		table.insert(entry.connections, model:GetAttributeChangedSignal(name):Connect(function()
			if name == TABLE_ATTR.State then
				local state = model:GetAttribute(TABLE_ATTR.State)
				if state == STATES.Waiting or state == STATES.Starting then
					entry.override = nil
				end
			end
			refresh(model, true)
		end))
	end
	refresh(model, false)
end

local function untrack(model)
	local entry = piles[model]
	if not entry then
		return
	end
	for _, connection in ipairs(entry.connections) do
		connection:Disconnect()
	end
	clear(entry)
	piles[model] = nil
end

--------------------------------------------------
-- 금화 비 (보물 폭발)
--------------------------------------------------
local function rain(model, tier)
	local geo = geometry(model)
	if not geo then
		return
	end
	local count = ({ pouch = 14, chest = 26, kraken = 44 })[tier] or 14
	if reduced() then
		count = math.floor(count / 3)
	end
	for i = 1, count do
		task.delay(i * 0.018, function()
			local angle = math.random() * math.pi * 2
			local radius = geo.inner + math.random() * (geo.outer - geo.inner)
			local land = geo.center + Vector3.new(math.cos(angle) * radius, 0.08, math.sin(angle) * radius)
			local from = geo.lid + Vector3.new(math.cos(angle) * 0.6, 1.2 + math.random() * 1.5, math.sin(angle) * 0.6)
			local gem = tier == "kraken" and (i % 4 == 0) and GEMS[i % #GEMS + 1] or nil
			local coin = makeCoin(CFrame.new(from) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6), gem)
			-- 통 위로 한 번 튀어 올랐다가 테이블에 떨어진다
			local peak = from:Lerp(land, 0.35) + Vector3.new(0, 2 + math.random() * 1.5, 0)
			Tween:Create(coin, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(peak) * CFrame.Angles(math.random() * 6, 0, math.random() * 6) }):Play()
			task.delay(0.22, function()
				if coin.Parent then
					Tween:Create(coin, TweenInfo.new(0.38, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = CFrame.new(land) * CFrame.Angles(0, angle, math.pi / 2) }):Play()
				end
			end)
			task.delay(1.4, function()
				if coin.Parent then
					Tween:Create(coin, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				end
			end)
			Debris:AddItem(coin, 1.9)
		end)
	end
	-- 크라켄의 보물은 보랏빛 고리가 퍼진다
	if tier == "kraken" and not reduced() then
		local ring = Instance.new("Part")
		ring.Name = "TreasureRing"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(196, 130, 255)
		ring.Size = Vector3.new(0.08, 1, 1)
		ring.CFrame = CFrame.new(geo.center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.2
		ring.Parent = folder
		Tween:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.02, 16, 16), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.8)
	end
end

--------------------------------------------------
-- 승자에게 날아가기
--------------------------------------------------
local function characterOf(model, userId)
	local actor = Players:GetPlayerByUserId(userId or 0)
	if actor then
		return actor.Character
	end
	for _, seat in ipairs(model:GetDescendants()) do
		if seat:IsA("Seat") and seat:GetAttribute(config.SeatAttributes.OccupantUserId) == userId and seat.Occupant then
			return seat.Occupant.Parent
		end
	end
	return nil
end

local function flyToWinner(model, data)
	local entry = piles[model]
	if not entry then
		return
	end
	local keep = math.max(0, tonumber(data.carry) or 0)
	local character = (data.userId or 0) > 0 and characterOf(model, data.userId) or nil
	local head = character and character:FindFirstChild("Head")
	local coins = entry.coins
	entry.coins = {}
	entry.shown = 0
	entry.override = keep
	for i, coin in ipairs(coins) do
		if head and (data.pot or 0) > 0 and not reduced() then
			task.delay(i * 0.02, function()
				if coin.Parent and head.Parent then
					Tween:Create(coin, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = head.CFrame, Transparency = 0.6 }):Play()
				end
			end)
			Debris:AddItem(coin, 0.6 + i * 0.02)
		else
			coin:Destroy()
		end
	end
	-- 현상금 부스터 : 이긴 사람 머리 위로 금화가 한 번 더 쏟아진다
	local winner = Players:GetPlayerByUserId(data.userId or 0)
	if winner and winner:GetAttribute("Booster") == true and (data.pot or 0) > 0 then
		rain(model, "chest")
	end
	-- 가져가지 못한 몫은 금화로 다시 쌓인다 (이월)
	task.delay(0.6, function()
		if piles[model] == entry then
			refresh(model, true)
		end
	end)
end

cues.OnClientEvent:Connect(function(kind, model, data)
	if typeof(model) ~= "Instance" or typeof(data) ~= "table" or not piles[model] then
		return
	end
	if kind == "Surge" then
		rain(model, data.tier)
	elseif kind == "Win" then
		flyToWinner(model, data)
	end
end)

--------------------------------------------------
-- 가까운 테이블만 만든다
--------------------------------------------------
local checkAt = 0
Run.Heartbeat:Connect(function()
	if os.clock() < checkAt then
		return
	end
	checkAt = os.clock() + 1
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	if not eye then
		return
	end
	for _, model in ipairs(Tags:GetTagged(config.Tags.Table)) do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			local pivot = model:GetPivot().Position
			local near = (pivot - eye).Magnitude < NEAR
			if near and not piles[model] then
				track(model)
			elseif not near and piles[model] then
				untrack(model)
			end
		end
	end
	for model in pairs(piles) do
		if not model:IsDescendantOf(workspace) then
			untrack(model)
		end
	end
end)
