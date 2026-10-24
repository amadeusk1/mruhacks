"""Activities kit: basketball court kit (Basketball Prop Kit sheet, brief section 14) and the
Drawing Club social table kit (Drawing Club Prop Kit sheet, brief section 15).

Reuse, don't duplicate: spectator seating is plaza/bench and club seating is plaza/stool
(see each asset's "reuse" meta). Table clutter is never fused: tools are separate props placed
at sockets."""
from common import *

KIT = "activities"
PREVIEW_WIDTH = 16.0

COURT_W, COURT_D = 8.0, 7.0
SLAB = 0.06
TILE = 2.0
RIM = (0.0, 3.0)        # rim centre on the half court (x, y)
RIM_Z = 1.72
LINE = 0.06
COURT = tint("court", "teal")
KEY = tint("court_key", "coral")
LINES = tint("court_line", "cream")
POLE = tint("pole", "wood_b")
METAL = tint("frame", "teal")
RIMC = tint("rim", "orange")
SPOT = tint("spot", "coral")
READY = tint("ready", "teal")
ROOFT = tint("roof", "roof")
BANNER = tint("banner", "coral")
CUSHION = tint("cup", "teal")
PENNANTS = (tint("pennant_a", "coral"), tint("pennant_b", "teal_light"), tint("pennant_c", "cream"), tint("pennant_d", "mustard"))
TABLE_H = 0.6


# ---------------------------------------------------------------- helpers
def shade_snow(b, thr=0.55):
    """Blue-white snow_shade on snow faces that point sideways or down, for readable facets."""
    if "snow" not in b.mats:
        return
    src, dst = b.mats.index("snow"), b._mi("snow_shade")
    for f in b.bm.faces:
        if f.material_index == src:
            f.normal_update()
            if f.normal.z < thr:
                f.material_index = dst


def done(b, *a, **k):
    shade_snow(b)
    return b.finish(KIT, *a, **k)


def attach(child, parent):
    """Make child part of parent's exported hierarchy (removable roof) instead of its own asset."""
    ASSETS[:] = [a for a in ASSETS if a["obj"] is not child]
    child.parent = parent
    return child


def line(b, x0, y0, x1, y1, z, mat=LINES, w=LINE, ext=0.5):
    L = math.hypot(x1 - x0, y1 - y0)
    b.box(L + w * ext, w, 0.008, (x0 + x1) / 2, (y0 + y1) / 2, z, mat, bevel=0,
          rot=(0, 0, math.degrees(math.atan2(y1 - y0, x1 - x0))))


