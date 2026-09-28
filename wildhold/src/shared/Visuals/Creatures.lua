-- 파트로 만든 크리처 (펫 대체 모델 + 밤의 괴물).
-- 블렌더 펫(FBX)을 ReplicatedStorage.PetModels 에 넣기 전까지 쓰이는 대체 모델이며,
-- 뼈 이름(Body, Head, EarL, LegFL …)을 블렌더 리그와 똑같이 맞춰 같은 애니메이션 코드로 움직인다.
--
-- 모델 공간: 발밑 중심이 원점, +Y 위, -Z 정면. 단위 = stud.
-- 반환: rig = {Model, Groups = {이름 = {Pivot, Parent, Parts = {{Part, Offset}}}}, Order, Height, Points}
local B = require(script.Parent.Build)

local C = {}
local M = Enum.Material
local rad = math.rad

local function newRig(name)
	local model = Instance.new("Model")
	model.Name = name
	return {Model = model, Groups = {}, Order = {}, Height = 3, Points = {}, Name = name}
end

local function group(rig, name, pivot, parent)
	rig.Groups[name] = {Name = name, Pivot = pivot, Parent = parent, Parts = {}}
	table.insert(rig.Order, name)
end

local function place(rig, groupName, part, frame)
	local g = rig.Groups[groupName]
	part.CFrame = frame
	part.Parent = rig.Model
	table.insert(g.Parts, {Part = part, Offset = CFrame.new(g.Pivot):Inverse() * frame})
	return part
end

local function at(pos, rx, ry, rz)
	return CFrame.new(pos) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end

local function E(rig, g, size, pos, col, rx, ry, rz, material)
	local p = B.ellipsoid(nil, size, CFrame.new(), col, material or M.SmoothPlastic)
	return place(rig, g, p, at(pos, rx, ry, rz))
end

local function Ball(rig, g, d, pos, col, material)
	local p = B.ball(nil, d, CFrame.new(), col, material or M.SmoothPlastic)
	return place(rig, g, p, CFrame.new(pos))
end

local function Box(rig, g, size, pos, col, rx, ry, rz, material)
	local p = B.block(nil, size, CFrame.new(), col, material or M.SmoothPlastic)
	return place(rig, g, p, at(pos, rx, ry, rz))
end

local function Wedge(rig, g, size, pos, col, rx, ry, rz, material)
	local p = B.wedge(nil, size, CFrame.new(), col, material or M.SmoothPlastic)
	return place(rig, g, p, at(pos, rx, ry, rz))
end

local function Cyl(rig, g, length, d, pos, col, rx, ry, rz, material)
	local p = B.new("Part", nil, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, d, d), Color = Color3.fromHex(col),
		Material = material or M.SmoothPlastic})
	return place(rig, g, p, at(pos, rx, ry, rz))
end

-- 반짝이는 큰 눈: 검은 눈 + 색 홍채 + 하이라이트 2개
local function eyes(rig, g, x, y, z, size, iris, yawOut)
	for _, s in ipairs({-1, 1}) do
		local base = CFrame.new(s * x, y, z) * CFrame.Angles(0, rad(-s * (yawOut or 20)), 0)
		place(rig, g, B.ellipsoid(nil, Vector3.new(size * 0.78, size, size * 0.34), CFrame.new(), "#1c1d2b"), base)
		place(rig, g, B.ellipsoid(nil, Vector3.new(size * 0.52, size * 0.62, size * 0.2), CFrame.new(), iris), base * CFrame.new(0, -size * 0.1, -size * 0.1))
		place(rig, g, B.ellipsoid(nil, Vector3.new(size * 0.26, size * 0.32, size * 0.2), CFrame.new(), "#14141c"), base * CFrame.new(0, -size * 0.06, -size * 0.14))
		place(rig, g, B.ball(nil, size * 0.3, CFrame.new(), "#ffffff", M.Neon), base * CFrame.new(-s * size * 0.12, size * 0.2, -size * 0.16))
		place(rig, g, B.ball(nil, size * 0.14, CFrame.new(), "#ffffff", M.Neon), base * CFrame.new(s * size * 0.14, -size * 0.2, -size * 0.16))
	end
