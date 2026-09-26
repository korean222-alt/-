--[[
	GameConfig
	게임 전역에서 공유하는 설정값과 이름 상수 모음.

	문자열을 직접 여기저기 적지 않고 전부 이 파일을 거치게 한다.
	나중에 이름을 바꿔야 할 때 한 곳만 고치면 되고, 오타로 인한 버그도 막아준다.

	Phase 2 : 카운트다운 / 라운드 / 턴 Attribute, 라이팅 프리셋
	Phase 3 : 칼 슬롯 Attribute · 태그 · 배치 규칙, 랭킹판
	Phase 5 : 해적 잡기, 스킨, 전시장
	Phase 6 : 항구와 해적선(MapBuilder), 스킨 이펙트 정의
	Phase 7 : 코인 · 인벤토리 · 상점 · 로벅스 상품
	Phase 8 : 6인 테이블 · 빠른 모드 · 연승 · 일일 퀘스트 · 업적 · 방해 아이템
]]

local GameConfig = {}

-- 개발 중에는 true. 출시 전에 false 로 바꾸면 로그가 조용해진다.
GameConfig.DEBUG = false

--------------------------------------------------
-- CollectionService 태그
-- Workspace 에 테이블 모델을 복제하고 이 태그만 붙이면 자동으로 게임에 등록된다.
--------------------------------------------------
GameConfig.Tags = {
	Table = "CursedBarrel_Table",
	Seat = "CursedBarrel_Seat",
	Slot = "CursedBarrel_Slot", -- Phase 3 : 칼 슬롯 하나하나
	RankingBoard = "CursedBarrel_RankingBoard", -- Phase 3 : 랭킹판
	SkinPedestal = "CursedBarrel_SkinPedestal", -- Phase 5 : 전시대
	SkinPreview = "CursedBarrel_SkinPreview", -- Phase 5 : 전시대 위에서 도는 모형
	Decor = "CursedBarrel_Decor", -- Phase 6 : 장식 (성능 정리 대상)
	LikeReward = "CursedBarrel_LikeReward", -- Phase 16 : 스폰 옆 좋아요 보상 받침대의 프롬프트
}

--------------------------------------------------
-- 테이블 모델에 서버가 기록하는 Attribute 이름
-- 클라이언트는 이 Attribute 만 읽어서 UI 를 그린다. (읽기 전용 통로)
--------------------------------------------------
GameConfig.TableAttributes = {
	-- Phase 1
	TableId = "TableId", -- 테이블 고유 ID (문자열)
	TableType = "TableType", -- TableConfig.Types 의 키
	SeatCount = "SeatCount", -- 총 좌석 수
	SeatedCount = "SeatedCount", -- 현재 앉아 있는 인원
	MinPlayers = "MinPlayers", -- 시작에 필요한 최소 인원
	State = "State", -- 현재 상태 머신 상태

	-- Phase 2 : 카운트다운
	-- 남은 초를 매 틱 기록하지 않고 "끝나는 시각" 하나만 기록한다.
	-- 클라이언트가 workspace:GetServerTimeNow() 로 빼서 쓰면 네트워크 부담 없이 부드럽다.
	CountdownEndsAt = "CountdownEndsAt", -- 서버 시계 기준 종료 시각 (0 = 카운트다운 없음)
	CountdownDuration = "CountdownDuration", -- 이번 카운트다운의 전체 길이(초)

	-- Phase 2 : 라운드 / 턴
	RoundId = "RoundId",
	ParticipantCount = "ParticipantCount", -- 이번 라운드를 시작한 인원 (중간에 줄지 않는다)
	TurnCount = "TurnCount", -- 아직 살아 있는 인원
	TurnIndex = "TurnIndex", -- 현재 몇 번째 차례인지 (1 부터)
	CurrentTurnUserId = "CurrentTurnUserId", -- 현재 차례인 플레이어 UserId (0 = 없음)
	CurrentTurnName = "CurrentTurnName",
	TurnEndsAt = "TurnEndsAt", -- 이번 턴 제한시간 종료 시각 (0 = 제한 없음)

	-- Phase 3 : 칼 슬롯 / 승패
	KnifeSlotCount = "KnifeSlotCount",
	SlotsRemaining = "SlotsRemaining", -- 아직 아무도 고르지 않은 슬롯 수
	BarrelCycle = "BarrelCycle", -- 이번 라운드에서 통을 몇 번째로 채웠는지 (1 부터)
	LastPickSlot = "LastPickSlot",
	LastPickUserId = "LastPickUserId",
	LastPickName = "LastPickName",
	LastPickSafe = "LastPickSafe", -- true = 안전, false = 위험
	WinnerUserId = "WinnerUserId",
	WinnerName = "WinnerName",
	ResetEndsAt = "ResetEndsAt",

	-- Phase 5 : 해적 잡기
	CatchCount = "CatchCount", -- 이번 라운드에서 성공한 잡기 횟수 (많을수록 다음 창이 좁다)

	-- Phase 8 : 통 안에 몇 마리가 숨어 있는지 (어느 자리인지는 절대 쓰지 않는다)
	PirateCount = "PirateCount",

	-- Phase 10 : 현상금과 배짱
	Pot = "Pot", -- 이번 판의 현상금 (마지막 생존자가 가져간다)
	BraveOfferUserId = "BraveOfferUserId", -- "한 번 더" 를 누를 수 있는 사람 (0 = 없음)
	BraveOfferEndsAt = "BraveOfferEndsAt", -- 그 제안이 끝나는 서버 시각
	BraveLevel = "BraveLevel", -- 지금 차례의 사람이 몇 번째로 더 찌르는 중인지 (0 = 보통 차례)
	BraveNextReward = "BraveNextReward", -- 한 번 더 찔러 살아남으면 받을 코인
	WinForfeit = "WinForfeit", -- 이번 승리가 기권승인가 (승리 기록 없음 · 보상 절반)

	-- Phase 11
	PotCarry = "PotCarry", -- 이번 판 현상금 중 지난 판에서 넘어온 몫
	Practice = "Practice", -- AI 선원이 함께 앉은 연습 판인가 (보상이 줄고 승수 · 랭킹에 들어가지 않는다)

	-- Phase 12
	Lucky = "Lucky", -- 오늘의 행운 테이블 (보물 폭발 확률 2배)
	PredictOpen = "PredictOpen", -- 관전자가 "누가 살아남을까" 예측을 할 수 있는 동안 true
	Tutorial = "Tutorial", -- 처음 온 사람의 연습 판 (AI 와 함께, 잡기가 조금 쉽다)

	-- Phase 15 : 라운드 (한 명이 탈락할 때마다 다음 라운드로 올라간다) · 최후의 1인
	Stage = "Stage", -- 지금 몇 라운드인가 (1 부터)
	StageCount = "StageCount", -- 이번 판의 라운드 수 (시작 인원 - 1)
	WinnerTakesAll = "WinnerTakesAll", -- 최후의 1인이 현상금을 전부 가져가는 테이블인가

	-- Phase 7 : 이 테이블에 적용 중인 통 스킨 (앉은 사람들 중에서 서버가 하나를 고른다)
	BarrelSkinId = "BarrelSkinId",
	BarrelSkinOwnerId = "BarrelSkinOwnerId",
	BarrelSkinOwnerName = "BarrelSkinOwnerName",
}

--------------------------------------------------
-- 좌석(Seat)에 기록하는 Attribute 이름
--------------------------------------------------
GameConfig.SeatAttributes = {
	SeatIndex = "SeatIndex", -- 1 부터 시작하는 좌석 번호
	OccupantUserId = "OccupantUserId", -- 앉아 있는 플레이어 UserId (비었으면 0)
	TurnOrder = "TurnOrder", -- Phase 2: 이번 라운드의 턴 순서 (0 = 참가자 아님)
	Alive = "Alive", -- Phase 3: 아직 살아 있는 참가자인가
	CatchesLeft = "CatchesLeft", -- 이번 판에 앞으로 잡을 수 있는 횟수 (참가자가 아니면 0)
	CatchLevel = "CatchLevel", -- Phase 11: 이번 판에 이미 잡은 횟수 (클수록 다음 해적이 빠르다)
	OccupantName = "OccupantName", -- Phase 11: 앉은 사람 이름 (AI 선원은 Players 에 없어서 이걸로 읽는다)
	OccupantBot = "OccupantBot", -- Phase 11: 앉은 것이 AI 선원인가
}

--------------------------------------------------
-- 칼 슬롯(Part)에 기록하는 Attribute 이름
--
-- ★ "위험 슬롯"은 절대 Attribute 로 쓰지 않는다.
--    Attribute 는 모든 클라이언트에 복제되므로, 적어두는 순간 정답이 새어 나간다.
--    위험 슬롯은 서버 메모리(Round 객체) 안에만 존재한다.
--------------------------------------------------
GameConfig.SlotAttributes = {
	SlotIndex = "SlotIndex",
	Used = "Used", -- 이미 칼이 꽂혔는가
	UsedByUserId = "UsedByUserId",
}

--------------------------------------------------
-- 플레이어에게 기록하는 Attribute 이름 (Phase 7 · 8)
--
-- 코인처럼 "본인만 알면 되는" 값도 Attribute 로 두면 모두에게 복제된다.
-- 여기 있는 값은 전부 남이 봐도 괜찮은 것들이다. (연승은 머리 위에 띄운다)
--------------------------------------------------
GameConfig.PlayerAttributes = {
	Coins = "Coins",
	Wins = "Wins",
	Games = "Games",
	Level = "Level",
	Streak = "Streak", -- 지금 연승 수
	BestStreak = "BestStreak",
	Loaded = "ProfileLoaded", -- 저장된 자료를 다 읽었는가
	VIP = "VIP", -- Phase 10: VIP 게임패스를 가지고 있는가 (서버만 쓴다)
	LoginStreak = "LoginStreak", -- Phase 10: 연속 출석 일수
	Booster = "Booster", -- Phase 12: 현상금 부스터 게임패스 (서버만 쓴다)
	Title = "Title", -- Phase 12: 머리 위 칭호 (선원 동료 · 크라켄 사냥꾼 · 토너먼트 챔피언)
	CannonId = "CannonId", -- Phase 12: 지금 잡고 있는 대포 (없으면 nil)
	TourneyRounds = "TourneyRounds", -- Phase 12: 토너먼트 시리즈에서 치른 판 수 (0~4)
	TourneyScore = "TourneyScore", -- Phase 12: 토너먼트 시리즈 점수
}

--------------------------------------------------
-- 테이블 상태 머신
--------------------------------------------------
GameConfig.States = {
	Waiting = "Waiting",
	Countdown = "Countdown",
	Starting = "Starting",
	Playing = "Playing",
	RoundEnding = "RoundEnding",
	Resetting = "Resetting",
}

-- 게임에 새로 참가할 수 있는 상태들
GameConfig.JoinableStates = {
	[GameConfig.States.Waiting] = true,
	[GameConfig.States.Countdown] = true,
}

-- "게임이 진행 중"으로 취급하는 상태들. 이 동안 내 화면 조명이 어두워진다.
GameConfig.InGameStates = {
	[GameConfig.States.Starting] = true,
	[GameConfig.States.Playing] = true,
	[GameConfig.States.RoundEnding] = true,
}

--------------------------------------------------
-- 프롬프트 설정
--------------------------------------------------
GameConfig.SeatPrompt = {
	ActionText = "앉기",
	HoldDuration = 0,
	MaxActivationDistance = 12,
	RequiresLineOfSight = false,
}

GameConfig.PromptCooldown = 0.35

GameConfig.SlotPrompt = {
	ActionText = "칼 꽂기",
	HoldDuration = 0,
	MaxActivationDistance = 14,
	RequiresLineOfSight = false,
}

GameConfig.SelectCooldown = 0.25

--------------------------------------------------
-- RemoteEvent 이름 (ReplicatedStorage > CursedBarrel > Remotes)
--
-- 판정은 전부 서버에서 하고, 클라이언트가 보내는 값은 전부 다시 검사한다.
--------------------------------------------------
GameConfig.Remotes = {
	Folder = "Remotes",
	SelectSlot = "SelectSlot",

	-- Phase 5 : 해적 잡기
	CatchPrompt = "CatchPrompt", -- 서버 → 잡아야 하는 사람 한 명
	CatchInput = "CatchInput", -- 그 사람 → 서버 (누른 시각)
	CatchResult = "CatchResult", -- 서버 → 모두 (성공/실패)

	-- Phase 5 : 스킨
	EquipSkin = "EquipSkin", -- 클라이언트 → 서버 (전시대에서 고른 스킨)

	-- Phase 7 : 상점 · 인벤토리
	ShopRequest = "ShopRequest", -- 클라이언트 → 서버 (구매/장착 요청)
	ShopResult = "ShopResult", -- 서버 → 그 사람 (성공/실패 · 보유 목록)

	-- Phase 8 : 방해 아이템 · 퀘스트
	Sabotage = "Sabotage", -- 클라이언트 → 서버 (누구를 방해할지)
	SabotageCue = "SabotageCue", -- 서버 → 당한 사람 + 테이블 (연출)
	QuestUpdate = "QuestUpdate", -- 서버 → 그 사람 (퀘스트 진행도)

	-- Phase 10 : 배짱 ("한 번 더")
	Brave = "BraveRequest", -- 클라이언트 → 서버 (테이블 모델)

	-- Phase 12
	WorldCue = "WorldCue", -- 서버 → 모두 (날씨 바뀜 · 크라켄 습격 · 내려치기)
	CannonRequest = "CannonRequest", -- 클라이언트 → 서버 (발사 방향 · 내리기)
	CannonCue = "CannonCue", -- 서버 → 모두 (포탄 연출 · 맞았는지)
	Predict = "PredictRequest", -- 관전자 → 서버 (누가 살아남을지)

	-- Phase 13
	Reward = "RewardRequest", -- 클라이언트 → 서버 (출석 받기 · 룰렛 돌리기)
	RewardCue = "RewardCue", -- 서버 → 그 사람 (룰렛 결과 · 출석 결과)
}

