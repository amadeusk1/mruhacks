"""Personal cottage (concept 07): exterior prefab with a hideable roof child, a standalone roof,
an interior shell with a hideable cutaway child, interior furniture and shrubs."""
from common import *
from kits.buildings import (T, ROOF_T, masonry_wall, door_unit, window_unit, tiled_gable, entry_steps,
                            paving_apron, shrub, attach)

KIT = "cottage"
PREVIEW_WIDTH = 12.0
W, D = 3.4, 3.0
SLAB = 0.24          # raised floor; two entry steps
H = 1.95
TOP = SLAB + H
RISE = 1.45
DOOR_X, WIN_X = -0.55, 0.85
CH_X, CH_Y = 0.95, 0.75


def roof(name, seed):
    r = Builder(name, seed=seed)
    tiled_gable(r, W, D, RISE, z=TOP, overhang=0.36, tile=0.5, tile_thick=0.13, timber=False,
                )
    zr = TOP + RISE * (1 - CH_X / (W / 2)) - 0.15
    top = TOP + RISE + 0.35
    r.box(0.56, 0.56, top - zr, CH_X, CH_Y, zr, "chimney", bevel=0.035)
    for k in range(int((top - zr) / 0.28)):
        r.box(0.59, 0.59, 0.05, CH_X, CH_Y, zr + 0.2 + k * 0.28, "stone", bevel=0.015)
    r.box(0.68, 0.68, 0.14, CH_X, CH_Y, top, "chimney_cap", bevel=0.03)
    r.box(0.36, 0.36, 0.05, CH_X, CH_Y, top + 0.11, "black", bevel=0)
    r.socket("fx_smoke", (CH_X, CH_Y, top + 0.24))
    return r


def walls(b, front=True, back=True, left=True, right=True, inward=False):
    """The four masonry walls on the slab. inward=True turns the detailed faces of the
    back and left walls into the room (interior shell)."""
    if front:
        with b.at((0, -D / 2 + T / 2, SLAB)):
            masonry_wall(b, W, H, openings=[(DOOR_X, 1.02, 0, 1.68), (WIN_X, 0.76, 0.83, 1.69)],
                         quoins=(True, True), cap="paving" if inward else None)
            door_unit(b, DOOR_X, heavy=True, socket=False)
            window_unit(b, WIN_X, 0.9, box=True, flowers=("petal_red", "petal_white"))
    if back:
        with b.at((0, D / 2 - T / 2, SLAB), rotz=0 if inward else 180):
            masonry_wall(b, W, H, openings=[] if inward else [(-0.5, 0.76, 0.83, 1.69)], quoins=(True, True),
                         cap="paving" if inward else None)
            if not inward:
                window_unit(b, -0.5, 0.9)
    if left:
        with b.at((-W / 2 + T / 2, 0, SLAB), rotz=90 if inward else -90):
            masonry_wall(b, D - 2 * T, H, openings=[(0, 0.76, 0.83, 1.69)], cap="paving" if inward else None)
            window_unit(b, 0, 0.9)
    if right:
        with b.at((W / 2 - T / 2, 0, SLAB), rotz=90):
            masonry_wall(b, D - 2 * T, H, openings=[(0, 0.76, 0.83, 1.69)], cap="paving" if inward else None)
            window_unit(b, 0, 0.9)


def flower_pot(b, x, y, z=0.0, s=1.0, petal="petal_white"):
    b.cyl(0.15 * s, 0.24 * s, x, y, z, "terracotta", segs=8, r2=0.19 * s, bevel=0.015)
    b.cyl(0.2 * s, 0.05 * s, x, y, z + 0.22 * s, "terracotta", segs=8, bevel=0.012)
    b.cyl(0.17 * s, 0.01, x, y, z + 0.26 * s, "soil", segs=8)
    foliage(b, 0.26 * s, 0.26 * s, z + 0.26 * s, x, y, density=1.6, flowers=(petal,), fsize=0.06 * s)


def build_exterior():
    b = Builder("cottage_exterior", seed=401)
    paving_apron(b, W + 0.2, D + 0.2, unit=0.42, seed=7)
    # raised stone plinth
    b.box(W + 0.16, D + 0.16, SLAB, 0, 0, 0, "stone_dark", bevel=0.035)
    b.box(W - 2 * T, D - 2 * T, 0.02, 0, 0, SLAB, "wood_b", bevel=0)
    entry_steps(b, DOOR_X, -D / 2 - 0.08, w=1.25, steps=2, rise=SLAB / 2, tread=0.32)
    walls(b)
    fy = -D / 2
    flower_pot(b, DOOR_X - 0.95, fy - 0.45, 0, 1.0)
    b.socket("door", (DOOR_X, fy - 1.0, 0), rotz=180)
    b.socket("spawn_inside", (DOOR_X, fy + T + 0.5, SLAB))
    b.socket("mailbox", (DOOR_X - 1.1, fy - 0.9, 0))
    house = b.finish(KIT, "building", {"footprint_m": [W, D], "floor_z": SLAB, "roof_child": "cottage_exterior_roof"})
    attach(roof("cottage_exterior_roof", 402).finish(KIT, "roof"), house)
    return house


