"""Player homes (concepts: Player Homes - Exterior Variations / Interior Personalities /
Modular House Construction Kit; vault notes Player Housing - *, Prop Kit - Modular Houses).

Six shell families, each as
  <type>_exterior  assembled house on its snowy base (houseboat: on water at a dock). The roof /
                   top is a child <type>_exterior_roof the game hides for cutaway views.
  <type>_interior  the room shell players decorate on the 0.5 m grid. Visible walls are the back
                   (+Y) and left (-X); the front/right are a low cutaway lip (camera sits at +X,-Y).
plus the construction modules (mod_*) the prefabs are assembled from: floor tiles and curved floor
sectors, straight / curved / door / window walls, roof sections, stairs, treehouse support and
deck, lighthouse floor, houseboat hull and deck, door and window inserts. Modules are an
authoring kit (shell variants, art iteration); player structural building is not implied.

Seams: straight walls run x=0..length with the pivot on the left seam (0.5 m seam grid); curved
walls and floor sectors pivot on the circle centre and span +-arc/2 about +X (rotate by the
segment's centre angle); floor tiles pivot on their min corner (= a cell corner). Door leaves are
hinge parts (part_door_leaf). Chimneys carry socket_fx_smoke above the cap.
Interior meta: cells, cell_origin, cell_m, floor_z, blocked_cells, wall_slots, ceiling_anchors;
the A-frame also has cells_loft / blocked_cells_loft / loft_z and a penguin headroom check.
"""
from contextlib import contextmanager, nullcontext
from common import *
from kits.buildings import (T, WALL_T, ROOF_T, DOOR_T, TRIM_T, masonry_wall, tiled_gable, entry_steps, attach)
from kits.winter import snowy_fir, snowy_rock, snow_lumps, snow_post, SNOW
from kits.nature_dock import water_surface, canopy, dock_post
from kits.world_misc import beam
from kits.plaza import WATER_Z

KIT = "homes"
PREVIEW_WIDTH = 24.0
FLOOR = 0.12                      # interior floor top
WALL_H = 2.0                      # straight wall module height (rect rooms and cabins)
LIP_H = 0.42                      # cutaway lip height
PENGUIN_H = 0.9
ICE = (tint("wall", "ice"), tint("wall_b", "snow_shade"), tint("wall_c", "snow"))
STRIPE_T = tint("stripe", "teal")
HULL_T = tint("hull", "wood_b")
PLASTER = (WALL_T, "plaster_shade", WALL_T)
WOODS = ("wood", "wood_c", "wood_b")
DOOR_OPEN = 100                   # hinge swing (deg) toward local +Y: into the building / out of the room


# House upgrade tiers (docs/Housing - House Upgrades Plan.md): tier 1 is the plain family name,
# tier N adds _tN. A bigger tier is the same house rebuilt with larger numbers, so the shared
# dimension tables (AF, RC, TH_, LH, HB) are overridden while it builds.
def tier_name(base, tier):
    return base if tier == 1 else f"{base}_t{tier}"


def tier_extra(base, tier, part):
    return {"tier": tier, "upgrade_of": f"{tier_name(base, tier - 1)}_{part}"} if tier > 1 else {}


@contextmanager
def variant(table, **over):
    saved = dict(table)
    table.update(over)
    try:
        yield
    finally:
        table.clear()
        table.update(saved)


# =============================================================================== shared dressing
def snow_base(b, rx, ry, seed=0, n=20, depth=0.32, rocks=6, lumps=10, back_firs=()):
    """Faceted snowy island the house sits on: top at z~0, skirt down to -depth, rocks on the rim."""
    rng = random.Random(seed)
    top, rim, bot = [], [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        j = rng.uniform(0.94, 1.05)
        top.append((rx * 0.62 * math.cos(a) * rng.uniform(0.96, 1.04), ry * 0.62 * math.sin(a) * rng.uniform(0.96, 1.04),
                    rng.uniform(0.0, 0.025)))
        rim.append((rx * j * math.cos(a), ry * j * math.sin(a), rng.uniform(-0.05, -0.01)))
        bot.append((rx * j * 1.07 * math.cos(a), ry * j * 1.07 * math.sin(a), -depth))
    vs = [(0, 0, 0.02)] + top + rim
    f = [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)]
    f += [(1 + i, 1 + n + i, 1 + n + (i + 1) % n, 1 + (i + 1) % n) for i in range(n)]
    b.mesh(vs, f, "snow")
    vs = rim + bot
    f = [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)] + [tuple(range(2 * n - 1, n - 1, -1))]
    b.mesh(vs, f, "snow_shade")
    for k in range(rocks):  # rocks sit on the rim, mostly behind and at the sides
        a = math.radians(rng.uniform(-20, 200) if k % 3 else rng.uniform(200, 340))
        s = rng.uniform(0.22, 0.42)
        snowy_rock(b, rx * 0.93 * math.cos(a), ry * 0.93 * math.sin(a), s * 1.3, s, s * 0.9, k)
    snow_lumps(b, 0, 0, 0.0, rx * 1.6, ry * 1.6, lumps, r=(0.12, 0.24), flat=0.4)
    for x, y, h in back_firs:
        snowy_fir(b, x, y, 0, h=h, r=h * 0.32, tiers=4)


def stepping_stones(b, x, y0, y1, n=3, seed=0):
    rng = random.Random(seed)
    for i in range(n):
        y = y0 + (y1 - y0) * (i + 0.5) / n
        b.box(rng.uniform(0.42, 0.55), rng.uniform(0.3, 0.38), 0.07, x + rng.uniform(-0.12, 0.12), y, -0.01,
              pick(("stone_grey", "rock_grey", "stone_dark"), i), bevel=0.025, rot=(0, 0, rng.uniform(-12, 12)))


def settle(b, p, n, gap=0.02):
    """Drop a point along -n onto the geometry already built in b; returns the local hit point
    lifted by gap (or p if nothing is hit). Keeps snow resting on the real tile surface."""
    from mathutils.bvhtree import BVHTree
    xf = b.xf
    pw, nw = xf @ Vector(p), (xf.to_3x3() @ Vector(n)).normalized()
    hit = BVHTree.FromBMesh(b.bm).ray_cast(pw + nw * 2.5, -nw, 5.0)[0]
    return (xf.inverted() @ (hit + nw * gap)) if hit is not None else Vector(p)


def snow_clump(b, c, n, u, v, rot, seed=0, size=1.0):
    """A drift of 4-6 flattened lumps around c on a surface with normal n (u, v span the surface),
    each dropped onto the real geometry so it hugs the tiles."""
    rng = random.Random(seed)
    for i in range(rng.randint(4, 6)):
        r = rng.uniform(0.12, 0.22) * size
        p = settle(b, c + u * rng.uniform(-0.3, 0.3) * size + v * rng.uniform(-0.38, 0.38) * size, n, gap=-r * 0.12)
        b.blob(r * 1.35, r * 1.15, r * 0.42, p.x, p.y, p.z, pick(SNOW, i + seed), subdiv=1, rot=rot, jitter=r * 0.08)


def slope_snow(b, span, length, rise, z, side, spots, overhang=0.3, size=1.0):
    """Snow drifts on one slope of a tiled_gable (ridge along Y). spots: [(s 0..1 up the slope, y)]."""
    half = span / 2
    A = math.atan(rise / half)
    run = half + overhang
    eave = z - overhang * rise / half
    Ls = run / math.cos(A)
    n = Vector((side * math.sin(A), 0, math.cos(A)))
    up = Vector((side * -math.cos(A), 0, math.sin(A)))
    for k, (s, y) in enumerate(spots):
        c = Vector((side * (run - s * Ls * math.cos(A)), y, eave + s * Ls * math.sin(A)))
        snow_clump(b, c, n, up, Vector((0, 1, 0)), rot=(0, side * math.degrees(A), 0), seed=k + int(y * 10), size=size)


def ridge_snow(b, length, z, w=0.36):
    b.box(w, length, 0.1, 0, 0, z, "snow", bevel=0.04)
    snow_lumps(b, 0, 0, z + 0.08, w * 0.5, length * 0.9, max(2, int(length * 2)), r=(0.08, 0.13), flat=0.45)


def ridge_snow_on(b, span, length, rise, z, tile_thick=0.09, w=0.36):
    """Ridge snow for a tiled_gable (ridge along Y). On steep roofs the tile tops meet well above the
    geometric apex and bury tiled_gable's own ridge cap, so add a cap row where they really meet."""
    A = math.atan(rise / (span / 2))
    lift = (tile_thick + 0.03) / math.cos(A)
    top = z + rise + max(0.18, lift)
    if lift > 0.18:
        n = max(2, round(length / 0.42))
        for i in range(n):
            b.box(0.34, length / n - 0.02, 0.16, 0, -length / 2 + length / n * (i + 0.5), top - 0.14, ROOF_T[1], bevel=0.035)
        top += 0.02
    with b.at((0, 0, top)):
        ridge_snow(b, length + 0.1, 0, w=w)


def barrel(b, x, y, z=0.0, s=1.0, snow=True):
    b.cyl(0.2 * s, 0.26 * s, x, y, z, "wood_b", segs=10, r2=0.24 * s)
    b.cyl(0.24 * s, 0.26 * s, x, y, z + 0.26 * s, "wood_b", segs=10, r2=0.2 * s)
    for zz, R in ((0.06, 0.212), (0.26, 0.245), (0.46, 0.212)):
        b.torus(R * s, 0.014 * s, x, y, z + zz * s, "iron", segs=12, ring=4)
    b.cyl(0.19 * s, 0.02, x, y, z + 0.51 * s, "wood_dark", segs=10)
    if snow:
        b.blob(0.17 * s, 0.17 * s, 0.05, x, y, z + 0.54 * s, "snow", subdiv=1)


def crate(b, x, y, z=0.0, s=0.45, rotz=0):
    with b.at((x, y, z), rotz=rotz):
        b.box(s, s, s, 0, 0, 0, "wood_c", bevel=0.02)
        for sy in (-1, 1):
            b.box(s + 0.01, 0.03, 0.06, 0, sy * s / 2, s * 0.15, "wood_dark", bevel=0.006)
            b.box(s + 0.01, 0.03, 0.06, 0, sy * s / 2, s * 0.75, "wood_dark", bevel=0.006)


def post_lantern(b, x, y, side=1, h=1.5):
    """Wooden post with an arm carrying a lantern (arm points toward side*X)."""
    b.box(0.12, 0.12, h, x, y, 0, "wood_b", bevel=0.02)
    b.box(0.45, 0.07, 0.07, x + side * 0.2, y, h - 0.12, "wood_b", bevel=0.01)
    b.box(0.04, 0.04, 0.12, x + side * 0.38, y, h - 0.24, "iron", bevel=0)
    lantern_head(b, x + side * 0.38, y, h - 0.6, 0.9)
    b.box(0.17, 0.17, 0.05, x, y, h, "snow", bevel=0.02)


def rail_run(b, p0, p1, z, h=0.75, posts=3, snow=True):
    """Fence/railing between two ground points at base height z: posts, two rails, snow caps."""
    p0, p1 = Vector(p0), Vector(p1)
    for i in range(posts):
        p = p0.lerp(p1, i / (posts - 1))
        if snow:
            snow_post(b, p.x, p.y, z, h=h, w=0.12)
        else:
            b.box(0.12, 0.12, h, p.x, p.y, z, "wood_b", bevel=0.02)
    for zz in (h * 0.45, h * 0.85):
        beam(b, (p0.x, p0.y, z + zz), (p1.x, p1.y, z + zz), 0.06, 0.08, "wood", 0.01)


def chimney_stone(b, x, y, z0, z1, w=0.5, snow=True):
    b.box(w, w, z1 - z0, x, y, z0, "chimney", bevel=0.03)
    k = 0
    zz = z0 + 0.2
    while zz < z1 - 0.1:
        b.box(w + 0.03, w + 0.03, 0.05, x, y, zz, pick(("stone", "stone_dark"), k), bevel=0.012)
        zz += 0.3
        k += 1
    b.box(w + 0.12, w + 0.12, 0.12, x, y, z1, "chimney_cap", bevel=0.03)
    b.box(w * 0.6, w * 0.6, 0.04, x, y, z1 + 0.09, "black", bevel=0)
    if snow:
        b.box(w + 0.1, w * 0.4, 0.06, x, y - w * 0.3, z1 + 0.12, "snow", bevel=0.025)
    b.socket("fx_smoke", (x, y, z1 + 0.22))      # chimney mouth, just above the cap (outdoors)


# =============================================================================== inserts
def arch_fill(b, cx, y, z, r_mid, zc, half, top, thick, mat):
    """Wall-material fill between an arch and the rectangular opening it sits in: thin trapezoid
    strips from the arch (at the frame's mid radius, so the frame overlaps their edge) up to `top`,
    plus the side strips out to +-half. Full wall thickness, so no gap shows from either side."""
    yc = y + thick / 2
    step = 12
    for a in range(0, 180, step):
        a0, a1 = math.radians(a), math.radians(a + step)
        x0, z0 = r_mid * math.cos(a0), zc + r_mid * math.sin(a0)
        x1, z1 = r_mid * math.cos(a1), zc + r_mid * math.sin(a1)
        if top - max(z0, z1) > 0.003 or top - min(z0, z1) > 0.003:
            b.prism([(x1, z1), (x0, z0), (x0, top), (x1, top)], thick, x=cx, y=yc, z=z, mat=mat)
    if half > r_mid + 0.003:
        for sx in (-1, 1):
            xa, xb = sorted((sx * r_mid, sx * half))
            b.prism([(xa, zc), (xb, zc), (xb, top), (xa, top)], thick, x=cx, y=yc, z=z, mat=mat)


def arched_door(b, cx=0.0, y=0.0, z=0.0, w=0.8, h=1.55, fw=0.12, depth=0.26, mat=DOOR_T, frame=TRIM_T,
                socket=True, port=True, backing=True, hinge=True, fill=None, fill_top=None, thick=T):
    """Round-topped plank door for an opening whose face is at y (front -Y): arch frame with
    keystone, threshold, dark backing; the leaf (planks, straps, porthole, knob) is the hinge part
    part_door_leaf, pivot on its left edge, swinging DOOR_OPEN degrees toward +Y."""
    r = w / 2
    zc = z + h - r
    arc = [(r * math.cos(math.radians(a)), h - r + r * math.sin(math.radians(a))) for a in range(0, 181, 15)]
    if backing:                     # arch-shaped (never shows corners), seen only when the leaf opens
        rb = r + fw / 2
        arcb = [(rb * math.cos(math.radians(a)), h - r + rb * math.sin(math.radians(a))) for a in range(0, 181, 15)]
        b.prism([(-rb, 0), (rb, 0)] + arcb[1:-1] + [(-rb, h - r)], 0.04, x=cx, y=y + min(depth, thick) - 0.06, z=z,
                mat="wood_deep")
    if fill:
        arch_fill(b, cx, y, z, r + fw / 2, h - r, r + fw, fill_top if fill_top is not None else h + fw, thick, fill)
    leaf = b.part("door_leaf", pivot=(cx - r, y + 0.06, z), motion="hinge", axis="z", open_deg=DOOR_OPEN) \
        if hinge else nullcontext()
    with leaf:
        b.prism([(-r, 0), (r, 0)] + arc[1:-1] + [(-r, h - r)], 0.07, x=cx, y=y + 0.06, z=z, mat=mat)
        for sx in (-1, 1):  # plank seams
            xx = sx * r / 3
            b.box(0.018, 0.012, h - r + math.sqrt(r * r - xx * xx) - 0.06, cx + xx, y + 0.02, z + 0.03, "wood_deep", bevel=0)
        for zz in (z + 0.32, zc - 0.12):  # iron straps
            b.box(w * 0.86, 0.02, 0.05, cx, y + 0.014, zz, "iron", bevel=0.005)
        if port:
            b.cyl(0.1, 0.03, cx, y + 0.02, z + h * 0.66, "glow_window", segs=10, rot=(90, 0, 0), center=True)
            b.torus(0.12, 0.028, cx, y + 0.0, z + h * 0.66, frame, segs=10, ring=5, rot=(90, 0, 0))
        b.sphere(0.035, cx + r * 0.62, y - 0.01, z + h * 0.42, "gold", u=6, v=4)
        b.torus(0.07, 0.014, cx + r * 0.62, y - 0.03, z + h * 0.42 - 0.07, "gold", segs=10, ring=4, rot=(90, 0, 0))
    yf = y + depth / 2 - 0.06          # frame protrudes 6 cm in front of the face
    for sx in (-1, 1):
        b.box(fw, depth, h - r, cx + sx * (r + fw / 2), yf, z, frame, bevel=0.02)
    rm, n = r + fw / 2, 8
    for k in range(n):
        a = (k + 0.5) * 180 / n
        b.box(2 * rm * math.sin(math.pi / (2 * n)) * 1.18, depth, fw, cx + rm * math.cos(math.radians(a)), yf,
              zc + rm * math.sin(math.radians(a)), frame, bevel=0.015, rot=(0, -(a + 90), 0), center=True)
    b.box(fw * 1.25, depth + 0.04, fw * 1.5, cx, yf - 0.02, zc + rm, frame, bevel=0.02, center=True)   # keystone
    b.box(w + 2 * fw + 0.1, depth + 0.1, 0.05, cx, yf - 0.03, z, "stone_dark", bevel=0.012)       # threshold
    if socket:
        b.socket("door", (cx, y - 0.6, z), rotz=180)


