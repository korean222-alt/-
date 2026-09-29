return {
    ActiveLimit = 3, ServerLimit = 18, CollectionLimit = 100, PendingLimit = 8,
    MaxLevel = 40, RegionCap = 10, Growth = 0.07, SwapCooldown = 6,
    -- 성장형: 새끼(Stage 1) → 성체(Stage 2). EvolveLevel 이 되면 진화해서 커지고 강해진다 (야생도 이 레벨 이상이면 성체).
    -- 성체 모델: ReplicatedStorage.PetModels/<종>_Adult 가 있으면 그것, 없으면 새끼 모델을 Scale 배로 키워서 쓴다.
    EvolveLevel = 6,
    FollowSpeed = 18, Leash = 70, Aggro = 24, DayRecovery = 30,
    StandDamage = 1.2, StandRange = 1.25, CaptureHP = 0.25,
    CaptureRange = 16, CaptureSeconds = 2.4, ExhaustSeconds = 40,
    FirstCaptureGuaranteed = true, FailBonus = 0.07, ChanceCap = 0.95,
    NightXP = 35, CaptureXP = 12, KillXP = 3, NightCoins = 30, ClearCoins = 60,
    Order = {"Mossling", "Emberpup", "Shellbub", "Mossdeer", "Ashlizard", "Bogtoad", "Briarhorn"},
    Species = {
        Mossling = {Name = "모슬링", Element = "Leaf", Role = "근접", HP = 110, Damage = 13, Range = 5, Interval = 0.8, Capture = 0.65, Color = {131,207,133}, Adult = {Name = "모스팽", HP = 1.6, Damage = 1.45, Scale = 1.5}},
        Emberpup = {Name = "엠버펍", Element = "Ember", Role = "원거리", HP = 85, Damage = 18, Range = 25, Interval = 1.4, Splash = 7, Capture = 0.48, Color = {246,151,103}, Adult = {Name = "신더팽", HP = 1.55, Damage = 1.5, Scale = 1.45}},
        Shellbub = {Name = "셸버브", Element = "Tide", Role = "탱커", HP = 240, Damage = 9, Range = 5, Interval = 1.3, Taunt = 18, Capture = 0.48, Color = {116,186,229}, Adult = {Name = "타이드가드", HP = 1.7, Damage = 1.35, Scale = 1.5}},
        -- 지역 펫 (블렌더/Meshy 모델이 없으면 파트 대체 모델)
        Mossdeer = {Name = "이끼사슴", Element = "Leaf", Role = "돌격", HP = 130, Damage = 20, Range = 6, Interval = 0.9, Capture = 0.4, Color = {122,90,62}, Adult = {Name = "고목사슴왕", HP = 1.55, Damage = 1.5, Scale = 1.35}},
        Ashlizard = {Name = "애쉬리자드", Element = "Ember", Role = "범위", HP = 150, Damage = 16, Range = 8, Interval = 1.3, Splash = 9, Capture = 0.4, Color = {74,74,80}, Adult = {Name = "용암드레이크", HP = 1.6, Damage = 1.45, Scale = 1.5}},
        Bogtoad = {Name = "보그토드", Element = "Tide", Role = "원거리", HP = 125, Damage = 14, Range = 22, Interval = 1.2, Capture = 0.45, Color = {63,106,90}, Adult = {Name = "늪군주", HP = 1.6, Damage = 1.45, Scale = 1.45}},
        Briarhorn = {Name = "브라이어혼 α", Element = "Leaf", Role = "알파", HP = 420, Damage = 26, Range = 7, Interval = 1.5, Splash = 8, Capture = 0.25, Color = {192,158,226}, Adult = {Name = "쏜로드 α", HP = 1.5, Damage = 1.4, Scale = 1.25}},
    },
    -- 야생 스폰 자리는 MapConfig (StarterWild, Wild, Grove)
    -- 종별 게임 속 키(stud). 블렌더 모델과 대체 모델 모두 이 높이로 맞춘다.
    Heights = {Mossling = 2.9, Emberpup = 3.3, Shellbub = 2.2, Briarhorn = 7.8, Mossdeer = 4.2, Ashlizard = 1.9, Bogtoad = 2.1},
}
