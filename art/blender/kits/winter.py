"""Winter kit: sledding hill pieces and the snowball arena (concepts 16 and 18, brief sections 12 and 13)."""
from common import *

KIT = "winter"
PREVIEW_WIDTH = 16.0
SNOW = ("snow", "snow", "snow_shade")
PENNANTS = (tint("pennant_a", "coral"), tint("pennant_b", "teal_light"), tint("pennant_c", "cream"), tint("pennant_d", "mustard"))
TEAM = tint("team", "coral")
TEAM_A, TEAM_B = tint("team_a", "coral"), tint("team_b", "teal")
TEAM_VARIANTS = ["#E86D58", "#207D85"]


# ---------------------------------------------------------------- local helpers
def heightfield(b, fn, nu, nv, top="snow", side="snow_shade"):
    """Closed solid: top surface fn(u, v)->(x, y, z) over a nu x nv grid, skirts down to z=0."""
    P = [[fn(i / (nu - 1), j / (nv - 1)) for j in range(nv)] for i in range(nu)]
    vs, idx = [], {}
    for i in range(nu):
        for j in range(nv):
            idx[i, j] = len(vs)
            vs.append(P[i][j])
    faces = [(idx[i, j], idx[i + 1, j], idx[i + 1, j + 1], idx[i, j + 1]) for i in range(nu - 1) for j in range(nv - 1)]
    b.mesh(vs, faces, top)
    ring = [(i, 0) for i in range(nu)] + [(nu - 1, j) for j in range(1, nv)] + \
           [(i, nv - 1) for i in range(nu - 2, -1, -1)] + [(0, j) for j in range(nv - 2, 0, -1)]
    sv = []
    for (i, j) in ring:
        x, y, z = P[i][j]
        sv += [(x, y, z), (x, y, 0.0)]
    n = len(ring)
    sf = [(2 * k + 1, 2 * ((k + 1) % n) + 1, 2 * ((k + 1) % n), 2 * k) for k in range(n)]
    sf.append(tuple(2 * k + 1 for k in range(n))[::-1])
    b.mesh(sv, sf, side)


def snow_block(b, sx, sy, sz, x, y, z, i=0, bevel=0.07, rot=(0, 0, 0)):
    b.box(sx, sy, sz, x, y, z, pick(SNOW, i), bevel=bevel, jitter=0.02, rot=rot)


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


def snow_lumps(b, x, y, z, w, d, n, r=(0.1, 0.2), flat=0.55):
    for k in range(n):
        rr = b.rng.uniform(*r)
        b.blob(rr * 1.3, rr * 1.1, rr * flat, x + b.rng.uniform(-w / 2, w / 2), y + b.rng.uniform(-d / 2, d / 2),
               z, pick(SNOW, k), subdiv=1, jitter=rr * 0.12)


def strip(b, pts, w, t, mat, x=0.0):
    """Rectangular bar following a polyline in the YZ plane (pts = [(y, z)...]) at offset x."""
    for (y0, z0), (y1, z1) in zip(pts, pts[1:]):
        L = math.hypot(y1 - y0, z1 - z0)
        ang = math.degrees(math.atan2(z1 - z0, y1 - y0))
        b.box(w, L + t * 0.9, t, x, (y0 + y1) / 2, (z0 + z1) / 2, mat, bevel=0.006, rot=(ang, 0, 0), center=True)


def snow_post(b, x, y, z=0.0, h=0.9, w=0.14, mat="wood_b"):
    b.box(w, w, h, x, y, z, mat, bevel=0.02)
    b.box(w + 0.05, w + 0.05, 0.07, x, y, z + h, "snow", bevel=0.03)
    b.blob(w * 0.55, w * 0.55, 0.06, x, y, z + h + 0.07, "snow", subdiv=1)


def snowy_fir(b, x=0, y=0, z=0, h=2.2, r=0.75, tiers=4):
    """Fir with a snow layer sitting on every tier and a snow mound at its foot."""
    b.cyl(r * 0.14, h * 0.2, x, y, z, "bark", segs=6, bevel=0.01)
    for i in range(tiers):
        t = i / tiers
        rr = r * (1 - t * 0.62)
        zz = z + h * 0.14 + (h * 0.72 / tiers) * i
        hh = h * 0.36
        b.cyl(rr, hh, x, y, zz, pick(("pine", "pine_b"), i), segs=7, r2=0.03, jitter=rr * 0.035)
        # snow shell: same slope, upper half, slightly proud of the needles
        b.cyl(rr * 0.6 + 0.025, hh * 0.52, x, y, zz + hh * 0.42, "snow", segs=7, r2=0.035, jitter=rr * 0.02)
    b.cyl(0.07 * r, h * 0.12, x, y, z + h * 0.14 + (h * 0.72 / tiers) * (tiers - 1) + h * 0.3, "snow", segs=7, r2=0.0)
    b.blob(r * 0.85, r * 0.85, 0.12, x, y, z + 0.02, "snow", subdiv=1, jitter=0.03)


