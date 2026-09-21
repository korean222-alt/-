--!nocheck
--[[
	mock_roblox
	Roblox 스튜디오 없이 서버 로직을 실행해 보기 위한 최소 흉내 구현.

	실제 게임에는 들어가지 않는다. tools/run_tests.py 가 이 파일과 src/ 의 모듈들,
	그리고 scenarios.luau 를 하나로 묶어 luau 로 실행한다.

	흉내 내는 범위
	  - Instance 트리 (Parent/자식/Attribute/속성 변경 신호)
	  - Seat / Humanoid 의 앉기·일어서기 동작
	  - Players / CollectionService / HttpService
	  - task.delay / task.defer 를 가상 시계로 돌리는 스케줄러
]]

local REG = {}          -- [proxy] = data
local playersList = {}
local warnings = {}
local logs = {}

local EVENT_NAMES = {
	AncestryChanged = true, DescendantAdded = true, DescendantRemoving = true,
	ChildAdded = true, ChildRemoved = true, Changed = true,
	Triggered = true, Died = true, Touched = true,
	CharacterAdded = true, CharacterRemoving = true,
	PlayerAdded = true, PlayerRemoving = true,
}

local BASE_PARTS = { Part = true, Seat = true, SpawnLocation = true, MeshPart = true }

--------------------------------------------------
-- 가상 시계 + 스케줄러
--------------------------------------------------
local clock = 1000
local queue = {}
local seq = 0

local function schedule(delay, fn, args)
	seq += 1
	table.insert(queue, { time = clock + delay, seq = seq, fn = fn, args = args })
end

local function runDue(target)
	while true do
		local best, bestIndex
		for index, item in ipairs(queue) do
			if item.time <= target + 1e-9 then
				if not best or item.time < best.time or (item.time == best.time and item.seq < best.seq) then
					best, bestIndex = item, index
				end
			end
		end
		if not best then
			break
		end
		table.remove(queue, bestIndex)
		if best.time > clock then
			clock = best.time
		end
		best.fn(table.unpack(best.args, 1, best.args.n))
	end
	if target > clock then
		clock = target
	end
end

--------------------------------------------------
-- 신호 (RBXScriptSignal 흉내)
--------------------------------------------------
local function newSignal()
	local signal = { _handlers = {} }

	function signal:Connect(fn)
		local connection = { Connected = true, _fn = fn, _isConnection = true }
		function connection:Disconnect()
			if not self.Connected then
				return
			end
			self.Connected = false
			local index = table.find(signal._handlers, self)
			if index then
				table.remove(signal._handlers, index)
			end
		end
		table.insert(signal._handlers, connection)
		return connection
	end

	function signal:Fire(...)
		local snapshot = table.clone(signal._handlers)
		for _, connection in ipairs(snapshot) do
			if connection.Connected then
				connection._fn(...)
			end
		end
	end

	return signal
end

--------------------------------------------------
-- Vector3
--------------------------------------------------
local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__sub = function(a, b)
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return setmetatable({ X = dx, Y = dy, Z = dz, __vector = true, Magnitude = math.sqrt(dx * dx + dy * dy + dz * dz) }, vectorMeta)
end

local function V3(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z, __vector = true, Magnitude = math.sqrt(x * x + y * y + z * z) }, vectorMeta)
end

--------------------------------------------------
-- Instance
--------------------------------------------------
local instanceMethods = {}
local instanceMeta = {}

local function dataOf(obj)
	return REG[obj]
end

local function getName(obj)
	return REG[obj].fields.Name
end

local function eachDescendant(obj, out)
	out = out or {}
	for _, child in ipairs(REG[obj].children) do
		table.insert(out, child)
		eachDescendant(child, out)
	end
	return out
end

local function isAncestorWorkspace(obj)
	local node = REG[obj].fields.Parent
	while node do
		if node == workspace then
			return true
		end
		node = REG[node] and REG[node].fields.Parent or nil
	end
	return false
end

local function fireAncestry(obj)
	local data = REG[obj]
	if data.signals.AncestryChanged then
		data.signals.AncestryChanged:Fire(obj, data.fields.Parent)
	end
	for _, child in ipairs(eachDescendant(obj)) do
		local childData = REG[child]
		if childData.signals.AncestryChanged then
			childData.signals.AncestryChanged:Fire(child, childData.fields.Parent)
		end
	end
