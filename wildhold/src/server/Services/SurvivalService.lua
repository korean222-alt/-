-- 배고픔 (가볍게). 낮·밤 동안 천천히 줄고, 음식을 들고 공격 버튼을 누르면 먹는다.
-- 0이 되면 체력이 조금씩 닳지만 StarveFloor 아래로는 떨어지지 않는다 (굶어서 죽지는 않는다).
local RS = game:GetService("ReplicatedStorage")
local U = require(RS.Shared.Modules.Utility)
local G = require(RS.Shared.Config.GameConfig)
local I = require(RS.Shared.Config.ItemConfig)
local S = {}

function S:Init(ctx)
	self.ctx, self.Hunger, self.NextStarve, self.LastEat = ctx, {}, {}, {}
end
function S:AddPlayer(player)
	self.Hunger[player] = G.HungerMax
end
function S:RemovePlayer(player)
	self.Hunger[player], self.NextStarve[player], self.LastEat[player] = nil, nil, nil
end
function S:Reset()
	for player in pairs(self.Hunger) do self.Hunger[player] = G.HungerMax end
end
function S:OnSpawn(player)
	if self.Hunger[player] then self.Hunger[player] = math.max(self.Hunger[player], G.RespawnHunger) end
end
function S:Get(player)
	return self.Hunger[player] or G.HungerMax
end

function S:Tick(dt)
	local phase = self.ctx.Clock.Phase
	if phase ~= "Day" and phase ~= "Night" then return end
	local now = os.clock()
	local loss = G.HungerDecay * dt * self.ctx.Clock:Scale()
	for player, hunger in pairs(self.Hunger) do
		local _, human = U.aliveRoot(player)
		if human then
			hunger = math.max(0, hunger - loss)
			self.Hunger[player] = hunger
			if hunger <= 0 and now >= (self.NextStarve[player] or 0) then
				self.NextStarve[player] = now + G.StarveInterval
				local room = human.Health - G.StarveFloor
				if room > 0 then human:TakeDamage(math.min(G.StarveDamage, room)) end
			end
		end
	end
end

-- 음식 먹기. 성공하면 true
function S:Eat(player, id)
	local spec = I.Items[id]
	if not spec or spec.Kind ~= "Food" or not self.Hunger[player] then return false end
	local _, human = U.aliveRoot(player)
	if not human then return false end
	local now = os.clock()
	if now - (self.LastEat[player] or -100) < G.EatCooldown then return false end
	if self.Hunger[player] >= G.HungerMax - 1 and human.Health >= human.MaxHealth then
		self.ctx.Notify(player, "배가 부릅니다.")
		return false
	end
	local ok
	if spec.FromBag then
		local bag = self.ctx.Resources.Bags[player]
		ok = bag and (bag[id] or 0) > 0
		if ok then bag[id] = bag[id] - 1 end
	else
		ok = self.ctx.Crafting:Use(player, id)
	end
	if not ok then return false end
	self.LastEat[player] = now
	self.Hunger[player] = math.min(G.HungerMax, self.Hunger[player] + spec.Hunger)
	if spec.Heal and spec.Heal > 0 then human.Health = math.min(human.MaxHealth, human.Health + spec.Heal) end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then self.ctx.FX:FireAllClients("Eat", root.Position, id) end
	return true
end

return S
