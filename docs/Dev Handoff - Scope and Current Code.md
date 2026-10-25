# Scope and Current Code

[Dev Handoff - Start Here](Dev%20Handoff%20-%20Start%20Here.md)

## Required product scope

| Area | Required experience | Smallest complete delivery |
| --- | --- | --- |
| World | Cozy shared snowy town, legible destinations | One compact hub with connected activity spaces and private home instances |
| Penguin | Same base rig, separate hats/clothes/accessories, body tint | Saved appearance, responsive waddle, emotes, reusable seated/held poses |
| Social | Presence and proximity voice | Join/leave, visible speaking/mute state, clean room routing |
| Cinema | Browse personal media source and watch together | One real playable source and synchronized screening |
| Arcade | Solo and two players at ONE cabinet | One complete shared game with AI opponent for solo |
| Fishing | Active vertical-band catch minigame | Cast through result with nearby friends visible |
| Sledding | Complete downhill activity | Start, ride, finish, retry and exit |
| Snowballs | Sensible arena and complete match | Teams/participation, throw, cover, hit, respawn, result |
| Basketball | Play basketball in the world | Proposed practice/shooting contest; full possession game remains open |
| Drawing telephone | Integrated prompt/draw/guess/reveal | Complete multi-round session, private assignments and synchronized reveal |
| Housing | Player decoration on a grid | Placement, rotation, validation, save/load and owner permissions |
| UI | Simple original menus titled Pengloo Party | Full lifecycle and error states, not only happy-path screens |
| Online backend | Play from separate machines/networks | Dedicated authoritative session server, identity and persistent saves |

## Observed repository baseline

Static inspection on 2026-10-24 after pulling game commit `533da1f` (subsequent documentation commits do not change this observation):

- `project.godot` requests Godot 4.7/Forward Plus, 1280×720, boots through `scenes/startup.tscn`, and names the project Pengloo Party. The playable title screen is `ui/screens/main_menu.tscn`.
- `scripts/net.gd` implements solo/host/client ENet, port 7777, hardcoded `127.0.0.1`, roster, room presence, chat and bench occupancy. `create_server(PORT, 8)` is a prototype argument, not an approved production world capacity.
- The prototype relays client-produced poses every 0.05 seconds and uses host-owned roster/bench state. This is not proof of server-authoritative movement, identity authentication, persistent saves or internet hosting.
- `scripts/lobby.gd` provides Host/Join/Solo and name input. The world-list mockup is a proposed future flow, not implemented matchmaking.
- `scripts/locations.gd` lists home, plaza and sled_hill. Full destination catalog is not yet demonstrated by that list.
- `scripts/sled_run.gd` has a local countdown, ride, crash/finish and retry flow. It must be integrated with authoritative activity state before claiming synchronized race results.
- `project.godot` references a Travel autoload at `scripts/travel.gd`, but that file was absent from the inspected tracked checkout. Resolve this startup reference or restore the intended script before a build gate can pass. This is a static finding, not a runtime test result.

Existing code and models are starting points. Do not replace working code just to match a hypothetical architecture. First run and characterize it, then adapt the existing Net/room/UI code to the contracts below. Static inspection was bounded; absence from this inventory is not proof no other implementation exists.

## Out of scope unless explicitly chosen

Currency, monetization, shops, battle passes, hunger, crafting, vehicles, arbitrary structural house building, unlimited server capacity and public account recovery. Decorative props do not create these requirements. Friend requests, reporting, visitor controls and alternate house types are UI proposals that need actual services before shipping enabled controls.

## Confirmed hosting and future platform update

The team will self-host the server. A browser client on its own domain is also required eventually. The observed native ENet and Forward Plus baseline therefore needs an early compatibility proof and deliberate transport/rendering choices; see [Dev Handoff - Self Hosting and Browser Release](Dev%20Handoff%20-%20Self%20Hosting%20and%20Browser%20Release.md). These requirements are documented, not implemented by this handoff.
