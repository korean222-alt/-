-- 전투·채집·건설·포획 효과. 서버 FX 리모트를 받아 로컬에서만 그린다 (서버 부하 없음).
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local B = require(RS.Shared.Visuals.Build)
local Structures = require(RS.Shared.Visuals.Structures)
local P = require(RS.Shared.Config.PetConfig)

local FX = {}
local M = Enum.Material
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function holder(folder, pos)
	return B.new("Part", folder, {Name = "FX", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(pos), Transparency = 1, CastShadow = false})
end

-- 한 번 터뜨리는 입자
function FX:Burst(pos, count, props)
	local h = holder(self.Folder, pos)
	local att = Instance.new("Attachment")
	att.Parent = h
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = props.Texture or SPARK
	e.Color = props.Color or ColorSequence.new(Color3.new(1, 1, 1))
	e.Size = props.Size or NumberSequence.new(0.6, 0)
	e.Lifetime = props.Lifetime or NumberRange.new(0.4, 0.8)
	e.Speed = props.Speed or NumberRange.new(4, 9)
	e.SpreadAngle = props.Spread or Vector2.new(180, 180)
	e.Acceleration = props.Acceleration or Vector3.new(0, -8, 0)
	e.LightEmission = props.LightEmission or 0.6
	e.Transparency = props.Transparency or NumberSequence.new(0, 1)
	e.Drag = props.Drag or 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Parent = att
	e:Emit(count)
	Debris:AddItem(h, 2)
	return h
end

function FX:Init(remotes)
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "LocalFX"
	self.Folder.Parent = workspace
	self.Flights, self.Traps = {}, {}
	remotes.FX.OnClientEvent:Connect(function(kind, ...)
		local fn = self["On" .. tostring(kind)]
		if fn then
			fn(self, ...)
		end
	end)
	RunService.RenderStepped:Connect(function() self:Step() end)
end

-- ===================================================================== 날아가는 것
function FX:Fly(parts, from, to, speed, arc, onArrive, spin)
	local distance = (to - from).Magnitude
	table.insert(self.Flights, {Parts = parts, From = from, To = to, Start = os.clock(), Duration = math.max(0.08, distance / speed),
		Arc = arc or 0, Done = onArrive, Spin = spin})
end

function FX:Step()
	local now = os.clock()
	for i = #self.Flights, 1, -1 do
		local f = self.Flights[i]
		local a = math.clamp((now - f.Start) / f.Duration, 0, 1)
		local pos = f.From:Lerp(f.To, a) + Vector3.new(0, math.sin(a * math.pi) * f.Arc, 0)
		local ahead = f.From:Lerp(f.To, math.min(1, a + 0.05)) + Vector3.new(0, math.sin(math.min(1, a + 0.05) * math.pi) * f.Arc, 0)
		local frame = (ahead - pos).Magnitude > 1e-3 and CFrame.lookAt(pos, ahead) or CFrame.new(pos)
		if f.Spin then
			frame = frame * CFrame.Angles(0, 0, now * f.Spin)
		end
		for _, entry in ipairs(f.Parts) do
			entry[1].CFrame = frame * entry[2]
		end
		if a >= 1 then
			table.remove(self.Flights, i)
			for _, entry in ipairs(f.Parts) do entry[1]:Destroy() end
			if f.Done then f.Done(f.To) end
		end
	end
end

-- ===================================================================== 플레이어 창 / 채집
function FX:OnSpear(from, to)
	local dir = (to - from)
	if dir.Magnitude < 0.1 then return end
	local mid = from + dir * 0.6
	local slash = B.block(self.Folder, Vector3.new(0.15, 0.15, math.min(6, dir.Magnitude)), CFrame.lookAt(mid, to), "#e8fbff", M.Neon, {Transparency = 0.2})
	TweenService:Create(slash, TweenInfo.new(0.16), {Transparency = 1, Size = Vector3.new(0.02, 0.02, slash.Size.Z * 1.3)}):Play()
	Debris:AddItem(slash, 0.2)
	self:Burst(to, 8, {Color = ColorSequence.new(Color3.fromHex("#fff6c8")), Size = NumberSequence.new(0.5, 0), Speed = NumberRange.new(6, 12)})
end

