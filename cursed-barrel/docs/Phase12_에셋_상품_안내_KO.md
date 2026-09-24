# Phase 12 — 받아 오실 음원 · 에셋, 상품 ID 만드는 법

> ⚠️ **상품 가격은 [할일 총정리](할일_총정리_KO.md) 3장이 기준입니다** (게임 코드 `GameConfig.lua` 와 같은 값). 이 문서의 예전 사본에 다른 가격이 있으면 그 가격은 쓰지 마세요.

이 문서에 **직접 해 주셔야 하는 것**을 모두 모았습니다.
ID를 모두 넣지 않아도 게임은 돌아갑니다.
- 음원 ID가 0이면 Roblox 기본 효과음으로 대신 소리를 냅니다. (천둥 · 쾅 · 대포 · 물 튀는 소리 등)
- 상품 ID가 0이면 상점에 "준비 중"으로만 보입니다.

> ⚠️ **중요: 파일을 저에게 보내 주셔도 제가 Roblox에 올릴 수는 없습니다.**
> 저는 게임 주인의 Roblox 계정에 들어갈 수 없습니다. 그래서 음원은 **내 계정으로 Roblox에 올린 뒤 나오는 "숫자 ID"** 가 필요합니다.
> 숫자만 보내 주시면 코드에 넣는 일은 제가 하겠습니다. (직접 넣으셔도 됩니다. 넣을 자리는 아래 표에 적었습니다.)

---

## 1. 음원 · 효과음

### 가장 쉬운 방법: Roblox 안에 이미 있는 소리 쓰기 (추천)

내려받거나 올릴 필요가 없습니다. 심사를 기다릴 필요도 없습니다.

1. Roblox Studio에서 게임을 엽니다.
2. 위 메뉴 **보기(View) → 도구 상자(Toolbox)** 를 엽니다.
3. **Creator Store** 탭에서 종류를 **오디오(Audio)** 로 바꿉니다.
4. 아래 표의 검색어로 찾습니다. ▶ 버튼으로 들어 볼 수 있습니다.
5. 마음에 드는 소리를 **오른쪽 클릭 → "Copy Asset ID"** 로 숫자를 복사합니다.
6. 그 숫자를 저에게 보내 주세요. 예: `Thunder = 1234567890`

인터넷 창에서 보셔도 됩니다. 아래 표의 **Roblox** 링크를 누르면 검색 결과가 바로 열립니다.
검증된 제작자(Roblox와 계약한 음원사 포함)만 보이도록 해 두었습니다.

