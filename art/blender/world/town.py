"""The town: island terrain, paving, sled run and every placement, following
Images/World Map Concept.png. Blender coords: +X east, +Y north, Z up, metres.

Outputs (see vault note Art Docs/World Layout Format.md):
  Models/world/town_terrain.glb   terrain meshes + water
  Models/world/town_layout.json   placements and markers in Godot space
  Renders/Details/town_*.png      previews from the concept camera
Run:  Blender -b --factory-startup --python art/blender/world/build_town.py
"""
import math, json, os, random, sys, importlib
import bpy
from mathutils import Vector
import common
from common import Builder, mat, tint
import sled_hill
import ground
import hand_layout
importlib.reload(hand_layout)

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
ARENA_C, ARENA_HALF, ARENA_Z = Vector((28.5, 23.7)), Vector((7.4, 6.1)), 1.5
SKETCH_C, SKETCH_Z = C(1050, 595), 0.0
COURT_C = Vector((25.5, -19.2))
COVE = [(Vector((-16.5, -22.0)), Vector((12.0, 9.0))), (Vector((-24.0, -31.0)), Vector((9.0, 5.5)))]
CAFE_SHIFT = Vector((2.2, -1.0))   # keeps the cafe clear of the sled stair foot and the path to it
CINEMA_P, CAFE_P, ARCADE_P = C(575, 200), C(455, 370) + CAFE_SHIFT, Vector((8.8, 12.8))
ARCADE_YAW, ARCADE_S = -15.0, 0.85   # the 13 x 11 m exterior only fits the NE pocket (plaza/stream/cinema path) at 0.85
CASINO_P = Vector((23.2, 8.4))   # Images/World Map - Casino Placement.png: east of the arcade, across the stream

# streets (metres) for the homes grid
HX, HY = (-35.0, -23.5, -12.0), (9.5, 0.0, -9.5)

PATHS = [  # (polyline, width)
    ([C(575, 440), C(575, 290)], 3.0),                                  # N spoke -> cinema
    ([Vector((-4.6, 7.0)), C(470, 425) + CAFE_SHIFT], 2.6),                                  # NW spoke -> cafe
    ([C(655, 505), Vector((7.55, 8.12))], 2.6),                         # NE spoke -> arcade door
    ([Vector((-PLAZA_R + 0.4, 0)), Vector((HX[0], 0))], 2.8),           # W spoke = homes main street
    ([Vector((PLAZA_R - 0.4, 0)), C(1000, 595)], 2.8),                  # E spoke -> sketch club
    ([Vector((0, -PLAZA_R + 0.4)), C(600, 1030)], 2.8),                 # S spoke -> south pier
    ([Vector((-6.2, -7.2)), Vector((-11.4, -11.7))], 2.6),              # SW spoke -> cove
    ([Vector((6.2, -7.2)), C(760, 760), Vector((19.2, -14.3))], 2.6),   # SE spoke -> court
    ([C(470, 425) + CAFE_SHIFT, Vector((-7.4, 8.6)), Vector((-11.6, 9.6))], 2.4),   # cafe door -> homes/sled-stairs path, round the cafe's west side
    ([C(575, 290), C(700, 230), C(880, 230), Vector((24.7, 14.4))], 2.4),   # cinema -> arena stairs foot
    ([Vector((24.7, 14.4)), Vector((30.4, 12.6)), Vector((30.4, 4.0)), C(1000, 595)], 2.4),  # arena -> east loop -> sketch
    ([Vector((23.2, 4.2)), Vector((23.2, -0.6))], 2.6),               # casino forecourt -> east spoke
    ([C(1000, 595), C(1010, 760), Vector((29.6, -14.6))], 2.4),         # sketch -> court
    ([Vector((HX[0], HY[0])), Vector((HX[2], HY[0]))], 2.2),            # homes grid
    ([Vector((HX[0], HY[2])), Vector((HX[2], HY[2]))], 2.2),
    ([Vector((HX[0], HY[0])), Vector((HX[0], HY[2]))], 2.2),
    ([Vector((HX[1], HY[0])), Vector((HX[1], HY[2]))], 2.2),
    ([Vector((HX[2], HY[0])), Vector((HX[2], HY[2]))], 2.2),
    ([Vector((HX[2], HY[0])), C(420, 340)], 2.2),                       # homes -> sled stairs path
    ([Vector((-11.4, -11.7)), Vector((-15.9, -12.0)), Vector((-24.0, -12.6))], 2.4),  # cove shore path
    ([Vector((HX[0], HY[2])), Vector((-30.0, -12.4)), Vector((-24.0, -12.6))], 2.2),  # homes -> boathouse
]

