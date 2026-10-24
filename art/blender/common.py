"""Shared toolkit for the low-poly diorama asset pack.

Conventions (every kit follows these):
  * Units are metres, Blender Z-up. glTF export converts to Y-up.
  * The avatar is ~0.9 m tall. Doors are ~1.6 m, seats ~0.42 m, tables ~0.6 m.
  * An asset's FRONT faces -Y. Its origin is at ground level (z=0), centred on its footprint.
  * Modular building and kit pieces snap to a 1 m grid (MODULE = 1.0).
  * Interaction points are empties named `socket_<what>` parented to the asset
    (for example socket_seat_0, socket_player_1, socket_screen, socket_head).
  * Materials come only from PALETTE. Names are stable so the game can swap them.
    Materials named insert_* are flat graphic inserts (screens, posters, sign faces)
    that get a texture in the game.
  * Engine-managed colour: any part the game may recolour (avatar body, clothes, hats,
    cabinet bodies, upholstery, team colours, awnings...) uses a TINT material named
    `tint_<role>__<default>` via tint(role, default), e.g. tint("body", "blue") ->
    "tint_body__blue". In the engine, every material starting with "tint_" is
    recolourable; <role> is the key and the default colour is baked in. One mesh, any
    colour: never export a separate model per colour. manifest.json lists each asset's
    tint roles and defaults under "tints".
"""
import bpy, bmesh, math, random, json, os, importlib, sys, re, zlib
from contextlib import contextmanager
from mathutils import Vector, Matrix, Euler

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(os.path.dirname(ART), "Models")  # vault folder, beside Renders/
VAULT = os.path.dirname(ART)
PREVIEWS = os.path.join(VAULT, "Renders", "Kits")      # one contact sheet per kit
DETAILS = os.path.join(VAULT, "Renders", "Details")    # close-ups worth keeping: <kit>_<what>.png
WIP = os.path.join(ART, "_wip")                         # throwaway iteration renders
MODULE = 1.0
AVATAR_H = 0.9

# name: (hex, roughness, emission_strength)
PALETTE = {
    # architecture
    "plaster": ("#F3E2C5", 0.9, 0), "plaster_shade": ("#E6CFAA", 0.9, 0),
    "stone": ("#D9CBB4", 0.9, 0), "stone_dark": ("#B9AC98", 0.9, 0), "stone_grey": ("#A9A49C", 0.9, 0),
    "paving": ("#E9D9BE", 0.9, 0), "paving_b": ("#DDCBAE", 0.9, 0),
    "roof": ("#E86D58", 0.8, 0), "roof_b": ("#D95B48", 0.8, 0), "roof_c": ("#F07E66", 0.8, 0),
    "teal": ("#207D85", 0.7, 0), "teal_light": ("#3FB3B5", 0.7, 0), "navy": ("#153447", 0.8, 0),
    "chimney": ("#BFB3A6", 0.9, 0), "chimney_cap": ("#7E7670", 0.9, 0),
    # wood
    "wood": ("#BC874E", 0.85, 0), "wood_b": ("#A9743F", 0.85, 0), "wood_c": ("#C99559", 0.85, 0),
    "wood_dark": ("#7A4E2C", 0.85, 0), "wood_deep": ("#5A3A22", 0.85, 0),
    # metal / misc
    "iron": ("#3E3B3A", 0.6, 0), "iron_light": ("#5E5955", 0.6, 0), "gold": ("#E2A93B", 0.4, 0),
    "steel": ("#8D9096", 0.5, 0), "rope": ("#C9A774", 0.95, 0), "black": ("#1E1E22", 0.8, 0),
    "white": ("#F7F4EE", 0.8, 0), "cream": ("#FAF1DD", 0.85, 0),
    # fabrics and colours
    "coral": ("#E86D58", 0.85, 0), "red": ("#D9473B", 0.85, 0), "red_dark": ("#B23A33", 0.85, 0),
    "orange": ("#F08A2E", 0.85, 0), "yellow": ("#F2C230", 0.85, 0), "mustard": ("#E3A92B", 0.85, 0),
    "green": ("#5DAA3C", 0.85, 0), "olive": ("#6E8A3A", 0.85, 0), "sage": ("#8DAA5B", 0.85, 0),
    "blue": ("#3D7BD9", 0.85, 0), "sky": ("#69B5E8", 0.85, 0), "purple": ("#7B4FC4", 0.85, 0),
    "lavender": ("#A784D9", 0.85, 0), "pink": ("#F2A0B5", 0.85, 0), "brown": ("#9C6A3C", 0.85, 0),
    "tan": ("#D4A46A", 0.85, 0), "grey": ("#9A9A9E", 0.85, 0), "charcoal": ("#3A3D44", 0.85, 0),
    # nature
    "leaf": ("#5FA83A", 0.9, 0), "leaf_b": ("#7CBF45", 0.9, 0), "leaf_dark": ("#3F8A35", 0.9, 0),
    "pine": ("#2F7A4A", 0.9, 0), "pine_b": ("#3E8F55", 0.9, 0), "bark": ("#8A5A34", 0.9, 0),
    "rock": ("#D8CBB8", 0.95, 0), "rock_b": ("#C4B7A4", 0.95, 0), "rock_grey": ("#B4B2AE", 0.95, 0),
    "snow": ("#EEF4F7", 0.9, 0), "snow_shade": ("#D9E6EE", 0.9, 0), "ice": ("#CDEFF5", 0.6, 0),
    "water": ("#69C9D8", 0.3, 0), "water_deep": ("#3FA9C4", 0.3, 0),
    "petal_white": ("#FFFDF6", 0.9, 0), "petal_red": ("#E8524A", 0.9, 0), "petal_yellow": ("#F6C33B", 0.9, 0),
    "terracotta": ("#C8663E", 0.9, 0), "soil": ("#5B3E2B", 1.0, 0),
    # avatar
    "beak": ("#F2A23A", 0.7, 0), "eye": ("#1A1A1F", 0.3, 0), "belly": ("#FAF1DD", 0.85, 0),
    # light emitters
    "glow": ("#FFC76B", 0.5, 3.0), "glow_window": ("#FFC46A", 0.5, 2.0), "bulb": ("#FFE2A0", 0.5, 4.0),
    "glow_teal": ("#7FE9F0", 0.5, 2.5), "aisle_light": ("#FFB84D", 0.5, 4.0),
    # graphic inserts (textured by the game)
    "insert_screen": ("#F8F1E3", 0.6, 0.6), "insert_poster": ("#3C4E8F", 0.7, 0),
    "insert_sign": ("#5A2E2A", 0.7, 0), "insert_chalk": ("#2C3236", 0.95, 0),
    "insert_arcade": ("#7EC8F2", 0.5, 1.5), "insert_marquee": ("#7A2A2E", 0.7, 0),
    "glass": ("#CFEFF4", 0.1, 0),
}

ASSETS = []  # filled by Builder.finish()


