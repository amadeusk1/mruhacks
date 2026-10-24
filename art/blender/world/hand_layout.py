"""Hand-authored town dressing: every prop, home and marker at explicit coordinates, grouped by district
and vignette. town.py calls build(town) and only adds the generated parts on top (sled hill, arena stairs,
coast cliffs/boulders, coastal forest, sea rocks and floes).

Coordinates are Blender metres (+X east, +Y north); yaw in degrees, assets face -Y at yaw 0.
z defaults to the ground height. To move something, edit its numbers here and rebuild
(build_town.py), or move it in Models/world/town_layout.blend and run layout_edit.py -- export.
Rules (checked by town.validate on export): nothing decorative on paths, the plaza disc lanes, bridges,
docks, stairs or door/activity approaches; stream rocks sit on the banks, never mid-channel; plants only
in beds by walls, the plaza ring and the gate posts.
"""
import math
from mathutils import Vector

T = None            # the town module, set by build()
ZONE = None
WALK = ("prop", "walkable")
BLOCK = ("prop", "blocker")
LIGHT = ("light", "blocker")
DECOR = ("decor",)
ROCK = ("rock",)
BANK = ("rock", "coast")    # bank rocks at the waterline: exempt from the stream rule, checked against paths here


def place(asset, x, y, yaw=0.0, z=None, tags=("prop",), **kw):
    kw.setdefault("zone", ZONE)
    T.put(asset, x, y, yaw, z=z, tags=tags, **kw)


def mark(name, x, y, yaw=0.0, kind="spawn", **kw):
    T.mark(name, x, y, yaw, kind=kind, **kw)


def ground(x, y):
    return T.height(Vector((x, y)))


def at_socket(asset, sock, x, y, yaw, z=0.0):
    return T.socket_world(asset, sock, x, y, yaw, z)


def building(asset, x, y, yaw, name, door_target=None, **kw):
    T.building(asset, x, y, yaw, name, door_target, ZONE, **kw)


def run(asset, a, b, step, yaw=None, tags=BLOCK, z=None):
    """Evenly spaced modules from a to b (fences, rails); yaw follows the run unless given."""
    a, b = Vector(a), Vector(b)
    d = b - a
    n = max(1, round(d.length / step))
    y = math.degrees(math.atan2(d.y, d.x)) if yaw is None else yaw
    for k in range(n):
        q = a + d * ((k + 0.5) / n)
        place(asset, q.x, q.y, y, z=z, tags=tags)


def wall_beds(asset, x, y, yaw, lateral, back=0.25, z=None, shrubs=(), scale=1.0, sides=(1, -1)):
    """Edged flower beds against a building's front wall either side of its door, with shrubs at the ends."""
    d = T.socket_world(asset, "socket_door", x, y, yaw, ground(x, y) if z is None else z, scale)
    a = math.radians(yaw)
    side, front = Vector((math.cos(a), math.sin(a))), Vector((math.sin(a), -math.cos(a)))
    for k, sg in enumerate(sides):
        q = Vector(d[:2]) + side * sg * lateral - front * back
        place("plaza/rect_planter", q.x, q.y, yaw, z=z)
        if k < len(shrubs) and shrubs[k]:
            s = q + side * sg * 1.05 + front * -0.35
            place(shrubs[k], s.x, s.y, yaw, z=z, tags=DECOR)


def sign(x, y, yaw, icon):
    """Activity sign with its icon decal."""
    place("world_misc/activity_sign", x, y, yaw, tags=BLOCK)
    w = at_socket("world_misc/activity_sign", "socket_icon", x, y, yaw, ground(x, y))
    place(f"world_misc/{icon}", w[0], w[1], yaw, z=w[2], tags=DECOR)


def table_set(asset, x, y, yaw, seats=(0, 1, 2, 3), stool="plaza/stool"):
    place(asset, x, y, yaw, tags=BLOCK)
    for k in seats:
        w = at_socket(asset, f"socket_seat_{k}", x, y, yaw)
        place(stool, w[0], w[1], yaw + 45 + 90 * k)


def grove(trees, zone="woods"):
    """Hand-placed tree clump: (asset, x, y, yaw, scale)."""
    for asset, x, y, yaw, s in trees:
        place(asset, x, y, yaw, tags=("tree",), scale=s, zone=zone)


def build(town):
    global T, ZONE
    T = town
    plaza(); shops(); homes(); stream(); cove(); south_pier(); court(); sketch(); arena(); woods(); wayfinding()


# ------------------------------------------------------------------------------------------- plaza --
def plaza():
    global ZONE
    ZONE = "plaza"
    place("plaza/small_fountain", 0, 0, 0, tags=BLOCK, name="Fountain", scale=1.55)
    # benches on r 4 at the diagonals, facing the fountain
    place("plaza/bench", 2.83, 2.83, 135, tags=BLOCK)
    place("plaza/bench", -2.83, 2.83, 225, tags=BLOCK)
    place("plaza/bench", -2.83, -2.83, 315, tags=BLOCK)
    place("plaza/bench", 2.83, -2.83, 45, tags=BLOCK)
    # outer ring between the spokes: trees in round beds and flower beds tangent to the rim (bus stop at ~290 deg)
    place("nature_dock/small_tree_bed", 6.84, 2.83, 68, tags=("tree", "blocker"))
    place("nature_dock/small_tree_bed", -2.83, 6.84, 338, tags=("tree", "blocker"))
    place("nature_dock/small_tree_bed", -6.84, -2.83, 248, tags=("tree", "blocker"))
    place("nature_dock/small_tree_bed", -2.83, -6.84, 23, tags=("tree", "blocker"))
    place("plaza/rect_planter", -7.02, 2.91, 247.5)
    place("plaza/rect_planter", 7.02, -2.91, 67.5)
    # rim lanterns between the spokes
    for x, y in [(8.39, 3.39), (-3.39, 8.39),                     # none at 67 deg: the arcade corner (-8.33, 3.54), (-8.39, -3.39), (-3.54, -8.33),
                 (8.33, -3.54)]:                                  # none at 292 deg: the bus stop
        place("plaza/lantern_post", x, y, 0, tags=LIGHT)
    # string lights across the west, east and south spokes
    place("plaza/string_lights", -10.1, 0, 90, z=ground(-9.5, 0) + 2.4, tags=("light",))
    place("plaza/string_lights", 10.1, 0, 90, z=2.4, tags=("light",))
    place("plaza/string_lights", 0, -10.1, 0, z=2.4, tags=("light",))
    mark("Spawn", 0, -3.0, 180)
    mark("BusArrival", 2.2, -5.2, 200)
    mark("BusStop", 3.4, -7.3, 200, kind="bus")
    # south gate: map board with a bench beside it, notice board, signpost and a bin
    place("world_misc/world_map_board", -3.95, -11.03, 160, tags=BLOCK, name="MapBoard")
    place("plaza/bench", -2.05, -11.63, 160, tags=BLOCK)
    place("world_misc/notice_board", -5.7, -10.2, 35, tags=BLOCK)
    place("world_misc/signpost", 4.0, -10.4, -30, tags=BLOCK)
    place("plaza/street_bin", 2.4, -11.0, 0)


