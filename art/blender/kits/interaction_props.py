"""Interaction props (sheet: Activity Interaction Prop Kit). Sled course, snow arena, fishing and
cinema snack props that the existing kits don't cover. The rod, bobber, fish, sled, team flags,
ready pads, snowball and duo cabinet already exist in avatar / fishing / winter / arcade."""
from common import *
from kits.winter import snow_post, snow_lumps, shade_snow, snowy_rock
from kits.arcade import _station, DECK_TILT

KIT = "interaction_props"
PREVIEW_WIDTH = 10.0

PALETTE.update({
    # countdown lamps: one material each so the game can switch them on in sequence
    "lamp_red": ("#E8443A", 0.4, 1.4), "lamp_amber": ("#F2A22B", 0.4, 1.4), "lamp_green": ("#2FC283", 0.4, 1.4),
    "team_glow": ("#F07A68", 0.5, 0.9),
    "popcorn": ("#FBE7A6", 0.9, 0), "popcorn_b": ("#F6D77F", 0.9, 0),
})
TEAM = tint("team", "coral")
TEAM_GLOW = tint("team_glow", "team_glow")
TEAM_VARIANTS = ["#E86D58", "#207D85"]
HELD = {"slot": "hand", "socket": "socket_hand_R", "excludes": ["hand"], "replaces": ["hand"]}


def done(b, cat="prop", meta=None):
    shade_snow(b)
    return b.finish(KIT, cat, meta)


def rock_base(b, x, y, r=0.2, i=0):
    """Grey stone foot with a snow mound, like the sheet's post bases."""
    snowy_rock(b, x, y, r * 1.3, r * 1.1, r * 0.55, i)
    snow_lumps(b, x, y, r * 0.55, r * 1.4, r * 1.2, 2, r=(0.08, 0.12))


def lashing(b, x, y, z, w=0.17, t=0.03):
    """Rope X-wrap where a beam meets a post."""
    for a in (35, -35):
        b.box(w * 1.25, t, t, x, y - w / 2 - 0.005, z, "rope", bevel=0.008, rot=(0, a, 0), center=True)


# ----------------------------------------------------------------- sled course
def start_light():
    b = Builder("start_light", seed=11)
    rock_base(b, 0, 0, 0.22)
    snow_post(b, 0, 0, 0.0, h=1.95, w=0.16)
    b.box(0.07, 0.62, 0.1, 0, -0.27, 1.72, "wood_dark", bevel=0.02)            # bracket arm toward -Y
    b.box(0.05, 0.05, 0.36, 0, -0.07, 1.42, "wood_dark", bevel=0.01, rot=(-38, 0, 0))  # brace
    snow_cap(b, 0.12, 0.6, 0, -0.27, 1.82, h=0.05, lumps=False)
    for sx in (-0.07, 0.07):
        b.cyl(0.012, 0.12, sx, -0.5, 1.6, "iron", segs=4)                   # hanger rods
    # housing hanging from the arm, lenses facing -Y
    hx, hy, hz = 0, -0.5, 0.78
    b.box(0.34, 0.24, 0.84, hx, hy, hz, "charcoal", bevel=0.05)
    b.box(0.38, 0.27, 0.05, hx, hy, hz + 0.8, "iron", bevel=0.02)
    b.box(0.38, 0.27, 0.05, hx, hy, hz - 0.01, "iron", bevel=0.02)
    for i, (lamp, z) in enumerate((("lamp_red", 1.39), ("lamp_amber", 1.2), ("lamp_green", 1.01))):
        b.cyl(0.105, 0.04, hx, hy - 0.12, z, "black", segs=10, rot=(90, 0, 0), center=True)
        b.cyl(0.085, 0.05, hx, hy - 0.15, z, lamp, segs=10, rot=(90, 0, 0), center=True)
        b.box(0.22, 0.08, 0.025, hx, hy - 0.17, z + 0.1, "charcoal", bevel=0.008, rot=(-25, 0, 0), center=True)  # visor
        b.socket(f"lamp_{i}", (hx, hy - 0.18, z))
    return done(b, "track", {"lamps": ["lamp_red", "lamp_amber", "lamp_green"],
                             "note": "each lamp has its own emissive material: set emission energy per countdown step",
                             "faces": "-Y (toward racers at the start line)"})


