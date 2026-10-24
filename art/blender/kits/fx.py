"""Detached effect shapes. The game parents these to socket_fx_* and scales, fades, and moves them.

Concept: docs/concepts/Effect Shapes Prop Kit.jpg. Spec: docs/Prop Kit - Effect Shapes.md.
Ripples stay fishing/ripple. Snowball hits and sled-brake puffs stay winter/snow_puff.
Each mesh origin is the attachment point. Local +Z is up. No motion is baked in.
"""
import math
from common import *

KIT = "fx"
PREVIEW_WIDTH = 4.0


def done(b, socket, size, **meta):
    return b.finish(KIT, "fx", {"socket": socket, "rest_size_m": size, "network": "local", **meta})


def smoke_puff(name, size, seed):
    """Lumpy cream puff. `size` is the width; the bottom sits on the origin."""
    b = Builder(name, seed=seed)
    r = size * 0.42
    with b.at((0, 0, 0), scale=(1.32, 1.32, 1.32)):
        b.blob(r, r * 0.92, r * 0.86, 0, 0, r * 0.9, "smoke", subdiv=1, jitter=0.012)
        b.blob(r * 0.55, r * 0.5, r * 0.48, r * 0.35, r * 0.08, r * 1.35, "smoke_b", subdiv=1, jitter=0.01)
        if size >= 0.3:
            b.blob(r * 0.4, r * 0.38, r * 0.36, -r * 0.28, -r * 0.1, r * 0.55, "smoke", subdiv=1)
    meta = {"origin": "bottom", "life_s": [3, 5]}
    if name != "smoke_puff_l":
        meta["emit_s"] = [0.6, 1.2]
    else:
        meta["note"] = "rare; do not emit a column"
    return done(b, "socket_fx_smoke", size, **meta)


def steam_wisp():
    b = Builder("steam_wisp", seed=4)
    for i in range(5):
        t = i / 4
        y = 0.016 * math.sin(t * math.pi * 2)
        z = 0.018 + t * 0.18
        r = 0.022 * (1.0 - 0.4 * t)
        b.blob(r * 0.7, r, r * 1.15, 0, y, z, "steam" if i % 2 == 0 else "white", subdiv=1)
    return done(b, "socket_fx_steam", 0.22, origin="bottom", life_s=[1.2, 2.0])


def splash_drop():
    b = Builder("splash_drop", seed=5)
    b.blob(0.016, 0.016, 0.02, 0, 0, -0.004, "water", subdiv=1)
    b.blob(0.007, 0.007, 0.01, 0, 0, 0.016, "ice", subdiv=0)
    return done(b, "socket_fx_splash", 0.05, origin="center", trigger="one-shot", note="pool the bursts")


def foam_blob():
    b = Builder("foam_blob", seed=6)
    b.blob(0.11, 0.07, 0.028, 0, 0, 0.028, "foam", subdiv=1, jitter=0.008)
    b.blob(0.035, 0.025, 0.016, 0.04, 0.015, 0.04, "white", subdiv=1)
    return done(b, "socket_fx_splash", 0.22, origin="water plane", trigger="one-shot")


def snow_flake():
    b = Builder("snow_flake", seed=8)
    b.blob(0.025, 0.025, 0.025, 0, 0, 0, "snow", subdiv=0, jitter=0.004)
    return done(b, "camera weather", 0.05, origin="center",
                note="everyday particle; disable indoors and with distance")


def snow_clump():
    b = Builder("snow_clump", seed=9)
    b.blob(0.055, 0.05, 0.048, 0, 0, 0, "snow", subdiv=1, jitter=0.008)
    b.blob(0.028, 0.024, 0.024, 0.038, 0.012, 0.022, "white", subdiv=0)
    return done(b, "socket_fx_spray", 0.12, origin="center",
                note="close flakes and light sled spray; hits stay winter/snow_puff")


def _star_pts(radius, inner=0.4, points=6):
    pts = []
    for i in range(points * 2):
        ang = math.pi * i / points - math.pi / 2
        r = radius if i % 2 == 0 else radius * inner
        pts.append((r * math.cos(ang), r * math.sin(ang)))
    return pts


def snow_star():
    b = Builder("snow_star", seed=10)
    b.prism(_star_pts(0.08), 0.016, z=-0.008, mat="snow", plane="xy", bevel=0.001)
    return done(b, "camera weather", 0.16, origin="center", note="occasional, not the default particle")


def _box(x0, x1, y0, y1, z0, z1):
    return [
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
    ]


def _rotz(v, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    x, y, z = v
    return (c * x - s * y, s * x + c * y, z)


def snowflake():
    """Hero flake, about 0.28 m across. Arms start clear of the centre so faces do not stack."""
    b = Builder("snowflake", seed=11)
    thick = 0.008
    verts, faces = [], []
    quads = [
        (0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1),
        (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0),
    ]

    def add(corners, ang):
        base = len(verts)
        verts.extend(_rotz(v, ang) for v in corners)
        faces.extend(tuple(i + base for i in f) for f in quads)

    for ang in range(0, 360, 60):
        add(_box(0.03, 0.14, -0.008, 0.008, -thick, thick), ang)
        for side in (-1, 1):
            twig = []
            for v in _box(0.0, 0.045, -0.005, 0.005, -thick * 0.7, thick * 0.7):
                x, y, z = _rotz(v, side * 48)
                twig.append((x + 0.085, y, z))
            add(twig, ang)
    b.mesh(verts, faces, mat="snow")
    b.blob(0.02, 0.02, 0.012, 0, 0, 0, "white", subdiv=0)
    return done(b, "camera weather", 0.28, origin="center", note="hero shape; everyday particle is snow_flake")


def flame():
    b = Builder("flame", seed=12)
    b.blob(0.022, 0.022, 0.032, 0, 0, 0.034, "orange", subdiv=1)
    b.blob(0.012, 0.012, 0.02, 0, 0, 0.058, "glow", subdiv=1)
    b.blob(0.006, 0.006, 0.01, 0, 0, 0.08, "bulb", subdiv=0)
    return done(b, "socket_fx_flame", 0.09, origin="bottom",
                note="flicker locally; reduced motion keeps a steady glow")


def sparkle():
    b = Builder("sparkle", seed=13)
    for rot in ((0, 0, 0), (0, 0, 90), (0, 90, 0)):
        with b.at((0, 0, 0), rot=rot):
            b.box(0.06, 0.01, 0.01, 0, 0, 0, "bulb", bevel=0.002, center=True)
    b.blob(0.008, 0.008, 0.008, 0, 0, 0, "gold", subdiv=0)
    return done(b, "socket_fx_sparkle", 0.06, origin="center", trigger="short twinkle")


def build():
    smoke_puff("smoke_puff_s", 0.16, 1)
    smoke_puff("smoke_puff_m", 0.32, 2)
    smoke_puff("smoke_puff_l", 0.48, 3)
    steam_wisp()
    splash_drop()
    foam_blob()
    snow_flake()
    snow_clump()
    snow_star()
    snowflake()
    flame()
    sparkle()
