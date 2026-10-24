"""Checks for the social activity animation kits (anim_arcade, anim_drawing, anim_cinema, anim_home).
  Blender -b --factory-startup --python art/blender/anim_check_social.py [-- --no-render]
1. Runs anim_check.py on these kits (loop seams + contact strips), with its outfit-clipping pass pointed at the
   seated and reaching poses (wizard_robe, puffer_vest, frog_hood, backpack).
2. Reach: right/left flipper tip and socket_hand_R world positions at the key frames.
3. Seat contact: lowest body vertex relative to socket_seat in each seated pose (gameplay snaps socket_seat to
   the seat socket, so 0 = sitting exactly on the cushion, negative = sinking in).
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
KITS = ["anim_arcade", "anim_drawing", "anim_cinema", "anim_home"]
POSES = ("arcade_play", "sketch_draw", "sketch_reveal", "cinema_watch", "cinema_snack", "armchair_idle", "door_reach")
user = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
sys.argv = sys.argv[:1] + ["--"] + KITS + user
src = open(os.path.join(HERE, "anim_check.py")).read()
src = src.replace('("run", "hop", "emote_cheer", "emote_dance")', repr(POSES))
assert repr(POSES) in src, "anim_check.py outfit loop changed; update this wrapper"
exec(compile(src, "anim_check.py", "exec"))

# ---- reach targets ----------------------------------------------------------------
KEY = {"arcade_ready": 0, "arcade_play": 4, "sketch_draw": 3, "cinema_snack": 18, "door_reach": 15, "place_item": 16}
for n, f in KEY.items():
    L.play(arm, n, f)
    out = []
    for b in ("flipper.L", "flipper.R"):
        pb = arm.pose.bones[b]
        tip = arm.matrix_world @ pb.tail
        out.append(f"{b} tip=({tip.x:+.2f},{tip.y:+.2f},{tip.z:.2f})")
    print(f"REACH {n:14s} f{f:<3d} " + "  ".join(out))

# ---- seat contact -----------------------------------------------------------------
seat_z = A.SOCKETS["seat"][1][2]
for n in ("sketch_think", "sketch_draw", "cinema_watch", "cinema_reaction_laugh", "armchair_idle"):
    L.play(arm, n, 0)
    me = bpy.data.meshes.new_from_object(body.evaluated_get(dg()))
    lowest = min((body.matrix_world @ v.co).z for v in me.vertices if v.co.z > 0.03 or True)
    feet_z = min((arm.matrix_world @ arm.pose.bones[b].head).z for b in ("foot.L", "foot.R"))
    bpy.data.meshes.remove(me)
    print(f"SEAT {n:22s} lowest_body={lowest - seat_z:+.3f} m vs socket_seat  feet_head={feet_z - seat_z:+.3f}")
L.stop(arm)
