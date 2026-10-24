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
    ([C(470, 425), C(420, 340), Vector((-10.1, 16.3))], 2.4),           # cafe -> sled stairs foot
    ([C(575, 290), C(700, 230), C(880, 230), Vector((24.7, 15.3))], 2.4),   # cinema -> arena stairs foot
    ([Vector((24.7, 15.3)), Vector((30.4, 12.6)), Vector((30.4, 4.0)), C(1000, 595)], 2.4),  # arena -> east loop -> sketch
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

# broad sled track down the hill (centreline, metres): start gate -> finish
TRACK = [C(400, 92), C(250, 112), C(165, 172), C(152, 262), C(222, 322), C(360, 345)]
TRACK_W = 3.6
SLED_STAIRS = (Vector((-10.1, 16.3)), Vector((-9.6, 29.8)))   # foot -> top, east of the track


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
    """NW hill: rises northward from y=13 to the top plateau at y>=27."""
    d = ellipse_d(p, Vector((-19.5, 24.0)), 13.5, 11.0)
    rise = max(0.0, min(1.0, (p.y - 13.0) / 14.0))
    return HILL_TOP * smoothstep(0, 1, rise) * (1 - smoothstep(-2.5, 0.8, d))


def track_z(at, total):
    """Track height: follows the hill, monotonic from the top to the finish."""
    pts = TRACK
    z0, z1 = hill_h(pts[0]) - 0.15, max(0.35, hill_h(pts[-1]) - 0.1)
    t = at / total
    return z0 + (z1 - z0) * (t ** 0.85)


def height(p):
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
    # sled track: smooth groove with snow berms
    td, at, tot = poly_param(p, TRACK)
    if td < TRACK_W * 0.5 + 1.4:
        tz = track_z(at, tot)
        berm = 0.38 * smoothstep(TRACK_W * 0.5 - 0.2, TRACK_W * 0.5 + 0.5, td) * (1 - smoothstep(TRACK_W * 0.5 + 0.6, TRACK_W * 0.5 + 1.4, td))
        inner = 1 - smoothstep(TRACK_W * 0.5 + 0.4, TRACK_W * 0.5 + 1.4, td)
        h = h * (1 - inner) + (tz + berm) * inner
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
       [(Vector((x, y)), Vector((4.4, 4.0)), 0.0) for x in (-29.25, -17.75) for y in (4.75, -4.75)]


def pad_w(p):
    """(weight 0..1, z) of the strongest pad at p."""
    best, z = 0.0, 0.0
    for c, hx, pz in PADS:
        q = Vector((max(abs(p.x - c.x) - hx.x, 0), max(abs(p.y - c.y) - hx.y, 0))).length
        w = 1 - smoothstep(0.0, 1.0, q)
        if w > best:
            best, z = w, pz
    return best, z


def stair_runs():
    """(foot, top, z at foot, z at top) for every stair flight."""
    a, b = SLED_STAIRS
    return [(a, b, hill_h(a), hill_h(b)),
            (Vector((24.7, 15.3)), Vector((24.7, 18.3)), 0.0, ARENA_Z)]


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
            if island_d(p) < -3.5 and not on_path(p) and poly_dist(p, TRACK) > TRACK_W * 0.5 + 1.5 and stream_d(p) > STREAM_W + 1.5 and pad_w(p)[0] == 0:
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
                    if (p - PLAZA_C).length < PLAZA_R - 0.3 or stream_d(p) < STREAM_W + 0.7:
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
MARKERS = []


def put(asset, x, y, yaw=0.0, z=None, name=None, tags=("prop",), tints=None, scale=1.0, zone=None):
    p = Vector((x, y))
    PLACE.append({"id": asset, "name": name, "pos": (x, y, height(p) if z is None else z), "yaw": yaw,
                  "tags": list(tags), "tints": tints or {}, "scale": scale, "zone": zone})


def mark(name, x, y, yaw=0.0, kind="spawn", z=None, **extra):
    MARKERS.append({"name": name, "pos": (x, y, height(Vector((x, y))) if z is None else z), "yaw": yaw,
                    "kind": kind, **extra})


