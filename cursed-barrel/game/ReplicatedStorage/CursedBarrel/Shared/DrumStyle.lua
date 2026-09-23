--[[
	DrumStyle  (Phase 13)
	200리터 철제 드럼의 겉모양을 원통 몸통 위에 덧붙인다. (skin.drum 이 있는 통 스킨)

	  · 굴림 테 2줄 : 몸통을 3등분하는 불룩한 띠 (드럼을 굴릴 때 닿는 곳)
	  · 주름 8줄     : 위 · 아래 칸에 가는 가로 주름 4줄씩
	  · 테두리 2개   : 위아래 끝의 말린 가장자리
	  · 마개 2개     : 뚜껑 위의 큰 마개(은색)와 작은 마개(놋쇠색)

	게임 테이블(서버) · 로비 전시대(서버) · 상점 3D 미리보기(클라이언트)가 모두 이것을 쓴다.
	몸통 크기와 위치는 건드리지 않는다. (칼 슬롯이 몸통 크기에서 계산된다)

	bodyCFrame : 원통 파트의 CFrame (원통은 X 축이 길이 방향이다)
	length     : 몸통 길이 (원통 Size.X)
	diameter   : 몸통 지름 (원통 Size.Y)
	top        : 뚜껑 윗면이 몸통 가운데에서 위로 얼마나 떨어져 있나 (없으면 몸통 윗면). 마개를 그 위에 얹는다
]]

local DrumStyle = {}

local function piece(parent, name, size, cframe, color, material, reflectance)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Reflectance = reflectance or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- 몸통의 +X 가 위를 보도록 맞춘다
function DrumStyle.upright(bodyCFrame)
	if bodyCFrame.RightVector.Y < 0 then
		return bodyCFrame * CFrame.Angles(0, math.pi, 0)
	end
	return bodyCFrame
end

-- 붙일 조각 목록 (이름 · 크기 · 몸통 기준 위치 · 색 이름). 테스트가 모양을 검사할 때도 쓴다.
function DrumStyle.layout(length, diameter, top)
	local list = {}
	local third = length / 6
	-- 굴림 테
	for _, sign in ipairs({ -1, 1 }) do
		table.insert(list, { kind = "hoop", x = sign * third, thick = 0.24, scale = 1.07 })
	end
	-- 위아래 칸의 가는 주름
	for _, sign in ipairs({ -1, 1 }) do
		for k = 1, 4 do
			table.insert(list, { kind = "rib", x = sign * (third + (length / 3) * k / 5), thick = 0.07, scale = 1.025 })
		end
	end
	-- 말린 가장자리
	for _, sign in ipairs({ -1, 1 }) do
		table.insert(list, { kind = "chime", x = sign * (length / 2 - 0.06), thick = 0.12, scale = 1.035 })
	end
	-- 뚜껑 마개 (몸통 윗면 위)
	local radius = diameter / 2
	local surface = math.max(top or 0, length / 2)
	table.insert(list, { kind = "bung", x = surface + 0.05, y = radius * 0.62, z = 0, thick = 0.12, size = diameter * 0.15 })
	table.insert(list, { kind = "bungSmall", x = surface + 0.04, y = -radius * 0.45, z = radius * 0.42, thick = 0.1, size = diameter * 0.1 })
	return list
end

function DrumStyle.build(parent, bodyCFrame, length, diameter, skin, name, top)
	local drum = skin and skin.drum
	if not drum then
		return {}
	end
	local cf = DrumStyle.upright(bodyCFrame)
	local made = {}
	for _, entry in ipairs(DrumStyle.layout(length, diameter, top)) do
		local part
		if entry.kind == "bung" or entry.kind == "bungSmall" then
			local color = entry.kind == "bung" and (drum.bung or Color3.fromRGB(206, 210, 216)) or (drum.bungSmall or drum.bung or Color3.fromRGB(196, 158, 92))
			part = piece(parent, name or "SkinDrum", Vector3.new(entry.thick, entry.size, entry.size),
				cf * CFrame.new(entry.x, entry.y, entry.z), color, Enum.Material.Metal, 0.1)
		else
			local color = entry.kind == "rib" and skin.body or skin.hoop
			part = piece(parent, name or "SkinDrum", Vector3.new(entry.thick, diameter * entry.scale, diameter * entry.scale),
				cf * CFrame.new(entry.x, 0, 0), color, skin.bodyMaterial, skin.reflectance)
		end
		table.insert(made, part)
	end
	return made
end

return DrumStyle
