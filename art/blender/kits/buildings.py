"""Shared modular architecture: walls, openings, floors, roofs and trims.

The helper functions here (masonry_wall, door_unit, window_unit, tiled_gable, ...)
are also used by the cafe and cottage prefabs, so every building has the same
construction. Modules sit on the 1 m grid. Origin is at the wall base centre and
the front faces -Y. Wall thickness is T, standard wall height is WALL_H.
"""
from common import *

KIT = "buildings"
PREVIEW_WIDTH = 16.0
T = 0.22          # wall thickness
WALL_H = 2.1      # eave height of a standard storey
BASE_H = 0.28     # stone plinth course
QUOIN = ("stone", "paving_b", "stone_dark")
# engine-recolourable roles (see common.tint)
WALL_T = tint("wall", "plaster")
ROOF_T = (tint("roof", "roof"), tint("roof_b", "roof_b"), tint("roof_c", "roof_c"))
DOOR_T = tint("door", "teal")
TRIM_T = tint("trim", "wood")
AWN_T = (tint("awning_a", "coral"), tint("awning_b", "cream"))


def seeded(name, seed):
    return Builder(name, seed=seed)


# ---------------------------------------------------------------------------
# Walls
# ---------------------------------------------------------------------------
def _spans(L, cuts):
    """Split [-L/2, L/2] into the x-ranges not covered by cuts [(x0, x1)]."""
    out, x = [], -L / 2
    for a, c in sorted(cuts):
        if a > x + 1e-4:
            out.append((x, a))
        x = max(x, c)
    if x < L / 2 - 1e-4:
        out.append((x, L / 2))
    return out


def quoin_stack(b, x, z0, z1, depth, toward=1, y=0.0):
    """Alternating long/short corner stones from z0 to z1 at wall end x.
    toward=+1 means the wall continues toward +X, so stones run inward from x."""
    z, i = z0, 0
    while z < z1 - 0.05:
        h = min(0.27, z1 - z)
        w = 0.36 if i % 2 == 0 else 0.24
        # stones stand proud of the front (-Y) face only, never through the back face
        b.box(w, depth - 0.03, h - 0.025, x + toward * w / 2, y - 0.015, z, pick(QUOIN, i), bevel=0.03)
        z += h
        i += 1


def masonry_wall(b, L, H=WALL_H, openings=(), quoins=(False, False), base=True, timber=False,
                 cap=None, mat=WALL_T, y=0.0, rng_seed=0):
    """Plaster wall along X centred at x=0, thickness T centred on y, bottom at z=0.
    openings: (cx, w, z_bottom, z_top) holes for doors and windows.
    quoins: (left_end, right_end) add stone corner blocks.
    timber: add a dark beam along the top on both faces (cafe style)."""
    cuts = [(cx - w / 2, cx + w / 2) for cx, w, _, _ in openings]
    # full-height columns between openings
    for x0, x1 in _spans(L, cuts):
        b.box(x1 - x0, T, H, (x0 + x1) / 2, y, 0, mat, bevel=0.02)
    # lintels and sills around each opening
    for cx, w, zb, zt in openings:
        if zt < H - 1e-3:
            b.box(w, T, H - zt, cx, y, zt, mat, bevel=0.0)
        if zb > 1e-3:
            b.box(w, T, zb, cx, y, 0, mat, bevel=0.0)
    if base:
        base_cuts = [(cx - w / 2, cx + w / 2) for cx, w, zb, _ in openings if zb < BASE_H]
        for x0, x1 in _spans(L, base_cuts):
            stone_row(b, x1 - x0, BASE_H, T + 0.07, x0=x0, y=y, z=0, unit=0.42,
                      rng=random.Random(rng_seed + int(x0 * 100)))
    qd = T + 0.05
    if quoins[0]:
        quoin_stack(b, -L / 2, BASE_H if base else 0, H, qd, toward=1, y=y)
    if quoins[1]:
        quoin_stack(b, L / 2, BASE_H if base else 0, H, qd, toward=-1, y=y)
    if timber:
        for s in (-1, 1):
            b.box(L + 0.04, 0.07, 0.16, 0, y + s * (T / 2 + 0.03), H - 0.16, "wood_dark", bevel=0.015)
    if cap:
        b.box(L + 0.02, T + 0.06, 0.1, 0, y, H, cap, bevel=0.02)


