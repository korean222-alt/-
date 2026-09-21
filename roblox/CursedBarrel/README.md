# 저주받은 통 · Phase 2

Phase 1(테이블 참가 시스템) 위에 **카운트다운 → 라운드 시작 → 턴 순서**를 얹은 단계입니다.
폴더 이름, 스크립트 이름, 기존 구조는 Phase 1 그대로 두고 필요한 부분만 더했습니다.

## 설치 (Studio에서 한 번만)

1. Studio에서 Play/Run을 **멈춘 상태**로 둡니다. (편집 모드)
2. `build/CursedBarrel_Phase2_Install.lua` 전체를 복사합니다.
3. Studio 하단 **Command Bar**에 붙여넣고 Enter.

외부 다운로드, HTTP 허용, LoadStringEnabled, 플러그인 모두 필요 없습니다.
기존 스크립트와 교체되는 항목은 전부 `ServerStorage/CursedBarrel_Backup_<날짜>` 로 백업되고,
설치 중 오류가 나면 원래 상태로 되돌립니다. (Ctrl+Z 로도 한 번에 취소됩니다)

설치 스크립트 맨 위의 스위치로 범위를 조절할 수 있습니다.

| 스위치 | 기본값 | 설명 |
| --- | --- | --- |
| `APPLY_LIGHTING` | `true` | 로비 조명을 밝게 바꾼다 |
| `REBUILD_MAP` | `true` | 로비 맵 + 테이블 6개를 새로 만든다. `false` 면 스크립트만 갱신 |
| `REPLACE_SPAWN` | `true` | 기존 SpawnLocation을 백업하고 로비 스폰만 남긴다 |
| `TABLE_LAYOUT` | 6개 | 테이블 이름/종류/위치 목록. 줄을 더하거나 지우면 그대로 반영 |

## Phase 2에서 달라진 것

| 요청 | 처리한 곳 |
| --- | --- |
| 1. 인원이 모이면 카운트다운 시작 | `RoundService` · `Round:_startCountdown` |
| 2. 인원이 줄면 카운트다운 즉시 취소 | `RoundService` · `Round:_cancelCountdown` |
| 3. 현황판에 남은 시간 표시 | `TableController` · 큰 숫자 + 게이지 |
| 4. 카운트다운 종료 → 참가자 확정 → `Playing` | `RoundService` · `Round:_beginRound` |
| 5. 턴 순서를 서버에서 무작위 결정 | `Utility.shuffle` + 서버 전용 `Random` |
| 6. 현재 차례를 테이블 Attribute로 표시 | `CurrentTurnUserId` / `CurrentTurnName` / `TurnIndex` |
| 7. 시작 후 새 참가자 차단 | `GameConfig.JoinableStates` + `GameTable:_refresh` |
| 8. 퇴장·리셋 시 참가자/턴 정리 | `Round:RemoveParticipant` |
| 9. 테이블마다 독립 진행 | 테이블 1개 = `GameTable` 1개 + `Round` 1개 |
| 10. 칼 슬롯·위험 판정·탈락·승리 | 구현하지 않음 (Phase 3) |

판정과 상태 변경은 전부 서버에서만 일어납니다.
클라이언트는 테이블 Attribute를 **읽기만** 하며, RemoteEvent가 하나도 없습니다.

### 최소 인원(`MinPlayers`) 안내

요청에 "1명 이상이면 시작"과 "2명 미만이면 취소"가 함께 있어서, **한 개의 값**으로 통일했습니다.

- `MinPlayers` 이상이 앉으면 카운트다운 시작
- `MinPlayers` 아래로 떨어지면 즉시 취소

기본값은 혼자서도 테스트할 수 있게 **1**입니다.
출시할 때처럼 "2명 미만이면 취소"로 만들려면 `Shared/TableConfig` 의 `MinPlayers` 를 `2` 로 바꾸면 됩니다.
그 한 곳만 고치면 서버 판정, 현황판 문구, 라운드 정리가 전부 따라옵니다. (테스트 7번에서 2로 두고도 검증했습니다)

### 조명

로비는 스킨/디자인 전시장이라 **밝게** 두고, **내가 앉은 테이블의 게임이 시작될 때만** 어두워집니다.

- 조명 변경은 `LightingController`(클라이언트)가 내 화면에서만 수행합니다.
  옆 테이블에서 게임이 시작돼도 로비 손님 화면은 밝은 그대로입니다.
- 밝기 값은 `GameConfig.Lighting.Lobby` / `.Game` 에 모여 있습니다. 숫자만 바꾸면 분위기가 바뀝니다.
- 테이블 랜턴은 로비에서는 장식이지만, 어두워지면 조명 역할을 합니다.

