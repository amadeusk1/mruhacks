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
try:                                              # real town terrain around the hill (coast, cliffs) when available
    import town
    importlib.reload(town)
    terrain_h = town.height
    half = half + Vector((5.0, 5.0))
except Exception as e:
    print("TOWN unavailable, flat base:", repr(e)[:120])
    terrain_h = lambda p: sh.height(p, 0.0)
b = common.Builder("hill_patch")
b.skip_zfix = True
step = 0.5
nx, ny = int(2 * half.x / step), int(2 * half.y / step)
verts, faces, idx = [], [], {}
for i in range(nx + 1):
    for j in range(ny + 1):
        p = Vector((c.x - half.x + i * step, c.y - half.y + j * step))
        idx[i, j] = len(verts)
        verts.append((p.x, p.y, terrain_h(p)))
groups = {}
for i in range(nx):
    for j in range(ny):
        f = [idx[i, j], idx[i + 1, j], idx[i + 1, j + 1], idx[i, j + 1]]
        a, b2, c2 = (Vector(verts[k]) for k in f[:3])
        nz = abs((b2 - a).cross(c2 - a).normalized().z)
        groups.setdefault(common.tint("rock", "#9AA1A8") if nz < 0.55 else common.tint("snow_shade", "#CFDCE7") if nz < 0.86 else common.tint("snow", "#F2F6F9"), []).append(f)
for m, fs in groups.items():
    b.mesh(verts, fs, mat=m)
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
wb = common.Builder("water_plane")
wb.skip_zfix = True
wb.box(200, 200, 0.02, c.x, c.y, -0.52, common.tint("water", "#1E9FC2"), bevel=0)
wb.finish("_sled", "terrain")
common.ensure_shade()

common.setup_render((1600, 1000))
g = bpy.data.objects.get("_ground")
if g:
    g.hide_render = True                          # real terrain + water plane replace the cream preview ground
sc = bpy.context.scene
w = sc.world
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = common.hex_rgb("#BFE6F0") + [1]
bg.inputs["Strength"].default_value = 0.4
sc.view_settings.view_transform = "Standard"
try:
    sc.view_settings.look = "Medium High Contrast"
except TypeError:
    pass
sun = bpy.data.objects["_sun"]
sun.data.energy = 2.6
sun.data.color = common.hex_rgb("#FFF0D8")
sun.rotation_euler = (math.radians(46), 0, math.radians(-38))   # matches the game sun (layout "sun")
cam = bpy.data.objects.new("_c", bpy.data.cameras.new("_c"))
sc.collection.objects.link(cam)
sc.camera = cam
def orbit(tgt, pitch, dist, yaw=0.0):
    a, y = math.radians(pitch), math.radians(yaw)
    return (tgt[0] + math.sin(y) * dist * math.cos(a), tgt[1] - math.cos(y) * dist * math.cos(a), tgt[2] + dist * math.sin(a))


views = {"game": (orbit((-20.0, 24.0, 3.0), 50, 22), (-20.0, 24.0, 3.0), 40),
         "game_start": (orbit((-14.0, 30.0, 6.0), 50, 18), (-14.0, 30.0, 6.0), 40),
         "concept": (orbit((-22.5, 24.0, 2.0), 55, 52, 10), (-22.5, 24.0, 2.0), 42),
         "overview": ((-21.0, 0.0, 44.0), (-21.0, 24.5, 0.0), 42)}
for name, (loc, tgt, fov) in views.items():
    cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle = math.radians(fov)
    cam.data.clip_end = 300
    sc.render.filepath = os.path.join(OUT, f"sled_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("SHOT", sc.render.filepath)
