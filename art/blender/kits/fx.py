"""Effect mesh shapes (sheet: Ambient Effects Prop Kit; note: Animation Kit - Ambient World).
Tiny low-poly particle meshes, origin at their centre, materials named fx_<name> with a soft
emission and alpha blending. Emit them from socket_fx_<kind> sockets (Art Docs/Movable Parts and Effects)."""
from common import *

KIT = "fx"
PREVIEW_WIDTH = 4.0

PALETTE.update({
    "fx_smoke": ("#E8E2D8", 1.0, 0.25), "fx_steam": ("#F6F3EE", 1.0, 0.3), "fx_snow": ("#F4F8FB", 0.9, 0.35),
    "fx_water": ("#8FDDE8", 0.3, 0.35), "fx_foam": ("#F2FBFC", 0.8, 0.35), "fx_sparkle": ("#FFE08A", 0.5, 2.5),
    "fx_confetti": ("#E86D58", 0.8, 0.2), "fx_fishtail": ("#2E7F8C", 0.7, 0.0), "fx_fishtail_b": ("#3C98A4", 0.7, 0.0),
    "fx_flame": ("#F59A3C", 0.6, 3.0), "fx_flame_core": ("#FFE8A8", 0.5, 4.5),
})
ALPHA = {"fx_smoke": 0.75, "fx_steam": 0.55, "fx_snow": 0.95, "fx_water": 0.7, "fx_foam": 0.85, "fx_sparkle": 1.0, "fx_confetti": 1.0,
         "fx_flame": 0.8}


def fx(b, **meta):
    return b.finish(KIT, "fx", meta)


def puff(name, blobs, seed):
    b = Builder(name, seed=seed)
    for (x, y, z, r) in blobs:
        b.blob(r, r * 0.95, r * 0.9, x, y, z, "fx_smoke", subdiv=1, jitter=r * 0.08)
    return b


