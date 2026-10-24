"""Everyday interaction clips ('Animation Kit - Everyday Penguin Interactions').
pick_up -> carry_hold (upper-body layer over walk) -> place: a prop carried at the belly in both flippers, riding
the virtual socket 'carry' documented in meta (gameplay attaches the prop there at 'grasp', detaches at 'release').
stool_back_up_sit ends on anim_social's seated pose, so sit_idle / sit_exit follow. step_up climbs one 0.25 m
stone step (town_connections). sip uses the mug in socket_hand_R. drawer_open targets room_kit writing_desk's
part_drawer (handle 0.45 m high, 0.28 m ahead of socket_use, slides 0.25 m).
Existing clips are kept: anim_home place_item (one flipper, from hold_item_idle) and anim_social sit_* still apply.
"""
import common
import animlib_social as L
from animlib_social import X, Y, Z, ss, bump, cyc, window, aim

KIT = "anim_everyday"
S = common.load_kit("anim_social")

CARRY = {"flipper.L": (-0.38, -0.84, -0.28), "flipper.R": (0.38, -0.84, -0.28)}  # both flippers meet at the belly
LOW = {"flipper.L": (-0.2, -0.72, -0.66), "flipper.R": (0.2, -0.72, -0.66)}      # down to the floor
SET = {"flipper.L": (-0.25, -0.92, -0.05), "flipper.R": (0.25, -0.92, -0.05)}    # out over a table top
STEP_H = 0.25
STOOL_H = 0.44
HANDLE, PULLED = (0.28, -0.94, -0.12), (0.35, -0.62, -0.62)
SIP = (0.55, -0.62, 0.42)
UPPER = ("body", "head", "flipper.L", "flipper.R")


def lerp3(a, b, w):
    return tuple(x + (y - x) * w for x, y in zip(a, b))


def flips(a, b, w, blend=1.0):
    """Both flippers aimed at set a blended toward set b by w, the whole thing blended in from rest by `blend`."""
    return {f: {"rot": aim(f, lerp3(a[f], b[f], w), blend)} for f in a}


def carry_spec(w=1.0, breath=0.0):
    return {"body": {"rot": (X, -4 * w), "loc": (0, 0, 0.004 * breath)},   # lean back a touch to balance the load
            "head": {"rot": (X, 8 * w)},                                    # glance down at what it holds
            **flips(CARRY, CARRY, 0, w)}


def pick_up(t):
    look = window(t, 0.0, 0.2, 0.3, 0.45)
    crouch = window(t, 0.2, 0.45, 0.7, 1.0)
    reach = ss(0.25, 0.5, t) * (1 - ss(0.6, 0.95, t))     # down to the pot, then up with it
    held = ss(0.6, 0.95, t)
    p = {"body": {"rot": (X, 26 * crouch - 4 * held), "loc": (0, 0.03 * crouch, 0.04 * crouch),  # bend, and lift so the belly clears the floor
                  "scl": (1 + 0.01 * crouch, 1 + 0.01 * crouch, 1 - 0.02 * crouch)},
         "head": {"rot": (X, 12 * look + 2 * crouch + 8 * held * (1 - crouch))},
         **{f: {"rot": aim(f, lerp3(LOW[f], CARRY[f], held), max(reach, held))} for f in CARRY}}
    return L.pose(p, morph={"eyes_wide": 0.25 * look})


def carry_hold(t):
    u = t / 0.8  # one walk cycle, so the bob lines up with anim_locomotion walk
    p = carry_spec(1.0, breath=cyc(u, 2))
    for f in CARRY:
        p[f]["rot"] += [(X, 1.5 * cyc(u, 2, 0.1))]
    return L.pose(p)


def place(t):
    lower = window(t, 0.1, 0.45, 0.65, 1.1)
    let_go = ss(0.55, 0.8, t)
    p = {"body": {"rot": (X, -4 + 14 * lower), "loc": (0, 0, -0.02 * lower)},
         "head": {"rot": (X, 8 + 6 * lower)},
         **{f: {"rot": aim(f, lerp3(CARRY[f], SET[f], ss(0.1, 0.45, t)), 1 - ss(0.65, 1.1, t))} for f in CARRY}}
    return L.pose(p, morph={"eyes_happy": 0.6 * window(t, 0.7, 0.8, 1.0, 1.1) * let_go})


def stool_back_up_sit(t):
    back = 1 - ss(0.0, 0.5, t)
    s1, s2 = bump(t, 0.0, 0.25), bump(t, 0.2, 0.25)       # two little backward steps (gameplay owns the travel)
    look = window(t, 0.0, 0.12, 0.35, 0.5)                 # glance back over the shoulder at the stool
    w = ss(0.5, 0.85, t)
    hopv = bump(t, 0.5, 0.3)
    p = S.sit_spec(w)
    p["body"] = {**p["body"], "loc": (0, 0.02 * hopv, 0.05 * hopv - 0.02 * bump(t, 0.78, 0.12))}
    p["head"] = {"rot": [(X, 6 * w), (Z, 35 * look)]}
    for fb, s in (("foot.L", s1), ("foot.R", s2)):
        x, y, z = p[fb]["loc"]
        p[fb]["loc"] = (x, y + 0.05 * s * back, z + 0.025 * s * back)
    return L.pose(p, morph={"eyes_happy": 0.5 * bump(t, 0.75, 0.2)})


