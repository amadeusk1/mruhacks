"""The town: island terrain, paving, sled run and every placement, following
Images/World Map Concept.png. Blender coords: +X east, +Y north, Z up, metres.

Outputs (see vault note Art Docs/World Layout Format.md):
  Models/world/town_terrain.glb   terrain meshes + water
  Models/world/town_layout.json   placements and markers in Godot space
  Renders/Details/town_*.png      previews from the concept camera
Run:  Blender -b --factory-startup --python art/blender/world/build_town.py
"""
import math, json, os, random
import bpy
from mathutils import Vector
import common
from common import Builder, mat, tint

KIT = "world"
WATER_Z = -0.5
SEA_FLOOR = -2.4
RNG = random.Random(7)


# ---------------------------------------------------------------- zones ----
# Layout follows Images/World Map - Overhead Layout.png (S metres per concept pixel, plaza at the
# origin, north = +Y); mood follows Images/World Map - Island Overview.png.
S = 0.065


def C(px, py):
    return Vector(((px - 575) * S, (580 - py) * S))


PLAZA_C, PLAZA_R = Vector((0.0, 0.0)), 9.5
ISLAND_C, ISLAND_HALF, ISLAND_N = Vector((0.0, 1.3)), Vector((38.5, 35.5)), 4.0
HILL_TOP = 6.0
ARENA_C, ARENA_HALF, ARENA_Z = Vector((28.5, 23.7)), Vector((7.4, 6.1)), 1.5
SKETCH_C, SKETCH_Z = C(1050, 595), 0.0
COURT_C = Vector((25.5, -19.2))
COVE = [(Vector((-16.5, -22.0)), Vector((12.0, 9.0))), (Vector((-24.0, -31.0)), Vector((9.0, 5.5)))]
CINEMA_P, CAFE_P, ARCADE_P = C(575, 200), C(455, 370), Vector((10.3, 13.4))
CASINO_P = Vector((23.2, 8.4))   # Images/World Map - Casino Placement.png: east of the arcade, across the stream

# streets (metres) for the homes grid
HX, HY = (-35.0, -23.5, -12.0), (9.5, 0.0, -9.5)

PATHS = [  # (polyline, width)
    ([C(575, 440), C(575, 290)], 3.0),                                  # N spoke -> cinema
    ([C(495, 505), C(470, 425)], 2.6),                                  # NW spoke -> cafe
    ([C(655, 505), Vector((10.3, 9.6))], 2.6),                          # NE spoke -> arcade
    ([Vector((-PLAZA_R + 0.4, 0)), Vector((HX[0], 0))], 2.8),           # W spoke = homes main street
    ([Vector((PLAZA_R - 0.4, 0)), C(1000, 595)], 2.8),                  # E spoke -> sketch club
    ([Vector((0, -PLAZA_R + 0.4)), C(600, 1030)], 2.8),                 # S spoke -> south pier
    ([Vector((-6.2, -7.2)), Vector((-11.4, -11.7))], 2.6),              # SW spoke -> cove
    ([Vector((6.2, -7.2)), C(760, 760), Vector((19.2, -14.3))], 2.6),   # SE spoke -> court
    ([C(470, 425), C(420, 340), Vector((-8.6, 17.4))], 2.4),            # cafe -> sled stairs foot
    ([Vector((-17.4, 26.1)), Vector((-15.6, 28.8)), Vector((-12.4, 30.2))], 2.2),     # stair top -> sled start plateau
    ([C(575, 290), C(700, 230), C(880, 230), Vector((24.7, 14.4))], 2.4),   # cinema -> arena stairs foot
    ([Vector((24.7, 14.4)), Vector((30.4, 12.6)), Vector((30.4, 4.0)), C(1000, 595)], 2.4),  # arena -> east loop -> sketch
    ([Vector((23.2, 4.2)), Vector((23.2, -0.6))], 2.6),               # casino forecourt -> east spoke
    ([C(1000, 595), C(1010, 760), Vector((25.0, -14.6))], 2.4),         # sketch -> court
    ([Vector((HX[0], HY[0])), Vector((HX[2], HY[0]))], 2.2),            # homes grid
    ([Vector((HX[0], HY[2])), Vector((HX[2], HY[2]))], 2.2),
    ([Vector((HX[0], HY[0])), Vector((HX[0], HY[2]))], 2.2),
    ([Vector((HX[1], HY[0])), Vector((HX[1], HY[2]))], 2.2),
    ([Vector((HX[2], HY[0])), Vector((HX[2], HY[2]))], 2.2),
    ([Vector((HX[2], HY[0])), C(420, 340)], 2.2),                       # homes -> sled stairs path
    ([Vector((-11.4, -11.7)), Vector((-15.9, -12.0)), Vector((-24.0, -12.6))], 2.4),  # cove shore path
    ([Vector((HX[0], HY[2])), Vector((-30.0, -12.4)), Vector((-24.0, -12.6))], 2.2),  # homes -> boathouse
]

STREAM = [C(800, 70), C(800, 250), C(850, 330), C(800, 450), C(780, 580), C(760, 700), C(700, 800),
          C(690, 920), C(700, 1080)]
STREAM_W, STREAM_BED = 1.05, -1.05

# Authored sled course on the NW hill (concept: wide white track hugging the hill's west face,
# start gate on the top plateau, long run-out, return stairs on the east side).
TRACK_CTRL = [(-13.0, 31.0), (-17.5, 32.4), (-23.5, 31.6), (-28.2, 28.0), (-29.0, 23.4), (-26.2, 19.6),
              (-21.4, 18.0), (-16.6, 17.4), (-13.2, 17.0)]
TRACK_W, TRACK_LIP = 4.2, 0.7          # carved surface width, raised snow berm each side
TRACK_TOP, TRACK_FINISH_Z, TRACK_END_Z = 6.0, 0.55, 0.3
TRACK_FLAT_START, TRACK_RUNOUT = 2.5, 7.0   # metres of flat start pad and of run-out after the finish line
SLED_STAIRS = (Vector((-9.4, 19.4)), Vector((-9.4, 30.9)))   # foot -> top, east of the hill


def _catmull(pts, step=0.5):
    """Uniform Catmull-Rom through pts, resampled every ~step metres."""
    P = [Vector(pts[0]) * 2 - Vector(pts[1])] + [Vector(q) for q in pts] + [Vector(pts[-1]) * 2 - Vector(pts[-2])]
    dense = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(20):
            t = k / 20
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


TRACK = _catmull(TRACK_CTRL)
_S = [0.0]
for _a, _b in zip(TRACK, TRACK[1:]):
    _S.append(_S[-1] + (_b - _a).length)
TRACK_LEN = _S[-1]
TRACK_FINISH_S = TRACK_LEN - TRACK_RUNOUT


def track_z_at(s):
    if s <= TRACK_FLAT_START:
        return TRACK_TOP
    if s <= TRACK_FINISH_S:
        t = (s - TRACK_FLAT_START) / (TRACK_FINISH_S - TRACK_FLAT_START)
        return TRACK_TOP + (TRACK_FINISH_Z - TRACK_TOP) * t
    t = (s - TRACK_FINISH_S) / TRACK_RUNOUT
    return TRACK_FINISH_Z + (TRACK_END_Z - TRACK_FINISH_Z) * t


def _bank(i):
    """Bank angle (radians, +: left edge higher) from local curvature, so curves are banked outward."""
    a, b = TRACK[max(i - 3, 0)], TRACK[min(i + 3, len(TRACK) - 1)]
    m = TRACK[i]
    h1, h2 = math.atan2((m - a).y, (m - a).x), math.atan2((b - m).y, (b - m).x)
    dh = (h2 - h1 + math.pi) % (2 * math.pi) - math.pi
    L = max((b - a).length, 1e-3)
    k = dh / L                                            # signed curvature, + = turning left
    return max(-0.28, min(0.28, -k * 2.2))               # left turn -> right (outer) edge up


TRACK_BANK = [_bank(i) for i in range(len(TRACK))]
TRACK_WIDTH = [TRACK_W + (2.0 * max(0.0, (s - TRACK_FINISH_S) / TRACK_RUNOUT)) for s in _S]   # widens into the stop area


def track_frame(i):
    a, b = TRACK[max(i - 1, 0)], TRACK[min(i + 1, len(TRACK) - 1)]
    t = (b - a).normalized()
    return t, Vector((-t.y, t.x))


def track_nearest(p):
    """(distance, index, signed lateral offset) of p to the sampled centreline."""
    best, bi = 1e9, 0
    for i, q in enumerate(TRACK):
        d = (p - q).length_squared
        if d < best:
            best, bi = d, i
    t, n = track_frame(bi)
    return math.sqrt(best), bi, (p - TRACK[bi]).dot(n)


def track_surface_z(i, lat):
    return track_z_at(_S[i]) + lat * math.tan(TRACK_BANK[i])


TRACK_BBOX = (min(q.x for q in TRACK) - 8, max(q.x for q in TRACK) + 8, min(q.y for q in TRACK) - 8, max(q.y for q in TRACK) + 8)


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def ellipse_d(p, c, rx, ry):
    """<0 inside, approx metres outside."""
    q = Vector(((p.x - c.x) / rx, (p.y - c.y) / ry))
    return (q.length - 1.0) * min(rx, ry)


def seg_dist(p, a, b):
    a, b = Vector(a), Vector(b)
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def poly_dist(p, pts):
    return min(seg_dist(p, a, b) for a, b in zip(pts, pts[1:]))


def poly_param(p, pts):
    """(distance to polyline, arc length of the nearest point, total length)."""
    best, at, run = 1e9, 0.0, 0.0
    for a, b in zip(pts, pts[1:]):
        ab = b - a
        L = ab.length
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(L * L, 1e-9)))
        d = (p - (a + ab * t)).length
        if d < best:
            best, at = d, run + t * L
        run += L
    return best, at, run


def island_d(p):
    """Signed distance-ish to the coastline: <0 on land. Rounded square (superellipse) minus the cove."""
    q = Vector((abs(p.x - ISLAND_C.x) / ISLAND_HALF.x, abs(p.y - ISLAND_C.y) / ISLAND_HALF.y))
    r = (q.x ** ISLAND_N + q.y ** ISLAND_N) ** (1 / ISLAND_N)
    # wobble so the coast is not a perfect curve
    a = math.atan2(p.y - ISLAND_C.y, p.x - ISLAND_C.x)
    r += 0.035 * math.sin(5 * a) + 0.02 * math.sin(11 * a + 1.3)
    d = (r - 1.0) * min(ISLAND_HALF)
    for c, rad in COVE:
        d = max(d, -ellipse_d(p, c, rad.x, rad.y))
    return d


def stream_d(p):
    return poly_dist(p, STREAM)


def cove_d(p):
    return min(ellipse_d(p, c, r.x, r.y) for c, r in COVE)


