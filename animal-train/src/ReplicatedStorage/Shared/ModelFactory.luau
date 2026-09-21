-- 파트만 조합해서 만드는 모델 공장.
-- 툴박스 무료 모델은 쓰지 않습니다 (CLAUDE.md 기술 규칙).
-- 서버(동물 스폰)와 클라이언트(도감·HUD 아이콘) 양쪽에서 씁니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ModelFactory = {}

local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local DARK = Color3.fromRGB(48, 46, 58)
local WHITE = Color3.fromRGB(252, 252, 255)
local ORANGE = Color3.fromRGB(255, 163, 71)
local PINK = Color3.fromRGB(255, 168, 196)

-- 동물 몸 중심을 땅에서 얼마나 띄울지 (발이 땅에 닿게)
ModelFactory.Lift = {
	Chick = 1.2,
	Duckling = 1.25,
	Penguin = 1.5,
	SnowBunny = 1.15,
	RainbowRabbit = 1.15,
	GoldenPenguin = 1.5,
	Fox = 1.75,
}

--=========================================================
-- 기본 도구
--=========================================================
local function newPart(def)
	local instance = Instance.new(def.Class or "Part")
	instance.Name = def.Name or "Piece"
	instance.Anchored = true
	instance.CanCollide = def.CanCollide == true
	instance.CanQuery = def.CanQuery == true
	instance.CanTouch = def.CanTouch == true
	instance.CastShadow = def.CastShadow == true
	instance.Material = def.Material or SMOOTH
	instance.Size = def.Size
	instance.Color = def.Color or WHITE
	instance.Transparency = def.Transparency or 0
	instance.Reflectance = def.Reflectance or 0
	if instance:IsA("Part") then
		if def.Shape then
			instance.Shape = def.Shape
		end
		instance.TopSurface = Enum.SurfaceType.Smooth
		instance.BottomSurface = Enum.SurfaceType.Smooth
		instance.LeftSurface = Enum.SurfaceType.Smooth
		instance.RightSurface = Enum.SurfaceType.Smooth
		instance.FrontSurface = Enum.SurfaceType.Smooth
		instance.BackSurface = Enum.SurfaceType.Smooth
	end
	return instance
end
ModelFactory.newPart = newPart

-- 파트 목록을 하나의 Model 로 조립합니다. Primary = true 인 파트가 기준점.
local function assemble(name, pieces)
	local model = Instance.new("Model")
	model.Name = name

	local primary = nil
	for _, def in ipairs(pieces) do
		local piece = newPart(def)
		local cframe = CFrame.new(def.Pos or Vector3.zero)
		if def.Rot then
			cframe = cframe
				* CFrame.fromEulerAnglesXYZ(math.rad(def.Rot.X), math.rad(def.Rot.Y), math.rad(def.Rot.Z))
		end
		piece.CFrame = cframe
		piece.Parent = model
		if def.Primary then
			primary = piece
		end
	end

	if primary then
		model.PrimaryPart = primary
		model.WorldPivot = primary.CFrame
	end
	return model
end
ModelFactory.assemble = assemble

