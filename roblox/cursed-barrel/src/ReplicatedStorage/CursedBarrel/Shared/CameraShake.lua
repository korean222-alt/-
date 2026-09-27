--[[
	CameraShake  (Phase 12, 클라이언트 전용)
	크라켄이 갑판을 내려칠 때 · 천둥 · 대포처럼 화면 전체가 흔들리는 연출.

	· 여러 스크립트가 같은 모듈을 require 한다. (클라이언트 안에서는 한 벌만 있다)
	· 카메라를 누가 움직이든(기본 카메라 · 테이블 카메라 · 대포 카메라) 그 위에 흔들림만 더한다.
	  카메라가 계산되기 직전에 지난 프레임의 흔들림을 빼고, 계산된 직후에 새 흔들림을 더한다.
	  그래서 흔들림이 쌓이거나 카메라가 밀려나지 않는다.
	· 설정의 "화면 흔들림"을 끄거나 "연출 줄이기"를 켜면 흔들리지 않는다.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraShake = {}
local impulses = {} -- { power, duration, startedAt, roll }
local applied = CFrame.new()
local bound = false

local function allowed()
	local player = Players.LocalPlayer
	return player and player:GetAttribute("Setting_shake") ~= false and player:GetAttribute("Setting_reducedFX") ~= true
end

-- power : 스터드 단위 흔들림 크기 (0.3 약하게 ~ 1.5 크게), duration : 초, roll : 배가 기우는 느낌(도)
function CameraShake.add(power, duration, roll)
	if not allowed() then
		return
	end
	table.insert(impulses, { power = power, duration = math.max(0.05, duration or 0.4), startedAt = os.clock(), roll = roll or 0 })
	CameraShake.bind()
end

-- 멀리서 일어난 일은 약하게 흔든다
function CameraShake.at(position, power, duration, radius, roll)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	local falloff = math.clamp(1 - distance / (radius or 120), 0, 1)
	if falloff > 0.02 then
		CameraShake.add(power * falloff, duration, (roll or 0) * falloff)
	end
end

local function sample(now)
	local x, y, r = 0, 0, 0
	for index = #impulses, 1, -1 do
		local imp = impulses[index]
		local t = now - imp.startedAt
		if t >= imp.duration then
			table.remove(impulses, index)
		else
			local fade = (1 - t / imp.duration) ^ 2
			x += math.sin(now * 61 + index * 3.1) * imp.power * fade
			y += math.cos(now * 47 + index * 1.7) * imp.power * fade * 0.8
			r += math.sin(t * 9) * imp.roll * fade
		end
	end
	return x, y, r
end

function CameraShake.bind()
	if bound then
		return
	end
	bound = true
	-- 카메라가 계산되기 전 : 지난 흔들림을 뺀다
	RunService:BindToRenderStep("CursedBarrel_ShakeUndo", Enum.RenderPriority.Camera.Value - 1, function()
		local camera = workspace.CurrentCamera
		if camera and applied ~= CFrame.new() then
			camera.CFrame = camera.CFrame * applied:Inverse()
		end
		applied = CFrame.new()
	end)
	-- 카메라가 계산된 뒤 : 새 흔들림을 더한다
	RunService:BindToRenderStep("CursedBarrel_ShakeApply", Enum.RenderPriority.Camera.Value + 20, function()
		local camera = workspace.CurrentCamera
		if not camera or #impulses == 0 then
			return
		end
		if not allowed() then
			table.clear(impulses)
			return
		end
		local x, y, r = sample(os.clock())
		applied = CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(r))
		camera.CFrame = camera.CFrame * applied
	end)
end

return CameraShake
