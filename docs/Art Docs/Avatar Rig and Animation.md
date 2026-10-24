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

## Clips (current)

| Clip | Loop | Notes |
| --- | --- | --- |
| `idle` | yes | Breathing bob |
| `waddle` | yes | Walk cycle; in place, so the game moves the root |
| `sit` | hold | Settles onto the `socket_seat` point |
| `wave` | yes | Right flipper |

- Clips are stored as NLA tracks and exported as glTF animations on `avatar_base` at 24 fps.
- Clothing GLBs have the rig but no clips; they follow the avatar's skeleton.

## Animation kits (in progress)

Animation work will follow the animation concept sheet the user is preparing. These conventions are set up so every clip plugs in the same way:

- **Authored in code** like the models: one `kits/anim_<set>.py` per set, with keys per bone. Rebuilding keeps every clip reproducible and tweakable.
- **Sets:**
  - locomotion: idle, waddle, run, turn, jump, slide-on-belly;
  - social: wave, cheer, dance, sit, laugh, emotes;
  - activities: cast, reel, catch for fishing; throw and hit-react for snowballs; sled ride; shoot for basketball; joystick for the arcade; draw for Sketch Club; watch and eat popcorn for the cinema;
  - props: doors, sled, fish flop, bobber bob, flags, marquee bulb chase, fountain.
- **In place.** The root doesn't travel; the game moves the character. Speed-matched locomotion clips record their stride length in the manifest.
- **Events.** Gameplay moments, such as a footstep or the frame a snowball leaves the flipper, are listed in the manifest as `events: {clip: {name: time_s}}`, because glTF has no markers.
- **Looping clips** start and end on the same pose. One-shots record `loop: false`.
- **Rig growth.** If a sheet needs more articulation (a tail, flipper tips, eyelids), new bones are added under the existing ones without renaming any. Existing clips and clothing keep working.
