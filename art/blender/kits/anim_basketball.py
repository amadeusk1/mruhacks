"""Basketball clips (Animation Kit - Basketball). The ball (activities/basketball.glb, origin = ball centre,
r 0.12 m) is held in front of the belly between both flippers, so each clip that shows it carries a sampled prop_path (Godot Y-up,
relative to the avatar origin). At basket_shoot / basket_pass 'release' gameplay takes the ball over.
The flippers are shorter than the belly is deep, so they angle forward along the ball's sides rather than
wrapping it; the ball rests 6 cm off the bare belly so it also clears the thickest coat (raincoat).
Shooting-contest clips are the baseline; possession clips are tagged extension = true.
"""
import math
import animlib as L
from animlib import X, Y, Z, ss, bump, cyc, window, flippers, merge
from mathutils import Vector

KIT = "anim_basketball"
BALL = "activities/basketball"
R = 0.12

HOLD = merge(flippers(l=(-38, 58), r=(-38, 58)), {"body": {"rot": (X, 3)}, "head": {"rot": (X, -4)}})
CHARGE = merge(flippers(l=(-38, 50), r=(-38, 50)), {"body": {"rot": (X, 8), "loc": (0, 0, -0.04), "scl": (1.03, 1.03, 0.95)},
                                                     "head": {"rot": (X, -10)}})
LIFT = merge(flippers(l=(-24, 132), r=(-24, 132)), {"body": {"rot": (X, -6), "loc": (0, 0, 0.01)}, "head": {"rot": (X, -12)}})
FOLLOW = merge(flippers(l=(-8, 142), r=(-8, 142)), {"body": {"rot": (X, -3)}, "head": {"rot": (X, -14)}})


def held(t, arm):
    return L.clear_of_body(arm, L.between_flippers(arm, fwd=0.0, along=0.03), R, gap=0.06)  # thickest coat shell


def until(t_end, fn=held):
    return lambda t, arm: fn(t, arm) if t <= t_end + 1e-6 else None


def hold(t):
    u = t / 2.0
    return L.add(L.pose(HOLD), L.pose({"body": {"scl": (1 - 0.006 * cyc(u), 1 - 0.006 * cyc(u), 1 + 0.012 * cyc(u))},
                                       "head": {"rot": (Z, 3 * cyc(u))}}), {"eyes_closed": bump(t, 1.2, 0.18)})


shoot = L.seq([(0.0, CHARGE, {}), (0.3, LIFT, {"eyes_wide": 0.3}), (0.4, merge(LIFT, {"body": {"loc": (0, 0, 0.02)}}), {}),
               (0.55, FOLLOW, {"beak_open": 0.4}), (0.8, FOLLOW, {})],
              overlay=lambda t: ({"root": {"loc": (0, 0, 0.035 * bump(t, 0.3, 0.3))}}, {}))
recover = L.seq([(0.0, FOLLOW, {}), (0.5, HOLD, {})])
CHEER = merge(flippers(l=(100, 20), r=(100, 20)), {"body": {"rot": (X, -6)}})
score = L.seq([(0.0, HOLD, {}), (0.3, CHEER, {"eyes_happy": 1, "beak_open": 0.7}), (0.75, CHEER, {"eyes_happy": 1}), (1.0, HOLD, {})],
              overlay=lambda t: ({"root": {"loc": (0, 0, 0.04 * bump(t, 0.25, 0.28))}}, {}))
SHRUG = merge(flippers(l=(42, 18), r=(42, 18)), {"body": {"scl": (0.99, 0.99, 1.02)}, "head": {"rot": [(Y, 12), (X, 4)]}})
miss = L.seq([(0.0, HOLD, {}), (0.3, SHRUG, {"eyes_closed": 0.5}), (0.7, SHRUG, {"eyes_closed": 0.4, "beak_open": 0.2}), (1.0, HOLD, {})])

# extension: possession play
GROUND = Vector((0.0, -0.3, R))
BEND = merge(flippers(l=(-32, 74), r=(-32, 74)), {"body": {"rot": (X, 24), "loc": (0, -0.03, -0.05)}, "head": {"rot": (X, -14)}})
pickup = L.seq([(0.0, {}, {}), (0.35, BEND, {}), (0.7, HOLD, {})])


def pickup_ball(t, arm):
    return GROUND if t < 0.35 else held(t, arm)


DR = merge(flippers(l=(-4, 18), r=(8, 55)), {"body": {"rot": [(X, 9), (Z, 6)], "loc": (0, 0, -0.025)}, "head": {"rot": (X, -6)}})


def dribble(t):
    u = t / 0.6
    push = math.cos(2 * math.pi * u)                    # hand high at u=0, pushing down after
    return L.add(L.pose(DR), L.pose({"flipper.R": {"rot": (X, -12 * push)}, "body": {"loc": (0, 0, -0.01 * push)}}))


def dribble_ball(t, arm):
    u = t / 0.6
    top = L.tip(arm, "flipper.R", 0.02)
    hi = top.z - R - 0.01
    return Vector((top.x, top.y - 0.05, R + (hi - R) * abs(math.cos(math.pi * u))))


PASS = merge(flippers(l=(-26, 86), r=(-26, 86)), {"body": {"rot": (X, 12), "loc": (0, -0.02, 0)}, "head": {"rot": (X, -6)}})
pas = L.seq([(0.0, HOLD, {}), (0.12, merge(HOLD, {"body": {"rot": (X, -5)}}), {}), (0.3, PASS, {"beak_open": 0.4}), (0.6, HOLD, {})])
OPEN = merge(flippers(l=(-14, 76), r=(-14, 76)), {"head": {"rot": (X, -6)}})
receive = L.seq([(0.0, OPEN, {"eyes_wide": 0.5}), (0.15, merge(HOLD, {"body": {"rot": (X, -8), "loc": (0, 0.02, 0)}}), {"eyes_closed": 0.4}),
                 (0.5, HOLD, {})])


def receive_ball(t, arm):
    if t >= 0.15:
        return held(t, arm)
    w = t / 0.15
    return Vector((0, -0.9, 0.55)).lerp(held(t, arm), w)


def clips(arm):
    ext = {"extension": True}
    L.clip(arm, "basket_hold", 2.0, hold, loop=True, prop_path=(BALL, held))
    L.clip(arm, "basket_charge", 0.2, lambda t: L.pose(CHARGE), prop_path=(BALL, held), note="held pose; blend by charge amount")
    L.clip(arm, "basket_shoot", 0.8, shoot, cancel="none", events={"release": 0.4}, prop_path=(BALL, until(0.4)))
    L.clip(arm, "basket_recover", 0.5, recover, note="no ball; gameplay hands the next ball (attach at the end, or basket_receive)")
    L.clip(arm, "basket_score", 1.0, score, note="cosmetic; never delays the next accepted shot")
    L.clip(arm, "basket_miss", 1.0, miss)
    L.clip(arm, "basket_pickup", 0.7, pickup, cancel="none", events={"grab": 0.35}, prop_path=(BALL, pickup_ball), extra=ext)
    L.clip(arm, "basket_dribble", 0.6, dribble, loop=True, cancel="none", events={"bounce": 0.3}, prop_path=(BALL, dribble_ball), extra=ext)
    L.clip(arm, "basket_pass", 0.6, pas, cancel="none", events={"release": 0.3}, prop_path=(BALL, until(0.3)), extra=ext)
    L.clip(arm, "basket_receive", 0.5, receive, cancel="none", events={"catch": 0.15}, prop_path=(BALL, receive_ball), extra=ext)


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
