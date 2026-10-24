# Animation Kit - Gameplay Effects

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Gallery](Gallery.md)

Concept reference only; this sheet does not itself implement models or animation. Generated with the built-in image generation tool.

![Animation Kit - Gameplay Effects](concepts/Animation%20Kit%20-%20Gameplay%20Effects.png)

## Effect inventory

| Effect | Sequence | Trigger and cleanup |
| --- | --- | --- |
| Bobber splash | Contact → droplets → widening ring → fade | Accepted cast landing; pool once per event |
| Fish escape | Tail/splash → expanding ripple → calm | Escape result; fish visual submerges and is removed |
| Snowball impact | Contact → soft burst → scattered clumps → fade | Accepted impact; hide projectile once, then recycle |
| Sled brake spray | Runner contact → sideways spray → settle → dissipate | Driven by contact and braking; stop emitting when stopped |
| Basket swish | Ball enters → net stretches → ball exits → settle | Actual visual passage/contact; scoring remains gameplay-owned |
| Small celebration | Spark → confetti spread → drift → fade | Result event; short and restrained, no endless emitter |

Existing `fx` exports include ripple ring, splash droplet, snow puff, snow spray clump, sparkle star and confetti bit. They are reusable shapes, not proof these complete effects are implemented.

## Implementation and review

Keep particles, water rings, net motion and scoring separate. Use event IDs to avoid duplicated bursts on network updates. Bound lifetime and particle count, pool effects, cull distant emissions and offer reduced effects. A miss should not trigger a made-basket swish. Effects should never hide the aiming target or cover boundaries.

The fading bobber in the final storyboard frame is illustrative: the gameplay bobber stays present while fishing, and only its splash/ripple fades. Similarly, the basketball must preserve its standard ball markings in the actual asset. These are timing/key-phase references, not a sprite atlas or frame-accurate simulation.

Related: [Animation Kit - Fishing](Animation%20Kit%20-%20Fishing.md), [Animation Kit - Sledding](Animation%20Kit%20-%20Sledding.md), [Animation Kit - Snowballs](Animation%20Kit%20-%20Snowballs.md), [Animation Kit - Basketball](Animation%20Kit%20-%20Basketball.md), [Animation Kit - Ambient World](Animation%20Kit%20-%20Ambient%20World.md).
