"""Town connections: paths, steps, landings, cliffs, streams, bridge approach, rails, snow overlays.
Concept: Images/Town Connections Prop Kit.png. Vault note: Prop Kit - Town Connections.

Shared seam grid (every module follows it; recorded in each asset's meta as "seam_grid"):
  * Footprint: 2 x 2 m modules (steps 2 x 1 m, rails 2 m), on a 1 m sub-grid, origin at the
    footprint centre, ground at z=0. Front faces -Y; a path straight runs along Y.
  * Walking top of every path piece is PATH_TOP = 0.07 m, flush with plaza paving, so collision is
    flat across seams. Path is 1.6 m wide, curbs fill the outer 0.2 m band and the corners.
  * Height steps of 0.5 m: a stone step module rises 0.5 m in two 0.25 m steps; a landing's top is
    PATH_TOP + 0.5. Cliffs are 1 m or 2 m tall (0.5 m increments) with their walkable top at z=H.
  * Ramps stay under 20 deg. Streams cut 0.7 m into the ground; water sits at WATER_Z = -0.5,
    the same level as the harbour water in nature_dock.
  * socket_seam_<n|e|s|w> marks each open edge at walking height for snapping.
Snow is never baked into a base module; the snow_overlay_* assets sit on the same origin.
"""
from common import *
from kits.plaza import WATER_Z

KIT = "town_connections"
PREVIEW_WIDTH = 16.0
PATH_TOP = 0.07
HALF = 1.0          # half module
PW = 0.8            # half path width
RISE = 0.5
SEAM = {"module_m": 2.0, "subgrid_m": 1.0, "path_top_z": PATH_TOP, "path_width_m": 1.6,
        "height_step_m": RISE, "stair_step_m": 0.25, "max_ramp_deg": 20, "water_z": WATER_Z}

STONE_T = (tint("path_stone", "paving"), tint("path_stone_b", "paving_b"))
CURB_T = (tint("curb_stone", "stone"), tint("curb_stone_b", "stone_dark"))
ROCK_T = (tint("cliff_rock", "rock"), tint("cliff_rock_b", "rock_b"))
RAIL_T = tint("rail_wood", "wood")
GROUND_T = tint("ground", "snow")
ARMS = {"n": (0, 1), "s": (0, -1), "e": (1, 0), "w": (-1, 0)}


def done(b, cat, meta=None):
    return b.finish(KIT, cat, {"seam_grid": SEAM, **(meta or {})})


# ---------------------------------------------------------------- paths
def path_rects(open_sides):
    """Walkable area as axis-aligned rects: the centre square plus an arm to each open edge."""
    rects = [(-PW, PW, -PW, PW)]
    for s in open_sides:
        dx, dy = ARMS[s]
        if dx:
            rects.append((PW, HALF, -PW, PW) if dx > 0 else (-HALF, -PW, -PW, PW))
        else:
            rects.append((-PW, PW, PW, HALF) if dy > 0 else (-PW, PW, -HALF, -PW))
    return rects


def intervals(rects, y0, y1):
    """Merged x-intervals of rects that fully cover the band y0..y1."""
    iv = sorted((r[0], r[1]) for r in rects if r[2] <= y0 + 1e-6 and r[3] >= y1 - 1e-6)
    out = []
    for a, c in iv:
        if out and a <= out[-1][1] + 1e-6:
            out[-1][1] = max(out[-1][1], c)
        else:
            out.append([a, c])
    return out


def cobbles(b, rects, z=0.0):
    """Grout bed plus running-bond cobbles over the rects; top exactly z + PATH_TOP.
    Row boundaries are fixed in module space so neighbouring modules line up."""
    rng = b.rng
    ys = sorted({-HALF, -PW, -0.4, 0.0, 0.4, PW, HALF})
    for r in rects:
        b.box(r[1] - r[0], r[3] - r[2], 0.02, (r[0] + r[1]) / 2, (r[2] + r[3]) / 2, z, "stone_dark", bevel=0)
    for k, (y0, y1) in enumerate(zip(ys, ys[1:])):
        for a, c in intervals(rects, y0, y1):
            x = a + (0.15 if k % 2 else 0.0) * (c - a > 0.8)
            if x > a:  # half cobble to start the stagger
                b.box(x - a - 0.03, y1 - y0 - 0.03, 0.05, (a + x) / 2, (y0 + y1) / 2, z + 0.02, pick(STONE_T, k), bevel=0.02)
            i = 0
            while x < c - 1e-3:
                w = min(rng.choice((0.32, 0.4, 0.46, 0.52)), c - x)
                if c - x - w < 0.18:
                    w = c - x
                b.box(w - 0.03, y1 - y0 - 0.03, 0.05, x + w / 2, (y0 + y1) / 2, z + 0.02,
                      pick(STONE_T, k * 3 + i), bevel=0.022, jitter=0.003)
                x += w
                i += 1


