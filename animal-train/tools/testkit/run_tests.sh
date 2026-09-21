#!/usr/bin/env bash
# 게임 로직을 실제로 돌려 보는 검사. luau 실행 파일 경로를 LUAU 로 넘겨 주세요.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU="${LUAU:-luau}"
python3 "$HERE/../build_place.py" >/dev/null
cat "$HERE/rbxmock.luau" "$HERE/bundle.luau" "$HERE/runner.luau" > "$HERE/_all.luau"
"$LUAU" "$HERE/_all.luau"
