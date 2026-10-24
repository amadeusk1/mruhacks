"""Interior-personality props (Images/Player Homes - Interior Personalities.png).
Standalone placeable items for the grid decoration system; core furniture lives in room_kit."""
import math
from common import *

KIT = "home_themes"
PREVIEW_WIDTH = 13.0
PALETTE.setdefault("glow_violet", ("#B98AF5", 0.5, 1.2))
PALETTE.setdefault("neon_violet", ("#B070FF", 0.5, 1.3))
PALETTE.setdefault("neon_teal", ("#4FE3EA", 0.5, 1.3))
PALETTE.setdefault("star_glow", ("#FFC23F", 0.5, 1.2))
PALETTE.setdefault("moon_glow", ("#FFD36B", 0.5, 0.9))
PALETTE.setdefault("glow_fire", ("#FF9A3C", 0.5, 4.0))
PALETTE.setdefault("mirror", ("#BFDDE6", 0.15, 0))

FINISH = tint("finish", "wood")


def done(b, layer, category="decor", meta=None, **pl):
    return b.finish(KIT, category, {**placement(layer, **pl), **(meta or {})})


def legs(b, w, d, h, inset=0.06, mat=FINISH, s=0.06, r2=None):
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(s / 2, h, sx * (w / 2 - inset), sy * (d / 2 - inset), 0, mat, segs=6, r2=r2, bevel=0.006)


def knob(b, x, y, z, mat="gold"):
    b.sphere(0.022, x, y, z, mat, u=6, v=4)


def drawer(b, w, h, x, y, z, front=FINISH):
    """Drawer front on a cabinet face at y (front = -Y), bottom at z."""
    b.box(w, 0.03, h, x, y - 0.012, z, front, bevel=0.01)
    knob(b, x, y - 0.04, z + h / 2)


def star_pts(r, inner=0.45, n=5, rot=90):
    return [((r if i % 2 == 0 else r * inner) * math.cos(math.radians(rot + 180 * i / n)),
             (r if i % 2 == 0 else r * inner) * math.sin(math.radians(rot + 180 * i / n))) for i in range(2 * n)]


def crescent_pts(R, cut=0.82, off=(0.42, 0.12), n=48):
    """Crescent outline: the part of a circle (radius R) outside an offset circle (radius R*cut)."""
    cx, cy, r = R * off[0], R * off[1], R * cut
    ang = [2 * math.pi * i / n for i in range(n)]
    outer = [(R * math.cos(a), R * math.sin(a)) for a in ang]
    keep = [math.hypot(x - cx, y - cy) > r for x, y in outer]
    start = next(i for i in range(n) if keep[i] and not keep[i - 1])
    arc = [outer[(start + i) % n] for i in range(n) if keep[(start + i) % n]]
    inner = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in ang]
    inside = [p for p in inner if math.hypot(*p) < R]
    # walk the inner arc back from the outer arc's end to its start
    end = arc[-1]
    k = min(range(len(inner)), key=lambda i: math.hypot(inner[i][0] - end[0], inner[i][1] - end[1]))
    back = []
    for i in range(len(inner)):
        q = inner[(k - i) % len(inner)]
        if q in inside:
            back.append(q)
    return arc + back


assert len(crescent_pts(1.0)) > 20


def tufted(b, w, d, h, z, mat, x=0, y=0, bevel=0.06, buttons=0):
    b.box(w, d, h, x, y, z, mat, bevel=bevel)
    for i in range(buttons):
        bx = x + (i - (buttons - 1) / 2) * w / max(buttons, 1)
        b.sphere(0.018, bx, y, z + h + 0.004, "gold", u=6, v=4)


