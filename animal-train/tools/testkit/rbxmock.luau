-- Roblox API 흉내내기 (Studio 없이 서버 로직을 실제로 돌려 보기 위한 테스트용)
-- 게임 코드에는 들어가지 않습니다. tools/run_tests.sh 로만 씁니다.

math.randomseed(20240521) -- 검사 결과가 매번 같게 나오도록

-- 모듈에 넘겨 줄 환경 테이블 (Luau CLI 는 전역을 고칠 수 없으므로)
local ENV = {}
local Mock = {}

--=========================================================
-- 시간과 스케줄러
--=========================================================
local VirtualClock = 0
local threads = {} -- { thread, wakeAt }

local realOs = os
local osMock = setmetatable({
	clock = function()
		return VirtualClock
	end,
	time = function()
		return math.floor(VirtualClock)
	end,
}, { __index = realOs })
ENV.os = osMock

local function schedule(thread, wakeAt)
	table.insert(threads, { thread = thread, wakeAt = wakeAt })
end

local Task = {}
Task.spawn = function(fn, ...)
	local thread
	if type(fn) == "thread" then
		thread = fn
	else
		thread = coroutine.create(fn)
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		error("task.spawn 안에서 오류: " .. tostring(err), 0)
	end
	if coroutine.status(thread) == "suspended" then
		-- yield 한 스레드는 스케줄러가 깨웁니다 (wait 이 wakeAt 을 남겨 둠)
	end
	return thread
end
Task.defer = Task.spawn
Task.delay = function(seconds, fn, ...)
	local args = table.pack(...)
	local thread = coroutine.create(function()
		fn(table.unpack(args, 1, args.n))
	end)
	schedule(thread, VirtualClock + (seconds or 0))
	return thread
end
Task.wait = function(seconds)
	local current = coroutine.running()
	schedule(current, VirtualClock + (seconds or 0))
	return coroutine.yield()
end
Task.cancel = function() end
ENV.task = Task
ENV.wait = Task.wait

-- 이번 차례에 깨울 스레드만 한 번 돌립니다.
-- (이 안에서 새로 예약된 스레드는 다음 차례에 깨웁니다)
local function runDueThreads()
	local pending = threads
	threads = {}
	for _, entry in ipairs(pending) do
		if entry.wakeAt <= VirtualClock then
			if coroutine.status(entry.thread) == "suspended" then
				local ok, err = coroutine.resume(entry.thread)
				if not ok then
					error("대기 중이던 작업에서 오류: " .. tostring(err), 0)
				end
			end
		else
			table.insert(threads, entry)
		end
	end
end

--=========================================================
-- 신호 (Event)
--=========================================================
local Signal = {}
Signal.__index = Signal
function Signal.new(name)
	return setmetatable({ _handlers = {}, _name = name }, Signal)
end
function Signal:Connect(fn)
	table.insert(self._handlers, fn)
	local index = #self._handlers
	return {
		Connected = true,
		Disconnect = function(this)
			self._handlers[index] = nil
		end,
	}
end
Signal.Once = Signal.Connect
-- 로블록스처럼 각 처리기를 따로 실행합니다 (안에서 task.wait 을 써도 되도록)
function Signal:Fire(...)
	local args = table.pack(...)
	for _, fn in pairs(self._handlers) do
		local thread = coroutine.create(fn)
		local ok, err = coroutine.resume(thread, table.unpack(args, 1, args.n))
		if not ok then
			error("이벤트 처리 중 오류(" .. tostring(self._name) .. "): " .. tostring(err), 0)
		end
	end
end
function Signal:Wait()
	error("테스트에서는 Signal:Wait 을 쓰지 않습니다", 0)
end

