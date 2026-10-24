"""Town ground: terrain mesh, path corridors and path ribbons (owned by the ground builder).

town.py wiring (see Art Docs/World Layout Format.md):
    ground.setup(PATHS, base_height=_height_unflattened, stream_d=stream_d, stream_w=STREAM_W,
                 plaza=(PLAZA_C, PLAZA_R), bridges=BRIDGES, island_d=island_d, on_beach=on_beach)
    inside height():          h = ground.flatten(p, h)
    build():                  ground.terrain_mesh(Builder("town_terrain"), height)
                              ground.paths_mesh(Builder("terrain_paths"), PATHS, (PLAZA_C, PLAZA_R))

Why: the old ground was a 1 m grid whose path/sand material was chosen per triangle (saw-tooth edges)
and paths followed height() into the stream banks (tilted slabs). Here the terrain is a 0.5 m grid with
no path material at all (the ribbon covers it), every path corridor is flattened to a smoothed height
profile, and snow variation is a baked shade (COLOR_0) instead of material switches.
"""
import math
import random
from mathutils import Vector
import common
from common import tint

WATER_Z = -0.5
CELL = 0.5
ENV = {}
_PROF = []          # per path: (spline pts, cumulative s, z profile, width)
_HASH = {}          # 2 m cell -> [(path index, seg index)]


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def spline(pts, step=0.3):
    """Catmull-Rom resample of a polyline (ends kept), ~step metres apart."""
    P = [Vector(q) for q in pts]
    if len(P) == 2:
        n = max(1, int((P[1] - P[0]).length / step))
        return [P[0].lerp(P[1], k / n) for k in range(n + 1)]
    E = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(E) - 2):
        p0, p1, p2, p3 = E[i - 1], E[i], E[i + 1], E[i + 2]
        n = max(2, int((p2 - p1).length / step))
        for k in range(n):
            t = k / n
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-1])
    return out


def setup(paths, base_height, stream_d, stream_w, plaza, bridges=(), island_d=None, on_beach=None):
    """Build smoothed height profiles along every path (ignoring the stream carve under bridges)."""
    ENV.update(base=base_height, stream_d=stream_d, stream_w=stream_w, plaza=plaza, bridges=list(bridges),
               island_d=island_d or (lambda p: -10.0), on_beach=on_beach or (lambda p: False))
    _PROF.clear(); _HASH.clear()
    pc, pr = plaza
    pz = base_height(pc)
    for pi, (pts, w) in enumerate(paths):
        line = spline(pts)
        S = [0.0]
        for a, b in zip(line, line[1:]):
            S.append(S[-1] + (b - a).length)
        raw = []
        for q in line:
            if stream_d(q) < stream_w + 1.8:
                raw.append(None)                     # bridge span: interpolate across, never dip
            elif (q - pc).length < pr + 0.3:
                raw.append(pz)
            else:
                raw.append(base_height(q))
        known = [i for i, z in enumerate(raw) if z is not None] or [0]
        if raw[known[0]] is None:
            raw = [0.0] * len(raw)
        for i, z in enumerate(raw):                  # fill gaps linearly
            if z is None:
                lo = max([k for k in known if k < i], default=None)
                hi = min([k for k in known if k > i], default=None)
                if lo is None or hi is None:
                    raw[i] = raw[lo if hi is None else hi]
                else:
                    raw[i] = raw[lo] + (raw[hi] - raw[lo]) * (i - lo) / (hi - lo)
        z = [sum(raw[max(0, i - 4):i + 5]) / len(raw[max(0, i - 4):i + 5]) for i in range(len(raw))]  # ~2.7 m box filter
        z[0], z[-1] = raw[0], raw[-1]                # ends stay exact (stairs feet, plaza mouths, bridge ends)
        _PROF.append((line, S, z, w))
        for si, (a, b) in enumerate(zip(line, line[1:])):
            for gx in range(int(math.floor(min(a.x, b.x) / 2)) - 1, int(math.floor(max(a.x, b.x) / 2)) + 2):
                for gy in range(int(math.floor(min(a.y, b.y) / 2)) - 1, int(math.floor(max(a.y, b.y) / 2)) + 2):
                    _HASH.setdefault((gx, gy), []).append((pi, si))