# ---------------------------------------------------------------- cozy loft
def wood_stove():
    b = Builder("wood_stove", seed=11)
    body = tint("stove", "charcoal")
    b.box(0.86, 0.66, 0.05, 0, 0, 0, tint("hearth", "stone_grey"), bevel=0.012)            # hearth tile
    for i, x in enumerate((-0.28, 0.0, 0.28)):
        b.box(0.27, 0.62, 0.012, x, 0, 0.05, pick(("stone", "stone_dark", "paving_b"), i), bevel=0.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(0.028, 0.12, sx * 0.2, sy * 0.15, 0.062, body, segs=6, r2=0.04)
    b.box(0.54, 0.42, 0.5, 0, 0, 0.17, body, bevel=0.03)                                  # firebox
    b.box(0.6, 0.48, 0.05, 0, 0, 0.67, body, bevel=0.015)                                  # top plate
    b.box(0.5, 0.38, 0.03, 0, 0, 0.72, "iron_light", bevel=0.01)
    # door with glowing window and fire logs behind
    b.box(0.28, 0.01, 0.2, 0, -0.212, 0.29, "glow_fire", bevel=0)                             # fire seen when open
    with b.part("door", pivot=(-0.18, -0.23, 0.25), motion="hinge", axis="z", open_deg=-100):
        b.box(0.36, 0.03, 0.3, 0, -0.23, 0.25, "iron_light", bevel=0.012)
        b.box(0.26, 0.03, 0.18, 0, -0.24, 0.3, "glow_fire", bevel=0.004)
        for i in range(3):
            b.box(0.016, 0.035, 0.18, -0.08 + 0.08 * i, -0.25, 0.3, "iron", bevel=0)
        b.box(0.03, 0.06, 0.04, 0.15, -0.265, 0.34, "gold", bevel=0.008)
    b.socket("fx_flame", (0, -0.1, 0.24))
    b.box(0.4, 0.04, 0.02, 0, -0.226, 0.215, "iron_light", bevel=0.004)                      # ash lip
    # stovepipe with damper and collar
    b.cyl(0.085, 0.06, 0, 0.06, 0.75, body, segs=10)
    b.cyl(0.07, 1.25, 0, 0.06, 0.81, body, segs=10)
    b.cyl(0.082, 0.035, 0, 0.06, 1.2, "iron_light", segs=10)
    b.cyl(0.082, 0.035, 0, 0.06, 1.75, "iron_light", segs=10)
    b.socket("use", (0, -0.75, 0), rotz=180)
    b.socket("light", (0, -0.25, 0.36))
    return done(b, "floor", "furniture", clearance=1, meta={"light": "warm"})


def side_table():
    b = Builder("side_table", seed=12)
    legs(b, 0.42, 0.36, 0.12, inset=0.04, s=0.05)
    b.box(0.44, 0.38, 0.42, 0, 0, 0.12, FINISH, bevel=0.02)
    b.box(0.5, 0.42, 0.05, 0, 0, 0.54, FINISH, bevel=0.015)
    drawer(b, 0.36, 0.13, 0, -0.19, 0.38)
    b.box(0.36, 0.02, 0.18, 0, -0.18, 0.15, tint("trim", "wood_dark"), bevel=0.005)          # open cubby back
    b.box(0.36, 0.3, 0.02, 0, -0.02, 0.15, FINISH, bevel=0.004)
    b.socket("surface_0", (0, 0, 0.59))
    return done(b, "floor", "furniture", meta={"surfaces": {"surface_0": [0.44, 0.36]}})


def log_basket():
    b = Builder("log_basket", seed=13)
    weave = tint("basket", "tan")
    b.cyl(0.24, 0.04, 0, 0, 0, weave, segs=12, bevel=0.01)
    for i in range(5):                                                                     # coiled bands
        b.cyl(0.25 + 0.005 * i, 0.055, 0, 0, 0.04 + 0.055 * i, pick((weave, "rope"), i), segs=12, bevel=0.012, cap=False)
    b.cyl(0.235, 0.27, 0, 0, 0.04, "wood_deep", segs=12, cap=False)                         # inner wall
    for sx in (-1, 1):
        b.torus(0.07, 0.014, sx * 0.26, 0, 0.33, "rope", segs=8, ring=5, rot=(90, 0, 90))
    for i, (x, y, z, rz) in enumerate([(-0.08, -0.07, 0.3, 4), (0.08, -0.06, 0.31, -6), (0.0, 0.08, 0.32, 10),
                                       (-0.1, 0.06, 0.4, -3), (0.1, 0.04, 0.41, 8)]):
        with b.at((x, y, z), rot=(0, 90, rz)):
            b.cyl(0.055, 0.5, 0, 0, -0.25, pick(("bark", "wood_dark"), i), segs=7, bevel=0.008)
            for e in (-0.252, 0.25):
                b.cyl(0.048, 0.006, 0, 0, e, "tan", segs=7)
    return done(b, "floor")


# ---------------------------------------------------------------- botanical nook
def window_seat_bench():
    b = Builder("window_seat_bench", seed=21)
    W, D = 1.3, 0.5
    b.box(W, D, 0.08, 0, 0, 0, tint("trim", "wood_dark"), bevel=0.012)                     # plinth
    b.box(W, D, 0.3, 0, 0, 0.08, FINISH, bevel=0.02)
    for i in range(3):
        drawer(b, W / 3 - 0.06, 0.2, -W / 3 + i * W / 3, -D / 2, 0.13)
    b.box(W + 0.04, D + 0.02, 0.04, 0, 0, 0.38, FINISH, bevel=0.012)
    cush = tint("cushion", "sage")
    b.box(W - 0.06, D - 0.06, 0.08, 0, 0, 0.42, cush, bevel=0.035)
    for i in range(2):
        b.box(0.01, D - 0.1, 0.004, -W / 6 + i * W / 3, 0, 0.497, tint("cushion_b", "olive"), bevel=0)  # seams
    for x, rz in ((-0.5, 12), (0.5, -10)):
        with b.at((x, 0.14, 0.62), rot=(-18, 0, rz)):
            b.box(0.3, 0.1, 0.24, 0, 0, 0, tint("pillow", "cream"), bevel=0.045, center=True)
    b.socket("seat_0", (-0.3, -0.05, 0.5))
    b.socket("seat_1", (0.3, -0.05, 0.5))
    return done(b, "floor", "furniture", rotations=(0, 90, 180, 270))


def monstera_leaf(b, L, w, mat):
    pts = []
    for i in range(22):
        t = 2 * math.pi * i / 22
        notch = 0.72 if (abs(math.sin(t)) > 0.45 and i % 3 == 1) else 1.0
        pts.append((0.5 * w * math.sin(t) * notch, L * (0.5 - 0.5 * math.cos(t)) * (0.95 + 0.05 * notch)))
    b.prism(pts, 0.014, mat=mat, rot=(0, 0, 0))
    b.box(0.012, 0.02, L * 0.9, 0, -0.006, L * 0.05, "leaf_dark", bevel=0)                  # midrib


def large_monstera():
    b = Builder("large_monstera", seed=22)
    pot = tint("pot", "cream")
    b.cyl(0.2, 0.34, 0, 0, 0, pot, segs=8, r2=0.25, bevel=0.012)
    b.cyl(0.265, 0.05, 0, 0, 0.32, pot, segs=8, bevel=0.012)
    b.cyl(0.23, 0.02, 0, 0, 0.35, "soil", segs=8)
    leaves = [(0, 0.55, 0.42, 0, -25), (60, 0.5, 0.38, 25, -35), (140, 0.48, 0.36, -20, -40),
              (200, 0.55, 0.4, 10, -30), (270, 0.5, 0.38, -15, -45), (320, 0.45, 0.34, 20, -20), (100, 0.6, 0.44, 0, -10)]
    for i, (yaw, L, w, roll, tilt) in enumerate(leaves):
        stem_h = 0.45 + 0.25 * ((i * 37) % 5) / 5
        a = math.radians(yaw)
        tip = (math.cos(a) * 0.18, math.sin(a) * 0.18, 0.36 + stem_h)
        d = Vector(tip) - Vector((0, 0, 0.36))
        q = d.to_track_quat("Z", "Y").to_euler()
        b.cyl(0.012, d.length, 0, 0, 0.36, "leaf_dark", segs=5, rot=tuple(math.degrees(v) for v in q))
        with b.at(tip, rot=(tilt, roll, yaw - 90)):
            monstera_leaf(b, L, w, pick(("leaf", "leaf_b", "leaf_dark"), i))
    return done(b, "floor", "plant", meta={"also_layer": "surface_large"})


def hanging_planter_cluster():
    b = Builder("hanging_planter_cluster", seed=23)
    b.box(0.9, 0.12, 0.06, 0, 0, -0.06, FINISH, bevel=0.015)                               # ceiling batten
    b.torus(0.03, 0.008, 0, 0, -0.005, "iron", segs=8, ring=4, rot=(90, 0, 0))
    for i, (x, drop, r) in enumerate(((-0.32, 0.55, 0.12), (0.0, 0.85, 0.15), (0.32, 0.4, 0.11))):
        z = -0.06 - drop
        with b.part(f"planter_{i}", pivot=(x, 0, -0.06), motion="sway", amp_deg=3 + i):
            hang_pot(b, i, x, z, r)
    return done(b, "ceiling", "plant", rotations=(0, 90, 180, 270))


def hang_pot(b, i, x, z, r):
    for k in range(3):
        a = math.radians(90 + 120 * k)
        rope_between(b, (x, 0, -0.06), (x + math.cos(a) * r * 0.9, math.sin(a) * r * 0.9, z + r * 0.9),
                     sag=0.0, r=0.006, segs=1)
    b.cyl(r * 0.7, r * 0.9, x, 0, z, tint("pot", "terracotta"), segs=8, r2=r, bevel=0.008)
    b.cyl(r * 0.9, 0.015, x, 0, z + r * 0.85, "soil", segs=8)
    for j in range(4):                                                                 # foliage + trailing vine
        b.blob(r * 0.55, r * 0.55, r * 0.45, x + b.rng.uniform(-r, r) * 0.5, b.rng.uniform(-r, r) * 0.5,
               z + r * 1.1, pick(("leaf", "leaf_b", "leaf_dark"), i + j), subdiv=1, jitter=0.006)
    for v in range(2):
        vx = x + (v - 0.5) * r * 1.2
        for s in range(4 + i):
            b.blob(0.035, 0.03, 0.03, vx + 0.015 * math.sin(s), -r * 0.6, z + r * 0.4 - 0.07 * s,
                   pick(("leaf_b", "leaf"), s), subdiv=1)


def plant_stand_tiered():
    b = Builder("plant_stand_tiered", seed=24)
    H, W = 1.0, 0.7
    for sx in (-1, 1):                                                                     # A-frame ladder sides
        for sy, ang in ((-1, -12), (1, 12)):
            b.box(0.05, 0.05, H, sx * W / 2, sy * 0.1, 0, FINISH, bevel=0.01, rot=(ang, 0, 0))
    surfaces = {}
    for i, (z, y, d) in enumerate(((0.25, -0.17, 0.2), (0.55, -0.1, 0.18), (0.85, -0.03, 0.16))):
        b.box(W + 0.04, d, 0.035, 0, y, z, pick((FINISH, "wood_b", "wood_c"), i), bevel=0.008)
        b.socket(f"surface_{i}", (0, y, z + 0.035))
        surfaces[f"surface_{i}"] = [W, d]
    return done(b, "floor", "furniture", meta={"surfaces": surfaces})


def woven_round_rug():
    b = Builder("woven_round_rug", seed=25)
    a, c = tint("rug", "tan"), tint("rug_b", "brown")
    b.cyl(0.05, 0.012, 0, 0, 0, a, segs=8)
    for i in range(10):
        R = 0.09 + i * 0.075
        with b.at((0, 0, 0.012), scale=(1, 1, 0.45)):
            b.torus(R, 0.034, 0, 0, 0, c if i in (3, 7) else pick((a, "rope"), i), segs=28, ring=5)
    return done(b, "rug", "rug")


# ---------------------------------------------------------------- gamer den
def tv_console():
    b = Builder("tv_console", seed=31)
    W, D, H = 1.5, 0.42, 0.42
    legs(b, W, D, 0.1, inset=0.08, s=0.05, mat="wood_dark", r2=0.018)
    for sx in (-1, 1):                                                                     # hollow side cupboards
        b.box(0.5, D, 0.03, sx * 0.5, 0, 0.1, FINISH, bevel=0.008)
        b.box(0.5, D, 0.03, sx * 0.5, 0, H - 0.03, FINISH, bevel=0.008)
        b.box(0.03, D, H - 0.1, sx * 0.735, 0, 0.1, FINISH, bevel=0.008)
        b.box(0.03, D, H - 0.1, sx * 0.265, 0, 0.1, FINISH, bevel=0.008)
        b.box(0.44, 0.02, H - 0.16, sx * 0.5, D / 2 - 0.02, 0.13, "wood_deep", bevel=0)
        b.box(0.44, D - 0.06, 0.02, sx * 0.5, 0.01, 0.25, FINISH, bevel=0.004)             # inner shelf
    b.box(0.5, D, 0.04, 0, 0, 0.1, FINISH, bevel=0.01)                                     # open centre niche
    b.box(0.5, D, 0.04, 0, 0, H - 0.04, FINISH, bevel=0.01)
    b.box(0.5, 0.03, H - 0.18, 0, D / 2 - 0.015, 0.14, "wood_deep", bevel=0)
    b.box(W + 0.04, D + 0.02, 0.04, 0, 0, H, FINISH, bevel=0.012)
    for sx in (-1, 1):                                                                     # side doors, hinged outside
        with b.part(f"door_{'l' if sx < 0 else 'r'}", pivot=(sx * 0.71, -D / 2 - 0.025, 0.13), motion="hinge",
                    axis="z", open_deg=-100 * sx):
            b.box(0.42, 0.03, 0.26, sx * 0.5, -D / 2 - 0.01, 0.13, tint("doors", "navy"), bevel=0.01)
            knob(b, sx * 0.33, -D / 2 - 0.04, 0.26)
    b.socket("surface_0", (0, 0.04, H + 0.04))
    b.socket("surface_shelf", (0, 0.0, 0.14))
    return done(b, "floor", "furniture", meta={"surfaces": {"surface_0": [1.5, 0.4], "surface_shelf": [0.46, 0.36]}})


def tv():
    b = Builder("tv", seed=32)
    b.box(0.34, 0.2, 0.025, 0, 0, 0, "black", bevel=0.008)                                  # foot
    b.box(0.06, 0.04, 0.12, 0, 0.03, 0.02, "charcoal", bevel=0.01)
    b.box(1.0, 0.06, 0.6, 0, 0.03, 0.1, tint("frame", "black"), bevel=0.02)
    b.box(0.93, 0.02, 0.53, 0, -0.005, 0.135, "insert_screen", bevel=0)
    b.box(0.05, 0.01, 0.015, 0.42, -0.003, 0.11, "glow_teal", bevel=0)                      # power led
    b.socket("screen", (0, -0.02, 0.4))
    return done(b, "surface", "electronics", rotations=(0, 90, 180, 270))


def game_console():
    b = Builder("game_console", seed=33)
    body = tint("body", "white")
    b.box(0.3, 0.22, 0.07, -0.05, 0, 0, body, bevel=0.015)
    b.box(0.3, 0.012, 0.012, -0.05, -0.11, 0.03, "glow_teal", bevel=0)
    b.box(0.08, 0.012, 0.025, -0.15, -0.111, 0.022, "charcoal", bevel=0.004)
    with b.at((0.2, -0.02, 0), rotz=-20):                                                  # controller
        c = tint("controller", "charcoal")
        b.box(0.14, 0.07, 0.035, 0, 0, 0, c, bevel=0.015)
        for sx in (-1, 1):
            b.blob(0.035, 0.04, 0.02, sx * 0.065, 0.02, 0.018, c, subdiv=1)
        b.cyl(0.012, 0.02, -0.035, -0.005, 0.035, "black", segs=6)
        for k, m in enumerate(("petal_red", "petal_yellow", "teal_light", "blue")):
            a = math.radians(90 * k)
            b.cyl(0.008, 0.008, 0.035 + 0.012 * math.cos(a), -0.005 + 0.012 * math.sin(a), 0.035, m, segs=6)
    return done(b, "surface", "electronics")


def beanbag():
    b = Builder("beanbag", seed=34)
    m = tint("fabric", "purple")
    b.blob(0.4, 0.38, 0.22, 0, 0, 0.21, m, subdiv=2, jitter=0.015)
    b.blob(0.3, 0.16, 0.24, 0, 0.17, 0.4, m, subdiv=2, jitter=0.012, rot=(-15, 0, 0))     # slumped back
    b.blob(0.22, 0.2, 0.06, 0, -0.06, 0.4, tint("seat_dent", "lavender"), subdiv=1, jitter=0.004)  # seat dent: own role, not a shade of fabric
    b.socket("seat_0", (0, -0.05, 0.4))
    return done(b, "floor", "seating")


def pouf_round():
    b = Builder("pouf_round", seed=35)
    m = tint("fabric", "navy")
    b.cyl(0.235, 0.3, 0, 0, 0, m, segs=12, bevel=0.06)   # fits one 0.5 m cell
    b.cyl(0.245, 0.04, 0, 0, 0.13, tint("piping", "teal_light"), segs=12, bevel=0.01, cap=False)
    b.sphere(0.022, 0, 0, 0.3, "gold", u=6, v=4)
    b.socket("seat_0", (0, 0, 0.31))
    return done(b, "floor", "seating")


def pouf_square():
    b = Builder("pouf_square", seed=36)
    m = tint("fabric", "teal")
    tufted(b, 0.46, 0.46, 0.3, 0.03, m, bevel=0.07)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(0.02, 0.04, sx * 0.17, sy * 0.17, 0, "wood_dark", segs=6)
    for x, y in ((-0.1, -0.1), (0.1, -0.1), (-0.1, 0.1), (0.1, 0.1)):
        b.sphere(0.018, x, y, 0.335, "gold", u=6, v=4)
    b.socket("seat_0", (0, 0, 0.34))
    return done(b, "floor", "seating")


def neon_wall_sign():
    b = Builder("neon_wall_sign", seed=37)
    b.box(0.9, 0.04, 0.6, 0, -0.02, -0.3, "insert_sign", bevel=0.015, center=False)          # backboard (wall at y=0)
    for x, z in ((-0.38, 0.22), (0.38, 0.22), (-0.38, -0.22), (0.38, -0.22)):
        b.cyl(0.015, 0.03, x, -0.04, z, "steel", segs=6, rot=(90, 0, 0))
    neon = tint("neon", "neon_violet")
    tri = [(-0.3, -0.18), (0.3, -0.18), (0.0, 0.22)]
    for (x0, z0), (x1, z1) in zip(tri, tri[1:] + tri[:1]):                                  # mountain triangle
        d = Vector((x1 - x0, 0, z1 - z0))
        q = d.to_track_quat("Z", "Y").to_euler()
        b.cyl(0.016, d.length, x0, -0.07, z0, neon, segs=6, rot=tuple(math.degrees(v) for v in q))
    b.cyl(0.016, 0.3, -0.15, -0.07, -0.02, tint("neon_b", "neon_teal"), segs=6, rot=(0, 90, 0))  # horizon line
    return done(b, "wall", "decor", rotations=(0,), meta={"light": "neon"})


def gaming_chair():
    b = Builder("gaming_chair", seed=38)
    up, trim = tint("upholstery", "charcoal"), tint("trim", "coral")
    for k in range(5):                                                                     # star base + casters
        a = math.radians(90 + 72 * k)
        b.box(0.3, 0.05, 0.04, math.cos(a) * 0.15, math.sin(a) * 0.15, 0.06, "black", bevel=0.01, rot=(0, 0, 72 * k + 90))
        b.sphere(0.03, math.cos(a) * 0.29, math.sin(a) * 0.29, 0.03, "charcoal", u=6, v=4)
    b.cyl(0.03, 0.3, 0, 0, 0.08, "steel", segs=8)
    with b.part("seat", pivot=(0, 0, 0.36), motion="spin", axis="z"):
        chair_top(b, up, trim)
    b.socket("seat_0", (0, -0.03, 0.46))
    return done(b, "floor", "seating")


def chair_top(b, up, trim):
    b.box(0.5, 0.48, 0.1, 0, 0, 0.36, up, bevel=0.035)
    for sx in (-1, 1):
        b.box(0.07, 0.42, 0.06, sx * 0.25, 0, 0.42, trim, bevel=0.025)                      # seat bolsters
        b.box(0.05, 0.05, 0.18, sx * 0.29, -0.02, 0.38, "black", bevel=0.01)
        b.box(0.08, 0.26, 0.04, sx * 0.29, -0.02, 0.56, "charcoal", bevel=0.012)             # armrest
    with b.at((0, 0.22, 0.44), rot=(-10, 0, 0)):
        b.box(0.48, 0.1, 0.7, 0, 0, 0, up, bevel=0.04)
        for sx in (-1, 1):
            b.box(0.07, 0.12, 0.6, sx * 0.23, -0.02, 0.05, trim, bevel=0.03)
        b.box(0.22, 0.06, 0.12, 0, -0.07, 0.5, trim, bevel=0.03)                            # headrest pad


# ---------------------------------------------------------------- artist studio
def easel_with_canvas():
    b = Builder("easel_with_canvas", seed=41)
    for sx in (-1, 1):                                                                     # front legs lean back
        b.box(0.045, 0.045, 1.55, sx * 0.24, -0.12, 0, FINISH, bevel=0.008, rot=(-10, -8 * sx, 0))
    b.box(0.045, 0.045, 1.45, 0, 0.55, 0, FINISH, bevel=0.008, rot=(16, 0, 0))              # back leg
    b.box(0.6, 0.03, 0.04, 0, 0.0, 0.3, FINISH, bevel=0.006)                               # spreader
    b.box(0.62, 0.11, 0.035, 0, -0.07, 0.62, FINISH, bevel=0.01)                            # ledge
    b.box(0.62, 0.025, 0.04, 0, -0.115, 0.655, FINISH, bevel=0.006)
    b.box(0.07, 0.05, 0.08, 0, 0.06, 1.42, FINISH, bevel=0.01)                              # top clamp
    with b.at((0, -0.06, 0.66), rot=(-10, 0, 0)):
        b.box(0.62, 0.035, 0.78, 0, 0, 0, tint("canvas_edge", "white"), bevel=0.008)
        b.box(0.56, 0.01, 0.72, 0, -0.02, 0.03, "insert_poster", bevel=0)
    b.socket("use", (0, -0.65, 0), rotz=180)
    return done(b, "floor", "furniture", clearance=1)


def drafting_table():
    b = Builder("drafting_table", seed=42)
    for sx in (-1, 1):                                                                     # trestle legs
        b.box(0.05, 0.55, 0.05, sx * 0.48, 0, 0, FINISH, bevel=0.01)
        b.box(0.06, 0.06, 0.72, sx * 0.48, 0, 0.03, FINISH, bevel=0.012)
    b.box(1.0, 0.05, 0.05, 0, 0.02, 0.18, FINISH, bevel=0.01)
    b.box(0.86, 0.44, 0.12, 0, 0.03, 0.62, FINISH, bevel=0.015)                             # drawer apron
    drawer(b, 0.3, 0.08, 0.2, -0.19, 0.64)
    with b.at((0, -0.02, 0.8), rot=(14, 0, 0)):
        b.box(1.04, 0.66, 0.04, 0, 0, 0, tint("top", "sage"), bevel=0.012, center=True)
        b.box(1.04, 0.035, 0.05, 0, -0.33, 0.02, FINISH, bevel=0.008)                       # pencil ledge
    b.socket("use", (0, -0.6, 0), rotz=180)
    return done(b, "floor", "furniture", clearance=1)


def canvas_stack():
    b = Builder("canvas_stack", seed=43)
    for i, (w, h, x, ang) in enumerate(((0.55, 0.7, 0.0, 10), (0.48, 0.6, 0.04, 14), (0.6, 0.45, -0.03, 18), (0.4, 0.5, 0.06, 22))):
        with b.at((x, 0.04 * i - 0.06, 0), rot=(-ang, 0, (i - 1.5) * 3)):
            b.box(w, 0.03, h, 0, 0, 0, tint("frame", "wood_c") if i % 2 else "wood_c", bevel=0.008)
            if i in (0, 2):
                b.box(w - 0.05, 0.01, h - 0.05, 0, -0.02, 0.025, "insert_poster", bevel=0)
            else:
                b.box(w - 0.06, 0.012, h - 0.06, 0, 0.018, 0.03, "cream", bevel=0)         # canvas back
                b.box(w - 0.06, 0.025, 0.03, 0, 0.02, h / 2 - 0.015, "wood_b", bevel=0)
    return done(b, "floor")


def paint_supplies():
    b = Builder("paint_supplies", seed=44)
    b.cyl(0.05, 0.12, -0.08, 0.02, 0, tint("jar", "glass"), segs=8)                        # brush jar
    b.cyl(0.045, 0.03, -0.08, 0.02, 0, "sky", segs=8)
    for i, (dx, dy, tip) in enumerate(((-0.015, 0, "petal_red"), (0.015, 0.01, "teal_light"), (0, -0.015, "petal_yellow"),
                                         (0.02, -0.01, "purple"))):
        b.cyl(0.006, 0.22, -0.08 + dx, 0.02 + dy, 0.02, "wood", segs=5, rot=(dy * 200, dx * 200, 0))
        b.cyl(0.009, 0.03, -0.08 + dx * 1.6, 0.02 + dy * 1.6, 0.23, tip, segs=5, r2=0.003)
    with b.at((0.08, -0.02, 0), rotz=-25):                                                  # palette
        pts = [(0.11 * math.cos(math.radians(a)), 0.08 * math.sin(math.radians(a))) for a in range(0, 360, 30)]
        b.prism(pts, 0.012, mat="wood_c", plane="xy")
        for k, m in enumerate(("petal_red", "petal_yellow", "teal_light", "blue", "white")):
            a = math.radians(40 + 60 * k)
            b.blob(0.018, 0.018, 0.008, 0.07 * math.cos(a), 0.05 * math.sin(a), 0.014, m, subdiv=1)
    for i, m in enumerate(("petal_red", "blue")):                                           # tubes
        b.cyl(0.013, 0.08, 0.02 + i * 0.03, 0.09, 0.013, m, segs=6, rot=(0, 90, 15), r2=0.009)
    return done(b, "surface", "decor")


def tall_dresser():
    b = Builder("tall_dresser", seed=45)
    body = tint("finish", "teal")
    b.box(0.72, 0.44, 0.08, 0, 0, 0, tint("trim", "wood_dark"), bevel=0.012)
    b.box(0.68, 0.42, 1.1, 0, 0, 0.08, body, bevel=0.02)
    b.box(0.74, 0.46, 0.05, 0, 0, 1.18, body, bevel=0.015)
    for i in range(4):
        z = 0.12 + i * 0.26
        b.box(0.58, 0.006, 0.2, 0, -0.211, z + 0.01, "wood_deep", bevel=0)                   # dark opening
        with b.part(f"drawer_{i}", pivot=(0, -0.215, z), motion="slide", dir=(0, -1, 0), dist=0.28):
            b.box(0.6, 0.03, 0.22, 0, -0.215, z, tint("drawers", "teal_light"), bevel=0.012)
            for sx in (-1, 1):                                                             # drawer box, hidden when shut
                b.box(0.02, 0.32, 0.17, sx * 0.27, -0.04, z + 0.02, "wood_c", bevel=0.004)
            b.box(0.56, 0.32, 0.015, 0, -0.04, z + 0.02, "wood_c", bevel=0.004)
            b.box(0.56, 0.02, 0.17, 0, 0.12, z + 0.02, "wood_c", bevel=0.004)
            for sx in (-1, 1):
                knob(b, sx * 0.16, -0.24, z + 0.11)
    b.socket("surface_0", (0, 0, 1.23))
    return done(b, "floor", "furniture", meta={"surfaces": {"surface_0": [0.7, 0.4]}})


def storage_crate():
    b = Builder("storage_crate", seed=46)
    m = tint("finish", "teal")
    W, D, H = 0.52, 0.4, 0.34
    b.box(W - 0.04, D - 0.04, 0.03, 0, 0, 0.01, "wood_dark", bevel=0.005)
    for i in range(3):                                                                     # slats on 4 sides
        z = 0.02 + i * 0.105
        b.box(W, 0.03, 0.085, 0, -D / 2 + 0.015, z, m, bevel=0.01)
        b.box(W, 0.03, 0.085, 0, D / 2 - 0.015, z, m, bevel=0.01)
        b.box(0.03, D - 0.06, 0.085, -W / 2 + 0.015, 0, z, m, bevel=0.01)
        b.box(0.03, D - 0.06, 0.085, W / 2 - 0.015, 0, z, m, bevel=0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.05, 0.05, H, sx * (W / 2 - 0.02), sy * (D / 2 - 0.02), 0, tint("corners", "wood_dark"), bevel=0.01)
    b.socket("surface_0", (0, 0, H))
    return done(b, "floor", "furniture", meta={"surfaces": {"surface_0": [W, D]}, "stackable": True})


def striped_rug():
    b = Builder("striped_rug", seed=47)
    W, D, n = 1.6, 1.1, 7
    a, c = tint("stripe_a", "cream"), tint("stripe_b", "sky")
    for i in range(n):
        b.box(W, D / n, 0.016, 0, -D / 2 + D / n * (i + 0.5), 0, a if i % 2 == 0 else c, bevel=0.004)
    for sx in (-1, 1):
        for k in range(10):
            b.box(0.07, 0.022, 0.008, sx * (W / 2 + 0.03), -D / 2 + 0.05 + k * (D - 0.1) / 9, 0, "cream", bevel=0.002)
    return done(b, "rug", "rug")


# ---------------------------------------------------------------- coastal retreat
def ship_wheel_wall():
    b = Builder("ship_wheel_wall", seed=51)
    w = tint("wood", "wood")
    with b.part("wheel", pivot=(0, -0.09, 0), motion="spin", axis="y"), b.at((0, -0.09, 0), rot=(90, 0, 0)):
        b.torus(0.3, 0.035, 0, 0, 0, w, segs=20, ring=6)
        b.torus(0.17, 0.02, 0, 0, 0, "wood_dark", segs=16, ring=5)
        b.cyl(0.07, 0.08, 0, 0, -0.04, "wood_dark", segs=10, bevel=0.01)
        b.cyl(0.035, 0.03, 0, 0, 0.04, "gold", segs=8)
        for k in range(8):
            a = math.radians(45 * k)
            with b.at((0, 0, 0), rotz=45 * k):
                b.box(0.4, 0.035, 0.035, 0.2, 0, 0, w, bevel=0.008, center=True)
                b.cyl(0.026, 0.13, 0.43, 0, 0, w, segs=6, r2=0.018, rot=(0, 90, 0), bevel=0.004)
    b.box(0.08, 0.05, 0.12, 0, -0.025, -0.03, "iron", bevel=0.01)                            # wall peg
    return done(b, "wall", "decor", rotations=(0,))


def model_sailboat():
    b = Builder("model_sailboat", seed=52)
    hull = tint("hull", "navy")
    b.box(0.2, 0.06, 0.02, 0, 0, 0, "wood_dark", bevel=0.005)                               # stand
    for sx in (-1, 1):
        b.box(0.015, 0.04, 0.06, sx * 0.08, 0, 0.02, "wood_dark", bevel=0.003)
    pts = [(-0.18, 0.1), (0.2, 0.1), (0.13, 0.05), (-0.13, 0.05)]
    b.prism(pts, 0.08, 0, 0, 0, hull, bevel=0.008)
    b.box(0.34, 0.07, 0.012, 0, 0, 0.1, "wood_c", bevel=0.003)                              # deck
    b.box(0.36, 0.085, 0.012, 0, 0, 0.088, "white", bevel=0.003)                            # waterline stripe
    b.cyl(0.006, 0.3, 0.02, 0, 0.11, "wood_dark", segs=5)
    sail = tint("sail", "cream")
    b.prism([(0.03, 0.14), (0.15, 0.14), (0.03, 0.4)], 0.008, mat=sail)
    b.prism([(0.01, 0.15), (-0.13, 0.15), (0.01, 0.36)], 0.008, mat=sail)
    b.prism([(0.02, 0.41), (0.02, 0.45), (0.07, 0.43)], 0.004, mat="coral")                 # pennant
    return done(b, "surface", "decor")


def curved_bookshelf():
    b = Builder("curved_bookshelf", seed=53)
    R, D, H, bays, span = 2.5, 0.34, 1.8, 4, 52.0   # fits a round wall of radius R; spans `span` degrees
    m = tint("finish", "wood")
    surfaces = {}
    step = span / bays
    for i in range(bays + 1):                                                               # uprights
        a = -span / 2 + step * i
        with b.at((0, R, 0), rotz=a):
            b.box(0.04, D, H, 0, -R + D / 2, 0, m, bevel=0.01)
            for z in (0.0, H - 0.045):                                                     # caps hide chord joints
                b.box(0.1, D + 0.02, 0.05, 0, -R + D / 2, z, m, bevel=0.012)
    for i in range(bays):
        a = -span / 2 + step * (i + 0.5)
        chord = 2 * (R - D / 2) * math.sin(math.radians(step / 2)) - 0.04
        with b.at((0, R, 0), rotz=a):
            b.box(chord + 0.06, 0.02, H, 0, -R + D - 0.01, 0, "wood_deep", bevel=0)          # back panel
            for k, z in enumerate((0.0, 0.08, 0.5, 0.92, 1.34, H - 0.04)):
                if k == 1:
                    b.box(chord, D - 0.02, 0.08, 0, -R + D / 2, 0, tint("trim", "wood_dark"), bevel=0.008)
                    continue
                b.box(chord + 0.02, D - 0.02, 0.04, 0, -R + D / 2, z, m, bevel=0.008)
            for k, z in enumerate((0.12, 0.54, 0.96, 1.38)):
                if z < H - 0.1:
                    b.socket(f"surface_{i}_{k}", (math.sin(-math.radians(a)) * (R - D / 2),
                                                  R - math.cos(math.radians(a)) * (R - D / 2), z))
                    surfaces[f"surface_{i}_{k}"] = [round(chord, 2), D - 0.04]
    return done(b, "floor", "furniture", rotations=(0, 90, 180, 270),
                meta={"surfaces": surfaces, "fits_wall_radius_m": R, "arc_deg": span,
                      "note": "back is curved, convex toward -Y; snap its back to a round wall of this radius"})


def anchor_wall_decor():
    b = Builder("anchor_wall_decor", seed=54)
    m = tint("metal", "navy")
    b.box(0.05, 0.04, 0.6, 0, -0.04, -0.3, m, bevel=0.012)                                   # shank
    b.torus(0.06, 0.016, 0, -0.04, 0.36, m, segs=12, ring=5, rot=(90, 0, 0))                 # ring
    b.box(0.34, 0.045, 0.045, 0, -0.04, 0.2, m, bevel=0.012)                                  # stock
    for sx in (-1, 1):
        b.sphere(0.03, sx * 0.17, -0.04, 0.222, m, u=6, v=4)
    for k in range(13):                                                                    # curved arms
        a = math.radians(200 + 140 * k / 12)
        x, z = 0.24 * math.cos(a), -0.14 + 0.24 * math.sin(a)
        b.box(0.075, 0.04, 0.05, x, -0.04, z, m, bevel=0.008, rot=(0, -math.degrees(a) - 90, 0), center=True)
    for sx in (-1, 1):                                                                     # flukes
        with b.at((sx * 0.22, -0.04, -0.2)):
            b.prism([(0, -0.02), (sx * 0.1, 0.08), (sx * 0.02, 0.12)], 0.035, mat=m)
    b.box(0.05, 0.04, 0.06, 0, -0.04, -0.4, m, bevel=0.012)                                  # crown
    rope_between(b, (0, -0.07, 0.36), (0.14, -0.07, -0.05), sag=0.08, r=0.012, segs=6)
    return done(b, "wall", "decor", rotations=(0,))


def porthole_mirror():
    b = Builder("porthole_mirror", seed=55)
    with b.at((0, 0, 0), rot=(90, 0, 0)):
        b.cyl(0.27, 0.03, 0, 0, 0, tint("frame", "gold"), segs=16, bevel=0.008)              # back plate
        b.torus(0.22, 0.04, 0, 0, 0.05, tint("frame", "gold"), segs=18, ring=6)
        b.cyl(0.2, 0.012, 0, 0, 0.045, "mirror", segs=16)
        for k in range(8):
            a = math.radians(22.5 + 45 * k)
            b.sphere(0.016, 0.255 * math.cos(a), 0.255 * math.sin(a), 0.032, "iron_light", u=6, v=4)
    return done(b, "wall", "decor", rotations=(0,))


# ---------------------------------------------------------------- starlight room
def canopy_bed():
    b = Builder("canopy_bed", seed=61)
    frame, drape = tint("frame", "wood_dark"), tint("drape", "purple")
    W, L, Hp = 1.3, 2.0, 1.85
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.08, 0.08, Hp, sx * (W / 2 - 0.04), sy * (L / 2 - 0.04), 0, frame, bevel=0.015)
            b.sphere(0.045, sx * (W / 2 - 0.04), sy * (L / 2 - 0.04), Hp + 0.02, "gold", u=8, v=5)
    for sy in (-1, 1):
        b.box(W, 0.06, 0.08, 0, sy * (L / 2 - 0.04), Hp - 0.1, frame, bevel=0.012)
    for sx in (-1, 1):
        b.box(0.06, L, 0.08, sx * (W / 2 - 0.04), 0, Hp - 0.1, frame, bevel=0.012)
    b.box(W - 0.08, L - 0.08, 0.16, 0, 0, 0.12, frame, bevel=0.02)                          # base rails
    b.box(W - 0.06, 0.08, 0.7, 0, L / 2 - 0.05, 0.25, tint("headboard", "lavender"), bevel=0.04)
    b.box(W - 0.14, L - 0.16, 0.18, 0, 0, 0.28, "cream", bevel=0.05)                         # mattress
    b.box(W - 0.08, L * 0.62, 0.12, 0, -L * 0.17, 0.4, tint("bedding", "purple"), bevel=0.05)
    b.box(W - 0.06, 0.18, 0.13, 0, L * 0.12, 0.4, tint("bedding_b", "lavender"), bevel=0.05)  # fold
    for x in (-0.28, 0.28):
        with b.at((x, L / 2 - 0.3, 0.54), rot=(-20, 0, 0)):
            b.box(0.42, 0.14, 0.22, 0, 0, 0, tint("pillow", "lavender"), bevel=0.06, center=True)
    for i in range(3):                                                                      # star motif on blanket
        with b.at((-0.3 + i * 0.3, -L * 0.25 + (i % 2) * 0.25, 0.525)):
            b.prism(star_pts(0.06), 0.006, mat="petal_yellow", plane="xy")
    b.box(W + 0.04, L + 0.04, 0.03, 0, 0, Hp - 0.02, drape, bevel=0.01)                     # canopy top
    for sy in (-1, 1):                                                                      # scalloped valance
        for k in range(6):
            b.box(W / 6, 0.03, 0.14, -W / 2 + W / 12 + k * W / 6, sy * (L / 2 + 0.02), Hp - 0.15, drape, bevel=0.012)
    for sx in (-1, 1):                                                                      # gathered side curtains
        for sy in (-1, 1):
            with b.part(f"drape_{'l' if sx < 0 else 'r'}{'f' if sy < 0 else 'b'}",
                        pivot=(sx * (W / 2 + 0.03), sy * (L / 2 - 0.12), Hp - 0.12), motion="sway", amp_deg=1.5):
                for f in range(3):
                    b.box(0.07, 0.07, Hp - 0.5, sx * (W / 2 + 0.03 - f * 0.05), sy * (L / 2 - 0.12 - f * 0.05),
                          0.38, pick((drape, tint("drape_b", "lavender")), f), bevel=0.03)
                b.box(0.2, 0.2, 0.04, sx * (W / 2 - 0.02), sy * (L / 2 - 0.16), 1.0, "gold", bevel=0.012)
    b.socket("sleep", (0, 0.1, 0.55))
    b.socket("seat_0", (0, -L / 2 + 0.2, 0.46))
    return done(b, "floor", "furniture", clearance=1)


