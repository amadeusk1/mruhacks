"""Arcade kit (concepts 15 Arcade Building, Arcade Social Scene)."""
import math
from contextlib import nullcontext
from common import *

KIT = "arcade"
PREVIEW_WIDTH = 16.0

CAB_H = 1.5


def variants(**roles):
    """meta entry listing the concept colours per tint role, as hex."""
    return {"color_variants": {r: [PALETTE[c][0] for c in cs] for r, cs in roles.items()}}


# Side profile (y, z) of a cabinet; front faces -Y.
CAB_PROFILE = [(-0.26, 0), (0.30, 0), (0.30, CAB_H), (-0.20, CAB_H), (-0.27, 1.30), (-0.14, 1.23),
               (-0.20, 0.93), (-0.38, 0.87), (-0.38, 0.76), (-0.26, 0.70)]
INSET = 0.035  # how far the inner body sits behind the side panels


def _inner(p):
    return [(y + INSET if y < 0.29 else y, z) for y, z in p]


DECK_TILT = 18.4
# buttons press along the tilted deck's normal, in asset axes
DECK_NORMAL = (0.0, round(-math.sin(math.radians(DECK_TILT)), 3), round(math.cos(math.radians(DECK_TILT)), 3))


def _station(b, x, plate=None, stick="red", buttons=("yellow", "red", "sky"), n=1, static=False):
    """Station n on the deck's local frame (deck top at z=0): movable joystick (tilt) and
    buttons (press) named joystick_<n> / btn_<n>_<a|b|c>, plus flipper grip sockets."""
    if plate:
        b.box(0.44, 0.17, 0.012, x, 0, 0, plate, bevel=0.004)
    z = 0.012 if plate else 0
    jx = x - 0.12
    b.cyl(0.04, 0.015, jx, 0, z, "black", segs=8)
    part = (lambda *a, **k: nullcontext()) if static else b.part
    with part(f"joystick_{n}", pivot=(jx, 0, z + 0.015), motion="tilt", axis="xy", max_deg=22):
        b.cyl(0.011, 0.075, jx, 0, z + 0.012, "iron_light", segs=6)
        b.sphere(0.034, jx, 0, z + 0.09, stick, u=8, v=6)
    bx = []
    for i, c in enumerate(buttons):
        px, py = x + i * 0.07, 0.02 - (i % 2) * 0.04
        b.cyl(0.03, 0.006, px, py, z, "black", segs=8)                                   # bezel ring
        with part(f"btn_{n}_{'abc'[i]}", pivot=(px, py, z + 0.006), motion="press", depth=0.008, dir=DECK_NORMAL):
            b.cyl(0.024, 0.02, px, py, z + 0.004, c, segs=8, bevel=0.004)
        bx.append((px, py))
    if static:
        return
    b.socket(f"grip_{n}_L", (jx, 0, z + 0.12))
    b.socket(f"grip_{n}_R", (sum(p[0] for p in bx) / len(bx), 0, z + 0.03))


