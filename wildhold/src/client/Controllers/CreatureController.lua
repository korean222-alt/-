-- 펫·야생 펫·밤의 괴물을 화면에 그린다.
-- 서버는 보이지 않는 기준 파트(anchor)만 움직이고, 여기서 모델을 붙여 부드럽게 따라가며 애니메이션한다.
-- ReplicatedStorage.PetModels 에 블렌더 펫 모델이 있으면 그것을, 없으면 파트 대체 모델을 쓴다.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Rig = require(script.Parent.Rig)
local Anim = require(script.Parent.Anim)
local Creatures = require(RS.Shared.Visuals.Creatures)
local P = require(RS.Shared.Config.PetConfig)
local PR = require(RS.Shared.Modules.PetRules)

local CC = {}
local player = Players.LocalPlayer
local exp, clamp = math.exp, math.clamp

local ENEMY_NAMES = {Crawler = "크롤러", Runner = "러너", Brute = "브루트", Howler = "울부짖는 자"}
local ELEMENT_COLOR = {Leaf = Color3.fromHex("#7ed36a"), Ember = Color3.fromHex("#ff9a4a"), Tide = Color3.fromHex("#6fc3ff")}
local FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamBold

local function new(className, parent, props)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end

local function corner(parent, r)
	return new("UICorner", parent, {CornerRadius = UDim.new(0, r or 6)})
end

local function hpColor(ratio)
	if ratio > 0.5 then
		return Color3.fromHex("#7be08a"):Lerp(Color3.fromHex("#f4d35e"), (1 - ratio) * 2)
	end
	return Color3.fromHex("#f4d35e"):Lerp(Color3.fromHex("#ef5b5b"), (0.5 - ratio) * 2)
end

local function localPart(parent, name, size)
	return new("Part", parent, {Name = name, Size = size or Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Anchored = true,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false})
end

function CC:Init()
	self.Visuals = {}
	self.Folder = new("Folder", workspace, {Name = "ClientVisuals"})
	self.FXFolder = new("Folder", self.Folder, {Name = "Floaters"})
	local root = workspace:WaitForChild("WILDHOLD")
	self.Root = root
	self.Ray = RaycastParams.new()
	self.Ray.FilterType = Enum.RaycastFilterType.Include
	self.Ray.FilterDescendantsInstances = {workspace.Terrain, root:WaitForChild("Base"), root:WaitForChild("Defenses"),
		root:WaitForChild("Map"), root:WaitForChild("ResourceNodes")}
	self.Ray.IgnoreWater = false
	for folderName, category in pairs({Pets = "Pet", WildPets = "Wild", Enemies = "Enemy"}) do
		local folder = root:WaitForChild(folderName)
		folder.ChildAdded:Connect(function(anchor) self:Watch(anchor, category) end)
		for _, anchor in ipairs(folder:GetChildren()) do self:Watch(anchor, category) end
	end
	-- 블렌더 모델을 나중에 넣어도(스튜디오 테스트 중) 새로 소환되는 펫부터 반영된다
	RunService.RenderStepped:Connect(function(dt) self:Step(dt) end)
end

function CC:Watch(anchor, category)
	if not anchor:IsA("BasePart") then return end
	local key = category == "Enemy" and "Kind" or "SpeciesId"
	if anchor:GetAttribute(key) then
		self:Add(anchor, category)
	else
		local conn
		conn = anchor:GetAttributeChangedSignal(key):Connect(function()
			conn:Disconnect()
			self:Add(anchor, category)
		end)
	end
end

function CC:BuildRig(kind, category, stage)
	if category == "Enemy" then
		local built = Creatures.build(kind) or Creatures.Crawler()
		return Rig.fromParts(built, 1)
	end
	-- 성체: <종>_Adult 모델이 있으면 그것, 없으면 새끼 모델을 크게
	local adult = stage == 2 and P.Species[kind] and P.Species[kind].Adult
	local height = (P.Heights[kind] or 3) * (adult and adult.Scale or 1)
	local models = RS:FindFirstChild("PetModels")
	local template = models and ((adult and models:FindFirstChild(kind .. "_Adult")) or models:FindFirstChild(kind))
	if template and template:IsA("Model") then
		local ok, result = pcall(Rig.fromMesh, template:Clone(), height)
		if ok then
			return result
		end
		warn("[WILDHOLD] 펫 모델을 쓰지 못해 대체 모델로 표시합니다: " .. kind .. " · " .. tostring(result))
	end
	local built = Creatures.build(kind) or Creatures.Mossling()
	return Rig.fromParts(built, height / built.Height)
