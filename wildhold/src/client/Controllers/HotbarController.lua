-- 화면 아래 핫바 (마인크래프트처럼). 손에 든 것을 보여주고 1~9 키·마우스 휠·터치로 바꾼다.
-- 칸마다 서버가 넣어 준 Tool(ItemId 속성)이 하나씩 있다. 고르면 그 Tool 을 손에 든다 (EquipTool 은 클라이언트에서 해도 서버로 복제된다).
-- 핫바 위: 체력(❤) · 배고픔(🍖) 막대. Roblox 기본 가방/체력 표시는 끈다.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local G = require(RS.Shared.Config.GameConfig)
local I = require(RS.Shared.Config.ItemConfig)
local Inv = require(RS.Shared.Modules.Inventory)

local H = {}
local player = Players.LocalPlayer
local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamBold
local SLOT = 58
local GAP = 6
local KEYS = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine}
local ACTION = {Tool = "공격", Food = "먹기", Trap = "덫 던지기", PetFood = "간식 주기"}

local function new(className, parent, props)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end

local function hideCoreGui()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then return end
		task.wait(0.5)
	end
end

function H:Init(remotes)
	task.spawn(hideCoreGui)
	self.List, self.Slots, self.Data = {}, {}, nil
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "Hotbar", ResetOnSpawn = false, DisplayOrder = 12,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
	self.Gui = gui
	self.Scale = new("UIScale", gui, {Scale = 1})
	local function rescale()
		local size = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		self.Scale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 700), 0.62, 1.15)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	self.Bar = new("Frame", gui, {Name = "Slots", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(SLOT, SLOT), BackgroundTransparency = 1})
	new("UIListLayout", self.Bar, {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder})
	for i = 1, 9 do
		self.Slots[i] = self:MakeSlot(i)
	end

	-- 체력 / 배고픔
	local vitals = new("Frame", gui, {Name = "Vitals", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(SLOT + 14)),
		Size = UDim2.fromOffset(440, 16), BackgroundTransparency = 1})
	self.HPFill, self.HPText = self:Meter(vitals, 0, "❤", "#e0525b")
	self.FoodFill, self.FoodText = self:Meter(vitals, 1, "🍖", "#e8a04a")
	-- 고른 물건 이름 (잠깐 보였다 사라짐)
	self.Name = new("TextLabel", gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(SLOT + 36)), Size = UDim2.fromOffset(300, 22),
		BackgroundTransparency = 1, Font = TITLE, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Text = "", TextTransparency = 1})

	remotes.State.OnClientEvent:Connect(function(data)
		self.Data = data
		self:Refresh()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		for i, key in ipairs(KEYS) do
			if input.KeyCode == key then self:Select(i) end
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel or #self.List == 0 then return end
		local index = (self:HeldIndex() or 1) + (input.Position.Z > 0 and -1 or 1)
		self:Select((index - 1) % #self.List + 1)
	end)
	local function watch(character)
		character.ChildAdded:Connect(function() self:Refresh() end)
		character.ChildRemoved:Connect(function() self:Refresh() end)
		local human = character:WaitForChild("Humanoid", 10)
		if human then
			human.HealthChanged:Connect(function() self:Vitals() end)
			self:Vitals()
		end
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then task.spawn(watch, player.Character) end
end

function H:Meter(parent, column, icon, color)
	local box = new("Frame", parent, {Position = UDim2.new(column * 0.5, column == 1 and 6 or 0, 0, 0), Size = UDim2.new(0.5, -6, 1, 0),
		BackgroundColor3 = Color3.fromHex("#1c2330"), BackgroundTransparency = 0.2, BorderSizePixel = 0})
	new("UICorner", box, {CornerRadius = UDim.new(0, 8)})
	new("UIStroke", box, {Color = Color3.fromHex("#0b1018"), Thickness = 1.5, Transparency = 0.3})
	local fill = new("Frame", box, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHex(color), BorderSizePixel = 0})
	new("UICorner", fill, {CornerRadius = UDim.new(0, 8)})
	local label = new("TextLabel", box, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = BODY, TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, Text = icon, ZIndex = 2})
	return fill, label
end

