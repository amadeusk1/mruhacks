"""Player homes (concepts: Player Homes - Exterior Variations / Interior Personalities).

Six house types, each as
  <type>_exterior  assembled house on its snowy base (houseboat: on water at a dock). The roof /
                   top is a child <type>_exterior_roof the game hides for cutaway views.
  <type>_interior  the room shell players decorate on the 0.5 m grid. Visible walls are the back
                   (+Y) and left (-X); the front/right are a low cutaway lip (camera sits at +X,-Y).
Interior meta: cells (valid [ix, iy] floor cells), cell_origin (XY of cell [0,0]'s min corner),
cell_m, floor_z, blocked_cells, wall_slots {name: {pos, facing}}, ceiling_anchors {name: pos};
the A-frame also has cells_loft / loft_z. Sockets: spawn_inside, exit, wall_slot_*, ceiling_*.
"""
from common import *
from kits.buildings import (T, WALL_T, ROOF_T, DOOR_T, TRIM_T, masonry_wall, tiled_gable, entry_steps, attach)
from kits.winter import snowy_fir, snowy_rock, snow_lumps, snow_post, SNOW
from kits.nature_dock import water_surface, canopy, dock_post
from kits.world_misc import beam
from kits.plaza import WATER_Z

KIT = "homes"
PREVIEW_WIDTH = 24.0
FLOOR = 0.12                      # interior floor top
ICE = (tint("wall", "ice"), tint("wall_b", "snow_shade"), tint("wall_c", "snow"))
STRIPE_T = tint("stripe", "teal")
HULL_T = tint("hull", "wood_b")
PLASTER = (WALL_T, "plaster_shade", WALL_T)


# =============================================================================== shared pieces
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


def arched_door(b, cx=0.0, y=0.0, z=0.0, w=0.8, h=1.55, fw=0.12, depth=0.26, mat=DOOR_T, frame=TRIM_T,
                socket=True, port=True, backing=True):
    """Round-topped plank door for an opening whose face is at y (front -Y): leaf, chunky arch frame
    with keystone, porthole, iron straps, knob and threshold. A dark backing fills behind the arch."""
    r = w / 2
    zc = z + h - r
    if backing:
        b.box(w + 2 * fw - 0.02, 0.04, h + fw - 0.02, cx, y + depth - 0.08, z, "wood_deep", bevel=0)
    arc = [(r * math.cos(math.radians(a)), h - r + r * math.sin(math.radians(a))) for a in range(0, 181, 15)]
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


def arched_window(b, cx, y, zb, w=0.56, h=0.7, frame=TRIM_T, fw=0.075, sill=True):
    """Surface-mounted arch-topped window on a wall face at y: proud frame, glowing 4-pane glass, sill."""
    r = w / 2
    arc = [(r * math.cos(math.radians(a)), h - r + r * math.sin(math.radians(a))) for a in range(0, 181, 20)]
    b.prism([(-r, 0), (r, 0)] + arc[1:-1] + [(-r, h - r)], 0.03, x=cx, y=y - 0.01, z=zb, mat="glow_window")
    yf = y - 0.04
    for sx in (-1, 1):
        b.box(fw, 0.1, h - r, cx + sx * (r + fw / 2), yf, zb, frame, bevel=0.012)
    rm, n = r + fw / 2, 6
    for k in range(n):
        a = (k + 0.5) * 180 / n
        b.box(2 * rm * math.sin(math.pi / (2 * n)) * 1.2, 0.1, fw, cx + rm * math.cos(math.radians(a)), yf,
              zb + h - r + rm * math.sin(math.radians(a)), frame, bevel=0.01, rot=(0, -(a + 90), 0), center=True)
    b.box(0.035, 0.05, h - 0.03, cx, y - 0.04, zb, frame, bevel=0)
    b.box(w, 0.05, 0.035, cx, y - 0.04, zb + (h - r) * 0.62, frame, bevel=0)
    if sill:
        b.box(w + 0.24, 0.16, 0.06, cx, y - 0.08, zb - 0.06, "wood_b", bevel=0.015)


def round_window(b, cx, y, zc, r=0.24, frame=TRIM_T, cross=True):
    """Surface-mounted round (porthole) window on a wall face at y."""
    b.cyl(r, 0.03, cx, y - 0.01, zc, "glow_window", segs=12, rot=(90, 0, 0), center=True)
    b.torus(r + 0.035, 0.05, cx, y - 0.045, zc, frame, segs=12, ring=6, rot=(90, 0, 0))
    if cross:
        b.box(0.035, 0.04, 2 * r, cx, y - 0.04, zc - r, frame, bevel=0)
        b.box(2 * r, 0.04, 0.035, cx, y - 0.04, zc - 0.0175, frame, bevel=0)


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


def ring_wall(b, R, H, n, z0=0.0, thick=T, doors=(), windows=(), low=None, low_h=0.45, facing="out",
              mat=PLASTER, base=True, band=True, door_kw=None, win_kw=None, cap=None, offset=None):
    """Round wall of n flat segments (outer radius R). doors / windows: angles in degrees; the
    segment nearest a door angle is opened. low(angle)->True makes that segment a cutaway lip.
    facing='in' turns door/window faces into the room. Returns the segment angles."""
    step = 360 / n
    off = offset if offset is not None else (doors[0] % step if doors else 0.0)
    angs = [off + step * i for i in range(n)]
    near = lambda a, t: abs((a - t + 180) % 360 - 180) <= step / 2
    rm = R - thick / 2
    wseg = 2 * R * math.tan(math.pi / n) + 0.01
    for i, a in enumerate(angs):
        rz = a + 90 if facing == "out" else a - 90
        lowseg = low(a % 360) if low else False
        hh = low_h if lowseg else H
        with b.at((rm * math.cos(math.radians(a)), rm * math.sin(math.radians(a)), z0), rotz=rz):
            is_door = any(near(a, d) for d in doors) and not lowseg
            if is_door:
                kw = dict(w=0.78, h=1.55, fw=0.11)
                kw.update(door_kw or {})
                dt = kw["h"] + kw["fw"]
                b.box(wseg, thick, hh - dt, 0, 0, dt, pick(mat, i), bevel=0.02)
                arched_door(b, 0, -thick / 2, 0, socket=False, **kw)
            else:
                b.box(wseg, thick, hh, 0, 0, 0, pick(mat, i), bevel=0.02)
                if base:
                    b.box(wseg + 0.01, thick + 0.07, 0.3, 0, 0, 0, pick(("stone", "stone_dark", "paving_b"), i), bevel=0.03)
                if any(near(a, wa) for wa in windows) and not lowseg:
                    kw = dict(w=0.52, h=0.72)
                    kw.update(win_kw or {})
                    arched_window(b, 0, -thick / 2, 0.85, **kw)
            if band and not lowseg:
                b.box(wseg + 0.01, thick + 0.08, 0.13, 0, 0, hh - 0.13, TRIM_T, bevel=0.015)
            if cap and lowseg:
                b.box(wseg + 0.01, thick + 0.05, 0.07, 0, 0, hh, cap, bevel=0.02)
    return angs


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
        for k in range(7):  # drifts on the slope
            a = rng.uniform(0, 2 * math.pi)
            s = rng.uniform(0.25, 0.75) * L
            rr = Re - s * math.cos(th)
            nrm = Vector((math.cos(a) * math.sin(th), math.sin(a) * math.sin(th), math.cos(th)))
            c = Vector((rr * math.cos(a), rr * math.sin(a), ze + s * math.sin(th)))
            up = Vector((-math.cos(a) * math.cos(th), -math.sin(a) * math.cos(th), math.sin(th)))
            tang = Vector((-math.sin(a), math.cos(a), 0))
            with b.at((0, 0, 0), rotz=0):
                snow_clump(b, c, nrm, up, tang, rot=(0, 0, 0), seed=k * 3 + seed, size=0.9)


def settle(b, p, n, gap=0.02):
    """Drop a point along -n onto the geometry already built in b; returns the local hit point
    lifted by gap (or p if nothing is hit). Keeps snow resting on the real tile surface."""
    from mathutils.bvhtree import BVHTree
    xf = b.xf
    pw, nw = xf @ Vector(p), (xf.to_3x3() @ Vector(n)).normalized()
    hit = BVHTree.FromBMesh(b.bm).ray_cast(pw + nw * 2.5, -nw, 5.0)[0]
    return (xf.inverted() @ (hit + nw * gap)) if hit is not None else Vector(p)


