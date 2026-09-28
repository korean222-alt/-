-- 펫 얼굴 사진 (ViewportFrame). 팀 카드, 펫 목록, 도감에서 쓴다.
local RS = game:GetService("ReplicatedStorage")
local Rig = require(script.Parent.Rig)
local Creatures = require(RS.Shared.Visuals.Creatures)
local P = require(RS.Shared.Config.PetConfig)

local Portrait = {}

local function build(species)
	local height = P.Heights[species] or 3
	local models = RS:FindFirstChild("PetModels")
	local template = models and models:FindFirstChild(species)
	if template and template:IsA("Model") then
		local ok, rig = pcall(Rig.fromMesh, template:Clone(), height)
		if ok then return rig end
	end
	local built = Creatures.build(species) or Creatures.Mossling()
	return Rig.fromParts(built, height / built.Height)
end

-- silhouette=true 면 아직 못 잡은 펫처럼 검은 그림자로 그린다
function Portrait.make(parent, species, props, silhouette)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromHex("#9aa6b8")
	vp.LightColor = Color3.fromHex("#fff4e0")
	vp.LightDirection = Vector3.new(-0.6, -1, -0.8)
	for k, v in pairs(props or {}) do vp[k] = v end
	local rig = build(species)
	rig:Apply(CFrame.new(), {Head = CFrame.Angles(0, math.rad(-12), 0)})
	rig.Model.Parent = vp
	if silhouette then
		vp.ImageColor3 = Color3.fromHex("#1d2433")
	end
	local h = rig.Height
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local focus = Vector3.new(0, h * (species == "Briarhorn" and 0.62 or 0.5), 0)
	camera.CFrame = CFrame.lookAt(Vector3.new(-h * 0.85, h * 0.85, -h * 2.2), focus)
	camera.Parent = vp
	vp.CurrentCamera = camera
	vp.Parent = parent
	return vp
end

return Portrait