-- 서버가 거절할 때 클라이언트에 보여 줄 문구
GameConfig.RejectMessages = {
	NotPlaying = "지금은 칼을 꽂을 수 없습니다",
	OtherTable = "다른 테이블의 통은 건드릴 수 없습니다",
	NotParticipant = "이번 라운드 참가자가 아닙니다",
	NotYourTurn = "아직 내 차례가 아닙니다",
	Eliminated = "이미 탈락했습니다",
	BadSlot = "없는 자리입니다",
	SlotUsed = "이미 칼이 꽂힌 자리입니다",
	TooFast = "너무 빠릅니다",
	NotOwned = "아직 가지고 있지 않은 스킨입니다",
	NoCoins = "코인이 모자랍니다",
	AlreadyOwned = "이미 가지고 있습니다",
	RobuxOnly = "로벅스로만 살 수 있습니다",
	NoTarget = "방해할 상대가 없습니다",
	SabotageCooldown = "아직 다시 쓸 수 없습니다",
	VipOnly = "VIP 패스 전용입니다",
	PackOnly = "스타터 팩 전용입니다",
	SeasonOnly = "시즌 보상으로만 받을 수 있습니다",
	LikeOnly = "🎟 코드 선물이에요 (코드에 love 입력 · 2층 뒤쪽 받침대)", -- Phase 24 : 예전 "계단 아래 그룹 가입" 안내는 틀린 설명이었다
	-- Phase 13
	AlreadyClaimed = "오늘은 이미 받았습니다",
	NoSpins = "오늘은 이미 돌렸습니다. 내일 다시 돌릴 수 있어요",
}

--------------------------------------------------
-- 칼 슬롯 배치 규칙 (Phase 3)
--------------------------------------------------
GameConfig.SlotLayout = {
	BarrelName = "Barrel",
	BodyName = "Body",
	FolderName = "KnifeSlots",
	MaxPerRing = 8, -- 한 줄에 최대 몇 개까지 두를지
	RingSpread = 0.155, -- 통 높이 대비 줄 간격
	SurfaceGap = 0.06,
	KnifeTilt = 14,
	MarkerSize = Vector3.new(0.34, 0.52, 0.12),
	BladeSize = Vector3.new(0.12, 0.5, 1.6),
	HandleSize = Vector3.new(0.26, 0.34, 0.7),
	MarkerColor = Color3.fromRGB(28, 20, 15),
	BladeColor = Color3.fromRGB(206, 210, 214),
	HandleColor = Color3.fromRGB(64, 42, 28),
	DangerColor = Color3.fromRGB(235, 96, 78),
}

--------------------------------------------------
-- 라운드 연출 타이밍 (Phase 3)
--------------------------------------------------
GameConfig.Timing = {
	StartingDuration = 1.6,
	ResultHold = 2.2,
	RoundEndDuration = 5,
	ResetDuration = 0.6,
}

--------------------------------------------------
-- 랭킹판 (Phase 3 · Phase 7 에서 저장이 진짜가 된다)
--------------------------------------------------
GameConfig.Ranking = {
	Rows = 10,
	LeaderstatsName = "Wins", -- Phase 13 : 플레이어 목록 머리글은 번역이 안 되므로 영어로 (한국어 사용자도 알아본다)
	StreakStatName = "Streak",

	-- Phase 7 : 이제 기본으로 켠다. ProfileService 가 모든 참가자의 판수를 저장한다.
	-- (Studio 에서는 "Studio의 API 서비스 접근 허용"이 필요하다. 꺼져 있어도 게임은 그대로 돌아간다.)
	UseDataStore = true,
	DataStoreName = "CursedBarrel_Profile_v2",
	OrderedStoreName = "CursedBarrel_Wins_v2", -- 전 서버 랭킹
	GlobalRows = 10,
	GlobalRefresh = 90, -- 전 서버 랭킹을 다시 읽는 간격(초)
	-- Phase 16 : 스폰 앞 "명예의 문" 나무판자 셋. id 는 ShipLayout.HallOfFame.Boards 의 id 와 같다.
	--   stat  : 프로필에서 읽는 값 · store : 전 서버 순위를 쌓는 OrderedDataStore
	Boards = {
		{ id = "streak", title = "🔥 최고 연승", stat = "bestStreak", store = "CursedBarrel_BestStreak_v1", suffix = "연승", keepMax = true },
		{ id = "coins", title = "💰 전체 부자 순위", stat = "coins", store = "CursedBarrel_Coins_v1" },
		{ id = "wins", title = "🏆 전체 승리", stat = "wins", store = "CursedBarrel_Wins_v2", suffix = "승", keepMax = true },
	},
	PublishInterval = 120, -- 코인 · 연승을 전 서버 순위에 올리는 간격(초). 바뀐 사람만 쓴다
}

--------------------------------------------------
-- 해적 잡기 (Phase 5)
--
-- 위험한 자리를 뽑으면 바로 탈락하지 않는다.
-- 통에서 튀어나오는 해적을 정해진 순간에 잡으면 살아남고, 놓치면 탈락한다.
--
-- ★ 창이 열리는 시각과 길이는 서버가 정하고 서버 메모리에만 둔다.
-- ★ 잡았다는 신고는 믿지 않는다. 서버가 그 시각이 물리적으로 가능한지 다시 따진다.
--------------------------------------------------
GameConfig.Catch = {
	Enabled = true,

	-- ★ Phase 11 : 해적은 몇 번이든 잡을 수 있다. 대신 잡을 때마다 다음 해적이 빨라진다.
	--   Phase 10 에서는 한 판에 한 번만 잡게 막았다. (잡는 창이 넉넉해 판이 안 끝나던 제보 때문)
	--   이번에는 "계속 잡을 수 있지만 점점 빨라지는" 쪽으로 바꾼다.
	--     · 내가 잡을 때마다 내 다음 창이 PersonalDecay 배로 좁아진다. (0.62 → 0.50 → 0.40 → 0.32 → 0.25 → 0.20초)
	--     · 해적이 튀어나오기까지의 시간도 LeadDecay 배로 짧아진다. (준비할 틈이 줄어든다)
	--     · MaxPerPlayer 번을 잡은 사람에게 다음 해적은 "분노한 해적"이다. 잡기 창 없이 탈락한다.
	--   그래서 인원이 N 명이면 잡기는 많아야 N × MaxPerPlayer 번이고, 판은 반드시 끝난다.
	-- ★ Phase 21 : 판이 오래 가게. 창이 HardWindow(0.40초) 아래로 내려가는 "어려운 경지"부터는
	--   잡을 때마다 HardStep(0.02초)씩만 좁아진다 (0.40 → 0.38 → 0.36 … → 0.20). 잘하는 사람은 훨씬 오래 버틴다.
	--   분노한 해적은 16번을 잡은 다음 (예전 6번)
	MaxPerPlayer = 16,
	HardWindow = 0.40,
	HardStep = 0.02,
	PersonalDecay = 0.8,
	LeadDecay = 0.86,
	MinLead = 0.85, -- ★ 칼 꽂는 모션(최대 0.75초)이 끝나기 전에 해적이 나오면 안 된다
	SpentReveal = 1.4, -- 분노한 해적을 보여주고 탈락시키기까지

	-- 칼이 꽂힌 순간부터 잡기 창이 열릴 때까지.
	-- 클라이언트는 서버가 보낸 opensAt 에 맞춰 연출하므로 길이가 매번 달라도 화면과 맞는다.
	Lead = 1.30,
	LeadJitter = 0.5, -- 0 ~ 이 값만큼 무작위로 늦춘다. 박자를 외워서 누르는 것을 막는다.

	BaseWindow = 0.62, -- 첫 번째 잡기의 창 길이(초)
	StepPerCatch = 0.03, -- 이 테이블에서 누군가 잡을 때마다 모두의 창이 이만큼 좁아진다
	MinWindow = 0.2, -- ★ 이 아래로는 내리지 않는다. (누른 시각은 따로 지연 보정을 받는다)
	DuelScale = 0.85, -- 최후의 2인이면 곱한다
	LowSlotScale = 0.90, -- 남은 자리가 3칸 이하면 곱한다

	-- ★ Phase 11 : 해적이 나오기 전에 누르면 그 자리에서 실패다. (예전에는 세 번까지 봐줬다)
	EarlyTolerance = 0.06, -- 시계 오차. 창이 열리기 이만큼 전까지는 "딱 맞춰 누른 것"으로 친다
	ArmDelay = 0.3, -- 칼을 고른 직후 이 시간 안의 입력은 버린다 (자리 버튼을 두 번 누른 손가락)

	-- 클라이언트가 보낸 "누른 시각"은 MaxLatency 안에서 이미 지연 보정을 받는다.
	-- 그래서 창이 닫힌 뒤의 여유는 시계 오차 정도만 둔다. (Phase 9 까지 0.4 초라 너무 쉬웠다)
	Grace = 0.12,
	MaxLatency = 0.25, -- 지연 보정 상한. 이보다 큰 차이는 조작으로 본다.
	LatencySlack = 0.08, -- Phase 24 : 서버가 잰 그 사람의 지연(왕복의 절반)에 더해 주는 여유(휴대폰 전파 흔들림 · 화면 한 프레임). 보정은 (지연 + 여유)와 MaxLatency 중 작은 값까지만
	Timeout = 2.2, -- 창이 열리고 이 시간이 지나면 서버가 실패로 확정한다
	Hold = 1.6, -- 결과를 보여주고 다음 턴으로 넘어가기까지
	PerfectAccuracy = 0.72, -- 이 정확도 이상이면 "완벽한 잡기"

	-- Phase 5 에서는 "잡으면 통을 다시 채우지 않는다" 였다.
	-- 그런데 위험 자리는 하나뿐이라, 그 자리를 잡고 나면 통이 완전히 안전해져
	-- 칼을 다 뽑을 때까지 해적이 두 번 다시 나오지 않았다. (Phase 6 에서 고침)
	RefillOnCatch = false,

	-- ★ Phase 6 수정: 잡는 데 성공하면 아직 아무도 꽂지 않은 자리 중에서
	--   새 해적을 이만큼 더 숨긴다. 통을 새로 채우지 않아도 긴장이 이어진다.
	ArmOnCatch = 1,
	MinFreeSlotsToArm = 1, -- 남은 빈 자리가 이보다 적으면 숨길 곳이 없다
}

--------------------------------------------------
-- 배짱 (Phase 10) : 안전한 자리를 뽑은 뒤 "한 번 더" 찌를 수 있다.
--
-- 운만으로 흘러가던 판에 고를 거리를 준다.
--   · 더 찌르면 보너스 코인을 바로 받고 현상금이 커진다.
--   · 대신 통의 안전한 자리가 줄어서 내가 해적을 만날 확률이 오른다.
--   · 반대로 다음 사람 차례의 통은 더 위험해진다. (상대를 몰아붙이는 수)
--------------------------------------------------
GameConfig.Brave = {
	Enabled = true,
	MaxChain = 3, -- 한 차례에 더 찌를 수 있는 최대 횟수
	MinPickable = 3, -- 고를 수 있는 빈 자리가 이보다 적으면 제안하지 않는다
	Rewards = { 35, 65, 110 }, -- 배짱 1·2·3단계로 살아남으면 바로 받는 코인
}

--------------------------------------------------
-- 현상금 (Phase 10) : 한 판 동안 쌓이다가 마지막 생존자가 가져간다.
-- 참가자의 코인을 걷는 것이 아니다. 판돈이 아니라 서버가 거는 상금이다.
--------------------------------------------------
GameConfig.Pot = {
	Enabled = true,
	Base = 60,
	PerPick = 18, -- 안전한 자리 하나마다
	PerBravePick = 42, -- 배짱으로 더 찌른 안전한 자리마다 (PerPick 에 더해진다)
	PerCatch = 48, -- 해적을 잡을 때마다
	PerPerfect = 30, -- 완벽한 잡기는 더
	-- Phase 15 : 최후의 1인 테이블은 모두가 벌던 코인이 현상금에 쌓이므로 상한을 넉넉히 둔다
	Cap = 18000,

	-- ★ Phase 11 : 보물 폭발. 안전한 자리를 뽑을 때마다 작은 확률로 현상금이 크게 뛴다.
	--   안 터질수록 확률이 조금씩 오른다(PityStep). 한 판에 한두 번쯤 터지게 맞췄다.
	Surge = {
		Enabled = true,
		Chance = 0.05,
		PityStep = 0.012,
		MaxChance = 0.3,
		BoostedMaxChance = 0.5, -- Phase 12 : 노을 · 행운 테이블로 커져도 이 이상은 안 된다
		Tiers = {
			{ id = "pouch", name = "금화 주머니", weight = 70, add = 135 },
			{ id = "chest", name = "보물 상자", weight = 25, add = 270, mult = 1.5 },
			{ id = "kraken", name = "크라켄의 보물", weight = 5, add = 450, mult = 2.5 },
		},
	},

	-- ★ Phase 11 : 이월. 현상금을 다 가져가지 못한 판(기권승 · 승자 없음 · AI 선원 승리)은
	--   남은 몫이 이 테이블의 다음 판으로 넘어간다. 판이 거듭될수록 테이블 위 금화가 쌓인다.
	CarryCap = 4500,
}

