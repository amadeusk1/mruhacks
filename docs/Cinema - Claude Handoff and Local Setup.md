# Cinema — Claude handoff and local setup

Updated 2026-10-24. This is the implementation handoff for the Emby cinema in Pengloo, not a proposal. Read this before changing the cinema integration. Also see [Cinema - Working Emby Prototype](Cinema%20-%20Working%20Emby%20Prototype.md) and [Cinema - Plex Watchparty Integration Plan](Cinema%20-%20Plex%20Watchparty%20Integration%20Plan.md). The older plan is design context; this guide describes what actually exists now.

## Start here: which checkout has the work?

| Item | Exact location |
| --- | --- |
| Obsidian vault | `/Users/nick/Documents/club penguin hackathon` |
| Cinema implementation worktree | `/Users/nick/Documents/Codex/2026-10-23/make-a-new-obsidian-vault-on/cinema-integration` |
| Git branch | `feature/cinema-emby` |
| Draft pull request | https://github.com/amadeusk1/mruhacks/pull/2 |
| Main working checkout, used by other ongoing work | `/Users/nick/Documents/Codex/2026-10-23/make-a-new-obsidian-vault-on/mruhacks` |
| Private configuration | `/Users/nick/.config/pengloo/cinema.env` |
| Gateway source | `services/cinema/` inside the cinema worktree |
| Local player page | http://127.0.0.1:8095/cinema/ |
| Local health endpoint | http://127.0.0.1:8095/cinema/health |
| Intended public URL, not deployed by this work | https://pengloo.party/cinema/ |

The cinema changes are on a separate branch, not automatically installed into every other checkout. Do not assume opening `mruhacks`, `mruhacks-main`, or another worktree runs this code. Review/merge PR #2 into the target branch, preserving other developers' changes to `project.godot`, `scripts/net.gd`, and `scripts/cinema.gd`. Do not reset another checkout to bring this work over.

## What the player should experience

A player already in the game lobby enters the cinema, interacts with an auditorium seat or the movie kiosk, and gets the embedded watch screen. **There is no invite-code prompt or separate cinema login.** The existing game host can select a film and control play/pause/seek. Other players watch the same timeline and have their own volume controls. A late joiner catches up to the current position.

The implemented watch screen covers the game viewport using a native webview on desktop, or an iframe bridge for a browser build. The game connection stays alive underneath it. This is **not yet video painted onto the auditorium's 3D screen**. Returning destroys the embedded player, stops that client's decoder/audio, removes the UI overlay and stands the seated penguin up. Travel or host loss closes the overlay too.

Opening the local player page directly without an authorized game session shows instructions to enter through the game. That is intentional; do not restore the invite form to solve it.

## The private env file

`/Users/nick/.config/pengloo/cinema.env` already exists with permissions `0600`. It is outside the repository and outside Obsidian. It contains real working credentials. **Do not copy its contents into Git, Obsidian, screenshots, chat, logs or the client export.** Claude can read/use the local file without printing its values.

| Variable | Purpose |
| --- | --- |
| `EMBY_URL` | Configured as `https://emby.saladsync.ca`; the upstream NickFlix server |
| `EMBY_API_KEY` | Real Emby API key; gateway only |
| `EMBY_USER_ID` | Resolved Emby ID for Nick's account; this is not the text username |
| `CINEMA_GAME_SERVER_KEY` | Random shared service credential between the trusted game host and cinema gateway; never sent to ordinary game clients |
| `CINEMA_ORIGIN` | Currently `http://127.0.0.1:8095`; exact browser origin allowed for state-changing requests |
| `CINEMA_LISTEN` | Currently `127.0.0.1:8095`; HTTP bind address |
| `CINEMA_HOST_CODE`, `CINEMA_VIEWER_CODE` | Legacy prototype entries may still be present; invitation login is disabled when the game-server key is configured. They are not the in-game access mechanism. |

The gateway's `--env` loader accepts simple `KEY=value` lines, without shell quoting or `export`. Existing environment variables take precedence. Editing this file does not hot-reload the running gateway; restart it. The game host caches its host configuration for the current game session; restart/rehost after changing it.

The Emby key was tested successfully. Earlier HTTP 403 responses were resolved with the gateway's `PenglooCinema/0.1` User-Agent. Preserve the explicit User-Agent and `X-Emby-Token` header in the provider when investigating connectivity.

