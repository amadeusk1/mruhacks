"""Interior finishing and utility details (World Kit - Interior Finishing Details).

Shell finishes (skirting, wall panels) are layered in front of a room-shell wall, each 3 mm proud of
what it covers: wall face -> stone base course (0.035) -> wall panel (0.038..0.073) -> skirting.
Wall items: back at y=0, facing -Y. Ceiling items: hook/top at the origin. Floor items: bottom centre.
Lamp glass uses its own emissive material (glow) so the engine can pulse it.
"""
from common import *
from kits.buildings import T

KIT = "interior_finishing"
PREVIEW_WIDTH = 9.0
WOOD = (tint("trim", "wood"), tint("trim_b", "wood_b"), tint("trim_c", "wood_c"))
CREAM = tint("frame", "cream")
PANEL_LO = tint("panel", "teal")
PANEL_HI = tint("panel_upper", "cream")
SHELL = {"shell_finish": True}
PANEL_H = 0.78   # stays under a window_unit sill (glass at 0.93 m, sill underside 0.80 m)
SKIRT_H = 0.13


def skirting(b, L):
    b.box(L, 0.028, SKIRT_H - 0.025, 0, -0.014, 0, WOOD[0], bevel=0.008)
    b.box(L, 0.04, 0.025, 0, -0.02, SKIRT_H - 0.025, WOOD[1], bevel=0.01)   # rounded top lip


def skirting_corner(b, L=0.3):
    """Inside corner: two short runs meeting at the origin. The walls' faces are the planes
    y=0 (back wall) and x=0 (side wall); the piece lies in the room quadrant x>0, y<0."""
    with b.at((L / 2, 0, 0)):
        skirting(b, L)
    with b.at((0, -L / 2 - 0.04, 0), rotz=90):
        skirting(b, L - 0.04)
    b.box(0.05, 0.05, SKIRT_H + 0.01, 0.025, -0.025, 0, WOOD[2], bevel=0.008)


def wall_panel(b, L):
    """Teal boarded wainscot with a cream upper band and a cap rail, 0.035 thick."""
    n = max(2, round(L / 0.16))
    lo = PANEL_H * 0.62
    b.box(L, 0.012, PANEL_H, 0, -0.006, 0, PANEL_LO, bevel=0)                      # backer
    for i in range(n):
        x = -L / 2 + L / n * (i + 0.5)
        b.box(L / n - 0.012, 0.022, lo - 0.01, x, -0.023, 0, PANEL_LO, bevel=0.006)
        b.box(L / n - 0.012, 0.018, PANEL_H - lo - 0.05, x, -0.021, lo + 0.02, PANEL_HI, bevel=0.005)
    b.box(L, 0.03, 0.03, 0, -0.027, lo - 0.01, WOOD[1], bevel=0.008)               # chair rail
    b.box(L + 0.01, 0.04, 0.035, 0, -0.022, PANEL_H - 0.035, WOOD[0], bevel=0.01)  # cap rail


def door_frame(b, w=1.02, h=1.68, depth=T):
    """Cream casing for a plain wall opening (masonry_wall opening w x h, wall thickness T):
    linings through the wall and a chunky casing on both faces. Origin at the opening's
    bottom centre, wall centred on y=0."""
    c = 0.1
    for s in (-1, 1):
        b.box(0.04, depth + 0.006, h, s * (w / 2 - 0.02 - 0.003), 0, 0, CREAM, bevel=0.006)        # lining
        for fy in (-1, 1):
            b.box(c, 0.04, h + c, s * (w / 2 + c / 2 - 0.035), fy * (depth / 2 + 0.023), 0, CREAM, bevel=0.012)
            b.box(c + 0.03, 0.05, 0.1, s * (w / 2 + c / 2 - 0.035), fy * (depth / 2 + 0.028), 0, WOOD[1], bevel=0.01)  # plinth block
    b.box(w - 0.046, depth + 0.006, 0.04, 0, 0, h - 0.04 - 0.003, CREAM, bevel=0.006)
    for fy in (-1, 1):
        b.box(w + 2 * c - 0.05, 0.05, c + 0.02, 0, fy * (depth / 2 + 0.025), h, CREAM, bevel=0.015)


