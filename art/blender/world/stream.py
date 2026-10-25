"""The stream: one smooth channel from the rock spring in the north woods to the sea by the south pier,
stepping down in two waterfalls and two weirs (World Map - Island Overview: cascades between rocky banks).

Everything is in stream coordinates: s = metres along the centreline from the spring, d = distance from
it. town.py uses dist() for the channel carve and the placement rules, the water ribbon and its falls
sheets come from water_mesh(), and hand_layout.stream() dresses the banks with bank_xy().

Water levels step down at STEPS; between steps the surface is flat. The terrain bed sits DEPTH under the
local level and the banks rise to BANK above it, so the waterline is always inside the ribbon (which runs
EDGE past the waterline, under the bank) and nothing gaps or z-fights at the shore.
Ribbon UVs: UV0 = (across 0..1, s metres) for flow; UV1 = (foam 0..1, falls 0/1). The Godot water shader
(scripts/world/water.gdshader) reads both.
"""
import math
from mathutils import Vector, kdtree
import ground

CTRL = [Vector((15.4, 33.15)), Vector((16.2, 21.45)), Vector((18.6, 16.25)), Vector((16.1, 8.45)),
        Vector((13.32, 0.0)), Vector((12.02, -7.8)), Vector((8.12, -14.3)), Vector((7.47, -22.1)),
        Vector((8.12, -32.5)), Vector((8.45, -37.6))]          # last point is out through the coast, in the sea
STEP_M = 0.25
PTS = ground.spline(CTRL, STEP_M)
S = [0.0]
for _a, _b in zip(PTS, PTS[1:]):
    S.append(S[-1] + (_b - _a).length)
LENGTH = S[-1]
_KD = kdtree.KDTree(len(PTS))
for _i, _p in enumerate(PTS):
    _KD.insert((_p.x, _p.y, 0.0), _i)
_KD.balance()

W = 1.05            # nominal half-width (town.STREAM_W)
DEPTH = 0.42        # bed under the water surface
BANK = 0.15         # bank lip above the water surface
EDGE = 0.35         # ribbon runs this far past the waterline, under the bank
# (s where the level starts, water level, how it arrives: "lip" = the spring notch, "falls", "weir")
STEPS = [(0.0, 2.25, "lip"), (0.35, 0.85, "falls"), (3.9, -0.2, "falls"), (30.0, -0.34, "weir"), (51.0, -0.46, "weir")]
SEA_LEVEL = -0.5


def _bump(s, a, b):
    """0 outside [a, b], 1 in the middle, smooth both ends."""
    if s <= a or s >= b:
        return 0.0
    t = (s - a) / (b - a)
    return math.sin(math.pi * t) ** 0.8


def width(s):
    """Half-width: pools under each waterfall, a little narrower at every lip, a wider mouth."""
    w = W + 0.06 * math.sin(s * 0.55) + 0.05 * math.sin(s * 1.37 + 1.1)
    w += 0.5 * _bump(s, 0.3, 3.9) + 0.4 * _bump(s, 3.7, 7.5)
    for s0, _, kind in STEPS[1:]:
        w -= (0.18 if kind == "falls" else 0.08) * _bump(s, s0 - 0.9, s0 + 0.3)
    return w + 0.6 * ground.smoothstep(LENGTH - 7.0, LENGTH - 2.0, s)


def level(s):
    lv = STEPS[0][1]
    for s0, z, _ in STEPS:
        if s >= s0:
            lv = z
    return lv


def drop_run(k):
    """Horizontal run of the sheet at step k (falls arc out, weirs are short chutes)."""
    s0, z, kind = STEPS[k]
    drop = STEPS[k - 1][1] - z
    return max(0.22, 0.32 * drop) if kind == "falls" else 0.3


def surface(s):
    """Water surface height at s, following the falls/weir sheets (used for the ribbon)."""
    for k in range(1, len(STEPS)):
        s0, z1, _ = STEPS[k]
        run = drop_run(k)
        if s0 <= s < s0 + run:
            t = (s - s0) / run
            z0 = STEPS[k - 1][1]
            return z0 - (z0 - z1) * t * t
    return level(s)


def at(s):
    """(centre point, unit tangent) at arc length s."""
    s = max(0.0, min(LENGTH, s))
    i = max(0, min(len(PTS) - 2, int(s / STEP_M)))
    while i > 0 and S[i] > s:
        i -= 1
    while i < len(PTS) - 2 and S[i + 1] < s:
        i += 1
    seg = PTS[i + 1] - PTS[i]
    t = (s - S[i]) / max(1e-9, S[i + 1] - S[i])
    return PTS[i] + seg * t, seg.normalized()


