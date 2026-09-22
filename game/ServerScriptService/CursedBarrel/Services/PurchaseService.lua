--[[
	PurchaseService  (Phase 7)
	로벅스 결제(개발자 상품) 영수증을 한 곳에서 처리한다.

	MarketplaceService.ProcessReceipt 는 서버 전체에서 딱 하나만 둘 수 있다.
	상점과 방해 아이템이 각자 붙이려 하면 뒤에 붙인 쪽이 앞을 덮어버리고,
	덮인 쪽의 결제는 영원히 처리되지 않는다. (환불 문의로 돌아온다)
	그래서 이 파일이 유일한 주인이 되고, 나머지는 여기에 "등록"만 한다.

	중복 지급 방지
	  Roblox 는 지급이 확인될 때까지 같은 영수증을 계속 다시 보낸다.
	  이미 처리한 PurchaseId 를 DataStore 에 적어 두고, 같은 것이 오면 지급 없이 성공만 돌려준다.
	  DataStore 가 막혀 있으면 서버 메모리로만 막는다. (그 서버 안에서는 안전하다)
]]

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CursedBarrel"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local PurchaseService = {}
PurchaseService._handlers = {} -- [productId] = function(player, receiptInfo) -> boolean
PurchaseService._seen = {} -- [purchaseId] = true (이 서버에서 처리한 것)
PurchaseService._store = nil
PurchaseService._started = false

local function receiptStore()
	if PurchaseService._store == nil then
		local ok, store = pcall(function()
			return DataStoreService:GetDataStore("CursedBarrel_Receipts_v1")
		end)
		PurchaseService._store = ok and store or false
	end
	return PurchaseService._store or nil
end

--[[
	productId 가 0 이면 아직 만들지 않은 상품이다. 등록하지 않는다.
	handler 는 지급에 성공하면 true 를 돌려줘야 한다.
	false 를 돌려주면 Roblox 가 나중에 다시 보낸다.
]]
function PurchaseService:Register(productId, handler)
	productId = tonumber(productId) or 0
	if productId <= 0 or typeof(handler) ~= "function" then
		return false
	end
	if self._handlers[productId] then
		warn(("[CursedBarrel] 상품 %d 이 두 번 등록되었습니다. 나중 것을 씁니다."):format(productId))
	end
	self._handlers[productId] = handler
	return true
end

function PurchaseService:_alreadyGranted(purchaseId)
	if self._seen[purchaseId] then
		return true
	end
	local store = receiptStore()
	if not store then
		return false
	end
	local ok, value = pcall(function()
		return store:GetAsync(purchaseId)
	end)
	return ok and value == true
end

function PurchaseService:_remember(purchaseId)
	self._seen[purchaseId] = true
	local store = receiptStore()
	if not store then
		return
	end
	pcall(function()
		store:UpdateAsync(purchaseId, function()
			return true
		end)
	end)
end

function PurchaseService:Start()
	if self._started then
		return
	end
	self._started = true

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local purchaseId = tostring(receiptInfo.PurchaseId)

		-- 이미 지급했던 영수증이면 지급 없이 성공만 알린다.
		local seen = false
		local okSeen, result = pcall(function()
			return self:_alreadyGranted(purchaseId)
		end)
		if okSeen then
			seen = result
		end
		if seen then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local player = game:GetService("Players"):GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			-- 산 사람이 이미 나갔다. 다시 들어왔을 때 처리하도록 미룬다.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local handler = self._handlers[receiptInfo.ProductId]
		if not handler then
			warn(("[CursedBarrel] 등록되지 않은 상품 %d 결제가 들어왔습니다."):format(receiptInfo.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local ok, granted = pcall(handler, player, receiptInfo)
		if not ok then
			warn("[CursedBarrel] 결제 처리 중 오류: " .. tostring(granted))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		pcall(function()
			self:_remember(purchaseId)
		end)
		GameConfig.log(("%s 결제 처리 완료 · 상품 %d"):format(player.Name, receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	GameConfig.log("PurchaseService 시작 완료")
end

return PurchaseService
