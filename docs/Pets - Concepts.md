# Pets — Concepts

Three launch pets, picked by the owner: a **baby pengloo**, a **fish on a leash**, and a **rolling snowball**. Each one follows its owner around town, reacts to the activities, and has one signature gag. All three fit the low-poly diorama style and use the existing base-bird pipeline where possible.

The placeholder `scenes/snow_pet.tscn` (a colored ball with eyes napping in the plaza pen) should be replaced by these. As it stands it reads very close to Club Penguin's puffles, and the brief asks for original characters.

---

## 1. Baby Pengloo — the mini-me

A tiny chick-sized pengloo: fluffy grey down, oversized head, stubby flippers, and it waddles a beat behind you.

**Personality:** devoted copycat. It does whatever you just did, a little late and a little badly.

| Behavior | Detail |
| --- | --- |
| Follow | Waddles in your footsteps. Falls behind on long runs, then belly-slides to catch up. |
| Copy emotes | Repeats your last emote about 0.5s later at chick scale (wave is a flipper flap, dance is a wobble, and sometimes it tips over). |
| Mini outfit | Wears a shrunken copy of your hat. That reuses the equipment system: same item, scaled hat socket. |
| Idle | Sits on your feet, pecks at snow, falls asleep standing up. |
| Signature gag | **Grows up a little.** Its bond level changes the down from fluffy to patchy to sleek. It always stays small, and you can toggle back to fluffy. |

**Activity hooks**
- **Sledding:** rides in front of you on the sled with flippers up.
- **Snowballs:** tosses tiny useless snowballs from the sideline.
- **Fishing:** waits next to you with its beak open; it gets the small catches.
- **Cinema:** sits on your lap (seat socket), falls asleep halfway through.
- **Home:** nest/basket furniture item where it naps.

**Art:** derive it from the shared base bird rig with scaled proportions (head about 55% of height) and a separate down-fluff shell mesh per stage. Body color can follow the owner's color or be chosen at adoption, using the same recolor material region.

---

## 2. Fish on a Leash — the "dog"

A chunky, slightly too-big fish on a red leash, walked exactly like a dog. It flops along the ground with total confidence. Nobody comments on it.

**Personality:** a golden retriever that doesn't know it's a fish.

| Behavior | Detail |
| --- | --- |
| Follow | Flop-hops on a visible leash (a rope from the flipper socket to the fish's mouth ring). When you stop, the leash goes slack and the fish keeps flopping in place happily. |
| Pulling | It sometimes yanks toward water, puddles, the fish counter at the café, or other fish pets. The leash goes taut and your penguin leans back. |
| Fetch | Emote: "Fetch!" It flops off and brings back a random junk item (boot, sock, tin can, someone's snowball). |
| Idle | Lies on its side gasping dramatically. Then perks up the moment you look. |
| Signature gag | **Sniff greeting.** When two fish pets meet they circle and bump noses, and their owners get pulled together. |

**Activity hooks**
- **Fishing dock:** it gets very nervous. It hides behind you and covers its eyes with a fin whenever you catch something. Optional: it "barks" (spits water) when a bite is coming, a small cosmetic hint only.
- **Café:** stares longingly at the sushi. Blub.
- **Snowballs:** a hit gets it snow-covered, and it shakes off like a wet dog.
- **Basketball:** it sometimes steals a loose ball and flops away with it (solo/free-shoot only, never in matches).
- **Home:** fish-bowl dog bed with a little bone-shaped fish-food chew.

**Variants:** different species as pet skins: chubby orange "goldie", spiky pufferfish (puffs up when startled), sleek blue tuna, an anglerfish with a lantern that glows at night. Collars and bandanas use the accessory slot.

**Art:** a single fish rig (spine chain of 4–5 bones for floppy follow), plus a leash done as a runtime rope (Line/curve mesh between two sockets), so it never clips into a baked shape.

---

## 3. Snowball — the roller

A living snowball with two coal-chip eyes and a twig sticking out like a cowlick. It doesn't walk, it rolls.

**Personality:** cheerful, slightly out of control, gets carried away (literally).

| Behavior | Detail |
| --- | --- |
| Follow | Rolls after you. Rolling rotates the mesh, and the face stays upright on a separate counter-rotated layer so it doesn't spin upside down. |
| Grows in snow | Rolling on snow slowly increases its size (cap around 2× base). It leaves a packed-snow trail decal. |
| Shrinks in warmth | Indoors, near the café fireplace or your igloo heater, it slowly shrinks back and "sweats" drips. It never melts away fully, it just goes back to normal. |
| Idle | Wobbles, then bounces in place. It sometimes rolls off downhill and has to roll back up. |
| Signature gag | **Too big.** At max size it bowls over nearby players: a harmless stumble animation, opt-out in settings. Then it pops back to small with a puff of snow. |

**Activity hooks**
- **Sledding hill:** it rolls down beside you and grows the whole way, so it arrives huge at the bottom.
- **Snowball fight:** it hides during the match (scared of its own kind), then celebrates with the winning team.
- **Basketball:** it sits on the rim like a ball that's stuck.
- **Cinema/Café:** shrinks, sweats, and looks nervous by the hot cocoa.
- **Home:** a mini freezer/ice-box bed that keeps it at full size.

**Variants:** slush (blue-tinted), dirty-snowball (pebbles in it), sparkle-frost, and a top-hat snowman-head accessory.

**Art:** a low-poly faceted sphere with a few chunk bumps, face on a child node, and a scale driven by a single `size` float (synced).

---

## Shared pet systems

**Getting a pet:** adopt at the plaza pet shop (already on the map board). You get one free pick at first adoption. Other pets come from coins or unlocks.

**One active pet:** one follows you in town. The rest wait at home in their furniture beds, where visitors can see them.

**Cozy care, no punishment:** pets never get sick, run away, or die. Optional pats/treats raise **bond**, which unlocks tricks and cosmetic changes (baby pengloo growth stages, extra fetch items).

**Tricks as emotes:** each pet adds 2–3 entries to the emote wheel (Fetch, Roll Over, Sit, Copy Me). It reuses the existing emote UI.

**Naming:** a name tag floats over the pet when you hover or click it. Run it through the same name filter as chat.

**Multiplayer sync:** the server stores `{ petId, species, variant, name, accessory, bond }`. In-session sync is minimal: species/variant/accessory on join, plus small state changes (`size` for snowball, current trick, leash-pull target). Follow pathing runs client-side from the owner's synced position, so pets cost almost no bandwidth.

**Settings:** "Hide other players' pets" and "Pets can bump me" toggles, for crowded plazas and accessibility.

## Animation list (per pet)

| Clip | Baby Pengloo | Fish on Leash | Snowball |
| --- | --- | --- | --- |
| Idle | stand, peck | side-gasp | wobble |
| Move | waddle, belly-slide | flop-hop | roll (procedural) |
| Sit/Rest | sit on feet | lie flat | settle squish |
| Sleep | stand-sleep | belly-up | snore puff |
| Happy | flipper flap | tail wag-flop | bounce |
| Trick | copy emote | fetch + drop | roll-over/pop |
| React | tip over | shake off snow | sweat drips |

## Hackathon slice

1. Replace `snow_pet` in the plaza pen with one model of each pet (idle + move).
2. One active pet follows the local player; it syncs its species to others.
3. One trick each: Copy Me, Fetch, and Grow/Pop.
4. Pet shop adoption screen with three cards (name field + pick).

Later: variants and accessories, bond, home beds, activity hooks, the leash rope physics polish.
