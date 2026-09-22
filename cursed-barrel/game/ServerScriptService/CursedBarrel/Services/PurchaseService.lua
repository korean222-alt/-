-- One receipt owner. Durable reward and receipt history share a session-locked key.
local Marketplace=game:GetService("MarketplaceService")
local Players=game:GetService("Players")
local Profiles=require(script.Parent.ProfileService)
local P={_handlers={},_started=false}
function P:Register(id,handler)
 id=tonumber(id) or 0
 if id<=0 then return false end
 assert(not self._handlers[id],"Duplicate developer product ID: "..id)
 self._handlers[id]=handler;return true
end
function P:Start()
 if self._started then return end;self._started=true
 Marketplace.ProcessReceipt=function(receipt)
  local player=Players:GetPlayerByUserId(receipt.PlayerId)
  local handler=self._handlers[receipt.ProductId]
  if not player or not handler then return Enum.ProductPurchaseDecision.NotProcessedYet end
  if Profiles:ProcessReceipt(player,receipt,handler) then return Enum.ProductPurchaseDecision.PurchaseGranted end
  return Enum.ProductPurchaseDecision.NotProcessedYet
 end
end
return P