def striped_post(b, x, h=1.05, w=0.15, i=0):
    rock_base(b, x, 0, 0.17, i)
    snow_post(b, x, 0, 0.0, h=h, w=w)
    for k, z in enumerate((0.35, 0.58, 0.81)):
        b.box(w + 0.025, w + 0.025, 0.1, x, 0, z, tint("stripe_a", "coral") if k % 2 == 0 else tint("stripe_b", "teal"), bevel=0.015)


def checkpoint_posts(gap=3.0):
    """A pair of posts marking a checkpoint. Nothing spans the route between them."""
    b = Builder("checkpoint_posts", seed=12)
    for s in (-1, 1):
        x = s * gap / 2
        striped_post(b, x, i=s)
        # small pennant on the outer face, pointing away from the route so it never crosses it
        with b.part(f"pennant_{'l' if s < 0 else 'r'}", pivot=(x + s * 0.08, 0, 0.98), motion="flutter", amp_deg=8):
            b.prism([(0, 0.1), (0, -0.1), (s * 0.3, -0.02)], 0.015, x=x + s * 0.08, y=0, z=0.98, mat=tint("pennant", "coral"))
    return done(b, "track", {"gap_m": gap, "route_axis": "Y (racers pass between the posts along ±Y)",
                             "note": "posts only: no rope or banner across the sled route"})


def finish_timer():
    b = Builder("finish_timer", seed=13)
    S = 1.25
    for s in (-1, 1):
        rock_base(b, s * S, 0, 0.24, s)
        snow_post(b, s * S, 0, 0.0, h=2.15, w=0.2)
        lashing(b, s * S, 0, 1.92, w=0.2)
    b.box(2.95, 0.2, 0.2, 0, 0, 1.86, "wood", bevel=0.03)
    snow_cap(b, 3.0, 0.24, 0, 0, 2.06, h=0.07)
    for sx in (-0.55, 0.55):
        b.cyl(0.012, 0.32, sx, -0.06, 1.55, "iron", segs=4)
    b.box(1.5, 0.1, 0.62, 0, -0.06, 0.95, tint("sign_frame", "wood_dark"), bevel=0.03)
    b.box(1.32, 0.03, 0.46, 0, -0.12, 1.03, "insert_screen", bevel=0)
    b.socket("display", (0, -0.14, 1.26))
    for s in (-1, 1):  # chequered flags on short poles atop the beam
        x = s * 0.55
        b.cyl(0.02, 0.62, x, 0, 2.06, "iron", segs=6)
        b.sphere(0.03, x, 0, 2.69, "gold", u=6, v=4)
        with b.part(f"flag_{'l' if s < 0 else 'r'}", pivot=(x, 0, 2.62), motion="flutter", amp_deg=10):
            for i in range(4):
                for j in range(3):
                    m = "black" if (i + j) % 2 else "white"
                    b.box(0.09, 0.012, 0.09, x + s * (0.065 + 0.09 * i), 0, 2.34 + 0.09 * j, m, bevel=0)
    return done(b, "track", {"insert": "display (blank insert_screen; the game draws the time)"})


# ----------------------------------------------------------------- snow arena
def team_badge():
    """Chest badge worn by arena players. Origin = avatar socket_neck; the shield sits on the chest."""
    b = Builder("team_badge", seed=14)
    with b.at((0.135, -0.33, -0.13), rot=(-10, 0, 20), scale=1.2):
        shield = [(-0.07, 0.07), (0.07, 0.07), (0.07, -0.01), (0, -0.085), (-0.07, -0.01)]
        inner = [(x * 0.78, y * 0.78 + 0.004) for x, y in shield]
        b.prism(shield, 0.022, mat="gold")
        b.prism(inner, 0.008, y=-0.014, mat=TEAM)
        # simple bird emblem: body, head, tail
        b.blob(0.026, 0.006, 0.018, 0.002, -0.02, 0.0, "cream", subdiv=1)
        b.blob(0.012, 0.006, 0.012, 0.024, -0.02, 0.016, "cream", subdiv=1)
        b.prism([(-0.02, 0.0), (-0.048, 0.02), (-0.044, -0.006)], 0.006, y=-0.02, mat="cream")
        for s in (-1, 1):  # ribbon tails
            b.prism([(s * 0.012, -0.06), (s * 0.05, -0.06), (s * 0.06, -0.13), (s * 0.035, -0.115), (s * 0.02, -0.135)],
                    0.006, y=0.004, mat=TEAM)
    return done(b, "accessory", {"slot": "neck", "socket": "socket_neck", "team_marker": True,
                                 "color_variants": TEAM_VARIANTS,
                                 "note": "sits proud of the thickest torso items (puffer vest, robe)"})


