--[[
	RoundService 모의 실험 (Phase 32)
	Roblox 없이 진짜 RoundService · GameConfig · TableConfig · Utility 코드를 돌린다.
	  · Roblox 서비스 · 테이블 · 프로필은 가짜(stub)로 바꾸고, 시간은 가상 시계로 빨리 감는다.
	  · AI 선원은 진짜 RoundService 의 AI 코드로, 사람은 아래 정책(policy)대로 누른다.
	사용 : lune run tests/sim_round.luau [src 폴더]
	실패(오류 · 멈춘 판 · 기대와 다른 결과)가 있으면 error 로 끝난다.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local SRC = process.args[1] or "src"

--------------------------------------------------
-- 가상 시계 · task
--------------------------------------------------
local NOW = 1000
local queue = {}
local seq = 0
local errors = {}
local function schedule(at, fn, ...)
	seq += 1
	table.insert(queue, { at = at, seq = seq, fn = fn, args = table.pack(...) })
end
local function runSafe(fn, args)
	local ok, err = xpcall(function()
		fn(table.unpack(args, 1, args.n))
	end, function(e)
		return tostring(e) .. "\n" .. debug.traceback()
	end)
	if not ok then
		table.insert(errors, err)
		print("!! ERROR: " .. err)
	end
end
local fakeTask = {
	delay = function(d, fn, ...)
		schedule(NOW + math.max(0, tonumber(d) or 0), fn, ...)
	end,
	spawn = function(fn, ...)
		runSafe(fn, table.pack(...))
	end,
	defer = function(fn, ...)
		schedule(NOW, fn, ...)
	end,
	wait = function()
		error("task.wait 는 모의 실험에서 쓸 수 없습니다")
	end,
}
local function step()
	if #queue == 0 then
		return false
	end
	table.sort(queue, function(a, b)
		if a.at == b.at then
			return a.seq < b.seq
		end
		return a.at < b.at
	end)
	local item = table.remove(queue, 1)
	NOW = math.max(NOW, item.at)
	runSafe(item.fn, item.args)
	return true
end

--------------------------------------------------
-- 가짜 Random (결과를 되풀이할 수 있게 씨앗을 쓴다)
--------------------------------------------------
local Random = {}
Random.__index = Random
local seedCounter = 12345
function Random.new(seed)
	seedCounter += 7919
	return setmetatable({ state = (tonumber(seed) or seedCounter) % 2147483647 + 1 }, Random)
end
function Random:NextNumber(a, b)
	self.state = (self.state * 16807) % 2147483647
	local x = self.state / 2147483647
	if a and b then
		return a + (b - a) * x
	end
	return x
end
function Random:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:NextNumber())
end

--------------------------------------------------
-- 가짜 신호 · 인스턴스
--------------------------------------------------
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in ipairs(self.handlers) do
			fn(...)
		end
	end
	return s
end

local fired = {} -- 원격으로 나간 것들 { remote, target, args }
local listeners = {} -- [remote 이름] = function(target, ...)
local function attrs(obj)
	obj._attrs = obj._attrs or {}
	function obj:GetAttribute(k)
		return self._attrs[k]
	end
	function obj:SetAttribute(k, v)
		self._attrs[k] = v
		if self._onAttr then
			self._onAttr(k, v)
		end
	end
	return obj
end

local function remoteEvent(name)
	local r = attrs({ Name = name, ClassName = "RemoteEvent", OnServerEvent = signal() })
	function r:FireClient(target, ...)
		table.insert(fired, { remote = name, target = target, args = table.pack(...) })
		if listeners[name] then
			listeners[name](target, ...)
		end
	end
	function r:FireAllClients(...)
		table.insert(fired, { remote = name, target = "all", args = table.pack(...) })
		if listeners[name] then
			listeners[name]("all", ...)
		end
	end
	function r:IsA(c)
		return c == "RemoteEvent"
	end
	return r
end

local function folder(name, children)
	local f = { Name = name, _children = children or {} }
	function f:FindFirstChild(n)
		return self._children[n]
	end
	function f:WaitForChild(n)
		local c = self._children[n]
		if not c then
			error("WaitForChild 에 없는 것: " .. tostring(n) .. " in " .. self.Name)
		end
		return c
	end
	setmetatable(f, {
		__index = function(t, k)
			local c = rawget(t, "_children")[k]
			if c ~= nil then
				return c
			end
			return nil
		end,
	})
	return f
end

-- Instance.new 는 RemoteEvent · Folder 만 쓰인다
local FakeInstance = {
	new = function(className)
		if className == "RemoteEvent" then
			local r = remoteEvent("?")
			setmetatable(r, {
				__newindex = function(t, k, v)
					if k == "Parent" and v and v._children then
						v._children[rawget(t, "Name")] = t
					end
					rawset(t, k, v)
				end,
			})
			return r
		end
		return folder(className)
	end,
}

--------------------------------------------------
-- 모듈 불러오기
--------------------------------------------------
local stubs = {} -- [모듈 이름] = 가짜 모듈 (서버 서비스들)
local loaded = {}
local baseEnv

local function moduleRef(path, name)
	return { __module = true, path = path, name = name }
end

local function sharedFolder()
	local names = {}
	for _, file in fs.readDir(SRC .. "/ReplicatedStorage/CursedBarrel/Shared") do
		local n = file:match("^(.-)%.lua$")
		if n then
			names[n] = moduleRef(SRC .. "/ReplicatedStorage/CursedBarrel/Shared/" .. file, n)
		end
	end
	return folder("Shared", names)
end

local remotesFolder = folder("Remotes", {})
for _, name in ipairs({ "PresentationCue", "SelectSlot", "CatchPrompt", "CatchInput", "CatchResult", "SabotageCue", "TableStart", "BraveRequest" }) do
	remotesFolder._children[name] = remoteEvent(name)
end
local shared = sharedFolder()
local cursedBarrel = folder("CursedBarrel", { Shared = shared, Remotes = remotesFolder })
local ReplicatedStorage = folder("ReplicatedStorage", { CursedBarrel = cursedBarrel })

local Players = { Name = "Players", PlayerRemoving = signal(), PlayerAdded = signal(), _list = {} }
function Players:GetPlayers()
	return table.clone(self._list)
end

local services = {
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = { IsStudio = function() return false end, Heartbeat = signal() },
	AnalyticsService = {
		LogCustomEvent = function() end,
		LogOnboardingFunnelStepEvent = function() end,
	},
}
local fakeGame = {
	GetService = function(_, name)
		local s = services[name]
		if not s then
			error("모의 실험에 없는 서비스: " .. tostring(name))
		end
		return s
	end,
}
local fakeWorkspace = attrs({ Name = "Workspace" })
function fakeWorkspace:GetServerTimeNow()
	return NOW
end

local function requireModule(ref)
	if type(ref) == "table" and ref.__stub then
		return ref.value
	end
	if type(ref) ~= "table" or not ref.__module then
		error("require 할 수 없는 값: " .. tostring(ref))
	end
	if stubs[ref.name] ~= nil and not ref.path then
		return stubs[ref.name]
	end
	if loaded[ref.path] ~= nil then
		return loaded[ref.path]
	end
	local source = fs.readFile(ref.path)
	local scriptObj = { Name = ref.name, Parent = ref.parent }
	-- Lune 은 환경 표의 metatable 을 따르지 않으므로 값을 직접 옮겨 담는다
	local env = { script = scriptObj }
	for k, v in pairs(baseEnv) do
		env[k] = v
	end
	local chunk = luau.load(source, { debugName = ref.name, environment = env })
	local result = chunk()
	loaded[ref.path] = result
	return result
end

-- 서버 서비스 폴더 : script.Parent.X → 가짜 모듈
local servicesFolder = setmetatable({ Name = "Services" }, {
	__index = function(_, k)
		if stubs[k] ~= nil then
			return { __stub = true, value = stubs[k] }
		end
		error("모의 실험에 없는 서버 모듈: " .. tostring(k))
	end,
})
-- Shared 모듈의 script.Parent = Shared 폴더
for _, ref in pairs(shared._children) do
	ref.parent = shared
end

baseEnv = {
	game = fakeGame,
	workspace = fakeWorkspace,
	task = fakeTask,
	Random = Random,
	Instance = FakeInstance,
	require = requireModule,
	warn = function(...)
		print("warn:", ...)
	end,
	typeof = function(v)
		if type(v) == "table" and rawget(v, "__instance") then
			return "Instance"
		end
		return typeof(v)
	end,
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	Enum = roblox.Enum,
	NumberSequence = roblox.NumberSequence,
	NumberRange = roblox.NumberRange,
	ColorSequence = roblox.ColorSequence,
	Font = roblox.Font,
	BrickColor = roblox.BrickColor,
	TweenInfo = { new = function() return {} end },
	DateTime = { now = function() return { UnixTimestamp = os.time() } end },
}
for _, name in ipairs({ "print", "pairs", "ipairs", "next", "select", "type", "tostring", "tonumber", "pcall", "xpcall", "error", "assert",
	"setmetatable", "getmetatable", "rawget", "rawset", "rawequal", "rawlen", "unpack", "math", "string", "table", "os", "coroutine", "utf8", "bit32", "buffer", "debug", "newproxy" }) do
	baseEnv[name] = _G[name] or ({ print = print, pairs = pairs, ipairs = ipairs, next = next, select = select, type = type, tostring = tostring,
		tonumber = tonumber, pcall = pcall, xpcall = xpcall, error = error, assert = assert, setmetatable = setmetatable, getmetatable = getmetatable,
		rawget = rawget, rawset = rawset, rawequal = rawequal, rawlen = rawlen, unpack = table.unpack, math = math, string = string, table = table,
		os = os, coroutine = coroutine, utf8 = utf8, bit32 = bit32, buffer = buffer, debug = debug, newproxy = newproxy })[name]
end

--------------------------------------------------
-- 가짜 서버 서비스
--------------------------------------------------
local profiles = {} -- [player] = profile
local awarded = {} -- [player] = coins
local counted = {} -- [player] = games
stubs.ProfileService = {
	Award = function(_, player, coins)
		awarded[player] = (awarded[player] or 0) + (tonumber(coins) or 0)
		return coins
	end,
	RecordRound = function(_, _, _, _, _, _, _, options)
		if options then
			options.sameFoes = nil
		end
	end,
	BreakStreak = function() end,
	Bump = function() end,
	MarkTutorialDone = function(_, player)
		local p = profiles[player]
		if p then
			p.tutorialDone = true
		end
		player:SetAttribute("TutorialDone", true)
	end,
	Get = function(_, player)
		return profiles[player]
	end,
	CountGame = function(_, player)
		counted[player] = (counted[player] or 0) + 1
		return counted[player], counted[player] == 2, false
	end,
	SeeKind = function(_, player, kind)
		local p = profiles[player]
		if not p then
			return false
		end
		p.seen = p.seen or {}
		if p.seen[kind] then
			return false
		end
		p.seen[kind] = true
		return true
	end,
	Funnel = function() end,
	GainScale = function()
		return 1
	end,
}
stubs.RankingService = { RecordRound = function() end }
stubs.RewardService = { OnGameCounted = function() end }

local tablesList = {}
stubs.TableService = {
	TableAdded = signal(),
	TableRemoved = signal(),
	GetAllTables = function()
		return tablesList
	end,
	GetTableFromModel = function(_, model)
		for _, t in ipairs(tablesList) do
			if t.model == model then
				return t
			end
		end
		return nil
	end,
	GetTableOfPlayer = function(_, player)
		for _, t in ipairs(tablesList) do
			if t:HasPlayer(player) then
				return t
			end
		end
		return nil
	end,
}

--------------------------------------------------
-- 가짜 테이블
--------------------------------------------------
local TableConfig = requireModule(shared._children.TableConfig)
local GameConfig = requireModule(shared._children.GameConfig)
GameConfig.DEBUG = false

local function newTable(typeName, seatCount)
	local t = {
		tableId = "Table_SIM",
		typeName = typeName,
		config = TableConfig.get(typeName),
		state = "Waiting",
		destroyed = false,
		RosterChanged = signal(),
		SlotTriggered = signal(),
		seats = {},
		occupants = {},
		used = {},
		slotCount = TableConfig.getSlotCount(typeName),
	}
	t.model = attrs({ Name = "Table_SIM", __instance = true })
	t.model._attrs.TableId = "Table_SIM"
	function t.model:IsA(c)
		return c == "Model"
	end
	function t.model:FindFirstChild()
		return nil
	end
	for i = 1, seatCount do
		t.seats[i] = attrs({ Name = "Seat" .. i })
	end
	function t:SetTableAttribute(k, v)
		self.model:SetAttribute(k, v)
	end
	function t:SetState(s)
		self.state = s
		self.model:SetAttribute("State", s)
	end
	function t:GetMinPlayers()
		return self.config.MinPlayers or 2
	end
	function t:GetPlayers()
		local list = {}
		for i = 1, #self.seats do
			if self.occupants[i] then
				table.insert(list, self.occupants[i])
			end
		end
		return list
	end
	function t:GetPlayerCount()
		return #self:GetPlayers()
	end
	function t:GetSeats()
		return self.seats
	end
	function t:GetPlayerOfSeat(seat)
		for i, s in ipairs(self.seats) do
			if s == seat then
				return self.occupants[i]
			end
		end
		return nil
	end
	function t:HasPlayer(p)
		for i = 1, #self.seats do
			if self.occupants[i] == p then
				return true
			end
		end
		return false
	end
	function t:GetSeatOfPlayer(p)
		for i = 1, #self.seats do
			if self.occupants[i] == p then
				return self.seats[i]
			end
		end
		return nil
	end
	function t:Seat(p)
		for i = 1, #self.seats do
			if not self.occupants[i] then
				self.occupants[i] = p
				self.RosterChanged:Fire(self, p, true)
				return true
			end
		end
		return false
	end
	function t:RemovePlayer(p)
		for i = 1, #self.seats do
			if self.occupants[i] == p then
				self.occupants[i] = nil
				self.RosterChanged:Fire(self, p, false)
			end
		end
	end
	function t:GetFreeSlotIndices()
		local list = {}
		for i = 1, self.slotCount do
			if not self.used[i] then
				table.insert(list, i)
			end
		end
		return list
	end
	function t:IsSlotUsed(i)
		return self.used[i] == true
	end
	function t:MarkSlotUsed(i)
		self.used[i] = true
	end
	function t:ResetSlots()
		table.clear(self.used)
	end
	function t:ResetBarrelLook() end
	function t:RefreshBarrelSkin() end
	function t:ClearSeatFlags() end
	function t:PlayDangerEffect() end
	function t:SetSeatAlive() end
	function t:GetSlotCount()
		return self.slotCount
	end
	function t:GetSlot(i)
		if i >= 1 and i <= self.slotCount then
			return attrs({ Name = "Slot" .. i })
		end
		return nil
	end
	return t
end

--------------------------------------------------
-- 사람 · AI
--------------------------------------------------
local nextBotId = -1
local function newBot(skill)
	nextBotId -= 1
	local b = attrs({ IsBot = true, UserId = nextBotId, Name = "Bot" .. -nextBotId, DisplayName = "Bot", skill = skill or 0.6, brave = 0.3 })
	return b
end
local function newHuman(userId, games, tutorialDone)
	local p = attrs({ UserId = userId, Name = "Human" .. userId, DisplayName = "Human" .. userId, Parent = Players, __instance = true })
	function p:GetNetworkPing()
		return 0.06
	end
	function p:IsA(c)
		return c == "Player"
	end
	p._attrs.Games = games or 0
	p._attrs.TutorialDone = tutorialDone
	profiles[p] = { tutorialDone = tutorialDone == true, games = games or 0 }
	table.insert(Players._list, p)
	return p
end

--------------------------------------------------
-- 실험 하나
--------------------------------------------------
local RoundService -- 한 번만 불러온다

local function runScenario(opts)
	print(("\n=== %s ==="):format(opts.name))
	table.clear(queue)
	table.clear(fired)
	table.clear(tablesList)
	table.clear(Players._list)
	table.clear(awarded)
	table.clear(counted)
	local errorsBefore = #errors

	local t = newTable(opts.tableType or "Standard4", opts.seats or 4)
	table.insert(tablesList, t)
	if opts.tutorialFor then
		t.model._attrs.Tutorial = opts.tutorialFor
	end

	if not RoundService then
		local roundRef = moduleRef(SRC .. "/ServerScriptService/CursedBarrel/Services/RoundService.lua", "RoundService")
		roundRef.parent = servicesFolder
		RoundService = requireModule(roundRef)
		RoundService:Start()
	else
		RoundService._rounds = {}
		RoundService:_attach(t)
	end
	if not RoundService._rounds[t] then
		RoundService:_attach(t)
	end
	local round = RoundService._rounds[t]

	local humans = opts.humans or {}
	local stats = { kinds = {}, cards = {}, stages = 0, saves = 0, results = {}, winner = nil, tutorialSteps = {}, reactions = {} }

	-- 사람이 차례를 받으면 칼을 고른다
	t.model._onAttr = function(k, v)
		if k == "CurrentTurnUserId" and t.state == "Playing" then
			for _, h in ipairs(humans) do
				if h.player.UserId == v then
					fakeTask.delay(0.6, function()
						if round.participants[round.turnIndex] ~= h.player or round.resolving or t.state ~= "Playing" then
							return
						end
						local free = {}
						for _, i in ipairs(t:GetFreeSlotIndices()) do
							if i ~= round.sealed then
								table.insert(free, i)
							end
						end
						round.afk[h.player] = 0
						round:_resolvePick(h.player, free[math.random(1, #free)], "sim")
					end)
				end
			end
		elseif k == "Stage" then
			stats.stages = math.max(stats.stages, v or 0)
		elseif k == "TutorialStep" and (v or 0) > 0 then
			table.insert(stats.tutorialSteps, v)
		end
	end

	listeners.CatchPrompt = function(target, model, data)
		if target == "all" or not data.mine then
			return
		end
		stats.kinds[data.kind] = (stats.kinds[data.kind] or 0) + 1
		for _, h in ipairs(humans) do
			if h.player == target then
				h.policy(round, h.player, data)
			end
		end
	end
	listeners.CatchResult = function(_, model, data)
		table.insert(stats.results, data)
		if data.saved then
			stats.saves += 1
		end
		if data.reaction then
			table.insert(stats.reactions, data.reaction)
		end
	end
	listeners.PresentationCue = function(_, kind, model, data)
		if kind == "FateCard" then
			stats.cards[data.card] = (stats.cards[data.card] or 0) + 1
		elseif kind == "Win" then
			stats.winner = data.userId
			stats.winData = data
		end
	end

	-- 앉힌다 (카운트다운이 끝나면 판이 시작된다)
	for _, h in ipairs(humans) do
		t:Seat(h.player)
	end
	for i = 1, (opts.bots or 0) do
		t:Seat(newBot(opts.botSkill))
	end

	local limit = NOW + (opts.maxTime or 3600)
	while NOW < limit and stats.winner == nil do
		if not step() then
			break
		end
		if #errors > errorsBefore + 5 then
			break
		end
	end
	-- 결과 알림 뒤 초기화까지 조금 더 돌린다
	local after = NOW + 8
	while NOW < after and step() do
	end

	stats.errors = #errors - errorsBefore
	stats.timedOut = stats.winner == nil
	local kinds = {}
	for k, n in pairs(stats.kinds) do
		table.insert(kinds, k .. "×" .. n)
	end
	table.sort(kinds)
	local cards = {}
	for k, n in pairs(stats.cards) do
		table.insert(cards, k .. "×" .. n)
	end
	table.sort(cards)
	print(("  stages %d · winner %s · saves %d · errors %d%s"):format(stats.stages, tostring(stats.winner), stats.saves, stats.errors, stats.timedOut and " · 시간 초과(판이 안 끝남)" or ""))
	print("  kinds (사람이 만난 해적): " .. table.concat(kinds, ", "))
	print("  cards: " .. table.concat(cards, ", "))
	if #stats.tutorialSteps > 0 then
		print("  tutorial steps: " .. table.concat(stats.tutorialSteps, ","))
	end
	if #stats.reactions > 0 then
		local sum = 0
		for _, r in ipairs(stats.reactions) do
			sum += r
		end
		print(("  reaction avg %.3fs over %d catches"):format(sum / #stats.reactions, #stats.reactions))
	end
	return stats, round, t
end

--------------------------------------------------
-- 사람 정책
--------------------------------------------------
-- 잘하는 사람 : 해적 종류마다 맞게 누른다 (반응 0.18~0.26초)
local function skilled(round, player, data)
	local steps = data.steps or { { opensAt = data.opensAt, window = data.window } }
	local function tap(at, side)
		fakeTask.delay(at - NOW + 0.03, function()
			round:HandleCatchInput(player, at, false, side)
		end)
	end
	if data.kind == "skull" then
		return
	elseif data.kind == "mash" then
		for i = 1, data.need or 5 do
			tap(steps[1].opensAt + 0.2 + i * 0.09)
		end
	else
		for _, s in ipairs(steps) do
			tap(s.opensAt + 0.18 + math.random() * 0.08, data.side)
		end
	end
end
-- 서툰 신입 : 해적이 나오기 전에 누른다
local function hasty(round, player, data)
	fakeTask.delay(math.max(0.35, (data.opensAt - NOW) * 0.5), function()
		round:HandleCatchInput(player, NOW, false, data.side)
	end)
end
-- 튜토리얼 : 종류마다 처음 한 번은 틀리고 그다음엔 잘 누른다
local function learner()
	local tried = {}
	return function(round, player, data)
		if not tried[data.kind] then
			tried[data.kind] = true
			if data.kind == "skull" then
				fakeTask.delay(data.opensAt - NOW + 0.2, function()
					round:HandleCatchInput(player, NOW, false)
				end)
			elseif data.kind == "side" then
				fakeTask.delay(data.opensAt - NOW + 0.25, function()
					round:HandleCatchInput(player, NOW, false, data.side == "L" and "R" or "L")
				end)
			else
				hasty(round, player, data)
			end
			return
		end
		skilled(round, player, data)
	end
end

--------------------------------------------------
-- 실험들
--------------------------------------------------
local failures = {}
local function expect(cond, message)
	if not cond then
		table.insert(failures, message)
		print("  ✗ " .. message)
	else
		print("  ✓ " .. message)
	end
end

-- 1) 잘하는 사람 + AI 셋 : 여러 종류 · 카드 · 라운드
local expert = newHuman(101, 50, true)
local s1 = runScenario({ name = "잘하는 사람 + AI 셋", humans = { { player = expert, policy = skilled } }, bots = 3, botSkill = 0.55, maxTime = 7200 })
expect(s1.errors == 0, "오류 없이 돈다")
expect(not s1.timedOut, "판이 끝난다")
-- 사람 하나 + AI 셋이면 사람이 만나는 해적이 한 판에 몇 마리뿐이라 판마다 운이다. 종류 뽑기는 직접 본다
local picker = Random.new(4242)
local stage1, stage2, stage5 = {}, {}, {}
for _ = 1, 400 do
	local k1, k2, k5 = GameConfig.pickPirateKind(1, nil, picker), GameConfig.pickPirateKind(2, nil, picker), GameConfig.pickPirateKind(5, nil, picker)
	stage1[k1] = (stage1[k1] or 0) + 1
	stage2[k2] = (stage2[k2] or 0) + 1
	stage5[k5] = (stage5[k5] or 0) + 1
end
expect(stage1.normal == 400, "1라운드는 보통 해적만")
expect((stage2.twin or 0) > 40 and not stage2.side, ("2라운드부터 쌍둥이가 섞인다 (400번 중 %d)"):format(stage2.twin or 0))
expect((stage5.twin or 0) > 0 and (stage5.side or 0) > 0 and (stage5.skull or 0) > 0 and (stage5.mash or 0) > 0 and not stage5.angry, "5라운드면 다섯 종류가 모두 섞인다 (분노한 해적은 7라운드부터)")
local cardCount = 0
for _ in pairs(s1.cards) do
	cardCount += 1
end
expect(cardCount > 0, "운명 카드가 뽑힌다")

-- 2) 잘하는 사람 둘이 끝까지 : 8라운드를 넘기는가 (AI 는 금방 떨어진다)
local a, b = newHuman(201, 80, true), newHuman(202, 80, true)
local s2 = runScenario({ name = "잘하는 사람 둘 (끝없는 라운드)", humans = { { player = a, policy = skilled }, { player = b, policy = skilled } }, bots = 0, maxTime = 1800 })
expect(s2.errors == 0, "오류 없이 돈다")
expect(s2.stages > 8, ("8라운드를 넘긴다 (%d라운드까지 · 둘 다 한 번도 안 놓치면 끝나지 않는다)"):format(s2.stages))

-- 2b) 쌍둥이는 둘 다 잡아야 한다 : 첫째만 누르고 둘째를 안 누르면 놓친 것이다
local function twinOnce(round, player, data)
	if data.kind == "twin" then
		local first = (data.steps or {})[1] or { opensAt = data.opensAt }
		fakeTask.delay(first.opensAt - NOW + 0.2, function()
			round:HandleCatchInput(player, first.opensAt + 0.17, false)
		end)
		return
	end
	skilled(round, player, data)
end
local steady, lazy = newHuman(211, 80, true), newHuman(212, 80, true)
local s2b = runScenario({ name = "쌍둥이를 한 마리만 잡는 사람", humans = { { player = steady, policy = skilled }, { player = lazy, policy = twinOnce } }, bots = 0, maxTime = 1800 })
local lazyTwins, lazyTwinCaught = 0, 0
for _, r in ipairs(s2b.results) do
	if r.userId == lazy.UserId and r.kind == "twin" then
		lazyTwins += 1
		if r.success then
			lazyTwinCaught += 1
		end
	end
end
expect(s2b.errors == 0, "오류 없이 돈다")
expect(lazyTwins >= 1 and lazyTwinCaught == 0, ("한 마리만 잡으면 놓친 것 (쌍둥이 %d번 · 잡음 %d)"):format(lazyTwins, lazyTwinCaught))
expect(s2b.winner == steady.UserId, "둘 다 잡는 사람이 이긴다")

-- 3) 서툰 신입 : 한 번은 살려 주고 그다음엔 탈락
local rookie = newHuman(301, 0, true)
local s3 = runScenario({ name = "서툰 신입 + AI 셋", humans = { { player = rookie, policy = hasty } }, bots = 3, maxTime = 1800 })
expect(s3.errors == 0, "오류 없이 돈다")
local rookieMet = 0
for _, count in pairs(s3.kinds) do
	rookieMet += count
end
-- (AI 셋과 하면 해적을 한 번도 안 만나고 끝나는 판도 드물게 있다. 그때는 살려 줄 일이 없다)
expect(s3.saves == 1 or rookieMet == 0, ("신입 보호는 한 판에 한 번 (%d번 · 만난 해적 %d)"):format(s3.saves, rookieMet))
expect(not s3.timedOut, "판이 끝난다")

-- 4) 튜토리얼 : 다섯 종류를 모두 잡아야 끝나고, 튜토리얼한 사람이 이긴다
local newbie = newHuman(401, 0, false)
local s4 = runScenario({ name = "필수 튜토리얼", humans = { { player = newbie, policy = learner() } }, bots = 2, tutorialFor = 401, maxTime = 1800 })
expect(s4.errors == 0, "오류 없이 돈다")
expect(profiles[newbie].tutorialDone == true, "튜토리얼을 마친다")
expect(s4.winner == 401, "튜토리얼한 사람이 이긴다")
expect((s4.kinds.normal or 0) >= 1 and (s4.kinds.twin or 0) >= 1 and (s4.kinds.side or 0) >= 1 and (s4.kinds.skull or 0) >= 1 and (s4.kinds.mash or 0) >= 1, "다섯 종류를 모두 만난다")
expect(s4.saves >= 5, ("종류마다 한 번씩 틀려도 다시 나온다 (살려 준 횟수 %d)"):format(s4.saves))

-- 5) 튜토리얼에서 아무것도 안 누르는 사람 : 멈추지 않고 끝난다
local afk = newHuman(501, 0, false)
local s5 = runScenario({ name = "튜토리얼에서 가만히 있는 사람", humans = { { player = afk, policy = function() end } }, bots = 2, tutorialFor = 501, maxTime = 1800 })
expect(s5.errors == 0, "오류 없이 돈다")
expect(not s5.timedOut, "판이 끝난다 (무한히 다시 나오지 않는다)")

print(("\n총 오류 %d · 실패 %d"):format(#errors, #failures))
if #errors > 0 or #failures > 0 then
	error("모의 실험 실패")
end
