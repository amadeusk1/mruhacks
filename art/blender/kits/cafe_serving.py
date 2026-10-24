"""Cafe serving and food props (sheet "Cafe Serving and Food Prop Kit"), built into the cafe kit.

Every item is its own surface-layer asset (origin at the bottom centre) with an optional
socket_grip. Ceramics share three tint roles: ceramic (body), ceramic_rim (bands, lids, handles)
and ceramic_accent (the leaf motif). Lids are lift parts. tray_breakfast_preset is a preset
that references the separate assets, plus a fused preview mesh tagged preview_only.
"""
import json
from common import *

KIT = "cafe"
CER = tint("ceramic", "cream")
RIM = tint("ceramic_rim", "teal")
ACC = tint("ceramic_accent", "coral")
SURF = placement("surface")


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------
def _ring(verts, r, z, segs):
    i0 = len(verts)
    for k in range(segs):
        a = 2 * math.pi * k / segs
        verts.append((r * math.cos(a), r * math.sin(a), z))
    return i0


def lathe(b, prof, mats, segs=12, wall=None, lip=None, floor=True, imats=None, x=0, y=0, z=0, rot=(0, 0, 0)):
    """Revolve a bottom-to-top profile [(r, z), ...] around Z.
    mats: one material per band (len(prof)-1) or a single name. wall=None gives a solid with a
    top cap; wall=t gives an open vessel whose inner wall is offset by t, with a floor raised by t
    (floor=False leaves a hollow tube, e.g. a dome). lip: material for the top lip; imats: per inner band
    (defaults to lip)."""
    if isinstance(mats, str):
        mats = [mats] * (len(prof) - 1)
    lip = lip or mats[-1]

    def strip(r0, z0, r1, z1, m, inward=False):
        v = []
        a, c = _ring(v, r0, z0, segs), _ring(v, r1, z1, segs)
        f = [((a + k, a + (k + 1) % segs, c + (k + 1) % segs, c + k)[::-1 if inward else 1]) for k in range(segs)]
        b.mesh(v, f, m, x, y, z, rot)

    def fan(r, zz, m, up):
        v = [(0, 0, zz)]
        a = _ring(v, r, zz, segs)
        f = [(0, a + k, a + (k + 1) % segs) if up else (0, a + (k + 1) % segs, a + k) for k in range(segs)]
        b.mesh(v, f, m, x, y, z, rot)

    for i in range(len(prof) - 1):
        strip(*prof[i], *prof[i + 1], mats[i])
    rb, zb = prof[0]
    rt, zt = prof[-1]
    if wall is None:
        fan(rb, zb, mats[0], up=False)
        fan(rt, zt, mats[-1], up=True)
        return
    inner = [(max(r - wall, 0.002), max(zz, zb + wall)) for r, zz in prof]
    imats = imats or [lip] * (len(inner) - 1)
    if floor:
        fan(rb, zb, mats[0], up=False)
        fan(inner[0][0], inner[0][1], imats[0], up=True)
    else:
        strip(inner[0][0], inner[0][1], rb, zb, mats[0])          # bottom annulus (faces down)
    strip(rt, zt, inner[-1][0], inner[-1][1], lip, inward=True)    # top lip (faces up)
    for i in range(len(inner) - 1):
        strip(*inner[i], *inner[i + 1], imats[i], inward=True)


def inner_r(prof, wall, zz):
    """Inner radius of a lathe vessel at height zz (for liquid discs)."""
    for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
        if z0 <= zz <= z1:
            return r0 + (r1 - r0) * (zz - z0) / max(z1 - z0, 1e-6) - wall
    return prof[-1][0] - wall


def leaf(cx, cz, L, Wd, ang):
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    pts = [(0, -L / 2), (Wd / 2, 0), (0, L / 2), (-Wd / 2, 0)]
    return [(cx + px * c - pz * s, cz + px * s + pz * c) for px, pz in pts]