def curbs(b, open_sides, z=0.0, h=0.14):
    """Raised edge stones on closed sides and all four corner squares."""
    rng = b.rng
    band = HALF - PW
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        b.box(band - 0.02, band - 0.02, h + 0.02, sx * (PW + band / 2), sy * (PW + band / 2), z,
              pick(CURB_T, i), bevel=0.035, jitter=0.006)
    for s, (dx, dy) in ARMS.items():
        if s in open_sides:
            continue
        x = -PW
        i = 0
        while x < PW - 1e-3:
            L = min(rng.choice((0.4, 0.5, 0.55)), PW - x)
            if PW - x - L < 0.25:
                L = PW - x
            c = x + L / 2
            cx, cy = (c, dy * (PW + band / 2)) if dy else (dx * (PW + band / 2), c)
            sxs, sys = (L - 0.02, band - 0.02) if dy else (band - 0.02, L - 0.02)
            b.box(sxs, sys, h + rng.uniform(-0.01, 0.01), cx, cy, z, pick(CURB_T, i + len(s)), bevel=0.035, jitter=0.006)
            x += L
            i += 1


def seam_sockets(b, open_sides, z=PATH_TOP):
    for s in open_sides:
        dx, dy = ARMS[s]
        b.socket(f"seam_{s}", (dx * HALF, dy * HALF, z), rotz=math.degrees(math.atan2(dy, dx)) - 90)


def path_tile(name, open_sides):
    b = Builder(name)
    cobbles(b, path_rects(open_sides))
    curbs(b, open_sides)
    seam_sockets(b, open_sides)
    b.socket("light", (-(PW + 0.1), -(PW + 0.1), 0.16))  # corner curb: lantern post spot
    if len(open_sides) >= 3:
        b.socket("sign", (PW + 0.1, PW + 0.1, 0.16))
    return done(b, "path", {"open_sides": sorted(open_sides), "walk_z": PATH_TOP, "collision": "flat_top"})


# ---------------------------------------------------------------- steps and landings
def stone_step():
    """Two 0.25 m steps climbing +Y; 2 m wide, 1 m long. Bottom at PATH_TOP, top at PATH_TOP + 0.5."""
    b = Builder("stone_step")
    L, n = 1.0, 2
    tread = L / n
    for k in range(n):
        top = PATH_TOP + RISE * (k + 1) / n
        y = -L / 2 + tread * (k + 0.5)
        # solid riser block under the tread (also the step collision)
        b.box(2 * PW, tread, top - 0.05, 0, y, 0, "stone_grey", bevel=0.02)
        # tread slabs in two pieces so it reads as laid stone
        for i, (xa, xc) in enumerate(((-PW, -0.1), (-0.1, PW))):
            b.box(xc - xa - 0.03, tread - 0.03, 0.05, (xa + xc) / 2, y, top - 0.05, pick(STONE_T, k + i), bevel=0.025)
    for sx in (-1, 1):  # cheek walls rise with the flight and finish level with the landing
        for k in range(n + 1):
            hh = PATH_TOP + RISE * min(k + 1, n) / n + 0.1
            yy = -L / 2 + (L / (n + 1)) * (k + 0.5)
            b.box(HALF - PW - 0.02, L / (n + 1) - 0.02, hh, sx * (PW + (HALF - PW) / 2), yy, 0,
                  pick(CURB_T, k + (sx > 0)), bevel=0.035, jitter=0.006)
    b.socket("seam_s", (0, -L / 2, PATH_TOP), rotz=180)
    b.socket("seam_n", (0, L / 2, PATH_TOP + RISE), rotz=0)
    return done(b, "path", {"module_m": [2.0, L], "rise_m": RISE, "step_m": RISE / n, "climb": "+Y",
                            "collision": "steps (0.25 m step-up) or a 26.6 deg ramp collider"})