--------------------------------------------------
-- 기권승 (Phase 10)
-- 상대가 전부 스스로 나가서 이긴 판은 "승리"로 치지 않는다.
-- 부계정 두 개로 앉았다 일어나기를 반복해 승리·연승·코인을 버는 것을 막는다.
-- 해적에게 탈락한 사람이 한 명이라도 있거나, 칼을 참가 인원 × 이 값만큼 꽂았으면 정상 승리다.
--------------------------------------------------
GameConfig.ForfeitWin = {
	MinPicksPerPlayer = 2,
	-- ★ Phase 11 : 기권승은 승리 보상과 현상금을 절반만 받는다. (승수 · 연승 · 랭킹에는 들어가지 않는다)
	--   남은 현상금 절반은 이 테이블의 다음 판으로 이월된다.
	RewardShare = 0.5,
	-- ★ Phase 24 : 기권승 보상 조건. 판 전체에 (시작 인원 × MinPicksForReward) 자루 이상 꽂혔고,
	--   이긴 사람이 직접 MinOwnPicksForReward 자루 이상 꽂았어야 한다. 아니면 "무효 판"(보상 · 판수 · 퀘스트 없음).
	MinPicksForReward = 1,
	MinOwnPicksForReward = 1,
}

--------------------------------------------------
-- 잭팟 (Phase 21) : 아주 낮은 확률로 현상금이 한 번에 크게 뛴다. 라운드가 올라갈수록 큰 잭팟 확률이 오른다.
--   라운드 = 위 알림판의 "라운드 N/M" (한 명이 떨어질 때마다 올라간다. 4인 테이블은 1 · 2 · 3(결승))
--   · 라운드마다 한 번, 그 라운드의 첫 안전한 자리에서 몰래 굴린다.
--       큰 잭팟 10,000  : 1% + 라운드마다 2%  (1라운드 1% · 2라운드 3% · 3라운드 5% … MaxChance 까지)
--       잭팟 5,000      : 큰 잭팟이 아니면 10%
--   · 뽑혔으면 그 라운드의 안전한 자리 1~TriggerWithin 번째 안에서 "잭팟!" 이 터진다 (현상금에 들어가 마지막 생존자가 가져간다)
--   · AI 연습 판은 Bots.RewardScale 만큼만 (0.6배)
--------------------------------------------------
GameConfig.Jackpot = {
	Enabled = true,
	TriggerWithin = 3,
	Big = { Id = "big", Name = "대박 잭팟", Amount = 10000, Chance = 0.01, PerRound = 0.02, MaxChance = 0.15 },
	Small = { Id = "small", Name = "잭팟", Amount = 5000, Chance = 0.10 },
}
-- 잭팟이 들어가도 현상금이 막히지 않게 상한을 올린다 (예전 18,000)
GameConfig.Pot.Cap = 60000

-- 이번 잡기의 창 길이. 서버에서만 호출한다.
-- personal : 이 사람이 이번 판에 이미 잡은 횟수 (Phase 11 : 잡을수록 빨라진다)
-- hardSteps (Phase 21) : 이 사람이 "어려운 경지"(HardWindow 아래)에 들어선 뒤 잡은 횟수
-- 돌려주는 값 : 창 길이, 어려운 경지인가
function GameConfig.catchWindow(catchCount, aliveCount, slotsLeft, personal, hardSteps)
	local catch = GameConfig.Catch
	local window = catch.BaseWindow - catch.StepPerCatch * math.max(0, catchCount or 0)
	window *= (catch.PersonalDecay or 1) ^ math.max(0, personal or 0)
	if aliveCount and aliveCount <= 2 then
		window *= catch.DuelScale
	end
	if slotsLeft and slotsLeft <= 3 then
		window *= catch.LowSlotScale
	end
	local hard = catch.HardWindow
	if hard and (window < hard or (hardSteps or 0) > 0) then
		-- 어려운 경지부터는 한 번에 HardStep 씩만 좁아진다
		return math.max(catch.MinWindow, hard - (catch.HardStep or 0.02) * math.max(0, hardSteps or 0)), true
	end
	return math.max(catch.MinWindow, window), false
end

-- 해적이 튀어나오기까지의 기본 시간 (흔들기 전). 잡을수록 짧아진다.
-- scale (Phase 12) : 항해 시계의 배율 (밤 0.9). 그래도 MinLead 아래로는 내려가지 않는다.
function GameConfig.catchLead(personal, scale)
	local catch = GameConfig.Catch
	local lead = catch.Lead * (catch.LeadDecay or 1) ^ math.max(0, personal or 0) * (tonumber(scale) or 1)
	return math.max(catch.MinLead or 0.85, lead)
end

--------------------------------------------------
-- 희귀도 (Phase 7)
-- 상점 가격 · 이름표 색 · 통 스킨 우선순위가 전부 여기서 나온다.
--------------------------------------------------
GameConfig.Rarity = {
	common = { rank = 1, label = "기본", color = Color3.fromRGB(198, 190, 176) },
	rare = { rank = 2, label = "희귀", color = Color3.fromRGB(120, 190, 255) },
	epic = { rank = 3, label = "영웅", color = Color3.fromRGB(196, 130, 255) },
	legend = { rank = 4, label = "전설", color = Color3.fromRGB(255, 186, 78) },
	-- Phase 13 : 가장 비싼 용 세트. 무지갯빛 반짝임이 더 붙고, 사면 서버 전체에 알린다.
	mythic = { rank = 5, label = "신화", color = Color3.fromRGB(255, 92, 150) },
}

function GameConfig.rarityOf(skin)
	return GameConfig.Rarity[skin and skin.rarity or "common"] or GameConfig.Rarity.common
end

