-- Release configuration. IDs are deliberately zero until the owner creates assets.
local C = {}
C.Version = "15.0.0"
C.StudioSolo = false
C.FriendBonus = 0.10 -- one verified friend in the same round, non-stacking
C.PartyBonus = 0.05
C.AFKTimeouts = 3
C.Badges = { first_win = 0, win10 = 0, win50 = 0, catch50 = 0, catch250 = 0, streak3 = 0, streak7 = 0, games100 = 0,
 raid10 = 0, crew5 = 0, tourney34 = 0, cannon100 = 0 } -- Phase 12 : 칭호 업적도 배지로 줄 수 있다 (0 이면 건너뜀)
-- 음원 ID. 0 이면 Roblox 기본 효과음으로 대신하거나 조용히 둔다. (docs/Phase12_에셋_상품_안내_KO.md 에 찾는 곳이 있다)
C.Audio = {
 Lobby = 0, -- 로비 음악 (낮 · 노을 · 새벽, 반복)
 Match = 0, -- 테이블 게임 중 긴장 음악 (반복)
 Dragon = 0, -- 해적이 튀어나올 때 비명 · 포효
 Impact = 0, -- 칼이 꽂히는 소리
 Win = 0, -- 승리 팡파르
 -- Phase 12
 Night = 0, -- 밤 · 안개 로비 음악 (반복)
 Storm = 0, -- 폭풍 · 크라켄 습격 음악 (반복)
 Rain = 0, -- 빗소리 (반복)
 Thunder = 0, -- 천둥
 KrakenRoar = 0, -- 크라켄 울음 (습격 시작)
 Slam = 0, -- 다리가 갑판을 내려치는 "쾅"
 WoodCrack = 0, -- 갑판이 부서지는 소리
 Cannon = 0, -- 대포 발사
 Splash = 0, -- 포탄이 바다에 떨어지는 소리
 Hit = 0, -- 포탄이 크라켄에 맞는 소리
 Coins = 0, -- 금화 쏟아지는 소리
 Waves = 0, -- 파도 · 바람 (반복, 배경)
}
C.Textures = { Rain = 0 }
-- Phase 14 : 3D 모델(메시) ID. 0 이면 코드로 만든 모양을 쓴다.
--   Studio 에서 MeshPart 를 가져온 뒤 속성창의 MeshId · TextureID 숫자를 적는다.
--   Scale 은 모양이 너무 크거나 작을 때만 고친다. (Offset 은 위치가 어긋날 때)
--   Knife  : 스킨 id 마다 { MeshId = 0, TextureId = 0, Scale = Vector3.new(1, 1, 1) }  예) Knife = { gold = { MeshId = 123, TextureId = 456 } }
--   Barrel : 스킨 id 마다 같은 모양. 통 몸통에 붙고 쇠테 · 뚜껑 장식은 숨긴다.
--   Cannon : 대포 포신 하나. (8문 모두 같은 모델)
C.Meshes = {
 Knife = {},
 Barrel = {},
 Cannon = { MeshId = 0, TextureId = 0, Scale = Vector3.new(1, 1, 1), Offset = Vector3.new(0, 0, 0) },
}
-- Phase 14 : UI 그림 ID (0 이면 코드로 그린 것을 쓴다)
--   Pattern : 창 머리띠에 깔리는 무늬 타일 (assets/ui/pattern_tile.png 를 올린 ID)
C.UIImages = { Pattern = 0 }
-- Phase 13 : 버튼 이미지 ID. 0 이면 코드로 그린 나무 버튼을 쓴다.
--   Attendance : assets/branding/attendance_button.png 을 올린 이미지 ID (출석판 버튼)
--   Roulette   : assets/branding/roulette_button.png 을 올린 이미지 ID (룰렛 버튼)
C.Images = { Attendance = 0, Roulette = 0 } -- 빗줄기 이미지 (0 이면 기본 입자를 길게 늘여 쓴다)
C.Branding = {
 -- Exact user-supplied images are in assets/branding, unchanged.
 -- Roblox ImageButton requires a Roblox-uploaded image asset ID, not a local JPEG path.
 ShopImage = 0,
 IconFile = "assets/branding/game_profile.jpeg",
 ThumbnailFile = "assets/branding/game_thumbnail.jpeg",
 ShopFile = "assets/branding/shop_button.jpeg",
}
C.Weekly = {
 {id="week_games",text="주간 20판 완료",en="Complete 20 rounds",metric="games",goal=20,reward=5400},
 {id="week_wins",text="주간 5회 우승",en="Win 5 rounds",metric="wins",goal=5,reward=6600},
 {id="week_catches",text="주간 해적 25회 잡기",en="Catch 25 pirates",metric="catches",goal=25,reward=4800},
}
C.Season = {
 Enabled=true, Id="dragon_tide_2026", Name="용의 항로", EnglishName="Dragon Tide",
 StartsAt=1788220800, EndsAt=1798761600, -- 2026-09-01 through 2027-01-01 UTC
 Tiers={
  {xp=100,coins=1500}, {xp=250,coins=3000},
  {xp=500,kind="Chair",skin="dragon_throne"},
  {xp=900,kind="Victory",skin="dragon_ascension"},
  {xp=1300,kind="Stab",skin="storm_strike"}, -- Phase 12 : 시즌 한정 칼 모션
 },
}
C.Settings = {music=0.35,sfx=0.65,shake=true,reducedFX=false,quality="Auto",language="Auto",camera=true,wide=true}
C.Cards = {
 skip={name="한 번 넘기기",en="Pass once"},
 rotate={name="통 회전",en="Rotate barrel"},
 seal={name="슬롯 봉인",en="Seal a slot"},
}
C.FX = {MaxBursts=3,MaxDistance=110,HighSegments=22,LowSegments=10}
C.Strings = {
 menu={"항해 수첩","Voyage"},watch={"관전","Spectate"},leave={"관전 종료","Exit spectator"},
 rejoin={"다음 판 참가","Rejoin next round"},settings={"설정","Settings"},weekly={"주간 의뢰","Weekly quests"},
 party={"파티","Party"},invite={"친구 초대","Invite friends"},claim={"보상 받기","Claim"},
 noTable={"진행 중인 테이블이 없습니다","No active tables"},cards={"파티 카드","Party cards"},
 preview={"3D 미리보기","3D Preview"},season={"용의 항로","Dragon Tide"},
}
function C.text(key,locale)
 local pair=C.Strings[key];return pair and pair[locale=="en" and 2 or 1] or key
end
function C.seasonActive(now)
 return C.Season.Enabled and now>=C.Season.StartsAt and now<C.Season.EndsAt
end
return C