def cabinet(b, body="purple", width=0.62, stations=None, coin_doors=None, static=False):
    """static=True builds scenery with no movable parts or grip sockets (prefab dressing)."""
    """Upright cabinet: side panels with the full profile, inset body, angled marquee, recessed
    tilted screen, angled control deck, kick plate and coin door."""
    W = width
    for sx in (-1, 1):
        b.prism(CAB_PROFILE, 0.05, x=sx * (W / 2 - 0.025), mat=body, rot=(0, 0, 90), bevel=0.008)
    b.prism(_inner(CAB_PROFILE), W - 0.09, mat=body, rot=(0, 0, 90))
    b.box(W + 0.02, 0.6, 0.035, 0, 0.02, 0, "black", bevel=0.008)                      # plinth
    # marquee (leans back at the top) with a light strip under it
    with b.at((0, -0.2, 1.40), rot=(-19.3, 0, 0)):
        b.box(W - 0.11, 0.02, 0.18, 0, -0.012, 0, "insert_marquee", center=True, bevel=0.004)
    b.box(W - 0.1, 0.06, 0.025, 0, -0.19, 1.255, "glow", bevel=0.004)
    # screen: black bezel, recessed insert
    with b.at((0, -0.135, 1.08), rot=(-11.3, 0, 0)):
        sw, sh, bw = W - 0.2, 0.235, W - 0.11
        b.box(bw, 0.02, 0.31, 0, 0.004, 0, "black", center=True, bevel=0.006)                 # back plate
        for sx in (-1, 1):
            b.box((bw - sw) / 2, 0.03, 0.31, sx * (sw + bw) / 4, -0.016, 0, "black", center=True, bevel=0.006)
        for sz in (-1, 1):
            b.box(sw, 0.03, (0.31 - sh) / 2, 0, -0.016, sz * (sh + 0.31) / 4, "black", center=True, bevel=0.006)
        b.box(sw, 0.01, sh, 0, -0.011, 0, "insert_arcade", center=True)                         # 1 cm behind bezel face
    b.socket("screen", (0, -0.17, 1.08))
    # control deck (front edge lower)
    with b.at((0, -0.255, 0.90), rot=(DECK_TILT, 0, 0)):
        b.box(W - 0.07, 0.21, 0.022, 0, 0, -0.012, "charcoal", bevel=0.006)
        for n, st in enumerate(stations or [dict(x=0, plate=None)], start=1):
            _station(b, n=n, static=static, **st)
    # kick plate and coin door on the lower front
    yf = -0.26 + INSET
    b.box(W - 0.09, 0.02, 0.12, 0, yf - 0.01, 0.035, "black", bevel=0.004)
    for cx in coin_doors or [0]:
        b.box(0.2, 0.025, 0.26, cx, yf - 0.012, 0.25, "charcoal", bevel=0.01)
        b.box(0.11, 0.02, 0.05, cx, yf - 0.024, 0.4, "iron_light", bevel=0.006)
        b.box(0.014, 0.02, 0.035, cx, yf - 0.034, 0.407, "gold", bevel=0)
        b.box(0.08, 0.02, 0.05, cx, yf - 0.024, 0.29, "black", bevel=0.006)


def build_cabinet():
    b = Builder("arcade_cabinet")
    cabinet(b, tint("body", "purple"))
    b.socket("player_1", (0, -0.7, 0), rotz=180)
    return b.finish(KIT, "arcade_cabinet", {"slots": 1, **variants(body=("purple", "teal_light", "red", "mustard", "blue"))})


def build_duo():
    b = Builder("arcade_cabinet_duo")
    s1, s2 = tint("station_1", "coral"), tint("station_2", "teal_light")
    d = DUO_STATION                    # stations 1.15 m apart (Interior Spacing Standard)
    cabinet(b, tint("body", "navy"), width=1.9, coin_doors=(-d, d), stations=[
        dict(x=-d, plate=s1, stick="red", buttons=("yellow", "red")),
        dict(x=d, plate=s2, stick="sky", buttons=("yellow", "sky")),
    ])
    # colour-coded floor pads for the two stations
    for x, c in ((-d, s1), (d, s2)):
        b.box(0.8, 0.5, 0.018, x, -0.65, 0, c, bevel=0.008)
        b.box(0.7, 0.4, 0.022, x, -0.65, 0, "cream", bevel=0.006)
        b.box(0.66, 0.36, 0.026, x, -0.65, 0, c, bevel=0.006)
    b.socket("player_1", (-d, -0.72, 0), rotz=180)
    b.socket("player_2", (d, -0.72, 0), rotz=180)
    return b.finish(KIT, "arcade_cabinet", {"slots": 2, **variants(body=("navy", "purple"), station_1=("coral",), station_2=("teal_light",))})


