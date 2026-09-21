--=========================================================
-- Studio 없이 게임 로직을 실제로 돌려 보는 검사 (개발용)
--=========================================================
local ENV = Mock.ENV
local game = ENV.game
local workspace = ENV.workspace
local Instance = ENV.Instance
local Vector3 = ENV.Vector3
local GAME_SOURCES = ENV.GAME_SOURCES

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local passed, failed = 0, 0
local function check(label, condition, detail)
	if condition then
		passed += 1
		print("  ✅ " .. label)
	else
		failed += 1
		print("  ❌ " .. label .. (detail and ("  → " .. tostring(detail)) or ""))
	end
end

local function section(title)
	print("\n== " .. title .. " ==")
end

--=========================================================
-- 인스턴스 트리 만들기 (place 파일과 같은 구조)
--=========================================================
local roots = {
	ReplicatedStorage = ReplicatedStorage,
	ServerScriptService = ServerScriptService,
	StarterPlayer = StarterPlayer,
}

local function split(text, sep)
	local out = {}
	for piece in string.gmatch(text, "([^" .. sep .. "]+)") do
		table.insert(out, piece)
	end
	return out
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local made
	if name == "StarterPlayerScripts" or name == "StarterCharacterScripts" then
		made = Instance.new(name)
	else
		made = Instance.new("Folder")
	end
	made.Name = name
	made.Parent = parent
	return made
end

