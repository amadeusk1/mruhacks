"""Plaza prop kit (concept 05 Plaza Prop Kit, 08 Waterfront Plaza, World Map).
Plaza ground is z=0. Water surface sits at WATER_Z below the plaza edge."""
from common import *

KIT = "plaza"
WATER_Z = -0.5
PREVIEW_WIDTH = 11.0


# ---- helpers shared with the other kits in this builder ---------------------
def clip_x(poly, a, b):
    """Clip a convex 2D polygon to the vertical strip a <= x <= b."""
    def half(pts, keep, k):
        out = []
        for i, cur in enumerate(pts):
            prev = pts[i - 1]
            cin, pin = keep(cur), keep(prev)
            if cin != pin:
                t = (k - prev[0]) / (cur[0] - prev[0])
                out.append((k, prev[1] + t * (cur[1] - prev[1])))
            if cin:
                out.append(cur)
        return out
    p = half(poly, lambda q: q[0] >= a, a)
    return half(p, lambda q: q[0] <= b, b) if p else []


def circle(r, segs, phase=0.0):
    return [(r * math.cos(2 * math.pi * i / segs + phase), r * math.sin(2 * math.pi * i / segs + phase)) for i in range(segs)]


def planked_disc(b, r, z, thick=0.07, n=3, segs=10, gap=0.014, mats=WOOD, x=0, y=0, rotz=0):
    """Round tabletop/stool seat made of n planks clipped to a faceted circle."""
    poly = circle(r, segs, math.pi / segs)
    w = 2 * r / n
    with b.at((x, y, 0), rotz=rotz):
        for i in range(n):
            a, c = -r + w * i + gap / 2, -r + w * (i + 1) - gap / 2
            pts = clip_x(poly, a, c)
            if len(pts) >= 3:
                b.prism(pts, thick, z=z, mat=pick(mats, i * 2 + 1), plane="xy", bevel=0.01)


LEAVES = ("leaf", "leaf_b", "leaf_dark")
PETAL = tint("petal", "petal_white")
FLAGS = (tint("flag_a", "coral"), tint("flag_b", "teal_light"), tint("flag_c", "cream"), tint("flag_d", "mustard"))
FLAG_VARIANTS = {"flag_a": ["coral", "red"], "flag_b": ["teal_light", "sky"], "flag_c": ["cream", "white"], "flag_d": ["mustard", "yellow"]}
PETAL_VARIANTS = ["petal_white", "petal_red", "petal_yellow", "pink", "lavender"]


def leafy(b, x, y, z, r=0.14, n=6, mats=LEAVES, seed=0, tilt=28):
    """Leaf rosette: a dark core plus n faceted leaves fanning out and up (concept-style foliage)."""
    rng = random.Random(seed)
    b.blob(r * 0.55, r * 0.55, r * 0.45, x, y, z + r * 0.2, "leaf_dark")
    for i in range(n):
        a = 360 * i / n + rng.uniform(-15, 15)
        ar = math.radians(a)
        L = r * rng.uniform(0.85, 1.1)
        with b.at((x + math.cos(ar) * L * 0.5, y + math.sin(ar) * L * 0.5, z + r * 0.25), rot=(0, -tilt - rng.uniform(0, 15), a)):
            b.blob(L * 0.6, L * 0.33, L * 0.1, 0, 0, 0, pick(mats, i + seed))


def flutter_bunting(b, p0, p1, n=4, colors=None, size=0.2, sag=0.12, rope_r=0.012, amp=14):
    """Static rope with each pennant as its own flutter part hinged on its top edge (the rope)."""
    pts = rope_between(b, p0, p1, sag=sag, r=rope_r, segs=n * 2)
    d = (Vector(p1) - Vector(p0)).normalized()
    rz = math.degrees(math.atan2(d.y, d.x))
    for i in range(n):
        p = pts[1 + i * 2]
        with b.part(f"flag_{i}", pivot=tuple(p), motion="flutter", amp_deg=amp, axis="x"):
            with b.at(tuple(p), rotz=rz):
                b.prism([(-size / 2, -rope_r), (size / 2, -rope_r), (0, -size * 1.15)], 0.015, mat=pick(colors, i))


