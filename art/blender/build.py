"""Headless entry point:
  Blender -b --factory-startup --python art/blender/build.py -- <kit> [<kit> ...] [--no-preview] [--save]
Builds each kit, writes art/models/<kit>/*.glb + manifest.json, renders Renders/Kits/<kit>.png in the vault.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
kits = [a for a in args if not a.startswith("--")]
for kit in kits:
    common.build_kit(kit, preview="--no-preview" not in args)
    if "--save" in args:
        import bpy
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(common.ART, "blender", "out", f"{kit}.blend"))
    print(f"BUILT {kit}: {len(common.roots_of(kit))} assets")

import render_index
render_index.main()

import subprocess
subprocess.run([sys.executable if not sys.executable.endswith("Blender") else "python3",
                os.path.join(os.path.dirname(os.path.abspath(__file__)), "check_parts.py")])