def build_interior_shell():
    b = Builder("cottage_interior_shell", seed=411)
    b.box(W + 0.16, D + 0.16, SLAB - 0.06, 0, 0, 0, "stone_dark", bevel=0.035)
    b.box(W - 0.1, D - 0.1, 0.04, 0, 0, SLAB - 0.06, "wood_dark", bevel=0)
    planks(b, W - 2 * T + 0.02, D - 2 * T + 0.02, z=SLAB - 0.04, plank=0.2, thick=0.05, along="y")
    walls(b, front=False, right=False, inward=True)
    # chimney breast in the back-right corner
    b.box(0.6, 0.4, H, CH_X, D / 2 - T - 0.2, SLAB, "chimney", bevel=0.03)
    for k in range(6):
        b.box(0.615, 0.415, 0.04, CH_X, D / 2 - T - 0.2, SLAB + 0.25 + k * 0.28, "stone", bevel=0.008)
    for sx, sy in ((-1, 1), (1, 1), (-1, -1)):
        b.box(T + 0.1, T + 0.1, 0.18, sx * (W / 2 - T / 2), sy * (D / 2 - T / 2), TOP, ROOF_T[0], bevel=0.03)
    b.socket("door", (DOOR_X, -D / 2 + T + 0.45, SLAB))
    b.socket("spawn_inside", (DOOR_X, -D / 2 + T + 0.7, SLAB))
    b.socket("bed", (-0.85, 0.4, SLAB), rotz=0)
    b.socket("desk", (0.95, -0.15, SLAB), rotz=90)
    b.socket("rug", (0.05, -0.1, SLAB))
    b.socket("wall_shelf", (0.1, D / 2 - T, SLAB + 1.25), rotz=0)
    b.socket("grid_origin", (-W / 2 + T, -D / 2 + T, SLAB))
    shell = b.finish(KIT, "room", {"footprint_m": [W, D], "floor_z": SLAB, "grid_cell_m": 0.5,
                                   "cutaway_child": "cottage_interior_shell_cutaway"})
    c = Builder("cottage_interior_shell_cutaway", seed=412)
    walls(c, back=False, left=False, inward=True)
    c.box(T + 0.1, T + 0.1, 0.18, W / 2 - T / 2, -D / 2 + T / 2, TOP, ROOF_T[0], bevel=0.03)
    attach(c.finish(KIT, "room"), shell)
    return shell


