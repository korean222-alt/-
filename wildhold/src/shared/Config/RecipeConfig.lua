-- 제작법. 재료는 내 가방에서 먼저, 모자라면 공용 창고에서 쓴다 (기지 영역 안에 있을 때). 만든 물건은 만든 사람이 갖는다.
--  Station = "Hand"      : 어디서나 (🔨 제작대 설치 도구 — 나무 한 그루면 된다, 들어와서 1분 안에 첫 건축)
--  Station = "Workbench" : 내가 놓은 제작대 근처. Bench = 필요한 제작대 레벨 (제작대에서 [E] 강화)
--  Station = "Campfire"  : 기지 모닥불에서 요리
return {
	Order = {
		"WorkbenchKit", "WallKit", "GateKit", "TowerKit", "SpikeKit", "StandKit", "TorchKit", "Torch", "StoneAxe", "StonePick", "StoneSpear", "Trap", "Bait", "Snack", "FiberBag", "RoastMushroom",
		"BetterTrap", "IronAxe", "IronPick", "IronSpear", "SturdyBag", "Stew",
		"CrystalTrap", "CrystalSpear",
	},
	Recipes = {
		WorkbenchKit = {Station = "Hand", Bench = 0, Cost = {Wood = 8}},
		WallKit = {Station = "Workbench", Bench = 1, Cost = {Wood = 10}},
		GateKit = {Station = "Workbench", Bench = 1, Cost = {Wood = 8}},
		TowerKit = {Station = "Workbench", Bench = 1, Cost = {Wood = 15, Stone = 5}},
		SpikeKit = {Station = "Workbench", Bench = 1, Cost = {Wood = 8, Stone = 4}},
		StandKit = {Station = "Workbench", Bench = 1, Cost = {Wood = 4, Stone = 6}},
		TorchKit = {Station = "Workbench", Bench = 1, Cost = {Wood = 2, Fiber = 1}},
		Torch = {Station = "Workbench", Bench = 1, Cost = {Wood = 2, Fiber = 2}},
		StoneAxe = {Station = "Workbench", Bench = 1, Cost = {Wood = 5, Stone = 4, Fiber = 3}},
		StonePick = {Station = "Workbench", Bench = 1, Cost = {Wood = 5, Stone = 4, Fiber = 3}},
		StoneSpear = {Station = "Workbench", Bench = 1, Cost = {Wood = 6, Stone = 3, Fiber = 4}},
		Trap = {Station = "Workbench", Bench = 1, Cost = {Wood = 2, Fiber = 3}},
		Bait = {Station = "Workbench", Bench = 1, Cost = {Berry = 3}},
		Snack = {Station = "Workbench", Bench = 1, Cost = {Berry = 2, Fiber = 1}},
		FiberBag = {Station = "Workbench", Bench = 1, Cost = {Fiber = 18, Wood = 6}},
		RoastMushroom = {Station = "Campfire", Bench = 1, Cost = {Mushroom = 2}},
		BetterTrap = {Station = "Workbench", Bench = 2, Cost = {Wood = 2, Fiber = 3, Scrap = 2}},
		IronAxe = {Station = "Workbench", Bench = 2, Cost = {Wood = 6, Scrap = 8, Stone = 4}},
		IronPick = {Station = "Workbench", Bench = 2, Cost = {Wood = 6, Scrap = 8, Stone = 4}},
		IronSpear = {Station = "Workbench", Bench = 2, Cost = {Wood = 6, Scrap = 8, Fiber = 4}},
		SturdyBag = {Station = "Workbench", Bench = 2, Cost = {Fiber = 25, Scrap = 8}},
		Stew = {Station = "Campfire", Bench = 2, Cost = {Berry = 4, Mushroom = 3}},
		CrystalTrap = {Station = "Workbench", Bench = 3, Cost = {Crystal = 2, Scrap = 3, Fiber = 4}},
		CrystalSpear = {Station = "Workbench", Bench = 3, Cost = {Crystal = 6, Scrap = 10, Wood = 4}},
	},
	-- 제작대 레벨 (강화 비용은 DefenseConfig.Workbench). 레벨이 오르면 새 제작법과 방어 시설 강화가 풀린다. 이름은 Locale "bench.lv"
	Bench = {{}, {}, {}},
}
