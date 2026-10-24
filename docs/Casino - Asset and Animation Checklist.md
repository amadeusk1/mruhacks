# Casino - Asset and Animation Checklist

[Casino - Concept Index](Casino%20-%20Concept%20Index.md) · [Casino - Gameplay and UI Requirements](Casino%20-%20Gameplay%20and%20UI%20Requirements.md)

Status: planned assets and motion references. No new GLBs or animations are claimed complete by these sheets.

| Kit | Required modular assets | Setup and interaction requirements |
| --- | --- | --- |
| Building | Shell, removable roof, doors, windows, marquee, trim, banner, entrance mat | Separate exterior/interior; entrance/spawn anchors; door pivots; readable silhouette beside arcade |
| Interior | Floor/wall modules, ceiling lamp, wall lantern, carpet, sign, lounge furniture, planter | Clear circulation around occupied seats and entrances; hideable ceiling; reuse existing props |
| Roulette | Table base, felt insert, rail, stationary bowl, rotor, ball, marker, rack | Rotor centered on its rotation axis; independent ball; bet-surface/UI anchor; spectator and seat anchors |
| Slots | Cabinet, bezel, three reels, lever, button, sign, light strip, token tray, stool | Reel axes aligned; separate lever pivot and button travel; shared frame with material variants |
| Poker | Oval table, replaceable felt/rail, seats, dealer/small-blind/big-blind buttons | Public board slots, private hand presentation, pot/chip anchors, six seats proposed pending rules |
| Blackjack | Semicircular table, felt/rail, seats, shoe, discard tray | Dealer hand anchor, five player positions proposed; extra hand area if splitting supported |
| Cards | Shared thin card mesh, back material, face atlas, deck stack | Deterministic face lookup; correct ranks/suits; opaque back; private faces never sent to unauthorized clients |
| Chips | Shared token mesh with material variants, stack mesh/instances, rack | Readable denominations if adopted; quantity UI authoritative; visual stacks need not equal mesh-per-chip counts |
| Shared decor | Card-suit plaque, stanchion/rope, side table, coat stand | Reuse common kit dimensions/materials; avoid blocking player circulation |

## Animation clips and procedural motion

| Motion | Separate parts / states | Integration notes |
| --- | --- | --- |
| Roulette round | Idle, rotor spin, ball orbit, deceleration, settled marker, reset | Animate toward server result; decorative physics cannot decide or change outcome |
| Slot spin | Lever/button press, three reel loops, staggered stops, result hold, idle | Server determines symbols; stop offsets must match result; block duplicate spin requests |
| Card handling | Deal, slide, flip, collect, shuffle presentation | Timed visual events tied to round/sequence ID; never reveal private card while animating |
| Chips | Place, move to pot, stack, collect, settle | Reuse pooled visuals; settlement occurs exactly once on server, not animation completion |
| Penguin interaction | Approach, hop onto seat, seated idle, reach, look, small cheer, leave | Shared modular penguin rig; flippers remain short; hat/clothes remain separate |
| Ambient | Soft lamp glow, restrained marquee pulse, door swing | Reduced-motion mode; avoid fast flashing; distance-cull decorative effects |

Author reusable clips for rigged penguins; use engine tween/procedural motion for rigid reels, chips and cards where it produces cleaner reusable assets. Define named seat, hand, camera, card, wheel and interaction anchors. Keep collisions simple, separate from animated decorative meshes. Include LODs/material batching appropriate to browser delivery.

## Asset acceptance

Inspect each model from gameplay and close interaction camera; test shared-avatar reach/seat fit; confirm no clipped hats or flippers; verify pivots, transforms, collision, readable cards and chip colors. Test occupancy of every seat while other penguins walk past. Check Compatibility-renderer export and restrained emissive effects. Generated text/numbering must be replaced with authored assets.
