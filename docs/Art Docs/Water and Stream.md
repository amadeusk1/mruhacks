# Water and Stream

The sea, the stream with its falls, and everything that floats. Written against `Images/World Map - Island Overview.png` (cascades between rocky banks, teal water with pale cell lines and white foam) and `World Kit - Shoreline and Waterfront Details.png`. Hub: [Art Pipeline](../Art%20Pipeline.md). Layout contract: [World Layout Format](World%20Layout%20Format.md).

## What was wrong (in-game shots, 2026-10-24)

1. **Houseboat under water.** Its hull is modelled in world terms (waterline at −0.5, deck at 0.24, `homes/manifest.json` `water_z`), but it was placed at z = −0.48, so it sank 0.48 m and only the roof showed. The rowboats (placed at −0.5), the ice floes (−0.56: completely invisible), the cove foam strips and the shallow-water patches had the same double offset.
2. **The stream was a trench.** One flat sea plane at −0.5 was the only water, so the stream was a 1 m-deep straight-walled cut with flat cyan in the bottom. It had no flow, no foam and no level changes. The two `waterfall_step` props stood in the middle of flat water like glass boxes. The polyline had hard corners, and the stream stopped 3 m short of the coast.
3. **Flat, untextured water everywhere**, with no shore foam.
4. **Fishing.** The pier-B T-head spot `-16, -22.5` had yaw 90, so its two anglers faced back along the deck and cast into the planks. Every rail post stood 1.2 m in front of its marker, which is 0.7 m out over the water. The bobber floated at −0.34, 16 cm above the town's water, because that height came from the old plaza pond. The sunken houseboat sat right in front of the T-head casts.
5. **String lights in the air.** The spans' anchors are already 2.4 m up in the asset, but they were placed 2.4 m up again, so they hung at 4.8 m with nothing under them.

## How it works now

**Stream** (`art/blender/world/stream.py`): a Catmull-Rom channel, sampled every 0.25 m, from a rock spring north of the cinema to the sea east of the south pier (73.6 m).
- **Levels step down** at `STEPS`:
  - spring notch at 2.25;
  - falls to the spring pool at 0.85;
  - falls off the woodland rise to −0.2;
  - a weir above the plaza bridge to −0.34;
  - a weir below the south-east bridge to −0.46;
  - the mouth, 4 cm above the sea.
- **Bed and banks.** The terrain bed is 0.42 m under each reach's level, and the banks rise 0.15 m above it. The channel is wider in the pools under each fall and narrower at every lip.
- **The spring** is a 2.7 m snow-capped rock knoll. The water spills out of a notch in its south face between two `cliff_straight_2m` walls with snow overlays. The second fall is framed by `cliff_straight_1m`. The weirs are broken lines of wet stones.
- **The water ribbon** (`water_stream` in `town_terrain.glb`) runs 0.35 m past the waterline under the bank, so no gaps or z-fighting show at the shore. It uses `UV` = (across 0..1, s metres) and `UV2` = (foam, falls flag). Falls are arcs that leave the lip horizontally and end vertical.
- **Bank dressing** is authored by hand in stream coordinates (`hand_layout.stream()`: s, side, offset), so it follows the channel. Anything that would land on a path or within 2.7 m of a bridge is skipped.

**Sea**: a flat plane at −0.5 (no vertex jitter, so the stream mouth can sit 4 cm above it). `Models/world/water_shore.png` (512² over x, y ∈ [−50, 50] m, about 0.2 m per pixel, north up) is baked on every town export:
- **R = foam**: shallow water within 0.55 m depth, plus soft rings round coast rocks, floes, rowboats, the houseboat hull and every dock pile;
- **G = depth** (0 shallow to 1 deep, 1.9 m).

**Shader** (`scripts/world/water.gdshader`, one shader for both): opaque, with no depth or screen texture, so it is identical in the web (Compatibility) build.
- drifting caustic cell lines (Voronoi F2 − F1);
- shallow-to-deep colour;
- lapping shore foam with a second, thinner line further out;
- subtle fresnel;
- a little emission so shade doesn't make it muddy.

The stream's cells and streaks scroll with the flow, boil white below each fall and along the banks, and the falls sheets streak 4.5× faster. `town_builder.gd` sets it as `material_override` on every `water*` mesh.

**Spray**: the layout's `stream.falls` gives each fall a `socket_fx_splash_*` (droplets) and a `socket_fx_mist_*` (`fx/steam_wisp`, AmbientFx). Weirs get spray only.

**Walking**: the layout's `stream.points` (`[x, level, z, half_width]` every 0.5 m) give the town's water-edge pass each corner's local water line. A grid corner is wet when its floor is below the stream level, not only below the sea, so the raised spring pool is blocked too. Bridges stay walkable because the floor ray hits their deck first.

**Floating props**: boats, floes, the houseboat, foam strips and shallow patches are modelled at the waterline, so they are placed at z = 0. Bobbers and ripples have their origin at the waterline (the game moves them), so they go at `WATER_Z`.

**Houseboat**: it rides at anchor in the outer cove at (−19, −30.4), clear of every cast. It has no gangway: there is no "home" door wired for it in the town, so the old gangway led nowhere.

**Fishing**: pier tips face open water, and the -16 T-head spot now faces west. The rail post stands on the deck edge, 0.45 m in front of the marker (`fishing_spot.gd` `reach`). The tackle reads the room's water line from the `water_surface` group node (the town's `WaterLevel`) and falls back to the old pond's −0.34.

**String lights**: each span hangs between two `plaza/string_light_pole` posts. These are iron, 2.9 m, with a wire collar at 2.4 m and a small lantern on top. Both the span and its poles sit at ground z (`hand_layout.lights_span`). The cinema approach has one span with a pole either side.

## Checks

- `tools/water_capture.tscn` (windowed): gameplay, low and top shots of every reach plus a penguin fishing from each spot. Before/after images are in `Renders/Map/river_*.png`.
- `tools/walk_test.tscn`: zero stuck, pass-through and unreachable in the town.

## Not done

- No water sound: the project has no SFX library yet.
- The stream is opaque: no refraction or visible bed.
