--[[
	FirstPersonHands  (Phase 37)
	1인칭 전용 손 (내 화면에만 보인다). 화면 오른쪽 아래에서 내가 장착한 칼을 쥐고 있다가,
	내 차례에 칼을 꽂으면 손이 직접 칼을 들어 올려 슬롯에 꽂는다.

	· 파트는 카메라(workspace.CurrentCamera) 아래에 둔다 → 이 사람 화면에만 보이고, 부딪힘 · 광선 검사에 걸리지 않는다.
	· 팔은 어깨(화면 밖 오른쪽 아래) → 팔꿈치 → 주먹, 두 마디 IK 로 잇는다. 주먹은 칼 손잡이를 쥔다.
	· 칼은 슬롯 칼과 같은 틀(날 -Z · 손잡이 +Z)로 만들어서, 꽂는 순간 통에 꽂힌 진짜 칼과 딱 겹친다.
	· 꽂는 동작은 모션 스킨(StabMotion 의 style)마다 다르다.
	    classic  : 뒤로 당겼다가 찌르기           overhead : 두 손으로 머리 위로 들었다가 내려찍기
	    triple   : 짧게 두 번 찌르고 크게 한 번    spin     : 손 안에서 칼을 두 바퀴 돌리고 찌르기
	    flourish : 칼을 한 바퀴 비틀며 8자를 그리고 찌르기
	    slam     : 두 손으로 들어 떨다가 세게 내려찍기      dive : 멀리 당겼다가 몸을 깊이 숙이며 찌르기
	    bolt     : 두 손으로 높이 들었다가 번개처럼 내리꽂기
	  찌르는 동안 몸이 앞으로 살짝 숙여진다(lean → 카메라가 따라 나간다).
	· 해적을 잡으려고 누르면 주먹을 휘두르고, 이기면 칼을 치켜들고, 탈락하면 손이 힘없이 떨어진다.
	· 판정 · 서버와는 아무 관계가 없다 (보여 주기만).

	쓰는 법 (Phase4Controller)
	  local hands = FirstPersonHands.new(player)
	  카메라 그리기에서 매 프레임 : hands.want = 1인칭인가 · hands.ready = 내 차례인가 · 카메라 위치에 hands.lean 만큼 앞으로
	  RenderStep(Camera + 2) : hands:update(dt)
	  칼 꽂기 : hands:takeStab(copy, ctx, plan, settle) 가 true 면 날아가는 칼(copy)을 손이 움직인다
	  hands:grab() · hands:cheer() · hands:drop()
]]

local Shared = script.Parent
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local okKit, MeshKit = pcall(require, Shared:WaitForChild("MeshKit"))
local okFx, SkinFX = pcall(require, Shared:WaitForChild("SkinFX"))

local Hands = {}
Hands.__index = Hands
Hands.Reach = 1.85 + 1.95 -- 검사용 (UPPER + LOWER)
Hands.Shoulder = Vector3.new(1.35, -1.5, 0.45)

local LAYOUT = GameConfig.SlotLayout or {}
local BLADE_SIZE = LAYOUT.BladeSize or Vector3.new(0.12, 0.5, 1.6)
local HANDLE_SIZE = LAYOUT.HandleSize or Vector3.new(0.26, 0.34, 0.7)
local SLOT_GUARD_Z = 1.05 -- SlotBuilder 와 같은 값 (Blender 칼 조각 자리)
local SLOT_KNIFE_SCALE = 0.55

-- 칼 틀 (슬롯 칼과 같다) : 원점 = 날 가운데, 날끝 = -Z, 손잡이 = +Z
local GRIP = CFrame.new(0, 0, 1.15) -- 오른손이 쥐는 자리
local POMMEL = CFrame.new(0, 0, 1.72) -- 두 손으로 쥘 때 왼손 자리

