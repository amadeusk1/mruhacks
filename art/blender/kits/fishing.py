"""Fishing kit (concept 17 Fishing Dock, World Map). The rod is an avatar accessory (avatar kit).
Water-level props (bobber, ripple, ice floes, rowboat) are placed at world z=0 like everything else.
Their geometry already sits at WATER_Z, except bobber and ripple: those have their origin at the
waterline because the game moves them on the water."""
from common import *
from kits.plaza import WATER_Z
from kits.nature_dock import dock_straight

KIT = "fishing"
PREVIEW_WIDTH = 8.0


def recolor(b, faces, mat_name, test):
    mi = b._mi(mat_name)
    for f in faces:
        if test(f.calc_center_median()):
            f.material_index = mi


def oriented_tris(b, verts, tris, mat, want):
    """Add triangles, flipping each so its normal points along `want`."""
    vs = [Vector(v) for v in verts]
    faces = []
    for t in tris:
        a, c, d = (vs[i] for i in t)
        n = (c - a).cross(d - a)
        faces.append(t if n.dot(Vector(want)) >= 0 else (t[0], t[2], t[1]))
    b.mesh(verts, faces, mat=mat)


# ---- small props ---------------------------------------------------------------------
def bobber():
    b = Builder("bobber", seed=301)
    A, B = tint("bobber_a", "red"), tint("bobber_b", "white")
    f = b.sphere(0.075, 0, 0, 0, A, u=10, v=8, scale=(1, 1, 0.95))
    recolor(b, f, B, lambda c: c.z > 0.005)
    b.cyl(0.022, 0.012, 0, 0, 0.068, A, segs=8)
    b.cyl(0.011, 0.07, 0, 0, 0.075, B, segs=6)
    b.cyl(0.014, 0.03, 0, 0, -0.095, B, segs=6)
    b.socket("line", (0, 0, 0.145))
    b.socket("fx_ripple", (0, 0, 0))
    return b.finish(KIT, "fishing", {"origin": "waterline", "color_variants": {"bobber_a": ["red", "orange", "teal"], "bobber_b": ["white"]}})


def bucket(name, fish=False):
    b = Builder(name, seed=302 + fish)
    H = 0.34
    body = tint("bucket", "steel")
    b.cyl(0.165, H, 0, 0, 0, body, segs=10, r2=0.205, bevel=0.008)
    b.cyl(0.19, 0.012, 0, 0, H + 0.001, "charcoal", segs=10)                      # dark opening
    b.torus(0.205, 0.016, 0, 0, H, body, segs=10, ring=5)                         # rolled rim
    for z, r in ((0.08, 0.175), (H - 0.07, 0.198)):
        b.torus(r, 0.012, 0, 0, z, "grey", segs=10, ring=4)
    for sx in (-1, 1):
        b.box(0.03, 0.05, 0.06, sx * 0.205, 0, H - 0.08, "grey", bevel=0.006)
    pts = [Vector((0.215 * math.cos(math.radians(a)), 0, H - 0.05 + 0.24 * math.sin(math.radians(a)))) for a in range(0, 181, 20)]
    for p0, p1 in zip(pts, pts[1:]):
        d = p1 - p0
        b.cyl(0.011, d.length, p0.x, p0.y, p0.z, "grey", segs=5,
              rot=tuple(math.degrees(v) for v in d.to_track_quat("Z", "Y").to_euler()))
    b.cyl(0.028, 0.14, -0.07, 0, H + 0.19, "wood_b", segs=6, rot=(0, 90, 0))
    if fish:
        for i, (x, y, rz, shape) in enumerate(((-0.03, 0.04, 20, "round"), (0.05, -0.04, 160, "slim"))):
            with b.at((x, y, H - 0.12), rot=(0, 72 - 10 * i, rz)):  # head down, tail sticking out of the top
                fish_geo(b, shape, scale=0.75, role=f"fish{i}")
    return b.finish(KIT, "fishing", {"color_variants": {"bucket": ["steel", "teal", "red", "mustard"]}})


