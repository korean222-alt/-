-- 절차적 애니메이션: 상태(대기/걷기/공격/기절/탈진)와 시간으로 뼈 포즈를 계산한다.
-- 블렌더 리그와 파트 리그가 같은 뼈 이름을 쓰므로 이 파일 하나로 모두 움직인다.
local Anim = {}

local sin, cos, rad, clamp = math.sin, math.cos, math.rad, math.clamp
local ANG = CFrame.Angles

-- 다리 위상: 대각선 다리가 같이 움직이는 네발 걸음 (FL+BR / FR+BL), 가운데 다리는 그 사이
local LEG_PHASE = {LegFL = 0, LegBR = 0, LegFR = math.pi, LegBL = math.pi, LegML = math.pi, LegMR = 0, LegL = 0, LegR = math.pi}

-- 종별 성격: 걷는 방식과 과장 정도
local STYLE = {
	Mossling = {Hop = 0.22, Stride = 34, Wag = 18, Bounce = 1.2},
	Emberpup = {Hop = 0.08, Stride = 38, Wag = 28, Bounce = 1.0},
	Shellbub = {Hop = 0.0, Stride = 26, Wag = 14, Bounce = 0.7, Waddle = 7},
	Briarhorn = {Hop = 0.0, Stride = 30, Wag = 12, Bounce = 0.6},
	Mossdeer = {Hop = 0.05, Stride = 36, Wag = 10, Bounce = 0.6},
	Ashlizard = {Hop = 0.0, Stride = 40, Wag = 30, Bounce = 0.5, Waddle = 9},
	Bogtoad = {Hop = 0.3, Stride = 20, Wag = 0, Bounce = 1.4, Waddle = 4},
	Crawler = {Hop = 0.0, Stride = 30, Wag = 0, Bounce = 0.5, Skitter = true},
	Runner = {Hop = 0.1, Stride = 42, Wag = 20, Bounce = 0.8},
	Brute = {Hop = 0.0, Stride = 22, Wag = 0, Bounce = 0.6, Stomp = true},
	Howler = {Hop = 0.0, Stride = 30, Wag = 10, Bounce = 0.6},
}

