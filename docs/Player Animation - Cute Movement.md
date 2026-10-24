# Player Animation — Cute Movement

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Animation Production Checklist](Animation%20Production%20Checklist.md) · [Player Animation - Emotes](Player%20Animation%20-%20Emotes.md)

Confirmed direction: cute movement, a shared modular bird, interchangeable clothing and accessories, and body colors controlled separately in-engine. The timing and implementation suggestions below are proposals. These are concept poses, not finished animation clips or a frame-exact sprite atlas.

![Player Animation - Cute Movement](concepts/Player%20Animation%20-%20Cute%20Movement.png)

## Motion personality

Keep the bird soft, weighty, and playful: short alternating steps, gentle side-to-side body tilt, a small vertical bounce, and flippers that follow the motion. Feet should feel planted during contact. Keep the broad pear silhouette and avoid rubbery stretching, frantic motion, or large head/body separations.

| Motion | Key poses and feel | Proposed timing |
| --- | --- | --- |
| Idle | Relaxed stance, gentle breath, occasional blink or curious tilt | Slow 2–3 second breathing loop; variation between repeats |
| Waddle walk | Left contact, settle, passing, right contact, settle | About 0.7–0.9 seconds per full cycle |
| Bouncy run | Forward intent, quick alternating contacts, a little lift, trailing flippers | About 0.45–0.6 seconds per cycle |
| Little hop | Small crouch, push, airborne tuck, soft landing, recover | About 0.6–0.9 seconds; visual proposal, not confirmation of a jump mechanic |
| Stop and turn | Short braking steps, settle, small foot shuffle toward new direction | About 0.2–0.4 seconds, responsive to input |

## Shared rig and modular clothes

Animate the base bird once. Clothing follows the same compatible skeleton; hats and rigid accessories use stable attachment points. Do not bake a particular hat, body color, or outfit into a movement clip. Keep body deformation restrained enough that thick jackets, robes, and hoods remain believable. Foot placement and flipper clearance must be checked on the widest outfits.

Suggested game integration: in-place locomotion with gameplay controlling travel speed, and animation playback matched to that speed. Blend idle, walk, and run without delaying movement input. Treat turn, start, and stop gestures as short transitions. These are implementation recommendations, not an implemented controller.

## Art review

Review front, side, rear, and the actual game camera. Compare the silhouette to [Gallery](Gallery.md) and the avatar turnaround. Check grounded contacts, no foot skating, readable small-scale poses, clean looping, and no hat/hood/robe clipping. Test several body colors and the largest accessory combination.

Visual made with the built-in image generation tool: low-poly blue bird key-pose sheet covering idle, waddle, run, hop, and stop/turn. The sheet communicates attitude; animators should establish consistent proportions and contact timing in the actual rig.
