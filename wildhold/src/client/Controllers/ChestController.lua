-- 보물상자 연출 (v2). 서버 ChestService 와 MapService/Ruins.chest 가 만든 "WildChest" 모델을 찾아 화면에서만 움직인다.
--  · 뚜껑: 모델 속성 Open (공용 상자) / OpenedBy (대원별 상자에 내 UserId 가 있으면) 에 따라 열림·닫힘
--  · 빛기둥: 아직 안 연 상자만 보인다. 천천히 숨 쉬듯 밝아졌다 어두워진다
--  · FX "Chest": 덜컹덜컹(0.6초) → 뚜껑 펑 → 등급 색 빛 폭발 + 반짝이 + (내가 열었으면) 큰 글자 "✨ 희귀 보물!"
--  · FX "Loot" : 받은 아이템 아이콘이 하나씩 떠오른다
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CC = require(RS.Shared.Config.ChestConfig)
local Items = require(RS.Shared.Config.ItemConfig)
local Ruins = require(RS.Shared.Visuals.Ruins)
local L = require(RS.Shared.Modules.Locale)
local Feel = require(script.Parent.BattleFeelController)
local FX = require(script.Parent.FXController)
local Audio = require(script.Parent.AudioController)

local C = {}
local player = Players.LocalPlayer
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

function C:Init(remotes)
	self.Chests = {}
	for _, model in ipairs(CollectionService:GetTagged("WildChest")) do task.spawn(self.Track, self, model) end
	CollectionService:GetInstanceAddedSignal("WildChest"):Connect(function(model) self:Track(model) end)
	remotes.FX.OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "Chest" then self:OnChest(a, b, c)
		elseif kind == "Loot" then self:OnLoot(a, b, c) end
	end)
	RunService.RenderStepped:Connect(function() self:Step() end)
	return self
end

function C:Track(model)
	if self.Chests[model] or not model:IsA("Model") then return end
	local lid = model:WaitForChild("Lid", 5)
	if not lid or not lid.PrimaryPart then return end
	local entry = {Model = model, Lid = lid, Closed = lid:GetPivot(), Angle = 0, Target = 0, Beam = model:FindFirstChild("Beam")}
	self.Chests[model] = entry
	self:Refresh(entry, true)
	model:GetAttributeChangedSignal("Open"):Connect(function() self:Refresh(entry) end)
	model:GetAttributeChangedSignal("OpenedBy"):Connect(function() self:Refresh(entry) end)
end

function C:IsOpen(model)
	if model:GetAttribute("Open") == true then return true end
	local by = model:GetAttribute("OpenedBy")
	return type(by) == "string" and string.find(by, "," .. tostring(player.UserId) .. ",", 1, true) ~= nil
end

function C:Refresh(entry, instant)
	local open = self:IsOpen(entry.Model)
	-- 대원별 상자를 남이 열면 잠깐 열렸다가 닫힌다 (OnChest 에서). 내가 열었으면 계속 열린 채로
	if instant then
		entry.Target = open and math.rad(Ruins.ChestOpenAngle) or 0
		entry.Angle = entry.Target
	elseif open and entry.Target == 0 then
		-- 막 열렸다: 덜컹거린 뒤에 열린다 (FX "Chest" 를 못 받았어도)
		entry.Shaking = entry.Shaking or os.clock()
	elseif not open and not entry.Shaking then
		entry.Target = 0
	end
	if entry.Beam then
		for _, p in ipairs(entry.Beam:GetChildren()) do
			if p:IsA("BasePart") then
				if p:GetAttribute("BaseT") == nil then p:SetAttribute("BaseT", p.Transparency) end
				p.Transparency = open and 1 or p:GetAttribute("BaseT")
			end
		end
	end
end

