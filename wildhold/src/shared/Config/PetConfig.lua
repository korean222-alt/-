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
    -- 개체 차이 (포켓몬 개체값·이로치 참고): 같은 종이라도 잡을 때마다 다르다 → "더 좋은 한 마리" 를 찾는 재미
    --  재능 별 1~5: 체력·공격 배율. 야생은 Weights 확률로, 알은 EggConfig 의 확률로
    Stars = {Weights = {30, 32, 22, 11, 5}, Mult = {0.9, 1.0, 1.1, 1.22, 1.38}},
    ShinyChance = 1 / 200, -- 빛나는 변종 (야생). 색이 다르고 반짝인다
    -- 특성 1개 (성격). 배율은 PetRules.stats / PetService 에서 쓴다
    TraitOrder = {"Brave", "Sturdy", "Swift", "Clever", "Loyal", "Hunter"},
    Traits = {
        Brave = {Name = "용감함", Icon = "⚔", Desc = "공격 +15%", Damage = 1.15},
        Sturdy = {Name = "튼튼함", Icon = "🛡", Desc = "체력 +20%", HP = 1.2},
        Swift = {Name = "날쌤", Icon = "💨", Desc = "공격 속도 +12%", Interval = 0.88},
        Clever = {Name = "영리함", Icon = "🧠", Desc = "경험치 +30%", XP = 1.3},
        Loyal = {Name = "충직함", Icon = "💚", Desc = "기절해도 두 배 빨리 회복", Recover = 0.5},
        Hunter = {Name = "사냥꾼", Icon = "🎯", Desc = "야생 펫에게 피해 +25%", WildDamage = 1.25},
    },
    NicknameMax = 12, -- 이름 짓기 최대 글자 수
    -- 포획 전투력 (Palworld 레벨 차이 · ARK 기절시키기 참고): 강한 야생 펫은 도구만으로 못 잡는다.
    --  사람 도구로는 HP 를 HuntFloor 아래로 못 깎는다 → 펫이 약화시켜야 한다 (약한 여러 마리 또는 강한 한 마리)
    --  포획 확률 × (우리 팀 전투력 / 야생 전투력)^PowerExponent (PowerMin~PowerMax), PowerGate 미만이면 포획 불가
    HuntFloor = 0.6, PowerGate = 0.45, PowerExponent = 1.3, PowerMin = 0.3, PowerMax = 1.25, HelpRange = 40,
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
