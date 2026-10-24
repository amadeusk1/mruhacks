"""Standalone sled-hill preview: hill terrain patch + track ribbon + placements, rendered from the
gameplay angle and an overview into art/_wip/sled_<view>.png.
  Blender -b --factory-startup --python art/blender/world/preview_sled.py -- [module=sled_hill_dev]
"""
import sys, os, math, importlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE)); sys.path.insert(0, HERE)
import bpy
from mathutils import Vector
import common

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
modname = next((a.split("=", 1)[1] for a in args if a.startswith("module=")), "sled_hill_dev")
sh = importlib.import_module(modname)
OUT = os.path.join(common.ART, "_wip")
common.reset_scene()

# terrain patch (0.5 m faceted grid, snow), flat town ground outside the hill
c, half = sh.REGION
b = common.Builder("hill_patch")
b.skip_zfix = True
step = 0.5
nx, ny = int(2 * half.x / step), int(2 * half.y / step)
verts, faces, idx = [], [], {}
for i in range(nx + 1):
    for j in range(ny + 1):
        p = Vector((c.x - half.x + i * step, c.y - half.y + j * step))
        idx[i, j] = len(verts)
        verts.append((p.x, p.y, sh.height(p, 0.0)))
for i in range(nx):
    for j in range(ny):
        faces.append([idx[i, j], idx[i + 1, j], idx[i + 1, j + 1], idx[i, j + 1]])
b.mesh(verts, faces, mat=common.tint("snow", "#E8EFF4"))
b.finish("_sled", "terrain")
t = common.Builder("terrain_sled_track")
t.skip_zfix = True
sh.track_mesh(t, common.tint)
t.finish("_sled", "terrain")

# placements: import each GLB once, then linked copies
M = common.MODELS
src = {}


def imp(asset):
    if asset in src:
        return src[asset]
    f = os.path.join(M, asset + ".glb")
    if not os.path.exists(f):
        src[asset] = None
        print("MISSING", asset)
        return None
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        o.hide_render = True
    src[asset] = [o for o in new if o.parent is None]
    return src[asset]


def dup(o, parent=None):
    d = o.copy()
    bpy.context.scene.collection.objects.link(d)
    d.hide_render = False
    d.parent = parent
    for ch in o.children:
        dup(ch, d)
    return d


for pl in sh.placements():
    roots = imp(pl.get("id") or pl.get("asset"))
    for r in roots or []:
        d = dup(r)
        d.location = (pl["x"], pl["y"], pl["z"])
        d.rotation_mode = "XYZ"
        d.rotation_euler = (0, 0, math.radians(pl["yaw"]))
        d.scale = (pl["scale"],) * 3
common.ensure_shade()

common.setup_render((1600, 1000))
g = bpy.data.objects.get("_ground")
if g:
    g.location.z = -0.02
sc = bpy.context.scene
w = sc.world
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = common.hex_rgb("#BFE6F0") + [1]
sun = bpy.data.objects["_sun"]
sun.data.energy = 4.0
sun.rotation_euler = (math.radians(46), 0, math.radians(-38))   # matches the game sun (layout "sun")
cam = bpy.data.objects.new("_c", bpy.data.cameras.new("_c"))
sc.collection.objects.link(cam)
sc.camera = cam
views = {"gameplay": ((-6.0, 6.0, 22.0), (-20.0, 24.0, 2.5), 46),     # like the concept sheet: from the SE, looking up the hill
         "overview": ((-21.0, 0.0, 44.0), (-21.0, 24.5, 0.0), 42),
         "track": ((-36.0, 12.0, 14.0), (-22.0, 25.0, 3.0), 52)}
for name, (loc, tgt, fov) in views.items():
    cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle = math.radians(fov)
    cam.data.clip_end = 300
    sc.render.filepath = os.path.join(OUT, f"sled_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("SHOT", sc.render.filepath)
