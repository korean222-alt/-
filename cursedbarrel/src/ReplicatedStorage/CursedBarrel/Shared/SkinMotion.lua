--[[
	SkinMotion  (Phase 17)
	비싼 스킨의 움직이는 장식을 각자 화면에서 만든다. (서버는 SkinFX_Motion 표시만 단다)

	  전설  발밑 룬 고리가 천천히 돈다 (통 · 해적)
	  신화  Blender 용이 칼 · 통 · 해적 둘레를 돌고, 꽃잎이 흩날리며 떨어진다

	· 표시(Configuration, 태그 CB_SkinMotion)가 붙은 파트를 따라간다. 표시가 사라지면 장식도 사라진다.
	· 3D 미리보기(ViewportFrame 의 WorldModel) 안의 표시는 그 WorldModel 안에 장식을 만든다.
	· 한 번에 움직이는 수를 제한한다 (가까운 것부터 MaxActive 개). 효과 "낮음"이면 꽃잎을 줄인다.
	· Blender 모델(CursedBarrelSkins)이 없으면 아무것도 하지 않는다.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local MeshKit = require(script.Parent.MeshKit)
local FX = require(script.Parent.PremiumFX)

local SkinMotion = {}
SkinMotion.Tag = "CB_SkinMotion"
SkinMotion.MaxActive = 14
SkinMotion.MaxDistance = 150

-- Phase 17.1 : 흰 조각처럼 보인다고 해서 진한 벚꽃색으로
local PETAL_COLORS = { Color3.fromRGB(255, 140, 184), Color3.fromRGB(255, 110, 165), Color3.fromRGB(250, 168, 204) }

-- 종류별 설정 (Scale 1 기준, 스터드)
--   dragon : 용 모델 이름 · 배율 · 축 위의 높이 · 도는 속도(라디안/초)
--   petals : 꽃잎이 떨어지는 원기둥 (반지름 · 위 · 아래)
--   ring   : 룬 고리 반지름 · 높이
local KIND = {
	Knife = {
		dragon = { asset = "DragonCoil", scale = 1, lift = 0, speed = 1.5 },
		petals = { count = 9, radius = 1.3, top = 3.4, bottom = -0.6, size = 1 },
	},
	-- Phase 17.1 : 통 둘레의 빛나는 룬 고리는 뺐다 (통은 용 · 꽃잎만)
	Barrel = {
		dragon = { asset = "DragonRing", scale = 1, lift = 0, speed = 0.7 },
		petals = { count = 8, radius = 3, top = 5, bottom = -2.1, size = 1 },
	},
	Ghost = {
		dragon = { asset = "DragonCoil", scale = 3.3, lift = -3.6, speed = 1.1 },
		petals = { count = 8, radius = 3, top = 5, bottom = -3.5, size = 1.1 },
		ring = { radius = 2.4, height = -3.3 },
	},
}

local active = {} -- [marker] = entry
local connection = nil
local clientFolder = nil

local function lowQuality()
	local ok, q = pcall(FX.quality)
	return ok and q == "Low"
end

local function reduced()
	local player = Players.LocalPlayer
	return player ~= nil and player:GetAttribute("Setting_reducedFX") == true
end

local function folderFor(anchor)
	local world = anchor:FindFirstAncestorWhichIsA("WorldModel")
	if world then
		return world, world
	end
	if not clientFolder or not clientFolder.Parent then
		clientFolder = Instance.new("Folder")
		clientFolder.Name = "CursedBarrel_SkinMotion"
		clientFolder.Parent = workspace
	end
	return clientFolder, workspace
end

local function decor(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Locked = true
end

local function build(marker)
	local anchor = marker.Parent
	if not (anchor and anchor:IsA("BasePart")) then
		return nil
	end
	local kind = KIND[marker:GetAttribute("Kind")]
	if not kind then
		return nil
	end
	local rank = marker:GetAttribute("Rank") or 1
	local scale = marker:GetAttribute("Scale") or 1
	local color = marker:GetAttribute("Color") or Color3.fromRGB(68, 240, 218)
	local accent = marker:GetAttribute("Accent") or Color3.fromRGB(255, 212, 126)
	local parent, root = folderFor(anchor)
	local model = Instance.new("Model")
	model.Name = "SkinMotion"
	model.Parent = parent
	local entry = { marker = marker, anchor = anchor, model = model, root = root, kind = kind, scale = scale,
		pieces = {}, petals = {}, ring = nil, born = os.clock(), seed = math.random() * 100,
		static = marker:GetAttribute("Static") == true, placed = false }

	if rank >= 5 and MeshKit.has(kind.dragon.asset) then
		local styles = {
			Scales = { color = color, material = Enum.Material.SmoothPlastic, reflectance = 0.15 },
			Mane = { color = accent, material = Enum.Material.SmoothPlastic },
			Horn = { color = accent:Lerp(Color3.new(1, 1, 1), 0.5), material = Enum.Material.Metal, reflectance = 0.2 },
			Eyes = { color = accent:Lerp(Color3.new(1, 1, 1), 0.6), material = Enum.Material.Neon },
		}
		local s = scale * kind.dragon.scale
		for _, name in ipairs(MeshKit.Catalog.Assets[kind.dragon.asset]) do
			local slot = MeshKit.slotOf(name)
			local opts = table.clone(styles[slot] or {})
			opts.parent = model
			opts.name = "Dragon" .. slot
			opts.scale = s
			local part = MeshKit.place(name, CFrame.new(), opts)
			if part then
				decor(part)
				table.insert(entry.pieces, { part = part, offset = CFrame.new(MeshKit.Catalog.Pieces[name].center * s) * MeshKit.fixOf(name) })
			end
		end
	end

	if rank >= 5 and MeshKit.has("Petal") then
		local p = kind.petals
		local count = lowQuality() and math.ceil(p.count / 3) or p.count
		if reduced() then
			count = math.min(count, 3)
		end
		for i = 1, count do
			local part = MeshKit.place("SK_Petal", CFrame.new(), {
				parent = model, name = "Petal", scale = scale * p.size,
				color = PETAL_COLORS[(i % #PETAL_COLORS) + 1], material = Enum.Material.SmoothPlastic,
			})
			if part then
				decor(part)
				local r = math.random()
				table.insert(entry.petals, {
					part = part,
					angle = math.random() * math.pi * 2,
					radius = p.radius * scale * math.sqrt(0.15 + 0.85 * math.random()),
					height = (p.bottom + (p.top - p.bottom) * r) * scale,
					fall = (0.55 + math.random() * 0.5) * scale,
					spin = (math.random() - 0.5) * 6,
					sway = math.random() * math.pi * 2,
				})
			end
		end
	end

	if rank >= 4 and kind.ring and MeshKit.has("RuneRing") then
		local ring = MeshKit.place("SK_RuneRing", CFrame.new(), {
			parent = model, name = "RuneRing", scale = scale * kind.ring.radius,
			color = accent, material = Enum.Material.Neon, transparency = 0.25,
		})
		if ring then
			decor(ring)
			entry.ring = ring
		end
	end

	if #entry.pieces == 0 and #entry.petals == 0 and not entry.ring then
		model:Destroy()
		return nil
	end
	return entry
end

local function destroy(marker)
	local entry = active[marker]
	if entry then
		active[marker] = nil
		if entry.model then
			entry.model:Destroy()
		end
	end
end

local moveParts = {}
local moveFrames = {}
local byRoot = {}

local function queue(root, part, cf)
	local bucket = byRoot[root]
	if not bucket then
		bucket = { parts = {}, frames = {} }
		byRoot[root] = bucket
	end
	table.insert(bucket.parts, part)
	table.insert(bucket.frames, cf)
end

local function step(dt)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local now = os.clock()
	-- 가까운 것부터 MaxActive 개만 움직인다 (미리보기 창 안의 것은 늘 움직인다)
	local list = {}
	for marker, entry in pairs(active) do
		if not marker.Parent or not entry.anchor.Parent or entry.marker.Parent ~= entry.anchor then
			destroy(marker)
		else
			local distance = entry.root == workspace and (entry.anchor.CFrame.Position - eye).Magnitude or 0
			entry.distance = distance
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)
	local moving = 0
	for _, entry in ipairs(list) do
		local visible
		if entry.static then
			visible = true
		else
			moving += 1
			visible = moving <= SkinMotion.MaxActive and entry.distance <= SkinMotion.MaxDistance
		end
		if entry.model.Parent and visible ~= entry.visible then
			entry.visible = visible
			for _, child in ipairs(entry.model:GetChildren()) do
				if child:IsA("BasePart") then
					child.LocalTransparencyModifier = visible and 0 or 1
				end
			end
		end
		if visible and entry.static and entry.placed then
			-- 한 번 놓은 정지 그림 (상점 카드)
		elseif visible then
			entry.placed = true
			local frameOffset = entry.marker:GetAttribute("Frame") or CFrame.new()
			local frame = entry.anchor.CFrame * frameOffset
			local t = now - entry.born
			local kind = entry.kind
			if #entry.pieces > 0 then
				local spin = CFrame.Angles(0, t * kind.dragon.speed, 0)
				local bob = CFrame.new(0, math.sin(t * 1.3 + entry.seed) * 0.08 * entry.scale * kind.dragon.scale + kind.dragon.lift * entry.scale, 0)
				local base = frame * bob * spin
				for _, piece in ipairs(entry.pieces) do
					queue(entry.root, piece.part, base * piece.offset)
				end
			end
			local p = kind.petals
			for _, petal in ipairs(entry.petals) do
				petal.height -= petal.fall * dt
				if petal.height < p.bottom * entry.scale then
					petal.height = p.top * entry.scale
					petal.angle = math.random() * math.pi * 2
				end
				petal.angle += dt * 0.35
				local sway = math.sin(t * 1.7 + petal.sway) * 0.25 * entry.scale
				local position = Vector3.new(math.cos(petal.angle) * (petal.radius + sway), petal.height, math.sin(petal.angle) * (petal.radius + sway))
				local cf = CFrame.new(frame.Position + position) * CFrame.Angles(t * petal.spin, t * petal.spin * 0.7 + petal.sway, math.sin(t * 2 + petal.sway) * 0.8)
				queue(entry.root, petal.part, cf)
			end
			if entry.ring then
				local ringFrame = frame * CFrame.new(0, kind.ring.height * entry.scale, 0) * CFrame.Angles(0, -t * 0.4, 0)
				queue(entry.root, entry.ring, ringFrame * CFrame.new(MeshKit.Catalog.Pieces.SK_RuneRing.center * entry.scale * kind.ring.radius) * MeshKit.fixOf("SK_RuneRing"))
				entry.ring.Transparency = 0.25 + 0.2 * (0.5 + 0.5 * math.sin(t * 2.2))
			end
		end
	end
	for root, bucket in pairs(byRoot) do
		if root.Parent or root == workspace then
			pcall(root.BulkMoveTo, root, bucket.parts, bucket.frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		table.clear(bucket.parts)
		table.clear(bucket.frames)
	end
	table.clear(byRoot)
	table.clear(moveParts)
	table.clear(moveFrames)
end

local function track(marker)
	if active[marker] or not marker:IsA("Configuration") then
		return
	end
	local ok, entry = pcall(build, marker)
	if ok and entry then
		active[marker] = entry
		marker.AncestryChanged:Connect(function()
			if not marker:IsDescendantOf(game) then
				destroy(marker)
			end
		end)
	elseif not ok then
		warn("[CursedBarrel] SkinMotion: " .. tostring(entry))
	end
end

function SkinMotion.start()
	if connection or not RunService:IsClient() then
		return
	end
	for _, marker in ipairs(CollectionService:GetTagged(SkinMotion.Tag)) do
		task.spawn(track, marker)
	end
	CollectionService:GetInstanceAddedSignal(SkinMotion.Tag):Connect(function(marker)
		task.defer(track, marker)
	end)
	CollectionService:GetInstanceRemovedSignal(SkinMotion.Tag):Connect(destroy)
	connection = RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then
			warn("[CursedBarrel] SkinMotion step: " .. tostring(err))
		end
	end)
end

-- Blender 스킨 모델이 늦게 도착하면 (서버가 옮긴 직후) 이미 붙은 표시를 다시 만든다
function SkinMotion.rebuild()
	local markers = {}
	for marker in pairs(active) do
		table.insert(markers, marker)
	end
	for _, marker in ipairs(markers) do
		destroy(marker)
	end
	for _, marker in ipairs(CollectionService:GetTagged(SkinMotion.Tag)) do
		track(marker)
	end
end

return SkinMotion