# ------------------------------------------------------------------------- cafe, arcade, cinema, casino --
def shops():
    global ZONE
    cafe_yaw = 23.8                                        # turned towards the fountain
    ZONE = "plaza"
    building("cinema/cinema_exterior", 0.0, 24.7, 0, "Cinema", "cinema_lobby")
    building("cafe/cafe_exterior", -7.8, 13.65, cafe_yaw, "Cafe", "cafe_interior")
    building("arcade/arcade_exterior", T.ARCADE_P.x, T.ARCADE_P.y, T.ARCADE_YAW, "Arcade", "arcade_interior", scale=T.ARCADE_S)
    ZONE = "casino"
    building("casino/casino_exterior", 23.2, 8.4, 0, "Casino", "casino_interior")

    # cafe terrace: a four-stool table, two umbrella tables, a chalkboard by the door, milk and cups out
    ZONE = "cafe"
    table_set("plaza/round_table", -4.4, 12.6, 10)
    place("cafe/milk_jug", -4.25, 12.7, 0, z=ground(-4.4, 12.6) + 0.6, tags=DECOR)
    place("interaction_props/drink_cup", -4.6, 12.45, 0, z=ground(-4.4, 12.6) + 0.6, tags=DECOR)
    place("plaza/cafe_umbrella_table", -3.35, 15.57, 20, tags=BLOCK)
    place("plaza/cafe_umbrella_table", -13.73, 12.93, -15, tags=BLOCK)
    place("plaza/aframe_chalkboard", -4.0, 9.4, 30)
    place("world_misc/crate", -12.53, 16.73, 10, tags=BLOCK)                  # service corner behind the cafe
    place("world_misc/crate", -12.43, 16.73, 35, z=ground(-12.53, 16.73) + 0.53)
    place("world_misc/barrel", -11.83, 16.53, 0, tags=BLOCK)

    # cinema: topiaries at the door, stanchion queue lane beside the forecourt, poster frames, string lights
    ZONE = "cinema"
    place("cinema/cinema_topiary", -2.7, 20.1, 0, tags=BLOCK)
    place("cinema/cinema_topiary", 1.93, 21.95, 0, tags=BLOCK)
    place("cinema/poster_frame_a", -4.2, 19.7, 0)
    place("cinema/poster_frame_b", 4.2, 18.9, 0)
    place("plaza/string_lights", -2.2, 19.3, 0, z=2.4, tags=("light",))
    place("plaza/string_lights", 2.2, 19.3, 0, z=2.4, tags=("light",))
    for k in range(4):
        y = 18.3 - 1.25 * k
        place("cinema_lobby/stanchion", 2.2, y, 0)
        place("cinema_lobby/stanchion", 3.6, y, 0)
        place("world_misc/queue_spot_marker", 2.9, y, 0, tags=DECOR)
        if k < 3:
            place("cinema_lobby/stanchion_rope", 2.2, y - 0.62, 90, tags=DECOR)
            place("cinema_lobby/stanchion_rope", 3.6, y - 0.62, 90, tags=DECOR)
    wall_beds("cinema/cinema_exterior", 0.0, 24.7, 0, 3.4, back=0.6, shrubs=("cottage/shrub_round",), sides=(-1,))   # east side is the arena path
    for x in (-3.85, 3.85):                                                # drifts against the side walls
        place("winter/snowbank_small", x, 26.4, 90)
    place("winter/snowbank_small", -3.85, 23.2, 80)

    # arcade: everything in the arcade's own frame (u along the facade, v outwards from it is negative)
    ZONE = "arcade"
    ax, ay, ayaw, asc = T.ARCADE_P.x, T.ARCADE_P.y, T.ARCADE_YAW, T.ARCADE_S
    ca, sa = math.cos(math.radians(ayaw)), math.sin(math.radians(ayaw))

    def A(u, v):
        return ax + u * ca - v * sa, ay + u * sa + v * ca
    place("arcade/arcade_chalkboard", *A(-3.4, -5.6), ayaw - 15)
    place("arcade/arcade_bench", *A(3.4, -5.25), ayaw, tags=BLOCK)
    place("world_misc/crate", *A(4.7, -5.3), ayaw + 15, tags=BLOCK)
    place("world_misc/queue_spot_marker_stone", *A(1.3, -5.6), 0, tags=DECOR)
    place("world_misc/queue_spot_marker_stone", *A(2.3, -5.6), 0, tags=DECOR)
    place("interaction_props/double_control_deck", *A(-4.6, -5.4), ayaw, tags=BLOCK)
    for u in (-4.92, -4.28):                                              # stools at the deck's player spots
        place("arcade/arcade_stool", *A(u, -6.0), ayaw)
    wall_beds("arcade/arcade_exterior", ax, ay, ayaw, 2.5, scale=asc)
    place("world_misc/crate", *A(6.2, 3.6), ayaw + 10, tags=BLOCK)          # service corner on the east side
    place("world_misc/crate", *A(6.25, 3.6), ayaw + 35, z=ground(*A(6.2, 3.6)) + 0.53)
    place("world_misc/barrel", *A(6.3, 2.8), 0, tags=BLOCK)

    # casino forecourt: lanterns, bunting, a two-stone queue, beds against the front wall
    ZONE = "casino"
    place("plaza/lantern_post", 20.6, 3.8, 0, tags=LIGHT)
    place("plaza/lantern_post", 25.8, 3.8, 0, tags=LIGHT)
    place("plaza/bunting_posts", 26.6, 3.4, 0)
    place("world_misc/queue_spot_marker_stone", 20.8, 3.0, 0, tags=DECOR)
    place("world_misc/queue_spot_marker_stone", 22.0, 3.0, 0, tags=DECOR)
    wall_beds("casino/casino_exterior", 23.2, 8.4, 0, 2.8, shrubs=("cottage/shrub_flowering", "cottage/shrub_flowering"))
    place("world_misc/crate", 27.6, 10.6, 10, tags=BLOCK)                   # service corner
    place("world_misc/crate", 27.7, 10.6, 35, z=ground(27.6, 10.6) + 0.53)
    place("world_misc/barrel", 28.3, 10.4, 0, tags=BLOCK)
    place("winter/snowbank_small", 28.1, 7.4, 90)


