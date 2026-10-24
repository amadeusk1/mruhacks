"""Shared helpers for the avatar animation kits (anim_locomotion, anim_emotes, anim_social).

A kit module does:
    import animlib as L
    KIT = "anim_x"
    def clips(arm): L.clip(arm, "name", duration_s, pose_fn, loop=True, events={...}, stride_m=..., cancel="move")
    def build(): arm = L.rig(KIT); clips(arm); L.finalize(arm, KIT)

pose_fn(t) returns L.pose({bone: {"rot": [(axis, deg), ...], "loc": world_vec, "scl": world_scale}}, morph={...}).
Rotations and locations are given in WORLD axes at the bind pose and converted to each bone's local space.
Clips are sampled at every frame (30 fps) with linear keys, so planted feet stay exactly planted.
Looping clips are exported as "<name>_loop": Godot's importer turns that suffix into loop mode and strips it,
so in Godot every clip appears under its plain name with the right loop flag.
Each clip is ONE Blender action with two slots (armature + face shape keys), which the glTF exporter writes as
one animation carrying bone channels plus the mesh's morph 'weights'.

The kit GLB contains the full avatar_base (rig + skinned mesh with morph targets): the face tracks need the
mesh to import in Godot. Node names match avatar_base.glb, so the clips retarget by path and bone name.
"""
import math
import bpy
import common
from mathutils import Vector, Quaternion, Matrix

FPS = 30
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
A = common.load_kit("avatar")
CLIPS = {}  # name -> manifest info, per build
ACTION = {}  # clip name -> exported action name (loops get a _loop suffix: Godot loops and strips it on import)


# ---------------------------------------------------------------------------
# small timing helpers
# ---------------------------------------------------------------------------
def ss(a, b, x):
    """Smoothstep from 0 at a to 1 at b (a > b ramps down)."""
    if a == b:
        return 1.0 if x >= a else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def window(t, a, b, c, d):
    """0 before a, eases to 1 by b, holds, eases back to 0 between c and d."""
    return ss(a, b, t) * (1 - ss(c, d, t))


def bump(t, t0, dur):
    """Half-sine pulse 0 -> 1 -> 0 over [t0, t0+dur]."""
    x = (t - t0) / dur
    return math.sin(math.pi * x) if 0 < x < 1 else 0.0


def cyc(u, k=1, ph=0.0):
    """sin(2*pi*(k*u + ph)) for loop phase u in [0, 1]: exactly periodic."""
    return math.sin(2 * math.pi * (k * u + ph))


def lerp(a, b, w):
    return a + (b - a) * w


# ---------------------------------------------------------------------------
# poses
# ---------------------------------------------------------------------------
class Pose:
    """Resolved pose: bone -> (local quaternion, local location, local scale) plus morph weights."""

    def __init__(self, bones, morph):
        self.bones, self.morph = bones, morph


_REST = {}


def _rest(arm):
    if not _REST:
        for pb in arm.pose.bones:
            _REST[pb.name] = pb.bone.matrix_local.to_3x3()
    return _REST


def pose(spec, morph=None, arm=None):
    arm = arm or bpy.data.objects["avatar_base"]
    rest = _rest(arm)
    out = {}
    for name, R in rest.items():
        p = spec.get(name, {})
        rq = R.to_quaternion()
        rots = p.get("rot", [])
        if len(rots) == 2 and isinstance(rots[1], (int, float)):
            rots = [rots]
        q = Quaternion()
        for ax, deg in rots:
            q = rq.inverted() @ Quaternion(ax, math.radians(deg)) @ rq @ q
        loc = rq.inverted() @ Vector(p.get("loc", (0, 0, 0)))
        ws = Vector(p.get("scl", (1, 1, 1)))
        scl = Vector([math.sqrt(sum((R[j][i] * ws[j]) ** 2 for j in range(3))) for i in range(3)])  # = 1 when ws = 1
        out[name] = (q, loc, scl)
    return Pose(out, dict(morph or {}))


def mix(a, b, w):
    """Blend two resolved poses (slerp rotations, lerp the rest)."""
    bones = {}
    for n in a.bones:
        qa, la, sa = a.bones[n]
        qb, lb, sb = b.bones[n]
        if qa.dot(qb) < 0:
            qb = -qb
        bones[n] = (qa.slerp(qb, w), la.lerp(lb, w), sa.lerp(sb, w))
    morph = {k: lerp(a.morph.get(k, 0.0), b.morph.get(k, 0.0), w) for k in set(a.morph) | set(b.morph)}
    return Pose(bones, morph)


def rest_pose():
    return pose({})


# ---------------------------------------------------------------------------
# clips
# ---------------------------------------------------------------------------
def _key_mesh(arm):
    return bpy.data.objects[arm.name + "_mesh"]


