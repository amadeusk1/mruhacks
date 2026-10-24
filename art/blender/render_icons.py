"""Inventory / catalogue thumbnails: one transparent PNG per asset, consistent framing.
  Blender -b --factory-startup --python art/blender/render_icons.py -- [kit ...]
Writes Models/<kit>/icons/<asset>.png and adds "icon" to each asset in that kit's manifest.
Default kits are the ones whose items appear in UI cards (wardrobe, inventory, decoration).
"""
import sys, os, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import common
from mathutils import Vector, Euler

DEFAULT = ["avatar", "room_kit", "home_themes", "cafe", "fishing", "interaction_props"]
SIZE = 256
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
kits = [a for a in args if not a.startswith("--")] or DEFAULT


def setup():
    sc = bpy.context.scene
    common.setup_render((SIZE, SIZE))
    sc.render.film_transparent = True
    g = bpy.data.objects.get("_ground")
    if g:
        g.hide_render = True
    try:
        sc.eevee.taa_render_samples = 16
    except AttributeError:
        pass
    # soft fill from the camera side so icons read on any panel colour
    if not bpy.data.objects.get("_fill"):
        ld = bpy.data.lights.new("_fill", "SUN")
        ld.energy = 1.6
        fo = bpy.data.objects.new("_fill", ld)
        sc.collection.objects.link(fo)
        fo.rotation_euler = (math.radians(60), 0, math.radians(200))


def frame(o, elev=28, azim=-30):
    lo, hi = common.bbox(o)
    pts = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    c = sum(pts, Vector()) / 8
    cam = bpy.data.objects.get("_icon_cam")
    if not cam:
        cam = bpy.data.objects.new("_icon_cam", bpy.data.cameras.new("_icon_cam"))
        bpy.context.scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    # front (-Y) three-quarter, slightly above: matches how items sit in the world
    cam.rotation_euler = Euler((math.radians(90 - elev), 0, math.radians(azim)))
    fwd = cam.rotation_euler.to_matrix() @ Vector((0, 0, -1))
    cam.location = c - fwd * 20
    cam.data.clip_end = 100
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    ps = [inv @ p for p in pts]
    w = max(p.x for p in ps) - min(p.x for p in ps)
    h = max(p.y for p in ps) - min(p.y for p in ps)
    cam.data.ortho_scale = max(w, h) * 1.12
    mx = (max(p.x for p in ps) + min(p.x for p in ps)) / 2
    my = (max(p.y for p in ps) + min(p.y for p in ps)) / 2
    cam.location = cam.matrix_world @ Vector((mx, my, 0))
    bpy.context.scene.camera = cam


for kit in kits:
    common.reset_scene()
    mod = common.load_kit(kit)
    mod.build()
    common.ensure_shade()
    setup()
    roots = [a["obj"] for a in common.roots_of(kit) if a["obj"].parent is None]
    out = os.path.join(common.MODELS, kit, "icons")
    os.makedirs(out, exist_ok=True)
    made = {}
    worn = {}
    if kit == "avatar":
        # wearables read badly as loose shells: show them on a neutral grey penguin
        A = mod
        body_src = bpy.data.objects["avatar_base_mesh"]
        grey = bpy.data.materials.new("_icon_body")
        grey.diffuse_color = common.hex_rgb("#C9D1D9") + [1]
        grey.use_nodes = True
        next(n for n in grey.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = grey.diffuse_color
        meta = {a["obj"].name: a["meta"] for a in common.roots_of(kit)}
        for o in roots:
            slot = meta.get(o.name, {}).get("slot")
            if slot not in ("torso", "back", "neck", "face"):
                continue
            body = body_src.copy(); body.data = body_src.data.copy(); body.parent = None; body.modifiers.clear()
            body.data.materials.clear()
            for m in body_src.data.materials:
                body.data.materials.append(grey if m and m.name.startswith("tint_body") else m)
            bpy.context.scene.collection.objects.link(body)
            body.location = (0, 0, 0)
            if slot == "torso":
                item = bpy.data.objects[o.name + "_mesh"].copy(); item.modifiers.clear(); item.parent = None
                item.location = (0, 0, 0)
            else:
                item = o.copy(); item.parent = None
                item.location = Vector(A.SOCKETS[{"back": "back", "neck": "neck", "face": "face"}[slot]][1])
            bpy.context.scene.collection.objects.link(item)
            worn[o.name] = (body, item, 150 if slot == "back" else -25)
    for o in roots:
        # show only this asset (and its children)
        keep = set(common.hierarchy(o))
        if o.name in worn:
            keep = {worn[o.name][0], worn[o.name][1]}
        for ob in bpy.data.objects:
            if ob.type in ("MESH", "CURVE", "FONT"):
                ob.hide_render = ob not in keep
        if o.type == "ARMATURE":  # rigged item: frame its mesh children
            pass
        if o.name in worn:
            body, item, az = worn[o.name]
            frame(body, elev=18, azim=az)
        else:
            frame(o)
        path = os.path.join(out, f"{o.name}.png")
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        made[o.name] = f"{kit}/icons/{o.name}.png"
    man_p = os.path.join(common.MODELS, kit, "manifest.json")
    if os.path.exists(man_p):
        man = json.load(open(man_p))
        for a in man:
            nm = os.path.basename(a["file"])[:-4]
            if nm in made:
                a["icon"] = made[nm]
        json.dump(man, open(man_p, "w"), indent=2)
    print(f"ICONS {kit}: {len(made)}")