def team_foot_ring():
    b = Builder("team_foot_ring", seed=15)
    b.torus(0.47, 0.028, 0, 0, 0.03, TEAM, segs=20, ring=6)
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        b.cyl(0.026, 0.025, 0.47 * math.cos(a), 0.47 * math.sin(a), 0.045, TEAM_GLOW, segs=6)
    return done(b, "accessory", {"slot": "root", "socket": "root", "team_marker": True, "color_variants": TEAM_VARIANTS,
                                 "note": "flat ring around the feet; team_glow is emissive, so set its emission colour with the albedo"})


def respawn_pad():
    b = Builder("respawn_pad", seed=16)
    n = 10
    for i in range(n):  # chunky stone rim blocks
        a0 = 2 * math.pi * i / n
        with b.at((0.56 * math.cos(a0 + math.pi / n), 0.56 * math.sin(a0 + math.pi / n), 0), rotz=math.degrees(a0 + math.pi / n) + 90):
            b.box(0.34, 0.2, 0.13, 0, 0, 0, pick(("stone_grey", "rock_grey", "stone_dark"), i), bevel=0.035, jitter=0.006)
            if i % 2 == 0:
                b.box(0.08, 0.04, 0.05, 0, -0.1, 0.05, TEAM_GLOW, bevel=0.01)
    b.cyl(0.47, 0.08, 0, 0, 0, "charcoal", segs=20)
    b.torus(0.37, 0.025, 0, 0, 0.09, TEAM_GLOW, segs=24, ring=5)
    b.cyl(0.32, 0.095, 0, 0, 0, TEAM, segs=20)
    # bird emblem on the pad face
    b.blob(0.12, 0.07, 0.012, 0.0, 0.0, 0.1, "cream", subdiv=1)
    b.blob(0.055, 0.05, 0.012, 0.1, 0.035, 0.105, "cream", subdiv=1)
    b.prism([(-0.1, 0.0), (-0.2, 0.06), (-0.19, -0.04)], 0.012, z=0.1, mat="cream", plane="xy")
    snow_lumps(b, 0.52, -0.42, 0.04, 0.2, 0.2, 2, r=(0.06, 0.1))
    b.socket("spawn", (0, 0, 0.1))
    return done(b, "arena", {"color_variants": TEAM_VARIANTS, "diameter_m": 1.3,
                             "note": "tints team (pad face) and team_glow (emissive rim): recolour both"})


def match_scoreboard():
    b = Builder("match_scoreboard", seed=17)
    S = 0.85
    for s in (-1, 1):
        rock_base(b, s * S, 0, 0.2, s)
        b.box(0.14, 0.14, 1.0, s * S, 0, 0, "wood_b", bevel=0.02)
    b.box(2.0, 0.16, 0.86, 0, 0, 0.82, "wood", bevel=0.04)                     # frame
    for s, team in ((-1, tint("team_a", "coral")), (1, tint("team_b", "teal"))):
        b.box(0.8, 0.05, 0.62, s * 0.46, -0.07, 0.94, team, bevel=0.02)
        b.box(0.62, 0.02, 0.44, s * 0.46, -0.1, 1.03, "insert_screen", bevel=0)
        b.socket(f"score_{'a' if s < 0 else 'b'}", (s * 0.46, -0.11, 1.25))
    b.box(0.08, 0.06, 0.7, 0, -0.07, 0.9, "wood_dark", bevel=0.015)
    # crown emblem centred on top
    b.box(0.34, 0.08, 0.16, 0, 0, 1.66, "wood_dark", bevel=0.02)
    b.prism([(-0.12, 0), (0.12, 0), (0.12, 0.08), (0.06, 0.04), (0, 0.11), (-0.06, 0.04), (-0.12, 0.08)], 0.04,
            y=-0.045, z=1.69, mat="gold")
    snow_cap(b, 2.04, 0.2, 0, 0, 1.68, h=0.06)
    return done(b, "arena", {"insert": "score_a / score_b (blank insert_screen; the game draws digits)"})


