"""Exterior finishing details (World Kit - Building Finishing Details): trims, caps, shutters,
porch, snow overlay and sign bracket that close modular seams on the buildings/cottage/cafe shells.

Every piece is its own asset; it never stacks on an existing trim face. Conventions:
  * Wall-mounted pieces: origin on the wall face at y=0, piece in front of it (-Y). Placed
    3 mm proud of the face they attach to (the assembly test in preview_building_finishing.py
    does exactly that) so two assets never share a plane.
  * Pitch-dependent pieces default to the cottage roof (40.5 deg, 0.36 m overhang) and record
    the pitch they fit in meta; rebuild with another pitch for other roofs.
  * Roof-side pieces carry meta visibility_group="roof" so the cutaway hides them with the roof.
"""
from common import *
from kits.buildings import T, BASE_H, WALL_H, tiled_gable, ROOF_T

KIT = "building_finishing"
PREVIEW_WIDTH = 10.0
TRIM = (tint("trim", "wood"), tint("trim_b", "wood_b"), tint("trim_c", "wood_c"))
STONE_T = (tint("stone", "stone"), tint("stone_b", "paving_b"), tint("stone_c", "stone_dark"))
SHUTTER = tint("shutter", "coral")
SNOW = tint("snow", "snow")
COTTAGE_PITCH = math.degrees(math.atan(1.45 / 1.7))   # kits/cottage.py RISE over W/2
ROOF_GROUP = {"visibility_group": "roof"}


# ---------------------------------------------------------------------------
def foundation_skirt(b, L, h=0.3, d=0.12, seed=0):
    """Two courses of chunky stones in front of y=0 (back face on the wall/plinth)."""
    rng = random.Random(seed)
    for row, (z, hh) in enumerate(((0, h * 0.52), (h * 0.52, h * 0.48))):
        x, i = -L / 2, row * 3
        while x < L / 2 - 1e-3:
            w = min(rng.uniform(0.3, 0.46), L / 2 - x)
            if L / 2 - (x + w) < 0.12:
                w = L / 2 - x
            dd = d - row * 0.015 - rng.uniform(0, 0.012)
            b.box(w - 0.015, dd, hh - 0.012, x + w / 2, -dd / 2, z, pick(STONE_T, i), bevel=0.028)
            x += w
            i += 1


def skirt_corner(b, h=0.3, d=0.12):
    """Outer corner block where two skirt runs meet. The building occupies x<0, y>0 (front face
    plane y=0, side face plane x=0); the front run ends at x=0 and the side run starts at y=0."""
    s = d + 0.02
    b.box(s, s, h * 0.52 - 0.012, 0.003 + s / 2, -0.003 - s / 2, 0, STONE_T[2], bevel=0.03)
    b.box(s - 0.01, s - 0.01, h * 0.48 - 0.012, 0.003 + s / 2, -0.003 - s / 2, h * 0.52, STONE_T[0], bevel=0.03)


def corner_trim(b, h):
    """Honey-wood corner post wrapping an outer corner at the origin. The two wall faces are the
    planes y=0 (front, piece toward -Y) and x=0 (side, piece toward -X)."""
    t, w = 0.05, 0.15
    b.box(w, t, h, -t + w / 2, -t / 2, 0, TRIM[0], bevel=0.012)        # front board, wraps the corner
    b.box(t, w - t, h, -t / 2, (w - t) / 2, 0, TRIM[1], bevel=0.012)   # side board
    for k, z in enumerate((h * 0.22, h * 0.62)):                       # cross blocks, as on the sheet
        b.box(w + 0.1, t + 0.03, 0.12, -t + w / 2 + 0.05, -(t + 0.03) / 2, z, TRIM[2], bevel=0.015)
        b.box(t + 0.03, w + 0.05, 0.12, -(t + 0.03) / 2, (w + 0.05) / 2 - t, z, TRIM[k], bevel=0.015)


def window_sill(b, w=0.62):
    """Sill for a window_unit built with sill=False (window width w). Top at z=0."""
    L = w + 0.34
    b.box(L, 0.2, 0.08, 0, -0.1, -0.08, TRIM[0], bevel=0.02)
    for s in (-1, 1):  # corbels
        b.box(0.08, 0.1, 0.14, s * (L / 2 - 0.12), -0.05, -0.22, TRIM[2], bevel=0.015)
        b.box(0.08, 0.06, 0.06, s * (L / 2 - 0.12), -0.13, -0.14, TRIM[2], bevel=0.012, rot=(-30, 0, 0))


