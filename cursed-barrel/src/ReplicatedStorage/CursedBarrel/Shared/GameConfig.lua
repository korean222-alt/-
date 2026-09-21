--[[
	GameConfig
	게임 전역에서 공유하는 설정값과 이름 상수 모음.

	문자열을 직접 여기저기 적지 않고 전부 이 파일을 거치게 한다.
	나중에 이름을 바꿔야 할 때 한 곳만 고치면 되고, 오타로 인한 버그도 막아준다.
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
	TableId = "TableId", -- 테이블 고유 ID (문자열)
	TableType = "TableType", -- TableConfig.Types 의 키
	SeatCount = "SeatCount", -- 총 좌석 수
	SeatedCount = "SeatedCount", -- 현재 앉아 있는 인원
	MinPlayers = "MinPlayers", -- 시작에 필요한 최소 인원
	State = "State", -- 현재 상태 머신 상태
}

--------------------------------------------------
-- 좌석(Seat)에 기록하는 Attribute 이름
--------------------------------------------------
GameConfig.SeatAttributes = {
	SeatIndex = "SeatIndex", -- 1 부터 시작하는 좌석 번호
	OccupantUserId = "OccupantUserId", -- 앉아 있는 플레이어 UserId (비었으면 0)
}

--------------------------------------------------
-- 테이블 상태 머신
-- Phase 1 에서는 Waiting 만 사용하고, 나머지는 다음 단계에서 채운다.
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
GameConfig.JoinableStates = {
	[GameConfig.States.Waiting] = true,
	[GameConfig.States.Countdown] = true,
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
-- 디버그 로그
--------------------------------------------------
function GameConfig.log(...)
	if GameConfig.DEBUG then
		print("[CursedBarrel]", ...)
	end
end

return GameConfig
