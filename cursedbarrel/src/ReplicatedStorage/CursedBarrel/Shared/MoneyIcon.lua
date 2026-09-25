--[[
	MoneyIcon  (Phase 16)
	돈 모양 그림 : 초록 지폐 묶음(노란 띠) · 금화 · 보물 상자 · 금고 · 선물 상자 · 왕관 · 물약.
	출석판 · 상점 카드 · 룰렛 칸 · 왼쪽 아래 코인 숫자 옆에 쓴다.

	두 가지로 그린다.
	  1) 그림 ID 가 있으면 (ReleaseConfig.Images.Money[종류]) 그 그림.
	     assets/ui/money/*.png 를 올리면 된다 (Blender 로 그린 만화풍 그림 · 검은 외곽선 · 투명 배경).
	  2) 없으면 같은 모양을 파트로 만든 작은 3D 모형을 ViewportFrame 에 띄운다. 올리지 않아도 바로 보인다.
	  모양은 tools/blender/money_icons.py 한 곳에서 정한다 (그림 · 3D 모형이 같은 모양).

	MoneyIcon.view(parent, kind, props) → GuiObject
	  props : size · position · anchor · zIndex · spin(천천히 돌기)
	MoneyIcon.model(kind) → Model (월드 · ViewportFrame 어디에나 넣을 수 있다)
]]

local RunService = game:GetService("RunService")

local MoneyIcon = {}

local Data = require(script.Parent:WaitForChild("MoneyIconData"))

MoneyIcon.Kinds = { "cash", "cash2", "cash3", "coins", "chest", "vault", "gift", "crown", "potion" }

local imageIds = {}
pcall(function()
	local release = require(script.Parent.ReleaseConfig)
	imageIds = (release.Images and release.Images.Money) or {}
end)

--------------------------------------------------
-- 파트 모형 (MoneyIconData : tools/blender/money_icons.py 가 만든 조각 목록)
--------------------------------------------------

local SHAPES = { Block = Enum.PartType.Block, Cylinder = Enum.PartType.Cylinder, Ball = Enum.PartType.Ball }

function MoneyIcon.model(kind)
	local model = Instance.new("Model")
	model.Name = "MoneyIcon_" .. tostring(kind)
	for index, piece in ipairs(Data[kind] or Data.cash) do
		local p = Instance.new("Part")
		p.Name = "Piece" .. index
		p.Shape = SHAPES[piece.t] or Enum.PartType.Block
		p.Size = Vector3.new(piece.s[1], piece.s[2], piece.s[3])
		local c = piece.c
		p.CFrame = CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		p.Color = Color3.fromRGB(piece.k[1], piece.k[2], piece.k[3])
		p.Material = Enum.Material[piece.m] or Enum.Material.SmoothPlastic
		p.Transparency = piece.tr or 0
		p.Reflectance = piece.rf or 0
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
	end
	return model
end

--------------------------------------------------
-- 화면에 띄우기
--------------------------------------------------

-- 모든 아이콘은 같은 쪽(앞 위)에서 본다
local VIEW_DIRECTION = Vector3.new(0.25, 0.75, 1).Unit

-- 창이 닫혀 있으면(조상 중 하나라도 안 보이면) 돌리지 않는다
function MoneyIcon.shown(gui)
	local node = gui
	while node do
		if node:IsA("ScreenGui") then
			return node.Enabled
		elseif node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return false
end

local spinning = {} -- { camera, center, distance, angle }
local spinConnection = nil
local function startSpin()
	if spinConnection then
		return
	end
	spinConnection = RunService.RenderStepped:Connect(function(dt)
		for i = #spinning, 1, -1 do
			local entry = spinning[i]
			if not entry.frame.Parent then
				table.remove(spinning, i)
			elseif MoneyIcon.shown(entry.frame) then
				entry.angle += dt * 0.9
				local d = Vector3.new(math.sin(entry.angle) * 0.9, VIEW_DIRECTION.Y, math.cos(entry.angle)).Unit
				entry.camera.CFrame = CFrame.lookAt(entry.center + d * entry.distance, entry.center)
			end
		end
		if #spinning == 0 then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end)
end

function MoneyIcon.imageId(kind)
	return tonumber(imageIds[kind]) or 0
end

function MoneyIcon.view(parent, kind, props)
	props = props or {}
	local id = MoneyIcon.imageId(kind)
	local frame
	if id > 0 then
		frame = Instance.new("ImageLabel")
		frame.Image = "rbxassetid://" .. id
		frame.ScaleType = Enum.ScaleType.Fit
		frame.BackgroundTransparency = 1
	else
		frame = Instance.new("ViewportFrame")
		frame.BackgroundTransparency = 1
		frame.Ambient = Color3.fromRGB(200, 200, 210)
		frame.LightColor = Color3.fromRGB(255, 248, 230)
		frame.LightDirection = Vector3.new(-0.6, -1, -0.7)
		local model = MoneyIcon.model(kind)
		model.Parent = frame
		local box, size = model:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 28
		camera.Parent = frame
		frame.CurrentCamera = camera
		local radius = size.Magnitude * 0.5
		local distance = radius / math.sin(math.rad(14)) * (props.zoom or 1)
		camera.CFrame = CFrame.lookAt(box.Position + VIEW_DIRECTION * distance, box.Position)
		if props.spin then
			table.insert(spinning, { frame = frame, camera = camera, center = box.Position, distance = distance, angle = math.random() * 6 })
			startSpin()
		end
	end
	frame.Name = props.name or "MoneyIcon"
	frame.Size = props.size or UDim2.fromOffset(64, 64)
	frame.Position = props.position or UDim2.new()
	frame.AnchorPoint = props.anchor or Vector2.new()
	frame.ZIndex = props.zIndex or (parent:IsA("GuiObject") and parent.ZIndex + 1 or 1)
	frame:SetAttribute("NoStyle", true)
	frame.Parent = parent
	return frame
end

return MoneyIcon
