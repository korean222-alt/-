--[[
	round_test.lua
	해적 잡기 규칙을 흉내 환경에서 끝까지 돌려 본다.

	실행:  luau tests/round_test.lua      (tests 폴더 안에서)

	여기서 확인하는 것
	  1. 제보해 주신 버그 — 잡고 나면 그 판이 끝날 때까지 해적이 안 나오던 문제
	  2. 잡으면 "아직 칼이 안 꽂힌 자리"에 해적이 새로 숨는가
	  3. 6인 테이블은 해적이 두 마리인가
	  4. 어떤 경로로 해적이 사라져도 다음 턴에 복구되는가
	  5. 위험한 자리 번호가 Attribute 나 RemoteEvent 로 새어 나가지 않는가
	  6. 미리 두들기기 · 늦은 입력 · 미래 시각 위조가 막히는가
]]

local Loader = require("./loader")
local loader = Loader.new()
local env = loader.env
local scheduler = loader.stub.scheduler
local newInstance = loader.stub.newInstance

--------------------------------------------------
-- 검사 도구
--------------------------------------------------
local passed, failed = 0, 0
local function check(condition, description)
	if condition then
		passed += 1
		print(("  ✓ %s"):format(description))
	else
		failed += 1
		print(("  ✗ %s"):format(description))
	end
end
local function section(title)
	print("")
	print(title)
end

--------------------------------------------------
-- ReplicatedStorage 트리 세우기
--------------------------------------------------
local ReplicatedStorage = env.game:GetService("ReplicatedStorage")
local Players = env.game:GetService("Players")

local function folder(name, parent)
	local instance = newInstance("Folder")
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function moduleScript(name, parent, source)
	local instance = newInstance("ModuleScript")
	instance.Name = name
	instance.__source = source
	instance.Parent = parent
	return instance
end

local package = folder("CursedBarrel", ReplicatedStorage)
local shared = folder("Shared", package)
moduleScript("GameConfig", shared, "../game/ReplicatedStorage/CursedBarrel/Shared/GameConfig.lua")
moduleScript("TableConfig", shared, "../game/ReplicatedStorage/CursedBarrel/Shared/TableConfig.lua")
moduleScript("Utility", shared, "../game/ReplicatedStorage/CursedBarrel/Shared/Utility.lua")
moduleScript("SkinFX", shared, "../game/ReplicatedStorage/CursedBarrel/Shared/SkinFX.lua")

local remotes = folder("Remotes", package)
env.Instance.new("RemoteEvent", remotes).Name = "PresentationCue"
env.Instance.new("RemoteEvent", remotes).Name = "SelectSlot"

local services = folder("Services", nil)
moduleScript("TableService", services, "./doubles/TableService.lua")
moduleScript("RankingService", services, "./doubles/RankingService.lua")
moduleScript("ProfileService", services, "./doubles/ProfileService.lua")
local roundModule = moduleScript("RoundService", services, "../game/ServerScriptService/CursedBarrel/Services/RoundService.lua")

local GameConfig = env.require(shared:FindFirstChild("GameConfig"))
local TableConfig = env.require(shared:FindFirstChild("TableConfig"))
local Utility = env.require(shared:FindFirstChild("Utility"))
local TableServiceDouble = env.require(services:FindFirstChild("TableService"))
local RoundService = env.require(roundModule)

local TABLE_ATTR = GameConfig.TableAttributes
local SLOT_ATTR = GameConfig.SlotAttributes