def square_door(b, cx=0.0, y=0.0, z=0.0, w=0.78, h=1.6, fw=0.1, depth=T + 0.04, mat=tint("door", "coral"), frame=TRIM_T):
    """Alternate door insert: square plank door with a diamond light and stone surround (hinge leaf)."""
    b.box(w + 2 * fw - 0.02, 0.04, h + fw - 0.02, cx, y + depth - 0.08, z, "wood_deep", bevel=0)
    with b.part("door_leaf", pivot=(cx - w / 2, y + 0.06, z), motion="hinge", axis="z", open_deg=DOOR_OPEN):
        b.box(w, 0.07, h, cx, y + 0.06, z, mat, bevel=0.015)
        for i in range(1, 3):
            b.box(0.018, 0.012, h - 0.06, cx - w / 2 + w * i / 3, y + 0.02, z + 0.03, "wood_deep", bevel=0)
        b.box(0.17, 0.03, 0.17, cx, y + 0.02, z + h * 0.7, "glow_window", bevel=0, rot=(0, 45, 0), center=True)
        b.box(0.22, 0.02, 0.22, cx, y + 0.03, z + h * 0.7, frame, bevel=0.005, rot=(0, 45, 0), center=True)
        b.torus(0.06, 0.012, cx + w * 0.3, y - 0.01, z + h * 0.45, "iron", segs=8, ring=4, rot=(90, 0, 0))
    yf = y + depth / 2 - 0.06
    for sx in (-1, 1):
        b.box(fw, depth, h + fw, cx + sx * (w / 2 + fw / 2), yf, z, pick(("stone", "stone_dark"), sx > 0), bevel=0.025)
    b.box(w + 2 * fw + 0.04, depth + 0.02, fw + 0.04, cx, yf, z + h, "stone", bevel=0.025)
    b.box(w + 2 * fw + 0.1, depth + 0.1, 0.05, cx, yf - 0.03, z, "stone_dark", bevel=0.012)


def arched_window(b, cx, y, zb, w=0.56, h=0.7, frame=TRIM_T, fw=0.075, sill=True, depth=0.18):
    """Surface-mounted arch-topped window on a wall face at y: proud frame, glowing 4-pane glass, sill."""
    r = w / 2
    arc = [(r * math.cos(math.radians(a)), h - r + r * math.sin(math.radians(a))) for a in range(0, 181, 20)]
    b.prism([(-r, 0), (r, 0)] + arc[1:-1] + [(-r, h - r)], 0.03, x=cx, y=y - 0.01, z=zb, mat="glow_window")
    yf = y + depth / 2 - 0.09        # front stays 9 cm proud; deeper frames reach further into the wall
    for sx in (-1, 1):
        b.box(fw, depth, h - r, cx + sx * (r + fw / 2), yf, zb, frame, bevel=0.012)
    rm, n = r + fw / 2, 6
    for k in range(n):
        a = (k + 0.5) * 180 / n
        b.box(2 * rm * math.sin(math.pi / (2 * n)) * 1.2, depth, fw, cx + rm * math.cos(math.radians(a)), yf,
              zb + h - r + rm * math.sin(math.radians(a)), frame, bevel=0.01, rot=(0, -(a + 90), 0), center=True)
    b.box(0.035, 0.05, h - 0.03, cx, y - 0.04, zb, frame, bevel=0)
    b.box(w, 0.05, 0.035, cx, y - 0.04, zb + (h - r) * 0.62, frame, bevel=0)
    if sill:
        b.box(w + 0.24, 0.16, 0.06, cx, y - 0.08, zb - 0.06, "wood_b", bevel=0.015)


def round_window(b, cx, y, zc, r=0.24, frame=TRIM_T, cross=True, lining=0.12):
    """Surface-mounted round (porthole) window on a wall face at y."""
    b.cyl(r, 0.03, cx, y - 0.01, zc, "glow_window", segs=12, rot=(90, 0, 0), center=True)
    b.torus(r + 0.035, 0.05, cx, y - 0.045, zc, frame, segs=12, ring=6, rot=(90, 0, 0))
    b.cyl(r + 0.07, lining, cx, y + lining / 2 - 0.03, zc, frame, segs=12, rot=(90, 0, 0), center=True, cap=False)  # lining into the wall
    if cross:
        b.box(0.035, 0.04, 2 * r, cx, y - 0.04, zc - r, frame, bevel=0)
        b.box(2 * r, 0.04, 0.035, cx, y - 0.04, zc - 0.0175, frame, bevel=0)


WIN_ZB, WIN_H, WIN_W = 0.8, 0.72, 0.62           # window opening in straight walls


def through_window(b, x, w=WIN_W, zb=WIN_ZB, h=WIN_H, outside=False):
    """Window filling a wall opening (wall centred on local y=0, front at -Y): glow pane, lining,
    mullions, sill; outside=True adds a head trim and shutters on the front face."""
    b.box(w, 0.03, h, x, 0, zb, "glow_window", bevel=0)
    for s in (-1, 1):
        b.box(0.07, T + 0.03, h, x + s * (w / 2 + 0.035), 0, zb, TRIM_T, bevel=0.01)
        b.box(0.04, 0.03, h, x, s * 0.03, zb, TRIM_T, bevel=0)
        b.box(w, 0.03, 0.04, x, s * 0.03, zb + h / 2 - 0.02, TRIM_T, bevel=0)
    b.box(w + 0.14, T + 0.03, 0.07, x, 0, zb + h, TRIM_T, bevel=0.01)
    b.box(w + 0.3, T + 0.1, 0.06, x, -0.04, zb - 0.07, "wood_b", bevel=0.015)
    if outside:
        b.box(w + 0.3, 0.1, 0.1, x, -T / 2 - 0.04, zb + h, TRIM_T, bevel=0.015)
        for s in (-1, 1):
            b.box(w * 0.42, 0.04, h + 0.06, x + s * (w * 0.5 + 0.2), -T / 2 - 0.03, zb - 0.03, DOOR_T, bevel=0.012)


# =============================================================================== modules
COURSE, BLOCK = 0.25, 0.5          # cream stone block courses on wall modules
BLOCKS = (WALL_T, "plaster_shade", WALL_T, "plaster")   # one engine tint (wall) with baked shade


_core_n = [0]


def _core_inset():
    """Cycle 2-8 mm insets so overlapping mortar cores (wall corners, curved joints) never share a plane."""
    _core_n[0] += 1
    return 0.002 + 0.0015 * (_core_n[0] % 5)


def blocks(b, x0, x1, z0, z1, depth=T, y=0.0, seed=0):
    """Fill the rectangle x0..x1, z0..z1 of a wall face with staggered stone blocks (courses on an
    absolute COURSE grid, joints on a BLOCK grid offset every other course). A slightly thinner
    mortar core fills the area so the joints read as recessed lines, never as see-through cracks."""
    e = _core_inset()
    b.box(x1 - x0 - 2 * e, depth - 0.03 - e, z1 - z0 - 2 * e - 0.01, (x0 + x1) / 2, y, z0 + e + 0.005, "plaster_shade", bevel=0)
    k = math.floor(z0 / COURSE + 1e-6)
    while k * COURSE < z1 - 1e-4:
        za, zb = max(z0, k * COURSE), min(z1, (k + 1) * COURSE)
        off = (BLOCK / 2) * (k % 2)
        j = math.floor((x0 - off) / BLOCK + 1e-6)
        while off + j * BLOCK < x1 - 1e-4:
            xa, xb = max(x0, off + j * BLOCK), min(x1, off + (j + 1) * BLOCK)
            if xb - xa > 0.02 and zb - za > 0.02:
                b.box(xb - xa - 0.01, depth, zb - za - 0.01, (xa + xb) / 2, y, za + 0.005, pick(BLOCKS, k * 3 + j * 5 + seed),
                      bevel=0.018)
            j += 1
        k += 1


def block_wall(b, L, H, openings=(), timber=True, cap=None):
    """Stone-block wall along X centred at x=0 (thickness T on y=0, bottom z=0) with rectangular
    holes openings [(cx, w, zb, zt)], like buildings.masonry_wall but in block courses."""
    levels = sorted({0.0, H} | {o[2] for o in openings} | {o[3] for o in openings})
    levels = [l for l in levels if 0 <= l <= H]
    for lo, hi in zip(levels, levels[1:]):
        if hi - lo < 1e-4:
            continue
        cuts = sorted((cx - w / 2, cx + w / 2) for cx, w, zb, zt in openings if zb < (lo + hi) / 2 < zt)
        x = -L / 2
        for a, c in cuts + [(L / 2, L / 2)]:
            if a > x + 1e-4:
                blocks(b, x, a, lo, hi, seed=int(L * 10))
            x = max(x, c)
    if timber:
        for sgn in (-1, 1):
            b.box(L + 0.02, 0.07, 0.14, 0, sgn * (T / 2 + 0.03), H - 0.14, "wood_dark", bevel=0.015)
    if cap:
        b.box(L + 0.02, T + 0.06, 0.1, 0, 0, H, cap, bevel=0.02)


def floor_tile(b, kind="wood", seed=0):
    """One CELL x CELL floor tile, pivot on its min corner, top at FLOOR (wood / stone / snow)."""
    c = CELL
    if kind == "wood":
        b.box(c, c, FLOOR - 0.06, c / 2, c / 2, 0, "wood_dark", bevel=0.01)
        for i in range(2):
            b.box(c - 0.012, c / 2 - 0.012, 0.06, c / 2, c / 4 + i * c / 2, FLOOR - 0.06, pick(WOODS, seed * 3 + i), bevel=0.01)
    elif kind == "stone":
        b.box(c - 0.014, c - 0.014, FLOOR, c / 2, c / 2, 0, pick(("paving", "paving_b", "stone"), seed), bevel=0.025)
    else:
        b.box(c - 0.01, c - 0.01, FLOOR, c / 2, c / 2, 0, pick(("snow", "snow", "snow_shade"), seed), bevel=0.035)


def floor_sector(b, R, arc=45.0, ring=0.26, seed=0):
    """Wedge of a round floor: pivot on the circle centre, spanning -arc/2..+arc/2 about +X.
    Concentric boards on a dark sub-floor, top at FLOOR."""
    a0, a1 = math.radians(-arc / 2), math.radians(arc / 2)
    na = max(2, int(arc / 7.5))
    rim = [(R * math.cos(a0 + (a1 - a0) * k / na), R * math.sin(a0 + (a1 - a0) * k / na)) for k in range(na + 1)]
    b.prism([(0, 0)] + rim, FLOOR - 0.06, z=0, mat="wood_dark", plane="xy")
    b.prism([(0, 0), (0.2 * math.cos(a0), 0.2 * math.sin(a0)), (0.2 * math.cos(a1), 0.2 * math.sin(a1))], 0.06,
            z=FLOOR - 0.06, mat="wood_c", plane="xy")
    r, k = 0.21, 0
    while r < R - 0.03:
        r1 = min(R, r + ring)
        nb = max(1, round(math.radians(arc) * (r + r1) / 2 / 0.6))
        for j in range(nb):
            g0 = 0.006 / r
            b0 = a0 + (a1 - a0) * j / nb + g0
            b1 = a0 + (a1 - a0) * (j + 1) / nb - g0
            arcp = lambda rr, s0, s1: [(rr * math.cos(s0 + (s1 - s0) * q / 3), rr * math.sin(s0 + (s1 - s0) * q / 3)) for q in range(4)]
            pts = arcp(r + 0.006, b0, b1) + arcp(r1 - 0.006, b1, b0)
            b.prism(pts, 0.06, z=FLOOR - 0.06, mat=pick(WOODS, k * 3 + j + seed), plane="xy")
        r, k = r1, k + 1


def straight_wall(b, kind="plain", L=1.0, H=WALL_H, outside=True, lip=False, posts=True, mat=WALL_T, hinge=True):
    """Straight wall module from x=0 to x=L (pivot on the left seam), centred on y=0, bottom z=0,
    front -Y. kind: plain | door | window | window_round; lip=True: cutaway-height lip with cap."""
    with b.at((L / 2, 0, 0)):
        if lip:
            block_wall(b, L, LIP_H, timber=False, cap="wood_c")
        elif kind == "door":
            block_wall(b, L, H, openings=[(0, 0.98, 0, 1.68)])
            arched_door(b, 0, -T / 2, 0, w=0.78, h=1.55, fw=0.1, depth=T + 0.04, socket=False, hinge=hinge,
                        fill=WALL_T, fill_top=1.68, thick=T)
        elif kind == "window":
            block_wall(b, L, H, openings=[(0, WIN_W, WIN_ZB, WIN_ZB + WIN_H)])
            through_window(b, 0, outside=outside)
        else:
            block_wall(b, L, H)
            if kind == "window_round":
                round_window(b, 0, -T / 2, 1.15, r=0.22)
    if posts and not lip:
        for x in (0.0, L):
            b.box(0.12, T + 0.06, H, x, 0, 0, TRIM_T, bevel=0.015)


def wall_run(b, pieces, H=WALL_H, outside=True, lip=False, mat=WALL_T):
    """Lay straight wall modules end to end along local X, centred on x=0. pieces: [(kind, L)].
    Returns [(kind, centre_x, L)] for slots and openings."""
    x = -sum(L for _, L in pieces) / 2
    out = []
    for kind, L in pieces:
        with b.at((x, 0, 0)):
            straight_wall(b, kind, L, H, outside, lip, mat=mat)
        out.append((kind, x + L / 2, L))
        x += L
    return out


def curved_wall(b, R, n, kind="plain", H=2.0, facing="out", thick=T, mat=PLASTER, base=True, band=True, cap=None,
                lip=False, low_h=0.45, door_kw=None, win_kw=None, i=0):
    """One segment (arc 360/n) of a round wall of outer radius R; pivot on the circle centre,
    centred on +X. kind: plain | door | window. facing='in' puts the door/window face inside."""
    rm = R - thick / 2
    wseg = 2 * R * math.tan(math.pi / n) + 0.01
    hh = low_h if lip else H
    with b.at((rm, 0, 0), rotz=90 if facing == "out" else -90):
        if kind == "door" and not lip:
            kw = dict(w=0.78, h=1.55, fw=0.11)
            kw.update(door_kw or {})
            dt = kw["h"] + kw["fw"]
            _curved_fill(b, wseg, dt, hh, thick, mat, i)
            arched_door(b, 0, -thick / 2, 0, socket=False, fill=pick(mat, i) if mat is not PLASTER else WALL_T,
                        fill_top=dt, thick=thick, **kw)
        else:
            _curved_fill(b, wseg, 0.0, hh, thick, mat, i)
            if base:
                b.box(wseg + 0.01, thick + 0.07, 0.3, 0, 0, 0, pick(("stone", "stone_dark", "paving_b"), i), bevel=0.03)
            if kind == "window" and not lip:
                kw = dict(w=0.52, h=0.72)
                kw.update(win_kw or {})
                arched_window(b, 0, -thick / 2, 0.85, **kw)
        if band and not lip:
            b.box(wseg + 0.01, thick + 0.08, 0.13, 0, 0, hh - 0.13, TRIM_T, bevel=0.015)
        if cap and lip:
            b.box(wseg + 0.01, thick + 0.05, 0.07, 0, 0, hh, cap, bevel=0.02)


