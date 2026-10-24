"""Activities kit: basketball half-court (brief section 14) and the Sketch Club drawing-telephone corner (brief section 15)."""
from common import *

KIT = "activities"
PREVIEW_WIDTH = 16.0

COURT_W, COURT_D = 8.0, 7.0
SLAB = 0.06
RIM = (0.0, 3.0)        # rim centre on the court (x, y)
RIM_Z = 1.72
LINE = 0.06
COURT = tint("court", "teal")
KEY = tint("court_key", "coral")
POLE = tint("pole", "charcoal")
RIMC = tint("rim", "orange")
FRAME = tint("frame", "navy")
TRIM = tint("trim", "coral")


# ---------------------------------------------------------------- helpers
def line(b, x0, y0, x1, y1, z, mat="white", w=LINE):
    L = math.hypot(x1 - x0, y1 - y0)
    b.box(L + w * 0.5, w, 0.012, (x0 + x1) / 2, (y0 + y1) / 2, z, mat, bevel=0,
          rot=(0, 0, math.degrees(math.atan2(y1 - y0, x1 - x0))))


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


def arc(b, cx, cy, R, a0, a1, z, n=14, mat="white", w=LINE):
    pts = [(cx + R * math.cos(a0 + (a1 - a0) * i / n), cy + R * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        line(b, x0, y0, x1, y1, z, mat, w)


def disc(b, cx, cy, R, z, mat, a0=0.0, a1=2 * math.pi, n=16, h=0.01):
    pts = [(cx, cy)] + [(cx + R * math.cos(a0 + (a1 - a0) * i / n), cy + R * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    if a1 - a0 >= 2 * math.pi - 1e-6:
        pts = pts[1:-1]
    b.prism(pts, h, z=z, mat=mat, plane="xy")


def face_to(px, py, tx, ty):
    """rotz (deg) that turns an asset's -Y front toward the target."""
    return math.degrees(math.atan2(tx - px, -(ty - py)))


def ball(b, r, x, y, z, seams=True):
    b.blob(r, r, r, x, y, z, tint("ball", "orange"), subdiv=2)
    if seams:
        for rot in ((0, 0, 0), (90, 0, 0), (90, 0, 90)):
            b.torus(r * 1.005, r * 0.05, x, y, z, "black", segs=16, ring=4, rot=rot)


def stool(b, x, y, h=0.4, top="wood", r=0.19):
    b.cyl(r, 0.06, x, y, h - 0.06, top, segs=8, bevel=0.015)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        b.box(0.05, 0.05, h - 0.06, x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.6, 0, "wood_dark", bevel=0.01,
              rot=(math.sin(a) * 6, -math.cos(a) * 6, 0))
    b.cyl(r * 0.62, 0.03, x, y, h * 0.35, "wood_dark", segs=8, cap=True)


# ---------------------------------------------------------------- basketball
def basketball_court_half():
    b = Builder("basketball_court_half")
    W, D = COURT_W, COURT_D
    z = SLAB
    b.box(W + 0.7, D + 0.7, SLAB - 0.012, 0, 0, 0, "paving_b", bevel=0.04)
    b.box(W + 0.1, D + 0.1, SLAB, 0, 0, 0, COURT, bevel=0.02)
    top = z + 0.001
    # coral key and centre half-circle
    key_w, ft_y = 2.0, 1.1
    b.box(key_w, COURT_D / 2 - ft_y, 0.008, 0, (COURT_D / 2 + ft_y) / 2, top, KEY, bevel=0)
    disc(b, 0, -D / 2, 0.9, top, KEY, 0, math.pi)
    lz = top + 0.008
    # boundary
    for (x0, y0, x1, y1) in ((-W / 2, -D / 2, W / 2, -D / 2), (W / 2, -D / 2, W / 2, D / 2),
                             (W / 2, D / 2, -W / 2, D / 2), (-W / 2, D / 2, -W / 2, -D / 2)):
        line(b, x0, y0, x1, y1, lz)
    # key outline and free-throw circle
    for sx in (-1, 1):
        line(b, sx * key_w / 2, ft_y, sx * key_w / 2, D / 2, lz)
    line(b, -key_w / 2, ft_y, key_w / 2, ft_y, lz)
    arc(b, 0, ft_y, 0.7, 0, 2 * math.pi, lz, n=18)
    # three-point line
    R, cx = 3.0, 2.85
    dy = math.sqrt(R * R - cx * cx)
    for sx in (-1, 1):
        line(b, sx * cx, RIM[1] - dy, sx * cx, D / 2, lz)
    arc(b, RIM[0], RIM[1], R, math.atan2(-dy, -cx), math.atan2(-dy, cx), lz, n=22)
    # centre half circle outline
    arc(b, 0, -D / 2, 0.9, 0, math.pi, lz, n=12)
    # marked shooting spots
    for k, a in enumerate((-150, -115, -65, -30)):
        px, py = RIM[0] + 2.4 * math.cos(math.radians(a)), RIM[1] + 2.4 * math.sin(math.radians(a))
        b.cyl(0.2, 0.012, px, py, lz, "white", segs=10)
        b.cyl(0.14, 0.014, px, py, lz, tint("court_spot", "mustard"), segs=10)
        b.socket(f"shoot_{k}", (px, py, top), rotz=face_to(px, py, *RIM))
    for k in range(4):
        b.socket(f"spectator_{k}", (-1.8 + 1.2 * k, -D / 2 - 0.9, 0), rotz=180)
    b.socket("hoop", (0, D / 2 + 0.25, top), rotz=0)
    b.socket("scoreboard", (W / 2 + 0.9, D / 2 - 1.0, 0), rotz=90)
    return done(b, "activity", {
        "activity": "basketball", "court_m": [W, D], "rim_xy": list(RIM), "rim_z": RIM_Z,
        "note": "place basketball_hoop at socket_hoop; keep snowbanks outside the paving apron",
    })


def basketball_hoop():
    """Pole at the origin (behind the baseline); board and rim reach toward -Y over the court."""
    b = Builder("basketball_hoop")
    b.box(0.55, 0.55, 0.12, 0, 0.1, 0, "charcoal", bevel=0.03)
    b.cyl(0.07, 2.25, 0, 0.1, 0.1, POLE, segs=8)
    b.box(0.1, 0.45, 0.1, 0, -0.12, 2.0, POLE, bevel=0.02)
    b.box(0.08, 0.3, 0.08, 0, -0.08, 1.7, POLE, bevel=0.015, rot=(-40, 0, 0))
    # backboard
    by = -0.38
    b.box(1.14, 0.06, 0.72, 0, by, 1.66, "white", bevel=0.02)
    for (sx, sy, x, z) in ((1.14, 0.075, 0, 2.35), (1.14, 0.075, 0, 1.66), (0.06, 0.075, -0.57, 1.66), (0.06, 0.075, 0.57, 1.66)):
        b.box(sx, sy, 0.05 if sx > 1 else 0.74, x, by, z - (0.025 if sx > 1 else 0), POLE, bevel=0.01)
    for (sx, x, z) in ((0.44, 0, 1.97), (0.44, 0, 1.76), (0.04, -0.2, 1.76), (0.04, 0.2, 1.76)):
        b.box(sx, 0.02, 0.04 if sx > 0.1 else 0.25, x, by - 0.035, z, tint("board_mark", "coral"), bevel=0)
    # rim, bracket and net
    ry = by - 0.27
    b.box(0.1, 0.12, 0.05, 0, by - 0.07, RIM_Z - 0.03, RIMC, bevel=0.01)
    b.torus(0.21, 0.018, 0, ry, RIM_Z, RIMC, segs=16, ring=6)
    n = 10
    for k in range(n):
        a = 2 * math.pi * k / n
        for d in (-1, 1):
            a2 = a + d * math.pi / n
            p0 = (0.2 * math.cos(a), ry + 0.2 * math.sin(a), RIM_Z - 0.01)
            p1 = (0.14 * math.cos(a2), ry + 0.14 * math.sin(a2), RIM_Z - 0.34)
            rope_between(b, p0, p1, sag=0.0, r=0.006, segs=1, mat="white")
    b.torus(0.17, 0.008, 0, ry, RIM_Z - 0.17, "white", segs=12, ring=4)
    b.torus(0.14, 0.008, 0, ry, RIM_Z - 0.34, "white", segs=12, ring=4)
    b.socket("rim", (0, ry, RIM_Z))
    return done(b, "activity", {"activity": "basketball", "rim_radius_m": 0.21})


def basketball():
    b = Builder("basketball")
    ball(b, 0.12, 0, 0, 0.12)
    return done(b, "projectile", {"radius_m": 0.12})


def scoreboard():
    b = Builder("scoreboard")
    for sx in (-1, 1):
        b.box(0.3, 0.3, 0.1, sx * 0.7, 0, 0, "stone_dark", bevel=0.02)
        b.box(0.12, 0.12, 1.1, sx * 0.7, 0, 0.1, "charcoal", bevel=0.02)
    b.box(1.8, 0.16, 0.95, 0, 0, 1.0, FRAME, bevel=0.04)
    b.box(1.86, 0.2, 0.12, 0, 0, 1.95, TRIM, bevel=0.03)
    b.box(1.55, 0.03, 0.62, 0, -0.08, 1.12, "insert_screen", bevel=0)
    for sx in (-0.82, 0.82):
        b.sphere(0.05, sx, -0.1, 2.0, "bulb", u=6, v=4)
    snow_cap(b, 1.84, 0.22, 0, 0, 2.07, h=0.05, lumps=False)
    b.socket("screen", (0, -0.1, 1.43))
    return done(b, "activity", {"activity": "basketball"})


def ball_rack():
    b = Builder("ball_rack")
    L = 1.0
    for sx in (-1, 1):
        x = sx * L / 2
        b.box(0.05, 0.05, 0.75, x, -0.18, 0, "charcoal", bevel=0.01, rot=(-8, 0, 0))
        b.box(0.05, 0.05, 0.75, x, 0.18, 0, "charcoal", bevel=0.01, rot=(8, 0, 0))
        b.box(0.05, 0.42, 0.05, x, 0, 0.08, "charcoal", bevel=0.01)
    for (yy, zz) in ((-0.12, 0.3), (0.12, 0.3), (-0.08, 0.62), (0.08, 0.62)):
        b.box(L + 0.06, 0.035, 0.035, 0, yy, zz, "steel", bevel=0.008)
    for k in range(3):
        ball(b, 0.12, -0.32 + 0.32 * k, 0, 0.42)
    for k in range(3):
        ball(b, 0.12, -0.32 + 0.32 * k, 0, 0.74)
    return done(b, "activity", {"activity": "basketball"})


# ---------------------------------------------------------------- Sketch Club (drawing telephone)
TABLE_H = 0.6
SEATS = (tint("seat_a", "coral"), tint("seat_b", "teal_light"), tint("seat_c", "mustard"), tint("seat_d", "sage"))
PINS = (tint("pin_a", "coral"), tint("pin_b", "teal"), tint("pin_c", "mustard"))
ROOFT = tint("roof", "roof")
SIGN_FRAME = tint("sign_frame", "wood_dark")


def drawing_pad_geo(b, x, y, z, rotz=0.0):
    with b.at((x, y, z), rotz=rotz):
        b.box(0.34, 0.26, 0.02, 0, 0, 0, "wood_dark", bevel=0.005)
        b.box(0.32, 0.23, 0.012, 0, -0.01, 0.02, "cream", bevel=0.003)
        for k in range(7):
            b.torus(0.014, 0.004, -0.13 + 0.043 * k, 0.11, 0.03, "steel", segs=6, ring=3, rot=(0, 90, 0))
        b.cyl(0.009, 0.2, 0.2, 0.0, 0.012, "mustard", segs=6, rot=(90, 0, 10))


def pencil_cup_geo(b, x, y, z):
    b.cyl(0.055, 0.12, x, y, z, tint("cup", "teal"), segs=8, bevel=0.006)
    b.cyl(0.045, 0.005, x, y, z + 0.118, "black", segs=8)
    cols = ("coral", "mustard", "blue", "green", "purple")
    for k, c in enumerate(cols):
        a = 2 * math.pi * k / len(cols)
        px, py = x + math.cos(a) * 0.022, y + math.sin(a) * 0.022
        tilt = (math.sin(a) * -10, math.cos(a) * 10, 0)
        b.cyl(0.009, 0.17, px, py, z + 0.02, c, segs=6, rot=tilt)
        tip = Euler([math.radians(t) for t in tilt]).to_matrix() @ Vector((0, 0, 0.17))
        b.cyl(0.009, 0.03, px + tip.x, py + tip.y, z + 0.02 + tip.z, "tan", segs=6, r2=0.002, rot=tilt)


def sketch_table():
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
        stool(b, sx, sy, 0.42, top=SEATS[k % 4])
        b.socket(f"seat_{k}", (sx, sy, 0.42), rotz=rz)
        # pad spot: a cream placemat on the table edge in front of the seat
        f = Euler((0, 0, math.radians(rz))).to_matrix() @ Vector((0, -1, 0))
        px = sx + f.x * (0.55 if abs(sy) > 0.1 else 0.75)
        py = sy + f.y * 0.55
        px = max(-L / 2 + 0.25, min(L / 2 - 0.25, px))
        py = max(-W / 2 + 0.2, min(W / 2 - 0.2, py))
        b.box(0.36, 0.27, 0.006, px, py, TABLE_H, "cream", bevel=0, rot=(0, 0, rz))
        b.socket(f"pad_{k}", (px, py, TABLE_H + 0.006), rotz=rz)
    pencil_cup_geo(b, -0.5, 0.0, TABLE_H)
    pencil_cup_geo(b, 0.5, 0.0, TABLE_H)
    return done(b, "activity", {"activity": "drawing_telephone", "seats": 8, "table_h_m": TABLE_H})


def drawing_pad():
    b = Builder("drawing_pad")
    drawing_pad_geo(b, 0, 0, 0)
    return done(b, "prop", {"activity": "drawing_telephone"})


def pencil_cup():
    b = Builder("pencil_cup")
    pencil_cup_geo(b, 0, 0, 0)
    return done(b, "prop", {"activity": "drawing_telephone"})


def easel_board():
    b = Builder("easel_board")
    for sx in (-1, 1):
        b.box(0.07, 0.07, 1.6, sx * 0.32, -0.05, 0, "wood", bevel=0.012, rot=(-6, sx * 7, 0))
    b.box(0.07, 0.07, 1.5, 0, 0.32, 0, "wood_b", bevel=0.012, rot=(14, 0, 0))
    b.box(0.9, 0.12, 0.05, 0, -0.1, 0.62, "wood_b", bevel=0.012)
    b.box(0.96, 0.06, 0.76, 0, -0.1, 0.67, FRAME, bevel=0.02)
    b.box(0.86, 0.02, 0.66, 0, -0.14, 0.72, "insert_screen", bevel=0)
    b.box(0.18, 0.05, 0.06, 0, -0.12, 1.42, "wood_dark", bevel=0.01)
    b.socket("screen", (0, -0.16, 1.05))
    return done(b, "activity", {"activity": "drawing_telephone", "use": "reveal display"})


def sketch_pavilion():
    """Open timber pavilion that hosts sketch_table at socket_table. Front (-Y) is open."""
    b = Builder("sketch_pavilion")
    W, D, H = 5.2, 4.2, 2.0
    z0 = 0.22
    b.box(W + 0.5, D + 0.5, z0 - 0.06, 0, 0, 0, "stone_dark", bevel=0.04)
    stone_row(b, W + 0.5, z0 - 0.06, 0.12, x0=-(W + 0.5) / 2, y=-(D + 0.5) / 2 + 0.06, z=0, unit=0.5)
    planks(b, W + 0.3, D + 0.3, z=z0 - 0.06, plank=0.24, thick=0.06, along="y")
    b.box(1.8, 0.4, z0 * 0.5, 0, -(D + 0.5) / 2 - 0.2, 0, "stone", bevel=0.03)
    # posts and beams
    px = [-W / 2, 0, W / 2]
    for x in px:
        for y in (-D / 2, D / 2):
            b.box(0.2, 0.2, 0.12, x, y, z0, "stone_grey", bevel=0.02)
            b.box(0.16, 0.16, H, x, y, z0, "wood_b", bevel=0.02)
    for y in (-D / 2, D / 2):
        b.box(W + 0.3, 0.2, 0.2, 0, y, z0 + H, "wood", bevel=0.025)
    for x in px:
        b.box(0.18, D + 0.3, 0.18, x, 0, z0 + H + 0.02, "wood_dark", bevel=0.02)
    # corner braces
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            sx = 1 if x < 0 else -1
            b.box(0.08, 0.08, 0.6, x + sx * 0.22, y, z0 + H - 0.48, "wood_dark", bevel=0.01, rot=(0, sx * 45, 0))
    # gable faces the front (-Y) like the Sketch Club in the world map: ridge runs along Y
    with b.at((0, 0, 0), rotz=90):
        gable_roof(b, D + 0.1, W + 0.1, 1.4, z0 + H + 0.2, overhang=0.3, gable_wall="wood_c", trim="wood_dark", mats=(ROOFT,) * 3)
    # snow along the ridge (roofs carry snow caps in the world concept)
    for k in range(8):
        y = -D / 2 + D * (k + 0.5) / 8
        b.blob(0.13, 0.3, 0.06, b.rng.uniform(-0.04, 0.04), y, z0 + H + 0.2 + 1.4 + 0.08, "snow", subdiv=1, jitter=0.02)
    # back half-wall with pinned drawings (the reveal wall) and side rails
    b.box(W, 0.12, 0.85, 0, D / 2 - 0.02, z0, "wood_c", bevel=0.02)
    b.box(W + 0.05, 0.16, 0.06, 0, D / 2 - 0.02, z0 + 0.85, "wood_dark", bevel=0.015)
    for k, c in enumerate(("cream", "white", "cream", "white", "cream")):
        x = -1.8 + 0.9 * k
        b.box(0.42, 0.02, 0.32, x, D / 2 - 0.09, z0 + 0.35 + 0.05 * (k % 2), c, bevel=0, rot=(0, (k % 3 - 1) * 4, 0))
        b.sphere(0.02, x, D / 2 - 0.11, z0 + 0.66 + 0.05 * (k % 2), pick(PINS, k), u=6, v=4)
    for sx in (-1, 1):
        x = sx * W / 2
        b.box(0.08, D, 0.08, x, 0, z0 + 0.75, "wood", bevel=0.015)
        b.box(0.08, D, 0.08, x, 0, z0 + 0.35, "wood", bevel=0.015)
    # sign mounted on the front gable
    # mounted flush on the gable's vertical beam (beam front face at -D/2 - 0.11)
    b.box(1.9, 0.08, 0.5, 0, -D / 2 - 0.15, z0 + H + 0.32, SIGN_FRAME, bevel=0.02)
    b.box(1.76, 0.02, 0.38, 0, -D / 2 - 0.2, z0 + H + 0.38, "insert_sign", bevel=0)
    # warm string lights between the front posts
    for x0, x1 in ((-W / 2, 0), (0, W / 2)):
        pts = rope_between(b, (x0, -D / 2 - 0.12, z0 + H - 0.05), (x1, -D / 2 - 0.12, z0 + H - 0.05), sag=0.22, r=0.01, segs=8, mat="black")
        for p in pts[1:-1]:
            b.sphere(0.04, p.x, p.y, p.z - 0.05, "bulb", u=6, v=4)
    # planters by the entrance
    for sx in (-1, 1):
        planter_box(b, 0.7, 0.32, 0.3, x=sx * 1.6, y=-(D + 0.5) / 2 - 0.25, z=0)
    b.socket("table", (0, 0.1, z0))
    b.socket("entry", (0, -(D + 0.5) / 2 - 0.6, 0), rotz=180)
    b.socket("easel", (W / 2 - 0.6, D / 2 - 0.6, z0), rotz=45)
    return done(b, "building", {"activity": "drawing_telephone", "floor_z_m": z0, "room": "sketch_club",
                                       "voice_room": "own audio room (quiet rounds)"})


def build():
    basketball_court_half()
    basketball_hoop()
    basketball()
    scoreboard()
    ball_rack()
    sketch_pavilion()
    sketch_table()
    drawing_pad()
    pencil_cup()
    easel_board()
