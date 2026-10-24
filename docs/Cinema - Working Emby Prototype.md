# Cinema — working Emby prototype

Updated 2026-10-24. Source: `services/cinema/README.md` in the game repository.

The Emby server at `emby.saladsync.ca` (NickFlix, 4.8.11.0) is connected using Nick's account. API credentials and the game-host key live only in `~/.config/pengloo/cinema.env`, outside Git and this vault.

## What works

The cinema kiosk and auditorium seats launch a close-up watch overlay. The server provides library search, a shared screening, host-only selection/play/pause/seek, lobby-authorized viewer sessions, and authenticated HLS streaming. Media credentials never enter the browser. Native Godot uses the operating system webview through Godot WRY; the web client has an iframe bridge.

Live tests played a real 1920×1080 Emby stream in Chromium and a native Godot 4.7.2 window on macOS. Two independent browsers were about 0.41 seconds apart during playback and 0.085 seconds apart after a seek; both paused at 310.065 seconds. Viewers could not use host controls. Automated Go race tests cover authentication, permissions, command deduplication, stale media, playlist rewriting, origin restrictions, controller loss and idle cleanup.

## Local use

Run `go run . --env ~/.config/pengloo/cinema.env` from `services/cinema` and open http://127.0.0.1:8095/cinema/. Players enter through a cinema seat or kiosk without an invite code. The trusted host reads the private config and supplies a one-use ticket only to the requesting lobby peer. Opening that URL directly shows instructions to enter from the game. Launch the native game with `PENGLOO_CINEMA_URL=http://127.0.0.1:8095/cinema/` to use this local service.

## Still needed

- Render video onto the 3D auditorium screen. The working implementation is close-up watch mode.
- Add dedicated-server account authentication for public rollout. Game-issued tickets and host-checked cinema membership are now implemented; they trust the existing listen-server roster.
- Deploy behind HTTPS at `pengloo.party/cinema/`; public hosting has not been configured.
- Verify the complete Godot web export with its same-origin bridge, and native Windows/Linux playback.
- Add per-room screenings, subtitle/audio-track selection, progress reporting, moderation and production monitoring.
- Connect movie volume to game settings; the embedded player currently has its own slider.

The original plex-watchparty repository informed the architecture. This implementation uses a new Emby provider; Plex and Jellyfin adapters are not implemented. See the source README and third-party notices for setup and licenses.


## Lobby integration update

No separate cinema sign-in is required. The host validates the actual RPC sender against its cinema roster, creates a 30-second one-use ticket, and delivers it only to that peer. Ticket exchange establishes the embedded player's cookie session; the ticket is removed from the URL immediately. Clients never receive the Emby API key or game-host service key. A host heartbeat maintains membership, leaving the cinema revokes it, and host loss expires access within fifteen seconds. A gateway rejects another simultaneously active lobby.

Three real Godot game instances were tested in the same ENet lobby, entering separate auditorium seats and receiving automatic playback access. All three decoded 1080p video, viewers had no host controls, and all three reached the same paused timestamp after seeking. Return released the viewer's seat. This supplements the earlier two-browser test; it does not imply production deployment or 3D screen-texture playback.

For exact paths, startup commands, configuration and follow-up work, see [Cinema - Claude Handoff and Local Setup](Cinema%20-%20Claude%20Handoff%20and%20Local%20Setup.md).