--------------------------------------------------
-- 가짜 플레이어 / 가짜 테이블
--------------------------------------------------
local nextUserId = 100
local function makePlayer(name)
	nextUserId += 1
	local player = newInstance("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = nextUserId
	player.Parent = Players
	table.insert(Players._players, player)
	return player
end

local FakeTable = {}
FakeTable.__index = FakeTable

local function makeTable(tableId, typeName)
	local self = setmetatable({}, FakeTable)
	self.model = newInstance("Model")
	self.model.Name = tableId
	self.tableId = tableId
	self.typeName = typeName
	self.config = TableConfig.get(typeName)
	self.state = GameConfig.States.Waiting
	self.destroyed = false

	self.cleaner = Utility.Cleaner.new()
	self.RosterChanged = Utility.Signal.new()
	self.SlotTriggered = Utility.Signal.new()

	self.seats = {}
	self.playerOfSeat = {}
	self.seatOfPlayer = {}
	for index = 1, self.config.SeatCount do
		local seat = newInstance("Seat")
		seat.Name = ("Seat_%02d"):format(index)
		seat:SetAttribute(GameConfig.SeatAttributes.SeatIndex, index)
		table.insert(self.seats, seat)
	end

	self.slots = {}
	for index = 1, TableConfig.getSlotCount(typeName) do
		local slot = newInstance("Part")
		slot.Name = ("Slot_%02d"):format(index)
		slot:SetAttribute(SLOT_ATTR.SlotIndex, index)
		slot:SetAttribute(SLOT_ATTR.Used, false)
		self.slots[index] = slot
	end

	self.barrelResets = 0
	self.dangerEffects = 0
	return self
end

function FakeTable:SetTableAttribute(name, value)
	self.model:SetAttribute(name, value)
	return true
end
function FakeTable:GetMinPlayers()
	return math.max(1, math.min(tonumber(self.config.MinPlayers) or 1, #self.seats))
end
function FakeTable:GetSeats()
	return self.seats
end
function FakeTable:GetPlayerOfSeat(seat)
	return self.playerOfSeat[seat]
end
function FakeTable:GetPlayers()
	local list = {}
	for _, seat in ipairs(self.seats) do
		if self.playerOfSeat[seat] then
			table.insert(list, self.playerOfSeat[seat])
		end
	end
	return list
end
function FakeTable:GetPlayerCount()
	return #self:GetPlayers()
end
function FakeTable:HasPlayer(player)
	return self.seatOfPlayer[player] ~= nil
end
function FakeTable:Seat(player)
	for _, seat in ipairs(self.seats) do
		if not self.playerOfSeat[seat] then
			self.playerOfSeat[seat] = player
			self.seatOfPlayer[player] = seat
			self.RosterChanged:Fire(self, player, true)
			return seat
		end
	end
	return nil
end
function FakeTable:RemovePlayer(player)
	local seat = self.seatOfPlayer[player]
	if not seat then
		return false
	end
	self.playerOfSeat[seat] = nil
	self.seatOfPlayer[player] = nil
	self.RosterChanged:Fire(self, player, false)
	return true
end
function FakeTable:GetSlotCount()
	return #self.slots
end
function FakeTable:GetSlot(index)
	return self.slots[index]
end
function FakeTable:IsSlotUsed(index)
	local slot = self.slots[index]
	return slot ~= nil and slot:GetAttribute(SLOT_ATTR.Used) == true
end
function FakeTable:GetFreeSlotIndices()
	local free = {}
	for index, slot in ipairs(self.slots) do
		if slot:GetAttribute(SLOT_ATTR.Used) ~= true then
			table.insert(free, index)
		end
	end
	return free
end
function FakeTable:MarkSlotUsed(index, player)
	local slot = self.slots[index]
	if slot then
		slot:SetAttribute(SLOT_ATTR.Used, true)
		slot:SetAttribute(SLOT_ATTR.UsedByUserId, player and player.UserId or 0)
	end
	return true
end
function FakeTable:ResetSlots()
	for _, slot in ipairs(self.slots) do
		slot:SetAttribute(SLOT_ATTR.Used, false)
		slot:SetAttribute(SLOT_ATTR.UsedByUserId, 0)
	end
	self.barrelResets += 1
end
function FakeTable:ResetBarrelLook() end
function FakeTable:RefreshBarrelSkin() end
function FakeTable:PlayDangerEffect()
	self.dangerEffects += 1
end
function FakeTable:SetSeatAlive() end
function FakeTable:ClearSeatFlags() end
function FakeTable:SetState(newState)
	self.state = newState
	self.model:SetAttribute(TABLE_ATTR.State, newState)
end

--------------------------------------------------
-- 서비스 켜기
--------------------------------------------------
RoundService:Start()

local function attach(gameTable)
	TableServiceDouble:Register(gameTable)
	return RoundService:GetRound(gameTable)
end

-- 라운드가 실제로 시작될 때까지 시계를 민다.
local function startRound(gameTable)
	scheduler.step(gameTable.config.CountdownDuration + GameConfig.Timing.StartingDuration + 0.2)
end

local function liveDangerCount(round, gameTable)
	local count = 0
	for slotIndex in pairs(round.dangerSlots) do
		if not gameTable:IsSlotUsed(slotIndex) then
			count += 1
		end
	end
	return count
end

local function firstLiveDanger(round, gameTable)
	for slotIndex in pairs(round.dangerSlots) do
		if not gameTable:IsSlotUsed(slotIndex) then
			return slotIndex
		end
	end
	return nil
end

local function firstSafeFree(round, gameTable)
	for _, slotIndex in ipairs(gameTable:GetFreeSlotIndices()) do
		if not round.dangerSlots[slotIndex] then
			return slotIndex
		end
	end
	return nil
end

--------------------------------------------------
-- 1) 제보된 버그: 잡은 뒤에도 해적이 계속 나오는가
--------------------------------------------------
section("1. 잡은 뒤에도 해적이 다시 나오는가 (제보된 버그)")

local alice = makePlayer("Alice")
local bob = makePlayer("Bob")
local tableA = makeTable("Table_A", "Standard4")
local roundA = attach(tableA)

tableA:Seat(alice)
tableA:Seat(bob)
startRound(tableA)

check(tableA.state == GameConfig.States.Playing, "두 명이 앉으면 라운드가 시작된다")
check(liveDangerCount(roundA, tableA) == 1, "4인 테이블은 해적이 한 마리로 시작한다")
check(tableA.model:GetAttribute(TABLE_ATTR.PirateCount) == 1, "해적 마릿수가 현황판에 나간다")

-- 지금 차례인 사람이 위험한 자리를 뽑는다
local danger = firstLiveDanger(roundA, tableA)
local current = roundA:GetCurrentPlayer()
roundA:HandlePick(current, danger, "test")

check(roundA.catch ~= nil, "위험한 자리를 뽑으면 잡기가 열린다")
check(liveDangerCount(roundA, tableA) == 0, "밟은 해적은 통에서 사라진다")

-- 창이 열린 뒤 제때 누른다
scheduler.step(GameConfig.Catch.Lead + 0.05)
roundA:HandleCatchInput(current, scheduler.now())

check(roundA.catchCount == 1, "제때 누르면 잡기에 성공한다")
check(liveDangerCount(roundA, tableA) == 1, "★ 잡으면 해적이 하나 새로 숨는다 (버그 수정)")

local newDanger = firstLiveDanger(roundA, tableA)
check(newDanger ~= nil and not tableA:IsSlotUsed(newDanger), "★ 새 해적은 아직 칼이 안 꽂힌 자리에 숨는다")
check(newDanger ~= danger, "이미 칼이 꽂힌 그 자리에 다시 숨지 않는다")
check(tableA.model:GetAttribute(TABLE_ATTR.PirateCount) == 1, "현황판의 마릿수도 따라 올라간다")

-- 통을 새로 채우지 않았는지 확인 (이어서 계속되어야 한다)
local resetsBefore = tableA.barrelResets
scheduler.step(GameConfig.Catch.Hold + 0.2)
check(tableA.barrelResets == resetsBefore, "잡기에 성공해도 통을 새로 채우지 않는다")
check(tableA.state == GameConfig.States.Playing, "판이 그대로 이어진다")

-- 계속 뽑아 보면 해적을 다시 만난다
local metAgain = false
for _ = 1, 30 do
	if tableA.state ~= GameConfig.States.Playing then
		break
	end
	local player = roundA:GetCurrentPlayer()
	if not player then
		break
	end
	local live = firstLiveDanger(roundA, tableA)
	local target = live or firstSafeFree(roundA, tableA)
	if not target then
		break
	end
	roundA:HandlePick(player, target, "test")
	if roundA.catch then
		metAgain = true
		break
	end
	scheduler.step(GameConfig.Timing.ResultHold + 0.2)
end
check(metAgain, "★ 잡은 뒤에도 해적을 다시 만난다 (예전에는 판이 끝날 때까지 안 나왔다)")

--------------------------------------------------
-- 2) 해적을 놓치면 탈락한다
--------------------------------------------------
section("2. 놓치면 탈락한다")

local catchPlayer = roundA.catch and roundA.catch.player
-- 창이 완전히 닫히고 봐주는 시간(Grace)까지 지난 뒤에 누른다.
-- 서버가 스스로 실패로 확정하는 시각(Lead + 창 + Timeout)보다는 앞이어야
-- "늦게 누른 것"이 실패로 처리되는지를 볼 수 있다.
scheduler.step(GameConfig.Catch.Lead + GameConfig.Catch.BaseWindow + GameConfig.Catch.Grace + 0.6)
roundA:HandleCatchInput(catchPlayer, scheduler.now())
check(roundA.catch == nil, "늦게 누르면 잡기가 실패로 닫힌다")

-- 탈락 연출이 끝나는 순간을 본다. 더 지나면 테이블이 스스로 초기화되고
-- 아직 앉아 있는 승자 때문에 다음 판이 바로 시작된다.
scheduler.step(GameConfig.Timing.ResultHold + 0.3)
check(tableA.state == GameConfig.States.RoundEnding, "탈락자가 나오면 라운드가 끝난다")
check(tableA.model:GetAttribute(TABLE_ATTR.WinnerUserId) ~= 0, "남은 한 명이 승자가 된다")
check(tableA.model:GetAttribute(TABLE_ATTR.WinnerUserId) ~= catchPlayer.UserId, "놓친 사람은 승자가 아니다")

-- 초기화되고, 남아 있는 사람으로 다음 판이 알아서 시작된다
scheduler.step(GameConfig.Timing.RoundEndDuration + GameConfig.Timing.ResetDuration + 0.3)
check(tableA.model:GetAttribute(TABLE_ATTR.WinnerUserId) == 0, "초기화되면 승자 표시가 지워진다")

--------------------------------------------------
-- 3) 6인 테이블은 해적이 두 마리
--------------------------------------------------
section("3. 6인 테이블은 해적이 두 마리")