def slope_snow(b, span, length, rise, z, side, spots, overhang=0.3, tile_thick=0.09, size=1.0):
    """Snow drifts on one slope of a tiled_gable (ridge along Y). spots: [(s 0..1 up the slope, y)]."""
    half = span / 2
    A = math.atan(rise / half)
    run = half + overhang
    eave = z - overhang * rise / half
    Ls = run / math.cos(A)
    n = Vector((side * math.sin(A), 0, math.cos(A)))
    up = Vector((side * -math.cos(A), 0, math.sin(A)))           # uphill along the slope
    for k, (s, y) in enumerate(spots):
        c = Vector((side * (run - s * Ls * math.cos(A)), y, eave + s * Ls * math.sin(A)))
        snow_clump(b, c, n, up, Vector((0, 1, 0)), rot=(0, side * math.degrees(A), 0), seed=k + int(y * 10), size=size)


def snow_clump(b, c, n, u, v, rot, seed=0, size=1.0):
    """A drift of 4-6 flattened lumps around c on a surface with normal n (u, v span the surface),
    each dropped onto the real geometry so it hugs the tiles."""
    rng = random.Random(seed)
    for i in range(rng.randint(4, 6)):
        r = rng.uniform(0.12, 0.22) * size
        p = settle(b, c + u * rng.uniform(-0.3, 0.3) * size + v * rng.uniform(-0.38, 0.38) * size, n, gap=-r * 0.12)
        b.blob(r * 1.35, r * 1.15, r * 0.42, p.x, p.y, p.z, pick(SNOW, i + seed), subdiv=1, rot=rot, jitter=r * 0.08)


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


def ridge_snow(b, length, z, w=0.36):
    b.box(w, length, 0.1, 0, 0, z, "snow", bevel=0.04)
    snow_lumps(b, 0, 0, z + 0.08, w * 0.5, length * 0.9, max(2, int(length * 2)), r=(0.08, 0.13), flat=0.45)


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


def stair_flight(b, x, y_top, z_top, y_bot, w=0.8, steps=10, rails=True):
    """Wooden stair descending from (x, y_top, z_top) toward y_bot at ground (z=0)."""
    run = y_top - y_bot
    for i in range(steps):
        t = (i + 0.5) / steps
        zz = z_top * (1 - (i + 1) / steps)
        yy = y_top - run * t
        b.box(w, run / steps + 0.03, 0.06, x, yy, zz, pick(("wood", "wood_c", "wood_b"), i), bevel=0.012)
        b.box(w - 0.06, 0.03, z_top / steps, x, yy - run / steps / 2 + 0.03, zz - z_top / steps + 0.06, "wood_dark", bevel=0)
    for sx in (-1, 1):
        beam(b, (x + sx * (w / 2 + 0.03), y_bot, 0.0), (x + sx * (w / 2 + 0.03), y_top, z_top), 0.06, 0.16, "wood_b", 0.012)
    if rails:
        for sx in (-1, 1):
            for t in (0.0, 0.5, 1.0):
                yy, zz = y_bot + run * t, z_top * t
                snow_post(b, x + sx * (w / 2 + 0.06), yy, zz, h=0.75, w=0.09)
            beam(b, (x + sx * (w / 2 + 0.06), y_bot, 0.7), (x + sx * (w / 2 + 0.06), y_top, z_top + 0.7), 0.05, 0.07, "wood", 0.01)


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


# =============================================================================== interior helpers
class Room:
    """Collects the grid, wall slots and ceiling anchors of an interior shell."""

    def __init__(self, b, inside, hx, hy, floor_z=FLOOR, corner=False):
        """corner=True anchors the grid at the room's (-hx, -hy) corner (rect rooms whose sides are
        multiples of CELL but not of 2*CELL); otherwise the grid is centred on the origin."""
        self.b, self.inside, self.floor_z = b, inside, floor_z
        if corner:
            self.origin = (-hx, -hy)
            self.nx, self.ny = math.ceil(hx / CELL - 1e-6), math.ceil(hy / CELL - 1e-6)
        else:
            self.nx, self.ny = math.ceil(hx / CELL - 1e-6), math.ceil(hy / CELL - 1e-6)
            self.origin = (-self.nx * CELL, -self.ny * CELL)
        self.blockers = []
        self.slots, self.anchors = {}, {}

    def block_circle(self, x, y, r):
        self.blockers.append(lambda cx, cy: math.hypot(cx - x, cy - y) < r)

    def block_rect(self, x0, x1, y0, y1):
        self.blockers.append(lambda cx, cy: x0 <= cx <= x1 and y0 <= cy <= y1)

    def cells(self, inside=None, origin=None):
        inside = inside or self.inside
        ox, oy = origin or self.origin
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
        cx = lambda c: (self.origin[0] + (c[0] + 0.5) * CELL, self.origin[1] + (c[1] + 0.5) * CELL)
        blocked = [c for c in cells if any(f(*cx(c)) for f in self.blockers)]
        assert cells and len(blocked) < len(cells), "room grid is empty or fully blocked"
        m = {"cells": cells, "cell_origin": [round(v, 3) for v in self.origin], "cell_m": CELL,
             "floor_z": self.floor_z, "blocked_cells": blocked, "wall_slots": self.slots,
             "ceiling_anchors": self.anchors}
        m.update(extra)
        return m


def round_floor(b, R, z=FLOOR, plank=0.22, slab=True):
    if slab:
        b.cyl(R + 0.18, z - 0.06, 0, 0, 0, "stone_dark", segs=24, bevel=0.03)
    n = int(2 * R / plank)
    for i in range(n):
        y = -R + plank * (i + 0.5)
        ye = abs(y) + plank / 2
        if ye >= R:
            continue
        L = 2 * math.sqrt(R * R - ye * ye)
        b.box(L, plank - 0.012, 0.06, 0, y, z - 0.06, pick(("wood", "wood_c", "wood_b"), i * 3), bevel=0.01)


def rect_floor(b, W, D, z=FLOOR):
    b.box(W + 0.5, D + 0.5, z - 0.06, 0, 0, 0, "stone_dark", bevel=0.03)
    planks(b, W + 0.06, D + 0.06, z=z - 0.06, plank=0.2, thick=0.06, along="y")


def rect_room_walls(b, W, D, H, door_x, wins_back=(), wins_left=(), lip=0.42, wall=WALL_T, timber=True):
    """Interior walls of a W x D (inner) room: full back (+Y) and left (-X) walls with their
    detail facing in, low lips on the front and right. Door on the left wall at y=door_x."""
    with b.at((0, D / 2 + T / 2, 0), rotz=0):            # back wall, inner face at local -Y
        ops = [(x, 0.62, 0.85, 1.6) for x in wins_back]
        masonry_wall(b, W + 2 * T, H, openings=[(x, 0.62, 0.85, 1.6) for x in wins_back], base=False, timber=timber,
                     mat=wall)
        for x in wins_back:
            _through_window(b, x)
    with b.at((-W / 2 - T / 2, 0, 0), rotz=90):           # left wall: local -Y faces +X (into the room)
        ops = [(door_x, 0.98, 0, 1.68)] + [(y, 0.62, 0.85, 1.6) for y in wins_left]
        masonry_wall(b, D, H, openings=ops, base=False, timber=timber, mat=wall)
        arched_door(b, door_x, -T / 2, 0, w=0.78, h=1.55, fw=0.1, depth=T + 0.04, socket=False)
        for y in wins_left:
            _through_window(b, y)
    with b.at((0, -D / 2 - T / 2, 0), rotz=180):
        masonry_wall(b, W + 2 * T, lip, base=False, cap="wood_c", mat=wall)
    with b.at((W / 2 + T / 2, 0, 0), rotz=90):
        masonry_wall(b, D, lip, base=False, cap="wood_c", mat=wall)
    # skirting along the full walls
    b.box(W, 0.04, 0.1, 0, D / 2 - 0.02, FLOOR, "wood_dark", bevel=0.01)
    b.box(0.04, D, 0.1, -W / 2 + 0.02, 0, FLOOR, "wood_dark", bevel=0.01)


