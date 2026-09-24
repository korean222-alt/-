--[[
	KrakenController  (Phase 10 · Phase 12 에서 살아 움직이게 됨)
	배를 삼키려는 크라켄을 내 화면에만 세우고 움직인다.

	· 모양은 KrakenLayout, 과녁 · 내려치기 궤적은 KrakenTargets 가 정한다. 여기서는 파트를 만들고 옮기기만 한다.
	· 전부 장식이다. 부딪히지 않고(CanCollide/CanTouch), 카메라 · 레이캐스트에도 걸리지 않는다(CanQuery).

	Phase 12
	  · 시각을 서버 시계(GetServerTimeNow)로 맞춘다. 그래서 대포 과녁이 서버 판정과 같은 자리에 있다.
	  · 날씨에 따라 날뛴다 : 평소 1 → 밤 · 안개 1.2 → 폭풍 1.6 → 습격 2.2 (KrakenTargets.agitation)
	  · 다리마다 빛나는 약점(대포 과녁). 대포에 맞으면 그 다리가 움찔한다. 눈에 맞으면 눈을 질끈 감는다.
	  · 습격 : 머리가 떠오르고 눈이 붉어진다. 거대한 다리가 치켜들렸다가 갑판을 "쾅" 내려친다.
	    파편 · 물보라 · 충격파 · 화면 흔들림 · 소리. 대포로 막으면 움찔 물러나 바다로 빠진다.
	  · 물리치면 머리가 물속으로 가라앉는다.

	성능
	  · 효과 품질 "낮음"(모바일 기본)이면 마디를 줄이고 빨판을 빼고 10Hz 로만 움직인다. (습격 중에는 20Hz)
	  · "번쩍임 · 연출 줄이기"를 켜면 쉬는 다리는 멈춘다. 내려치기는 보이되 파편을 줄인다.
	  · 테이블에서 게임 중(검은 개인 무대 안)이면 다리를 움직이지 않는다. 내려치기의 소리 · 흔들림만 전한다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local package = ReplicatedStorage:WaitForChild("CursedBarrel")
local Shared = package:WaitForChild("Shared")
local K = require(Shared:WaitForChild("KrakenLayout"))
local T = require(Shared:WaitForChild("KrakenTargets"))
local FX = require(Shared:WaitForChild("PremiumFX"))
local CameraShake = require(Shared:WaitForChild("CameraShake"))
local Sfx = require(Shared:WaitForChild("Sfx"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MeshKit = require(Shared:WaitForChild("MeshKit")) -- Phase 15 : Blender 머리 · 마디 · 빨판 · 누운 다리
local remotes = package:WaitForChild("Remotes")
local worldCue = remotes:WaitForChild(GameConfig.Remotes.WorldCue)
local cannonCue = remotes:WaitForChild(GameConfig.Remotes.CannonCue)

local player = Players.LocalPlayer
local COLORS = K.Colors
local RAID_IRIS = Color3.fromRGB(255, 40, 60)
local BULB = Color3.fromRGB(255, 140, 60)
local BULB_RAID = Color3.fromRGB(255, 70, 160)

local folder = nil
local arms = {} -- { spec, count, tube, normal, sign, faded, bulb, flinchUntil }
local resting = {} -- Phase 15 : 갑판에 누운 다리 (한 번 세우고 움직이지 않는다)
local head = nil
local animate = true
local interval = 1 / 30
local quality = "High"

local amp = 1 -- 지금 날뛰는 정도 (목표값으로 천천히 옮겨 간다)
local rise = 0 -- 머리가 떠오른 정도
local sinkUntil = 0 -- 물리친 뒤 머리가 가라앉는 동안

local moveParts = {}
local moveFrames = {}

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function reduced()
	return player:GetAttribute("Setting_reducedFX") == true
end

--------------------------------------------------
-- 파트
--------------------------------------------------

local function part(parent, name, shape, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Parent = parent
	return p
end

-- 원통의 긴 축(X)이 a → b 를 향하는 CFrame
local function along(a, b)
	local mid = (a + b) * 0.5
	if (b - a).Magnitude < 1e-4 then
		return CFrame.new(mid)
	end
	return CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
end

-- 원판(원통)의 축(X)이 n 을 향하는 CFrame
local function facing(position, n)
	return CFrame.lookAt(position, position + n) * CFrame.Angles(0, math.rad(90), 0)
end

--------------------------------------------------
-- 다리 (Phase 14 : 진짜 문어 다리처럼)
--   · 마디를 촘촘히 하고, 뿌리(어두운 자주) → 끝(붉은 분홍)으로 색이 부드럽게 바뀐다. (줄무늬 없음)
--   · 안쪽(빨판 쪽)은 밝은 배 살이 길게 드러난다.
--   · 빨판은 테두리 + 오목한 속 두 겹이고, 두 줄로 엇갈려 붙으며 끝으로 갈수록 작아진다.
--   · 끝은 위로 말려 올라간다. (연출만. 서버 판정 · 겹침 검사는 KrakenLayout 곡선 그대로다)
--   · 젖은 살결처럼 살짝 반사한다.
--------------------------------------------------

local WET = 0.06
local CURL_FROM = 0.8 -- 다리 길이의 이 지점부터 말린다
local CURL_ANGLE = math.rad(240)

local function skinAt(u)
	u = math.clamp(u, 0, 1)
	if u < 0.5 then
		return COLORS.SkinDark:Lerp(COLORS.Skin, u / 0.5)
	end
	return COLORS.Skin:Lerp(COLORS.Tip, (u - 0.5) / 0.5)
end

-- 곡선 위 index 번째 점에서 안쪽(빨판 쪽) 방향. normal 은 다리가 놓인 평면의 법선.
local function innerAt(points, index, normal, sign)
	local a = points[math.max(index - 1, 1)]
	local b = points[math.min(index + 1, #points)]
	local t = b - a
	if t.Magnitude < 1e-4 then
		return Vector3.new(0, -1, 0)
	end
	local inner = normal:Cross(t.Unit) * sign
	if inner.Magnitude < 1e-4 then
		return Vector3.new(0, -1, 0)
	end
	return inner.Unit
end

-- 굵기 목록대로 관 하나를 세운다. detailed 면 배 살 · 빨판까지 붙인다.
-- Phase 15 : Blender 마디 · 빨판 메시가 있으면 원통 · 원판 대신 그것을 쓴다 (모양이 더 살아 있고 파트도 줄어든다)
local function meshPiece(model, name, pieceName, size, color)
	local piece = MeshKit.place(pieceName, nil, { parent = model, name = name, color = color, material = Enum.Material.SmoothPlastic })
	if piece then
		piece.Size = size
		piece.Locked = true
	end
	return piece
end

local function buildTube(model, radii, detailed)
	local count = #radii
	local tube = { joints = {}, segs = {}, bellies = {}, suckers = {}, radii = radii, parts = {} }
	local meshed = MeshKit.has("KrakenPieces")
	for i = 1, count do
		local u = (i - 1) / (count - 1)
		local r = radii[i]
		local joint = part(model, "Joint", Enum.PartType.Ball, Vector3.new(r * 2, r * 2, r * 2), skinAt(u))
		joint.Reflectance = WET
		tube.joints[i] = joint
		table.insert(tube.parts, joint)
		if i > 1 then
			local d = r + radii[i - 1]
			local color = skinAt(u - 0.5 / (count - 1))
			local seg = meshed and meshPiece(model, "Segment", "CB_Kraken_Segment", Vector3.new(1, d, d), color)
				or part(model, "Segment", Enum.PartType.Cylinder, Vector3.new(1, d, d), color)
			seg.Reflectance = WET
			tube.segs[i - 1] = seg
			table.insert(tube.parts, seg)
			if detailed then
				local bd = d * 0.8
				local belly = part(model, "Belly", Enum.PartType.Cylinder, Vector3.new(1, bd, bd), COLORS.Belly:Lerp(color, 0.2))
				belly.Reflectance = WET
				tube.bellies[i - 1] = belly
				table.insert(tube.parts, belly)
			end
		end
		if detailed and u >= 0.3 and u <= 0.97 and i < count then
			local rim = meshed and meshPiece(model, "Sucker", "CB_Kraken_Sucker", Vector3.new(0.2, r * 0.74, r * 0.74), COLORS.Sucker)
			if rim then
				table.insert(tube.suckers, { rim = rim, index = i, row = (i % 2 == 0) and 1 or -1 })
				table.insert(tube.parts, rim)
			else
				rim = part(model, "Sucker", Enum.PartType.Cylinder, Vector3.new(0.14, r * 0.7, r * 0.7), COLORS.Sucker)
				local cup = part(model, "SuckerCup", Enum.PartType.Cylinder, Vector3.new(0.16, r * 0.36, r * 0.36), COLORS.SuckerCup)
				table.insert(tube.suckers, { rim = rim, cup = cup, index = i, row = (i % 2 == 0) and 1 or -1 })
				table.insert(tube.parts, rim)
				table.insert(tube.parts, cup)
			end
		end
	end
	return tube
end

-- 관을 점들에 맞춰 옮긴다 (BulkMoveTo 에 쌓아 두기만 한다)
-- given (Phase 15) : 빨판 방향을 미리 정해 준 경우 (누운 다리)
local function placeTube(tube, points, normal, sign, given)
	local count = #points
	local inners = {}
	for i = 1, count do
		inners[i] = (given and given[i]) or innerAt(points, i, normal, sign)
	end
	for i = 1, count do
		local p = points[i]
		table.insert(moveParts, tube.joints[i])
		table.insert(moveFrames, CFrame.new(p))
		local seg = tube.segs[i - 1]
		if seg then
			local a = points[i - 1]
			local length = (p - a).Magnitude * 1.06
			if math.abs(seg.Size.X - length) > 0.08 then
				seg.Size = Vector3.new(length, seg.Size.Y, seg.Size.Z)
			end
			table.insert(moveParts, seg)
			table.insert(moveFrames, along(a, p))
			local belly = tube.bellies[i - 1]
			if belly then
				local inner = inners[i] + inners[i - 1]
				inner = inner.Magnitude > 1e-4 and inner.Unit or inners[i]
				local off = inner * (seg.Size.Y * 0.16)
				if math.abs(belly.Size.X - length) > 0.08 then
					belly.Size = Vector3.new(length, belly.Size.Y, belly.Size.Z)
				end
				table.insert(moveParts, belly)
				table.insert(moveFrames, along(a + off, p + off))
			end
		end
	end
	for _, sucker in ipairs(tube.suckers) do
		local i = sucker.index
		local r = tube.radii[i]
		local inner = inners[i]
		local side = normal * sucker.row
		local face = inner + side * 0.35
		face = face.Magnitude > 1e-4 and face.Unit or inner
		local at = points[i] + inner * r + side * (r * 0.42)
		table.insert(moveParts, sucker.rim)
		table.insert(moveFrames, facing(at, face))
		if sucker.cup then
			table.insert(moveParts, sucker.cup)
			table.insert(moveFrames, facing(at + face * 0.04, face))
		end
	end
end

-- 다리 끝을 빨판 반대쪽(쉬는 끝에서는 위쪽)으로 돌돌 만다. 길이는 그대로 둔다.
local function curlTip(points, normal, sign)
	local n = #points
	local k = math.floor((n - 1) * CURL_FROM) + 1
	if k < 2 or k >= n - 1 then
		return points
	end
	local d = points[k] - points[k - 1]
	if d.Magnitude < 1e-4 then
		return points
	end
	d = d.Unit
	local up = -innerAt(points, k, normal, sign)
	up -= d * up:Dot(d)
	if up.Magnitude < 1e-4 then
		return points
	end
	up = up.Unit
	local lengths, total = {}, 0
	for j = k + 1, n do
		lengths[j] = (points[j] - points[j - 1]).Magnitude
		total += lengths[j]
	end
	if total < 1e-3 then
		return points
	end
	local out = table.clone(points)
	local walked = 0
	local position = points[k]
	for j = k + 1, n do
		local theta = CURL_ANGLE * ((walked + lengths[j] * 0.5) / total) ^ 1.7
		position += (d * math.cos(theta) + up * math.sin(theta)) * lengths[j]
		out[j] = position
		walked += lengths[j]
	end
	return out
end

local function buildArm(spec, index)
	local count = K.Samples[quality] or K.Samples.High
	local model = Instance.new("Model")
	model.Name = spec.name
	model.Parent = folder

	local samples = K.sample(spec, nil, count)
	local root = spec.waypoints[1].p
	local radii = {}
	for i, s in ipairs(samples) do
		radii[i] = s.r
	end
	local tube = buildTube(model, radii, quality == "High")
	local arm = {
		spec = spec,
		index = index,
		count = count,
		model = model,
		tube = tube,
		normal = K.planeNormal(spec),
		sign = K.innerSign(spec, count),
		faded = false,
		parts = tube.parts,
		flinchUntil = 0,
		outward = Vector3.new(root.X, 0, root.Z).Magnitude > 1 and Vector3.new(root.X, 0, root.Z).Unit or Vector3.new(1, 0, 0),
	}

	-- Phase 12 : 빛나는 약점 (대포 과녁). 서버가 판정에 쓰는 바로 그 점에 있다.
	local bulb = part(model, "WeakSpot", Enum.PartType.Ball, Vector3.new(3.6, 3.6, 3.6), BULB, Enum.Material.Neon)
	bulb.Transparency = 0.15
	local glow = Instance.new("PointLight")
	glow.Color = BULB
	glow.Range = 10
	glow.Brightness = 1.2
	glow.Shadows = false
	glow.Parent = bulb
	arm.bulb = bulb
	arm.bulbLight = glow

	for i = 2, #samples do
		local a, b = samples[i - 1], samples[i]
		if a.p.Y < K.SeaY and b.p.Y >= K.SeaY then
			local alpha = (K.SeaY - a.p.Y) / math.max(b.p.Y - a.p.Y, 1e-3)
			local at = a.p:Lerp(b.p, alpha)
			local width = (a.r + (b.r - a.r) * alpha) * 2 + 3
			local foam = part(model, "Foam", Enum.PartType.Cylinder, Vector3.new(0.2, width, width), COLORS.Foam)
			foam.CFrame = CFrame.new(at.X, K.SeaY + 0.42, at.Z) * CFrame.Angles(0, 0, math.rad(90))
			foam.Transparency = 0.45
			arm.foam = foam
			break
		end
	end

	return arm
end

local function queueArm(arm, t, now)
	local samples = K.sample(arm.spec, t, arm.count, amp)
	-- 대포에 맞아 움찔한다 : 끝으로 갈수록 크게 바깥 · 위로 튄다
	local flinch = math.clamp((arm.flinchUntil - now) / 0.45, 0, 1)
	if flinch > 0 then
		local kick = arm.outward * 2.4 + Vector3.new(0, 1.8, 0)
		for _, s in ipairs(samples) do
			if s.u > 0.15 and s.p.Y > K.SeaY then
				s.p = s.p + kick * (flinch * s.u)
			end
		end
	end
	local points = {}
	for i, s in ipairs(samples) do
		points[i] = s.p
	end
	points = curlTip(points, arm.normal, arm.sign)
	for i, s in ipairs(samples) do
		s.p = points[i]
	end
	placeTube(arm.tube, points, arm.normal, arm.sign)
	return samples
end

-- 약점은 서버 판정과 같은 자리에 둔다. (연출을 줄여 다리가 멈춰 있어도 약점은 서버 시계를 따라간다)
local function queueBulb(arm, now, clock)
	if not arm.bulb then
		return
	end
	local target = K.waypointsAt(arm.spec, now, amp)[T.WeakPoint]
	local flinch = math.clamp((arm.flinchUntil - clock) / 0.45, 0, 1)
	if flinch > 0 then
		-- 약점은 3번째 점이다. 곡선 위치(u)는 대략 0.3
		target += (arm.outward * 2.4 + Vector3.new(0, 1.8, 0)) * (flinch * 0.3)
	end
	table.insert(moveParts, arm.bulb)
	table.insert(moveFrames, CFrame.new(target))
end

local function fadeArm(arm, samples, cameraPosition)
	local near = false
	for _, s in ipairs(samples) do
		if (s.p - cameraPosition).Magnitude < s.r + 7 then
			near = true
			break
		end
	end
	if near ~= arm.faded then
		arm.faded = near
		for _, p in ipairs(arm.parts) do
			p.LocalTransparencyModifier = near and 0.7 or 0
		end
	end
end

--------------------------------------------------
-- 머리
--------------------------------------------------

local function buildHead()
	local spec = K.Head
	local model = Instance.new("Model")
	model.Name = "KrakenHead"
	model.Parent = folder

	local h = { model = model, eyes = {} }
	-- Phase 15 : Blender 머리(울퉁불퉁한 살 · 성난 눈썹 · 눈 둘레)가 있으면 그것 하나로 두 공을 대신한다
	local mantle = MeshKit.place("CB_Kraken_Mantle", CFrame.new(), { parent = model, name = "Mantle", color = COLORS.Skin, material = Enum.Material.SmoothPlastic, reflectance = WET })
	if mantle then
		mantle.Locked = true
		h.low = mantle
		h.lowOffset = CFrame.new(MeshKit.Catalog.Pieces.CB_Kraken_Mantle.center)
	else
		h.low = part(model, "Mantle", Enum.PartType.Ball, Vector3.new(spec.mantle, spec.mantle, spec.mantle), COLORS.Skin)
		local back = spec.mantle * 0.8
		h.high = part(model, "MantleTop", Enum.PartType.Ball, Vector3.new(back, back, back), COLORS.SkinDark)
		h.low.Reflectance = WET
		h.high.Reflectance = WET
	end
	h.highOffset = Vector3.new(0, spec.mantle * 0.2, 0)
	h.highBack = spec.mantle * 0.16

	local foamWidth = spec.mantle * 0.95
	local foam = part(model, "Foam", Enum.PartType.Cylinder, Vector3.new(0.2, foamWidth, foamWidth), COLORS.Foam)
	foam.CFrame = CFrame.new(spec.center.X, K.SeaY + 0.42, spec.center.Z) * CFrame.Angles(0, 0, math.rad(90))
	foam.Transparency = 0.55

	for _, side in ipairs({ -1, 1 }) do
		local eye = { side = side }
		eye.white = part(model, "EyeWhite", Enum.PartType.Ball, Vector3.new(spec.eye, spec.eye, spec.eye), COLORS.EyeWhite)
		eye.iris = part(model, "Iris", Enum.PartType.Ball, Vector3.new(spec.eye * 0.72, spec.eye * 0.72, spec.eye * 0.72), COLORS.Iris, Enum.Material.Neon)
		eye.pupil = part(model, "Pupil", nil, Vector3.new(spec.eye * 0.13, spec.eye * 0.6, spec.eye * 0.1), COLORS.Pupil)
		eye.brow = part(model, "Brow", Enum.PartType.Ball, Vector3.new(spec.eye * 1.3, spec.eye * 1.3, spec.eye * 1.3), COLORS.SkinDark)
		eye.lid = part(model, "Lid", Enum.PartType.Ball, Vector3.new(spec.eye * 1.25, spec.eye * 1.25, spec.eye * 1.25), COLORS.Skin)
		table.insert(h.eyes, eye)
	end

	h.blinkAt = os.clock() + 4
	h.squintUntil = 0
	return h
end

local function queueHead(h, t, cameraPosition, raid)
	local spec = K.Head
	-- 머리 자리 : 서버의 눈 과녁과 같은 식 (KrakenTargets.headBasis)
	local sink = math.clamp((sinkUntil - os.clock()) / 6, 0, 1)
	local center, look, right, up = T.headBasis(t, rise - 12 * sink)
	local frame = CFrame.fromMatrix(center, right, up, -look)

	table.insert(moveParts, h.low)
	table.insert(moveFrames, h.lowOffset and (frame * h.lowOffset) or frame)
	if h.high then
		table.insert(moveParts, h.high)
		table.insert(moveFrames, CFrame.new(center + h.highOffset - look * h.highBack))
	end

	-- 눈꺼풀 : 몇 초에 한 번 느리게 감는다. 눈에 맞으면 질끈 감는다.
	local blink = 0
	local now = os.clock()
	if t then
		if now > h.blinkAt + 0.45 then
			h.blinkAt = now + 5 + math.random() * 4
		end
		local phase = (now - h.blinkAt) / 0.45
		if phase >= 0 and phase <= 1 then
			blink = math.sin(phase * math.pi)
		end
	end
	if now < h.squintUntil then
		blink = math.max(blink, 0.9)
	end
	blink = math.max(blink, sink)

	local irisColor = raid and RAID_IRIS or COLORS.Iris
	for _, eye in ipairs(h.eyes) do
		if eye.iris.Color ~= irisColor then
			eye.iris.Color = irisColor
		end
		local center3 = center + right * (eye.side * spec.eyeSpread) + up * spec.eyeRise + look * spec.eyeForward
		local rest = look
		local lookAt = rest
		if cameraPosition then
			local toCamera = cameraPosition - center3
			if toCamera.Magnitude > 1 then
				toCamera = toCamera.Unit
				local angle = math.acos(math.clamp(toCamera:Dot(rest), -1, 1))
				local limit = math.rad(40)
				if angle <= limit then
					lookAt = toCamera
				else
					local axis = rest:Cross(toCamera)
					if axis.Magnitude > 1e-4 then
						lookAt = (CFrame.fromAxisAngle(axis.Unit, limit) * rest).Unit
					end
				end
			end
		end
		local worldUp = Vector3.new(0, 1, 0)
		table.insert(moveParts, eye.white)
		table.insert(moveFrames, CFrame.new(center3))
		table.insert(moveParts, eye.brow)
		-- 습격 때는 눈썹이 내려와 노려본다
		table.insert(moveFrames, CFrame.new(center3 + worldUp * (spec.eye * (raid and 0.3 or 0.42)) - rest * (spec.eye * 0.12)))
		table.insert(moveParts, eye.iris)
		table.insert(moveFrames, CFrame.new(center3 + lookAt * (spec.eye * 0.2)))
		table.insert(moveParts, eye.pupil)
		table.insert(moveFrames, CFrame.lookAt(center3 + lookAt * (spec.eye * 0.57), center3 + lookAt * (spec.eye * 2), worldUp))
		table.insert(moveParts, eye.lid)
		table.insert(moveFrames, CFrame.new(center3 + worldUp * (spec.eye * 0.62 * (1 - blink)) - rest * (spec.eye * 0.02)))
	end
end

--------------------------------------------------
-- 내려치는 다리 (습격)
--------------------------------------------------
local slams = {} -- [id] = { data, model, tube, count, impacted, bulb }
local SLAM_COUNT = 22

local function slamRadius(u)
	return 0.6 + (3.6 - 0.6) * (1 - u) ^ 1.1
end

local function buildSlam(data)
	local count = (quality == "Low") and 12 or SLAM_COUNT
	local model = Instance.new("Model")
	model.Name = "SlamTentacle_" .. tostring(data.id)
	model.Parent = folder
	local radii = {}
	for i = 1, count do
		radii[i] = slamRadius((i - 1) / (count - 1))
	end
	local slam = { data = data, model = model, tube = buildTube(model, radii, quality == "High"), count = count, impacted = false }
	-- 치켜든 다리 끝에도 약점이 빛난다 (여기를 맞히면 막는다)
	slam.bulb = part(model, "SlamWeakSpot", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), BULB_RAID, Enum.Material.Neon)
	slams[data.id] = slam
	return slam
end

local function splinters(at, count)
	for i = 1, count do
		local p = part(workspace, "Splinter", nil, Vector3.new(0.25, 0.25, 0.9 + math.random() * 1.2), Color3.fromRGB(118, 78, 44), Enum.Material.Wood)
		p.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		local fly = Vector3.new((math.random() - 0.5) * 16, 6 + math.random() * 8, (math.random() - 0.5) * 16)
		local peak = at + fly * 0.6
		local land = Vector3.new(at.X + fly.X, K.DeckTop + 0.2, at.Z + fly.Z)
		TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(peak) * CFrame.Angles(math.random() * 6, math.random() * 6, 0) }):Play()
		task.delay(0.3, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(land) * CFrame.Angles(0, math.random() * 6, math.pi / 2) }):Play()
			end
		end)
		task.delay(1.6, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(p, 2.3)
	end
end

local function splashColumn(at, height)
	for i = 1, 7 do
		local p = part(workspace, "Splash", Enum.PartType.Ball, Vector3.new(2, 2, 2), COLORS.Foam, Enum.Material.SmoothPlastic)
		p.Transparency = 0.25
		local offset = Vector3.new((math.random() - 0.5) * 5, 0, (math.random() - 0.5) * 5)
		p.CFrame = CFrame.new(at + offset)
		TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(at + offset + Vector3.new(0, height * (0.6 + math.random() * 0.4), 0)),
			Size = Vector3.new(3.2, 3.2, 3.2),
			Transparency = 1,
		}):Play()
		Debris:AddItem(p, 0.6)
	end
end

local function impact(slam, inStage)
	local hit = T.slamPoints(slam.data)
	Sfx.play("Slam", { at = hit, volume = 1, range = 320 })
	Sfx.play("WoodCrack", { at = hit, volume = 0.8, pitch = 0.9 + math.random() * 0.2 })
	if inStage then
		-- 테이블 게임 중에는 배가 맞은 것만 느낄 만큼 약하게 (잡기 타이밍을 방해하지 않게)
		CameraShake.add(0.3, 0.5, 0.6)
		return
	end
	CameraShake.at(hit, 1.3, 0.9, 150, 2.6)
	-- 충격파 고리
	local ring = part(workspace, "SlamShock", Enum.PartType.Cylinder, Vector3.new(0.12, 2, 2), Color3.fromRGB(255, 240, 220), Enum.Material.Neon)
	ring.CFrame = CFrame.new(hit + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.04, 26, 26), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.55)
	-- 먼지
	local dust = part(workspace, "SlamDust", nil, Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1))
	dust.Transparency = 1
	dust.CFrame = CFrame.new(hit)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 130, 110))
	emitter.Size = NumberSequence.new(2, 6)
	emitter.Transparency = NumberSequence.new(0.4, 1)
	emitter.Lifetime = NumberRange.new(0.8, 1.3)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Rate = 0
	emitter.Parent = dust
	emitter:Emit(reduced() and 6 or 24)
	Debris:AddItem(dust, 1.6)
	splinters(hit + Vector3.new(0, 0.5, 0), reduced() and 4 or 14)
	-- 뱃전 밖으로 물보라
	local half = math.abs(hit.X) + (GameConfig.Raid.SlamInset or 9)
	splashColumn(Vector3.new(slam.data.side * (half + 3), K.SeaY, slam.data.z), 16)