def build():
    fx(puff("smoke_puff_a", [(0, 0, 0, 0.07)], 1), lifetime_s=[3, 5], particle_size_m=[0.08, 0.2], emit_every_s=[0.6, 1.2],
       usage="chimney smoke (socket_fx_smoke): rise, grow 2-3x, drift with wind, fade out")
    fx(puff("smoke_puff_b", [(-0.04, 0, -0.02, 0.06), (0.04, 0.01, 0.025, 0.075)], 2), lifetime_s=[3, 5], particle_size_m=[0.12, 0.3],
       usage="chimney smoke, mid puff")
    fx(puff("smoke_puff_c", [(-0.06, 0, -0.04, 0.07), (0.05, 0.02, -0.02, 0.08), (0.0, -0.01, 0.06, 0.095)], 3),
       lifetime_s=[4, 5], particle_size_m=[0.2, 0.45], usage="chimney smoke, large late puff")

    b = Builder("steam_wisp", seed=4)
    for i in range(6):  # S-curve of shrinking flattened blobs
        t = i / 5
        b.blob(0.018 * (1 - t * 0.5), 0.012, 0.022, 0.025 * math.sin(t * math.pi * 1.4), 0, -0.06 + 0.12 * t, "fx_steam", subdiv=1)
    fx(b, lifetime_s=[1.0, 1.8], particle_size_m=[0.06, 0.14], usage="coffee machine, mugs and cups (socket_fx_steam): rise and fade")

    b = Builder("snow_flake_a", seed=5)
    b.blob(0.016, 0.016, 0.016, 0, 0, 0, "fx_snow", subdiv=0)
    fx(b, lifetime_s=[4, 8], particle_size_m=[0.01, 0.03], usage="weather: camera-local bounded field, disabled indoors")

    b = Builder("snow_flake_b", seed=6)
    arm = [(0.0, -0.004), (0.022, -0.002), (0.022, 0.002), (0.0, 0.004)]
    for k in range(6):
        with b.at((0, 0, 0), rot=(0, 60 * k, 0)):
            b.prism(arm, 0.004, mat="fx_snow")
    b.blob(0.006, 0.003, 0.006, 0, 0, 0, "fx_snow", subdiv=0)
    fx(b, lifetime_s=[4, 8], particle_size_m=[0.02, 0.05], usage="weather, larger hero flakes (sparser)")

    b = Builder("splash_droplet", seed=7)
    b.sphere(0.018, 0, 0, -0.006, "fx_water", u=6, v=4)
    b.cyl(0.015, 0.03, 0, 0, 0.0, "fx_water", segs=6, r2=0.0)
    fx(b, lifetime_s=[0.4, 0.8], particle_size_m=[0.015, 0.04], usage="fountain/waterfall landing (socket_fx_splash), bobber splash")

    b = Builder("foam_patch", seed=8)
    for i in range(7):
        a = 2 * math.pi * i / 7
        r = b.rng.uniform(0.04, 0.07)
        b.blob(r, r * 0.8, 0.01, 0.08 * math.cos(a), 0.06 * math.sin(a), 0, "fx_foam", subdiv=1, jitter=0.004)
    b.blob(0.07, 0.06, 0.012, 0, 0, 0.002, "fx_foam", subdiv=1)
    fx(b, lifetime_s=[1.5, 3], particle_size_m=[0.15, 0.35], usage="shoreline and fountain basin foam, flat on the water surface")

    b = Builder("snow_puff_small", seed=9)
    for (x, y, z, r) in [(0, 0, 0, 0.06), (0.05, 0.02, -0.01, 0.045), (-0.045, 0.01, 0.0, 0.05), (0.0, -0.03, 0.04, 0.04)]:
        b.blob(r, r, r * 0.9, x, y, z, "fx_snow", subdiv=1, jitter=r * 0.1)
    fx(b, lifetime_s=[0.5, 0.9], particle_size_m=[0.12, 0.3], usage="snowball hit (pooled; winter/snow_puff is the large version)")

    b = Builder("sparkle_star", seed=10)
    star = []
    for k in range(8):
        r = 0.03 if k % 2 == 0 else 0.009
        a = math.pi / 2 + k * math.pi / 4
        star.append((r * math.cos(a), r * math.sin(a)))
    b.prism(star, 0.004, mat="fx_sparkle")
    fx(b, lifetime_s=[0.3, 0.7], particle_size_m=[0.02, 0.06], usage="arcade marquee, celebrations (socket_fx_sparkle); billboard it")

    b = Builder("snow_spray_clump", seed=11)
    for i in range(7):  # fan of blobs thrown up and back from a runner
        t = i / 6
        r = 0.022 + 0.02 * t
        b.blob(r, r, r * 0.8, -0.04 + 0.13 * t, 0.03 * math.sin(i * 1.7), -0.02 + 0.07 * t * (1 - t) * 2.5, "fx_snow", subdiv=1, jitter=r * 0.1)
    fx(b, lifetime_s=[0.4, 0.8], particle_size_m=[0.1, 0.25], usage="sled brake spray (socket_fx_spray on the sled runners)")

    b = Builder("confetti_bit", seed=12)
    b.box(0.03, 0.016, 0.003, 0, 0, 0, "fx_confetti", bevel=0, center=True)
    fx(b, lifetime_s=[1.5, 2.5], particle_size_m=[0.02, 0.04], usage="celebrations; randomise colour per particle in the engine")

    b = Builder("ripple_ring", seed=13)
    b.torus(0.12, 0.006, 0, 0, 0, "fx_water", segs=24, ring=4, rot=(0, 0, 0))
    fx(b, lifetime_s=[0.8, 1.4], particle_size_m=[0.1, 0.6], usage="pooled single ring: scale up 3-5x while fading; one per contact, never stacked")

    b = Builder("flame", seed=14)  # origin = wick top, so it sits on socket_fx_flame with no offset
    b.blob(0.02, 0.02, 0.032, 0, 0, 0.03, "fx_flame", subdiv=1)
    b.blob(0.011, 0.011, 0.02, 0, 0, 0.026, "fx_flame_core", subdiv=1)
    b.cyl(0.012, 0.03, 0, 0, 0.055, "fx_flame", segs=6, r2=0.0)
    fx(b, particle_size_m=[0.06, 0.09], pivot="base (wick top)",
       usage="candles and wood stove (socket_fx_flame): one persistent mesh, local flicker by scale and emission; reduced motion holds a steady glow")

    gameplay()

    # alpha-blended particle materials (exported as glTF alphaMode BLEND)
    for m in bpy.data.materials:
        if m.name in ALPHA:
            bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bsdf.inputs["Alpha"].default_value = ALPHA[m.name]
            if ALPHA[m.name] < 1:
                m.surface_render_method = "BLENDED"


