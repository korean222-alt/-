# 해적 통 찌르기 — Phase 39 : 들어오면 바로 진짜 판

원본 : `CursedBarrel_Phase38_5_tutorialfix.rbxl`
수정본 : `CursedBarrel_Phase39_quickstart.rbxl` (스크립트 13개만 바뀜 · 파트 · 모델 · 설정은 원본 그대로)
코드 차이 전체 : `phase39.diff`

## 왜 고쳤나

- 평균 플레이 2.5분, 1일 유지율 7%.
- 새로 온 사람은 이런 순서를 거쳤습니다.
  1. 환영 창에서 최대 15초 대기
  2. 필수 튜토리얼 (해적 3종을 모두 잡아야 끝남)
  3. 끝나기 전에는 다른 테이블에 앉을 수 없음
- 그래서 대부분 진짜 판을 한 번도 못 해 보고 나갔습니다.

## 바뀐 것

### 1. 필수 튜토리얼 없음 → 들어오면 바로 진짜 판
- 처음 온 사람(판 수 0)은 자료를 읽고 캐릭터가 서면 약 1초 뒤 자동으로 테이블에 앉습니다.
  - 사람이 기다리는 작은 테이블(4인 이하)이 있으면 그쪽에 앉습니다. AI가 앉은 자리는 AI가 비켜 줍니다.
  - 그런 테이블이 없으면 가장 가까운 빈 2인 테이블에 앉고, AI 한 명이 1초 안에 앉은 뒤 3초 후 시작합니다.
- 해적 종류는 원래 있던 "처음 보는 해적 설명 카드"와 "신입 보호"(첫 5판은 한 번 놓쳐도 다시 기회)가 가르칩니다.
- 환영 창은 6초가 지나도 못 앉았을 때만 뜹니다. 버튼은 「튜토리얼 시작」 대신 「바로 시작!」입니다.
- 「튜토리얼 다시 하기」(항해 수첩)는 원하는 사람만 하는 연습 판으로 남겨 두었습니다.
- 관련 파일 : `OnboardingService`(새로 씀), `BotService`(`FillSoon`), `ReleaseService`(`quickStart`), `Phase4Controller`(환영 창), `GameConfig`(`Onboarding` · `Tutorial.Mandatory = false`)

### 2. 기다리는 시간 줄이기

| 항목 | 전 | 후 |
|---|---|---|
| 혼자 앉은 뒤 AI가 오기까지 (`Bots.FillDelay`) | 10초 | 3초 |
| 방장이 시작을 안 누를 때 자동 시작 (`Lobby.WaitForHost`) | 30초 | 12초 |
| 자리가 다 찼을 때 카운트다운 (`Lobby.FullCountdown`) | 5초 | 3초 |
| AI 생각 시간 (`Bots.ThinkMin~Max`) | 1.1~2.8초 | 0.7~1.6초 |
| 안전한 자리 뒤 다음 차례까지 (`Timing.ResultHold`) | 2.2초 | 1.6초 |
| 해적 잡기 결과 뒤 다음 차례까지 (`Catch.Hold`) | 1.6초 | 1.2초 |
| 판이 끝나고 다음 판 대기까지 (`Timing.RoundEndDuration`) | 5초 | 3.5초 |
| 운명 카드 보여 주는 시간 (`FateCards.RevealTime`) | 3.4초 | 2.4초 (화면 카드도 맞춰서 줄임) |

### 3. 처음 두 판은 단순하게 (`GameConfig.Onboarding.SimpleGames = 2`)
- 해적은 보통과 쌍둥이만 나옵니다. 해골 유령, 갈고리, 욕심쟁이, 분노한 해적은 3번째 판부터 나옵니다.
- 처음 두 판 중인 사람이 앉은 판에서는 운명 카드를 뽑지 않습니다.
- 상점, 퀘스트, 방해, 출석, 룰렛, 코드 버튼을 숨깁니다. 항해 수첩과 설정만 보입니다.
- 출석판 자동 열기는 두 판이 끝난 뒤로 미룹니다.
- 내 차례마다 "내 차례! 아래 칼 버튼 중 아무거나 하나 눌러요" 안내가 뜹니다.

### 4. 분석
- `ReleaseConfig.Version = "39.0.0"`
  - 맞춤 이벤트의 CustomField02에 실리므로 수정 전과 후를 나눠 볼 수 있습니다.
- 온보딩 퍼널 단계 이름
  - 전 : `1 Joined · 2 TutorialStarted · 3 FirstPirate · 4 TutorialDone · 5 FirstGameFinished · 6 SecondGameFinished`
  - 후 : `1 Joined · 2 FirstSeated · 3 FirstPirate · 4 FirstCatch · 5 FirstGameFinished · 6 SecondGameFinished`
- 새 맞춤 이벤트 `FirstGameQuit`
  - 첫 판을 끝내기 전에 나간 사람을 기록합니다.
  - 값은 들어온 뒤 몇 초 만에 나갔는지입니다.
  - 필드1은 `seated`(앉아 보기는 함) 또는 `never_seated`입니다.

## 반영 방법 (PC의 Roblox Studio)

1. 지금 게임을 Studio에서 열고 **파일 → 다른 이름으로 저장**으로 백업을 하나 남겨 둡니다.
2. `CursedBarrel_Phase39_quickstart.rbxl`을 Studio로 엽니다.
3. **테스트 → 플레이**로 확인합니다.
   - 새 유저처럼 시작하려면 **게임 설정 → 보안 → Studio의 API 서비스 접근 허용**을 잠깐 끄고 플레이하세요. 자료가 저장되지 않아 판 수 0으로 시작합니다.
   - 확인할 것 : 스폰 후 1~2초 안에 2인 테이블에 자동으로 앉는지, AI가 곧바로 앉고 3초 뒤 시작하는지, 왼쪽·오른쪽 버튼이 항해 수첩과 설정만 남는지.
4. 확인이 끝나면 API 접근 허용을 다시 켭니다. 그다음 **파일 → Roblox에 게시 →** 기존 게임 "해적 통 찌르기"를 골라 덮어씁니다.

## 코드로 못 한 것 (직접 해야 함)

- **핵심 효과음**
  - `ReleaseConfig.Audio`의 `Impact`(칼 꽂힘), `Dragon`(해적 튀어나옴), `Win`(승리)이 0이라 로블록스 기본 소리(착지음, 폭발음)로 대신 나오고 있습니다.
  - 크리에이터 스토어 → 오디오에서 마음에 드는 효과음을 골라 ID를 복사합니다.
  - `ReplicatedStorage > CursedBarrel > Shared > ReleaseConfig`의 해당 숫자에 넣으면 됩니다.
- **배지**
  - `ReleaseConfig.Badges`가 전부 0입니다.
  - Creator Hub → 이 게임 → 배지에서 "첫 승리", "첫 해적 잡기" 같은 쉬운 배지를 만들고 ID를 넣으세요.
- **썸네일과 아이콘** : 광고 CTR이 약 1%로 낮습니다.
- **영어 검수** : 영어는 사전 조각을 이어 붙이는 방식이라 영어 원어민 검수를 권합니다.

## 다시 고칠 때

- `tools/parse.py 원본.rbxl 폴더` : 스크립트를 `.lua` 파일로 풉니다.
- `tools/patch.py 원본.rbxl 폴더 새파일.rbxl` : 고친 `.lua`를 스크립트 Source에만 다시 넣습니다. 나머지 바이트는 그대로 둡니다.
- 필요 패키지 : `pip install lz4 zstandard`