## How to run it on this Mac

### 1. Start or check the gateway

```sh
curl -fsS http://127.0.0.1:8095/cinema/health
```

A healthy listener returns an object with `ok: true`. A gateway was left running in a development process at handoff, but it is **not** installed as a launchd service and should not be assumed to survive restarts. If it is not running:

```sh
cd '/Users/nick/Documents/Codex/2026-10-23/make-a-new-obsidian-vault-on/cinema-integration/services/cinema'
go run . --env /Users/nick/.config/pengloo/cinema.env
```

Go is installed at `/opt/homebrew/bin/go`. The module declares Go 1.26.3. If port 8095 is occupied, inspect the owner with `lsof -nP -iTCP:8095 -sTCP:LISTEN`; don't kill unrelated processes. Stop the old gateway before starting a replacement. A stop/restart clears in-memory sessions and the current screening.

### 2. Launch the game host

Steam's Godot executable is:

`/Users/nick/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot`

```sh
PENGLOO_CINEMA_URL=http://127.0.0.1:8095/cinema/ \
PENGLOO_PORT=17895 \
'/Users/nick/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot' \
  --path '/Users/nick/Documents/Codex/2026-10-23/make-a-new-obsidian-vault-on/cinema-integration' \
  res://scenes/world.tscn -- --net-host --net-name=Nick
```

This launches the real world directly and hosts a local game. The ordinary main menu can also be used. The trusted host reads the private env from its default path. Override the file path with `PENGLOO_CINEMA_SERVER_ENV` if needed. For a deployed host, `CINEMA_GAME_SERVER_KEY` and `PENGLOO_CINEMA_GATEWAY` can be environment variables instead; the latter must end in `/cinema/`.

### 3. Launch friends in additional processes

```sh
PENGLOO_CINEMA_URL=http://127.0.0.1:8095/cinema/ \
PENGLOO_PORT=17895 \
'/Users/nick/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot' \
  --path '/Users/nick/Documents/Codex/2026-10-23/make-a-new-obsidian-vault-on/cinema-integration' \
  res://scenes/world.tscn -- --net-join --net-name=Friend
```

Enter the cinema in each window and use different seats. Do not give the friends the private env file. The code reads the service credential only in host mode.

`PENGLOO_PORT` is optional; default game port is 7777. Other agents were testing multiplayer simultaneously on 7777, so the cinema test used **17895**. Set the same port in every test process. The game's current join address is hard-coded to `127.0.0.1` in `scripts/net.gd`; these commands are for multiple local windows, not a completed remote-server connection UI.

`PENGLOO_CINEMA_URL` is the player-facing URL and must end in `/cinema/`. Without that variable, the native player uses project setting `cinema/service_url`, falling back to `https://pengloo.party/cinema/`. That public deployment has not been set up here.

## How authorization and streaming work

1. `scripts/cinema.gd` marks auditorium `SeatSpot`s with activity `cinema` and creates a movie kiosk. Seat interaction uses the existing host-owned seat-claim mechanism.
2. `Activities.requested` reaches the `CinemaClient` autoload. It opens a loading overlay and asks the game host for access. A client request supplies a request nonce, **not a player ID or a role**.
3. The host uses the RPC sender ID and its own `Net.roster()` to verify that the peer is connected, visible and in location `cinema`. The current check covers the cinema location, not a narrower auditorium voice room or exact seat distance.
4. The trusted host posts a roster to `/cinema/internal/roster` using `X-Pengloo-Server-Key`. It refreshes every three seconds and on roster changes. The gateway grants a fifteen-second membership lease. The host's peer ID 1 is eligible for the remote.
5. The host requests `/cinema/internal/ticket` for that member and sends the one-use ticket only to that peer using an authority RPC. Tickets expire after thirty seconds.
6. The embedded player opens with the ticket in the URL fragment, immediately removes the fragment from browser history, and exchanges it at `/cinema/api/ticket` for an HttpOnly session cookie. The fragment is not sent as part of the initial HTTP URL. Reusing the ticket is rejected.
7. Catalogue and playback requests go through the gateway. `provider.go` requests Emby user-scoped metadata and H.264/AAC HLS transcoding. Emby API credentials stay server-side.
8. The gateway rewrites playlist references to opaque authenticated `/cinema/media/...` URLs. It rejects cross-origin upstream references and redirects. Media requests validate membership as well as the cookie.
9. The player receives the shared timeline over server-sent events. All clients, including the host, follow it. The UI corrects drift, seeks on large divergence and has bounded decoder recovery for a stalled seek. This is synchronization around one shared screening, not separate playback state per player.
10. Leaving/disconnecting removes membership. Further API/media requests fail; the UI and game overlay close. If the trusted host stops publishing, access expires within fifteen seconds. A missing controller pauses the film. The gateway stops unused transcodes after idle cleanup.

