"""Cinema auditorium kit (concept 14, Movie Night Scene). Front faces -Y for loose parts.
In the assembled auditorium the screen is at +Y and seats face it (socket rotz 180).
Socket rotz convention: 0 means the occupant faces -Y."""
from common import *
from kits.cinema import UPHOLSTERY, CURTAIN, WALL, CARPET, DOOR, potted_plant
from kits.cinema_lobby import wall_banner

KIT = "cinema_auditorium"
PREVIEW_WIDTH = 13.0
# Sizes follow Art Docs/Interior Spacing Standard: 1.15 m seat pitch, 1.4 m row pitch, 1.6 m aisle.
AW, AD, AH = 14.0, 12.0, 4.4        # interior width (X), depth (Y), wall height
FZ = 0.05                           # front floor surface
STEP = 0.3                          # tier rise: each row's eyes clear the heads in front
TIER_D = 1.4                        # tier depth = row pitch
FRONT_Y = 2.6                       # front edge of the first seat tier
ROW_SEATS = 6
SEAT_PITCH = 1.155                  # 1.15 m minimum plus float margin
SEAT_W = 0.84                       # cushion width; shared armrests fill the rest of the pitch
ARM_W = SEAT_PITCH - SEAT_W
SEAT_Z = 0.38                       # seat cushion top above its floor
AISLE = (3.8, 5.4)                  # aisle carpet span (x), right of the seat block


# ---------------------------------------------------------------------- seats
def seat_body(b, x=0, y=0, z=0, w=SEAT_W):
    """Cushion, tilted back and pedestal of one cinema seat (no arms). Front -Y."""
    with b.at((x, y, z)):
        b.box(w * 0.7, 0.44, 0.17, 0, 0.02, 0, "charcoal", bevel=0.03)
        b.box(w, 0.6, 0.17, 0, -0.02, 0.2, UPHOLSTERY, bevel=0.06)
        with b.at((0, 0.26, 0.3), rot=(-9, 0, 0)):
            b.box(w + 0.02, 0.2, 0.7, 0, 0, 0, UPHOLSTERY, bevel=0.07)


def seat_arm(b, x=0, y=0, z=0, w=ARM_W):
    """Shared wooden armrest console with a cup holder, between two seats."""
    with b.at((x, y, z)):
        b.box(w - 0.06, 0.56, 0.36, 0, 0.01, 0.1, "wood", bevel=0.025)
        b.box(w - 0.02, 0.62, 0.06, 0, 0.0, 0.46, "wood_b", bevel=0.02)
        b.box(w - 0.04, 0.3, 0.1, 0, 0.12, 0.0, "charcoal", bevel=0.02)
        b.cyl(0.065, 0.02, 0, -0.14, 0.515, "black", segs=10)


def seat_row(b, n=4, x=0, y=0, z=0, rotz=0, sock=True, name="seat_{i}"):
    """n seats sharing n+1 arms on a common plinth. Seats spaced SEAT_PITCH along X."""
    w = SEAT_PITCH * n
    with b.at((x, y, z), rotz=rotz):
        b.box(w + ARM_W, 0.3, 0.08, 0, 0.1, 0, "charcoal", bevel=0.02)
        for i in range(n):
            sx = -w / 2 + SEAT_PITCH * (i + 0.5)
            seat_body(b, sx, 0, 0.0)
            if sock:
                b.socket(name.format(i=i), (sx, -0.02, SEAT_Z), (rotz + 0) % 360)
        for i in range(n + 1):
            seat_arm(b, -w / 2 + SEAT_PITCH * i, 0, 0)


# ------------------------------------------------------------ floor and walls
def aisle_light(b, x=0, y=0, z=0, rotz=0):
    """Low step light; back against a face at y, glowing face toward -Y, bottom at z."""
    with b.at((x, y, z), rotz=rotz):
        b.box(0.24, 0.07, 0.12, 0, -0.035, 0, "charcoal", bevel=0.012)
        b.box(0.16, 0.02, 0.07, 0, -0.075, 0.025, "aisle_light", bevel=0)