end

local function setParent(obj, newParent)
	local data = REG[obj]
	local oldParent = data.fields.Parent

	if oldParent == newParent then
		return
	end

	if oldParent then
		local siblings = REG[oldParent].children
		local index = table.find(siblings, obj)
		if index then
			table.remove(siblings, index)
		end
		-- 사라지기 전에 조상들에게 알린다
		local node = oldParent
		while node do
			local nodeData = REG[node]
			if nodeData.signals.DescendantRemoving then
				nodeData.signals.DescendantRemoving:Fire(obj)
			end
			node = nodeData.fields.Parent
		end
	end

	data.fields.Parent = newParent

	if newParent then
		table.insert(REG[newParent].children, obj)
		local node = newParent
		while node do
			local nodeData = REG[node]
			if nodeData.signals.DescendantAdded then
				for _, item in ipairs({ obj, table.unpack(eachDescendant(obj)) }) do
					nodeData.signals.DescendantAdded:Fire(item)
				end
			end
			node = nodeData.fields.Parent
		end
	end

	fireAncestry(obj)
end

local function setOccupant(seat, humanoid)
	local data = REG[seat]
	if data.fields.Occupant == humanoid then
		return
	end

	local previous = data.fields.Occupant
	data.fields.Occupant = humanoid

	if previous and REG[previous].fields.SeatPart == seat then
		REG[previous].fields.SeatPart = nil
		REG[previous].fields.Sit = false
	end

	local signal = data.propSignals.Occupant
	if signal then
		signal:Fire()
	end
end

local function rawSit(seat, humanoid)
	local humanoidData = REG[humanoid]
	local previousSeat = humanoidData.fields.SeatPart
	if previousSeat and previousSeat ~= seat then
		setOccupant(previousSeat, nil)
	end
	humanoidData.fields.SeatPart = seat
	humanoidData.fields.Sit = true
	setOccupant(seat, humanoid)
end

instanceMeta.__index = function(self, key)
	local data = REG[self]
	if key == "ClassName" then
		return data.className
	end
	local method = instanceMethods[key]
	if method then
		return method
	end
	if EVENT_NAMES[key] then
		data.signals[key] = data.signals[key] or newSignal()
		return data.signals[key]
	end
	local value = data.fields[key]
	if value ~= nil then
		return value
	end
	for _, child in ipairs(data.children) do
		if REG[child].fields.Name == key then
			return child
		end
	end
	return nil
end

instanceMeta.__newindex = function(self, key, value)
	local data = REG[self]

	if key == "Parent" then
		setParent(self, value)
		return
	end

	-- Humanoid.Sit = false 는 실제 Roblox 처럼 좌석에서 일어나게 만든다
	if key == "Sit" and data.className == "Humanoid" then
		if value == false then
			local seat = data.fields.SeatPart
			data.fields.Sit = false
			if seat then
				setOccupant(seat, nil)
			end
			return
		end
	end

	local old = data.fields[key]
	data.fields[key] = value
	if old ~= value then
		local signal = data.propSignals[key]
		if signal then
			signal:Fire()
		end
	end
end

instanceMeta.__tostring = function(self)
	return REG[self].fields.Name
end

local function newInstance(className, name)
	local obj = setmetatable({}, instanceMeta)
	REG[obj] = {
		className = className,
		fields = { Name = name or className, Parent = nil },
		children = {},
		attributes = {},
		attrSignals = {},
		propSignals = {},
		signals = {},
	}

	if className == "Seat" then
		REG[obj].fields.Occupant = nil
		REG[obj].fields.Disabled = false
		REG[obj].fields.Position = V3(0, 0, 0)
	elseif className == "Humanoid" then
		REG[obj].fields.Health = 100
		REG[obj].fields.Sit = false
		REG[obj].fields.SeatPart = nil
	elseif className == "ProximityPrompt" then
		REG[obj].fields.Enabled = true
	end

	return obj
end

function instanceMethods.IsA(self, className)
	local own = REG[self].className
	if own == className then
		return true
	end
	if className == "Instance" then
		return true
	end
	if className == "BasePart" then
		return BASE_PARTS[own] == true
	end
	if className == "Model" and own == "Model" then
		return true
	end
	return false
