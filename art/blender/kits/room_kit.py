"""Housing decoration catalogue (concepts: Home Decor - Modular Prop Kit, 11 Customizable Room Kit).

Every item is a separate grid-placeable asset (vault note: Player Housing - Grid Decoration):
meta 'placement' from common.placement(); shelves, tables and desks ship EMPTY and expose
surface_<n> sockets (top centre of the usable area) with sizes in meta 'surfaces'; small decor
is its own 'surface'-layer item. Recolourable regions are tint() roles.
"""
import math
from common import *
from kits.arcade import cabinet, variants

KIT = "room_kit"
PALETTE.setdefault("indigo", ("#34408F", 0.85, 0))  # Home Decor sofa
PALETTE.setdefault("insert_mirror", ("#CFE6EE", 0.15, 0))  # stylised mirror face; the engine may swap a texture
PREVIEW_WIDTH = 12.0

CUSHION = tint("cushion", "cream")
ACCENT = tint("cushion_accent", "coral")
FINISH = tint("finish", "wood")


def done(b, layer, category="furniture", meta=None, footprint=None, clearance=0, surfaces=None, **kw):
    m = {**placement(layer, footprint, clearance=clearance, **kw), **(meta or {})}
    if surfaces:
        m["surfaces"] = surfaces
    return b.finish(KIT, category, m)


def legs(b, w, d, h=0.08, inset=0.07, mat="wood_dark", s=0.07, splay=0):
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(s, s, h, sx * (w / 2 - inset), sy * (d / 2 - inset), 0, mat, bevel=0.012,
                  rot=(-sy * splay, sx * splay, 0))


def diamond(b, x, y, z, s=0.07, mat=ACCENT, depth=0.012):
    """Flat diamond motif facing -Y (pillows, headboard)."""
    b.prism([(0, -s), (s * 0.8, 0), (0, s), (-s * 0.8, 0)], depth, x=x, y=y, z=z, mat=mat)


def pillow(b, x, y, z, w=0.3, h=0.26, mat=CUSHION, tilt=-14, yaw=0, motif=ACCENT):
    with b.at((x, y, z), rot=(tilt, 0, yaw)):
        b.box(w, 0.1, h, 0, 0, 0, mat, bevel=0.045, center=True)
        b.box(w * 0.78, 0.13, h * 0.72, 0, 0, 0, mat, bevel=0.04, center=True)
        if motif:
            diamond(b, 0, -0.07, 0, s=h * 0.26, mat=motif)


# Home Details & Storage sheet palette roles
PATCH = (tint("patch_a", "coral"), tint("patch_b", "cream"), tint("patch_c", "teal"))


def penguin_outline(h=1.0, belly=False):
    """Front silhouette of the bird (x, z), z from 0 to h: flat feet, flippers flared at mid-body,
    a slight neck and a round head. belly=True gives the inner face/belly patch."""
    if belly:
        return [(math.cos(math.radians(-90 + i * 360 / 14)) * 0.2 * h,
                 0.4 * h + math.sin(math.radians(-90 + i * 360 / 14)) * 0.3 * h) for i in range(14)]
    right = [(0.2, 0.0), (0.3, 0.06), (0.35, 0.2), (0.47, 0.3), (0.45, 0.36), (0.35, 0.44),
             (0.3, 0.62), (0.26, 0.74), (0.27, 0.83), (0.22, 0.94), (0.12, 0.99)]
    pts = [(x * h, z * h) for x, z in right] + [(0.0, h)] + [(-x * h, z * h) for x, z in reversed(right)]
    return pts


def penguin_badge(b, x, y, z, h, body, belly_mat=None, depth=0.01):
    """Flat penguin motif facing -Y (clock face, mat, bookends)."""
    b.prism(penguin_outline(h), depth, x=x, y=y, z=z, mat=body)
    if belly_mat:   # thin inlay standing 3 mm proud of the front face (y - depth/2)
        t = min(depth, 0.006)
        b.prism(penguin_outline(h, belly=True), t, x=x, y=y - depth / 2 - t / 2 + 0.003, z=z, mat=belly_mat)


def draped(b, prof, y0, y1, cols=3, thick=0.025, mats=PATCH, tassels=True, axis="x"):
    """Patchwork cloth laid along a profile polyline [(u, z), ...] (u = world X, or world Y when
    axis='y') and extruded between y0..y1 across the other axis: one row of patches per segment."""
    span = (y1 - y0) / cols
    for i, (p0, p1) in enumerate(zip(prof, prof[1:])):
        du, dz = p1[0] - p0[0], p1[1] - p0[1]
        L = math.hypot(du, dz)
        ang = math.degrees(math.atan2(dz, du))
        mu, mz = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        for j in range(cols):
            c = y0 + span * (j + 0.5)
            m = pick(mats, i + j)
            if axis == "x":
                b.box(L + 0.006, span - 0.004, thick, mu, c, mz, m, bevel=0.006, rot=(0, -ang, 0), center=True)
            else:
                b.box(span - 0.004, L + 0.006, thick, c, mu, mz, m, bevel=0.006, rot=(ang, 0, 0), center=True)
    if tassels:
        for (u, z) in (prof[0], prof[-1]):
            for yy in (y0 + 0.02, y1 - 0.02):
                xx, yv = (u, yy) if axis == "x" else (yy, u)
                b.cyl(0.004, 0.04, xx, yv, z - 0.05, "cream", segs=4)
                b.blob(0.018, 0.018, 0.026, xx, yv, z - 0.06, tint("tassel", "cream"), subdiv=1)


# ---------------------------------------------------------------- seating
def armchair():
    b = Builder("armchair")
    col = tint("upholstery", "coral")
    w, d = 0.86, 0.78
    legs(b, w - 0.04, d - 0.04, h=0.1, mat=FINISH, s=0.07, splay=6)
    b.box(w - 0.06, d - 0.04, 0.2, 0, 0, 0.09, col, bevel=0.06)                      # base
    b.box(w - 0.34, d - 0.22, 0.13, 0, -0.07, 0.28, col, bevel=0.055)               # seat cushion
    b.box(w - 0.08, 0.24, 0.5, 0, d / 2 - 0.13, 0.27, col, bevel=0.085, rot=(-6, 0, 0))  # back
    for sx in (-1, 1):                                                               # rolled, flared arms
        b.box(0.19, d, 0.27, sx * (w / 2 - 0.1), 0, 0.27, col, bevel=0.08, rot=(0, sx * 4, 0))
    pillow(b, 0, d / 2 - 0.29, 0.56)
    b.socket("seat_0", (0, -0.1, 0.41))
    return done(b, "floor", clearance=1,
                meta=variants(upholstery=("coral", "olive", "navy", "mustard"), cushion=("cream", "white")))


def sofa():
    b = Builder("sofa_2seat")
    col = tint("upholstery", "indigo")
    w, d = 1.44, 0.8
    legs(b, w - 0.04, d - 0.04, h=0.1, mat=FINISH, s=0.07, splay=6)
    b.box(w - 0.04, d - 0.04, 0.2, 0, 0, 0.09, col, bevel=0.06)
    cw = (w - 0.38) / 2
    for i, sx in enumerate((-1, 1)):
        b.box(cw - 0.015, d - 0.24, 0.13, sx * cw / 2, -0.07, 0.28, col, bevel=0.055)
        b.box(cw - 0.03, 0.2, 0.42, sx * cw / 2, d / 2 - 0.21, 0.35, col, bevel=0.075, rot=(-7, 0, 0))
        b.box(0.19, d, 0.28, sx * (w / 2 - 0.1), 0, 0.27, col, bevel=0.08, rot=(0, sx * 4, 0))
    b.box(w - 0.04, 0.16, 0.5, 0, d / 2 - 0.08, 0.27, col, bevel=0.06)
    pillow(b, -cw / 2 - 0.04, d / 2 - 0.33, 0.6, yaw=8, motif=None)
    pillow(b, cw / 2 + 0.06, d / 2 - 0.33, 0.58, mat=tint("cushion_b2", "teal"), yaw=-10, motif=tint("cushion_accent", "cream"))
    b.socket("seat_0", (-cw / 2, -0.1, 0.41))
    b.socket("seat_1", (cw / 2, -0.1, 0.41))
    return done(b, "floor", clearance=1,
                meta=variants(upholstery=("indigo", "mustard", "coral", "olive"), cushion=("cream", "white")))


def desk_stool():
    b = Builder("desk_stool")
    for i in range(4):
        a = math.radians(45 + 90 * i)
        b.box(0.05, 0.05, 0.36, math.cos(a) * 0.12, math.sin(a) * 0.12, 0, FINISH, bevel=0.01,
              rot=(-math.sin(a) * 7, math.cos(a) * 7, 0))
    b.cyl(0.15, 0.04, 0, 0, 0.34, FINISH, segs=10, bevel=0.01)
    b.cyl(0.155, 0.07, 0, 0, 0.375, tint("cushion", "cream"), segs=10, bevel=0.025)
    b.cyl(0.12, 0.012, 0, 0, 0.443, tint("cushion", "cream"), segs=10)
    b.socket("seat_0", (0, 0, 0.45))
    return done(b, "floor", meta=variants(cushion=("cream", "sage", "coral")))


