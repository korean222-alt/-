# 저주받은 통 (CursedBarrel) · Phase 3

`CursedBarrel_Phase3.rbxl` — Roblox Studio 에서 바로 열면 된다. 설치 스크립트를 따로 돌릴 필요가 없다.
Phase 2 파일을 처음부터 다시 만들지 않고, 기존 구조 위에 Phase 3 를 얹었다.

## 게임 규칙 (Phase 3)

1. 의자에 앉으면 최소 인원이 모인 시점에 5초 카운트다운
2. 카운트다운이 끝나면 참가자 확정 · 턴 순서를 서버가 무작위로 섞는다
3. 통 둘레에 칼 슬롯이 채워진다 (4인 테이블 16개 / 2인 테이블 10개)
4. 라운드마다 서버가 "터지는 자리"를 새로 뽑는다 — 이 번호는 **서버 메모리에만** 있다
5. 내 차례에 자리를 하나 고른다 (PC: E 또는 화면 버튼 / 모바일: 탭)
6. 안전하면 다음 사람 차례, 위험하면 그 사람 탈락 (뚜껑이 튀어오르고 통이 붉게 빛난다)
7. 탈락자가 나오면 통을 새 칼로 다시 채우고 위험 자리도 다시 뽑는다
8. 마지막 한 명이 남으면 승리 → 5초 뒤 테이블 초기화 → 앉아 있으면 다시 카운트다운

## 서버가 판정하는 것 (클라이언트가 조작할 수 없는 것)

슬롯 선택은 두 경로로 들어오지만 검사는 한 곳(`Round:ValidatePick`)에서만 한다.

- 통에 붙은 ProximityPrompt (PC E / 모바일 탭)
- 화면 아래 자리 버튼 → `Remotes/SelectSlot` RemoteEvent

검사 순서: 레이트 리밋 → 등록된 테이블인가 → **요청한 사람이 그 테이블에 앉아 있는가(다른 테이블 요청 거부)**
→ 게임 중인가 → 참가자인가 → 지금 그 사람 차례인가 → 결과 연출 중이 아닌가 → 그 번호 자리가 있는가 → 이미 쓰인 자리가 아닌가.

위험 자리는 Attribute 로도, RemoteEvent 로도 내려보내지 않는다. 서버 로그에도 남기지 않는다.

## 파일 구조

```
ReplicatedStorage/CursedBarrel/
  Shared/     GameConfig · TableConfig · Utility
  Remotes/    SelectSlot (RemoteEvent)
ServerScriptService/CursedBarrel/
  Main (Script)
  Services/   TableService · GameTable · SlotBuilder · RoundService · RankingService
StarterPlayer/StarterPlayerScripts/Controllers/
  TableController · LightingController · KnifeController (LocalScript)
Workspace/
  GameTables/Table_A..F   (각 테이블에 Seats/ · KnifeSlots/ · Barrel/ · StatusAnchor)
  Lobby/                  ShopDisplay · ArtifactDisplay · RankingArea · HowToPlay · LobbySpawn
```

태그: `CursedBarrel_Table` · `CursedBarrel_Seat` · `CursedBarrel_Slot` · `CursedBarrel_RankingBoard`

## Phase 3 에서 같이 고친 것 (스크린샷 지적 사항)

- **의자 방향**: Z축 쪽 의자 2개가 테이블을 등지고 있었다. 좌석 축 기준 180도 회전 → 6개 테이블 전부 등받이가 바깥쪽
- **등불이 현황판을 가림**: 등불을 y=12 → 15.8 로 올리고 줄을 짧게 줄였다. 현황판(9.48~13.88)보다 1스터드 위
- **스폰 발판 Z-파이팅**: 발판 윗면이 바닥 윗면과 같은 높이(y=1)였다. 바닥 위로 띄우고(1.15~1.35) 받침을 깔았다
- **간판이 벽을 보고 있음**: ShopSign / HowToPlay 의 SurfaceGui 면이 벽을 향해 있어 글자가 안 보였다 → 방 안쪽으로 회전
- **아티팩트 자리**: 스폰 좌우에 진열대 6개 + DisplayAnchor 6개 (현질용 아티팩트 전시 예정 구역). 가운데 통로 22스터드는 비워 둠
- **랭킹판**: 스폰을 바라보는 큰 판. `RankingService` 가 승리/참가 수를 세어 채운다 (leaderstats "승리" 포함)

## 다시 빌드하려면

`.rbxl` 은 아래 도구로 만들었다. (Studio 없이 Rust + rbx-dom 으로 직접 직렬화)

```bash
cd tools/builder
PHASE3_SRC=../../src cargo run --release -- <Phase2.rbxl> ../../CursedBarrel_Phase3.rbxl
cargo run --release --bin verify -- ../../CursedBarrel_Phase3.rbxl   # 구조 검사 123개 항목
cd ../luacheck && cargo run --release -- ../../src/**/*.lua          # Luau 문법 검사
cd ../rbxtool  && cargo run --release -- ../../CursedBarrel_Phase3.rbxl  # 트리/속성 덤프
```

외부 에셋이나 Asset ID 는 쓰지 않는다. 소리도 넣지 않았다 (에셋이 필요하기 때문).

## 설정을 바꾸고 싶을 때

- 칼 개수 · 위험 자리 수 · 턴 시간 · 카운트다운: `src/Shared/TableConfig.lua`
- 탈락/승리 연출 타이밍, 슬롯 배치, 조명 프리셋: `src/Shared/GameConfig.lua`
- 서버를 껐다 켜도 랭킹을 남기려면: `GameConfig.Ranking.UseDataStore = true`
  (Studio 에서는 게임 설정 > 보안 > "Studio의 API 서비스 접근 허용" 필요. 꺼져 있으면 이 서버 세션 기준으로만 집계한다)