end

function instanceMethods.FindFirstChild(self, name, recursive)
	for _, child in ipairs(REG[self].children) do
		if REG[child].fields.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(REG[self].children) do
			local found = instanceMethods.FindFirstChild(child, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function instanceMethods.WaitForChild(self, name)
	local found = instanceMethods.FindFirstChild(self, name)
	assert(found, ("WaitForChild 실패: %s 안에 %s 가 없습니다"):format(getName(self), name))
	return found
end

function instanceMethods.FindFirstChildOfClass(self, className)
	for _, child in ipairs(REG[self].children) do
		if REG[child].className == className then
			return child
		end
	end
	return nil
end

function instanceMethods.FindFirstChildWhichIsA(self, className, recursive)
	for _, child in ipairs(REG[self].children) do
		if instanceMethods.IsA(child, className) then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(REG[self].children) do
			local found = instanceMethods.FindFirstChildWhichIsA(child, className, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function instanceMethods.FindFirstAncestorOfClass(self, className)
	local node = REG[self].fields.Parent
	while node do
		if REG[node].className == className then
			return node
		end
		node = REG[node].fields.Parent
	end
	return nil
end

function instanceMethods.GetChildren(self)
	return table.clone(REG[self].children)
end

function instanceMethods.GetDescendants(self)
	return eachDescendant(self)
end

function instanceMethods.IsDescendantOf(self, ancestor)
	local node = REG[self].fields.Parent
	while node do
		if node == ancestor then
			return true
		end
		node = REG[node].fields.Parent
	end
	return false
end

function instanceMethods.GetFullName(self)
	local parts = { getName(self) }
	local node = REG[self].fields.Parent
	while node do
		table.insert(parts, 1, getName(node))
		node = REG[node].fields.Parent
	end
	return table.concat(parts, ".")
end

function instanceMethods.Destroy(self)
	setParent(self, nil)
	REG[self].destroyed = true
end

function instanceMethods.SetAttribute(self, name, value)
	local data = REG[self]
	local old = data.attributes[name]
	data.attributes[name] = value
	if old ~= value and data.attrSignals[name] then
		data.attrSignals[name]:Fire()
	end
end

function instanceMethods.GetAttribute(self, name)
	return REG[self].attributes[name]
end

function instanceMethods.GetAttributeChangedSignal(self, name)
	local data = REG[self]
	data.attrSignals[name] = data.attrSignals[name] or newSignal()
	return data.attrSignals[name]
end

function instanceMethods.GetPropertyChangedSignal(self, name)
	local data = REG[self]
	data.propSignals[name] = data.propSignals[name] or newSignal()
	return data.propSignals[name]
end

-- Seat:Sit(humanoid) : 실제 Roblox 처럼 Disabled 좌석에는 앉지 못한다
function instanceMethods.Sit(self, humanoid)
	if REG[self].fields.Disabled then
		return
	end
	rawSit(self, humanoid)
end

--------------------------------------------------
-- 서비스
--------------------------------------------------
local services = {}

local function newService(className)
	local service = newInstance(className, className)
	services[className] = service
	return service
end

workspace = newService("Workspace")
instanceMethods.GetServerTimeNow = function()
	return clock
end

local PlayersService = newService("Players")
instanceMethods.GetPlayerFromCharacter = function(self, character)
	if not character then
		return nil
	end
	for _, player in ipairs(playersList) do
		if REG[player].fields.Character == character then
			return player
		end
	end
	return nil
end
instanceMethods.GetPlayers = function()
	return table.clone(playersList)
end

local ReplicatedStorage = newService("ReplicatedStorage")
local ServerScriptService = newService("ServerScriptService")

local CollectionService = newService("CollectionService")
local tagMap = {} -- [tag] = { [instance] = true }
local tagAdded, tagRemoved = {}, {}

instanceMethods.AddTag = function(self, instance, tag)
	tagMap[tag] = tagMap[tag] or {}
	if tagMap[tag][instance] then
		return
	end
	tagMap[tag][instance] = true
	if tagAdded[tag] then
		tagAdded[tag]:Fire(instance)
	end
end
instanceMethods.RemoveTag = function(self, instance, tag)
	if not (tagMap[tag] and tagMap[tag][instance]) then
		return
	end
	tagMap[tag][instance] = nil
	if tagRemoved[tag] then
		tagRemoved[tag]:Fire(instance)
	end
end
instanceMethods.HasTag = function(self, instance, tag)
	return (tagMap[tag] and tagMap[tag][instance]) == true
end
instanceMethods.GetTagged = function(self, tag)
	local list = {}
	for instance in pairs(tagMap[tag] or {}) do
		table.insert(list, instance)
	end
	return list
end
instanceMethods.GetInstanceAddedSignal = function(self, tag)
	tagAdded[tag] = tagAdded[tag] or newSignal()
	return tagAdded[tag]
end
instanceMethods.GetInstanceRemovedSignal = function(self, tag)
	tagRemoved[tag] = tagRemoved[tag] or newSignal()
	return tagRemoved[tag]
end

local HttpService = newService("HttpService")
local guidCounter = 0
instanceMethods.GenerateGUID = function()
	guidCounter += 1
	return ("GUID%04d"):format(guidCounter)
end

game = {
	GetService = function(_, name)
		local service = services[name]
		assert(service, "알 수 없는 서비스: " .. tostring(name))
		return service
	end,
}

--------------------------------------------------
-- 전역 흉내
--------------------------------------------------
local realOsClock = os.clock
os = { clock = function() return clock end, time = os.time, date = os.date }

task = {
	delay = function(delay, fn, ...) schedule(delay, fn, table.pack(...)) end,
	defer = function(fn, ...) schedule(0, fn, table.pack(...)) end,
	spawn = function(fn, ...) fn(...) end,
	wait = function() end,
}

function typeof(value)
	local kind = type(value)
	if kind == "table" then
		if REG[value] then
			return "Instance"
		end
		if rawget(value, "_isConnection") then
			return "RBXScriptConnection"
		end
		if rawget(value, "__vector") then
			return "Vector3"
		end
	end
	return kind
end

local realPrint = print
function print(...)
	table.insert(logs, table.concat({ ... }, " "))
end
function warn(...)
	local message = ""
	for _, value in ipairs({ ... }) do
		message ..= tostring(value) .. " "
	end
	table.insert(warnings, message)
end

Instance = { new = function(className) return newInstance(className) end }

Random = {
	new = function()
		return {
			NextInteger = function(_, min, max)
				return math.random(min, max)
			end,
		}
	end,
}

Color3 = {
	fromRGB = function(r, g, b)
		return { R = r, G = g, B = b, __color = true }
	end,
}

local enumMeta
enumMeta = {
	__index = function(t, key)
		local value = setmetatable({ Name = key }, enumMeta)
		rawset(t, key, value)
		return value
	end,
}
Enum = setmetatable({}, enumMeta)

--------------------------------------------------
-- 모듈 로딩 (require 흉내)
--------------------------------------------------
local moduleFns = {}
local moduleCache = {}
local moduleOfInstance = {}

function require(target)
	if moduleCache[target] then
		return moduleCache[target]
	end
	local name = moduleOfInstance[target]
	assert(name, "require 대상이 아닙니다: " .. tostring(target))
	assert(moduleFns[name], "모듈 소스가 없습니다: " .. name)
	local result = moduleFns[name](target)
	moduleCache[target] = result
	return result
end

--------------------------------------------------
-- 테스트가 사용하는 도구
--------------------------------------------------
Mock = {}
Mock.REG = REG
Mock.V3 = V3
Mock.newInstance = newInstance
Mock.workspace = workspace
Mock.Players = PlayersService
Mock.CollectionService = CollectionService
Mock.ReplicatedStorage = ReplicatedStorage
Mock.ServerScriptService = ServerScriptService
Mock.warnings = warnings
Mock.logs = logs
Mock.realPrint = realPrint

function Mock.now()
	return clock
end

function Mock.advance(seconds)
	runDue(clock + seconds)
end

function Mock.flush()
	runDue(clock)
end

function Mock.registerModules(fns)
	moduleFns = fns
end

function Mock.mountModule(name, parent)
	local holder = newInstance("ModuleScript", name)
	holder.Parent = parent
	moduleOfInstance[holder] = name
	return holder
end

function Mock.makePlayer(name, userId)
	local player = newInstance("Player", name)
	REG[player].fields.UserId = userId
	REG[player].fields.DisplayName = name

	local character = newInstance("Model", name)
	local humanoid = newInstance("Humanoid", "Humanoid")
	humanoid.Parent = character
	local root = newInstance("Part", "HumanoidRootPart")
	root.Position = V3(0, 0, 0)
	root.Parent = character
	REG[humanoid].fields.RootPart = root

	REG[player].fields.Character = character
	player.Parent = PlayersService
	table.insert(playersList, player)
	return player
end

function Mock.humanoidOf(player)
	return player.Character:FindFirstChildOfClass("Humanoid")
end

function Mock.makeTableModel(name, tableType, seatCount, parent)
	local model = newInstance("Model", name)
	local seats = newInstance("Folder", "Seats")
	seats.Parent = model

	for index = 1, seatCount do
		local chair = newInstance("Model", ("Chair_%02d"):format(index))
		chair.Parent = seats
		local seat = newInstance("Seat", ("Seat_%02d"):format(index))
		seat.Position = V3(index * 4, 0, 0)
		seat:SetAttribute("SeatIndex", index)
		seat:SetAttribute("OccupantUserId", 0)
		seat.Parent = chair
	end

	model:SetAttribute("TableId", name)
	model:SetAttribute("TableType", tableType)
	model.Parent = parent or workspace
	CollectionService:AddTag(model, "CursedBarrel_Table")
	return model
end

function Mock.seatsOf(model)
	local list = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Seat") then
			table.insert(list, descendant)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("SeatIndex") or 0) < (b:GetAttribute("SeatIndex") or 0)
	end)
	return list
