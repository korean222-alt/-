# 졸졸 동물 기차 🐥🚂

아기 동물에 닿으면 뒤에 줄지어 따라오고, 농장에 데려다주면 별을 받아 새 섬을 여는
6~12세용 로블록스 게임입니다. (규칙: [CLAUDE.md](CLAUDE.md))

---

## 1. 바로 해 보기 (3분)

1. **`졸졸동물기차.rbxlx`** 파일을 컴퓨터에 내려받습니다.
2. Roblox Studio 를 켜고 **File → Open from File…** 에서 그 파일을 고릅니다.
3. **Play(F5)** 를 누릅니다. 끝입니다. 별도 설치나 설정이 없습니다.

접속하면 이런 순서로 놀 수 있습니다.

| 언제 | 무엇이 보이나 |
| --- | --- |
| 0초 | 초원 섬 스폰. **정면 13스터드 앞에 병아리 1마리**, 그 뒤로 농장이 바로 보임 |
| 1초 | 병아리에 닿으면 "삐약" 소리 + 하트가 터지고 뒤에 졸졸 따라옴 |
| 3초 | 화면 위 기차 칸(●●○○○…)이 채워지고, 화살표가 농장을 가리킴 |
| 6초 | 농장 입구 노란 발판을 밟으면 동물이 폴짝 들어가고 **별 +1** |
| 그 뒤 | 별 8개 → 신발 업그레이드 / 총 별 15개 → 별 문이 열리고 펭귄 섬 |

### 처음 플레이하며 확인할 것

- [ ] 스폰하자마자 병아리와 농장이 눈에 보이는지
- [ ] 동물 3마리를 달고 뛰어도 줄이 끊기거나 벽에 끼지 않는지
- [ ] 3마리 배달 → 별이 정확히 3개 오르는지 (병아리 1개씩)
- [ ] 섬 밖으로 떨어지면 스폰으로 돌아오는지
- [ ] 출력 창(Output)에 빨간 오류가 없는지
- [ ] Studio 의 휴대폰 화면 미리보기(Device → Phone)에서 UI 가 겹치지 않는지

---

## 2. 두 가지만 직접 해 주세요

### (1) 별을 저장하려면 — API 서비스 켜기

Studio 에서 처음 실행하면 출력 창에 이런 안내가 나옵니다.

```
[데이터] 저장 기능을 쓸 수 없습니다: ...
[데이터]   Studio 상단 HOME → Game Settings → Security →
[데이터]   'Enable Studio Access to API Services' 를 켜고 저장(Save)
```

게임을 한 번 **게시(Publish)** 한 뒤 위 설정을 켜면 별·열린 섬·도감·업그레이드가
저장됩니다. 켜지 않아도 게임은 정상으로 돌아가고, 나갔다 오면 별만 0이 됩니다.

### (2) 배경 음악 (원하면)

음악은 저작권 확인이 필요해서 비워 두었습니다.
`ReplicatedStorage/Shared/Config` 에서 한 줄만 바꾸면 스피커 버튼이 자동으로 생깁니다.

```lua
Config.Music = {
    AssetId = "rbxassetid://여기에_ID",  -- 크리에이터 스토어에서 "사용 허용된" 음악
    Volume = 0.2,
}
```

그 밖의 소리(삐약, 별, 폭죽)와 반짝임 파티클은 **로블록스 클라이언트에 기본으로
들어있는 무료 리소스**(`rbxasset://sounds/...`, `rbxasset://textures/particles/...`)를
씁니다. 툴박스의 남의 모델은 악성 스크립트 위험이 있어 하나도 쓰지 않았고,
섬·동물·여우·별문까지 전부 파트를 조합해 코드로 만듭니다.

---

## 3. 무엇이 어디에 들어있나

```
Workspace/
  World/                     ← 서버가 켜질 때 코드로 만들어집니다
    Water, Meadow/, Snow/, Bridge/, StarGate/
    Meadow/Farm/DeliveryZone ← 노란 배달 발판
    Meadow/Shop/Pad_Speed…   ← 업그레이드 발판 3개
  Animals/                   ← 돌아다니는 동물
  Foxes/                     ← NPC 여우

ReplicatedStorage/
  Shared/   Config, Rules, ModelFactory, Sounds, Net
  Client/   Hud, Arrow, Dex, Music, ShopUi, GateClient, ClientEffects, UiKit
  Remotes/  StateUpdate, Effect, RequestState, SetPref

ServerScriptService/
  GameBootstrap            ← 서비스를 순서대로 켜는 시작점
  Services/  DataService, WorldService, AnimalService, FarmService,
             GateService, ShopService, FoxService, StateService,
             Effects, MetricsService

StarterPlayer/StarterPlayerScripts/ClientMain
```

