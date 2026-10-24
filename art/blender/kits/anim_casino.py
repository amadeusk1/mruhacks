"""Casino penguin clips (Casino - Asset and Animation Checklist, 'Penguin interaction').
Frame: the avatar origin sits on the seat's socket for EVERY clip (like sledding). Floor clips (casino_approach,
the start of hop_onto_seat, the end of leave_seat) move the root down and forward to stand on the floor
FLOOR_OFFSET from the seat, so gameplay parents/snaps once at the start of casino_approach and releases at the
end of leave_seat with no pop. SEAT_H matches the casino seat sockets (0.42 m until Models/casino exists).
Short flippers cannot reach a table point 0.7 m out: reach_table leans in and the manifest records the flipper
tip at 'place'; the engine tweens the chip or card from there to its table anchor.
"""
import json, math, os
import animlib as L
import common
from animlib import X, Y, Z, ss, bump, cyc, window, flippers, merge, aim
from mathutils import Vector

KIT = "anim_casino"


def seat_height():
    try:
        for a in json.load(open(os.path.join(common.MODELS, "casino", "manifest.json"))):
            for k, v in a.get("sockets", {}).items():
                if "seat" in k:
                    return round(v[2], 3)  # manifest sockets are Blender Z-up
    except (OSError, ValueError, KeyError, IndexError):
        pass
    return 0.42


SEAT_H = seat_height()
FLOOR_OFFSET = (0.0, -0.32, -SEAT_H)          # standing in front of the seat, on the floor
TABLE_TARGET = Vector((0.0, -0.7, 0.62 - SEAT_H))  # 0.7 m forward, 0.62 m above the floor
LEVER = Vector((-0.42, -0.12, 0.42))           # seated right, about handle height on a slot cabinet
BUTTON = Vector((0.0, -0.36, 0.3))             # cabinet button panel in front

FEET = {"foot.L": {"rot": [(X, -30), (Z, 12)], "loc": (0.03, -0.19, 0.015)},
        "foot.R": {"rot": [(X, -30), (Z, -12)], "loc": (-0.03, -0.19, 0.015)}}   # same as anim_social sit: clears coat hems
SEAT = merge(FEET, flippers(l=(-4, 14), r=(-4, 14)), {"body": {"rot": (X, -5)}, "head": {"rot": (X, 3)}})


def at_floor(w):
    return {"root": {"loc": tuple(o * w for o in FLOOR_OFFSET)}}


def approach(t):
    """Arrive at the floor spot in front of the seat: settle the last step and look up at the seat."""
    look = window(t, 0.15, 0.4, 0.55, 0.7)
    return L.pose(merge(at_floor(1.0), {"body": {"rot": (X, -4 * look), "loc": (0, 0, -0.012 * bump(t, 0.0, 0.25))},
                                         "head": {"rot": (X, -10 * look)},
                                         "foot.R": {"loc": (0, 0, 0.025 * bump(t, 0.0, 0.22))}}),
                  {"eyes_wide": 0.3 * look})


def hop_on(t):
    crouch = bump(t, 0.0, 0.25)
    air = ss(0.18, 0.5, t)                   # root travels floor -> seat
    arc = bump(t, 0.18, 0.32)
    land = bump(t, 0.48, 0.16)
    seat_w = ss(0.4, 0.62, t)
    p = L.mix(L.rest_pose(), L.pose(SEAT), seat_w)
    off = L.pose({"root": {"loc": (0, FLOOR_OFFSET[1] * (1 - air), FLOOR_OFFSET[2] * (1 - air) + 0.08 * arc)},
                  "body": {"loc": (0, 0, -0.04 * crouch - 0.02 * land),
                           "scl": (1 + 0.03 * (crouch + land), 1 + 0.03 * (crouch + land), 1 - 0.05 * (crouch + land))},
                  "flipper.L": {"rot": (Y, -40 * arc)}, "flipper.R": {"rot": (Y, 40 * arc)}})
    return L.add(p, off, {"eyes_happy": 0.5 * land})