def landing():
    """2 x 2 raised stone platform, walking top at PATH_TOP + 0.5, corner posts. Open on all sides
    (steps or a bridge approach attach); rails attach between the posts."""
    b = Builder("landing")
    z = RISE
    b.box(2 * HALF - 0.04, 2 * HALF - 0.04, z - 0.01, 0, 0, 0, "stone_grey", bevel=0.02)  # core / collision
    for s, rz in (("s", 0), ("e", 90), ("n", 180), ("w", 270)):
        with b.at((0, 0, 0), rotz=rz):
            stone_row(b, 2 * HALF, 0.25, 0.22, x0=-HALF, y=-HALF + 0.11, z=0, mats=CURB_T + ("stone_grey",), unit=0.5, bevel=0.035)
            stone_row(b, 2 * HALF - 0.06, 0.24, 0.2, x0=-HALF + 0.03, y=-HALF + 0.12, z=0.25, mats=CURB_T, unit=0.55, bevel=0.035)
    cobbles(b, path_rects("nsew"), z=z)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        px, py = sx * (HALF - 0.12), sy * (HALF - 0.12)
        b.box(0.18, 0.18, 0.72, px, py, z + PATH_TOP, RAIL_T, bevel=0.025)
        b.box(0.13, 0.13, 0.05, px, py, z + PATH_TOP + 0.72, RAIL_T, bevel=0.015)
        b.socket(f"post_{i}", (px, py, z + PATH_TOP + 0.77))
    seam_sockets(b, "nsew", z=z + PATH_TOP)
    return done(b, "path", {"walk_z": z + PATH_TOP, "rise_m": RISE, "collision": "box top"})


def footbridge_approach_landing():
    """Cobbled ramp from path level (+X edge) up to the world_misc footbridge deck end (-X edge,
    z 0.30). Snap socket_seam_bridge onto footbridge socket_end_e (mirror for end_w)."""
    b = Builder("footbridge_approach_landing")
    z_bridge = 0.30
    ang = math.degrees(math.atan2(z_bridge - PATH_TOP, 2 * HALF))  # ~6.6 deg
    # sloped cobble deck: a tilted frame over a wedge fill whose top is the cobbles' underside
    b.prism([(-HALF, 0), (HALF, 0), (HALF, 0.0), (-HALF, z_bridge - PATH_TOP)], 2 * PW - 0.02, mat="stone_dark")
    with b.at((0, 0, (PATH_TOP + z_bridge) / 2 - PATH_TOP), rot=(0, ang, 0)):
        cobbles(b, [(-HALF, HALF, -PW, PW)])
    for sy in (-1, 1):  # side kerbs stepping up with the ramp
        for k in range(4):
            x0 = -HALF + k * 0.5
            hh = z_bridge - (z_bridge - PATH_TOP) * (k + 0.5) / 4 + 0.12
            b.box(0.48, HALF - PW - 0.02, hh, x0 + 0.25, sy * (PW + (HALF - PW) / 2), 0, pick(CURB_T, k + (sy > 0)), bevel=0.035, jitter=0.005)
        b.box(0.16, 0.16, 0.8, -HALF + 0.12, sy * (PW + 0.1), z_bridge + 0.1, RAIL_T, bevel=0.025)
        b.box(0.12, 0.12, 0.05, -HALF + 0.12, sy * (PW + 0.1), z_bridge + 0.9, RAIL_T, bevel=0.015)
        b.socket(f"light_{'s' if sy < 0 else 'n'}", (-HALF + 0.12, sy * (PW + 0.1), z_bridge + 0.95))
    b.socket("seam_bridge", (-HALF, 0, z_bridge), rotz=90)
    b.socket("seam_e", (HALF, 0, PATH_TOP), rotz=-90)
    return done(b, "path", {"ramp_deg": round(ang, 1), "high_z": z_bridge, "low_z": PATH_TOP,
                            "pairs_with": "world_misc/footbridge socket_end_e (rotate 180 for end_w)"})


