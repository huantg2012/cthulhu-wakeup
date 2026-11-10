# Blender headless asset builder for "旧日星图" (Eldritch Starchart)
# Usage: blender -b -P build_assets.py -- /workspace/project/assets/eldritch_assets.glb
#
# Generates every mesh the Godot generator needs, procedurally:
#   Planet      - smooth icosphere (r=1)          -> planet / moon / star / atmosphere shells
#   PlanetLow   - jittered flat icosphere          -> low-poly art style (face centres in COLOR)
#   Tentacle    - tapered tube along +Y with sucker rows (COLOR.r = sucker mask)
#   Ring        - annulus r=0.2..1.0 in XZ plane   -> planetary rings / accretion disks / orbits
#   Rock0..3    - lumpy asteroid variants
#   Monolith    - eldritch obelisk
#   Gate        - cyclopean ring gate with thorns (faces +Z in Godot)
#   Ruins       - floating island with leaning non-euclidean towers
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, Matrix, noise

argv = sys.argv
OUT = argv[argv.index('--') + 1] if '--' in argv else '/workspace/project/assets/eldritch_assets.glb'

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def link(name, bm, smooth=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        me.shade_smooth()
    else:
        me.shade_flat()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


def set_corner_colors(ob, fn):
    """fn(poly, loop_vertex_co) -> (r,g,b)"""
    me = ob.data
    attr = me.color_attributes.new(name="Col", type='FLOAT_COLOR', domain='CORNER')
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            r, g, b = fn(poly, me.vertices[vi].co)
            attr.data[li].color = (r, g, b, 1.0)
    me.color_attributes.active_color = attr
    try:
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    except Exception:
        pass


# ---------------------------------------------------------------- Planet
bm = bmesh.new()
bmesh.ops.create_icosphere(bm, subdivisions=6, radius=1.0)
for v in bm.verts:
    v.co.normalize()
link("Planet", bm, smooth=True)

# ---------------------------------------------------------------- Orb (light sphere for instancing)
bm = bmesh.new()
bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
for v in bm.verts:
    v.co.normalize()
link("Orb", bm, smooth=True)

# ---------------------------------------------------------------- PlanetLow
random.seed(7)
bm = bmesh.new()
bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
for v in bm.verts:
    v.co.normalize()
    v.co *= 1.0 + random.uniform(-0.02, 0.02)
link("PlanetLow", bm, smooth=False)   # flat normals ~= face centre direction

# ---------------------------------------------------------------- Tentacle
NA, NR = 200, 40           # rings along, verts around
BASE_R, TIP_R = 0.085, 0.003


def radius_at(t):
    flare = 1.0 + 0.7 * math.exp(-t * 18.0)
    return (BASE_R * (1.0 - t) ** 0.85 + TIP_R) * flare


# sucker centres: two rows around +X (inner side of the curl)
suckers = []
t = 0.06
while t < 0.93:
    r = radius_at(t)
    for row, ang in enumerate((-0.42, 0.42)):
        tt = t + (0.5 * r * 1.35 if row else 0.0)
        suckers.append((tt, ang, radius_at(tt) * 0.36))
    t += radius_at(t) * 1.35

bm = bmesh.new()
rings = []
mask_of = {}
for k in range(NA + 1):
    t = k / NA
    r = radius_at(t)
    ring = []
    for j in range(NR):
        a = j / NR * math.tau
        # sucker profile
        m = 0.0
        disp = 0.0
        for (st, sa, sr) in suckers:
            if abs(st - t) > sr * 1.6:
                continue
            da = (a - sa + math.pi) % math.tau - math.pi
            dx = da * r
            dy = (t - st)
            d = math.sqrt(dx * dx + dy * dy) / sr
            if d < 1.25:
                m = max(m, 1.0 - max(0.0, d - 0.85) / 0.4)
                # raised rim, sunken centre
                disp += sr * (0.28 * math.exp(-((d - 0.85) / 0.18) ** 2) - 0.18 * math.exp(-(d / 0.45) ** 2))
        # dorsal wrinkles on the outer side
        back = max(0.0, -math.cos(a))
        disp += r * 0.035 * back * math.sin(t * 260.0 + math.sin(a * 3.0))
        rr = r + disp
        v = bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, t))
        mask_of[v] = (m, t)
        ring.append(v)
    rings.append(ring)

for k in range(NA):
    for j in range(NR):
        j2 = (j + 1) % NR
        bm.faces.new((rings[k][j], rings[k][j2], rings[k + 1][j2], rings[k + 1][j]))
tip = bm.verts.new((0.0, 0.0, 1.0 + TIP_R * 2.0))
mask_of[tip] = (0.0, 1.0)
for j in range(NR):
    j2 = (j + 1) % NR
    bm.faces.new((rings[NA][j], rings[NA][j2], tip))
base = bm.verts.new((0.0, 0.0, -0.002))
mask_of[base] = (0.0, 0.0)
for j in range(NR):
    j2 = (j + 1) % NR
    bm.faces.new((rings[0][j2], rings[0][j], base))

