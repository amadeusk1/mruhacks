"""Cinema clips ('Animation Kit - Cinema'): approach seat -> sit -> watch -> stand. Seat sockets on the
cinema_auditorium seats are at 0.38 m; socket_seat snaps there at 'seated'. WATCH is a relaxed lean-back with
flippers on the armrests and eyes up to the screen. Reactions are small, seated and user-triggered.
"""
import common
import animlib_social as L
from animlib_social import X, Y, Z, ss, bump, cyc, window, aim

KIT = "anim_cinema"
S = common.load_kit("anim_social")

ARM = {"flipper.L": (0.85, -0.3, -0.42), "flipper.R": (-0.85, -0.3, -0.42)}     # on the armrests
BELLY = {"flipper.L": (-0.45, -0.8, -0.4), "flipper.R": (0.45, -0.8, -0.4)}     # laugh
WIDE = {"flipper.L": (0.95, -0.2, 0.25), "flipper.R": (-0.95, -0.2, 0.25)}      # surprised
BEAK = (0.35, -0.85, 0.45)                                                        # snack to the beak


def lerp3(a, b, w):
    return tuple(x + (y - x) * w for x, y in zip(a, b))


def watch_spec(w=1.0, breath=0.0, to=None, tw=0.0, r=None):
    p = S.sit_spec(w, breath)
    p["body"] = {**p["body"], "rot": (X, -14 * w)}       # settled back into the seat
    p["head"]["rot"] = (X, -2 * w)                       # eyes up to the screen
    for b in ARM:
        d = lerp3(ARM[b], to[b], tw) if to else ARM[b]
        p[b] = {"rot": aim(b, r if (r and b == "flipper.R") else d, w)}
    return p


def sit(t):
    hopv = bump(t, 0.06, 0.32)
    p = watch_spec(ss(0.1, 0.45, t))
    p["body"] = {**p["body"], "loc": (0, 0.02 * hopv, 0.05 * hopv - 0.02 * bump(t, 0.38, 0.12))}
    return L.pose(p, morph={"eyes_happy": 0.4 * bump(t, 0.32, 0.18)})


def stand(t):
    hopv = bump(t, 0.05, 0.3)
    p = watch_spec(1 - ss(0.05, 0.4, t))
    p["body"] = {**p["body"], "loc": (0, -0.02 * hopv, 0.05 * hopv - 0.015 * bump(t, 0.36, 0.14))}
    return L.pose(p)


def watch(t):
    u = t / 4.0
    p = watch_spec(1.0, breath=cyc(u))                   # very subtle: breathing, one blink, tiny head drift
    p["head"]["rot"] = [(X, -2 + 1.0 * cyc(u, 1, 0.3)), (Z, 1.5 * cyc(u))]
    return L.pose(p, morph={"eyes_closed": bump(t, 2.6, 0.2)})


def snack(t):
    """popcorn_tub (or drink_cup) in socket_hand_R: lift to the beak, munch twice, rest."""
    up = window(t, 0.1, 0.45, 0.95, 1.4)
    p = watch_spec(1.0, r=lerp3(ARM["flipper.R"], BEAK, up))
    p["head"]["rot"] = [(X, -2 + 8 * up), (Z, -4 * up)]
    munch = bump(t, 0.55, 0.12) + bump(t, 0.72, 0.12)
    return L.pose(p, morph={"beak_open": 0.45 * munch, "eyes_happy": 0.5 * window(t, 0.5, 0.6, 0.85, 0.95)})


def reaction_laugh(t):
    w = window(t, 0.0, 0.2, 1.1, 1.4)
    bob = sum(bump(t, s, 0.18) for s in (0.25, 0.45, 0.65, 0.85))
    p = watch_spec(1.0, to=BELLY, tw=w)
    p["body"] = {**p["body"], "loc": (0, 0, 0.01 * bob), "scl": (1 + 0.008 * bob, 1 + 0.008 * bob, 1 - 0.016 * bob)}
    p["head"]["rot"] = (X, -2 - 6 * w + 3 * bob)
    return L.pose(p, morph={"eyes_happy": w, "beak_open": 0.6 * w * (0.5 + 0.5 * min(1.0, bob))})


def reaction_surprised(t):
    jolt = bump(t, 0.0, 0.25)
    w = window(t, 0.0, 0.12, 0.6, 1.0)
    p = watch_spec(1.0, to=WIDE, tw=w)
    p["body"] = {**p["body"], "rot": (X, -14 + 6 * w), "loc": (0, 0, 0.02 * jolt)}
    p["head"]["rot"] = (X, -2 - 6 * w)
    return L.pose(p, morph={"eyes_wide": w, "beak_open": 0.5 * window(t, 0.05, 0.15, 0.4, 0.6)})


def clips(arm):
    L.clip(arm, "cinema_sit", 0.5, sit, events={"seated": 0.42}, cancel="none",
           note="snap socket_seat to the seat's socket_seat(_N), facing the screen")
    L.clip(arm, "cinema_watch", 4.0, watch, loop=True, cancel="none")
    L.clip(arm, "cinema_snack", 1.6, snack, events={"munch": [0.61, 0.78]}, cancel="none",
           note="optional; popcorn_tub or drink_cup in socket_hand_R")
    L.clip(arm, "cinema_reaction_laugh", 1.4, reaction_laugh, cancel="none", note="user-triggered, seated")
    L.clip(arm, "cinema_reaction_surprised", 1.0, reaction_surprised, cancel="none", note="user-triggered, seated")
    L.clip(arm, "cinema_stand", 0.5, stand, events={"stand": 0.36}, cancel="none")


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
