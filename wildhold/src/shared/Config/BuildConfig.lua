-- 설치형 건축 (ARK · 99 Nights 처럼): 재료 → 🔨 제작대를 만들어 놓고 → 제작대에서 벽·포탑 설치 도구를 만들어 기지 영역 안에 놓는다.
-- 설치 도구(Kit)는 핫바에 들어가고, 들면 반투명 미리보기가 보인다. 공격 버튼 = 설치, R(또는 ⟳ 버튼) = 돌리기.
-- 강화·수리는 놓은 구조물의 [E]/[R]. 벽·포탑 Lv2·3 은 제작대 Lv2·3 이 있어야 한다.
return {
	Radius = 112, -- Core 에서 이 거리 안에만 설치 (기지 영역)
	Reach = 26, -- 캐릭터에서 이 거리 안에만 놓을 수 있다
	Ahead = 6, -- 미리보기: 캐릭터 앞 이만큼 + 구조물 깊이의 절반
	RotateStep = 15, -- 돌리기 단위(도)
	-- 설치 도구 → 구조물
	Kits = {WorkbenchKit = "Workbench", WallKit = "Wall", GateKit = "Gate", TowerKit = "ArrowTower", SpikeKit = "SpikeTrap",
		StandKit = "PetStand", TorchKit = "TorchPost"},
	-- 바닥 크기 {가로, 세로} (겹침 검사)
	Footprint = {Workbench = {8, 4}, Wall = {12, 3}, Gate = {12, 2.4}, ArrowTower = {6.4, 6.4}, SpikeTrap = {8.6, 8.6}, PetStand = {5.6, 5.6},
		TorchPost = {1.6, 1.6}},
	-- 괴물이 지나가지 못하고 부숴야 하는 것
	Blocks = {Wall = true, Gate = true},
	-- 처음부터 있는 것: {종류, 길목, 반지름, 옆으로}. v2: 빈 기지에서 시작한다 (제작대·벽·포탑 모두 직접 짓는다)
	-- 예전 값: {{"Gate", 1, 40, 0}, {"Gate", 2, 40, 0}, {"Wall", 3, 40, 0}, {"ArrowTower", 1, 31, 11}}
	Starter = {},
	Limit = 60, -- 한 판에 놓을 수 있는 구조물 수 (성능)
}
