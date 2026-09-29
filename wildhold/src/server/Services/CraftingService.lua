-- 판 단위 소지품(도구·덫·먹이·음식·가방)과 제작.
--  제작대(팀 공용, Lv1~3)에서 재료로 도구·덫·가방을, 모닥불에서 음식을 만든다. 재료는 공용 창고에서 쓴다.
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
local S = {}

function S:Init(ctx)
	self.ctx, self.Items, self.Last, self.AutoEquip, self.NextSync = ctx, {}, {}, {}, 0
	self.BenchLevel = 1
end
function S:AddPlayer(player)
	self.Items[player] = R.copy(I.Starter)
	self.AutoEquip[player] = true
end
function S:RemovePlayer(player)
	self.Items[player], self.Last[player], self.AutoEquip[player] = nil, nil, nil
end
function S:Reset()
	self.BenchLevel = 1
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

function S:Tick()
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

-- 제작 가능 여부와 이유 (UI 도 같은 규칙을 보여준다)
function S:Station(player, recipe)
	local map = self.ctx.Map
	local spot = recipe.Station == "Campfire" and map.Campfire or map.Workbench
	return U.near(player, spot.Position, G.InteractionRange + 2)
end

function S:Craft(player, id)
	if G.ActiveStage < 6 or type(id) ~= "string" or not self.ctx.Data:Ready(player) then return end
	if id == "BenchUpgrade" then return self:UpgradeBench(player) end
	local recipe = C.Recipes[id]
	local spec = I.Items[id]
	if not recipe or not spec then return end
	if not self.ctx.Run:IsParticipant(player) then return end
	local phase = self.ctx.Clock.Phase
	if phase ~= "Day" and phase ~= "Night" then return end
	if os.clock() - (self.Last[player] or -100) < 0.4 then return end
	self.Last[player] = os.clock()
	if not self:Station(player, recipe) then
		self.ctx.Notify(player, recipe.Station == "Campfire" and "기지 모닥불 근처에서 요리할 수 있습니다." or "기지 제작대 근처에서 제작할 수 있습니다.")
		return
	end
	if recipe.Bench > self.BenchLevel then
		self.ctx.Notify(player, "제작대 Lv" .. recipe.Bench .. "가 필요합니다. 제작대를 업그레이드하세요.")
		return
	end
	local items = self.Items[player]
	if not items then return end
	if spec.Kind == "Tool" or spec.Kind == "Bag" then
		if (items[id] or 0) > 0 then self.ctx.Notify(player, "이미 가지고 있습니다: " .. spec.Name); return end
	elseif (items[id] or 0) >= I.Limit then
		self.ctx.Notify(player, "더 들 수 없습니다: " .. spec.Name)
		return
	end
	if self.ctx.Resources:Spend(recipe.Cost) then
		items[id] = (items[id] or 0) + 1
		self.ctx.Notify(player, spec.Icon .. " " .. spec.Name .. (recipe.Station == "Campfire" and " 요리 완료" or " 제작 완료"))
		local station = recipe.Station == "Campfire" and self.ctx.Map.Campfire or self.ctx.Map.Workbench
		self.ctx.FX:FireAllClients("Craft", station.Position, id)
		self:Sync(player)
	else
		self.ctx.Notify(player, "공용 창고의 재료가 부족합니다.")
	end
end

function S:UpgradeBench(player)
	if not self.ctx.Run:IsParticipant(player) or self.ctx.Clock.Phase ~= "Day" then
		self.ctx.Notify(player, "제작대 업그레이드는 낮에만 할 수 있습니다.")
		return
	end
	if os.clock() - (self.Last[player] or -100) < 0.4 then return end
	self.Last[player] = os.clock()
	local nextLevel = C.Bench[self.BenchLevel + 1]
	if not nextLevel then return end
	if not U.near(player, self.ctx.Map.Workbench.Position, G.InteractionRange + 2) then
		self.ctx.Notify(player, "기지 제작대 근처에서 업그레이드할 수 있습니다.")
		return
	end
	if not self.ctx.Resources:Spend(nextLevel.Cost) then
		self.ctx.Notify(player, "공용 창고의 재료가 부족합니다.")
		return
	end
	self.BenchLevel = self.BenchLevel + 1
	self.ctx.Map.Workbench:SetAttribute("Level", self.BenchLevel)
	self.ctx.FX:FireAllClients("Build", self.ctx.Map.Workbench.Position, "Workbench", self.BenchLevel)
	self.ctx.Notify(nil, "🔨 " .. nextLevel.Name .. " 달성! 새 제작법과 방어 시설 강화가 풀렸습니다")
	if self.ctx.Defenses then self.ctx.Defenses:RefreshAll() end
end

return S