def face_center_rot(x, y):
    """rotz (deg) so a socket at (x,y) faces the origin (asset front is -Y)."""
    return math.degrees(math.atan2(y, x)) - 90


def table_with_pedestal(b, r=0.46, h=0.6, n=3):
    planked_disc(b, r, h - 0.08, 0.08, n=n, segs=10)
    b.box(0.5 * r * 2 * 0.55, 0.12, 0.05, 0, 0, h - 0.13, "wood_dark", bevel=0.01)       # cleat under top
    b.box(0.15, 0.15, h - 0.2, 0, 0, 0.08, "wood_b", bevel=0.02)                          # pedestal
    b.box(0.22, 0.22, 0.08, 0, 0, h - 0.2, "wood", bevel=0.02)                            # collar
    b.box(0.22, 0.22, 0.1, 0, 0, 0.06, "wood", bevel=0.02)
    for rz in (45, 135):
        b.box(0.62, 0.11, 0.09, 0, 0, 0, "wood_c", bevel=0.02, rot=(0, 0, rz))           # cross feet
        for s in (-1, 1):
            a = math.radians(rz)
            b.box(0.12, 0.12, 0.04, s * 0.29 * math.cos(a), s * 0.29 * math.sin(a), 0.085, "wood_b", bevel=0.012, rot=(0, 0, rz))


def stool_geo(b, r=0.2, h=0.44, x=0, y=0, rotz=0):
    with b.at((x, y, 0), rotz=rotz):
        planked_disc(b, r, h - 0.07, 0.07, n=2, segs=10)
        sp = 0.1
        for i, (sx, sy) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
            b.box(0.065, 0.065, h - 0.06, sx * (sp + 0.02), sy * (sp + 0.02), 0, pick(("wood_b", "wood"), i),
                  bevel=0.012, rot=(sy * 5, -sx * 5, 0))
        b.box(0.24, 0.035, 0.035, 0, 0.11, 0.14, "wood_dark", bevel=0.006)
        b.box(0.24, 0.035, 0.035, 0, -0.11, 0.14, "wood_dark", bevel=0.006)


def lantern_post_geo(b, h=1.75, x=0, y=0):
    with b.at((x, y, 0)):
        b.box(0.34, 0.34, 0.12, 0, 0, 0, "iron", bevel=0.025)
        b.box(0.26, 0.26, 0.14, 0, 0, 0.12, "iron_light", bevel=0.02)
        b.cyl(0.1, 0.12, 0, 0, 0.26, "iron", segs=6, r2=0.065, bevel=0.01)
        b.cyl(0.055, h - 0.72, 0, 0, 0.38, "iron", segs=6, bevel=0.008)
        b.cyl(0.08, 0.06, 0, 0, 0.55, "iron_light", segs=6, bevel=0.008)
        b.cyl(0.075, 0.08, 0, 0, h - 0.4, "iron_light", segs=6, r2=0.11, bevel=0.008)
        lantern_head(b, 0, 0, h - 0.32, s=1.15)


def bulb(b, x, y, z, m="bulb"):
    b.cyl(0.018, 0.04, x, y, z - 0.02, "iron", segs=5)
    b.sphere(0.065, x, y, z - 0.08, m, u=7, v=5, scale=(1, 1, 1.2))


# ---- assets -----------------------------------------------------------------
def round_table():
    b = Builder("round_table", seed=11)
    table_with_pedestal(b)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        x, y = 0.75 * math.cos(a), 0.75 * math.sin(a)
        b.socket(f"seat_{i}", (x, y, 0.44), face_center_rot(x, y))
    b.socket("table_top", (0, 0, 0.6))
    return b.finish(KIT, "furniture", {"seats": 4, "top_height": 0.6})


def stool():
    b = Builder("stool", seed=12)
    stool_geo(b)
    b.socket("seat", (0, 0, 0.44))
    return b.finish(KIT, "furniture", {"seats": 1, "seat_height": 0.44})