def arc(b, cx, cy, R, a0, a1, z, n=14, mat=LINES, w=LINE, ext=0.5):
    pts = [(cx + R * math.cos(a0 + (a1 - a0) * i / n), cy + R * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    for i, ((x0, y0), (x1, y1)) in enumerate(zip(pts, pts[1:])):
        # overlap interior joints only, so the line ends exactly on its end points
        line(b, x0, y0, x1, y1, z, mat, w, ext=ext if 0 < i < n - 1 else ext / 2)


def disc(b, cx, cy, R, z, mat, a0=0.0, a1=2 * math.pi, n=16, h=0.006):
    pts = [(cx, cy)] + [(cx + R * math.cos(a0 + (a1 - a0) * i / n), cy + R * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    if a1 - a0 >= 2 * math.pi - 1e-6:
        pts = pts[1:-1]
    b.prism(pts, h, z=z, mat=mat, plane="xy")


def face_to(px, py, tx, ty):
    """rotz (deg) that turns an asset's -Y front toward the target."""
    return math.degrees(math.atan2(tx - px, -(ty - py)))


def ell(cx, cy, rx, ry, n=12, a0=0.0):
    return [(cx + rx * math.cos(a0 + 2 * math.pi * i / n), cy + ry * math.sin(a0 + 2 * math.pi * i / n)) for i in range(n)]


BIRD = [ell(0, 0, 0.5, 0.32), ell(0.36, 0.26, 0.22, 0.22, 10),
        [(0.55, 0.3), (0.76, 0.24), (0.55, 0.18)], [(-0.4, 0.06), (-0.74, 0.24), (-0.62, -0.06)]]


def emblem(b, s, x, y, z, mat="cream", flat=False, rotz=0.0, depth=0.012):
    """Flat bird silhouette (the village crest). flat=True lies on the ground; else faces -Y."""
    with b.at((x, y, z), rotz=rotz):
        for poly in BIRD:
            pts = [(u * s, v * s) for u, v in poly]
            b.prism(pts, depth, mat=mat, plane="xy" if flat else "xz")


def flutter_bunting(b, p0, p1, n, name, colors=PENNANTS, size=0.16, sag=0.1):
    """Rope stays static; every pennant is its own flutter part hinged on the rope."""
    pts = rope_between(b, p0, p1, sag=sag, r=0.012, segs=n * 2)
    d = (Vector(p1) - Vector(p0)).normalized()
    rz = math.degrees(math.atan2(d.y, d.x))
    for i in range(n):
        p = tuple(pts[1 + i * 2])
        with b.part(f"{name}_{i}", pivot=p, motion="flutter", amp_deg=14):
            with b.at(p, rotz=rz):
                b.prism([(-size / 2, 0), (size / 2, 0), (0, -size * 1.15)], 0.015, mat=pick(colors, i))


def ball(b, r, x, y, z, seams=True):
    b.blob(r, r, r, x, y, z, tint("ball", "orange"), subdiv=2)
    if seams:
        for rot in ((0, 0, 0), (90, 0, 0), (90, 0, 90)):
            b.torus(r * 1.005, r * 0.05, x, y, z, "black", segs=16, ring=4, rot=rot)


def snow_post(b, x, y, z=0.0, h=0.8, w=0.16, mat="wood_b"):
    b.box(w + 0.08, w + 0.08, 0.12, x, y, z, "stone", bevel=0.025)
    b.box(w, w, h, x, y, z + 0.1, mat, bevel=0.02)
    b.box(w + 0.05, w + 0.05, 0.07, x, y, z + h + 0.1, "snow", bevel=0.03)
    b.blob(w * 0.55, w * 0.55, 0.06, x, y, z + h + 0.17, "snow", subdiv=1)


# ---------------------------------------------------------------- basketball: court
def basketball_court_half():
    """Assembled reference half court (one piece). For modular courts use the court_tile_* set."""
    b = Builder("basketball_court_half")
    W, D = COURT_W, COURT_D
    b.box(W + 0.7, D + 0.7, SLAB - 0.012, 0, 0, 0, "paving_b", bevel=0.04)
    b.box(W + 0.1, D + 0.1, SLAB, 0, 0, 0, COURT, bevel=0.0)  # unbevelled top: flat walk surface
    top = SLAB
    key_w, ft_y = 2.0, 1.1
    b.box(key_w, D / 2 - ft_y, 0.004, 0, (D / 2 + ft_y) / 2, top, KEY, bevel=0)
    disc(b, 0, -D / 2, 0.9, top, KEY, 0, math.pi, h=0.004)
    lz = top + 0.004
    for (x0, y0, x1, y1) in ((-W / 2, -D / 2, W / 2, -D / 2), (W / 2, -D / 2, W / 2, D / 2),
                             (W / 2, D / 2, -W / 2, D / 2), (-W / 2, D / 2, -W / 2, -D / 2)):
        line(b, x0, y0, x1, y1, lz)
    for sx in (-1, 1):
        line(b, sx * key_w / 2, ft_y, sx * key_w / 2, D / 2, lz)
    line(b, -key_w / 2, ft_y, key_w / 2, ft_y, lz)
    arc(b, 0, ft_y, 0.7, 0, 2 * math.pi, lz, n=18)
    R, cx = 3.0, 2.85
    dy = math.sqrt(R * R - cx * cx)
    for sx in (-1, 1):
        line(b, sx * cx, RIM[1] - dy, sx * cx, D / 2, lz)
    arc(b, RIM[0], RIM[1], R, math.atan2(-dy, -cx), math.atan2(-dy, cx), lz, n=22)
    arc(b, 0, -D / 2, 0.9, 0, math.pi, lz, n=12)
    for k, a in enumerate((-150, -115, -65, -30)):
        px, py = RIM[0] + 2.4 * math.cos(math.radians(a)), RIM[1] + 2.4 * math.sin(math.radians(a))
        b.socket(f"shoot_{k}", (px, py, top), rotz=face_to(px, py, *RIM))
    for k in range(4):
        b.socket(f"spectator_{k}", (-1.8 + 1.2 * k, -D / 2 - 0.9, 0), rotz=180)
    b.socket("hoop", (0, D / 2 + 0.25, top), rotz=0)
    b.socket("target", (RIM[0], RIM[1], RIM_Z - 0.05))
    b.socket("scoreboard", (W / 2 + 0.9, D / 2 - 1.0, 0), rotz=90)
    return done(b, "activity", {
        "activity": "basketball", "court_m": [W, D], "rim_xy": list(RIM), "rim_z": RIM_Z,
        "collider": f"flat plane at z={SLAB}", "reuse": {"spectator_seat": "plaza/bench"},
        "note": "place basketball_hoop at socket_hoop and shooting_spot props at socket_shoot_*; snow stays outside",
    })


def court_tile(name, paint=None, key=False):
    """2 m seamless court module: unbevelled slab so the walk/collision surface is flat across seams.
    Painted lines run on the tile centre lines and meet the edge midpoints, so tiles chain."""
    b = Builder(name)
    h = TILE / 2
    b.box(TILE, TILE, SLAB, 0, 0, 0, KEY if key else COURT, bevel=0.0)
    lz = SLAB
    if paint == "straight":
        line(b, -h, 0, h, 0, lz, w=LINE * 1.2, ext=0)
    elif paint == "corner":
        line(b, -LINE * 0.6, 0, h, 0, lz, w=LINE * 1.2, ext=0)
        line(b, 0, -LINE * 0.6, 0, h, lz, w=LINE * 1.2, ext=0)
    elif paint == "arc":
        arc(b, h, -h, h, math.pi / 2, math.pi, lz, n=10, w=LINE * 1.2, ext=0.4)
    b.socket("tile_centre", (0, 0, SLAB))
    return done(b, "court", {"grid_m": TILE, "collider": f"box {TILE}x{TILE}x{SLAB}, flat top",
                             "paint": paint or ("key" if key else "plain"),
                             "line_ends": "edge midpoints (chains with neighbours by rotation)"})


def shooting_spot():
    b = Builder("shooting_spot")
    b.cyl(0.36, 0.02, 0, 0, 0, "paving_b", segs=16)
    b.cyl(0.31, 0.024, 0, 0, 0, SPOT, segs=16)
    for k in range(8):
        a = 2 * math.pi * k / 8
        b.box(0.08, 0.03, 0.004, math.cos(a) * 0.255, math.sin(a) * 0.255, 0.024, "cream", bevel=0,
              rot=(0, 0, math.degrees(a)))
    emblem(b, 0.25, 0.02, -0.02, 0.024, "cream", flat=True, depth=0.004)
    b.socket("shoot", (0, 0, 0.028))
    return done(b, "marker", {"activity": "basketball", "walkable": True, "collider": "none (decal-height)"})


def ready_marker():
    b = Builder("ready_marker")
    S = 0.8
    b.box(S, S, 0.02, 0, 0, 0, "paving_b", bevel=0.0)
    b.box(S - 0.1, S - 0.1, 0.024, 0, 0, 0, READY, bevel=0.0)
    L = 0.16
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (S / 2 - 0.12), sy * (S / 2 - 0.12)
            b.box(L, 0.035, 0.004, cx - sx * L / 2, cy, 0.024, "cream", bevel=0)
            b.box(0.035, L, 0.004, cx, cy - sy * L / 2, 0.024, "cream", bevel=0)
    emblem(b, 0.32, 0.02, -0.02, 0.024, "cream", flat=True, depth=0.004)
    b.socket("ready", (0, 0, 0.028))
    return done(b, "marker", {"activity": "basketball", "walkable": True, "color_variants": ["#207D85", "#E86D58"]})


# ---------------------------------------------------------------- basketball: hoop and equipment
def basketball_hoop():
    """Static support and backboard; rim (tilt) and net (sway) are child parts. Pole base at origin,
    board and rim reach toward -Y over the court."""
    b = Builder("basketball_hoop")
    b.box(0.6, 0.6, 0.2, 0, 0.12, 0, "stone", bevel=0.04)
    b.box(0.5, 0.5, 0.06, 0, 0.12, 0.2, "stone_dark", bevel=0.02)
    b.box(0.2, 0.2, 2.1, 0, 0.12, 0.26, POLE, bevel=0.03)
    for z in (0.32, 1.9):
        b.box(0.24, 0.24, 0.1, 0, 0.12, z, METAL, bevel=0.02)
    # angled arm up and forward to the board, with a teal bracket plate
    beam_pts = ((0, 0.12, 1.95), (0, -0.3, 2.2))
    d = Vector(beam_pts[1]) - Vector(beam_pts[0])
    m = (Vector(beam_pts[0]) + Vector(beam_pts[1])) / 2
    b.box(0.16, 0.16, d.length + 0.1, m.x, m.y, m.z, POLE, bevel=0.02, center=True,
          rot=tuple(math.degrees(a) for a in d.to_track_quat("Z", "Y").to_euler()))
    by = -0.4
    b.box(0.3, 0.06, 0.4, 0, by + 0.07, 1.85, METAL, bevel=0.015)
    # backboard: cream face, teal frame, teal target square
    b.box(1.14, 0.06, 0.74, 0, by, 1.64, "cream", bevel=0.02)
    for (sx, x, z, h) in ((1.18, 0, 2.36, 0.06), (1.18, 0, 1.62, 0.06), (0.06, -0.58, 1.62, 0.8), (0.06, 0.58, 1.62, 0.8)):
        b.box(sx, 0.075, h, x, by, z, METAL, bevel=0.01)
    for (sx, x, z, h) in ((0.44, 0, 2.0, 0.04), (0.44, 0, 1.76, 0.04), (0.04, -0.2, 1.76, 0.28), (0.04, 0.2, 1.76, 0.28)):
        b.box(sx, 0.02, h, x, by - 0.035, z, METAL, bevel=0)
    # rim mount bracket stays static
    b.box(0.12, 0.08, 0.06, 0, by - 0.07, RIM_Z - 0.04, RIMC, bevel=0.01)
    ry = by - 0.32
    with b.part("rim", pivot=(0, by - 0.1, RIM_Z), motion="tilt", axis="x", max_deg=6):
        b.box(0.1, 0.1, 0.03, 0, by - 0.15, RIM_Z - 0.015, RIMC, bevel=0.008)
        b.torus(0.21, 0.018, 0, ry, RIM_Z, RIMC, segs=16, ring=6)
    with b.part("net", pivot=(0, ry, RIM_Z - 0.02), motion="sway", amp_deg=5):
        n = 10
        for k in range(n):
            a = 2 * math.pi * k / n
            for dd in (-1, 1):
                a2 = a + dd * math.pi / n
                p0 = (0.19 * math.cos(a), ry + 0.19 * math.sin(a), RIM_Z - 0.03)  # hangs just inside the rim tube
                p1 = (0.13 * math.cos(a2), ry + 0.13 * math.sin(a2), RIM_Z - 0.36)
                rope_between(b, p0, p1, sag=0.0, r=0.006, segs=1, mat="white")
        b.torus(0.16, 0.008, 0, ry, RIM_Z - 0.2, "white", segs=12, ring=4)
        b.torus(0.13, 0.008, 0, ry, RIM_Z - 0.36, "white", segs=12, ring=4)
    b.socket("target", (0, ry, RIM_Z - 0.05))
    return done(b, "activity", {"activity": "basketball", "rim_radius_m": 0.21, "rim_z": RIM_Z})


def basketball():
    b = Builder("basketball")
    ball(b, 0.12, 0, 0, 0)
    return done(b, "projectile", {"radius_m": 0.12, "pivot": "ball centre (origin is not on the ground)"})


def scoreboard():
    b = Builder("scoreboard")
    W = 1.9
    for sx in (-1, 1):
        b.box(0.3, 0.3, 0.14, sx * W / 2, 0, 0, "stone", bevel=0.03)
        b.box(0.14, 0.14, 1.95, sx * W / 2, 0, 0.14, "wood_b", bevel=0.02)
        b.cyl(0.05, 0.05, sx * W / 2, 0, 2.09, "wood_dark", segs=8)
        b.sphere(0.075, sx * W / 2, 0, 2.2, "gold", u=8, v=6)
    b.box(W, 0.1, 0.1, 0, 0, 0.9, "wood", bevel=0.02)
    # teal board with an arched crest
    arch = [(-W / 2 + 0.1, 0), (W / 2 - 0.1, 0), (W / 2 - 0.1, 0.62), (0.45, 0.66)] + \
           [(0.4 * math.cos(math.radians(a)), 0.66 + 0.28 * math.sin(math.radians(a))) for a in range(0, 181, 30)] + \
           [(-0.45, 0.66), (-W / 2 + 0.1, 0.62)]
    b.prism(arch, 0.1, 0, 0, 1.0, METAL)
    b.prism([(p[0] * 1.03, p[1] * 1.03 - 0.015) for p in arch], 0.06, 0, 0.03, 0.99, "wood_dark")
    b.box(1.5, 0.02, 0.44, 0, -0.06, 1.1, "insert_screen", bevel=0)
    emblem(b, 0.2, 0, -0.055, 1.82, "cream")
    b.socket("screen", (0, -0.08, 1.32))
    return done(b, "activity", {"activity": "basketball", "insert": "blank score insert, game-driven"})


def ball_rack():
    b = Builder("ball_rack")
    L = 1.0
    for sx in (-1, 1):
        x = sx * L / 2
        b.box(0.3, 0.3, 0.06, x, 0, 0, "stone", bevel=0.02)
        b.box(0.08, 0.36, 0.95, x, 0, 0.06, "wood_b", bevel=0.02)
        b.box(0.03, 0.26, 0.6, x + sx * 0.045, 0, 0.22, METAL, bevel=0.01)
        with b.at((x + sx * 0.06, 0, 0.5), rotz=90 * sx):
            emblem(b, 0.14, 0, 0, 0, "cream", depth=0.01)
    for zz in (0.26, 0.6):
        b.box(L, 0.34, 0.05, 0, 0, zz, "wood", bevel=0.015)
        b.box(L, 0.04, 0.06, 0, -0.16, zz + 0.05, "wood_dark", bevel=0.01)
    for k in range(3):
        ball(b, 0.12, -0.3 + 0.3 * k, 0, 0.43)
        ball(b, 0.12, -0.3 + 0.3 * k, 0, 0.77)
    return done(b, "activity", {"activity": "basketball"})


def gear_crate():
    b = Builder("gear_crate")
    S, H = 0.6, 0.46
    b.box(S - 0.06, S - 0.06, 0.05, 0, 0, 0.02, "wood_dark", bevel=0.01)
    for i in range(3):
        z = 0.03 + i * (H / 3)
        for sy in (-1, 1):
            b.box(S - 0.04, 0.05, H / 3 - 0.01, 0, sy * (S / 2 - 0.025), z, pick(WOOD, i + sy), bevel=0.012)
        for sx in (-1, 1):
            b.box(0.05, S - 0.1, H / 3 - 0.01, sx * (S / 2 - 0.025), 0, z, pick(WOOD, i + 1 - sx), bevel=0.012)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.09, 0.09, H + 0.03, sx * (S / 2 - 0.02), sy * (S / 2 - 0.02), 0, METAL, bevel=0.015)
    emblem(b, 0.16, -0.1, -S / 2 - 0.01, 0.22, "cream")
    # contents ride above the floor and inside the walls
    ball(b, 0.12, -0.12, 0.08, 0.19)
    b.cyl(0.09, 0.03, 0.14, 0.1, 0.06, "orange", segs=8)
    b.cyl(0.07, 0.32, 0.14, 0.1, 0.09, "orange", segs=8, r2=0.012)
    b.cyl(0.05, 0.05, 0.14, 0.1, 0.22, "white", segs=8, r2=0.04)
    # towel draped over the front wall: inside drop, fold on top, outside drop
    tx = 0.17
    b.box(0.18, 0.025, 0.28, tx, -S / 2 + 0.065, H - 0.24, "cream", bevel=0.008)
    b.box(0.18, 0.11, 0.025, tx, -S / 2 + 0.025, H + 0.03, "cream", bevel=0.008)
    b.box(0.18, 0.025, 0.2, tx, -S / 2 - 0.02, H - 0.15, "cream", bevel=0.008)
    b.box(0.18, 0.027, 0.04, tx, -S / 2 - 0.021, H - 0.12, CUSHION, bevel=0.005)
    return done(b, "prop", {"activity": "basketball", "collider_box": [S, S, H]})


def court_gate():
    """Two lantern posts and a planked leaf on a hinge (part_gate_leaf). Opening 1.1 m."""
    b = Builder("court_gate")
    O = 1.1
    for sx in (-1, 1):
        x = sx * (O / 2 + 0.12)
        b.box(0.36, 0.36, 0.16, x, 0, 0, "stone", bevel=0.03)
        b.box(0.22, 0.22, 1.3, x, 0, 0.16, "wood_b", bevel=0.025)
        b.box(0.28, 0.28, 0.08, x, 0, 1.46, "snow", bevel=0.035)
        b.blob(0.13, 0.13, 0.07, x, 0, 1.54, "snow", subdiv=1)
        b.box(0.22, 0.05, 0.04, x + sx * 0.2, -0.02, 1.2, "iron", bevel=0)
        lantern_head(b, x + sx * 0.32, -0.02, 0.86, 0.75)
    with b.part("gate_leaf", pivot=(-O / 2, 0, 0.1), motion="hinge", axis="z", open_deg=100):
        n = 6
        pw = O / n
        for k in range(n):
            x = -O / 2 + pw * (k + 0.5)
            top = 1.0 + 0.16 * math.cos((x / (O / 2)) * math.pi / 2)  # arched top
            b.box(pw - 0.015, 0.06, top - 0.12, x, 0, 0.12, pick(WOOD, k), bevel=0.012)
        for z in (0.3, 0.85):
            b.box(O - 0.04, 0.03, 0.08, 0, -0.045, z, METAL, bevel=0.008)
            b.box(0.18, 0.035, 0.06, -O / 2 + 0.1, -0.05, z + 0.01, "iron", bevel=0.005)
        emblem(b, 0.16, 0.05, -0.04, 0.58, "cream")
    b.socket("entry", (0, -0.6, 0), rotz=0)
    return done(b, "fence", {"opening_m": O, "swing": "into the court (+Y side), 100 deg",
                             "clear_swing_radius_m": O})


def low_boundary_fence():
    b = Builder("low_boundary_fence")
    L = 2.0
    for sx in (-1, 1):
        snow_post(b, sx * (L / 2 - 0.08), 0, 0, h=0.72, w=0.16)
    for z in (0.3, 0.58):
        b.box(L - 0.16, 0.08, 0.14, 0, 0, z, "wood", bevel=0.02)
        for sx in (-1, 1):
            b.cyl(0.025, 0.02, sx * (L / 2 - 0.26), -0.04, z + 0.07, METAL, segs=6, rot=(90, 0, 0), center=True)
    b.box(L - 0.2, 0.1, 0.05, 0, 0, 0.72, "snow", bevel=0.02)
    for k in range(4):
        b.blob(0.18, 0.12, 0.07, -0.7 + 0.47 * k, 0.12 * (1 if k % 2 else -1), 0.0, "snow", subdiv=1, jitter=0.02)
    return done(b, "fence", {"module_m": L, "note": "snow stays outside the active court"})


# ---------------------------------------------------------------- Drawing Club
OCT_R = 2.7      # base corner radius
FLOOR_Z = 0.3


def oct_pts(R, z=None, rot=22.5):
    return [(R * math.cos(math.radians(rot + 45 * k)), R * math.sin(math.radians(rot + 45 * k))) for k in range(8)]


def sketch_pavilion():
    """Octagonal timber pavilion (frame). Its roof is the removable child sketch_pavilion_roof.
    One facet faces -Y and is the open entrance with stone steps."""
    b = Builder("sketch_pavilion")
    a = OCT_R * math.cos(math.radians(22.5))  # apothem of the base
    # stone base: octagon slab plus chunky footing blocks
    b.prism(oct_pts(OCT_R), FLOOR_Z - 0.06, mat="stone_dark", plane="xy")
    for k, (x, y) in enumerate(oct_pts(OCT_R - 0.05)):
        with b.at((x, y, 0), rotz=22.5 + 45 * k):
            b.box(0.55, 0.62, FLOOR_Z + 0.04, 0, 0, 0, pick(("stone_grey", "rock_grey"), k), bevel=0.05, jitter=0.01)
    # plank floor clipped to the octagon: |x|<=a, |y|<=a, |x|+|y|<=a*sqrt2
    fa = a - 0.12
    pw = 0.24
    n = int(2 * fa / pw)
    hw = lambda y: min(fa, fa * math.sqrt(2) - abs(y))
    for i in range(n):
        y0, y1 = -fa + pw * i + 0.006, -fa + pw * (i + 1) - 0.006
        ys = sorted({y0, y1} | {yb for yb in (-(fa * math.sqrt(2) - fa), fa * math.sqrt(2) - fa) if y0 < yb < y1})
        pts = [(-hw(y), y) for y in ys] + [(hw(y), y) for y in reversed(ys)]  # plank trimmed to the octagon edge
        b.prism(pts, 0.06, z=FLOOR_Z - 0.06, mat=pick(WOOD, i * 3), plane="xy")
    # entrance steps on the -Y facet
    for k, (w, d, h) in enumerate(((1.8, 0.4, FLOOR_Z * 0.5), (1.6, 0.36, FLOOR_Z * 0.97))):
        b.box(w, d, h, 0, -a - 0.2 - 0.36 * (1 - k), 0, pick(("stone", "paving_b"), k), bevel=0.03)
    # posts at the corners, ring beams, low rails, braces
    Rp = OCT_R - 0.32
    posts = oct_pts(Rp)
    H = 2.15
    for k, (x, y) in enumerate(posts):
        with b.at((x, y, FLOOR_Z), rotz=22.5 + 45 * k):
            b.box(0.2, 0.2, H, 0, 0, 0, "wood_b", bevel=0.025)
            b.box(0.28, 0.28, 0.1, 0, 0, 0, "stone_grey", bevel=0.02)
    front = {5, 6}  # the two posts either side of the -Y facet (angles 247.5 and 292.5)
    for k in range(8):
        (x0, y0), (x1, y1) = posts[k], posts[(k + 1) % 8]
        d = Vector((x1 - x0, y1 - y0, 0))
        mid = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))
        rz = math.degrees(math.atan2(d.y, d.x))
        with b.at((mid.x, mid.y, FLOOR_Z), rotz=rz):
            b.box(d.length + 0.2, 0.2, 0.2, 0, 0, H - 0.05, "wood", bevel=0.025)
            for sx in (-1, 1):  # knee braces from post to beam
                b.box(0.08, 0.08, 0.55, sx * (d.length / 2 - 0.24), 0, H - 0.5, "wood_dark", bevel=0.01, rot=(0, -sx * 45, 0))
            if {k, (k + 1) % 8} != front:
                b.box(d.length - 0.18, 0.1, 0.1, 0, 0, 0.55, "wood", bevel=0.015)
                b.box(d.length - 0.18, 0.06, 0.06, 0, 0, 0.25, "wood_dark", bevel=0.01)
    # lanterns on alternate posts, outside, hung from small brackets under the beam
    for k in (0, 2, 3, 7):  # not the front posts, which carry the banners
        x, y = posts[k]
        ux, uy = x / Rp, y / Rp
        b.box(0.04, 0.04, 0.04, x + ux * 0.18, y + uy * 0.18, FLOOR_Z + H - 0.32, "iron", bevel=0)
        beam_from = (x + ux * 0.1, y + uy * 0.1, FLOOR_Z + H - 0.3)
        b.box(0.24, 0.04, 0.04, x + ux * 0.2, y + uy * 0.2, FLOOR_Z + H - 0.3, "iron", bevel=0,
              rot=(0, 0, math.degrees(math.atan2(uy, ux))))
        lantern_head(b, x + ux * 0.32, y + uy * 0.32, FLOOR_Z + H - 0.72, 0.75)
    # coral banners on the two front posts (flutter, hinged on their top rods)
    for k in front:
        x, y = posts[k]
        ux, uy = x / Rp, y / Rp
        bx, by_ = x + ux * 0.02, y - 0.13
        b.box(0.42, 0.03, 0.03, bx, by_, FLOOR_Z + 1.86, "wood_dark", bevel=0.005)
        with b.part(f"banner_{k}", pivot=(bx, by_, FLOOR_Z + 1.86), motion="flutter", amp_deg=8):
            b.box(0.34, 0.02, 0.6, bx, by_, FLOOR_Z + 1.26, BANNER, bevel=0.004)
            b.prism([(-0.17, 0), (0.17, 0), (0, -0.14)], 0.02, bx, by_, FLOOR_Z + 1.26, BANNER)
            emblem(b, 0.14, bx, by_ - 0.015, FLOOR_Z + 1.56, "cream", depth=0.006)
    # bunting across the entrance under the front beam
    (x0, y0), (x1, y1) = posts[5], posts[6]
    flutter_bunting(b, (x0 + 0.12, y0, FLOOR_Z + H - 0.2), (x1 - 0.12, y1, FLOOR_Z + H - 0.2), 5, "bunting", size=0.15, sag=0.16)
    b.socket("table", (0, 0.05, FLOOR_Z))
    b.socket("entry", (0, -a - 0.9, 0), rotz=180)
    b.socket("easel", (Rp - 0.8, 0.6, FLOOR_Z), rotz=60)
    b.socket("notice_board", (-OCT_R - 0.8, 0.8, 0), rotz=-90)
    house = done(b, "building", {"activity": "drawing_telephone", "floor_z_m": FLOOR_Z, "room": "sketch_club",
                                  "voice_room": "own audio room (quiet rounds)", "roof_child": "sketch_pavilion_roof",
                                  "reuse": {"seat": "activities/sketch_stool", "notice_board": "world_misc/notice_board_club"}})

    r = Builder("sketch_pavilion_roof", seed=707)
    ez = FLOOR_Z + H + 0.12
    Re = Rp + 0.55          # eave corner radius
    rise = 1.35
    ae = Re * math.cos(math.radians(22.5))
    slant = math.hypot(ae, rise)
    ang = math.degrees(math.atan2(rise, ae))
    rows = 7
    hw0 = ae * math.tan(math.radians(22.5))  # half eave edge
    for k in range(8):
        with r.at((0, 0, 0), rotz=-90 + 45 * k):  # facet k faces outward along local -Y
            # fascia along the eave
            r.box(2 * hw0 + 0.05, 0.08, 0.14, 0, -ae + 0.05, ez - 0.14, "wood", bevel=0.015)
            # tiles: trapezoids in the facet plane that exactly fill the triangle, row by row
            with r.at((0, -ae, ez), rot=(ang, 0, 0)):
                for row in range(rows):
                    v0, v1 = slant * row / rows, slant * (row + 1) / rows + 0.04
                    h0, h1 = hw0 * (1 - v0 / slant), hw0 * (1 - min(v1, slant) / slant)
                    cols = max(1, round(2 * h0 / 0.36))
                    for c in range(cols):
                        f0, f1 = c / cols, (c + 1) / cols
                        g = 0.012
                        pts = [(-h0 + 2 * h0 * f0 + g, v0), (-h0 + 2 * h0 * f1 - g, v0),
                               (-h1 + 2 * h1 * f1 - g, v1), (-h1 + 2 * h1 * f0 + g, v1)]
                        r.prism(pts, 0.07, z=0.005 * (rows - row), mat=pick(ROOF, row * 3 + c + k), plane="xy", bevel=0.012)
    # hip ridges from each eave corner to the apex
    for (x, y) in oct_pts(Re):
        p0, p1 = Vector((x, y, ez + 0.04)), Vector((0, 0, ez + rise + 0.02))
        d = p1 - p0
        m = (p0 + p1) / 2
        r.box(0.2, 0.14, d.length, m.x, m.y, m.z + 0.03, "roof_b", bevel=0.03, center=True,
              rot=tuple(math.degrees(v) for v in d.to_track_quat("Z", "Y").to_euler()))
    # finial
    top = ez + rise
    r.cyl(0.24, 0.12, 0, 0, top - 0.06, "wood_b", segs=8, bevel=0.015)
    r.cyl(0.16, 0.26, 0, 0, top + 0.06, "wood", segs=8)
    r.cyl(0.13, 0.32, 0, 0, top + 0.32, "wood_b", segs=8, r2=0.0)
    r.sphere(0.05, 0, 0, top + 0.66, "gold", u=6, v=4)
    # snow drifts sitting on a few facets (surface height follows the cone)
    for k, (fa_, fr) in enumerate(((0.0, 0.45), (1.2, 0.7), (2.3, 0.55), (3.6, 0.8), (4.7, 0.5), (5.5, 0.65))):
        ax = math.radians(-90 + 45 * fa_ + 22.5 * (k % 2))
        rad = Re * fr
        zz = ez + rise * (1 - rad / ae) + 0.05
        r.blob(0.3, 0.22, 0.08, rad * math.cos(ax), rad * math.sin(ax), zz, "snow", subdiv=1, jitter=0.02,
               rot=(0, 0, math.degrees(ax) + 90))
    shade_snow(r)
    roof = r.finish(KIT, "roof", {"eave_z": ez, "removable": True})
    attach(roof, house)
    return house


def communal_table():
    """Round club table: 6 seats (plaza/stool at socket_seat_*) and 6 pad spots on the top."""
    b = Builder("communal_table")
    R = 0.85
    # radial plank top: 8 wedge boards with hairline gaps
    for k in range(8):
        a0, a1 = math.radians(45 * k + 1), math.radians(45 * (k + 1) - 1)
        pts = [(0.03 * math.cos((a0 + a1) / 2), 0.03 * math.sin((a0 + a1) / 2))] + \
              [(R * math.cos(a0 + (a1 - a0) * i / 3), R * math.sin(a0 + (a1 - a0) * i / 3)) for i in range(4)]
        b.prism(pts, 0.06, z=TABLE_H - 0.06, mat=pick(WOOD, k), plane="xy")
    b.cyl(0.7, 0.07, 0, 0, TABLE_H - 0.13, "wood_dark", segs=12)
    # thick pedestal on a stepped octagonal foot with four splayed feet
    b.cyl(0.27, TABLE_H - 0.25, 0, 0, 0.12, "wood_b", segs=8, bevel=0.02)
    b.cyl(0.34, 0.08, 0, 0, TABLE_H - 0.21, "wood_dark", segs=8, bevel=0.015)
    b.cyl(0.4, 0.12, 0, 0, 0.0, "wood_dark", segs=8, bevel=0.02)
    for k in range(4):
        with b.at((0, 0, 0), rotz=45 + 90 * k):
            b.box(0.16, 0.66, 0.14, 0, 0.32, 0, "wood_b", bevel=0.025)
            b.box(0.16, 0.18, 0.06, 0, 0.6, 0.0, "wood_dark", bevel=0.015)
    for k in range(6):
        a = math.radians(-90 + 60 * k)
        sx, sy = math.cos(a) * 1.18, math.sin(a) * 1.18
        rz = face_to(sx, sy, 0, 0)
        b.socket(f"seat_{k}", (sx, sy, 0.0), rotz=rz)
        b.socket(f"pad_{k}", (math.cos(a) * 0.55, math.sin(a) * 0.55, TABLE_H), rotz=rz)
    b.socket("centerpiece", (0, 0, TABLE_H))
    return done(b, "activity", {"activity": "drawing_telephone", "seats": 6, "table_h_m": TABLE_H,
                                "reuse": {"seat": "activities/sketch_stool", "centerpiece": "activities/table_lantern"}, "collider": "cylinder r0.85 h0.6"})


def sketch_table():
    """Long club table for bigger groups (8 seats). Seats and tools are separate props at sockets."""
    b = Builder("sketch_table")
    L, W = 3.2, 1.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.1, 0.1, TABLE_H - 0.06, sx * (L / 2 - 0.2), sy * (W / 2 - 0.15), 0, "wood_dark", bevel=0.015)
        b.box(0.08, W - 0.3, 0.06, sx * (L / 2 - 0.2), 0, 0.15, "wood_dark", bevel=0.01)
    b.box(L - 0.4, 0.08, 0.06, 0, 0, 0.15, "wood_dark", bevel=0.01)
    b.box(L - 0.2, W - 0.12, 0.05, 0, 0, TABLE_H - 0.11, "wood_b", bevel=0.01)
    planks(b, L, W, z=TABLE_H - 0.06, plank=0.2, thick=0.06, along="x")
    seats = [(-0.95, -0.85, 180), (0.0, -0.85, 180), (0.95, -0.85, 180),
             (0.95, 0.85, 0), (0.0, 0.85, 0), (-0.95, 0.85, 0),
             (L / 2 + 0.45, 0.0, -90), (-L / 2 - 0.45, 0.0, 90)]
    for k, (sx, sy, rz) in enumerate(seats):
        b.socket(f"seat_{k}", (sx, sy, 0.0), rotz=rz)
        f = Euler((0, 0, math.radians(rz))).to_matrix() @ Vector((0, -1, 0))
        px = max(-L / 2 + 0.25, min(L / 2 - 0.25, sx + f.x * (0.55 if abs(sy) > 0.1 else 0.75)))
        py = max(-W / 2 + 0.2, min(W / 2 - 0.2, sy + f.y * 0.55))
        b.socket(f"pad_{k}", (px, py, TABLE_H), rotz=rz)
    return done(b, "activity", {"activity": "drawing_telephone", "seats": 8, "table_h_m": TABLE_H,
                                "reuse": {"seat": "activities/sketch_stool"}})