end

local function inkBurst(at)
	for i = 1, (reduced() and 4 or 12) do
		local p = part(workspace, "Ink", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(40, 16, 50), Enum.Material.SmoothPlastic)
		p.CFrame = CFrame.new(at)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(at + dir * (4 + math.random() * 4)),
			Size = Vector3.new(0.3, 0.3, 0.3),
			Transparency = 1,
		}):Play()
		Debris:AddItem(p, 0.55)
	end
end

local function queueSlam(slam, now, inStage)
	local data = slam.data
	local tip, phase = T.slamTip(data, now)
	if not tip then
		if now > data.at then
			slam.model:Destroy()
			slams[data.id] = nil
		end
		return
	end
	if not slam.impacted and not data.blockedAt and now >= data.at then
		slam.impacted = true
		impact(slam, inStage)
	end
	if inStage then
		return
	end
	-- 다리가 놓인 평면은 배의 옆(x)과 위(y). 빨판은 아래(갑판)를 본다.
	placeTube(slam.tube, T.slamSpine(data, tip, slam.count), Vector3.new(0, 0, 1), data.side)
	local blockable = T.slamBlockable(data, now)
	slam.bulb.Transparency = blockable and (0.1 + 0.3 * math.abs(math.sin(now * 10))) or 1
	table.insert(moveParts, slam.bulb)
	table.insert(moveFrames, CFrame.new(tip))
	-- 치켜드는 동안 끝이 부르르 떤다 (이제 내려친다는 신호)
	if phase == "rise" and not slam.warned and now > data.at - 0.7 then
		slam.warned = true
		Sfx.play("KrakenRoar", { at = tip, volume = 0.45, pitch = 1.4 })
	end