# ---------------------------------------------------------------- tables & storage
def low_table():
    b = Builder("low_table_round")
    r = 0.44
    b.cyl(r, 0.07, 0, 0, 0.3, FINISH, segs=12, bevel=0.018)
    for y in (-0.15, 0.0, 0.15):                                                     # plank seams
        b.box(2 * math.sqrt(r * r - y * y) - 0.06, 0.008, 0.006, 0, y, 0.37, "wood_deep", bevel=0)
    b.cyl(r * 0.82, 0.05, 0, 0, 0.255, FINISH, segs=12, bevel=0.01)                 # apron
    for i in range(4):
        a = math.radians(45 + 90 * i)
        b.box(0.085, 0.085, 0.29, math.cos(a) * r * 0.62, math.sin(a) * r * 0.62, 0, FINISH, bevel=0.016,
              rot=(-math.sin(a) * 6, math.cos(a) * 6, 0))
    b.socket("surface_0", (0, 0, 0.37))
    return done(b, "floor", surfaces={"surface_0": [0.6, 0.6]}, meta=variants(finish=("wood", "wood_dark")))


def writing_desk():
    b = Builder("writing_desk")
    w, d, h = 1.2, 0.56, 0.62
    b.box(w, d, 0.06, 0, 0, h - 0.06, FINISH, bevel=0.018)
    for x in (-0.36, 0.0, 0.36):
        b.box(0.006, d - 0.04, 0.004, x, 0, h, "wood_deep", bevel=0)                 # plank seams
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.075, 0.075, h - 0.06, sx * (w / 2 - 0.08), sy * (d / 2 - 0.07), 0, FINISH, bevel=0.015,
                  rot=(-sy * 4, sx * 4, 0))
    b.box(w - 0.2, 0.04, 0.09, 0, d / 2 - 0.07, h - 0.15, FINISH, bevel=0.01)       # back apron
    b.box(w - 0.24, 0.04, 0.04, 0, d / 2 - 0.07, 0.12, "wood_b", bevel=0.008)       # stretcher
    # drawer box on the right, front at -Y
    dx = w / 2 - 0.27
    b.box(0.36, d - 0.1, 0.13, dx, 0, h - 0.19, FINISH, bevel=0.012)
    with b.part("drawer", pivot=(dx, -d / 2 + 0.035, h - 0.17), motion="slide", dir=(0, -1, 0), dist=0.25):
        b.box(0.3, 0.03, 0.09, dx, -d / 2 + 0.035, h - 0.17, "wood_c", bevel=0.01)
        b.sphere(0.022, dx, -d / 2 + 0.01, h - 0.125, "gold", u=6, v=4)
    b.socket("surface_0", (0, 0, h))
    b.socket("use", (-0.2, -d / 2 - 0.25, 0), rotz=0)
    return done(b, "floor", clearance=1, surfaces={"surface_0": [w - 0.1, d - 0.08]},
                meta=variants(finish=("wood", "wood_dark", "cream")))


def cube_shelf():
    b = Builder("cube_shelf")
    mat = tint("finish", "teal")
    w, d, h, t = 0.9, 0.4, 0.92, 0.055
    for sx in (-1, 0, 1):
        b.box(t, d, h - 2 * t, sx * (w / 2 - t / 2), 0, t, mat, bevel=0.012)
    for z in (0, h / 2 - t / 2, h - t):
        b.box(w, d, t, 0, 0, z, mat, bevel=0.016)
    b.box(w - 0.04, 0.025, h - 0.06, 0, d / 2 - 0.0125, 0.03, mat, bevel=0)
    b.box(w - 0.02, 0.05, 0.05, 0, -d / 2 + 0.03, -0.0, "wood_deep", bevel=0.01)   # kick
    cw = (w - 3 * t) / 2
    surf = {}
    for i, (cx, cz) in enumerate(((-(cw / 2 + t / 2), t), (cw / 2 + t / 2, t),
                                  (-(cw / 2 + t / 2), h / 2 + t / 2), (cw / 2 + t / 2, h / 2 + t / 2))):
        b.socket(f"surface_{i}", (cx, -0.01, cz))
        surf[f"surface_{i}"] = [round(cw - 0.02, 2), round(d - 0.05, 2)]
    b.socket("surface_4", (0, 0, h))
    surf["surface_4"] = [w - 0.04, d - 0.04]
    return done(b, "floor", surfaces=surf, meta=variants(finish=("teal", "wood", "blue", "wood_dark")))


def wall_shelf():
    b = Builder("wall_shelf")
    w, d = 0.9, 0.24
    # back at y=0, origin at the centre of the back face; plank sits at z=0
    b.box(w, d, 0.05, 0, -d / 2, -0.025, FINISH, bevel=0.014)
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.16)
        b.box(0.05, 0.03, 0.2, x, -0.015, -0.225, "wood_dark", bevel=0.01)
        b.prism([(0, 0), (-0.17, 0), (0, -0.17)], 0.045, x=x, y=0, z=-0.025, mat="wood_dark", rot=(0, 0, 90))
    b.socket("surface_0", (0, -d / 2, 0.025))
    return done(b, "wall", surfaces={"surface_0": [w - 0.04, d - 0.03]}, meta=variants(finish=("wood", "wood_dark", "cream")))


# ---------------------------------------------------------------- bed & lighting
def bed():
    b = Builder("bed")
    blanket = tint("bedding", "coral")
    w, L = 0.96, 1.46
    hy, fy = L / 2 - 0.05, -L / 2 + 0.05
    for sx in (-1, 1):
        b.box(0.075, L - 0.1, 0.14, sx * (w / 2 - 0.04), 0, 0.12, FINISH, bevel=0.015)  # rails
        b.box(0.11, 0.11, 0.86, sx * (w / 2 - 0.05), hy, 0, FINISH, bevel=0.022)     # head posts
        b.box(0.13, 0.13, 0.04, sx * (w / 2 - 0.05), hy, 0.86, "wood_dark", bevel=0.012)
        b.box(0.11, 0.11, 0.5, sx * (w / 2 - 0.05), fy, 0, FINISH, bevel=0.022)      # foot posts
    for z in (0.34, 0.7):
        b.box(w - 0.12, 0.07, 0.1, 0, hy, z, FINISH, bevel=0.015)                   # headboard rails
    b.box(w - 0.12, 0.05, 0.26, 0, hy, 0.44, "wood_c", bevel=0.012)
    b.box(w - 0.12, 0.07, 0.24, 0, fy, 0.2, FINISH, bevel=0.015)                    # footboard
    b.box(w - 0.06, 0.09, 0.06, 0, fy, 0.44, "wood_dark", bevel=0.015)
    b.box(w - 0.14, L - 0.2, 0.18, 0, 0.01, 0.2, "cream", bevel=0.045)              # mattress
    bl = L * 0.64                                                                    # blanket draping over
    by = fy + 0.07 + bl / 2
    b.box(w - 0.07, bl, 0.22, 0, by, 0.2, blanket, bevel=0.07)
    b.box(w - 0.05, 0.16, 0.08, 0, by + bl / 2 - 0.04, 0.35, tint("bedding_fold", "cream"), bevel=0.035)
    pillow(b, 0, hy - 0.24, 0.47, w=0.5, h=0.18, mat=tint("pillow", "coral"), tilt=-62, motif=tint("cushion_accent", "cream"))
    b.socket("sleep", (0, 0.1, 0.44))
    b.socket("seat_0", (0, -0.35, 0.4))
    return done(b, "floor", clearance=1, meta=variants(bedding=("coral", "blue", "olive", "purple"), pillow=("coral", "cream")))


def floor_lamp():
    b = Builder("floor_lamp")
    base = FINISH
    b.cyl(0.17, 0.05, 0, 0, 0, base, segs=8, bevel=0.012)
    b.cyl(0.12, 0.04, 0, 0, 0.05, base, segs=8, r2=0.08, bevel=0.008)
    b.cyl(0.03, 1.08, 0, 0, 0.09, base, segs=6)
    for z in (0.32, 0.7):                                                            # turned bulges
        b.cyl(0.045, 0.06, 0, 0, z, base, segs=6, bevel=0.012)
    b.cyl(0.05, 0.06, 0, 0, 1.15, "gold", segs=6)
    b.sphere(0.06, 0, 0, 1.2, "bulb", u=8, v=5)
    b.cyl(0.25, 0.3, 0, 0, 1.08, tint("shade", "mustard"), segs=8, r2=0.13, cap=False)  # open cone shade
    b.cyl(0.25, 0.012, 0, 0, 1.08, tint("shade", "mustard"), segs=8)                  # rim
    b.cyl(0.2, 0.004, 0, 0, 1.092, "glow", segs=8)                                    # lit underside
    b.cyl(0.004, 0.16, 0.1, -0.05, 0.94, "gold", segs=4)                             # pull cord
    b.sphere(0.018, 0.1, -0.05, 0.93, FINISH, u=6, v=4)
    b.socket("light", (0, 0, 1.2))
    b.socket("use", (0.1, -0.35, 0))
    return done(b, "floor", meta=variants(shade=("mustard", "sky", "coral"), finish=("wood", "wood_dark", "charcoal")))


