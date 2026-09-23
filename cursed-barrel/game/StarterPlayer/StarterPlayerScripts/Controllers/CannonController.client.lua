-- CannonController  (Phase 12)
-- 대포 미니게임의 화면 쪽. 판정은 서버(CannonService)가 한다.
--
--   · 뱃전 대포에 다가가 E(모바일은 탭)를 누르면 대포를 잡는다. 카메라가 대포 뒤로 간다.
--   · 조준 : PC 는 A·D(←·→)로 좌우, W·S 로 위아래, 마우스 클릭으로 발사.
--            모바일은 화면을 끌어 돌리고, 과녁을 탭하면 발사. 게임패드는 스틱으로 돌리고 R2/A 로 발사.
--   · 과녁 : 다리의 빛나는 약점 · 크라켄의 눈 · (습격 때) 치켜든 다리. 화면에 동그라미로 표시한다.
--            과녁 근처를 누르면 그 과녁을 겨눈다. (작은 화면에서도 맞히기 쉽게)
--   · 내리기 : 버튼 · 스페이스 · 게임패드 B. 대포에서 멀어지면 서버가 알아서 내려 준다.
--   · 누가 쏘든 포구 섬광 · 포탄 · 물보라 · 명중 연출은 모두에게 보인다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Input = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local package = RS:WaitForChild("CursedBarrel")
local config = require(package.Shared:WaitForChild("GameConfig"))
local T = require(package.Shared:WaitForChild("KrakenTargets"))
local CameraShake = require(package.Shared:WaitForChild("CameraShake"))
local Sfx = require(package.Shared:WaitForChild("Sfx"))
local remotes = package:WaitForChild("Remotes")
local cannonRequest = remotes:WaitForChild(config.Remotes.CannonRequest)
local cannonCue = remotes:WaitForChild(config.Remotes.CannonCue)
local worldCue = remotes:WaitForChild(config.Remotes.WorldCue)

local CANNON = config.Cannon
local gold = Color3.fromRGB(255, 206, 110)
local cream = Color3.fromRGB(244, 231, 198)
local teal = Color3.fromRGB(120, 255, 214)
local red = Color3.fromRGB(255, 96, 78)

local aiming = nil -- { cannon, muzzle, outward, yaw, pitch }
local lastFire = 0
local slams = {} -- [id] = slam (습격 때 치켜든 다리)
local ACTION = "CursedBarrel_CannonAim"

local function reduced()
	return player:GetAttribute("Setting_reducedFX") == true
end

--------------------------------------------------
-- 화면
--------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CursedBarrel_Cannon"
gui.ResetOnSpawn = false
gui.DisplayOrder = 16
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 0.35
hint.BackgroundColor3 = Color3.fromRGB(14, 20, 30)
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -24)
hint.Size = UDim2.fromOffset(560, 46)
hint.Font = Enum.Font.GothamBold
hint.TextSize = 14
hint.TextColor3 = cream
hint.TextWrapped = true
hint.Parent = gui
Instance.new("UICorner", hint).CornerRadius = UDim.new(0, 10)
local hintCap = Instance.new("UISizeConstraint")
hintCap.MaxSize = Vector2.new(560, 46)
hintCap.Parent = hint

local reload = Instance.new("Frame")
reload.AnchorPoint = Vector2.new(0.5, 1)
reload.Position = UDim2.new(0.5, 0, 1, -76)
reload.Size = UDim2.fromOffset(220, 8)
reload.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
reload.Parent = gui
Instance.new("UICorner", reload).CornerRadius = UDim.new(0, 4)
local reloadFill = Instance.new("Frame")
reloadFill.Size = UDim2.fromScale(1, 1)
reloadFill.BackgroundColor3 = gold
reloadFill.Parent = reload
Instance.new("UICorner", reloadFill).CornerRadius = UDim.new(0, 4)

local leaveButton = Instance.new("TextButton")
leaveButton.AnchorPoint = Vector2.new(1, 1)
leaveButton.Position = UDim2.new(1, -16, 1, -24)
leaveButton.Size = UDim2.fromOffset(110, 46)
leaveButton.BackgroundColor3 = Color3.fromRGB(70, 30, 30)
leaveButton.TextColor3 = cream
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 16
leaveButton.Text = "내리기"
leaveButton.Parent = gui
Instance.new("UICorner", leaveButton).CornerRadius = UDim.new(0, 10)

