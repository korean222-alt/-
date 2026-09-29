-- 제작법. 재료는 공용 창고에서 쓴다. 만든 물건은 만든 사람이 갖는다 (가방·도구·소모품).
--  Station = "Workbench" : 기지 제작대. Bench = 필요한 제작대 레벨 (제작대는 팀 공용으로 업그레이드)
--  Station = "Campfire"  : 기지 모닥불에서 요리
return {
	Order = {
		"Torch", "StoneAxe", "StonePick", "StoneSpear", "Trap", "Bait", "Snack", "FiberBag", "RoastMushroom",
		"BetterTrap", "IronAxe", "IronPick", "IronSpear", "SturdyBag", "Stew",
		"CrystalTrap", "CrystalSpear",
	},
	Recipes = {
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
	-- 제작대 레벨 (팀 공용). 레벨이 오르면 새 제작법과 방어 시설 업그레이드가 풀린다.
	Bench = {
		{Name = "제작대 Lv1"},
		{Name = "제작대 Lv2", Cost = {Wood = 40, Stone = 25, Fiber = 10}},
		{Name = "제작대 Lv3", Cost = {Stone = 40, Scrap = 20, Crystal = 5}},
	},
}