# ------------------------------------------------------------------------------------------- homes --
LOTS = [  # (asset, x, y, yaw, tints, yard tree): yaw 0 faces the main street to the south, 180 to the north
    ("cottage/cottage_exterior", -29.25, 4.75, 0, {"roof": "#E86D58"}, "nature_dock/small_tree_snow"),
    ("homes/round_cottage_exterior", -17.75, 4.75, 0, {"roof": "#207D85"}, "nature_dock/broad_tree_snow"),
    ("homes/snow_dome_exterior", -29.25, -4.75, 180, {}, "nature_dock/small_tree_snow"),
    ("cottage/cottage_exterior", -17.75, -4.75, 180, {"roof": "#2F8F94"}, "nature_dock/broad_tree_snow"),
]


def homes():
    global ZONE
    ZONE = "homes"
    # gate from the plaza: arch with planted beds at its posts
    place("world_misc/homes_arch", -11.6, 0, 90, tags=("building", "blocker"), name="HomesArch")
    mark("HomesGate", -12.6, 0, 90, kind="door", target="home")
    for y in (2.9, -2.9):
        place("plaza/rect_planter", -10.2, y, 90)
        place("nature_dock/flower_single", -10.2, y + (0.95 if y > 0 else -0.95), 0, tags=DECOR)
        place("nature_dock/leaf_tuft_small", -10.0, y + (1.2 if y > 0 else -1.2), 40, tags=DECOR)

    for i, (asset, x, y, yaw, tn, tree) in enumerate(LOTS):
        building(asset, x, y, yaw, f"Home{i}", "home", tints=tn)
        f = 1 if yaw == 0 else -1                      # +1: the street is to the south
        # plaque at the front-left corner, mailbox front-right, low fence across the back with end posts
        place("world_misc/home_number_plaque", x - 3.4 * f, y - 2.9 * f, yaw)
        place("world_misc/mailbox", x + 3.0 * f, y - 2.75 * f, yaw)
        yb = y + 3.4 * f
        place("plaza/low_wood_fence_2m", x - 2.2, yb, 0, tags=BLOCK)
        place("plaza/low_wood_fence_2m", x, yb, 0, tags=BLOCK)
        place("plaza/low_wood_fence_1m", x + 1.65, yb, 0, tags=BLOCK)
        place("plaza/low_wood_fence_post", x - 3.3, yb, 0)
        place("plaza/low_wood_fence_post", x + 2.2, yb, 0)
        # yard tree in the back corner away from the plaque, a drift against the side wall
        place(tree, x + 3.4 * (1 if i % 2 else -1), y + 2.2 * f, [87, 21, 341, 210][i], tags=("tree", "blocker"))
        hw = T.manifest(asset)["size_m"][0] * 0.5
        place("winter/snowbank_small", x - (hw + 0.25) * (1 if i % 2 == 0 else -1), y + 1.0 * f, 90)
        if "cottage/" in asset:                       # the round cottage and dome doors open right onto the street
            wall_beds(asset, x, y, yaw, 2.2, shrubs=[("cottage/shrub_round",), (), (), ("nature_dock/shrub_small",)][i])
    # porches and doorsteps on the two gabled cottages
    for asset, x, y, yaw, *_ in (LOTS[0], LOTS[3]):
        dsk = at_socket(asset, "socket_door", x, y, yaw, ground(x, y))
        fx, fy = math.sin(math.radians(yaw)), -math.cos(math.radians(yaw))
        place("building_finishing/doorstep_threshold", dsk[0] - fx * 0.5, dsk[1] - fy * 0.5, yaw)
        place("building_finishing/porch_canopy", dsk[0] - fx * 0.62, dsk[1] - fy * 0.62, yaw, z=dsk[2])

    # landmark homes on the north street: the treehouse in its fir grove, the A-frame at the west end
    building("homes/treehouse_exterior", -22.5, 13.6, 0, "Home4", "home")
    building("homes/aframe_cabin_exterior", -33.0, 13.0, 0, "Home5", "home", tints={"roof": "#207D85"})
    grove([("winter/fir_tree_large", -26.9, 17.4, 30, 1.05), ("winter/fir_tree_small", -27.6, 12.0, 200, 0.95),
           ("winter/fir_tree_medium", -17.6, 11.4, 75, 0.9)],
          zone="homes")


