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
PLAZA_C, PLAZA_R = Vector((0.0, 1.0)), 8.0
HILL_TOP = 4.75          # sled start platform base
ARENA_C, ARENA_Z = Vector((21.0, 22.0)), 3.0
SKETCH_C, SKETCH_Z = Vector((26.0, 1.0)), 1.0
COURT_C = Vector((17.0, -19.5))
BAY_C, BAY_R = Vector((-18.0, -25.0)), 9.0

# walkable paths: polylines (x, y) with width; heights come from the terrain
PATHS = [
    ([(-7.6, 0.4), (-14.0, -0.2), (-21.0, -0.5)], 2.6),               # plaza -> homes arch
    ([(-5.4, -5.0), (-10.0, -9.5), (-14.6, -13.6)], 2.6),             # plaza -> dock head
    ([(4.6, -5.6), (5.0, -9.0), (5.0, -12.2)], 2.4),                  # plaza -> bridge (north end)
    ([(5.0, -16.4), (9.0, -16.8), (12.5, -16.0)], 2.4),               # bridge (south end) -> court
    ([(7.8, 1.6), (13.5, 1.4), (20.0, 1.2)], 2.6),                    # plaza -> sketch stairs
    ([(6.4, 6.0), (10.0, 9.6), (13.0, 13.0)], 2.4),                   # plaza -> arena stairs
    ([(-6.2, 6.0), (-12.0, 10.0), (-19.0, 12.5)], 2.6),               # plaza -> sled finish
    ([(-22.0, 12.5), (-30.0, 13.0), (-37.5, 15.0)], 2.2),             # sled finish -> return stairs
]


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


def island_d(p):
    """Signed distance-ish to the coastline: <0 on land."""
    d = ellipse_d(p, Vector((0, 5)), 42, 30)
    d = min(d, ellipse_d(p, Vector((-27.0, 22.0)), 17.0, 14.0))  # sled hill shoulder (north west)
    d = min(d, (p - COURT_C).length - 10.5)            # court peninsula
    d = max(d, -((p - BAY_C).length - BAY_R))          # dock bay cut
    d = max(d, -ellipse_d(p, Vector((-4.5, -21)), 3.2, 9))  # waterfall inlet between dock and bridge
    return d


# --------------------------------------------------------------- sled run --
SLED = []   # [(asset, (x, y, z), yaw_deg, half_extents)]


def _chain():
    """Place start platform + chute modules so each entry socket meets the previous exit.
    Module local travel direction is -Y; yaw = heading + 90."""
    def R(deg, v):
        a = math.radians(deg)
        return Vector((v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a)))
    SOCK = {"slope_section": ((0, 2.0, 1.15), (0, -2.0, 0.15), 0, (1.6, 2.0)),
            "banked_turn": ((0.7, 2.3, 0.75), (-2.3, -0.7, 0.15), -90, (2.3, 2.3))}
    heading = 0.0                       # travel east first
    top = Vector((-34.0, 27.5))
    yaw = heading + 90
    SLED.append(("winter/start_platform", (top.x, top.y, HILL_TOP), yaw, (1.6, 1.9)))
    ex = top + R(yaw, (0, -1.0))
    P = Vector((ex.x, ex.y, HILL_TOP + 1.15))
    for m in ["slope_section", "slope_section", "banked_turn", "slope_section", "slope_section", "slope_section"]:
        e, x, dh, half = SOCK[m]
        yaw = heading + 90
        pxy = P.xy - R(yaw, e)
        base = P.z - e[2]
        SLED.append((f"winter/{m}", (pxy.x, pxy.y, base), yaw, half))
        nxt = pxy + R(yaw, x)
        P = Vector((nxt.x, nxt.y, base + x[2]))
        heading += dh
    return P, heading


SLED_END, SLED_HEADING = _chain()


def sled_floor(p):
    """Module base height if p is under (or just around) a sled module, else None."""
    best = None
    for _, (x, y, z), yaw, (hx, hy) in SLED:
        a = -math.radians(yaw)
        d = p - Vector((x, y))
        lx, ly = d.x * math.cos(a) - d.y * math.sin(a), d.x * math.sin(a) + d.y * math.cos(a)
        if abs(lx) <= hx + 0.7 and abs(ly) <= hy + 0.7:
            best = z if best is None else min(best, z)
    return best