function FX:OnHarvest(from, to)
	self:OnSpear(from, to)
	self:Burst(to + Vector3.new(0, 1, 0), 10, {Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#d9c7a3")), Size = NumberSequence.new(0.6, 1.4),
		Speed = NumberRange.new(2, 5), Lifetime = NumberRange.new(0.4, 0.7), LightEmission = 0, Transparency = NumberSequence.new(0.3, 1)})
	self:Burst(to + Vector3.new(0, 1.5, 0), 7, {Color = ColorSequence.new(Color3.fromHex("#8a5d36"), Color3.fromHex("#7fc65c")), Size = NumberSequence.new(0.35, 0.2),
		Speed = NumberRange.new(6, 11), Acceleration = Vector3.new(0, -30, 0), LightEmission = 0})
end

-- ===================================================================== 포탑 화살
function FX:OnArrow(from, to)
	local shaft = B.block(self.Folder, Vector3.new(0.12, 0.12, 2.2), CFrame.new(from), "#b98a57", M.Wood)
	local tip = B.wedge(self.Folder, Vector3.new(0.1, 0.3, 0.45), CFrame.new(from), "#dfe6ea", M.Metal)
	local fletch = B.block(self.Folder, Vector3.new(0.4, 0.05, 0.4), CFrame.new(from), "#f2f2f2", M.SmoothPlastic)
	local distance = (to - from).Magnitude
	self:Fly({{shaft, CFrame.new()}, {tip, CFrame.new(0, 0, -1.3) * CFrame.Angles(math.rad(-90), 0, 0)}, {fletch, CFrame.new(0, 0, 1)}},
		from, to + Vector3.new(0, 1, 0), 140, distance * 0.08, function(pos)
			self:Burst(pos, 6, {Color = ColorSequence.new(Color3.fromHex("#fff0b3")), Speed = NumberRange.new(5, 9), Size = NumberSequence.new(0.4, 0)})
		end)
end

-- ===================================================================== 펫 공격 (속성별)
function FX:OnPet(from, to, species)
	local spec = P.Species[species or ""]
	local element = spec and spec.Element or "Leaf"
	local target = to + Vector3.new(0, 1, 0)
	if species == "Emberpup" then
		local ball = B.ball(self.Folder, 1.1, CFrame.new(from), "#ffb347", M.Neon)
		local att = Instance.new("Attachment")
		att.Parent = ball
		local trail = Instance.new("ParticleEmitter")
		trail.Texture, trail.Rate, trail.Lifetime = FIRE, 60, NumberRange.new(0.2, 0.35)
		trail.Speed, trail.LightEmission = NumberRange.new(0.5, 1), 1
		trail.Size = NumberSequence.new(1.1, 0.1)
		trail.Color = ColorSequence.new(Color3.fromHex("#ffd36b"), Color3.fromHex("#ff5a1f"))
		trail.Parent = att
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color, light.Parent = 10, 2, Color3.fromHex("#ff9a3c"), ball
		self:Fly({{ball, CFrame.new()}}, from + Vector3.new(0, 1.5, 0), target, 55, 2.5, function(pos)
			self:Burst(pos, 18, {Texture = FIRE, Color = ColorSequence.new(Color3.fromHex("#ffd36b"), Color3.fromHex("#ff5a1f")),
				Size = NumberSequence.new(1.6, 0.2), Speed = NumberRange.new(4, 10), Acceleration = Vector3.new(0, 6, 0), LightEmission = 1})
			self:Burst(pos, 8, {Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#6b5a52")), Size = NumberSequence.new(1, 2.4),
				Speed = NumberRange.new(2, 4), LightEmission = 0, Transparency = NumberSequence.new(0.4, 1), Acceleration = Vector3.new(0, 3, 0)})
		end)
	elseif element == "Tide" then
		self:Burst(target, 16, {Color = ColorSequence.new(Color3.fromHex("#bdf0ff"), Color3.fromHex("#4fb8d8")), Size = NumberSequence.new(0.7, 0.1),
			Speed = NumberRange.new(5, 10), Acceleration = Vector3.new(0, -25, 0), LightEmission = 0.3})
		local ring = B.cyl(self.Folder, 0.1, 1, CFrame.new(to + Vector3.new(0, 0.3, 0)), "#9fe6ff", M.Neon, true, {Transparency = 0.3})
		TweenService:Create(ring, TweenInfo.new(0.35), {Size = Vector3.new(0.1, 6, 6), Transparency = 1}):Play()
		Debris:AddItem(ring, 0.4)
	elseif species == "Briarhorn" then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local base = to + Vector3.new(math.cos(a) * 1.6, 0, math.sin(a) * 1.6)
			local thorn = B.wedge(self.Folder, Vector3.new(0.4, 0.1, 0.8), CFrame.new(base) * CFrame.Angles(0, a, 0), "#6f9443", M.SmoothPlastic)
			TweenService:Create(thorn, TweenInfo.new(0.15, Enum.EasingStyle.Back), {Size = Vector3.new(0.4, 2.6, 0.8), CFrame = CFrame.new(base + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, a, 0)}):Play()
			Debris:AddItem(thorn, 0.45)
		end
		self:Burst(target, 14, {Color = ColorSequence.new(Color3.fromHex("#b6ff8a"), Color3.fromHex("#ff9ecf")), Speed = NumberRange.new(6, 12)})
	else
		-- 잎 베기: 초록 호가 휙
		local arcPart = B.block(self.Folder, Vector3.new(2.6, 0.1, 0.4), CFrame.lookAt(target, from) * CFrame.Angles(0, 0, math.rad(35)), "#9df07e", M.Neon, {Transparency = 0.15})
		TweenService:Create(arcPart, TweenInfo.new(0.18), {Transparency = 1, Size = Vector3.new(3.4, 0.05, 0.2),
			CFrame = arcPart.CFrame * CFrame.Angles(0, 0, math.rad(-70))}):Play()
		Debris:AddItem(arcPart, 0.22)
		self:Burst(target, 10, {Color = ColorSequence.new(Color3.fromHex("#7ed36a"), Color3.fromHex("#d9ff9e")), Size = NumberSequence.new(0.5, 0.1),
			Speed = NumberRange.new(4, 9), Acceleration = Vector3.new(0, -6, 0)})
	end
