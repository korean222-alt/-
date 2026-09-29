-- 밤 웨이브 (초원 원정 5밤). 밤 5 에 보스 The Howler.
return {
    PerExtraPlayer = 0.35,
    HealthPerNight = 0.10,
    DamagePerNight = 0.06,
    SpawnInterval = 2,
    SoloHealth = 0.8, -- 혼자 할 때 괴물 체력 배율 (혼자서도 버틸 수 있게)
    Waves = {
        {{Kind = "Crawler", Count = 8}},
        {{Kind = "Crawler", Count = 12}, {Kind = "Runner", Count = 4}, {Kind = "Brute", Count = 1}},
        {{Kind = "Crawler", Count = 14}, {Kind = "Runner", Count = 6}, {Kind = "Brute", Count = 2}},
        {{Kind = "Crawler", Count = 16}, {Kind = "Runner", Count = 8}, {Kind = "Brute", Count = 3}},
        {{Kind = "Howler", Count = 1, Boss = true}, {Kind = "Crawler", Count = 14}, {Kind = "Runner", Count = 6}, {Kind = "Brute", Count = 2}},
    },
}