def door_unit(b, cx, w=0.86, h=1.6, z=0.0, y=0.0, mat=DOOR_T, surround=TRIM_T, heavy=False, socket=True,
              open_deg=100, part_name="door_leaf"):
    """Door set in a wall of thickness T centred on y: deep static frame, threshold and a
    plank leaf with a 4-pane glowing light and gold knobs. The leaf is a hinge part
    'part_door_leaf' pivoting on its back (+Y) face at the left (-X) jamb; positive open_deg
    swings it toward +Y (into the wall's back side) and it clears the frame through the arc.
    Front is -Y."""
    fy = y - T / 2
    # frame lining through the wall
    for s in (-1, 1):
        b.box(0.08, T + 0.04, h + 0.04, cx + s * (w / 2 + 0.04), y, z, surround, bevel=0.012)
    b.box(w + 0.16, T + 0.04, 0.08, cx, y, z + h, surround, bevel=0.012)
    # outer surround (heavy = chunky cottage style with protruding lintel beam)
    sw = 0.14 if heavy else 0.09
    for s in (-1, 1):
        b.box(sw, 0.07, h + 0.06, cx + s * (w / 2 + sw / 2 + 0.03), fy - 0.03, z, surround, bevel=0.02)
    b.box(w + 2 * sw + (0.24 if heavy else 0.1), 0.12 if heavy else 0.08, 0.16 if heavy else 0.12,
          cx, fy - 0.05, z + h + 0.04, surround, bevel=0.025)
    # threshold
    b.box(w + 0.2, T + 0.12, 0.05, cx, y - 0.02, z, "stone_dark", bevel=0.012)
    # leaf: sits on the threshold, 1 cm clear of the jambs and head
    lw, lz0, lh0 = w - 0.02, z + 0.06, h - 0.08
    back = fy + 0.105
    with b.part(part_name, pivot=(cx - w / 2, back, lz0), motion="hinge", axis="z", open_deg=open_deg):
        pw = lw / 3
        b.box(lw - 0.03, 0.05, lh0 - 0.004, cx, fy + 0.07, lz0 + 0.002, mat, bevel=0)              # solid core behind the plank grooves
        for i in range(3):
            b.box(pw - 0.012, 0.07, lh0, cx - lw / 2 + pw * (i + 0.5), fy + 0.07, lz0, mat, bevel=0.012)
        b.box(lw - 0.04, 0.03, 0.07, cx, fy + 0.025, lz0 + 0.2, mat, bevel=0.01)              # rail
        gw, gh, gz = w * 0.46, h * 0.24, z + h * 0.6
        b.box(gw + 0.07, 0.04, gh + 0.07, cx, fy + 0.02, gz - 0.035, surround, bevel=0.01)
        b.box(gw, 0.03, gh, cx, fy + 0.015, gz, "glow_window", bevel=0)
        b.box(0.025, 0.04, gh, cx, fy + 0.0, gz, surround, bevel=0)
        b.box(gw, 0.04, 0.025, cx, fy + 0.0, gz + gh / 2 - 0.012, surround, bevel=0)
        for ky in (fy + 0.0, back + 0.035):                                                     # knobs both faces
            b.sphere(0.04, cx + w * 0.34, ky, z + h * 0.46, "gold", u=6, v=4)
    if socket:
        b.socket("door", (cx, y - T / 2 - 0.55, z), rotz=180)


