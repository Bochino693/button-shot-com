"""Craque 3D (abertura Lazer & Sport, pódio): corpo inteiro, liso e articulado.

    /caminho/do/python-com-bpy tools/modelos3d/jogador.py  [--render pasta]

Feito no Blender (bpy), sem nada de terceiros:
  * corpo com o modificador Skin (um "esqueleto" de vértices com raio em cada
    ponto: tronco, braços, pernas) + subdivisão = pele contínua, sem emendas;
  * cabeça própria (crânio, queixo, nariz, orelhas) e cabelo;
  * uniforme por regiões do mesmo corpo: camisa com manga curta e gola,
    calção, meião, chuteira; materiais com nome (o jogo pinta com as cores
    do time: camisa, detalhe, calcao, meiao, chuteira, pele, cabelo);
  * esqueleto com os ossos que o jogo anima (nomes iguais às juntas do
    intro.gd) e pesos automáticos (calor) do Blender.
Saída: modelos/jogador.glb (de frente para +Y no Blender = -Z no Godot).
"""
import math
import os
import sys

import bpy  # (o bmesh só existe depois do bpy)
import bmesh
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "modelos", "jogador.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
cena = bpy.context.scene


def material(nome, cor, rugoso=0.6, brilho=0.0):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*cor, 1.0)
    p.inputs["Roughness"].default_value = rugoso
    p.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in p.inputs:
        p.inputs["Specular IOR Level"].default_value = 0.35 + brilho
    return m


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


MAT = {
    "pele": material("pele", srgb("#c08463"), 0.55),
    "camisa": material("camisa", srgb("#ffcc22"), 0.62),
    "detalhe": material("detalhe", srgb("#0d1d52"), 0.6),
    "calcao": material("calcao", srgb("#0d1d52"), 0.65),
    "meiao": material("meiao", srgb("#f4f4f6"), 0.75),
    "chuteira": material("chuteira", srgb("#00a34c"), 0.3, 0.3),
    "cabelo": material("cabelo", srgb("#171009"), 0.75),
    "sola": material("sola", srgb("#f2f2f2"), 0.5),
    "olho": material("olho", srgb("#1a120c"), 0.2, 0.4),
    "boca": material("boca", srgb("#8a4a3a"), 0.6),
}
ORDEM = ["pele", "camisa", "detalhe", "calcao", "meiao", "chuteira", "cabelo", "sola", "olho", "boca"]

# ------------------------------------------------------------ juntas (m)
# mesmas posições das juntas do intro.gd (de frente para +Y aqui)
J = {
    "pelve": Vector((0, 0, 0.95)),
    "tronco": Vector((0, 0, 0.99)),
    "cabeca": Vector((0, 0, 1.65)),
    "ombro_d": Vector((0.215, 0, 1.48)), "ombro_e": Vector((-0.215, 0, 1.48)),
    "cotovelo_d": Vector((0.225, -0.01, 1.19)), "cotovelo_e": Vector((-0.225, -0.01, 1.19)),
    "quadril_d": Vector((0.1, 0, 0.93)), "quadril_e": Vector((-0.1, 0, 0.93)),
    "joelho_d": Vector((0.1, 0.01, 0.49)), "joelho_e": Vector((-0.1, 0.01, 0.49)),
    "tornozelo_d": Vector((0.1, -0.01, 0.075)), "tornozelo_e": Vector((-0.1, -0.01, 0.075)),
}

# ------------------------------------------------------------ corpo (Skin)
# (posição, raio x, raio y) e as ligações
pts = []
lig = []


def ponto(p, rx, ry=None):
    pts.append((Vector(p), rx, ry if ry is not None else rx))
    return len(pts) - 1


def corrente(lista, ini=None):
    ant = ini
    idx = []
    for p in lista:
        i = ponto(*p)
        if ant is not None:
            lig.append((ant, i))
        ant = i
        idx.append(i)
    return idx


coluna = corrente([((0, 0.0, 0.93), 0.165, 0.115), ((0, 0.0, 1.02), 0.15, 0.105), ((0, 0.0, 1.12), 0.148, 0.1),
                   ((0, 0.008, 1.24), 0.17, 0.112), ((0, 0.01, 1.36), 0.19, 0.12), ((0, 0.0, 1.45), 0.175, 0.105),
                   ((0, -0.005, 1.53), 0.07, 0.065), ((0, 0.0, 1.6), 0.055, 0.055)])
