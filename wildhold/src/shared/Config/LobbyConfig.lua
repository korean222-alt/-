-- 로비 (99 Nights 처럼): 공개 서버 = 로비, 예약 서버 = 원정. 같은 Place 하나로 동작한다.
--  원정 수레(방)에 올라타면 방이 생기고, 방장이 인원(1~6)을 정한다. 다 차거나 기다림이 끝나면 출발.
--  "혼자 바로 출발" 은 기다림 없이 곧장 (들어와서 1분 안에 놀기).
-- Studio 에서는 텔레포트가 안 되므로 같은 서버 안에서 로비(StudioOrigin) ↔ 원정 맵을 오간다.
return {
	Wagons = 4, -- 원정 수레 (방) 수
	PadRadius = 7, -- 수레 앞 이 거리 안에 서 있으면 그 방 대원
	DefaultSize = 4, -- 방 정원 (방장이 1~6 으로 바꿈)
	MaxSize = 6,
	RoomWait = 20, -- 첫 대원이 탄 뒤 이 시간이 지나면 모인 인원으로 출발
	FullWait = 4, -- 정원이 다 차면 이 시간 뒤 출발
	SoloDelay = 1.5, -- "혼자 바로 출발" 누르고 출발까지
	StudioOrigin = {0, 0, 2400}, -- Studio 에서 로비 위치 (원정 맵과 겹치지 않게 멀리)
	Radius = 78, -- 로비 캠프 크기
	ReturnSeconds = 20, -- 원정 결과 화면 뒤 로비로 돌아가기까지 (GameConfig.ResultSeconds 와 같게)
	WaitArrival = 10, -- 원정 서버: 방 인원이 다 들어올 때까지 기다리는 최대 시간
}
