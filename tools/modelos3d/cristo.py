"""Cristo Redentor (Rio): estátua art déco de braços abertos sobre o pedestal.

    /caminho/do/python-com-bpy tools/modelos3d/cristo.py  [--render pasta]

Medidas reais (m): estátua 30 de altura, 28 de braço a braço, pedestal 8.
Túnica com pregas verticais, mangas caindo dos braços, mãos, pescoço,
cabeça com cabelo e barba, coração no peito; pedestal com o terraço em volta.
Material "pedra_sabao". Saída: modelos/cristo.glb (base do pedestal na
origem, de frente para +Y no Blender = -Z no Godot, braços em X).
"""
import math
import os
import sys

import bpy  # (o bmesh só existe depois do bpy)
import bmesh
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "modelos", "cristo.glb")
P = 8.0            # altura do pedestal

bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene

m = bpy.data.materials.new("pedra_sabao")
m.use_nodes = True
pr = m.node_tree.nodes["Principled BSDF"]
pr.inputs["Base Color"].default_value = (0.78, 0.77, 0.71, 1.0)
pr.inputs["Roughness"].default_value = 0.7
m2 = bpy.data.materials.new("pedestal")
m2.use_nodes = True
pr2 = m2.node_tree.nodes["Principled BSDF"]
pr2.inputs["Base Color"].default_value = (0.55, 0.54, 0.5, 1.0)
pr2.inputs["Roughness"].default_value = 0.85


def loft(secoes, seg=48, fechar_topo=True, fechar_base=True, nome="loft"):
    """secoes: lista de (z, rx, ry, cx, cy, func_raio(theta) -> fator)."""
    bm = bmesh.new()
    aneis = []
    for z, rx, ry, cx, cy, fr in secoes:
        anel = []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            k = fr(t)
            anel.append(bm.verts.new((cx + math.cos(t) * rx * k, cy + math.sin(t) * ry * k, z)))
        aneis.append(anel)
    for a, b in zip(aneis, aneis[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if fechar_base:
        bm.faces.new(list(reversed(aneis[0])))
    if fechar_topo:
        bm.faces.new(aneis[-1])
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nome, me)
    cena.collection.objects.link(o)
    for p in me.polygons:
        p.use_smooth = True
    return o


def pregas(amp, n=16):
    return lambda t: 1.0 + amp * (math.sin(t * n) * 0.6 + math.sin(t * n * 0.5 + 1.3) * 0.4)


liso = lambda t: 1.0
# túnica: da barra (pés) até os ombros, com pregas que somem no peito
tunica = loft([
    (P + 0.0, 2.45, 2.0, 0, 0, pregas(0.07)),
    (P + 1.0, 2.35, 1.9, 0, 0, pregas(0.07)),
    (P + 6.0, 2.15, 1.72, 0, 0, pregas(0.06)),
    (P + 12.0, 2.02, 1.62, 0, 0, pregas(0.05)),
    (P + 15.5, 1.95, 1.55, 0, 0.05, pregas(0.03)),      # cintura (cordão)
    (P + 16.0, 2.02, 1.6, 0, 0.05, liso),
    (P + 19.5, 2.35, 1.7, 0, 0.1, pregas(0.015)),
    (P + 22.5, 2.65, 1.72, 0, 0.1, liso),               # peito
    (P + 24.2, 2.9, 1.6, 0, 0.05, liso),                # ombros
    (P + 24.9, 1.8, 1.15, 0, 0.0, liso),
    (P + 25.4, 0.75, 0.72, 0, 0.0, liso),               # pescoço
], nome="tunica")
# pés aparecendo na barra
pes = loft([(P - 0.01, 0.35, 0.9, s * 0.55, 1.4, liso) for s in (1,)] + [(P + 0.5, 0.33, 0.85, 0.55, 1.4, liso)], seg=16, nome="pe1")
pes2 = loft([(P - 0.01, 0.35, 0.9, -0.55, 1.4, liso), (P + 0.5, 0.33, 0.85, -0.55, 1.4, liso)], seg=16, nome="pe2")

# braços (horizontais, em X), mangas largas caindo embaixo e mãos
objs = [tunica, pes, pes2]
for lado in (1, -1):
    # braço: tubo do ombro até o pulso
    secoes = []
    for k in range(9):
        u = k / 8
        x = lado * (1.8 + u * 10.7)
        r = 0.95 - 0.45 * u
        secoes.append((x, r))
    bm = bmesh.new()
    seg = 20
    aneis = []
    for x, r in secoes:
        anel = []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            anel.append(bm.verts.new((x, math.cos(t) * r * 0.9, P + 23.6 + math.sin(t) * r)))
        aneis.append(anel)
    for a, b in zip(aneis, aneis[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            f = bm.faces.new((a[i], a[j], b[j], b[i]) if lado > 0 else (a[j], a[i], b[i], b[j]))
    me = bpy.data.meshes.new("braco")
    bm.to_mesh(me)
    bm.free()
    br = bpy.data.objects.new("braco", me)
    cena.collection.objects.link(br)
    for p in me.polygons:
        p.use_smooth = True
    objs.append(br)
    # manga: pano que cai do braço (triângulo grosso do ombro ao pulso)
    bm = bmesh.new()
    pts = []
    for k in range(7):
        u = k / 6
        x = lado * (2.2 + u * 9.6)
        topo = P + 23.4
        fundo = P + 23.4 - (3.6 - 2.7 * u)          # mais comprida perto do ombro
        for y in (-0.55, 0.55):
            pts.append((bm.verts.new((x, y * (1.0 - 0.4 * u), topo)), bm.verts.new((x, y * (0.6 - 0.3 * u), fundo))))
    for k in range(6):
        a1, a2 = pts[2 * k], pts[2 * k + 1]
        b1, b2 = pts[2 * k + 2], pts[2 * k + 3]
        for f in [(a1[0], b1[0], b1[1], a1[1]), (a2[0], a2[1], b2[1], b2[0]), (a1[1], b1[1], b2[1], a2[1])]:
            bm.faces.new(f if lado > 0 else tuple(reversed(f)))
    me = bpy.data.meshes.new("manga")
    bm.to_mesh(me)
    bm.free()
    mg = bpy.data.objects.new("manga", me)
    cena.collection.objects.link(mg)
    sub = mg.modifiers.new("s", "SUBSURF")
    sub.levels = 2
    for p in me.polygons:
        p.use_smooth = True
    objs.append(mg)
    # mão aberta (palma para a frente, dedos juntos)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1.0, location=(lado * 13.4, 0.05, P + 23.5))
    mao = bpy.context.active_object
    mao.scale = (0.95, 0.28, 0.62)
    for p in mao.data.polygons:
        p.use_smooth = True
    objs.append(mao)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=(lado * 12.8, 0.25, P + 24.0))
    pol = bpy.context.active_object
    pol.scale = (0.45, 0.2, 0.22)
    objs.append(pol)

# cabeça: crânio, rosto, cabelo até os ombros, barba; levemente inclinada
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=18, radius=1.0, location=(0, 0.3, P + 27.1))
cab = bpy.context.active_object
cab.scale = (1.1, 1.22, 1.5)
cab.rotation_euler = (math.radians(-12), 0, 0)
objs.append(cab)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=1.0, location=(0, -0.1, P + 26.7))
cabelo = bpy.context.active_object
cabelo.scale = (1.3, 1.15, 1.75)
objs.append(cabelo)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1.0, location=(0, 0.95, P + 26.0))
barba = bpy.context.active_object
barba.scale = (0.72, 0.48, 0.78)
objs.append(barba)
# coração em relevo no peito
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=(0.45, 1.55, P + 21.6))
cor = bpy.context.active_object
cor.scale = (0.42, 0.15, 0.4)
objs.append(cor)