quadril, peito = coluna[0], coluna[4]
for lado in (1, -1):
    x = lado
    # braço: do ombro (saindo do peito) até a mão
    ombro = ponto((0.17 * x, 0.0, 1.455), 0.078, 0.075)
    lig.append((coluna[5], ombro))
    corrente([((0.228 * x, 0.0, 1.425), 0.066, 0.064), ((0.232 * x, -0.005, 1.31), 0.058, 0.056),
              ((0.228 * x, -0.01, 1.19), 0.045, 0.046), ((0.23 * x, -0.008, 1.07), 0.047, 0.042),
              ((0.233 * x, 0.0, 0.955), 0.033, 0.028), ((0.236 * x, 0.008, 0.89), 0.042, 0.02),
              ((0.238 * x, 0.012, 0.825), 0.034, 0.016)], ombro)
    # perna: do quadril até o pé
    anca = ponto((0.095 * x, 0.0, 0.9), 0.095, 0.095)
    lig.append((quadril, anca))
    pe = corrente([((0.1 * x, 0.012, 0.72), 0.083, 0.08), ((0.1 * x, 0.012, 0.52), 0.056, 0.056),
                   ((0.1 * x, -0.012, 0.38), 0.062, 0.062), ((0.1 * x, -0.012, 0.2), 0.04, 0.042),
                   ((0.1 * x, -0.012, 0.085), 0.034, 0.038), ((0.1 * x, 0.06, 0.04), 0.045, 0.035),
                   ((0.1 * x, 0.16, 0.03), 0.04, 0.027)], anca)
    # calcanhar
    calc = ponto((0.1 * x, -0.045, 0.045), 0.035, 0.03)
    lig.append((pe[4], calc))

me = bpy.data.meshes.new("corpo")
me.from_pydata([p[0] for p in pts], lig, [])
corpo = bpy.data.objects.new("corpo", me)
cena.collection.objects.link(corpo)
sk = corpo.modifiers.new("skin", "SKIN")
sk.use_smooth_shade = True
sk.branch_smoothing = 0.6
for i, p in enumerate(pts):
    sv = me.skin_vertices[0].data[i]
    sv.radius = (p[1], p[2])
me.skin_vertices[0].data[0].use_root = True
sub = corpo.modifiers.new("sub", "SUBSURF")
sub.levels = 2
sub.render_levels = 2
bpy.context.view_layer.objects.active = corpo
corpo.select_set(True)
bpy.ops.object.modifier_apply(modifier="skin")
bpy.ops.object.modifier_apply(modifier="sub")

# ------------------------------------------------------------ cabeça
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=1.0, location=(0, 0, 0))
cab = bpy.context.active_object
cab.name = "cabeca"
bm = bmesh.new()
bm.from_mesh(cab.data)
for v in bm.verts:
    x, y, z = v.co
    # crânio oval, queixo mais estreito e para a frente, nuca
    sx = 0.088 * (1.0 - 0.18 * max(0.0, -z) ** 1.5)
    sy = 0.105 * (1.0 - 0.1 * max(0.0, -z))
    sz = 0.122
    nx, ny, nz = x * sx, y * sy, z * sz
    if z < -0.2 and y > 0:
        ny += 0.012 * (-z - 0.2) * y            # queixo
    # nariz
    d_n = math.sqrt((x / 0.18) ** 2 + ((z + 0.1) / 0.28) ** 2)
    if y > 0.6 and d_n < 1.0:
        ny += 0.022 * (1 - d_n) ** 1.6
    # sobrancelha
    d_s = abs(z - 0.18)
    if y > 0.55 and d_s < 0.12 and abs(x) < 0.6:
        ny += 0.008 * (1 - d_s / 0.12)
    # olhos (leve fundo)
    for ox in (-0.35, 0.35):
        d_o = math.sqrt(((x - ox) / 0.18) ** 2 + ((z - 0.06) / 0.12) ** 2)
        if y > 0.5 and d_o < 1.0:
            ny -= 0.007 * (1 - d_o)
    v.co = Vector((nx, ny, nz))
bm.to_mesh(cab.data)
bm.free()
for p in cab.data.polygons:
    p.use_smooth = True
