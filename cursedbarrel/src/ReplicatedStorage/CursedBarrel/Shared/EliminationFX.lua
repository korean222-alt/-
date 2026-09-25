-- Premium pirate defeat cues. Brief, local-only effects at the eliminated avatar.
-- The pirate's existing lunge supplies the physical attack; these effects add the skin's signature.
local Debris = game:GetService("Debris")
local Tween = game:GetService("TweenService")

local FX = {}

local function anchor(parent, position)
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.CFrame = CFrame.new(position)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.Parent = parent
	return p
end

local function ring(parent, position, color)
	local p = Instance.new("Part")
	p.Name = "DefeatRing"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.08, 1.5, 1.5)
	p.CFrame = CFrame.new(position - Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.35
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Parent = parent
	Tween:Create(p, TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.08, 6.8, 6.8), Transparency = 1,
	}):Play()
end

local function particles(parent, position, color, kind, count)
	local p = anchor(parent, position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(kind == "water" and 2 or 5, kind == "water" and 5 or 11)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = kind == "water" and Vector3.new(0, 9, 0) or Vector3.new(0, 3, 0)
	emitter.Drag = 3
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, kind == "water" and 0.45 or 0.28),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = p
	emitter:Emit(count)
end

local function lightning(parent, hit, color, offset)
	local from = hit + Vector3.new(offset, 8.5, -0.8)
	local points = {
		from,
		hit + Vector3.new(offset - 0.7, 5.7, 0.35),
		hit + Vector3.new(offset + 0.55, 3.1, -0.4),
		hit + Vector3.new(0, 0.4, 0),
	}
	for i = 1, #points - 1 do
		local a = Instance.new("Attachment", anchor(parent, points[i]))
		local b = Instance.new("Attachment", anchor(parent, points[i + 1]))
		local beam = Instance.new("Beam")
		beam.Attachment0 = a
		beam.Attachment1 = b
		beam.Color = ColorSequence.new(color)
		beam.Width0 = i == 1 and 0.16 or 0.26
		beam.Width1 = 0.36
		beam.LightEmission = 1
		beam.FaceCamera = true
		beam.Parent = a.Parent
	end
end

function FX.play(position, skin, reduced)
	if reduced or typeof(position) ~= "Vector3" or not skin then return end
	local id = skin.id
	local kind = ({
		ember = "fire", siren = "water", voidking = "void",
		tide_dragon = "tide", crimson_dragon = "crimson", moon_dragon = "moon",
	})[id]
	if not kind then return end
	local color = skin.aura or Color3.fromRGB(200, 170, 255)
	local folder = Instance.new("Folder")
	folder.Name = "PirateDefeatFX"
	folder.Parent = workspace
	ring(folder, position, color)
	if kind == "fire" or kind == "crimson" then
		particles(folder, position, color, "fire", kind == "crimson" and 24 or 15)
	elseif kind == "water" or kind == "tide" then
		particles(folder, position, color, "water", kind == "tide" and 22 or 15)
	else
		particles(folder, position, color, "spark", kind == "moon" and 18 or 11)
	end
	if kind == "void" or kind == "tide" or kind == "crimson" or kind == "moon" then
		lightning(folder, position, color, 0)
		if kind == "tide" or kind == "crimson" or kind == "moon" then
			lightning(folder, position, skin.accent or color, 1.1)
		end
		for _, child in ipairs(folder:GetDescendants()) do
			if child:IsA("Beam") then
				Tween:Create(child, TweenInfo.new(0.42), { Width0 = 0, Width1 = 0 }):Play()
			end
		end
	end
	Debris:AddItem(folder, 1.6)
end

return FX
