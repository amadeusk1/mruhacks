"""Cinema lobby kit (concept 13). Front faces -Y; wall decor has its back at y=0, bottom at z=0.
Socket rotz convention: 0 means the occupant faces -Y."""
from common import *
from kits.cinema import (stanchion, velvet_rope, poster_frame, potted_plant, BULB_SPACING,
                         UPHOLSTERY, CARPET, DOOR, AWNING_A, AWNING_B, BANNER)

KIT = "cinema_lobby"
PREVIEW_WIDTH = 13.0
# Sizes follow Art Docs/Interior Spacing Standard (seats >= 1.15 m apart, 2.0 m double doors).
LW, LD, LH = 12.0, 10.0, 3.6    # lobby interior footprint and wall height
FZ = 0.06                       # floor surface height
SD_R = 1.17                     # screen-door arch radius: leaves open to a 2.0 m clear width
SD_RECT = 1.7                    # screen-door leaf height (arch springs here)
DOOR_TOP = SD_RECT + SD_R + 0.38 # lintel height of the screen-door wall opening
ENTRANCE = 2.4                   # front entrance gap
SOFA_PITCH = 1.15


# ------------------------------------------------------------------ furniture
def popcorn_machine(b, x=0, y=0, z=0):
    """Counter-top popcorn cart: red base, glass case heaped with popcorn, red hip roof."""
    w, d = 0.5, 0.42
    b.box(w, d, 0.2, x, y, z, "red", bevel=0.02)
    b.box(w + 0.02, d + 0.02, 0.04, x, y, z + 0.2, "brass", bevel=0.01)
    b.box(w * 0.6, 0.02, 0.08, x, y - d / 2 - 0.005, z + 0.06, "brass", bevel=0.005)
    gz, gh = z + 0.24, 0.42
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.04, 0.04, gh, x + sx * (w / 2 - 0.02), y + sy * (d / 2 - 0.02), gz, "red_dark", bevel=0.008)
    rng = b.rng
    for i in range(46):
        px, py = rng.uniform(-w / 2 + 0.07, w / 2 - 0.07), rng.uniform(-d / 2 + 0.07, d / 2 - 0.07)
        pz = gz + 0.04 + rng.uniform(0, 0.2) * (1 - abs(px) * 1.4)
        r = rng.uniform(0.028, 0.04)
        b.blob(r, r, r * 0.85, x + px, y + py, pz, pick(("popcorn", "popcorn", "popcorn_b"), i), jitter=r * 0.15)
    b.box(w - 0.06, d - 0.06, 0.4, x, y, gz, "glass", bevel=0)
    b.box(w + 0.06, d + 0.06, 0.07, x, y, gz + gh, "red", bevel=0.02)
    b.cyl(0.36, 0.14, x, y, gz + gh + 0.07, "red", segs=4, r2=0.06, rot=(0, 0, 45))
    b.sphere(0.04, x, y, gz + gh + 0.24, "brass", u=6, v=4)


def register_till(b, x, y, z):
    b.box(0.32, 0.26, 0.12, x, y, z, "charcoal", bevel=0.02)
    b.box(0.3, 0.06, 0.18, x, y + 0.06, z + 0.1, "charcoal", bevel=0.015, rot=(-20, 0, 0))
    b.box(0.24, 0.02, 0.12, x, y + 0.03, z + 0.14, "glow_teal", bevel=0, rot=(-20, 0, 0))
    for i in range(3):
        b.box(0.05, 0.05, 0.02, x - 0.08 + i * 0.08, y - 0.08, z + 0.12, "iron_light", bevel=0.005)