def corridor_z(p):
    """Height of the nearest point of the sled corridor (for the hill shape)."""
    best, bz = 1e9, 0.0
    for _, (x, y, z), _, _ in SLED:
        d = (p - Vector((x, y))).length
        if d < best:
            best, bz = d, z
    return best, bz


# ---------------------------------------------------------------- terrain --
def height(p):
    d = island_d(p)
    if d > 0:                                            # sea floor, dropping with distance
        return SEA_FLOOR - min(1.0, d * 0.15)
    h = 0.0
    # sled hill: a raised shoulder following the run, rising gently away from it
    hill = ellipse_d(p, Vector((-27.0, 24.0)), 15.5, 12.5)
    if hill < 3.0:
        dist, cz = corridor_z(p)
        hh = cz + min(2.2, dist * 0.45) if dist < 9 else HILL_TOP + 0.6
        h = max(h, hh * (1 - smoothstep(-1.5, 3.0, hill)))
    # snowball arena plateau (flat top, firm edge)
    ar = ellipse_d(p, ARENA_C, 10.5, 8.5)
    h = max(h, ARENA_Z * (1 - smoothstep(-0.6, 1.4, ar)))
    # sketch club rise
    sk = (p - SKETCH_C).length - 6.5
    h = max(h, SKETCH_Z * (1 - smoothstep(-0.5, 1.0, sk)))
    # stairs ramps (terrain under stair modules rises with them)
    for (sx, sy, z0, length, dirx, diry, rise) in STAIR_RUNS:
        a = Vector((sx, sy)); dv = Vector((dirx, diry))
        t = (p - a).dot(dv)
        w = abs((p - a).dot(Vector((-dv.y, dv.x))))
        if -0.5 <= t <= length + 0.5 and w < 1.4:
            h = max(h, z0 + rise * max(0.0, min(1.0, t / length)) - 0.02)
    sf = sled_floor(p)
    if sf is not None:
        h = sf
    # coastline: a band of cliff dropping into the sea
    edge = smoothstep(-0.9, 0.5, d)                      # steep drop behind the cliff ring
    return h * (1 - edge) + (SEA_FLOOR + 0.2) * edge


# stairs: (x, y, base z, length along dir, dir x, dir y, total rise)
STAIR_RUNS = [
    (13.0, 13.0, 0.0, 6.0, 0.62, 0.78, ARENA_Z),     # plaza -> arena
    (20.0, 1.2, 0.0, 2.0, 1.0, 0.0, SKETCH_Z),       # plaza -> sketch club
    (-37.5, 15.5, 0.0, 9.5, 0.0, 1.0, HILL_TOP),     # return stairs up the sled hill
]


def on_path(p):
    if (p - PLAZA_C).length < PLAZA_R:
        return True
    return any(seg_dist(p, a, b) < w * 0.5 for pts, w in PATHS for a, b in zip(pts, pts[1:]))


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
            if island_d(p) < -3.5 and not on_path(p) and sled_floor(p) is None:
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
                elif island_d(p2) > -4.0 and (p2 - COURT_C).length < 11.5 and p2.y < -24:
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
                    if (p - PLAZA_C).length < PLAZA_R - 0.3:
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
    b.mesh(verts, faces, mat=tint("water", "#2DB6CB"))
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


