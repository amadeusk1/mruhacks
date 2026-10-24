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


def ell(cx, cy, rx, ry, n=12):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


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
    # front lid hinges at its bottom edge and drops open toward the reader
    with b.part("lid", pivot=(0, -0.235, 0.94), motion="hinge", axis="x", open_deg=80):
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


def notice_board(name="notice_board", top="roof"):
    """top='roof': little coral gable (town board). top='club': flat snow-capped teal cap (Drawing Club sheet)."""
    b = Builder(name)
    for sx in (-1, 1):
        b.box(0.12, 0.12, 1.8, sx * 0.62, 0, 0, "wood_b", bevel=0.02)
    b.box(1.36, 0.1, 0.92, 0, 0, 0.72, SIGN_FRAME, bevel=0.025)
    b.box(1.2, 0.03, 0.78, 0, -0.05, 0.79, "tan", bevel=0)
    notes = [(-0.35, 1.25, 0.3, 0.34, "cream"), (0.08, 1.2, 0.28, 0.24, "white"), (0.38, 1.0, 0.26, 0.3, "cream"),
             (-0.3, 0.88, 0.32, 0.22, "white"), (0.05, 0.9, 0.22, 0.2, "petal_yellow")]
    for k, (x, z, w, h, c) in enumerate(notes):
        b.box(w, 0.012, h, x, -0.07, z - h / 2, c, bevel=0, rot=(0, (k % 3 - 1) * 5, 0))
        b.sphere(0.018, x, -0.08, z - 0.04, pick(PINS, k), u=6, v=4)
    if top == "club":
        cap = tint("cap", "teal")
        b.box(1.5, 0.22, 0.12, 0, 0, 1.64, cap, bevel=0.03)
        b.box(1.42, 0.16, 0.05, 0, 0, 1.6, "wood_dark", bevel=0.015)
        b.box(1.46, 0.2, 0.06, 0, 0, 1.76, "snow", bevel=0.03)
        for k in range(4):
            b.blob(0.16, 0.1, 0.05, -0.5 + 0.33 * k, 0.0, 1.82, "snow", subdiv=1, jitter=0.01)
    else:
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
    b.socket("fx_splash", (0, -0.05, 0.07), rotz=0)  # where the falling sheet lands in the pool
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


# =========================================================================
# Wayfinding and activity markers (World Kit - Wayfinding sheet): ONE frame family.
# Shared pieces: wf_post (rock base, teal snow cap), wf_panel (cream panel, teal frame,
# optional coral corners, blank insert face). Activity icons are separate flat decal GLBs.
# Blank faces use insert_screen; the intended insert role is in meta "insert".
# =========================================================================
WF_FRAME = tint("frame", "teal")
WF_CORNER = tint("corner", "coral")
WF_CAP = tint("cap", "teal")
ICON_D = 0.005     # icon extrusion depth
ICON_GAP = 0.003   # icon back face sits this far in front of the panel face


def wf_base(b, x, y, s=1.0):
    for k, (dx, dy, r) in enumerate(((0, 0, 0.2), (0.16, -0.1, 0.13), (-0.15, 0.08, 0.12))):
        b.blob(r * s * 1.2, r * s, r * s * 0.75, x + dx * s, y + dy * s, r * s * 0.35, pick(("stone_grey", "rock_grey"), k), subdiv=1, jitter=0.015)
    b.blob(0.2 * s, 0.16 * s, 0.05, x - 0.05 * s, y - 0.12 * s, 0.03, "snow", subdiv=1, jitter=0.01)
    b.blob(0.13 * s, 0.1 * s, 0.05, x + 0.12 * s, y - 0.05 * s, 0.17 * s, "snow", subdiv=1, jitter=0.01)