def bench():
    b = Builder("bench", seed=13)
    W, sh = 1.5, 0.42
    for i, y in enumerate((-0.1, 0.08)):                                   # two thick seat planks
        b.box(W, 0.17, 0.08, 0, y, sh - 0.08, pick(WOOD, i + 1), bevel=0.018)
    for sx in (-1, 1):
        x = sx * (W / 2 - 0.18)
        b.box(0.1, 0.1, sh - 0.08, x, -0.12, 0, "wood_dark", bevel=0.015)  # front legs
        b.box(0.1, 0.1, 0.86, x, 0.14, 0, "wood_dark", bevel=0.015)        # back legs run up into the backrest
        b.box(0.1, 0.42, 0.08, x, 0.0, sh - 0.16, "wood_b", bevel=0.015)   # seat support
        b.box(0.08, 0.3, 0.06, x, 0.0, 0.08, "wood_deep", bevel=0.01)       # stretcher
    b.box(W - 0.05, 0.08, 0.15, 0, 0.17, 0.6, "wood", bevel=0.018, rot=(-6, 0, 0))   # backrest plank
    b.box(W - 0.2, 0.06, 0.1, 0, 0.18, sh + 0.02, "wood_c", bevel=0.015)
    for i, x in enumerate((-0.33, 0.33)):
        b.socket(f"seat_{i}", (x, -0.02, sh), 0)
    return b.finish(KIT, "furniture", {"seats": 2, "seat_height": sh})


def aframe_chalkboard():
    b = Builder("aframe_chalkboard", seed=14)
    H, W, ang = 0.92, 0.62, 13
    for side in (-1, 1):
        with b.at((0, side * 0.1, 0), rot=(side * -ang, 0, 0)):
            for sx in (-1, 1):
                b.box(0.07, 0.07, H, sx * (W / 2 - 0.035), 0, 0, "wood", bevel=0.015)
            b.box(W, 0.07, 0.07, 0, 0, H - 0.07, "wood_b", bevel=0.015)
            b.box(W, 0.06, 0.06, 0, 0, 0.12, "wood_b", bevel=0.012)
            b.box(W - 0.14, 0.03, H - 0.28, 0, side * -0.01, 0.2, "insert_chalk", bevel=0.005)
    return b.finish(KIT, "sign", {"insert": "insert_chalk"})


def lantern_post():
    b = Builder("lantern_post", seed=15)
    lantern_post_geo(b)
    b.socket("light", (0, 0, 1.55))
    return b.finish(KIT, "light", {"light_color": "#FFC76B", "light_height": 1.55})


def wall_lantern_asset():
    b = Builder("wall_lantern", seed=16)
    with b.at((0, 0, 0.42)):  # origin = bottom of the back plate on the wall face
        wall_lantern_geo(b)
    b.socket("light", (0, -0.32, 0.17))
    return b.finish(KIT, "light", {"mount": "wall", "mount_height": 1.25, "light_color": "#FFC76B"})


def wall_lantern_geo(b):
    b.box(0.16, 0.05, 0.3, 0, -0.025, -0.12, "iron", bevel=0.012)        # back plate, origin = wall mount point
    b.box(0.1, 0.04, 0.2, 0, -0.06, -0.07, "iron_light", bevel=0.008)
    b.box(0.045, 0.3, 0.045, 0, -0.19, 0.08, "iron", bevel=0.006)
    b.box(0.03, 0.03, 0.18, 0, -0.2, -0.06, "iron", bevel=0, rot=(-40, 0, 0))
    b.cyl(0.02, 0.08, 0, -0.32, 0.0, "iron", segs=5)
    lantern_head(b, 0, -0.32, -0.36, s=0.95)