local party = makeTable("Table_G", "Party6")
local roundP = attach(party)
local partyPlayers = {}
for index = 1, 6 do
	partyPlayers[index] = makePlayer("Party" .. index)
	party:Seat(partyPlayers[index])
end
startRound(party)

check(party.state == GameConfig.States.Playing, "6인 테이블도 라운드가 시작된다")
check(liveDangerCount(roundP, party) == 2, "★ 6인 테이블은 해적이 두 마리")
check(party.model:GetAttribute(TABLE_ATTR.PirateCount) == 2, "두 마리라는 사실이 현황판에 나간다")
check(TableConfig.getDangerCount("Party6", 6) == 2, "좌석 수로 계산해도 두 마리")
check(TableConfig.getDangerCount("Standard4", 4) == 1, "4인 테이블은 한 마리")
check(TableConfig.getDangerCount("Duo2", 2) == 1, "2인 테이블은 한 마리")

-- 한 마리를 잡아도 정원(2)이 유지된다
local partyCurrent = roundP:GetCurrentPlayer()
roundP:HandlePick(partyCurrent, firstLiveDanger(roundP, party), "test")
scheduler.step(GameConfig.Catch.Lead + 0.05)
roundP:HandleCatchInput(partyCurrent, scheduler.now())
check(liveDangerCount(roundP, party) == 2, "★ 6인 테이블은 잡은 뒤에도 두 마리를 유지한다")