function C:Step()
	local now = os.clock()
	for model, entry in pairs(self.Chests) do
		if not model.Parent then
			self.Chests[model] = nil
		else
			local shake = CFrame.new()
			if entry.Shaking then
				local t = now - entry.Shaking
				if t < CC.OpenDelay then
					local k = t / CC.OpenDelay
					shake = CFrame.Angles(math.sin(t * 50) * 0.06 * k, 0, math.sin(t * 43) * 0.08 * k)
				else
					entry.Shaking = nil
					entry.Target = math.rad(Ruins.ChestOpenAngle)
					entry.Pop = now
					if entry.CloseAt == nil and model:GetAttribute("PerPlayer") and not self:IsOpen(model) then entry.CloseAt = now + 4 end
				end
			end
			if entry.CloseAt and now >= entry.CloseAt then
				entry.CloseAt = nil
				self:Refresh(entry)
			end
			-- 뚜껑: 열릴 때는 튕기듯 빠르게, 닫힐 때는 천천히
			local speed = entry.Target > entry.Angle and 14 or 3
			entry.Angle = entry.Angle + (entry.Target - entry.Angle) * math.min(1, speed * (1 / 60))
			local overshoot = entry.Pop and math.max(0, 1 - (now - entry.Pop) / 0.5) * math.sin((now - entry.Pop) * 25) * 0.15 or 0
			local angle = entry.Angle + overshoot
			if math.abs(angle - (entry.Shown or -1)) > 1e-3 or entry.Shaking then
				entry.Shown = angle
				entry.Lid:PivotTo(entry.Closed * shake * CFrame.Angles(angle, 0, 0))
			end
			-- 빛기둥 숨쉬기
			if entry.Beam and not self:IsOpen(model) then
				local glow = 0.5 + math.sin(now * 2 + entry.Closed.Position.X) * 0.5
				for _, p in ipairs(entry.Beam:GetChildren()) do
					local base = p:GetAttribute("BaseT")
					if base then p.Transparency = math.min(0.97, base + glow * 0.12) end
				end
			end
		end
	end
end

-- 상자가 열린다 (모든 화면)
function C:OnChest(model, who, tier)
	if typeof(model) ~= "Instance" then return end
	local entry = self.Chests[model]
	local pos = model:GetPivot().Position
	local color = Color3.fromHex(CC.Colors[tier] or "#ffffff")
	local mine = who == player
	if entry and not (entry.Shaking and os.clock() - entry.Shaking < 0.3) then entry.Shaking = os.clock() end
	Audio:Play("ChestShake", pos, 0.1)
	task.delay(CC.OpenDelay, function()
		Audio:Play("ChestOpen", pos, 0.1)
		FX:Burst(pos + Vector3.new(0, 1, 0), tier == "Epic" and 60 or 38, {Color = ColorSequence.new(Color3.new(1, 1, 1), color), Size = NumberSequence.new(0.9, 0),
			Speed = NumberRange.new(8, 20), Acceleration = Vector3.new(0, -14, 0), LightEmission = 1, Lifetime = NumberRange.new(0.6, 1.3), Spread = Vector2.new(50, 50)})
		FX:Burst(pos + Vector3.new(0, 2, 0), 24, {Texture = SPARK, Color = ColorSequence.new(color), Size = NumberSequence.new(1.4, 0),
			Speed = NumberRange.new(2, 6), Acceleration = Vector3.new(0, 6, 0), LightEmission = 1, Lifetime = NumberRange.new(1, 1.8)})
		-- 빛 폭발: 잠깐 아주 밝게 → 사라짐 + 위로 솟는 빛기둥
		local flash = Instance.new("Part")
		flash.Anchored, flash.CanCollide, flash.CanQuery, flash.CanTouch, flash.CastShadow = true, false, false, false, false
		flash.Shape, flash.Material, flash.Color, flash.Transparency = Enum.PartType.Cylinder, Enum.Material.Neon, color, 0.2
		flash.Size = Vector3.new(30, 3, 3)
		flash.CFrame = CFrame.new(pos + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		flash.Parent = workspace
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = color, 30, 6, false
		light.Parent = flash
		TweenService:Create(flash, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {Transparency = 1, Size = Vector3.new(60, 0.3, 0.3)}):Play()
		TweenService:Create(light, TweenInfo.new(1.1), {Brightness = 0}):Play()
		Debris:AddItem(flash, 1.2)
		if mine then
			Feel.Shake = math.max(Feel.Shake or 0, tier == "Epic" and 0.7 or 0.4)
			Feel:BigText(L.t("chest.big." .. tostring(tier)), color, 1.6)
		end
	end)
end

-- 받은 아이템 (나에게만)
function C:OnLoot(pos, got, tier)
	if typeof(pos) ~= "Vector3" or type(got) ~= "table" then return end
	local color = Color3.fromHex(CC.Colors[tier] or "#ffffff"):Lerp(Color3.new(1, 1, 1), 0.3)
	for i, entry in ipairs(got) do
		local spec = Items.Items[entry[1]]
		task.delay(0.15 + i * 0.22, function()
			Feel:Popup(pos + Vector3.new(0, 3, 0), (spec and spec.Icon or "🎁") .. " +" .. tostring(entry[2]) .. "  " .. L.t("item." .. entry[1]), color, 26, 5, 1.6)
		end)
	end
end

return C
