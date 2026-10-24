# Pengloo cinema gateway

Working Emby-backed watch mode for the cinema kiosk and auditorium seats. One shared screening per gateway process. Inspired by [plex-watchparty](https://github.com/rawsocket-dev/plex-watchparty), with a separate Emby provider and private media proxy.

## Run locally

Install Go 1.26.3 or newer. Copy `.env.example` to a private file outside this repository, fill it, and restrict it with `chmod 600`. Never commit API keys or invitation codes.

```sh
cd services/cinema
go test -race ./...
go run . --env ~/.config/pengloo/cinema.env
```

Open http://127.0.0.1:8095/cinema/. Enter your display name and the host or viewer invitation code from the private config. The first host gets the remote. Viewers cannot select films, seek, pause, or claim the remote. A host can claim the remote after the previous controller disconnects. Only give the host code to people allowed to control screenings.

For the native game, launch Godot with `PENGLOO_CINEMA_URL=http://127.0.0.1:8095/cinema/`. Installed exports can instead configure `cinema/service_url` in project settings. The default is https://pengloo.party/cinema/; that URL needs deployment before it works.

For Nick's development machine the configured private file is `~/.config/pengloo/cinema.env`. It contains the verified Nick Emby user ID. Do not put its contents in issue reports.

## Browser game

Host the Godot HTML export and gateway on the same origin. Include `<script src="/cinema/bridge.js"></script>` in the export HTML before launching Godot. The bridge opens an iframe over the canvas and destroys it on return. Exclude `addons/godot_wry/**`, `services/**`, and documentation from the web export: WRY is native-only. A full game web export is not yet verified; browser media playback has been tested independently.

## Self-hosting

Build with `go build -o pengloo-cinema .`, or use the Dockerfile. Bind to loopback behind your HTTPS reverse proxy. Proxy `/cinema/*` to the gateway, preserving the path, Origin, cookies, and Range headers. Disable proxy buffering for `/cinema/events` and allow long-lived SSE connections. Set `CINEMA_ORIGIN=https://pengloo.party`. Serve the Godot web export on the same domain. The Emby server must be reachable by the gateway; browsers never need its API key.

Container use: set `CINEMA_LISTEN=0.0.0.0:8095` inside the container and publish only `127.0.0.1:8095:8095` behind your reverse proxy. Pass secrets using an external `--env-file`.

## Implemented

- User-scoped Emby catalogue/search and H.264/AAC HLS transcoding (6 Mbps target).
- Shared server timeline, host control, seek, pause, late join and periodic drift correction for all clients including the host.
- Invitation-code sessions, HttpOnly cookies, exact-origin write checks, login throttling, stale-generation rejection and command deduplication.
- Authenticated same-origin playlist/segment proxy with opaque URLs. Emby credentials stay on the gateway. Upstream redirects and external playlist URLs are rejected.
- Disconnect pauses when the controller is absent; unused transcodes stop after the room is empty for 60 seconds. Graceful shutdown stops the current encoding.
- Native WRY embedded webview and browser iframe close-up playback. Returning destroys the decoder/audio output and releases the player's seat.

## Limits before public release

This is a private prototype, not public game account authorization. Invitation codes are shared, sessions are in memory, and all users on one process share one movie. Add game-issued short-lived cinema tickets, room membership enforcement, moderator permissions, persistent screening state, per-room isolation, bounded bandwidth/caching and operational metrics before public rollout.

The film is not rendered onto the 3D auditorium screen yet. Subtitle/audio-track selection, Emby progress reporting, automatic end-of-film lifecycle, Plex/Jellyfin adapters, full browser game export, Linux/Windows native playback and production deployment remain unverified or unimplemented. Native webview volume currently uses the player slider, not Godot's Movie audio bus. Codec/DRM support depends on Emby and the operating system webview.

## Verification (2026-10-24)

`go test -race ./...` covers role checks, duplicate controls, stale generations, authentication, playlist rewriting, external URL rejection, CSRF, controller loss and provider requests. Live Emby catalogue and HLS proxy succeeded. Chromium and macOS Godot 4.7.2 + WRY played an actual 1920×1080 stream. These tests do not establish full deployed-game readiness.

## In-world screen segments (game clients)

`GET /cinema/api/segment?kind=video|audio&start=<s>&len=<1..20>` (session required) returns the current
film as 10 s chunks for the game's in-world screen: video is length-prefixed JPEG frames (`[u32 LE length][jpeg]...`,
15 fps, 640 px wide), audio is MP3 128 kbps. Decoding happens in an `ffmpeg` child process (installed in the
Docker image; on a Mac `brew install ffmpeg`), reading the film through a loopback-only single-use token
URL so the Emby key never appears in process arguments. One transcode per chunk is shared by all viewers.
Optional: `CINEMA_WEB_DIR=<web build>` serves a same-origin Godot web build at `/cinema/play/`.