# ---------------------------------------------------------------- terrain --
def hill_h(p):
    """NW hill: a dome with a flat top plateau (start area), falling away to the plaza and coast."""
    d = ellipse_d(p, Vector((-20.0, 26.8)), 9.0, 6.2)
    return HILL_TOP * (1 - smoothstep(-1.5, 3.5, d))


_HC = {}


def height(p):
    key = (round(p.x, 3), round(p.y, 3))
    if key in _HC:
        return _HC[key]
    _HC[key] = v = _height(p)
    return v


def _height(p):
    d = island_d(p)
    if d > 0:                                            # sea floor, dropping with distance
        return SEA_FLOOR - min(1.0, d * 0.15)
    h = hill_h(p)
    # north woodland rise behind the cinema, where the stream springs
    h = max(h, 1.2 * (1 - smoothstep(-2.0, 2.5, ellipse_d(p, Vector((8.0, 32.0)), 12.0, 4.5))))
    # snowball arena plateau (rounded rectangle, firm edge)
    q = Vector((max(abs(p.x - ARENA_C.x) - ARENA_HALF.x, 0), max(abs(p.y - ARENA_C.y) - ARENA_HALF.y, 0)))
    h = max(h, ARENA_Z * (1 - smoothstep(0.2, 1.6, q.length)))
    # stairs runs: terrain rises with them
    for (a, b, z0, z1) in stair_runs():
        dv = (b - a).normalized()
        t = (p - a).dot(dv)
        w = abs((p - a).dot(Vector((-dv.y, dv.x))))
        L = (b - a).length
        if -0.3 <= t <= L + 0.3 and w < 1.5:
            h = max(h, z0 + (z1 - z0) * max(0.0, min(1.0, t / L)))
    # sled track: terrain sits just under the ribbon mesh, then blends back to the hill
    if TRACK_BBOX[0] < p.x < TRACK_BBOX[1] and TRACK_BBOX[2] < p.y < TRACK_BBOX[3]:
        td, ti, lat = track_nearest(p)
        half = TRACK_WIDTH[ti] * 0.5 + TRACK_LIP
        if td < half + 2.5:
            tz = track_surface_z(ti, max(-half, min(half, lat))) - 0.12
            w = 1 - smoothstep(half - 0.1, half + 2.5, td)
            h = h * (1 - w) + tz * w
    # stream: a channel below the water plane with soft snowy banks
    sd = stream_d(p)
    if sd < STREAM_W + 0.9:
        h = min(h, STREAM_BED + (h - STREAM_BED) * smoothstep(STREAM_W * 0.6, STREAM_W + 0.9, sd))
    pw, pz = pad_w(p)
    h = h * (1 - pw) + pz * pw
    # coastline: steep drop behind the cliff ring
    edge = smoothstep(-0.9, 0.5, d)
    return h * (1 - edge) + (SEA_FLOOR + 0.2) * edge


# flat building pads: (centre, half extents, z). Terrain is exactly z inside, blended over 1 m.
PADS = [(CINEMA_P, Vector((4.2, 4.8)), 0.0), (CAFE_P, Vector((3.2, 3.0)), 0.0), (ARCADE_P, Vector((4.2, 3.9)), 0.0),
        (COURT_C, Vector((9.6, 5.4)), 0.0), (SKETCH_C, Vector((3.6, 3.6)), 0.0), (CASINO_P, Vector((4.6, 4.2)), 0.0)] + \
       [(Vector((x, y)), Vector((4.4, 4.0)), 0.0) for x in (-29.25, -17.75) for y in (4.75, -4.75)] + \
       [(Vector((-12.4, 31.0)), Vector((2.6, 1.8)), HILL_TOP),                 # sled start plateau / stair top
        (Vector((-22.5, 13.6)), Vector((4.0, 3.6)), 0.0), (Vector((-33.0, 13.0)), Vector((4.2, 3.9)), 0.0),
        (STAIR_LANDING[0], Vector((1.1, 1.1)), STAIR_LANDING[1]),              # mid-flight landing
        (Vector((-17.4, 26.1)), Vector((1.4, 1.4)), HILL_TOP),                   # top of the upper flight
        (Vector((24.7, 18.6)), Vector((1.2, 0.6)), ARENA_Z),                     # arena stair top
        (Vector((24.7, 14.1)), Vector((1.2, 0.6)), 0.0)]                         # arena stair foot


def pad_w(p):
    """(weight 0..1, z) of the strongest pad at p."""
    best, z = 0.0, 0.0
    for c, hx, pz in PADS:
        q = Vector((max(abs(p.x - c.x) - hx.x, 0), max(abs(p.y - c.y) - hx.y, 0))).length
        w = 1 - smoothstep(0.0, 1.0, q)
        if w > best:
            best, z = w, pz
    return best, z


# stair flights: (foot xy, climb direction, modules). stone_stairs_snow mesh is 1.0 m per 0.5 m rise.
STAIR_FLIGHTS = [(Vector((-8.6, 17.6)), Vector((0, 1)), 6, 0.0),          # sled hill, lower flight (north)
                 (Vector((-9.6, 26.1)), Vector((-1, 0)), 6, 3.0),         # sled hill, upper flight (west, onto the plateau)
                 (Vector((24.7, 14.6)), Vector((0, 1)), 3, 0.0)]          # snowball arena plateau
STAIR_CHAINS = []
for _foot, _u, _n, _z0 in STAIR_FLIGHTS:
    _mods = [(_foot + _u * (k + 0.5), _z0 + 0.5 * k) for k in range(_n)]
    STAIR_CHAINS.append({"mods": _mods, "dir": _u, "foot": (_foot, _z0), "top": (_foot + _u * _n, _z0 + 0.5 * _n)})
STAIR_LANDING = (Vector((-8.6, 26.1)), 3.0)                                # between the two sled-hill flights


def stair_runs():
    """(foot, top, z at foot, z at top) for every stair flight (terrain follows them)."""
    return [(c["foot"][0], c["top"][0], c["foot"][1], c["top"][1]) for c in STAIR_CHAINS]


def _bridges():
    """(centre, yaw_deg) of a footbridge at every path/stream crossing."""
    out = []
    for pts, w in PATHS:
        for a, b in zip(pts, pts[1:]):
            a, b = Vector(a), Vector(b)
            for c, d in zip(STREAM, STREAM[1:]):
                r, s2 = b - a, d - c
                den = r.x * s2.y - r.y * s2.x
                if abs(den) < 1e-9:
                    continue
                t = ((c - a).x * s2.y - (c - a).y * s2.x) / den
                u = ((c - a).x * r.y - (c - a).y * r.x) / den
                if 0 <= t <= 1 and 0 <= u <= 1:
                    out.append((a + r * t, math.degrees(math.atan2(r.y, r.x))))
    return out


BRIDGES = _bridges()
BRIDGE_LANDINGS = [(c + Vector((math.cos(math.radians(y)), math.sin(math.radians(y)))) * sg * 3.4, y + (0 if sg > 0 else 180))
                   for c, y in BRIDGES for sg in (1, -1)]
PADS += [(c, Vector((1.3, 1.3)), 0.0) for c, _ in BRIDGE_LANDINGS]


def on_path(p):
    if (p - PLAZA_C).length < PLAZA_R:
        return True
    return any(poly_dist(p, pts) < w * 0.5 for pts, w in PATHS)


def on_beach(p):
    d = island_d(p)
    return -4.5 < d < 0.3 and (cove_d(p) < 3.0 and p.x > -14.0 or (p - COURT_C).length < 13.0 and p.y < -26.0)


def build_terrain():
    """Faceted grid. Flat walk areas stay exact; snow and rock get jitter."""
    b = Builder("town_terrain", seed=11)
    b.skip_zfix = True
    X0, X1, Y0, Y1, S = -48, 48, -40, 42, 1.0
    nx, ny = int((X1 - X0) / S), int((Y1 - Y0) / S)
    H = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            p = Vector((X0 + i * S, Y0 + j * S))
            h = height(p)
            if island_d(p) < -3.5 and not on_path(p) and track_nearest(p)[0] > TRACK_W * 0.5 + TRACK_LIP + 1.0 and stream_d(p) > STREAM_W + 1.5 and pad_w(p)[0] == 0:
                h += RNG.uniform(-0.06, 0.09)            # soft snow facets
            elif island_d(p) >= -3.5:
                h += RNG.uniform(-0.25, 0.25)            # rough cliff and sea floor
            H[i, j] = h
    verts, faces, fmats = [], [], []
    vid = {}
    for (i, j), h in H.items():
        vid[i, j] = len(verts)
        verts.append((X0 + i * S, Y0 + j * S, h))
    groups = {}
    for i in range(nx):
        for j in range(ny):
            q = [vid[i, j], vid[i + 1, j], vid[i + 1, j + 1], vid[i, j + 1]]
            tris = ([q[0], q[1], q[2]], [q[0], q[2], q[3]]) if (i + j) % 2 == 0 else ([q[0], q[1], q[3]], [q[1], q[2], q[3]])
            for t in tris:
                vs = [Vector(verts[k]) for k in t]
                n = (vs[1] - vs[0]).cross(vs[2] - vs[0]).normalized()
                c = sum(vs, Vector()) / 3
                p2 = c.xy
                if c.z < WATER_Z - 0.05:
                    m = "seabed"
                elif n.z < 0.72:
                    m = "rock"
                elif on_path(p2):
                    m = "joint"
                elif on_beach(p2):
                    m = "sand"
                else:
                    m = "snow"
                groups.setdefault(m, []).append(t)
    names = {"snow": tint("snow", "#E8EFF4"), "rock": tint("rock", "rock_b"), "joint": "paving_b",
             "sand": tint("sand", "#E8D3A6"), "seabed": "water_deep"}
    for m, tris in groups.items():
        used = sorted({k for t in tris for k in t})
        remap = {k: n for n, k in enumerate(used)}
        b.mesh([verts[k] for k in used], [[remap[k] for k in t] for t in tris], mat=names[m])
    return b


