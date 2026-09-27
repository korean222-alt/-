--[[
	NavigationController  (Phase 8)
	누가 앉아서 사람을 기다리고 있으면, 서 있는 사람 발밑에 화살표가 뜬다.

	요청하신 그대로입니다.
	  "어떤 사람이 앉아 있고 다른 플레이어를 기다리고 있으면,
	   안 앉아 있는 사람한테 제일 가까운 자리로 네비게이션 같이 화살표가 밑에 뜨게"

	규칙
	  · 내가 이미 앉아 있으면 뜨지 않는다.
	  · 아무도 안 앉은 테이블만 있으면 뜨지 않는다. (기다리는 사람이 없으니 급할 게 없다)
	  · 여러 테이블이 기다리는 중이면 "가장 가까운 빈 자리"를 고른다.
	    단, 곧 시작할 테이블(카운트다운 중)을 먼저 본다. 거기가 제일 급하다.
	  · 자리에 다 오면 조용히 사라진다.

	전부 내 화면에서만 그린다. 서버는 이 파일을 모른다.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local TABLE_TAG = GameConfig.Tags.Table
local TABLE_ATTR = GameConfig.TableAttributes
local SEAT_ATTR = GameConfig.SeatAttributes
local STATES = GameConfig.States
local WAY = GameConfig.Wayfinder

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local CHEVRON_COUNT = 6
local CHEVRON_GAP = 4.5 -- 화살표 사이 간격(스터드)
local SCAN_INTERVAL = 0.3

--------------------------------------------------
-- 화살표 만들기
--------------------------------------------------

local folder = Instance.new("Folder")
folder.Name = "CursedBarrel_Wayfinder"
folder.Parent = workspace

local chevrons = {}
for index = 1, CHEVRON_COUNT do
	local wedge = Instance.new("WedgePart")
	wedge.Name = "Chevron" .. index
	wedge.Size = Vector3.new(2.4, 0.2, 2.8)
	wedge.Color = WAY.Color
	wedge.Material = Enum.Material.Neon
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CanTouch = false
	wedge.CanQuery = false
	wedge.CastShadow = false
	wedge.Transparency = 1
	wedge.Parent = folder
	chevrons[index] = wedge
end

-- 목표 자리 위에 뜨는 작은 표지
local marker = Instance.new("BillboardGui")
marker.Name = "SeatMarker"
marker.Size = UDim2.fromOffset(160, 44)
marker.StudsOffset = Vector3.new(0, 3.4, 0)
marker.AlwaysOnTop = true
marker.MaxDistance = 160
marker.Enabled = false
marker.ResetOnSpawn = false
marker.Parent = playerGui

local markerPlate = Instance.new("Frame")
markerPlate.Size = UDim2.fromScale(1, 1)
markerPlate.BackgroundColor3 = Color3.fromRGB(26, 20, 14)
markerPlate.BackgroundTransparency = 0.2
markerPlate.BorderSizePixel = 0
markerPlate.Parent = marker
Instance.new("UICorner", markerPlate).CornerRadius = UDim.new(0, 8)

local markerStroke = Instance.new("UIStroke")
markerStroke.Color = WAY.Color
markerStroke.Thickness = 2
markerStroke.Transparency = 0.15
markerStroke.Parent = markerPlate

local markerTitle = Instance.new("TextLabel")
markerTitle.Size = UDim2.new(1, -10, 1, -6)
markerTitle.Position = UDim2.fromOffset(5, 3)
markerTitle.BackgroundTransparency = 1
markerTitle.Font = Enum.Font.GothamBold
markerTitle.TextSize = 22
markerTitle.TextColor3 = WAY.Color
markerTitle.Text = "빈 자리"
markerTitle.Parent = markerPlate

local markerInfo = Instance.new("TextLabel")
markerInfo.Size = UDim2.new(1, -10, 0, 18)
markerInfo.Position = UDim2.fromOffset(5, 24)
markerInfo.BackgroundTransparency = 1
markerInfo.Font = Enum.Font.GothamMedium
markerInfo.TextSize = 13
markerInfo.TextColor3 = Color3.fromRGB(226, 214, 190)
markerInfo.Text = ""
markerInfo.Parent = markerPlate
-- Phase 14 : 만화풍 글꼴 · 글자 외곽선
require(Shared:WaitForChild("UIKit")).restyle(marker)

--------------------------------------------------
-- 목표 고르기
--------------------------------------------------

local function isSeatedSomewhere()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end

-- 이 테이블이 "사람을 기다리는 중"인가
local function isWaitingForPeople(model)
	local state = model:GetAttribute(TABLE_ATTR.State)
	if state ~= STATES.Waiting and state ~= STATES.Countdown then
		return false
	end
	local seated = model:GetAttribute(TABLE_ATTR.SeatedCount) or 0
	local capacity = model:GetAttribute(TABLE_ATTR.SeatCount) or 0
	if seated < WAY.ShowWhenSeatedAtLeast then
		return false
	end
	return seated < capacity
end

local function freeSeatsOf(model)
	local seatsFolder = model:FindFirstChild("Seats")
	if not seatsFolder then
		return {}
	end
	local free = {}
	for _, descendant in ipairs(seatsFolder:GetDescendants()) do
		if descendant:IsA("Seat") and descendant.Occupant == nil
			and (descendant:GetAttribute(SEAT_ATTR.OccupantUserId) or 0) == 0 then
			table.insert(free, descendant)
		end
	end
	return free
end

-- 가장 가까운 빈 자리. 카운트다운 중인 테이블을 먼저 본다.
local function pickTarget(origin)
	local best, bestModel, bestScore = nil, nil, math.huge

	for _, model in ipairs(CollectionService:GetTagged(TABLE_TAG)) do
		if model:IsDescendantOf(workspace) and isWaitingForPeople(model) then
			local urgent = model:GetAttribute(TABLE_ATTR.State) == STATES.Countdown
			for _, seat in ipairs(freeSeatsOf(model)) do
				local distance = (seat.Position - origin).Magnitude
				-- 카운트다운 중인 테이블은 40스터드만큼 가까운 것처럼 친다.
				local score = distance - (urgent and 40 or 0)
				if score < bestScore then
					best, bestModel, bestScore = seat, model, score
				end
			end
		end
	end

	return best, bestModel
end

--------------------------------------------------
-- 그리기
--------------------------------------------------

local function hide()
	for _, wedge in ipairs(chevrons) do
		wedge.Transparency = 1
	end
	marker.Enabled = false
	marker.Adornee = nil
end

local targetSeat, targetModel = nil, nil
local scanAt = 0

RunService.Heartbeat:Connect(function()
	if not WAY.Enabled then
		return
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or isSeatedSomewhere() then
		hide()
		return
	end

	-- 목표는 자주 바뀌지 않는다. 0.3초마다 다시 고른다.
	if os.clock() - scanAt > SCAN_INTERVAL then
		scanAt = os.clock()
		targetSeat, targetModel = pickTarget(root.Position)
	end

	if not targetSeat or not targetSeat.Parent or not targetModel or not targetModel.Parent then
		hide()
		return
	end

	local toSeat = targetSeat.Position - root.Position
	local flat = Vector3.new(toSeat.X, 0, toSeat.Z)
	local distance = flat.Magnitude

	-- 다 왔으면 조용히 끈다.
	if distance <= WAY.ArriveDistance then
		hide()
		return
	end

	local direction = flat.Unit
	local urgent = targetModel:GetAttribute(TABLE_ATTR.State) == STATES.Countdown
	local color = urgent and WAY.UrgentColor or WAY.Color

	-- 화살표가 목표 쪽으로 흘러간다. (발밑에서 앞으로)
	local flow = (os.clock() * 4) % 1
	local groundY = root.Position.Y - 2.6

	for index, wedge in ipairs(chevrons) do
		local step = (index - 1 + flow) * CHEVRON_GAP + 3
		if step > distance - 1.5 then
			wedge.Transparency = 1
		else
			local point = root.Position + direction * step
			wedge.CFrame = CFrame.lookAt(Vector3.new(point.X, groundY, point.Z), Vector3.new(point.X, groundY, point.Z) + direction)
				* CFrame.Angles(math.rad(-90), 0, 0)
			wedge.Color = color
			-- 멀리 있는 화살표일수록 흐리게. 흐름이 눈에 보인다.
			wedge.Transparency = math.clamp(0.15 + (index - 1) * 0.12, 0, 0.85)
		end
	end

	markerStroke.Color = color
	markerTitle.TextColor3 = color
	markerTitle.Text = urgent and "곧 시작! 빈 자리" or "빈 자리"

	-- 부제목(테이블 · 인원 · 거리)은 두지 않는다
	markerInfo.Text = ""

	marker.Adornee = targetSeat
	marker.Enabled = true
end)

localPlayer.CharacterRemoving:Connect(hide)

script.Destroying:Connect(function()
	folder:Destroy()
	marker:Destroy()
end)
