"""Snowball clips (Animation Kit - Snowballs). The held ball is winter/snowball.glb on socket_hand_R. At
snow_throw's 'release' event gameplay hides the held ball and spawns the projectile exactly once; the held ball
reappears at the clip's end (unlimited snowballs). snow_aim is a held pose for upper-body layering over
locomotion (mask: body, head, flippers). Hit puffs and spawn protection are effects, not part of these clips.
"""
import math
import animlib as L
from animlib import X, Y, Z, ss, bump, cyc, window, flippers, merge

KIT = "anim_snowballs"
BALL = {"asset": "winter/snowball", "socket": "socket_hand_R"}
RELEASE = 0.3

READY = merge(flippers(l=(-6, 22), r=(28, 18)), {"body": {"rot": (X, 5)}, "head": {"rot": (X, -3)}})
AIM = merge(flippers(l=(50, 40), r=(80, -30)), {"body": {"rot": [(Z, -12), (X, -2)]}, "head": {"rot": (Z, 10)}})
WIND = merge(flippers(l=(55, 35), r=(105, -55)), {"body": {"rot": [(Z, -22), (X, -6)], "loc": (0, 0.01, 0)},
                                                  "head": {"rot": (Z, 16)}, "foot.L": {"loc": (0, -0.03, 0.03)}})
THROWN = merge(flippers(l=(25, -10), r=(30, 95)), {"body": {"rot": [(Z, 16), (X, 12)], "loc": (0, -0.02, -0.01)},
                                                   "head": {"rot": [(Z, -6), (X, -4)]}})


def ready(t):
    u = t / 1.2
    return L.add(L.pose(READY), L.pose({"body": {"loc": (0, 0, 0.008 * (0.5 - 0.5 * math.cos(4 * math.pi * u)))},
                                        "head": {"rot": (Z, 5 * cyc(u))}, "flipper.R": {"rot": (X, 4 * cyc(u))}}),
                 {"eyes_closed": bump(t, 0.8, 0.18)})


throw = L.seq([(0.0, READY, {}), (0.2, WIND, {"eyes_wide": 0.3}), (RELEASE, THROWN, {"beak_open": 0.5}),
               (0.42, THROWN, {}), (0.6, READY, {})])
HIT = merge(flippers(l=(55, -10), r=(60, -10)), {"body": {"rot": (X, -13), "loc": (0, 0.03, 0)}, "head": {"rot": [(X, -10), (Y, 8)]}})
hit = L.seq([(0.0, READY, {}), (0.1, HIT, {"eyes_closed": 1.0, "beak_open": 0.5}), (0.3, HIT, {"eyes_happy": 0.8}),
             (0.7, READY, {})],
            overlay=lambda t: ({"head": {"rot": (Z, 9 * math.sin(2 * math.pi * (t - 0.3) / 0.2) * window(t, 0.3, 0.35, 0.55, 0.62))}}, {}))
respawn = L.seq([(0.0, merge(READY, {"body": {"scl": (1.0, 1.0, 1.0)}}), {"eyes_closed": 1.0}),
                 (0.3, merge(READY, {"body": {"scl": (1.05, 1.05, 0.92), "loc": (0, 0, -0.03)}}), {"eyes_closed": 0.3}),
                 (0.5, merge(READY, {"body": {"scl": (0.98, 0.98, 1.03)}}), {"eyes_wide": 0.4}), (0.8, READY, {})],
                overlay=lambda t: ({"root": {"loc": (0, 0, 0.12 * (1 - ss(0.0, 0.3, t)))}}, {}))
CHEER = merge(flippers(l=(105, 15), r=(105, 15)), {"body": {"rot": (X, -7)}, "head": {"rot": (X, -7)}})
result = L.seq([(0.0, READY, {}), (0.2, merge(READY, {"body": {"loc": (0, 0, -0.03)}}), {}),
                (0.45, CHEER, {"eyes_happy": 1, "beak_open": 0.8}), (0.95, CHEER, {"eyes_happy": 1, "beak_open": 0.4}),
                (1.2, READY, {})],
               overlay=lambda t: ({"root": {"loc": (0, 0, 0.06 * bump(t, 0.25, 0.3))}}, {}))


def clips(arm):
    L.clip(arm, "snow_ready", 1.2, ready, loop=True, props=[BALL])
    L.clip(arm, "snow_aim", 0.2, lambda t: L.pose(AIM), props=[BALL], note="held pose; layer over locomotion with an upper-body mask")
    L.clip(arm, "snow_throw", 0.6, throw, cancel="none", events={"release": RELEASE},
           props=[dict(BALL, visible=[0.0, RELEASE]), dict(BALL, visible=[0.55, 0.6], note="new held ball")])
    L.clip(arm, "snow_hit", 0.7, hit, props=[BALL], note="presentation only; hits are resolved by gameplay")
    L.clip(arm, "snow_respawn", 0.8, respawn, cancel="none", props=[dict(BALL, visible=[0.3, 0.8])])
    L.clip(arm, "snow_result", 1.2, result, note="win/celebrate; for a loss play emote_shy")


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
