"""Casino: building (exterior + interior shell), roulette, slots, poker, blackjack, cards, chips,
the chip-window booth and shared decor. Concepts: Images/Casino - *.png; requirements: vault note
"Casino - Asset and Animation Checklist". Front faces -Y, origin at ground centre, 0.9 m penguin
scale (seats at 0.42 m).

Graphic faces are blank `insert_*` materials with planar (or cylindrical, for slot reels) UVs so the
engine can map authored textures: generated numerals and logos on the sheets are not final.
"""
from common import *
from kits.buildings import T, WALL_T, ROOF_T, masonry_wall, window_unit, tiled_gable, entry_steps, attach

KIT = "casino"
PREVIEW_WIDTH = 16.0

PALETTE.update({
    "insert_felt": ("#1F6B66", 0.95, 0), "insert_rotor": ("#7A2A24", 0.6, 0), "insert_reels": ("#F5EEDD", 0.7, 0),
    "insert_card_face": ("#FBF8F1", 0.7, 0), "insert_button": ("#F5EEDD", 0.7, 0), "insert_suits": ("#F5EEDD", 0.7, 0),
    "insert_mat": ("#1F6B66", 0.95, 0), "insert_carpet": ("#C9963E", 0.9, 0), "card_back": ("#C8443A", 0.7, 0), "card_edge": ("#F4EFE6", 0.8, 0),
    "felt_dark": ("#174F4C", 0.95, 0), "walnut": ("#6B4227", 0.8, 0), "walnut_b": ("#5A361F", 0.8, 0),
    "carpet_red": ("#8E3B2E", 0.95, 0), "carpet_gold": ("#C9963E", 0.9, 0),
})
FELT = tint("felt", "#1F6B66")
RAIL = tint("rail", "#225C63")
UPH = tint("upholstery", "coral")
CUSH = tint("cushion", "#2F7F86")
TRIM = tint("trim", "#2F7F86")
CHIP = tint("chip", "red")
CHIP_VARIANTS = {"1": "#D9473B", "5": "#3D7BD9", "10": "#3E9A5B", "25": "#7B4FC4", "100": "#F4EFE6"}
SLOT_VARIANTS = {"coral": "#E86D58", "teal": "#207D85", "plum": "#7A3A6B"}
SEAT_Z = 0.42
TABLE_Z = 0.64          # felt height: a seated penguin's flippers reach the rail
BRASS = "gold"


# ------------------------------------------------------------------------ helpers --
def planar_uv(obj, prefix="insert_", cyl=False):
    """UVs for insert faces (0..1 over each insert material's extent) so the engine can texture them.
    cyl=True wraps around local X (slot reels). Applies to obj and every mesh child (parts)."""
    for ob in hierarchy(obj):
        if ob.type != "MESH":
            continue
        me = ob.data
        if not me.uv_layers:
            me.uv_layers.new(name="UVMap")
        uv = me.uv_layers[0].data
        by_mat = {}
        for poly in me.polygons:
            m = me.materials[poly.material_index]
            if m and m.name.startswith(prefix):
                by_mat.setdefault(m.name, []).append(poly)
        for polys in by_mat.values():
            vs = [me.vertices[i].co for p in polys for i in p.vertices]
            n = sum((p.normal for p in polys), Vector())
            ax = max(range(3), key=lambda i: abs(n[i]))
            u_ax, v_ax = [(1, 2), (0, 2), (0, 1)][ax]
            lo = [min(v[i] for v in vs) for i in range(3)]
            hi = [max(v[i] for v in vs) for i in range(3)]
            for p in polys:
                for li in p.loop_indices:
                    co = me.vertices[me.loops[li].vertex_index].co
                    if cyl:
                        a = math.atan2(co.z, co.y)
                        uv[li].uv = ((a / (2 * math.pi)) % 1.0, (co.x - lo[0]) / max(hi[0] - lo[0], 1e-6))
                    else:
                        su = (co[u_ax] - lo[u_ax]) / max(hi[u_ax] - lo[u_ax], 1e-6)
                        sv = (co[v_ax] - lo[v_ax]) / max(hi[v_ax] - lo[v_ax], 1e-6)
                        if ax == 1 and n[1] > 0:          # back-facing plane: mirror so it reads correctly
                            su = 1 - su
                        uv[li].uv = (su, sv)


def stadium(w, d, n=10):
    """Outline (x, y) of a rounded-end oval w x d, ends along X."""
    r = d / 2
    cx = w / 2 - r
    pts = []
    for k in range(n + 1):
        a = -math.pi / 2 + math.pi * k / n
        pts.append((cx + r * math.cos(a), r * math.sin(a)))
    for k in range(n + 1):
        a = math.pi / 2 + math.pi * k / n
        pts.append((-cx + r * math.cos(a), r * math.sin(a)))
    return pts


def half_disc(r, n=16, back=0.0):
    """Blackjack outline: semicircle toward -Y with a flat dealer edge at y = back."""
    pts = [(r * math.cos(math.pi + math.pi * k / n), back + r * math.sin(math.pi + math.pi * k / n)) for k in range(n + 1)]
    return pts


def offset(pts, d):
    """Offset a closed convex outline outward by d (vertex-normal approximation)."""
    out = []
    n = len(pts)
    for i in range(n):
        p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
        e0 = (p1 - p0).normalized(); e1 = (p2 - p1).normalized()
        nrm = (Vector((e0.y, -e0.x)) + Vector((e1.y, -e1.x)))
        nrm = nrm.normalized() if nrm.length > 1e-6 else Vector((e1.y, -e1.x))
        out.append(tuple(p1 + nrm * d))
    return out


def ccw(pts):
    a = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    return pts if a > 0 else pts[::-1]


def slab(b, pts, z, h, mat, bevel=0.0):
    b.prism(ccw(pts), h, z=z, mat=mat, plane="xy", bevel=bevel)


def rail_ring(b, pts, z, w=0.13, h=0.09, mat=RAIL, closed=True, studs=0):
    """Padded rail: chunky segments along an outline, brass studs every `studs` segments."""
    pts = ccw(pts)
    n = len(pts) if closed else len(pts) - 1
    for i in range(n):
        a, c = Vector(pts[i]), Vector(pts[(i + 1) % len(pts)])
        d = c - a
        m = (a + c) / 2
        b.box(d.length + w * 0.55, w, h, m.x, m.y, z, mat, bevel=0.035, rot=(0, 0, math.degrees(math.atan2(d.y, d.x))))
        if studs and i % studs == 0:
            b.box(0.05, w + 0.02, h + 0.02, a.x, a.y, z - 0.01, BRASS, bevel=0.01, rot=(0, 0, math.degrees(math.atan2(d.y, d.x))))


def stool(b, x=0, y=0, h=SEAT_Z, r=0.17, top=CUSH):
    """Roulette/slot stool: walnut post, brass foot ring, padded cushion."""
    b.cyl(r * 0.9, 0.05, x, y, 0, "walnut_b", segs=10, bevel=0.012)
    b.cyl(0.06, h - 0.1, x, y, 0.05, "walnut", segs=8)
    b.torus(r * 0.7, 0.014, x, y, 0.16, BRASS, segs=12, ring=5)
    b.cyl(r * 0.85, 0.04, x, y, h - 0.12, BRASS, segs=12, bevel=0.008)
    b.cyl(r, 0.09, x, y, h - 0.08, top, segs=12, bevel=0.03)


def chair(b, x=0, y=0, yaw=0.0):
    """Poker/blackjack chair: walnut frame, coral seat and back, brass foot ring. Faces -Y locally."""
    with b.at((x, y, 0), rotz=yaw):
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.box(0.045, 0.045, SEAT_Z - 0.05, sx * 0.15, sy * 0.15, 0, "walnut", bevel=0.01)
        for sx in (-1, 1):
            b.box(0.02, 0.32, 0.02, sx * 0.15, 0, 0.14, BRASS, bevel=0)
        b.box(0.38, 0.38, 0.05, 0, 0, SEAT_Z - 0.09, "walnut_b", bevel=0.015)
        b.box(0.36, 0.36, 0.07, 0, 0, SEAT_Z - 0.06, UPH, bevel=0.03)
        for sx in (-1, 1):
            b.box(0.045, 0.045, 0.42, sx * 0.15, 0.17, SEAT_Z - 0.05, "walnut", bevel=0.01)
        b.box(0.34, 0.06, 0.24, 0, 0.18, SEAT_Z + 0.12, UPH, bevel=0.03)
        b.box(0.36, 0.05, 0.05, 0, 0.18, SEAT_Z + 0.36, "walnut", bevel=0.015)
        b.prism([(-0.035, 0), (0, 0.05), (0.035, 0), (0, -0.05)], 0.012, 0, 0.215, SEAT_Z + 0.24, BRASS)