def sketch_stool():
    """Octagonal club stool with a teal cushion (the plaza stool doesn't match the sheet)."""
    b = Builder("sketch_stool")
    for k in range(4):
        a = math.radians(45 + 90 * k)
        b.box(0.06, 0.06, 0.34, math.cos(a) * 0.13, math.sin(a) * 0.13, 0, "wood_b", bevel=0.012,
              rot=(math.sin(a) * 7, -math.cos(a) * 7, 0))
    b.cyl(0.15, 0.04, 0, 0, 0.13, "wood_dark", segs=8)
    b.cyl(0.2, 0.06, 0, 0, 0.32, "wood", segs=8, bevel=0.015)
    b.cyl(0.19, 0.07, 0, 0, 0.375, tint("cushion", "teal"), segs=8, bevel=0.025)
    b.socket("seat", (0, 0, 0.445))
    return done(b, "seating", {"seat_h_m": 0.445, "color_variants": ["#207D85", "#E86D58", "#E3A92B"]})


def table_lantern():
    """Communal-table centrepiece: lantern on a wooden block ringed by a little greenery. Separate item."""
    b = Builder("table_lantern")
    b.cyl(0.13, 0.04, 0, 0, 0, "wood_dark", segs=8, bevel=0.01)
    for k in range(9):
        a = 2 * math.pi * k / 9
        b.blob(0.05, 0.04, 0.035, math.cos(a) * 0.14, math.sin(a) * 0.14, 0.03, pick(("leaf", "leaf_dark", "pine"), k), subdiv=1, jitter=0.006)
    for k in range(3):
        a = 2 * math.pi * (k + 0.3) / 3
        b.sphere(0.018, math.cos(a) * 0.16, math.sin(a) * 0.16, 0.06, "petal_red", u=6, v=4)
    lantern_head(b, 0, 0, 0.04, 0.6)
    b.torus(0.03, 0.006, 0, 0, 0.29, "iron", segs=8, ring=3, rot=(90, 0, 0))
    b.socket("light", (0, 0, 0.13))
    return done(b, "tool", {"activity": "drawing_telephone", "light": "warm glow, pulse emission"})


