-- Roblox 엔진 모의 구현. 하나의 Luau VM 안에서 서버와 클라이언트 스크립트를 함께 돌린다.
-- 속성 이름/읽기전용/자료형/Enum 은 api.lua (실제 Roblox API 목록)로 검사해서, 잘못 쓰면 즉시 오류를 낸다.
local API, D = ...

local R = {Errors = {}, Warnings = {}, Log = {}, Now = 0, Threads = {}, Kicks = {}}

-- ===================================================================== typeof
local builtinTypeof = typeof
local function rtypeof(v)
	local mt = type(v) == "table" and getmetatable(v)
	if mt and rawget(mt, "__type") then return mt.__type end
	return builtinTypeof(v)
end
R.typeof = rtypeof

-- ===================================================================== 스케줄러 (가상 시간)
local queue = {}
local function schedule(co, at, args)
	table.insert(queue, {co = co, at = at, args = args})
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(R.Errors, tostring(err) .. "\n" .. debug.traceback(co))
	end
end
R.resume = resume

local task = {}
function task.spawn(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.defer(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	schedule(co, R.Now, {...})
	return co
end
function task.delay(t, fn, ...)
	local co = coroutine.create(fn)
	schedule(co, R.Now + (t or 0), {...})
	return co
end
function task.wait(t)
	local co = coroutine.running()
	assert(coroutine.isyieldable(), "task.wait 는 스크립트 스레드 안에서만 부를 수 있습니다")
	schedule(co, R.Now + math.max(t or 0, 1 / 60), {})
	coroutine.yield()
	return t or 0
end
function task.cancel(co)
	for i = #queue, 1, -1 do
		if queue[i].co == co then table.remove(queue, i) end
	end
end
R.task = task

function R.runUntil(target)
	while true do
		table.sort(queue, function(a, b) return a.at < b.at end)
		local item = queue[1]
		if not item or item.at > target then break end
		table.remove(queue, 1)
		R.Now = math.max(R.Now, item.at)
		if coroutine.status(item.co) == "suspended" then
			resume(item.co, table.unpack(item.args))
		end
	end
	R.Now = target
end

-- ===================================================================== Enum
local EnumItemMeta = {__type = "EnumItem"}
EnumItemMeta.__index = function(item, k)
	if k == "Name" or k == "Value" or k == "EnumType" then return rawget(item, k) end
	error("EnumItem 에 " .. tostring(k) .. " 가 없습니다", 2)
end
EnumItemMeta.__tostring = function(item) return "Enum." .. rawget(item, "EnumName") .. "." .. rawget(item, "Name") end
local enumCache = {}
local Enum = setmetatable({}, {__index = function(_, name)
	local items = API.Enums[name]
	if not items then error("Enum." .. tostring(name) .. " 는 존재하지 않습니다", 2) end
	if not enumCache[name] then
		local e = {}
		local list = {}
		for itemName, value in pairs(items) do
			e[itemName] = setmetatable({Name = itemName, Value = value, EnumName = name}, EnumItemMeta)
			table.insert(list, e[itemName])
		end
		enumCache[name] = setmetatable({}, {__type = "Enum", __index = function(_, itemName)
			if itemName == "GetEnumItems" then return function() return list end end
			local item = e[itemName]
			if not item then error("Enum." .. name .. "." .. tostring(itemName) .. " 는 존재하지 않습니다", 2) end
			return item
		end})
	end
	return enumCache[name]
end})
R.Enum = Enum

-- ===================================================================== Signal
local SignalMeta = {__type = "RBXScriptSignal"}
SignalMeta.__index = SignalMeta
local ConnMeta = {__type = "RBXScriptConnection"}
ConnMeta.__index = ConnMeta
function ConnMeta:Disconnect() self.Connected = false end
local function Signal(name)
	return setmetatable({handlers = {}, name = name, waiting = {}}, SignalMeta)
end
function SignalMeta:Connect(fn)
	assert(type(fn) == "function", (self.name or "signal") .. ":Connect 에 함수가 아닌 값")
	local c = setmetatable({fn = fn, Connected = true}, ConnMeta)
	table.insert(self.handlers, c)
	return c
end
function SignalMeta:Once(fn)
	local c
	c = self:Connect(function(...) c:Disconnect(); fn(...) end)
	return c
end
function SignalMeta:Wait()
	local co = coroutine.running()
	table.insert(self.waiting, co)
	return coroutine.yield()
end
function SignalMeta:Fire(...)
	for _, c in ipairs(table.clone(self.handlers)) do
		if c.Connected then
			task.spawn(c.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in ipairs(waiting) do resume(co, ...) end
end
R.Signal = Signal

-- ===================================================================== 클래스 정보
local function classInfo(name) return API.Classes[name] end
local function isA(className, target)
	local c = className
	while c do
		if c == target then return true end
		local info = classInfo(c)
		c = info and info.Super
	end
	return false
end
local function findProp(className, prop)
	local c = className
	while c do
		local info = classInfo(c)
		if not info then return nil end
		if info.Props[prop] then return info.Props[prop], c end
		c = info.Super
	end
	return nil
end
local function findMethod(className, name)
	local c = className
	while c do
		local info = classInfo(c)
		if not info then return false end
		if info.Methods[name] then return true end
		c = info.Super
	end
	return false
end
R.isA = isA

-- 자료형 검사: api.lua 의 간단 표기("?number", "enum:Material", "Vector3" …)
local function checkType(spec, value, where)
	if spec == nil then return end
	local nullable = spec:sub(1, 1) == "?"
	if nullable then spec = spec:sub(2) end
	if value == nil then
		if nullable or spec:find("any") or spec:find("instance") then return end
		error(where .. " 에 nil 을 넣을 수 없습니다 (" .. spec .. ")", 4)
	end
	local vt = rtypeof(value)
	for kind in spec:gmatch("[^,]+") do
		if kind == "any" or kind == "signal" then return end
		if kind == "number" and vt == "number" then return end
		if kind == "boolean" and vt == "boolean" then return end
		if kind == "string" and vt == "string" then return end
		if kind == "Content" and vt == "string" then return end
		if kind == "instance" and vt == "Instance" then return end
		if kind:sub(1, 5) == "enum:" then
			if vt == "EnumItem" then
				if rawget(value, "EnumName") == kind:sub(6) then return end
				error(where .. " 에 다른 Enum(" .. rawget(value, "EnumName") .. ") 을 넣었습니다. 필요: " .. kind:sub(6), 4)
			end
			if vt == "number" or vt == "string" then return end
		end
		if kind == vt then return end
	end
	error(where .. " 자료형 불일치: " .. vt .. " (필요: " .. spec .. ")", 4)
end

-- ===================================================================== Instance
local InstanceMeta = {__type = "Instance"}
local allInstances = setmetatable({}, {__mode = "k"})
local DEFAULTS = {
	BasePart = {Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true, Transparency = 0, Reflectance = 0, Massless = false,
		CastShadow = true, LocalTransparencyModifier = 0},
	Part = {Size = D.Vector3.new(4, 1.2, 2)},
	MeshPart = {Size = D.Vector3.new(1, 1, 1)},
	WedgePart = {Size = D.Vector3.new(4, 1.2, 2)},
	CornerWedgePart = {Size = D.Vector3.new(2, 2, 2)},
	SpawnLocation = {Size = D.Vector3.new(12, 1, 12)},
	Humanoid = {Health = 100, MaxHealth = 100, WalkSpeed = 16},
	GuiObject = {Visible = true, BackgroundTransparency = 0, Size = D.UDim2.new(0, 100, 0, 100), Position = D.UDim2.new(0, 0, 0, 0)},
	LayerCollector = {Enabled = true},
	ProximityPrompt = {Enabled = true, MaxActivationDistance = 10},
	Light = {Enabled = true},
	ParticleEmitter = {Enabled = true},
	Camera = {ViewportSize = D.Vector2.new(1280, 720), CFrame = D.CFrame.new(0, 20, 60), FieldOfView = 70},
	Model = {},
}
local function defaultFor(className, prop, spec)
	local c = className
	while c do
		local d = DEFAULTS[c]
		if d and d[prop] ~= nil then return d[prop] end
		local info = classInfo(c)
		c = info and info.Super
	end
	if not spec then return nil end
	spec = spec:gsub("^%?", "")
	local first = spec:match("^[^,]+")
	if first == "number" then return 0
	elseif first == "boolean" then return false
	elseif first == "string" or first == "Content" then return ""
	elseif first == "Vector3" then return D.Vector3.new(0, 0, 0)
	elseif first == "Vector2" then return D.Vector2.new(0, 0)
	elseif first == "CFrame" then return D.CFrame.new()
	elseif first == "Color3" then return D.Color3.new(0.64, 0.64, 0.65)
	elseif first == "UDim2" then return D.UDim2.new(0, 0, 0, 0)
	elseif first == "UDim" then return D.UDim.new(0, 0)
	elseif first and first:sub(1, 5) == "enum:" then
		local items = API.Enums[first:sub(6)]
		if items then
			for name in pairs(items) do return Enum[first:sub(6)][name] end
		end
	end
	return nil
end

local newInstance
local SIGNALS = {"ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "Changed", "AncestryChanged", "Destroying", "AttributeChanged"}

local methods = {}

local function fireDescendantAdded(inst, added)
	local p = inst
	while p do
		p._signals.DescendantAdded:Fire(added)
		p = p._props.Parent
	end
end

local function setParent(inst, parent)
	local old = inst._props.Parent
	if old == parent then return end
	if rawget(inst, "_destroyed") then error("Destroy 된 인스턴스의 Parent 는 바꿀 수 없습니다: " .. inst._props.Name, 3) end
	if old then
		local list = old._children
		for i, child in ipairs(list) do
			if child == inst then table.remove(list, i); break end
		end
		old._signals.ChildRemoved:Fire(inst)
	end
	inst._props.Parent = parent
	if parent then
		table.insert(parent._children, inst)
		parent._signals.ChildAdded:Fire(inst)
		fireDescendantAdded(parent, inst)
		for _, d in ipairs(methods.GetDescendants(inst)) do fireDescendantAdded(parent, d) end
	end
	inst._signals.AncestryChanged:Fire(inst, parent)
end

-- BasePart 위치/회전은 CFrame 하나로 관리한다
local function partGet(inst, k)
	local cfv = inst._props.CFrame or D.CFrame.new()
	if k == "Position" then return cfv.Position end
	if k == "Orientation" or k == "Rotation" then local x, y, z = cfv:ToEulerAnglesXYZ(); return D.Vector3.new(math.deg(x), math.deg(y), math.deg(z)) end
	if k == "AssemblyLinearVelocity" then return inst._props.AssemblyLinearVelocity or D.Vector3.new() end
	return nil
end

local PASS = {}
local function specialGet(inst, k)
	local cls = inst._class
	if isA(cls, "BasePart") and (k == "Position" or k == "Orientation" or k == "Rotation") then return partGet(inst, k) end
	if isA(cls, "Attachment") then
		local parent = inst._props.Parent
		local base = D.CFrame.new()
		if parent and isA(parent._class, "BasePart") then base = parent._props.CFrame or base end
		local local_ = inst._props.CFrame or D.CFrame.new()
		if isA(cls, "Bone") then
			if k == "WorldCFrame" then return base * local_ end
			if k == "TransformedWorldCFrame" then return base * local_ * (inst._props.Transform or D.CFrame.new()) end
			if k == "WorldPosition" then return (base * local_).Position end
		end
		if k == "WorldCFrame" then return base * local_ end
		if k == "WorldPosition" then return (base * local_).Position end
		if k == "Position" then return local_.Position end
	end
	if isA(cls, "Model") and k == "WorldPivot" then return methods.GetPivot(inst) end
	return PASS
end

local function specialSet(inst, k, v)
	local cls = inst._class
	if isA(cls, "BasePart") then
		if k == "Position" then
			local c = inst._props.CFrame or D.CFrame.new()
			inst._props.CFrame = D.CFrame.new(v) * c.Rotation
			return true
		elseif k == "Orientation" or k == "Rotation" then
			local c = inst._props.CFrame or D.CFrame.new()
			inst._props.CFrame = D.CFrame.new(c.Position) * D.CFrame.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
			return true
		elseif k == "Size" then
			if inst._props.Shape and rawget(inst._props.Shape, "Name") == "Ball" then
				local m = math.min(v.X, v.Y, v.Z)
				v = D.Vector3.new(m, m, m)
			end
			inst._props.Size = D.Vector3.new(math.max(0.001, v.X), math.max(0.001, v.Y), math.max(0.001, v.Z))
			return true
		end
	end
	if isA(cls, "Attachment") then
		if k == "WorldPosition" or k == "WorldCFrame" then
			local parent = inst._props.Parent
			local base = D.CFrame.new()
			if parent and isA(parent._class, "BasePart") then base = parent._props.CFrame or base end
			local world = k == "WorldPosition" and D.CFrame.new(v) or v
			inst._props.CFrame = base:Inverse() * world
			return true
		elseif k == "Position" then
			local c = inst._props.CFrame or D.CFrame.new()
			inst._props.CFrame = D.CFrame.new(v) * c.Rotation
			return true
		end
	end
	if isA(cls, "Model") and k == "WorldPivot" then
		rawset(inst, "_pivot", v)
		return true
	end
	return false
end

InstanceMeta.__index = function(inst, k)
	if k == "Parent" then return inst._props.Parent end
	if k == "ClassName" then return inst._class end
	if k == "Name" then return inst._props.Name end
	local special = specialGet(inst, k)
	if special ~= PASS then return special end
	local spec = findProp(inst._class, k)
	if spec then
		if spec[2]:find("signal") then
			local s = inst._signals[k]
			if not s then s = Signal(inst._class .. "." .. k); inst._signals[k] = s end
			return s
		end
		local v = inst._props[k]
		if v == nil then v = defaultFor(inst._class, k, spec[2]) end
		return v
	end
	if inst._signals[k] then return inst._signals[k] end
	local custom = rawget(inst, "_custom") and rawget(inst, "_custom")[k]
	if custom ~= nil then return custom end
	local m = methods[k]
	if m and (findMethod(inst._class, k) or k == "Destroy" or k == "Clone") then return m end
	if m and methods._always[k] then return m end
	-- 자식 이름으로 찾기
	for _, child in ipairs(inst._children) do
		if child._props.Name == k then return child end
	end
	error(string.format("%s(%s) 에 '%s' 가 없습니다 (속성/메서드/자식 아님)", inst._props.Name, inst._class, tostring(k)), 2)
end

InstanceMeta.__newindex = function(inst, k, v)
	if rawget(inst, "_destroyed") and k ~= "Parent" then
		-- Roblox 는 Destroy 된 인스턴스 속성 변경을 허용한다 (의미는 없음)
	end
	if k == "Parent" then
		if v ~= nil and rtypeof(v) ~= "Instance" then error("Parent 에는 Instance 만 넣을 수 있습니다", 2) end
		if v == inst then error("자기 자신을 Parent 로 둘 수 없습니다", 2) end
		setParent(inst, v)
		return
	end
	if k == "Name" then
		assert(type(v) == "string", "Name 은 문자열")
		inst._props.Name = v
		return
	end
	local spec = findProp(inst._class, k)
	if not spec then
		error(string.format("%s 에는 '%s' 속성이 없습니다", inst._class, tostring(k)), 2)
	end
	if spec[1] then
		error(string.format("%s.%s 는 읽기 전용입니다", inst._class, k), 2)
	end
	checkType(spec[2], v, inst._class .. "." .. k)
	if specialSet(inst, k, v) then
		inst._changed[k] = (inst._changed[k] or 0) + 1
		return
	end
	local old = inst._props[k]
	inst._props[k] = v
	if old ~= v then
		local s = inst._propSignals[k]
		if s then s:Fire() end
	end
end
InstanceMeta.__tostring = function(inst) return inst._props.Name end

function newInstance(className, parent)
	local inst = setmetatable({_class = className, _props = {Name = className}, _children = {}, _signals = {}, _propSignals = {}, _attrs = {},
		_attrSignals = {}, _changed = {}}, InstanceMeta)
	for _, s in ipairs(SIGNALS) do rawget(inst, "_signals")[s] = Signal(className .. "." .. s) end
	allInstances[inst] = true
	if parent then setParent(inst, parent) end
	return inst
end
R.newInstance = newInstance

-- ===================================================================== 메서드
methods._always = {GetAttribute = true, SetAttribute = true, GetAttributes = true, GetAttributeChangedSignal = true, GetPropertyChangedSignal = true,
	FindFirstChild = true, WaitForChild = true, GetChildren = true, GetDescendants = true, IsA = true, IsDescendantOf = true,
	FindFirstChildOfClass = true, FindFirstChildWhichIsA = true, FindFirstAncestor = true, FindFirstAncestorOfClass = true,
	FindFirstAncestorWhichIsA = true, ClearAllChildren = true, GetFullName = true, IsAncestorOf = true, FindFirstDescendant = true}

function methods.GetChildren(inst) return table.clone(inst._children) end
function methods.GetDescendants(inst)
	local out = {}
	local function walk(i)
		for _, c in ipairs(i._children) do table.insert(out, c); walk(c) end
	end
	walk(inst)
	return out
end
function methods.FindFirstChild(inst, name, recursive)
	for _, c in ipairs(inst._children) do
		if c._props.Name == name then return c end
	end
	if recursive then
		for _, c in ipairs(inst._children) do
			local f = methods.FindFirstChild(c, name, true)
			if f then return f end
		end
	end
	return nil
end
methods.FindFirstDescendant = function(inst, name) return methods.FindFirstChild(inst, name, true) end
function methods.WaitForChild(inst, name, timeout)
	local found = methods.FindFirstChild(inst, name)
	if found then return found end
	-- 가상 시간으로 잠깐 기다려 본다
	local deadline = R.Now + (timeout or 5)
	while R.Now < deadline and coroutine.isyieldable() do
		task.wait(0.1)
		found = methods.FindFirstChild(inst, name)
		if found then return found end
	end
	if timeout then return nil end
	error("WaitForChild 무한 대기: " .. inst._props.Name .. "." .. name, 2)
end
function methods.FindFirstChildOfClass(inst, cls)
	for _, c in ipairs(inst._children) do if c._class == cls then return c end end
	return nil
end
function methods.FindFirstChildWhichIsA(inst, cls, recursive)
	for _, c in ipairs(recursive and methods.GetDescendants(inst) or inst._children) do if isA(c._class, cls) then return c end end
	return nil
end
function methods.FindFirstAncestor(inst, name)
	local p = inst._props.Parent
	while p do if p._props.Name == name then return p end p = p._props.Parent end
	return nil
end
function methods.FindFirstAncestorOfClass(inst, cls)
	local p = inst._props.Parent
	while p do if p._class == cls then return p end p = p._props.Parent end
	return nil
end
function methods.FindFirstAncestorWhichIsA(inst, cls)
	local p = inst._props.Parent
	while p do if isA(p._class, cls) then return p end p = p._props.Parent end
	return nil
end
function methods.IsA(inst, cls)
	if not API.Classes[cls] then error("IsA: 없는 클래스 " .. tostring(cls), 2) end
	return isA(inst._class, cls)
end
function methods.IsDescendantOf(inst, ancestor)
	local p = inst._props.Parent
	while p do if p == ancestor then return true end p = p._props.Parent end
	return false
end
function methods.IsAncestorOf(inst, d) return methods.IsDescendantOf(d, inst) end
function methods.GetFullName(inst)
	local names = {}
	local p = inst
	while p do table.insert(names, 1, p._props.Name) p = p._props.Parent end
	return table.concat(names, ".")
end
function methods.Destroy(inst)
	if rawget(inst, "_destroyed") then return end
	inst._signals.Destroying:Fire()
	for _, c in ipairs(table.clone(inst._children)) do methods.Destroy(c) end
	if inst._props.Parent then setParent(inst, nil) end
	rawset(inst, "_destroyed", true)
end
function methods.ClearAllChildren(inst)
	for _, c in ipairs(table.clone(inst._children)) do methods.Destroy(c) end
end
function methods.Clone(inst)
	local copy = newInstance(inst._class)
	for k, v in pairs(inst._props) do
		if k ~= "Parent" then copy._props[k] = v end
	end
	for k, v in pairs(inst._attrs) do copy._attrs[k] = v end
	rawset(copy, "_pivot", rawget(inst, "_pivot"))
	for _, c in ipairs(inst._children) do
		local cc = methods.Clone(c)
		setParent(cc, copy)
	end
	if inst._props.PrimaryPart then
		copy._props.PrimaryPart = nil
	end
	return copy
end
local ATTR_TYPES = {string = true, number = true, boolean = true, Vector3 = true, Color3 = true, CFrame = true, UDim2 = true, Vector2 = true, UDim = true,
	NumberRange = true, EnumItem = true}
function methods.SetAttribute(inst, name, value)
	assert(type(name) == "string", "SetAttribute 이름은 문자열")
	if value ~= nil and not ATTR_TYPES[rtypeof(value)] then
		error("SetAttribute(" .. name .. ") 에 넣을 수 없는 자료형: " .. rtypeof(value), 2)
	end
	local old = inst._attrs[name]
	inst._attrs[name] = value
	if old ~= value then
		local s = inst._attrSignals[name]
		if s then s:Fire() end
		inst._signals.AttributeChanged:Fire(name)
	end
end
function methods.GetAttribute(inst, name) return inst._attrs[name] end
function methods.GetAttributes(inst) return table.clone(inst._attrs) end
function methods.GetAttributeChangedSignal(inst, name)
	local s = inst._attrSignals[name]
	if not s then s = Signal("Attr." .. name); inst._attrSignals[name] = s end
	return s
end
function methods.GetPropertyChangedSignal(inst, name)
	if not findProp(inst._class, name) and name ~= "Parent" and name ~= "Name" then
		error("GetPropertyChangedSignal: " .. inst._class .. " 에 " .. name .. " 속성이 없습니다", 2)
	end
	local s = inst._propSignals[name]
	if not s then s = Signal("Prop." .. name); inst._propSignals[name] = s end
	return s
end

-- PVInstance / Model
local function partsOf(inst)
	local list = {}
	if isA(inst._class, "BasePart") then table.insert(list, inst) end
	for _, d in ipairs(methods.GetDescendants(inst)) do
		if isA(d._class, "BasePart") then table.insert(list, d) end
	end
	return list
end
function methods.GetPivot(inst)
	if isA(inst._class, "BasePart") then return inst._props.CFrame or D.CFrame.new() end
	if inst._props.PrimaryPart then return inst._props.PrimaryPart._props.CFrame * (rawget(inst, "_primaryOffset") or D.CFrame.new()) end
	if rawget(inst, "_pivot") then return rawget(inst, "_pivot") end
	local cfv = methods.GetBoundingBox(inst)
	return D.CFrame.new(cfv.Position)
end
function methods.PivotTo(inst, target)
	assert(rtypeof(target) == "CFrame", "PivotTo 는 CFrame 을 받습니다")
	local current = methods.GetPivot(inst)
	local delta = target * current:Inverse()
	for _, p in ipairs(partsOf(inst)) do
		p._props.CFrame = delta * (p._props.CFrame or D.CFrame.new())
	end
	if not isA(inst._class, "BasePart") then rawset(inst, "_pivot", target) end
end
function methods.GetBoundingBox(inst)
	local parts = partsOf(inst)
	if #parts == 0 then return D.CFrame.new(), D.Vector3.new() end
	local lo, hi = D.Vector3.new(math.huge, math.huge, math.huge), D.Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(parts) do
		local c, s = p._props.CFrame or D.CFrame.new(), (p._props.Size or D.Vector3.new(4, 1.2, 2)) / 2
		for _, sx in ipairs({-1, 1}) do
			for _, sy in ipairs({-1, 1}) do
				for _, sz in ipairs({-1, 1}) do
					local w = c * D.Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)
					lo, hi = lo:Min(w), hi:Max(w)
				end
			end
		end
	end
	return D.CFrame.new((lo + hi) / 2), hi - lo
end
function methods.GetExtentsSize(inst) local _, s = methods.GetBoundingBox(inst); return s end
function methods.GetScale(inst) return rawget(inst, "_scale") or 1 end
function methods.ScaleTo(inst, scale)
	local factor = scale / (rawget(inst, "_scale") or 1)
	local pivot = methods.GetPivot(inst)
	for _, p in ipairs(partsOf(inst)) do
		local rel = pivot:Inverse() * p._props.CFrame
		p._props.CFrame = pivot * (D.CFrame.new(rel.Position * factor) * rel.Rotation)
		p._props.Size = (p._props.Size or D.Vector3.new(1, 1, 1)) * factor
	end
	for _, d in ipairs(methods.GetDescendants(inst)) do
		if isA(d._class, "Attachment") and d._props.CFrame then
			d._props.CFrame = D.CFrame.new(d._props.CFrame.Position * factor) * d._props.CFrame.Rotation
		end
	end
	rawset(inst, "_scale", scale)
end

R.methods = methods
return R