# ---------------------------------------------------------------- cliffs
def rock_face(b, length, H, x0=-HALF, y=-0.5, seed=0):
    """Faceted rock columns along +X with their front near y; a solid core sits behind them."""
    rng = random.Random(seed)
    x = x0
    i = 0
    while x < x0 + length - 1e-3:
        w = min(rng.uniform(0.32, 0.5), x0 + length - x)
        if x0 + length - x - w < 0.2:
            w = x0 + length - x
        hh = H * rng.uniform(0.82, 0.97)
        d = rng.uniform(0.34, 0.46)
        b.box(w * 0.98, d, hh, x + w / 2, y + d / 2 + rng.uniform(-0.04, 0.03), 0, pick(ROCK_T + ("rock_grey",), i),
              bevel=0.06, jitter=0.035)
        if hh > 1.2 and rng.random() < 0.7:  # ledge break halfway up
            b.box(w * 0.8, d * 0.7, 0.18, x + w / 2, y + d * 0.3, hh * rng.uniform(0.4, 0.6), "rock_grey", bevel=0.05, jitter=0.03)
        x += w
        i += 1
    for k in range(int(length / 0.45)):  # scree at the foot
        r = rng.uniform(0.09, 0.17)
        b.blob(r * 1.2, r, r * 0.8, x0 + rng.uniform(0.15, length - 0.15), y - rng.uniform(0.05, 0.2), r * 0.5,
               pick(("rock_grey", "rock_b"), k), subdiv=1, jitter=r * 0.15)


def cliff_straight(H):
    """2 m cliff, upper ground behind (+Y) at z=H; drops toward -Y."""
    b = Builder(f"cliff_straight_{int(H)}m", seed=300 + int(H))
    b.box(2 * HALF, 0.62, H, 0, 0.19, 0, "rock_grey", bevel=0.03)  # core / collision, top = walkable
    rock_face(b, 2 * HALF, H, y=-0.5, seed=int(H * 10))
    b.socket("seam_w", (-HALF, 0, H), rotz=90)
    b.socket("seam_e", (HALF, 0, H), rotz=-90)
    b.socket("cap", (0, 0, H))
    return done(b, "cliff", {"height_m": H, "top_z": H, "drop_side": "-Y", "collision": "box"})


def cliff_corner(outer=True, H=2.0):
    """90 deg cliff corner. Outer: upper ground is the +X+Y quadrant (convex nose at -X-Y).
    Inner: upper ground wraps three quadrants (concave)."""
    b = Builder(f"cliff_corner_{'outer' if outer else 'inner'}", seed=320 + outer)
    if outer:
        b.box(1.5, 1.5, H, 0.25, 0.25, 0, "rock_grey", bevel=0.03)
        rock_face(b, 1.5, H, x0=-0.5, y=-0.5, seed=21)
        with b.at((0, 0, 0), rotz=-90):
            rock_face(b, 1.5, H, x0=-1.0, y=-0.5, seed=22)
        b.box(0.5, 0.5, H * 0.95, -0.55, -0.55, 0, "rock_b", bevel=0.07, jitter=0.04)  # nose column
    else:
        b.box(2 * HALF, 1.5, H, 0, 0.25, 0, "rock_grey", bevel=0.03)
        b.box(1.5, 0.5, H, -0.25, -0.75, 0, "rock_grey", bevel=0.03)
        rock_face(b, 1.0, H, x0=0.0, y=-0.5, seed=23)
        with b.at((0, 0, 0), rotz=90):
            rock_face(b, 1.0, H, x0=-0.5, y=-0.5, seed=24)
    b.socket("seam_w", (-HALF, 0 if not outer else 0.25, H), rotz=90)
    b.socket("seam_n", (0.25 if outer else 0, HALF, H), rotz=0)
    return done(b, "cliff", {"height_m": H, "top_z": H, "corner": "outer" if outer else "inner", "collision": "box"})


def cliff_cap():
    """Rock coping for a cliff's front lip: sits on top of a cliff at socket_cap; walkable top behind stays at H."""
    b = Builder("cliff_cap", seed=340)
    rng = random.Random(4)
    x = -HALF
    i = 0
    while x < HALF - 1e-3:
        w = min(rng.uniform(0.4, 0.6), HALF - x)
        if HALF - x - w < 0.25:
            w = HALF - x
        b.box(w - 0.02, 0.5, rng.uniform(0.14, 0.2), x + w / 2, -0.28, 0, pick(ROCK_T, i), bevel=0.05, jitter=0.02)
        x += w
        i += 1
    return done(b, "cliff", {"sits_on": "cliff socket_cap", "lip_depth_m": 0.5})