end

local function blush(rig, g, x, y, z, size, yawOut)
	for _, s in ipairs({-1, 1}) do
		place(rig, g, B.ellipsoid(nil, Vector3.new(size, size * 0.55, size * 0.2), CFrame.new(), "#f59aa8"),
			CFrame.new(s * x, y, z) * CFrame.Angles(0, rad(-s * (yawOut or 35)), 0))
	end
end

local function finish(rig, height)
	rig.Height = height
	for _, d in ipairs(rig.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CastShadow = true
		end
	end
	return rig
end

-- ============================================================================ 펫

function C.Mossling()
	local r = newRig("Mossling")
	local G, GD, CR = "#79c96b", "#5aac56", "#f5efcf"
	group(r, "Body", Vector3.new(0, 0.8, 0.2))
	E(r, "Body", Vector3.new(1.3, 1.15, 1.5), Vector3.new(0, 0.78, 0.3), G)
	E(r, "Body", Vector3.new(0.75, 0.7, 0.3), Vector3.new(0, 0.66, -0.4), CR)
	Ball(r, "Body", 0.5, Vector3.new(0, 0.9, 1.05), "#dff5c2")
	group(r, "Head", Vector3.new(0, 1.2, -0.1), "Body")
	E(r, "Head", Vector3.new(1.75, 1.5, 1.55), Vector3.new(0, 1.55, -0.15), G)
	E(r, "Head", Vector3.new(1.0, 0.35, 1.0), Vector3.new(0, 2.2, 0.15), GD)
	E(r, "Head", Vector3.new(0.85, 0.5, 0.35), Vector3.new(0, 1.2, -0.83), CR)
	Ball(r, "Head", 0.12, Vector3.new(0, 1.33, -0.98), "#d56d7c")
	E(r, "Head", Vector3.new(0.38, 0.22, 0.26), Vector3.new(-0.62, 1.35, -0.3), G, 0, 20, 30)
	E(r, "Head", Vector3.new(0.38, 0.22, 0.26), Vector3.new(0.62, 1.35, -0.3), G, 0, -20, -30)
	eyes(r, "Head", 0.34, 1.56, -0.8, 0.46, "#2f8a6a", 18)
	blush(r, "Head", 0.56, 1.3, -0.72, 0.3)
	for _, s in ipairs({-1, 1}) do
		local ear = s < 0 and "EarL" or "EarR"
		group(r, ear, Vector3.new(s * 0.42, 2.05, -0.05), "Head")
		E(r, ear, Vector3.new(0.52, 1.3, 0.12), Vector3.new(s * 0.72, 2.6, 0.1), "#5fb45c", -12, 0, -s * 26)
		E(r, ear, Vector3.new(0.08, 1.05, 0.14), Vector3.new(s * 0.72, 2.6, 0.08), "#3d8c45", -12, 0, -s * 26)
		local leg = s < 0 and "LegFL" or "LegFR"
		group(r, leg, Vector3.new(s * 0.33, 0.5, -0.25), "Body")
		E(r, leg, Vector3.new(0.42, 0.55, 0.42), Vector3.new(s * 0.34, 0.25, -0.3), G)
		E(r, leg, Vector3.new(0.42, 0.18, 0.5), Vector3.new(s * 0.34, 0.08, -0.36), "#eef4d0")
		local back = s < 0 and "LegBL" or "LegBR"
		group(r, back, Vector3.new(s * 0.42, 0.55, 0.6), "Body")
		E(r, back, Vector3.new(0.55, 0.62, 0.7), Vector3.new(s * 0.45, 0.4, 0.62), G)
		E(r, back, Vector3.new(0.44, 0.18, 0.55), Vector3.new(s * 0.45, 0.08, 0.42), "#eef4d0")
	end
	group(r, "Sprout", Vector3.new(0, 2.3, -0.08), "Head")
	Cyl(r, "Sprout", 0.3, 0.07, Vector3.new(0, 2.42, -0.08), "#6a9a48", 0, 0, 90)
	E(r, "Sprout", Vector3.new(0.3, 0.06, 0.16), Vector3.new(-0.14, 2.6, -0.08), "#8ad874", 0, 0, 25)
	E(r, "Sprout", Vector3.new(0.34, 0.06, 0.18), Vector3.new(0.16, 2.62, -0.08), "#8ad874", 0, 0, -25)
	group(r, "Tail", Vector3.new(0, 0.9, 0.95), "Body")
	r.Points.Mouth = Vector3.new(0, 1.2, -1)
	return finish(r, 2.9)
end

function C.Emberpup()
	local r = newRig("Emberpup")
	local O, OD, CR, BR = "#f07f3e", "#d9612d", "#fff0da", "#6b3a2b"
	group(r, "Body", Vector3.new(0, 0.85, 0.15))
	E(r, "Body", Vector3.new(0.95, 0.9, 1.45), Vector3.new(0, 0.85, 0.2), O)
	E(r, "Body", Vector3.new(0.7, 0.75, 0.4), Vector3.new(0, 0.95, -0.45), CR)
	E(r, "Body", Vector3.new(0.5, 0.2, 1.0), Vector3.new(0, 1.28, 0.25), OD)
	group(r, "Head", Vector3.new(0, 1.3, -0.35), "Body")
	E(r, "Head", Vector3.new(1.35, 1.15, 1.2), Vector3.new(0, 1.55, -0.45), O)
	E(r, "Head", Vector3.new(0.6, 0.42, 0.65), Vector3.new(0, 1.3, -1.0), CR)
	Ball(r, "Head", 0.2, Vector3.new(0, 1.42, -1.32), "#2b1d1d")
	for _, s in ipairs({-1, 1}) do
		Wedge(r, "Head", Vector3.new(0.2, 0.45, 0.6), Vector3.new(s * 0.68, 1.3, -0.45), CR, 0, s * 90, s * -20)
	end
	eyes(r, "Head", 0.3, 1.62, -0.98, 0.4, "#e0782c", 22)
	for _, s in ipairs({-1, 1}) do
		local ear = s < 0 and "EarL" or "EarR"
		group(r, ear, Vector3.new(s * 0.35, 2.0, -0.4), "Head")
		E(r, ear, Vector3.new(0.46, 0.95, 0.18), Vector3.new(s * 0.55, 2.4, -0.38), O, 0, 0, -s * 24)
		E(r, ear, Vector3.new(0.28, 0.6, 0.12), Vector3.new(s * 0.54, 2.35, -0.46), "#ffd9c0", 0, 0, -s * 24)
		E(r, ear, Vector3.new(0.3, 0.35, 0.2), Vector3.new(s * 0.72, 2.78, -0.38), BR, 0, 0, -s * 24)
		for i, name in ipairs({s < 0 and "LegFL" or "LegFR", s < 0 and "LegBL" or "LegBR"}) do
			local z = i == 1 and -0.3 or 0.6
			group(r, name, Vector3.new(s * 0.28, 0.7, z), "Body")
			E(r, name, Vector3.new(0.3, 0.75, 0.32), Vector3.new(s * 0.28, 0.42, z), O)
			E(r, name, Vector3.new(0.32, 0.26, 0.42), Vector3.new(s * 0.28, 0.1, z - 0.05), BR)
		end
	end
	group(r, "Tail1", Vector3.new(0, 1.0, 0.85), "Body")
	E(r, "Tail1", Vector3.new(0.55, 0.55, 1.0), Vector3.new(0, 1.25, 1.2), O, -40, 0, 0)
	group(r, "Tail2", Vector3.new(0, 1.6, 1.45), "Tail1")
	E(r, "Tail2", Vector3.new(0.7, 0.95, 0.7), Vector3.new(0, 1.95, 1.45), O)
	E(r, "Tail2", Vector3.new(0.6, 0.45, 0.6), Vector3.new(0, 2.3, 1.42), CR)
	local flame = E(r, "Tail2", Vector3.new(0.55, 0.9, 0.55), Vector3.new(0, 2.8, 1.4), "#ffb02e", 0, 0, 0, M.Neon)
	flame.Name = "FlameCore"
	E(r, "Tail2", Vector3.new(0.3, 0.5, 0.3), Vector3.new(0, 3.2, 1.35), "#fff6b8", 0, 0, 0, M.Neon)
	r.Points.Flame = Vector3.new(0, 2.9, 1.4)
	r.Points.Mouth = Vector3.new(0, 1.35, -1.3)
	return finish(r, 3.3)
end

function C.Shellbub()
	local r = newRig("Shellbub")
	local BL, PALE = "#6fb6e6", "#e8f7ff"
	group(r, "Body", Vector3.new(0, 0.6, 0))
	E(r, "Body", Vector3.new(1.6, 0.9, 1.8), Vector3.new(0, 0.6, 0.05), BL)
	E(r, "Body", Vector3.new(1.4, 0.4, 1.6), Vector3.new(0, 0.38, 0.05), PALE)
	E(r, "Body", Vector3.new(2.0, 1.55, 2.2), Vector3.new(0, 1.0, 0.2), "#2f86a4")
	E(r, "Body", Vector3.new(2.2, 0.32, 2.4), Vector3.new(0, 0.8, 0.2), "#f2e2b3")
	for _, p in ipairs({Vector3.new(0, 1.76, 0.2), Vector3.new(0.52, 1.55, -0.2), Vector3.new(-0.52, 1.55, -0.2),
		Vector3.new(0.52, 1.55, 0.62), Vector3.new(-0.52, 1.55, 0.62), Vector3.new(0, 1.58, 0.9)}) do
		E(r, "Body", Vector3.new(0.62, 0.12, 0.62), p, "#5cc0d6", p.Z * 20, 0, -p.X * 40)
	end
	group(r, "Head", Vector3.new(0, 0.8, -0.8), "Body")
	E(r, "Head", Vector3.new(1.25, 1.1, 1.1), Vector3.new(0, 0.98, -1.15), BL)
	E(r, "Head", Vector3.new(0.9, 0.5, 0.4), Vector3.new(0, 0.72, -1.52), PALE)
	eyes(r, "Head", 0.28, 1.05, -1.6, 0.36, "#3b7fd0", 22)
	blush(r, "Head", 0.46, 0.84, -1.5, 0.24)
	for _, s in ipairs({-1, 1}) do
		local gill = s < 0 and "GillL" or "GillR"
		group(r, gill, Vector3.new(s * 0.55, 1.15, -1.1), "Head")
		for _, a in ipairs({35, 0, -35}) do
			E(r, gill, Vector3.new(0.14, 0.6, 0.14), Vector3.new(s * 0.78, 1.15 + math.sin(rad(a)) * 0.25, -1.08), "#ff7f98", 0, 0, -s * (90 - a))
			Ball(r, gill, 0.2, Vector3.new(s * 1.02, 1.15 + math.sin(rad(a)) * 0.42, -1.06), "#ffd0d9")
		end
		for i, name in ipairs({s < 0 and "LegFL" or "LegFR", s < 0 and "LegBL" or "LegBR"}) do
			local z = i == 1 and -0.55 or 0.7
			group(r, name, Vector3.new(s * 0.6, 0.35, z), "Body")
			E(r, name, Vector3.new(0.55, 0.32, 0.65), Vector3.new(s * 0.82, 0.18, z), BL, 0, s * (i == 1 and -25 or 25), 0)
		end
	end
	group(r, "Tail", Vector3.new(0, 0.45, 0.95), "Body")
	E(r, "Tail", Vector3.new(0.3, 0.25, 0.55), Vector3.new(0, 0.4, 1.2), BL, 15, 0, 0)
	r.Points.Mouth = Vector3.new(0, 0.8, -1.65)
	return finish(r, 2.1)
end

function C.Briarhorn()
	local r = newRig("Briarhorn")
	local L, LD, CR, HOOF, GR = "#bb97e0", "#8d69c0", "#efe4fb", "#4b3a5c", "#4f9d4a"
	group(r, "Body", Vector3.new(0, 2.9, 0.4))
	E(r, "Body", Vector3.new(2.1, 2.0, 3.6), Vector3.new(0, 2.9, 0.55), L)
	E(r, "Body", Vector3.new(1.9, 2.1, 1.4), Vector3.new(0, 3.0, -0.95), L)
	E(r, "Body", Vector3.new(1.0, 1.4, 0.5), Vector3.new(0, 2.85, -1.55), CR)
	E(r, "Body", Vector3.new(1.3, 0.35, 2.6), Vector3.new(0, 3.85, 0.6), LD)
	for i, p in ipairs({Vector3.new(0.5, 3.8, 0.2), Vector3.new(-0.6, 3.7, 0.8), Vector3.new(0.4, 3.75, 1.4), Vector3.new(-0.3, 3.9, -0.2), Vector3.new(0.7, 3.5, 1.0)}) do
		E(r, "Body", Vector3.new(0.3, 0.1, 0.3), p, "#f6efff", 0, i * 20, -p.X * 30)
	end
	group(r, "Neck", Vector3.new(0, 3.4, -1.0), "Body")
	E(r, "Neck", Vector3.new(1.1, 2.1, 1.1), Vector3.new(0, 4.1, -1.5), L, -28, 0, 0)
	for i = 0, 7 do
		local a = rad(i * 45)
		E(r, "Neck", Vector3.new(0.7, 0.18, 1.4), Vector3.new(math.cos(a) * 0.75, 3.95 + math.sin(a) * 0.55, -1.15 + math.abs(math.sin(a)) * 0.2),
			i % 2 == 0 and GR or "#7cc865", -20 + math.sin(a) * 30, math.deg(a) + 90, 0)
	end
	group(r, "Head", Vector3.new(0, 4.7, -2.0), "Neck")
	E(r, "Head", Vector3.new(1.45, 1.35, 1.55), Vector3.new(0, 5.0, -2.35), L)
	E(r, "Head", Vector3.new(0.8, 0.7, 0.95), Vector3.new(0, 4.72, -3.05), CR)
	Ball(r, "Head", 0.3, Vector3.new(0, 4.85, -3.52), "#4a3159")
	eyes(r, "Head", 0.4, 5.1, -2.92, 0.42, "#5fb22e", 26)
	blush(r, "Head", 0.62, 4.75, -2.85, 0.28)
	for _, s in ipairs({-1, 1}) do
		local ear = s < 0 and "EarL" or "EarR"
		group(r, ear, Vector3.new(s * 0.6, 5.3, -2.1), "Head")
		E(r, ear, Vector3.new(0.9, 0.42, 0.15), Vector3.new(s * 1.05, 5.4, -2.0), L, 0, s * 10, s * 15)
		-- 가시덩굴 뿔
		local base = Vector3.new(s * 0.35, 5.55, -2.2)
		local seg = {base, base + Vector3.new(s * 0.45, 0.9, 0.2), base + Vector3.new(s * 1.0, 1.6, 0.45), base + Vector3.new(s * 1.3, 2.35, 0.7)}
		for i = 1, #seg - 1 do
			local a, b = seg[i], seg[i + 1]
			local len = (b - a).Magnitude
			local p = B.new("Part", nil, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(len + 0.1, 0.3 - i * 0.05, 0.3 - i * 0.05),
				Color = Color3.fromHex(i == 3 and "#6f9443" or "#6b5238"), Material = M.Wood})
			place(r, "Head", p, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0))
			Wedge(r, "Head", Vector3.new(0.08, 0.3, 0.14), (a + b) / 2 + Vector3.new(s * 0.12, 0.05, 0), "#efe2c0", 0, s * 90, s * -30)
		end
		local tine = B.new("Part", nil, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 0.16, 0.16), Color = Color3.fromHex("#6f9443"), Material = M.Wood})
		place(r, "Head", tine, CFrame.lookAt(seg[2], seg[2] + Vector3.new(-s * 0.2, 0.8, -0.35)) * CFrame.new(0, 0, -0.4) * CFrame.Angles(0, rad(90), 0))
		for _, fp in ipairs({seg[4], seg[2] + Vector3.new(-s * 0.2, 0.75, -0.35), seg[3] + Vector3.new(0, 0.1, 0)}) do
			Ball(r, "Head", 0.34, fp, "#ff8fc6")
			Ball(r, "Head", 0.14, fp + Vector3.new(0, 0.12, 0), "#ffe27a")
		end
		for i, name in ipairs({s < 0 and "LegFL" or "LegFR", s < 0 and "LegBL" or "LegBR"}) do
			local z = i == 1 and -1.0 or 1.6
			group(r, name, Vector3.new(s * 0.6, 2.5, z), "Body")
			E(r, name, Vector3.new(0.62, 2.6, 0.62), Vector3.new(s * 0.62, 1.35, z), L)
			if i == 2 then
				E(r, name, Vector3.new(0.9, 1.6, 1.2), Vector3.new(s * 0.62, 2.45, z - 0.1), L)
			end
			Cyl(r, name, 0.4, 0.62, Vector3.new(s * 0.62, 0.2, z - 0.05), HOOF, 0, 0, 90)
		end
	end
	group(r, "Tail", Vector3.new(0, 3.3, 2.2), "Body")
	E(r, "Tail", Vector3.new(0.5, 0.9, 0.35), Vector3.new(0, 3.35, 2.45), GR, -40, 0, 0)
	E(r, "Tail", Vector3.new(0.45, 0.8, 0.3), Vector3.new(0.18, 3.25, 2.4), "#7cc865", -50, 0, -25)
	r.Points.Mouth = Vector3.new(0, 4.7, -3.5)
	return finish(r, 7.9)
