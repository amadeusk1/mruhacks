# Third-party sources

- Architecture reference: [rawsocket-dev/plex-watchparty](https://github.com/rawsocket-dev/plex-watchparty), commit b1c1ceccda030a2f03128baad98c7c3daf8893c3, MIT (`UPSTREAM-LICENSE`). Pengloo's server is a separate implementation with an Emby adapter, not the original Plex server with a changed URL.
- `web/hls.min.js`: hls.js 1.6.16, obtained from the above upstream checkout. Apache-2.0 (`HLS-LICENSE`), [video-dev/hls.js](https://github.com/video-dev/hls.js).
- `../../addons/godot_wry`: Godot WRY v1.0.2 release binaries, [doceazedo/godot_wry](https://github.com/doceazedo/godot_wry/releases/tag/v1.0.2), MIT (license in addon directory). Universal macOS, x86_64 Windows and Linux binaries included. Examples omitted; hot reload disabled because the WebView class does not support it. Native-only; exclude from web exports.
