"""World odds and ends from the World Map concept: bridge, HOMES gateway, wayfinding and small props."""
from common import *

KIT = "world_misc"
PREVIEW_WIDTH = 12.0
SIGN_FRAME = tint("sign_frame", "wood_dark")
ROOFT = tint("roof", "roof")
PINS = (tint("pin_a", "coral"), tint("pin_b", "teal"), tint("pin_c", "mustard"))


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


def beam(b, p0, p1, w, t, mat, bevel=0.012):
    """Rectangular beam between two points (w across, t thick)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    rot = d.to_track_quat("Z", "Y").to_euler()
    m = (p0 + p1) / 2
    b.box(w, t, d.length, m.x, m.y, m.z, mat, bevel=bevel, center=True, rot=tuple(math.degrees(a) for a in rot))


def snow_top(b, w, d, x, y, z):
    b.box(w, d, 0.06, x, y, z, "snow", bevel=0.025)
    b.blob(w * 0.35, d * 0.4, 0.05, x, y, z + 0.05, "snow", subdiv=1)


def footbridge():
    """Arched footbridge spanning X (crossing a stream that runs along Y)."""
    b = Builder("footbridge")
    L, Wd, rise, z0 = 3.6, 1.4, 0.45, 0.3
    rail = tint("bridge_paint", "wood_b")
    zf = lambda x: z0 + rise * (1 - (x / (L / 2)) ** 2)
    # stone abutments
    for sx in (-1, 1):
        x = sx * (L / 2 + 0.25)
        with b.at((x, 0, 0), rotz=90):
            stone_row(b, Wd + 0.6, z0 - 0.03, 0.6, x0=-(Wd + 0.6) / 2, y=0, z=0, unit=0.4)  # deck planks rest on top
    # stringers under the deck
    n = 10
    for sy in (-0.5, 0.0, 0.5):
        xs = [-L / 2 - 0.3 + (L + 0.6) * i / n for i in range(n + 1)]
        for xa, xb in zip(xs, xs[1:]):
            beam(b, (xa, sy, zf(max(-L / 2, min(L / 2, xa))) - 0.1), (xb, sy, zf(max(-L / 2, min(L / 2, xb))) - 0.1), 0.1, 0.12, "wood_dark")
    # deck planks following the arch
    m = 18
    for i in range(m):
        x = -L / 2 - 0.3 + (L + 0.6) * (i + 0.5) / m
        xc = max(-L / 2, min(L / 2, x))
        slope = -2 * rise * xc / (L / 2) ** 2 if abs(x) <= L / 2 else 0.0
        b.box((L + 0.6) / m - 0.02, Wd, 0.06, x, 0, zf(xc) - 0.03, pick(WOOD, i * 5), bevel=0.01,
              rot=(0, -math.degrees(math.atan(slope)), 0))
    # railings: posts along the arch, top and mid rails
    k = 5
    for sy in (-1, 1):
        y = sy * (Wd / 2 - 0.05)
        xs = [-L / 2 - 0.15 + (L + 0.3) * i / (k - 1) for i in range(k)]
        tops = []
        for i, x in enumerate(xs):
            zb = zf(max(-L / 2, min(L / 2, x)))
            b.box(0.12, 0.12, 0.72, x, y, zb - 0.05, rail, bevel=0.02)
            b.box(0.09, 0.09, 0.04, x, y, zb + 0.67, rail, bevel=0.01)
            tops.append((x, y, zb + 0.6))
        for (pa, pb) in zip(tops, tops[1:]):
            beam(b, pa, pb, 0.08, 0.08, rail)
            beam(b, (pa[0], pa[1], pa[2] - 0.3), (pb[0], pb[1], pb[2] - 0.3), 0.06, 0.05, rail)
        for x, yy, zz in (tops[0], tops[-1]):
            snow_top(b, 0.16, 0.16, x, yy, zz + 0.12)
    b.socket("end_w", (-L / 2 - 0.6, 0, z0), rotz=90)
    b.socket("end_e", (L / 2 + 0.6, 0, z0), rotz=-90)
    return done(b, "path", {"span_m": L, "deck_width_m": Wd, "walk_axis": "X"})


def house_board(b, w, h, x, y, z):
    """House-shaped (pentagon) sign: frame plus insert face on the front."""
    out = [(-w / 2, 0), (w / 2, 0), (w / 2, h), (0, h + w * 0.28), (-w / 2, h)]
    inn = [(-w / 2 + 0.07, 0.07), (w / 2 - 0.07, 0.07), (w / 2 - 0.07, h - 0.03), (0, h + w * 0.28 - 0.09), (-w / 2 + 0.07, h - 0.03)]
    b.prism(out, 0.08, x, y, z, SIGN_FRAME)
    b.prism(inn, 0.02, x, y - 0.05, z, "insert_sign")
    b.prism(inn, 0.02, x, y + 0.05, z, "insert_sign")


def homes_arch():
    b = Builder("homes_arch")
    S, H = 1.35, 2.3
    for sx in (-1, 1):
        x = sx * S
        b.box(0.42, 0.42, 0.3, x, 0, 0, "stone_dark", bevel=0.04)
        b.box(0.2, 0.2, H, x, 0, 0.3, "wood_b", bevel=0.025)
        b.box(0.04, 0.24, 0.04, x, -0.12, H - 0.15, "iron", bevel=0)
        lantern_head(b, x, -0.26, H - 0.62, 0.8)
        planter_box(b, 0.55, 0.3, 0.26, x=x + sx * 0.5, y=-0.1, z=0)
    b.box(3.3, 0.24, 0.22, 0, 0, H + 0.3, "wood", bevel=0.03)
    b.box(3.0, 0.16, 0.12, 0, 0, H + 0.18, "wood_dark", bevel=0.02)
    snow_cap(b, 3.32, 0.28, 0, 0, H + 0.52, h=0.06)
    house_board(b, 1.15, 0.5, 0, -0.02, H - 0.75)  # apex clears the lower beam (H+0.18)
    for sx in (-0.4, 0.4):
        b.cyl(0.012, 0.45, sx, -0.02, H - 0.27, "iron", segs=4)
    b.socket("path", (0, -0.8, 0), rotz=0)
    return done(b, "landmark", {"sign_text": "HOMES"})


def mailbox():
    b = Builder("mailbox")
    body = tint("mailbox", "red")
    b.box(0.3, 0.3, 0.1, 0, 0, 0, "stone_dark", bevel=0.02)
    b.box(0.1, 0.1, 0.85, 0, 0, 0.1, "wood_b", bevel=0.015)
    b.box(0.3, 0.46, 0.2, 0, 0, 0.92, body, bevel=0.025)
    b.cyl(0.15, 0.46, 0, 0.23, 1.12, body, segs=10, rot=(90, 0, 0))
    b.box(0.28, 0.03, 0.3, 0, -0.235, 0.94, body, bevel=0.012)
    b.box(0.12, 0.02, 0.03, 0, -0.255, 1.12, "iron", bevel=0)
    b.box(0.03, 0.03, 0.26, 0.17, 0.05, 1.02, "iron", bevel=0)
    b.box(0.02, 0.14, 0.09, 0.17, 0.13, 1.2, tint("mailbox_flag", "yellow"), bevel=0.008)
    b.blob(0.13, 0.22, 0.05, 0, 0, 1.27, "snow", subdiv=1, jitter=0.01)
    return done(b, "prop", {"interact": "mail"})


def arrow_board(b, L, h, x, y, z, rotz):
    with b.at((x, y, z), rotz=rotz):
        pts = [(0, -h / 2), (L - h * 0.55, -h / 2), (L, 0), (L - h * 0.55, h / 2), (0, h / 2)]
        b.prism(pts, 0.06, mat=SIGN_FRAME)
        inn = [(0.06, -h / 2 + 0.05), (L - h * 0.55 - 0.02, -h / 2 + 0.05), (L - 0.09, 0), (L - h * 0.55 - 0.02, h / 2 - 0.05), (0.06, h / 2 - 0.05)]
        b.prism(inn, 0.02, y=-0.035, mat="insert_sign")
        b.prism(inn, 0.02, y=0.035, mat="insert_sign")


def signpost():
    b = Builder("signpost")
    b.box(0.36, 0.36, 0.14, 0, 0, 0, "stone_dark", bevel=0.03)
    b.box(0.13, 0.13, 1.95, 0, 0, 0.14, "wood_b", bevel=0.02)
    b.cyl(0.1, 0.12, 0, 0, 2.09, "wood_dark", segs=6, r2=0.0)
    b.blob(0.09, 0.09, 0.04, 0, 0, 2.12, "snow", subdiv=1)
    for k, (z, rz, L) in enumerate(((1.75, 0, 0.85), (1.45, 150, 0.75), (1.15, 35, 0.8))):
        arrow_board(b, L, 0.24, 0, 0, z, rz)
        b.socket(f"arrow_{k}", (0, 0, z), rotz=rz)
    return done(b, "landmark", {"note": "each arrow has insert_sign faces on both sides"})


def notice_board():
    b = Builder("notice_board")
    for sx in (-1, 1):
        b.box(0.12, 0.12, 1.8, sx * 0.62, 0, 0, "wood_b", bevel=0.02)
    b.box(1.36, 0.1, 0.92, 0, 0, 0.72, SIGN_FRAME, bevel=0.025)
    b.box(1.2, 0.03, 0.78, 0, -0.05, 0.79, "tan", bevel=0)
    notes = [(-0.35, 1.25, 0.3, 0.34, "cream"), (0.08, 1.2, 0.28, 0.24, "white"), (0.38, 1.0, 0.26, 0.3, "cream"),
             (-0.3, 0.88, 0.32, 0.22, "white"), (0.05, 0.9, 0.22, 0.2, "petal_yellow")]
    for k, (x, z, w, h, c) in enumerate(notes):
        b.box(w, 0.012, h, x, -0.07, z - h / 2, c, bevel=0, rot=(0, (k % 3 - 1) * 5, 0))
        b.sphere(0.018, x, -0.08, z - 0.04, pick(PINS, k), u=6, v=4)
    with b.at((0, 0, 1.7)):
        for sy in (-1, 1):
            b.box(1.6, 0.36, 0.06, 0, sy * 0.15, 0.08, ROOFT, bevel=0.015, rot=(sy * -28, 0, 0), center=True)
        b.box(1.62, 0.1, 0.08, 0, 0, 0.17, ROOFT, bevel=0.02)
        b.box(1.5, 0.16, 0.05, 0, -0.06, 0.2, "snow", bevel=0.02)
    return done(b, "landmark", {"interact": "read notices"})


def waterfall_step():
    """Stylised cascade piece: rock lip, falling sheet, foam and a shallow pool. Water flows toward -Y."""
    b = Builder("waterfall_step")
    W, Hs = 1.4, 0.8
    # rock lip and side rocks
    stone_row(b, W + 0.5, Hs, 0.7, x0=-(W + 0.5) / 2, y=0.5, z=0, mats=("stone_grey", "rock_grey", "stone_dark"), unit=0.35)
    for sx in (-1, 1):
        b.blob(0.32, 0.38, 0.5, sx * (W / 2 + 0.15), 0.1, 0.35, pick(("stone_grey", "rock_grey"), sx > 0), subdiv=1, jitter=0.04)
        b.blob(0.24, 0.24, 0.1, sx * (W / 2 + 0.1), 0.15, 0.82, "snow", subdiv=1, jitter=0.02)
        b.blob(0.22, 0.25, 0.2, sx * (W / 2 + 0.05), -0.75, 0.1, "rock_grey", subdiv=1, jitter=0.03)
    # upper channel and falling sheet (stepped, slightly bulged)
    b.box(W, 0.7, 0.05, 0, 0.5, Hs, "water", bevel=0.01)
    b.box(W, 0.1, Hs * 0.55, 0, 0.13, Hs * 0.45, "water", bevel=0.02)
    b.box(W * 0.96, 0.12, Hs * 0.5, 0, 0.06, 0.05, "water_deep", bevel=0.02)
    for k in range(4):
        x = -W / 2 + W * (k + 0.5) / 4
        b.box(0.05, 0.02, Hs * 0.8, x + 0.08, 0.06, 0.08, "ice", bevel=0)
    # pool and foam
    b.box(W + 0.4, 0.9, 0.06, 0, -0.45, 0, "water", bevel=0.02)
    for k in range(9):
        x = -W / 2 + W * (k + 0.5) / 9
        r = b.rng.uniform(0.08, 0.14)
        b.blob(r, r * 0.8, r * 0.55, x, -0.04 + b.rng.uniform(-0.05, 0.05), 0.08, "white", subdiv=1, jitter=0.01)
    for k in range(5):
        x = -W / 2 + W * (k + 0.5) / 5
        b.blob(0.07, 0.05, 0.03, x, 0.17, Hs + 0.03, "white", subdiv=1)
    b.socket("inflow", (0, 0.85, Hs), rotz=0)
    b.socket("outflow", (0, -0.9, 0.06), rotz=0)
    return done(b, "nature", {"flow": "-Y", "drop_m": Hs})


def barrel():
    b = Builder("barrel")
    b.cyl(0.2, 0.26, 0, 0, 0, "wood_b", segs=10, r2=0.24)
    b.cyl(0.24, 0.26, 0, 0, 0.26, "wood_b", segs=10, r2=0.2)
    for k in range(10):
        a = 2 * math.pi * (k + 0.5) / 10
        beam(b, (math.cos(a) * 0.202, math.sin(a) * 0.202, 0.0), (math.cos(a) * 0.243, math.sin(a) * 0.243, 0.26), 0.012, 0.012, "wood_dark", 0)
        beam(b, (math.cos(a) * 0.243, math.sin(a) * 0.243, 0.26), (math.cos(a) * 0.202, math.sin(a) * 0.202, 0.52), 0.012, 0.012, "wood_dark", 0)
    for z, R in ((0.06, 0.212), (0.26, 0.245), (0.46, 0.212)):
        b.torus(R, 0.014, 0, 0, z, "iron", segs=12, ring=4)
    b.cyl(0.19, 0.02, 0, 0, 0.51, "wood_dark", segs=10)
    return done(b, "prop")


def crate():
    b = Builder("crate")
    S = 0.5
    for i in range(4):
        b.box(S - 0.04, S - 0.04, 0.12, 0, 0, 0.02 + i * 0.12, pick(WOOD, i), bevel=0.012)
    e = 0.07
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(e, e, S, sx * (S / 2 - e / 2), sy * (S / 2 - e / 2), 0, "wood_dark", bevel=0.012)
    for z in (0, S - e):
        for sy in (-1, 1):
            b.box(S, e, e, 0, sy * (S / 2 - e / 2), z, "wood_dark", bevel=0.012)
        for sx in (-1, 1):
            b.box(e, S, e, sx * (S / 2 - e / 2), 0, z, "wood_dark", bevel=0.012)
    beam(b, (-S / 2 + e, -S / 2 - 0.005, e), (S / 2 - e, -S / 2 - 0.005, S - e), 0.07, 0.03, "wood_dark")
    beam(b, (-S / 2 - 0.005, -S / 2 + e, e), (-S / 2 - 0.005, S / 2 - e, S - e), 0.03, 0.07, "wood_dark")
    return done(b, "prop")


def build():
    footbridge()
    homes_arch()
    mailbox()
    signpost()
    notice_board()
    waterfall_step()
    barrel()
    crate()