-- 반짝임 파티클 (멀리서도 눈에 띄게)
function ModelFactory.addSparkles(parent: Instance, color: Color3, rate: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = Config.Textures.Sparkle
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.9
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Rate = rate or 7
	emitter.Speed = NumberRange.new(1.2, 2.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 2.5, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = parent
	return emitter
end

-- 한 번 터지는 파티클 (하트/별/폭죽)
function ModelFactory.burst(position: Vector3, color: Color3, count: number, parentTo: Instance?)
	local anchor = newPart({
		Name = "Burst",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Color = color,
		Transparency = 1,
	})
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = parentTo or workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Config.Textures.Sparkle
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(7, 13)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = anchor
	emitter:Emit(count)

	task.delay(1.4, function()
		anchor:Destroy()
	end)
	return anchor
end

--=========================================================
-- 동물 : 병아리 / 오리
--=========================================================
local function buildChickLike(name, opts)
	local body = opts.Body
	local scale = opts.Scale or 1
	local pieces = {
		{ Name = "Body", Primary = true, Shape = BALL, Size = Vector3.new(2.2, 2.2, 2.2) * scale, Pos = Vector3.zero, Color = body },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(1.5, 1.5, 1.5) * scale, Pos = Vector3.new(0, 1.25, 0.3) * scale, Color = body },
		{ Name = "Beak", Size = opts.BeakSize * scale, Pos = Vector3.new(0, 1.12, 1.0) * scale, Color = ORANGE },
		{ Name = "EyeL", Shape = BALL, Size = Vector3.new(0.3, 0.3, 0.3) * scale, Pos = Vector3.new(-0.36, 1.48, 0.9) * scale, Color = DARK },
		{ Name = "EyeR", Shape = BALL, Size = Vector3.new(0.3, 0.3, 0.3) * scale, Pos = Vector3.new(0.36, 1.48, 0.9) * scale, Color = DARK },
		{ Name = "WingL", Shape = BALL, Size = Vector3.new(0.3, 0.85, 1.0) * scale, Pos = Vector3.new(-1.05, 0.05, 0) * scale, Color = opts.Wing or body },
		{ Name = "WingR", Shape = BALL, Size = Vector3.new(0.3, 0.85, 1.0) * scale, Pos = Vector3.new(1.05, 0.05, 0) * scale, Color = opts.Wing or body },
		{ Name = "Tuft", Shape = BALL, Size = Vector3.new(0.5, 0.5, 0.5) * scale, Pos = Vector3.new(0, 1.95, 0.15) * scale, Color = opts.Tuft or body },
		{ Name = "FootL", Size = Vector3.new(0.32, 0.2, 0.68) * scale, Pos = Vector3.new(-0.4, -1.05, 0.2) * scale, Color = ORANGE },
		{ Name = "FootR", Size = Vector3.new(0.32, 0.2, 0.68) * scale, Pos = Vector3.new(0.4, -1.05, 0.2) * scale, Color = ORANGE },
	}
	return assemble(name, pieces)
end

--=========================================================
-- 동물 : 펭귄
--=========================================================
local function buildPenguinLike(name, opts)
	local body = opts.Body
	local belly = opts.Belly or WHITE
	local shine = opts.Reflectance or 0
	local pieces = {
		{ Name = "Body", Primary = true, Shape = BALL, Size = Vector3.new(2.3, 2.7, 2.1), Pos = Vector3.zero, Color = body, Reflectance = shine },
		{ Name = "Belly", Shape = BALL, Size = Vector3.new(1.7, 2.0, 1.2), Pos = Vector3.new(0, -0.1, 0.7), Color = belly },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(1.55, 1.55, 1.55), Pos = Vector3.new(0, 1.5, 0.05), Color = body, Reflectance = shine },
		{ Name = "FaceL", Shape = BALL, Size = Vector3.new(0.55, 0.6, 0.4), Pos = Vector3.new(-0.38, 1.55, 0.66), Color = belly },
		{ Name = "FaceR", Shape = BALL, Size = Vector3.new(0.55, 0.6, 0.4), Pos = Vector3.new(0.38, 1.55, 0.66), Color = belly },
		{ Name = "EyeL", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(-0.38, 1.6, 0.84), Color = DARK },
		{ Name = "EyeR", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(0.38, 1.6, 0.84), Color = DARK },
		{ Name = "Beak", Size = Vector3.new(0.42, 0.3, 0.6), Pos = Vector3.new(0, 1.24, 0.82), Color = ORANGE },
		{ Name = "FlipperL", Shape = BALL, Size = Vector3.new(0.3, 1.3, 0.9), Pos = Vector3.new(-1.15, -0.15, 0), Color = body, Reflectance = shine },
		{ Name = "FlipperR", Shape = BALL, Size = Vector3.new(0.3, 1.3, 0.9), Pos = Vector3.new(1.15, -0.15, 0), Color = body, Reflectance = shine },
		{ Name = "FootL", Size = Vector3.new(0.5, 0.2, 0.78), Pos = Vector3.new(-0.44, -1.35, 0.3), Color = ORANGE },
		{ Name = "FootR", Size = Vector3.new(0.5, 0.2, 0.78), Pos = Vector3.new(0.44, -1.35, 0.3), Color = ORANGE },
	}
	return assemble(name, pieces)