def motif(b, x, y, z, s=1.0, up=False, tilt=0.0, rotz=0.0):
    """Three-leaf accent: a coral centre leaf and two rim-coloured side leaves.
    up=False: a decal on a vertical face whose outer side is -Y at (x, y). up=True: flat on a surface at z."""
    leaves = [(leaf(0, 0.004 * s, 0.024 * s, 0.011 * s, 0), ACC),
              (leaf(-0.011 * s, -0.004 * s, 0.017 * s, 0.008 * s, 50), RIM),
              (leaf(0.011 * s, -0.004 * s, 0.017 * s, 0.008 * s, -50), RIM)]
    with b.at((x, y, z), rot=(tilt, 0, rotz)):
        for pts, m in leaves:
            if up:
                b.prism(pts, 0.002, mat=m, plane="xy")
            else:
                b.prism(pts, 0.003, y=-0.0005, mat=m)


def body_r(prof, zz):
    for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
        if z0 <= zz <= z1:
            return r0 + (r1 - r0) * (zz - z0) / max(z1 - z0, 1e-6)
    return prof[-1][0]


def handle(b, prof, z0, z1, out, r, mat, embed=0.002, n=8):
    """Handle on the +X side running from the body surface at z0 to the surface at z1, bulging
    `out` metres outward; the ends sink `embed` into the wall (less than the wall thickness)."""
    A = Vector((body_r(prof, z0) - embed, 0, z0))
    B = Vector((body_r(prof, z1) - embed, 0, z1))
    C = (A + B) / 2 + Vector((out * 1.6, 0, 0))
    pts = [A * (1 - t) ** 2 + C * 2 * (1 - t) * t + B * t * t for t in [i / n for i in range(n + 1)]]
    for p, q in zip(pts, pts[1:]):
        d = q - p
        e = d.to_track_quat("Z", "Y").to_euler()
        b.cyl(r, d.length + r * 0.5, p.x, p.y, p.z, mat, segs=6, rot=tuple(math.degrees(v) for v in e))
    return (C + (A + B) / 2) / 2


# ---------------------------------------------------------------------------
# Food
# ---------------------------------------------------------------------------
def croissant(b, s=1.0):
    """Seven ridged lobes along a crescent, the tips curling down and back (+Y)."""
    lobes = ((-78, 0.017, "orange"), (-55, 0.025, "mustard"), (-28, 0.032, "orange"), (0, 0.037, "mustard"),
             (28, 0.032, "orange"), (55, 0.025, "mustard"), (78, 0.017, "orange"))
    for a, r, m in lobes:
        t = math.radians(a)
        # each lobe is a plump ridge across the crescent; the horns curl back toward +Y
        b.sphere(r * s, math.sin(t) * 0.058 * s, (0.04 - math.cos(t) * 0.052) * s, r * 0.8 * s, m, u=8, v=5,
                 scale=(0.85, 1.25, 0.95), rot=(0, 0, a))
    b.socket("grip", (0, -0.005, 0.03 * s))


def muffin(b):
    case = tint("muffin_case", "brown")
    lathe(b, [(0.036, 0.0), (0.047, 0.05)], case, segs=12)
    for k in range(12):  # pleats
        a = 2 * math.pi * (k + 0.5) / 12
        with b.at((math.cos(a) * 0.0442, math.sin(a) * 0.0442, 0.025), rotz=math.degrees(a)):
            b.box(0.006, 0.007, 0.048, mat="wood_b", bevel=0, rot=(0, 12.4, 0), center=True)
    b.blob(0.056, 0.056, 0.036, 0, 0, 0.056, "mustard", subdiv=2, jitter=0.003)
    rng = random.Random(7)
    for i in range(8):
        a, p = rng.uniform(0, math.tau), rng.uniform(0.25, 1.0)
        b.box(0.012, 0.012, 0.009, math.cos(a) * 0.05 * math.sin(p), math.sin(a) * 0.05 * math.sin(p),
              0.056 + 0.034 * math.cos(p) - 0.002, "wood_deep", bevel=0.002, rot=(rng.uniform(0, 40), 0, math.degrees(a)))
    b.socket("grip", (0, 0, 0.04))


def cookie(b):
    b.blob(0.058, 0.055, 0.014, 0, 0, 0.014, "tan", subdiv=2, jitter=0.003)
    rng = random.Random(11)
    for i in range(7):
        a, d = rng.uniform(0, math.tau), rng.uniform(0.0, 0.038)
        b.box(0.013, 0.012, 0.009, math.cos(a) * d, math.sin(a) * d, 0.022, "wood_deep", bevel=0.002,
              rot=(0, 0, rng.uniform(0, 90)))
    b.socket("grip", (0.04, 0, 0.014))