def flower_pot():
    b = Builder("flower_pot", seed=17)
    pot = tint("pot", "terracotta")
    b.cyl(0.15, 0.26, 0, 0, 0, pot, segs=8, r2=0.2, bevel=0.012)
    b.cyl(0.225, 0.07, 0, 0, 0.24, pot, segs=8, bevel=0.015)
    b.cyl(0.18, 0.02, 0, 0, 0.29, "soil", segs=8)
    leafy(b, 0, 0, 0.3, r=0.2, n=8, seed=4, tilt=20)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        leafy(b, 0.1 * math.cos(a), 0.1 * math.sin(a), 0.36, r=0.13, n=5, seed=i + 9, tilt=35)
    for i, (x, y, z) in enumerate(((0.0, -0.04, 0.55), (0.12, 0.06, 0.5), (-0.12, 0.05, 0.5), (0.06, -0.15, 0.45), (-0.1, -0.12, 0.46))):
        flower(b, x * 0.8, y * 0.8, z - 0.04, PETAL, size=0.095)
    return b.finish(KIT, "decor", {"color_variants": {"petal": PETAL_VARIANTS, "pot": ["terracotta", "cream", "teal", "charcoal"]}})


def rect_planter():
    b = Builder("rect_planter", seed=18)
    W, D, H = 1.25, 0.5, 0.36
    for i, z in enumerate((0, H / 2)):                                       # two plank courses
        for sy in (-1, 1):
            b.box(W, 0.06, H / 2 - 0.01, 0, sy * (D / 2 - 0.03), z, pick(WOOD, i + (sy > 0)), bevel=0.014)
        for sx in (-1, 1):
            b.box(0.06, D - 0.04, H / 2 - 0.01, sx * (W / 2 - 0.03), 0, z, pick(WOOD, i + 2), bevel=0.014)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.09, 0.09, H + 0.03, sx * (W / 2 - 0.02), sy * (D / 2 - 0.02), 0, "wood_b", bevel=0.018)
    b.box(W - 0.1, D - 0.1, 0.03, 0, 0, H - 0.06, "soil", bevel=0)
    foliage(b, W - 0.16, D - 0.16, H - 0.04, flowers=None, height=0.22)
    for i in range(7):  # a sparse row of daisies like the concept, not a carpet
        flower(b, -W / 2 + 0.2 + i * (W - 0.4) / 6, (0.07 if i % 2 else -0.06), H + 0.13, PETAL, size=0.1)
    return b.finish(KIT, "decor", {"color_variants": {"petal": PETAL_VARIANTS}})


def bunting_posts():
    b = Builder("bunting_posts", seed=19)
    span = 1.6
    for sx in (-1, 1):
        post(b, sx * span / 2, 0, 0, h=0.85, w=0.15)
        b.box(0.17, 0.17, 0.05, sx * span / 2, 0, 0.66, "iron_light", bevel=0.01)
    flutter_bunting(b, (-span / 2 + 0.08, 0, 0.72), (span / 2 - 0.08, 0, 0.72), n=4,
                    colors=FLAGS, size=0.22, sag=0.14)
    return b.finish(KIT, "decor", {"span": span, "color_variants": FLAG_VARIANTS})


def fence(name, length):
    b = Builder(name, seed=20 + int(length * 10))
    for sx in (-1, 1):
        post(b, sx * (length / 2 - 0.07), 0, 0, h=0.62, w=0.14)
    for i, z in enumerate((0.18, 0.4)):
        b.box(length - 0.1, 0.07, 0.11, 0, 0.0, z, pick(WOOD, i + int(length)), bevel=0.016)
    b.socket("snap_a", (-length / 2, 0, 0))
    b.socket("snap_b", (length / 2, 0, 0))
    return b.finish(KIT, "modular", {"module": "fence", "length": length})


def fence_post():
    b = Builder("low_wood_fence_post", seed=23)
    post(b, 0, 0, 0, h=0.66, w=0.16)
    return b.finish(KIT, "modular", {"module": "fence", "use": "corner_or_end"})


