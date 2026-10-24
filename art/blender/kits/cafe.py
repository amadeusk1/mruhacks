"""Cafe: the exterior prefab (concept 03), the interior shell (04) and interior props.

The roof (with its chimney) is a child mesh `cafe_exterior_roof`, so the game can hide it
for the cutaway view. The interior shell keeps its front and right walls in the child
`cafe_interior_shell_cutaway` for the same reason.
"""
from common import *
from kits.buildings import (T, BASE_H, WALL_T, ROOF_T, AWN_T, masonry_wall, door_unit, window_unit, tiled_gable, entry_steps,
                            stool, attach)

KIT = "cafe"
PREVIEW_WIDTH = 13.0
W, D = 4.4, 3.4      # outer footprint
SLAB = 0.1           # foundation slab; ground floor level
H = 2.4              # wall height above the slab
TOP = SLAB + H
RISE = 1.65
DOOR_X = -1.05
SERV_X, SERV_W, SERV_ZB, SERV_ZT = 0.85, 1.5, 0.95, 1.75


def mug(b, x, y, z, s=1.0, body="white", coffee=True):
    b.cyl(0.045 * s, 0.09 * s, x, y, z, body, segs=8, bevel=0.006)
    b.torus(0.026 * s, 0.009 * s, x + 0.05 * s, y, z + 0.045 * s, body, segs=8, ring=4, rot=(90, 0, 0))
    if coffee:
        b.cyl(0.037 * s, 0.005, x, y, z + 0.082 * s, "wood_deep", segs=8)


def pastries(b, x, y, z, w, d, rows=2):
    rng = b.rng
    for i in range(rows):
        for j in range(3):
            px = x - w / 2 + w * (j + 0.5) / 3
            py = y - d / 2 + d * (i + 0.5) / rows
            m = pick(("tan", "mustard", "brown", "pink"), i * 3 + j)
            b.blob(0.05, 0.045, 0.028, px, py, z + 0.025, m, subdiv=1, jitter=0.004)
            if m == "pink":
                b.blob(0.03, 0.03, 0.012, px, py, z + 0.05, "white", subdiv=1)


def pastry_case(b, x=0, y=0, z=0, w=0.7, d=0.36, h=0.32):
    """Glass display case with a wooden base and two trays of pastries."""
    b.box(w, d, 0.06, x, y, z, "wood_b", bevel=0.012)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.03, 0.03, h, x + sx * (w / 2 - 0.015), y + sy * (d / 2 - 0.015), z + 0.06, "wood_dark", bevel=0.004)
    b.box(w, d, 0.03, x, y, z + 0.06 + h, "wood_dark", bevel=0.008)
    b.box(w - 0.04, d - 0.04, h - 0.01, x, y, z + 0.065, "glass", bevel=0.005)
    b.box(w - 0.06, d - 0.06, 0.012, x, y, z + 0.06 + h * 0.5, "glass", bevel=0)
    pastries(b, x, y, z + 0.06, w - 0.1, d - 0.12)
    pastries(b, x, y, z + 0.07 + h * 0.5, w - 0.1, d - 0.12, rows=1)


def register_till(b, x, y, z):
    b.box(0.26, 0.24, 0.1, x, y, z, "charcoal", bevel=0.015)
    b.box(0.22, 0.04, 0.12, x, y + 0.05, z + 0.1, "charcoal", bevel=0.01, rot=(-20, 0, 0))
    b.box(0.17, 0.01, 0.08, x, y + 0.025, z + 0.13, "glow_teal", bevel=0, rot=(-20, 0, 0))
    b.box(0.2, 0.1, 0.02, x, y - 0.06, z + 0.1, "iron_light", bevel=0.004)


def potted_plant(b, x, y, z, s=1.0, pot="terracotta", flowers=True):
    b.cyl(0.07 * s, 0.1 * s, x, y, z, pot, segs=8, r2=0.085 * s, bevel=0.008)
    b.cyl(0.075 * s, 0.01, x, y, z + 0.095 * s, "soil", segs=8)
    for i in range(4):
        a = i * math.pi / 2 + 0.4
        b.blob(0.06 * s, 0.04 * s, 0.035 * s, x + math.cos(a) * 0.05 * s, y + math.sin(a) * 0.05 * s,
               z + 0.13 * s, pick(("leaf", "leaf_dark"), i), subdiv=1, rot=(0, 0, math.degrees(a)))
    if flowers:
        flower(b, x, y, z + 0.17 * s, "petal_white", size=0.035 * s)


