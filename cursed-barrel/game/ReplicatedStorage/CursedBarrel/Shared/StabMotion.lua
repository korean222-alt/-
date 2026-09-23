--[[
	StabMotion  (Phase 11)
	칼 꽂는 모션. 상점에서 파는 "모션 스킨"이 여기 있는 동작 이름(style)을 고른다.

	애니메이션 에셋(업로드한 Animation ID) 없이 코드로 만든다.
	  · 칼은 매 프레임 계산한 자리로 옮긴다 (knifeAt)
	  · 사람 팔 · 허리는 관절(Motor6D)의 C0 를 잠깐 돌렸다가 되돌린다 (playBody)
	  · R15 · R6 둘 다 된다. AI 선원은 R6 관절 이름을 쓴다.

	★ 어떤 모션이든 MaxDuration(0.75초) 안에 칼이 꽂힌다.
	  해적은 GameConfig.Catch.MinLead(0.85초)보다 먼저 나오지 않으므로 칼이 꽂히기 전에 해적이 튀어나오는 일은 없다.
	★ 결과에는 아무 영향이 없다. 판정은 서버가 이미 끝낸 뒤에 보여 주는 연출이다.
]]

local TweenService = game:GetService("TweenService")

local StabMotion = {}
StabMotion.MaxDuration = 0.75

local UP = Vector3.new(0, 1, 0)
local TAU = math.pi * 2

local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function outQuad(x)
	return 1 - (1 - x) * (1 - x)
end
local function inQuint(x)
	return x * x * x * x * x
end
local function inOut(x)
	return x * x * (3 - 2 * x)
end

-- 칼이 지나는 자리들. target = 꽂힌 칼의 자리, look = 슬롯 정면(통 안쪽), center = 통 가운데
local function keyframes(ctx)
	local target = ctx.target
	local inward = ctx.look
	local outward = -inward
	local start = target + inward * 0.9 + UP * 0.5
	-- Phase 10 까지의 기본 모션 그대로 (통 위로 들어 올렸다가 비스듬히 꽂는다)
	local raised = target * CFrame.Angles(math.rad(-38), 0, 0) + inward * 2.6 + UP * 1.9
	local high = target * CFrame.Angles(math.rad(-80), 0, 0) + outward * 0.6 + UP * 4.2
	return start, raised, high, outward
end

--------------------------------------------------
-- 모션 계획. 총 길이와 "칼이 닿는 순간들"을 정한다.
--   windup : 부른 쪽이 정하는 뜸 (내 차례 · 긴장도에 따라 0.1 ~ 0.42초)
--------------------------------------------------
local PLANS = {
	classic = function(w)
		return { rise = w, strike = 0.085, hits = { { t = w + 0.085, power = 1 } } }
	end,
	overhead = function(w)
		local rise = w * 1.15 + 0.05
		return { rise = rise, strike = 0.07, hits = { { t = rise + 0.07, power = 1.5 } } }
	end,
	triple = function(w)
		local jab = 0.06
		local rise = math.max(0.12, w * 0.6)
		local jabs = 4 * jab
		return {
			jab = jab, jabs = jabs, rise = rise, strike = 0.08,
			hits = { { t = jab, power = 0.35 }, { t = jab * 3, power = 0.35 }, { t = jabs + rise + 0.08, power = 1.1 } },
		}
	end,
	spin = function(w)
		local rise = math.max(0.3, w * 1.2)
		return { rise = rise, strike = 0.09, hits = { { t = rise + 0.09, power = 1.2 } } }
	end,
	flourish = function(w)
		local rise = 0.46 + w * 0.3
		return { rise = rise, strike = 0.08, hits = { { t = rise + 0.08, power = 1.2 } } }
	end,
	slam = function(w)
		local rise = w * 1.1 + 0.05
		return { rise = rise, hang = 0.1, strike = 0.06, hits = { { t = rise + 0.1 + 0.06, power = 1.8 } } }
	end,
	dive = function(w)
		local rise = 0.5 + w * 0.2
		return { rise = rise, strike = 0.1, hits = { { t = rise + 0.1, power = 1.4 } } }
	end,
}

