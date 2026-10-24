"""Cinema exterior kit (concept 12) plus parts shared with cinema_lobby and cinema_auditorium.

Socket rotz convention: 0 means the occupant faces -Y (the asset's front).
"""
from common import *

KIT = "cinema"
PREVIEW_WIDTH = 16.0

# Cinema-only colours. Registered here so the shared palette file stays untouched.
PALETTE.update({
    "teal_deep": ("#1F5A66", 0.85, 0), "taupe": ("#B49C84", 0.9, 0), "taupe_dark": ("#9A8470", 0.9, 0),
    "floor_dark": ("#2F3545", 0.9, 0), "floor_dark_b": ("#383F51", 0.9, 0),
    "velvet": ("#C8362F", 0.95, 0), "seat_red": ("#E0483D", 0.9, 0), "seat_red_dark": ("#B93A33", 0.9, 0),
    "brass": ("#E3A73A", 0.35, 0), "insert_poster_b": ("#5B3F8F", 0.7, 0),
    "popcorn": ("#FFF0B8", 0.9, 0), "popcorn_b": ("#F7D774", 0.9, 0),
    # graphic inserts: dimmer than the shared insert_screen so previews don't blow out to white
    "insert_cinema_screen": ("#B7C2CF", 0.6, 0.12), "insert_kiosk": ("#2A3A4C", 0.5, 0.35),
})
BULB_SPACING = 0.19

# Engine-recolourable roles (see common.tint). One mesh, any colour.
TRIM = tint("trim", "coral")                 # facade bands, parapet, light strips
MARQUEE = tint("marquee_frame", "coral")
DOOR = tint("door", "teal")
CARPET = tint("carpet", "velvet")            # carpets and stair runner
ROPE = tint("rope", "velvet")
UPHOLSTERY = tint("upholstery", "seat_red")
CURTAIN = tint("curtain", "velvet")
WALL = tint("wall", "teal_deep")
AWNING_A, AWNING_B = tint("awning", "red"), tint("awning_alt", "cream")
BANNER = tint("banner", "red")


# ---------------------------------------------------------------- shared parts
def poly_perimeter(pts, spacing):
    """Evenly spaced points along a closed polygon outline."""
    out = []
    for a, c in zip(pts, pts[1:] + pts[:1]):
        a, c = Vector(a), Vector(c)
        n = max(1, round((c - a).length / spacing))
        out += [a.lerp(c, i / n) for i in range(n)]
    return out


def shrink(pts, d):
    """Inset a convex outline by moving each point toward the centroid by d."""
    c = sum((Vector(p) for p in pts), Vector((0, 0))) / len(pts)
    return [tuple(Vector(p) + (c - Vector(p)).normalized() * d) for p in pts]


def stanchion(b, x=0, y=0, z=0, h=0.62):
    """Brass queue post: weighted base, column, ball top, rope hooks."""
    b.cyl(0.13, 0.04, x, y, z, "brass", segs=10, bevel=0.01)
    b.cyl(0.09, 0.05, x, y, z + 0.04, "brass", segs=10, r2=0.05)
    b.cyl(0.032, h - 0.12, x, y, z + 0.09, "brass", segs=8)
    b.cyl(0.05, 0.04, x, y, z + h - 0.06, "brass", segs=8)
    b.sphere(0.055, x, y, z + h, "brass", u=8, v=6)


def velvet_rope(b, p0, p1, sag=0.14):
    rope_between(b, p0, p1, sag=sag, r=0.026, segs=8, mat=ROPE)
    for p in (p0, p1):
        b.sphere(0.035, p[0], p[1], p[2], "brass", u=6, v=4)


def reel(b, x, y, z, r=0.34, depth=0.1):
    """Film-reel emblem facing -Y, centred at (x, z) on a face at y."""
    b.cyl(r + 0.04, depth, x, y, z, "brass", segs=20, rot=(90, 0, 0), center=True)
    b.cyl(r, depth, x, y - 0.03, z, "charcoal", segs=20, rot=(90, 0, 0), center=True)
    for i in range(5):
        a = math.radians(90 + 72 * i)
        b.cyl(r * 0.24, 0.04, x + math.cos(a) * r * 0.55, y - depth / 2 - 0.03, z + math.sin(a) * r * 0.55,
              "cream", segs=10, rot=(90, 0, 0), center=True)
    b.cyl(r * 0.16, 0.05, x, y - depth / 2 - 0.035, z, "brass", segs=10, rot=(90, 0, 0), center=True)


