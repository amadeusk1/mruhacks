"""Shared helpers for the avatar animation kits (anim_locomotion, anim_emotes, anim_social).

A kit module does:
    import animlib as L
    KIT = "anim_x"
    def clips(arm): L.clip(arm, "name", duration_s, pose_fn, loop=True, events={...}, stride_m=..., cancel="move")
    def build(): arm = L.rig(KIT); clips(arm); L.finalize(arm, KIT)

pose_fn(t) returns L.pose({bone: {"rot": [(axis, deg), ...], "loc": world_vec, "scl": world_scale}}, morph={...}).
Rotations and locations are given in WORLD axes at the bind pose and converted to each bone's local space.
Clips are sampled at every frame (30 fps) with linear keys, so planted feet stay exactly planted.
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
        if rots and isinstance(rots[1], (int, float)):
            rots = [rots]
        q = Quaternion()
        for ax, deg in rots:
            q = rq.inverted() @ Quaternion(ax, math.radians(deg)) @ rq @ q
        loc = rq.inverted() @ Vector(p.get("loc", (0, 0, 0)))
        ws = Vector(p.get("scl", (1, 1, 1)))
        scl = Vector([sum(abs(R[j][i]) * ws[j] for j in range(3)) for i in range(3)])  # axis-aligned bones
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


def clip(arm, name, duration, pose_fn, loop=False, events=None, stride_m=None, cancel="move", note=None):
    """Sample pose_fn(t) at every frame over [0, duration] into one two-slot action."""
    n = round(duration * FPS)
    assert abs(n - duration * FPS) < 1e-6, f"{name}: duration must be a whole number of frames at {FPS} fps"
    bpy.context.scene.render.fps = FPS
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    mesh = _key_mesh(arm)
    key = mesh.data.shape_keys
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    for idb in (arm, key):
        ad = idb.animation_data or idb.animation_data_create()
        ad.action = act
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for f in range(n + 1):
        p = pose_fn(f / FPS)
        for pb in arm.pose.bones:
            q, l, s = p.bones[pb.name]
            pb.rotation_quaternion, pb.location, pb.scale = q, l, s
            pb.keyframe_insert("rotation_quaternion", frame=f, group=pb.name)
            pb.keyframe_insert("location", frame=f, group=pb.name)
            pb.keyframe_insert("scale", frame=f, group=pb.name)
        for kb in key.key_blocks[1:]:
            kb.value = max(0.0, min(1.0, p.morph.get(kb.name, 0.0)))
            kb.keyframe_insert("value", frame=f)
    for idb in (arm, key):
        ad = idb.animation_data
        tr = ad.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 0, act)
        tr.mute = True  # the scene stays in rest pose; the exporter still writes every track's action
        ad.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion, pb.location, pb.scale = (1, 0, 0, 0), (0, 0, 0), (1, 1, 1)
    for kb in key.key_blocks[1:]:
        kb.value = 0.0
    info = {"duration_s": round(n / FPS, 4), "frames": n, "loop": loop, "events": events or {}, "cancel": cancel}
    if stride_m is not None:
        info["stride_m"] = stride_m
        info["speed_mps"] = round(stride_m / duration, 4)
    if note:
        info["note"] = note
    CLIPS[name] = info
    return act


def play(arm, name, frame):
    """Pose the rig (and face) at a frame of a clip: for checks and renders."""
    act = bpy.data.actions[name]
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
                         "root_motion": "none: clips play in place; only hop moves the root vertically"}
    return arm