end

--=========================================================
-- 동물 : 토끼
--=========================================================
local function buildBunnyLike(name, opts)
	local body = opts.Body
	local ear = opts.EarTip or opts.Body
	local pieces = {
		{ Name = "Body", Primary = true, Shape = BALL, Size = Vector3.new(2.1, 2.0, 2.3), Pos = Vector3.zero, Color = body },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(1.4, 1.4, 1.4), Pos = Vector3.new(0, 1.1, 0.35), Color = body },
		{ Name = "EarL", Size = Vector3.new(0.36, 1.4, 0.3), Pos = Vector3.new(-0.36, 2.2, 0.2), Color = body, Rot = Vector3.new(-8, 0, -6) },
		{ Name = "EarR", Size = Vector3.new(0.36, 1.4, 0.3), Pos = Vector3.new(0.36, 2.2, 0.2), Color = body, Rot = Vector3.new(-8, 0, 6) },
		{ Name = "EarTipL", Size = Vector3.new(0.34, 0.45, 0.28), Pos = Vector3.new(-0.42, 2.85, 0.15), Color = ear, Rot = Vector3.new(-8, 0, -6) },
		{ Name = "EarTipR", Size = Vector3.new(0.34, 0.45, 0.28), Pos = Vector3.new(0.42, 2.85, 0.15), Color = ear, Rot = Vector3.new(-8, 0, 6) },
		{ Name = "EyeL", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(-0.34, 1.28, 0.94), Color = DARK },
		{ Name = "EyeR", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(0.34, 1.28, 0.94), Color = DARK },
		{ Name = "Nose", Shape = BALL, Size = Vector3.new(0.24, 0.2, 0.2), Pos = Vector3.new(0, 1.06, 1.04), Color = PINK },
		{ Name = "Tail", Shape = BALL, Size = Vector3.new(0.62, 0.62, 0.62), Pos = Vector3.new(0, 0.25, -1.15), Color = opts.Tail or WHITE },
		{ Name = "FootL", Size = Vector3.new(0.42, 0.24, 0.8), Pos = Vector3.new(-0.42, -0.98, 0.3), Color = body },
		{ Name = "FootR", Size = Vector3.new(0.42, 0.24, 0.8), Pos = Vector3.new(0.42, -0.98, 0.3), Color = body },
	}
	local model = assemble(name, pieces)

	-- 무지개 토끼: 등에 무지개 줄무늬
	if opts.Rainbow then
		local rainbow = {
			Color3.fromRGB(255, 138, 138),
			Color3.fromRGB(255, 196, 120),
			Color3.fromRGB(255, 242, 140),
			Color3.fromRGB(152, 226, 160),
			Color3.fromRGB(150, 196, 255),
			Color3.fromRGB(198, 168, 245),
		}
		for index, color in ipairs(rainbow) do
			local stripe = newPart({
				Name = "Stripe" .. index,
				Shape = BALL,
				Size = Vector3.new(0.5, 0.5, 0.5),
				Color = color,
				Material = NEON,
			})
			stripe.CFrame = CFrame.new(0, 1.05 - index * 0.04, 0.65 - index * 0.32)
			stripe.Parent = model
		end
	end
	return model
end

