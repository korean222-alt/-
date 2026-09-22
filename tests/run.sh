#!/usr/bin/env bash
# 모든 테스트를 돌린다.
#
#   ./tests/run.sh
#
# 준비물
#   · luau       — https://github.com/luau-lang/luau/releases 의 luau-ubuntu.zip
#                  (PATH 에 두거나 LUAU 환경 변수로 경로를 알려 주세요)
#   · python3    — 모듈 묶음을 만드는 데 씁니다
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUAU="${LUAU:-luau}"

if ! command -v "$LUAU" >/dev/null 2>&1; then
	echo "luau 를 찾을 수 없습니다. LUAU=/경로/luau ./tests/run.sh 처럼 알려 주세요." >&2
	exit 1
fi

cd "$HERE"
python3 build_bundle.py

failures=0
for test in round_test.lua camera_test.lua config_test.lua; do
	echo ""
	echo "=============================================="
	echo " $test"
	echo "=============================================="
	if ! "$LUAU" "$test"; then
		failures=$((failures + 1))
	fi
done

echo ""
if [ "$failures" -gt 0 ]; then
	echo "테스트 파일 $failures 개가 실패했습니다."
	exit 1
fi
echo "모든 테스트 통과."