end

-- ============================================================================ 밤의 괴물
local SHADOW, SHADOW_L = "#2a2138", "#3d2f55"

function C.Crawler()
	local r = newRig("Crawler")
	group(r, "Body", Vector3.new(0, 1.0, 0))
	E(r, "Body", Vector3.new(2.4, 1.3, 2.8), Vector3.new(0, 1.05, 0.45), SHADOW)
	for _, s in ipairs({-1, 1}) do
		E(r, "Body", Vector3.new(1.3, 0.9, 2.7), Vector3.new(s * 0.58, 1.45, 0.45), SHADOW_L, 0, 0, s * -12)
	end
	Box(r, "Body", Vector3.new(0.18, 0.12, 2.2), Vector3.new(0, 1.92, 0.45), "#b04dff", 0, 0, 0, M.Neon)
	group(r, "Head", Vector3.new(0, 1.0, -0.9), "Body")
	E(r, "Head", Vector3.new(1.4, 1.0, 1.1), Vector3.new(0, 1.0, -1.25), SHADOW)
	for _, p in ipairs({Vector3.new(-0.35, 1.2, -1.74), Vector3.new(0.35, 1.2, -1.74), Vector3.new(0, 1.42, -1.66)}) do
		Ball(r, "Head", 0.3, p, "#ff3b5c", M.Neon)
	end
	for _, s in ipairs({-1, 1}) do
		Wedge(r, "Head", Vector3.new(0.18, 0.35, 0.8), Vector3.new(s * 0.4, 0.62, -1.9), "#d8cfe6", 0, 0, 0)
	end
	local legs = {{"LegFL", -1, -0.5}, {"LegFR", 1, -0.5}, {"LegML", -1, 0.35}, {"LegMR", 1, 0.35}, {"LegBL", -1, 1.15}, {"LegBR", 1, 1.15}}
	for _, leg in ipairs(legs) do
		local name, s, z = leg[1], leg[2], leg[3]
		group(r, name, Vector3.new(s * 0.9, 0.95, z), "Body")
		Box(r, name, Vector3.new(1.4, 0.22, 0.22), Vector3.new(s * 1.45, 0.75, z), SHADOW_L, 0, 0, s * -28)
		Box(r, name, Vector3.new(0.2, 0.8, 0.2), Vector3.new(s * 2.05, 0.35, z), SHADOW, 0, 0, s * 10)
	end
	return finish(r, 2.3)
