-- 설치형 구조물: 제작대 · 벽 · 문 · 화살 포탑 · 가시 함정 · 펫 배치대 · 횃불대.
--  플레이어가 설치 도구(Kit)를 들고 기지 영역 안에 놓는다 (Request). 놓은 것은 [E] 강화 · [R] 수리 · 옮기기(도구로 돌려받기).
--  괴물은 가는 길을 막은 벽·문을 부수고(Barrier), 브루트는 가까운 구조물을 노린다(Nearest).
--  제작대의 가장 높은 레벨 = 팀 제작대 레벨 (새 제작법, 방어 시설 Lv2·3 강화 조건).
-- 구조물마다 Map.DefenseSlots/<Id>/<Id> 에 보이지 않는 Pad 가 있다 (프롬프트 · 체력 속성 · WorldUI 체력 막대).
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local Rules = require(RS.Shared.Modules.Rules)
local Placement = require(RS.Shared.Modules.Placement)
local C = require(RS.Shared.Config.GameConfig)
local D = require(RS.Shared.Config.DefenseConfig)
local R = require(RS.Shared.Config.ResourceConfig)
local BC = require(RS.Shared.Config.BuildConfig)
local M = require(RS.Shared.Config.MapConfig)
local I = require(RS.Shared.Config.ItemConfig)
local Structures = require(RS.Shared.Visuals.Structures)
local L = require(RS.Shared.Modules.Locale)
local S = {}

local KIT_OF = {}
for kit, kind in pairs(BC.Kits) do KIT_OF[kind] = kit end

function S:Init(ctx)
	self.ctx, self.LastAction, self.Slots, self.NextId = ctx, {}, {}, 0
	self.Blocked = Placement.blocked(M)
	self:Reset()
end

-- 비용 = 번역 메시지 ("나무 10 · 돌 5")
function S:CostText(cost)
	local parts = {}
	for _, kind in ipairs(R.Order) do
		if cost[kind] then
			if #parts > 0 then table.insert(parts, " · ") end
			table.insert(parts, L.M("res." .. kind))
			table.insert(parts, " " .. cost[kind])
		end
	end
	return L.C(table.unpack(parts))
end

-- 판이 시작될 때: 모두 치우고 시작 구조물(길목 문·벽·포탑)만 둔다
function S:Reset()
	for _, slot in pairs(self.Slots) do self:Remove(slot, true) end
	self.Slots, self.LastAction = {}, {}
	self.ctx.Map.DefensesFolder:ClearAllChildren()
	self.ctx.Map.SlotsFolder:ClearAllChildren()
	if C.ActiveStage >= 3 then
		for _, spec in ipairs(BC.Starter) do
			local kind, laneId, radius, side = table.unpack(spec)
			local lane = self.ctx.Map.Lanes[laneId]
			local pos = lane.Dir * radius + lane.Side * side
			self:Place(kind, CFrame.lookAt(pos, pos + lane.Dir), 1, nil)
		end
	end
	self:UpdateBench()
end

-- ===================================================================== 놓기 / 치우기
function S:Rect(kind, frame, pad)
	return Placement.rect(frame.X, frame.Z, frame.RightVector.X, frame.RightVector.Z, BC.Footprint[kind], pad)
end