def marquee(b, w=2.9, h=0.86, x=0, y=0, z=0, bump=0.26, depth=0.22):
    """Lit marquee sign whose front is at y (faces -Y), bottom at z.
    Backing in coral, an inset sign face (insert_marquee) and a ring of bulbs."""
    k = 9
    top = [(w / 2 - 0.32 - (w - 0.64) * i / k,
            h + bump * math.sin(math.pi * i / k)) for i in range(k + 1)]
    outline = [(-w / 2, 0.06), (-w / 2 + 0.06, 0), (w / 2 - 0.06, 0), (w / 2, 0.06),
               (w / 2, h - 0.08), (w / 2 - 0.12, h)] + top + [(-w / 2 + 0.12, h), (-w / 2, h - 0.08)]
    with b.at((x, y + depth / 2, z)):
        b.prism(outline, depth, mat=MARQUEE, bevel=0.02)
        inner = shrink(outline, 0.17)
        b.prism(inner, 0.05, y=-depth / 2 - 0.01, mat="insert_marquee")
        b.prism(shrink(outline, 0.11), 0.03, y=-depth / 2 + 0.005, mat="mustard")
        for p in poly_perimeter(shrink(outline, 0.07), BULB_SPACING):
            b.sphere(0.042, p.x, -depth / 2 - 0.02, p.y, "bulb", u=6, v=4)


def poster_frame(b, x=0, y=0, z=0, w=0.86, h=1.28, insert="insert_poster", frame="brass"):
    """Wall poster in a deep frame; back against a wall face at y, faces -Y, bottom at z."""
    b.box(w, 0.1, h, x, y - 0.05, z, frame, bevel=0.025, center=False)
    b.box(w - 0.14, 0.04, h - 0.14, x, y - 0.11, z + 0.07, "navy", bevel=0.01)
    b.box(w - 0.2, 0.04, h - 0.2, x, y - 0.12, z + 0.1, insert, bevel=0)


def topiary(b, x=0, y=0, z=0, s=1.0):
    """Cone evergreen in a wooden box planter (flanks the cinema entrance)."""
    w = 0.48 * s
    for i in range(2):
        for sy in (-1, 1):
            b.box(w, 0.05, 0.19 * s, x, y + sy * (w / 2 - 0.025), z + i * 0.2 * s, pick(WOOD, i + sy), bevel=0.01)
            b.box(0.05, w, 0.19 * s, x + sy * (w / 2 - 0.025), y, z + i * 0.2 * s, pick(WOOD, i - sy), bevel=0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.07, 0.07, 0.42 * s, x + sx * (w / 2 - 0.02), y + sy * (w / 2 - 0.02), z, "wood_b", bevel=0.012)
    b.box(w - 0.08, w - 0.08, 0.03, x, y, z + 0.36 * s, "soil", bevel=0)
    for i, (r, zz) in enumerate(((0.24, 0.38), (0.19, 0.62), (0.13, 0.84))):
        b.cyl(r * s, 0.42 * s, x, y, z + zz * s, pick(("pine", "pine_b"), i), segs=7, r2=0.03 * s, jitter=0.01)


def potted_plant(b, x=0, y=0, z=0, s=1.0, pot="terracotta", leaf=("leaf", "leaf_dark", "leaf_b"), berries=False):
    """Chunky pot with a faceted leafy mound (lobby and auditorium dressing)."""
    b.cyl(0.17 * s, 0.26 * s, x, y, z, pot, segs=7, r2=0.13 * s, bevel=0.01)
    b.cyl(0.19 * s, 0.05 * s, x, y, z + 0.24 * s, pot, segs=7, bevel=0.01)
    b.cyl(0.15 * s, 0.02, x, y, z + 0.27 * s, "soil", segs=7)
    rng = b.rng
    for i in range(7):
        a = 2 * math.pi * i / 7
        r = 0.11 * s
        b.blob(r, r, r * 1.2, x + math.cos(a) * 0.1 * s, y + math.sin(a) * 0.1 * s,
               z + (0.36 + rng.uniform(0, 0.08)) * s, pick(leaf, i), jitter=r * 0.12)
    b.blob(0.13 * s, 0.13 * s, 0.15 * s, x, y, z + 0.5 * s, leaf[0], jitter=0.01)
    if berries:
        for i in range(5):
            a = 2 * math.pi * i / 5 + 0.3
            b.sphere(0.022 * s, x + math.cos(a) * 0.14 * s, y + math.sin(a) * 0.14 * s, z + 0.45 * s, "red", u=6, v=4)


