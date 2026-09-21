--!strict
-- 졸졸 동물 기차 / 공용 설정값
-- 게임의 모든 숫자값은 이 파일 한 곳에서만 바꿉니다.

local Config = {}

--=========================================================
-- 저장 (8단계)
--=========================================================
Config.Data = {
	StoreName = "AnimalTrain_Player", -- DataStore 이름
	Version = 2, -- 저장 구조 버전 (구조가 바뀌면 올립니다)
	AutoSaveInterval = 120, -- 자동 저장 간격(초)
	MaxRetries = 4, -- 저장/불러오기 재시도 횟수
	RetryWait = 2, -- 재시도 대기 시간(초, 실패할수록 2배)
}

--=========================================================
-- 기차 (4단계)
--=========================================================
Config.Train = {
	BaseMaxLength = 10, -- 기차 최대 길이 (기본)
	Spacing = 4, -- 앞 동물과의 간격 (스터드)
	Smoothness = 9, -- 클수록 빠르게 따라붙음 (부드러움)
	TrailStep = 0.4, -- 발자취를 남기는 최소 거리
	TrailExtra = 10, -- 발자취를 여유있게 보관할 길이
	HopHeight = 0.55, -- 폴짝 뛰는 높이
	HopSpeed = 11, -- 폴짝 빈도
	RootHeight = 3, -- 플레이어 허리(HumanoidRootPart)가 땅에서 떠 있는 높이
	TurnSpeed = 9, -- 몸 방향이 도는 속도
	SnapDistance = 30, -- 이만큼 멀어지면(순간이동) 기차를 즉시 붙임
}

--=========================================================
-- 동물 줍기 (4·11단계)
--=========================================================
Config.Pickup = {
	BaseRadius = 4.2, -- 닿았다고 보는 거리
	MagnetBonusPerLevel = 3.5, -- 자석 업그레이드 1단계당 늘어나는 거리
	CheckInterval = 0.1, -- 줍기 검사 간격(초)
}

--=========================================================
-- 플레이어
--=========================================================
Config.Player = {
	BaseWalkSpeed = 16, -- 로블록스 기본값
	SpeedPerLevel = 3, -- 신발 업그레이드 1단계당 속도 증가
	JumpPower = 50,
}

--=========================================================
-- 동물 종류 (3·7·9단계)
--   Reward   : 배달 1마리당 받는 별
--   Count    : 섬에 돌아다닐 목표 마리 수
--   Rare     : 희귀 동물 (가끔 1마리만, 빠르게 도망)
--=========================================================
Config.Animals = {
	Chick = {
		Species = "Chick", Island = "Meadow", Order = 1,
		Reward = 1, Count = 8, Rare = false,
		MoveSpeed = 7, WanderIdle = { 2, 4 },
	},
	Duckling = {
		Species = "Duckling", Island = "Meadow", Order = 2,
		Reward = 2, Count = 4, Rare = false,
		MoveSpeed = 8, WanderIdle = { 2, 4 },
	},
	RainbowRabbit = {
		Species = "RainbowRabbit", Island = "Meadow", Order = 3,
		Reward = 5, Count = 1, Rare = true,
		MoveSpeed = 17, WanderIdle = { 0.4, 0.9 },
		RespawnDelay = 180, FleeRadius = 30,
	},
	Penguin = {
		Species = "Penguin", Island = "Snow", Order = 1,
		Reward = 2, Count = 6, Rare = false,
		MoveSpeed = 7, WanderIdle = { 2, 4 },
	},
	SnowBunny = {
		Species = "SnowBunny", Island = "Snow", Order = 2,
		Reward = 3, Count = 3, Rare = false,
		MoveSpeed = 9, WanderIdle = { 1.5, 3 },
	},
	GoldenPenguin = {
		Species = "GoldenPenguin", Island = "Snow", Order = 3,
		Reward = 5, Count = 1, Rare = true,
		MoveSpeed = 17, WanderIdle = { 0.4, 0.9 },
		RespawnDelay = 180, FleeRadius = 30,
	},
}

-- 도감에 보여줄 순서 (9단계: 섬마다 3칸)
Config.DexOrder = {
	Meadow = { "Chick", "Duckling", "RainbowRabbit" },
	Snow = { "Penguin", "SnowBunny", "GoldenPenguin" },
}

-- 같은 종이 한 섬에 최대 몇 마리까지 존재할 수 있는지 (성능 보호)
Config.MaxAnimalsPerSpecies = 3 -- Count 의 배수
Config.AnimalRespawnDelay = 5 -- 마리 수가 부족할 때 새로 태어나는 시간(초)

--=========================================================
-- 섬 (2·7단계)   * 모든 섬의 땅 높이(TopY)는 0 입니다.
--=========================================================
Config.Islands = {
	Meadow = {
		Key = "Meadow", Order = 1, UnlockCost = 0,
		Center = Vector3.new(0, 0, 0),
		Radius = 100,
		SpawnPoint = Vector3.new(0, 0, 62), -- 스폰 발판
		FarmCenter = Vector3.new(0, 0, 18), -- 농장 중심
		FarmSize = 36, -- 농장 한 변
		DeliveryPos = Vector3.new(0, 0, 37), -- 노란 배달 발판
		FirstAnimalPos = Vector3.new(0, 0, 50), -- 접속 직후 보이는 첫 동물
		FoxDen = Vector3.new(-48, 0, -14),
		ShopPos = Vector3.new(30, 0, 33),
		WanderBand = { 14, 90 }, -- 중심에서 이 거리 사이에 동물이 생김
		Ground = Color3.fromRGB(150, 216, 138),
		Beach = Color3.fromRGB(246, 228, 174),
	},
	Snow = {
		Key = "Snow", Order = 2, UnlockCost = 15, -- 두 번째 섬 해금 비용: 별 15개
		Center = Vector3.new(0, 0, -258),
		Radius = 72,
		SpawnPoint = Vector3.new(0, 0, -200),
		FarmCenter = Vector3.new(0, 0, -288),
		FarmSize = 24,
		DeliveryPos = Vector3.new(0, 0, -274),
		FirstAnimalPos = Vector3.new(0, 0, -214),
		FoxDen = Vector3.new(-42, 0, -246),
		ShopPos = nil,
		WanderBand = { 12, 62 },
		Ground = Color3.fromRGB(240, 247, 255),
		Beach = Color3.fromRGB(198, 226, 245),
	},
}
Config.IslandOrder = { "Meadow", "Snow" }
Config.StartIsland = "Meadow"