def wf_post(b, x, y, h=1.6, w=0.16):
    """Wood post on a rock cluster, iron bands, teal cap with snow."""
    wf_base(b, x, y)
    b.box(w, w, h, x, y, 0.05, "wood_b", bevel=0.02)
    for z in (0.5, h - 0.25):
        b.box(w + 0.02, w + 0.02, 0.04, x, y, z, "iron", bevel=0.006)
    b.box(w + 0.06, w + 0.06, 0.14, x, y, h + 0.05, WF_CAP, bevel=0.025)
    b.box(w + 0.08, w + 0.08, 0.05, x, y, h + 0.19, "snow", bevel=0.022)
    b.blob(w * 0.5, w * 0.5, 0.05, x, y, h + 0.24, "snow", subdiv=1)


def wf_panel(b, w, h, x, y, z, corners=True, face="insert_screen", bolts=True):
    """Cream panel with a teal frame (front face at y - 0.035). Returns the insert face plane y."""
    b.box(w, 0.05, h, x, y, z, "cream", bevel=0.012)
    fw = 0.06
    for (sx, sz, px, pz) in ((w + 0.02, fw, x, z + h - fw + 0.01), (w + 0.02, fw, x, z - 0.01),
                             (fw, h, x - w / 2 + fw / 2 - 0.01, z), (fw, h, x + w / 2 - fw / 2 + 0.01, z)):
        b.box(sx, 0.07, sz, px, y, pz, WF_FRAME, bevel=0.012)
    if corners:
        for cx in (x - w / 2, x + w / 2):
            for cz in (z, z + h - 0.12):
                b.box(0.12, 0.08, 0.12, cx, y, cz, WF_CORNER, bevel=0.02)
    fy = y - 0.026
    b.box(w - 2 * fw - 0.02, 0.002, h - 2 * fw - 0.02, x, fy - 0.001, z + fw + 0.01, face, bevel=0)
    if bolts:
        for bx in (x - w / 2 + fw + 0.05, x + w / 2 - fw - 0.05):
            for bz in (z + fw + 0.05, z + h - fw - 0.05):
                b.sphere(0.012, bx, fy - 0.004, bz, "gold", u=6, v=4)
    return fy - 0.002


def chain(b, x, y, z0, z1):
    n = max(2, int((z0 - z1) / 0.05))
    for k in range(n):
        b.torus(0.018, 0.005, x, y, z0 - (z0 - z1) * (k + 0.5) / n, "iron", segs=6, ring=3, rot=(90, 0, 90 * (k % 2)))


def world_map_board():
    b = Builder("world_map_board")
    S = 1.0
    for sx in (-1, 1):
        wf_post(b, sx * S, 0, h=1.7, w=0.18)
    b.box(2 * S + 0.1, 0.16, 0.14, 0, 0, 1.6, "wood", bevel=0.02)
    for sx in (-1, 1):
        b.box(0.17, 0.18, 0.05, sx * S, 0, 1.64, "iron", bevel=0.006)
    snow_cap(b, 2 * S - 0.3, 0.18, 0, 0, 1.74, h=0.05)
    for sx in (-0.55, 0.55):
        chain(b, sx, -0.02, 1.6, 1.48)
    fy = wf_panel(b, 1.55, 1.0, 0, -0.02, 0.48, corners=False)
    b.socket("map", (0, fy, 0.98))
    return done(b, "wayfinding", {"insert": "map (insert_screen face; match the playable map)", "label_insert": "socket_map"})


def wf_arrow(b, name, L, h, z, rz, frame):
    """Arrow pointing local +X from the post centre; a tilt part about z so the game can aim it."""
    with b.part(name, pivot=(0, 0, z), motion="tilt", axis="z", max_deg=180):
        with b.at((0, 0, z), rotz=rz):
            out = [(-0.1, -h / 2), (L - h * 0.5, -h / 2), (L, 0), (L - h * 0.5, h / 2), (-0.1, h / 2)]
            b.prism(out, 0.07, mat=frame)
            inn = [(-0.04, -h / 2 + 0.05), (L - h * 0.5 - 0.02, -h / 2 + 0.05), (L - 0.08, 0), (L - h * 0.5 - 0.02, h / 2 - 0.05), (-0.04, h / 2 - 0.05)]
            b.prism(inn, 0.074, mat="cream")
            for yy in (-0.038, 0.038):
                b.prism([(p[0] + 0.02 * (i in (0, 4)), p[1] * 0.85) for i, p in enumerate(inn)], 0.002, y=yy, mat="insert_screen")
            for bx in (0.04, L - h * 0.75):
                for yy in (-0.04, 0.04):
                    b.sphere(0.011, bx, yy, 0, "gold", u=6, v=4)