def _curved_fill(b, w, z0, z1, thick, mat, i):
    """Solid part of a curved segment: block courses for the plaster families, one slab for others
    (e.g. the lighthouse stripes, which read as painted bands)."""
    if mat is PLASTER:
        e = _core_inset()
        b.box(w - 2 * e, thick - 0.03 - e, z1 - z0 - 2 * e - 0.01, 0, 0, z0 + e + 0.005, "plaster_shade", bevel=0)  # mortar core
        k = math.floor(z0 / COURSE + 1e-6)
        while k * COURSE < z1 - 1e-4:
            za, zb = max(z0, k * COURSE), min(z1, (k + 1) * COURSE)
            s = w * (0.22 if (k + i) % 2 else -0.22)
            for xa, xb in ((-w / 2, s), (s, w / 2)):
                b.box(xb - xa - 0.01, thick, zb - za - 0.01, (xa + xb) / 2, 0, za + 0.005, pick(BLOCKS, k * 3 + i * 7 + (xa > -w / 2)),
                      bevel=0.018)
            k += 1
    else:
        b.box(w, thick, z1 - z0, 0, 0, z0, pick(mat, i), bevel=0.02)


def ring_wall(b, R, H, n, z0=0.0, doors=(), windows=(), low=None, offset=None, **kw):
    """Round wall assembled from n curved_wall modules. doors / windows: angles (deg); low(angle)
    -> True makes that segment a cutaway lip. Returns [(angle, kind, lip)] per segment."""
    step = 360 / n
    off = offset if offset is not None else (doors[0] % step if doors else 0.0)
    near = lambda a, t: abs((a - t + 180) % 360 - 180) <= step / 2
    segs = []
    for i in range(n):
        a = off + step * i
        lip = low(a % 360) if low else False
        kind = "door" if any(near(a, d) for d in doors) else "window" if any(near(a, w) for w in windows) else "plain"
        with b.at((0, 0, z0), rotz=a):
            curved_wall(b, R, n, kind if not lip else "plain", H, lip=lip, i=i, **kw)
        segs.append((a, kind if not lip else "plain", lip))
    return segs


def round_floor(b, R, slab=True, sectors=8):
    """Round floor of `sectors` floor_sector modules (+ stone plinth). Pivot = circle centre."""
    if slab:
        b.cyl(R + 0.18, FLOOR - 0.05, 0, 0, 0, "stone_dark", segs=24, bevel=0.03)
    for k in range(sectors):
        with b.at((0, 0, 0), rotz=(k + 0.5) * 360 / sectors):
            floor_sector(b, R, 360 / sectors, seed=k)


def lighthouse_floor(b, R=2.4 + T / 2, rail=True):
    """Lighthouse curved floor module: 8 floor sectors inside a ring of stone rim blocks, with an
    optional rope rail on short posts (gallery / tower landing use). Pivot = circle centre."""
    round_floor(b, R, slab=False)
    n = 20
    for k in range(n):
        a = 360 * (k + 0.5) / n
        with b.at((0, 0, 0), rotz=a):
            b.box(0.3, 2 * (R + 0.15) * math.tan(math.pi / n) + 0.01, FLOOR + 0.08, R + 0.15, 0, 0,
                  pick(("stone", "stone_dark", "paving_b"), k), bevel=0.03)
    if rail:
        pts = []
        for k in range(8):
            a = math.radians(360 * k / 8 + 22.5)
            p = (R + 0.15) * math.cos(a), (R + 0.15) * math.sin(a)
            b.box(0.12, 0.12, 0.62, p[0], p[1], FLOOR + 0.08, "wood_b", bevel=0.02)
            pts.append((p[0], p[1], FLOOR + 0.62))
        for p0, p1 in zip(pts, pts[1:] + pts[:1]):
            rope_between(b, p0, p1, sag=0.1, r=0.022)


def rect_floor(b, W, D, kind="wood"):
    """Rect floor of floor_tile modules on the room's cell grid (corner at -W/2, -D/2) + plinth."""
    b.box(W + 0.5, D + 0.5, FLOOR - 0.05, 0, 0, 0, "stone_dark", bevel=0.03)
    for ix in range(round(W / CELL)):
        for iy in range(round(D / CELL)):
            with b.at((-W / 2 + ix * CELL, -D / 2 + iy * CELL, 0)):
                floor_tile(b, kind, seed=ix * 5 + iy * 3)


def stair_flight(b, run=2.75, rise=1.9, w=0.78, steps=10, rails=True):
    """Stair module: pivot at the centre of the foot (y=0, z=0), climbing toward +Y to (run, rise)."""
    for i in range(steps):
        yy = run * (i + 0.5) / steps
        zz = rise * (i + 1) / steps - 0.06
        b.box(w, run / steps + 0.03, 0.06, 0, yy, zz, pick(WOODS, i), bevel=0.012)
        b.box(w - 0.06, 0.03, rise / steps, 0, yy - run / steps / 2 + 0.03, zz - rise / steps + 0.06, "wood_dark", bevel=0)
    for sx in (-1, 1):
        beam(b, (sx * (w / 2 + 0.03), 0, 0.0), (sx * (w / 2 + 0.03), run, rise), 0.06, 0.16, "wood_b", 0.012)
    if rails:
        for sx in (-1, 1):
            for t in (0.0, 0.5, 1.0):
                snow_post(b, sx * (w / 2 + 0.06), run * t, rise * t, h=0.75, w=0.09)
            beam(b, (sx * (w / 2 + 0.06), 0, 0.7), (sx * (w / 2 + 0.06), run, rise + 0.7), 0.05, 0.07, "wood", 0.01)


def landing(b, y0, z, w=1.0, d=1.0):
    """Landing platform at the top of a flight: deck at z from y0 to y0+d, posts, rails."""
    b.box(w, d, 0.12, 0, y0 + d / 2, z - 0.12, "wood_dark", bevel=0.02)
    planks(b, w, d, z=z - 0.04, plank=0.2, thick=0.04, along="x", y=y0 + d / 2)
    for sx in (-1, 1):
        for yy in (y0 + 0.08, y0 + d - 0.08):
            b.box(0.12, 0.12, z - 0.12, sx * (w / 2 - 0.06), yy, 0, "wood_b", bevel=0.02)
    rail_run(b, (-w / 2 + 0.06, y0 + d - 0.06), (w / 2 - 0.06, y0 + d - 0.06), z, posts=2)
    rail_run(b, (w / 2 - 0.06, y0 + 0.3), (w / 2 - 0.06, y0 + d - 0.06), z, posts=2)
    b.box(0.1, 0.1, 1.0, -w / 2 + 0.06, y0 + d - 0.06, z + 0.7, "wood_b", bevel=0.015)        # lantern post
    b.box(0.32, 0.06, 0.06, -w / 2 + 0.2, y0 + d - 0.06, z + 1.62, "wood_b", bevel=0.01)
    with b.part("landing_lantern", pivot=(-w / 2 + 0.33, y0 + d - 0.06, z + 1.6), motion="sway", amp_deg=4):
        b.box(0.03, 0.03, 0.14, -w / 2 + 0.33, y0 + d - 0.06, z + 1.46, "iron", bevel=0)
        lantern_head(b, -w / 2 + 0.33, y0 + d - 0.06, z + 1.1, 0.8)


def treehouse_support(b, crown_z=3.6):
    """Tree trunk with root flares and limbs (pivot = trunk base centre)."""
    b.cyl(0.62, 4.6, 0, 0, 0, "bark", segs=9, r2=0.38, jitter=0.03)
    for k in range(6):
        a = 360 * k / 6 + 15
        r = math.radians(a)
        b.cyl(0.26, 0.9, 0.45 * math.cos(r), 0.45 * math.sin(r), -0.05, "bark", segs=6, r2=0.06, rot=(0, 62, a), jitter=0.02)
    for (az, el, L) in ((150, 40, 1.7), (40, 45, 1.6), (260, 50, 1.3), (95, 35, 1.5)):
        with b.at((0, 0, crown_z), rot=(0, 90 - el, az)):
            b.cyl(0.17, L, 0, 0, 0, "bark", segs=6, r2=0.08)
    # cross beam through the trunk with a brace and a hanging lantern (faces -Y)
    b.box(2.2, 0.18, 0.2, 0.55, 0, 1.45, "wood_b", bevel=0.025)
    b.torus(0.6, 0.05, 0, 0, 1.5, "rope", segs=12, ring=5)
    beam(b, (0.35, 0, 0.75), (1.2, 0, 1.45), 0.12, 0.12, "wood_b")
    rope_between(b, (1.5, 0, 1.45), (1.5, 0, 1.15), sag=0.0, r=0.015, segs=2)
    with b.part("hanging_lantern", pivot=(1.5, 0, 1.45), motion="sway", amp_deg=5):
        lantern_head(b, 1.5, 0, 0.8, 0.85)


def treehouse_deck(b, W, D, DZ, trunk=(-0.8, 0.5), stair_gap=0.95):
    """Deck platform module, pivot = deck centre on the ground: frame, planks, posts and braces
    (two braces run to the trunk at `trunk`, relative to the deck centre), rails with a stair gap
    at the front-right corner."""
    x0, x1, y0, y1 = -W / 2, W / 2, -D / 2, D / 2
    b.box(W, D, 0.12, 0, 0, DZ - 0.2, "wood_dark", bevel=0.02)
    planks(b, W, D, z=DZ - 0.08, plank=0.22, thick=0.08, along="x")
    for x, y in ((x1 - 0.15, y0 + 0.15), (x1 - 0.15, y1 - 0.15), (x0 + 0.15, y0 + 0.15)):
        b.box(0.18, 0.18, DZ - 0.2, x, y, 0, "wood_b", bevel=0.025)
        beam(b, (x, y, DZ - 0.75), (x + (0.6 if x < 0 else -0.6), y, DZ - 0.2), 0.1, 0.1, "wood_b")
    tx, ty = trunk
    beam(b, (tx + 0.4, ty - 0.3, 0.9), (0.4, y0 + 0.2, DZ - 0.22), 0.12, 0.12, "wood_b")
    beam(b, (tx + 0.45, ty, 1.0), (x1 - 0.3, 0, DZ - 0.22), 0.12, 0.12, "wood_b")
    rail_run(b, (x0 + 0.08, y0 + 0.08), (x1 - stair_gap, y0 + 0.08), DZ, posts=4)
    rail_run(b, (x0 + 0.08, y0 + 0.08), (x0 + 0.08, y1 - 0.1), DZ, posts=3)
    rail_run(b, (x1 - 0.08, y0 + stair_gap), (x1 - 0.08, y1 - 0.08), DZ, posts=3)
    snow_lumps(b, 0, y0 + 0.3, DZ, W - 0.8, 0.3, 4, r=(0.07, 0.12))


def _hull_stations(sx=1.0):
    return [(x * sx, hw, sh, bt) for x, hw, sh, bt in (  # x, half-beam, sheer z, bottom z (relative to the hull frame)
        (-2.7, 1.18, 0.24, -0.72), (-2.1, 1.3, 0.2, -0.8), (-1.0, 1.32, 0.18, -0.84), (0.0, 1.32, 0.18, -0.84),
        (1.0, 1.28, 0.2, -0.82), (1.85, 1.08, 0.28, -0.72), (2.45, 0.66, 0.4, -0.52), (2.85, 0.08, 0.55, -0.16))]


HULL_Z = WATER_Z + 0.62           # hull frame height (waterline ~0.62 below it)
BOAT_DECK = HULL_Z + 0.12         # boat deck top


def houseboat_hull(b, sx=1.0):
    """Lofted hull (stern -X, bow +X) with gunwale cap and rub rail. Pivot = boat centre, z in
    world terms (water at WATER_Z). sx stretches the hull along its length."""
    st = _hull_stations(sx)
    sec = lambda hw, sh, bt: [(-hw, sh), (-hw * 0.97, (sh + bt) / 2 + 0.06), (-hw * 0.72, bt + 0.08), (0, bt),
                              (hw * 0.72, bt + 0.08), (hw * 0.97, (sh + bt) / 2 + 0.06), (hw, sh)]
    with b.at((0, 0, HULL_Z)):
        vs, rows = [], []
        for x, hw, sh, bt in st:
            rows.append(list(range(len(vs), len(vs) + 7)))
            vs += [(x, y, z) for y, z in sec(hw, sh, bt)]
        f = []
        for r0, r1 in zip(rows, rows[1:]):
            f += [(r0[k], r0[k + 1], r1[k + 1], r1[k]) for k in range(6)]
        f.append(tuple(reversed(rows[0])))
        f.append(tuple(rows[-1]))
        b.mesh(vs, f, HULL_T)
        for side in (-1, 1):
            for (x0, hw0, sh0, _), (x1, hw1, sh1, _) in zip(st, st[1:]):
                beam(b, (x0, side * hw0, sh0 + 0.03), (x1, side * hw1, sh1 + 0.03), 0.12, 0.08, TRIM_T, 0.012)
                beam(b, (x0, side * (hw0 * 0.995 + 0.012), sh0 - 0.13), (x1, side * (hw1 * 0.995 + 0.012), sh1 - 0.13),
                     0.035, 0.16, tint("hull_band", "teal"), 0.01)
                beam(b, (x0, side * (hw0 + 0.02), sh0 - 0.32), (x1, side * (hw1 + 0.02), sh1 - 0.3), 0.08, 0.1, "wood_dark", 0.01)
        for k in range(8):                                     # life ring on the port side
            a0, a1 = 2 * math.pi * k / 8, 2 * math.pi * (k + 1) / 8
            seg = [(1.25 * sx + 0.2 * math.cos(a0 + (a1 - a0) * q / 2), -1.36, 0.0 + 0.2 * math.sin(a0 + (a1 - a0) * q / 2)) for q in range(3)]
            for p0, p1 in zip(seg, seg[1:]):
                beam(b, p0, p1, 0.08, 0.08, tint("ring", "coral") if k % 2 else "white", 0.01)


def houseboat_deck(b, gap_x=-0.45, sx=1.0):
    """Deck planks clipped to the hull plan, rope rail on snow-capped posts (gap at gap_x for the
    gangway) and the stern flag pole. Pivot = boat centre."""
    z = BOAT_DECK
    for i in range(11):
        y = -1.15 + 0.23 * (i + 0.5)
        x1 = (2.0 - 1.4 * (abs(y) / 1.2) ** 2) * sx
        x0 = 2.6 * sx
        b.box(x1 + x0, 0.22, 0.06, (x1 - x0) / 2, y, z - 0.06, pick(WOODS, i), bevel=0.01)
    pts = [(x * sx, y) for x, y in ((-2.45, -1.05), (-1.2, -1.2), (1.0, -1.18), (1.9, -0.95), (2.45, -0.5))]
    for x, y in pts:
        snow_post(b, x, y, z, h=0.62, w=0.1)
        snow_post(b, x, -y, z, h=0.62, w=0.1)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if not (x0 < gap_x < x1):
            rope_between(b, (x0, y0, z + 0.5), (x1, y1, z + 0.5), sag=0.08, r=0.022)
        rope_between(b, (x0, -y0, z + 0.5), (x1, -y1, z + 0.5), sag=0.08, r=0.022)
    fx = -2.55 * sx
    b.cyl(0.04, 1.6, fx, 0.0, z, "wood_b", segs=6)
    with b.part("flag", pivot=(fx, 0, z + 1.58), motion="flutter", amp_deg=12):
        b.prism([(0, 0), (0.55, -0.12), (0, -0.32)], 0.02, x=fx, y=0, z=z + 1.58, mat=tint("flag", "cream"))


