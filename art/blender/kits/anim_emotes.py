"""Emotes from 'Player Animation - Emotes': each one-shot starts and ends on the rest pose, so it can
blend from and back to idle. Laugh is split into _in / _loop / _out. Sleepy and dance are seamless loops.
Moving cancels any emote (cancel = "move").
"""
import math
import animlib as L
from animlib import X, Y, Z, ss, bump, cyc, window

KIT = "anim_emotes"


def flips(l_out=0.0, r_out=0.0, l_fwd=0.0, r_fwd=0.0):
    """Flipper helper. out > 0 raises the flipper sideways; fwd > 0 swings the tip forward."""
    return {"flipper.L": {"rot": [(Y, -l_out), (X, -l_fwd)]}, "flipper.R": {"rot": [(Y, r_out), (X, -r_fwd)]}}


def tuck(w):
    """Flippers folded in over the belly (laugh, shy)."""
    return {"flipper.L": {"rot": [(Y, 30 * w), (X, -50 * w)]}, "flipper.R": {"rot": [(Y, -30 * w), (X, -50 * w)]}}


def wave(t):
    up = window(t, 0.0, 0.25, 0.9, 1.2)
    wv = math.sin(2 * math.pi * (t - 0.3) / 0.27) if 0.3 < t < 0.84 else 0.0   # two small waves
    return L.pose({"body": {"rot": [(Y, 5 * up), (X, -3 * up)]}, "head": {"rot": [(Y, 7 * up), (X, -4 * up)]},
                   "flipper.R": {"rot": (Y, 104 * up + 14 * wv * up)}, "flipper.L": {"rot": (Y, -6 * up)}},
                  morph={"eyes_happy": window(t, 0.25, 0.4, 0.85, 1.05), "beak_open": 0.6 * window(t, 0.2, 0.32, 0.55, 0.7)})


def happy_bounce(t):
    dip = bump(t, 0.0, 0.3)
    air = bump(t, 0.26, 0.32)
    land = bump(t, 0.58, 0.22)
    arms = window(t, 0.22, 0.32, 0.6, 0.85)
    return L.pose({
        "root": {"loc": (0, 0, 0.09 * air)},
        "body": {"loc": (0, 0, -0.04 * dip - 0.03 * land),
                 "scl": (1 + 0.035 * (dip + land), 1 + 0.035 * (dip + land), 1 - 0.06 * (dip + land) + 0.025 * air),
                 "rot": (X, 5 * dip - 5 * arms)},
        "head": {"rot": (X, 6 * dip - 6 * arms)},
        "foot.L": {"loc": (0, 0, 0.025 * air), "rot": (X, -18 * air)}, "foot.R": {"loc": (0, 0, 0.025 * air), "rot": (X, -18 * air)},
        **flips(62 * arms - 8 * dip, 62 * arms - 8 * dip),
    }, morph={"eyes_happy": window(t, 0.2, 0.3, 0.8, 0.98), "beak_open": 0.7 * window(t, 0.24, 0.32, 0.55, 0.7)})


def laugh_pose(u, w=1.0):
    bob = cyc(u, 2)
    return L.pose({
        "body": {"rot": [(X, -6 * w), (Y, 2 * cyc(u) * w)], "loc": (0, 0, 0.012 * bob * w),
                 "scl": (1 + 0.01 * bob * w, 1 + 0.01 * bob * w, 1 - 0.02 * bob * w)},
        "head": {"rot": [(X, -8 * w + 3 * bob * w), (Y, 3 * cyc(u, 1, 0.25) * w)]},
        **{k: {"rot": v["rot"] + [(X, 5 * bob * w)]} for k, v in tuck(w).items()},
    }, morph={"eyes_happy": w, "beak_open": w * (0.55 + 0.35 * (0.5 + 0.5 * cyc(u, 2, 0.25)))})


LAUGH_LOOP = 0.6


def laugh_in(t):
    return L.mix(L.rest_pose(), laugh_pose(0.0), ss(0.0, 0.3, t))


def laugh_loop(t):
    return laugh_pose(t / LAUGH_LOOP)


def laugh_out(t):
    return L.mix(laugh_pose(0.0), L.rest_pose(), ss(0.0, 0.3, t))


def shy(t):
    w = window(t, 0.0, 0.4, 1.4, 1.8)
    sway = math.sin(2 * math.pi * (t - 0.4) / 1.0) if 0.4 < t < 1.4 else 0.0
    return L.pose({
        "body": {"rot": [(Y, 6 * w + 2 * sway * w), (X, 4 * w)], "scl": (1 - 0.015 * w, 1 - 0.015 * w, 1 + 0.01 * w)},
        "head": {"rot": [(X, 13 * w), (Y, 10 * w), (Z, -8 * w)]},
        **tuck(w),
        "foot.R": {"loc": (0.01 * w, 0, 0.012 * bump(t, 0.6, 0.6)), "rot": (Z, 10 * bump(t, 0.6, 0.6))},
    }, morph={"eyes_closed": 0.55 * window(t, 0.15, 0.4, 0.95, 1.2), "blush": window(t, 0.2, 0.6, 1.45, 1.75),
              "eyes_happy": 0.6 * window(t, 1.0, 1.2, 1.45, 1.7)})