# ----------------------------------------------------------------- fishing
def catch_display_stand():
    b = Builder("catch_display_stand", seed=18)
    S = 0.7
    for s in (-1, 1):
        rock_base(b, s * S, 0, 0.18, s)
        snow_post(b, s * S, 0, 0.0, h=1.6, w=0.14)
        lashing(b, s * S, 0, 1.36, w=0.14)
    b.box(1.6, 0.13, 0.13, 0, 0, 1.3, "wood", bevel=0.025)
    rope_between(b, (-S, -0.08, 1.45), (S, -0.08, 1.45), sag=0.05, r=0.014)
    b.box(0.7, 0.07, 0.24, 0, 0, 1.62, tint("sign_frame", "wood_dark"), bevel=0.025)   # top plaque
    b.box(0.58, 0.02, 0.14, 0, -0.04, 1.67, "insert_sign", bevel=0)
    for s in (-1, 1):
        b.box(0.06, 0.06, 0.2, s * 0.3, 0, 1.43, "wood_dark", bevel=0.01)
    for i, x in enumerate((-0.4, 0, 0.4)):  # hooks the game hangs caught fish on
        b.cyl(0.008, 0.12, x, -0.07, 1.18, "gold", segs=4)
        b.torus(0.022, 0.006, x, -0.07, 1.165, "gold", segs=8, ring=4, rot=(90, 0, 0))
        b.socket(f"hook_{i}", (x, -0.07, 1.14))
    b.box(1.46, 0.36, 0.1, 0, 0, 0.12, "wood_b", bevel=0.02)                          # low plank base
    b.box(1.46, 0.08, 0.14, 0, 0.14, 0.12, "wood_c", bevel=0.02)
    return done(b, "prop", {"insert": "top plaque (insert_sign)", "note": "fish from the fishing kit hang at hook_0..2"})


def mooring_post():
    """Decorative 'line anchor' detail for docks. The fishing line attaches to the rod tip
    (avatar/fishing_rod socket_line_tip), never to this post."""
    b = Builder("mooring_post", seed=22)
    for i, (x, y, r) in enumerate(((0.12, 0.05, 0.2), (-0.14, 0.08, 0.16), (0.02, -0.15, 0.15))):
        snowy_rock(b, x, y, r * 1.2, r, r * 0.6, i)
    b.box(0.26, 0.26, 0.82, 0, 0, 0.0, "wood_b", bevel=0.035, jitter=0.004)
    for k in range(3):  # weathered grain grooves
        b.box(0.012, 0.01, 0.6, -0.06 + 0.06 * k, -0.132, 0.12, "wood_dark", bevel=0)
    b.cyl(0.14, 0.05, 0, 0, 0.82, "snow", segs=8, r2=0.12, jitter=0.01)
    b.blob(0.13, 0.13, 0.07, 0, 0, 0.87, "snow", subdiv=1, jitter=0.012)
    for k in range(4):  # rope wraps hugging the square post (a round torus clips the corners)
        z = 0.48 + 0.045 * k
        for a in (0, 90, 180, 270):
            with b.at((0, 0, z), rotz=a):
                b.box(0.3, 0.04, 0.04, 0, -0.145, 0, "rope", bevel=0.012, rot=(0, (k % 2) * 6 - 3, 0), center=True)
    b.box(0.06, 0.06, 0.06, 0, -0.15, 0.6, "iron", bevel=0.012)                           # ring staple
    b.torus(0.1, 0.02, 0, -0.19, 0.5, "gold", segs=14, ring=5, rot=(90, 0, 0))            # brass ring
    return done(b, "prop", {"decorative": True,
                            "note": "dock dressing only; the fishing line runs rod tip -> bobber"})


