"""Load kits into the open (live) Blender for viewing; no export, no render.
In Blender: exec(open(".../art/blender/showcase.py").read()); show(["plaza", "cafe"])
"""
import sys, os, importlib
_dir = "/Users/nick/Documents/club penguin hackathon/art/blender"
if _dir not in sys.path:
    sys.path.insert(0, _dir)
import bpy
import common
importlib.reload(common)


def show(kits, cols=4, gap=4.0, width=16.0, clear=True, labels=True):
    """Build kits into the live scene as a grid of labelled blocks, one collection per kit."""
    if clear:
        common.reset_scene()
        for c in [c for c in bpy.data.curves if c.name.startswith("label_")]:
            bpy.data.curves.remove(c)
    x0 = y0 = row_h = 0.0
    for i, kit in enumerate(kits):
        if i and i % cols == 0:
            x0, y0, row_h = 0.0, y0 + row_h + gap, 0.0
        mod = common.load_kit(kit)
        mod.build()
        common.ensure_shade()
        common.layout_kit(kit, max_w=max(width, getattr(mod, "PREVIEW_WIDTH", width)), origin=(x0, y0))
        his = [common.bbox(a["obj"])[1].y for a in common.roots_of(kit)]
        row_h = max(row_h, (max(his) - y0) if his else 0)
        if labels:
            cu = bpy.data.curves.new(f"label_{kit}", "FONT")
            cu.body = kit.replace("_", " ").upper()
            cu.size = 0.9
            t = bpy.data.objects.new(f"label_{kit}", cu)
            t.location = (x0, y0 - 1.6, 0.01)
            common.kit_collection(kit).objects.link(t)
        his_x = [common.bbox(a["obj"])[1].x for a in common.roots_of(kit)]
        x0 = max(x0 + width, max(his_x) if his_x else x0) + gap
    frame([a["obj"] for a in common.ASSETS])
    return [a["obj"].name for a in common.ASSETS]


def frame(objs, elev=48, azim=35, zoom=1.0):
    """Point the user's 3D viewport at objs from a three-quarter angle, material shading."""
    import math
    from mathutils import Vector, Euler
    boxes = [common.bbox(o) for o in objs]
    lo = Vector([min(b[0][i] for b in boxes) for i in range(3)])
    hi = Vector([max(b[1][i] for b in boxes) for i in range(3)])
    if not bpy.context.window_manager.windows:
        return  # headless
    for a in bpy.context.window_manager.windows[0].screen.areas:
        if a.type == "VIEW_3D":
            sp = a.spaces[0]
            sp.shading.type = "MATERIAL"
            sp.overlay.show_floor = sp.overlay.show_axis_x = sp.overlay.show_axis_y = False
            r3 = sp.region_3d
            r3.view_perspective = "PERSP"
            r3.view_rotation = Euler((math.radians(elev), 0, math.radians(azim))).to_quaternion()
            r3.view_location = (lo + hi) / 2
            r3.view_distance = (hi - lo).length * zoom