One gateway currently supports **one active lobby and one screening**. It rejects another live lobby instance. A new lobby can take over after the old membership lease expires; old sessions/tickets are invalidated and the old screening is cleared. Multi-lobby routing is still future work.

## Code map

All paths below are relative to the cinema worktree.

| File | What to change there |
| --- | --- |
| `scripts/cinema_client.gd` | Game-host membership publishing, RPC ticket request/delivery, overlay lifecycle |
| `ui/activities/cinema/cinema_player.gd` | Native WebView / browser bridge, player-facing URL, return handling |
| `scripts/cinema.gd` | Kiosk and auditorium-seat activity entry points |
| `scripts/net.gd` | Existing ENet lobby/roster/seat authority; optional test port override |
| `project.godot` | `CinemaClient` autoload registration |
| `services/cinema/lobby.go` | Trusted-host endpoints, lobby lease, one-use tickets, revocation |
| `services/cinema/main.go` | HTTP routes, cookie sessions, shared timeline, media proxy, cleanup |
| `services/cinema/provider.go` | Emby API adapter, user-scoped library, transcode profile, stream fetching |
| `services/cinema/web/player.js` | Ticket exchange, video decoder, controls, SSE and drift/seek recovery |
| `services/cinema/web/index.html`, `style.css` | Watch-mode UI |
| `services/cinema/web/bridge.js` | Same-origin overlay iframe for Godot web exports |
| `services/cinema/main_test.go`, `lobby_test.go` | Backend tests |
| `tools/cinema_lobby_smoke.gd`, `.tscn` | Real three-process game test harness |
| `addons/godot_wry/` | WRY v1.0.2 native extension and platform binaries; hot reload disabled |
| `services/cinema/README.md` | Service setup and limitations |
| `services/cinema/THIRD_PARTY.md` | Upstream attribution and dependency licenses |

The upstream plex-watchparty repository was an architecture reference. This is a separate Go implementation with an Emby provider, not the original Plex server with its URL changed. Plex and Jellyfin adapters have not been implemented.

## What was actually tested

- `go test -race ./...` passes in `services/cinema`.
- Tests cover role enforcement, duplicate commands, stale generations, cookie authentication, cross-origin playlist rejection, CSRF, controller loss and idle cleanup.
- Lobby tests additionally cover unauthorized roster writes, wrong-lobby rejection, nonmember ticket denial, single-use/expired tickets, disabled invitation bypass, viewer control denial and media denial after membership removal/host lease expiry.
- Real Emby catalogue and HLS requests succeeded.
- Real 1920×1080 playback worked in Chromium and in native macOS Godot 4.7.2 using WRY.
- **Three actual Godot game processes** joined one isolated ENet lobby, entered different cinema seats and automatically obtained player access. This was not just three browser tabs.
- Final three-game run: all three decoded 1080p, no invite/login form appeared, only the host had controls, and all three paused at **312.426 seconds** after a seek.
- Returning from watch mode passed the seat-release/overlay-close assertion. Travelling to the plaza passed the overlay-revocation assertion. All three test processes exited with status 0.
- The native seek test initially exposed a stalled viewer; bounded decoder recovery and background-window synchronization were added before the successful run.

The test uses the real game scene and interaction code, but programmatically moves each test penguin to a seat and invokes interaction. It does not simulate every manual walking/clicking action. It selects the first Emby library title: do not run the harness against a gateway with a real audience watching.

Current local logs, which may be overwritten by another run:

- `/tmp/pengloo-game-host.log`
- `/tmp/pengloo-game-viewer.log`
- `/tmp/pengloo-game-late.log`

The final compatibility-renderer run emitted two OpenGL texture-leak warnings at shutdown. No cinema script assertion failed, but those renderer cleanup warnings have not been investigated. Do not describe all-platform testing as complete.