end

function C.Runner()
	local r = newRig("Runner")
	group(r, "Body", Vector3.new(0, 1.5, 0))
	E(r, "Body", Vector3.new(1.05, 1.05, 2.5), Vector3.new(0, 1.55, 0.1), SHADOW)
	for i = 0, 3 do
		Wedge(r, "Body", Vector3.new(0.14, 0.5, 0.5), Vector3.new(0, 2.15 - i * 0.03, -0.6 + i * 0.5), SHADOW_L, 0, 180, 0)
	end
	group(r, "Head", Vector3.new(0, 1.8, -1.0), "Body")
	E(r, "Head", Vector3.new(0.85, 0.8, 1.0), Vector3.new(0, 1.95, -1.3), SHADOW)
	Wedge(r, "Head", Vector3.new(0.55, 0.4, 0.8), Vector3.new(0, 1.8, -1.9), SHADOW_L, 0, 0, 0)
	for _, s in ipairs({-1, 1}) do
		Wedge(r, "Head", Vector3.new(0.14, 0.6, 0.35), Vector3.new(s * 0.3, 2.45, -1.2), SHADOW_L, 0, 0, s * -10)
		Ball(r, "Head", 0.22, Vector3.new(s * 0.25, 2.05, -1.72), "#ffd23b", M.Neon)
	end
	for _, leg in ipairs({{"LegFL", -1, -0.7}, {"LegFR", 1, -0.7}, {"LegBL", -1, 0.9}, {"LegBR", 1, 0.9}}) do
		local name, s, z = leg[1], leg[2], leg[3]
		group(r, name, Vector3.new(s * 0.38, 1.3, z), "Body")
		E(r, name, Vector3.new(0.3, 1.45, 0.3), Vector3.new(s * 0.4, 0.7, z), SHADOW_L)
	end
	group(r, "Tail", Vector3.new(0, 1.7, 1.25), "Body")
	E(r, "Tail", Vector3.new(0.28, 0.28, 1.4), Vector3.new(0, 1.9, 1.85), SHADOW, 25, 0, 0)
	Ball(r, "Tail", 0.3, Vector3.new(0, 2.2, 2.5), "#ffd23b", M.Neon)
	return finish(r, 2.7)
