-- 판 단위 소지품(도구·덫·먹이·음식·가방·설치 도구)과 제작.
--  손 제작(어디서나): 🔨 제작대 설치 도구. 놓은 제작대 근처: 도구·덫·가방·벽/포탑 설치 도구 (제작대 레벨 조건).
--  요리(v2): 메뉴 없음. 기지 모닥불 근처(GameConfig.CookRadius)에 서 있으면 가방의 버섯이 0.5초마다 하나씩 구운 버섯이 된다 (AutoCook).
--  재료는 내 가방에서 (v2 는 창고 건물이 없다). BenchLevel = 놓인 제작대 중 가장 높은 레벨 (DefenseService 가 정한다)
--  손에 드는 것은 전부 Roblox Tool 로 만들어 Backpack 에 넣는다 → 화면 아래 핫바(HotbarController)에서 골라 든다.
--  Sync 가 0.5초마다 "가진 것 = 가방 속 Tool" 이 되도록 맞추므로, 캐릭터가 늦게 생겨도 도구가 빠지지 않는다.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config.RecipeConfig)
local I = require(RS.Shared.Config.ItemConfig)
local G = require(RS.Shared.Config.GameConfig)
local R = require(RS.Shared.Modules.PetRules)
local U = require(RS.Shared.Modules.Utility)
local Inv = require(RS.Shared.Modules.Inventory)
local ToolLook = require(RS.Shared.Visuals.ToolLook)
local Shop = require(RS.Shared.Config.ShopConfig)
local L = require(RS.Shared.Modules.Locale)
local S = {}

function S:Init(ctx)
	self.ctx, self.Items, self.Last, self.AutoEquip, self.NextSync, self.NextCook = ctx, {}, {}, {}, 0, 0
	self.BenchLevel = self.BenchLevel or 0
end
function S:AddPlayer(player)
	local items = R.copy(I.Starter)
	-- 코인으로 해금한 시작 보급
	local profile = self.ctx.Data and self.ctx.Data:Get(player)
	for id, owned in pairs(profile and profile.Perks or {}) do
		local perk = Shop.Perks[id]
		if owned and perk then
			for item, n in pairs(perk.Give) do items[item] = (items[item] or 0) + n end
		end
	end
	self.Items[player] = items
	self.AutoEquip[player] = true
end

-- 보급 해금: 코인을 쓰고 영구 저장. 이번 원정에도 바로 받는다.
function S:BuyPerk(player, id)
	local perk = Shop.Perks[id]
	local profile = self.ctx.Data:Get(player)
	if not perk or not profile or not self.Items[player] then return end
	if os.clock() - (self.Last[player] or -100) < 0.4 then return end
	self.Last[player] = os.clock()
	if profile.Perks[id] then self.ctx.Notify(player, L.M("perk.owned")); return end
	if profile.Coins < perk.Cost then self.ctx.Notify(player, L.M("perk.noCoins")); return end
	local ok = self.ctx.Data:Mutate(player, function(data)
		if data.Perks[id] or data.Coins < perk.Cost then return end
		data.Coins = data.Coins - perk.Cost
		data.Perks[id] = true
	end)
	if ok and profile.Perks[id] then
		for item, n in pairs(perk.Give) do self.Items[player][item] = (self.Items[player][item] or 0) + n end
		self.ctx.Notify(player, L.M("perk.unlockedNow", {icon = perk.Icon, name = L.M("perk." .. id)}))
		self:Sync(player)
	end
end
function S:RemovePlayer(player)
	self.Items[player], self.Last[player], self.AutoEquip[player] = nil, nil, nil
end
function S:Reset()
	for player in pairs(self.Items) do self:AddPlayer(player) end
end

function S:Capacity(player)
	return Inv.capacity(self.Items[player] or {}, I)
end
function S:Best(player, family)
	return Inv.best(self.Items[player] or {}, family, I)
end
function S:Use(player, item)
	local inventory = self.Items[player]
	if inventory and (inventory[item] or 0) > 0 then
		inventory[item] = inventory[item] - 1
		return true
	end
	return false
end

-- 가진 것과 Backpack/손의 Tool 을 맞춘다
function S:Sync(player)
	local items = self.Items[player]
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not items or not backpack then return end
	local character = player.Character
	local human = character and character:FindFirstChildOfClass("Humanoid")
	local bag = self.ctx.Resources.Bags[player]
	local want = {}
	for _, id in ipairs(Inv.hotbar(items, bag, I)) do want[id] = true end
	local have, lostFamily = {}, nil
	for _, container in ipairs({backpack, character}) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") then
					local id = tool:GetAttribute("ItemId")
					if id and want[id] and not have[id] then
						have[id] = tool
					else
						-- 다 쓴 소모품, 더 좋은 등급으로 바뀐 도구, 우리 것이 아닌 도구
						if container == character and id and I.Items[id] then lostFamily = I.Items[id].Family or "" end
						tool:Destroy()
					end
				end
			end
		end
	end
	local created = {}
	for id in pairs(want) do
		if not have[id] then
			local tool = ToolLook.make(id)
			tool.Parent = backpack
			have[id], created[id] = tool, true
		end
	end
	-- 들고 있던 도구가 더 좋은 등급으로 바뀌면 새 도구를 바로 든다. 처음 스폰했을 때는 첫 칸(창)을 든다.
	if human and human.Health > 0 and character.Parent and not character:FindFirstChildOfClass("Tool") then
		local pick
		if lostFamily and lostFamily ~= "" then
			local id = Inv.best(items, lostFamily, I)
			pick = id and have[id]
		elseif self.AutoEquip[player] then
			local first = Inv.hotbar(items, bag, I)[1]
			pick = first and have[first]
		end
		if pick then
			self.AutoEquip[player] = nil
			human:EquipTool(pick)
		end
	end
	return created
