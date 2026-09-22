--[[
	config_test.lua
	설정표가 스스로 모순되지 않는지 확인한다.

	실행:  luau tests/config_test.lua   (tests 폴더 안에서)

	확인하는 것
	  1. 통 스킨 우선순위 규칙 (희귀도 → 레벨 → 연승 → 먼저 앉은 순서)
	  2. 테이블 종류별 해적 수
	  3. 레벨 곡선
	  4. 스킨 목록이 성한가 (id 중복 · 등급 오타 · 기본 지급품)
	  5. 방해 아이템이 "산 사람에게 유리한 것"을 팔지 않는가
	  6. 퀘스트와 업적이 실제로 세는 통계를 보는가
]]

local Loader = require("./loader")
local loader = Loader.new()
local env = loader.env
local newInstance = loader.stub.newInstance

local ReplicatedStorage = env.game:GetService("ReplicatedStorage")
local function folder(name, parent)
	local instance = newInstance("Folder")
	instance.Name = name
	instance.Parent = parent
	return instance
end
local function moduleScript(name, parent)
	local instance = newInstance("ModuleScript")
	instance.Name = name
	instance.Parent = parent
	return instance
end

local package = folder("CursedBarrel", ReplicatedStorage)
local shared = folder("Shared", package)
moduleScript("GameConfig", shared)
moduleScript("TableConfig", shared)
moduleScript("Utility", shared)

local GameConfig = env.require(shared:FindFirstChild("GameConfig"))
local TableConfig = env.require(shared:FindFirstChild("TableConfig"))

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

local function skinById(kind, id)
	local skin = GameConfig.findSkin(kind, id)
	assert(skin and skin.id == id, ("%s/%s 를 찾지 못했습니다"):format(kind, id))
	return skin
end

--------------------------------------------------
section("1. 통 스킨 우선순위 — 한 테이블에 통은 하나뿐이다")
--------------------------------------------------
local oak = skinById("Barrel", "oak") -- 기본
local treasure = skinById("Barrel", "treasure") -- 희귀
local volcano = skinById("Barrel", "volcano") -- 영웅
local abyss = skinById("Barrel", "abyss") -- 전설

local function wins(a, b)
	return GameConfig.barrelSkinScore(a.skin, a.level, a.streak, a.seat)
		> GameConfig.barrelSkinScore(b.skin, b.level, b.streak, b.seat)
end

check(wins(
	{ skin = abyss, level = 1, streak = 0, seat = 4 },
	{ skin = oak, level = 99, streak = 20, seat = 1 }
), "전설 통을 낀 새 사람이 기본 통을 낀 고인물을 이긴다 (상점이 의미를 갖는다)")

check(wins(
	{ skin = treasure, level = 5, streak = 0, seat = 3 },
	{ skin = oak, level = 80, streak = 9, seat = 1 }
), "희귀 통이 기본 통을 이긴다")

check(wins(
	{ skin = abyss, level = 3, streak = 0, seat = 2 },
	{ skin = volcano, level = 60, streak = 5, seat = 1 }
), "전설이 영웅을 이긴다")

check(wins(
	{ skin = abyss, level = 40, streak = 0, seat = 3 },
	{ skin = abyss, level = 12, streak = 9, seat = 1 }
), "같은 등급이면 레벨이 높은 사람 것이 보인다 (요청하신 규칙)")

check(wins(
	{ skin = treasure, level = 20, streak = 6, seat = 4 },
	{ skin = treasure, level = 20, streak = 1, seat = 1 }
), "등급도 레벨도 같으면 지금 연승이 높은 사람 것이 보인다")

check(wins(
	{ skin = treasure, level = 20, streak = 3, seat = 1 },
	{ skin = treasure, level = 20, streak = 3, seat = 2 }
), "전부 같으면 먼저 앉은 사람 것이 보인다")

-- 같은 상황이면 언제나 같은 결과가 나와야 한다. (통이 깜빡이면 안 된다)
local first = GameConfig.barrelSkinScore(treasure, 20, 3, 2)
local second = GameConfig.barrelSkinScore(treasure, 20, 3, 2)
check(first == second, "같은 상황에서는 언제나 같은 결과가 나온다")