def token_machine():
    b = Builder("token_machine")
    body = tint("body", "purple")
    W, D, H = 0.56, 0.44, 1.3
    b.box(W, D, H, 0, 0, 0, body, bevel=0.035)
    b.box(W + 0.04, D + 0.04, 0.08, 0, 0, H - 0.02, body, bevel=0.025)
    b.box(W - 0.1, 0.03, 0.17, 0, -D / 2 - 0.005, H - 0.26, "insert_sign", bevel=0.01)   # "TOKENS"
    b.box(W - 0.12, 0.03, 0.36, 0, -D / 2 - 0.005, 0.62, "black", bevel=0.012)           # display window
    b.cyl(0.13, 0.035, 0, -D / 2 - 0.02, 0.8, "gold", segs=12, rot=(90, 0, 0), center=True)
    b.cyl(0.095, 0.03, 0, -D / 2 - 0.04, 0.8, "yellow", segs=12, rot=(90, 0, 0), center=True)
    b.box(0.03, 0.02, 0.1, 0, -D / 2 - 0.055, 0.75, "mustard", bevel=0.004)
    b.box(0.2, 0.03, 0.12, 0, -D / 2 - 0.005, 0.4, "charcoal", bevel=0.01)               # bill slot
    b.box(0.12, 0.02, 0.015, 0, -D / 2 - 0.02, 0.45, "black", bevel=0)
    b.box(0.24, 0.1, 0.12, 0, -D / 2 - 0.02, 0.12, "charcoal", bevel=0.015)              # tray
    b.box(0.18, 0.02, 0.06, 0, -D / 2 - 0.065, 0.15, "black", bevel=0.004)
    b.socket("use", (0, -0.6, 0), rotz=180)
    return b.finish(KIT, "arcade_prop", variants(body=("purple", "red")))


def stool(b, x=0, y=0, h=0.42):
    b.cyl(0.2, 0.07, x, y, h - 0.07, "wood", segs=10, bevel=0.015)
    b.box(0.32, 0.03, 0.012, x, y + 0.05, h - 0.004, "wood_b", bevel=0)
    b.box(0.32, 0.03, 0.012, x, y - 0.05, h - 0.004, "wood_b", bevel=0)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        lx, ly = x + math.cos(a) * 0.12, y + math.sin(a) * 0.12
        b.box(0.06, 0.06, h - 0.06, lx, ly, 0, "wood_b", bevel=0.012,
              rot=(-math.sin(a) * 6, math.cos(a) * 6, 0))
    b.cyl(0.13, 0.03, x, y, 0.14, "wood_dark", segs=8, cap=True)


TRI_RUG = ("teal_light", "lavender", "cream", "teal", "purple")


def tri_rug(b, w, d, cells=(4, 3), cols=tuple(tint(f"rug_{i}", c) for i, c in enumerate(TRI_RUG))):
    """Geometric triangle-pattern rug (concepts 11, 15)."""
    nx, ny = cells
    cw, cd = w / nx, d / ny
    k = 0
    for i in range(nx):
        for j in range(ny):
            x0, y0 = -w / 2 + i * cw, -d / 2 + j * cd
            a, bb, c, dd = (x0, y0), (x0 + cw, y0), (x0 + cw, y0 + cd), (x0, y0 + cd)
            tris = [(a, bb, c), (a, c, dd)] if (i + j) % 2 else [(a, bb, dd), (bb, c, dd)]
            for t in tris:
                b.prism(list(t), 0.02, mat=pick(cols, k * 3 + i), plane="xy")
                k += 1


def marquee(b, w=1.8):
    """Arched bulb sign with a controller emblem; back at y=0, front -Y, bottom at z=0."""
    s = w / 1.8
    outline = [(-0.9, 0), (0.9, 0), (0.9, 0.72), (0.42, 0.78), (0.3, 1.02), (-0.3, 1.02), (-0.42, 0.78), (-0.9, 0.72)]
    outline = [(x * s, z * s) for x, z in outline]
    b.prism(outline, 0.12, y=-0.06, mat="wood_dark", bevel=0.02)
    inner = [(x * 0.86, z * 0.82 + 0.09 * s) for x, z in outline]
    b.prism(inner, 0.03, y=-0.13, mat="insert_sign")
    # bulbs around the border
    pts = outline + outline[:1]
    cx = sum(p[0] for p in outline) / len(outline)
    cz = sum(p[1] for p in outline) / len(outline)
    for p0, p1 in zip(pts, pts[1:]):
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        n = max(1, round(L / (0.14 * s)))
        for i in range(n):
            t = i / n
            px, pz = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
            px += (cx - px) * 0.06
            pz += (cz - pz) * 0.1
            b.sphere(0.03 * s, px, -0.135, pz, "bulb", u=6, v=4)
    b.socket("fx_sparkle", (0, -0.17, 1.0 * s))
    # controller emblem in the arch
    with b.at((0, -0.16, 0.84 * s), scale=s):
        b.box(0.36, 0.05, 0.17, 0, 0, 0, "pink", bevel=0.05, center=True)
        for sx in (-1, 1):
            b.blob(0.07, 0.04, 0.07, sx * 0.15, 0, -0.04, "pink", subdiv=1)
        b.box(0.075, 0.03, 0.022, -0.08, -0.03, 0, "navy", center=True, bevel=0)
        b.box(0.022, 0.03, 0.075, -0.08, -0.03, 0, "navy", center=True, bevel=0)
        b.sphere(0.018, 0.07, -0.03, 0.02, "teal_light", u=6, v=4)
        b.sphere(0.018, 0.11, -0.03, -0.015, "navy", u=6, v=4)


