# Kit Authoring Guide

How to add or change models. Every model is a Python script, so changes are reproducible. Hub: [Art Pipeline](../Art%20Pipeline.md).

## Make a kit

`art/blender/kits/my_kit.py`:

```python
from common import *

KIT = "my_kit"

def build():
    b = Builder("garden_bench")                 # one asset = one Builder
    for i, x in enumerate((-0.6, 0.6)):
        b.box(0.1, 0.4, 0.42, x, 0, 0, "wood_dark")              # legs, bottom at z = 0
    planks(b, 1.4, 0.4, z=0.42, mats=WOOD)                       # individual seat planks
    b.box(1.4, 0.06, 0.3, 0, 0.18, 0.5, tint("paint", "teal"))   # recolourable backrest
    b.socket("seat_0", (-0.35, 0, 0.45)); b.socket("seat_1", (0.35, 0, 0.45))
    b.finish(KIT, "prop", meta={"color_variants": ["#207D85", "#E86D58"]})
```

Build it, then look at `Renders/Kits/my_kit.png`:

```
Blender -b --factory-startup --python art/blender/build.py -- my_kit
```

Add the kit to `GROUPS` in `render_index.py` and `KITS` in `save_all.py`.

## Builder parts (all in metres; angles in degrees)

| Call | Makes |
| --- | --- |
| `box(sx, sy, sz, x, y, z, mat, bevel, rot, center)` | Beveled block, bottom at z |
| `cyl(r, h, ..., segs, r2)` | Cylinder or cone (`r2` sets the top radius) |
| `blob(rx, ry, rz, ..., subdiv, jitter)` | Faceted ellipsoid: foliage, rocks, snow, bodies |
| `sphere`, `torus`, `prism(points, depth, plane)`, `mesh(verts, faces)` | Round parts, extruded outlines (signs, gables, pennants), raw polygons |
| `with b.at(loc, rotz):` | Build a group in a moved or rotated local frame |
| `socket(name, loc, rotz)` | Interaction point (see [Sockets and Attachments](Sockets%20and%20Attachments.md)) |

Shared helpers:
- architecture: `door`, `window`, `gable_roof`, `awning`, `chimney`, `stone_row`, `planks`;
- dressing: `planter_box`, `foliage`, `flower`, `lantern_head`, `wall_lantern`, `post`, `rope_between`, `bunting`, `snow_cap`, `fir`;
- housing: `placement(...)` (see [Housing Placement Data](Housing%20Placement%20Data.md)).

## Quality bar

- Match the concept sheet's silhouette and proportions first, then its details.
- Chunky bevels, individual planks and tiles, faceted organics, and subtle shade variation within a family.
- Size everything against the 0.9 m bird.
- Recolourable regions use `tint(...)` (see [Tint System](Tint%20System.md)); fixed details use palette names.
- Text and pictures go on `insert_*` faces, not modelled letters.

## Openings must match their frames

Arched or round doors and windows need an arched or round wall opening, or spandrel fill flush with the wall face. A rectangular hole behind an arched frame shows dark corner triangles (reported on the A-frame home). The frame overlaps the opening edge everywhere, from the outside and the inside.

## Checks before calling it done

1. Every asset reports `zfight_remaining == 0` (see [Z-Fighting and Clipping](Z-Fighting%20and%20Clipping.md)).
2. Render the assembled pieces from 4 sides plus top-down into `common.WIP` and look for poke-through, covered glass, floating parts, and openings visible past their frames (check close up, about 1.5 m away).
3. Sockets sit where the bird actually stands or sits, and face the right way.
4. Save one or two good close-ups to `common.DETAILS` as `<kit>_<what>.png`; they appear in [Renders](../../Renders).
