"""Home interaction clips (Home interactions row of the Social Activities sheet / 'Animation Kit - Ambient World').
door_reach: reach a handle ~0.75 m high, ~0.3 m ahead (gameplay places the penguin there; socket_door is the
approach point) and swing the door's part_door_leaf on 'handle'. place_item: from anim_social's hold_item_idle
pose, lower the held item (socket_hand_R) onto a table top ~0.6 m high and detach it on 'place'. Grid placement
never waits for these gestures. armchair_*: a deeper, cozier sit for room_kit armchair/sofa seats (0.41 m).
"""
import common
import animlib_social as L
from animlib_social import X, Y, Z, ss, bump, cyc, window, aim

KIT = "anim_home"
S = common.load_kit("anim_social")

HANDLE = (0.15, -0.6, 0.8)
TABLE_TOP = (0.08, -0.8, 0.6)
ARMREST = {"flipper.L": (0.8, -0.3, -0.52), "flipper.R": (-0.8, -0.3, -0.52)}


def door_reach(t):
    w = window(t, 0.05, 0.4, 0.6, 1.0)
    lift = bump(t, 0.0, 0.3) + bump(t, 0.65, 0.3)        # step the right foot in, then back
    turn = window(t, 0.4, 0.5, 0.55, 0.62)               # small twist of the handle
    return L.pose({
        "body": {"rot": [(X, 14 * w), (Z, -6 * w)]},
        "head": {"rot": [(X, -6 * w), (Z, -4 * w)]},
        "flipper.R": {"rot": aim("flipper.R", HANDLE, w) + [(Y, -12 * turn)]},
        "flipper.L": {"rot": (Y, -8 * w)},
        "foot.R": {"loc": (0, -0.05 * w, 0.02 * lift)},
    }, morph={"eyes_wide": 0.2 * w})


def place_item(t):
    hold = L.pose({"flipper.R": {"rot": list(S.HOLD["flipper.R"])}})   # = hold_item_idle at frame 0
    place = L.pose({"body": {"rot": (X, 18), "loc": (0, 0, 0.012)}, "head": {"rot": (X, 12)},
                    "flipper.R": {"rot": aim("flipper.R", TABLE_TOP)}, "flipper.L": {"rot": (Y, -10)},
                    "foot.L": {"loc": (0, -0.03, 0)}})
    p = L.mix(L.mix(hold, place, ss(0.1, 0.5, t)), L.rest_pose(), ss(0.62, 1.15, t))
    p.morph["eyes_happy"] = 0.5 * window(t, 0.6, 0.7, 0.95, 1.1)
    return p


def chair_spec(w=1.0, breath=0.0):
    p = S.sit_spec(w, breath)
    p["body"] = {**p["body"], "rot": (X, -18 * w), "loc": (0, 0.02 * w, -0.012 * w + 0.005 * breath)}  # sinks into the cushion
    p["head"]["rot"] = (X, 2 * w)
    for b in ARMREST:
        p[b] = {"rot": aim(b, ARMREST[b], w)}
    p["foot.L"]["loc"] = (0.03 * w, -0.2 * w, 0.04 * w)
    p["foot.R"]["loc"] = (-0.03 * w, -0.2 * w, 0.04 * w)
    return p


def armchair_sit(t):
    w = ss(0.1, 0.55, t)
    hopv = bump(t, 0.06, 0.34)
    p = chair_spec(w)
    p["body"] = {**p["body"], "loc": (0, 0.02 * w + 0.02 * hopv, -0.012 * w + 0.05 * hopv - 0.02 * bump(t, 0.42, 0.14))}
    return L.pose(p, morph={"eyes_happy": 0.6 * bump(t, 0.4, 0.2)})


def armchair_idle(t):
    u = t / 3.0
    p = chair_spec(1.0, breath=cyc(u))
    p["head"]["rot"] = [(X, 2 + 1.5 * cyc(u, 1, 0.2)), (Y, 5 * cyc(u))]   # cozy, slow head tilt
    sway = 6 * cyc(u, 1, 0.5)
    p["foot.L"]["rot"] = list(p["foot.L"]["rot"]) + [(X, sway)]
    p["foot.R"]["rot"] = list(p["foot.R"]["rot"]) + [(X, -sway)]
    return L.pose(p, morph={"eyes_closed": 0.25 + 0.75 * bump(t, 1.6, 0.25), "eyes_happy": 0.3})


def armchair_stand(t):
    w = 1 - ss(0.05, 0.45, t)
    hopv = bump(t, 0.05, 0.34)
    p = chair_spec(w)
    p["body"] = {**p["body"], "loc": (0, 0.02 * w - 0.02 * hopv, -0.012 * w + 0.05 * hopv - 0.015 * bump(t, 0.4, 0.14))}
    return L.pose(p, morph={"eyes_closed": 0.25 * w})


def clips(arm):
    L.clip(arm, "door_reach", 1.0, door_reach, events={"handle": 0.5}, cancel="move",
           note="handle ~0.75 m high, ~0.3 m ahead; swing the door's part_door_leaf on 'handle'")
    L.clip(arm, "place_item", 1.2, place_item, events={"place": 0.55}, cancel="move",
           note="starts on anim_social hold_item_idle's pose (item in socket_hand_R); detach the item at 'place'")
    L.clip(arm, "armchair_sit", 0.6, armchair_sit, events={"seated": 0.5}, cancel="none",
           note="snap socket_seat to the armchair/sofa socket_seat_N (0.41 m)")
    L.clip(arm, "armchair_idle", 3.0, armchair_idle, loop=True, cancel="none")
    L.clip(arm, "armchair_stand", 0.6, armchair_stand, events={"stand": 0.42}, cancel="none")


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
