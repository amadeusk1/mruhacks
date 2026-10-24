# Movable Parts and Effects

How models expose things that move (doors, curtains, tree crowns, flags, rims and nets, joysticks) and where effects attach (smoke, steam, splashes, sparkles). This is the asset side of [Animation Kit - Ambient World](../Animation%20Kit%20-%20Ambient%20World.md) and [Prop Kit - Ambient Effects](../Prop%20Kit%20-%20Ambient%20Effects.md). Hub: [Art Pipeline](../Art%20Pipeline.md).

## Movable parts

A movable part is a **child node named `part_<name>`** whose **origin is its pivot**: a door leaf's hinge, a crown's base, a curtain's top edge, a rim's mount. The game moves the node (rotate, slide or sway); nothing is baked into the static mesh.

Each part carries its motion as node properties (glTF extras) and in the manifest under `parts`:

| `motion` | Extra fields | Example |
| --- | --- | --- |
| `hinge` | `axis` (`x`, `y`, `z`), `open_deg` (signed: the swing direction) | Door leaves, gates, mailbox lid |
| `slide` | `dir` [x, y, z], `dist` (m) | Cinema curtains, drawers |
| `sway` | `amp_deg` | Tree crowns, hanging planters, the star mobile |
| `flutter` | `amp_deg` | Flags, pennants, bunting cloth |
| `spin` | `axis` | Fishing reel, ship's wheel |
| `press` | `depth` (m) | Arcade buttons |
| `tilt` | `axis`, `max_deg` | Joysticks, sled steering rope |

Manifest example:

```json
"parts": { "part_door_leaf": { "pivot": [-0.4, -0.12, 0.0], "motion": "hinge", "axis": "z", "open_deg": 100 } }
```

In Godot the part is a `MeshInstance3D` child. Open a door by tweening `rotation.y` (Blender's Z axis becomes Godot's Y) to `deg_to_rad(open_deg)`. Only consequential state (door open or closed) is networked; ambient sway and flutter are local and phase-randomised.

**Authoring (kit scripts):** wrap the geometry in `with b.part(name, pivot=..., motion=..., ...):`. Z-fight fixing still runs over the whole asset before the parts split off, so a leaf flush in its frame is handled.

## Effect emitter sockets

Effects (particles and shaders) attach at sockets named `socket_fx_<kind>`, placed exactly where the effect starts and facing its direction:

| Socket | Where | Effect |
| --- | --- | --- |
| `socket_fx_smoke` | Chimney mouth, just above the cap | Smoke puffs (see the `fx` kit meshes) |
| `socket_fx_steam` | Coffee machine spout, mugs, takeaway cups | Steam wisps |
| `socket_fx_splash` | Where a fountain stream or waterfall lands | Droplets and foam |
| `socket_fx_ripple` | Bobber, fountain basin | Pooled ripple rings |
| `socket_fx_spray` | Sled runners | Brake snow spray |
| `socket_fx_sparkle` | Arcade marquee, celebration points | Small sparkles |
| `socket_fx_flame` | Candles, wood stove firebox | Flicker light and flame quad |

**Lights and glow.** Lanterns, windows and screens already use separate emissive materials (`glow*`, `insert_*`). Pulse their emission energy in the engine with randomised phase.

## Rules (from the ambient brief)

- **No baked motion.** Static meshes stay static; motion comes from parts, shaders or particles.
- **Smoke stays outside.** Smoke never starts inside a wall or indoors; emitters sit above the chimney cap.
- **Bounds and cost.** Particle bounds include the full drift. Cap emission, pool event effects, cull distant effects, and support a reduced-motion setting.
- **Cleanup.** Moving or deleting a decorated prop also removes its emitter.
