"""Seam test: assemble a small network from town_connections + the world_misc footbridge and render it.
  Blender -b --factory-startup --python art/blender/preview_town_connections.py [-- keep]
'keep' also writes the keeper to Renders/Details/town_connections_network.png."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import common

common.reset_scene()
common.load_kit("town_connections").build()
common.load_kit("world_misc").build()
src = {a["obj"].name: a["obj"] for a in common.ASSETS}
used = set()
placed = []


def inst(name, x, y, z=0.0, rz=0.0):
    """Place a copy of an asset (with its child parts) at (x, y, z), rotated rz degrees."""
    def cp(o, parent=None):
        c = o.copy()
        bpy.context.scene.collection.objects.link(c)
        if parent:
            c.parent = parent
        for ch in o.children:
            if ch.type == "MESH":
                cp(ch, c)
        return c
    root = cp(src[name])
    root.location = (x, y, z)
    root.rotation_euler = (0, 0, math.radians(rz))
    placed.append(root)
    used.add(name)
    return root


# main path along Y with a T junction
for y in (-4, -2, 0):
    inst("straight_path_tile", 0, y); inst("snow_overlay_straight_path", 0, y)
inst("path_end", 0, -6, rz=180); inst("snow_overlay_path_end", 0, -6, rz=180)
inst("path_junction_t", 0, 2); inst("snow_overlay_path_junction_t", 0, 2)
# step-up north of the junction: 1 m flight then a landing (top +0.5)
inst("stone_step", 0, 3.5)
inst("landing", 0, 5)
inst("cliff_straight_1m", 0, 7.0, z=-0.5)       # upper tier wall behind the landing, top flush at 0.5
inst("cliff_cap", 0, 7.0, z=0.5); inst("snow_overlay_cliff_straight", 0, 7.0, z=0.5)
for x in (-2, 2):
    inst("cliff_straight_2m", x, 5.0, rz=0, z=-1.5)
inst("cliff_corner_outer", 3.5, 5.0, z=-1.5, rz=90)   # wraps the plateau's east end
inst("snow_overlay_cliff_corner_outer", 3.5, 5.0, z=0.5, rz=90)
for x in (-2, 2):
    inst("snow_overlay_cliff_straight", x, 5.0, z=0.5)
# east arm -> path -> approach -> footbridge -> approach -> path
inst("straight_path_tile", 2, 2, rz=90)
inst("footbridge_approach_landing", 4, 2, rz=180)
bx = 5 + 2.4
inst("footbridge", bx, 2)
inst("footbridge_approach_landing", bx + 2.4 + 1, 2)
inst("straight_path_tile", bx + 2.4 + 3, 2, rz=90)
# stream under the bridge, bending east at the south end
for y in (2, 4, 6):
    inst("stream_straight", bx, y)
inst("stream_bend", bx, 0, rz=90)
inst("stream_end", bx, 8, rz=180)
# rails along the west side of the main path
for y in (-5, -3, -1):
    inst("rail_segment", -1.1, y, rz=90)
inst("rail_end_post", -1.1, 1.0)

for o in list(src.values()):  # drop the unplaced originals with their child parts
    for h in common.hierarchy(o):
        bpy.data.objects.remove(h, do_unlink=True)
for o in list(bpy.data.objects):
    if o.type == "EMPTY":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.context.view_layer.update()
common.ASSETS[:] = [{"obj": o, "kit": "_net", "category": "", "meta": {}} for o in placed]
keep = "keep" in sys.argv
common.setup_render()
bpy.data.objects["_ground"].location.z = -1.6  # streams and sunk cliffs sit below z=0
common.render_preview("_net", objs=placed, path=os.path.join(common.WIP, "tc_net_top.png"), res=(1600, 1200), elev=0.01, azim=0)
common.render_preview("_net", objs=placed, path=os.path.join(common.DETAILS if keep else common.WIP, "town_connections_network.png"),
                      res=(1800, 1200), elev=55, azim=35)
print("NET OK", len(placed))
