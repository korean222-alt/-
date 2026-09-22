# 소스 및 재현

- `output/CursedBarrel_Phase9_DragonTide.rbxl`: 통합 Place.
- `game`: 30개 Script/LocalScript/ModuleScript 소스.
- `base`: 사용자 첨부 Phase 8 원본.
- `assets/branding`: 사용자 원본 JPEG 3장 및 연결 안내. 이전 생성 홍보물 제외.
- `assets/audio`: 합성 원본 WAV 5개.
- `tests`: 모의 검사·바이너리 검사·선택적 Studio 검사.
- `docs/reference`: 첨부 로드맵과 Phase 6–8 설명 원본.

## 오프라인 검사 및 빌드

Python 3, 시스템 liblz4와 liblua5.4가 필요합니다. 이 도구는 Roblox Studio 또는 Luau 컴파일러를 포함하지 않습니다.

```bash
python tools/extend_place.py base/CursedBarrel_Phase8.rbxl game output/CursedBarrel_Phase9_DragonTide.rbxl
python tests/verify_place.py base/CursedBarrel_Phase8.rbxl output/CursedBarrel_Phase9_DragonTide.rbxl
```

`extend_place.py`는 이 원본의 기존 스크립트 클래스 구조에 맞춘 빌더입니다. 다른 구조의 임의 rbxl에 적용하는 일반 편집기가 아닙니다. 소스 변경 전후는 소스 관리로 별도 보관하세요. Roblox에서 직접 열어 확인하기 전에는 바이너리 구조 검사만으로 완전한 호환성을 단정할 수 없습니다.

## 변경 기록

- 9.0.0 Dragon Tide: 프로필/영수증/라운드 안정화, 6종 코스메틱과 절차적 용 VFX, 관전/파티/카드/주간/시즌/설정, 선박형 플레이 공간, 사용자 브랜딩 연결.
- 카탈로그 희귀도 조회 부작용 제거; 중복 ID/조회 불변성 회귀 검사 추가.
- 공개 및 Roblox Studio 검증은 수행하지 않음.

## 게임 소개 초안

**저주받은 통 — 용의 항로**

해적선에 올라 친구들과 통에 칼을 꽂아 보세요. 튀어나오는 해적을 타이밍에 맞춰 잡고, 마지막까지 살아남아 선장의 자리를 차지하세요!

2인 결투부터 6인 파티, 빠른 모드와 무료 특수 카드 테이블까지. 코인을 모아 칼·통·해적·의자와 화려한 용 이펙트를 꾸며 보세요.

조작: 빈 의자에 앉기 → 내 차례에 슬롯 선택 → 해적이 나오면 잡기 버튼. 모바일은 화면 버튼, PC는 화면 안내, 게임패드는 선택 포커스를 사용합니다. 눈부심이 불편하면 항해 수첩 설정에서 효과와 화면 흔들림을 줄이세요.

이 초안은 출시 QA 후 실제 활성화된 기능만 남겨 게시하세요. 스킨 외 기존 방해 상품을 판매한다면 그 기능과 가격도 별도로 명확히 고지하세요.