--=========================================================
-- 동물 : 여우 (10단계 NPC)
--=========================================================
function ModelFactory.buildFox()
	local fur = Color3.fromRGB(238, 152, 98)
	local pieces = {
		{ Name = "Body", Primary = true, Shape = BALL, Size = Vector3.new(2.4, 2.2, 3.2), Pos = Vector3.zero, Color = fur },
		{ Name = "Chest", Shape = BALL, Size = Vector3.new(1.5, 1.4, 1.5), Pos = Vector3.new(0, -0.2, 1.1), Color = WHITE },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(1.7, 1.7, 1.7), Pos = Vector3.new(0, 1.05, 1.3), Color = fur },
		{ Name = "Snout", Size = Vector3.new(0.7, 0.55, 0.85), Pos = Vector3.new(0, 0.78, 2.2), Color = WHITE },
		{ Name = "Nose", Shape = BALL, Size = Vector3.new(0.3, 0.28, 0.28), Pos = Vector3.new(0, 0.86, 2.62), Color = DARK },
		{ Name = "EarL", Size = Vector3.new(0.5, 0.85, 0.26), Pos = Vector3.new(-0.58, 1.95, 1.15), Color = fur, Rot = Vector3.new(-10, 0, -10) },
		{ Name = "EarR", Size = Vector3.new(0.5, 0.85, 0.26), Pos = Vector3.new(0.58, 1.95, 1.15), Color = fur, Rot = Vector3.new(-10, 0, 10) },
		{ Name = "EyeL", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(-0.5, 1.25, 2.0), Color = DARK },
		{ Name = "EyeR", Shape = BALL, Size = Vector3.new(0.26, 0.26, 0.26), Pos = Vector3.new(0.5, 1.25, 2.0), Color = DARK },
		{ Name = "TailA", Shape = BALL, Size = Vector3.new(1.2, 1.2, 1.4), Pos = Vector3.new(0, 0.45, -2.0), Color = fur },
		{ Name = "TailB", Shape = BALL, Size = Vector3.new(0.95, 0.95, 1.1), Pos = Vector3.new(0, 0.95, -2.8), Color = fur },
		{ Name = "TailTip", Shape = BALL, Size = Vector3.new(0.7, 0.7, 0.7), Pos = Vector3.new(0, 1.35, -3.35), Color = WHITE },
		{ Name = "WaveArm", Size = Vector3.new(0.42, 1.1, 0.42), Pos = Vector3.new(1.2, -0.25, 0.95), Color = fur },
		{ Name = "ArmL", Size = Vector3.new(0.42, 1.1, 0.42), Pos = Vector3.new(-1.2, -0.25, 0.95), Color = fur },
		{ Name = "LegL", Size = Vector3.new(0.46, 1.0, 0.52), Pos = Vector3.new(-0.85, -1.2, -1.0), Color = fur },
		{ Name = "LegR", Size = Vector3.new(0.46, 1.0, 0.52), Pos = Vector3.new(0.85, -1.2, -1.0), Color = fur },
	}
	return assemble("Fox", pieces)
end

--=========================================================
-- 동물 만들기 (종류 이름으로)
--=========================================================
local builders = {
	Chick = function()
		return buildChickLike("Chick", {
			Body = Color3.fromRGB(255, 233, 128),
			Tuft = Color3.fromRGB(255, 214, 92),
			BeakSize = Vector3.new(0.4, 0.3, 0.55),
		})
	end,
	Duckling = function()
		return buildChickLike("Duckling", {
			Body = Color3.fromRGB(252, 247, 226),
			Wing = Color3.fromRGB(240, 233, 205),
			Tuft = Color3.fromRGB(240, 233, 205),
			BeakSize = Vector3.new(0.8, 0.26, 0.7),
			Scale = 1.05,
		})
	end,
	Penguin = function()
		return buildPenguinLike("Penguin", { Body = Color3.fromRGB(78, 86, 118) })
	end,
	GoldenPenguin = function()
		local model = buildPenguinLike("GoldenPenguin", {
			Body = Color3.fromRGB(255, 205, 74),
			Belly = Color3.fromRGB(255, 240, 190),
			Reflectance = 0.25,
		})
		ModelFactory.addSparkles(model.PrimaryPart, Color3.fromRGB(255, 232, 150), 16)
		return model
	end,
	SnowBunny = function()
		return buildBunnyLike("SnowBunny", {
			Body = Color3.fromRGB(246, 250, 255),
			EarTip = Color3.fromRGB(186, 224, 247),
			Tail = Color3.fromRGB(255, 255, 255),
		})
	end,
	RainbowRabbit = function()
		local model = buildBunnyLike("RainbowRabbit", {
			Body = Color3.fromRGB(255, 244, 250),
			EarTip = Color3.fromRGB(255, 168, 196),
			Tail = Color3.fromRGB(255, 240, 246),
			Rainbow = true,
		})
		ModelFactory.addSparkles(model.PrimaryPart, Color3.fromRGB(255, 190, 230), 18)
		return model
	end,
}