def drawing_pad():
    b = Builder("drawing_pad")
    b.box(0.34, 0.26, 0.02, 0, 0, 0, "wood_dark", bevel=0.005)
    b.box(0.32, 0.23, 0.012, 0, -0.01, 0.02, "insert_screen", bevel=0.003)  # blank, private: drawn by the game
    for k in range(7):
        b.torus(0.014, 0.004, -0.13 + 0.043 * k, 0.11, 0.03, "steel", segs=6, ring=3, rot=(0, 90, 0))
    b.socket("canvas", (0, -0.01, 0.032))
    return done(b, "prop", {"activity": "drawing_telephone", "insert": "blank private pad"})


def pencil_geo(b, x, y, z, rot=(0, 90, 0), body=tint("pencil", "teal"), L=0.19, r=0.011):
    with b.at((x, y, z), rot=rot):
        b.cyl(r, L, 0, 0, -L / 2, body, segs=6)
        b.cyl(r * 1.05, 0.02, 0, 0, L / 2, "steel", segs=6)
        b.cyl(r, 0.022, 0, 0, L / 2 + 0.02, "pink", segs=6)
        b.cyl(r, 0.035, 0, 0, -L / 2 - 0.035, "tan", segs=6, r2=r * 0.3)
        b.cyl(r * 0.3, 0.008, 0, 0, -L / 2 - 0.043, "charcoal", segs=6, r2=0.0)


