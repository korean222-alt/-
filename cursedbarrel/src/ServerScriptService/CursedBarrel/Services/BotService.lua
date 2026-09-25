--[[
	BotService  (Phase 11)
	혼자 앉아 기다리는 사람을 위한 AI 선원.

	언제 앉나
	  · 테이블에 사람이 앉아 있는데 시작 인원(MinPlayers)이 모자라고,
	    Bots.FillDelay 초가 지나도 아무도 안 오면 AI 가 한 명씩 빈 의자에 앉는다.
	  · 사람 자리는 항상 Bots.KeepFreeSeats 개 남겨 둔다. 누가 오면 바로 앉을 수 있다.

	언제 일어나나
	  · 기다리는 동안(Waiting · Countdown) 사람만으로 시작 인원이 차면 AI 는 자리를 비켜 준다.
	  · 사람이 모두 일어나면 AI 도 일어난다.
	  · 게임 중에는 떠나지 않는다. (해적에게 탈락하면 그때 사라진다)

	Phase 12
	  · 토너먼트 테이블(config.NoBots)에는 앉지 않는다.
	  · 연습 판(Tutorial) : 처음 온 사람이 "AI 와 연습 한 판"을 누르면 빈 테이블에 앉히고, AI 가 곧바로 앉는다.

	AI 의 차례 · 잡기 · 배짱은 RoundService 가 사람과 같은 규칙으로 처리한다.
	AI 도 해적 위치를 모른다. 이 파일은 "앉히고 치우는 일"과 "몸 만들기"만 한다.

	★ AI 는 Player 가 아니다. RoundService · GameTable 이 쓰는 만큼만 흉내 낸 표다.
	  UserId 는 음수라 실제 계정과 겹치지 않고, ProfileService 에는 자료가 없어서 코인 · 기록이 쌓이지 않는다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TableService = require(script.Parent.TableService)
local BotRegistry = require(script.Parent.BotRegistry)

local BOTS = GameConfig.Bots
local STATES = GameConfig.States
local SKIN_ATTR = GameConfig.Skins.PlayerAttributes

local BotService = {}
BotService._started = false
BotService._nextId = 0
BotService._bots = {} -- [bot] = { gameTable, character }
BotService._waitingSince = {} -- [GameTable] = os.clock()
BotService._folder = nil
BotService._random = Random.new()

--------------------------------------------------
-- AI 한 명 (Player 흉내)
--------------------------------------------------
local Bot = {}
Bot.__index = Bot

function Bot.new(id, crew)
	local self = setmetatable({}, Bot)
	self.IsBot = true -- GameConfig.isBot 이 이 값을 본다
	self.UserId = -id
	self.Name = "AI_" .. crew.name
	self.DisplayName = "AI " .. crew.name
	self.crew = crew
	self.skill = crew.skill
	self.brave = crew.brave
	self.Character = nil
	self.CharacterRemoving = Utility.Signal.new()
	self._attributes = {}
	return self
end

function Bot:GetAttribute(name)
	return self._attributes[name]
end

function Bot:SetAttribute(name, value)
	self._attributes[name] = value
end

--------------------------------------------------
-- 몸 만들기
-- 반투명한 유령 선원. R6 와 같은 관절 이름을 써서 칼 꽂기 모션(StabMotion)이 그대로 먹는다.
--------------------------------------------------

local function part(parent, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function motor(name, part0, part1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

-- 머리 · 모자 같은 장식은 붙은 곳에 용접한다.
local function attach(base, piece, offset)
	piece.Massless = true
	piece.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = piece
	weld.Parent = piece
	return piece
end

function BotService:_buildCharacter(bot)
	local crew = bot.crew
	local body = crew.color or Color3.fromRGB(176, 246, 230)
	local coat = body:Lerp(Color3.fromRGB(20, 26, 34), 0.62)
	local dark = Color3.fromRGB(24, 22, 26)

	local model = Instance.new("Model")
	model.Name = bot.Name

	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), body)
	root.Transparency = 1
	local torso = part(model, "Torso", Vector3.new(2, 2, 1), coat, Enum.Material.Fabric)
	local head = part(model, "Head", Vector3.new(2, 1, 1), body, Enum.Material.SmoothPlastic)
	local rightArm = part(model, "Right Arm", Vector3.new(1, 2, 1), coat, Enum.Material.Fabric)
	local leftArm = part(model, "Left Arm", Vector3.new(1, 2, 1), coat, Enum.Material.Fabric)
	local rightLeg = part(model, "Right Leg", Vector3.new(1, 2, 1), dark, Enum.Material.Fabric)
	local leftLeg = part(model, "Left Leg", Vector3.new(1, 2, 1), dark, Enum.Material.Fabric)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head
	for _, limb in ipairs({ torso, head, rightArm, leftArm, rightLeg, leftLeg }) do
		limb.Transparency = 0.12 -- 살짝 비친다. 사람이 아니라는 것이 한눈에 보인다.
	end

	-- R6 표준 관절 (C0 · C1 은 Roblox 기본 R6 리그와 같다)
	motor("RootJoint", root, torso, CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	local rightShoulder = motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	local leftShoulder = motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	local rightHip = motor("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	local leftHip = motor("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	-- 앉은 자세. AI 에게는 기본 애니메이션 스크립트가 없어서 관절을 직접 굽혀 둔다.
	-- (엉덩이 관절의 Z 축은 몸통의 오른쪽 · 왼쪽을 가리킨다. +90° / -90° 가 다리를 앞으로 뻗는다)
	rightHip.C0 *= CFrame.Angles(0, 0, math.rad(90))
	leftHip.C0 *= CFrame.Angles(0, 0, math.rad(-90))
	-- 팔은 탁자 쪽으로 살짝 든다.
	rightShoulder.C0 *= CFrame.Angles(0, 0, math.rad(28))
	leftShoulder.C0 *= CFrame.Angles(0, 0, math.rad(-28))

	-- 빛나는 눈 · 턱
	local eyeColor = crew.color or Color3.fromRGB(120, 255, 214)
	for _, x in ipairs({ -0.28, 0.28 }) do
		local eye = part(model, "Eye", Vector3.new(0.26, 0.18, 0.08), eyeColor, Enum.Material.Neon)
		attach(head, eye, CFrame.new(x, 0.12, -0.6))
	end
	local jaw = part(model, "Jaw", Vector3.new(0.9, 0.12, 0.08), dark, Enum.Material.SmoothPlastic)
	attach(head, jaw, CFrame.new(0, -0.3, -0.6))
	local glow = Instance.new("PointLight")
	glow.Color = eyeColor
	glow.Brightness = 0.8
	glow.Range = 6
	glow.Shadows = false
	glow.Parent = head

	-- 해적 모자 (챙 + 몸통 + 해골 문양)
	local brim = part(model, "HatBrim", Vector3.new(0.18, 2.6, 2.6), dark, Enum.Material.Fabric)
	brim.Shape = Enum.PartType.Cylinder
	attach(head, brim, CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local crown = part(model, "HatCrown", Vector3.new(1.5, 0.7, 1.4), dark, Enum.Material.Fabric)
	attach(head, crown, CFrame.new(0, 1.0, 0.05))
	local band = part(model, "HatBand", Vector3.new(1.54, 0.16, 1.44), eyeColor, Enum.Material.Neon)
	attach(head, band, CFrame.new(0, 0.74, 0.05))
	local emblem = part(model, "HatSkull", Vector3.new(0.34, 0.34, 0.06), Color3.fromRGB(240, 236, 220), Enum.Material.SmoothPlastic)
	attach(crown, emblem, CFrame.new(0, 0.05, -0.72))

	-- 허리띠와 버클
	local belt = part(model, "Belt", Vector3.new(2.04, 0.3, 1.04), dark, Enum.Material.Leather)
	attach(torso, belt, CFrame.new(0, -0.6, 0))
	local buckle = part(model, "Buckle", Vector3.new(0.4, 0.3, 0.06), Color3.fromRGB(240, 202, 104), Enum.Material.Metal)
	attach(torso, buckle, CFrame.new(0, -0.6, -0.54))

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayName = bot.DisplayName
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 40
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	Instance.new("Animator").Parent = humanoid

	model.PrimaryPart = root
	return model, humanoid
end

--------------------------------------------------
-- 앉히기 / 치우기
--------------------------------------------------

local function pickFrom(list, random)
	if #list == 0 then
		return nil
	end
	return list[random:NextInteger(1, #list)]
end

-- 상점에 있는 치장을 골고루 끼워 둔다. 사람들이 "저건 뭐지?" 하고 보게 된다. (전부 모양일 뿐이다)
local function dressUp(bot, random)
	for kind, attribute in pairs(SKIN_ATTR) do
		local list = GameConfig.Skins[kind]
		if list and kind ~= "Barrel" then
			local choices = {}
			for _, skin in ipairs(list) do
				if not skin.vip and not skin.pack then
					table.insert(choices, skin.id)
				end
			end
			bot:SetAttribute(attribute, pickFrom(choices, random) or list[1].id)
		end
	end
	bot:SetAttribute(GameConfig.PlayerAttributes.Level, random:NextInteger(3, 24))
	bot:SetAttribute(GameConfig.PlayerAttributes.Streak, 0)
end

function BotService:_crewFor(gameTable)
	local used = {}
	for _, occupant in ipairs(gameTable:GetPlayers()) do
		if GameConfig.isBot(occupant) and occupant.crew then
			used[occupant.crew.name] = true
		end
	end
	local choices = {}
	for _, crew in ipairs(BOTS.Crew) do
		if not used[crew.name] then
			table.insert(choices, crew)
		end
	end
	return pickFrom(choices, self._random)
end

function BotService:_spawn(gameTable)
	local seat = pickFrom(gameTable:GetFreeSeats(), self._random)
	local crew = seat and self:_crewFor(gameTable)
	if not seat or not crew then
		return nil
	end

	self._nextId += 1
	local bot = Bot.new(self._nextId, crew)
	dressUp(bot, self._random)

	local character, humanoid = self:_buildCharacter(bot)
	bot.Character = character
	BotRegistry.register(character, bot)
	self._bots[bot] = { gameTable = gameTable, character = character }

	-- 의자 위에 앉은 자세로 고정한다. (Seat:Sit 은 막 만든 NPC 에게 조용히 실패해서 AI 가 갑판 아래로 떨어지곤 했다)
	-- 자리는 Roblox 의자가 R6 를 앉히는 자리와 같다: 좌판 윗면 + 1.5
	local root = character.PrimaryPart
	root.Anchored = true
	humanoid.PlatformStand = true
	character:PivotTo(seat.CFrame * CFrame.new(0, seat.Size.Y / 2 + 1.5, 0))
	character.Parent = self._folder

	if not gameTable:SeatBot(bot, seat) then
		self:_despawn(bot)
		return nil
	end

	GameConfig.log(("%s 에 AI 선원 %s 이 앉음"):format(gameTable.tableId, bot.DisplayName))
	return bot
end

-- 유령답게 흐려지면서 사라진다.
function BotService:_despawn(bot)
	local entry = self._bots[bot]
	if not entry then
		return
	end
	self._bots[bot] = nil
	local character = entry.character
	if entry.gameTable and not entry.gameTable.destroyed and entry.gameTable:HasPlayer(bot) then
		entry.gameTable:RemovePlayer(bot)
	end
	bot.CharacterRemoving:Fire(character)

	if character and character.Parent then
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				TweenService:Create(descendant, TweenInfo.new(0.7), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.75, function()
			BotRegistry.unregister(character)
			character:Destroy()
		end)
	else
		BotRegistry.unregister(character)
	end
	bot.CharacterRemoving:Destroy()
end

--------------------------------------------------
-- 판단 (1초마다)
--------------------------------------------------

function BotService:_botsAt(gameTable)
	local list = {}
	for _, occupant in ipairs(gameTable:GetPlayers()) do
		if GameConfig.isBot(occupant) then
			table.insert(list, occupant)
		end
	end
	return list
end

-- Phase 24 : 앉은 사람 중 누군가 "AI 선원 끄기"(설정 aiCrew = false)를 해 두었는가
--   설정은 저장되므로 한 번 꺼 두면 다시 켤 때까지 어느 테이블에서나 AI 가 오지 않는다.
function BotService:_humansWantBots(gameTable)
	for _, occupant in ipairs(gameTable:GetPlayers()) do
		if not GameConfig.isBot(occupant) and occupant:GetAttribute("Setting_aiCrew") == false then
			return false
		end
	end
	return true
end

-- AI 를 채워 맞출 전체 인원
-- 2인 테이블은 빈자리를 남기면 AI 가 영영 못 앉는다. 시작 인원만큼은 꼭 채운다.
function BotService:_targetSeated(gameTable)
	local seats = #gameTable:GetSeats()
	local minPlayers = gameTable:GetMinPlayers()
	local target = math.max(minPlayers, tonumber(BOTS.TargetSeated) or minPlayers)
	target = math.min(target, seats - (tonumber(BOTS.KeepFreeSeats) or 1))
	return math.min(seats, math.max(minPlayers, target))
end

function BotService:_tick(gameTable)
	if gameTable.destroyed then
		self._waitingSince[gameTable] = nil
		return
	end
	local state = gameTable.state
	if state ~= STATES.Waiting and state ~= STATES.Countdown then
		return -- 게임 중에는 아무도 넣고 빼지 않는다
	end
	if gameTable.config.NoBots then
		return
	end

	local humans = gameTable:GetHumanCount()
	local bots = self:_botsAt(gameTable)
	local minPlayers = gameTable:GetMinPlayers()

	-- 연습 판 : 그 사람이 자리를 떠났으면 연습 표시를 지운다
	local tutorialId = gameTable.model and gameTable.model:GetAttribute(GameConfig.TableAttributes.Tutorial) or 0
	if tutorialId and tutorialId ~= 0 then
		local stillHere = false
		for _, occupant in ipairs(gameTable:GetPlayers()) do
			if occupant.UserId == tutorialId then
				stillHere = true
			end
		end
		if not stillHere then
			gameTable:SetTableAttribute(GameConfig.TableAttributes.Tutorial, 0)
			tutorialId = 0
		end
	end

	-- 사람이 없거나, 사람만으로 시작 인원이 찼으면 AI 는 비켜 준다.
	-- Phase 24 : 앉은 사람 중 누가 AI 를 꺼 두었어도 비켜 준다 (연습 판은 직접 부른 것이라 예외)
	local practiceTable = tutorialId and tutorialId ~= 0
	if humans == 0 or humans >= minPlayers or (not practiceTable and not self:_humansWantBots(gameTable)) then
		self._waitingSince[gameTable] = nil
		for _, bot in ipairs(bots) do
			self:_despawn(bot)
		end
		return
	end

	local since = self._waitingSince[gameTable]
	if not since then
		self._waitingSince[gameTable] = os.clock()
		return
	end
	local delay = (tutorialId and tutorialId ~= 0) and GameConfig.Tutorial.BotFillDelay or (tonumber(BOTS.FillDelay) or 6)
	if os.clock() - since < delay then
		return
	end

	-- 한 번에 한 명씩 앉힌다. (우르르 앉으면 어색하다)
	if humans + #bots < self:_targetSeated(gameTable) then
		self:_spawn(gameTable)
	end
end

function BotService:_watch(gameTable)
	-- 탈락하거나 일어난 AI 는 바로 사라진다.
	gameTable.cleaner:add(gameTable.RosterChanged:Connect(function(_, who, joined)
		if not joined and GameConfig.isBot(who) then
			self:_despawn(who)
		end
	end))
end

function BotService:Start()
	if self._started then
		return
	end
	self._started = true
	if not BOTS.Enabled then
		return
	end

	local folder = workspace:FindFirstChild("CursedBarrelBots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CursedBarrelBots"
		folder.Parent = workspace
	end
	self._folder = folder

	TableService.TableAdded:Connect(function(gameTable)
		self:_watch(gameTable)
	end)
	TableService.TableRemoved:Connect(function(gameTable)
		self._waitingSince[gameTable] = nil
		for bot, entry in pairs(self._bots) do
			if entry.gameTable == gameTable then
				self:_despawn(bot)
			end
		end
	end)
	for _, gameTable in ipairs(TableService:GetAllTables()) do
		self:_watch(gameTable)
	end

	task.spawn(function()
		while self._started do
			task.wait(1)
			for _, gameTable in ipairs(TableService:GetAllTables()) do
				local ok, err = pcall(self._tick, self, gameTable)
				if not ok then
					warn("[CursedBarrel] AI 선원 처리 중 오류: " .. tostring(err))
				end
			end
		end
	end)

	GameConfig.log("BotService 시작 완료")
end

--------------------------------------------------
-- 연습 판 (Phase 12)
--------------------------------------------------

-- 처음 온 사람을 빈 테이블에 앉힌다. 성공하면 true.
function BotService:SeatForPractice(player)
	if not GameConfig.Tutorial.Enabled or not BOTS.Enabled then
		return false, "지금은 연습 판을 열 수 없습니다"
	end
	if TableService:GetTableOfPlayer(player) then
		return false, "이미 테이블에 앉아 있습니다"
	end
	local humanoid = Utility.getHumanoid(player)
	local root = humanoid and humanoid.RootPart
	if not root or humanoid.SeatPart then
		return false, "캐릭터가 준비되면 다시 눌러 주세요"
	end
	local best, bestDistance = nil, math.huge
	for _, gameTable in ipairs(TableService:GetAllTables()) do
		if not gameTable.destroyed and not gameTable.config.NoBots and gameTable.state == STATES.Waiting
			and gameTable:GetHumanCount() == 0 and #gameTable:GetFreeSeats() >= 3 then
			local seat = gameTable:GetFreeSeats()[1]
			local distance = (seat.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = gameTable, distance
			end
		end
	end
	if not best then
		return false, "빈 테이블이 없습니다. 잠시 뒤 다시 눌러 주세요"
	end
	best:SetTableAttribute(GameConfig.TableAttributes.Tutorial, player.UserId)
	self._waitingSince[best] = os.clock() - 10
	local seat = best:GetFreeSeats()[1]
	root.CFrame = seat.CFrame * CFrame.new(0, 3, 0)
	seat:Sit(humanoid)
	return true, "연습 판에 앉았습니다. 곧 AI 선원이 옵니다"
end

-- 테스트 · 디버그용
BotService.Bot = Bot

return BotService
