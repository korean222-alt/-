-- 조절할 숫자는 여기 한 곳에 있습니다. 수정한 뒤 Stop → Play.
local C = {
    SphereRadius = 600,
    PlayRadius = 150,
    ForestWidth = 20,
    TopY = 40,
    SoilDepth = 12,
    Embed = 0.6,
    TreeSpacing = 9,
    MonsterSpeed = 5,
    MonsterNear = 14,
    MonsterEdgeInset = 12,
    MarkerDistances = {30, 60, 90, 120},
}
assert(C.PlayRadius + C.ForestWidth < C.SphereRadius, "놀이 범위가 공 반지름보다 작아야 합니다")
assert(C.MonsterSpeed > 0 and C.TreeSpacing > 0 and C.SoilDepth >= 8)
assert(C.MonsterNear < C.PlayRadius - C.MonsterEdgeInset)
local D = {Config = C}
function D.height(x, z)
    return C.TopY + math.sqrt(math.max(0, C.SphereRadius^2 - x*x - z*z)) - C.SphereRadius
end
-- 왕복 경로: 시간으로 계산하므로 프레임 속도에 의존하지 않습니다.
function D.monsterRadius(t)
    local far = C.PlayRadius - C.MonsterEdgeInset
    local span = far - C.MonsterNear
    local d = (t * C.MonsterSpeed) % (2 * span)
    return if d <= span then far - d else C.MonsterNear + d - span
end
-- 4 stud 복셀의 채움 비율. 거대한 구 대신 표면 아래 얕은 층만 생성합니다.
function D.occupancy(x, y, z)
    if x*x + z*z > (C.PlayRadius + C.ForestWidth)^2 then return 0 end
    local h = D.height(x, z)
    return math.clamp((math.min(y+2, h) - math.max(y-2, h-C.SoilDepth))/4, 0, 1)
end
return D