--=========================================================
-- 숫자 타입들
--=========================================================
local Vector3MT = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3MT)
end
Vector3MT.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local magnitude = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if magnitude == 0 then
			return v3(0, 0, 0)
		end
		return v3(self.X / magnitude, self.Y / magnitude, self.Z / magnitude)
	elseif key == "Lerp" then
		return function(this, other, alpha)
			return v3(
				this.X + (other.X - this.X) * alpha,
				this.Y + (other.Y - this.Y) * alpha,
				this.Z + (other.Z - this.Z) * alpha
			)
		end
	elseif key == "Dot" then
		return function(this, other)
			return this.X * other.X + this.Y * other.Y + this.Z * other.Z
		end
	elseif key == "Cross" then
		return function(this, other)
			return v3(
				this.Y * other.Z - this.Z * other.Y,
				this.Z * other.X - this.X * other.Z,
				this.X * other.Y - this.Y * other.X
			)
		end
	end
	return nil
end
Vector3MT.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3MT.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3MT.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3MT.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3MT.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
Vector3MT.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3MT.__tostring = function(a)
	return string.format("%.2f, %.2f, %.2f", a.X, a.Y, a.Z)
end
Vector3MT.__type = "Vector3"
local Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), yAxis = v3(0, 1, 0) }

local Vector2MT = { __type = "Vector2" }
Vector2MT.__index = Vector2MT
local Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, Vector2MT)
	end,
}

local Color3MT = { __type = "Color3" }
Color3MT.__index = Color3MT
local function color3(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3MT)
end
local Color3 = {
	new = color3,
	fromRGB = function(r, g, b)
		return color3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
	fromHSV = function(h, s, v)
		return color3(v, v, v)
	end,
	fromHex = function()
		return color3(1, 1, 1)
	end,
}

--=========================================================
-- CFrame (회전 행렬을 실제로 계산합니다)
--=========================================================
local CFrameMT = {}
CFrameMT.__type = "CFrame"

-- 로블록스는 파트에 CFrame 을 넣을 때 회전을 정규화해 줍니다.
-- 테스트에서도 같게 맞춰야 오랫동안 돌렸을 때 값이 망가지지 않습니다.
local function cframe(position, right, up, back)
	local rz = back or v3(0, 0, 1)
	local rx = right or v3(1, 0, 0)
	if rz.Magnitude < 1e-9 then
		rz = v3(0, 0, 1)
	end
	rz = rz.Unit
	local dot = rx.X * rz.X + rx.Y * rz.Y + rx.Z * rz.Z
	rx = rx - rz * dot
	if rx.Magnitude < 1e-9 then
		rx = v3(rz.Y, rz.Z, rz.X)
		local dot2 = rx.X * rz.X + rx.Y * rz.Y + rx.Z * rz.Z
		rx = (rx - rz * dot2)
	end
	rx = rx.Unit
	local ry = rz:Cross(rx)
	return setmetatable({
		p = position or v3(0, 0, 0),
		rx = rx,
		ry = ry,
		rz = rz,
	}, CFrameMT)
end
local function rotateVector(cf, vector)
	return cf.rx * vector.X + cf.ry * vector.Y + cf.rz * vector.Z
end
CFrameMT.__index = function(self, key)
	if key == "Position" then
		return self.p
	elseif key == "LookVector" then
		return -self.rz
	elseif key == "RightVector" then
		return self.rx
	elseif key == "UpVector" then
		return self.ry
	elseif key == "X" then
		return self.p.X
	elseif key == "Y" then
		return self.p.Y
	elseif key == "Z" then
		return self.p.Z
	elseif key == "Inverse" then
		return function(this)
			local right = v3(this.rx.X, this.ry.X, this.rz.X)
			local up = v3(this.rx.Y, this.ry.Y, this.rz.Y)
			local back = v3(this.rx.Z, this.ry.Z, this.rz.Z)
			local inverse = cframe(v3(0, 0, 0), right, up, back)
			return cframe(-rotateVector(inverse, this.p), right, up, back)
		end
	elseif key == "ToWorldSpace" then
		return function(this, other)
			return this * other
		end
	end
	return nil
end
CFrameMT.__mul = function(a, b)
	if getmetatable(b) == Vector3MT then
		return a.p + rotateVector(a, b)
	end
	return cframe(
		a.p + rotateVector(a, b.p),
		rotateVector(a, b.rx),
		rotateVector(a, b.ry),
		rotateVector(a, b.rz)
	)
end
CFrameMT.__sub = function(a, b)
	return cframe(a.p - b, a.rx, a.ry, a.rz)
