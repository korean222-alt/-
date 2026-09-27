--[[
	OnboardingService  (Phase 32)
	필수 튜토리얼 : 처음 온 사람을 AI 선원과 함께 연습 테이블에 앉힌다.

	· 자료를 다 읽고 캐릭터가 서 있으면, 빈 연습 테이블(BotService:SeatForPractice)에 앉힌다.
	· 튜토리얼 판(RoundService)에서는 해적 종류를 하나씩 모두 잡아 봐야 끝난다. 끝나면 TutorialDone.
	· 튜토리얼을 마치기 전에는 다른 테이블에 앉을 수 없다 (GameTable 이 되돌린다).
	· 중간에 일어나면 잠시 뒤 다시 앉힌다 (자리 비움이면 기다린다).
	· 빈 연습 테이블을 GiveUpAfter 초 동안 못 찾으면 필수를 풀어 준다 (TutorialFree). 신입 보호는 그대로 받는다.
	· 화면(TutorialController)은 player 의 TutorialActive · TutorialStep(테이블) 을 보고 안내를 그린다.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local TableService = require(script.Parent.TableService)
local BotService = require(script.Parent.BotService)

local TUTORIAL = GameConfig.Tutorial
local TABLE_ATTR = GameConfig.TableAttributes

local OnboardingService = {}
OnboardingService._started = false
OnboardingService._running = {} -- [Player] = true

local function onTutorialTable(player)
	local gameTable = TableService:GetTableOfPlayer(player)
	return gameTable ~= nil and gameTable.model ~= nil and gameTable.model:GetAttribute(TABLE_ATTR.Tutorial) == player.UserId, gameTable
end

function OnboardingService:_run(player)
	if self._running[player] then
		return
	end
	self._running[player] = true
	-- 자료를 다 읽을 때까지 (다른 서버의 저장 잠금을 기다리면 오래 걸릴 수 있다)
	while player.Parent == Players and player:GetAttribute("ProfileLoaded") ~= true do
		task.wait(0.5)
	end
	if player.Parent ~= Players or player:GetAttribute("TutorialDone") == true then
		self._running[player] = nil
		return
	end
	player:SetAttribute("TutorialActive", true)
	local lookingSince = os.clock()
	local retry = math.max(1, tonumber(TUTORIAL.SeatRetry) or 3)
	local giveUp = tonumber(TUTORIAL.GiveUpAfter) or 45
	-- Phase 32.1 : 들어오자마자 앉히지 않는다. 환영 창(TutorialController)에서 「튜토리얼 시작」을 누르거나
	--   WelcomeWait 초가 지나거나, 스스로 다른 테이블에 앉으려 하면(= 놀 준비가 됐다) 시작한다.
	player:SetAttribute("TutorialWelcome", true)
	local welcomeUntil = os.clock() + (tonumber(TUTORIAL.WelcomeWait) or 30)
	while player.Parent == Players and os.clock() < welcomeUntil and player:GetAttribute("TutorialGo") ~= true do
		local blocked = tostring(player:GetAttribute("SeatBlocked") or "")
		if blocked:sub(1, 8) == "tutorial" then
			break
		end
		task.wait(0.25)
	end
	if player.Parent ~= Players then
		self._running[player] = nil
		return
	end
	player:SetAttribute("TutorialWelcome", nil)
	lookingSince = os.clock()
	while player.Parent == Players and player:GetAttribute("TutorialDone") ~= true do
		local seatedTutorial, seatedTable = onTutorialTable(player)
		if seatedTutorial then
			lookingSince = os.clock()
		elseif not seatedTable and player:GetAttribute("AFK") ~= true then
			local humanoid = Utility.getHumanoid(player)
			if humanoid and humanoid.RootPart and humanoid.Health > 0 and not humanoid.SeatPart then
				local ok = BotService:SeatForPractice(player)
				if ok then
					lookingSince = os.clock()
				end
			end
		end
		if not seatedTutorial and os.clock() - lookingSince > giveUp then
			-- 빈 연습 테이블을 끝내 못 찾았다. 필수를 풀어 준다 (다른 사람들과 바로 놀 수 있게)
			player:SetAttribute("TutorialFree", true)
			GameConfig.log(("%s : 연습 테이블을 찾지 못해 튜토리얼 필수를 풉니다"):format(player.Name))
			break
		end
		task.wait(retry)
	end
	if player.Parent == Players then
		player:SetAttribute("TutorialActive", nil)
	end
	self._running[player] = nil
end

function OnboardingService:Start()
	if self._started then
		return
	end
	self._started = true
	if not (TUTORIAL and TUTORIAL.Enabled and TUTORIAL.Mandatory) then
		return
	end
	local function begin(player)
		task.spawn(function()
			local ok, err = pcall(self._run, self, player)
			if not ok then
				self._running[player] = nil
				warn("[CursedBarrel] 튜토리얼 안내 오류: " .. tostring(err))
			end
		end)
	end
	Players.PlayerAdded:Connect(begin)
	for _, player in ipairs(Players:GetPlayers()) do
		begin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self._running[player] = nil
	end)
	GameConfig.log("OnboardingService 시작 완료 (필수 튜토리얼)")
end

return OnboardingService
