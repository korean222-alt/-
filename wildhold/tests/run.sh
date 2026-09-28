#!/usr/bin/env bash
# 헤드리스 플레이 테스트 실행. 필요: Luau 실행기(LUAURUN), tests/api.lua
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
LUAURUN="${LUAURUN:-luaurun}"
(cd "$ROOT/src" && find . -name "*.lua" | sed 's#^\./##' | sort) > "$HERE/.manifest"
BOOT="$(mktemp --suffix=.luau)"
printf 'ROOT_DIR = "%s"\nlocal f = loadsource(readfile(ROOT_DIR .. "/tests/run_game.luau"), "run_game")\nf()\n' "$ROOT" > "$BOOT"
"$LUAURUN" "$BOOT"
