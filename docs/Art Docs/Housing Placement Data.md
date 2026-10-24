# Housing Placement Data

The metadata that makes furniture and house shells work with grid decoration ([Player Housing - Grid Decoration](../Player%20Housing%20-%20Grid%20Decoration.md)). Hub: [Art Pipeline](../Art%20Pipeline.md).

## Grid

- Square cells of **0.5 m** (`common.CELL`), next to a 0.9 m bird.
- Floor furniture rotates in 90° steps, and its footprint rotates with it.

## Per item: `placement` (in the manifest)

| Field | Meaning |
| --- | --- |
| `layer` | `floor`, `rug` (under furniture, may overlap it), `wall`, `ceiling`, `surface` (small decor on a table or shelf) |
| `footprint` | `[w, d]` in cells. Derived from the model's size if the kit didn't set it |
| `rotations` | Allowed rotations in degrees |
| `clearance_front` | Cells to keep free in front (−Y) so the item stays usable: a bed's approach, an arcade player spot |
| `recolor` | Whether the item has tint regions (see [Tint System](Tint%20System.md)) |

Origins:
- **floor, rug, surface:** bottom centre.
- **wall:** centre of the back face, touching the wall at y = 0 and facing −Y.
- **ceiling:** the hook point at the top.

**Supporting surfaces.** A table, shelf or desk has `surface_<n>` sockets (top centre) with sizes in meta `surfaces: {name: [w, d]}`. Small decor placed there doesn't consume floor cells. Store the supporting item's instance ID and the surface offset in the saved layout.

**No fused clutter.** Shelves, tables and desks ship empty. Books, mugs, plants and so on are separate `surface` items.

## Per house: interior shell meta

| Field | Meaning |
| --- | --- |
| `cells` | Valid floor cells `[ix, iy]` (round rooms use a circular mask) |
| `cell_origin` | World XY of cell `[0, 0]` |
| `blocked_cells` | Entry clearance, stairs, stove spots |
| `cells_loft` and loft height | Second floor level (A-frame) |
| `wall_slots` | `wall_slot_<n>` sockets with a facing direction, for wall-layer items |
| `ceiling_anchors` | `ceiling_<n>` sockets |
| sockets | `socket_spawn_inside`, `socket_exit`, and `socket_door` on the exterior |

## Saved layout record (proposal from the design note)

House type, plus per placed item:
- instance ID;
- catalogue asset ID (`room_kit/armchair`);
- cell position and rotation;
- layer;
- tint colours;
- optional supporting item ID and surface offset.

## Catalogue notes (room_kit, 39 items)

- **Footprints, at 0.5 m cells:** sofa 3×2, bed 2×3, armchair 2×2, desk 3×2, cube shelf 2×1, aquarium 2×1, home arcade 1×2, round rugs 3×3, patchwork rug 3×2. Sizes were trimmed to land on whole cells.
- **Front clearance of 1 cell:** armchair, sofa, bed, desk, arcade and aquarium.
- **Rotation:** wall art allows 0° only (it faces out from its wall slot).
- **Surfaces:** low table, desk, cube shelf (4 cubbies plus the top) and wall shelf. Each has `surface_<n>` sockets.
- **Cushions:** the sofa and armchair cushions are part of the seat mesh (as on the sheet), with their own `cushion` and `cushion_accent` tints. The standalone `cushion` item is separate decor.
- **Kit sheet:** in `Renders/Kits/room_kit.png`, wall and ceiling items render below the ground line because of their origin conventions. That's expected.