def window_unit(b, cx, zb, w=0.62, h=0.72, y=0.0, frame=TRIM_T, box=False, flowers=("petal_white", "petal_red"),
                panes=4, sill=True, glow="glow_window"):
    """Deep-set window through a wall of thickness T: lining, chunky outer frame,
    a glowing pane in the middle of the wall (it reads from both sides),
    mullions, a sill and an optional flower box."""
    fy = y - T / 2
    for s in (-1, 1):
        b.box(0.07, T + 0.03, h, cx + s * (w / 2 + 0.035), y, zb, frame, bevel=0.01)
    b.box(w + 0.14, T + 0.03, 0.07, cx, y, zb + h, frame, bevel=0.01)
    b.box(w + 0.14, T + 0.03, 0.07, cx, y, zb - 0.07, frame, bevel=0.01)
    # outer chunky frame
    for s in (-1, 1):
        b.box(0.09, 0.06, h + 0.18, cx + s * (w / 2 + 0.08), fy - 0.02, zb - 0.09, frame, bevel=0.015)
    b.box(w + 0.32, 0.08, 0.11, cx, fy - 0.03, zb + h + 0.02, frame, bevel=0.018)
    b.box(w, 0.03, h, cx, y, zb, glow, bevel=0)
    for s in (-1, 1):  # mullions on both faces
        yy = y + s * 0.03
        if panes >= 2:
            b.box(0.04, 0.03, h, cx, yy, zb, frame, bevel=0)
        if panes >= 4:
            b.box(w, 0.03, 0.04, cx, yy, zb + h / 2 - 0.02, frame, bevel=0)
    if sill:
        b.box(w + 0.3, 0.16, 0.06, cx, fy - 0.06, zb - 0.13, "wood_b", bevel=0.018)
    if box:
        planter_box(b, w + 0.34, 0.24, 0.2, x=cx, y=fy - 0.15, z=zb - 0.36, flowers=flowers)
        for s in (-1, 1):  # brackets under the box
            b.box(0.05, 0.14, 0.12, cx + s * (w / 2), fy - 0.08, zb - 0.48, "wood_dark", bevel=0.01)


