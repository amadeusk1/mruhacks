#!/bin/zsh
# tools/cinema_sync.sh: host instance picks a film (smoke part "pick", held 25 s), a second instance
# signs in with the viewer code and must follow it (part "viewer"). Both hard-killed after 150 s.
cd "${0:A:h}/.."
G="${GODOT:-$HOME/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot}"
set -a; . ~/.config/pengloo/cinema.env; set +a
export PENGLOO_CINEMA_URL="${PENGLOO_CINEMA_URL:-http://127.0.0.1:8097/cinema/}"
PICK_HOLD=25 PENGLOO_CINEMA_TEST_CODE="$CINEMA_HOST_CODE" "$G" --path . res://tools/cinema_smoke.tscn -- --part=pick > /tmp/cinema_smoke_pick.log 2>&1 &
h=$!
sleep 4
PENGLOO_CINEMA_TEST_CODE="$CINEMA_VIEWER_CODE" "$G" --path . --position 640,80 res://tools/cinema_smoke.tscn -- --part=viewer > /tmp/cinema_smoke_viewer.log 2>&1 &
v=$!
( sleep 150; kill -9 $h $v 2>/dev/null ) & k=$!
wait $h; rh=$?; wait $v; rv=$?; kill $k 2>/dev/null
echo "exit host=$rh viewer=$rv"; grep -h "CINEMA_SMOKE\|SCRIPT ERROR" /tmp/cinema_smoke_pick.log /tmp/cinema_smoke_viewer.log