def counter_body(b, length, x, y, z=0.0, h=0.86, depth=0.55, rotz=0):
    """Cream panelled counter run with wood top, plinth and pilasters, front at -Y."""
    with b.at((x, y, z), rotz=rotz):
        b.box(length, depth, 0.08, 0, 0, 0, "wood_dark", bevel=0.01)
        b.box(length - 0.02, depth - 0.06, h - 0.14, 0, 0.02, 0.08, tint("counter_panel", "plaster"), bevel=0.015)
        n = max(2, round(length / 0.5))
        for i in range(n + 1):
            b.box(0.06, 0.04, h - 0.14, -length / 2 + 0.01 + (length - 0.02) * i / n, -depth / 2 + 0.03, 0.08,
                  "wood_b", bevel=0.008)
        b.box(length - 0.04, 0.04, 0.06, 0, -depth / 2 + 0.03, h - 0.2, "wood_b", bevel=0.008)
        b.box(length + 0.06, depth + 0.06, 0.06, 0, 0, h - 0.06, "wood_c", bevel=0.015)


# ---------------------------------------------------------------------------
def build_exterior():
    b = Builder("cafe_exterior", seed=301)
    # foundation slab + entry
    b.box(W + 0.3, D + 0.3, SLAB, 0, 0, 0, "stone_dark", bevel=0.03)
    entry_steps(b, DOOR_X, -D / 2 - 0.15, w=1.2, steps=1, rise=SLAB, tread=0.35)
    # interior floor + warm back light (seen through the service window)
    b.box(W - 2 * T, D - 2 * T, 0.02, 0, 0, SLAB, "wood_b", bevel=0)

    with b.at((0, -D / 2 + T / 2, SLAB)):                                     # front
        masonry_wall(b, W, H, openings=[(DOOR_X, 1.02, 0, 1.68), (SERV_X, SERV_W, SERV_ZB, SERV_ZT)],
                     quoins=(True, True), timber=True)
        door_unit(b, DOOR_X, socket=False)
    with b.at((0, D / 2 - T / 2, SLAB), rotz=180):                            # back
        masonry_wall(b, W, H, openings=[(0.4, 1.02, 0, 1.68)], quoins=(True, True), timber=True)
        door_unit(b, 0.4, socket=False)
    with b.at((-W / 2 + T / 2, 0, SLAB), rotz=-90):                           # left
        masonry_wall(b, D - 2 * T, H, openings=[(0, 0.76, 0.86, 1.72)], timber=True)
        window_unit(b, 0, 0.93, box=True)
    with b.at((W / 2 - T / 2, 0, SLAB), rotz=90):                             # right
        masonry_wall(b, D - 2 * T, H, openings=[(-0.6, 0.76, 0.86, 1.72), (0.6, 0.76, 0.86, 1.72)], timber=True)
        window_unit(b, -0.6, 0.93)
        window_unit(b, 0.6, 0.93)
        planter_box(b, 1.9, 0.24, 0.2, x=0, y=-T / 2 - 0.15, z=0.57)
        for s in (-1, 0, 1):
            b.box(0.05, 0.14, 0.12, s * 0.8, -T / 2 - 0.08, 0.45, "wood_dark", bevel=0.01)

    # service window: deep frame, inner shelf with mugs and plants, sill counter, awning
    fy = -D / 2
    with b.at((SERV_X, 0, SLAB)):
        zb, zt = SERV_ZB, SERV_ZT
        for s in (-1, 1):
            b.box(0.1, T + 0.04, zt - zb + 0.1, s * (SERV_W / 2 + 0.03), fy + T / 2, zb - 0.05, "wood", bevel=0.015)
        b.box(SERV_W + 0.2, T + 0.08, 0.1, 0, fy + T / 2, zt, "wood", bevel=0.015)
        b.box(SERV_W + 0.06, 0.3, 0.06, 0, fy - 0.03, zb - 0.06, "wood_c", bevel=0.015)                 # outside sill
        b.box(SERV_W, 0.03, zt - zb, 0, fy + T / 2, zb, "glass", bevel=0)                                # glazing
        for s in (-1, 1):                                                                              # sash bars
            b.box(0.05, 0.05, zt - zb, s * SERV_W / 4, fy + T / 2 - 0.03, zb, "wood", bevel=0.006)
        b.box(SERV_W, 0.05, 0.05, 0, fy + T / 2 - 0.03, zb + (zt - zb) * 0.55, "wood", bevel=0.006)
        b.box(0.07, 0.06, zt - zb, 0, fy - 0.0, zb, "wood", bevel=0.01)                                # centre post
        # warm lit back panel inside, so the shop window reads as a glowing interior
        b.box(SERV_W + 0.3, 0.04, zt - zb + 0.35, 0, fy + T + 0.42, zb - 0.2, "glow_window", bevel=0)
        # inside: shelf with mugs and plants, under-glow
        b.box(SERV_W, 0.22, 0.04, 0, fy + T + 0.2, zb + 0.38, "wood_b", bevel=0.008)
        for i, xx in enumerate((-0.55, -0.3, 0.25, 0.5)):
            mug(b, xx, fy + T + 0.2, zb + 0.42, body=pick(("white", "cream", "teal_light"), i), coffee=False)
        potted_plant(b, -0.05, fy + T + 0.2, zb + 0.42, 0.8)
        potted_plant(b, 0.0, fy + 0.03, zb - 0.0, 0.9)                                                  # on the sill
        mug(b, -0.45, fy + 0.0, zb, 0.9)
        mug(b, 0.42, fy + 0.02, zb, 0.9)
        # outside bar counter below the window on brackets
        b.box(1.75, 0.4, 0.06, 0, fy - 0.2, 0.74, "wood_c", bevel=0.018)
        b.box(1.65, 0.05, 0.14, 0, fy - 0.37, 0.62, "wood_b", bevel=0.012)
        for s in (-1, 1):
            b.box(0.08, 0.34, 0.08, s * 0.7, fy - 0.17, 0.52, "wood_dark", bevel=0.012, rot=(32, 0, 0), center=True)
        awning(b, w=SERV_W + 0.5, depth=0.75, drop=0.38, x=0, y=fy - 0.01, z=H - 0.02, stripes=6, a=AWN_T[0], c=AWN_T[1])
    stools = [(SERV_X - 0.45, fy - 0.72), (SERV_X + 0.45, fy - 0.72)]
    for i, (sx, sy) in enumerate(stools):
        stool(b, sx, sy, 0, h=0.46)
        b.socket(f"seat_{i}", (sx, sy, 0.46), rotz=0)

    # lanterns, eave brackets, ground planters
    wall_lantern(b, DOOR_X - 0.72, fy, SLAB + 1.95)
    wall_lantern(b, DOOR_X + 0.72, fy, SLAB + 1.95)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.08, 0.08, 0.5, sx * (W / 2 + 0.08), sy * (D / 2 - 0.1), TOP - 0.42, "wood_dark", bevel=0.012,
                  rot=(0, sx * 35, 0), center=True)
    planter_box(b, 0.62, 0.34, 0.3, x=-W / 2 + 0.38, y=fy - 0.3, z=0)
    planter_box(b, 0.62, 0.34, 0.3, x=W / 2 + 0.05, y=fy - 0.3, z=0)

    b.socket("door", (DOOR_X, fy - 0.6, 0), rotz=180)
    b.socket("door_back", (0.4 * -1, D / 2 + 0.6, 0), rotz=0)
    b.socket("counter_service", (SERV_X, fy - 0.45, 0), rotz=180)
    b.socket("chalkboard", (DOOR_X + 0.75, fy - 0.6, 0), rotz=200)
    b.socket("interior_spawn", (DOOR_X, -D / 2 + T + 0.5, SLAB))
    house = b.finish(KIT, "building", {"footprint_m": [W, D], "floor_z": SLAB, "roof_child": "cafe_exterior_roof"})

    r = Builder("cafe_exterior_roof", seed=302)
    tiled_gable(r, W, D, RISE, z=TOP, overhang=0.32, tile=0.36, tile_thick=0.085)
    cx, cy = 1.15, 0.75
    zr = TOP + RISE * (1 - cx / (W / 2)) - 0.1
    r.box(0.5, 0.5, TOP + RISE + 0.45 - zr, cx, cy, zr, "chimney", bevel=0.03)
    for k in range(3):
        r.box(0.53, 0.53, 0.05, cx, cy, zr + 0.25 + k * 0.3, "stone_grey", bevel=0.015)
    r.box(0.6, 0.6, 0.12, cx, cy, TOP + RISE + 0.45, "chimney_cap", bevel=0.025)
    r.box(0.3, 0.3, 0.05, cx, cy, TOP + RISE + 0.55, "black", bevel=0)
    roof = r.finish(KIT, "roof")
    attach(roof, house)
    return house


