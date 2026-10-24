"""Locomotion clips: idle, idle_variant, walk, run, hop, start, stop, turn_left, turn_right.
All in place. Gameplay moves the character at clip speed_mps (= stride_m / duration) so stance feet stay
planted. Only hop moves the root, vertically. Body bob lives on the body bone so planted feet never lift.
"""
import math
import animlib as L
from animlib import X, Y, Z, ss, bump, cyc, window

KIT = "anim_locomotion"
WALK_D, WALK_DUTY, WALK_STEP = 0.8, 0.6, 0.16      # step = foot travel under the body per stance
RUN_D, RUN_DUTY, RUN_STEP = 0.5, 0.35, 0.1925
WALK_STRIDE = round(WALK_STEP / WALK_DUTY, 4)        # body travel per cycle while a foot is planted
RUN_STRIDE = round(RUN_STEP / RUN_DUTY, 4)


def foot(u, phase, duty, step, lift, toe=15.0):
    """Stance: slide back linearly (planted in the world). Swing: arc forward with toes up."""
    s = (u - phase) % 1.0
    if s < duty:
        return {"loc": (0, -step / 2 + step * s / duty, 0)}
    w = (s - duty) / (1 - duty)
    e = ss(0, 1, w)
    return {"loc": (0, step / 2 - step * e, lift * math.sin(math.pi * w)), "rot": (X, -toe * math.sin(math.pi * w))}


def breath(u, amt=1.0):
    b = cyc(u)
    return {"scl": (1 - 0.006 * b * amt, 1 - 0.006 * b * amt, 1 + 0.012 * b * amt), "loc": (0, 0, 0.004 * b * amt)}


def walk_spec(u):
    sway = math.cos(2 * math.pi * (u - 0.3))           # +1 over the left foot, -1 over the right
    return {
        "foot.L": foot(u, 0.0, WALK_DUTY, WALK_STEP, 0.035),
        "foot.R": foot(u, 0.5, WALK_DUTY, WALK_STEP, 0.035),
        "body": {"rot": [(Y, 7 * sway), (Z, 4 * math.sin(2 * math.pi * (u - 0.3))), (X, 3)],
                 "loc": (0, 0, 0.014 * (0.5 - 0.5 * math.cos(4 * math.pi * (u - 0.05))))},
        "head": {"rot": [(Y, -3 * sway), (X, -2)]},
        "flipper.L": {"rot": [(Y, -8 - 6 * sway), (X, -10 * math.sin(2 * math.pi * (u - 0.3)))]},
        "flipper.R": {"rot": [(Y, 8 - 6 * sway), (X, 10 * math.sin(2 * math.pi * (u - 0.3)))]},
    }


def walk(t):
    return L.pose(walk_spec((t / WALK_D) % 1.0))


def run(t):
    u = (t / RUN_D) % 1.0
    sl, sr = (u - 0.0) % 1, (u - 0.5) % 1
    lift = 0.028 * (bump(sl, RUN_DUTY, 0.5 - RUN_DUTY) + bump(sr, RUN_DUTY, 0.5 - RUN_DUTY))
    squash = bump(sl, 0.0, 0.16) + bump(sr, 0.0, 0.16)
    sway = math.cos(2 * math.pi * (u - RUN_DUTY / 2))
    return L.pose({
        "root": {"loc": (0, 0, lift)},
        "foot.L": foot(u, 0.0, RUN_DUTY, RUN_STEP, 0.042, toe=18),
        "foot.R": foot(u, 0.5, RUN_DUTY, RUN_STEP, 0.042, toe=18),
        "body": {"rot": [(X, 13), (Y, 4 * sway)], "loc": (0, 0, -0.012 * squash),
                 "scl": (1 + 0.02 * squash, 1 + 0.02 * squash, 1 - 0.035 * squash)},
        "head": {"rot": [(X, -9), (Y, -2 * sway)]},
        "flipper.L": {"rot": [(X, 34), (Y, -15 - 7 * cyc(u, 2))]},
        "flipper.R": {"rot": [(X, 34), (Y, 15 + 7 * cyc(u, 2))]},
    })


HOP_D, HOP_UP, HOP_DOWN = 23 / 30, 0.27, 0.57


def hop(t):
    crouch = ss(0.0, 0.2, t) * (1 - ss(0.2, HOP_UP, t))
    air = bump(t, HOP_UP, HOP_DOWN - HOP_UP)
    flight = window(t, HOP_UP, HOP_UP + 0.06, HOP_DOWN - 0.06, HOP_DOWN)
    land = bump(t, HOP_DOWN, 0.17)
    push = bump(t, 0.2, 0.15)
    return L.pose({
        "root": {"loc": (0, 0, 0.15 * air)},
        "body": {"loc": (0, 0, -0.05 * crouch - 0.035 * land),
                 "scl": (1 + 0.04 * crouch + 0.035 * land - 0.015 * push, 1 + 0.04 * crouch + 0.035 * land - 0.015 * push,
                         1 - 0.07 * crouch - 0.045 * land + 0.03 * push),
                 "rot": (X, 6 * crouch - 4 * flight)},
        "head": {"rot": (X, 8 * crouch - 6 * flight)},
        "foot.L": {"loc": (0.01 * flight, -0.02 * flight, 0.035 * flight), "rot": (X, -28 * flight)},
        "foot.R": {"loc": (-0.01 * flight, -0.02 * flight, 0.035 * flight), "rot": (X, -28 * flight)},
        "flipper.L": {"rot": [(X, 22 * crouch), (Y, -52 * flight + 6 * land)]},
        "flipper.R": {"rot": [(X, 22 * crouch), (Y, 52 * flight - 6 * land)]},
    }, morph={"eyes_happy": flight, "beak_open": 0.5 * flight})


