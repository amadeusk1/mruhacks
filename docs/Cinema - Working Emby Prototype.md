# Cinema — working Emby prototype

Updated 2026-10-24. Source: `services/cinema/README.md` in the game repository.

The Emby server at `emby.saladsync.ca` (NickFlix, 4.8.11.0) is connected using Nick's account. API credentials and invitation codes live only in `~/.config/pengloo/cinema.env`, outside Git and this vault.

## What works

The cinema kiosk and auditorium seats launch a close-up watch overlay. The server provides library search, a shared screening, host-only selection/play/pause/seek, viewer sessions, and authenticated HLS streaming. Media credentials never enter the browser. Native Godot uses the operating system webview through Godot WRY; the web client has an iframe bridge.

Live tests played a real 1920×1080 Emby stream in Chromium and a native Godot 4.7.2 window on macOS. Two independent browsers were about 0.41 seconds apart during playback and 0.085 seconds apart after a seek; both paused at 310.065 seconds. Viewers could not use host controls. Automated Go race tests cover authentication, permissions, command deduplication, stale media, playlist rewriting, origin restrictions, controller loss and idle cleanup.

## Local use

Run `go run . --env ~/.config/pengloo/cinema.env` from `services/cinema` and open http://127.0.0.1:8095/cinema/. Invitation codes are in the private configuration file. Launch the native game with `PENGLOO_CINEMA_URL=http://127.0.0.1:8095/cinema/` to use this local service.

## Still needed

- Render video onto the 3D auditorium screen. The working implementation is close-up watch mode.
- Replace shared invitations with game-issued tickets and server-checked room membership before public release.
- Deploy behind HTTPS at `pengloo.party/cinema/`; public hosting has not been configured.
- Verify the complete Godot web export with its same-origin bridge, and native Windows/Linux playback.
- Add per-room screenings, subtitle/audio-track selection, progress reporting, moderation and production monitoring.
- Connect movie volume to game settings; the embedded player currently has its own slider.

The original plex-watchparty repository informed the architecture. This implementation uses a new Emby provider; Plex and Jellyfin adapters are not implemented. See the source README and third-party notices for setup and licenses.