def light_strip(b, x, y, z, h=1.4, w=0.2):
    """Vertical coral strip with a column of bulbs, mounted on a face at y."""
    b.box(w, 0.1, h, x, y - 0.05, z, TRIM, bevel=0.02)
    b.box(w - 0.08, 0.03, h - 0.08, x, y - 0.11, z + 0.04, "mustard", bevel=0)
    n = int(h / BULB_SPACING)
    for i in range(n):
        b.sphere(0.04, x, y - 0.13, z + 0.1 + i * (h - 0.2) / (n - 1), "bulb", u=6, v=4)


# --------------------------------------------------------------- exterior parts
W, D, H = 6.8, 5.6, 3.6          # shell footprint and wall height
FLOOR = 0.4                       # interior floor / entrance landing height
OPEN_W, OPEN_H = 2.0, 2.35        # entrance opening (above FLOOR)


def shell(b):
    """Four walls with a grey stone base band, coral parapet band and entrance opening."""
    t = 0.3
    ow, oz = OPEN_W, FLOOR + OPEN_H
    hw = H - 0.24      # walls stop under the coral parapet instead of running through it
    # front wall in three pieces around the opening
    side_w = (W - ow) / 2
    for sx in (-1, 1):
        b.box(side_w, t, hw, sx * (ow / 2 + side_w / 2), -D / 2 + t / 2, 0, "plaster", bevel=0.03)
    b.box(ow, t, hw - oz, 0, -D / 2 + t / 2, oz, "plaster", bevel=0.03)
    b.box(W, t, hw, 0, D / 2 - t / 2, 0, "plaster", bevel=0.03)
    for sx in (-1, 1):
        b.box(t, D - 2 * t, hw, sx * (W / 2 - t / 2), 0, 0, "plaster", bevel=0.03)
    # grey base band (skips the doorway) and blocky coral parapet band
    bh = 0.48
    for sx in (-1, 1):
        b.box(side_w + 0.06, t + 0.08, bh, sx * (ow / 2 + side_w / 2 + 0.03), -D / 2 + t / 2, 0, "stone_grey", bevel=0.03)
        b.box(t + 0.08, D + 0.08, bh, sx * (W / 2 - t / 2), 0, 0, "stone_grey", bevel=0.03)
    b.box(W + 0.08, t + 0.08, bh, 0, D / 2 - t / 2, 0, "stone_grey", bevel=0.03)
    # floor slab inside, level with the entrance landing
    b.box(W - 2 * t, D - 2 * t, FLOOR, 0, 0, 0, "stone_dark", bevel=0.01)
    # coral band at the top, made of chunky blocks so it reads as masonry
    for side in range(4):
        L = W if side < 2 else D
        n = max(2, round(L / 1.2))
        for i in range(n):
            o = -L / 2 + L * (i + 0.5) / n
            m = TRIM
            if side < 2:
                b.box(L / n, t + 0.12, 0.24, o, (-1 if side == 0 else 1) * (D / 2 - t / 2), H - 0.24, m, bevel=0.03)
            else:
                b.box(t + 0.12, L / n, 0.24, (-1 if side == 2 else 1) * (W / 2 - t / 2), o, H - 0.24, m, bevel=0.03)
    # shallow pilasters on the long sides break up the flat walls
    for sx in (-1, 1):
        for yy in (-D / 2 + 1.9, D / 2 - 1.9):
            b.box(0.08, 0.5, H - 0.75, sx * (W / 2 + 0.02), yy, bh, "plaster_shade", bevel=0.02)


def roof_cap(b, z=0.0):
    """Flat roof slab with coral rim and a rooftop vent box."""
    t = 0.3
    b.box(W - 2 * t + 0.02, D - 2 * t + 0.02, 0.12, 0, 0, z + H - 0.32, "stone_grey", bevel=0.01)
    for sx in (-1, 1):
        b.box(W, 0.2, 0.14, 0, sx * (D / 2 - 0.1), z + H, TRIM, bevel=0.03)
        b.box(0.2, D - 0.4, 0.14, sx * (W / 2 - 0.1), 0, z + H, TRIM, bevel=0.03)
    b.box(1.3, 0.9, 0.5, 1.6, 1.4, z + H - 0.2, "chimney", bevel=0.04)
    b.box(1.36, 0.96, 0.08, 1.6, 1.4, z + H + 0.28, "chimney_cap", bevel=0.02)
    for i in range(3):
        b.box(0.9, 0.04, 0.05, 1.6, 1.4 - 0.47, z + H - 0.05 + i * 0.12, "chimney_cap", bevel=0)