# ---------------------------------------------------------------- streams
BED = -0.7
CH_IN, CH_OUT = 0.5, 0.8  # water half-width, top-of-bank half-distance


def heightfield(b, dist, n=16, seed=0):
    """Terrain tile over the module: ground (tint) at z=0 away from the channel, rock banks, bed at BED.
    dist(x, y) = distance from the stream centreline. Edge vertices stay unjittered so modules match."""
    rng = random.Random(seed)
    verts, idx = [], {}

    def h(x, y):
        d = dist(x, y)
        if d <= CH_IN:
            return BED
        if d >= CH_OUT:
            return 0.0
        t = (d - CH_IN) / (CH_OUT - CH_IN)
        return BED * (1 - t) ** 1.6
    for i in range(n + 1):
        for j in range(n + 1):
            x, y = -HALF + 2 * HALF * i / n, -HALF + 2 * HALF * j / n
            edge = i in (0, n) or j in (0, n)
            z = h(x, y)
            if not edge and BED < z < 0:
                z += rng.uniform(-0.04, 0.04)
                x += rng.uniform(-0.03, 0.03)
            idx[i, j] = len(verts)
            verts.append((x, y, z))
    faces = {"top": [], "bank": [], "bed": []}
    for i in range(n):
        for j in range(n):
            q = (idx[i, j], idx[i + 1, j], idx[i + 1, j + 1], idx[i, j + 1])
            zs = [verts[k][2] for k in q]
            key = "top" if min(zs) > -0.02 else ("bed" if max(zs) < BED + 0.02 else "bank")
            faces[key] += [(q[0], q[1], q[2]), (q[0], q[2], q[3])]
    for key, mat_ in (("top", GROUND_T), ("bank", ROCK_T[0]), ("bed", "soil")):
        if faces[key]:
            used = sorted({k for t in faces[key] for k in t})
            rm = {k: m for m, k in enumerate(used)}
            b.mesh([verts[k] for k in used], [tuple(rm[k] for k in t) for t in faces[key]], mat=mat_)
    # skirt down to the bed so the tile is closed at its seams' underside
    b.box(2 * HALF, 2 * HALF, 0.05, 0, 0, BED - 0.05, "stone_dark", bevel=0)


def boulders(b, pts, seed=0):
    rng = random.Random(seed)
    for i, (x, y) in enumerate(pts):
        r = rng.uniform(0.12, 0.22)
        b.blob(r * 1.2, r, r * 0.9, x, y, rng.uniform(-0.25, -0.05), pick(("rock_grey", "rock_b", "rock"), i),
               subdiv=1, jitter=r * 0.15, rot=(0, 0, rng.uniform(0, 90)))


def water_strip(b, centre, n=10, seed=0):
    """Faceted water ribbon at WATER_Z following centre(t)->(x, y, dirx, diry), t in 0..1."""
    rng = random.Random(seed)
    w = CH_IN + 0.08  # tucks under the bank slope
    verts, faces = [], []
    for k in range(n + 1):
        x, y, dx, dy = centre(k / n)
        nx, ny = -dy, dx
        for s in (-1, 0, 1):
            j = 0 if k in (0, n) or s else rng.uniform(-0.04, 0.04)
            verts.append((x + nx * w * s + j, y + ny * w * s + j, WATER_Z))
    for k in range(n):
        a = k * 3
        for s in range(2):
            p, q, r_, t = a + s, a + s + 1, a + s + 4, a + s + 3
            faces += [(p, q, r_), (p, r_, t)]
    b.mesh(verts, faces, mat="water")


