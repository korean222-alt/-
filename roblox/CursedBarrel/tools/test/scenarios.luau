--!nocheck
--[[
	scenarios
	사용자가 요청한 Phase 2 점검 항목을 실제로 실행해 본다.

	  1. 1명 참가 후 카운트다운
	  2. 도중에 한 명이 나가면 취소
	  3. 다시 1명이 되면 새 카운트다운 시작
	  4. 게임 시작 후 빈 의자 참가 차단
	  5. 참가자 퇴장 및 캐릭터 리셋
	  6. 테이블을 복제했을 때 독립 진행
]]

--------------------------------------------------
-- 모듈 배치 (실제 게임의 폴더 구조와 같게)
--------------------------------------------------
local rsRoot = Mock.newInstance("Folder", "CursedBarrel")
rsRoot.Parent = Mock.ReplicatedStorage
local shared = Mock.newInstance("Folder", "Shared")
shared.Parent = rsRoot
Mock.mountModule("GameConfig", shared)
Mock.mountModule("TableConfig", shared)
Mock.mountModule("Utility", shared)

local ssRoot = Mock.newInstance("Folder", "CursedBarrel")
ssRoot.Parent = Mock.ServerScriptService
local servicesFolder = Mock.newInstance("Folder", "Services")
servicesFolder.Parent = ssRoot
Mock.mountModule("GameTable", servicesFolder)
Mock.mountModule("TableService", servicesFolder)
Mock.mountModule("RoundService", servicesFolder)

local GameConfig = require(shared.GameConfig)
local TableConfig = require(shared.TableConfig)
local Utility = require(shared.Utility)

--------------------------------------------------
-- 작은 테스트 도구
--------------------------------------------------
local passed, failed = 0, 0
local failures = {}
local print = Mock.realPrint

local function section(title)
	print("")
	print("── " .. title)
end

local function check(label, condition, detail)
	if condition then
		passed += 1
		print(("   [통과] %s"):format(label))
	else
		failed += 1
		table.insert(failures, label)
		print(("   [실패] %s %s"):format(label, detail and ("· " .. tostring(detail)) or ""))
	end
end

local function attr(model, name)
	return model:GetAttribute(name)
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 0.001)
end

--------------------------------------------------
-- 서버 부팅 (Main 과 같은 순서)
--------------------------------------------------
local tableA = Mock.makeTableModel("Table_A", "Standard4", 4)
local tableB = Mock.makeTableModel("Table_B", "Standard4", 4)

local TableService = require(servicesFolder.TableService)
local RoundService = require(servicesFolder.RoundService)

TableService:Start()
RoundService:Start()
Mock.flush()

local seatsA = Mock.seatsOf(tableA)
local seatsB = Mock.seatsOf(tableB)

section("0. 부팅")
check("Table_A 등록", TableService:GetTableById("Table_A") ~= nil)
check("Table_B 등록", TableService:GetTableById("Table_B") ~= nil)
check("초기 상태 Waiting", attr(tableA, "State") == "Waiting")
check("좌석 수 기록 4", attr(tableA, "SeatCount") == 4)
check("MinPlayers 기록 1", attr(tableA, "MinPlayers") == 1)
check("Phase 2 Attribute 자리 생성", attr(tableA, "CountdownEndsAt") == 0 and attr(tableA, "CurrentTurnUserId") == 0)
check("좌석마다 앉기 프롬프트", seatsA[1]:FindFirstChild("SitPrompt") ~= nil)

--------------------------------------------------
section("1. 1명 참가 후 5초 카운트다운")
--------------------------------------------------
local p1 = Mock.makePlayer("플레이어1", 101)

check("1번 자리에 앉음", Mock.pressSit(p1, seatsA[1]) == true)
check("인원 1명 기록", attr(tableA, "SeatedCount") == 1)
check("상태 Countdown", attr(tableA, "State") == "Countdown")

local endsAt = attr(tableA, "CountdownEndsAt")
check("종료 시각 = 지금 + 5초", near(endsAt, Mock.now() + 5), endsAt)
check("카운트다운 길이 5초 기록", attr(tableA, "CountdownDuration") == 5)

Mock.advance(3)
check("3초 경과 · 아직 Countdown", attr(tableA, "State") == "Countdown")
check("현황판이 읽을 남은 시간 = 2초", near(endsAt - Mock.now(), 2))

