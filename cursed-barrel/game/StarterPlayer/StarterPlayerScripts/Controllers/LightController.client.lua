--[[
	LightController  (Phase 15)
	배의 등불 빛을 내 화면에서 켠다.

	"처음 들어오고 몇 초 동안 조명이 안 켜진다" 를 고친다.
	  · 예전에는 빛(PointLight)이 등불 모델에 붙어 스트리밍으로 도착했다. 먼 등불은 몇 초 뒤에야 왔다.
	  · 이제 서버는 등불 자리 목록만 ReplicatedStorage 에 둔다 (접속할 때 통째로 먼저 온다).
	    이 스크립트가 그 자리에 보이지 않는 작은 파트 + 빛을 바로 만든다.
	  · 성능 : 카메라에서 먼 빛은 끈다 (효과 품질 "낮음"이면 더 가까운 것만 켠다). 낮에는 흐리게, 밤에는 밝게.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local package = ReplicatedStorage:WaitForChild("CursedBarrel")

local folder = Instance.new("Folder")
folder.Name = "CursedBarrel_ShipLights"
folder.Parent = workspace

local lights = {} -- { part, light, base }
local known = {}

local LIGHT_COLOR = Color3.fromRGB(255, 200, 128)

local function add(spot)
	if known[spot] or not spot:IsA("Vector3Value") then
		return
	end
	known[spot] = true
	local anchor = Instance.new("Part")
	anchor.Name = "LanternLight"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.CFrame = CFrame.new(spot.Value)
	anchor.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = LIGHT_COLOR
	light.Range = spot:GetAttribute("Range") or 20
	light.Brightness = spot:GetAttribute("Brightness") or 1.8
	light.Shadows = false
	light.Parent = anchor
	table.insert(lights, { part = anchor, light = light, base = light.Brightness })
end

local spots = package:FindFirstChild("LanternSpots")
local function watch(container)
	for _, spot in ipairs(container:GetChildren()) do
		add(spot)
	end
	container.ChildAdded:Connect(add)
end
if spots then
	watch(spots)
else
	package.ChildAdded:Connect(function(child)
		if child.Name == "LanternSpots" then
			watch(child)
		end
	end)
end

-- 밤 · 안개 · 폭풍에는 밝게, 낮에는 은은하게. 먼 빛은 끈다.
local DIM = { day = 0.55, dusk = 0.85, dawn = 0.8 }
local checkAt = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < checkAt then
		return
	end
	checkAt = now + 0.5
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local quality = player:GetAttribute("Setting_quality") or "Auto"
	local reach = quality == "Low" and 110 or 190
	local scale = DIM[workspace:GetAttribute("WorldPhase") or "day"] or 1
	local eye = camera.CFrame.Position
	for _, entry in ipairs(lights) do
		local near = (entry.part.Position - eye).Magnitude < reach
		if entry.light.Enabled ~= near then
			entry.light.Enabled = near
		end
		local want = entry.base * scale
		if math.abs(entry.light.Brightness - want) > 0.01 then
			entry.light.Brightness = want
		end
	end
end)

script.Destroying:Connect(function()
	folder:Destroy()
end)
