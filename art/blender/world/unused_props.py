"""Prop coverage: outdoor-capable assets placed in Models/world/town_layout.json, with a reason for every
deliberate exclusion. Prints the report and writes Renders/Map/coverage.md (build_town.py runs it after export).
  python3 art/blender/world/unused_props.py
Interior/housing/held/fx/anim kits and interior-only categories are ignored."""
import json, glob, os

V = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
M = os.path.join(V, "Models")
OUTDOOR_KITS = {"plaza", "nature_dock", "fishing", "winter", "world_misc", "town_connections", "activities",
                "building_finishing", "interaction_props", "homes", "cinema", "arcade", "cafe", "casino", "cottage"}
# shells, interiors, held items, modules and pieces that only make sense indoors or inside other assets
SKIP_WORDS = ("interior", "shell", "_roof", "mod_", "counter", "coffee", "mug", "pastry", "plate", "cup", "cake",
              "croissant", "muffin", "cookie", "teapot", "saucer", "spoon", "tongs", "jar", "napkin", "tray", "menu",
              "card", "chip", "roulette", "slot_", "poker", "blackjack", "dealer", "blind", "deck", "lounge",
              "lobby", "auditorium", "seat_", "screen", "curtain", "speaker", "riser", "aisle", "kiosk", "popcorn",
              "drink", "reservation", "team_badge", "foot_ring", "concession", "cabinet", "token", "poster",
              "rug", "insert", "bed", "desk", "chair", "shelf", "wall_panel", "exit_door", "double_doors",
              "facade", "marquee", "stair", "entrance", "casino_planter", "suit_plaque", "coat_stand", "side_table",
              "wall_lamp", "standing_lamp", "card_mat", "ball", "fish_", "pencil", "pad", "eraser", "timer",
              "paper", "room_example", "dock_spot")
_TILES = "path tiles: paths are continuous ribbon meshes from ground.py"
_TRIM = "house-kit trim; the placed exteriors already have their trims, sills and caps modelled in"
_SLED = "sled hill pieces: owned by sled_hill.py (sled builder)"
EXCLUDE = {
    "activities/court_tile_plain": "court is built from the two court_half pieces",
    "activities/court_tile_straight": "court is built from the two court_half pieces",
    "activities/court_tile_corner": "court is built from the two court_half pieces",
    "activities/court_tile_arc": "court is built from the two court_half pieces",
    "activities/court_tile_key": "court is built from the two court_half pieces",
    "plaza/paving_1x1": "plaza disc and paths are ribbon meshes from ground.py",
    "plaza/paving_2x2": "plaza disc and paths are ribbon meshes from ground.py",
    "town_connections/straight_path_tile": _TILES, "town_connections/path_corner": _TILES,
    "town_connections/path_junction_t": _TILES, "town_connections/path_junction_x": _TILES,
    "town_connections/path_end": _TILES, "town_connections/snow_overlay_straight_path": _TILES,
    "town_connections/snow_overlay_path_corner": _TILES, "town_connections/snow_overlay_path_junction_t": _TILES,
    "town_connections/snow_overlay_path_junction_x": _TILES, "town_connections/snow_overlay_path_end": _TILES,
    "town_connections/stone_step": "0.5 m riser; every door in town sits at grade",
    "town_connections/landing": "bridges hand over to the paving directly (flush ends, check_seams)",
    "town_connections/footbridge_approach_landing": "bridges hand over to the paving directly (flush ends, check_seams)",
    "town_connections/stream_straight": "the stream is a carved terrain channel",
    "town_connections/stream_end": "the stream starts at a rock spring and ends over the coast (stream.py)",
    "world_misc/waterfall_step": "falls and weirs are generated water sheets in stream.py, framed by cliff pieces",
    "town_connections/stream_bend": "the stream is a carved terrain channel",
    "town_connections/stream_bank": "regularly spaced bank modules read as procedural; banks are carved terrain with rock clusters",
    "town_connections/cliff_corner_inner": "no concave cliff corner anywhere on this coastline",
    "town_connections/snow_overlay_cliff_corner_inner": "no concave cliff corner anywhere on this coastline",
    "nature_dock/water_tile_2x2": "water is one generated plane",
    "nature_dock/shallow_water_patch": "the water shader shades shallows from water_shore.png; a flat patch read as a square",
    "nature_dock/water_edge_2m": "the cove's north quay became the boardwalk joining the piers",
    **{f"nature_dock/{n}": "the cove is a sculpted sand beach with a quay wall; modular shore banks would double that edge"
       for n in ("shore_bank_sloped", "snow_overlay_shore_bank_sloped", "shore_inner_corner", "snow_overlay_shore_inner_corner",
                 "shore_outer_corner", "snow_overlay_shore_outer_corner")},
    "nature_dock/water_edge_corner": "3.3 m corner block; the quay wall ends against the two piers",
    "winter/slope_section": _SLED, "winter/banked_turn": _SLED, "winter/start_platform": _SLED,
    "interaction_props/finish_timer": _SLED,
    "interaction_props/seat_reservation_marker": "cinema auditorium seat marker (indoor)",
    "interaction_props/team_badge": "worn by players, not placed",
    "casino/table_marker": "casino table-game marker (indoor)",
    "nature_dock/flower_clump": "free-standing flowers read as scatter; plants live only in beds by walls, the plaza ring and gate posts",
    "nature_dock/shrub_flowering": "replaced by cottage/shrub_flowering in the casino wall beds",
    "nature_dock/shrub_round": "replaced by cottage/shrub_round in the wall beds",
    "nature_dock/leaf_tuft": "free-standing tufts read as scatter; leaf_tuft_small sits at the homes gate posts",
    **{f"building_finishing/{n}": _TRIM for n in ("foundation_skirt_1m", "foundation_skirt_2m", "foundation_skirt_corner",
                                                  "exterior_corner_trim", "window_sill", "window_shutters", "roof_ridge_cap",
                                                  "roof_end_cap", "eave_trim", "chimney_cap", "snow_eave_overlay",
                                                  "wall_sign_bracket")},
}
LANDMARKS = [("homes/houseboat_exterior", "at anchor in the outer cove, south-west of pier B, clear of every fishing cast"),
             ("homes/lighthouse_loft_exterior", "rocky point at the end of the south pier, reached along the pier"),
             ("homes/treehouse_exterior", "fir grove on the north street of the homes district"),
             ("homes/aframe_cabin_exterior", "west end of the north street, in its own fir grove"),
             ("homes/round_cottage_exterior", "homes lot, NE of the crossroads"),
             ("homes/snow_dome_exterior", "homes lot, SW of the crossroads"),
             ("cottage/cottage_exterior", "two homes lots plus the boathouse on pier A")]