# ---------------------------------------------------------------------------
# Roof
# ---------------------------------------------------------------------------
def tiled_gable(b, span, length, rise, z=0.0, overhang=0.28, tile=0.38, tile_thick=0.09,
                mats=ROOF_T, gable=WALL_T, timber=True, ridge=ROOF_T[1], fascia="wood_dark", gable_t=T):
    """Chunky tiled gable roof with the ridge along Y (gable ends face -Y and +Y).
    span = wall-to-wall width in X, length = wall-to-wall depth in Y, z = eave/wall-top height.
    Tiles are individual beveled slabs, staggered per row and slightly overlapping like shingles."""
    half = span / 2
    tanA = rise / half
    A = math.atan(tanA)
    # lift the roof so its underside clears anything on the wall top that sticks out up to
    # `clear` metres beyond the wall face (quoins, timber beams); a wall plate fills the gap
    wall_top = z
    clear = 0.12
    lift = 0.06 / math.cos(A) + clear * tanA + 0.02
    z = z + lift
    run = half + overhang
    eave_z = z - overhang * tanA
    Ls = run / math.cos(A)
    Ly = length + 2 * overhang
    rows = max(2, round(Ls / tile))
    tl = Ls / rows
    cols = max(2, round(Ly / tile))
    tw = Ly / cols
    deg = math.degrees(A)
    for sx in (-1, 1):
        n = Vector((sx * math.sin(A), 0, math.cos(A)))
        # solid underlay so the roof is closed from below
        mid = Ls / 2
        p = Vector((sx * (run - mid * math.cos(A)), 0, eave_z + mid * math.sin(A))) - n * 0.02
        b.box(Ls, Ly, 0.06, p.x, p.y, p.z, mats[1], bevel=0.01, rot=(0, sx * deg, 0), center=True)
        for r in range(rows):
            s = (r + 0.5) * tl
            base = Vector((sx * (run - s * math.cos(A)), 0, eave_z + s * math.sin(A))) + n * (tile_thick / 2 + 0.01)
            off = (tw / 2) * (r % 2)
            for c in range(cols + (r % 2)):
                yc = -Ly / 2 + tw * (c + 0.5) - off
                y0, y1 = max(-Ly / 2, yc - tw / 2), min(Ly / 2, yc + tw / 2)
                if y1 - y0 < 0.06:
                    continue
                # tilt each tile a touch more than the slope so lower edges kick out (shingle look)
                b.box(tl + 0.05, y1 - y0 - 0.02, tile_thick, base.x, (y0 + y1) / 2, base.z,
                      pick(mats, r * 3 + c * 7 + (sx > 0)), bevel=0.022,
                      rot=(0, sx * (deg + 3.5), 0), center=True)
        # fascia under the eave
        b.box(0.08, Ly, 0.12, sx * (run - 0.03), 0, eave_z - 0.1, fascia, bevel=0.012)
    # ridge: a row of chunky capping tiles
    nr = max(2, round(Ly / 0.42))
    for i in range(nr):
        yc = -Ly / 2 + Ly / nr * (i + 0.5)
        b.box(0.3, Ly / nr - 0.02, 0.16, 0, yc, z + rise + 0.02, ridge, bevel=0.035)
    # bargeboards along the gable verges
    for sy in (-1, 1):
        for sx in (-1, 1):
            mid = Ls / 2
            p = Vector((sx * (run - mid * math.cos(A)), sy * (Ly / 2 - 0.04), eave_z + mid * math.sin(A)))
            b.box(Ls + 0.04, 0.08, 0.14, p.x, p.y, p.z - 0.05, fascia, bevel=0.015, rot=(0, sx * deg, 0), center=True)
    # wall plates on the eave walls close the slot under the lifted roof
    for sx in (-1, 1):
        b.box(gable_t, length, lift - 0.01, sx * (half - gable_t / 2), 0, wall_top, fascia, bevel=0.01)
    # gable infill triangles with timber truss (base at the wall top, apex under the ridge)
    if gable:
        z = wall_top
        rise = rise + lift - 0.06 / math.cos(A) - 0.03
        tri = [(-half, 0), (half, 0), (0, rise)]
        for sy in (-1, 1):
            gy = sy * (length / 2 - gable_t / 2)
            b.prism(tri, gable_t, x=0, y=gy, z=z, mat=gable)
            if timber:
                fy = sy * (length / 2 + 0.02)
                b.box(span + 0.1, 0.07, 0.14, 0, fy, z - 0.02, "wood_dark", bevel=0.015)        # tie beam
                b.box(0.12, 0.07, rise - 0.1, 0, fy, z + 0.1, "wood_dark", bevel=0.015)          # king post
                for sx in (-1, 1):                                                              # braces
                    L2 = math.hypot(half * 0.55, rise * 0.45)
                    a2 = math.degrees(math.atan2(rise * 0.45, half * 0.55))
                    b.box(L2, 0.07, 0.1, sx * half * 0.3, fy, z + 0.12 + rise * 0.2, "wood_dark",
                          bevel=0.012, rot=(0, -sx * a2, 0), center=True)


def roof_module(name, span, length, rise, seed, timber=True):
    b = seeded(name, seed)
    tiled_gable(b, span, length, rise, z=0.0, timber=timber)
    return b.finish(KIT, "roof", {"footprint_m": [span, length], "rise_m": rise})


# ---------------------------------------------------------------------------
# Small shared pieces
# ---------------------------------------------------------------------------
def entry_steps(b, x=0, y=0, w=1.3, steps=2, rise=0.14, tread=0.3, mats=STONE):
    """Stone steps leading up to a door at y (the top step's back edge), descending toward -Y."""
    for i in range(steps):
        h = rise * (steps - i)
        d = tread * (i + 1)
        b.box(w - i * 0.0, d, h, x, y - d / 2, 0, pick(mats, i), bevel=0.03)