def concession_counter(b, x=0, y=0, z=0, popcorn=True, sock=True):
    """Snack counter (front at -Y) with back shelving, lit header sign and striped awning."""
    w, d, h = 2.7, 0.7, 0.86
    with b.at((x, y, z)):
        b.box(w, d, 0.1, 0, 0, 0, "wood_deep", bevel=0.02)
        n = 12
        for i in range(n):
            b.box(w / n - 0.012, 0.06, h - 0.16, -w / 2 + w / n * (i + 0.5), -d / 2 + 0.03, 0.1, pick(WOOD, i), bevel=0.01)
        b.box(w, d - 0.06, h - 0.1, 0, 0.03, 0.1, "wood_b", bevel=0.01)
        b.box(w + 0.12, d + 0.14, 0.07, 0, -0.03, h - 0.07, "wood_c", bevel=0.02)
        b.box(w, 0.04, 0.05, 0, -d / 2 - 0.02, h - 0.24, "wood_dark", bevel=0.01)
        register_till(b, -0.75, 0.0, h)
        if popcorn:
            popcorn_machine(b, 0.95, 0.02, h)
        potted_plant(b, 0.3, 0.05, h, s=0.55, berries=True)
        for i in range(3):
            b.cyl(0.04, 0.1, -0.25 + i * 0.1, 0.1, h, pick(("white", "red", "white"), i), segs=8, r2=0.05)
        # back shelving
        sy = 0.95
        b.box(w - 0.1, 0.36, 1.75, 0, sy, 0, "wood_b", bevel=0.02)
        for lvl in range(3):
            sz = 0.55 + lvl * 0.42
            b.box(w - 0.2, 0.3, 0.32, 0, sy - 0.04, sz, "wood_deep", bevel=0)
            b.box(w - 0.14, 0.32, 0.04, 0, sy - 0.05, sz - 0.04, "wood_c", bevel=0.01)
            for k in range(7):
                bx = -w / 2 + 0.3 + k * 0.33
                m = pick(("red", "teal_light", "mustard", "blue", "coral", "cream", "green"), k + lvl * 3)
                b.box(0.14, 0.16, 0.2 + 0.05 * ((k + lvl) % 2), bx, sy - 0.08, sz, m, bevel=0.012)
        # header frame, lit sign and awning
        for sx in (-1, 1):
            b.box(0.14, 0.14, 2.55, sx * (w / 2 - 0.02), sy, 0, "wood_dark", bevel=0.02)
        b.box(w + 0.1, 0.18, 0.62, 0, sy - 0.05, 2.0, "wood", bevel=0.03)
        b.box(w - 0.4, 0.06, 0.42, 0, sy - 0.16, 2.1, "insert_sign", bevel=0.01)
        for zz in (2.04, 2.56):
            k = int((w - 0.2) / BULB_SPACING)
            for i in range(k + 1):
                b.sphere(0.035, -w / 2 + 0.1 + i * (w - 0.2) / k, sy - 0.16, zz, "bulb", u=6, v=4)
        for sx in (-1, 1):
            b.sphere(0.035, sx * (w / 2 - 0.1), sy - 0.16, 2.3, "bulb", u=6, v=4)
        awning(b, w, 0.75, 0.32, x=0, y=sy - 0.14, z=1.98, a=AWNING_A, c=AWNING_B, stripes=9)
        if sock:
            b.socket("use", (0, -d / 2 - 0.45, 0), 180)
            b.socket("staff", (0, 0.52, 0), 0)


def movie_kiosk(b, x=0, y=0, z=0, sock=True):
    """Browsing lectern: angled screen top, cases displayed on the front shelf."""
    w = 1.05
    with b.at((x, y, z)):
        side = [(-0.28, 0), (0.28, 0), (0.3, 0.98), (-0.2, 0.72), (-0.3, 0.32)]
        for sx in (-1, 1):
            b.prism([(p[1] * 0 + p[0], p[1]) for p in side], 0.07, x=sx * (w / 2 - 0.035), mat="wood_b",
                    rot=(0, 0, 90), bevel=0.012)
        b.box(w - 0.07, 0.5, 0.08, 0, 0.02, 0.0, "wood_deep", bevel=0.01)
        b.box(w - 0.07, 0.05, 0.92, 0, 0.27, 0.0, "wood", bevel=0.01)
        # sloped screen board
        with b.at((0, 0.02, 0.84), rot=(28, 0, 0)):
            b.box(w + 0.04, 0.62, 0.07, 0, 0, 0, "wood_c", bevel=0.02, center=True)
            b.box(w - 0.14, 0.48, 0.03, 0, 0.0, 0.035, "insert_kiosk", bevel=0.005, center=True)
        # front display shelf with leaning cases
        b.box(w - 0.07, 0.24, 0.05, 0, -0.17, 0.3, "wood_c", bevel=0.01)
        b.box(w - 0.07, 0.04, 0.12, 0, -0.29, 0.3, "wood_c", bevel=0.01)
        for i, m in enumerate(("red", "teal_light", "blue", "mustard")):
            b.box(0.19, 0.04, 0.27, -0.33 + i * 0.22, -0.15, 0.35, m, bevel=0.008, rot=(-12, 0, 0))
        if sock:
            b.socket("use", (0, -0.8, 0), 180)