# ------------------------------------------------------------------------------------------ stream --
def stream():
    global ZONE
    ZONE = "stream"
    # spring and mouth
    place("world_misc/waterfall_step", 15.4, 30.55, 0, z=0.15)
    place("world_misc/waterfall_step", 7.775, -26.6, 0, z=-0.6)
    place("town_connections/stream_end", 15.4, 33.75, 0, z=0.0, tags=BANK)
    # footbridges at the three path crossings: deck ends flush with the paving (town.check_seams)
    for c, yaw in T.BRIDGES:                      # where the paths cross the stream (town.BRIDGES)
        place("world_misc/footbridge", c.x, c.y, yaw, z=T.BRIDGE_Z, tags=WALK, name="Bridge")
    # bank rocks: small clusters at the bends and tucked under the bridge abutments, never in the channel
    for asset, x, y, yaw, s in [
            ("nature_dock/rock_cluster_snow", 13.8, 34.4, 20, 0.8), ("nature_dock/rock_small_a_snow", 17.1, 33.2, 140, 1.0),   # spring
            ("nature_dock/rock_small_b_snow", 14.65, 25.0, 60, 0.9), ("nature_dock/rock_small_a_snow", 17.55, 24.9, 200, 0.9),   # N bridge
            ("nature_dock/rock_small_b_snow", 14.85, 20.4, 300, 0.8), ("winter/rock_cluster_snow_small", 17.75, 20.5, 10, 1.0),
            ("nature_dock/rock_cluster_snow", 20.85, 16.5, 110, 0.85), ("nature_dock/rock_small_a_snow", 20.5, 17.7, 30, 0.9),  # E bend
            ("nature_dock/rock_small_b_snow", 20.7, 15.1, 250, 0.8),
            ("winter/rock_cluster_snow_small", 14.5, 8.9, 70, 1.0), ("nature_dock/rock_small_a_snow", 14.65, 7.7, 190, 0.8), ("nature_dock/pebble_cluster_snow", 14.9, 6.6, 160, 0.9),  # W bend
            ("nature_dock/rock_small_a_snow", 12.65, 2.3, 30, 0.8), ("nature_dock/rock_small_b_snow", 15.45, 2.0, 160, 0.8),    # E spoke bridge
            ("winter/rock_cluster_snow_small", 11.5, -2.7, 220, 0.9), ("nature_dock/rock_small_b_snow", 14.35, -2.4, 80, 0.8),
            ("nature_dock/rock_small_a_snow", 12.92, -9.04, 120, 0.8), ("nature_dock/rock_small_b_snow", 10.52, -7.6, 10, 0.8),  # SE bridge
            ("winter/rock_cluster_snow_small", 10.34, -13.32, 300, 1.0), ("nature_dock/rock_small_a_snow", 7.94, -11.88, 75, 0.8),
            ("nature_dock/rock_cluster_snow", 6.3, -16.6, 40, 0.8), ("nature_dock/rock_small_b_snow", 6.0, -15.4, 180, 0.8)]:  # S bend
        place(asset, x, y, yaw, z=ground(x, y) - 0.12, tags=BANK, scale=s)
    # railing on both banks beside the plaza stretch, with end posts
    for a, b in [((13.45, 8.4), (11.6, 2.6)), ((17.4, 4.9), (16.85, 2.2)), ((10.1, -2.9), (9.7, -5.6)), ((15.4, -3.3), (14.95, -6.5))]:
        run("town_connections/rail_segment", a, b, 2.1, yaw=math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])))
        for q in (a, b):
            place("town_connections/rail_end_post", q[0], q[1], 0, tags=BLOCK)
    # stream picnic on the east bank below the plaza bridge
    ZONE = "picnic"
    table_set("plaza/round_table", 16.8, -5.4, 20, seats=(0, 2))
    place("room_kit/woven_basket", 17.5, -4.6, 10)
    place("interaction_props/drink_cup", 16.7, -5.3, 0, z=ground(16.8, -5.4) + 0.6, tags=DECOR)
    place("interaction_props/drink_cup", 16.95, -5.55, 0, z=ground(16.8, -5.4) + 0.6, tags=DECOR)
    place("plaza/lantern_post", 18.2, -6.3, 0, tags=LIGHT)
    place("nature_dock/small_tree_snow", 18.6, -7.0, 60, tags=("tree", "blocker"))
    # bench looking down the stream from the cinema-arena bridge, someone's popcorn left on it
    ZONE = "streamview"
    place("plaza/bench", 19.0, 25.8, 200, tags=BLOCK)
    place("plaza/lantern_post", 20.2, 25.9, 0, tags=LIGHT)
    place("interaction_props/popcorn_tub", 19.3, 25.93, 200, z=ground(19.0, 25.8) + 0.42, tags=DECOR)


# -------------------------------------------------------------------------------------------- cove --
def pier(x, y0, n, end_spot=True):
    """Dock tiles running south from the shore path; the first tile is flush with the paving."""
    z = ground(x, y0 + 1.35) + 0.07
    for k in range(n):
        place("nature_dock/dock_straight", x, y0 - 2 * k, 0, z=z, tags=WALK)
        if k == 0:
            T.DOCK_HEADS.append((T.PLACE[-1], Vector((0, -1))))
    if end_spot:
        place("fishing/fishing_dock_spot", x, y0 - 2 * n, 0, z=z, tags=WALK)
    return z