end
CFrameMT.__add = function(a, b)
	return cframe(a.p + b, a.rx, a.ry, a.rz)
end
CFrameMT.__tostring = function(a)
	return "CFrame(" .. tostring(a.p) .. ")"
end

local function anglesXYZ(x, y, z)
	local cosX, sinX = math.cos(x), math.sin(x)
	local cosY, sinY = math.cos(y), math.sin(y)
	local cosZ, sinZ = math.cos(z), math.sin(z)
	local rotX = cframe(v3(), v3(1, 0, 0), v3(0, cosX, sinX), v3(0, -sinX, cosX))
	local rotY = cframe(v3(), v3(cosY, 0, -sinY), v3(0, 1, 0), v3(sinY, 0, cosY))
	local rotZ = cframe(v3(), v3(cosZ, sinZ, 0), v3(-sinZ, cosZ, 0), v3(0, 0, 1))
	return rotX * rotY * rotZ
end

local CFrame = {
	new = function(a, b, c)
		if type(a) == "number" then
			return cframe(v3(a, b or 0, c or 0))
		end
		return cframe(a or v3(0, 0, 0))
	end,
	identity = cframe(v3(0, 0, 0)),
	lookAt = function(from, to, up)
		up = up or v3(0, 1, 0)
		local back = (from - to)
		if back.Magnitude < 1e-6 then
			back = v3(0, 0, 1)
		end
		back = back.Unit
		local right = up:Cross(back)
		if right.Magnitude < 1e-6 then
			right = v3(1, 0, 0)
		end
		right = right.Unit
		local realUp = back:Cross(right)
		return cframe(from, right, realUp, back)
	end,
	Angles = anglesXYZ,
	fromEulerAnglesXYZ = anglesXYZ,
	fromAxisAngle = function()
		return cframe(v3(0, 0, 0))
	end,
}

--=========================================================
-- UI 값 타입 (실제 계산은 하지 않음)
--=========================================================
local function passthrough(typeName)
	local mt = { __type = typeName }
	mt.__index = mt
	return function(...)
		return setmetatable({ args = { ... } }, mt)
	end
end
local udimNew = function(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, { __type = "UDim" })
end
local UDim = { new = udimNew }
local function udim2(sx, ox, sy, oy)
	return setmetatable({
		X = udimNew(sx, ox),
		Y = udimNew(sy, oy),
	}, { __type = "UDim2" })
end
local UDim2 = {
	new = udim2,
	fromScale = function(x, y)
		return udim2(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return udim2(0, x, 0, y)
	end,
}
local NumberRange = { new = passthrough("NumberRange") }
local NumberSequenceKeypoint = { new = passthrough("NumberSequenceKeypoint") }
local NumberSequence = { new = passthrough("NumberSequence") }
local ColorSequenceKeypoint = { new = passthrough("ColorSequenceKeypoint") }
local ColorSequence = { new = passthrough("ColorSequence") }
local TweenInfo = { new = passthrough("TweenInfo") }
local Rect = { new = passthrough("Rect") }

local RandomMT = {}
RandomMT.__index = RandomMT
function RandomMT:_next()
	self.state = (self.state * 1103515245 + 12345) % 2147483648
	return self.state / 2147483648
end
function RandomMT:NextNumber(min, max)
	if min == nil then
		return self:_next()
	end
	return min + self:_next() * (max - min)
end
function RandomMT:NextInteger(min, max)
	return math.floor(min + self:_next() * (max - min + 1 - 1e-9))
end
local Random = {
	new = function(seed)
		return setmetatable({ state = math.floor(math.abs(seed or 1)) % 2147483648 }, RandomMT)
	end,
}

--=========================================================
-- Enum (어떤 값이든 받아 줍니다)
--=========================================================
local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumType)
		local existing = enumCache[enumType]
		if existing then
			return existing
		end
		local made = setmetatable({}, {
			__index = function(_, itemName)
				return setmetatable({ Name = itemName, EnumType = enumType, Value = 0 }, {
					__type = "EnumItem",
					__tostring = function()
						return "Enum." .. enumType .. "." .. itemName
					end,
				})
			end,
		})
		enumCache[enumType] = made
		return made
	end,
})

