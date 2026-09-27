-- 1인칭 손(FirstPersonHands)의 자세를 가짜 장면에서 검사한다.
--   · 가만히 · 내 차례일 때 주먹과 칼끝이 화면 안(FOV 74, 16:9)에 보이는가
--   · 모션 여덟 가지로 찌를 때 : 끝나면 칼이 슬롯 칼 자리(target)에 딱 놓이는가, 팔이 닿는가(늘어남 15% 이하), NaN 이 없는가
--   · 찌르는 동안 칼이 카메라 뒤로 넘어가지 않는가
-- 사용 : lune run tests/fp_hands.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Color3, Enum = roblox.CFrame, roblox.Vector3, roblox.Color3, roblox.Enum

local SRC = "src/ReplicatedStorage/CursedBarrel/Shared/FirstPersonHands.lua"

-- ★ Lune 0.10 의 CFrame.lookAt 은 Roblox 와 반대쪽을 본다 (LookVector 가 목표 반대). 검사 장면은 직접 만든다
local function lookAt(pos, at)
	local fwd = (at - pos).Unit
	local right = fwd:Cross(Vector3.new(0, 1, 0)).Unit
	local up = right:Cross(fwd)
	return CFrame.fromMatrix(pos, right, up, -fwd)
end

--------------------------------------------------
-- 가짜 Instance (필요한 것만)
--------------------------------------------------
local BASEPART = { Part = true, WedgePart = true }
local methods = {}
local function new(class)
	local props = { ClassName = class, Name = class, _children = {}, CFrame = CFrame.new(), Size = Vector3.new(1, 1, 1) }
	local o
	o = setmetatable({}, {
		__index = function(_, k)
			if props[k] ~= nil then
				return props[k]
			end
			return methods[k]
		end,
		__newindex = function(_, k, v)
			if k == "Parent" then
				local old = props.Parent
				if old then
					local list = old._children
					for i, c in ipairs(list) do
						if c == o then
							table.remove(list, i)
							break
						end
					end
				end
				if v then
					table.insert(v._children, o)
				end
			end
			props[k] = v
		end,
	})
	return o
end
function methods:IsA(name)
	if name == "BasePart" then
		return BASEPART[self.ClassName] == true
	end
	return self.ClassName == name
end
function methods:GetChildren()
	return table.clone(self._children)
end
function methods:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in ipairs(n._children) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods:FindFirstChild(name)
	for _, c in ipairs(self._children) do
		if c.Name == name then
			return c
		end
	end
	return nil
end
function methods:Destroy()
	self.Parent = nil
end
function methods:GetPivot()
	return self.PrimaryPart and self.PrimaryPart.CFrame or CFrame.new()