### 맵

한 방에 테이블 6개(4인 4개 + 2인 2개), 전시용 좌대 5개와 간판, 안내판, 로비 스폰이 들어갑니다.
전시 좌대의 `DisplayAnchor_01~05` 위에 판매할 의자/스킨 모델을 올리면 됩니다.

## 파일

```
src/
  Shared/GameConfig.lua              상수 · Attribute 이름 · 조명 프리셋
  Shared/TableConfig.lua             테이블 종류별 규칙 (MinPlayers, 카운트다운, 턴 시간)
  Shared/Utility.lua                 Cleaner · Signal · RateLimiter · shuffle
  Services/GameTable.lua             테이블 1개 = 좌석/착석 관리
  Services/TableService.lua          태그 달린 테이블 자동 등록/해제
  Services/RoundService.lua          ★ Phase 2 핵심 (카운트다운 · 라운드 · 턴)
  Main.server.lua                    서버 진입점
  Controllers/TableController.client.lua    현황판 UI
  Controllers/LightingController.client.lua ★ 로비 밝음 / 게임 중 어두움
```

Studio 안에서의 위치는 Phase 1과 같습니다.

```
ReplicatedStorage/CursedBarrel/Shared/   GameConfig, TableConfig, Utility
ServerScriptService/CursedBarrel/        Main
ServerScriptService/CursedBarrel/Services/  GameTable, TableService, RoundService
StarterPlayer/StarterPlayerScripts/Controllers/  TableController, LightingController
Workspace/GameTables/                    Table_A ~ Table_F
Workspace/Lobby/                         바닥 · 벽 · 전시 구역 · 안내판 · 스폰
```

## 테이블 Attribute (클라이언트가 읽는 값)

| 이름 | 뜻 |
| --- | --- |
| `State` | `Waiting` / `Countdown` / `Playing` … |
| `SeatedCount` / `SeatCount` / `MinPlayers` | 현재 인원 / 좌석 수 / 최소 인원 |
| `CountdownEndsAt` | 카운트다운이 끝나는 **서버 시각** (0이면 없음) |
| `CountdownDuration` | 이번 카운트다운 전체 길이 |
| `RoundId` / `ParticipantCount` | 몇 번째 라운드 / 확정된 참가자 수 |
| `TurnIndex` / `TurnCount` | 현재 몇 번째 차례 / 남은 인원 |
| `CurrentTurnUserId` / `CurrentTurnName` | 현재 차례인 플레이어 |
| `TurnEndsAt` | 이번 턴 제한시간이 끝나는 서버 시각 |

좌석에는 `SeatIndex`, `OccupantUserId`, `TurnOrder`(이번 라운드 순번, 0이면 참가자 아님)가 기록됩니다.

남은 시간을 매 초 보내지 않고 "끝나는 시각" 하나만 기록합니다.
클라이언트가 `workspace:GetServerTimeNow()` 로 빼서 그리기 때문에 네트워크 부담 없이 부드럽게 흐릅니다.

## 점검 결과

Studio 없이도 서버 로직을 그대로 돌려볼 수 있게 Roblox API를 흉내 낸 환경을 만들어 두었습니다.

```bash
python3 tools/build_installer.py                # 설치 스크립트 생성
python3 tools/run_tests.py <luau 실행파일>       # 시나리오 102개 실행
python3 tools/check_layout.py                   # 맵 배치가 겹치지 않는지 계산
```

`luau` 실행파일은 <https://github.com/luau-lang/luau/releases> 에서 받을 수 있습니다.

검증한 시나리오: 부팅 / 1명 참가 후 카운트다운 / 도중 이탈 시 취소 / 재참가 시 새 카운트다운 /
시작 후 빈 의자 차단(익스플로잇 포함) / 턴 무작위 배정과 턴 넘김 / 캐릭터 리셋 · 접속 종료 /
`MinPlayers=2` 설정 / 테이블 복제와 독립 진행 / 테이블 제거 시 정리 / 턴 순서 분포.

## Phase 3에서 이어붙일 자리

- `Round:AdvanceTurn()` — 칼을 뽑은 뒤 다음 차례로 넘기는 지점
- `Round:RemoveParticipant(player)` — 탈락 처리에 그대로 쓸 수 있음
- `Round:_finishRound(reason)` — 지금은 정리만. 여기에 승자 발표가 들어감
- `States.Starting` / `States.RoundEnding` — 연출용으로 비워 둔 상태값
- `TableConfig` 의 `KnifeSlots` / `DangerSlots` — 칼 슬롯 수와 위험 슬롯 수