def paving_apron(b, w, d, y0=0.0, unit=0.4, mats=("paving", "paving_b", "stone"), h=0.06, seed=1):
    """Ring of chunky paving stones around a w x d footprint centred at origin."""
    rng = random.Random(seed)
    for sy in (-1, 1):
        x = -w / 2 - unit
        i = 0
        while x < w / 2 + unit - 0.05:
            ww = min(unit * rng.uniform(0.8, 1.2), w / 2 + unit - x)
            b.box(ww - 0.03, unit - 0.03, h * rng.uniform(0.8, 1.1), x + ww / 2, sy * (d / 2 + unit / 2), 0,
                  pick(mats, i), bevel=0.02)
            x += ww
            i += 1
    for sx in (-1, 1):
        yy = -d / 2
        i = 0
        while yy < d / 2 - 0.05:
            dd = min(unit * rng.uniform(0.8, 1.2), d / 2 - yy)
            b.box(unit - 0.03, dd - 0.03, h * rng.uniform(0.8, 1.1), sx * (w / 2 + unit / 2), yy + dd / 2, 0,
                  pick(mats, i + 1), bevel=0.02)
            yy += dd
            i += 1


def stool(b, x, y, z=0.0, h=0.42, r=0.17, seat="wood_c"):
    b.cyl(r, 0.07, x, y, z + h - 0.07, seat, segs=8, bevel=0.015)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        b.box(0.05, 0.05, h - 0.07, x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.6, z, "wood_b", bevel=0.01,
              rot=(math.sin(a) * 6, -math.cos(a) * 6, 0))
    b.cyl(r * 0.62, 0.03, x, y, z + h * 0.35, "wood_b", segs=8)


def shrub(b, x=0, y=0, s=1.0, flowers=False):
    """Faceted bush made of a few overlapping leaf masses."""
    rng = b.rng
    for i, (dx, dy, r) in enumerate(((0, 0, 0.32), (0.22, 0.08, 0.24), (-0.2, 0.1, 0.25), (0.05, -0.18, 0.22))):
        r *= s
        b.blob(r, r, r * 0.95, x + dx * s, y + dy * s, r * 0.85, pick(("leaf_dark", "leaf", "leaf_b"), i), subdiv=1,
               jitter=r * 0.08)
    if flowers:
        for i in range(4):
            a = rng.uniform(0, math.tau)
            flower(b, x + math.cos(a) * 0.22 * s, y + math.sin(a) * 0.22 * s - 0.08, 0.5 * s,
                   pick(("petal_white", "petal_red"), i), size=0.06)


def attach(child, parent):
    """Make child a part of parent's exported hierarchy instead of its own asset."""
    ASSETS[:] = [a for a in ASSETS if a["obj"] is not child]
    child.parent = parent
    return child