def destination_signpost():
    b = Builder("destination_signpost")
    wf_post(b, 0, 0, h=1.95, w=0.16)
    arrows = ((1.75, 0, 0.95, WF_FRAME), (1.48, 180, 0.85, WF_CORNER), (1.21, 20, 0.85, WF_FRAME))
    for k, (z, rz, L, frame) in enumerate(arrows):
        wf_arrow(b, f"arrow_{k}", L, 0.22, z, rz, frame)
        b.socket(f"arrow_{k}", (0, 0, z), rotz=rz)
    return done(b, "wayfinding", {"aim": "rotate part_arrow_* about z; each arrow points local +X; default yaw in socket",
                                  "insert": "destination name on both arrow faces", "label_insert": "part_arrow_* faces"})


def activity_sign():
    """One hanging sign for every activity: drop an icon_* decal on socket_icon and text on socket_label."""
    b = Builder("activity_sign")
    wf_post(b, -0.55, 0, h=1.85, w=0.17)
    b.box(1.35, 0.13, 0.13, 0.05, 0, 1.78, "wood", bevel=0.02)
    b.box(0.07, 0.08, 0.5, -0.32, 0, 1.38, "wood_dark", bevel=0.01, rot=(0, -45, 0))
    for x in (-0.12, 0.42):
        b.box(0.06, 0.12, 0.08, x, 0, 1.68, "iron", bevel=0.006)
    snow_cap(b, 1.1, 0.14, 0.15, 0, 1.91, h=0.05)
    for x in (-0.06, 0.36):
        chain(b, x, 0, 1.69, 1.56)
    PW, PH, PZ = 0.7, 0.7, 0.86
    fy = wf_panel(b, PW, PH, 0.15, 0, PZ)
    b.socket("icon", (0.15, fy - ICON_GAP, PZ + PH / 2 + 0.03))
    # label strip under the panel: readable activity name (localised, from world data)
    b.box(PW - 0.1, 0.05, 0.14, 0.15, 0, PZ - 0.2, "cream", bevel=0.01)
    b.box(PW - 0.1, 0.06, 0.03, 0.15, 0, PZ - 0.07, WF_FRAME, bevel=0.006)
    b.box(PW - 0.16, 0.002, 0.1, 0.15, -0.026, PZ - 0.18, "insert_screen", bevel=0)
    for x in (-0.12, 0.42):
        b.box(0.02, 0.02, 0.07, x, 0, PZ - 0.07, "iron", bevel=0)
    b.socket("label", (0.15, -0.03, PZ - 0.13))
    return done(b, "wayfinding", {"insert": "icon", "label_insert": "socket_label",
                                  "icons": ["icon_cafe", "icon_cinema", "icon_arcade", "icon_fishing", "icon_sled",
                                            "icon_snowball", "icon_basketball", "icon_drawing"]})


def thick(pts, w):
    """Outline polygon of a polyline of width w (open stroke)."""
    L, R = [], []
    for i, p in enumerate(pts):
        a = Vector(pts[max(0, i - 1)]); c = Vector(pts[min(len(pts) - 1, i + 1)])
        d = (c - a).normalized()
        nrm = Vector((-d.y, d.x)) * (w / 2)
        L.append((p[0] + nrm.x, p[1] + nrm.y)); R.append((p[0] - nrm.x, p[1] - nrm.y))
    return L + R[::-1]


