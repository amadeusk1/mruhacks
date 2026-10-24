#!/bin/zsh
# Import every GLB in the vault's Models/ into a throwaway Godot project (outside the vault, so
# no .import files land in Obsidian) and run the checks in tests/. Usage: art/godot/verify_in_godot.sh
set -e
HERE=${0:A:h}
VAULT=${HERE:h:h}
P="$HOME/Library/Caches/club_penguin_godot_check"
G="$HOME/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot"
mkdir -p "$P"
# one run at a time: builders run this concurrently and share the import cache
LOCK="$P.lock"
until mkdir "$LOCK" 2>/dev/null; do
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +20 2>/dev/null)" ] && rmdir "$LOCK"  # stale lock from a killed run
  sleep 5
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
rsync -a --delete --include='*/' --include='*.glb' --exclude='*' "$VAULT/Models/" "$P/models/"
cp "$HERE"/*.gd "$HERE"/tests/*.gd "$P/"
printf 'config_version=5\n\n[application]\nconfig/name="asset_check"\n' > "$P/project.godot"
cd "$P"
"$G" --headless --path . --import > import.log 2>&1 || true
for t in import_report shade_flags tint_helpers anim_kits part_clips; do
  "$G" --headless --path . --script "$t.gd" 2>&1 | grep -E "REPORT|RESULT|SHADED|TINT_TEST|ROLES|ANIM |RETARGET|PART_CLIPS|LOAD_FAILED|SCRIPT ERROR" || true
done
