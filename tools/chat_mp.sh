#!/bin/zsh
# tools/chat_mp.sh <out dir>: host + client chat test (bubbles, typing, minimize/unread/history).
# Run under the shared heavy-run lock; both Godot instances are hard-killed after 120 s.
cd "${0:A:h}/.."
G="${GODOT:-$HOME/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot}"
OUT=${1:-/tmp/chat_mp/}; mkdir -p $OUT
"$G" --path . --resolution 1280x720 res://tools/chat_mp.tscn -- --net-host --net-name=Snowdrop --net-port=7799 --out=$OUT > $OUT/host.log 2>&1 &
h=$!
sleep 5
"$G" --path . --resolution 1280x720 --position 660,60 res://tools/chat_mp.tscn -- --net-join --net-name=Milo --net-port=7799 --out=${OUT}client_ > $OUT/client.log 2>&1 &
c=$!
( sleep 120; kill -9 $h $c 2>/dev/null ) & k=$!
wait $h; rh=$?; wait $c; rc=$?; kill $k 2>/dev/null
echo "exit host=$rh client=$rc"; grep -h "CHAT_MP\|SCRIPT ERROR" $OUT/host.log $OUT/client.log | grep -v SAVED