function S:Place(kind, frame, level, owner)
	self.NextId = self.NextId + 1
	local id = string.format("S%03d", self.NextId)
	local size = BC.Footprint[kind]
	frame = CFrame.new(frame.X, 0, frame.Z) * (frame - frame.Position)
	local holder = Instance.new("Model")
	holder.Name = id
	local pad = U.part(holder, id, Vector3.new(size[1], 0.4, size[2]), frame.Position + Vector3.new(0, 0.2, 0))
	pad.CFrame = frame * CFrame.new(0, 0.2, 0)
	pad.Transparency, pad.CanCollide, pad.CanTouch, pad.CanQuery = 1, false, false, true
	pad:SetAttribute("SlotId", id)
	pad:SetAttribute("SlotType", kind)
	holder.Parent = self.ctx.Map.SlotsFolder
	local slot = {Id = id, Kind = kind, Level = level, CFrame = frame, Width = size[1], Pad = pad, Holder = holder, Owner = owner,
		Rect = self:Rect(kind, frame), NextAttack = 0, LastMutation = -math.huge}
	slot.HP = D[kind].Levels[level].HP
	slot.BuildPrompt = U.prompt(pad, "Build", L.M("prompt.upgrade"), Enum.KeyCode.E, Vector3.new(0, 2.5, 0))
	slot.RepairPrompt = U.prompt(pad, "Repair", L.M("prompt.repair"), Enum.KeyCode.R, Vector3.new(0, 4.5, 0))
	slot.MovePrompt = U.prompt(pad, "Move", L.M("prompt.move"), Enum.KeyCode.G, Vector3.new(0, 6.5, 0))
	slot.MovePrompt.HoldDuration = 0.6
	slot.BuildPrompt.Triggered:Connect(function(player) self:Interact(player, slot, "Build") end)
	slot.RepairPrompt.Triggered:Connect(function(player) self:Interact(player, slot, "Repair") end)
	slot.MovePrompt.Triggered:Connect(function(player) self:Interact(player, slot, "Move") end)
	if kind == "Workbench" then
		slot.CraftPrompt = U.prompt(pad, "Craft", L.M("prompt.craft"), Enum.KeyCode.F, Vector3.new(0, 1, -2.5))
		L.tag(slot.CraftPrompt, "ObjectText", L.M("defense.Workbench"))
		slot.CraftPrompt.Triggered:Connect(function(player)
			if self.ctx.Data:Ready(player) and U.near(player, pad.Position, C.InteractionRange + 2) then self.ctx.PetFX:FireClient(player, "OpenCraft", "Workbench") end
		end)
	elseif kind == "PetStand" then
		local prompt = U.prompt(pad, "PlacePet", L.M("prompt.placePet"), Enum.KeyCode.F, Vector3.new(0, 3, 0))
		L.tag(prompt, "ObjectText", L.M("defense.PetStand"))
		prompt.Triggered:Connect(function(player) if C.ActiveStage >= 5 then self.ctx.Pets:AssignStand(player, slot) end end)
	end
	self.Slots[id] = slot
	self:Render(slot)
	return slot
end

function S:Remove(slot, silent)
	if slot.Visual then slot.Visual:Destroy() end
	if slot.Holder then slot.Holder:Destroy() end
	self.Slots[slot.Id] = nil
	if not silent then self:UpdateBench() end
end

-- 레벨에 맞는 모델을 새로 짓는다. 충돌/사선 판정은 모델 안의 Hitbox 한 개로 한다.
function S:Render(slot)
	if slot.Visual then slot.Visual:Destroy(); slot.Visual, slot.Hitbox = nil, nil end
	local model, muzzle = Structures.structure(self.ctx.Map.DefensesFolder, slot.Kind, slot.Level, slot.CFrame, slot.Width)
	model.Name = slot.Id
	model:SetAttribute("SlotId", slot.Id)
	slot.Visual, slot.Hitbox = model, model:FindFirstChild("Hitbox")
	if slot.Hitbox then slot.Hitbox.Name = slot.Id end
	slot.Muzzle = slot.CFrame.Position + Vector3.new(0, muzzle or 2, 0)
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
	slot.Pad:SetAttribute("DisplayName", "defense." .. slot.Kind) -- 번역 키
	if slot.Visual then
		slot.Visual:SetAttribute("CurrentHealth", slot.HP)
		slot.Visual:SetAttribute("MaxHealth", stats and stats.HP or 0)
	end
	slot.BuildPrompt.Enabled = C.ActiveStage >= 3 and phase == "Day" and nextStats ~= nil
	local bench = nextStats and self:BenchNeeded(slot)
	local name = L.M("defense." .. slot.Kind)
	L.tag(slot.BuildPrompt, "ActionText", L.M("prompt.upgradeCost", {cost = bench and L.M("prompt.needBench", {lv = bench})
		or (nextStats and self:CostText(nextStats.Cost) or L.M("prompt.max"))}))
	L.tag(slot.BuildPrompt, "ObjectText", L.M("fmt.nameLv", {name = name, lv = slot.Level}))
	slot.RepairPrompt.Enabled = C.ActiveStage >= 3 and (phase == "Day" or phase == "Night") and stats ~= nil and slot.HP < stats.HP
	local mult = phase == "Night" and C.NightRepairMultiplier or 1
	L.tag(slot.RepairPrompt, "ActionText", L.M("prompt.repairCost", {cost = stats and self:CostText(Rules.repairCost(stats.Repair, mult)) or ""}))
	L.tag(slot.RepairPrompt, "ObjectText", L.C(name, stats and string.format(" %d/%d", slot.HP, stats.HP) or ""))
	slot.MovePrompt.Enabled = phase == "Day" and stats ~= nil and slot.HP >= stats.HP
	L.tag(slot.MovePrompt, "ObjectText", name)
end

function S:RefreshAll() for _, slot in pairs(self.Slots) do self:Refresh(slot) end end

-- ===================================================================== 제작대 레벨
function S:BenchLevel()
	local best = 0
	for _, slot in pairs(self.Slots) do
		if slot.Kind == "Workbench" then best = math.max(best, slot.Level) end
	end
	return best