function StabMotion.plan(style, windup, color)
	local maker = PLANS[style] or PLANS.classic
	local plan = maker(math.clamp(tonumber(windup) or 0.2, 0.05, 0.42))
	plan.style = PLANS[style] and style or "classic"
	plan.total = plan.hits[#plan.hits].t
	plan.color = color
	return plan
end

--------------------------------------------------
-- t 초일 때 칼의 자리
--------------------------------------------------
function StabMotion.knifeAt(plan, t, ctx)
	local start, raised, high, outward = keyframes(ctx)
	local target = ctx.target
	local style = plan.style

	if style == "overhead" or style == "slam" then
		if t < plan.rise then
			return start:Lerp(high, outQuad(t / plan.rise))
		end
		t -= plan.rise
		if plan.hang then
			if t < plan.hang then
				-- 꼭대기에서 잠깐 멈칫한다 (떨림)
				return high * CFrame.new(math.sin(t * 90) * 0.05, 0, 0)
			end
			t -= plan.hang
		end
		return high:Lerp(target, inQuint(clamp01(t / plan.strike)))
	elseif style == "triple" then
		local tip = target + outward * 0.55
		local back = target + outward * 1.9 + UP * 0.5
		if t < plan.jabs then
			local phase = t / plan.jab
			local index = math.floor(phase)
			local a = phase - index
			if index % 2 == 0 then
				return back:Lerp(tip, inQuint(a) * 0.7 + a * 0.3)
			end
			return tip:Lerp(back, outQuad(a))
		end
		t -= plan.jabs
		if t < plan.rise then
			return back:Lerp(raised, outQuad(t / plan.rise))
		end
		return raised:Lerp(target, inQuint(clamp01((t - plan.rise) / plan.strike)))
	elseif style == "spin" then
		if t < plan.rise then
			local a = t / plan.rise
			local pos = start.Position:Lerp(raised.Position + UP * 0.8, outQuad(a))
			local turn = CFrame.Angles(0, TAU * 2 * inOut(a), 0)
			return CFrame.new(pos) * turn * start.Rotation:Lerp(raised.Rotation, a)
		end
		local top = raised + UP * 0.8
		return top:Lerp(target, inQuint(clamp01((t - plan.rise) / plan.strike)))
	elseif style == "flourish" then
		if t < plan.rise then
			local a = t / plan.rise
			local side = outward:Cross(UP)
			if side.Magnitude < 0.01 then
				side = Vector3.new(1, 0, 0)
			end
			local pos = start.Position:Lerp(raised.Position, a) + UP * (5 * 4 * a * (1 - a))
			local flip = CFrame.fromAxisAngle(side.Unit, TAU * 2 * a)
			return CFrame.new(pos) * flip * start.Rotation:Lerp(raised.Rotation, a)
		end
		return raised:Lerp(target, inQuint(clamp01((t - plan.rise) / plan.strike)))
	elseif style == "dive" then
		if t < plan.rise then
			local a = t / plan.rise
			local center = ctx.center or (target.Position + ctx.look * 2)
			local radial = Vector3.new(target.Position.X - center.X, 0, target.Position.Z - center.Z)
			local radius = math.max(radial.Magnitude + 1.8, 3)
			local home = math.atan2(radial.Z, radial.X)
			local angle = home - TAU * (1 - inOut(a))
			local height = (raised.Position.Y - center.Y) * a + 0.8 * (1 - a)
			local pos = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			local flying = CFrame.lookAt(pos, pos + tangent)
			if a > 0.8 then
				return flying:Lerp(raised, (a - 0.8) / 0.2)
			end
			return flying
		end
		return raised:Lerp(target, inQuint(clamp01((t - plan.rise) / plan.strike)))
	end

	-- classic
	if t < plan.rise then
		return start:Lerp(raised, outQuad(t / plan.rise))
	end
	return raised:Lerp(target, inQuint(clamp01((t - plan.rise) / plan.strike)))
end

--------------------------------------------------
-- 사람 몸
--------------------------------------------------

-- R15 · R6 관절을 찾는다.
local function joints(character)
	if not character then
		return nil
	end
	local function find(parentName, jointName)
		local parent = character:FindFirstChild(parentName)
		local joint = parent and parent:FindFirstChild(jointName)
		return (joint and joint:IsA("Motor6D")) and joint or nil
	end
	local r15 = find("RightUpperArm", "RightShoulder")
	if r15 then
		return {
			rig = "R15",
			right = r15,
			left = find("LeftUpperArm", "LeftShoulder"),
			waist = find("UpperTorso", "Waist"),
		}
	end
	local r6 = find("Torso", "Right Shoulder")
	if r6 then
		return {
			rig = "R6",
			right = r6,
			left = find("Torso", "Left Shoulder"),
			waist = find("HumanoidRootPart", "RootJoint"),
		}
	end
	return nil
end

-- 관절의 원래 C0. 모션이 겹쳐도 원래 자세를 잃지 않도록 처음 값을 기억한다.
local homes = setmetatable({}, { __mode = "k" })
local function home(joint)
	if not homes[joint] then
		homes[joint] = joint.C0
	end
	return homes[joint]
end

-- pitch : 팔을 앞으로 드는 각도(0 = 내림, 90 = 앞으로, 170 = 머리 위)
local function armPose(set, side, pitch, spread)
	local joint = side == "right" and set.right or set.left
	if not joint then
		return nil, nil
	end
	local p, s = math.rad(pitch), math.rad(spread or 0)
	local sign = side == "right" and 1 or -1
	if set.rig == "R15" then
		return joint, home(joint) * CFrame.Angles(p, 0, sign * s)
	end
	return joint, home(joint) * CFrame.Angles(-s, 0, sign * p)
end

-- lean : 앞으로 숙이는 각도, twist : 허리 비틀기
local function waistPose(set, lean, twist)
	local joint = set.waist
	if not joint then
		return nil, nil
	end
	local l, w = math.rad(lean or 0), math.rad(twist or 0)
	if set.rig == "R15" then
		return joint, home(joint) * CFrame.Angles(-l, w, 0)
	end
	return joint, home(joint) * CFrame.Angles(l, 0, w)
end

-- 모션별 몸 동작 : { 시작 시각, 걸리는 시간, 오른팔, 왼팔(nil 이면 그대로), 숙임, 비틀기 }
local function bodyFrames(plan)
	local s = plan.style
	local up = plan.rise
	local hit = plan.total
	if s == "overhead" or s == "slam" then
		local hang = plan.hang or 0
		return {
			{ 0, up, 172, 172, -12, 0 },
			{ up + hang, plan.strike, 38, 38, s == "slam" and 30 or 22, 0 },
		}
	elseif s == "triple" then
		local j = plan.jab
		return {
			{ 0, j, 95, nil, 8, -10 }, { j, j, 65, nil, 2, 0 },
			{ 2 * j, j, 100, nil, 10, -12 }, { 3 * j, j, 65, nil, 2, 0 },
			{ plan.jabs, plan.rise, 150, nil, -6, 0 },
			{ plan.jabs + plan.rise, plan.strike, 55, nil, 16, 0 },
		}
	elseif s == "spin" then
		return {
			{ 0, up * 0.5, 120, 60, 0, 35 },
			{ up * 0.5, up * 0.5, 150, 20, -6, -20 },
			{ up, plan.strike, 55, 10, 14, 0 },
		}
	elseif s == "flourish" then
		return {
			{ 0, 0.12, 150, nil, -8, 0 }, -- 던진다
			{ 0.12, up - 0.12, 70, nil, 0, 0 },
			{ up - 0.1, 0.1, 150, nil, -6, 0 }, -- 받는다
			{ up, plan.strike, 55, nil, 16, 0 },
		}
	elseif s == "dive" then
		return {
			{ 0, up * 0.6, 100, 100, 0, 25 }, -- 두 팔로 칼을 조종한다
			{ up * 0.6, up * 0.4, 160, 120, -10, 0 },
			{ up, plan.strike, 45, 30, 24, 0 },
		}
	end
	return {
		{ 0, up, 150, nil, -5, 0 },
		{ up, hit - up, 60, nil, 12, 0 },
	}
end

-- 몸 동작을 튼다. 끝나면 스스로 원래 자세로 돌아간다.
function StabMotion.playBody(character, plan)
	local set = joints(character)
	if not set then
		return
	end
	local touched = {}
	for _, frame in ipairs(bodyFrames(plan)) do
		local at, duration, right, left, lean, twist = frame[1], frame[2], frame[3], frame[4], frame[5], frame[6]
		task.delay(at, function()
			local info = TweenInfo.new(math.max(0.03, duration), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local function go(joint, goal)
				if joint and goal and joint.Parent then
					touched[joint] = true
					TweenService:Create(joint, info, { C0 = goal }):Play()
				end
			end
			go(armPose(set, "right", right, 6))
			if left then
				go(armPose(set, "left", left, 6))
			end
			go(waistPose(set, lean, twist))
		end)
	end
	task.delay(plan.total + 0.4, function()
		for joint in pairs(touched) do
			if joint.Parent then
				TweenService:Create(joint, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = home(joint) }):Play()
			end
		end
	end)
end

-- 상점 미리보기 : 내 캐릭터로 몸 동작만 보여 준다. (내 화면에서만 보인다)
function StabMotion.preview(character, style)
	local plan = StabMotion.plan(style, 0.32)
	StabMotion.playBody(character, plan)
	return plan
end

return StabMotion