# ---------------------------------------------------------------- plants
def pot(b, x=0, y=0, z=0, r=0.13, h=0.2, mat="terracotta", segs=6, faceted=False):
    mat = tint("pot", mat)
    if faceted:   # chunky faceted planter (Home Decor sheet)
        b.cyl(r * 0.72, h * 0.5, x, y, z, mat, segs=segs, r2=r, jitter=0.0)
        b.cyl(r, h * 0.5, x, y, z + h * 0.5, mat, segs=segs, r2=r * 0.92)
    else:
        b.cyl(r * 0.78, h, x, y, z, mat, segs=segs, r2=r, bevel=0.01)
        b.cyl(r * 1.08, 0.045, x, y, z + h - 0.035, mat, segs=segs, bevel=0.01)
    b.cyl(r * 0.86, 0.02, x, y, z + h - 0.012, "soil", segs=segs)
    return z + h


def leaf(b, x, y, z, L, W, yaw, tilt, mat="leaf"):
    with b.at((x, y, z), rot=(tilt, 0, yaw)):
        b.prism([(0, 0), (W / 2, L * 0.4), (0, L), (-W / 2, L * 0.4)], 0.02, mat=mat)


def monstera_leaf(b, x, y, z, L, yaw, tilt, mat="leaf"):
    """Big split leaf on a stem, blade facing outward; outline has notches each side."""
    W = L * 0.85
    pts = [(0, 0), (W * 0.45, L * 0.22), (W * 0.3, L * 0.34), (W * 0.52, L * 0.5), (W * 0.3, L * 0.62),
           (W * 0.38, L * 0.8), (0, L), (-W * 0.38, L * 0.8), (-W * 0.3, L * 0.62), (-W * 0.52, L * 0.5),
           (-W * 0.3, L * 0.34), (-W * 0.45, L * 0.22)]
    stem = L * 0.8
    with b.at((x, y, z), rot=(tilt * 0.4, 0, yaw)):
        b.cyl(0.011, stem, 0, 0, 0, "leaf_dark", segs=5)
        with b.at((0, 0, stem), rot=(tilt, 0, 0)):     # blade droops outward past the stem
            b.prism(pts, 0.016, mat=mat)
            b.box(0.012, 0.024, L * 0.85, 0, 0, 0, "leaf_dark", bevel=0)   # midrib


def plant(b, kind, x=0, y=0, z=0, s=1.0):
    """Potted plants (Home Decor sheet + concept 11)."""
    with b.at((x, y, z), scale=s):
        rng = b.rng
        if kind == "large":
            t = pot(b, r=0.22, h=0.32, mat="cream", segs=7, faceted=True)
            for i in range(7):
                monstera_leaf(b, rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), t - 0.02,
                              rng.uniform(0.28, 0.36), i * 360 / 7 + rng.uniform(-14, 14), rng.uniform(30, 55),
                              pick(("leaf", "leaf_dark", "leaf_b"), i))
        elif kind == "small":
            t = pot(b, r=0.1, h=0.13, mat="cream", segs=6, faceted=True)
            for i in range(5):
                leaf(b, 0, 0, t - 0.01, rng.uniform(0.12, 0.17), 0.09, i * 72 + rng.uniform(-10, 10),
                     rng.uniform(30, 55), pick(("leaf", "leaf_b"), i))
        elif kind == "topiary":
            t = pot(b, mat="cream", r=0.12)
            b.cyl(0.02, 0.1, 0, 0, t, "bark", segs=5)
            b.blob(0.2, 0.2, 0.2, 0, 0, t + 0.24, "leaf_dark", subdiv=1, jitter=0.02)
            b.blob(0.14, 0.14, 0.12, 0.04, -0.05, t + 0.32, "leaf", subdiv=1, jitter=0.015)
        elif kind == "broadleaf":
            t = pot(b, r=0.13)
            for i in range(7):
                leaf(b, 0, 0, t - 0.02, rng.uniform(0.26, 0.36), 0.16, i * 360 / 7 + rng.uniform(-10, 10),
                     rng.uniform(25, 50), pick(("leaf", "leaf_dark", "leaf_b"), i))
        elif kind == "snake":
            t = pot(b, r=0.15, h=0.22)
            for i in range(8):
                leaf(b, rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), t - 0.02, rng.uniform(0.32, 0.5), 0.12,
                     i * 45 + rng.uniform(-15, 15), rng.uniform(8, 30), pick(("leaf_dark", "leaf", "pine_b"), i))
        elif kind == "cactus":
            t = pot(b, mat="cream", r=0.12, h=0.18)
            b.cyl(0.07, 0.36, 0, 0, t - 0.02, "leaf_dark", segs=6, r2=0.05, jitter=0.006)
            b.cyl(0.04, 0.14, 0.09, 0, t + 0.12, "leaf", segs=6, r2=0.03, rot=(0, 20, 0))
            b.cyl(0.035, 0.1, -0.08, 0, t + 0.18, "leaf", segs=6, r2=0.025, rot=(0, -25, 0))
        elif kind == "flowerpot":
            t = pot(b, r=0.15, h=0.2, segs=8)
            foliage(b, 0.26, 0.26, t - 0.02, flowers=(tint("petal", "petal_white"), "petal_yellow"), fsize=0.07)
        elif kind == "hanging":
            # origin is the ceiling hook; everything hangs below z=0
            b.torus(0.03, 0.008, 0, 0, -0.03, "iron", segs=8, ring=4, rot=(90, 0, 0))
            bot = -0.55
            with b.part("planter", pivot=(0, 0, -0.05), motion="sway", amp_deg=3):
                for i in range(3):
                    a = math.radians(90 + 120 * i)
                    rope_between(b, (0, 0, -0.05), (math.cos(a) * 0.12, math.sin(a) * 0.12, bot + 0.16), sag=0, r=0.008, segs=1)
                t = pot(b, 0, 0, bot, r=0.13, h=0.16, segs=8)
                foliage(b, 0.16, 0.16, t - 0.02, flowers=None, height=0.1)
                for i in range(6):
                    a = math.radians(i * 60 + 20)
                    px, py = math.cos(a) * 0.14, math.sin(a) * 0.14
                    for k in range(rng.randint(3, 5)):
                        b.blob(0.035, 0.035, 0.04, px * (1 + k * 0.08), py * (1 + k * 0.08), t - 0.06 - k * 0.07,
                               pick(("leaf", "leaf_dark"), k + i), subdiv=1, jitter=0.006)


def flower_box():
    b = Builder("flower_box")
    planter_box(b, 0.82, 0.36, 0.26, flowers=(tint("petal", "petal_white"), tint("petal_alt", "petal_red")))
    return done(b, "floor", meta=variants(petal=("petal_white", "petal_yellow"), petal_alt=("petal_red", "pink")))


# ---------------------------------------------------------------- rugs
def rug_round():
    b = Builder("rug_round")
    rings = ((0.74, "cream"), (0.61, "olive"), (0.46, "cream"), (0.3, "olive"))
    for i, (r, c) in enumerate(rings):
        b.cyl(r, 0.014 + i * 0.003, 0, 0, 0, tint("rug" if c == "olive" else "rug_base", c), segs=20)
    for i in range(20):                                                              # stitched border
        a = math.radians(i * 18 + 9)
        b.box(0.05, 0.012, 0.004, math.cos(a) * 0.74, math.sin(a) * 0.68, 0.014, "wood_c", bevel=0,
              rot=(0, 0, i * 18 + 99))
    return done(b, "rug", category="decor", meta=variants(rug=("olive", "coral", "teal"), rug_base=("cream",)))


def rug_patchwork():
    b = Builder("rug_patchwork")
    W, D, cols, rows = 1.3, 0.92, 4, 3
    cw, ch = W / cols, D / rows
    roles = (tint("rug_0", "teal"), tint("rug_1", "purple"), tint("rug_2", "cream"))
    b.box(W + 0.04, D + 0.04, 0.012, 0, 0, 0, roles[2], bevel=0.004)
    for i in range(cols):
        for j in range(rows):
            x0, y0 = -W / 2 + i * cw, -D / 2 + j * ch
            A, B = pick(roles, i + j * 2), pick(roles, i * 2 + j + 1)
            if (i + j) % 2:
                t1 = [(x0, y0), (x0 + cw, y0), (x0, y0 + ch)]
                t2 = [(x0 + cw, y0), (x0 + cw, y0 + ch), (x0, y0 + ch)]
            else:
                t1 = [(x0, y0), (x0 + cw, y0), (x0 + cw, y0 + ch)]
                t2 = [(x0, y0), (x0 + cw, y0 + ch), (x0, y0 + ch)]
            b.prism(t1, 0.006, z=0.012, mat=A, plane="xy")
            b.prism(t2, 0.006, z=0.012, mat=B, plane="xy")
    for sx in (-1, 1):                                                               # fringe on short ends
        for k in range(11):
            y = -D / 2 + 0.06 + k * (D - 0.12) / 10
            b.box(0.08, 0.022, 0.008, sx * (W / 2 + 0.05), y, 0, "cream", bevel=0)
    return done(b, "rug", category="decor",
                meta=variants(rug_0=("teal", "coral"), rug_1=("purple", "navy"), rug_2=("cream",)))