# =============================================================================== roof sections
DOME_R, DOME_TH, DOME_HB = 2.3, 0.3, 0.55


def dome_blocks(main, roof, R=DOME_R):
    """Ice-block dome: rings below 1.45 m go to `main`, the upper rings to `roof`. Block size is
    fixed (about 0.66 m wide, HB tall), so a bigger R gets more blocks rather than bigger ones."""
    TH, HB = DOME_TH, DOME_HB
    dphi = HB / R
    door_half = lambda rr: math.asin(min(1, 0.72 / rr))
    for k in range(8):
        phi = (k + 0.5) * dphi
        if phi > math.radians(63):
            break
        rc = (R - TH / 2) * math.cos(phi)
        zc = (R - TH / 2) * math.sin(phi)
        cnt = max(5, round(2 * math.pi * R * math.cos(phi) / 0.66))
        tgt = roof if zc > 1.45 else main
        for c in range(cnt):
            a = 2 * math.pi * (c + 0.5 * (k % 2)) / cnt
            if zc < 1.75 and abs((a - 1.5 * math.pi + math.pi) % (2 * math.pi) - math.pi) < door_half(rc):
                continue  # entrance opening at the front
            with tgt.at((rc * math.cos(a), rc * math.sin(a), zc), rotz=math.degrees(a) + 90):
                tgt.box(2 * math.pi * R * math.cos(phi) / cnt * 1.03, TH, HB * 1.04, 0, 0, 0, pick(ICE, k * 7 + c * 3),
                        bevel=0.06, rot=(-math.degrees(phi), 0, 0), center=True, jitter=0.012)


def dome_roof(roof, R=DOME_R):
    """Snow dome removable top: upper block rings, ice cap, snow, chimney. The cap and chimney
    grow with R so the bigger dome's top stays closed."""
    g = R / DOME_R
    dome_blocks(Builder("_scratch"), roof, R)
    zcap = R - 0.52
    roof.blob(1.18 * g, 1.18 * g, 0.56, 0, 0, zcap, ICE[0], subdiv=2, jitter=0.02)
    roof.blob(0.92 * g, 0.86 * g, 0.2, 0.05, 0.1, zcap + 0.42, "snow", subdiv=2, jitter=0.02)
    for k, (a, s) in enumerate(((40, 0.62), (130, 0.55), (210, 0.6), (300, 0.5))):
        phi = math.radians(52)
        p = (R * math.cos(phi) * math.cos(math.radians(a)), R * math.cos(phi) * math.sin(math.radians(a)), R * math.sin(phi))
        with roof.at(p, rotz=a + 90):
            roof.blob(s * 0.8 * g, s * 0.6 * g, 0.07, 0, -0.02, 0, pick(SNOW, k), subdiv=2, rot=(-52, 0, 0), jitter=0.01)
    chimney_stone(roof, 0.95 * g, 0.85 * g, 1.4, 2.95 + (R - DOME_R))


AF = dict(SPAN=4.4, LEN=4.4, KNEE=0.9, RISE=4.2, SLAB=0.2)


def aframe_roof(roof):
    SPAN, LEN, RISE = AF["SPAN"], AF["LEN"], AF["RISE"]
    ZE = AF["SLAB"] + AF["KNEE"]
    half = SPAN / 2
    tiled_gable(roof, SPAN, LEN, RISE, z=ZE, overhang=0.32, tile=0.46, tile_thick=0.11, gable=None, timber=False)
    slope_snow(roof, SPAN, LEN, RISE, ZE, -1, ((0.35, -1.2), (0.6, 0.6), (0.85, -0.3), (0.2, 1.5)), overhang=0.32, size=1.5)
    slope_snow(roof, SPAN, LEN, RISE, ZE, 1, ((0.8, -1.4), (0.45, 1.6), (0.15, -0.9), (0.6, -0.2)), overhang=0.32, size=1.5)
    ridge_snow_on(roof, SPAN, LEN + 0.64, RISE, ZE, tile_thick=0.11, w=0.48)
    xf = 1.55                                                      # dormer front face (world x), faces +X
    zf = ZE + (half - xf) * RISE / half
    with roof.at((xf - 0.35, 0.4, zf - 0.05), rotz=90):
        roof.box(1.0, 1.5, 1.2, 0, 0.4, 0, WALL_T, bevel=0.02)
        arched_window(roof, 0, -0.35, 0.3, w=0.5, h=0.62)
        with roof.at((0, 0.4, 0)):
            tiled_gable(roof, 1.0, 1.5, 0.5, z=1.2, overhang=0.16, tile=0.3, tile_thick=0.07, gable=WALL_T, timber=False)
            ridge_snow_on(roof, 1.0, 1.8, 0.5, 1.2, tile_thick=0.07, w=0.24)
    chimney_stone(roof, -1.15, 1.0 + (LEN - 4.4) / 2, ZE + 0.6, ZE + RISE * 0.9)


RC = dict(R=2.2, H=1.9, SLAB=0.22, RISE=1.55)


def round_cottage_roof(roof):
    R, H, SLAB, RISE = RC["R"], RC["H"], RC["SLAB"], RC["RISE"]
    cone_roof(roof, R, RISE, SLAB + H, overhang=0.4, seed=7)
    g = R / 2.2
    roof.box(0.5, 0.5, 1.2, 0.85 * g, 0.7 * g, SLAB + H + 0.3, "chimney", bevel=0.03)
    chimney_stone(roof, 0.85 * g, 0.7 * g, SLAB + H + 0.6, SLAB + H + RISE + 0.35)


TH_ = dict(DZ=1.9, TX=-1.25, TY=0.65, CW=2.5, CD=2.0, CH=WALL_H, CX=0.45, CY=0.25)


def treehouse_roof(roof):
    DZ, CW, CD, CH, CX, CY = TH_["DZ"], TH_["CW"], TH_["CD"], TH_["CH"], TH_["CX"], TH_["CY"]
    with roof.at((CX, CY, 0)):
        tiled_gable(roof, CW, CD, 0.95, z=DZ + CH, overhang=0.3, tile=0.36, tile_thick=0.09, gable=WALL_T, timber=True)
        ridge_snow_on(roof, CW, CD + 0.6, 0.95, DZ + CH)
        slope_snow(roof, CW, CD, 0.95, DZ + CH, -1, ((0.5, -0.5), (0.4, 0.6)))
        slope_snow(roof, CW, CD, 0.95, DZ + CH, 1, ((0.55, 0.0),))
        chimney_stone(roof, -0.55, 0.45, DZ + CH + 0.2, DZ + CH + 1.35, w=0.38)


LH = dict(TX=-0.85, TY=0.35, TOWER=4.3, R0=1.25, R1=0.92, CW=2.5, CD=2.0, CH=WALL_H, SLAB=0.18, CX=1.35, CY=-0.25)


def lighthouse_lantern(roof):
    """Lighthouse lantern room and domed cap (removable top of the tower)."""
    TX, TY, R1 = LH["TX"], LH["TY"], LH["R1"]
    LZ = LH["TOWER"] + 0.14
    roof.cyl(0.78, 0.3, TX, TY, LZ, WALL_T, segs=8, bevel=0.02)
    roof.cyl(0.66, 0.78, TX, TY, LZ + 0.3, "glow", segs=8)
    for k in range(8):
        a = 2 * math.pi * (k + 0.5) / 8
        roof.box(0.06, 0.06, 0.78, TX + 0.66 * math.cos(a), TY + 0.66 * math.sin(a), LZ + 0.3, "iron", bevel=0)
    roof.cyl(0.74, 0.08, TX, TY, LZ + 1.08, "iron", segs=8)
    roof.cyl(0.86, 0.5, TX, TY, LZ + 1.16, ROOF_T[0], segs=8, r2=0.14, bevel=0.02)
    for k in range(8):
        a = 2 * math.pi * k / 8
        beam(roof, (TX + 0.84 * math.cos(a), TY + 0.84 * math.sin(a), LZ + 1.18),
             (TX + 0.15 * math.cos(a), TY + 0.15 * math.sin(a), LZ + 1.66), 0.05, 0.05, ROOF_T[1], 0.008)
    roof.sphere(0.12, TX, TY, LZ + 1.75, "gold", u=6, v=4)
    roof.cyl(0.02, 0.25, TX, TY, LZ + 1.8, "iron", segs=4)
    roof.blob(0.42, 0.4, 0.09, TX - 0.1, TY + 0.1, LZ + 1.42, "snow", subdiv=1, jitter=0.01)


def lighthouse_cottage_roof(roof):
    CX, CY, CW, CD, CH, SLAB = LH["CX"], LH["CY"], LH["CW"], LH["CD"], LH["CH"], LH["SLAB"]
    with roof.at((CX, CY, 0), rotz=90):
        tiled_gable(roof, CD, CW, 0.85, z=SLAB + CH, overhang=0.28, tile=0.36, tile_thick=0.09, gable=WALL_T, timber=False)
        ridge_snow_on(roof, CD, CW + 0.56, 0.85, SLAB + CH)
        slope_snow(roof, CD, CW, 0.85, SLAB + CH, 1, ((0.5, -0.6), (0.45, 0.7)))
        slope_snow(roof, CD, CW, 0.85, SLAB + CH, -1, ((0.5, 0.0),))


HB = dict(CW=3.0, CD=2.0, CH=WALL_H, CX=-0.45)


def houseboat_roof(roof):
    CW, CD, CH, CX = HB["CW"], HB["CD"], HB["CH"], HB["CX"]
    z = BOAT_DECK + CH
    with roof.at((CX, 0, 0), rotz=90):
        tiled_gable(roof, CD, CW, 0.75, z=z, overhang=0.32, tile=0.36, tile_thick=0.09, gable=WALL_T, timber=False)
        ridge_snow_on(roof, CD, CW + 0.64, 0.75, z)
        slope_snow(roof, CD, CW, 0.75, z, 1, ((0.45, -0.8), (0.55, 0.5)), overhang=0.32)
        slope_snow(roof, CD, CW, 0.75, z, -1, ((0.5, 0.1),), overhang=0.32)
    roof.cyl(0.07, 1.0, CX + 0.9, 0.45, z + 0.3, "iron", segs=8)            # stove pipe
    roof.cyl(0.12, 0.1, CX + 0.9, 0.45, z + 1.3, "iron", segs=8, r2=0.04)
    roof.socket("fx_smoke", (CX + 0.9, 0.45, z + 1.5))


def cone_roof(b, R, rise, z, overhang=0.35, tile=0.42, tw=0.36, thick=0.09, mats=ROOF_T, snow=True, seed=0):
    """Conical tiled roof over a round wall of radius R whose top is at z; apex at z+rise."""
    rng = random.Random(seed)
    th = math.atan2(rise, R)
    Re = R + overhang
    ze = z - overhang * math.tan(th)
    L = Re / math.cos(th)
    rows = max(3, round(L / tile))
    tl = L / rows
    b.cyl(Re, z + rise - ze, 0, 0, ze, mats[1], segs=20, r2=0.03)               # underlay closes the cone
    for r in range(rows):
        s = (r + 0.5) * tl
        rr = Re - s * math.cos(th)
        zz = ze + s * math.sin(th)
        cnt = max(6, round(2 * math.pi * rr / tw))
        for c in range(cnt):
            a = 2 * math.pi * (c + 0.5 * (r % 2)) / cnt
            nrm = Vector((math.cos(a) * math.sin(th), math.sin(a) * math.sin(th), math.cos(th)))
            p = Vector((rr * math.cos(a), rr * math.sin(a), zz)) + nrm * (thick / 2 + 0.012)
            with b.at(tuple(p), rotz=math.degrees(a) + 90):
                b.box(2 * math.pi * rr / cnt * 1.04, tl + 0.06, thick, 0, 0, 0, pick(mats, r * 5 + c * 3), bevel=0.02,
                      rot=(math.degrees(th) + 3, 0, 0), center=True)
    for k in range(20):  # rafter tails under the eave
        a = 2 * math.pi * (k + 0.5) / 20
        rr = R + overhang * 0.45
        zz = ze + (Re - rr) * math.tan(th) - 0.09
        with b.at((rr * math.cos(a), rr * math.sin(a), zz), rotz=math.degrees(a) + 90):
            b.box(0.08, overhang + 0.12, 0.09, 0, 0, 0, TRIM_T, bevel=0.012, rot=(math.degrees(th), 0, 0), center=True)
    b.cyl(0.14, 0.18, 0, 0, z + rise - 0.06, mats[1], segs=8, bevel=0.02)                     # apex cap
    b.sphere(0.07, 0, 0, z + rise + 0.16, "gold", u=6, v=4)
    if snow:
        rc, lift = 0.85, (thick + 0.05) / math.cos(th)
        b.cyl(rc, rc * math.tan(th), 0, 0, z + rise - rc * math.tan(th) + lift, "snow", segs=14, r2=0.05, jitter=0.01)
        for k in range(7):  # drifts settled on the tile ledges
            a = rng.uniform(0, 2 * math.pi)
            s = rng.uniform(0.25, 0.75) * L
            rr = Re - s * math.cos(th)
            nrm = Vector((math.cos(a) * math.sin(th), math.sin(a) * math.sin(th), math.cos(th)))
            c = Vector((rr * math.cos(a), rr * math.sin(a), ze + s * math.sin(th)))
            up = Vector((-math.cos(a) * math.cos(th), -math.sin(a) * math.cos(th), math.sin(th)))
            tang = Vector((-math.sin(a), math.cos(a), 0))
            snow_clump(b, c, nrm, up, tang, rot=(0, 0, 0), seed=k * 3 + seed, size=0.9)


def gable_facade(b, half, zeave, rise, openings=(), z0=0.0, thick=T, mat=WALL_T, y=0.0):
    """Pentagon wall in XZ at y (rectangle to zeave, triangle to zeave+rise) with rectangular holes
    openings [(x0, x1, zb, zt)], built from trapezoid slabs between the openings' levels."""
    def wid(z):
        return half if z <= zeave + 1e-6 else max(0.0, half * (1 - (z - zeave) / rise))
    top = zeave + rise
    levels = sorted({z0, zeave, top} | {o[2] for o in openings} | {o[3] for o in openings})
    levels = [l for l in levels if z0 - 1e-6 <= l <= top + 1e-6]
    for lo, hi in zip(levels, levels[1:]):
        if hi - lo < 1e-4:
            continue
        zm = (lo + hi) / 2
        cuts = sorted((o[0], o[1]) for o in openings if o[2] < zm < o[3])
        edges = [None] + cuts + [None]
        for left, right in zip(edges, edges[1:]):
            xl0 = left[1] if left else -wid(lo)
            xl1 = left[1] if left else -wid(hi)
            xr0 = right[0] if right else wid(lo)
            xr1 = right[0] if right else wid(hi)
            xl0, xr0 = max(xl0, -wid(lo)), min(xr0, wid(lo))
            xl1, xr1 = max(xl1, -wid(hi)), min(xr1, wid(hi))
            if xr0 - xl0 < 0.01:
                continue
            pts = [(xl0, lo), (xr0, lo)]
            if xr1 - xl1 < 0.005:
                pts.append(((xr1 + xl1) / 2, hi))
            else:
                pts += [(xr1, hi), (xl1, hi)]
            b.prism(pts, thick, x=0, y=y, z=0, mat=mat)