PATHS += sled_hill.PATHS

STREAM = [Vector((15.4, 33.15)), Vector((16.2, 21.45)), Vector((19.3, 16.25)), Vector((16.1, 8.45)), C(780, 580),   # NE bends pushed east to clear the arcade
          C(760, 700), C(700, 800),
          C(690, 920), C(700, 1080)]
STREAM_W, STREAM_BED = 1.05, -1.05

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
_HC = {}


def height(p):
    key = (round(p.x, 3), round(p.y, 3))
    if key in _HC:
        return _HC[key]
    _HC[key] = v = ground.flatten(p, _height(p))
    return v


def _height(p):
    d = island_d(p)
    if d > 0:                                            # sea floor, dropping with distance
        return SEA_FLOOR - min(1.0, d * 0.15)
    h = 0.0
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
    # sled hill (owned by sled_hill.py)
    sh = sled_hill.height(p, h)
    if sh is not None:
        h = sh
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
PADS = [(CINEMA_P, Vector((4.2, 4.8)), 0.0), (CAFE_P, Vector((3.2, 3.0)), 0.0), (ARCADE_P, Vector((5.6, 4.6)), 0.0),
        (COURT_C, Vector((9.6, 5.4)), 0.0), (SKETCH_C, Vector((3.6, 3.6)), 0.0), (CASINO_P, Vector((4.6, 4.2)), 0.0)] + \
       [(Vector((x, y)), Vector((4.4, 4.0)), 0.0) for x in (-29.25, -17.75) for y in (4.75, -4.75)] + \
       [(Vector((-22.5, 13.6)), Vector((4.0, 3.6)), 0.0), (Vector((-33.0, 13.0)), Vector((4.2, 3.9)), 0.0),
        ]


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
STAIR_FLIGHTS = [(Vector((24.7, 14.6)), Vector((0, 1)), 3, 0.0)]          # snowball arena plateau (sled stairs: sled_hill.py)
STAIR_CHAINS = []
for _foot, _u, _n, _z0 in STAIR_FLIGHTS:
    _mods = [(_foot + _u * (k + 0.5), _z0 + 0.5 * k) for k in range(_n)]
    STAIR_CHAINS.append({"mods": _mods, "dir": _u, "foot": (_foot, _z0), "top": (_foot + _u * _n, _z0 + 0.5 * _n)})
PADS += [(Vector((-10.1, 13.9)), Vector((1.2, 1.9)), 0.0),                   # approach to the sled stair foot (sled_hill's mound buried it)
         (Vector((24.7, 18.6)), Vector((1.2, 0.6)), ARENA_Z),                 # arena stair top
         (Vector((24.7, 14.1)), Vector((1.2, 0.6)), 0.0)]                     # arena stair foot


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
BRIDGE_Z = 0.07 - 0.3                     # footbridge end sockets sit 0.3 m up: drop it so ends meet the paving top
BRIDGE_ENDS = [c + Vector((math.cos(math.radians(y)), math.sin(math.radians(y)))) * sg * 2.4 for c, y in BRIDGES for sg in (1, -1)]
BRIDGE_LANDINGS = []                       # kept for older call sites; bridges now hand over to paving directly
PADS += [(c, Vector((1.5, 1.5)), 0.0) for c in BRIDGE_ENDS]


def on_path(p):
    if (p - PLAZA_C).length < PLAZA_R:
        return True
    return any(poly_dist(p, pts) < w * 0.5 for pts, w in PATHS)


def on_beach(p):
    d = island_d(p)
    return -4.5 < d < 0.3 and (cove_d(p) < 3.0 and p.x > -14.0 or (p - COURT_C).length < 13.0 and p.y < -26.0)


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
          "stairs", "landing", "court_half", "arena_blockout", "lighthouse", "icon_", "court_gate", "shore_", "foam", "porch_canopy", "doorstep", "home_number", "wall_lantern", "fender", "cleat")
SOLID = ("tree", "rock_", "fence", "planter", "mailbox", "plaque", "stanchion", "rail_", "lantern_post", "bench", "round_table",
         "umbrella", "crate", "barrel", "sign", "board", "snow_wall", "snowbank", "snow_bank", "topiary", "shrub", "street_bin",
         "chalkboard", "catch_display", "mooring_post", "rope_posts", "control_deck", "bunting_posts", "team_flag", "easel",
         "sketch_table", "ball_rack", "cliff_", "water_edge", "plaza_edge", "hoop", "scoreboard", "basket")
