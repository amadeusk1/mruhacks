"""Social and interaction clips: sit_enter, sit_idle, sit_exit, interact_reach, hold_item_idle.
Sitting: gameplay snaps the avatar's socket_seat (the root, at the bottom) to the seat's socket_seat_N at the
'seated' event of sit_enter, and releases it at 'stand' in sit_exit. The hop onto and off the seat is
body-only, so the root stays on the seat point.
"""
import math
import animlib as L
from animlib import X, Y, Z, ss, bump, cyc, window

KIT = "anim_social"


def sit_spec(w=1.0, breath=0.0):
    return {
        "body": {"rot": (X, -10 * w), "loc": (0, 0, 0.006 * breath),
                 "scl": (1 - 0.005 * breath, 1 - 0.005 * breath, 1 + 0.01 * breath)},
        "head": {"rot": (X, 6 * w)},
        "foot.L": {"rot": [(X, -30 * w), (Z, 12 * w)], "loc": (0.03 * w, -0.19 * w, 0.015 * w)},
        "foot.R": {"rot": [(X, -30 * w), (Z, -12 * w)], "loc": (-0.03 * w, -0.19 * w, 0.015 * w)},
        "flipper.L": {"rot": [(X, 15 * w), (Y, 6 * w)]}, "flipper.R": {"rot": [(X, 15 * w), (Y, -6 * w)]},
    }


def sit_enter(t):
    w = ss(0.1, 0.42, t)
    hopv = bump(t, 0.06, 0.32)
    p = sit_spec(w)
    p["body"] = {**p["body"], "loc": (0, 0.02 * hopv, 0.05 * hopv - 0.02 * bump(t, 0.38, 0.12))}
    return L.pose(p, morph={"eyes_happy": 0.5 * bump(t, 0.3, 0.2)})


def sit_idle(t):
    D = 3.0
    u = t / D
    p = sit_spec(1.0, breath=cyc(u))
    swing = 8 * cyc(u, 2)                                    # feet dangle a little, alternating
    p["foot.L"]["rot"] = p["foot.L"]["rot"] + [(X, swing)]
    p["foot.R"]["rot"] = p["foot.R"]["rot"] + [(X, -swing)]
    p["head"]["rot"] = [(X, 6 + 1.5 * cyc(u, 1, 0.2)), (Y, 4 * window(t, 1.2, 1.6, 2.2, 2.6))]
    return L.pose(p, morph={"eyes_closed": bump(t, 0.9, 0.2)})


def sit_exit(t):
    w = 1 - ss(0.05, 0.38, t)
    hopv = bump(t, 0.05, 0.3)
    p = sit_spec(w)
    p["body"] = {**p["body"], "loc": (0, -0.02 * hopv, 0.05 * hopv - 0.015 * bump(t, 0.36, 0.14))}
    return L.pose(p)


def reach(t):
    w = window(t, 0.0, 0.32, 0.5, 0.8)
    return L.pose({"body": {"rot": [(X, 12 * w), (Z, -6 * w)]}, "head": {"rot": [(X, 6 * w), (Z, -4 * w)]},
                   "flipper.R": {"rot": [(X, -72 * w), (Y, 14 * w)]}, "flipper.L": {"rot": (Y, -10 * w)},
                   "foot.R": {"loc": (0, -0.04 * w, 0.02 * bump(t, 0.05, 0.25))}},
                  morph={"eyes_wide": 0.25 * w})


HOLD = {"flipper.R": [(X, -48), (Y, 22)]}


def hold_item_idle(t):
    D = 2.0
    u = t / D
    return L.pose({"body": {"scl": (1 - 0.006 * cyc(u), 1 - 0.006 * cyc(u), 1 + 0.012 * cyc(u)), "loc": (0, 0, 0.004 * cyc(u))},
                   "head": {"rot": [(X, 4), (Z, -4)]},
                   "flipper.R": {"rot": HOLD["flipper.R"] + [(X, 2 * cyc(u, 1, 0.1))]},
                   "flipper.L": {"rot": (Y, -3 * cyc(u, 1, 0.1))}},
                  morph={"eyes_closed": bump(t, 1.3, 0.2)})


def clips(arm):
    L.clip(arm, "sit_enter", 0.5, sit_enter, events={"seated": 0.42}, cancel="none")
    L.clip(arm, "sit_idle", 3.0, sit_idle, loop=True, cancel="none", note="leave the seat with sit_exit, not by moving")
    L.clip(arm, "sit_exit", 0.5, sit_exit, events={"stand": 0.36}, cancel="none")
    L.clip(arm, "interact_reach", 0.8, reach, events={"contact": 0.4})
    L.clip(arm, "hold_item_idle", 2.0, hold_item_idle, loop=True,
           note="right-flipper hold pose for socket_hand_R; layer it over idle/walk with a flipper.R bone mask")


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