def lobby_poster(b, x=0, y=0, z=0, insert="insert_poster"):
    """Poster frame with a small picture light over it (wall decor, back at y)."""
    poster_frame(b, x, y, z + 0.0, w=0.78, h=1.12, insert=insert)
    b.box(0.12, 0.05, 0.08, x, y - 0.025, z + 1.24, "iron", bevel=0.01)
    b.cyl(0.015, 0.2, x, y - 0.03, z + 1.28, "iron", segs=5, rot=(90, 0, 0))
    b.cyl(0.08, 0.1, x, y - 0.24, z + 1.2, "iron", segs=6, r2=0.04)
    b.cyl(0.07, 0.02, x, y - 0.24, z + 1.19, "glow", segs=6)


def sofa(b, x=0, y=0, z=0, seats=2, mats=(UPHOLSTERY, UPHOLSTERY), sock=True, pitch=SOFA_PITCH):
    """Lounge sofa or armchair (seats=1). Seat centres sit `pitch` apart."""
    w = pitch * (seats - 1) + 0.96
    cw = (w - 0.36) / seats - 0.02          # cushions fit between the arms
    with b.at((x, y, z)):
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.box(0.08, 0.08, 0.08, sx * (w / 2 - 0.1), sy * 0.26, 0, "wood_dark", bevel=0.01)
        b.box(w, 0.68, 0.18, 0, 0, 0.08, "wood_dark", bevel=0.04)
        for i in range(seats):
            b.box(cw, 0.56, 0.14, -pitch / 2 * (seats - 1) + pitch * i, -0.04, 0.25, mats[0], bevel=0.05)
        b.box(w - 0.04, 0.22, 0.5, 0, 0.24, 0.24, mats[0], bevel=0.06)
        for sx in (-1, 1):
            b.box(0.18, 0.66, 0.42, sx * (w / 2 - 0.09), 0, 0.2, mats[0], bevel=0.06)
        for i in range(seats if sock else 0):
            b.socket(f"seat_{i}", (-pitch / 2 * (seats - 1) + pitch * i, -0.05, 0.39), 0)


def round_table(b, x=0, y=0, z=0, lantern=True):
    with b.at((x, y, z)):
        for a in (0, 90):
            b.box(0.62, 0.11, 0.07, 0, 0, 0, "wood_b", bevel=0.015, rot=(0, 0, a))
        b.cyl(0.08, 0.42, 0, 0, 0.05, "wood_dark", segs=8, bevel=0.01)
        b.cyl(0.45, 0.07, 0, 0, 0.46, "wood", segs=12, bevel=0.015)
        b.cyl(0.42, 0.01, 0, 0, 0.53, "wood_c", segs=12)
        if lantern:
            b.box(0.13, 0.13, 0.02, 0.12, -0.05, 0.53, "iron", bevel=0.005)
            lantern_head(b, 0.12, -0.05, 0.55, s=0.55)
            potted_plant(b, -0.13, 0.08, 0.53, s=0.42, berries=True)


def bin_box(b, x=0, y=0, z=0):
    with b.at((x, y, z)):
        b.box(0.42, 0.42, 0.06, 0, 0, 0, "wood_deep", bevel=0.01)
        for side in range(4):
            for i in range(3):
                o = -0.13 + i * 0.13
                if side < 2:
                    b.box(0.125, 0.04, 0.58, o, (-1 if side == 0 else 1) * 0.19, 0.06, pick(WOOD, i + side), bevel=0.01)
                else:
                    b.box(0.04, 0.125, 0.58, (-1 if side == 2 else 1) * 0.19, o, 0.06, pick(WOOD, i + side), bevel=0.01)
        b.box(0.46, 0.46, 0.06, 0, 0, 0.62, "wood_dark", bevel=0.015)
        b.box(0.28, 0.28, 0.02, 0, 0, 0.67, "black", bevel=0)