def facade(b):
    """Stepped art-deco front. Its back is the plane y=0 (the shell's front face) and it projects to -Y.
    Layout from the centre out: door opening, lantern piers, recessed poster bays under
    speed lines, outer pilasters with bulb strips. A stepped crown carries the reel."""
    ow = OPEN_W
    lz = FLOOR + OPEN_H
    for sx in (-1, 1):
        # narrow piers beside the doors
        px = sx * (ow / 2 + 0.18)
        b.box(0.36, 0.42, 4.0, px, -0.21, 0, "plaster", bevel=0.03)
        b.box(0.42, 0.48, 0.5, px, -0.22, 0, "stone_grey", bevel=0.03)
        b.box(0.44, 0.5, 0.13, px, -0.23, 4.0, TRIM, bevel=0.03)
        # poster bay: shell wall shows through; speed lines and a capped parapet above it
        bx = sx * (ow / 2 + 0.36 + 0.6)
        b.box(1.2, 0.16, 0.5, bx, -0.08, 0, "stone_grey", bevel=0.03)
        b.box(1.2, 0.24, 3.45 - 2.3, bx, -0.12, 2.3, "plaster", bevel=0.03)
        for i in range(3):
            b.box(1.22, 0.3, 0.09, bx, -0.15, 2.45 + i * 0.24, TRIM, bevel=0.02)
        b.box(1.3, 0.32, 0.13, bx, -0.15, 3.45, TRIM, bevel=0.03)
        # outer pilasters with bulb strips
        ox = sx * (ow / 2 + 0.36 + 1.2 + 0.22)
        b.box(0.44, 0.4, 3.85, ox, -0.2, 0, "plaster", bevel=0.03)
        b.box(0.5, 0.46, 0.5, ox, -0.21, 0, "stone_grey", bevel=0.03)
        b.box(0.52, 0.48, 0.13, ox, -0.22, 3.85, TRIM, bevel=0.03)
        light_strip(b, ox, -0.4, 1.9, h=1.8)
    # lintel above the opening carries the marquee
    b.box(ow + 0.02, 0.32, 4.0 - lz, 0, -0.16, lz, "plaster", bevel=0.03)
    # stepped crown, each step capped in coral
    steps = ((3.0, 4.0, 0.42), (2.1, 4.42, 0.42), (1.3, 4.84, 0.4))
    for i, (sw, sz, sh) in enumerate(steps):
        b.box(sw, 0.34 - i * 0.02, sh, 0, -0.17, sz, "plaster", bevel=0.03)
        b.box(sw + 0.1, 0.4 - i * 0.02, 0.12, 0, -0.19, sz + sh - 0.04, TRIM, bevel=0.03)
    reel(b, 0, -0.36, 4.62, r=0.38)
    # coral reveal around the doorway
    for sx in (-1, 1):
        b.box(0.08, 0.36, OPEN_H, sx * (ow / 2 - 0.02), -0.18, FLOOR, TRIM, bevel=0.015)


def double_doors(b, w=1.9, h=2.25, x=0, y=0, z=0):
    """Pair of teal doors with big warm glass panes and brass ring handles; front at y."""
    b.box(w + 0.16, 0.12, 0.12, x, y + 0.06, z + h, DOOR, bevel=0.02)
    for sx in (-1, 1):
        b.box(0.1, 0.12, h, x + sx * (w / 2 + 0.03), y + 0.06, z, DOOR, bevel=0.02)
        cx = x + sx * w / 4
        dw = w / 2 - 0.03
        b.box(dw, 0.08, h, cx, y + 0.06, z, DOOR, bevel=0.02)
        b.box(dw - 0.2, 0.03, h * 0.52, cx, y + 0.01, z + h * 0.4, "glow_window", bevel=0)
        b.box(dw - 0.12, 0.04, 0.06, cx, y, z + h * 0.4 - 0.05, "teal_light", bevel=0.01)
        b.box(dw - 0.12, 0.04, 0.24, cx, y, z + 0.08, "teal_light", bevel=0.01)
        b.torus(0.13, 0.025, cx - sx * (dw / 2 - 0.2), y - 0.03, z + h * 0.42, "brass", segs=14, ring=6, rot=(90, 0, 0))
    b.box(0.05, 0.06, h, x, y + 0.04, z, "navy", bevel=0)