def gameplay():
    """Shapes for the Gameplay Effects sheet (bobber splash, fish escape, snowball impact,
    small celebration). The game sequences and pools them; see Animation Kit - Gameplay Effects."""
    b = Builder("fish_tail", seed=21)  # origin = waterline; only the tail rises above it
    b.cyl(0.03, 0.09, 0, 0, -0.04, "fx_fishtail", segs=6, r2=0.022)                  # wrist under the surface
    for s in (-1, 1):  # two forked lobes, faceted, slightly cupped
        lobe = [(0.0, 0.035), (s * 0.07, 0.07), (s * 0.15, 0.16), (s * 0.17, 0.22), (s * 0.1, 0.19), (s * 0.03, 0.15), (0.0, 0.12)]
        b.prism(lobe, 0.022, mat="fx_fishtail" if s < 0 else "fx_fishtail_b", rot=(0, 0, s * 6))
    b.blob(0.032, 0.02, 0.035, 0, 0, 0.05, "fx_fishtail", subdiv=1)
    b.finish(KIT, "fx", {"lifetime_s": [0.6, 1.0], "particle_size_m": [0.18, 0.26], "pivot": "waterline (z=0)",
                         "usage": "fish escape: rise through the water surface, tip, sink back; pair with splash_crown + ripple_ring_wide"})

    b = Builder("splash_crown", seed=22)
    b.torus(0.07, 0.012, 0, 0, 0.006, "fx_water", segs=16, ring=4)
    for i in range(9):  # droplets leaning outward round the rim
        a = 2 * math.pi * i / 9
        r = 0.08 + 0.01 * (i % 2)
        with b.at((r * math.cos(a), r * math.sin(a), 0.01), rot=(0, 0, math.degrees(a))):
            with b.at((0, 0, 0), rot=(0, 28 + 8 * (i % 3), 0)):
                b.cyl(0.011, 0.05 + 0.015 * (i % 3), 0, 0, 0, "fx_water", segs=5, r2=0.004)
                b.sphere(0.012, 0, 0, 0.075 + 0.015 * (i % 3), "fx_water", u=6, v=4)
    b.finish(KIT, "fx", {"lifetime_s": [0.35, 0.6], "particle_size_m": [0.16, 0.3], "pivot": "water surface, centre",
                         "usage": "bobber hits water (socket_fx_splash/ripple at the bobber): pop up, then hand over to ripple rings"})

    b = Builder("snow_burst", seed=23)
    b.blob(0.075, 0.075, 0.065, 0, 0, 0, "fx_snow", subdiv=1, jitter=0.006)
    for i in range(10):
        a = 2 * math.pi * i / 10 + 0.3 * (i % 2)
        d = 0.1 + 0.03 * (i % 3)
        r = 0.016 + 0.012 * ((i * 7) % 3) / 2
        b.blob(r, r, r * 0.9, d * math.cos(a), d * math.sin(a), 0.02 * ((i % 4) - 1.5), "fx_snow", subdiv=1, jitter=r * 0.1)
    b.finish(KIT, "fx", {"lifetime_s": [0.25, 0.45], "particle_size_m": [0.2, 0.4],
                         "usage": "snowball impact frame 2 (soft burst): spawn at the hit point once per accepted hit, then emit snow_clump_a/b"})

    for nm, seed, specs in (("snow_clump_a", 24, [(0, 0, 0.0, 0.045)]),
                            ("snow_clump_b", 25, [(0, 0, 0.0, 0.035), (0.035, 0.01, -0.01, 0.025), (-0.02, 0.025, -0.012, 0.02)])):
        b = Builder(nm, seed=seed)
        for (x, y, z, r) in specs:
            b.blob(r * 1.15, r, r * 0.8, x, y, z, "fx_snow", subdiv=1, jitter=r * 0.14)
        b.finish(KIT, "fx", {"lifetime_s": [0.8, 1.4], "particle_size_m": [0.03, 0.1],
                             "usage": "scattered/settling clumps after a snowball impact or sled brake: hop out, settle on the ground, fade"})

    b = Builder("spark_star_big", seed=26)
    star = []
    for k in range(8):
        r = 0.08 if k % 2 == 0 else 0.022
        a = math.pi / 2 + k * math.pi / 4
        star.append((r * math.cos(a), r * math.sin(a)))
    b.prism(star, 0.016, mat="fx_sparkle", bevel=0.003)
    for k in range(4):  # short rays between the points, like the sheet
        a = math.pi / 4 + k * math.pi / 2
        with b.at((0.105 * math.cos(a), 0, 0.105 * math.sin(a)), rot=(0, -math.degrees(a), 0)):
            b.box(0.03, 0.008, 0.008, 0, 0, 0, "fx_sparkle", bevel=0, center=True)
    b.finish(KIT, "fx", {"lifetime_s": [0.5, 0.9], "particle_size_m": [0.12, 0.25],
                         "usage": "small celebration frame 1: one spark that scales in, then fades as confetti_bit spreads; billboard it"})

    b = Builder("ripple_ring_wide", seed=27)
    b.torus(0.2, 0.0035, 0, 0, 0, "fx_water", segs=36, ring=4)
    b.finish(KIT, "fx", {"lifetime_s": [1.0, 1.8], "particle_size_m": [0.2, 1.0],
                         "usage": "widening ring (bobber splash frame 3, fish escape frame 3): thinner and wider than ripple_ring; scale up while fading"})
