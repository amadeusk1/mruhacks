"""Build the town: export terrain GLB + layout JSON, then place every asset in Blender
and render previews from the concept camera.
  Blender -b --factory-startup --python art/blender/world/build_town.py -- [--no-preview] [--save]
"""
import sys, os, math, importlib, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)
import bpy
from mathutils import Vector
import common
import town
importlib.reload(town)

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.join(common.MODELS, "world")
os.makedirs(OUT, exist_ok=True)

# 1. terrain asset + layout data
common.reset_scene()
town.build()
common.ensure_shade()
common.export_kit("world")
data = town.write_layout(os.path.join(OUT, "town_layout.json"))
print(f"TOWN placements={len(data['placements'])} markers={len(data['markers'])}")

if "--no-preview" not in args:
    # 2. place linked copies of every referenced asset
    kits = sorted({p["id"].split("/")[0] for p in town.PLACE})
    src = {}
    for k in kits:
        mod = common.load_kit(k)
        before = len(common.ASSETS)
        mod.build()
        for a in common.ASSETS[before:]:
            src[f"{k}/{a['obj'].name}"] = a["obj"]
    common.ensure_shade()
    coll = bpy.data.collections.new("town_layout")
    bpy.context.scene.collection.children.link(coll)
    for a in common.ASSETS:
        if a["kit"] != "world":
            for o in common.hierarchy(a["obj"]):
                o.hide_render = True
                o.hide_set(True) if bpy.context.view_layer.objects.get(o.name) else None
    missing = set()

    def clone(o, parent=None):
        c = o.copy()
        if o.data is not None:
            c.data = o.data
        c.animation_data_clear() if c.animation_data else None
        coll.objects.link(c)
        c.hide_render = False
        c.parent = parent
        if parent is not None:
            c.matrix_parent_inverse = o.matrix_parent_inverse.copy()
        for ch in o.children:
            clone(ch, c)
        return c
    for p in town.PLACE:
        o = src.get(p["id"])
        if o is None:
            missing.add(p["id"])
            continue
        c = clone(o)
        c.location = p["pos"]
        c.rotation_euler = (0, 0, math.radians(p["yaw"]))
        c.scale = (p["scale"],) * 3
    if missing:
        print("MISSING", sorted(missing))
    # 3. previews
    common.setup_render((1920, 1280))
    sc = bpy.context.scene
    g = bpy.data.objects.get("_ground")
    if g:
        g.hide_render = True
    w = sc.world
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = common.hex_rgb("#BFE6F0") + [1]
    bg.inputs["Strength"].default_value = 0.75
    sun = bpy.data.objects["_sun"]
    sun.data.energy = 4.2
    sun.data.color = common.hex_rgb("#FFE6BE")
    sun.rotation_euler = (math.radians(48), 0, math.radians(-145))
    cam = bpy.data.objects.new("_town_cam", bpy.data.cameras.new("_town_cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    shots = {"town_overview": ((0, -64, 62), (0, 4, 0), 42),
             "town_plaza": ((10, -24, 20), (0, 4, 1), 38),
             "town_dock_court": ((-2, -40, 20), (0, -16, 0), 40),
             "town_hill_arena": ((0, -6, 34), (-4, 22, 2), 45)}
    only = [a for a in args if a.startswith("shot=")]
    for name, (loc, tgt, lens_fov) in shots.items():
        if only and f"shot={name}" not in only:
            continue
        cam.location = loc
        d = Vector(tgt) - Vector(loc)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam.data.angle = math.radians(lens_fov)
        cam.data.clip_end = 400
        path = os.path.join(common.DETAILS, f"{name}.png")
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        if name == "town_overview":
            import shutil
            shutil.copy(path, os.path.join(OUT, "town_preview.png"))
        print("SHOT", path)
    if "--save" in args:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "town.blend"), compress=True)