def snowy_rock(b, x, y, rx, ry, rz, i=0):
    b.blob(rx, ry, rz, x, y, rz * 0.6, pick(("stone_grey", "rock_grey", "stone_grey"), i), subdiv=1, jitter=min(rx, rz) * 0.1)
    b.blob(rx * 0.82, ry * 0.82, rz * 0.32, x - rx * 0.05, y + ry * 0.05, rz * 1.32, "snow", subdiv=1, jitter=rz * 0.04)


# ---------------------------------------------------------------- sledding
def sled():
    b = Builder("sled")
    for sx in (-0.2, 0.2):
        # runner: flat along the ground, then curling up and back at the front (-Y)
        pts = [(0.5, 0.03), (0.2, 0.025), (-0.38, 0.025)]
        for k in range(1, 12):
            t = math.radians(k * 22)
            pts.append((-0.38 - 0.13 * math.sin(t), 0.155 - 0.13 * math.cos(t)))
        strip(b, pts, 0.045, 0.035, "wood_dark", x=sx)
        for yy in (0.32, -0.08, -0.3):
            b.box(0.04, 0.05, 0.13, sx, yy, 0.03, "wood_dark", bevel=0.008)
    for yy in (0.32, -0.08, -0.3):
        b.box(0.5, 0.06, 0.04, 0, yy, 0.14, "wood_b", bevel=0.01)
    for k, xx in enumerate((-0.18, -0.06, 0.06, 0.18)):
        b.box(0.105, 0.9, 0.035, xx, 0.04, 0.18, pick(WOOD, k), bevel=0.012)
    b.box(0.46, 0.05, 0.035, 0, -0.42, 0.185, "wood_b", bevel=0.01)
    # pull rope looping forward from both runner curls
    top = (-0.38 - 0.13 * math.sin(math.radians(140)), 0.155 - 0.13 * math.cos(math.radians(140)))
    rope_between(b, (-0.2, top[0], top[1]), (0, -0.78, 0.2), sag=0.06, r=0.012, segs=5)
    rope_between(b, (0, -0.78, 0.2), (0.2, top[0], top[1]), sag=0.06, r=0.012, segs=5)
    b.socket("rider", (0, 0.05, 0.215))
    b.socket("pull", (0, -0.78, 0.2))
    return done(b, "activity", {"activity": "sledding"})


CH_W = 2.0     # chute floor width
BERM = 0.6     # berm width each side
DROP = 1.0     # height lost per 4 m straight section
BASE = 0.15    # snow thickness at the low end


def chute_profile(u):
    """Height offset across the chute (u: 0..1 over berm + floor + berm)."""
    w = CH_W + 2 * BERM
    d = abs(u - 0.5) * w
    if d <= CH_W / 2:
        return 0.04 * (d / (CH_W / 2)) ** 2
    t = min(1.0, (d - CH_W / 2) / (BERM * 0.55))
    return 0.04 + 0.4 * (math.sin(t * math.pi / 2))


def slope_section():
    b = Builder("slope_section")
    W, L = CH_W + 2 * BERM, 4.0
    rng = b.rng

    def fn(u, v):
        x, y = -W / 2 + u * W, -L / 2 + v * L
        z = BASE + DROP * v + chute_profile(u)
        if 0 < u < 1 and 0 < v < 1:
            z += rng.uniform(-0.035, 0.035)  # visible facets on the snow field
        return (x, y, z)
    heightfield(b, fn, 11, 9)
    # chunky snow blocks along both berm crests
    for side in (-1, 1):
        for k in range(5):
            v = (k + 0.5) / 5
            snow_block(b, 0.42, 0.75, 0.22, side * (W / 2 - 0.28), -L / 2 + v * L, BASE + DROP * v + 0.36, k, bevel=0.06,
                       rot=(math.degrees(math.atan2(DROP, L)), 0, 0))  # follow the slope so no end floats
    # sled tracks pressed into the floor
    for xx in (-0.25, 0.25):
        b.box(0.06, L - 0.2, 0.02, xx, 0, BASE + DROP / 2 + 0.01, "snow_shade", bevel=0,
              rot=(math.degrees(math.atan2(DROP, L)), 0, 0), center=True)
    b.socket("entry", (0, L / 2, BASE + DROP), rotz=180)
    b.socket("exit", (0, -L / 2, BASE), rotz=0)
    return done(b, "track", {"module_m": [W, L], "drop_m": DROP, "travel": "-Y",
                                   "snap": "entry socket (high, +Y) meets previous exit (low, -Y)"})


