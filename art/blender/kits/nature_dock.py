"""Nature & dock kit (concept 06 Nature and Dock Kit, 17 Fishing Dock, World Map).
Plaza/dock deck top is z=0. Water surface is WATER_Z (-0.5).
Docks run along Y and extend out toward -Y (the water). A straight module carries posts only at its
far (-Y) end, so modules chain without doubled posts. The plaza edge supports the land end."""
from common import *
from kits.town_connections import SEAM
from kits.plaza import leafy, edge_run, flutter_bunting, WATER_Z, LEAVES, PETAL_VARIANTS, FLAG_VARIANTS

KIT = "nature_dock"
PREVIEW_WIDTH = 13.0
FLOWERS = (tint("petal", "petal_white"), tint("petal_b", "petal_red"))
FLOWER_VARIANTS = {"color_variants": {"petal": PETAL_VARIANTS, "petal_b": PETAL_VARIANTS}}


# ---- trees --------------------------------------------------------------------------
def trunk(b, h, r0, r1, lean=(0, 0), seed=0):
    b.cyl(r0, h, 0, 0, 0, "bark", segs=6, r2=r1, rot=(lean[0], lean[1], 0))
    b.cyl(r0 * 1.55, 0.28, 0, 0, 0, "bark", segs=6, r2=r0 * 0.98, rot=(0, 0, 30 * seed))   # flared base


def branch(b, x0, z0, length, ang, az, r=0.07):
    with b.at((x0, 0, z0), rot=(0, ang, az)):
        b.cyl(r, length, 0, 0, 0, "bark", segs=5, r2=r * 0.6)


def canopy(b, blobs, snow=False, seed=0):
    """blobs: (x, y, z, r). Faceted icosphere masses, lighter on top; optional snow caps."""
    rng = random.Random(seed)
    for i, (x, y, z, r) in enumerate(blobs):
        m = "leaf_b" if z > max(bz for _, _, bz, _ in blobs) - 0.2 else pick(("leaf", "leaf_dark", "leaf"), i)
        b.blob(r, r * 0.97, r * 0.92, x, y, z, m, subdiv=1, jitter=r * 0.06, rot=(0, 0, rng.uniform(0, 70)))
        if snow:
            b.blob(r * 0.86, r * 0.84, r * 0.3, x, y, z + r * 0.62, "snow", subdiv=2, jitter=r * 0.03,
                   rot=(0, 0, rng.uniform(0, 70)))


def ring_bed(b, R, flowers=FLOWERS, seed=0):
    rng = random.Random(seed)
    n = 12
    side = 2 * R * math.tan(math.pi / n)
    for i in range(n):
        a = 2 * math.pi * i / n
        b.box(side * 0.96, 0.24, 0.24, (R - 0.12) * math.cos(a), (R - 0.12) * math.sin(a), 0,
              pick(("stone", "paving_b", "stone_dark"), i), bevel=0.035, rot=(0, 0, math.degrees(a) + 90))
    b.cyl(R - 0.2, 0.17, 0, 0, 0, "soil", segs=12)
    for i in range(7):
        a = 2 * math.pi * i / 7 + rng.uniform(-0.2, 0.2)
        rr = (R - 0.2) * rng.uniform(0.55, 0.75)
        leafy(b, rr * math.cos(a), rr * math.sin(a), 0.15, r=rng.uniform(0.15, 0.2), n=6, seed=seed + i)
    for i in range(6):
        a = 2 * math.pi * (i + 0.5) / 6
        rr = (R - 0.2) * rng.uniform(0.5, 0.8)
        flower(b, rr * math.cos(a), rr * math.sin(a), 0.3 + rng.uniform(0, 0.05), pick(flowers, i), size=0.085)


def broad_tree(name, snow=False, bed=False):
    b = Builder(name, seed=101)
    if bed:
        ring_bed(b, 1.05, seed=3)
    trunk(b, 1.9, 0.22, 0.13, seed=1)
    branch(b, 0, 1.1, 0.8, -42, 0)
    branch(b, 0, 1.25, 0.75, 40, 20)
    with b.part("crown", pivot=(0, 0, 1.6), motion="sway", amp_deg=2.0):  # trunk static, snow rides the crown
        canopy(b, [(0, 0, 2.55, 0.78), (-0.68, 0.12, 2.15, 0.62), (0.7, -0.1, 2.2, 0.66), (0.12, 0.62, 2.3, 0.6),
                   (-0.2, -0.58, 2.1, 0.56), (0.32, 0.22, 2.95, 0.52), (-0.4, -0.1, 2.85, 0.48)], snow, seed=5)
    if bed:
        b.socket("sit_rim_0", (0, -1.05, 0.24), 0)
    return b.finish(KIT, "nature", {"collision_radius": 0.3 if not bed else 1.05, **(FLOWER_VARIANTS if bed else {})})