for o in objs:
    for p in o.data.polygons:
        p.use_smooth = True
    if not o.data.materials:
        o.data.materials.append(m)
    o.select_set(True)
bpy.context.view_layer.objects.active = tunica
for o in objs:
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

# pedestal: bloco art déco com degraus e o terraço
bm = bmesh.new()


def bloco(cx, cy, z0, sx, sy, sz):
    r = bmesh.ops.create_cube(bm, size=1.0)
    for v in r["verts"]:
        v.co = Vector((cx + v.co.x * sx, cy + v.co.y * sy, z0 + (v.co.z + 0.5) * sz))


bloco(0, 0, -2.0, 22.0, 22.0, 2.0)          # terraço
bloco(0, 0, 0.0, 9.5, 9.5, 1.2)
bloco(0, 0, 1.2, 8.2, 8.2, P - 2.0)
bloco(0, 0, P - 0.8, 9.0, 9.0, 0.8)
me = bpy.data.meshes.new("pedestal")
bm.to_mesh(me)
bm.free()
ped = bpy.data.objects.new("pedestal", me)
cena.collection.objects.link(ped)
me.materials.append(m2)

for o in bpy.data.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = tunica
bpy.ops.object.join()
cristo = bpy.context.active_object
cristo.name = "cristo"
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
print("vertices", len(cristo.data.vertices), "faces", len(cristo.data.polygons))

if "--render" in sys.argv:
    pasta = sys.argv[sys.argv.index("--render") + 1]
    os.makedirs(pasta, exist_ok=True)
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.65, 0.85, 1)
    cena.world = w
    luz = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
    luz.data.energy = 4.0
    luz.rotation_euler = (0.9, 0.3, 0.5)
    cena.collection.objects.link(luz)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cena.collection.objects.link(cam)
    cena.camera = cam
    cam.location = (14, 48, 22)
    cam.rotation_euler = (Vector((0, 0, 20)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 24
    cena.render.resolution_x = 700
    cena.render.resolution_y = 600
    cena.render.filepath = os.path.join(pasta, "cristo.png")
    bpy.ops.render.render(write_still=True)

for o in bpy.data.objects:
    o.select_set(o == cristo)
bpy.ops.export_scene.gltf(filepath=SAIDA, export_format="GLB", use_selection=True, export_animations=False,
                          export_tangents=False, export_extras=False, export_yup=True)
print("salvo", SAIDA, os.path.getsize(SAIDA) // 1024, "KB")
