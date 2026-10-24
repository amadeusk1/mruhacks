"""animlib, with bone-local scale fixed for the social activity kits (anim_arcade/drawing/cinema/home).

shortcut: animlib.pose() converts world scale with sum(abs(R[j][i]) * ws[j]), which is only right for
axis-aligned bones; the diagonal flipper bones get ~1.41x local scale even at ws=(1,1,1). This module
recomputes it as the length of each rest axis scaled by ws (exact for uniform scale, same as before for aligned
bones). Delete this file and import animlib directly once animlib.pose() has the same fix.
"""
import math
import bpy
from mathutils import Vector
import animlib as _L
from animlib import X, Y, Z, FPS, ss, window, bump, cyc, lerp, mix, clip, rig, finalize, play, stop  # noqa: F401


def aim(bone, d, w=1.0):
    """World rotation that swings a bone's rest direction onto direction d (blended by w from rest)."""
    b = bpy.data.objects["avatar_base"].data.bones[bone]
    ax, ang = (b.tail_local - b.head_local).normalized().rotation_difference(Vector(d).normalized()).to_axis_angle()
    return [(tuple(ax), math.degrees(ang) * w)]


def pose(spec, morph=None, arm=None):
    for v in spec.values():  # animlib reads a one-item rot list as (axis, deg) and fails: unwrap it
        if isinstance(v.get("rot"), list) and len(v["rot"]) == 1:
            v["rot"] = v["rot"][0]
    p = _L.pose(spec, morph, arm)
    rest = _L._rest(arm or bpy.data.objects["avatar_base"])
    for name, (q, loc, _scl) in p.bones.items():
        ws, R = Vector(spec.get(name, {}).get("scl", (1, 1, 1))), rest[name]
        p.bones[name] = (q, loc, Vector([Vector([R[j][i] * ws[j] for j in range(3)]).length for i in range(3)]))
    return p


def rest_pose():
    return pose({})