--------------------------------------------------
-- 4) 어떤 경로로 해적이 사라져도 복구된다
--------------------------------------------------
section("4. 해적이 사라져도 다음 턴에 복구된다")

scheduler.step(GameConfig.Catch.Hold + 0.3)
table.clear(roundP.dangerSlots) -- 일부러 전부 지운다
check(liveDangerCount(roundP, party) == 0, "일부러 해적을 전부 지웠다")
roundP:_beginTurn(roundP.turnIndex + 1)
check(liveDangerCount(roundP, party) == 2, "★ 턴을 시작할 때 정원만큼 다시 채워진다 (안전망)")

--------------------------------------------------
-- 5) 위험한 자리가 새어 나가지 않는가
--------------------------------------------------
section("5. 위험한 자리 번호가 밖으로 나가지 않는가")

local liveSlots = {}
for slotIndex in pairs(roundP.dangerSlots) do
	if not party:IsSlotUsed(slotIndex) then
		liveSlots[slotIndex] = true
	end
end

-- 진짜로 위험한 것은 "슬롯 파트를 들여다보면 구분이 되는가" 다.
-- 클라이언트는 슬롯 파트의 Attribute 를 전부 읽을 수 있다.
-- 해적이 숨은 슬롯과 그냥 빈 슬롯이 똑같아 보여야 한다.
-- SlotIndex 는 어차피 자리마다 다른 공개 번호다. 그것 말고 상태 값만 본다.
local function attributeShape(slot)
	local keys = {}
	for _, name in pairs(SLOT_ATTR) do
		if name ~= SLOT_ATTR.SlotIndex then
			table.insert(keys, ("%s=%s"):format(name, tostring(slot:GetAttribute(name))))
		end
	end
	table.sort(keys)
	return table.concat(keys, "|")
