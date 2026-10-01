-- 채집 손맛 (v2). 서버 FX 를 받아 화면에서만 그린다:
--  · Harvest : 맞은 나무·바위가 맞은 쪽으로 흔들린다(PivotTo, 끝나면 원래 자리로). 다 캐면 나무는 복제본이 반대쪽으로 쓰러지고
--              땅에 쿵 → 흙먼지 + 작은 화면 흔들림. 바위·덤불은 살짝 튀었다가 땅속으로 꺼진다. 황금 노드는 "✨ x3!"
--  · Pickup  : 떨어진 자원이 캐릭터로 빨려 들어오고 머리 위에 "+8 🪵"
--  · Cook    : 모닥불에서 구운 버섯이 될 때마다 불꽃 + "🍄 +1"
--  · Goal    : 튜토리얼 단계를 마칠 때 "🎯 목표 달성!" + 받은 보상
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Res = require(RS.Shared.Config.ResourceConfig)
local Items = require(RS.Shared.Config.ItemConfig)
local L = require(RS.Shared.Modules.Locale)
local Feel = require(script.Parent.BattleFeelController)
local FX = require(script.Parent.FXController)
local Audio = require(script.Parent.AudioController)

local G = {}
local player = Players.LocalPlayer
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function color(kind)
	local c = Res.Types[kind] and Res.Types[kind].Color
	return c and Color3.fromRGB(c[1], c[2], c[3]):Lerp(Color3.new(1, 1, 1), 0.35) or Color3.new(1, 1, 1)
end

local function myRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

function G:Init(remotes)
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "GatherFX"
	self.Folder.Parent = workspace
	self.Shaking, self.Falling = {}, {}
	remotes.FX.OnClientEvent:Connect(function(kind, a, b, c, d)
		if kind == "Harvest" then self:OnHarvest(a, b, c, d)
		elseif kind == "Pickup" then self:OnPickup(a, b, c, d)
		elseif kind == "Cook" then self:OnCook(a, b, c, d)
		elseif kind == "Goal" then self:OnGoal(a, b)
		end
	end)
	RunService.RenderStepped:Connect(function() self:Step() end)
	return self
end

-- ===================================================================== 흔들림
-- 바닥 점을 축으로 맞은 방향(dir)으로 기울었다가 출렁이며 돌아온다
local function groundOf(model)
	local pivot = model:GetPivot()
	local primary = model.PrimaryPart
	local half = primary and primary.Size.Y / 2 or 0
	return pivot, CFrame.new(pivot.Position - Vector3.new(0, half, 0))
end

function G:Shake(model, dir, strength)
	local entry = self.Shaking[model]
	if not entry then
		local pivot, ground = groundOf(model)
		entry = {Base = pivot, Ground = ground}
		self.Shaking[model] = entry
	end
	entry.Start, entry.Dir, entry.Strength = os.clock(), dir, strength
end

function G:StopShake(model)
	local entry = self.Shaking[model]
	if entry then
		model:PivotTo(entry.Base)
		self.Shaking[model] = nil
	end
end

