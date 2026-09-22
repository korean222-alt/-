--[[
	GameConfig
	게임 전역에서 공유하는 설정값과 이름 상수 모음.

	문자열을 직접 여기저기 적지 않고 전부 이 파일을 거치게 한다.
	나중에 이름을 바꿔야 할 때 한 곳만 고치면 되고, 오타로 인한 버그도 막아준다.

	Phase 2 에서 늘어난 것
	  - 카운트다운 / 라운드 / 턴 Attribute 이름
	  - 로비(밝음) · 게임 중(어두움) 라이팅 프리셋

	Phase 3 에서 늘어난 것
	  - 칼 슬롯 Attribute / 태그 / 배치 규칙
	  - 슬롯 선택 RemoteEvent 이름
	  - 탈락 · 승리 · 초기화 타이밍
	  - 랭킹판 설정
]]

local GameConfig = {}

-- 개발 중에는 true. 출시 전에 false 로 바꾸면 로그가 조용해진다.
GameConfig.DEBUG = true

--------------------------------------------------
-- CollectionService 태그
-- Workspace 에 테이블 모델을 복제하고 이 태그만 붙이면 자동으로 게임에 등록된다.
--------------------------------------------------
GameConfig.Tags = {
	Table = "CursedBarrel_Table",
	Seat = "CursedBarrel_Seat",
	Slot = "CursedBarrel_Slot", -- Phase 3 : 칼 슬롯 하나하나
	RankingBoard = "CursedBarrel_RankingBoard", -- Phase 3 : 랭킹판
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
	RoundId = "RoundId", -- 이 테이블에서 몇 번째 라운드인지
	ParticipantCount = "ParticipantCount", -- 이번 라운드를 시작한 인원 (중간에 줄지 않는다)
	TurnCount = "TurnCount", -- 아직 살아 있는 인원 (= 턴 순서에 남아 있는 인원)
	TurnIndex = "TurnIndex", -- 현재 몇 번째 차례인지 (1 부터)
	CurrentTurnUserId = "CurrentTurnUserId", -- 현재 차례인 플레이어 UserId (0 = 없음)
	CurrentTurnName = "CurrentTurnName", -- 현재 차례인 플레이어 표시 이름
	TurnEndsAt = "TurnEndsAt", -- 이번 턴 제한시간 종료 시각 (0 = 제한 없음)

	-- Phase 3 : 칼 슬롯 / 승패
	KnifeSlotCount = "KnifeSlotCount", -- 이 통에 있는 칼 슬롯 총 개수
	SlotsRemaining = "SlotsRemaining", -- 아직 아무도 고르지 않은 슬롯 수
	BarrelCycle = "BarrelCycle", -- 이번 라운드에서 통을 몇 번째로 채웠는지 (1 부터)
	LastPickSlot = "LastPickSlot", -- 마지막으로 선택된 슬롯 번호 (0 = 없음)
	LastPickUserId = "LastPickUserId", -- 그 슬롯을 고른 플레이어
	LastPickName = "LastPickName", -- 그 플레이어 표시 이름
	LastPickSafe = "LastPickSafe", -- true = 안전, false = 위험(탈락)
	WinnerUserId = "WinnerUserId", -- 우승자 UserId (0 = 아직 없음)
	WinnerName = "WinnerName", -- 우승자 표시 이름
	ResetEndsAt = "ResetEndsAt", -- 초기화까지 남은 시간의 종료 시각
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
	SlotIndex = "SlotIndex", -- 1 부터 시작하는 슬롯 번호
	Used = "Used", -- 이미 칼이 꽂혔는가
	UsedByUserId = "UsedByUserId", -- 그 칼을 꽂은 플레이어 (0 = 없음)
}

--------------------------------------------------
-- 테이블 상태 머신
--------------------------------------------------
GameConfig.States = {
	Waiting = "Waiting", -- 사람을 기다리는 중
	Countdown = "Countdown", -- 최소 인원이 모여 카운트다운 중
	Starting = "Starting", -- 시작 연출 중 (통에 칼을 채우는 시간)
	Playing = "Playing", -- 라운드 진행 중
	RoundEnding = "RoundEnding", -- 승자 연출 중
	Resetting = "Resetting", -- 테이블 초기화 중
}

-- 게임에 새로 참가할 수 있는 상태들
-- Playing 이 여기에 없기 때문에 게임이 시작되면 빈 의자에도 앉을 수 없다.
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
-- 좌석 ProximityPrompt 설정
-- PC(E 키)와 모바일(탭) 모두 기본 지원되기 때문에 ClickDetector 대신 사용한다.
--------------------------------------------------
GameConfig.SeatPrompt = {
	ActionText = "앉기",
	HoldDuration = 0,
	MaxActivationDistance = 12,
	RequiresLineOfSight = false,
}