# --- building ------------------------------------------------------------
# Interior Spacing Standard: about 12 x 9 m of floor, 2.0 m clear double doors.
IW, ID = 12.0, 9.0                        # interior floor
ST, SH = 0.3, 2.8                         # wall thickness, wall height
SW, SD = IW + 2 * ST, ID + 2 * ST         # outer shell width, depth
DOOR_W, DOOR_H = 2.1, 2.1                 # opening; 2.02 m clear between the frame posts
IX, IY = IW / 2, ID / 2                   # interior half extents (inner wall faces)
CAB_Y = IY - 0.33                         # cabinet origin: plinth back against the back wall
SOLO_X = (-4.6, -3.2, -1.8, -0.4, 1.0)    # 1.4 m pitch, players never closer than 1.15 m
DUO_X = 3.6                               # duo stations at 3.025 and 4.175
DUO_STATION = 0.575                       # half of the 1.15 m station spacing
# zones as [x0, y0, x1, y1] in shell coordinates
ZONES = {
    "standing": [-IX, IY - 0.71 - 1.4, IX, IY - 0.71],    # 1.4 m deep in front of the cabinet decks
    "spectator": [-IX, IY - 0.71 - 2.9, IX, IY - 0.71 - 1.4],
    "aisle": [-IX, IY - 0.71 - 4.9, IX, IY - 0.71 - 2.9],  # 2.0 m main aisle
    "entry": [-1.25, -IY, 1.25, -IY + 2.5],
}


def door_leaf(b, w, h, s=1):
    """One teal door leaf, hinge at local x=0 extending toward s*X, outside face toward -Y."""
    c = s * w / 2
    b.box(w, 0.07, h, c, 0, 0, "teal", bevel=0.02)
    b.box(w * 0.6, 0.03, h * 0.3, c, -0.04, h * 0.1, "teal", bevel=0.012)
    b.box(w * 0.55, 0.03, h * 0.3, c, -0.04, h * 0.55, "wood", bevel=0.01)
    b.box(w * 0.45, 0.02, h * 0.24, c, -0.06, h * 0.58, "glow_window", bevel=0)
    b.torus(0.07, 0.014, s * w * 0.82, -0.075, h * 0.45, "gold", segs=10, ring=4, rot=(90, 0, 0))


def pilaster(b, x, y, top, roofed):
    z, k = 0, 0
    while z < top - 0.05:
        hh = min(0.42, top - z)
        s = 0.46 if k % 2 == 0 else 0.4
        b.box(s, s, hh - 0.02, x, y, z, pick(("stone", "paving_b"), k), bevel=0.03)
        z += hh
        k += 1
    if not roofed:
        snow_cap(b, 0.5, 0.5, x, y, top - 0.02, h=0.07, lumps=False)


