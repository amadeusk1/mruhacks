"""Verify the animation kits.
  Blender -b --factory-startup --python art/blender/anim_check.py -- [kit ...] [--no-render]
* loop seams: the first and last frames of every loop match (bone matrices and morph weights)
* foot contacts: during stance in walk and run, foot world position drift with gameplay travel at speed_mps
* outfit clipping across every frame of run, hop, emote_cheer and emote_dance (wizard_robe, puffer_vest, frog_hood, backpack)
* contact strips per clip -> common.WIP/anim_<kit>_<clip>.png, copied to common.DETAILS
"""
import sys, os, math, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import common
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KITS = [a for a in args if not a.startswith("--")] or ["anim_locomotion", "anim_emotes", "anim_social"]
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
        clipinfo[n] = (k, i)
dg = lambda: bpy.context.evaluated_depsgraph_get()

# ---- loop seams ---------------------------------------------------------------
for n, (k, i) in clipinfo.items():
    if not i["loop"]:
        continue
    def state(f):
        L.play(arm, n, f)
        return ([pb.matrix.copy() for pb in arm.pose.bones], [kb.value for kb in body.data.shape_keys.key_blocks[1:]])
    (m0, w0), (m1, w1) = state(0), state(i["frames"])
    dm = max(max(abs(a[r][c] - b[r][c]) for r in range(4) for c in range(4)) for a, b in zip(m0, m1))
    dw = max(abs(a - b) for a, b in zip(w0, w1))
    print(f"SEAM {n:22s} bone_delta={dm:.2e} morph_delta={dw:.2e} {'OK' if dm < 1e-4 and dw < 1e-4 else 'POP'}")

# ---- foot contacts --------------------------------------------------------------
for n in ("walk", "run"):
    if n not in clipinfo:
        continue
    i = clipinfo[n][1]
    v = i["speed_mps"]
    worst = 0.0
    for fb in ("foot.L", "foot.R"):
        prev = None
        for f in range(i["frames"] + 1):
            L.play(arm, n, f)
            pb = arm.pose.bones[fb]
            w = arm.matrix_world @ pb.head + Vector((0, -v * f / L.FPS, 0))
            rest_z = (arm.matrix_world @ pb.bone.head_local).z
            planted = abs(w.z - rest_z) < 1e-4
            if planted and prev is not None:
                worst = max(worst, (w.xy - prev.xy).length)
            prev = w if planted else None
    print(f"FEET {n:6s} speed={v:.3f} m/s  max planted-foot slip per frame = {worst * 1000:.3f} mm")

# ---- outfit clipping ------------------------------------------------------------
WIDE = {"wizard_robe": None, "puffer_vest": None, "frog_hood": "head", "backpack": "back"}
for w, sock in WIDE.items():
    if sock is None:
        bpy.data.objects[w + "_mesh"].modifiers["Armature"].object = arm
FLIP = {A.GROUPS.index("flipper.L"), A.GROUPS.index("flipper.R")}


def snap(o):
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg()))
    me.transform(o.matrix_world)
    c = bpy.data.objects.new("_s", me)
    c.hide_render = True
    bpy.context.scene.collection.objects.link(c)
    return c


def flv(me):
    return {v.index for v in me.vertices if any(g.group in FLIP and g.weight > 0.5 for g in v.groups)}


def pokes(bs, it):
    bm = bmesh.new(); bm.from_mesh(it.data); full = BVHTree.FromBMesh(bm); bm.free()
    ifl = flv(it.data)
    sp = [list(p.vertices) for p in it.data.polygons if all(i in ifl for i in p.vertices)]
    sleeve = BVHTree.FromPolygons([v.co for v in it.data.vertices], sp) if sp else None
    bfl = flv(bs.data)
    n = 0
    where = []
    for v in bs.data.vertices:
        t = sleeve if v.index in bfl else full
        if t is None:
            continue
        p, nr = v.co, v.normal
        h = t.ray_cast(p - nr * 5e-4, -nr, 0.04)
        if t.ray_cast(p + nr * 5e-4, nr, 0.15)[0] is None and h[0] is not None:
            n += 1
            where.append((round(p.z, 2), round(math.degrees(math.atan2(p.x, -p.y))), v.index in bfl, round(h[3], 3)))
    pokes.last = where
    return n


for n in ("run", "hop", "emote_cheer", "emote_dance"):
    if n not in clipinfo:
        continue
    res = {w: 0 for w in WIDE}
    worst_f = {w: 0 for w in WIDE}
    for f in range(0, clipinfo[n][1]["frames"] + 1, 2):
        L.play(arm, n, f)
        bs = snap(body)
        for w, sock in WIDE.items():
            if sock:
                bone, loc = A.SOCKETS[sock]
                pb = arm.pose.bones[bone]
                o = bpy.data.objects[w]
                o.matrix_world = arm.matrix_world @ pb.matrix @ pb.bone.matrix_local.inverted() @ Matrix.Translation(loc)
                bpy.context.view_layer.update()
                it = snap(o)
            else:
                it = snap(bpy.data.objects[w + "_mesh"])
            c = pokes(bs, it)
            if c > res[w]:
                res[w], worst_f[w] = c, f
                if "--diag" in args:
                    print("  WHERE", n, w, f, pokes.last[:8])
            bpy.data.objects.remove(it, do_unlink=True)
        bpy.data.objects.remove(bs, do_unlink=True)
    print(f"CLIP {n:14s} " + " ".join(f"{w}={res[w]}@f{worst_f[w]}" for w in WIDE))

# ---- contact strips -------------------------------------------------------------
if render:
    os.makedirs(common.WIP, exist_ok=True)
    os.makedirs(common.DETAILS, exist_ok=True)
    for n, (k, i) in clipinfo.items():
        N = 7
        frames = sorted({round(j * i["frames"] / (N if i["loop"] else N - 1)) for j in range(N)})
        objs = []
        for j, f in enumerate(frames):
            L.play(arm, n, f)
            o = snap(body)
            o.hide_render = False
            o.matrix_world = Matrix.Translation((j * 1.05, 0, 0)) @ o.matrix_world
            objs.append(o)
        L.stop(arm)
        path = os.path.join(common.WIP, f"{k}_{n}.png")
        common.render_preview(k, objs=objs, path=path, elev=80, azim=28, res=(2400, 420), pad=1.04)
        shutil.copy(path, os.path.join(common.DETAILS, f"{k}_{n}.png"))
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    print("STRIPS", len(clipinfo))
