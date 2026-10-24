"""Assembly test for the finishing kits: dresses cottage_exterior and room_shell_3x3 with the
finishing pieces (built from the same kit functions at the shells' real dimensions), then renders
4 sides + close-ups into WIP and keepers into Renders/Details.
  Blender -b --factory-startup --python art/blender/preview_finishing.py -- [ext|int|keep]
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import common as c
from mathutils import Vector

shots = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["ext", "int"]
c.reset_scene()
import kits.building_finishing as bf
import kits.interior_finishing as itf
import kits.cottage as ck
import kits.buildings as bk

K = "_assembly"
W, D, SLAB, TOP, RISE = ck.W, ck.D, ck.SLAB, ck.TOP, ck.RISE
A = math.atan(RISE / (W / 2))
LIFT = 0.06 / math.cos(A) + 0.12 * math.tan(A) + 0.02          # same as buildings.tiled_gable
OVER = 0.36


def piece(name, fn, loc, rotz=0.0, **kw):
    b = c.Builder(name, seed=abs(hash(name)) % 997 + 1)
    with b.at(loc, rotz=rotz):
        fn(b, **kw)
    return b.finish(K, "test")


def check(objs):
    bad = [(o.name, o.get("zfight_remaining")) for o in objs if o.get("zfight_remaining")]
    print("ZF_REMAINING", bad or "none")


def exterior():
    house = ck.build_exterior()
    out = [house]
    fy = -D / 2 - 0.025 - 0.003               # in front of the quoins
    # skirt: front run right of the entry steps, front-right corner block, right side runs
    out.append(piece("t_skirt_front", bf.foundation_skirt, (1.28, -D / 2 - 0.08 - 0.003, 0), L=1.0))
    out.append(piece("t_skirt_corner", bf.skirt_corner, (W / 2 + 0.08, -D / 2 - 0.08, 0)))
    out.append(piece("t_skirt_side_a", bf.foundation_skirt, (W / 2 + 0.083, -0.577, 0), rotz=90, L=2.0))
    out.append(piece("t_skirt_side_b", bf.foundation_skirt, (W / 2 + 0.083, 0.923, 0), rotz=90, L=1.0, seed=3))
    hz = SLAB + bk.BASE_H
    out.append(piece("t_corner_l", lambda b: bf.corner_trim(b, TOP - hz - 0.02), (-W / 2 - 0.003, fy, hz)))
    out.append(piece("t_corner_r", lambda b: bf.corner_trim(b, TOP - hz - 0.02), (W / 2 + 0.003, fy, hz), rotz=90))
    # right side wall: shutters on its window, sign bracket, eave trim under the right eave
    out.append(piece("t_shutters", lambda b: [bf.shutter_leaf(b, s, 0.3, 0.92, s * 0.48) for s in (-1, 1)],
                     (W / 2, 0, SLAB + 0.9 - 0.06), rotz=90))
    out.append(piece("t_sign", bf.sign_bracket, (W / 2 + 0.003, -1.1, SLAB + 1.72), rotz=90))
    for y in (-0.64, 0.64):
        out.append(piece(f"t_eave_{y}", bf.eave_trim, (W / 2 + 0.003, y, TOP), rotz=90, L=1.0))
    # snow overlay along the right eave, on the tile tops
    n = Vector((math.sin(A), 0, math.cos(A)))
    edge = Vector((W / 2 + OVER, 0, TOP + LIFT - OVER * math.tan(A))) + n * (0.13 + 0.01 + 0.015)
    for y in (-1.5, -0.5, 0.5, 1.5):
        out.append(piece(f"t_snow_{y}", bf.snow_eave, (edge.x, y, edge.z), rotz=90, L=1.0, seed=int(y * 10) + 20))
    # ridge caps on top of the ridge row, an end cap at each gable
    rz = TOP + LIFT + RISE + 0.02 + 0.16 + 0.003
    for i in range(7):
        out.append(piece(f"t_ridge_{i}", bf.ridge_cap, (0, -1.26 + i * 0.42, rz)))
    out.append(piece("t_end_f", bf.end_cap, (0, -1.26 - 0.36, rz)))
    out.append(piece("t_end_b", bf.end_cap, (0, 1.26 + 0.36, rz), rotz=180))
    # chimney hood on the cottage chimney cap
    top = TOP + RISE + 0.35
    out.append(piece("t_chimney", bf.chimney_cap, (ck.CH_X, ck.CH_Y, top + 0.14 + 0.003)))
    # porch over the front door
    out.append(piece("t_porch", bf.porch_canopy, (ck.DOOR_X, -D / 2 - 0.003, 0)))
    # test wall beside the house: window without its own sill + sill + shutters, door + threshold
    b = c.Builder("t_wall", seed=7)
    with b.at((W / 2 + 2.6, 0, 0), rotz=0):
        bk.masonry_wall(b, 2.6, openings=[(-0.6, 1.02, 0, 1.68), (0.65, 0.76, 0.83, 1.69)], quoins=(True, True))
        bk.door_unit(b, -0.6, socket=False)
        bk.window_unit(b, 0.65, 0.9, sill=False)
    out.append(b.finish(K, "test"))
    wx, fyw = W / 2 + 2.6, -bk.T / 2
    out.append(piece("t_sill", bf.window_sill, (wx + 0.65, fyw - 0.003, 0.9 - 0.13 + 0.06)))
    out.append(piece("t_shutters2", lambda b: [bf.shutter_leaf(b, s, 0.3, 0.92, s * 0.48) for s in (-1, 1)],
                     (wx + 0.65, fyw, 0.9 - 0.06)))
    out.append(piece("t_step", bf.threshold, (wx - 0.6, fyw - 0.083, 0)))
    check(out)
    return out


def interior():
    shell = bk.room_shell(K, "t_room")
    out = [shell]
    S, F = 3.0, 0.21                                  # room size, plank top
    PB = 0.038                                        # panel back offset from wall face
    SK = PB + 0.042 + 0.003                           # skirting back offset (in front of the panel)
    wall_runs = [  # (centre along wall, length, which wall)
        (0.35, 1.0, "back"), (1.1, 0.5, "back"),
        (1.177, 0.5, "left"), (0.427, 1.0, "left"), (-0.573, 1.0, "left")]
    for i, (u, L, w) in enumerate(wall_runs):
        if w == "back":
            loc, rz = (u, S / 2 - PB, F + 0.003), 0
            sloc = (u, S / 2 - SK, F + 0.003)
        else:
            loc, rz = (-S / 2 + PB, u, F + 0.003), 90
            sloc = (-S / 2 + SK, u, F + 0.003)
        rz = rz if w == "back" else 90
        out.append(piece(f"t_panel_{i}", itf.wall_panel, loc, rotz=rz, L=L))
        out.append(piece(f"t_skirt_{i}", itf.skirting, sloc, rotz=rz, L=L))
    out.append(piece("t_corner_skirt", itf.skirting_corner, (-S / 2 + 0.038, S / 2 - 0.038, F + 0.003), L=0.13))
    out.append(piece("t_sconce", itf.sconce, (-S / 2 + 0.003, 0.43, 1.75), rotz=90))
    out.append(piece("t_beam", itf.ceiling_beam, (0.003, 0.3, 0.18 + 2.2 - 0.003)))
    out.append(piece("t_pendant", itf.pendant, (0.4, 0.3, 0.18 + 2.2 - 0.2 - 0.003)))
    out.append(piece("t_radiator", itf.radiator, (-S / 2 + SK + 0.043, -0.573, F + 0.003), rotz=90))
    out.append(piece("t_divider", itf.room_divider, (0.55, -0.45, F + 0.003)))
    out.append(piece("t_bin", itf.waste_bin, (1.05, 1.05, F + 0.003)))
    out.append(piece("t_vent", itf.floor_vent, (-0.5, -0.95, F + 0.003)))
    # plain interior opening with the cream door frame
    b = c.Builder("t_iwall", seed=9)
    with b.at((0, -3.2, 0.0)):
        bk.masonry_wall(b, 2.4, H=2.2, openings=[(0, 1.02, 0, 1.68)], base=False)
    with b.at((-1.2 + bk.T / 2, -3.2 + bk.T / 2 + 0.6, 0), rotz=90):     # return wall -> inside corner for the shelf
        bk.masonry_wall(b, 1.2, H=2.2, base=False)
    out.append(b.finish(K, "test"))
    out.append(piece("t_frame", itf.door_frame, (0, -3.2, 0)))
    # corner shelf in the inside corner (room side is +Y of the wall, +X of the return)
    out.append(piece("t_shelf", itf.corner_shelf, (-1.2 + bk.T + 0.003, -3.2 + bk.T / 2 + 0.003, 0.95), rotz=90))
    check(out)
    return out


def shoot(objs, tag, views, close=None):
    c.ensure_shade()
    for nm, el, az, pad in views:
        c.render_preview(K, objs=objs, path=os.path.join(c.WIP, f"finishing_{tag}_{nm}.png"),
                         res=(1400, 1000), elev=el, azim=az, pad=pad)


if "ext" in shots or "keep" in shots:
    ex = exterior()
    if "ext" in shots:
        shoot(ex, "ext", [("az45", 55, 45, 1.05), ("az135", 55, 135, 1.05), ("az225", 55, 225, 1.05),
                          ("az315", 55, 315, 1.05), ("top", 89, 0, 1.05)])
        shoot([o for o in ex if o.name in ("cottage_exterior", "t_porch", "t_corner_l", "t_skirt_front")], "ext",
              [("close_porch", 75, -25, 0.9)])
        shoot([o for o in ex if o.name in ("cottage_exterior",) or o.name.startswith(("t_shutters", "t_sign", "t_eave", "t_snow"))],
              "ext", [("close_side", 72, 65, 0.8)])
        shoot([o for o in ex if o.name.startswith(("t_ridge", "t_end", "t_chimney"))], "ext", [("close_ridge", 60, 30, 1.0)])
        shoot([o for o in ex if o.name.startswith(("t_wall", "t_sill", "t_shutters2", "t_step"))], "ext", [("close_wall", 78, -20, 1.0)])
    if "keep" in shots:
        c.render_preview(K, objs=ex, path=os.path.join(c.DETAILS, "building_finishing_dressed.png"),
                         res=(1800, 1200), elev=40, azim=40, pad=1.02)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    c.ASSETS.clear()

if "int" in shots or "keep" in shots:
    it = interior()
    if "int" in shots:
        shoot(it, "int", [("az45", 50, 45, 1.05), ("az135", 50, 135, 1.05), ("az225", 50, 225, 1.05),
                          ("az315", 50, 315, 1.05), ("top", 89, 0, 1.05)])
        shoot([o for o in it if not o.name.startswith(("t_iwall", "t_frame"))], "int", [("close_room", 62, 25, 0.75)])
        shoot([o for o in it if o.name.startswith(("t_iwall", "t_frame"))], "int", [("close_frame", 78, -20, 1.0)])
    if "keep" in shots:
        c.render_preview(K, objs=[o for o in it if not o.name.startswith(("t_iwall", "t_frame"))],
                         path=os.path.join(c.DETAILS, "interior_finishing_dressed.png"),
                         res=(1800, 1200), elev=38, azim=30, pad=1.02)
