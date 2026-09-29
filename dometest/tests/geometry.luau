-- 실제 게임이 사용하는 모듈을 Luau VM에서 실행합니다(물리 엔진 검사는 아님).
local D = require("../src/shared/Dome")
local C = D.Config
assert(math.abs(D.height(0,0)-C.TopY)<1e-8)
local last = C.TopY
for r=1,C.PlayRadius+C.ForestWidth do
    local h = D.height(r,0)
    assert(h <= last)
    assert(math.abs(h-D.height(0,-r))<1e-8)
    last = h
end
local filled = 0
for x=-172,172,4 do
    for z=-172,172,4 do
        local thickness = 0
        for y=-10,46,4 do
            local v = D.occupancy(x,y,z)
            assert(v>=0 and v<=1)
            thickness += v*4
            if v>0 then filled+=1 end
        end
        if x*x+z*z <= (C.PlayRadius+C.ForestWidth)^2 then
            assert(math.abs(thickness-C.SoilDepth)<1e-6, "missing soil column")
        else assert(thickness==0) end
    end
end
local far = C.PlayRadius-C.MonsterEdgeInset
local duration = (far-C.MonsterNear)/C.MonsterSpeed
assert(D.monsterRadius(0)==far)
assert(math.abs(D.monsterRadius(duration)-C.MonsterNear)<1e-6)
assert(math.abs(D.monsterRadius(duration*2)-far)<1e-6)
local previous = far
for i=1,20000 do
    local r = D.monsterRadius(i/60)
    assert(r>=C.MonsterNear and r<=far)
    assert(math.abs(r-previous)<=C.MonsterSpeed/60+1e-6)
    assert(D.height(0,-r)==D.height(r,0))
    previous = r
end
print("PASS: spherical surface, shallow voxel columns, 20000 monster path samples; filled voxels",filled)