def diamond(b, x, y, z, s=0.06, mat=BRASS, rotz=0.0):
    """Little lozenge ornament on a face whose normal is -Y (in the current frame)."""
    with b.at((x, y, z), rotz=rotz):
        b.prism([(-s * 0.6, 0), (0, s), (s * 0.6, 0), (0, -s)], 0.02, mat=mat)


def cup_holder(b, x, y, z):
    b.cyl(0.055, 0.03, x, y, z, BRASS, segs=10, bevel=0.006)
    b.cyl(0.04, 0.012, x, y, z + 0.022, "black", segs=10)


# --------------------------------------------------------------------- roulette ---
WHEEL_R = 0.42


def roulette_wheel(b, x, y, z):
    """Static walnut bowl with a stone band; the rotor (with turret) is a spin part."""
    b.cyl(WHEEL_R, 0.11, x, y, z, "walnut", segs=28, bevel=0.02)
    b.cyl(WHEEL_R * 1.02, 0.05, x, y, z + 0.01, "stone", segs=28, bevel=0.01)
    b.cyl(WHEEL_R * 0.92, 0.03, x, y, z + 0.11, "walnut", segs=28, bevel=0.008)        # raised rim
    b.cyl(WHEEL_R * 0.8, 0.012, x, y, z + 0.112, "walnut_b", segs=28)                 # ball track (dark ring)
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        diamond(b, x + math.cos(a) * WHEEL_R * 1.03, y + math.sin(a) * WHEEL_R * 1.03, z + 0.035, 0.03,
                rotz=math.degrees(a) + 90)
    with b.part("rotor", pivot=(x, y, z + 0.125), motion="spin", axis="z"):
        b.cyl(WHEEL_R * 0.7, 0.03, x, y, z + 0.125, "walnut", segs=28, bevel=0.006)
        b.cyl(WHEEL_R * 0.66, 0.006, x, y, z + 0.155, "insert_rotor", segs=37)            # numbered ring texture
        b.cyl(WHEEL_R * 0.34, 0.014, x, y, z + 0.158, "walnut_b", segs=20, bevel=0.004)
        b.cyl(0.05, 0.05, x, y, z + 0.17, BRASS, segs=10, r2=0.03)
        b.cyl(0.014, 0.08, x, y, z + 0.21, BRASS, segs=6)
        b.sphere(0.024, x, y, z + 0.3, BRASS, u=8, v=6)
        for k in range(4):
            a = math.radians(90 * k)
            b.box(0.11, 0.016, 0.016, x + math.cos(a) * 0.055, y + math.sin(a) * 0.055, z + 0.23, BRASS,
                  bevel=0.004, rot=(0, 0, 90 * k))
            b.sphere(0.014, x + math.cos(a) * 0.11, y + math.sin(a) * 0.11, z + 0.24, BRASS, u=6, v=4)
    b.socket("wheel_center", (x, y, z + 0.158))
    b.socket("ball_track", (x + WHEEL_R * 0.76, y, z + 0.124))


def roulette_base(b, w=2.5, d=1.25):
    """Cream stone base with walnut plinth and coral/teal pennant panels."""
    b.box(w + 0.1, d + 0.1, 0.12, 0, 0, 0, "stone_dark", bevel=0.04)
    b.box(w, d, TABLE_Z - 0.2, 0, 0, 0.12, "stone", bevel=0.05)
    for i, xx in enumerate((-1.2, 0.0, 1.2)):
        b.box(0.32, 0.03, 0.3, xx, -d / 2 - 0.015, 0.18, TRIM, bevel=0.01)
        b.prism([(-0.16, 0.3), (0.16, 0.3), (0.0, 0.05)], 0.03, xx, -d / 2 - 0.035, 0.18, "coral")
        diamond(b, xx, -d / 2 - 0.05, 0.38, 0.05)


def roulette_table():
    b = Builder("roulette_table", seed=901)
    w, d = 3.6, 1.3                                   # 4 seats at 1.15 m pitch (Interior Spacing Standard)
    roulette_base(b, w, d)
    top = stadium(w + 0.25, d + 0.25, 10)
    slab(b, top, TABLE_Z - 0.1, 0.06, "walnut", bevel=0.015)
    slab(b, offset(top, -0.13), TABLE_Z - 0.05, 0.05, FELT)
    rail_ring(b, offset(top, -0.04), TABLE_Z - 0.04, studs=5)
    # felt betting layout insert (authored texture), right of the wheel
    b.box(2.0, 0.8, 0.006, 0.55, 0.0, TABLE_Z, "insert_felt", bevel=0)
    b.socket("bet_surface", (0.55, 0.0, TABLE_Z + 0.006))
    roulette_wheel(b, -1.2, 0.0, TABLE_Z - 0.04)
    # brass chip rack at the back rail, table marker
    with b.at((0.8, d / 2 + 0.02, TABLE_Z)):
        chip_rack_geo(b)
    b.cyl(0.03, 0.02, -0.4, 0.28, TABLE_Z, BRASS, segs=8)
    b.cyl(0.012, 0.06, -0.4, 0.28, TABLE_Z + 0.02, BRASS, segs=6)
    b.sphere(0.02, -0.4, 0.28, TABLE_Z + 0.09, BRASS, u=6, v=4)
    for i, sx in enumerate((-1.74, -0.58, 0.58, 1.74)):   # four stools along the front, 1.16 m apart
        stool(b, sx, -d / 2 - 0.42)
        b.socket(f"seat_{i}", (sx, -d / 2 - 0.42, SEAT_Z), rotz=180)   # sockets face where the bird looks (+Y = table)
    for i, (sx, sy) in enumerate(((-2.6, -0.2), (2.6, -0.2))):
        b.socket(f"spectator_{i}", (sx, sy, 0), rotz=90 if sx < 0 else -90)
    o = b.finish(KIT, "furniture", {"game": "roulette", "seats": 4, "felt_insert": "insert_felt",
                                    "rotor_insert": "insert_rotor", "notes": "single-zero layout authored as texture"})
    planar_uv(o)
    return o


def chip_rack_geo(b, n=6):
    """Walnut tray with brass ends holding chip rolls lying along Y."""
    w = 0.09 * n + 0.06
    b.box(w, 0.16, 0.03, 0, 0, 0, "walnut", bevel=0.01)
    for s in (-1, 1):
        b.box(w, 0.02, 0.07, 0, s * 0.07, 0, "walnut_b", bevel=0.006)
        b.box(0.02, 0.16, 0.08, s * (w / 2), 0, 0, BRASS, bevel=0.006)
    cols = ("red", "blue", "blue", "green", "cream", "cream")
    for i in range(n):
        b.cyl(0.035, 0.13, -w / 2 + 0.06 + i * 0.09, 0, 0.065, pick(cols, i), segs=10, rot=(90, 0, 0), center=True)


def roulette_ball():
    b = Builder("roulette_ball", seed=902)
    b.sphere(0.018, 0, 0, 0.018, "white", u=10, v=8)
    return b.finish(KIT, "prop", {"origin": "centre-bottom; engine drives its orbit toward the server result"})


def roulette_marker():
    b = Builder("table_marker", seed=903)
    b.cyl(0.035, 0.02, 0, 0, 0, BRASS, segs=10, bevel=0.005)
    b.cyl(0.014, 0.07, 0, 0, 0.02, BRASS, segs=8)
    b.cyl(0.03, 0.05, 0, 0, 0.09, BRASS, segs=8, r2=0.0)
    return b.finish(KIT, "prop", placement("surface"))