end

-- 자동 요리: 모닥불 근처의 모든 대원. 버섯 1개 → 구운 버섯 1개 (0.5초마다 하나씩, 구워질 때마다 불꽃·"+1")
function S:AutoCook()
	local fire = self.ctx.Map.Campfire
	if not fire then return end
	local spec = I.Items.RoastMushroom
	for player, items in pairs(self.Items) do
		local bag = self.ctx.Resources.Bags[player]
		if bag and (bag.Mushroom or 0) > 0 and (items.RoastMushroom or 0) < I.Limit and player.Parent
			and U.near(player, fire.Position, G.CookRadius) then
			bag.Mushroom = bag.Mushroom - 1
			items.RoastMushroom = (items.RoastMushroom or 0) + 1
			self.ctx.FX:FireAllClients("Cook", fire.Position, player, "RoastMushroom", items.RoastMushroom)
			if items.RoastMushroom == 1 then
				self.ctx.Notify(player, L.M("cook.first", {icon = spec.Icon}))
			end
			self:Sync(player)
		end
	end
end

function S:Tick()
	local phase = self.ctx.Clock and self.ctx.Clock.Phase
	if os.clock() >= self.NextCook and (phase == "Day" or phase == "Night") then
		self.NextCook = os.clock() + G.CookInterval
		self:AutoCook()
	end
	if os.clock() < self.NextSync then return end
	self.NextSync = os.clock() + 0.5
	for player in pairs(self.Items) do
		if player.Parent then self:Sync(player) end
	end
end

function S:OnSpawn(player)
	self.AutoEquip[player] = true
	self:Sync(player)
end

-- 제작 장소 조건. 반환: 되면 true, 안 되면 false 와 이유
function S:Station(player, recipe)
	if recipe.Station == "Hand" then return true end
	local root = U.aliveRoot(player)
	local level = root and self.ctx.Defenses:BenchNear(root.Position, G.InteractionRange + 6) or 0
	if level == 0 then return false, L.M("craft.needBenchFirst") end
	if level < recipe.Bench then return false, L.M("craft.needBenchLv", {lv = recipe.Bench}) end
	return true
end

function S:Craft(player, id)
	if G.ActiveStage < 6 or type(id) ~= "string" or not self.ctx.Data:Ready(player) then return end
	if id == "BenchUpgrade" then return self:UpgradeBench(player) end
	if string.sub(id, 1, 5) == "Perk:" then return self:BuyPerk(player, string.sub(id, 6)) end
	local recipe = C.Recipes[id]
	local spec = I.Items[id]
	if not recipe or not spec then return end
	if not self.ctx.Run:IsParticipant(player) then return end
	local phase = self.ctx.Clock.Phase
	if phase ~= "Day" and phase ~= "Night" then return end
	if os.clock() - (self.Last[player] or -100) < 0.4 then return end
	self.Last[player] = os.clock()
	local here, why = self:Station(player, recipe)
	if not here then
		self.ctx.Notify(player, why)
		return
	end
	local items = self.Items[player]
	if not items then return end
	if spec.Kind == "Tool" or spec.Kind == "Bag" then
		if (items[id] or 0) > 0 then self.ctx.Notify(player, L.M("craft.haveIt", {name = L.M("item." .. id)})); return end
	elseif (items[id] or 0) >= I.Limit then
		self.ctx.Notify(player, L.M("craft.full", {name = L.M("item." .. id)}))
		return
	end
	if self.ctx.Resources:SpendFor(player, recipe.Cost) then
		items[id] = (items[id] or 0) + 1
		self.ctx.Notify(player, L.M(recipe.Station == "Campfire" and "craft.cooked" or (spec.Kind == "Build" and "craft.madeKit" or "craft.made"),
			{icon = spec.Icon, name = L.M("item." .. id)}))
		local root = U.aliveRoot(player)
		if root then self.ctx.FX:FireAllClients("Craft", root.Position, id) end
		self:Sync(player)
	else
		self.ctx.Notify(player, L.M("craft.noMats"))
	end
end

-- 제작 창의 "제작대 강화" 버튼: 가장 가까운 내 제작대를 강화 (DefenseService 와 같은 규칙)
function S:UpgradeBench(player)
	local root = U.aliveRoot(player)
	if not root then return end
	local best, distance = nil, G.InteractionRange + 6
	for _, slot in pairs(self.ctx.Defenses.Slots) do
		if slot.Kind == "Workbench" then
			local d = U.flat(slot.Pad.Position - root.Position).Magnitude
			if d < distance then best, distance = slot, d end
		end
	end
	if not best then self.ctx.Notify(player, L.M("craft.nearBench")); return end
	self.ctx.Defenses:Interact(player, best, "Build")
end

return S
