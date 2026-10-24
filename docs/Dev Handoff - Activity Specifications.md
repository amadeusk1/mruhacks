# Activity Specifications

[Dev Handoff - Start Here](Dev%20Handoff%20-%20Start%20Here.md) · [Dev Handoff - Data and Network Contracts](Dev%20Handoff%20-%20Data%20and%20Network%20Contracts.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md)

All seven activities share join/leave, phase, occupancy, input focus, reconnect and authoritative timing contracts. Exact numerical defaults below remain proposals from the brief, not locked requirements.

## Cinema

Flow: kiosk/library → select film → reserve seat → watch → leave. State: mediaId/providerRef, controllerId, playback state, position at authoritative timestamp, participants and seat slots. Controller sends play/pause/seek requests; server accepts and broadcasts a new reference position/time. Clients catch up after buffering or late join. Define drift threshold and resync policy during playback tests, avoiding constant disruptive seeks. If controller leaves, transfer explicitly or pause and request a new controller.

Required UI: search/browse, source status, selected film, movie/voice volumes, who is watching, leave seat, buffering/failure/reconnect. Demo artwork is not a connected library. Test two machines with independently authorized playable media, late join, seek, pause, buffering and controller loss. Failure to fetch media must not trap an occupied seat.

## Arcade

One cabinet, two explicit player slots; solo uses AI in the second role. Proposed first game: paddle/puck match. Phases waiting → ready → playing → results. Server owns paddles' valid movement, puck/collisions, scores and end state. A mid-game join queues for next round rather than hijacking the AI slot. Spectators receive public state but no control. Releasing a participant must end or transition the game under a documented policy.

Test solo completion, two remote players on the SAME cabinet, third-player spectator, duplicate ready, disconnect and replay. A readable local board is mandatory; a tiny cabinet screen alone is insufficient.

## Fishing

Flow cast → wait → bite → hook → reel → catch/escape → retry/leave. Reserve one fishing spot. State includes attemptId, phase/deadline, fish behavior seed/configuration, band state and catch progress. Client sends input intent; authoritative logic validates the attempt and produces result. The visible fish must be kept inside a moving catch band; progress rises on overlap and falls outside, with initial grace so a round does not instantly fail.

World rod/line/bobber and nearby players remain visible; only participant gets the catch UI. Others see activity phase/reactions. Keep line attached to rod tip and bobber. Test cast cancellation, missed bite, success, escape, two neighboring spots, duplicate result and reconnect. Fish catalog/economy expansion is optional.

## Sledding

Flow ready/countdown → run → finish/result → retry/leave. A short safe course, broad stopping zone and separate return path are required. Proposed first mode is time trial; shared race remains an option. State: runId, start time, current checkpoint/progress, valid course position, finish time and result. Server verifies ordered checkpoints and finish; clients cannot submit final best times as truth. Reset teleports both sled and rider to a valid reset point with a fresh/penalized attempt according to selected rules.

Existing local crash behavior is a prototype, not a required design. Decide crash/reset and sled collision policies explicitly. Test identical start clocks, invalid shortcut rejection, off-course reset, safe dismount, finish only once and retry cleanup.

## Snowballs

Proposed first format: two teams, compact balanced arena, hit scoring and quick respawn. Defaults in the brief: 2v2, two minutes or ten hits, unlimited snowballs with cooldown, about three seconds to respawn. Keep these configurable. State: roster/team, ready phase, scores, accepted throws/projectiles, respawn deadline and protection flags.

Server validates throw origin/direction/cooldown, resolves collisions against visible cover, scores accepted opponent hits once, ignores friendly-fire scoring and stops scoring at match end. Spawn protection ends on throwing. Spectators cannot interfere. Team identification is separate from body color. Test cover, mirrored spawns, both flank routes, duplicate hits, disconnect imbalance policy, protection and match reset.

## Basketball

Confirmed activity, unresolved final mode. Proposed initial shooting contest: player slots, timed attempts, hold/release power band, accepted shot sequences and synchronized trajectories/results. Server validates phase/cooldown/input and determines made/missed shot, then publishes the shot event and score. Do not accept client score values. Individual balls can be noncolliding in this mode.

Full possession-based 1v1/2v2 is a separate extension requiring authoritative possession, pickup, dribble, pass, steal/defense, out-of-bounds and scoring. Do not label the shooting contest a complete team game. Test solo practice, concurrent shooters, duplicate shot requests, late spectator, result agreement and replay.

## Drawing telephone

Flow lobby → initial prompt → alternating draw/guess rounds → synchronized reveal → replay. Lock ordered roster at start; one chain per participant, each contributes once per chain. Suggested 3–8 players and 30/75/30-second prompt/draw/guess timers are configurable. A fixed roster must survive disconnects; timeouts create explicit skipped entries without reindexing participants.

Server stores chains privately and sends only the current assigned predecessor content. Submitted work locks for the round. Public state may include readiness counts, never hidden text/strokes. Stroke data has bounded count/points/size and normalized coordinates. Reveal exposes only entries through current reveal position; later entries remain private. Quiet-round voice is a proposed setting; restore prior mic intent at reveal.

Test complete chains for different roster sizes, submit twice, timeout, disconnect/reconnect, no hidden data in spectator/public messages, host/reveal controller loss and clean next game. The final contribution may be a drawing or text; do not force all chains into one shape.

## Shared acceptance

Every activity must pass happy path, early cancel, occupied slot, invalid request, simultaneous join, late join/spectate, disconnect, reconnect/expiry and replay. Input, cursor, camera and voice state must restore correctly every time. Result effects may play after accepted state; they do not decide scores. Show understandable unavailable/demo states when a dependency is missing.

## Cross-platform activity acceptance

The eventual browser client must share activity state with native players. Verify cinema playback and voice integration early, then test every activity with mixed native/browser participants. Browser suspension must not pause server timers or leave stale input active. See [Dev Handoff - Self Hosting and Browser Release](Dev%20Handoff%20-%20Self%20Hosting%20and%20Browser%20Release.md).


## Plex cinema integration update

The user selected plex-watchparty as the base for the first Plex integration. See [Cinema - Plex Watchparty Integration Plan](Cinema%20-%20Plex%20Watchparty%20Integration%20Plan.md) for verified source behavior, required adaptations and implementation gates. Playback adapters and deployment remain to implement.
