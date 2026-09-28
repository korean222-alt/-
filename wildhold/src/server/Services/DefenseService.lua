local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local Rules = require(RS.Shared.Modules.Rules)
local C = require(RS.Shared.Config.GameConfig)
local D = require(RS.Shared.Config.DefenseConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local Structures = require(RS.Shared.Visuals.Structures)
local S = {}

function S:Init(ctx)
	self.ctx, self.Slots, self.LastAction = ctx, {}, {}
	for _, slot in ipairs(ctx.Map.Slots) do
		if D[slot.Kind] then
			self.Slots[slot.Id] = slot
			slot.BuildPrompt = U.prompt(slot.Pad, "Build", "건설", Enum.KeyCode.E, Vector3.new(0, 2.5, 0))
			slot.RepairPrompt = U.prompt(slot.Pad, "Repair", "수리", Enum.KeyCode.R, Vector3.new(0, 4.5, 0))
			slot.BuildPrompt.Triggered:Connect(function(player) self:Interact(player, slot, "Build") end)
			slot.RepairPrompt.Triggered:Connect(function(player) self:Interact(player, slot, "Repair") end)
		end
	end
	self:Reset()
end

function S:CostText(cost)
	local parts = {}
	for _, kind in ipairs(R.Order) do
		if cost[kind] then table.insert(parts, R.Labels[kind] .. " " .. cost[kind]) end
	end
	return table.concat(parts, " · ")
end

function S:Reset()
	self.ctx.Map.DefensesFolder:ClearAllChildren()
	self.LastAction = {}
	for _, slot in pairs(self.Slots) do
		slot.Visual, slot.NextAttack, slot.LastMutation = nil, 0, -math.huge
		slot.Level = C.ActiveStage >= 3 and slot.InitialLevel or 0
		slot.HP = slot.Level > 0 and D[slot.Kind].Levels[slot.Level].HP or 0
		self:Render(slot)
	end
end

-- 레벨에 맞는 모델을 새로 짓는다. 충돌/사선 판정은 모델 안의 Hitbox 한 개로 한다.
function S:Render(slot)
	if slot.Visual then slot.Visual:Destroy(); slot.Visual, slot.Hitbox = nil, nil end
	if slot.Level > 0 then
		local model, muzzle = Structures.defense(self.ctx.Map.DefensesFolder, slot.Kind, slot.Level, slot.CFrame, slot.Width)
		model.Name = slot.Id
		model:SetAttribute("SlotId", slot.Id)
		slot.Visual, slot.Hitbox = model, model:FindFirstChild("Hitbox")
		slot.Hitbox.Name = slot.Id
		slot.Muzzle = slot.CFrame.Position + Vector3.new(0, muzzle, 0)
	end
	if slot.Blueprint then
		slot.Blueprint.Parent = slot.Level == 0 and slot.Pad.Parent or nil
	end
	self:Refresh(slot)
end

function S:Refresh(slot)
	local spec = D[slot.Kind]
	local stats = spec.Levels[slot.Level]
	local nextStats = spec.Levels[slot.Level + 1]
	local phase = self.ctx.Clock.Phase
	-- 클라이언트는 이 속성으로 체력 막대/이름표를 그린다
	slot.Pad:SetAttribute("Level", slot.Level)
	slot.Pad:SetAttribute("CurrentHealth", slot.HP)
	slot.Pad:SetAttribute("MaxHealth", stats and stats.HP or 0)
	slot.Pad:SetAttribute("DisplayName", spec.Name)
	if slot.Visual then
		slot.Visual:SetAttribute("CurrentHealth", slot.HP)
		slot.Visual:SetAttribute("MaxHealth", stats and stats.HP or 0)
	end
	slot.BuildPrompt.Enabled = C.ActiveStage >= 3 and phase == "Day" and nextStats ~= nil
	slot.BuildPrompt.ActionText = (slot.Level == 0 and "건설 · " or "강화 · ") .. (nextStats and self:CostText(nextStats.Cost) or "최대")
	slot.BuildPrompt.ObjectText = spec.Name .. (slot.Level > 0 and (" Lv" .. slot.Level) or " (빈 자리)")
	slot.RepairPrompt.Enabled = C.ActiveStage >= 3 and (phase == "Day" or phase == "Night") and stats ~= nil and slot.HP < stats.HP
	local mult = phase == "Night" and C.NightRepairMultiplier or 1
	slot.RepairPrompt.ActionText = "수리 · " .. (stats and self:CostText(Rules.repairCost(stats.Repair, mult)) or "")
	slot.RepairPrompt.ObjectText = spec.Name .. (stats and string.format(" %d/%d", slot.HP, stats.HP) or "")
end

function S:RefreshAll() for _, slot in pairs(self.Slots) do self:Refresh(slot) end end

function S:Interact(player, slot, action)
	if C.ActiveStage < 3 or not self.ctx.Run:IsParticipant(player) then return end
	if not U.near(player, slot.Pad.Position, C.InteractionRange) then return end
	local now = os.clock()
	if now - (self.LastAction[player] or -math.huge) < C.InteractionCooldown then return end
	self.LastAction[player] = now
	if now - (slot.LastMutation or -math.huge) < C.InteractionCooldown then return end
	local phase, spec = self.ctx.Clock.Phase, D[slot.Kind]
	if action == "Build" then
		if phase ~= "Day" then return end
		local nextStats = spec.Levels[slot.Level + 1]
		if not nextStats then return end
		if not self.ctx.Resources:Spend(nextStats.Cost) then self.ctx.Notify(player, "공용 창고의 자원이 부족합니다 · " .. self:CostText(nextStats.Cost)); return end
		-- No yielding in validation, spend, mutation: simultaneous requests serialize.
		local oldHP = slot.Level > 0 and spec.Levels[slot.Level].HP or 0
		slot.HP = Rules.upgradeHP(slot.HP, oldHP, nextStats.HP)
		slot.Level = slot.Level + 1
		slot.LastMutation = now
		self:Render(slot)
		self.ctx.FX:FireAllClients("Build", slot.CFrame.Position, slot.Kind, slot.Level)
		self.ctx.Notify(player, spec.Name .. " Lv" .. slot.Level .. " 완성!")
	elseif action == "Repair" then
		if phase ~= "Day" and phase ~= "Night" then return end
		local stats = spec.Levels[slot.Level]
		if not stats or slot.HP >= stats.HP then return end
		local cost = Rules.repairCost(stats.Repair, phase == "Night" and C.NightRepairMultiplier or 1)
		if not self.ctx.Resources:Spend(cost) then self.ctx.Notify(player, "수리 자원이 부족합니다"); return end
		slot.HP = math.min(stats.HP, slot.HP + math.ceil(stats.HP * C.RepairFraction))
		slot.LastMutation = now
		self.ctx.FX:FireAllClients("Repair", slot.CFrame.Position, slot.Kind, slot.Level)
		self:Refresh(slot)
	end
end

function S:Damage(slot, amount)
	if slot.Level == 0 or slot.HP <= 0 then return end
	slot.HP = math.max(0, slot.HP - amount)
	if slot.HP == 0 then
		self.ctx.FX:FireAllClients("Break", slot.CFrame.Position, slot.Kind, slot.Level)
		slot.Level = 0
		self:Render(slot)
	else
		self:Refresh(slot)
	end
end

function S:Barrier(laneId, position)
	local closest, distance = nil, math.huge
	local dir = self.ctx.Map.Lanes[laneId].Dir
	local radius = U.flat(position):Dot(dir)
	for _, slot in pairs(self.Slots) do
		if slot.LaneId == laneId and slot.Level > 0 and D[slot.Kind].Blocks then
			local r = U.flat(slot.Pad.Position):Dot(dir)
			local delta = radius - r
			if delta >= -2 and delta < distance then closest, distance = slot, delta end
		end
	end
	return closest
end

function S:Nearest(position, radius)
	local closest, distance = nil, radius
	for _, slot in pairs(self.Slots) do
		if slot.Level > 0 and slot.Kind ~= "SpikeTrap" then
			local d = U.flat(slot.Pad.Position - position).Magnitude
			if d < distance then closest, distance = slot, d end
		end
	end
	return closest
end

-- 사선을 막는 장애물: 지어진 벽·문·포탑의 Hitbox
function S:Obstacles(ignored)
	local list = {}
	for _, slot in pairs(self.Slots) do
		if slot.Hitbox and slot.Visual ~= ignored and slot.Kind ~= "SpikeTrap" then
			table.insert(list, slot.Hitbox)
		end
	end
	return list
end

function S:Tick()
	if C.ActiveStage < 3 or self.ctx.Clock.Phase ~= "Night" then return end
	local now = os.clock()
	for _, slot in pairs(self.Slots) do
		local stats = D[slot.Kind].Levels[slot.Level]
		if stats and stats.Damage and now >= slot.NextAttack then
			local origin = slot.Muzzle
			-- 화살은 포물선으로 벽 위를 넘어간다: 벽 뒤에서 벽을 때리는 적도 맞힐 수 있어야 한다
			local target = self.ctx.Enemies:Nearest(origin, stats.Range, false)
			if target then
				slot.NextAttack = now + stats.Interval
				if slot.Kind == "SpikeTrap" then
					local hit = false
					for _, enemy in pairs(self.ctx.Enemies.Units) do
						if U.flat(enemy.Part.Position - slot.Pad.Position).Magnitude <= stats.Range then
							self.ctx.Enemies:Damage(enemy, stats.Damage); hit = true
						end
					end
					if hit then self.ctx.FX:FireAllClients("Spikes", slot.Pad.Position) end
				else
					self.ctx.FX:FireAllClients("Arrow", origin, target.Part.Position)
					self.ctx.Enemies:Damage(target, stats.Damage * (C.ActiveStage >= 5 and C.TowerDamageScale or 1))
				end
			end
		end
	end
end

return S
