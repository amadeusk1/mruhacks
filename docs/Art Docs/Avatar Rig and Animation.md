# Avatar Rig and Animation

The bird's skeleton, clothing system, and how animation kits are organised. Hub: [Art Pipeline](../Art%20Pipeline.md). Attachment slots: [Sockets and Attachments](Sockets%20and%20Attachments.md).

## Base bird

- `avatar_base`: about 0.9 m tall, about 2.4k triangles, faceted low-poly. Body colour is the tint role `body` (see [Tint System](Tint%20System.md)). Suggested body colours are in its manifest `color_variants`.
- Beak, eyes, feet and the cream face/belly mask are fixed materials.

## Skeleton

| Bone | Parent | Drives |
| --- | --- | --- |
| `root` | — | Whole-body placement; stays at the origin (clips are in place) |
| `body` | root | Torso lean, bob and waddle sway |
| `head` | body | Nods and looks; hats follow it |
| `flipper.L`, `flipper.R` | body | Waves, holding, throwing |
| `foot.L`, `foot.R` | root | Steps |

Every clothing GLB includes its own copy of this skeleton. To dress a bird, bind the clothing's skinned mesh to the player's skeleton **by bone name**. In three.js, rebuild the `Skeleton` from the avatar's bones in the same order; other engines have an equivalent "retarget by name" step.

## Face morph targets

On `avatar_base` and in every animation kit, all exported at weight 0:

| Morph | Use |
| --- | --- |
| `eyes_closed` | Blinks, sleepy |
| `eyes_happy` | ^ ^ smiling eyes (cheer, laugh, hop) |
| `eyes_wide` | Surprised |
| `beak_open` | Laugh, cheer, yawn (the lower beak hinges) |
| `blush` | Shy (a cheek patch that scales in from zero) |

Body language must read without them. Clips drive them as morph-weight tracks.

## Animation kits (delivered)

Each kit is its own GLB under `Models/anim_<set>/`: the skeleton, clips, and the full bird mesh (Godot drops face tracks without the mesh). The clips play on any bird by bone name; Godot verified all 475 track paths on a separately loaded `avatar_base`.

- **30 fps.**
- **In place:** only `hop` moves the root, and only vertically.
- **Loops** are exported with a `_loop` suffix, which Godot's importer turns into loop mode and strips from the name.
- **Events and stride** are in each kit's `manifest.json` (`clips: {name: {duration_s, loop, events, stride_m, cancel}}`).

| Kit | Clips (seconds) |
| --- | --- |
| `anim_locomotion` | `idle` 2.4, `idle_variant` 3.0, `walk` 0.8 (0.333 m/s), `run` 0.5 (1.1 m/s), `hop` 0.77, `start` 0.3, `stop` 0.4, `turn_left` 0.33, `turn_right` 0.33 |
| `anim_emotes` | `emote_wave` 1.2, `emote_happy_bounce` 1.0, `emote_laugh_in` 0.3 → `emote_laugh` loop 0.6 → `emote_laugh_out` 0.3, `emote_shy` 1.8, `emote_cheer` 1.3, `emote_sleepy` loop 3.0, `emote_surprised` 0.9, `emote_dance` loop 2.4 |
| `anim_social` | `sit_enter` 0.5, `sit_idle` loop 3.0, `sit_exit` 0.5, `interact_reach` 0.8, `hold_item_idle` loop 2.0 |

**Locomotion speed matching:** play `walk` at `speed / 0.333` and `run` at `speed / 1.1` so feet don't skate. Measured slip is under 0.002 mm per frame at the manifest speeds.

**Retired clips:** the old `idle`, `waddle`, `sit` and `wave` on `avatar_base` are replaced by `idle`, `walk`, `sit_idle` and `emote_wave`.

**Verified:** loop seams match exactly, and feet stay planted. Every worn item was ray-tested in the extreme poses; the remaining contact is 1–2 vertices under 1.5 cm on jackets in extreme waddle and wave frames. Contact strips are in [Renders](../../Renders) (`anim_*`).

**Known issue being fixed:** in `emote_cheer` and `hop`, raised flippers read as rigid slabs with a gap at the shoulder. The shoulder pivot is being moved inside the body.

## Activity animation kits (in progress)

Built per [Animation Kits - Index](../Animation%20Kits%20-%20Index.md):
- `anim_fishing`, `anim_sledding`, `anim_snowballs`, `anim_basketball`. Events: `line_release`, `spray_start`, the snowball `release` frame where the projectile spawns, the basketball `release`. Possession extras are tagged `extension`.
- `anim_arcade`, `anim_drawing`, `anim_cinema`, `anim_home` (door reach, place item, armchair sit).

## Conventions for new clips

- **Authored in code**, like the models: `art/blender/animlib.py` plus one `kits/anim_<set>.py` per set.
- **In place:** gameplay moves the character.
- **Loops** start and end on the same pose; one-shots record `loop: false`.
- **Events:** gameplay moments (a footstep, a snowball release) go in the manifest as `events`, because glTF has no markers.
- **Rig growth:** new bones are added under existing ones without renaming any, so existing clips and clothing keep working.