def pencil():
    b = Builder("pencil")
    pencil_geo(b, 0, 0, 0.011)
    return done(b, "tool", {"activity": "drawing_telephone", "length_m": 0.25})


def eraser():
    b = Builder("eraser")
    b.box(0.08, 0.04, 0.026, 0, 0, 0, "cream", bevel=0.008)
    b.box(0.038, 0.044, 0.03, 0.022, 0, -0.002, tint("eraser_sleeve", "coral"), bevel=0.006)
    return done(b, "tool", {"activity": "drawing_telephone"})


def pencil_cup_geo(b, x, y, z):
    b.cyl(0.055, 0.12, x, y, z, "cream", segs=10, bevel=0.006)
    b.cyl(0.057, 0.04, x, y, z + 0.015, CUSHION, segs=10)
    b.cyl(0.045, 0.005, x, y, z + 0.118, "black", segs=10)
    emblem(b, 0.045, x, y - 0.057, z + 0.08, CUSHION, depth=0.004)
    for k, c in enumerate(("coral", "mustard", "blue", "teal", "purple")):
        a = 2 * math.pi * k / 5
        px, py = x + math.cos(a) * 0.022, y + math.sin(a) * 0.022
        tilt = (math.sin(a) * -10, math.cos(a) * 10, 0)
        b.cyl(0.009, 0.17, px, py, z + 0.02, c, segs=6, rot=tilt)
        tip = Euler([math.radians(t) for t in tilt]).to_matrix() @ Vector((0, 0, 0.17))
        b.cyl(0.009, 0.03, px + tip.x, py + tip.y, z + 0.02 + tip.z, "tan", segs=6, r2=0.002, rot=tilt)