def banked_turn():
    """90° right-hand turn: enter heading -Y, leave heading -X; outer edge banked up."""
    b = Builder("banked_turn")
    W = CH_W + 2 * BERM
    Rm = 3.0
    cx = -Rm
    drop = DROP * 0.6
    rng = b.rng

    def fn(u, v):
        r = Rm - W / 2 + u * W
        th = -math.radians(90) * v
        x, y = cx + r * math.cos(th), r * math.sin(th)
        z = surf(u, v)
        if 0 < u < 1 and 0 < v < 1:
            z += rng.uniform(-0.035, 0.035)  # visible facets on the snow field
        return (x, y, z)

    def surf(u, v):
        # outer side banked up mid-turn, tapering to the straight profile at both ends for snapping
        return BASE + drop * (1 - v) + chute_profile(u) + 0.35 * max(0.0, (u - 0.5) * 2) ** 2 * math.sin(math.pi * v)
    # centre the footprint
    xs = [cx, cx + Rm + W / 2]
    ys = [-(Rm + W / 2), 0]
    off = (-(xs[0] + xs[1]) / 2, -(ys[0] + ys[1]) / 2, 0)
    with b.at(off):
        heightfield(b, fn, 9, 12)
        for k in range(6):
            v = (k + 0.5) / 6
            th = -math.radians(90) * v
            r = Rm + W / 2 - 0.3
            z = surf(0.92, v) - 0.02
            with b.at((cx + r * math.cos(th), r * math.sin(th), 0), rotz=math.degrees(th)):
                snow_block(b, 0.45, 0.8, 0.26, 0, 0, z - 0.04, k, rot=(math.degrees(math.atan2(drop, r * math.pi / 2)), 0, 0))
        b.socket("entry", (0, 0, BASE + drop), rotz=180)
        b.socket("exit", (cx, -Rm, BASE), rotz=90)
    return done(b, "track", {"turn_deg": 90, "drop_m": drop, "travel": "-Y then -X"})


def start_platform():
    """Snow-topped launch block whose deck matches a slope_section entry (z = BASE + DROP)."""
    b = Builder("start_platform")
    W, D, H = CH_W + 2 * BERM, 2.0, BASE + DROP
    heightfield(b, lambda u, v: (-W / 2 + u * W, -D / 2 + v * D, H + (chute_profile(u) if u < 0.2 or u > 0.8 else 0)), 7, 3)
    planks(b, CH_W - 0.3, 1.6, z=H, plank=0.2, thick=0.05, along="y", y=0.05)
    # back steps up onto the platform
    n = 5
    for k in range(n):
        zz = H * (k + 1) / n
        b.box(1.2, 0.34, zz, 0, D / 2 + 0.17 + 0.34 * (n - 1 - k), 0, pick(("stone", "stone_dark"), k), bevel=0.03)
        b.box(1.2, 0.34, 0.06, 0, D / 2 + 0.17 + 0.34 * (n - 1 - k), zz, "snow", bevel=0.025)
    for sx in (-1, 1):
        snow_post(b, sx * (CH_W / 2 + 0.2), -D / 2 + 0.15, H + 0.3, h=0.7)
        snow_post(b, sx * (CH_W / 2 + 0.2), D / 2 - 0.15, H + 0.3, h=0.7)
        b.box(0.08, D - 0.3, 0.08, sx * (CH_W / 2 + 0.2), 0, H + 0.85, "wood_b", bevel=0.015)
    for k in range(3):
        b.socket(f"start_{k}", (-0.6 + 0.6 * k, -0.4, H + 0.05))
    b.socket("exit", (0, -D / 2, H), rotz=0)
    b.socket("stairs", (0, D / 2 + 1.9, 0), rotz=180)
    return done(b, "track", {"deck_height_m": H})


def sign_board(b, w, h, x, y, z, face="insert_sign"):
    b.box(w + 0.1, 0.07, h + 0.1, x, y, z - 0.05, tint("sign_frame", "wood_dark"), bevel=0.02)
    b.box(w, 0.02, h, x, y - 0.04, z, face, bevel=0.0)