end

-- 플레이어가 자리로 걸어가 E 를 누른 상황
function Mock.pressSit(player, seat)
	local prompt = seat:FindFirstChild("SitPrompt")
	if not prompt then
		return false, "프롬프트 없음"
	end
	if prompt.Enabled == false then
		return false, "프롬프트 비활성"
	end

	local humanoid = Mock.humanoidOf(player)
	REG[humanoid].fields.RootPart.Position = seat.Position
	prompt.Triggered:Fire(player)
	Mock.flush()
	return seat.Occupant == humanoid
end

-- 익스플로잇: 프롬프트/Disabled 를 무시하고 강제로 앉힌 상황
function Mock.exploitSit(player, seat)
	rawSit(seat, Mock.humanoidOf(player))
	Mock.flush()
end

function Mock.stand(player)
	local humanoid = Mock.humanoidOf(player)
	humanoid.Sit = false
	Mock.flush()
end

-- 캐릭터 리셋 (리스폰)
function Mock.resetCharacter(player)
	local data = REG[player]
	local oldCharacter = data.fields.Character
	local humanoid = oldCharacter:FindFirstChildOfClass("Humanoid")

	if data.signals.CharacterRemoving then
		data.signals.CharacterRemoving:Fire(oldCharacter)
	end

	-- 캐릭터가 사라지면 좌석도 비워진다
	local seat = REG[humanoid].fields.SeatPart
	if seat then
		setOccupant(seat, nil)
	end
	oldCharacter:Destroy()

	local character = newInstance("Model", getName(player))
	local newHumanoid = newInstance("Humanoid", "Humanoid")
	newHumanoid.Parent = character
	local root = newInstance("Part", "HumanoidRootPart")
	root.Position = V3(0, 0, 0)
	root.Parent = character
	REG[newHumanoid].fields.RootPart = root
	data.fields.Character = character

	if data.signals.CharacterAdded then
		data.signals.CharacterAdded:Fire(character)
	end
	Mock.flush()
end

function Mock.leave(player)
	if PlayersService.PlayerRemoving then
		PlayersService.PlayerRemoving:Fire(player)
	end
	local index = table.find(playersList, player)
	if index then
		table.remove(playersList, index)
	end
	local character = REG[player].fields.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and REG[humanoid].fields.SeatPart
		if seat then
			setOccupant(seat, nil)
		end
		character:Destroy()
	end
	REG[player].fields.Character = nil
	player.Parent = nil
	Mock.flush()
end
