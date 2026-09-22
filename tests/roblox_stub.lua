--[[
	roblox_stub.lua
	Roblox 엔진 없이 게임 로직을 돌려 보기 위한 최소한의 흉내 환경.

	진짜 엔진이 아니다. 물리 · 렌더 · 네트워크는 흉내 내지 않는다.
	여기서 확인하려는 것은 "규칙이 맞게 돌아가는가" 하나다.
	  · 가짜 시계 : task.delay 가 쌓이고, step(초) 로 시간을 밀어 준다
	  · 가짜 인스턴스 : Attribute · 자식 · 신호
	  · 가짜 RemoteEvent : 보낸 내용을 기록만 한다
]]

local stub = {}

--------------------------------------------------
-- 가짜 시계와 스케줄러
--------------------------------------------------
local clock = 0
local queue = {}

local scheduler = {}
function scheduler.now()
	return clock
end

function scheduler.reset()
	clock = 0
	queue = {}
end

-- 예약된 일이 없을 때까지, 또는 지정한 시간만큼 시계를 민다.
function scheduler.step(seconds)
	local target = clock + seconds
	while true do
		local soonest, index = nil, nil
		for position, entry in ipairs(queue) do
			if not entry.done and (soonest == nil or entry.at < soonest.at) then
				soonest, index = entry, position
			end
		end
		if not soonest or soonest.at > target then
			break
		end
		clock = soonest.at
		soonest.done = true
		table.remove(queue, index)
		local ok, err = pcall(soonest.fn)
		if not ok then
			error("예약된 일에서 오류: " .. tostring(err), 0)
		end
	end
	clock = target
end

stub.scheduler = scheduler

--------------------------------------------------
-- 전역
--------------------------------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(handler)
	table.insert(self.handlers, handler)
	local connection = { Connected = true }
	function connection:Disconnect()
		self.Connected = false
		for index, entry in ipairs(self.handlers or {}) do
			if entry == handler then
				table.remove(self.handlers, index)
				break
			end
		end
	end
	connection.handlers = self.handlers
	return connection
end
function Signal:Once(handler)
	return self:Connect(handler)
end
function Signal:Fire(...)
	for _, handler in ipairs(table.clone(self.handlers)) do
		handler(...)
	end
end

local Instance = {}

-- 점 표기로 자식을 찾을 수 있어야 한다. (ReplicatedStorage.CursedBarrel.Remotes 처럼)
-- 먼저 메서드를 찾고, 없으면 같은 이름의 자식을 돌려준다.
Instance.__index = function(self, key)
	local method = rawget(Instance, key)
	if method ~= nil then
		return method
	end
	for _, child in ipairs(rawget(self, "_children") or {}) do
		if child.Name == key then
			return child
		end
	end
	return nil
end

local function newInstance(className)
	return setmetatable({
		ClassName = className,
		Name = className,
		_children = {},
		_attributes = {},
		_attributeSignals = {},
		_propertySignals = {},
		Parent = nil,
		Occupant = nil,
		Enabled = true,
		Disabled = false,
	}, Instance)
end

function Instance:IsA(className)
	if self.ClassName == className then
		return true
	end
	if className == "BasePart" then
		return self.ClassName == "Part" or self.ClassName == "Seat" or self.ClassName == "WedgePart"
	end
	if className == "Instance" then
		return true
	end
	return false
end

function Instance:GetChildren()
	return table.clone(self._children)
end

function Instance:GetDescendants()
	local list = {}
	for _, child in ipairs(self._children) do
		table.insert(list, child)
		for _, deeper in ipairs(child:GetDescendants()) do
			table.insert(list, deeper)
		end
	end
	return list
end

function Instance:FindFirstChild(name, recursive)
	for _, child in ipairs(self._children) do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(self._children) do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function Instance:FindFirstChildOfClass(className)
	for _, child in ipairs(self._children) do
		if child.ClassName == className then
			return child
		end
	end
	return nil
end