--------------------------------------------------
-- 스킨 (Phase 5 · Phase 6 에서 이펙트가 붙고 · Phase 7 에서 값이 붙는다)
--
-- 칼 스킨은 서버가 꽂히는 칼에 입힌다 → 같은 테이블 모두에게 보인다. (자랑용)
-- 해적 스킨은 각자 화면에서만 바뀐다 → 남의 취향이 내 화면을 덮지 않는다.
-- 통 스킨은 테이블 하나에 하나만 적용된다 → 서버가 앉은 사람들 중에서 고른다.
--
-- ★ 통 스킨은 Body 파트의 크기를 절대 바꾸지 않는다.
--   칼 슬롯 배치가 Body 크기에서 계산되기 때문에, 크기를 바꾸면 칼이 허공에 뜬다.
--
-- fx 항목 (SkinFX 가 읽는다)
--   emit   : 은은하게 피어오르는 입자 색
--   spark  : 반짝임을 붙일지
--   trail  : 칼이 움직일 때 남는 꼬리 색
--   halo   : 바닥/주변에 깔리는 고리 색
--   pulse  : 밝기가 숨 쉬는 속도 (0 이면 가만히 있는다)
--------------------------------------------------
GameConfig.Skins = {
	PlayerAttributes = {
		Knife = "KnifeSkin",
		Barrel = "BarrelSkin",
		Ghost = "GhostSkin",
		Stab = "StabSkin", -- Phase 11 : 칼 꽂는 모션
	},

	Knife = {
		{
			id = "classic", shape = "dagger", name = "낡은 단검", rarity = "common", price = 0,
			blade = Color3.fromRGB(206, 210, 214), bladeMaterial = Enum.Material.Metal,
			handle = Color3.fromRGB(64, 42, 28), handleMaterial = Enum.Material.Wood,
			guard = Color3.fromRGB(126, 104, 62), trail = Color3.fromRGB(226, 216, 190),
		},
		{
			id = "bone", shape = "bone", name = "뼈칼", rarity = "common", price = 7900,
			blade = Color3.fromRGB(238, 232, 212), bladeMaterial = Enum.Material.Sand,
			handle = Color3.fromRGB(206, 196, 170), handleMaterial = Enum.Material.Sand,
			guard = Color3.fromRGB(96, 86, 68), trail = Color3.fromRGB(240, 236, 216),
			fx = { emit = Color3.fromRGB(226, 220, 200), trail = Color3.fromRGB(240, 236, 216) },
		},
		{
			id = "gold", shape = "cutlass", name = "선장의 금검", rarity = "rare", price = 48900,
			blade = Color3.fromRGB(246, 206, 106), bladeMaterial = Enum.Material.Metal,
			handle = Color3.fromRGB(120, 78, 32), handleMaterial = Enum.Material.Wood,
			guard = Color3.fromRGB(255, 226, 140), trail = Color3.fromRGB(255, 226, 140), glow = 0.45,
			fx = { emit = Color3.fromRGB(255, 226, 140), spark = true, trail = Color3.fromRGB(255, 226, 140), halo = Color3.fromRGB(255, 206, 110), pulse = 1.4 },
		},
		{
			id = "cursed", shape = "kris", name = "저주받은 칼날", rarity = "epic", price = 128900,
			blade = Color3.fromRGB(120, 255, 214), bladeMaterial = Enum.Material.Neon,
			handle = Color3.fromRGB(26, 34, 40), handleMaterial = Enum.Material.Slate,
			guard = Color3.fromRGB(84, 214, 186), trail = Color3.fromRGB(120, 255, 214), glow = 1,
			fx = { emit = Color3.fromRGB(120, 255, 214), spark = true, trail = Color3.fromRGB(120, 255, 214), halo = Color3.fromRGB(84, 214, 186), pulse = 2.1 },
		},
		{
			id = "ember", shape = "dagger", name = "잿불 단검", rarity = "legend", price = 291900,
			blade = Color3.fromRGB(255, 132, 62), bladeMaterial = Enum.Material.Neon,
			handle = Color3.fromRGB(46, 26, 20), handleMaterial = Enum.Material.Slate,
			guard = Color3.fromRGB(255, 96, 48), trail = Color3.fromRGB(255, 150, 70), glow = 1,
			fx = { emit = Color3.fromRGB(255, 132, 62), spark = true, trail = Color3.fromRGB(255, 150, 70), halo = Color3.fromRGB(255, 96, 48), pulse = 3.2, smoke = true },
		},
		{
			id = "deep", shape = "harpoon", name = "심해의 작살", rarity = "legend", price = 248900,
			blade = Color3.fromRGB(126, 196, 255), bladeMaterial = Enum.Material.Ice,
			handle = Color3.fromRGB(28, 58, 74), handleMaterial = Enum.Material.Slate,
			guard = Color3.fromRGB(96, 168, 226), trail = Color3.fromRGB(150, 214, 255), glow = 0.6,
			fx = { emit = Color3.fromRGB(150, 214, 255), spark = true, trail = Color3.fromRGB(150, 214, 255), halo = Color3.fromRGB(96, 168, 226), pulse = 1.1, bubbles = true },
		},
		-- Phase 10 : 스타터 팩 · VIP 패스 전용 (코인으로는 살 수 없다)
		{
			id = "starter_hook", shape = "hook", name = "선원의 갈고리", rarity = "rare", price = 0, pack = "starter",
			blade = Color3.fromRGB(176, 186, 196), bladeMaterial = Enum.Material.Metal,
			handle = Color3.fromRGB(34, 64, 96), handleMaterial = Enum.Material.Fabric,
			guard = Color3.fromRGB(226, 178, 86), trail = Color3.fromRGB(186, 220, 255),
			fx = { emit = Color3.fromRGB(186, 220, 255), bubbles = true },
		},
		{
			id = "vip_cutlass", shape = "cutlass", name = "VIP 선장의 곡도", rarity = "legend", price = 0, vip = true,
			blade = Color3.fromRGB(255, 222, 128), bladeMaterial = Enum.Material.Neon,
			handle = Color3.fromRGB(96, 24, 36), handleMaterial = Enum.Material.Leather,
			guard = Color3.fromRGB(255, 236, 170), trail = Color3.fromRGB(255, 222, 128), glow = 0.8,
			fx = { emit = Color3.fromRGB(255, 222, 128), spark = true, trail = Color3.fromRGB(255, 222, 128), halo = Color3.fromRGB(255, 196, 96), pulse = 1.6, coins = true },
		},
	},

	-- Phase 17 : 통 스킨은 전부 20% 내렸다 (값 끝자리는 게임의 다른 값처럼 900 으로 맞춤)
	Barrel = {
		{
			id = "oak", name = "참나무 통", rarity = "common", price = 0,
			body = Color3.fromRGB(122, 78, 44), bodyMaterial = Enum.Material.Wood,
			hoop = Color3.fromRGB(58, 48, 42), hoopMaterial = Enum.Material.Metal,
			lid = Color3.fromRGB(96, 62, 36), glow = Color3.fromRGB(255, 196, 120),
		},
		{
			id = "drum", name = "기름 드럼통", rarity = "common", price = 6900,
			body = Color3.fromRGB(196, 62, 44), bodyMaterial = Enum.Material.CorrodedMetal,
			hoop = Color3.fromRGB(226, 208, 96), hoopMaterial = Enum.Material.Metal,
			lid = Color3.fromRGB(150, 46, 34), glow = Color3.fromRGB(255, 150, 90),
			ribbed = true, -- 드럼통 특유의 가로 주름
			fx = { emit = Color3.fromRGB(255, 150, 90), smoke = true },
		},
		{
			id = "steel", name = "폐유 드럼통", rarity = "common", price = 6900,
			body = Color3.fromRGB(96, 104, 110), bodyMaterial = Enum.Material.DiamondPlate,
			hoop = Color3.fromRGB(58, 64, 70), hoopMaterial = Enum.Material.Metal,
			lid = Color3.fromRGB(78, 86, 92), glow = Color3.fromRGB(180, 220, 255),
			ribbed = true,
			fx = { emit = Color3.fromRGB(180, 220, 255) },
		},
		-- Phase 13 : 파란 철제 드럼 (진짜 200리터 드럼처럼 : 광택 파란 페인트 · 굴림 테 두 줄 · 위아래 주름 · 뚜껑 마개 둘)
		{
			-- Phase 16 : 그룹 가입 보상 (상점에서는 팔지 않는다) → Phase 22 부터 출시 기념 코드 love 선물 (2층 뒤쪽 받침대에서 안내)
			id = "blue_drum", name = "파란 철제 드럼", rarity = "rare", price = 0, reward = "like",
			body = Color3.fromRGB(26, 70, 178), bodyMaterial = Enum.Material.SmoothPlastic, reflectance = 0.16,
			hoop = Color3.fromRGB(34, 84, 196), hoopMaterial = Enum.Material.SmoothPlastic,
			lid = Color3.fromRGB(30, 76, 186), glow = Color3.fromRGB(30, 76, 186), glowMaterial = Enum.Material.SmoothPlastic,
			drum = { bung = Color3.fromRGB(206, 210, 216), bungSmall = Color3.fromRGB(196, 158, 92) },
		},
		{
			id = "treasure", name = "보물 상자", rarity = "rare", price = 44900,
			body = Color3.fromRGB(104, 68, 38), bodyMaterial = Enum.Material.Wood,
			hoop = Color3.fromRGB(240, 202, 104), hoopMaterial = Enum.Material.Metal,
			lid = Color3.fromRGB(240, 202, 104), glow = Color3.fromRGB(255, 220, 140),
			fx = { emit = Color3.fromRGB(255, 220, 140), spark = true, halo = Color3.fromRGB(255, 206, 110), pulse = 1.2, coins = true },
		},
		{
			id = "kimchi", name = "김치통", rarity = "rare", price = 44900,
			body = Color3.fromRGB(236, 66, 52), bodyMaterial = Enum.Material.Plastic,
			hoop = Color3.fromRGB(246, 246, 246), hoopMaterial = Enum.Material.Plastic,
			lid = Color3.fromRGB(246, 246, 246), glow = Color3.fromRGB(255, 150, 130),
			fx = { emit = Color3.fromRGB(255, 120, 100), pulse = 0.9 },
		},
		{
			id = "abyss", name = "심연의 통", rarity = "legend", price = 209900,
			body = Color3.fromRGB(28, 34, 46), bodyMaterial = Enum.Material.Slate,
			hoop = Color3.fromRGB(120, 255, 214), hoopMaterial = Enum.Material.Neon,
			lid = Color3.fromRGB(38, 46, 60), glow = Color3.fromRGB(120, 255, 214),
			fx = { emit = Color3.fromRGB(120, 255, 214), spark = true, halo = Color3.fromRGB(84, 214, 186), pulse = 2.4, bubbles = true },
		},
		-- Phase 8 : 새 통 테마
		{
			id = "volcano", name = "화산의 통", rarity = "epic", price = 112900,
			body = Color3.fromRGB(58, 34, 30), bodyMaterial = Enum.Material.Basalt,
			hoop = Color3.fromRGB(255, 118, 46), hoopMaterial = Enum.Material.Neon,
			lid = Color3.fromRGB(44, 26, 24), glow = Color3.fromRGB(255, 132, 46),
			fx = { emit = Color3.fromRGB(255, 132, 46), spark = true, halo = Color3.fromRGB(255, 90, 40), pulse = 3, smoke = true },
		},
		{
			id = "frost", name = "유빙의 통", rarity = "epic", price = 112900,
			body = Color3.fromRGB(176, 220, 246), bodyMaterial = Enum.Material.Ice,
			hoop = Color3.fromRGB(226, 246, 255), hoopMaterial = Enum.Material.Glass,
			lid = Color3.fromRGB(198, 232, 250), glow = Color3.fromRGB(198, 240, 255),
			fx = { emit = Color3.fromRGB(226, 246, 255), spark = true, pulse = 0.8 },
		},
	},

	Ghost = {
		{
			id = "captain", name = "저주받은 선장", rarity = "common", price = 0,
			coat = Color3.fromRGB(58, 132, 122), skin = Color3.fromRGB(176, 246, 230),
			hat = Color3.fromRGB(28, 36, 42), accent = Color3.fromRGB(240, 202, 104),
			aura = Color3.fromRGB(101, 241, 211),
		},
		{
			id = "skull", name = "해골 선장", rarity = "common", price = 9900,
			coat = Color3.fromRGB(46, 46, 52), skin = Color3.fromRGB(242, 240, 228),
			hat = Color3.fromRGB(22, 22, 26), accent = Color3.fromRGB(226, 226, 226),
			aura = Color3.fromRGB(226, 230, 236),
			fx = { emit = Color3.fromRGB(226, 230, 236), smoke = true },
		},
		{
			id = "kraken", name = "크라켄", rarity = "rare", price = 61900,
			coat = Color3.fromRGB(94, 58, 140), skin = Color3.fromRGB(176, 130, 226),
			hat = Color3.fromRGB(52, 30, 82), accent = Color3.fromRGB(226, 150, 255),
			aura = Color3.fromRGB(196, 130, 255),
			fx = { emit = Color3.fromRGB(196, 130, 255), spark = true, halo = Color3.fromRGB(150, 90, 226), pulse = 1.6, bubbles = true },
		},
		{
			id = "cook", name = "좀비 요리사", rarity = "rare", price = 61900,
			coat = Color3.fromRGB(226, 226, 220), skin = Color3.fromRGB(150, 196, 120),
			hat = Color3.fromRGB(240, 240, 236), accent = Color3.fromRGB(196, 72, 60),
			aura = Color3.fromRGB(170, 226, 130),
			fx = { emit = Color3.fromRGB(170, 226, 130), smoke = true, pulse = 1 },
		},
		{
			id = "ember", name = "잿불 망령", rarity = "legend", price = 298900,
			coat = Color3.fromRGB(96, 34, 20), skin = Color3.fromRGB(255, 160, 90),
			hat = Color3.fromRGB(42, 20, 14), accent = Color3.fromRGB(255, 120, 50),
			aura = Color3.fromRGB(255, 140, 60),
			fx = { emit = Color3.fromRGB(255, 140, 60), spark = true, halo = Color3.fromRGB(255, 90, 40), pulse = 3.4, smoke = true },
		},
		{
			id = "siren", name = "심해의 인어", rarity = "legend", price = 255900,
			coat = Color3.fromRGB(28, 88, 126), skin = Color3.fromRGB(150, 226, 255),
			hat = Color3.fromRGB(20, 60, 90), accent = Color3.fromRGB(120, 255, 255),
			aura = Color3.fromRGB(120, 226, 255),
			fx = { emit = Color3.fromRGB(120, 226, 255), spark = true, halo = Color3.fromRGB(80, 180, 226), pulse = 1.3, bubbles = true },
		},
		-- Phase 8 : 새 괴물
		{
			id = "voidking", name = "공허의 왕", rarity = "epic", price = 144900,
			coat = Color3.fromRGB(26, 22, 40), skin = Color3.fromRGB(150, 130, 226),
			hat = Color3.fromRGB(16, 14, 26), accent = Color3.fromRGB(196, 150, 255),
			aura = Color3.fromRGB(150, 110, 255),
			fx = { emit = Color3.fromRGB(150, 110, 255), spark = true, halo = Color3.fromRGB(110, 70, 220), pulse = 2.6 },
		},
	},

	-- Phase 11 : 칼 꽂는 모션. 내가 칼을 꽂을 때 테이블의 모두가 이 동작을 본다. (결과에는 영향이 없다)
	--   style : StabMotion 이 아는 동작 이름
	--   color : 칼이 지나간 자리에 남는 빛 색
	Stab = {
		{ id = "classic", name = "기본 찌르기", rarity = "common", price = 0, style = "classic", color = Color3.fromRGB(226, 216, 190) },
		{ id = "overhead", name = "내려찍기", rarity = "common", price = 11900, style = "overhead", color = Color3.fromRGB(255, 226, 140) },
		{ id = "triple", name = "세 번 찌르기", rarity = "rare", price = 61900, style = "triple", color = Color3.fromRGB(150, 214, 255) },
		{ id = "spin", name = "회전 베기", rarity = "rare", price = 68900, style = "spin", color = Color3.fromRGB(120, 255, 214) },
		{ id = "flourish", name = "단검 저글링", rarity = "epic", price = 142900, style = "flourish", color = Color3.fromRGB(196, 130, 255) },
		{ id = "ember_slam", name = "잿불 강타", rarity = "legend", price = 277900, style = "slam", color = Color3.fromRGB(255, 132, 62) },
		{ id = "dragon_dive", name = "용의 급강하", rarity = "mythic", price = 499000, style = "dive", color = Color3.fromRGB(68, 240, 218) },
		-- Phase 12 : 시즌 한정 (시즌 보상으로만 받는다 · 상점에서 살 수 없다)
		{ id = "storm_strike", name = "폭풍의 일격", rarity = "legend", price = 0, season = true, style = "bolt", color = Color3.fromRGB(170, 210, 255) },
	},
}

-- id 로 스킨 하나를 찾는다. 없으면 그 종류의 첫 번째(기본)를 돌려준다.
function GameConfig.findSkin(kind, id)
	local list = GameConfig.Skins[kind]
	if not list then
		return nil
	end
	for _, skin in ipairs(list) do
		if skin.id == id then
			return skin
		end
	end
	return list[1]
end

-- 기본으로 처음부터 가지고 있는 스킨 (가격 0 이고 로벅스 · VIP · 묶음 전용이 아닌 것)
function GameConfig.isFreeSkin(skin)
	return skin ~= nil and (tonumber(skin.price) or 0) <= 0 and not skin.robux and not skin.vip and not skin.pack and not skin.season and not skin.reward
end

--------------------------------------------------
-- 코인과 레벨 (Phase 7)
--------------------------------------------------
GameConfig.Economy = {
	WinReward = 360, -- 우승
	ParticipationReward = 75, -- 한 판 끝까지 앉아 있기
	SurviveTurnReward = 18, -- 안전한 자리를 뽑을 때마다
	CatchReward = 55, -- 해적을 잡을 때마다
	StreakBonus = 100, -- 연승 1회당 더해지는 우승 보상 (5연승이면 +500)
	StreakBonusCap = 6, -- 보너스가 커지는 상한 연승 수
	DuoScale = 0.7, -- 2인 테이블은 금방 끝나므로 보상을 줄인다
	PartyScale = 1.25, -- 6인 테이블은 오래 버텨야 하므로 더 준다
	LeaveEarlyReward = 0, -- 중도 이탈은 주지 않는다
	DailyBonus = 450, -- 하루에 한 번 접속 보상 (연속 출석 1일째)
	-- Phase 10 : 연속 출석. 7일을 채우면 다시 1일째부터 돈다. 하루라도 빠지면 1일째로 돌아간다.
	DailyStreakBonus = { 450, 600, 750, 900, 1050, 1200, 2100 },
	PerfectCatchBonus = 45, -- 완벽한 잡기에 더 주는 코인
}

