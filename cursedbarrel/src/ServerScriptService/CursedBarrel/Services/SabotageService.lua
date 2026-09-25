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

local ProfileService=require(script.Parent.ProfileService)
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
SabotageService._listLimiter = Utility.RateLimiter.new(0.2) -- Phase 24 : 목록 새로고침은 "사용" 과 따로 센다
SabotageService._cooldown = {} -- [Player] = 다시 쓸 수 있는 시각
-- Phase 24 : [Player] = { [itemId] = { targetUserId, at } } 상품마다 따로 기억한다.
--   (예전에는 한 칸이라 연달아 누르면 앞의 대상이 덮이고, 상품이 맞는지 보기 전에 지워졌다)
SabotageService._intent = {}
SabotageService._busy = {} -- [Player] = 사용권을 쓰는 중 (저장이 끝날 때까지 두 번 쓰지 못하게)

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

	local ok, reason = round:CanSabotage(player, target, item)
	if not ok then
		return nil, nil, nil, reason
	end

	return item, target, round, nil
end

--------------------------------------------------
-- 효과 넣기
--------------------------------------------------

-- onVoid : 예약된 방해가 발동하지 못하고 사라질 때 부른다 (사용권 환불)
function SabotageService:_apply(player, itemId, targetUserId, onVoid)
	local item, target, round, reason = self:_validate(player, itemId, targetUserId)
	if not item then
		return false, reason
	end

	local ok, why, queued = round:ApplySabotage(player, target, item, onVoid)
	if not ok then
		return false, why
	end

	self._cooldown[player] = os.clock() + SABOTAGE.Cooldown
	local name = target.DisplayName or target.Name
	if queued then
		return true, ("%s → %s (상대 차례에 발동)"):format(item.name, name)
	end
	return true, ("%s → %s"):format(item.name, name)
end

-- Phase 24 : 사용권은 "먼저 줄여서 저장하고" 쓴다.
--   예전에는 효과를 넣은 뒤 메모리에서만 줄여서, 저장 전에 서버가 꺼지면 사용권이 되살아나 다시 쓸 수 있었다.
--   · 저장에 실패하면 줄인 것을 되돌리고 쓰지 않는다.
--   · 저장 뒤 상대가 없어졌거나, 예약된 방해가 발동하지 못하고 판이 끝나면 사용권을 돌려준다.
function SabotageService:_refund(player, item)
	local profile = ProfileService:Get(player)
	if not profile or player.Parent ~= Players then
		return
	end
	profile.consumables[item.id] = (profile.consumables[item.id] or 0) + 1
	ProfileService:_touch(player)
	self._cue:FireClient(player, nil, { id = "refund", message = ("%s 사용권을 돌려받았어요 (발동하지 못함)"):format(item.name) })
	self:_sendList(player)
end