cab.location = (0, 0.012, 1.715)
m_ = cab.modifiers.new("sub", "SUBSURF")
m_.levels = 1
bpy.context.view_layer.objects.active = cab
bpy.ops.object.modifier_apply(modifier="sub")
# orelhas
orelhas = []
for lado in (1, -1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=(0.086 * lado, -0.005, 1.71))
    o = bpy.context.active_object
    o.scale = (0.012, 0.022, 0.032)
    for p in o.data.polygons:
        p.use_smooth = True
    orelhas.append(o)

# olhos, sobrancelhas e boca (pequenos, na frente do rosto)
rosto = []
for lado in (1, -1):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=(0.031 * lado, 0.106, 1.726))
    o = bpy.context.active_object
    o.scale = (0.0125, 0.006, 0.0085)
    o.name = "olho"
    rosto.append(o)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.032 * lado, 0.106, 1.745))
    o = bpy.context.active_object
    o.scale = (0.026, 0.006, 0.0045)
    o.rotation_euler = (0, -0.18 * lado, 0)
    o.name = "sobrancelha"
    rosto.append(o)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=(0, 0.106, 1.652))
o = bpy.context.active_object
o.scale = (0.02, 0.006, 0.0045)
o.name = "boca"
rosto.append(o)

# cabelo: casca por cima e atrás do crânio, curto
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=28, radius=1.0, location=(0, 0, 0))
cab_c = bpy.context.active_object
cab_c.name = "cabelo"
bm = bmesh.new()
bm.from_mesh(cab_c.data)
apagar = []
for v in bm.verts:
    x, y, z = v.co
    # linha do cabelo: testa livre na frente, costeleta nos lados (acima da
    # orelha), nuca atrás
    linha = 0.42 * y + 0.02 if y > 0 else 0.02 + 0.5 * y
    if abs(x) > 0.75 and -0.3 < y < 0.35:
        linha = max(linha, 0.1)            # acima da orelha
    if z < linha:
        apagar.append(v)
    v.co = Vector((x * 0.0925, y * 0.1105, z * 0.1275))
bmesh.ops.delete(bm, geom=apagar, context="VERTS")
bm.to_mesh(cab_c.data)
bm.free()
cab_c.location = (0, 0.004, 1.722)
for p in cab_c.data.polygons:
    p.use_smooth = True
bpy.context.view_layer.objects.active = cab_c
m_ = cab_c.modifiers.new("sub", "SUBSURF")
m_.levels = 1
bpy.ops.object.modifier_apply(modifier="sub")
sol = cab_c.modifiers.new("esp", "SOLIDIFY")
sol.thickness = 0.006
sol.offset = 1.0
bpy.ops.object.modifier_apply(modifier="esp")

# ------------------------------------------------------------ juntar e pintar
IDX = {n: i for i, n in enumerate(ORDEM)}


def pintar(o, nome):
    o.data.materials.clear()
    for n in ORDEM:
        o.data.materials.append(MAT[n])
    for p in o.data.polygons:
        p.material_index = IDX[nome]


def regiao(c):
    x, y, z = c
    ax = abs(x)
    if z > 1.535:
        return "pele"                                   # pescoço
    if ax > 0.17 and z > 0.8 and not (z > 1.45 and ax < 0.2):  # braço
        if z > 1.335:
            return "camisa"
        if z > 1.3:
            return "detalhe"                            # barra da manga
        return "pele"
    if z > 1.505:
        return "detalhe"                                # gola
    if z > 0.99:
        return "camisa"
    if z > 0.955:
        return "detalhe"                                # barra da camisa
    if z > 0.68:
        return "calcao"
    if z > 0.535:
        return "pele"                                   # joelho
    if z > 0.51:
        return "detalhe"                                # dobra do meião
    if z > 0.105:
        return "meiao"
    if z < 0.016:
        return "sola"
    return "chuteira"


# corpo: divisas retas (corta nos planos onde muda a cor, sem serrilhado)
bm = bmesh.new()
bm.from_mesh(corpo.data)
for z in (1.535, 1.505, 0.99, 0.955, 0.68, 0.535, 0.51, 0.105, 0.016):
    geo = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geo, plane_co=(0, 0, z), plane_no=(0, 0, 1))
for z in (1.335, 1.3):
    braco = [v for v in bm.verts if abs(v.co.x) > 0.17 and 1.2 < v.co.z < 1.45]
    arestas = list({e for v in braco for e in v.link_edges})
    faces = list({f for v in braco for f in v.link_faces})
    bmesh.ops.bisect_plane(bm, geom=braco + arestas + faces, plane_co=(0, 0, z), plane_no=(0, 0, 1))