def cake_slice(b):
    """Wedge with its point toward -Y: sponge and cream layers with strawberry pieces showing on
    the cut faces, a cream top and a whole strawberry with leaves."""
    wedge = [(0, -0.075), (0.052, 0.055), (-0.052, 0.055)]
    cream = tint("cake_cream", "cream")
    z = 0.0
    for m, h in (("tan", 0.03), (cream, 0.014), ("tan", 0.026), (cream, 0.012)):
        b.prism(wedge, h, z=z, mat=m, plane="xy")
        if m == cream and z < 0.04:
            for t in (0.3, 0.55, 0.8):  # strawberry halves cut through both side faces
                for sx in (-1, 1):
                    px, py = sx * 0.052 * t, -0.075 + 0.13 * t
                    b.box(0.014, 0.014, h * 0.8, px, py, z + h * 0.1, "red", bevel=0.002, rot=(0, 0, sx * 22))
        z += h
    b.blob(0.016, 0.016, 0.019, 0, 0.022, z + 0.017, "red", subdiv=1, rot=(12, 0, 0))
    for a in (0, 120, 240):
        t = math.radians(a)
        b.blob(0.011, 0.005, 0.003, math.cos(t) * 0.008, 0.022 + math.sin(t) * 0.008, z + 0.035, "leaf", subdiv=1,
               rot=(0, 0, a))
    b.socket("grip", (0, 0.03, 0.02))


# ---------------------------------------------------------------------------
# Ceramics
# ---------------------------------------------------------------------------
def plate(b, r=0.12):
    """Cream 12-sided plate with a raised teal rim band and the leaf motif in the centre."""
    lathe(b, [(r * 0.62, 0.0), (r * 0.66, 0.008), (r * 0.9, 0.012), (r, 0.02), (r, 0.024)],
          [CER, CER, CER, RIM], segs=12, wall=0.006, lip=RIM, imats=[CER, CER, RIM, CER])
    motif(b, 0, 0.004, 0.006, s=1.9, up=True)
    b.socket("surface_0", (0, 0, 0.006))
    b.socket("grip", (r * 0.95, 0, 0.02))
    return 0.006


def saucer(b, r=0.085):
    lathe(b, [(r * 0.55, 0.0), (r * 0.6, 0.006), (r * 0.92, 0.01), (r, 0.017), (r, 0.02)],
          [CER, CER, CER, RIM], segs=12, wall=0.005, lip=RIM, imats=[CER, CER, RIM, CER])
    lathe(b, [(0.04, 0.005), (0.04, 0.0075)], CER, segs=12, wall=0.003, floor=False)       # cup well ring
    b.socket("surface_0", (0, 0, 0.005))
    b.socket("grip", (r * 0.95, 0, 0.018))
    return 0.005


TEACUP = [(0.026, 0.0), (0.028, 0.008), (0.03, 0.009), (0.044, 0.03), (0.05, 0.05), (0.05, 0.056)]


def teacup(b, tea=True):
    lathe(b, TEACUP, [RIM, RIM, CER, CER, RIM], segs=12, wall=0.005, lip=RIM, imats=[CER] * 5)
    if tea:
        zt = 0.046
        b.cyl(inner_r(TEACUP, 0.005, zt) - 0.0015, 0.003, 0, 0, zt, "wood_b", segs=12)
        b.socket("fx_steam", (0, 0, 0.062))
    motif(b, 0, -(body_r(TEACUP, 0.026) + 0.001), 0.026, s=0.85, tilt=-34)
    g = handle(b, TEACUP, 0.02, 0.045, 0.02, 0.005, CER)
    b.socket("grip", tuple(g))


