--[[
	SabotageService  (Phase 8)
	로벅스를 내고 같은 테이블의 상대를 잠깐 방해하는 아이템.

	요청하신 대로 "플레이에 영향이 있어도 괜찮은" 물건들입니다.
	다만 선은 하나 그어 두었습니다.

	  파는 것   : 상대가 잠깐 불편해지는 것 (화면 얼룩 · 버튼 흔들림 · 짧아진 턴 · 뒤섞인 번호 · 가짜 해적)
	  안 파는 것 : 위험 자리 힌트 · 잡기 창 늘리기 · 잡기 횟수 추가

	앞의 것은 "상대가 실수하기 쉬워지는" 정도이고, 당한 사람도 여전히 스스로 고르고 잡습니다.
	뒤의 것은 승패를 직접 사는 것이라 무료 플레이어가 아무리 잘해도 이길 수 없게 됩니다.
	그 선을 넘으면 게임이 오래가지 못합니다.

	★ 그리고 "뒤섞인 번호"는 화면의 숫자만 바꿉니다.
	  누른 자리와 실제로 칼이 꽂히는 자리는 언제나 같습니다. (조작이 아니라 착시입니다)

	흐름
	  1. 클라이언트가 "이 아이템으로 저 사람을" 이라고 보낸다
	  2. 서버가 지금 쓸 수 있는 상황인지 검사하고, 쓸 수 있으면 의도를 기억해 둔다
	  3. 서버가 로벅스 구매창을 띄운다
	  4. 영수증이 확인되면 그때 효과가 들어간다 (PurchaseService 를 거친다)

	Studio 에서는 상품 ID 가 없어도 눌러볼 수 있습니다. (GameConfig.Sabotage.StudioFreeTest)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Utility = require(Shared:WaitForChild("Utility"))

local PurchaseService = require(script.Parent.PurchaseService)
local RoundService = require(script.Parent.RoundService)
local TableService = require(script.Parent.TableService)

local SABOTAGE = GameConfig.Sabotage
local REJECT = GameConfig.RejectMessages
local INTENT_TTL = 120 -- 결제창을 띄운 뒤 이 시간 안에 결제가 끝나야 한다

local SabotageService = {}
SabotageService._started = false
SabotageService._cleaner = Utility.Cleaner.new()
SabotageService._limiter = Utility.RateLimiter.new(0.5)
SabotageService._cooldown = {} -- [Player] = 다시 쓸 수 있는 시각
SabotageService._intent = {} -- [Player] = { itemId, targetUserId, at }

local function remote(name)
	local folder = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild(GameConfig.Remotes.Folder)
	local found = folder:FindFirstChild(name)
	if not found then
		found = Instance.new("RemoteEvent")
		found.Name = name
		found.Parent = folder
	end
	return found
end

--------------------------------------------------
-- 지금 쓸 수 있는가
--------------------------------------------------

function SabotageService:_validate(player, itemId, targetUserId)
	if not SABOTAGE.Enabled then
		return nil, nil, nil, "지금은 쓸 수 없습니다"
	end

	local item = GameConfig.findSabotage(itemId)
	if not item then
		return nil, nil, nil, REJECT.BadSlot
	end

	local readyAt = self._cooldown[player]
	if readyAt and os.clock() < readyAt then
		return nil, nil, nil, REJECT.SabotageCooldown
	end

	local gameTable = TableService:GetTableOfPlayer(player)
	if not gameTable then
		return nil, nil, nil, REJECT.NotParticipant
	end

	local round = RoundService:GetRound(gameTable)
	if not round then
		return nil, nil, nil, REJECT.NotPlaying
	end

	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	if not target or target == player then
		return nil, nil, nil, REJECT.NoTarget
	end

	-- 같은 테이블에 앉아 있는 사람만 방해할 수 있다.
	if TableService:GetTableOfPlayer(target) ~= gameTable then
		return nil, nil, nil, REJECT.NoTarget
	end

	local ok, reason = round:CanSabotage(player, target)
	if not ok then
		return nil, nil, nil, reason
	end

	return item, target, round, nil
end

--------------------------------------------------
-- 효과 넣기
--------------------------------------------------

function SabotageService:_apply(player, itemId, targetUserId)
	local item, target, round, reason = self:_validate(player, itemId, targetUserId)
	if not item then
		return false, reason
	end

	local ok, why = round:ApplySabotage(player, target, item)
	if not ok then
		return false, why
	end

	self._cooldown[player] = os.clock() + SABOTAGE.Cooldown
	return true, ("%s → %s"):format(item.name, target.DisplayName or target.Name)
end

--------------------------------------------------
-- 요청 처리
--------------------------------------------------

function SabotageService:_sendList(player)
	local items = {}
	for _, item in ipairs(SABOTAGE.Items) do
		table.insert(items, {
			id = item.id,
			name = item.name,
			icon = item.icon,
			color = item.color,
			robux = item.robux,
			blurb = item.blurb,
			detail = item.detail,
			ready = (tonumber(item.productId) or 0) > 0 or (SABOTAGE.StudioFreeTest and RunService:IsStudio()),
		})
	end

	local opponents = {}
	local gameTable = TableService:GetTableOfPlayer(player)
	local round = gameTable and RoundService:GetRound(gameTable)
	if round then
		for _, other in ipairs(round:GetOpponents(player)) do
			table.insert(opponents, { userId = other.UserId, name = other.DisplayName or other.Name })
		end
	end

	local readyAt = self._cooldown[player]
	self._cue:FireClient(player, gameTable and gameTable.model or nil, {
		id = "list",
		items = items,
		opponents = opponents,
		cooldown = readyAt and math.max(0, readyAt - os.clock()) or 0,
	})
end

function SabotageService:_onRequest(player, action, itemId, targetUserId)
	if not self._limiter:check(player.UserId) then
		return
	end
	if typeof(action) ~= "string" then
		return
	end

	if action == "list" then
		self:_sendList(player)
		return
	end

	if action ~= "use" then
		return
	end

	local item, target, _, reason = self:_validate(player, itemId, targetUserId)
	if not item then
		self._cue:FireClient(player, nil, { id = "deny", message = reason })
		return
	end

	local productId = tonumber(item.productId) or 0

	-- Studio 에서 상품을 아직 안 만들었으면 무료로 시험할 수 있다.
	if productId <= 0 then
		if SABOTAGE.StudioFreeTest and RunService:IsStudio() then
			local ok, message = self:_apply(player, item.id, target.UserId)
			self._cue:FireClient(player, nil, { id = ok and "done" or "deny", message = message })
		else
			self._cue:FireClient(player, nil, { id = "deny", message = "이 아이템은 아직 준비 중입니다" })
		end
		return
	end

	-- 결제가 끝나면 무엇을 누구에게 쓸지 기억해 둔다.
	self._intent[player] = { itemId = item.id, targetUserId = target.UserId, at = os.clock() }

	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	if not ok then
		warn("[CursedBarrel] 방해 아이템 구매창을 띄우지 못했습니다: " .. tostring(err))
		self._intent[player] = nil
	end
end

--------------------------------------------------
-- 결제 처리
--------------------------------------------------

function SabotageService:_registerProducts()
	for _, item in ipairs(SABOTAGE.Items) do
		PurchaseService:Register(item.productId, function(player)
			local intent = self._intent[player]
			self._intent[player] = nil

			-- 의도가 없거나(창을 안 거치고 들어온 결제) 너무 오래됐으면
			-- 그 자리에서 쓸 수 있는 상대를 하나 찾아 준다. 돈만 받고 넘어가지 않는다.
			local targetUserId = intent and intent.targetUserId or nil
			if not intent or intent.itemId ~= item.id or (os.clock() - intent.at) > INTENT_TTL then
				targetUserId = nil
			end

			if not targetUserId then
				local gameTable = TableService:GetTableOfPlayer(player)
				local round = gameTable and RoundService:GetRound(gameTable)
				local opponents = round and round:GetOpponents(player) or {}
				if opponents[1] then
					targetUserId = opponents[1].UserId
				end
			end

			if not targetUserId then
				-- 쓸 상대가 없다. 지급은 확정하고(중복 청구 방지) 안내만 남긴다.
				self._cue:FireClient(player, nil, {
					id = "deny",
					message = "상대가 없어 이번에는 쓰지 못했습니다. 테이블에 앉은 뒤 다시 눌러 주세요.",
				})
				return true
			end

			local ok, message = self:_apply(player, item.id, targetUserId)
			self._cue:FireClient(player, nil, { id = ok and "done" or "deny", message = message })
			return true
		end)
	end
end

function SabotageService:Start()
	if self._started then
		return
	end
	self._started = true

	self._request = remote(GameConfig.Remotes.Sabotage)
	self._cue = remote(GameConfig.Remotes.SabotageCue)

	self:_registerProducts()

	self._cleaner:add(self._request.OnServerEvent:Connect(function(player, action, itemId, targetUserId)
		local ok, err = pcall(function()
			self:_onRequest(player, action, itemId, targetUserId)
		end)
		if not ok then
			warn("[CursedBarrel] 방해 요청 처리 중 오류: " .. tostring(err))
		end
	end))

	self._cleaner:add(Players.PlayerRemoving:Connect(function(player)
		self._limiter:forget(player.UserId)
		self._cooldown[player] = nil
		self._intent[player] = nil
	end))

	local ready = 0
	for _, item in ipairs(SABOTAGE.Items) do
		if (tonumber(item.productId) or 0) > 0 then
			ready += 1
		end
	end
	GameConfig.log(("SabotageService 시작 완료 · 상품 %d/%d 개 준비됨"):format(ready, #SABOTAGE.Items))
	if ready == 0 then
		print("[CursedBarrel] 방해 아이템의 개발자 상품 ID 가 아직 비어 있습니다. "
			.. "크리에이터 대시보드에서 상품을 만들고 GameConfig.Sabotage.Items 의 productId 에 적어 주세요.")
	end
end

return SabotageService