def start_gate():
    b = Builder("start_gate")
    S = 1.45
    for sx in (-1, 1):
        b.blob(0.32, 0.32, 0.16, sx * S, 0, 0.02, "snow", subdiv=1, jitter=0.03)
        b.box(0.2, 0.2, 2.3, sx * S, 0, 0, "wood_b", bevel=0.025)
        b.box(0.26, 0.26, 0.14, sx * S, 0, 0, "wood_dark", bevel=0.02)
        # lantern on the outer face of each post
        b.box(0.04, 0.2, 0.04, sx * S, -0.18, 1.55, "iron", bevel=0)
        lantern_head(b, sx * S, -0.3, 1.18, 0.85)
    b.box(3.5, 0.24, 0.22, 0, 0, 2.3, "wood", bevel=0.03)
    b.box(3.2, 0.18, 0.12, 0, 0, 2.12, "wood_dark", bevel=0.02)
    for sx in (-1, 1):
        b.box(0.12, 0.14, 0.5, sx * (S - 0.25), 0, 1.95, "wood_dark", bevel=0.015, rot=(0, sx * -40, 0))
    snow_cap(b, 3.55, 0.3, 0, 0, 2.52, h=0.08)
    sign_board(b, 1.3, 0.38, 0, -0.06, 1.68)
    for sx in (-0.45, 0.45):
        b.cyl(0.012, 0.16, sx, -0.06, 2.06, "iron", segs=4)
    b.socket("sign", (0, -0.12, 1.87))
    return done(b, "track", {"sign_text": "START"})


def finish_flags():
    b = Builder("finish_flags")
    S = 1.5
    for sx in (-1, 1):
        b.blob(0.3, 0.3, 0.18, sx * S, 0, 0.03, "snow", subdiv=1, jitter=0.04)
        snow_post(b, sx * S, 0, 0, h=1.9, w=0.15)
    # banner hung from the posts
    b.box(2.0, 0.03, 0.42, 0, 0, 1.06, "insert_sign", bevel=0.0)
    b.box(2.08, 0.05, 0.05, 0, 0, 1.48, tint("banner_trim", "red_dark"), bevel=0.01)
    b.box(2.08, 0.05, 0.05, 0, 0, 1.04, tint("banner_trim", "red_dark"), bevel=0.01)
    for sx in (-1, 1):
        rope_between(b, (sx * 1.04, 0, 1.5), (sx * S, 0, 1.56), sag=0.0, r=0.012, segs=1)
        rope_between(b, (sx * 1.04, 0, 1.06), (sx * S, 0, 1.1), sag=0.0, r=0.012, segs=1)
    bunting(b, (-S, 0, 1.9), (S, 0, 1.9), n=7, colors=PENNANTS, size=0.18, sag=0.05)
    b.socket("finish_line", (0, 0, 0))
    return done(b, "track", {"sign_text": "FINISH"})


def snow_fence(length):
    b = Builder(f"snow_fence_{length}m")
    n = int(length) + 1
    for k in range(n):
        snow_post(b, -length / 2 + k * (length / (n - 1)), 0, 0, h=0.75, w=0.13, mat=pick(("wood_b", "wood"), k))
    for zz in (0.3, 0.6):
        b.box(length, 0.07, 0.1, 0, 0.02, zz, "wood", bevel=0.015)
    snow_lumps(b, 0, 0.02, 0.71, length * 0.9, 0.04, int(length * 3), r=(0.04, 0.07))
    return done(b, "fence", {"module_m": length})


def snowbank(name, w, d, h, n):
    b = Builder(name)
    b.blob(w / 2, d / 2, h * 0.85, 0, 0, 0, "snow", subdiv=1, jitter=h * 0.07)
    for k in range(n):
        a = 2 * math.pi * k / n + b.rng.uniform(-0.3, 0.3)
        r = b.rng.uniform(0.25, 0.4) * min(w, d)
        b.blob(r, r * 0.9, r * 0.7, math.cos(a) * w * 0.38, math.sin(a) * d * 0.38, r * 0.3, pick(SNOW, k), subdiv=1, jitter=r * 0.08)
    return done(b, "nature", {"collider": "ellipsoid", "size_m": [w, d, h]})


def fir_tree(name, h, r, tiers):
    b = Builder(name)
    snowy_fir(b, h=h, r=r, tiers=tiers)
    return done(b, "nature")


def rock_cluster(name, specs):
    b = Builder(name)
    for i, (x, y, rx, ry, rz) in enumerate(specs):
        snowy_rock(b, x, y, rx, ry, rz, i)
    snow_lumps(b, 0, -0.3, 0.02, 1.2, 0.4, 3, r=(0.08, 0.14))
    return done(b, "nature")