def pencil_cup():
    b = Builder("pencil_cup")
    pencil_cup_geo(b, 0, 0, 0)
    return done(b, "tool", {"activity": "drawing_telephone"})


def paper_tray():
    b = Builder("paper_tray")
    W, D, H = 0.38, 0.3, 0.07
    b.box(W, D, 0.015, 0, 0, 0, "wood_b", bevel=0.004)
    for sy in (-1, 1):
        b.box(W, 0.025, H, 0, sy * (D / 2 - 0.0125), 0, "wood", bevel=0.006)
    for sx in (-1, 1):
        b.box(0.025, D - 0.05, H, sx * (W / 2 - 0.0125), 0, 0, "wood", bevel=0.006)
        for sy in (-1, 1):
            b.box(0.04, 0.04, H + 0.01, sx * (W / 2 - 0.015), sy * (D / 2 - 0.015), 0, METAL, bevel=0.006)
    for k in range(6):
        b.box(W - 0.07, D - 0.07, 0.006, 0.004 * (k % 2), -0.003 * (k % 3), 0.017 + 0.0075 * k,
              pick(("cream", "white"), k), bevel=0, rot=(0, 0, (k % 3 - 1) * 1.5))
    b.socket("paper", (0, 0, 0.065))
    return done(b, "tool", {"activity": "drawing_telephone"})