def cheer(t):
    dip = bump(t, 0.0, 0.22)
    air = bump(t, 0.2, 0.32)
    land = bump(t, 0.5, 0.2)
    arms = window(t, 0.16, 0.3, 1.0, 1.3)
    wig = math.sin(2 * math.pi * (t - 0.55) / 0.22) * window(t, 0.55, 0.65, 0.9, 1.0)
    return L.pose({
        "root": {"loc": (0, 0, 0.065 * air)},
        "body": {"loc": (0, 0, -0.035 * dip - 0.025 * land), "rot": (X, 4 * dip - 9 * arms),
                 "scl": (1 + 0.03 * (dip + land), 1 + 0.03 * (dip + land), 1 - 0.05 * (dip + land) + 0.02 * air)},
        "head": {"rot": (X, -7 * arms)},
        "foot.L": {"loc": (0.01 * air, 0, 0.02 * air)}, "foot.R": {"loc": (-0.01 * air, 0, 0.02 * air)},
        **flips(100 * arms + 8 * wig - 10 * dip, 100 * arms - 8 * wig - 10 * dip, -24 * arms, -24 * arms),  # raised: -fwd tips them forward
    }, morph={"eyes_happy": window(t, 0.18, 0.28, 1.0, 1.2), "beak_open": window(t, 0.2, 0.3, 0.85, 1.05)})


SLEEPY_D = 3.0


def sleepy(t):
    u = t / SLEEPY_D
    yawn = window(t, 0.5, 0.9, 1.4, 1.75)
    nod = bump(t, 1.9, 0.9)
    return L.pose({
        "body": {"rot": [(X, 6 + 2 * nod), (Y, 2 * cyc(u))], "scl": (1 - 0.008 * cyc(u), 1 - 0.008 * cyc(u), 1 + 0.015 * cyc(u))},
        "head": {"rot": [(X, 9 + 10 * nod - 14 * yawn), (Y, 4 * cyc(u, 1, 0.2))]},
        "flipper.L": {"rot": [(Y, 3), (X, -4)]},
        "flipper.R": {"rot": [(Y, -18 * yawn), (X, -78 * yawn)]},     # flipper up to the beak for the yawn
    }, morph={"eyes_closed": 0.62 + 0.3 * yawn + 0.08 * nod - 0.1 * bump(t, 2.85, 0.15),
              "beak_open": yawn, "blush": 0.35})


def surprised(t):
    jolt = window(t, 0.0, 0.1, 0.42, 0.65)
    hopb = bump(t, 0.03, 0.2)
    ask = window(t, 0.5, 0.62, 0.78, 0.9)
    return L.pose({
        "root": {"loc": (0, 0, 0.03 * hopb)},
        "body": {"rot": [(X, -11 * jolt), (Y, 4 * ask)], "loc": (0, 0.015 * jolt, 0),
                 "scl": (1 - 0.02 * hopb, 1 - 0.02 * hopb, 1 + 0.03 * hopb)},
        "head": {"rot": [(X, -6 * jolt), (Y, 12 * ask)]},
        "foot.R": {"loc": (0, -0.03 * jolt, 0.04 * jolt), "rot": (X, -24 * jolt)},
        **flips(72 * jolt + 12 * ask, 72 * jolt),
    }, morph={"eyes_wide": max(jolt, 0.6 * ask), "beak_open": 0.85 * window(t, 0.02, 0.1, 0.35, 0.55)})


DANCE_D = 2.4


def dance(t):
    u = t / DANCE_D
    side = math.sin(2 * math.pi * u)                    # one step each side per loop
    beat = 0.5 - 0.5 * math.cos(2 * math.pi * 4 * u)    # four soft bounces
    stepL = max(0.0, math.sin(2 * math.pi * u))
    stepR = max(0.0, -math.sin(2 * math.pi * u))
    return L.pose({
        "body": {"rot": [(Y, 9 * side), (Z, 12 * math.sin(2 * math.pi * u + 0.6)), (X, 2)],
                 "loc": (0.0, 0, -0.018 * beat), "scl": (1 + 0.012 * beat, 1 + 0.012 * beat, 1 - 0.022 * beat)},
        "head": {"rot": [(Y, -5 * side), (X, -3 + 3 * beat)]},
        "foot.L": {"loc": (0.045 * stepL, -0.02 * stepL, 0.03 * stepL * (1 - beat))},
        "foot.R": {"loc": (-0.045 * stepR, -0.02 * stepR, 0.03 * stepR * (1 - beat))},
        **flips(30 + 22 * side, 30 - 22 * side, 12 * math.sin(2 * math.pi * 2 * u), -12 * math.sin(2 * math.pi * 2 * u)),
    }, morph={"eyes_happy": 1.0, "beak_open": 0.25 + 0.25 * math.sin(2 * math.pi * 2 * u) ** 2})


def clips(arm):
    L.clip(arm, "emote_wave", 1.2, wave)
    L.clip(arm, "emote_happy_bounce", 1.0, happy_bounce, events={"land": 0.6})
    L.clip(arm, "emote_laugh_in", 0.3, laugh_in, note="then emote_laugh (loop)")
    L.clip(arm, "emote_laugh", LAUGH_LOOP, laugh_loop, loop=True, note="loop body of emote_laugh_in -> emote_laugh -> emote_laugh_out")
    L.clip(arm, "emote_laugh_out", 0.3, laugh_out, note="from any emote_laugh frame: blend 0.1 s, then this")
    L.clip(arm, "emote_shy", 1.8, shy)
    L.clip(arm, "emote_cheer", 1.3, cheer, events={"land": 0.5})
    L.clip(arm, "emote_sleepy", SLEEPY_D, sleepy, loop=True, events={"yawn": 0.9})
    L.clip(arm, "emote_surprised", 0.9, surprised)
    L.clip(arm, "emote_dance", DANCE_D, dance, loop=True, events={"beat": [i * DANCE_D / 4 for i in range(4)]})


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