def double_control_deck():
    """Standalone two-player control panel: same stations, spacing and grip sockets as
    arcade_cabinet_duo (socket_grip_<n>_L/R, joystick tilt + button press parts)."""
    b = Builder("double_control_deck", seed=23)
    W, D = 1.25, 0.46
    b.box(W, D, 0.82, 0, 0, 0, "wood", bevel=0.03)                                      # cabinet box
    for s, c in ((-1, tint("station_1", "coral")), (1, tint("station_2", "teal_light"))):
        b.box(0.06, D + 0.02, 0.84, s * (W / 2 - 0.02), 0, 0, c, bevel=0.02)               # side trims
    for x in (-W / 2 + 0.08, W / 2 - 0.08):
        b.box(0.07, 0.05, 0.7, x, -D / 2, 0.06, "wood_dark", bevel=0.01)                     # corner straps
        for z in (0.12, 0.7):
            b.cyl(0.014, 0.012, x, -D / 2 - 0.025, z, "iron", segs=6, rot=(90, 0, 0), center=True)
    b.box(W - 0.06, 0.06, 0.06, 0, -D / 2 + 0.01, 0, "wood_dark", bevel=0.012)              # kick strip
    # hexagonal bird emblem on the front
    hexp = [(0.11 * math.cos(math.radians(30 + 60 * k)), 0.42 + 0.11 * math.sin(math.radians(30 + 60 * k))) for k in range(6)]
    b.prism(hexp, 0.03, y=-D / 2 - 0.01, mat="charcoal", bevel=0.006)
    b.blob(0.04, 0.008, 0.026, 0.0, -D / 2 - 0.028, 0.41, "cream", subdiv=1)
    b.blob(0.02, 0.008, 0.02, 0.035, -D / 2 - 0.028, 0.44, "cream", subdiv=1)
    b.prism([(-0.03, 0.41), (-0.07, 0.44), (-0.065, 0.395)], 0.008, y=-D / 2 - 0.028, mat="cream")
    # tilted cream top with the two stations (same layout as the duo cabinet deck)
    with b.at((0, -0.02, 0.84), rot=(DECK_TILT, 0, 0)):
        b.box(W + 0.02, D + 0.04, 0.05, 0, 0, -0.05, tint("deck", "cream"), bevel=0.015)
        _station(b, -0.31, plate=tint("station_1", "coral"), stick="red", buttons=("yellow", "red"), n=1)
        _station(b, 0.31, plate=tint("station_2", "teal_light"), stick="sky", buttons=("yellow", "sky"), n=2)
    for n, x in ((1, -0.32), (2, 0.32)):
        b.socket(f"player_{n}", (x, -0.62, 0), rotz=180)
    return done(b, "arcade", {"slots": 2, "matches": "arcade/arcade_cabinet_duo control scale and socket names",
                              "screen": "none (pair with a screen or cabinet; controls are independent)"})