function ModelFactory.buildAnimal(species: string)
	local builder = builders[species]
	if not builder then
		return nil
	end
	local model = builder()
	local info = Config.Animals[species]
	if info and not info.Rare then
		-- 평범한 동물도 멀리서 보이게 작은 반짝임 (3단계)
		ModelFactory.addSparkles(model.PrimaryPart, Color3.fromRGB(255, 252, 220), 5)
	end
	model:SetAttribute("Species", species)
	model:SetAttribute("Lift", ModelFactory.Lift[species] or 1.2)
	return model
end

function ModelFactory.hasSpecies(species: string): boolean
	return builders[species] ~= nil
end

--=========================================================
-- 별 (반짝 별 모양)
--=========================================================
function ModelFactory.buildStar(color: Color3?)
	local starColor = color or Config.Colors.Star
	local pieces = {
		{ Name = "Core", Primary = true, Size = Vector3.new(1.6, 0.46, 0.3), Pos = Vector3.zero, Color = starColor, Material = NEON },
		{ Name = "Cross", Size = Vector3.new(0.46, 1.6, 0.3), Pos = Vector3.zero, Color = starColor, Material = NEON },
		{ Name = "DiagA", Size = Vector3.new(1.1, 0.3, 0.28), Pos = Vector3.zero, Color = starColor, Material = NEON, Rot = Vector3.new(0, 0, 45) },
		{ Name = "DiagB", Size = Vector3.new(1.1, 0.3, 0.28), Pos = Vector3.zero, Color = starColor, Material = NEON, Rot = Vector3.new(0, 0, -45) },
		{ Name = "Middle", Shape = BALL, Size = Vector3.new(0.62, 0.62, 0.62), Pos = Vector3.zero, Color = starColor, Material = NEON },
	}
	return assemble("Star", pieces)
end