def dist(p):
    """(distance to the centreline, s of the nearest point). Before the spring it is the radial distance."""
    _, i, _ = _KD.find((p.x, p.y, 0.0))
    best = (1e9, 0.0)
    for j in (i - 1, i):
        if 0 <= j < len(PTS) - 1:
            a, b = PTS[j], PTS[j + 1]
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
            d = (p - (a + ab * t)).length
            if d < best[0]:
                best = (d, S[j] + t * ab.length)
    return best


def carve(p, h):
    """Terrain height h with the channel cut in: bed DEPTH under the local level, banks easing up."""
    d, s = dist(p)
    w = width(s)
    if d > w + 4.0:
        return h
    lv = level(s)
    prof = lv - DEPTH + (DEPTH + BANK) * ground.smoothstep(0.45 * w, w + 0.15, d) + max(0.0, d - (w + 0.15)) * 0.9
    return min(h, prof)


def wet(p, margin=0.0):
    """Inside the water (to the waterline) plus margin."""
    d, s = dist(p)
    return d < width(s) * 0.92 + margin


def bank_xy(s, side, off=0.0):
    """Point on the waterline at s (side +1 = right bank looking downstream), pushed `off` m outward."""
    c, t = at(s)
    n = Vector((t.y, -t.x))           # right of the flow
    return c + n * side * (width(s) * 0.92 + off)


def yaw_at(s):
    """Blender yaw (deg) of the flow direction at s (assets face -Y at yaw 0, so this faces downstream)."""
    _, t = at(s)
    return math.degrees(math.atan2(t.y, t.x)) + 90.0


def falls():
    """One entry per step below the spring: where it is, how far it drops and which way it faces."""
    out = []
    for k in range(1, len(STEPS)):
        s0, z, kind = STEPS[k]
        run = drop_run(k)
        c, t = at(s0 + run)
        out.append({"s": s0, "kind": kind, "base": (c.x, c.y, z), "top": STEPS[k - 1][1], "drop": STEPS[k - 1][1] - z,
                    "half_width": width(s0) * 0.85, "dir": (t.x, t.y), "run": run})
    return out


def _foam(s):
    """Foam on the surface: boil at the foot of each step, fading downstream; a band where it meets the sea."""
    f = 0.0
    for k in range(1, len(STEPS)):
        s0, z, kind = STEPS[k]
        foot = s0 + drop_run(k)
        if s >= foot:
            strength = min(1.0, 0.45 + 0.6 * (STEPS[k - 1][1] - z))
            f = max(f, strength * math.exp(-(s - foot) / (1.6 if kind == "falls" else 0.9)))
        elif s >= s0:
            f = max(f, 0.35)          # on the sheet itself (the shader adds streaks)
    return min(1.0, f)


def water_mesh(island_d):
    """Ribbon verts/faces/uv0/uv1 from the spring to just past the coast (Blender space)."""
    stations = []
    s = 0.0
    while s <= LENGTH and island_d(at(s)[0]) <= 0.6:     # past the coast the sea plane takes over
        stations.append(s)
        s += STEP_M
    end = stations[-1]
    for k in range(1, len(STEPS)):          # extra rows along each sheet so the arc is smooth
        s0, run = STEPS[k][0], drop_run(k)
        stations += [s0 - 0.02] + [s0 + run * q / 6 for q in range(1, 7)]
    stations = sorted({round(v, 4) for v in stations if 0.0 <= v <= end})
    cols = [-1.0, -0.72, -0.4, 0.0, 0.4, 0.72, 1.0]
    verts, faces, uv0, uv1 = [], [], [], []
    for r, s in enumerate(stations):
        c, t = at(s)
        n = Vector((t.y, -t.x))
        half = width(s) * 0.92 + EDGE
        z = surface(s)
        fall = 1.0 if any(st[0] <= s < st[0] + drop_run(k) for k, st in enumerate(STEPS) if k) else 0.0
        foam = _foam(s)
        for cx in cols:
            q = c + n * (cx * half)
            verts.append((q.x, q.y, z))
            uv0.append(((cx + 1) * 0.5, s))
            uv1.append((foam, fall))
        if r:
            a0, b0 = (r - 1) * len(cols), r * len(cols)
            for k in range(len(cols) - 1):
                faces.append((a0 + k, a0 + k + 1, b0 + k + 1, b0 + k))
    return verts, faces, uv0, uv1, stations