def build_paving():
    """Chunky cobble slabs over the plaza and paths, never overlapping (spatial hash)."""
    b = Builder("town_paving", seed=12)
    b.skip_zfix = True
    taken = {}

    def free(p, r=0.42):
        k = (int(p.x // 0.5), int(p.y // 0.5))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for q in taken.get((k[0] + dx, k[1] + dy), ()):
                    if (q - p).length < r:
                        return False
        taken.setdefault(k, []).append(p)
        return True

    mats = ("paving", "paving_b", "stone")

    def slab(p, ang):
        z = height(p)
        sx, sy = RNG.uniform(0.38, 0.5), RNG.uniform(0.3, 0.42)
        b.box(sx, sy, 0.07 + RNG.uniform(0, 0.012), p.x, p.y, z, mats[RNG.randrange(3)], bevel=0.025,
              rot=(0, 0, ang))
    # plaza: concentric rings of slabs around the fountain
    r = 1.6
    while r < PLAZA_R:
        n = max(6, int(2 * math.pi * r / 0.5))
        off = RNG.uniform(0, 1)
        for k in range(n):
            a = 2 * math.pi * (k + off) / n
            p = PLAZA_C + Vector((math.cos(a), math.sin(a))) * r
            if free(p):
                slab(p, math.degrees(a))
        r += 0.48
    # paths: rows across the width, laid along each segment
    for pts, w in PATHS:
        for a, c in zip(pts, pts[1:]):
            a, c = Vector(a), Vector(c)
            d = (c - a)
            L = d.length
            u = d / L
            nrm = Vector((-u.y, u.x))
            ang = math.degrees(math.atan2(u.y, u.x))
            t = 0.0
            while t <= L:
                for s in range(-int(w / 0.5), int(w / 0.5) + 1):
                    off = s * 0.46 + (0.23 if int(t / 0.44) % 2 else 0)
                    if abs(off) > w / 2 - 0.15:
                        continue
                    p = a + u * t + nrm * off
                    if (p - PLAZA_C).length < PLAZA_R - 0.3 or stream_d(p) < STREAM_W + 0.7 or \
                            any((p - c).length < 1.15 for c, _ in BRIDGE_LANDINGS):
                        continue
                    if free(p):
                        slab(p, ang)
                t += 0.44
    # curb ring around the plaza
    n = int(2 * math.pi * PLAZA_R / 0.62)
    for k in range(n):
        a = 2 * math.pi * k / n
        p = PLAZA_C + Vector((math.cos(a), math.sin(a))) * (PLAZA_R + 0.05)
        if any(seg_dist(p, x, y) < w * 0.5 + 0.3 for pts, w in PATHS for x, y in zip(pts, pts[1:])):
            continue  # leave openings where paths leave the plaza
        b.box(0.58, 0.28, 0.16, p.x, p.y, height(p), "stone_dark", bevel=0.04, rot=(0, 0, math.degrees(a) + 90))
    return b


def build_sled_track():
    """Smooth spline-swept ribbon with banking and raised snow lips (exported as terrain_sled_track)."""
    b = Builder("terrain_sled_track", seed=14)
    b.skip_zfix = True
    verts, faces = [], []
    prof = None
    for i, c in enumerate(TRACK):
        t, n = track_frame(i)
        half = TRACK_WIDTH[i] * 0.5
        lats = [-(half + TRACK_LIP), -half, -half * 0.5, 0.0, half * 0.5, half, half + TRACK_LIP]
        lip = [0.32, 0.0, 0.0, 0.0, 0.0, 0.0, 0.32]
        row = []
        for lat, up in zip(lats, lip):
            q = c + n * lat
            l2 = max(-half, min(half, lat))
            row.append(len(verts))
            verts.append((q.x, q.y, track_surface_z(i, l2) + up + 0.02))
        if prof is not None:
            for k in range(len(row) - 1):
                faces.append([prof[k], prof[k + 1], row[k + 1], row[k]])
        prof = row
    groove = [f for f in faces]
    b.mesh(verts, groove, mat=tint("track", "#F6FAFC"))
    return b


def build_water():
    b = Builder("water", seed=13)
    b.skip_zfix = True
    verts, faces = [], []
    R, S = 90, 3.0
    n = int(2 * R / S)
    idx = {}
    for i in range(n + 1):
        for j in range(n + 1):
            idx[i, j] = len(verts)
            verts.append((-R + i * S + RNG.uniform(-0.6, 0.6), -R + j * S + RNG.uniform(-0.6, 0.6), WATER_Z + RNG.uniform(-0.03, 0.03)))
    for i in range(n):
        for j in range(n):
            a, c, d, e = idx[i, j], idx[i + 1, j], idx[i + 1, j + 1], idx[i, j + 1]
            faces += [[a, c, d], [a, d, e]]
    b.mesh(verts, faces, mat=tint("water", "#1E9FC2"))
    return b


# ------------------------------------------------------------- placements --
PLACE = []      # dicts in Blender space; converted at export
DOCK_Z = {}
DOCK_HEADS = []  # (first tile placement, direction away from shore) for the seam check
MARKERS = []


EDGE_OK = ("lantern_post", "bench", "signpost", "activity_sign", "world_map_board", "spectator_bench", "notice_board",
           "low_boundary_fence", "court_gate", "rope_posts", "snow_fence", "low_wood_fence", "plaza_edge", "water_edge",
           "rail_", "start_gate", "start_light", "finish", "checkpoint", "stanchion")
EXEMPT = ("string_lights", "queue_spot", "shooting_spot", "ready_marker", "ripple", "bobber", "ice_floe", "rowboat",
          "houseboat", "waterfall", "cliff_", "snow_overlay", "stream_", "fountain", "footbridge", "dock_", "fishing_dock",
          "stairs", "landing", "court_half", "arena_blockout", "lighthouse", "icon_", "shore_", "foam", "porch_canopy", "doorstep", "home_number")
ON_DOCK = ("bucket", "fish_", "tackle", "catch_display", "crate", "barrel", "life_ring", "mooring", "coiled_rope",
           "fender", "cleat", "lantern_bracket", "rope_posts")


def footprint(asset, x, y, yaw, scale=1.0, shrink=1.0):
    """Oriented footprint sample points (corners, edge mids, centre) from the manifest size."""
    sz = manifest(asset).get("size_m") or [0.6, 0.6, 0.6]
    hx, hy = sz[0] * 0.5 * scale * shrink, sz[1] * 0.5 * scale * shrink
    a = math.radians(yaw)
    ca, sa = math.cos(a), math.sin(a)
    return [Vector((x + u * ca - v * sa, y + u * sa + v * ca)) for u in (-hx, 0, hx) for v in (-hy, 0, hy)]


def walk_rects():
    out = []
    for q in PLACE:
        if "walkable" in q["tags"]:
            sz = manifest(q["id"]).get("size_m") or [2, 2, 1]
            out.append((Vector(q["pos"][:2]), sz[0] * 0.5 * q["scale"], sz[1] * 0.5 * q["scale"], math.radians(q["yaw"]), q["id"]))
    return out


def in_rect(p, r, pad=0.0):
    c, hx, hy, a, _ = r
    d = p - c
    u = d.x * math.cos(a) + d.y * math.sin(a)
    v = -d.x * math.sin(a) + d.y * math.cos(a)
    return abs(u) < hx + pad and abs(v) < hy + pad


PLAZA_LANES = [(Vector((0, 0)) + Vector((math.cos(math.radians(a)), math.sin(math.radians(a)))) * 2.0,
                Vector((math.cos(math.radians(a)), math.sin(math.radians(a)))) * (PLAZA_R + 0.5)) for a in (0, 90, 180, 270)]


def walk_violation(asset, x, y, yaw, scale, tags, rects=None):
    """Why this placement would stand on a walkable surface (None if clear)."""
    if "walkable" in tags or "building" in tags or "coast" in tags or any(e in asset for e in EXEMPT):
        return None
    edge = any(e in asset for e in EDGE_OK)
    clear = 0.0 if edge else 0.3
    shrink = 0.55 if "tree" in tags else 1.0
    pts = footprint(asset, x, y, yaw, scale, shrink)
    for pts_, w in PATHS:
        for p in pts:
            if poly_dist(p, pts_) < w * 0.5 + clear:
                return "path"
    for a, b in PLAZA_LANES:                                  # spoke lanes across the plaza disc
        for p in pts:
            if seg_dist(p, a, b) < 1.5 + clear and "plaza/bench" not in asset and "lantern" not in asset:
                return "plaza lane"
    for p in pts:
        if 5.3 < (p - PLAZA_C).length < 6.3 and "lantern" not in asset:
            return "plaza ring lane"
    for m in MARKERS:
        if m["kind"] in ("door", "activity", "spawn", "bus"):
            c = Vector(m["pos"][:2])
            if any((p - c).length < 1.3 for p in pts):
                return f"approach {m['name']}"
    for r in (rects if rects is not None else walk_rects()):
        if any(in_rect(p, r) for p in pts):
            if any(k in asset for k in ON_DOCK) and not in_rect(Vector((x, y)), r, -0.55):
                continue                                      # dock dressing along a deck's edge
            return f"on {r[4]}"
    if TRACK_BBOX[0] < x < TRACK_BBOX[1] and TRACK_BBOX[2] < y < TRACK_BBOX[3] and not edge:
        for p in pts:
            td, ti, _ = track_nearest(p)
            if td < TRACK_WIDTH[ti] * 0.5 + TRACK_LIP:
                return "sled track"
    return None


def put(asset, x, y, yaw=0.0, z=None, name=None, tags=("prop",), tints=None, scale=1.0, zone=None, auto=False):
    """Place an asset. auto=True (procedural fill) silently drops placements that would block a walkway."""
    if auto and walk_violation(asset, x, y, yaw, scale, tags):
        return False
    p = Vector((x, y))
    PLACE.append({"id": asset, "name": name, "pos": (x, y, height(p) if z is None else z), "yaw": yaw,
                  "tags": list(tags), "tints": tints or {}, "scale": scale, "zone": zone})
    return True


def validate():
    """Export gate: authored props must never stand on a walkable surface; walkable seams must meet."""
    rects = walk_rects()
    bad = [(q["id"], [round(v, 1) for v in q["pos"][:2]], why) for q in PLACE
           for why in [walk_violation(q["id"], q["pos"][0], q["pos"][1], q["yaw"], q["scale"], q["tags"], rects)] if why]
    seams = check_seams()
    for b in bad:
        print("WALK_VIOLATION", *b)
    for sm in seams:
        print("SEAM", *sm)
    print(f"VALIDATE violations={len(bad)} seams={len(seams)}")
    if bad or seams:
        raise RuntimeError(f"layout validation failed: {len(bad)} props on walkways, {len(seams)} seam gaps")


def surface_z(p):
    """Top of whatever you'd stand on at p: walkable decks/landings, else paving or terrain."""
    best = None
    for q in PLACE:
        if "walkable" not in q["tags"]:
            continue
        sz = manifest(q["id"]).get("size_m") or [2, 2, 1]
        r = (Vector(q["pos"][:2]), sz[0] * 0.5 * q["scale"], sz[1] * 0.5 * q["scale"], math.radians(q["yaw"]), q["id"])
        if in_rect(p, r, 0.05):
            top = q["pos"][2] + (0.3 if "landing" in q["id"] else 0.0)
            if "stairs" in q["id"] or "footbridge" in q["id"] or "court_half" in q["id"] or "arena" in q["id"]:
                continue
            best = top if best is None else max(best, top)
    if best is not None:
        return best
    return height(p) + (0.07 if on_path(p) else 0.0)


def check_seams():
    """Walkable end sockets that miss the surface they hand over to by more than 0.1 m."""
    out = []
    for q in PLACE:
        if "walkable" not in q["tags"]:
            continue
        x, y, z = q["pos"]
        socks = {"world_misc/footbridge": ["socket_end_e", "socket_end_w"],
                 "winter/stone_stairs_snow": [], "town_connections/footbridge_approach_landing": ["socket_seam_e"]}.get(q["id"])
        if socks is None:
            continue
        for sk in socks:
            w = socket_world(q["id"], sk, x, y, q["yaw"], z)
            if not w:
                continue
            # look just beyond the socket, away from the piece
            d = Vector((w[0] - x, w[1] - y))
            pt = Vector((w[0], w[1])) + (d.normalized() * 0.35 if d.length > 1e-6 else Vector())
            exp = height(pt) + (0.07 if on_path(pt) else 0.0)
            if "footbridge" in q["id"] and any("landing" in o["id"] and (Vector(o["pos"][:2]) - Vector((w[0], w[1]))).length < 1.3 for o in PLACE):
                exp = 0.3
            if abs(w[2] - exp) > 0.1:
                out.append((q["id"], [round(x, 1), round(y, 1)], sk, round(w[2], 2), "expected", round(exp, 2)))
    for run in STAIR_CHAINS:
        foot, top = run["foot"], run["top"]
        if abs(height(foot[0]) + 0.0 - foot[1]) > 0.1:
            out.append(("stairs foot", [round(foot[0].x, 1), round(foot[0].y, 1)], round(foot[1], 2), "ground", round(height(foot[0]), 2)))
        if abs(height(top[0]) - top[1]) > 0.1:
            out.append(("stairs top", [round(top[0].x, 1), round(top[0].y, 1)], round(top[1], 2), "ground", round(height(top[0]), 2)))
    for q0, pier_dir in DOCK_HEADS:
        sz = 1.0
        edge = Vector(q0["pos"][:2]) - pier_dir * (sz + 0.35)
        exp = height(edge) + (0.07 if on_path(edge) else 0.0)
        if abs(q0["pos"][2] - exp) > 0.1:
            out.append((q0["id"], [round(v, 1) for v in q0["pos"][:2]], "shore end", round(q0["pos"][2], 2), "expected", round(exp, 2)))
    return out


def mark(name, x, y, yaw=0.0, kind="spawn", z=None, **extra):
    MARKERS.append({"name": name, "pos": (x, y, height(Vector((x, y))) if z is None else z), "yaw": yaw,
                    "kind": kind, **extra})


def face(fx, fy, tx, ty):
    """Yaw so an asset at (fx,fy) faces (tx,ty) (assets face -Y)."""
    return math.degrees(math.atan2(tx - fx, -(ty - fy)))


class KeepOut(list):
    """(point, radius) list with a 4 m spatial hash so overlap tests stay fast with thousands of props."""
    def __init__(self, items=()):
        super().__init__()
        self.h = {}
        for it in items:
            self.append(it)

    def append(self, it):
        super().append(it)
        c, r = it
        self.h.setdefault((int(c.x // 4), int(c.y // 4)), []).append(it)

    def blocked(self, p, r):
        kx, ky = int(p.x // 4), int(p.y // 4)
        for dx in (-2, -1, 0, 1, 2):
            for dy in (-2, -1, 0, 1, 2):
                for c, rr in self.h.get((kx + dx, ky + dy), ()):
                    if (p - c).length < max(r, rr):
                        return True
        return False


_MAN = {}


def manifest(asset):
    kit = asset.split("/")[0]
    if kit not in _MAN:
        pth = os.path.join(common.MODELS, kit, "manifest.json")
        _MAN[kit] = {a["id"]: a for a in json.load(open(pth))} if os.path.exists(pth) else {}
    return _MAN[kit].get(asset, {})


def socket_world(asset, sock, x, y, yaw, z=0.0):
    loc = manifest(asset).get("sockets", {}).get(sock)
    if not loc:
        return None
    a = math.radians(yaw)
    return (x + loc[0] * math.cos(a) - loc[1] * math.sin(a), y + loc[0] * math.sin(a) + loc[1] * math.cos(a), z + loc[2])


def building(asset, x, y, yaw, name, door_target=None, zone=None, tints=None, scale=1.0):
    z = height(Vector((x, y)))
    put(asset, x, y, yaw, z=z, name=name, tags=("building", "blocker"), zone=zone, tints=tints, scale=scale)
    d = socket_world(asset, "socket_door", x, y, yaw, z)
    if d and door_target:
        mark(f"{name}Door", d[0], d[1], yaw, kind="door", target=door_target, z=d[2])


def intersect(a, b, c, d):
    r, s2 = b - a, d - c
    den = r.x * s2.y - r.y * s2.x
    if abs(den) < 1e-9:
        return None
    t = ((c - a).x * s2.y - (c - a).y * s2.x) / den
    u = ((c - a).x * r.y - (c - a).y * r.x) / den
    return (a + r * t, r) if 0 <= t <= 1 and 0 <= u <= 1 else None


def layout():
    PLACE.clear(); MARKERS.clear()
    ring = lambda r, a: (PLAZA_C.x + math.cos(math.radians(a)) * r, PLAZA_C.y + math.sin(math.radians(a)) * r)
    # --- plaza ------------------------------------------------------------------------
    put("plaza/small_fountain", 0, 0, 0, tags=("prop", "blocker"), name="Fountain", zone="plaza", scale=1.55)
    for a in (45, 135, 225, 315):                       # benches facing the fountain
        x, y = ring(4.4, a)
        put("plaza/bench", x, y, face(x, y, 0, 0) + 180, tags=("prop", "blocker"), zone="plaza")
    for a in range(0, 360, 30):                         # ring of trees and flower beds inside the rim
        x, y = ring(7.4, a)
        if a % 90 == 0:
            continue                                    # keep the four spokes open
        if a % 60 == 30:
            put("nature_dock/small_tree_bed", x, y, RNG.uniform(0, 360), tags=("tree", "blocker"), zone="plaza")
        else:
            put("plaza/rect_planter", x, y, face(x, y, 0, 0), zone="plaza")
    for a in range(22, 360, 45):
        x, y = ring(PLAZA_R - 0.45, a)
        put("plaza/lantern_post", x, y, 0, tags=("light", "blocker"), zone="plaza")
    mark("Spawn", 0, -3.0, 180)
    mark("BusArrival", 2.2, -5.2, 200)
    mark("BusStop", 3.4, -7.3, 200, kind="bus")
    # --- cinema, cafe, arcade -------------------------------------------------------------
    building("cinema/cinema_exterior", CINEMA_P.x, CINEMA_P.y, 0, "Cinema", "cinema_lobby", "plaza")
    building("cafe/cafe_exterior", CAFE_P.x, CAFE_P.y, face(CAFE_P.x, CAFE_P.y, 0, 0) * 0.8, "Cafe", "cafe_interior", "plaza")
    building("arcade/arcade_exterior", ARCADE_P.x, ARCADE_P.y, face(ARCADE_P.x, ARCADE_P.y, 0, 0) * 0.8, "Arcade",
             "arcade_interior", "plaza")
    building("casino/casino_exterior", CASINO_P.x, CASINO_P.y, 0, "Casino", "casino_interior", "casino")
    for dx in (-2.6, 2.6):
        put("plaza/lantern_post", CASINO_P.x + dx, CASINO_P.y - 4.6, 0, tags=("light", "blocker"), zone="casino")
        put("plaza/rect_planter", CASINO_P.x + dx * 1.6, CASINO_P.y - 4.2, 0, zone="casino")
    cx, cy = CINEMA_P
    put("plaza/string_lights", cx - 2.2, cy - 5.4, 0, z=2.4, tags=("light",), zone="plaza")
    put("plaza/string_lights", cx + 2.2, cy - 5.4, 0, z=2.4, tags=("light",), zone="plaza")
    put("cinema/poster_frame_a", cx - 4.2, cy - 5.0, 0, zone="plaza")
    put("cinema/poster_frame_b", cx + 4.2, cy - 5.0, 0, zone="plaza")
    for (x, y, yaw) in [(-5.4, 10.6, 20), (-9.8, 9.8, -15), (-4.2, 13.6, 40)]:   # cafe terrace
        put("plaza/cafe_umbrella_table", x, y, yaw, tags=("prop", "blocker"), zone="plaza")
    put("plaza/aframe_chalkboard", -4.6, 9.0, 30, zone="plaza")
    put("plaza/flower_pot", -11.0, 11.4, 0, zone="plaza")
    put("world_misc/crate", 6.6, 10.4, 15, tags=("prop", "blocker"), zone="plaza")
    put("world_misc/barrel", 14.0, 11.0, 0, tags=("prop", "blocker"), zone="plaza")
    put("arcade/arcade_chalkboard", 6.0, 9.4, -30, zone="plaza")
    put("world_misc/signpost", 4.0, -10.4, -30, tags=("prop", "blocker"), zone="plaza")
    put("world_misc/notice_board", -4.2, -10.6, 20, tags=("prop", "blocker"), zone="plaza")
    put("plaza/street_bin", 2.0, -10.2, 0, zone="plaza")
    # --- homes (west street grid) -----------------------------------------------------------
    put("world_misc/homes_arch", -11.6, 0, 90, tags=("building", "blocker"), name="HomesArch", zone="homes")
    mark("HomesGate", -12.6, 0, 90, kind="door", target="home")
    homes = [("cottage/cottage_exterior", -29.25, 4.75, 0, {"roof": "#E86D58"}),
             ("homes/round_cottage_exterior", -17.75, 4.75, 0, {"roof": "#207D85"}),
             ("homes/snow_dome_exterior", -29.25, -4.75, 180, {}),
             ("cottage/cottage_exterior", -17.75, -4.75, 180, {"roof": "#2F8F94"})]
    for i, (asset, x, y, yaw, tn) in enumerate(homes):
        building(asset, x, y, yaw, f"Home{i}", "home", "homes", tints=tn)
        sx = 1 if yaw == 0 else -1
        put("world_misc/mailbox", x + 3.0, y - 3.4 * sx, yaw, zone="homes")
        for k in range(3):                              # garden fence along the back of the lot
            put("plaza/low_wood_fence_2m", x - 2.2 + k * 2.2, y + 3.9 * sx, 0, tags=("prop", "blocker"), zone="homes")
        put("nature_dock/shrub_flowering", x - 3.4, y - 2.6 * sx, RNG.uniform(0, 360), tags=("decor",), zone="homes")
        put("nature_dock/flower_clump", x + 3.6, y + 1.2 * sx, RNG.uniform(0, 360), tags=("decor",), zone="homes")
    # --- stream: waterfalls at the spring and at the mouth; bridges at every path crossing -----
    put("world_misc/waterfall_step", STREAM[0].x, STREAM[0].y - 2.6, 0, z=0.15, zone="stream")
    put("world_misc/waterfall_step", STREAM[-2].x + 0.3, STREAM[-2].y - 4.5, 0, z=-0.6, zone="stream")
    for c, yaw in BRIDGES:
        put("world_misc/footbridge", c.x, c.y, yaw, z=0.0, tags=("prop", "walkable"), name="Bridge", zone="stream")
    for c, yaw in BRIDGE_LANDINGS:                       # landings ramp the 0.3 m bridge ends down to the paving
        put("town_connections/footbridge_approach_landing", c.x, c.y, yaw, z=0.0, tags=("prop", "walkable"), zone="stream")
    # --- cove: two piers and a boathouse platform; decks start flush with the shore path ---------
    DOCK_HEADS.clear()

    def pier(x, y0, n, end_spot=True):
        z = height(Vector((x, y0 + 1.35))) + 0.07          # shore paving top at the pier's land end
        tiles = []
        for k in range(n):
            put("nature_dock/dock_straight", x, y0 - 2 * k, 0, z=z, tags=("prop", "walkable"), zone="dock")
            tiles.append(PLACE[-1])
        DOCK_HEADS.append((tiles[0], Vector((0, -1))))
        if end_spot:
            put("fishing/fishing_dock_spot", x, y0 - 2 * n, 0, z=z, tags=("prop", "walkable"), zone="dock")
        return z
    zA = pier(-24.0, -14.8, 3)
    for x in (-26.0, -28.0):
        for y in (-16.8, -18.8):
            put("nature_dock/dock_straight", x, y, 90, z=zA, tags=("prop", "walkable"), zone="dock")
    put("cottage/cottage_exterior", -27.0, -17.8, 90, z=zA + 0.06, tags=("building", "blocker"), name="Boathouse",
        zone="dock", scale=0.7)
    zB = pier(-12.0, -14.5, 4, end_spot=False)
    put("fishing/fishing_dock_spot", -12.0, -22.5, 0, z=zB, tags=("prop", "walkable"), zone="dock")
    put("nature_dock/dock_straight", -14.0, -22.5, 90, z=zB, tags=("prop", "walkable"), zone="dock")
    put("fishing/fishing_dock_spot", -16.0, -22.5, 90, z=zB, tags=("prop", "walkable"), zone="dock")
    DOCK_Z.update(A=zA, B=zB)
    put("fishing/rowboat", -9.4, -20.4, 75, z=WATER_Z, zone="dock")
    put("fishing/rowboat", -21.0, -24.0, -20, z=WATER_Z, zone="dock")
    put("fishing/life_ring", -11.05, -16.5, 90, z=zB + 0.3, zone="dock")
    put("fishing/bucket_fish", -11.35, -18.0, 0, z=zB + 0.06, zone="dock")
    put("fishing/tackle_crate", -23.3, -16.3, 20, z=zA + 0.06, zone="dock")
    put("nature_dock/rope_posts_bunting", -12.0, -13.6, 0, z=zB, zone="dock")
    for (x, y) in [(-11.6, -26.0), (-19.0, -28.0), (-27.0, -26.5), (-8.6, -18.0)]:
        put("fishing/bobber", x, y, 0, z=WATER_Z, zone="dock")
    n = 0
    for q in [q for q in PLACE if q["id"] == "fishing/fishing_dock_spot"]:
        for sk in ("socket_fish_0", "socket_fish_1"):
            w = socket_world(q["id"], sk, q["pos"][0], q["pos"][1], q["yaw"], q["pos"][2])
            if w:
                mark(f"FishingSpot{n}", w[0], w[1], q["yaw"] + 180, kind="activity", activity="fishing", z=w[2])
                n += 1
    # --- south pier ----------------------------------------------------------------------------
    zS = height(Vector((1.7, -29.0 + 0.35))) + 0.07
    for k in range(4):
        put("nature_dock/dock_straight", 1.7, -30.3 - 2 * k, 0, z=zS, tags=("prop", "walkable"), zone="pier")
        if k == 0:
            DOCK_HEADS.append((PLACE[-1], Vector((0, -1))))
    put("fishing/fishing_dock_spot", 1.7, -38.3, 0, z=zS, tags=("prop", "walkable"), zone="pier")
    # --- basketball: full court from two halves ------------------------------------------------------
    put("activities/basketball_court_half", COURT_C.x - 3.85, COURT_C.y, -90, z=0.0, tags=("prop", "walkable"), name="CourtWest", zone="court")
    put("activities/basketball_court_half", COURT_C.x + 3.85, COURT_C.y, 90, z=0.0, tags=("prop", "walkable"), name="CourtEast", zone="court")
    put("activities/basketball_hoop", COURT_C.x - 8.45, COURT_C.y, -90, tags=("prop", "blocker"), zone="court")
    put("activities/basketball_hoop", COURT_C.x + 8.45, COURT_C.y, 90, tags=("prop", "blocker"), zone="court")
    put("activities/scoreboard", COURT_C.x, COURT_C.y + 6.2, 0, tags=("prop", "blocker"), zone="court")
    put("activities/ball_rack", COURT_C.x - 4.0, COURT_C.y + 5.4, 0, tags=("prop", "blocker"), zone="court")
    for x in (-2.0, 2.0):
        put("plaza/bench", COURT_C.x + x, COURT_C.y - 5.6, 0, tags=("prop", "blocker"), zone="court")
    for k in range(-3, 4):
        put("activities/low_boundary_fence", COURT_C.x + k * 2.2, COURT_C.y - 4.9, 0, tags=("prop",), zone="court")
    mark("CourtEntry", COURT_C.x - 6.0, COURT_C.y + 4.6, 180, kind="activity", activity="basketball")
    # --- sketch club ---------------------------------------------------------------------------
    put("activities/sketch_pavilion", SKETCH_C.x, SKETCH_C.y, 90, z=SKETCH_Z, tags=("building", "blocker"), name="SketchClub", zone="sketch")
    put("activities/communal_table", SKETCH_C.x, SKETCH_C.y, 0, z=SKETCH_Z, tags=("prop", "blocker"), zone="sketch")
    put("activities/easel_display", SKETCH_C.x + 3.6, SKETCH_C.y + 2.4, -120, zone="sketch")
    put("world_misc/notice_board_club", SKETCH_C.x - 3.4, SKETCH_C.y + 3.4, 150, tags=("prop", "blocker"), zone="sketch")
    mark("SketchEntry", SKETCH_C.x - 3.6, SKETCH_C.y, -90, kind="activity", activity="sketch")
    # --- snowball arena --------------------------------------------------------------------------
    put("winter/snowball_arena_blockout", ARENA_C.x - 6.7, ARENA_C.y - 5.4, 0, z=ARENA_Z, tags=("prop",), name="SnowballArena", zone="arena")
    for k, x in enumerate((-4.0, 4.0)):
        put("winter/spectator_bench_snow", ARENA_C.x + x, ARENA_C.y - 7.2, 180, z=ARENA_Z, tags=("prop", "blocker"), zone="arena")
    mark("ArenaGate", 24.7, 18.8, 0, kind="activity", activity="snowballs", z=ARENA_Z)
    # --- sled course: gate + start light + queue on the plateau, checkpoints, finish, stop area -----
    def at_s(sv, lat=0.0):
        i = min(range(len(_S)), key=lambda k: abs(_S[k] - sv))
        t, n = track_frame(i)
        q = TRACK[i] + n * lat
        return q, math.degrees(math.atan2(t.y, t.x)), i
    g, gyaw, gi = at_s(1.6)
    put("winter/start_gate", g.x, g.y, gyaw + 90, z=TRACK_TOP, zone="sled", name="SledGate")
    q, _, _ = at_s(1.6, TRACK_W * 0.5 + TRACK_LIP + 0.6)
    put("interaction_props/start_light", q.x, q.y, gyaw + 90, z=TRACK_TOP, tags=("prop", "blocker"), zone="sled")
    for k, (x, y) in enumerate([(-11.6, 30.4), (-10.7, 30.4), (-11.6, 31.5), (-10.7, 31.5)]):
        put("world_misc/queue_spot_marker", x, y, 0, z=TRACK_TOP + 0.004, zone="sled")
    for x, y, yaw in [(-13.8, 32.4), (-13.0, 32.6)]:
        put("winter/sled", x, y, 100, z=TRACK_TOP, zone="sled")
    for x, y in [(-14.8, 29.6), (-10.0, 29.6), (-14.8, 32.6), (-10.0, 32.6)]:
        put("plaza/lantern_post", x, y, 0, z=TRACK_TOP, tags=("light", "blocker"), zone="sled")
    put("world_misc/activity_sign", -10.2, 28.9, 180, z=TRACK_TOP, tags=("prop", "blocker"), zone="sled")
    for sv in (TRACK_FINISH_S * 0.45, TRACK_FINISH_S * 0.75):
        q, yaw, i = at_s(sv)
        put("interaction_props/checkpoint_posts", q.x, q.y, yaw + 90, z=track_surface_z(i, 0), zone="sled")
    q, fyaw, fi = at_s(TRACK_FINISH_S)
    put("winter/finish_flags", q.x, q.y, fyaw + 90, z=track_surface_z(fi, 0), zone="sled")
    q2, _, _ = at_s(TRACK_FINISH_S - 0.8, -(TRACK_W * 0.5 + TRACK_LIP + 1.4))
    put("interaction_props/finish_timer", q2.x, q2.y, fyaw + 90, tags=("prop", "blocker"), zone="sled")
    e, eyaw, ei = at_s(TRACK_LEN)
    t, n = track_frame(len(TRACK) - 1)
    for k, lat in enumerate((-2.4, -0.8, 0.8, 2.4)):     # soft snowbanks catch sleds at the end
        q = e + t * 1.4 + n * lat
        put(["winter/snowbank_large", "winter/snowbank_medium"][k % 2], q.x, q.y, eyaw + 90 + RNG.uniform(-12, 12),
            tags=("prop", "blocker"), zone="sled")
    mark("SledStart", g.x, g.y, gyaw + 90, kind="activity", activity="sled", z=TRACK_TOP + 0.05)
    q, _, _ = at_s(TRACK_LEN - 2.0)
    mark("SledFinish", q.x, q.y, eyaw + 90, kind="activity", activity="sled_finish")
    # edges: snow fence on the outer side, fence + lanterns on the inner side, berm snowbanks at bends
    sv = TRACK_FLAT_START + 1.0
    while sv < TRACK_LEN - 1.0:
        q0, yaw, i = at_s(sv)
        t, n = track_frame(i)
        half = TRACK_WIDTH[i] * 0.5 + TRACK_LIP + 0.35
        for sgn in (1, -1):
            q = q0 + n * sgn * half
            put("winter/snow_fence_2m", q.x, q.y, yaw, z=track_surface_z(i, sgn * (half - 0.35)) + 0.2,
                tags=("prop", "blocker"), zone="sled")
        if abs(TRACK_BANK[i]) > 0.12 and int(sv) % 4 == 0:
            q = q0 + n * (1 if TRACK_BANK[i] > 0 else -1) * (half + 1.0)
            put("winter/snowbank_medium", q.x, q.y, yaw, tags=("decor",), zone="sled")
        if int(sv) % 7 == 0:
            q = q0 + n * (half + 1.1)
            put("plaza/lantern_post", q.x, q.y, 0, tags=("light", "blocker"), zone="sled")
        sv += 2.2
    # --- stairs: modules chained foot-to-top (no gaps), plus the mid landing ---------------------
    for c in STAIR_CHAINS:
        u = c["dir"]
        yaw = math.degrees(math.atan2(-u.x, u.y))       # module local +Y climbs along u
        for q, z in c["mods"]:
            put("winter/stone_stairs_snow", q.x, q.y, yaw, z=z, tags=("prop", "walkable"), zone="stairs")
    # --- path edges: lantern pairs every ~9 m, set just outside the paving ---------------------------
    LANT = 0.17                                           # lantern post half-width
    for pts, w in PATHS:
        for u, v in zip(pts, pts[1:]):
            u, v = Vector(u), Vector(v)
            d = v - u
            L = d.length
            n = Vector((-d.y, d.x)) / L
            t = 4.5
            while t < L - 1.5:
                for sgn in (1, -1):
                    q = u + d * (t / L) + n * sgn * (w * 0.5 + LANT + 0.05)
                    if (q - PLAZA_C).length > PLAZA_R + 1.0 and stream_d(q) > STREAM_W + 0.8 and island_d(q) < -1.2:
                        put("plaza/lantern_post", q.x, q.y, 0, tags=("light", "blocker"), auto=True)
                t += 9.0
    dress()
    # --- coast: cliff modules where the ground meets the sea, big snowy rocks elsewhere ---
    keep_out = KeepOut((Vector((p["pos"][0], p["pos"][1])), 4.2 if "building" in p["tags"] else 1.2) for p in PLACE)
    coast = []
    for k in range(720):
        a = 2 * math.pi * k / 720
        dirv = Vector((math.cos(a), math.sin(a)))
        r = 10.0
        while r < 70 and island_d(Vector((0, 1.3)) + dirv * r) < 0:
            r += 0.25
        coast.append(Vector((0, 1.3)) + dirv * (r - 0.9))
    last = None
    for p in coast:
        if last is not None and (p - last).length < 1.95:
            continue
        nx = (Vector((p.x + 0.1, p.y)) - Vector((p.x - 0.1, p.y)))
        g = Vector((island_d(Vector((p.x + 0.1, p.y))) - island_d(Vector((p.x - 0.1, p.y))),
                    island_d(Vector((p.x, p.y + 0.1))) - island_d(Vector((p.x, p.y - 0.1))))).normalized()
        yaw = math.degrees(math.atan2(g.x, -g.y))          # module front (-Y) faces the sea
        z = height(p - g * 0.8)
        if on_beach(p) or stream_d(p) < 3.0 or abs(p.x - 1.7) < 2.0 and p.y < -25:
            last = p
            continue
        if z > 0.6:
            put("town_connections/cliff_straight_2m", p.x, p.y, yaw, z=z - 2.05, tags=("rock", "blocker", "coast"))
            if len(PLACE) % 3 == 0:
                put("town_connections/cliff_cap", p.x, p.y, yaw, z=z + 0.02, tags=("rock",))
            else:
                put("town_connections/snow_overlay_cliff_straight", p.x, p.y, yaw, z=z + 0.02, tags=("decor",))
        o = p + g * RNG.uniform(0.4, 1.2)                  # big snowy boulders along the waterline
        put(["nature_dock/rock_cluster_snow", "winter/rock_cluster_snow_large", "nature_dock/rock_cluster_snow"][RNG.randrange(3)],
            o.x, o.y, RNG.uniform(0, 360), z=WATER_Z - 0.45, tags=("rock", "blocker", "coast"), scale=RNG.uniform(1.5, 2.4))
        keep_out.append((p, 1.6))
        last = p
    # --- groves: firs in clusters with snowy rocks, leaving open snow lawns -----------
    firs = ["winter/fir_tree_small", "winter/fir_tree_medium", "winter/fir_tree_large"]

    def free_spot(p, r=1.3):
        d = island_d(p)
        if d > -2.2 or on_path(p) or (p - PLAZA_C).length < PLAZA_R + 1.0 or track_nearest(p)[0] < TRACK_W * 0.5 + TRACK_LIP + 2.0:
            return False
        if stream_d(p) < STREAM_W + 1.2 or on_beach(p):
            return False
        if (abs(p.x - ARENA_C.x) < ARENA_HALF.x + 1 and abs(p.y - ARENA_C.y) < ARENA_HALF.y + 1) or \
                (abs(p.x - COURT_C.x) < 10.5 and abs(p.y - COURT_C.y) < 7.0) or (p - SKETCH_C).length < 5.5 or \
                (abs(p.x - CASINO_P.x) < 5.2 and abs(p.y - CASINO_P.y) < 5.4):
            return False
        if abs(p.x - SLED_STAIRS[0].x) < 1.6 and SLED_STAIRS[0].y - 0.5 < p.y < SLED_STAIRS[1].y + 0.5:
            return False
        if any(seg_dist(p, u, v) < w * 0.5 + 0.9 for pts, w in PATHS for u, v in zip(pts, pts[1:])):
            return False
        return not keep_out.blocked(p, r)
    def density(p):
        """0..1 tree density: thick on the coast ring and in the woodland belts between districts."""
        d = island_d(p)
        ring = 1 - smoothstep(-9.0, -4.5, d)                         # 1 near the coast
        belt = 0.0
        for c, r in [(Vector((8.5, 30.0)), 6.0), (Vector((-6.5, 23.0)), 4.5), (Vector((19.0, 16.0)), 4.0),
                     (Vector((-4.0, -18.0)), 5.0), (Vector((16.5, -27.0)), 5.0), (Vector((-34.0, 23.0)), 4.0),
                     (Vector((34.0, 9.0)), 4.5), (Vector((-36.5, -2.0)), 4.0), (Vector((-24.0, 14.5)), 4.0),
                     (Vector((-36.5, 12.0)), 3.5), (Vector((-36.5, -14.0)), 3.5), (Vector((-6.0, -26.0)), 4.0), (Vector((-6.5, 16.0)), 2.5),
                     (Vector((17.5, 0.0)), 3.5), (Vector((-30.0, -14.0)), 3.0)]:
            belt = max(belt, 1 - smoothstep(r * 0.6, r, (p - c).length))
        return max(ring * 0.85, belt) * (0.35 + 0.65 * RNG.random()) + 0.06
    planted = 0
    for _ in range(9000):
        p = Vector((RNG.uniform(-40, 40), RNG.uniform(-36, 38)))
        if RNG.random() > density(p) or not free_spot(p, 1.25):
            continue
        keep_out.append((p, 1.25))
        near_town = min((p - c).length for c in (PLAZA_C, CAFE_P, ARCADE_P, CINEMA_P, CASINO_P, SKETCH_C, Vector((-23.5, 0)))) < 16
        if near_town and RNG.random() < 0.22:
            ok = put(["nature_dock/broad_tree_snow", "nature_dock/small_tree_snow", "nature_dock/broad_tree", "nature_dock/small_tree"][RNG.randrange(4)],
                     p.x, p.y, RNG.uniform(0, 360), tags=("tree",), scale=RNG.uniform(0.9, 1.15), auto=True)
        else:
            ok = put(firs[RNG.randrange(3)], p.x, p.y, RNG.uniform(0, 360), tags=("tree",), scale=RNG.uniform(0.85, 1.2), auto=True)
        if not ok:
            keep_out.h[(int(p.x // 4), int(p.y // 4))].pop()
            keep_out.pop()
            continue
        planted += 1
        if RNG.random() < 0.08:
            q = p + Vector((RNG.uniform(-1.6, 1.6), RNG.uniform(-1.6, 1.6)))
            if free_spot(q, 1.0):
                keep_out.append((q, 1.0))
                put(["nature_dock/rock_small_a_snow", "winter/rock_cluster_snow_small"][RNG.randrange(2)], q.x, q.y,
                    RNG.uniform(0, 360), tags=("rock",), scale=RNG.uniform(0.8, 1.3), auto=True)
    print("FIRS", planted)
    for _ in range(40):  # scattered shrubs and flower clumps on the lawns
        p = Vector((RNG.uniform(-36, 36), RNG.uniform(-24, 30)))
        if free_spot(p, 1.0):
            keep_out.append((p, 1.0))
            put(["nature_dock/shrub_round", "nature_dock/shrub_flowering", "nature_dock/shrub_small"][RNG.randrange(3)],
                p.x, p.y, RNG.uniform(0, 360), tags=("decor",), auto=True)
    for _ in range(80):  # rocks in the water
        a = RNG.uniform(0, 2 * math.pi)
        p = Vector((math.cos(a) * RNG.uniform(41, 54), 1.3 + math.sin(a) * RNG.uniform(38, 50)))
        if island_d(p) < 1.5:
            continue
        put(["nature_dock/rock_cluster_snow", "nature_dock/rock_small_a_snow", "nature_dock/rock_small_b_snow"][RNG.randrange(3)],
            p.x, p.y, RNG.uniform(0, 360), z=WATER_Z - 0.3, tags=("rock", "coast"), scale=RNG.uniform(1.0, 2.4))
    for x, y in [(-6.6, -6.0), (7.0, -6.2), (-9.6, -2.6), (10.0, -1.8)]:
        put("nature_dock/broad_tree_bed", x, y, RNG.uniform(0, 360), tags=("tree", "blocker"), zone="plaza")


def nudge(x, y, clear=0.4):
    """Nearest point to (x, y) that is off every path (props never stand in a walk lane)."""
    p = Vector((x, y))
    if not any(poly_dist(p, pts) < w * 0.5 + clear for pts, w in PATHS) and (p - PLAZA_C).length > PLAZA_R + clear or \
            ((p - PLAZA_C).length < PLAZA_R - 1.5 and not any(poly_dist(p, pts) < w * 0.5 + clear for pts, w in PATHS)):
        return p
    for r in (0.5, 1.0, 1.5, 2.0, 2.5, 3.0):
        for k in range(12):
            q = p + Vector((math.cos(k * math.pi / 6), math.sin(k * math.pi / 6))) * r
            if not any(poly_dist(q, pts) < w * 0.5 + clear for pts, w in PATHS) and (q - PLAZA_C).length > PLAZA_R + clear:
                return q
    return p


def sign_at(x, y, icon, toward):
    """Activity sign with its icon decal, facing a path point."""
    q = nudge(x, y, 0.5)
    yaw = face(q.x, q.y, toward[0], toward[1])
    z = height(q)
    put("world_misc/activity_sign", q.x, q.y, yaw, z=z, tags=("prop", "blocker"))
    if icon:
        w = socket_world("world_misc/activity_sign", "socket_icon", q.x, q.y, yaw, z)
        if w:
            put(f"world_misc/{icon}", w[0], w[1], yaw, z=w[2], tags=("decor",))


def dress():
    """Deliberate placement of the outdoor kit: every prop in its intended spot (see unused_props.py)."""
    # plaza: map board facing the spawn, string lights across the W/E/S approaches, bunting on the rim
    put("world_misc/world_map_board", -3.4, -7.9, 180, tags=("prop", "blocker"), zone="plaza", name="MapBoard")
    put("plaza/string_lights", -PLAZA_R - 0.6, 0, 90, z=height(Vector((-PLAZA_R, 0))) + 2.4, tags=("light",), zone="plaza")
    put("plaza/string_lights", PLAZA_R + 0.6, 0, 90, z=2.4, tags=("light",), zone="plaza")
    put("plaza/string_lights", 0, -PLAZA_R - 0.6, 0, z=2.4, tags=("light",), zone="plaza")
    for a in (45, 135, 225, 315):
        x, y = PLAZA_C.x + math.cos(math.radians(a)) * (PLAZA_R - 0.9), PLAZA_C.y + math.sin(math.radians(a)) * (PLAZA_R - 0.9)
        put("plaza/bunting_posts", x, y, a + 90, zone="plaza")
    # cafe terrace: round tables with four stools each
    for (x, y, yaw) in [(-10.6, 8.4, 10), (-2.6, 11.4, -15)]:
        put("plaza/round_table", x, y, yaw, tags=("prop", "blocker"), zone="plaza")
        for k in range(4):
            w = socket_world("plaza/round_table", f"socket_seat_{k}", x, y, yaw)
            if w:
                put("plaza/stool", w[0], w[1], yaw + 45 + 90 * k, zone="plaza")
    # cinema: entrance topiaries, stanchion queue along the door approach, queue spots
    cx, cy = CINEMA_P
    for dx in (-2.7, 2.7):
        put("cinema/cinema_topiary", cx + dx, cy - 4.6, 0, tags=("prop", "blocker"), zone="plaza")
    for dx in (-0.85, 0.85):
        ys = [cy - 5.2 - 1.25 * k for k in range(4)]
        for y in ys:
            put("cinema_lobby/stanchion", cx + dx, y, 0, tags=("prop",), zone="plaza")
        for y0, y1 in zip(ys, ys[1:]):
            put("cinema_lobby/stanchion_rope", cx + dx, (y0 + y1) / 2, 90, tags=("decor",), zone="plaza")
    for k in range(4):
        w = socket_world("cinema/cinema_exterior", f"socket_queue_{k}", cx, cy, 0)
        if w:
            put("world_misc/queue_spot_marker", w[0], w[1], 0, z=height(Vector((w[0], w[1]))) + 0.004, tags=("decor",), zone="plaza")
    # arcade: bench out front, the standalone two-player deck, queue spots by the door
    ayaw = face(ARCADE_P.x, ARCADE_P.y, 0, 0) * 0.8
    put("arcade/arcade_bench", 13.6, 9.0, face(13.6, 9.0, 0, 0) + 180, tags=("prop", "blocker"), zone="plaza")
    put("interaction_props/double_control_deck", 7.2, 11.4, face(7.2, 11.4, 0, 0), tags=("prop", "blocker"), zone="plaza")
    d = socket_world("arcade/arcade_exterior", "socket_door", ARCADE_P.x, ARCADE_P.y, ayaw)
    if d:
        for k in (1, 2):
            put("world_misc/queue_spot_marker_stone", d[0] - 0.9 * k * math.sin(math.radians(ayaw)), d[1] + 0.9 * k * math.cos(math.radians(ayaw)) * -1,
                0, tags=("decor",), zone="plaza")
    # casino forecourt queue
    for k in (0, 1):
        put("world_misc/queue_spot_marker_stone", CASINO_P.x - 0.6 + 1.2 * k, CASINO_P.y - 5.2, 0, tags=("decor",), zone="casino")
    # crates and barrels by the shops' side walls (service corners, never the fronts)
    for (x, y) in [(-11.4, 15.6), (-11.0, 16.4), (14.6, 15.4), (14.0, 16.2), (27.6, 10.6), (-27.6, -21.6), (-28.4, -21.2)]:
        q = nudge(x, y)
        put(["world_misc/crate", "world_misc/barrel"][int(abs(x * 3 + y)) % 2], q.x, q.y, RNG.uniform(0, 90),
            tags=("prop", "blocker"))
    # activity signs with icons at each destination entrance
    sign_at(-4.6, 7.2, "icon_cafe", (-6.0, 7.0))
    sign_at(2.6, 15.6, "icon_cinema", (0.0, 15.6))
    sign_at(7.8, 7.4, "icon_arcade", (8.6, 8.6))
    sign_at(-10.0, -9.8, "icon_fishing", (-8.6, -9.8))
    sign_at(-10.8, 17.6, "icon_sled", (-9.4, 18.2))
    sign_at(22.8, 14.2, "icon_snowball", (24.7, 15.0))
    sign_at(18.6, -12.4, "icon_basketball", (19.2, -14.0))
    sign_at(26.4, 1.6, "icon_drawing", (27.0, -0.6))
    # destination signposts at junctions
    for (x, y) in [(-12.6, 1.8), (11.0, -2.0), (-12.4, -10.6), (7.0, 21.2), (31.6, 5.6), (26.6, -13.2), (-8.0, 15.6),
                   (-23.5, -8.4), (-23.5, 8.2)]:
        q = nudge(x, y, 0.5)
        put("world_misc/destination_signpost", q.x, q.y, RNG.uniform(0, 360), tags=("prop", "blocker"))
    # homes: plaques, porches, doorsteps, planters at the door, fence ends with posts, yard trees
    for i, (x, y, yaw) in enumerate([(-29.25, 4.75, 0), (-17.75, 4.75, 0), (-29.25, -4.75, 180), (-17.75, -4.75, 180)]):
        f = Vector((math.sin(math.radians(yaw)), -math.cos(math.radians(yaw))))      # towards the street
        put("world_misc/home_number_plaque", x - 3.6 * (1 if yaw == 0 else -1), y + f.y * 3.3, yaw, tags=("prop",), zone="homes")
        put("plaza/rect_planter", x - 1.7, y + f.y * 3.0, yaw, zone="homes")
        put("plaza/rect_planter", x + 1.7, y + f.y * 3.0, yaw, zone="homes")
        put("plaza/low_wood_fence_1m", x + 3.9, y + f.y * -3.9, 90, tags=("prop", "blocker"), zone="homes")
        for dx in (-3.4, 3.4):
            put("plaza/low_wood_fence_post", x + dx, y - f.y * 3.9, 0, tags=("prop",), zone="homes")
        put(["nature_dock/small_tree_snow", "nature_dock/broad_tree_snow"][i % 2], x + 3.4 * (1 if i % 2 else -1), y - f.y * 2.8,
            RNG.uniform(0, 360), tags=("tree", "blocker"), zone="homes")
        put("nature_dock/leaf_tuft", x - 3.0, y - f.y * 1.4, RNG.uniform(0, 360), tags=("decor",), zone="homes")
    for i, (asset, x, y, yaw) in enumerate([("cottage/cottage_exterior", -29.25, 4.75, 0), ("cottage/cottage_exterior", -17.75, -4.75, 180)]):
        dsk = socket_world(asset, "socket_door", x, y, yaw, height(Vector((x, y))))
        if dsk:
            f = Vector((math.sin(math.radians(yaw)), -math.cos(math.radians(yaw))))
            put("building_finishing/doorstep_threshold", dsk[0] - f.x * 0.5, dsk[1] - f.y * 0.5, yaw, zone="homes")
            put("building_finishing/porch_canopy", dsk[0] - f.x * 0.62, dsk[1] - f.y * 0.62, yaw, z=dsk[2], tags=("prop",), zone="homes")
    # landmark homes: treehouse + A-frame on the north street, lighthouse at the end of the south pier,
    # houseboat moored in the cove
    building("homes/treehouse_exterior", -22.5, 13.6, 180, "Home4", "home", "homes")
    building("homes/aframe_cabin_exterior", -33.0, 13.0, 180, "Home5", "home", "homes", tints={"roof": "#207D85"})
    put("homes/lighthouse_loft_exterior", 1.7, -44.2, 0, z=0.0, tags=("building", "blocker"), name="Lighthouse", zone="pier")
    put("homes/houseboat_exterior", -19.6, -27.4, 160, z=WATER_Z + 0.02, tags=("building", "blocker"), name="Houseboat", zone="dock")
    # cove: quay wall along the north shore, rope rails on the piers, catch stand + bucket + fish, mooring post
    zA, zB = DOCK_Z["A"], DOCK_Z["B"]
    for x in (-21.5, -19.5, -17.5, -15.5):
        put("nature_dock/water_edge_2m", x, -14.4, 0, z=height(Vector((x, -13.2))) - 0.88, tags=("rock", "blocker", "coast"), zone="dock")
    for y in (-14.8, -16.8, -18.8):
        put("nature_dock/rope_posts", -22.95, y, 90, z=zA, zone="dock")
    for y in (-14.5, -16.5, -18.5, -20.5):
        put("nature_dock/rope_posts", -10.95, y, 90, z=zB, zone="dock")
    put("nature_dock/dock_corner", -28.0, -20.8, 0, z=zA, tags=("prop", "walkable"), zone="dock")
    put("interaction_props/catch_display_stand", -24.75, -18.8, 90, z=zA + 0.06, tags=("prop", "blocker"), zone="dock")
    put("fishing/bucket", -23.35, -18.2, 0, z=zA + 0.06, zone="dock")
    for k, fish in enumerate(("fishing/fish_round", "fishing/fish_slim")):
        put(fish, -23.35, -19.0 - 0.4 * k, RNG.uniform(0, 360), z=zA + 0.1, zone="dock")
    put("interaction_props/mooring_post", -9.4, -14.6, 0, tags=("prop", "blocker"), zone="dock")
    for (x, y) in [(-11.6, -26.0), (-19.0, -28.0), (-27.0, -26.5), (-8.6, -18.0)]:
        put("fishing/ripple", x, y, 0, z=WATER_Z + 0.01, tags=("decor",), zone="dock")
    # south pier head: quay edging either side of the pier
    for x in (-0.4, -2.4, 3.8, 5.8):
        put("plaza/plaza_edge_2m", x, -29.6, 0, z=height(Vector((x, -29.0))) - 0.88, tags=("prop", "blocker", "coast"), zone="pier")
    put("plaza/plaza_edge_corner", -3.8, -29.6, 0, z=height(Vector((-3.8, -29.0))) - 0.88, tags=("prop", "coast"), zone="pier")
    put("plaza/plaza_edge_1m", 7.3, -29.6, 0, z=height(Vector((7.3, -29.0))) - 0.88, tags=("prop", "coast"), zone="pier")
    # basketball: gate in the north fence, shooting spots, ready marker, rack with balls, gear crate
    cxx, cyy = COURT_C
    put("activities/court_gate", cxx - 6.0, cyy + 4.5, 0, tags=("prop",), zone="court")
    for k in range(-3, 4):
        if abs(cxx + k * 2.2 - (cxx - 6.0)) > 1.4:
            put("activities/low_boundary_fence", cxx + k * 2.2, cyy + 4.9, 0, tags=("prop",), zone="court")
    for k in range(4):
        w = socket_world("activities/basketball_court_half", f"socket_shoot_{k}", cxx - 3.85, cyy, -90, 0.0)
        if w:
            put("activities/shooting_spot", w[0], w[1], -90, z=0.065, tags=("decor",), zone="court")
    put("activities/ready_marker", cxx - 5.2, cyy + 3.2, 0, z=0.065, tags=("decor",), zone="court")
    for k in range(3):
        put("activities/basketball", cxx - 4.4 + k * 0.4, cyy + 5.4, 0, z=0.82, tags=("decor",), zone="court")
    put("activities/gear_crate", cxx - 2.8, cyy + 5.6, 15, tags=("prop", "blocker"), zone="court")
    # sketch club: a second, outdoor drawing table by the pavilion
    tx, ty = SKETCH_C.x + 2.2, SKETCH_C.y - 5.6
    put("activities/sketch_table", tx, ty, 0, tags=("prop", "blocker"), zone="sketch")
    for k in range(6):
        w = socket_world("activities/sketch_table", f"socket_seat_{k}", tx, ty, 0)
        if w:
            put("activities/sketch_stool", w[0], w[1], 0, zone="sketch")
    put("activities/table_lantern", tx, ty, 0, z=0.76, tags=("decor",), zone="sketch")
    for k, item in enumerate(("activities/drawing_pad", "activities/pencil_cup", "activities/drawing_pad")):
        put(item, tx - 0.6 + 0.6 * k, ty + 0.25, RNG.uniform(-20, 20), z=0.76, tags=("decor",), zone="sketch")
    put("activities/easel_board", tx + 2.6, ty + 0.4, -90, tags=("prop", "blocker"), zone="sketch")
    # snowball arena: team flags, ready pads, snowball pile, respawn pads, scoreboard, snow walls outside
    ax, ay = ARENA_C.x - 6.7, ARENA_C.y - 5.4
    for team, col in (("coral", "#E86D58"), ("teal", "#207D85")):
        w = socket_world("winter/snowball_arena_blockout", f"socket_ready_{team}_0", ax, ay, 0, ARENA_Z)
        if w:
            put("winter/ready_pad", w[0], w[1] - 1.6, 0, z=ARENA_Z, tints={"team": col}, zone="arena")
            put("interaction_props/respawn_pad", w[0] + (-2.2 if team == "coral" else 2.2), w[1] - 1.8, 0, z=ARENA_Z,
                tints={"team": col}, zone="arena")
    put("winter/team_flag", ax - 0.6, ay + 8.6, 0, z=ARENA_Z, tints={"team": "#E86D58"}, zone="arena")
    put("winter/team_flag", ax + 12.6, ay + 8.6, 0, z=ARENA_Z, tints={"team": "#207D85"}, zone="arena")
    put("interaction_props/match_scoreboard", ax + 6.0, ay - 2.4, 0, z=ARENA_Z, tags=("prop", "blocker"), zone="arena")
    w = socket_world("winter/snowball_arena_blockout", "socket_snowball_pile", ax, ay, 0, ARENA_Z)
    if w:
        put("winter/snowball_pile", w[0], w[1], 0, z=ARENA_Z, zone="arena")
    for k in range(4):
        put("winter/snow_wall_straight", ax - 1.4, ay + 1.0 + 2.1 * k, 90, z=ARENA_Z, tags=("prop", "blocker"), zone="arena")
    put("winter/snow_wall_corner", ax - 1.4, ay - 0.6, 0, z=ARENA_Z, tags=("prop", "blocker"), zone="arena")
    put("winter/snow_bank_cover", ax + 13.8, ay + 3.2, 0, z=ARENA_Z, tags=("prop", "blocker"), zone="arena")
    put("winter/snow_puff", ax + 2.0, ay - 1.8, 0, z=ARENA_Z + 0.1, tags=("decor",), zone="arena")
    put("winter/snow_fence_1m", ax + 13.6, ay - 1.2, 90, z=ARENA_Z, tags=("prop", "blocker"), zone="arena")
    # arena plateau: rock cliff faces on the south and west edges
    for k in range(7):
        x = ARENA_C.x - ARENA_HALF.x + 1.0 + 2.1 * k
        if abs(x - 24.7) > 1.6:
            put(["town_connections/cliff_straight_2m", "town_connections/cliff_straight_1m"][k % 2], x,
                ARENA_C.y - ARENA_HALF.y - 0.9, 0, z=ARENA_Z - (2.05 if k % 2 == 0 else 1.0), tags=("rock", "blocker"), zone="arena")
    # stream: rail segments along the banks beside the plaza, a spring end and a mouth end
    for c0, c1 in zip(STREAM[3:6], STREAM[4:7]):
        d = c1 - c0
        L = d.length
        n = Vector((-d.y, d.x)) / L
        t = 1.0
        while t < L - 1.0:
            for sgn in (1, -1):
                q = c0 + d * (t / L) + n * sgn * (STREAM_W + 0.9)
                if all(poly_dist(q, pts) > w * 0.5 + 1.2 for pts, w in PATHS):
                    put("town_connections/rail_segment", q.x, q.y, math.degrees(math.atan2(d.y, d.x)), tags=("prop", "blocker"), zone="stream")
            t += 2.1
    put("town_connections/stream_end", STREAM[0].x, STREAM[0].y + 0.6, 0, z=0.0, tags=("rock",), zone="stream")
    for c0, c1 in ((STREAM[0], STREAM[1]), (STREAM[-3], STREAM[-2])):
        d = c1 - c0
        n = Vector((-d.y, d.x)).normalized()
        for t in (0.35, 0.65):
            for sgn in (1, -1):
                q = c0 + d * t + n * sgn * (STREAM_W + 0.6)
                put("town_connections/stream_bank", q.x, q.y, math.degrees(math.atan2(d.y, d.x)) + (0 if sgn > 0 else 180),
                    z=height(q) - 0.55, tags=("rock",), zone="stream")
    # sea: ice floes, like the concepts
    for _ in range(40):
        a = RNG.uniform(0, 2 * math.pi)
        q = Vector((math.cos(a) * RNG.uniform(42, 58), 1.3 + math.sin(a) * RNG.uniform(39, 52)))
        if island_d(q) > 2.5:
            put(["fishing/ice_floe_a", "fishing/ice_floe_b", "fishing/ice_floe_c"][RNG.randrange(3)], q.x, q.y,
                RNG.uniform(0, 360), z=WATER_Z - 0.06, tags=("decor",), scale=RNG.uniform(1.0, 2.2))
    # beaches: bare rocks and leaf tufts on the sand
    for _ in range(60):
        q = Vector((RNG.uniform(-14, 34), RNG.uniform(-34, -12)))
        if on_beach(q) and island_d(q) < -0.4:
            put(["nature_dock/rock_cluster", "nature_dock/rock_small_a", "nature_dock/rock_small_b"][RNG.randrange(3)],
                q.x, q.y, RNG.uniform(0, 360), tags=("rock",), scale=RNG.uniform(0.7, 1.3))
    vignettes()


# ----------------------------------------------------------------- export --
def to_godot(v):
    return [round(v[0], 3), round(v[2], 3), round(-v[1], 3)]


def write_layout(path):
    data = {
        "version": 1, "terrain": "world/town_terrain.glb", "water_level": WATER_Z,
        "sun": {"rotation_deg": [-46, -38, 0], "color": "#FFE2B0", "energy": 1.25},
        "placements": [{"id": p["id"], "name": p["name"], "pos": to_godot(p["pos"]), "rot_y_deg": round(p["yaw"], 2),
                        "scale": round(p["scale"], 3), "tints": p["tints"], "tags": p["tags"], "zone": p["zone"]}
                       for p in PLACE],
        "markers": [{**{k: v for k, v in m.items() if k not in ("pos", "yaw")}, "pos": to_godot(m["pos"]),
                     "rot_y_deg": round(m["yaw"], 2)} for m in MARKERS],
        "zones": [{"name": "plaza", "center": to_godot((PLAZA_C.x, PLAZA_C.y, 0)), "radius": PLAZA_R}],
        "concept": {"overhead": "Images/World Map - Overhead Layout.png", "overview": "Images/World Map - Island Overview.png",
                    "metres_per_pixel": S, "origin_px": [575, 580]},
        "camera": {"bounds_min": to_godot((-36, 34, 0))[::2], "bounds_max": to_godot((36, -32, 0))[::2],
                   "pitch_deg": -50, "distance": 18, "fov": 40},
        "nav_blockers": [],
        "sled_track": {"points": [to_godot((q.x, q.y, track_z_at(sv))) for q, sv in zip(TRACK, _S)],
                       "width": [round(w, 2) for w in TRACK_WIDTH],
                       "bank_deg": [round(math.degrees(bk), 1) for bk in TRACK_BANK],
                       "finish_index": min(range(len(_S)), key=lambda k: abs(_S[k] - TRACK_FINISH_S)),
                       "length_m": round(TRACK_LEN, 2)},
    }
    for p in data["placements"]:
        if p["name"] is None:
            del p["name"]
        if p["zone"] is None:
            del p["zone"]
    json.dump(data, open(path, "w"), indent=1)
    return data


def build():
    """Kit entry point (build.py): terrain + paving + water as one asset with three meshes."""
    layout()
    t = build_terrain().finish(KIT, "terrain")
    pav = build_paving().finish(KIT, "terrain")
    w = build_water().finish(KIT, "terrain")
    trk = build_sled_track().finish(KIT, "terrain")
    for o in (pav, w, trk):
        common.ASSETS[:] = [a for a in common.ASSETS if a["obj"] is not o]
        o.parent = t
    t.name = "town_terrain"
    pav.name, w.name, trk.name = "terrain_paving", "water", "terrain_sled_track"
