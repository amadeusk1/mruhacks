"""Clipping check for worn avatar items.
  Blender -b --factory-startup --python art/blender/clip_avatar.py -- [--no-render] [item ...]
For each worn item and pose extreme it counts body vertices that end up OUTSIDE a covering
surface: the ray along the vertex normal finds nothing within 15 cm, but the ray inward hits the
item within 4 cm. It writes one sheet per item to common.WIP: front, back, side and 3/4 at rest,
then waddle (both extremes), sit and wave.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import common
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
render = "--no-render" not in args
only = [a for a in args if not a.startswith("--")]

common.reset_scene()
A = common.load_kit("avatar")
A.build()
common.ensure_shade()
arm = bpy.data.objects["avatar_base"]
A.build_actions(arm)  # the old test loops (idle/waddle/sit/wave) are still good extreme poses
body = bpy.data.objects["avatar_base_mesh"]
acts = {a.name: a for a in bpy.data.actions}
POSES = [("rest", None, 0), ("waddle_a", "waddle", 0), ("waddle_b", "waddle", 12), ("sit", "sit", 0),
         ("wave", "wave", 8), ("idle", "idle", 24)]
WARDROBE = ["hoodie", "varsity_jacket", "raincoat", "overalls", "striped_tee", "puffer_vest", "cafe_apron", "wizard_robe"]
RIGID = {"red_beanie": "head", "frog_hood": "head", "explorer_hat": "head", "wizard_hat": "head", "bucket_hat": "head",
         "headphones": "head", "backpack": "back", "rolltop_backpack": "back", "crossbody_bag": "back",
         "glasses": "face", "scarf": "neck", "mug": "hand_R", "fishing_rod": "hand_R", "watering_can": "hand_R", "wand": "hand_R"}
dg = bpy.context.evaluated_depsgraph_get()
for a in common.ASSETS:
    for o in common.hierarchy(a["obj"]):
        o.hide_render = True
for n in WARDROBE:
    bpy.data.objects[n + "_mesh"].modifiers["Armature"].object = arm   # drive clothes with the avatar rig


def set_pose(act, fr):
    ad = arm.animation_data
    ad.action = acts[act] if act else None
    if act and hasattr(ad, "action_slot") and acts[act].slots:
        ad.action_slot = acts[act].slots[0]
    if not act:
        for pb in arm.pose.bones:
            pb.rotation_quaternion, pb.location = (1, 0, 0, 0), (0, 0, 0)
    bpy.context.scene.frame_set(fr)
    bpy.context.view_layer.update()


def place_rigid(name):
    bone, loc = A.SOCKETS[RIGID[name]]
    pb = arm.pose.bones[bone]
    d = arm.matrix_world @ pb.matrix @ pb.bone.matrix_local.inverted()
    o = bpy.data.objects[name]
    o.matrix_world = d @ Matrix.Translation(loc)
    bpy.context.view_layer.update()
    return o


def snapshot(o, tag):
    ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = bpy.data.meshes.new_from_object(ev)
    me.transform(o.matrix_world)
    c = bpy.data.objects.new(f"_snap_{o.name}_{tag}", me)
    c.hide_render = True  # only the placed copies in views() render
    bpy.context.scene.collection.objects.link(c)
    return c


def bvh(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    t = BVHTree.FromBMesh(bm)
    bm.free()
    return t


DIAG = "--diag" in args


FLIP = {A.GROUPS.index("flipper.L"), A.GROUPS.index("flipper.R")}


def flipper_verts(me):
    return {v.index for v in me.vertices if any(g.group in FLIP and g.weight > 0.5 for g in v.groups)}


def sub_bvh(me, keep):
    polys = [list(p.vertices) for p in me.polygons if keep(p)]
    return BVHTree.FromPolygons([v.co for v in me.vertices], polys) if polys else None


def pokes(body_snap, item_snap):
    """Flipper vertices are only tested against the item's sleeves, because a bare flipper lying
    over a jacket is correct layering. Every other body vertex is tested against the whole item."""
    t_full = bvh(item_snap)
    im = item_snap.data
    ifl = flipper_verts(im)
    t_sleeve = sub_bvh(im, lambda p: all(i in ifl for i in p.vertices))
    me = body_snap.data
    bfl = flipper_verts(me)
    n = 0
    for v in me.vertices:
        t = t_full if v.index not in bfl else t_sleeve
        if t is None:
            continue
        p, nr = v.co, v.normal
        hit = t.ray_cast(p - nr * 0.0005, -nr, 0.04)
        if t.ray_cast(p + nr * 0.0005, nr, 0.15)[0] is None and hit[0] is not None:
            n += 1
            if DIAG:
                mi = item_snap.data.polygons[hit[2]].material_index
                m = item_snap.data.materials[mi].name if item_snap.data.materials else "?"
                phi = math.degrees(math.atan2(p.x, -p.y))
                print(f"  POKE z={p.z:.3f} phi={phi:6.1f} depth={hit[3]:.3f} mat={m} flipper={v.index in bfl} x={p.x:.3f} y={p.y:.3f}")
    return n


def views(objs, i, rz, x):
    out = []
    for o in objs:
        c = o.copy()
        c.data = o.data
        c.hide_render = False
        c.matrix_world = Matrix.Translation((x, 0, 0)) @ Matrix.Rotation(math.radians(rz), 4, "Z") @ o.matrix_world
        bpy.context.scene.collection.objects.link(c)
        out.append(c)
    return out


report = {}
for name in (only or WARDROBE + list(RIGID)):
    snaps, row = [], []
    report[name] = {}
    for tag, act, fr in POSES:
        set_pose(act, fr)
        item = place_rigid(name) if name in RIGID else bpy.data.objects[name + "_mesh"]
        bs, its = snapshot(body, tag), snapshot(item, tag)
        report[name][tag] = pokes(bs, its)
        snaps.append((tag, bs, its))
    if render:
        x = 0.0
        for tag, bs, its in snaps:
            for rz in ((0, 180, 90, 40) if tag == "rest" else ((35,) if tag != "idle" else ())):
                row += views([bs, its], 0, rz, x)
                x += 1.15
        common.render_preview("avatar", objs=row, path=os.path.join(common.WIP, f"avatar_clip_{name}.png"),
                              elev=80, azim=0, res=(2600, 420), pad=1.05)
    for o in row + [s for _, a, b in snaps for s in (a, b)]:
        bpy.data.objects.remove(o, do_unlink=True)
    print("CLIP", f"{name:18s}", " ".join(f"{k}={v}" for k, v in report[name].items()))