# ----------------------------------------------------------------- cinema snacks
def popcorn_tub():
    """Held at socket_hand_R; origin is the grip, the tub sits inward and in front like the mug."""
    b = Builder("popcorn_tub", seed=19)
    with b.at((0.09, -0.1, -0.09), scale=1.25):
        H, r0, r1 = 0.16, 0.062, 0.082
        b.cyl(r0, H, 0, 0, 0, tint("stripe_b", "cream"), segs=4, r2=r1, rot=(0, 0, 45), bevel=0.004)
        # coral stripes: thin flared slats proud of each face (two per face)
        for k in range(4):
            a = math.radians(90 * k)
            for off in (-0.028, 0.028):
                with b.at((0, 0, 0), rotz=90 * k):
                    flare = math.degrees(math.atan2((r1 - r0) * 0.7071, H))  # face lean of the flared tub
                    b.box(0.022, 0.005, H, off, -r0 * 0.7071 - 0.003, 0, tint("stripe_a", "coral"), bevel=0, rot=(flare, 0, 0))
        # round bird emblem on the front face
        b.cyl(0.028, 0.006, 0, -0.054, 0.085, "cream", segs=10, rot=(90, 0, 0), center=True)
        b.blob(0.014, 0.004, 0.009, 0.0, -0.059, 0.083, tint("stripe_a", "coral"), subdiv=1)
        b.blob(0.007, 0.004, 0.007, 0.012, -0.059, 0.092, tint("stripe_a", "coral"), subdiv=1)
        # heap of popcorn
        rng = b.rng
        for i in range(26):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(0, 0.06) ** 0.8
            z = H + 0.012 + (0.05 - r * 0.5) * rng.uniform(0.6, 1.0)
            k = rng.uniform(0.014, 0.02)
            b.blob(k, k * 0.9, k * 0.85, r * math.cos(a), r * math.sin(a), z, pick(("popcorn", "popcorn_b"), i), subdiv=1, jitter=k * 0.15)
    return done(b, "accessory", {**HELD, "use": "cinema_snack", "color_variants": {"stripe_a": ["#E86D58", "#207D85"]}})


def drink_cup():
    b = Builder("drink_cup", seed=20)
    with b.at((0.07, -0.085, -0.075)):
        H = 0.15
        b.cyl(0.042, H, 0, 0, 0, tint("cup", "teal"), segs=12, r2=0.054)
        b.cyl(0.0445, 0.04, 0, 0, 0.0, tint("cup_band", "cream"), segs=12, r2=0.0475)
        b.cyl(0.058, 0.018, 0, 0, H, "white", segs=12, r2=0.055, bevel=0.004)           # lid
        b.cyl(0.04, 0.012, 0, 0, H + 0.016, "white", segs=12, r2=0.034)
        with b.at((0.012, 0, H + 0.02), rot=(0, 14, 0)):                              # striped straw
            for i in range(5):
                b.cyl(0.007, 0.018, 0, 0, i * 0.018, "white" if i % 2 else tint("straw", "coral"), segs=6)
        b.blob(0.014, 0.004, 0.009, 0.0, -0.05, 0.095, "cream", subdiv=1)              # bird emblem
        b.blob(0.007, 0.004, 0.007, 0.012, -0.05, 0.104, "cream", subdiv=1)
    return done(b, "accessory", {**HELD, "use": "cinema_snack"})


def seat_reservation_marker():
    """Hangs over the top of a cinema seat back, sign facing the aisle side (-Y of the seat).
    Origin = hook point resting on the seat-back top."""
    b = Builder("seat_reservation_marker", seed=21)
    # U strap over the seat-back top (back is ~0.2 m thick)
    b.box(0.08, 0.24, 0.02, 0, 0.0, 0.0, "wood_dark", bevel=0.006)
    b.box(0.08, 0.02, 0.09, 0, 0.12, -0.09, "wood_dark", bevel=0.006)
    b.box(0.08, 0.02, 0.05, 0, -0.12, -0.05, "wood_dark", bevel=0.006)
    for sx in (-0.08, 0.08):
        b.cyl(0.004, 0.09, sx, -0.125, -0.13, "rope", segs=4)
    b.box(0.3, 0.025, 0.16, 0, -0.135, -0.3, tint("frame", "wood"), bevel=0.012)
    b.box(0.26, 0.01, 0.12, 0, -0.152, -0.28, "insert_sign", bevel=0)
    return done(b, "prop", {"attach": {"to": "cinema_auditorium seat_single / seat_row_4",
                                       "relative_to": "socket_seat / socket_seat_<n>",
                                       "offset_m": [0.0, 0.37, 0.58],
                                       "note": "hook rests on the seat-back top; sign hangs toward the front of the seat"},
                             "insert": "insert_sign (the game writes 'Reserved' or the friend's name)",
                             "removable": True})


def build():
    start_light()
    checkpoint_posts()
    finish_timer()
    team_badge()
    team_foot_ring()
    respawn_pad()
    match_scoreboard()
    catch_display_stand()
    mooring_post()
    double_control_deck()
    popcorn_tub()
    drink_cup()
    seat_reservation_marker()