def cove():
    global ZONE
    ZONE = "dock"
    T.DOCK_HEADS.clear()
    # pier A with the boathouse platform; pier B with a T head
    zA = pier(-24.0, -14.8, 3)
    for x in (-26.0, -28.0):
        for y in (-16.8, -18.8):
            place("nature_dock/dock_straight", x, y, 90, z=zA, tags=WALK)
    place("nature_dock/dock_corner", -28.0, -20.8, 0, z=zA, tags=WALK)
    place("cottage/cottage_exterior", -27.0, -17.8, 90, z=zA + 0.06, tags=("building", "blocker"), name="Boathouse", scale=0.7)
    place("plaza/wall_lantern", -25.5, -17.49, 90, z=zA + 1.6, tags=DECOR)
    zB = pier(-12.0, -14.5, 4, end_spot=False)
    place("fishing/fishing_dock_spot", -12.0, -22.5, 0, z=zB, tags=WALK)
    place("nature_dock/dock_straight", -14.0, -22.5, 90, z=zB, tags=WALK)
    place("fishing/fishing_dock_spot", -16.0, -22.5, 90, z=zB, tags=WALK)
    T.DOCK_Z.update(A=zA, B=zB)
    n = 0
    for q in [q for q in T.PLACE if q["id"] == "fishing/fishing_dock_spot"]:
        for sk in ("socket_fish_0", "socket_fish_1"):
            w = at_socket(q["id"], sk, q["pos"][0], q["pos"][1], q["yaw"], q["pos"][2])
            if w:
                mark(f"FishingSpot{n}", w[0], w[1], q["yaw"] + 180, kind="activity", activity="fishing", z=w[2])
                n += 1
    # quay wall along the north shore between the piers, rope rails on the pier edges, a mooring post
    for x in (-21.5, -19.5, -17.5, -15.5):
        place("nature_dock/water_edge_2m", x, -14.4, 0, z=ground(x, -13.2) - 0.88, tags=("rock", "blocker", "coast"))
    for y in (-14.8, -16.8):
        place("nature_dock/rope_posts", -22.95, y, 90, z=zA)
    for y in (-14.5, -16.5, -18.5):
        place("nature_dock/rope_posts", -10.95, y, 90, z=zB)
    place("nature_dock/rope_posts_bunting", -12.0, -13.6, 0, z=zB)
    place("interaction_props/mooring_post", -8.83, -14.03, 0, tags=BLOCK)
    # pier A: the catch of the day on its stand, tackle crate, bucket
    place("interaction_props/catch_display_stand", -24.75, -18.8, 90, z=zA + 0.06, tags=BLOCK)
    place("fishing/tackle_crate", -23.3, -16.3, 20, z=zA + 0.06)
    place("fishing/bucket", -23.35, -18.2, 0, z=zA + 0.06)
    place("fishing/fish_round", -23.35, -19.0, 35, z=zA + 0.1)
    place("fishing/fish_slim", -23.35, -19.4, 160, z=zA + 0.1)
    place("fishing/fish_spiky", -23.35, -17.6, 80, z=zA + 0.1)
    # boathouse dock corner: crate stack and a barrel on the deck edge
    place("world_misc/crate", -28.6, -21.35, 10, z=zA + 0.06)
    place("world_misc/crate", -28.6, -21.35, 35, z=zA + 0.59)
    place("world_misc/barrel", -27.9, -21.45, 0, z=zA + 0.06)
    # pier B: life ring on the rail, a bucket of fish
    place("fishing/life_ring", -11.05, -16.5, 90, z=zB + 0.3)
    place("fishing/bucket_fish", -11.35, -18.0, 0, z=zB + 0.06)
    # houseboat moored south of pier B's T head with a gangway tile
    place("homes/houseboat_exterior", -14.5, -29.0, 180, z=T.WATER_Z + 0.02, tags=("building", "blocker"), name="Houseboat")
    place("nature_dock/dock_straight", -14.0, -24.0, 0, z=zB, tags=WALK, name="Gangway")
    place("nature_dock/dock_straight", -14.0, -26.0, 0, z=zB, tags=WALK)
    mark("HouseboatDoor", -14.05, -26.4, 0, kind="door", target="home", z=zB)
    # boats, bobbers with ripples, a few cove floes
    place("fishing/rowboat", -9.4, -20.4, 75, z=T.WATER_Z)
    place("fishing/rowboat", -21.0, -24.0, -20, z=T.WATER_Z)
    for x, y in [(-11.6, -26.0), (-19.0, -28.0), (-27.0, -26.5), (-8.6, -18.0)]:
        place("fishing/bobber", x, y, 0, z=T.WATER_Z)
        place("fishing/ripple", x, y, 0, z=T.WATER_Z + 0.01, tags=DECOR)
    for x, y, yaw in [(-17.0, -20.0, 30), (-20.5, -23.0, 140), (-9.6, -23.5, 250)]:
        place("fishing/ice_floe_b", x, y, yaw, z=T.WATER_Z - 0.06, tags=DECOR)
    # shoreline kit: fenders on the T head facing the houseboat, cleats on the gangway, rope coil and
    # lantern brackets on the rails, a ladder off pier B, an end cap where the gangway meets the boat
    for x in (-15.3, -12.7):
        place("nature_dock/boat_fender", x, -23.55, 0, z=zB - 0.3, tags=DECOR)
    for x in (-14.8, -13.2):
        place("nature_dock/mooring_cleat", x, -26.85, 0, z=zB + 0.06, tags=DECOR)
    place("nature_dock/dock_end_cap", -14.0, -27.0, 0, z=zB)
    place("nature_dock/coiled_rope", -23.3, -15.3, 30, z=zA + 0.06, tags=DECOR)
    place("nature_dock/dock_lantern_bracket", -11.05, -20.2, 90, z=zB)
    place("nature_dock/dock_lantern_bracket", -22.95, -18.6, 90, z=zA)
    place("nature_dock/dock_ladder", -10.85, -20.9, 90, z=zB - 1.2, tags=DECOR)
    # cove beach: foam along the waterline, shallows just offshore, rocks and pebbles on the sand
    for x, y, yaw in [(-6.52, -27.73, 225), (-4.98, -25.72, 240), (-4.09, -23.3, 260), (-4.09, -20.7, 280), (-4.98, -18.29, 300)]:
        place("nature_dock/foam_edge_strip", x, y, yaw, z=T.WATER_Z, tags=DECOR)
    place("nature_dock/shallow_water_patch", -5.6, -22.6, 20, z=T.WATER_Z - 0.3, tags=DECOR)
    place("nature_dock/shallow_water_patch", -6.6, -25.4, 70, z=T.WATER_Z - 0.3, tags=DECOR)
    place("nature_dock/rock_cluster", -2.9, -21.2, 40, tags=ROCK)
    place("nature_dock/rock_small_b", -2.4, -22.4, 120, tags=ROCK)
    place("nature_dock/pebble_cluster", -3.0, -24.6, 75, tags=ROCK)


