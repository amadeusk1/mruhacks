"""Sled hill on the island's NW corner: landform, carved track, start/finish dressing, return stair.
Owned separately from town.py (see the interface list below; town also reads PATHS, STAIRS_FOOT,
STAIR_CHAINS, blocks() and layout_data(), and sets `ground` and `to_godot` before placements()).

Concepts: Images/16 Sledding Hill.png, World Map - Island Overview.png, World Map - Overhead Layout.png.
Blender space (+X east, +Y north, Z up, metres, plaza at the origin). Interface used by town.py:
  REGION                      (centre Vector, half-extents Vector)  - town keeps its own dressing out of it
  height(p, base_h)           terrain height at p, or None outside the hill (base_h = town terrain there)
  meshes(b)                   adds the track ribbon (+ groove lines) to a Builder named terrain_sled_track
  placements()                list of town.put(**kwargs) dicts; z=None means "sit on the terrain"
  markers()                   list of town.mark(**kwargs) dicts
  sled_track(to_godot)        the layout's "sled_track" block (centreline, width, bank) in Godot space
"""
import math
import random
from mathutils import Vector

HILL_TOP = 6.0
ground = None          # set by town.py: full terrain height function (Vector -> z)
to_godot = None        # set by town.py: Blender -> Godot coordinate conversion
REGION = (Vector((-22.0, 24.25)), Vector((14.5, 12.25)))   # x -36.5..-7.5 (stops short of the cafe), y 12..36.5
RNG = random.Random(16)

# ------------------------------------------------------------------ track --
# Concept: start on the top plateau, sweep west along the crest, swing down the west face,
# S-curve back east across the foot of the hill into a wide flat stopping area.
CTRL = [(-12.6, 31.0), (-16.8, 31.7), (-22.4, 31.4), (-26.6, 29.4), (-29.0, 26.8), (-28.2, 23.6),
        (-24.8, 22.0), (-21.2, 22.3), (-18.6, 21.0), (-16.2, 19.9)]   # lower half clear of the NW home lots
W = 4.4                    # carved width
LIP = 0.75                 # berm width each side
BERM_H = 0.42
FLAT_START, RUNOUT = 3.0, 6.5
Z_START, Z_FINISH, Z_END = HILL_TOP, 1.1, 0.3