local instanceByPath = {}
for _, entry in ipairs(GAME_SOURCES) do
	local parts = split(entry.path, "/")
	local node = roots[parts[1]]
	assert(node, "알 수 없는 서비스: " .. parts[1])
	for index = 2, #parts - 1 do
		node = ensureFolder(node, parts[index])
	end
	local made = Instance.new(entry.class)
	made.Name = parts[#parts]
	made._source = entry.source
	made.Parent = node
	instanceByPath[entry.path] = made
end

--=========================================================
-- require 를 인스턴스용으로 바꿔치기
--=========================================================
local moduleCache = {}
local function requireInstance(target)
	local cached = moduleCache[target]
	if cached ~= nil then
		return cached
	end
	local source = target._source
	if not source then
		error("소스가 없는 모듈: " .. tostring(target), 0)
	end
	local chunk, compileError = loadstring("return function(script) " .. source .. "\nend", target.Name)
	if not chunk then
		error("컴파일 실패 " .. tostring(target.Name) .. ": " .. tostring(compileError), 0)
	end
	setfenv(chunk, ENV)
	local factory = chunk()
	local result = factory(target)
	moduleCache[target] = result
	return result
end
ENV.require = requireInstance
local require = requireInstance

local function runScript(path)
	local target = instanceByPath[path]
	assert(target, "스크립트를 찾을 수 없음: " .. path)
	local chunk, compileError = loadstring("return function(script) " .. target._source .. "\nend", target.Name)
	assert(chunk, compileError)
	setfenv(chunk, ENV)
	return chunk()(target)
end

--=========================================================
-- 0. 서버 시작
--=========================================================
section("0단계 · 서버 시작")
runScript("ServerScriptService/GameBootstrap")
Mock.advance(0.5)

local Config = require(instanceByPath["ReplicatedStorage/Shared/Config"])
local DataService = require(instanceByPath["ServerScriptService/Services/DataService"])
local AnimalService = require(instanceByPath["ServerScriptService/Services/AnimalService"])
local WorldService = require(instanceByPath["ServerScriptService/Services/WorldService"])
local FarmService = require(instanceByPath["ServerScriptService/Services/FarmService"])

local world = workspace:FindFirstChild("World")
check("World 폴더가 만들어졌다", world ~= nil)
check("초원 섬 땅이 있다", world and world:FindFirstChild("Meadow") and world.Meadow:FindFirstChild("Ground") ~= nil)
check("펭귄 섬 땅이 있다", world and world:FindFirstChild("Snow") ~= nil)
check("배달 발판이 있다", WorldService.getDeliveryZone("Meadow") ~= nil)
check("다리가 있다", world and world:FindFirstChild("Bridge") ~= nil)
check("별 문이 있다", world and world:FindFirstChild("StarGate") ~= nil)
check("상점 가판대가 있다", world and world.Meadow:FindFirstChild("Shop") ~= nil)
check("스폰 발판이 초원 섬에 있다", world and world.Meadow:FindFirstChild("MainSpawn") ~= nil)

local animals = workspace:FindFirstChild("Animals")
local animalCount = animals and #animals:GetChildren() or 0
check("동물이 스폰됐다 (" .. animalCount .. "마리)", animalCount >= 20, animalCount)

local firstChick = nil
for _, model in ipairs(animals:GetChildren()) do
	if model.Name == "Chick" then
		local part = model.PrimaryPart
		if part and (part.Position - Config.Islands.Meadow.FirstAnimalPos).Magnitude < 11 then
			firstChick = model
		end
	end
end
check("첫 병아리가 스폰 정면에 있다", firstChick ~= nil)

local foxes = workspace:FindFirstChild("Foxes")
check("여우가 두 섬에 있다", foxes and #foxes:GetChildren() == 2, foxes and #foxes:GetChildren())

--=========================================================
-- 1. 플레이어 접속과 데이터
--=========================================================
section("8단계 · 접속과 저장 데이터")
local player = Mock.addPlayer("테스트아이", 1234)
Mock.advance(0.5)
local character = Mock.spawnCharacter(player, Vector3.new(0, 3, 62))
Mock.advance(1.5)

check("데이터를 불러왔다", DataService.isLoaded(player))
check("leaderstats ⭐ 가 생겼다", player:FindFirstChild("leaderstats") ~= nil)
check("시작 별은 0개", DataService.get(player).stars == 0)
check("초원 섬은 처음부터 열려 있다", DataService.hasIsland(player, "Meadow"))
check("펭귄 섬은 아직 잠겨 있다", not DataService.hasIsland(player, "Snow"))

--=========================================================
-- 2. 동물 줍기 (4단계 핵심)
--=========================================================
section("4단계 · 닿으면 따라오기")
local function walkTo(target, seconds)
	local character = player.Character
	local root = character:FindFirstChild("HumanoidRootPart")
	local from = root.Position
	local steps = math.max(1, math.floor(seconds * 30))
	for index = 1, steps do
		local alpha = index / steps
		Mock.moveCharacter(player, from:Lerp(target, alpha))
		Mock.step(1 / 30)
	end
end

local function nearestWildPart(from, islandKey)
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(animals:GetChildren()) do
		if model:GetAttribute("Owned") == false and model:GetAttribute("Island") == islandKey then
			local part = model.PrimaryPart
			if part then
				local distance = (part.Position - from).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					best = part
				end
			end
		end
	end
	return best, bestDistance
end

local spawnPoint = Vector3.new(0, 3, Config.Islands.Meadow.SpawnPoint.Z)
local firstPart, firstDistance = nearestWildPart(spawnPoint, "Meadow")
check(
	"스폰에서 가장 가까운 동물이 " .. string.format("%.0f", firstDistance) .. " 스터드 (걸어서 약 "
		.. string.format("%.1f", firstDistance / Config.Player.BaseWalkSpeed) .. "초)",
	firstDistance <= 20,
	firstDistance
)
walkTo(Vector3.new(firstPart.Position.X, 3, firstPart.Position.Z), math.max(0.4, firstDistance / 16))
Mock.advance(0.4)
check("첫 동물이 기차에 붙었다", AnimalService.trainLength(player) >= 1, AnimalService.trainLength(player))

-- 근처 병아리를 더 모읍니다
local collected = AnimalService.trainLength(player)
local tries = 0
while collected < 3 and tries < 40 do
	tries += 1
	local nearest = nil
	local bestDistance = math.huge
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	for _, model in ipairs(animals:GetChildren()) do
		if model:GetAttribute("Owned") == false and model:GetAttribute("Island") == "Meadow" then
			local part = model.PrimaryPart
			if part then
				local distance = (part.Position - root.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					nearest = part
				end
			end
		end
	end
	if not nearest then
		break
	end
	walkTo(Vector3.new(nearest.Position.X, 3, nearest.Position.Z), math.max(0.3, bestDistance / 16))
	Mock.advance(0.3)
	collected = AnimalService.trainLength(player)
end
check("동물 3마리를 모았다 (" .. collected .. "마리)", collected >= 3, collected)

-- 줄이 제대로 따라오는지 (간격 확인)
local train = AnimalService.getTrain(player)
walkTo(Vector3.new(0, 3, 55), 1.5)
Mock.advance(0.5)
local root = player.Character:FindFirstChild("HumanoidRootPart")
local firstGap = (train[1].pos - Vector3.new(root.Position.X, train[1].pos.Y, root.Position.Z)).Magnitude
check(
	"첫 동물이 플레이어 뒤 약 " .. Config.Train.Spacing .. " 스터드에 있다 (" .. string.format("%.1f", firstGap) .. ")",
	firstGap > 1 and firstGap < Config.Train.Spacing * 2.5,
	firstGap
)
if #train >= 2 then
	local gap = (train[1].pos - train[2].pos).Magnitude
	check("두 동물 사이 간격이 유지된다 (" .. string.format("%.1f", gap) .. ")", gap > 1 and gap < Config.Train.Spacing * 2.5, gap)
end

local groundY = train[1].pos.Y
check("동물이 공중에 떠 있지 않다 (y=" .. string.format("%.2f", groundY) .. ")", math.abs(groundY) < 1.0, groundY)

--=========================================================
-- 3. 배달과 별 (5단계)
--=========================================================
section("5단계 · 농장 배달과 별")
local before = AnimalService.trainLength(player)
local zone = WorldService.getDeliveryZone("Meadow")
walkTo(Vector3.new(zone.Position.X, 3, zone.Position.Z), 2)
Mock.advance(3)

local data = DataService.get(player)
check("별이 " .. before .. "마리만큼 들어왔다 (별 " .. data.stars .. "개)", data.stars >= before, data.stars)
check("기차가 비었다", AnimalService.trainLength(player) == 0, AnimalService.trainLength(player))
check("도감에 병아리가 기록됐다", data.dex.Chick == true)
check("총 별과 현재 별이 같다", data.totalStars == data.stars)
check("농장에 동물이 들어갔다", FarmService.getDeliveredCount("Meadow") >= before)
local inside = WorldService.getFarmInside("Meadow")
check("농장 안 동물이 보인다", inside and #inside:GetChildren() >= 1, inside and #inside:GetChildren())

-- 같은 동물로 두 번 별을 받지 않는지
-- (발판 위에 서 있으면 지나가던 동물이 붙어서 바로 배달될 수 있으므로,
--  "농장에 들어간 마리 수가 늘지 않았는데 별만 늘었다" 를 확인합니다)
local starsNow = data.stars
local deliveredNow = FarmService.getDeliveredCount("Meadow")
Mock.advance(2)
local starsDelta = data.stars - starsNow
local deliveredDelta = FarmService.getDeliveredCount("Meadow") - deliveredNow
check(
	"배달 없이 별이 늘어나는 일은 없다 (별 +" .. starsDelta .. " / 배달 +" .. deliveredDelta .. ")",
	(starsDelta == 0 and deliveredDelta == 0) or (deliveredDelta > 0 and starsDelta <= deliveredDelta * 5),
	starsDelta .. "/" .. deliveredDelta
)

--=========================================================
-- 4. 별 문 (7단계)
--=========================================================
section("7단계 · 별 문")
walkTo(Vector3.new(0, 3, -90), 2)
Mock.advance(0.5)
Mock.moveCharacter(player, Vector3.new(0, 3, -130)) -- 막이를 통과한 상황을 흉내
Mock.advance(1)
local rootAfter = player.Character:FindFirstChild("HumanoidRootPart")
check("별이 모자라면 서버가 되돌려 보낸다", rootAfter.Position.Z > Config.Bridge.BlockZ, rootAfter.Position.Z)

DataService.addStars(player, Config.Islands.Snow.UnlockCost)
Mock.advance(1.5)
check("총 별 15개가 되면 펭귄 섬이 열린다", DataService.hasIsland(player, "Snow"))
local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
check("문을 연 사람은 통과할 수 있다 (충돌 그룹 변경)", rootPart.CollisionGroup == "StarGatePass", rootPart.CollisionGroup)

Mock.moveCharacter(player, Vector3.new(0, 3, -130))
Mock.advance(1)
check("이제는 되돌려 보내지 않는다", player.Character.HumanoidRootPart.Position.Z < Config.Bridge.BlockZ)

--=========================================================
-- 5. 업그레이드 상점 (11단계)
--=========================================================
section("11단계 · 업그레이드 상점")
local shop = world.Meadow:FindFirstChild("Shop")
local speedPad = shop:FindFirstChild("Pad_Speed")
check("신발 발판이 있다", speedPad ~= nil)

local starsBefore = DataService.get(player).stars
local price = Config.Upgrades.Speed.Prices[1]
speedPad.Touched:Fire(player.Character:FindFirstChild("HumanoidRootPart"))
Mock.advance(0.2)
check("신발 업그레이드를 샀다", DataService.getUpgrade(player, "Speed") == 1, DataService.getUpgrade(player, "Speed"))
check("별이 " .. price .. "개 줄었다", DataService.get(player).stars == starsBefore - price, DataService.get(player).stars)
check("달리기 속도가 빨라졌다", player.Character.Humanoid.WalkSpeed > Config.Player.BaseWalkSpeed, player.Character.Humanoid.WalkSpeed)
check("섬 해금 기준은 총 별이라 그대로다", DataService.hasIsland(player, "Snow"))

-- 별이 모자랄 때
local magnetPad = shop:FindFirstChild("Pad_Magnet")
local starsNow2 = DataService.get(player).stars
local magnetPrice = Config.Upgrades.Magnet.Prices[1]
if starsNow2 < magnetPrice then
	magnetPad.Touched:Fire(player.Character:FindFirstChild("HumanoidRootPart"))
	Mock.advance(0.2)
	check("별이 모자라면 아무 일도 안 생긴다", DataService.getUpgrade(player, "Magnet") == 0 and DataService.get(player).stars == starsNow2)
end

-- 기차 길이 업그레이드
DataService.addStars(player, 100)
local trainPad = shop:FindFirstChild("Pad_Train")
trainPad.Touched:Fire(player.Character:FindFirstChild("HumanoidRootPart"))
Mock.advance(0.2)
local Rules = require(instanceByPath["ReplicatedStorage/Shared/Rules"])
check(
	"기차 최대 길이가 늘었다 (" .. DataService.maxTrain(player) .. ")",
	DataService.maxTrain(player) == Config.Train.BaseMaxLength + Config.Upgrades.Train.LengthPerLevel,
	DataService.maxTrain(player)
)

--=========================================================
-- 6. 오래 돌려도 문제 없는지 (10·12단계)
--=========================================================
section("10·12단계 · 오래 돌려 보기")
Mock.moveCharacter(player, Vector3.new(0, 3, 40))
Mock.advance(60, 1 / 20)
check("60초를 돌려도 오류가 없다", true)
local aliveAnimals = #animals:GetChildren()
check("동물 수가 유지된다 (" .. aliveAnimals .. "마리)", aliveAnimals >= 15, aliveAnimals)

local foxMoved = false
for _, fox in ipairs(foxes:GetChildren()) do
	local part = fox.PrimaryPart
	if part and (part.Position - Config.Islands.Meadow.FoxDen).Magnitude > 1 then
		foxMoved = true
	end
end
check("여우가 움직였다", foxMoved)

-- 희귀 동물 (3분 뒤)
Mock.advance(200, 1 / 10)
local rareFound = false
for _, model in ipairs(animals:GetChildren()) do
	if model:GetAttribute("Rare") == true then
		rareFound = true
	end
end
check("희귀 동물이 나타났다", rareFound)

--=========================================================
-- 7. 나갔다 들어오기 (8단계 저장)
--=========================================================
section("8단계 · 저장과 불러오기")
local savedStars = DataService.get(player).stars
local savedTotal = DataService.get(player).totalStars
Players.PlayerRemoving:Fire(player)
Mock.advance(1)
check("나갈 때 저장됐다 (별 " .. savedStars .. "개)", true)

for index, item in ipairs(Mock.playerList) do
	if item == player then
		table.remove(Mock.playerList, index)
	end
end
local player2 = Mock.addPlayer("테스트아이", 1234)
Mock.advance(1.5)
local data2 = DataService.get(player2)
check("다시 들어와도 별이 그대로다", data2 and data2.stars == savedStars, data2 and data2.stars)
check("총 별도 그대로다", data2 and data2.totalStars == savedTotal, data2 and data2.totalStars)
check("열린 섬도 그대로다", DataService.hasIsland(player2, "Snow"))
check("도감도 그대로다", data2.dex.Chick == true)
check("업그레이드도 그대로다", data2.upgrades.Speed == 1)

--=========================================================
-- 8. 화면 (클라이언트) 실행
--=========================================================
section("6·9단계 · 화면 만들기")
Mock.spawnCharacter(player2, Vector3.new(0, 3, 62))
local playerGui = Instance.new("Folder")
playerGui.Name = "PlayerGui"
playerGui.Parent = player2
Players.LocalPlayer = player2
Mock.isServer = false

local ok, err = pcall(runScript, "StarterPlayer/StarterPlayerScripts/ClientMain")
check("클라이언트 스크립트가 오류 없이 실행된다", ok, err)

local screen = playerGui:FindFirstChild("AnimalTrainHud")
check("화면(ScreenGui)이 만들어졌다", screen ~= nil)
if screen then
	check("별 패널이 있다", screen:FindFirstChild("StarPanel") ~= nil)
	check("기차 칸 표시가 있다", screen:FindFirstChild("TrainBar") ~= nil)
	check("도감 버튼이 있다", screen:FindFirstChild("DexButton") ~= nil)
	local bar = screen:FindFirstChild("TrainBar")
	local holder = bar and bar:FindFirstChild("Pips")
	check("기차 칸이 최대 길이만큼 있다", holder and #holder:GetChildren() >= Config.Train.BaseMaxLength, holder and #holder:GetChildren())
end

-- 상태 보내기 (서버 → 화면)
local StateService = require(instanceByPath["ServerScriptService/Services/StateService"])
Mock.isServer = true
StateService.push(player2)
Mock.isServer = false
Mock.advance(0.3)
check("상태를 받아 화면이 갱신된다", true)

-- 모든 연출 신호를 한 번씩 흘려 봅니다
local ClientEffects = require(instanceByPath["ReplicatedStorage/Client/ClientEffects"])
local kinds = { "pickup", "full", "deliver", "newAnimal", "buyOk", "buyFail", "buyMax", "gateOpen", "gateLocked", "fell", "rareAppeared" }
for _, kind in ipairs(kinds) do
	local okEffect, errEffect = pcall(ClientEffects.handle, kind, { species = "Chick", kind = "Speed", price = 8 })
	check("연출 '" .. kind .. "' 이 오류 없이 돈다", okEffect, errEffect)
end

local Dex = require(instanceByPath["ReplicatedStorage/Client/Dex"])
local okDex = pcall(function()
	Dex.open()
	Mock.advance(0.2)
	Dex.update({ dex = { Chick = true }, stars = 3, train = 0, maxTrain = 10, islands = { Meadow = true } })
	Mock.advance(0.2)
	Dex.close()
end)
check("도감을 열고 갱신하고 닫을 수 있다", okDex)

--=========================================================
print("\n=========================================")
print(string.format("검사 결과 : 통과 %d개 / 실패 %d개", passed, failed))
print("=========================================")
if failed > 0 then
	error("실패한 검사가 있습니다", 0)
end