end
function methods:PivotTo(cf)
	local delta = cf * self:GetPivot():Inverse()
	for _, d in ipairs(self:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end
function methods:WaitForChild(name)
	return name
end
function methods:GetAttribute()
	return nil
end

local T = 0
local camera = new("Camera")
local workspaceStub = { CurrentCamera = camera }
local player = new("Player")
player.Character = nil

local stubs = {
	GameConfig = {
		SlotLayout = { BladeSize = Vector3.new(0.12, 0.5, 1.6), HandleSize = Vector3.new(0.26, 0.34, 0.7) },
		Skins = { PlayerAttributes = { Knife = "KnifeSkin" } },
		findSkin = function()
			return { blade = Color3.fromRGB(200, 200, 210), handle = Color3.fromRGB(60, 40, 30), guard = Color3.fromRGB(120, 100, 60) }
		end,
	},
	MeshKit = { hasKnife = function()
		return false
	end },
	SkinFX = { applyKnife = function() end },
}
local env = {
	game = { GetService = function()
		return {}
	end },
	script = { Parent = setmetatable({}, { __index = { WaitForChild = function(_, n)
		return n
	end } }) },
	require = function(name)
		return stubs[name]
	end,
	workspace = workspaceStub,
	Instance = { new = new },
	CFrame = CFrame, Vector3 = Vector3, Color3 = Color3, Enum = Enum,
	os = { clock = function()
		return T
	end },
}
setmetatable(env, { __index = _G })
for k, v in pairs(_G) do
	if env[k] == nil then
		env[k] = v
	end
end
local Hands = luau.load(fs.readFile(SRC), { environment = env, debugName = "FirstPersonHands" })()

--------------------------------------------------
-- 장면 : place 파일의 테이블과 같게. 통 가운데 (0, 0, 0) · 반지름 1.75 · 슬롯 줄 ±0.62
--   자리는 통에서 수평 5.6(2인) · 6.6(4인), 의자 윗면은 통 가운데보다 3.23 아래 → 앉은 눈은 통 가운데 높이쯤
--------------------------------------------------
local center = Vector3.new(0, 0, 0)
local SEAT_DISTANCES = { 5.6, 6.6 }
local eye = Vector3.new(0, 0.15, 6.6)
local look = center + Vector3.new(0, 2.35 * 0.55 + 1.1, 0)
local function slotTarget(angleDeg, ringY)
	local a = math.rad(angleDeg)
	local outward = Vector3.new(math.sin(a), 0, math.cos(a))
	local pos = center + Vector3.new(0, ringY, 0) + outward * 1.75
	local spot = lookAt(pos, pos - outward) -- LookVector = 통 안쪽 · +Z = 바깥
	return spot * CFrame.Angles(math.rad(-14), 0, 0) * CFrame.new(0, 0, 0.2)
end

local failed = 0
local function check(cond, msg)
	if not cond then
		failed += 1
		print("  ✗ " .. msg)
	end
end
local function finite(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6
end
local function inView(cam, p, margin)
	local l = cam:PointToObjectSpace(p)
	if l.Z >= -0.2 then
		return false
	end
	local d = -l.Z
	local halfH, halfW = math.tan(math.rad(37)) * d, math.tan(math.rad(37)) * d * 16 / 9
	return math.abs(l.Y) <= halfH * (margin or 1) and math.abs(l.X) <= halfW * (margin or 1)
end

local function fistOf(h)
	return h.fistR.model.PrimaryPart.CFrame.Position
end
local function knifeTip(knifeCF)
	return (knifeCF * CFrame.new(0, 0, -0.8)).Position
end

local function step(h, dt)
	T += dt
	h:update(dt)
end

local function placeCamera(h, dt)
	-- Phase4Controller 와 같다 : 눈 + 숙이기, 방향은 그대로, 매 프레임 1 - exp(-dt*14) 로 따라간다
	local want = lookAt(eye + h.leanVector, eye + h.leanVector + (look - eye))
	local alpha = dt and (1 - math.exp(-dt * 14)) or 1
	camera.CFrame = camera.CFrame:Lerp(want, alpha)
end

local function fresh()
	T = 0
	local h = Hands.new(player)
	placeCamera(h)
	h.want = true
	for _ = 1, 90 do
		step(h, 1 / 60)
	end
	return h
end

print("가만히 · 내 차례")
do
	local h = fresh()
	local cam = camera.CFrame
	local knife = h.knife:GetPivot()
	print(("  주먹 화면 좌표 %s · 칼끝 %s"):format(tostring(cam:PointToObjectSpace(fistOf(h))), tostring(cam:PointToObjectSpace(knifeTip(knife)))))
	check(inView(cam, fistOf(h), 0.95), "가만히 : 주먹이 화면 안에 보인다")
	check(inView(cam, knifeTip(knife), 0.95), "가만히 : 칼끝이 화면 안에 보인다")
	h.ready = true
	for _ = 1, 60 do
		step(h, 1 / 60)
	end
	check(inView(cam, fistOf(h), 0.95), "내 차례 : 주먹이 화면 안에 보인다")
	check(inView(cam, knifeTip(h.knife:GetPivot()), 0.95), "내 차례 : 칼끝이 화면 안에 보인다")
end

local StabPlans = {
	classic = function(w)
		return { rise = w, strike = 0.085, hits = { { t = w + 0.085 } } }
	end,
	overhead = function(w)
		local rise = w * 1.15 + 0.05
		return { rise = rise, strike = 0.07, hits = { { t = rise + 0.07 } } }
	end,
	triple = function(w)
		local jab = 0.06
		local rise = math.max(0.12, w * 0.6)
		return { jab = jab, jabs = 4 * jab, rise = rise, strike = 0.08, hits = { { t = jab }, { t = jab * 3 }, { t = 4 * jab + rise + 0.08 } } }
	end,
	spin = function(w)
		local rise = math.max(0.3, w * 1.2)
		return { rise = rise, strike = 0.09, hits = { { t = rise + 0.09 } } }
	end,
	flourish = function(w)
		local rise = 0.46 + w * 0.3
		return { rise = rise, strike = 0.08, hits = { { t = rise + 0.08 } } }
	end,
	slam = function(w)
		local rise = w * 1.1 + 0.05
		return { rise = rise, hang = 0.1, strike = 0.06, hits = { { t = rise + 0.16 } } }
	end,
	dive = function(w)
		local rise = 0.5 + w * 0.2
		return { rise = rise, strike = 0.1, hits = { { t = rise + 0.1 } } }
	end,
	bolt = function(w)
		local rise = math.max(0.22, w * 0.9)
		return { rise = rise, strike = 0.07, hits = { { t = rise + 0.07 } } }
	end,
}

print("모션 여덟 가지 × 슬롯 여러 곳")
local REACH = Hands.Reach
for _, style in { "classic", "overhead", "triple", "spin", "flourish", "slam", "dive", "bolt" } do
	local worstStretch, behind, nan, endErr, inside = 0, 0, 0, 0, 0
	for _, seatDistance in SEAT_DISTANCES do
	eye = Vector3.new(0, 0.15, seatDistance)
	for _, angle in { -60, -25, 0, 25, 60, 110, 180, -135 } do
		for _, ringY in { -0.62, 0.62 } do
			local h = fresh()
			local plan = StabPlans[style](0.3)
			plan.style = style
			plan.total = plan.hits[#plan.hits].t
			local copy = new("Model")
			copy.Parent = new("Folder")
			local blade = new("Part")
			blade.Parent = copy
			copy.PrimaryPart = blade
			local target = slotTarget(angle, ringY)
			local ctx = { target = target, look = -(target.Position - center).Unit, center = center }
			assert(h:takeStab(copy, ctx, plan, 0.12), "takeStab 이 1인칭에서 true")
			local t0 = T
			while T - t0 < plan.total + 1.0 do
				-- 카메라는 몸 숙이기(lean)만큼 앞으로 나간다 (Phase4Controller 와 같게)
				placeCamera(h, 1 / 120)
				step(h, 1 / 120)
				local cam = camera.CFrame
				local fist = fistOf(h)
				local knifeCF = copy:GetPivot()
				if not finite(fist) or not finite(knifeCF.Position) then
					nan += 1
				end
				local shoulder = (cam * Hands.Shoulder)
				worstStretch = math.max(worstStretch, (fist - shoulder).Magnitude / REACH)
				if T - t0 < plan.total and cam:PointToObjectSpace(knifeCF.Position).Z > -0.3 then
					behind += 1
				end
				-- 꽂히기 직전(마지막 0.04초)까지 칼 가운데가 통(반지름 1.75 · 높이 ±2) 속에 들어가지 않는다
				local kp = knifeCF.Position - center
				if T - t0 < plan.total - 0.04 and math.sqrt(kp.X * kp.X + kp.Z * kp.Z) < 1.75 and math.abs(kp.Y) < 2 then
					inside += 1
				end
			end
			local final = copy:GetPivot()
			endErr = math.max(endErr, (final.Position - target.Position).Magnitude, (final.LookVector - target.LookVector).Magnitude)
		end
	end
	end
	print(("  %-9s 팔 늘어남 최대 %.2f · 칼이 카메라 뒤 %d · 통 속 %d · 끝 자리 오차 %.4f · NaN %d"):format(style, worstStretch, behind, inside, endErr, nan))
	check(inside == 0, style .. " : 칼이 통 속을 지나가지 않는다 (던지기 포함)")
	check(nan == 0, style .. " : NaN 없음")
	check(endErr < 1e-3, style .. " : 끝나면 칼이 슬롯 칼 자리에 딱 놓인다")
	check(worstStretch <= 1.15, style .. " : 팔이 닿는다 (늘어남 15% 이하)")
	check(behind == 0, style .. " : 칼이 카메라 뒤로 넘어가지 않는다")
end

print("잡기 · 우승 · 탈락 · 3인칭으로")
do
	local h = fresh()
	h:grab()
	for _ = 1, 30 do
		step(h, 1 / 60)
	end
	check(h.action == nil, "잡기 휘두르기는 0.34초 안에 끝난다")
	h:cheer()
	for _ = 1, 60 do
		step(h, 1 / 60)
	end
	check(inView(camera.CFrame, knifeTip(h.knife:GetPivot()), 1), "우승 : 치켜든 칼이 보인다")
	for _ = 1, 90 do
		step(h, 1 / 60)
	end
	h:drop()
	for _ = 1, 60 do
		step(h, 1 / 60)
	end
	check(h.dropped == true and not inView(camera.CFrame, fistOf(h), 1), "탈락 : 손이 화면 밖으로 떨어진다")
	h.want = false
	step(h, 1 / 60)
	check(h.root.Parent == nil and h.dropped == false, "3인칭 · 자리를 뜨면 손을 치운다")
end

print(failed == 0 and "통과" or ("실패 " .. failed))
if failed > 0 then
	error("1인칭 손 검사 실패")
end