FISH = {  # shape: (length, height, dorsal height, default body, fin, stripe)
    "round": (1.0, 1.15, 0.9, "orange", "red", "mustard"),
    "slim": (1.2, 0.85, 0.8, "teal_light", "teal", None),
    "spiky": (1.05, 1.0, 1.6, "lavender", "purple", None),
}


def fish_geo(b, shape="round", scale=1.0, role="fish"):
    """Fish along +X (head) with the belly at local z=0. Body/fin/stripe are tint roles."""
    L, Hh, dors, body, fin, stripe = FISH[shape]
    body, fin = tint(f"{role}_body" if role != "fish" else "body", body), tint(f"{role}_fin" if role != "fish" else "fin", fin)
    with b.at((0, 0, 0), scale=(scale * L, scale, scale * Hh)):
        b.blob(0.16, 0.065, 0.1, 0, 0, 0.1, body, subdiv=1, jitter=0.004)
        b.blob(0.06, 0.05, 0.065, 0.11, 0, 0.1, body, subdiv=1)                     # head
        b.prism([(-0.12, 0.0), (-0.27, 0.1), (-0.225, 0.0), (-0.27, -0.1)], 0.025, z=0.1, mat=fin)
        b.prism([(-0.08, 0.075), (0.05, 0.08), (-0.06, 0.075 + 0.085 * dors)], 0.02, z=0.1, mat=fin)   # dorsal
        if shape == "spiky":
            b.prism([(0.0, 0.08), (0.08, 0.07), (0.02, 0.07 + 0.07 * dors)], 0.02, z=0.1, mat=fin)
        b.prism([(-0.02, -0.08), (0.04, -0.075), (-0.03, -0.12)], 0.018, z=0.1, mat=fin)
        for sy in (-1, 1):
            with b.at((0.04, sy * 0.06, 0.08), rot=(sy * 30, 25, sy * -30)):
                b.blob(0.045, 0.012, 0.025, 0, 0, 0, fin)
            b.sphere(0.022, 0.135, sy * 0.042, 0.125, "white", u=6, v=4)
            b.sphere(0.012, 0.148, sy * 0.055, 0.128, "eye", u=6, v=4)
        b.blob(0.012, 0.02, 0.012, 0.172, 0, 0.09, fin)                                # mouth
        if stripe:
            st = tint(f"{role}_stripe" if role != "fish" else "stripe", stripe)
            for x in (-0.03, 0.05):
                b.blob(0.016, 0.068, 0.101, x, 0, 0.1, st, subdiv=1)


FISH_COLORS = ["orange", "teal_light", "lavender", "yellow", "pink", "sky", "red"]


def fish(name, shape, size_cm):
    b = Builder(name, seed=310 + len(name))
    fish_geo(b, shape)
    L = FISH[shape][0]
    b.socket("mouth", (0.18 * L, 0, 0.09))
    return b.finish(KIT, "fishing", {"head": "+X", "length_m": round(0.45 * L, 2), "catch_card_size_cm": size_cm,
                                     "color_variants": {"body": FISH_COLORS, "fin": ["red", "teal", "purple", "mustard"]}})


def ripple():
    b = Builder("ripple", seed=320)
    for i, R in enumerate((0.13, 0.25, 0.37)):
        b.torus(R, 0.014 - i * 0.002, 0, 0, 0.004, pick(("white", "ice", "ice"), i), segs=16, ring=4)
    return b.finish(KIT, "fishing", {"origin": "waterline", "note": "scale/fade in game"})


def torus_arc(b, R, r, a0, a1, mat, segs=4, ring=6):
    pts = []
    for i in range(segs + 1):
        a = math.radians(a0 + (a1 - a0) * i / segs)
        pts.append([(math.cos(a) * (R + r * math.cos(2 * math.pi * j / ring)), math.sin(a) * (R + r * math.cos(2 * math.pi * j / ring)),
                     r * math.sin(2 * math.pi * j / ring)) for j in range(ring)])
    verts = [v for row in pts for v in row]
    faces = [(i * ring + j, (i + 1) * ring + j, (i + 1) * ring + (j + 1) % ring, i * ring + (j + 1) % ring)
             for i in range(segs) for j in range(ring)]
    b.mesh(verts, faces, mat=mat)