# =============================================================================== interior helpers
class Room:
    """Collects the grid, wall slots and ceiling anchors of an interior shell."""

    def __init__(self, b, inside, hx, hy, floor_z=FLOOR, corner=False):
        """corner=True anchors the grid at the room's (-hx, -hy) corner (rect rooms); otherwise the
        grid is centred on the origin (round rooms)."""
        self.b, self.inside, self.floor_z = b, inside, floor_z
        self.nx, self.ny = math.ceil(hx / CELL - 1e-6), math.ceil(hy / CELL - 1e-6)
        self.origin = (-hx, -hy) if corner else (-self.nx * CELL, -self.ny * CELL)
        self.blockers = []
        self.slots, self.anchors = {}, {}
        self.solids = []

    def solid(self, x0, x1, y0, y1):
        """A fixture the player can't walk through (stove, stairs, trunk); the game adds a collider."""
        self.solids.append([round(v, 3) for v in (x0, x1, y0, y1)])

    def block_circle(self, x, y, r):
        self.blockers.append(lambda cx, cy: math.hypot(cx - x, cy - y) < r)

    def block_rect(self, x0, x1, y0, y1):
        self.blockers.append(lambda cx, cy: x0 <= cx <= x1 and y0 <= cy <= y1)

    def centre(self, c):
        return self.origin[0] + (c[0] + 0.5) * CELL, self.origin[1] + (c[1] + 0.5) * CELL

    def cells(self, inside=None):
        inside = inside or self.inside
        ox, oy = self.origin
        out = []
        for ix in range(2 * self.nx + 1):
            for iy in range(2 * self.ny + 1):
                x0, y0 = ox + ix * CELL, oy + iy * CELL
                if all(inside(x, y) for x, y in ((x0, y0), (x0 + CELL, y0), (x0, y0 + CELL), (x0 + CELL, y0 + CELL))):
                    out.append([ix, iy])
        return out

    def wall_slot(self, pos, normal):
        name = f"wall_slot_{len(self.slots)}"
        nx, ny = normal
        self.b.socket(name, pos, rotz=math.degrees(math.atan2(nx, -ny)))  # item front (-Y) faces the room
        self.slots[name] = {"pos": [round(v, 3) for v in pos], "facing": [round(nx, 3), round(ny, 3)]}

    def anchor(self, pos):
        name = f"ceiling_{len(self.anchors)}"
        self.b.socket(name, pos)
        self.anchors[name] = [round(v, 3) for v in pos]

    def meta(self, **extra):
        cells = self.cells()
        blocked = [c for c in cells if any(f(*self.centre(c)) for f in self.blockers)]
        assert cells and len(blocked) < len(cells), "room grid is empty or fully blocked"
        m = {"cells": cells, "cell_origin": [round(v, 3) for v in self.origin], "cell_m": CELL,
             "floor_z": self.floor_z, "blocked_cells": blocked, "wall_slots": self.slots,
             "ceiling_anchors": self.anchors}
        if self.solids:
            m["solids"] = self.solids
        m.update(extra)
        return m


def low_front(a, center=315, half=95):
    """Cutaway sector of a round room (faces the +X,-Y camera)."""
    return abs((a - center + 180) % 360 - 180) <= half


def ring_slots(room, R, z, segs, skip=lambda a: False):
    """Wall slots at the centre of every full, plain segment of a round room."""
    for a, kind, lip in segs:
        if kind == "plain" and not lip and not skip(a % 360):
            r = math.radians(a)
            room.wall_slot((R * math.cos(r), R * math.sin(r), z), (-math.cos(r), -math.sin(r)))


def rect_room(b, W, D, back, left, H=WALL_H):
    """Interior walls of a W x D room from straight wall modules: full back (+Y) and left (-X)
    walls facing in, low lips on the front and right, corner posts. back/left: piece lists
    (left runs -Y to +Y). Returns the laid pieces {"back": [...], "left": [...]}."""
    with b.at((0, D / 2 + T / 2, 0)):                              # back wall, inner face at local -Y
        bk = wall_run(b, back, H, outside=False)
    with b.at((-W / 2 - T / 2, 0, 0), rotz=90):                    # left wall: local -Y faces +X (in)
        lf = wall_run(b, left, H, outside=False)
    with b.at((0, -D / 2 - T / 2, 0), rotz=180):
        wall_run(b, [("plain", 1.0)] * int(W) + [("plain", 0.5)] * round((W - int(W)) / 0.5), lip=True)
    with b.at((W / 2 + T / 2, 0, 0), rotz=90):
        wall_run(b, [("plain", 1.0)] * int(D) + [("plain", 0.5)] * round((D - int(D)) / 0.5), lip=True)
    b.box(T + 0.06, T + 0.06, H, -W / 2 - T / 2, D / 2 + T / 2, 0, TRIM_T, bevel=0.015)
    for sx, sy in ((-1, -1), (1, -1), (1, 1)):
        b.box(T, T, LIP_H, sx * (W / 2 + T / 2), sy * (D / 2 + T / 2), 0, WALL_T, bevel=0.02)
        b.box(T + 0.05, T + 0.05, 0.07, sx * (W / 2 + T / 2), sy * (D / 2 + T / 2), LIP_H, "wood_c", bevel=0.02)
    b.box(W, 0.04, 0.1, 0, D / 2 - 0.02, 0, "wood_dark", bevel=0.01)          # skirting
    b.box(0.04, D, 0.1, -W / 2 + 0.02, 0, 0, "wood_dark", bevel=0.01)
    return {"back": bk, "left": lf}


def rect_slots(room, W, D, z, laid, skip=lambda x, y: False):
    """Wall slots at the centre of every plain piece on the back and left walls."""
    for kind, x, L in laid["back"]:
        if kind == "plain" and not skip(x, D / 2):
            room.wall_slot((x, D / 2, z), (0, -1))
    for kind, y, L in laid["left"]:
        if kind == "plain" and not skip(-W / 2, y):
            room.wall_slot((-W / 2, y, z), (1, 0))


def door_y(laid):
    return next(c for k, c, _ in laid["left"] if k == "door")


def finish_house(b, roof, meta):
    meta.setdefault("color_variants", ROOF_VARIANTS)
    house = b.finish(KIT, "building", meta)
    attach(roof.finish(KIT, "roof"), house)
    return house


# =============================================================================== snow dome
# House upgrade tiers (docs/Housing - House Upgrades Plan.md). Every tier is the same igloo:
# block size, door, windows and dressing keep their size; only the radius, the block count,
# the wall segment count (about 1 m each) and the extra dressing change.
#   R / Ri     exterior dome / interior room radius      n        interior wall segments
#   base       snow island half extents                  windows  interior window bearings
#   ext_windows  exterior windows (bearing, elevation, kind)     anchors  ceiling hooks (x, y)
DOME_TIERS = {
    1: dict(name="snow_dome", R=DOME_R, Ri=2.3, n=16, base=(3.5, 3.2), rocks=7, firs=(), windows=(95,),
            ext_windows=((215, 30, "round"), (325, 26, "arch")), anchors=((0, 0), (-0.9, 0.7), (0.8, 0.8)),
            footprint=[7.0, 6.4]),
    2: dict(name="snow_dome_t2", R=3.0, Ri=3.0, n=20, base=(4.3, 3.95), rocks=9,
            firs=((-2.75, 2.45, 1.8), (2.7, 2.6, 1.5)), windows=(80, 120),
            ext_windows=((215, 30, "round"), (325, 26, "arch"), (165, 30, "round"), (20, 24, "arch")),
            anchors=((0, 0), (-1.3, 1.0), (1.1, 1.2), (-1.5, -0.6), (0.3, 2.0)), footprint=[8.6, 7.9]),
}


def woodpile(b, x, y, rotz=0.0):
    """Split logs stacked 3-2-1 under a snow cap."""
    with b.at((x, y, 0), rotz=rotz):
        for row, (count, z) in enumerate(((3, 0.07), (2, 0.19), (1, 0.31))):
            for i in range(count):
                b.cyl(0.07, 0.62, (i - (count - 1) / 2) * 0.145, 0, z, pick(("bark", "wood_b", "wood_dark"), row + i),
                      segs=6, rot=(0, 90, 0), center=True)
        b.blob(0.24, 0.32, 0.06, 0, 0, 0.39, "snow", subdiv=2, jitter=0.01)


def snow_dome(tier=1):
    t = DOME_TIERS[tier]
    name, R, g = t["name"], t["R"], t["R"] / DOME_R
    b = Builder(f"{name}_exterior", seed=601)
    roof = Builder(f"{name}_exterior_roof", seed=602)
    snow_base(b, *t["base"], seed=61, rocks=t["rocks"], back_firs=t["firs"])
    dome_blocks(b, Builder("_scratch"), R)
    dome_roof(roof, R)
    b.cyl(R - 0.2, 0.2, 0, 0, -0.05, ICE[1], segs=16)                              # closes the floor
    y0, y1 = -R * 0.72, -R - 0.55                                                  # entrance tunnel
    ym, dl = (y0 + y1) / 2, y0 - y1
    rr, zc = 0.62, 1.1
    for j in range(7):
        be = (j + 0.5) * 180 / 7
        x, z = rr * math.cos(math.radians(be)), zc + rr * math.sin(math.radians(be))
        b.box(0.34, dl, 0.28, x, ym, z, pick(ICE, j), bevel=0.05, rot=(0, 90 - be, 0), center=True, jitter=0.01)
    for sx in (-1, 1):
        for zz in (0.0, 0.55):
            b.box(0.3, dl, 0.55, sx * (rr + 0.02), ym, zz, pick(ICE, 3 + int(zz > 0)), bevel=0.05, jitter=0.01)
    b.box(1.1, dl - 0.05, 0.04, 0, ym, 0.0, "stone_grey", bevel=0.01)
    arched_door(b, 0, y1, 0, w=0.8, h=1.5, fw=0.13, depth=0.3, socket=False)
    b.blob(0.62, dl * 0.48, 0.12, 0, ym - 0.05, zc + rr + 0.16, "snow", subdiv=2, jitter=0.015)
    snow_lumps(b, 0, y1 + 0.1, zc + rr + 0.14, 1.0, 0.3, 3, r=(0.08, 0.14))
    for a, phi, kind in t["ext_windows"]:
        p = (R * math.cos(math.radians(phi)) * math.cos(math.radians(a)),
             R * math.cos(math.radians(phi)) * math.sin(math.radians(a)), R * math.sin(math.radians(phi)))
        with b.at(p, rotz=a + 90):
            with b.at((0, 0, 0), rot=(-phi, 0, 0)):
                if kind == "round":
                    round_window(b, 0, -0.07, 0, r=0.3, lining=0.36)
                else:
                    arched_window(b, 0, -0.07, -0.3, w=0.42, h=0.6, depth=0.4)
    post_lantern(b, -1.05, y1 + 0.05, side=1, h=1.55)
    barrel(b, 0.95 if tier == 1 else 1.75, y1 + 0.25)
    snowy_rock(b, 1.5 * g, -1.9 * g, 0.4, 0.3, 0.3, 1)
    snowy_rock(b, -1.7 * g, -1.7 * g, 0.35, 0.28, 0.26, 2)
    stepping_stones(b, 0, y1 - 0.25, -3.1 if tier == 1 else y1 - 0.85, n=3, seed=6)
    if tier >= 2:  # a bigger household: twin lanterns at the tunnel and a woodpile for the stove
        post_lantern(b, 1.05, y1 + 0.05, side=-1, h=1.55)
        woodpile(b, -1.85, y1 + 0.1, rotz=15)
    b.socket("door", (0, y1 - 0.6, 0), rotz=180)
    meta = {"interior": f"{name}_interior", "roof_child": f"{name}_exterior_roof", "footprint_m": t["footprint"]}
    if tier > 1:
        meta.update(tier=tier, upgrade_of=DOME_TIERS[tier - 1]["name"] + "_exterior")
    finish_house(b, roof, meta)

    Ri, n = t["Ri"], t["n"]
    b = Builder(f"{name}_interior", seed=611)
    round_floor(b, Ri + T / 2)
    segs = ring_wall(b, Ri + T, 2.0, n, facing="in", doors=(160,), windows=t["windows"], low=low_front,
                     mat=PLASTER, base=False, cap="wood_c", door_kw=dict(depth=T + 0.04))
    for i, (a, kind, lip) in enumerate(segs):  # an inward-leaning ice course hints at the dome above
        if lip:
            continue
        rm = (Ri + 0.02) * 0.97
        with b.at((rm * math.cos(math.radians(a)), rm * math.sin(math.radians(a)), 2.0), rotz=a - 90):
            b.box(2 * Ri * math.tan(math.pi / n) * 0.98, 0.18, 0.55, 0, 0, 0, pick(ICE, i), bevel=0.04,
                  rot=(25, 0, 0), jitter=0.006)
    room = Room(b, lambda x, y: math.hypot(x, y) <= Ri - 0.03, Ri, Ri)
    dr = math.radians(160)
    room.block_circle((Ri - 0.5) * math.cos(dr), (Ri - 0.5) * math.sin(dr), 0.75)
    ring_slots(room, Ri, 1.3, segs)
    for x, y in t["anchors"]:
        room.anchor((x, y, 2.45))
    b.socket("spawn_inside", ((Ri - 0.9) * math.cos(dr), (Ri - 0.9) * math.sin(dr), FLOOR), rotz=-20)
    b.socket("exit", ((Ri - 0.25) * math.cos(dr), (Ri - 0.25) * math.sin(dr), FLOOR))
    extra = {"tier": tier, "upgrade_of": DOME_TIERS[tier - 1]["name"] + "_interior"} if tier > 1 else {}
    b.finish(KIT, "room", room.meta(shape="round", radius_m=Ri, exterior=f"{name}_exterior",
                                    modules=[f"mod_wall_curved_r{Ri + T:.2f}_n{n}_*", f"mod_floor_sector_r{Ri + T / 2:.2f}_45"],
                                    **extra))


# =============================================================================== A-frame cabin
AF_DOOR_H = 1.5                                 # interior back door sits under the loft
LOFT_Z = 1.85                                    # loft floor height above the room floor
STAIR_X0, STAIR_X1 = 0.25, 0.8                   # loft stair footprint (rises toward +Y to the loft edge)


def aframe_headroom(roof_z, cells_loft, room):
    """Penguin clearance checks for the A-frame interior (asserted; also stored in meta)."""
    need = PENGUIN_H + 0.05
    loft_top = FLOOR + LOFT_Z
    loft_min = min(min(roof_z(room.origin[0] + (ix + dx) * CELL) for dx in (0, 1)) - loft_top for ix, iy in cells_loft)
    under_loft = (FLOOR + LOFT_Z - 0.3) - FLOOR                    # front beam bottom over the main floor
    xc, half_body = (STAIR_X0 + STAIR_X1) / 2, 0.3
    stair_min = min(roof_z(xc + half_body) - (FLOOR + LOFT_Z * (i + 1) / 9) for i in range(9))
    door_top = FLOOR + AF_DOOR_H + 0.1 + 0.08                      # interior door frame top (keystone)
    loft_underside = FLOOR + LOFT_Z - 0.14
    check = {"penguin_m": PENGUIN_H, "loft_min_headroom_m": round(loft_min, 3), "under_loft_m": round(under_loft, 3),
             "stair_min_headroom_m": round(stair_min, 3), "door_clear_of_loft_m": round(loft_underside - door_top, 3)}
    assert loft_min >= need and under_loft >= need and stair_min >= need and loft_underside > door_top, check
    return check


# LEN is the cabin length (AF override), HD the interior half depth; a longer cabin keeps its span.
AF_TIERS = {
    1: dict(LEN=4.4, HD=2.0, base=(3.7, 3.6), rocks=6, firs=((-2.7, 1.6, 2.6), (2.75, 1.2, 2.3)),
            left_slots=(-1.2, -0.2, 0.8),
            anchors=((0.0, -0.6), (-0.6, -1.3), (0.5, -1.4))),
    2: dict(LEN=6.4, HD=3.0, base=(3.8, 4.6), rocks=8, firs=((-2.8, 2.6, 2.6), (2.85, 2.2, 2.3), (-2.9, -0.6, 1.8)),
            left_slots=(-2.2, -1.2, -0.2, 0.8, 1.8),
            anchors=((0.0, -0.6), (-0.6, -1.3), (0.5, -1.4), (0.0, -2.3), (-0.6, -2.5))),
}