def takeaway_cup(b):
    prof = [(0.033, 0.0), (0.045, 0.12)]
    lathe(b, prof, tint("cup", "cream"), segs=12, wall=0.004)
    b.cyl(inner_r(prof, 0.004, 0.1) - 0.0015, 0.003, 0, 0, 0.1, "wood_b", segs=12)          # coffee
    lathe(b, [(0.0398, 0.035), (0.0438, 0.088)], tint("cup_sleeve", "tan"), segs=12)          # sleeve
    motif(b, 0, -0.0428, 0.06, s=0.9, tilt=-4.3)
    lid = tint("cup_lid", "teal")
    with b.part("lid", pivot=(0, 0, 0.12), motion="slide", dir=(0, 0, 1), dist=0.06):
        lathe(b, [(0.047, 0.1201), (0.048, 0.128), (0.044, 0.134), (0.038, 0.136)], lid, segs=12)
        b.box(0.016, 0.01, 0.004, 0, -0.03, 0.136, "black", bevel=0.001)                    # sip hole
    b.socket("fx_steam", (0, -0.03, 0.15))
    b.socket("grip", (0, -0.044, 0.06))


def sugar_jar(b):
    prof = [(0.036, 0.0), (0.043, 0.02), (0.044, 0.055), (0.04, 0.068), (0.04, 0.074)]
    lathe(b, prof, [CER, CER, CER, RIM], segs=12, wall=0.005, lip=RIM, imats=[CER] * 4)
    rng = random.Random(3)
    for i in range(7):   # sugar cubes heaped inside, tops just below the rim
        a, d = rng.uniform(0, math.tau), rng.uniform(0, 0.018)
        b.box(0.016, 0.016, 0.015, math.cos(a) * d, math.sin(a) * d, 0.036 + (i % 3) * 0.006, "white", bevel=0.002,
              rot=(rng.uniform(-15, 15), rng.uniform(-15, 15), rng.uniform(0, 90)))
    motif(b, 0, -0.0445, 0.036, s=0.85)
    with b.part("lid", pivot=(0, 0, 0.074), motion="slide", dir=(0, 0, 1), dist=0.05):
        lathe(b, [(0.045, 0.0741), (0.046, 0.08), (0.03, 0.096), (0.012, 0.1)], RIM, segs=12)
        b.blob(0.011, 0.011, 0.012, 0, 0, 0.108, ACC, subdiv=1)
    b.socket("grip", (0, -0.045, 0.04))


TEAPOT = [(0.044, 0.008), (0.062, 0.022), (0.076, 0.055), (0.072, 0.09), (0.052, 0.116), (0.036, 0.124)]


def teapot(b):
    b.cyl(0.046, 0.008, 0, 0, 0, RIM, segs=12, r2=0.044)                                        # foot band
    lathe(b, TEAPOT, [RIM, CER, CER, CER, RIM], segs=12, wall=0.007, lip=RIM, imats=[CER] * 5)
    # spout from the -X side, tapering upward; its base stays within the wall, outside the cavity
    sx0, sz0, L, ang = -0.074, 0.042, 0.072, 48
    b.cyl(0.015, L, sx0, 0, sz0, CER, segs=8, r2=0.0095, rot=(0, -ang, 0))
    tip = Vector((sx0 - L * math.sin(math.radians(ang)), 0, sz0 + L * math.cos(math.radians(ang))))
    b.cyl(0.0108, 0.01, tip.x + 0.006, 0, tip.z - 0.005, RIM, segs=8, rot=(0, -ang, 0))
    g = handle(b, TEAPOT, 0.04, 0.1, 0.035, 0.008, CER, embed=0.003)
    motif(b, 0, -(body_r(TEAPOT, 0.062) + 0.001), 0.062, s=1.2, tilt=6.5)
    with b.part("lid", pivot=(0, 0, 0.124), motion="slide", dir=(0, 0, 1), dist=0.05):
        lathe(b, [(0.042, 0.1242), (0.043, 0.13), (0.03, 0.146), (0.012, 0.152)], RIM, segs=12)
        b.cyl(0.006, 0.01, 0, 0, 0.151, RIM, segs=6)
        b.blob(0.012, 0.012, 0.012, 0, 0, 0.168, RIM, subdiv=1)
    b.socket("fx_steam", (tip.x - 0.004, 0, tip.z + 0.012))
    b.socket("grip", tuple(g))


JUG = [(0.036, 0.0), (0.042, 0.028), (0.04, 0.06), (0.032, 0.082), (0.037, 0.097), (0.038, 0.102)]


