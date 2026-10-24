"""Avatar review renders: hats, outfits and accessories worn on body copies.
  Blender -b --factory-startup --python art/blender/preview_avatar.py -- [base|hats|wardrobe|acc|poses] ...
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import common
from mathutils import Vector

shots = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["base", "hats", "wardrobe", "acc"]
common.reset_scene()
A = common.load_kit("avatar")
A.build()
obj = {a["obj"].name: a["obj"] for a in common.ASSETS}
body_mesh = bpy.data.objects["avatar_base_mesh"]
coll = bpy.data.collections.new("_review")
bpy.context.scene.collection.children.link(coll)


def copy(o, loc, rz=0.0):
    c = o.copy()
    c.data = o.data
    c.parent = None
    c.modifiers.clear()
    c.hide_render = False
    c.location = loc
    c.rotation_euler = (0, 0, math.radians(rz))
    coll.objects.link(c)
    return c


def hide_kit():
    for a in common.ASSETS:
        for o in common.hierarchy(a["obj"]):
            o.hide_render = True


def shot(name, objs, **kw):
    bpy.context.view_layer.update()
    common.render_preview("avatar", objs=objs, path=os.path.join(common.DETAILS, f"avatar_{name}.png"), **kw)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)


hide_kit()
for s in shots:
    if s == "base":
        objs = [copy(body_mesh, (i * 1.0, 0, 0), rz) for i, rz in enumerate((0, 90, 180, 35))]
        shot("base", objs, elev=80, azim=0, res=(1800, 700))
    elif s == "face":
        objs = [copy(body_mesh, (i * 0.8, 0, 0), rz) for i, rz in enumerate((0, 30))]
        common.render_preview("avatar", objs=objs, path=os.path.join(common.WIP, "avatar_face.png"), elev=88, azim=0,
                              res=(1600, 900), pad=1.05)
        for o in list(coll.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    elif s == "hats":
        objs = []
        for i, h in enumerate(["red_beanie", "frog_hood", "explorer_hat", "wizard_hat", "bucket_hat", "headphones"]):
            objs += [copy(body_mesh, (i * 1.05, 0, 0), 20), copy(obj[h], (i * 1.05, 0, 0.72), 20)]
        shot("hats", objs, elev=78, azim=0, res=(2000, 600))
    elif s == "wardrobe":
        objs = []
        for i, w in enumerate(["hoodie", "varsity_jacket", "raincoat", "overalls", "striped_tee", "puffer_vest",
                               "cafe_apron", "wizard_robe"]):
            for j, rz in enumerate((20, 160)):
                p = (i * 1.0, j * 3.2, 0)
                objs += [copy(body_mesh, p, rz), copy(bpy.data.objects[w + "_mesh"], p, rz)]
        shot("wardrobe", objs, elev=72, azim=0, res=(2200, 1300))
    elif s == "acc":
        objs = []
        for i, (a, sock, rz) in enumerate([("backpack", "back", 150), ("rolltop_backpack", "back", 150),
                                           ("crossbody_bag", "back", 20), ("glasses", "face", 20), ("scarf", "neck", 20),
                                           ("mug", "hand_R", 20), ("fishing_rod", "hand_R", 60),
                                           ("watering_can", "hand_R", 20), ("wand", "hand_R", 20)]):
            base = Vector((i * 1.1, 0, 0))
            body = copy(body_mesh, base, rz)
            item = copy(obj[a], base, rz)
            item.location = base + (body.matrix_basis.to_3x3() @ Vector(A.SOCKETS[sock][1]))
            objs += [body, item]
        shot("acc", objs, elev=75, azim=0, res=(2200, 700))
    elif s == "morphs":
        keys = body_mesh.data.shape_keys.key_blocks
        objs = []
        for i, nm in enumerate(["Basis"] + A.MORPHS + ["happy+open+blush"]):
            for kb in keys[1:]:
                kb.value = 1.0 if (kb.name == nm or (nm.startswith("happy") and kb.name in ("eyes_happy", "beak_open", "blush"))) else 0.0
            me = bpy.data.meshes.new_from_object(body_mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()))
            o = bpy.data.objects.new(f"_m_{nm}", me)
            coll.objects.link(o)
            o.location = (i * 0.75, 0, 0)
            objs.append(o)
        for kb in keys[1:]:
            kb.value = 0.0
        common.render_preview("avatar", objs=objs, path=os.path.join(common.DETAILS, "avatar_morphs.png"), elev=88,
                              azim=0, res=(2600, 480), pad=1.06)
        for o in list(coll.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    elif s == "poses":
        arm = obj["avatar_base"]
        A.build_actions(arm)
        for o in common.hierarchy(arm):
            o.hide_render = False
        acts = {a.name: a for a in bpy.data.actions}
        for nm, fr in (("idle", 24), ("waddle", 0), ("sit", 0), ("wave", 8)):
            arm.animation_data.action = acts[nm]
            if hasattr(arm.animation_data, "action_slot") and acts[nm].slots:
                arm.animation_data.action_slot = acts[nm].slots[0]
            bpy.context.scene.frame_set(fr)
            common.render_preview("avatar", objs=[arm], path=os.path.join(common.DETAILS, f"avatar_pose_{nm}.png"),
                                  elev=80, azim=20, res=(700, 700), pad=1.4)