-- 카메라 기준 칼 자세 (x 오른쪽 · y 위 · z 뒤). pitch + 면 날끝이 위로
local function pose(x, y, z, pitch, yaw, roll)
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(pitch or 0), math.rad(yaw or 0), math.rad(roll or 0))
end
local REST = pose(0.95, -0.98, -2.35, -22, 10, -8)
local READY = pose(0.8, -0.72, -2.15, -40, 6, -4)
-- ★ 손잡이(+Z)는 카메라 쪽을 향하므로, 쥔 자리는 칼 자리보다 1.15 가깝다. 당기는 자세도 카메라에 너무 붙지 않게
local PULL = pose(0.95, -0.3, -2.35, -8, 16, -12) -- 뒤로 당기기
local DIVE_PULL = pose(1.15, -0.45, -2.1, 0, 24, -16) -- 더 멀리 당기기
local SPIN_POSE = pose(0.8, -0.35, -3.0, -10, 8, -6) -- 손 안에서 돌리기 (날이 카메라 뒤로 넘어가지 않을 만큼 멀리)
local HIGH = pose(0.3, 0.6, -1.75, 72, 0, 0) -- 머리 위로 들기 (두 손)
local BOLT_HIGH = pose(0.2, 0.95, -1.9, 88, 0, 0)
local GRAB = pose(0.45, -0.1, -2.3, 35, -6, -14) -- 잡기 : 주먹을 위로 휘두른다
local CHEER = pose(0.45, 0.45, -1.95, 84, 0, 14)
local DROP = pose(1.2, -3.4, -2.0, -70, 25, 0)
local DRAW_FROM = pose(1.25, -2.4, -1.7, -85, 35, 0)

local SHOULDER_R = Vector3.new(1.35, -1.5, 0.45)
local SHOULDER_L = Vector3.new(-1.35, -1.5, 0.45)
local POLE_R = Vector3.new(2.4, -2.6, -0.4)
local POLE_L = Vector3.new(-2.4, -2.6, -0.4)
-- 자리는 통에서 5.6 ~ 6.6 스터드라 슬롯까지 4 ~ 5 스터드다. 팔을 조금 길게(만화처럼) 하고, 찌를 때 몸을 숙여 닿게 한다
local UPPER, LOWER = 1.85, 1.95
local ARM_THICK = 0.5

local COAT = Color3.fromRGB(70, 40, 48)
local CUFF = Color3.fromRGB(226, 178, 88)

local function outQuad(x)
	return 1 - (1 - x) * (1 - x)
end
local function inQuad(x)
	return x * x