-- 연속 출석 N일째의 보상
function GameConfig.dailyBonusFor(streak)
	local list = GameConfig.Economy.DailyStreakBonus
	local day = ((math.max(1, math.floor(tonumber(streak) or 1)) - 1) % #list) + 1
	return list[day], day
end

-- 레벨 = 판수와 승수가 같이 쌓인다. 승리가 더 크게 쌓이지만 참가만 해도 오른다.
function GameConfig.experienceOf(wins, games)
	return (tonumber(wins) or 0) * 40 + (tonumber(games) or 0) * 12
end

function GameConfig.levelOf(wins, games)
	local xp = GameConfig.experienceOf(wins, games)
	-- 초반은 빠르고 뒤로 갈수록 천천히 오른다.
	return math.max(1, math.floor(math.sqrt(xp / 45)) + 1)
end

function GameConfig.experienceForLevel(level)
	local base = math.max(0, (tonumber(level) or 1) - 1)
	return base * base * 45
end

--------------------------------------------------
-- 통 스킨 우선순위 (Phase 7)
--
-- 같은 테이블에 통 스킨을 적용한 사람이 둘 이상이면 하나만 보여야 한다.
-- "레벨이 높은 사람 것"이 처음 요청이었지만, 그것만으로는
-- 전설 통을 방금 산 새 사람이 기본 참나무 통을 쓰는 고인물에게 항상 진다.
-- 그러면 통 스킨을 살 이유가 사라진다.
--
-- 그래서 순서를 이렇게 둔다.
--   1) 스킨 희귀도 — 어렵게 얻은 통이 이긴다 (상점이 의미를 갖는다)
--   2) 레벨       — 같은 등급이면 오래 한 사람이 이긴다 (원래 요청)
--   3) 현재 연승   — 지금 잘 나가는 사람이 이긴다
--   4) 먼저 앉은 순서 — 남은 동점은 여기서 항상 똑같이 갈린다
--
-- 값이 큰 쪽이 이긴다. 네 단계를 자릿수로 쌓아 한 숫자로 만든다.
--------------------------------------------------
function GameConfig.barrelSkinScore(skin, level, streak, seatOrder)
	local rarity = GameConfig.rarityOf(skin).rank
	local clampedLevel = math.clamp(tonumber(level) or 1, 1, 999)
	local clampedStreak = math.clamp(tonumber(streak) or 0, 0, 99)
	local order = math.clamp(tonumber(seatOrder) or 1, 1, 99)
	return rarity * 1e8 + clampedLevel * 1e5 + clampedStreak * 1e3 + (100 - order)
end

--------------------------------------------------
-- 방해 아이템 (Phase 8, 로벅스)
--
-- ★ 여기서 파는 것은 "상대를 잠깐 불편하게 하는 연출"까지다.
--   위험 자리 힌트 · 잡기 창 늘리기 · 잡기 횟수 추가처럼
--   승률을 직접 사는 물건은 넣지 않는다. 그건 게임을 돈으로 끝내는 일이다.
--
-- 쓰려면 Roblox 크리에이터 페이지에서 개발자 상품을 만들고 그 ID 를 여기에 적는다.
-- productId 가 0 이면 상점에 "준비 중"으로만 뜬다. (Studio 에서는 무료로 시험할 수 있다)
--------------------------------------------------
GameConfig.Sabotage = {
	Enabled = true,
	StudioFreeTest = true, -- Studio 에서는 상품 ID 없이도 눌러볼 수 있다
	Cooldown = 25, -- 같은 사람이 다시 쓰기까지(초)
	PerRoundLimit = 3, -- 한 라운드에 한 사람이 쓸 수 있는 횟수
	TargetMustBeAlive = true,
	-- ★ Phase 24 : duration 이 있는 방해(먹물 · 흔들기 · 뒤섞기 · 포효)는 상대가 칼을 고르는 차례에 발동한다.
	--   지금 상대 차례면 바로, 아니면 상대 차례가 열릴 때 발동한다. 발동 전에 상대가 떨어지거나 판이 끝나면 사용권을 돌려준다.

	Items = {
		{
			id = "ink", name = "먹물 한 통", robux = 15, productId = 0,
			icon = "🖤", color = Color3.fromRGB(58, 52, 74),
			duration = 6,
			blurb = "상대 화면을 먹물로 덮습니다",
			detail = "상대 차례가 오면 6초 동안 상대 화면 가장자리가 먹물로 얼룩집니다. 자리 번호는 계속 읽을 수 있습니다.",
		},
		{
			id = "shake", name = "흔들리는 손", robux = 25, productId = 0,
			icon = "🌀", color = Color3.fromRGB(120, 180, 226),
			duration = 7,
			blurb = "상대의 자리 버튼이 흔들립니다",
			detail = "상대 차례가 오면 칼 선택 버튼이 7초 동안 좌우로 흔들립니다. 누를 수는 있지만 조준이 어려워집니다.",
		},
		{
			id = "hurry", name = "저주의 재촉", robux = 35, productId = 0,
			icon = "⏳", color = Color3.fromRGB(255, 160, 70),
			turnCut = 0.4, -- 다음 턴 제한시간을 이 비율만큼 깎는다
			blurb = "상대의 다음 턴이 짧아집니다",
			detail = "상대의 다음 턴 제한시간이 40% 줄어듭니다. 시간이 끝나면 서버가 대신 골라 줍니다.",
		},
		{
			id = "scramble", name = "뒤섞인 번호", robux = 45, productId = 0,
			icon = "🔀", color = Color3.fromRGB(196, 130, 255),
			duration = 9,
			blurb = "상대 화면의 자리 번호가 뒤섞입니다",
			detail = "상대 차례가 오면 상대 화면에서만 버튼 위 숫자가 9초 동안 뒤섞입니다. 누른 자리는 화면에 보이는 그 자리가 맞습니다. (엉뚱한 곳에 꽂히지는 않습니다)",
		},
		{
			id = "roar", name = "해적의 포효", robux = 55, productId = 0,
			icon = "💀", color = Color3.fromRGB(255, 96, 78),
			duration = 3,
			blurb = "상대 앞에 가짜 해적이 튀어나옵니다",
			detail = "상대 차례가 오면 상대 화면에만 가짜 해적이 한 번 튀어나옵니다. 잡기 창은 열리지 않고 판정에도 영향이 없습니다.",
		},
	},
}

function GameConfig.findSabotage(id)
	for _, item in ipairs(GameConfig.Sabotage.Items) do
		if item.id == id then
			return item
		end
	end
	return nil
end

--------------------------------------------------
-- 로벅스 상품 (Phase 7 · Phase 13 에서 다시 짬)
--
-- ★ Phase 13 : 스킨은 모두 코인으로만 산다. 로벅스로는 코인을 충전한다. (돈 → 코인 → 스킨)
--   코인 숫자는 일부러 크게 보이게 잡았다 (한 판 평균 약 800 코인). 1 코인 ≈ 0.1원.
--   코인 묶음은 영화관 팝콘처럼 값을 매겼다. (400 R$ ≈ 7,500원 기준, R$ 1 ≈ 19원)
--     소     15,000 코인   159 R$ (약 3,000원)
--     중     30,000 코인   319 R$ (약 6,000원)   ← 소 두 개와 똑같다. 일부러 이득이 없다
--     대     70,000 코인   369 R$ (약 7,000원)   ← 중보다 50 R$ 더 내면 코인이 2배 넘게. 희귀 스킨 하나 값
--     특대  160,000 코인   799 R$ (약 15,000원)  ← 영웅 스킨 하나 값
--     금고  500,000 코인 1,999 R$ (약 37,000원)  ← 신화 스킨 하나 값. 크게 쓰는 사람용
--   robux 값은 상점에 보이는 숫자일 뿐이다. 실제 가격은 Creator Hub 에서 상품을 만들 때 같은 값으로 적는다.
--------------------------------------------------
GameConfig.Products = {
	Coins = {
		{ id = "coins_small", size = "소", name = "코인 15,000", coins = 15000, robux = 159, productId = 0 },
		{ id = "coins_medium", size = "중", name = "코인 30,000", coins = 30000, robux = 319, productId = 0 },
		{ id = "coins_large", size = "대", name = "코인 70,000", coins = 70000, robux = 369, productId = 0,
			highlight = true, badge = "🔥 인기!" },
		{ id = "coins_huge", size = "특대", name = "코인 160,000", coins = 160000, robux = 799, productId = 0, badge = "👑 추천" },
		{ id = "coins_vault", size = "금고", name = "코인 500,000", coins = 500000, robux = 1999, productId = 0, badge = "💎 최고 가치" },
	},
	-- 로벅스 전용 스킨 (Phase 13 부터 비움 : 스킨은 코인으로만 산다). skin 에는 "Knife/ember" 처럼 적는다.
	Skins = {},

	-- Phase 10 : 스타터 팩 (계정당 한 번). 처음 들어온 사람이 가장 많이 사는 묶음이다.
	-- 게임 결과를 바꾸는 것은 넣지 않는다. 코인과 전용 칼 스킨뿐이다.
	Starter = {
		id = "starter", name = "선원 스타터 팩", robux = 99, productId = 0,
		coins = 25000, skin = "Knife/starter_hook",
		blurb = "코인 25,000 + 전용 칼",
	},

	-- Phase 10 : 게임패스. Creator Dashboard 에서 게임패스를 만들고 그 ID 를 gamePassId 에 적는다.
	-- 0 이면 상점에 "준비 중"으로만 보인다.
	GamePasses = {
		VIP = {
			id = "vip", name = "VIP 선장 패스", robux = 399, gamePassId = 0,
			coinBonus = 0.2, -- 게임에서 버는 코인 +20% (퀘스트 · 업적 · 출석 보상에는 붙지 않는다)
			skin = "Knife/vip_cutlass",
			blurb = "코인 +20% · 전용 칼 · VIP 표시",
			attribute = "VIP",
		},
		-- Phase 12 : 현상금 부스터. 내가 이긴 판의 현상금이 늘어난다. (판정 · 확률에는 영향 없음)
		Booster = {
			id = "booster", name = "현상금 부스터", robux = 249, gamePassId = 0,
			potBonus = 0.1, -- 내가 가져가는 현상금 +10%
			blurb = "현상금 +10%",
			attribute = "Booster",
		},
	},
}

--------------------------------------------------
-- 일일 퀘스트 · 업적 (Phase 8)
--------------------------------------------------
GameConfig.Quests = {
	Enabled = true,
	DailyCount = 3, -- 하루에 주어지는 개수
	Pool = {
		{ id = "play3", text = "3판 참가하기", metric = "games", goal = 3, reward = 360 },
		{ id = "win1", text = "1판 우승하기", metric = "wins", goal = 1, reward = 600 },
		{ id = "catch5", text = "해적 5번 잡기", metric = "catches", goal = 5, reward = 540 },
		{ id = "safe12", text = "안전한 자리 12번 뽑기", metric = "safePicks", goal = 12, reward = 450 },
		{ id = "duo2", text = "2인 테이블에서 2판 하기", metric = "duoGames", goal = 2, reward = 390 },
		{ id = "party1", text = "6인 테이블에서 1판 하기", metric = "partyGames", goal = 1, reward = 480 },
		{ id = "streak2", text = "2연승 만들기", metric = "bestStreakToday", goal = 2, reward = 660 },
		-- Phase 10
		{ id = "brave3", text = "배짱으로 3번 더 찌르고 살아남기", metric = "bravePicks", goal = 3, reward = 600 },
		{ id = "perfect2", text = "해적을 완벽하게 2번 잡기", metric = "perfectCatches", goal = 2, reward = 660 },
		-- Phase 12
		{ id = "cannon10", text = "대포로 크라켄을 10번 맞히기", metric = "cannonHits", goal = 10, reward = 480 },
		{ id = "raid1", text = "크라켄 습격 물리치기에 참여하기", metric = "raidWins", goal = 1, reward = 600 },
		{ id = "predict2", text = "관전하며 생존자 2번 맞히기", metric = "predictWins", goal = 2, reward = 450 },
	},
}

GameConfig.Achievements = {
	{ id = "first_win", text = "첫 승리", metric = "wins", goal = 1, reward = 600 },
	{ id = "win10", text = "10승", metric = "wins", goal = 10, reward = 1800 },
	{ id = "win50", text = "50승", metric = "wins", goal = 50, reward = 7500 },
	{ id = "catch50", text = "해적 50번 잡기", metric = "catches", goal = 50, reward = 2700 },
	{ id = "catch250", text = "해적 250번 잡기", metric = "catches", goal = 250, reward = 9000 },
	{ id = "streak3", text = "3연승", metric = "bestStreak", goal = 3, reward = 2100 },
	{ id = "streak7", text = "7연승", metric = "bestStreak", goal = 7, reward = 8400 },
	{ id = "games100", text = "100판 참가", metric = "games", goal = 100, reward = 3600 },
	-- Phase 10
	{ id = "brave25", text = "배짱으로 25번 살아남기", metric = "bravePicks", goal = 25, reward = 2700 },
	{ id = "perfect20", text = "완벽한 잡기 20회", metric = "perfectCatches", goal = 20, reward = 3300 },
	-- Phase 12 (title 이 있으면 머리 위 칭호가 생긴다)
	{ id = "cannon100", text = "대포로 크라켄 100번 맞히기", metric = "cannonHits", goal = 100, reward = 2400 },
	{ id = "raid10", text = "크라켄 습격 10번 물리치기", metric = "raidWins", goal = 10, reward = 6000, title = "크라켄 사냥꾼" },
	{ id = "crew5", text = "친구 · 파티와 같은 판에서 5번 우승", metric = "crewWins", goal = 5, reward = 2700, title = "선원 동료" },
	{ id = "tourney34", text = "토너먼트 시리즈 34점 이상", metric = "bestSeries", goal = 34, reward = 7500, title = "토너먼트 챔피언" },
}

--------------------------------------------------
-- 연승 표시 (Phase 8)
-- 플레이어 머리 위 불꽃 안에 숫자가 뜬다.
--------------------------------------------------
GameConfig.Streak = {
	MinToShow = 2, -- 2연승부터 보인다
	MaxDistance = 90,
	Tiers = {
		{ min = 2, color = Color3.fromRGB(255, 186, 78), label = "불꽃" },
		{ min = 4, color = Color3.fromRGB(255, 120, 50), label = "맹렬" },
		{ min = 7, color = Color3.fromRGB(150, 110, 255), label = "공허" },
		{ min = 10, color = Color3.fromRGB(120, 255, 214), label = "전설" },
	},
}