# ---------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------
def build():
    # walls -------------------------------------------------------------------
    b = seeded("wall_1m", 11)
    masonry_wall(b, 1.0)
    b.finish(KIT, "wall", {"grid_m": [1, 0.22], "height_m": WALL_H})

    b = seeded("wall_2m", 12)
    masonry_wall(b, 2.0)
    b.finish(KIT, "wall", {"grid_m": [2, 0.22], "height_m": WALL_H})

    b = seeded("wall_corner", 13)
    # an L corner: two half-metre stubs meeting at the origin, one quoin stack that
    # alternates direction so no stones intersect
    with b.at((0.25 + T / 4, 0, 0)):
        masonry_wall(b, 0.5 - T / 2, mat=WALL_T)
    with b.at((0, 0.25 + T / 4, 0), rotz=90):
        masonry_wall(b, 0.5 - T / 2, mat=WALL_T)
    b.box(T, T, WALL_H, 0, 0, 0, WALL_T, bevel=0.02)
    stone_row(b, T + 0.07, BASE_H, T + 0.07, x0=-T / 2 - 0.035, unit=0.5)
    z, i = BASE_H, 0
    while z < WALL_H - 0.05:
        h = min(0.27, WALL_H - z)
        L = 0.36 if i % 2 == 0 else 0.26
        if i % 2 == 0:
            b.box(L, T + 0.02, h - 0.025, -T / 2 - 0.025 + L / 2, -0.015, z, pick(QUOIN, i), bevel=0.03)
        else:
            b.box(T + 0.02, L, h - 0.025, -0.015, -T / 2 - 0.025 + L / 2, z, pick(QUOIN, i), bevel=0.03)
        z += h
        i += 1
    b.finish(KIT, "wall", {"note": "outer corner at origin; walls run +X and +Y"})

    b = seeded("wall_door", 14)
    masonry_wall(b, 2.0, openings=[(0, 0.86 + 0.16, 0, 1.68)])
    door_unit(b, 0)
    b.finish(KIT, "wall", {"grid_m": [2, 0.22]})

    b = seeded("wall_window", 15)
    masonry_wall(b, 1.0, openings=[(0, 0.62 + 0.14, 0.9 - 0.07, 0.9 + 0.72 + 0.07)])
    window_unit(b, 0, 0.9)
    b.finish(KIT, "wall", {"grid_m": [1, 0.22]})

    b = seeded("wall_window_box", 16)
    masonry_wall(b, 1.0, openings=[(0, 0.62 + 0.14, 0.9 - 0.07, 0.9 + 0.72 + 0.07)])
    window_unit(b, 0, 0.9, box=True)
    b.finish(KIT, "wall", {"grid_m": [1, 0.22]})

    b = seeded("stone_base", 17)
    stone_row(b, 2.0, BASE_H, T + 0.07, x0=-1.0, unit=0.42)
    b.finish(KIT, "trim", {"grid_m": [2, 0.29]})

    # floors ------------------------------------------------------------------
    b = seeded("floor_wood_2x2", 18)
    b.box(2.0, 2.0, 0.04, 0, 0, 0, "wood_dark", bevel=0)
    planks(b, 2.0, 2.0, z=0.04, plank=0.2, thick=0.05)
    b.finish(KIT, "floor", {"grid_m": [2, 2], "top_z": 0.09})

    b = seeded("floor_tile_2x2", 19)
    b.box(2.0, 2.0, 0.04, 0, 0, 0, "stone_dark", bevel=0)
    for i in range(4):
        for j in range(4):
            b.box(0.48, 0.48, 0.05, -0.75 + i * 0.5, -0.75 + j * 0.5, 0.04,
                  pick(("paving", "paving_b", "stone"), i * 3 + j * 5 + (i * j) % 2), bevel=0.02)
    b.finish(KIT, "floor", {"grid_m": [2, 2], "top_z": 0.09})

    # roofs -------------------------------------------------------------------
    roof_module("roof_gable_3x3", 3.0, 3.0, 1.15, 21)
    roof_module("roof_gable_4x3", 4.0, 3.0, 1.35, 22)

    # inserts and trims -------------------------------------------------------
    b = seeded("awning_module", 23)
    awning(b, w=2.0, depth=0.7, drop=0.38, x=0, y=0, z=0.6, stripes=7, a=AWN_T[0], c=AWN_T[1])
    for s in (-1, 1):  # side brackets
        b.box(0.05, 0.62, 0.05, s * 0.98, -0.31, 0.18, "wood_dark", bevel=0.01, rot=(-28, 0, 0), center=True)
    b.socket("wall_mount", (0, 0, 0.6))
    b.finish(KIT, "trim", {"note": "origin at the wall face below the awning; socket_wall_mount is the top attach edge (0.6 m up)"})

    b = seeded("chimney", 24)
    b.box(0.5, 0.5, 1.4, 0, 0, 0, "chimney", bevel=0.03)
    for k in range(4):  # stone courses
        b.box(0.53, 0.53, 0.05, 0, 0, 0.25 + k * 0.3, "stone_grey", bevel=0.015)
    b.box(0.6, 0.6, 0.12, 0, 0, 1.4, "chimney_cap", bevel=0.025)
    b.box(0.3, 0.3, 0.05, 0, 0, 1.5, "black", bevel=0)
    b.socket("fx_smoke", (0, 0, 1.62))
    b.finish(KIT, "trim", {"note": "sink the bottom into the roof; top at 1.52 m"})

    b = seeded("door_insert", 25)
    door_unit(b, 0)
    b.finish(KIT, "insert", {"opening_m": [1.02, 1.68], "wall_t": T})

    b = seeded("window_insert", 26)
    window_unit(b, 0, 0.0)
    b.finish(KIT, "insert", {"opening_m": [0.76, 0.86], "wall_t": T, "note": "z=0 is glass bottom"})

    b = seeded("entry_step", 27)
    entry_steps(b, 0, 0, w=1.3, steps=2)
    b.finish(KIT, "trim", {"note": "back edge at y=0 meets the wall face"})

    # room shell ---------------------------------------------------------------
    room_shell(KIT, "room_shell_3x3", 3.0)


