-- 경제 시뮬레이션 : 실제 RoundService · ProfileService 로 판을 여러 번 돌려 우승자가 한 판에 버는 코인을 잰다.
--   CB_TIMESCALE=100 lune run tools/tests/sim_economy.luau [판 수] [테이블 종류] [잡기 성공률]
local task = require("@lune/task")
local process = require("@lune/process")
local H = require("./harness")
local SSS = H.services.ServerScriptService
local RS = H.services.ReplicatedStorage
local Services = SSS.CursedBarrel.Services
H.cache[Services.TableService] = { TableAdded = H.Signal(), TableRemoved = H.Signal(), GetAllTables = function() return {} end }
local Profiles = H.load(Services.ProfileService)
Profiles:Start()
local RoundService = H.load(Services.RoundService)
local GameConfig = H.load(RS.CursedBarrel.Shared.GameConfig)
local TableConfig = H.load(RS.CursedBarrel.Shared.TableConfig)

local GAMES = tonumber(process.args[1]) or 40
local TYPE = process.args[2] or "Standard4"
local CATCH_RATE = tonumber(process.args[3]) or 0.6

-- 가짜 테이블 ----------------------------------------------------------
local T = {}
T.__index = T
local function newTable(typeName)
	local t = setmetatable({}, T)
	t.tableId = "T_" .. typeName
	t.typeName = typeName
	t.config = table.clone(TableConfig.get(typeName))
	t.state = GameConfig.States.Waiting
	t.destroyed = false
	t.model = H.fakeInstance("Model", "TableModel")
	t.RosterChanged = H.Signal()
	t.SlotTriggered = H.Signal()
	t.players = {}
	t.seats = {}
	for i = 1, t.config.SeatCount do
		local seat = H.fakeInstance("Seat", "Seat" .. i)
		seat.Position = Vector3 and nil
		table.insert(t.seats, seat)
	end
	t.used = {}
	t.slotObjs = {}
	for i = 1, t.config.KnifeSlots do
		t.slotObjs[i] = H.fakeInstance("Part", "Slot" .. i)
	end
	return t
end
function T:SetTableAttribute(n, v) self.model:SetAttribute(n, v) end
function T:SetState(s) self.state = s; self.model:SetAttribute("State", s) end
function T:GetMinPlayers() return self.config.MinPlayers end
function T:GetPlayers() return table.clone(self.players) end
function T:GetPlayerCount() return #self.players end
function T:GetSeats() return self.seats end
function T:GetPlayerOfSeat(seat) return seat.player end
function T:GetSeatOfPlayer(p) for _, s in ipairs(self.seats) do if s.player == p then return s end end end
function T:GetFreeSlotIndices() local l = {} for i = 1, #self.slotObjs do if not self.used[i] then table.insert(l, i) end end return l end
function T:IsSlotUsed(i) return self.used[i] == true end
function T:MarkSlotUsed(i) self.used[i] = true end
function T:GetSlot(i) return self.slotObjs[i] end
function T:GetSlotCount() return #self.slotObjs end
function T:ResetSlots() table.clear(self.used) end
function T:ResetBarrelLook() end
function T:RefreshBarrelSkin() end
function T:PlayDangerEffect() end
function T:ClearSeatFlags() end
function T:SetSeatAlive() end
function T:HasPlayer(p) return table.find(self.players, p) ~= nil end
function T:Sit(p)
	for _, s in ipairs(self.seats) do
		if not s.player then
			s.player = p
			table.insert(self.players, p)
			self.RosterChanged:Fire(self, p, true)
			return
		end
	end
end
function T:RemovePlayer(p)
	local i = table.find(self.players, p)
	if i then
		table.remove(self.players, i)
		for _, s in ipairs(self.seats) do if s.player == p then s.player = nil end end
		self.RosterChanged:Fire(self, p, false)
	end
end

local function human(name)
	local p = H.newPlayer(name)
	p.GetNetworkPing = function() return 0.1 end
	H.waitFor(function() return Profiles:Get(p) ~= nil end, 5)
	return p
end
local function startRound(t, players)
	for _, p in ipairs(players) do t:Sit(p) end
	RoundService:_attach(t)
	local round = RoundService:GetRound(t)
	task.wait(0.05)
	round:_beginRound()
	H.waitFor(function() return t.state == GameConfig.States.Playing end, 10)
	return round
end

local function playGame(n)
	local t = newTable(TYPE)
	local players = {}
	for i = 1, n do
		local p = human("P" .. i)
		table.insert(players, p)
	end
	local before = {}
	for _, p in ipairs(players) do
		before[p] = Profiles:Get(p).coins
	end
	for _, p in ipairs(players) do t:Sit(p) end
	RoundService:_attach(t)
	local round = RoundService:GetRound(t)
	task.wait(0.01)
	round:_beginRound()
	local handled, braved = {}, {}
	local maxPot, rounds, jackpots, surges = 0, 0, 0, 0
	local seenEvents = #H.events
	local started = os.clock()
	while t.state ~= GameConfig.States.RoundEnding and os.clock() - started < 30 do
		if t.state == GameConfig.States.Playing then
			local c = round.catch
			if c and not handled[c.token] then
				handled[c.token] = true
				if not c.spent and math.random() < CATCH_RATE then
					local tapAt = c.opensAt + c.window * 0.35
					task.spawn(function()
						while GameConfig.now() < tapAt do task.wait() end
						round:HandleCatchInput(c.player, tapAt, true)
					end)
				end
			elseif not c and not round.resolving then
				local p = round:GetCurrentPlayer()
				local free = {}
				for _, i in ipairs(t:GetFreeSlotIndices()) do if i ~= round.sealed then table.insert(free, i) end end
				if p and #free > 0 then
					round:_resolvePick(p, free[math.random(1, #free)], "sim")
				end
			end
			local offer = round.braveOffer
			if offer and not braved[offer.token] then
				braved[offer.token] = true
				if math.random() < 0.25 then round:AcceptBrave(offer.player) end
			end
		end
		maxPot = math.max(maxPot, round.pot or 0)
		task.wait()
	end
	for i = seenEvents + 1, #H.events do
		local e = H.events[i]
		if e.remote == "PresentationCue" then
			if e.args[1] == "Jackpot" then jackpots += 1 elseif e.args[1] == "Surge" then surges += 1 end
		end
	end
	rounds = t.model:GetAttribute(GameConfig.TableAttributes.Stage) or 0
	local best = 0
	for _, p in ipairs(players) do
		best = math.max(best, Profiles:Get(p).coins - before[p])
	end
	RoundService:_detach(t)
	for _, p in ipairs(players) do H.leave(p) end
	return best, maxPot, rounds, jackpots, surges
end

local seats = TableConfig.get(TYPE).SeatCount
local results = {}
local totalJ, totalS, totalR = 0, 0, 0
for g = 1, GAMES do
	local best, pot, rounds, j, s = playGame(seats)
	table.insert(results, best)
	totalJ += j; totalS += s; totalR += rounds
end
table.sort(results)
local sum = 0
for _, v in ipairs(results) do sum += v end
local function pct(q) return results[math.max(1, math.ceil(#results * q))] end
print(("%s %d판 · 우승자 한 판 코인  평균 %d · 중간 %d · 상위10%% %d · 최고 %d  |  판당 라운드 %.1f · 보물폭발 %.1f · 잭팟 %.2f")
	:format(TYPE, #results, sum / #results, pct(0.5), pct(0.9), results[#results], totalR / GAMES, totalS / GAMES, totalJ / GAMES))
process.exit(0)
