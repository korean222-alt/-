#!/usr/bin/env python3
"""src/ 의 서버 모듈을 mock 환경에 묶어 luau 로 실행한다.

사용법:  python3 tools/run_tests.py [luau 실행파일 경로]
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
TEST = ROOT / "tools" / "test"

# 테스트에서 돌리는 서버 측 모듈 (클라이언트 스크립트는 문법 검사만 한다)
MODULES = [
    ("GameConfig", SRC / "Shared" / "GameConfig.lua"),
    ("TableConfig", SRC / "Shared" / "TableConfig.lua"),
    ("Utility", SRC / "Shared" / "Utility.lua"),
    ("GameTable", SRC / "Services" / "GameTable.lua"),
    ("TableService", SRC / "Services" / "TableService.lua"),
    ("RoundService", SRC / "Services" / "RoundService.lua"),
]


def build_bundle() -> str:
    parts = ["--!nocheck\n", (TEST / "mock_roblox.luau").read_text(encoding="utf-8")]
    parts.append("\nlocal __moduleFns = {}\n")
    for name, path in MODULES:
        source = path.read_text(encoding="utf-8")
        parts.append(f'\n__moduleFns["{name}"] = function(script)\n{source}\nend\n')
    parts.append("\nMock.registerModules(__moduleFns)\n")
    parts.append((TEST / "scenarios.luau").read_text(encoding="utf-8"))
    return "".join(parts)


def main() -> int:
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
    bundle_path = ROOT / "build" / "test_bundle.luau"
    bundle_path.parent.mkdir(parents=True, exist_ok=True)
    bundle_path.write_text(build_bundle(), encoding="utf-8")

    result = subprocess.run([luau, str(bundle_path)])
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