end

function C.Brute()
	local r = newRig("Brute")
	local ROCK, CRACK = "#3a3346", "#c35cff"
	group(r, "Body", Vector3.new(0, 2.4, 0))
	Box(r, "Body", Vector3.new(3.4, 2.9, 2.6), Vector3.new(0, 2.9, 0), ROCK, 6, 0, 0, M.Slate)
	Box(r, "Body", Vector3.new(2.6, 1.2, 2.2), Vector3.new(0, 1.7, 0.1), "#312b3b", 0, 0, 0, M.Slate)
	Box(r, "Body", Vector3.new(2.2, 0.16, 0.12), Vector3.new(0, 3.1, -1.34), CRACK, 0, 0, 18, M.Neon)
	Box(r, "Body", Vector3.new(0.14, 1.2, 0.12), Vector3.new(0.6, 2.6, -1.34), CRACK, 0, 0, -10, M.Neon)
	for _, s in ipairs({-1, 1}) do
		Box(r, "Body", Vector3.new(1.4, 1.1, 1.4), Vector3.new(s * 1.6, 4.3, 0), "#4a4258", 0, 0, s * 12, M.Slate)
	end
	group(r, "Head", Vector3.new(0, 4.3, -0.3), "Body")
	Box(r, "Head", Vector3.new(1.4, 1.1, 1.2), Vector3.new(0, 4.6, -0.6), ROCK, 0, 0, 0, M.Slate)
	Ball(r, "Head", 0.55, Vector3.new(0, 4.65, -1.2), "#ff8a3b", M.Neon)
	for _, s in ipairs({-1, 1}) do
		local arm = s < 0 and "ArmL" or "ArmR"
		group(r, arm, Vector3.new(s * 2.0, 4.0, 0), "Body")
		E(r, arm, Vector3.new(1.1, 2.2, 1.1), Vector3.new(s * 2.25, 2.9, 0), ROCK, 0, 0, s * 8, M.Slate)
		Box(r, arm, Vector3.new(1.6, 1.4, 1.6), Vector3.new(s * 2.4, 1.3, -0.2), "#4a4258", 0, 0, 0, M.Slate)
		local leg = s < 0 and "LegL" or "LegR"
		group(r, leg, Vector3.new(s * 0.8, 1.3, 0), "Body")
		Box(r, leg, Vector3.new(1.2, 1.4, 1.3), Vector3.new(s * 0.85, 0.7, 0), "#312b3b", 0, 0, 0, M.Slate)
	end
	return finish(r, 5.3)