def front_wall(b, roofed):
    """Front wall with doors, windows, planters and lanterns: the cutaway the camera can hide."""
    hx, hy = SW / 2, SD / 2
    top = SH + 0.12
    for sx in (-1, 1):
        seg = hx - DOOR_W / 2
        b.box(seg, ST, SH, sx * (DOOR_W / 2 + seg / 2), -hy + ST / 2, 0, "plaster", bevel=0.03)
    b.box(DOOR_W, ST, SH - DOOR_H, 0, -hy + ST / 2, DOOR_H, "plaster", bevel=0.03)
    b.box(SW + 0.06, ST + 0.06, 0.12, 0, -hy + ST / 2, SH, "wood", bevel=0.02)
    for x0, L in ((-hx, hx - DOOR_W / 2 - 0.1), (DOOR_W / 2 + 0.1, hx - DOOR_W / 2 - 0.1)):
        stone_row(b, L, 0.42, 0.1, x0=x0, y=-hy - 0.03, z=0)
    for sx in (-1, 1):
        pilaster(b, sx * (hx - 0.12), -hy + 0.12, top, roofed)
    # door frame and leaves (hinge parts rest closed, swing outward)
    for sx in (-1, 1):
        b.box(0.14, ST + 0.1, DOOR_H, sx * (DOOR_W / 2 + 0.03), -hy + ST / 2, 0, "wood", bevel=0.02)
    b.box(DOOR_W + 0.3, ST + 0.12, 0.16, 0, -hy + ST / 2, DOOR_H, "wood", bevel=0.02)
    lw = DOOR_W / 2 - 0.02
    for sx in (-1, 1):
        with b.at((sx * (DOOR_W / 2 - 0.04), -hy - 0.1, 0.07)):
            with b.part("door_l" if sx < 0 else "door_r", pivot=(0, 0, 0), motion="hinge", axis="z", open_deg=sx * 72):
                door_leaf(b, lw - 0.035, DOOR_H - 0.1, s=-sx)
    # outside: windows with flower boxes, lanterns by the door
    for sx in (-1, 1):
        for wx in (2.4, 4.6):
            window(b, 0.85, 0.85, x=sx * wx, y=-hy, z=1.15)
            planter_box(b, 1.05, 0.26, 0.2, x=sx * wx, y=-hy - 0.19, z=0.62)
        wall_lantern(b, sx * 1.5, -hy, 2.0)
    # inside: chair rail either side of the door
    for sx in (-1, 1):
        L = IX - DOOR_W / 2 - 0.1
        b.box(L, 0.04, 0.06, sx * (DOOR_W / 2 + 0.1 + L / 2), -IY + 0.02, 0.95, "wood", bevel=0.01)


def shell(b, roofed=False, front=None):
    """Arcade interior shell. The front wall goes into `front` (the cutaway child) when given."""
    hx, hy = SW / 2, SD / 2
    top = SH + 0.12
    # foundation slab, checker floor, doorway threshold
    b.box(SW + 0.4, SD + 0.4, 0.12, 0, 0, -0.08, "stone_dark", bevel=0.03)
    nx, ny = math.ceil(IW / 0.5), math.ceil(ID / 0.5)
    tx, ty = IW / nx, ID / ny
    for i in range(nx):
        for j in range(ny):
            b.box(tx - 0.02, ty - 0.02, 0.06, -IX + tx * (i + 0.5), -IY + ty * (j + 0.5), 0,
                  "paving" if (i + j) % 2 else "paving_b", bevel=0.01)
    b.box(DOOR_W - 0.04, ST, 0.06, 0, -hy + ST / 2, 0, "stone", bevel=0.015)
    b.box(DOOR_W + 0.4, 0.5, 0.1, 0, -hy - 0.25, -0.04, "stone", bevel=0.03)
    b.box(DOOR_W + 0.1, 0.4, 0.08, 0, -hy - 0.65, -0.04, "paving_b", bevel=0.03)
    # back and side walls with their timber caps and stone courses
    b.box(SW, ST, SH, 0, hy - ST / 2, 0, "plaster", bevel=0.03)
    b.box(SW + 0.06, ST + 0.06, 0.12, 0, hy - ST / 2, SH, "wood", bevel=0.02)
    for sx in (-1, 1):
        b.box(ST, SD - 2 * ST, SH, sx * (hx - ST / 2), 0, 0, "plaster", bevel=0.03)
        b.box(ST + 0.06, SD - 2 * ST, 0.12, sx * (hx - ST / 2), 0, SH, "wood", bevel=0.02)
        with b.at((sx * (hx + 0.03), 0, 0), rotz=90 * sx):
            stone_row(b, SD, 0.42, 0.1, x0=-hy, y=0, z=0)
        pilaster(b, sx * (hx - 0.12), hy - 0.12, top, roofed)
        # side windows, outside and inside faces
        for wy in (-2.2, 1.8):
            with b.at((sx * hx, wy, 0), rotz=90 * sx):
                window(b, 0.8, 0.8, x=0, y=0, z=1.2)
            with b.at((sx * IX, wy, 0), rotz=-90 * sx):
                window(b, 0.8, 0.8, x=0, y=0, z=1.2, sill=False)
        with b.at((sx * IX, 0, 0), rotz=-90 * sx):
            wall_lantern(b, 0, 0, 2.3)
            b.box(ID, 0.04, 0.06, 0, -0.02, 0.95, "wood", bevel=0.01)      # chair rail
    for x in (-4.5, -1.5, 1.5, 4.5):
        wall_lantern(b, x, IY, 2.35)
    b.box(IW, 0.04, 0.06, 0, IY - 0.02, 0.95, "wood", bevel=0.01)
    front_wall(front or b, roofed)

    # anchors: cabinets face -Y with their backs to the back wall; avatars face +Y (rotz 180)
    b.socket("door", (0, -hy - 0.9, 0))
    b.socket("door_inside", (0, -IY + 1.25, 0))
    for i, x in enumerate(SOLO_X):
        b.socket(f"cabinet_solo_{i}", (x, CAB_Y, 0))
    b.socket("cabinet_duo", (DUO_X, CAB_Y, 0))
    spect = list(SOLO_X) + [DUO_X - DUO_STATION, DUO_X + DUO_STATION]
    for i, x in enumerate(spect):
        b.socket(f"spectate_{i}", (x, (ZONES["spectator"][1] + ZONES["spectator"][3]) / 2, 0), rotz=180)
    b.socket("token_machine", (IX - 0.24, -2.2, 0), rotz=-90)       # faces into the room (-X)
    b.socket("bench_0", (-IX + 0.25, -2.2, 0), rotz=90)             # seats face +X
    b.socket("rug", (0, (ZONES["aisle"][1] + ZONES["aisle"][3]) / 2, 0))