def start(t):
    w = ss(0.0, 0.3, t)
    p = L.mix(L.rest_pose(), walk(0.0), w)
    dip = L.pose({"body": {"rot": (X, 6 * bump(t, 0.0, 0.3)), "loc": (0, 0, -0.012 * bump(t, 0.0, 0.3))}})
    return _add(p, dip)


def stop(t):
    D = 0.4
    w = ss(0.0, D, t)
    base = L.mix(walk(0.0), L.rest_pose(), w)
    brake = L.pose({"body": {"rot": (X, -7 * bump(t, 0.0, D)), "loc": (0, 0, -0.01 * bump(t, 0.1, 0.3))},
                    "foot.R": {"loc": (0, 0, 0.03 * bump(t, 0.0, 0.18))},
                    "foot.L": {"loc": (0, 0, 0.025 * bump(t, 0.16, 0.2))},
                    "flipper.L": {"rot": (Y, -14 * bump(t, 0.0, D))}, "flipper.R": {"rot": (Y, 14 * bump(t, 0.0, D))}},
                   morph={"eyes_wide": 0.4 * bump(t, 0.0, D)})
    return _add(base, brake)


def turn(side):
    """side +1 = left (yaw toward +X), -1 = right. Gameplay rotates the root during the clip."""
    D = 1 / 3

    def fn(t):
        lead, out_, in_ = bump(t, 0.0, D), bump(t, 0.0, 0.18), bump(t, 0.13, 0.2)
        fo, fi = ("foot.R", "foot.L") if side > 0 else ("foot.L", "foot.R")
        return L.pose({
            "body": {"rot": [(Z, side * 16 * lead), (Y, side * 5 * lead)], "loc": (0, 0, -0.008 * lead)},
            "head": {"rot": (Z, side * 14 * bump(t, 0.0, 0.26))},
            fo: {"loc": (0, -0.01 * out_, 0.03 * out_), "rot": (Z, side * 18 * out_)},
            fi: {"loc": (0, 0.01 * in_, 0.025 * in_), "rot": (Z, side * 12 * in_)},
            "flipper.L": {"rot": (Y, -10 * lead)}, "flipper.R": {"rot": (Y, 10 * lead)},
        })
    return fn, D


def _add(a, b):
    """Layer pose b's offsets on top of pose a."""
    bones = {}
    for n, (qa, la, sa) in a.bones.items():
        qb, lb, sb = b.bones[n]
        bones[n] = (qb @ qa, la + lb, L.Vector([sa[i] * sb[i] for i in range(3)]))
    m = dict(a.morph)
    for k, v in b.morph.items():
        m[k] = m.get(k, 0.0) + v
    return L.Pose(bones, m)


def idle(t):
    D = 2.4
    u = t / D
    return L.pose({"body": breath(u), "head": {"rot": (X, 2 * cyc(u, ph=0.15))},
                   "flipper.L": {"rot": (Y, -3 * cyc(u, ph=0.1))}, "flipper.R": {"rot": (Y, 3 * cyc(u, ph=0.1))}},
                  morph={"eyes_closed": bump(t, 1.55, 0.2)})


def idle_variant(t):
    D = 3.0
    u = t / D
    tilt = window(t, 0.5, 0.9, 1.9, 2.4)
    return L.pose({"body": {**breath(u), "rot": (Y, 3 * tilt)},
                   "head": {"rot": [(Y, 13 * tilt), (X, -4 * tilt + 2 * cyc(u, ph=0.15))]},
                   "flipper.L": {"rot": (Y, -3 * cyc(u, ph=0.1) - 4 * tilt)}, "flipper.R": {"rot": (Y, 3 * cyc(u, ph=0.1))},
                   "foot.R": {"loc": (0, 0, 0.02 * bump(t, 1.1, 0.25))}},
                  morph={"eyes_wide": 0.35 * tilt, "eyes_closed": bump(t, 2.6, 0.2)})


def clips(arm):
    L.clip(arm, "idle", 2.4, idle, loop=True, cancel="move", events={"blink": 1.65})
    L.clip(arm, "idle_variant", 3.0, idle_variant, loop=True, cancel="move", events={"blink": 2.7},
           note="play occasionally between idle loops")
    L.clip(arm, "walk", WALK_D, walk, loop=True, stride_m=WALK_STRIDE, cancel="none",
           events={"foot_L": 0.0, "foot_R": WALK_D / 2})
    L.clip(arm, "run", RUN_D, run, loop=True, stride_m=RUN_STRIDE, cancel="none",
           events={"foot_L": 0.0, "foot_R": RUN_D / 2})
    L.clip(arm, "hop", HOP_D, hop, loop=False, cancel="none", events={"takeoff": HOP_UP, "land": HOP_DOWN})
    L.clip(arm, "start", 0.3, start, loop=False, cancel="none", note="ends on walk frame 0")
    L.clip(arm, "stop", 0.4, stop, loop=False, cancel="move", note="starts on walk frame 0")
    for side, nm in ((1, "turn_left"), (-1, "turn_right")):
        fn, D = turn(side)
        L.clip(arm, nm, D, fn, loop=False, cancel="move")


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