end

--------------------------------------------------
-- 세우기 · 움직이기
--------------------------------------------------

local function flush()
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	table.clear(moveParts)
	table.clear(moveFrames)
end

local function currentQuality()
	return FX.quality() == "Low" and "Low" or "High"
end

-- Phase 15 : 갑판에 가로로 누운 다리. Blender 모델이 있으면 통째로 한 번 놓고, 없으면 같은 곡선으로 파트를 세운다.
local function buildResting(spec)
	local model = Instance.new("Model")
	model.Name = spec.name
	model.Parent = folder
	local made = MeshKit.build(spec.name, nil, { parent = model, material = Enum.Material.SmoothPlastic, reflectance = WET }, {
		["CB_" .. spec.name:gsub("^Rest_", "KrakenRest_") .. "_Skin"] = { color = COLORS.Skin },
		["CB_" .. spec.name:gsub("^Rest_", "KrakenRest_") .. "_Belly"] = { color = COLORS.Belly },
		["CB_" .. spec.name:gsub("^Rest_", "KrakenRest_") .. "_Suckers"] = { color = COLORS.Sucker },
	})
	if made then
		for _, piece in ipairs(made) do
			piece.Locked = true
		end
		return { model = model, parts = made }
	end
	local samples = K.restingSample(spec, K.Samples[quality] or K.Samples.High)
	local radii, points, inners = {}, {}, {}
	for i, s in ipairs(samples) do
		radii[i], points[i], inners[i] = s.r, s.p, s.inner
	end
	local tube = buildTube(model, radii, quality == "High")
	placeTube(tube, points, Vector3.new(0, 0, 1), 1, inners)
	return { model = model, parts = tube.parts }
