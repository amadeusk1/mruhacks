"""Standalone ground preview: terrain + path ribbons from ground_dev, no props.
  Blender -b --factory-startup --python art/blender/world/preview_ground.py -- [module=ground_dev] [shots]
Renders art/_wip/ground_<shot>.png."""
import sys, os, math, time, importlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [os.path.dirname(HERE), HERE]
import bpy
from mathutils import Vector
import common
import town
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
modname = next((a.split("=")[1] for a in args if a.startswith("module=")), "ground_dev")
G = importlib.import_module(modname)
common.reset_scene()
t0 = time.time()
G.setup(town.PATHS, town._height, town.stream_d, town.STREAM_W, (town.PLAZA_C, town.PLAZA_R),
        town.BRIDGES, town.island_d, town.on_beach)
_c = {}
def hf(p):
    k = (round(p.x, 3), round(p.y, 3))
    if k not in _c:
        _c[k] = G.flatten(p, town._height(p))
    return _c[k]
assert G.selfcheck()
t = G.terrain_mesh(common.Builder("town_terrain", seed=11), hf).finish("world", "terrain")
p = G.paths_mesh(common.Builder("terrain_paths", seed=12), town.PATHS, (town.PLAZA_C, town.PLAZA_R), hf).finish("world", "terrain")
w = town.build_water().finish("world", "terrain")
tris = sum(len(o.data.polygons) for o in (t, p))
print(f"GROUND built in {time.time() - t0:.1f}s, polys terrain={len(t.data.polygons)} paths={len(p.data.polygons)}")
common.ensure_shade()
common.setup_render((1600, 1000))
sc = bpy.context.scene
g = bpy.data.objects.get("_ground")
if g:
    g.hide_render = True
bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = common.hex_rgb("#BFE6F0") + [1]
bg.inputs["Strength"].default_value = 0.55
sun = bpy.data.objects["_sun"]
sun.data.energy = 3.6
sun.rotation_euler = (math.radians(48), 0, math.radians(-145))
try:
    sc.view_settings.view_transform = "Filmic"
except TypeError:
    pass
cam = bpy.data.objects.new("_c", bpy.data.cameras.new("_c")); sc.collection.objects.link(cam); sc.camera = cam
shots = {"plaza": ((0, -15, 14), (0, 0, 0), 40), "bridge": ((13.3, -11, 10), (13.3, 0, 0), 38),
         "homes": ((-23.5, -12, 12), (-23.5, 0, 0), 40), "junction": ((-12, -10, 10), (-11.4, -11.7, 0), 40),
         "top": ((0, 0, 120), (0, 0.01, 0), 45)}
want = [a for a in args if a in shots] or list(shots)
out = os.path.join(common.ART, "_wip")
for name in want:
    loc, tgt, fov = shots[name]
    cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle = math.radians(fov); cam.data.clip_end = 400
    sc.render.filepath = os.path.join(out, f"ground_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("SHOT", name)