def milk_jug(b):
    lathe(b, JUG, [CER, CER, CER, CER, RIM], segs=12, wall=0.005, lip=RIM, imats=[CER] * 5)
    b.cyl(inner_r(JUG, 0.005, 0.07) - 0.0015, 0.003, 0, 0, 0.07, "white", segs=12)             # milk
    b.prism([(-0.034, -0.013), (-0.034, 0.013), (-0.053, 0)], 0.005, z=0.098, mat=RIM, plane="xy")   # pouring lip
    g = handle(b, JUG, 0.03, 0.085, 0.024, 0.0065, RIM)
    b.socket("grip", tuple(g))


# ---------------------------------------------------------------------------
# Wood and utensils
# ---------------------------------------------------------------------------
def serving_tray(b, L=0.52, D=0.34):
    wood = tint("tray", "wood")
    t, hs, he = 0.022, 0.05, 0.08
    b.box(L - 2 * t, D - 2 * t, 0.008, 0, 0, 0, "wood_b", bevel=0)                               # floor base
    planks(b, L - 2 * t - 0.002, D - 2 * t - 0.002, z=0.008, plank=0.068, thick=0.008, mats=(wood, wood, wood),
           along="x", gap=0.004)
    for sy in (-1, 1):                                                                         # long sides
        b.box(L - 2 * t, t, hs, 0, sy * (D / 2 - t / 2), 0, wood, bevel=0.005)
    hw, hz0, hz1 = 0.12, 0.034, 0.062                                                          # handle cut-out
    for sx in (-1, 1):                                                                         # end walls
        x = sx * (L / 2 - t / 2)
        b.box(t, D, hz0, x, 0, 0, wood, bevel=0.005)
        b.box(t, D, he - hz1, x, 0, hz1, wood, bevel=0.005)
        for sy in (-1, 1):
            b.box(t, D / 2 - hw / 2, hz1 - hz0, x, sy * (hw / 2 + (D / 2 - hw / 2) / 2), hz0, wood, bevel=0)
        b.socket(f"grip_{'l' if sx < 0 else 'r'}", (x, 0, (hz0 + hz1) / 2))
    b.socket("surface_0", (0, 0, 0.016))
    return 0.016


def napkin_holder(b):
    wood = tint("napkin_holder", "wood")
    b.box(0.13, 0.07, 0.012, 0, 0, 0, wood, bevel=0.003)
    for sy, h in ((-1, 0.07), (1, 0.06)):
        b.box(0.13, 0.012, h, 0, sy * 0.029, 0.012, wood, bevel=0.004)
        b.box(0.014, 0.012, h + 0.01, 0.058, sy * 0.029, 0.012, wood, bevel=0.003)
        b.box(0.014, 0.012, h + 0.01, -0.058, sy * 0.029, 0.012, wood, bevel=0.003)
    motif(b, 0, -0.035, 0.045, s=1.0)
    nap = tint("napkin", "cream")
    for i in range(5):
        b.box(0.104, 0.006, 0.086 - (i % 2) * 0.004, 0, -0.018 + i * 0.009, 0.012, pick((nap, "white"), i), bevel=0.001)
    b.socket("grip", (0, 0, 0.05))


def spoon(b):
    b.blob(0.022, 0.016, 0.006, -0.058, 0, 0.006, "steel", subdiv=1)
    b.box(0.05, 0.007, 0.004, -0.02, 0, 0.004, "steel", bevel=0.001, rot=(0, -4, 0))
    b.box(0.012, 0.013, 0.009, 0.01, 0, 0.003, RIM, bevel=0.002)
    b.box(0.058, 0.014, 0.009, 0.045, 0, 0.003, "wood", bevel=0.003)
    b.socket("grip", (0.045, 0, 0.008))


def pastry_tongs(b):
    for sy in (-1, 1):
        with b.at((0, 0, 0), rotz=sy * 4):
            b.box(0.1, 0.006, 0.006, -0.045, sy * 0.012, 0.002, "steel", bevel=0.001)
            for i in range(3):                                                                  # scalloped jaw
                b.blob(0.011, 0.009, 0.004, -0.098 - i * 0.012, sy * 0.014, 0.005, "steel", subdiv=1)
            b.box(0.09, 0.014, 0.01, 0.045, sy * 0.012, 0.0, "wood", bevel=0.003)
    b.box(0.016, 0.044, 0.012, 0.096, 0, 0.0, "wood_b", bevel=0.003)                            # hinge block
    b.socket("grip", (0.05, 0, 0.008))