def entrance_stair(b, w=4.6, steps=3, run=0.36, landing=0.75):
    """Stone landing and steps with red carpet runner and brass stanchions with velvet rope.
    Origin at the back-centre of the landing (put it against the facade); descends toward -Y."""
    rise = FLOOR / steps
    b.box(w, landing, FLOOR, 0, -landing / 2, 0, "stone", bevel=0.03)
    for i in range(1, steps):
        b.box(w + i * 0.12, run, FLOOR - i * rise, 0, -landing - (i - 0.5) * run, 0, pick(STONE, i), bevel=0.03)
    for i in range(1, 5):
        b.box(0.02, landing - 0.04, 0.005, -w / 2 + w * i / 5, -landing / 2, FLOOR, "stone_dark", bevel=0)
    # red carpet draped over landing, risers and treads, with a short run-out on the ground
    cw = 1.25
    b.box(cw, landing, 0.02, 0, -landing / 2, FLOOR, CARPET, bevel=0)
    for i in range(steps):
        y = -landing - i * run
        b.box(cw, 0.02, rise, 0, y - 0.01, FLOOR - (i + 1) * rise, CARPET, bevel=0)
        if i:
            b.box(cw, run, 0.02, 0, y + run / 2, FLOOR - i * rise, CARPET, bevel=0)
    foot = -landing - (steps - 1) * run
    b.box(cw + 0.2, 0.7, 0.02, 0, foot - 0.35, 0, CARPET, bevel=0)
    for sx in (-1, 1):
        b.box(0.05, landing, 0.025, sx * (cw / 2 + 0.03), -landing / 2, FLOOR, "mustard", bevel=0)
    # stanchions on the landing and at the foot, roped down each side of the carpet
    for sx in (-1, 1):
        top = (sx * (cw / 2 + 0.35), -0.3, FLOOR)
        bot = (sx * (cw / 2 + 0.45), foot - 0.3, 0)
        stanchion(b, *top)
        stanchion(b, *bot)
        velvet_rope(b, (top[0], top[1], top[2] + 0.52), (bot[0], bot[1], bot[2] + 0.52), sag=0.1)


def build_poster(name, insert):
    b = Builder(name)
    poster_frame(b, 0, 0, 0, insert=insert)
    return b.finish(KIT, "wall_decor", {"note": f"face uses {insert}; game supplies poster art"})


def build():
    b = Builder("cinema_shell")
    shell(b)
    b.socket("door", (0, -D / 2 - 0.5, FLOOR), 180)
    b.finish(KIT, "building", {"module": "shell", "footprint_m": [W, D]})

    b = Builder("cinema_facade")
    facade(b)
    b.finish(KIT, "building", {"module": "facade", "attach": "shell front face, y=-D/2"})

    b = Builder("cinema_roof_cap")
    roof_cap(b, z=-H + 0.32)
    b.finish(KIT, "building", {"module": "roof", "attach_z": H - 0.32})

    b = Builder("cinema_marquee")
    marquee(b)
    b.finish(KIT, "sign", {"note": "sign face material insert_marquee takes the CINEMA graphic"})

    b = Builder("cinema_double_doors")
    double_doors(b)
    b.socket("door", (0, -0.6, 0), 180)
    b.finish(KIT, "door")

    build_poster("poster_frame_a", "insert_poster")
    build_poster("poster_frame_b", "insert_poster_b")

    b = Builder("cinema_entrance_stair")
    entrance_stair(b)
    b.finish(KIT, "building", {"module": "stair", "attach": "back edge against facade, top at FLOOR=0.4"})

    b = Builder("cinema_topiary")
    topiary(b)
    b.finish(KIT, "plant")

    # ---- assembled prefab --------------------------------------------------
    b = Builder("cinema_exterior")
    shell(b)
    roof_cap(b, z=0)
    with b.at((0, -D / 2, 0)):
        facade(b)
        marquee(b, y=-0.42 - 0.02, z=FLOOR + OPEN_H + 0.12)
        double_doors(b, y=0.12, z=FLOOR)
        for sx in (-1, 1):
            poster_frame(b, sx * (OPEN_W / 2 + 0.96), 0, FLOOR + 0.45, insert="insert_poster" if sx < 0 else "insert_poster_b")
            wall_lantern(b, sx * (OPEN_W / 2 + 0.18), -0.42, 2.05, s=1.25)
        with b.at((0, -0.42, 0)):
            entrance_stair(b)
        for sx in (-1, 1):
            topiary(b, sx * (OPEN_W / 2 + 1.78), -0.9, 0, s=1.35)
    stair_front = -D / 2 - 0.42 - 0.75 - 2 * 0.36
    b.socket("door", (0, -D / 2 - 0.7, FLOOR), 180)
    for i in range(4):
        b.socket(f"queue_{i}", (0, stair_front - 0.8 - i * 0.75, 0), 180)
    b.finish(KIT, "building", {"prefab": True, "footprint_m": [W, D + 1.6],
                               "note": "assembled from the cinema_* modules; sockets rotz 180 face the doors"})
