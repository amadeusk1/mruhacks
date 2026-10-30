# Pets — Animation and Emotes

Animation plan for the three pets (models: `art/blender/kits/pets.py`, runtime: `scripts/pets/pet_follower.gd`). Concepts: [Pets - Concepts](Pets%20-%20Concepts.md).

## How pets animate

The pets have no skeleton. Each GLB has movable `part_*` children (see the manifest's `parts`), and `PetFollower` poses them in code every frame. New animations are written the same way: a small timed function that turns parts and moves the model root. No Blender clips are needed, which keeps the pets cheap to sync and easy to tune.

| Pet | Parts | Godot axes for the motion |
| --- | --- | --- |
| Baby Pengloo | `flipper_L/R`, `foot_L/R` | flippers flap about +Z (L positive = out), feet lift about +X |
| Fish on a Leash | `tail`, `fin_L/R`, plus a leash rope built at runtime | tail wags about +Y, fins flap about +Z |
| Snowball | `ball`, `face` | ball rolls about local +X (top moves forward), face tilts about +X |

Pets face +Z. Their root (`_model`) carries the body motion: bob, lean, squash, hop.

## Already in the game

| Pet | Moving | Idle (random gags after ~2.5 s still) | Special |
| --- | --- | --- | --- |
| Baby Pengloo | waddle: side rock, foot lifts, flipper flutter | breathing squash, flipper flap, look around, little hop | belly-slide when more than 2.6 m behind |
| Fish on a Leash | flop-hop arcs, nose up rising / down landing, tail thrash | side-flop "gasp" then perks up, happy tail wag | leash goes slack when close and taut when pulling |
| Snowball | rolls by distance, face stays upright, slight wobble | wobble, bounce | grows while rolling, pops at 1.75× with a snow puff, packs back down when resting |

## Emotes

Pet emotes go on the emote wheel (`ui/screens/emote_picker.gd`) in a **Pet** row that shows only while a pet is out. They play on the owner and the pet together. Each has a name, a duration and a short procedural script.

### Baby Pengloo

| Emote | What happens | Length |
| --- | --- | --- |
| **Copy Me** (signature) | For 8 s the chick repeats every owner emote half a second late, at chick scale and slightly wrong: Wave is a frantic flap, Dance is a wobble that ends in a tip-over, Sleepy is an instant faceplant nap. | 8 s |
| **Flipper Five** | The owner crouches. The chick hops up, the two slap flippers, there's a sparkle burst and both do happy eyes. | 1.6 s |
| **Toboggan Ride** | The owner belly-slides forward with the chick riding on their back (`socket_back` → chick root), flippers up. | 2.5 s |
| **Tantrum** | The chick stomps its feet, flaps furiously and puffs up (scale 1.15), then forgets why and waddles off happy. | 2 s |
| **Nap Pile** | The owner sits. The chick climbs into their lap and they sleep together; Zzz bubbles alternate between them. Loops until you move. | loop |

### Fish on a Leash

| Emote | What happens | Length |
| --- | --- | --- |
| **Fetch!** (signature) | The owner throws (reuse the snowball throw clip). The fish flops off about 4 m and comes back with a random junk prop (boot, sock, tin can, someone's hat). It drops the prop at the owner's feet; the prop fades after 3 s. | 3–4 s |
| **Play Dead** | The owner points with a finger-gun flipper. The fish flips belly-up, tail twitching, X-eyes (swap eye material). The owner pokes it and it springs back to life. | 2.5 s |
| **Fountain** | The fish arches up and spits a water arc (particle stream) in a rainbow over the owner's head. | 2 s |
| **Hammer Throw** | The owner spins on the spot; the fish orbits on a taut leash at 1.4 m, flying horizontally with fins flapping. Both are dizzy afterwards. | 2.2 s |
| **Sit. Stay. Good Boy.** | The fish props itself upright on its tail and wags; the owner pats its head; hearts pop. | 2 s |

### Snowball

| Emote | What happens | Length |
| --- | --- | --- |
| **Grow & Pop** (signature) | The snowball inflates to full size in 1 s, shudders, and pops in a big puff, landing back small and grinning. | 1.6 s |
| **Snowman** | The owner lifts it overhead and stacks it on a second snow lump; their hat jumps onto the snowball for the pose, then returns. | 2.5 s |
| **Bowling** | The owner rolls it like a bowling ball. It knocks over 6 pop-up snow pins and rolls back. | 3 s |
| **Split** | It splits into three mini snowballs that bounce in a circle around the owner, then crash back together. | 2.4 s |
| **Meltdown** | It drama-melts into a puddle with sad eyes floating in it, then reforms with a "ta-da" bounce. | 2.8 s |

### Shared reactions (no button needed)

- **Mirror the owner:** owner Wave → the pet waves a flipper/fin or bounces; Cheer → a hop; Laugh → the pet shakes; Sleepy → the pet naps too.
- **Pet Party:** when three or more pets are within 3 m and their owners Dance, the pets start a group bounce in sync with the music beat.
- **Greeting:** two pets meeting circle each other for 1 s. Two fish bump noses and pull their owners a step together.
- **Activity flavour:** fish hides behind the owner at the fishing dock; the snowball cheers after a snowball fight; the chick sits on the owner's lap at the cinema.

## Implementation plan

1. **Pet emote API.** Add `PetFollower.play_emote(name)`, which runs a coroutine that owns the parts until it ends or the owner moves (same rule as player emotes). Add `pet_emotes(species)` to `Pets`, read from a new `emotes` list in each manifest entry.
2. **Wheel.** Add a Pet row to `emote_picker.gd`, built from the active pet's list.
3. **Sync.** Reuse the emote channel: send the clip as `pet:<name>` through the existing `Net` emote broadcast (`emote_played(peer_id, clip)`). Remote puppets route `pet:` clips to their `Pet` child.
4. **Mirror reactions.** In `penguin_movement.play_emote`, notify the `Pet` child of the owner's clip. These run locally on every client, so they need no extra sync.
5. **Props and effects.** Fetch junk, bowling pins, water arc, hearts and Zzz bubbles go in a small `pets_fx` addition to the pets kit (GLBs) plus Godot particles.
6. **Accessibility.** Respect `reduce_motion`: no screen shake and a shorter Hammer Throw. The "Pets can bump me" toggle covers the snowball's knock-over.

**Build order:** Copy Me, Fetch!, Grow & Pop first (one signature each), then the mirror reactions, then the rest.

## Status

Built (steps 1–5 for these): **Copy Me**, **Fetch!** and **Grow & Pop**, plus mirror reactions to all eight owner emotes for every pet.

- **Wheel:** a slim Pet button row in the emote picker, shown while a pet is out.
- **Sync:** pet emotes go out as `pet/<id>` through `Net.note_emote`. Remote puppets route them in `penguin_movement.play_emote`.
- **Data:** each pet's emotes are listed in the manifest (`emotes: [{id, name, owner_clip}]`).
- **Fetch junk:** `fetch_boot`, `fetch_sock` and `fetch_can` in the pets kit (slot `pet_prop`). The fish carries them from `socket_mouth`.
- **Snow puff:** the pop's puff is faceted snow chunks animated with tweens.

Not built yet: the other twelve emotes in the tables above, Pet Party, greetings, activity flavour, and the `reduce_motion` handling.