def aframe_cabin(tier=1):
    t = AF_TIERS[tier]
    name = tier_name("aframe_cabin", tier)
    SPAN, LEN, KNEE, RISE, SLAB = AF["SPAN"], AF["LEN"], AF["KNEE"], AF["RISE"], AF["SLAB"]
    ZE = SLAB + KNEE
    half = SPAN / 2
    b = Builder(f"{name}_exterior", seed=621)
    roof = Builder(f"{name}_exterior_roof", seed=622)
    snow_base(b, *t["base"], seed=62, rocks=t["rocks"], back_firs=t["firs"])
    b.box(SPAN + 0.3, LEN + 0.3, SLAB, 0, 0, 0, "stone_dark", bevel=0.035)
    for sx in (-1, 1):
        with b.at((sx * (half - T / 2), 0, SLAB), rotz=90 * sx):
            masonry_wall(b, LEN, KNEE + 0.15, base=False, timber=False)
    dx, dw, dh = 0.0, 0.9, 1.7
    front_ops = [(dx - dw / 2 - 0.12, dx + dw / 2 + 0.12, SLAB, SLAB + dh + 0.12)]
    gable_facade(b, half - 0.05, ZE, RISE, front_ops, z0=SLAB, y=-LEN / 2 + T / 2)
    gable_facade(b, half - 0.05, ZE, RISE, [], z0=SLAB, y=LEN / 2 - T / 2)          # windows are surface-mounted
    yF = -LEN / 2
    arched_door(b, dx, yF, SLAB, w=dw, h=dh, fw=0.12, depth=T + 0.06, socket=False, fill=WALL_T, fill_top=dh + 0.12, thick=T)
    arched_window(b, 0, yF, SLAB + 2.25, w=0.62, h=0.78)
    with b.at((0, LEN / 2, 0), rotz=180):
        arched_window(b, 0, 0.0, SLAB + 1.0, w=0.56, h=0.74)
    for sx in (-1, 1):
        beam(b, (sx * (half - 0.25), yF - 0.06, ZE), (sx * 0.08, yF - 0.06, ZE + RISE * 0.96), 0.12, 0.1, TRIM_T)
    b.box(SPAN - 0.4, 0.1, 0.12, 0, yF - 0.06, SLAB + 2.05, TRIM_T, bevel=0.015)
    b.box(2.6, 1.0, 0.16, 0, yF - 0.5, 0.04, "wood_c", bevel=0.02)                 # porch
    planks(b, 2.6, 1.0, z=0.2, plank=0.2, thick=0.04, along="x", y=yF - 0.5)
    entry_steps(b, 0, yF - 1.0, w=1.1, steps=2, rise=0.12, tread=0.3, mats=("wood_b", "wood"))
    rail_run(b, (-1.3, yF - 0.95), (-1.3, yF - 0.05), 0.24, posts=2)
    rail_run(b, (-1.3, yF - 0.95), (-0.6, yF - 0.95), 0.24, posts=2)
    rail_run(b, (1.3, yF - 0.95), (1.3, yF - 0.05), 0.24, posts=2)
    for i in range(3):
        for j in range(3 - i):
            b.cyl(0.09, 0.62, 1.6 + j * 0.19 + i * 0.095, yF - 0.35, 0.09 + i * 0.16, pick(("wood_b", "brown"), i + j),
                  segs=7, rot=(90, 0, 0), center=True)
            b.cyl(0.06, 0.63, 1.6 + j * 0.19 + i * 0.095, yF - 0.35, 0.09 + i * 0.16, "tan", segs=7, rot=(90, 0, 0), center=True)
    wall_lantern(b, dx + 0.75, yF - 0.05, SLAB + 1.55)
    if tier >= 2:  # a longer cabin: a side window down each long wall and a second lantern
        for sx in (-1, 1):
            with b.at((sx * half, 0.6, 0), rotz=-90 * sx):
                arched_window(b, 0, 0.0, SLAB + 0.2, w=0.46, h=0.56)
        wall_lantern(b, dx - 0.75, yF - 0.05, SLAB + 1.55)
    aframe_roof(roof)
    b.socket("door", (dx, yF - 1.3, 0), rotz=180)
    finish_house(b, roof, {"interior": f"{name}_interior", "roof_child": f"{name}_exterior_roof",
                           "footprint_m": [SPAN, LEN], "floor_z": SLAB, **tier_extra("aframe_cabin", tier, "exterior")})

    # interior: A-frame room with loft, stair and wood stove (cozy loft); no roof slopes, they would
    # cover the room from the game camera
    HW, HD = 2.0, t["HD"]
    LOFT_Y0, STAIR_Y0 = 0.5 + HD - 2.0, -0.95 + HD - 2.0   # the loft stays at the back, so the camera sees under it
    K, SL = 0.9, RISE / half
    roof_z = lambda x: FLOOR + K + (HW - abs(x)) * SL
    b = Builder(f"{name}_interior", seed=631)
    rect_floor(b, 2 * HW, 2 * HD)
    with b.at((-HW - T / 2, 0, 0), rotz=-90):
        masonry_wall(b, 2 * HD, K + FLOOR, base=False, mat=WALL_T)
    yB = HD + T / 2
    ops = [(-1.5, -0.5, 0, FLOOR + AF_DOOR_H + 0.1), (-0.32, 0.32, 2.3, 3.0)]
    gable_facade(b, HW + 0.05, FLOOR + K, RISE * (HW + 0.05) / half, ops, z0=0, y=yB)
    with b.at((0, yB, 0)):
        arched_door(b, -1.0, -T / 2, FLOOR, w=0.82, h=AF_DOOR_H, fw=0.1, depth=T + 0.04, socket=False,
                    fill=WALL_T, fill_top=AF_DOOR_H + 0.1, thick=T)
        through_window(b, 0, w=0.5, zb=2.35, h=0.6)
    with b.at((HW + T / 2, 0, 0), rotz=90):
        masonry_wall(b, 2 * HD, LIP_H, base=False, cap="wood_c")
    with b.at((0, -HD - T / 2, 0), rotz=180):
        masonry_wall(b, 2 * HW + 2 * T, LIP_H, base=False, cap="wood_c")
    # loft platform across the back, railing with a gap for the stair
    b.box(2 * HW, HD - LOFT_Y0, 0.14, 0, (HD + LOFT_Y0) / 2, FLOOR + LOFT_Z - 0.14, "wood_b", bevel=0.02)
    planks(b, 2 * HW - 0.4, HD - LOFT_Y0, z=FLOOR + LOFT_Z, plank=0.2, thick=0.04, along="y", y=(HD + LOFT_Y0) / 2)
    for x in (-1.4, -0.1, 1.4):
        b.box(0.14, 0.14, LOFT_Z - 0.14, x, LOFT_Y0 + 0.1, FLOOR, "wood_dark", bevel=0.02)
    b.box(2 * HW, 0.16, 0.18, 0, LOFT_Y0 + 0.08, FLOOR + LOFT_Z - 0.3, "wood_dark", bevel=0.02)
    for x in [-1.25 + i * 0.27 for i in range(6)] + [1.0]:
        b.box(0.05, 0.05, 0.6, x, LOFT_Y0 + 0.05, FLOOR + LOFT_Z, "wood", bevel=0.008)
    b.box(1.45, 0.08, 0.08, -0.55, LOFT_Y0 + 0.05, FLOOR + LOFT_Z + 0.6, "wood_c", bevel=0.012)
    steps = 9
    run = LOFT_Y0 - STAIR_Y0
    for i in range(steps):
        yy = STAIR_Y0 + run * (i + 0.5) / steps
        zz = FLOOR + LOFT_Z * (i + 1) / steps - 0.06
        b.box(STAIR_X1 - STAIR_X0, run / steps + 0.02, 0.06, (STAIR_X0 + STAIR_X1) / 2, yy, zz, pick(("wood", "wood_c"), i), bevel=0.01)
    for x in (STAIR_X0 - 0.03, STAIR_X1 + 0.03):
        beam(b, (x, STAIR_Y0, FLOOR), (x, LOFT_Y0, FLOOR + LOFT_Z), 0.05, 0.16, "wood_b", 0.012)
    sx, sy = -1.35, -HD + 1.0                                           # wood stove (front-left)
    b.box(0.95, 0.95, 0.08, sx, sy, FLOOR, "stone", bevel=0.02)
    b.box(0.55, 0.5, 0.5, sx, sy, FLOOR + 0.12, "iron", bevel=0.03)
    b.box(0.32, 0.03, 0.22, sx, sy - 0.25, FLOOR + 0.22, "glow", bevel=0)
    for lx in (-0.2, 0.2):
        for ly in (-0.18, 0.18):
            b.box(0.06, 0.06, 0.06, sx + lx, sy + ly, FLOOR + 0.08, "iron", bevel=0.01)
    b.cyl(0.08, roof_z(sx) - FLOOR - 0.6, sx, sy, FLOOR + 0.62, "iron", segs=8)
    b.box(0.6, 0.55, 0.06, sx, sy, FLOOR + 0.62, "iron_light", bevel=0.015)
    b.socket("fx_flame", (sx, sy - 0.2, FLOOR + 0.3))
    room = Room(b, lambda x, y: abs(x) <= HW + 1e-6 and abs(y) <= HD + 1e-6, HW, HD)
    room.block_rect(STAIR_X0 - 0.1, STAIR_X1 + 0.1, STAIR_Y0 - 0.15, LOFT_Y0)
    room.block_rect(sx - 0.55, sx + 0.55, sy - 0.55, sy + 0.55)
    room.block_rect(-1.6, -0.4, HD - 1.0, HD)
    room.solid(STAIR_X0 - 0.05, STAIR_X1 + 0.05, STAIR_Y0, LOFT_Y0 + 0.1)
    room.solid(sx - 0.45, sx + 0.45, sy - 0.45, sy + 0.45)
    cells_loft = room.cells(inside=lambda x, y: abs(x) <= 1.0 + 1e-6 and LOFT_Y0 - 1e-6 <= y <= HD + 1e-6)
    blocked_loft = [c for c in cells_loft
                    if STAIR_X0 - 0.3 <= room.centre(c)[0] <= STAIR_X1 + 0.3 and room.centre(c)[1] < LOFT_Y0 + CELL]
    check = aframe_headroom(roof_z, cells_loft, room)
    room.wall_slot((0.3, HD, 1.3), (0, -1))
    room.wall_slot((1.2, HD, 1.3), (0, -1))
    for y in t["left_slots"]:
        room.wall_slot((-HW, y, FLOOR + 0.6), (1, 0))
    for x, y in t["anchors"]:
        room.anchor((x, y, roof_z(x) - 0.25))
    b.socket("spawn_inside", (-1.0, HD - 0.75, FLOOR), rotz=180)
    b.socket("exit", (-1.0, HD - 0.25, FLOOR))
    b.socket("stair_top", ((STAIR_X0 + STAIR_X1) / 2, LOFT_Y0 + 0.3, FLOOR + LOFT_Z))
    b.finish(KIT, "room", room.meta(shape="aframe", exterior=f"{name}_exterior", cells_loft=cells_loft,
                                    blocked_cells_loft=blocked_loft, loft_z=round(FLOOR + LOFT_Z, 3), headroom=check,
                                    headroom_note="roof height at x = floor_z + 0.9 + (2.0 - |x|) * 1.909",
                                    **tier_extra("aframe_cabin", tier, "interior")))


# =============================================================================== round cottage
# n: wall segments outside / in the room (about 1 m each); lanterns hug the door at any size.
RC_TIERS = {
    1: dict(R=2.2, Ri=2.2, n=14, ni=16, base=(3.4, 3.2), rocks=5, firs=((2.6, 1.4, 2.0),), lanterns=(243, 297),
            windows=(215, 330, 30, 150), room_windows=(90, 140, 60), anchors=((0, 0), (-0.8, 0.7), (0.7, 0.6))),
    2: dict(R=2.9, Ri=2.9, n=18, ni=20, base=(4.2, 3.95), rocks=7, firs=((3.3, 1.8, 2.0), (-3.3, 1.5, 1.7)),
            lanterns=(249, 291), windows=(215, 330, 30, 150, 90), room_windows=(50, 85, 120, 145),
            anchors=((0, 0), (-1.1, 0.9), (0.9, 0.9), (-1.3, -0.5), (0.2, 1.8))),
}


def round_cottage(tier=1):
    t = RC_TIERS[tier]
    name = tier_name("round_cottage", tier)
    R, H, SLAB = RC["R"], RC["H"], RC["SLAB"]
    g = R / 2.2
    b = Builder(f"{name}_exterior", seed=641)
    roof = Builder(f"{name}_exterior_roof", seed=642)
    snow_base(b, *t["base"], seed=64, rocks=t["rocks"], back_firs=t["firs"])
    b.cyl(R + 0.2, SLAB, 0, 0, 0, "stone_dark", segs=14, bevel=0.03)
    ring_wall(b, R, H, t["n"], z0=SLAB, doors=(270,), windows=t["windows"], door_kw=dict(w=0.78, h=1.55, fw=0.11, depth=0.3))
    entry_steps(b, 0, -R - 0.12, w=1.1, steps=2, rise=SLAB / 2, tread=0.3, mats=("stone", "stone_dark"))
    for a in t["lanterns"]:
        r = math.radians(a)
        with b.at((R * math.cos(r), R * math.sin(r), SLAB), rotz=a + 90):
            wall_lantern(b, 0, 0.02, 1.55)
    rail_run(b, (-2.75 * g, -1.2 * g), (-2.4 * g, -2.0 * g), 0.0, posts=2)
    rail_run(b, (-2.4 * g, -2.0 * g), (-1.55 * g, -2.45 * g), 0.0, posts=2)
    planter_box(b, 0.8, 0.32, 0.28, x=1.6 * g, y=-2.25 * g, z=0.0, flowers=("leaf_b",))
    snow_lumps(b, 1.6 * g, -2.25 * g, 0.3, 0.7, 0.25, 3, r=(0.06, 0.1))
    barrel(b, 2.1 * g, -1.65 * g)
    stepping_stones(b, 0, -R - 0.75, -R - 0.8, n=2, seed=4)
    if tier >= 2:  # a bigger household: a second planter and a woodpile by the wall
        planter_box(b, 0.8, 0.32, 0.28, x=-1.1 * g, y=-2.6 * g, z=0.0, flowers=("leaf_b",))
        woodpile(b, 2.75, -2.15, rotz=-35)
    round_cottage_roof(roof)
    b.socket("door", (0, -R - 0.9, 0), rotz=180)
    finish_house(b, roof, {"interior": f"{name}_interior", "roof_child": f"{name}_exterior_roof",
                           "footprint_m": [2 * R, 2 * R], "floor_z": SLAB, "modules": [f"mod_wall_curved_r{R:g}_n{t['n']}_*"],
                           **tier_extra("round_cottage", tier, "exterior")})

    Ri, ni = t["Ri"], t["ni"]
    b = Builder(f"{name}_interior", seed=651)
    round_floor(b, Ri + T / 2)
    segs = ring_wall(b, Ri + T, 2.1, ni, facing="in", doors=(195,), windows=t["room_windows"], low=low_front, base=False,
                     cap="wood_c", door_kw=dict(depth=T + 0.04), offset=195 % (360 / ni))
    for k in range(8):  # exposed ceiling beams on the full walls' top
        a = 45 + k * 22.5
        r = math.radians(a)
        if low_front(a):
            continue
        b.box(0.12, 0.6, 0.14, (Ri - 0.2) * math.cos(r), (Ri - 0.2) * math.sin(r), 1.95, "wood_dark", bevel=0.015, rot=(0, 0, a + 90))
    room = Room(b, lambda x, y: math.hypot(x, y) <= Ri - 0.03, Ri, Ri)
    dr = math.radians(195)
    room.block_circle((Ri - 0.5) * math.cos(dr), (Ri - 0.5) * math.sin(dr), 0.75)
    ring_slots(room, Ri, 1.35, segs)
    for x, y in t["anchors"]:
        room.anchor((x, y, 2.3))
    b.socket("spawn_inside", ((Ri - 0.9) * math.cos(dr), (Ri - 0.9) * math.sin(dr), FLOOR), rotz=-75)
    b.socket("exit", ((Ri - 0.25) * math.cos(dr), (Ri - 0.25) * math.sin(dr), FLOOR))
    b.finish(KIT, "room", room.meta(shape="round", radius_m=Ri, exterior=f"{name}_exterior",
                                    modules=[f"mod_wall_curved_r{Ri + T:.2f}_n{ni}_*", f"mod_floor_sector_r{Ri + T / 2:.2f}_45"],
                                    **tier_extra("round_cottage", tier, "interior")))