-- s: {Kind, Time, Speed(0..1), Attack(0..1 진행, 없으면 nil), Faint, Exhausted, Height, Phase(개체별), Night}
-- 반환: pose 테이블, 몸 전체 오프셋 CFrame (뛰기, 기울기)
function Anim.pose(s)
	local style = STYLE[s.Kind] or STYLE.Mossling
	local t = s.Time + s.Phase
	local h = s.Height
	local move = clamp(s.Speed, 0, 1)
	local idle = 1 - move
	local pose = {}
	local whole = CFrame.identity

	if s.Faint then
		-- 옆으로 누워서 숨만 쉰다
		pose.Body = CFrame.new(0, -h * 0.05, 0)
		pose.Head = ANG(rad(-15), 0, rad(10))
		for name in pairs(LEG_PHASE) do
			pose[name] = ANG(rad(25), 0, 0)
		end
		pose.EarL, pose.EarR = ANG(0, 0, rad(40)), ANG(0, 0, rad(-40))
		whole = CFrame.new(0, h * 0.22, 0) * ANG(0, 0, rad(80 + sin(t * 2) * 2))
		return pose, whole
	end

	local cycle = t * (7 + move * 5)
	-- 걷기: 다리 흔들기 + 몸 들썩
	local stride = rad(style.Stride) * move
	for name, phase in pairs(LEG_PHASE) do
		local swing = sin(cycle + phase)
		if style.Skitter then
			pose[name] = ANG(swing * stride * 0.6, swing * stride * 0.5, 0)
		else
			pose[name] = ANG(swing * stride, 0, 0)
		end
	end
	local bob = math.abs(sin(cycle)) * h * 0.035 * move * style.Bounce
	local breathe = sin(t * 2.2) * h * 0.012 * idle
	pose.Body = CFrame.new(0, bob + breathe, 0) * ANG(0, 0, sin(cycle) * rad(style.Waddle or 3) * move)
	if style.Stomp then
		pose.ArmL = ANG(sin(cycle + math.pi) * stride * 0.8, 0, rad(-6))
		pose.ArmR = ANG(sin(cycle) * stride * 0.8, 0, rad(6))
	end

	-- 머리: 가만히 있으면 두리번, 걸으면 끄덕
	local look = idle * (sin(t * 0.7) * rad(18) + sin(t * 1.9) * rad(5))
	local nod = sin(cycle * 2) * rad(4) * move + sin(t * 1.3) * rad(3) * idle
	pose.Head = ANG(nod, look, sin(t * 0.9) * rad(4) * idle)
	pose.Neck = ANG(nod * 0.5, look * 0.4, 0)

	-- 꼬리·귀·아가미·새싹
	local wag = sin(t * (5 + move * 6)) * rad(style.Wag)
	pose.Tail = ANG(rad(6) * sin(t * 1.5), wag, 0)
	pose.Tail1 = ANG(rad(-6) + sin(t * 1.7) * rad(4), wag * 0.6, 0)
	pose.Tail2 = ANG(sin(t * 2.1 + 1) * rad(6), wag, 0)
	local twitch = (math.floor(t * 0.5) % 4 == 0) and sin(t * 30) * rad(8) or 0
	local flop = sin(cycle * 2) * rad(10) * move
	pose.EarL = ANG(0, 0, flop + twitch + sin(t * 1.4) * rad(3))
	pose.EarR = ANG(0, 0, -flop - sin(t * 1.4 + 0.5) * rad(3))
	pose.GillL = ANG(0, sin(t * 3) * rad(10), sin(t * 2.4) * rad(12))
	pose.GillR = ANG(0, -sin(t * 3) * rad(10), -sin(t * 2.4 + 0.3) * rad(12))
	pose.Sprout = ANG(sin(t * 2.6) * rad(10), 0, sin(t * 1.8) * rad(14))

	-- 통통 뛰는 종 (모슬링)
	if style.Hop > 0 and move > 0.05 then
		local hop = math.abs(sin(cycle * 0.5)) * h * style.Hop * move
		whole = CFrame.new(0, hop, 0)
	end

	-- 탈진 (포획 가능): 비틀비틀, 머리가 빙글
	if s.Exhausted then
		pose.Head = ANG(rad(-12) + sin(t * 3) * rad(8), cos(t * 3) * rad(14), sin(t * 3) * rad(10))
		pose.Body = CFrame.new(0, -h * 0.06, 0) * ANG(0, 0, sin(t * 2) * rad(7))
		pose.EarL, pose.EarR = ANG(0, 0, rad(35)), ANG(0, 0, rad(-35))
		whole = CFrame.identity
	end

	-- 공격: 뒤로 움츠렸다가 앞으로 확 달려든다
	if s.Attack then
		local a = s.Attack
		local wind = a < 0.35 and (a / 0.35) or 1 - (a - 0.35) / 0.65
		local strike = a >= 0.35 and sin((a - 0.35) / 0.65 * math.pi) or 0
		local lunge = -strike * h * 0.35 + wind * h * 0.06 * (a < 0.35 and 1 or 0)
		pose.Body = (pose.Body or CFrame.identity) * CFrame.new(0, 0, lunge) * ANG(rad(-14) * strike + rad(8) * (a < 0.35 and wind or 0), 0, 0)
		pose.Head = ANG(rad(-18) * strike, 0, 0)
		pose.LegFL = ANG(rad(40) * strike, 0, 0)
		pose.LegFR = ANG(rad(40) * strike, 0, 0)
		if style.Stomp then
			pose.ArmL = ANG(rad(-120) * wind + rad(60) * strike, 0, rad(-10))
			pose.ArmR = ANG(rad(-120) * wind + rad(60) * strike, 0, rad(10))
		end
		if s.Kind == "Howler" then
			pose.Head = ANG(rad(35) * wind, 0, 0)
		end
	end
	return pose, whole
end

return Anim