def stream_straight():
    """Stream along Y, flowing toward -Y. Water is the separate 'flow' part."""
    b = Builder("stream_straight", seed=360)
    heightfield(b, lambda x, y: abs(x), seed=1)
    boulders(b, [(-0.62, -0.6), (0.66, -0.1), (-0.6, 0.45), (0.64, 0.7), (0.1, 0.15)], seed=2)
    with b.part("flow", pivot=(0, 0, WATER_Z), motion="flow", dir=[0, -1, 0]):
        water_strip(b, lambda t: (0.0, HALF - 2 * HALF * t, 0.0, -1.0), seed=3)
    b.socket("seam_n", (0, HALF, WATER_Z), rotz=0)
    b.socket("seam_s", (0, -HALF, WATER_Z), rotz=180)
    b.socket("fx_ripple", (0.1, 0.1, WATER_Z))
    return done(b, "stream", {"flow": "-Y", "water_z": WATER_Z, "bed_z": BED, "channel_width_m": 2 * CH_IN,
                              "collision": "heightfield; water not walkable"})


def stream_bend():
    """90 deg bend: enters at the -Y edge, leaves at the +X edge (arc centred on (+1, -1))."""
    b = Builder("stream_bend", seed=370)
    cx, cy = HALF, -HALF
    heightfield(b, lambda x, y: abs(math.hypot(x - cx, y - cy) - HALF), n=18, seed=4)
    boulders(b, [(-0.55, 0.3), (0.0, 0.62), (0.55, -0.6), (-0.2, -0.05)], seed=5)

    def centre(t):  # from the +X edge (1, 0) round to the -Y edge (0, -1), flowing that way
        a = math.radians(90 + 90 * t)
        return cx + HALF * math.cos(a), cy + HALF * math.sin(a), -math.sin(a), math.cos(a)
    with b.part("flow", pivot=(0, 0, WATER_Z), motion="flow", dir=[-1, 0, 0]):
        water_strip(b, centre, n=12, seed=6)
    b.socket("seam_e", (HALF, 0, WATER_Z), rotz=-90)
    b.socket("seam_s", (0, -HALF, WATER_Z), rotz=180)
    return done(b, "stream", {"flow": "+X edge -> -Y edge", "water_z": WATER_Z, "bed_z": BED})


def stream_bank():
    """Bank edge for where the ground meets wider water (pond, harbour): ground at +Y, water at -Y."""
    b = Builder("stream_bank", seed=380)
    heightfield(b, lambda x, y: max(0.0, y + HALF), seed=7)  # bed at the -Y edge, ground by y=-0.2
    boulders(b, [(-0.7, -0.55), (-0.15, -0.45), (0.4, -0.6), (0.8, -0.4)], seed=8)
    b.socket("seam_w", (-HALF, 0, 0), rotz=90)
    b.socket("seam_e", (HALF, 0, 0), rotz=-90)
    return done(b, "stream", {"water_side": "-Y", "water_z": WATER_Z, "note": "pair with nature_dock water_tile_2x2 on the -Y side"})


def stream_end():
    """Spring / source: the channel starts at a rock cluster and flows out of the -Y edge."""
    b = Builder("stream_end", seed=390)
    heightfield(b, lambda x, y: abs(x) if y < 0.1 else math.hypot(x, y - 0.1), seed=9)
    boulders(b, [(-0.35, 0.55), (0.3, 0.6), (0.0, 0.8), (-0.6, 0.1), (0.62, 0.05)], seed=10)
    with b.part("flow", pivot=(0, 0, WATER_Z), motion="flow", dir=[0, -1, 0]):
        water_strip(b, lambda t: (0.0, 0.2 - (0.2 + HALF) * t, 0.0, -1.0), n=8, seed=11)
    b.socket("seam_s", (0, -HALF, WATER_Z), rotz=180)
    b.socket("fx_splash", (0, 0.25, WATER_Z))
    return done(b, "stream", {"flow": "-Y", "water_z": WATER_Z})


# ---------------------------------------------------------------- rails
def rail_post(b, x, base=True):
    if base:
        b.blob(0.17, 0.15, 0.1, x, 0, 0.06, "rock_grey", subdiv=1, jitter=0.02)
    b.box(0.15, 0.15, 0.82, x, 0, 0.0, RAIL_T, bevel=0.025)
    b.box(0.11, 0.11, 0.05, x, 0, 0.82, RAIL_T, bevel=0.015)