# =============================================================================== treehouse
def treehouse_canopy(roof):
    TX, TY = TH_["TX"], TH_["TY"]
    canopy(roof, [(TX - 0.9, TY + 0.4, 4.7, 0.95), (TX + 0.8, TY + 0.6, 4.95, 1.05), (TX - 0.1, TY - 0.6, 5.2, 0.95),
                  (TX + 1.2, TY + 1.2, 5.0, 0.75), (TX - 0.3, TY + 0.9, 5.6, 0.85), (TX - 1.6, TY - 0.4, 4.4, 0.7)],
           snow=True, seed=6)


DECK = dict(X0=-2.05, X1=2.0, Y0=-1.45, Y1=1.6)
CABIN_FRONT = [("plain", 0.5), ("door", 1.0), ("window", 1.0)]
CABIN_SIDE = [("plain", 0.5), ("window", 1.0), ("plain", 0.5)]


def cabin_walls(b, CW, CD, front, side_l, side_r, back, posts=0.14):
    """Rect cabin from straight wall modules in the current frame (centre at 0, bottom z=0):
    front faces -Y, sides span the full depth. Returns the front pieces."""
    with b.at((0, -CD / 2 + T / 2, 0)):
        fr = wall_run(b, front)
    if side_l:
        with b.at((-CW / 2 + T / 2, 0, 0), rotz=-90):
            wall_run(b, side_l)
    if side_r:
        with b.at((CW / 2 - T / 2, 0, 0), rotz=90):
            wall_run(b, side_r)
    with b.at((0, CD / 2 - T / 2, 0), rotz=180):
        wall_run(b, back)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(posts, posts, WALL_H, sx * (CW / 2 - 0.02), sy * (CD / 2 - 0.02), 0, TRIM_T, bevel=0.02)
    return fr


# The bigger cabin grows away from the trunk (toward +X) on a longer deck.
TH_TIERS = {
    1: dict(deck=DECK, base=(3.6, 3.3), rocks=6, foot=[7.2, 6.6], front=CABIN_FRONT, side=CABIN_SIDE,
            back=[("plain", 1.0), ("plain", 1.0), ("plain", 0.5)], W=3.0, D=2.5,
            room_back=[("plain", 1.0), ("plain", 0.5), ("window", 1.0), ("plain", 0.5)],
            room_left=[("window", 1.0), ("door", 1.0), ("plain", 0.5)], beams=(-1.0, 0.0, 1.0),
            anchors=((-0.5, -0.4), (0.5, 0.4), (0.9, -0.6))),
    2: dict(deck=dict(X0=-2.05, X1=3.05, Y0=-1.6, Y1=1.9), base=(4.3, 3.6), rocks=8, foot=[8.6, 7.2],
            front=CABIN_FRONT + [("window", 1.0)], side=[("plain", 0.5), ("window", 1.0), ("plain", 1.0)],
            back=[("plain", 1.0), ("plain", 1.0), ("plain", 1.0), ("plain", 0.5)], W=4.0, D=3.0,
            room_back=[("plain", 1.0), ("plain", 0.5), ("window", 1.0), ("plain", 0.5), ("window", 1.0)],
            room_left=[("window", 1.0), ("door", 1.0), ("plain", 1.0)], beams=(-1.5, -0.5, 0.5, 1.5),
            anchors=((-0.5, -0.4), (0.5, 0.4), (0.9, -0.6), (-1.0, 0.7), (1.4, 0.6))),
}


def treehouse(tier=1):
    t = TH_TIERS[tier]
    name = tier_name("treehouse", tier)
    DECK = t["deck"]
    DZ, TX, TY, CW, CD, CX, CY = TH_["DZ"], TH_["TX"], TH_["TY"], TH_["CW"], TH_["CD"], TH_["CX"], TH_["CY"]
    b = Builder(f"{name}_exterior", seed=661)
    roof = Builder(f"{name}_exterior_roof", seed=662)
    snow_base(b, *t["base"], seed=66, rocks=t["rocks"])
    with b.at((TX, TY, 0)):
        treehouse_support(b)
    treehouse_canopy(roof)
    dcx, dcy = (DECK["X0"] + DECK["X1"]) / 2, (DECK["Y0"] + DECK["Y1"]) / 2
    with b.at((dcx, dcy, 0)):
        treehouse_deck(b, DECK["X1"] - DECK["X0"], DECK["Y1"] - DECK["Y0"], DZ, trunk=(TX - dcx, TY - dcy))
    sx = DECK["X1"] + 0.42                                         # stair down the right side
    with b.at((sx, DECK["Y0"] - 2.0, 0)):
        stair_flight(b, run=2.75, rise=DZ)
    with b.at((CX, CY, DZ)):
        fr = cabin_walls(b, CW, CD, t["front"], t["side"], t["side"], t["back"])
        with b.at((0, -CD / 2 + T / 2, 0)):
            wall_lantern(b, -1.0, -T / 2, 1.5)
    door_x = CX + next(c for k, c, _ in fr if k == "door")
    treehouse_roof(roof)
    b.socket("door", (door_x, CY - CD / 2 - 0.6, DZ), rotz=180)
    b.socket("approach", (sx, DECK["Y0"] - 2.5, 0), rotz=180)
    finish_house(b, roof, {"interior": f"{name}_interior", "roof_child": f"{name}_exterior_roof", "deck_z": DZ,
                           "footprint_m": t["foot"], "modules": ["mod_treehouse_support", "mod_treehouse_deck",
                                                                  "mod_stairs_2m", "mod_wall_straight_*"],
                           **tier_extra("treehouse", tier, "exterior")})

    W, D = t["W"], t["D"]
    b = Builder(f"{name}_interior", seed=671)
    rect_floor(b, W, D)
    with b.at((0, 0, FLOOR)):
        laid = rect_room(b, W, D, back=t["room_back"], left=t["room_left"])
    for x in t["beams"]:                               # ceiling beams and a branch through the corner
        b.box(0.12, D + 0.3, 0.14, x, 0, FLOOR + WALL_H, "wood_dark", bevel=0.015)
    trunk = (-W / 2 + 0.25, D / 2 - 0.25)
    b.cyl(0.24, 2.3, trunk[0], trunk[1], 0, "bark", segs=8, r2=0.2, jitter=0.015)
    dy = door_y(laid)
    room = Room(b, lambda x, y: abs(x) <= W / 2 + 1e-6 and abs(y) <= D / 2 + 1e-6, W / 2, D / 2, corner=True)
    room.block_circle(*trunk, 0.45)
    room.solid(trunk[0] - 0.25, trunk[0] + 0.25, trunk[1] - 0.25, trunk[1] + 0.25)
    room.block_rect(-W / 2, -W / 2 + 0.8, dy - 0.5, dy + 0.5)
    rect_slots(room, W, D, FLOOR + 1.3, laid, skip=lambda x, y: math.hypot(x - trunk[0], y - trunk[1]) < 0.55)
    for x, y in t["anchors"]:
        room.anchor((x, y, FLOOR + 1.93))
    b.socket("spawn_inside", (-W / 2 + 0.7, dy, FLOOR), rotz=-90)
    b.socket("exit", (-W / 2 + 0.2, dy, FLOOR))
    b.finish(KIT, "room", room.meta(shape="rect", room_m=[W, D], exterior=f"{name}_exterior",
                                    modules=["mod_floor_tile_wood", "mod_wall_straight_*"],
                                    **tier_extra("treehouse", tier, "interior")))


# =============================================================================== lighthouse loft
# The keeper's cottage beside the tower grows toward +X; the round room inside gets wider.
LH_TIERS = {
    1: dict(Ri=2.4, n=18, base=(3.7, 3.2), rocks=8, foot=[7.4, 6.4], firs=((-2.6, 1.6, 2.4),),
            front=[("window_round", 1.0), ("door", 1.0), ("plain", 0.5)], back=[("plain", 1.0), ("plain", 1.0), ("plain", 0.5)],
            windows=(70, 110, 140), anchors=((0, 0), (-0.9, 0.8), (0.6, -0.4))),
    2: dict(Ri=3.0, n=22, base=(4.4, 3.4), rocks=10, foot=[8.8, 6.8], firs=((-3.1, 1.7, 2.4), (3.6, 1.6, 1.8)),
            front=[("window_round", 1.0), ("door", 1.0), ("window", 1.0), ("plain", 0.5)],
            back=[("plain", 1.0), ("plain", 1.0), ("plain", 1.0), ("plain", 0.5)], windows=(95, 120, 145),
            anchors=((0, 0), (-1.2, 1.0), (0.8, -0.5), (-1.3, -0.6), (0.3, 1.6))),
}


def lighthouse_loft(tier=1):
    t = LH_TIERS[tier]
    name = tier_name("lighthouse_loft", tier)
    TX, TY, TOW, R0, R1 = LH["TX"], LH["TY"], LH["TOWER"], LH["R0"], LH["R1"]
    CW, CD, SLAB, CX, CY = LH["CW"], LH["CD"], LH["SLAB"], LH["CX"], LH["CY"]
    b = Builder(f"{name}_exterior", seed=681)
    roof = Builder(f"{name}_exterior_roof", seed=682)
    snow_base(b, *t["base"], seed=68, rocks=t["rocks"], back_firs=t["firs"])
    b.cyl(R0 + 0.12, 0.4, TX, TY, 0, "stone_dark", segs=14, r2=R0 + 0.06, bevel=0.03)
    bands = 6
    for i in range(bands):
        z0 = 0.4 + (TOW - 0.4) * i / bands
        z1 = 0.4 + (TOW - 0.4) * (i + 1) / bands
        r0 = R0 + (R1 - R0) * (z0 / TOW)
        r1 = R0 + (R1 - R0) * (z1 / TOW)
        b.cyl(r0, z1 - z0, TX, TY, z0, STRIPE_T if i % 2 == 0 else WALL_T, segs=14, r2=r1, cap=(i == bands - 1))
    for a, z in ((250, 1.5), (300, 2.8), (205, 2.2)):
        r = math.radians(a)
        rr = R0 + (R1 - R0) * (z / TOW)
        with b.at((TX + rr * math.cos(r), TY + rr * math.sin(r), z), rotz=a + 90):
            arched_window(b, 0, -0.03, 0, w=0.36, h=0.52, depth=0.3)
    GZ = TOW                                                    # gallery
    b.cyl(R1 + 0.38, 0.14, TX, TY, GZ, "wood_b", segs=14, bevel=0.02)
    for k in range(12):
        a = 2 * math.pi * k / 12
        snow_post(b, TX + (R1 + 0.3) * math.cos(a), TY + (R1 + 0.3) * math.sin(a), GZ + 0.14, h=0.5, w=0.08)
    b.torus(R1 + 0.3, 0.035, TX, TY, GZ + 0.58, "wood", segs=14, ring=5)
    b.torus(R1 + 0.3, 0.025, TX, TY, GZ + 0.36, "wood", segs=14, ring=4)
    lighthouse_lantern(roof)
    b.box(CW + 0.2, CD + 0.2, SLAB, CX, CY, 0, "stone_dark", bevel=0.03)        # side cottage
    with b.at((CX, CY, SLAB)):
        fr = cabin_walls(b, CW, CD, t["front"], None, CABIN_SIDE, t["back"])
        with b.at((0, -CD / 2 + T / 2, 0)):
            wall_lantern(b, 1.0, -T / 2, 1.5)
    door_x = CX + next(c for k, c, _ in fr if k == "door")
    entry_steps(b, door_x, CY - CD / 2 - 0.1, w=1.0, steps=1, rise=SLAB, tread=0.35)
    lighthouse_cottage_roof(roof)
    rail_run(b, (CX + CW / 2 + 0.35, CY - 1.3), (CX + CW / 2 + 0.35, CY + 0.4), 0.0, posts=3)
    barrel(b, CX - 0.6, CY - CD / 2 - 0.45)
    barrel(b, CX - 1.0, CY - CD / 2 - 0.3, s=0.85)
    crate(b, CX + 1.35, CY - CD / 2 - 0.5, rotz=12)
    stepping_stones(b, door_x, CY - CD / 2 - 0.65, -2.9, n=2, seed=8)
    b.socket("door", (door_x, CY - CD / 2 - 0.85, 0), rotz=180)
    finish_house(b, roof, {"interior": f"{name}_interior", "roof_child": f"{name}_exterior_roof",
                           "footprint_m": t["foot"], "modules": ["mod_wall_straight_*", "mod_lighthouse_lantern"],
                           **tier_extra("lighthouse_loft", tier, "exterior")})

    Ri = t["Ri"]
    b = Builder(f"{name}_interior", seed=691)
    round_floor(b, Ri + T / 2)
    segs = ring_wall(b, Ri + T, 2.3, t["n"], facing="in", doors=(180,), windows=t["windows"], low=low_front, base=False,
                     cap="wood_c", door_kw=dict(depth=T + 0.04), mat=(WALL_T, STRIPE_T, WALL_T), band=True)
    ST0, ST1, STR = 20, 75, 0.62                     # curved stair arc (degrees) and tread length
    steps = 10
    for i in range(steps):
        a = math.radians(ST0 + (ST1 - ST0) * (i + 0.5) / steps)
        zz = FLOOR + 2.1 * (i + 1) / steps
        rr = Ri - STR / 2 - 0.02
        with b.at((rr * math.cos(a), rr * math.sin(a), 0), rotz=math.degrees(a) + 90):
            b.box(0.42, STR, 0.07, 0, 0, zz - 0.07, pick(("wood", "wood_c"), i), bevel=0.012)
            b.box(0.12, 0.12, zz - 0.07, 0, STR / 2 - 0.1, 0, "wood_dark", bevel=0.01)
    room = Room(b, lambda x, y: math.hypot(x, y) <= Ri - 0.03, Ri, Ri)
    for i in range(0, steps, 2):
        a = math.radians(ST0 + (ST1 - ST0) * (i + 1) / steps)
        px, py = (Ri - STR / 2) * math.cos(a), (Ri - STR / 2) * math.sin(a)
        room.solid(px - 0.3, px + 0.3, py - 0.3, py + 0.3)
    in_stair = lambda a: ST0 - 8 <= a <= ST1 + 8
    room.blockers.append(lambda x, y: math.hypot(x, y) > Ri - STR - 0.2 and in_stair(math.degrees(math.atan2(y, x)) % 360))
    room.block_circle(-(Ri - 0.5), 0, 0.75)
    ring_slots(room, Ri, 1.4, segs, skip=in_stair)
    for x, y in t["anchors"]:
        room.anchor((x, y, 2.6))
    b.socket("spawn_inside", (-(Ri - 0.9), 0, FLOOR), rotz=-90)
    b.socket("exit", (-(Ri - 0.25), 0, FLOOR))
    b.socket("stair_top", ((Ri - 0.3) * math.cos(math.radians(ST1)), (Ri - 0.3) * math.sin(math.radians(ST1)), FLOOR + 2.1))
    b.finish(KIT, "room", room.meta(shape="round", radius_m=Ri, exterior=f"{name}_exterior",
                                    modules=["mod_lighthouse_floor", f"mod_wall_curved_r{Ri + T:.2f}_n{t['n']}_*"],
                                    **tier_extra("lighthouse_loft", tier, "interior")))