bm.to_mesh(corpo.data)
bm.free()
pintar(corpo, "pele")
for p in corpo.data.polygons:
    p.material_index = IDX[regiao(p.center)]
pintar(cab, "pele")
for o in orelhas:
    pintar(o, "pele")
pintar(cab_c, "cabelo")
for o in rosto:
    pintar(o, "cabelo" if o.name.startswith("sobrancelha") else ("olho" if o.name.startswith("olho") else "boca"))

for o in bpy.data.objects:
    o.select_set(o.type == "MESH")
bpy.context.view_layer.objects.active = corpo
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.join()
corpo = bpy.context.active_object
corpo.name = "jogador"

# ------------------------------------------------------------ esqueleto
arm_d = bpy.data.armatures.new("esqueleto")
arm = bpy.data.objects.new("esqueleto", arm_d)
cena.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
for o in bpy.data.objects:
    o.select_set(o == arm)
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_d.edit_bones


def osso(nome, cabeca, cauda, pai=None):
    b = eb.new(nome)
    b.head = cabeca
    b.tail = cauda
    if pai:
        b.parent = eb[pai]
        b.use_connect = False
    return b


osso("pelve", J["pelve"], J["pelve"] + Vector((0, 0, 0.05)))
osso("tronco", J["tronco"], Vector((0, 0, 1.56)), "pelve")
osso("cabeca", J["cabeca"], Vector((0, 0, 1.86)), "tronco")
for s in ("_d", "_e"):
    osso("ombro" + s, J["ombro" + s], J["cotovelo" + s], "tronco")
    osso("cotovelo" + s, J["cotovelo" + s], J["cotovelo" + s] + Vector((0.008 if s == "_d" else -0.008, 0.012, -0.36)), "ombro" + s)
    osso("quadril" + s, J["quadril" + s], J["joelho" + s], "pelve")
    osso("joelho" + s, J["joelho" + s], J["tornozelo" + s], "quadril" + s)
    osso("tornozelo" + s, J["tornozelo" + s], J["tornozelo" + s] + Vector((0, 0.15, -0.04)), "joelho" + s)
bpy.ops.object.mode_set(mode="OBJECT")

for o in bpy.data.objects:
    o.select_set(o in (corpo, arm))
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
# cabeça e cabelo: 100% no osso da cabeça (sem a pele do rosto esticar)
vg = {g.name: g for g in corpo.vertex_groups}
for v in corpo.data.vertices:
    if v.co.z > 1.635:
        for g in list(v.groups):
            corpo.vertex_groups[g.group].remove([v.index])
        vg["cabeca"].add([v.index], 1.0, "REPLACE")
print("vertices", len(corpo.data.vertices), "faces", len(corpo.data.polygons))

if "--render" in sys.argv:
    pasta = sys.argv[sys.argv.index("--render") + 1]
    os.makedirs(pasta, exist_ok=True)
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.55, 0.7, 1)
    cena.world = w
    luz = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN"))
    luz.data.energy = 4.0
    luz.rotation_euler = (0.8, 0.2, 0.6)
    cena.collection.objects.link(luz)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cena.collection.objects.link(cam)
    cena.camera = cam
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 24
    cena.render.resolution_x = 640
    cena.render.resolution_y = 800
    for nome, pos in [("frente", (0.9, 3.2, 1.2)), ("lado", (3.2, 0.4, 1.1)), ("rosto", (0.25, 0.75, 1.72))]:
        cam.location = pos
        alvo = Vector((0, 0, 1.7 if nome == "rosto" else 0.95))
        cam.rotation_euler = (alvo - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 50 if nome != "rosto" else 70
        cena.render.filepath = os.path.join(pasta, nome + ".png")
        bpy.ops.render.render(write_still=True)

os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
for o in bpy.data.objects:
    o.select_set(o in (corpo, arm))
bpy.ops.export_scene.gltf(filepath=SAIDA, export_format="GLB", use_selection=True, export_animations=False,
                          export_def_bones=False, export_leaf_bone=False, export_tangents=False,
                          export_extras=False, export_yup=True, export_apply=False)
print("salvo", SAIDA, os.path.getsize(SAIDA) // 1024, "KB")
