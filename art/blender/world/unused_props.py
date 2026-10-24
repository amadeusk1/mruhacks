"""List outdoor-capable assets not placed in Models/world/town_layout.json.
  python3 art/blender/world/unused_props.py
Interior/housing/held/fx/anim kits and interior-only categories are ignored."""
import json, glob, os

M = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), "Models")
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
placed = {p["id"] for p in json.load(open(os.path.join(M, "world", "town_layout.json")))["placements"]}
unused = []
for man in sorted(glob.glob(os.path.join(M, "*", "manifest.json"))):
    kit = os.path.basename(os.path.dirname(man))
    if kit not in OUTDOOR_KITS:
        continue
    for a in json.load(open(man)):
        i = a["id"]
        name = i.split("/", 1)[1]
        if i in placed or a.get("category") == "terrain":
            continue
        if any(w in name for w in SKIP_WORDS) and kit not in ("fishing", "activities", "interaction_props"):
            continue
        unused.append(i)
print(f"UNUSED {len(unused)} (placed ids {len(placed)})")
for i in unused:
    print("  ", i)
