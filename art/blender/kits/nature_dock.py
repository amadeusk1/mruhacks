"""Nature & dock kit (concept 06 Nature and Dock Kit, 17 Fishing Dock, World Map).
Plaza/dock deck top is z=0. Water surface is WATER_Z (-0.5).
Docks run along Y and extend out toward -Y (the water). A straight module carries posts only at its
far (-Y) end, so modules chain without doubled posts. The plaza edge supports the land end."""
from common import *
from kits.plaza import leafy, edge_run, WATER_Z, LEAVES, PETAL_VARIANTS, FLAG_VARIANTS

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
    canopy(b, [(0, 0, 1.85, 0.56), (-0.42, 0.05, 1.6, 0.44), (0.4, -0.08, 1.62, 0.46), (0.05, 0.4, 1.66, 0.42),
               (0.12, -0.05, 2.22, 0.38)], snow, seed=9)
    return b.finish(KIT, "nature", {"collision_radius": 0.2 if not bed else 0.78, **(FLOWER_VARIANTS if bed else {})})


# ---- shrubs, flowers ------------------------------------------------------------------
def shrub(name, blobs, flowers=None, seed=0):
    b = Builder(name, seed=110 + seed)
    rng = random.Random(seed)
    for i, (x, y, z, r) in enumerate(blobs):
        b.blob(r, r, r * 0.85, x, y, z, pick(LEAVES, i + seed), subdiv=1, jitter=r * 0.06)
    if flowers:
        top = max(z + r * 0.85 for _, _, z, r in blobs)
        for i in range(7):
            x, y, z, r = blobs[i % len(blobs)]
            a = rng.uniform(0, 2 * math.pi)
            rr = r * rng.uniform(0.3, 0.7)
            fz = z + math.sqrt(max(0, r * r - rr * rr)) * 0.85
            flower(b, x + rr * math.cos(a), y + rr * math.sin(a), fz, pick(flowers, i), size=0.08)
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
        bunting(b, p0, p1, n=3, colors=(tint("flag_a", "coral"), tint("flag_c", "cream"), tint("flag_b", "teal_light")), size=0.2, sag=0.16)
        rope_between(b, p0, p1, sag=0.16, r=0.024, segs=8)
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
            verts.append((x - w / 2 + w * i / n + jx, y - d / 2 + d * j / n + jy, z + (0 if edge else rng.uniform(-0.015, 0.015))))
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
    return b.finish(KIT, "modular", {"module": "water_edge", "length": 2.0, "corner": corner,
                                    "water_z": WATER_Z, "water_side": "-Y" if not corner else "-Y,+X"})


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