# -------------------------------------------------------------------------------------- south pier --
def south_pier():
    global ZONE
    ZONE = "pier"
    zS = ground(1.7, -28.65) + 0.07
    T.DOCK_Z["S"] = zS
    for k in range(4):
        place("nature_dock/dock_straight", 1.7, -30.3 - 2 * k, 0, z=zS, tags=WALK)
        if k == 0:
            T.DOCK_HEADS.append((T.PLACE[-1], Vector((0, -1))))
    place("fishing/fishing_dock_spot", 1.7, -38.3, 0, z=zS, tags=WALK)
    place("nature_dock/dock_straight", 1.7, -40.3, 0, z=zS, tags=WALK)
    # lighthouse on its rocky point at the pier's end, door facing the pier
    lx, ly = 3.3, -43.8                                    # door socket (1.6, -2.1) lands on the pier's axis
    place("homes/lighthouse_loft_exterior", lx, ly, 180, z=0.0, tags=("building", "blocker"), name="Lighthouse")
    mark("LighthouseDoor", lx - 1.6, ly + 2.1, 0, kind="door", target="home", z=zS)
    for k, (x, y) in enumerate([(-2.62, -45.17), (-2.19, -46.38), (-1.38, -47.34), (-0.25, -47.88), (0.99, -47.97),
                                (2.21, -47.62), (3.31, -46.85), (4.27, -45.71), (4.95, -44.36)]):
        place(["nature_dock/rock_cluster_snow", "winter/rock_cluster_snow_large"][k % 2], x + 1.6, y, k * 40,
              z=T.WATER_Z - 0.35, tags=("rock", "coast"), scale=1.6 + 0.2 * (k % 3))
    # quay edging either side of the pier head
    for x in (-0.4, -2.4, 3.8, 5.8):
        place("plaza/plaza_edge_2m", x, -29.6, 0, z=ground(x, -29.0) - 0.88, tags=("prop", "blocker", "coast"))
    place("plaza/plaza_edge_corner", -3.8, -29.6, 0, z=ground(-3.8, -29.0) - 0.88, tags=("prop", "coast"))
    place("plaza/plaza_edge_1m", 7.3, -29.6, 0, z=ground(7.3, -29.0) - 0.88, tags=("prop", "coast"))
    # sea lookout west of the pier: bench and a lamp facing the open water
    ZONE = "lookout"
    place("plaza/bench", -4.39, -28.88, 0, tags=BLOCK)
    place("plaza/lantern_post", -5.69, -28.58, 0, tags=LIGHT)
    # rocks at the stream mouth and on the court beach
    ZONE = "beach"
    for asset, x, y, yaw, s in [("nature_dock/rock_cluster", 4.9, -29.6, 30, 1.1), ("nature_dock/rock_small_a", 4.2, -30.6, 150, 1.0),
                                ("nature_dock/rock_cluster", 10.8, -30.2, 210, 0.9), ("nature_dock/rock_small_b", 11.6, -29.4, 80, 1.0),
                                ("nature_dock/rock_cluster", 20.5, -28.6, 300, 1.0), ("nature_dock/rock_small_a", 21.4, -29.3, 20, 0.9),
                                ("nature_dock/rock_small_b", 30.0, -28.9, 100, 1.1)]:
        place(asset, x, y, yaw, tags=ROCK, scale=s)


# ------------------------------------------------------------------------------------------- court --
def court():
    global ZONE
    ZONE = "court"
    cx, cy = 25.5, -19.2                                   # half/hoop yaws match scripts/town_court.gd (9c5de37)
    place("activities/basketball_court_half", cx - 3.85, cy, 90, z=0.0, tags=WALK, name="CourtWest")
    place("activities/basketball_court_half", cx + 3.85, cy, -90, z=0.0, tags=WALK, name="CourtEast")
    place("activities/basketball_hoop", cx - 8.45, cy, 90, tags=BLOCK)     # rim (local -Y) faces +X, into the court
    place("activities/basketball_hoop", cx + 8.45, cy, -90, tags=BLOCK)
    place("activities/scoreboard", cx, cy + 6.2, 0, tags=BLOCK)            # faces the court from the north side
    mark("CourtEntry", cx - 6.0, cy + 4.6, 180, kind="activity", activity="basketball")
    # north fence with the gate where the plaza path arrives and a gap for the sketch path
    place("activities/court_gate", 19.2, cy + 4.7, 0)
    for x in (23.3, 25.5, 32.1, 34.3):
        place("activities/low_boundary_fence", x, cy + 4.7, 0)
    # south side: fence along the beach, two benches behind it looking at the court
    for k in range(-3, 4):
        place("activities/low_boundary_fence", cx + k * 2.2, cy - 4.9, 0)
    for x in (-2.0, 2.0):
        place("plaza/bench", cx + x, cy - 5.6, 180, tags=BLOCK)
    # shooting spots on the west half, ready marker, rack with balls, gear crate
    for k in range(4):
        w = at_socket("activities/basketball_court_half", f"socket_shoot_{k}", cx - 3.85, cy, 90, 0.0)
        place("activities/shooting_spot", w[0], w[1], 90, z=0.065, tags=DECOR)
    place("activities/ready_marker", cx - 5.2, cy + 3.2, 0, z=0.065, tags=DECOR)
    place("activities/ball_rack", 21.5, -13.2, 0, tags=BLOCK)
    for k in range(3):
        place("activities/basketball", 21.1 + 0.4 * k, -13.2, 0, z=ground(21.5, -13.2) + 0.82, tags=DECOR)
    place("activities/gear_crate", 22.9, -13.0, 15, tags=BLOCK)