end

local function build()
	if folder then
		folder:Destroy()
	end
	table.clear(arms)
	table.clear(slams)
	folder = Instance.new("Folder")
	folder.Name = "CursedBarrel_Kraken"

	quality = currentQuality()
	animate = not reduced()
	interval = quality == "Low" and (1 / 10) or (1 / 30)

	for index, spec in ipairs(K.Arms) do
		local ok, arm = pcall(buildArm, spec, index)
		if ok then
			table.insert(arms, arm)
		else
			warn("[CursedBarrel] 크라켄 다리를 세우지 못했습니다: " .. tostring(arm))
		end
	end
	local ok, built = pcall(buildHead)
	head = ok and built or nil
	table.clear(resting)
	for _, spec in ipairs(K.Resting or {}) do
		local restOk, rest = pcall(buildResting, spec)
		if restOk then
			table.insert(resting, rest)
		else
			warn("[CursedBarrel] 누운 크라켄 다리를 세우지 못했습니다: " .. tostring(rest))
		end
	end

	local t = serverNow()
	for _, arm in ipairs(arms) do
		queueArm(arm, animate and t or nil, os.clock())
		queueBulb(arm, t, os.clock())
	end
	if head then
		queueHead(head, animate and t or nil, nil, false)
	end
	folder.Parent = workspace
	flush()