# =============================================================================== houseboat
# sx stretches the hull and deck so the longer cabin keeps its walkway at both ends.
HB_TIERS = {
    1: dict(sx=1.0, water=(9.0, 7.0), front=[("window_round", 1.0), ("door", 1.0), ("plain", 1.0)],
            back=[("plain", 1.0), ("window_round", 1.0), ("plain", 1.0)], W=3.5, D=2.5,
            room_back=[("window_round", 1.0), ("plain", 1.0), ("window_round", 1.0), ("plain", 0.5)],
            room_left=[("plain", 0.5), ("door", 1.0), ("window_round", 1.0)], ribs=(-1.2, -0.4, 0.4, 1.2),
            anchors=((-0.8, 0.0), (0.8, 0.0))),
    2: dict(sx=1.22, water=(10.8, 7.0), front=[("window_round", 1.0), ("door", 1.0), ("plain", 1.0), ("window_round", 1.0)],
            back=[("plain", 1.0), ("window_round", 1.0), ("window_round", 1.0), ("plain", 1.0)], W=4.5, D=3.0,
            room_back=[("window_round", 1.0), ("plain", 1.0), ("window_round", 1.0), ("plain", 1.0), ("plain", 0.5)],
            room_left=[("plain", 0.5), ("door", 1.0), ("window_round", 1.0), ("plain", 0.5)],
            ribs=(-1.8, -1.0, -0.2, 0.6, 1.4), anchors=((-1.2, 0.0), (0.0, 0.5), (1.2, 0.0))),
}


def houseboat(tier=1):
    t = HB_TIERS[tier]
    name = tier_name("houseboat", tier)
    sx = t["sx"]
    CW, CD, CX = HB["CW"], HB["CD"], HB["CX"]
    b = Builder(f"{name}_exterior", seed=701)
    roof = Builder(f"{name}_exterior_roof", seed=702)
    water_surface(b, *t["water"], x=0, y=-0.6, n=8, seed=7, z=WATER_Z)
    houseboat_hull(b, sx)
    zdeck = BOAT_DECK
    with b.at((CX, 0, zdeck)):
        fr = cabin_walls(b, CW, CD, t["front"],
                         [("plain", 0.5), ("window_round", 1.0), ("plain", 0.5)],
                         [("plain", 0.5), ("window_round", 1.0), ("plain", 0.5)],
                         t["back"], posts=0.13)
        with b.at((0, -CD / 2 + T / 2, 0)):
            wall_lantern(b, 0.9, -T / 2, 1.55)
    door_x = CX + next(c for k, c, _ in fr if k == "door")
    houseboat_deck(b, gap_x=door_x, sx=sx)
    houseboat_roof(roof)
    barrel(b, 1.7 * sx, 0.45, zdeck)
    crate(b, 2.15 * sx, 0.1, zdeck, s=0.4, rotz=-10)
    for i in range(7):                                            # moored dock with gangway
        y = -1.75 - 0.25 * (i + 0.5)
        b.box(2.4, 0.24, 0.08, 0.2, y, -0.08, pick(WOODS, i), bevel=0.012)
    for sx in (-1, 1):
        b.box(0.14, 1.8, 0.16, 0.2 + sx * 0.9, -2.6, -0.24, "wood_dark", bevel=0.015)
    for x, y in ((-1.0, -1.65), (1.4, -1.65), (-1.0, -3.55), (1.4, -3.55)):
        dock_post(b, x, y, top=0.45)
        b.box(0.22, 0.22, 0.06, x, y, 0.45, "snow", bevel=0.02)
    rope_between(b, (-1.0, -1.65, 0.38), (-1.2, -1.2, zdeck + 0.45), sag=0.1, r=0.02)
    rope_between(b, (1.4, -1.65, 0.38), (1.0, -1.18, zdeck + 0.45), sag=0.1, r=0.02)
    beam(b, (door_x, -1.8, 0.0), (door_x, -1.15, zdeck), 0.6, 0.06, "wood_c", 0.01)
    b.torus(0.22, 0.06, 1.85, -1.62, 0.3, tint("ring", "coral"), segs=12, ring=6, rot=(90, 0, 0))
    snow_lumps(b, 0.2, -2.6, 0.0, 2.2, 1.6, 4, r=(0.08, 0.14))
    b.socket("door", (door_x, -2.4, 0.0), rotz=180)
    finish_house(b, roof, {"interior": f"{name}_interior", "roof_child": f"{name}_exterior_roof", "water_z": WATER_Z,
                           "deck_z": round(zdeck, 3), "footprint_m": list(t["water"]),
                           "modules": ["mod_houseboat_hull", "mod_houseboat_deck", "mod_wall_straight_*"],
                           **tier_extra("houseboat", tier, "exterior")})

    W, D = t["W"], t["D"]
    b = Builder(f"{name}_interior", seed=711)
    rect_floor(b, W, D)
    with b.at((0, 0, FLOOR)):
        laid = rect_room(b, W, D, back=t["room_back"], left=t["room_left"])
    for x in t["ribs"]:  # ceiling ribs
        b.box(0.1, D + 0.2, 0.12, x, 0, FLOOR + WALL_H, "wood_dark", bevel=0.015)
    dy = door_y(laid)
    room = Room(b, lambda x, y: abs(x) <= W / 2 + 1e-6 and abs(y) <= D / 2 + 1e-6, W / 2, D / 2, corner=True)
    room.block_rect(-W / 2, -W / 2 + 0.8, dy - 0.5, dy + 0.5)
    rect_slots(room, W, D, FLOOR + 1.3, laid)
    for x, y in t["anchors"]:
        room.anchor((x, y, FLOOR + 1.93))
    b.socket("spawn_inside", (-W / 2 + 0.7, dy, FLOOR), rotz=-90)
    b.socket("exit", (-W / 2 + 0.2, dy, FLOOR))
    b.finish(KIT, "room", room.meta(shape="rect", room_m=[W, D], exterior=f"{name}_exterior",
                                    modules=["mod_floor_tile_wood", "mod_wall_straight_*"],
                                    **tier_extra("houseboat", tier, "interior")))


# =============================================================================== module exports
CURVED = [  # family, outer radius, segments, height, facing, base stone, cap, material set
    ("round_cottage", RC["R"], 14, RC["H"], "out", True, None, PLASTER),
    ("round_cottage_room", 2.2 + T, 16, 2.1, "in", False, "wood_c", PLASTER),
    ("snow_dome_room", 2.3 + T, 16, 2.0, "in", False, "wood_c", PLASTER),
    ("lighthouse_room", 2.4 + T, 18, 2.3, "in", False, "wood_c", (WALL_T, STRIPE_T, WALL_T)),
]
SECTORS = [("snow_dome", 2.3 + T / 2), ("round_cottage", 2.2 + T / 2), ("lighthouse", 2.4 + T / 2)]


def mod(name, fn, meta, seed=0, category="module"):
    b = Builder(name, seed=seed or zlib.crc32(name.encode()) & 0xFFFF)
    fn(b)
    m = {"module": True, "seam_grid_m": CELL, "authoring_only": "shell variants; player structural building not implied"}
    m.update(meta)
    return b.finish(KIT, category, m)


ROOF_VARIANTS = {"roof": ["#F07E66", "#2F8F8A", "#3D6E8F", "#7A9A4A"]}   # coral, sheet teal, slate blue, moss


def room_example():
    """'Empty room example' from the construction sheet: a 3 x 3 m room assembled only from
    modules (stone floor tiles, door wall, round-window wall, plain walls, lips)."""
    W = D = 3.0
    b = Builder("homes_room_example", seed=731)
    rect_floor(b, W, D, kind="stone")
    with b.at((0, 0, FLOOR)):
        laid = rect_room(b, W, D, back=[("plain", 1.0), ("window_round", 1.0), ("plain", 1.0)],
                         left=[("plain", 1.0), ("door", 1.0), ("plain", 1.0)])
    room = Room(b, lambda x, y: abs(x) <= W / 2 + 1e-6 and abs(y) <= D / 2 + 1e-6, W / 2, D / 2, corner=True)
    dy = door_y(laid)
    room.block_rect(-W / 2, -W / 2 + 0.8, dy - 0.5, dy + 0.5)
    rect_slots(room, W, D, FLOOR + 1.3, laid)
    b.socket("spawn_inside", (-W / 2 + 0.7, dy, FLOOR), rotz=-90)
    b.finish(KIT, "room", room.meta(shape="rect", room_m=[W, D], example=True,
                                    modules=["mod_floor_tile_stone", "mod_wall_straight_*", "mod_wall_lip_*"]))


def build_modules():
    room_example()
    for kind in ("wood", "stone", "snow"):
        mod(f"mod_floor_tile_{kind}", lambda b, k=kind: floor_tile(b, k),
            {"kind": "floor_tile", "size_m": [CELL, CELL], "pivot": "min corner (cell corner)", "top_z": FLOOR,
             "floor_mask": "one tile per valid cell in the room's cells list"})
    for fam, R in SECTORS:
        mod(f"mod_floor_sector_r{R:.2f}_45", lambda b, R=R: floor_sector(b, R, 45),
            {"kind": "floor_sector", "family": fam, "radius": round(R, 3), "arc_deg": 45, "top_z": FLOOR,
             "pivot": "circle centre; spans +-arc/2 about +X; rotate by k*45+22.5",
             "floor_mask": f"room cells are the 0.5 m cells inside radius {R - T / 2 - 0.03:.2f}"})
    for kind, L in (("plain", 0.5), ("plain", 1.0), ("door", 1.0), ("window", 1.0), ("window_round", 1.0)):
        mod(f"mod_wall_straight_{kind}_{L:g}m", lambda b, k=kind, L=L: straight_wall(b, k, L),
            {"kind": f"wall_{kind}", "length": L, "height": WALL_H, "thickness": T,
             "pivot": "left seam (x=0) on the wall centre line; front -Y", "seams": [0.0, L],
             "opening": {"door": [0.98, 1.68], "window": [WIN_W, WIN_ZB, WIN_ZB + WIN_H]}.get(kind)})
    for L in (0.5, 1.0):
        mod(f"mod_wall_lip_{L:g}m", lambda b, L=L: straight_wall(b, "plain", L, lip=True),
            {"kind": "wall_lip", "length": L, "height": LIP_H, "thickness": T, "pivot": "left seam", "seams": [0.0, L]})
    for fam, R, n, H, facing, base, cap, mats in CURVED:
        for kind in ("plain", "door", "window"):
            mod(f"mod_wall_curved_r{R:.2f}_n{n}_{kind}", lambda b, k=kind, R=R, n=n, H=H, f=facing, ba=base, ma=mats:
                curved_wall(b, R, n, k, H, facing=f, base=ba, mat=ma, door_kw=dict(depth=T + 0.04) if f == "in" else
                            dict(depth=0.3)),
                {"kind": f"wall_curved_{kind}", "family": fam, "radius": round(R, 3), "arc_deg": round(360 / n, 3),
                 "height": H, "thickness": T, "facing": facing,
                 "pivot": "circle centre; segment centred on +X; rotate by its centre angle"})
        mod(f"mod_wall_curved_r{R:.2f}_n{n}_lip", lambda b, R=R, n=n, f=facing, ma=mats:
            curved_wall(b, R, n, "plain", facing=f, base=False, mat=ma, lip=True, cap="wood_c"),
            {"kind": "wall_curved_lip", "family": fam, "radius": round(R, 3), "arc_deg": round(360 / n, 3),
             "height": 0.45, "pivot": "circle centre"})
    roofs = [("snow_dome", dome_roof), ("aframe_cabin", aframe_roof), ("round_cottage", round_cottage_roof),
             ("treehouse", treehouse_roof), ("lighthouse_loft", lighthouse_lantern), ("lighthouse_cottage", lighthouse_cottage_roof),
             ("houseboat", houseboat_roof)]
    for fam, fn in roofs:
        mod(f"mod_roof_{fam}", fn, {"kind": "roof_section", "family": fam, "color_variants": ROOF_VARIANTS,
                                    "pivot": "same origin as the family's exterior shell (drop in place)"})
    for tag, rise, run, steps in (("1m", 1.0, 1.5, 5), ("2m", TH_["DZ"], 2.75, 10)):
        mod(f"mod_stairs_{tag}", lambda b, r=rise, u=run, n=steps: stair_flight(b, run=u, rise=r, steps=n),
            {"kind": "stairs", "length": run, "height": rise, "width": 0.78, "steps": steps,
             "pivot": "centre of the foot; climbs toward +Y"})
        mod(f"mod_stairs_landing_{tag}", lambda b, r=rise, u=run, n=steps: (stair_flight(b, run=u, rise=r, steps=n),
                                                                             landing(b, u, r)),
            {"kind": "stairs_landing", "length": run + 1.0, "height": rise, "width": 1.0, "pivot": "centre of the foot"})
    mod("mod_treehouse_support", lambda b: treehouse_support(b), {"kind": "support", "height": 4.6, "pivot": "trunk base centre"})
    mod("mod_treehouse_deck", lambda b: treehouse_deck(b, DECK["X1"] - DECK["X0"], DECK["Y1"] - DECK["Y0"], TH_["DZ"]),
        {"kind": "deck", "size_m": [DECK["X1"] - DECK["X0"], DECK["Y1"] - DECK["Y0"]], "deck_z": TH_["DZ"],
         "pivot": "deck centre on the ground"})
    mod("mod_lighthouse_floor", lambda b: lighthouse_floor(b),
        {"kind": "floor_round", "radius": round(2.4 + T / 2, 3), "sectors": 8, "top_z": FLOOR, "pivot": "circle centre",
         "rim": "stone blocks + rope rail on 8 posts",
         "floor_mask": "room cells inside radius 2.37"})
    mod("mod_houseboat_hull", houseboat_hull, {"kind": "hull", "length": 5.55, "beam": 2.64, "water_z": WATER_Z,
                                               "pivot": "boat centre (world z)"})
    mod("mod_houseboat_deck", lambda b: houseboat_deck(b), {"kind": "deck", "deck_z": round(BOAT_DECK, 3), "pivot": "boat centre"})
    mod("mod_door_insert_arched", lambda b: arched_door(b, 0, 0, 0, w=0.78, h=1.55, fw=0.1, depth=T + 0.04, socket=False),
        {"kind": "door_insert", "opening": [0.98, 1.68], "pivot": "opening bottom centre on the wall's front face"})
    mod("mod_door_insert_square", lambda b: square_door(b, 0, 0, 0),
        {"kind": "door_insert", "opening": [0.98, 1.7], "pivot": "opening bottom centre on the wall's front face"})
    mod("mod_window_insert_arched", lambda b: arched_window(b, 0, 0, WIN_ZB, w=0.56, h=0.72),
        {"kind": "window_insert", "style": "arched, mullions", "pivot": "on the wall's front face, opening bottom centre"})
    mod("mod_window_insert_square", lambda b: through_window(b, 0, outside=True),
        {"kind": "window_insert", "style": "square, shutters", "opening": [WIN_W, WIN_ZB, WIN_ZB + WIN_H],
         "pivot": "wall centre line, opening centre x"})
    mod("mod_window_insert_round", lambda b: round_window(b, 0, -T / 2, 1.15, r=0.22),
        {"kind": "window_insert", "radius": 0.22, "centre_z": 1.15, "pivot": "wall centre line"})


def build():
    snow_dome()
    snow_dome(2)
    aframe_cabin()
    with variant(AF, LEN=AF_TIERS[2]["LEN"]):
        aframe_cabin(2)
    round_cottage()
    with variant(RC, R=RC_TIERS[2]["R"], RISE=1.85):
        round_cottage(2)
    treehouse()
    with variant(TH_, CW=3.5, CD=2.5, CX=0.95, CY=0.3):
        treehouse(2)
    lighthouse_loft()
    with variant(LH, CW=3.5, CX=1.85):
        lighthouse_loft(2)
    houseboat()
    with variant(HB, CW=4.0):
        houseboat(2)
    build_modules()
