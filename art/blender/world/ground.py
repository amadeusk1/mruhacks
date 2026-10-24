"""Ground: terrain mesh and path/plaza ribbons for the town (owned by the ground builder).
Seam used by town.py:
  terrain_mesh(Builder, height_fn) -> Builder   faceted terrain (snow/rock/sand/seabed materials)
  paths_mesh(Builder, PATHS, plaza) -> Builder  path ribbons with curbs + snow lips, junction aprons, patterned plaza
  flatten(p, h) -> h                           path-corridor flattening hook (town.height calls it last)
town.py keeps PATHS and the height data; these functions read the rest from the town module.
"""
import math, random
from mathutils import Vector
from common import tint


def flatten(p, h):
    """Hook for flattening path corridors; currently a pass-through."""
    return h


def terrain_mesh(Builder, height_fn):
    import town as T
    return _terrain(T, Builder)


def paths_mesh(Builder, PATHS, plaza):
    import town as T
    return _paths(T, Builder, PATHS)


def _terrain(T, Builder):
    """Faceted grid. Flat walk areas stay exact; snow and rock get jitter."""
    b = Builder("town_terrain", seed=11)
    b.skip_zfix = True
    X0, X1, Y0, Y1, S = -48, 48, -40, 42, 1.0
    nx, ny = int((X1 - X0) / S), int((Y1 - Y0) / S)
    H = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            p = Vector((X0 + i * S, Y0 + j * S))
            h = T.height(p)
            if T.island_d(p) < -3.5 and not T.on_path(p) and not T.sled_hill.blocks(p, 1.0) and T.stream_d(p) > T.STREAM_W + 1.5 and T.pad_w(p)[0] == 0:
                h += T.RNG.uniform(-0.06, 0.09)            # soft snow facets
            elif T.island_d(p) >= -3.5:
                h += T.RNG.uniform(-0.25, 0.25)            # rough cliff and sea floor
            H[i, j] = h
    verts, faces, fmats = [], [], []
    vid = {}
    for (i, j), h in H.items():
        vid[i, j] = len(verts)
        verts.append((X0 + i * S, Y0 + j * S, h))
    groups = {}
    for i in range(nx):
        for j in range(ny):
            q = [vid[i, j], vid[i + 1, j], vid[i + 1, j + 1], vid[i, j + 1]]
            tris = ([q[0], q[1], q[2]], [q[0], q[2], q[3]]) if (i + j) % 2 == 0 else ([q[0], q[1], q[3]], [q[1], q[2], q[3]])
            for t in tris:
                vs = [Vector(verts[k]) for k in t]
                n = (vs[1] - vs[0]).cross(vs[2] - vs[0]).normalized()
                c = sum(vs, Vector()) / 3
                p2 = c.xy
                if c.z < T.WATER_Z - 0.05:
                    m = "seabed"
                elif n.z < 0.72:
                    m = "rock"
                elif T.on_path(p2):
                    m = "joint"
                elif T.on_beach(p2):
                    m = "sand"
                else:
                    m = "snow"
                groups.setdefault(m, []).append(t)
    names = {"snow": tint("snow", "#E8EFF4"), "rock": tint("rock", "rock_b"), "joint": "paving_b",
             "sand": tint("sand", "#E8D3A6"), "seabed": "water_deep"}
    for m, tris in groups.items():
        used = sorted({k for t in tris for k in t})
        remap = {k: n for n, k in enumerate(used)}
        b.mesh([verts[k] for k in used], [[remap[k] for k in t] for t in tris], mat=names[m])
    return b



def _spline(pts, step=0.3):
    """Catmull-Rom resample of a polyline (ends kept), ~step metres apart."""
    P = [Vector(q) for q in pts]
    if len(P) == 2:
        L = (P[1] - P[0]).length
        n = max(1, int(L / step))
        return [P[0].lerp(P[1], k / n) for k in range(n + 1)]
    E = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(E) - 2):
        p0, p1, p2, p3 = E[i - 1], E[i], E[i + 1], E[i + 2]
        n = max(2, int((p2 - p1).length / step))
        for k in range(n):
            t = k / n
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-1])
    return out