def path_dist(q, pi, interior=False):
    """Distance from q to path pi's centreline; interior=True ignores points past either end cap."""
    line = _PROF[pi][0]
    best = 1e9
    for si, (a, b) in enumerate(zip(line, line[1:])):
        ab = b - a
        t = (q - a).dot(ab) / max(ab.length_squared, 1e-9)
        if interior and ((si == 0 and t < 0) or (si == len(line) - 2 and t > 1)):
            continue
        t = max(0.0, min(1.0, t))
        best = min(best, (q - (a + ab * t)).length)
    return best


def nearest_path(p, reach=3.0):
    """(distance, path z, half width) of the closest path point, or None beyond reach."""
    best = None
    seen = set()
    cx, cy = int(math.floor(p.x / 2)), int(math.floor(p.y / 2))
    for gx in (cx - 1, cx, cx + 1):
        for gy in (cy - 1, cy, cy + 1):
            for key in _HASH.get((gx, gy), ()):
                if key in seen:
                    continue
                seen.add(key)
                pi, si = key
                line, S, z, w = _PROF[pi]
                a, b = line[si], line[si + 1]
                ab = b - a
                t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
                d = (p - (a + ab * t)).length
                if d < reach and (best is None or d - w * 0.5 < best[0] - best[2]):
                    best = (d, z[si] + (z[si + 1] - z[si]) * t, w * 0.5)
    return best


def path_z(p):
    np_ = nearest_path(p, 0.01 + 50)
    return None if np_ is None else np_[1]


def flatten(p, h):
    """Flatten the terrain under every path corridor (and the plaza) to its smoothed path level.
    Leaves the stream channel alone so bridges still span water."""
    if not ENV:
        return h
    sd = ENV["stream_d"](p)
    if sd < ENV["stream_w"] + 0.9:
        return h
    keep = smoothstep(ENV["stream_w"] + 0.9, ENV["stream_w"] + 2.6, sd)   # banks ease into the channel
    pc, pr = ENV["plaza"]
    dpl = (p - pc).length
    best_w, best_z = 0.0, h
    if dpl < pr + 1.6:
        best_w, best_z = 1 - smoothstep(pr + 0.5, pr + 1.6, dpl), ENV["base"](pc)
    np_ = nearest_path(p)
    if np_:
        d, z, half = np_
        w = 1 - smoothstep(half + 0.6, half + 1.6, d)   # curb + snow lip stay flat too, then ease out
        if w > best_w:
            best_w, best_z = w, z
    best_w *= keep
    return h * (1 - best_w) + best_z * best_w