def _through_window(b, x, w=0.62, zb=0.85, h=0.75):
    """Window seen from inside a wall opening (wall centred on local y=0, room at -Y)."""
    b.box(w, 0.03, h, x, 0, zb, "glow_window", bevel=0)
    for s in (-1, 1):
        b.box(0.07, T + 0.03, h, x + s * (w / 2 + 0.035), 0, zb, TRIM_T, bevel=0.01)
        b.box(0.04, 0.03, h, x, s * 0.03, zb, TRIM_T, bevel=0)
        b.box(w, 0.03, 0.04, x, s * 0.03, zb + h / 2 - 0.02, TRIM_T, bevel=0)
    b.box(w + 0.14, T + 0.03, 0.07, x, 0, zb + h, TRIM_T, bevel=0.01)
    b.box(w + 0.3, T + 0.1, 0.06, x, -0.04, zb - 0.07, "wood_b", bevel=0.015)


def rect_slots(room, W, D, z, door_y, wins_back=(), wins_left=()):
    """Wall slots along the back and left walls, skipping openings."""
    cand = lambda L: [round(-L / 2 + 0.35 + 0.5 * i, 3) for i in range(int((L - 0.7) / 0.5 + 1e-6) + 1)]
    for x in cand(W):
        if all(abs(x - wx) >= 0.5 for wx in wins_back):
            room.wall_slot((x, D / 2, z), (0, -1))
    for y in cand(D):
        if abs(y - door_y) >= 0.7 and all(abs(y - wy) >= 0.5 for wy in wins_left):
            room.wall_slot((-W / 2, y, z), (1, 0))


def ring_slots(room, R, z, angles):
    for a in angles:
        r = math.radians(a)
        room.wall_slot((R * math.cos(r), R * math.sin(r), z), (-math.cos(r), -math.sin(r)))


def low_front(a, center=315, half=95):
    """Cutaway sector of a round room (faces the +X,-Y camera)."""
    return abs((a - center + 180) % 360 - 180) <= half


def finish_house(b, roof, name, meta):
    house = b.finish(KIT, "building", meta)
    attach(roof.finish(KIT, "roof"), house)
    return house


# =============================================================================== snow dome
def snow_dome():
    R, TH, HB = 2.3, 0.3, 0.55
    b = Builder("snow_dome_exterior", seed=601)
    roof = Builder("snow_dome_exterior_roof", seed=602)
    snow_base(b, 3.5, 3.2, seed=61, rocks=7)
    dphi = HB / R
    door_half = lambda rr: math.asin(min(1, 0.72 / rr))
    for k in range(6):
        phi = (k + 0.5) * dphi
        if phi > math.radians(63):
            break
        rc = (R - TH / 2) * math.cos(phi)
        zc = (R - TH / 2) * math.sin(phi)
        cnt = max(5, round(2 * math.pi * R * math.cos(phi) / 0.66))
        tgt = roof if zc > 1.45 else b
        for c in range(cnt):
            a = 2 * math.pi * (c + 0.5 * (k % 2)) / cnt
            if zc < 1.75 and abs((a - 1.5 * math.pi + math.pi) % (2 * math.pi) - math.pi) < door_half(rc):
                continue  # entrance opening at the front
            with tgt.at((rc * math.cos(a), rc * math.sin(a), zc), rotz=math.degrees(a) + 90):
                tgt.box(2 * math.pi * R * math.cos(phi) / cnt * 1.03, TH, HB * 1.04, 0, 0, 0, pick(ICE, k * 7 + c * 3),
                        bevel=0.06, rot=(-math.degrees(phi), 0, 0), center=True, jitter=0.012)
    zcap = R - 0.52
    roof.blob(1.18, 1.18, 0.56, 0, 0, zcap, ICE[0], subdiv=2, jitter=0.02)
    b.cyl(R - 0.2, 0.2, 0, 0, -0.05, ICE[1], segs=16)                              # closes the floor
    # snow on top
    roof.blob(0.92, 0.86, 0.2, 0.05, 0.1, zcap + 0.42, "snow", subdiv=2, jitter=0.02)
    for k, (a, s) in enumerate(((40, 0.62), (130, 0.55), (210, 0.6), (300, 0.5))):
        phi = math.radians(52)
        p = (R * math.cos(phi) * math.cos(math.radians(a)), R * math.cos(phi) * math.sin(math.radians(a)), R * math.sin(phi))
        with roof.at(p, rotz=a + 90):
            roof.blob(s * 0.8, s * 0.6, 0.07, 0, -0.02, 0, pick(SNOW, k), subdiv=2, rot=(-52, 0, 0), jitter=0.01)
    # entrance tunnel: arch of blocks around the door
    y0, y1 = -R * 0.72, -R - 0.55
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
    # windows on the dome surface
    for a, phi, kind in ((215, 30, "round"), (325, 26, "arch")):
        p = (R * math.cos(math.radians(phi)) * math.cos(math.radians(a)),
             R * math.cos(math.radians(phi)) * math.sin(math.radians(a)), R * math.sin(math.radians(phi)))
        with b.at(p, rotz=a + 90):
            with b.at((0, 0, 0), rot=(-phi, 0, 0)):
                if kind == "round":
                    round_window(b, 0, 0.02, 0, r=0.3)
                else:
                    arched_window(b, 0, 0.02, -0.3, w=0.42, h=0.6)
    chimney_stone(roof, 0.95, 0.85, 1.4, 2.95)
    post_lantern(b, -1.05, y1 + 0.05, side=1, h=1.55)
    barrel(b, 0.95, y1 + 0.25)
    snowy_rock(b, 1.5, -1.9, 0.4, 0.3, 0.3, 1)
    snowy_rock(b, -1.7, -1.7, 0.35, 0.28, 0.26, 2)
    stepping_stones(b, 0, y1 - 0.25, -3.1, n=3, seed=6)
    b.socket("door", (0, y1 - 0.6, 0), rotz=180)
    finish_house(b, roof, "snow_dome_exterior", {"interior": "snow_dome_interior", "roof_child": "snow_dome_exterior_roof",
                                                  "footprint_m": [7.0, 6.4]})

    # interior: round room under the dome (starlight room)
    Ri = 2.3
    b = Builder("snow_dome_interior", seed=611)
    round_floor(b, Ri + T / 2)
    angs = ring_wall(b, Ri + T, 2.0, 16, z0=0, facing="in", doors=(160,), windows=(95,), low=low_front,
                     mat=PLASTER, base=False, cap="wood_c", door_kw=dict(depth=T + 0.04))
    # a second, inward-leaning course hints at the dome above the full walls
    for i, a in enumerate(angs):
        if low_front(a % 360):
            continue
        rm = Ri + 0.02
        with b.at((rm * math.cos(math.radians(a)) * 0.97, rm * math.sin(math.radians(a)) * 0.97, 2.0), rotz=a - 90):
            b.box(2 * Ri * math.tan(math.pi / 16) * 0.98, 0.18, 0.55, 0, 0, 0, pick(ICE, i), bevel=0.04,
                  rot=(25, 0, 0), jitter=0.006)
    room = Room(b, lambda x, y: math.hypot(x, y) <= Ri - 0.03, Ri, Ri)
    dr = math.radians(160)
    room.block_circle((Ri - 0.5) * math.cos(dr), (Ri - 0.5) * math.sin(dr), 0.75)
    ring_slots(room, Ri, 1.3, (70, 120, 200, 225))
    for x, y in ((0, 0), (-0.9, 0.7), (0.8, 0.8)):
        room.anchor((x, y, 2.45))
    sp = (Ri - 0.9) * math.cos(dr), (Ri - 0.9) * math.sin(dr)
    b.socket("spawn_inside", (sp[0], sp[1], FLOOR), rotz=-20)
    b.socket("exit", ((Ri - 0.25) * math.cos(dr), (Ri - 0.25) * math.sin(dr), FLOOR))
    b.finish(KIT, "room", room.meta(shape="round", radius_m=Ri, exterior="snow_dome_exterior"))


