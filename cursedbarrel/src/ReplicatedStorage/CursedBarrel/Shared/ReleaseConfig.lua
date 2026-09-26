-- Release configuration. IDs are deliberately zero until the owner creates assets.
local C = {}
C.Version = "24.0.0"

--------------------------------------------------
-- Phase 17 : 출시에 필요한 ID 는 전부 이 파일에 적는다 (숫자만)
--   만드는 곳 : create.roblox.com → Creations → 이 게임 → Monetization
--     · Developer Products → Create → 목록 그림의 ⋯ → Copy Asset ID
--     · Passes → Create → ⋯ → Copy Asset ID  (Sales 에서 Item for Sale 켜기)
--   ★ 가격은 GameConfig 의 robux 값과 똑같이 적어 주세요 (상점에 보이는 값 = 실제 결제 값)
--   ★ 이 게임 안에서 만든 상품이어야 합니다 (다른 게임의 상품은 2026-05-30 부터 팔 수 없음)
--   0 이면 상점에 "준비 중" 으로 보이고 살 수 없다. (Studio 에서는 무료 시험 가능)
--------------------------------------------------
C.ProductIds = {
 coins_small = 3714669149, -- 코인 15,000 · 159 R$
 coins_medium = 3714669225, -- 코인 30,000 · 319 R$
 coins_large = 3714669293, -- 코인 70,000 · 369 R$
 coins_huge = 3714669439, -- 코인 160,000 · 799 R$
 coins_vault = 3714669506, -- 코인 500,000 · 1,999 R$
 starter = 3714669924, -- 선원 스타터 팩 · 99 R$
 -- (선택) 방해 아이템
 ink = 0, shake = 0, hurry = 0, scramble = 0, roar = 0,
}
C.GamePassIds = {
 VIP = 1998602379, -- VIP 선장 패스 · 399 R$
 Booster = 1999928363, -- 현상금 부스터 · 249 R$
}
C.StudioSolo = false
C.FriendBonus = 0.10 -- one verified friend in the same round, non-stacking
C.PartyBonus = 0.05
C.AFKTimeouts = 3
C.Badges = { first_win = 0, win10 = 0, win50 = 0, catch50 = 0, catch250 = 0, streak3 = 0, streak7 = 0, games100 = 0,
 raid10 = 0, crew5 = 0, tourney34 = 0, cannon100 = 0 } -- Phase 12 : 칭호 업적도 배지로 줄 수 있다 (0 이면 건너뜀)