# ------------------------------------------------------------------------- slots ---
def slot_machine(name="slot_machine", body="coral"):
    b = Builder(name, seed=911)
    BODY = tint("body", body)
    W, D, H = 0.74, 0.56, 1.3
    # walnut plinth, cream stone sides, tinted front
    b.box(W + 0.08, D + 0.08, 0.1, 0, 0, 0, "walnut", bevel=0.02)
    for s in (-1, 1):
        b.box(0.12, D, H - 0.1, s * (W / 2 - 0.06), 0, 0.1, "stone", bevel=0.04)
    wz, wh, ww = 0.84, 0.32, W - 0.2
    fy = -D / 2 + 0.05                                            # front face of the tinted body
    b.box(W - 0.22, D - 0.3, H - 0.1, 0, 0.15, 0.1, BODY, bevel=0.03)               # rear core behind the reels
    b.box(W - 0.22, 0.25, wz - 0.1 - 0.04, 0, fy + 0.125, 0.1, BODY, bevel=0.03)     # front below the window
    b.box(W - 0.22, 0.25, H - (wz + wh + 0.04), 0, fy + 0.125, wz + wh + 0.04, BODY, bevel=0.03)  # front above
    # lower cabinet door with brass trim
    b.box(W - 0.28, 0.03, 0.42, 0, fy - 0.01, 0.14, BODY, bevel=0.012)
    b.box(W - 0.34, 0.02, 0.32, 0, fy - 0.025, 0.19, "walnut", bevel=0.01)
    diamond(b, 0, fy - 0.04, 0.35, 0.05)
    # control deck: angled shelf in front of the window, spin button part and two lamp buttons
    deck_z = 0.66
    b.box(W - 0.06, 0.3, 0.07, 0, fy - 0.1, deck_z, TRIM, bevel=0.02, rot=(-12, 0, 0))
    b.box(W - 0.06, 0.04, 0.09, 0, fy - 0.25, deck_z - 0.04, BRASS, bevel=0.01)
    with b.part("button", pivot=(0, fy - 0.1, deck_z + 0.09), motion="press", depth=0.012, dir=[0, 0.21, -0.98]):
        b.cyl(0.055, 0.035, 0, fy - 0.1, deck_z + 0.075, "red", segs=12, bevel=0.012, rot=(-12, 0, 0))
    b.cyl(0.068, 0.02, 0, fy - 0.1, deck_z + 0.065, BRASS, segs=12, rot=(-12, 0, 0))
    for sx in (-0.21, 0.21):
        b.cyl(0.022, 0.02, sx, fy - 0.12, deck_z + 0.07, "bulb", segs=8, rot=(-12, 0, 0))
    # reel window: brass bezel; three reel drums spin about X inside the open well
    b.box(ww + 0.1, 0.07, 0.05, 0, fy - 0.01, wz - 0.05, BRASS, bevel=0.012)
    b.box(ww + 0.1, 0.07, 0.05, 0, fy - 0.01, wz + wh, BRASS, bevel=0.012)
    for sx in (-1, 1):
        b.box(0.05, 0.07, wh + 0.1, sx * (ww / 2 + 0.025), fy - 0.01, wz - 0.05, BRASS, bevel=0.012)
        b.box(0.11, 0.26, wh + 0.08, sx * (ww / 2 + 0.03), fy + 0.12, wz - 0.04, BODY, bevel=0.01)   # window cheeks
    b.box(ww, 0.05, wh + 0.08, 0, fy + 0.27, wz - 0.04, "black", bevel=0)                          # dark back of the well
    rw = (ww - 0.04) / 3
    ry = fy + 0.13
    for i in range(3):
        cx = -ww / 2 + 0.02 + rw * (i + 0.5)
        with b.part(f"reel_{i}", pivot=(cx, ry, wz + wh / 2), motion="spin", axis="x"):
            b.cyl(0.125, rw - 0.03, cx, ry, wz + wh / 2, "insert_reels", segs=16, rot=(0, 90, 0), center=True)
        for sx in (-1, 1):
            b.cyl(0.13, 0.01, cx + sx * (rw / 2 - 0.006), ry, wz + wh / 2, BRASS, segs=16, rot=(0, 90, 0), center=True)
    # status light strip
    b.box(ww + 0.1, 0.06, 0.06, 0, -D / 2 + 0.06, wz + wh + 0.06, "walnut", bevel=0.012)
    for k in range(7):
        b.sphere(0.017, -ww / 2 + 0.02 + k * (ww - 0.04) / 6, -D / 2 + 0.03, wz + wh + 0.09, "bulb", u=6, v=4)
    # top sign: arched panel with insert face and bulbs
    sz = H + 0.0
    arch = [(-0.32, 0), (0.32, 0), (0.32, 0.16), (0.2, 0.26), (0.06, 0.3), (0.0, 0.34), (-0.06, 0.3), (-0.2, 0.26), (-0.32, 0.16)]
    b.prism(arch, 0.1, 0, -0.08, sz, BRASS, bevel=0.01)
    b.prism([(x * 0.86, z * 0.82 + 0.02) for x, z in arch], 0.03, 0, -0.15, sz, BODY)
    b.box(0.3, 0.012, 0.14, 0, -0.17, sz + 0.06, "insert_sign", bevel=0)
    for k in range(7):
        a = math.pi * k / 6
        b.sphere(0.016, math.cos(a) * 0.3, -0.14, sz + 0.03 + math.sin(a) * 0.26, "bulb", u=6, v=4)
    # lever on the right side: hinge part tilting toward the player
    lx = W / 2 + 0.03
    b.box(0.06, 0.16, 0.22, lx, 0.02, 0.86, BRASS, bevel=0.02)
    b.cyl(0.05, 0.05, lx + 0.03, 0.02, 0.98, BRASS, segs=10, rot=(0, 90, 0), center=True)
    with b.part("lever", pivot=(lx + 0.05, 0.02, 0.98), motion="hinge", axis="x", open_deg=-55):
        b.cyl(0.016, 0.42, lx + 0.06, 0.02, 0.98, "steel", segs=8)
        b.sphere(0.05, lx + 0.06, 0.02, 1.42, "red", u=10, v=8)
    # token tray
    b.box(0.34, 0.16, 0.05, 0, fy - 0.08, 0.5, "walnut", bevel=0.012)
    b.box(0.3, 0.12, 0.02, 0, fy - 0.08, 0.535, "walnut_b", bevel=0)
    for sx in (-1, 1):
        b.box(0.02, 0.16, 0.06, sx * 0.17, fy - 0.08, 0.5, BRASS, bevel=0.004)
    # rear service door (penguin silhouette panel is an insert)
    b.box(W - 0.3, 0.03, 0.9, 0, D / 2 + 0.005, 0.2, TRIM, bevel=0.012)
    b.box(0.28, 0.01, 0.36, 0, D / 2 + 0.02, 0.45, "insert_sign", bevel=0)
    b.socket("player_1", (0, -D / 2 - 0.55, 0), rotz=180)
    b.socket("screen", (0, ry, wz + wh / 2))
    b.socket("seat_0", (0, -D / 2 - 0.42, SEAT_Z), rotz=180)
    o = b.finish(KIT, "furniture", {"game": "slots", "color_variants": {"body": SLOT_VARIANTS},
                                    "reel_insert": "insert_reels (cylindrical UV: u = angle around X, 4 symbols: fish, snowflake, star, footprint)",
                                    **placement("floor", clearance=2)})
    planar_uv(o)
    for ch in o.children:
        if ch.get("part", "").startswith("reel_"):
            planar_uv(ch, cyl=True)
    return o


def slot_stool():
    b = Builder("slot_stool", seed=912)
    stool(b, top=tint("cushion", "coral"))
    b.socket("seat", (0, 0, SEAT_Z))
    return b.finish(KIT, "furniture", {"color_variants": {"cushion": SLOT_VARIANTS}, **placement("floor")})


def roulette_stool():
    b = Builder("roulette_stool", seed=913)
    stool(b)
    b.socket("seat", (0, 0, SEAT_Z))
    return b.finish(KIT, "furniture", placement("floor"))


def casino_chair():
    b = Builder("casino_chair", seed=914)
    chair(b)
    b.socket("seat", (0, 0, SEAT_Z))
    return b.finish(KIT, "furniture", {"color_variants": {"upholstery": ["#E86D58", "#207D85"]}, **placement("floor")})


# ------------------------------------------------------------------------- poker ---
def pedestal(b, x, y, h, w=0.3):
    b.box(w + 0.1, w * 0.8 + 0.1, 0.06, x, y, 0, "walnut_b", bevel=0.02)
    b.box(w, w * 0.8, h - 0.12, x, y, 0.06, "walnut", bevel=0.03)
    b.box(w + 0.06, w * 0.8 + 0.06, 0.06, x, y, h - 0.06, "walnut_b", bevel=0.02)
    b.cyl(0.03, 0.02, x, y - w * 0.4 - 0.005, h * 0.5, BRASS, segs=4, rot=(90, 0, 0), center=True)
    b.box(w + 0.07, 0.03, 0.04, x, y - w * 0.4 - 0.02, 0.07, BRASS, bevel=0.006)


def poker_table():
    b = Builder("poker_table", seed=921)
    W, D = 3.0, 1.7                                   # seats on a 1.95 x 1.3 m ellipse: neighbours >= 1.3 m apart
    for sx in (-0.75, 0.75):
        pedestal(b, sx, 0, TABLE_Z - 0.1)
    top = stadium(W, D, 12)
    slab(b, top, TABLE_Z - 0.1, 0.06, "walnut", bevel=0.015)
    slab(b, offset(top, -0.16), TABLE_Z - 0.05, 0.05, "insert_felt")       # replaceable felt (board lines are texture)
    rail_ring(b, offset(top, -0.05), TABLE_Z - 0.04, w=0.16, h=0.1, studs=4)
    seats = []
    for i, a in enumerate((-90, -30, 30, 90, 150, 210)):
        r = math.radians(a)
        ex, ey = (W / 2 - 0.15) * math.cos(r), (D / 2 - 0.08) * math.sin(r)
        cup_holder(b, ex * 0.95, ey * 0.95, TABLE_Z + 0.06)
        cx, cy = (W / 2 + 0.45) * math.cos(r), (D / 2 + 0.45) * math.sin(r)
        chair(b, cx, cy, math.degrees(math.atan2(-cy, -cx)) - 90 + 180)
        b.socket(f"seat_{i}", (cx, cy, SEAT_Z), rotz=math.degrees(math.atan2(-cx, cy)))
        b.socket(f"hand_{i}", (ex * 0.62, ey * 0.62, TABLE_Z), rotz=math.degrees(math.atan2(-ex, ey)))
        seats.append((cx, cy))
    for k in range(5):
        b.socket(f"board_{k}", (-0.44 + k * 0.22, 0.0, TABLE_Z + 0.002))
    b.socket("pot", (0, 0.24, TABLE_Z))
    b.socket("deck", (0, -0.24, TABLE_Z))
    o = b.finish(KIT, "furniture", {"game": "poker", "seats": 6, "felt_insert": "insert_felt"})
    planar_uv(o)
    return o


