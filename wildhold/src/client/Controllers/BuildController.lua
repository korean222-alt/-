-- 설치 미리보기 (ARK 식): 설치 도구(🔨 제작대 · 🧱 벽 · 🏹 포탑 …)를 들면 캐릭터 앞에 반투명 구조물이 보인다.
--  초록 = 놓을 수 있음, 빨강 = 안 됨 (이유가 화면 아래에 나온다). 공격 버튼 = 설치, R 키(휴대폰은 ⟳ 버튼) = 15° 돌리기.
-- 자리 검사는 서버와 같은 규칙(Modules/Placement)을 쓰고, 설치는 서버가 다시 검사한다.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local BC = require(RS.Shared.Config.BuildConfig)
local M = require(RS.Shared.Config.MapConfig)
local Placement = require(RS.Shared.Modules.Placement)
local Structures = require(RS.Shared.Visuals.Structures)
local L = require(RS.Shared.Modules.Locale)

local Build = {}
local player = Players.LocalPlayer
local OK_COLOR, BAD_COLOR = Color3.fromHex("#6cff9a"), Color3.fromHex("#ff5a5a")

local function new(className, parent, props)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end

function Build:Init(remotes)
	self.Remotes, self.Rotation, self.Blocked = remotes, 0, Placement.blocked(M)
	self.Folder = new("Folder", workspace, {Name = "BuildGhost"})
	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {Name = "BuildHint", ResetOnSpawn = false, DisplayOrder = 13})
	self.Hint = new("TextLabel", gui, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(520, 26),
		BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromHex("#0b1018"), Font = Enum.Font.GothamBold, TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1), Text = "", Visible = false})
	new("UICorner", self.Hint, {CornerRadius = UDim.new(0, 10)})
	RunService.RenderStepped:Connect(function() self:Step() end)
end

-- 들고 있는 설치 도구 → 도구 id, 구조물 종류
function Build:Held()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local kit = tool and tool:GetAttribute("ItemId")
	return kit, kit and BC.Kits[kit]
end

function Build:SetGhost(kind)
	self.Folder:ClearAllChildren()
	self.Kind, self.Parts, self.Offsets = kind, {}, {}
	if not kind then return end
	local model = Structures.structure(self.Folder, kind, 1, CFrame.new(), BC.Footprint[kind][1])
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
			d.Transparency = d.Transparency >= 0.95 and 1 or math.max(d.Transparency, 0.45)
			table.insert(self.Parts, d)
			table.insert(self.Offsets, d.CFrame)
		elseif d:IsA("Light") or d:IsA("Fire") or d:IsA("ParticleEmitter") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	self.Highlight = new("Highlight", model, {Adornee = model, FillTransparency = 0.55, OutlineTransparency = 0.2, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop})
end

-- 캐릭터 앞 자리 (1 stud 격자, RotateStep 단위 방향)
function Build:Frame(kind)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
	flat = flat.Unit
	local depth = BC.Footprint[kind][2]
	local pos = root.Position + flat * (BC.Ahead + depth / 2)
	local yaw = math.deg(math.atan2(-flat.X, -flat.Z)) + self.Rotation
	yaw = math.floor(yaw / BC.RotateStep + 0.5) * BC.RotateStep
	return CFrame.new(math.floor(pos.X + 0.5), 0, math.floor(pos.Z + 0.5)) * CFrame.Angles(0, math.rad(yaw), 0), root.Position
end

function Build:Rects()
	local list = {}
	local root = workspace:FindFirstChild("WILDHOLD")
	local slots = root and root:FindFirstChild("Map") and root.Map:FindFirstChild("DefenseSlots")
	for _, holder in ipairs(slots and slots:GetChildren() or {}) do
		local pad = holder:FindFirstChild(holder.Name)
		local kind = pad and pad:GetAttribute("SlotType")
		if kind and BC.Footprint[kind] then
			local cf = pad.CFrame
			table.insert(list, Placement.rect(cf.X, cf.Z, cf.RightVector.X, cf.RightVector.Z, BC.Footprint[kind]))
		end
	end
	return list
end

function Build:Check(kind, frame, from)
	local rect = Placement.rect(frame.X, frame.Z, frame.RightVector.X, frame.RightVector.Z, BC.Footprint[kind])
	return Placement.check(rect, self:Rects(), self.Blocked, BC, from.X, from.Z)
end

function Build:BindRotate(on)
	if on == self.Bound then return end
	self.Bound = on
	if on then
		CAS:BindAction("WildholdRotate", function(_, state)
			if state == Enum.UserInputState.Begin then self.Rotation = (self.Rotation + BC.RotateStep) % 360 end
			return Enum.ContextActionResult.Sink
		end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonL1)
		CAS:SetTitle("WildholdRotate", "⟳")
		CAS:SetPosition("WildholdRotate", UDim2.new(1, -240, 1, -120))
	else
		CAS:UnbindAction("WildholdRotate")
	end
end

function Build:Step()
	local kit, kind = self:Held()
	if (player:GetAttribute("Place") or "Expedition") ~= "Expedition" then kind = nil end
	if kind ~= self.Kind then
		self:SetGhost(kind)
		self:BindRotate(kind ~= nil)
	end
	self.Hint.Visible = kind ~= nil
	if not kind then return end
	local frame, from = self:Frame(kind)
	if not frame then return end
	local frames = {}
	for i, offset in ipairs(self.Offsets) do frames[i] = frame * offset end
	workspace:BulkMoveTo(self.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	local ok, reason = self:Check(kind, frame, from)
	self.Frame0, self.Valid, self.Kit = frame, ok, kit
	if self.Highlight then
		self.Highlight.FillColor = ok and OK_COLOR or BAD_COLOR
		self.Highlight.OutlineColor = ok and OK_COLOR or BAD_COLOR
	end
	self.Hint.Text = ok and L.t("build.hint", {name = L.t("defense." .. kind)}) or ("🚫 " .. L.text(reason))
	self.Hint.TextColor3 = ok and Color3.new(1, 1, 1) or Color3.fromHex("#ffb3b3")
end

-- 공격 버튼을 눌렀을 때 (CombatController): 설치 도구를 들고 있으면 설치하고 true
function Build:TryPlace()
	local kit, kind = self:Held()
	if not kind then return false end
	self:Step()
	if self.Valid and self.Frame0 then
		self.Remotes.BuildRequest:FireServer(kit, self.Frame0)
	end
	return true
end

return Build