# =============================================================================== A-frame cabin
def aframe_cabin():
    SPAN, LEN, KNEE, RISE, SLAB = 4.4, 4.4, 0.9, 4.2, 0.2
    ZE = SLAB + KNEE
    half = SPAN / 2
    b = Builder("aframe_cabin_exterior", seed=621)
    roof = Builder("aframe_cabin_exterior_roof", seed=622)
    snow_base(b, 3.7, 3.6, seed=62, rocks=6, back_firs=((-2.7, 1.6, 2.6), (2.75, 1.2, 2.3)))
    b.box(SPAN + 0.3, LEN + 0.3, SLAB, 0, 0, 0, "stone_dark", bevel=0.035)
    # knee walls along both sides
    for sx in (-1, 1):
        with b.at((sx * (half - T / 2), 0, SLAB), rotz=90 * sx):
            masonry_wall(b, LEN, KNEE + 0.15, base=False, timber=False)
    # front and back gables
    dx, dw, dh = 0.0, 0.9, 1.7
    front_ops = [(dx - dw / 2 - 0.12, dx + dw / 2 + 0.12, SLAB, SLAB + dh + 0.12),
                 (-0.4, 0.4, SLAB + 2.2, SLAB + 3.05)]
    gable_facade(b, half - 0.05, ZE, RISE, front_ops, z0=SLAB, y=-LEN / 2 + T / 2)
    gable_facade(b, half - 0.05, ZE, RISE, [(-0.35, 0.35, SLAB + 1.0, SLAB + 1.8)], z0=SLAB, y=LEN / 2 - T / 2)
    yF = -LEN / 2
    arched_door(b, dx, yF, SLAB, w=dw, h=dh, fw=0.12, depth=T + 0.06, socket=False)
    # attic window: deep arched window in the gable opening
    b.box(0.8, 0.04, 0.85, 0, yF + T - 0.05, SLAB + 2.2, "wood_deep", bevel=0)
    arched_window(b, 0, yF + 0.04, SLAB + 2.25, w=0.62, h=0.78)
    with b.at((0, LEN / 2, 0), rotz=180):
        arched_window(b, 0, 0.04, SLAB + 1.0, w=0.56, h=0.74)
    # timber on the front gable
    for sx in (-1, 1):
        beam(b, (sx * (half - 0.25), yF - 0.06, ZE), (sx * 0.08, yF - 0.06, ZE + RISE * 0.96), 0.12, 0.1, TRIM_T)
    b.box(SPAN - 0.4, 0.1, 0.12, 0, yF - 0.06, SLAB + 2.05, TRIM_T, bevel=0.015)
    # porch: deck, steps, rails, firewood
    b.box(2.6, 1.0, 0.16, 0, yF - 0.5, 0.04, "wood_c", bevel=0.02)
    planks(b, 2.6, 1.0, z=0.2, plank=0.2, thick=0.04, along="x", y=yF - 0.5)
    entry_steps(b, 0, yF - 1.0, w=1.1, steps=2, rise=0.12, tread=0.3, mats=("wood_b", "wood"))
    rail_run(b, (-1.3, yF - 0.95), (-1.3, yF - 0.05), 0.24, posts=2)
    rail_run(b, (-1.3, yF - 0.95), (-0.6, yF - 0.95), 0.24, posts=2)
    rail_run(b, (1.3, yF - 0.95), (1.3, yF - 0.05), 0.24, posts=2)
    for i in range(3):
        for j in range(3 - i):
            b.cyl(0.09, 0.62, 1.6 + j * 0.19 + i * 0.095, yF - 0.35, 0.09 + i * 0.16, pick(("wood_b", "brown"), i + j),
                  segs=7, rot=(90, 0, 0), center=True)
            b.cyl(0.06, 0.63, 1.6 + j * 0.19 + i * 0.095, yF - 0.35, 0.09 + i * 0.16, "tan", segs=7, rot=(90, 0, 0),
                  center=True)
    wall_lantern(b, dx + 0.75, yF - 0.05, SLAB + 1.55)
    # roof (child): steep tiled A, dormer, chimney, snow
    tiled_gable(roof, SPAN, LEN, RISE, z=ZE, overhang=0.32, tile=0.46, tile_thick=0.11, gable=None, timber=False)
    slope_snow(roof, SPAN, LEN, RISE, ZE, -1, ((0.35, -1.2), (0.6, 0.6), (0.85, -0.3), (0.2, 1.5)), overhang=0.32, tile_thick=0.11, size=1.5)
    slope_snow(roof, SPAN, LEN, RISE, ZE, 1, ((0.8, -1.4), (0.45, 1.6), (0.15, -0.9), (0.6, -0.2)), overhang=0.32, tile_thick=0.11, size=1.5)
    ridge_snow_on(roof, SPAN, LEN + 0.64, RISE, ZE, tile_thick=0.11, w=0.48)
    # dormer on the +X slope (faces +X)
    xf = 1.55                                                      # dormer front face (world x)
    zf = ZE + (half - xf) * RISE / half
    with roof.at((xf - 0.35, 0.4, zf - 0.05), rotz=90):
        roof.box(1.0, 1.5, 1.2, 0, 0.4, 0, WALL_T, bevel=0.02)
        arched_window(roof, 0, -0.35, 0.3, w=0.5, h=0.62)
        with roof.at((0, 0.4, 0)):
            tiled_gable(roof, 1.0, 1.5, 0.5, z=1.2, overhang=0.16, tile=0.3, tile_thick=0.07, gable=WALL_T, timber=False)
            ridge_snow_on(roof, 1.0, 1.8, 0.5, 1.2, tile_thick=0.07, w=0.24)
    chimney_stone(roof, -1.15, 1.0, ZE + 0.6, ZE + RISE * 0.9)
    b.socket("door", (dx, yF - 1.3, 0), rotz=180)
    finish_house(b, roof, "aframe_cabin_exterior", {"interior": "aframe_cabin_interior", "roof_child": "aframe_cabin_exterior_roof",
                                                    "footprint_m": [SPAN, LEN], "floor_z": SLAB})

    # interior: A-frame room with loft, stair and wood stove (cozy loft)
    HW, HD = 2.0, 2.0                       # inner half extents
    K, SL = 0.9, RISE / half                # knee height, roof slope
    LOFT_Z, LOFT_Y0 = 2.0, 0.5
    roof_z = lambda x: FLOOR + K + (HW - abs(x)) * SL
    b = Builder("aframe_cabin_interior", seed=631)
    rect_floor(b, 2 * HW, 2 * HD)
    A = math.atan(SL)
    Ls = (HW + 0.1) / math.cos(A) * 0.98
    # left roof plane seen from inside: board lining with rafters
    mid = Vector((-(HW + 0.1) / 2, 0, FLOOR + K + (HW + 0.1) / 2 * SL))
    b.box(Ls, 2 * HD + 0.2, 0.08, mid.x - 0.06, 0, mid.z + 0.05, "wood_c", bevel=0.01, rot=(0, -math.degrees(A), 0), center=True)
    for y in (-1.6, -0.55, 0.5, 1.55):
        b.box(Ls, 0.1, 0.12, mid.x + 0.02, y, mid.z - 0.03, "wood_dark", bevel=0.012, rot=(0, -math.degrees(A), 0), center=True)
    with b.at((-HW - T / 2, 0, 0), rotz=-90):
        masonry_wall(b, 2 * HD, K + FLOOR, base=False, mat=WALL_T)
    # back gable (inner face) with door under the loft and a window above it
    yB = HD + T / 2
    ops = [(-1.0 - 0.5, -1.0 + 0.5, 0, 1.75), (-0.32, 0.32, 2.3, 3.0)]
    gable_facade(b, HW + 0.05, FLOOR + K, RISE * (HW + 0.05) / half, ops, z0=0, y=yB)
    with b.at((0, yB, 0), rotz=0):
        arched_door(b, -1.0, -T / 2, FLOOR, w=0.82, h=1.55, fw=0.1, depth=T + 0.04, socket=False)
        _through_window(b, 0, w=0.5, zb=2.35, h=0.6)
    # right side and front: low lips only
    with b.at((HW + T / 2, 0, 0), rotz=90):
        masonry_wall(b, 2 * HD, 0.42, base=False, cap="wood_c")
    with b.at((0, -HD - T / 2, 0), rotz=180):
        masonry_wall(b, 2 * HW + 2 * T, 0.42, base=False, cap="wood_c")
    # loft platform across the back with railing and a straight stair on the right
    b.box(2 * HW, HD - LOFT_Y0, 0.14, 0, (HD + LOFT_Y0) / 2, FLOOR + LOFT_Z - 0.14, "wood_b", bevel=0.02)
    planks(b, 2 * HW - 0.4, HD - LOFT_Y0, z=FLOOR + LOFT_Z, plank=0.2, thick=0.04, along="y", y=(HD + LOFT_Y0) / 2)
    for x in (-1.4, 0.0, 1.4):
        b.box(0.14, 0.14, LOFT_Z - 0.14, x, LOFT_Y0 + 0.1, FLOOR, "wood_dark", bevel=0.02)
    b.box(2 * HW, 0.16, 0.18, 0, LOFT_Y0 + 0.08, FLOOR + LOFT_Z - 0.3, "wood_dark", bevel=0.02)
    for i in range(7):
        x = -1.2 + i * 0.27
        b.box(0.05, 0.05, 0.6, x, LOFT_Y0 + 0.05, FLOOR + LOFT_Z, "wood", bevel=0.008)
    b.box(1.7, 0.08, 0.08, -0.4, LOFT_Y0 + 0.05, FLOOR + LOFT_Z + 0.6, "wood_c", bevel=0.012)
    SX0, SX1 = 0.6, 1.15
    steps = 9
    for i in range(steps):
        yy = -0.95 + (LOFT_Y0 + 0.95) * (i + 0.5) / steps
        zz = FLOOR + LOFT_Z * (i + 1) / steps - 0.06
        b.box(SX1 - SX0, (LOFT_Y0 + 0.95) / steps + 0.02, 0.06, (SX0 + SX1) / 2, yy, zz, pick(("wood", "wood_c"), i), bevel=0.01)
    for x in (SX0 - 0.03, SX1 + 0.03):
        beam(b, (x, -0.95, FLOOR), (x, LOFT_Y0, FLOOR + LOFT_Z), 0.05, 0.16, "wood_b", 0.012)
    # wood stove with flue through the roof (front-left)
    sx, sy = -1.35, -1.0
    b.box(0.95, 0.95, 0.08, sx, sy, FLOOR, "stone", bevel=0.02)
    b.box(0.55, 0.5, 0.5, sx, sy, FLOOR + 0.12, "iron", bevel=0.03)
    b.box(0.32, 0.03, 0.22, sx, sy - 0.25, FLOOR + 0.22, "glow", bevel=0)
    for lx in (-0.2, 0.2):
        for ly in (-0.18, 0.18):
            b.box(0.06, 0.06, 0.06, sx + lx, sy + ly, FLOOR + 0.08, "iron", bevel=0.01)
    b.cyl(0.08, roof_z(sx) - FLOOR - 0.6, sx, sy, FLOOR + 0.62, "iron", segs=8)
    b.box(0.6, 0.55, 0.06, sx, sy, FLOOR + 0.62, "iron_light", bevel=0.015)
    room = Room(b, lambda x, y: abs(x) <= HW + 1e-6 and abs(y) <= HD + 1e-6, HW, HD)
    room.block_rect(SX0 - 0.1, SX1 + 0.1, -1.1, LOFT_Y0)          # stair
    room.block_rect(sx - 0.55, sx + 0.55, sy - 0.55, sy + 0.55)    # stove + hearth
    room.block_rect(-1.6, -0.4, 1.0, HD)                            # door swing / entry
    loft_inside = lambda x, y: abs(x) <= 1.0 + 1e-6 and LOFT_Y0 - 1e-6 <= y <= HD + 1e-6
    cells_loft = room.cells(inside=loft_inside)
    # wall slots: back wall beside the door, the left slope's knee wall
    room.wall_slot((0.3, HD, 1.3), (0, -1))
    room.wall_slot((1.2, HD, 1.3), (0, -1))
    for y in (-1.2, -0.2, 0.8):
        room.wall_slot((-HW, y, FLOOR + 0.6), (1, 0))
    for x, y in ((0.0, -0.6), (-0.6, -1.3), (0.5, -1.4)):
        room.anchor((x, y, roof_z(x) - 0.25))
    b.socket("spawn_inside", (-1.0, HD - 0.75, FLOOR), rotz=180)
    b.socket("exit", (-1.0, HD - 0.25, FLOOR))
    b.finish(KIT, "room", room.meta(shape="aframe", exterior="aframe_cabin_exterior", cells_loft=cells_loft,
                                    loft_z=round(FLOOR + LOFT_Z, 3), headroom_note="roof height at x = floor_z + 0.9 + (2.0 - |x|) * 1.909"))


