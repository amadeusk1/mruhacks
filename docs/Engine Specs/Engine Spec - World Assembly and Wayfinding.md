# Engine Spec: World Assembly and Wayfinding

**Built in Godot.** Sources: [World Assembly - Completion Checklist](../World%20Assembly%20-%20Completion%20Checklist.md) and [World Kit - Wayfinding and Activity Markers](../World%20Kit%20-%20Wayfinding%20and%20Activity%20Markers.md). The checklist is integration work; this note maps each item to what the art pack already provides, and states what the engine must do. Index: [Engine Specs - Index](Engine%20Specs%20-%20Index.md).

## Traversal and placement

| Checklist item | Art pack provides | Engine must |
| --- | --- | --- |
| Path, bridge, stair, shore and cliff seams at consistent heights | `town_connections` seam grid: 2 m modules on a 1 m sub-grid, path top +0.07 m, steps 0.25 m, landing 0.57 m, water −0.5 m, deck 0. Stored as `seam_grid` meta plus `socket_seam_*` | Snap modules by seam sockets in the level editor. Build walk colliders as flat boxes and ramps per module, not trimesh from the visual cobbles |
| Walkable collision matches visible surfaces; deliberate water and cliff edges | Water surfaces are separate meshes or `part_flow` | Invisible boundary colliders at the water's edge and cliff tops. Shallow-water patches are **not** walkable unless designed so |
| Doorways, seats, fishing spots and lanes fit the largest outfit | Doors are 0.9 m wide by 1.6 m; seats at 0.42 m; duo cabinet stations 0.64 m apart | Character capsule radius 0.30 m, height 0.95 m (covers wizard_robe and puffer_vest). Test every doorway with it |
| Safe spawn and recovery points | `socket_spawn_*`, `socket_door`, `socket_spawn_inside`, `socket_exit` on shells and arenas | Validate each spawn against occupancy before use; fall back to the activity's `socket_door` |
| Home footprints and layers match saved data | `placement` meta (layer, footprint in 0.5 m cells, rotations, clearance) plus shell `cells`, `blocked_cells`, `wall_slots`, `ceiling_anchors` | Placement validation uses exactly this data. Reject placements that block `socket_exit` or the entry `blocked_cells` |

## Camera and visibility

- **Cutaway:** hide these together when the camera goes inside, and show them again on exit:
  - child nodes named `*_roof` or `*_cutaway` (building and home exteriors and shells);
  - any node whose extras have `visibility_group: "roof"` (finishing kit ridge and end caps, eave trim, snow eave overlays, ceiling beams).
- **Tall foreground props** (fir trees over 1.8 m, signs, dividers): fade to 30% alpha when they sit between the camera and the local penguin. Use a ray or sphere-cast from the camera to the player each frame, and fade over 0.2 s.
- **Destination readability:** every sign shows its **name text** in the engine, not only its pictogram (see Wayfinding below).

## Interaction plumbing

- **Names:** socket and part names are stable across rebuilds (see [Sockets and Attachments](../Art%20Docs/Sockets%20and%20Attachments.md)). Read them by name, never by child index.
- **Duo cabinet:** two independent stations (`socket_player_1/2`, `socket_grip_<n>_L/R`).
- **Exits:** every activity must restore movement, camera, UI focus and the occupied slot on leave, cancel or disconnect.
- **Decorative pieces** (`dock_ladder`, `mooring_post`, home plaques) carry `decorative: true`. Don't attach interaction prompts to them.
- **Events:** projectile release, hits and scores come from accepted gameplay events. Animation events (`release`, `line_release`) only time the visuals.

## Ambient and rendering

See [Engine Spec - Ambient World](Engine%20Spec%20-%20Ambient%20World.md) and [Engine Spec - Gameplay Effects](Engine%20Spec%20-%20Gameplay%20Effects.md).
- **Indoors:** rooms disable snow and exterior smoke.
- **Sorting:** water, glass, foam and smoke use alpha blending. Set `render_priority` so foam (+1) and smoke (+2) draw over water.
- **Shared resources:** instance repeated props through `MultiMeshInstance3D` (trees, fence posts, paving) and share materials. `Tints.prepare` duplicates materials only for assets the game actually recolours.

## Wayfinding

The art pack provides one sign **frame family** with blank insert faces, plus separate flat icon decals:
- `world_map_board`: `insert_map` face.
- `destination_signpost`: arrows are separate parts, each with an insert.
- `activity_sign`: `insert_icon` face, with an icon decal at `socket_icon`.
- `icon_cafe`, `icon_cinema`, `icon_arcade`, `icon_fishing`, `icon_sled`, `icon_snowball`, `icon_basketball`, `icon_drawing`.
- `home_number_plaque` (blank insert) and `queue_spot_marker` (a decal, no collision).

Engine:
1. **Data-driven signs.** Each sign instance references a destination ID from world data. The engine places the matching icon decal and renders the destination's **localized name** on the label insert, using a `Label3D` or a SubViewport texture.
2. **Arrows aim.** Rotate each signpost arrow part about its vertical axis toward its destination's world position at load.
3. **Map board.** The `insert_map` texture is generated from, or authored to match, the **playable** map, not the concept art.
4. **Queue markers** are decals, not colliders. Their reserved or occupied state comes from authoritative activity logic.
5. **Placement:** keep signs off narrow paths, camera sightlines, fishing cast arcs and sports trajectories. Check each in the level editor with the gameplay camera.

## Done when

The checklist in [World Assembly - Completion Checklist](../World%20Assembly%20-%20Completion%20Checklist.md) is ticked, item by item, in the real game, using the capsule size, cutaway groups and data-driven signs above.