def layout_data(to_godot):
    """Godot-space data for the town loader: the centreline with level and half-width (walk blocking) and
    the falls (spray, mist)."""
    pts = []
    s = 0.0
    while s <= LENGTH:
        c, _ = at(s)
        pts.append([*to_godot((c.x, c.y, level(s))), round(width(s) * 0.92, 3)])
        s += 0.5
    fl = []
    for f in falls():
        b = to_godot(f["base"])
        fl.append({"kind": f["kind"], "base": b, "top": round(f["top"], 3), "drop": round(f["drop"], 3),
                   "half_width": round(f["half_width"], 3), "dir": [round(f["dir"][0], 4), round(-f["dir"][1], 4)]})
    return {"points": pts, "falls": fl, "sea_level": SEA_LEVEL}


def ribbon_object(name, island_d, material):
    """The stream water as a mesh object with both UV maps (exported as TEXCOORD_0/1)."""
    import bpy
    verts, faces, uv0, uv1, _ = water_mesh(island_d)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    for nm, uv in (("UVMap", uv0), ("UV_foam", uv1)):
        layer = me.uv_layers.new(name=nm)
        for poly in me.polygons:
            for li in poly.loop_indices:
                layer.data[li].uv = uv[me.loops[li].vertex_index]
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(material)
    me.update()
    return bpy.data.objects.new(name, me)


SHORE_RES, SHORE_HALF = 512, 50.0   # water_shore.png covers x, y in [-50, 50] m (Blender), ~0.2 m a pixel


def bake_shore(terrain, stamps, path, water_z=SEA_LEVEL):
    """Water helper texture for the sea shader: R = shore foam (shallow water, rings round rocks, boats,
    floes and dock posts), G = depth 0..1 (shallow to deep colour). Pixel (i, j) covers Blender
    x = -50 + (i + 0.5) * 100 / 512, y = 50 - (j + 0.5) * 100 / 512 (image row 0 is north)."""
    import bpy
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(terrain, dg)
    N, H = SHORE_RES, SHORE_HALF
    px = N * N
    foam = [0.0] * px
    depth = [1.0] * px
    m = 2 * H / N
    down = Vector((0, 0, -1))
    for j in range(N):
        y = H - (j + 0.5) * m
        for i in range(N):
            x = -H + (i + 0.5) * m
            hit = bvh.ray_cast(Vector((x, y, 20.0)), down, 40.0)
            g = hit[0].z if hit[0] is not None else -3.0
            dz = water_z - g
            k = j * N + i
            if dz <= 0:
                foam[k], depth[k] = 1.0, 0.0       # dry land: the shader never sees it, but keeps edges foamy
                continue
            foam[k] = max(0.0, 1.0 - dz / 0.55)
            depth[k] = min(1.0, dz / 1.9)
    for (x, y, r) in stamps:                        # soft rings round things standing in the water
        r1 = r + 0.25
        i0, i1 = int((x - r1 + H) / m), int((x + r1 + H) / m) + 1
        j0, j1 = int((H - (y + r1)) / m), int((H - (y - r1)) / m) + 1
        for j in range(max(0, j0), min(N, j1)):
            for i in range(max(0, i0), min(N, i1)):
                qx, qy = -H + (i + 0.5) * m, H - (j + 0.5) * m
                d = math.hypot(qx - x, qy - y)
                if d < r1:
                    k = j * N + i
                    foam[k] = max(foam[k], min(1.0, (r1 - d) / 0.25) * 0.85)
    img = bpy.data.images.new("water_shore", N, N, alpha=False)
    flat = [0.0] * (px * 4)
    for j in range(N):                              # Blender images are bottom-up: row 0 is the south edge
        for i in range(N):
            k, o = j * N + i, ((N - 1 - j) * N + i) * 4
            flat[o], flat[o + 1], flat[o + 2], flat[o + 3] = foam[k], depth[k], 0.0, 1.0
    img.pixels.foreach_set(flat)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def selfcheck():
    """Run on every town export: levels only ever step down, the channel is never pinched shut, and the
    nearest-point lookup lands on the centreline."""
    assert all(a[1] > b[1] and a[0] < b[0] for a, b in zip(STEPS, STEPS[1:])), "levels must step down along s"
    assert STEPS[-1][1] > SEA_LEVEL, "the mouth sits above the sea plane"
    assert min(width(i * 0.5) for i in range(int(LENGTH * 2))) > 0.7, "channel pinched"
    for i in range(0, len(PTS), 37):
        d, s = dist(PTS[i])
        assert d < 1e-6 and abs(s - S[i]) < 1e-6, (i, d, s, S[i])
