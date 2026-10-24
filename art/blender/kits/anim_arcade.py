"""Arcade clips ('Animation Kit - Arcade'): approach -> claim station -> ready -> playing -> results -> exit.
The penguin stands at a cabinet's socket_player_N facing the cabinet. Left flipper works the joystick, right
flipper the buttons (socket_grip_<N>_L / _R). Flippers reach forward, inside the body's width, so two players at
one duo cabinet don't sweep into each other. enter ends on READY; ready/play loop on READY; both results start
and end on READY; exit goes READY -> rest. Manifest 'grip_targets' gives where the flipper tips actually are,
relative to socket_player_N, for cabinet authors.
"""
import animlib_social as L
from animlib_social import X, Y, Z, ss, bump, cyc, window, aim

KIT = "anim_arcade"

DIR = {"flipper.L": (0.12, -0.94, 0.22), "flipper.R": (-0.12, -0.94, 0.22)}   # forward to the control deck
UP = {"flipper.L": (0.5, -0.1, 0.86), "flipper.R": (-0.5, -0.1, 0.86)}        # cheer
OUT = {"flipper.L": (0.8, -0.5, 0.05), "flipper.R": (-0.8, -0.5, 0.05)}       # shrug


def lerp3(a, b, w):
    return tuple(x + (y - x) * w for x, y in zip(a, b))


def ready_spec(w=1.0, breath=0.0, to=None, tw=0.0):
    """READY blended in by w from rest; optionally blended toward another flipper direction set `to` by tw."""
    p = {
        "body": {"rot": (X, 5 * w), "loc": (0, 0, 0.004 * breath),
                 "scl": (1 - 0.005 * breath, 1 - 0.005 * breath, 1 + 0.01 * breath)},
        "head": {"rot": (X, -4 * w)},
    }
    for b in DIR:
        d = lerp3(DIR[b], to[b], tw) if to else DIR[b]
        p[b] = {"rot": aim(b, d, w)}
    return p


def enter(t):
    w = ss(0.12, 0.55, t)
    p = ready_spec(w)
    s1, s2 = bump(t, 0.0, 0.25), bump(t, 0.12, 0.25)  # little alignment shuffle to the station
    p["foot.L"] = {"loc": (0.015 * s1, -0.02 * s1, 0.02 * s1)}
    p["foot.R"] = {"loc": (-0.015 * s2, -0.02 * s2, 0.02 * s2)}
    return L.pose(p, morph={"eyes_wide": 0.3 * window(t, 0.3, 0.45, 0.5, 0.6)})


def ready(t):
    u = t / 2.0
    p = ready_spec(1.0, breath=cyc(u))
    p["flipper.L"]["rot"] += [(X, 2 * cyc(u, 1, 0.3))]   # hovering over the stick
    p["flipper.R"]["rot"] += [(X, 2 * cyc(u, 1, 0.55))]
    p["head"]["rot"] = (X, -4 + 1.5 * cyc(u, 1, 0.2))
    return L.pose(p, morph={"eyes_closed": bump(t, 1.2, 0.2)})


PLAY = 1.2
TAPS = (0.15, 0.45, 0.6, 0.95)  # button presses within the loop


def play(t):
    u = t / PLAY
    p = ready_spec(1.0, breath=cyc(u, 2))
    tap = sum(bump(t, s, 0.1) for s in TAPS)
    p["flipper.L"]["rot"] += [(X, 5 * cyc(u, 3, 0.25)), (Z, 6 * cyc(u, 2))]   # joystick nudges
    p["flipper.R"]["rot"] += [(X, 7 * tap)]                                    # button dips
    p["body"]["rot"] = [(X, 5), (Z, 2.5 * cyc(u, 2))]                          # leans into the game
    p["head"]["rot"] = [(X, -5 + 1.5 * cyc(u, 2, 0.1)), (Z, 3 * cyc(u, 2))]
    return L.pose(p, morph={"eyes_wide": 0.2})


def result(t):
    """Win: brief cheer, then back to the controls."""
    up = window(t, 0.05, 0.25, 0.65, 0.95)
    air = bump(t, 0.2, 0.3)
    p = ready_spec(1.0, to=UP, tw=up)
    p["root"] = {"loc": (0, 0, 0.05 * air)}
    p["body"] = {"rot": (X, 5 - 11 * up), "loc": (0, 0, -0.025 * bump(t, 0.0, 0.2))}
    p["foot.L"] = {"loc": (0, 0, 0.02 * air)}
    p["foot.R"] = {"loc": (0, 0, 0.02 * air)}
    return L.pose(p, morph={"eyes_happy": window(t, 0.1, 0.2, 0.75, 0.95),
                            "beak_open": 0.7 * window(t, 0.15, 0.25, 0.5, 0.65)})


def result_shrug(t):
    """Lose: small shrug and head shake, then back to the controls."""
    s = window(t, 0.05, 0.3, 0.6, 0.9)
    p = ready_spec(1.0, to=OUT, tw=0.7 * s)
    p["body"] = {"rot": (X, 5 - 3 * s), "loc": (0, 0, 0.015 * s)}
    p["head"] = {"rot": [(X, -4 + 8 * s), (Z, 10 * bump(t, 0.25, 0.25) - 10 * bump(t, 0.5, 0.25))]}
    return L.pose(p, morph={"eyes_closed": 0.4 * s})


def exit_(t):
    p = ready_spec(1 - ss(0.0, 0.4, t))
    b1, b2 = bump(t, 0.1, 0.3), bump(t, 0.2, 0.3)  # small step back from the cabinet
    p["foot.L"] = {"loc": (0, 0.03 * b1, 0.02 * b1)}
    p["foot.R"] = {"loc": (0, 0.03 * b2, 0.02 * b2)}
    return L.pose(p)


def clips(arm):
    note = "plays at socket_player_N facing the cabinet; flipper.L = joystick, flipper.R = buttons"
    L.clip(arm, "arcade_enter", 0.6, enter, events={"at_controls": 0.55}, cancel="none", note=note)
    L.clip(arm, "arcade_ready", 2.0, ready, loop=True, cancel="none")
    L.clip(arm, "arcade_play", PLAY, play, loop=True, events={"button_tap": list(TAPS)}, cancel="none",
           note="visual only: gameplay input drives the game, not this loop")
    L.clip(arm, "arcade_result", 1.0, result, cancel="none", note="win; starts and ends on the ready pose")
    L.clip(arm, "arcade_result_shrug", 1.0, result_shrug, cancel="none", note="lose; starts and ends on the ready pose")
    L.clip(arm, "arcade_exit", 0.5, exit_, events={"released": 0.4})


def build():
    import common
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
    L.play(arm, "arcade_ready", 0)
    tips = {b: [round(v, 3) for v in arm.pose.bones[b].tail] for b in DIR}
    L.stop(arm)
    for a in common.ASSETS:  # contract for cabinet authors: where the flipper tips are, relative to socket_player_N
        if a["obj"] is arm:
            a["meta"]["grip_targets"] = {"frame": "avatar local (front -Y), arcade_ready frame 0", **tips}