def layout():
    PLACE.clear(); MARKERS.clear()
    B = ("building", "blocker")
    # --- plaza core (compact, densely dressed like the concept) ------------------
    put("plaza/small_fountain", 0, 1, 0, tags=("prop", "blocker"), name="Fountain", zone="plaza")
    put("cinema/cinema_exterior", 0.0, 12.6, 0, tags=B, name="Cinema", zone="plaza")
    put("cafe/cafe_exterior", -10.4, 5.4, 32, tags=B, name="Cafe", zone="plaza")
    put("arcade/arcade_exterior", 10.9, 7.0, -34, tags=B, name="Arcade", zone="plaza")
    ring = lambda r, a: (math.cos(math.radians(a)) * r, 1 + math.sin(math.radians(a)) * r)
    for a in (30, 150, 210, 330):                      # benches facing the fountain
        x, y = ring(3.6, a)
        put("plaza/bench", x, y, face(x, y, 0, 1) + 180, tags=("prop", "blocker"), zone="plaza")
    for a in (90, 270, 0, 180):                        # flower boxes on the cross axes
        x, y = ring(3.4, a)
        put("plaza/rect_planter", x, y, face(x, y, 0, 1), zone="plaza")
    for a in range(22, 360, 45):                       # lanterns on the plaza rim
        x, y = ring(PLAZA_R - 0.5, a)
        put("plaza/lantern_post", x, y, 0, tags=("light", "blocker"), zone="plaza")
    put("plaza/bunting_posts", 0, 8.4, 0, zone="plaza")
    put("plaza/bunting_posts", -5.4, -5.4, 45, zone="plaza")
    put("plaza/bunting_posts", 5.4, -5.4, -45, zone="plaza")
    # flower beds hugging the plaza edge between the openings
    for a in range(0, 360, 12):
        x, y = ring(PLAZA_R + 0.8, a)
        p = Vector((x, y))
        if on_path(p) and (p - PLAZA_C).length > PLAZA_R or any(
                seg_dist(p, u, v) < w * 0.5 + 0.6 for pts, w in PATHS for u, v in zip(pts, pts[1:])):
            continue
        put(["nature_dock/shrub_flowering", "nature_dock/flower_clump", "nature_dock/shrub_round",
             "nature_dock/flower_clump"][(a // 12) % 4], x, y, RNG.uniform(0, 360), tags=("decor",), zone="plaza")
    # cafe terrace
    for (x, y, yaw) in [(-7.2, 3.6, 15), (-6.2, 0.6, -10), (-8.6, -1.6, 30)]:
        put("plaza/cafe_umbrella_table", x, y, yaw, tags=("prop", "blocker"), zone="plaza")
    put("plaza/aframe_chalkboard", -7.6, 6.6, 40, zone="plaza")
    put("plaza/flower_pot", -8.2, 7.6, 0, zone="plaza")
    put("plaza/flower_pot", -12.6, 3.0, 0, zone="plaza")
    # cinema forecourt
    put("plaza/string_lights", -2.2, 8.9, 0, z=2.4, tags=("light",), zone="plaza")
    put("plaza/string_lights", 2.2, 8.9, 0, z=2.4, tags=("light",), zone="plaza")
    put("cinema/poster_frame_a", -4.6, 8.6, 0, zone="plaza")
    put("cinema/poster_frame_b", 4.6, 8.6, 0, zone="plaza")
    # arcade frontage: crates, barrel, chalkboard
    put("world_misc/crate", 8.0, 4.2, 15, tags=("prop", "blocker"), zone="plaza")
    put("world_misc/crate", 8.4, 3.6, 40, z=height(Vector((8.4, 3.6))) + 0.5, zone="plaza")
    put("world_misc/barrel", 13.6, 3.8, 0, tags=("prop", "blocker"), zone="plaza")
    put("arcade/arcade_chalkboard", 7.4, 5.8, -30, zone="plaza")
    put("plaza/street_bin", 3.2, -6.8, 0, zone="plaza")
    put("world_misc/signpost", 6.4, -4.8, -40, tags=("prop", "blocker"), zone="plaza")
    put("world_misc/notice_board", -4.0, -6.6, 25, tags=("prop", "blocker"), zone="plaza")
    mark("Spawn", 0, -3.2, 180)
    mark("BusArrival", 2.4, -4.6, 200)
    mark("BusStop", 3.6, -7.6, 200, kind="bus")
    mark("CinemaDoor", 0.0, 8.0, 0, kind="door", target="cinema_lobby")
    mark("CafeDoor", -9.2, 3.2, 32, kind="door", target="cafe_interior")
    mark("ArcadeDoor", 9.6, 4.4, -34, kind="door", target="arcade_interior")
    # --- homes (west) ------------------------------------------------------
    put("world_misc/homes_arch", -22.5, -0.5, 90, tags=("building", "blocker"), name="HomesArch", zone="homes")
    put("world_misc/mailbox", -21.5, 2.4, 90, zone="homes")
    for i, (x, y) in enumerate([(-27, -4.5), (-30.5, 1.5), (-27.5, 6.5)]):
        put(["cottage/cottage_exterior", "homes/round_cottage_exterior", "homes/aframe_cabin_exterior"][i],
            x, y, face(x, y, -22.5, -0.5), tags=B, zone="homes")
    mark("HomesGate", -21.0, -0.5, 90, kind="door", target="home")
    # --- dock bay (south west) -----------------------------------------------
    dock = [(-14.6, -13.2, 0), (-14.6, -15.2, 0), (-14.6, -17.2, 0), (-14.6, -19.2, 0)]
    for (x, y, yaw) in dock:
        put("nature_dock/dock_straight", x, y, yaw, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("fishing/fishing_dock_spot", -14.6, -21.2, 0, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("nature_dock/dock_straight", -16.6, -21.2, 90, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("fishing/fishing_dock_spot", -18.6, -21.2, 90, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("nature_dock/dock_end_cap", -14.6, -23.2, 0, z=0.0, tags=("prop", "walkable"), zone="dock")
    put("fishing/rowboat", -11.6, -20.6, 70, z=WATER_Z, zone="dock")
    put("fishing/life_ring", -12.9, -16.0, 90, z=0.3, zone="dock")
    put("fishing/bucket_fish", -15.4, -19.6, 0, z=0.06, zone="dock")
    put("fishing/tackle_crate", -13.8, -14.0, 20, z=0.06, zone="dock")
    put("nature_dock/rope_posts_bunting", -14.6, -12.4, 0, zone="dock")
    mark("FishingSpot0", -14.0, -21.6, 0, kind="activity", activity="fishing", z=0.06)
    mark("FishingSpot1", -18.6, -22.0, 0, kind="activity", activity="fishing", z=0.06)
    # --- stream, waterfall and bridge (south) ----------------------------------
    put("world_misc/waterfall_step", -4.5, -12.6, 0, zone="stream")
    put("world_misc/footbridge", 5.0, -14.3, 90, tags=("prop", "walkable"), name="Footbridge", zone="stream")
    # --- basketball court (south east peninsula) --------------------------------
    put("activities/basketball_court_half", COURT_C.x, COURT_C.y, 0, z=0.0, tags=("prop", "walkable"), name="Court", zone="court")
    put("activities/basketball_hoop", COURT_C.x, COURT_C.y - 4.6, 0, tags=("prop", "blocker"), zone="court")
    put("activities/scoreboard", COURT_C.x + 5.6, COURT_C.y + 2.5, -90, tags=("prop", "blocker"), zone="court")
    put("activities/ball_rack", COURT_C.x - 5.4, COURT_C.y + 1.0, 90, tags=("prop", "blocker"), zone="court")
    put("plaza/bench", COURT_C.x - 1.5, COURT_C.y + 5.2, 180, tags=("prop", "blocker"), zone="court")
    put("plaza/bench", COURT_C.x + 2.0, COURT_C.y + 5.2, 180, tags=("prop", "blocker"), zone="court")
    mark("CourtEntry", COURT_C.x - 4.5, COURT_C.y + 3.5, 0, kind="activity", activity="basketball")
    # --- sketch club (east rise) -------------------------------------------------
    put("activities/sketch_pavilion", SKETCH_C.x, SKETCH_C.y, face(SKETCH_C.x, SKETCH_C.y, 0, 1), z=SKETCH_Z,
        tags=B, name="SketchClub", zone="sketch")
    put("activities/communal_table", SKETCH_C.x, SKETCH_C.y, 0, z=SKETCH_Z, tags=("prop", "blocker"), zone="sketch")
    mark("SketchEntry", SKETCH_C.x - 4.0, SKETCH_C.y, -90, kind="activity", activity="sketch", z=SKETCH_Z)
    # --- snowball arena (north east plateau) -------------------------------------
    put("winter/snowball_arena_blockout", ARENA_C.x - 6.7, ARENA_C.y - 5.4, 0, z=ARENA_Z, tags=("prop",),
        name="SnowballArena", zone="arena")
    put("winter/spectator_bench_snow", ARENA_C.x - 2, ARENA_C.y - 7.4, 180, z=ARENA_Z, tags=("prop", "blocker"), zone="arena")
    mark("ArenaGate", ARENA_C.x - 0.7, ARENA_C.y - 6.6, 0, kind="activity", activity="snowballs", z=ARENA_Z)
    # --- sled hill (north west) ---------------------------------------------------
    for asset, (x, y, z), yaw, _ in SLED:
        put(asset, x, y, yaw, z=z, tags=("prop", "walkable"), zone="sled")
    put("winter/start_gate", SLED[0][1][0] + 1.6, SLED[0][1][1], SLED[0][2], z=HILL_TOP + 1.15, zone="sled")
    put("winter/finish_flags", SLED_END.x, SLED_END.y, SLED_HEADING + 90, z=height(SLED_END.xy), zone="sled")
    mark("SledStart", SLED[0][1][0], SLED[0][1][1] + 0.4, SLED[0][2], kind="activity", activity="sled", z=HILL_TOP + 1.2)
    mark("SledFinish", SLED_END.x, SLED_END.y - 2.5, 0, kind="activity", activity="sled_finish")
    # --- stairs ------------------------------------------------------------------
    for (sx, sy, z0, length, dx, dy, rise) in STAIR_RUNS:
        n = int(round(length))
        yaw = math.degrees(math.atan2(dx, -dy)) + 180  # stairs climb toward their +Y (socket_top)
        for k in range(n):
            put("winter/stone_stairs_snow", sx + dx * (k + 0.5), sy + dy * (k + 0.5), yaw,
                z=z0 + rise * k / n, tags=("prop", "walkable"), zone="stairs")
    # --- path dressing: lanterns alternate sides every ~6 m, flowers at bends ------
    for pts, w in PATHS:
        side = 1
        for u, v in zip(pts, pts[1:]):
            u, v = Vector(u), Vector(v)
            d = v - u
            L = d.length
            n = Vector((-d.y, d.x)) / L
            t = 3.0
            while t < L:
                p = u + d * (t / L) + n * side * (w * 0.5 + 0.45)
                if (p - PLAZA_C).length > PLAZA_R + 1.2:
                    put("plaza/lantern_post", p.x, p.y, 0, tags=("light", "blocker"))
                    q = u + d * (t / L) - n * side * (w * 0.5 + 0.6)
                    if RNG.random() < 0.5:
                        put("plaza/rect_planter", q.x, q.y, math.degrees(math.atan2(d.y, d.x)), tags=("decor",))
                    else:
                        put(["nature_dock/flower_clump", "nature_dock/shrub_flowering"][RNG.randrange(2)],
                            q.x, q.y, RNG.uniform(0, 360), tags=("decor",))
                side = -side
                t += 6.0
    # low fences where paths run near the coast
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
                    if -3.5 < island_d(p) < -0.6:
                        put("plaza/low_wood_fence_2m", p.x, p.y, math.degrees(math.atan2(d.y, d.x)) + 90 - 90,
                            tags=("prop", "blocker"))
                t += 2.0
    # --- coast: cliff modules where the ground meets the sea, big snowy rocks elsewhere ---
    keep_out = [(Vector((p["pos"][0], p["pos"][1])), 4.2 if "building" in p["tags"] else 1.6) for p in PLACE]
    coast = []
    for k in range(720):
        a = 2 * math.pi * k / 720
        dirv = Vector((math.cos(a), math.sin(a)))
        r = 10.0
        while r < 70 and island_d(Vector((0, 5)) + dirv * r) < 0:
            r += 0.25
        coast.append(Vector((0, 5)) + dirv * (r - 0.9))
    last = None
    for p in coast:
        if last is not None and (p - last).length < 1.95:
            continue
        nx = (Vector((p.x + 0.1, p.y)) - Vector((p.x - 0.1, p.y)))
        g = Vector((island_d(Vector((p.x + 0.1, p.y))) - island_d(Vector((p.x - 0.1, p.y))),
                    island_d(Vector((p.x, p.y + 0.1))) - island_d(Vector((p.x, p.y - 0.1))))).normalized()
        yaw = math.degrees(math.atan2(g.x, -g.y))          # module front (-Y) faces the sea
        z = height(p - g * 0.8)
        near_dock = (p - BAY_C).length < BAY_R + 1.5 and p.x > -22 and p.x < -12 and p.y > -17
        sandy = (p - COURT_C).length < 11.5 and p.y < -26
        inlet = abs(p.x + 4.5) < 3.5 and p.y < -11
        if sandy or inlet or near_dock:
            last = p
            continue
        if z < 0.6:
            put("town_connections/cliff_straight_2m", p.x, p.y, yaw, z=z - 2.05, tags=("rock", "blocker"))
            put("town_connections/snow_overlay_cliff_straight", p.x, p.y, yaw, z=z + 0.02, tags=("decor",))
        else:
            put("nature_dock/rock_cluster_snow", p.x, p.y, RNG.uniform(0, 360), z=z - 1.2, tags=("rock", "blocker"),
                scale=RNG.uniform(1.6, 2.3))
        keep_out.append((p, 1.6))
        last = p
    # --- groves: firs in clusters with snowy rocks, leaving open snow lawns -----------
    firs = ["winter/fir_tree_small", "winter/fir_tree_medium", "winter/fir_tree_large"]

    def free_spot(p, r=1.3):
        d = island_d(p)
        if d > -2.2 or on_path(p) or (p - PLAZA_C).length < PLAZA_R + 2.0 or sled_floor(p) is not None:
            return False
        if ellipse_d(p, ARENA_C, 9.5, 7.5) < 0 or (p - COURT_C).length < 7.5 or (p - SKETCH_C).length < 5.5:
            return False
        if any(seg_dist(p, u, v) < w * 0.5 + 0.9 for pts, w in PATHS for u, v in zip(pts, pts[1:])):
            return False
        return not any((p - c).length < max(r, rr) for c, rr in keep_out)
    groves = []
    for _ in range(400):
        c = Vector((RNG.uniform(-44, 44), RNG.uniform(-32, 38)))
        if free_spot(c, 2.5) and all((c - g).length > 7.5 for g in groves):
            groves.append(c)
        if len(groves) >= 30:
            break
    for g in groves:
        n = RNG.randint(5, 11)
        for _ in range(n * 4):
            if n <= 0:
                break
            p = g + Vector((RNG.gauss(0, 2.4), RNG.gauss(0, 2.4)))
            if free_spot(p):
                keep_out.append((p, 1.25))
                put(firs[RNG.randrange(3)], p.x, p.y, RNG.uniform(0, 360), tags=("tree",), scale=RNG.uniform(0.85, 1.2))
                n -= 1
        for _ in range(RNG.randint(1, 3)):
            p = g + Vector((RNG.uniform(-3.5, 3.5), RNG.uniform(-3.5, 3.5)))
            if free_spot(p, 1.0):
                keep_out.append((p, 1.0))
                put(["nature_dock/rock_cluster_snow", "nature_dock/rock_small_a_snow", "winter/rock_cluster_snow_small"][RNG.randrange(3)],
                    p.x, p.y, RNG.uniform(0, 360), tags=("rock",), scale=RNG.uniform(0.8, 1.4))
    for _ in range(26):  # scattered shrubs and flower clumps on the lawns
        p = Vector((RNG.uniform(-36, 36), RNG.uniform(-24, 30)))
        if free_spot(p, 1.0):
            keep_out.append((p, 1.0))
            put(["nature_dock/shrub_round", "nature_dock/shrub_flowering", "nature_dock/flower_clump"][RNG.randrange(3)],
                p.x, p.y, RNG.uniform(0, 360), tags=("decor",))
    for _ in range(46):  # rocks in the water
        a = RNG.uniform(0, 2 * math.pi)
        p = Vector((math.cos(a) * RNG.uniform(44, 56), 5 + math.sin(a) * RNG.uniform(32, 42)))
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
        "camera": {"bounds_min": to_godot((-40, 34, 0))[::2], "bounds_max": to_godot((40, -32, 0))[::2],
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