def roof(b):
    rise, ov = 2.4, 0.32
    gable_roof(b, SW, SD, rise, 0.0, overhang=ov, tile=0.36)
    half = SD / 2 + ov
    ang = math.degrees(math.atan2(rise, half))
    rng = b.rng
    # snow pillows resting on tile rows, a drift line at the eaves and a lumpy ridge
    def pillow(x, y, z, L, side):
        with b.at((x, y, z), rot=(ang if side < 0 else -ang, 0, 0)):
            b.blob(L * 0.5, 0.17, 0.1, 0, 0, 0.05, "snow", subdiv=2, jitter=0.012)
            for k in range(2):
                b.blob(L * 0.22, 0.12, 0.08, (k - 0.5) * L * 0.45, rng.uniform(-0.04, 0.04), 0.1, "snow", subdiv=1, jitter=0.01)
    for side in (-1, 1):
        for i in range(18):
            t = rng.uniform(0.2, 0.8)
            pillow(rng.uniform(-SW / 2, SW / 2) * 0.85, side * half * (1 - t), rise * t + 0.04, rng.uniform(0.35, 0.65), side)
        x = -SW / 2 - ov + 0.3
        while x < SW / 2 + ov - 0.3:
            L = min(rng.uniform(0.4, 0.8), SW / 2 + ov - 0.25 - x)
            if L < 0.35:  # no slivers at the gable edge
                break
            if rng.random() < 0.7:
                pillow(x + L / 2, side * (half - 0.25), rise * 0.25 / half + 0.02, L, side)
            x += L + 0.1
    b.box(SW + 0.55, 0.36, 0.14, 0, 0, rise + 0.03, "snow", bevel=0.06, jitter=0.01)
    for x in [(-SW / 2 + 0.6) + k * (SW - 1.2) / 8 for k in range(9)]:
        b.blob(rng.uniform(0.3, 0.45), 0.2, 0.1, x, 0, rise + 0.15, "snow", subdiv=1, jitter=0.02)
    cx, cy = SW * 0.3, SD * 0.18
    cz = rise * (1 - cy / half) - 0.25                                  # base tucked under the tiles
    chimney(b, cx, cy, cz, h=1.0, snow=True)
    b.socket("fx_smoke", (cx, cy, cz + 1.0 + 0.16 + 0.08))              # above the snowy cap


def lantern_post(b, x, y, h=1.8):
    b.box(0.24, 0.24, 0.12, x, y, 0, "iron", bevel=0.02)
    b.cyl(0.05, h - 0.4, x, y, 0.12, "iron", segs=6)
    b.box(0.14, 0.14, 0.06, x, y, h - 0.3, "iron", bevel=0.01)
    lantern_head(b, x, y, h - 0.26, 1.15)


