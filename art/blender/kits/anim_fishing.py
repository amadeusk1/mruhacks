"""Fishing clips (Animation Kit - Fishing). The rod is avatar/fishing_rod.glb on socket_hand_R; the fishing line
runs from the rod's socket_line_tip to the bobber (both gameplay/effects, not in these clips).
Flow: fish_equip -> fish_cast -> fish_wait (loop) -> fish_hook -> fish_reel (loop) -> fish_catch | fish_escape
-> fish_wait or fish_stow. All clips stay planted in place; cancel = "move" except during the cast.
"""
import math
import animlib as L
from animlib import X, Y, Z, ss, bump, cyc, window, flippers, merge

KIT = "anim_fishing"
ROD = [{"asset": "avatar/fishing_rod", "socket": "socket_hand_R", "line_from": "socket_line_tip"}]

HOLD = merge(flippers(l=(-22, 48), r=(-8, 34)), {"body": {"rot": (X, 3)}, "head": {"rot": (X, -3)}})
BACK = merge(flippers(l=(-14, 30), r=(62, -38)), {"body": {"rot": [(X, -9), (Z, -12)]}, "head": {"rot": (X, -8)},
                                                   "foot.L": {"loc": (0, -0.02, 0.02)}})
FWD = merge(flippers(l=(-20, 55), r=(18, 78)), {"body": {"rot": [(X, 12), (Z, 8)], "loc": (0, -0.015, -0.01)},
                                                 "head": {"rot": (X, -6)}})
TUG = merge(flippers(l=(-20, 40), r=(10, 8)), {"body": {"rot": (X, -10), "loc": (0, 0.02, 0)}, "head": {"rot": (X, -8)}})
PROUD = merge(flippers(l=(40, 10), r=(70, 25)), {"body": {"rot": (X, -6), "scl": (0.99, 0.99, 1.02)}, "head": {"rot": [(X, -8), (Y, -6)]}})
SLUMP = merge(flippers(l=(-6, 20), r=(-4, 14)), {"body": {"rot": (X, 9), "loc": (0, 0, -0.012), "scl": (1.01, 1.01, 0.985)},
                                                 "head": {"rot": [(X, 14), (Y, 5)]}})


def breath(t, D):
    u = t / D
    return {"body": {"scl": (1 - 0.006 * cyc(u), 1 - 0.006 * cyc(u), 1 + 0.012 * cyc(u)), "loc": (0, 0, 0.004 * cyc(u))}}


equip = L.seq([(0.0, {}, {}), (0.25, merge(flippers(l=(-10, 20), r=(-15, 40)), {"body": {"rot": (X, 6)}}), {}), (0.6, HOLD, {})])
stow = L.seq([(0.0, HOLD, {}), (0.3, merge(flippers(l=(-10, 20), r=(-15, 40)), {"body": {"rot": (X, 6)}}), {}), (0.6, {}, {})])
cast = L.seq([(0.0, HOLD, {}), (0.18, merge(HOLD, {"body": {"rot": (X, 5)}}), {}), (0.42, BACK, {"eyes_wide": 0.3}),
              (0.58, FWD, {"beak_open": 0.3}), (0.75, FWD, {}), (1.0, HOLD, {})])


def wait(t):
    D = 3.0
    p = L.pose(HOLD, {"eyes_closed": bump(t, 1.8, 0.2)})
    adj = bump(t, 1.0, 0.5)
    return L.add(p, L.pose(merge(breath(t, D), {"flipper.R": {"rot": (X, -4 * adj)}, "flipper.L": {"rot": (X, 3 * cyc(t / D))},
                                                "head": {"rot": (Z, 5 * window(t, 2.0, 2.3, 2.6, 2.9))}})))


hook = L.seq([(0.0, HOLD, {}), (0.12, TUG, {"eyes_wide": 1.0, "beak_open": 0.6}), (0.4, merge(HOLD, {"body": {"rot": (X, -5)}}), {"eyes_wide": 0.4})])


def reel(t):
    D = 0.8
    u = t / D
    base = L.pose(merge(HOLD, {"body": {"rot": (X, -6)}}), {"eyes_closed": 0.35})
    crank = {"flipper.L": {"rot": [(X, -14 * math.sin(2 * math.pi * 2 * u)), (Y, 8 * math.cos(2 * math.pi * 2 * u))]},
             "body": {"rot": [(Y, 3 * cyc(u)), (X, -2 * cyc(u, 2))]}, "flipper.R": {"rot": (X, 4 * cyc(u))}}
    return L.add(base, L.pose(crank), {"beak_open": 0.2 + 0.1 * cyc(u, 2)})


catch = L.seq([(0.0, HOLD, {}), (0.3, PROUD, {"eyes_happy": 1.0, "beak_open": 0.7}),
               (1.0, PROUD, {"eyes_happy": 1.0, "beak_open": 0.3}), (1.4, HOLD, {})],
              overlay=lambda t: ({"root": {"loc": (0, 0, 0.04 * bump(t, 0.25, 0.3))}}, {}))
escape = L.seq([(0.0, TUG, {"eyes_wide": 0.5}), (0.25, SLUMP, {"eyes_closed": 0.6}), (0.85, SLUMP, {"eyes_closed": 0.5}),
                (1.2, HOLD, {})])


def clips(arm):
    L.clip(arm, "fish_equip", 0.6, equip, cancel="move", props=[dict(ROD[0], visible=[0.2, 0.6])], events={"grip": 0.2})
    L.clip(arm, "fish_cast", 1.0, cast, cancel="none", props=ROD, events={"line_release": 0.5})
    L.clip(arm, "fish_wait", 3.0, wait, loop=True, props=ROD)
    L.clip(arm, "fish_hook", 0.4, hook, cancel="none", props=ROD, note="play on the authoritative bite, then fish_reel")
    L.clip(arm, "fish_reel", 0.8, reel, loop=True, cancel="none", props=ROD)
    L.clip(arm, "fish_catch", 1.4, catch, props=ROD, events={"show_fish": 0.3})
    L.clip(arm, "fish_escape", 1.2, escape, props=ROD)
    L.clip(arm, "fish_stow", 0.6, stow, props=[dict(ROD[0], visible=[0.0, 0.4])], events={"release_rod": 0.4})


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