end

local dangerShapes, safeShapes = {}, {}
for _, slotIndex in ipairs(party:GetFreeSlotIndices()) do
	local shape = attributeShape(party.slots[slotIndex])
	if liveSlots[slotIndex] then
		dangerShapes[shape] = true
	else
		safeShapes[shape] = true
	end
end

local distinguishable = false
for shape in pairs(dangerShapes) do
	if not safeShapes[shape] then
		distinguishable = true
		print(("      해적이 숨은 슬롯만 가진 모습: %s"):format(shape))
	end
end
check(not distinguishable, "해적이 숨은 슬롯과 빈 슬롯이 Attribute 로 구분되지 않는다")

-- 테이블 Attribute 에는 마릿수만 나간다. 자리 번호를 담는 칸은 LastPickSlot 하나뿐이고
-- 그 값은 "방금 모두가 본 선택"이라 이미 공개된 정보다.
check(party.model:GetAttribute(TABLE_ATTR.PirateCount) == #(function()
		local list = {}
		for index in pairs(liveSlots) do
			table.insert(list, index)
		end
		return list
	end)(), "테이블 Attribute 로 나가는 것은 마릿수까지다")

local promptRemote = remotes:FindFirstChild(GameConfig.Remotes.CatchPrompt)
local promptLeak = false
for _, entry in ipairs(promptRemote and promptRemote.sent or {}) do
	local payload = entry.args[2]
	if type(payload) == "table" then
		for key, value in pairs(payload) do
			-- slot 은 "방금 내가 뽑은 자리"라서 이미 모두가 아는 값이다.
			if key ~= "slot" and type(value) == "number" and liveSlots[value] then
				promptLeak = true
			end
		end
	end
end
check(not promptLeak, "CatchPrompt 에도 숨은 해적의 자리가 실리지 않는다")

--------------------------------------------------
-- 6) 부정행위 방어
--------------------------------------------------
section("6. 미리 두들기기 · 늦은 입력 · 미래 시각 위조")

local cheatTable = makeTable("Table_C", "Standard4")
local cheatRound = attach(cheatTable)
local carol = makePlayer("Carol")
local dave = makePlayer("Dave")
cheatTable:Seat(carol)
cheatTable:Seat(dave)
startRound(cheatTable)

local cheater = cheatRound:GetCurrentPlayer()
cheatRound:HandlePick(cheater, firstLiveDanger(cheatRound, cheatTable), "test")
check(cheatRound.catch ~= nil, "잡기가 열렸다")

-- 창이 열리기 전에 세 번 두들긴다
cheatRound:HandleCatchInput(cheater, scheduler.now())
check(cheatRound.catch ~= nil, "한 번은 봐준다")
cheatRound:HandleCatchInput(cheater, scheduler.now())
check(cheatRound.catch ~= nil, "두 번도 봐준다")
cheatRound:HandleCatchInput(cheater, scheduler.now())
check(cheatRound.catch == nil, "★ 세 번 두들기면 그 자리에서 실패")

-- 미래 시각 위조
local forgeTable = makeTable("Table_F", "Standard4")
local forgeRound = attach(forgeTable)
local erin = makePlayer("Erin")
local frank = makePlayer("Frank")
forgeTable:Seat(erin)
forgeTable:Seat(frank)
startRound(forgeTable)

local forger = forgeRound:GetCurrentPlayer()
forgeRound:HandlePick(forger, firstLiveDanger(forgeRound, forgeTable), "test")
-- 창이 열리기 한참 전인데 "창이 열린 뒤에 눌렀다"고 미래 시각을 보낸다
forgeRound:HandleCatchInput(forger, scheduler.now() + 999)
check(forgeRound.catch ~= nil and forgeRound.catchCount == 0,
	"★ 미래 시각을 보내도 지금으로 깎여 성공으로 인정되지 않는다")

-- 응답이 없으면 서버가 실패로 확정한다
scheduler.step(GameConfig.Catch.Lead + GameConfig.Catch.BaseWindow + GameConfig.Catch.Timeout + 0.5)
check(forgeRound.catch == nil, "★ 응답이 없어도 서버가 시간이 지나면 끝을 낸다")

--------------------------------------------------
print("")
print(("결과: %d개 통과, %d개 실패"):format(passed, failed))
if failed > 0 then
	error(("테스트 %d개 실패"):format(failed), 0)
end
