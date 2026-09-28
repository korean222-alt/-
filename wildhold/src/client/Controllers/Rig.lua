-- 크리처 리그 두 종류를 같은 방식으로 움직인다.
--  1) Mesh  : 블렌더에서 만든 스킨 메쉬(FBX → ReplicatedStorage.PetModels). Bone.Transform 을 쓴다.
--  2) Parts : Creatures.lua 로 조립한 대체 모델. 파트 묶음(그룹)을 관절처럼 돌린다.
-- 포즈 = {뼈이름 = CFrame}. 회전은 "모델 공간" 축(X 오른쪽, Y 위, -Z 정면) 기준, 관절 위치에서 돈다.
local Rig = {}
Rig.__index = Rig

local IDENTITY = CFrame.identity

local function strip(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery, d.Massless = true, false, false, false, true
		elseif d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("Animator") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

-- ===================================================================== 파트 리그
function Rig.fromParts(built, scale)
	scale = scale or 1
	local self = setmetatable({Kind = "Parts", Model = built.Model, Height = built.Height * scale, Scale = scale, Order = built.Order,
		Groups = {}, Parts = {}, Entries = {}, Frames = {}, Points = {}}, Rig)
	for name, point in pairs(built.Points or {}) do
		self.Points[name] = point * scale
	end
	for _, name in ipairs(built.Order) do
		local g = built.Groups[name]
		local pivot = g.Pivot * scale
		self.Groups[name] = {Name = name, Parent = g.Parent, Pivot = CFrame.new(pivot), Unpivot = CFrame.new(-pivot)}
		for _, e in ipairs(g.Parts) do
			local part = e.Part
			if scale ~= 1 then
				part.Size = part.Size * scale
			end
			local offset = e.Offset - e.Offset.Position + e.Offset.Position * scale
			table.insert(self.Parts, part)
			table.insert(self.Entries, {Group = name, Local = CFrame.new(pivot) * offset})
		end
	end
	strip(self.Model)
	return self
end

-- ===================================================================== 스킨 메쉬 리그
function Rig.fromMesh(model, targetHeight)
	strip(model)
	local self = setmetatable({Kind = "Mesh", Model = model, Bones = {}, Rest = {}, RestInv = {}, Points = {}}, Rig)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") and not self.Bones[d.Name] then
			self.Bones[d.Name] = d
		end
	end
	local _, size = model:GetBoundingBox()
	if size.Y > 0.01 then
		model:ScaleTo(model:GetScale() * targetHeight / size.Y)
	end
	local box, size2 = model:GetBoundingBox()
	local body = self.Bones.Body or self.Bones.Root
	local front = self.Bones.Front or self.Bones.Head
	local bodyPos = body and body.WorldPosition or box.Position
	local forward = front and (front.WorldPosition - bodyPos) or box.LookVector
	forward = Vector3.new(forward.X, 0, forward.Z)
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(0, 0, -1)
	end
	local bottom = box.Position.Y - size2.Y / 2
	local origin = Vector3.new(bodyPos.X, bottom, bodyPos.Z)
	local frame = CFrame.lookAt(origin, origin + forward.Unit)
	self.Offset = frame:ToObjectSpace(model:GetPivot())
	self.Height = size2.Y
	for name, bone in pairs(self.Bones) do
		local rest = frame:ToObjectSpace(bone.WorldCFrame)
		self.Rest[name] = rest.Rotation
		self.RestInv[name] = rest.Rotation:Inverse()
		self.Points[name] = rest.Position
	end
	return self
end

-- root: 발밑 중심의 월드 CFrame (정면 = LookVector)
function Rig:Apply(root, pose)
	if self.Kind == "Mesh" then
		self.Model:PivotTo(root * self.Offset)
		for name, bone in pairs(self.Bones) do
			local p = pose[name]
			if p then
				local restInv = self.RestInv[name]
				bone.Transform = CFrame.new(restInv * p.Position) * (restInv * p.Rotation * self.Rest[name])
			elseif bone.Transform ~= IDENTITY then
				bone.Transform = IDENTITY
			end
		end
		return
	end
	local world = {}
	for _, name in ipairs(self.Order) do
		local g = self.Groups[name]
		local parent = g.Parent and world[g.Parent] or root
		world[name] = parent * g.Pivot * (pose[name] or IDENTITY) * g.Unpivot
	end
	local frames = self.Frames
	for i, e in ipairs(self.Entries) do
		frames[i] = world[e.Group] * e.Local
	end
	if self.Model:IsDescendantOf(workspace) then
		workspace:BulkMoveTo(self.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, part in ipairs(self.Parts) do
			part.CFrame = frames[i]
		end
	end
end

-- 효과를 붙일 점(꼬리 불꽃 등)의 현재 월드 위치. 스킨 메쉬는 움직이는 뼈 위치를 그대로 쓴다.
function Rig:PointWorld(root, name, fallback)
	local bone = self.Bones and self.Bones[name]
	if bone then
		return CFrame.new(bone.TransformedWorldCFrame.Position)
	end
	local p = self.Points[name] or fallback or Vector3.new(0, self.Height * 0.6, 0)
	return root * CFrame.new(p)
end

function Rig:SetTransparency(alpha)
	for _, d in ipairs(self.Model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Tag" then
			d.LocalTransparencyModifier = alpha
		end
	end
end

function Rig:Destroy()
	self.Model:Destroy()
end

return Rig