def rug_round_plain():
    b = Builder("rug_round_plain")
    b.cyl(0.73, 0.018, 0, 0, 0, tint("rug_edge", "plaster_shade"), segs=16)
    b.cyl(0.62, 0.022, 0, 0, 0, tint("rug", "white"), segs=16)
    return done(b, "rug", category="decor", meta=variants(rug=("white", "sage", "pink")))


# ---------------------------------------------------------------- wall & ceiling
def frame_box(b, w, h, fw, fm, depth=0.05):
    """Picture frame on a wall: back at y=0, centred on z=0."""
    for sx in (-1, 1):
        b.box(fw, depth, h + 2 * fw, sx * (w / 2 + fw / 2), -depth / 2, -h / 2 - fw, fm, bevel=0.012)
    for z in (-h / 2 - fw, h / 2):
        b.box(w, depth, fw, 0, -depth / 2, z, fm, bevel=0.012)


def wall_poster():
    """Home Decor sheet poster: wood frame on a hanging cord, replaceable art insert."""
    b = Builder("wall_poster")
    w, h, fw = 0.46, 0.58, 0.06
    fm = tint("frame", "wood")
    frame_box(b, w, h, fw, fm)
    b.box(w, 0.02, h, 0, -0.02, -h / 2, "insert_poster", bevel=0)
    top = h / 2 + fw
    rope_between(b, (-w * 0.3, -0.01, top - 0.02), (0, -0.01, top + 0.12), sag=0, r=0.006, segs=1)
    rope_between(b, (w * 0.3, -0.01, top - 0.02), (0, -0.01, top + 0.12), sag=0, r=0.006, segs=1)
    b.cyl(0.015, 0.03, 0, -0.015, top + 0.115, "iron", segs=6, rot=(90, 0, 0), center=True)
    return done(b, "wall", category="decor", rotations=(0,),
                meta={**variants(frame=("wood", "wood_dark", "purple", "teal")), "inserts": ["insert_poster"]})


def poster(name, style):
    b = Builder(name)
    w, h = 0.48, 0.6
    fw = {"thin": 0.05, "matted": 0.06, "bold": 0.09}[style]
    fm = tint("frame", {"thin": "wood", "matted": "wood_c", "bold": "wood_dark"}[style])
    frame_box(b, w, h, fw, fm)
    if style == "matted":
        b.box(w, 0.02, h, 0, -0.015, -h / 2, "cream", bevel=0)
        b.box(w * 0.6, 0.02, h * 0.62, 0, -0.025, -h * 0.31, "insert_poster", bevel=0)
    else:
        b.box(w, 0.02, h, 0, -0.02, -h / 2, "insert_poster", bevel=0)
    return done(b, "wall", category="decor", rotations=(0,),
                meta={**variants(frame=("wood", "wood_dark", "purple", "teal")), "inserts": ["insert_poster"]})


def star(b, x, y, z, r, mat, depth=0.03):
    pts = []
    for i in range(10):
        a = math.radians(90 + i * 36)
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    b.prism(pts, depth, x=x, y=y, z=z, mat=mat)


def star_mobile():
    """Ceiling item: origin is the hook; hoop with stars, a moon and crystals hanging below."""
    b = Builder("star_mobile")
    wood = tint("finish", "wood")
    b.torus(0.03, 0.008, 0, 0, -0.03, "gold", segs=8, ring=4, rot=(90, 0, 0))
    with b.part("mobile", pivot=(0, 0, -0.06), motion="sway", amp_deg=4):
        hz = -0.32
        for i in range(4):                                                               # hanger strings
            a = math.radians(45 + 90 * i)
            rope_between(b, (0, 0, -0.06), (math.cos(a) * 0.3, math.sin(a) * 0.3, hz), sag=0, r=0.004, segs=1, mat="cream")
        b.torus(0.3, 0.022, 0, 0, hz, wood, segs=16, ring=6)
        b.cyl(0.025, 0.06, 0, 0, hz - 0.03, wood, segs=6)
        hang = [("star", 0, 0.24), ("crystal", 36, 0.3), ("star", 72, 0.2), ("crystal", 108, 0.36), ("star", 144, 0.26),
                ("crystal", 180, 0.28), ("star", 216, 0.22), ("crystal", 252, 0.34), ("star", 288, 0.18), ("crystal", 324, 0.3)]
        for kind, deg, drop in hang:
            a = math.radians(deg)
            px, py = math.cos(a) * 0.3, math.sin(a) * 0.3
            rope_between(b, (px, py, hz - 0.01), (px, py, hz - drop), sag=0, r=0.003, segs=1, mat="cream")
            if kind == "star":
                with b.at((px, py, hz - drop - 0.07), rotz=deg + 90):
                    star(b, 0, 0, 0, 0.07, tint("charm", "yellow"))
            else:
                with b.at((px, py, hz - drop - 0.04)):
                    b.cyl(0.035, 0.05, 0, 0, 0, tint("crystal", "lavender"), segs=5, r2=0.0)
                    b.cyl(0.035, 0.08, 0, 0, 0, tint("crystal", "lavender"), segs=5, r2=0.0, rot=(180, 0, 0))
        # centre crescent moon
        moon = []
        for i in range(13):
            a = math.radians(-120 + i * 20)
            moon.append((math.cos(a) * 0.13, math.sin(a) * 0.13))
        for i in range(13):
            a = math.radians(120 - i * 20)
            moon.append((math.cos(a) * 0.1 + 0.055, math.sin(a) * 0.1))
        rope_between(b, (0, 0, hz - 0.06), (0, 0, hz - 0.26), sag=0, r=0.003, segs=1, mat="cream")
        with b.at((0, 0, hz - 0.4), rotz=90):
            b.prism(moon, 0.04, mat=tint("charm", "yellow"))
    return done(b, "ceiling", category="decor", rotations=(0, 90, 180, 270),
                meta=variants(charm=("yellow", "white"), crystal=("lavender", "sky")))


# ---------------------------------------------------------------- arcade & aquarium
def arcade_home():
    b = Builder("arcade_cabinet_home")
    body = tint("body", "purple")
    with b.at(scale=0.78):
        cabinet(b, body)   # joystick_1 (tilt) and btn_1_* (press) parts come from the arcade cabinet
        for sx in (-1, 1):                                                          # star decals on the sides
            for (yy, zz, r) in ((0.12, 1.2, 0.06), (0.0, 0.85, 0.05), (0.15, 0.55, 0.06), (-0.08, 0.3, 0.045)):
                with b.at((sx * 0.312, yy, zz), rotz=90 * sx):
                    star(b, 0, 0, 0, r, tint("decal", "yellow"), depth=0.006)
    b.socket("player_1", (0, -0.62, 0), rotz=180)
    return done(b, "floor", clearance=1, meta=variants(body=("purple", "mustard", "teal_light", "red"), decal=("yellow", "white")))