def tier(b, w, d, h, x=0, y=0, lights=(), tiles=True):
    """Solid dark floor block, top at h, step face toward -Y with optional step lights."""
    b.box(w, d, h - 0.02, x, y, 0, "floor_dark", bevel=0.01)
    if tiles:
        ts = 0.6
        nx, ny = max(1, round(w / ts)), max(1, round(d / ts))
        for ix in range(nx):
            for iy in range(ny):
                b.box(w / nx - 0.015, d / ny - 0.015, 0.02, x - w / 2 + w / nx * (ix + 0.5), y - d / 2 + d / ny * (iy + 0.5),
                      h - 0.02, pick(("floor_dark", "floor_dark_b"), ix + iy), bevel=0.004)
    b.box(w, 0.05, 0.04, x, y - d / 2 + 0.02, h - 0.03, "charcoal", bevel=0.01)
    for lx in lights:
        aisle_light(b, lx, y - d / 2, max(0.02, h - 0.17))


def carpet_strip(b, w, d, x, y, z, border=True):
    b.box(w, d, 0.02, x, y, z, CARPET, bevel=0.004)
    if border:
        for sx in (-1, 1):
            b.box(0.04, d, 0.022, x + sx * (w / 2 - 0.08), y, z, "mustard", bevel=0)
        for k in range(max(1, int(d / 0.45))):
            yy = y - d / 2 + 0.45 * (k + 0.5)
            b.box(0.12, 0.12, 0.022, x, yy, z, "red_dark", bevel=0, rot=(0, 0, 45))


def screen_unit(b, x=0, y=0, z=0, w=4.3, h=2.15, base=0.85, stage_w=None, stage_d=0.7):
    """Framed projection screen on a dark stage block, with a low centre speaker. Faces -Y.
    The screen insert is static geometry, separate from any curtain part."""
    with b.at((x, y, z)):
        sw = stage_w or w + 0.6
        front = 0.1 - stage_d
        b.box(sw, stage_d, base, 0, 0.1 - stage_d / 2, 0, "floor_dark", bevel=0.02)
        b.box(sw + 0.02, 0.05, 0.06, 0, front + 0.02, base - 0.06, "charcoal", bevel=0.01)
        b.box(w + 0.3, 0.16, h + 0.3, 0, 0.0, base, "charcoal", bevel=0.03)
        b.box(w + 0.18, 0.04, h + 0.18, 0, -0.08, base + 0.06, "black", bevel=0.01)
        b.box(w, 0.04, h, 0, -0.1, base + 0.15, "insert_cinema_screen", bevel=0)
        # low centre speaker in front of the stage
        b.box(0.62, 0.34, 0.3, 0, front - 0.2, 0, "charcoal", bevel=0.03)
        b.box(0.5, 0.02, 0.18, 0, front - 0.38, 0.06, "black", bevel=0.005)
        b.socket("screen", (0, -0.1, base + 0.15 + h / 2), 0)


def _segment(b, p0, p1, r, mat, segs=6):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    e = d.to_track_quat("Z", "Y").to_euler()
    b.cyl(r, d.length, p0.x, p0.y, p0.z, mat, segs=segs, rot=tuple(math.degrees(v) for v in e))


def curtain_panel(b, x0, x1, y, z0, z1, r=0.08):
    """Straight pleated panel: vertical faceted folds between x0 and x1, hem at z0, top at z1."""
    n = max(3, round((x1 - x0) / 0.16))
    for i in range(n):
        xx = x0 + r + (x1 - x0 - 2 * r) * i / (n - 1)
        b.cyl(r, z1 - z0, xx, y - 0.03 * (i % 2), z0, CURTAIN, segs=6)
    b.box(x1 - x0 - 0.02, 0.05, 0.05, (x0 + x1) / 2, y - 0.1, z0 + 0.04, "mustard", bevel=0.01)   # hem braid