--------------------------------------------------
section("2. 테이블 종류별 해적 수")
--------------------------------------------------
check(TableConfig.getDangerCount("Duo2", 2) == 1, "2인 테이블 · 해적 1마리")
check(TableConfig.getDangerCount("Standard4", 4) == 1, "4인 테이블 · 해적 1마리")
check(TableConfig.getDangerCount("Party6", 6) == 2, "★ 6인 테이블 · 해적 2마리")
check(TableConfig.getDangerCount("Blitz4", 4) == 1, "빠른 테이블 · 해적 1마리")
check(TableConfig.dangerForSeats(9) == 3, "좌석 9개짜리를 만들면 3마리로 늘어난다")

for name in pairs(TableConfig.Types) do
	local slots = TableConfig.getSlotCount(name)
	local danger = TableConfig.getDangerCount(name)
	check(danger < slots, ("%s · 해적 수(%d)가 칼 자리(%d)보다 적다"):format(name, danger, slots))
end

check(GameConfig.TableTypeByName.Table_G == "Party6", "맵의 Table_G 가 6인 테이블로 배정된다")
check(GameConfig.TableTypeByName.Table_H == "Party6", "맵의 Table_H 가 6인 테이블로 배정된다")
for modelName, typeName in pairs(GameConfig.TableTypeByName) do
	check(TableConfig.Types[typeName] ~= nil, ("%s 에 배정한 '%s' 가 실제로 있는 종류다"):format(modelName, typeName))
end

--------------------------------------------------
section("3. 레벨 곡선")
--------------------------------------------------
check(GameConfig.levelOf(0, 0) == 1, "처음에는 1레벨")
local previous = 0
local rising = true
for games = 0, 400, 20 do
	local level = GameConfig.levelOf(math.floor(games / 4), games)
	if level < previous then
		rising = false
	end
	previous = level
end
check(rising, "판수가 늘면 레벨이 내려가지 않는다")
check(GameConfig.levelOf(10, 40) > GameConfig.levelOf(0, 40), "같은 판수라면 이긴 쪽이 레벨이 높다")
check(GameConfig.levelOf(0, 400) - GameConfig.levelOf(0, 200) < GameConfig.levelOf(0, 200) - GameConfig.levelOf(0, 0),
	"뒤로 갈수록 천천히 오른다")

--------------------------------------------------
section("4. 스킨 목록이 성한가")
--------------------------------------------------
for _, kind in ipairs({ "Knife", "Barrel", "Ghost" }) do
	local seen = {}
	local duplicate, badRarity, freeCount = nil, nil, 0
	for _, skin in ipairs(GameConfig.Skins[kind]) do
		if seen[skin.id] then
			duplicate = skin.id
		end
		seen[skin.id] = true
		if not GameConfig.Rarity[skin.rarity or "common"] then
			badRarity = skin.id
		end
		if GameConfig.isFreeSkin(skin) then
			freeCount += 1
		end
	end
	check(duplicate == nil, ("%s 스킨 id 가 겹치지 않는다"):format(kind))
	check(badRarity == nil, ("%s 스킨 등급에 오타가 없다"):format(kind))
	check(freeCount >= 1, ("%s 는 처음부터 쓸 수 있는 스킨이 하나 이상 있다"):format(kind))
	check(GameConfig.isFreeSkin(GameConfig.Skins[kind][1]), ("%s 의 첫 번째가 기본 지급품이다"):format(kind))
end

-- 로벅스 전용 스킨은 코인 가격이 없어야 한다. (둘 다 있으면 코인으로 싸게 사 버린다)
local mixedUp = nil
for _, kind in ipairs({ "Knife", "Barrel", "Ghost" }) do
	for _, skin in ipairs(GameConfig.Skins[kind]) do
		if skin.robux and (tonumber(skin.price) or 0) > 0 then
			mixedUp = kind .. "/" .. skin.id
		end
	end
end
check(mixedUp == nil, "로벅스 전용 스킨에 코인 가격이 같이 붙어 있지 않다")

-- 비싼 스킨일수록 등급이 높아야 한다
local priceByRank = {}
for _, kind in ipairs({ "Knife", "Barrel", "Ghost" }) do
	for _, skin in ipairs(GameConfig.Skins[kind]) do
		local rank = GameConfig.rarityOf(skin).rank
		local price = tonumber(skin.price) or 0
		if price > 0 then
			priceByRank[rank] = math.min(priceByRank[rank] or math.huge, price)
		end
	end
