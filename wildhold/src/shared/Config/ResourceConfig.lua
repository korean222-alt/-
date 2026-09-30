-- 자원. Tool = 이 자원을 잘 캐는 도구 계열 (ItemConfig). 없으면 맨손·아무 도구로 똑같이 캔다.
-- MinTier = 이 등급 이상의 맞는 도구가 있어야 캘 수 있다 (수정 = 고철 곡괭이부터).
return {
	Order = {"Wood", "Stone", "Fiber", "Berry", "Mushroom", "Scrap", "Crystal"},
	Icons = {Wood = "🪵", Stone = "🪨", Fiber = "🌿", Berry = "🍓", Mushroom = "🍄", Scrap = "⚙️", Crystal = "💎"},
	Types = {
		Wood = {HP = 75, Yield = 8, Respawn = 45, Tool = "Axe", Color = {130, 102, 75}},
		Stone = {HP = 70, Yield = 6, Respawn = 50, Tool = "Pickaxe", Color = {138, 150, 158}},
		Fiber = {HP = 25, Yield = 5, Respawn = 30, Color = {126, 175, 111}},
		Berry = {HP = 25, Yield = 4, Respawn = 35, Color = {208, 112, 144}},
		Mushroom = {HP = 20, Yield = 3, Respawn = 40, Color = {196, 150, 110}},
		Scrap = {HP = 100, Yield = 4, Respawn = 60, Tool = "Pickaxe", Color = {119, 145, 163}},
		Crystal = {HP = 150, Yield = 3, Respawn = 90, Tool = "Pickaxe", MinTier = 3, Color = {127, 240, 255}},
	},
}
