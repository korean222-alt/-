--[[
	BuildTable.lua  (Studio 명령줄 전용 · 1회 실행)

	Roblox Studio 에서 View > Command Bar 를 열고
	이 파일 내용을 전부 복사해 붙여넣은 뒤 Enter 를 누른다.

	결과물: Workspace > GameTables > Table_A
	기본 Part 만 사용하지만 회색 개발 블록이 아니라
	나무/금색 톤의 stylized 형태로 만든다.

	나중에 직접 모델링한 통이나 의자로 교체해도
	구조(Seats 폴더 · Seat · StatusAnchor · 태그)만 지키면 코드는 그대로 동작한다.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

--------------------------------------------------
-- 설정
--------------------------------------------------
local TABLE_TAG = "CursedBarrel_Table"
local TABLE_NAME = "Table_A"
local TABLE_TYPE = "Standard4"
local TABLE_ORIGIN = Vector3.new(0, 0, -18) -- 바닥 높이 기준 위치
local SEAT_COUNT = 4

local TABLE_TOP_RADIUS = 4.6
local TABLE_TOP_HEIGHT = 3.2
local SEAT_RADIUS = 6.6
local SEAT_HEIGHT = 2.0

local PALETTE = {
	DarkWood = Color3.fromRGB(52, 34, 23),
	Wood = Color3.fromRGB(94, 62, 40),
	LightWood = Color3.fromRGB(131, 92, 58),
	Gold = Color3.fromRGB(198, 154, 74),
	Iron = Color3.fromRGB(70, 72, 77),
	Cursed = Color3.fromRGB(72, 132, 122),
}

--------------------------------------------------
-- 헬퍼
--------------------------------------------------
local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.Wood
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local parent = props.Parent
	props.Parent = nil
	for key, value in pairs(props) do
		part[key] = value
	end
	if parent then
		part.Parent = parent
	end
	return part
end

-- 세로로 세운 원기둥. Cylinder 는 X축이 길이 방향이라 Z로 90도 눕힌다.
local function newCylinder(props, diameter, height, position)
	local part = newPart(props)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

--------------------------------------------------
-- 기존 테이블 제거 (여러 번 실행해도 안전하게)
--------------------------------------------------
local gameTables = Workspace:FindFirstChild("GameTables")
if not gameTables then
	gameTables = Instance.new("Folder")
	gameTables.Name = "GameTables"
	gameTables.Parent = Workspace
end

local existing = gameTables:FindFirstChild(TABLE_NAME)
if existing then
	existing:Destroy()
end

--------------------------------------------------
-- 테이블 모델
--------------------------------------------------
local tableModel = Instance.new("Model")
tableModel.Name = TABLE_NAME

local origin = TABLE_ORIGIN

-- 바닥 받침
newCylinder({ Name = "Foot", Color = PALETTE.DarkWood, Parent = tableModel }, 3.4, 0.5, origin + Vector3.new(0, 0.25, 0))

-- 기둥
newCylinder({ Name = "Pillar", Color = PALETTE.Wood, Parent = tableModel }, 1.7, TABLE_TOP_HEIGHT - 0.5, origin + Vector3.new(0, (TABLE_TOP_HEIGHT - 0.5) / 2 + 0.3, 0))

-- 금색 테두리 링 (상판보다 살짝 아래 + 살짝 크게)
newCylinder({ Name = "Rim", Color = PALETTE.Gold, Material = Enum.Material.Metal, Parent = tableModel }, TABLE_TOP_RADIUS * 2 + 0.45, 0.3, origin + Vector3.new(0, TABLE_TOP_HEIGHT - 0.28, 0))

-- 상판
local tableTop = newCylinder({
	Name = "TableTop",
	Color = PALETTE.LightWood,
	Material = Enum.Material.WoodPlanks,
	Parent = tableModel,
}, TABLE_TOP_RADIUS * 2, 0.55, origin + Vector3.new(0, TABLE_TOP_HEIGHT, 0))

tableModel.PrimaryPart = tableTop

--------------------------------------------------
-- 저주받은 통 (Phase 3 에서 칼 슬롯이 붙을 자리)
--------------------------------------------------
local barrel = Instance.new("Model")
local barrelBottom = TABLE_TOP_HEIGHT + 0.28
local barrelHeight = 4.0

local barrelBody = newCylinder({
	Name = "Body",
	Color = PALETTE.Wood,
	Material = Enum.Material.WoodPlanks,
	Parent = barrel,
}, 3.5, barrelHeight, origin + Vector3.new(0, barrelBottom + barrelHeight / 2, 0))

-- 쇠 테두리 두 줄
newCylinder({ Name = "HoopLower", Color = PALETTE.Iron, Material = Enum.Material.Metal, Parent = barrel }, 3.7, 0.35, origin + Vector3.new(0, barrelBottom + 0.9, 0))
newCylinder({ Name = "HoopUpper", Color = PALETTE.Iron, Material = Enum.Material.Metal, Parent = barrel }, 3.7, 0.35, origin + Vector3.new(0, barrelBottom + barrelHeight - 0.9, 0))

-- 뚜껑
newCylinder({ Name = "Lid", Color = PALETTE.DarkWood, Parent = barrel }, 3.3, 0.3, origin + Vector3.new(0, barrelBottom + barrelHeight + 0.15, 0))

-- 통 위로 새어나오는 저주의 빛 (분위기용)
local glow = newCylinder({
	Name = "Glow",
	Color = PALETTE.Cursed,
	Material = Enum.Material.Neon,
	Transparency = 0.55,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Parent = barrel,
}, 2.9, 0.12, origin + Vector3.new(0, barrelBottom + barrelHeight + 0.34, 0))

local glowLight = Instance.new("PointLight")
glowLight.Color = PALETTE.Cursed
glowLight.Brightness = 1.4
glowLight.Range = 10
glowLight.Parent = glow

barrel.Name = "Barrel"
barrel.PrimaryPart = barrelBody
barrel.Parent = tableModel

--------------------------------------------------
-- 현황판이 붙을 기준점 (보이지 않는 작은 Part)
--------------------------------------------------
newPart({
	Name = "StatusAnchor",
	Size = Vector3.new(1, 1, 1),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Parent = tableModel,
	CFrame = CFrame.new(origin + Vector3.new(0, barrelBottom + barrelHeight + 3.2, 0)),
})

--------------------------------------------------
-- 좌석
--------------------------------------------------
local seatsFolder = Instance.new("Folder")
seatsFolder.Name = "Seats"
seatsFolder.Parent = tableModel

for index = 1, SEAT_COUNT do
	local angle = (index - 1) * (math.pi * 2 / SEAT_COUNT)
	local offset = Vector3.new(math.sin(angle) * SEAT_RADIUS, SEAT_HEIGHT, math.cos(angle) * SEAT_RADIUS)
	local seatPosition = origin + offset

	-- 의자가 테이블 중앙을 바라보게 한다 → 앉은 캐릭터도 중앙을 본다
	local lookTarget = Vector3.new(origin.X, seatPosition.Y, origin.Z)
	local seatCFrame = CFrame.lookAt(seatPosition, lookTarget)

	local chair = Instance.new("Model")
	chair.Name = ("Chair_%02d"):format(index)
	chair.Parent = seatsFolder

	local seat = Instance.new("Seat")
	seat.Name = ("Seat_%02d"):format(index)
	seat.Size = Vector3.new(2.4, 0.5, 2.4)
	seat.Anchored = true
	seat.Color = PALETTE.LightWood
	seat.Material = Enum.Material.Wood
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.CFrame = seatCFrame
	seat:SetAttribute("SeatIndex", index)
	seat.Parent = chair

	chair.PrimaryPart = seat

	-- 등받이 (앉은 사람 뒤쪽 = 로컬 +Z)
	local back = newPart({
		Name = "Back",
		Size = Vector3.new(2.4, 2.4, 0.35),
		Color = PALETTE.Wood,
		Parent = chair,
	})
	back.CFrame = seatCFrame * CFrame.new(0, 1.0, 1.05)

	-- 등받이 위 금색 장식
	local crest = newPart({
		Name = "Crest",
		Size = Vector3.new(2.4, 0.25, 0.42),
		Color = PALETTE.Gold,
		Material = Enum.Material.Metal,
		CanCollide = false,
		Parent = chair,
	})
	crest.CFrame = seatCFrame * CFrame.new(0, 2.25, 1.05)

	-- 다리
	local legHeight = SEAT_HEIGHT - 0.25
	local legPosition = seatPosition - Vector3.new(0, 0.25 + legHeight / 2, 0)
	newCylinder({ Name = "Leg", Color = PALETTE.DarkWood, Parent = chair }, 0.9, legHeight, legPosition)
	newCylinder({ Name = "LegFoot", Color = PALETTE.DarkWood, Parent = chair }, 2.0, 0.3, Vector3.new(seatPosition.X, 0.15, seatPosition.Z))
end

--------------------------------------------------
-- 머리 위 랜턴 (따뜻한 주황 조명)
--------------------------------------------------
local lanternHeight = 11
local lanternRope = newPart({
	Name = "LanternRope",
	Size = Vector3.new(0.18, 4, 0.18),
	Color = PALETTE.DarkWood,
	CanCollide = false,
	Parent = tableModel,
})
lanternRope.CFrame = CFrame.new(origin + Vector3.new(0, lanternHeight + 2, 0))

local lantern = newPart({
	Name = "Lantern",
	Size = Vector3.new(1.4, 1.8, 1.4),
	Color = PALETTE.Gold,
	Material = Enum.Material.Metal,
	CanCollide = false,
	Parent = tableModel,
})
lantern.CFrame = CFrame.new(origin + Vector3.new(0, lanternHeight, 0))

local flame = newPart({
	Name = "Flame",
	Size = Vector3.new(0.9, 1.1, 0.9),
	Color = Color3.fromRGB(255, 196, 120),
	Material = Enum.Material.Neon,
	CanCollide = false,
	CanQuery = false,
	Parent = tableModel,
})
flame.CFrame = lantern.CFrame

local lanternLight = Instance.new("PointLight")
lanternLight.Color = Color3.fromRGB(255, 186, 120)
lanternLight.Brightness = 2.4
lanternLight.Range = 32
lanternLight.Shadows = true
lanternLight.Parent = flame

--------------------------------------------------
-- 마무리: Attribute + 태그
--------------------------------------------------
tableModel:SetAttribute("TableId", TABLE_NAME)
tableModel:SetAttribute("TableType", TABLE_TYPE)
tableModel.Parent = gameTables

CollectionService:AddTag(tableModel, TABLE_TAG)

print(("[CursedBarrel] %s 생성 완료 · 좌석 %d개 · 위치 %s"):format(TABLE_NAME, SEAT_COUNT, tostring(TABLE_ORIGIN)))