# ---------------------------------------------------------------------------------- terrain --
def terrain_mesh(b, height_fn, bounds=(-48, 48, -40, 42), seed=11):
    """0.5 m faceted grid. Materials: snow / rock (steep) / sand (beach) / seabed, no path material.
    Snow and rock carry a baked shade (COLOR_0): darker in hollows, on steep and north faces."""
    rng = random.Random(seed)
    b.skip_zfix = True
    X0, X1, Y0, Y1 = bounds
    nx, ny = int((X1 - X0) / CELL), int((Y1 - Y0) / CELL)
    isl, beach = ENV.get("island_d", lambda p: -10.0), ENV.get("on_beach", lambda p: False)
    H, F = {}, {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            p = Vector((X0 + i * CELL, Y0 + j * CELL))
            h = height_fn(p)
            flat = False
            if ENV:
                np_ = nearest_path(p)
                flat = (np_ is not None and np_[0] < np_[2] + 1.6) or (p - ENV["plaza"][0]).length < ENV["plaza"][1] + 1.6
            d = isl(p)
            if flat:
                pass                                     # walk corridors stay exact (no shards through paving)
            elif d < -3.0:
                h += rng.uniform(-0.03, 0.045)           # gentle snow facets
            else:
                h += rng.uniform(-0.15, 0.15)            # rough cliff and sea floor
            H[i, j], F[i, j] = h, flat
    # per-vertex shade from curvature (hollows), slope and facing; plus a soft hand-painted wobble
    shade = {}
    for (i, j), h in H.items():
        nb = [H.get((i + di, j + dj)) for di, dj in ((-2, 0), (2, 0), (0, -2), (0, 2))]
        nb = [v for v in nb if v is not None]
        hollow = max(0.0, (sum(nb) / len(nb) - h) if nb else 0.0)
        gx = (H.get((i + 1, j), h) - H.get((i - 1, j), h)) / (2 * CELL)
        gy = (H.get((i, j + 1), h) - H.get((i, j - 1), h)) / (2 * CELL)
        slope = math.hypot(gx, gy)
        north = max(0.0, -gy) / (1 + slope)              # surface facing +Y (away from the south-east sun)
        s = 1.0 - 0.55 * min(hollow, 0.25) - 0.10 * min(slope, 1.5) - 0.06 * north
        s += 0.025 * math.sin(i * 0.37 + j * 0.21) * math.sin(j * 0.29 - i * 0.13)
        shade[i, j] = max(0.78, min(1.0, s))
    names = {"snow": tint("snow", "#EEF3F7"), "rock": tint("rock", "rock_b"), "sand": tint("sand", "#E8D3A6"),
             "seabed": "water_deep"}
    verts, vid = [], {}
    for (i, j), h in H.items():
        vid[i, j] = len(verts)
        verts.append((X0 + i * CELL, Y0 + j * CELL, h))
    groups = {}
    face_shade = {}
    for i in range(nx):
        for j in range(ny):
            q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            tris = ((q[0], q[1], q[2]), (q[0], q[2], q[3])) if (i + j) % 2 == 0 else ((q[0], q[1], q[3]), (q[1], q[2], q[3]))
            for t in tris:
                vs = [Vector(verts[vid[k]]) for k in t]
                n = (vs[1] - vs[0]).cross(vs[2] - vs[0]).normalized()
                c = sum(vs, Vector()) / 3
                if c.z < WATER_Z - 0.05:
                    m = "seabed"
                elif n.z < 0.74 and not any(F[k] for k in t):
                    m = "rock"
                elif beach(c.xy) and not any(F[k] for k in t):
                    m = "sand"
                else:
                    m = "snow"
                groups.setdefault(m, []).append(t)
    for m, tris in groups.items():
        used = sorted({k for t in tris for k in t})
        remap = {k: n for n, k in enumerate(used)}
        b.mesh([verts[vid[k]] for k in used], [[remap[k] for k in t] for t in tris], mat=names[m])
        for k in used:
            face_shade.setdefault(names[m], {})[(round(verts[vid[k]][0], 3), round(verts[vid[k]][1], 3))] = shade[k]
    _bake_shade_after_tints(b, face_shade)
    return b


def _bake_shade_after_tints(b, table):
    """Builder.apply_tint_families rewrites the shade layer per material family at finish(); write
    our per-vertex shade right after it (keyed by material + vertex xy)."""
    orig = b.apply_tint_families

    def apply():
        orig()
        cl = b.bm.loops.layers.color.get(common.SHADE)
        for f in b.bm.faces:
            tab = table.get(b.mats[f.material_index])
            if not tab:
                continue
            for lp in f.loops:
                s = tab.get((round(lp.vert.co.x, 3), round(lp.vert.co.y, 3)), 1.0)
                lp[cl] = (s, s, s, 1.0)
    b.apply_tint_families = apply


# ------------------------------------------------------------------------------------ paths --
def paths_mesh(b, paths, plaza, height_fn=None, skip_near=()):
    """Walkable ribbons: slab courses following each spline, edge-stone curbs, snow lips, rounded
    junction aprons, and the patterned plaza disc. Heights come from the path profiles, so slabs
    stay level even where the terrain beside them slopes. skip_near: [(centre, axis_deg)] bridge spans."""
    rng = random.Random(12)
    b.skip_zfix = True
    hf = height_fn or ENV["base"]
    pc, pr = plaza
    pz = ENV["base"](pc) if ENV else hf(pc)
    SL = ("paving", "paving_b", "stone")
    quads = {m: ([], []) for m in SL + ("stone_dark", "snow_lip", "joint")}
    bridges = list(skip_near) or ENV.get("bridges", [])

    def quad(m, vs):
        V, Fc = quads[m]
        base = len(V)
        V.extend(vs)
        Fc.append([base, base + 1, base + 2, base + 3])

    def under_bridge(q):
        for c, y in bridges:
            ax = Vector((math.cos(math.radians(y)), math.sin(math.radians(y))))
            if abs((q - c).dot(ax)) < 2.3 and abs((q - c).dot(Vector((-ax.y, ax.x)))) < 2.0:
                return True
        return False

    def covered(q, own):
        """Another walkable surface takes over here (plaza, another path, the stream): no curb."""
        if (q - pc).length < pr + 0.1 or ENV["stream_d"](q) < ENV["stream_w"] + 0.7:
            return True
        return any(path_dist(q, qi) < W2 * 0.5 + 0.7 for qi, (_, _, _, W2) in enumerate(_PROF) if qi != own)

    def owned_by_earlier(q, own):
        return any(path_dist(q, qi, interior=True) < W2 * 0.5 - 0.05 for qi, (_, _, _, W2) in enumerate(_PROF[:own]))

    for pi, (line, S, Z, w) in enumerate(_PROF):
        half = w * 0.5
        cols = max(3, int(round(w / 0.55)))

        def top(k, extra=0.0):
            return Z[k] + 0.07 + extra
        for i in range(len(line) - 1):
            a2, b2 = line[i], line[i + 1]
            d = b2 - a2
            if d.length < 1e-4 or under_bridge((a2 + b2) * 0.5):
                continue
            na = Vector((-d.y, d.x)).normalized()
            nb = na
            if i + 2 < len(line):
                d2 = line[i + 2] - b2
                if d2.length > 1e-4:
                    nb = (na + Vector((-d2.y, d2.x)).normalized()).normalized()
            row = int(S[i] / 0.45)
            quad("joint", [(*(a2 - na * half), top(i) - 0.012), (*(b2 - nb * half), top(i + 1) - 0.012),
                           (*(b2 + nb * half), top(i + 1) - 0.012), (*(a2 + na * half), top(i) - 0.012)])
            for c in range(cols):                    # slab courses, staggered every other row, clipped to the ribbon
                u0 = -half + (w / cols) * c + 0.025
                u1 = -half + (w / cols) * (c + 1) - 0.025
                if row % 2:
                    u0 = max(-half + 0.025, u0 - (w / cols) * 0.5)
                    u1 = min(half - 0.025, u1 - (w / cols) * 0.5) if c < cols - 1 else half - 0.025
                if u1 - u0 < 0.08:
                    continue
                sc = (a2 + b2) * 0.5 + na * ((u0 + u1) * 0.5)
                if (sc - pc).length < pr - 0.02 or owned_by_earlier(sc, pi):
                    continue                         # the plaza / an earlier path already paves here
                m = SL[(row * 7 + c * 3 + rng.randrange(2)) % 3]
                j = rng.uniform(-0.006, 0.008)
                quad(m, [(*(a2 + na * u0), top(i, j)), (*(b2 + nb * u0), top(i + 1, j)),
                         (*(b2 + nb * u1), top(i + 1, j)), (*(a2 + na * u1), top(i, j))])
            for sgn in (1, -1):                      # curbs + snow lips
                ca, cb = a2 + na * sgn * half, b2 + nb * sgn * half
                if covered((ca + cb) * 0.5 + (na + nb) * 0.5 * sgn * 0.2, pi):
                    continue
                xa, xb = ca + na * sgn * 0.18, cb + nb * sgn * 0.18
                la, lb = ca + na * sgn * 0.6, cb + nb * sgn * 0.6
                quad("stone_dark", [(*ca, top(i, 0.08)), (*cb, top(i + 1, 0.08)), (*xb, top(i + 1, 0.08)), (*xa, top(i, 0.08))])
                quad("stone_dark", [(*ca, top(i) - 0.01), (*cb, top(i + 1) - 0.01), (*cb, top(i + 1, 0.08)), (*ca, top(i, 0.08))])
                quad("snow_lip", [(*xa, top(i, 0.1)), (*xb, top(i + 1, 0.1)), (*lb, hf(lb) - 0.02), (*la, hf(la) - 0.02)])
        for k_end, end in ((0, line[0]), (len(line) - 1, line[-1])):   # rounded aprons at junctions
            if (end - pc).length > pr and any(
                    path_dist(end, qi) < W2 * 0.5 + 0.3 for qi, (_, _, _, W2) in enumerate(_PROF) if qi != pi):
                n = 16
                r = half + 0.35
                ring = [end + Vector((math.cos(2 * math.pi * k / n), math.sin(2 * math.pi * k / n))) * r for k in range(n)]
                zt = top(k_end) - 0.004
                for k in range(n):
                    q0, q1 = ring[k], ring[(k + 1) % n]
                    quad(SL[k % 3], [(*end, zt), (*q0, zt), (*q1, zt), (*end, zt)])
    # plaza: darker fountain ring (r 3.2), radial courses, contrasting rim band, curb with snow lip
    zt = pz + 0.07
    rings = [1.6, 2.2, 2.7, 3.2]
    r = 3.2
    while r < pr - 0.6:
        r = min(r + 0.5, pr - 0.6)
        rings.append(r)
    rings.append(pr - 0.05)
    for ri, (r0, r1) in enumerate(zip(rings, rings[1:])):
        n = max(12, int(2 * math.pi * r1 / 0.5))
        twist = 0.5 * (ri % 2)
        for k in range(n):
            a0, a1 = 2 * math.pi * (k + twist) / n, 2 * math.pi * (k + 1 + twist) / n
            g = 0.012
            p4 = [pc + Vector((math.cos(a0 + g / r0), math.sin(a0 + g / r0))) * (r0 + g),
                  pc + Vector((math.cos(a1 - g / r0), math.sin(a1 - g / r0))) * (r0 + g),
                  pc + Vector((math.cos(a1 - g / r1), math.sin(a1 - g / r1))) * (r1 - g),
                  pc + Vector((math.cos(a0 + g / r1), math.sin(a0 + g / r1))) * (r1 - g)]
            m = ("stone_dark" if (k + ri) % 2 else "stone") if r1 <= 3.2 else ("stone_dark" if r0 >= pr - 0.65 else SL[(k * 5 + ri * 3) % 3])
            j = rng.uniform(-0.005, 0.006)
            quad(m, [(*q, zt + j) for q in p4[::-1]])
    n = 64
    for k in range(n):
        q0 = pc + Vector((math.cos(2 * math.pi * k / n), math.sin(2 * math.pi * k / n))) * pr
        q1 = pc + Vector((math.cos(2 * math.pi * (k + 1) / n), math.sin(2 * math.pi * (k + 1) / n))) * pr
        quad("joint", [(*pc, zt - 0.012), (*q1, zt - 0.012), (*q0, zt - 0.012), (*pc, zt - 0.012)])
    n = 120
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        mid = pc + Vector((math.cos((a0 + a1) / 2), math.sin((a0 + a1) / 2))) * (pr + 0.3)
        if any(min((mid - a).length for a in L2[::2]) < W2 * 0.5 + 0.1 for L2, _, _, W2 in _PROF):
            continue
        c0, c1 = [pc + Vector((math.cos(a), math.sin(a))) * pr for a in (a0, a1)]
        x0, x1 = [pc + Vector((math.cos(a), math.sin(a))) * (pr + 0.2) for a in (a0, a1)]
        l0, l1 = [pc + Vector((math.cos(a), math.sin(a))) * (pr + 0.6) for a in (a0, a1)]
        quad("stone_dark", [(*c1, zt + 0.1), (*c0, zt + 0.1), (*x0, zt + 0.1), (*x1, zt + 0.1)])
        quad("snow_lip", [(*x1, zt + 0.12), (*x0, zt + 0.12), (*l0, hf(l0) - 0.02), (*l1, hf(l1) - 0.02)])
    mats = {"snow_lip": tint("snow", "#EEF3F7"), "joint": "stone_grey"}
    for m, (V, Fc) in quads.items():
        if Fc:
            b.mesh(V, Fc, mat=mats.get(m, m))
    return b


def selfcheck():
    """Path profiles never dip into the stream; flatten is exact on path centrelines."""
    for line, S, z, w in _PROF:
        assert min(z) > -0.6, "path profile dips under water"
        for k in range(0, len(line), max(1, len(line) // 5)):
            q = line[k]
            if ENV["stream_d"](q) < ENV["stream_w"] + 0.9:
                continue
            got = flatten(q, ENV["base"](q))
            assert abs(got - z[k]) < 0.02, (q, got, z[k])
    return True