function Instance:FindFirstChildWhichIsA(className, recursive)
	for _, child in ipairs(self._children) do
		if child:IsA(className) then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(self._children) do
			local found = child:FindFirstChildWhichIsA(className, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function Instance:WaitForChild(name)
	local found = self:FindFirstChild(name)
	assert(found, ("WaitForChild('%s') 가 %s 안에서 실패"):format(name, self.Name))
	return found
end

function Instance:GetAttribute(name)
	return self._attributes[name]
end

function Instance:SetAttribute(name, value)
	local before = self._attributes[name]
	self._attributes[name] = value
	if before ~= value and self._attributeSignals[name] then
		self._attributeSignals[name]:Fire()
	end
end

function Instance:GetAttributeChangedSignal(name)
	if not self._attributeSignals[name] then
		self._attributeSignals[name] = Signal.new()
	end
	return self._attributeSignals[name]
end

function Instance:GetPropertyChangedSignal(name)
	if not self._propertySignals[name] then
		self._propertySignals[name] = Signal.new()
	end
	return self._propertySignals[name]
end

function Instance:Destroy()
	if self.Parent then
		for index, child in ipairs(self.Parent._children) do
			if child == self then
				table.remove(self.Parent._children, index)
				break
			end
		end
	end
	self.Parent = nil
end

function Instance:GetFullName()
	return self.Name
end

local function setParent(instance, parent)
	if instance.Parent then
		for index, child in ipairs(instance.Parent._children) do
			if child == instance then
				table.remove(instance.Parent._children, index)
				break
			end
		end
	end
	rawset(instance, "Parent", parent)
	if parent then
		table.insert(parent._children, instance)
	end
end

Instance.__newindex = function(self, key, value)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	rawset(self, key, value)
end

stub.newInstance = newInstance
stub.Signal = Signal

--------------------------------------------------
-- 환경 만들기
--
-- Luau CLI 는 _G 가 읽기 전용이라 전역을 갈아끼울 수 없다.
-- 그래서 전역을 흉내 낸 표를 하나 만들어 주고, 모듈을 불러올 때
-- 그 표의 값들을 지역 변수로 가려 쓰게 한다. (tests/loader.lua 가 한다)
--------------------------------------------------
function stub.build()
	scheduler.reset()

	local env = {}

	env.Instance = {
		new = function(className, parent)
			local instance = newInstance(className)
			if className == "RemoteEvent" then
				instance.sent = {}
				instance.OnServerEvent = Signal.new()
				function instance:FireClient(player, ...)
					table.insert(self.sent, { player = player, args = table.pack(...) })
				end
				function instance:FireAllClients(...)
					table.insert(self.sent, { player = "all", args = table.pack(...) })
				end
			end
			if parent then
				instance.Parent = parent
			end
			return instance
		end,
	}

	env.Vector3 = setmetatable({
		new = function(x, y, z)
			return { X = x or 0, Y = y or 0, Z = z or 0 }
		end,
	}, {})
	env.Color3 = {
		fromRGB = function(r, g, b)
			return { R = r, G = g, B = b, Lerp = function(self) return self end }
		end,
		new = function(r, g, b)
			return { R = r, G = g, B = b }
		end,
	}
	env.CFrame = setmetatable({
		new = function() return {} end,
		Angles = function() return {} end,
		lookAt = function() return {} end,
	}, {})
	env.UDim2 = { new = function() return {} end, fromScale = function() return {} end, fromOffset = function() return {} end }
	env.UDim = { new = function() return {} end }
	env.NumberSequence = { new = function() return {} end }
	env.NumberSequenceKeypoint = { new = function() return {} end }
	env.ColorSequence = { new = function() return {} end }
	env.NumberRange = { new = function() return {} end }
	env.Vector2 = { new = function() return {} end }
	env.TweenInfo = { new = function() return {} end }

	local function enumItem(name)
		return setmetatable({ Name = name }, { __tostring = function() return name end })
	end
	env.Enum = setmetatable({}, {
		__index = function(_, category)
			return setmetatable({}, {
				__index = function(_, name)
					return enumItem(category .. "." .. name)
				end,
			})
		end,
	})

	env.Random = {
		new = function(seed)
			local state = seed or 20260922
			local generator = {}
			local function nextValue()
				state = (1103515245 * state + 12345) % 2147483648
				return state / 2147483648
			end
			function generator:NextInteger(low, high)
				return low + math.floor(nextValue() * (high - low + 1))
			end
			function generator:NextNumber(low, high)
				if low == nil then
					return nextValue()
				end
				return low + nextValue() * (high - low)
			end
			return generator
		end,
	}

	env.task = {
		delay = function(seconds, fn)
			table.insert(queue, { at = clock + (seconds or 0), fn = fn })
		end,
		spawn = function(fn, ...)
			local args = table.pack(...)
			local ok, err = pcall(fn, table.unpack(args, 1, args.n))
			if not ok then
				error("task.spawn 안에서 오류: " .. tostring(err), 0)
			end
		end,
		defer = function(fn)
			table.insert(queue, { at = clock, fn = fn })
		end,
		wait = function(seconds)
			clock += seconds or 0
		end,
	}

	env.typeof = function(value)
		if type(value) == "table" and getmetatable(value) == Instance then
			return "Instance"
		end
		return type(value)
	end

	env.os = os
	env.workspace = newInstance("Workspace")
	env.workspace.Name = "Workspace"
	function env.workspace:GetServerTimeNow()
		return scheduler.now()
	end

	local services = {}
	env.game = {
		GetService = function(_, name)
			if not services[name] then
				local service = newInstance(name)
				service.Name = name
				if name == "Players" then
					service.PlayerAdded = Signal.new()
					service.PlayerRemoving = Signal.new()
					service._players = {}
					function service:GetPlayers()
						return table.clone(self._players)
					end
					function service:GetPlayerByUserId(userId)
						for _, player in ipairs(self._players) do
							if player.UserId == userId then
								return player
							end
						end
						return nil
					end
					function service:GetPlayerFromCharacter()
						return nil
					end
				end
				services[name] = service
			end
			return services[name]
		end,
		BindToClose = function() end,
	}
	env.game.Workspace = env.workspace
	env.warn = warn
	env.print = print
	stub.services = services
	stub.env = env

	return env
end

return stub