end

function CC:Add(anchor, category)
	if self.Visuals[anchor] or not anchor.Parent then return end
	local kind = category == "Enemy" and anchor:GetAttribute("Kind") or anchor:GetAttribute("SpeciesId")
	local stage = anchor:GetAttribute("Stage") or 1
	local rig = self:BuildRig(kind, category, stage)
	rig.Model.Name = kind
	rig.Model.Parent = self.Folder
	local v = {Anchor = anchor, Category = category, Kind = kind, Stage = stage, Rig = rig, Pos = anchor.Position, Phase = math.random() * 10,
		Speed = 0, NextRay = 0, Ground = anchor.Position.Y - anchor.Size.Y / 2, Frame = 0}
	v.GroundTarget = v.Ground
	local look = anchor.CFrame.LookVector
	v.Yaw = math.atan2(-look.X, -look.Z)
	v.Tag = localPart(rig.Model, "Tag")
	v.Own = category == "Pet" and anchor:GetAttribute("OwnerId") == player.UserId
	self:MakeTag(v)
	self:Extras(v)
	local hpKey = category == "Enemy" and "CurrentHealth" or "HP"
	v.HP = anchor:GetAttribute(hpKey)
	v.Conns = {
		anchor:GetAttributeChangedSignal(hpKey):Connect(function()
			local hp = anchor:GetAttribute(hpKey)
			if v.HP and hp and hp < v.HP then
				v.HitUntil = os.clock() + 0.16
				self:DamageNumber(v, v.HP - hp)
			end
			v.HP = hp
			self:RefreshTag(v)
		end),
	}
	for _, key in ipairs({"Exhausted", "Busy", "Hunter", "Level", "MaxHP", "Status", "Fainted"}) do
		table.insert(v.Conns, anchor:GetAttributeChangedSignal(key):Connect(function() self:RefreshTag(v) end))
	end
	-- 진화하면 모델을 새로 만든다
	table.insert(v.Conns, anchor:GetAttributeChangedSignal("Stage"):Connect(function()
		if self.Visuals[anchor] == v then
			self:Remove(v)
			self:Add(anchor, category)
		end
	end))
	self.Visuals[anchor] = v
	self:RefreshTag(v)
	-- 등장 연출: 살짝 커지며 나타난다
	rig:SetTransparency(1)
	task.spawn(function()
		for i = 1, 8 do
			if not rig.Model.Parent then return end
			rig:SetTransparency(1 - i / 8)
			task.wait(0.03)
		end
		rig:SetTransparency(0)
	end)
end

function CC:Remove(v)
	self.Visuals[v.Anchor] = nil
	for _, c in ipairs(v.Conns or {}) do c:Disconnect() end
	if v.Category == "Enemy" then
		-- 쓰러진 괴물은 옆으로 기울며 연기처럼 사라진다
		local rig, root = v.Rig, v.LastRoot or CFrame.new(v.Pos)
		task.spawn(function()
			for i = 1, 10 do
				if not rig.Model.Parent then return end
				rig:Apply(root * CFrame.new(0, -i * 0.08, 0) * CFrame.Angles(0, 0, math.rad(i * 6)), {})
				rig:SetTransparency(i / 10)
				task.wait(0.03)
			end
			rig:Destroy()
		end)
	else
		v.Rig:Destroy()
	end
end