end

-- 놓인 제작대 중 이 위치에서 range 안에 있는 가장 높은 레벨 (없으면 0)
function S:BenchNear(position, range)
	local best = 0
	for _, slot in pairs(self.Slots) do
		if slot.Kind == "Workbench" and U.flat(slot.Pad.Position - position).Magnitude <= range then best = math.max(best, slot.Level) end
	end
	return best
end

function S:UpdateBench()
	if self.ctx.Crafting then self.ctx.Crafting.BenchLevel = self:BenchLevel() end
	workspace:SetAttribute("BenchLevel", self:BenchLevel())
	for _, slot in pairs(self.Slots) do self:Refresh(slot) end
end

-- 방어 시설 Lv2 는 제작대 Lv2, Lv3 은 제작대 Lv3 이 있어야 강화할 수 있다. 필요하면 그 레벨, 아니면 nil (제작대 자신은 조건 없음)
function S:BenchNeeded(slot)
	if slot.Kind == "Workbench" then return nil end
	local want = slot.Level + 1
	if want >= 2 and self:BenchLevel() < want then return want end
	return nil
end

-- ===================================================================== 플레이어 요청
-- 설치: 설치 도구를 들고 공격 버튼 → 클라이언트가 미리보기 자리(CFrame)를 보낸다. 서버가 다시 검사한다.
function S:Request(player, kit, frame)
	if C.ActiveStage < 3 or type(kit) ~= "string" or typeof(frame) ~= "CFrame" or not self.ctx.Run:IsParticipant(player) then return false end
	local kind = BC.Kits[kit]
	if not kind then return false end
	local phase = self.ctx.Clock.Phase
	if phase ~= "Day" and phase ~= "Night" then return false end
	local now = os.clock()
	if now - (self.LastAction[player] or -math.huge) < C.InteractionCooldown then return false end
	self.LastAction[player] = now
	local items = self.ctx.Crafting.Items[player]
	if not items or (items[kit] or 0) <= 0 then return false end
	local root = U.aliveRoot(player)
	if not root then return false end
	local count = 0
	for _ in pairs(self.Slots) do count = count + 1 end
	if count >= BC.Limit then self.ctx.Notify(player, L.M("build.limit", {n = BC.Limit})); return false end
	-- 수평으로만 돌린다
	local look = frame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.1 then flatLook = Vector3.new(0, 0, -1) end
	local at = CFrame.lookAt(Vector3.new(frame.X, 0, frame.Z), Vector3.new(frame.X, 0, frame.Z) + flatLook.Unit)
	local ok, reason = Placement.check(self:Rect(kind, at), self:Rects(), self.Blocked, BC, root.Position.X, root.Position.Z)
	if not ok then self.ctx.Notify(player, L.M("build.cantPlace", {why = reason})); return false end
	self.ctx.Crafting:Use(player, kit)
	local slot = self:Place(kind, at, 1, player)
	if kind == "Workbench" then self:UpdateBench() end
	self.ctx.FX:FireAllClients("Build", at.Position, kind, 1)
	self.ctx.Notify(player, L.M(kind == "Workbench" and "build.placedBench" or "build.placed", {name = L.M("defense." .. kind)}))
	self.ctx.Crafting:Sync(player)
	return true, slot
end

function S:Rects()
	local list = {}
	for _, slot in pairs(self.Slots) do table.insert(list, slot.Rect) end
	return list
end

