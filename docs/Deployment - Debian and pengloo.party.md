# Deployment — Debian and pengloo.party

Updated 2026-10-24.

The public game is at **https://pengloo.party**. Choose **Pengloo Party → Join world** for multiplayer; Practice Island is local solo play.

## Source and scope

Deployment checkout on this Mac:
`/Users/nick/Documents/Codex/2026-10-23/make-a-new-obsidian-vault-on/pengloo-deployment`

Branch: `deploy/debian`, based on main `ddb9d29cfcefa102e987dd31580c6e5cadcc42dc` (town basketball and house ownership update). It adds WebSocket networking, a dedicated startup path, browser export presets and hosting files. The cinema feature in PR #2 remains separate because it is not on that main snapshot. Do not assume cinema streaming is deployed with this build.

## Server and tunnel

- Debian 12, x86_64, IP `192.168.1.242`, hostname SaladBar.
- SSH username is **nick**, lowercase. The server password is intentionally not stored in this note or Git.
- Existing Docker/Compose installation is used. Other containers were not changed.
- Release folder: `/home/nick/pengloo/current`.
- Persistent data directory: `/home/nick/pengloo/data`.
- Compose project: `pengloo`.
- Containers: `pengloo-game-1` and `pengloo-web-1`, both restart unless stopped.
- Web origin: `http://192.168.1.242:18085`.
- User configured Cloudflare Tunnel: `pengloo.party` → that origin.
- Nginx serves the exported web game and proxies `/multiplayer` to the game container on TCP 7778. No separate game port needs exposing through the tunnel.
- Port 7777 already belongs to another game on this server; leave it alone.

## How multiplayer works now

The Debian process stays running as the game's host. Browser clients derive `wss://pengloo.party/multiplayer` from the website origin and use Godot's WebSocketMultiplayerPeer. The existing Net autoload remains responsible for roster, room presence, chat, poses, seat ownership and activity state. The hidden server penguin is disabled after loading the town; it is not a normal player walking around.

Native local ENet hosting remains available. For a native client connecting to the public server, set `PENGLOO_WS_URL=wss://pengloo.party/multiplayer` and use the Join flow. The configured WebSocket URL controls the connection; local desktop ENet remains the fallback when it is not set.

The browser menu hides hosting and defaults to the online shared world. Its title backdrop uses the existing static image rather than constructing the whole town behind the menu. The web build uses Compatibility rendering and single-threaded WebAssembly. Initial downloads remain substantial (roughly 85 MB of game data plus the engine before HTTP compression); mobile performance is unverified.

## Operations

```sh
ssh nick@192.168.1.242
cd /home/nick/pengloo/current
docker compose -p pengloo ps
docker compose -p pengloo logs --tail 100 game
docker compose -p pengloo logs --tail 100 web
curl -fsS http://127.0.0.1:18085/health
```

`/health` only checks the web server. A real game client must be used to verify multiplayer.

Restart the game (disconnects players):

```sh
docker compose -p pengloo restart game
```

Do not run `docker compose down` in unrelated application directories. This deployment is isolated by its `pengloo` project name.

## Build, update and rollback

The checkout's `deploy/README.md`, `deploy/build.sh`, `deploy/export_presets.cfg`, `deploy/compose.yaml` and `deploy/nginx.conf` are the source of truth for operations.

Mac Godot binary:
`/Users/nick/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot`

```sh
cd '/Users/nick/Documents/Codex/2026-10-23/make-a-new-obsidian-vault-on/pengloo-deployment'
GODOT='/Users/nick/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot' ./deploy/build.sh
```

This requires matching Godot 4.7.2 export templates. Outputs are in `builds/web` and `builds/server`. The tracked preset is under `deploy` because the original repo ignores the root `export_presets.cfg`.

Upload a complete new immutable release folder under `/home/nick/pengloo/releases/RELEASE`. Include `web/`, `server/`, `compose.yaml` and `nginx.conf`. From that folder run `docker compose -p pengloo up -d --force-recreate`. Keep the previous folder. Rollback is the same command from the previous folder. Preserve the folder depth so the shared `../../data` mount resolves correctly.

Do not overwrite a package while the server/browser is reading it. For staging, upload as a temporary filename and rename atomically. Keep HTML, package, JavaScript, WebAssembly and compressed copies together. Changing GitHub main does not automatically update the server.

## Checks performed

Two independent Godot clients connected through the real public Cloudflare WebSocket endpoint. Tests verified shared roster, chat, remote poses, seat ownership/release and room changes. Both printed `DEPLOYMENT_PASS`. The game container stayed running with zero restart count after the final startup correction.

Two independent Chromium browser sessions joined the public world as WebTestA and WebTestB. Both rendered in the same town; movement from one appeared in the other, and a typed chat message arrived in the second browser. Both also successfully used Reconnect after an earlier connection loss. A transient connection loss was observed during testing; long-duration stability and reconnect identity are not claimed solved.

Repeat protocol tests using `tools/deployment_smoke.tscn` in the checkout: launch two local Godot instances against `PENGLOO_WS_URL=wss://pengloo.party/multiplayer`, one with `--test-role=a`, the other `b`. These probes send chat and claim a test seat; use a quiet test server.

## Known limits / Claude follow-up

- This deploys the current prototype; it is not a finished account/persistence/anti-cheat backend. Player names are not authenticated accounts, and some game state/house identity still uses the existing peer-ID model.
- Native and browser clients can share the WebSocket server, but reconnect/persistent identity still needs work.
- The server admits eight clients. WebSocket uses TCP; do not claim UDP-style latency or large-scale capacity.
- Existing main emits town transform/navigation warnings, including gap warnings. These were not fixed as part of server deployment.
- The full server world is loaded for current activity configuration. A lean dedicated-server scene would reduce work/memory; do not remove it without preserving court/activity initialization.
- Cinema PR #2 needs a deliberate merge and deployment of its separate Emby gateway. Keep its private env server-side; see [[Cinema - Claude Handoff and Local Setup]].
- Browser/mobile performance, all minigames, multiple isolated worlds, monitoring and durable world saves need further acceptance work.

## Branding update

The Pengloo Party browser branding release is `releases/party-branding`. The `current` symlink points there. Only the web container was recreated for this visual update; the active game container remains on its prior identical-networking release. The new folder includes a copy of that server binary for a later full restart. See [[Pengloo Party - Branding and Loading Screen]].