def life_ring():
    b = Builder("life_ring", seed=330)
    R, r = 0.27, 0.085
    with b.at((0, 0, R + r), rot=(90, 0, 0)):                 # stands upright, faces -Y
        for i in range(8):
            torus_arc(b, R, r, i * 45, (i + 1) * 45, tint("stripe_a", "red") if i % 2 == 0 else tint("stripe_b", "white"), segs=3, ring=7)
        for i in range(4):                                     # rope grab-line loops
            a = math.radians(22.5 + 90 * i)
            with b.at((math.cos(a) * R, math.sin(a) * R, 0), rot=(0, 0, math.degrees(a))):
                b.torus(r + 0.004, 0.012, 0, 0, 0, "rope", segs=10, ring=5, rot=(90, 0, 0))
    return b.finish(KIT, "fishing", {"mount": "post or wall; centre at z=0.355", "color_variants": {"stripe_a": ["red", "coral", "orange"], "stripe_b": ["white"]}})


def ice_floe(name, radius, seed):
    b = Builder(name, seed=340 + seed)
    rng = random.Random(seed)
    n = 7
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.25, 0.25)
        rr = radius * rng.uniform(0.75, 1.1)
        pts.append((rr * math.cos(a), rr * math.sin(a) * 0.8))
    b.prism(pts, 0.2, z=WATER_Z - 0.12, mat="ice", plane="xy", bevel=0.035)
    inner = [(x * 0.86, y * 0.86) for x, y in pts]
    b.prism(inner, 0.035, z=WATER_Z + 0.07, mat="snow", plane="xy", bevel=0.012)
    return b.finish(KIT, "nature", {"floats_at": WATER_Z, "walkable": False})


def tackle_crate():
    b = Builder("tackle_crate", seed=350)
    W, D, H = 0.56, 0.4, 0.3
    for i, z in enumerate((0.0, H / 2)):
        for sy in (-1, 1):
            b.box(W - 0.06, 0.04, H / 2 - 0.012, 0, sy * (D / 2 - 0.02), z, pick(WOOD, i + (sy > 0)), bevel=0.01)
        for sx in (-1, 1):
            b.box(0.04, D - 0.06, H / 2 - 0.012, sx * (W / 2 - 0.02), 0, z, pick(WOOD, i + 2), bevel=0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.06, 0.06, H, sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), 0, "wood_dark", bevel=0.012)
    for i in range(3):                                         # lid planks
        b.box(W + 0.02, D / 3 - 0.012, 0.045, 0, -D / 3 + i * D / 3, H, pick(WOOD, i + 1), bevel=0.01)
    b.box(0.08, 0.02, 0.09, 0, -D / 2 - 0.01, H - 0.05, "iron", bevel=0.004)          # latch
    b.box(0.18, 0.05, 0.03, 0, 0, H + 0.065, "iron", bevel=0.006)
    for sx in (-1, 1):
        b.box(0.03, 0.04, 0.05, sx * 0.08, 0, H + 0.045, "iron", bevel=0.004)
    return b.finish(KIT, "prop", {"seat_height": H + 0.045})


