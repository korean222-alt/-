-- 보물상자 (v2 도파민 포인트). 유적 한가운데·스폰 근처에 놓이고, 하늘로 솟은 빛기둥으로 멀리서도 보인다.
-- [E] 로 열면 잠깐 덜컹거리다 뚜껑이 열리고, 등급 색 빛과 함께 자원이 튀어나온다 (가까이 있으면 저절로 빨려 들어옴).
--  Tier : Common 일반 · Rare 희귀 · Epic 영웅
--  Res  : 자원 {종류 = {최소, 최대}} → 상자에서 튀어나오는 자원 (ResourceService:Drop)
--  Items: 아이템 {아이템ID = 개수} → 바로 소지품에 (가진 개수가 ItemConfig.Limit 를 넘지 않게)
--  Pick : Items 중에서 무작위로 몇 개 고를지 (없으면 전부)
--  Upgrade = true : 계열(도끼·곡괭이·창)마다 가진 것보다 한 등급 위 도구 하나 (영웅 상자)
return {
	OpenDelay = 0.65, -- 덜컹거리는 시간 (이 뒤에 전리품이 나온다)
	Range = 11, -- 이 거리 안에서 열 수 있다
	Refill = 300, -- 유적 상자는 열린 뒤 이 시간(초)이 지나면 다시 채워진다
	-- 스폰 근처 첫 상자: 대원마다 한 번씩 열 수 있다 (판마다). 첫 상자는 늘 희귀
	Starter = {Distance = 70, Tier = "Rare"},
	Colors = {Common = "#f2e6c4", Rare = "#5cb8ff", Epic = "#c77dff"},
	Tiers = {
		Common = {
			Res = {Wood = {6, 10}, Stone = {4, 6}, Fiber = {3, 5}, Berry = {3, 4}},
			Items = {Trap = 2, Snack = 1, RoastMushroom = 2},
			Pick = 1,
		},
		Rare = {
			Res = {Wood = {10, 14}, Stone = {8, 10}, Fiber = {6, 8}, Mushroom = {3, 4}, Scrap = {2, 4}},
			Items = {BetterTrap = 2, Snack = 2, Stew = 1, RoastMushroom = 2},
			Pick = 2,
		},
		Epic = {
			Res = {Wood = {14, 18}, Stone = {12, 14}, Scrap = {6, 9}, Crystal = {2, 3}, Mushroom = {4, 5}},
			Items = {CrystalTrap = 1, Stew = 2, Snack = 2},
			Upgrade = true,
		},
	},
	-- 지역별 유적 수와 상자 등급 (가장 먼 유적은 한 단계 위)
	Ruins = {
		Meadow = {Count = 2, Tier = "Common", Far = "Rare", Kinds = {"Circle", "Temple"}},
		Crags = {Count = 3, Tier = "Rare", Far = "Epic", Kinds = {"Tower", "Arch", "Temple"}},
		Ancient = {Count = 3, Tier = "Rare", Far = "Epic", Kinds = {"Temple", "Arch", "Tower"}},
		Swamp = {Count = 3, Tier = "Rare", Far = "Epic", Kinds = {"Tower", "Temple", "Arch"}},
	},
}