# =============================================================================== round cottage
def round_cottage():
    R, H, SLAB, RISE = 2.2, 1.9, 0.22, 1.55
    b = Builder("round_cottage_exterior", seed=641)
    roof = Builder("round_cottage_exterior_roof", seed=642)
    snow_base(b, 3.4, 3.2, seed=64, rocks=5, back_firs=((2.6, 1.4, 2.0),))
    b.cyl(R + 0.2, SLAB, 0, 0, 0, "stone_dark", segs=14, bevel=0.03)
    with b.at((0, 0, SLAB)):
        ring_wall(b, R, H, 14, doors=(270,), windows=(215, 330, 30, 150), door_kw=dict(w=0.78, h=1.55, fw=0.11, depth=0.3))
        dr = -R
    entry_steps(b, 0, -R - 0.12, w=1.1, steps=2, rise=SLAB / 2, tread=0.3, mats=("stone", "stone_dark"))
    with b.at((0, 0, SLAB)):
        for a in (243, 297):
            r = math.radians(a)
            with b.at((R * math.cos(r), R * math.sin(r), 0), rotz=a + 90):
                wall_lantern(b, 0, 0.02, 1.55)
    # fence and planter
    rail_run(b, (-2.75, -1.2), (-2.4, -2.0), 0.0, posts=2)
    rail_run(b, (-2.4, -2.0), (-1.55, -2.45), 0.0, posts=2)
    planter_box(b, 0.8, 0.32, 0.28, x=1.6, y=-2.25, z=0.0, flowers=("leaf_b",))
    snow_lumps(b, 1.6, -2.25, 0.3, 0.7, 0.25, 3, r=(0.06, 0.1))
    barrel(b, 2.1, -1.65)
    stepping_stones(b, 0, -R - 0.75, -3.0, n=2, seed=4)
    cone_roof(roof, R, RISE, SLAB + H, overhang=0.4, seed=7)
    roof.box(0.5, 0.5, 1.2, 0.85, 0.7, SLAB + H + 0.3, "chimney", bevel=0.03)
    chimney_stone(roof, 0.85, 0.7, SLAB + H + 0.6, SLAB + H + RISE + 0.35)
    b.socket("door", (0, -R - 0.9, 0), rotz=180)
    finish_house(b, roof, "round_cottage_exterior", {"interior": "round_cottage_interior", "roof_child": "round_cottage_exterior_roof",
                                                     "footprint_m": [2 * R, 2 * R], "floor_z": SLAB})

    Ri = 2.2
    b = Builder("round_cottage_interior", seed=651)
    round_floor(b, Ri + T / 2)
    ring_wall(b, Ri + T, 2.1, 16, facing="in", doors=(195,), windows=(90, 140, 60), low=low_front, base=False,
              cap="wood_c", door_kw=dict(depth=T + 0.04), offset=195 % 22.5)
    for k in range(8):  # exposed ceiling beams on the full walls' top
        a = 45 + k * 22.5
        r = math.radians(a)
        if low_front(a):
            continue
        b.box(0.12, 0.6, 0.14, (Ri - 0.2) * math.cos(r), (Ri - 0.2) * math.sin(r), 1.95, "wood_dark", bevel=0.015,
              rot=(0, 0, a + 90))
    room = Room(b, lambda x, y: math.hypot(x, y) <= Ri - 0.03, Ri, Ri)
    dr = math.radians(195)
    room.block_circle((Ri - 0.5) * math.cos(dr), (Ri - 0.5) * math.sin(dr), 0.75)
    ring_slots(room, Ri, 1.35, (75, 115, 165, 220))
    for x, y in ((0, 0), (-0.8, 0.7), (0.7, 0.6)):
        room.anchor((x, y, 2.3))
    b.socket("spawn_inside", ((Ri - 0.9) * math.cos(dr), (Ri - 0.9) * math.sin(dr), FLOOR), rotz=-75)
    b.socket("exit", ((Ri - 0.25) * math.cos(dr), (Ri - 0.25) * math.sin(dr), FLOOR))
    b.finish(KIT, "room", room.meta(shape="round", radius_m=Ri, exterior="round_cottage_exterior"))


