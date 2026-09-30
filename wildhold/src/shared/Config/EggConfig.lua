-- 알 (원정 보상 → 로비 부화장에서 부화). 소유욕의 핵심: "무엇이 나올까" + 재능 별·빛나는 변종.
--  Rare  : 원정 클리어(5밤) 보상. 별 3개 이상 보장, 빛나는 확률 높음, 알파(브라이어혼)도 나올 수 있다
--  Common: 실패해도 CommonNights 밤 이상 버티면 보상
-- 확률은 Pool 의 {종, 가중치}. 부화한 펫은 새끼(Stage 1) · Level 로 시작한다.
return {
	Order = {"Rare", "Common"},
	Kinds = {
		Common = {Name = "보통 알", Icon = "🥚", Color = "#e8dcc0", Spots = "#a8916a", HatchSeconds = 90, Level = 1,
			Pool = {{"Mossling", 30}, {"Emberpup", 25}, {"Shellbub", 25}, {"Mossdeer", 8}, {"Ashlizard", 6}, {"Bogtoad", 6}},
			Stars = {20, 34, 28, 13, 5}, MinStars = 1, ShinyChance = 1 / 60},
		Rare = {Name = "희귀한 알", Icon = "🌟", Color = "#bfe8ff", Spots = "#7a5cff", HatchSeconds = 180, Level = 3,
			Pool = {{"Mossdeer", 22}, {"Ashlizard", 22}, {"Bogtoad", 22}, {"Emberpup", 12}, {"Shellbub", 12}, {"Briarhorn", 10}},
			Stars = {0, 0, 45, 35, 20}, MinStars = 3, ShinyChance = 1 / 25},
	},
	CommonNights = 3, -- 이만큼 버티면 실패해도 보통 알
	Limit = 20, -- 가질 수 있는 알 수 (넘치면 코인으로)
	OverflowCoins = 40,
	IncubatorSlots = 2, -- 부화장 칸 (동시에 부화)
}