def aquarium():
    b = Builder("aquarium")
    frame = tint("frame", "teal")
    stand = tint("finish", "wood")
    w, d = 1.0, 0.46
    sh = 0.42
    for sx in (-1, 1):                                                               # stand
        for sy in (-1, 1):
            b.box(0.08, 0.08, sh, sx * (w / 2 - 0.06), sy * (d / 2 - 0.06), 0, stand, bevel=0.015)
    b.box(w, d, 0.07, 0, 0, sh, stand, bevel=0.018)
    b.box(w - 0.12, 0.05, 0.08, 0, -d / 2 + 0.04, sh - 0.08, stand, bevel=0.01)
    b.box(w - 0.12, d - 0.12, 0.04, 0, 0, 0.1, "wood_b", bevel=0.01)                 # lower shelf
    tz, th = sh + 0.07, 0.5
    b.box(w - 0.04, d - 0.04, 0.04, 0, 0, tz, frame, bevel=0.012)                    # tank base frame
    b.box(w - 0.04, d - 0.04, 0.035, 0, 0, tz + th, frame, bevel=0.012)              # top frame (ring)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.035, 0.035, th, sx * (w / 2 - 0.0375), sy * (d / 2 - 0.0375), tz + 0.02, frame, bevel=0.006)
    ix, iy = w - 0.1, d - 0.1
    for sy in (-1, 1):                                                               # glass panes
        b.box(ix + 0.02, 0.012, th - 0.02, 0, sy * (d / 2 - 0.04), tz + 0.04, "glass", bevel=0)
    for sx in (-1, 1):
        b.box(0.012, iy + 0.02, th - 0.02, sx * (w / 2 - 0.04), 0, tz + 0.04, "glass", bevel=0)
    b.box(ix, iy, 0.012, 0, 0, tz + th - 0.08, "glass", bevel=0)                    # water surface
    gz = tz + 0.04
    rng = b.rng
    for i in range(26):                                                              # gravel
        b.blob(0.035, 0.03, 0.02, rng.uniform(-ix / 2 + 0.04, ix / 2 - 0.04), rng.uniform(-iy / 2 + 0.03, iy / 2 - 0.03),
               gz + 0.02, pick(("tan", "paving_b", "rock_b"), i), subdiv=1, jitter=0.004)
    b.box(ix, iy, 0.03, 0, 0, gz, "tan", bevel=0)
    for i, (px, py) in enumerate(((-0.32, 0.08), (-0.25, 0.1), (0.3, 0.09), (0.36, 0.05), (0.05, 0.12))):
        for k in range(4):                                                           # weed fronds
            leaf(b, px, py, gz + 0.03, rng.uniform(0.18, 0.3), 0.05, k * 90 + rng.uniform(-20, 20),
                 rng.uniform(5, 18), pick(("leaf_dark", "leaf"), k + i))
    b.blob(0.07, 0.06, 0.05, 0.18, 0.05, gz + 0.05, "rock_grey", subdiv=1, jitter=0.01)

    def fish(name, x, y, z, body, stripe, yaw):
        with b.part(name, pivot=(x, y, z), motion="sway", amp_deg=14), b.at((x, y, z), rotz=yaw):
            b.blob(0.06, 0.025, 0.04, 0, 0, 0, body, subdiv=1)
            b.prism([(0.05, 0), (0.1, 0.035), (0.1, -0.035)], 0.012, mat=body)  # tail fin
            if stripe:
                b.box(0.012, 0.054, 0.07, -0.015, 0, 0, stripe, bevel=0, center=True)
                b.box(0.012, 0.054, 0.06, 0.025, 0, 0, stripe, bevel=0, center=True)
            for sy in (-1, 1):
                b.sphere(0.008, -0.04, sy * 0.02, 0.012, "eye", u=5, v=3)
    fish("fish_0", 0.12, -0.05, tz + 0.27, "orange", "white", 180)
    fish("fish_1", -0.16, 0.02, tz + 0.2, "blue", None, 0)
    b.socket("fx_bubbles", (0.18, 0.05, gz + 0.1))
    b.socket("use", (0, -d / 2 - 0.3, 0))
    return done(b, "floor", clearance=1, meta=variants(frame=("teal", "wood_dark", "charcoal"), finish=("wood", "wood_dark")))


# ---------------------------------------------------------------- small decor (surface layer)
def small(name, fn, meta=None, surfaces=None, layer="surface", footprint=(1, 1)):
    b = Builder(name)
    fn(b)
    return done(b, layer, category="decor", footprint=list(footprint) if footprint else None, meta=meta, surfaces=surfaces)


def _book(b, x, y, z, w, d, t, col, yaw=0):
    with b.at((x, y, z), rotz=yaw):
        b.box(w, d, t, 0, 0, 0, col, bevel=0.006)
        b.box(w - 0.012, d - 0.008, t - 0.012, 0.006, 0, 0.006, "cream", bevel=0)  # page block


def book_single(b):
    _book(b, 0, 0, 0, 0.17, 0.12, 0.03, tint("cover", "red"))


def book_stack(b):
    for i, (c, yaw) in enumerate((("blue", 0), ("teal", 9), ("mustard", -6))):
        _book(b, 0, 0, i * 0.032, 0.17 - i * 0.012, 0.12 - i * 0.008, 0.03, tint(f"cover_{i}", c), yaw)


def mug(b):
    b.cyl(0.04, 0.085, 0, 0, 0, tint("glaze", "white"), segs=8, bevel=0.006)
    b.cyl(0.033, 0.01, 0, 0, 0.072, "wood_deep", segs=8)
    b.torus(0.024, 0.008, 0.045, 0, 0.045, tint("glaze", "white"), segs=8, ring=4, rot=(90, 0, 0))


def cushion(b):
    with b.at((0, 0, 0.13)):
        b.box(0.3, 0.1, 0.26, 0, 0, 0, tint("cushion", "cream"), bevel=0.045, center=True)
        b.box(0.24, 0.13, 0.19, 0, 0, 0, tint("cushion", "cream"), bevel=0.04, center=True)
        diamond(b, 0, -0.07, 0, s=0.07, mat=tint("cushion_accent", "coral"))
        diamond(b, 0, 0.07, 0, s=0.07, mat=tint("cushion_accent", "coral"))


def framed_photo(b):
    with b.at(rot=(-10, 0, 0)):
        for sx in (-1, 1):
            b.box(0.025, 0.02, 0.2, sx * 0.0775, 0, 0, tint("frame", "wood"), bevel=0.006)
        for z in (0, 0.175):
            b.box(0.13, 0.02, 0.025, 0, 0, z, tint("frame", "wood"), bevel=0.006)
        b.box(0.13, 0.008, 0.15, 0, 0.002, 0.025, "insert_poster", bevel=0)
    b.box(0.03, 0.08, 0.012, 0, 0.05, 0, tint("frame", "wood"), bevel=0, rot=(28, 0, 0))


def tabletop_plant(b):
    plant(b, "small", s=0.8)


def candle(b):
    b.cyl(0.05, 0.015, 0, 0, 0, "gold", segs=8, bevel=0.004)
    b.cyl(0.03, 0.09, 0, 0, 0.015, tint("wax", "cream"), segs=8)
    b.cyl(0.004, 0.015, 0, 0, 0.105, "black", segs=4)
    b.blob(0.012, 0.012, 0.024, 0, 0, 0.13, "glow", subdiv=1)
    b.socket("fx_flame", (0, 0, 0.125))


def small_lantern(b):
    lantern_head(b, 0, 0, 0, s=0.65, frame="iron")
    b.socket("fx_flame", (0, 0, 0.1))
    b.torus(0.025, 0.006, 0, 0, 0.27, "iron", segs=8, ring=4, rot=(90, 0, 0))


def trophy(b):
    g = tint("metal", "gold")
    b.box(0.09, 0.09, 0.04, 0, 0, 0, "wood_dark", bevel=0.008)
    b.cyl(0.02, 0.05, 0, 0, 0.04, g, segs=6)
    b.cyl(0.03, 0.02, 0, 0, 0.085, g, segs=8)
    b.cyl(0.03, 0.08, 0, 0, 0.1, g, segs=8, r2=0.06)
    for sx in (-1, 1):
        b.torus(0.025, 0.007, sx * 0.065, 0, 0.15, g, segs=8, ring=4, rot=(90, 0, 0))


def plush_penguin(b):
    """Sitting plush bird: navy-blue body, cream belly and face, orange beak and feet, stubby flippers."""
    body = tint("body", "blue")
    b.blob(0.11, 0.1, 0.12, 0, 0, 0.12, body, subdiv=2)
    b.blob(0.085, 0.05, 0.09, 0, -0.06, 0.11, "belly", subdiv=2)
    b.blob(0.07, 0.04, 0.05, 0, -0.07, 0.17, "belly", subdiv=2)                              # face patch
    for sx in (-1, 1):
        b.sphere(0.012, sx * 0.032, -0.105, 0.185, "eye", u=6, v=4)
        b.blob(0.03, 0.05, 0.065, sx * 0.105, -0.005, 0.1, body, subdiv=1, rot=(0, sx * 30, 0))   # flippers
        b.blob(0.035, 0.05, 0.016, sx * 0.045, -0.06, 0.015, "beak", subdiv=1)               # feet
    b.cyl(0.024, 0.04, 0, -0.1, 0.16, "beak", segs=5, r2=0.0, rot=(90, 0, 0))


def pencil_cup(b):
    b.cyl(0.045, 0.1, 0, 0, 0, tint("glaze", "cream"), segs=8, bevel=0.006)
    for i, (c, a) in enumerate((("red", 0), ("blue", 110), ("yellow", 220), ("green", 300))):
        ar = math.radians(a)
        with b.at((math.cos(ar) * 0.018, math.sin(ar) * 0.018, 0.02), rot=(math.sin(ar) * 16, -math.cos(ar) * 16, 0)):
            b.cyl(0.008, 0.17, 0, 0, 0, c, segs=6)
            b.cyl(0.008, 0.025, 0, 0, 0.17, "tan", segs=6, r2=0.0)


