-- 월드에 떠 있는 정보: Core 체력, 가까운 자원 노드 이름·체력, 부서지는 시설 체력.
-- 이전 빌드처럼 모든 물체에 글자를 띄우지 않고, 가까이 있거나 필요할 때만 보여준다.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local R = require(RS.Shared.Config.ResourceConfig)

local W = {}
local player = Players.LocalPlayer
local ICON = R.Icons
local FONT = Enum.Font.FredokaOne

local function new(className, parent, props)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end

local function bar(gui, y, width, height, color)
	local back = new("Frame", gui, {Name = "Bar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(width, height), BackgroundColor3 = Color3.fromHex("#1c2330"), BackgroundTransparency = 0.15, BorderSizePixel = 0})
	new("UICorner", back, {CornerRadius = UDim.new(0, height / 2)})
	new("UIStroke", back, {Color = Color3.fromHex("#0d1118"), Thickness = 1.5})
	local fill = new("Frame", back, {Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0})
	new("UICorner", fill, {CornerRadius = UDim.new(0, height / 2)})
	return fill
end

function W:Init()
	local root = workspace:WaitForChild("WILDHOLD")
	self.Gui = new("Folder", player:WaitForChild("PlayerGui"), {Name = "WorldLabels"})
	-- Core
	local base = root:WaitForChild("Base")
	local coreModel = base:WaitForChild("Core")
	local core = coreModel:WaitForChild("Core")
	local coreGui = new("BillboardGui", self.Gui, {Adornee = core, Size = UDim2.fromOffset(190, 44), StudsOffset = Vector3.new(0, 9.5, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 400})
	new("TextLabel", coreGui, {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Font = FONT, TextSize = 17,
		TextColor3 = Color3.fromHex("#b8fff6"), TextStrokeTransparency = 0.3, Text = "💎 CORE"})
	local coreFill = bar(coreGui, 23, 150, 12, Color3.fromHex("#6ff3e0"))
	local function coreUpdate()
		local hp, maxHP = core:GetAttribute("CurrentHealth") or 1, core:GetAttribute("MaxHealth") or 1
		coreFill.Size = UDim2.fromScale(math.clamp(hp / maxHP, 0, 1), 1)
		coreFill.BackgroundColor3 = hp / maxHP > 0.35 and Color3.fromHex("#6ff3e0") or Color3.fromHex("#ff6b6b")
	end
	core:GetAttributeChangedSignal("CurrentHealth"):Connect(coreUpdate)
	coreUpdate()

	-- 자원 노드: 이름표 풀(pool)
	self.NodeTags = {}
	local nodes = root:WaitForChild("ResourceNodes")
	self.NodesFolder = nodes
	-- 방어 시설 체력
	self.SlotTags = {}
	self.Slots = root:WaitForChild("Map"):WaitForChild("DefenseSlots")
	task.spawn(function()
		while true do
			self:Refresh()
			task.wait(0.25)
		end
	end)
end

function W:NodeTag(hit)
	local tag = self.NodeTags[hit]
	if tag then return tag end
	local kind = hit:GetAttribute("ResourceType")
	local gui = new("BillboardGui", self.Gui, {Adornee = hit, Size = UDim2.fromOffset(120, 34), StudsOffset = Vector3.new(0, hit.Size.Y / 2 + 1, 0),
		LightInfluence = 0, MaxDistance = 40, Enabled = false})
	new("TextLabel", gui, {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Font = FONT, TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Text = (ICON[kind] or "") .. " " .. (R.Labels[kind] or kind)})
	local fill = bar(gui, 21, 70, 7, Color3.fromHex("#f4d35e"))
	tag = {Gui = gui, Fill = fill}
	self.NodeTags[hit] = tag
	return tag
end

function W:Refresh()
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	local me = rootPart and rootPart.Position
	for _, model in ipairs(self.NodesFolder:GetChildren()) do
		local hit = model:IsA("Model") and model.PrimaryPart
		-- 맵의 나무가 모두 노드라서 이름표는 가까이 간 것에만 만든다
		local near = hit and me and (hit.Position - me).Magnitude < 22
		local tag = hit and (self.NodeTags[hit] or (near and hit:GetAttribute("ResourceType") and self:NodeTag(hit)))
		if tag then
			local hp, maxHP = hit:GetAttribute("CurrentHealth") or 1, hit:GetAttribute("MaxHealth") or 1
			tag.Gui.Enabled = near == true and hp > 0
			tag.Fill.Size = UDim2.fromScale(math.clamp(hp / maxHP, 0, 1), 1)
			tag.Fill.Parent.Visible = hp < maxHP
		end
	end
	for hit, tag in pairs(self.NodeTags) do
		if not hit:IsDescendantOf(workspace) then
			tag.Gui.Enabled = false
		end
	end
	for _, slotModel in ipairs(self.Slots:GetChildren()) do
		local pad = slotModel:FindFirstChild(slotModel.Name)
		if pad and pad:IsA("BasePart") then
			local hp, maxHP = pad:GetAttribute("CurrentHealth") or 0, pad:GetAttribute("MaxHealth") or 0
			local tag = self.SlotTags[pad]
			if maxHP > 0 and hp < maxHP then
				if not tag then
					local gui = new("BillboardGui", self.Gui, {Adornee = pad, Size = UDim2.fromOffset(110, 28), StudsOffset = Vector3.new(0, 9, 0),
						LightInfluence = 0, MaxDistance = 120})
					local label = new("TextLabel", gui, {Name = "Title", Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = FONT, TextSize = 13,
						TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Text = ""})
					tag = {Gui = gui, Fill = bar(gui, 16, 90, 8, Color3.fromHex("#f4a35e")), Label = label}
					self.SlotTags[pad] = tag
				end
				tag.Gui.Enabled = true
				tag.Label.Text = string.format("%s Lv%d", pad:GetAttribute("DisplayName") or "", pad:GetAttribute("Level") or 0)
				tag.Fill.Size = UDim2.fromScale(math.clamp(hp / maxHP, 0, 1), 1)
			elseif tag then
				tag.Gui.Enabled = false
			end
		end
	end
end

return W
