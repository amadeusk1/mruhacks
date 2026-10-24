# Sockets and Attachments

Interaction and attachment points baked into the models. Hub: [Art Pipeline](../Art%20Pipeline.md).

## What a socket is

An empty node named `socket_<name>`, parented to the asset (or to a bone, on the avatar). It shows up:
- in the GLB node tree, with a clean name: the exporter strips Blender's `.001` suffixes per asset;
- in `manifest.json` under `sockets`, as `{name: [x, y, z]}` in the asset's local Blender coordinates (Z-up, front −Y). glTF import converts them to Y-up like the mesh.

A socket's rotation sets the direction the bird should face when using it. For example, cinema seats face the screen and fishing spots face the water.

## Naming used across the pack

| Socket | Meaning | Found on |
| --- | --- | --- |
| `socket_door` | Point just outside an entrance | Buildings, homes, screen doors |
| `socket_exit`, `socket_spawn_inside`, `socket_interior_spawn` | Room transitions | Interior shells |
| `socket_seat`, `socket_seat_<n>` | Where the bird sits (seat-contact height) | Benches, stools, sofas, cinema seats, Sketch Club table |
| `socket_sleep` | Lie-down point | Beds |
| `socket_player_1`, `socket_player_2` | Cabinet stations (the duo cabinet has both, 0.64 m apart) | Arcade cabinets |
| `socket_screen` | Centre of a game or video screen | Cabinets, cinema screen, kiosk |
| `socket_use` | Generic interaction point | Movie kiosk, token machine, easel |
| `socket_fish_<n>`, `socket_stand_<n>` | Seated fishing spots facing the water; safe standing spots | Dock modules |
| `socket_line_tip` | End of the fishing line | Fishing rod |
| `socket_rider`, `socket_pull` | Sled seat and pull-rope point | Sled |
| `socket_entry`, `socket_exit` | Track connection points | Sled slope and turn modules |
| `socket_start_<n>` | Start positions | Sled start platform |
| `socket_spawn_coral_<n>`, `socket_spawn_teal_<n>`, `socket_ready_<n>`, `socket_spectator_<n>` | Snowball arena roles | `snowball_arena_blockout` |
| `socket_shoot_<n>` | Basketball shooting positions facing the rim | `basketball_court_half` |
| `socket_pad_<n>` | Drawing-pad spot per seat | `sketch_table` |
| `socket_queue_<n>` | Where people line up outside | Cinema exterior |
| `surface_<n>` | Top centre of a surface that holds small decor | Housing tables, shelves, desks |
| `wall_slot_<n>`, `ceiling_<n>` | Wall-art and ceiling-decor anchors | Housing interior shells |

## Avatar attachment slots

On `avatar_base` the sockets are parented to bones:

| Socket | Bone | Use |
| --- | --- | --- |
| `socket_head` | head | Hats, hoods, headphones (origin at brow level, z ≈ 0.72 m) |
| `socket_face` | head | Glasses |
| `socket_neck` | body | Scarf |
| `socket_back` | body | Backpacks |
| `socket_hand_R` | flipper.R | Held items: mug, rod, wand, watering can |
| `socket_seat` | root | Contact point to snap onto a seat socket |

- **Positions:** the manifest's `sockets` for the avatar are **bone-local**. Use `sockets_world` (rest pose) to place things.
- **Attaching:** rigid items (hats, accessories) attach by parenting the item's origin to the slot node. Clothing (torso items) is skinned instead; see [Avatar Rig and Animation](Avatar%20Rig%20and%20Animation.md).
- **Conflicts:** each item's meta `slot` and `excludes` encode them. For example `frog_hood` excludes every head item, and an activity rod replaces whatever is in the hand slot.

## Sitting a bird on a seat

Snap the bird's `socket_seat` onto the seat socket's position and match its rotation, then play `sit`.