def hex_rgb(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]


def rgb_hex(lin):
    srgb = [c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055 for c in lin[:3]]
    return "#%02X%02X%02X" % tuple(round(min(1, max(0, c)) * 255) for c in srgb)


SHADE = "shade"  # colour attribute: greyscale multiplier on tint materials, 1.0 = none

# Palette families that become ONE engine tint with baked shade variation, so recolouring a
# roof or wall to blue keeps its subtle tile-to-tile variation. palette name -> tint role
AUTO_TINT = {"roof": "roof", "roof_b": "roof", "roof_c": "roof",
             "plaster": "wall", "plaster_shade": "wall"}


def _lum(lin):
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def _tint_family(names):
    """Group this mesh's materials into tint families: {old_name: (new_name, shade)}.
    Merges AUTO_TINT palette shades and tint roles named <role>_b/_c that are the same hue
    as <role> (e.g. roof_b). Different hues (awning_a/awning_b stripes) stay separate."""
    import colorsys
    fam = {}
    for nme in names:
        if nme in AUTO_TINT:
            fam.setdefault(AUTO_TINT[nme], []).append((nme, PALETTE[nme][0]))
        elif nme.startswith("tint_"):
            role, d = nme[5:].split("__", 1)
            hx = PALETTE[d][0] if d in PALETTE else "#" + d
            base = re.sub(r"_[bc]$", "", role)
            fam.setdefault(base, []).append((nme, hx))
    out = {}
    for role, members in fam.items():
        cols = {nm: hex_rgb(hx) for nm, hx in members}
        hsv = {nm: colorsys.rgb_to_hsv(*c) for nm, c in cols.items()}
        top = max(cols, key=lambda nm: _lum(cols[nm]))
        same = [nm for nm in cols if min(abs(hsv[nm][0] - hsv[top][0]), 1 - abs(hsv[nm][0] - hsv[top][0])) < 0.05
                and abs(hsv[nm][1] - hsv[top][1]) < 0.2]
        if len(same) < 2 and not any(nm in AUTO_TINT for nm in same):
            continue
        new = tint(role, rgb_hex(cols[top]))
        for nm in same:
            out[nm] = (new, (_lum(cols[nm]) / _lum(cols[top])) ** (1 / 2.2))
    return out


CELL = 0.5  # housing decoration grid, metres


def placement(layer, footprint=None, rotations=(0, 90, 180, 270), clearance=None, recolor=True):
    """Grid-decoration metadata for housing items (see vault note Player Housing - Grid Decoration).
    layer: floor | rug | wall | ceiling | surface. footprint: [w, d] in CELL units, None = derived
    from the model's size at export. clearance: extra cells kept free in front (-Y) for use.
    Origins: floor/rug/surface items at bottom centre; wall items at the centre of their back
    face, touching the wall at y=0 and facing -Y; ceiling items at the hook point (top).
    Surfaces that hold small decor are sockets named surface_<n> (top centre of the surface),
    with their usable size in meta 'surfaces': {name: [w, d]}."""
    return {"placement": {"layer": layer, "cell_m": CELL, "footprint": footprint,
                          "rotations": list(rotations), "clearance_front": clearance or 0,
                          "recolor": recolor}}


def tint(role, default):
    """Recolourable material name for a role, defaulting to a PALETTE colour (or '#hex')."""
    return f"tint_{role}__{default.lstrip('#')}"


def mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    if name.startswith("tint_"):
        d = name.split("__", 1)[1]
        hx, rough, emit = PALETTE[d] if d in PALETTE else ("#" + d, 0.85, 0)
    else:
        hx, rough, emit = PALETTE[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgb = hex_rgb(hx) + [1.0]
    bsdf.inputs["Base Color"].default_value = rgb
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    if emit:
        bsdf.inputs["Emission Color"].default_value = rgb
        bsdf.inputs["Emission Strength"].default_value = emit
    if name == "glass":
        bsdf.inputs["Alpha"].default_value = 0.45
        m.surface_render_method = "BLENDED"
    if name.startswith("tint_"):
        # Base Color = shade attribute x tint. glTF exports this as baseColorFactor (the
        # tint the engine sets) times COLOR_0 (baked per-tile variation that survives recolouring)
        nt = m.node_tree
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = SHADE
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[7].default_value = rgb
        nt.links.new(attr.outputs["Color"], mix.inputs[6])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    m.diffuse_color = rgb
    return m


def pick(names, seed):
    """Deterministic variant pick, e.g. pick(('wood','wood_b','wood_c'), i)."""
    return names[seed % len(names)]


class Builder:
    """Accumulates beveled low-poly parts into one mesh with per-face materials."""

    def __init__(self, name, seed=0):
        self.name = name
        self.bm = bmesh.new()
        self.bm.faces.layers.int.new("piece")  # part id, for fix_coplanar
        self.bm.faces.layers.int.new("movable")  # 0 = static body, n = self.parts[n-1]
        self.parts = []
        self._cur_part = 0
        self.mats = []
        self.sockets = []
        self.rng = random.Random(seed or zlib.crc32(name.encode()))  # stable across runs
        self.xf = Matrix.Identity(4)

    # ---- placement -------------------------------------------------------
    @contextmanager
    def at(self, loc=(0, 0, 0), rotz=0.0, rot=None, scale=1.0):
        """Nest a local frame: everything built inside is moved/rotated (degrees)."""
        prev = self.xf
        r = Euler([math.radians(a) for a in (rot or (0, 0, rotz))]).to_matrix().to_4x4()
        s = Matrix.Diagonal((scale, scale, scale, 1)) if not isinstance(scale, tuple) else Matrix.Diagonal((*scale, 1))
        self.xf = prev @ Matrix.Translation(loc) @ r @ s
        try:
            yield self
        finally:
            self.xf = prev

    @contextmanager
    def part(self, name, pivot=(0, 0, 0), **motion):
        """Movable sub-part: everything built inside becomes a child object 'part_<name>' with
        its origin at `pivot` (in the current frame), so the engine can rotate/slide/sway it.
        Build in the asset's own coordinates as usual. Describe the motion as keywords, e.g.
          with b.part("door_leaf", pivot=(-0.45, -0.1, 0), motion="hinge", axis="z", open_deg=100): ...
          with b.part("crown", pivot=(0, 0, 1.2), motion="sway", amp_deg=3): ...
          with b.part("curtain_l", pivot=(-1, 0, 2), motion="slide", dir=(-1, 0, 0), dist=0.8): ...
        Motion vocabulary: hinge(axis, open_deg) | slide(dir, dist) | sway(amp_deg) |
        flutter(amp_deg) | spin(axis) | press(depth) | tilt(axis, max_deg). Z-fight fixing still
        runs on the whole asset before the parts are split off."""
        self.parts.append({"name": name, "pivot": tuple(self.xf @ Vector(pivot)), "motion": motion})
        prev, self._cur_part = self._cur_part, len(self.parts)
        try:
            yield self
        finally:
            self._cur_part = prev

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _piece(self, create, mat_name, loc, rot, bevel=0.0, jitter=0.0, smooth=False):
        before = set(self.bm.faces)
        create()
        new = [f for f in self.bm.faces if f not in before]
        if bevel > 0:
            edges = list({e for f in new for e in f.edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, offset_type="OFFSET",
                            segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
            new = [f for f in self.bm.faces if f not in before]
        verts = list({v for f in new for v in f.verts})
        if jitter:
            for v in verts:
                v.co += Vector([self.rng.uniform(-jitter, jitter) for _ in range(3)])
        m = self.xf @ Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        mi = self._mi(mat_name)
        lay = self.bm.faces.layers.int.get("piece")
        mov = self.bm.faces.layers.int.get("movable")
        self._pid = getattr(self, "_pid", 0) + 1
        for f in new:
            f.material_index = mi
            f.smooth = smooth
            f[lay] = self._pid
            f[mov] = self._cur_part
        return new

    def _to_mesh(self, bm, name):
        """Weld, write a mesh, and keep only the materials its faces use."""
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        used = sorted({f.material_index for f in bm.faces})
        idx = {old: new for new, old in enumerate(used)}
        for f in bm.faces:
            f.material_index = idx[f.material_index]
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for i in used:
            me.materials.append(mat(self.mats[i]))
        return me

    def apply_tint_families(self):
        """Collapse shade variants into single engine tints and bake the variation as a
        greyscale 'shade' colour attribute (exported as glTF COLOR_0)."""
        fam = _tint_family(self.mats)
        cl = self.bm.loops.layers.color.get(SHADE) or self.bm.loops.layers.color.new(SHADE)
        remap, shade_of = {}, {}
        for i, nm in enumerate(list(self.mats)):
            new, sh = fam.get(nm, (nm, 1.0))
            remap[i] = self._mi(new)
            shade_of[i] = sh
        for f in self.bm.faces:
            sh = shade_of.get(f.material_index, 1.0)
            f.material_index = remap.get(f.material_index, f.material_index)
            for lp in f.loops:
                lp[cl] = (sh, sh, sh, 1.0)
        used = {f.material_index for f in self.bm.faces}
        keep = [i for i in range(len(self.mats)) if i in used]
        idx = {old: new for new, old in enumerate(keep)}
        for f in self.bm.faces:
            f.material_index = idx[f.material_index]
        self.mats = [self.mats[i] for i in keep]

    def drop_duplicates(self):
        """Delete parts that exactly repeat another part (same vertices within 1 mm). They can
        only z-fight and are always a modelling slip. Returns how many were removed."""
        lay = self.bm.faces.layers.int.get("piece")
        verts_of = {}
        for f in self.bm.faces:
            verts_of.setdefault(f[lay], set()).update(f.verts)
        seen, dead = {}, []
        for pid in sorted(verts_of):
            sig = tuple(sorted(tuple(round(c * 1000) for c in v.co) for v in verts_of[pid]))
            if sig in seen:
                dead.append(pid)
            else:
                seen[sig] = pid
        if dead:
            bmesh.ops.delete(self.bm, geom=[f for f in self.bm.faces if f[lay] in dead], context="FACES")
            bmesh.ops.delete(self.bm, geom=[v for v in self.bm.verts if not v.link_faces], context="VERTS")
        self.dupes = len(dead)
        return len(dead)

    def fix_coplanar(self, push=0.004, passes=8, tol=0.0015):
        """Remove z-fighting. Where faces of two different parts share a plane (within tol)
        and overlap, the biggest face stays and each smaller part's conflicting face is pushed
        outward along its normal (growing that part by a few mm) to the first depth, a
        multiple of push, clear of every face it overlaps.
        Runs in finish() before vertices are welded. push=0 only counts conflicting parts."""
        import bisect
        lay = self.bm.faces.layers.int.get("piece")
        moved_total = 0
        if push:
            self.drop_duplicates()
        self.conflicts = []
        for _ in range(passes):
            self.bm.normal_update()
            groups = {}
            for f in self.bm.faces:
                n = f.normal
                if n.length < 0.5:
                    continue
                c = f.calc_center_median()
                if n.z < -0.9 and c.z < 0.003:
                    continue  # ground-contact bottoms are never seen
                a = f.calc_area()
                if a < 2e-5:
                    continue
                groups.setdefault((round(n.x, 2), round(n.y, 2), round(n.z, 2)), []).append([n.dot(c), f, a])
            moves = {}
            for key, fs in groups.items():
                if len({f[lay] for _, f, _ in fs}) < 2:
                    continue
                n = Vector(key).normalized()
                # world-aligned in-plane axes, so grid-laid tiles and planks project exactly
                ax = Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))
                u = (ax - n * n.dot(ax)).normalized()
                v = n.cross(u)
                for item in fs:
                    pts = [(u.dot(p.co), v.dot(p.co)) for p in item[1].verts]
                    xs, ys = [q[0] for q in pts], [q[1] for q in pts]
                    item.append((min(xs), max(xs), min(ys), max(ys), pts))
                fs.sort(key=lambda t: t[0])
                ds = [t[0] for t in fs]

                def overlap(A, B, eps=0.003):
                    """True if the two convex faces overlap by more than eps (separating-axis test)."""
                    if min(A[1], B[1]) - max(A[0], B[0]) <= eps or min(A[3], B[3]) - max(A[2], B[2]) <= eps:
                        return False
                    for P in (A[4], B[4]):
                        for i in range(len(P)):
                            (x0, y0), (x1, y1) = P[i], P[(i + 1) % len(P)]
                            nx, ny = y0 - y1, x1 - x0
                            L = math.hypot(nx, ny)
                            if L < 1e-9:
                                continue
                            nx, ny = nx / L, ny / L
                            pa = [x * nx + y * ny for x, y in A[4]]
                            pb = [x * nx + y * ny for x, y in B[4]]
                            if min(max(pa), max(pb)) - max(min(pa), min(pb)) <= eps:
                                return False
                    return True
                parent, size, faces_of = {}, {}, {}

                def root(p):
                    while parent.setdefault(p, p) != p:
                        p = parent[p]
                    return p
                for i, (d, fa, aa, ea) in enumerate(fs):
                    j = i + 1
                    while j < len(fs) and fs[j][0] - d < tol:
                        _, fb, ab, eb = fs[j]
                        if fa[lay] != fb[lay] and overlap(ea, eb):
                            parent[root(fa[lay])] = root(fb[lay])
                            if push == 0:
                                self.conflicts.append((key, round(d, 4), round(fs[j][0], 4), self.mats[fa.material_index],
                                                       self.mats[fb.material_index], round(aa, 4), round(ab, 4), fa[lay], fb[lay]))
                            for pid, ar, it in ((fa[lay], aa, fs[i]), (fb[lay], ab, fs[j])):
                                size[pid] = max(size.get(pid, 0), ar)
                                faces_of.setdefault(pid, []).append(it)
                        j += 1
                if push == 0:
                    moves.update({(pid, key): None for pid in size})
                    continue
                # greedy depth colouring: biggest parts first; each takes the smallest step k whose
                # depth is clear of every overlapping face already placed or not in conflict
                planned = {}
                for pid in sorted(size, key=lambda p: (-size[p], p)):
                    for k in range(5):  # cap: never move a part more than 4 * push
                        t_ok = True
                        for d, f, a, e in faces_of[pid]:
                            t = d + k * push
                            lo = bisect.bisect_left(ds, t - tol - 5 * push)
                            hi = bisect.bisect_right(ds, t + tol)
                            for q in range(lo, hi):
                                qp = fs[q][1][lay]
                                if qp == pid or (qp in size and qp not in planned):
                                    continue
                                dq = fs[q][0] + planned.get(qp, 0) * push
                                if abs(dq - t) < tol and overlap(e, fs[q][3]):
                                    t_ok = False
                                    break
                            if not t_ok:
                                break
                        if t_ok:
                            break
                    else:
                        k = 0  # no clear depth within the cap: leave it rather than drift
                    planned[pid] = k
                    if k:
                        moves[(pid, key)] = (n * push * k, faces_of[pid])
            if push == 0:
                return len(moves)
            if not moves:
                return moved_total
            # grow only the conflicting faces outward, so a part flush at both ends (top and
            # bottom) resolves each side independently instead of oscillating
            for vec, items in moves.values():
                for vtx in {vt for it in items for vt in it[1].verts}:
                    vtx.co += vec
            moved_total += len(moves)
        return moved_total

    # ---- primitives (all sizes in metres, angles in degrees) -------------
    def box(self, sx, sy, sz, x=0, y=0, z=0, mat="wood", bevel=0.015, rot=(0, 0, 0), center=False, jitter=0.0):
        """Box with its bottom at z (or centred on z if center=True)."""
        def mk():
            r = bmesh.ops.create_cube(self.bm, size=1.0)
            bmesh.ops.scale(self.bm, vec=(sx, sy, sz), verts=r["verts"])
            if not center:
                bmesh.ops.translate(self.bm, vec=(0, 0, sz / 2), verts=r["verts"])
        bev = min(bevel, sx * 0.45, sy * 0.45, sz * 0.45)
        return self._piece(mk, mat, (x, y, z), rot, bev, jitter)

    def cyl(self, r, h, x=0, y=0, z=0, mat="wood", segs=8, r2=None, bevel=0.0, rot=(0, 0, 0), cap=True, center=False, jitter=0.0):
        """Cylinder or cone along local Z, bottom at z."""
        def mk():
            res = bmesh.ops.create_cone(self.bm, cap_ends=cap, cap_tris=False, segments=segs,
                                        radius1=r, radius2=r if r2 is None else r2, depth=h)
            if not center:
                bmesh.ops.translate(self.bm, vec=(0, 0, h / 2), verts=res["verts"])
        return self._piece(mk, mat, (x, y, z), rot, bevel, jitter)

    def blob(self, rx, ry, rz, x=0, y=0, z=0, mat="leaf", subdiv=1, jitter=0.0, rot=(0, 0, 0)):
        """Faceted ellipsoid (icosphere) centred at (x,y,z): canopies, rocks, snow, bodies."""
        def mk():
            res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0)
            bmesh.ops.scale(self.bm, vec=(rx, ry, rz), verts=res["verts"])
        return self._piece(mk, mat, (x, y, z), rot, 0, jitter)

    def sphere(self, r, x=0, y=0, z=0, mat="white", u=8, v=6, scale=(1, 1, 1), rot=(0, 0, 0), jitter=0.0):
        def mk():
            res = bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=r)
            bmesh.ops.scale(self.bm, vec=scale, verts=res["verts"])
        return self._piece(mk, mat, (x, y, z), rot, 0, jitter)

    def prism(self, pts, depth, x=0, y=0, z=0, mat="wood", rot=(0, 0, 0), bevel=0.0, plane="xz"):
        """Extrude a 2D outline. plane='xz' gives a flat front-facing shape extruded along +Y
        (signs, pennants, gables). plane='xy' gives a floor shape extruded up along Z."""
        def mk():
            if plane == "xz":
                vs = [self.bm.verts.new((p[0], -depth / 2, p[1])) for p in pts]
                vec = (0, depth, 0)
            else:
                vs = [self.bm.verts.new((p[0], p[1], 0)) for p in pts]
                vec = (0, 0, depth)
            f = self.bm.faces.new(vs)
            ext = bmesh.ops.extrude_face_region(self.bm, geom=[f])
            nv = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
            bmesh.ops.translate(self.bm, vec=vec, verts=nv)
            bmesh.ops.recalc_face_normals(self.bm, faces=list({fc for v in vs + nv for fc in v.link_faces}))
        return self._piece(mk, mat, (x, y, z), rot, bevel)

    def torus(self, R, r, x=0, y=0, z=0, mat="white", segs=12, ring=6, rot=(0, 0, 0)):
        def mk():
            grid = []
            for i in range(segs):
                a = 2 * math.pi * i / segs
                row = []
                for j in range(ring):
                    b = 2 * math.pi * j / ring
                    rr = R + r * math.cos(b)
                    row.append(self.bm.verts.new((rr * math.cos(a), rr * math.sin(a), r * math.sin(b))))
                grid.append(row)
            for i in range(segs):
                for j in range(ring):
                    a, b = grid[i][j], grid[(i + 1) % segs][j]
                    c, d = grid[(i + 1) % segs][(j + 1) % ring], grid[i][(j + 1) % ring]
                    self.bm.faces.new((a, b, c, d))
        return self._piece(mk, mat, (x, y, z), rot)

    def mesh(self, verts, faces, mat="wood", x=0, y=0, z=0, rot=(0, 0, 0)):
        """Raw polygons for anything the primitives can't express."""
        def mk():
            vs = [self.bm.verts.new(v) for v in verts]
            for f in faces:
                self.bm.faces.new([vs[i] for i in f])
        return self._piece(mk, mat, (x, y, z), rot)

    def socket(self, name, loc=(0, 0, 0), rotz=0.0):
        """Interaction or attachment point, exported as an empty node."""
        p = self.xf @ Vector(loc)
        self.sockets.append((name, tuple(p), rotz))

    # ---- output ----------------------------------------------------------
    def finish(self, kit, category="prop", meta=None, collection=None):
        self.apply_tint_families()
        self.zfix = self.fix_coplanar()
        self.zleft = self.fix_coplanar(push=0.0)  # count only
        mov = self.bm.faces.layers.int.get("movable")
        part_meshes = []
        for i, p in enumerate(self.parts, start=1):
            pb = self.bm.copy()
            pm = pb.faces.layers.int.get("movable")
            bmesh.ops.delete(pb, geom=[f for f in pb.faces if f[pm] != i], context="FACES")
            bmesh.ops.delete(pb, geom=[v for v in pb.verts if not v.link_faces], context="VERTS")
            bmesh.ops.translate(pb, vec=-Vector(p["pivot"]), verts=pb.verts)
            part_meshes.append((p, self._to_mesh(pb, f"{self.name}_{p['name']}")))
        if self.parts:
            bmesh.ops.delete(self.bm, geom=[f for f in self.bm.faces if f[mov] != 0], context="FACES")
            bmesh.ops.delete(self.bm, geom=[v for v in self.bm.verts if not v.link_faces], context="VERTS")
        me = self._to_mesh(self.bm, self.name)
        obj = bpy.data.objects.new(self.name, me)
        coll = collection or kit_collection(kit)
        coll.objects.link(obj)
        for p, pme in part_meshes:
            po = bpy.data.objects.new(f"part_{p['name']}", pme)
            coll.objects.link(po)
            po.parent = obj
            po.location = p["pivot"]
            po["part"] = p["name"]
            for k, v in p["motion"].items():
                po[k] = v if isinstance(v, (int, float, str)) else json.dumps(v)
        for name, loc, rz in self.sockets:
            add_socket(obj, name, loc, rz)
        register(obj, kit, category, meta)
        obj["zfight_parts_moved"] = self.zfix
        obj["zfight_remaining"] = self.zleft
        return obj


