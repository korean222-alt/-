-- 12단계 : 배경 음악과 스피커(끄기) 버튼.
-- Config.Music.AssetId 가 비어 있으면 버튼을 만들지 않습니다.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local Music = {}

local sound
local button
local slash
local enabled = true
local ready = false

local function setEnabled(value)
	enabled = value
	if sound then
		sound.Volume = value and Config.Music.Volume or 0
		if value and not sound.IsPlaying then
			pcall(function()
				sound:Play()
			end)
		end
	end
	if slash then
		slash.Visible = not value
	end
end

local function buildButton(parent)
	button = UiKit.panel(parent, "MusicButton", Color3.fromRGB(255, 252, 240))
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(0.975, 0, 0.055, 0)
	button.Size = UDim2.new(0.08, 0, 0.1, 0)
	button.BackgroundTransparency = 0.05
	UiKit.aspect(button, 1)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(54, 54)
	constraint.MaxSize = Vector2.new(96, 96)
	constraint.Parent = button

	-- 스피커 몸통
	local body = UiKit.frame(button, "Body")
	body.BackgroundTransparency = 0
	body.BackgroundColor3 = Color3.fromRGB(96, 104, 132)
	body.Size = UDim2.fromScale(0.2, 0.3)
	body.Position = UDim2.fromScale(0.22, 0.35)
	UiKit.corner(body, 0.25)

	local cone = UiKit.frame(button, "Cone")
	cone.BackgroundTransparency = 0
	cone.BackgroundColor3 = Color3.fromRGB(96, 104, 132)
	cone.Size = UDim2.fromScale(0.26, 0.56)
	cone.Position = UDim2.fromScale(0.36, 0.22)
	UiKit.corner(cone, 0.3)

	-- 소리 물결 2개
	for index = 1, 2 do
		local wave = UiKit.frame(button, "Wave" .. index)
		wave.BackgroundTransparency = 0
		wave.BackgroundColor3 = Color3.fromRGB(255, 196, 96)
		wave.Size = UDim2.fromScale(0.07, 0.16 + index * 0.12)
		wave.Position = UDim2.fromScale(0.64 + (index - 1) * 0.12, 0.5 - (0.08 + index * 0.06))
		UiKit.corner(wave, 0.5)
	end

	-- 꺼졌을 때 사선
	slash = UiKit.frame(button, "Slash")
	slash.BackgroundTransparency = 0
	slash.BackgroundColor3 = Color3.fromRGB(255, 110, 110)
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.fromScale(0.5, 0.5)
	slash.Size = UDim2.fromScale(0.95, 0.12)
	slash.Rotation = -35
	slash.Visible = false
	UiKit.corner(slash, 0.5)

	local hit = UiKit.hitButton(button)
	hit.MouseButton1Click:Connect(function()
		setEnabled(not enabled)
		UiKit.pop(button, 0.2)
		Net.event(Config.Remotes.SetPref):FireServer("music", enabled)
	end)
end

function Music.init(parent)
	if Config.Music.AssetId == "" then
		print("[음악] Config.Music.AssetId 가 비어 있어 음악을 켜지 않았습니다.")
		print("[음악] 로블록스에서 사용 허용된 음악 ID 를 Config 에 넣으면 스피커 버튼이 생깁니다.")
		return
	end

	sound = Instance.new("Sound")
	sound.Name = "BackgroundMusic"
	sound.SoundId = Config.Music.AssetId
	sound.Looped = true
	sound.Volume = Config.Music.Volume
	sound.Parent = SoundService
	pcall(function()
		sound:Play()
	end)

	buildButton(parent)
	ready = true
end

function Music.update(state)
	if not ready or not state then
		return
	end
	local want = state.music ~= false
	if want ~= enabled then
		setEnabled(want)
	end
end

return Music
