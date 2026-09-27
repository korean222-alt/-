# Cursed Barrel (Roblox) — 스크립트 작업 폴더

`CursedBarrel_Phase31.rbxl` 에서 스크립트를 꺼내 `src/` 에 두고, 고친 뒤 다시 place 파일로 묶는다.

| 파일 | 역할 |
|---|---|
| `CursedBarrel_Phase31.rbxl` | 받은 원본 place |
| `src/` | 원본에서 꺼낸 스크립트 (경로 = Studio 탐색기 경로) |
| `extract.luau` | place → `src/` |
| `build.luau` | `src/` → 새 place (모든 스크립트를 먼저 컴파일해서 문법 오류가 있으면 멈춘다) |

`.server.lua` = Script, `.client.lua` = LocalScript, 나머지 `.lua` = ModuleScript.

```sh
cargo install lune --locked
lune run build.luau CursedBarrel_Phase31.rbxl CursedBarrel_Phase32.rbxl
```