def table_timer():
    b = Builder("table_timer")
    hexo = [(0.095 * math.cos(math.radians(60 * k)), 0.1 + 0.095 * math.sin(math.radians(60 * k))) for k in range(6)]
    hexi = [(0.07 * math.cos(math.radians(60 * k)), 0.1 + 0.07 * math.sin(math.radians(60 * k))) for k in range(6)]
    b.prism(hexo, 0.06, mat="wood", bevel=0.006)
    b.prism(hexi, 0.012, y=-0.03, mat="insert_screen")  # blank countdown face
    for sx in (-1, 1):
        b.box(0.03, 0.064, 0.07, sx * 0.08, 0, 0.065, tint("timer_band", "coral"), bevel=0.006)
    b.cyl(0.018, 0.02, 0, 0, 0.19, "wood_dark", segs=6)
    b.sphere(0.022, 0, 0, 0.225, tint("timer_band", "coral"), u=8, v=5)
    b.box(0.17, 0.07, 0.02, 0, 0, 0, "wood_dark", bevel=0.006)
    b.socket("face", (0, -0.037, 0.1))
    return done(b, "tool", {"activity": "drawing_telephone", "insert": "blank timer face"})


def easel_display():
    """Tabletop easel for showing the reveal at a seat (floor version: easel_board)."""
    b = Builder("easel_display")
    lean = 12
    with b.at((0, 0, 0), rot=(-lean, 0, 0)):
        for sx in (-1, 1):
            b.box(0.025, 0.025, 0.38, sx * 0.12, 0, 0, "wood", bevel=0.005)
        b.box(0.3, 0.04, 0.02, 0, -0.01, 0.06, "wood_b", bevel=0.005)
        b.box(0.26, 0.015, 0.24, 0, -0.02, 0.08, "wood_dark", bevel=0.004)
        b.box(0.23, 0.006, 0.21, 0, -0.03, 0.095, "insert_screen", bevel=0)
        b.box(0.06, 0.03, 0.04, 0, -0.03, 0.31, METAL, bevel=0.006)
    b.box(0.022, 0.022, 0.32, 0, 0.1, 0, "wood_b", bevel=0.005, rot=(20, 0, 0))
    b.box(0.3, 0.12, 0.02, 0, 0.02, 0, "wood_b", bevel=0.005)
    b.socket("screen", (0, -0.05, 0.2))
    return done(b, "tool", {"activity": "drawing_telephone", "insert": "blank reveal canvas"})