def curtain_set(b, y=0, z0=0, z1=3.0, half=1.68, open_to=2.5):
    """Stage curtains, resting CLOSED over the screen. Each side is two slide parts (outer on the
    back track at y, inner on the front track at y-0.23) that open sideways and stack between
    open_to-0.84 and open_to; the engine eases them so they settle. The valance stays fixed."""
    inner_w = half / 2 + 0.02
    for sx in (-1, 1):
        side = "l" if sx < 0 else "r"
        for name, a, c, yy in (("outer", half - inner_w + 0.02, half, y), ("inner", 0.02, inner_w, y - 0.23)):
            x0, x1 = sorted((sx * a, sx * c))
            with b.part(f"curtain_{side}_{name}", pivot=((x0 + x1) / 2, yy, z1), motion="slide",
                        dir=[sx, 0, 0], dist=round(open_to - c, 3)):
                curtain_panel(b, x0, x1, yy, z0, z1)
    # fixed valance and rail trim hide the tracks
    b.box(2 * open_to + 0.1, 0.56, 0.34, 0, y - 0.17, z1, CURTAIN, bevel=0.04)
    b.box(2 * open_to + 0.12, 0.06, 0.06, 0, y - 0.47, z1, "brass", bevel=0.01)
    b.box(2 * open_to + 0.14, 0.6, 0.05, 0, y - 0.17, z1 + 0.34, "wood_dark", bevel=0.015)


def wall_panel(b, x=0, y=0, z=0, w=0.62, h=1.05):
    """Acoustic panel: tan fabric pad on a teal backing board. Back at y, bottom at z."""
    b.box(w + 0.12, 0.05, h + 0.12, x, y - 0.025, z, WALL, bevel=0.015)
    b.box(w, 0.08, h, x, y - 0.08, z + 0.06, "tan", bevel=0.035)
    b.box(w - 0.16, 0.02, h - 0.16, x, y - 0.13, z + 0.14, "cream", bevel=0.01)


def speaker(b, x=0, y=0, z=0, w=0.42, h=0.8):
    """Cabinet speaker with two drivers; back at y, bottom at z."""
    b.box(w, 0.36, h, x, y - 0.18, z, "charcoal", bevel=0.03)
    for i, (rz, r) in enumerate(((0.62, 0.12), (0.25, 0.15))):
        b.cyl(r + 0.025, 0.03, x, y - 0.36, z + h * rz + (0.06 if i else 0), "iron_light", segs=12, rot=(90, 0, 0), center=True)
        b.cyl(r, 0.04, x, y - 0.37, z + h * rz + (0.06 if i else 0), "black", segs=12, rot=(90, 0, 0), center=True)
        b.cyl(r * 0.3, 0.05, x, y - 0.38, z + h * rz + (0.06 if i else 0), "iron", segs=8, rot=(90, 0, 0), center=True)


def exit_door(b, x=0, y=0, z=0, w=1.9, h=1.9):
    """Teal double door (clear width >= 1.6 m) in a wood frame, lit windows, levers and kick
    plates. Back at y. Both leaves hinge at the frame and swing 90 degrees into the room (-Y)."""
    with b.at((x, y, z)):
        b.box(w + 0.24, 0.12, 0.14, 0, -0.05, h, "wood", bevel=0.02)
        for sx in (-1, 1):
            b.box(0.12, 0.12, h, sx * (w / 2 + 0.06), -0.05, 0, "wood", bevel=0.02)
            # pivot 9 cm in from the frame: swinging corners clear the post, open clear width 1.65 m
            lw = w / 2 - 0.03
            cx = sx * (0.01 + lw / 2)
            with b.part(f"door_{'l' if sx < 0 else 'r'}", pivot=(sx * (w / 2 - 0.09), -0.03, 0),
                        motion="hinge", axis="z", open_deg=90 * sx):
                b.box(lw, 0.07, h - 0.01, cx, -0.03, 0.005, DOOR, bevel=0.02)
                b.box(0.3, 0.03, 0.3, cx, -0.08, h * 0.62, "wood", bevel=0.01)
                b.box(0.22, 0.03, 0.22, cx, -0.09, h * 0.62 + 0.04, "glow_window", bevel=0)
                b.box(lw - 0.12, 0.03, 0.15, cx, -0.08, 0.05, "brass", bevel=0.008)
                b.box(0.05, 0.05, 0.08, -sx * 0.12, -0.09, h * 0.46, "brass", bevel=0.008)
                b.box(0.16, 0.04, 0.035, -sx * 0.18, -0.12, h * 0.48, "brass", bevel=0.008)


