# Sketch Club Game

The drawing-telephone game at the Sketch Club table, implemented in the Godot game ([GAME_DESIGN_CONTEXT](../GAME_DESIGN_CONTEXT.md) §15, [Dev Handoff - Activity Specifications](../Dev%20Handoff%20-%20Activity%20Specifications.md)). Hub: [Art Pipeline](../Art%20Pipeline.md) · UI: [UI Implementation](UI%20Implementation.md).

## How to play

1. Walk to the communal table in the Sketch Club pavilion and sit on any stool (press F). The penguin plays the sketch sit clip, and the Sketch Club screen opens on the lobby.
2. **Ready** when everyone is seated. The game starts when every seated player is ready and there are at least `min_players` (default 3). Seat order locks at that moment.
3. Rounds alternate: **prompt** (write an idea) → **draw** (draw the text you were handed) → **guess** (describe the drawing you were handed) → draw → … until every player has added once to every chain.
4. **Reveal:** the host (the first seated player) steps through each chain entry by entry with contributor names, then chooses **Play again**. The latest revealed drawing also appears on the easel beside the pavilion for anyone watching.
5. **Leave** at any time: it frees the stool and your slot. Players who aren't seated can open the screen to watch: lobby, progress and reveal.

## Rules (SketchGame)

- **Chain rotation:** N players make N chains. In round r, slot s works on chain (s − r) mod N; round 0 is the prompt, odd rounds draw, even rounds guess. Every slot contributes once to every chain.
- **Timers** run on the host clock (prompt 30 s, draw 75 s, guess 30 s; `SketchGame.times`). A round ends when everyone has submitted or the deadline passes.
- **Timeouts and leaving:** a missing turn becomes an explicit **skipped** entry, and the next player gets a fallback instruction ("Draw anything you like!"). A player who leaves or disconnects keeps their slot; nobody is reindexed. Reconnecting with the same name before the game ends restores the slot and its current task.
- **Quiet rounds:** `view.quiet` is true during private rounds. The UI shows "voice paused". Real voice routing isn't implemented yet; this is the flag it will read.

## Network (host-authoritative)

The host, or the solo player, owns the `SketchGame`. Clients only send intents and receive their own view.

| Message | Direction | Content |
| --- | --- | --- |
| `request_intent(action, value)` | client → host (rpc_id 1) | `join`(name), `leave`, `ready`, `submit`(text, or drawing bytes), `next`, `again` |
| `deliver_view(view)` | host → one peer (rpc_id) | That peer's view only |

- **View contents:** phase, player names, ready flags, seconds remaining, submitted count. In private rounds it also carries **only that peer's assignment**: the previous text when drawing, the previous drawing when guessing. Chains are never broadcast. Reveal entries go to everyone only once revealed.
- **Drawings:** `SketchStrokes` bytes. Per stroke: RGB, width and point count, then points as u16 x/y. Capped at 400 strokes and 6000 points, and malformed data decodes to empty.
- **Who controls the reveal:** only the host peer can advance it or restart.
- **Moving to a dedicated server later:** all host logic sits in `SketchClub._host_*` plus `SketchGame`, so a dedicated server can take the host role without changing clients.

## Files (game repo)

| File | What |
| --- | --- |
| `scripts/activities/sketch_game.gd` | Rules and views (pure, no networking) |
| `scripts/activities/sketch_strokes.gd` | Stroke wire format |
| `scripts/activities/sketch_club.gd` | `SketchClub` autoload: networking, phase animations, easel |
| `ui/activities/sketch/sketch_ui.gd` | Screens (the UI builder's design, now on live state) |
| `ui/activities/activity_screens.gd` | Opens the screen and wires its intents to `SketchClub` |
| `scripts/world/town_builder.gd` | Turns the communal table's `socket_seat_*` into joinable seats |
| `tools/tests/sketch_game_test.gd` | Headless rules test |
| `tools/sketch_mp.tscn` | Multi-instance localhost test with screenshots |

**Config:** `SketchClub.min_players` (or the command-line flag `--sketch-min=2`), and `SketchGame.times` and `max_players` (6, the table's seat count).

## Seated animations

Each phase sets a seat style that replicates to other players: `sketch_think` (prompt and guess), `sketch_draw`, `sketch_wait` (submitted) and `sketch_reveal`. Standing up plays `sketch_stand`.

## Status

**Working and tested:**
- full rules;
- privacy;
- timeouts and skips;
- rejoin;
- the reveal and play again;
- the multi-instance game over real ENet.

**Not done:**
- Voice muting (no voice system yet).
- The drawing pads on the table stay blank; only the easel shows reveals.
- A spectator in a different room doesn't get reveal updates. Reveal views go to everyone in the session, but the easel only exists in the town.
- The host role is the first seated player, not the network host. Host handoff happens implicitly when the host leaves: the next connected seat becomes host.
