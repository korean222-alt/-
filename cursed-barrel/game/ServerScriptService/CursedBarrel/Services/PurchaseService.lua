-- One receipt owner. Durable reward and receipt history share a session-locked key.
local Marketplace=game:GetService("MarketplaceService")
local Players=game:GetService("Players")
local Profiles=require(script.Parent.ProfileService)
local P={_handlers={},_after={},_started=false}
-- after (Phase 15) : 결제가 확정된 뒤 한 번 부르는 함수 (예: 방해 아이템을 곧바로 쓰기). 저장과는 따로 돈다.
function P:Register(id,handler,after)
 id=tonumber(id) or 0
 if id<=0 then return false end
 assert(not self._handlers[id],"Duplicate developer product ID: "..id)
 self._handlers[id]=handler;self._after[id]=after;return true
end
function P:Start()
 if self._started then return end;self._started=true
 Marketplace.ProcessReceipt=function(receipt)
  local player=Players:GetPlayerByUserId(receipt.PlayerId)
  local handler=self._handlers[receipt.ProductId]
  if not player or not handler then return Enum.ProductPurchaseDecision.NotProcessedYet end
  if Profiles:ProcessReceipt(player,receipt,handler) then
   local after=self._after[receipt.ProductId]
   if after then task.spawn(function() local ok,err=pcall(after,player,receipt);if not ok then warn("[CursedBarrel] After purchase: "..tostring(err)) end end) end
   return Enum.ProductPurchaseDecision.PurchaseGranted
  end
  return Enum.ProductPurchaseDecision.NotProcessedYet
 end
end
return P