def arch_points(cx, cz, r, a0=0, a1=180, n=10):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def screen_doors(b, x=0, y=0, z=0, rotz=0, sock=True, fill_to=DOOR_TOP, fill_mat="plaster"):
    """Arched teal double doors in a stone surround with a SCREEN sign (insert) in the arch.
    Back of the surround at y; faces -Y. Door sill at z."""
    r, rect = SD_R, SD_RECT
    dw = 2 * r
    with b.at((x, y, z), rotz=rotz):
        # stone surround: block jambs and voussoir arch
        for sx in (-1, 1):
            for i in range(4):
                zz, hh = rect * i / 4, rect / 4
                b.box(0.3, 0.3, hh - 0.015, sx * (r + 0.15), -0.15, zz, pick(STONE, i + (sx > 0)), bevel=0.03)
        k = 9
        for i in range(k):
            a0, a1 = 180 * i / k, 180 * (i + 1) / k
            ri, ro = r, r + 0.3
            pts = [(ri * math.cos(math.radians(a0)), ri * math.sin(math.radians(a0))),
                   (ro * math.cos(math.radians(a0)), ro * math.sin(math.radians(a0))),
                   (ro * math.cos(math.radians(a1)), ro * math.sin(math.radians(a1))),
                   (ri * math.cos(math.radians(a1)), ri * math.sin(math.radians(a1)))]
            b.prism(pts, 0.3, y=-0.15, z=rect, mat=pick(STONE, i), bevel=0.02)
        b.box(0.36, 0.34, 0.12, 0, -0.16, rect + r + 0.22, "stone_dark", bevel=0.03)
        # spandrels: wall-flush fill between the arch ring and the rectangular wall opening
        # (2 * (r + 0.3) wide, up to fill_to), notched around the keystone, so no corner gaps show
        ro, kx, ktop = r + 0.3, 0.18, rect + r + 0.34
        ka = math.degrees(math.acos(kx / ro))
        for sx in (-1, 1):
            arc = arch_points(0, rect, ro, ka, 0, 8)
            pts = [(ro, rect), (ro, fill_to), (0, fill_to), (0, ktop), (kx, ktop)] + arc[:-1]
            b.prism([(sx * px, pz) for px, pz in pts], 0.3, y=-0.15, mat=fill_mat)
        # fixed arched transom over the doors carries the sign; a bar separates it from the leaves
        b.prism(arch_points(0, rect, r, 0, 180, 10), 0.1, y=-0.14, mat=DOOR, bevel=0.01)
        b.box(dw + 0.02, 0.12, 0.05, 0, -0.15, rect - 0.025, "brass", bevel=0.01)
        for sx in (-1, 1):
            b.box(0.05, 0.1, rect, sx * (r - 0.025), -0.15, 0, DOOR, bevel=0.01)   # jamb liner
            # door stop on the front face hides the hinge-side gap; leaves swing away from it (+Y)
            b.box(0.09, 0.03, rect - 0.04, sx * (r - 0.075), -0.205, 0.01, DOOR, bevel=0.008)
            # leaves hinge just inside the liner and swing 90 degrees through the doorway (+Y)
            with b.part(f"door_{'l' if sx < 0 else 'r'}", pivot=(sx * (r - 0.12), -0.14, 0),
                        motion="hinge", axis="z", open_deg=-90 * sx):
                b.box(r - 0.08, 0.1, rect - 0.06, sx * (0.01 + (r - 0.08) / 2), -0.14, 0.01, DOOR, bevel=0.01)
                b.torus(0.17, 0.035, sx * r * 0.5, -0.2, 1.15, "brass", segs=14, ring=6, rot=(90, 0, 0))
                b.cyl(0.15, 0.03, sx * r * 0.5, -0.19, 1.15, "glow_window", segs=14, rot=(90, 0, 0), center=True)
                b.box(0.04, 0.05, 0.4, sx * 0.1, -0.22, 0.6, "brass", bevel=0.01)
                b.box(r - 0.16, 0.03, 0.16, sx * (r / 2 - 0.02), -0.2, 0.05, "brass", bevel=0.008)
                if sx > 0:
                    b.box(0.07, 0.03, rect - 0.08, 0.0, -0.205, 0.02, DOOR, bevel=0.008)   # astragal covers the centre seam
        # SCREEN sign plate in the arch
        sign = arch_points(0, rect + 0.06, r - 0.2, 0, 180, 12)
        b.prism(sign, 0.04, y=-0.21, mat="insert_sign", bevel=0.005)
        if sock:
            b.socket("door", (0, -0.7, 0), 180 + rotz)


