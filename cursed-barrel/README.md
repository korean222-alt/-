# 저주받은 통 / Cursed Barrel

해적 선술집 분위기의 Roblox 멀티플레이 파티 게임.
원형 테이블에 둘러앉아 중앙의 저주받은 통에 칼을 꽂고, 위험 구멍을 찌른 사람이 탈락한다.
마지막 생존자가 승리. 한 판은 1~3분.

이 디렉터리는 Roblox Studio 에 붙여넣을 Luau 소스의 원본을 보관한다.
폴더 구조가 곧 Studio 의 Instance 구조다.

```
src/
  ReplicatedStorage/CursedBarrel/Shared/     ← 서버·클라 공용 (ModuleScript)
    GameConfig.lua                             설정값과 이름 상수
    TableConfig.lua                            테이블 종류별 규칙
    Utility.lua                                Cleaner / Signal / RateLimiter
  ServerScriptService/CursedBarrel/
    Main.server.lua                          ← Script (서버 진입점)
    Services/
      GameTable.lua                            테이블 1개 = 객체 1개
      TableService.lua                         태그로 테이블을 찾아 등록/해제
  StarterPlayer/StarterPlayerScripts/Controllers/
    TableController.client.lua               ← LocalScript (테이블 현황판)

tools/                                       ← Studio 명령줄에 1회 붙여넣는 스크립트
  BuildTable.lua                               Workspace 에 4인 테이블 생성
  SetupLighting.lua                            선술집 톤 라이팅 기본 세팅
```

## 설계 원칙

- **서버가 전부 판정한다.** 승패, 위험 슬롯, 턴, 보상은 클라이언트가 절대 결정하지 않는다.
  RemoteEvent 는 "요청"만 받는다.
- **테이블은 서로 독립이다.** 테이블마다 GameTable 객체 하나, 상태 머신 하나.
  한 테이블의 라운드가 다른 테이블에 영향을 주지 않는다.
- **하드코딩된 테이블 이름이 없다.** `CursedBarrel_Table` 태그가 붙은 모델은
  Workspace 어디에 있든, 게임 도중에 복제되든 자동으로 등록된다.
- **이벤트 기반.** Heartbeat 나 `while true do` 루프를 상시로 돌리지 않는다.
- **정리한다.** 모든 연결은 Cleaner 에 등록하고, 테이블이 사라지면 한 번에 치운다.
- **클라이언트 UI 는 Attribute 를 읽는다.** 서버가 테이블 모델의 Attribute 를 바꾸면
  자동 복제되므로 현황판에 RemoteEvent 가 필요 없다.

## 테이블 모델이 지켜야 하는 구조 (계약)

모델링을 교체해도 아래만 지키면 코드는 그대로 동작한다.

```
Table_A                    (Model, 태그: CursedBarrel_Table)
  ├─ Seats                 (Folder)  ← 이름 고정
  │   └─ Chair_01 (Model)
  │       └─ Seat_01       (Seat)    ← 클래스가 Seat 이기만 하면 이름은 자유
  ├─ StatusAnchor          (Part, 투명)  ← 현황판이 떠 있을 기준점
  └─ Barrel                (Model)   ← Phase 3 에서 칼 슬롯이 붙는다
```

| 위치 | Attribute | 용도 |
|---|---|---|
| 테이블 Model | `TableId` | 테이블 고유 이름 (없으면 자동 부여) |
| 테이블 Model | `TableType` | `TableConfig.Types` 의 키 (기본 `Standard4`) |
| Seat | `SeatIndex` | 좌석 번호. 없으면 서버가 이름 순으로 자동 부여 |

서버가 런타임에 기록하는 값: `SeatCount`, `SeatedCount`, `MinPlayers`, `State`,
좌석의 `OccupantUserId`. 이 값들은 손으로 건드리지 않는다.

## 개발 단계

- [x] **Phase 1** 테이블 참가 시스템 — 4인 좌석, 앉기/일어서기, 참가자 관리, 현황판
- [ ] **Phase 2** 라운드 상태 머신 — 카운트다운, 시작/종료, 턴 순서 결정
- [ ] **Phase 3** 통과 칼 슬롯 — 슬롯 선택, 서버 검증, 안전/위험 판정, 탈락과 승리
- [ ] **Phase 4** 연출 — 카메라, 애니메이션, 사운드, VFX
- [ ] **Phase 5** UI polish, 여러 테이블, 관전
- [ ] **Phase 6** Coins/Wins, 상점, DataStore
