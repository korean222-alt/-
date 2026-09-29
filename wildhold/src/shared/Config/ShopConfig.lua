-- 코인 쓰는 곳 (영구). 밤을 버티면 받는 코인으로 "다음 원정부터 더 좋게 시작" 하는 보급을 해금한다.
-- 혼자 해도 판을 거듭할수록 편해지는 이유가 된다. 전투력을 돈으로 사는 구조가 아니다 (코인은 게임 안에서만 번다).
return {
	Order = {"StartTraps", "StartFood", "StartTorch", "StartStoneAxe", "StartBag"},
	Perks = {
		StartTraps = {Name = "덫 +3 개로 시작", Icon = "🧺", Cost = 80, Give = {Trap = 3}},
		StartFood = {Name = "간식·먹이 +2 개로 시작", Icon = "🍪", Cost = 80, Give = {Snack = 2, Bait = 2}},
		StartTorch = {Name = "횃불을 들고 시작", Icon = "🔥", Cost = 100, Give = {Torch = 1}},
		StartStoneAxe = {Name = "돌 도끼로 시작", Icon = "🪓", Cost = 160, Give = {StoneAxe = 1}},
		StartBag = {Name = "섬유 가방으로 시작", Icon = "🎒", Cost = 200, Give = {FiberBag = 1}},
	},
	DexReward = 25, -- 새 종을 처음 영구 확정하면 받는 코인 (도감 보상)
}
