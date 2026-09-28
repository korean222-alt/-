return {
    PerExtraPlayer = 0.35,
    HealthPerNight = 0.10,
    DamagePerNight = 0.06,
    SpawnInterval = 2,
    Waves = {
        {{Kind = "Crawler", Count = 8}},
        {{Kind = "Crawler", Count = 12}, {Kind = "Runner", Count = 4}, {Kind = "Brute", Count = 1}},
        {{Kind = "Howler", Count = 1, Boss = true}, {Kind = "Crawler", Count = 10}, {Kind = "Runner", Count = 4}},
    },
}