end

-- ===================================================================== 포획 바구니
function FX:OnTrapStart(pos, seconds, better, wildId)
	if self.Traps[wildId] then self.Traps[wildId].Model:Destroy() end
	local model = Instance.new("Model")
	model.Name = "Trap"
	model.Parent = self.Folder
	local ground = Vector3.new(pos.X, pos.Y - 1.8, pos.Z)
	local charm = Structures.trapIcon(model, CFrame.new(ground), 1.25)
	if better then
		charm.Color = Color3.fromHex("#ffd36b")
	end
	local trap = {Model = model, Charm = charm, Ground = ground, Start = os.clock(), Seconds = seconds or 2.4}
	self.Traps[wildId] = trap
	model:PivotTo(CFrame.new(ground + Vector3.new(0, 9, 0)))
	task.spawn(function()
		-- 떨어져서 덮치고 → 3번 흔들린다
		local t0 = os.clock()
		while model.Parent do
			local e = os.clock() - t0
			local frame
			if e < 0.28 then
				local a = e / 0.28
				frame = CFrame.new(ground + Vector3.new(0, 9 * (1 - a * a), 0))
			else
				local shake = (e - 0.28) / math.max(0.3, trap.Seconds - 0.28)
				local beat = (shake * 3) % 1
				local angle = shake < 1 and math.sin(beat * math.pi * 2) * math.rad(16) * (beat < 0.6 and 1 or 0) or 0
				frame = CFrame.new(ground) * CFrame.Angles(0, 0, angle)
				charm.Transparency = 0.5 + 0.5 * math.sin(e * 12)
			end
			model:PivotTo(frame)
			if e > trap.Seconds + 1.5 then
				model:Destroy()
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
	self:Burst(ground + Vector3.new(0, 1, 0), 12, {Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#e8dcc0")), Size = NumberSequence.new(1, 2.2),
		Speed = NumberRange.new(3, 6), LightEmission = 0, Transparency = NumberSequence.new(0.4, 1), Spread = Vector2.new(90, 20)})
end

function FX:OnTrapResult(pos, success, species, wildId)
	local trap = self.Traps[wildId]
	self.Traps[wildId] = nil
	local center = trap and trap.Ground + Vector3.new(0, 1.5, 0) or pos
	if success then
		local spec = P.Species[species or ""]
		local col = spec and Color3.fromRGB(table.unpack(spec.Color)) or Color3.fromHex("#b6ff8a")
		self:Burst(center, 40, {Color = ColorSequence.new(Color3.fromHex("#fff3a8"), col), Size = NumberSequence.new(0.9, 0), Speed = NumberRange.new(8, 16),
			Lifetime = NumberRange.new(0.6, 1.1), Acceleration = Vector3.new(0, -4, 0), LightEmission = 1})
		self:Burst(center + Vector3.new(0, 2, 0), 12, {Color = ColorSequence.new(Color3.fromHex("#ffe066")), Size = NumberSequence.new(1.2, 0),
			Speed = NumberRange.new(2, 5), Lifetime = NumberRange.new(1, 1.6), Acceleration = Vector3.new(0, 3, 0), LightEmission = 1})
		if trap then
			trap.Charm.Color = Color3.fromHex("#ffe066")
			for _, d in ipairs(trap.Model:GetDescendants()) do
				if d:IsA("BasePart") then
					TweenService:Create(d, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.4), {Transparency = 1}):Play()
				end
			end
			Debris:AddItem(trap.Model, 1.5)
		end
	else
		-- 실패: 바구니가 터지며 조각이 흩어진다
		if trap then
			trap.Model.Parent = self.Folder
			for _, d in ipairs(trap.Model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored, d.CanCollide = false, true
					d.AssemblyLinearVelocity = (d.Position - trap.Ground).Unit * 22 + Vector3.new(0, 18, 0)
					TweenService:Create(d, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
				end
			end
			Debris:AddItem(trap.Model, 1.4)
		end
		self:Burst(center, 18, {Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#cfc3b0")), Size = NumberSequence.new(1.2, 2.6),
			Speed = NumberRange.new(4, 8), LightEmission = 0, Transparency = NumberSequence.new(0.3, 1)})
	end
end

-- ===================================================================== 괴물, 시설, 노드
function FX:OnEnemyDie(pos, kind)
	local big = kind == "Brute" or kind == "Howler"
	self:Burst(pos, big and 30 or 16, {Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#6a3fa0"), Color3.fromHex("#1c1427")),
		Size = NumberSequence.new(big and 3 or 1.6, big and 6 or 3.2), Speed = NumberRange.new(3, 7), Lifetime = NumberRange.new(0.6, 1.1),
		LightEmission = 0.2, Transparency = NumberSequence.new(0.2, 1), Acceleration = Vector3.new(0, 4, 0)})
	self:Burst(pos, 10, {Color = ColorSequence.new(Color3.fromHex("#d9a6ff")), Speed = NumberRange.new(8, 14), Size = NumberSequence.new(0.6, 0)})
end

function FX:Dust(pos, radius)
	self:Burst(pos + Vector3.new(0, 0.5, 0), 16, {Texture = SMOKE, Color = ColorSequence.new(Color3.fromHex("#e0d2b5")), Size = NumberSequence.new(radius * 0.3, radius * 0.7),
		Speed = NumberRange.new(radius, radius * 2), Spread = Vector2.new(90, 10), LightEmission = 0, Transparency = NumberSequence.new(0.3, 1),
		Acceleration = Vector3.new(0, 1, 0), Lifetime = NumberRange.new(0.6, 1)})
end

function FX:OnBuild(pos)
	self:Dust(pos, 5)
	self:Burst(pos + Vector3.new(0, 4, 0), 24, {Color = ColorSequence.new(Color3.fromHex("#fff3a8"), Color3.fromHex("#8ff5e8")),
		Size = NumberSequence.new(0.7, 0), Speed = NumberRange.new(6, 12), LightEmission = 1})
end

function FX:OnRepair(pos)
	self:Burst(pos + Vector3.new(0, 3, 0), 12, {Color = ColorSequence.new(Color3.fromHex("#9df07e")), Size = NumberSequence.new(0.6, 0), Speed = NumberRange.new(4, 8)})
end

function FX:OnBreak(pos)
	self:Dust(pos, 7)
	for i = 1, 8 do
		local chunk = B.block(self.Folder, Vector3.new(0.8, 0.6, 0.7), CFrame.new(pos + Vector3.new(0, 2 + i * 0.3, 0)), i % 2 == 0 and "#8b5a2b" or "#9aa1a6", M.Wood)
		chunk.Anchored, chunk.CanCollide = false, true
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-14, 14), math.random(10, 20), math.random(-14, 14))
		Debris:AddItem(chunk, 2)
	end
end

function FX:OnSpikes(pos)
	self:Burst(pos + Vector3.new(0, 0.5, 0), 10, {Color = ColorSequence.new(Color3.fromHex("#e3e8ec")), Size = NumberSequence.new(0.4, 0), Speed = NumberRange.new(4, 10),
		Spread = Vector2.new(40, 40)})
end

function FX:OnRegrow(pos, kind)
	local col = kind == "Berry" and Color3.fromHex("#ff6b9a") or Color3.fromHex("#9df07e")
	self:Burst(pos + Vector3.new(0, 2, 0), 16, {Color = ColorSequence.new(col, Color3.fromHex("#ffffff")), Size = NumberSequence.new(0.6, 0),
		Speed = NumberRange.new(2, 6), Acceleration = Vector3.new(0, 4, 0), LightEmission = 0.8})
end

return FX