def auditorium_shell(b):
    """Cutaway room: tall teal screen wall and left wall, low taupe right and rear walls,
    dark floor with three seat tiers and a rear landing, carpeted aisle on the right."""
    t = 0.32
    xa0, xa1 = AISLE
    # front floor in front of the tiers
    front_d = AD / 2 - FRONT_Y
    tier(b, AW, front_d, FZ, 0, FRONT_Y + front_d / 2)
    # three seat tiers then the rear landing; step faces look toward the screen (+Y)
    for r in range(4):
        y1 = FRONT_Y - r * TIER_D
        y0 = y1 - TIER_D if r < 3 else -AD / 2
        top = FZ + STEP * (r + 1)
        with b.at((0, (y0 + y1) / 2, 0), rotz=180):
            tier(b, AW, y1 - y0, top, 0, 0, lights=(-6.2, 5.4))   # walkway step lights (local x = -world x)
        # aisle carpet: tread plus a drape down the step face
        carpet_strip(b, xa1 - xa0, y1 - y0, (xa0 + xa1) / 2, (y0 + y1) / 2, top)
        b.box(xa1 - xa0, 0.02, STEP, (xa0 + xa1) / 2, y1 + 0.01, top - STEP, CARPET, bevel=0)
        for lx in (xa0 - 0.06, xa1 + 0.06):
            b.box(0.1, 0.1, 0.02, lx, y1 - 0.12, top, "aisle_light", bevel=0.005)
    carpet_strip(b, xa1 - xa0, front_d - 1.4, (xa0 + xa1) / 2, FRONT_Y + (front_d - 1.4) / 2, FZ)
    # tall screen wall (+Y) and left wall (-X): taupe core with a teal inner face
    b.box(AW + 2 * t, t, AH, 0, AD / 2 + t / 2, 0, "taupe", bevel=0.03)
    b.box(AW, 0.05, AH - 0.1, 0, AD / 2 - 0.025, 0, WALL, bevel=0)
    b.box(t, AD, AH, -AW / 2 - t / 2, 0, 0, "taupe", bevel=0.03)
    b.box(0.05, AD, AH - 0.1, -AW / 2 + 0.025, 0, 0, WALL, bevel=0)
    for sx, sy, w_, d_ in ((0, AD / 2 + t / 2, AW + 2 * t + 0.06, t + 0.08), (-AW / 2 - t / 2, 0, t + 0.08, AD)):
        b.box(w_, d_, 0.14, sx, sy, AH, "taupe_dark", bevel=0.03)
    # wood pilasters on the left wall
    for py in (-5.5, -2.6, 0.0, 2.6, 4.9):
        b.box(0.14, 0.24, AH - 0.3, -AW / 2 + 0.07, py, 0, "wood_dark", bevel=0.02)
    # low cutaway walls on the right (+X) and rear (-Y)
    lh = FZ + STEP * 4 + 0.3
    b.box(t, AD + t, lh, AW / 2 + t / 2, -t / 2, 0, "taupe", bevel=0.03)
    b.box(AW + t, t, lh, t / 2 - t, -AD / 2 - t / 2, 0, "taupe", bevel=0.03)
    for sx, sy, w_, d_ in ((AW / 2 + t / 2, -t / 2, t + 0.08, AD + t), (-t / 2, -AD / 2 - t / 2, AW + t, t + 0.08)):
        b.box(w_, d_, 0.1, sx, sy, lh, "taupe_dark", bevel=0.03)
    for px, py in ((AW / 2 + t / 2, -AD / 2 - t / 2), (AW / 2 + t / 2, AD / 2 + t / 2), (-AW / 2 - t / 2, -AD / 2 - t / 2)):
        hh = AH if py > 0 else lh + 0.25
        b.box(t + 0.12, t + 0.12, hh, px, py, 0, "taupe_dark", bevel=0.04)