--=========================================================
-- 업그레이드 아이콘 (11단계) : 신발 / 기차 / 자석
--=========================================================
local iconBuilders = {
	Speed = function()
		return assemble("ShoeIcon", {
			{ Name = "Sole", Primary = true, Size = Vector3.new(1.8, 0.3, 0.8), Pos = Vector3.zero, Color = WHITE },
			{ Name = "Upper", Shape = BALL, Size = Vector3.new(1.0, 0.85, 0.8), Pos = Vector3.new(-0.32, 0.4, 0), Color = Color3.fromRGB(122, 190, 255) },
			{ Name = "Toe", Shape = BALL, Size = Vector3.new(0.8, 0.6, 0.78), Pos = Vector3.new(0.6, 0.2, 0), Color = WHITE },
			{ Name = "Lace", Size = Vector3.new(0.5, 0.12, 0.6), Pos = Vector3.new(-0.1, 0.72, 0), Color = Color3.fromRGB(255, 240, 160) },
		})
	end,
	Train = function()
		return assemble("TrainIcon", {
			{ Name = "Body", Primary = true, Size = Vector3.new(1.7, 0.9, 0.95), Pos = Vector3.zero, Color = Color3.fromRGB(255, 142, 142) },
			{ Name = "Cabin", Size = Vector3.new(0.65, 0.65, 0.9), Pos = Vector3.new(-0.5, 0.75, 0), Color = Color3.fromRGB(255, 190, 190) },
			{ Name = "Chimney", Shape = CYL, Size = Vector3.new(0.6, 0.38, 0.38), Pos = Vector3.new(0.6, 0.72, 0), Color = Color3.fromRGB(255, 236, 160), Rot = Vector3.new(0, 0, 90) },
			{ Name = "WheelA", Shape = CYL, Size = Vector3.new(0.24, 0.62, 0.62), Pos = Vector3.new(-0.5, -0.52, 0), Color = Color3.fromRGB(96, 104, 132) },
			{ Name = "WheelB", Shape = CYL, Size = Vector3.new(0.24, 0.62, 0.62), Pos = Vector3.new(0.5, -0.52, 0), Color = Color3.fromRGB(96, 104, 132) },
		})
	end,
	Magnet = function()
		return assemble("MagnetIcon", {
			{ Name = "Arch", Primary = true, Size = Vector3.new(1.5, 0.45, 0.5), Pos = Vector3.new(0, 0.75, 0), Color = Color3.fromRGB(255, 122, 122) },
			{ Name = "LegL", Size = Vector3.new(0.45, 1.2, 0.5), Pos = Vector3.new(-0.52, 0.0, 0), Color = Color3.fromRGB(255, 122, 122) },
			{ Name = "LegR", Size = Vector3.new(0.45, 1.2, 0.5), Pos = Vector3.new(0.52, 0.0, 0), Color = Color3.fromRGB(255, 122, 122) },
			{ Name = "TipL", Size = Vector3.new(0.45, 0.35, 0.52), Pos = Vector3.new(-0.52, -0.78, 0), Color = Color3.fromRGB(226, 232, 240) },
			{ Name = "TipR", Size = Vector3.new(0.45, 0.35, 0.52), Pos = Vector3.new(0.52, -0.78, 0), Color = Color3.fromRGB(226, 232, 240) },
		})
	end,
}

function ModelFactory.buildIcon(kind: string)
	local builder = iconBuilders[kind]
	if not builder then
		return nil
	end
	return builder()
end

-- 원점 기준으로 만든 모델의 크기를 바꿉니다 (별 문의 큰 별 등).
function ModelFactory.scaleModel(model: Model, scale: number)
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			local cframe = piece.CFrame
			piece.Size = piece.Size * scale
			piece.CFrame = CFrame.new(cframe.Position * scale) * (cframe - cframe.Position)
		end
	end
	if model.PrimaryPart then
		model.WorldPivot = model.PrimaryPart.CFrame
	end
	return model
end

-- 원점 기준으로 만든 모델을 한 번에 옮깁니다 (장식용).
function ModelFactory.offsetModel(model: Model, position: Vector3, yawDegrees: number?)
	local target = CFrame.new(position)
	if yawDegrees then
		target = target * CFrame.fromEulerAnglesXYZ(0, math.rad(yawDegrees), 0)
	end
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.CFrame = target * piece.CFrame
		end
	end
	return model
end

--=========================================================
-- 섬 장식 (2·7단계)
--=========================================================
function ModelFactory.buildTree(rng: Random)
	local height = rng:NextNumber(5, 8)
	local leaf = rng:NextInteger(1, 2) == 1 and Config.Colors.Leaf or Config.Colors.LeafAlt
	local pieces = {
		{ Name = "Trunk", Primary = true, Shape = CYL, Size = Vector3.new(height, 1.3, 1.3), Pos = Vector3.new(0, height / 2, 0), Color = Config.Colors.Wood, Rot = Vector3.new(0, 0, 90), CastShadow = true, CanCollide = true },
		{ Name = "LeafA", Shape = BALL, Size = Vector3.new(6, 5.2, 6), Pos = Vector3.new(0, height + 1.2, 0), Color = leaf, CastShadow = true },
		{ Name = "LeafB", Shape = BALL, Size = Vector3.new(4.2, 3.8, 4.2), Pos = Vector3.new(1.4, height + 2.6, 0.7), Color = leaf, CastShadow = true },
		{ Name = "LeafC", Shape = BALL, Size = Vector3.new(3.6, 3.2, 3.6), Pos = Vector3.new(-1.5, height + 2.2, -0.6), Color = leaf, CastShadow = true },
	}
	return assemble("Tree", pieces)