def clip(arm, name, duration, pose_fn, loop=False, events=None, stride_m=None, cancel="move", note=None,
         props=None, prop_path=None, extra=None):
    """Sample pose_fn(t) at every frame over [0, duration] into one two-slot action.
    props: [{"asset": "kit/name", "socket": "socket_hand_R", "visible": [t0, t1]}] for props riding a socket.
    prop_path: (asset, fn(t, arm) -> Vector | None) for a prop that follows a path (e.g. a ball held in both
    flippers). It is sampled every frame into meta as Godot Y-up [t, x, y, z] relative to the avatar origin."""
    n = round(duration * FPS)
    assert abs(n - duration * FPS) < 1e-6, f"{name}: duration must be a whole number of frames at {FPS} fps"
    bpy.context.scene.render.fps = FPS
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    mesh = _key_mesh(arm)
    key = mesh.data.shape_keys
    act = bpy.data.actions.new(name + "_loop" if loop else name)
    ACTION[name] = act.name
    act.use_fake_user = True
    for idb in (arm, key):
        ad = idb.animation_data or idb.animation_data_create()
        ad.action = act
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    path = []
    for f in range(n + 1):
        p = pose_fn(f / FPS)
        for pb in arm.pose.bones:
            q, l, s = p.bones[pb.name]
            pb.rotation_quaternion, pb.location, pb.scale = q, l, s
            pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
            pb.keyframe_insert("location", frame=f, group=pb.name)
            pb.keyframe_insert("scale", frame=f, group=pb.name)
        if prop_path:
            bpy.context.view_layer.update()
            v = prop_path[1](f / FPS, arm)
            if v is not None:
                path.append([round(f / FPS, 4), round(v.x, 4), round(v.z, 4), round(-v.y, 4)])
        for kb in key.key_blocks[1:]:
            kb.value = max(0.0, min(1.0, p.morph.get(kb.name, 0.0)))
            kb.keyframe_insert("value", frame=f)
    for idb in (arm, key):
        ad = idb.animation_data
        tr = ad.nla_tracks.new()
        tr.name = act.name
        tr.strips.new(act.name, 0, act)
        tr.mute = True  # the scene stays in rest pose; the exporter still writes every track's action
        ad.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion, pb.location, pb.scale = (1, 0, 0, 0), (0, 0, 0), (1, 1, 1)
    for kb in key.key_blocks[1:]:
        kb.value = 0.0
    info = {"duration_s": round(n / FPS, 4), "frames": n, "loop": loop, "events": events or {}, "cancel": cancel,
            "gltf_name": act.name}
    if stride_m is not None:
        info["stride_m"] = stride_m
        info["speed_mps"] = round(stride_m / duration, 4)
    if note:
        info["note"] = note
    if props:
        info["props"] = props
    if prop_path:
        info["prop_path"] = {"asset": prop_path[0], "space": "avatar origin, Godot Y-up metres", "samples": path}
    info.update(extra or {})
    CLIPS[name] = info
    return act


def play(arm, name, frame):
    """Pose the rig (and face) at a frame of a clip: for checks and renders."""
    act = bpy.data.actions[ACTION.get(name, name)]
    mesh = _key_mesh(arm)
    for idb in (arm, mesh.data.shape_keys):
        ad = idb.animation_data or idb.animation_data_create()
        ad.action = act
        slot = next((s for s in act.slots if s.target_id_type == ("OBJECT" if idb is arm else "KEY")), None)
        if slot is not None:
            ad.action_slot = slot
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def stop(arm):
    for idb in (arm, _key_mesh(arm).data.shape_keys):
        if idb.animation_data:
            idb.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion, pb.location, pb.scale = (1, 0, 0, 0), (0, 0, 0), (1, 1, 1)
    for kb in _key_mesh(arm).data.shape_keys.key_blocks[1:]:
        kb.value = 0.0
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()


# ---------------------------------------------------------------------------
# kit build
# ---------------------------------------------------------------------------
def rig(kit):
    """Build avatar_base (rig + skinned bird + face morphs) and file it under this animation kit."""
    CLIPS.clear()
    _REST.clear()
    for a in list(bpy.data.actions):  # the exporter attaches every compatible action, so start clean
        bpy.data.actions.remove(a)
    arm = A.build_base()
    for a in common.ASSETS:
        if a["obj"] is arm:
            a["kit"], a["category"] = kit, "animation"
    arm["asset_id"] = f"{kit}/{arm.name}"
    return arm


def finalize(arm, kit):
    for a in common.ASSETS:
        if a["obj"] is arm:
            a["meta"] = {"fps": FPS, "bones": [b[0] for b in A.BONES], "morphs": A.MORPHS, "clips": dict(CLIPS),
                         "rig": "avatar_base (same node and bone names as avatar/avatar_base.glb)",
                         "root_motion": "none: clips play in place; only hop and jump move the root vertically"}
    return arm


def tip(arm, bone, along=0.0):
    """Armature-space point on a posed flipper: 0 = tip, positive moves back up toward the root (metres)."""
    pb = arm.pose.bones[bone]
    d = (pb.head - pb.tail).normalized()
    return pb.tail + d * along


