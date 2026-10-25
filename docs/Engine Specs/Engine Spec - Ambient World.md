# Engine Spec: Ambient World

**Built in Godot.** Source sheets: [Animation Kit - Ambient World](../Animation%20Kit%20-%20Ambient%20World.md), `Images/Animation Kit - Living World.png` and [Prop Kit - Ambient Effects](../Prop%20Kit%20-%20Ambient%20Effects.md). The art pack supplies the movable parts (with ready-made clips), the emissive materials and the emitter sockets. This spec is the engine side. Index: [Engine Specs - Index](Engine%20Specs%20-%20Index.md).

## What the models already give you

- **Movable parts** with generated clips (see [Movable Parts and Effects](../Art%20Docs/Movable%20Parts%20and%20Effects.md)):
  - `part_*_open/_close` on doors, gates, curtains, lids and drawers;
  - `*_sway` loops on tree crowns, planters and mobiles;
  - `*_flutter` loops on flags, pennants and bunting;
  - `*_spin` loops on clocks, reels and wheels.
- **Emitter sockets:** `socket_fx_smoke` (chimneys), `socket_fx_steam` (cups, coffee station, teapot), `socket_fx_splash` / `socket_fx_ripple` (fountain, waterfall, bobber), `socket_fx_flame` (candles, stove), `socket_fx_bubbles` (aquarium), `socket_fx_sparkle` (marquees).
- **Emissive materials:** `glow*`, `bulb_<n>` (each string-light bulb separate), `lamp_*`, `insert_*` screens.

## Systems

**1. Chimney smoke**
- **Emitter:** at every `socket_fx_smoke`. A `GPUParticles3D` puff using `fx/smoke_puff_a/b/c`.
- **Rate and life:** one puff every 0.6–1.2 s, life 3–5 s.
- **Motion:** rise at 0.25 m/s, drift with the global wind (default +X at 0.15 m/s), scale 0.4→1.6, alpha 0.8→0, random spin.
- **Rules:** no emitters indoors; disable them when the interior scene is active. Particle bounds must include the full drift (about 2 m up, 1 m sideways).

**2. Lanterns, windows and string lights**
- **Pulse:** gently pulse emission energy on `glow*` / `glow_window` / `bulb_*`: ±12% around the base, a 2.5–4 s period, smooth sine, **random phase per instance**. Never flash.
- **String lights:** give each `bulb_<n>` its own phase. Never let all bulbs blink together.
- **Lights:** add an `OmniLight3D` only on a few hero lanterns per area (range about 3 m, warm #FFC76B); the others are emission only.
- **Night:** for a day/night cycle, scale the base emission up at night.

**3. Trees, shrubs, flags and bunting**
- **Play:** the generated `*_sway_loop` / `*_flutter_loop` clips on spawn, `seek(randf() * length)` for a random phase, and a playback speed of 0.8–1.2×.
- **Wind:** a global wind strength (0–1) scales the playback speed and blend weight. The trunks and poles are already static; snow is attached to the crowns.
- **Distance:** stop the animations beyond about 30 m (`AnimationPlayer` pause).

**4. Water, ripples and fountain**
- **Water surfaces:** use a scrolling-normal or UV-flow shader on `water`, `water_deep` and every `part_flow` (stream water, fountain streams). Slow, 0.05–0.1 m/s. Don't rigidly bob the tile geometry.
- **Shoreline foam:** strips (where present) get their own slow alpha pulse.
- **Ripples:** a pooled `fx/ripple_ring` at `socket_fx_ripple`, only from events (bobber, fountain drops) and a slow ambient ring on the fountain basin every 3 s. Never an unbounded stack.
- **Fountain streams:** the stream mesh flow-scrolls. At each `socket_fx_splash`, a continuous low-rate emitter (8/s) of `fx/splash_droplet`, plus a `fx/foam_patch` that pulses gently.

**5. Doors and curtains**
- **Doors:** play `part_<door>_open` / `_close`. Gameplay owns the open/closed state, and **only that state is networked**. Disable the door's collider while it is open, or block movement through the swing area while it animates.
- **Curtains:** cinema curtains play `part_curtain_*_open` when the screening starts and `_close` when it ends. The screen is independent. Home window curtains do the same on interaction.

**6. Arcade screens and weather**
- **Arcade attract mode:** when a cabinet is idle, show an attract loop on `insert_arcade`: a scrolling or twinkling texture, or a small SubViewport. In play, it shows the live game. Short emission pulses on accepted inputs.
- **Snow:** a camera-local bounded box (about 20×10×20 m) of `fx/snow_flake_a/b`. Sparse (about 60 particles), slow fall (0.3 m/s) with sideways drift. Disable it indoors, and thin it with distance.
- **Flowers and leaves:** small sway parts on shrubs where present; otherwise skip them.

**7. Interior decoration**
- **Effects:** candle flicker (`socket_fx_flame`: the `fx/flame` mesh plus light jitter), the star mobile's `part_mobile_sway`, aquarium fish `part_fish_*` sway plus bubbles at `socket_fx_bubbles`, and the wood stove's flame.
- **Pause** all of these when the room isn't active.
- **Cleanup:** moving or deleting a decorated prop removes its emitter.

## Global rules

- **Phase:** randomise the phase of every ambient loop.
- **Local only:** ambient motion is never networked; only door and curtain state is.
- **Budget:** cap emitters per area, cull offscreen and distant effects, and support a reduced-motion setting that stops sway and flutter and halves particles.
- **Sorting:** test transparent sorting of smoke and snow against water, windows and glass.

## Done when

- The plaza at the game camera shows smoke, pulsing lanterns, swaying trees, fluttering bunting, a flowing fountain and light snow, all out of sync with each other.
- Doors open and close with matching collision.
- Interiors have no smoke or snow.
- Reduced-motion mode works.
