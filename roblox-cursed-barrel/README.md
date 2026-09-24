# Cursed Barrel — Blender 스킨 팩 (Phase 17)

로블록스 게임 **Cursed Barrel** 의 칼 · 통 · 해적 스킨을 Blender(4.5 LTS, 파이썬 모듈)로 만드는 도구와 결과물.

- **안내서**: [docs/Phase17_블렌더스킨_로비_출시_KO.md](docs/Phase17_블렌더스킨_로비_출시_KO.md) — 바뀐 것 · Studio 에서 할 일 · 출시 ID 어디서 얻나
- `export/CursedBarrelSkins.fbx` — Studio 3D 가져오기로 한 번 넣는 모델 (조각 111개, 약 10만 삼각형)
- `export/SkinMeshCatalog.lua` — 조각 크기 · 자리 (게임의 `Shared/SkinMeshCatalog` 와 같은 파일)
- `thumbnails/` — 스킨 33개 그림 (투명 배경), `thumbnails/cards/` — 희귀도 배경 카드 (상점 · 개발자 상품 아이콘용)
- `fx/` — 꽃잎 · 별 · 빛 구슬 · 룬 고리 입자 그림 (흰색이라 게임에서 물들일 수 있다)
- `blender/` — 모델 · 그림을 만드는 스크립트 (`build_all.py export|thumbs`)
- `tools/` — .rbxl 에서 스크립트 꺼내기 · 넣기 · 자동 실행 검사 (Lune)

게임 파일(.rbxl)은 게임 코드 전체가 들어 있어서 이 공개 저장소에는 올리지 않는다 (`output/` 은 git 에서 빠진다).