function G:Step()
	local now = os.clock()
	for model, entry in pairs(self.Shaking) do
		local t = now - entry.Start
		if t > 0.7 or not model.Parent then
			if model.Parent then model:PivotTo(entry.Base) end
			self.Shaking[model] = nil
		else
			local angle = math.rad(entry.Strength) * math.exp(-t * 7) * math.sin(t * 34 + 0.6)
			local axis = Vector3.yAxis:Cross(entry.Dir)
			if axis.Magnitude > 1e-3 then
				local g = entry.Ground
				model:PivotTo(g * CFrame.fromAxisAngle(g:VectorToObjectSpace(axis.Unit), angle) * g:ToObjectSpace(entry.Base))
			end
		end
	end
	for i = #self.Falling, 1, -1 do
		local f = self.Falling[i]
		local t = now - f.Start
		if f.Kind == "Tree" then
			-- 천천히 기울다가 점점 빨라져 쿵 (0~T) → 살짝 튀었다 (T~T+0.25) → 땅속으로 가라앉으며 사라짐
			local T = f.Duration
			local angle
			if t < T then
				angle = math.rad(88) * (t / T) ^ 2.2
			elseif t < T + 0.25 then
				local k = (t - T) / 0.25
				angle = math.rad(88) - math.rad(6) * math.sin(k * math.pi)
				if not f.Landed then
					f.Landed = true
					self:Land(f)
				end
			else
				angle = math.rad(88)
			end
			local sink = math.max(0, t - T - 0.9) * 3
			local g = f.Ground
			f.Model:PivotTo(CFrame.new(0, -sink, 0) * g * CFrame.fromAxisAngle(g:VectorToObjectSpace(f.Axis), angle) * g:ToObjectSpace(f.Base))
			if t > T + 2.2 then
				f.Model:Destroy()
				table.remove(self.Falling, i)
			end
		else
			-- 바위·덤불: 살짝 튀었다가 땅속으로
			local hop = t < 0.18 and math.sin(t / 0.18 * math.pi) * 0.8 or -(t - 0.18) * 8
			f.Model:PivotTo(f.Base + Vector3.new(0, hop, 0))
			if t > 0.6 then
				f.Model:Destroy()
				table.remove(self.Falling, i)
			end
		end
	end
end

-- 쓰러진 나무가 땅에 닿을 때
function G:Land(f)
	local tip = f.Ground.Position + f.Dir * f.Height * 0.55
	FX:Burst(tip + Vector3.new(0, 0.5, 0), 26, {Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#b9a684")), Size = NumberSequence.new(1.2, 3.2),
		Speed = NumberRange.new(3, 9), Lifetime = NumberRange.new(0.6, 1.2), LightEmission = 0, Transparency = NumberSequence.new(0.35, 1),
		Acceleration = Vector3.new(0, 1, 0), Spread = Vector2.new(180, 30)})
	FX:Burst(tip + Vector3.new(0, 1, 0), 14, {Color = ColorSequence.new(Color3.fromHex("#5e7f45"), Color3.fromHex("#8a5d36")), Size = NumberSequence.new(0.5, 0.2),
		Speed = NumberRange.new(8, 16), Acceleration = Vector3.new(0, -30, 0), LightEmission = 0})
	local root = myRoot()
	local near = root and (root.Position - tip).Magnitude < 45
	if f.Mine or near then Feel.Shake = math.max(Feel.Shake or 0, f.Mine and 0.55 or 0.3) end
	Audio:Play("Thud", tip, 0.08)
end

-- 맞은 노드를 복제해서 쓰러뜨린다 (서버는 원래 모델을 바로 치운다)
function G:Fell(model, kind, dir, mine)
	self:StopShake(model)
	if not model.Parent then return end
	local clone = model:Clone()
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide, d.CanQuery, d.CanTouch, d.Anchored = false, false, false, true
		elseif d:IsA("Highlight") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	clone.Parent = self.Folder
	local pivot, ground = groundOf(model)
	local _, size = clone:GetBoundingBox()
	local entry = {Model = clone, Base = pivot, Ground = ground, Start = os.clock(), Dir = dir, Mine = mine, Height = size.Y}
	if kind == "Wood" then
		entry.Kind = "Tree"
		entry.Axis = Vector3.yAxis:Cross(dir).Unit
		entry.Duration = math.clamp(0.55 + size.Y / 40, 0.7, 1.25)
	else
		entry.Kind = "Pop"
	end
	table.insert(self.Falling, entry)
end

function G:OnHarvest(from, to, kind, info)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or type(info) ~= "table" then return end
	local mine = info.O == player.UserId
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local model = info.Model
	if typeof(model) == "Instance" and model.Parent then
		if info.Done then
			self:Fell(model, kind, dir, mine)
		else
			-- 많이 깎일수록 크게 흔들린다
			local strength = (kind == "Wood" and 4.5 or 2) * (1.6 - (info.HP or 1) * 0.6)
			self:Shake(model, dir, strength)
		end
	end
	if mine then
		Feel.Shake = math.max(Feel.Shake or 0, info.Done and 0.25 or 0.12)
		if info.Gold then
			Feel:Popup(to + Vector3.new(0, 2, 0), info.Done and L.t("gather.goldDone") or "✨", Color3.fromHex("#ffd54a"), info.Done and 38 or 26, 4, 1.2)
			if info.Done then Feel:BigText(L.t("gather.goldDone"), Color3.fromHex("#ffd54a"), 1.1) end
		end
	end
