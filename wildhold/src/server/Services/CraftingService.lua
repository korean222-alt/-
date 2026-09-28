local RS=game:GetService("ReplicatedStorage")
local C=require(RS.Shared.Config.RecipeConfig)
local G=require(RS.Shared.Config.GameConfig)
local R=require(RS.Shared.Modules.PetRules)
local U=require(RS.Shared.Modules.Utility)
local S={}
function S:Init(ctx) self.ctx,self.Items,self.Last=ctx,{},{} end
function S:AddPlayer(player) self.Items[player]=R.copy(C.Starter) end
function S:RemovePlayer(player) self.Items[player],self.Last[player]=nil,nil end
function S:Reset() for player in pairs(self.Items) do self:AddPlayer(player) end end
function S:Use(player,item)
    local inventory=self.Items[player]
    if inventory and (inventory[item] or 0)>0 then inventory[item]=inventory[item]-1;return true end
    return false
end
function S:Craft(player,item)
    if G.ActiveStage<6 or type(item)~="string" or not C.Recipes[item] or not self.ctx.Data:Ready(player) then return end
    if not self.ctx.Run:IsParticipant(player) or self.ctx.Clock.Phase~="Day" then return end
    if os.clock()-(self.Last[player] or -100)<0.4 then return end
    self.Last[player]=os.clock()
    if not U.near(player,self.ctx.Map.Workbench.Position,G.InteractionRange) then self.ctx.Notify(player,"기지 제작대 근처에서 제작할 수 있습니다.");return end
    local items=self.Items[player];if not items or items[item]>=C.Limit then return end
    if self.ctx.Resources:Spend(C.Recipes[item].Cost) then items[item]=items[item]+1;self.ctx.Notify(player,C.Recipes[item].Name.." 제작 완료")
    else self.ctx.Notify(player,"공용 창고의 재료가 부족합니다.") end
end
return S
