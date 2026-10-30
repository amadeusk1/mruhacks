"""Pets kit: companions that follow a bird around town (docs/Pets - Concepts.md).

Every pet is rigid with movable `part_*` children, so the game animates them procedurally
(waddle, flop, roll) instead of through a skeleton. Each faces -Y with its origin on the
ground. meta "slot" is "pet"; "price" and "display_name" drive the wardrobe's Pets tab.
  baby_pengloo   chick-sized bird. Tint "body" follows its owner's coat.
  leash_fish     goldfish walked like a dog. socket_leash is the collar ring the leash clips to.
  snowball_pet   rolling snowball. part_ball rolls; part_face stays upright on top of it.
"""
import math
from mathutils import Vector
from common import *
from kits.avatar import tube

KIT = "pets"
PREVIEW_WIDTH = 3.0
UP = (0, 0, 1)


def lerp_tab(tab, x):
    if x <= tab[0][0]:
        return tab[0][1]
    for (x0, y0), (x1, y1) in zip(tab, tab[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return tab[-1][1]


# ---------------------------------------------------------------------------
# Baby pengloo: egg-shaped chick, big head, fluffy ribbed down, stubby flippers
# ---------------------------------------------------------------------------
CHICK = [(0.02, 0.0), (0.03, 0.09), (0.05, 0.14), (0.09, 0.172), (0.14, 0.188), (0.19, 0.186),
         (0.23, 0.176), (0.26, 0.17), (0.29, 0.174), (0.32, 0.174), (0.35, 0.165), (0.38, 0.145),
         (0.405, 0.11), (0.42, 0.062), (0.428, 0.0)]
CHICK_DEPTH = 0.92
CHICK_BODY = tint("body", "#8E9BAA")
# half-angle of the cream face-and-belly patch by height: wide belly, neck dip, two brow lobes
MASK = [(0.0, 54), (0.22, 52), (0.26, 40), (0.29, 50), (0.335, 52), (0.36, 40), (0.378, 22), (0.39, 0)]


def chick_surf(z, phi, off=0.0):
    r, a = lerp_tab(CHICK, z), math.radians(phi)
    return Vector(((r + off) * math.sin(a), -(r * CHICK_DEPTH + off) * math.cos(a), z))


def baby_pengloo():
    b = Builder("baby_pengloo", seed=71)
    rows = [((0, 0, z), r * CHICK_DEPTH, r) for z, r in CHICK]
    # rib alternates columns outward: reads as soft tufts of down on the faceted body
    tube(b, rows, lambda p, z: "belly" if abs(p) < lerp_tab(MASK, z) else CHICK_BODY, n=22, axis=UP,
         rib=0.006, cap0=True)
    # head tuft: three little spikes of down
    for dx, tilt, h in ((-0.022, -30, 0.045), (0.0, -6, 0.06), (0.022, 26, 0.04)):
        b.cyl(0.022, h, dx, 0.01, 0.405, CHICK_BODY, segs=6, r2=0.004, rot=(-14, tilt, 0))
    # side fluff puffs where the down sticks out
    for sx in (-1, 1):
        p = chick_surf(0.12, sx * 115, -0.01)
        b.blob(0.03, 0.03, 0.026, p.x, p.y, p.z, CHICK_BODY, subdiv=1, jitter=0.004)
    # big eyes with a highlight
    for sx in (-1, 1):
        p = chick_surf(0.315, sx * 27, -0.006)
        b.sphere(0.033, p.x, p.y, p.z, "eye", u=10, v=7, scale=(1, 0.5, 1.2), rot=(0, 0, sx * 27))
        b.sphere(0.01, p.x + sx * 0.004 - 0.005, p.y - 0.016, p.z + 0.014, "white", u=6, v=4)
        c = chick_surf(0.282, sx * 50, 0.004)
        b.cyl(0.026, 0.004, c.x, c.y, c.z, "blush", segs=10, rot=(90, 0, sx * 50), center=True)
    # tiny beak, stubby wedge
    p = chick_surf(0.288, 0, -0.008)
    with b.at(tuple(p), scale=(1.25, 1.0, 0.8)):
        b.cyl(0.032, 0.05, mat="beak", segs=6, r2=0.006, rot=(100, 0, 0))
    # stubby flippers, hinged at the shoulder so the game can flap them
    for sx, side in ((1, "L"), (-1, "R")):
        sh = chick_surf(0.215, sx * 84, -0.022)
        with b.part(f"flipper_{side}", pivot=tuple(sh), motion="flutter", axis="y", amp_deg=35):
            b.blob(0.03, 0.062, 0.088, sh.x + sx * 0.04, sh.y, sh.z - 0.06, CHICK_BODY, subdiv=2,
                   rot=(0, -sx * 38, 0), jitter=0.002)
    # feet: little orange pads that lift for the waddle
    for sx, side in ((1, "L"), (-1, "R")):
        with b.part(f"foot_{side}", pivot=(sx * 0.07, -0.06, 0.02), motion="tilt", axis="x", max_deg=25):
            b.blob(0.045, 0.06, 0.02, sx * 0.07, -0.1, 0.02, "beak", subdiv=2, rot=(0, 0, -sx * 12))
    b.socket("head", (0, 0, 0.36))
    b.socket("back", tuple(chick_surf(0.2, 180, 0.0)))
    return b.finish(KIT, "pet", {"slot": "pet", "species": "baby_pengloo", "display_name": "Baby Pengloo",
                                 "price": 40, "height_m": 0.43,
                                 "emotes": [{"id": "copy", "name": "Copy Me", "owner_clip": "emotes/emote_wave"}],
                                 "blurb": "A tiny copycat that waddles after you."})


# ---------------------------------------------------------------------------
# Fish on a leash: chunky goldfish with googly eyes, pouty lips and a red collar
# ---------------------------------------------------------------------------
FISH_BODY = tint("body", "orange")
FISH_FIN = tint("fin", "red")


def leash_fish():
    b = Builder("leash_fish", seed=83)
    zc = 0.17
    b.blob(0.13, 0.22, 0.15, 0, 0.02, zc, FISH_BODY, subdiv=2, jitter=0.005)          # body
    b.blob(0.115, 0.11, 0.128, 0, -0.15, zc + 0.005, FISH_BODY, subdiv=2, jitter=0.003)  # head
    b.blob(0.09, 0.16, 0.06, 0, -0.02, 0.07, "cream", subdiv=2)                          # pale belly
    # pouty lips facing forward
    b.torus(0.03, 0.014, 0, -0.255, zc - 0.03, "pink", segs=10, ring=5, rot=(90, 0, 0))
    # googly eyes, pupils slightly cross-eyed for the derpy look
    for sx in (-1, 1):
        ex, ey, ez = sx * 0.082, -0.185, zc + 0.065
        b.sphere(0.048, ex, ey, ez, "white", u=10, v=7)
        b.sphere(0.022, ex - sx * 0.008, ey - 0.042, ez + 0.004, "eye", u=8, v=5)
    # dorsal fin on top, fixed
    b.prism([(-0.1, 0.0), (0.12, 0.0), (0.08, 0.1), (-0.04, 0.085)], 0.022, 0, 0.04, zc + 0.13, FISH_FIN,
            rot=(0, 0, 90), bevel=0.004)
    # tail fan: wags side to side
    with b.part("tail", pivot=(0, 0.21, zc), motion="sway", axis="z", amp_deg=30):
        b.prism([(0.0, 0.03), (0.18, 0.14), (0.14, 0.0), (0.18, -0.12), (0.0, -0.03)], 0.026,
                0, 0.2, zc, FISH_FIN, rot=(0, 0, 90), bevel=0.004)
    # pectoral fins: little paddles that flap while it hops
    for sx, side in ((1, "L"), (-1, "R")):
        with b.part(f"fin_{side}", pivot=(sx * 0.115, -0.07, zc - 0.06), motion="flutter", axis="y", amp_deg=40):
            b.blob(0.012, 0.06, 0.035, sx * 0.13, -0.04, zc - 0.075, FISH_FIN, subdiv=1, rot=(0, sx * 25, 0))
    # collar behind the head, ring on top for the leash
    with b.at((0, -0.075, zc), scale=(1.0, 1.0, 1.13)):
        b.torus(0.128, 0.016, 0, 0, 0, "red", segs=16, ring=5, rot=(90, 0, 0))
    b.torus(0.022, 0.006, 0, -0.075, zc + 0.165, "gold", segs=10, ring=4, rot=(0, 90, 0))
    b.cyl(0.024, 0.006, 0.0, -0.093, zc + 0.12, "gold", segs=8, rot=(90, 0, 0), center=True)  # name tag
    b.socket("leash", (0, -0.075, zc + 0.185))
    b.socket("mouth", (0, -0.27, zc - 0.03))
    return b.finish(KIT, "pet", {"slot": "pet", "species": "leash_fish", "display_name": "Fish on a Leash",
                                 "price": 25, "height_m": 0.34,
                                 "emotes": [{"id": "fetch", "name": "Fetch!", "owner_clip": "snowballs/snow_throw"}],
                                 "color_variants": {"body": ["orange", "yellow", "sky", "lavender", "pink"],
                                                    "fin": ["red", "teal", "purple", "mustard"]},
                                 "blurb": "A very good boy. Who happens to be a fish."})


# ---------------------------------------------------------------------------
# Snowball: lumpy faceted ball that rolls, with a coal face and a twig cowlick
# ---------------------------------------------------------------------------
BALL_R = 0.19


def on_ball(phi, el, off=0.0):
    """Point on the ball surface: phi around (0 = front, +90 = +X), el up from the equator (deg)."""
    a, e = math.radians(phi), math.radians(el)
    r = BALL_R + off
    return Vector((r * math.cos(e) * math.sin(a), -r * math.cos(e) * math.cos(a), BALL_R + r * math.sin(e)))


def snowball_pet():
    b = Builder("snowball_pet", seed=97)
    c = (0, 0, BALL_R)
    with b.part("ball", pivot=c, motion="spin", axis="x"):
        b.blob(BALL_R, BALL_R, BALL_R, *c, "snow", subdiv=2, jitter=0.007)
        # packed lumps all round, so the roll reads: they stick out about 1.5 cm
        for phi, el in ((150, 30), (215, -15), (95, -40), (265, 45), (30, -55), (180, 72)):
            p = on_ball(phi, el, -0.024)
            b.blob(0.034, 0.034, 0.034, p.x, p.y, p.z, "snow_shade", subdiv=1, jitter=0.003)
    with b.part("face", pivot=c, motion="tilt", axis="x", max_deg=12):
        # coal eyes with a glint
        for sx in (-1, 1):
            p = on_ball(sx * 24, 14, 0.004)
            b.blob(0.024, 0.014, 0.03, p.x, p.y, p.z, "black", subdiv=1, rot=(0, 0, sx * 24))
            g = on_ball(sx * 24 - 6, 20, 0.014)
            b.sphere(0.007, g.x, g.y, g.z, "white", u=5, v=4)
            k = on_ball(sx * 44, -2, 0.002)
            b.cyl(0.022, 0.004, k.x, k.y, k.z, "blush", segs=10, rot=(90, 0, sx * 44), center=True)
        # coal-chip smile
        for i, phi in enumerate((-20, -8, 4, 16)):
            el = -10 - 4 * math.cos(math.radians((phi + 2) * 3.5))
            p = on_ball(phi, el, 0.002)
            b.box(0.02, 0.014, 0.018, p.x, p.y, p.z - 0.009, "black", bevel=0.004, rot=(0, 0, phi), jitter=0.002)
        # twig cowlick on top with a side sprig and one leaf
        top = Vector((0, 0.01, 2 * BALL_R - 0.01))
        b.cyl(0.012, 0.17, top.x, top.y, top.z - 0.02, "bark", segs=5, r2=0.006, rot=(-10, 16, 0))
        b.cyl(0.007, 0.065, 0.028, 0.0, top.z + 0.08, "bark", segs=5, r2=0.003, rot=(0, 62, 0))
        b.blob(0.03, 0.01, 0.016, 0.075, 0.0, top.z + 0.115, "leaf", subdiv=1, rot=(0, -30, 0))
    return b.finish(KIT, "pet", {"slot": "pet", "species": "snowball_pet", "display_name": "Snowball",
                                 "price": 15, "height_m": 0.42, "roll_radius_m": BALL_R,
                                 "emotes": [{"id": "pop", "name": "Grow & Pop", "owner_clip": "emotes/emote_surprised"}],
                                 "blurb": "Rolls after you and grows in fresh snow."})


# ---------------------------------------------------------------------------
# Fetch junk: what the fish brings back. Origin is the grip point the fish bites, at the
# prop's middle, so it hangs from socket_mouth; meta "slot" is "pet_prop".
# ---------------------------------------------------------------------------
def fetch_boot():
    b = Builder("fetch_boot", seed=101)
    b.box(0.07, 0.15, 0.022, 0, -0.02, -0.06, "wood_deep", bevel=0.006)                # sole
    b.box(0.066, 0.1, 0.045, 0, -0.035, -0.04, "brown", bevel=0.012)                    # foot
    b.blob(0.034, 0.035, 0.028, 0, -0.085, -0.035, "brown", subdiv=1)                    # toe
    b.cyl(0.035, 0.1, 0, 0.025, -0.04, "brown", segs=8)                                  # shaft
    b.torus(0.035, 0.007, 0, 0.025, 0.06, "tan", segs=10, ring=4)                        # cuff
    for z in (-0.01, 0.015, 0.04):
        b.box(0.05, 0.006, 0.006, 0, -0.012, z, "cream", bevel=0.0)                      # laces
    return b.finish(KIT, "pet_prop", {"slot": "pet_prop", "fetch": True})


def fetch_sock():
    b = Builder("fetch_sock", seed=103)
    for i, z in enumerate((0.05, 0.02, -0.01, -0.04)):
        b.cyl(0.026, 0.03, 0, 0, z - 0.015, "red" if i % 2 == 0 else "cream", segs=8)    # striped leg
    b.cyl(0.026, 0.07, 0, -0.035, -0.055, "red", segs=8, rot=(90, 0, 0), center=True)    # foot
    b.blob(0.027, 0.022, 0.027, 0, -0.072, -0.055, "cream", subdiv=1)                    # toe
    b.blob(0.028, 0.022, 0.028, 0, 0.005, -0.055, "cream", subdiv=1)                     # heel
    return b.finish(KIT, "pet_prop", {"slot": "pet_prop", "fetch": True})


def fetch_can():
    b = Builder("fetch_can", seed=107)
    b.cyl(0.04, 0.11, 0, 0, -0.055, "steel", segs=10)
    b.cyl(0.0405, 0.055, 0, 0, -0.03, "teal", segs=10)                                   # label band
    b.cyl(0.0405, 0.012, 0, 0, -0.01, "cream", segs=10)
    b.torus(0.039, 0.005, 0, 0, 0.055, "steel", segs=12, ring=4)                         # rim
    b.cyl(0.035, 0.003, 0, 0, 0.051, "iron", segs=10)                                    # open top
    with b.at((0.0, 0.0, 0.055), rot=(-60, 0, 0)):
        b.cyl(0.03, 0.003, 0, 0.03, 0, "steel", segs=10)                                 # bent-up lid
    return b.finish(KIT, "pet_prop", {"slot": "pet_prop", "fetch": True})


def build():
    baby_pengloo()
    leash_fish()
    snowball_pet()
    fetch_boot()
    fetch_sock()
    fetch_can()