end

-- ===================================================================== 줍기
function G:OnPickup(from, who, kind, amount)
	if typeof(from) ~= "Vector3" or typeof(who) ~= "Instance" then return end
	local char = who.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	-- 작은 빛 구슬이 캐릭터로 날아간다
	local orb = Instance.new("Part")
	orb.Shape, orb.Size, orb.Material, orb.Color = Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), Enum.Material.Neon, color(kind)
	orb.Anchored, orb.CanCollide, orb.CanQuery, orb.CanTouch, orb.CastShadow = true, false, false, false, false
	orb.CFrame = CFrame.new(from)
	orb.Parent = self.Folder
	FX:Fly({{orb, CFrame.new()}}, from, root.Position + Vector3.new(0, 1, 0), 60, 2)
	if who == player then
		Feel:Popup(root.Position + Vector3.new(0, 1.5, 0), "+" .. tostring(amount) .. " " .. (Res.Icons[kind] or ""), color(kind), 26, 3.4, 0.9)
		Audio:Play("Pickup", nil, 0.06, 1 + math.min(0.4, (amount or 1) / 40))
	end
end

-- ===================================================================== 자동 요리
function G:OnCook(firePos, who, id)
	if typeof(firePos) ~= "Vector3" then return end
	FX:Burst(firePos + Vector3.new(0, 1.5, 0), 12, {Color = ColorSequence.new(Color3.fromHex("#ffd27a"), Color3.fromHex("#ff7a2a")), Size = NumberSequence.new(0.5, 0),
		Speed = NumberRange.new(3, 7), Acceleration = Vector3.new(0, 10, 0), LightEmission = 1})
	if who == player then
		local root = myRoot()
		local spec = Items.Items[id]
		if root then Feel:Popup(root.Position + Vector3.new(0, 2, 0), (spec and spec.Icon or "🍄") .. " +1", Color3.fromHex("#ffcf8a"), 26, 3.2, 0.9) end
		Audio:Play("Cook", nil, 0.08)
	end
end

-- ===================================================================== 목표 달성
function G:OnGoal(step, got)
	Feel:BigText(L.t("tut.done", {n = step}), Color3.fromHex("#ffe066"), 1.4)
	Audio:Play("Goal", nil, 0.05)
	local root = myRoot()
	if not root or type(got) ~= "table" then return end
	for i, entry in ipairs(got) do
		local id, n, isRes = entry[1], entry[2], entry[3]
		local icon = isRes and (Res.Icons[id] or "") or (Items.Items[id] and Items.Items[id].Icon or "")
		task.delay(0.25 + i * 0.18, function()
			local r = myRoot()
			if r then Feel:Popup(r.Position + Vector3.new(0, 2.5, 0), "+" .. tostring(n) .. " " .. icon, Color3.fromHex("#ffe9a8"), 28, 4, 1.2) end
		end)
	end
	local pillar = Instance.new("Part")
	pillar.Shape, pillar.Size, pillar.Material, pillar.Color = Enum.PartType.Cylinder, Vector3.new(24, 4, 4), Enum.Material.Neon, Color3.fromHex("#ffe066")
	pillar.Anchored, pillar.CanCollide, pillar.CanQuery, pillar.CanTouch, pillar.CastShadow = true, false, false, false, false
	pillar.Transparency = 0.4
	pillar.CFrame = CFrame.new(root.Position + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Parent = self.Folder
	TweenService:Create(pillar, TweenInfo.new(0.9), {Transparency = 1, Size = Vector3.new(30, 0.4, 0.4)}):Play()
	Debris:AddItem(pillar, 1)
end

return G
