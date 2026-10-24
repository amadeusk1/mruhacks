# World Layout Format

The contract between the Blender town build and the Godot game. The town is authored in Blender by `art/blender/world/town.py` (terrain plus asset placements, compared against `Images/World Map Concept.png`) and exported as data. Godot rebuilds the scene from that data, so the layout can change without anyone hand-editing a `.tscn`. Hub: [Art Pipeline](../Art%20Pipeline.md).

## Files (in `Models/world/`)

| File | Content |
| --- | --- |
| `town_terrain.glb` | The island ground as several meshes: `terrain_snow`, `terrain_rock` (cliffs), `terrain_paving` (plaza and paths), `terrain_sand`, plus `water` (separate, at `water_level`). Collision comes from `terrain_*` meshes in Godot (trimesh); water is not walkable |
| `town_layout.json` | Everything placed on the terrain (schema below) |
| `town_preview.png` | Blender preview from the concept camera, for comparing against the concept map |

## `town_layout.json`

All positions are in **Godot space** (Y-up, metres, −Z = north/"up the map", +X = east), already converted from Blender.

```json
{
  "version": 1,
  "terrain": "world/town_terrain.glb",
  "water_level": -0.5,
  "sun": {"rotation_deg": [-48, -35, 0], "color": "#FFE2B0", "energy": 1.25},
  "placements": [
    {"id": "cafe/cafe_exterior", "name": "Cafe", "pos": [-9.0, 0.0, 2.0], "rot_y_deg": 20.0, "scale": 1.0,
     "tints": {"awning_a": "#E86D58"}, "tags": ["building", "blocker"], "zone": "plaza"}
  ],
  "markers": [
    {"name": "Spawn", "pos": [0, 0, 6], "rot_y_deg": 180, "kind": "spawn"},
    {"name": "BusArrival", "pos": [6, 0, 9], "rot_y_deg": 200, "kind": "spawn"},
    {"name": "CafeDoor", "pos": [-8, 0, 4], "rot_y_deg": 20, "kind": "door", "target": "cafe_interior"}
  ],
  "zones": [{"name": "plaza", "center": [0, 0, 0], "radius": 12}],
  "nav_blockers": [{"pos": [0, 0, 0], "size": [3, 2, 3], "rot_y_deg": 0}]
}
```

- **`id`**: `<kit>/<asset>`. The GLB is at `res://Models/<id>.glb`, and its manifest entry gives size, sockets, tints and parts.
- **`tags`**: `building` / `prop` / `tree` / `rock` / `light` / `decor` / `fx`. `blocker` means "add a simple box collider from the manifest `size_m`" (physics layer 2, which carves the navmesh). `walkable` means its mesh is walk surface (docks, bridges, stairs: trimesh collider, layer 1). Anything else has no collision.
- **`tints`**: passed straight to `Tints.apply` after `Tints.prepare`.
- **`markers`**: named `Marker3D`s that gameplay looks up. `kind`: `spawn`, `door` (with `target`), `activity` (with `activity`: fishing, sled, snowballs, basketball, sketch, cinema, arcade, cafe), `bus`, `seat`, `route`.
- **`nav_blockers`**: extra invisible blockers (water edges, cliff tops) beyond the auto ones.
- Repeated small props (trees, rocks, lanterns, fence posts) may be batched into `MultiMeshInstance3D` by the loader; the data stays one placement per instance.

## Coordinates

Blender (x, y, z) → Godot (x, z, −y). Blender yaw `rz` → Godot `rot_y_deg` = degrees(rz). Assets face Blender −Y, which is Godot +Z (toward the camera's default south view).