def build_props():
    b = Builder("bed_single", seed=421)
    L, Wd = 1.55, 0.9
    for sx in (-1, 1):                       # legs
        for sy in (-1, 1):
            b.box(0.09, 0.09, 0.2, sx * (Wd / 2 - 0.05), sy * (L / 2 - 0.05), 0, "wood_b", bevel=0.015)
    b.box(Wd, L, 0.1, 0, 0, 0.16, "wood", bevel=0.02)                                   # frame
    b.box(Wd + 0.06, 0.08, 0.72, 0, L / 2 + 0.02, 0, "wood_b", bevel=0.025)              # headboard
    b.box(Wd + 0.1, 0.12, 0.08, 0, L / 2 + 0.02, 0.72, "wood_c", bevel=0.02)
    b.box(Wd + 0.06, 0.08, 0.44, 0, -L / 2 - 0.02, 0, "wood_b", bevel=0.025)             # footboard
    b.box(Wd + 0.1, 0.12, 0.07, 0, -L / 2 - 0.02, 0.44, "wood_c", bevel=0.02)
    b.box(Wd - 0.06, L - 0.06, 0.14, 0, 0, 0.26, "cream", bevel=0.04)                    # mattress
    BED = tint("bedding", "sage")
    b.box(Wd + 0.02, L * 0.62, 0.06, 0, -L * 0.17, 0.36, BED, bevel=0.03)             # blanket
    b.box(Wd + 0.04, 0.12, 0.08, 0, L * 0.15, 0.37, BED, bevel=0.035)                 # folded edge
    for sx in (-1, 1):
        b.box(0.04, L * 0.62, 0.16, sx * (Wd / 2 + 0.01), -L * 0.17, 0.26, BED, bevel=0.015)
    b.box(0.56, 0.3, 0.12, 0, L / 2 - 0.24, 0.4, tint("pillow", "white"), bevel=0.05)                     # pillow
    b.socket("lie", (0, 0.1, 0.42))
    b.finish(KIT, "furniture", {"footprint_m": [Wd, L]})

    b = Builder("desk", seed=422)
    b.box(1.0, 0.52, 0.06, 0, 0, 0.62, "wood_c", bevel=0.018)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.07, 0.07, 0.62, sx * 0.44, sy * 0.2, 0, "wood_b", bevel=0.012)
    b.box(0.88, 0.04, 0.12, 0, 0.21, 0.48, "wood_b", bevel=0.01)
    b.box(0.4, 0.44, 0.12, 0.25, 0, 0.5, "wood", bevel=0.012)                              # drawer
    b.sphere(0.022, 0.25, -0.23, 0.56, "gold", u=6, v=4)
    # small flower pots on top, like the concept
    for i, (xx, p) in enumerate(((-0.3, "petal_white"), (-0.12, "petal_red"))):
        b.cyl(0.06, 0.08, xx, 0.1, 0.68, "terracotta", segs=8, r2=0.07, bevel=0.006)
        b.blob(0.06, 0.06, 0.05, xx, 0.1, 0.8, "leaf", subdiv=1)
        flower(b, xx, 0.1, 0.84, p, size=0.04)
    b.box(0.22, 0.16, 0.03, 0.2, -0.05, 0.68, "cream", bevel=0.006)                         # notebook
    b.socket("use", (0, -0.55, 0), rotz=180)
    b.finish(KIT, "furniture")

    b = Builder("chair", seed=423)
    b.box(0.42, 0.42, 0.06, 0, 0, 0.4, "wood_c", bevel=0.015)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.06, 0.06, 0.4, sx * 0.17, sy * 0.17, 0, "wood_b", bevel=0.01)
        b.box(0.06, 0.06, 0.46, sx * 0.17, 0.17, 0.46, "wood_b", bevel=0.01)
    b.box(0.4, 0.05, 0.12, 0, 0.17, 0.62, "wood", bevel=0.012)
    b.box(0.4, 0.05, 0.1, 0, 0.17, 0.82, "wood", bevel=0.012)
    b.socket("seat", (0, 0, 0.46))
    b.finish(KIT, "furniture", {"note": "backrest at +Y; sitter faces -Y"})

    b = Builder("wall_shelf_small", seed=424)
    with b.at((0, 0, 0.18)):
        b.box(0.7, 0.2, 0.05, 0, -0.1, 0, "wood_c", bevel=0.012)
        for s in (-1, 1):
            b.box(0.04, 0.16, 0.16, s * 0.26, -0.08, -0.16, "wood_dark", bevel=0.008)
        for i, c in enumerate(("red", "teal", "mustard", "olive")):
            b.box(0.045, 0.14, 0.17 - (i % 2) * 0.03, -0.27 + i * 0.05, -0.1, 0.05, c, bevel=0.006)
        b.box(0.045, 0.14, 0.15, -0.06, -0.1, 0.05, "coral", bevel=0.006, rot=(0, 18, 0))
        b.cyl(0.06, 0.08, 0.18, -0.1, 0.05, "terracotta", segs=8, r2=0.07, bevel=0.006)
        for i in range(4):
            a = i * math.pi / 2
            b.blob(0.06, 0.04, 0.035, 0.18 + math.cos(a) * 0.04, -0.1 + math.sin(a) * 0.04, 0.17, "leaf", subdiv=1,
                   rot=(0, 0, math.degrees(a)))
    b.finish(KIT, "wall_prop", {"note": "origin at the bracket bottoms on the wall face"})

    b = Builder("round_rug", seed=425)
    b.cyl(0.68, 0.025, 0, 0, 0, tint("rug", "coral"), segs=16, bevel=0.01)
    b.cyl(0.52, 0.027, 0, 0, 0.0, tint("rug_b", "roof_c"), segs=16)
    b.cyl(0.4, 0.029, 0, 0, 0.0, tint("rug", "coral"), segs=16)
    b.cyl(0.18, 0.031, 0, 0, 0.0, tint("rug_b", "roof_c"), segs=16)
    b.finish(KIT, "furniture", {"walkable": True})

    b = Builder("shrub_round", seed=431)
    shrub(b, 0, 0, 1.0)
    b.finish(KIT, "nature")
    b = Builder("shrub_flowering", seed=432)
    shrub(b, 0, 0, 0.85, flowers=True)
    b.finish(KIT, "nature")


def build():
    build_exterior()
    roof("cottage_roof", 403).finish(KIT, "roof", {"footprint_m": [W, D], "eave_z": TOP,
                                                   "note": "fits cottage walls; origin at ground like the house"})
    build_interior_shell()
    build_props()