# ---------------------------------------------------------------- curtains, clock, storage, food
def window_curtains():
    """Wall item: rod with two tab-top panels (cream with coral and teal bands) that slide apart
    (part_curtain_l / _r, pivot at the panel top)."""
    b = Builder("window_curtains")
    rod = tint("rod", "wood")
    cloth, band, hem = tint("curtain", "cream"), tint("curtain_band", "coral"), tint("curtain_hem", "teal")
    W, H, top = 1.3, 1.1, 0.6           # origin = centre of the back face; rod near the top
    for sx in (-1, 1):
        b.box(0.04, 0.1, 0.06, sx * (W / 2 - 0.05), -0.05, top - 0.02, rod, bevel=0.008)   # brackets
        b.cyl(0.05, 0.07, sx * (W / 2 + 0.06), -0.09, top + 0.02, rod, segs=8, rot=(0, 90, 0), center=True)  # finials
    b.cyl(0.024, W + 0.06, -(W + 0.06) / 2, -0.09, top + 0.02, rod, segs=8, rot=(0, 90, 0))
    pw = W / 2 - 0.08
    slide = 0.3
    for name, sx in (("curtain_l", -1), ("curtain_r", 1)):
        cx = sx * (pw / 2 + 0.05)
        with b.part(name, pivot=(cx, -0.09, top), motion="slide", dir=(sx, 0, 0), dist=slide):
            n = 4
            for i in range(n):                                                               # pleats
                px = cx - pw / 2 + pw / n * (i + 0.5)
                dy = 0.05 if i % 2 else 0.07
                flare = 0.012 * (i - (n - 1) / 2)
                hb = H * 0.22
                b.box(pw / n + 0.01, dy, H - hb - 0.08, px, -0.09, top - H + hb + 0.08, cloth, bevel=0.012)
                b.box(pw / n + 0.012, dy + 0.004, 0.08, px, -0.09, top - H + hb, band, bevel=0.012)
                b.box(pw / n + 0.014 + abs(flare), dy + 0.006, hb, px + flare, -0.09, top - H, hem, bevel=0.012)
            for k in range(3):                                                               # tab tops over the rod
                tx = cx - pw / 2 + pw * (k + 0.5) / 3
                b.box(0.05, 0.075, 0.1, tx, -0.09, top - 0.02, hem, bevel=0.012)
    return done(b, "wall", category="decor", rotations=(0,),
                meta={**variants(curtain=("cream", "white"), curtain_band=("coral", "mustard"), curtain_hem=("teal", "navy"),
                                 rod=("wood", "wood_dark")),
                      "fits_window_m": [W - 0.2, H - 0.1],
                      "opening_envelope_m": {"closed": [-W / 2, W / 2], "open": [-(W / 2 + slide), W / 2 + slide],
                                             "z": [top - H, top + 0.08], "depth": 0.14}})


def wall_clock():
    """Wall item: octagonal honey frame, cream face with a penguin motif; hands spin about Y."""
    b = Builder("wall_clock")
    frame = tint("frame", "wood")
    hand = tint("hands", "teal")
    R = 0.21
    with b.at((0, 0, 0), rot=(90, 22.5, 0)):      # local +Z -> world -Y (out of the wall); flat-top octagon
        b.cyl(R, 0.055, 0, 0, 0, frame, segs=8, bevel=0.014)
        b.cyl(R - 0.045, 0.012, 0, 0, 0.05, tint("face", "cream"), segs=8)
    with b.at((0, 0, 0), rot=(90, 0, 0)):
        for i in range(12):                                                                  # hour ticks
            a = math.radians(i * 30)
            L = 0.032 if i % 3 == 0 else 0.018
            b.box(0.012, L, 0.006, math.sin(a) * (R - 0.075), math.cos(a) * (R - 0.075), 0.062, hand, bevel=0,
                  rot=(0, 0, -i * 30))
    penguin_badge(b, 0, -0.066, -0.12, 0.08, hand, tint("face", "cream"), depth=0.004)
    hy = -0.07
    with b.part("hand_hour", pivot=(0, hy, 0), motion="spin", axis="y"):
        b.box(0.018, 0.006, 0.085, 0, hy, 0, hand, bevel=0, rot=(0, -60, 0))
    with b.part("hand_minute", pivot=(0, hy - 0.007, 0), motion="spin", axis="y"):
        b.box(0.012, 0.006, 0.13, 0, hy - 0.007, 0, hand, bevel=0, rot=(0, 45, 0))
    b.cyl(0.016, 0.02, 0, hy - 0.016, 0, hand, segs=8, rot=(90, 0, 0), center=True)
    return done(b, "wall", category="decor", rotations=(0,),
                meta=variants(frame=("wood", "teal", "coral", "charcoal"), face=("cream", "white"), hands=("teal", "navy")))


def woven_basket():
    """Checker weave in tan, cream and teal, with loop handles."""
    b = Builder("woven_basket")
    weave = (tint("weave", "tan"), tint("weave_alt", "cream"), tint("weave_accent", "teal"))
    R, n, rows, rh = 0.2, 12, 4, 0.06
    b.cyl(R * 0.85, 0.03, 0, 0, 0, weave[0], segs=n)
    for k in range(rows):
        r = R * (0.88 + 0.04 * k)                                                            # flares upward
        for i in range(n):
            a = math.radians(i * 360 / n + (15 if k % 2 else 0))
            m = weave[2] if k == 1 and i % 2 == 0 else weave[(i + k) % 2]
            b.box(2 * math.pi * r / n * 0.97, 0.045, rh - 0.004, math.cos(a) * r, math.sin(a) * r, 0.02 + k * rh, m,
                  bevel=0.01, rot=(0, 0, math.degrees(a) + 90))
    top = 0.02 + rows * rh
    b.torus(R * 1.04, 0.022, 0, 0, top, weave[0], segs=n, ring=5)                            # rim
    for sx in (-1, 1):                                                                       # loop handles
        with b.at((sx * (R + 0.02), 0, top + 0.03)):
            b.box(0.04, 0.12, 0.03, 0, 0, 0.05, weave[0], bevel=0.01)
            for sy in (-1, 1):
                b.box(0.04, 0.03, 0.08, 0, sy * 0.045, -0.03, weave[0], bevel=0.01)
    b.socket("surface_0", (0, 0, 0.03))
    return done(b, "floor", category="decor", surfaces={"surface_0": [0.3, 0.3]},
                meta={**variants(weave=("tan", "wood_c"), weave_alt=("cream",), weave_accent=("teal", "coral")),
                      "also_surface": True})


def storage_box():
    """Stackable: cream body, teal lid and base band, coral clips and corner caps; top is a support surface."""
    b = Builder("storage_box")
    body, lid, clip = tint("box", "cream"), tint("lid", "teal"), tint("clip", "coral")
    w, d, h = 0.42, 0.34, 0.28
    b.box(w, d, 0.04, 0, 0, 0, lid, bevel=0.012)                                             # base band
    b.box(w - 0.02, d - 0.02, h - 0.1, 0, 0, 0.04, body, bevel=0.015)
    b.box(w + 0.02, d + 0.02, 0.07, 0, 0, h - 0.07, lid, bevel=0.02)                          # lid
    b.box(w - 0.08, d - 0.08, 0.012, 0, 0, h, lid, bevel=0.004)                               # lid inset rim
    b.box(0.1, 0.03, 0.08, 0, -d / 2 - 0.01, h - 0.11, clip, bevel=0.01)                      # front clip
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.05, 0.05, 0.05, sx * (w / 2 - 0.02), sy * (d / 2 - 0.02), 0.0, clip, bevel=0.01)   # corner caps
        b.box(0.02, 0.1, 0.035, sx * (w / 2 - 0.005), 0, h - 0.14, "charcoal", bevel=0.005)  # handle slots
    b.socket("surface_0", (0, 0, h + 0.012))
    b.socket("stack", (0, 0, h + 0.012))
    return done(b, "floor", category="decor", surfaces={"surface_0": [w - 0.08, d - 0.08]},
                meta={**variants(box=("cream", "white"), lid=("teal", "coral", "mustard"), clip=("coral", "teal")),
                      "also_surface": True, "stackable": True,
                      "stack": {"socket": "socket_stack", "accepts": ["storage_box"], "max": 3}})