end

function C.Howler()
	local r = newRig("Howler")
	local FUR, MANE, GLOW = "#231a33", "#3b2754", "#d04dff"
	group(r, "Body", Vector3.new(0, 3.2, 0))
	E(r, "Body", Vector3.new(3.2, 3.0, 5.2), Vector3.new(0, 3.3, 0.4), FUR)
	E(r, "Body", Vector3.new(3.4, 3.4, 2.2), Vector3.new(0, 3.9, -1.4), MANE)
	for i = 0, 6 do
		Wedge(r, "Body", Vector3.new(0.3, 1.3, 1.0), Vector3.new(0, 5.2 - i * 0.12, -1.4 + i * 0.6), MANE, 0, 180, 0)
	end
	group(r, "Head", Vector3.new(0, 4.4, -2.2), "Body")
	E(r, "Head", Vector3.new(2.2, 2.0, 2.4), Vector3.new(0, 4.6, -2.8), FUR)
	Wedge(r, "Head", Vector3.new(1.3, 1.0, 1.6), Vector3.new(0, 4.2, -4.1), MANE, 0, 0, 0)
	for _, s in ipairs({-1, 1}) do
		Ball(r, "Head", 0.45, Vector3.new(s * 0.55, 4.95, -3.9), GLOW, M.Neon)
		local horn = B.new("Part", nil, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 0.4, 0.4), Color = Color3.fromHex("#e9dcff"), Material = M.SmoothPlastic})
		place(r, "Head", horn, CFrame.lookAt(Vector3.new(s * 0.7, 5.6, -2.6), Vector3.new(s * 1.8, 7.2, -1.8)) * CFrame.new(0, 0, -0.9) * CFrame.Angles(0, rad(90), 0))
		Ball(r, "Head", 0.5, Vector3.new(s * 1.7, 7.0, -1.9), GLOW, M.Neon)
		for i, name in ipairs({s < 0 and "LegFL" or "LegFR", s < 0 and "LegBL" or "LegBR"}) do
			local z = i == 1 and -1.4 or 2.0
			group(r, name, Vector3.new(s * 1.1, 2.6, z), "Body")
			E(r, name, Vector3.new(0.9, 2.9, 0.9), Vector3.new(s * 1.15, 1.4, z), FUR)
			Box(r, name, Vector3.new(1.0, 0.4, 1.2), Vector3.new(s * 1.15, 0.2, z - 0.2), MANE)
		end
	end
	group(r, "Tail", Vector3.new(0, 3.8, 2.8), "Body")
	E(r, "Tail", Vector3.new(0.8, 0.8, 2.6), Vector3.new(0, 4.4, 3.8), MANE, 30, 0, 0)
	Ball(r, "Tail", 0.6, Vector3.new(0, 5.0, 4.9), GLOW, M.Neon)
	return finish(r, 7.4)
end

-- 이름 → 빌더
function C.build(kind)
	local fn = C[kind]
	if type(fn) ~= "function" or kind == "build" then
		return nil
	end
	return fn()
end

return C
