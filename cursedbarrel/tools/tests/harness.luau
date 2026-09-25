-- 최소 Roblox 흉내 : ReplicatedStorage/ServerScriptService 모듈을 실제 파일로 불러 서버 로직을 돌려 본다.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local process = require("@lune/process")
local SRC = process.env.CB_SRC or (process.cwd .. "/src")

local H = {}

-- Fake Instance (Parent 를 넣으면 부모 목록에 들어간다)
local FakeMT = {}
local function fakeInstance(className, name)
	local obj = { _props = { Name = name or className, ClassName = className }, _children = {}, _attrs = {} }
	return setmetatable(obj, FakeMT)
end
FakeMT.__index = function(self, key)
	local props = rawget(self, "_props")
	if props[key] ~= nil then
		return props[key]
	end
	local method = FakeMT[key]
	if method then
		return method
	end
	return rawget(self, "_children")[key]
end
FakeMT.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = props.Parent
		if old then
			rawget(old, "_children")[props.Name] = nil
		end
		props.Parent = value
		if value then
			rawget(value, "_children")[props.Name] = self
		end
	else
		props[key] = value
	end
end
function FakeMT.FindFirstChild(self, name)
	return rawget(self, "_children")[name]
end
function FakeMT.WaitForChild(self, name)
	local c = rawget(self, "_children")[name]
	if not c then
		error("WaitForChild: no " .. tostring(name) .. " under " .. tostring(self.Name))
	end
	return c
end
function FakeMT.GetChildren(self)
	local out = {}
	for _, c in pairs(rawget(self, "_children")) do
		table.insert(out, c)
	end
	return out
end
function FakeMT.IsA(self, class)
	return self.ClassName == class
end
function FakeMT.SetAttribute(self, k, v)
	rawget(self, "_attrs")[k] = v
end
function FakeMT.GetAttribute(self, k)
	return rawget(self, "_attrs")[k]
end
function FakeMT.GetFullName(self)
	return self.Name
end
function FakeMT.Destroy(self)
	self.Parent = nil
end
H.fakeInstance = fakeInstance
H.FakeMT = FakeMT

local function Signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end, Connected = true }
	end
	function s:Fire(...)
		for _, fn in ipairs(self.handlers) do
			task.spawn(fn, ...)
		end
	end
	return s
end
H.Signal = Signal

-- 서비스들
local Players = fakeInstance("Players", "Players")
Players.PlayerAdded = Signal()
Players.PlayerRemoving = Signal()
function Players.GetPlayers(self)
	local list = {}
	for _, c in pairs(rawget(self, "_children")) do
		table.insert(list, c)
	end
	return list
end
function Players.GetPlayerByUserId(self, id)
	for _, c in pairs(rawget(self, "_children")) do
		if c.UserId == id then
			return c
		end
	end
	return nil
end