def stone_stairs_snow():
    """1 m return-path stair module: climbs 0.5 m toward +Y, wooden rails both sides."""
    b = Builder("stone_stairs_snow")
    W, L, RISE, n = 1.4, 1.0, 0.5, 3
    for k in range(n):
        zz = RISE * (k + 1) / n
        y = -L / 2 + L * (k + 0.5) / n
        b.box(W, L / n + 0.02, zz, 0, y, 0, pick(("stone", "stone_dark", "paving_b"), k), bevel=0.03)
        b.box(W * 0.62, 0.12, 0.035, b.rng.uniform(-0.15, 0.15), y - L / n / 2 + 0.08, zz, "snow", bevel=0.015)
    for sx in (-1, 1):
        b.box(0.22, L, RISE + 0.12, sx * (W / 2 + 0.11), 0, 0, "stone_grey", bevel=0.035)
        b.box(0.26, L + 0.02, 0.06, sx * (W / 2 + 0.11), 0, RISE + 0.12, "snow", bevel=0.025)
        snow_post(b, sx * (W / 2 + 0.11), -L / 2 + 0.12, RISE / n + 0.12, h=0.55, w=0.1)
        strip(b, [(-L / 2 + 0.1, RISE / n + 0.6), (L / 2, RISE + 0.55)], 0.08, 0.06, "wood", x=sx * (W / 2 + 0.11))
    b.socket("bottom", (0, -L / 2 - 0.3, 0), rotz=0)
    b.socket("top", (0, L / 2, RISE), rotz=0)
    return done(b, "path", {"module_m": [W, L], "rise_m": RISE, "climb": "+Y"})


# ---------------------------------------------------------------- snowball arena
WALL_H = 0.7
WALL_T = 0.6


def wall_blocks(b, length, x0=0.0, y=0.0, seed=0):
    """Two staggered courses of faceted snow blocks along +X; bounding box = length x WALL_T x WALL_H."""
    for c, zz in enumerate((0.0, WALL_H / 2)):
        n = max(1, round(length / 0.55))
        bw = length / n
        offs = [0.0] if c == 0 else [-bw / 2]
        xs = [x0 + bw * (k + 0.5) for k in range(n)] if c == 0 else \
             [x0 + bw * 0.25] + [x0 + bw * (k + 1) for k in range(n - 1)] + [x0 + length - bw * 0.25]
        ws = [bw] * n if c == 0 else [bw / 2] + [bw] * (n - 1) + [bw / 2]
        for k, (xx, ww) in enumerate(zip(xs, ws)):
            snow_block(b, ww - 0.02, WALL_T - b.rng.uniform(0, 0.04), WALL_H / 2 - 0.01, xx, y, zz, k + c + seed, bevel=0.06)


def snow_wall_straight():
    b = Builder("snow_wall_straight")
    wall_blocks(b, 2.0, -1.0)
    return done(b, "cover", {"collider_box": [2.0, WALL_T, WALL_H], "module_m": 2.0})


def snow_wall_corner():
    b = Builder("snow_wall_corner")
    A = 1.6
    wall_blocks(b, A, -A / 2, -A / 2 + WALL_T / 2)
    with b.at((-A / 2 + WALL_T / 2, 0, 0), rotz=90):
        wall_blocks(b, A - WALL_T, -A / 2 + WALL_T, 0, seed=3)
    return done(b, "cover", {"collider_boxes": [[0, -A / 2 + WALL_T / 2, A, WALL_T, WALL_H],
                                                      [-A / 2 + WALL_T / 2, WALL_T / 2, WALL_T, A - WALL_T, WALL_H]]})


def snow_bank_cover():
    b = Builder("snow_bank_cover")
    b.blob(0.6, 0.45, 0.52, 0, 0, 0.08, "snow", subdiv=1, jitter=0.03)
    b.blob(0.28, 0.24, 0.18, -0.12, 0.05, 0.5, "snow", subdiv=1, jitter=0.02)
    b.blob(0.34, 0.3, 0.3, 0.42, -0.12, 0.1, "snow_shade", subdiv=1, jitter=0.03)
    b.blob(0.3, 0.26, 0.24, -0.45, 0.14, 0.08, "snow", subdiv=1, jitter=0.03)
    b.box(1.1, 0.8, 0.12, 0, 0, 0, "snow", bevel=0.05, jitter=0.02)
    return done(b, "cover", {"collider_box": [1.2, 0.9, 0.6]})