-- 같은 플레이어가 Prompt 를 연타해도 이 간격 안에서는 한 번만 처리한다.
GameConfig.PromptCooldown = 0.35

--------------------------------------------------
-- 칼 슬롯 ProximityPrompt 설정 (Phase 3)
-- 역시 PC(E) · 모바일(탭)이 그대로 동작한다.
-- 화면 아래 버튼 UI(KnifeController)는 같은 요청을 RemoteEvent 로 보낸다.
--------------------------------------------------
GameConfig.SlotPrompt = {
	ActionText = "칼 꽂기",
	HoldDuration = 0,
	MaxActivationDistance = 14,
	RequiresLineOfSight = false,
}

-- 슬롯 선택 요청(프롬프트 + RemoteEvent 공통) 최소 간격
GameConfig.SelectCooldown = 0.25

--------------------------------------------------
-- RemoteEvent 이름 (ReplicatedStorage > CursedBarrel > Remotes)
--
-- 클라이언트 → 서버 : (테이블 모델, 슬롯 번호) "이 자리에 꽂겠다"
-- 서버 → 클라이언트 : (성공 여부, 내용) 짧은 안내 문구
-- 판정은 전부 서버에서 하고, 클라이언트가 보내는 값은 전부 다시 검사한다.
--------------------------------------------------
GameConfig.Remotes = {
	Folder = "Remotes",
	SelectSlot = "SelectSlot",
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
}

--------------------------------------------------
-- 칼 슬롯 배치 규칙 (Phase 3)
--
-- 서버(SlotBuilder)가 이 값으로 통 둘레에 슬롯을 만든다.
-- 통 크기가 달라도 통 파트의 실제 크기를 기준으로 계산하므로 그대로 들어맞는다.
--------------------------------------------------
GameConfig.SlotLayout = {
	BarrelName = "Barrel", -- 테이블 모델 안의 통 모델 이름
	BodyName = "Body", -- 통 몸통 파트 이름
	FolderName = "KnifeSlots", -- 슬롯들을 담는 폴더 이름
	MaxPerRing = 8, -- 한 줄에 최대 몇 개까지 두를지
	RingSpread = 0.155, -- 통 높이 대비 줄 간격 (위/아래로 이만큼씩)
	SurfaceGap = 0.06, -- 통 표면에서 살짝 띄우는 거리
	KnifeTilt = 14, -- 칼이 아래로 기운 각도(도)
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
	StartingDuration = 1.6, -- 카운트다운 종료 → 첫 턴까지의 연출 시간
	ResultHold = 1.1, -- 칼을 꽂은 뒤 결과를 보여주고 다음 턴으로 넘어가는 시간
	RoundEndDuration = 5, -- ★ 승자 발표 후 테이블이 초기화되기까지의 시간(초)
	ResetDuration = 0.6, -- 초기화 연출 시간
}

--------------------------------------------------
-- 랭킹판 (Phase 3)
--------------------------------------------------
GameConfig.Ranking = {
	Rows = 10, -- 랭킹판에 보여 줄 인원
	LeaderstatsName = "승리", -- Roblox 기본 순위표에 표시할 항목 이름

	-- 서버가 꺼져도 기록을 남기고 싶으면 true 로 바꾼다.
	-- (Studio 에서는 "Studio의 API 서비스 접근 허용"을 켜야 동작한다. 꺼져 있어도 게임은 그대로 돌아간다.)
	UseDataStore = false,
	DataStoreName = "CursedBarrel_Ranking_v1",
}

--------------------------------------------------
-- 서버와 클라이언트가 같은 시계를 본다.
-- 카운트다운 / 턴 남은 시간 계산은 전부 이 값을 기준으로 한다.
--------------------------------------------------
function GameConfig.now()
	return workspace:GetServerTimeNow()
end

--------------------------------------------------
-- 라이팅 프리셋 (Phase 2)
--
-- 로비는 스킨 전시장이라 밝아야 하고, 게임이 시작되면 어두워진다.
-- 조명 변경은 LightingController(클라이언트)가 "내 화면에서만" 수행하므로
-- 옆 테이블에서 게임이 시작돼도 로비에 있는 사람의 화면은 밝은 그대로다.
--------------------------------------------------
GameConfig.Lighting = {
	-- 접속하자마자 로비 프리셋을 한 번 적용할지 여부
	ApplyLobbyOnJoin = true,
	TweenTime = 1.4, -- 밝음 <-> 어두움 전환에 걸리는 시간(초)

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
