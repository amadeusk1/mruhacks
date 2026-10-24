#!/bin/zsh
# tools/cinema_smoke.sh <part> [extra Godot args]: one cinema port smoke test against the local gateway.
# Reads the host invite code from ~/.config/pengloo/cinema.env at run time (never printed).
# Godot is hard-killed after ${SMOKE_SECONDS:-120} s so no instance is left running.
cd "${0:A:h}/.."
G="${GODOT:-$HOME/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot}"
set -a; . ~/.config/pengloo/cinema.env; set +a
export PENGLOO_CINEMA_URL="${PENGLOO_CINEMA_URL:-http://127.0.0.1:8097/cinema/}"
PENGLOO_CINEMA_TEST_CODE="$CINEMA_HOST_CODE" "$G" ${@:2} --path . res://tools/cinema_smoke.tscn -- "--part=$1" > "/tmp/cinema_smoke_$1.log" 2>&1 &
p=$!; ( sleep ${SMOKE_SECONDS:-120}; kill -9 $p 2>/dev/null ) & k=$!; wait $p; rc=$?; kill $k 2>/dev/null
echo "exit=$rc"; grep -E "CINEMA_SMOKE|SCRIPT ERROR|at: res" "/tmp/cinema_smoke_$1.log" | head -10
