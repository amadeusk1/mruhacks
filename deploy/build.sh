#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?Set GODOT to the Godot 4.7.2 executable}"
cp deploy/export_presets.cfg export_presets.cfg
git rev-parse --short HEAD > build_version.txt  # Net.build_version(): servers and clients must match to join
mkdir -p builds/web builds/server
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release Web builds/web/index.html
"$GODOT" --headless --path . --export-release 'Linux Server' builds/server/pengloo.x86_64
mkdir -p builds/web/branding
cp ui/branding/*.png builds/web/branding/
mkdir -p builds/web/music
cp audio/music/*.ogg audio/music/*.mp3 audio/music/*.wav builds/web/music/  # streamed by scripts/music.gd, kept out of the .pck
python3 - <<'PY'
import gzip, shutil
from pathlib import Path
for p in Path('builds/web').iterdir():
    if p.suffix in {'.pck', '.wasm', '.js'}:
        with p.open('rb') as src, gzip.open(str(p)+'.gz','wb',compresslevel=6) as dst:
            shutil.copyfileobj(src,dst)
PY