# ------------------------------------------------------------------------------------------ sketch --
def sketch():
    global ZONE
    ZONE = "sketch"
    sx, sy = 30.875, -0.975
    place("activities/sketch_pavilion", sx, sy, 90, z=0.0, tags=("building", "blocker"), name="SketchClub")
    place("activities/communal_table", sx, sy, 0, z=0.0, tags=BLOCK)
    place("activities/easel_display", sx + 3.6, sy + 2.4, -120)
    place("world_misc/notice_board_club", 27.48, 2.83, 150, tags=BLOCK)
    mark("SketchEntry", sx - 3.6, sy, -90, kind="activity", activity="sketch")
    # outdoor drawing table south of the pavilion: six stools, lantern, pads, pencils, timer, paper tray
    tx, ty = 33.08, -6.57
    place("activities/sketch_table", tx, ty, 0, tags=BLOCK)
    for k in range(6):
        w = at_socket("activities/sketch_table", f"socket_seat_{k}", tx, ty, 0)
        if w:
            place("activities/sketch_stool", w[0], w[1], 0)
    top = ground(tx, ty) + 0.6
    place("activities/table_lantern", tx, ty, 0, z=top, tags=DECOR)
    place("activities/drawing_pad", tx - 0.95, ty - 0.3, -12, z=top, tags=DECOR)
    place("activities/drawing_pad", tx + 0.95, ty + 0.3, 15, z=top, tags=DECOR)
    place("activities/pencil_cup", tx + 0.6, ty - 0.25, 0, z=top, tags=DECOR)
    place("activities/pencil", tx - 0.6, ty - 0.22, 70, z=top, tags=DECOR)
    place("activities/eraser", tx - 0.45, ty + 0.25, 20, z=top, tags=DECOR)
    place("activities/table_timer", tx + 1.3, ty, 90, z=top, tags=DECOR)
    place("activities/paper_tray", tx - 1.3, ty, 90, z=top, tags=DECOR)
    place("activities/easel_board", 35.67, -6.17, -90, tags=BLOCK)


# ------------------------------------------------------------------------------------------- arena --
def arena():
    global ZONE
    ZONE = "arena"
    az = T.ARENA_Z
    ax, ay = 21.8, 18.3                                     # blockout origin (its local 0,0)
    place("winter/snowball_arena_blockout", ax, ay, 0, z=az, tags=("prop",), name="SnowballArena")
    mark("ArenaGate", 24.7, 18.8, 0, kind="activity", activity="snowballs", z=az)
    # team ready pads with foot rings, respawn pads, flags, the snowball pile, scoreboard
    place("winter/ready_pad", 26.6, 18.6, 0, tints={"team": "#E86D58"})
    place("winter/ready_pad", 28.9, 18.6, 0, tints={"team": "#207D85"})
    place("interaction_props/team_foot_ring", 26.6, 20.0, 0, z=az + 0.02, tags=DECOR, tints={"team": "#E86D58"})
    place("interaction_props/team_foot_ring", 28.9, 20.0, 0, z=az + 0.02, tags=DECOR, tints={"team": "#207D85"})
    place("interaction_props/respawn_pad", 24.32, 21.02, 0, tints={"team": "#E86D58"})
    place("interaction_props/respawn_pad", 31.3, 18.8, 0, tints={"team": "#207D85"})
    place("winter/team_flag", ax - 0.2, ay + 8.6, 0, z=az, tints={"team": "#E86D58"})
    place("winter/team_flag", ax + 12.4, ay + 8.6, 0, z=az, tints={"team": "#207D85"})
    place("winter/snowball_pile", 27.8, 25.8, 0, z=az)
    place("interaction_props/match_scoreboard", 30.8, 17.7, 0, tags=BLOCK)
    place("winter/spectator_bench_snow", 30.0, 18.2, 180, tags=BLOCK)
    place("winter/spectator_bench_snow", 33.0, 18.2, 180, tags=BLOCK)
    # north-east corner: snow bank cover, puff, snow fence and a boundary fence along the east edge
    place("winter/snow_bank_cover", 33.2, 27.9, 0, tags=BLOCK)
    place("winter/snow_puff", 34.8, 22.3, 0, tags=DECOR)
    place("winter/snow_fence_1m", 33.3, 28.5, 90, tags=BLOCK)
    run("winter/arena_boundary_fence", (35.4, 19.4), (35.4, 23.8), 2.2)
    # a little snow fort below the plateau beside the stairs, where waiting players hang out
    place("winter/snow_wall_straight", 28.68, 15.68, 0, tags=BLOCK)
    place("winter/snow_wall_straight", 30.73, 15.68, 0, tags=BLOCK)
    place("winter/snow_wall_corner", 27.38, 16.28, 90, tags=BLOCK)
    place("winter/snowball_pile", 29.68, 16.68, 0)
    # rock faces on the plateau's south edge (gap at the stairs), corner modules at both ends
    for x, big in [(22.1, 1), (26.3, 1), (28.4, 0), (30.5, 1), (32.6, 0), (34.7, 1)]:
        place("town_connections/cliff_straight_2m" if big else "town_connections/cliff_straight_1m", x, 16.7, 0,
              z=az - (2.05 if big else 1.0), tags=("rock", "blocker", "coast"))
    for x, yaw in [(20.75, 0), (35.95, 90)]:
        place("town_connections/cliff_corner_outer", x, 16.7, yaw, z=az - 2.05, tags=("rock", "blocker", "coast"))
        place("town_connections/snow_overlay_cliff_corner_outer", x, 16.7, yaw, z=az + 0.02, tags=("decor", "coast"))