def small_fountain():
    b = Builder("small_fountain", seed=24)
    R, H = 1.05, 0.38
    n = 8
    side = 2 * R * math.tan(math.pi / n)
    for i in range(n):                                                     # octagon of rim blocks, two courses
        a = 2 * math.pi * i / n
        rz = math.degrees(a) + 90
        cx, cy = (R - 0.13) * math.cos(a), (R - 0.13) * math.sin(a)
        b.box(side * 0.98 - 0.02, 0.27, H * 0.55, cx, cy, 0, pick(("stone", "stone_dark"), i), bevel=0.03, rot=(0, 0, rz))
        b.box(side * 0.98, 0.3, H * 0.45, cx * 1.005, cy * 1.005, H * 0.55, pick(("stone", "paving_b", "stone"), i + 1),
              bevel=0.035, rot=(0, 0, rz))
    b.cyl(R - 0.22, 0.06, 0, 0, 0.0, "stone_dark", segs=8)
    WZ = H - 0.06
    with b.part("basin_water", pivot=(0, 0, WZ), motion="flow"):
        b.cyl(R - 0.24, 0.04, 0, 0, H - 0.1, "water", segs=8, cap=True)
    b.socket("fx_ripple", (0, 0, WZ))
    # central pillar
    b.cyl(0.24, 0.16, 0, 0, 0, "stone_dark", segs=8, bevel=0.02)
    b.cyl(0.17, 0.62, 0, 0, 0.16, "stone", segs=8, bevel=0.015)
    b.cyl(0.22, 0.08, 0, 0, 0.78, "paving_b", segs=8, bevel=0.015)
    b.cyl(0.15, 0.2, 0, 0, 0.86, "stone", segs=8, r2=0.02, bevel=0.01)
    # water arcs: four jets from the collar curving into the basin, one flow part for all streams
    landings = []
    with b.part("streams", pivot=(0, 0, 0.72), motion="flow"):
        for k in range(4):
            a = math.radians(45 + 90 * k)
            pts = []
            for i in range(9):
                t = i / 8
                rr = 0.2 + t * 0.48
                pts.append(Vector((rr * math.cos(a), rr * math.sin(a), 0.72 + 0.16 * math.sin(t * math.pi * 0.85) - t * 0.35)))
            for p0, p1 in zip(pts, pts[1:]):
                d = p1 - p0
                rot = d.to_track_quat("Z", "Y").to_euler()
                b.cyl(0.028, d.length + 0.02, p0.x, p0.y, p0.z, "water", segs=6, rot=tuple(math.degrees(v) for v in rot))
            b.cyl(0.09, 0.015, pts[-1].x, pts[-1].y, H - 0.065, "ice", segs=8)     # splash ring
            landings.append(pts[-1])
    for k, p in enumerate(landings):
        b.socket(f"fx_splash_{k}", (p.x, p.y, WZ))
    for i, a in enumerate((-90, -30)):
        x, y = (R - 0.12) * math.cos(math.radians(a)), (R - 0.12) * math.sin(math.radians(a))
        b.socket(f"sit_rim_{i}", (x, y, H), a + 90 + 180)
    return b.finish(KIT, "landmark", {"water_surface_z": H - 0.06})


def street_bin():
    b = Builder("street_bin", seed=25)
    S, H = 0.44, 0.6
    b.box(S, S, 0.06, 0, 0, 0, "iron", bevel=0.012)
    for side in range(4):
        with b.at((0, 0, 0), rotz=90 * side):
            for i in range(4):
                b.box(S / 4 - 0.015, 0.05, H - 0.1, -S / 2 + S / 8 + i * S / 4, -S / 2 + 0.03, 0.06, pick(WOOD, i + side), bevel=0.01)
    for z in (0.14, H - 0.12):
        b.box(S + 0.02, S + 0.02, 0.05, 0, 0, z, "iron", bevel=0.01)
    b.box(S + 0.06, S + 0.06, 0.07, 0, 0, H - 0.04, "iron", bevel=0.02)
    b.box(S - 0.04, S - 0.04, 0.05, 0, 0, H + 0.02, "iron_light", bevel=0.015)
    for sx in (-1, 1):
        b.box(0.035, 0.05, 0.1, sx * 0.08, 0, H + 0.06, "iron", bevel=0.006)
    b.box(0.2, 0.05, 0.035, 0, 0, H + 0.15, "iron", bevel=0.006)
    return b.finish(KIT, "prop")