def table_button(name, color, label):
    b = Builder(name, seed=922 + len(name))
    b.cyl(0.05, 0.014, 0, 0, 0, color, segs=16, bevel=0.004)
    b.cyl(0.042, 0.002, 0, 0, 0.014, "insert_button", segs=16)
    o = b.finish(KIT, "prop", {"label": label, **placement("surface")})
    planar_uv(o)
    return o


# --------------------------------------------------------------------- blackjack ---
def blackjack_table():
    b = Builder("blackjack_table", seed=931)
    R = 1.5                                           # 5 seats on r = 1.9 m: chord 1.17 m apart
    arc = half_disc(R, 20, back=0.0)
    # walnut apron with brass-studded panels around the arc
    slab(b, half_disc(R - 0.18, 20), 0, TABLE_Z - 0.1, "walnut")
    for k in range(11):
        a = math.pi + math.pi * (k + 0.5) / 11
        x, y = (R - 0.16) * math.cos(a), (R - 0.16) * math.sin(a)
        with b.at((x, y, 0), rotz=math.degrees(a) + 90):
            b.box(0.3, 0.03, TABLE_Z - 0.2, 0, 0, 0.06, "walnut_b", bevel=0.01)
            diamond(b, 0, -0.02, (TABLE_Z - 0.1) / 2, 0.05)
    b.box(2 * R - 0.3, 0.08, TABLE_Z - 0.1, 0, -0.04, 0, "walnut", bevel=0.02)                # dealer side
    slab(b, arc, TABLE_Z - 0.1, 0.06, "walnut", bevel=0.015)
    slab(b, offset(arc, -0.16), TABLE_Z - 0.05, 0.05, "insert_felt")
    rail_ring(b, offset(arc, -0.05)[1:-1], TABLE_Z - 0.04, w=0.16, h=0.1, closed=False, studs=3)
    b.box(2 * R + 0.1, 0.16, 0.12, 0, 0.02, TABLE_Z - 0.08, "walnut", bevel=0.03)              # back bolster
    # chip tray inset, shoe and discard tray on the dealer edge
    with b.at((0, -0.14, TABLE_Z)):
        chip_rack_geo(b, 6)
    with b.at((0.95, -0.15, TABLE_Z)):
        shoe_geo(b)
    with b.at((-0.95, -0.15, TABLE_Z)):
        discard_geo(b)
    b.socket("dealer_hand", (0, -0.36, TABLE_Z))
    for i in range(5):
        a = math.pi + math.pi * (i + 0.5) / 5
        bx, by = 0.95 * math.cos(a), 0.95 * math.sin(a)
        cx, cy = (R + 0.4) * math.cos(a), (R + 0.4) * math.sin(a)
        cup_holder(b, (R - 0.1) * math.cos(a), (R - 0.1) * math.sin(a), TABLE_Z + 0.06)
        chair(b, cx, cy, math.degrees(math.atan2(-cy, -cx)) + 90)
        b.socket(f"seat_{i}", (cx, cy, SEAT_Z), rotz=math.degrees(math.atan2(-cx, cy)))
        b.socket(f"bet_{i}", (bx, by, TABLE_Z), rotz=math.degrees(math.atan2(-bx, by)))
        b.socket(f"hand_{i}", (bx * 0.8, by * 0.8, TABLE_Z), rotz=math.degrees(math.atan2(-bx, by)))
    o = b.finish(KIT, "furniture", {"game": "blackjack", "seats": 5, "felt_insert": "insert_felt"})
    planar_uv(o)
    return o


def shoe_geo(b):
    b.box(0.2, 0.13, 0.1, 0, 0, 0, "walnut_b", bevel=0.015, rot=(0, -12, 0))
    b.box(0.14, 0.1, 0.06, 0.02, 0, 0.06, "card_back", bevel=0.005, rot=(0, -12, 0))
    b.box(0.06, 0.135, 0.11, -0.08, 0, 0, "charcoal", bevel=0.01)


def discard_geo(b):
    b.box(0.18, 0.14, 0.02, 0, 0, 0, "walnut_b", bevel=0.006)
    for s in (-1, 1):
        b.box(0.18, 0.015, 0.05, 0, s * 0.065, 0, "walnut", bevel=0.004)
        b.box(0.015, 0.14, 0.05, s * 0.085, 0, 0, "walnut", bevel=0.004)
    b.box(0.13, 0.09, 0.02, 0, 0, 0.02, "card_edge", bevel=0.002)


def card_shoe():
    b = Builder("card_shoe", seed=932); shoe_geo(b)
    return b.finish(KIT, "prop", placement("surface"))


def discard_tray():
    b = Builder("discard_tray", seed=933); discard_geo(b)
    return b.finish(KIT, "prop", placement("surface"))


# ------------------------------------------------------------------ cards, chips ---
CARD_W, CARD_D, CARD_H = 0.09, 0.125, 0.004


def card():
    b = Builder("card", seed=941)
    b.box(CARD_W, CARD_D, CARD_H, 0, 0, 0, "card_edge", bevel=0.0015)
    b.box(CARD_W - 0.006, CARD_D - 0.006, 0.0006, 0, 0, CARD_H, "insert_card_face", bevel=0)
    b.box(CARD_W - 0.006, CARD_D - 0.006, 0.0006, 0, 0, -0.0006, "card_back", bevel=0)
    o = b.finish(KIT, "prop", {
        "face_atlas": "insert_card_face UV is 0..1 over the face (portrait, top = +Y). Map a 13 x 4 atlas with "
                      "uv1_scale = (1/13, 1/4) and uv1_offset = ((rank-1)/13, suit/4); ranks A..K, suits spades, hearts, diamonds, clubs.",
        "private": "never send unrevealed faces to unauthorised clients; show card_back until revealed",
        **placement("surface")})
    planar_uv(o)
    return o


def deck_stack():
    b = Builder("deck_stack", seed=942)
    b.box(CARD_W, CARD_D, 0.06, 0, 0, 0, "card_edge", bevel=0.003)
    b.box(CARD_W - 0.006, CARD_D - 0.006, 0.001, 0, 0, 0.06, "card_back", bevel=0)
    for k in range(5):  # page lines on the sides
        b.box(CARD_W + 0.0008, 0.002, 0.0015, 0, -CARD_D / 2 + 0.02 + k * 0.02, 0.01 + k * 0.009, "stone", bevel=0)
    return b.finish(KIT, "prop", placement("surface"))


def chip_geo(b, x=0, y=0, z=0, mat=CHIP):
    b.cyl(0.032, 0.009, x, y, z, mat, segs=16, bevel=0.002)
    for k in range(6):
        a = math.radians(60 * k)
        b.box(0.012, 0.006, 0.0094, x + math.cos(a) * 0.03, y + math.sin(a) * 0.03, z - 0.0002, "white",
              bevel=0.001, rot=(0, 0, 60 * k + 90))
    b.cyl(0.02, 0.0012, x, y, z + 0.009, "cream", segs=16)


def chip():
    b = Builder("chip", seed=951); chip_geo(b)
    return b.finish(KIT, "prop", {"color_variants": {"chip": CHIP_VARIANTS}, "denominations": list(CHIP_VARIANTS),
                                  **placement("surface")})


def chip_stack():
    b = Builder("chip_stack", seed=952)
    for k in range(10):
        chip_geo(b, b.rng.uniform(-0.002, 0.002), b.rng.uniform(-0.002, 0.002), k * 0.0095)
    return b.finish(KIT, "prop", {"color_variants": {"chip": CHIP_VARIANTS}, "count": 10, **placement("surface")})


def chip_rack():
    b = Builder("chip_rack", seed=953); chip_rack_geo(b)
    return b.finish(KIT, "prop", placement("surface"))