def small_tree(name, snow=False, bed=False):
    b = Builder(name, seed=102)
    if bed:
        ring_bed(b, 0.78, seed=7)
    trunk(b, 1.35, 0.15, 0.09, seed=2)
    branch(b, 0, 0.85, 0.5, 38, -30, r=0.05)
    with b.part("crown", pivot=(0, 0, 1.2), motion="sway", amp_deg=2.5):
        canopy(b, [(0, 0, 1.85, 0.56), (-0.42, 0.05, 1.6, 0.44), (0.4, -0.08, 1.62, 0.46), (0.05, 0.4, 1.66, 0.42),
                   (0.12, -0.05, 2.22, 0.38)], snow, seed=9)
    return b.finish(KIT, "nature", {"collision_radius": 0.2 if not bed else 0.78, **(FLOWER_VARIANTS if bed else {})})


# ---- shrubs, flowers ------------------------------------------------------------------
def shrub(name, blobs, flowers=None, seed=0):
    """First blob is the rooted core (static); the rest and the flowers sway as part 'top'."""
    b = Builder(name, seed=110 + seed)
    rng = random.Random(seed)
    x0, y0, z0, r0 = blobs[0]
    b.blob(r0, r0, r0 * 0.85, x0, y0, z0, pick(LEAVES, seed), subdiv=1, jitter=r0 * 0.06)
    with b.part("top", pivot=(x0, y0, 0.08), motion="sway", amp_deg=3.0):
        for i, (x, y, z, r) in enumerate(blobs[1:], 1):
            b.blob(r, r, r * 0.85, x, y, z, pick(LEAVES, i + seed), subdiv=1, jitter=r * 0.06)
        for i in range(7 if flowers else 0):
            x, y, z, r = blobs[i % len(blobs)]
            a_ = rng.uniform(0, 2 * math.pi)
            rr = r * rng.uniform(0.3, 0.7)
            fz = z + math.sqrt(max(0, r * r - rr * rr)) * 0.85
            flower(b, x + rr * math.cos(a_), y + rr * math.sin(a_), fz, pick(flowers, i), size=0.08)
    return b.finish(KIT, "nature", FLOWER_VARIANTS if flowers else None)


def flower_stem(name, petal, leaves=2, seed=0):
    b = Builder(name, seed=120 + seed)
    b.cyl(0.015, 0.32, 0, 0, 0, "leaf_dark", segs=5)
    for i in range(leaves):
        a = 120 * i + 30
        with b.at((0, 0, 0.06 + 0.07 * i), rot=(0, -35, a)):
            b.blob(0.11, 0.045, 0.012, 0.09, 0, 0, pick(("leaf", "leaf_b"), i))
    flower(b, 0, 0, 0.33, tint("petal", petal), size=0.1)
    return b.finish(KIT, "nature", {"color_variants": {"petal": PETAL_VARIANTS}})


def leaf_tuft(name, n=7, seed=0, r=0.16):
    b = Builder(name, seed=130 + seed)
    leafy(b, 0, 0, 0.0, r=r, n=n, seed=seed, tilt=40)
    return b.finish(KIT, "nature")


def flower_clump(name, seed=0):
    b = Builder(name, seed=140 + seed)
    rng = random.Random(seed)
    leafy(b, 0, 0, 0.0, r=0.2, n=8, seed=seed, tilt=30)
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
        flower(b, 0.1 * math.cos(a), 0.1 * math.sin(a), 0.18 + rng.uniform(0, 0.05), pick(FLOWERS, i), size=0.08)
    return b.finish(KIT, "nature", FLOWER_VARIANTS)


# ---- rocks ------------------------------------------------------------------------------
def rocks(name, parts, snow=False, seed=0):
    """parts: (x, y, rx, ry, rz). Faceted boulders sunk slightly into the ground."""
    b = Builder(name, seed=150 + seed)
    rng = random.Random(seed)
    for i, (x, y, rx, ry, rz) in enumerate(parts):
        rot = (rng.uniform(-8, 8), rng.uniform(-8, 8), rng.uniform(0, 90))
        b.blob(rx, ry, rz, x, y, rz * 0.72, pick(("rock", "rock_b", "rock"), i), subdiv=1, jitter=min(rx, rz) * 0.1, rot=rot)
        if snow:
            b.blob(rx * 0.86, ry * 0.84, rz * 0.4, x, y, rz * 0.72 + rz * 0.55, "snow", subdiv=2, jitter=rz * 0.03, rot=rot)
    return b.finish(KIT, "nature", {"collision": "convex"})


ROCK_LARGE = [(0, 0.05, 0.72, 0.62, 0.62), (0.75, -0.2, 0.42, 0.38, 0.38), (0.35, -0.6, 0.3, 0.28, 0.24), (-0.6, -0.45, 0.24, 0.22, 0.2)]
ROCK_SMALL_A = [(0, 0, 0.32, 0.28, 0.26), (0.38, -0.12, 0.2, 0.18, 0.16)]
ROCK_SMALL_B = [(0, 0, 0.26, 0.24, 0.22), (0.3, 0.1, 0.18, 0.16, 0.15), (0.12, -0.28, 0.15, 0.14, 0.12)]


# ---- docks ----------------------------------------------------------------------------
def dock_post(b, x, y, top=0.4, w=0.2):
    b.box(w, w, top - WATER_Z + 0.7, x, y, WATER_Z - 0.7, "wood_b", bevel=0.03)
    b.box(w * 0.8, w * 0.8, 0.05, x, y, top, "wood_dark", bevel=0.015)