def add_socket(parent, name, loc, rotz=0.0):
    e = bpy.data.objects.new(f"socket_{name}" if not name.startswith("socket_") else name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.12
    e.location = loc
    e.rotation_euler = (0, 0, math.radians(rotz))
    for c in parent.users_collection:
        c.objects.link(e)
    e.parent = parent
    return e


def register(obj, kit, category="prop", meta=None):
    obj["asset_id"] = f"{kit}/{obj.name}"
    obj["category"] = category
    for k, v in (meta or {}).items():
        obj[k] = v if isinstance(v, (int, float, str)) else json.dumps(v)
    ASSETS.append({"obj": obj, "kit": kit, "category": category, "meta": meta or {}})
    return obj


def kit_collection(kit):
    c = bpy.data.collections.get(kit)
    if not c:
        c = bpy.data.collections.new(kit)
        bpy.context.scene.collection.children.link(c)
    return c


# =========================================================================
# Shared architecture and dressing helpers. They take a Builder and build in
# its current frame. Front faces -Y.
# =========================================================================
WOOD = ("wood", "wood_b", "wood_c")
ROOF = ("roof", "roof_b", "roof_c")
STONE = ("stone", "stone_dark", "paving_b")


def planks(b, w, d, z=0.0, plank=0.16, thick=0.06, mats=WOOD, along="x", gap=0.012, x=0, y=0):
    """Deck or floor of individual planks covering w x d, top at z+thick."""
    n = max(1, round((d if along == "x" else w) / plank))
    step = (d if along == "x" else w) / n
    for i in range(n):
        o = -((d if along == "x" else w) / 2) + step * (i + 0.5)
        m = pick(mats, i * 7 + 3)
        if along == "x":
            b.box(w, step - gap, thick, x, y + o, z, m, bevel=0.01)
        else:
            b.box(step - gap, d, thick, x + o, y, z, m, bevel=0.01)


def stone_row(b, length, height, depth, x0=0, y=0, z=0, mats=STONE, unit=0.45, bevel=0.03, rng=None):
    """A course of chunky blocks along +X from x0, front face at y-depth/2."""
    rng = rng or b.rng
    x = x0
    i = 0
    while x < x0 + length - 1e-3:
        w = min(unit * rng.uniform(0.75, 1.25), x0 + length - x)
        hh = height * rng.uniform(0.94, 1.0)
        b.box(w - 0.015, depth, hh, x + w / 2, y, z, pick(mats, i * 5 + int(w * 100)), bevel=bevel)
        x += w
        i += 1


def gable_roof(b, width, depth, rise, z, overhang=0.18, tile=0.32, mats=ROOF, gable_wall="plaster",
               trim="wood_dark", rows=None, tile_thick=0.07, ridge_axis="x"):
    """Chunky tiled gable roof. Ridge runs along X (the building's width) at height z+rise.
    Includes gable triangles in gable_wall material and a ridge cap."""
    W, D = width + 2 * overhang, depth + 2 * overhang
    half = D / 2
    slope = math.hypot(half, rise)
    ang = math.degrees(math.atan2(rise, half))
    rows = rows or max(2, round(slope / tile))
    cols = max(2, round(W / tile))
    tl, tw = slope / rows, W / cols
    for side in (-1, 1):
        for r in range(rows):
            s = (r + 0.5) * tl
            yy = side * (half - s * math.cos(math.radians(ang)))
            zz = z + s * math.sin(math.radians(ang)) - 0.04 * (1 - r / rows)
            off = (tw / 2) * (r % 2)
            for c in range(cols + (1 if r % 2 else 0)):
                xx = -W / 2 + tw * (c + 0.5) - off
                x0, x1 = max(-W / 2, xx - tw / 2), min(W / 2, xx + tw / 2)
                if x1 - x0 < 0.05:
                    continue
                b.box(x1 - x0 - 0.012, tl + 0.02, tile_thick, (x0 + x1) / 2, yy, zz,
                      pick(mats, r * 3 + c * 5 + (side > 0)), bevel=0.018,
                      rot=(ang if side < 0 else -ang, 0, 0),
                      center=True)
    # ridge cap
    b.box(W + 0.04, 0.2, 0.12, 0, 0, z + rise - 0.03, mats[1], bevel=0.03)
    # gable triangles on both ends
    if gable_wall:
        tri = [(-depth / 2, 0), (depth / 2, 0), (0, rise - 0.05)]
        for sx in (-1, 1):
            b.prism([(p[0], p[1]) for p in tri], 0.12, x=sx * (width / 2 - 0.06), y=0, z=z,
                    mat=gable_wall, rot=(0, 0, 90))
            # exposed beams on the gable
            b.box(0.1, depth * 0.9, 0.1, sx * (width / 2 + 0.01), 0, z + 0.02, trim, bevel=0.015)
            b.box(0.1, 0.1, rise * 0.8, sx * (width / 2 + 0.01), 0, z + 0.05, trim, bevel=0.015)


def door(b, w=0.9, h=1.55, x=0, y=0, z=0, mat="teal", frame="wood", window=True, knob="gold", panels=True):
    """Door with frame and lintel, face at y (front = -Y), bottom at z. Adds socket 'door'."""
    t = 0.08
    b.box(w + 0.2, t + 0.04, 0.14, x, y - 0.01, z + h, frame, bevel=0.02)             # lintel
    for sx in (-1, 1):
        b.box(0.1, t + 0.04, h, x + sx * (w / 2 + 0.05), y - 0.01, z, frame, bevel=0.02)
    b.box(w, t, h, x, y + 0.02, z, mat, bevel=0.02)
    if panels:
        b.box(w * 0.7, 0.03, h * 0.28, x, y - 0.03, z + h * 0.12, mat, bevel=0.012)
    if window:
        ww, wh = w * 0.42, h * 0.24
        b.box(ww + 0.06, 0.03, wh + 0.06, x, y - 0.03, z + h * 0.6, frame, bevel=0.01)
        b.box(ww, 0.03, wh, x, y - 0.04, z + h * 0.6 + 0.03, "glow_window", bevel=0.005)
        b.box(0.025, 0.035, wh, x, y - 0.05, z + h * 0.6 + 0.03, frame, bevel=0)
        b.box(ww, 0.035, 0.025, x, y - 0.05, z + h * 0.6 + 0.03 + wh / 2 - 0.012, frame, bevel=0)
    b.sphere(0.035, x + w * 0.35, y - 0.04, z + h * 0.45, knob, u=6, v=4)
    b.socket("door", (x, y - 0.6, z))


def window(b, w=0.6, h=0.7, x=0, y=0, z=1.0, frame="wood", glow="glow_window", sill=True, cross=True, shutters=None):
    """Window set into a wall face at y; z is the bottom of the glass."""
    t = 0.07
    b.box(w + 0.12, t, 0.08, x, y - 0.02, z + h, frame, bevel=0.015)
    b.box(w + 0.12, t, 0.08, x, y - 0.02, z - 0.08, frame, bevel=0.015)
    for sx in (-1, 1):
        b.box(0.07, t, h, x + sx * (w / 2 + 0.025), y - 0.02, z, frame, bevel=0.012)
    b.box(w, 0.03, h, x, y + 0.01, z, glow, bevel=0)
    if cross:
        b.box(0.04, 0.05, h, x, y - 0.02, z, frame, bevel=0)
        b.box(w, 0.05, 0.04, x, y - 0.02, z + h / 2 - 0.02, frame, bevel=0)
    if sill:
        b.box(w + 0.22, 0.14, 0.05, x, y - 0.06, z - 0.12, frame, bevel=0.015)
    if shutters:
        for sx in (-1, 1):
            b.box(w * 0.45, 0.04, h + 0.06, x + sx * (w * 0.5 + 0.2), y - 0.03, z - 0.03, shutters, bevel=0.012)


def flower(b, x, y, z, petal="petal_white", center="petal_yellow", size=0.06, n=5):
    for i in range(n):
        a = 2 * math.pi * i / n
        b.blob(size * 0.55, size * 0.35, size * 0.18, x + math.cos(a) * size * 0.6, y + math.sin(a) * size * 0.6, z,
               petal, subdiv=1, rot=(0, 0, math.degrees(a)))
    b.blob(size * 0.32, size * 0.32, size * 0.22, x, y, z + size * 0.08, center, subdiv=1)


def foliage(b, w, d, z, x=0, y=0, density=1.0, flowers=("petal_white", "petal_red"), leaf=("leaf", "leaf_b", "leaf_dark"), fsize=0.065, height=0.16):
    """A lush mound of faceted leaf clusters with flowers on top, for planters and beds.
    Grid-filled base (no bare patches), a raised centre layer, leaves spilling over the
    front (-Y) lip, and flowers resting on the mound."""
    rng = b.rng
    step = 0.085 / max(0.5, density) ** 0.5
    nx, ny = max(1, round(w / step)), max(1, round(d / step))
    hs = height / 0.16
    tops = []
    for ix in range(nx):
        for iy in range(ny):
            lx = x - w / 2 + (ix + 0.5) * w / nx + rng.uniform(-0.02, 0.02)
            ly = y - d / 2 + (iy + 0.5) * d / ny + rng.uniform(-0.02, 0.02)
            r = rng.uniform(0.065, 0.085)
            # mound: taller toward the middle of the box
            cx = 1 - abs((lx - x) / (w / 2 + 1e-6))
            cy = 1 - abs((ly - y) / (d / 2 + 1e-6))
            lift = (0.35 + 0.65 * min(cx, cy) ** 0.5) * height * 0.55
            b.blob(r * 1.25, r * 1.0, r * 0.7 * hs, lx, ly, z + lift, pick(leaf, ix * 3 + iy),
                   subdiv=1, jitter=r * 0.1, rot=(rng.uniform(-15, 15), rng.uniform(-15, 15), rng.uniform(0, 180)))
            tops.append((lx, ly, z + lift + r * 0.6 * hs))
    # spill over the front lip
    for i in range(max(2, round(w / 0.13))):
        lx = x - w / 2 + (i + 0.5) * w / max(2, round(w / 0.13)) + rng.uniform(-0.02, 0.02)
        r = rng.uniform(0.05, 0.07)
        b.blob(r * 1.2, r * 0.8, r * 0.75, lx, y - d / 2 - r * 0.35, z - r * 0.15, pick(leaf, i + 1),
               subdiv=1, jitter=r * 0.1, rot=(rng.uniform(10, 30), 0, rng.uniform(0, 180)))
    if flowers:
        rng.shuffle(tops)
        for i, (fx, fy, fz) in enumerate(tops[:max(2, int(len(tops) * 0.45 * density))]):
            flower(b, fx, fy, fz + 0.005, pick(flowers, i), size=fsize * rng.uniform(0.85, 1.15))


def planter_box(b, w=0.9, d=0.36, h=0.28, x=0, y=0, z=0, flowers=("petal_white", "petal_red"), mats=WOOD):
    """Wooden planter: plank sides, corner posts, soil and foliage. Used for window boxes too."""
    for i, zz in enumerate((z, z + h / 2)):
        b.box(w, 0.05, h / 2 - 0.01, x, y - d / 2 + 0.025, zz, pick(mats, i), bevel=0.012)
        b.box(w, 0.05, h / 2 - 0.01, x, y + d / 2 - 0.025, zz, pick(mats, i + 1), bevel=0.012)
        b.box(0.05, d, h / 2 - 0.01, x - w / 2 + 0.025, y, zz, pick(mats, i + 2), bevel=0.012)
        b.box(0.05, d, h / 2 - 0.01, x + w / 2 - 0.025, y, zz, pick(mats, i), bevel=0.012)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box(0.07, 0.07, h + 0.02, x + sx * (w / 2 - 0.02), y + sy * (d / 2 - 0.02), z, "wood_b", bevel=0.015)
    b.box(w - 0.08, d - 0.08, 0.04, x, y, z + h - 0.06, "soil", bevel=0)
    foliage(b, w - 0.1, d - 0.08, z + h - 0.04, x, y, flowers=flowers)


def lantern_head(b, x, y, z, s=1.0, frame="iron", glow="glow"):
    """Hexagonal lantern cage with glowing glass, cap and finial; z is the cage bottom."""
    b.cyl(0.11 * s, 0.05 * s, x, y, z, frame, segs=6, bevel=0.01)
    b.cyl(0.085 * s, 0.22 * s, x, y, z + 0.05 * s, glow, segs=6)
    for i in range(6):
        a = math.radians(30 + 60 * i)
        b.box(0.025 * s, 0.025 * s, 0.22 * s, x + math.cos(a) * 0.09 * s, y + math.sin(a) * 0.09 * s, z + 0.05 * s, frame, bevel=0)
    b.cyl(0.13 * s, 0.07 * s, x, y, z + 0.27 * s, frame, segs=6, r2=0.05 * s, bevel=0.008)
    b.cyl(0.035 * s, 0.07 * s, x, y, z + 0.34 * s, frame, segs=6, r2=0.0)


def wall_lantern(b, x, y, z, s=1.0):
    """Bracket lantern mounted on a wall whose face is at y (front -Y). z = bracket height."""
    b.box(0.12 * s, 0.05 * s, 0.24 * s, x, y - 0.02 * s, z - 0.1 * s, "iron", bevel=0.01)
    b.box(0.04 * s, 0.24 * s, 0.04 * s, x, y - 0.14 * s, z + 0.08 * s, "iron", bevel=0)
    lantern_head(b, x, y - 0.26 * s, z - 0.22 * s, s * 0.85)


def awning(b, w=1.6, depth=0.6, drop=0.35, x=0, y=0, z=2.0, a="coral", c="cream", stripes=None, scallop=True):
    """Striped shop awning attached at wall face y, top edge at z, sloping out toward -Y."""
    n = stripes or max(4, round(w / 0.3))
    sw = w / n
    ang = math.degrees(math.atan2(drop, depth))
    L = math.hypot(depth, drop)
    for i in range(n):
        m = a if i % 2 == 0 else c
        xx = x - w / 2 + sw * (i + 0.5)
        b.box(sw, L, 0.04, xx, y - depth / 2, z - drop / 2, m, bevel=0.008, rot=(ang, 0, 0), center=True)
        if scallop:
            b.box(sw - 0.02, 0.04, 0.16, xx, y - depth - 0.01, z - drop - 0.16, m, bevel=0.01)
    b.box(w + 0.08, 0.06, 0.06, x, y - 0.03, z - 0.02, "wood_dark", bevel=0.01)


def snow_cap(b, w, d, x=0, y=0, z=0, h=0.09, lumps=True):
    """Lumpy snow layer sitting on a surface at height z."""
    b.box(w, d, h, x, y, z, "snow", bevel=min(0.04, h * 0.45))
    if lumps:
        rng = b.rng
        for i in range(max(1, int(w * d * 6))):
            r = rng.uniform(0.06, 0.12)
            b.blob(r * 1.4, r, r * 0.6, x + rng.uniform(-w / 2, w / 2) * 0.8, y + rng.uniform(-d / 2, d / 2) * 0.8,
                   z + h, "snow", subdiv=1, jitter=r * 0.1)


def chimney(b, x, y, z, h=0.9, w=0.42, snow=False):
    b.box(w, w, h, x, y, z, "chimney", bevel=0.025)
    b.box(w + 0.08, w + 0.08, 0.1, x, y, z + h, "chimney_cap", bevel=0.02)
    b.box(w * 0.55, w * 0.55, 0.04, x, y, z + h + 0.07, "black", bevel=0)
    if snow:
        snow_cap(b, w + 0.06, w + 0.06, x, y, z + h + 0.1, h=0.06, lumps=False)


def post(b, x, y, z=0, h=0.8, w=0.14, mat="wood_b", cap=True):
    b.box(w, w, h, x, y, z, mat, bevel=0.02)
    if cap:
        b.box(w * 0.75, w * 0.75, 0.04, x, y, z + h, mat, bevel=0.012)


def rope_between(b, p0, p1, sag=0.12, r=0.018, segs=6, mat="rope"):
    """Sagging rope made of short cylinders between two points (world coords in the frame)."""
    p0, p1 = Vector(p0), Vector(p1)
    pts = []
    for i in range(segs + 1):
        t = i / segs
        p = p0.lerp(p1, t)
        p.z -= sag * 4 * t * (1 - t)
        pts.append(p)
    for a, c in zip(pts, pts[1:]):
        d = c - a
        L = d.length
        rot = d.to_track_quat("Z", "Y").to_euler()
        b.cyl(r, L + r, a.x, a.y, a.z, mat, segs=5, rot=tuple(math.degrees(v) for v in rot))
    return pts


def bunting(b, p0, p1, n=4, colors=("coral", "teal_light", "cream", "mustard"), size=0.16, sag=0.1):
    pts = rope_between(b, p0, p1, sag=sag, r=0.012, segs=n * 2)
    for i in range(n):
        p = pts[1 + i * 2]
        d = (Vector(p1) - Vector(p0)).normalized()
        rz = math.degrees(math.atan2(d.y, d.x))
        with b.at(tuple(p), rotz=rz):
            b.prism([(-size / 2, 0), (size / 2, 0), (0, -size * 1.15)], 0.015, mat=pick(colors, i))


def fir(b, x=0, y=0, z=0, h=1.8, r=0.6, tiers=3, snow=True, mats=("pine", "pine_b")):
    """Low-poly fir: stacked faceted cones with optional snow tips."""
    b.cyl(r * 0.16, h * 0.22, x, y, z, "bark", segs=6, bevel=0.01)
    for i in range(tiers):
        t = i / tiers
        rr = r * (1 - t * 0.55)
        zz = z + h * 0.18 + h * 0.26 * i
        hh = h * 0.42
        b.cyl(rr, hh, x, y, zz, pick(mats, i), segs=7, r2=0.02, jitter=rr * 0.04)
        if snow:
            b.cyl(rr * 0.55, hh * 0.38, x, y, zz + hh * 0.62, "snow", segs=7, r2=0.015)


# =========================================================================
# Build, export and preview pipeline
# =========================================================================
def reset_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    for a in list(bpy.data.armatures):
        bpy.data.armatures.remove(a)
    ASSETS.clear()


def roots_of(kit):
    return [a for a in ASSETS if a["kit"] == kit]


def hierarchy(o):
    out = [o]
    for c in o.children:
        out += hierarchy(c)
    return out


def bbox(o):
    pts = []
    for ob in hierarchy(o):
        if ob.type == "MESH":
            pts += [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    if not pts:
        return Vector((0, 0, 0)), Vector((0, 0, 0))
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi


def _clean_names(o):
    """Blender names are global, so a second socket_door becomes socket_door.001. Give this
    asset's children their clean names for the export, then put everything back."""
    undo = []
    for c in hierarchy(o)[1:]:
        base = re.sub(r"\.\d{3}$", "", c.name)
        if base == c.name:
            continue
        holder = bpy.data.objects.get(base)
        if holder:
            undo.append((holder, base))
            holder.name = base + "__park"
        undo.append((c, c.name))
        c.name = base
    return undo


def _restore_names(undo):
    for ob, name in reversed(undo):
        ob.name = name


def export_kit(kit):
    ensure_shade()
    out = os.path.join(MODELS, kit)
    os.makedirs(out, exist_ok=True)
    manifest = []
    for a in roots_of(kit):
        o = a["obj"]
        bpy.ops.object.select_all(action="DESELECT")
        for ob in hierarchy(o):
            ob.select_set(True)
        bpy.context.view_layer.objects.active = o
        path = os.path.join(out, f"{o.name}.glb")
        undo = _clean_names(o)
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                                  export_apply=True, export_yup=True, export_extras=True,
                                  export_skins=True, export_materials="EXPORT",
                                  export_vertex_color="MATERIAL")
        sockets = {c.name: [round(v, 3) for v in c.location] for c in hierarchy(o) if c.type == "EMPTY"}
        parts = {c.name: {"pivot": [round(v, 3) for v in c.location],
                          **{k: (json.loads(c[k]) if isinstance(c[k], str) and c[k][:1] in "[{" else c[k])
                             for k in c.keys() if k not in ("part",)}}
                 for c in hierarchy(o)[1:] if "part" in c}
        _restore_names(undo)
        lo, hi = bbox(o)
        manifest.append({
            "id": f"{kit}/{o.name}", "file": f"{kit}/{o.name}.glb", "category": a["category"],
            "size_m": [round(hi[i] - lo[i], 3) for i in range(3)],
            "sockets": sockets,
            **({"parts": parts} if parts else {}),
            "tints": {m.name.split("__")[0][5:]: rgb_hex(m.diffuse_color)
                      for ob in hierarchy(o) if ob.type == "MESH" for m in ob.data.materials if m and m.name.startswith("tint_")},
            **{k: v for k, v in a["meta"].items()},
        })
        pl = manifest[-1].get("placement")
        if isinstance(pl, dict) and pl.get("footprint") is None and pl.get("layer") in ("floor", "rug", "surface"):
            pl["footprint"] = [max(1, math.ceil(round((hi[i] - lo[i]) / CELL, 3))) for i in (0, 1)]
    with open(os.path.join(out, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    return manifest


def layout_kit(kit, gap=0.6, max_w=14.0, origin=(0, 0)):
    """Arrange a kit's assets in rows (for previews and the combined showcase file)."""
    x = y = row_d = 0.0
    for a in roots_of(kit):
        o = a["obj"]
        if o.parent is not None:
            continue  # registered child parts (hideable roofs) travel with their parent
        lo, hi = bbox(o)
        w, d = hi.x - lo.x, hi.y - lo.y
        if x > 0 and x + w > max_w:
            x = 0
            y += row_d + gap
            row_d = 0
        o.location.x = origin[0] + x - lo.x + o.location.x
        o.location.y = origin[1] + y - lo.y + o.location.y
        if lo.z < -0.01:  # wall/ceiling items, hats and water sit below their origin: lift for viewing
            o.location.z -= lo.z
        x += w + gap
        row_d = max(row_d, d)
    bpy.context.view_layer.update()


def setup_render(res=(1800, 1100)):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    try:
        sc.eevee.taa_render_samples = 32
        sc.eevee.use_shadows = True
    except AttributeError:
        pass
    try:
        sc.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = hex_rgb("#F7EEDD") + [1]
    bg.inputs["Strength"].default_value = 0.55
    if not bpy.data.objects.get("_ground"):
        me = bpy.data.meshes.new("_ground")
        me.from_pydata([(-500, -500, 0), (500, -500, 0), (500, 500, 0), (-500, 500, 0)], [], [(0, 1, 2, 3)])
        g = bpy.data.materials.get("_ground") or bpy.data.materials.new("_ground")
        g.use_nodes = True
        gb = next(n for n in g.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        gb.inputs["Base Color"].default_value = hex_rgb("#F3E9D6") + [1]
        gb.inputs["Roughness"].default_value = 1.0
        me.materials.append(g)
        gr = bpy.data.objects.new("_ground", me)
        sc.collection.objects.link(gr)
        gr.location.z = -0.001
    sun = bpy.data.objects.get("_sun")
    if not sun:
        ld = bpy.data.lights.new("_sun", "SUN")
        ld.energy = 4.5
        ld.color = (1.0, 0.95, 0.86)
        ld.angle = math.radians(8)
        sun = bpy.data.objects.new("_sun", ld)
        sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(42), 0, math.radians(-35))


def render_preview(kit, objs=None, path=None, res=(1800, 1100), elev=58, azim=40, pad=1.12):
    """Orthographic three-quarter render framing the given objects (default: the whole kit)."""
    ensure_shade()
    setup_render(res)
    objs = objs or [a["obj"] for a in roots_of(kit)]
    pts = []
    for o in objs:
        lo, hi = bbox(o)
        pts += [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    center = sum(pts, Vector()) / len(pts)
    cam = bpy.data.objects.get("_cam")
    if not cam:
        cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam"))
        bpy.context.scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    rot = Euler((math.radians(elev), 0, math.radians(azim)))
    cam.rotation_euler = rot
    fwd = rot.to_matrix() @ Vector((0, 0, -1))
    cam.location = center - fwd * 60
    cam.data.clip_end = 200
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    ps = [inv @ p for p in pts]
    sx = max(p.x for p in ps) - min(p.x for p in ps)
    sy = max(p.y for p in ps) - min(p.y for p in ps)
    aspect = res[0] / res[1]
    cam.data.ortho_scale = max(sx, sy * aspect) * pad
    mx = (max(p.x for p in ps) + min(p.x for p in ps)) / 2
    my = (max(p.y for p in ps) + min(p.y for p in ps)) / 2
    cam.location = cam.matrix_world @ Vector((mx, my, 0))
    bpy.context.scene.camera = cam
    path = path or os.path.join(PREVIEWS, f"{kit}.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return bpy.context.scene.render.filepath


def load_kit(kit):
    kits_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kits")
    if os.path.dirname(kits_dir) not in sys.path:
        sys.path.insert(0, os.path.dirname(kits_dir))
    mod = importlib.import_module(f"kits.{kit}")
    importlib.reload(mod)
    return mod


def ensure_shade(objs=None):
    """Tint materials read the 'shade' attribute; give meshes without one a neutral 1.0."""
    for o in objs or bpy.data.objects:
        if o.type == "MESH" and SHADE not in o.data.color_attributes and \
                any(m and m.name.startswith("tint_") for m in o.data.materials):
            ca = o.data.color_attributes.new(SHADE, "BYTE_COLOR", "CORNER")
            for d in ca.data:
                d.color = (1, 1, 1, 1)


def build_kit(kit, export=True, preview=True, clear=True):
    if clear:
        reset_scene()
    mod = load_kit(kit)
    mod.build()
    ensure_shade()
    man = export_kit(kit) if export else None
    if preview:
        layout_kit(kit, max_w=getattr(mod, "PREVIEW_WIDTH", 14.0))
        render_preview(kit)
    return man