# -------------------------------------------------------------------- shared decor ---
def lounge_chair():
    b = Builder("lounge_chair", seed=961)
    b.box(0.86, 0.78, 0.1, 0, 0, 0.04, "walnut", bevel=0.03)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(0.03, 0.05, sx * 0.36, sy * 0.32, 0, "walnut_b", segs=6)
    b.box(0.66, 0.64, 0.16, 0, -0.02, 0.14, CUSH, bevel=0.06)                   # seat cushion
    b.box(0.86, 0.2, 0.62, 0, 0.29, 0.14, CUSH, bevel=0.07)                     # back
    for sx in (-1, 1):
        b.box(0.17, 0.78, 0.42, sx * 0.35, 0, 0.14, CUSH, bevel=0.06)          # arms
        b.box(0.04, 0.6, 0.3, sx * 0.44, -0.04, 0.18, "walnut_b", bevel=0.015)  # side wood panel
    b.box(0.32, 0.12, 0.22, 0, 0.16, 0.34, UPH, bevel=0.05, rot=(-12, 0, 0))     # cushion
    diamond(b, 0, 0.09, 0.45, 0.04)
    b.socket("seat_0", (0, -0.06, 0.32))
    return b.finish(KIT, "furniture", {"color_variants": {"cushion": ["#207D85", "#E86D58"]}, **placement("floor", clearance=1)})


def side_table():
    b = Builder("side_table", seed=962)
    b.cyl(0.16, 0.04, 0, 0, 0, "walnut_b", segs=12, bevel=0.01)
    b.cyl(0.04, 0.4, 0, 0, 0.04, "walnut", segs=8)
    b.cyl(0.23, 0.05, 0, 0, 0.44, "walnut", segs=14, bevel=0.012)
    b.cyl(0.05, 0.08, 0, 0, 0.49, BRASS, segs=8, r2=0.04)
    b.cyl(0.045, 0.06, 0, 0, 0.57, "glow", segs=8)
    b.socket("surface_0", (0.1, 0, 0.49))
    return b.finish(KIT, "furniture", {"surfaces": {"surface_0": [0.2, 0.2]}, **placement("floor")})


def card_suit_plaque():
    b = Builder("card_suit_plaque", seed=963)
    hexa = [(-0.16, 0.0), (-0.16, 0.3), (0.0, 0.42), (0.16, 0.3), (0.16, 0.0), (0.0, -0.12)]
    b.prism(hexa, 0.05, 0, 0.025, 0.12, BRASS, bevel=0.01)
    b.prism([(x * 0.84, z * 0.84 + 0.03) for x, z in hexa], 0.02, 0, -0.005, 0.12, "insert_suits")
    o = b.finish(KIT, "decor", placement("wall", rotations=(0,)))
    planar_uv(o)
    return o


def wall_lamp():
    b = Builder("casino_wall_lamp", seed=964)
    wall_lantern(b, 0, 0, 0.3)
    return b.finish(KIT, "decor", placement("wall", rotations=(0,)))


def standing_lamp():
    b = Builder("standing_lamp", seed=965)
    b.cyl(0.14, 0.04, 0, 0, 0, "walnut_b", segs=12, bevel=0.01)
    b.cyl(0.02, 1.25, 0, 0, 0.04, BRASS, segs=8)
    b.cyl(0.05, 0.04, 0, 0, 0.6, BRASS, segs=8)
    b.cyl(0.1, 0.05, 0, 0, 1.24, "bulb", segs=8)
    b.cyl(0.24, 0.3, 0, 0, 1.2, tint("shade", "#F6E4B8"), segs=12, r2=0.15, cap=False)
    return b.finish(KIT, "decor", placement("floor"))


def casino_planter():
    b = Builder("casino_planter", seed=966)
    b.cyl(0.26, 0.38, 0, 0, 0, "stone", segs=8, bevel=0.03)
    b.cyl(0.27, 0.06, 0, 0, 0.17, TRIM, segs=8, bevel=0.01)
    diamond(b, 0, -0.27, 0.2, 0.04)
    b.cyl(0.22, 0.03, 0, 0, 0.36, "soil", segs=8)
    for k in range(7):
        a = 2 * math.pi * k / 7
        b.blob(0.09, 0.32, 0.05, math.cos(a) * 0.14, math.sin(a) * 0.14, 0.62, pick(("leaf", "leaf_b", "leaf_dark"), k),
               subdiv=1, rot=(40, 0, math.degrees(a) + 90))
    b.blob(0.14, 0.14, 0.18, 0, 0, 0.5, "leaf_dark", subdiv=1)
    return b.finish(KIT, "decor", placement("floor"))


def coat_stand():
    b = Builder("coat_stand", seed=967)
    b.cyl(0.18, 0.04, 0, 0, 0, "walnut_b", segs=10, bevel=0.01)
    b.cyl(0.03, 1.5, 0, 0, 0.04, "walnut", segs=8)
    b.sphere(0.05, 0, 0, 1.58, BRASS, u=8, v=6)
    for k in range(4):
        a = math.radians(90 * k + 45)
        b.box(0.18, 0.025, 0.025, math.cos(a) * 0.08, math.sin(a) * 0.08, 1.42, BRASS, bevel=0.006,
              rot=(0, -35, 90 * k + 45), center=True)
    b.box(0.08, 0.04, 0.5, 0.12, 0, 0.9, "coral", bevel=0.02)   # hanging scarf
    return b.finish(KIT, "decor", placement("floor"))


def card_mat():
    b = Builder("card_mat", seed=968)
    b.box(1.6, 0.9, 0.012, 0, 0, 0, "insert_mat", bevel=0.004)
    o = b.finish(KIT, "decor", placement("rug"))
    planar_uv(o)
    return o


# ----------------------------------------------------------------------- building ---
CW, CD, CH = 8.4, 6.6, 2.7          # exterior footprint and wall height
BW, BD, BH = 3.4, 0.6, 3.9          # raised entrance bay (false front carrying the marquee)
SLAB = 0.12
DOOR_W, DOOR_H = 1.9, 1.95          # double doors >= 1.9 m clear (Interior Spacing Standard)


def arch_ring(b, cx, z0, r, y, mat="stone", n=9, depth=0.1, keystone=True):
    """Stone voussoirs on the wall face (wall stays solid behind: no opening to show)."""
    for k in range(n):
        a = math.pi * (k + 0.5) / n
        with b.at((cx + math.cos(a) * r, y, z0 + math.sin(a) * r), rot=(0, -math.degrees(a) + 90, 0)):
            b.box(0.2, depth, 0.15, 0, 0, 0, pick((mat, "stone_dark", mat), k), bevel=0.02, center=True)
    if keystone:
        b.box(0.2, depth + 0.03, 0.24, cx, y, z0 + r - 0.06, "stone_dark", bevel=0.025)


def double_door(b, cx, y, z, w=DOOR_W, h=DOOR_H):
    """Teal double doors in a rectangular opening; leaves hinge on the jambs and swing inward (+Y)."""
    lw = w / 2 - 0.01
    for s, nm in ((-1, "door_l"), (1, "door_r")):
        hx = cx + s * w / 2
        with b.part(nm, pivot=(hx, y + 0.05, z + 0.06), motion="hinge", axis="z", open_deg=-s * 95):
            xc = hx - s * lw / 2
            b.box(lw - 0.01, 0.06, h - 0.08, xc, y + 0.02, z + 0.06, tint("door", "teal"), bevel=0.012)
            for k in range(2):
                b.box(lw - 0.14, 0.02, (h - 0.4) / 2 - 0.08, xc, y - 0.02, z + 0.2 + k * (h - 0.4) / 2, tint("door", "teal"), bevel=0.01)
            b.box(lw * 0.5, 0.02, 0.28, xc, y - 0.025, z + h * 0.62, "glow_window", bevel=0)
            b.box(0.03, 0.04, 0.3, cx - s * 0.06, y - 0.03, z + h * 0.45, BRASS, bevel=0.008)
    # frame and threshold
    for s in (-1, 1):
        b.box(0.1, T + 0.06, h + 0.08, cx + s * (w / 2 + 0.05), y + T / 2 - 0.02, z, "walnut", bevel=0.015)
    b.box(w + 0.3, T + 0.06, 0.12, cx, y + T / 2 - 0.02, z + h, "walnut", bevel=0.015)
    b.box(w + 0.3, T + 0.2, 0.06, cx, y + 0.05, z, "stone_dark", bevel=0.015)


def marquee(b, x, y, z):
    """Arched sign above the door: walnut and brass frame, navy insert face, suit band, bulb ring."""
    shape = [(-1.25, 0.0), (1.25, 0.0), (1.3, 0.36), (1.0, 0.62), (0.5, 0.82), (0.0, 0.9), (-0.5, 0.82),
             (-1.0, 0.62), (-1.3, 0.36)]
    with b.at((x, y, z)):
        b.prism(shape, 0.14, 0, 0, 0, "walnut", bevel=0.03)
        b.prism([(px * 0.94, pz * 0.9 + 0.03) for px, pz in shape], 0.04, 0, -0.08, 0, BRASS)
        b.box(1.9, 0.02, 0.36, 0, -0.105, 0.1, "insert_sign", bevel=0)                 # CASINO lettering texture
        b.box(1.0, 0.02, 0.16, 0, -0.105, 0.56, "insert_suits", bevel=0)               # suit band texture
        for k in range(15):
            a = math.pi * k / 14
            b.sphere(0.035, math.cos(a) * 1.22, -0.1, 0.06 + math.sin(a) * 0.78, "bulb", u=6, v=4)
        b.socket("fx_sparkle", (0, -0.2, 0.95))