def room_divider(b, L=1.5, h=0.9):
    n = 3
    pw = (L - 0.12) / n
    for i in range(n + 1):
        b.box(0.09, 0.09, h, -L / 2 + 0.045 + i * (pw + 0.04) - (0 if i == 0 else 0.0) + (0 if i < n else -0.0), 0, 0,
              WOOD[i % 2], bevel=0.015)
        b.box(0.12, 0.12, 0.05, -L / 2 + 0.045 + i * (pw + 0.04), 0, h, WOOD[2], bevel=0.015)
    for z in (0.08, h - 0.1):
        b.box(L - 0.08, 0.06, 0.07, 0, 0, z, WOOD[0], bevel=0.012)
    for i in range(n):
        x = -L / 2 + 0.09 + pw / 2 + i * (pw + 0.04) - 0.005
        b.box(pw - 0.06, 0.03, h - 0.24, x, 0, 0.16, CREAM, bevel=0.008)
        for j, (dx, dz, r) in enumerate(((-0.08, 0.38, -30), (0.0, 0.22, 0), (0.08, 0.38, 30))):  # leaf cut-outs
            for fy in (-1, 1):
                b.blob(0.03, 0.006, 0.06, x + dx, fy * 0.0175, 0.16 + dz, PANEL_LO, subdiv=1, rot=(0, r, 0))
    b.socket("block", (0, 0, 0))


def corner_shelf(b, r=0.36):
    """Quarter-round corner shelf: back panels on the planes y=0 and x=0, shelf boards in the corner."""
    H = 0.7
    b.box(0.03, r, H, 0.015, -r / 2, 0, WOOD[1], bevel=0.008)
    b.box(r, 0.03, H, r / 2, -0.015, 0, WOOD[2], bevel=0.008)
    for i, z in enumerate((0.0, 0.33, H - 0.03)):
        pts = [(0, 0)] + [(r * math.cos(a), -r * math.sin(a)) for a in [math.radians(t) for t in range(0, 91, 15)]]
        b.prism(pts, 0.03, z=z, mat=WOOD[0], plane="xy")
        if i < 2:
            b.socket(f"surface_{i}", (r * 0.4, -r * 0.4, z + 0.03))
    pts = [(r * math.cos(math.radians(t)), -r * math.sin(math.radians(t))) for t in range(0, 91, 15)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):  # front lip on the bottom shelf
        L = math.hypot(x1 - x0, y1 - y0)
        b.box(L, 0.025, 0.06, (x0 + x1) / 2, (y0 + y1) / 2, 0.03, WOOD[1], bevel=0.006,
              rot=(0, 0, math.degrees(math.atan2(y1 - y0, x1 - x0))))


def ceiling_beam(b, L=3.0):
    """Origin at the top centre of the beam."""
    b.box(L, 0.18, 0.2, 0, 0, -0.2, WOOD[0], bevel=0.025)
    for s in (-1, 1):
        b.box(0.12, 0.22, 0.26, s * (L / 2 - 0.06), 0, -0.26, WOOD[2], bevel=0.02)   # end blocks


def pendant(b, drop=0.55):
    b.cyl(0.08, 0.03, 0, 0, -0.03, "gold", segs=8, bevel=0.006)
    b.cyl(0.012, drop - 0.12, 0, 0, -drop + 0.09, "rope", segs=5)
    b.cyl(0.05, 0.05, 0, 0, -drop + 0.05, "gold", segs=8)
    b.cyl(0.11, 0.12, 0, 0, -drop - 0.07, "glow", segs=8, r2=0.05)
    b.cyl(0.04, 0.06, 0, 0, -drop - 0.13, "glow", segs=8, r2=0.11)
    for i in range(8):
        a = math.radians(22.5 * 2 * i)
        b.box(0.012, 0.012, 0.13, 0.11 * math.cos(a), 0.11 * math.sin(a), -drop - 0.075, "gold", bevel=0,
              rot=(math.sin(a) * 20, -math.cos(a) * 20, 0))
    b.socket("light", (0, 0, -drop - 0.07))


def sconce(b):
    b.cyl(0.08, 0.025, 0, -0.0125, 0, WOOD[0], segs=8, bevel=0.006, rot=(90, 0, 0), center=True)
    b.box(0.03, 0.14, 0.03, 0, -0.09, 0.05, "gold", bevel=0.006)
    b.box(0.03, 0.03, 0.08, 0, -0.15, 0.0, "gold", bevel=0.006)
    b.cyl(0.075, 0.1, 0, -0.17, -0.16, "glow", segs=8, r2=0.09)
    b.cyl(0.09, 0.04, 0, -0.17, -0.06, "gold", segs=8, r2=0.04)
    b.socket("light", (0, -0.17, -0.11))