local reticle = Instance.new("Frame")
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Size = UDim2.fromOffset(34, 34)
reticle.BackgroundTransparency = 1
reticle.Parent = gui
local reticleStroke = Instance.new("UIStroke")
reticleStroke.Color = gold
reticleStroke.Thickness = 2
reticleStroke.Parent = reticle
Instance.new("UICorner", reticle).CornerRadius = UDim.new(1, 0)

local markers = {} -- 과녁 표시 (재사용)
local function marker(index)
	local m = markers[index]
	if not m then
		m = Instance.new("Frame")
		m.AnchorPoint = Vector2.new(0.5, 0.5)
		m.BackgroundTransparency = 1
		m.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = m
		Instance.new("UICorner", m).CornerRadius = UDim.new(1, 0)
		markers[index] = m
	end
	return m
end

local toast = Instance.new("TextLabel")
toast.BackgroundTransparency = 1
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0.2, 0)
toast.Size = UDim2.fromOffset(500, 40)
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 24
toast.TextColor3 = gold
toast.TextStrokeTransparency = 0.4
toast.TextTransparency = 1
toast.Parent = gui
local toastToken = 0
local function showToast(text, color)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextColor3 = color or gold
	toast.TextTransparency = 0
	task.delay(1.2, function()
		if token == toastToken then
			Tween:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

--------------------------------------------------
-- 과녁 목록 (서버와 같은 식)
--------------------------------------------------
local function candidates(now)
	local raid = workspace:GetAttribute("RaidActive") == true
	local amp = T.agitation(workspace:GetAttribute("WorldPhase") or "day", raid)
	local list = {}
	for _, target in ipairs(T.armTargets(now, amp)) do
		table.insert(list, { kind = "arm", pos = target.pos, radius = CANNON.TargetRadius })
	end
	for _, target in ipairs(T.eyeTargets(now, raid and T.HeadRaidRise or 0)) do
		table.insert(list, { kind = "eye", pos = target.pos, radius = CANNON.EyeRadius })
	end
	for id, slam in pairs(slams) do
		if T.slamBlockable(slam, now) then
			-- 다리 끝은 빨리 움직인다. 서버에 닿을 즈음의 자리를 겨눈다.
			local tip = T.slamTip(slam, now + 0.08)
			if tip then
				table.insert(list, { kind = "slam", pos = tip, radius = CANNON.SlamRadius })
			end
		elseif now > slam.at + 4 then
			slams[id] = nil
		end
	end
	return list
end

-- 이 대포로 쏠 수 있는 방향인가 (서버와 같은 규칙)
local function reachable(from, outward, point)
	local d = point - from
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude < 1 or d.Magnitude > CANNON.Range then
		return false
	end
	local angle = math.deg(math.acos(math.clamp(flat.Unit:Dot(outward), -1, 1)))
	return angle <= CANNON.MaxAngle - 2
end

--------------------------------------------------
-- 조준 · 발사
--------------------------------------------------
local function cameraCFrame()
	local a = aiming
	local base = CFrame.lookAt(a.muzzle, a.muzzle + a.outward)
	local turn = base * CFrame.Angles(0, math.rad(-a.yaw), 0) * CFrame.Angles(math.rad(a.pitch), 0, 0)
	local eye = a.muzzle - turn.LookVector * 9 + Vector3.new(0, 4.5, 0)
	return CFrame.lookAt(eye, eye + turn.LookVector)
end

-- viewport = true 면 화면 전체 좌표(상단 바 포함), 아니면 입력 좌표(상단 바 아래 기준)
local function fireAt(screenPoint, viewport)
	if not aiming or os.clock() - lastFire < CANNON.Cooldown then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local ray = viewport and camera:ViewportPointToRay(screenPoint.X, screenPoint.Y) or camera:ScreenPointToRay(screenPoint.X, screenPoint.Y)
	-- 광선 가까이 있는 과녁을 찾는다 (반지름의 1.6배까지 도와준다)
	local now = workspace:GetServerTimeNow()
	local best, bestScore = nil, math.huge
	for _, target in ipairs(candidates(now)) do
		local oc = target.pos - ray.Origin
		local along = oc:Dot(ray.Direction)
		if along > 0 then
			local miss = (oc - ray.Direction * along).Magnitude
			if miss < target.radius * 1.6 and miss < bestScore and reachable(aiming.muzzle, aiming.outward, target.pos) then
				best, bestScore = target, miss
			end
		end
	end
	local aimPoint = best and best.pos or (ray.Origin + ray.Direction * 150)
	local dir = (aimPoint - aiming.muzzle)
	if dir.Magnitude < 1 then
		return
	end
	lastFire = os.clock()
	cannonRequest:FireServer("fire", dir.Unit)
end

local function stopAiming(tellServer)
	if not aiming then
		return
	end
	aiming = nil
	gui.Enabled = false
	ContextActionService:UnbindAction(ACTION)
	Run:UnbindFromRenderStep("CursedBarrel_CannonCamera")
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	if tellServer then
		cannonRequest:FireServer("leave")
	end
end

local held = {}
local function onAction(name, state, input)
	local key = input.KeyCode
	if key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonB then
		if state == Enum.UserInputState.Begin then
			stopAiming(true)
		end
		return Enum.ContextActionResult.Sink
	end
	if key == Enum.KeyCode.ButtonR2 or key == Enum.KeyCode.ButtonA then
		if state == Enum.UserInputState.Begin then
			local camera = workspace.CurrentCamera
			if camera then
				fireAt(camera.ViewportSize * 0.5, true)
			end
		end
		return Enum.ContextActionResult.Sink
	end
	if key == Enum.KeyCode.Thumbstick1 or key == Enum.KeyCode.Thumbstick2 then
		held.stick = input.Position
		return Enum.ContextActionResult.Sink
	end
	held[key] = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
	return Enum.ContextActionResult.Sink
end

local function startAiming(data)
	stopAiming(false)
	aiming = { cannon = data.cannon, muzzle = data.muzzle, outward = data.outward, yaw = 0, pitch = 6 }
	table.clear(held)
	gui.Enabled = true
	local touch = Input.TouchEnabled and not Input.KeyboardEnabled
	hint.Text = touch and "화면을 끌어 돌리고, 빛나는 약점 · 눈을 탭해서 쏘세요" or "A·D 돌리기 · W·S 위아래 · 클릭으로 발사  (빛나는 약점 · 눈 · 치켜든 다리)"
	-- 움직이는 키를 대포 조준으로 쓴다 (캐릭터가 걸어가지 않게)
	ContextActionService:BindActionAtPriority(ACTION, onAction, false, Enum.ContextActionPriority.High.Value + 50,
		Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.W, Enum.KeyCode.S, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Up, Enum.KeyCode.Down,
		Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonR2, Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	Run:BindToRenderStep("CursedBarrel_CannonCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
		if not aiming then
			return
		end
		local yawInput = ((held[Enum.KeyCode.D] or held[Enum.KeyCode.Right]) and 1 or 0) - ((held[Enum.KeyCode.A] or held[Enum.KeyCode.Left]) and 1 or 0)
		local pitchInput = ((held[Enum.KeyCode.W] or held[Enum.KeyCode.Up]) and 1 or 0) - ((held[Enum.KeyCode.S] or held[Enum.KeyCode.Down]) and 1 or 0)
		if held.stick then
			yawInput += held.stick.X
			pitchInput += held.stick.Y
		end
		aiming.yaw = math.clamp(aiming.yaw + yawInput * 60 * dt, -(CANNON.MaxAngle - 5), CANNON.MaxAngle - 5)
		aiming.pitch = math.clamp(aiming.pitch + pitchInput * 35 * dt, -8, 32)
		camera.CFrame = cameraCFrame()
		camera.FieldOfView = 70

		-- 조준점 · 과녁 표시
		local pointer = Input:GetMouseLocation()
		local touchNow = Input.TouchEnabled and not Input.KeyboardEnabled
		if touchNow or held.stick then
			pointer = camera.ViewportSize * 0.5
		end
		reticle.Position = UDim2.fromOffset(pointer.X, pointer.Y)
		local now = workspace:GetServerTimeNow()
		local used = 0
		for _, target in ipairs(candidates(now)) do
			local screen, visible = camera:WorldToViewportPoint(target.pos)
			if visible and reachable(aiming.muzzle, aiming.outward, target.pos) then
				used += 1
				local m = marker(used)
				local size = math.clamp(900 / math.max(screen.Z, 1) * target.radius, 18, 90)
				m.Size = UDim2.fromOffset(size, size)
				m.Position = UDim2.fromOffset(screen.X, screen.Y)
				local stroke = m:FindFirstChildOfClass("UIStroke")
				stroke.Color = (target.kind == "slam" and red) or (target.kind == "eye" and teal) or gold
				stroke.Transparency = 0.2 + 0.3 * math.abs(math.sin(os.clock() * 5))
				m.Visible = true
			end
		end
		for index = used + 1, #markers do
			markers[index].Visible = false
		end
		reloadFill.Size = UDim2.fromScale(math.clamp((os.clock() - lastFire) / CANNON.Cooldown, 0, 1), 1)
	end)
end

leaveButton.Activated:Connect(function()
	stopAiming(true)
end)

-- 마우스 클릭 · 화면 탭으로 발사. 끌어서 돌리기는 터치 이동으로.
local dragStart = nil
Input.InputBegan:Connect(function(input, processed)
	if not aiming or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		fireAt(Vector2.new(input.Position.X, input.Position.Y), false)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		dragStart = { position = input.Position, moved = 0 }
	end
end)
Input.InputChanged:Connect(function(input)
	if not aiming or input.UserInputType ~= Enum.UserInputType.Touch or not dragStart then
		return
	end
	local delta = input.Delta
	dragStart.moved += delta.Magnitude
	aiming.yaw = math.clamp(aiming.yaw + delta.X * 0.25, -(CANNON.MaxAngle - 5), CANNON.MaxAngle - 5)
	aiming.pitch = math.clamp(aiming.pitch - delta.Y * 0.2, -8, 32)
end)
Input.InputEnded:Connect(function(input)
	if not aiming or input.UserInputType ~= Enum.UserInputType.Touch or not dragStart then
		return
	end
	-- 거의 안 움직였으면 탭 = 발사
	if dragStart.moved < 12 then
		local p = input.Position
		fireAt(Vector2.new(p.X, p.Y), false)
	end
	dragStart = nil
end)

--------------------------------------------------
-- 포탄 연출 (모두에게)
--------------------------------------------------
local function part(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = workspace
	return p
end

local function smoke(at, color, count, size)
	local holder = part("CannonSmoke", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at), Color3.new(1, 1, 1))
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(size or 1.5, (size or 1.5) * 3)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(3, 8)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(reduced() and math.ceil(count / 3) or count)
	Debris:AddItem(holder, 1.5)
end

local function recoil(cannonId)
	local root = workspace:FindFirstChild("Lobby")
	root = root and root:FindFirstChild("PlayableGalleon")
	local model = root and root:FindFirstChild(cannonId, true)
	local tube = model and model:FindFirstChild("CannonTube")
	if not tube or tube:GetAttribute("Recoiling") then
		return
	end
	tube:SetAttribute("Recoiling", true)
	local home = tube.CFrame
	local side = tube.Position.X < 0 and -1 or 1
	tube.CFrame = home - Vector3.new(side * 0.9, 0, 0)
	Tween:Create(tube, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = home }):Play()
	task.delay(0.55, function()
		if tube.Parent then
			tube.CFrame = home
			tube:SetAttribute("Recoiling", nil)
		end
	end)
end

cannonCue.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	if data.kind == "manned" then
		startAiming(data)
		return
	elseif data.kind == "left" then
		stopAiming(false)
		return
	elseif data.kind == "deny" then
		if aiming and data.message then
			showToast(data.message, red)
		end
		return
	elseif data.kind == "busy" then
		showToast(("%s 님이 쓰는 중입니다"):format(data.name or "누군가"), red)
		gui.Enabled = true
		task.delay(1.5, function()
			if not aiming then
				gui.Enabled = false
			end
		end)
		return
	end
	if data.kind ~= "shot" or typeof(data.muzzle) ~= "Vector3" or typeof(data.point) ~= "Vector3" then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - data.muzzle).Magnitude > 320 then
		return
	end
	local mine = data.userId == player.UserId

	-- 포구 섬광 · 연기 · 반동 · 소리
	local flash = part("MuzzleFlash", Vector3.new(2.4, 2.4, 2.4), CFrame.new(data.muzzle), Color3.fromRGB(255, 200, 120), Enum.Material.Neon, Enum.PartType.Ball)
	Tween:Create(flash, TweenInfo.new(0.15), { Size = Vector3.new(4, 4, 4), Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.2)
	smoke(data.muzzle, Color3.fromRGB(200, 200, 200), 12, 1.6)
	recoil(data.cannon)
	Sfx.play("Cannon", { at = data.muzzle, volume = mine and 0.9 or 0.6 })
	if mine then
		CameraShake.add(0.35, 0.3, 0.6)
	end

	-- 포탄 : 살짝 휘어서 날아간다
	local distance = (data.point - data.muzzle).Magnitude
	local travel = math.clamp(distance / 140, 0.15, 1.2)
	local ball = part("Cannonball", Vector3.new(1.1, 1.1, 1.1), CFrame.new(data.muzzle), Color3.fromRGB(28, 28, 30), Enum.Material.Metal, Enum.PartType.Ball)
	local arc = distance * 0.06
	local started = os.clock()
	local conn
	conn = Run.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - started) / travel, 0, 1)
		local p = data.muzzle:Lerp(data.point, a) + Vector3.new(0, math.sin(a * math.pi) * arc, 0)
		ball.CFrame = CFrame.new(p)
		if a >= 1 then
			conn:Disconnect()
			ball:Destroy()
		end
	end)

	task.delay(travel, function()
		if data.hit then
			local color = data.hit == "slam" and Color3.fromRGB(255, 90, 170) or Color3.fromRGB(120, 60, 150)
			local burst = part("HitBurst", Vector3.new(2, 2, 2), CFrame.new(data.point), color, Enum.Material.Neon, Enum.PartType.Ball)
			Tween:Create(burst, TweenInfo.new(0.3), { Size = Vector3.new(7, 7, 7), Transparency = 1 }):Play()
			Debris:AddItem(burst, 0.35)
			smoke(data.point, Color3.fromRGB(70, 30, 80), 10, 2)
			Sfx.play("Hit", { at = data.point, volume = 0.9 })
			if mine then
				local text
				if data.damage then
					text = data.hit == "slam" and ("막았다!  크라켄 -%d"):format(data.damage) or ("명중!  크라켄 -%d"):format(data.damage)
				elseif data.coins and data.coins > 0 then
					text = ("명중!  +%d 코인"):format(data.coins)
				else
					text = data.hit == "eye" and "눈에 명중! (오늘 대포 코인은 다 받았어요)" or "명중! (오늘 대포 코인은 다 받았어요)"
				end
				showToast(text, data.hit == "slam" and teal or gold)
			end
		else
			-- 물보라
			for i = 1, (reduced() and 3 or 8) do
				local drop = part("Splash", Vector3.new(1.2, 1.2, 1.2), CFrame.new(data.point), Color3.fromRGB(228, 240, 246), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
				drop.Transparency = 0.2
				local offset = Vector3.new((math.random() - 0.5) * 3, 5 + math.random() * 6, (math.random() - 0.5) * 3)
				Tween:Create(drop, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(data.point + offset), Transparency = 1 }):Play()
				Debris:AddItem(drop, 0.55)
			end
			Sfx.play("Splash", { at = data.point, volume = 0.6 })
			if mine then
				showToast("빗나갔다…", cream)
			end
		end
	end)
end)

-- 습격 때 치켜드는 다리를 과녁 목록에 넣는다
worldCue.OnClientEvent:Connect(function(kind, data)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "Slam" and data.id then
		slams[data.id] = data
	elseif kind == "SlamBlocked" and slams[data.id] then
		slams[data.id].blockedAt = data.blockedAt
	end
end)

player.CharacterRemoving:Connect(function()
	stopAiming(false)
end)