def arcpts(cx, cy, r, a0, a1, n=12):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def icon(name, colour, shapes, accents=()):
    """Flat 5 mm decal facing -Y; back face at y=0 so it sits ICON_GAP in front of the panel at socket_icon."""
    b = Builder(name)
    m = tint("icon", colour)
    for pts in shapes:
        b.prism(pts, ICON_D, y=-ICON_D / 2, mat=m)
    for pts in accents:  # cream cut-out details, 1 mm proud
        b.prism(pts, 0.001, y=-ICON_D - 0.0005, mat="cream")
    return done(b, "decal", {"decal": True, "attach": "activity_sign socket_icon", "label_insert": "activity_sign socket_label",
                             "icon_size_m": 0.44})


def build_icons():
    C, T = "coral", "teal"
    icon("icon_cafe", C, [
        [(-0.14, 0.04), (0.1, 0.04), (0.09, -0.1), (0.05, -0.13), (-0.09, -0.13), (-0.13, -0.1)],
        thick(arcpts(0.11, -0.03, 0.05, 90, -90, 8), 0.03),
        [(-0.2, -0.16), (0.16, -0.16), (0.12, -0.19), (-0.16, -0.19)],
        thick([(-0.06, 0.08), (-0.08, 0.12), (-0.05, 0.16), (-0.07, 0.2)], 0.025),
        thick([(0.02, 0.08), (0.0, 0.12), (0.03, 0.16), (0.01, 0.2)], 0.025)])
    icon("icon_cinema", T, [ell(0, 0.02, 0.17, 0.17, 16), thick([(0.1, -0.12), (0.17, -0.17), (0.22, -0.13)], 0.04)],
         accents=[ell(0.1 * math.cos(math.radians(90 + 72 * k)), 0.02 + 0.1 * math.sin(math.radians(90 + 72 * k)), 0.035, 0.035, 10) for k in range(5)]
         + [ell(0, 0.02, 0.02, 0.02, 8)])
    icon("icon_arcade", C, [
        [(-0.18, -0.2), (0.18, -0.2), (0.16, -0.12), (-0.16, -0.12)],
        [(-0.022, -0.12), (0.022, -0.12), (0.022, 0.06), (-0.022, 0.06)],
        ell(0, 0.1, 0.075, 0.075, 14), [(-0.08, -0.14), (0.08, -0.14), (0.06, -0.1), (-0.06, -0.1)]])
    icon("icon_fishing", T, [
        thick([(0.0, 0.15), (0.0, -0.08)] + arcpts(-0.07, -0.08, 0.07, 0, -180, 10)[1:] + [(-0.14, -0.03)], 0.03),
        [(-0.155, -0.03), (-0.125, -0.03), (-0.1, 0.02)],
        thick(arcpts(0.0, 0.18, 0.035, -60, 250, 12), 0.022)])
    icon("icon_sled", C, [
        [(-0.17, -0.02), (0.08, -0.02), (0.16, 0.06), (0.17, 0.12), (0.12, 0.12), (0.08, 0.03), (-0.17, 0.03)],
        thick([(-0.2, -0.12), (0.12, -0.12)] + arcpts(0.12, -0.07, 0.05, -90, 90, 8)[1:], 0.028),
        [(-0.13, -0.12), (-0.1, -0.12), (-0.1, -0.02), (-0.13, -0.02)],
        [(0.03, -0.12), (0.06, -0.12), (0.06, -0.02), (0.03, -0.02)]])
    icon("icon_snowball", T, [thick(arcpts(-0.055, -0.03, 0.11, 10, 350, 20), 0.03),
                              thick(arcpts(0.065, 0.04, 0.11, 190, 530, 20), 0.03)])
    icon("icon_basketball", C, [ell(0, 0, 0.18, 0.18, 18)],
         accents=[thick([(-0.18, 0), (0.18, 0)], 0.016), thick([(0, -0.18), (0, 0.18)], 0.016),
                  thick(arcpts(-0.26, 0, 0.19, -45, 45, 8), 0.016), thick(arcpts(0.26, 0, 0.19, 135, 225, 8), 0.016)])
    with_rot = lambda pts, a: [(x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)) for x, y in pts]
    a = math.radians(45)
    icon("icon_drawing", T, [
        with_rot([(-0.13, -0.035), (0.12, -0.035), (0.12, 0.035), (-0.13, 0.035)], a),
        with_rot([(-0.13, -0.035), (-0.13, 0.035), (-0.21, 0.0)], a),
        with_rot([(0.135, -0.035), (0.18, -0.035), (0.18, 0.035), (0.135, 0.035)], a)])