def deck(b, w, d, x=0, y=0, along="x", plank=0.25):
    """Planked deck surface (top at z=0) with stringers underneath."""
    planks(b, w, d, z=-0.09, plank=plank, thick=0.09, along=along, x=x, y=y, mats=("wood", "wood_c", "wood_b", "wood"))
    if along == "x":
        for sx in (-1, 1):
            b.box(0.14, d, 0.16, x + sx * (w / 2 - 0.3), y, -0.25, "wood_dark", bevel=0.015)
    else:
        for sy in (-1, 1):
            b.box(w, 0.14, 0.16, x, y + sy * (d / 2 - 0.3), -0.25, "wood_dark", bevel=0.015)


def stand_sockets(b, pts, prefix="stand"):
    for i, (x, y) in enumerate(pts):
        b.socket(f"{prefix}_{i}", (x, y, 0), 0)


def dock_straight(name="dock_straight", fish=0, kit=KIT):
    b = Builder(name, seed=160 + fish)
    W = D = 2.0
    deck(b, W, D)
    b.box(W, 0.14, 0.18, 0, -D / 2 + 0.07, -0.27, "wood_dark", bevel=0.015)       # end beam
    for sx in (-1, 1):
        dock_post(b, sx * (W / 2 - 0.1), -D / 2 + 0.1)
    stand_sockets(b, [(-0.45, 0.45), (0.45, 0.45), (-0.45, -0.3), (0.45, -0.3)])
    meta = {"module": "dock", "grid": 2.0, "deck_z": 0.0, "water_z": WATER_Z, "connects": ["+Y", "-Y"]}
    if fish:
        # seated fishing positions at the open side edges, facing out over the water
        for i, y in enumerate((-0.5, 0.45)[:fish // 2 or 1]):
            b.socket(f"fish_{2 * i}", (-W / 2 + 0.12, y, 0.0), -90)
            b.socket(f"fish_{2 * i + 1}", (W / 2 - 0.12, y, 0.0), 90)
        meta["fishing_spots"] = fish
    return b.finish(kit, "modular", meta)


def dock_corner():
    b = Builder("dock_corner", seed=170)
    W = 2.0
    deck(b, W, 1.0, 0, 0.5, along="x")                  # incoming half: travel along Y
    deck(b, W, 1.0, 0, -0.5, along="y")                 # turning half: travel along +X
    b.box(W, 0.14, 0.18, 0, -W / 2 + 0.07, -0.27, "wood_dark", bevel=0.015)
    b.box(0.14, W, 0.18, -W / 2 + 0.07, 0, -0.27, "wood_dark", bevel=0.015)
    for x, y in ((-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9)):
        dock_post(b, x, y)
    stand_sockets(b, [(-0.4, 0.4), (0.4, 0.4), (-0.4, -0.4), (0.4, -0.4)])
    return b.finish(KIT, "modular", {"module": "dock", "grid": 2.0, "connects": ["+Y", "+X"], "water_z": WATER_Z})


def dock_stairs():
    """Steps from deck level (z=0, +Y edge) down to a landing just above the water, toward -Y."""
    b = Builder("dock_stairs", seed=180)
    W, n, drop = 1.2, 3, 0.42
    run = 0.32
    for i in range(n):
        z = -drop * (i + 1) / (n + 0.5)
        b.box(W - 0.16, run - 0.03, 0.07, 0, -run * (i + 0.5), z, pick(("wood", "wood_c", "wood_b"), i), bevel=0.014)
    ang = math.degrees(math.atan2(drop, run * n))
    L = math.hypot(drop, run * n) - 0.08  # ends stay inside the top and bottom posts
    for sx in (-1, 1):
        b.box(0.08, L, 0.2, sx * (W / 2 - 0.04), -run * n / 2, -drop / 2 - 0.12, "wood_dark", bevel=0.015, rot=(ang, 0, 0), center=True)
        post(b, sx * (W / 2 - 0.04), -0.06, -0.3, h=0.75, w=0.16, mat="wood_b")
        dock_post(b, sx * (W / 2 - 0.04), -run * n - 0.05, top=-0.05, w=0.16)
    b.socket("top", (0, 0, 0))
    b.socket("bottom", (0, -run * n, -drop * n / (n + 0.5)))
    return b.finish(KIT, "modular", {"module": "dock_stairs", "width": W, "drop": drop})


def rope_posts(name, flags=False):
    b = Builder(name, seed=190 + flags)
    span = 1.8
    for sx in (-1, 1):
        x = sx * span / 2
        post(b, x, 0, 0, h=0.95, w=0.17, mat="wood_b")
        b.torus(0.105, 0.03, x, 0, 0.72, "rope", segs=10, ring=5)
        b.torus(0.105, 0.03, x, 0, 0.66, "rope", segs=10, ring=5)
    p0, p1 = (-span / 2 + 0.1, 0, 0.7), (span / 2 - 0.1, 0, 0.7)
    if flags:
        flutter_bunting(b, p0, p1, n=3, colors=(tint("flag_a", "coral"), tint("flag_c", "cream"), tint("flag_b", "teal_light")),
                        size=0.2, sag=0.16, rope_r=0.024)
    else:
        rope_between(b, p0, p1, sag=0.2, r=0.028, segs=8)
    return b.finish(KIT, "modular", {"module": "rope_rail", "span": span, **({"color_variants": FLAG_VARIANTS} if flags else {})})


# ---- water --------------------------------------------------------------------------------
def water_surface(b, w, d, x=0, y=0, n=5, seed=0, z=WATER_Z):
    """Faceted water: a jittered triangle grid with a few deeper-tone facets."""
    rng = random.Random(seed)
    verts, idx = [], {}
    for i in range(n + 1):
        for j in range(n + 1):
            edge = i in (0, n) or j in (0, n)
            jx = 0 if edge else rng.uniform(-0.08, 0.08) * w / n
            jy = 0 if edge else rng.uniform(-0.08, 0.08) * d / n
            idx[i, j] = len(verts)
            verts.append((x - w / 2 + w * i / n + jx, y - d / 2 + d * j / n + jy, z + (0 if edge else rng.uniform(-0.003, 0.003))))
    tris = {"water": [], "water_deep": []}
    for i in range(n):
        for j in range(n):
            a, c, e, f = idx[i, j], idx[i + 1, j], idx[i + 1, j + 1], idx[i, j + 1]
            for t in ((a, c, e), (a, e, f)):
                tris["water_deep" if rng.random() < 0.22 else "water"].append(t)
    for m, faces in tris.items():
        if faces:
            used = sorted({k for t in faces for k in t})
            remap = {k: n_ for n_, k in enumerate(used)}
            b.mesh([verts[k] for k in used], [tuple(remap[k] for k in t) for t in faces], mat=m)


def water_tile():
    b = Builder("water_tile_2x2", seed=200)
    water_surface(b, 2.0, 2.0, seed=1)
    return b.finish(KIT, "modular", {"module": "water", "grid": 2.0, "surface_z": WATER_Z})


def foam_strip(b, x0, x1, rng, y=-0.21, n=12):
    """Irregular shoreline foam lying on the water along a wall face at y, spreading toward -Y."""
    z = WATER_Z + 0.025  # clears the waterline ledge of the lowest stone course
    verts, faces = [], []
    for i in range(n + 1):
        t = i / n
        w = rng.uniform(0.05, 0.13) * min(1.0, 4 * t, 4 * (1 - t)) + 0.02
        x = x0 + (x1 - x0) * t
        verts += [(x, y, z), (x, y - w, z)]
    for i in range(n):
        faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    b.mesh(verts, faces, mat="snow")


def water_edge(name, corner=False):
    b = Builder(name, seed=210 + corner)
    rng = random.Random(21 + corner)
    edge_run(b, 2.0, rng)
    water_surface(b, 2.0, 1.25, 0, -0.875, n=4, seed=3)
    if corner:
        with b.at((0.75, 1.0 + 0.14, 0), rotz=90):  # starts past run 1's coping so blocks don't interpenetrate
            edge_run(b, 2.0 - 0.28, rng)
        water_surface(b, 1.25, 2.25, 1.625, 0.875, n=4, seed=4)
        water_surface(b, 1.25, 1.25, 1.625, -0.875, n=3, seed=5)
    with b.part("foam", pivot=(0, -0.25, WATER_Z), motion="flow"):  # shoreline foam, shader-driven
        foam_strip(b, -1.0, 1.0 if not corner else 0.98, rng)
        if corner:
            with b.at((0.98 + 0.21, 0, 0), rotz=90):  # along the +X-facing wall, spreading toward +X
                foam_strip(b, -0.21, 2.0, rng)
    return b.finish(KIT, "modular", {"module": "water_edge", "length": 2.0, "corner": corner,
                                    "water_z": WATER_Z, "water_side": "-Y" if not corner else "-Y,+X"})


# ---- shoreline (concept: World Kit - Shoreline and Waterfront Details) ------------------------
# Every bank module is a heightfield of one shared profile h(d), where d is the signed distance from
# the shoreline crest (land > 0, water < 0). Straights and corners therefore have identical edge
# heights wherever they meet on the 2 m seam grid. Land top z=0, water WATER_Z, bed -0.85.
SHORE_N = 16                                    # 0.125 m grid
SHORE_PROFILE = [(-0.6, -0.85), (-0.2, -0.58), (0.35, -0.32), (0.7, 0.0)]   # (d, z)
SAND = tint("shore_sand", "#E6D3AA")  # pale winter sand, like the sheet
SHORE_ROCK = (tint("cliff_rock", "rock"), tint("cliff_rock_b", "rock_b"))   # shared with town_connections cliffs
FOAM_Z = WATER_Z + 0.004


def shore_h(d):
    P = SHORE_PROFILE
    if d <= P[0][0]:
        return P[0][1]
    for (d0, z0), (d1, z1) in zip(P, P[1:]):
        if d <= d1:
            return z0 + (z1 - z0) * (d - d0) / (d1 - d0)
    return P[-1][1]


def d_straight(x, y):                       # land +Y, water -Y; seams W and E
    return y + 0.1


def d_outer(x, y):                          # convex land quadrant x<=0.1, y>=-0.1; seams W and N
    a, c = y + 0.1, 0.1 - x
    return -math.hypot(a, c) if a < 0 and c < 0 else min(a, c)


def d_inner(x, y):                          # concave: water quadrant x>=0.1, y<=-0.1; seams S and E
    a, c = x - 0.1, -0.1 - y
    return math.hypot(a, c) if a < 0 and c < 0 else -min(a, c)


SHORE_TYPES = {  # name: (distance fn, seams, foam centre-line polyline with water on its right)
    "straight": (d_straight, "we", [(-1 + 0.25 * i, -0.14) for i in range(9)]),
    "outer": (d_outer, "wn", [(-1 + 0.22 * i, -0.14) for i in range(6)] +
              [(0.1 + 0.04 * math.sin(math.radians(a)), -0.1 - 0.04 * math.cos(math.radians(a))) for a in (30, 60)] +
              [(0.14, -0.1 + 1.1 * i / 5) for i in range(6)]),
    "inner": (d_inner, "se", [(0.14, -1 + 0.86 * i / 4) for i in range(5)] + [(0.14 + 0.86 * i / 4, -0.14) for i in range(1, 5)]),
}
SEAM_SOCKETS = {"w": ((-1, 0, 0), 90), "e": ((1, 0, 0), -90), "n": ((0, 1, 0), 180), "s": ((0, -1, WATER_Z), 0)}


def grid_mesh(b, zf, keep, matf, n=SHORE_N):
    """Triangulated heightfield over the 2x2 module. zf(x, y, interior) -> z; keep(tri) and
    matf(tri) take the triangle's three (x, y, z) points."""
    pts = {}
    for i in range(n + 1):
        for j in range(n + 1):
            x, y = -1 + 2 * i / n, -1 + 2 * j / n
            pts[i, j] = (x, y, zf(x, y, 0 < i < n and 0 < j < n))
    groups = {}
    for i in range(n):
        for j in range(n):
            a, c, e, f = pts[i, j], pts[i + 1, j], pts[i + 1, j + 1], pts[i, j + 1]
            for t in ((a, c, e), (a, e, f)) if (i + j) % 2 else ((a, c, f), (c, e, f)):
                if keep(t):
                    groups.setdefault(matf(t), []).append(t)
    for m, tris in groups.items():
        b.mesh([v for t in tris for v in t], [(3 * k, 3 * k + 1, 3 * k + 2) for k in range(len(tris))], mat=m)
    return pts


def shore_blobs(dfun, seed):
    """Boulders along the rock face (d about 0.5), kept clear of the seams."""
    rng = random.Random(seed)
    out = []
    for _ in range(600):  # bounded: a short boulder line may only fit 3-4
        if len(out) == 5:
            break
        x, y = rng.uniform(-0.75, 0.75), rng.uniform(-0.75, 0.75)
        d = dfun(x, y)
        if abs(d - 0.52) < 0.08 and all(math.hypot(x - o[0], y - o[1]) > 0.34 for o in out):
            r = rng.uniform(0.17, 0.26)
            out.append((x, y, shore_h(d) + r * 0.25, r))
    return out


def shore_bank(kind):
    dfun, seams, foam = SHORE_TYPES[kind]
    name = {"straight": "shore_bank_sloped", "outer": "shore_outer_corner", "inner": "shore_inner_corner"}[kind]
    b = Builder(name, seed=500 + len(kind))
    rng = random.Random(len(kind))

    def zf(x, y, interior):
        d = dfun(x, y)
        j = rng.uniform(-0.02, 0.02) if interior and -0.55 < d < 0.66 else 0.0  # land top and seams stay exact
        return shore_h(d) + j

    def matf(t):
        d = sum(dfun(p[0], p[1]) for p in t) / 3
        return pick(SHORE_ROCK, int((t[0][0] + t[0][1]) * 8)) if d > 0.42 else SAND if d > -0.22 else "stone_dark"
    pts = grid_mesh(b, zf, lambda t: True, matf)
    # skirts close the solid on all four sides down to the bed
    n, bot = SHORE_N, -0.95
    for edge, out in ((lambda k: (k, 0), (0, -1, 0)), (lambda k: (n, k), (1, 0, 0)), (lambda k: (n - k, n), (0, 1, 0)), (lambda k: (0, n - k), (-1, 0, 0))):
        for k in range(n):
            p, q = pts[edge(k)], pts[edge(k + 1)]
            quad = [p, q, (q[0], q[1], bot), (p[0], p[1], bot)]
            nrm = (Vector(quad[1]) - Vector(quad[0])).cross(Vector(quad[2]) - Vector(quad[0]))
            b.mesh(quad, [(0, 1, 2, 3)] if nrm.dot(Vector(out)) > 0 else [(0, 3, 2, 1)], mat="rock_b")
    for x, y, z, r in shore_blobs(dfun, 7 + len(kind)):
        b.blob(r * 1.2, r, r * 0.85, x, y, z, pick(SHORE_ROCK, int(r * 100)), subdiv=1, jitter=r * 0.08)
    # water: only cells that are actually below the surface somewhere, edges flat for tiling
    with b.part("water", pivot=(0, 0, WATER_Z), motion="flow"):
        wr = random.Random(3)
        grid_mesh(b, lambda x, y, interior: WATER_Z + (wr.uniform(-0.003, 0.003) if interior else 0.0),
                  lambda t: min(shore_h(dfun(p[0], p[1])) for p in t) < WATER_Z + 0.03,
                  lambda t: "water_deep" if wr.random() < 0.2 else "water", n=8)
    with b.part("foam", pivot=(0, 0, FOAM_Z), motion="flow"):
        foam_line(b, foam)
    for sd in seams:
        loc, rz = SEAM_SOCKETS[sd]
        b.socket(f"seam_{sd}", loc, rz)
    return b.finish(KIT, "modular", {"seam_grid": SEAM, "module": "shore", "shore_type": kind, "seams": list(seams),
                                     "water_z": WATER_Z, "land_top_z": 0.0, "snow_overlay": f"snow_overlay_{name}",
                                     "walkable": "land top only (d >= 0.7); sand and water are not traversable by default"})


def foam_w(x, y):
    """Foam width from world-periodic terms, so every seam (x or y = +-1) gets the same width."""
    return 0.085 + 0.025 * math.sin(2 * math.pi * x) * math.cos(math.pi * y / 2) + 0.018 * math.sin(5 * math.pi * y) * math.cos(math.pi * x / 2)


def foam_line(b, line, z=FOAM_Z):
    """Thin foam ribbon: inner edge on the polyline, spreading to its right (the water side)."""
    verts, faces = [], []
    for i, p in enumerate(line):
        a = Vector(line[max(0, i - 1)]); c = Vector(line[min(len(line) - 1, i + 1)])
        t = (c - a).normalized()
        nrm = Vector((t.y, -t.x))                      # right-hand side of travel
        w = foam_w(*p)
        verts += [(p[0], p[1], z), (p[0] + nrm.x * w, p[1] + nrm.y * w, z)]
    for i in range(len(line) - 1):
        faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    b.mesh(verts, faces, mat="white")


def snow_overlay_shore(kind):
    dfun, _, _ = SHORE_TYPES[kind]
    base = {"straight": "shore_bank_sloped", "outer": "shore_outer_corner", "inner": "shore_inner_corner"}[kind]
    b = Builder(f"snow_overlay_{base}", seed=520 + len(kind))
    rng = random.Random(40 + len(kind))
    thick = lambda d: 0.05 * min(1.0, max(0.0, (d - 0.6) / 0.2)) - 0.012   # tucks under the rock at its edge

    def zf(x, y, interior):
        d = dfun(x, y)
        return shore_h(d) + thick(d) + (rng.uniform(-0.006, 0.006) if interior and thick(d) > 0 else 0.0)
    grid_mesh(b, zf, lambda t: any(thick(dfun(p[0], p[1])) > 0 for p in t), lambda t: "snow")
    for x, y, z, r in shore_blobs(dfun, 7 + len(kind)):
        b.blob(r * 1.02, r * 0.85, r * 0.34, x, y, z + r * 0.62, "snow", subdiv=2, jitter=r * 0.03)
    return b.finish(KIT, "overlay", {"seam_grid": SEAM, "overlay_for": base, "layer": "snow"})


def pebble_cluster(name, snow=False):
    b = Builder(name, seed=530 + snow)
    rng = random.Random(53)
    big = [(0.0, 0.05, 0.3, 0.26, 0.24), (0.34, -0.12, 0.17, 0.15, 0.14), (-0.3, -0.14, 0.15, 0.13, 0.12)]
    small = [(rng.uniform(-0.6, 0.6), rng.uniform(-0.4, 0.4), r, r * 0.9, r * 0.7) for r in [rng.uniform(0.04, 0.08) for _ in range(9)]]
    for i, (x, y, rx, ry, rz) in enumerate(big + small):
        if any(math.hypot(x - bx, y - by) < bx_r + rx for bx, by, bx_r, _, _ in big if (bx, by) != (x, y)) and i >= len(big):
            continue
        rot = (rng.uniform(-8, 8), rng.uniform(-8, 8), rng.uniform(0, 90))
        b.blob(rx, ry, rz, x, y, rz * 0.7, pick(("rock", "rock_b", "rock_grey"), i), subdiv=1, jitter=min(rx, rz) * 0.1, rot=rot)
        if snow and rx > 0.1:
            b.blob(rx * 0.85, ry * 0.82, rz * 0.4, x, y, rz * 0.7 + rz * 0.55, "snow", subdiv=2, jitter=rz * 0.03, rot=rot)
    return b.finish(KIT, "nature", {"collision": "none (decor)"})


def shallow_water_patch():
    """A 2 m water module (replaces a water_tile_2x2) with a lighter shallow centre over a sandy bed
    and stones; only the water is a flow part. Edges sit exactly at WATER_Z so it tiles."""
    b = Builder("shallow_water_patch", seed=540)
    rng = random.Random(54)
    b.box(2.0, 2.0, 0.04, 0, 0, WATER_Z - 0.32, SAND, bevel=0)                         # bed
    for i, (x, y, r, top) in enumerate([(-0.5, 0.35, 0.22, -0.03), (0.42, -0.3, 0.18, 0.012), (0.1, 0.55, 0.12, -0.06),
                                        (-0.2, -0.45, 0.14, -0.05), (0.6, 0.4, 0.1, 0.015), (-0.65, -0.2, 0.08, -0.08)]):
        zc = WATER_Z + top - r * 0.45                                                   # some break the surface, most sit below
        b.blob(r * 1.3, r * 1.05, r * 0.45, x, y, zc, pick(("rock_grey", "stone_dark", "rock_b"), i), subdiv=1, jitter=r * 0.08,
               rot=(0, 0, rng.uniform(0, 90)))
    shallow = tint("water_shallow", "#8FDCE2")
    with b.part("water", pivot=(0, 0, WATER_Z), motion="flow"):
        wr = random.Random(5)
        grid_mesh(b, lambda x, y, interior: WATER_Z + (wr.uniform(-0.003, 0.003) if interior else 0.0), lambda t: True,
                  lambda t: shallow if max(abs(p[0]) for p in t) < 0.76 and max(abs(p[1]) for p in t) < 0.76 else "water", n=8)
    return b.finish(KIT, "modular", {"seam_grid": SEAM, "module": "water", "surface_z": WATER_Z, "shallow": True,
                                     "walkable": False, "note": "visual only; shallow tint does not make it traversable"})


def foam_edge_strip():
    """Loose 2 m foam ribbon for any shoreline (stream banks, water edges). Sits FOAM_Z (4 mm above the water)."""
    b = Builder("foam_edge_strip", seed=550)
    with b.part("foam", pivot=(0, 0, FOAM_Z), motion="flow"):
        foam_line(b, [(-1 + 0.2 * i, 0.0) for i in range(11)])
    return b.finish(KIT, "overlay", {"seam_grid": SEAM, "layer": "foam", "surface_z": FOAM_Z, "spreads": "-Y from the origin line"})


# ---- dock dressing ------------------------------------------------------------------------
def iron_band(b, x, y, z, w=0.2, h=0.06):
    b.box(w + 0.03, w + 0.03, h, x, y, z, "iron_light", bevel=0.008)


def snowy_post(b, x, y, top=0.42, w=0.22, bands=(0.18, -0.35)):
    dock_post(b, x, y, top=top, w=w)
    for z in bands:
        iron_band(b, x, y, z, w)
    b.box(w * 0.9, w * 0.9, 0.07, x, y, top + 0.05, "snow", bevel=0.025)


def dock_end_cap():
    """Closes the open -Y end of a dock run: a short deck, fascia beam and two snow-capped, iron-banded posts.
    Origin is the seam with the dock module it extends; it reaches 0.6 m toward -Y."""
    b = Builder("dock_end_cap", seed=560)
    W, D = 2.0, 0.6
    deck(b, W, D, 0, -D / 2, along="x", plank=0.2)
    b.box(W + 0.04, 0.1, 0.22, 0, -D + 0.05, -0.3, "wood_dark", bevel=0.015)           # fascia
    for sx in (-1, 1):
        snowy_post(b, sx * (W / 2 - 0.11), -D + 0.11)
    b.socket("seam_n", (0, 0, 0), 180)
    b.socket("stand_0", (0, -0.3, 0))
    return b.finish(KIT, "modular", {"module": "dock", "grid": 2.0, "deck_z": 0.0, "water_z": WATER_Z, "connects": ["+Y"]})


def dock_ladder():
    b = Builder("dock_ladder", seed=570)
    for sx in (-1, 1):
        x = sx * 0.22
        b.box(0.07, 0.07, 1.35, x, -0.05, WATER_Z - 0.4, "wood_b", bevel=0.015)        # rails into the water
        b.box(0.07, 0.24, 0.07, x, -0.15, 0.36, "wood_b", bevel=0.015)
        b.box(0.07, 0.07, 0.36, x, -0.25, 0.0, "wood_b", bevel=0.015)
        iron_band(b, x, -0.05, -0.12, 0.07, 0.045)
    for i in range(4):
        b.box(0.4, 0.06, 0.05, 0, -0.05, -0.15 - i * 0.22, pick(WOOD, i), bevel=0.01)
    return b.finish(KIT, "prop", {"decorative": True, "climbable": False, "mount": "dock side edge (origin on the deck edge, hangs -Y)",
                                  "note": "keep clear of fishing sockets"})


def mooring_cleat():
    b = Builder("mooring_cleat", seed=580)
    for i, y in enumerate((-0.05, 0.05)):
        b.box(0.42, 0.1, 0.05, 0, y, 0, pick(WOOD, i), bevel=0.01)
    b.box(0.16, 0.08, 0.06, 0, 0, 0.05, "iron", bevel=0.012)
    b.box(0.36, 0.06, 0.04, 0, 0, 0.11, "iron", bevel=0.012)
    for sx in (-1, 1):
        b.box(0.07, 0.065, 0.035, sx * 0.17, 0, 0.13, "iron", bevel=0.01, rot=(0, sx * -12, 0))
        b.cyl(0.018, 0.012, sx * 0.13, 0.0, 0.05, "steel", segs=6)
    b.socket("rope", (0, 0, 0.12))
    return b.finish(KIT, "prop", {"decorative": True})


def coiled_rope():
    b = Builder("coiled_rope", seed=590)
    for i, (R, z) in enumerate(((0.2, 0.03), (0.17, 0.085), (0.2, 0.14), (0.15, 0.19))):
        b.torus(R, 0.032, 0.01 * (i % 2), 0, z, "rope", segs=14, ring=5)
    b.box(0.08, 0.1, 0.25, 0.2, 0, 0.0, tint("rope_band", "teal"), bevel=0.012)        # binding band across the coil side
    rope_between(b, (0.22, -0.08, 0.03), (0.42, -0.25, 0.03), sag=0.0, r=0.03, segs=3)
    return b.finish(KIT, "prop", {"decorative": True, "color_variants": {"rope_band": ["teal", "navy", "red"]}})


def boat_fender():
    b = Builder("boat_fender", seed=600)
    body, cap = tint("fender", "cream"), tint("fender_cap", "teal")
    with b.at((0, 0, 0.13), rot=(0, 90, 0)):                                           # lies along X
        b.cyl(0.13, 0.36, 0, 0, -0.18, body, segs=8, bevel=0.01)
        for sz in (-1, 1):
            b.cyl(0.13, 0.08, 0, 0, sz * 0.18 + (0 if sz > 0 else -0.08), cap, segs=8, r2=0.07 if sz > 0 else 0.13, bevel=0.008)
        b.cyl(0.07, 0.05, 0, 0, -0.31, cap, segs=8, r2=0.13)
        for sz in (-1, 1):
            b.torus(0.045, 0.015, 0, 0, sz * 0.32, cap, segs=10, ring=5, rot=(90, 0, 0))
    b.socket("rope_a", (-0.36, 0, 0.13)); b.socket("rope_b", (0.36, 0, 0.13))
    return b.finish(KIT, "prop", {"decorative": True, "color_variants": {"fender": ["cream", "white", "red"], "fender_cap": ["teal", "navy"]}})


def dock_lantern_bracket():
    b = Builder("dock_lantern_bracket", seed=610)
    b.box(0.18, 0.18, 1.6, 0, 0, 0, "wood_b", bevel=0.025)
    for z in (0.12, 1.3):
        iron_band(b, 0, 0, z, 0.18, 0.06)
    b.box(0.16, 0.16, 0.06, 0, 0, 1.6, "snow", bevel=0.025)
    b.box(0.1, 0.6, 0.1, 0, -0.32, 1.42, "wood", bevel=0.015)                         # arm toward -Y
    b.box(0.07, 0.42, 0.07, 0, -0.2, 1.22, "wood_dark", bevel=0.01, rot=(40, 0, 0))   # brace
    iron_band(b, 0, -0.56, 1.42, 0.1, 0.06)
    b.cyl(0.012, 0.14, 0, -0.56, 1.28, "iron", segs=5)
    lantern_head(b, 0, -0.56, 0.86, s=1.15)                                            # glow stays its own material
    b.socket("light", (0, -0.56, 1.0))
    return b.finish(KIT, "light", {"light_color": "#FFC76B", "mount": "dock deck or plaza edge"})


def build():
    broad_tree("broad_tree"); broad_tree("broad_tree_bed", bed=True); broad_tree("broad_tree_snow", snow=True)
    small_tree("small_tree"); small_tree("small_tree_bed", bed=True); small_tree("small_tree_snow", snow=True)
    shrub("shrub_round", [(0, 0, 0.32, 0.36), (-0.3, 0.1, 0.24, 0.27), (0.3, -0.05, 0.25, 0.28), (0.05, 0.25, 0.22, 0.25), (0.05, -0.05, 0.55, 0.26)])
    shrub("shrub_small", [(0, 0, 0.2, 0.24), (0.2, 0.08, 0.15, 0.17), (-0.15, -0.05, 0.14, 0.16)], seed=1)
    shrub("shrub_flowering", [(0, 0, 0.26, 0.3), (-0.25, 0.05, 0.2, 0.22), (0.25, 0.0, 0.2, 0.23)], flowers=FLOWERS, seed=2)
    flower_stem("flower_single", "petal_white")
    leaf_tuft("leaf_tuft", r=0.22); leaf_tuft("leaf_tuft_small", n=5, seed=3, r=0.15); flower_clump("flower_clump")
    rocks("rock_cluster", ROCK_LARGE); rocks("rock_small_a", ROCK_SMALL_A, seed=1); rocks("rock_small_b", ROCK_SMALL_B, seed=2)
    rocks("rock_cluster_snow", ROCK_LARGE, snow=True); rocks("rock_small_a_snow", ROCK_SMALL_A, snow=True, seed=1)
    rocks("rock_small_b_snow", ROCK_SMALL_B, snow=True, seed=2)
    dock_straight(); dock_corner(); dock_stairs()
    rope_posts("rope_posts"); rope_posts("rope_posts_bunting", flags=True)
    water_tile(); water_edge("water_edge_2m"); water_edge("water_edge_corner", corner=True)
    for k in ("straight", "inner", "outer"):
        shore_bank(k); snow_overlay_shore(k)
    pebble_cluster("pebble_cluster"); pebble_cluster("pebble_cluster_snow", snow=True)
    shallow_water_patch(); foam_edge_strip()
    dock_end_cap(); dock_ladder(); mooring_cleat(); coiled_rope(); boat_fender(); dock_lantern_bracket()