def face(fx, fy, tx, ty):
    """Yaw so an asset at (fx,fy) faces (tx,ty) (assets face -Y)."""
    return math.degrees(math.atan2(tx - fx, -(ty - fy)))


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
    put("plaza/bunting_posts", 0, PLAZA_R - 1.2, 0, zone="plaza")
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
    for pts, w in PATHS:
        for a, b in zip(pts, pts[1:]):
            for c, d in zip(STREAM, STREAM[1:]):
                hit = intersect(Vector(a), Vector(b), c, d)
                if hit:
                    q, r = hit
                    put("world_misc/footbridge", q.x, q.y, math.degrees(math.atan2(r.y, r.x)), z=0.0,
                        tags=("prop", "walkable"), name="Bridge", zone="stream")
    # --- cove: two piers and a boathouse platform ----------------------------------------------
    for y in (-16.0, -18.0, -20.0):
        put("nature_dock/dock_straight", -24.0, y, 0, z=0.0, tags=("prop", "walkable"), zone="dock")
    for x in (-26.0, -28.0):
        for y in (-18.0, -20.0):
            put("nature_dock/dock_straight", x, y, 90, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("fishing/fishing_dock_spot", -24.0, -22.0, 0, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("cottage/cottage_exterior", -27.0, -19.0, 90, z=0.06, tags=("building", "blocker"), name="Boathouse",
        zone="dock", scale=0.7)
    for y in (-14.5, -16.5, -18.5, -20.5):
        put("nature_dock/dock_straight", -12.0, y, 0, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("fishing/fishing_dock_spot", -12.0, -22.5, 0, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("nature_dock/dock_straight", -14.0, -22.5, 90, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("fishing/fishing_dock_spot", -16.0, -22.5, 90, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("fishing/rowboat", -9.6, -20.4, 75, z=WATER_Z, zone="dock")
    put("fishing/rowboat", -20.6, -24.8, -20, z=WATER_Z, zone="dock")
    put("fishing/life_ring", -13.1, -17.0, 90, z=0.3, zone="dock")
    put("fishing/bucket_fish", -12.6, -21.6, 0, z=0.06, zone="dock")
    put("fishing/tackle_crate", -24.6, -21.2, 20, z=0.06, zone="dock")
    put("nature_dock/rope_posts_bunting", -12.0, -13.6, 0, zone="dock")
    for (x, y) in [(-11.6, -26.0), (-19.0, -28.0), (-27.0, -26.5), (-8.6, -16.4)]:
        put("fishing/bobber", x, y, 0, z=WATER_Z, zone="dock")
    for i, (x, y) in enumerate([(-11.4, -23.2), (-12.8, -23.2), (-16.0, -23.4), (-24.0, -22.8)]):
        mark(f"FishingSpot{i}", x, y, 180, kind="activity", activity="fishing", z=0.06)
    # --- south pier ----------------------------------------------------------------------------
    for k in range(4):
        put("nature_dock/dock_straight", 1.7, -31.0 - 2 * k, 0, z=0.0, tags=("prop", "walkable"), zone="pier")
    put("fishing/fishing_dock_spot", 1.7, -39.0, 0, z=0.0, tags=("prop", "walkable"), zone="pier")
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
    # --- sled hill: broad track with fences, gate at the top, flags at the finish ---------------------
    td_total = poly_param(TRACK[-1], TRACK)[2]
    run, prev = 0.0, None
    for a, b in zip(TRACK, TRACK[1:]):
        d = b - a
        L = d.length
        n = Vector((-d.y, d.x)) / L
        t = 1.0
        while t < L:
            c = a + d * (t / L)
            yaw = math.degrees(math.atan2(d.y, d.x))
            for sgn in (1, -1):
                q = c + n * sgn * (TRACK_W * 0.5 + 0.9)
                put("winter/snow_fence_2m", q.x, q.y, yaw, tags=("prop", "blocker"), zone="sled")
            if int(t) % 6 == 1:
                q = c + n * (TRACK_W * 0.5 + 1.6)
                put("plaza/lantern_post", q.x, q.y, 0, tags=("light", "blocker"), zone="sled")
            t += 2.2
    g0, g1 = TRACK[0], TRACK[1]
    gy = math.degrees(math.atan2((g1 - g0).y, (g1 - g0).x)) + 90
    put("winter/start_gate", g0.x, g0.y, gy, z=height(g0), zone="sled")
    put("winter/start_platform", g0.x + 1.8, g0.y + 0.4, gy, z=height(g0) - 1.15, tags=("prop", "walkable"), zone="sled")
    f0, f1 = TRACK[-2], TRACK[-1]
    put("winter/finish_flags", f1.x, f1.y, math.degrees(math.atan2((f1 - f0).y, (f1 - f0).x)) + 90, z=height(f1), zone="sled")
    put("winter/sled", f1.x + 1.4, f1.y - 2.0, 30, zone="sled")
    put("winter/sled", f1.x - 1.0, f1.y - 2.6, -20, zone="sled")
    mark("SledStart", g0.x + 0.6, g0.y - 0.6, gy, kind="activity", activity="sled", z=height(g0) + 0.05)
    mark("SledFinish", f1.x + 1.0, f1.y - 2.8, 0, kind="activity", activity="sled_finish")
    # --- stairs ---------------------------------------------------------------------------------
    for (a, b, z0, z1) in stair_runs():
        d = b - a
        L = d.length
        n = max(1, int(round((z1 - z0) / 0.5)))
        step = L / n
        yaw = math.degrees(math.atan2(d.x, -d.y)) + 180
        for k in range(n):
            q = a + d * ((k + 0.5) / n)
            put("winter/stone_stairs_snow", q.x, q.y, yaw, z=z0 + (z1 - z0) * k / n, tags=("prop", "walkable"),
                scale=1.0, zone="stairs")
    # --- path dressing: lanterns alternate sides, planters and flowers between ---------------------
    for pts, w in PATHS:
        side = 1
        for u, v in zip(pts, pts[1:]):
            u, v = Vector(u), Vector(v)
            d = v - u
            L = d.length
            n = Vector((-d.y, d.x)) / L
            t = 2.5
            while t < L:
                p = u + d * (t / L) + n * side * (w * 0.5 + 0.45)
                if (p - PLAZA_C).length > PLAZA_R + 1.0 and stream_d(p) > STREAM_W + 0.8 and island_d(p) < -1.5:
                    put("plaza/lantern_post", p.x, p.y, 0, tags=("light", "blocker"))
                    q = u + d * (t / L) - n * side * (w * 0.5 + 0.6)
                    if stream_d(q) > STREAM_W + 0.8:
                        if RNG.random() < 0.45:
                            put("plaza/rect_planter", q.x, q.y, math.degrees(math.atan2(d.y, d.x)), tags=("decor",))
                        else:
                            put(["nature_dock/flower_clump", "nature_dock/shrub_flowering"][RNG.randrange(2)],
                                q.x, q.y, RNG.uniform(0, 360), tags=("decor",))
                side = -side
                t += 5.0
    # fences where paths run close to the coast or the stream
    for pts, w in PATHS:
        for u, v in zip(pts, pts[1:]):
            u, v = Vector(u), Vector(v)
            d = v - u
            L = d.length
            n = Vector((-d.y, d.x)) / L
            t = 1.0
            while t < L - 1.0:
                for sgn in (1, -1):
                    p = u + d * (t / L) + n * sgn * (w * 0.5 + 0.35)
                    if (-3.5 < island_d(p) < -0.6) or (STREAM_W + 0.4 < stream_d(p) < STREAM_W + 1.4 and
                                                      all(seg_dist(p, a2, b2) > 3.0 for pts2, _ in PATHS for a2, b2 in zip(pts2, pts2[1:]) if pts2 is not pts)):
                        put("plaza/low_wood_fence_2m", p.x, p.y, math.degrees(math.atan2(d.y, d.x)), tags=("prop", "blocker"))
                t += 2.0
    # --- coast: cliff modules where the ground meets the sea, big snowy rocks elsewhere ---
    keep_out = [(Vector((p["pos"][0], p["pos"][1])), 4.2 if "building" in p["tags"] else 1.6) for p in PLACE]
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
            put("town_connections/cliff_straight_2m", p.x, p.y, yaw, z=z - 2.05, tags=("rock", "blocker"))
            put("town_connections/snow_overlay_cliff_straight", p.x, p.y, yaw, z=z + 0.02, tags=("decor",))
        o = p + g * RNG.uniform(0.4, 1.2)                  # big snowy boulders along the waterline
        put(["nature_dock/rock_cluster_snow", "winter/rock_cluster_snow_large", "nature_dock/rock_cluster_snow"][RNG.randrange(3)],
            o.x, o.y, RNG.uniform(0, 360), z=WATER_Z - 0.45, tags=("rock", "blocker"), scale=RNG.uniform(1.5, 2.4))
        keep_out.append((p, 1.6))
        last = p
    # --- groves: firs in clusters with snowy rocks, leaving open snow lawns -----------
    firs = ["winter/fir_tree_small", "winter/fir_tree_medium", "winter/fir_tree_large"]

    def free_spot(p, r=1.3):
        d = island_d(p)
        if d > -2.2 or on_path(p) or (p - PLAZA_C).length < PLAZA_R + 1.0 or poly_dist(p, TRACK) < TRACK_W * 0.5 + 1.6:
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
        return not any((p - c).length < max(r, rr) for c, rr in keep_out)
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
        put(firs[RNG.randrange(3)], p.x, p.y, RNG.uniform(0, 360), tags=("tree",), scale=RNG.uniform(0.85, 1.2))
        planted += 1
        if RNG.random() < 0.08:
            q = p + Vector((RNG.uniform(-1.6, 1.6), RNG.uniform(-1.6, 1.6)))
            if free_spot(q, 1.0):
                keep_out.append((q, 1.0))
                put(["nature_dock/rock_small_a_snow", "winter/rock_cluster_snow_small"][RNG.randrange(2)], q.x, q.y,
                    RNG.uniform(0, 360), tags=("rock",), scale=RNG.uniform(0.8, 1.3))
    print("FIRS", planted)
    for _ in range(40):  # scattered shrubs and flower clumps on the lawns
        p = Vector((RNG.uniform(-36, 36), RNG.uniform(-24, 30)))
        if free_spot(p, 1.0):
            keep_out.append((p, 1.0))
            put(["nature_dock/shrub_round", "nature_dock/shrub_flowering", "nature_dock/flower_clump"][RNG.randrange(3)],
                p.x, p.y, RNG.uniform(0, 360), tags=("decor",))
    for _ in range(80):  # rocks in the water
        a = RNG.uniform(0, 2 * math.pi)
        p = Vector((math.cos(a) * RNG.uniform(41, 54), 1.3 + math.sin(a) * RNG.uniform(38, 50)))
        if island_d(p) < 1.5:
            continue
        put(["nature_dock/rock_cluster_snow", "nature_dock/rock_small_a_snow", "nature_dock/rock_small_b_snow"][RNG.randrange(3)],
            p.x, p.y, RNG.uniform(0, 360), z=WATER_Z - 0.3, tags=("rock",), scale=RNG.uniform(1.0, 2.4))
    for x, y in [(-6.6, -6.0), (7.0, -6.2), (-9.6, -2.6), (10.0, -1.8)]:
        put("nature_dock/broad_tree_bed", x, y, RNG.uniform(0, 360), tags=("tree", "blocker"), zone="plaza")


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
    for o in (pav, w):
        common.ASSETS[:] = [a for a in common.ASSETS if a["obj"] is not o]
        o.parent = t
    t.name = "town_terrain"
    pav.name, w.name = "terrain_paving", "water"
