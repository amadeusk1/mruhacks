# Pengloo cinema gateway

Working Emby-backed watch mode for the cinema kiosk and auditorium seats. One shared screening per gateway process. Inspired by [plex-watchparty](https://github.com/rawsocket-dev/plex-watchparty), with a separate Emby provider and private media proxy.

## Run locally

Install Go 1.26.3 or newer. Copy `.env.example` to a private file outside this repository, fill it, and restrict it with `chmod 600`. Never commit API keys or server keys.

```sh
cd services/cinema
go test -race ./...
go run . --env ~/.config/pengloo/cinema.env
```

Players enter from the in-game cinema kiosk or an auditorium seat. No invite code or separate sign-in is shown. The game host publishes its cinema roster to the gateway and requests a short-lived, one-use handoff for the requesting peer. The host's peer ID controls the remote; other players watch. Opening the player URL directly tells you to enter through the game.

Set `CINEMA_GAME_SERVER_KEY` to a random secret of at least 32 characters in the private environment file. Only the trusted game host and gateway receive it. The host reads `PENGLOO_CINEMA_SERVER_ENV` (default `~/.config/pengloo/cinema.env`), or environment variables `CINEMA_GAME_SERVER_KEY` and `PENGLOO_CINEMA_GATEWAY` (gateway URL ending `/cinema/`). Clients receive only their one-use ticket, sent directly by the host RPC. Never bundle the private config in a client export.

One gateway supports one active game lobby. A different active lobby is rejected instead of sharing its film. Run separate gateway instances for concurrent lobbies until room routing is implemented. Membership refreshes every three seconds and expires after fifteen seconds without the host. Leaving the cinema or disconnecting removes membership; the gateway rejects further API/segment access and the game closes the player.

For the native game, launch Godot with `PENGLOO_CINEMA_URL=http://127.0.0.1:8095/cinema/`. Installed exports can instead configure `cinema/service_url` in project settings. The default is https://pengloo.party/cinema/; that URL needs deployment before it works.

For Nick's development machine the configured private file is `~/.config/pengloo/cinema.env`. It contains the verified Nick Emby user ID and the game-host key. Do not put its contents in issue reports.

## Browser game

Host the Godot HTML export and gateway on the same origin. Include `<script src="/cinema/bridge.js"></script>` in the export HTML before launching Godot. The bridge opens an iframe over the canvas and destroys it on return. Exclude `addons/godot_wry/**`, `services/**`, and documentation from the web export: WRY is native-only. A full game web export is not yet verified; browser media playback has been tested independently.

## Self-hosting

Build with `go build -o pengloo-cinema .`, or use the Dockerfile. Bind to loopback behind your HTTPS reverse proxy. Proxy `/cinema/*` to the gateway, preserving the path, Origin, cookies, and Range headers. Disable proxy buffering for `/cinema/events` and allow long-lived SSE connections. Set `CINEMA_ORIGIN=https://pengloo.party`. Serve the Godot web export on the same domain. The Emby server must be reachable by the gateway; browsers never need its API key.

Container use: set `CINEMA_LISTEN=0.0.0.0:8095` inside the container and publish only `127.0.0.1:8095:8095` behind your reverse proxy. Pass secrets using an external `--env-file`.

## Implemented

- User-scoped Emby catalogue/search and H.264/AAC HLS transcoding (6 Mbps target).
- Shared server timeline, host control, seek, pause, late join and periodic drift correction for all clients including the host.
- Host-verified roster membership, one-use 30-second handoffs, HttpOnly sessions, exact-origin browser write checks, stale-generation rejection and command deduplication. Legacy invitation login is disabled in game-server mode.
- Authenticated same-origin playlist/segment proxy with opaque URLs. Emby credentials stay on the gateway. Upstream redirects and external playlist URLs are rejected.
- Disconnect pauses when the controller is absent; unused transcodes stop after the room is empty for 60 seconds. Graceful shutdown stops the current encoding.
- Native WRY embedded webview and browser iframe close-up playback. Returning destroys the decoder/audio output and releases the player's seat.

## Limits before public release

This uses the existing trusted listen-server lobby. The gateway trusts that host's roster; it does not add player accounts or harden the game's existing client-reported movement/location protocol. Keep the server key on your own trusted host. For public rollout add dedicated-server account authentication, persistent screening state, routing for multiple lobbies, moderator permissions, bounded bandwidth/caching and operational metrics. Sessions are currently in memory.

The film is not rendered onto the 3D auditorium screen yet. Subtitle/audio-track selection, Emby progress reporting, automatic end-of-film lifecycle, Plex/Jellyfin adapters, full browser game export, Linux/Windows native playback and production deployment remain unverified or unimplemented. Native webview volume currently uses the player slider, not Godot's Movie audio bus. Codec/DRM support depends on Emby and the operating system webview.

## Verification (2026-10-24)

`go test -race ./...` covers role checks, duplicate controls, stale generations, authentication, playlist rewriting, external URL rejection, CSRF, controller loss and provider requests. Live Emby catalogue and HLS proxy succeeded. Chromium and macOS Godot 4.7.2 + WRY played an actual 1920×1080 stream. These tests do not establish full deployed-game readiness.


## Three-player game test

`tools/cinema_lobby_smoke.tscn` is an integration harness using the real world scene, Net host/join flow, separate seats, CinemaClient RPC handoffs and native WebViews. It requires a running configured gateway and a display. Run three processes with `--net-host` / `--net-join`, `--net-name=...` and `--cinema-test=host|viewer|late`. Set `PENGLOO_PORT=17895` in all three to avoid other multiplayer tests, and `PENGLOO_CINEMA_URL=http://127.0.0.1:8095/cinema/`. Start the clients after the host reports `SEATED`.

The harness selects the first library title, plays, seeks and pauses it, logs only playback observations (never tickets), tests return/seat release and travel away, then exits. Do not run against a lobby people are currently watching. Test logs should show 1920-wide decoded video, `loginVisible:false`, disabled viewer controls, shared paused positions and the return/travel PASS markers. Browser page tests alone do not establish this game flow.