def report(write_md=True):
    placed = {}
    for p in json.load(open(os.path.join(M, "world", "town_layout.json")))["placements"]:
        placed[p["id"]] = placed.get(p["id"], 0) + 1
    relevant, unused = [], []
    for man in sorted(glob.glob(os.path.join(M, "*", "manifest.json"))):
        kit = os.path.basename(os.path.dirname(man))
        if kit not in OUTDOOR_KITS:
            continue
        for a in json.load(open(man)):
            i = a["id"]
            if a.get("category") == "terrain" or i in EXCLUDE:
                continue
            if i not in placed and any(w in i.split("/", 1)[1] for w in SKIP_WORDS) and kit not in ("fishing", "activities", "interaction_props"):
                continue
            relevant.append(i)
            if i not in placed:
                unused.append(i)
    cov = 100.0 * (len(relevant) - len(unused)) / max(1, len(relevant))
    print(f"COVERAGE {cov:.1f}% ({len(relevant) - len(unused)}/{len(relevant)} outdoor-relevant models placed, "
          f"{len(EXCLUDE)} excluded with reasons)")
    for i in unused:
        print("  UNUSED", i)
    if write_md:
        L = ["# Town prop coverage", "", f"**{cov:.1f}%** of outdoor-relevant models placed "
             f"({len(relevant) - len(unused)} of {len(relevant)}). Generated by `art/blender/world/unused_props.py` on every town export.", "",
             "## Landmarks", "", "| Model | Where |", "| --- | --- |"]
        L += [f"| `{i}` | {w} |" for i, w in LANDMARKS if i in placed]
        L += ["", "## Not yet placed", ""] + ([f"- `{i}`" for i in unused] or ["- none"])
        L += ["", "## Deliberately excluded", "", "| Model | Reason |", "| --- | --- |"]
        L += [f"| `{i}` | {r} |" for i, r in sorted(EXCLUDE.items())]
        L += ["", "## Placed (count)", "", "| Model | Count |", "| --- | --- |"]
        L += [f"| `{i}` | {n} |" for i, n in sorted(placed.items())]
        os.makedirs(os.path.join(V, "Renders", "Map"), exist_ok=True)
        open(os.path.join(V, "Renders", "Map", "coverage.md"), "w").write("\n".join(L) + "\n")
    return cov, unused


if __name__ == "__main__":
    report()