def shutter_leaf(b, side, w, h, x_hinge):
    """One shutter leaf resting open against the wall, hinged on its inner edge."""
    xc = x_hinge + side * w / 2
    with b.part(f"shutter_{'l' if side < 0 else 'r'}", pivot=(x_hinge, -0.023, 0), motion="hinge", axis="z",
                open_deg=-side * 165, rest="open_against_wall"):
        n = 3
        for i in range(n):
            pw = w / n
            b.box(pw - 0.012, 0.04, h, x_hinge + side * pw * (i + 0.5), -0.023, 0, SHUTTER, bevel=0.012)
        for z in (h * 0.16, h * 0.78):  # iron strap hinges
            b.box(w * 0.7, 0.012, 0.05, x_hinge + side * w * 0.35, -0.049, z, "iron", bevel=0.004)
            b.cyl(0.022, 0.07, x_hinge - side * 0.005, -0.03, z - 0.01, "iron", segs=6)
        b.cyl(0.045, 0.012, xc, -0.043, h * 0.5, "black", segs=4, rot=(90, 0, 0))   # diamond cut-out mark


def threshold(b, w=1.1, d=0.36, h=0.06):
    b.box(w, d, h, 0, -d / 2, 0, STONE_T[0], bevel=0.02)
    b.box(w + 0.08, 0.06, h * 0.7, 0, -d - 0.02, 0, STONE_T[2], bevel=0.012)


def ridge_cap(b, L=0.42, pitch=COTTAGE_PITCH, wdt=0.42):
    """One chunky coral capping tile; origin at the ridge line on top of the roof's ridge row.
    Two slabs meet at a rounded top, following the roof pitch."""
    a = pitch
    half = wdt / 2
    for sx in (-1, 1):
        b.box(half / math.cos(math.radians(a)) + 0.02, L - 0.02, 0.07, sx * half / 2, 0, 0.035 - half / 2 * math.tan(math.radians(a)) * 0.35,
              ROOF_T[0], bevel=0.025, rot=(0, sx * a * 0.55, 0), center=True)
    b.box(0.16, L - 0.03, 0.1, 0, 0, 0.02, ROOF_T[1], bevel=0.04)


def end_cap(b, pitch=COTTAGE_PITCH):
    """Ridge end with the diamond face plate, closes the ridge row at a gable."""
    ridge_cap(b, L=0.3, pitch=pitch)
    b.box(0.22, 0.05, 0.22, 0, -0.16, 0.0, ROOF_T[2], bevel=0.02, rot=(0, 45, 0), center=True)


def eave_trim(b, L=1.0, pitch=COTTAGE_PITCH, n=2):
    """Trim board under the eave along the wall top, with corbels that stay under the roof slope.
    Origin at the wall face, z=0 at the wall top; the roof overhang is toward -Y."""
    tanA = math.tan(math.radians(pitch))
    b.box(L, 0.045, 0.12, 0, -0.0225, -0.14, TRIM[0], bevel=0.012)
    for i in range(n):
        x = -L / 2 + L / n * (i + 0.5)
        b.box(0.07, 0.06, 0.26, x, -0.075, -0.4, TRIM[1], bevel=0.012)                  # leg on the wall
        reach = 0.16
        top = -0.16 - 0.02
        b.box(0.07, reach, 0.07, x, -0.045 - reach / 2, top - 0.07, TRIM[2], bevel=0.012)  # arm
        b.box(0.06, 0.05, 0.2, x, -0.13, -0.33, TRIM[2], bevel=0.01, rot=(-38, 0, 0))     # brace
    return {"fits_pitch_deg": round(pitch, 1), "top_below_wall_top_m": 0.02}


