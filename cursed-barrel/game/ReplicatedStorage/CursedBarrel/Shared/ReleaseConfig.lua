-- Release configuration. IDs are deliberately zero until the owner creates assets.
local C = {}
C.Version = "9.0.0-dragon-tide"
C.StudioSolo = false
C.FriendBonus = 0.10 -- one verified friend in the same round, non-stacking
C.PartyBonus = 0.05
C.AFKTimeouts = 3
C.Badges = { first_win = 0, win10 = 0, win50 = 0, catch50 = 0, catch250 = 0, streak3 = 0, streak7 = 0, games100 = 0 }
C.Audio = { Lobby = 0, Match = 0, Dragon = 0, Impact = 0, Win = 0 } -- licensed owner audio IDs
C.Branding = {
 -- Exact user-supplied images are in assets/branding, unchanged.
 -- Roblox ImageButton requires a Roblox-uploaded image asset ID, not a local JPEG path.
 ShopImage = 0,
 IconFile = "assets/branding/game_profile.jpeg",
 ThumbnailFile = "assets/branding/game_thumbnail.jpeg",
 ShopFile = "assets/branding/shop_button.jpeg",
}
C.Weekly = {
 {id="week_games",text="주간 20판 완료",en="Complete 20 rounds",metric="games",goal=20,reward=1800},
 {id="week_wins",text="주간 5회 우승",en="Win 5 rounds",metric="wins",goal=5,reward=2200},
 {id="week_catches",text="주간 해적 25회 잡기",en="Catch 25 pirates",metric="catches",goal=25,reward=1600},
}
C.Season = {
 Enabled=true, Id="dragon_tide_2026", Name="용의 항로", EnglishName="Dragon Tide",
 StartsAt=1788220800, EndsAt=1798761600, -- 2026-09-01 through 2027-01-01 UTC
 Tiers={
  {xp=100,coins=500}, {xp=250,coins=1000},
  {xp=500,kind="Chair",skin="dragon_throne"},
  {xp=900,kind="Victory",skin="dragon_ascension"},
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