local typeofMock = function(value)
	local mt = getmetatable(value)
	if mt and mt.__type then
		return mt.__type
	end
	if type(value) == "table" and value._class then
		return "Instance"
	end
	return type(value)
end

--=========================================================
-- Instance
--=========================================================
local classParents = {
	Part = "BasePart",
	WedgePart = "BasePart",
	MeshPart = "BasePart",
	TrussPart = "BasePart",
	SpawnLocation = "BasePart",
	BasePart = "PVInstance",
	Model = "PVInstance",
	PVInstance = "Instance",
	Folder = "Instance",
	Frame = "GuiObject",
	TextLabel = "GuiObject",
	TextButton = "GuiObject",
	ImageLabel = "GuiObject",
	ViewportFrame = "GuiObject",
	GuiObject = "GuiBase2d",
	ScreenGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	GuiBase2d = "Instance",
	Humanoid = "Instance",
	Camera = "Instance",
	Sound = "Instance",
	SoundGroup = "Instance",
	ParticleEmitter = "Instance",
	PointLight = "Instance",
	Atmosphere = "Instance",
	IntValue = "ValueBase",
	StringValue = "ValueBase",
	BoolValue = "ValueBase",
	ValueBase = "Instance",
	RemoteEvent = "Instance",
	ModuleScript = "LuaSourceContainer",
	Script = "BaseScript",
	LocalScript = "BaseScript",
	BaseScript = "LuaSourceContainer",
	LuaSourceContainer = "Instance",
	Player = "Instance",
	UICorner = "UIComponent",
	UIStroke = "UIComponent",
	UIListLayout = "UIComponent",
	UIAspectRatioConstraint = "UIComponent",
	UISizeConstraint = "UIComponent",
	UIScale = "UIComponent",
	UIComponent = "Instance",
	WeldConstraint = "Instance",
}

local eventNames = {
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	Touched = true,
	TouchEnded = true,
	CharacterAdded = true,
	CharacterRemoving = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Changed = true,
	Died = true,
	OnServerEvent = true,
	OnClientEvent = true,
	Heartbeat = true,
	RenderStepped = true,
	Stepped = true,
	MouseButton1Click = true,
	Activated = true,
	InputBegan = true,
	Destroying = true,
	AncestryChanged = true,
	Ended = true,
}

local partDefaults = {
	Size = function()
		return v3(4, 1, 2)
	end,
	Anchored = function()
		return false
	end,
	CanCollide = function()
		return true
	end,
	CanTouch = function()
		return true
	end,
	CanQuery = function()
		return true
	end,
	CastShadow = function()
		return true
	end,
	Transparency = function()
		return 0
	end,
	Reflectance = function()
		return 0
	end,
	CollisionGroup = function()
		return "Default"
	end,
	Color = function()
		return color3(0.6, 0.6, 0.6)
	end,
	Material = function()
		return Enum.Material.Plastic
	end,
	Shape = function()
		return Enum.PartType.Block
	end,
}

local guiDefaults = {
	Size = function()
		return udim2(0, 100, 0, 100)
	end,
	Position = function()
		return udim2(0, 0, 0, 0)
	end,
	AbsoluteSize = function()
		return Vector2.new(120, 40)
	end,
	Rotation = function()
		return 0
	end,
	Visible = function()
		return true
	end,
	BackgroundTransparency = function()
		return 0
	end,
	ZIndex = function()
		return 1
	end,
	Text = function()
		return ""
	end,
}

local InstanceMT = {}
local methods = {}

local function assertCF(label, cf)
	for _, key in ipairs({ "p", "rx", "ry", "rz" }) do
		local vector = cf[key]
		if vector.X ~= vector.X or vector.Y ~= vector.Y or vector.Z ~= vector.Z then
			error(
				"NaN CFrame: " .. label .. " (" .. key .. ")\n"
					.. "  p=" .. tostring(cf.p) .. " rx=" .. tostring(cf.rx)
					.. " ry=" .. tostring(cf.ry) .. " rz=" .. tostring(cf.rz) .. "\n"
					.. debug.traceback(),
				0
			)
		end
	end