end
local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function prep(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function block(parent, name, size, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	prep(p)
	p.Parent = parent
	return p
end

-- 두 마디 IK : 어깨 s · 주먹 f · 팔꿈치가 굽는 쪽 pole (모두 월드). 팔꿈치 자리를 돌려준다
local function elbowOf(s, f, pole)
	local d = f - s
	local dist = d.Magnitude
	if dist < 1e-3 then
		return s
	end
	local dir = d / dist
	local reach = UPPER + LOWER
	if dist >= reach * 0.999 then
		-- 닿지 않으면 곧게 편다 (조금 늘어난다)
		return s + dir * (dist * UPPER / reach)
	end
	local a = (UPPER * UPPER - LOWER * LOWER + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(0, UPPER * UPPER - a * a))
	local bend = pole - s
	bend -= dir * bend:Dot(dir)
	if bend.Magnitude < 1e-3 then
		bend = Vector3.new(0, -1, 0)
	end
	return s + dir * a + bend.Unit * h
end

-- 두 점을 잇는 막대
local function segment(part, a, b, thick)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		part.Size = Vector3.new(thick, thick, 0.05)
		part.CFrame = CFrame.new(a)
		return
	end
	part.Size = Vector3.new(thick, thick, len)
	part.CFrame = CFrame.lookAt((a + b) * 0.5, b)
end

-- 주먹 하나 (칼 손잡이를 쥐는 모양). 원점 = 쥔 자리, 칼 틀과 같은 축
local function makeFist(parent, name, skinColor)
	local fist = Instance.new("Model")
	fist.Name = name
	local palm = block(fist, "Palm", Vector3.new(0.6, 0.58, 0.68), skinColor)
	local knuckles = {}
	for i = 1, 4 do
		knuckles[i] = block(fist, "Knuckle", Vector3.new(0.2, 0.2, 0.15), skinColor:Lerp(Color3.new(0, 0, 0), 0.08))
	end
	local thumb = block(fist, "Thumb", Vector3.new(0.19, 0.19, 0.42), skinColor)
	fist.PrimaryPart = palm
	fist.Parent = parent
	return {
		model = fist,
		place = function(cf)
			palm.CFrame = cf * CFrame.new(0.06, 0, 0)
			for i, k in ipairs(knuckles) do
				k.CFrame = cf * CFrame.new(0.33, 0.14, -0.3 + (i - 1) * 0.2)
			end
			thumb.CFrame = cf * CFrame.new(-0.12, 0.33, -0.12) * CFrame.Angles(math.rad(12), 0, 0)
		end,
		color = function(c)
			palm.Color = c
			thumb.Color = c
			for _, k in ipairs(knuckles) do
				k.Color = c:Lerp(Color3.new(0, 0, 0), 0.08)
			end
		end,
	}
end

-- 팔 (윗팔 · 아랫팔 · 금 소매단)
local function makeArm(parent, name)
	local upper = block(parent, name .. "Upper", Vector3.new(ARM_THICK, ARM_THICK, 1), COAT, Enum.Material.Fabric)
	local lower = block(parent, name .. "Lower", Vector3.new(ARM_THICK, ARM_THICK, 1), COAT, Enum.Material.Fabric)
	local cuff = block(parent, name .. "Cuff", Vector3.new(0.6, 0.6, 0.2), CUFF, Enum.Material.Metal)
	cuff.Reflectance = 0.15
	return { upper = upper, lower = lower, cuff = cuff }
end

local function placeArm(arm, shoulder, fistCF, pole)
	local fistPos = fistCF.Position
	local elbow = elbowOf(shoulder, fistPos, pole)
	local toElbow = elbow - fistPos
	local wristDir = toElbow.Magnitude > 1e-3 and toElbow.Unit or Vector3.new(0, -1, 0)
	local wrist = fistPos + wristDir * 0.3
	segment(arm.upper, shoulder, elbow, ARM_THICK + 0.04)
	segment(arm.lower, elbow, wrist, ARM_THICK)
	segment(arm.cuff, wrist, wrist + wristDir * 0.2, 0.6)
end

-- 슬롯 칼과 같은 틀의 내 칼 (Blender 칼 조각이 있으면 그것, 없으면 네모 칼)
local function buildKnife(skin)
	local model = Instance.new("Model")
	model.Name = "FPKnife"
	skin = skin or {}
	local blade = block(model, "Blade", BLADE_SIZE, skin.blade or LAYOUT.BladeColor or Color3.fromRGB(206, 210, 214), skin.bladeMaterial or Enum.Material.Metal)
	blade.Reflectance = skin.glow and 0.2 or 0.05
	local boxes = { blade }
	local edge = block(model, "Edge", Vector3.new(BLADE_SIZE.X + 0.01, 0.1, BLADE_SIZE.Z * 0.94), (skin.blade or Color3.fromRGB(206, 210, 214)):Lerp(Color3.new(1, 1, 1), 0.45), Enum.Material.Metal)
	edge.CFrame = CFrame.new(0, -BLADE_SIZE.Y * 0.42, 0)
	table.insert(boxes, edge)
	local handle = block(model, "Handle", HANDLE_SIZE, skin.handle or LAYOUT.HandleColor or Color3.fromRGB(64, 42, 28), skin.handleMaterial or Enum.Material.Wood)
	handle.CFrame = CFrame.new(0, 0, 1.15)
	table.insert(boxes, handle)
	local guard = block(model, "Guard", Vector3.new(0.3, 0.72, 0.14), skin.guard or Color3.fromRGB(126, 104, 62), Enum.Material.Metal)
	guard.CFrame = CFrame.new(0, 0, 0.82)
	table.insert(boxes, guard)
	local pommel = block(model, "Pommel", Vector3.new(0.3, 0.3, 0.3), skin.guard or Color3.fromRGB(126, 104, 62), Enum.Material.Metal, Enum.PartType.Ball)
	pommel.CFrame = CFrame.new(0, 0, 1.58)
	table.insert(boxes, pommel)
	blade.CFrame = CFrame.new()
	model.PrimaryPart = blade
	if okKit and MeshKit.hasKnife and MeshKit.hasKnife(skin) then
		local holder = Instance.new("Model")
		holder.Name = "SkinMesh"
		holder.Parent = model
		local frame = CFrame.new(0, 0, -0.2 + SLOT_GUARD_Z) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
		local ok, made = pcall(MeshKit.knife, skin, holder, frame, SLOT_KNIFE_SCALE)
		if ok and made and #made > 0 then
			for _, p in ipairs(boxes) do
				p.Transparency = 1
			end
		else
			holder:Destroy()
		end
	end
	if okFx and SkinFX.applyKnife then
		pcall(SkinFX.applyKnife, model, skin, true)
	end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			prep(p)
		end
	end
	return model
end

-- Phase 38 : 던지는 칼 · 다른 연출에서도 같은 칼 모형을 쓴다
Hands.makeKnife = buildKnife

function Hands.new(player)
	local self = setmetatable({}, Hands)
	self.player = player
	self.want = false -- 이번 프레임에 1인칭인가 (카메라 그리기가 정한다)
	self.ready = false -- 내 차례인가
	self.lean = 0 -- 카메라가 앞으로 나가는 거리 (찌를 때)
	self.leanVector = Vector3.zero -- 카메라에 더할 월드 오프셋 (슬롯 쪽 수평 방향 × lean)
	self.leanDir = Vector3.zero
	self.shown = false
	self.localPose = REST -- 지금 칼 자세 (카메라 기준)
	self.sway = Vector3.zero
	self.lastLook = nil
	self.action = nil
	self.dropped = false

	local root = Instance.new("Model")
	root.Name = "CursedBarrel_FPHands"
	self.root = root
	self.armR = makeArm(root, "Right")
	self.armL = makeArm(root, "Left")
	self.fistR = makeFist(root, "FistR", Color3.fromRGB(234, 184, 146))
	self.fistL = makeFist(root, "FistL", Color3.fromRGB(234, 184, 146))
	self.knifeSkinId = nil
	self.knife = nil
	return self
end

-- 손 색 = 캐릭터 손 색 (R15 RightHand · R6 Right Arm)
function Hands:_refreshLook()
	local character = self.player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	local color = hand and hand:IsA("BasePart") and hand.Color or Color3.fromRGB(234, 184, 146)
	if self.skinColor ~= color then
		self.skinColor = color
		self.fistR.color(color)
		self.fistL.color(color)
	end
	local skinId = self.player:GetAttribute(GameConfig.Skins.PlayerAttributes.Knife) or "classic"
	if skinId ~= self.knifeSkinId or not self.knife then
		self.knifeSkinId = skinId
		if self.knife then
			self.knife:Destroy()
		end
		self.knife = buildKnife(GameConfig.findSkin("Knife", skinId))
		self.knife.Parent = self.root
	end
end

function Hands:_show(on)
	local camera = workspace.CurrentCamera
	if on then
		if self.root.Parent ~= camera then
			self.root.Parent = camera
		end
	elseif self.root.Parent then
		self.root.Parent = nil
	end
	self.shown = on
end

-- 찌르기 : 날아가는 칼(copy)을 손이 움직인다. 1인칭이 아니면 false (원래 연출)
function Hands:takeStab(copy, ctx, plan, settle)
	if not self.shown or self.dropped or not copy or not ctx or not plan then
		return false
	end
	if self.action and self.action.kind == "stab" and self.action.copy and self.action.copy.Parent then
		self.action.copy:PivotTo(self.action.ctx.target)
	end
	local style = plan.style or "classic"
	self.action = {
		kind = "stab",
		started = os.clock(),
		copy = copy,
		ctx = ctx,
		plan = plan,
		settle = settle or 0.12,
		style = style,
		from = self.localPose,
		twoHand = style == "overhead" or style == "slam" or style == "bolt",
	}
	-- 몸을 숙이는 방향 = 슬롯 쪽 수평 · 거리 = 팔이 닿을 만큼 (최소 0.6 · 최대 2.6)
	local cam = workspace.CurrentCamera.CFrame
	local grip = (ctx.target * GRIP).Position
	local shoulder = (cam * SHOULDER_R)
	local flat = Vector3.new(grip.X - cam.Position.X, 0, grip.Z - cam.Position.Z)
	self.leanDir = flat.Magnitude > 1e-3 and flat.Unit or Vector3.zero
	local need = (grip - shoulder).Magnitude - (UPPER + LOWER) * 0.92
	self.action.leanMax = math.clamp(need * 1.25, 0.6, 2.6) + (style == "dive" and 0.35 or 0)
	-- 슬롯이 통 옆 · 뒤쪽이면(내 쪽에서 45도 넘게 돌아가 있으면) 손이 닿지 않는다 → 던진다
	local center = ctx.center
	if center then
		local toSlot = Vector3.new(grip.X - center.X, 0, grip.Z - center.Z)
		local toMe = Vector3.new(cam.Position.X - center.X, 0, cam.Position.Z - center.Z)
		if toSlot.Magnitude > 1e-3 and toMe.Magnitude > 1e-3 and toSlot.Unit:Dot(toMe.Unit) < math.cos(math.rad(45)) then
			self.action.throw = true
			self.action.twoHand = false
			self.action.flight = math.clamp(plan.total * 0.55, 0.16, 0.3)
		end
	end
	copy:PivotTo(cam * self.localPose)
	return true
end

function Hands:grab()
	if not self.shown or self.dropped then
		return
	end
	if self.action and self.action.kind == "stab" then
		return
	end
	self.action = { kind = "grab", started = os.clock(), from = self.localPose }
end

-- Phase 38 : 해적을 잡으려고 누르면 칼을 던진다. 손은 휙 던지고, 새 칼을 뽑아 든다.
--   돌려주는 값 = 칼이 손을 떠나는 자리 (월드). 1인칭이 아니면 nil (다른 곳에서 던진다)
local TOSS = pose(0.55, -0.45, -2.9, -12, -4, -8)
function Hands:toss()
	if not self.shown or self.dropped then
		return nil
	end
	if self.action and self.action.kind == "stab" then
		return nil
	end
	local camera = workspace.CurrentCamera
	local from = camera.CFrame * self.localPose
	self.action = { kind = "toss", started = os.clock(), from = self.localPose }
	return from
end

function Hands:cheer()
	if not self.shown then
		return
	end
	self.dropped = false
	self.action = { kind = "cheer", started = os.clock(), from = self.localPose }
end

function Hands:drop()
	if not self.shown then
		return
	end
	self.action = { kind = "drop", started = os.clock(), from = self.localPose }
end

-- 던지기 (슬롯이 통 옆 · 뒤쪽이라 손이 닿지 않을 때) : 뒤로 젖혔다가 휙 던진다. 칼은 통을 돌아 슬롯에 꽂힌다
local THROW_BACK = pose(1.1, 0.15, -2.3, 45, 22, -20)
local THROW_FLICK = pose(0.55, -0.35, -3.1, -25, 0, -6)
local TAU = math.pi * 2

local function windupOf(style)
	if style == "spin" then
		return SPIN_POSE
	elseif style == "overhead" or style == "slam" then
		return HIGH
	elseif style == "bolt" then
		return BOLT_HIGH
	elseif style == "dive" then
		return DIVE_PULL
	end
	return PULL
end

-- 통을 돌아 날아가는 칼. u = 0 (손에서 놓은 자리) → 1 (슬롯 칼 자리)
local function flightAt(fromCF, target, center, u)
	local p0, p1 = fromCF.Position, target.Position
	local h0 = Vector3.new(p0.X - center.X, 0, p0.Z - center.Z)
	local h1 = Vector3.new(p1.X - center.X, 0, p1.Z - center.Z)
	local a0, a1 = math.atan2(h0.Z, h0.X), math.atan2(h1.Z, h1.X)
	local d = (a1 - a0 + math.pi) % TAU - math.pi -- 짧은 쪽으로 돈다
	local e = smooth(u)
	local angle = a0 + d * e
	local radius = h0.Magnitude + (h1.Magnitude - h0.Magnitude) * e + math.sin(math.pi * u) * 0.7
	local y = p0.Y + (p1.Y - p0.Y) * e + math.sin(math.pi * u) * 0.9
	local pos = Vector3.new(center.X + math.cos(angle) * radius, y, center.Z + math.sin(angle) * radius)
	local turn = fromCF.Rotation:Lerp(target.Rotation, e) * CFrame.Angles(TAU * 2 * outQuad(u), 0, 0)
	if u >= 1 then
		return target
	end
	return CFrame.new(pos) * turn
end

-- 찌르기 중 칼 · 주먹 자세 (월드). 돌려주는 값 : 칼, 주먹(nil 이면 칼 손잡이), 칼을 쥐고 있는가, 숙이기
function Hands:_stabPose(a, now, cam)
	local plan, ctx = a.plan, a.ctx
	local t = now - a.started
	local total = plan.total
	local style = a.style
	local leanMax = a.leanMax or 1

	if a.throw then
		local flight = a.flight
		local releaseAt = total - flight
		if t < releaseAt then
			local r = t / math.max(0.01, releaseAt)
			local localCF
			if r < 0.75 then
				localCF = a.from:Lerp(THROW_BACK, outQuad(r / 0.75))
			else
				localCF = THROW_BACK:Lerp(THROW_FLICK, inQuad((r - 0.75) / 0.25))
			end
			return cam * localCF, nil, true, 0.35 * leanMax * r
		end
		if not a.releaseCF then
			a.releaseCF = cam * THROW_FLICK
			a.releaseFist = a.releaseCF * GRIP
		end
		local u = (t - releaseAt) / flight
		local back = math.clamp(u / 0.8, 0, 1)
		local fist = a.releaseFist:Lerp(cam * REST * GRIP, outQuad(back))
		return flightAt(a.releaseCF, ctx.target, ctx.center or (ctx.target.Position + (ctx.look or Vector3.zero) * 2), math.min(u, 1)), fist, false, 0.35 * leanMax * (1 - back)
	end

	local jabs = plan.jabs or 0
	local riseEnd = jabs + (plan.rise or 0.2)
	local strikeStart = riseEnd + (plan.hang or 0)
	local windup = windupOf(style)

	if t < jabs then
		-- 세 번 찌르기 : 짧게 두 번 (목표까지 45%)
		local phase = (t / (jabs * 0.5)) % 1
		local reachA = math.sin(phase * math.pi)
		local fromW = cam * READY
		return fromW:Lerp(ctx.target, 0.45 * reachA), nil, true, leanMax * 0.45 * reachA
	end
	if t < riseEnd then
		local r = (t - jabs) / math.max(0.01, riseEnd - jabs)
		local e = outQuad(r)
		local startLocal = jabs > 0 and READY or a.from
		local localCF = startLocal:Lerp(windup, e)
		if style == "spin" then
			-- 손 안에서 칼을 두 바퀴 (쥔 자리를 축으로)
			local grip = localCF * GRIP
			localCF = grip * CFrame.Angles(e * math.pi * 4, 0, 0) * GRIP:Inverse()
		elseif style == "flourish" then
			-- 8자를 그리며 칼을 한 바퀴 비튼다
			local w = r * math.pi * 2
			localCF = CFrame.new(math.sin(w) * 0.3, math.sin(w * 2) * 0.14, 0) * localCF * CFrame.Angles(0, 0, e * math.pi * 2)
		end
		-- 들어 올리는 동안 몸을 미리 숙인다 (찌르는 순간은 짧아서 그때 숙이면 늦다)
		return cam * localCF, nil, true, leanMax * 0.75 * e
	end
	if t < strikeStart then
		-- 꼭대기에서 멈칫 (떨림)
		local shake = math.sin(now * 90) * 0.03
		return cam * windup * CFrame.new(shake, 0, 0), nil, true, leanMax * 0.75
	end
	if t < total then
		local s = (t - strikeStart) / math.max(0.01, total - strikeStart)
		local fromW = cam * windup
		return fromW:Lerp(ctx.target, inQuad(s)), nil, true, leanMax * (0.75 + 0.25 * smooth(s * 1.6))
	end
	return ctx.target, nil, false, 0
end

function Hands:update(dt)
	local camera = workspace.CurrentCamera
	local want = self.want and camera ~= nil
	if not want then
		if self.action and self.action.kind == "stab" and self.action.copy and self.action.copy.Parent then
			self.action.copy:PivotTo(self.action.ctx.target)
		end
		self.action = nil
		self.dropped = false
		self.lean = 0
		self.leanVector = Vector3.zero
		self.lastLook = nil
		if self.shown then
			self:_show(false)
		end
		return
	end
	self:_refreshLook()
	if not self.shown then
		self:_show(true)
		self.localPose = DRAW_FROM
	end

	local now = os.clock()
	local cam = camera.CFrame

	-- 카메라를 돌리면 손이 살짝 늦게 따라온다
	if self.lastLook then
		local prev = cam:VectorToObjectSpace(self.lastLook)
		local target = Vector3.new(math.clamp(prev.X, -0.3, 0.3), math.clamp(prev.Y, -0.3, 0.3), 0) * 1.6
		self.sway = self.sway:Lerp(target, 1 - math.exp(-dt * 10))
	end
	self.lastLook = cam.LookVector
	self.sway = self.sway:Lerp(Vector3.zero, 1 - math.exp(-dt * 6))
	local bob = math.sin(now * 1.7) * 0.02
	local swayCF = CFrame.new(self.sway.X * 0.35, self.sway.Y * 0.35 + bob, 0) * CFrame.Angles(self.sway.Y * 0.3, self.sway.X * 0.3, 0)

	local goal = self.ready and READY or REST
	if self.ready then
		-- 내 차례 : 칼끝이 조금 떨린다
		goal = goal * CFrame.Angles(math.sin(now * 23) * 0.012, 0, math.sin(now * 17) * 0.012)
	end

	local knifeWorld, holding, leanGoal = nil, true, 0
	local fistWorld = nil
	local secondHand = false
	local a = self.action
	if a then
		local t = now - a.started
		if a.kind == "stab" then
			local total = a.plan.total
			if t < total then
				knifeWorld, fistWorld, holding, leanGoal = self:_stabPose(a, now, cam)
				secondHand = a.twoHand and not a.throw and t < total
				if a.copy and a.copy.Parent then
					a.copy:PivotTo(knifeWorld)
				end
			else
				-- 꽂았다 : 칼은 통에 남고, 손은 놓고 돌아온다. 그다음 새 칼을 뽑아 든다
				if not a.planted then
					a.planted = true
					if a.copy and a.copy.Parent then
						a.copy:PivotTo(a.ctx.target)
					end
				end
				local back = t - total
				local release = 0.3
				local drawAt = math.max(release, a.settle + 0.05)
				if back < release and not a.throw then
					local fistFrom = a.ctx.target * GRIP
					local fistTo = cam * REST * GRIP
					local fist = fistFrom:Lerp(fistTo, outQuad(back / release))
					self.fistR.place(fist)
					placeArm(self.armR, cam * SHOULDER_R, fist, cam * POLE_R)
					self.fistL.model.Parent = nil
					self.armL.upper.Parent, self.armL.lower.Parent, self.armL.cuff.Parent = nil, nil, nil
					if self.knife then
						self.knife.Parent = nil
					end
					self.localPose = REST
					self.lean = self.lean * math.exp(-dt * 8)
					self.leanVector = self.leanDir * self.lean
					return
				elseif back < drawAt + 0.3 then
					local d = smooth((back - drawAt) / 0.3)
					self.localPose = DRAW_FROM:Lerp(REST, d) * CFrame.Angles(0, 0, (1 - d) * math.pi)
					knifeWorld = cam * self.localPose * swayCF
				else
					self.action = nil
				end
			end
		elseif a.kind == "toss" then
			-- 휙 던지고(칼은 손을 떠났다) → 새 칼을 뽑아 든다
			if t < 0.2 then
				self.localPose = (a.from or REST):Lerp(TOSS, outQuad(math.min(1, t / 0.08)))
				knifeWorld = cam * self.localPose * swayCF
				holding = false
			elseif t < 0.42 then
				self.localPose = DRAW_FROM:Lerp(REST, smooth((t - 0.2) / 0.22))
				knifeWorld = cam * self.localPose * swayCF
			else
				self.action = nil
			end
		elseif a.kind == "grab" then
			local d = 0.34
			if t < d then
				local k = math.sin(math.clamp(t / d, 0, 1) * math.pi)
				self.localPose = (a.from or REST):Lerp(GRAB, k)
				knifeWorld = cam * self.localPose * swayCF
			else
				self.action = nil
			end
		elseif a.kind == "cheer" then
			local d = 1.8
			if t < d then
				local up = smooth(t / 0.3) * (1 - smooth((t - 1.4) / 0.4))
				self.localPose = (a.from or REST):Lerp(CHEER, up) * CFrame.Angles(0, 0, math.sin(t * 14) * 0.08 * up)
				knifeWorld = cam * self.localPose * swayCF
			else
				self.action = nil
			end
		elseif a.kind == "drop" then
			local k = smooth(t / 0.7)
			self.localPose = (a.from or REST):Lerp(DROP, k)
			knifeWorld = cam * self.localPose
			if t > 0.8 then
				self.dropped = true
				self.action = nil
			end
		end
	end
	if not knifeWorld then
		if self.dropped then
			-- 탈락 : 손은 화면 밖에 둔다 (다음 판에 다시 뽑아 든다)
			self.localPose = DROP
		else
			self.localPose = self.localPose:Lerp(goal, 1 - math.exp(-dt * 9))
		end
		knifeWorld = cam * self.localPose * swayCF
	end
	self.lean += (leanGoal - self.lean) * (1 - math.exp(-dt * 30))
	self.leanVector = self.leanDir * self.lean

	-- 칼 · 오른손 · 오른팔
	local inHand = holding and not (a and a.kind == "stab" and (now - a.started) < a.plan.total)
	if self.knife then
		self.knife.Parent = inHand and self.root or nil
		if inHand then
			self.knife:PivotTo(knifeWorld)
		end
	end
	local fistR = fistWorld or (knifeWorld * GRIP)
	self.fistR.place(fistR)
	placeArm(self.armR, cam * SHOULDER_R, fistR, cam * POLE_R)

	-- 왼손 (두 손 모션일 때만)
	if secondHand then
		for _, p in ipairs({ self.armL.upper, self.armL.lower, self.armL.cuff }) do
			p.Parent = self.root
		end
		self.fistL.model.Parent = self.root
		local fistL = knifeWorld * POMMEL * CFrame.Angles(0, math.pi, 0)
		self.fistL.place(fistL)
		placeArm(self.armL, cam * SHOULDER_L, fistL, cam * POLE_L)
	else
		self.fistL.model.Parent = nil
		for _, p in ipairs({ self.armL.upper, self.armL.lower, self.armL.cuff }) do
			p.Parent = nil
		end
	end
end

return Hands