Mock.advance(2.01)
check("5초 뒤 Playing", attr(tableA, "State") == "Playing")
check("참가자 1명 확정", attr(tableA, "ParticipantCount") == 1)
check("RoundId 1", attr(tableA, "RoundId") == 1)
check("현재 차례 = 플레이어1", attr(tableA, "CurrentTurnUserId") == 101)
check("현재 차례 이름 기록", attr(tableA, "CurrentTurnName") == "플레이어1")
check("턴 1/1", attr(tableA, "TurnIndex") == 1 and attr(tableA, "TurnCount") == 1)
check("좌석에 턴 순서 기록", seatsA[1]:GetAttribute("TurnOrder") == 1)
check("카운트다운 종료 시각 0으로 정리", attr(tableA, "CountdownEndsAt") == 0)

--------------------------------------------------
section("2. 카운트다운 도중 인원이 줄면 즉시 취소")
--------------------------------------------------
Mock.stand(p1)
check("혼자였던 참가자가 나가면 정리", attr(tableA, "State") == "Waiting")
check("참가자 0", attr(tableA, "ParticipantCount") == 0)
check("턴 정보 초기화", attr(tableA, "CurrentTurnUserId") == 0 and attr(tableA, "TurnIndex") == 0)
check("좌석 턴 순서 초기화", seatsA[1]:GetAttribute("TurnOrder") == 0)

Mock.advance(1)
Mock.pressSit(p1, seatsA[1])
check("다시 앉으면 카운트다운", attr(tableA, "State") == "Countdown")

Mock.advance(2)
Mock.stand(p1)
check("도중에 일어나면 즉시 취소 → Waiting", attr(tableA, "State") == "Waiting")
check("남은 시간 0으로 지움", attr(tableA, "CountdownEndsAt") == 0)

Mock.advance(10)
check("취소된 카운트다운이 되살아나지 않음", attr(tableA, "State") == "Waiting")
check("라운드가 시작되지 않음 (RoundId 그대로)", attr(tableA, "RoundId") == 1)

--------------------------------------------------
section("3. 다시 인원이 차면 새 카운트다운")
--------------------------------------------------
Mock.pressSit(p1, seatsA[2])
check("새 카운트다운 시작", attr(tableA, "State") == "Countdown")
local newEndsAt = attr(tableA, "CountdownEndsAt")
check("새 종료 시각 = 지금 + 5초", near(newEndsAt, Mock.now() + 5), newEndsAt)
check("이전 카운트다운 시각과 다름", newEndsAt ~= endsAt)

Mock.advance(5.01)
check("Playing 전환", attr(tableA, "State") == "Playing")
check("RoundId 2", attr(tableA, "RoundId") == 2)
check("2번 자리 참가자로 확정", seatsA[2]:GetAttribute("TurnOrder") == 1)

--------------------------------------------------
section("4. 게임 시작 후 빈 의자 참가 차단")
--------------------------------------------------
local p2 = Mock.makePlayer("플레이어2", 102)

local sat, reason = Mock.pressSit(p2, seatsA[3])
check("앉기 프롬프트가 꺼져 있음", sat == false, reason)
check("빈 의자가 그대로 비어 있음", seatsA[3].Occupant == nil)
check("인원 수 변화 없음", attr(tableA, "SeatedCount") == 1)
check("좌석이 Disabled 로 잠김", seatsA[3].Disabled == true)
check("참가 중인 좌석은 잠그지 않음", seatsA[2].Disabled == false)

-- 익스플로잇: 프롬프트를 무시하고 강제로 앉은 경우
Mock.exploitSit(p2, seatsA[3])
Mock.advance(0.2)
check("서버가 강제 착석을 되돌림", seatsA[3].Occupant == nil)
check("참가자 명단에 끼어들지 못함", attr(tableA, "ParticipantCount") == 1)
check("어느 테이블에도 소속되지 않음", TableService:GetTableOfPlayer(p2) == nil)

--------------------------------------------------
section("5. 턴 순서 · 무작위 배정 · 턴 넘김 (Table_B)")
--------------------------------------------------
local p3 = Mock.makePlayer("플레이어3", 103)
local p4 = Mock.makePlayer("플레이어4", 104)

Mock.pressSit(p3, seatsB[1])
Mock.pressSit(p4, seatsB[2])
check("B 테이블 Countdown", attr(tableB, "State") == "Countdown")
check("A 테이블은 영향 없음 (Playing 유지)", attr(tableA, "State") == "Playing")

Mock.advance(5.01)
check("B 테이블 Playing", attr(tableB, "State") == "Playing")
check("참가자 2명 확정", attr(tableB, "ParticipantCount") == 2)

local orderOne = seatsB[1]:GetAttribute("TurnOrder")
local orderTwo = seatsB[2]:GetAttribute("TurnOrder")
check("두 사람 모두 턴 순서를 받음", orderOne ~= 0 and orderTwo ~= 0)
check("턴 순서가 서로 다름", orderOne ~= orderTwo, ("%s / %s"):format(tostring(orderOne), tostring(orderTwo)))

