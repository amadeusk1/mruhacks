"""Drawing telephone clips ('Animation Kit - Drawing Telephone'): sit -> think -> draw -> wait -> reveal -> stand.
Seated on a stool at the table (plaza stool seat 0.44 m; table top 0.6 m). socket_seat snaps to the stool top at
'seated'. TABLE is the seated-at-table pose: leaning in, flippers down on the table, pencil in socket_hand_R.
think/draw/wait/reveal all start and end on TABLE. Gestures stay generic: nothing hints at what is drawn.
"""
import common
import animlib as L
from animlib import X, Y, Z, ss, bump, cyc, window, aim

KIT = "anim_drawing"
S = common.load_kit("anim_social")  # shared seated pose (sit_spec) and its hop on/off timing

TABLE = {"flipper.L": (-0.12, -0.75, -0.6), "flipper.R": (0.12, -0.75, -0.6)}   # down onto the pad
CHIN = (0.45, -0.6, 0.35)                                                        # pencil to the beak, thinking
REST_PENCIL = (0.05, -0.55, -0.83)
OPEN = {"flipper.L": (0.7, -0.5, 0.15), "flipper.R": (-0.7, -0.5, 0.15)}         # reveal laugh


def lerp3(a, b, w):
    return tuple(x + (y - x) * w for x, y in zip(a, b))


def table_spec(w=1.0, breath=0.0, r=None, open_w=0.0):
    p = S.sit_spec(w, breath)
    p["body"] = {**p["body"], "rot": (X, 8 * w)}         # lean in over the pad instead of back
    p["head"]["rot"] = (X, 13 * w)                       # looking down at the pad
    for b in TABLE:
        d = lerp3(TABLE[b], OPEN[b], open_w)
        p[b] = {"rot": aim(b, r if (r and b == "flipper.R") else d, w)}
    return p


def sit(t):
    hopv = bump(t, 0.06, 0.32)
    p = table_spec(ss(0.1, 0.5, t))
    p["body"] = {**p["body"], "loc": (0, 0.02 * hopv, 0.05 * hopv - 0.02 * bump(t, 0.38, 0.12))}
    return L.pose(p)


def stand(t):
    hopv = bump(t, 0.05, 0.3)
    p = table_spec(1 - ss(0.05, 0.4, t))
    p["body"] = {**p["body"], "loc": (0, -0.02 * hopv, 0.05 * hopv - 0.015 * bump(t, 0.36, 0.14))}
    return L.pose(p)


def think(t):
    u = t / 2.4
    lift = 0.5 + 0.5 * cyc(u, 1, 0.75)                   # pencil drifts up to the beak and back down
    p = table_spec(1.0, breath=cyc(u), r=lerp3(TABLE["flipper.R"], CHIN, 0.8 * lift))
    p["head"]["rot"] = [(X, 8 + 2 * cyc(u, 2)), (Y, 9 * cyc(u))]   # slow thoughtful tilt
    return L.pose(p, morph={"eyes_closed": bump(t, 0.7, 0.2)})


DRAW = 1.6
STROKES = (0.1, 0.45, 0.85, 1.2)


def draw(t):
    u = t / DRAW
    p = table_spec(1.0, breath=cyc(u, 2))
    glance = window(t, 0.62, 0.72, 0.82, 0.92)           # glances up between strokes
    p["head"]["rot"] = [(X, 13 - 11 * glance), (Z, 3 * cyc(u, 2))]
    p["flipper.R"]["rot"] += [(X, 4 * cyc(u, 4)), (Z, 6 * cyc(u, 4, 0.25))]   # small strokes
    p["flipper.L"]["rot"] += [(X, 1.5 * cyc(u, 2, 0.5))]                     # holding the pad
    p["body"]["rot"] = [(X, 8), (Z, 2 * cyc(u, 2))]
    return L.pose(p, morph={"eyes_closed": bump(t, 0.75, 0.12)})


def wait(t):
    u = t / 2.0
    settle = 0.5 + 0.5 * cyc(u, 1, 0.75)                 # pencil rests on the table, lifts a touch now and then
    p = table_spec(1.0, breath=cyc(u), r=lerp3(REST_PENCIL, TABLE["flipper.R"], 0.3 * settle))
    p["head"]["rot"] = [(X, 6), (Z, 10 * cyc(u))]        # looks around the table at the others
    p["body"]["rot"] = [(X, 6), (Y, 2 * cyc(u, 1, 0.25))]
    return L.pose(p, morph={"eyes_closed": bump(t, 1.1, 0.2)})


def reveal(t):
    """Seated laugh at the reveal, constrained to the stool; back to TABLE at the end."""
    w = window(t, 0.0, 0.2, 0.95, 1.2)
    bob = bump(t, 0.25, 0.18) + bump(t, 0.45, 0.18) + bump(t, 0.65, 0.18)
    p = table_spec(1.0, open_w=0.8 * w)
    p["body"] = {**p["body"], "rot": (X, 8 - 16 * w), "loc": (0, 0, 0.012 * bob),
                 "scl": (1 + 0.01 * bob, 1 + 0.01 * bob, 1 - 0.02 * bob)}
    p["head"]["rot"] = (X, 13 - 23 * w + 3 * bob)
    return L.pose(p, morph={"eyes_happy": w, "beak_open": 0.75 * w * (0.6 + 0.4 * min(1.0, bob))})


def clips(arm):
    L.clip(arm, "sketch_sit", 0.5, sit, events={"seated": 0.42}, cancel="none",
           note="snap socket_seat to the stool top at socket_seat_N of communal_table / sketch_table, facing the table")
    L.clip(arm, "sketch_think", 2.4, think, loop=True, cancel="none")
    L.clip(arm, "sketch_draw", DRAW, draw, loop=True, events={"stroke": list(STROKES)}, cancel="none",
           note="pencil in socket_hand_R; generic scribbling only, never the private drawing")
    L.clip(arm, "sketch_wait", 2.0, wait, loop=True, cancel="none", note="after submitting: pencil rests")
    L.clip(arm, "sketch_reveal", 1.2, reveal, cancel="none", note="seated laugh at the shared reveal")
    L.clip(arm, "sketch_stand", 0.5, stand, events={"stand": 0.36}, cancel="none")


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