end

local function assertFinite(label, vector)
	if vector.X ~= vector.X or vector.Y ~= vector.Y or vector.Z ~= vector.Z then
		error("NaN 발견: " .. label .. "\n" .. debug.traceback(), 0)
	end
end

local function isA(self, className)
	local current = self._class
	while current do
		if current == className then
			return true
		end
		current = classParents[current]
	end
	return className == "Instance"
end

local function newInstance(className)
	local self = {
		_class = className,
		_children = {},
		_props = {},
		_attrs = {},
		_signals = {},
		_destroyed = false,
	}
	self._props.Name = className
	self._props.Parent = nil
	if isA(self, "BasePart") then
		self._props.CFrame = cframe(v3(0, 0, 0))
	end
	if className == "Model" then
		self._props.WorldPivot = cframe(v3(0, 0, 0))
		self._props.PrimaryPart = nil
	end
	if className == "Sound" then
		self._props.IsPlaying = false
	end
	if className == "ViewportFrame" then
		self._props.CurrentCamera = nil
	end
	return setmetatable(self, InstanceMT)
end

local function fireAncestryEvents(instance, parent)
	local node = parent
	while node do
		local signal = node._signals.DescendantAdded
		if signal then
			signal:Fire(instance)
		end
		node = node._props.Parent
	end
end

InstanceMT.__index = function(self, key)
	local method = methods[key]
	if method then
		return method
	end
	if eventNames[key] then
		local existing = self._signals[key]
		if not existing then
			existing = Signal.new(self._props.Name .. "." .. key)
			self._signals[key] = existing
		end
		return existing
	end
	local value = self._props[key]
	if value ~= nil then
		return value
	end
	if key == "Position" and isA(self, "BasePart") then
		return self._props.CFrame.p
	end
	if key == "Parent" then
		return nil
	end
	if isA(self, "BasePart") and partDefaults[key] then
		return partDefaults[key]()
	end
	if (isA(self, "GuiObject") or isA(self, "LayerCollector")) and guiDefaults[key] then
		return guiDefaults[key]()
	end
	-- 이름이 같은 자식 찾기 (로블록스와 같은 동작)
	for _, child in ipairs(self._children) do
		if child._props.Name == key then
			return child
		end
	end
	return nil
end

InstanceMT.__newindex = function(self, key, value)
	if key == "CFrame" and typeofMock(value) == "CFrame" then
		assertFinite(tostring(self._props.Name) .. ".CFrame", value.p)
		assertFinite(tostring(self._props.Name) .. ".CFrame.look", value.rz)
	end
	if key == "Parent" then
		local old = self._props.Parent
		if old then
			for index, child in ipairs(old._children) do
				if child == self then
					table.remove(old._children, index)
					break
				end
			end
		end
		self._props.Parent = value
		if value then
			if value._destroyed then
				error("지워진 인스턴스에 Parent 를 붙이려 했습니다: " .. tostring(self._props.Name), 0)
			end
			table.insert(value._children, self)
			local added = value._signals.ChildAdded
			if added then
				added:Fire(self)
			end
			fireAncestryEvents(self, value)
		end
		return
	end
	if key == "Position" and isA(self, "BasePart") then
		self._props.CFrame = cframe(value)
		return
	end
	self._props[key] = value
end

InstanceMT.__tostring = function(self)
	return self._props.Name .. " <" .. self._class .. ">"
end
InstanceMT.__type = "Instance"

function methods.IsA(self, className)
	return isA(self, className)
end

function methods.GetChildren(self)
	local copy = {}
	for index, child in ipairs(self._children) do
		copy[index] = child
	end
	return copy
end

