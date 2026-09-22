--[[
	KrakenController  (Phase 10)
	배를 삼키려는 크라켄을 내 화면에만 세우고 천천히 움직인다.

	· 모양은 KrakenLayout 이 정한다. 여기서는 파트를 만들고 매 틱 자리를 옮기기만 한다.
	· 전부 장식이다. 부딪히지 않고(CanCollide/CanTouch), 카메라 · 레이캐스트에도 걸리지 않는다(CanQuery).
	· 서버는 이 파일을 모른다. 파트는 클라이언트에서만 생기므로 복제 · 스트리밍 비용이 없다.

	성능
	  · 효과 품질 "낮음"(모바일 기본)이면 마디를 줄이고 빨판을 빼고 10Hz 로만 움직인다.
	  · "번쩍임 · 연출 줄이기"를 켜면 움직이지 않는다. (자세만 잡아 두고 멈춘다)
	  · 테이블에서 게임 중(검은 개인 무대 안)이면 어차피 보이지 않으므로 움직이지 않는다.
	  · 카메라가 다리 바로 옆에 오면 그 다리를 반투명하게 해서 화면을 가리지 않는다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local K = require(Shared:WaitForChild("KrakenLayout"))
local FX = require(Shared:WaitForChild("PremiumFX"))

local player = Players.LocalPlayer
local COLORS = K.Colors

local folder = nil
local arms = {} -- { spec, count, joints, segs, suckers, normal, sign, lengths, faded }
local head = nil -- { parts..., frame }
local animate = true
local interval = 1 / 30
local startedAt = os.clock()

local moveParts = {} -- BulkMoveTo 에 넘길 표 (매 틱 새로 만들지 않고 재사용한다)
local moveFrames = {}

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
-- 다리
--------------------------------------------------

local function tangentAt(samples, index)
	local a = samples[math.max(index - 1, 1)].p
	local b = samples[math.min(index + 1, #samples)].p
	local t = b - a
	if t.Magnitude < 1e-4 then
		return Vector3.new(0, 1, 0)
	end
	return t.Unit
end

local function buildArm(spec, quality)
	local count = K.Samples[quality] or K.Samples.High
	local model = Instance.new("Model")
	model.Name = spec.name
	model.Parent = folder

	local samples = K.sample(spec, nil, count)
	local arm = {
		spec = spec,
		count = count,
		model = model,
		joints = {},
		segs = {},
		suckers = {},
		normal = K.planeNormal(spec),
		sign = K.innerSign(spec, count),
		faded = false,
		parts = {},
	}

	for index, s in ipairs(samples) do
		-- 마디 사이 빛깔을 조금씩 바꿔 매끈한 관처럼 보이지 않게 한다.
		local shade = (index % 2 == 0) and COLORS.Skin or COLORS.Skin:Lerp(COLORS.SkinDark, 0.35)
		local joint = part(model, "Joint", Enum.PartType.Ball, Vector3.new(s.r * 2, s.r * 2, s.r * 2), shade)
		arm.joints[index] = joint
		table.insert(arm.parts, joint)
		if index > 1 then
			local previous = samples[index - 1]
			local length = (s.p - previous.p).Magnitude * 1.08
			local diameter = s.r + previous.r
			local seg = part(model, "Segment", Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter), shade)
			arm.segs[index - 1] = seg
			table.insert(arm.parts, seg)
		end
	end

	-- 빨판 : 곡선 안쪽에 한 칸씩 건너 붙인다. (물속 뿌리 쪽 세 마디는 건너뛴다)
	if quality == "High" then
		for index = 4, count - 1, 2 do
			local r = samples[index].r
			local disc = part(model, "Sucker", Enum.PartType.Cylinder, Vector3.new(0.14, r * 1.15, r * 1.15), COLORS.Sucker)
			table.insert(arm.suckers, { part = disc, index = index })
			table.insert(arm.parts, disc)
		end
	end

	-- 물 위로 올라오는 자리에 흰 포말
	for index = 2, #samples do
		local a, b = samples[index - 1], samples[index]
		if a.p.Y < K.SeaY and b.p.Y >= K.SeaY then
			local alpha = (K.SeaY - a.p.Y) / math.max(b.p.Y - a.p.Y, 1e-3)
			local at = a.p:Lerp(b.p, alpha)
			local width = (a.r + (b.r - a.r) * alpha) * 2 + 3
			local foam = part(model, "Foam", Enum.PartType.Cylinder, Vector3.new(0.2, width, width), COLORS.Foam)
			foam.CFrame = CFrame.new(at.X, K.SeaY + 0.42, at.Z) * CFrame.Angles(0, 0, math.rad(90))
			foam.Transparency = 0.45
			break
		end
	end

	return arm
end

local function queueArm(arm, t)
	local samples = K.sample(arm.spec, t, arm.count)
	for index, s in ipairs(samples) do
		table.insert(moveParts, arm.joints[index])
		table.insert(moveFrames, CFrame.new(s.p))
		local seg = arm.segs[index - 1]
		if seg then
			table.insert(moveParts, seg)
			table.insert(moveFrames, along(samples[index - 1].p, s.p))
		end
	end
	for _, sucker in ipairs(arm.suckers) do
		local s = samples[sucker.index]
		local inner = arm.normal:Cross(tangentAt(samples, sucker.index)) * arm.sign
		if inner.Magnitude > 1e-4 then
			inner = inner.Unit
			table.insert(moveParts, sucker.part)
			table.insert(moveFrames, facing(s.p + inner * (s.r * 0.9), inner))
		end
	end
	return samples
end

-- 카메라가 다리 바로 옆에 오면 그 다리를 반투명하게 한다.
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

local function buildHead(quality)
	local spec = K.Head
	local model = Instance.new("Model")
	model.Name = "KrakenHead"
	model.Parent = folder

	local frame = CFrame.lookAt(spec.center, Vector3.new(spec.lookAt.X, spec.center.Y, spec.lookAt.Z))
	local h = { model = model, frame = frame, eyes = {} }

	h.low = part(model, "Mantle", Enum.PartType.Ball, Vector3.new(spec.mantle, spec.mantle, spec.mantle), COLORS.Skin)
	local back = spec.mantle * 0.8
	h.high = part(model, "MantleTop", Enum.PartType.Ball, Vector3.new(back, back, back), COLORS.SkinDark)
	h.highOffset = CFrame.new(0, spec.mantle * 0.2, spec.mantle * 0.16)

	-- 머리가 물을 가르는 자리
	local foamWidth = spec.mantle * 0.95
	local foam = part(model, "Foam", Enum.PartType.Cylinder, Vector3.new(0.2, foamWidth, foamWidth), COLORS.Foam)
	foam.CFrame = CFrame.new(spec.center.X, K.SeaY + 0.42, spec.center.Z) * CFrame.Angles(0, 0, math.rad(90))
	foam.Transparency = 0.55

	for _, side in ipairs({ -1, 1 }) do
		local eye = {}
		eye.offset = CFrame.new(side * spec.eyeSpread, spec.eyeRise, -spec.eyeForward)
		eye.white = part(model, "EyeWhite", Enum.PartType.Ball, Vector3.new(spec.eye, spec.eye, spec.eye), COLORS.EyeWhite)
		eye.iris = part(model, "Iris", Enum.PartType.Ball, Vector3.new(spec.eye * 0.72, spec.eye * 0.72, spec.eye * 0.72), COLORS.Iris, Enum.Material.Neon)
		eye.pupil = part(model, "Pupil", nil, Vector3.new(spec.eye * 0.13, spec.eye * 0.6, spec.eye * 0.1), COLORS.Pupil)
		eye.brow = part(model, "Brow", Enum.PartType.Ball, Vector3.new(spec.eye * 1.3, spec.eye * 1.3, spec.eye * 1.3), COLORS.SkinDark)
		eye.lid = part(model, "Lid", Enum.PartType.Ball, Vector3.new(spec.eye * 1.25, spec.eye * 1.25, spec.eye * 1.25), COLORS.Skin)
		table.insert(h.eyes, eye)
	end

	h.blinkAt = os.clock() + 4
	h.quality = quality
	return h
end

local function queueHead(h, t, cameraPosition)
	local spec = K.Head
	local bob = t and (math.sin(t * 0.35) * 0.7) or 0
	local frame = h.frame + Vector3.new(0, bob, 0)

	table.insert(moveParts, h.low)
	table.insert(moveFrames, frame)
	table.insert(moveParts, h.high)
	table.insert(moveFrames, frame * h.highOffset)

	-- 눈꺼풀 : 몇 초에 한 번 느리게 감았다 뜬다.
	local blink = 0
	if t then
		local now = os.clock()
		if now > h.blinkAt + 0.45 then
			h.blinkAt = now + 5 + math.random() * 4
		end
		local phase = (now - h.blinkAt) / 0.45
		if phase >= 0 and phase <= 1 then
			blink = math.sin(phase * math.pi)
		end
	end

	for _, eye in ipairs(h.eyes) do
		local center = (frame * eye.offset).Position
		local rest = frame.LookVector
		-- 눈동자는 카메라 쪽을 본다. 너무 돌아가지는 않게 40도 안으로 가둔다.
		local look = rest
		if cameraPosition then
			local toCamera = cameraPosition - center
			if toCamera.Magnitude > 1 then
				toCamera = toCamera.Unit
				local dot = math.clamp(toCamera:Dot(rest), -1, 1)
				local angle = math.acos(dot)
				local limit = math.rad(40)
				if angle <= limit then
					look = toCamera
				else
					local axis = rest:Cross(toCamera)
					if axis.Magnitude > 1e-4 then
						look = (CFrame.fromAxisAngle(axis.Unit, limit) * rest).Unit
					end
				end
			end
		end
		local up = Vector3.new(0, 1, 0)
		table.insert(moveParts, eye.white)
		table.insert(moveFrames, CFrame.new(center))
		table.insert(moveParts, eye.brow)
		table.insert(moveFrames, CFrame.new(center + up * (spec.eye * 0.42) - rest * (spec.eye * 0.12)))
		table.insert(moveParts, eye.iris)
		table.insert(moveFrames, CFrame.new(center + look * (spec.eye * 0.2)))
		table.insert(moveParts, eye.pupil)
		table.insert(moveFrames, CFrame.lookAt(center + look * (spec.eye * 0.57), center + look * (spec.eye * 2), up))
		-- 뜬 눈 : 눈꺼풀이 눈썹 안에 숨어 있다. 감은 눈 : 눈 위를 덮는다.
		table.insert(moveParts, eye.lid)
		table.insert(moveFrames, CFrame.new(center + up * (spec.eye * 0.62 * (1 - blink)) - rest * (spec.eye * 0.02)))
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

local function build()
	if folder then
		folder:Destroy()
	end
	table.clear(arms)
	folder = Instance.new("Folder")
	folder.Name = "CursedBarrel_Kraken"

	local quality = currentQuality()
	animate = player:GetAttribute("Setting_reducedFX") ~= true
	interval = quality == "Low" and (1 / 10) or (1 / 30)

	for _, spec in ipairs(K.Arms) do
		local ok, arm = pcall(buildArm, spec, quality)
		if ok then
			table.insert(arms, arm)
		else
			warn("[CursedBarrel] 크라켄 다리를 세우지 못했습니다: " .. tostring(arm))
		end
	end
	local ok, built = pcall(buildHead, quality)
	head = ok and built or nil

	-- 쉬는 자세를 한 번 잡은 뒤에 보이게 한다. (처음 한 프레임 동안 원점에 뭉쳐 보이지 않게)
	for _, arm in ipairs(arms) do
		queueArm(arm, animate and 0 or nil)
	end
	if head then
		queueHead(head, animate and 0 or nil, nil)
	end
	folder.Parent = workspace
	flush()
end

-- 테이블에서 게임 중이면 검은 개인 무대가 둘러싸 크라켄이 보이지 않는다.
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

local accumulator = 0
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	if not animate or not folder or not folder.Parent then
		return
	end
	accumulator += dt
	if accumulator < interval then
		return
	end
	accumulator = 0
	if insidePrivateStage() then
		return
	end

	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position
	local t = os.clock() - startedAt

	for _, arm in ipairs(arms) do
		-- 멀리 있는 다리는 움직여도 보이지 않는다.
		local root = arm.spec.waypoints[3].p
		if not cameraPosition or (root - cameraPosition).Magnitude < 520 then
			local samples = queueArm(arm, t)
			if cameraPosition then
				fadeArm(arm, samples, cameraPosition)
			end
		end
	end
	if head then
		queueHead(head, t, cameraPosition)
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