WATER_OK = ("rowboat", "ice_floe", "bobber", "ripple", "houseboat", "fender", "ladder", "shallow_water", "foam")
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
    if height(Vector((x, y))) < WATER_Z and not any(k in asset for k in ON_DOCK + WATER_OK):
        return "in the water"
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
    if "coast" not in tags and any(stream_d(p) < STREAM_W + 0.6 for p in pts):
        return "stream"
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
    if "sled" not in tags and not edge and any(sled_hill.blocks(p) for p in pts):
        return "sled hill walkway"
    return None


def put(asset, x, y, yaw=0.0, z=None, name=None, tags=("prop",), tints=None, scale=1.0, zone=None, auto=False):
    """Place an asset. auto=True (procedural fill) silently drops placements that would block a walkway."""
    if auto and walk_violation(asset, x, y, yaw, scale, tags):
        return False
    if "blocker" not in tags and "walkable" not in tags and "decor" not in tags and any(k in asset for k in SOLID):
        tags = tuple(tags) + ("blocker",)                 # nothing that looks solid may be walked through
    p = Vector((x, y))
    PLACE.append({"id": asset, "name": name, "pos": (x, y, height(p) if z is None else z), "yaw": yaw,
                  "tags": list(tags), "tints": tints or {}, "scale": scale, "zone": zone})
    return True


def validate():
    """Export gate: authored props must never stand on a walkable surface; walkable seams must meet."""
    rects = walk_rects()
    flagged = [(q, (q["id"], [round(v, 1) for v in q["pos"][:2]], why)) for q in PLACE
               for why in [walk_violation(q["id"], q["pos"][0], q["pos"][1], q["yaw"], q["scale"], q["tags"], rects)] if why]
    seams = check_seams()
    sled = [b for q, b in flagged if "sled" in q["tags"]]      # judged per placement, not per asset id
    bad = [b for q, b in flagged if "sled" not in q["tags"]]
    for b in sled:
        print("SLED_WARN", *b)                                # sled_hill.py owner's to fix; does not fail the town build
    for b in bad:
        print("WALK_VIOLATION", *b)
    for sm in seams:
        print("SEAM", *sm)
    print(f"VALIDATE violations={len(bad)} seams={len(seams)} sled_warnings={len(sled)}")
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
            if q["id"] == "world_misc/footbridge" and any("landing" in o["id"] and (Vector(o["pos"][:2]) - Vector((w[0], w[1]))).length < 1.3 for o in PLACE):
                exp = 0.3
            if abs(w[2] - exp) > 0.1:
                out.append((q["id"], [round(x, 1), round(y, 1)], sk, round(w[2], 2), "expected", round(exp, 2)))
    for run in STAIR_CHAINS + sled_hill.STAIR_CHAINS:
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


def socket_world(asset, sock, x, y, yaw, z=0.0, scale=1.0):
    loc = manifest(asset).get("sockets", {}).get(sock)
    if not loc:
        return None
    loc = [c * scale for c in loc]
    a = math.radians(yaw)
    return (x + loc[0] * math.cos(a) - loc[1] * math.sin(a), y + loc[0] * math.sin(a) + loc[1] * math.cos(a), z + loc[2])