BULB_COLORS = ("bulb", "glow", "glow_teal")  # amber, gold, teal like the sheet's string bulbs


def string_lights():
    b = Builder("string_lights", seed=26)
    L, z = 4.0, 2.4
    pts = rope_between(b, (-L / 2, 0, z), (L / 2, 0, z), sag=0.35, r=0.01, segs=10, mat="iron")
    for i, p in enumerate(pts[1:-1]):  # one glow material per bulb so the engine can phase each
        bulb(b, p.x, p.y, p.z, tint(f"bulb_{i}", pick(BULB_COLORS, i)))
    b.socket("anchor_a", (-L / 2, 0, z))
    b.socket("anchor_b", (L / 2, 0, z))
    return b.finish(KIT, "light", {"span": L, "anchor_height": z, "note": "hang between lantern posts or building eaves",
                                   "color_variants": {f"bulb_{i}": list(BULB_COLORS) for i in range(9)},
                                   "glow_roles": [f"bulb_{i}" for i in range(9)]})


def string_light_pole():
    """Iron post that carries a string_lights span: the wire eye collar sits at the strings' 2.4 m anchor
    height, with a small lantern on top. Place one at each socket_anchor_a/b of the span."""
    b = Builder("string_light_pole", seed=27)
    z = 2.4
    b.box(0.3, 0.3, 0.1, 0, 0, 0, "iron", bevel=0.022)
    b.box(0.22, 0.22, 0.12, 0, 0, 0.1, "iron_light", bevel=0.018)
    b.cyl(0.085, 0.14, 0, 0, 0.22, "iron", segs=6, r2=0.055, bevel=0.008)
    b.cyl(0.045, z + 0.1 - 0.36, 0, 0, 0.36, "iron", segs=6, bevel=0.006)
    b.cyl(0.068, 0.05, 0, 0, 0.56, "iron_light", segs=6, bevel=0.006)
    b.cyl(0.062, 0.06, 0, 0, z - 0.03, "iron_light", segs=6, bevel=0.006)      # eye collar the wires tie to
    for sx in (-1, 1):
        b.torus(0.03, 0.009, sx * 0.075, 0, z, "iron", segs=8, ring=4, rot=(90, 0, 0))
    b.cyl(0.06, 0.06, 0, 0, z + 0.1, "iron_light", segs=6, r2=0.09, bevel=0.006)
    lantern_head(b, 0, 0, z + 0.16, s=0.85)
    b.socket("anchor", (0, 0, z))
    b.socket("light", (0, 0, z + 0.3))
    return b.finish(KIT, "light", {"anchor_height": z, "light_color": "#FFC76B", "light_height": z + 0.3,
                                   "note": "carries plaza/string_lights: one pole at each anchor, same ground z"})


def paving(name, size, seed):
    b = Builder(name, seed=seed)
    rng = random.Random(seed)
    rows = int(round(size / 0.5))
    rh = size / rows
    b.box(size, size, 0.02, 0, 0, 0, "stone_dark", bevel=0)                 # grout bed
    for r in range(rows):
        y0 = -size / 2 + r * rh
        x = -size / 2
        i = 0
        while x < size / 2 - 1e-3:
            w = min(rng.choice((0.35, 0.45, 0.5, 0.6)), size / 2 - x)
            if size / 2 - x - w < 0.2:
                w = size / 2 - x
            h = 0.05 + rng.uniform(-0.006, 0.006)
            b.box(w - 0.03, rh - 0.03, h, x + w / 2, y0 + rh / 2, 0.02, pick(("paving", "paving_b", "stone", "paving", "stone_dark", "paving_b"), rng.randrange(6)),
                  bevel=0.018, jitter=0.002)
            x += w
            i += 1
    return b.finish(KIT, "modular", {"module": "paving", "grid": size, "top_z": 0.07})