-- 음원 ID. 0 이면 Roblox 기본 효과음으로 대신하거나 조용히 둔다. (docs/Phase12_에셋_상품_안내_KO.md 에 찾는 곳이 있다)
-- Phase 21 : 배경음악 · 심장 소리 · 잭팟 소리는 직접 작곡해 두었다 → roblox-cursed-barrel/audio/*.ogg
--   Studio → 보기 → 에셋 관리자 → 가져오기(Import) 로 .ogg 를 올리고, 오른쪽 클릭 → Copy Asset ID → 아래 숫자에 붙여 넣기
C.Audio = {
 Lobby = 100089390811202, -- lobby.ogg : 로비 뱃노래 (반복). 밤 · 폭풍 음악을 따로 안 넣으면 이 곡이 계속 나온다
 Match = 70852587476324, -- match.ogg : 게임 중 긴장 음악 (반복)
 MatchFinal = 84836020545310, -- final.ogg : 결승(마지막 두 명) 음악 (반복). 0 이면 Match 를 조금 빠르게 튼다
 Heartbeat = 133565197103552, -- heartbeat.ogg : 심장 "쿵-쿵". 라운드가 올라갈수록 빨리 뛴다 (0 이면 기본 소리로 대신)
 Jackpot = 96889994861519, -- jackpot.ogg : 잭팟 팡파르
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
 -- Phase 24 : 화면 버튼 소리 (0 이면 Roblox 기본 "딸깍" 소리를 높여서 쓴다)
 Click = 0, -- 버튼 · 탭 · 퀘스트 받기 등을 누를 때
 Open = 0, -- 창(상점 · 출석 · 항해 수첩 …)이 열릴 때
}
-- Phase 24 : 이 게임에서 재생할 수 없는 음원(권한 없음 · 심사 거절 · 삭제). 클라이언트가 켜질 때 채운다 (ReleaseController).
--   여기에 들어간 소리는 0 인 것처럼 기본 소리로 대신한다.
C.AudioFailed = {}
function C.audioId(key)
 local id = tonumber(C.Audio[key]) or 0
 if id <= 0 or C.AudioFailed[key] then return 0 end
 return id
end
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
-- Phase 16.1 : 그룹 ID (그룹 페이지 주소의 숫자). 계단 아래 파란 드럼은 서버가 이 그룹 가입을 확인한 사람에게만 준다. 0 이면 아무도 못 받는다.
C.GroupId = 0
-- Phase 13 : 버튼 이미지 ID. 0 이면 코드로 그린 나무 버튼을 쓴다.
--   Attendance : assets/branding/attendance_button.png 을 올린 이미지 ID (출석판 버튼)
--   Roulette   : assets/branding/roulette_button.png 을 올린 이미지 ID (룰렛 버튼)
C.Images = { Attendance = 0, Roulette = 0 }
-- Blender 로 렌더한 버튼 PNG 를 Roblox 에 업로드한 뒤 이미지 ID 를 적는다.
-- 0 인 동안에도 같은 소품을 ViewportFrame 3D 아이콘으로 표시한다.
C.Images.Buttons = { Shop = 83154457667168, Quest = 129160417218479, Sabotage = 122019919299247, Attendance = 96573704685287, Roulette = 73600487469864, Code = 136722937887207, Voyage = 111953096805607 }
-- Phase 16 : 돈 모양 그림 ID (assets/ui/money/*.png 를 올린 ID). 0 이면 같은 모양의 작은 3D 모형이 대신 보인다.
C.Images.Money = { cash = 0, cash2 = 0, cash3 = 0, coins = 0, chest = 0, vault = 0, gift = 0, crown = 0, potion = 0 } -- 빗줄기 이미지 (0 이면 기본 입자를 길게 늘여 쓴다)
-- Phase 17 : 상점 카드 그림 (선택). roblox-cursed-barrel/thumbnails/cards/종류_id.png 를 올린 이미지 ID.
--   0 이면 카드에 3D 모형이 그대로 보인다 (올리지 않아도 됨). 넣으면 그 그림이 보인다 (휴대폰이 더 가볍다)
C.Images.Skins = {
 ["Knife/classic"] = 0,
 ["Knife/bone"] = 0,
 ["Knife/gold"] = 0,
 ["Knife/cursed"] = 0,
 ["Knife/ember"] = 0,
 ["Knife/deep"] = 0,
 ["Knife/starter_hook"] = 0,
 ["Knife/vip_cutlass"] = 0,
 ["Knife/tide_dragon"] = 0,
 ["Knife/crimson_dragon"] = 0,
 ["Knife/moon_dragon"] = 0,
 ["Barrel/oak"] = 0,
 ["Barrel/drum"] = 0,
 ["Barrel/steel"] = 0,
 ["Barrel/blue_drum"] = 0,
 ["Barrel/treasure"] = 0,
 ["Barrel/kimchi"] = 0,
 ["Barrel/abyss"] = 0,
 ["Barrel/volcano"] = 0,
 ["Barrel/frost"] = 0,
 ["Barrel/tide_dragon"] = 0,
 ["Barrel/crimson_dragon"] = 0,
 ["Barrel/moon_dragon"] = 0,
 ["Ghost/captain"] = 0,
 ["Ghost/skull"] = 0,
 ["Ghost/kraken"] = 0,
 ["Ghost/cook"] = 0,
 ["Ghost/ember"] = 0,
 ["Ghost/siren"] = 0,
 ["Ghost/voidking"] = 0,
 ["Ghost/tide_dragon"] = 0,
 ["Ghost/crimson_dragon"] = 0,
 ["Ghost/moon_dragon"] = 0,
 -- Phase 24 : 모션 · 의자 · 탈락 · 승리 카드 그림 자리 (0 이면 동작 · 테마 그림 + "눌러서 미리보기" 가 보인다)
 ["Stab/classic"] = 0, ["Stab/overhead"] = 0, ["Stab/triple"] = 0, ["Stab/spin"] = 0,
 ["Stab/flourish"] = 0, ["Stab/ember_slam"] = 0, ["Stab/dragon_dive"] = 0, ["Stab/storm_strike"] = 0,
 ["Chair/classic"] = 0, ["Chair/captain"] = 0, ["Chair/dragon_throne"] = 0,
 ["Elimination/classic"] = 0, ["Elimination/rift"] = 0, ["Elimination/dragon_devour"] = 0,
 ["Elimination/ink_burst"] = 0, ["Elimination/ember_ash"] = 0, ["Elimination/frost_shatter"] = 0,
 ["Victory/classic"] = 0, ["Victory/solar_crown"] = 0, ["Victory/dragon_ascension"] = 0, ["Victory/gold_rain"] = 0,
 ["Victory/frost_crown"] = 0, ["Victory/kraken_embrace"] = 0, ["Victory/storm_lord"] = 0,
}
-- Phase 17 : 꽃잎 그림 (선택). roblox-cursed-barrel/fx/petal.png 를 올린 ID. 신화 스킨에 꽃잎 입자가 더 붙는다
--   0 이어도 Blender 꽃잎 조각은 흩날린다.
C.Images.Petal = 0
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
-- Phase 24 : aiCrew = 혼자 기다릴 때 AI 선원을 채워 줄지. 한 번 바꾸면 저장되어 다시 바꿀 때까지 그대로 간다.
--   앉은 사람 중 한 명이라도 끄면 그 테이블에는 AI 가 오지 않는다 (사람끼리 하고 싶을 때). "연습 한 판"은 예외.
C.Settings = {music=0.35,sfx=0.65,shake=true,reducedFX=false,quality="Auto",language="Auto",camera=true,wide=true,aiCrew=true}
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
-- Phase 24 : 출시 전 점검. 아직 0 인(등록하지 않은) ID 를 종류별로 모아 돌려준다. 서버가 켜질 때 출력창에 한 번 적는다.
--   필수 : 방해 상품(0 이면 출시 서버에서 살 수 없다) · 선택 : 음원 · 그림 · 배지 · 그룹 (0 이면 대체 표현을 쓰거나 건너뛴다)
function C.missingIds()
 local out={}
 local function scan(label,list,skip)
  local keys={}
  for key,value in pairs(list or {}) do
   if typeof(value)=="number" and value<=0 and not (skip and skip[key]) then table.insert(keys,tostring(key)) end
  end
  table.sort(keys)
  if #keys>0 then table.insert(out,{label=label,keys=keys}) end
 end
 scan("Developer Product (ProductIds)",C.ProductIds)
 scan("Game Pass (GamePassIds)",C.GamePassIds)
 scan("Badge (Badges)",C.Badges)
 scan("Audio (Audio)",C.Audio)
 scan("Image (Images)",C.Images,{Buttons=true,Money=true,Skins=true,Petal=true})
 scan("Image (Images.Money)",C.Images.Money)
 scan("Image (Images.Skins)",C.Images.Skins)
 scan("Image (UIImages · Textures · Branding)",{Pattern=C.UIImages.Pattern,Rain=C.Textures.Rain,ShopImage=C.Branding.ShopImage,Petal=C.Images.Petal})
 if (tonumber(C.GroupId) or 0)<=0 then table.insert(out,{label="Group (GroupId)",keys={"GroupId"}}) end
 return out
end
return C