def snowball():
    b = Builder("snowball")
    b.blob(0.09, 0.09, 0.09, 0, 0, 0.09, "snow", subdiv=1, jitter=0.008)
    return done(b, "projectile", {"radius_m": 0.09})


def snowball_pile():
    b = Builder("snowball_pile")
    r = 0.09
    k = 0
    for layer, (n, ring) in enumerate(((7, 0.2), (4, 0.1), (1, 0.0))):
        for i in range(n):
            a = 2 * math.pi * i / max(1, n - (1 if layer == 0 else 0)) + layer
            rr = ring if (layer != 0 or i < n - 1) else 0
            x, y = (math.cos(a) * rr, math.sin(a) * rr)
            b.blob(r, r, r * 0.95, x, y, r + layer * r * 1.45, pick(SNOW, k), subdiv=1, jitter=0.01)
            k += 1
    b.blob(0.3, 0.3, 0.05, 0, 0, 0.0, "snow_shade", subdiv=1)
    return done(b, "prop", {"interact": "refill"})


def team_flag():
    b = Builder("team_flag")
    colour = TEAM
    b.box(0.3, 0.3, 0.16, 0, 0, 0, "wood_dark", bevel=0.03)
    b.box(0.24, 0.24, 0.06, 0, 0, 0.16, "snow", bevel=0.025)
    b.cyl(0.04, 1.75, 0, 0, 0.1, "wood", segs=6)
    b.sphere(0.06, 0, 0, 1.87, "gold", u=6, v=4)
    # waving cloth: columns of verts offset in Y, flying toward +X
    cols, H, W, z0 = 5, 0.55, 0.85, 1.22
    vs, fs = [], []
    for c in range(cols):
        x = 0.04 + W * c / (cols - 1)
        y = 0.06 * math.sin(c * 1.4)
        zz = z0 - 0.05 * c / (cols - 1)
        vs += [(x, y - 0.012, zz), (x, y - 0.012, zz + H), (x, y + 0.012, zz), (x, y + 0.012, zz + H)]
    for c in range(cols - 1):
        a, n = 4 * c, 4 * (c + 1)
        fs += [(a, n, n + 1, a + 1), (a + 2, a + 3, n + 3, n + 2), (a + 1, n + 1, n + 3, a + 3), (a, a + 2, n + 2, n)]
    last = 4 * (cols - 1)
    fs += [(0, 1, 3, 2), (last, last + 2, last + 3, last + 1)]
    b.mesh(vs, fs, colour)
    # bird emblem (round body, two eyes) on the cloth front, matching the concept flags
    ex, ez, ey = 0.44, z0 + H / 2 - 0.02, 0.06 * math.sin(2 * 1.4) - 0.02
    b.blob(0.13, 0.02, 0.15, ex, ey, ez, "cream", subdiv=1)
    for dx in (-0.045, 0.045):
        b.blob(0.018, 0.012, 0.022, ex + dx, ey - 0.02, ez + 0.03, "navy", subdiv=1)
    b.blob(0.025, 0.012, 0.015, ex, ey - 0.022, ez - 0.015, "beak", subdiv=1)
    return done(b, "team", {"color_variants": TEAM_VARIANTS})


def snow_puff():
    b = Builder("snow_puff")
    b.blob(0.16, 0.16, 0.13, 0, 0, 0.18, "snow", subdiv=1, jitter=0.02)
    for k in range(9):
        a = 2 * math.pi * k / 9
        d = b.rng.uniform(0.15, 0.3)
        r = b.rng.uniform(0.04, 0.09)
        b.blob(r, r, r, math.cos(a) * d, math.sin(a) * d, 0.12 + b.rng.uniform(0, 0.25), pick(SNOW, k), subdiv=1, jitter=r * 0.15)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        r = 0.025
        b.blob(r, r, r, math.cos(a) * 0.42, math.sin(a) * 0.42, 0.3 + 0.08 * (k % 2), "white", subdiv=0)
    return done(b, "fx", {"fx": "hit"})


