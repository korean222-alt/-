--[[
	GameConfig
	게임 전역에서 공유하는 설정값과 이름 상수 모음.

	문자열을 직접 여기저기 적지 않고 전부 이 파일을 거치게 한다.
	나중에 이름을 바꿔야 할 때 한 곳만 고치면 되고, 오타로 인한 버그도 막아준다.

	Phase 2 에서 늘어난 것
	  - 카운트다운 / 라운드 / 턴 Attribute 이름
	  - 로비(밝음) · 게임 중(어두움) 라이팅 프리셋
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
}

--------------------------------------------------
-- 테이블 모델에 서버가 기록하는 Attribute 이름
-- 클라이언트는 이 Attribute 만 읽어서 UI 를 그린다. (RemoteEvent 가 필요 없다)
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
	ParticipantCount = "ParticipantCount", -- 확정된 참가자 수
	TurnCount = "TurnCount", -- 턴 순서에 남아 있는 인원
	TurnIndex = "TurnIndex", -- 현재 몇 번째 차례인지 (1 부터)
	CurrentTurnUserId = "CurrentTurnUserId", -- 현재 차례인 플레이어 UserId (0 = 없음)
	CurrentTurnName = "CurrentTurnName", -- 현재 차례인 플레이어 표시 이름
	TurnEndsAt = "TurnEndsAt", -- 이번 턴 제한시간 종료 시각 (0 = 제한 없음)
}

--------------------------------------------------
-- 좌석(Seat)에 기록하는 Attribute 이름
--------------------------------------------------
GameConfig.SeatAttributes = {
	SeatIndex = "SeatIndex", -- 1 부터 시작하는 좌석 번호
	OccupantUserId = "OccupantUserId", -- 앉아 있는 플레이어 UserId (비었으면 0)
	TurnOrder = "TurnOrder", -- Phase 2: 이번 라운드의 턴 순서 (0 = 참가자 아님)
}

--------------------------------------------------
-- 테이블 상태 머신
-- Phase 2 에서는 Waiting / Countdown / Playing 을 사용한다.
-- Starting / RoundEnding 은 Phase 3 의 연출용으로 비워둔다.
--------------------------------------------------
GameConfig.States = {
	Waiting = "Waiting", -- 사람을 기다리는 중
	Countdown = "Countdown", -- 최소 인원이 모여 카운트다운 중
	Starting = "Starting", -- 시작 연출 중
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
