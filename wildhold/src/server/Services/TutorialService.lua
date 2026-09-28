local S={}
function S:Init(ctx) self.ctx=ctx end
function S:Objective(player)
    local profile=self.ctx.Data:Get(player);if not profile then return "데이터 불러오는 중" end
    if self.ctx.Clock.Phase=="Night" then return "펫을 길목에 배치하세요 · 쓰러진 펫은 새벽에 회복됩니다" end
    if not profile.Tutorial.Captured then return "① 가까운 모슬링 → E 또는 야생 탭 → 약화 후 포획 (첫 모슬링은 성공 보장)" end
    for _,rec in pairs(self.ctx.Pets.Rosters[player] or {}) do
        if not rec.Secured and not rec.PendingSave then return rec.Registered and "③ 등록 완료! 밤을 버텨 펫을 영구 확정하세요" or "② 기지의 펫 우리에서 등록하세요 · 원정 실패 전에는 아직 내 펫이 아닙니다" end
    end
    if not profile.Tutorial.Survived then return "③ 펫과 시설로 첫날 밤을 버티세요" end
    return "팀을 편성해 강한 펫에 도전하세요 · 포탑은 고정 방어, 펫은 이동 전력"
end
return S