# ---------------------------------------------------------------------- build
def build():
    b = Builder("seat_single")
    seat_row(b, n=1, name="seat")
    b.finish(KIT, "seat")

    for n_ in (4, ROW_SEATS):
        b = Builder(f"seat_row_{n_}")
        seat_row(b, n=n_)
        b.finish(KIT, "seat", {"seat_pitch_m": SEAT_PITCH})

    b = Builder("riser")
    tier(b, 3.2, TIER_D, STEP, lights=(-1.0, 0.0, 1.0))
    b.finish(KIT, "floor", {"module": "tier", "size_m": [3.2, TIER_D, STEP], "note": "step face toward -Y"})

    b = Builder("screen")
    screen_unit(b)
    b.finish(KIT, "interactive", {"activity": "cinema_screen", "note": "insert_cinema_screen shows the synced video"})

    b = Builder("curtain")
    curtain_set(b, y=-0.27, z0=0.0, z1=2.2, half=1.68)
    b.finish(KIT, "wall_decor", {"note": "rests closed; four slide parts open sideways, valance static"})

    b = Builder("wall_panel")
    wall_panel(b)
    b.finish(KIT, "wall_decor")

    b = Builder("speaker")
    speaker(b)
    b.finish(KIT, "wall_decor")

    b = Builder("aisle_light")
    aisle_light(b)
    b.finish(KIT, "light")

    b = Builder("exit_door")
    exit_door(b)
    b.socket("door", (0, -0.6, 0), 180)
    b.finish(KIT, "door")

    b = Builder("auditorium_shell")
    auditorium_shell(b)
    b.finish(KIT, "building", {"interior_m": [AW, AD], "floor_z": FZ, "tier_rise_m": STEP})

    # ---- assembled auditorium ------------------------------------------------
    b = Builder("cinema_auditorium")
    auditorium_shell(b)
    wy = AD / 2                                     # screen wall inner face
    # full-width stage so curtain hems always land on it, open or closed
    sb = 1.0                                        # stage height
    screen_unit(b, 0, wy - 0.1, FZ, w=4.6, h=2.4, base=sb, stage_w=AW - 0.1, stage_d=0.85)
    curtain_set(b, y=wy - 0.27, z0=FZ + sb + 0.005, z1=FZ + 3.8, half=2.45, open_to=3.75)
    for sx in (-1, 1):
        speaker(b, sx * 6.0, wy - 0.9, FZ, w=0.5, h=1.3)
    # three rows of ROW_SEATS centred on the screen, one per tier, facing it
    n = 0
    for r in range(3):
        top = FZ + STEP * (r + 1)
        sy = FRONT_Y - r * TIER_D - TIER_D + 0.45
        seat_row(b, ROW_SEATS, 0, sy, top, rotz=180, sock=False)
        for i in range(ROW_SEATS):
            lx = SEAT_PITCH * (i + 0.5) - SEAT_PITCH * ROW_SEATS / 2
            b.socket(f"seat_{n}", (-lx, sy + 0.02, top + SEAT_Z), 180)
            n += 1
    land = FZ + STEP * 4
    # left wall dressing between pilasters; local frame on the wall's inner face:
    # local x = world y, local -Y points into the room
    with b.at((-AW / 2 + 0.05, 0, 0), rotz=90):
        for py in (-1.3, 3.75):
            wall_panel(b, py, 0, 1.6)
        for py in (0.0, 2.6):
            wall_lantern(b, py, -0.14, 2.9, s=1.2)
        wall_banner(b, 1.3, 0, 1.8)
        exit_door(b, -4.0, 0, land)
    potted_plant(b, AW / 2 - 0.45, -5.5, land, s=1.2)
    potted_plant(b, -AW / 2 + 0.45, -5.5, land, s=1.2)
    b.socket("exit", (-AW / 2 + 0.8, -4.0, land), -90)
    b.socket("screen", (0, wy - 0.2, FZ + sb + 0.15 + 1.2), 0)
    b.finish(KIT, "room", {"prefab": True, "interior_m": [AW, AD], "seats": n,
                           "seat_pitch_m": SEAT_PITCH, "row_pitch_m": TIER_D,
                           "note": "seat_0..17 face the screen (+Y); 1.6 m aisle on the right; double exit door on the left wall at the rear landing"})