# =============================================================================== treehouse
def treehouse():
    DZ = 1.9                                  # deck top
    TX, TY = -1.25, 0.65                      # trunk
    CW, CD, CH = 2.4, 2.0, 1.75               # cabin
    CX, CY = 0.45, 0.25
    b = Builder("treehouse_exterior", seed=661)
    roof = Builder("treehouse_exterior_roof", seed=662)
    snow_base(b, 3.6, 3.3, seed=66, rocks=6)
    # trunk with root flares and limbs
    b.cyl(0.62, 4.6, TX, TY, 0, "bark", segs=9, r2=0.38, jitter=0.03)
    for k in range(6):
        a = 360 * k / 6 + 15
        r = math.radians(a)
        b.cyl(0.26, 0.9, TX + 0.45 * math.cos(r), TY + 0.45 * math.sin(r), -0.05, "bark", segs=6, r2=0.06,
              rot=(0, 62, a), jitter=0.02)
    for (az, el, L) in ((150, 40, 1.7), (40, 45, 1.6), (260, 50, 1.3), (95, 35, 1.5)):
        with b.at((TX, TY, 3.6), rot=(0, 90 - el, az)):
            b.cyl(0.17, L, 0, 0, 0, "bark", segs=6, r2=0.08)
    canopy(roof, [(TX - 0.9, TY + 0.4, 4.7, 0.95), (TX + 0.8, TY + 0.6, 4.95, 1.05), (TX - 0.1, TY - 0.6, 5.2, 0.95),
                  (TX + 1.2, TY + 1.2, 5.0, 0.75), (TX - 0.3, TY + 0.9, 5.6, 0.85), (TX - 1.6, TY - 0.4, 4.4, 0.7)],
           snow=True, seed=6)
    # deck on posts and braces
    DX0, DX1, DY0, DY1 = -2.05, 2.0, -1.45, 1.6
    dcx, dcy = (DX0 + DX1) / 2, (DY0 + DY1) / 2
    b.box(DX1 - DX0, DY1 - DY0, 0.12, dcx, dcy, DZ - 0.2, "wood_dark", bevel=0.02)
    planks(b, DX1 - DX0, DY1 - DY0, z=DZ - 0.08, plank=0.22, thick=0.08, along="x", x=dcx, y=dcy)
    for x, y in ((DX1 - 0.15, DY0 + 0.15), (DX1 - 0.15, DY1 - 0.15), (DX0 + 0.15, DY0 + 0.15)):
        b.box(0.18, 0.18, DZ - 0.2, x, y, 0, "wood_b", bevel=0.025)
        beam(b, (x, y, DZ - 0.75), (x + (0.6 if x < 0 else -0.6), y, DZ - 0.2), 0.1, 0.1, "wood_b")
    beam(b, (TX + 0.4, TY - 0.3, 0.9), (dcx + 0.4, DY0 + 0.2, DZ - 0.22), 0.12, 0.12, "wood_b")
    beam(b, (TX + 0.45, TY, 1.0), (DX1 - 0.3, dcy, DZ - 0.22), 0.12, 0.12, "wood_b")
    # railings: front and left, stair gap at the front right
    rail_run(b, (DX0 + 0.08, DY0 + 0.08), (DX1 - 0.95, DY0 + 0.08), DZ, posts=4)
    rail_run(b, (DX0 + 0.08, DY0 + 0.08), (DX0 + 0.08, DY1 - 0.1), DZ, posts=3)
    rail_run(b, (DX1 - 0.08, DY0 + 0.95), (DX1 - 0.08, DY1 - 0.08), DZ, posts=3)
    snow_lumps(b, dcx, DY0 + 0.3, DZ, 3.2, 0.3, 4, r=(0.07, 0.12))
    # stair down the right side
    stair_flight(b, DX1 + 0.42, DY0 + 0.75, DZ, DY0 - 2.0, w=0.78, steps=10)
    # cabin
    with b.at((CX, CY - CD / 2 + T / 2, DZ)):
        masonry_wall(b, CW, CH, openings=[(-0.45, 0.96, 0, 1.68), (0.65, 0.62, 0.75, 1.47)], base=False, timber=True)
        arched_door(b, -0.45, -T / 2, 0, w=0.78, h=1.55, fw=0.09, depth=T + 0.04, socket=False)
        _through_window_out(b, 0.65)
        wall_lantern(b, 0.15, -T / 2, 1.5)
    with b.at((CX - CW / 2 + T / 2, CY, DZ), rotz=-90):
        masonry_wall(b, CD - 2 * T, CH, openings=[(0, 0.62, 0.75, 1.47)], base=False, timber=True)
        _through_window_out(b, 0)
    with b.at((CX + CW / 2 - T / 2, CY, DZ), rotz=90):
        masonry_wall(b, CD - 2 * T, CH, openings=[(0, 0.62, 0.75, 1.47)], base=False, timber=True)
        _through_window_out(b, 0)
    with b.at((CX, CY + CD / 2 - T / 2, DZ), rotz=180):
        masonry_wall(b, CW, CH, base=False, timber=True)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.14, 0.14, CH, CX + sx * (CW / 2 - 0.02), CY + sy * (CD / 2 - 0.02), DZ, TRIM_T, bevel=0.02)
    with roof.at((CX, CY, 0)):
        tiled_gable(roof, CW, CD, 0.95, z=DZ + CH, overhang=0.3, tile=0.36, tile_thick=0.09, gable=WALL_T, timber=True)
        ridge_snow_on(roof, CW, CD + 0.6, 0.95, DZ + CH)
        slope_snow(roof, CW, CD, 0.95, DZ + CH, -1, ((0.5, -0.5), (0.4, 0.6)))
        slope_snow(roof, CW, CD, 0.95, DZ + CH, 1, ((0.55, 0.0),))
        chimney_stone(roof, -0.55, 0.45, DZ + CH + 0.2, DZ + CH + 1.35, w=0.38)
    b.socket("door", (CX - 0.45, CY - CD / 2 - 0.6, DZ), rotz=180)
    b.socket("approach", (DX1 + 0.42, DY0 - 2.5, 0), rotz=180)
    finish_house(b, roof, "treehouse_exterior", {"interior": "treehouse_interior", "roof_child": "treehouse_exterior_roof",
                                                 "deck_z": DZ, "footprint_m": [7.2, 6.6]})

    W, D = 3.0, 2.5
    b = Builder("treehouse_interior", seed=671)
    rect_floor(b, W, D)
    with b.at((0, 0, FLOOR)):
        rect_room_walls(b, W, D, 2.0, door_x=-0.5, wins_back=(0.45,), wins_left=(0.65,))
    # ceiling beams and a branch through the back corner (it's a treehouse)
    for x in (-1.0, 0.0, 1.0):
        b.box(0.12, D + 0.3, 0.14, x, 0, FLOOR + 2.0, "wood_dark", bevel=0.015)
    b.cyl(0.24, 2.3, -W / 2 + 0.25, D / 2 - 0.25, 0, "bark", segs=8, r2=0.2, jitter=0.015)
    room = Room(b, lambda x, y: abs(x) <= W / 2 + 1e-6 and abs(y) <= D / 2 + 1e-6, W / 2, D / 2, corner=True)
    room.block_circle(-W / 2 + 0.25, D / 2 - 0.25, 0.45)
    room.block_rect(-W / 2, -W / 2 + 0.8, -1.0, 0.0)          # entry by the door on the left wall
    rect_slots(room, W, D, FLOOR + 1.3, door_y=-0.5, wins_back=(0.45,), wins_left=(0.65,))
    for x, y in ((-0.5, -0.4), (0.5, 0.4), (0.9, -0.6)):
        room.anchor((x, y, FLOOR + 1.93))
    b.socket("spawn_inside", (-W / 2 + 0.7, -0.5, FLOOR), rotz=-90)
    b.socket("exit", (-W / 2 + 0.2, -0.5, FLOOR))
    b.finish(KIT, "room", room.meta(shape="rect", room_m=[W, D], exterior="treehouse_exterior"))


def _through_window_out(b, x, w=0.62, zb=0.75, h=0.72):
    """Exterior window in a masonry_wall opening (wall centred on local y=0, outside at -Y)."""
    _through_window(b, x, w=w, zb=zb, h=h)
    b.box(w + 0.3, 0.1, 0.1, x, -T / 2 - 0.04, zb + h, TRIM_T, bevel=0.015)
    for s in (-1, 1):
        b.box(w * 0.42, 0.04, h + 0.06, x + s * (w * 0.5 + 0.2), -T / 2 - 0.03, zb - 0.03, DOOR_T, bevel=0.012)


