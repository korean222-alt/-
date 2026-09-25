local task = require("@lune/task")
local H = require("./harness")
local SSS = H.services.ServerScriptService
local RS = H.services.ReplicatedStorage
local Services = SSS.CursedBarrel.Services
-- TableService 는 무거운 빌더를 끌고 오므로 가짜로 둔다 (Round 는 Start 전에는 쓰지 않는다)
H.cache[Services.TableService] = { TableAdded = H.Signal(), TableRemoved = H.Signal(), GetAllTables = function() return {} end }
local Profiles = H.load(Services.ProfileService)
Profiles:Start()
local RoundService = H.load(Services.RoundService)
local GameConfig = H.load(RS.CursedBarrel.Shared.GameConfig)
local TableConfig = H.load(RS.CursedBarrel.Shared.TableConfig)
local Utility = H.load(RS.CursedBarrel.Shared.Utility)

local function check(name, cond)
	print((cond and "PASS " or "FAIL ") .. name)
	if not cond then
		H.failed = true
	end
end

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
local function safeSlot(round)
	for _, i in ipairs(round.gameTable:GetFreeSlotIndices()) do
		if not round.dangerSlots[i] and i ~= round.sealed then return i end
	end
end
local function cuesTo(p, id)
	local n = 0
	for _, e in ipairs(H.events) do
		if e.remote == GameConfig.Remotes.SabotageCue and e.to == p and e.args[2] and e.args[2].id == id and e.args[2].mine then n += 1 end
	end
	return n
end

-- A) 무효 판 : 아무도 꽂지 않고 둘이 나가면 남은 사람은 보상 · 판수가 없다
do
	local t = newTable("Trio3")
	local a, b, c = human("A1"), human("B1"), human("C1")
	local coins, games = Profiles:Get(a).coins, Profiles:Get(a).games
	local round = startRound(t, { a, b, c })
	t:RemovePlayer(b)
	t:RemovePlayer(c)
	task.wait(0.3)
	check("A no-contest: winner declared", t.model:GetAttribute(GameConfig.TableAttributes.WinnerUserId) == a.UserId)
	check("A no-contest: WinForfeit shown", t.model:GetAttribute(GameConfig.TableAttributes.WinForfeit) == true)
	check("A no-contest: no coins (" .. coins .. "→" .. Profiles:Get(a).coins .. ")", Profiles:Get(a).coins == coins)
	check("A no-contest: no games", Profiles:Get(a).games == games)
	check("A no-contest: pot carried", (round.carry or 0) > 0)
end

-- B) 기권승 : 모두 한 번씩 꽂은 뒤 상대가 나가면 절반 보상과 판수
do
	local t = newTable("Duo2")
	local a, b = human("A2"), human("B2")
	local coins, games = Profiles:Get(a).coins, Profiles:Get(a).games
	local round = startRound(t, { a, b })
	for _ = 1, 2 do
		local current = round:GetCurrentPlayer()
		round:_resolvePick(current, safeSlot(round), "test")
		H.waitFor(function() return not round.resolving end, 10)
	end
	t:RemovePlayer(b)
	task.wait(0.3)
	check("B forfeit win: coins paid (" .. coins .. "→" .. Profiles:Get(a).coins .. ")", Profiles:Get(a).coins > coins)
	check("B forfeit win: games +1", Profiles:Get(a).games == games + 1)
end

-- C) 방해 예약 : 상대 차례가 아니면 예약 → 상대 차례에 발동 · 중복 거절 · 상대가 나가면 환불
do
	local t = newTable("Standard4")
	local a, b, c = human("A3"), human("B3"), human("C3")
	local round = startRound(t, { a, b, c })
	local actor = round:GetCurrentPlayer()
	local order = round.participants
	local idx = table.find(order, actor)
	local nextP = order[idx % #order + 1]
	local thirdP = order[(idx + 1) % #order + 1]
	local shake = GameConfig.findSabotage("shake")
	local refunds = 0
	local ok, why, queued = round:ApplySabotage(actor, nextP, shake, function() refunds += 1 end)
	check("C queued when not target's turn", ok and queued == true and cuesTo(nextP, "shake") == 0)
	local ok2 = round:ApplySabotage(thirdP, nextP, shake, function() refunds += 1 end)
	check("C duplicate on same target rejected", ok2 == false)
	-- actor 가 안전한 자리를 고르면 nextP 차례가 온다
	round:_resolvePick(actor, safeSlot(round), "test")
	H.waitFor(function() return round:GetCurrentPlayer() == nextP and not round.resolving end, 10)
	check("C fired on target's turn", cuesTo(nextP, "shake") == 1)
	check("C no refund when fired", refunds == 0)
	-- 이번에는 thirdP 에게 예약해 두고 thirdP 가 나간다 → 환불
	local ok3, _, queued3 = round:ApplySabotage(nextP, thirdP, GameConfig.findSabotage("scramble"), function() refunds += 1 end)
	check("C second queued", ok3 and queued3)
	t:RemovePlayer(thirdP)
	task.wait(0.2)
	check("C refund when target leaves", refunds == 1)
	-- 재촉 : 걸린 사람이 탈락하면 환불
	local hurryRefunds = 0
	local current = round:GetCurrentPlayer()
	local other = current == nextP and actor or nextP
	local okH = round:ApplySabotage(current, other, GameConfig.findSabotage("hurry"), function() hurryRefunds += 1 end)
	check("C hurry applied", okH and round.turnCut[other] ~= nil)
	round:_eliminate(other)
	task.wait(0.2)
	check("C hurry refunded on elimination", hurryRefunds == 1)
end

-- D) 잡기 판정 : 늦게 누르고 이른 시각을 보내도 서버가 잰 지연만큼만 인정
do
	local t = newTable("Duo2")
	local a, b = human("A4"), human("B4")
	local round = startRound(t, { a, b })
	local p = round:GetCurrentPlayer()
	local danger
	for i in pairs(round.dangerSlots) do danger = i end
	round:_resolvePick(p, danger, "test")
	local catch = round.catch
	check("D catch started", catch ~= nil and catch.player == p)
	-- 창이 열리고 0.3초 뒤에 누르면서 "열리자마자 눌렀다"고 거짓말
	H.waitFor(function() return os.clock() >= catch.opensAt + 0.3 end, 5)
	local before = #H.events
	round:HandleCatchInput(p, catch.opensAt + 0.001)
	local result
	for i = before + 1, #H.events do
		local e = H.events[i]
		if e.remote == GameConfig.Remotes.CatchResult then result = e.args[2] end
	end
	check("D resolved", result ~= nil)
	local window = catch.window
	-- 인정되는 가장 이른 시각 = 지금 - (0.05 + 0.05) → 정확도는 적어도 (0.3-0.1)/window 만큼 깎인다
	check(("D no free perfect (acc %.2f, window %.2f)"):format(result and result.accuracy or -1, window), result and result.perfect == false)
end

print(H.failed and "SOME TESTS FAILED" or "ALL PASSED")
require("@lune/process").exit(H.failed and 1 or 0)
