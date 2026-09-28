# 헤드리스 플레이 테스트

Studio 없이 실제 게임 스크립트를 한 판 끝까지 돌려 보는 테스트.

- `luaurun/` — Luau VM 실행기 (Rust + mlua). `cargo build --release` 후 `target/release/luaurun` 을 PATH 에 둔다.
- `api.lua` — Roblox 클래스/속성/메서드/Enum 목록. `gen_api.py` 로 `@rbxts/types` 에서 생성 (`npm pack @rbxts/types`).
- `mock/` — Roblox 엔진 모의 구현 (자료형, Instance, 서비스, 가상 시간 스케줄러).
  속성을 쓸 때마다 api.lua 로 이름·읽기전용·자료형·Enum 을 검사한다.
- `run_game.luau` — 시나리오: 입장 → 사냥/포획 → 채집/입금/건설 → 등록/배치 → 밤 전투 → 3밤 결과.
- `run.sh` — 실행. 끝나면 `.scene_parts.txt` / `.scene_terrain.txt` 에 맵을 내보낸다.
- `render_scene.py` — 내보낸 맵을 Blender(bpy) 로 렌더.

한계: 물리, 실제 렌더링, 네트워크 복제 지연, FBX 가져오기 결과는 흉내 내지 못한다. Studio 확인을 대신하지 않는다.