def rail_segment():
    """2 m rail along X: a post at the -X end plus two rails; chain segments, cap with rail_end_post."""
    b = Builder("rail_segment", seed=400)
    rail_post(b, -HALF + 0.08)
    for z, hh in ((0.66, 0.09), (0.36, 0.07)):
        b.box(2 * HALF - 0.02, 0.07, hh, 0.04, 0, z, RAIL_T, bevel=0.015)
    b.socket("light", (-HALF + 0.08, -0.12, 0.6), rotz=0)
    b.socket("seam_w", (-HALF, 0, 0), rotz=90)
    b.socket("seam_e", (HALF, 0, 0), rotz=-90)
    return done(b, "rail", {"length_m": 2.0, "post_at": "-X end", "collision": "box 2.0 x 0.15 x 0.87"})


def rail_end_post():
    b = Builder("rail_end_post", seed=410)
    rail_post(b, 0.0)
    b.socket("light", (0, -0.12, 0.6))
    return done(b, "rail", {"caps": "rail_segment +X end"})


# ---------------------------------------------------------------- snow overlays
def snow_heap(b, x, y, z, w, d, rng):
    b.box(w, d, 0.05, x, y, z, "snow", bevel=0.022)
    b.blob(w * 0.45, d * 0.45, 0.06, x, y, z + 0.04, "snow", subdiv=1, jitter=0.01)
    if rng.random() < 0.5:
        b.blob(w * 0.3, d * 0.3, 0.05, x + rng.uniform(-w, w) * 0.2, y, z + 0.07, "snow_shade", subdiv=1)


def snow_overlay_path(name, open_sides):
    """Snow on the curbs and corners of the matching path tile; the walking area stays clear."""
    b = Builder(name)
    rng = b.rng
    band = HALF - PW
    top = 0.15 + 0.004
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        snow_heap(b, sx * (PW + band / 2), sy * (PW + band / 2), top, band + 0.02, band + 0.02, rng)
    for s, (dx, dy) in ARMS.items():
        if s in open_sides:
            continue
        for c in (-0.45, 0.1, 0.5):
            L = rng.uniform(0.3, 0.45)
            cx, cy = (c, dy * (PW + band / 2)) if dy else (dx * (PW + band / 2), c)
            w, d = (L, band * 0.9) if dy else (band * 0.9, L)
            snow_heap(b, cx, cy, top, w, d, rng)
    return done(b, "overlay", {"overlays": name.replace("snow_overlay_", ""), "same_origin_as_base": True})


def snow_overlay_cliff(name, outer=None):
    """Snow along a cliff top's front lip (matching cliff_straight_* / cliff_corner_*)."""
    b = Builder(name)
    rng = b.rng
    runs = [((-HALF, HALF), 0)] if outer is None else ([((-0.5, HALF), 0), ((-0.5, HALF), -90)] if outer else [((0.0, HALF), 0), ((-0.5, HALF), 90)])
    for (a, c), rz in runs:
        with b.at((0, 0, 0), rotz=rz):
            x = a
            while x < c - 1e-3:
                w = min(rng.uniform(0.4, 0.6), c - x)
                snow_heap(b, x + w / 2, -0.3, 0.0, w, 0.45, rng)
                b.blob(w * 0.4, 0.12, 0.16, x + w / 2, -0.52, -0.08, "snow", subdiv=1, jitter=0.02)  # drip over the edge
                x += w
    return done(b, "overlay", {"z_offset": "place at the cliff's socket_cap (z = top_z)", "same_origin_as_base": True})


# ---------------------------------------------------------------- build
PATHS = {"straight_path_tile": "ns", "path_corner": "ne", "path_junction_t": "nes", "path_junction_x": "nesw", "path_end": "s"}


def build():
    for name, sides in PATHS.items():
        path_tile(name, sides)
    stone_step()
    landing()
    footbridge_approach_landing()
    cliff_straight(1.0)
    cliff_straight(2.0)
    cliff_corner(True)
    cliff_corner(False)
    cliff_cap()
    stream_straight()
    stream_bend()
    stream_bank()
    stream_end()
    rail_segment()
    rail_end_post()
    for name, sides in PATHS.items():
        snow_overlay_path("snow_overlay_" + name.replace("_tile", ""), sides)
    snow_overlay_cliff("snow_overlay_cliff_straight")
    snow_overlay_cliff("snow_overlay_cliff_corner_outer", outer=True)
    snow_overlay_cliff("snow_overlay_cliff_corner_inner", outer=False)