def chimney_cap(b, w=0.68):
    """Stone hood for a chimney top of width w: ring base (the flue stays open), four corner
    piers and a pyramid lid. Origin at the top of the existing chimney cap."""
    t = 0.12
    for sx, sy, lx, ly in ((0, -1, w, t), (0, 1, w, t), (-1, 0, t, w - 2 * t), (1, 0, t, w - 2 * t)):
        b.box(lx, ly, 0.08, sx * (w - t) / 2, sy * (w - t) / 2, 0, STONE_T[1], bevel=0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.13, 0.13, 0.2, sx * (w / 2 - 0.065), sy * (w / 2 - 0.065), 0.08, STONE_T[0], bevel=0.02)
    b.box(w + 0.08, w + 0.08, 0.07, 0, 0, 0.28, STONE_T[2], bevel=0.02)
    b.cyl((w + 0.06) / math.sqrt(2), 0.16, 0, 0, 0.35, "stone_grey", segs=4, r2=0.04, rot=(0, 0, 45))
    b.socket("fx_smoke", (0, 0, 0.56))


def porch_canopy(b, inner=1.5, depth=0.95, h=2.05, rise=0.38):
    """Honey posts on stone bases with a small coral gable; clear opening `inner` wide and h
    high (under the beam). Back edge at the wall face y=0, extending toward -Y."""
    pw = 0.13
    px = inner / 2 + pw / 2
    py = -depth + 0.1
    for s in (-1, 1):
        b.box(0.24, 0.24, 0.18, s * px, py, 0, STONE_T[0], bevel=0.03)
        b.box(pw, pw, h - 0.18, s * px, py, 0.18, TRIM[0], bevel=0.018)
        b.box(pw, depth - 0.05, 0.12, s * px, -(depth - 0.05) / 2 - 0.003, h, TRIM[1], bevel=0.015)  # side beam to wall
        b.box(0.07, 0.3, 0.07, s * (px - 0.1), py + 0.14, h - 0.16, TRIM[2], bevel=0.01, rot=(40, 0, 0))  # knee brace
    b.box(inner + 2 * pw + 0.1, 0.13, 0.14, 0, py, h, TRIM[2], bevel=0.018)                   # front beam
    with b.at((0, -depth / 2, h + 0.14)):
        tiled_gable(b, inner + 2 * pw, depth, rise, z=0.0, overhang=0.12, tile=0.24, tile_thick=0.06,
                    gable=None, timber=False, fascia=TRIM[2], gable_t=pw)
    b.socket("door_approach", (0, -depth - 0.4, 0), rotz=180)
    return {"clear_width_m": inner, "clear_height_m": h, "depth_m": depth}


def snow_eave(b, L=1.0, pitch=COTTAGE_PITCH, seed=1):
    """Soft snow lying on the eave tiles, rolling over the edge with icicles. Origin at the
    eave's outer edge on the tile top; the roof rises toward +Y (into the building)."""
    rng = random.Random(seed)
    with b.at((0, 0, 0), rot=(pitch, 0, 0)):
        b.box(L, 0.42, 0.065, 0, 0.21, 0, SNOW, bevel=0.03)                            # snow bed on the tiles
        b.blob(L * 0.42, 0.14, 0.03, rng.uniform(-0.08, 0.08), 0.25, 0.06, SNOW, subdiv=2)  # one soft drift
        b.cyl(0.05, L - 0.03, -L / 2 + 0.015, 0.025, 0.03, SNOW, segs=8, rot=(0, 90, 0))   # rounded lip over the edge
    for i in range(int(L / 0.11)):
        x = -L / 2 + 0.06 + i * 0.11 + rng.uniform(-0.025, 0.025)
        ln = rng.uniform(0.05, 0.15)
        b.cyl(0.018, ln, x, -0.02, -ln - 0.005, "ice", segs=5, r2=0.002)


def sign_bracket(b, arm=0.62):
    """Wall plate, arm with knee brace and a hanging octagonal teal sign (sway part) with a blank
    insert on both faces. Wall item: back of the plate at y=0, arm toward -Y."""
    b.box(0.12, 0.05, 0.5, 0, -0.025, -0.25, TRIM[0], bevel=0.012)
    for z in (-0.06, -0.42):
        b.box(0.14, 0.012, 0.05, 0, -0.056, z, "iron", bevel=0.004)
    b.box(0.08, arm, 0.08, 0, -arm / 2 - 0.05, 0.0, TRIM[1], bevel=0.015)
    b.box(0.06, 0.06, 0.34, 0, -0.2, -0.24, TRIM[2], bevel=0.01, rot=(-48, 0, 0))
    hx = -arm + 0.02
    with b.part("sign", pivot=(0, hx, -0.01), motion="sway", amp_deg=4):
        for s in (-1, 1):
            b.cyl(0.012, 0.1, 0, hx + s * 0.13, -0.11, "iron", segs=5)
        with b.at((0, hx, -0.42), rot=(90, 0, 90)):
            b.cyl(0.25, 0.06, 0, 0, -0.03, tint("sign", "teal"), segs=8, bevel=0.012, rot=(0, 0, 22.5))
            for s in (-1, 1):
                b.cyl(0.19, 0.004, 0, 0, s * 0.032 - (0.004 if s < 0 else 0), "insert_sign", segs=8, rot=(0, 0, 22.5))


