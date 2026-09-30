-- 첫 판 안내: 목표 카드 문장 + 지금 가야 할 곳(목표 표시). 처음 30초 안에 "뭘 해야 하는지" 보이게 한다.
local RS=game:GetService("ReplicatedStorage")
local U=require(RS.Shared.Modules.Utility)
local G=require(RS.Shared.Config.GameConfig)
local L=require(RS.Shared.Modules.Locale)
-- 문장은 번역 메시지 (Locale "tut.*"), 각 플레이어 화면에서 그 사람 언어로
local S={}
function S:Init(ctx) self.ctx=ctx end
function S:NoBench() return self.ctx.Defenses and self.ctx.Defenses:BenchLevel()==0 end
function S:Objective(player)
    local profile=self.ctx.Data:Get(player);if not profile then return L.M("tut.loading") end
    if self.ctx.Clock.Phase=="Night" then return L.M("tut.night") end
    if not profile.Tutorial.Captured then return L.M("tut.capture") end
    for _,rec in pairs(self.ctx.Pets.Rosters[player] or {}) do
        if not rec.Secured and not rec.PendingSave then return L.M(rec.Registered and (self:NoBench() and "tut.registeredBench" or "tut.registeredWalls") or "tut.register") end
    end
    if not profile.Tutorial.Survived then
        if self:NoBench() then return L.M("tut.bench") end
        return L.M("tut.walls")
    end
    return L.M("tut.explore")
end
-- 지금 가야 할 곳 (없으면 nil). 반환: 위치, 이름
function S:Target(player)
    local profile=self.ctx.Data:Get(player)
    local root=U.aliveRoot(player)
    if not profile or not root then return nil end
    local clock=self.ctx.Clock
    local home=self.ctx.Map.Core.Position
    local far=(root.Position-home).Magnitude>70
    if clock.Phase=="Night" then return far and home or nil,L.M("goal.base") end
    if clock.Phase~="Day" then return nil end
    if far and clock:Remaining()<=G.WarningSeconds/clock:Scale() then return home,L.M("goal.returnBase") end
    if not profile.Tutorial.Captured then
        local best,distance=nil,math.huge
        for _,wild in pairs(self.ctx.Capture.Wild) do
            local d=(wild.Part.Position-root.Position).Magnitude
            if wild.SpeciesId=="Mossling" and wild.Stage==1 and d<distance then best,distance=wild,d end
        end
        return best and best.Part.Position,L.M("goal.wildMossling")
    end
    for _,rec in pairs(self.ctx.Pets.Rosters[player] or {}) do
        if not rec.Secured and not rec.PendingSave and not rec.Registered then return self.ctx.Map.Cage.Position,L.M("place.cage") end
    end
    if not profile.Tutorial.Survived then
        local bag=self.ctx.Resources.Bags[player] or {}
        local total=0;for _,n in pairs(bag) do total=total+n end
        if self:NoBench() and (bag.Wood or 0)>=8 then return self.ctx.Map.Core.Position+Vector3.new(0,0,-26),L.M("goal.benchSpot") end
        if total>=20 then return self.ctx.Map.Warehouse.Position,L.M("sign.warehouse") end
        local best,distance=nil,math.huge
        for _,node in ipairs(self.ctx.Map.Nodes) do
            local d=(node.Part.Position-root.Position).Magnitude
            if node.Kind=="Wood" and node.HP>0 and d<distance then best,distance=node,d end
        end
        return best and best.Part.Position,L.M("goal.tree")
    end
    return nil
end
return S