local function deepcopy(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in pairs(v) do
		c[k] = deepcopy(x)
	end
	return c
end
H.deepcopy = deepcopy

local store = { data = {}, failNext = 0, failAll = false, delay = 0.05, calls = 0 }
function store:SetAsync(key, value)
	self.data[key] = value
end
function store:UpdateAsync(key, fn)
	self.calls += 1
	task.wait(self.delay)
	if self.failAll or self.failNext > 0 then
		self.failNext -= 1
		error("mock datastore failure")
	end
	local new = fn(deepcopy(self.data[key]))
	if new ~= nil then
		self.data[key] = deepcopy(new)
	end
	return new
end
H.store = store
local DataStoreService = {
	GetDataStore = function() return store end,
	GetOrderedDataStore = function() return store end,
	GetRequestBudgetForRequestType = function() return 100 end,
}
local closeHandlers = {}
local marketplace = { ProcessReceipt = nil }
local services = {
	Players = Players,
	DataStoreService = DataStoreService,
	RunService = { IsStudio = function() return false end, IsClient = function() return false end, IsServer = function() return true end },
	HttpService = { GenerateGUID = function() return "GUID" end },
	MarketplaceService = marketplace,
	AnalyticsService = { LogCustomEvent = function() end },
}
H.marketplace = marketplace
H.Players = Players
H.closeHandlers = closeHandlers

-- 파일 트리를 노드로
local roots = {}
local function build(dir, node)
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			local child = fakeInstance("Folder", name)
			child.Parent = node
			build(full, child)
		else
			local base = name:gsub("%.server%.lua$", ""):gsub("%.client%.lua$", ""):gsub("%.lua$", "")
			local child = fakeInstance("ModuleScript", base)
			rawget(child, "_props")._file = full
			child.Parent = node
		end
	end
end
for _, svc in ipairs({ "ReplicatedStorage", "ServerScriptService" }) do
	local node = fakeInstance(svc, svc)
	build(SRC .. "/" .. svc, node)
	services[svc] = node
end
local remotes = fakeInstance("Folder", "Remotes")
remotes.Parent = services.ReplicatedStorage.CursedBarrel
for _, name in ipairs({ "PresentationCue" }) do
	local r = fakeInstance("RemoteEvent", name)
	r.Parent = remotes
end
services.CollectionService = { GetTagged = function() return {} end, GetInstanceAddedSignal = function() return Signal() end, GetInstanceRemovedSignal = function() return Signal() end, AddTag = function() end, HasTag = function() return false end }
services.TweenService = { Create = function() return { Play = function() end } end }

local game = {
	JobId = "job",
	PrivateServerId = "",
	GetService = function(_, name)
		local s = services[name]
		if not s then
			error("no mock service " .. name)
		end
		return s
	end,
	BindToClose = function(_, fn)
		table.insert(closeHandlers, fn)
	end,
}
H.game = game

local RandomMT = {}
RandomMT.__index = RandomMT
function RandomMT:NextInteger(a, b)
	return math.random(a, b)
end
function RandomMT:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + math.random() * (b - a)
end
local Random = { new = function() return setmetatable({}, RandomMT) end }

local cache = {}
H.cache = cache
H.events = {}
function FakeMT.FireClient(self, player, ...)
	table.insert(H.events, { remote = self.Name, to = player, args = { ... } })
end
function FakeMT.FireAllClients(self, ...)
	table.insert(H.events, { remote = self.Name, to = "all", args = { ... } })
end
local function customTypeof(v)
	if type(v) == "table" and getmetatable(v) == FakeMT then
		return "Instance"
	end
	return typeof(v)
end
local function load(node)
	if cache[node] ~= nil then
		return cache[node]
	end
	local file = node._file
	assert(file, "not a module: " .. tostring(node.Name))
	local env
	env = setmetatable({
		script = node,
		game = game,
		workspace = { GetServerTimeNow = function() return os.clock() end, GetAttribute = function() return nil end },
		require = function(x)
			if type(x) == "table" and getmetatable(x) == FakeMT then
				return load(x)
			end
			return require(x)
		end,
		typeof = customTypeof,
		task = task,
		Random = Random,
		Instance = { new = function(class) return fakeInstance(class) end },
		Enum = roblox.Enum,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Font = roblox.Font,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		BrickColor = roblox.BrickColor,
		warn = function(...) H.warns = (H.warns or 0) + 1; if H.verbose then print("WARN", ...) end end,
		print = function(...) if H.verbose then print(...) end end,
	}, { __index = _G })
	local fn = luau.load(fs.readFile(file), { debugName = node.Name, environment = env })
	local result = fn()
	cache[node] = result
	return result
end
H.load = load
H.services = services

local nextId = 1000
function H.newPlayer(name)
	nextId += 1
	local p = fakeInstance("Player", name)
	p.UserId = nextId
	p.DisplayName = name
	p.LocaleId = "ko-kr"
	p.Kick = function(self, msg)
		rawget(self, "_props").kicked = msg
	end
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	return p
end
function H.leave(p)
	p.Parent = nil
	Players.PlayerRemoving:Fire(p)
end
function H.waitFor(cond, timeout)
	local t0 = os.clock()
	while not cond() do
		if os.clock() - t0 > (timeout or 10) then
			return false
		end
		task.wait(0.02)
	end
	return true
end
return H
