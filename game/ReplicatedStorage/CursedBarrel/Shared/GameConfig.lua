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
	LeaderstatsName = "승리",
	StreakStatName = "연승",

	-- Phase 7 : 이제 기본으로 켠다. ProfileService 가 모든 참가자의 판수를 저장한다.
	-- (Studio 에서는 "Studio의 API 서비스 접근 허용"이 필요하다. 꺼져 있어도 게임은 그대로 돌아간다.)
	UseDataStore = true,
	DataStoreName = "CursedBarrel_Profile_v2",
	OrderedStoreName = "CursedBarrel_Wins_v2", -- 전 서버 랭킹
	GlobalRows = 10,
	GlobalRefresh = 90, -- 전 서버 랭킹을 다시 읽는 간격(초)
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

	-- 칼이 꽂힌 순간부터 잡기 창이 열릴 때까지.
	-- 클라이언트의 클로즈업 연출 길이와 같아야 손이 화면과 맞는다.
	Lead = 1.30,

	BaseWindow = 0.80, -- 첫 번째 잡기의 창 길이(초)
	StepPerCatch = 0.09, -- 이번 라운드에서 한 번 잡을 때마다 이만큼 좁아진다
	MinWindow = 0.34, -- ★ 이 아래로는 내리지 않는다. 모바일 터치 왕복이 이 정도다.
	DuelScale = 0.85, -- 최후의 2인이면 곱한다
	LowSlotScale = 0.90, -- 남은 자리가 3칸 이하면 곱한다

	Grace = 0.40, -- 창이 닫힌 뒤에도 이만큼 늦은 입력은 받아준다 (네트워크 지연 배려)
	MaxLatency = 0.25, -- 지연 보정 상한. 이보다 큰 차이는 조작으로 본다.
	Timeout = 2.2, -- 창이 열리고 이 시간이 지나면 서버가 실패로 확정한다
	Hold = 1.6, -- 결과를 보여주고 다음 턴으로 넘어가기까지

	-- Phase 5 에서는 "잡으면 통을 다시 채우지 않는다" 였다.
	-- 그런데 위험 자리는 하나뿐이라, 그 자리를 잡고 나면 통이 완전히 안전해져
	-- 칼을 다 뽑을 때까지 해적이 두 번 다시 나오지 않았다. (Phase 6 에서 고침)
	RefillOnCatch = false,

	-- ★ Phase 6 수정: 잡는 데 성공하면 아직 아무도 꽂지 않은 자리 중에서
	--   새 해적을 이만큼 더 숨긴다. 통을 새로 채우지 않아도 긴장이 이어진다.
	ArmOnCatch = 1,
	MinFreeSlotsToArm = 1, -- 남은 빈 자리가 이보다 적으면 숨길 곳이 없다
}

