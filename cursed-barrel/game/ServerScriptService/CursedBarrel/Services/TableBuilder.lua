--[[
	TableBuilder  (Phase 8)
	테이블 모델의 의자 수를 TableType 이 요구하는 수에 맞춘다.

	6인 테이블을 손으로 만들지 않고 여기서 만든다.
	  · 이미 있는 의자 하나를 본으로 삼아 복제한다 (모양이 어긋나지 않는다)
	  · 상판 반지름을 재서 전부 같은 간격으로 다시 둘러 세운다
	  · 좌석 번호는 GameTable 이 다시 매기므로 여기서는 자리만 잡는다

	줄이는 경우도 처리한다. Standard4 로 되돌리면 남는 의자를 치운다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local TableBuilder = {}

-- 상판 반지름. 없으면 통 크기에서 짐작한다.
local function tableRadius(model)
	local top = model:FindFirstChild("TableTop", true)
	if top and top:IsA("BasePart") then
		if top:IsA("Part") and top.Shape == Enum.PartType.Cylinder then
			return top.Size.Y * 0.5
		end
		return math.max(top.Size.X, top.Size.Z) * 0.5
	end
	local barrel = model:FindFirstChild(GameConfig.SlotLayout.BarrelName)
	local body = barrel and barrel:FindFirstChild(GameConfig.SlotLayout.BodyName, true)
	if body and body:IsA("BasePart") then
		return math.max(body.Size.X, body.Size.Z) * 1.9
	end
	return 7
end

local function tableCenter(model)
	local top = model:FindFirstChild("TableTop", true)
	if top and top:IsA("BasePart") then
		return top.Position
	end
	local pivot = model:GetPivot()
	return pivot.Position
end

local function chairsIn(seatsFolder)
	local chairs = {}
	for _, child in ipairs(seatsFolder:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChildWhichIsA("Seat", true) then
			table.insert(chairs, child)
		end
	end
	table.sort(chairs, function(a, b)
		return a.Name < b.Name
	end)
	return chairs
end

--[[
	의자를 테이블 중심을 축으로 돌려서 배치한다.

	왜 CFrame.lookAt 으로 새로 만들지 않고 "돌리기"를 쓰나?
	  의자 모델의 기준 방향이 어느 쪽인지 파일마다 다르다.
	  lookAt 으로 새로 세우면 잘못 만든 모델에서는 의자가 옆이나 뒤를 보게 된다.
	  이미 제대로 놓여 있는 의자 하나를 기준으로 삼아 그것을 축 둘레로 돌리면,
	  기준 방향이 무엇이든 관계없이 전부 똑같이 테이블을 보게 된다.
]]
local function placeAround(chair, pivot, reference, angle)
	chair:PivotTo(pivot * CFrame.Angles(0, angle, 0) * reference)
end

--[[
	모델의 의자 수를 count 에 맞춘다. 실제로 놓인 의자 목록을 돌려준다.
]]
function TableBuilder.ensureSeats(model, count)
	local seatsFolder = model:FindFirstChild("Seats")
	if not seatsFolder then
		return {}
	end

	count = math.max(1, math.floor(tonumber(count) or 1))
	local chairs = chairsIn(seatsFolder)
	if #chairs == 0 then
		return {}
	end
	if #chairs == count then
		return chairs -- 이미 맞다. 잘 놓여 있는 의자를 굳이 건드리지 않는다.
	end

	local template = chairs[1]
	local home = template:GetPivot()
	local center = tableCenter(model)

	-- 회전축은 테이블 중심을 지나는 세로선. 높이는 의자 높이에 맞춘다.
	local pivot = CFrame.new(center.X, home.Position.Y, center.Z)
	local reference = pivot:Inverse() * home

	-- 기준 의자가 테이블 한가운데에 겹쳐 있으면 회전이 의미가 없다. 반지름을 직접 잡아준다.
	if reference.Position.Magnitude < 1 then
		reference = CFrame.new(0, 0, tableRadius(model) + 2.6) * (home - home.Position)
	end

	local added, removed = 0, 0

	while #chairs < count do
		local copy = template:Clone()
		copy.Name = ("Chair_%02d"):format(#chairs + 1)
		local seat = copy:FindFirstChildWhichIsA("Seat", true)
		if seat then
			seat.Name = ("Seat_%02d"):format(#chairs + 1)
			seat:SetAttribute(GameConfig.SeatAttributes.SeatIndex, #chairs + 1)
			seat:SetAttribute(GameConfig.SeatAttributes.OccupantUserId, 0)
		end
		copy.Parent = seatsFolder
		table.insert(chairs, copy)
		added += 1
	end

	-- 남으면 치운다. 단 사람이 앉아 있는 의자는 건드리지 않는다.
	while #chairs > count do
		local chair = chairs[#chairs]
		local seat = chair:FindFirstChildWhichIsA("Seat", true)
		if seat and seat.Occupant then
			break
		end
		chair:Destroy()
		table.remove(chairs)
		removed += 1
	end

	-- 전부 같은 간격으로 다시 두른다. 기준 의자(1번)는 제자리 그대로다.
	for index, chair in ipairs(chairs) do
		placeAround(chair, pivot, reference, (index - 1) / #chairs * math.pi * 2)
	end

	GameConfig.log(("%s 의자 정리 · %d개로 맞춤 (추가 %d · 제거 %d)")
		:format(model.Name, #chairs, added, removed))

	return chairs
end

return TableBuilder
