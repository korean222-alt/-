-- 공격 버튼을 눌렀을 때의 팔 동작 (코드로 만든 절차적 애니메이션).
-- 예전에는 기본 Animate 의 "찌르기(Lunge)" 하나로 도끼·곡괭이·음식까지 모두 칼처럼 찔렀다.
--  Chop  : 도끼·곡괭이·횃불 — 머리 위로 들었다가 앞으로 내려찍기
--  Stab  : 창 — 비스듬히 세워 든 창을 살짝 뒤로 당겼다가, 팔을 내리며(창이 앞으로 눕는다) 몸을 틀어 앞으로 찌르기
--  Punch : 맨손 — 주먹 뻗기          Eat : 입으로 두 번          Throw : 크게 들었다가 던지기          Give : 앞으로 내밀기
-- 방법: 기본 애니메이션이 매 프레임 관절(Motor6D.Transform)을 쓴 다음(RunService.Stepped) 그 위에 어깨 회전·팔 밀기·허리 비틀기를 덧입힌다.
-- 내 캐릭터는 누르는 즉시 재생하고(반응 속도), 다른 사람 것은 서버 FX("Swing") 를 받아 각자 화면에서 재생한다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local S = {}
S.Active = {}

-- 키프레임: {시간(초), 어깨 들기(도, + = 위로), 팔 밀기(stud, + = 앞으로), 허리 비틀기(도)}
local MOTIONS = {
	-- 내려찍기: 크게 들어 올려 허리를 뒤로 비틀고 → 빠르게 내려찍으며 몸을 앞으로 → 잠깐 멈춤(맞는 느낌) → 제자리
	Chop = {{0, 0, 0, 0}, {0.14, 88, -0.35, -22}, {0.24, -66, 0.5, 18}, {0.32, -60, 0.45, 16}, {0.52, 0, 0, 0}},
	-- 찌르기: 창을 든 팔을 살짝 올려 당기고 → 팔을 -58° 내리면 세운 창(-62°)이 거의 수평이 되어 앞으로 쭉 → 돌아오기
	Stab = {{0, 0, 0, 0}, {0.1, 14, -0.7, -14}, {0.2, -58, 1.7, 16}, {0.28, -56, 1.6, 14}, {0.46, 0, 0, 0}},
	Punch = {{0, 0, 0, 0}, {0.08, 25, -0.2, -12}, {0.18, 85, 0.7, 14}, {0.4, 0, 0, 0}},
	Eat = {{0, 0, 0, 0}, {0.14, 48, -0.5, 0}, {0.26, 32, -0.5, 0}, {0.38, 48, -0.5, 0}, {0.6, 0, 0, 0}},
	Throw = {{0, 0, 0, 0}, {0.16, 100, -0.5, -20}, {0.3, -28, 0.7, 16}, {0.56, 0, 0, 0}},
	Give = {{0, 0, 0, 0}, {0.16, 12, 0.9, 6}, {0.3, 12, 0.9, 6}, {0.5, 0, 0, 0}},
}
S.Motions = MOTIONS

local function smooth(t)
	return t * t * (3 - 2 * t)
end

-- 시간 t 의 (들기, 밀기, 비틀기)
function S.sample(name, t)
	local keys = MOTIONS[name] or MOTIONS.Chop
	if t >= keys[#keys][1] then
		return 0, 0, 0, true
	end
	for i = 2, #keys do
		local b = keys[i]
		if t <= b[1] then
			local a = keys[i - 1]
			local k = smooth((t - a[1]) / math.max(1e-3, b[1] - a[1]))
			return a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k, false
		end
	end
	return 0, 0, 0, true
end

-- R15: 어깨 관절 축이 몸통과 같다 (X 축으로 돌리면 팔이 앞뒤로, -Z 가 앞)
-- R6 : "Right Shoulder" 의 C0 가 Y 로 90° 돌아 있어서 관절 Z = 몸통 X, 관절 X = 몸통 앞
local function joints(character)
	local shoulder = character:FindFirstChild("RightShoulder", true)
	if shoulder and shoulder:IsA("Motor6D") then
		local waist = character:FindFirstChild("Waist", true)
		return {Shoulder = shoulder, Waist = waist and waist:IsA("Motor6D") and waist or nil, R6 = false}
	end
	shoulder = character:FindFirstChild("Right Shoulder", true)
	if shoulder and shoulder:IsA("Motor6D") then
		return {Shoulder = shoulder, R6 = true}
	end
	return nil
end

local function offset(r6, raise, push)
	if r6 then
		return CFrame.new(push, 0, 0) * CFrame.Angles(0, 0, math.rad(raise))
	end
	return CFrame.new(0, 0, -push) * CFrame.Angles(math.rad(raise), 0, 0)
end

-- 애니메이션이 이번 프레임에 관절을 새로 썼으면 그 값을, 안 썼으면(우리가 쓴 값이 그대로면) 기억해 둔 값을 바탕으로 쓴다
local function apply(entry, key, motor, extra)
	local current = motor.Transform
	local base = (entry.Applied[key] and current == entry.Applied[key]) and entry.Base[key] or current
	entry.Base[key] = base
	local value = extra * base
	motor.Transform = value
	entry.Applied[key] = value
end

local function restore(entry)
	for key, motor in pairs({Shoulder = entry.Joints.Shoulder, Waist = entry.Joints.Waist}) do
		if motor and entry.Applied[key] and motor.Transform == entry.Applied[key] then
			motor.Transform = entry.Base[key]
		end
	end
end

function S:Init(remotes)
	self.LocalAt = -math.huge
	RunService.Stepped:Connect(function() self:Step() end)
	remotes.FX.OnClientEvent:Connect(function(kind, who, motion)
		if kind ~= "Swing" or typeof(who) ~= "Instance" then return end
		-- 내 동작은 이미 눌렀을 때 재생했다. 단 서버가 다른 동작을 정했으면(창을 들고 나무를 치면 내려찍기) 그걸로 바꾼다
		if who == Players.LocalPlayer and os.clock() - self.LocalAt < 0.45 and motion == self.LocalMotion then return end
		if who.Character then self:Play(who.Character, motion) end
	end)
end

function S:Play(character, motion, isLocal)
	if not character or not MOTIONS[motion] then return false end
	local rig = joints(character)
	if not rig then return false end
	local old = self.Active[character]
	if old then restore(old) end
	self.Active[character] = {Motion = motion, Start = os.clock(), Joints = rig, Base = {}, Applied = {}}
	if isLocal then self.LocalAt, self.LocalMotion = os.clock(), motion end
	return true
end

function S:Step()
	local now = os.clock()
	for character, entry in pairs(self.Active) do
		local shoulder = entry.Joints.Shoulder
		local raise, push, twist, done = S.sample(entry.Motion, now - entry.Start)
		if done or not character.Parent or not shoulder.Parent then
			restore(entry)
			self.Active[character] = nil
		else
			apply(entry, "Shoulder", shoulder, offset(entry.Joints.R6, raise, push))
			if entry.Joints.Waist then
				apply(entry, "Waist", entry.Joints.Waist, CFrame.Angles(0, math.rad(twist), 0))
			end
		end
	end
end

return S