def easel_board():
    b = Builder("easel_board")
    for sx in (-1, 1):
        b.box(0.07, 0.07, 1.6, sx * 0.32, -0.05, 0, "wood", bevel=0.012, rot=(-6, sx * 7, 0))
    b.box(0.07, 0.07, 1.5, 0, 0.32, 0, "wood_b", bevel=0.012, rot=(14, 0, 0))
    b.box(0.9, 0.12, 0.05, 0, -0.1, 0.62, "wood_b", bevel=0.012)
    b.box(0.96, 0.06, 0.76, 0, -0.1, 0.67, tint("frame", "navy"), bevel=0.02)
    b.box(0.86, 0.02, 0.66, 0, -0.14, 0.72, "insert_screen", bevel=0)
    b.box(0.18, 0.05, 0.06, 0, -0.12, 1.42, "wood_dark", bevel=0.01)
    b.socket("screen", (0, -0.16, 1.05))
    return done(b, "activity", {"activity": "drawing_telephone", "use": "reveal display"})


def build():
    basketball_court_half()
    court_tile("court_tile_plain")
    court_tile("court_tile_straight", "straight")
    court_tile("court_tile_corner", "corner")
    court_tile("court_tile_arc", "arc")
    court_tile("court_tile_key", key=True)
    basketball_hoop()
    basketball()
    shooting_spot()
    ready_marker()
    scoreboard()
    ball_rack()
    gear_crate()
    court_gate()
    low_boundary_fence()
    sketch_pavilion()
    communal_table()
    sketch_table()
    sketch_stool()
    table_lantern()
    drawing_pad()
    pencil()
    eraser()
    pencil_cup()
    paper_tray()
    table_timer()
    easel_display()
    easel_board()