-- 이번 잡기의 창 길이. 서버에서만 호출한다.
function GameConfig.catchWindow(catchCount, aliveCount, slotsLeft)
	local catch = GameConfig.Catch
	local window = catch.BaseWindow - catch.StepPerCatch * math.max(0, catchCount)
	if aliveCount and aliveCount <= 2 then
		window *= catch.DuelScale
	end
	if slotsLeft and slotsLeft <= 3 then
		window *= catch.LowSlotScale
	end
	return math.max(catch.MinWindow, window)
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
	},

	Knife = {
		{
			id = "classic", name = "낡은 단검", rarity = "common", price = 0,
			blade = Color3.fromRGB(206, 210, 214), bladeMaterial = Enum.Material.Metal,
			handle = Color3.fromRGB(64, 42, 28), handleMaterial = Enum.Material.Wood,
			guard = Color3.fromRGB(126, 104, 62), trail = Color3.fromRGB(226, 216, 190),
		},
		{
			id = "bone", name = "뼈칼", rarity = "common", price = 250,
			blade = Color3.fromRGB(238, 232, 212), bladeMaterial = Enum.Material.Sand,
			handle = Color3.fromRGB(206, 196, 170), handleMaterial = Enum.Material.Sand,
			guard = Color3.fromRGB(96, 86, 68), trail = Color3.fromRGB(240, 236, 216),
			fx = { emit = Color3.fromRGB(226, 220, 200), trail = Color3.fromRGB(240, 236, 216) },
		},
		{
			id = "gold", name = "선장의 금검", rarity = "rare", price = 900,
			blade = Color3.fromRGB(246, 206, 106), bladeMaterial = Enum.Material.Metal,
			handle = Color3.fromRGB(120, 78, 32), handleMaterial = Enum.Material.Wood,
			guard = Color3.fromRGB(255, 226, 140), trail = Color3.fromRGB(255, 226, 140), glow = 0.45,
			fx = { emit = Color3.fromRGB(255, 226, 140), spark = true, trail = Color3.fromRGB(255, 226, 140), halo = Color3.fromRGB(255, 206, 110), pulse = 1.4 },
		},
		{
			id = "cursed", name = "저주받은 칼날", rarity = "epic", price = 2200,
			blade = Color3.fromRGB(120, 255, 214), bladeMaterial = Enum.Material.Neon,
			handle = Color3.fromRGB(26, 34, 40), handleMaterial = Enum.Material.Slate,
			guard = Color3.fromRGB(84, 214, 186), trail = Color3.fromRGB(120, 255, 214), glow = 1,
			fx = { emit = Color3.fromRGB(120, 255, 214), spark = true, trail = Color3.fromRGB(120, 255, 214), halo = Color3.fromRGB(84, 214, 186), pulse = 2.1 },
		},
		{
			id = "ember", name = "잿불 단검", rarity = "legend", price = 0, robux = 99,
			blade = Color3.fromRGB(255, 132, 62), bladeMaterial = Enum.Material.Neon,
			handle = Color3.fromRGB(46, 26, 20), handleMaterial = Enum.Material.Slate,
			guard = Color3.fromRGB(255, 96, 48), trail = Color3.fromRGB(255, 150, 70), glow = 1,
			fx = { emit = Color3.fromRGB(255, 132, 62), spark = true, trail = Color3.fromRGB(255, 150, 70), halo = Color3.fromRGB(255, 96, 48), pulse = 3.2, smoke = true },
		},
		{
			id = "deep", name = "심해의 작살", rarity = "legend", price = 6000,
			blade = Color3.fromRGB(126, 196, 255), bladeMaterial = Enum.Material.Ice,
			handle = Color3.fromRGB(28, 58, 74), handleMaterial = Enum.Material.Slate,
			guard = Color3.fromRGB(96, 168, 226), trail = Color3.fromRGB(150, 214, 255), glow = 0.6,
			fx = { emit = Color3.fromRGB(150, 214, 255), spark = true, trail = Color3.fromRGB(150, 214, 255), halo = Color3.fromRGB(96, 168, 226), pulse = 1.1, bubbles = true },
		},
	},

	Barrel = {
		{
			id = "oak", name = "참나무 통", rarity = "common", price = 0,
			body = Color3.fromRGB(122, 78, 44), bodyMaterial = Enum.Material.Wood,
			hoop = Color3.fromRGB(58, 48, 42), hoopMaterial = Enum.Material.Metal,
			lid = Color3.fromRGB(96, 62, 36), glow = Color3.fromRGB(255, 196, 120),
		},
		{
			id = "drum", name = "기름 드럼통", rarity = "common", price = 350,
			body = Color3.fromRGB(196, 62, 44), bodyMaterial = Enum.Material.CorrodedMetal,
			hoop = Color3.fromRGB(226, 208, 96), hoopMaterial = Enum.Material.Metal,
			lid = Color3.fromRGB(150, 46, 34), glow = Color3.fromRGB(255, 150, 90),
			ribbed = true, -- 드럼통 특유의 가로 주름
			fx = { emit = Color3.fromRGB(255, 150, 90), smoke = true },
		},
		{
			id = "steel", name = "폐유 드럼통", rarity = "common", price = 350,
			body = Color3.fromRGB(96, 104, 110), bodyMaterial = Enum.Material.DiamondPlate,
			hoop = Color3.fromRGB(58, 64, 70), hoopMaterial = Enum.Material.Metal,
			lid = Color3.fromRGB(78, 86, 92), glow = Color3.fromRGB(180, 220, 255),
			ribbed = true,
			fx = { emit = Color3.fromRGB(180, 220, 255) },
		},
		{
			id = "treasure", name = "보물 상자", rarity = "rare", price = 1200,
			body = Color3.fromRGB(104, 68, 38), bodyMaterial = Enum.Material.Wood,
			hoop = Color3.fromRGB(240, 202, 104), hoopMaterial = Enum.Material.Metal,
			lid = Color3.fromRGB(240, 202, 104), glow = Color3.fromRGB(255, 220, 140),
			fx = { emit = Color3.fromRGB(255, 220, 140), spark = true, halo = Color3.fromRGB(255, 206, 110), pulse = 1.2, coins = true },
		},
		{
			id = "kimchi", name = "김치통", rarity = "rare", price = 1200,
			body = Color3.fromRGB(236, 66, 52), bodyMaterial = Enum.Material.Plastic,
			hoop = Color3.fromRGB(246, 246, 246), hoopMaterial = Enum.Material.Plastic,
			lid = Color3.fromRGB(246, 246, 246), glow = Color3.fromRGB(255, 150, 130),
			fx = { emit = Color3.fromRGB(255, 120, 100), pulse = 0.9 },
		},
		{
			id = "abyss", name = "심연의 통", rarity = "legend", price = 7000,
			body = Color3.fromRGB(28, 34, 46), bodyMaterial = Enum.Material.Slate,
			hoop = Color3.fromRGB(120, 255, 214), hoopMaterial = Enum.Material.Neon,
			lid = Color3.fromRGB(38, 46, 60), glow = Color3.fromRGB(120, 255, 214),
			fx = { emit = Color3.fromRGB(120, 255, 214), spark = true, halo = Color3.fromRGB(84, 214, 186), pulse = 2.4, bubbles = true },
		},
		-- Phase 8 : 새 통 테마
		{
			id = "volcano", name = "화산의 통", rarity = "epic", price = 3400,
			body = Color3.fromRGB(58, 34, 30), bodyMaterial = Enum.Material.Basalt,
			hoop = Color3.fromRGB(255, 118, 46), hoopMaterial = Enum.Material.Neon,
			lid = Color3.fromRGB(44, 26, 24), glow = Color3.fromRGB(255, 132, 46),
			fx = { emit = Color3.fromRGB(255, 132, 46), spark = true, halo = Color3.fromRGB(255, 90, 40), pulse = 3, smoke = true },
		},
		{
			id = "frost", name = "유빙의 통", rarity = "epic", price = 3400,
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
			id = "skull", name = "해골 선장", rarity = "common", price = 400,
			coat = Color3.fromRGB(46, 46, 52), skin = Color3.fromRGB(242, 240, 228),
			hat = Color3.fromRGB(22, 22, 26), accent = Color3.fromRGB(226, 226, 226),
			aura = Color3.fromRGB(226, 230, 236),
			fx = { emit = Color3.fromRGB(226, 230, 236), smoke = true },
		},
		{
			id = "kraken", name = "크라켄", rarity = "rare", price = 1500,
			coat = Color3.fromRGB(94, 58, 140), skin = Color3.fromRGB(176, 130, 226),
			hat = Color3.fromRGB(52, 30, 82), accent = Color3.fromRGB(226, 150, 255),
			aura = Color3.fromRGB(196, 130, 255),
			fx = { emit = Color3.fromRGB(196, 130, 255), spark = true, halo = Color3.fromRGB(150, 90, 226), pulse = 1.6, bubbles = true },
		},
		{
			id = "cook", name = "좀비 요리사", rarity = "rare", price = 1500,
			coat = Color3.fromRGB(226, 226, 220), skin = Color3.fromRGB(150, 196, 120),
			hat = Color3.fromRGB(240, 240, 236), accent = Color3.fromRGB(196, 72, 60),
			aura = Color3.fromRGB(170, 226, 130),
			fx = { emit = Color3.fromRGB(170, 226, 130), smoke = true, pulse = 1 },
		},
		{
			id = "ember", name = "잿불 망령", rarity = "legend", price = 0, robux = 129,
			coat = Color3.fromRGB(96, 34, 20), skin = Color3.fromRGB(255, 160, 90),
			hat = Color3.fromRGB(42, 20, 14), accent = Color3.fromRGB(255, 120, 50),
			aura = Color3.fromRGB(255, 140, 60),
			fx = { emit = Color3.fromRGB(255, 140, 60), spark = true, halo = Color3.fromRGB(255, 90, 40), pulse = 3.4, smoke = true },
		},
		{
			id = "siren", name = "심해의 인어", rarity = "legend", price = 6500,
			coat = Color3.fromRGB(28, 88, 126), skin = Color3.fromRGB(150, 226, 255),
			hat = Color3.fromRGB(20, 60, 90), accent = Color3.fromRGB(120, 255, 255),
			aura = Color3.fromRGB(120, 226, 255),
			fx = { emit = Color3.fromRGB(120, 226, 255), spark = true, halo = Color3.fromRGB(80, 180, 226), pulse = 1.3, bubbles = true },
		},
		-- Phase 8 : 새 괴물
		{
			id = "voidking", name = "공허의 왕", rarity = "epic", price = 3800,
			coat = Color3.fromRGB(26, 22, 40), skin = Color3.fromRGB(150, 130, 226),
			hat = Color3.fromRGB(16, 14, 26), accent = Color3.fromRGB(196, 150, 255),
			aura = Color3.fromRGB(150, 110, 255),
			fx = { emit = Color3.fromRGB(150, 110, 255), spark = true, halo = Color3.fromRGB(110, 70, 220), pulse = 2.6 },
		},
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

-- 기본으로 처음부터 가지고 있는 스킨 (가격 0 이고 로벅스 전용이 아닌 것)
function GameConfig.isFreeSkin(skin)
	return skin ~= nil and (tonumber(skin.price) or 0) <= 0 and not skin.robux
end

--------------------------------------------------
-- 코인과 레벨 (Phase 7)
--------------------------------------------------
GameConfig.Economy = {
	WinReward = 120, -- 우승
	ParticipationReward = 25, -- 한 판 끝까지 앉아 있기
	SurviveTurnReward = 6, -- 안전한 자리를 뽑을 때마다
	CatchReward = 18, -- 해적을 잡을 때마다
	StreakBonus = 35, -- 연승 1회당 더해지는 우승 보상 (5연승이면 +175)
	StreakBonusCap = 6, -- 보너스가 커지는 상한 연승 수
	DuoScale = 0.7, -- 2인 테이블은 금방 끝나므로 보상을 줄인다
	PartyScale = 1.25, -- 6인 테이블은 오래 버텨야 하므로 더 준다
	LeaveEarlyReward = 0, -- 중도 이탈은 주지 않는다
	DailyBonus = 150, -- 하루에 한 번 접속 보상
}

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

	Items = {
		{
			id = "ink", name = "먹물 한 통", robux = 15, productId = 0,
			icon = "🖤", color = Color3.fromRGB(58, 52, 74),
			duration = 6,
			blurb = "상대 화면을 먹물로 덮습니다",
			detail = "다음 6초 동안 상대 화면 가장자리가 먹물로 얼룩집니다. 자리 번호는 계속 읽을 수 있습니다.",
		},
		{
			id = "shake", name = "흔들리는 손", robux = 25, productId = 0,
			icon = "🌀", color = Color3.fromRGB(120, 180, 226),
			duration = 7,
			blurb = "상대의 자리 버튼이 흔들립니다",
			detail = "상대의 칼 선택 버튼이 7초 동안 좌우로 흔들립니다. 누를 수는 있지만 조준이 어려워집니다.",
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
			detail = "상대 화면에서만 버튼 위 숫자가 뒤섞입니다. 누른 자리는 화면에 보이는 그 자리가 맞습니다. (엉뚱한 곳에 꽂히지는 않습니다)",
		},
		{
			id = "roar", name = "해적의 포효", robux = 55, productId = 0,
			icon = "💀", color = Color3.fromRGB(255, 96, 78),
			duration = 3,
			blurb = "상대 앞에 가짜 해적이 튀어나옵니다",
			detail = "상대 화면에만 가짜 해적이 한 번 튀어나옵니다. 잡기 창은 열리지 않고 판정에도 영향이 없습니다.",
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
-- 로벅스 상품 (Phase 7)
-- 코인 묶음과 스킨 직접 구매. 역시 ID 를 채워 넣어야 실제로 팔린다.
--------------------------------------------------
GameConfig.Products = {
	Coins = {
		{ id = "coins_small", name = "코인 1,000", coins = 1000, robux = 25, productId = 0 },
		{ id = "coins_medium", name = "코인 5,500", coins = 5500, robux = 99, productId = 0 },
		{ id = "coins_large", name = "코인 12,000", coins = 12000, robux = 199, productId = 0 },
	},
	-- 스킨을 로벅스로 바로 사고 싶을 때. skin 에는 "Knife/ember" 처럼 적는다.
	Skins = {
		{ id = "skin_ember_knife", skin = "Knife/ember", robux = 99, productId = 0 },
		{ id = "skin_ember_ghost", skin = "Ghost/ember", robux = 129, productId = 0 },
	},
}

--------------------------------------------------
-- 일일 퀘스트 · 업적 (Phase 8)
--------------------------------------------------
GameConfig.Quests = {
	Enabled = true,
	DailyCount = 3, -- 하루에 주어지는 개수
	Pool = {
		{ id = "play3", text = "3판 참가하기", metric = "games", goal = 3, reward = 120 },
		{ id = "win1", text = "1판 우승하기", metric = "wins", goal = 1, reward = 200 },
		{ id = "catch5", text = "해적 5번 잡기", metric = "catches", goal = 5, reward = 180 },
		{ id = "safe12", text = "안전한 자리 12번 뽑기", metric = "safePicks", goal = 12, reward = 150 },
		{ id = "duo2", text = "2인 테이블에서 2판 하기", metric = "duoGames", goal = 2, reward = 130 },
		{ id = "party1", text = "6인 테이블에서 1판 하기", metric = "partyGames", goal = 1, reward = 160 },
		{ id = "streak2", text = "2연승 만들기", metric = "bestStreakToday", goal = 2, reward = 220 },
	},
}

GameConfig.Achievements = {
	{ id = "first_win", text = "첫 승리", metric = "wins", goal = 1, reward = 200 },
	{ id = "win10", text = "10승", metric = "wins", goal = 10, reward = 600 },
	{ id = "win50", text = "50승", metric = "wins", goal = 50, reward = 2500 },
	{ id = "catch50", text = "해적 50번 잡기", metric = "catches", goal = 50, reward = 900 },
	{ id = "catch250", text = "해적 250번 잡기", metric = "catches", goal = 250, reward = 3000 },
	{ id = "streak3", text = "3연승", metric = "bestStreak", goal = 3, reward = 700 },
	{ id = "streak7", text = "7연승", metric = "bestStreak", goal = 7, reward = 2800 },
	{ id = "games100", text = "100판 참가", metric = "games", goal = 100, reward = 1200 },
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
-- 테이블 종류 배정 (Phase 8)
--
-- 맵 파일 안의 테이블은 전부 Standard4 / Duo2 로 저장돼 있다.
-- 6인 테이블과 빠른 모드를 넣으려고 .rbxl 을 손으로 고치는 대신,
-- 모델 이름으로 종류를 덮어쓴다. 여기 한 줄만 고치면 테이블 성격이 바뀐다.
--
-- ★ 6인 테이블(Party6)은 해적이 두 마리다. 좌석은 TableBuilder 가 만들어 붙인다.
--------------------------------------------------
GameConfig.TableTypeByName = {
	Table_D = "Blitz4", -- 빠른 모드 (턴 4초 · 칼 10자루)
	Table_G = "Party6", -- 6인 테이블 · 해적 2마리
	Table_H = "Party6", -- 6인 테이블 · 해적 2마리
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

return GameConfig