# ---------------------------------------------------------------------------
def build():
    b = Builder("foundation_skirt_1m", seed=501); foundation_skirt(b, 1.0, seed=1)
    b.finish(KIT, "trim", {"length_m": 1.0, "height_m": 0.3, "attach": "front of plinth/wall base, 3 mm proud"})
    b = Builder("foundation_skirt_2m", seed=502); foundation_skirt(b, 2.0, seed=2)
    b.finish(KIT, "trim", {"length_m": 2.0, "height_m": 0.3, "attach": "front of plinth/wall base, 3 mm proud"})
    b = Builder("foundation_skirt_corner", seed=503); skirt_corner(b)
    b.finish(KIT, "trim", {"attach": "outer corner where two skirt runs meet"})

    h = WALL_H - BASE_H
    b = Builder("exterior_corner_trim", seed=504); corner_trim(b, h)
    b.finish(KIT, "trim", {"height_m": round(h, 3), "attach": "outer wall corner above the stone base course; "
                           "origin at the corner, front face y=0, side face x=0"})

    b = Builder("window_sill", seed=505); window_sill(b)
    b.finish(KIT, "trim", {"fits_window_w_m": 0.62, "attach": "under a window_unit(sill=False); top at the glass bottom - 0.13"})

    b = Builder("window_shutters", seed=506)
    for s in (-1, 1):
        shutter_leaf(b, s, 0.3, 0.92, s * 0.48)
    b.finish(KIT, "trim", {"fits_window_w_m": 0.62, "rest": "open against the wall; *_open clips close them over the window",
                           "attach": "origin at the window centre line, z = glass bottom - 0.06, on the wall face"})

    b = Builder("doorstep_threshold", seed=507); threshold(b)
    b.finish(KIT, "trim", {"step_height_m": 0.06, "traversable": True, "attach": "back edge against the door threshold"})

    b = Builder("roof_ridge_cap", seed=508); ridge_cap(b)
    b.finish(KIT, "roof_trim", {**ROOF_GROUP, "segment_m": 0.42, "fits_pitch_deg": round(COTTAGE_PITCH, 1),
                                "attach": "on top of a tiled_gable ridge row, 3 mm above it"})
    b = Builder("roof_end_cap", seed=509); end_cap(b)
    b.finish(KIT, "roof_trim", {**ROOF_GROUP, "fits_pitch_deg": round(COTTAGE_PITCH, 1),
                                "attach": "last ridge cap at a gable end; diamond plate faces -Y"})

    b = Builder("eave_trim", seed=510); m = eave_trim(b)
    b.finish(KIT, "roof_trim", {**ROOF_GROUP, **m, "length_m": 1.0, "attach": "eave wall face, z=0 at the wall top"})

    b = Builder("chimney_cap", seed=511); chimney_cap(b)
    b.finish(KIT, "roof_trim", {**ROOF_GROUP, "fits_chimney_cap_w_m": 0.68,
                                "attach": "on top of an existing chimney cap; flue stays open"})

    b = Builder("porch_canopy", seed=512); m = porch_canopy(b)
    b.finish(KIT, "building_part", {**m, "fits_door": "buildings.door_unit 0.86 x 1.6 (heavy surround 1.4 m wide)",
                                    "attach": "back edge on the door wall face, centred on the door"})

    b = Builder("snow_eave_overlay", seed=513); snow_eave(b)
    b.finish(KIT, "roof_trim", {**ROOF_GROUP, "length_m": 1.0, "removable": True,
                                "fits_pitch_deg": round(COTTAGE_PITCH, 1), "attach": "eave outer edge on the tile top"})

    b = Builder("wall_sign_bracket", seed=514); sign_bracket(b)
    b.finish(KIT, "wall_prop", {**placement("wall", rotations=(0,)), "insert": "insert_sign on both faces",
                                "attach": "wall face, top of the plate at the origin"})
