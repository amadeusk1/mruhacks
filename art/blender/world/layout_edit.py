"""Hand-placement round trip for the town layout.

The town's placements live as real objects in Models/world/town_layout.blend (collection "Layout").
Each placed object is an instance of the asset GLB with custom properties:
    asset_id ("kit/name"), tags (comma list), tints (JSON), zone, name_override
Markers are empties in collection "Markers" with props kind / target / activity.

Use from Blender (live via MCP, or the user in the UI):
    import layout_edit as L
    L.open_layout()            # build the editable scene from town_layout.json (first time) or the .blend
    L.place("plaza/bench", (x, y, z), yaw_deg)   # add one prop (Blender coords, Z-up)
    L.save()                   # write town_layout.blend AND export town_layout.json
Headless:
    Blender -b --python art/blender/world/layout_edit.py -- export   # .blend -> json
    Blender -b --python art/blender/world/layout_edit.py -- import   # json -> .blend (bootstraps)
Terrain/paths stay generated (town.py / ground.py); only placements + markers are hand-authored here.
"""
import bpy, json, math, os, sys

V = "/Users/nick/Documents/club penguin hackathon"
MODELS = os.path.join(V, "Models")
JSON = os.path.join(MODELS, "world", "town_layout.json")
BLEND = os.path.join(MODELS, "world", "town_layout.blend")
_SRC = "_layout_sources"


def _coll(name, hidden=False):
    c = bpy.data.collections.get(name)
    if not c:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    c.hide_render = hidden
    lc = bpy.context.view_layer.layer_collection.children.get(name)
    if lc:
        lc.hide_viewport = hidden
    return c


def _source(asset_id):
    """One hidden imported copy per asset; placed props are linked duplicates of it."""
    src = _coll(_SRC, hidden=True)
    for o in src.objects:
        if o.get("asset_id") == asset_id and o.parent is None:
            return o
    path = os.path.join(MODELS, asset_id + ".glb")
    if not os.path.exists(path):
        return None
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        src.objects.link(o)
    roots = [o for o in new if o.parent is None]
    root = roots[0]
    if len(roots) > 1:  # wrap multiple roots in an empty
        root = bpy.data.objects.new(asset_id, None)
        src.objects.link(root)
        for r in roots:
            r.parent = root
    root["asset_id"] = asset_id
    return root


def _dup(o, coll, parent=None):
    c = o.copy()
    coll.objects.link(c)
    c.parent = parent
    for ch in o.children:
        _dup(ch, coll, c)
    return c


def place(asset_id, loc, yaw_deg=0.0, scale=1.0, tags=("prop",), tints=None, zone=None, name=None):
    src = _source(asset_id)
    if src is None:
        print("MISSING", asset_id)
        return None
    o = _dup(src, _coll("Layout"))
    o.location = loc
    o.rotation_mode = "XYZ"
    o.rotation_euler = (0, 0, math.radians(yaw_deg))
    o.scale = (scale,) * 3
    o["asset_id"] = asset_id
    o["tags"] = ",".join(tags)
    o["tints"] = json.dumps(tints or {})
    if zone:
        o["zone"] = zone
    if name:
        o["name_override"] = name
    o.name = name or asset_id.split("/")[1]
    return o


def mark(name, loc, yaw_deg=0.0, kind="spawn", **extra):
    e = bpy.data.objects.new(name, None)
    _coll("Markers").objects.link(e)
    e.empty_display_type = "SINGLE_ARROW"
    e.location = loc
    e.rotation_euler = (0, 0, math.radians(yaw_deg))
    e["kind"] = kind
    for k, v in extra.items():
        e[k] = v if isinstance(v, (int, float, str)) else json.dumps(v)
    return e