def _covered_by_other(T, PATHS, p, own):
    """True where p already lies on the plaza, another path, a bridge landing or the stream (curbs stop there)."""
    if (p - T.PLAZA_C).length < T.PLAZA_R + 0.1 or T.stream_d(p) < T.STREAM_W + 0.7:
        return True
    if any((p - c).length < 1.4 for c, _ in T.BRIDGE_LANDINGS):
        return True
    return any(T.poly_dist(p, pts) < w * 0.5 - 0.05 for pts, w in PATHS if pts is not own)


def _paths(T, Builder, PATHS):
    """Paths as smooth ribbon meshes: slab courses following the curve, edge-stone curbs, snow lips,
    rounded junction aprons; plus the patterned plaza disc. One walkable mesh (terrain_paths)."""
    b = Builder("terrain_paths", seed=12)
    b.skip_zfix = True
    rng = random.Random(12)
    SL = ("paving", "paving_b", "stone")
    quads = {m: ([], []) for m in SL + ("stone_dark", "snow_lip", "joint")}

    def quad(m, vs):
        V, F = quads[m]
        base = len(V)
        V.extend(vs)
        F.append([base, base + 1, base + 2, base + 3])

    def top(p, extra=0.0):
        return T.height(p) + 0.07 + extra
    for pts, w in PATHS:
        line = _spline(pts)
        S = [0.0]
        for a2, b2 in zip(line, line[1:]):
            S.append(S[-1] + (b2 - a2).length)
        half = w * 0.5
        cols = max(3, int(round(w / 0.55)))
        for i in range(len(line) - 1):
            a2, b2 = line[i], line[i + 1]
            d = (b2 - a2)
            if d.length < 1e-4:
                continue
            mid = (a2 + b2) * 0.5
            if any(abs((mid - c).dot(Vector((math.cos(math.radians(y)), math.sin(math.radians(y)))))) < 2.3 and
                   (mid - c).length < 2.6 for c, y in T.BRIDGES):
                continue                                  # under the footbridge deck: no paving in the channel
            na = Vector((-d.y, d.x)).normalized()
            nb = na
            if i + 2 < len(line):
                d2 = line[i + 2] - b2
                nb = (Vector((-d.y, d.x)).normalized() + Vector((-d2.y, d2.x)).normalized()).normalized()
            row = int(S[i] / 0.45)
            # joint bed under the slabs (fills the gaps)
            quad("joint", [(*(a2 - na * half), top(a2) - 0.012), (*(b2 - nb * half), top(b2) - 0.012),
                           (*(b2 + nb * half), top(b2) - 0.012), (*(a2 + na * half), top(a2) - 0.012)])
            # slabs: courses staggered every other row, small inset gaps
            off = 0.5 if row % 2 else 0.0
            for c in range(cols):
                u0 = -half + (c + off * (c > 0) * 0) * 0 + (w / cols) * c + 0.025
                u1 = -half + (w / cols) * (c + 1) - 0.025
                if row % 2 and c == 0:
                    u1 = -half + (w / cols) * 0.5 - 0.025
                m = SL[(row * 7 + c * 3 + rng.randrange(2)) % 3]
                quad(m, [(*(a2 + na * u0), top(a2)), (*(b2 + nb * u0), top(b2)),
                         (*(b2 + nb * u1), top(b2)), (*(a2 + na * u1), top(a2))])
            # curbs + snow lips, except where another surface takes over
            for sgn in (1, -1):
                ca, cb = a2 + na * sgn * half, b2 + nb * sgn * half
                mid = (ca + cb) * 0.5 + (na + nb) * 0.5 * sgn * 0.2
                if _covered_by_other(T, PATHS, mid, pts):
                    continue
                o1, o2, o3 = 0.18, 0.18 + 0.35, 0.18 + 0.35
                ia, ib = ca, cb
                xa, xb = ca + na * sgn * o1, cb + nb * sgn * o1
                quad("stone_dark", [(*ia, top(a2, 0.09)), (*ib, top(b2, 0.09)), (*xb, top(b2, 0.09)), (*xa, top(a2, 0.09))])
                quad("stone_dark", [(*ia, top(a2) - 0.01), (*ib, top(b2) - 0.01), (*ib, top(b2, 0.09)), (*ia, top(a2, 0.09))])
                la, lb = ca + na * sgn * o2, cb + nb * sgn * o2
                quad("snow_lip", [(*xa, top(a2, 0.11)), (*xb, top(b2, 0.11)), (*lb, T.height(lb) - 0.02), (*la, T.height(la) - 0.02)])
        # rounded junction aprons where a path meets another path
        for end in (line[0], line[-1]):
            if any(T.poly_dist(end, p2) < w2 * 0.5 + 0.3 for p2, w2 in PATHS if p2 is not pts) and (end - T.PLAZA_C).length > T.PLAZA_R:
                n = 16
                r = half + 0.35
                ring = [end + Vector((math.cos(2 * math.pi * k / n), math.sin(2 * math.pi * k / n))) * r for k in range(n)]
                for k in range(n):
                    q0, q1 = ring[k], ring[(k + 1) % n]
                    quad(SL[k % 3], [(*end, top(end) - 0.004), (*q0, top(q0) - 0.004), (*q1, top(q1) - 0.004), (*end, top(end) - 0.004)])
    # plaza: inner fountain ring in darker stone, radial courses, contrasting rim band
    rings = [1.6, 2.2, 2.7, 3.2]
    r = 3.2
    while r < T.PLAZA_R - 0.6:
        r += 0.5
        rings.append(min(r, T.PLAZA_R - 0.6))
    rings.append(T.PLAZA_R - 0.05)
    for ri, (r0, r1) in enumerate(zip(rings, rings[1:])):
        n = max(12, int(2 * math.pi * r1 / 0.5))
        twist = 0.5 * (ri % 2)
        for k in range(n):
            a0, a1 = 2 * math.pi * (k + twist) / n, 2 * math.pi * (k + 1 + twist) / n
            g = 0.012
            pts4 = [T.PLAZA_C + Vector((math.cos(a0 + g / r0), math.sin(a0 + g / r0))) * (r0 + g),
                    T.PLAZA_C + Vector((math.cos(a1 - g / r0), math.sin(a1 - g / r0))) * (r0 + g),
                    T.PLAZA_C + Vector((math.cos(a1 - g / r1), math.sin(a1 - g / r1))) * (r1 - g),
                    T.PLAZA_C + Vector((math.cos(a0 + g / r1), math.sin(a0 + g / r1))) * (r1 - g)]
            if r1 <= 3.2:
                m = "stone_dark" if (k + ri) % 2 else "stone"
            elif r0 >= T.PLAZA_R - 0.65:
                m = "stone_dark"
            else:
                m = SL[(k * 5 + ri * 3) % 3]
            quad(m, [(*q, top(q)) for q in pts4[::-1]])
    # plaza joint bed
    n = 64
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        q0 = T.PLAZA_C + Vector((math.cos(a0), math.sin(a0))) * T.PLAZA_R
        q1 = T.PLAZA_C + Vector((math.cos(a1), math.sin(a1))) * T.PLAZA_R
        quad("joint", [(*T.PLAZA_C, top(T.PLAZA_C) - 0.012), (*q1, top(q1) - 0.012), (*q0, top(q0) - 0.012), (*T.PLAZA_C, top(T.PLAZA_C) - 0.012)])
    # plaza rim curb with a snow lip, open at the path mouths
    n = 120
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        mid = T.PLAZA_C + Vector((math.cos((a0 + a1) / 2), math.sin((a0 + a1) / 2))) * (T.PLAZA_R + 0.3)
        if any(T.poly_dist(mid, p2) < w2 * 0.5 + 0.1 for p2, w2 in PATHS):
            continue
        c0, c1 = [T.PLAZA_C + Vector((math.cos(a), math.sin(a))) * T.PLAZA_R for a in (a0, a1)]
        x0, x1 = [T.PLAZA_C + Vector((math.cos(a), math.sin(a))) * (T.PLAZA_R + 0.2) for a in (a0, a1)]
        l0, l1 = [T.PLAZA_C + Vector((math.cos(a), math.sin(a))) * (T.PLAZA_R + 0.6) for a in (a0, a1)]
        quad("stone_dark", [(*c1, top(c1, 0.1)), (*c0, top(c0, 0.1)), (*x0, top(x0, 0.1)), (*x1, top(x1, 0.1))])
        quad("snow_lip", [(*x1, top(x1, 0.12)), (*x0, top(x0, 0.12)), (*l0, T.height(l0) - 0.02), (*l1, T.height(l1) - 0.02)])
    mats = {"snow_lip": tint("snow", "#EEF4F7"), "joint": "stone_grey"}
    for m, (V, F) in quads.items():
        if F:
            b.mesh(V, F, mat=mats.get(m, m))
    return b


