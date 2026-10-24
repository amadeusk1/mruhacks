# Delivery and QA

[Dev Handoff - Start Here](Dev%20Handoff%20-%20Start%20Here.md)

## Dependency-ordered milestones

| Milestone | Work | Exit gate |
| --- | --- | --- |
| 0 — Reproducible baseline | Pin engine/export templates, resolve missing references, run existing game, document commands | Clean clone imports and starts; current functionality characterized |
| 1 — Internet vertical slice | Dedicated server entry, identity/join ticket, configurable endpoints, one room, movement and occupancy | Two clients on separate networks join and contend safely for one seat |
| 2 — Durable identity and home | Appearance catalog, saved profile, one shell, grid editor and revisioned saves | Restart server and restore outfit/home; invalid/foreign edits rejected |
| 3 — Voice and cinema risk proof | Choose/test actual providers, permission/mute, one playable source, synchronized playback | Two remote clients hear allowed voice and watch/play/pause/seek same media |
| 4 — First complete minigames | Shared-cabinet arcade and active fishing | Each passes full join/play/result/retry/leave online |
| 5 — Outdoor activities | Sledding, snowballs and chosen basketball mode | Accepted timing/scoring and safe replay/exit agree on clients |
| 6 — Drawing telephone | Private chains, all rounds, reveal, timeout/reconnect | Full group completes session without leaking hidden content |
| 7 — UI/art polish | Shared UI theme, emotes, remaining shells/decor, world effects/audio | Gameplay camera, clipping, readability and performance review |
| 8 — Release rehearsal | Deploy, backups/restore, drain/restart, rollback, distribution | External playtest succeeds from clean client installs |

Provider proof work should happen early even if visual polish follows later. Keep all seven activities in scope, but reduce depth per activity rather than silently omitting one.

## Work packages for developers

**Backend/network owner:** server bootstrap, auth/join, world registry, authoritative activity framework, persistent transactions and deployment. **Client/UI owner:** shared components, focus/router, housing editor, appearance and settings, network error states. **Gameplay owner:** per-activity state machines and server validation with visual feedback. **Art/integration owner:** manifests, rig compatibility, collision, cutaways, effects and scene assembly. **QA/release owner:** reproducible builds, multi-client test harness, failure injection and release evidence. These are responsibilities to assign, not claims that a team has already accepted them.

## Required automated checks

- Clean headless import/start and client/server exports using pinned engine version; fail on missing scripts/resources.
- Schema and catalog validation; unknown IDs, invalid layer/rotation, nonfinite transforms, oversized payloads rejected.
- Slot contention: two requests for one seat produce exactly one owner; disconnect frees or leases it once.
- State-machine tests: invalid phase transitions, duplicate actions and replay after result are rejected/idempotent.
- Home transaction tests: concurrent revisions, remove/undo, shell migration and save failure do not lose/duplicate items.
- Activity logic tests: collisions/score once, shot cooldown, catch progress, ordered sled checkpoints, drawing assignment rotation and private serialization.
- Save migration and backup restore tests on a disposable database.
- Repository doc links and asset manifests validate separately from gameplay integration.

## Manual multi-client matrix

Run at least two clients on different networks, plus a spectator for occupancy modes. Exercise simultaneous join, late join, leave during animation, host/controller departure, server restart, network loss, reconnection before/after lease expiry, provider failure and repeated rounds. Test drawing with enough participants to rotate chains through both text and drawing rounds. Use latency/loss simulation after a stable baseline; record actual conditions and outcomes.

Verify UI at project baseline 1280×720 and a larger desktop viewport with enlarged text. Test keyboard focus, remapped keys, muted/no-microphone play, high-contrast indicators and reduced motion. Do not assume screenshots establish accessibility conformance.

## Performance and release evidence

Choose measurable budgets after target hardware and capacity are selected: frame time, server tick time, memory, bandwidth, load duration and save latency. Record a reproducible busy-hub/activity case and realistic player count. Do not claim the world supports 40 players because a mockup says 18/40.

Every completed feature records build/commit, test conditions, expected and observed results, known limitations and reproduction steps. A release includes client/server versions, protocol version, migration version, checksums, runbook and rollback artifact. Label unimplemented controls and demo media honestly.