# =============================================================================== lighthouse loft
def lighthouse_loft():
    TX, TY = -0.85, 0.35
    TH_, R0, R1 = 4.3, 1.25, 0.92
    CW, CD, CH, SLAB = 2.5, 2.2, 1.8, 0.18
    CX, CY = 1.35, -0.25
    b = Builder("lighthouse_loft_exterior", seed=681)
    roof = Builder("lighthouse_loft_exterior_roof", seed=682)
    snow_base(b, 3.7, 3.2, seed=68, rocks=8, back_firs=((-2.6, 1.6, 2.4),))
    # tower: stone foot, then teal/cream bands tapering up
    b.cyl(R0 + 0.12, 0.4, TX, TY, 0, "stone_dark", segs=14, r2=R0 + 0.06, bevel=0.03)
    bands = 6
    for i in range(bands):
        z0 = 0.4 + (TH_ - 0.4) * i / bands
        z1 = 0.4 + (TH_ - 0.4) * (i + 1) / bands
        r0 = R0 + (R1 - R0) * (z0 / TH_)
        r1 = R0 + (R1 - R0) * (z1 / TH_)
        b.cyl(r0, z1 - z0, TX, TY, z0, STRIPE_T if i % 2 == 0 else WALL_T, segs=14, r2=r1, cap=(i == bands - 1))
    for a, z in ((250, 1.5), (300, 2.8), (205, 2.2)):
        r = math.radians(a)
        rr = R0 + (R1 - R0) * (z / TH_)
        with b.at((TX + rr * math.cos(r), TY + rr * math.sin(r), z), rotz=a + 90):
            arched_window(b, 0, 0.0, 0, w=0.36, h=0.52)
    # gallery
    GZ = TH_
    b.cyl(R1 + 0.38, 0.14, TX, TY, GZ, "wood_b", segs=14, bevel=0.02)
    for k in range(12):
        a = 2 * math.pi * k / 12
        snow_post(b, TX + (R1 + 0.3) * math.cos(a), TY + (R1 + 0.3) * math.sin(a), GZ + 0.14, h=0.5, w=0.08)
    b.torus(R1 + 0.3, 0.035, TX, TY, GZ + 0.58, "wood", segs=14, ring=5)
    b.torus(R1 + 0.3, 0.025, TX, TY, GZ + 0.36, "wood", segs=14, ring=4)
    # lantern room (roof child)
    LZ = GZ + 0.14
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
    # side cottage
    b.box(CW + 0.2, CD + 0.2, SLAB, CX, CY, 0, "stone_dark", bevel=0.03)
    with b.at((CX, CY - CD / 2 + T / 2, SLAB)):
        masonry_wall(b, CW, CH, openings=[(0.35, 0.98, 0, 1.68)], quoins=(False, True))
        arched_door(b, 0.35, -T / 2, 0, w=0.78, h=1.55, fw=0.1, depth=T + 0.04, socket=False)
        round_window(b, -0.55, -T / 2, 1.15, r=0.24)
        wall_lantern(b, 1.0, -T / 2, 1.5)
    with b.at((CX + CW / 2 - T / 2, CY, SLAB), rotz=90):
        masonry_wall(b, CD - 2 * T, CH, openings=[(0, 0.62, 0.75, 1.47)], quoins=(True, True))
        _through_window_out(b, 0)
    with b.at((CX, CY + CD / 2 - T / 2, SLAB), rotz=180):
        masonry_wall(b, CW, CH, quoins=(True, False))
    entry_steps(b, CX + 0.35, CY - CD / 2 - 0.1, w=1.0, steps=1, rise=SLAB, tread=0.35)
    with roof.at((CX, CY, 0), rotz=90):
        tiled_gable(roof, CD, CW, 0.85, z=SLAB + CH, overhang=0.28, tile=0.36, tile_thick=0.09, gable=WALL_T, timber=False)
        ridge_snow_on(roof, CD, CW + 0.56, 0.85, SLAB + CH)
        slope_snow(roof, CD, CW, 0.85, SLAB + CH, 1, ((0.5, -0.6), (0.45, 0.7)))   # +X local = world -Y (front)
        slope_snow(roof, CD, CW, 0.85, SLAB + CH, -1, ((0.5, 0.0),))
    # dock railing, barrels and crates by the door
    rail_run(b, (CX + CW / 2 + 0.35, CY - 1.3), (CX + CW / 2 + 0.35, CY + 0.4), 0.0, posts=3)
    barrel(b, CX - 0.6, CY - CD / 2 - 0.45)
    barrel(b, CX - 1.0, CY - CD / 2 - 0.3, s=0.85)
    crate(b, CX + 1.35, CY - CD / 2 - 0.5, rotz=12)
    stepping_stones(b, CX + 0.35, CY - CD / 2 - 0.65, -2.9, n=2, seed=8)
    b.socket("door", (CX + 0.35, CY - CD / 2 - 0.85, 0), rotz=180)
    finish_house(b, roof, "lighthouse_loft_exterior", {"interior": "lighthouse_loft_interior",
                                                        "roof_child": "lighthouse_loft_exterior_roof", "footprint_m": [7.4, 6.4]})

    # interior: round room with a curved stair up the back-right wall (coastal retreat)
    Ri = 2.4
    b = Builder("lighthouse_loft_interior", seed=691)
    round_floor(b, Ri + T / 2)
    ring_wall(b, Ri + T, 2.3, 18, facing="in", doors=(180,), windows=(70, 110, 140), low=low_front, base=False,
              cap="wood_c", door_kw=dict(depth=T + 0.04), mat=(WALL_T, STRIPE_T, WALL_T), band=True)
    ST0, ST1, STR = 20, 75, 0.62                     # stair arc (degrees) and tread length
    steps = 10
    for i in range(steps):
        a = math.radians(ST0 + (ST1 - ST0) * (i + 0.5) / steps)
        zz = FLOOR + 2.1 * (i + 1) / steps
        rr = Ri - STR / 2 - 0.02
        with b.at((rr * math.cos(a), rr * math.sin(a), 0), rotz=math.degrees(a) + 90):
            b.box(0.42, STR, 0.07, 0, 0, zz - 0.07, pick(("wood", "wood_c"), i), bevel=0.012)
            b.box(0.12, 0.12, zz - 0.07, 0, STR / 2 - 0.1, 0, "wood_dark", bevel=0.01)
    room = Room(b, lambda x, y: math.hypot(x, y) <= Ri - 0.03, Ri, Ri)
    room.blockers.append(lambda x, y: math.hypot(x, y) > Ri - STR - 0.2 and
                         ST0 - 8 <= math.degrees(math.atan2(y, x)) % 360 <= ST1 + 8)
    room.block_circle(-(Ri - 0.5), 0, 0.75)
    ring_slots(room, Ri, 1.4, (100, 125, 155, 205, 230))
    for x, y in ((0, 0), (-0.9, 0.8), (0.6, -0.4)):
        room.anchor((x, y, 2.6))
    b.socket("spawn_inside", (-(Ri - 0.9), 0, FLOOR), rotz=-90)
    b.socket("exit", (-(Ri - 0.25), 0, FLOOR))
    b.socket("stair_top", ((Ri - 0.3) * math.cos(math.radians(ST1)), (Ri - 0.3) * math.sin(math.radians(ST1)), FLOOR + 2.1))
    b.finish(KIT, "room", room.meta(shape="round", radius_m=Ri, exterior="lighthouse_loft_exterior"))


# =============================================================================== houseboat
def _hull(b):
    """Lofted boat hull: stern at -X (square transom), bow at +X. Deck edge (sheer) to keel."""
    st = [  # x, half-beam, sheer z, bottom z
        (-2.7, 1.18, 0.24, -0.72), (-2.1, 1.3, 0.2, -0.8), (-1.0, 1.32, 0.18, -0.84), (0.0, 1.32, 0.18, -0.84),
        (1.0, 1.28, 0.2, -0.82), (1.85, 1.08, 0.28, -0.72), (2.45, 0.66, 0.4, -0.52), (2.85, 0.08, 0.55, -0.16)]
    sec = lambda hw, sh, bt: [(-hw, sh), (-hw * 0.97, (sh + bt) / 2 + 0.06), (-hw * 0.72, bt + 0.08), (0, bt),
                              (hw * 0.72, bt + 0.08), (hw * 0.97, (sh + bt) / 2 + 0.06), (hw, sh)]
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
    return st