- 음악(로비 · 게임 · 밤 · 폭풍)은 **꼭 이 방법을 쓰세요.** 밖에서 받은 음악을 올리면 저작권 검사에 걸려 막힐 수 있습니다.
- Creator Store 오디오는 Roblox 게임 안에서 무료로 쓸 수 있습니다. 자세한 내용: [Audio assets 문서](https://create.roblox.com/docs/audio/assets)

### 두 번째 방법: 무료 사이트에서 받아서 올리기 (효과음만)

- **Pixabay**: 상업적 사용 가능, 출처 표시 필요 없음 ([라이선스 요약](https://pixabay.com/service/license-summary/)). 가입 없이 받을 수 있습니다.
- **Freesound**: 로그인해야 받을 수 있습니다. 검색한 뒤 오른쪽 "Licenses"에서 **Creative Commons 0** 만 고르세요. (CC0는 조건 없이 쓸 수 있습니다) [Freesound 도움말](https://freesound.org/help/faq/)

받은 파일을 Roblox에 올리는 법:
1. Studio → **보기(View) → 에셋 관리자(Asset Manager)** → **가져오기(Import / Bulk Import)** 를 누르고 파일을 고릅니다.
   Creator Hub 웹사이트의 대시보드에서도 올릴 수 있습니다.
2. 파일 조건:
   - .mp3 · .ogg · .wav · .flac
   - 20MB 이하, 7분 이하
   - 신분 인증 계정은 30일에 2,000개, 인증하지 않은 계정은 100개까지 무료
3. 심사가 끝나면(보통 몇 분) 에셋 관리자에서 **오른쪽 클릭 → Copy Asset ID** 로 숫자를 복사합니다.
4. 게임을 **그룹**이 소유하고 있다면 음원도 그 그룹으로 올려야 소리가 납니다. 개인 계정으로 올렸다면 음원 권한에서 그 게임을 허용해 주세요.

공식 설명: [Audio assets (Roblox 문서)](https://create.roblox.com/docs/audio/assets)

### 필요한 소리 목록 (`ReleaseConfig.lua` 의 `C.Audio`)

★ 표시는 크라켄이 "쾅" 하고 치는 느낌에 가장 중요한 소리입니다. 먼저 채우시길 추천합니다.

| 칸 이름 | 어떤 소리 | 길이 · 반복 | Roblox에서 찾기 | Pixabay에서 찾기 |
|---|---|---|---|---|
| ★ `Slam` | 문어 다리가 갑판을 내려치는 둔탁하고 큰 "쾅" | 1~2초 | [heavy impact](https://create.roblox.com/store/audio?keyword=heavy%20impact&includeOnlyVerifiedCreators=true) | [heavy impact](https://pixabay.com/sound-effects/search/heavy%20impact/) |
| ★ `WoodCrack` | 나무 판자가 쩍 갈라지는 소리 | 1~2초 | [wood break](https://create.roblox.com/store/audio?keyword=wood%20break&includeOnlyVerifiedCreators=true) | [wood crack](https://pixabay.com/sound-effects/search/wood%20crack/) |
| ★ `KrakenRoar` | 거대한 바다 괴물의 낮은 울음 (습격 시작) | 2~4초 | [monster roar](https://create.roblox.com/store/audio?keyword=monster%20roar&includeOnlyVerifiedCreators=true) | [sea monster](https://pixabay.com/sound-effects/search/sea%20monster/) |
| ★ `Thunder` | 가까이서 치는 천둥 | 3~6초 | [thunder](https://create.roblox.com/store/audio?keyword=thunder&includeOnlyVerifiedCreators=true) | [thunder](https://pixabay.com/sound-effects/search/thunder/) |
| `Rain` | 빗소리 | 반복되는 20초 이상 | [rain loop](https://create.roblox.com/store/audio?keyword=rain%20loop&includeOnlyVerifiedCreators=true) | [rain](https://pixabay.com/sound-effects/search/rain/) |
| `Waves` | 파도 · 바람 (배경) | 반복되는 20초 이상 | [ocean waves](https://create.roblox.com/store/audio?keyword=ocean%20waves&includeOnlyVerifiedCreators=true) | [ocean waves](https://pixabay.com/sound-effects/search/ocean%20waves/) |
| `Cannon` | 대포 발사 "펑" | 1~2초 | [cannon](https://create.roblox.com/store/audio?keyword=cannon&includeOnlyVerifiedCreators=true) | [cannon](https://pixabay.com/sound-effects/search/cannon/) |
| `Splash` | 포탄이 바다에 빠지는 "첨벙" | 1초 | [water splash](https://create.roblox.com/store/audio?keyword=water%20splash&includeOnlyVerifiedCreators=true) | [water splash](https://pixabay.com/sound-effects/search/water%20splash/) |
| `Hit` | 포탄이 살덩이에 맞는 "퍽" | 1초 이하 | [flesh hit](https://create.roblox.com/store/audio?keyword=flesh%20hit&includeOnlyVerifiedCreators=true) | [punch impact](https://pixabay.com/sound-effects/search/punch%20impact/) |
| `Coins` | 금화가 쏟아지는 소리 | 1~2초 | [coins](https://create.roblox.com/store/audio?keyword=coins&includeOnlyVerifiedCreators=true) | [coins](https://pixabay.com/sound-effects/search/coins/) |
| `Storm` | 폭풍 · 크라켄 습격 음악 (북 · 긴박) | 반복 음악 | [epic battle](https://create.roblox.com/store/audio?keyword=epic%20battle&includeOnlyVerifiedCreators=true) | (음악은 Roblox에서) |
| `Night` | 밤 · 안개 로비 음악 (으스스, 조용) | 반복 음악 | [dark ambient](https://create.roblox.com/store/audio?keyword=dark%20ambient&includeOnlyVerifiedCreators=true) | (음악은 Roblox에서) |
| `Lobby` | 낮 로비 음악 (해적 · 바다 분위기) | 반복 음악 | [pirate](https://create.roblox.com/store/audio?keyword=pirate&includeOnlyVerifiedCreators=true) | (음악은 Roblox에서) |
| `Match` | 테이블 게임 중 긴장 음악 | 반복 음악 | [suspense](https://create.roblox.com/store/audio?keyword=suspense&includeOnlyVerifiedCreators=true) | (음악은 Roblox에서) |
| `Dragon` | 해적이 튀어나올 때 비명 · 포효 | 1~2초 | [scream](https://create.roblox.com/store/audio?keyword=scream&includeOnlyVerifiedCreators=true) | [monster scream](https://pixabay.com/sound-effects/search/monster%20scream/) |
| `Impact` | 칼이 나무통에 "탁" 꽂히는 소리 | 1초 이하 | [knife stab](https://create.roblox.com/store/audio?keyword=knife%20stab&includeOnlyVerifiedCreators=true) | [knife wood](https://pixabay.com/sound-effects/search/knife%20wood/) |
| `Win` | 승리 팡파르 | 2~4초 | [victory](https://create.roblox.com/store/audio?keyword=victory&includeOnlyVerifiedCreators=true) | [victory fanfare](https://pixabay.com/sound-effects/search/victory%20fanfare/) |

- `Lobby` · `Match` · `Dragon` · `Impact` · `Win` 은 `assets/audio` 폴더에 제가 만든 WAV가 이미 있습니다. 그걸 올리셔도 됩니다. 더 좋은 소리를 찾으시면 바꾸세요.
- 검색 결과가 적으면 링크 끝의 `&includeOnlyVerifiedCreators=true` 를 지우고 다시 찾아보세요.
- 소리가 너무 크거나 작으면 숫자와 함께 알려 주세요. 코드에서 크기를 맞춰 드립니다.

### 보내 주실 형식 (복사해서 숫자만 채워 주세요)

```
Slam =
WoodCrack =
KrakenRoar =
Thunder =
Rain =
Waves =
Cannon =
Splash =
Hit =
Coins =
Storm =
Night =
Lobby =
Match =
Dragon =
Impact =
Win =
```

---

## 2. 선택 에셋 (안 해도 됩니다)

| 무엇 | 넣는 곳 | 설명 |
|---|---|---|
| 빗줄기 이미지 | `ReleaseConfig.lua` → `C.Textures.Rain` | 0이면 기본 입자를 길게 늘여서 비를 만듭니다. 세로로 긴 흰 빗줄기 PNG(배경 투명)를 에셋 관리자로 올리고 **이미지 ID**를 주세요. (데칼 ID는 안 됩니다. 헷갈리면 이미지 링크를 보내 주시면 됩니다) |
| 해적 모델 | `ReplicatedStorage > CursedBarrel > Visuals > CustomPirate` | Phase 11 문서 5장 "에셋을 받아서 넣고 싶다면" 참고. 모델 안의 Script는 반드시 지우세요. |
| 크라켄 | — | 크라켄은 코드로 만들어서 에셋이 필요 없습니다. 움직임 · 내려치기 · 먹물이 모두 코드입니다. |

---

## 3. 상품 ID 만드는 법

먼저 게임을 **한 번 공개(Publish)** 해 두어야 상품을 만들 수 있습니다. (공개 설정은 비공개여도 됩니다)
아래는 Roblox 공식 문서의 순서입니다. 메뉴 이름은 영어로 보일 수 있어 영어도 함께 적었습니다.

### 3-1. 개발자 상품 (Developer Product) — 여러 번 살 수 있는 것

코인 묶음, 로벅스 스킨, 스타터 팩, 방해 아이템이 여기에 해당합니다.

1. [create.roblox.com](https://create.roblox.com/) 에 로그인 → **Creations(내 작품)** → 이 게임을 누릅니다.
2. 왼쪽 메뉴 **Monetization(수익 창출) → Developer Products(개발자 상품)** → **Create developer product** 를 누릅니다.
3. 아이콘 이미지를 올립니다. (512×512 이하, .jpg / .png / .bmp)
4. 이름 · 설명 · 가격(로벅스)을 적고 저장합니다. 가격은 아래 표의 추천 가격을 쓰시면 됩니다.
5. 목록에서 상품 그림에 마우스를 올리면 **⋯ 버튼**이 생깁니다. 누른 뒤 **Copy Asset ID** 로 숫자를 복사합니다.
6. 그 숫자를 아래 표의 "넣는 곳"에 넣습니다. (또는 저에게 보내 주세요)

공식 문서: [Developer Products](https://create.roblox.com/docs/production/monetization/developer-products)

### 3-2. 게임패스 (Pass) — 한 번 사면 영원히 갖는 것

VIP 선장 패스, 현상금 부스터가 여기에 해당합니다.

1. 같은 게임 페이지에서 **Monetization → Passes** → **Create pass** 를 누릅니다.
2. 아이콘(512×512 이하), 이름, 설명을 넣고 만듭니다.
3. 만든 패스를 눌러 **Sales(판매)** 로 들어갑니다. **Item for Sale** 을 켜고 가격을 적은 뒤 저장합니다. ← 이걸 안 켜면 살 수 없습니다.
4. Passes 목록에서 **⋯ → Copy Asset ID** 로 숫자를 복사합니다.

공식 문서: [Passes](https://create.roblox.com/docs/production/monetization/passes)

### 3-3. 배지 (Badge) — 선택

1. Creator Hub 대시보드에서 게임 그림에 마우스를 올리고 **⋯ → Create Badge** 를 누릅니다.
2. 이미지(512×512 권장, 동그랗게 잘립니다), 이름, 설명을 넣습니다.
   - 게임마다 하루(GMT 기준) 5개까지는 무료입니다.
   - 그보다 많이 만들면 하나에 100 로벅스입니다.
3. **Engagement(참여) → Badges** 에서 **⋯ → Copy Asset ID** 로 숫자를 복사합니다.

공식 문서: [Badges](https://create.roblox.com/docs/production/publishing/badges)

---

## 4. 만들어야 할 상품 전체 표

파일 위치:
- `GameConfig.lua` = `game/ReplicatedStorage/CursedBarrel/Shared/GameConfig.lua`
- `ReleaseConfig.lua` = 같은 폴더의 `ReleaseConfig.lua`

> ★ Phase 13 에서 바뀐 최신 표입니다. 스킨은 코인으로만 사고, 로벅스로는 코인을 충전합니다. (자세한 이유: [Phase 13 문서](Phase13_돈_출석_룰렛_영어_KO.md) 1장)

### 개발자 상품 11개 (최신 전체 목록은 [할일 총정리](할일_총정리_KO.md) 3장)

| 상품 | 추천 가격 | 넣는 곳 (`GameConfig.lua`) |
|---|---|---|
| 코인 충전 소 · 15,000 코인 | 159 R$ | `Products.Coins` 의 `coins_small` 줄 `productId` |
| 코인 충전 중 · 30,000 코인 | 319 R$ | `Products.Coins` 의 `coins_medium` 줄 `productId` |
| 코인 충전 대 · 70,000 코인 | 369 R$ | `Products.Coins` 의 `coins_large` 줄 `productId` |
| 코인 충전 특대 · 160,000 코인 | 799 R$ | `Products.Coins` 의 `coins_huge` 줄 `productId` |
| 코인 충전 금고 · 500,000 코인 | 1,999 R$ | `Products.Coins` 의 `coins_vault` 줄 `productId` |
| 선원 스타터 팩 (계정당 1회) | 99 R$ | `Products.Starter.productId` |
| 먹물 한 통 (방해) | 15 R$ | `Sabotage.Items` 의 `ink` 줄 `productId` |
| 흔들리는 손 (방해) | 25 R$ | `Sabotage.Items` 의 `shake` 줄 `productId` |
| 저주의 재촉 (방해) | 35 R$ | `Sabotage.Items` 의 `hurry` 줄 `productId` |
| 뒤섞인 번호 (방해) | 45 R$ | `Sabotage.Items` 의 `scramble` 줄 `productId` |
| 해적의 포효 (방해) | 55 R$ | `Sabotage.Items` 의 `roar` 줄 `productId` |

- 방해 아이템은 상대에게 영향을 줍니다. 공정성 논란이 생길 수 있으니 **팔지 말지 먼저 정하세요.** 안 팔려면 ID를 0으로 두면 됩니다.
- 표의 가격과 Creator Hub에 적은 가격이 **같아야** 합니다. 상점에 보이는 숫자는 코드의 `robux`, 실제 결제는 Creator Hub 가격입니다.
- 예전 표에 있던 "잿불 칼 · 잿불 유령 · 잿불 강타 · 폭풍의 군주" 로벅스 스킨은 이제 코인 스킨이라 **만들지 않아도 됩니다.**

### 게임패스 2개

| 패스 | 추천 가격 | 넣는 곳 (`GameConfig.lua`) |
|---|---|---|
| VIP 선장 패스 | 399 R$ | `Products.GamePasses.VIP.gamePassId` |
| 현상금 부스터 | 249 R$ | `Products.GamePasses.Booster.gamePassId` |

### 배지 12개 (선택)

`ReleaseConfig.lua` 의 `C.Badges` 에 넣습니다. 0이면 배지를 주지 않고 넘어갑니다.

| 칸 | 조건 |
|---|---|
| `first_win` · `win10` · `win50` | 첫 승리 · 10승 · 50승 |
| `catch50` · `catch250` | 해적 50번 · 250번 잡기 |
| `streak3` · `streak7` | 3연승 · 7연승 |
| `games100` | 100판 참가 |
| **`cannon100`** | 대포로 크라켄 100번 맞히기 (Phase 12) |
| **`raid10`** | 크라켄 습격 10번 물리치기 · 칭호 「크라켄 사냥꾼」 (Phase 12) |
| **`crew5`** | 친구 · 파티와 같은 판에서 5번 우승 · 칭호 「선원 동료」 (Phase 12) |
| **`tourney34`** | 토너먼트 시리즈 34점 이상 · 칭호 「토너먼트 챔피언」 (Phase 12) |

하루 5개까지 무료이니, 며칠에 나눠 만드시면 로벅스가 들지 않습니다.

### 보내 주실 형식 (복사해서 숫자만 채워 주세요)

```
coins_small =
coins_medium =
coins_large =
coins_huge =
coins_vault =
starter =
ink =
shake =
hurry =
scramble =
roar =
VIP (게임패스) =
Booster (게임패스) =
배지: first_win= win10= win50= catch50= catch250= streak3= streak7= games100= cannon100= raid10= crew5= tourney34=
```

---

## 5. 넣은 뒤 확인할 것

1. **상품**: 비공개 서버에서 하나씩 사 봅니다.
   - Studio 안에서 산 것은 실제 로벅스가 나가지 않는 테스트 결제입니다.
   - 확인할 것: 코인이 한 번만 들어오는지, 스킨이 바로 장착되는지, 다시 들어와도 남아 있는지.
2. **게임패스**:
   - VIP: 코인 +20%, 머리 위 표시.
   - 부스터: 이긴 판 현상금 +10%, 상점에 "보유 중" 표시.
   - 산 직후 바로 적용되는지 봅니다.
3. **음원**:
   - 폭풍이 올 때 음악이 바뀌는지, 천둥 · 쾅 · 대포 소리가 나는지 봅니다.
   - 설정의 효과음 크기를 줄이면 같이 줄어드는지 봅니다.
   - 빠르게 보려면 `GameConfig.World.StudioStartPhase = "storm"` 으로 두고 Play를 누르세요. 확인한 뒤에는 `nil` 로 되돌립니다.
