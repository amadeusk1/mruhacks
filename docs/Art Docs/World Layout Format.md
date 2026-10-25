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
- **`stream`**: `points` = `[x, water level, z, half-width]` every 0.5 m along the stream (the water-edge pass uses each point's own level), `falls` = `{kind, base, top, drop, half_width, dir}` per fall/weir (spray and mist), `sea_level`. See [Water and Stream](Water%20and%20Stream.md).
- **`town_terrain.glb`** also holds `water_stream`, the stream's water ribbon (UV = flow, UV2 = foam/falls), next to the sea plane `water`; `water_shore.png` beside it is the sea shader's foam/depth map.
- Repeated small props (trees, rocks, lanterns, fence posts) may be batched into `MultiMeshInstance3D` by the loader; the data stays one placement per instance.

## Coordinates

Blender (x, y, z) → Godot (x, z, −y). Blender yaw `rz` → Godot `rot_y_deg` = degrees(rz). Assets face Blender −Y, which is Godot +Z (toward the camera's default south view).

## Hand placement (source of truth)

Placements and markers are authored by hand, not generated. They live as real objects in `Models/world/town_layout.blend`: the collection **Layout** holds props, each an instance of its GLB carrying the custom properties `asset_id`, `tags`, `tints` and `zone`; the collection **Markers** holds empties with `kind`, `target` and `activity`.

`art/blender/world/layout_edit.py` round-trips that file to `town_layout.json`. The conversion is verified exact (0 mismatches across 769 placements):
- `open_layout()`, `place()` and `save()` from a live Blender session (via MCP, or by you in the UI);
- `-- export` from the command line.

Terrain, paths, the sled hill and the deep coastal forest stay generated (`town.py`, `ground.py`, `sled_hill.py`). The authored district compositions are in `art/blender/world/hand_layout.py`.

**To move things yourself:** open `town_layout.blend`, move or duplicate objects in **Layout** (keep their custom properties), save, then run `Blender -b --python art/blender/world/layout_edit.py -- export`.