def leave(t):
    air = ss(0.12, 0.45, t)
    arc = bump(t, 0.12, 0.33)
    land = bump(t, 0.43, 0.17)
    p = L.mix(L.pose(SEAT), L.rest_pose(), ss(0.05, 0.4, t))
    off = L.pose({"root": {"loc": (0, FLOOR_OFFSET[1] * air, FLOOR_OFFSET[2] * air + 0.06 * arc)},
                  "body": {"loc": (0, 0, -0.03 * land)}, "flipper.L": {"rot": (Y, -30 * arc)}, "flipper.R": {"rot": (Y, 30 * arc)}})
    return L.add(p, off)


def seated_idle(t):
    u = t / 3.0
    look = window(t, 1.1, 1.4, 1.9, 2.2)
    return L.add(L.pose(SEAT, {"eyes_closed": bump(t, 0.6, 0.2)}),
                 L.pose({"body": {"scl": (1 - 0.006 * cyc(u), 1 - 0.006 * cyc(u), 1 + 0.012 * cyc(u)), "loc": (0, 0, 0.004 * cyc(u))},
                         "head": {"rot": [(Z, 9 * look), (X, 2 * cyc(u))]},
                         "foot.L": {"rot": (X, 7 * cyc(u, 2))}, "foot.R": {"rot": (X, -7 * cyc(u, 2))}}))


def reach_to(bone, target, w):
    """Aim a flipper from its seated pivot toward a point in seat space."""
    sx = 1 if bone.endswith("L") else -1
    pivot = Vector((sx * 0.215, 0.035, 0.465))
    return {bone: {"rot": aim(bone, target - pivot, w)}}


LEAN = {"body": {"rot": (X, 16), "loc": (0, -0.03, 0)}, "head": {"rot": (X, -10)}}
def lean_feet(w):
    """Feet hang on the root, so slide them forward and apart as the body (and its coat hem) leans over them."""
    return {"foot.L": {"loc": (0.03 * w, -0.06 * w, -0.01 * w)}, "foot.R": {"loc": (-0.03 * w, -0.06 * w, -0.01 * w)}}


def _lean(w):
    sp = merge(SEAT, {"body": {"rot": (X, 12 * w), "loc": (0, -0.03 * w, 0)}, "head": {"rot": (X, -10 * w)}})
    for f, d in lean_feet(w).items():
        sp[f]["loc"] = tuple(a + b for a, b in zip(sp[f]["loc"], d["loc"]))
    return sp


reach = lambda t: L.pose(merge(_lean(window(t, 0, 0.3, 0.55, 0.85)),
                                 reach_to("flipper.R", TABLE_TARGET, window(t, 0.05, 0.35, 0.55, 0.85))),
                           {"eyes_wide": 0.25 * window(t, 0.1, 0.3, 0.5, 0.7)})


def lever(t):
    grab = window(t, 0.0, 0.25, 0.75, 1.0)
    pull = ss(0.3, 0.45, t) * (1 - ss(0.55, 0.8, t))
    target = LEVER + Vector((0, 0.06 * pull, -0.22 * pull))          # handle travels down and back
    return L.pose(merge(SEAT, {"body": {"rot": [(Z, -14 * grab), (Y, -5 * grab), (X, 4 * pull)]},
                               "head": {"rot": (Z, -10 * grab)}},
                        reach_to("flipper.R", target, grab)),
                  {"beak_open": 0.3 * bump(t, 0.38, 0.25), "eyes_wide": 0.3 * bump(t, 0.4, 0.3)})


def button(t):
    w = window(t, 0.0, 0.18, 0.4, 0.6)
    push = bump(t, 0.2, 0.15)
    return L.pose(merge(SEAT, {"body": {"rot": (X, 8 * w + 3 * push)}, "head": {"rot": (X, 4 * w)}},
                        reach_to("flipper.R", BUTTON + Vector((0, -0.03 * push, 0)), w)))