end
local ordered = true
for rank = 2, 4 do
	if priceByRank[rank] and priceByRank[rank - 1] and priceByRank[rank] < priceByRank[rank - 1] then
		ordered = false
	end
end
check(ordered, "등급이 높을수록 값이 싸지 않다")

--------------------------------------------------
section("5. 방해 아이템은 승률을 팔지 않는다")
--------------------------------------------------
local FORBIDDEN = { "window", "hint", "reveal", "extraCatch", "selfBuff", "dangerHint" }
local sellsAdvantage = nil
for _, item in ipairs(GameConfig.Sabotage.Items) do
	for _, key in ipairs(FORBIDDEN) do
		if item[key] ~= nil then
			sellsAdvantage = item.id .. "." .. key
		end
	end
end
check(sellsAdvantage == nil, "★ 잡기 창 늘리기 · 위험 자리 힌트 같은 항목이 없다")

local allTargetOthers = true
for _, item in ipairs(GameConfig.Sabotage.Items) do
	-- 모든 효과는 "상대에게 걸리는 것"이어야 한다. 자기 자신을 강화하는 항목이 없어야 한다.
	if item.selfDuration or item.selfBonus then
		allTargetOthers = false
	end
end
check(allTargetOthers, "모든 방해 아이템이 상대에게만 걸린다")
check(GameConfig.Sabotage.PerRoundLimit <= 5, "한 라운드에 쓸 수 있는 횟수가 제한되어 있다")
check(GameConfig.Sabotage.Cooldown >= 10, "연속으로 퍼붓지 못하도록 쿨다운이 있다")

local uniqueIds = {}
local duplicateItem = nil
for _, item in ipairs(GameConfig.Sabotage.Items) do
	if uniqueIds[item.id] then
		duplicateItem = item.id
	end
	uniqueIds[item.id] = true
	check(GameConfig.findSabotage(item.id) == item, ("'%s' 를 id 로 찾을 수 있다"):format(item.id))
end
check(duplicateItem == nil, "방해 아이템 id 가 겹치지 않는다")

--------------------------------------------------
section("6. 퀘스트와 업적이 실제로 세는 통계를 본다")
--------------------------------------------------
-- ProfileService 가 세는 항목들. 여기 없는 통계를 퀘스트가 보면 영원히 못 깬다.
local TRACKED = {
	wins = true, games = true, catches = true, safePicks = true,
	duoGames = true, partyGames = true, bestStreak = true, bestStreakToday = true,
}

local badQuest, badAchievement = nil, nil
local questIds = {}
for _, quest in ipairs(GameConfig.Quests.Pool) do
	if not TRACKED[quest.metric] then
		badQuest = quest.id .. " → " .. tostring(quest.metric)
	end
	if questIds[quest.id] then
		badQuest = "id 중복: " .. quest.id
	end
	questIds[quest.id] = true
end
for _, entry in ipairs(GameConfig.Achievements) do
	if not TRACKED[entry.metric] then
		badAchievement = entry.id .. " → " .. tostring(entry.metric)
	end
end
check(badQuest == nil, "일일 퀘스트가 전부 실제로 세는 통계를 본다")
check(badAchievement == nil, "업적이 전부 실제로 세는 통계를 본다")
check(#GameConfig.Quests.Pool >= GameConfig.Quests.DailyCount, "하루에 줄 퀘스트가 모자라지 않는다")

local risingGoals = true
local lastGoal = 0
for _, entry in ipairs(GameConfig.Achievements) do
	if entry.metric == "wins" then
		if entry.goal <= lastGoal then
			risingGoals = false
		end
		lastGoal = entry.goal
	end
end
check(risingGoals, "승리 업적의 목표가 차례대로 커진다")

--------------------------------------------------
section("7. 연승 표시")
--------------------------------------------------
check(GameConfig.Streak.MinToShow >= 2, "1연승은 머리 위에 띄우지 않는다")
check(GameConfig.streakTier(2).min == 2, "2연승은 첫 단계")
check(GameConfig.streakTier(12).min == 10, "10연승 이상은 마지막 단계")
check(GameConfig.streakTier(5).min == 4, "5연승은 두 번째 단계")

--------------------------------------------------
print("")
print(("결과: %d개 통과, %d개 실패"):format(passed, failed))
if failed > 0 then
	error(("테스트 %d개 실패"):format(failed), 0)
end