def ready_pad():
    b = Builder("ready_pad")
    colour = TEAM
    b.cyl(0.5, 0.05, 0, 0, 0, "snow_shade", segs=10, bevel=0.015)
    b.cyl(0.45, 0.06, 0, 0, 0.0, colour, segs=10, bevel=0.015)
    b.cyl(0.3, 0.065, 0, 0, 0.0, "cream", segs=10, bevel=0.01)
    b.cyl(0.24, 0.07, 0, 0, 0.0, colour, segs=10, bevel=0.01)
    for sx in (-1, 1):
        b.blob(0.06, 0.09, 0.012, sx * 0.07, 0, 0.075, "cream", subdiv=1)
    snow_post(b, 0.0, 0.55, 0, h=0.55, w=0.1)
    b.box(0.28, 0.03, 0.18, 0.0, 0.5, 0.36, colour, bevel=0.01)
    b.socket("ready", (0, 0, 0.07))
    return done(b, "team", {"color_variants": TEAM_VARIANTS})


def bench(b, L=1.6, x=0, y=0, rotz=0):
    with b.at((x, y, 0), rotz=rotz):
        for sx in (-1, 1):
            b.box(0.12, 0.42, 0.4, sx * (L / 2 - 0.15), 0, 0, "wood_dark", bevel=0.02)
            snow_lumps(b, sx * (L / 2 - 0.1), 0.0, 0.48, 0.1, 0.3, 1, r=(0.05, 0.07))
        for k, yy in enumerate((-0.12, 0.0, 0.12)):
            b.box(L, 0.11, 0.06, 0, yy, 0.4, pick(WOOD, k), bevel=0.015)
        b.box(L, 0.08, 0.3, 0, 0.2, 0.5, "wood", bevel=0.015)
        b.box(L * 0.85, 0.1, 0.04, 0, 0.2, 0.8, "snow", bevel=0.02)


def spectator_bench_snow():
    b = Builder("spectator_bench_snow")
    bench(b)
    for k in range(3):
        b.socket(f"spectator_{k}", (-0.5 + 0.5 * k, -0.02, 0.46), rotz=0)
    return done(b, "seating")


def arena_fence(b, length, lights=True):
    """Boundary posts with rope and warm string lights along +X from 0."""
    n = max(1, round(length / 2))
    for k in range(n + 1):
        snow_post(b, length * k / n, 0, 0, h=0.85, w=0.14)
    for k in range(n):
        x0, x1 = length * k / n, length * (k + 1) / n
        pts = rope_between(b, (x0, 0, 0.78), (x1, 0, 0.78), sag=0.1, r=0.014, segs=6)
        rope_between(b, (x0, 0, 0.45), (x1, 0, 0.45), sag=0.04, r=0.014, segs=4)
        if lights:
            for p in pts[1:-1:2]:
                b.sphere(0.045, p.x, p.y, p.z - 0.06, "bulb", u=6, v=4)


def arena_boundary_fence():
    b = Builder("arena_boundary_fence")
    with b.at((-1.0, 0, 0)):
        arena_fence(b, 2.0)
    return done(b, "fence", {"module_m": 2.0, "blocks": "players only; projectiles pass above 0.85 m"})