def chalkboard(b, x=0, y=0, rotz=0):
    with b.at((x, y, 0), rotz=rotz):
        for s in (-1, 1):
            with b.at((0, s * 0.12, 0), rot=(s * 12, 0, 0)):
                for sx in (-1, 1):
                    b.box(0.05, 0.04, 0.78, sx * 0.25, 0, 0, "wood", bevel=0.01)
                b.box(0.55, 0.04, 0.05, 0, 0, 0.73, "wood", bevel=0.01)
                b.box(0.55, 0.04, 0.05, 0, 0, 0.1, "wood", bevel=0.01)
                b.box(0.45, 0.03, 0.56, 0, s * 0.01, 0.16, "insert_chalk", bevel=0)


def build():
    # cabinets: shared geometry, body colour variants (concepts 15 + social scene)
    build_cabinet()
    build_duo()
    token_machine()

    b = Builder("arcade_stool")
    stool(b)
    b.socket("seat_0", (0, 0, 0.42))
    b.finish(KIT, "furniture")

    b = Builder("arcade_bench")
    for i, y in enumerate((-0.12, 0.0, 0.12)):
        b.box(1.9, 0.115, 0.07, 0, y, 0.35, pick(WOOD, i), bevel=0.015)
    for x in (-0.78, 0, 0.78):
        b.box(0.12, 0.38, 0.35, x, 0, 0, "wood_b", bevel=0.02)
        b.box(0.16, 0.42, 0.04, x, 0, 0, "wood_dark", bevel=0.01)
    b.socket("seat_0", (-0.575, 0, 0.42))   # 1.15 m apart
    b.socket("seat_1", (0.575, 0, 0.42))
    b.finish(KIT, "furniture")

    b = Builder("arcade_marquee")
    marquee(b)
    b.finish(KIT, "sign", {"mount": "wall", "insert": "ARCADE"})

    for name, w, h in (("arcade_poster", 0.5, 0.6), ("arcade_poster_wide", 0.8, 0.55)):
        b = Builder(name)
        b.box(w + 0.1, 0.05, h + 0.1, 0, -0.025, 0, tint("frame", "wood_dark"), bevel=0.015)
        b.box(w, 0.02, h, 0, -0.055, 0.05, "insert_poster", bevel=0)
        b.finish(KIT, "decor", {"mount": "wall"})

    b = Builder("arcade_rug")
    tri_rug(b, 2.4, 1.8)
    b.finish(KIT, "decor", {"mount": "floor"})

    b = Builder("arcade_chalkboard")
    chalkboard(b)
    b.finish(KIT, "prop")

    b = Builder("arcade_shell")
    c = Builder("arcade_shell_cutaway", seed=1502)
    shell(b, front=c)
    sh = b.finish(KIT, "building", {"module": "shell", "wall_height": SH, "roof": "arcade_roof",
                                    "interior_m": [IW, ID], "door_clear_m": round(DOOR_W - 0.08, 2),
                                    "zones": ZONES, "cutaway_child": "arcade_shell_cutaway"})
    c.finish(KIT, "building").parent = sh
    ASSETS[:] = [a for a in ASSETS if a["obj"].name != "arcade_shell_cutaway"]

    b = Builder("arcade_roof")
    roof(b)
    b.finish(KIT, "building", {"module": "roof", "sits_on": "arcade_shell", "z": SH + 0.12})

    # assembled exterior prefab
    b = Builder("arcade_exterior")
    shell(b, roofed=True)
    with b.at((0, 0, SH + 0.12)):
        roof(b)
    with b.at((0, -SD / 2 - 0.4, DOOR_H + 0.2)):
        marquee(b, 3.0)
    for sx in (-1, 1):
        b.box(0.08, 0.4, 0.08, sx * 1.0, -SD / 2 - 0.2, DOOR_H + 0.35, "iron", bevel=0.01)
    for x, c in ((SOLO_X[0], "purple"), (SOLO_X[2], "teal_light"), (SOLO_X[4], "red")):
        with b.at((x, CAB_Y, 0)):
            cabinet(b, tint(f"cabinet_{c}", c), static=True)
    for sx in (-1, 1):
        lantern_post(b, sx * 1.9, -SD / 2 - 0.9)
    chalkboard(b, -3.2, -SD / 2 - 0.85, rotz=-15)
    b.socket("door", (0, -SD / 2 - 0.9, 0))
    b.finish(KIT, "building", {"module": "prefab", "interior": "arcade_shell"})
