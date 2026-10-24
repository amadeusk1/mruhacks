# Prop Kit - Effect Shapes

Reference: [Prop Kit - Ambient Effects](Prop%20Kit%20-%20Ambient%20Effects.md) · [Animation Kit - Ambient World](Animation%20Kit%20-%20Ambient%20World.md) · [Movable Parts and Effects](Art%20Docs/Movable%20Parts%20and%20Effects.md)

![Effect Shapes Prop Kit](concepts/Effect%20Shapes%20Prop%20Kit.jpg)

The host props already exist: chimneys, lanterns, trees, doors, fountains, curtains, and water tiles. The detached shapes live in `art/blender/kits/fx.py` and export to `Models/fx`. The game parents them to `socket_fx_*`, then scales, fades, and moves them. They are not a second copy of the buildings.

## Reuse before modeling

| Need | Existing export | Do not remodel |
| --- | --- | --- |
| Water ripple | `fishing/ripple` (0.76 m, origin at the waterline) | The two rings on the sheet are scale stages of this one mesh |
| Hit or brake puff | `winter/snow_puff` (about 0.8 m, category `fx`) | Keep it for snowball hits and sled spray |

## New shapes

Origin is the attachment point, so parenting to `socket_fx_*` uses an identity transform. Local +Z is up. Nothing is lettered, and no motion is baked into the mesh.

| Asset | Socket | Rest size | Starting motion |
| --- | --- | --- | --- |
| `smoke_puff_s` | `socket_fx_smoke` | 0.16 m blob, origin at the bottom | Rise, expand, drift, fade. Emit one every 0.6–1.2 s. Life 3–5 s |
| `smoke_puff_m` | `socket_fx_smoke` | 0.32 m | Same family, mixed in at random |
| `smoke_puff_l` | `socket_fx_smoke` | 0.48 m | Rare. One large puff, not a column |
| `steam_wisp` | `socket_fx_steam` | 0.05 m wide, 0.22 m tall, origin at the bottom | Shorter life, about 1.2–2.0 s. Mugs, coffee spout, takeaway cups |
| `splash_drop` | `socket_fx_splash` | 0.05 m, origin at the center | One-shot burst where a stream lands. Pool it |
| `foam_blob` | `socket_fx_splash` | 0.22 × 0.14 × 0.06 m, origin on the water plane | Sits, thins, disappears. Not a looping sheet |
| `snow_flake` | camera-local weather | 0.05 m | Sparse drift. Disable indoors and with distance |
| `snow_clump` | weather, or `socket_fx_spray` | 0.12 m | Close flakes and light sled spray |
| `snow_star` | weather | 0.16 m | Occasional, not the default particle |
| `flame` | `socket_fx_flame` | 0.09 m tall, origin at the base | Local flicker on candles and the stove. Not a fireball |
| `sparkle` | `socket_fx_sparkle` | 0.06 m, origin at the center | Short twinkle on an arcade attract loop |

Colors stay in the existing palette: cream-gray smoke, whiter steam, turquoise water, white snow, amber flame and sparkle. Use a transparent material. These shapes are not recolorable clothing tints.

## Rules

- Smoke starts above the chimney cap and never inside a room. The emitter is the existing chimney socket, not a new building.
- Ripples are one pooled ring per contact. Scale it up and fade it out. Do not stack rings.
- Weather is a bounded field on the camera, not a mesh glued to the island.
- Only door open/closed is a shared state. Do not network each puff.
- Reduced motion hides new particles and lets the ones already in the air fade. The flame becomes a steady glow.
- Deleting a decorated prop deletes its emitter with it.
- The large snowflake on the sheet is a hero shape. The everyday particle is `snow_flake`.