DOME = [(0.118, 0.0), (0.118, 0.012), (0.112, 0.09), (0.085, 0.135), (0.04, 0.155), (0.006, 0.16)]


def cake_dome(b):
    lathe(b, DOME, "glass", segs=14, wall=0.005, floor=False)
    b.cyl(0.012, 0.008, 0, 0, 0.158, "wood_b", segs=8)
    b.blob(0.016, 0.016, 0.014, 0, 0, 0.176, "wood_c", subdiv=1)
    b.socket("grip", (0, 0, 0.18))


def cake_base(b):
    lathe(b, [(0.13, 0.0), (0.14, 0.006), (0.14, 0.024)], tint("cake_base", "wood"), segs=14, wall=0.016)
    b.socket("surface_0", (0, 0, 0.016))
    b.socket("dome_seat", (0, 0, 0.016))
    b.socket("grip", (0.14, 0, 0.012))


ITEMS = {
    "croissant": croissant, "muffin": muffin, "cookie": cookie, "cake_slice": cake_slice,
    "plate": plate, "saucer": saucer, "teacup": teacup, "takeaway_cup": takeaway_cup,
    "sugar_jar": sugar_jar, "teapot": teapot, "milk_jug": milk_jug, "serving_tray": serving_tray,
    "napkin_holder": napkin_holder, "spoon": spoon, "pastry_tongs": pastry_tongs,
    "cake_dome": cake_dome, "cake_base": cake_base,
}

# tray_breakfast_preset: (asset, offset on the tray, rotation about Z in degrees)
TRAY_TOP = 0.016
BREAKFAST = [
    ("serving_tray", (0, 0, 0), 0),
    ("plate", (-0.06, -0.045, TRAY_TOP), 0),
    ("croissant", (-0.06, -0.045, TRAY_TOP + 0.006), 15),
    ("teacup", (0.15, 0.07, TRAY_TOP), 20),
    ("napkin_holder", (-0.168, 0.105, TRAY_TOP), 0),
    ("spoon", (0.15, -0.09, TRAY_TOP), 35),
]


def _strip_sockets(b, keep_prefix=None):
    """The fused preview keeps only the tray's grips, so engines don't double-spawn effects."""
    b.sockets = [s for s in b.sockets if keep_prefix and s[0].startswith(keep_prefix)]


def build():
    for name, fn in ITEMS.items():
        b = Builder(name, seed=500 + len(name))
        fn(b)
        meta = dict(SURF)
        if name in ("teacup", "takeaway_cup", "spoon", "croissant", "cookie", "muffin"):
            meta["slot"] = "held"
        b.finish(KIT, "prop", meta)

    b = Builder("plate_with_pastry", seed=598)
    top = plate(b)
    with b.at((0, -0.01, top), rotz=15):
        croissant(b)
    _strip_sockets(b)
    b.finish(KIT, "prop", {**SURF, "note": "convenience combo; the plate and croissant also exist separately"})

    preset = [{"asset_id": f"{KIT}/{n}", "offset": [round(v, 4) for v in off], "rot": [0, 0, r]} for n, off, r in BREAKFAST]
    os.makedirs(os.path.join(MODELS, KIT), exist_ok=True)
    with open(os.path.join(MODELS, KIT, "tray_breakfast_preset.preset.json"), "w") as f:
        json.dump({"id": f"{KIT}/tray_breakfast_preset", "placement": SURF["placement"], "parts": preset}, f, indent=2)

    p = Builder("tray_breakfast_preset_preview", seed=599)
    for n, off, r in BREAKFAST:
        with p.at(off, rotz=r):
            ITEMS[n](p)
    _strip_sockets(p, "grip_")
    p.finish(KIT, "preset", {"preview_only": True, "preset": preset, **SURF,
                             "note": "fused preview; spawn the parts listed in tray_breakfast_preset.preset.json"})