def snowball_arena_blockout():
    """Brief §13.4 topology. Origin = arena corner (brief X=0, Z=0); brief Z maps to Blender +Y."""
    b = Builder("snowball_arena_blockout")
    LX, LY = 12.0, 8.0
    rng = b.rng
    heightfield(b, lambda u, v: (u * LX, v * LY, 0.05 + (rng.uniform(0, 0.04) if 0 < u < 1 and 0 < v < 1 else 0)), 13, 9)
    colliders = []
    # spawn recesses (coral left, teal right) and their walls spanning brief Z 2.5..5.5
    for team, sx, wx, col in (("coral", 1.0, 2.5, TEAM_A), ("teal", 11.0, 9.5, TEAM_B)):
        b.cyl(0.85, 0.02, sx, 4.0, 0.05, "snow_shade", segs=10)
        b.cyl(0.7, 0.025, sx, 4.0, 0.05, col, segs=10)
        b.cyl(0.55, 0.03, sx, 4.0, 0.05, "snow", segs=10)
        with b.at((wx, 2.5, 0.05), rotz=90):
            wall_blocks(b, 3.0, 0.0, 0.0, seed=int(wx))
        colliders.append([wx, 4.0, WALL_T, 3.0, WALL_H])
        for k, yy in enumerate((3.4, 4.6)):
            b.socket(f"spawn_{team}_{k}", (sx, yy, 0.05), rotz=-90 if team == "coral" else 90)
        # team flag behind each spawn, outside the field
        fx = -0.6 if team == "coral" else LX + 0.6
        b.box(0.26, 0.26, 0.14, fx, 6.6, 0, "wood_dark", bevel=0.03)
        b.cyl(0.035, 1.6, fx, 6.6, 0.1, "wood", segs=6)
        b.box(0.03, 0.7, 0.45, fx, 6.95, 1.18, col, bevel=0.01)
    # mirrored central banks
    for k, (cx, cy) in enumerate(((5.0, 5.0), (7.0, 3.0))):
        b.blob(0.6, 0.45, 0.55, cx, cy, 0.08, "snow", subdiv=1, jitter=0.03)
        b.blob(0.3, 0.25, 0.25, cx + (0.38 if k else -0.38), cy, 0.12, "snow_shade", subdiv=1, jitter=0.02)
        b.box(1.1, 0.8, 0.12, cx, cy, 0.05, "snow", bevel=0.05)
        colliders.append([cx, cy, 1.2, 0.9, 0.6])
    # lane markers (subtle packed-snow strips) on the upper and lower routes
    for yy in (1.0, 7.0):
        for k in range(5):
            b.box(1.2, 0.35, 0.012, 1.5 + k * 2.25, yy, 0.05, "snow_shade", bevel=0.0)
    # boundary fence with the neutral gate gap (brief X 5..7 on the near side)
    with b.at((0, 0, 0)):
        arena_fence(b, 5.0)
    with b.at((7.0, 0, 0)):
        arena_fence(b, 5.0)
    with b.at((0, LY, 0)):
        arena_fence(b, LX)
    with b.at((0, 0, 0), rotz=90):
        arena_fence(b, LY)
    with b.at((LX, 0, 0), rotz=90):
        arena_fence(b, LY)
    # gate arch posts with bunting
    for gx in (5.0, 7.0):
        snow_post(b, gx, -0.05, 0, h=1.4, w=0.16)
    bunting(b, (5.0, -0.05, 1.38), (7.0, -0.05, 1.38), n=5, colors=PENNANTS, size=0.16, sag=0.08)
    # outside: ready pads by team and a spectator bench
    for k, (px, team, col) in enumerate(((4.0, "coral", TEAM_A), (4.9, "coral", TEAM_A), (7.1, "teal", TEAM_B), (8.0, "teal", TEAM_B))):
        b.cyl(0.38, 0.04, px, -1.3, 0, "snow_shade", segs=10)
        b.cyl(0.33, 0.05, px, -1.3, 0, col, segs=10, bevel=0.01)
        b.cyl(0.2, 0.055, px, -1.3, 0, "cream", segs=10)
        b.socket(f"ready_{team}_{k % 2}", (px, -1.3, 0.055), rotz=0)
    bench(b, 1.6, 6.0, -2.6)
    for k in range(3):
        b.socket(f"spectator_{k}", (5.5 + 0.5 * k, -2.62, 0.46), rotz=0)
    b.socket("gate", (6.0, 0.0, 0.05))
    b.socket("snowball_pile", (6.0, 7.5, 0.05))
    return done(b, "arena", {
        "origin": "arena corner = brief (X=0, Z=0); brief X -> +X, brief Z -> +Y",
        "field_m": [LX, LY], "cover_colliders_cx_cy_sx_sy_h": colliders,
        "lanes_y": [1.0, 4.0, 7.0], "gate_x": [5.0, 7.0], "team_tints": {"team_a": "coral side", "team_b": "teal side"},
    })


def build():
    sled()
    slope_section()
    banked_turn()
    start_platform()
    start_gate()
    finish_flags()
    snow_fence(1)
    snow_fence(2)
    snowbank("snowbank_small", 0.8, 0.6, 0.35, 3)
    snowbank("snowbank_medium", 1.4, 1.0, 0.55, 5)
    snowbank("snowbank_large", 2.2, 1.5, 0.8, 7)
    fir_tree("fir_tree_small", 1.4, 0.5, 3)
    fir_tree("fir_tree_medium", 2.2, 0.75, 4)
    fir_tree("fir_tree_large", 3.2, 1.05, 5)
    rock_cluster("rock_cluster_snow_small", [(0, 0, 0.35, 0.3, 0.28), (0.35, -0.15, 0.2, 0.18, 0.16)])
    rock_cluster("rock_cluster_snow_large", [(0, 0.1, 0.75, 0.6, 0.6), (0.7, -0.2, 0.42, 0.38, 0.35),
                                             (-0.6, -0.3, 0.32, 0.3, 0.26), (0.25, -0.6, 0.22, 0.2, 0.17)])
    stone_stairs_snow()
    snow_wall_straight()
    snow_wall_corner()
    snow_bank_cover()
    snowball()
    snowball_pile()
    team_flag()
    snow_puff()
    ready_pad()
    spectator_bench_snow()
    arena_boundary_fence()
    snowball_arena_blockout()