def carpet(b, w=2.0, d=2.0, x=0, y=0, z=0, border="mustard"):
    b.box(w, d, 0.02, x, y, z, CARPET, bevel=0.005)
    for sx in (-1, 1):
        b.box(0.05, d - 0.2, 0.022, x + sx * (w / 2 - 0.12), y, z, border, bevel=0)
        b.box(w - 0.2, 0.05, 0.022, x, y + sx * (d / 2 - 0.12), z, border, bevel=0)


def wall_banner(b, x=0, y=0, z=0, w=0.62, h=1.05):
    """Hanging cloth banner with camera emblem; back at y, bottom point at z."""
    with b.at((x, y, z)):
        cloth = [(-w / 2, 0.22), (0, 0), (w / 2, 0.22), (w / 2, h), (-w / 2, h)]
        b.prism([(px * 1.08, pz * 1.0 - 0.03) for px, pz in cloth], 0.02, y=-0.03, mat="brass")
        b.prism(cloth, 0.03, y=-0.055, mat=BANNER)
        b.cyl(0.025, w + 0.24, -w / 2 - 0.12, -0.06, h + 0.03, "brass", segs=6, rot=(0, 90, 0))
        for sx in (-1, 1):
            b.sphere(0.04, sx * (w / 2 + 0.12), -0.06, h + 0.03, "brass", u=6, v=4)
            b.box(0.04, 0.08, 0.04, sx * (w / 2 - 0.05), -0.03, h + 0.0, "brass", bevel=0)
        # camera emblem
        ez = h * 0.52
        b.box(0.26, 0.03, 0.15, -0.02, -0.08, ez, "cream", bevel=0.01)
        b.prism([(0.11, 0.03), (0.21, -0.02), (0.21, 0.18), (0.11, 0.13)], 0.03, y=-0.08, z=ez, mat="cream")
        for cx, r in ((-0.09, 0.075), (0.05, 0.065)):
            b.cyl(r, 0.03, cx, -0.08, ez + 0.15 + r, "cream", segs=10, rot=(90, 0, 0), center=True)
            b.cyl(r * 0.35, 0.035, cx, -0.085, ez + 0.15 + r, "red", segs=8, rot=(90, 0, 0), center=True)
        for sx in (-1, 1):
            b.box(0.03, 0.03, 0.16, -0.02 + sx * 0.08, -0.08, ez - 0.15, "cream", bevel=0, rot=(0, sx * 15, 0))


def stone_pier(b, x, y, h=LH, w=0.46, cap=True):
    """Stacked stone pier with slight jitter, as on the lobby walls in concept 13."""
    zz, i = 0.0, 0
    while zz < h - 1e-3:
        bh = min(0.5 + 0.12 * ((i * 7) % 3) / 2, h - zz)
        b.box(w + 0.03 * ((i % 2) * 2 - 1), w + 0.03 * ((i % 2) * 2 - 1), bh - 0.015, x, y, zz, pick(STONE, i + int(x * 3)), bevel=0.035)
        zz += bh
        i += 1
    if cap:
        b.box(w + 0.1, w + 0.1, 0.16, x, y, h, "stone_dark", bevel=0.04)


