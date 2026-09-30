-- 구조물 능력치. Levels[1].Cost 는 쓰지 않는다 (처음 설치는 제작대에서 만든 설치 도구로). Levels[2~] 의 Cost = 강화 비용.
-- 벽·문·포탑·함정의 Lv2·3 강화는 제작대 Lv2·3 이 있어야 한다 (DefenseService:BenchNeeded).
return {
    Workbench = {Levels = {
        {HP = 300, Repair = {Wood = 3}},
        {HP = 450, Cost = {Wood = 40, Stone = 25, Fiber = 10}, Repair = {Wood = 3, Stone = 2}},
        {HP = 650, Cost = {Stone = 40, Scrap = 20, Crystal = 5}, Repair = {Stone = 3, Scrap = 2}},
    }},
    Wall = {Size = {11, 6, 3}, Blocks = true, Levels = {
        {HP = 250, Cost = {Wood = 10}, Repair = {Wood = 3}},
        {HP = 450, Cost = {Wood = 8, Stone = 10}, Repair = {Wood = 2, Stone = 2}},
        {HP = 750, Cost = {Stone = 12, Scrap = 6}, Repair = {Stone = 3, Scrap = 1}},
    }},
    Gate = {Size = {11, 6, 2}, Blocks = true, Levels = {
        {HP = 220, Cost = {Wood = 8}, Repair = {Wood = 3}},
        {HP = 400, Cost = {Wood = 6, Stone = 10}, Repair = {Wood = 2, Stone = 2}},
    }},
    ArrowTower = {Size = {4, 10, 4}, Levels = {
        {HP = 180, Damage = 16, Range = 42, Interval = 1.1, Cost = {Wood = 15, Stone = 5}, Repair = {Wood = 4}},
        {HP = 260, Damage = 25, Range = 47, Interval = 0.9, Cost = {Wood = 12, Stone = 8, Scrap = 3}, Repair = {Wood = 3, Stone = 2}},
        {HP = 380, Damage = 36, Range = 52, Interval = 0.75, Cost = {Stone = 12, Scrap = 8}, Repair = {Stone = 3, Scrap = 2}},
    }},
    SpikeTrap = {Size = {9, 1, 9}, Levels = {
        {HP = 140, Damage = 12, Range = 6, Interval = 1.5, Cost = {Wood = 8, Stone = 4}, Repair = {Wood = 2}},
        {HP = 220, Damage = 23, Range = 7, Interval = 1.2, Cost = {Stone = 8, Scrap = 3}, Repair = {Stone = 2}},
    }},
    PetStand = {Levels = {
        {HP = 200, Repair = {Stone = 2}},
    }},
    TorchPost = {Levels = {
        {HP = 80, Repair = {Wood = 1}},
    }},
}
