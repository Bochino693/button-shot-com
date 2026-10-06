"""Bola 3D de gomos (abertura, pódio): 12 pentágonos e 20 hexágonos costurados.

    /caminho/do/python-com-bpy tools/modelos3d/bola.py  [--render pasta]

Icosaedro truncado (o desenho clássico da bola), cada gomo vira um pedaço de
esfera um pouco estufado, com a costura em baixo-relevo entre eles.
Materiais: "gomo_claro" (hexágonos), "gomo_escuro" (pentágonos), "costura".
Diâmetro 0,22 m (raio 0,11, o mesmo da bola do intro.gd).
"""
import itertools
import math
import os
import sys

import bpy  # (o bmesh só existe depois do bpy)
import bmesh
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "modelos", "bola.glb")
R = 0.11

bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene


def material(nome, cor, rugoso, brilho=0.5):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*cor, 1.0)
    p.inputs["Roughness"].default_value = rugoso
    if "Specular IOR Level" in p.inputs:
        p.inputs["Specular IOR Level"].default_value = brilho
    return m


MATS = [material("gomo_claro", (0.92, 0.92, 0.93), 0.32), material("gomo_escuro", (0.012, 0.012, 0.016), 0.3),
        material("costura", (0.25, 0.25, 0.27), 0.7, 0.2)]

# vértices do icosaedro truncado: permutações pares de (0, ±1, ±3φ), (±1, ±(2+φ), ±2φ), (±φ, ±2, ±φ³)
fi = (1 + 5 ** 0.5) / 2


def perm_pares(v):
    a, b, c = v
    return [(a, b, c), (b, c, a), (c, a, b)]


base = [(0, 1, 3 * fi), (1, 2 + fi, 2 * fi), (fi, 2, fi ** 3)]
verts = set()
for b in base:
    for p in perm_pares(b):
        for s in itertools.product((-1, 1), repeat=3):
            v = tuple(round(p[i] * s[i], 6) for i in range(3))
            verts.add(v)
verts = [Vector(v).normalized() for v in verts]
assert len(verts) == 60, len(verts)

# faces: para cada direção de face (centro), os vértices mais próximos
# centros: 12 pentágonos (vértices do icosaedro) e 20 hexágonos (do dodecaedro)
ico = []
for s1 in (-1, 1):
    for s2 in (-1, 1):
        for q in [(0, s1, s2 * fi), (s1, s2 * fi, 0), (s2 * fi, 0, s1)]:
            ico.append(Vector(q).normalized())
dode = [Vector(q).normalized() for q in itertools.product((-1, 1), repeat=3)]
for s1 in (-1, 1):
    for s2 in (-1, 1):
        for q in [(0, s1 * fi, s2 / fi), (s1 * fi, s2 / fi, 0), (s2 / fi, 0, s1 * fi)]:
            dode.append(Vector(q).normalized())
assert len(ico) == 12 and len(dode) == 20, (len(ico), len(dode))

# esfera; a malha é CORTADA exatamente nas divisas dos gomos (os arcos de
# círculo máximo das arestas do icosaedro truncado) e nas duas bordas de cada
# costura: as cores ficam com borda reta e lisa, e a costura afunda.
centros = [(c, True) for c in ico] + [(c, False) for c in dode]
arestas = []
lado = min((a - b).length for a, b in itertools.combinations(verts, 2))
for a, b in itertools.combinations(verts, 2):
    if (a - b).length < lado * 1.01:
        arestas.append((a, b, a.cross(b).normalized()))
assert len(arestas) == 90, len(arestas)
H_PENT = max(ico[0].dot(v) for v in verts)
H_HEX = max(dode[0].dot(v) for v in verts)
D = 0.011                       # meia largura da costura (fração do raio)

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=1.0)
bola = bpy.context.active_object
bola.name = "bola"
me = bola.data
bm = bmesh.new()
bm.from_mesh(me)


def perto_do_arco(c, a, b, n, folga, alem=0.02):
    if abs(c.dot(n)) > folga:
        return False
    # entre a e b (no arco curto; "alem" passa um pouco das pontas)
    meio = (a + b).normalized()
    return c.normalized().dot(meio) > math.cos(a.angle(b) / 2.0) - alem


for a, b, n in arestas:
    for off in (-D, 0.0, D):
        faces = [f for f in bm.faces if perto_do_arco(f.calc_center_median(), a, b, n, 0.08)]
        if not faces:
            continue
        geo = faces + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=geo, plane_co=n * off, plane_no=n)
bmesh.ops.triangulate(bm, faces=bm.faces)


def na_costura(c, folga=D):
    for a, b, n in arestas:
        if perto_do_arco(c, a, b, n, folga, 0.0015):
            return True
    return False


for v in bm.verts:
    d = v.co.normalized()
    v.co = d * R * (1.0 - 0.013 if na_costura(d, D * 1.01) else 1.0)
# gomo levemente estufado longe da costura
for v in bm.verts:
    d = v.co.normalized()
    if v.co.length > R * 0.995:
        m_borda = min(abs(d.dot(n)) for a, b, n in arestas if d.dot((a + b).normalized()) > 0.5)
        v.co = d * R * (1.0 + 0.006 * min(1.0, m_borda / 0.3))
for f in bm.faces:
    c = f.calc_center_median().normalized()
    if na_costura(c, D):
        f.material_index = 2
    else:
        # o gomo é a face do poliedro que o raio do centro atravessa:
        # maior c·n/h (h = distância do plano da face ao centro)
        _, escuro = max(centros, key=lambda x: x[0].dot(c) / (H_PENT if x[1] else H_HEX))
        f.material_index = 1 if escuro else 0
    f.smooth = True
bm.to_mesh(me)
bm.free()
for m in MATS:
    me.materials.append(m)
print("vertices", len(bola.data.vertices), "faces", len(bola.data.polygons))

if "--render" in sys.argv:
    pasta = sys.argv[sys.argv.index("--render") + 1]
    os.makedirs(pasta, exist_ok=True)
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.5, 0.35, 1)
    cena.world = w
    luz = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
    luz.data.energy = 4.0
    luz.rotation_euler = (0.7, 0.3, 0.8)
    cena.collection.objects.link(luz)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cena.collection.objects.link(cam)
    cena.camera = cam
    cam.location = (0.35, -0.5, 0.25)
    cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 24
    cena.render.resolution_x = 500
    cena.render.resolution_y = 500
    cena.render.filepath = os.path.join(pasta, "bola.png")
    bpy.ops.render.render(write_still=True)

for o in bpy.data.objects:
    o.select_set(o == bola)
bpy.ops.export_scene.gltf(filepath=SAIDA, export_format="GLB", use_selection=True, export_animations=False,
                          export_tangents=False, export_extras=False, export_yup=True)
print("salvo", SAIDA, os.path.getsize(SAIDA) // 1024, "KB")