def telescope_on_tripod():
    b = Builder("telescope_on_tripod", seed=62)
    top = Vector((0, 0, 1.0))
    for k in range(3):
        a = math.radians(90 + 120 * k)
        foot = Vector((math.cos(a) * 0.36, math.sin(a) * 0.36, 0))
        d = top - foot
        q = d.to_track_quat("Z", "Y").to_euler()
        b.cyl(0.022, d.length, foot.x, foot.y, 0, tint("tripod", "wood_dark"), segs=6, rot=tuple(math.degrees(v) for v in q))
        b.cyl(0.03, 0.03, foot.x, foot.y, 0, "black", segs=6)
    b.cyl(0.07, 0.08, 0, 0, 0.98, "iron", segs=8)
    with b.part("tube", pivot=(0, 0, 1.1), motion="tilt", axis="x", max_deg=25), b.at((0, 0, 1.1), rot=(55, 0, 0)):
        tube = tint("tube", "navy")
        b.cyl(0.075, 0.75, 0, 0, -0.25, tube, segs=10, r2=0.065)
        b.cyl(0.085, 0.08, 0, 0, 0.45, "gold", segs=10)                                     # dew cap
        b.cyl(0.08, 0.03, 0, 0, -0.27, "gold", segs=10)
        b.cyl(0.02, 0.1, 0, 0, -0.37, "black", segs=6)                                      # eyepiece
        b.cyl(0.022, 0.2, 0.0, 0.1, -0.05, "iron", segs=6)                                   # finder scope
    b.socket("use", (0, -0.55, 0), rotz=180)
    return done(b, "floor", "furniture", clearance=1)


