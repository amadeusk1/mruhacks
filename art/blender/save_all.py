"""Build every kit into one scene and save Models/all_assets.blend (headless).
  Blender -b --factory-startup --python art/blender/save_all.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "showcase.py")).read())

KITS = ["avatar", "plaza", "nature_dock", "town_connections", "fishing", "buildings", "cafe", "cottage", "world_misc",
        "cinema", "cinema_lobby", "cinema_auditorium", "arcade", "winter", "activities",
        "homes", "room_kit", "home_themes", "interaction_props", "fx", "building_finishing", "interior_finishing"]
kits = [k for k in KITS if os.path.exists(os.path.join(common.ART, "blender", "kits", f"{k}.py"))]
show(kits)
common.setup_render()
bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backups in the vault
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(common.MODELS, "all_assets.blend"), compress=True)
print("SAVED", len(common.ASSETS), "assets from", len(kits), "kits")