local firstTurn = attr(tableB, "CurrentTurnUserId")
check("첫 차례는 참가자 중 한 명", firstTurn == 103 or firstTurn == 104, firstTurn)
check("턴 제한시간 기록", attr(tableB, "TurnEndsAt") > Mock.now())

Mock.advance(7.01)
local secondTurn = attr(tableB, "CurrentTurnUserId")
check("제한시간이 지나면 다음 사람 차례", secondTurn ~= firstTurn, secondTurn)
check("턴 번호 2", attr(tableB, "TurnIndex") == 2)

Mock.advance(7.01)
check("한 바퀴 돌면 처음으로", attr(tableB, "CurrentTurnUserId") == firstTurn)
check("턴 번호 1로 복귀", attr(tableB, "TurnIndex") == 1)

--------------------------------------------------
section("6. 참가자 퇴장 · 캐릭터 리셋")
--------------------------------------------------
local warningsBefore = #Mock.warnings
local turnOwnerId = attr(tableB, "CurrentTurnUserId")
local resetTarget = (turnOwnerId == 103) and p3 or p4
local remaining = (turnOwnerId == 103) and p4 or p3

Mock.resetCharacter(resetTarget)
check("캐릭터 리셋한 참가자가 명단에서 빠짐", attr(tableB, "ParticipantCount") == 1)
check("남은 사람이 현재 차례로 이어짐", attr(tableB, "CurrentTurnUserId") == remaining.UserId)
check("게임은 계속 진행", attr(tableB, "State") == "Playing")
check("턴 번호가 인원 범위 안", attr(tableB, "TurnIndex") == 1 and attr(tableB, "TurnCount") == 1)
check("리셋한 사람의 좌석이 비워짐", seatsB[1].Occupant == nil or seatsB[2].Occupant == nil)