function methods.FindFirstChild(self, name, recursive)
	for _, child in ipairs(self._children) do
		if child._props.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(self._children) do
			local found = methods.FindFirstChild(child, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function methods.FindFirstChildOfClass(self, className)
	for _, child in ipairs(self._children) do
		if child._class == className then
			return child
		end
	end
	return nil
end

function methods.FindFirstChildWhichIsA(self, className)
	for _, child in ipairs(self._children) do
		if isA(child, className) then
			return child
		end
	end
	return nil
end

function methods.FindFirstAncestorOfClass(self, className)
	local node = self._props.Parent
	while node do
		if node._class == className then
			return node
		end
		node = node._props.Parent
	end
	return nil
end

function methods.WaitForChild(self, name, timeout)
	local found = methods.FindFirstChild(self, name)
	if found then
		return found
	end
	-- 테스트에서는 트리를 미리 만들어 두므로 기다리지 않고 nil 을 돌려 줍니다
	return nil
end

function methods.GetDescendants(self)
	local result = {}
	local function walk(node)
		for _, child in ipairs(node._children) do
			table.insert(result, child)
			walk(child)
		end
	end
	walk(self)
	return result
end

function methods.Destroy(self)
	local parent = self._props.Parent
	if parent then
		for index, child in ipairs(parent._children) do
			if child == self then
				table.remove(parent._children, index)
				break
			end
		end
	end
	self._props.Parent = nil
	self._destroyed = true
	for _, child in ipairs(methods.GetChildren(self)) do
		methods.Destroy(child)
	end
	self._children = {}
end
methods.ClearAllChildren = function(self)
	for _, child in ipairs(methods.GetChildren(self)) do
		methods.Destroy(child)
	end
end

function methods.Clone(self)
	local copy = newInstance(self._class)
	for key, value in pairs(self._props) do
		if key ~= "Parent" then
			copy._props[key] = value
		end
	end
	for key, value in pairs(self._attrs) do
		copy._attrs[key] = value
	end
	for _, child in ipairs(self._children) do
		local childCopy = methods.Clone(child)
		childCopy.Parent = copy
	end
	return copy
end

function methods.SetAttribute(self, name, value)
	self._attrs[name] = value
end
function methods.GetAttribute(self, name)
	return self._attrs[name]
end
function methods.GetAttributes(self)
	return self._attrs
end
function methods.GetPropertyChangedSignal(self, propertyName)
	local key = "__changed_" .. propertyName
	local existing = self._signals[key]
	if not existing then
		existing = Signal.new(propertyName)
		self._signals[key] = existing
	end
	return existing
end

-- Model
function methods.PivotTo(self, targetCFrame)
	assertCF("PivotTo 목표(" .. tostring(self._props.Name) .. ")", targetCFrame)
	local pivot = self._props.WorldPivot or cframe(v3(0, 0, 0))
	if self._props.PrimaryPart then
		pivot = self._props.PrimaryPart._props.CFrame
	end
	assertCF("PivotTo 기준점(" .. tostring(self._props.Name) .. ")", pivot)
	local delta = targetCFrame * pivot:Inverse()
	assertCF("PivotTo delta(" .. tostring(self._props.Name) .. ")", delta)
	for _, part in ipairs(methods.GetDescendants(self)) do
		if isA(part, "BasePart") then
			local result = delta * part._props.CFrame
			assertFinite("PivotTo 결과(" .. tostring(part._props.Name) .. ")", result.p)
			part._props.CFrame = result
		end
	end
	self._props.WorldPivot = targetCFrame
	self._pivotCalls = (self._pivotCalls or 0) + 1
end

function methods.GetPivot(self)
	if self._props.PrimaryPart then
		return self._props.PrimaryPart._props.CFrame
	end
	return self._props.WorldPivot
end

function methods.GetBoundingBox(self)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	local found = false
	for _, part in ipairs(methods.GetDescendants(self)) do
		if isA(part, "BasePart") then
			found = true
			local position = part._props.CFrame.p
			local size = part.Size
			minX = math.min(minX, position.X - size.X / 2)
			minY = math.min(minY, position.Y - size.Y / 2)
			minZ = math.min(minZ, position.Z - size.Z / 2)
			maxX = math.max(maxX, position.X + size.X / 2)
			maxY = math.max(maxY, position.Y + size.Y / 2)
			maxZ = math.max(maxZ, position.Z + size.Z / 2)
		end
	end
	if not found then
		return cframe(v3(0, 0, 0)), v3(0, 0, 0)
	end
	local center = v3((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
	return cframe(center), v3(maxX - minX, maxY - minY, maxZ - minZ)
end

function methods.GetExtentsSize(self)
	local _, size = methods.GetBoundingBox(self)
	return size
end

function methods.ScaleTo(self, scale)
	self._props.Scale = scale
end

-- ParticleEmitter / Sound / Humanoid
function methods.Emit(self, count)
	self._emitted = (self._emitted or 0) + (count or 1)
end
function methods.Play(self)
	self._props.IsPlaying = true
end
function methods.Stop(self)
	self._props.IsPlaying = false
end
function methods.Pause(self) end
function methods.Resume(self) end
function methods.ChangeState(self) end
function methods.MoveTo(self) end
function methods.LoadCharacter(self) end
function methods.TakeDamage(self) end

-- RemoteEvent
function methods.FireClient(self, player, ...)
	self._fired = (self._fired or 0) + 1
	local signal = self._signals.OnClientEvent
	if signal then
		signal:Fire(...)
	end
end
function methods.FireAllClients(self, ...)
	self._fired = (self._fired or 0) + 1
	local signal = self._signals.OnClientEvent
	if signal then
		signal:Fire(...)
	end
end
function methods.FireServer(self, ...)
	local signal = self._signals.OnServerEvent
	if signal then
		signal:Fire(Mock.player, ...)
	end
end

local Instance = {
	new = function(className, parent)
		local made = newInstance(className)
		if parent then
			made.Parent = parent
		end
		return made
	end,
}

ENV.Vector3 = Vector3
ENV.Vector2 = Vector2
ENV.Color3 = Color3
ENV.CFrame = CFrame
ENV.UDim = UDim
ENV.UDim2 = UDim2
ENV.NumberRange = NumberRange
ENV.NumberSequenceKeypoint = NumberSequenceKeypoint
ENV.NumberSequence = NumberSequence
ENV.ColorSequenceKeypoint = ColorSequenceKeypoint
ENV.ColorSequence = ColorSequence
ENV.TweenInfo = TweenInfo
ENV.Rect = Rect
ENV.Random = Random
ENV.Enum = Enum
ENV.Instance = Instance
ENV.typeof = typeofMock

--=========================================================
-- 서비스
--=========================================================
local services = {}
local function service(className, name)
	local made = newInstance(className)
	made._props.Name = name or className
	services[name or className] = made
	return made
end

local Workspace = service("Workspace", "Workspace")
local ReplicatedStorage = service("ReplicatedStorage", "ReplicatedStorage")
local ServerScriptService = service("ServerScriptService", "ServerScriptService")
local ServerStorage = service("ServerStorage", "ServerStorage")
local Lighting = service("Lighting", "Lighting")
local SoundService = service("SoundService", "SoundService")
local StarterGui = service("StarterGui", "StarterGui")
local StarterPlayer = service("StarterPlayer", "StarterPlayer")
local PlayersService = service("Players", "Players")
local RunService = service("RunService", "RunService")
local TweenService = service("TweenService", "TweenService")
local PhysicsService = service("PhysicsService", "PhysicsService")
local DataStoreService = service("DataStoreService", "DataStoreService")
local UserInputService = service("UserInputService", "UserInputService")

PlayersService._props.CharacterAutoLoads = true
PlayersService._props.RespawnTime = 5
local playerList = {}
methods.GetPlayers = function(self)
	if self._class == "Players" then
		local copy = {}
		for index, player in ipairs(playerList) do
			copy[index] = player
		end
		return copy
	end
	return {}
end
methods.GetPlayerFromCharacter = function(self, character)
	for _, player in ipairs(playerList) do
		if player._props.Character == character then
			return player
		end
	end
	return nil
end

RunService._props.IsStudio = nil
methods.IsStudio = function()
	return true
end
methods.IsServer = function()
	return Mock.isServer
end
methods.IsClient = function()
	return not Mock.isServer
end
methods.IsRunning = function()
	return true
end

-- TweenService : 바로 목표값을 넣어 줍니다
methods.Create = function(self, instance, info, properties)
	return {
		Play = function()
			for key, value in pairs(properties) do
				instance[key] = value
			end
		end,
		Cancel = function() end,
		Completed = Signal.new("Completed"),
	}
end

-- PhysicsService
local collisionGroups = { Default = true }
methods.RegisterCollisionGroup = function(self, name)
	collisionGroups[name] = true
end
methods.CreateCollisionGroup = methods.RegisterCollisionGroup
methods.CollisionGroupSetCollidable = function(self, a, b, value)
	if not collisionGroups[a] or not collisionGroups[b] then
		error("등록하지 않은 충돌 그룹: " .. tostring(a) .. ", " .. tostring(b), 0)
	end
end

-- DataStore (메모리에만 저장)
local storeData = {}
methods.GetDataStore = function(self, name)
	local store = newInstance("GlobalDataStore")
	store._props.Name = name
	storeData[name] = storeData[name] or {}
	store._props.__bucket = storeData[name]
	return store
end
methods.GetAsync = function(self, key)
	return self._props.__bucket[key]
end
methods.SetAsync = function(self, key, value)
	self._props.__bucket[key] = value
end
methods.UpdateAsync = function(self, key, transform)
	local updated = transform(self._props.__bucket[key])
	self._props.__bucket[key] = updated
	return updated
end
methods.RemoveAsync = function(self, key)
	self._props.__bucket[key] = nil
end

local game = newInstance("DataModel")
game._props.Name = "Game"
methods.GetService = function(self, name)
	local found = services[name]
	if not found then
		error("테스트에 없는 서비스: " .. tostring(name), 0)
	end
	return found
end
methods.BindToClose = function(self, fn)
	Mock.bindToClose = fn
end
methods.IsLoaded = function()
	return true
end

ENV.game = game
ENV.workspace = Workspace
ENV.Workspace = Workspace
for name, instance in pairs(services) do
	instance._props.Parent = game
	table.insert(game._children, instance)
end

--=========================================================
-- 테스트에서 쓰는 도구
--=========================================================
Mock.isServer = true
Mock.services = services
Mock.Signal = Signal
Mock.newInstance = newInstance
Mock.playerList = playerList

Mock.step = function(dt)
	VirtualClock += dt
	runDueThreads()
	RunService.Heartbeat:Fire(dt)
	runDueThreads()
	RunService.RenderStepped:Fire(dt)
	runDueThreads()
end

Mock.advance = function(seconds, dt)
	dt = dt or 1 / 30
	local steps = math.max(1, math.floor(seconds / dt))
	for _ = 1, steps do
		Mock.step(dt)
	end
end

Mock.now = function()
	return VirtualClock
end

Mock.addPlayer = function(name, userId)
	local player = newInstance("Player")
	player._props.Name = name
	player._props.UserId = userId
	player.Parent = PlayersService
	table.insert(playerList, player)
	Mock.player = player
	PlayersService.PlayerAdded:Fire(player)
	return player
end

Mock.spawnCharacter = function(player, position)
	local character = newInstance("Model")
	character._props.Name = player._props.Name
	local root = newInstance("Part")
	root._props.Name = "HumanoidRootPart"
	root._props.Size = v3(2, 2, 1)
	root._props.CFrame = cframe(position)
	root.Parent = character
	local head = newInstance("Part")
	head._props.Name = "Head"
	head._props.CFrame = cframe(position + v3(0, 1.5, 0))
	head.Parent = character
	local humanoid = newInstance("Humanoid")
	humanoid._props.Name = "Humanoid"
	humanoid._props.WalkSpeed = 16
	humanoid.Parent = character
	character._props.PrimaryPart = root
	character.Parent = Workspace
	player._props.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

Mock.moveCharacter = function(player, position)
	local character = player._props.Character
	local root = character and methods.FindFirstChild(character, "HumanoidRootPart")
	if root then
		root._props.CFrame = cframe(position)
		local head = methods.FindFirstChild(character, "Head")
		if head then
			head._props.CFrame = cframe(position + v3(0, 1.5, 0))
		end
	end
end

ENV.RbxMock = Mock
ENV.warn = function(...)
	print("[warn]", ...)
end
setmetatable(ENV, { __index = _G })
Mock.ENV = ENV
