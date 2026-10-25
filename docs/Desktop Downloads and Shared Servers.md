# Desktop downloads and shared servers

The website has a `/download/` page for native Pengloo Party clients. Desktop players use the same public WebSocket server as browser players: `wss://pengloo.party/multiplayer`. No invite code, local server or environment variable is required to join the island.

## Player flow

Download for your OS, extract everything, open the app, press Play, choose your penguin, then **Pengloo Party → Join world**. Practice Island remains solo play. Internet is required for the shared world. Native downloads are early preview builds; Windows runtime and graphical Linux coverage are explicitly listed on the page rather than implied tested.

## Implementation

- `desktop_online` is a custom export feature on the three desktop presets. `Net.public_client()` exposes the public online lobby for web and those desktop exports.
- Desktop defaults to the public WSS endpoint. `PENGLOO_WS_URL` still overrides it for development. Editor/LAN hosting and the dedicated-server export retain their existing defaults.
- This is the same game/network protocol. There is no second native-only server or port.
- Mac universal builds require ETC2/ASTC texture imports. Desktop exports include music and the TwoVoIP libraries; the web/server presets continue excluding those native voice libraries.
- Native cinema already uses `https://pengloo.party/cinema/`; the download change does not claim acceptance coverage for every native cinema/voice feature.
- The download page reads `manifest.json` with real archive filenames, sizes and SHA-256 hashes. Versions live under `/download/VERSION/` to avoid replacing bytes behind an existing release URL.
- The web loading screen and menu link to the download page. Direct browser play remains the default at `/`.

## Build and package

Use matching Godot 4.7.2 templates for Windows x86_64, macOS universal and Linux x86_64. From the checkout:

```sh
GODOT='/path/to/Godot' ./deploy/build-desktop.sh
```

`deploy/package-desktop.py` packages the exports, README and license notices, then creates `builds/web/download/manifest.json` and per-release SHA256SUMS. Set `DESKTOP_VERSION` to a unique release identifier for repeatable release naming. Never reuse an existing published version for different files.

Upload archives first, then atomically publish the new manifest and page. Preserve prior download versions when publishing new web builds. `deploy/build.sh` builds the browser game separately; it does not export desktop clients. A website update must preserve or copy the existing `download/` directory.

## Signing and testing

Mac uses ad-hoc signing, not Developer ID notarization. Windows is unsigned. Production distribution should add signing/notarization credentials privately; never commit signing keys or passwords. System approval prompts are expected for previews. Offer browser play as the alternative; do not tell users to disable system protections globally.

Verify an extracted native release joins the public WSS service without an environment override. Test desktop/browser roster and movement on matching builds. Check archive contents and download checksums before publishing. An exported binary alone is not proof of platform runtime compatibility.

## Follow-ups

- Signed Windows releases and Apple Developer ID notarization.
- Full Windows/Linux graphical, voice and cinema acceptance tests.
- Native update notification and protocol-version compatibility checks; today users download a new build after server updates.
- Durable account identity and cloud saves remain separate work. Local profile files are not shared cross-device accounts.
- Preserve downloads across deployments, or move them to persistent object storage before larger distribution.

References: [Godot macOS export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html), [Windows export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html).
