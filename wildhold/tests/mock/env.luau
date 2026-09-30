-- 서비스 모의 구현 + 스크립트 로더. roblox.luau 위에서 DataModel(game) 을 만든다.
local R, D, API = ...
local new = R.newInstance
local task = R.task
local Signal = R.Signal
local methods = R.methods

local E = {}

local function custom(inst, tbl)
	rawset(inst, "_custom", tbl)
	return inst
end

local function deepcopy(v, seen)
	if type(v) ~= "table" or getmetatable(v) ~= nil then return v end
	seen = seen or {}
	if seen[v] then return seen[v] end
	local out = {}
	seen[v] = out
	for k, x in pairs(v) do out[deepcopy(k, seen)] = deepcopy(x, seen) end
	return out
end

-- ===================================================================== 광선 (지형 = y 0 평면, 파트 = 회전 상자)
local function rayBox(origin, dir, part)
	local cf, size = part._props.CFrame or D.CFrame.new(), part._props.Size or D.Vector3.new(4, 1.2, 2)
	local inv = cf:Inverse()
	local o = inv * origin
	local d = inv:VectorToWorldSpace(dir)
	local half = size / 2
	local tmin, tmax = 0, 1
	for _, axis in ipairs({"X", "Y", "Z"}) do
		local oa, da, h = o[axis], d[axis], half[axis]
		if math.abs(da) < 1e-9 then
			if oa < -h or oa > h then return nil end
		else
			local t1, t2 = (-h - oa) / da, (h - oa) / da
			if t1 > t2 then t1, t2 = t2, t1 end
			tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
			if tmin > tmax then return nil end
		end
	end
	-- 광선이 상자 안에서 시작하면 그 상자는 맞지 않는다 (Roblox 와 같음)
	if tmin <= 0 then return nil end
	return tmin
end

-- 인스턴스 아래 BasePart 목록 캐시 (트리가 바뀌면 R.TreeVersion 이 올라가 다시 모은다). 큰 맵에서 광선마다 전체를 훑지 않게.
local partCache = setmetatable({}, {__mode = "k"})
local function partsUnder(inst)
	local entry = partCache[inst]
	local version = rawget(inst, "_ver") or 0
	if entry and entry.Version == version then return entry.List end
	local list = {}
	if R.isA(inst._class, "BasePart") then table.insert(list, inst) end
	for _, d in ipairs(methods.GetDescendants(inst)) do
		if R.isA(d._class, "BasePart") then table.insert(list, d) end
	end
	partCache[inst] = {Version = version, List = list}
	return list
end

function E.raycast(origin, dir, params)
	local filter = params and rawget(params, "FilterDescendantsInstances") or {}
	local include = params and rawget(params, "FilterType") and rawget(rawget(params, "FilterType"), "Name") == "Include"
	local candidates = {}
	local terrainAllowed = not include
	-- 광선 구간의 상자 (파트 중심이 이 상자에서 파트 크기보다 멀면 건너뛴다)
	local ox, oy, oz, dx, dy, dz = origin.X, origin.Y, origin.Z, dir.X, dir.Y, dir.Z
	local minX, maxX = math.min(ox, ox + dx), math.max(ox, ox + dx)
	local minY, maxY = math.min(oy, oy + dy), math.max(oy, oy + dy)
	local minZ, maxZ = math.min(oz, oz + dz), math.max(oz, oz + dz)
	local function near(part)
		local cf, size = part._props.CFrame, part._props.Size
		if not cf or not size then return true end
		local r = (size.X + size.Y + size.Z) * 0.5
		local x, y, z = cf[1], cf[2], cf[3]
		return x + r >= minX and x - r <= maxX and y + r >= minY and y - r <= maxY and z + r >= minZ and z - r <= maxZ
	end
	local function addTree(inst)
		if R.isA(inst._class, "Terrain") then terrainAllowed = true return end
		for _, part in ipairs(partsUnder(inst)) do
			if near(part) then table.insert(candidates, part) end
		end
	end
	if include then
		for _, inst in ipairs(filter) do addTree(inst) end
	else
		local excluded = {}
		for _, inst in ipairs(filter) do
			excluded[inst] = true
			for _, d in ipairs(methods.GetDescendants(inst)) do excluded[d] = true end
		end
		for _, d in ipairs(partsUnder(E.workspace)) do
			if not excluded[d] and d._class ~= "Terrain" and near(d) then table.insert(candidates, d) end
		end
	end
	local best, bestPart
	for _, part in ipairs(candidates) do
		local canQuery = part._props.CanQuery
		if canQuery == nil then canQuery = true end
		local canCollide = part._props.CanCollide
		if canCollide == nil then canCollide = true end
		if canQuery or canCollide then
			local t = rayBox(origin, dir, part)
			if t and (not best or t < best) then best, bestPart = t, part end
		end
	end
	if terrainAllowed and dir.Y < 0 and origin.Y > 0 then
		local t = -origin.Y / dir.Y
		if t <= 1 and (not best or t < best) then best, bestPart = t, E.workspace.Terrain end
	end
	if not best then return nil end
	local hit = origin + dir * best
	return setmetatable({Position = hit, Instance = bestPart, Distance = (dir * best).Magnitude, Normal = D.Vector3.new(0, 1, 0),
		Material = R.Enum.Material.Grass}, {__type = "RaycastResult"})