def build_interior_shell():
    b = Builder("cafe_interior_shell", seed=311)
    b.box(W + 0.3, D + 0.3, SLAB, 0, 0, 0, "stone_dark", bevel=0.03)
    # checker tile floor
    n, m = 8, 6
    fw, fd = W - 2 * T, D - 2 * T
    for i in range(n):
        for j in range(m):
            b.box(fw / n - 0.02, fd / m - 0.02, 0.03, -fw / 2 + fw * (i + 0.5) / n, -fd / 2 + fd * (j + 0.5) / m, SLAB,
                  pick(("paving", "paving_b", "stone"), i * 3 + j * 5 + (i + j) % 2), bevel=0.012)
    # walls are built with their detailed face (-Y local) pointing into the room
    with b.at((0, D / 2 - T / 2, SLAB)):                                      # back
        masonry_wall(b, W, H, openings=[(-0.3, 1.02, 0, 1.68)], quoins=(True, True), cap=ROOF_T[0])
        door_unit(b, -0.3, socket=False)
    with b.at((-W / 2 + T / 2, 0, SLAB), rotz=90):                            # left, two windows
        masonry_wall(b, D - 2 * T, H, openings=[(-0.65, 0.76, 0.86, 1.72), (0.65, 0.76, 0.86, 1.72)], cap=ROOF_T[0])
        window_unit(b, -0.65, 0.93)
        window_unit(b, 0.65, 0.93)
    # corner blocks
    for sx, sy in ((-1, 1), (1, 1), (-1, -1)):
        b.box(T + 0.1, T + 0.1, 0.22, sx * (W / 2 - T / 2), sy * (D / 2 - T / 2), TOP, "stone_grey", bevel=0.03)
    b.socket("door_back", (-0.3, D / 2 - T - 0.5, SLAB))
    b.socket("door_front", (DOOR_X, -D / 2 + T + 0.5, SLAB))
    b.socket("counter", (0.75, 0.2, SLAB))
    b.socket("coffee_station", (1.2, D / 2 - T - 0.25, SLAB), rotz=180)
    b.socket("wall_shelf", (0.9, D / 2 - T, SLAB + 1.35), rotz=180)
    b.socket("menu_board", (-1.4, D / 2 - T, SLAB + 1.2), rotz=180)
    b.socket("table_0", (-1.3, 0.55, SLAB))
    b.socket("table_1", (-1.2, -0.6, SLAB))
    shell = b.finish(KIT, "room", {"footprint_m": [W, D], "floor_z": SLAB, "cutaway_child": "cafe_interior_shell_cutaway"})

    c = Builder("cafe_interior_shell_cutaway", seed=312)
    with c.at((0, -D / 2 + T / 2, SLAB)):
        masonry_wall(c, W, H, openings=[(DOOR_X, 1.02, 0, 1.68), (SERV_X, SERV_W, SERV_ZB, SERV_ZT)],
                     quoins=(True, True), cap=ROOF_T[0])
        door_unit(c, DOOR_X, socket=False)
        c.box(SERV_W + 0.06, T + 0.3, 0.06, SERV_X, -0.08, SERV_ZB - 0.06, "wood_c", bevel=0.015)
        c.box(SERV_W, 0.03, SERV_ZT - SERV_ZB, SERV_X, 0, SERV_ZB, "glass", bevel=0)
        c.box(0.07, T + 0.02, SERV_ZT - SERV_ZB, SERV_X, 0, SERV_ZB, "wood", bevel=0.008)          # centre post
        for s in (-1, 1):                                                                           # sash bars
            c.box(0.05, 0.05, SERV_ZT - SERV_ZB, SERV_X + s * SERV_W / 4, -0.03, SERV_ZB, "wood", bevel=0.006)
        c.box(SERV_W, 0.05, 0.05, SERV_X, -0.03, SERV_ZB + (SERV_ZT - SERV_ZB) * 0.55, "wood", bevel=0.006)
        c.box(SERV_W + 0.2, T + 0.06, 0.08, SERV_X, 0, SERV_ZT, "wood", bevel=0.012)
        awning(c, w=SERV_W + 0.5, depth=0.75, drop=0.38, x=SERV_X, y=-T / 2 - 0.01, z=H - 0.02, stripes=6, a=AWN_T[0], c=AWN_T[1])
    with c.at((W / 2 - T / 2, 0, SLAB), rotz=90):
        masonry_wall(c, D - 2 * T, H, openings=[(-0.6, 0.76, 0.86, 1.72), (0.6, 0.76, 0.86, 1.72)], cap=ROOF_T[0])
        window_unit(c, -0.6, 0.93, box=True)
        window_unit(c, 0.6, 0.93, box=True)
    c.box(T + 0.1, T + 0.1, 0.22, W / 2 - T / 2, -D / 2 + T / 2, TOP, "stone_grey", bevel=0.03)
    attach(c.finish(KIT, "room"), shell)
    return shell