def radiator(b, n=7):
    W = n * 0.07 + 0.04
    for i in range(n):
        x = -W / 2 + 0.04 + i * 0.07
        b.box(0.055, 0.1, 0.42, x, -0.07, 0.08, CREAM, bevel=0.02)
    b.box(W, 0.04, 0.04, 0, -0.07, 0.42, CREAM, bevel=0.01)
    for s in (-1, 1):
        b.box(0.05, 0.07, 0.08, s * (W / 2 - 0.06), -0.07, 0, CREAM, bevel=0.01)   # feet
        b.cyl(0.02, 0.1, s * (W / 2 + 0.04), -0.07, 0.12, "gold", segs=6, rot=(0, 90, 0), center=True)
        b.cyl(0.03, 0.05, s * (W / 2 + 0.06), -0.07, 0.12, "gold", segs=6)
    return W


def waste_bin(b):
    b.cyl(0.13, 0.3, 0, 0, 0.01, tint("bin", "teal"), segs=8, r2=0.16, bevel=0.008)
    b.cyl(0.165, 0.04, 0, 0, 0.29, CREAM, segs=8, bevel=0.01)
    b.cyl(0.135, 0.04, 0, 0, 0.0, CREAM, segs=8, bevel=0.008)


def floor_vent(b):
    b.box(0.42, 0.24, 0.012, 0, 0, 0.0, "iron_light", bevel=0.004)
    for i in range(4):
        y = -0.075 + i * 0.05
        for sx in (-1, 1):
            b.box(0.15, 0.022, 0.006, sx * 0.09, y, 0.009, "black", bevel=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(0.012, 0.006, sx * 0.19, sy * 0.1, 0.009, "steel", segs=6)


def build():
    for L in (0.5, 1.0, 2.0):
        b = Builder(f"skirting_strip_{str(L).replace('.0', '').replace('0.5', '05')}m", seed=601 + int(L * 2)); skirting(b, L)
        b.finish(KIT, "shell_finish", {**SHELL, "length_m": L, "height_m": SKIRT_H,
                                       "attach": "wall face (in front of any wall_panel), 3 mm proud"})
    b = Builder("inside_corner_skirting", seed=604); skirting_corner(b)
    b.finish(KIT, "shell_finish", {**SHELL, "attach": "inside corner; walls on planes y=0 and x=0"})
    for L in (1.0, 0.5):
        b = Builder(f"wall_panel_{str(L).replace('.0', '').replace('0.5', '05')}m", seed=605 + int(L * 2)); wall_panel(b, L)
        b.finish(KIT, "shell_finish", {**SHELL, "length_m": L, "height_m": PANEL_H,
                                       "attach": "wall face, in front of the stone base course (0.038 m proud)"})
    b = Builder("door_frame", seed=608); door_frame(b)
    b.finish(KIT, "shell_finish", {**SHELL, "fits_opening_m": [1.02, 1.68], "wall_thickness_m": T,
                                   "attach": "plain masonry_wall opening (no door_unit); origin at the opening bottom centre"})
    b = Builder("room_divider", seed=609); room_divider(b)
    b.finish(KIT, "furniture", {**placement("floor", footprint=[3, 1]), "height_m": 0.95,
                                "note": "low enough not to hide the 0.9 m penguin from the game camera"})
    b = Builder("corner_shelf", seed=610); corner_shelf(b)
    b.finish(KIT, "furniture", {**placement("wall", rotations=(0,)), "surfaces": {"surface_0": [0.2, 0.2], "surface_1": [0.2, 0.2]},
                                "attach": "inside corner, walls on planes y=0 and x=0; hang at about 0.9 m"})
    b = Builder("ceiling_beam", seed=611); ceiling_beam(b)
    b.finish(KIT, "furniture", {**placement("ceiling", footprint=[6, 1], rotations=(0, 90)), "visibility_group": "roof",
                                "length_m": 3.0})
    b = Builder("ceiling_pendant", seed=612); pendant(b)
    b.finish(KIT, "light", placement("ceiling", footprint=[1, 1]))
    b = Builder("wall_sconce", seed=613); sconce(b)
    b.finish(KIT, "light", {**placement("wall", rotations=(0,)), "mount_height_m": 1.45})
    b = Builder("radiator", seed=614); radiator(b)
    b.finish(KIT, "furniture", {**placement("floor", footprint=[2, 1], clearance=0),
                                "attach": "against a wall, back at y=0 (sits clear of skirting and panels)",
                                "note": "decorative; must not cover a door or interaction spot"})
    b = Builder("small_waste_bin", seed=615); waste_bin(b)
    b.finish(KIT, "furniture", placement("floor", footprint=[1, 1]))
    b = Builder("floor_vent", seed=616); floor_vent(b)
    b.finish(KIT, "decal", {**placement("rug", footprint=[1, 1]), "offset_m": 0.003,
                            "note": "place 3 mm above the floor; no collision"})
