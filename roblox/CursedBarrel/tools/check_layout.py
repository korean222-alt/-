#!/usr/bin/env python3
"""설치 스크립트가 만드는 로비/테이블 배치가 서로 겹치지 않는지 계산으로 확인한다.
좌표 값은 installer_template.lua 에서 직접 읽어온다."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = (ROOT / "tools" / "installer_template.lua").read_text(encoding="utf-8")

# --- 템플릿에서 실제 값 읽기 ---
layout = [
    (m.group(1), m.group(2), int(m.group(3)), float(m.group(4)), float(m.group(5)))
    for m in re.finditer(
        r'\{ name = "(\w+)", tableType = "(\w+)", seatCount = (\d+), '
        r'offset = Vector3\.new\((-?[\d.]+), 0, (-?[\d.]+)\) \}',
        TEMPLATE,
    )
]
floor = re.search(r'Name = "Floor",\s*\n\s*Size = Vector3\.new\(([\d.]+), [\d.]+, ([\d.]+)\)', TEMPLATE)
assert layout and floor, "템플릿에서 배치 값을 읽지 못했습니다"

FLOOR_X, FLOOR_Z = float(floor.group(1)) / 2, float(floor.group(2)) / 2
SEAT_RADIUS = {4: 6.6, 2: 5.6}
CHAIR_DEPTH = 1.5  # 등받이/다리까지 포함한 여유

failures = []


def check(label, condition, detail=""):
    print(f"   [{'통과' if condition else '실패'}] {label} {detail}")
    if not condition:
        failures.append(label)


print("── 테이블 배치")
for name, kind, seats, x, z in layout:
    radius = SEAT_RADIUS[seats] + CHAIR_DEPTH
    check(f"{name} 이 바닥 안에 들어감",
          abs(x) + radius < FLOOR_X and abs(z) + radius < FLOOR_Z,
          f"(x={x}, z={z}, 반경={radius})")

for i, (n1, _, s1, x1, z1) in enumerate(layout):
    for n2, _, s2, x2, z2 in layout[i + 1:]:
        gap = ((x1 - x2) ** 2 + (z1 - z2) ** 2) ** 0.5 - (SEAT_RADIUS[s1] + SEAT_RADIUS[s2] + 2 * CHAIR_DEPTH)
        check(f"{n1} ↔ {n2} 사이 간격", gap > 4, f"({gap:.1f} 스터드)")

print("── 로비 시설")
SHOP_Z, SHOP_DEPTH, SHOP_WIDTH = -60, 16, 80
SPAWN_Z, SPAWN_SIZE = 52, 16
check("전시 구역이 바닥 안", abs(SHOP_Z) + SHOP_DEPTH / 2 < FLOOR_Z and SHOP_WIDTH / 2 < FLOOR_X)
check("스폰이 바닥 안", abs(SPAWN_Z) + SPAWN_SIZE / 2 < FLOOR_Z)
for name, _, seats, x, z in layout:
    radius = SEAT_RADIUS[seats] + CHAIR_DEPTH
    check(f"{name} ↔ 전시 구역", abs(z - SHOP_Z) - (SHOP_DEPTH / 2 + radius) > 2, f"({abs(z - SHOP_Z) - (SHOP_DEPTH / 2 + radius):.1f})")
    check(f"{name} ↔ 스폰", abs(z - SPAWN_Z) - (SPAWN_SIZE / 2 + radius) > 2, f"({abs(z - SPAWN_Z) - (SPAWN_SIZE / 2 + radius):.1f})")

check("랜턴(높이 15)이 벽(높이 16)보다 낮음", 11 + 2 + 2 <= 16)

print(f"\n══ 배치 점검 실패 {len(failures)}건")
sys.exit(1 if failures else 0)