def import_json(path=JSON):
    # path is only read; export_json() decides where output goes
    """Bootstrap the editable scene from the current json (Godot space -> Blender)."""
    d = json.load(open(path))
    for c in ("Layout", "Markers"):
        col = bpy.data.collections.get(c)
        if col:
            for o in list(col.objects):
                bpy.data.objects.remove(o, do_unlink=True)
    for p in d["placements"]:
        x, y, z = p["pos"]
        place(p["id"], (x, -z, y), p.get("rot_y_deg", 0), p.get("scale", 1.0), p.get("tags", ["prop"]),
              p.get("tints"), p.get("zone"), p.get("name"))
    for m in d.get("markers", []):
        x, y, z = m["pos"]
        extra = {k: v for k, v in m.items() if k not in ("name", "pos", "rot_y_deg", "kind")}
        mark(m["name"], (x, -z, y), m.get("rot_y_deg", 0), m.get("kind", "spawn"), **extra)
    bpy.context.scene["layout_meta"] = json.dumps({k: v for k, v in d.items() if k not in ("placements", "markers")})


def export_json(path=JSON):
    """Write placements/markers from the scene. Keeps every non-placement key of the existing json."""
    base = json.load(open(path)) if os.path.exists(path) else (json.load(open(JSON)) if os.path.exists(JSON) else {})
    meta = bpy.context.scene.get("layout_meta")
    if meta:
        base = {**json.loads(meta), **{k: v for k, v in base.items() if k not in ("placements", "markers")}}
    bpy.context.view_layer.update()  # matrix_world is stale until the depsgraph runs
    pl = []
    for o in _coll("Layout").objects:
        if o.parent is not None or "asset_id" not in o:
            continue
        x, y, z = o.matrix_world.translation
        e = {"id": o["asset_id"], "pos": [round(x, 3), round(z, 3), round(-y, 3)],
             "rot_y_deg": round(math.degrees(o.matrix_world.to_euler().z), 2), "scale": round(o.scale.x, 3),
             "tints": json.loads(o.get("tints", "{}")), "tags": [t for t in o.get("tags", "prop").split(",") if t]}
        if o.get("zone"):
            e["zone"] = o["zone"]
        if o.get("name_override"):
            e["name"] = o["name_override"]
        pl.append(e)
    mk = []
    for o in _coll("Markers").objects:
        x, y, z = o.matrix_world.translation
        m = {"name": o.name, "pos": [round(x, 3), round(z, 3), round(-y, 3)],
             "rot_y_deg": round(math.degrees(o.matrix_world.to_euler().z), 2), "kind": o.get("kind", "spawn")}
        for k in o.keys():
            if k not in ("kind",) and not k.startswith("_"):
                v = o[k]
                m[k] = json.loads(v) if isinstance(v, str) and v[:1] in "[{" else v
        mk.append(m)
    base["placements"], base["markers"] = pl, mk
    json.dump(base, open(path, "w"), indent=1)
    print(f"EXPORTED {len(pl)} placements, {len(mk)} markers -> {path}")


def open_layout():
    """In a live session: load the hand-authored .blend layout if it exists, else bootstrap from json."""
    if os.path.exists(BLEND):
        with bpy.data.libraries.load(BLEND, link=False) as (src, dst):
            dst.collections = [c for c in src.collections if c in ("Layout", "Markers", _SRC)]
        for c in dst.collections:
            if c and c.name not in [x.name for x in bpy.context.scene.collection.children]:
                bpy.context.scene.collection.children.link(c)
        _coll(_SRC, hidden=True)
    else:
        import_json()


def save():
    bpy.context.preferences.filepaths.save_version = 0
    export_json()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, copy=True, compress=True)
    print("SAVED", BLEND)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = next((a.split("=", 1)[1] for a in args if a.startswith("out=")), None)
    if "import" in args:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        import_json()
        if out:  # verification run: never touch the live json/.blend
            export_json(out)
        else:
            save()
    elif "export" in args:
        bpy.ops.wm.open_mainfile(filepath=BLEND)
        export_json()