def _catmull(pts, step=0.5):
    P = [Vector(pts[0]) * 2 - Vector(pts[1])] + [Vector(q) for q in pts] + [Vector(pts[-1]) * 2 - Vector(pts[-2])]
    dense = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(24):
            t = k / 24
            dense.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                                (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    dense.append(Vector(pts[-1]))
    out, acc = [dense[0]], 0.0
    for a, b in zip(dense, dense[1:]):
        acc += (b - a).length
        if acc >= step:
            out.append(b)
            acc = 0.0
    if (out[-1] - dense[-1]).length > 0.05:
        out.append(dense[-1])
    return out


TRACK = _catmull(CTRL)
S = [0.0]
for _a, _b in zip(TRACK, TRACK[1:]):
    S.append(S[-1] + (_b - _a).length)
LENGTH = S[-1]
FINISH_S = LENGTH - RUNOUT


def z_at(s):
    """Gentle start, steep middle, flattening into the finish; nearly flat run-out."""
    if s <= FLAT_START:
        return Z_START
    if s <= FINISH_S:
        t = (s - FLAT_START) / (FINISH_S - FLAT_START)
        f = 0.22 * t + 0.78 * (t - math.sin(2 * math.pi * t) / (2 * math.pi))   # slope ~0 at ends, peak mid
        return Z_START + (Z_FINISH - Z_START) * f
    t = (s - FINISH_S) / RUNOUT
    return Z_FINISH + (Z_END - Z_FINISH) * (1 - (1 - t) ** 2)


def _frame(i):
    a, b = TRACK[max(i - 1, 0)], TRACK[min(i + 1, len(TRACK) - 1)]
    t = (b - a).normalized()
    return t, Vector((-t.y, t.x))


def _bank(i):
    a, b, m = TRACK[max(i - 4, 0)], TRACK[min(i + 4, len(TRACK) - 1)], TRACK[i]
    h1, h2 = math.atan2((m - a).y, (m - a).x), math.atan2((b - m).y, (b - m).x)
    k = ((h2 - h1 + math.pi) % (2 * math.pi) - math.pi) / max((b - a).length, 1e-3)
    return max(-0.26, min(0.26, -k * 2.4))            # turning left -> right (outer) edge up


BANK = [_bank(i) for i in range(len(TRACK))]
for _ in range(3):                                    # smooth the banking so it rolls in and out
    BANK = [sum(BANK[max(0, i - 2):i + 3]) / len(BANK[max(0, i - 2):i + 3]) for i in range(len(BANK))]
WIDTH = [W + 1.4 * math.sin(math.pi * min(1.0, max(0.0, (s - FINISH_S) / RUNOUT)) * 0.5) *
         (1.0 if s < LENGTH - 1.5 else 0.55 + 0.45 * (LENGTH - s) / 1.5) for s in S]   # bulb-shaped stop area, rounded end


def surf_z(i, lat):
    half = WIDTH[i] * 0.5
    return z_at(S[i]) + max(-half, min(half, lat)) * math.tan(BANK[i])


def nearest(p):
    best, bi = 1e18, 0
    for i in range(0, len(TRACK), 2):
        d = (p - TRACK[i]).length_squared
        if d < best:
            best, bi = d, i
    for i in range(max(0, bi - 2), min(len(TRACK), bi + 3)):
        d = (p - TRACK[i]).length_squared
        if d < best:
            best, bi = d, i
    t, n = _frame(bi)
    return math.sqrt(best), bi, (p - TRACK[bi]).dot(n)


# --------------------------------------------------------------- landform --
HOME_LOTS = [(Vector((-22.5, 13.6)), Vector((6.5, 6.1))), (Vector((-33.0, 13.0)), Vector((6.7, 6.4)))]   # town pads + 2.5 m


def _in_lot(p, r=0.0):
    return any(_box_d(p, c, h) <= r for c, h in HOME_LOTS)


PLATEAU = (Vector((-11.6, 31.6)), Vector((4.2, 2.6)))          # start area on the hill top
STAIR_X = -10.1
STAIR_FOOT_Y = 15.8                                            # town path "homes -> sled stairs" ends at y=15.6
STAIR_FLIGHTS = [(Vector((STAIR_X, STAIR_FOOT_Y)), 6, 0.0), (Vector((STAIR_X, STAIR_FOOT_Y + 8.0)), 6, 3.0)]  # foot, modules, z0 (climb +Y)
STAIR_TOP = Vector((STAIR_X, STAIR_FOOT_Y + 14.0))            # 2 m landing between the flights
_LOOP = TRACK + [TRACK[0]]
_SAMPLES = [(TRACK[i], z_at(S[i])) for i in range(0, len(TRACK), 3)] + \
           [(Vector((x, y)), HILL_TOP) for x in (-15.0, -12.0, -9.0) for y in (30.0, 32.5, 34.5)]


def _inside_loop(p):
    c = False
    for a, b in zip(_LOOP, _LOOP[1:]):
        if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
            c = not c
    return c


def _idw(p):
    num = den = 0.0
    for q, z in _SAMPLES:
        d2 = (p - q).length_squared + 0.25
        w = 1.0 / (d2 * d2)
        num += w * z
        den += w
    return num / den


def _smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _box_d(p, c, half):
    return Vector((max(abs(p.x - c.x) - half.x, 0), max(abs(p.y - c.y) - half.y, 0))).length


def _stair_z(p):
    """(z, lateral) of the stair corridor at p, or None. Covers both flights, the landing and the top."""
    y0 = STAIR_FOOT_Y
    if not (abs(p.x - STAIR_X) < 2.6 and y0 - 0.4 < p.y < y0 + 14.6):
        return None
    y = p.y - y0
    z = 0.0 if y < 0 else y * 0.5 if y < 6 else 3.0 if y < 8 else 3.0 + (y - 8) * 0.5 if y < 14 else HILL_TOP
    return z, abs(p.x - STAIR_X)


def height(p, base_h=0.0):
    c, half = REGION
    if abs(p.x - c.x) > half.x or abs(p.y - c.y) > half.y:
        return None
    td, ti, lat = nearest(p)
    halfw = WIDTH[ti] * 0.5
    hill = _idw(p)
    # where the hill exists: inside the track loop, near the track, the plateau, and up to the stair
    m = max(1.0 if _inside_loop(p) else 0.0,
            1 - _smooth(halfw + LIP + 1.5, halfw + LIP + 8.0, td),
            1 - _smooth(0.0, 4.0, _box_d(p, *PLATEAU)))
    lot = min(_box_d(p, c, hh) for c, hh in HOME_LOTS)  # home lots keep the town's flat ground
    m *= _smooth(0.0, 2.0, lot)
    if p.x > STAIR_X:                                  # east of the stair the ground drops back to town
        m = min(m, 1 - _smooth(0.8, 2.4, p.x - STAIR_X))
    m *= _smooth(0.0, 2.5, min(half.x - abs(p.x - c.x), half.y - abs(p.y - c.y)))   # meet town terrain at the edge
    if _inside_loop(p):                                # interior: smooth surface spanning the upper and lower legs
        num = den = 0.0
        for k in range(0, len(TRACK), 2):
            d2 = (p - TRACK[k]).length_squared + 0.5
            w = 1.0 / (d2 * d2)
            num += w * z_at(S[k])
            den += w
        hill = num / den + BERM_H + 0.5 * _smooth(halfw + LIP, halfw + LIP + 3.0, td)   # gentle crown
    h = base_h + (hill - base_h) * m
    # plateau: flat start area
    pw = 1 - _smooth(0.0, 1.2, _box_d(p, *PLATEAU))
    h = h * (1 - pw) + HILL_TOP * pw
    # the track: terrain sits just under the ribbon, raised berms at the edges
    if td < halfw + LIP + 2.0:
        tz = surf_z(ti, lat) - 0.08
        berm = BERM_H * _smooth(halfw - 0.1, halfw + 0.35, abs(lat)) * (1 - _smooth(halfw + LIP - 0.2, halfw + LIP + 1.0, abs(lat)))
        w = 1 - _smooth(halfw + LIP - 0.2, halfw + LIP + 2.0, td)
        h = h * (1 - w) + (tz + berm) * w
    # stair corridor: terrain follows the treads exactly, then blends out
    st = _stair_z(p)
    if st is not None:
        sz, sl = st
        w = 1 - _smooth(1.0, 2.6, sl)
        h = h * (1 - w) + (sz - 0.03) * w
    return h


# --------------------------------------------------------------------- mesh --
def meshes(Builder):
    """Track ribbon as its own Builder (town names it terrain_sled_track)."""
    from common import tint
    b = Builder("terrain_sled_track", seed=14)
    b.skip_zfix = True
    track_mesh(b, tint)
    return [b]


def track_mesh(b, tint=None):
    """Track surface as a smooth ribbon with banked cross-section, berm lips and faint groove lines."""
    mat = tint("track", "#D6E2EC") if tint else "snow_shade"
    berm = tint("snow", "#E8EFF4") if tint else "snow"
    groove = tint("track_groove", "#BCCDDB") if tint else "snow_shade"
    verts, faces_track, faces_berm = [], [], []
    prev = None
    for i, c in enumerate(TRACK):
        t, n = _frame(i)
        half = WIDTH[i] * 0.5
        lats = [-(half + LIP), -(half + LIP * 0.45), -half, -half * 0.5, 0.0, half * 0.5, half, half + LIP * 0.45, half + LIP]
        ups = [0.05, BERM_H, 0.0, 0.0, 0.0, 0.0, 0.0, BERM_H, 0.05]
        row = []
        for lat, up in zip(lats, ups):
            q = c + n * lat
            row.append(len(verts))
            verts.append((q.x, q.y, surf_z(i, lat) + up + 0.02))
        if prev is not None:
            for k in range(len(row) - 1):
                f = [prev[k], prev[k + 1], row[k + 1], row[k]]
                (faces_berm if k in (0, 1, 6, 7) else faces_track).append(f)
        prev = row
    b.mesh(verts, faces_track, mat=mat)
    b.mesh(verts, faces_berm, mat=berm)
    fi = min(range(len(S)), key=lambda k: abs(S[k] - FINISH_S))     # checkered finish line across the track
    t, n = _frame(fi)
    half = WIDTH[fi] * 0.5
    cells = 10
    for k in range(cells):
        for row in range(2):
            lat = -half + (k + 0.5) * (2 * half / cells)
            c = TRACK[fi] + n * lat + t * (row - 0.5) * 0.22
            b.box(2 * half / cells, 0.22, 0.01, c.x, c.y, surf_z(fi, lat) + 0.03,
                  "black" if (k + row) % 2 else "white", bevel=0, rot=(0, 0, math.degrees(math.atan2(t.y, t.x)) + 90))
    # groove lines: thin strips 4 mm above the surface where sled runners pack the snow
    for off in (-1.15, -0.85, 0.85, 1.15):
        gv, gf, pr = [], [], None
        for i in range(int(FLAT_START * 2), len(TRACK)):
            c = TRACK[i]
            t, n = _frame(i)
            row = []
            for d in (-0.035, 0.035):
                q = c + n * (off + d)
                row.append(len(gv))
                gv.append((q.x, q.y, surf_z(i, off + d) + 0.026))
            if pr is not None:
                gf.append([pr[0], pr[1], row[1], row[0]])
            pr = row
        b.mesh(gv, gf, mat=groove)


# --------------------------------------------------------- town interface --
STAIRS_FOOT = Vector((STAIR_X, STAIR_FOOT_Y - 0.2))           # town path to the hill ends here
STAIR_CHAINS = []
for _foot, _n, _z0 in STAIR_FLIGHTS:
    _mods = [(_foot + Vector((0, k + 0.5)), _z0 + 0.5 * k) for k in range(_n)]
    STAIR_CHAINS.append({"mods": _mods, "dir": Vector((0, 1)), "foot": (_foot, _z0), "top": (_foot + Vector((0, _n)), _z0 + 0.5 * _n)})
PATHS = [([Vector((STAIR_X, STAIR_TOP.y + 0.3)), Vector((STAIR_X, 31.1)), Vector((-12.6, 31.1))], 1.8)]   # stair top -> queue -> gate


def blocks(p, margin=0.0):
    """True where nothing else may be placed: the track and its berms, the stair corridor, the start plateau."""
    c, half = REGION
    if abs(p.x - c.x) > half.x or abs(p.y - c.y) > half.y:
        return False
    td, ti, _ = nearest(p)
    t, _n = _frame(ti)
    along = (p - TRACK[ti]).dot(t)
    beyond = (ti == 0 and along < -0.2) or (ti == len(TRACK) - 1 and along > 0.2)
    if not beyond and td < WIDTH[ti] * 0.5 + LIP * 0.5 + margin:   # outer berm carries the fence/bunting line
        return True
    if abs(p.x - STAIR_X) < 1.2 + margin and STAIR_FOOT_Y - 0.5 < p.y < STAIR_TOP.y + 0.5:
        return True
    return _box_d(p, Vector((-12.0, 31.1)), Vector((2.6, 0.9))) <= margin   # paved queue lane on the plateau


# --------------------------------------------------------------- placements --
def _at(s, lat=0.0):
    i = min(range(len(S)), key=lambda k: abs(S[k] - s))
    t, n = _frame(i)
    return TRACK[i] + n * lat, math.degrees(math.atan2(t.y, t.x)), i


def placements():
    out = []

    def put(asset, x, y, yaw=0.0, z=None, name=None, tags=("prop",), scale=1.0, tints=None):
        out.append(dict(id=asset, x=x, y=y, yaw=yaw, z=z, name=name, tags=tags, scale=scale, tints=tints, zone="sled"))

    def ground_at(x, y):
        p = Vector((x, y))
        return ground(p) if ground else height(p, 0.0)

    T = HILL_TOP
    # --- start area on the plateau ---------------------------------------------------------
    g, gh, gi = _at(3.0)
    put("winter/start_gate", g.x, g.y, gh + 90, z=surf_z(gi, 0), name="SledGate",
        tints={"sign_frame": "#D9822B", "pennant_a": "#E86D58", "pennant_b": "#3FB3B5", "pennant_c": "#E3A92B"})
    tg, ng = _frame(gi)
    for sgn in (1, -1):                                       # firs frame the gate, red flag on the left post
        for d in (2.9, 3.9):
            q = g + ng * sgn * (W * 0.5 + d) - tg * 0.6
            put(["winter/fir_tree_medium", "winter/fir_tree_large"][d > 3], q.x, q.y, RNG.uniform(0, 360), z=T, tags=("tree",))
    q = g + ng * (W * 0.5 + 1.9)
    put("winter/team_flag", q.x, q.y, gh, z=T, tags=("prop", "blocker"), tints={"team": "#D9473B"})
    q, _, _ = _at(3.0, W * 0.5 + LIP + 0.7)
    put("interaction_props/start_light", q.x, q.y, gh + 90, z=T, tags=("prop", "blocker"))
    # queue lane from the stair top to the gate: 4 spots between fences, lanterns and the sign at the stair top
    for k in range(4):
        put("world_misc/queue_spot_marker", STAIR_X - 0.6 - 0.95 * k, 31.1, 90, z=T + 0.004, tags=("decor",))
    put("plaza/low_wood_fence_2m", -10.8, 32.3, 0, z=T, tags=("prop", "blocker"))   # north rail; south side stays open to the stair
    for q in (Vector((-8.4, 32.2)), Vector((-8.4, 29.6)), Vector((-15.2, 33.0))):
        put("plaza/lantern_post", q.x, q.y, 0, z=T, tags=("light", "blocker"))
    put("world_misc/activity_sign", -8.4, 30.9, -90, z=T, tags=("prop", "blocker"), name="SledSign")
    put("world_misc/icon_sled", -8.4 + 0.031 - 0.003, 30.9 + 0.15, -90, z=T + 1.24, tags=("decor",))
    put("plaza/bunting_posts", -10.6, 33.4, 0, z=T, tags=("decor",))
    for k in range(3):                                        # sled rack on the plateau's north edge
        put("winter/sled", -10.4 - 0.62 * k, 33.9, 180 + RNG.uniform(-4, 4), z=T, tags=("decor",))
    put("plaza/bench", -13.6, 29.0, 160, z=T, tags=("prop", "blocker"))   # warm-up bench looking down the hill
    put("plaza/rect_planter", -8.6, 34.6, 90, z=T, tags=("decor",))
    for q in ((-8.0, 28.4), (-12.4, 34.4), (-12.0, 35.4)):
        put("plaza/flower_pot", q[0], q[1], RNG.uniform(0, 360), z=T, tags=("decor",))
    put("nature_dock/shrub_flowering", -11.9, 28.4, 20, z=T, tags=("decor",))
    sx, sy = -9.0, 33.4                                      # snowman (composed: no snowman model in the pack)
    for r, zc in ((4.6, 0.33), (3.3, 0.90), (2.3, 1.36)):
        put("winter/snowball", sx, sy, RNG.uniform(0, 360), z=T + zc - 0.09 * r, tags=("decor",), scale=r)
    put("avatar/red_beanie", sx, sy, 30, z=T + 1.48, tags=("decor",), scale=0.62)
    put("avatar/scarf", sx, sy, 30, z=T + 1.1, tags=("decor",), scale=0.78)
    # --- course: fences follow both edges, lanterns on the outside, snowbanks on outer bends -------
    rc, rh = REGION

    def in_region(q, pad=1.0):
        return abs(q.x - rc.x) < rh.x - pad and abs(q.y - rc.y) < rh.y - pad
    for sgn in (1, -1):                       # edge line on the berm: fence, bunting, fence, bunting ... both sides
        acc, last, k = 0.0, None, 0
        for i in range(int(FLAT_START * 2) + 4, len(TRACK) - 1):
            if FINISH_S - 1.6 < S[i] < FINISH_S + 1.6:
                last = None
                continue
            t, n = _frame(i)
            q = TRACK[i] + n * sgn * (WIDTH[i] * 0.5 + LIP * 0.75)
            if last is None:
                last, acc = q, 0.0
                continue
            acc += (q - last).length
            if acc >= 1.95:
                mid, d = (q + last) * 0.5, q - last
                yaw = math.degrees(math.atan2(d.y, d.x))
                z = surf_z(i, sgn * WIDTH[i] * 0.5) + BERM_H * 0.8
                if blocks(mid) or blocks(q) or blocks(last):       # tight inner bend: chord would cut the track
                    last, acc = q, 0.0
                    continue
                if k % 2 == 0:
                    put("winter/snow_fence_2m", mid.x, mid.y, yaw, z=z, tags=("prop", "blocker"))
                else:
                    put("plaza/bunting_posts", mid.x, mid.y, yaw, z=z, tags=("prop", "blocker"),
                        tints={"flag_a": "#E86D58", "flag_b": "#3FB3B5", "flag_c": "#FAF1DD", "flag_d": "#E3A92B"})
                k += 1
                last, acc = q, 0.0
    last_s = -9.0                             # red pennants on the outer side of every bend
    for i in range(int(FLAT_START * 2), len(TRACK)):
        if abs(BANK[i]) > 0.11 and S[i] - last_s > 5.0:
            t, n = _frame(i)
            outer = 1 if BANK[i] > 0 else -1
            q = TRACK[i] + n * outer * (WIDTH[i] * 0.5 + LIP + 0.6)
            if in_region(q):
                put("winter/team_flag", q.x, q.y, math.degrees(math.atan2(t.y, t.x)), tags=("prop", "blocker"),
                    tints={"team": "#D9473B"})
                last_s = S[i]
    for i in range(int(FLAT_START * 2), len(TRACK), 9):     # snowbanks on the outer side of banked bends
        if abs(BANK[i]) > 0.1:
            t, n = _frame(i)
            outer = 1 if BANK[i] > 0 else -1
            q = TRACK[i] + n * outer * (WIDTH[i] * 0.5 + LIP + 1.6)
            if in_region(q):
                put("winter/snowbank_medium", q.x, q.y, math.degrees(math.atan2(t.y, t.x)) + RNG.uniform(-10, 10), tags=("decor",))
    s9, side = 6.0, 1                          # lanterns along the run every ~9 m, alternating sides
    while s9 < FINISH_S:
        c, hd, i = _at(s9)
        t, n = _frame(i)
        q = c + n * side * (WIDTH[i] * 0.5 + LIP + 0.9)
        if not in_region(q):
            q = c - n * side * (WIDTH[i] * 0.5 + LIP + 0.9)
        if in_region(q):
            put("plaza/lantern_post", q.x, q.y, 0, tags=("light", "blocker"))
        side, s9 = -side, s9 + 9.0
    for frac in (0.4, 0.72):                                   # checkpoint pairs run ALONG the edge, never across
        c, hd, i = _at(FLAT_START + frac * (FINISH_S - FLAT_START))
        t, n = _frame(i)
        q = c - n * (WIDTH[i] * 0.5 + LIP + 1.6)
        put("interaction_props/checkpoint_posts", q.x, q.y, hd, z=None, tags=("prop", "blocker"))
    # --- finish: flags across the line, timer beside it, stopping area with soft catch banks --------
    c, fh, fi = _at(FINISH_S)
    put("winter/finish_flags", c.x, c.y, fh + 90, z=surf_z(fi, 0), name="SledFinishFlags")
    t, n = _frame(fi)
    q = c + n * (WIDTH[fi] * 0.5 + LIP + 1.8) * (1 if _inside_loop(c - n * 4.0) else -1)
    put("interaction_props/finish_timer", q.x, q.y, fh + 90 + 180, tags=("prop", "blocker"))
    e, eh, ei = _at(LENGTH)
    t, n = _frame(len(TRACK) - 1)
    for k, lat in enumerate((-2.2, -0.6, 1.0, 2.6)):
        q = e + t * 2.6 + n * lat * 0.75
        put(["winter/snowbank_large", "winter/snowbank_medium"][k % 2], q.x, q.y, eh + 90 + RNG.uniform(-12, 12),
            tags=("prop", "blocker"))
    # spectators: bench + lantern pair south of the run-out (outside the loop), parked sled pile beside them
    sp = Vector((-13.2, 14.9))
    put("plaza/bench", sp.x, sp.y, 0, tags=("prop", "blocker"))          # faces north, up the run-out
    for dx in (-1.3, 1.3):
        put("plaza/lantern_post", sp.x + dx, sp.y - 0.4, 0, tags=("light", "blocker"))
    for k in range(2):
        put("winter/sled", -14.9 + 0.55 * k, 14.3, 80 + 10 * k, tags=("decor",))
    # --- return stair: two chained flights + landing, flanked by rocks, planters and lanterns --------
    for foot, nmod, z0 in STAIR_FLIGHTS:
        for k in range(nmod):
            put("winter/stone_stairs_snow", foot.x, foot.y + k + 0.5, 0, z=z0 + 0.5 * k, tags=("prop", "walkable"))
    y0 = STAIR_FOOT_Y
    for q, z in ((Vector((STAIR_X + 1.5, y0 + 0.5)), 0.0), (Vector((STAIR_X - 1.5, y0 + 0.5)), 0.0),
                 (Vector((STAIR_X + 1.5, y0 + 7.0)), 3.0), (Vector((STAIR_X + 1.5, y0 + 14.4)), T)):
        put("plaza/lantern_post", q.x, q.y, 0, z=z, tags=("light", "blocker"))
    for y, z in ((y0 + 3.0, 1.5), (y0 + 11.0, 4.5)):
        put("plaza/rect_planter", STAIR_X + 1.6, y, 90, z=z - 0.05, tags=("decor",))
    for y in (y0 + 2.6, y0 + 5.2, y0 + 10.4, y0 + 12.8):                          # boulders hold up the stair's east side
        put("winter/rock_cluster_snow_large", STAIR_X + 2.6, y, RNG.uniform(0, 360), z=None,
            tags=("rock", "blocker"), scale=RNG.uniform(0.9, 1.15))
    # --- framing: fir clusters + snowy rocks inside the loop and around the hill, never on the track ---
    def free(p, r):
        rc, rh = REGION
        if abs(p.x - rc.x) > rh.x - 0.4 or abs(p.y - rc.y) > rh.y - 0.4:
            return False
        td, ti, _ = nearest(p)
        if td < WIDTH[ti] * 0.5 + LIP + 0.4 + r:            # just outside the edge fence
            return False
        if abs(p.x - STAIR_X) < 2.4 + r and STAIR_FOOT_Y - 0.8 < p.y < STAIR_TOP.y + 0.8:
            return False
        if _box_d(p, *PLATEAU) < 0.5 + r:
            return False
        return all((p - Vector((o["x"], o["y"]))).length > r + 0.6 for o in out
                   if o["tags"][0] in ("tree", "rock", "light") or "bench" in o["id"] or "sled" in o["id"])
    rc, rh = REGION
    for k in range(110):                                            # grey snowy boulder ring along the hill's outer edge
        a = k / 110.0
        if a < 0.30:
            p = Vector((rc.x - rh.x + 0.7, rc.y - rh.y + 6.0 + a / 0.30 * (2 * rh.y - 7.5)))          # west face
        elif a < 0.75:
            p = Vector((rc.x - rh.x + 0.7 + (a - 0.30) / 0.45 * (2 * rh.x - 5.0), rc.y + rh.y - 0.7))  # north face
        else:
            continue
        p += Vector((RNG.uniform(-0.6, 0.6), RNG.uniform(-0.6, 0.6)))
        sc = RNG.uniform(1.3, 2.0)
        if free(p, 0.8 * sc):
            put(["winter/rock_cluster_snow_large", "nature_dock/rock_cluster_snow", "winter/rock_cluster_snow_small"][k % 3],
                p.x, p.y, RNG.uniform(0, 360), tags=("rock", "blocker"), scale=sc)
    groves = [(Vector((-21.6, 26.4)), 9), (Vector((-17.2, 24.4)), 7), (Vector((-24.4, 24.0)), 5),
              (Vector((-14.2, 23.0)), 5), (Vector((-33.0, 30.0)), 6), (Vector((-33.8, 22.0)), 6),
              (Vector((-33.0, 15.0)), 4), (Vector((-27.4, 34.4)), 4), (Vector((-19.4, 34.6)), 3),
              (Vector((-23.0, 15.0)), 4), (Vector((-15.5, 28.6)), 3), (Vector((-34.4, 27.0)), 6),
              (Vector((-31.0, 33.8)), 5), (Vector((-24.0, 35.0)), 4)]
    firs = ["winter/fir_tree_small", "winter/fir_tree_medium", "winter/fir_tree_large"]
    for c, n in groves:
        placed = tries = 0
        while placed < n and tries < 160:
            tries += 1
            p = c + Vector((RNG.gauss(0, 2.0), RNG.gauss(0, 2.0)))
            if free(p, 0.7):
                put(firs[RNG.randrange(3)], p.x, p.y, RNG.uniform(0, 360), tags=("tree",), scale=RNG.uniform(0.9, 1.25))
                placed += 1
        p = c + Vector((RNG.uniform(-2.5, 2.5), RNG.uniform(-2.5, 2.5)))
        if free(p, 1.0):
            put(["winter/rock_cluster_snow_large", "nature_dock/rock_cluster_snow"][RNG.randrange(2)], p.x, p.y,
                RNG.uniform(0, 360), tags=("rock", "blocker"), scale=RNG.uniform(1.0, 1.5))
    for i in range(int(FLAT_START * 2), len(TRACK), 2):          # fir border hugging the outside of the fences
        t, n = _frame(i)
        for sgn in (1, -1):
            for d in (1.2, 2.2, 3.3):
                if RNG.random() < 0.3:
                    continue
                p = TRACK[i] + n * sgn * (WIDTH[i] * 0.5 + LIP + d) + t * RNG.uniform(-0.6, 0.6)
                if free(p, 0.5):
                    put(firs[RNG.randrange(3)], p.x, p.y, RNG.uniform(0, 360), tags=("tree",), scale=RNG.uniform(0.85, 1.15))
    for _ in range(400):                                          # wooded loop interior
        p = Vector((RNG.uniform(-27.0, -13.0), RNG.uniform(19.0, 30.0)))
        if _inside_loop(p) and free(p, 0.7):
            if RNG.random() < 0.82:
                put(firs[RNG.randrange(3)], p.x, p.y, RNG.uniform(0, 360), tags=("tree",), scale=RNG.uniform(0.85, 1.2))
            else:
                put("nature_dock/rock_cluster_snow", p.x, p.y, RNG.uniform(0, 360), tags=("rock", "blocker"),
                    scale=RNG.uniform(0.8, 1.2))
    for _ in range(10):                                           # outcrops on the steep outer faces
        s = RNG.uniform(FLAT_START, FINISH_S)
        c, hd, i = _at(s)
        t, n = _frame(i)
        outer = 1 if BANK[i] >= 0 else -1
        p = c + n * outer * (WIDTH[i] * 0.5 + LIP + RNG.uniform(3.0, 5.5))
        if free(p, 1.0):
            put("winter/rock_cluster_snow_large", p.x, p.y, RNG.uniform(0, 360), tags=("rock", "blocker"),
                scale=RNG.uniform(1.3, 2.0))
    out[:] = [o for o in out if not _in_lot(Vector((o["x"], o["y"])), 0.3)]
    for o in out:
        if o["z"] is None:
            o["z"] = ground_at(o["x"], o["y"])
        assert o["z"] is not None, o                     # everything stays inside REGION
    return out


def markers():
    f, fh, fi = _at(FINISH_S + 2.0)
    r, rh, ri = _at(5.5)                                  # just past the gate
    m = [dict(name="SledStart", x=-13.2, y=31.1, yaw=90, kind="activity", z=HILL_TOP + 0.05, activity="sled"),
         dict(name="SledFinish", x=f.x, y=f.y, yaw=fh + 90, kind="activity", z=surf_z(fi, 0) + 0.05, activity="sled_finish"),
         dict(name="SledReset", x=r.x, y=r.y, yaw=rh + 90, kind="spawn", z=surf_z(ri, 0) + 0.05)]
    for k in range(4):
        m.append(dict(name=f"SledQueue_{k}", x=STAIR_X - 0.2 - 1.05 * k, y=31.0 + 0.1 * k, yaw=90, kind="queue",
                      z=HILL_TOP + 0.01, activity="sled"))
    return m


def layout_data():
    return {"points": [to_godot((q.x, q.y, z_at(s))) for q, s in zip(TRACK, S)],
            "width": [round(w, 2) for w in WIDTH],
            "bank_deg": [round(math.degrees(b), 1) for b in BANK],
            "finish_index": min(range(len(S)), key=lambda k: abs(S[k] - FINISH_S)),
            "length_m": round(LENGTH, 2)}


def grades():
    """(min, max) downhill grade in degrees between the flat start and the finish, sampled every 1 m."""
    g = []
    s = FLAT_START + 0.5
    while s < FINISH_S - 0.5:
        g.append(math.degrees(math.atan((z_at(s) - z_at(s + 1.0)) / 1.0)))
        s += 1.0
    return min(g), max(g)


if __name__ == "__main__":
    lo, hi = grades()
    print(f"length {LENGTH:.1f} m, finish at {FINISH_S:.1f} m, grade {lo:.1f}..{hi:.1f} deg")
    assert 2.0 <= lo and hi <= 20.0, (lo, hi)
    # return stair ends land flush: foot on town ground (0), top on the plateau
    foot, top = Vector((STAIR_X, STAIR_FOOT_Y - 0.3)), Vector((STAIR_X, STAIR_TOP.y + 0.4))
    fz, tz = height(foot, 0.0), height(top, 0.0)
    print(f"stair foot z {fz:.3f} (want 0), top z {tz:.3f} (want {HILL_TOP})")
    assert abs(fz) < 0.06 and abs(tz - HILL_TOP) < 0.06, (fz, tz)
    assert blocks(TRACK[len(TRACK) // 2]) and not blocks(Vector((-36.0, 13.0)))