# ------------------------------------------------------------------------------------------- woods --
def woods():
    """Tree clumps between the districts (the deep coastal forest is generated in town.py)."""
    F, M_, L = "winter/fir_tree_small", "winter/fir_tree_medium", "winter/fir_tree_large"
    # stream woods: east bank between the plaza bridge and the court path
    grove([(L, 21.2, -6.6, 15, 1.05), (M_, 22.9, -8.6, 120, 1.0), (F, 20.3, -9.6, 220, 0.95), (M_, 24.6, -5.9, 300, 0.9),
           ("nature_dock/broad_tree", 23.6, -10.8, 40, 1.0), ("nature_dock/small_tree", 18.2, -9.4, 160, 1.0)])
    place("nature_dock/rock_small_a_snow", 21.9, -7.7, 75, tags=ROCK, zone="woods")
    # south woods: between the south spoke and the stream mouth
    grove([(L, 4.5, -16.2, 0, 1.0), (M_, 5.0, -19.6, 90, 0.95), (F, 3.8, -22.6, 200, 1.0), (M_, 4.4, -25.0, 310, 0.9),
           (F, 5.8, -14.2, 140, 0.9)])
    # east of the stream mouth, between the stream and the court's west hoop
    grove([(M_, 11.4, -17.4, 30, 1.0), (L, 13.2, -19.6, 150, 1.05), (F, 11.0, -21.4, 250, 0.9), (M_, 13.6, -23.0, 80, 0.95),
           (L, 11.8, -24.8, 190, 1.0), (F, 14.6, -16.6, 320, 0.9), (M_, 14.9, -25.4, 10, 0.9)])
    place("nature_dock/rock_small_a_snow", 12.4, -22.2, 50, tags=ROCK, zone="woods")
    # cove woods: west of the south spoke, above the cove beach
    grove([(L, -3.2, -16.6, 60, 1.0), (M_, -2.0, -18.6, 170, 1.0), (F, -1.6, -20.6, 260, 0.95), (F, -7.0, -14.0, 20, 0.9),
           ("nature_dock/broad_tree_snow", -1.4, -22.8, 110, 1.0)])
    place("winter/rock_cluster_snow_small", -4.6, -15.2, 30, tags=ROCK, zone="woods")
    # between the arcade, the casino and the arena stairs
    grove([(M_, 21.0, 12.6, 50, 0.95)])
    # north woodland behind the cinema, around the spring
    grove([(M_, 5.6, 29.0, 80, 1.0), (L, 9.6, 28.4, 160, 1.05), (M_, 11.2, 30.6, 260, 0.9), (F, 7.4, 31.4, 330, 1.0),
           (F, 3.8, 30.6, 45, 0.95), (L, 12.6, 28.0, 120, 1.0)])
    # around the A-frame at the west end of the north street (kept off the sled hill)
    grove([(L, -35.4, 15.4, 20, 1.05), (M_, -35.2, 11.6, 140, 1.0), (F, -29.4, 16.0, 260, 0.95), (M_, -31.0, 16.9, 60, 0.9),
           (F, -35.4, 17.6, 300, 0.9)], zone="homes")
    # east of the casino and the east loop path
    grove([(L, 33.2, 13.6, 10, 1.05), (M_, 34.8, 11.4, 110, 1.0), (F, 33.0, 9.8, 230, 0.9), (M_, 35.4, 7.8, 300, 0.95),
           (L, 36.2, 13.2, 70, 1.0), (F, 33.8, 6.0, 160, 0.9)])
    place("winter/rock_cluster_snow_small", 34.0, 12.6, 15, tags=ROCK, zone="woods")
    # behind the sketch club
    grove([(M_, 36.2, -9.6, 40, 1.0), (F, 34.4, -11.0, 200, 0.9), (L, 36.8, -2.6, 120, 1.0), (F, 37.0, -5.0, 280, 0.9),
           (M_, 31.2, -10.8, 330, 0.95)], zone="sketch")
    # behind the cafe, below the sled stairs
    grove([(L, -5.4, 22.4, 120, 1.0), (M_, -7.6, 24.2, 20, 0.95), (F, -4.6, 25.8, 240, 1.0),
           ("nature_dock/broad_tree", -12.2, 21.2, 300, 1.0), ("nature_dock/small_tree", -14.2, 19.6, 140, 0.95)])


# -------------------------------------------------------------------------------------- wayfinding --
def wayfinding():
    global ZONE
    ZONE = None
    # activity signs with icons at each destination entrance, facing the approach path
    sign(-3.6, 6.6, -101.3, "icon_cafe")
    sign(2.9, 15.6, -90.0, "icon_cinema")
    sign(8.72, 5.18, 146.3, "icon_arcade")
    sign(-10.26, -8.09, 63.4, "icon_fishing")
    sign(-11.6, 17.6, 113.2, "icon_sled")
    sign(22.6, 13.6, 123.7, "icon_snowball")
    sign(18.28, -11.72, 31.0, "icon_basketball")
    sign(26.0, 2.2, 19.7, "icon_drawing")
    # destination signposts at the junctions
    for x, y, yaw in [(-14.08, 2.81, 0), (10.32, -2.48, 60), (-14.78, -8.02, 0), (7.0, 20.2, 30), (32.6, 5.6, 0),
                      (26.12, -12.32, 0), (-7.6, 15.6, 90), (-22.02, -7.39, 90), (-21.5, 8.0, 0)]:
        place("world_misc/destination_signpost", x, y, yaw, tags=BLOCK)
    # path lanterns where they mean something: bridge ends, the homes crossroads, the cove path, the pier head
    for x, y in [(10.6, 1.65), (16.1, -1.95),                     # plaza bridge
                 (9.09, -7.46), (11.77, -13.46),                  # court-path bridge
                 (13.2, 24.2), (19.0, 21.3),                      # cinema-arena bridge
                 (-33.6, 1.75),                                   # homes (none at the crossroads: doors)
                 (-15.9, -13.4), (-21.0, -13.85),                 # cove shore path
                 (-0.35, -27.5), (3.35, -27.5), (-0.95, -18.5),    # south spoke and pier head
                 (31.85, 8.3), (-8.4, 16.4)]:                     # east loop, sled stairs foot
        place("plaza/lantern_post", x, y, 0, tags=LIGHT)