### Repeat the game test

Use the launch commands above, replacing `res://scenes/world.tscn` with `res://tools/cinema_lobby_smoke.tscn` and adding `--cinema-test=host`, `--cinema-test=viewer`, or `--cinema-test=late` after `--`. Use one host and two joiners, distinct names, and the same isolated port. Start the joiners after the host log says `SEATED`; cold world loading can otherwise exceed the existing lobby handshake timeout. A display and working WRY installation are required.

The host selects/plays a title, seeks, pauses, then stays alive while the viewers test return/travel. Logs print `CINEMA_GAME` observations without tokens. Check that each client decodes video, gets no login prompt, and reaches the shared paused position. Look for `RETURN_AND_SEAT_RELEASE_PASS` and `TRAVEL_REVOKES_PASS`.

## What Claude should improve next

1. Review/merge the feature branch into the game branch being used, resolving overlaps rather than replacing other developers' work.
2. Improve the watch UI and failure/retry states. Preserve seamless lobby entry; do not bring back invitation codes. Add clearer buffering/reconnect feedback and meaningful tests around flaky network/slow decoding.
3. Decide how to render the movie on the actual 3D screen. The native WebView overlay is not a Godot video texture. Keep one decoder/audio owner per client when switching between room view and close-up.
4. Connect movie volume/mute to the game's audio settings. The webview currently owns its own volume slider and does not route through Godot's Movie bus.
5. Add subtitle/audio-track selection, playback progress reporting, and proper end-of-film handling. The current Emby profile is a simple H.264/AAC target around 6 Mbps.
6. Add dedicated-server/player authentication and multi-lobby routing for public hosting. This implementation trusts the current listen host and its roster; it does not fix the existing game protocol's client-reported locations or add account login.
7. Deploy the gateway behind HTTPS at `pengloo.party/cinema/`, preserving Origin/cookies/Range and disabling buffering for SSE. Bind the service privately and keep all keys server-side. There is a Dockerfile, but it has not been built/deployed in these tests.
8. Verify the complete Godot web export. Include `/cinema/bridge.js` in the HTML shell on the same origin, exclude native WRY and server/docs content, and account for the game's ENet transport not being a browser-ready multiplayer transport. The browser media page is tested; the full browser game is not.
9. Verify Windows/Linux native playback and package their OS webview dependencies. Only macOS native playback was exercised here.
10. Add operational limits, observability and segment caching/coalescing before a large audience. Current sessions are in memory and the proxy has no shared segment cache.

## Quick troubleshooting

- **Player page asks you to enter from the game:** open a seat/kiosk in the cinema; a raw browser tab is not a lobby member.
- **Cinema unavailable in game:** check the gateway health, host's private env path and game-server key, and matching player/gateway URL. Don't solve this by embedding a key in client code.
- **Native player tries pengloo.party locally:** launch with `PENGLOO_CINEMA_URL=http://127.0.0.1:8095/cinema/`.
- **Another active lobby error:** stop/release the old test host or use a separate gateway; wait for its membership lease to expire. Don't disable lobby isolation.
- **Wrong peers or host cannot bind:** another test may be using port 7777. Set `PENGLOO_PORT=17895` consistently, or choose another unused port.
- **Emby request fails:** verify the private API key and resolved user ID without printing them, preserve the provider's User-Agent, inspect HTTP status, and check upstream access/transcoding capacity.
- **Seat works but no player overlay:** confirm this checkout/branch has the `CinemaClient` autoload and the activity markers in `scripts/cinema.gd`.
- **No WebView class:** check `addons/godot_wry/WRY.gdextension`, matching native binary and platform dependencies. Headless mode cannot display native playback.

## Suggested prompt for Claude

> Read `Cinema - Claude Handoff and Local Setup.md` in `/Users/nick/Documents/club penguin hackathon`. Work from the `feature/cinema-emby` implementation/PR #2 and inspect the target game's current branch before merging. The cinema already supports automatic host-authorized lobby entry and tested three-player native playback. Improve its game integration and UX, preserve the no-invite-code flow, and keep `/Users/nick/.config/pengloo/cinema.env` private. Be explicit about what you have actually tested; the 3D screen video, public deployment and complete browser game still need work.