def banner(b, x, y, z):
    b.box(0.5, 0.05, 0.05, x, y - 0.12, z + 0.02, "walnut", bevel=0.01)
    b.box(0.05, 0.25, 0.05, x - 0.22, y - 0.08, z - 0.03, "walnut", bevel=0.008)
    b.prism([(-0.2, 0), (0.2, 0), (0.2, -0.85), (0, -1.0), (-0.2, -0.85)], 0.03, x, y - 0.2, z, "navy")
    b.prism([(-0.2, 0), (0.2, 0), (0.2, -0.85), (0, -1.0), (-0.2, -0.85)], 0.02, x, y - 0.22, z + 0.0, "navy")
    diamond(b, x, y - 0.235, z - 0.45, 0.11, BRASS)


def barrel_planter(b, x, y):
    b.cyl(0.26, 0.4, x, y, 0, "wood_b", segs=10, r2=0.23, bevel=0.02)
    for zz in (0.08, 0.3):
        b.cyl(0.265, 0.035, x, y, zz, "iron", segs=10)
    fir(b, x, y, 0.38, h=0.9, r=0.28, tiers=3)


def fanlight(b, cx, y, z, r):
    """Half-round glowing fanlight with walnut spokes, on the wall face above a door."""
    pts = [(cx + r * math.cos(math.pi * k / 12), r * math.sin(math.pi * k / 12)) for k in range(13)]
    b.prism(pts, 0.03, 0, y, z, "glow_window")
    for k in range(1, 5):
        a = math.pi * k / 5
        with b.at((cx, y - 0.02 - 0.005 * k, z), rot=(0, -math.degrees(a) + 90, 0)):   # staggered: spokes meet at the hub
            b.box(0.025, 0.03, r, 0, 0, r / 2, "walnut", bevel=0, center=True)
    b.box(2 * r + 0.06, 0.04, 0.04, cx, y - 0.02, z - 0.02, "walnut", bevel=0.006)


def casino_exterior():
    b = Builder("casino_exterior", seed=971)
    b.box(CW + 0.4, CD + 0.4, SLAB, 0, 0, 0, "stone_dark", bevel=0.04)
    b.box(BW + 0.6, BD + 0.3, SLAB, 0, -CD / 2 - BD / 2 + 0.05, 0, "stone_dark", bevel=0.04)
    fy = -CD / 2 + T / 2
    win = [(-2.75, 0.82, 0.95, 1.95), (2.75, 0.82, 0.95, 1.95)]
    with b.at((0, fy, SLAB)):
        masonry_wall(b, CW, CH, openings=[(0, BW - 2 * T, 0, CH)] + win, quoins=(True, True), cap=TRIM)
        for cx, w, zb, zt in win:
            window_unit(b, cx, zb, w=w, h=zt - zb, panes=4)
            arch_ring(b, cx, zt + 0.06, w / 2 + 0.1, -T / 2 - 0.05, n=7, keystone=False)
            fanlight(b, cx, -T / 2 - 0.02, zt + 0.06, w / 2 - 0.04)
            b.box(w + 0.3, 0.08, 0.08, cx, -T / 2 - 0.06, zb - 0.22, TRIM, bevel=0.015)        # teal sill band
        for sx in (-1, 1):
            banner(b, sx * 3.75, -T / 2, 2.35)
    # raised entrance bay: front wall with the door, side walls, stepped parapet cap
    by = -CD / 2 - BD + T / 2
    with b.at((0, by, SLAB)):
        masonry_wall(b, BW, BH, openings=[(0, DOOR_W + 0.04, 0, DOOR_H + 0.02)], quoins=(True, True), cap=None)
        double_door(b, 0, 0, 0)
        fanlight(b, 0, -T / 2 - 0.02, DOOR_H + 0.03, DOOR_W / 2 - 0.02)
        arch_ring(b, 0, DOOR_H + 0.03, DOOR_W / 2 + 0.12, -T / 2 - 0.06, n=11)
        for sx in (-1, 1):
            wall_lantern(b, sx * 1.12, -T / 2, 1.85)
    for sx in (-1, 1):
        b.box(T, BD + T, BH, sx * (BW / 2 - T / 2), -CD / 2 - BD / 2 + T / 2, SLAB, WALL_T, bevel=0.02)
    cap_y = -CD / 2 - BD / 2 + 0.25
    b.box(BW + 0.16, BD + 0.7, 0.16, 0, cap_y, SLAB + BH, TRIM, bevel=0.03)
    b.box(BW - 0.9, BD + 0.5, 0.3, 0, cap_y, SLAB + BH + 0.16, WALL_T, bevel=0.03)
    b.box(BW - 0.8, BD + 0.6, 0.1, 0, cap_y, SLAB + BH + 0.46, TRIM, bevel=0.02)
    snow_cap(b, BW + 0.1, BD + 0.6, 0, cap_y, SLAB + BH + 0.16, h=0.07, lumps=False)
    snow_cap(b, BW - 0.85, BD + 0.5, 0, cap_y, SLAB + BH + 0.56, h=0.07, lumps=True)
    # teal cornice band with corbels along the main walls
    for s2 in (-1, 1):
        b.box(CW + 0.12, 0.08, 0.14, 0, s2 * (CD / 2 + 0.02), SLAB + CH - 0.3, TRIM, bevel=0.02)
    for k in range(10):
        x = -CW / 2 + 0.45 + k * (CW - 0.9) / 9
        if abs(x) > BW / 2 + 0.1:
            b.box(0.12, 0.16, 0.2, x, -CD / 2 - 0.06, SLAB + CH - 0.2, "walnut", bevel=0.02)
    for side, rz in ((-1, 90), (1, -90)):
        with b.at((side * (CW / 2 - T / 2), 0, SLAB), rotz=rz):
            masonry_wall(b, CD - 2 * T, CH, openings=[(0, 0.82, 0.95, 1.95)], cap=TRIM)
            window_unit(b, 0, 0.95, w=0.82, h=1.0, panes=4)
            arch_ring(b, 0, 2.01, 0.51, -T / 2 - 0.05, n=7, keystone=False)
            fanlight(b, 0, -T / 2 - 0.02, 2.01, 0.37)
    with b.at((0, CD / 2 - T / 2, SLAB), rotz=180):
        masonry_wall(b, CW - 2 * T, CH, cap=TRIM)
    # entrance: steps, mat, marquee, planters
    entry_steps(b, 0, -CD / 2 - BD - 0.1, w=2.2, steps=1, rise=SLAB)
    b.box(1.4, 0.7, 0.012, 0, -CD / 2 - BD - 0.6, 0.0, "insert_mat", bevel=0.004)
    marquee(b, 0, -CD / 2 - BD - 0.04, SLAB + 2.7)
    for sx in (-1, 1):
        barrel_planter(b, sx * 1.6, -CD / 2 - BD - 0.55)
    b.socket("door", (0, -CD / 2 - BD - 1.0, 0), rotz=180)
    b.socket("spawn_inside", (0, -CD / 2 + 0.9, SLAB))
    house = b.finish(KIT, "building", {"footprint_m": [CW, CD + BD], "floor_z": SLAB, "roof_child": "casino_exterior_roof",
                                       "interior": "casino/casino_interior_shell"})
    r = Builder("casino_exterior_roof", seed=972)
    with r.at((0, 0, 0), rotz=90):                     # ridge along X so the long eave faces the plaza
        tiled_gable(r, CD, CW, 1.75, z=SLAB + CH, overhang=0.32, tile=0.38)
    cx, cy = 2.4, 1.2
    zr = SLAB + CH + 1.75 * (1 - cy / (CD / 2)) - 0.1
    r.box(0.56, 0.56, 1.2, cx, cy, zr, "chimney", bevel=0.03)
    r.box(0.66, 0.66, 0.12, cx, cy, zr + 1.2, "chimney_cap", bevel=0.025)
    r.socket("fx_smoke", (cx, cy, zr + 1.42))
    for k in range(9):                                 # snow lumps hanging over the front eave (clear of the bay)
        x = -CW / 2 + 0.4 + k * (CW - 0.8) / 8
        if abs(x) < BW / 2 + 0.3:
            continue
        r.blob(0.42, 0.28, 0.14, x, -CD / 2 - 0.2, SLAB + CH + 0.18, "snow", subdiv=1, jitter=0.03)
    for k in range(6):                                 # snow along the ridge
        r.blob(0.6, 0.35, 0.16, -CW / 2 + 0.8 + k * (CW - 1.6) / 5, 0, SLAB + CH + 1.95, "snow", subdiv=1, jitter=0.04)
    roof = r.finish(KIT, "roof", {"visibility_group": "roof"})
    attach(roof, house)
    planar_uv(house)
    return house


