# Interior Review

A review of every interior against the multiplayer vision ([GAME_DESIGN_CONTEXT](../GAME_DESIGN_CONTEXT.md) §3, 4.3, 7, 8, 9, 10, 15 and [Dev Handoff - Activity Specifications](../Dev%20Handoff%20-%20Activity%20Specifications.md)). The game repo is on branch `art/town-map`. Fixes landed in commit 7360b7d and the commits before it. Setup details are in [Game Setup](Game%20Setup.md).

Status key: ✅ meets it · 🔧 fixed in this review · ⚠️ open (needs gameplay, a service, or the teammate).

## Shared fixes (all rooms)

| Check | Status | What changed |
| --- | --- | --- |
| Claimable, net-safe seats | 🔧 | New `SeatSpot` interactable. Seats claim through the teammate's host-checked seat API (`Net.claim_bench`, `bench.gd`-style keys `<location>:<path>`). They release on standing up and stand the player up at the nearest walkable point. Before this, café and arcade seats and the cinema's 12 seats were props or colliders only, and the casino keys only passed the host check by coincidence. |
| Two players, one seat | 🔧 ✅ | Tested with two clients on localhost (host plus join): the second player was refused the occupied roulette seat and took the next one. |
| Presence | 🔧 ✅ | New `Net.note_act` and a roster `act` field, the same pattern as the teammate's fishing phase. Other players see each seated or station clip: casino, cinema, arcade, stool, armchair. Two-client check: each sees the other in `casino_seated_idle_loop`. |
| Prompts | 🔧 | Only the nearest usable interactable shows its "F …" prompt; tables have many seats. |
| Voice room ids | 🔧 / ⚠️ | Each interior is its own location id (`cafe`, `arcade`, `casino`, `cinema`, `home:<owner>`), and the teammate's `Net._same_room` already scopes presence to it. The cinema lobby and auditorium share one location, so `cinema.voice_room_at(pos)` returns `cinema_front`, `cinema_lobby` or `cinema_hall` for the voice layer (§8). Voice itself isn't implemented yet. |
| Silhouette | 🔧 | The always-on teal overlay tinted the penguin indoors. It now shows only while something covers the penguin. |

## Per room

### Café (`cafe`, `Renders/Details/game_review_cafe.png`)

| Check | Status | Notes |
| --- | --- | --- |
| Seats | 🔧 | 8 claimable stools, 4 around each of 2 round tables, so friends sit together. Back-up-and-sit clip, then seated idle. |
| Circulation | ✅ | The front door is 1.4 m wide (two penguins); there's an open strip between the tables and the counter. |
| Exit | ✅ | A walk-out door back to the town café door. |
| Camera | ✅ | The cutaway shows the whole room. |
| Finish | ✅ | Counter, pastry case, coffee station, shelf, menu board, mugs, breakfast tray (concept 04). |

### Arcade (`arcade`, `game_review_arcade.png`)

| Check | Status | Notes |
| --- | --- | --- |
| Stations | 🔧 | 6 claimable stations: 4 solo cabinets and the duo cabinet's two side-by-side stations (`socket_player_1/2`, 0.64 m apart, §10). They play `arcade_enter`, then the `arcade_play` loop, and emit `Activities.requested("arcade")`. |
| Spectators | ✅ | A free floor zone in front of the cabinets, plus a bench and stool along the side. |
| Shared session | ⚠️ | Two stations on one cabinet are claimable separately. The shared Puck Rally session (ready, play, results) belongs to the activity UI and server. |
| Camera | ✅ | The front wall is trimmed at load (a stopgap until the kit ships a `*_cutaway`). |

### Casino (`casino`, `game_review_casino.png`)

| Check | Status | Notes |
| --- | --- | --- |
| Seats | 🔧 ✅ | Roulette 4, poker 6, blackjack 5, slots 4 (tinted slot row with stools), lounge 2. Hop on, seated idle, leave. Games emit `Activities.requested(roulette/poker/blackjack/slots)`. |
| Spectators | ✅ | A central carpet aisle and space between the tables. |
| Finish | ✅ | Lamps, wall lamps, planter, coat stand, warm lights; the roulette rotor spins. |

### Cinema lobby and auditorium (`cinema`, `game_review_cinema.png`, `game_review_cinema_hall.png`)

| Check | Status | Notes |
| --- | --- | --- |
| Seats | 🔧 | 12 auditorium seats from the model's sockets, all facing the screen (3 rows of 4, §9). They play `cinema_sit`, then the `cinema_watch` loop. There are also 4 lobby seats on the sofas. |
| Rows and aisle | ✅ | The teammate's row colliders leave a side aisle, and the exit door is on the aisle. |
| Voice | 🔧 | `voice_room_at()` separates the auditorium audio from the lobby. |
| Spawn height | ⚠️ | `world.gd` places arrivals at y = 0.2, so the `InsideScreen` spawn on the raised tier sinks the penguin. This is the teammate's travel code. |
| Playback | ⚠️ | The screen insert and shared playback belong to the cinema integration. |

### Igloo / home (`home:<owner>`, `game_review_home.png`)

| Check | Status | Notes |
| --- | --- | --- |
| Visiting friends | 🔧 | Added a two-seat sofa and an armchair, for 3 claimable seats with armchair clips. The bed's seat socket isn't picked up yet. |
| Rooms | ✅ | One room per owner (`home:<id>`), with the teammate's invite flow. |
| Decoration | ⚠️ | Grid editing with the `cells` meta belongs to the UI and housing builder. |

### Homes shells (`Models/homes`)

| Check | Status | Notes |
| --- | --- | --- |
| Cell masks, wall slots, spawn and exit | ✅ | In the manifests, ready for the housing editor. Only the snow dome is wired into the game so far (the teammate's igloo). |

## Screenshots

| Room | Before | After |
| --- | --- | --- |
| Café | `art/_wip/scene_cafe_play.png` | `art/_wip/scene_review_cafe.png` |
| Arcade | `scene_arcade_play.png` | `scene_review_arcade.png` |
| Casino | `scene_casino_interior.png` | `scene_review_casino.png` |
| Cinema | `scene_cinema_lobby.png`, `scene_cinema_auditorium.png` | `scene_review_cinema.png`, `scene_review_cinema_hall.png` |
| Igloo | `scene_home.png` | `scene_review_home.png` |