function GameConfig.streakTier(streak)
	local chosen = GameConfig.Streak.Tiers[1]
	for _, tier in ipairs(GameConfig.Streak.Tiers) do
		if streak >= tier.min then
			chosen = tier
		end
	end
	return chosen
end

--------------------------------------------------
-- 길 안내 화살표 (Phase 8)
-- 누가 앉아서 사람을 기다리는 중이면, 서 있는 사람 발밑에 화살표가 뜬다.
--------------------------------------------------
GameConfig.Wayfinder = {
	Enabled = true,
	ShowWhenSeatedAtLeast = 1, -- 이만큼 앉아 있으면 안내를 켠다
	ArriveDistance = 9, -- 이 안에 들어오면 화살표를 끈다
	Color = Color3.fromRGB(255, 206, 110),
	UrgentColor = Color3.fromRGB(120, 255, 214),
}

--------------------------------------------------
-- AI 선원 (Phase 11)
--
-- 혼자 앉아 기다리는 사람이 있으면, 잠시 뒤 AI 선원이 빈 의자에 앉아 같이 한다.
-- 사람이 더 오면(MinPlayers 이상) 대기 중인 AI 는 자리를 비켜 준다.
--
-- ★ AI 와 함께한 판은 "연습 판"이다.
--   코인은 RewardScale 만큼만 받고, 승수 · 연승 · 랭킹에는 들어가지 않는다.
--   (AI 를 상대로 랭킹을 올리는 일을 막는다. 퀘스트 진행은 된다)
-- ★ AI 는 서버가 조종한다. 통 안의 해적 위치를 AI 도 모른다. 사람과 똑같이 무작위로 고른다.
--------------------------------------------------
GameConfig.Bots = {
	Enabled = true,
	FillDelay = 10, -- 혼자 앉은 뒤 이만큼 기다려도 아무도 안 오면 AI 가 앉는다 (Phase 24 : 4초 → 10초. 사람이 모일 틈을 준다)
	TargetSeated = 3, -- AI 를 채워서 맞출 인원 (좌석이 모자라면 좌석 수 - 1)
	KeepFreeSeats = 1, -- 사람이 들어올 자리는 항상 남겨 둔다
	RewardScale = 0.6,
	ThinkMin = 1.1, -- 자기 차례에 고르기까지 걸리는 시간
	ThinkMax = 2.8,
	-- 성격. skill 이 높을수록 해적을 잘 잡고, brave 가 높을수록 "한 번 더"를 자주 누른다.
	Crew = {
		{ name = "뼈다귀 잭", skill = 0.45, brave = 0.25, color = Color3.fromRGB(226, 222, 206) },
		{ name = "외눈 몰리", skill = 0.6, brave = 0.45, color = Color3.fromRGB(150, 226, 255) },
		{ name = "소금물 샘", skill = 0.5, brave = 0.15, color = Color3.fromRGB(170, 226, 130) },
		{ name = "갈고리 한스", skill = 0.7, brave = 0.35, color = Color3.fromRGB(255, 196, 120) },
		{ name = "안개 속 루", skill = 0.4, brave = 0.6, color = Color3.fromRGB(196, 150, 255) },
		{ name = "녹슨 닻 벤", skill = 0.55, brave = 0.3, color = Color3.fromRGB(255, 150, 130) },
	},
}

-- AI 선원인가. (AI 는 Player 가 아니라 BotService 가 만든 표다)
function GameConfig.isBot(who)
	return type(who) == "table" and rawget(who, "IsBot") == true
end

--------------------------------------------------
-- 테이블 종류 배정 (Phase 8)
--
-- 맵 파일 안의 테이블은 전부 Standard4 / Duo2 로 저장돼 있다.
-- 6인 테이블과 빠른 모드를 넣으려고 .rbxl 을 손으로 고치는 대신,
-- 모델 이름으로 종류를 덮어쓴다. 여기 한 줄만 고치면 테이블 성격이 바뀐다.
--
-- ★ 6인 테이블(Party6)은 해적이 두 마리다. 좌석은 TableBuilder 가 만들어 붙인다.
--------------------------------------------------
-- Phase 21 : 스폰(뱃머리 계단)에서 가까운 줄부터 2인 → 3인 → 4인 (ShipLayout.Tables 의 z 가 클수록 스폰에 가깝다)
--   I · J (z 85) 2인 · A · B (z 50) 2인 · C · D (z 12) 3인 · E (z -26) 4인 · F (z -26) 토너먼트 4인 · H 선미 2층 6인
GameConfig.TableTypeByName = {
	Table_I = "Duo2", Table_J = "Duo2",
	Table_A = "Duo2", Table_B = "Duo2",
	Table_C = "Trio3", Table_D = "Trio3",
	Table_E = "Standard4", -- Table_F 는 아래에서 토너먼트 4인으로 지정한다
	Table_H = "PartyCards6", -- 선미 2층 중앙의 유일한 6인 테이블
}

--------------------------------------------------
-- 로비 전시장 (Phase 5 · Phase 6 에서 설명 줄을 걷어냈다)
--------------------------------------------------
GameConfig.Showcase = {
	-- 간판이 바라봐야 하는 지점 = 사람들이 들어오는 쪽(스폰).
	-- 맵에 LobbySpawn 이 있으면 그 위치를 쓰고, 없을 때만 이 값을 쓴다.
	LobbyFocus = Vector3.new(0, 6, 100),

	-- 지울 것들. "선장의 휴식처"는 형태만 있고 쓰임이 없어 걷어낸다.
	RemoveNames = { "BarCounter", "BarTop", "BarSign", "Bottle" },

	Z = -95, -- 전시대가 늘어서는 줄
	SignZ = -106, -- 구역 간판
	Spacing = 8,

	-- ★ 간판에는 구역 이름만 남긴다.
	--   "드럼통 · 보물상자 · 김치통" 같은 설명 줄은 어차피 밑에 이름표가 있어서 중복이었다.
	Zones = {
		{ kind = "Ghost", title = "해적 스킨", x = -52, color = Color3.fromRGB(150, 226, 255) },
		{ kind = "Barrel", title = "통 스킨", x = 6, color = Color3.fromRGB(240, 202, 104) },
		{ kind = "Knife", title = "칼 스킨", x = 64, color = Color3.fromRGB(242, 130, 120) },
	},
}

--------------------------------------------------
-- 항구와 해적선 (Phase 6)
-- MapBuilder 가 이 값으로 배와 부둣가를 세운다.
--------------------------------------------------
GameConfig.Map = {
	Enabled = true,

	Ship = {
		Origin = Vector3.new(-6, 0, 74), -- 배의 중심 (스폰 뒤쪽 바다 위)
		Facing = 180, -- 뱃머리가 보는 방향(도)
		Length = 86,
		Beam = 26,
		HullHeight = 13,
		DeckHeight = 9.5,
		Masts = 3,
		Sail = Color3.fromRGB(226, 214, 186),
		Hull = Color3.fromRGB(74, 46, 28),
		HullDark = Color3.fromRGB(48, 30, 19),
		Trim = Color3.fromRGB(226, 178, 86),
		Rope = Color3.fromRGB(128, 104, 72),
	},

	Sea = {
		Level = -2.2,
		Size = 1500, -- 파일에 원래 있던 HarborSea(1500)를 완전히 덮는다
		Color = Color3.fromRGB(26, 58, 78),
		WaveHeight = 0.55,
		WaveSpeed = 0.6,
	},

	Props = {
		Crates = 26,
		Barrels = 22,
		Lanterns = 18,
		Ropes = 12,
		Gulls = 7,
	},

	-- Phase 6 성능 규칙. 장식은 전부 이 규칙을 따른다.
	Decor = {
		CastShadow = false,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	},
}

--------------------------------------------------
-- Phase 15 : 바다에 빠지면 배 위로 건져 올린다
--   예전에는 바다(장식 파트)를 뚫고 끝없이 떨어져 죽은 뒤 되살아나지 않는 일이 있었다.
--   이제는 물에 빠지는 순간 가장 가까운 갑판 가운데로 옮겨 준다. (죽지 않는다)
--   그래도 어떤 이유로든 죽으면 서버가 부활을 한 번 더 챙긴다.
--------------------------------------------------
GameConfig.Rescue = {
	Enabled = true,
	BelowY = -3.6, -- 몸 중심이 이보다 낮으면 물에 빠진 것 (바다 -2.2, 갑판 1)
	FarXZ = 260, -- 배에서 이만큼 멀리 나가도 건진다
	Interval = 0.15,
	-- 건져 올릴 자리 (갑판 가운데 줄. 테이블 · 돛대 · 계단을 피한다)
	Spots = {
		Vector3.new(0, 4.2, 98),
		Vector3.new(0, 4.2, 62),
		Vector3.new(0, 4.2, 12),
		Vector3.new(0, 4.2, -24),
		Vector3.new(0, 4.2, -62),
		Vector3.new(0, 4.2, -94),
	},
	FallenPartsDestroyHeight = -140,
	RespawnSafety = 2, -- 죽은 뒤 RespawnTime 에서 이만큼 더 기다려도 안 살아나면 서버가 살린다
}

--------------------------------------------------
-- 서버와 클라이언트가 같은 시계를 본다.
--------------------------------------------------
function GameConfig.now()
	return workspace:GetServerTimeNow()
end

--------------------------------------------------
-- 라이팅 프리셋 (Phase 2)
--------------------------------------------------
GameConfig.Lighting = {
	ApplyLobbyOnJoin = true,
	TweenTime = 1.4,

	Lobby = {
		Ambient = Color3.fromRGB(122, 120, 116),
		OutdoorAmbient = Color3.fromRGB(154, 158, 168),
		Brightness = 2.8,
		ClockTime = 14.3,
		ExposureCompensation = 0,
		FogColor = Color3.fromRGB(206, 214, 224),
		FogEnd = 100000,
		Atmosphere = {
			Density = 0.26,
			Offset = 0.1,
			Color = Color3.fromRGB(226, 226, 220),
			Decay = Color3.fromRGB(150, 165, 185),
			Glare = 0,
			Haze = 0.6,
		},
		Bloom = { Intensity = 0.3, Size = 22, Threshold = 1.3 },
		ColorCorrection = {
			Brightness = 0.01,
			Contrast = 0.06,
			Saturation = 0.1,
			TintColor = Color3.fromRGB(255, 252, 246),
		},
	},

	Game = {
		Ambient = Color3.fromRGB(38, 32, 28),
		OutdoorAmbient = Color3.fromRGB(28, 34, 44),
		Brightness = 1.2,
		ClockTime = 21.4,
		ExposureCompensation = 0.2,
		FogColor = Color3.fromRGB(28, 26, 30),
		FogEnd = 100000,
		Atmosphere = {
			Density = 0.42,
			Offset = 0.2,
			Color = Color3.fromRGB(190, 176, 158),
			Decay = Color3.fromRGB(58, 62, 78),
			Glare = 0.3,
			Haze = 2.2,
		},
		Bloom = { Intensity = 0.75, Size = 28, Threshold = 0.95 },
		ColorCorrection = {
			Brightness = -0.02,
			Contrast = 0.16,
			Saturation = -0.05,
			TintColor = Color3.fromRGB(255, 240, 224),
		},
	},
}

--------------------------------------------------
-- 디버그 로그
--------------------------------------------------
function GameConfig.log(...)
	if GameConfig.DEBUG then
		print("[CursedBarrel]", ...)
	end
end