def lidded_chest():
    """Wooden chest with patchwork front panels, cream corner caps and brass hinges (lid hinges at the back)."""
    b = Builder("lidded_chest")
    wood = tint("finish", "wood")
    w, d, h = 0.8, 0.46, 0.4
    b.box(w, d, h - 0.02, 0, 0, 0, wood, bevel=0.02)
    pw = (w - 0.16) / 3
    for i in range(3):                                                                       # patchwork panels
        b.box(pw - 0.02, 0.02, h - 0.14, -w / 2 + 0.08 + pw * (i + 0.5), -d / 2 - 0.004, 0.06, PATCH[i], bevel=0.006)
    b.box(w - 0.06, 0.03, 0.04, 0, -d / 2, 0.02, "wood_dark", bevel=0.008)                    # kick trim
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.07, 0.07, 0.07, sx * (w / 2 - 0.025), sy * (d / 2 - 0.025), 0, tint("caps", "cream"), bevel=0.012)
        b.box(0.025, 0.08, 0.05, sx * (w / 2 + 0.006), 0, h - 0.16, "wood_dark", bevel=0.006)   # side handles
    hinge_y, hinge_z = d / 2, h
    for sx in (-1, 1):
        b.box(0.08, 0.02, 0.05, sx * 0.22, hinge_y + 0.005, hinge_z - 0.05, "gold", bevel=0.005)
    with b.part("lid", pivot=(0, hinge_y, hinge_z), motion="hinge", axis="x", open_deg=-100):
        b.box(w + 0.02, d + 0.02, 0.09, 0, 0, h - 0.02, wood, bevel=0.02)
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.box(0.075, 0.075, 0.095, sx * (w / 2 - 0.02), sy * (d / 2 - 0.02), h - 0.022, tint("caps", "cream"), bevel=0.012)
            b.box(0.08, 0.02, 0.04, sx * 0.22, hinge_y + 0.015, h + 0.02, "gold", bevel=0.005)
        b.box(0.09, 0.03, 0.08, 0, -d / 2 - 0.012, h - 0.03, "gold", bevel=0.008)            # clasp
    b.socket("use", (0, -d / 2 - 0.35, 0))
    b.socket("surface_0", (0, 0, h + 0.07))
    return done(b, "floor", clearance=1, surfaces={"surface_0": [w - 0.2, d - 0.14]},
                meta={**variants(finish=("wood", "wood_dark"), caps=("cream",)),
                      "hinge_clearance_m": {"above": round(d + 0.04, 2), "behind": 0.12,
                                            "note": "keep free when the lid opens; blocks wall-flush back placement"}})


def fruit_bowl(b):
    """Cream bowl with a teal zig-zag rim band; fruit are separate items on surface_0..2."""
    bowl, zig = tint("bowl", "cream"), tint("bowl_band", "teal")
    n = 12
    b.cyl(0.07, 0.025, 0, 0, 0, zig, segs=n)
    b.cyl(0.08, 0.08, 0, 0, 0.025, bowl, segs=n, r2=0.15, cap=False)
    b.cyl(0.075, 0.006, 0, 0, 0.03, bowl, segs=n)                                             # inner floor
    b.torus(0.15, 0.012, 0, 0, 0.105, bowl, segs=n, ring=4)
    for i in range(n):                                                                        # zig-zag triangles
        a = math.radians(i * 360 / n)
        r = 0.122
        with b.at((math.cos(a) * r, math.sin(a) * r, 0.07), rotz=math.degrees(a) - 90):
            with b.at(rot=(-31, 0, 0)):
                b.prism([(-0.035, 0.022), (0.035, 0.022), (0, -0.02)], 0.004, y=-0.002, mat=zig)
    for i, spot in enumerate(FRUIT_SPOTS):
        b.socket(f"surface_{i}", spot)


FRUIT_SPOTS = ((-0.045, -0.02, 0.035), (0.05, 0.0, 0.035), (0.0, 0.055, 0.035))


def fruit_apple(b):
    b.blob(0.042, 0.042, 0.04, 0, 0, 0.04, tint("fruit", "red"), subdiv=1, jitter=0.002)
    b.cyl(0.004, 0.02, 0, 0, 0.075, "bark", segs=4)
    leaf(b, 0.003, 0, 0.088, 0.03, 0.02, 40, 60, "leaf")


def fruit_pear(b):
    m = tint("fruit", "sage")
    b.blob(0.04, 0.04, 0.038, 0, 0, 0.038, m, subdiv=1, jitter=0.002)
    b.blob(0.026, 0.026, 0.032, 0, 0, 0.088, m, subdiv=1)
    b.cyl(0.004, 0.025, 0, 0, 0.115, "bark", segs=4, rot=(0, 15, 0))


def fruit_orange(b):
    b.blob(0.042, 0.042, 0.04, 0, 0, 0.04, tint("fruit", "orange"), subdiv=2)
    b.cyl(0.006, 0.006, 0, 0, 0.079, "leaf_dark", segs=5)


def cookie_plate(b):
    plate = tint("plate", "white")
    b.cyl(0.08, 0.008, 0, 0, 0, plate, segs=12)
    b.cyl(0.12, 0.012, 0, 0, 0.008, plate, segs=12, r2=0.13)
    for i, (x, y, z, tilt) in enumerate(((-0.04, -0.03, 0.022, 0), (0.045, -0.01, 0.022, 0), (0.0, 0.05, 0.022, 0),
                                         (0.0, 0.0, 0.042, 12))):
        with b.at((x, y, z), rot=(tilt, 0, i * 40)):
            b.cyl(0.04, 0.016, 0, 0, 0, "tan", segs=9, bevel=0.004)
            for k in range(3):
                a = math.radians(k * 120 + 20)
                b.blob(0.008, 0.008, 0.005, math.cos(a) * 0.02, math.sin(a) * 0.02, 0.016, "wood_deep", subdiv=1)


def teapot_set(b):
    glaze = tint("glaze", "teal")
    b.box(0.34, 0.22, 0.02, 0, 0, 0, tint("tray", "wood"), bevel=0.008)
    with b.at((-0.05, 0.01, 0.02)):
        b.blob(0.075, 0.075, 0.065, 0, 0, 0.07, glaze, subdiv=2)
        b.cyl(0.04, 0.02, 0, 0, 0.125, glaze, segs=8)
        b.sphere(0.014, 0, 0, 0.15, glaze, u=6, v=4)
        b.cyl(0.013, 0.09, 0.06, 0, 0.05, glaze, segs=6, r2=0.008, rot=(0, 55, 0))          # spout
        b.torus(0.04, 0.01, -0.075, 0, 0.075, glaze, segs=8, ring=4, rot=(90, 0, 0))         # handle
        b.socket("fx_steam", (0.135, 0, 0.11))
    for i, x in enumerate((0.095, 0.12)):
        y = -0.05 if i == 0 else 0.06
        b.cyl(0.03, 0.008, x, y, 0.02, "white", segs=8)
        b.cyl(0.025, 0.045, x, y, 0.028, glaze, segs=8, r2=0.03)
        b.cyl(0.02, 0.004, x, y, 0.068, "wood_deep", segs=8)


def cushion_square(b):
    """Cream cushion with a coral diamond and teal centre on both faces, coral tassel corners."""
    base, d1, d2 = tint("cushion", "cream"), tint("cushion_accent", "coral"), tint("cushion_centre", "teal")
    with b.at((0, 0, 0.15)):
        b.box(0.32, 0.1, 0.28, 0, 0, 0, base, bevel=0.045, center=True)
        b.box(0.25, 0.135, 0.21, 0, 0, 0, base, bevel=0.04, center=True)
        for sy, rz in ((-1, 0), (1, 180)):
            with b.at((0, sy * 0.069, 0), rotz=rz):
                diamond(b, 0, 0, 0, s=0.09, mat=d1, depth=0.006)
                diamond(b, 0, -0.004, 0, s=0.04, mat=d2, depth=0.006)
        for sx in (-1, 1):
            for sz in (-1, 1):
                b.blob(0.022, 0.022, 0.022, sx * 0.165, 0, sz * 0.145, tint("tassel", "coral"), subdiv=1)


def cushion_round(b):
    """Pouf cushion of alternating teal and cream segments with a coral centre button."""
    segs = (tint("cushion", "teal"), tint("cushion_alt", "cream"))
    n = 8
    for i in range(n):
        a = math.radians(i * 360 / n)
        b.blob(0.13, 0.075, 0.075, math.cos(a) * 0.1, math.sin(a) * 0.1, 0.08, segs[i % 2], subdiv=2,
               rot=(0, 0, math.degrees(a)))
    b.cyl(0.08, 0.1, 0, 0, 0.03, segs[1], segs=n)
    b.cyl(0.04, 0.03, 0, 0, 0.13, tint("button", "coral"), segs=8, bevel=0.01)

# ---------------------------------------------------------------- Home Details & Storage additions
def wall_hook_rail():
    """Wall item: plank with bolts and three J hooks; each hook tip is a socket for hanging items."""
    b = Builder("wall_hook_rail")
    W = 0.72
    b.box(W, 0.035, 0.15, 0, -0.0175, -0.075, tint("finish", "wood"), bevel=0.012)
    for sx in (-1, 1):
        b.cyl(0.016, 0.012, sx * (W / 2 - 0.05), -0.035, 0.0, "iron", segs=6, rot=(90, 0, 0), center=True)
    for i, (x, c) in enumerate(((-0.2, "teal"), (0.0, "cream"), (0.2, "coral"))):
        m = tint(f"hook_{'abc'[i]}", c)
        b.box(0.04, 0.03, 0.06, x, -0.05, -0.05, m, bevel=0.01)                             # mount
        b.box(0.03, 0.09, 0.03, x, -0.1, -0.08, m, bevel=0.01)                              # arm
        b.box(0.03, 0.03, 0.06, x, -0.135, -0.08, m, bevel=0.01)                            # upturned tip
        b.socket(f"hook_{i}", (x, -0.12, -0.03))
    return done(b, "wall", category="decor", rotations=(0,),
                meta={**variants(finish=("wood", "wood_dark"), hook_a=("teal",), hook_b=("cream",), hook_c=("coral",)),
                      "hooks": ["socket_hook_0", "socket_hook_1", "socket_hook_2"]})