def between_flippers(arm, fwd=0.07, along=0.05):
    """Centre of a ball held between both flipper tips, pushed forward (toward -Y)."""
    return (tip(arm, "flipper.L", along) + tip(arm, "flipper.R", along)) / 2 + Vector((0, -fwd, 0))


def flippers(l=(0.0, 0.0), r=(0.0, 0.0), extra=None):
    """Flipper spec: (out, fwd) per side, in degrees. out > 0 raises the flipper sideways (out < 0 pulls it
    in across the belly); fwd > 0 swings the tip forward (past ~90 it goes up in front of the face)."""
    spec = {"flipper.L": {"rot": [(X, -l[1]), (Y, -l[0])]}, "flipper.R": {"rot": [(X, -r[1]), (Y, r[0])]}}
    for k, v in (extra or {}).items():
        spec[k]["rot"] = spec[k]["rot"] + v
    return spec


def lerp2(a, b, w):
    return (lerp(a[0], b[0], w), lerp(a[1], b[1], w))


def merge(*specs):
    """Merge pose specs bone by bone (rotation lists concatenate, loc/scl from the last spec that sets them)."""
    out = {}
    for sp in specs:
        for b, v in sp.items():
            d = out.setdefault(b, {})
            for k, x in v.items():
                if k == "rot":
                    x = [x] if len(x) == 2 and isinstance(x[1], (int, float)) else list(x)
                    d["rot"] = d.get("rot", []) + x
                else:
                    d[k] = x
    return out


def seq(keys, overlay=None):
    """Timeline of key poses: keys = [(t, spec, morph)], eased (smoothstep) between neighbours.
    overlay(t) -> (spec, morph) adds motion on top (breathing, bobs) and is merged before resolving."""
    resolved = []

    def fn(t):
        if not resolved:  # resolve lazily: kit modules define timelines before the rig exists
            resolved.extend((k, pose(sp, mo)) for k, sp, mo in keys)
        i = 0
        while i < len(resolved) - 1 and resolved[i + 1][0] <= t:
            i += 1
        if i == len(resolved) - 1:
            p = resolved[-1][1]
        else:
            (t0, a), (t1, b) = resolved[i], resolved[i + 1]
            p = mix(a, b, ss(t0, t1, t))
        if overlay is None:
            return p
        osp, omo = overlay(t)
        return add(p, pose(osp, {}), omo)
    return fn


def add(a, b, morph=None):
    """Layer resolved pose b's offsets on top of a; morph values are added."""
    bones = {}
    for n, (qa, la, sa) in a.bones.items():
        qb, lb, sb = b.bones[n]
        bones[n] = (qb @ qa, la + lb, Vector([sa[i] * sb[i] for i in range(3)]))
    m = dict(a.morph)
    for k, v in (morph or {}).items():
        m[k] = m.get(k, 0.0) + v
    return Pose(bones, m)


_FLIP_GROUPS = None


def clear_of_body(arm, c, r, gap=0.006, step=0.005, limit=0.4):
    """Push point c forward (the body bone's -Y) until a sphere of radius r clears the posed body surface,
    flippers excluded (they are meant to touch the prop). Used for props held against the belly or face."""
    global _FLIP_GROUPS
    from mathutils.bvhtree import BVHTree
    mesh = _key_mesh(arm)
    if _FLIP_GROUPS is None:
        _FLIP_GROUPS = {mesh.vertex_groups[n].index for n in ("flipper.L", "flipper.R")}
    ev = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    rest_flip = {v.index for v in mesh.data.vertices if any(g.group in _FLIP_GROUPS and g.weight > 0.5 for g in v.groups)}
    polys = [list(p.vertices) for p in me.polygons if not all(i in rest_flip for i in p.vertices)]
    tree = BVHTree.FromPolygons([mesh.matrix_world @ v.co for v in me.vertices], polys)
    ev.to_mesh_clear()
    fwd = (arm.matrix_world.to_3x3() @ arm.pose.bones["body"].matrix.to_3x3() @ Vector((0, 0, 1))).cross(Vector((1, 0, 0)))
    fwd = Vector((0, fwd.y, 0)).normalized() if abs(fwd.y) > 1e-6 else Vector((0, -1, 0))
    fwd = -fwd if fwd.y > 0 else fwd
    c = c.copy()
    moved = 0.0
    while moved < limit:
        hit = tree.find_nearest(c)
        inside = tree.ray_cast(c, fwd, 2.0)[0] is not None  # a forward ray from inside still exits through the belly
        if not inside and (hit[0] is None or hit[3] >= r + gap):
            break
        c += fwd * step
        moved += step
    return c


def aim(bone, d, w=1.0):
    """World rotation that swings a bone's rest direction onto direction d (blended by w from rest)."""
    b = bpy.data.objects["avatar_base"].data.bones[bone]
    ax, ang = (b.tail_local - b.head_local).normalized().rotation_difference(Vector(d).normalized()).to_axis_angle()
    return [(tuple(ax), math.degrees(ang) * w)]