end

local function insidePrivateStage()
	local effects = workspace:FindFirstChild("CursedBarrel_LocalEffects")
	return effects ~= nil and effects:FindFirstChild("PrivateTableStage") ~= nil
end

build()

local rebuildQueued = false
local function queueRebuild()
	if rebuildQueued then
		return
	end
	rebuildQueued = true
	task.delay(0.3, function()
		rebuildQueued = false
		build()
	end)
end
player:GetAttributeChangedSignal("Setting_quality"):Connect(queueRebuild)
player:GetAttributeChangedSignal("Setting_reducedFX"):Connect(queueRebuild)
-- Phase 15 : Blender 모델 보관함이 늦게 도착하면(서버가 옮긴 직후) 한 번 다시 세운다
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == MeshKit.LibraryName then
		queueRebuild()
	end
end)

--------------------------------------------------
-- 서버 알림 : 내려치기 · 막기 · 대포 명중 · 습격 결과
--------------------------------------------------
worldCue.OnClientEvent:Connect(function(kind, data)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "Slam" and data.id and not slams[data.id] and folder then
		buildSlam(data)
	elseif kind == "SlamBlocked" then
		local slam = slams[data.id]
		if slam then
			slam.data.blockedAt = data.blockedAt
			local tip = T.slamTip(slam.data, data.blockedAt)
			if tip and not insidePrivateStage() then
				inkBurst(tip)
				Sfx.play("Hit", { at = tip, volume = 0.9, pitch = 0.7 })
			end
		end
	elseif kind == "Raid" and data.state == "victory" then
		sinkUntil = os.clock() + 6
	end
end)

