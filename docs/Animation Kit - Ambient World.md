# Animation Kit - Ambient World

Reference: [GAME_DESIGN_CONTEXT](GAME_DESIGN_CONTEXT.md) · [Animation Kits - Index](Animation%20Kits%20-%20Index.md) · [Prop Kit - Ambient Effects](Prop%20Kit%20-%20Ambient%20Effects.md)

![Animation Kit - Living World](concepts/Animation%20Kit%20-%20Living%20World.png)

The world should feel gently alive. These are effect specifications, not claims of implemented particle systems. Use separate effects and movable components instead of baking motion into static meshes.

| System | Proposed motion | Implementation asset / controls |
| --- | --- | --- |
| Chimney smoke | Small soft cream-gray puffs emerge, rise, expand, drift and fade | Emitter at chimney mouth; reusable particle/mesh puff, random lifetime and rotation; wind direction, rate, size, opacity. Try a puff every 0.6–1.2 seconds with 3–5 second life as tuning starting points |
| Lanterns and windows | Subtle warm luminance changes; never harsh flashing | Emission material separate from frame; small randomized intensity, optional limited nearby light |
| String lights | Mostly steady amber with slight asynchronous variation | Shared material instances and staggered phase; avoid all bulbs blinking together |
| Trees and shrubs | Gentle foliage sway; rooted trunks stay fixed | Vertex mask or small bone motion; low amplitude, snow stays attached to crown |
| Flags and bunting | Cloth flutters around fixed attachment edge | Fixed pole/rope, flexible cloth; wind amplitude and phase |
| Water | Slow flowing surface and restrained highlights | Tiling shader flow, shoreline foam separate; no rigid geometry bobbing at every seam |
| Ripples | Ring expands, thins and disappears | Pooled effect triggered by bobber/contact; never an infinite stack of rings |
| Fountain and waterfall | Continuous stream plus small splashes | Separate stream mesh/material, droplets and foam emitter; cull distant particles |
| Doors | Open on hinge, hold, close | Door leaf separate from frame; pivot, clear swing area, collision state coordinated |
| Curtains | Open sideways and settle | Two movable panels; screen remains independent; avoid stretching fixed trim |
| Arcade screens | Attract loop while idle; live game during play | Screen insert switches state; short feedback on accepted events |
| Weather | Sparse drifting snow | Camera-local bounded particle field; disable indoors and reduce with distance |
| Interior decoration | Candle flicker, mobile sway, aquarium fish/tiny bubbles | Optional per-prop effect toggle; motion pauses outside active rooms |

## Shared rules

Ambient motion should be decorative and usually local; synchronize only consequential states such as door open/closed. Do not network each smoke particle. Use randomized phase so the town does not pulse in unison. Pool event effects, cap emission, cull offscreen/distant effects, and provide reduced-motion/low-effects options. Particle bounds must include full drift. Prevent smoke appearing indoors or emerging from a chimney wall. Test transparent sorting against water, windows, and snow.

Home interactions reuse reach/place, door, and seated poses from the social sheet. Grid placement must not wait on a decorative placement gesture. Moving or deleting a decorated prop also removes its emitter. See [Player Housing - Grid Decoration](Player%20Housing%20-%20Grid%20Decoration.md).
