"""Sledding clips (Animation Kit - Sledding). The avatar origin sits on winter/sled's socket_rider for every
clip: gameplay parents the avatar to that socket at sled_mount's start and unparents it at sled_dismount's end.
sled_mount starts (and sled_dismount ends) with the penguin standing on the snow MOUNT_OFFSET from the seat,
which the clip reaches by moving the root bone, so no snap is needed. Lean clips are short held poses for a
blend space (-1 left ... +1 right) layered over sled_ride.
"""
import math
import animlib as L
from animlib import X, Y, Z, ss, bump, cyc, window, flippers, merge

KIT = "anim_sledding"
RIDER = (0.0, 0.05, 0.215)          # winter/sled socket_rider (Blender Z-up)
MOUNT_OFFSET = (0.5, 0.0, -0.215)   # standing beside the sled on the character's left (+X), on the snow
SLED = [{"asset": "winter/sled", "attach": "avatar origin = sled socket_rider"}]

FEET = {"foot.L": {"rot": [(X, -32), (Z, 10)], "loc": (0.03, -0.2, 0.02)},
        "foot.R": {"rot": [(X, -32), (Z, -10)], "loc": (-0.03, -0.2, 0.02)}}
SEAT = merge(FEET, flippers(l=(-6, 22), r=(-6, 22)), {"body": {"rot": (X, -6)}, "head": {"rot": (X, 4)}})
TUCK = merge(FEET, flippers(l=(-10, 30), r=(-10, 30)),
             {"body": {"rot": (X, 10), "loc": (0, -0.01, -0.02), "scl": (1.02, 1.02, 0.97)}, "head": {"rot": (X, -10)}})
BRAKE = merge({"foot.L": {"rot": [(X, -55), (Z, 18)], "loc": (0.05, -0.26, 0.06)},
               "foot.R": {"rot": [(X, -55), (Z, -18)], "loc": (-0.05, -0.26, 0.06)}},
              flippers(l=(35, -20), r=(35, -20)), {"body": {"rot": (X, -16), "loc": (0, 0.02, 0)}, "head": {"rot": (X, 8)}})


def lean(side):
    """side +1 = left (+X)."""
    return merge(TUCK, {"body": {"rot": [(Y, 14 * side), (Z, 5 * side)]}, "head": {"rot": [(Y, -8 * side)]},
                        "flipper.L" if side > 0 else "flipper.R": {"rot": (Y, -20 * side if side > 0 else 20)}})


def root_at(off_w):
    return {"root": {"loc": tuple(o * off_w for o in MOUNT_OFFSET)}}


def mount(t):
    w = 1 - ss(0.1, 0.6, t)                              # root travels from beside the sled onto the seat
    arc = bump(t, 0.1, 0.5)
    seat = ss(0.35, 0.65, t)
    p = L.mix(L.rest_pose(), L.pose(SEAT), seat)
    off = L.pose({"root": {"loc": (MOUNT_OFFSET[0] * w, 0, MOUNT_OFFSET[2] * w + 0.12 * arc)},
                  "body": {"loc": (0, 0, -0.02 * bump(t, 0.58, 0.18))}})
    return L.add(p, off, {"eyes_happy": 0.6 * bump(t, 0.5, 0.3)})


def dismount(t):
    w = ss(0.15, 0.65, t)
    arc = bump(t, 0.15, 0.5)
    p = L.mix(L.pose(SEAT), L.rest_pose(), ss(0.05, 0.4, t))
    off = L.pose({"root": {"loc": (MOUNT_OFFSET[0] * w, 0, MOUNT_OFFSET[2] * w + 0.1 * arc)},
                  "body": {"loc": (0, 0, -0.02 * bump(t, 0.62, 0.18))}})
    return L.add(p, off)


def ready(t):
    u = t / 1.0
    return L.add(L.pose(SEAT, {"eyes_wide": 0.3}), L.pose({"body": {"loc": (0, 0, 0.01 * (0.5 - 0.5 * math.cos(4 * math.pi * u))),
                                                                     "rot": (X, 3 * cyc(u))},
                                                            "head": {"rot": (X, -3 * cyc(u, 2))}}))


def ride(t):
    u = t / 1.2
    bumpz = 0.008 * cyc(u, 3) + 0.005 * cyc(u, 5, 0.3)
    return L.add(L.pose(TUCK, {"eyes_closed": 0.25}), L.pose({"body": {"loc": (0, 0, bumpz), "rot": [(Y, 2 * cyc(u, 2)), (X, 2 * cyc(u, 3))]},
                                                              "head": {"rot": (Y, -1.5 * cyc(u, 2))}}))


brake = L.seq([(0.0, TUCK, {}), (0.15, BRAKE, {"eyes_closed": 0.5, "beak_open": 0.3}), (0.6, BRAKE, {"eyes_closed": 0.4}),
               (0.8, SEAT, {})])
finish = L.seq([(0.0, SEAT, {}), (0.3, merge(SEAT, flippers(l=(70, 10), r=(70, 10))), {"eyes_happy": 1, "beak_open": 0.6}),
                (0.7, merge(SEAT, flippers(l=(60, 10), r=(60, 10))), {"eyes_happy": 1}), (1.0, SEAT, {})],
               overlay=lambda t: ({"body": {"loc": (0, 0, 0.03 * bump(t, 0.25, 0.3))}}, {}))


def clips(arm):
    rider = {"sled_rider_socket": "socket_rider", "mount_offset_m_godot": [MOUNT_OFFSET[0], MOUNT_OFFSET[2], -MOUNT_OFFSET[1]]}
    L.clip(arm, "sled_mount", 0.8, mount, cancel="none", events={"seated": 0.65}, props=SLED, extra=rider)
    L.clip(arm, "sled_ready", 1.0, ready, loop=True, cancel="none", props=SLED)
    L.clip(arm, "sled_ride", 1.2, ride, loop=True, cancel="none", props=SLED)
    L.clip(arm, "sled_lean_left", 0.2, lambda t: L.pose(lean(1)), cancel="none", props=SLED, note="held pose: blend weight = steer left")
    L.clip(arm, "sled_lean_right", 0.2, lambda t: L.pose(lean(-1)), cancel="none", props=SLED, note="held pose: blend weight = steer right")
    L.clip(arm, "sled_brake", 0.8, brake, cancel="none", events={"spray_start": 0.1, "spray_stop": 0.6}, props=SLED,
           extra={"fx_sockets": ["socket_fx_spray_l", "socket_fx_spray_r"]})
    L.clip(arm, "sled_finish", 1.0, finish, cancel="none", props=SLED, note="cosmetic; never delays finish scoring")
    L.clip(arm, "sled_dismount", 0.8, dismount, cancel="none", events={"off_sled": 0.65}, props=SLED, extra=rider)


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