Mock.leave(remaining)
check("마지막 참가자가 접속을 끊으면 정리", attr(tableB, "State") == "Waiting")
check("참가자 0", attr(tableB, "ParticipantCount") == 0)
check("현재 차례 비움", attr(tableB, "CurrentTurnUserId") == 0)
check("좌석 전부 비워짐", seatsB[1].Occupant == nil and seatsB[2].Occupant == nil)
check("좌석 턴 순서 초기화", seatsB[1]:GetAttribute("TurnOrder") == 0 and seatsB[2]:GetAttribute("TurnOrder") == 0)
check("퇴장/리셋 처리 중 경고 없음", #Mock.warnings == warningsBefore, table.concat(Mock.warnings, " | "))

--------------------------------------------------
section("7. MinPlayers 를 2로 둔 테이블 (출시 설정 검증)")
--------------------------------------------------
TableConfig.Types.Duo2.MinPlayers = 2 -- 출시할 때처럼 "2명 미만이면 취소"

local duo = Mock.makeTableModel("Table_Duo", "Duo2", 2) -- 게임 도중에 새로 놓은 테이블
Mock.flush()
check("런타임에 추가한 테이블이 자동 등록됨", TableService:GetTableById("Table_Duo") ~= nil)
check("MinPlayers 2 기록", attr(duo, "MinPlayers") == 2)

local seatsD = Mock.seatsOf(duo)
local p5 = Mock.makePlayer("플레이어5", 105)
local p6 = Mock.makePlayer("플레이어6", 106)

Mock.pressSit(p5, seatsD[1])
check("1명만으로는 카운트다운하지 않음", attr(duo, "State") == "Waiting")

Mock.pressSit(p6, seatsD[2])
check("2명이 모이면 카운트다운", attr(duo, "State") == "Countdown")

Mock.advance(2)
Mock.stand(p6)
check("2명 미만으로 줄면 즉시 취소", attr(duo, "State") == "Waiting")
check("남은 시간 지움", attr(duo, "CountdownEndsAt") == 0)

Mock.advance(10)
check("취소 뒤 자동으로 시작되지 않음", attr(duo, "State") == "Waiting")

Mock.pressSit(p6, seatsD[2])
check("다시 2명이 되면 새 카운트다운", attr(duo, "State") == "Countdown")

Mock.advance(5.01)
check("Playing 전환", attr(duo, "State") == "Playing")
check("참가자 2명", attr(duo, "ParticipantCount") == 2)

Mock.stand(p5)
check("최소 인원 미만이 되면 라운드를 정리", attr(duo, "State") == "Waiting")
check("참가자 명단 초기화", attr(duo, "ParticipantCount") == 0)
check("남아 있는 1명으로는 다시 시작하지 않음", attr(duo, "CountdownEndsAt") == 0)

Mock.advance(1)
Mock.pressSit(p5, seatsD[1])
check("다시 2명이 되면 새 카운트다운", attr(duo, "State") == "Countdown")

--------------------------------------------------
section("8. 테이블 복제 · 독립 진행")
--------------------------------------------------
-- Duo 의 카운트다운이 1.5초 흐른 시점에 복제본을 놓는다.
-- 두 테이블의 카운트다운이 서로 다른 시각에 끝나는지 보기 위해서다.
Mock.advance(1.5)

local clone = Mock.makeTableModel("Table_A", "Standard4", 4) -- TableId 가 겹치는 복제본
Mock.flush()
check("복제본도 자동 등록", TableService:GetTableFromModel(clone) ~= nil)
check("겹친 TableId 를 자동으로 고유하게 바꿈", attr(clone, "TableId") ~= "Table_A", attr(clone, "TableId"))
check("원본 Table_A 는 그대로", TableService:GetTableById("Table_A") ~= nil)

local p7 = Mock.makePlayer("플레이어7", 107)
Mock.pressSit(p7, Mock.seatsOf(clone)[1])
check("복제본만 Countdown", attr(clone, "State") == "Countdown")
check("원본 A 는 Playing 유지", attr(tableA, "State") == "Playing")
check("B 는 Waiting 유지", attr(tableB, "State") == "Waiting")
check("Duo 는 Countdown 유지", attr(duo, "State") == "Countdown")

local cloneEndsAt = attr(clone, "CountdownEndsAt")
local duoEndsAt = attr(duo, "CountdownEndsAt")
check("테이블마다 카운트다운이 따로 흐름 (종료 시각 1.5초 차이)",
	near(cloneEndsAt - duoEndsAt, 1.5), ("%s / %s"):format(tostring(cloneEndsAt), tostring(duoEndsAt)))

Mock.advance(5.01)
check("복제본 Playing", attr(clone, "State") == "Playing")
check("Duo 도 제 시간표대로 Playing", attr(duo, "State") == "Playing")
check("복제본 RoundId 1 (원본과 별개)", attr(clone, "RoundId") == 1 and attr(tableA, "RoundId") == 2)
check("Duo 는 두 번째 라운드", attr(duo, "RoundId") == 2)
check("원본 A 의 턴 정보는 건드려지지 않음", attr(tableA, "CurrentTurnUserId") == 101)

--------------------------------------------------
section("9. 테이블 제거 시 정리")
--------------------------------------------------
local warningsBeforeRemoval = #Mock.warnings
Mock.CollectionService:RemoveTag(clone, "CursedBarrel_Table")
Mock.flush()
check("태그를 떼면 등록 해제", TableService:GetTableFromModel(clone) == nil)
check("앉아 있던 사람도 정리", Mock.seatsOf(clone)[1].Occupant == nil)

local doomed = Mock.makeTableModel("Table_Doomed", "Standard4", 4)
Mock.flush()
check("임시 테이블 등록", TableService:GetTableById("Table_Doomed") ~= nil)
doomed:Destroy()
Mock.flush()
check("모델을 지우면 등록 해제", TableService:GetTableById("Table_Doomed") == nil)
check("정리 중 경고 없음", #Mock.warnings == warningsBeforeRemoval, table.concat(Mock.warnings, " | "))

--------------------------------------------------
section("10. 턴 순서 무작위성")
--------------------------------------------------
local firstCounts = {}
local random = Random.new()
for _ = 1, 400 do
	local deck = { "A", "B", "C", "D" }
	Utility.shuffle(deck, random)
	firstCounts[deck[1]] = (firstCounts[deck[1]] or 0) + 1
end

local distinct, minCount = 0, math.huge
for _, count in pairs(firstCounts) do
	distinct += 1
	minCount = math.min(minCount, count)
end
check("4명 모두 첫 순서가 될 수 있음", distinct == 4, distinct)
check("특정인에게 쏠리지 않음 (각 50회 이상)", minCount >= 50, minCount)

--------------------------------------------------
-- 결과
--------------------------------------------------
print("")
print(("══ 통과 %d · 실패 %d"):format(passed, failed))
if failed > 0 then
	print("")
	print("실패 목록:")
	for _, label in ipairs(failures) do
		print("  - " .. label)
	end
	print("")
	print("마지막 서버 로그:")
	for index = math.max(1, #Mock.logs - 25), #Mock.logs do
		print("  " .. Mock.logs[index])
	end
	error("테스트 실패")
end

if #Mock.warnings > 0 then
	print("")
	print(("경고 %d건:"):format(#Mock.warnings))
	for _, message in ipairs(Mock.warnings) do
		print("  " .. message)
	end
end
