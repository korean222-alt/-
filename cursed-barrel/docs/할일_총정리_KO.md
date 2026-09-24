# 해야 할 일 총정리 — 이 문서 하나만 보시면 됩니다

게임 파일: `output/CursedBarrel_Phase14_Polish.rbxl`  (이번 변경: [Phase 14](Phase14_버그수정_그래픽_KO.md))
모든 ID는 **숫자만 복사해서 저에게 보내 주시면** 제가 넣고 새 파일을 드립니다. (직접 넣으셔도 됩니다)
맨 아래 [7장](#7-보내-주실-것--한-번에-복사해서-채우기)에 보내 주실 양식이 한 번에 있습니다.

| 순서 | 할 일 | 걸리는 시간 | 꼭? |
|---|---|---|---|
| 1 | Studio에서 열고 Publish | 5분 | ✅ |
| 2 | Play로 새 기능 확인 | 15분 | ✅ |
| 3 | 로벅스 상품 8개 만들기 | 30분 | ✅ |
| 4 | 그림 3개 올리기 | 10분 | ✅ |
| 5 | 소리 고르기 (17개, ★4개 먼저) | 20~40분 | 추천 |
| 6 | 공개 전 설정 | 20분 | ✅ (공개할 때) |
| 7 | ID 보내기 | 5분 | ✅ |

---

## 1. Studio에서 열고 Publish

1. Roblox Studio에서 `CursedBarrel_Phase14_Polish.rbxl` 을 엽니다.
2. **파일 → Roblox에 게시(Publish to Roblox)** 를 누릅니다.
   - 상품을 만들려면 게임이 한 번은 게시돼 있어야 합니다. 비공개 상태로 두어도 됩니다.
3. **게임 설정 → 보안 → "Studio에서 API 서비스 사용"** 을 켭니다. (저장 · 순위판을 Studio에서 확인할 수 있게)

## 2. Play로 확인할 것 (체크하면서)

- [ ] 왼쪽 아래 📅 출석 · 🎡 룰렛 버튼이 보이고, 들어오면 출석판이 한 번 열린다
- [ ] 출석 「받기!」 → ✔ 튀어나옴 → 룰렛이 이어서 열림 → 하루 한 번만 돌아감
- [ ] 상점:
  - 스킨마다 🪙 가격 버튼이 있다
  - 코인이 모자라면 아래에 「충전」 버튼이 생긴다
  - 코인 충전 「대」 줄이 금색이다
- [ ] 상점 → 통 탭 → **파란 철제 드럼** 「3D」 미리보기가 사진 속 드럼처럼 보인다
  - 파란 광택, 굴림 테 두 줄, 위아래 주름, 뚜껑 마개 두 개
- [ ] 신화(용 세트) 스킨 3D 미리보기에 무지갯빛 반짝임이 보인다
- [ ] 설정 → 언어 → English 로 바꾸면 화면이 영어가 된다
- [ ] 한 판 끝까지 해 보고 코인이 수백 단위로 들어오는지 본다 (한 판 평균 약 800)
- [ ] 폭풍 확인
  - `GameConfig.World.StudioStartPhase = "storm"` 으로 두고 Play 합니다.
  - 크라켄이 갑판을 쾅 치는지, 대포로 막히는지 봅니다.
  - **확인 뒤 `nil` 로 되돌립니다.**
- [ ] 휴대폰 화면(Studio의 기기 보기)에서 출석판 · 룰렛 · 상점 창 크기가 괜찮은지 본다

## 3. 로벅스 상품 만들기 (Creator Hub)

만드는 법 (자세히: [Phase 12 안내](Phase12_에셋_상품_안내_KO.md) 3장)
1. [create.roblox.com](https://create.roblox.com/) → Creations(내 작품) → 이 게임
2. 만들기
   - 개발자 상품: **Monetization → Developer Products → Create**
   - 게임패스: **Monetization → Passes → Create** → **Sales에서 Item for Sale 켜기**
3. 목록의 그림 위 **⋯ → Copy Asset ID** 로 숫자를 복사합니다.

⚠️ 가격은 아래 표와 **똑같이** 적어 주세요. (상점에 보이는 숫자와 실제 결제 가격이 같아야 합니다)

**개발자 상품 6개**

| 이름 (추천) | 가격 | 코드 이름 |
|---|---|---|
| 코인 충전 소 (15,000 코인) | 159 R$ | `coins_small` |
| 코인 충전 중 (30,000 코인) | 319 R$ | `coins_medium` |
| 코인 충전 대 (70,000 코인) | 369 R$ | `coins_large` |
| 코인 충전 특대 (160,000 코인) | 799 R$ | `coins_huge` |
| 코인 충전 금고 (500,000 코인) | 1,999 R$ | `coins_vault` |
| 선원 스타터 팩 (25,000 코인 + 전용 칼, 1회) | 99 R$ | `starter` |

**게임패스 2개**

| 이름 | 가격 | 코드 이름 |
|---|---|---|
| VIP 선장 패스 | 399 R$ | `VIP` |
| 현상금 부스터 | 249 R$ | `Booster` |

**선택: 방해 아이템 5개** (상대를 방해하는 아이템이라 공정성 논란이 생길 수 있습니다. 팔지 말지 먼저 정하세요)

| 이름 | 가격 | 코드 이름 |
|---|---|---|
| 먹물 한 통 | 15 R$ | `ink` |
| 흔들리는 손 | 25 R$ | `shake` |
| 저주의 재촉 | 35 R$ | `hurry` |
| 뒤섞인 번호 | 45 R$ | `scramble` |
| 해적의 포효 | 55 R$ | `roar` |

**만들지 않아도 되는 것** (예전 문서에 있었지만 지금은 없음)
- 스킨 바로 구매 5개
- 룰렛 이용권
- 로벅스 스킨 4개

## 4. 그림 올리기

Studio → **보기 → 에셋 관리자 → 가져오기(Import)** → 파일 선택 → 올라간 그림 오른쪽 클릭 → **Copy Asset ID**

| 파일 (`assets/branding/`) | 무엇 | 넣는 곳 |
|---|---|---|
| `attendance_button.png` | 📅 출석 버튼 (보내 주신 그림) | `ReleaseConfig.lua` → `C.Images.Attendance` |
| `roulette_button.png` | 🎡 룰렛 버튼 (보내 주신 그림) | `ReleaseConfig.lua` → `C.Images.Roulette` |
| `shop_button.jpeg` | 상점 버튼 | `ReleaseConfig.lua` → `C.Branding.ShopImage` |
| `assets/ui/pattern_tile.png` | 창 머리띠 무늬 (선택) | `ReleaseConfig.lua` → `C.UIImages.Pattern` |
| `game_profile.jpeg` | 게임 아이콘 | Creator Hub → 게임 → 설정의 아이콘 (ID 필요 없음) |
| `game_thumbnail.jpeg` | 게임 썸네일 | Creator Hub → 게임 → 설정의 썸네일 (ID 필요 없음) |

## 5. 소리 고르기 (`ReleaseConfig.lua` 의 `C.Audio`)

가장 쉬운 방법: Studio → 도구 상자 → Creator Store → **오디오**에서 검색 → ▶ 들어 보기 → 오른쪽 클릭 **Copy Asset ID**.
- 올릴 필요도, 심사도 없습니다.
- 음악(Lobby · Match · Night · Storm)은 꼭 여기서 고르세요. 밖에서 받은 음악은 저작권 검사에 걸릴 수 있습니다.
- 아무것도 안 넣어도 Roblox 기본 효과음으로 대신 소리가 납니다.

| 칸 | 무슨 소리 | 검색어 (Roblox 링크) |
|---|---|---|
| ★ `Slam` | 문어 다리가 갑판을 치는 "쾅" | [heavy impact](https://create.roblox.com/store/audio?keyword=heavy%20impact&includeOnlyVerifiedCreators=true) |
| ★ `WoodCrack` | 나무가 쩍 부서지는 소리 | [wood break](https://create.roblox.com/store/audio?keyword=wood%20break&includeOnlyVerifiedCreators=true) |
| ★ `KrakenRoar` | 바다 괴물 울음 | [monster roar](https://create.roblox.com/store/audio?keyword=monster%20roar&includeOnlyVerifiedCreators=true) |
| ★ `Thunder` | 천둥 | [thunder](https://create.roblox.com/store/audio?keyword=thunder&includeOnlyVerifiedCreators=true) |
| `Lobby` | 낮 로비 음악 (해적 분위기, 반복) | [pirate](https://create.roblox.com/store/audio?keyword=pirate&includeOnlyVerifiedCreators=true) |
| `Match` | 게임 중 긴장 음악 (반복) | [suspense](https://create.roblox.com/store/audio?keyword=suspense&includeOnlyVerifiedCreators=true) |
| `Night` | 밤 · 안개 음악 (으스스, 반복) | [dark ambient](https://create.roblox.com/store/audio?keyword=dark%20ambient&includeOnlyVerifiedCreators=true) |
| `Storm` | 폭풍 · 습격 음악 (긴박, 반복) | [epic battle](https://create.roblox.com/store/audio?keyword=epic%20battle&includeOnlyVerifiedCreators=true) |
| `Rain` | 빗소리 (반복) | [rain loop](https://create.roblox.com/store/audio?keyword=rain%20loop&includeOnlyVerifiedCreators=true) |
| `Waves` | 파도 · 바람 (반복) | [ocean waves](https://create.roblox.com/store/audio?keyword=ocean%20waves&includeOnlyVerifiedCreators=true) |
| `Cannon` | 대포 "펑" | [cannon](https://create.roblox.com/store/audio?keyword=cannon&includeOnlyVerifiedCreators=true) |
| `Splash` | 물에 "첨벙" | [water splash](https://create.roblox.com/store/audio?keyword=water%20splash&includeOnlyVerifiedCreators=true) |
| `Hit` | 포탄 명중 "퍽" | [flesh hit](https://create.roblox.com/store/audio?keyword=flesh%20hit&includeOnlyVerifiedCreators=true) |
| `Coins` | 금화 쏟아지는 소리 | [coins](https://create.roblox.com/store/audio?keyword=coins&includeOnlyVerifiedCreators=true) |
| `Dragon` | 해적이 튀어나올 때 비명 | [scream](https://create.roblox.com/store/audio?keyword=scream&includeOnlyVerifiedCreators=true) |
| `Impact` | 칼이 통에 "탁" | [knife stab](https://create.roblox.com/store/audio?keyword=knife%20stab&includeOnlyVerifiedCreators=true) |
| `Win` | 승리 팡파르 | [victory](https://create.roblox.com/store/audio?keyword=victory&includeOnlyVerifiedCreators=true) |

- `Lobby` · `Match` · `Dragon` · `Impact` · `Win` 은 `assets/audio` 폴더의 WAV를 올려서 써도 됩니다.
- 무료 효과음 사이트(Pixabay 등)와 올리는 법: [Phase 12 안내](Phase12_에셋_상품_안내_KO.md) 1장

## 6. 공개 전 설정 (공개할 때)

- [ ] 게임 이름 · 설명 쓰기 (영어 설명도 함께 쓰면 해외 사용자가 들어옵니다)
- [ ] 최대 서버 인원, 장르, 기기(PC · 휴대폰 · 콘솔) 설정
- [ ] **콘텐츠 성숙도 설문** 작성 (Creator Hub → 게임 → 성숙도 · 규정 준수)
  - 해골 · 해적 놀람 연출, 번개, 화면 흔들림이 있습니다.
- [ ] Creator Hub **자동 번역은 영어에 켜지 않기** (게임이 직접 영어를 넣습니다)
- [ ] `tests/StudioSmoke.server.lua` 를 넣어 봤다면 지우기
- [ ] `GameConfig.World.StudioStartPhase` 가 `nil`, `StudioTimeScale` 이 `1` 인지 확인
- [ ] 친구 몇 명과 비공개로 먼저 해 보기 → 괜찮으면 공개

**선택 (나중에 해도 됨)**
- 배지 12개 만들기 (하루 5개 무료): [Phase 12 안내](Phase12_에셋_상품_안내_KO.md) 4장
- 빗줄기 그림, 해적 모델 교체 (`CustomPirate`)

## 7. 보내 주실 것 — 한 번에 복사해서 채우기

```
[개발자 상품]
coins_small =
coins_medium =
coins_large =
coins_huge =
coins_vault =
starter =
(방해 아이템을 팔 경우) ink= shake= hurry= scramble= roar=

[게임패스]
VIP =
Booster =

[그림]
Attendance =
Roulette =
ShopImage =

[소리]
Slam =
WoodCrack =
KrakenRoar =
Thunder =
Lobby =
Match =
Night =
Storm =
Rain =
Waves =
Cannon =
Splash =
Hit =
Coins =
Dragon =
Impact =
Win =

[그래픽 — 선택] (찾는 법: Phase14 문서의 "3D 모델 ID")
Pattern = (assets/ui/pattern_tile.png 를 올린 ID)
칼 스킨 id = MeshId / TextureId   예) gold = 123 / 456
통 스킨 id = MeshId / TextureId
Cannon = MeshId / TextureId

[배지 — 선택]
first_win= win10= win50= catch50= catch250= streak3= streak7= games100= cannon100= raid10= crew5= tourney34=
```
