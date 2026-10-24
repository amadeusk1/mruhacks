"""Pet models. Pengi is a baby penguin with no collar or leash.
Fish wear a collar. The game draws their leash to socket_collar.

Front faces -Y. Origin is on the ground under the pet.
"""
import bpy
from mathutils import Vector
from common import *

KIT = "pets"
PREVIEW_WIDTH = 6.0

BODY_COLORS = ["blue", "green", "yellow", "pink", "red", "orange", "purple", "teal", "charcoal", "white"]
FISH_COLORS = ["orange", "teal_light", "lavender", "yellow", "pink", "sky", "red"]

# scale is applied to the 0.9 m player. Height = 0.9 * scale[2].
PENGUINS = {
    "pebble": dict(scale=(0.49, 0.49, 0.49), body="blue", fluff=False, cheeks=False),
    "puff": dict(scale=(0.58, 0.52, 0.445), body="yellow", fluff=True, cheeks=False),
    "tuxedo": dict(scale=(0.44, 0.40, 0.533), body="charcoal", fluff=False, cheeks=True),
}
# scale multiplies the fishing-kit fish. hover is the body centre above the ground.
FISH = {
    "minnow": dict(shape="round", scale=0.70, hover=0.36),
    "ribbon": dict(shape="slim", scale=0.72, hover=0.34),
    "puffer": dict(shape="spiky", scale=0.55, hover=0.40),
}


def add_penguin(b, kind):
    import bmesh
    import kits.avatar as avatar
    p = PENGUINS[kind]
    sx, sy, sz = p["scale"]
    # Build at the player's size, then scale every vertex. The face overlay is not
    # part of Builder.at, so scaling the frame alone leaves a full-size white shell.
    avatar.bird(b, body=tint("body", p["body"]))
    bmesh.ops.transform(b.bm, matrix=Matrix.Diagonal((*p["scale"], 1.0)), verts=list(b.bm.verts))
    bmesh.ops.recalc_face_normals(b.bm, faces=list(b.bm.faces))
    # The player mesh stores skin weights for an armature these pets do not have.
    deform = b.bm.verts.layers.deform.active
    if deform is not None:
        b.bm.verts.layers.deform.remove(deform)
    avpart = b.bm.verts.layers.int.get("avpart")
    if avpart is not None:
        b.bm.verts.layers.int.remove(avpart)
    if p["cheeks"]:
        for side in (-1, 1):
            b.sphere(0.02 * sz, side * 0.16 * sx, -0.24 * sy, 0.64 * sz, "yellow",
                     u=6, v=4, scale=(1.15, 0.4, 0.85))
    if p["fluff"]:
        for x, y, z, r in ((0.16, -0.05, 0.78, 0.055), (-0.16, -0.02, 0.76, 0.05),
                           (0.0, 0.08, 0.88, 0.06), (0.22, 0.04, 0.48, 0.045),
                           (-0.22, 0.02, 0.46, 0.042), (0.0, 0.16, 0.62, 0.04)):
            b.blob(r * sx, r * sy * 0.9, r * sz, x * sx, y * sy, z * sz, "cream", subdiv=1)


def add_fish(b, kind):
    import kits.fishing as fishing
    p = FISH[kind]
    s, hover = p["scale"], p["hover"]
    z0 = hover - 0.10 * s
    with b.at((0, 0, z0), rotz=-90, scale=s):
        fishing.fish_geo(b, p["shape"])
        b.torus(0.10, 0.012, -0.02, 0, 0.16, "red", segs=10, ring=4, rot=(0, 90, 0))
        b.sphere(0.018, -0.02, 0, 0.24, "gold", u=6, v=4)
        b.socket("collar", (-0.02, 0, 0.24))
    b.socket("hover", (0, 0, hover))


def finish_pet(name, kind, family):
    b = Builder(name, seed=len(name))
    if family == "penguin":
        add_penguin(b, kind)
        sx, sy, sz = PENGUINS[kind]["scale"]
        extra = {"height_m": round(0.9 * sz, 3), "width_m": round(0.74 * sx, 3)}
        colors = {"body": BODY_COLORS}
    else:
        add_fish(b, kind)
        extra = {"hover_m": FISH[kind]["hover"], "shape": FISH[kind]["shape"]}
        colors = {"body": FISH_COLORS, "fin": ["coral", "teal", "purple", "mustard"]}
    return b.finish(KIT, "pet", {
        "family": family, "follow": "ground" if family == "penguin" else "hover",
        "color_variants": colors, **extra,
    })


def _socket_world(obj, name):
    bpy.context.view_layer.update()
    prefix = "socket_" + name
    empty = next(c for c in obj.children if c.name == prefix or c.name.startswith(prefix + "."))
    return empty.matrix_world.translation.copy()


def _place(objs, spots):
    saved = {o: o.location.copy() for o in objs}
    for o, spot in zip(objs, spots):
        o.location = Vector(spot)
    bpy.context.view_layer.update()
    return saved


def _restore(saved):
    for o, loc in saved.items():
        o.location = loc
    bpy.context.view_layer.update()


def _show(objs):
    keep = set(objs)
    keep.update(o for o in bpy.data.objects if o.parent in keep)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o not in keep


def _shot(objs, path, **kw):
    _show(objs)
    render_preview(KIT, objs=objs, path=path, **kw)
    for o in bpy.data.objects:
        o.hide_render = False


def _drop(obj):
    """Take a helper object back out of the kit so it is not exported."""
    ASSETS[:] = [a for a in ASSETS if a["obj"] != obj]
    for c in list(obj.children):
        bpy.data.objects.remove(c, do_unlink=True)
    bpy.data.objects.remove(obj, do_unlink=True)


def _sheets():
    import kits.avatar as avatar
    chicks = [bpy.data.objects[f"pet_{k}"] for k in PENGUINS]
    fish = [bpy.data.objects[f"pet_{k}"] for k in FISH]
    saved = _place(chicks, [(i * 0.85, 0, 0) for i in range(3)])
    _shot(chicks, os.path.join(DETAILS, "pets_chicks.png"), res=(1600, 700), elev=28, azim=28, pad=1.2)
    _restore(saved)
    saved = _place(fish, [(i * 0.7, 0, 0) for i in range(3)])
    _shot(fish, os.path.join(DETAILS, "pets_fish.png"), res=(1600, 700), elev=24, azim=24, pad=1.25)
    _restore(saved)

    player = Builder("pet_scale_ref", seed=1)
    avatar.bird(player)
    player = player.finish(KIT, "mockup", {"note": "render helper"})
    pebble, minnow = bpy.data.objects["pet_pebble"], bpy.data.objects["pet_minnow"]
    hand = Vector(avatar.SOCKETS["hand_R"][1])
    saved = _place([player, pebble, minnow], [(0, 0, 0), (0.58, 0.36, 0), (-0.62, -0.06, 0)])
    leads = Builder("_pet_leads", seed=2)
    rope_between(leads, hand, _socket_world(minnow, "collar"), sag=0.03, r=0.008, segs=6, mat="rope")
    leads = leads.finish(KIT, "mockup", {"note": "render helper"})
    _shot([player, pebble, minnow, leads], os.path.join(DETAILS, "pets_with_player.png"),
          res=(1600, 1100), elev=32, azim=34, pad=1.14)
    _restore(saved)
    _drop(leads)
    _drop(player)


def build():
    for kind in PENGUINS:
        finish_pet(f"pet_{kind}", kind, "penguin")
    for kind in FISH:
        finish_pet(f"pet_{kind}", kind, "fish")
    _sheets()