end

function ModelFactory.buildPine(rng: Random)
	local height = rng:NextNumber(5, 7.5)
	local pieces = {
		{ Name = "Trunk", Primary = true, Shape = CYL, Size = Vector3.new(height * 0.5, 1.1, 1.1), Pos = Vector3.new(0, height * 0.25, 0), Color = Config.Colors.WoodDark, Rot = Vector3.new(0, 0, 90), CanCollide = true },
		{ Name = "LayerA", Shape = CYL, Size = Vector3.new(1.6, 5.4, 5.4), Pos = Vector3.new(0, height * 0.5, 0), Color = Color3.fromRGB(122, 186, 150), Rot = Vector3.new(0, 0, 90), CastShadow = true },
		{ Name = "LayerB", Shape = CYL, Size = Vector3.new(1.5, 4.0, 4.0), Pos = Vector3.new(0, height * 0.5 + 1.4, 0), Color = Color3.fromRGB(140, 200, 164), Rot = Vector3.new(0, 0, 90), CastShadow = true },
		{ Name = "LayerC", Shape = CYL, Size = Vector3.new(1.4, 2.6, 2.6), Pos = Vector3.new(0, height * 0.5 + 2.7, 0), Color = Config.Colors.Snow, Rot = Vector3.new(0, 0, 90), CastShadow = true },
		{ Name = "Top", Shape = BALL, Size = Vector3.new(1.3, 1.3, 1.3), Pos = Vector3.new(0, height * 0.5 + 3.7, 0), Color = Config.Colors.Snow },
	}
	return assemble("Pine", pieces)
end

function ModelFactory.buildFlower(rng: Random)
	local petals = {
		Color3.fromRGB(255, 176, 200),
		Color3.fromRGB(255, 226, 138),
		Color3.fromRGB(198, 176, 255),
		Color3.fromRGB(180, 226, 255),
	}
	local color = petals[rng:NextInteger(1, #petals)]
	local pieces = {
		{ Name = "Stem", Primary = true, Shape = CYL, Size = Vector3.new(1.3, 0.16, 0.16), Pos = Vector3.new(0, 0.65, 0), Color = Color3.fromRGB(140, 200, 140), Rot = Vector3.new(0, 0, 90) },
		{ Name = "Head", Shape = BALL, Size = Vector3.new(0.85, 0.5, 0.85), Pos = Vector3.new(0, 1.35, 0), Color = color },
		{ Name = "Middle", Shape = BALL, Size = Vector3.new(0.35, 0.4, 0.35), Pos = Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(255, 246, 190) },
	}
	return assemble("Flower", pieces)
end

function ModelFactory.buildRock(rng: Random)
	local size = rng:NextNumber(1.6, 3.4)
	local pieces = {
		{ Name = "RockA", Primary = true, Shape = BALL, Size = Vector3.new(size, size * 0.8, size * 1.1), Pos = Vector3.new(0, size * 0.3, 0), Color = Config.Colors.Rock, CastShadow = true, CanCollide = true },
		{ Name = "RockB", Shape = BALL, Size = Vector3.new(size * 0.6, size * 0.5, size * 0.7), Pos = Vector3.new(size * 0.5, size * 0.15, size * 0.2), Color = Color3.fromRGB(210, 213, 219) },
	}
	return assemble("Rock", pieces)
end

function ModelFactory.buildSnowMound(rng: Random)
	local size = rng:NextNumber(3, 6)
	local pieces = {
		{ Name = "Mound", Primary = true, Shape = BALL, Size = Vector3.new(size, size * 0.55, size), Pos = Vector3.new(0, size * 0.18, 0), Color = Config.Colors.Snow, CastShadow = true },
	}
	return assemble("SnowMound", pieces)
end

return ModelFactory