-- Phase 9: original premium themes, cosmetic-only catalog.
GameConfig.Skins.PlayerAttributes.Chair = "ChairSkin"
GameConfig.Skins.PlayerAttributes.Elimination = "EliminationSkin"
GameConfig.Skins.PlayerAttributes.Victory = "VictorySkin"
GameConfig.Skins.Chair = {
 {id="classic",name="선술집 의자",rarity="common",price=0},
 {id="captain",name="선장의 황금좌",rarity="epic",price=130900,fx={theme="solar",emit=Color3.fromRGB(255,198,87)}},
 {id="dragon_throne",name="해룡의 왕좌",rarity="mythic",price=499000,fx={theme="dragon",emit=Color3.fromRGB(68,240,218)}},
}
-- Phase 24 : 탈락 · 승리 연출 가격을 30% 내렸다 (연출에 비해 비쌌다). 이미 산 사람은 그대로.
GameConfig.Skins.Elimination = {
 {id="classic",name="유령의 흔적",rarity="common",price=0},
 {id="rift",name="심연의 균열",rarity="epic",price=96900,fx={theme="void",emit=Color3.fromRGB(186,102,255)}},
 {id="dragon_devour",name="용의 심판",rarity="mythic",price=349000,fx={theme="dragon",emit=Color3.fromRGB(68,240,218)}},
}
GameConfig.Skins.Victory = {
 {id="classic",name="선장의 경례",rarity="common",price=0},
 {id="solar_crown",name="태양의 대관식",rarity="epic",price=100900,fx={theme="solar",emit=Color3.fromRGB(255,198,87)}},
 {id="dragon_ascension",name="쌍룡 승천",rarity="mythic",price=349000,fx={theme="dragon",emit=Color3.fromRGB(68,240,218)}},
}
local themes = {
 {id="tide_dragon",name="청해룡",theme="dragon",color=Color3.fromRGB(68,240,218),accent=Color3.fromRGB(255,212,126)},
 {id="crimson_dragon",name="적염룡",theme="dragon",color=Color3.fromRGB(255,93,68),accent=Color3.fromRGB(255,210,96)},
 {id="moon_dragon",name="월백룡",theme="dragon",color=Color3.fromRGB(156,181,255),accent=Color3.fromRGB(242,250,255)},
}
for _, t in ipairs(themes) do
 local fx={theme=t.theme,emit=t.color,trail=t.color,halo=t.accent,spark=true,pulse=1.2,accent=t.accent}
 table.insert(GameConfig.Skins.Knife,{id=t.id,shape="fang",name=t.name.."의 송곳니",rarity="mythic",price=499000,blade=t.color,bladeMaterial=Enum.Material.Neon,handle=Color3.fromRGB(19,27,40),handleMaterial=Enum.Material.Metal,guard=t.accent,trail=t.color,glow=0.6,fx=fx})
 table.insert(GameConfig.Skins.Barrel,{id=t.id,name=t.name.."의 봉인",rarity="mythic",price=399000,body=Color3.fromRGB(24,36,49),bodyMaterial=Enum.Material.Slate,hoop=t.accent,hoopMaterial=Enum.Material.Metal,lid=t.color,glow=t.color,fx=fx})
 table.insert(GameConfig.Skins.Ghost,{id=t.id,name=t.name.."의 수호자",rarity="mythic",price=499000,coat=Color3.fromRGB(25,39,56),skin=t.color,hat=Color3.fromRGB(20,28,42),accent=t.accent,aura=t.color,fx=fx})
end
for _, list in ipairs({GameConfig.Skins.Knife,GameConfig.Skins.Barrel,GameConfig.Skins.Ghost}) do
 for _, skin in ipairs(list) do
  if skin.fx and not skin.fx.theme then
   if skin.id=="ember" or skin.id=="volcano" then skin.fx.theme="phoenix"
   elseif skin.id=="deep" or skin.id=="kraken" then skin.fx.theme="kraken"
   elseif skin.id=="void" or skin.id=="voidking" or skin.id=="abyss" then skin.fx.theme="void"
   elseif skin.id=="ice" or skin.id=="frost" or skin.id=="glacier" then skin.fx.theme="frost"
   elseif skin.rarity=="legend" then skin.fx.theme="solar" end
  end
 end
end
GameConfig.TableTypeByName.Table_H = "PartyCards6"

--------------------------------------------------
-- Phase 12 : 승리 · 탈락 연출 추가 (전부 모양일 뿐이다)
--------------------------------------------------
for _, skin in ipairs({
	{ id = "gold_rain", name = "황금 비", rarity = "rare", price = 47900, fx = { theme = "solar", emit = Color3.fromRGB(255, 214, 90) } },
	{ id = "frost_crown", name = "서리 왕관", rarity = "epic", price = 99900, fx = { theme = "frost", emit = Color3.fromRGB(190, 235, 255) } },
	{ id = "kraken_embrace", name = "크라켄의 포옹", rarity = "epic", price = 103900, fx = { theme = "kraken", emit = Color3.fromRGB(196, 130, 255) } },
	{ id = "storm_lord", name = "폭풍의 군주", rarity = "legend", price = 203900, fx = { theme = "void", emit = Color3.fromRGB(150, 200, 255), accent = Color3.fromRGB(240, 248, 255) } },
}) do
	table.insert(GameConfig.Skins.Victory, skin)
end
for _, skin in ipairs({
	{ id = "ink_burst", name = "먹물 폭발", rarity = "rare", price = 44900, fx = { theme = "kraken", emit = Color3.fromRGB(96, 50, 130) } },
	{ id = "ember_ash", name = "잿더미", rarity = "epic", price = 97900, fx = { theme = "phoenix", emit = Color3.fromRGB(255, 120, 50) } },
	{ id = "frost_shatter", name = "얼음 파편", rarity = "epic", price = 97900, fx = { theme = "frost", emit = Color3.fromRGB(190, 235, 255) } },
}) do
	table.insert(GameConfig.Skins.Elimination, skin)
end

--------------------------------------------------
-- Phase 12 : 시간과 날씨 (항해 시계)
--
-- 서버가 15분마다 한 바퀴 도는 시계를 돌린다. 단계마다 하늘 · 안개 · 비 · 번개와 판 규칙이 바뀐다.
--   낮 → 노을 → 밤 → 안개 → 폭풍(크라켄 습격) → 새벽 → 낮 …
-- mods (판 규칙. RoundService 가 읽는다)
--   pot          : 현상금이 쌓이는 배율
--   surge        : 보물 폭발 확률 배율
--   lead         : 해적이 튀어나오기까지 시간 배율 (작을수록 빨리 나온다. MinLead 아래로는 안 내려간다)
--   extraPirate  : 통 안의 해적 수 추가
--   fog          : 칼 고르는 창의 번호가 안개에 가려진다 (내 화면에서만. 누르는 자리는 그대로)
-- ★ 서버마다 시작 시각을 흔들어 둔다. 여러 서버가 한꺼번에 습격을 맞지 않는다.
--------------------------------------------------
GameConfig.World = {
	Enabled = true,
	Transition = 10, -- 하늘이 바뀌는 데 걸리는 시간(초)
	-- Studio 에서 빨리 보고 싶으면 이 값을 줄인다. (0.2 면 한 바퀴 3분)
	StudioTimeScale = 1,
	-- Studio 에서 특정 단계부터 보고 싶으면 id 를 적는다. (예: "storm")
	StudioStartPhase = nil,
	Phases = {
		{ id = "day", name = "낮", icon = "☀", duration = 240, blurb = "평온한 항해", mods = {} },
		{ id = "dusk", name = "노을", icon = "🌇", duration = 90, blurb = "황금 시간 · 보물 폭발 2배", mods = { surge = 2 } },
		{ id = "night", name = "밤", icon = "🌙", duration = 180, blurb = "현상금 +25% · 해적이 더 빨리 나온다", mods = { pot = 1.25, lead = 0.9 } },
		{ id = "fog", name = "안개", icon = "🌫", duration = 150, blurb = "자리 번호가 안개에 가려진다 · 현상금 +25%", mods = { pot = 1.25, fog = true } },
		{ id = "storm", name = "폭풍", icon = "⛈", duration = 180, blurb = "크라켄 습격! · 현상금 2배 · 해적 +1", mods = { pot = 2, extraPirate = 1, raid = true } },
		{ id = "dawn", name = "새벽", icon = "🌅", duration = 60, blurb = "폭풍이 지나간다", mods = {} },
	},

	-- 단계별 하늘. (WorldController 가 부드럽게 옮겨 간다)
	Sky = {
		day = { Ambient = Color3.fromRGB(128, 126, 122), OutdoorAmbient = Color3.fromRGB(160, 164, 174), Brightness = 3, ClockTime = 14.3, Exposure = 0.05,
			Density = 0.26, Offset = 0.1, AirColor = Color3.fromRGB(226, 226, 220), Decay = Color3.fromRGB(150, 165, 185), Glare = 0, Haze = 0.6,
			Tint = Color3.fromRGB(255, 252, 246), Saturation = 0.22, Contrast = 0.1, Rain = 0, Lightning = 0, Sea = Color3.fromRGB(28, 104, 150), PlayerGlow = 0 },
		dusk = { Ambient = Color3.fromRGB(132, 98, 82), OutdoorAmbient = Color3.fromRGB(176, 124, 102), Brightness = 2.2, ClockTime = 17.9, Exposure = 0.1,
			Density = 0.32, Offset = 0.12, AirColor = Color3.fromRGB(255, 190, 150), Decay = Color3.fromRGB(180, 110, 90), Glare = 0.6, Haze = 1.4,
			Tint = Color3.fromRGB(255, 226, 200), Saturation = 0.15, Contrast = 0.08, Rain = 0, Lightning = 0, Sea = Color3.fromRGB(58, 52, 70), PlayerGlow = 0.35 },
		-- 밤 · 안개 · 폭풍도 캄캄하지 않게 (등불이 없는 곳도 형체가 보인다)
		-- Phase 21 : 밤 · 안개 · 폭풍 주변광을 한 단계 밝혔다 (등불이 안 닿는 곳이 너무 어두웠다)
		night = { Ambient = Color3.fromRGB(100, 108, 146), OutdoorAmbient = Color3.fromRGB(112, 126, 166), Brightness = 1.8, ClockTime = 0.2, Exposure = 0.62,
			Density = 0.36, Offset = 0.1, AirColor = Color3.fromRGB(110, 130, 170), Decay = Color3.fromRGB(40, 50, 80), Glare = 0, Haze = 1.2,
			Tint = Color3.fromRGB(200, 215, 255), Saturation = -0.15, Contrast = 0.12, Rain = 0, Lightning = 0, Sea = Color3.fromRGB(12, 24, 40), PlayerGlow = 1.3 },
		fog = { Ambient = Color3.fromRGB(108, 114, 124), OutdoorAmbient = Color3.fromRGB(130, 138, 150), Brightness = 1.6, ClockTime = 3.2, Exposure = 0.5,
			Density = 0.62, Offset = 0.25, AirColor = Color3.fromRGB(170, 180, 190), Decay = Color3.fromRGB(120, 130, 140), Glare = 0, Haze = 3.4,
			Tint = Color3.fromRGB(225, 232, 240), Saturation = -0.3, Contrast = 0.04, Rain = 0, Lightning = 0, Sea = Color3.fromRGB(34, 44, 52), PlayerGlow = 1.0 },
		storm = { Ambient = Color3.fromRGB(92, 98, 116), OutdoorAmbient = Color3.fromRGB(106, 114, 138), Brightness = 1.4, ClockTime = 4.5, Exposure = 0.56,
			Density = 0.5, Offset = 0.2, AirColor = Color3.fromRGB(90, 100, 110), Decay = Color3.fromRGB(30, 40, 50), Glare = 0, Haze = 2.6,
			Tint = Color3.fromRGB(205, 225, 220), Saturation = -0.25, Contrast = 0.18, Rain = 1, Lightning = 1, Sea = Color3.fromRGB(14, 30, 36), PlayerGlow = 1.1 },
		dawn = { Ambient = Color3.fromRGB(112, 98, 112), OutdoorAmbient = Color3.fromRGB(150, 130, 150), Brightness = 1.8, ClockTime = 6.6, Exposure = 0.1,
			Density = 0.3, Offset = 0.1, AirColor = Color3.fromRGB(255, 200, 190), Decay = Color3.fromRGB(120, 110, 150), Glare = 0.4, Haze = 1.2,
			Tint = Color3.fromRGB(255, 236, 230), Saturation = 0.05, Contrast = 0.06, Rain = 0.15, Lightning = 0, Sea = Color3.fromRGB(40, 52, 72), PlayerGlow = 0.5 },
	},
	current = nil, -- 서버의 WorldService 가 지금 단계를 적어 둔다 (서버 전용)
}

function GameConfig.findPhase(id)
	for _, phase in ipairs(GameConfig.World.Phases) do
		if phase.id == id then
			return phase
		end
	end
	return GameConfig.World.Phases[1]
end

function GameConfig.worldCycleLength()
	local total = 0
	for _, phase in ipairs(GameConfig.World.Phases) do
		total += phase.duration
	end
	return total
end