def step_up(t):
    rise = ss(0.25, 0.55, t)                               # root rises with the weight shift
    lead = ss(0.05, 0.3, t)                                # lead foot lifts onto the step first
    trail = ss(0.45, 0.7, t)
    lift_l = bump(t, 0.05, 0.25) * 0.05
    lift_r = bump(t, 0.45, 0.25) * 0.05
    return L.pose({
        "root": {"loc": (0, 0, STEP_H * rise)},
        "foot.L": {"loc": (0, 0, STEP_H * (lead - rise) + lift_l)},
        "foot.R": {"loc": (0, 0, STEP_H * (trail - rise) + lift_r)},
        "body": {"rot": [(X, 10 * window(t, 0.15, 0.35, 0.5, 0.75)), (Y, 5 * window(t, 0.1, 0.25, 0.35, 0.5))],
                 "loc": (0, 0, -0.025 * bump(t, 0.15, 0.3) - 0.02 * bump(t, 0.68, 0.22))},
        "flipper.L": {"rot": (Y, -14 * bump(t, 0.1, 0.5))}, "flipper.R": {"rot": (Y, 14 * bump(t, 0.1, 0.5))},
    })


def sip(t):
    up = window(t, 0.15, 0.5, 1.1, 1.45)
    hold = S.HOLD["flipper.R"]
    hold_p = L.pose({"flipper.R": {"rot": list(hold)}})
    lift_p = L.pose({"flipper.R": {"rot": aim("flipper.R", SIP)}, "head": {"rot": (X, -10)}, "body": {"rot": (X, -4)}})
    p = L.mix(hold_p, lift_p, up)
    p.morph.update({"eyes_closed": window(t, 0.55, 0.65, 0.9, 1.0), "eyes_happy": 0.6 * window(t, 0.95, 1.05, 1.3, 1.45)})
    return p


def drawer_open(t):
    reach = window(t, 0.05, 0.35, 1.55, 1.85)
    pull = ss(0.4, 0.7, t) * (1 - ss(1.25, 1.55, t))
    look = window(t, 0.75, 0.9, 1.1, 1.25)
    return L.pose({
        "body": {"rot": [(X, 10 * reach + 14 * look), (Z, -5 * reach)], "loc": (0, 0, 0.0014 * (10 * reach + 14 * look))},
        "head": {"rot": [(X, 4 * reach + 9 * look), (Z, -6 * reach)]},
        "flipper.R": {"rot": aim("flipper.R", lerp3(HANDLE, PULLED, pull), reach)},
        "flipper.L": {"rot": (Y, -8 * reach)},
        "foot.R": {"loc": (0, -0.03 * reach, 0.015 * bump(t, 0.0, 0.3))},
    }, morph={"eyes_wide": 0.4 * look})


def upper_only(name):
    """Strip the lower-body channels so carry_hold layers over walk (keys only on body, head and flippers)."""
    act = bpy.data.actions[L._L.ACTION[name]]
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in [fc for fc in bag.fcurves if fc.data_path.startswith("pose.bones[")
                           and fc.data_path.split('"')[1] not in UPPER]:
                    bag.fcurves.remove(fc)


import bpy  # noqa: E402  (after the helpers above, which only need it at call time)


def clips(arm):
    L.clip(arm, "pick_up", 1.2, pick_up, events={"grasp": 0.55}, cancel="none",
           note="attach the prop to the 'carry' point at grasp; ends on the carry_hold pose")
    L.clip(arm, "carry_hold", 0.8, carry_hold, loop=True, cancel="none",
           note="upper-body layer: blend over walk/idle with a body+head+flipper bone mask", extra={"layer": "upper"})
    upper_only("carry_hold")
    L.clip(arm, "place", 1.2, place, events={"release": 0.6}, cancel="none",
           note="from carry_hold; detach the prop onto the validated surface (0.45-0.6 m) at release")
    L.clip(arm, "stool_back_up_sit", 1.0, stool_back_up_sit, events={"seated": 0.85}, cancel="none",
           note=f"seat height {STOOL_H} m (plaza/stool socket_seat); ends seated: continue with anim_social sit_idle / sit_exit",
           extra={"seat_height_m": STOOL_H})
    L.clip(arm, "step_up", 0.8, step_up, events={"foot_contact": [0.3, 0.7]}, cancel="none",
           note="one 0.25 m stone step (town_connections stone_step); root rises only, gameplay owns travel",
           extra={"rise_m": STEP_H})
    L.clip(arm, "sip", 1.6, sip, events={"sip": 0.75}, note="mug stays in socket_hand_R; starts and ends on hold_item_idle")
    L.clip(arm, "drawer_open", 2.0, drawer_open, events={"pull": 0.4, "push": 1.25},
           note="room_kit writing_desk: stand at socket_use; slide part_drawer 0.25 m between pull and push",
           extra={"target": {"asset": "room_kit/writing_desk", "part": "part_drawer", "handle_height_m": 0.45}})


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
    L.play(arm, "carry_hold", 0)
    tips = [arm.pose.bones[f].tail for f in CARRY]
    mid = (tips[0] + tips[1]) / 2
    L.stop(arm)
    for a in common.ASSETS:
        if a["obj"] is arm:
            a["meta"]["carry_socket"] = {"position": [round(v, 3) for v in mid], "space": "avatar local (Blender Z-up)",
                                         "parent": "body", "note": "prop origin between both flipper tips in carry_hold"}
