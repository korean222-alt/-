# CursedBarrel (Roblox)

Roblox Studio 플레이스(.rbxl)와, 그 안의 스크립트 69개를 꺼내 둔 소스.

```
cursedbarrel/
  place/CursedBarrel_Phase23.rbxl   받은 원본 (수정 전)
  place/CursedBarrel_Phase24.rbxl   점검 목록 수정 + 새 기능이 들어간 플레이스 ← Studio 에서 이걸 연다
  src/                              스크립트 원문 (게임 안 경로 그대로)
    ReplicatedStorage/…/*.lua         ModuleScript
    ServerScriptService/…/*.server.lua  Script
    StarterPlayer/…/*.client.lua      LocalScript
  tools/                            다시 묶기 · 검사 · 테스트 (Lune)
  docs/Phase24_점검결과.md           점검 목록 34개 처리 결과와 새 기능 설명
```

스크립트 말고 다른 것(파트 · 모델 · 조명 · 지형)은 원본 그대로다. `pack.luau` 는 원본에 있는 스크립트의 `Source` 만 바꾼다.

## 소스를 고친 뒤 .rbxl 다시 만들기

[Lune](https://github.com/lune-org/lune) 0.10 이상이 필요하다 (`cargo install lune --locked`).

```bash
cd cursedbarrel
lune run tools/check.luau src                       # 69개 문법 검사
lune run tools/pack.luau place/CursedBarrel_Phase23.rbxl src place/CursedBarrel_Phase24.rbxl
```

Studio 에서 직접 고쳤다면 그 .rbxl 을 새 원본으로 삼아 `src` 를 다시 꺼내야 한다 (이 폴더의 `src` 가 옛 것이 된다).

## 검사 · 테스트

```bash
selene --config tools/selene.toml src               # 정의 안 된 변수 같은 실수 (selene 0.29+)
lune run tools/translate_check.luau <문장목록.txt>   # 한 줄에 한 문장 → 영어로 바뀌는지 (✓ / ✗)
lune run tools/tests/test_profile.luau              # 저장 · 영수증 · 서버 종료 (약 1분)
lune run tools/tests/test_round.luau                # 무효 판 · 방해 예약/환불 · 잡기 판정 · 방장
CB_TIMESCALE=100 lune run tools/tests/sim_economy.luau 60   # 실제 코드로 60판 → 우승자 한 판 코인 (밸런스 확인)
```

테스트는 `tools/tests/harness.luau` 가 DataStore · Players · RemoteEvent 를 흉내 내고 실제 서버 모듈을 불러 돌린다.
Roblox 엔진 자체(물리 · 화면 · 네트워크)는 흉내 내지 않으므로 화면 쪽은 Studio 에서 확인해야 한다.
