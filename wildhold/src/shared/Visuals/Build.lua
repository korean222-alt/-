-- 파트 조립 도우미. 맵·시설·크리처 모델이 모두 이 함수들로 만들어진다.
-- 기본값: 고정(Anchored), 충돌/터치/쿼리 없음. 충돌이 필요한 파트만 켠다.
local B = {}

local SMOOTH = Enum.SurfaceType.Smooth

function B.hex(value)
	return Color3.fromHex(value)
end

function B.new(className, parent, props)
	local p = Instance.new(className)
	if p:IsA("BasePart") then
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.TopSurface = SMOOTH
		p.BottomSurface = SMOOTH
		p.Material = Enum.Material.SmoothPlastic
	end
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function color(value)
	if typeof(value) == "string" then
		return Color3.fromHex(value)
	end
	return value
end

local function cf(value)
	if typeof(value) == "Vector3" then
		return CFrame.new(value)
	end
	return value
end

function B.block(parent, size, at, col, material, extra)
	local props = {Size = size, CFrame = cf(at), Color = color(col), Material = material or Enum.Material.SmoothPlastic}
	for k, v in pairs(extra or {}) do props[k] = v end
	return B.new("Part", parent, props)
end

function B.ball(parent, diameter, at, col, material, extra)
	local props = {Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, CFrame = cf(at), Color = color(col),
		Material = material or Enum.Material.SmoothPlastic}
	for k, v in pairs(extra or {}) do props[k] = v end
	return B.new("Part", parent, props)
end

-- 원기둥: 길이 방향은 파트의 X 축. upright=true 면 세로로 세운다.
function B.cyl(parent, length, diameter, at, col, material, upright, extra)
	local frame = cf(at)
	if upright then
		frame = frame * CFrame.Angles(0, 0, math.rad(90))
	end
	local props = {Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), CFrame = frame,
		Color = color(col), Material = material or Enum.Material.SmoothPlastic}
	for k, v in pairs(extra or {}) do props[k] = v end
	return B.new("Part", parent, props)
end

-- 타원체: 파트 크기 그대로의 구 메쉬. 동글동글한 크리처와 나무 수관에 쓴다.
function B.ellipsoid(parent, size, at, col, material, extra)
	local p = B.block(parent, size, at, col, material, extra)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function B.wedge(parent, size, at, col, material, extra)
	local props = {Size = size, CFrame = cf(at), Color = color(col), Material = material or Enum.Material.SmoothPlastic}
	for k, v in pairs(extra or {}) do props[k] = v end
	return B.new("WedgePart", parent, props)
end

-- 삼각기둥 (말뚝 끝, 박공지붕, 가시). 밑변 중심이 at, 능선은 로컬 X 방향, 폭은 로컬 Z 방향.
-- WedgePart 는 수직면이 +Z, 경사면이 -Z 쪽을 본다 → 두 개를 등지게 붙인다.
function B.spike(parent, width, depth, height, at, col, material)
	local base = cf(at)
	local half = width / 2
	local size = Vector3.new(depth, height, half)
	local a = B.wedge(parent, size, base * CFrame.new(0, height / 2, -half / 2), col, material)
	local b = B.wedge(parent, size, base * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.pi, 0), col, material)
	return a, b
end

-- 원뿔 비슷한 지붕/뿔: 얇은 원판을 점점 작게 쌓는다. 밑면 중심이 at.
function B.cone(parent, diameter, height, at, col, material, steps)
	local base = cf(at)
	steps = steps or 5
	local parts = {}
	for i = 0, steps - 1 do
		local t = i / steps
		local d = diameter * (1 - t) + 0.15
		parts[#parts + 1] = B.cyl(parent, height / steps + 0.02, d, base * CFrame.new(0, height * (t + 0.5 / steps), 0), col, material, true)
	end
	return parts
end

function B.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function B.light(parent, kind, props)
	local l = Instance.new(kind or "PointLight")
	for k, v in pairs(props or {}) do l[k] = v end
	l.Parent = parent
	return l
end

function B.hitbox(parent, size, at, collide)
	return B.new("Part", parent, {Name = "Hitbox", Size = size, CFrame = cf(at), Transparency = 1,
		CanCollide = collide == true, CanQuery = true, CastShadow = false})
end

-- 몸이 뚫고 지나가면 안 되는 파트 (기둥·벽·바위·울타리). 광선 검사(CanQuery)는 그대로 둔다.
function B.solid(...)
	for i = 1, select("#", ...) do
		local p = select(i, ...)
		if typeof(p) == "Instance" then
			p.CanCollide = true
		end
	end
	return ...
end

-- 이 모델 안 모든 파트의 그림자/충돌 설정을 한 번에
function B.decorate(model, castShadow)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Hitbox" then
			d.CastShadow = castShadow ~= false
		end
	end
	return model
end

function B.jitter(rng, amount)
	return (rng:NextNumber() - 0.5) * 2 * amount
end

return B
