--[[
	camera_test.lua
	해적이 튀어나올 때 카메라가 정말 해적을 담는지 계산으로 확인한다.

	실행:  luau tests/camera_test.lua   (tests 폴더 안에서)

	Phase4Controller 의 closeShot 함수를 그대로 떼어 와서 돌린다.
	계산식은 한 글자도 고치지 않았다. 화면에 쓰이는 그 코드가 그대로 돌아간다.

	확인하는 것
	  1. 연출이 도는 내내 해적의 머리끝과 발끝이 화면 안에 들어오는가
	  2. 카메라가 해적을 뚫고 지나가지 않는가
	  3. 개인 무대의 검은 벽(29스터드) 밖으로 나가지 않는가
	  4. 테이블 아래로 내려가지 않는가
	  5. 해적의 키가 달라져도(스킨마다 다르다) 버티는가
	  6. Phase 5 의 옛 계산으로는 왜 해적이 안 보였는지
]]

local bundle = require("./bundle")

--------------------------------------------------
-- 계산에 필요한 만큼의 Vector3 · CFrame
--------------------------------------------------
local Vector3 = {}
Vector3.__index = Vector3

local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end

Vector3.new = vec

function Vector3.__add(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function Vector3.__sub(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function Vector3.__mul(a, b)
	if type(b) == "number" then
		return vec(a.X * b, a.Y * b, a.Z * b)
	end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function Vector3.__eq(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
function Vector3.__index(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	end
	if key == "Unit" then
		local length = self.Magnitude
		if length == 0 then
			return vec(0, 0, 0)
		end
		return vec(self.X / length, self.Y / length, self.Z / length)
	end
	return rawget(Vector3, key)
end
function Vector3:Lerp(other, alpha)
	return vec(
		self.X + (other.X - self.X) * alpha,
		self.Y + (other.Y - self.Y) * alpha,
		self.Z + (other.Z - self.Z) * alpha
	)
end
function Vector3:Dot(other)
	return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end

local CFrame = {}
function CFrame.lookAt(eye, target)
	return {
		Position = eye,
		LookVector = (target - eye).Unit,
		Target = target,
	}
end

local camera = bundle["CameraMath"]({ Vector3 = Vector3, CFrame = CFrame })
local SCARE = camera.SCARE

--------------------------------------------------
-- 검사 도구
--------------------------------------------------
local passed, failed = 0, 0
local function check(condition, description)
	if condition then
		passed += 1
		print(("  ✓ %s"):format(description))
	else
		failed += 1
		print(("  ✗ %s"):format(description))
	end
end
local function section(title)
	print("")
	print(title)
end

-- 어떤 점이 화면 안에 들어오는가. 세로 화각의 절반보다 각도가 작으면 들어온다.
local function angleFromCenter(shot, point)
	local toPoint = (point - shot.Position)
	if toPoint.Magnitude < 1e-6 then
		return 0
	end
	local cosine = math.clamp(toPoint.Unit:Dot(shot.LookVector), -1, 1)
	return math.deg(math.acos(cosine))
end

--------------------------------------------------
-- 장면 세팅
--   통 중심 (0, 5, 0), 플레이어는 +Z 쪽에 앉아 있다.
--   pirate() 가 해적을 세우는 지점은 SCARE 값으로 정해진다.
--------------------------------------------------
local barrel = vec(0, 5, 0)
local direction = vec(0, 0, 1)
camera.scene.lid = barrel + vec(0, 2.4, 0)
camera.scene.direction = direction

local function ghostCenter()
	return barrel + direction * SCARE.GhostLunge + vec(0, SCARE.GhostRise, 0)
end

local TOTAL = SCARE.Lead + SCARE.Punch + SCARE.Hold

--------------------------------------------------
section("1. 연출이 도는 내내 해적이 화면 안에 있는가")
--------------------------------------------------

local function sweep(height, label)
	camera.setGhostHeight(height)
	local center = ghostCenter()
	local top = center + vec(0, height * 0.5, 0)
	local bottom = center - vec(0, height * 0.5, 0)

	local worstTop, worstBottom, worstMargin = 0, 0, math.huge
	local closest, farthest = math.huge, 0
	local lowestEye = math.huge

	for step = 0, 60 do
		-- 해적이 실제로 서 있는 구간(들이닥치기 직전부터 끝까지)만 본다.
		local elapsed = SCARE.Lead + (TOTAL - SCARE.Lead) * (step / 60)
		local shot, fov = camera.closeShot(nil, barrel, elapsed)
		local half = fov * 0.5

		worstTop = math.max(worstTop, angleFromCenter(shot, top) / half)
		worstBottom = math.max(worstBottom, angleFromCenter(shot, bottom) / half)
		worstMargin = math.min(worstMargin, half - math.max(angleFromCenter(shot, top), angleFromCenter(shot, bottom)))

		local toGhost = (center - shot.Position).Magnitude
		closest = math.min(closest, toGhost)
		farthest = math.max(farthest, (barrel - shot.Position).Magnitude)
		lowestEye = math.min(lowestEye, shot.Position.Y)
	end

	print(("      %s · 머리끝 %.0f%% / 발끝 %.0f%% (100%% 를 넘으면 화면 밖) · 여유 %.1f도")
		:format(label, worstTop * 100, worstBottom * 100, worstMargin))

	return {
		topRatio = worstTop,
		bottomRatio = worstBottom,
		closest = closest,
		farthest = farthest,
		lowestEye = lowestEye,
	}
end

local normal = sweep(7.2, "보통 키 7.2")
check(normal.topRatio < 1, "해적의 머리끝이 화면 안에 들어온다")
check(normal.bottomRatio < 1, "해적의 발끝이 화면 안에 들어온다")

--------------------------------------------------
section("2. 카메라가 해적을 뚫거나 벽 밖으로 나가지 않는가")
--------------------------------------------------
check(normal.closest > 2.5, ("카메라가 해적에게 %.1f스터드까지만 다가간다"):format(normal.closest))
check(normal.farthest < 28, ("통에서 가장 멀어질 때도 %.1f스터드 (무대 벽 29 안쪽)"):format(normal.farthest))
check(normal.lowestEye >= barrel.Y + SCARE.MinEye - 0.001,
	("카메라 눈높이가 %.1f 까지만 내려간다 (바닥선 %.1f)"):format(normal.lowestEye, barrel.Y + SCARE.MinEye))

--------------------------------------------------
section("3. 해적 키가 달라져도 버티는가 (스킨마다 다르다)")
--------------------------------------------------
for _, height in ipairs({ 5, 6.5, 8, 9.5, 11 }) do
	local result = sweep(height, ("키 %.1f"):format(height))
	check(result.topRatio < 1 and result.bottomRatio < 1, ("키 %.1f 짜리 해적도 화면에 다 들어온다"):format(height))
	check(result.farthest < 28, ("키 %.1f 에서도 무대 벽 안쪽"):format(height))
end

--------------------------------------------------
section("4. 잡기 창이 열리는 순간 해적을 정면으로 보는가")
--------------------------------------------------
camera.setGhostHeight(7.2)
local center = ghostCenter()
-- 잡기 창은 들이닥치기가 끝나는 순간(Lead + Punch)에 열린다.
local openShot = camera.closeShot(nil, barrel, SCARE.Lead + SCARE.Punch + 0.01)
local offCenter = angleFromCenter(openShot, center)
check(offCenter < 8, ("창이 열리는 순간 해적이 화면 한가운데에서 %.1f도 안에 있다"):format(offCenter))

local holdShot = camera.closeShot(nil, barrel, SCARE.Lead + SCARE.Punch + SCARE.Hold * 0.5)
check(angleFromCenter(holdShot, center) < 8, "잡는 동안에도 계속 해적을 본다")

--------------------------------------------------
section("5. 파고드는 동안에는 통을 본다")
--------------------------------------------------
local earlyShot = camera.closeShot(nil, barrel, 0.02)
local toBarrel = angleFromCenter(earlyShot, barrel + vec(0, 2.4, 0))
check(toBarrel < 30, ("시작할 때는 통 뚜껑 쪽을 본다 (%.1f도)"):format(toBarrel))
check((barrel - earlyShot.Position).Magnitude > 9, "시작 거리는 충분히 멀다 (갑자기 코앞에서 시작하지 않는다)")

--------------------------------------------------
section("6. Phase 5 의 옛 계산은 왜 해적을 놓쳤나")
--------------------------------------------------
-- 옛 코드 (참고용으로만 다시 적었다. 지금 게임에서는 쓰이지 않는다):
--   anchor = 통 뚜껑 위
--   eye    = anchor + 나를 향한 방향 * 2.3 + (0, -0.35, 0)
--   보는 곳 = anchor + (0, 1.6, 0),  화각 94도
local oldAnchor = barrel + vec(0, 2.4, 0)
local oldEye = oldAnchor + direction * 2.3 + vec(0, -0.35, 0)
local oldShot = CFrame.lookAt(oldEye, oldAnchor + vec(0, 1.6, 0))
local oldHalf = 94 * 0.5
local oldTop = angleFromCenter(oldShot, center + vec(0, 7.2 * 0.5, 0))
local oldBottom = angleFromCenter(oldShot, center - vec(0, 7.2 * 0.5, 0))

print(("      옛 계산 · 머리끝 %.0f%% / 발끝 %.0f%% (100%% 를 넘으면 화면 밖)")
	:format(oldTop / oldHalf * 100, oldBottom / oldHalf * 100))
print(("      옛 계산 · 카메라와 해적 사이 거리 %.1f스터드 (해적 안에 들어가 있다)")
	:format((center - oldEye).Magnitude))

check(oldBottom > oldHalf, "옛 계산에서는 해적의 아랫몸이 화면 밖으로 잘려 나갔다")
check((center - oldEye).Magnitude < normal.closest * 0.5,
	("옛 계산은 지금보다 두 배 이상 가까웠다 (%.1f 스터드 vs 지금 %.1f)")
		:format((center - oldEye).Magnitude, normal.closest))
check(oldTop / oldHalf > 0.85,
	("옛 계산에서는 머리끝이 화면 가장자리(%.0f%%)에 걸려 있었다"):format(oldTop / oldHalf * 100))

--------------------------------------------------
print("")
print(("결과: %d개 통과, %d개 실패"):format(passed, failed))
if failed > 0 then
	error(("테스트 %d개 실패"):format(failed), 0)
end
