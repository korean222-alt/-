-- 원정 맵 배치. 좌표는 stud, 기지 중심(Core) = (0, 0). 놀 수 있는 곳은 지름 약 1500 (99 Nights 급).
-- 방향 각도: 0 = 북(-Z), 120 = 남동, 240 = 남서 (dir = (sin a, 0, -cos a)).
-- 기지 주변은 초원, 그 바깥은 길목 방향마다 다른 지역: 북 = 잿빛 바위 협곡(불), 남동 = 고목의 숲(알파), 남서 = 안개 늪(물).
-- 멀리 갈수록 야생 펫 레벨과 귀한 재료(고철·수정)가 늘어난다. 밤 괴물은 초원 끝의 굴 3곳에서 기지로 온다.
return {
	GroundSize = 1720,
	PlayRadius = 750, -- 이 바깥은 숲 벽과 언덕 (경계)
	MeadowRadius = 250, -- 여기까지 초원
	BaseRadius = 40, -- 기지 말뚝 울타리 반지름
	GapWidth = 13, -- 울타리의 길목 구멍 폭
	LaneRadius = 210, -- 괴물 굴(스폰) 위치
	LaneWidth = 12,
	WaypointRadii = {210, 170, 134, 100, 78, 57, 40, 24, 8},
	LaneAngles = {0, 120, 240},
	TrailLength = 690, -- 굴 너머 각 지역으로 이어지는 흙길 (길 잃지 않게)
	Spawn = {0, 0.5, 15},
	Warehouse = {21, 0, -12},
	Workbench = {-21, 0, -12},
	Cage = {0, 0, 29},
	-- 방어 자리: {종류, 길목, 반지름, 옆으로 비킨 거리, 시작 레벨}
	-- 길목 0 은 Core 근처 (방향은 길목 1 기준)
	Slots = {
		{"Gate", 1, 40, 0, 1}, {"Gate", 2, 40, 0, 1}, {"Wall", 3, 40, 0, 1},
		{"Wall", 1, 57, 0, 0}, {"Wall", 2, 57, 0, 0}, {"Wall", 3, 57, 0, 0},
		{"Wall", 1, 78, 0, 0}, {"Wall", 2, 78, 0, 0}, {"Wall", 3, 78, 0, 0},
		{"ArrowTower", 1, 31, 11, 1}, {"ArrowTower", 2, 31, 11, 0}, {"ArrowTower", 3, 31, 11, 0}, {"ArrowTower", 3, 31, -11, 0},
		{"SpikeTrap", 1, 67, 0, 0}, {"SpikeTrap", 2, 67, 0, 0}, {"SpikeTrap", 3, 67, 0, 0}, {"SpikeTrap", 1, 90, 0, 0},
		{"PetStand", 1, 31, -11, 0}, {"PetStand", 2, 31, -11, 0}, {"PetStand", 3, 24, 0, 0}, {"PetStand", 1, 12, 10, 0},
	},
	-- 지역. Angle 이 있는 지역은 그 방향 ±60° 부채꼴, MeadowRadius 바깥.
	Zones = {
		Meadow = {Name = "초원", Icon = "🌿", Danger = 1},
		Crags = {Name = "잿빛 바위 협곡", Icon = "🌋", Danger = 2, Angle = 0},
		Ancient = {Name = "고목의 숲", Icon = "🌲", Danger = 3, Angle = 120},
		Swamp = {Name = "안개 늪", Icon = "💧", Danger = 2, Angle = 240},
	},
	ZoneOrder = {"Meadow", "Crags", "Ancient", "Swamp"},
	-- 지역별 채집 노드 개수 (위치는 맵을 만들 때 고정 시드로 흩뿌린다)
	Nodes = {
		Meadow = {Wood = 16, Stone = 10, Fiber = 16, Berry = 18, Mushroom = 6, Scrap = 4},
		Crags = {Stone = 26, Scrap = 14, Crystal = 9, Wood = 6, Fiber = 4, Berry = 5, Mushroom = 3},
		Ancient = {Wood = 32, Mushroom = 16, Berry = 10, Fiber = 8, Stone = 6, Crystal = 3, Scrap = 3},
		Swamp = {Fiber = 22, Mushroom = 16, Berry = 8, Wood = 10, Scrap = 8, Crystal = 3, Stone = 4},
	},
	-- 튜토리얼용: 기지 남쪽 문 앞 약한 야생 모슬링 (항상 같은 자리)
	StarterWild = {{"Mossling", 1, 6, 56}, {"Mossling", 1, -12, 60}, {"Mossling", 2, 26, 70}},
	-- 지역별 야생 펫: {종, 마리 수, 최저 레벨, 최고 레벨}. 멀수록 높은 레벨
	Wild = {
		Meadow = {{"Mossling", 6, 1, 3}, {"Emberpup", 2, 2, 3}, {"Shellbub", 2, 2, 3}},
		Crags = {{"Emberpup", 7, 3, 8}, {"Ashlizard", 5, 4, 9}},
		Ancient = {{"Mossling", 4, 4, 8}, {"Mossdeer", 6, 4, 9}},
		Swamp = {{"Shellbub", 7, 3, 8}, {"Bogtoad", 5, 4, 9}},
	},
	WildRespawn = 90, -- 잡힌 야생 펫 자리에 새로 나타나는 시간(초)
	-- 알파의 숲 (브라이어혼 α): 고목의 숲 깊은 곳
	Grove = {Angle = 120, Radius = 560, Size = 26, Level = 8},
	-- 기지 근처 연못 (초원의 셸버브)
	Pond = {-84, -50, 15},
	SwampPonds = 9,
}