def houseboat():
    DZ = 0.12                                       # boat deck top; dock deck is at 0 like the plaza
    b = Builder("houseboat_exterior", seed=701)
    roof = Builder("houseboat_exterior_roof", seed=702)
    water_surface(b, 9.0, 7.0, x=0, y=-0.6, n=8, seed=7, z=WATER_Z)
    with b.at((0, 0, WATER_Z + 0.62)):
        st = _hull(b)
        for side in (-1, 1):  # gunwale cap and rub rail following the sheer
            for (x0, hw0, sh0, _), (x1, hw1, sh1, _) in zip(st, st[1:]):
                beam(b, (x0, side * hw0, sh0 + 0.03), (x1, side * hw1, sh1 + 0.03), 0.12, 0.08, TRIM_T, 0.012)
                beam(b, (x0, side * (hw0 + 0.02), sh0 - 0.32), (x1, side * (hw1 + 0.02), sh1 - 0.3), 0.08, 0.1, "wood_dark", 0.01)
    zdeck = WATER_Z + 0.62 + DZ
    for i in range(11):  # deck planks clipped to the hull plan
        y = -1.15 + 0.23 * (i + 0.5)
        x1 = 2.0 - 1.4 * (abs(y) / 1.2) ** 2
        b.box(x1 + 2.6, 0.22, 0.06, (x1 - 2.6) / 2, y, zdeck - 0.06, pick(("wood", "wood_c", "wood_b"), i), bevel=0.01)
    # cabin
    CW, CD, CH, CX = 3.0, 2.0, 1.75, -0.45
    with b.at((CX, -CD / 2 + T / 2, zdeck)):
        masonry_wall(b, CW, CH, openings=[(0.55, 0.98, 0, 1.68)], base=False, timber=True)
        arched_door(b, 0.55, -T / 2, 0, w=0.78, h=1.55, fw=0.09, depth=T + 0.04, socket=False)
        round_window(b, -0.65, -T / 2, 1.1, r=0.24)
        wall_lantern(b, 1.25, -T / 2, 1.55)
    with b.at((CX + CW / 2 - T / 2, 0, zdeck), rotz=90):
        masonry_wall(b, CD - 2 * T, CH, base=False, timber=True)
        round_window(b, 0, -T / 2, 1.1, r=0.22)
    with b.at((CX - CW / 2 + T / 2, 0, zdeck), rotz=-90):
        masonry_wall(b, CD - 2 * T, CH, base=False, timber=True)
        round_window(b, 0, -T / 2, 1.1, r=0.22)
    with b.at((CX, CD / 2 - T / 2, zdeck), rotz=180):
        masonry_wall(b, CW, CH, base=False, timber=True)
        round_window(b, 0, -T / 2, 1.1, r=0.24)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.13, 0.13, CH, CX + sx * (CW / 2 - 0.02), sy * (CD / 2 - 0.02), zdeck, TRIM_T, bevel=0.02)
    with roof.at((CX, 0, 0), rotz=90):
        tiled_gable(roof, CD, CW, 0.75, z=zdeck + CH, overhang=0.32, tile=0.36, tile_thick=0.09, gable=WALL_T, timber=False)
        ridge_snow_on(roof, CD, CW + 0.64, 0.75, zdeck + CH)
        slope_snow(roof, CD, CW, 0.75, zdeck + CH, 1, ((0.45, -0.8), (0.55, 0.5)), overhang=0.32)
        slope_snow(roof, CD, CW, 0.75, zdeck + CH, -1, ((0.5, 0.1),), overhang=0.32)
    roof.cyl(0.07, 1.0, CX + 0.9, 0.45, zdeck + CH + 0.3, "iron", segs=8)            # stove pipe
    roof.cyl(0.12, 0.1, CX + 0.9, 0.45, zdeck + CH + 1.3, "iron", segs=8, r2=0.04)
    # deck rail with rope, stern flag, barrels
    pts = [(-2.45, -1.05), (-1.2, -1.2), (1.0, -1.18), (1.9, -0.95), (2.45, -0.5)]
    for x, y in pts:
        snow_post(b, x, y, zdeck, h=0.62, w=0.1)
        snow_post(b, x, -y, zdeck, h=0.62, w=0.1)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if not (x0 < 0.4 < x1):                       # gap at the gangway
            rope_between(b, (x0, y0, zdeck + 0.5), (x1, y1, zdeck + 0.5), sag=0.08, r=0.022)
        rope_between(b, (x0, -y0, zdeck + 0.5), (x1, -y1, zdeck + 0.5), sag=0.08, r=0.022)
    b.cyl(0.04, 1.6, -2.55, 0.0, zdeck, "wood_b", segs=6)
    b.prism([(0, 0), (0.55, -0.12), (0, -0.32)], 0.02, x=-2.55, y=0, z=zdeck + 1.58, mat=tint("flag", "cream"))
    barrel(b, 1.7, 0.45, zdeck)
    crate(b, 2.15, 0.1, zdeck, s=0.4, rotz=-10)
    # moored dock with gangway
    for i in range(7):
        y = -1.75 - 0.25 * (i + 0.5)
        b.box(2.4, 0.24, 0.08, 0.2, y, -0.08, pick(("wood", "wood_c", "wood_b"), i), bevel=0.012)
    for sx in (-1, 1):
        b.box(0.14, 1.8, 0.16, 0.2 + sx * 0.9, -2.6, -0.24, "wood_dark", bevel=0.015)
    for x, y in ((-1.0, -1.65), (1.4, -1.65), (-1.0, -3.55), (1.4, -3.55)):
        dock_post(b, x, y, top=0.45)
        b.box(0.22, 0.22, 0.06, x, y, 0.45, "snow", bevel=0.02)
    rope_between(b, (-1.0, -1.65, 0.38), (-1.2, -1.2, zdeck + 0.45), sag=0.1, r=0.02)
    rope_between(b, (1.4, -1.65, 0.38), (1.0, -1.18, zdeck + 0.45), sag=0.1, r=0.02)
    beam(b, (CX + 0.55, -1.8, 0.0), (CX + 0.55, -1.15, zdeck), 0.6, 0.06, "wood_c", 0.01)       # gangway
    b.torus(0.22, 0.06, 1.85, -1.62, 0.3, tint("ring", "coral"), segs=12, ring=6, rot=(90, 0, 0))
    snow_lumps(b, 0.2, -2.6, 0.0, 2.2, 1.6, 4, r=(0.08, 0.14))
    b.socket("door", (CX + 0.55, -2.4, 0.0), rotz=180)
    finish_house(b, roof, "houseboat_exterior", {"interior": "houseboat_interior", "roof_child": "houseboat_exterior_roof",
                                                 "water_z": WATER_Z, "deck_z": round(zdeck, 3), "footprint_m": [9.0, 7.0]})

    W, D = 3.5, 2.5
    b = Builder("houseboat_interior", seed=711)
    rect_floor(b, W, D)
    with b.at((0, 0, FLOOR)):
        rect_room_walls(b, W, D, 1.9, door_x=0.4, wins_back=(), wins_left=())
        with b.at((0, D / 2 + T / 2, 0)):
            for x in (-1.0, 0.0, 1.0):
                round_window(b, x, -T / 2, 1.15, r=0.22)
        with b.at((-W / 2 - T / 2, 0, 0), rotz=90):
            round_window(b, 0.7, -T / 2, 1.15, r=0.2)
    for x in (-1.2, -0.4, 0.4, 1.2):  # curved-ish ceiling ribs
        b.box(0.1, D + 0.2, 0.12, x, 0, FLOOR + 1.9, "wood_dark", bevel=0.015)
    room = Room(b, lambda x, y: abs(x) <= W / 2 + 1e-6 and abs(y) <= D / 2 + 1e-6, W / 2, D / 2, corner=True)
    room.block_rect(-W / 2, -W / 2 + 0.8, -0.1, 0.9)
    for x in (-1.5, -0.5, 0.5, 1.5):
        room.wall_slot((x, D / 2, FLOOR + 1.55), (0, -1))
    room.wall_slot((-W / 2, -0.2, FLOOR + 1.3), (1, 0))
    for x, y in ((-0.8, 0.0), (0.8, 0.0)):
        room.anchor((x, y, FLOOR + 1.83))
    b.socket("spawn_inside", (-W / 2 + 0.7, 0.4, FLOOR), rotz=-90)
    b.socket("exit", (-W / 2 + 0.2, 0.4, FLOOR))
    b.finish(KIT, "room", room.meta(shape="rect", room_m=[W, D], exterior="houseboat_exterior"))


def build():
    snow_dome()
    aframe_cabin()
    round_cottage()
    treehouse()
    lighthouse_loft()
    houseboat()
