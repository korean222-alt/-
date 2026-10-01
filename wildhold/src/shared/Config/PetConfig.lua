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
        Brave = {Icon = "⚔", Damage = 1.15},
        Sturdy = {Icon = "🛡", HP = 1.2},
        Swift = {Icon = "💨", Interval = 0.88},
        Clever = {Icon = "🧠", XP = 1.3},
        Loyal = {Icon = "💚", Recover = 0.5},
        Hunter = {Icon = "🎯", WildDamage = 1.25},
    },
    NicknameMax = 12, -- 이름 짓기 최대 글자 수
    -- 전투 재미 (도파민 포인트): 치명타 · 필살기 게이지 · 속성 상성 표시 · 콤보 · KO · 레벨 업 연출
    --  치명타: 확률 = Chance + (별 - 1) × StarBonus. 피해 × Mult, 큰 노란 숫자 + 화면 흔들림
    Crit = {Chance = 0.12, StarBonus = 0.02, Mult = 1.75},
    --  필살기 게이지: 때릴 때 PerHit (치명타면 + Crit), 맞을 때 Hurt. Max 가 되면 다음 공격이 종별 필살기
    Energy = {PerHit = 17, Crit = 10, Hurt = 6, Max = 100},
    --  필살기: 피해 × Mult, Radius > 0 이면 밤 괴물에게 범위 피해(× Splash). 성체는 × AdultBonus. 이름은 Locale "skill.<종>"
    SkillAdultBonus = 1.2,
    Skills = {
        Mossling = {Mult = 2.6, Radius = 0, Splash = 0},
        Emberpup = {Mult = 2.2, Radius = 10, Splash = 0.6},
        Shellbub = {Mult = 2.0, Radius = 11, Splash = 0.7},
        Mossdeer = {Mult = 3.2, Radius = 0, Splash = 0},
        Ashlizard = {Mult = 2.2, Radius = 12, Splash = 0.6},
        Bogtoad = {Mult = 2.5, Radius = 7, Splash = 0.6},
        Briarhorn = {Mult = 2.6, Radius = 14, Splash = 0.7},
    },
    ComboWindow = 2.5, -- 이 시간 안에 다음 타격이 이어지면 콤보 (화면 표시만)
    -- 포획 전투력 (Palworld 레벨 차이 · ARK 기절시키기 참고): 강한 야생 펫은 도구만으로 못 잡는다.
    --  사람 도구로는 HP 를 HuntFloor 아래로 못 깎는다 → 펫이 약화시켜야 한다 (약한 여러 마리 또는 강한 한 마리)
    --  포획 확률 × (우리 팀 전투력 / 야생 전투력)^PowerExponent (PowerMin~PowerMax), PowerGate 미만이면 포획 불가
    HuntFloor = 0.6, PowerGate = 0.45, PowerExponent = 1.3, PowerMin = 0.3, PowerMax = 1.25, HelpRange = 40,
    Order = {"Mossling", "Emberpup", "Shellbub", "Mossdeer", "Ashlizard", "Bogtoad", "Briarhorn"},
    Species = {
        Mossling = {Element = "Leaf", Role = "Melee", HP = 110, Damage = 13, Range = 5, Interval = 0.8, Capture = 0.65, Color = {131,207,133}, Adult = {HP = 1.6, Damage = 1.45, Scale = 1.5}},
        Emberpup = {Element = "Ember", Role = "Ranged", HP = 85, Damage = 18, Range = 25, Interval = 1.4, Splash = 7, Capture = 0.48, Color = {246,151,103}, Adult = {HP = 1.55, Damage = 1.5, Scale = 1.45}},
        Shellbub = {Element = "Tide", Role = "Tank", HP = 240, Damage = 9, Range = 5, Interval = 1.3, Taunt = 18, Capture = 0.48, Color = {116,186,229}, Adult = {HP = 1.7, Damage = 1.35, Scale = 1.5}},
        -- 지역 펫 (블렌더/Meshy 모델이 없으면 파트 대체 모델)
        Mossdeer = {Element = "Leaf", Role = "Charger", HP = 130, Damage = 20, Range = 6, Interval = 0.9, Capture = 0.4, Color = {122,90,62}, Adult = {HP = 1.55, Damage = 1.5, Scale = 1.35}},
        Ashlizard = {Element = "Ember", Role = "Area", HP = 150, Damage = 16, Range = 8, Interval = 1.3, Splash = 9, Capture = 0.4, Color = {74,74,80}, Adult = {HP = 1.6, Damage = 1.45, Scale = 1.5}},
        Bogtoad = {Element = "Tide", Role = "Ranged", HP = 125, Damage = 14, Range = 22, Interval = 1.2, Capture = 0.45, Color = {63,106,90}, Adult = {HP = 1.6, Damage = 1.45, Scale = 1.45}},
        Briarhorn = {Element = "Leaf", Role = "Alpha", HP = 420, Damage = 26, Range = 7, Interval = 1.5, Splash = 8, Capture = 0.25, Color = {192,158,226}, Adult = {HP = 1.5, Damage = 1.4, Scale = 1.25}},
    },
    -- 야생 스폰 자리는 MapConfig (StarterWild, Wild, Grove)
    -- 종별 게임 속 키(stud). 블렌더 모델과 대체 모델 모두 이 높이로 맞춘다.
    Heights = {Mossling = 2.9, Emberpup = 3.3, Shellbub = 2.2, Briarhorn = 7.8, Mossdeer = 4.2, Ashlizard = 1.9, Bogtoad = 2.1},
}
