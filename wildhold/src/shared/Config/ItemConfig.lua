-- 손에 드는 모든 것 (핫바에 보이는 것). 판마다 초기화된다.
--  Tool    : 창·도끼·곡괭이·횃불. 계열(Family)마다 가장 좋은 등급 하나만 핫바에 보인다.
--  Trap    : 덫. 들고 공격하면 가까운 지친 야생 펫에게 던진다. Catch = 포획 확률 배율, Better = 먹이가 있으면 같이 쓴다
--  PetFood : 펫 회복 간식. 들고 공격하면 가까운 다친 내 펫을 회복.
--  Food    : 먹으면 배고픔(+Hunger)과 체력(+Heal)을 채운다.
--  Bag     : 가방. 들고 다니는 게 아니라 가진 것 중 가장 큰 용량이 적용된다 (핫바에 안 보임).
-- Damage = 적·야생 펫에게 주는 피해, Gather = 맞는 도구로 채집할 때 배율 (ResourceConfig 의 Tool 참고)
return {
	-- 핫바 순서
	-- 설치 도구(Build)는 가지고 있을 때만 칸이 생긴다 (놓으면 없어짐). 한 번에 9칸까지
	Order = {"Spear", "Axe", "Pickaxe", "Torch", "WorkbenchKit", "WallKit", "GateKit", "TowerKit", "SpikeKit", "StandKit", "TorchKit",
		"Trap", "BetterTrap", "CrystalTrap", "Snack", "Berry", "RoastMushroom", "Stew"},
	Families = {"Spear", "Axe", "Pickaxe", "Torch"},
	HandDamage = 6,
	HandGather = 0.3, -- 맨손으로 나무·돌을 칠 때
	WrongToolGather = 0.35, -- 창으로 나무를 칠 때처럼 안 맞는 도구
	Items = {
		OldSpear = {Icon = "🔱", Kind = "Tool", Family = "Spear", Tier = 1, Damage = 24},
		StoneSpear = {Icon = "🔱", Kind = "Tool", Family = "Spear", Tier = 2, Damage = 34},
		IronSpear = {Icon = "🔱", Kind = "Tool", Family = "Spear", Tier = 3, Damage = 48},
		CrystalSpear = {Icon = "🔱", Kind = "Tool", Family = "Spear", Tier = 4, Damage = 66},
		OldAxe = {Icon = "🪓", Kind = "Tool", Family = "Axe", Tier = 1, Damage = 14, Gather = 1.0},
		StoneAxe = {Icon = "🪓", Kind = "Tool", Family = "Axe", Tier = 2, Damage = 20, Gather = 1.6},
		IronAxe = {Icon = "🪓", Kind = "Tool", Family = "Axe", Tier = 3, Damage = 28, Gather = 2.4},
		StonePick = {Icon = "⛏️", Kind = "Tool", Family = "Pickaxe", Tier = 2, Damage = 12, Gather = 1.3},
		IronPick = {Icon = "⛏️", Kind = "Tool", Family = "Pickaxe", Tier = 3, Damage = 18, Gather = 2.2},
		Torch = {Icon = "🔥", Kind = "Tool", Family = "Torch", Tier = 1, Damage = 8},
		Trap = {Icon = "🧺", Kind = "Trap", Catch = 1},
		BetterTrap = {Icon = "🧺", Kind = "Trap", Catch = 1.35, Better = true},
		CrystalTrap = {Icon = "💠", Kind = "Trap", Catch = 1.7, Better = true},
		Bait = {Icon = "🍓", Kind = "Bait"},
		Snack = {Icon = "🍪", Kind = "PetFood", HealPet = 0.5},
		-- 열매는 가방의 자원(Berry)을 바로 먹는다
		Berry = {Icon = "🍓", Kind = "Food", Hunger = 9, Heal = 2, FromBag = true},
		RoastMushroom = {Icon = "🍄", Kind = "Food", Hunger = 32, Heal = 15},
		Stew = {Icon = "🍲", Kind = "Food", Hunger = 65, Heal = 40},
		-- 설치 도구: 들고 공격 버튼 = 설치 (BuildConfig.Kits)
		WorkbenchKit = {Icon = "🔨", Kind = "Build"},
		WallKit = {Icon = "🧱", Kind = "Build"},
		GateKit = {Icon = "🚪", Kind = "Build"},
		TowerKit = {Icon = "🏹", Kind = "Build"},
		SpikeKit = {Icon = "⚠", Kind = "Build"},
		StandKit = {Icon = "🐾", Kind = "Build"},
		TorchKit = {Icon = "🕯", Kind = "Build"},
		FiberBag = {Icon = "🎒", Kind = "Bag", Capacity = 100},
		SturdyBag = {Icon = "🎒", Kind = "Bag", Capacity = 150},
	},
	-- 원정 시작 때 받는 것
	Starter = {OldSpear = 1, OldAxe = 1, Trap = 5, Bait = 1, Snack = 1},
	Limit = 30, -- 소모품 최대 보유
	BaseCapacity = 60, -- 가방 없을 때
	-- 도구 등급별 모양 색 (낡은 → 돌 → 고철 → 수정)
	TierLook = {
		{Head = "#8a7f72", Material = "Slate", Wood = "#7a5a3c"},
		{Head = "#9aa1a6", Material = "Slate", Wood = "#8a6242"},
		{Head = "#c9d2d8", Material = "Metal", Wood = "#5e4430"},
		{Head = "#7ff0ff", Material = "Neon", Wood = "#3d4a63"},
	},
}