function SabotageService:_spendCharge(player, item, targetUserId)
	if self._busy[player] then
		return false, "처리 중입니다"
	end
	local profile = ProfileService:Get(player)
	if not profile or (profile.consumables[item.id] or 0) <= 0 then
		return false, "사용권이 없습니다"
	end
	local _, _, _, reason = self:_validate(player, item.id, targetUserId)
	if reason then
		return false, reason
	end
	self._busy[player] = true
	profile.consumables[item.id] -= 1
	ProfileService:_touch(player)
	-- 저장할 수 있는 자료면 쓰기 전에 저장까지 끝낸다. (Studio 처럼 저장이 없는 곳은 메모리만)
	local durable = ProfileService._writable[player] == true
	local saved = (not durable) or ProfileService:Save(player, "sabotage")
	-- 저장하는 동안 자료 표가 새로 바뀌었을 수 있다 (영수증 처리). 항상 다시 가져온다.
	profile = ProfileService:Get(player)
	if not saved then
		self._busy[player] = nil
		if profile then
			profile.consumables[item.id] = (profile.consumables[item.id] or 0) + 1
			ProfileService:_touch(player)
		end
		return false, "저장이 늦어져 쓰지 못했어요. 다시 눌러 주세요"
	end
	local ok, message = self:_apply(player, item.id, targetUserId, function()
		self:_refund(player, item)
	end)
	self._busy[player] = nil
	if not ok then
		-- 저장 사이에 상황이 바뀌었다 : 사용권을 돌려준다
		if profile then
			profile.consumables[item.id] = (profile.consumables[item.id] or 0) + 1
			ProfileService:_touch(player)
		end
	end
	return ok, message
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
            owned = (ProfileService:Get(player) and ProfileService:Get(player).consumables[item.id]) or 0,
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
	if typeof(action) ~= "string" then
		return
	end

	if action == "list" then
		-- Phase 24 : 목록은 따로 센다. (사용 직후의 새로고침이 사용 요청의 0.5초 제한에 걸려 버려지던 문제)
		if self._listLimiter:check(player.UserId) then
			self:_sendList(player)
		end
		return
	end

	if not self._limiter:check(player.UserId) then
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

	local profile=ProfileService:Get(player)
 if profile and (profile.consumables[item.id] or 0)>0 then
  local ok,message=self:_spendCharge(player,item,target.UserId)
  -- Phase 24 : 결과에 최신 목록을 함께 보낸다 (수량 · 쿨타임이 바로 맞는다)
  self._cue:FireClient(player,nil,{id=ok and "done" or "deny",message=message})
  self:_sendList(player);return
 end
 local productId = tonumber(item.productId) or 0
 if productId>0 and not ProfileService:CanPurchase(player) then self._cue:FireClient(player,nil,{id="deny",message="저장 연결이 필요합니다"});return end

 -- Studio 에서 상품을 아직 안 만들었으면 무료로 시험할 수 있다.
	if productId <= 0 then
		if SABOTAGE.StudioFreeTest and RunService:IsStudio() then
			local ok, message = self:_apply(player, item.id, target.UserId)
			self._cue:FireClient(player, nil, { id = ok and "done" or "deny", message = message })
			self:_sendList(player)
		else
			self._cue:FireClient(player, nil, { id = "deny", message = "이 아이템은 아직 준비 중입니다" })
		end
		return
	end

	-- 결제가 끝나면 무엇을 누구에게 쓸지 상품마다 기억해 둔다.
	self._intent[player] = self._intent[player] or {}
	self._intent[player][item.id] = { targetUserId = target.UserId, at = os.clock() }

	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	if not ok then
		warn("[CursedBarrel] 방해 아이템 구매창을 띄우지 못했습니다: " .. tostring(err))
		if self._intent[player] then
			self._intent[player][item.id] = nil
		end
	end
end

--------------------------------------------------
-- 결제 처리
--------------------------------------------------

function SabotageService:_registerProducts()
 for _,item in ipairs(SABOTAGE.Items) do
  PurchaseService:Register(item.productId,function(profile)
   -- Always bank a charge. (결제 기록과 한 번에 저장된다)
   profile.consumables[item.id]=(profile.consumables[item.id] or 0)+1
   return true
  end,function(player)
   -- Phase 15 : 결제가 끝나면 누른 상대에게 곧바로 쓴다. (예전에는 사 두기만 하고 "사용"을 한 번 더 눌러야 했다)
   --   그 사이 판이 끝났거나 상대가 없어졌으면 가방에 남겨 두고 알려 준다.
   -- Phase 24 : 이 상품의 기억만 꺼내 쓰고 지운다. 다른 상품의 기억은 그대로 둔다.
   --   (PurchaseService 는 영수증마다 이 함수를 한 번만 부른다)
   local byItem=self._intent[player]
   local intent=byItem and byItem[item.id]
   if byItem then byItem[item.id]=nil end
   if intent and os.clock()-intent.at<=INTENT_TTL then
    local ok,message=self:_spendCharge(player,item,intent.targetUserId)
    if ok then
     self._cue:FireClient(player,nil,{id="done",message=message})
     self:_sendList(player)
     return
    end
   end
   local profile=ProfileService:Get(player)
   local count=profile and (profile.consumables[item.id] or 0) or 0
   self._cue:FireClient(player,nil,{id="done",message=("%s 구매 완료 · 가방 %d개 (상대가 없어 보관)"):format(item.name,count)})
   self:_sendList(player)
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
		self._listLimiter:forget(player.UserId)
		self._cooldown[player] = nil
		self._intent[player] = nil
		self._busy[player] = nil
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