# vertex order is preserved by to_mesh(), so keep the mask by index
bm.verts.index_update()
mask_by_index = {v.index: m for v, (m, tt) in mask_of.items()}
tent = link("Tentacle", bm, smooth=True)


me = tent.data
attr = me.color_attributes.new(name="Col", type='FLOAT_COLOR', domain='CORNER')
for poly in me.polygons:
    for li in poly.loop_indices:
        vi = me.loops[li].vertex_index
        attr.data[li].color = (mask_by_index.get(vi, 0.0), me.vertices[vi].co.z, 0.0, 1.0)
me.color_attributes.active_color = attr

# ---------------------------------------------------------------- TentacleLow (for low-poly style)
NA2, NR2 = 28, 6
bm = bmesh.new()
rings2 = []
for k in range(NA2 + 1):
    t = k / NA2
    r = radius_at(t)
    ring = [bm.verts.new((math.cos(j / NR2 * math.tau + k * 0.5) * r, math.sin(j / NR2 * math.tau + k * 0.5) * r, t)) for j in range(NR2)]
    rings2.append(ring)
for k in range(NA2):
    for j in range(NR2):
        j2 = (j + 1) % NR2
        bm.faces.new((rings2[k][j], rings2[k][j2], rings2[k + 1][j2], rings2[k + 1][j]))
tip2 = bm.verts.new((0.0, 0.0, 1.0 + TIP_R * 2.0))
for j in range(NR2):
    bm.faces.new((rings2[NA2][j], rings2[NA2][(j + 1) % NR2], tip2))
tl = link("TentacleLow", bm, smooth=False)
me = tl.data
attr = me.color_attributes.new(name="Col", type='FLOAT_COLOR', domain='CORNER')
for poly in me.polygons:
    for li in poly.loop_indices:
        vi = me.loops[li].vertex_index
        attr.data[li].color = (0.0, me.vertices[vi].co.z, 0.0, 1.0)
me.color_attributes.active_color = attr

# ---------------------------------------------------------------- Ring (annulus)
SEG, RAD = 256, 10
R_IN, R_OUT = 0.2, 1.0
bm = bmesh.new()
grid = []
for i in range(RAD + 1):
    r = R_IN + (R_OUT - R_IN) * i / RAD
    row = []
    for j in range(SEG):
        a = j / SEG * math.tau
        row.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0.0)))
    grid.append(row)
for i in range(RAD):
    for j in range(SEG):
        j2 = (j + 1) % SEG
        bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j2], grid[i][j2]))
ob = link("Ring", bm, smooth=True)
for p in ob.data.polygons:
    if p.normal.z < 0:
        p.flip()

# ---------------------------------------------------------------- Rocks
for n in range(4):
    random.seed(100 + n)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    off = Vector((random.uniform(-50, 50), random.uniform(-50, 50), random.uniform(-50, 50)))
    squash = Vector((random.uniform(0.75, 1.0), random.uniform(0.55, 0.9), random.uniform(0.7, 1.0)))
    craters = [(Vector((random.gauss(0, 1), random.gauss(0, 1), random.gauss(0, 1))).normalized(),
                random.uniform(0.25, 0.55)) for _ in range(5)]
    for v in bm.verts:
        d = v.co.normalized()
        h = noise.fractal(d * 1.6 + off, 0.6, 2.1, 5, noise_basis='PERLIN_ORIGINAL')
        h2 = noise.noise(d * 5.0 + off)
        rad = 1.0 + 0.32 * h + 0.06 * h2
        for (cd, cr) in craters:
            ang = d.angle(cd)
            if ang < cr:
                x = ang / cr
                rad -= 0.12 * cr * (1.0 - x * x) - 0.05 * cr * math.exp(-((x - 1.0) / 0.2) ** 2)
        v.co = Vector((d.x * squash.x, d.y * squash.y, d.z * squash.z)) * rad
    link("Rock%d" % n, bm, smooth=(n % 2 == 0))

# ---------------------------------------------------------------- Monolith
bm = bmesh.new()
W0, W1, D0, D1, H, AP = 0.34, 0.24, 0.2, 0.15, 1.85, 2.15
b = [bm.verts.new(p) for p in ((-W0, -D0, 0), (W0, -D0, 0), (W0, D0, 0), (-W0, D0, 0))]
t_ = [bm.verts.new(p) for p in ((-W1, -D1, H), (W1, -D1, H), (W1, D1, H), (-W1, D1, H))]
apex = bm.verts.new((0.03, 0.0, AP))
bm.faces.new(list(reversed(b)))
for i in range(4):
    i2 = (i + 1) % 4
    bm.faces.new((b[i], b[i2], t_[i2], t_[i]))
    bm.faces.new((t_[i], t_[i2], apex))
# carved recess on the front & back faces
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
side = [f for f in bm.faces if abs(f.normal.y) > 0.9]
res = bmesh.ops.inset_individual(bm, faces=side, thickness=0.07, depth=-0.03)
bm.verts.ensure_lookup_table()
for v in bm.verts:
    v.co.z -= 0.0
mono = link("Monolith", bm, smooth=False)
mono.data.transform(Matrix.Translation((0, 0, -AP * 0.45)))

