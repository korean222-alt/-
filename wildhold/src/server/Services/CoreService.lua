local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config.GameConfig)
local Core = {}
function Core:Init(ctx) self.ctx = ctx; self:Reset() end
function Core:Reset() self.HP = C.CoreHP; self:Update() end
function Core:Update()
    self.ctx.Map.Core:SetAttribute("CurrentHealth", self.HP)
    self.ctx.Map.Core:SetAttribute("MaxHealth", C.CoreHP)
end
function Core:Damage(amount)
    if self.ctx.Clock.Phase ~= "Night" or self.HP <= 0 then return end
    self.HP = math.max(0, self.HP - amount)
    self.ctx.Map.Core:SetAttribute("HitAt", workspace:GetServerTimeNow())
    self:Update()
    if self.HP == 0 then self.ctx.Run:Finish(false, {k = "run.coreDestroyed"}) end
end
return Core
