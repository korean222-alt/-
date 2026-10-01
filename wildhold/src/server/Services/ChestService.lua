-- 보물상자 (v2 도파민 포인트): 유적과 스폰 근처의 상자를 [E] 로 연다.
--  · 열면 모든 화면에서 상자가 덜컹거리다 뚜껑이 열리고 등급 색 빛이 터진다 (클라이언트 ChestController, FX "Chest")
--  · OpenDelay 뒤 자원이 상자에서 튀어나오고(가까이 있으면 저절로 빨려 들어옴) 아이템은 바로 소지품으로 (FX "Loot")
--  · 스폰 근처 첫 상자는 대원마다 판마다 한 번씩. 유적 상자는 열리면 Refill 초 뒤 다시 채워진다
-- 상자 목록은 MapService.Chests ({Id, Model, Hit, Tier, PerPlayer, Pos, Zone}), 수치는 ChestConfig.
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local L = require(RS.Shared.Modules.Locale)
local CC = require(RS.Shared.Config.ChestConfig)
local I = require(RS.Shared.Config.ItemConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local S = {}

function S:Init(ctx)
	self.ctx, self.Rng = ctx, Random.new()
	self.List = ctx.Map.Chests or {}
	self.Opened = {} -- [chest] = {[player] = true} (대원별 상자) / true (공용 상자)
	self.Busy = {}
	for _, chest in ipairs(self.List) do
		local prompt = U.prompt(chest.Hit, "OpenChest", L.M("prompt.openChest"), Enum.KeyCode.E, Vector3.new(0, 1, 0))
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = CC.Range
		prompt.RequiresLineOfSight = false
		L.tag(prompt, "ObjectText", L.M("chest.tier." .. chest.Tier))
		chest.Prompt = prompt
		prompt.Triggered:Connect(function(player) self:Open(player, chest) end)
	end
	self:Reset()
end

function S:Reset()
	if not self.ctx then return end
	for _, chest in ipairs(self.List) do
		self.Opened[chest], self.Busy[chest], chest.RefillAt = nil, nil, nil
		chest.Model:SetAttribute("Open", false)
		chest.Model:SetAttribute("OpenedBy", "")
		if chest.Prompt then chest.Prompt.Enabled = true end
	end
end

function S:HasOpened(player, chest)
	local opened = self.Opened[chest]
	if opened == true then return true end
	return opened ~= nil and opened[player] == true
end

-- 스폰 근처 첫 상자를 이 대원이 열었나 (튜토리얼 첫 목표)
function S:OpenedStarter(player)
	for _, chest in ipairs(self.List) do
		if chest.PerPlayer and self:HasOpened(player, chest) then return true end
	end
	return false
end

function S:Starter()
	for _, chest in ipairs(self.List) do
		if chest.PerPlayer then return chest end
	end
	return nil
end

-- 가장 가까운 아직 안 연 상자 (목표 표시용)
function S:NearestClosed(player, position, maxDistance)
	local best, distance = nil, maxDistance or math.huge
	for _, chest in ipairs(self.List) do
		local d = (chest.Pos - position).Magnitude
		if d < distance and not self:HasOpened(player, chest) and not self.Busy[chest] then best, distance = chest, d end
	end
	return best
end

function S:Open(player, chest)
	if not self.ctx.Run:IsParticipant(player) or not self.ctx.Data:Ready(player) then return end
	local phase = self.ctx.Clock.Phase
	if phase ~= "Day" and phase ~= "Night" then return end
	if not U.near(player, chest.Pos, CC.Range + 2) then return end
	if self.Busy[chest] then return end
	if self:HasOpened(player, chest) then
		self.ctx.Notify(player, L.M(chest.PerPlayer and "chest.alreadyMine" or "chest.empty"))
		return
	end
	-- 열림 표시 (대원별 상자는 연 사람 목록, 공용 상자는 Open)
	if chest.PerPlayer then
		self.Opened[chest] = self.Opened[chest] or {}
		self.Opened[chest][player] = true
		local ids = {}
		for who in pairs(self.Opened[chest]) do table.insert(ids, tostring(who.UserId)) end
		chest.Model:SetAttribute("OpenedBy", "," .. table.concat(ids, ",") .. ",")
	else
		self.Opened[chest] = true
		self.Busy[chest] = true
		chest.Model:SetAttribute("Open", true)
		chest.Prompt.Enabled = false
		chest.RefillAt = os.clock() + CC.Refill
	end
	self.ctx.FX:FireAllClients("Chest", chest.Model, player, chest.Tier)
	task.delay(CC.OpenDelay, function()
		if player.Parent and self.ctx.Run:IsParticipant(player) then self:GiveLoot(player, chest) end
	end)
end

-- 전리품: 자원은 상자에서 튀어나오는 떨어진 자원, 아이템은 바로 소지품으로
function S:GiveLoot(player, chest)
	local spec = CC.Tiers[chest.Tier]
	local rng = self.Rng
	local top = chest.Pos + Vector3.new(0, 3, 0)
	for _, kind in ipairs(R.Order) do
		local range = spec.Res[kind]
		if range then
			local amount = rng:NextInteger(range[1], range[2])
			local pieces = math.min(3, amount)
			for n = 1, pieces do
				local part = math.floor(amount / pieces) + (n <= amount % pieces and 1 or 0)
				local a = rng:NextNumber() * math.pi * 2
				local r = 3 + rng:NextNumber() * 3
				self.ctx.Resources:Drop(kind, part, chest.Pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), top)
			end
		end
	end
	local items = self.ctx.Crafting.Items[player]
	local got = {}
	if items then
		local list = {}
		for id, n in pairs(spec.Items or {}) do table.insert(list, {id, n}) end
		table.sort(list, function(a, b) return a[1] < b[1] end)
		local want = spec.Pick or #list
		while #list > want do table.remove(list, rng:NextInteger(1, #list)) end
		if spec.Upgrade then
			local up = self:UpgradeFor(items)
			if up then table.insert(list, 1, {up, 1}) end
		end
		for _, entry in ipairs(list) do
			local id, n = entry[1], entry[2]
			local item = I.Items[id]
			if item then
				local limit = (item.Kind == "Tool" or item.Kind == "Bag") and 1 or I.Limit
				local add = math.max(0, math.min(n, limit - (items[id] or 0)))
				if add > 0 then
					items[id] = (items[id] or 0) + add
					table.insert(got, {id, add})
				end
			end
		end
		self.ctx.Crafting:Sync(player)
	end
	self.ctx.FX:FireClient(player, "Loot", chest.Pos, got, chest.Tier)
	self.ctx.Notify(player, L.M("chest.opened", {tier = L.M("chest.tier." .. chest.Tier)}))
end

-- 영웅 상자: 도끼·곡괭이·창 중 가진 것보다 한 등급 위 (가장 낮은 계열부터)
function S:UpgradeFor(items)
	local best, bestTier = nil, math.huge
	for _, family in ipairs({"Axe", "Pickaxe", "Spear"}) do
		local tier = 0
		for id, spec in pairs(I.Items) do
			if spec.Family == family and (items[id] or 0) > 0 then tier = math.max(tier, spec.Tier) end
		end
		for id, spec in pairs(I.Items) do
			if spec.Family == family and spec.Tier == tier + 1 and spec.Tier <= 3 and tier < bestTier then best, bestTier = id, tier end
		end
	end
	return best
end

-- 유적 상자 다시 채우기
function S:Tick()
	if not self.ctx then return end
	local now = os.clock()
	for _, chest in ipairs(self.List) do
		if chest.RefillAt and now >= chest.RefillAt then
			chest.RefillAt, self.Opened[chest], self.Busy[chest] = nil, nil, nil
			chest.Model:SetAttribute("Open", false)
			chest.Prompt.Enabled = true
		end
	end
end

return S
