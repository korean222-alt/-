--[[
	BarrelStyle  (Phase 14)
	미리보기 · 전시대 통에 판자 결과 양 끝 얇은 쇠테를 덧붙인다. (게임 테이블의 통은 GameTable 이 같은 모양으로 붙인다)

	나무 통(Wood · WoodPlanks)만 꾸민다. 드럼통 · 주름 통은 DrumStyle 이나 주름이 따로 있다.
	bodyCFrame 의 X 축이 통의 세로축이다. (원통 파트의 긴 축)
]]

local BarrelStyle = {}

local function decor(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

function BarrelStyle.isWooden(skin)
	return (skin.bodyMaterial == Enum.Material.Wood or skin.bodyMaterial == Enum.Material.WoodPlanks)
		and not skin.drum and not skin.ribbed
end

function BarrelStyle.decorate(parent, bodyCFrame, length, diameter, skin)
	if not BarrelStyle.isWooden(skin) then
		return
	end
	local radius = diameter * 0.5
	local staves = 12
	for index = 1, staves do
		local angle = (index - 1) / staves * math.pi * 2
		local frame = bodyCFrame * CFrame.Angles(angle, 0, 0)
		if index % 2 == 0 then
			local shade = (index % 4 == 0) and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
			decor(parent, "Stave", Vector3.new(length * 0.95, 0.02, 2 * math.pi * radius / staves * 0.92),
				frame * CFrame.new(0, radius + 0.003, 0), skin.body:Lerp(shade, 0.09), skin.bodyMaterial)
		end
		decor(parent, "StaveSeam", Vector3.new(length * 0.97, 0.04, 0.07),
			bodyCFrame * CFrame.Angles(angle + math.pi / staves, 0, 0) * CFrame.new(0, radius + 0.006, 0),
			skin.body:Lerp(Color3.new(0, 0, 0), 0.45), Enum.Material.Wood)
	end
	for _, x in ipairs({ -0.46, 0.46 }) do
		decor(parent, "ChimeHoop", Vector3.new(0.14, diameter * 1.025, diameter * 1.025), bodyCFrame * CFrame.new(length * x, 0, 0),
			skin.hoop, skin.hoopMaterial or Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

return BarrelStyle
