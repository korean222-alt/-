-- 건축 키트 메쉬: blender/build_kit.py → assets/build/BuildModels.fbx → Studio "3D 가져오기" → ReplicatedStorage.BuildModels
-- 있으면 제작대·벽·문·포탑·함정·배치대·횃불대·알·수레가 이 메쉬로 바뀌고, 없으면 Structures 의 파트 대체 모델을 쓴다.
-- 에셋 크기·중심은 Config/KitSizes (블렌더 스크립트가 만든다). 에셋의 앞(-Z) = 괴물이 오는 바깥쪽.
local RS = game:GetService("ReplicatedStorage")

local K = {}
local okSizes, Sizes = pcall(function() return require(RS.Shared.Config.KitSizes) end)
if not okSizes then Sizes = {} end
local okBuild, BC = pcall(function() return require(RS.Shared.Config.BuildConfig) end)
if not okBuild then BC = {} end

-- Studio 에서 가져온 BuildModels 를 찾는다. 작업 공간에 그대로 두었으면 ReplicatedStorage 로 옮긴다.
local function root()
	local r = RS:FindFirstChild("BuildModels")
	if not r then
		r = workspace:FindFirstChild("BuildModels")
		if r then r.Parent = RS end
	end
	return r
end

function K.part(name)
	local r = root()
	local found = r and r:FindFirstChild(name, true)
	if found and not found:IsA("BasePart") then found = found:FindFirstChildWhichIsA("BasePart", true) end
	return found
end

function K.has(name)
	return K.part(name) ~= nil
end

-- at = 바닥 가운데 CFrame (-Z = 앞). 반환: 복제한 MeshPart (에셋이 없으면 nil)
function K.place(parent, name, at, scale)
	local src = K.part(name)
	if not src then return nil end
	scale = scale or 1
	local info = Sizes[name]
	-- 가져올 때 배율이 달랐으면(예: 0.01) 원래 크기로 되돌린다. 축이 바뀌어도 되게 세 변의 합으로 비교
	local fix = 1
	if info then
		local want = info.Size[1] + info.Size[2] + info.Size[3]
		local have = src.Size.X + src.Size.Y + src.Size.Z
		if have > 0 then fix = want / have end
	end
	local rot = src.CFrame - src.Position
	local centre = info and Vector3.new(info.Center[1], info.Center[2], info.Center[3]) or Vector3.new(0, src.Size.Y * fix / 2, 0)
	local frame = at
	if BC.KitFlip then frame = frame * CFrame.Angles(0, math.pi, 0) end
	local p = src:Clone()
	p.Size = src.Size * fix * scale
	p.CFrame = frame * CFrame.new(centre * scale) * rot
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, true
	p:SetAttribute("KitAsset", name)
	p.Parent = parent
	return p
end

return K