def building(asset, x, y, yaw, name, door_target=None, zone=None, tints=None, scale=1.0):
    z = height(Vector((x, y)))
    put(asset, x, y, yaw, z=z, name=name, tags=("building", "blocker"), zone=zone, tints=tints, scale=scale)
    d = socket_world(asset, "socket_door", x, y, yaw, z, scale)
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
    """Authored dressing comes from hand_layout.py; only the sled hill, arena stairs, coast and the deep
    coastal forest are generated here."""
    PLACE.clear(); MARKERS.clear()
    hand_layout.build(sys.modules[__name__])
    # --- sled hill: everything from sled_hill.py ------------------------------------------------
    sled_hill.ground, sled_hill.to_godot = height, to_godot
    for q in sled_hill.placements():
        put(q["id"], q["x"], q["y"], q["yaw"], z=q["z"], name=q.get("name"), tags=tuple(q["tags"]) + ("sled",),
            tints=q.get("tints"), scale=q.get("scale", 1.0), zone="sled")
    for m in sled_hill.markers():
        mark(m["name"], m["x"], m["y"], m["yaw"], kind=m["kind"], z=m["z"],
             **{k: v for k, v in m.items() if k not in ("name", "x", "y", "yaw", "kind", "z")})
    # --- stairs: modules chained foot-to-top (no gaps) ---------------------
    for c in STAIR_CHAINS:
        u = c["dir"]
        yaw = math.degrees(math.atan2(-u.x, u.y))       # module local +Y climbs along u
        for q, z in c["mods"]:
            put("winter/stone_stairs_snow", q.x, q.y, yaw, z=z, tags=("prop", "walkable"), zone="stairs")
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
    # --- deep coastal forest: firs in the ring inside the cliffs, with the odd snowy rock ---------
    firs = ["winter/fir_tree_small", "winter/fir_tree_medium", "winter/fir_tree_large"]

    def free_spot(p, r=1.3):
        d = island_d(p)
        if d > -1.8 or on_path(p) or (p - PLAZA_C).length < PLAZA_R + 1.0 or sled_hill.blocks(p, 2.0):
            return False
        if stream_d(p) < STREAM_W + 1.2 or on_beach(p):
            return False
        if (abs(p.x - ARENA_C.x) < ARENA_HALF.x + 1 and abs(p.y - ARENA_C.y) < ARENA_HALF.y + 1) or \
                (abs(p.x - COURT_C.x) < 10.5 and abs(p.y - COURT_C.y) < 7.0) or (p - SKETCH_C).length < 5.5 or \
                (abs(p.x - CASINO_P.x) < 5.2 and abs(p.y - CASINO_P.y) < 5.4):
            return False
        if any(seg_dist(p, u, v) < w * 0.5 + 0.9 for pts, w in PATHS for u, v in zip(pts, pts[1:])):
            return False
        return not keep_out.blocked(p, r)
    def density(p):
        """0..1 tree density: the deep coastal forest ring only (between-district clumps are hand-placed)."""
        ring = 1 - smoothstep(-9.0, -4.5, island_d(p))
        return ring * (0.75 + 0.25 * RNG.random())
    planted = 0
    for _ in range(24000):
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
    for _ in range(80):  # rocks in the water
        a = RNG.uniform(0, 2 * math.pi)
        p = Vector((math.cos(a) * RNG.uniform(41, 54), 1.3 + math.sin(a) * RNG.uniform(38, 50)))
        if island_d(p) < 1.5:
            continue
        put(["nature_dock/rock_cluster_snow", "nature_dock/rock_small_a_snow", "nature_dock/rock_small_b_snow"][RNG.randrange(3)],
            p.x, p.y, RNG.uniform(0, 360), z=WATER_Z - 0.3, tags=("rock", "coast"), scale=RNG.uniform(1.0, 2.4))
    # sea: ice floes, like the concepts
    for _ in range(40):
        a = RNG.uniform(0, 2 * math.pi)
        q = Vector((math.cos(a) * RNG.uniform(42, 58), 1.3 + math.sin(a) * RNG.uniform(39, 52)))
        if island_d(q) > 2.5:
            put(["fishing/ice_floe_a", "fishing/ice_floe_b", "fishing/ice_floe_c"][RNG.randrange(3)], q.x, q.y,
                RNG.uniform(0, 360), z=WATER_Z - 0.06, tags=("decor",), scale=RNG.uniform(1.0, 2.2))


# ----------------------------------------------------------------- export --
def to_godot(v):
    return [round(v[0], 3), round(v[2], 3), round(-v[1], 3)]


def write_layout(path):
    validate()
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
        "paths": [{"name": i, "width": w, "points": [to_godot((q[0], q[1], height(Vector(q)) + 0.07)) for q in pts]}
                  for i, (pts, w) in enumerate(PATHS)],   # PATHS includes sled_hill.PATHS; for tools/walk_test.gd
        "sled_track": sled_hill.layout_data(),
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
    t = ground.terrain_mesh(Builder, height).finish(KIT, "terrain")
    pav = ground.paths_mesh(Builder, PATHS, (PLAZA_C, PLAZA_R)).finish(KIT, "terrain")
    w = build_water().finish(KIT, "terrain")
    trk = sled_hill.meshes(Builder)[0].finish(KIT, "terrain")
    for o in (pav, w, trk):
        common.ASSETS[:] = [a for a in common.ASSETS if a["obj"] is not o]
        o.parent = t
    t.name = "town_terrain"
    pav.name, w.name, trk.name = "terrain_paths", "water", "terrain_sled_track"
