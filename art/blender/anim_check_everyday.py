"""Checks for anim_everyday: loop seams, strips, outfit clipping (robe, vest, hood, backpack) plus
  * step_up: each foot's world height when planted (0 before, 0.25 after) and the root's final rise
  * sip: closest approach of socket_hand_R (mug) to the beak tip
  * carry_hold: only upper-body channels keyed
  Blender -b --factory-startup --python art/blender/anim_check_everyday.py [-- --no-render]
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
POSES = ("pick_up", "carry_hold", "place", "stool_back_up_sit", "sip", "drawer_open")
user = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
sys.argv = sys.argv[:1] + ["--", "anim_everyday"] + user
src = open(os.path.join(HERE, "anim_check.py")).read().replace('("run", "hop", "emote_cheer", "emote_dance")', repr(POSES))
assert repr(POSES) in src
exec(compile(src, "anim_check.py", "exec"))
from mathutils import Matrix
i = clipinfo["step_up"][1]
for f in (0, i["frames"]):
    L.play(arm, "step_up", f)
    print("STEP f%-3d root_z=%.3f feet_z=%s" % (f, arm.pose.bones["root"].head.z,
          [round((arm.pose.bones[b].head - arm.pose.bones[b].bone.head_local).z, 3) for b in ("foot.L", "foot.R")]))
bone, loc = A.SOCKETS["hand_R"]
beak = max(((body.matrix_world @ v.co) for v in body.data.vertices), key=lambda p: -p.y)
best = 9
for f in range(clipinfo["sip"][1]["frames"] + 1):
    L.play(arm, "sip", f)
    pb = arm.pose.bones[bone]
    hand = (pb.matrix @ pb.bone.matrix_local.inverted() @ Matrix.Translation(loc)).translation
    best = min(best, (hand - beak).length)
print("SIP closest mug-to-beak-tip %.3f m (mug radius ~0.05)" % best)
act = bpy.data.actions[L.ACTION["carry_hold"]]
bones = {fc.data_path.split('"')[1] for ly in act.layers for st in ly.strips for bag in st.channelbags for fc in bag.fcurves if "pose.bones" in fc.data_path}
print("CARRY keyed bones", sorted(bones))
L.stop(arm)