def lobby_shell(b, door_y=2.0):
    """Cutaway lobby room: tiled floor, plaster walls on back/left/right with stone piers,
    low front wall with entrance gap, opening in the right wall for the screen doors."""
    t = 0.3
    # floor slab and checker tiles
    b.box(LW + 2 * t, LD + 2 * t, 0.03, 0, 0, 0, "stone_dark", bevel=0.01)
    ts = 0.5
    for ix in range(int(LW / ts)):
        for iy in range(int(LD / ts)):
            b.box(ts - 0.02, ts - 0.02, FZ - 0.03, -LW / 2 + ts * (ix + 0.5), -LD / 2 + ts * (iy + 0.5), 0.03,
                  pick(("paving", "paving_b", "stone"), (ix + iy) % 2 + ((ix * 3 + iy * 5) % 7 == 0)), bevel=0.008)
    # back wall
    b.box(LW + 2 * t, t, LH, 0, LD / 2 + t / 2, 0, "plaster", bevel=0.03)
    b.box(LW, 0.06, 0.22, 0, LD / 2 - 0.03, FZ, "stone_dark", bevel=0.01)
    b.box(LW + 2 * t + 0.04, t + 0.08, 0.14, 0, LD / 2 + t / 2, LH, "stone_dark", bevel=0.03)
    # left wall: low cutaway like the front, so the camera sees in
    b.box(t, LD, 0.55, -LW / 2 - t / 2, 0, 0, "plaster", bevel=0.03)
    b.box(t + 0.08, LD, 0.1, -LW / 2 - t / 2, 0, 0.55, "stone_dark", bevel=0.03)
    # right wall with the screen-door opening
    y0, y1 = door_y - SD_R - 0.3, door_y + SD_R + 0.3   # matches the stone surround exactly
    for a, c in ((-LD / 2, y0), (y1, LD / 2)):
        b.box(t, c - a, LH, LW / 2 + t / 2, (a + c) / 2, 0, "plaster", bevel=0.03)
        b.box(0.06, c - a, 0.22, LW / 2 - 0.03, (a + c) / 2, FZ, "stone_dark", bevel=0.01)
    b.box(t, y1 - y0, LH - DOOR_TOP, LW / 2 + t / 2, door_y, DOOR_TOP, "plaster", bevel=0.03)
    b.box(t, y1 - y0, FZ - 0.03, LW / 2 + t / 2, door_y, 0.03, "stone_dark", bevel=0.005)   # threshold under the doors
    b.box(t + 0.08, LD, 0.14, LW / 2 + t / 2, 0, LH, "stone_dark", bevel=0.03)
    # low front wall with an entrance gap
    gap = ENTRANCE
    for sx in (-1, 1):
        L = LW / 2 - gap / 2
        b.box(L, t, 0.55, sx * (gap / 2 + L / 2), -LD / 2 - t / 2, 0, "plaster", bevel=0.03)
        b.box(L + 0.04, t + 0.08, 0.1, sx * (gap / 2 + L / 2), -LD / 2 - t / 2, 0.55, "stone_dark", bevel=0.03)
        stone_pier(b, sx * (gap / 2 + 0.23), -LD / 2 - t / 2, h=0.9)
    # stone piers at corners and along the walls
    for px, py, h in ((-LW / 2 - 0.1, LD / 2 + 0.1, LH), (LW / 2 + 0.1, LD / 2 + 0.1, LH),
                      (-LW / 2 - 0.1, -LD / 2 - 0.1, 1.0), (LW / 2 + 0.1, -LD / 2 - 0.1, 1.0),
                      (-1.6, LD / 2 + 0.1, LH), (-LW / 2 - 0.1, 0.0, 0.9), (LW / 2 + 0.1, -1.6, LH)):
        stone_pier(b, px, py, h=h)
    b.socket("entrance", (0, -LD / 2 - 0.6, 0), 180)
    b.socket("screen_door", (LW / 2 - 0.6, door_y, FZ), 90)


