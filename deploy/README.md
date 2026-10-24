# Debian deployment

Public URL: https://pengloo.party

Initial source snapshot: main `ddb9d29cfcefa102e987dd31580c6e5cadcc42dc`, plus this branch's browser/WebSocket/dedicated-host adaptation. The separate cinema PR #2 is not merged into this build.

## Host

Debian 12 x86_64 at `192.168.1.242`, SSH user **nick** (lowercase). No password belongs in this repo. Docker and Compose were already installed. Existing services are untouched; default game port 7777 is occupied by another game.

Deployment: `/home/nick/pengloo/releases/ddb9d29-web-final`
Persistent game data: `/home/nick/pengloo/data`
Compose project: `pengloo`
Website port: `18085` → nginx container port 80.
Game socket: container-private `7778`; nginx routes `/multiplayer` to it.
Cloudflare Tunnel: user configured `pengloo.party` → `http://192.168.1.242:18085`.

Two services restart automatically unless stopped: `pengloo-game-1` (headless Godot) and `pengloo-web-1` (nginx). The current game loads the town to configure existing gameplay systems, then hides/disables the server's local penguin. Browser clients use same-origin `wss://.../multiplayer`; local ENet hosting remains available for desktop development.

## Build

Use Godot 4.7.2 with matching Web and Linux x86_64 export templates:

```sh
GODOT='/path/to/Godot' ./deploy/build.sh
```

Outputs: `builds/web/` and `builds/server/`. The script copies the tracked deployment preset into Godot's ignored `export_presets.cfg`. Keep `art/godot/` included: its Tints/Sockets scripts are runtime dependencies. This web preset uses Compatibility rendering, single-threaded WebAssembly and desktop texture compression; mobile browsers are not verified.

The browser title screen uses the existing static background instead of loading the entire town behind the menu. The online world is the default web choice; hosting in the browser is hidden because browsers cannot listen for incoming peers.

## Deploy/update

Prepare a NEW release directory for each update, then upload the complete `web/`, `server/`, `compose.yaml` and `nginx.conf`. Keep the previous release for rollback. Do not overwrite `.pck` files while browsers or the server read them. For an initial staging directory a temporary file followed by `mv` is safe; a new immutable release directory is preferable.

On the server:

```sh
cd /home/nick/pengloo/releases/RELEASE
# Data directory must be writable by container uid 1000.
mkdir -p /home/nick/pengloo/data
docker compose -p pengloo up -d --force-recreate
```

Use the same project name across releases to replace only Pengloo's containers. The relative data mount expects `releases/RELEASE/` at this depth. To roll back, run the same command from the previous release. Restarting the game disconnects active players; arrange updates accordingly.

Godot release templates prohibit command-line scene/path overrides. `scenes/startup.tscn` selects the world for `--dedicated`; do not add `--path` or a scene path to the container command.

## Operations

```sh
cd /home/nick/pengloo/releases/ddb9d29-web-final
docker compose -p pengloo ps
docker compose -p pengloo logs --tail 100 game
docker compose -p pengloo logs --tail 100 web
docker compose -p pengloo restart game
curl -fsS http://127.0.0.1:18085/health
```

`/health` checks nginx only, not multiplayer. Verify a real client connection after updates. The game has a 2 GiB/2 CPU limit, nginx 128 MiB. No game port is published separately; the tunnel handles HTTPS and WebSocket upgrade through nginx.

## Multiplayer checks

`tools/deployment_smoke.tscn` runs against `PENGLOO_WS_URL=wss://pengloo.party/multiplayer`. Launch two local Godot instances with `--headless --path REPO res://tools/deployment_smoke.tscn -- --test-role=a` and `b`. They test actual shared roster, chat, pose relay, seat ownership/release and location changes. Use an otherwise empty test lobby to avoid disturbing players. These are real protocol tests, not a check that a socket opens.

## Current limits

This is the existing prototype game made accessible through a persistent shared server. Names are not authenticated accounts; inventory/house ownership still follow existing prototype behavior, including peer-ID-based identities. There is no new account database, automatic player reconnection, persistent authoritative world save, or comprehensive anti-cheat in this change. There is an eight-client admission limit. Client movement/location claims retain the current game's trust model.

Current main emits town placement/navmesh warnings, including walkable-edge gaps. They are not claimed fixed by deployment. Do not equate this deployment with a completed production backend or all minigames being acceptance-tested.