# ---- rowboat --------------------------------------------------------------------------
def rowboat():
    b = Builder("rowboat", seed=360)
    L, W, N, inset = 2.5, 1.05, 10, 0.06

    def half_w(t):
        if t < 0.4:
            return W / 2 * (1 - 0.3 * ((0.4 - t) / 0.4) ** 2)
        return max(0.015, W / 2 * math.sqrt(max(0.0, 1 - ((t - 0.4) / 0.6) ** 2)))

    outer, inner = [], []
    for i in range(N + 1):
        t = i / N
        x = -L / 2 + L * t
        w = half_w(t)
        zt = WATER_Z + 0.27 + 0.14 * t ** 3
        zb = WATER_Z - 0.17 + 0.18 * t ** 4
        zf = min(zb + 0.13, zt - 0.05)
        wi = max(0.008, w - inset)
        sec = [(x, -w, zt), (x, -w * 0.995, zt - 0.08), (x, -w * 0.93, zb + (zt - zb) * 0.35), (x, -w * 0.55, zb + 0.025), (x, 0, zb)]
        outer.append(sec + [(px, -py, pz) for px, py, pz in reversed(sec[:-1])])
        inner.append([(x, -wi, zt), (x, -wi * 0.88, zf), (x, wi * 0.88, zf), (x, wi, zt)])
    K = len(outer[0])
    ov = [v for s in outer for v in s]
    iv = [v for s in inner for v in s]
    oi = lambda i, k: i * K + k
    ii = lambda i, k: i * 4 + k
    band = {0, K - 2}
    HULL, TRIM = tint("hull", "red"), tint("trim", "white")
    for m, ks in ((TRIM, band), (HULL, set(range(K - 1)) - band)):
        b.mesh(ov, [(oi(i, k), oi(i, k + 1), oi(i + 1, k + 1), oi(i + 1, k)) for i in range(N) for k in sorted(ks)], mat=m)
    b.mesh(iv, [(ii(i, k), ii(i + 1, k), ii(i + 1, k + 1), ii(i, k + 1)) for i in range(N) for k in range(3)], mat="wood")
    rim = []
    for i in range(N):                                          # gunwale top, both sides
        rim.append([outer[i][0], outer[i + 1][0], inner[i + 1][0], inner[i][0]])
        rim.append([outer[i][K - 1], inner[i][3], inner[i + 1][3], outer[i + 1][K - 1]])
    for q in rim:
        b.mesh(q, [(0, 1, 2, 3)], mat="wood_c")
    for i, want in ((0, (-1, 0, 0)), (N, (1, 0, 0))):            # transom and bow caps
        o, n = outer[i], inner[i]
        verts = o + n
        Q = lambda k: K + k
        tris = [(0, 1, Q(0)), (1, 2, Q(0)), (2, Q(1), Q(0)), (2, 3, Q(1)), (3, 4, Q(1)), (4, Q(2), Q(1)),
                (4, 5, Q(2)), (5, 6, Q(2)), (6, Q(3), Q(2)), (6, 7, Q(3)), (7, 8, Q(3))]
        oriented_tris(b, verts, tris, HULL if i == N else TRIM, want)
    # thwarts, oars, oarlocks
    for x, t in ((-0.55, 0.28), (0.3, 0.62)):
        w = half_w(t) - inset
        b.box(0.26, 2 * w * 0.95, 0.05, x, 0, WATER_Z + 0.14 + 0.14 * t ** 3, pick(WOOD, int(x * 10)), bevel=0.012)
    for sy in (-1, 1):
        with b.at((-0.1, sy * 0.18, WATER_Z + 0.22), rot=(0, 90, sy * 4)):
            b.cyl(0.024, 1.5, 0, 0, -0.75, "wood_b", segs=6)
            b.box(0.03, 0.15, 0.36, 0, 0, 0.6, "wood_c", bevel=0.012)
        b.box(0.05, 0.05, 0.08, -0.25, sy * (half_w(0.38) - 0.02), WATER_Z + 0.27, "iron", bevel=0.008)
    b.socket("seat_0", (-0.55, 0, WATER_Z + 0.2), 90)
    b.socket("seat_1", (0.3, 0, WATER_Z + 0.24), 90)
    b.socket("mooring", (L / 2 - 0.05, 0, WATER_Z + 0.4))
    return b.finish(KIT, "vehicle", {"floats_at": WATER_Z, "decor": True,
                                     "color_variants": {"hull": ["red", "teal", "navy", "mustard"], "trim": ["white", "cream"]}})


def build():
    bobber(); bucket("bucket"); bucket("bucket_fish", fish=True)
    fish("fish_round", "round", 28); fish("fish_slim", "slim", 34); fish("fish_spiky", "spiky", 40)
    ripple(); life_ring()
    ice_floe("ice_floe_a", 0.7, 1); ice_floe("ice_floe_b", 0.45, 2); ice_floe("ice_floe_c", 1.0, 3)
    tackle_crate(); rowboat()
    dock_straight("fishing_dock_spot", fish=4, kit=KIT)