function S:Interact(player, slot, action)
	if C.ActiveStage < 3 or not self.ctx.Run:IsParticipant(player) or self.Slots[slot.Id] ~= slot then return end
	if not U.near(player, slot.Pad.Position, C.InteractionRange + math.max(0, slot.Width / 2 - 4)) then return end
	local now = os.clock()
	if now - (self.LastAction[player] or -math.huge) < C.InteractionCooldown then return end
	self.LastAction[player] = now
	if now - (slot.LastMutation or -math.huge) < C.InteractionCooldown then return end
	local phase, spec = self.ctx.Clock.Phase, D[slot.Kind]
	if action == "Build" then
		if phase ~= "Day" then return end
		local nextStats = spec.Levels[slot.Level + 1]
		if not nextStats then return end
		local bench = self:BenchNeeded(slot)
		if bench then self.ctx.Notify(player, L.M("build.needBench", {lv = bench})); return end
		if not self.ctx.Resources:SpendFor(player, nextStats.Cost) then self.ctx.Notify(player, L.M("build.needCost", {cost = self:CostText(nextStats.Cost)})); return end
		-- No yielding in validation, spend, mutation: simultaneous requests serialize.
		local oldHP = spec.Levels[slot.Level].HP
		slot.HP = Rules.upgradeHP(slot.HP, oldHP, nextStats.HP)
		slot.Level = slot.Level + 1
		slot.LastMutation = now
		self:Render(slot)
		self.ctx.FX:FireAllClients("Build", slot.CFrame.Position, slot.Kind, slot.Level)
		if slot.Kind == "Workbench" then
			self:UpdateBench()
			self.ctx.Notify(nil, L.M("build.benchUp", {lv = slot.Level}))
		else
			self.ctx.Notify(player, L.M("build.upgraded", {name = L.M("defense." .. slot.Kind), lv = slot.Level}))
		end
	elseif action == "Repair" then
		if phase ~= "Day" and phase ~= "Night" then return end
		local stats = spec.Levels[slot.Level]
		if not stats or slot.HP >= stats.HP then return end
		local cost = Rules.repairCost(stats.Repair, phase == "Night" and C.NightRepairMultiplier or 1)
		if not self.ctx.Resources:SpendFor(player, cost) then self.ctx.Notify(player, L.M("build.needRepair")); return end
		slot.HP = math.min(stats.HP, slot.HP + math.ceil(stats.HP * C.RepairFraction))
		slot.LastMutation = now
		self.ctx.FX:FireAllClients("Repair", slot.CFrame.Position, slot.Kind, slot.Level)
		self:Refresh(slot)
	elseif action == "Move" then
		-- 다친 데 없는 구조물은 낮에 설치 도구로 돌려받는다 (강화한 레벨은 사라진다)
		local stats = spec.Levels[slot.Level]
		if phase ~= "Day" or not stats or slot.HP < stats.HP then return end
		local items = self.ctx.Crafting.Items[player]
		local kit = KIT_OF[slot.Kind]
		if not items or not kit or (items[kit] or 0) >= I.Limit then return end
		items[kit] = (items[kit] or 0) + 1
		self.ctx.FX:FireAllClients("Break", slot.CFrame.Position, slot.Kind, slot.Level)
		self:Remove(slot)
		self.ctx.Crafting:Sync(player)
		self.ctx.Notify(player, L.M("build.moved", {icon = I.Items[kit].Icon, name = L.M("defense." .. slot.Kind)}))
	end
end

function S:Damage(slot, amount)
	if self.Slots[slot.Id] ~= slot or slot.HP <= 0 then return end
	slot.HP = math.max(0, slot.HP - amount)
	if slot.HP == 0 then
		self.ctx.FX:FireAllClients("Break", slot.CFrame.Position, slot.Kind, slot.Level)
		self:Remove(slot)
		if self.ctx.Pets then
			for _, rec in pairs(self.ctx.Pets.Active) do
				if rec.Stand == slot.Id then rec.Stand, rec.Mode = nil, "Follow" end
			end
		end
	else
		self:Refresh(slot)
	end
end

-- ===================================================================== 괴물이 보는 것
-- 지금 위치에서 goal 쪽으로 look 만큼 가는 길을 막는 벽·문. 반환: 구조물, 부딪히는 점
function S:Barrier(position, goal, radius, look)
	local dir = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
	local distance = dir.Magnitude
	if distance < 0.01 then return nil end
	dir = dir / distance
	local reach = math.min(distance, look or 8)
	local best, bestT = nil, math.huge
	for _, slot in pairs(self.Slots) do
		if BC.Blocks[slot.Kind] then
			local t = 0
			while t <= reach do
				local x, z = position.X + dir.X * t, position.Z + dir.Z * t
				if Placement.contains(slot.Rect, x, z, radius) then
					if t < bestT then best, bestT = slot, t end
					break
				end
				t = t + 1
			end
		end
	end
	if not best then return nil end
	local x, z = Placement.closest(best.Rect, position.X, position.Z)
	return best, Vector3.new(x, position.Y, z)
end

function S:Nearest(position, radius)
	local closest, distance, point = nil, radius, nil
	for _, slot in pairs(self.Slots) do
		if slot.Kind ~= "SpikeTrap" and slot.Kind ~= "TorchPost" then
			local x, z = Placement.closest(slot.Rect, position.X, position.Z)
			local d = Vector3.new(x - position.X, 0, z - position.Z).Magnitude
			if d < distance then closest, distance, point = slot, d, Vector3.new(x, position.Y, z) end
		end
	end
	return closest, point
end

-- 사선을 막는 장애물: 지어진 벽·문·포탑·제작대의 Hitbox
function S:Obstacles(ignored)
	local list = {}
	for _, slot in pairs(self.Slots) do
		if slot.Hitbox and slot.Visual ~= ignored and slot.Kind ~= "SpikeTrap" and slot.Kind ~= "TorchPost" and slot.Kind ~= "PetStand" then
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