**숫자는 모두 `Shared/Config` 한 곳에서 바꿉니다.** (기차 길이, 별 보상, 간격,
섬 해금 비용, 업그레이드 가격, 여우 수, 동물 종류와 마리 수, 소리, 색)

### 단계별 프롬프트 ↔ 구현 위치

| 단계 | 내용 | 파일 |
| --- | --- | --- |
| 1 | 폴더 구조와 설정값 | `Shared/Config`, `Shared/Rules` |
| 2 | 초원 섬, 농장, 물, 조명 | `WorldService` |
| 3 | 병아리 만들기와 돌아다니기 | `ModelFactory`, `AnimalService` |
| 4 | **닿으면 따라오기 (핵심)** | `AnimalService` (발자취 방식) |
| 5 | 농장 배달과 별 | `FarmService` |
| 6 | 글 없는 화면, 안내 화살표 | `Hud`, `Arrow` |
| 7 | 펭귄 섬과 별 문 | `GateService`, `GateClient` |
| 8 | 저장하기 | `DataService` |
| 9 | 동물 도감 (희귀 동물 포함) | `Dex`, `FarmService` |
| 10 | NPC 여우 기차 | `FoxService` |
| 11 | 업그레이드 상점 | `ShopService`, `ShopUi` |
| 12 | 10초 테스트와 다듬기 | `MetricsService` (출력 창에 시간 측정) |
| 13 | 출시 준비 | [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) |

동물은 섬마다 3종류입니다. 초원 = 병아리(별1) · 오리(별2) · **무지개 토끼(별5, 희귀)**,
펭귄 섬 = 펭귄(별2) · 눈토끼(별3) · **황금 펭귄(별5, 희귀)**.
희귀 동물은 3분에 한 번 1마리만 나타나고 빠르게 도망갑니다.

---

## 4. 코드를 고친 뒤

소스 원본은 `src/` 안의 `.luau` 파일입니다. Studio 안에서 고쳤다면 같은 내용을
`src/` 에도 복사해 두세요(백업). 반대로 `src/` 를 고쳤다면:

```bash
python3 tools/build_place.py     # 졸졸동물기차.rbxlx 와 Install.lua 를 다시 만듭니다
```

이미 만들어 둔 게임에 넣고 싶으면 place 파일 대신 **`Install.lua`** 를 Studio 명령 바
(View → Command Bar)에 붙여넣으면 같은 스크립트가 설치됩니다.

### 자동 검사 (개발용)

Studio 없이 게임 로직을 실제로 실행해 보는 검사가 들어있습니다.
로블록스 API 를 흉내내어 서버를 켜고, 가상의 아이를 걸어가게 해서 동물을 모으고
배달까지 시켜 봅니다. ([luau 실행 파일](https://github.com/luau-lang/luau/releases) 필요)

```bash
LUAU=./luau tools/testkit/run_tests.sh
# → 검사 결과 : 통과 68개 / 실패 0개
```

검사하는 것: 섬·농장·다리·별문 생성, 동물 21마리 스폰, 스폰 앞 첫 동물,
닿으면 따라오기와 간격 유지, 배달 시 별 증가, 이중 보상 방지, 도감 기록,
별 문 통과 제한과 해금, 업그레이드 구매와 별 차감, 저장 후 재접속,
60초 연속 구동, 희귀 동물 등장, 여우 이동, 화면(UI) 생성과 모든 연출 신호.

---

## 5. 알아 두면 좋은 것

- 이 원격 환경에는 Roblox Studio 가 없어서 **Studio 안에서의 눈으로 보는 확인은
  직접 해 주셔야 합니다.** 위 자동 검사로 로직은 확인했지만, 색감·카메라·소리 크기
  같은 감각적인 부분은 플레이해 보고 말씀해 주시면 바로 고쳐 드립니다.
- 실패해도 잃는 것이 없습니다. 별은 업그레이드에만 쓰이고, 섬 해금은 **지금까지 모은
  총 별**로 판단해서 업그레이드를 사도 문이 다시 닫히지 않습니다.
- 여우는 플레이어의 동물을 절대 빼앗지 않고, 주인 없는 동물만 모아 굴에 데려다 놓습니다.