cannonCue.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" or data.kind ~= "shot" or not data.hit then
		return
	end
	-- 포탄이 날아가는 시간만큼 기다렸다가 움찔한다
	local travel = data.point and data.muzzle and math.clamp((data.point - data.muzzle).Magnitude / 140, 0.15, 1.2) or 0.3
	task.delay(travel, function()
		if data.hit == "arm" then
			local arm = arms[data.index]
			if arm then
				arm.flinchUntil = os.clock() + 0.45
			end
		elseif data.hit == "eye" and head then
			head.squintUntil = os.clock() + 0.8
		end
	end)
end)

--------------------------------------------------
-- 매 틱
--------------------------------------------------
local accumulator = 0
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	if not folder or not folder.Parent then
		return
	end
	local raid = workspace:GetAttribute("RaidActive") == true
	local phaseId = workspace:GetAttribute("WorldPhase") or "day"
	-- 목표 날뜀 · 머리 높이로 부드럽게 옮겨 간다
	local wantAmp = T.agitation(phaseId, raid)
	amp += (wantAmp - amp) * math.clamp(dt * 0.6, 0, 1)
	local wantRise = raid and T.HeadRaidRise or 0
	rise += (wantRise - rise) * math.clamp(dt * 0.5, 0, 1)

	accumulator += dt
	local step = interval
	if raid or next(slams) then
		step = math.min(interval, 1 / 20)
	end
	if accumulator < step then
		return
	end
	accumulator = 0

	local inStage = insidePrivateStage()
	local now = serverNow()
	local clock = os.clock()

	-- 내려치기는 무대 안에서도 소리 · 흔들림을 전한다
	for _, slam in pairs(slams) do
		queueSlam(slam, now, inStage)
	end

	if inStage then
		pcall(flush)
		return
	end

	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position
	local t = animate and now or nil

	local bulbColor = raid and BULB_RAID or BULB
	local pulse = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(clock * (raid and 8 or 3)))
	for _, arm in ipairs(arms) do
		local root = arm.spec.waypoints[3].p
		-- Phase 15 최적화 : 화면 밖(여유를 두고)이면서 가깝지도 않은 다리는 움직이지 않는다
		local seen = true
		if camera and cameraPosition then
			local mid = arm.spec.waypoints[math.min(4, #arm.spec.waypoints)].p
			local screen = camera:WorldToViewportPoint(mid)
			local size = camera.ViewportSize
			local margin = 0.45
			seen = (mid - cameraPosition).Magnitude < 70 or (screen.Z > 0 and screen.X > -size.X * margin
				and screen.X < size.X * (1 + margin) and screen.Y > -size.Y * margin and screen.Y < size.Y * (1 + margin))
		end
		if seen and (not cameraPosition or (root - cameraPosition).Magnitude < 520) then
			if t or arm.flinchUntil > clock then
				local samples = queueArm(arm, t or now, clock)
				if cameraPosition then
					fadeArm(arm, samples, cameraPosition)
				end
			end
			queueBulb(arm, now, clock)
			if arm.bulb then
				arm.bulb.Color = bulbColor
				arm.bulb.Transparency = pulse
				arm.bulbLight.Color = bulbColor
				arm.bulbLight.Brightness = raid and 2.4 or 1.2
			end
		end
	end
	if head then
		queueHead(head, t or now, cameraPosition, raid)
	end

	local ok, err = pcall(flush)
	if not ok then
		table.clear(moveParts)
		table.clear(moveFrames)
		warn("[CursedBarrel] 크라켄 움직임 오류: " .. tostring(err))
		animate = false
	end
end)

script.Destroying:Connect(function()
	heartbeat:Disconnect()
	if folder then
		folder:Destroy()
	end
end)
