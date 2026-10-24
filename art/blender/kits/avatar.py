"""Avatar kit: base bird + rig + animations, hats, modular wardrobe, accessories.

Rig contract (shared by avatar_base and every wardrobe GLB):
  bones root, body, head, flipper.L, flipper.R, foot.L, foot.R (character faces -Y; .L is +X).
  Wardrobe GLBs carry their own copy of the rig, so the game rebinds them to the avatar
  skeleton by bone name.
Sockets on avatar_base are empties parented to bones. Their bind-pose world positions are
listed in meta "sockets_world" because the manifest's "sockets" are bone-local.
Hats and accessories are rigid. Each has its origin at the socket it attaches to (meta "slot").
Recolourable parts use tint roles: body, cloth_primary, cloth_secondary.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Quaternion
from common import *

KIT = "avatar"
PREVIEW_WIDTH = 7.0

# ---------------------------------------------------------------------------
# Body shape: (z, half-width). Half-depth = half-width * DEPTH.
# ---------------------------------------------------------------------------
PROFILE = [(0.035, 0.0), (0.045, 0.16), (0.07, 0.26), (0.11, 0.322), (0.17, 0.355), (0.25, 0.368),
           (0.34, 0.362), (0.43, 0.345), (0.51, 0.322), (0.58, 0.303), (0.65, 0.29), (0.71, 0.276),
           (0.77, 0.252), (0.82, 0.218), (0.86, 0.172), (0.885, 0.115), (0.898, 0.05), (0.90, 0.0)]
DEPTH = 0.86
N = 28  # columns around the body
BODY = tint("body", "#3E7DD6")
GROUPS = ["root", "body", "head", "flipper.L", "flipper.R", "foot.L", "foot.R"]
FLIP_ANG = 35.0                                   # flipper tilt out from vertical (deg)
FLIP_C = Vector((0.372, 0.035, 0.375))            # left flipper centre (mirror x for right)
FLIP_D = Vector((math.sin(math.radians(FLIP_ANG)), 0, -math.cos(math.radians(FLIP_ANG))))  # down-and-out
FLIP_L = 0.19                                     # half length
_fl = lambda sx, t: tuple((FLIP_C + FLIP_D * t) * Vector((sx, 1, 1)))
BONES = [  # name, head, tail, parent
    ("root", (0, 0, 0), (0, 0, 0.12), None),
    ("body", (0, 0, 0.12), (0, 0, 0.56), "root"),
    ("head", (0, 0, 0.56), (0, 0, 0.90), "body"),
    ("flipper.L", _fl(1, -FLIP_L), _fl(1, FLIP_L), "body"),
    ("flipper.R", _fl(-1, -FLIP_L), _fl(-1, FLIP_L), "body"),
    ("foot.L", (0.13, -0.05, 0.05), (0.13, -0.22, 0.03), "root"),
    ("foot.R", (-0.13, -0.05, 0.05), (-0.13, -0.22, 0.03), "root"),
]
EYE_Z, EYE_PHI = 0.70, 24.0
BODY_COLORS = {"blue": "#3E7DD6", "green": "#5DAA3C", "yellow": "#F2C230", "pink": "#F2A0B5",
               "red": "#D9473B", "orange": "#F08A2E", "purple": "#7B4FC4", "teal": "#2FA3A3",
               "black": "#2E3440", "white": "#E9EEF2"}


def ss(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def rx(z):
    if z <= PROFILE[0][0]:
        return 0.0
    for (z0, r0), (z1, r1) in zip(PROFILE, PROFILE[1:]):
        if z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return 0.0


def surf(z, phi, off=0.0):
    """Point on the body surface at height z, angle phi (deg, 0 = front, +90 = +X), pushed out by off."""
    r, a = rx(z), math.radians(phi)
    return Vector(((r + off) * math.sin(a), -(r * DEPTH + off) * math.cos(a), z))


SOCKETS = {  # name: (bone, bind-pose world position)
    "head": ("head", (0, 0, 0.72)),                                  # brow level: hats build upward from here
    "face": ("head", tuple(surf(EYE_Z, 0, 0.0))),                    # front of the face between the eyes
    "neck": ("body", (0, 0, 0.56)),
    "back": ("body", tuple(surf(0.40, 180, 0.0))),
    "hand_R": ("flipper.R", _fl(-1, FLIP_L - 0.02)),
    "seat": ("root", (0, 0, 0.04)),
}


def wrap(phi):
    return (phi + 180.0) % 360.0 - 180.0


# ---------------------------------------------------------------------------
# Skinning helpers
# ---------------------------------------------------------------------------
def weigh(b, faces, fn):
    dl = b.bm.verts.layers.deform.verify()
    for v in {v for f in faces for v in f.verts}:
        for g, w in fn(v.co).items():
            if w > 1e-3:
                v[dl][GROUPS.index(g)] = w


def w_torso(co):
    h = ss(0.53, 0.66, co.z)
    return {"head": h, "body": 1 - h}


def w_head(co):
    return {"head": 1.0}


def w_flipper(side):
    bone = "flipper.L" if side > 0 else "flipper.R"
    h = Vector(BONES[3][1]) * Vector((side, 1, 1))
    d = (Vector(BONES[3][2]) - Vector(BONES[3][1])) * Vector((side, 1, 1))

    def fn(co):
        t = (co - h).dot(d) / d.length_squared
        f = ss(-0.16, -0.04, t)  # blend inside the body so the visible flipper and its sleeve move rigidly together
        return {bone: f, "body": 1 - f}
    return fn


def w_foot(side):
    return lambda co: {"foot.L" if side > 0 else "foot.R": 1.0}


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------
def tube(b, rows, mat_fn, n=N, axis=None, phi_open=0.0, phi_range=None, rib=0.0, cap0=False, cap1=False,
         thick=0.0, skip=None, weight=None, off_fn=None):
    """Swept tube. rows = [(center, r_front, r_side)]. Each ring lies perpendicular to the path
    (or to `axis`). phi 0 is the ring's front (-Y) and +90 is its +X side. mat_fn(phi, z) picks
    the material per face, skip(phi, z) leaves holes, and thick > 0 solidifies the surface."""
    bm = b.bm
    before = set(bm.faces)
    if phi_range:
        phis, closed = [phi_range[0] + (phi_range[1] - phi_range[0]) * j / n for j in range(n + 1)], False
    elif phi_open:
        phis, closed = [phi_open + (360 - 2 * phi_open) * j / n for j in range(n + 1)], False
    else:
        phis, closed = [(j + 0.5) * 360.0 / n for j in range(n)], True
    cs = [Vector(r[0]) for r in rows]
    grid = []
    for i, (_, rf, rs) in enumerate(rows):
        c = cs[i]
        if axis is not None:
            t = Vector(axis)
        else:
            t = (cs[min(i + 1, len(cs) - 1)] - cs[max(i - 1, 0)])
        t.normalize()
        ref = Vector((0, -1, 0)) if abs(t.y) < 0.9 else Vector((0, 0, 1))
        u = (ref - t * ref.dot(t)).normalized()
        s = t.cross(u)
        ring = []
        for j, p in enumerate(phis):
            a = math.radians(p)
            k = rib if (rib and j % 2) else 0.0
            if off_fn:
                k += off_fn(wrap(p), c.z)
            ring.append(bm.verts.new(b.xf @ (c + (rf + k) * math.cos(a) * u + (rs + k) * math.sin(a) * s)))
        grid.append(ring)
    cols = len(phis) if closed else len(phis) - 1
    for i in range(len(rows) - 1):
        zc = (cs[i].z + cs[i + 1].z) / 2
        for j in range(cols):
            pc = wrap(phis[j] + (360.0 / n if closed else (phis[1] - phis[0])) / 2)
            if skip and skip(pc, zc):
                continue
            jn = (j + 1) % len(phis)
            f = bm.faces.new((grid[i][j], grid[i][jn], grid[i + 1][jn], grid[i + 1][j]))
            f.material_index = b._mi(mat_fn(pc, zc))
    if closed and cap0:
        cv = bm.verts.new(b.xf @ cs[0])
        for j in range(cols):
            f = bm.faces.new((cv, grid[0][(j + 1) % cols], grid[0][j]))
            f.material_index = b._mi(mat_fn(wrap(phis[j]), cs[0].z))
    if closed and cap1:
        cv = bm.verts.new(b.xf @ cs[-1])
        for j in range(cols):
            f = bm.faces.new((grid[-1][j], grid[-1][(j + 1) % cols], cv))
            f.material_index = b._mi(mat_fn(wrap(phis[j]), cs[-1].z))
    new = [f for f in bm.faces if f not in before]
    if thick:
        bmesh.ops.solidify(bm, geom=new, thickness=thick)
        new = [f for f in bm.faces if f not in before]
    bmesh.ops.recalc_face_normals(bm, faces=new)
    for f in new:
        f.smooth = False
    if weight:
        weigh(b, new, weight)
    return new


def body_rows(z0, z1, off=0.0, step=0.04, flare=0.0):
    """Rings that hug the body between z0 and z1, pushed out by off (number or fn(z))."""
    n = max(1, round((z1 - z0) / step))
    rows = []
    for i in range(n + 1):
        z = z0 + (z1 - z0) * i / n
        o = off(z) if callable(off) else off
        o += flare * ((z1 - z) / (z1 - z0)) ** 2
        r = rx(z)
        rows.append(((0, 0, z), r * DEPTH + o, r + o))
    return rows


def ring_rows(spec, depth=0.9):
    """Hat rings: spec = [(z, r) or (z, r, cx, cy)]."""
    out = []
    for s in spec:
        z, r = s[0], s[1]
        cx, cy = (s[2], s[3]) if len(s) > 2 else (0, 0)
        out.append(((cx, cy, z), r * depth, r))
    return out


def strap(b, pts, w, t, m, weight=None):
    faces = []
    for a, c in zip(pts, pts[1:]):
        a, c = Vector(a), Vector(c)
        d = c - a
        if d.length < 1e-4:
            continue
        mid = (a + c) / 2
        nrm = Vector((mid.x, mid.y, 0))
        nrm = nrm.normalized() if nrm.length > 1e-4 else Vector((0, -1, 0))
        tz = d.normalized()
        xa = tz.cross(nrm).normalized()
        ya = tz.cross(xa)
        e = Matrix((xa, ya, tz)).transposed().to_euler("XYZ")
        faces += b.box(w, t, d.length + t * 0.8, mid.x, mid.y, mid.z, m, bevel=0.004,
                       rot=tuple(math.degrees(v) for v in e), center=True)
    if weight:
        weigh(b, faces, weight)
    return faces


def star_pts(r=0.05, ri=0.022, n=5, rot=90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + 180.0 * i / n)
        rr = r if i % 2 == 0 else ri
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    return pts




def sleeve(b, side, m, cuff=None, upto=0.15, rf=0.148, rs=0.078, cuff_m=None):
    """Sleeve over a flipper from the shoulder to `upto` metres past the flipper centre."""
    d = FLIP_D * Vector((side, 1, 1))
    c = FLIP_C * Vector((side, 1, 1))
    top, end = c - d * 0.21, c + d * upto
    rows = [(top, rf * 0.85, rs * 0.95), (c - d * 0.08, rf, rs), (end, rf * 1.03, rs * 1.05)]
    # open, solidified ends: the flipper fills the opening and no hidden cap cuts through it
    f = tube(b, rows, lambda p, z: m, n=12, cap0=True, thick=0.012, weight=w_flipper(side))
    if cuff_m:
        tube(b, [(end - d * 0.035, rf * 1.06, rs * 1.12), (end + d * 0.015, rf * 1.06, rs * 1.12)],
             lambda p, z: cuff_m, n=12, thick=0.014, weight=w_flipper(side))
    return f


# ---------------------------------------------------------------------------
# Rig, skinned finish, animation
# ---------------------------------------------------------------------------
def make_rig(name, coll):
    data = bpy.data.armatures.new("avatar_rig")
    arm = bpy.data.objects.new(name, data)
    coll.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for n, h, t, p in BONES:
        eb = data.edit_bones.new(n)
        eb.head, eb.tail, eb.roll = h, t, 0.0
        if p:
            eb.parent = data.edit_bones[p]
    bpy.ops.object.mode_set(mode="OBJECT")
    data.display_type = "STICK"
    return arm


def finish_skinned(b, name, category, meta, sockets=None):
    bmesh.ops.remove_doubles(b.bm, verts=b.bm.verts, dist=1e-5)
    me = bpy.data.meshes.new(name + "_mesh")
    b.bm.to_mesh(me)
    b.bm.free()
    for m in b.mats:
        me.materials.append(mat(m))
    coll = kit_collection(KIT)
    obj = bpy.data.objects.new(name + "_mesh", me)
    coll.objects.link(obj)
    for g in GROUPS:
        obj.vertex_groups.new(name=g)
    arm = make_rig(name, coll)
    obj.parent = arm
    obj.modifiers.new("Armature", "ARMATURE").object = arm
    bpy.context.view_layer.update()
    for sname, (bone, loc) in (sockets or {}).items():
        e = bpy.data.objects.new(f"socket_{sname}", None)
        e.empty_display_type, e.empty_display_size = "ARROWS", 0.08
        coll.objects.link(e)
        e.parent, e.parent_type, e.parent_bone = arm, "BONE", bone
        bpy.context.view_layer.update()
        e.matrix_world = Matrix.Translation(loc)
    register(arm, KIT, category, meta)
    return arm, obj


def _wq(pb, axis, deg):
    r = pb.bone.matrix_local.to_quaternion()
    return r.inverted() @ Quaternion(axis, math.radians(deg)) @ r


def _wl(pb, vec):
    return pb.bone.matrix_local.to_quaternion().inverted() @ Vector(vec)


def make_action(arm, name, keys):
    """keys = [(frame, {bone: {"rot": (axis, deg) | [(axis, deg), ...], "loc": world_vec}})]."""
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for frame, poses in keys:
        for pb in arm.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
            p = poses.get(pb.name, {})
            rots = p.get("rot", [])
            rots = [rots] if rots and isinstance(rots[1], (int, float)) else rots
            q = Quaternion()
            for ax, deg in rots:
                q = _wq(pb, ax, deg) @ q
            pb.rotation_quaternion = q
            if "loc" in p:
                pb.location = _wl(pb, p["loc"])
            pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
            pb.keyframe_insert("location", frame=frame, group=pb.name)
    act = ad.action
    act.name = name
    act.use_fake_user = True
    tr = ad.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, int(keys[0][0]), act)
    tr.mute = True  # keep the rest pose in the scene; the glTF exporter still exports each track's action
    ad.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion, pb.location = (1, 0, 0, 0), (0, 0, 0)
    return act


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def build_actions(arm):
    bpy.context.scene.render.fps = 24
    make_action(arm, "idle", [
        (0, {}),
        (24, {"body": {"loc": (0, 0, 0.012)}, "head": {"rot": (X, 3)},
              "flipper.L": {"rot": (Y, -5)}, "flipper.R": {"rot": (Y, 5)}}),
        (48, {}),
    ])
    lift = lambda up: {"loc": (0, -0.02, 0.04) if up else (0, 0, 0), "rot": (X, -18 if up else 0)}
    make_action(arm, "waddle", [
        (0, {"body": {"rot": (Y, -7)}, "foot.L": lift(True), "flipper.L": {"rot": (X, 12)}, "flipper.R": {"rot": (X, -12)}}),
        (6, {"root": {"loc": (0, 0, 0.02)}}),
        (12, {"body": {"rot": (Y, 7)}, "foot.R": lift(True), "flipper.L": {"rot": (X, -12)}, "flipper.R": {"rot": (X, 12)}}),
        (18, {"root": {"loc": (0, 0, 0.02)}}),
        (24, {"body": {"rot": (Y, -7)}, "foot.L": lift(True), "flipper.L": {"rot": (X, 12)}, "flipper.R": {"rot": (X, -12)}}),
    ])
    sit = {"body": {"rot": (X, -10)}, "head": {"rot": (X, 6)},
           "foot.L": {"rot": [(X, -30), (Z, 12)], "loc": (0.03, -0.19, 0.015)},
           "foot.R": {"rot": [(X, -30), (Z, -12)], "loc": (-0.03, -0.19, 0.015)},
           "flipper.L": {"rot": (X, 15)}, "flipper.R": {"rot": (X, 15)}}
    sit_b = {k: dict(v) for k, v in sit.items()}
    sit_b["body"] = {"rot": (X, -10), "loc": (0, 0, 0.008)}
    make_action(arm, "sit", [(0, sit), (24, sit_b), (48, sit)])
    wave = lambda a: {"flipper.R": {"rot": (Y, a)}, "body": {"rot": (Y, 4)}, "head": {"rot": [(Y, 7), (X, 4)]}}
    make_action(arm, "wave", [(0, wave(92)), (8, wave(112)), (16, wave(92)), (24, wave(112)), (32, wave(92))])


# ---------------------------------------------------------------------------
# Base bird
# ---------------------------------------------------------------------------
MASK_W = [(0.05, 26), (0.075, 46), (0.12, 57), (0.2, 63), (0.32, 64), (0.42, 60), (0.5, 52), (0.56, 49),
          (0.62, 55), (0.68, 60), (0.735, 60)]


def _lerp_tab(tab, z):
    for (z0, a0), (z1, a1) in zip(tab, tab[1:]):
        if z <= z1:
            return a0 + (a1 - a0) * max(0.0, (z - z0) / (z1 - z0))
    return tab[-1][1]


def facet_point(z, phi, off=0.0):
    """Point on the actual flat-shaded body surface (bilinear in the quad holding (z, phi))."""
    i = max(k for k in range(len(PROFILE) - 1) if PROFILE[k][0] <= z)
    (z0, r0), (z1, r1) = PROFILE[i], PROFILE[i + 1]
    t = (z - z0) / (z1 - z0)
    step = 360.0 / N
    j = math.floor((phi - step / 2) / step)
    a0 = (j + 0.5) * step
    s = (phi - a0) / step
    v = lambda r, a, zz: Vector((r * math.sin(math.radians(a)), -r * DEPTH * math.cos(math.radians(a)), zz))
    p = (v(r0, a0, z0) * (1 - s) + v(r0, a0 + step, z0) * s) * (1 - t) + (v(r1, a0, z1) * (1 - s) + v(r1, a0 + step, z1) * s) * t
    n = Vector((p.x, p.y / DEPTH, 0))
    return p + (n.normalized() * off if n.length > 1e-6 else Vector())


def in_mask(phi, z):
    a = abs(phi)
    if 0.05 <= z <= 0.735:
        return a < _lerp_tab(MASK_W, z)
    if 0.735 < z < 0.829:
        e = 30 * math.sqrt(max(0.0, 1 - ((z - 0.745) / 0.088) ** 2))
        return 31 - e < a < 31 + e
    return False


def face_in_mask(phi, z):
    """True only when all four corners of the body quad centred at (phi, z) lie inside the mask,
    so the cream underlay never reaches past the smooth overlay outline."""
    zs = [p[0] for p in PROFILE]
    i = max(k for k in range(len(zs) - 1) if zs[k] <= z)
    h = 180.0 / N
    return all(in_mask(phi + dp, zz) for dp in (-h, h) for zz in (zs[i] + 1e-4, zs[i + 1] - 1e-4))


def strip(b, zs, span, m, cols, off=0.0065):
    """Surface patch hugging the faceted body: rows at zs, each spanning span(z) = (phi0, phi1)."""
    grid = []
    for z in zs:
        a0, a1 = span(z)
        grid.append([b.bm.verts.new(facet_point(z, a0 + (a1 - a0) * k / cols, off)) for k in range(cols + 1)])
    faces = []
    for i in range(len(zs) - 1):
        for k in range(cols):
            f = b.bm.faces.new((grid[i][k], grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]))
            f.material_index = b._mi(m)
            f.smooth = False
            faces.append(f)
    weigh(b, faces, w_torso)
    return faces


def face_mask(b):
    """Cream face-and-belly patch: smooth outline with two brow lobes and a centre dip, as in the concept."""
    zs = [0.05 + (0.735 - 0.05) * k / 24 for k in range(25)]
    strip(b, zs, lambda z: (-_lerp_tab(MASK_W, z), _lerp_tab(MASK_W, z)), "belly", 14)
    lz = [0.735, 0.755, 0.775, 0.793, 0.808, 0.82, 0.829]
    e = lambda z: 30 * math.sqrt(max(0.0, 1 - ((z - 0.745) / 0.088) ** 2))
    for sx in (-1, 1):
        def span(z, sx=sx):
            a0, a1 = max(1.0, 31 - e(z)), min(60.0, 31 + e(z))
            return (a0, a1) if sx > 0 else (-a1, -a0)
        strip(b, lz, span, "belly", 6)


PALETTE.setdefault("blush", ("#F59AB0", 0.9, 0))
PALETTE.setdefault("mouth", ("#7A2E35", 0.8, 0))
# face parts tagged per vertex (int attribute "avpart") so the morph targets can find them
EYE_L, EYE_R, HI_L, HI_R, BEAK_LO, MOUTH, BLUSH_L, BLUSH_R, BEAK_UP = range(1, 10)
FACE = {}  # part -> centre (and eye lateral axis)
MORPHS = ["eyes_closed", "eyes_happy", "eyes_wide", "beak_open", "blush"]


def tagp(b, faces, part):
    lay = b.bm.verts.layers.int.get("avpart")
    for v in {v for f in faces for v in f.verts}:
        v[lay] = part


def bird(b, body=BODY):
    """Build the bird into Builder b (skin weights and face-part tags included)."""
    b.bm.verts.layers.int.new("avpart")
    rows = [((0, 0, z), r * DEPTH, r) for z, r in PROFILE]
    tube(b, rows, lambda p, z: "belly" if face_in_mask(p, z) else body, axis=Z, weight=w_torso)
    face_mask(b)  # smooth-edged overlay; the faces under it are cream too, so nothing shows through
    # eyes with a small highlight
    for sx, ep, hp in ((1, EYE_L, HI_L), (-1, EYE_R, HI_R)):
        p = facet_point(EYE_Z, sx * EYE_PHI, -0.008)
        f = b.sphere(0.04, p.x, p.y, p.z, "eye", u=10, v=7, scale=(1, 0.5, 1.25), rot=(0, 0, sx * EYE_PHI))
        tagp(b, f, ep)
        h = b.sphere(0.011, p.x + sx * 0.006 - 0.006, p.y - 0.019, p.z + 0.018, "white", u=6, v=4)
        tagp(b, h, hp)
        a = math.radians(sx * EYE_PHI)
        FACE[ep] = (Vector(p), Vector((math.cos(a), math.sin(a), 0)))
        weigh(b, f + h, w_head)
    # beak: chunky upper wedge, a lower mandible that hinges open, and a mouth hidden behind them
    p = facet_point(0.632, 0, -0.012)
    with b.at(tuple(p), scale=(1.3, 1.0, 0.8)):
        up = b.cyl(0.062, 0.1, mat="beak", segs=6, r2=0.012, rot=(100, 0, 0))
    with b.at(tuple(p + Vector((0, 0.004, -0.014))), scale=(1.12, 1.0, 0.62)):
        lo = b.cyl(0.05, 0.082, mat="beak", segs=6, r2=0.01, rot=(110, 0, 0))
    mo = b.sphere(0.032, p.x, p.y - 0.012, p.z - 0.014, "mouth", u=8, v=5, scale=(1.25, 0.7, 0.75))
    tagp(b, up, BEAK_UP); tagp(b, lo, BEAK_LO); tagp(b, mo, MOUTH)
    FACE[BEAK_LO] = (Vector(p) + Vector((0, 0.004, -0.012)), None)
    weigh(b, up + lo + mo, w_head)
    # blush patches: full size here; the base shape collapses them so the 'blush' morph scales them in
    for sx, bp in ((1, BLUSH_L), (-1, BLUSH_R)):
        c = facet_point(0.648, sx * 45, 0.0095)
        f = b.cyl(0.042, 0.004, c.x, c.y, c.z, "blush", segs=10, rot=(90, 0, sx * 45), center=True)
        tagp(b, f, bp)
        FACE[bp] = (c, None)
        weigh(b, f, w_head)
    # flippers
    for sx in (-1, 1):
        c = FLIP_C * Vector((sx, 1, 1))
        f = b.blob(0.056, 0.13, FLIP_L, c.x, c.y, c.z, body, subdiv=2, rot=(0, -sx * FLIP_ANG, 0), jitter=0.003)
        weigh(b, f, w_flipper(sx))
    # feet: rounded faceted pads, splayed slightly
    for sx in (-1, 1):
        f = b.blob(0.088, 0.118, 0.04, sx * 0.13, -0.15, 0.04, "beak", subdiv=2, rot=(0, 0, -sx * 12))
        weigh(b, f, w_foot(sx))


def add_face_morphs(obj):
    """Morph targets (glTF): eyes_closed, eyes_happy (^ ^), eyes_wide, beak_open, blush."""
    me = obj.data
    part = [a.value for a in me.attributes["avpart"].data]
    full = [v.co.copy() for v in me.vertices]
    ids = lambda k: [i for i, a in enumerate(part) if a == k]
    basis = obj.shape_key_add(name="Basis", from_mix=False)
    for bp in (BLUSH_L, BLUSH_R):          # rest shape: blush collapsed to a point inside the cheek
        c = FACE[bp][0] - (FACE[bp][0] - Vector((0, 0, FACE[bp][0].z))).normalized() * 0.004
        for i in ids(bp):
            me.vertices[i].co = c
            basis.data[i].co = c
    up = Vector((0, 0, 1))

    def eyes(name, fn):
        k = obj.shape_key_add(name=name, from_mix=False)
        for ep, hp in ((EYE_L, HI_L), (EYE_R, HI_R)):
            c, lat = FACE[ep]
            for i in ids(ep):
                d = full[i] - c
                k.data[i].co = c + fn(d, lat)
            for i in ids(hp):
                d = full[i] - c
                k.data[i].co = c + (d * 1.28 if name == "eyes_wide" else Vector((0, 0.01, 0)))  # hide inside the eye
        return k

    def squash(d, lat, keep, lift):
        dz = d.dot(up)
        return d - up * dz + up * (dz * keep + lift(d.dot(lat)))
    eyes("eyes_closed", lambda d, lat: squash(d, lat, 0.17, lambda x: -0.008))
    eyes("eyes_happy", lambda d, lat: squash(d, lat, 0.3, lambda x: 0.032 * (1 - min(1.0, (x / 0.042) ** 2)) - 0.014))
    eyes("eyes_wide", lambda d, lat: d * 1.28)
    k = obj.shape_key_add(name="beak_open", from_mix=False)
    hinge = FACE[BEAK_LO][0]
    r_lo, r_up = Matrix.Rotation(math.radians(36), 3, "X"), Matrix.Rotation(math.radians(-9), 3, "X")
    for i in ids(BEAK_LO):
        k.data[i].co = hinge + r_lo @ (full[i] - hinge)
    for i in ids(BEAK_UP):
        k.data[i].co = hinge + r_up @ (full[i] - hinge)
    k = obj.shape_key_add(name="blush", from_mix=False)
    for bp in (BLUSH_L, BLUSH_R):
        for i in ids(bp):
            k.data[i].co = full[i]
    me.attributes.remove(me.attributes["avpart"])
    return [kb.name for kb in me.shape_keys.key_blocks[1:]]


def build_base():
    b = Builder("avatar_base", seed=1)
    bird(b)
    meta = {"slot": "base", "color_variants": BODY_COLORS, "bones": [x[0] for x in BONES], "morphs": MORPHS,
            "animations": "clips live in the anim_* kits (anim_locomotion, anim_emotes, anim_social)",
            "sockets_world": {k: list(v[1]) for k, v in SOCKETS.items()}, "height_m": 0.9}
    arm, obj = finish_skinned(b, "avatar_base", "character", meta, SOCKETS)
    add_face_morphs(obj)
    return arm


# ---------------------------------------------------------------------------
# Hats (rigid, origin at socket_head = brow level z 0.72)
# ---------------------------------------------------------------------------
HEAD_Z = SOCKETS["head"][1][2]


def hat_builder(name):
    b = Builder(name, seed=len(name))
    return b


def hat_finish(b, meta):
    """Shift so the socket point is the origin, then finish."""
    bm = b.bm
    bmesh.ops.translate(bm, vec=(0, 0, -HEAD_Z), verts=bm.verts)
    meta = {"slot": "head", "socket": "socket_head", **meta}
    return b.finish(KIT, "hat", meta)


def hr(z, off):
    """Head radius at z plus off, for fitting hats."""
    return rx(min(z, 0.899)) + off


def red_beanie():
    b = hat_builder("red_beanie")
    P = tint("cloth_primary", "#D9473B")
    tube(b, ring_rows([(z, hr(z, 0.045)) for z in (0.745, 0.79, 0.835)], DEPTH + 0.04), lambda p, z: P, n=32,
         rib=0.01, thick=0.02, axis=Z)
    tube(b, ring_rows([(0.82, hr(0.82, 0.05)), (0.87, 0.262), (0.92, 0.238), (0.965, 0.192), (1.0, 0.13),
                       (1.022, 0.06), (1.03, 0.0)], DEPTH + 0.04), lambda p, z: P, n=24, rib=0.007, axis=Z)
    b.blob(0.085, 0.085, 0.075, 0, 0.0, 1.085, P, subdiv=2, jitter=0.01)
    return hat_finish(b, {"color_variants": {"red": "#D9473B", "teal": "#2FA3A3", "mustard": "#E3A92B"}})


def frog_hood():
    b = hat_builder("frog_hood")
    G, C = tint("cloth_primary", "#5DAA3C"), tint("cloth_secondary", "#F3E6C4")
    oz, oa, ob = 0.685, 60.0, 0.13            # face opening: centre z, half-angle, half-height
    e = lambda p, z: (p / oa) ** 2 + ((z - oz) / ob) ** 2
    rows = body_rows(0.42, 0.86, off=lambda z: 0.042 + 0.035 * ss(0.58, 0.42, z), step=0.03)
    rows += ring_rows([(0.885, 0.19), (0.91, 0.14), (0.928, 0.07), (0.933, 0.0)], DEPTH)
    faces = tube(b, rows, lambda p, z: G, n=32, skip=lambda p, z: e(p, z) < 1.0, axis=Z)
    # snap the opening's boundary onto the ellipse so the face hole is smooth, then add thickness
    off = lambda z: 0.042 + 0.035 * ss(0.58, 0.42, z)
    for v in {v for f in faces for v in f.verts if v.is_boundary and 0.5 < v.co.z < 0.86}:
        p = math.degrees(math.atan2(v.co.x, -v.co.y / DEPTH))
        k = 1 / math.sqrt(max(e(p, v.co.z), 1e-6))
        np_, nz = p * k, oz + (v.co.z - oz) * k
        v.co = surf(nz, np_, off(nz))
    bmesh.ops.solidify(b.bm, geom=faces, thickness=0.022)
    bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces[:])
    # cream lining band hugging the opening
    ring = []
    for k in range(21):
        a = 2 * math.pi * k / 20
        ph, zz = oa * 1.08 * math.cos(a), oz + ob * 1.08 * math.sin(a)
        ring.append(surf(zz, ph, off(zz) + 0.026))
    strap(b, ring, 0.05, 0.03, C)
    for sx in (-1, 1):
        x, y, z = sx * 0.13, -0.06, 0.915
        b.blob(0.088, 0.082, 0.072, x, y, z, G, subdiv=1)
        b.sphere(0.066, x, y - 0.035, z + 0.045, "white", u=12, v=8)
        b.sphere(0.033, x, y - 0.09, z + 0.05, "eye", u=10, v=6, scale=(1, 0.55, 1.1))
        b.sphere(0.009, x - 0.009, y - 0.106, z + 0.066, "white", u=6, v=4)
        n = surf(0.84, sx * 12, 0.05)
        b.sphere(0.008, n.x, n.y, n.z, "leaf_dark", u=6, v=4)
    return hat_finish(b, {"excludes": ["head"], "covers": "head",
                          "color_variants": {"green": "#5DAA3C", "pink": "#F2A0B5", "yellow": "#F2C230"}})


def explorer_hat():
    b = hat_builder("explorer_hat")
    T, B = tint("cloth_primary", "#D4A46A"), tint("cloth_secondary", "#7A4E2C")
    tube(b, ring_rows([(0.765, 0.292), (0.83, 0.284), (0.9, 0.266), (0.945, 0.235), (0.97, 0.18),
                       (0.975, 0.09), (0.965, 0.0)], 0.9), lambda p, z: T, n=16, axis=Z)
    tube(b, ring_rows([(0.775, 0.298), (0.835, 0.29)], 0.9), lambda p, z: B, n=16, thick=0.012, axis=Z)
    tube(b, ring_rows([(0.78, 0.285), (0.775, 0.38), (0.758, 0.46), (0.738, 0.49)], 0.92), lambda p, z: T,
         n=16, thick=0.024, axis=Z)
    return hat_finish(b, {"color_variants": {"tan": "#D4A46A", "olive": "#6E8A3A", "brown": "#9C6A3C"}})


def wizard_hat():
    b = hat_builder("wizard_hat")
    Pu = tint("cloth_primary", "#7B4FC4")
    tube(b, ring_rows([(0.79, 0.28), (0.78, 0.37), (0.758, 0.44), (0.742, 0.455)], 0.92), lambda p, z: Pu,
         n=16, thick=0.024, axis=Z)
    path = [(0, 0, 0.77, 0.29), (0, 0.0, 0.87, 0.24), (0.0, 0.01, 0.97, 0.18), (0.015, 0.02, 1.06, 0.125),
            (0.055, 0.03, 1.135, 0.083), (0.12, 0.035, 1.175, 0.05), (0.19, 0.035, 1.17, 0.025), (0.23, 0.035, 1.14, 0.004)]
    tube(b, [((x, y, z), r * 0.92, r) for x, y, z, r in path], lambda p, z: Pu, n=12, cap0=True, cap1=True)
    with b.at((0.0, -0.215, 0.89), rot=(-26, 0, 0)):
        b.prism(star_pts(0.062, 0.028), 0.025, mat="yellow", bevel=0.004)
    return hat_finish(b, {"color_variants": {"purple": "#7B4FC4", "navy": "#2E3F6E", "teal": "#2FA3A3"}})


def bucket_hat():
    b = hat_builder("bucket_hat")
    Bl = tint("cloth_primary", "#3D7BD9")
    tube(b, ring_rows([(0.77, 0.296), (0.84, 0.29), (0.9, 0.272), (0.94, 0.235), (0.962, 0.165), (0.97, 0.07),
                       (0.97, 0.0)], 0.9), lambda p, z: Bl, n=14, axis=Z)
    tube(b, ring_rows([(0.785, 0.29), (0.75, 0.35), (0.712, 0.41)], 0.92), lambda p, z: Bl, n=14, thick=0.022, axis=Z)
    tube(b, ring_rows([(0.785, 0.302), (0.81, 0.299)], 0.9), lambda p, z: tint("cloth_secondary", "#2F64B8"),
         n=14, thick=0.01, axis=Z)
    return hat_finish(b, {"color_variants": {"blue": "#3D7BD9", "coral": "#E86D58", "sage": "#8DAA5B"}})


def headphones():
    b = hat_builder("headphones")
    R, K = tint("cloth_primary", "#D9473B"), "charcoal"
    cz, cr = 0.68, hr(0.64, 0.04)
    pts = [Vector((cr * math.cos(math.radians(180 * k / 12)), 0.0, cz + 0.29 * math.sin(math.radians(180 * k / 12))))
           for k in range(13)]
    tube(b, [(p, 0.042, 0.02) for p in pts], lambda p, z: R, n=8, cap0=True, cap1=True)
    tube(b, [(Vector((p.x * 0.93, 0, cz + (p.z - cz) * 0.92)), 0.028, 0.012) for p in pts[2:-2]],
         lambda p, z: K, n=6, cap0=True, cap1=True)
    for sx in (-1, 1):
        x = sx * cr
        b.box(0.04, 0.05, 0.1, x, 0, cz - 0.02, R, bevel=0.01)
        b.cyl(0.1, 0.075, x - sx * 0.03, 0, 0.62, K, segs=8, rot=(0, sx * 90, 0), bevel=0.012)
        b.cyl(0.072, 0.026, x + sx * 0.045, 0, 0.62, R, segs=8, rot=(0, sx * 90, 0), bevel=0.008)
        b.cyl(0.088, 0.02, x - sx * 0.045, 0, 0.62, "black", segs=8, rot=(0, sx * 90, 0))
    return hat_finish(b, {"color_variants": {"red": "#D9473B", "teal": "#2FA3A3", "white": "#E9EEF2"}})


# ---------------------------------------------------------------------------
# Wardrobe (skinned torso shells)
# ---------------------------------------------------------------------------
def outfit(name, color_variants, build_fn):
    b = Builder(name, seed=len(name) * 3)
    build_fn(b)
    meta = {"slot": "torso", "color_variants": color_variants, "rig": "avatar_rig (rebind by bone name)"}
    return finish_skinned(b, name, "wardrobe", meta)[0]


NECK_AXIS = (0, -0.14, 1)  # collar rings dip ~4 cm at the front so the beak clears them when the head nods


def hem_band(b, z0, z1, off, m, n=N, rib=0.0, phi_open=0.0, phi_range=None, axis=Z):
    return tube(b, body_rows(z0, z1, off, step=(z1 - z0)), lambda p, z: m, n=n, rib=rib, thick=0.02,
                phi_open=phi_open, phi_range=phi_range, axis=axis, weight=w_torso)


def hoodie(b):
    P, S = tint("cloth_primary", "#E8655A"), tint("cloth_secondary", "#F7F1E6")
    tube(b, body_rows(0.15, 0.55, 0.03, flare=0.012), lambda p, z: P, thick=0.02, axis=Z, weight=w_torso)
    hem_band(b, 0.12, 0.165, 0.042, P, rib=0.006)
    hem_band(b, 0.53, 0.585, 0.05, P, rib=0.005)
    for sx in (-1, 1):
        sleeve(b, sx, P, cuff_m=P, upto=0.08)
    # hood resting on the back
    f = b.blob(0.21, 0.1, 0.12, 0, 0.27, 0.56, P, subdiv=2, rot=(-20, 0, 0), jitter=0.004)
    f += b.blob(0.15, 0.06, 0.08, 0, 0.3, 0.575, S, subdiv=1, rot=(-20, 0, 0))
    weigh(b, f, w_torso)
    # kangaroo pocket
    p = surf(0.27, 0, 0.042)
    f = b.box(0.3, 0.04, 0.13, p.x, p.y, p.z, P, bevel=0.018, center=True, rot=(-6, 0, 0))
    f += b.box(0.27, 0.03, 0.02, p.x, p.y - 0.012, p.z + 0.052, tint("cloth_primary", "#E8655A"), bevel=0.006, center=True)
    weigh(b, f, w_torso)
    # drawstrings
    for sx in (-1, 1):
        q = surf(0.53, sx * 9, 0.06)
        f = b.cyl(0.009, 0.13, q.x, q.y, q.z - 0.13, S, segs=6)
        f += b.cyl(0.016, 0.03, q.x, q.y, q.z - 0.155, S, segs=6, bevel=0.004)
        weigh(b, f, w_torso)


def varsity_jacket(b):
    P, S = tint("cloth_primary", "#2E3F6E"), tint("cloth_secondary", "#F3E6C4")
    trim = lambda p, z: S if abs(p) < 36 or z < 0.175 else P
    tube(b, body_rows(0.15, 0.55, 0.03, flare=0.01), trim, phi_open=27, n=26, thick=0.02, axis=Z, weight=w_torso)
    hem_band(b, 0.12, 0.17, 0.042, P, rib=0.006, phi_open=27, n=26)
    hem_band(b, 0.135, 0.15, 0.046, S, phi_open=27, n=26)
    hem_band(b, 0.53, 0.585, 0.05, P, rib=0.005, phi_open=24, n=26)
    hem_band(b, 0.55, 0.565, 0.054, S, phi_open=24, n=26)
    for sx in (-1, 1):
        sleeve(b, sx, S, cuff_m=P, upto=0.09)
        d, c = FLIP_D * Vector((sx, 1, 1)), FLIP_C * Vector((sx, 1, 1))
        tube(b, [(c + d * 0.03, 0.151, 0.081), (c + d * 0.05, 0.151, 0.081)], lambda p, z: P, n=12, cap0=True,
             cap1=True, weight=w_flipper(sx))
    for z in (0.46, 0.36, 0.26):
        p = surf(z, 33, 0.055)
        f = b.cyl(0.016, 0.012, p.x, p.y, p.z, "white", segs=8, rot=(90, 0, 33 + 180))
        weigh(b, f, w_torso)
    # chest letter patch (graphic insert)
    p = surf(0.42, -48, 0.052)
    f = b.box(0.07, 0.015, 0.08, p.x, p.y, p.z, S, bevel=0.006, center=True, rot=(0, 0, -48))
    weigh(b, f, w_torso)


def raincoat(b):
    P, S = tint("cloth_primary", "#EDB33F"), tint("cloth_secondary", "#2FA3A3")
    tube(b, body_rows(0.13, 0.55, 0.032, flare=0.03), lambda p, z: P, thick=0.022, axis=Z, weight=w_torso)
    # big turned-out collar
    tube(b, [((0, 0, 0.52), rx(0.52) * DEPTH + 0.05, rx(0.52) + 0.05), ((0, 0, 0.6), rx(0.6) * DEPTH + 0.09, rx(0.6) + 0.09)],
         lambda p, z: P, phi_open=10, n=26, thick=0.024, axis=Z, weight=w_torso)
    # front placket and buttons
    for z in (0.47, 0.38, 0.29, 0.2):
        p = surf(z, 0, 0.055)
        f = b.cyl(0.026, 0.02, p.x, p.y, p.z, S, segs=8, rot=(90, 0, 0), bevel=0.006)
        weigh(b, f, w_torso)
    tube(b, body_rows(0.13, 0.53, 0.04), lambda p, z: P, phi_range=(-6, 6), n=2, thick=0.012, axis=Z, weight=w_torso)
    # pockets with flaps
    for sx in (-1, 1):
        p = surf(0.22, sx * 42, 0.05)
        f = b.box(0.13, 0.03, 0.1, p.x, p.y, p.z, P, bevel=0.01, center=True, rot=(0, 0, sx * 42))
        f += b.box(0.145, 0.04, 0.035, p.x, p.y - 0.008, p.z + 0.055, P, bevel=0.01, center=True, rot=(0, 0, sx * 42))
        weigh(b, f, w_torso)
        sleeve(b, sx, P, cuff_m=P, upto=0.1, rf=0.152, rs=0.082)


def overalls(b):
    P, S = tint("cloth_primary", "#3BB8B5"), tint("cloth_secondary", "#F3E6C4")
    tube(b, body_rows(0.12, 0.33, 0.03, flare=0.012), lambda p, z: P, thick=0.022, axis=Z, weight=w_torso)
    hem_band(b, 0.31, 0.345, 0.04, P)
    # bib
    tube(b, body_rows(0.32, 0.51, 0.036), lambda p, z: P, phi_range=(-40, 40), n=8, thick=0.02, axis=Z, weight=w_torso)
    p = surf(0.42, 0, 0.06)
    f = b.box(0.14, 0.025, 0.09, p.x, p.y, p.z, P, bevel=0.01, center=True)
    f += b.box(0.15, 0.03, 0.02, p.x, p.y - 0.004, p.z + 0.045, P, bevel=0.006, center=True)
    weigh(b, f, w_torso)
    # straps: up the front, around the neck line, crossing in an X on the back
    for sx in (-1, 1):
        pts = [surf(0.5, sx * 30, 0.045), surf(0.565, sx * 55, 0.045), surf(0.585, sx * 95, 0.05),
               surf(0.56, sx * 135, 0.05), surf(0.48, sx * 165, 0.05), surf(0.4, -sx * 170, 0.05),
               surf(0.33, -sx * 150, 0.045)]
        strap(b, pts, 0.075, 0.016, P, weight=w_torso)
        q = surf(0.5, sx * 30, 0.065)
        f = b.cyl(0.022, 0.016, q.x, q.y, q.z, S, segs=8, rot=(90, 0, sx * 30 + 180), bevel=0.005)
        weigh(b, f, w_torso)


def striped_tee(b):
    P, S = tint("cloth_primary", "#E8655A"), tint("cloth_secondary", "#F7EEDD")
    band = lambda p, z: P if int((z - 0.18) / 0.06) % 2 == 0 else S
    tube(b, body_rows(0.18, 0.54, 0.024, step=0.02), band, thick=0.018, axis=Z, weight=w_torso)
    hem_band(b, 0.52, 0.565, 0.035, P, rib=0.004)
    for sx in (-1, 1):
        d, c = FLIP_D * Vector((sx, 1, 1)), FLIP_C * Vector((sx, 1, 1))
        rows = [(c - d * (0.2 - 0.05 * k), 0.146 * (0.88 + 0.03 * k), 0.078) for k in range(5)]
        tube(b, rows, lambda p, z: P if int((z - 0.18) / 0.06) % 2 == 0 else S, n=12, cap0=True, cap1=True,
             weight=w_flipper(sx))


def puffer_vest(b):
    P, S = tint("cloth_primary", "#6E8A3A"), tint("cloth_secondary", "#4F6629")
    band_h = 0.085
    off = lambda z: 0.036 + 0.024 * math.sin(math.pi * (((z - 0.18) / band_h) % 1.0))
    tube(b, body_rows(0.18, 0.565, off, step=band_h / 4), lambda p, z: P, thick=0.02, axis=Z, weight=w_torso)
    hem_band(b, 0.5, 0.605, 0.062, P, axis=NECK_AXIS)
    # zipper seam and pull
    tube(b, body_rows(0.18, 0.59, lambda z: off(z) + 0.004 if z < 0.545 else 0.06), lambda p, z: S,
         phi_range=(-2.5, 2.5), n=1, thick=0.01, axis=Z, weight=w_torso)
    p = surf(0.5, 0, 0.09)
    f = b.box(0.025, 0.012, 0.05, p.x, p.y, p.z, "steel", bevel=0.004, center=True)
    weigh(b, f, w_torso)


def cafe_apron(b):
    P, S = tint("cloth_primary", "#F7E7CC"), tint("cloth_secondary", "#3BB8B5")
    tube(b, body_rows(0.13, 0.51, 0.034, flare=0.01), lambda p, z: P, phi_range=(-58, 58), n=12, thick=0.016,
         axis=Z, weight=w_torso)
    p = surf(0.25, 0, 0.055)
    f = b.box(0.22, 0.025, 0.12, p.x, p.y, p.z, S, bevel=0.012, center=True, rot=(-5, 0, 0))
    f += b.box(0.012, 0.03, 0.1, p.x, p.y - 0.004, p.z, P, bevel=0, center=True)
    weigh(b, f, w_torso)
    # waist tie all the way round, neck strap and bow on the back
    hem_band(b, 0.35, 0.385, 0.05, S, phi_range=(55, 305), n=20)
    hem_band(b, 0.54, 0.57, 0.04, S)
    for sx in (-1, 1):
        strap(b, [surf(0.5, sx * 52, 0.045), surf(0.55, sx * 40, 0.045)], 0.035, 0.012, S, weight=w_torso)
    c = surf(0.37, 180, 0.065)
    f = b.blob(0.03, 0.025, 0.028, c.x, c.y, c.z, S, subdiv=1)
    for sx in (-1, 1):
        f += b.torus(0.045, 0.016, c.x + sx * 0.05, c.y + 0.005, c.z + 0.008, S, segs=10, ring=5, rot=(90, sx * 15, 0))
        f += b.box(0.035, 0.015, 0.12, c.x + sx * 0.03, c.y + 0.01, c.z - 0.12, S, bevel=0.005, rot=(0, sx * 18, 0))
    weigh(b, f, w_torso)


def wizard_robe(b):
    P, S = tint("cloth_primary", "#9C6FD0"), tint("cloth_secondary", "#7B54B8")
    tube(b, body_rows(0.15, 0.56, 0.03, flare=0.04), lambda p, z: P, phi_open=24, n=26, thick=0.022, axis=Z,
         weight=w_torso)
    # mantle/collar over the shoulders
    tube(b, [((0, 0, 0.47), rx(0.47) * DEPTH + 0.075, rx(0.47) + 0.075), ((0, 0, 0.6), rx(0.6) * DEPTH + 0.045, rx(0.6) + 0.045)],
         lambda p, z: S, phi_open=16, n=26, thick=0.022, axis=Z, weight=w_torso)
    # hood draped on the back
    hb = surf(0.5, 180, 0.0)
    f = b.blob(0.235, 0.1, 0.15, 0, hb.y + 0.05, 0.46, P, subdiv=2, rot=(-12, 0, 0))
    f += b.blob(0.2, 0.05, 0.11, 0, hb.y + 0.105, 0.475, S, subdiv=2, rot=(-12, 0, 0))
    weigh(b, f, w_torso)
    for sx in (-1, 1):
        d, c = FLIP_D * Vector((sx, 1, 1)), FLIP_C * Vector((sx, 1, 1))
        rows = [(c - d * 0.21, 0.125, 0.07), (c - d * 0.05, 0.15, 0.085), (c + d * 0.1, 0.165, 0.094), (c + d * 0.14, 0.168, 0.096)]
        tube(b, rows, lambda p, z: P, n=12, cap0=True, weight=w_flipper(sx), thick=0.012)
    p = surf(0.55, 0, 0.085)
    with b.at(tuple(p), rot=(-8, 0, 0)):
        f = b.prism(star_pts(0.05, 0.022), 0.025, mat="gold", bevel=0.004)
    weigh(b, f, w_torso)


# ---------------------------------------------------------------------------
# Accessories (rigid, origin at their socket)
# ---------------------------------------------------------------------------
def acc(name, slot, build_fn, meta=None):
    b = Builder(name, seed=len(name) * 5)
    sock = Vector(SOCKETS[slot][1])
    with b.at(tuple(-sock)):
        build_fn(b)
    meta = {"slot": slot.replace("hand_R", "hand"), "socket": f"socket_{slot}", **(meta or {})}
    return b.finish(KIT, "accessory", meta)


def backpack(b):
    P, S = tint("cloth_primary", "#8C8A4E"), tint("cloth_secondary", "#6B5232")
    y0 = 0.285
    b.box(0.34, 0.15, 0.34, 0, y0 + 0.085, 0.25, P, bevel=0.045)
    b.box(0.35, 0.16, 0.07, 0, y0 + 0.085, 0.555, P, bevel=0.03)
    b.box(0.31, 0.04, 0.16, 0, y0 + 0.165, 0.43, P, bevel=0.02)                    # top flap
    b.box(0.25, 0.06, 0.13, 0, y0 + 0.175, 0.28, P, bevel=0.025)                   # front pocket
    for sx in (-1, 1):
        b.box(0.035, 0.02, 0.12, sx * 0.09, y0 + 0.19, 0.38, S, bevel=0.004)
        b.box(0.04, 0.025, 0.03, sx * 0.09, y0 + 0.195, 0.4, "gold", bevel=0.004)
        pts = [Vector((sx * 0.11, y0 + 0.02, 0.58)), surf(0.6, sx * 130, 0.035), surf(0.575, sx * 75, 0.04),
               surf(0.5, sx * 52, 0.04), surf(0.36, sx * 62, 0.04), surf(0.28, sx * 105, 0.035), surf(0.27, sx * 140, 0.035), Vector((sx * 0.13, y0 + 0.04, 0.27))]
        strap(b, pts, 0.05, 0.016, S)
    b.torus(0.03, 0.009, 0, y0 + 0.08, 0.64, S, segs=8, ring=4, rot=(90, 0, 0))


def rolltop_backpack(b):
    P, S = tint("cloth_primary", "#E86D58"), tint("cloth_secondary", "#7A4E2C")
    y0 = 0.285
    b.box(0.3, 0.16, 0.36, 0, y0 + 0.09, 0.22, P, bevel=0.04)
    b.cyl(0.055, 0.32, 0.16, y0 + 0.09, 0.62, P, segs=10, rot=(0, -90, 0), bevel=0.01)
    b.cyl(0.045, 0.325, 0.162, y0 + 0.09, 0.62, tint("cloth_primary", "#E86D58"), segs=10, rot=(0, -90, 0))
    for sx in (-1, 1):
        b.box(0.035, 0.02, 0.36, sx * 0.08, y0 + 0.175, 0.3, S, bevel=0.004)
        b.box(0.05, 0.025, 0.04, sx * 0.08, y0 + 0.18, 0.4, "gold", bevel=0.005)
        b.box(0.05, 0.13, 0.16, sx * 0.17, y0 + 0.09, 0.22, P, bevel=0.02)
        pts = [Vector((sx * 0.1, y0 + 0.02, 0.57)), surf(0.6, sx * 130, 0.035), surf(0.575, sx * 75, 0.04),
               surf(0.5, sx * 52, 0.04), surf(0.36, sx * 62, 0.04), surf(0.27, sx * 105, 0.035), surf(0.26, sx * 140, 0.035), Vector((sx * 0.12, y0 + 0.04, 0.25))]
        strap(b, pts, 0.05, 0.016, S)


def crossbody_bag(b):
    P, S = tint("cloth_primary", "#9C6A3C"), tint("cloth_secondary", "#6B4628")
    pts = [surf(0.43 + 0.15 * math.sin(math.radians(a)), a, 0.04 + 0.01 * (math.sin(math.radians(a)) > 0.7))
           for a in range(-180, 181, 15)]
    strap(b, pts, 0.04, 0.014, S)
    c = surf(0.27, -78, 0.08)
    with b.at(tuple(c), rotz=-78):
        b.box(0.2, 0.08, 0.15, 0, 0, -0.07, P, bevel=0.025)
        b.box(0.205, 0.09, 0.075, 0, -0.008, 0.01, S, bevel=0.02, rot=(8, 0, 0))
        b.cyl(0.015, 0.012, 0, -0.054, 0.0, "gold", segs=8, rot=(90, 0, 0))


def glasses(b):
    F = tint("cloth_primary", "#2B2B30")
    for sx in (-1, 1):
        p = facet_point(EYE_Z, sx * EYE_PHI, 0.052)
        b.torus(0.054, 0.009, p.x, p.y, p.z, F, segs=14, ring=5, rot=(90 - 8, 0, sx * EYE_PHI))
        b.cyl(0.05, 0.004, p.x, p.y, p.z, "glass", segs=14, rot=(90 - 8, 0, sx * EYE_PHI), center=True)
        strap(b, [facet_point(EYE_Z + 0.008, sx * 39, 0.038), facet_point(EYE_Z + 0.008, sx * 62, 0.03),
                  facet_point(EYE_Z, sx * 98, 0.026)], 0.016, 0.01, F)
    a, c = facet_point(EYE_Z + 0.008, -9, 0.045), facet_point(EYE_Z + 0.008, 9, 0.045)
    strap(b, [a, Vector((0, a.y - 0.006, EYE_Z + 0.014)), c], 0.014, 0.01, F)


def scarf(b):
    P, S = tint("cloth_primary", "#D9473B"), tint("cloth_secondary", "#B23A33")
    off = lambda z: 0.056 + 0.018 * math.sin(math.pi * (z - 0.5) / 0.1)
    tube(b, body_rows(0.5, 0.6, off, step=0.025), lambda p, z: P, n=26, thick=0.02, axis=NECK_AXIS)
    # knot and two hanging tails on the front-left
    k = surf(0.53, -22, 0.08)
    b.blob(0.05, 0.035, 0.045, k.x, k.y, k.z, P, subdiv=1)
    for i, (dx, ang) in enumerate(((-0.02, -6), (0.035, 9))):
        top = k + Vector((dx, -0.005 - 0.01 * i, -0.02))
        with b.at(tuple(top), rot=(4 + 4 * i, ang, -22)):
            b.box(0.075, 0.025, 0.2, 0, 0, -0.2, P, bevel=0.008)
            b.box(0.077, 0.027, 0.025, 0, 0, -0.17, S, bevel=0.004)
            for f in range(4):
                b.box(0.012, 0.012, 0.035, -0.027 + f * 0.018, 0, -0.235, S, bevel=0)


def mug(b):
    s = Vector(SOCKETS["hand_R"][1])
    c = s + Vector((0.0, -0.075, -0.01))
    b.cyl(0.07, 0.13, c.x, c.y - 0.01, c.z - 0.06, tint("cloth_primary", "#F7F4EE"), segs=12, bevel=0.01)
    b.cyl(0.06, 0.01, c.x, c.y - 0.01, c.z + 0.062, "wood_deep", segs=12)
    b.torus(0.036, 0.012, c.x + 0.072, c.y - 0.01, c.z, tint("cloth_primary", "#F7F4EE"), segs=10, ring=5, rot=(90, 0, 0))


def fishing_rod(b):
    s = Vector(SOCKETS["hand_R"][1])
    with b.at(tuple(s), rot=(55, 0, 0)):
        b.cyl(0.024, 0.2, 0, 0, -0.09, "tan", segs=8, bevel=0.006)                       # cork grip
        b.cyl(0.03, 0.025, 0, 0, -0.1, "wood_dark", segs=8, bevel=0.005)
        b.cyl(0.02, 0.03, 0, 0, 0.11, "iron", segs=8)
        b.cyl(0.016, 0.85, 0, 0, 0.14, tint("cloth_primary", "#8A5A34"), segs=7, r2=0.006)  # blank
        for t in (0.35, 0.6, 0.82):
            b.torus(0.013, 0.0035, 0, -0.016 - 0.008 * (1 - t), 0.14 + 0.85 * t, "steel", segs=8, ring=4, rot=(90, 0, 0))
        b.cyl(0.045, 0.035, 0.0, -0.05, 0.02, "steel", segs=10, rot=(0, 90, 0), center=True, bevel=0.006)
        b.box(0.02, 0.025, 0.04, 0, -0.025, 0.02, "iron", bevel=0.004, center=True)
        b.box(0.04, 0.01, 0.01, 0.03, -0.05, 0.035, "iron", bevel=0, center=True)
        b.sphere(0.012, 0.05, -0.05, 0.035, "wood_dark", u=6, v=4)
        b.socket("line_tip", (0, -0.006, 0.99))


def watering_can(b):
    s = Vector(SOCKETS["hand_R"][1])
    T = tint("cloth_primary", "#3BB8B5")
    c = s + Vector((0, -0.02, -0.2))
    b.cyl(0.1, 0.15, c.x, c.y, c.z, T, segs=12, bevel=0.012)
    b.cyl(0.105, 0.015, c.x, c.y, c.z + 0.15, T, segs=12, bevel=0.004)
    pts = [c + Vector((0, 0.08, 0.15)), c + Vector((0, 0.06, 0.21)), c + Vector((0, 0.0, 0.225)),
           c + Vector((0, -0.06, 0.21)), c + Vector((0, -0.08, 0.15))]
    tube(b, [(p, 0.014, 0.014) for p in pts], lambda p, z: T, n=6, cap0=True, cap1=True)
    with b.at(tuple(c + Vector((0, -0.07, 0.04))), rot=(-58, 0, 0)):
        b.cyl(0.018, 0.2, 0, 0, 0, T, segs=8, r2=0.013)
        b.cyl(0.024, 0.04, 0, 0, 0.19, T, segs=8, r2=0.04, bevel=0.004)


def wand(b):
    s = Vector(SOCKETS["hand_R"][1])
    with b.at(tuple(s), rot=(50, 0, -30)):
        b.cyl(0.015, 0.4, 0, 0, -0.08, tint("cloth_primary", "#7A4E2C"), segs=6, r2=0.01)
        b.cyl(0.02, 0.09, 0, 0, -0.09, "wood_deep", segs=6, bevel=0.004)
        with b.at((0, 0, 0.36), rot=(-50, 0, 0)):
            b.prism(star_pts(0.07, 0.03), 0.028, mat="yellow", bevel=0.005)


# ---------------------------------------------------------------------------
def build():
    build_base()
    for fn in (red_beanie, frog_hood, explorer_hat, wizard_hat, bucket_hat, headphones):
        fn()
    outfit("hoodie", {"coral": "#E8655A", "blue": "#3F7FD0", "olive": "#6E8A3A"}, hoodie)
    outfit("varsity_jacket", {"navy": "#2E3F6E", "coral": "#E8655A", "mustard": "#EDB33F"}, varsity_jacket)
    outfit("raincoat", {"mustard": "#EDB33F", "teal": "#3BB8B5", "olive": "#6E8A3A"}, raincoat)
    outfit("overalls", {"teal": "#3BB8B5", "coral": "#E8655A", "lavender": "#A77BD0"}, overalls)
    outfit("striped_tee", {"coral": "#E8655A", "cream": "#F7EEDD", "sky": "#3FA4D4"}, striped_tee)
    outfit("puffer_vest", {"olive": "#6E8A3A", "mustard": "#EDB33F", "blue": "#3F7FD0"}, puffer_vest)
    outfit("cafe_apron", {"cream": "#F7E7CC", "teal": "#3BB8B5", "coral": "#E8655A"}, cafe_apron)
    outfit("wizard_robe", {"purple": "#9C6FD0", "navy": "#2E3F6E", "mustard": "#EDB33F"}, wizard_robe)
    acc("backpack", "back", backpack, {"excludes": ["back"]})
    acc("rolltop_backpack", "back", rolltop_backpack, {"excludes": ["back"]})
    acc("crossbody_bag", "back", crossbody_bag, {"excludes": ["back"], "note": "strap wraps the body; worn in the back slot"})
    acc("glasses", "face", glasses)
    acc("scarf", "neck", scarf)
    acc("mug", "hand_R", mug)
    acc("fishing_rod", "hand_R", fishing_rod, {"activity_item": True, "replaces": ["hand"]})
    acc("watering_can", "hand_R", watering_can)
    acc("wand", "hand_R", wand)