IW, ID, IH = 16.0, 12.0, 3.0         # interior room (separate scene): Interior Spacing Standard target
SLOT_ROW_X = (2.6, 3.75, 4.9, 6.05)    # back-wall slot row, 1.15 m pitch, right of the main aisle
# table anchors: 2.0 m main aisle at x in [-1, 1], 2.5 m entry zone, 1.5 m spectator bands around tables
ANCHORS = {"roulette": (-4.5, 3.4), "poker": (-4.5, -2.4), "blackjack": (4.3, -1.4)}
SLOT_ROW_TINTS = ("coral", "teal", "plum", "coral")


def casino_interior_shell():
    b = Builder("casino_interior_shell", seed=981)
    b.box(IW + 0.4, ID + 0.4, SLAB, 0, 0, 0, "stone_dark", bevel=0.04)
    planks(b, IW - 2 * T, ID - 2 * T, z=SLAB, plank=0.24, mats=("walnut", "walnut_b", "wood_dark"), along="y")
    # 2.0 m red carpet main aisle from the door to the back wall, with a gold border and spade insert
    cl = ID - 2 * T - 0.4
    b.box(2.0, cl, 0.012, 0, -0.2 + 0.2, SLAB + 0.06, "carpet_gold", bevel=0.004)
    b.box(1.84, cl - 0.16, 0.012, 0, 0.0, SLAB + 0.068, "carpet_red", bevel=0.004)
    b.box(0.8, 0.8, 0.004, 0, -3.6, SLAB + 0.08, "insert_carpet", bevel=0)
    for side, rz in ((-1, 90), (1, -90)):
        with b.at((side * (IW / 2 - T / 2), 0, SLAB), rotz=rz):
            wins = [(-3.2, 0.9, 1.0, 2.0), (0.4, 0.9, 1.0, 2.0), (3.6, 0.9, 1.0, 2.0)]
            masonry_wall(b, ID - 2 * T, IH, openings=wins, cap=TRIM)
            for cx, w, zb, zt in wins:
                window_unit(b, cx, zb, w=w, h=zt - zb)
            b.box(ID - 2 * T, 0.03, 0.9, 0, -T / 2 - 0.015, 0.0, "walnut", bevel=0.01)          # wainscot
            # right wall skips the lantern that would sit inside the chip window (world y = 1.4)
            for cx in ((-4.8, 1.3, 2.0, 5.2) if side > 0 else (-4.8, -1.4, 2.0, 5.2)):
                wall_lantern(b, cx, -T / 2, 2.0)
    with b.at((0, ID / 2 - T / 2, SLAB), rotz=180):
        masonry_wall(b, IW, IH, quoins=(True, True), cap=TRIM)
        b.box(IW - 0.4, 0.03, 0.9, 0, -T / 2 - 0.015, 0.0, "walnut", bevel=0.01)
        for cx in (-6.6, -2.2, 2.2, 6.6):
            wall_lantern(b, cx, -T / 2, 2.0)
    # low front lip (cutaway) with a 2.0 m entrance gap
    for sgn in (-1, 1):
        b.box(IW / 2 - 1.0, T, 0.45, sgn * (IW / 4 + 0.5), -ID / 2 + T / 2, SLAB, WALL_T, bevel=0.02)
        b.box(0.35, T + 0.1, 0.9, sgn * 1.18, -ID / 2 + T / 2, SLAB, "stone", bevel=0.03)
    # lounge corners (front), planters on the side walls and back corners, plaque on the back wall
    for sx in (-1, 1):
        with b.at((sx * 6.5, -4.6, SLAB), rotz=180 + sx * 30):
            b.box(0.86, 0.78, 0.1, 0, 0, 0.04, "walnut", bevel=0.03)
            b.box(0.66, 0.64, 0.16, 0, -0.02, 0.14, CUSH, bevel=0.06)
            b.box(0.86, 0.2, 0.62, 0, 0.29, 0.14, CUSH, bevel=0.07)
            for ax in (-1, 1):
                b.box(0.17, 0.78, 0.42, ax * 0.35, 0, 0.14, CUSH, bevel=0.06)
        b.cyl(0.23, 0.05, sx * 5.3, -4.9, SLAB + 0.44, "walnut", segs=14, bevel=0.012)
        b.cyl(0.04, 0.44, sx * 5.3, -4.9, SLAB, "walnut", segs=8)
        # the right-hand planter moves north of the chip window; the left one stays between the tables
        for (px, py) in ((sx * (IW / 2 - 0.6), ID / 2 - 0.6), (sx * (IW / 2 - 0.6), 4.35 if sx > 0 else 1.0)):
            b.cyl(0.26, 0.38, px, py, SLAB, "stone", segs=8, bevel=0.03)
            b.cyl(0.27, 0.06, px, py, SLAB + 0.17, TRIM, segs=8, bevel=0.01)
            for k in range(6):
                a2 = 2 * math.pi * k / 6
                b.blob(0.09, 0.3, 0.05, px + math.cos(a2) * 0.13, py + math.sin(a2) * 0.13, SLAB + 0.6,
                       pick(("leaf", "leaf_b", "leaf_dark"), k), subdiv=1, rot=(40, 0, math.degrees(a2) + 90))
    hexa = [(-0.3, 0.0), (-0.3, 0.55), (0.0, 0.76), (0.3, 0.55), (0.3, 0.0), (0.0, -0.21)]
    b.prism(hexa, 0.05, 0, ID / 2 - T - 0.03, SLAB + 1.6, BRASS, bevel=0.01)
    b.prism([(x * 0.84, z * 0.84 + 0.05) for x, z in hexa], 0.02, 0, ID / 2 - T - 0.06, SLAB + 1.6, "insert_suits")
    o = b.finish(KIT, "building", {
        "footprint_m": [IW, ID], "floor_z": SLAB, "ceiling_child": "casino_interior_shell_ceiling",
        "spacing": "Art Docs/Interior Spacing Standard.md: seats >= 1.15 m apart, 2.0 m main aisle, 2.5 m entry zone, "
                   "1.5 m spectator bands, 1.4 m slot standing zones",
        "layout_sockets": "roulette, poker, blackjack, slots_0..3 (+ slot_stool_0..3), lounge_*, entry_zone, cash_out",
        "slot_row": {f"slots_{i}": {"asset": "casino/slot_machine", "tint": {"body": SLOT_VARIANTS[t]},
                                     "stool": f"slot_stool_{i}"} for i, t in enumerate(SLOT_ROW_TINTS)}})
    c = Builder("casino_interior_shell_ceiling", seed=982)
    for k in range(13):
        c.box(0.16, ID, 0.18, -IW / 2 + 0.6 + k * (IW - 1.2) / 12, 0, SLAB + IH - 0.18, "walnut", bevel=0.02)
    c.box(IW, ID, 0.06, 0, 0, SLAB + IH, "wood_c", bevel=0.01)
    lamps = [(ax, ay + 0.8) for ax, ay in ANCHORS.values()] + [(0, 2.5), (0, -2.5), (4.3, 4.6)]
    for (x, y) in lamps:
        c.cyl(0.01, 0.7, x, y, SLAB + IH - 0.7, BRASS, segs=6)
        c.cyl(0.32, 0.12, x, y, SLAB + IH - 0.85, BRASS, segs=12, r2=0.38)
        c.cyl(0.26, 0.05, x, y, SLAB + IH - 0.87, "glow", segs=12)
        c.cyl(0.3, 0.06, x, y, SLAB + IH - 0.77, TRIM, segs=12)
    ceil = c.finish(KIT, "roof", {"visibility_group": "roof"})
    attach(ceil, o)
    sy = ID / 2 - T - 0.06 - 0.28                     # slot backs against the wall
    socks = {"spawn_inside": (0, -ID / 2 + 1.4, SLAB), "exit": (0, -ID / 2 + 0.3, SLAB), "entry_zone": (0, -ID / 2 + 1.5, SLAB),
             **{k: (x, y, SLAB) for k, (x, y) in ANCHORS.items()},
             **{f"slots_{i}": (x, sy, SLAB) for i, x in enumerate(SLOT_ROW_X)},
             **{f"slot_stool_{i}": (x, sy - 0.7, SLAB) for i, x in enumerate(SLOT_ROW_X)},
             "lounge_0": (-6.5, -4.6, SLAB), "lounge_1": (6.5, -4.6, SLAB),
             # right wall, between the windows; back face tucks into the wall. Yaw -90 in the room.
             "cash_out": (7.31, 1.40, SLAB)}
    for nm, p in socks.items():
        add_socket(o, nm, p, 0)                       # slot machines face -Y (into the room) at yaw 0
    planar_uv(o)
    return o


