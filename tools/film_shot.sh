#!/usr/bin/env bash
# tools/film_shot.sh <scene> <out.mkv> [seconds] [extra host args...]: records one trailer take.
# Starts the host scene fullscreen on the main screen, four headless follow bots, and records the
# main screen (ffmpeg ddagrab, native resolution, no cursor) from the host's FILM READY line.
#   GODOT=/path/to/godot tools/film_shot.sh film_walk renders/walk.mkv 25 --tod=0.70
# The screen is taken over while it runs. Logs go next to the output.
cd "$(dirname "$0")/.."
G="${GODOT:-godot}"
scene=$1
out=$2
seconds=${3:-25}
shift 3
log="${out%.*}.log"
mkdir -p "$(dirname "$out")"
pids=()
cleanup() { kill "${pids[@]}" 2> /dev/null; }
trap cleanup EXIT INT TERM

"$G" --path . "res://tools/$scene.tscn" --screen 0 --fullscreen --always-on-top -- --net-host --net-name=Host "$@" > "$log" 2>&1 &
pids+=($!)
sleep 8  # the host builds the town before anyone joins
NAMES=(Pip Mochi Waddles Biscuit)
for i in 0 1 2 3; do
	# headless Godot runs uncapped; capped bots leave the CPU to the host's frame rate
	"$G" --headless --max-fps 20 --path . res://tools/follow_bot.tscn -- "--net-name=${NAMES[$i]}" "--slot=$((i * 2))" > "${log%.log}-bot$i.log" 2>&1 &
	pids+=($!)
	sleep 5  # spread out the CPU-heavy town builds
done

for ((t = 0; t < 240; t++)); do
	grep -q "FILM READY" "$log" && break
	sleep 1
done
grep -q "FILM READY" "$log" || { echo "no FILM READY after 4 min; see $log"; exit 1; }
ffmpeg -v error -y -f lavfi -i "ddagrab=output_idx=0:framerate=30:draw_mouse=0,hwdownload,format=bgra" \
	-t "$seconds" -c:v libx264 -preset ultrafast -crf 14 -pix_fmt yuv420p "$out"
grep -q "FILM DONE" "$log" || echo "warning: the shot had not printed FILM DONE when recording stopped"
echo "recorded $out"
