"""Verify activity animation kits.
  Blender -b --factory-startup --python art/blender/act_check.py -- [kit ...] [--no-render]
* loop seams (first frame == last frame)
* basketball: ball (r 0.12) never sinks into face/body (> 5 mm) or sleeves of raincoat / wizard_robe (> 15 mm grip)
* contact strips with the real prop GLBs -> common.WIP and common.DETAILS as <kit>_<clip>.png
"""
import sys, os, math, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import common
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KITS = [a for a in args if not a.startswith("--")] or ["anim_fishing", "anim_sledding", "anim_snowballs", "anim_basketball"]
render = "--no-render" not in args

common.reset_scene()
A = common.load_kit("avatar")
A.build()
common.ensure_shade()
import animlib as L
arm = bpy.data.objects["avatar_base"]
body = bpy.data.objects["avatar_base_mesh"]
for a in common.ASSETS:
    for o in common.hierarchy(a["obj"]):
        o.hide_render = True
clipinfo = {}
for k in KITS:
    L.CLIPS.clear()
    common.load_kit(k).clips(arm)
    for n, i in L.CLIPS.items():
        clipinfo[n] = (k, dict(i))
dg = lambda: bpy.context.evaluated_depsgraph_get()

# ---- props ----------------------------------------------------------------
_props = {}


def prop(asset):
    """Import a prop GLB once; returns a list of its mesh objects (joined under one empty)."""
    if asset not in _props:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(common.MODELS, asset + ".glb"))
        new = [o for o in bpy.data.objects if o not in before]
        root = next(o for o in new if o.parent is None)
        for o in new:
            o.hide_render = True
        _props[asset] = root
    return _props[asset]


def snap(o, mw=None):
    """Bake an object (and its mesh children) to a world-space mesh copy."""
    out = []
    for ob in common.hierarchy(o):
        if ob.type != "MESH":
            continue
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg()))
        me.transform((mw @ o.matrix_world.inverted() @ ob.matrix_world) if mw is not None else ob.matrix_world)
        c = bpy.data.objects.new("_s", me)
        c.hide_render = True
        bpy.context.scene.collection.objects.link(c)
        out.append(c)
    return out


def sock(name):
    return bpy.data.objects[name].matrix_world.copy()


def props_at(n, info, t):
    """World matrices of the props shown at time t."""
    out = []
    for p in info.get("props", []):
        vis = p.get("visible", [0, 1e9])
        if not (vis[0] - 1e-6 <= t <= vis[1] + 1e-6):
            continue
        if "socket" in p:
            out.append((p["asset"], sock(p["socket"])))
        else:  # sled: avatar origin = rider socket
            rider = Vector((0.0, 0.05, 0.215))
            out.append((p["asset"], Matrix.Translation(-rider)))
    pp = info.get("prop_path")
    if pp:
        s = min(pp["samples"], key=lambda q: abs(q[0] - t), default=None)
        if s and abs(s[0] - t) < 0.02:
            out.append((pp["asset"], Matrix.Translation((s[1], -s[3], s[2]))))
    return out


# ---- seams ----------------------------------------------------------------
for n, (k, i) in clipinfo.items():
    if not i["loop"]:
        continue
    def state(f):
        L.play(arm, n, f)
        return ([pb.matrix.copy() for pb in arm.pose.bones], [kb.value for kb in body.data.shape_keys.key_blocks[1:]])
    (m0, w0), (m1, w1) = state(0), state(i["frames"])
    dm = max(max(abs(a[r][c] - b[r][c]) for r in range(4) for c in range(4)) for a, b in zip(m0, m1))
    dw = max(abs(a - b) for a, b in zip(w0, w1))
    print(f"SEAM {n:18s} {'OK' if dm < 1e-4 and dw < 1e-4 else 'POP'} bone={dm:.1e} morph={dw:.1e}")

# ---- ball penetration -------------------------------------------------------
FLIP = {A.GROUPS.index("flipper.L"), A.GROUPS.index("flipper.R")}
outfits = {}
for w in ("raincoat", "wizard_robe"):
    o = bpy.data.objects[w + "_mesh"]
    o.modifiers["Armature"].object = arm
    outfits[w] = o


def bvh_of(me, keep):
    polys = [list(p.vertices) for p in me.polygons if keep(p)]
    return BVHTree.FromPolygons([v.co for v in me.vertices], polys) if polys else None


for n, (k, i) in clipinfo.items():
    pp = i.get("prop_path")
    if not pp:
        continue
    worst = {"face_body": (0.0, 0), "flipper": (0.0, 0), "raincoat": (0.0, 0), "wizard_robe": (0.0, 0)}
    for s in pp["samples"]:
        f = round(s[0] * L.FPS)
        if f % 2 and f != round(i["duration_s"] * L.FPS):
            continue
        L.play(arm, n, f)
        c = Vector((s[1], -s[3], s[2]))
        if c.z < 0.13:  # on the ground (pickup / dribble bounce)
            continue
        bs = snap(body)[0]
        fl = lambda p: all(any(g.group in FLIP and g.weight > 0.5 for g in bs.data.vertices[v].groups) for v in p.vertices)
        for key, tree in (("face_body", bvh_of(bs.data, lambda p: not fl(p))), ("flipper", bvh_of(bs.data, fl))):
            hit = tree.find_nearest(c) if tree else (None,)
            if hit[0] is not None:
                pen = 0.12 - hit[3]
                if pen > worst[key][0]:
                    worst[key] = (pen, f)
        bpy.data.objects.remove(bs, do_unlink=True)
        for w, o in outfits.items():
            os_ = snap(o)[0]
            hit = BVHTree.FromObject(os_, dg()).find_nearest(c)
            if hit[0] is not None and 0.12 - hit[3] > worst[w][0]:
                worst[w] = (0.12 - hit[3], f)
            bpy.data.objects.remove(os_, do_unlink=True)
    ok = worst["face_body"][0] <= 0.005 and max(worst[w][0] for w in ("raincoat", "wizard_robe")) <= 0.015
    print(f"BALL {n:16s} {'OK ' if ok else 'BAD'} " + " ".join(f"{a}={v[0] * 1000:.0f}mm@f{v[1]}" for a, v in worst.items()))

# ---- strips -------------------------------------------------------------------
if render:
    for n, (k, i) in clipinfo.items():
        N = 7
        frames = sorted({round(j * i["frames"] / (N if i["loop"] else N - 1)) for j in range(N)}) if i["frames"] else [0]
        objs = []
        gap = 1.5 if k == "anim_sledding" else (1.25 if k == "anim_fishing" else 1.05)
        for j, f in enumerate(frames):
            L.play(arm, n, f)
            off = Matrix.Translation((j * gap, 0, 0))
            parts = snap(body)
            for asset, mw in props_at(n, i, f / L.FPS):
                parts += snap(prop(asset), mw)
            for o in parts:
                o.matrix_world = off @ o.matrix_world
                o.hide_render = False
            objs += parts
        L.stop(arm)
        path = os.path.join(common.WIP, f"{k}_{n}.png")
        common.render_preview(k, objs=objs, path=path, elev=78, azim=28, res=(2400, 440), pad=1.04)
        shutil.copy(path, os.path.join(common.DETAILS, f"{k}_{n}.png"))
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    print("STRIPS", len(clipinfo))