# ---------------------------------------------------------------------- build
def build():
    b = Builder("concession_counter")
    concession_counter(b, popcorn=True)
    b.finish(KIT, "furniture", {"note": "header sign face insert_sign takes the CINEMA logo"})

    b = Builder("popcorn_machine")
    popcorn_machine(b)
    b.finish(KIT, "prop", {"note": "counter-top appliance"})

    b = Builder("movie_kiosk")
    movie_kiosk(b)
    b.finish(KIT, "interactive", {"activity": "cinema_browse", "note": "insert_kiosk shows the library UI"})

    b = Builder("lobby_poster_frame")
    lobby_poster(b)
    b.finish(KIT, "wall_decor")

    b = Builder("lobby_sofa")
    sofa(b, seats=2)
    b.finish(KIT, "seat")

    b = Builder("lobby_armchair")
    sofa(b, seats=1)
    b.finish(KIT, "seat")

    b = Builder("lobby_round_table")
    round_table(b)
    b.finish(KIT, "furniture")

    b = Builder("lobby_bin")
    bin_box(b)
    b.finish(KIT, "prop")

    b = Builder("screen_doors")
    screen_doors(b)
    b.finish(KIT, "door", {"note": "arch sign face insert_sign reads SCREEN 1"})

    b = Builder("carpet_tile")
    carpet(b)
    b.finish(KIT, "floor", {"tile_m": 2.0})

    b = Builder("stanchion")
    stanchion(b)
    b.socket("rope", (0, 0, 0.52))
    b.finish(KIT, "prop")

    b = Builder("stanchion_rope")
    velvet_rope(b, (-0.6, 0, 0.52), (0.6, 0, 0.52), sag=0.12)
    b.finish(KIT, "prop", {"span_m": 1.2, "note": "hook ends at x=+-0.6, z=0.52 (stanchion socket_rope height)"})

    b = Builder("wall_banner")
    wall_banner(b)
    b.finish(KIT, "wall_decor")

    b = Builder("lobby_plant")
    potted_plant(b, s=1.3, berries=True)
    b.finish(KIT, "plant")

    b = Builder("lobby_shell")
    lobby_shell(b)
    b.finish(KIT, "building", {"interior_m": [LW, LD], "floor_z": FZ})

    # ---- assembled lobby -----------------------------------------------------
    b = Builder("cinema_lobby")
    lobby_shell(b)
    dy = 2.0                                        # screen-door centre on the right wall
    with b.at((0, 0, FZ)):
        concession_counter(b, -3.4, 3.65, sock=False)
        for i, x in enumerate((-0.4, 0.8, 2.0, 3.2)):
            lobby_poster(b, x, LD / 2, 0.95, insert="insert_poster" if i % 2 == 0 else "insert_poster_b")
        wall_banner(b, 4.6, LD / 2, 1.5)
        movie_kiosk(b, 1.2, 3.3, sock=False)
        screen_doors(b, LW / 2 + 0.3, dy, 0, rotz=-90, sock=False)
        carpet(b, 4.2, 3.0, 2.7, -0.9, 0)
        carpet(b, 1.7, 2.3, 5.05, 1.75, 0)
        # queue line in front of the kiosk: posts 1.4 m apart
        posts = (-1.2, 0.2, 1.6)
        for x0, x1 in zip(posts, posts[1:]):
            velvet_rope(b, (x0, 1.6, 0.52), (x1, 1.6, 0.52), sag=0.12)
        for x in posts:
            stanchion(b, x, 1.6, 0)
        # lounge for four: two armchairs at a table, a two-seat sofa by the left wall
        round_table(b, -3.6, -2.6, 0)
        with b.at((-4.6, -2.6, 0), rotz=90):
            sofa(b, seats=1, sock=False)
        with b.at((-2.6, -2.6, 0), rotz=-90):
            sofa(b, seats=1, sock=False)
        with b.at((-5.2, -0.2, 0), rotz=90):
            sofa(b, seats=2, sock=False)
        bin_box(b, 5.45, -4.45, 0)
        for px, py in ((-5.5, -4.5), (5.4, 4.45), (-1.0, 4.55), (5.45, -3.4)):
            potted_plant(b, px, py, 0, s=1.25, berries=True)
        wall_lantern(b, -1.6, LD / 2 + 0.1 - 0.25, 2.2)
        for py in (0.25, 3.75):
            with b.at((LW / 2, py, 0), rotz=90):
                wall_lantern(b, 0, 0, 2.3)
    b.socket("kiosk", (1.2, 3.3 - 0.8, FZ), 180)
    b.socket("counter", (-3.4, 3.65 - 0.8, FZ), 180)
    seats = ((-4.55, -2.6, 90), (-2.65, -2.6, -90),
             (-5.15, -0.2 - SOFA_PITCH / 2, 90), (-5.15, -0.2 + SOFA_PITCH / 2, 90))
    for i, (sx, sy, rz) in enumerate(seats):
        b.socket(f"seat_{i}", (sx, sy, FZ + 0.39), rz)
    b.finish(KIT, "room", {"prefab": True, "interior_m": [LW, LD], "floor_z": FZ,
                           "note": "screen door on the right wall leads to cinema_auditorium"})