-- 시계가 elapsed 초 흘렀을 때의 단계. (단계, 그 단계 안에서 지난 초, 단계 길이, 몇 번째 바퀴)
function GameConfig.worldPhaseAt(elapsed)
	local cycle = GameConfig.worldCycleLength()
	local e = math.max(0, tonumber(elapsed) or 0)
	local lap = math.floor(e / cycle)
	local into = e - lap * cycle
	for _, phase in ipairs(GameConfig.World.Phases) do
		if into < phase.duration then
			return phase, into, phase.duration, lap
		end
		into -= phase.duration
	end
	local last = GameConfig.World.Phases[#GameConfig.World.Phases]
	return last, last.duration, last.duration, lap
end

-- 지금 판 규칙. 서버에서는 WorldService 가 current 를 적고, 클라이언트는 workspace Attribute 를 읽는다.
function GameConfig.worldMods()
	if not GameConfig.World.Enabled then
		return {}
	end
	local phase = GameConfig.World.current
	if not phase then
		local ok, id = pcall(function()
			return workspace:GetAttribute("WorldPhase")
		end)
		phase = ok and id and GameConfig.findPhase(id) or nil
	end
	return (phase and phase.mods) or {}
end

--------------------------------------------------
-- Phase 12 : 크라켄 습격 (폭풍 단계에 온다)
--
-- 크라켄이 다리로 갑판을 내려친다. 대포로 다리 · 눈을 맞히면 체력이 깎이고, 0 이 되면 물러난다.
-- 내려치기 직전의 다리를 맞히면 내려치기를 막는다. (체력이 크게 깎인다)
-- ★ 내려치기는 전부 연출이다. 사람을 밀거나 다치게 하지 않는다. 테이블 게임도 멈추지 않는다.
-- ★ 내려치는 자리(SlamZones)는 테이블 · 의자 · 대포 · 계단을 피해 뱃전 쪽에 둔다.
--------------------------------------------------
GameConfig.Raid = {
	Enabled = true,
	StartDelay = 8, -- 폭풍이 시작되고 이만큼 뒤에 습격이 시작된다
	EndBefore = 6, -- 폭풍이 끝나기 이만큼 전에 습격이 끝난다 (못 물리치면 크라켄이 떠난다)
	BaseHP = 60,
	HPPerPlayer = 18, -- 서버 인원 1명마다 체력 추가
	HitDamage = 1, -- 다리 약점
	EyeDamage = 3, -- 눈
	BlockDamage = 4, -- 내려치기 직전의 다리
	SlamEvery = { 5, 8 }, -- 내려치기 간격(초, 이 사이에서 무작위)
	SlamWindup = 1.6, -- 다리를 치켜들고 있는 시간 (이때 맞히면 막는다)
	SlamLinger = 0.9, -- 갑판에 닿은 채로 있는 시간
	SlamRetract = 1.2,
	SlamInset = 9, -- 갑판에서 뱃전 안쪽으로 이만큼 들어온 자리를 친다
	SlamZones = {
		{ side = -1, z = 76 }, { side = -1, z = 23 }, { side = -1, z = -20 },
		{ side = 1, z = 74 }, { side = 1, z = 30 }, { side = 1, z = -28 },
	},
	WinCoins = 180, -- 물리치면 참여한 사람 모두에게
	CoinsPerHit = 9, -- 맞힌 횟수만큼 더
	WinCoinsCap = 450,
	EscapeCoins = 45, -- 못 물리쳐도 한 번이라도 맞힌 사람에게
}

--------------------------------------------------
-- Phase 12 : 대포 미니게임
-- 뱃전의 대포 8문. 다가가서 E(모바일은 탭)로 잡고, 크라켄 다리의 빛나는 약점이나 눈을 누르면 쏜다.
-- 평소에는 적은 코인(하루 상한), 습격 때는 크라켄 체력을 깎는다.
--------------------------------------------------
GameConfig.Cannon = {
	Enabled = true,
	Cooldown = 1.4,
	Range = 200,
	MaxAngle = 80, -- 대포가 바깥을 보는 방향에서 이만큼까지만 돌릴 수 있다
	PromptDistance = 10,
	LeaveDistance = 16, -- 대포에서 이보다 멀어지면 자동으로 내린다
	IdleTimeout = 90, -- 이만큼 안 쏘면 자동으로 내린다
	CoinsPerHit = 6,
	EyeCoins = 12,
	DailyCoinCap = 300, -- 평소 대포로 벌 수 있는 하루 코인
	TargetRadius = 4.4, -- 다리 약점 판정 반지름
	EyeRadius = 4.2,
	SlamRadius = 5.5,
}

--------------------------------------------------
-- Phase 12 : 관전 예측 · 연습 판 · 토너먼트 · 친구 초대 · 행운의 테이블
--------------------------------------------------
GameConfig.Prediction = {
	Enabled = true,
	BaseCoins = 45,
	PerPlayer = 15, -- 참가 인원 1명마다 더
	MaxCoins = 120,
	DailyCap = 10, -- 하루에 보상을 받는 적중 횟수
}

GameConfig.Tutorial = {
	Enabled = true,
	WindowScale = 1.6, -- 연습 판에서 처음 온 사람의 잡기 창 배율
	Lead = 1.8, -- 연습 판에서는 해적이 나오는 시간을 흔들지 않고 이 값으로 둔다
	BotFillDelay = 1, -- 연습 판은 AI 가 곧바로 앉는다
}

GameConfig.Tournament = {
	Enabled = true,
	SeriesLength = 4, -- 이만큼 연달아 치른 판의 점수를 더한다
	Placement = { 10, 6, 4, 2, 1, 1 }, -- 1등(생존) · 2등 · 3등 …
	CatchPoint = 1, -- 이번 판에 잡은 해적 1번마다
	CatchPointCap = 3,
	CoinsPerPoint = 15, -- 시리즈를 마치면 점수 × 이 값
	SeriesTimeout = 900, -- 이만큼(초) 토너먼트 판을 안 하면 시리즈가 끊긴다
	StoreName = "CursedBarrel_Tournament_v1", -- 시즌 id 가 뒤에 붙는다
	BoardRows = 10,
}

GameConfig.Referral = {
	Enabled = true,
	InviterCoins = 600,
	NewcomerCoins = 450,
	DailyCap = 5, -- 초대한 사람이 하루에 받을 수 있는 횟수
}

GameConfig.Lucky = {
	Enabled = true,
	SurgeScale = 2,
}

GameConfig.TableTypeByName.Table_F = "Tournament4" -- Phase 21 : J → F (4인 줄로 옮김)

--------------------------------------------------
-- Phase 13 : 코인 · 로벅스 둘 다로 스킨 사기, 출석판, 룰렛, 첫 구매 보너스, 오늘의 특가
--------------------------------------------------

-- 코인으로 살 수 있는 스킨인가 (VIP · 스타터 · 시즌 · 로벅스 전용 · 기본 지급은 아니다)
function GameConfig.isCoinSkin(skin)
	return skin ~= nil and (tonumber(skin.price) or 0) > 0 and not skin.vip and not skin.pack and not skin.season and not skin.reward
end

-- 코인이 shortfall 만큼 모자랄 때 권할 묶음 : 그만큼 채우는 가장 작은 묶음 (다 모자라면 가장 큰 묶음)
-- ready 가 true 면 상품 ID 가 있는 묶음만 본다
function GameConfig.coinPackFor(shortfall, readyOnly)
	local best, biggest = nil, nil
	for _, pack in ipairs(GameConfig.Products.Coins) do
		if not readyOnly or (tonumber(pack.productId) or 0) > 0 then
			if pack.coins >= shortfall and (not best or pack.coins < best.coins) then
				best = pack
			end
			if not biggest or pack.coins > biggest.coins then
				biggest = pack
			end
		end
	end
	return best or biggest
end

-- 첫 코인 충전은 2배. 처음 돈을 쓰는 문턱을 낮추는 가장 흔한 방법이다.
GameConfig.FirstPurchase = {
	Enabled = true,
	CoinMultiplier = 2,
}

-- 오늘의 특가 : 날마다 코인 스킨 하나가 싸진다. (코인 가격만 깎는다)
GameConfig.DailyDeal = {
	Enabled = true,
	Discount = 0.3,
	Kinds = { "Knife", "Barrel", "Ghost", "Stab", "Victory", "Elimination", "Chair" },
}

-- 날짜 문자열("2026-09-24") → { kind, id, price(할인가), original }
function GameConfig.dailyDealFor(day)
	if not GameConfig.DailyDeal.Enabled then
		return nil
	end
	local pool = {}
	for _, kind in ipairs(GameConfig.DailyDeal.Kinds) do
		for _, skin in ipairs(GameConfig.Skins[kind] or {}) do
			if GameConfig.isCoinSkin(skin) and skin.rarity ~= "common" then
				table.insert(pool, { kind = kind, skin = skin })
			end
		end
	end
	if #pool == 0 then
		return nil
	end
	local hash = 7
	for index = 1, #tostring(day) do
		hash = (hash * 31 + tostring(day):byte(index)) % 1000003
	end
	local pick = pool[hash % #pool + 1]
	local original = tonumber(pick.skin.price) or 0
	return {
		kind = pick.kind,
		id = pick.skin.id,
		original = original,
		price = math.max(1, math.floor(original * (1 - GameConfig.DailyDeal.Discount) / 100 + 0.5) * 100),
	}
end

-- 출석판 : 들어온 날마다 한 칸씩 받는다. (하루 빠져도 처음으로 돌아가지 않는다. 7칸을 다 받으면 새 판)
-- VIP 는 코인이 2배.
GameConfig.Attendance = {
	Enabled = true,
	AutoOpen = true, -- 받을 것이 있으면 들어오자마자 출석판을 띄운다
	VipMultiplier = 2,
	Days = {
		{ coins = 450, icon = "coins" },
		{ coins = 600, icon = "coins" },
		{ coins = 750, icon = "coins" },
		{ coins = 900, icon = "coins" },
		{ coins = 1050, icon = "coins" },
		{ coins = 1350, icon = "gem" },
		{ coins = 3000, icon = "chest" },
	},
}

-- 룰렛 : 하루에 한 번 무료로 돌린다. (이용권 · 로벅스 판매 없음)
--   대부분 적은 코인이 나오고, 평범한 스킨은 20%, 희귀 스킨은 3%.
--   "스킨" 칸은 아직 없는 코인 스킨 중 minPrice ~ maxPrice 가격의 것 하나. 다 가졌으면 fallbackCoins.
--   확률표는 따로 보여 주지 않는다 (Phase 15). 하루 한 번 무료라 규정상 공개할 의무가 없다. 로벅스로 돌리게 바꾸면 반드시 다시 보여 줄 것.
GameConfig.Roulette = {
	Enabled = true,
	-- weight 합이 1000 이면 weight / 10 이 곧 % 다
	Segments = {
		{ id = "c60", kind = "coins", amount = 60, weight = 300, label = "60", color = Color3.fromRGB(120, 86, 52) },
		{ id = "c150", kind = "coins", amount = 150, weight = 250, label = "150", color = Color3.fromRGB(150, 104, 58) },
		{ id = "skin_plain", kind = "skin", minPrice = 1, maxPrice = 12000, fallbackCoins = 450, weight = 200, label = "스킨", color = Color3.fromRGB(46, 110, 150) },
		{ id = "c300", kind = "coins", amount = 300, weight = 140, label = "300", color = Color3.fromRGB(120, 86, 52) },
		{ id = "c900", kind = "coins", amount = 900, weight = 60, label = "900", color = Color3.fromRGB(150, 104, 58) },
		{ id = "skin_rare", kind = "skin", minPrice = 12001, maxPrice = 69000, fallbackCoins = 1500, weight = 30, label = "희귀", color = Color3.fromRGB(120, 60, 150) },
		{ id = "c3000", kind = "coins", amount = 3000, weight = 15, label = "3000", color = Color3.fromRGB(180, 132, 40) },
		{ id = "jackpot", kind = "coins", amount = 6000, weight = 5, label = "6000", color = Color3.fromRGB(200, 60, 50) },
	},
}

-- Phase 16 : 그룹 가입 보상 (스폰 옆 받침대 · 계정당 한 번). 이름은 예전 그대로 LikeReward.
--   Phase 16.1 : 서버가 그룹 가입을 직접 확인한 사람에게만 준다 (ReleaseConfig.GroupId 필요).
--   좋아요는 Roblox 가 게임에 알려 주지 않아서 확인할 수 없다 → 받침대에는 "좋아요도 부탁해요" 로만 적는다.
GameConfig.LikeReward = {
	Enabled = true,
	Kind = "Barrel",
	Skin = "blue_drum",
	AutoEquip = true, -- 받자마자 장착해서 다음 판부터 바로 보인다
}

-- 신화 스킨은 무지갯빛 반짝임이 하나 더 붙는다 (SkinFX 의 fx.mythic)
for _, kind in ipairs({ "Knife", "Barrel", "Ghost", "Chair", "Elimination", "Victory", "Stab" }) do
	for _, skin in ipairs(GameConfig.Skins[kind] or {}) do
		if skin.rarity == "mythic" then
			skin.fx = skin.fx or {}
			skin.fx.mythic = true
		end
	end
end

-- 전설 · 신화 스킨을 사면 서버 전체에 알린다 (남이 사는 걸 보면 사고 싶어진다)
GameConfig.Announce = {
	Rarities = { legend = true, mythic = true },
	RouletteRare = true, -- 룰렛에서 희귀 스킨이 나와도 알린다
}

function GameConfig.rouletteTotalWeight()
	local total = 0
	for _, segment in ipairs(GameConfig.Roulette.Segments) do
		total += segment.weight
	end
	return total
end

--------------------------------------------------
-- Phase 17 : 로벅스 상품 · 게임패스 ID 는 ReleaseConfig 한 곳에 적는다
--   ReleaseConfig.ProductIds / GamePassIds 에 숫자가 있으면 여기 값(productId · gamePassId)을 덮어쓴다.
--   (예전처럼 이 파일에 바로 적어도 된다. 둘 다 있으면 ReleaseConfig 가 이긴다)
--------------------------------------------------
do
	local ok, Release = pcall(require, script.Parent:WaitForChild("ReleaseConfig"))
	if ok and type(Release) == "table" then
		local products = Release.ProductIds or {}
		local function apply(entry)
			local id = tonumber(products[entry.id]) or 0
			if id > 0 then
				entry.productId = id
			end
		end
		for _, pack in ipairs(GameConfig.Products.Coins) do
			apply(pack)
		end
		apply(GameConfig.Products.Starter)
		for _, item in ipairs(GameConfig.Sabotage.Items) do
			apply(item)
		end
		for key, pass in pairs(GameConfig.Products.GamePasses) do
			local id = tonumber((Release.GamePassIds or {})[key]) or 0
			if id > 0 then
				pass.gamePassId = id
			end
		end
	end
end

return GameConfig
