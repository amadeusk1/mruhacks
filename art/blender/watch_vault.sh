#!/bin/zsh
# Exit (waking Claude) when the vault gains a file or a file changes. Compares the file list, not
# just mtimes, because copied-in images can keep old timestamps.
cd "${0:A:h:h:h}"
list() { find . \( -path ./art -o -path ./Models -o -path ./Renders -o -path ./.obsidian -o -path "./Art Docs" -o -path ./.trash \) -prune -o -type f ! -name .DS_Store ! -name Models.md ! -name Renders.md ! -name "Art Pipeline.md" -print | sort; }
STATE=art/_wip/vault_files.txt
[ -f "$STATE" ] || list > "$STATE"
mkdir -p art/_wip/notes_copy; [ -n "$(ls art/_wip/notes_copy)" ] || cp *.md art/_wip/notes_copy/
touch art/_wip/watch_marker
while true; do
  sleep 30
  added=$(comm -13 "$STATE" <(list))
  changed=$(find . \( -path ./art -o -path ./Models -o -path ./Renders -o -path ./.obsidian -o -path "./Art Docs" -o -path ./.trash \) -prune -o -type f -newer art/_wip/watch_marker ! -name .DS_Store ! -name Models.md ! -name Renders.md ! -name "Art Pipeline.md" -print)
  if [ -n "$added$changed" ]; then
    sleep 45   # let a batch finish landing
    echo "ADDED:"; comm -13 "$STATE" <(list)
    echo "CHANGED:"; find . \( -path ./art -o -path ./Models -o -path ./Renders -o -path ./.obsidian -o -path "./Art Docs" -o -path ./.trash \) -prune -o -type f -newer art/_wip/watch_marker ! -name .DS_Store ! -name Models.md ! -name Renders.md ! -name "Art Pipeline.md" -print
    list > "$STATE"
    # diff edited notes against the copies kept from last time, then refresh the copies
    mkdir -p art/_wip/notes_copy
    for f in ${(f)"$(comm -12 <(ls *.md | sort) <(ls art/_wip/notes_copy | sort))"}; do
      d=$(diff -u "art/_wip/notes_copy/$f" "$f" | tail -n +3 | grep -E "^[+-]" | head -40)
      [ -n "$d" ] && { echo "=== DIFF $f"; echo "$d"; }
    done
    cp *.md art/_wip/notes_copy/ 2>/dev/null
    exit 0
  fi
done