-- ===================================================================== 이름표
function CC:MakeTag(v)
	local height = v.Category == "Wild" and 52 or (v.Category == "Enemy" and 30 or 40)
	local gui = new("BillboardGui", v.Tag, {Name = "Nameplate", Size = UDim2.fromOffset(150, height), LightInfluence = 0,
		AlwaysOnTop = v.Own, MaxDistance = v.Category == "Enemy" and 80 or 70, StudsOffsetWorldSpace = Vector3.new(0, 0.4, 0)})
	local nameLabel = new("TextLabel", gui, {Name = "Name", Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Font = FONT,
		TextSize = 16, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.35, Text = ""})
	local bar = new("Frame", gui, {Name = "Bar", Position = UDim2.new(0.5, -44, 0, 20), Size = UDim2.fromOffset(88, 8),
		BackgroundColor3 = Color3.fromHex("#1c2330"), BackgroundTransparency = 0.2, BorderSizePixel = 0})
	corner(bar, 4)
	new("UIStroke", bar, {Color = Color3.fromHex("#0d1118"), Thickness = 1.2, Transparency = 0.2})
	local fill = new("Frame", bar, {Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex("#7be08a"), BorderSizePixel = 0})
	corner(fill, 4)
	if v.Category == "Wild" then
		-- 포획 기준선 (HP 25%)
		new("Frame", bar, {Name = "Mark", Position = UDim2.new(P.CaptureHP, -1, 0, -2), Size = UDim2.new(0, 2, 1, 4),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3})
		new("TextLabel", gui, {Name = "Hint", Position = UDim2.new(0, 0, 0, 31), Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
			Font = BODY_FONT, TextSize = 13, TextColor3 = Color3.fromHex("#ffe9a8"), TextStrokeTransparency = 0.3, Text = ""})
	end
	if v.Category == "Enemy" then
		nameLabel.TextSize = 13
		bar.Position = UDim2.new(0.5, -40, 0, 16)
		bar.Size = UDim2.fromOffset(80, 7)
		fill.BackgroundColor3 = Color3.fromHex("#ef5b5b")
		gui.Enabled = false
	end
	v.Gui, v.NameLabel, v.Fill = gui, nameLabel, fill
end

function CC:RefreshTag(v)
	local a = v.Anchor
	if not v.Gui then return end
	if v.Category == "Enemy" then
		local maxHP = a:GetAttribute("MaxHealth") or 1
		local hp = a:GetAttribute("CurrentHealth") or maxHP
		local boss = a:GetAttribute("Boss")
		v.Gui.Enabled = boss or hp < maxHP
		v.NameLabel.Text = boss and ("👑 " .. (ENEMY_NAMES[v.Kind] or v.Kind)) or ""
		v.Fill.Size = UDim2.fromScale(clamp(hp / maxHP, 0, 1), 1)
		if boss then
			v.Gui.Size = UDim2.fromOffset(200, 36)
			v.Gui.Bar.Size = UDim2.fromOffset(160, 10)
			v.Gui.Bar.Position = UDim2.new(0.5, -80, 0, 20)
			v.Gui.MaxDistance = 200
		end
		return
	end
	local spec = P.Species[v.Kind]
	local hp, maxHP = a:GetAttribute("HP") or 1, a:GetAttribute("MaxHP") or 1
	local ratio = clamp(hp / math.max(1, maxHP), 0, 1)
	TweenService:Create(v.Fill, TweenInfo.new(0.2), {Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = hpColor(ratio)}):Play()
	local level = a:GetAttribute("Level") or 1
	if v.Category == "Pet" then
		local status = a:GetAttribute("Status")
		local temp = status ~= "영구"
		v.NameLabel.Text = string.format("%s Lv%d%s", PR.name(v.Kind, v.Stage, P), level, a:GetAttribute("Fainted") and " 💤" or "")
		v.NameLabel.TextColor3 = v.Own and (temp and Color3.fromHex("#ffe58a") or Color3.fromHex("#b7f5c8")) or Color3.fromHex("#e8eef5")
		if not v.Own then
			v.NameLabel.Text = (a:GetAttribute("OwnerName") or "") .. "의 " .. v.NameLabel.Text
			v.NameLabel.TextSize = 13
		end
		return
	end
	-- 야생
	v.NameLabel.Text = string.format("야생 %s Lv%d", PR.name(v.Kind, v.Stage, P), level)
	v.NameLabel.TextColor3 = ELEMENT_COLOR[spec.Element] or Color3.new(1, 1, 1)
	local hint = v.Gui:FindFirstChild("Hint")
	local hunter = a:GetAttribute("Hunter") or ""
	if a:GetAttribute("Busy") then
		hint.Text = "🧺 포획 중…"
	elseif a:GetAttribute("Exhausted") then
		hint.Text = "✨ 포획 가능! 가까이 가서 E"
	elseif hunter ~= "" and hunter ~= player.DisplayName then
		hint.Text = "🏹 " .. hunter .. " 사냥 중 · 도와주기"
	elseif ratio < 1 then
		hint.Text = "HP 25%까지 약하게!"
	else
		hint.Text = spec.Role .. " · " .. ({Leaf = "풀", Ember = "불", Tide = "물"})[spec.Element]
	end
