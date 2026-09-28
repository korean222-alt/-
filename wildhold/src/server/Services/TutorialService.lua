local S={}
function S:Init(ctx) self.ctx=ctx end
function S:Objective(player)
    local profile=self.ctx.Data:Get(player);if not profile then return "데이터 불러오는 중" end
    if self.ctx.Clock.Phase=="Night" then return "🌙 펫을 배치대에 올리고 길목을 지키세요 · 쓰러진 펫은 새벽에 회복" end
    if not profile.Tutorial.Captured then return "① 기지 문 밖 초원에서 '야생 모슬링' 이름표를 찾아 [E] 사냥 → HP 25% 이하가 되면 [E] 덫 던지기 (첫 포획은 성공 보장)" end
    for _,rec in pairs(self.ctx.Pets.Rosters[player] or {}) do
        if not rec.Secured and not rec.PendingSave then return rec.Registered and "③ 등록 완료! 밤을 버티면 영구 확정 · 그동안 나무·돌을 모아 창고에 넣고 벽을 지으세요" or "② 기지 안 🐾 펫 우리에서 [E] 등록하세요 · 등록 전에는 아직 내 펫이 아닙니다" end
    end
    if not profile.Tutorial.Survived then return "③ 창으로 나무·돌 채집 → 공용 창고 → 빈 자리에서 [E] 건설 · 첫날 밤을 버티세요" end
    return "바위지대의 엠버펍·연못의 셸버브를 잡아 팀을 꾸리고, 큰 고목이 있는 알파의 숲에 도전하세요"
end
return S