def edge_run(b, L, rng, depth=0.5):
    """Three courses of chunky stone from below the water up to a curb just above the plaza (wall centred on y=0)."""
    stone_row(b, L, 0.32, depth, -L / 2, 0, WATER_Z - 0.3, mats=("stone_grey", "rock_grey", "stone_dark"), unit=0.5, bevel=0.04, rng=rng)
    stone_row(b, L, 0.3, depth - 0.04, -L / 2 + 0.01, 0, WATER_Z, mats=("stone_dark", "stone_grey", "stone"), unit=0.6, bevel=0.04, rng=rng)
    stone_row(b, L, 0.36, depth + 0.06, -L / 2, -0.03, -0.2, mats=("stone", "paving_b", "stone_dark"), unit=0.55, bevel=0.045, rng=rng)


def plaza_edge(name, length, corner=False):
    """Waterfront retaining wall. Plaza top at z=0, wall drops to below the water surface."""
    b = Builder(name, seed=40 + int(length * 3) + corner)
    rng = random.Random(7 + int(length))
    depth = 0.5
    run = lambda L: edge_run(b, L, rng)
    run(length)
    if corner:  # second run turns along +Y; water on the outside (-Y and +X)
        with b.at((length / 2 - depth / 2, length / 2 + 0.14, 0), rotz=90):  # clear of run 1's coping
            run(length - 0.28)
    b.socket("snap_a", (-length / 2, 0, 0))
    b.socket("snap_b", (length / 2, 0, 0) if not corner else (length / 2 - depth / 2, length, 0))
    return b.finish(KIT, "modular", {"module": "plaza_edge", "length": length, "corner": corner,
                                    "water_z": WATER_Z, "water_side": "-Y"})


def cafe_umbrella_table():
    b = Builder("cafe_umbrella_table", seed=50)
    table_with_pedestal(b, r=0.5)
    b.cyl(0.03, 2.05, 0, 0, 0.55, "wood_dark", segs=6)
    n, R, zr = 8, 1.15, 2.1
    peak = Vector((0, 0, zr + 0.42))
    pts = [Vector((R * math.cos(2 * math.pi * i / n), R * math.sin(2 * math.pi * i / n), zr)) for i in range(n)]
    for i in range(n):
        p0, p1 = pts[i], pts[(i + 1) % n]
        m = tint("canopy_a", "coral") if i % 2 == 0 else tint("canopy_b", "cream")
        dn = Vector((0, 0, -0.03))
        b.mesh([tuple(peak), tuple(p0), tuple(p1), tuple(peak + dn), tuple(p0 + dn), tuple(p1 + dn)],
               [(0, 1, 2), (3, 5, 4), (1, 4, 5, 2)], mat=m)  # top, underside and hem so it reads from below too
        mid = (p0 + p1) / 2
        rz = math.degrees(math.atan2(mid.y, mid.x)) + 90
        b.box((p1 - p0).length * 0.96, 0.03, 0.13, mid.x, mid.y, zr - 0.13, m, bevel=0.006, rot=(0, 0, rz))
    b.cyl(0.07, 0.1, 0, 0, zr + 0.38, "wood_dark", segs=6, r2=0.02)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        x, y = 0.8 * math.cos(a), 0.8 * math.sin(a)
        b.socket(f"seat_{i}", (x, y, 0.44), face_center_rot(x, y))
    return b.finish(KIT, "furniture", {"seats": 4, "color_variants": {"canopy_a": ["coral", "teal", "mustard", "navy"], "canopy_b": ["cream", "white"]}})


def build():
    round_table(); stool(); bench(); aframe_chalkboard(); lantern_post(); wall_lantern_asset()
    flower_pot(); rect_planter(); bunting_posts()
    fence("low_wood_fence_1m", 1.0); fence("low_wood_fence_2m", 2.0); fence_post()
    small_fountain(); street_bin(); string_lights(); string_light_pole()
    paving("paving_1x1", 1.0, 61); paving("paving_2x2", 2.0, 62)
    plaza_edge("plaza_edge_1m", 1.0); plaza_edge("plaza_edge_2m", 2.0); plaza_edge("plaza_edge_corner", 1.0, corner=True)
    cafe_umbrella_table()
