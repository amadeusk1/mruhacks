# Engine Spec: Gameplay Effects

**Built in Godot, not as models.** Source sheet: [Animation Kit - Gameplay Effects](../Animation%20Kit%20-%20Gameplay%20Effects.md). The art pack supplies the shapes and the attach points. Everything below (spawning, motion, timing, fading, pooling) is engine work. Index: [Engine Specs - Index](Engine%20Specs%20-%20Index.md).

## Shared rules for every effect

- **Trigger:** one accepted gameplay event spawns one burst. Each event carries an **event ID**; ignore a repeated ID (network resend, reconnect replay).
- **Pooling:** keep a small pool per effect type (4–8 instances), and reuse the oldest when it runs out. Never instantiate per hit.
- **Lifetime:** every burst ends by itself. No emitter left running after its event.
- **Settings:** honour a reduced-effects toggle (halve particle counts, skip secondary rings), and cull beyond about 25 m from the camera.
- **Readability:** effects never cover the aim reticle, court lines or arena boundaries. Keep them below 1.2 m height, except celebration sparks.
- **Particles:** use `GPUParticles3D` (or `CPUParticles3D` where counts are tiny), one-shot mode, with draw passes set to the `fx` meshes below.

## Assets you'll use (in `Models/`)

| Asset | Kit | Use |
| --- | --- | --- |
| `splash_droplet`, `splash_crown` | fx | Bobber splash droplets |
| `ripple_ring`, `ripple_ring_wide` | fx | Expanding water rings |
| `fish_tail` | fx | Fish-escape tail break |
| `snow_burst`, `snow_clump_a/b`, `snow_puff_small` | fx | Snowball impact |
| `snow_spray_clump` | fx | Sled brake spray |
| `spark_star_big`, `sparkle_star`, `confetti_bit` | fx | Celebration |
| `socket_fx_ripple` on `fishing/bobber` | fishing | Where rings spawn |
| `socket_fx_spray` (×2) on `winter/sled` | winter | Runner spray points |
| `socket_target`, `part_net`, `part_rim` on `activities/basketball_hoop` | activities | Swish |

Particle materials are the `fx_*` materials already on the meshes: alpha-blended with soft emission. Use them as-is.

## 1. Bobber splash

- **Trigger:** the cast lands (the accepted cast-landing event, after `fish_cast` fires `line_release` and the bobber's flight ends).
- **At:** the bobber's `socket_fx_ripple`, on the water surface.
- **Sequence (about 1.4 s):**
  1. Bobber dips 4 cm and springs back over 0.3 s. This is a tween on the bobber node; the bobber **stays** for the whole fishing session.
  2. 6–8 `splash_droplet` particles shoot up 0.15–0.3 m at random angles, gravity on, life 0.4 s.
  3. One `ripple_ring` scales from 0.1 to 0.6 m over 0.9 s while its alpha fades to 0. A second ring starts 0.2 s later (skip it on reduced effects).
- **While waiting:** a slow ring every 2.5 s at 50% opacity. On a bite, tween the bobber 6 cm down, plus one small ring.
- **Cleanup:** rings return to the pool after fading. Cancelling fishing removes the bobber and any active rings.

## 2. Fish escape

- **Trigger:** the escape result.
- **At:** the bobber position.
- **Sequence (about 1.6 s):**
  1. `fish_tail` rises 0.12 m above the water, tilts 25°, and flicks over 0.35 s.
  2. 5–6 droplets.
  3. The tail sinks below the surface over 0.25 s and is hidden.
  4. Two `ripple_ring_wide` rings, 0.15 s apart, grow to 0.8 m and fade over 1.0 s.
- **Cleanup:** the tail returns to the pool. The bobber stays if the player keeps fishing.

## 3. Snowball impact

- **Trigger:** the server-accepted hit or wall impact. On that same event, hide the projectile (exactly once).
- **At:** the impact point, oriented to the surface normal.
- **Sequence (about 1.2 s):**
  1. `snow_burst` scales from 0.6× to 1.4× over 0.15 s, then fades over 0.25 s.
  2. 6–10 `snow_clump_a/b` pieces scatter outward 0.2–0.5 m with gravity and settle on the ground, then shrink to nothing over 0.6 s.
  3. 3 `snow_puff_small` drift up and fade.
- **On a player hit:** also show a short white flash on the penguin, plus the `snow_hit` clip from `anim_snowballs` (no fall).
- **Cleanup:** everything is pooled; no lingering snow decals in the first version.

## 4. Sled brake spray

- **Trigger:** **continuous**, not one-shot. It emits while the sled is braking, or turning hard, and moving faster than 1.5 m/s. It starts with the `spray_start` event in `sled_brake`.
- **At:** both `socket_fx_spray` points on the sled runners.
- **Particles:** `snow_spray_clump` thrown sideways and back (±70° from the travel direction), 0.2–0.4 m, gravity on, life 0.5 s. Rate scales with speed: 20/s at 1.5 m/s up to 60/s at 4 m/s.
- **Stop:** emission ends when speed drops below 0.5 m/s or braking stops. Remaining clumps settle and fade (the "dissipated" frame).
- **Cleanup:** reset spray on a course reset.

## 5. Basket swish

- **Trigger:** the visual pass through the rim on a **made** shot only. A miss never swishes. Scoring stays gameplay-owned; this is presentation.
- **At:** the hoop's `socket_target` (rim centre).
- **Sequence (about 0.6 s):**
  1. The ball follows its accepted trajectory through the ring.
  2. `part_net` stretches: tween its scale Y from 1.0 to 1.25 and X/Z from 1.0 to 0.92 over 0.12 s, back over 0.2 s, overshoot to 0.96 Y, settle at 0.6 s.
  3. Optionally, a few `sparkle_star` at the rim on a swish with no rim contact.
- **Rim contact:** a tilt impulse on `part_rim` (±3°, 0.2 s damped).
- **Ambient:** `part_net` also has the generated `net_sway` loop. Pause it during the swish tween.

## 6. Small celebration

- **Trigger:** a result event (catch, win, high score, drawing reveal).
- **At:** 1.1 m above the penguin, or the activity's centre for shared results.
- **Sequence (about 1.8 s):**
  1. `spark_star_big` pops from 0 to 1 scale over 0.1 s, spins 30°, and fades over 0.4 s.
  2. 10–14 `confetti_bit` spread outward 0.3–0.6 m, then drift down slowly, tumbling, over 1.2 s, while fading. Tint each piece randomly from coral #E86D58, teal #207D85, cream #FAF1DD and mustard #E3A92B through the instance colour.
- **Rules:** short and restrained, never looping, at most one per player per result. Reduced effects: spark only.

## Done when

- Each of the six effects plays from its event in game, at the real camera distance.
- Each is pooled: no allocations after warm-up.
- A repeated event ID doesn't double the burst.
- A miss shows no swish, and the bobber persists through waiting.
- Reduced-effects mode works.