def look_cards(t):
    """Private peek: cupped flipper lifts a few cm, head dips toward it; nothing big for others to read."""
    w = window(t, 0.0, 0.3, 1.0, 1.3)
    return L.pose(merge(SEAT, {"body": {"rot": (X, 6 * w)}, "head": {"rot": [(X, 14 * w), (Z, -4 * w)]}},
                        flippers(l=(-8, 14 + 34 * w), r=(-4, 14 + 22 * w))),
                  {"eyes_closed": 0.3 * w})


def cheer(t):
    arms = window(t, 0.1, 0.25, 0.7, 1.0)
    bounce = bump(t, 0.15, 0.25) + 0.6 * bump(t, 0.42, 0.22)
    return L.pose(merge(SEAT, {"body": {"loc": (0, 0, 0.025 * bounce), "rot": (X, -6 * arms)}, "head": {"rot": (X, -6 * arms)}},
                        flippers(l=(-4 + 62 * arms, 18), r=(-4 + 62 * arms, 18))),
                  {"eyes_happy": window(t, 0.08, 0.2, 0.8, 1.0), "beak_open": 0.7 * window(t, 0.1, 0.2, 0.55, 0.75)})


def slump(t):
    w = window(t, 0.0, 0.35, 1.1, 1.5)
    return L.pose(merge(SEAT, {"body": {"rot": (X, 12 * w), "loc": (0, 0, -0.015 * w), "scl": (1 + 0.01 * w, 1 + 0.01 * w, 1 - 0.02 * w)},
                               "head": {"rot": [(X, 16 * w), (Y, 5 * w)]}},
                        flippers(l=(-4 - 8 * w, 14 - 8 * w), r=(-4 - 8 * w, 14 - 8 * w))),
                  {"eyes_closed": 0.55 * w})


def tip_at(arm, bone, t_event, name):
    """Flipper tip (seat space, Godot Y-up) at an event, sampled from the baked clip."""
    L.play(arm, name, round(t_event * L.FPS))
    p = arm.matrix_world @ L.tip(arm, bone)
    L.stop(arm)
    return [round(p.x, 3), round(p.z, 3), round(-p.y, 3)]


def clips(arm):
    frame = {"origin": "seat socket (all clips)", "seat_height_m": SEAT_H,
             "floor_offset_m_godot": [FLOOR_OFFSET[0], FLOOR_OFFSET[2], -FLOOR_OFFSET[1]]}
    L.clip(arm, "casino_approach", 0.7, approach, cancel="move", extra=frame, note="avatar parented to the seat socket from here")
    L.clip(arm, "hop_onto_seat", 0.7, hop_on, cancel="none", events={"seated": 0.55}, extra=frame)
    L.clip(arm, "casino_seated_idle_loop", 3.0, seated_idle, loop=True, cancel="none")
    L.clip(arm, "reach_table", 0.9, reach, cancel="none", events={"place": 0.45},
           extra={"table_target_m_godot": [0.0, 0.62, 0.7], "note_reach": "tween the chip/card from the flipper tip at 'place'"})
    L.clip(arm, "pull_lever", 1.0, lever, cancel="none", events={"pull": 0.45}, extra={"lever_handle_m_godot": [LEVER.x, LEVER.z + SEAT_H, -LEVER.y]})
    L.clip(arm, "press_button", 0.6, button, cancel="none", events={"press": 0.27})
    L.clip(arm, "look_cards", 1.3, look_cards, cancel="none", note="private peek; card content stays local UI")
    L.clip(arm, "small_cheer_seated", 1.0, cheer, cancel="none")
    L.clip(arm, "sad_slump_seated", 1.5, slump, cancel="none")
    L.clip(arm, "leave_seat", 0.6, leave, cancel="none", events={"off_seat": 0.5}, extra=frame,
           note="ends standing on the floor; release from the seat socket here")
    for name, bone, ev in (("reach_table", "flipper.R", "place"), ("pull_lever", "flipper.R", "pull"), ("press_button", "flipper.R", "press")):
        L.CLIPS[name]["flipper_tip_at_event_m_godot"] = tip_at(arm, bone, L.CLIPS[name]["events"][ev], name)


def build():
    arm = L.rig(KIT)
    clips(arm)
    L.finalize(arm, KIT)
