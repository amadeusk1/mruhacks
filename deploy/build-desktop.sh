#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?Set GODOT to the matching Godot executable}"
cp deploy/export_presets.cfg export_presets.cfg
mkdir -p builds/desktop/{windows,macos,linux}
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release 'Windows Desktop' builds/desktop/windows/PenglooParty.exe
"$GODOT" --headless --path . --export-release 'macOS Desktop' builds/desktop/macos/PenglooParty.zip
"$GODOT" --headless --path . --export-release 'Linux Desktop' builds/desktop/linux/PenglooParty.x86_64
python3 deploy/package-desktop.py