function H:MakeSlot(i)
	local b = new("TextButton", self.Bar, {Name = "Slot" .. i, LayoutOrder = i, Size = UDim2.fromOffset(SLOT, SLOT), Text = "",
		BackgroundColor3 = Color3.fromHex("#16202e"), BackgroundTransparency = 0.18, BorderSizePixel = 0, AutoButtonColor = true, Visible = false})
	new("UICorner", b, {CornerRadius = UDim.new(0, 10)})
	local stroke = new("UIStroke", b, {Color = Color3.fromHex("#0b1018"), Thickness = 2, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	local icon = new("TextLabel", b, {Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 1, -16), BackgroundTransparency = 1, Font = BODY,
		TextSize = 28, Text = "", TextColor3 = Color3.new(1, 1, 1)})
	local tier = new("TextLabel", b, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, -4, 0, 13),
		BackgroundTransparency = 1, Font = BODY, TextSize = 10, Text = "", TextColor3 = Color3.fromHex("#d8e2ee"), TextStrokeTransparency = 0.5})
	local key = new("TextLabel", b, {Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Font = TITLE,
		TextSize = 12, Text = tostring(i), TextColor3 = Color3.fromHex("#9fb0c4"), TextXAlignment = Enum.TextXAlignment.Left})
	local count = new("TextLabel", b, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(30, 16),
		BackgroundTransparency = 1, Font = TITLE, TextSize = 14, Text = "", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Right})
	b.Activated:Connect(function() self:Select(i) end)
	return {Button = b, Stroke = stroke, Icon = icon, Tier = tier, Key = key, Count = count}
end

function H:Tool(id)
	for _, container in ipairs({player.Character, player:FindFirstChildOfClass("Backpack")}) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("ItemId") == id then return tool end
			end
		end
	end
	return nil
end

function H:HeldId()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("ItemId")
end

function H:HeldIndex()
	local held = self:HeldId()
	for i, id in ipairs(self.List) do
		if id == held then return i end
	end
	return nil
end

function H:Select(i)
	local id = self.List[i]
	local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not id or not human or human.Health <= 0 then return end
	if self:HeldId() == id then return end
	local tool = self:Tool(id)
	if tool then
		human:EquipTool(tool)
		self:ShowName(I.Items[id].Name)
	end
end

function H:ShowName(text)
	self.Name.Text = text
	self.Name.TextTransparency, self.Name.TextStrokeTransparency = 0, 0.3
	self.NameToken = (self.NameToken or 0) + 1
	local token = self.NameToken
	task.delay(1.6, function()
		if self.NameToken ~= token then return end
		TweenService:Create(self.Name, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	end)
end

function H:Refresh()
	local d = self.Data
	if not d then return end
	local items, bag = d.Items or {}, d.Bag or {}
	self.List = Inv.hotbar(items, bag, I)
	local held = self:HeldId()
	for i, slot in ipairs(self.Slots) do
		local id = self.List[i]
		slot.Button.Visible = id ~= nil
		if id then
			local spec = I.Items[id]
			slot.Icon.Text = spec.Icon
			slot.Tier.Text = spec.Name
			local n = Inv.count(items, bag, id, I)
			slot.Count.Text = spec.Kind == "Tool" and "" or tostring(n)
			local selected = id == held
			slot.Stroke.Color = selected and Color3.fromHex("#ffe066") or Color3.fromHex("#0b1018")
			slot.Stroke.Thickness = selected and 3 or 2
			slot.Stroke.Transparency = selected and 0 or 0.3
			slot.Button.BackgroundColor3 = selected and Color3.fromHex("#2c3b52") or Color3.fromHex("#16202e")
		end
	end
	self.Bar.Size = UDim2.fromOffset(math.max(1, #self.List) * (SLOT + GAP) - GAP, SLOT)
	-- 공격 버튼 글자: 손에 든 것에 맞게
	local spec = held and I.Items[held]
	pcall(function() CAS:SetTitle("WildholdAttack", spec and ACTION[spec.Kind] or "공격") end)
	self:Vitals()
end

function H:Vitals()
	local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if human then
		local ratio = math.clamp(human.Health / math.max(1, human.MaxHealth), 0, 1)
		self.HPFill.Size = UDim2.fromScale(ratio, 1)
		self.HPText.Text = string.format("❤ %d", math.ceil(human.Health))
	end
	local d = self.Data
	if d and d.Hunger then
		local ratio = math.clamp(d.Hunger / G.HungerMax, 0, 1)
		self.FoodFill.Size = UDim2.fromScale(ratio, 1)
		self.FoodFill.BackgroundColor3 = ratio > 0.25 and Color3.fromHex("#e8a04a") or Color3.fromHex("#ef5b5b")
		self.FoodText.Text = ratio <= 0 and "🍖 배고픔! 열매나 음식을 드세요" or string.format("🍖 %d", math.ceil(d.Hunger))
	end
end

return H
