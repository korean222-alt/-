-- LocaleController  (Phase 13)
-- 영어를 쓰는 사람(설정 언어 English, 또는 Auto 인데 Roblox 계정 언어가 한국어가 아닌 사람)의 화면 글자를 영어로 바꾼다.
--
--   · 내 화면(PlayerGui)의 모든 글자, 3D 간판(SurfaceGui · BillboardGui), 누르기 안내(ProximityPrompt)
--   · 글자가 바뀔 때마다 다시 번역한다. 번역은 Shared/Locale 이 하고, 영어 문장은 LocaleData 에 있다.
--   · 한국어를 쓰는 사람에게는 아무 일도 하지 않는다.
--   · 이 스크립트가 영어를 넣으므로 Roblox 자동 번역(AutoLocalize)은 끈다. (영어를 다시 한국어 원문으로 착각해 번역하지 않게)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))

local watched = setmetatable({}, { __mode = "k" }) -- [인스턴스] = 연결들
local originals = setmetatable({}, { __mode = "k" }) -- [인스턴스] = { 속성 = 한국어 원문 }
local english = false

local TEXT_PROPS = {
	TextLabel = { "Text" },
	TextButton = { "Text" },
	TextBox = { "PlaceholderText" },
	ProximityPrompt = { "ActionText", "ObjectText" },
}

local function apply(instance, prop)
	local value = instance[prop]
	if english then
		if Locale.hasHangul(value) then
			originals[instance] = originals[instance] or {}
			originals[instance][prop] = value
			local translated = Locale.translate(value)
			if translated ~= value then
				instance[prop] = translated
			end
		end
	else
		-- 한국어로 돌아왔다 : 바꿔 둔 것을 원문으로
		local saved = originals[instance] and originals[instance][prop]
		if saved then
			originals[instance][prop] = nil
			instance[prop] = saved
		end
	end
end

local function watch(instance)
	local props = TEXT_PROPS[instance.ClassName]
	if not props or watched[instance] then
		return
	end
	local connections = {}
	watched[instance] = connections
	if instance:IsA("GuiBase2d") or instance:IsA("GuiObject") then
		pcall(function()
			instance.AutoLocalize = false
		end)
	end
	for _, prop in ipairs(props) do
		table.insert(connections, instance:GetPropertyChangedSignal(prop):Connect(function()
			if english then
				apply(instance, prop)
			end
		end))
		apply(instance, prop)
	end
end

-- 3D 간판은 SurfaceGui · BillboardGui 아래 글자만 본다 (workspace 전체의 모든 것을 보지 않는다)
local function inWorldGui(instance)
	return instance:FindFirstAncestorWhichIsA("SurfaceGui") ~= nil or instance:FindFirstAncestorWhichIsA("BillboardGui") ~= nil
end

local function consider(instance)
	if TEXT_PROPS[instance.ClassName] then
		if instance:IsA("ProximityPrompt") or not instance:IsDescendantOf(workspace) or inWorldGui(instance) then
			watch(instance)
		end
	end
end

local function refreshAll()
	for instance in pairs(watched) do
		if instance.Parent then
			for _, prop in ipairs(TEXT_PROPS[instance.ClassName]) do
				apply(instance, prop)
			end
		end
	end
end

local started = false
local function start()
	if started then
		return
	end
	started = true
	local playerGui = player:WaitForChild("PlayerGui")
	for _, root in ipairs({ playerGui, workspace }) do
		for _, instance in ipairs(root:GetDescendants()) do
			consider(instance)
		end
		root.DescendantAdded:Connect(function(instance)
			-- 글자를 채운 뒤에 붙이는 경우가 많아 한 박자 늦게 본다
			task.defer(function()
				if instance.Parent then
					consider(instance)
				end
			end)
		end)
	end
end

local function update()
	local now = Locale.language(player) == "en"
	if now == english then
		return
	end
	english = now
	if english then
		start()
	end
	refreshAll()
end

player:GetAttributeChangedSignal("Setting_language"):Connect(update)
update()