end

-- ===================================================================== DataModel
function E.build(localPlayerName)
	local game = new("DataModel")
	rawget(game, "_props").Name = "Game"
	local services = {}
	E.game = game
	local function service(name)
		if services[name] then return services[name] end
		assert(API.Services[name] or name == "Workspace", "없는 서비스: " .. tostring(name))
		local cls = API.Classes[name] and name or "Instance"
		local s = new(cls)
		rawget(s, "_props").Name = name
		rawget(s, "_props").Parent = game
		table.insert(rawget(game, "_children"), s)
		services[name] = s
		return s
	end
	custom(game, {
		GetService = function(_, name) return service(name) end,
		FindService = function(_, name) return services[name] end,
		BindToClose = function(_, fn) E.CloseHandlers = E.CloseHandlers or {}; table.insert(E.CloseHandlers, fn) end,
		IsLoaded = function() return true end,
	})
	local workspace = service("Workspace")
	E.workspace = workspace
	local terrain = new("Terrain", workspace)
	rawget(terrain, "_props").Name = "Terrain"
	rawget(workspace, "_props").Terrain = terrain
	E.TerrainOps = {}
	local function terrainOp(name)
		return function(_, ...)
			table.insert(E.TerrainOps, {name, ...})
		end
	end
	custom(terrain, {FillBlock = terrainOp("FillBlock"), FillBall = terrainOp("FillBall"), FillCylinder = terrainOp("FillCylinder"),
		FillWedge = terrainOp("FillWedge"), Clear = function() E.TerrainOps = {} end, SetMaterialColor = function(_, m, c)
			assert(R.typeof(m) == "EnumItem" and R.typeof(c) == "Color3", "SetMaterialColor 인자 오류")
		end, ReplaceMaterial = terrainOp("ReplaceMaterial")})
	local camera = new("Camera", workspace)
	rawget(workspace, "_props").CurrentCamera = camera
	custom(workspace, {
		Raycast = function(_, origin, dir, params)
			assert(R.typeof(origin) == "Vector3" and R.typeof(dir) == "Vector3", "Raycast 인자는 Vector3")
			return E.raycast(origin, dir, params)
		end,
		BulkMoveTo = function(_, parts, frames, mode)
			assert(#parts == #frames, "BulkMoveTo 개수 불일치")
			for i, p in ipairs(parts) do
				assert(R.typeof(frames[i]) == "CFrame", "BulkMoveTo 에 CFrame 아닌 값")
				p.CFrame = frames[i]
			end
		end,
		GetServerTimeNow = function() return 1000 + R.Now end,
		GetPartBoundsInRadius = function() return {} end,
	})

	-- Players
	local players = service("Players")
	E.players = players
	custom(players, {GetPlayers = function()
		local list = {}
		for _, c in ipairs(rawget(players, "_children")) do if c._class == "Player" then table.insert(list, c) end end
		return list
	end, GetPlayerFromCharacter = function(_, char)
		for _, c in ipairs(rawget(players, "_children")) do if c._props.Character == char then return c end end
		return nil
	end})

	-- RunService
	local run = service("RunService")
	custom(run, {IsStudio = function() return true end, IsServer = function() return true end, IsClient = function() return true end,
		IsRunning = function() return true end})
	E.Heartbeat, E.RenderStepped, E.Stepped = run.Heartbeat, run.RenderStepped, run.Stepped

	-- HttpService
	local guid = 0
	custom(service("HttpService"), {GenerateGUID = function(_, wrap)
		guid = guid + 1
		local s = string.format("%08x-0000-4000-8000-%012x", guid * 2654435761 % 4294967296, guid)
		return wrap == false and s or ("{" .. s .. "}")
	end, JSONEncode = function(_, v) return tostring(v) end})

	-- TweenService: 즉시 목표값을 적용하고, Completed 는 시간이 지나면 발생
	custom(service("TweenService"), {Create = function(_, obj, info, props)
		assert(R.typeof(obj) == "Instance", "TweenService:Create 대상은 Instance")
		assert(R.typeof(info) == "TweenInfo", "TweenService:Create 두번째 인자는 TweenInfo")
		for k in pairs(props) do
			local _ = obj[k] -- 없는 속성이면 여기서 오류
		end
		local tween = new("Tween")
		custom(tween, {
			Play = function()
				for k, v in pairs(props) do obj[k] = v end
				task.delay(rawget(info, "Time") or 0, function() tween.Completed:Fire(R.Enum.PlaybackState.Completed) end)
			end,
			Cancel = function() end, Pause = function() end,
		})
		return tween
	end})

	-- CollectionService
	local tags = {}
	custom(service("CollectionService"), {
		AddTag = function(_, inst, tag) tags[tag] = tags[tag] or {}; tags[tag][inst] = true end,
		RemoveTag = function(_, inst, tag) if tags[tag] then tags[tag][inst] = nil end end,
		HasTag = function(_, inst, tag) return tags[tag] ~= nil and tags[tag][inst] == true end,
		GetTagged = function(_, tag)
			local out = {}
			for inst in pairs(tags[tag] or {}) do if not rawget(inst, "_destroyed") then table.insert(out, inst) end end
			return out
		end,
		GetInstanceAddedSignal = function() return Signal("TagAdded") end,
	})

	-- Debris
	custom(service("Debris"), {AddItem = function(_, inst, t)
		task.delay(t or 10, function() if not rawget(inst, "_destroyed") then inst:Destroy() end end)
	end})

	-- Pathfinding: 직선 경로
	custom(service("PathfindingService"), {CreatePath = function()
		local path = new("Path")
		local waypoints = {}
		rawget(path, "_props").Status = R.Enum.PathStatus.Success
		custom(path, {
			ComputeAsync = function(_, from, to)
				task.wait(0.05)
				waypoints = {}
				for i = 0, 4 do
					table.insert(waypoints, {Position = from:Lerp(to, i / 4), Action = R.Enum.PathWaypointAction.Walk})
				end
			end,
			GetWaypoints = function() return waypoints end,
		})
		return path
	end})

	-- DataStore (메모리)
	local stores = {}
	custom(service("DataStoreService"), {GetDataStore = function(_, name)
		stores[name] = stores[name] or {}
		local data = stores[name]
		local store = new("DataStore")
		custom(store, {UpdateAsync = function(_, key, fn)
			task.wait(0.1)
			local result = fn(deepcopy(data[key]))
			if result ~= nil then data[key] = deepcopy(result) end
			return deepcopy(result)
		end, GetAsync = function(_, key) return deepcopy(data[key]) end, SetAsync = function(_, key, v) data[key] = deepcopy(v) end})
		return store
	end})

	-- ContextActionService
	E.Actions = {}
	custom(service("ContextActionService"), {
		BindAction = function(_, name, fn) E.Actions[name] = fn end,
		UnbindAction = function(_, name) E.Actions[name] = nil end,
		SetTitle = function() end, SetPosition = function() end, SetImage = function() end, GetButton = function() return nil end,
	})
	for _, name in ipairs({"ReplicatedStorage", "ServerScriptService", "StarterPlayer", "StarterGui", "StarterPack", "Lighting", "SoundService",
		"UserInputService", "ServerStorage", "TextService"}) do
		service(name)
	end
	-- TextService: 필터 흉내 ("나쁜말" → ###)
	custom(service("TextService"), {FilterStringAsync = function(_, text, userId)
		assert(type(text) == "string" and type(userId) == "number", "FilterStringAsync 인자 오류")
		task.wait(0.05)
		local result = new("TextFilterResult")
		local clean = string.gsub(text, "나쁜말", "###")
		custom(result, {GetNonChatStringForBroadcastAsync = function() return clean end})
		return result
	end})
	local starterPlayer = service("StarterPlayer")
	local sps = new("StarterPlayerScripts", starterPlayer)
	rawget(sps, "_props").Name = "StarterPlayerScripts"

	-- Instance.new
	E.Instance = {new = function(cls, parent)
		assert(type(cls) == "string", "Instance.new 인자는 클래스 이름")
		if not API.Creatable[cls] then error("Instance.new 로 만들 수 없는 클래스: " .. cls, 2) end
		local inst = new(cls)
		E.decorate(inst)
		if parent then inst.Parent = parent end
		return inst
	end}
	return game
end

-- 클래스별 동작 (리모트, 휴머노이드 등)
function E.decorate(inst)
	local cls = inst._class
	if cls == "RemoteEvent" then
		custom(inst, {
			FireServer = function(self, ...) self.OnServerEvent:Fire(E.LocalPlayer, table.unpack(deepcopy({...}))) end,
			FireClient = function(self, player, ...)
				assert(R.typeof(player) == "Instance" and player._class == "Player", "FireClient 첫 인자는 Player")
				if player == E.LocalPlayer then self.OnClientEvent:Fire(table.unpack(deepcopy({...}))) end
			end,
			FireAllClients = function(self, ...) self.OnClientEvent:Fire(table.unpack(deepcopy({...}))) end,
		})
	elseif cls == "Humanoid" then
		custom(inst, {
			TakeDamage = function(self, n)
				self.Health = math.max(0, self.Health - n)
				if self.Health <= 0 and not rawget(self, "_dead") then rawset(self, "_dead", true); self.Died:Fire() end
			end,
			-- 실제 Roblox 처럼 들고 있던 다른 도구는 가방(도구가 있던 곳)으로 돌아간다
			EquipTool = function(self, tool)
				local from = tool.Parent
				for _, other in ipairs(self.Parent:GetChildren()) do
					if other ~= tool and other.ClassName == "Tool" then other.Parent = from end
				end
				tool.Parent = self.Parent
			end,
			MoveTo = function() end,
			GetState = function() return R.Enum.HumanoidStateType.Running end,
		})
	elseif cls == "ParticleEmitter" then
		custom(inst, {Emit = function(_, n) assert(type(n) == "number", "Emit 숫자") end, Clear = function() end})
	elseif cls == "Sound" then
		custom(inst, {Play = function() end, Stop = function() end})
	end
	return inst
end

-- ===================================================================== 스크립트
function E.makeEnv(scriptInst, globals)
	local env = setmetatable({}, {__index = globals})
	env.script = scriptInst
	return env
end

function E.runScript(scriptInst, globals, requireFn)
	local src = rawget(scriptInst, "_source")
	local fn = loadsource(src, scriptInst:GetFullName())
	local env = E.makeEnv(scriptInst, globals)
	env.require = requireFn
	setfenv(fn, env)
	return task.spawn(fn)
end

return E