def build_props():
    # L counter: front run along X plus a return toward the back on the left end
    b = Builder("cafe_counter", seed=321)
    counter_body(b, 1.9, 0, 0)
    counter_body(b, 1.0, -0.95 + 0.275, 0.5 + 0.275, rotz=-90)
    pastry_case(b, 0.35, 0.0, 0.86)
    register_till(b, -0.55, 0.05, 0.86)
    mug(b, -0.85, 0.75, 0.86)
    potted_plant(b, -0.72, 1.05, 0.86, 0.9)
    b.socket("service", (0.2, 0.6, 0), rotz=180)
    b.socket("customer", (0.2, -0.65, 0))
    b.finish(KIT, "furniture", {"note": "L-counter; barista works on the +Y side"})

    b = Builder("coffee_station", seed=322)
    # base cabinet with open shelves of cups and plates
    b.box(1.1, 0.48, 0.08, 0, 0, 0, "wood_dark", bevel=0.01)
    for sx in (-1, 0, 1):
        b.box(0.05, 0.46, 0.74, sx * 0.525, 0, 0.08, "wood_b", bevel=0.01)
    b.box(1.1, 0.04, 0.74, 0, 0.22, 0.08, "wood_b", bevel=0.006)
    b.box(1.04, 0.44, 0.04, 0, 0, 0.42, "wood", bevel=0.008)
    b.box(1.16, 0.52, 0.06, 0, 0, 0.82, "wood_c", bevel=0.015)
    for i in range(3):
        b.cyl(0.1, 0.012, -0.32, -0.02, 0.12 + i * 0.016, "white", segs=10, bevel=0.003)
        mug(b, 0.12 + i * 0.12, -0.02, 0.46, coffee=False)
    for i in range(3):
        mug(b, 0.12 + i * 0.12, -0.02, 0.12, body="cream", coffee=False)
    # espresso machine
    with b.at((-0.15, 0.02, 0.88)):
        b.box(0.52, 0.38, 0.42, 0, 0, 0, "charcoal", bevel=0.03)
        b.box(0.48, 0.02, 0.1, 0, -0.19, 0.28, "steel", bevel=0.008)
        for i, xx in enumerate((-0.12, 0.12)):
            b.cyl(0.045, 0.06, xx, -0.22, 0.17, "steel", segs=8)
            b.box(0.03, 0.12, 0.025, xx, -0.3, 0.2, "black", bevel=0.005)
            b.sphere(0.018, -0.2 + i * 0.4, -0.2, 0.34, "glow", u=6, v=4)
        b.box(0.46, 0.16, 0.04, 0, -0.26, 0.0, "steel", bevel=0.008)
        for i in range(4):
            mug(b, -0.16 + i * 0.105, 0.0, 0.42, s=0.9, coffee=False)
    # grinder
    with b.at((0.35, 0.05, 0.88)):
        b.box(0.18, 0.2, 0.26, 0, 0, 0, "brown", bevel=0.02)
        b.box(0.1, 0.06, 0.06, 0, -0.12, 0.05, "black", bevel=0.008)
        b.cyl(0.07, 0.08, 0, 0, 0.26, "iron", segs=8)
        b.cyl(0.07, 0.18, 0, 0, 0.34, "glass", segs=8, r2=0.11)
        b.cyl(0.065, 0.1, 0, 0, 0.34, "wood_deep", segs=8, r2=0.09)
        b.cyl(0.115, 0.03, 0, 0, 0.52, "iron", segs=8)
    b.socket("use", (0, -0.6, 0), rotz=180)
    b.finish(KIT, "furniture")

    b = Builder("wall_shelf", seed=323)
    b.xf = Matrix.Translation((0, 0, 0.36))  # origin at the bracket bottoms on the wall face
    b.box(1.0, 0.24, 0.05, 0, -0.12, 0.0, "wood_c", bevel=0.012)
    for s in (-1, 1):
        b.box(0.05, 0.2, 0.14, s * 0.38, -0.1, -0.14, "wood_dark", bevel=0.01)
    for i, (xx, lid) in enumerate(((-0.4, "coral"), (-0.26, "mustard"), (-0.12, "teal"))):
        h = 0.16 - i * 0.02
        b.cyl(0.055, h, xx, -0.12, 0.05, "glass", segs=8)
        b.cyl(0.048, h * 0.6, xx, -0.12, 0.052, pick(("wood_deep", "tan", "brown"), i), segs=8)
        b.cyl(0.06, 0.035, xx, -0.12, 0.05 + h, lid, segs=8, bevel=0.006)
    potted_plant(b, 0.12, -0.12, 0.05, 1.1, flowers=False)
    for i in range(5):  # trailing vine
        b.blob(0.045, 0.035, 0.03, 0.22 + i * 0.025, -0.2, 0.06 - i * 0.07, pick(("leaf", "leaf_dark"), i), subdiv=1)
    mug(b, 0.36, -0.12, 0.05)
    b.finish(KIT, "wall_prop", {"note": "origin on the wall face at the bracket bottoms; shelf top at 0.41 m"})

    b = Builder("mug", seed=324)
    mug(b, 0, 0, 0, s=1.4)
    b.socket("hold", (0, 0, 0.06))
    b.finish(KIT, "prop", {"slot": "held"})

    b = Builder("mug_set", seed=325)
    b.box(0.42, 0.24, 0.02, 0, 0, 0, "wood_c", bevel=0.006)
    for i, c in enumerate(("white", "cream", "teal_light")):
        mug(b, -0.13 + i * 0.12, -0.03 + (i % 2) * 0.05, 0.02, body=c)
    b.cyl(0.045, 0.1, 0.16, 0.06, 0.02, "glass", segs=8)
    b.cyl(0.04, 0.06, 0.16, 0.06, 0.022, "wood_deep", segs=8)
    b.cyl(0.05, 0.03, 0.16, 0.06, 0.12, "coral", segs=8, bevel=0.006)
    b.finish(KIT, "prop")

    b = Builder("pastry_case", seed=326)
    pastry_case(b, 0, 0, 0)
    b.finish(KIT, "prop")

    b = Builder("menu_board", seed=327)
    b.box(0.9, 0.05, 0.62, 0, -0.03, 0, "wood_b", bevel=0.015)
    b.box(0.8, 0.02, 0.52, 0, -0.065, 0.05, "insert_chalk", bevel=0)
    for i in range(4):  # chalk lines
        b.box(0.3 + (i % 2) * 0.2, 0.005, 0.02, -0.1 + (i % 2) * 0.05, -0.078, 0.14 + i * 0.1, "white", bevel=0)
    b.box(0.08, 0.005, 0.08, -0.25, -0.078, 0.42, "white", bevel=0)
    b.box(1.0, 0.06, 0.05, 0, -0.03, 0.62, "wood_dark", bevel=0.012)
    b.finish(KIT, "wall_prop", {"note": "origin at the board bottom on the wall face"})


def build():
    build_exterior()
    build_interior_shell()
    build_props()
