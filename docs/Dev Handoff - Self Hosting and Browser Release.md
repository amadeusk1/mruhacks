# Self Hosting and Browser Release

[Dev Handoff - Start Here](Dev%20Handoff%20-%20Start%20Here.md) · [Dev Handoff - Server and Deployment](Dev%20Handoff%20-%20Server%20and%20Deployment.md) · [Dev Handoff - Delivery and QA](Dev%20Handoff%20-%20Delivery%20and%20QA.md)

## Confirmed requirements and implementation status

The game will run on the team's own server. An eventual browser client on its own domain is required. Desktop-first delivery is a proposed sequence, not permission to defer browser compatibility decisions. Mobile browser support is not yet confirmed. This is a deployment and implementation specification; no server, DNS record, certificate or browser build has been provisioned by this document.

## Proposed deployment

Use one public HTTPS entry point with a reverse proxy, a static web client, application API, authoritative headless Godot world process, and private persistent database. Keep these components separately restartable. Start on one host if measured capacity permits. Voice may need a separate signaling/relay service; cinema needs an authorized media delivery path.

Illustrative routes on `game.example.com` (placeholder, not a selected domain): `/` serves the web export; `/api/` routes to the application service; `/game/` upgrades to WSS if WebSocket is selected. Keep the API and game connection same-origin where practical. Expose neither the database nor internal administration endpoints publicly. The proxy must support WebSocket upgrade and appropriate idle timeouts. Retained ENet traffic or voice relay traffic requires its own explicitly configured network path.

The server owns world state, activity clocks, contested actions and saves. Closing or suspending a browser tab must never stop the world or promote a client to server authority.

## Early compatibility proof

The current project uses Forward Plus and native ENet. Godot web exports require WebAssembly and WebGL 2.0 and use the Compatibility renderer. Start by exporting a representative scene using Compatibility, then inspect lighting, materials, transparency and effects against the concepts. Single-thread export is the initial candidate; threaded exports require cross-origin isolation, which must also be checked against third-party media and voice dependencies. These are constraints to verify against the pinned engine/export-template version. [Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

Browsers cannot use the current ENet transport directly. WebSocket is available to both native and web Godot clients, but its reliable TCP delivery needs latency testing for fast activities. WebRTC is another candidate with different signaling/relay requirements. [Godot WebSocket documentation](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html).

Prototype a common native/browser transport before building the full networking layer. A shared WSS implementation is a reasonable first experiment, not a finalized decision. Native ENet and browser WebSocket peers do not automatically participate in the same Godot multiplayer session. If retaining both, explicitly design and test the gateway/session routing and authority model; otherwise use the selected common transport on both platforms.

Keep gameplay commands, snapshots, authentication, protocol versions and reconnect behavior separate from transport implementation. Define delivery and sequencing needs per message. On reliable-only transport, coalesce stale pose updates before enqueueing and bound queues; do not pretend an unreliable channel exists. Test movement, sled racing, snowball hits and basketball under delay, loss and reconnect conditions before accepting the transport.

The proof must include one desktop and one browser client sharing the same world, a durable home save, browser microphone audio, and synchronized cinema playback from a real supported source. Record actual browser/OS versions and results.

## Browser behavior

- Entry requires an explicit user interaction to enable audio; show permission denial and muted states truthfully. Request the microphone only when voice is enabled, with a clear retry path.
- Test microphone permissions, audio output, voice routing and echo behavior in supported browsers. A working native SDK does not prove web support.
- Prove the chosen cinema player, media format, source authorization and cross-origin policy in web exports. An HTML video bridge may be needed; decide through a prototype. Keep playback time authoritative and handle buffering, blocked playback and late joins visibly.
- Handle tab suspension, focus loss, resizing, refresh, expired sessions and network changes. On resume, obtain current server state instead of replaying stale actions. Release held movement/buttons when focus is lost.
- Persist profiles and homes on the server. Browser storage is a session convenience, not the only copy of ownership or decoration data. Document guest recovery and cross-device login policy.
- Handle keyboard focus between game, text input and browser shortcuts; keep controls remappable. Do not assume pointer lock, fullscreen or clipboard operations always succeed.
- Measure initial download, peak memory, frame time and load transitions on the agreed minimum device. Export runtime assets only; exclude concept boards, source Blender files, documentation and unused resources.

## Own-server preflight

Record the server owner/operator, OS, CPU, RAM, storage, available uplink, public connectivity and intended simultaneous players before sizing the deployment. Establish whether inbound connectivity is possible through the actual router/firewall and whether CGNAT or a changing public IP needs a deliberate solution. A domain alone does not make a private server reachable.

Select the domain and who controls DNS. Configure correct A/AAAA records only for working network paths, automated TLS renewal and external HTTPS/WSS checks. Use exact trusted origins where cross-origin requests are needed. Keep secrets outside the client and repository. Document every exposed TCP/UDP port and its purpose after the transport and voice stack are selected.

Run services unprivileged with restart supervision, bounded logs and persistent volumes outside release directories. Back up durable data to a separate location and rehearse restoration. Record disk/resource monitoring, readiness checks, restart/drain procedures and the incident contact. One host is a single point of failure; state expected downtime honestly.

## Build and release contract

Pin the Godot version and matching export templates. Produce separately identifiable native, web and headless-server artifacts with a shared protocol/build compatibility policy. Verify web MIME types, compression, headers and all export companion files using the pinned version's export instructions.

Publish the web export atomically so its loader and asset files belong to the same build. Version cacheable assets and ensure the entry document discovers new releases. Verify upgrade behavior with an old tab still open. Reject incompatible clients with a useful reload/update message. Keep the previous complete web build and compatible server artifact for rollback; database migrations require their own compatibility and recovery plan.

Use staging before the live domain. Acceptance includes: fresh visit over HTTPS; two external networks; desktop/browser cross-play; full home save/reload; voice permissions granted/denied; cinema start/seek/buffer/late join; focus and background recovery; server restart; stale cached client; dependency outage; backup restore. Choose supported versions of Chrome, Firefox and Safari through testing and publish the tested matrix. Do not claim mobile support until separately tested.

## Delivery order

1. Early technical spike: Compatibility rendering, common transport, microphone and real cinema playback in browser plus native client.
2. Build the shared authoritative server, API and persistence on the team's own server; preserve cross-platform contracts throughout native feature work.
3. Complete web download/performance, browser UI/input, supported-browser QA, domain/TLS, staged releases and recovery testing before public browser launch.

Domain name, server specifications, initial capacity, supported browser versions and provider/relay choices remain implementation decisions. Self-hosting and the future browser release are confirmed requirements.