end

function CC:DamageNumber(v, amount)
	if #self.FXFolder:GetChildren() > 30 then return end
	local holder = localPart(self.FXFolder, "Damage")
	holder.CFrame = v.Tag.CFrame * CFrame.new((math.random() - 0.5) * 1.5, 0, 0)
	local gui = new("BillboardGui", holder, {Size = UDim2.fromOffset(80, 30), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 90})
	local text = new("TextLabel", gui, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT, TextScaled = true,
		Text = tostring(math.max(1, math.floor(amount + 0.5))), TextStrokeTransparency = 0.2,
		TextColor3 = v.Category == "Enemy" and Color3.fromHex("#ffe066") or Color3.fromHex("#ff8a8a")})
	TweenService:Create(gui, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)}):Play()
	TweenService:Create(text, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(holder, 0.75)
end

-- ===================================================================== 종별 효과
local function emitter(parent, props)
	return new("ParticleEmitter", parent, props)
end

function CC:Extras(v)
	v.Extras = {}
	local model = v.Rig.Model
	if v.Kind == "Emberpup" then
		local flame = localPart(model, "FlamePoint")
		local att = new("Attachment", flame)
		emitter(att, {Texture = "rbxasset://textures/particles/fire_main.dds", Rate = 26, Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(12, 12), LightEmission = 1, LightInfluence = 0,
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1)}),
			Color = ColorSequence.new(Color3.fromHex("#ffd36b"), Color3.fromHex("#ff5a1f")),
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)}),
			Acceleration = Vector3.new(0, 4, 0)})
		new("PointLight", flame, {Range = 9, Brightness = 1.4, Color = Color3.fromHex("#ffa24a"), Shadows = false})
		v.Extras.Flame = flame
	elseif v.Kind == "Briarhorn" then
		local aura = localPart(model, "Aura")
		local att = new("Attachment", aura)
		emitter(att, {Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 10, Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(0.5, 1.4), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8,
			Size = NumberSequence.new(0.5, 0), Color = ColorSequence.new(Color3.fromHex("#c9ff9a"), Color3.fromHex("#ff9ecf"))})
		new("PointLight", aura, {Range = 16, Brightness = 1, Color = Color3.fromHex("#c9ff9a"), Shadows = false})
		v.Extras.Aura = aura
		if v.Category == "Wild" then
			local ring = new("Part", model, {Name = "AlphaRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 11, 11),
				Material = Enum.Material.Neon, Color = Color3.fromHex("#b6ff8a"), Transparency = 0.7, Anchored = true, CanCollide = false,
				CanQuery = false, CanTouch = false, CastShadow = false})
			v.Extras.Ring = ring
		end
	elseif v.Kind == "Howler" then
		local aura = localPart(model, "Aura")
		local att = new("Attachment", aura)
		emitter(att, {Texture = "rbxasset://textures/particles/smoke_main.dds", Rate = 18, Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(1, 2.5), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.4,
			Size = NumberSequence.new(3, 5), Color = ColorSequence.new(Color3.fromHex("#8a3cff")),
			Transparency = NumberSequence.new(0.6, 1)})
		new("PointLight", aura, {Range = 24, Brightness = 2, Color = Color3.fromHex("#b25cff"), Shadows = false})
		v.Extras.Aura = aura
	end
	if v.Category == "Wild" then
		-- 탈진하면 머리 위에 별이 돈다
		local stars = {}
		for i = 1, 3 do
			stars[i] = new("Part", model, {Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Material = Enum.Material.Neon,
				Color = Color3.fromHex("#ffe066"), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
				CastShadow = false, Transparency = 1})
		end
		v.Extras.Stars = stars
	end