def star_string_lights():
    b = Builder("star_string_lights", seed=63)
    for sx in (-1, 1):
        b.cyl(0.015, 0.05, sx * 0.75, 0, 0, "gold", segs=6, rot=(90, 0, 0))                 # wall hooks
    pts = rope_between(b, (-0.75, -0.05, 0), (0.75, -0.05, 0), sag=0.2, r=0.006, segs=10, mat="charcoal")
    for i, p in enumerate(pts[1:-1]):
        s = 0.075 if i % 2 else 0.06
        b.cyl(0.004, 0.05, p.x, p.y, p.z - 0.05, "charcoal", segs=4)
        with b.at((p.x, p.y, p.z - 0.05 - s)):
            b.prism(star_pts(s), 0.03, mat=tint(f"bulb_{i}", "star_glow"), bevel=0.004)  # own material: phased glow
    return done(b, "wall", "light", rotations=(0,), meta={"light": "warm"})


def crystal_ball_lamp():
    b = Builder("crystal_ball_lamp", seed=64)
    base = tint("base", "gold")
    b.cyl(0.09, 0.03, 0, 0, 0, "wood_dark", segs=8, bevel=0.006)
    b.cyl(0.06, 0.05, 0, 0, 0.03, base, segs=8, r2=0.075)
    for k in range(3):                                                                     # claw prongs
        a = math.radians(30 + 120 * k)
        b.box(0.02, 0.02, 0.07, math.cos(a) * 0.065, math.sin(a) * 0.065, 0.06, base, bevel=0.004, rot=(0, 0, 0))
    b.sphere(0.1, 0, 0, 0.17, tint("orb", "glow_violet"), u=12, v=8)
    return done(b, "surface", "light", meta={"light": "violet"})


