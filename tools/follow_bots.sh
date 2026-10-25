#!/usr/bin/env bash
# tools/follow_bots.sh [count]: start headless follower penguins (tools/follow_bot.gd) that join the
# local host and walk beside it. Start the host first. Ctrl+C stops them all.
#   GODOT=/path/to/godot tools/follow_bots.sh 4
# A bot the host drops rejoins; when no host answers, it stops.
cd "$(dirname "$0")/.."
G="${GODOT:-godot}"
NAMES=(Pip Mochi Waddles Biscuit Tofu Pebble Nori Sprout)
n=${1:-4}
trap 'kill 0' INT TERM EXIT
for ((i = 0; i < n; i++)); do
	name=${NAMES[$i]}
	slot=$((i * 8 / n))
	(
		while :; do
			"$G" --headless --path . res://tools/follow_bot.tscn -- "--net-name=$name" "--slot=$slot" > /dev/null 2>&1
			rc=$?
			echo "$name exited ($rc)"
			[ "$rc" -eq 3 ] || break
			sleep 2
		done
	) &
	sleep 5  # spread out the CPU-heavy town builds
done
wait