# ----------------------------------------------------------------- chip window ------
def cash_out_booth():
    """Cashier cage for play chips. One solid counter, stone posts and a teller screen, in the
    same chunky language as the slot cabinets: cream stone, walnut, teal felt, restrained brass.
    Front faces -Y. The wordmark is insert_sign (authored texture; no modelled letters, no
    currency marks). A penguin stands at player_0, on the mat."""
    b = Builder("cash_out_booth", seed=991)
    W, D = 1.88, 0.82
    fy, by = -D / 2, D / 2
    cz = 0.74

    # solid cabinet: plinth, stone body, walnut front with the roulette pennant
    b.box(W + 0.10, D + 0.08, 0.10, 0, 0.02, 0, "stone_dark", bevel=0.03)
    b.box(W, D, cz - 0.18, 0, 0.03, 0.10, "stone", bevel=0.04)
    b.box(W - 0.36, 0.06, cz - 0.32, 0, fy - 0.01, 0.18, "walnut", bevel=0.018)
    b.box(0.50, 0.03, 0.22, 0, fy - 0.045, 0.38, TRIM, bevel=0.008)
    b.prism([(-0.16, 0.20), (0.16, 0.20), (0.0, 0.03)], 0.026, 0, fy - 0.065, 0.38, "coral")
    diamond(b, 0, fy - 0.085, 0.52, 0.04)
    for s in (-1, 1):
        b.box(0.08, 0.04, cz - 0.28, s * (W * 0.5 - 0.22), fy - 0.02, 0.16, "walnut_b", bevel=0.012)

    # counter cap. The lip reaches toward the player; the brass rail is tucked under that lip.
    lip = fy - 0.20
    b.box(W + 0.08, 0.70, 0.07, 0, lip + 0.28, cz - 0.07, "walnut", bevel=0.02)
    b.box(W - 0.12, 0.04, 0.04, 0, lip - 0.01, cz - 0.05, BRASS, bevel=0.008)
    b.box(0.46, 0.22, 0.012, -0.46, lip + 0.16, cz, FELT)
    b.box(0.18, 0.12, 0.016, -0.62, lip + 0.14, cz + 0.012, "walnut_b", bevel=0.004)
    b.box(0.14, 0.09, 0.006, -0.62, lip + 0.14, cz + 0.028, "cream", bevel=0.002)
    b.cyl(0.046, 0.024, -0.22, lip + 0.14, cz + 0.012, BRASS, segs=10, r2=0.028, bevel=0.004)
    b.sphere(0.012, -0.22, lip + 0.14, cz + 0.058, BRASS, u=6, v=4)
    b.box(0.46, 0.20, 0.036, 0.42, lip + 0.14, cz, BRASS, bevel=0.008)
    b.box(0.38, 0.13, 0.010, 0.42, lip + 0.14, cz + 0.034, "felt_dark")
    for i, col in enumerate(("red", "blue", "green", "cream")):
        chip_geo(b, 0.26 + i * 0.09, lip + 0.14, cz + 0.044, col)
    b.box(0.70, 0.08, 0.014, 0, lip + 0.10, cz - 0.09, "glow")
    rail_y = lip + 0.08
    b.cyl(0.016, W - 0.70, 0, rail_y, 0.22, BRASS, segs=8, rot=(0, 90, 0), center=True)
    for s in (-1, 1):
        b.box(0.045, 0.045, 0.22, s * ((W - 0.70) * 0.5), rail_y, 0.0, BRASS, bevel=0.008)
        b.box(0.04, 0.05, cz - 0.07 - 0.20, s * ((W - 0.70) * 0.5), rail_y, 0.20, BRASS, bevel=0.006)

    # posts and the teller screen grow out of the counter, so the window is not a floating frame
    post_h = 0.64
    for s in (-1, 1):
        b.box(0.18, 0.20, post_h, s * (W * 0.5 - 0.12), fy + 0.06, cz, "stone", bevel=0.028)
        b.box(0.22, 0.24, 0.06, s * (W * 0.5 - 0.12), fy + 0.06, cz + post_h - 0.02, "walnut", bevel=0.012)
    b.box(W - 0.46, 0.12, post_h, 0, fy + 0.05, cz, "walnut", bevel=0.016)
    for s in (-1, 1):
        b.box(0.22, 0.03, 0.22, s * 0.52, fy - 0.02, cz + 0.18, "walnut_b", bevel=0.008)
        diamond(b, s * 0.52, fy - 0.045, cz + 0.29, 0.036)

    ww, wh, wz = 0.58, 0.28, cz + 0.18
    b.box(ww + 0.10, 0.045, 0.04, 0, fy - 0.02, wz - 0.02, BRASS, bevel=0.008)
    b.box(ww + 0.10, 0.045, 0.04, 0, fy - 0.02, wz + wh, BRASS, bevel=0.008)
    for s in (-1, 1):
        b.box(0.042, 0.045, wh + 0.06, s * (ww * 0.5 + 0.024), fy - 0.02, wz - 0.02, BRASS, bevel=0.006)
    b.box(ww - 0.02, 0.04, wh, 0, fy + 0.04, wz, "walnut_b")
    b.box(ww - 0.08, 0.016, wh - 0.06, 0, fy + 0.02, wz + 0.03, "glow")
    for i, col in enumerate(("red", "blue", "green", "cream")):
        for k in range(3):
            chip_geo(b, -0.18 + i * 0.12, fy + 0.01, wz + 0.015 + k * 0.011, col)
    for sx in (-0.16, 0.16):
        b.box(0.02, 0.02, wh - 0.05, sx, fy - 0.04, wz + 0.02, BRASS, bevel=0.003)

    # marquee sits on the post caps. Bulbs follow the arch; the medallion stays above the word plate.
    sign_z = cz + post_h - 0.04
    arch = [(-0.70, 0.0), (0.70, 0.0), (0.70, 0.10), (0.42, 0.22), (0.14, 0.30),
            (0.0, 0.34), (-0.14, 0.30), (-0.42, 0.22), (-0.70, 0.10)]
    b.prism(arch, 0.12, 0, fy + 0.02, sign_z, BRASS, bevel=0.012)
    b.prism([(x * 0.88, z * 0.76 + 0.03) for x, z in arch], 0.03, 0, fy - 0.04, sign_z, "coral")
    b.box(0.50, 0.014, 0.10, 0, fy - 0.06, sign_z + 0.045, "insert_sign")
    b.cyl(0.055, 0.014, 0, fy - 0.065, sign_z + 0.22, "red", segs=14, bevel=0.003, center=True)
    b.cyl(0.032, 0.006, 0, fy - 0.074, sign_z + 0.226, "cream", segs=12)
    for x, z in arch:
        b.sphere(0.018, x * 0.96, fy - 0.05, sign_z + max(z, 0.02) * 0.90, "bulb", u=6, v=4)

    # clerk bay: the cabinet is the counter; a rack sits on the back half
    b.box(W - 0.28, 0.06, 0.10, 0, by - 0.02, cz - 0.10, "walnut_b", bevel=0.01)
    with b.at((0.0, 0.16, cz)):
        chip_rack_geo(b, 5)

    b.box(1.00, 0.40, 0.010, 0, lip - 0.16, 0.0, "carpet_gold", bevel=0.003)
    b.box(0.86, 0.28, 0.010, 0, lip - 0.16, 0.010, "carpet_red", bevel=0.003)

    b.socket("player_0", (0.15, lip - 0.22, 0), rotz=180)
    b.socket("tray", (0.42, lip + 0.14, cz + 0.05))
    o = b.finish(KIT, "furniture", {
        "game": "cashier", "sign_insert": "insert_sign",
        "notes": "play-chip window; lettering is a texture on insert_sign; no currency marks",
        **placement("floor", clearance=1)})
    planar_uv(o)
    return o


# ---------------------------------------------------------------------- previews ---
def build():
    casino_exterior()
    casino_interior_shell()
    roulette_table(); roulette_ball(); roulette_marker(); roulette_stool()
    for nm, col in (("slot_machine", "coral"),):
        slot_machine(nm, col)
    slot_stool()
    poker_table(); casino_chair()
    table_button("dealer_button", "white", "DEALER")
    table_button("small_blind_button", "blue", "SMALL BLIND")
    table_button("big_blind_button", "red", "BIG BLIND")
    blackjack_table(); card_shoe(); discard_tray()
    card(); deck_stack(); chip(); chip_stack(); chip_rack()
    lounge_chair(); side_table(); card_suit_plaque(); wall_lamp(); standing_lamp(); casino_planter(); coat_stand(); card_mat()
    cash_out_booth()