def floor_cushion():
    b = Builder("floor_cushion", seed=65)
    m = tint("fabric", "lavender")
    b.cyl(0.32, 0.14, 0, 0, 0, m, segs=14, bevel=0.05)
    b.cyl(0.33, 0.02, 0, 0, 0.06, tint("piping", "purple"), segs=14, cap=False)
    b.sphere(0.025, 0, 0, 0.14, "gold", u=6, v=4)
    for k in range(6):
        a = math.radians(60 * k)
        b.box(0.18, 0.008, 0.004, 0.1 * math.cos(a), 0.1 * math.sin(a), 0.137, tint("piping", "purple"),
              bevel=0, rot=(0, 0, 60 * k))
    b.socket("seat_0", (0, 0, 0.15))
    return done(b, "floor", "seating")


def moon_lamp():
    b = Builder("moon_lamp", seed=66)
    b.cyl(0.08, 0.025, 0, 0, 0, "wood_dark", segs=8, bevel=0.006)
    b.cyl(0.01, 0.12, 0.0, 0, 0.025, "gold", segs=6)
    with b.at((0, 0, 0.3)):
        b.prism(crescent_pts(0.17), 0.06, mat=tint("moon", "moon_glow"), bevel=0.008)
    return done(b, "surface", "light", meta={"light": "warm"})


def build():
    for fn in (wood_stove, side_table, log_basket,
               window_seat_bench, large_monstera, hanging_planter_cluster, plant_stand_tiered, woven_round_rug,
               tv_console, tv, game_console, beanbag, pouf_round, pouf_square, neon_wall_sign, gaming_chair,
               easel_with_canvas, drafting_table, canvas_stack, paint_supplies, tall_dresser, storage_crate, striped_rug,
               ship_wheel_wall, model_sailboat, curved_bookshelf, anchor_wall_decor, porthole_mirror,
               canopy_bed, telescope_on_tripod, star_string_lights, crystal_ball_lamp, floor_cushion, moon_lamp):
        fn()