def home_number_plaque():
    b = Builder("home_number_plaque")
    for sx in (-1, 1):
        wf_base(b, sx * 0.32, 0, s=0.7)
        b.box(0.1, 0.1, 0.6, sx * 0.32, 0, 0.04, "wood_b", bevel=0.015)
    b.box(0.78, 0.07, 0.42, 0, 0, 0.3, "wood", bevel=0.015)
    crest = [(-0.42, 0), (0.42, 0), (0.42, 0.06)] + [(0.4 * math.cos(math.radians(t)), 0.06 + 0.12 * math.sin(math.radians(t))) for t in range(10, 171, 20)] + [(-0.42, 0.06)]
    b.prism(crest, 0.09, 0, 0, 0.7, WF_CAP)
    for k in range(5):
        b.blob(0.11, 0.06, 0.04, -0.3 + 0.15 * k, 0, 0.78 + 0.1 * math.sin(math.pi * (k + 0.5) / 5), "snow", subdiv=1, jitter=0.008)
    b.box(0.56, 0.02, 0.26, 0, -0.04, 0.38, "cream", bevel=0.006)
    b.box(0.5, 0.002, 0.2, 0, -0.051, 0.41, "insert_screen", bevel=0)
    for bx in (-0.24, 0.24):
        b.sphere(0.012, bx, -0.055, 0.51, "gold", u=6, v=4)
    b.socket("number", (0, -0.053, 0.51))
    return done(b, "wayfinding", {"insert": "home number (from housing data)", "label_insert": "socket_number"})


def queue_spot(name, stone=False):
    """Floor decal 3 mm above the ground, no collision. The stone surround is the optional variant."""
    b = Builder(name)
    z = 0.003
    b.prism(ell(0, 0, 0.42, 0.42, 24), 0.002, z=z, mat=tint("queue_ring", "coral"), plane="xy")
    b.prism(ell(0, 0, 0.34, 0.34, 24), 0.0015, z=z + 0.0025, mat=tint("queue", "teal"), plane="xy")
    for sx, dy in ((-0.08, -0.03), (0.08, 0.03)):
        b.prism(ell(sx, dy - 0.02, 0.045, 0.085, 12), 0.0015, z=z + 0.0045, mat="cream", plane="xy")
        b.prism(ell(sx, dy + 0.1, 0.035, 0.035, 10), 0.0015, z=z + 0.0045, mat="cream", plane="xy")
    if stone:
        for k in range(12):
            a = 360 * k / 12
            with b.at((0.5 * math.cos(math.radians(a)), 0.5 * math.sin(math.radians(a)), 0), rotz=a + 90):
                b.box(0.25, 0.16, 0.05, 0, 0, 0, pick(("stone", "stone_grey", "paving_b"), k), bevel=0.02, jitter=0.004)
        for k in range(4):
            a = math.radians(30 + 90 * k)
            b.blob(0.1, 0.07, 0.035, 0.52 * math.cos(a), 0.52 * math.sin(a), 0.05, "snow", subdiv=1, jitter=0.006)
    b.socket("spot", (0, 0, z + 0.006))
    meta = {"decal": not stone, "collision": "none" if not stone else "surround lip only (5 cm)",
            "note": "reserved-slot state needs authoritative interaction logic, not just this marker"}
    return done(b, "marker", meta)


def build():
    footbridge()
    homes_arch()
    mailbox()
    signpost()
    notice_board()
    notice_board("notice_board_club", top="club")
    world_map_board()
    destination_signpost()
    activity_sign()
    build_icons()
    home_number_plaque()
    queue_spot("queue_spot_marker")
    queue_spot("queue_spot_marker_stone", stone=True)
    waterfall_step()
    barrel()
    crate()
