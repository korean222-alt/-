-- 첫 판 안내: 목표 카드 문장 + 지금 가야 할 곳(목표 표시). 처음 30초 안에 "뭘 해야 하는지" 보이게 한다.
local RS=game:GetService("ReplicatedStorage")
local U=require(RS.Shared.Modules.Utility)
local G=require(RS.Shared.Config.GameConfig)
local S={}
function S:Init(ctx) self.ctx=ctx end
function S:Objective(player)
    local profile=self.ctx.Data:Get(player);if not profile then return "데이터 불러오는 중" end
    if self.ctx.Clock.Phase=="Night" then return "🌙 펫을 배치대에 올리고 길목을 지키세요 · 쓰러진 펫은 새벽에 회복" end
    if not profile.Tutorial.Captured then return "① 노란 표시를 따라 문 밖 '야생 모슬링'에게 가서 [E] 사냥 → HP가 25% 아래로 떨어지면 [E] 로 덫 던지기 (첫 포획은 성공 보장)" end
    for _,rec in pairs(self.ctx.Pets.Rosters[player] or {}) do
        if not rec.Secured and not rec.PendingSave then return rec.Registered and "③ 등록 완료! 밤을 버티면 영구 확정 · 그동안 🪓도끼로 나무, 돌을 모아 창고에 넣고 벽을 지으세요" or "② 기지 안 🐾 펫 우리에서 [E] 등록하세요 · 등록 전에는 아직 내 펫이 아닙니다" end
    end
    if not profile.Tutorial.Survived then return "③ 🪓도끼로 나무·돌 채집 → 공용 창고 → 제작대에서 돌 도구·횃불 → 빈 자리에 [E] 건설 · 첫날 밤을 버티세요" end
    return "멀리 갈수록 강한 펫과 귀한 재료 · 🌋북쪽 협곡(엠버펍·수정) 💧남서 늪(셸버브) 🌲남동 고목의 숲 깊은 곳(브라이어혼 α) · 제작대 Lv2·3으로 고철·수정 도구"
end
-- 지금 가야 할 곳 (없으면 nil). 반환: 위치, 이름
function S:Target(player)
    local profile=self.ctx.Data:Get(player)
    local root=U.aliveRoot(player)
    if not profile or not root then return nil end
    local clock=self.ctx.Clock
    local home=self.ctx.Map.Core.Position
    local far=(root.Position-home).Magnitude>70
    if clock.Phase=="Night" then return far and home or nil,"기지" end
    if clock.Phase~="Day" then return nil end
    if far and clock:Remaining()<=G.WarningSeconds/clock:Scale() then return home,"기지로 돌아가기" end
    if not profile.Tutorial.Captured then
        local best,distance=nil,math.huge
        for _,wild in pairs(self.ctx.Capture.Wild) do
            local d=(wild.Part.Position-root.Position).Magnitude
            if wild.SpeciesId=="Mossling" and wild.Stage==1 and d<distance then best,distance=wild,d end
        end
        return best and best.Part.Position,"야생 모슬링"
    end
    for _,rec in pairs(self.ctx.Pets.Rosters[player] or {}) do
        if not rec.Secured and not rec.PendingSave and not rec.Registered then return self.ctx.Map.Cage.Position,"펫 우리" end
    end
    if not profile.Tutorial.Survived then
        local bag=self.ctx.Resources.Bags[player] or {}
        local total=0;for _,n in pairs(bag) do total=total+n end
        if total>=20 then return self.ctx.Map.Warehouse.Position,"공용 창고" end
        local best,distance=nil,math.huge
        for _,node in ipairs(self.ctx.Map.Nodes) do
            local d=(node.Part.Position-root.Position).Magnitude
            if node.Kind=="Wood" and node.HP>0 and d<distance then best,distance=node,d end
        end
        return best and best.Part.Position,"나무 (도끼)"
    end
    return nil
end
return S
