#!/usr/bin/env python3
"""src/ 의 스크립트를 installer_template.lua 에 끼워 넣어
Studio Command Bar 에 한 번 붙여넣는 설치 스크립트를 만든다.

사용법:  python3 tools/build_installer.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "build" / "CursedBarrel_Phase2_Install.lua"

# 설치 스크립트에 담을 순서 (이름 → 원본 파일)
SOURCES = [
    ("GameConfig", SRC / "Shared" / "GameConfig.lua"),
    ("TableConfig", SRC / "Shared" / "TableConfig.lua"),
    ("Utility", SRC / "Shared" / "Utility.lua"),
    ("GameTable", SRC / "Services" / "GameTable.lua"),
    ("TableService", SRC / "Services" / "TableService.lua"),
    ("RoundService", SRC / "Services" / "RoundService.lua"),
    ("Main", SRC / "Main.server.lua"),
    ("TableController", SRC / "Controllers" / "TableController.client.lua"),
    ("LightingController", SRC / "Controllers" / "LightingController.client.lua"),
]

DELIM_OPEN = "[====["
DELIM_CLOSE = "]====]"


def main() -> int:
    template = (ROOT / "tools" / "installer_template.lua").read_text(encoding="utf-8")
    if "--@@SOURCES@@" not in template:
        print("템플릿에 --@@SOURCES@@ 표시가 없습니다.", file=sys.stderr)
        return 1

    blocks = []
    for name, path in SOURCES:
        source = path.read_text(encoding="utf-8")
        if DELIM_CLOSE in source:
            print(f"{path} 안에 {DELIM_CLOSE} 가 들어 있어 감쌀 수 없습니다.", file=sys.stderr)
            return 1
        # 긴 문자열은 첫 줄바꿈을 먹으므로 한 줄 띄워서 시작한다.
        blocks.append(f"SOURCES.{name} = {DELIM_OPEN}\n{source}{DELIM_CLOSE}")

    installer = template.replace("--@@SOURCES@@", "\n".join(blocks))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(installer, encoding="utf-8")

    # 끼워 넣은 내용이 원본과 똑같은지 다시 읽어서 확인한다.
    pattern = re.compile(
        r"^SOURCES\.(\w+) = \[====\[\n(.*?)\]====\]$",
        re.DOTALL | re.MULTILINE,
    )
    found = {match.group(1): match.group(2) for match in pattern.finditer(installer)}
    for name, path in SOURCES:
        expected = path.read_text(encoding="utf-8")
        if found.get(name) != expected:
            print(f"끼워 넣기 검증 실패: {name}", file=sys.stderr)
            return 1

    lines = installer.count("\n") + 1
    print(f"생성 완료: {OUT.relative_to(ROOT)}  ({lines} 줄, {len(installer.encode('utf-8'))} bytes)")
    print(f"포함된 스크립트 {len(found)}개: " + ", ".join(name for name, _ in SOURCES))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
