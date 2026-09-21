-- 7단계 : 별 문의 "빛나는 막"은 사람마다 따로 보여야 하므로
-- 각자의 화면(클라이언트)에서 만듭니다. 문을 연 사람 화면에서만 사라집니다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelFactory = require(Shared:WaitForChild("ModelFactory"))

local GateClient = {}

local LOCKED_ISLAND = "Snow"
local curtain
local sparkles
local opened = false

local function buildCurtain()
	local bridge = Config.Bridge
	curtain = Instance.new("Part")
	curtain.Name = "StarGateCurtain"
	curtain.Size = Vector3.new(bridge.GateWidth, bridge.GateHeight, 0.6)
	curtain.CFrame = CFrame.new(0, bridge.GateHeight / 2, bridge.GateZ - 1)
	curtain.Anchored = true
	curtain.CanCollide = false
	curtain.CanQuery = false
	curtain.CanTouch = false
	curtain.CastShadow = false
	curtain.Material = Enum.Material.Neon
	curtain.Color = Color3.fromRGB(190, 224, 255)
	curtain.Transparency = 0.62
	curtain.Parent = workspace

	sparkles = ModelFactory.addSparkles(curtain, Color3.fromRGB(255, 240, 180), 22)
	sparkles.SpreadAngle = Vector2.new(20, 20)
	sparkles.Speed = NumberRange.new(1, 3)
end

local function openCurtain()
	if not curtain or opened then
		return
	end
	opened = true
	if sparkles then
		sparkles.Rate = 0
	end
	TweenService:Create(curtain, TweenInfo.new(0.9), { Transparency = 1, Size = curtain.Size * 1.2 }):Play()
	task.delay(1.1, function()
		if curtain then
			curtain:Destroy()
			curtain = nil
		end
	end)
end

function GateClient.init()
	-- 막이는 첫 상태를 받은 뒤에 만듭니다.
	-- (이미 문을 연 사람 화면에는 아예 나타나지 않게)
end

function GateClient.update(state)
	if not state or not state.islands then
		return
	end
	if state.islands[LOCKED_ISLAND] then
		if curtain then
			openCurtain()
		end
		opened = true
		return
	end
	if not curtain and not opened then
		buildCurtain()
	end
end

-- 문이 열리는 순간 축하 폭죽 (내 화면)
function GateClient.celebrate()
	local bridge = Config.Bridge
	local center = Vector3.new(0, bridge.GateHeight * 0.7, bridge.GateZ)
	for index = 1, 5 do
		task.delay((index - 1) * 0.14, function()
			ModelFactory.burst(
				center + Vector3.new(math.random(-9, 9), math.random(0, 8), math.random(-3, 3)),
				Color3.fromHSV(math.random(), 0.5, 1),
				28
			)
		end)
	end
	openCurtain()
end

return GateClient