end

function CC:UpdateExtras(v, root, t)
	local e = v.Extras
	if e.Flame then
		local flameCore = v.Rig.Model:FindFirstChild("FlameCore")
		e.Flame.CFrame = flameCore and flameCore.CFrame or v.Rig:PointWorld(root, "FlameTip", Vector3.new(0, v.Rig.Height * 0.9, v.Rig.Height * 0.4))
	end
	if e.Aura then
		e.Aura.CFrame = root * CFrame.new(0, v.Rig.Height * 0.5, 0)
	end
	if e.Ring then
		e.Ring.CFrame = CFrame.new(root.Position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
		e.Ring.Transparency = 0.6 + math.sin(t * 3) * 0.15
	end
	if e.Stars then
		local on = v.Anchor:GetAttribute("Exhausted") == true
		for i, star in ipairs(e.Stars) do
			local a = t * 3 + i * (math.pi * 2 / 3)
			star.Transparency = on and 0 or 1
			star.CFrame = root * CFrame.new(math.cos(a) * 0.9, v.Rig.Height + 0.3 + math.sin(t * 5 + i) * 0.1, math.sin(a) * 0.9)
		end
	end
end

-- ===================================================================== 매 프레임
function CC:Step(dt)
	local now = workspace:GetServerTimeNow()
	local t = os.clock()
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	for anchor, v in pairs(self.Visuals) do
		if not anchor.Parent then
			self:Remove(v)
			continue
		end
		v.Frame = v.Frame + 1
		local target = anchor.Position
		local distance = (target - camPos).Magnitude
		-- 멀리 있는 것은 덜 자주 갱신 (모바일 성능)
		if distance > 220 or (distance > 110 and v.Frame % 3 ~= 0) then
			continue
		end
		local step = distance > 110 and dt * 3 or dt
		local alpha = 1 - exp(-9 * step)
		local newPos = v.Pos:Lerp(target, alpha)
		local moved = Vector3.new(newPos.X - v.Pos.X, 0, newPos.Z - v.Pos.Z).Magnitude / math.max(step, 1e-3)
		v.Pos = newPos
		local ref = v.Category == "Enemy" and 8 or 12
		v.Speed = v.Speed + (clamp(moved / ref, 0, 1) - v.Speed) * (1 - exp(-8 * step))
		local look = anchor.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local diff = (yaw - v.Yaw + math.pi) % (math.pi * 2) - math.pi
		v.Yaw = v.Yaw + diff * (1 - exp(-8 * step))
		if t >= v.NextRay then
			v.NextRay = t + 0.12
			local origin = Vector3.new(v.Pos.X, target.Y + 3, v.Pos.Z)
			local hit = workspace:Raycast(origin, Vector3.new(0, -40, 0), self.Ray)
			v.GroundTarget = hit and hit.Position.Y or (target.Y - anchor.Size.Y / 2)
		end
		v.Ground = v.Ground + (v.GroundTarget - v.Ground) * (1 - exp(-12 * step))
		local root = CFrame.new(v.Pos.X, v.Ground, v.Pos.Z) * CFrame.Angles(0, v.Yaw, 0)
		local attackAt = anchor:GetAttribute("AttackAt")
		local age = attackAt and now - attackAt
		local pose, whole = Anim.pose({Kind = v.Kind, Time = t, Speed = v.Speed, Height = v.Rig.Height, Phase = v.Phase,
			Attack = (age and age >= 0 and age < 0.45) and age / 0.45 or nil,
			Faint = anchor:GetAttribute("Fainted") == true, Exhausted = anchor:GetAttribute("Exhausted") == true})
		if v.HitUntil and t < v.HitUntil then
			whole = whole * CFrame.new((math.random() - 0.5) * 0.25, 0, (math.random() - 0.5) * 0.25)
		end
		local final = root * whole
		v.Rig:Apply(final, pose)
		v.LastRoot = final
		v.Tag.CFrame = root * CFrame.new(0, v.Rig.Height + 0.5, 0)
		self:UpdateExtras(v, root, t)
	end
end

return CC