def oval_mirror():
    """Wall item: faceted oval honey frame with a stylised mirror insert (no real reflection)."""
    b = Builder("oval_mirror")
    frame = tint("frame", "wood")
    with b.at((0, 0, 0), rot=(90, 0, 0), scale=(1.0, 1.4, 1.0)):
        b.cyl(0.2, 0.05, 0, 0, 0, frame, segs=12, bevel=0.012)
        b.cyl(0.16, 0.012, 0, 0, 0.046, "insert_mirror", segs=12)
    with b.at((-0.04, -0.06, 0.06), rot=(0, 35, 0)):                                         # glint streaks
        b.box(0.022, 0.003, 0.16, 0, 0, 0, "white", bevel=0, center=True)
        b.box(0.012, 0.003, 0.1, 0.05, 0, -0.02, "white", bevel=0, center=True)
    return done(b, "wall", category="decor", rotations=(0,),
                meta={**variants(frame=("wood", "wood_dark", "teal")), "inserts": ["insert_mirror"]})


def entry_mat():
    b = Builder("entry_mat")
    W, D = 0.9, 0.58
    b.box(W, D, 0.02, 0, 0, 0, tint("mat_border", "teal"), bevel=0.008)
    b.box(W - 0.12, D - 0.12, 0.006, 0, 0, 0.02, tint("mat_field", "cream"), bevel=0)
    with b.at((0, 0, 0.026), rot=(-90, 0, 0)):                                               # motif lies flat
        penguin_badge(b, 0, 0, -0.13, 0.26, tint("mat_motif", "teal"), depth=0.004)
    return done(b, "rug", category="decor", meta=variants(mat_border=("teal", "coral"), mat_field=("cream",), mat_motif=("teal", "navy")))


def folded_blanket(b):
    """Folded patchwork blanket: stacked folds with rounded fold ends (fits a shelf, chest or bed end)."""
    w, d, t = 0.42, 0.3, 0.05
    for k in range(3):
        z = k * t
        for j in range(3):
            b.box(w / 3 - 0.004, d, t - 0.004, -w / 2 + w / 3 * (j + 0.5), 0, z, pick(PATCH, j + k), bevel=0.014)
        side = 1 if k % 2 else -1
        b.cyl(t / 2, d, side * w / 2, -d / 2, z + t / 2, pick(PATCH, k), segs=6, rot=(-90, 0, 0))  # fold roll


def book_upright(b):
    m = tint("cover", "teal")
    b.box(0.04, 0.15, 0.21, 0, 0, 0, m, bevel=0.006)
    b.box(0.032, 0.14, 0.2, 0.004, 0.004, 0.005, "cream", bevel=0)
    for z in (0.04, 0.17):
        b.box(0.042, 0.02, 0.012, 0, -0.07, z, "gold", bevel=0)


def bookend(b, side):
    """One penguin-silhouette bookend; side=-1 is the left one, facing inward along X."""
    base = tint("finish", "wood")
    b.box(0.13, 0.15, 0.03, 0, 0, 0, base, bevel=0.008)
    with b.at((side * 0.02, 0, 0.03)):              # chunky figurine facing front, flat side against the books
        penguin_badge(b, 0, 0, 0, 0.2, tint("body", "navy"), "belly", depth=0.06)
        b.cyl(0.012, 0.022, 0, -0.03, 0.155, "beak", segs=5, r2=0.0, rot=(90, 0, 0))
        for sx in (-1, 1):
            b.sphere(0.008, sx * 0.022, -0.031, 0.172, "eye", u=5, v=3)


def small_vase(b):
    """Faceted cream vase with a teal zig-zag band; surface socket 'stems' takes the flower stems item."""
    v, z = tint("vase", "cream"), tint("vase_band", "teal")
    b.cyl(0.04, 0.03, 0, 0, 0, v, segs=8, r2=0.055)
    b.cyl(0.055, 0.05, 0, 0, 0.03, z, segs=8, r2=0.05)
    b.cyl(0.05, 0.05, 0, 0, 0.08, v, segs=8, r2=0.03)
    b.cyl(0.03, 0.03, 0, 0, 0.13, v, segs=8, r2=0.035)
    for i in range(8):                                                                       # zig-zag cream teeth
        a = math.radians(i * 45 + 22.5)
        with b.at((math.cos(a) * 0.054, math.sin(a) * 0.054, 0.052), rotz=math.degrees(a) - 90):
            b.prism([(-0.02, -0.022), (0.02, -0.022), (0, 0.022)], 0.003, mat=v)
    b.socket("stems", (0, 0, 0.16))


def flower_stems(b):
    for i, (yaw, tilt, h) in enumerate(((0, 12, 0.18), (120, 18, 0.15), (240, 10, 0.2))):
        with b.at(rot=(tilt, 0, yaw)):
            b.cyl(0.004, h, 0, 0, 0, "leaf_dark", segs=4)
            flower(b, 0, 0, h, tint("petal", "coral"), "petal_yellow", size=0.03)
            leaf(b, 0, 0, h * 0.5, 0.04, 0.025, 90, 50, "leaf")


THROW_FITS = {
    # profiles (u, z) traced 2 cm above each furniture's arm/blanket, see armchair/sofa/bed builders
    "armchair": dict(prof=[(-0.12, 0.43), (-0.23, 0.45), (-0.27, 0.575), (-0.33, 0.6), (-0.4, 0.585),
                           (-0.455, 0.52), (-0.465, 0.3)], y0=-0.34, y1=0.04, axis="x"),
    "sofa_2seat": dict(prof=[(-0.32, 0.43), (-0.5, 0.45), (-0.545, 0.585), (-0.62, 0.605), (-0.7, 0.59),
                             (-0.755, 0.52), (-0.765, 0.3)], y0=-0.36, y1=0.0, axis="x"),
    "bed": dict(prof=[(-0.53, 0.22), (-0.505, 0.4), (-0.465, 0.45), (0.465, 0.45), (0.505, 0.4), (0.53, 0.22)],
                y0=-0.56, y1=-0.18, axis="x"),
}


def patchwork_throw(fits):
    b = Builder(f"patchwork_throw_{fits}")
    f = THROW_FITS[fits]
    draped(b, f["prof"], f["y0"], f["y1"], cols=3, axis=f["axis"])
    return done(b, "surface", category="decor", footprint=None,
                meta={"fits": fits, "attach": "furniture origin (place with the same transform as the fitted asset)",
                      **variants(patch_a=("coral",), patch_b=("cream",), patch_c=("teal",))})


def build():
    armchair()
    sofa()
    low_table()
    cube_shelf()
    bed()
    writing_desk()
    desk_stool()
    floor_lamp()
    flower_box()
    arcade_home()
    aquarium()
    for kind in ("large", "small", "topiary", "broadleaf", "snake", "cactus", "flowerpot"):
        b = Builder(f"plant_{kind}")
        plant(b, kind)
        done(b, "floor", category="decor", meta={"also_surface": kind in ("small", "cactus", "flowerpot")})
    b = Builder("plant_hanging")
    plant(b, "hanging")
    done(b, "ceiling", category="decor")
    rug_round()
    rug_patchwork()
    rug_round_plain()
    wall_poster()
    for style in ("thin", "matted", "bold"):
        poster(f"poster_frame_{style}", style)
    wall_shelf()
    star_mobile()
    window_curtains()
    wall_clock()
    wall_hook_rail()
    oval_mirror()
    entry_mat()
    for fits in THROW_FITS:
        patchwork_throw(fits)
    woven_basket()
    storage_box()
    lidded_chest()
    for name, fn in (("book_single", book_single), ("book_stack", book_stack), ("mug", mug), ("cushion_square", cushion_square),
                     ("cushion_round", cushion_round), ("cookie_plate", cookie_plate),
                     ("fruit_apple", fruit_apple), ("fruit_pear", fruit_pear), ("fruit_orange", fruit_orange),
                     ("book_upright", book_upright), ("flower_stems", flower_stems),
                     ("teapot_set", teapot_set),
                     ("framed_photo", framed_photo), ("tabletop_plant", tabletop_plant), ("candle", candle),
                     ("small_lantern", small_lantern), ("trophy", trophy), ("plush_penguin", plush_penguin),
                     ("pencil_cup", pencil_cup)):
        small(name, fn)
    small("fruit_bowl", fruit_bowl, surfaces={f"surface_{i}": [0.09, 0.09] for i in range(3)})
    small("folded_blanket", folded_blanket, meta={"also_floor": True}, footprint=None)
    small("small_vase", small_vase, meta={"holds": {"socket_stems": ["flower_stems"]}})
    small("bookend_left", lambda b: bookend(b, -1), meta={"pair": "bookend_right", "books_between": True})
    small("bookend_right", lambda b: bookend(b, 1), meta={"pair": "bookend_left", "books_between": True})
