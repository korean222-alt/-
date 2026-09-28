return {
    ActiveLimit = 3, ServerLimit = 18, CollectionLimit = 100, PendingLimit = 8,
    MaxLevel = 40, RegionCap = 10, Growth = 0.07, SwapCooldown = 6,
    FollowSpeed = 18, Leash = 70, Aggro = 24, DayRecovery = 30,
    StandDamage = 1.2, StandRange = 1.25, CaptureHP = 0.25,
    CaptureRange = 16, CaptureSeconds = 2.4, ExhaustSeconds = 40,
    FirstCaptureGuaranteed = true, FailBonus = 0.07, ChanceCap = 0.95,
    NightXP = 35, CaptureXP = 12, KillXP = 3, NightCoins = 30, ClearCoins = 60,
    Order = {"Mossling", "Emberpup", "Shellbub", "Briarhorn"},
    Species = {
        Mossling = {Name = "모슬링", Element = "Leaf", Role = "근접", HP = 110, Damage = 13, Range = 5, Interval = 0.8, Capture = 0.65, Color = {131,207,133}},
        Emberpup = {Name = "엠버펍", Element = "Ember", Role = "원거리", HP = 85, Damage = 18, Range = 25, Interval = 1.4, Splash = 7, Capture = 0.48, Color = {246,151,103}},
        Shellbub = {Name = "셸버브", Element = "Tide", Role = "탱커", HP = 240, Damage = 9, Range = 5, Interval = 1.3, Taunt = 18, Capture = 0.48, Color = {116,186,229}},
        Briarhorn = {Name = "브라이어혼 α", Element = "Leaf", Role = "알파", HP = 420, Damage = 26, Range = 7, Interval = 1.5, Splash = 8, Capture = 0.25, Color = {192,158,226}},
    },
    -- 야생 스폰: {종, 레벨, x, z}. 모슬링 초원(남쪽) → 엠버펍 바위지대(북동) → 셸버브 연못(북서) → 알파의 숲(남쪽 끝)
    Spawns = {
        {"Mossling",1,6,56},{"Mossling",1,-12,60},{"Mossling",2,26,70},
        {"Mossling",2,-36,74},{"Mossling",3,8,82},
        {"Emberpup",3,60,-40},{"Emberpup",4,84,-58},
        {"Shellbub",3,-66,-40},{"Shellbub",4,-92,-62},
        {"Briarhorn",6,0,118},
    },
    -- 종별 게임 속 키(stud). 블렌더 모델과 대체 모델 모두 이 높이로 맞춘다.
    Heights = {Mossling = 2.9, Emberpup = 3.3, Shellbub = 2.2, Briarhorn = 7.8},
}