-- 다리와 별 문 (7단계)
Config.Bridge = {
	FromZ = -98, -- 초원 섬 끝
	ToZ = -190, -- 펭귄 섬 시작
	Width = 12,
	GateZ = -104, -- 별 문 위치
	GateWidth = 16,
	GateHeight = 15,
	BlockZ = -112, -- 잠긴 사람이 여기를 넘으면 되돌려 보냄
}

--=========================================================
-- 농장 (5단계)
--=========================================================
Config.Farm = {
	VisibleCapacity = 30, -- 농장 안에 눈에 보이는 최대 마리 수
	DeliveryInterval = 0.28, -- 한 마리씩 들어가는 간격(초)
	ZoneRadius = 7, -- 배달 발판 인식 범위
	HopInDuration = 0.7, -- 농장 안으로 폴짝 들어가는 시간
}

--=========================================================
-- 업그레이드 상점 (11단계)
--=========================================================
Config.Upgrades = {
	Order = { "Speed", "Train", "Magnet" },
	Speed = { MaxLevel = 3, Prices = { 8, 20, 40 } },
	Train = { MaxLevel = 3, Prices = { 12, 28, 55 }, LengthPerLevel = 5 },
	Magnet = { MaxLevel = 2, Prices = { 15, 35 } },
}

--=========================================================
-- NPC 여우 (10단계)
--=========================================================
Config.Fox = {
	PerIsland = { Meadow = 1, Snow = 1 },
	MaxTrain = 5,
	Speed = 11, -- 플레이어(16)보다 느리게
	ThinkInterval = 1.5, -- 목표를 다시 고르는 간격 (경로 계산 절약)
	CatchRadius = 3.6,
	WaveRadius = 14,
	WaveCooldown = 8,
	DenRadius = 6,
}

--=========================================================
-- 소리 (로블록스 클라이언트에 기본으로 들어있는 무료 사운드)
--   * 직접 구한 오디오 ID 를 쓰고 싶으면 Id 만 바꾸면 됩니다.
--=========================================================
Config.Sounds = {
	Chirp = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.95 },
	ChirpAlt = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 2.25 },
	Deliver = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.55, Pitch = 1.35 },
	StarUp = { Id = "rbxasset://sounds/snap.wav", Volume = 0.45, Pitch = 1.6 },
	Full = { Id = "rbxasset://sounds/switch3.wav", Volume = 0.5, Pitch = 1.4 },
	BuyOk = { Id = "rbxasset://sounds/snap.wav", Volume = 0.6, Pitch = 1.2 },
	BuyFail = { Id = "rbxasset://sounds/switch3.wav", Volume = 0.5, Pitch = 0.65 },
	Unlock = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.5, Pitch = 1.3 },
	NewAnimal = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.1 },
	Splash = { Id = "rbxasset://sounds/action_swim.mp3", Volume = 0.5, Pitch = 1 },
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Pitch = 1 },
}

-- 배경 음악 (12단계)
-- 로블록스 크리에이터 스토어에서 "사용 허용된" 음악의 ID 를 아래에 넣으면
-- 화면 오른쪽 아래에 스피커 버튼이 자동으로 생깁니다. 비워두면 음악 없이 동작합니다.
Config.Music = {
	AssetId = "", -- 예: "rbxassetid://1234567890"
	Volume = 0.2,
}

--=========================================================
-- 파티클 텍스처 (로블록스 클라이언트 기본 내장 무료 텍스처)
--=========================================================
Config.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

--=========================================================
-- 색 (파스텔)
--=========================================================
Config.Colors = {
	Water = Color3.fromRGB(137, 200, 240),
	Wood = Color3.fromRGB(197, 152, 106),
	WoodDark = Color3.fromRGB(160, 116, 78),
	Leaf = Color3.fromRGB(129, 205, 137),
	LeafAlt = Color3.fromRGB(160, 220, 150),
	Rock = Color3.fromRGB(196, 199, 206),
	Star = Color3.fromRGB(255, 221, 89),
	Snow = Color3.fromRGB(248, 252, 255),
	Ice = Color3.fromRGB(176, 222, 247),
	Pink = Color3.fromRGB(255, 176, 200),
	Sky = Color3.fromRGB(190, 228, 255),
}

--=========================================================
-- 리모트 이름 (서버 ↔ 클라이언트)
--=========================================================
Config.Remotes = {
	StateUpdate = "StateUpdate", -- 서버 → 클라 : 내 상태 전체
	Effect = "Effect", -- 서버 → 클라 : 소리/연출 신호
	RequestState = "RequestState", -- 클라 → 서버 : 접속 직후 상태 요청
	SetPref = "SetPref", -- 클라 → 서버 : 음악 켜기/끄기 저장
}

Config.Debug = true -- 출력 창에 진행 로그를 표시

return Config