# ---------------------------------------------------------------- Gate (in Blender XZ plane => faces Godot +Z)
random.seed(42)
bm = bmesh.new()
NB = 26
for i in range(NB):
    a = i / NB * math.tau
    arc = math.tau / NB
    thick = 0.16 + random.uniform(-0.02, 0.05)
    depth = 0.22 + random.uniform(-0.04, 0.08)
    rad = 1.0 + random.uniform(-0.015, 0.03)
    mat = (Matrix.Rotation(-a, 4, 'Y') @ Matrix.Translation((rad, 0, 0)) @
           Matrix.Rotation(random.uniform(-0.08, 0.08), 4, 'Z') @
           Matrix.Diagonal((thick, depth, arc * 0.93 * rad, 1.0)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=mat)
# outer thorns
for i in range(9):
    a = (i + 0.5) / 9 * math.tau + random.uniform(-0.1, 0.1)
    ln = random.uniform(0.35, 0.75)
    bend = random.uniform(-0.35, 0.35)
    mat = (Matrix.Rotation(-a, 4, 'Y') @ Matrix.Translation((1.08 + ln * 0.5, 0, 0)) @
           Matrix.Rotation(bend, 4, 'Y') @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.075, radius2=0.0, depth=ln, matrix=mat)
# inner teeth
for i in range(16):
    a = i / 16 * math.tau
    ln = random.uniform(0.12, 0.22)
    mat = (Matrix.Rotation(-a, 4, 'Y') @ Matrix.Translation((0.92 - ln * 0.5, 0, 0)) @
           Matrix.Rotation(-math.pi / 2, 4, 'Y'))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=0.04, radius2=0.0, depth=ln, matrix=mat)
# keystone blocks
for i in range(4):
    a = i / 4 * math.tau + math.pi / 4
    mat = (Matrix.Rotation(-a, 4, 'Y') @ Matrix.Translation((1.0, 0, 0)) @
           Matrix.Diagonal((0.32, 0.34, 0.26, 1.0)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=mat)
link("Gate", bm, smooth=False)

# ---------------------------------------------------------------- Ruins (floating island)
random.seed(1234)
bm = bmesh.new()
bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
off = Vector((3.1, 7.7, 1.9))
for v in bm.verts:
    d = v.co.normalized()
    h = noise.fractal(d * 2.0 + off, 0.5, 2.0, 4)
    x, y, z = d.x, d.y, d.z
    if z > 0.0:
        z = z * 0.18 + 0.02 * h
    else:
        z = z * (1.5 + 0.5 * h) - 0.25 * (1 - abs(z)) * h
    s = 1.0 + 0.18 * h
    v.co = Vector((x * 1.25 * s, y * 1.0 * s, z))
for i in range(9):
    w = random.uniform(0.12, 0.3)
    dpt = random.uniform(0.12, 0.3)
    hh = random.uniform(0.4, 1.4)
    px, py = random.uniform(-0.8, 0.8), random.uniform(-0.6, 0.6)
    tilt_x = random.uniform(-0.35, 0.35)
    tilt_y = random.uniform(-0.35, 0.35)
    mat = (Matrix.Translation((px, py, 0.1)) @ Matrix.Rotation(tilt_x, 4, 'X') @ Matrix.Rotation(tilt_y, 4, 'Y') @
           Matrix.Rotation(random.uniform(0, 3), 4, 'Z') @ Matrix.Translation((0, 0, hh * 0.5)) @
           Matrix.Diagonal((w, dpt, hh, 1.0)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=mat)
    if random.random() < 0.5:   # slanted cap block
        mat2 = (Matrix.Translation((px, py, 0.1)) @ Matrix.Rotation(tilt_x, 4, 'X') @ Matrix.Rotation(tilt_y, 4, 'Y') @
                Matrix.Translation((0, 0, hh + 0.05)) @ Matrix.Rotation(random.uniform(-0.6, 0.6), 4, 'X') @
                Matrix.Diagonal((w * 1.4, dpt * 1.4, 0.08, 1.0)))
        bmesh.ops.create_cube(bm, size=1.0, matrix=mat2)
# broken arch
for sx in (-0.25, 0.25):
    mat = Matrix.Translation((sx + 0.35, -0.2, 0.55)) @ Matrix.Rotation(0.12, 4, 'Y') @ Matrix.Diagonal((0.09, 0.09, 1.0, 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=mat)
mat = Matrix.Translation((0.38, -0.2, 1.08)) @ Matrix.Rotation(0.2, 4, 'Y') @ Matrix.Diagonal((0.7, 0.12, 0.1, 1.0))
bmesh.ops.create_cube(bm, size=1.0, matrix=mat)
ru = link("Ruins", bm, smooth=False)

# ---------------------------------------------------------------- export
for o in scene.objects:
    o.select_set(True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_apply=True,
                          export_vertex_color='ACTIVE', export_materials='NONE',
                          export_yup=True, export_normals=True, export_texcoords=True)
print("EXPORTED", OUT, [o.name for o in scene.objects])
