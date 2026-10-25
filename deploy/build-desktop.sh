#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${GODOT:?Set GODOT to the matching Godot executable}"
cp deploy/export_presets.cfg export_presets.cfg
git rev-parse --short HEAD > build_version.txt  # Net.build_version(): servers and clients must match to join
mkdir -p builds/desktop/{windows,macos,linux}
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release 'Windows Desktop' builds/desktop/windows/PenglooParty.exe
"$GODOT" --headless --path . --export-release 'macOS Desktop' builds/desktop/macos/PenglooParty.zip
"$GODOT" --headless --path . --export-release 'Linux Desktop' builds/desktop/linux/PenglooParty.x86_64
if [ -n "${ANDROID_HOME:-}${ANDROID_SDK_ROOT:-}" ]; then
  mkdir -p builds/desktop/android
  "$GODOT" --headless --path . --export-release 'Android' builds/desktop/android/PenglooParty.apk
fi
mkdir -p builds/desktop/server
"$GODOT" --headless --path . --export-release 'Linux Server' builds/desktop/server/pengloo.x86_64
# the cinema helper hosts run next to the game (services/cinema; their media server, their codes)
(cd services/cinema
 export CGO_ENABLED=0
 GOOS=windows GOARCH=amd64 go build -trimpath -o ../../builds/desktop/windows/pengloo-cinema.exe .
 GOOS=linux GOARCH=amd64 go build -trimpath -o ../../builds/desktop/linux/pengloo-cinema .
 GOOS=darwin GOARCH=arm64 go build -trimpath -o ../../builds/desktop/pengloo-cinema-arm64 .
 GOOS=darwin GOARCH=amd64 go build -trimpath -o ../../builds/desktop/pengloo-cinema-amd64 .)
lipo -create -output builds/desktop/macos/pengloo-cinema builds/desktop/pengloo-cinema-arm64 builds/desktop/pengloo-cinema-amd64
codesign -s - -f builds/desktop/macos/pengloo-cinema
rm builds/desktop/pengloo-cinema-arm64 builds/desktop/pengloo-cinema-amd64
cp builds/desktop/linux/pengloo-cinema builds/desktop/server/pengloo-cinema
cp deploy/community/compose.yaml deploy/community/Dockerfile.cinema deploy/community/env.example deploy/community/cinema.env.example deploy/community/README.md builds/desktop/server/
python3 deploy/package-desktop.py