def room_shell(kit, name, S=3.0, seed=31):
    """Cutaway room as in the 11 vignettes: wood floor on a stone plinth, full back (+Y)
    wall with door and window, full left (-X) wall, low stone lip on the open sides,
    paving steps in front of the lip."""
    b = seeded(name, seed)
    H = 2.2
    fz = 0.18
    # plinth and floor
    b.box(S + 0.3, S + 0.3, fz - 0.06, 0, 0, 0, "stone_dark", bevel=0.03)
    b.box(S, S, 0.04, 0, 0, fz - 0.06, "wood_dark", bevel=0)
    planks(b, S - 0.02, S - 0.02, z=fz - 0.02, plank=0.22, thick=0.05, along="y")
    # back wall (runs along X at y = +S/2)
    with b.at((0, S / 2 + T / 2, fz), rotz=0):
        masonry_wall(b, S + T, H, openings=[(-0.75, 1.02, 0, 1.68), (0.65, 0.76, 0.93, 1.79)],
                     quoins=(False, True), base=True, cap="paving")
        door_unit(b, -0.75, socket=False)
        window_unit(b, 0.65, 1.0)
    b.socket("door", (-0.75, S / 2 - 0.4, fz), rotz=180)
    # left wall (runs along Y at x = -S/2)
    with b.at((-S / 2 - T / 2, 0, fz), rotz=-90):
        masonry_wall(b, S + T, H, quoins=(False, True), base=True, cap="paving")
    b.box(T + 0.06, T + 0.06, H - BASE_H, -S / 2 - T / 2, S / 2 + T / 2, fz + BASE_H, "stone", bevel=0.03)
    # low lip along the open front (-Y) and right (+X) edges
    for i, (w, x, y, rz) in enumerate(((S + 0.3, 0, -S / 2 - 0.08, 0), (S + 0.1, S / 2 + 0.08, 0.1, 90))):
        with b.at((x, y, 0), rotz=rz):
            stone_row(b, w, fz + 0.12, 0.2, x0=-w / 2, unit=0.4, rng=random.Random(seed + i))
    # entry pavers in front
    for i in range(3):
        b.box(0.55, 0.42, 0.08, -0.6 + i * 0.6, -S / 2 - 0.45, 0, pick(("paving", "paving_b", "stone"), i), bevel=0.025)
    b.socket("spawn", (0, 0, fz))
    b.socket("grid_origin", (-S / 2, -S / 2, fz))
    return b.finish(kit, "room", {"interior_m": [S, S], "floor_z": fz, "grid_cell_m": 0.5})
