-- 공격 버튼 하나로 "손에 든 것" 을 쓴다. 클라이언트는 의도만 보내고, 대상·피해·결과는 서버가 정한다.
--  도구(창·도끼·곡괭이·횃불)·맨손 : 가까운 괴물 → 야생 펫(낮) → 자원 노드 순으로 친다. 도구마다 피해·채집 배율이 다르다.
--  음식 : 먹는다 (배고픔·체력)   덫 : 가까운 지친 야생 펫에게 던진다   간식 : 가까운 다친 내 펫을 회복
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local C = require(RS.Shared.Config.GameConfig)
local I = require(RS.Shared.Config.ItemConfig)
local Inv = require(RS.Shared.Modules.Inventory)
local S = {}
function S:Init(ctx)
	self.ctx, self.LastAttack = ctx, {}
	ctx.Attack.OnServerEvent:Connect(function(player) self:Attack(player) end)
end
-- 캐릭터가 생길 때: 스폰 위치로 옮기고, 도구를 맞춰 넣고, 죽으면 자원 일부를 떨어뜨린다
function S:Equip(player, character)
	local human = character:WaitForChild("Humanoid", 10)
	if not human then return end
	-- CharacterAdded 는 캐릭터가 작업 공간에 들어가기 전에 올 수 있다. 들어간 뒤에 도구를 쥐여 준다.
	local waited = 0
	while not character:IsDescendantOf(workspace) and waited < 10 do
		waited = waited + task.wait(0.1)
	end
	if not character:IsDescendantOf(workspace) or player.Character ~= character then return end
	character:PivotTo(self.ctx.Map.Spawn.CFrame + Vector3.new(0, 4, 0))
	if self.ctx.Survival then self.ctx.Survival:OnSpawn(player) end
	self.ctx.Crafting:OnSpawn(player)
	-- 같은 캐릭터로 원정에 다시 들어와도(로비 → 원정) 한 번만 연결한다
	if not character:GetAttribute("DeathHooked") then
		character:SetAttribute("DeathHooked", true)
		human.Died:Connect(function()
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and self.ctx.Run:IsParticipant(player) then self.ctx.Resources:OnDeath(player, root.Position) end
		end)
	end
end
function S:Held(player)
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if not tool then return nil, nil, nil end
	local id = tool:GetAttribute("ItemId")
	return id, id and I.Items[id], tool
end
function S:Attack(player)
	if C.ActiveStage < 2 or not self.ctx.Run:IsParticipant(player) then return end
	local phase = self.ctx.Clock.Phase
	if phase ~= "Day" and phase ~= "Night" then return end
	local root = U.aliveRoot(player)
	if not root or (self.ctx.Data and not self.ctx.Data:Ready(player)) then return end
	local id, spec, tool = self:Held(player)
	if tool and not spec then return end
	local now = os.clock()
	if now - (self.LastAttack[player] or -math.huge) < C.SpearCooldown then return end
	self.LastAttack[player] = now
	-- 팔 동작: 모든 클라이언트가 이 캐릭터의 팔을 휘두르게 한다 (내 화면은 누르는 즉시 먼저 재생)
	self.ctx.FX:FireAllClients("Swing", player, Inv.motion(spec))
	if spec and spec.Kind == "Food" then
		if self.ctx.Survival then self.ctx.Survival:Eat(player, id) end
		return
	elseif spec and spec.Kind == "Trap" then
		if C.ActiveStage >= 6 then self.ctx.Capture:Throw(player, id) end
		return
	elseif spec and spec.Kind == "PetFood" then
		if C.ActiveStage >= 5 then self.ctx.Pets:FeedNearest(player) end
		return
	end
	local damage = spec and spec.Damage or I.HandDamage
	local enemy = self.ctx.Enemies:Nearest(root.Position, C.SpearRange, true)
	if enemy then
		local killed = self.ctx.Enemies:Damage(enemy, damage)
		self.ctx.FX:FireAllClients("Spear", root.Position, enemy.Part.Position, {D = damage, O = player.UserId, K = killed})
		return
	end
	if C.ActiveStage >= 6 and phase == "Day" then
		local wild = self.ctx.Capture:Nearest(root.Position, C.SpearRange)
		if wild and self.ctx.Enemies:ClearShot(root.Position, wild.Part.Position) and self.ctx.Capture:Damage(wild, damage, player) then
			self.ctx.FX:FireAllClients("Spear", root.Position, wild.Part.Position, {D = damage, O = player.UserId})
			return
		end
	end
	local best, distance = nil, C.SpearRange
	for _, node in ipairs(self.ctx.Map.Nodes) do
		local d = (node.Part.Position - root.Position).Magnitude
		if node.HP > 0 and d < distance and self.ctx.Enemies:ClearShot(root.Position, node.Part.Position) then best, distance = node, d end
	end
	if best and self.ctx.Resources:Harvest(player, best, spec) then
		self.ctx.FX:FireAllClients("Harvest", root.Position, best.Part.Position, best.Kind)
	end
end
return S
