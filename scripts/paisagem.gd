extends Spatial

## PAISAGEM EM VOLTA DO ESTÁDIO 3D: a cidade e o cartão-postal do país do
## time da casa, todos em tamanho de verdade (1 unidade = 1 m; o estádio
## ocupa o raio de ~120 m no meio):
##   BRA  Rio: Corcovado com o Cristo Redentor, Pão de Açúcar, a baía,
##        favelas nos morros, prédios da orla
##   ARG  Buenos Aires: o Obelisco na avenida larga, prédios, o Rio da Prata
##   NOR  Bergen: fiorde, montanhas com neve, casinhas coloridas, barcos
##   FRA  Paris: Torre Eiffel (treliça), o Sena, prédios de mansarda,
##        Sacré-Cœur no morro
##   ALE  Munique: torre olímpica, Frauenkirche (cúpulas verdes), os Alpes
##   AUS  Sydney: Ópera, Harbour Bridge, a baía, as torres do centro
##   ESP  Barcelona: Sagrada Família com os guindastes, Torre Glòries, o
##        quadriculado do Eixample, Montjuïc, o mar
##   ING  Londres: Big Ben, o Parlamento, London Eye (girando), o Tâmisa
##   ITA  Roma: Coliseu com os arcos, a cúpula de São Pedro, pinheiros
##   SUE  Estocolmo: a Prefeitura das três coroas, ilhas, Gamla Stan
##   LAZ  Peri (zona norte de São Paulo), na FÁBRICA da Lazer & Sport: o
##        galpão com telhado em dente de serra e o logo na fachada, o pátio
##        com os brinquedos (torres com escorregador, balanços, gira-gira),
##        caminhões na doca, o bairro nos morros e a Serra da Cantareira
##   (time do pendrive: cidade moderna com morros)
## Tudo em poucas malhas juntas (leve): peças com cor nos vértices e luz
## "pintada" pela direção da face; prédios com o shader de janelas (vidro de
## dia, acesas de noite); água com reflexo do sol/lua; à noite os
## monumentos ficam iluminados e a cidade cheia de luzinhas.

const R_ESTADIO := 125.0
const R_PERTO := 300.0     # perfil leve: até aqui a cidade fica inteira

var leve := false          # perfil TV box: cidade menos densa longe, relevo e carros mais leves
# cartão-postal para a câmera abrir a apresentação (ex.: o Cristo Redentor):
# {"pos": base, "altura": m, "frente": direção para onde olha, "nome": texto}
var postal := {}

var noite := false
var chove := false
var astro := Vector3(0.0, 0.3, -1.0)      # direção do sol/lua (para a água)
var _rng := RandomNumberGenerator.new()
var _luz := Vector3(-0.5, 0.75, 0.45).normalized()
var _amb := 0.62
var _dif := 0.46
var _st: SurfaceTool
var _sp: SurfaceTool
var _sl: SurfaceTool
var _sa: SurfaceTool          # monumentos iluminados à noite (luz própria)
var _m_pos := PoolVector3Array()   # morros e montanhas (shaders/terreno.shader):
var _m_nor := PoolVector3Array()   # todos numa malha só, montada com arrays
var _m_cor := PoolColorArray()
var _m_idx := PoolIntArray()
var _nv := [0, 0, 0, 0, 0]
var _n_largo := OpenSimplexNoise.new()     # relevo: ondulação grande
var _n_crista := OpenSimplexNoise.new()    # cristas e vales
var _ocupado := []        # reservas grandes (cartões-postais): [Vector2 centro xz, raio]
var _grade_ocup := {}     # reservas pequenas por célula de 32 m: Vector2 célula -> [[centro, raio]]
const CEL := 32.0
const R_PEQ := 24.0       # até esse raio a reserva vai para a grade
var _aguas := []          # Rect2 (xz)
var _morros := []         # [Vector2 centro, raio, altura, forma, rugas, fase]
var _anim := []           # [Spatial, Vector3 eixo, velocidade]
var _pisca := []          # [MeshInstance, fase, cor]
var _t := 0.0
# grade de ruas (o chão desenha as ruas; os prédios ficam nos quarteirões)
var _q := 0.0             # passo da grade (0 = sem ruas)
var _r_rua := 14.0
var _calc := 3.5
var _raio_cidade := 760.0
var _varandas := 0.0      # chance de prédio com sacadas (Rio, Barcelona...)
var _tipo_mata := "copa"  # árvores das encostas: "copa" ou "pinheiro"
var _corredor := []       # caminho da câmera: [Vector2, raio] (só construção baixa)
# INSTÂNCIAS (MultiMesh): cada prédio/caixa/casa/árvore é uma cópia de uma
# peça única; quase nada de CPU para montar e poucos desenhos para a GPU
var _i_predios := []      # [Transform, Color(cor, janelas)]
var _i_caixas := []       # [Transform, Color]
var _i_casas := []        # [Transform, Color parede, Color telhado]
var _i_formas := {"mansarda": [], "telha": []}   # telhados: [Transform, Color]
var _i_arvores := {}      # tipo -> [[Transform, Color]]


func montar(sigla: String, clima: String) -> void:
	noite = clima.begins_with("noite")
	chove = clima == "chuva" or clima == "noite_chuva"
	_rng.seed = hash(sigla + "paisagem")
	if noite:
		_amb = 0.34
		_dif = 0.24
		_luz = Vector3(0.45, 0.7, 0.55).normalized()
	elif chove:
		_amb = 0.66
		_dif = 0.2
	_st = _nova()
	_sp = _nova()
	_sl = _nova()
	_sa = _nova()
	_n_largo.seed = _rng.randi()
	_n_largo.octaves = 3
	_n_largo.period = 260.0
	_n_crista.seed = _rng.randi()
	_n_crista.octaves = 4
	_n_crista.period = 95.0
	_n_crista.persistence = 0.55
	# o caminho da câmera da vista da cidade fica livre (nada de prédio
	# tampando o estádio e o cartão-postal)
	for k in range(14):
		var u := float(k) / 13.0
		_corredor.append([Vector2(lerp(30.0, 150.0, u), lerp(110.0, 520.0, u)), 60.0 + 40.0 * u])
	var sel := Jogo.selecao(sigla)
	var chave := sigla if not sel.get("extra", false) else "EXTRA"
	match chave:
		"BRA":
			_rio()
		"ARG":
			_buenos_aires()
		"NOR":
			_bergen()
		"FRA":
			_paris()
		"ALE":
			_munique()
		"AUS":
			_sydney()
		"ESP":
			_barcelona()
		"ING":
			_londres()
		"ITA":
			_roma()
		"SUE":
			_estocolmo()
		"LAZ":
			_peri()
		_:
			_cidade_moderna()
	_carros(min(_raio_cidade, 520.0), 110 if leve else 320)
	_fechar()


## Um MultiMesh com todas as cópias de uma peça: [Transform, Color(, custom)].
func _instancias(lista: Array, malha: Mesh, material: Material) -> void:
	if lista.empty():
		return
	if leve and lista.size() > 120:
		# TV box: longe do estádio fica 1 de cada 2 (a neblina disfarça)
		var fina := []
		for i in range(lista.size()):
			var o: Vector3 = lista[i][0].origin
			if Vector2(o.x, o.z).length() < R_PERTO or i % 2 == 0:
				fina.append(lista[i])
		lista = fina
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.color_format = MultiMesh.COLOR_8BIT
	var custom: bool = lista[0].size() > 2
	if custom:
		mm.custom_data_format = MultiMesh.CUSTOM_DATA_8BIT
	mm.mesh = malha
	mm.instance_count = lista.size()
	for i in range(lista.size()):
		var it: Array = lista[i]
		mm.set_instance_transform(i, it[0])
		mm.set_instance_color(i, it[1])
		if custom:
			mm.set_instance_custom_data(i, it[2])
	var mmi := MultiMeshInstance.new()
	mmi.multimesh = mm
	mmi.material_override = material
	add_child(mmi)


## Caixa de lado 1 centrada (sem o fundo), branca.
func _malha_caixa() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := _cantos(Vector3.ZERO, Vector3.ONE, 0.0)
	var normais := [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for i in range(1, 6):
		var f: Array = FACES[i]
		for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_color(Color(1, 1, 1, 1))
			st.add_normal(normais[i])
			st.add_vertex(p[idx])
	return st.commit()


## Casa de lado 1: paredes de y 0 a 1, telhado de duas águas até 1,45 com
## beiral (UV.x = 1 no telhado).
func _malha_casa() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := _cantos(Vector3(0, 0.5, 0), Vector3.ONE, 0.0)
	var normais := [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for i in [2, 3, 4, 5]:
		var f: Array = FACES[i]
		for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_color(Color(1, 1, 1))
			st.add_uv(Vector2(0, 0))
			st.add_normal(normais[i])
			st.add_vertex(p[idx])
	var e := 0.06
	var a0 := Vector3(-0.5 - e, 1, -0.5 - e)
	var a1 := Vector3(0.5 + e, 1, -0.5 - e)
	var b0 := Vector3(-0.5 - e, 1, 0.5 + e)
	var b1 := Vector3(0.5 + e, 1, 0.5 + e)
	var r0 := Vector3(-0.5 - e, 1.45, 0)
	var r1 := Vector3(0.5 + e, 1.45, 0)
	var tri := [[a0, a1, r1, Vector3(0, 0.75, -0.66), 1.0], [a0, r1, r0, Vector3(0, 0.75, -0.66), 1.0],
		[b1, b0, r0, Vector3(0, 0.75, 0.66), 1.0], [b1, r0, r1, Vector3(0, 0.75, 0.66), 1.0],
		[Vector3(-0.5, 1, -0.5), Vector3(-0.5, 1, 0.5), Vector3(-0.5, 1.45, 0), Vector3.LEFT, 0.0],
		[Vector3(0.5, 1, 0.5), Vector3(0.5, 1, -0.5), Vector3(0.5, 1.45, 0), Vector3.RIGHT, 0.0]]
	for t in tri:
		for k in range(3):
			st.add_color(Color(1, 1, 1))
			st.add_uv(Vector2(t[4], 0))
			st.add_normal(t[3].normalized())
			st.add_vertex(t[k])
	return st.commit()


## Telhado de lado 1 e altura 1: "mansarda" (tronco de pirâmide) ou "telha"
## (duas águas, cumeeira em x).
func _malha_telhado(forma: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var topo := Vector2(0.7, 0.62) if forma == "mansarda" else Vector2(1.0, 0.04)
	var p := []
	for nivel in [0, 1]:
		var t: Vector2 = Vector2.ONE if nivel == 0 else topo
		for i in range(4):
			var sx := 1.0 if (i == 1 or i == 2) else -1.0
			var sz := 1.0 if i >= 2 else -1.0
			p.append(Vector3(sx * t.x * 0.5, float(nivel), sz * t.y * 0.5))
	var faces := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7]]
	for f in faces:
		var n: Vector3 = (p[f[1]] - p[f[0]]).cross(p[f[2]] - p[f[0]]).normalized()
		if n.dot((p[f[0]] + p[f[2]]) * 0.5 - Vector3(0, 0.3, 0)) < 0.0:
			n = -n
		for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.add_color(Color(1, 1, 1))
			st.add_normal(n)
			st.add_vertex(p[idx])
	return st.commit()


## Carro pequeno (4,4 m) de frente para -Z: lataria branca (a cor vem da
## instância), cabine com vidro escuro, rodas, faróis (UV.x = 1) e
## lanternas (UV.x = 2).
func _carro_malha() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pecas := [
		# [centro, tamanho, cor, marca]
		[Vector3(0, 0.62, 0), Vector3(1.78, 0.62, 4.3), Color(1, 1, 1), 0.0],                # lataria
		[Vector3(0, 1.12, 0.25), Vector3(1.56, 0.5, 2.3), Color(0.12, 0.14, 0.18), 0.0],      # cabine (vidro)
		[Vector3(0, 1.39, 0.25), Vector3(1.5, 0.06, 2.0), Color(1, 1, 1), 0.0],               # teto
		[Vector3(-0.62, 0.72, -2.16), Vector3(0.36, 0.16, 0.04), Color(1, 0.97, 0.85), 1.0],  # faróis
		[Vector3(0.62, 0.72, -2.16), Vector3(0.36, 0.16, 0.04), Color(1, 0.97, 0.85), 1.0],
		[Vector3(-0.66, 0.74, 2.16), Vector3(0.3, 0.14, 0.04), Color(0.7, 0.05, 0.05), 2.0],  # lanternas
		[Vector3(0.66, 0.74, 2.16), Vector3(0.3, 0.14, 0.04), Color(0.7, 0.05, 0.05), 2.0],
	]
	for z in [-1.35, 1.35]:
		for x in [-0.86, 0.86]:
			pecas.append([Vector3(x, 0.33, z), Vector3(0.24, 0.66, 0.66), Color(0.06, 0.06, 0.07), 0.0])
	var normais := [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for pc in pecas:
		var p := _cantos(pc[0], pc[1], 0.0)
		for i in range(1, 6):
			var f: Array = FACES[i]
			for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
				st.add_color(pc[2])
				st.add_uv(Vector2(pc[3], 0))
				st.add_normal(normais[i])
				st.add_vertex(p[idx])
	return st.commit()


## Trânsito: carros nas duas mãos de cada quadra de rua perto do estádio.
func _carros(raio: float, n_max := 320) -> void:
	if _q <= 0.0:
		return
	var cores := [Color(0.92, 0.92, 0.94), Color(0.1, 0.1, 0.12), Color(0.6, 0.62, 0.66), Color(0.75, 0.1, 0.1),
		Color(0.12, 0.25, 0.6), Color(0.85, 0.85, 0.82), Color(0.35, 0.36, 0.4), Color(0.95, 0.75, 0.1)]
	var lista := []
	var comp := _q - _r_rua - 2.0
	var n := int(ceil(raio / _q))
	for k in range(-n, n + 1):
		for j in range(-n, n):
			for eixo in [0, 1]:
				# trecho entre dois cruzamentos: rua em x = k*q (anda em z) ou z = k*q
				var meio := Vector2(k * _q, (j + 0.5) * _q) if eixo == 0 else Vector2((j + 0.5) * _q, k * _q)
				var r := meio.length()
				if r < R_ESTADIO + 25.0 or r > raio or _na_agua(meio.x, meio.y, 4.0) or altura_em(meio.x, meio.y) > 0.5:
					continue
				if _monumento_em(meio.x, meio.y):
					continue
				for mao in [-1.0, 1.0]:
					var quantos := _rng.randi() % 3
					for _c in range(quantos):
						var desl = mao * _r_rua * 0.25
						var pos := Vector3(meio.x + (desl if eixo == 0 else 0.0), 0.0, meio.y + (desl if eixo == 1 else 0.0))
						# -Z local = sentido da mão
						var giro: float = (0.0 if mao < 0 else PI) if eixo == 0 else (PI * 0.5 if mao < 0 else -PI * 0.5)
						lista.append([Transform(Basis(Vector3.UP, giro), pos), cores[_rng.randi() % cores.size()],
							Color(_rng.randf_range(7.0, 13.0), comp, _rng.randf() * comp, 0)])
	if lista.empty():
		return
	while lista.size() > n_max:
		lista.remove(_rng.randi() % lista.size())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.color_format = MultiMesh.COLOR_8BIT
	mm.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT
	mm.mesh = _carro_malha()
	mm.instance_count = lista.size()
	for i in range(lista.size()):
		mm.set_instance_transform(i, lista[i][0])
		mm.set_instance_color(i, lista[i][1])
		mm.set_instance_custom_data(i, lista[i][2])
	var mmi := MultiMeshInstance.new()
	mmi.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/carro.shader")
	sm.set_shader_param("noite", 1.0 if noite else 0.0)
	mmi.material_override = sm
	add_child(mmi)


## Perto de um cartão-postal (reserva grande): ali não passa carro.
func _monumento_em(x: float, z: float) -> bool:
	for o in _ocupado:
		if o[1] >= 20.0 and Vector2(x, z).distance_to(o[0]) < o[1] + 8.0:
			return true
	return false


## Uma árvore (malha pequena, com cor nos vértices) para a mata instanciada.
func _arvore_malha(tipo: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tronco := _base(Color(0.36, 0.26, 0.18))
	var folha := _base(Color(0.13, 0.3, 0.15) if tipo == "pinheiro" else Color(0.17, 0.36, 0.15))
	var mata := tipo.begins_with("mata_")
	tipo = tipo.trim_prefix("mata_")
	var seg := 6 if not mata else 5
	# tronco (a mata de longe nem precisa)
	for i in range(seg if not mata else 0):
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		for v in [[d0 * 0.45, d0], [d1 * 0.45, d1], [d1 * 0.3 + Vector3(0, 4.0, 0), d1], [d0 * 0.45, d0], [d1 * 0.3 + Vector3(0, 4.0, 0), d1], [d0 * 0.3 + Vector3(0, 4.0, 0), d0]]:
			st.add_color(tronco)
			st.add_normal(v[1])
			st.add_vertex(v[0])
	if tipo == "pinheiro":
		# dois cones empilhados
		for c in [[2.0, 3.6, 7.0], [5.5, 2.6, 6.5]]:
			var base := Vector3(0, c[0], 0)
			var topo := Vector3(0, c[0] + c[2], 0)
			for i in range(seg):
				var a0 := TAU * i / seg
				var a1 := TAU * (i + 1) / seg
				var p0 = base + Vector3(cos(a0), 0, sin(a0)) * c[1]
				var p1 = base + Vector3(cos(a1), 0, sin(a1)) * c[1]
				var n0 := Vector3(cos(a0), 0.55, sin(a0)).normalized()
				var n1 := Vector3(cos(a1), 0.55, sin(a1)).normalized()
				for v in [[p0, n0, 0.85], [p1, n1, 0.85], [topo, (n0 + n1).normalized(), 1.15]]:
					st.add_color(folha * v[2])
					st.add_normal(v[1])
					st.add_vertex(v[0])
	else:
		# copa: esfera achatada irregular; guarda-chuva (pinheiro de Roma):
		# tronco alto e copa larga e chata
		var alta := tipo == "guarda_chuva"
		var c0 := Vector3(0, 12.0 if alta else 6.2, 0)
		var aneis := [[-1.0, 0.0, 0.0], [-0.4, 3.4, 0.75], [0.5, 3.4, 1.0], [1.0, 0.0, 1.2]]
		if mata:
			aneis = [[-0.8, 0.0, 0.0], [0.0, 3.6, 0.85], [1.0, 0.0, 1.2]]
		if alta:
			aneis = [[-0.5, 0.0, 0.0], [-0.2, 6.0, 0.8], [0.2, 5.4, 1.0], [0.5, 0.0, 1.15]]
			for i in range(seg):
				var a0 := TAU * i / seg
				var a1 := TAU * (i + 1) / seg
				var d0 := Vector3(cos(a0), 0, sin(a0))
				var d1 := Vector3(cos(a1), 0, sin(a1))
				for v in [[d0 * 0.3 + Vector3(0, 4, 0), d0], [d1 * 0.3 + Vector3(0, 4, 0), d1], [d1 * 0.25 + Vector3(0, 11, 0), d1], [d0 * 0.3 + Vector3(0, 4, 0), d0], [d1 * 0.25 + Vector3(0, 11, 0), d1], [d0 * 0.25 + Vector3(0, 11, 0), d0]]:
					st.add_color(tronco)
					st.add_normal(v[1])
					st.add_vertex(v[0])
		for k in range(aneis.size() - 1):
			var A: Array = aneis[k]
			var B: Array = aneis[k + 1]
			for i in range(7):
				var a0 := TAU * i / 7.0
				var a1 := TAU * (i + 1) / 7.0
				var q := []
				for par in [[A, a0], [A, a1], [B, a1], [B, a0]]:
					var anel: Array = par[0]
					var d := Vector3(cos(par[1]), 0, sin(par[1]))
					q.append([c0 + d * anel[1] + Vector3(0, anel[0] * 3.0, 0), (d * anel[1] / 3.9 + Vector3(0, anel[0], 0)).normalized(), anel[2]])
				for idx in [0, 1, 2, 0, 2, 3]:
					st.add_color(folha * q[idx][2])
					st.add_normal(q[idx][1])
					st.add_vertex(q[idx][0])
	return st.commit()


func _nova() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _fechar() -> void:
	var lit := SpatialMaterial.new()
	lit.vertex_color_use_as_albedo = true
	lit.roughness = 0.85
	if not _i_predios.empty():
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/predio.shader")
		sm.set_shader_param("noite", 1.0 if noite else 0.0)
		sm.set_shader_param("chuva", 1.0 if chove else 0.0)
		if chove and not noite:
			sm.set_shader_param("vidro", Color(0.42, 0.46, 0.52))
			sm.set_shader_param("ceu", Color(0.5, 0.54, 0.6))
		_instancias(_i_predios, _malha_caixa(), sm)
	_instancias(_i_caixas, _malha_caixa(), lit)
	if not _i_casas.empty():
		var mc := ShaderMaterial.new()
		mc.shader = load("res://shaders/casa.shader")
		_instancias(_i_casas, _malha_casa(), mc)
	for forma in _i_formas:
		_instancias(_i_formas[forma], _malha_telhado(forma), lit)
	for tipo in _i_arvores:
		_instancias(_i_arvores[tipo], _arvore_malha(tipo), lit)
	if _m_idx.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = _m_pos
		arr[Mesh.ARRAY_NORMAL] = _m_nor
		arr[Mesh.ARRAY_COLOR] = _m_cor
		arr[Mesh.ARRAY_INDEX] = _m_idx
		var malha := ArrayMesh.new()
		malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mm := MeshInstance.new()
		mm.mesh = malha
		var mt := ShaderMaterial.new()
		mt.shader = load("res://shaders/terreno.shader")
		mm.material_override = mt
		add_child(mm)
	if _nv[0] > 0:
		var mi := MeshInstance.new()
		mi.mesh = _st.commit()
		mi.material_override = _mat_vertices()
		add_child(mi)
	if _nv[3] > 0:
		var ma := MeshInstance.new()
		ma.mesh = _sa.commit()
		var m3 := SpatialMaterial.new()
		m3.flags_unshaded = true
		m3.vertex_color_use_as_albedo = true
		m3.params_cull_mode = SpatialMaterial.CULL_DISABLED
		ma.material_override = m3
		add_child(ma)
	if _nv[1] > 0:
		var mp := MeshInstance.new()
		mp.mesh = _sp.commit()
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/predio.shader")
		sm.set_shader_param("noite", 1.0 if noite else 0.0)
		sm.set_shader_param("chuva", 1.0 if chove else 0.0)
		if chove and not noite:
			sm.set_shader_param("vidro", Color(0.42, 0.46, 0.52))
		mp.material_override = sm
		add_child(mp)
	if _nv[2] > 0:
		var ml := MeshInstance.new()
		ml.mesh = _sl.commit()
		var m2 := SpatialMaterial.new()
		m2.flags_unshaded = true
		m2.flags_transparent = true
		m2.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
		m2.params_cull_mode = SpatialMaterial.CULL_DISABLED
		m2.vertex_color_use_as_albedo = true
		m2.albedo_texture = load("res://imagens/brilho.png")
		ml.material_override = m2
		add_child(ml)


func _process(delta: float) -> void:
	_t += delta
	for a in _anim:
		a[0].rotate(a[1], delta * a[2])
	for p in _pisca:
		var k := 0.55 + 0.45 * sin(_t * 3.0 + p[1])
		var c: Color = p[2]
		p[0].material_override.albedo_color = Color(c.r, c.g, c.b, c.a * k)


# ================================================================ cores
## Material das peças (cor nos vértices) com a luz de verdade da cena.
func _mat_vertices() -> SpatialMaterial:
	var m := SpatialMaterial.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	return m


## Cor de base (a luz da cena faz o resto; na chuva, mais acinzentada).
func _base(c: Color) -> Color:
	if chove:
		var cinza := (c.r + c.g + c.b) / 3.0
		return c.linear_interpolate(Color(cinza, cinza, cinza * 1.05), 0.25)
	return c


## Cor "pintada" com luz (só para o que brilha sozinho: monumentos acesos).
func _cor(c: Color, n: Vector3, acesa := false) -> Color:
	var k := _amb + _dif * max(0.0, n.dot(_luz))
	if noite:
		if acesa:
			var kk := 0.72 + 0.28 * max(0.0, n.dot(Vector3(0.2, 0.3, 1.0).normalized()))
			return Color(c.r * kk * 1.08, c.g * kk * 0.98, c.b * kk * 0.84)
		return Color(c.r * k * 0.62, c.g * k * 0.7, c.b * k * 0.95)
	var r := Color(c.r * k, c.g * k, c.b * k)
	if chove:
		var cinza := (r.r + r.g + r.b) / 3.0
		r = r.linear_interpolate(Color(cinza, cinza, cinza * 1.05), 0.3)
	return r


func _tri(a: Vector3, b: Vector3, c: Vector3, cor: Color, centro: Vector3, acesa := false) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - centro) < 0.0:
		n = -n
	if acesa and noite:
		# monumento iluminado: luz própria, quente (malha sem luz da cena)
		var k := _cor(cor, n, true)
		for v in [a, b, c]:
			_sa.add_color(k)
			_sa.add_vertex(_mt(v))
		_nv[3] += 3
		return
	var k2 := _base(cor)
	for v in [a, b, c]:
		_st.add_color(k2)
		_st.add_normal(n)
		_st.add_vertex(v)
	_nv[0] += 3


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cor: Color, centro: Vector3, acesa := false) -> void:
	_tri(a, b, c, cor, centro, acesa)
	_tri(a, c, d, cor, centro, acesa)


# ============================================================ formas
const FACES := [[0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 3, 2], [4, 5, 7, 6]]


func _cantos(c: Vector3, t: Vector3, giro: float) -> Array:
	var b := Basis(Vector3.UP, giro)
	var h := t * 0.5
	var p := []
	for i in range(8):
		var v := Vector3(h.x * (1.0 if i & 1 else -1.0), h.y * (1.0 if i & 2 else -1.0), h.z * (1.0 if i & 4 else -1.0))
		p.append(c + b.xform(v))
	return p


## Caixa (centro, tamanho), girada no eixo Y; topo com outra cor se quiser.
func _caixa(c: Vector3, t: Vector3, cor: Color, giro := 0.0, cor_topo = null, acesa := false) -> void:
	var p := _cantos(c, t, giro)
	for i in range(6):
		var f: Array = FACES[i]
		var k: Color = cor_topo if (i == 1 and cor_topo != null) else cor
		_quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], k, c, acesa)


## Tronco de pirâmide/prisma: base (centro do chão) com tamanho t0 (x,z),
## topo com t1 (x,z), altura h.
func _tronco(base: Vector3, t0: Vector2, t1: Vector2, h: float, cor: Color, giro := 0.0, acesa := false) -> void:
	var b := Basis(Vector3.UP, giro)
	var p := []
	for nivel in [0, 1]:
		var t: Vector2 = t0 if nivel == 0 else t1
		for i in range(4):
			var sx := 1.0 if (i == 1 or i == 2) else -1.0
			var sz := 1.0 if i >= 2 else -1.0
			p.append(base + b.xform(Vector3(sx * t.x * 0.5, h * nivel, sz * t.y * 0.5)))
	var c := base + Vector3(0, h * 0.5, 0)
	for i in range(4):
		var j := (i + 1) % 4
		_quad(p[i], p[j], p[j + 4], p[i + 4], cor, c, acesa)
	_quad(p[4], p[5], p[6], p[7], cor, c, acesa)


## Cilindro/cone: base no chão (centro), raios embaixo/em cima, altura.
func _cilindro(base: Vector3, r0: float, r1: float, h: float, seg: int, cor: Color, acesa := false, giro := 0.0, cor_topo = null) -> void:
	var c := base + Vector3(0, h * 0.5, 0)
	var topo := base + Vector3(0, h, 0)
	for i in range(seg):
		var a0 := giro + TAU * i / seg
		var a1 := giro + TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p00 := base + d0 * r0
		var p10 := base + d1 * r0
		var p01 := topo + d0 * r1
		var p11 := topo + d1 * r1
		if r1 > 0.001:
			_quad(p00, p10, p11, p01, cor, c, acesa)
			_tri(topo, p01, p11, cor_topo if cor_topo != null else cor, c - Vector3(0, h, 0), acesa)
		else:
			_tri(p00, p10, topo, cor, c, acesa)


func _cone(base: Vector3, r: float, h: float, seg: int, cor: Color, acesa := false) -> void:
	_cilindro(base, r, 0.0, h, seg, cor, acesa)


## Esfera (ou meia esfera de cima), achatável com esc.
func _esfera(c: Vector3, r: float, cor: Color, esc := Vector3.ONE, meia := false, acesa := false, seg := 14, aneis := 8) -> void:
	var a_ini := 0 if not meia else aneis / 2
	for i in range(a_ini, aneis):
		var t0 := PI * float(i) / aneis - PI * 0.5
		var t1 := PI * float(i + 1) / aneis - PI * 0.5
		for j in range(seg):
			var f0 := TAU * j / seg
			var f1 := TAU * (j + 1) / seg
			var v := []
			for q in [[t0, f0], [t0, f1], [t1, f1], [t1, f0]]:
				var p := Vector3(cos(q[0]) * cos(q[1]), sin(q[0]), cos(q[0]) * sin(q[1])) * r
				v.append(c + Vector3(p.x * esc.x, p.y * esc.y, p.z * esc.z))
			_quad(v[0], v[1], v[2], v[3], cor, c, acesa)


## Casa com telhado de duas águas (cumeeira ao longo do x local).
func _casa(base: Vector3, w: float, d: float, h: float, ht: float, parede: Color, telhado: Color, giro := 0.0) -> void:
	if _em_marco:
		_casa_malha(base, w, d, h, ht, parede, telhado, giro)
		return
	# peça única: paredes de 0 a 1 e telhado de 1 a 1,45 (em y) -> escala (w, h, d)
	var b := Basis(Vector3.UP, giro) * Basis().scaled(Vector3(w, h, d))
	_i_casas.append([Transform(b, base), _base(parede), _base(telhado)])


func _casa_malha(base: Vector3, w: float, d: float, h: float, ht: float, parede: Color, telhado: Color, giro := 0.0) -> void:
	_caixa(base + Vector3(0, h * 0.5, 0), Vector3(w, h, d), parede, giro)
	var b := Basis(Vector3.UP, giro)
	var e := 0.4
	var y := h
	var a0 := base + b.xform(Vector3(-w * 0.5 - e, y, -d * 0.5 - e))
	var a1 := base + b.xform(Vector3(w * 0.5 + e, y, -d * 0.5 - e))
	var b0 := base + b.xform(Vector3(-w * 0.5 - e, y, d * 0.5 + e))
	var b1 := base + b.xform(Vector3(w * 0.5 + e, y, d * 0.5 + e))
	var r0 := base + b.xform(Vector3(-w * 0.5 - e, y + ht, 0))
	var r1 := base + b.xform(Vector3(w * 0.5 + e, y + ht, 0))
	var c := base + Vector3(0, y, 0)
	_quad(a0, a1, r1, r0, telhado, c)
	_quad(b0, b1, r1, r0, telhado, c)
	_tri(a0, b0, r0, parede, c)
	_tri(a1, b1, r1, parede, c)


## Caixa instanciada (luz da cena): detalhes de prédio, casinhas da favela.
func _caixa_i(c: Vector3, t: Vector3, cor: Color, giro := 0.0) -> void:
	var b := Basis(Vector3.UP, giro) * Basis().scaled(t)
	_i_caixas.append([Transform(b, c), _base(cor)])


## Prédio com janelas (shader). janelas: 0..1 (densidade das janelas).
func _predio(base: Vector3, t: Vector3, cor: Color, giro := 0.0, janelas := 1.0) -> void:
	if _em_marco:
		_predio_malha(base, t, cor, giro, janelas)
		return
	var b := Basis(Vector3.UP, giro) * Basis().scaled(t)
	var k := _base(cor)
	_i_predios.append([Transform(b, base + Vector3(0, t.y * 0.5, 0)), Color(k.r, k.g, k.b, janelas)])


func _predio_malha(base: Vector3, t: Vector3, cor: Color, giro := 0.0, janelas := 1.0) -> void:
	var c := base + Vector3(0, t.y * 0.5, 0)
	var p := _cantos(c, t, giro)
	var b := Basis(Vector3.UP, giro)
	var normais := [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for i in range(1, 6):
		var f: Array = FACES[i]
		var n: Vector3 = b.xform(normais[i])
		var k := Color(cor.r, cor.g, cor.b, janelas if i != 1 else 0.0)
		for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			_sp.add_color(k)
			_sp.add_normal(n)
			_sp.add_vertex(p[idx])
		_nv[1] += 6


## Acabamento do prédio: térreo recuado, cornija no alto, casa de máquinas,
## caixa d'água e (às vezes) sacadas em todos os andares da frente e do fundo.
func _detalhes_predio(base: Vector3, t: Vector3, cor: Color, giro: float, terraco := true) -> void:
	var b := Basis(Vector3.UP, giro)
	var escura := cor.darkened(0.28)
	# cornija (laje saliente no topo) e faixa no 1º andar
	_caixa_i(base + Vector3(0, t.y + 0.25, 0), Vector3(t.x + 0.9, 0.7, t.z + 0.9), escura, giro)
	_caixa_i(base + Vector3(0, 4.6, 0), Vector3(t.x + 0.5, 0.45, t.z + 0.5), escura, giro)
	if terraco:
		var n := 1 + _rng.randi() % 2
		for i in range(n):
			var off := Vector3(_rng.randf_range(-0.3, 0.3) * t.x, 0, _rng.randf_range(-0.3, 0.3) * t.z)
			var tam := Vector3(_rng.randf_range(2.5, 5.0), _rng.randf_range(2.0, 3.5), _rng.randf_range(2.5, 5.0))
			_caixa_i(base + b.xform(off) + Vector3(0, t.y + 0.6 + tam.y * 0.5, 0), tam, Color(0.72, 0.72, 0.7), giro)
		if _rng.randf() < 0.4:
			var q := base + b.xform(Vector3(t.x * 0.28, 0, -t.z * 0.25)) + Vector3(0, t.y + 1.9, 0)
			_caixa_i(q, Vector3(2.8, 2.6, 2.8), Color(0.55, 0.6, 0.66), giro + PI * 0.25)
	# sacadas: uma peça (laje + parapeito) por andar, na frente (rua)
	if _varandas > 0.0 and _rng.randf() < _varandas and t.y < 70.0:
		var andares := int((t.y - 5.0) / 3.4)
		var claro := cor.lightened(0.12)
		var lado := -1.0
		for k in range(andares):
			var y := 5.8 + k * 3.4
			var c := base + b.xform(Vector3(0, 0, lado * (t.z * 0.5 + 0.6))) + Vector3(0, y, 0)
			_caixa_i(c, Vector3(t.x * 0.86, 1.0, 1.2), claro, giro)


## Luzinha da noite (dois quadrados cruzados, aditivos).
func _ponto_luz(p: Vector3, tam: float, cor: Color) -> void:
	if _em_marco:
		p = _mt(p)
		tam *= _marco_e
	for eixo in [Vector3.RIGHT, Vector3.BACK]:
		var lado: Vector3 = eixo * tam * 0.5
		var cima := Vector3(0, tam * 0.5, 0)
		var v := [p - lado - cima, p + lado - cima, p + lado + cima, p - lado + cima]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			_sl.add_color(cor)
			_sl.add_uv(uv[i])
			_sl.add_vertex(v[i])
		_nv[2] += 6


## Brilho solto (billboard), para halos de monumentos e luzes que piscam.
func _brilho(p: Vector3, tam: float, cor: Color, pisca := false) -> MeshInstance:
	if _em_marco:
		p = _mt(p)
		tam *= _marco_e
	var mi := MeshInstance.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(tam, tam)
	mi.mesh = qm
	var m := SpatialMaterial.new()
	m.flags_unshaded = true
	m.flags_transparent = true
	m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	m.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
	m.albedo_texture = load("res://imagens/brilho.png")
	m.albedo_color = cor
	mi.material_override = m
	mi.translation = p
	add_child(mi)
	if pisca:
		_pisca.append([mi, _rng.randf() * TAU, cor])
	return mi


# ======================================================= monumentos
## Um monumento é montado numa malha própria e AUMENTADO em volta da base
## (cartão-postal bem visível atrás do estádio); brilhos, luzes e a área
## reservada acompanham a escala.
var _em_marco := false
var _marco_base := Vector3()
var _marco_e := 1.0
var _marco_st: SurfaceTool
var _marco_nv := 0


func _mt(p: Vector3) -> Vector3:
	return _marco_base + (p - _marco_base) * _marco_e if _em_marco else p


func _marco_ini(base: Vector3, e: float) -> void:
	_em_marco = true
	_marco_base = base
	_marco_e = e
	_marco_st = _st
	_marco_nv = _nv[0]
	_st = _nova()
	_nv[0] = 0


func _marco_fim(material: Material = null) -> MeshInstance:
	var mi := MeshInstance.new()
	if _nv[0] > 0:
		mi.mesh = _st.commit()
	if material == null:
		material = _mat_vertices()
	mi.material_override = material
	mi.transform = Transform(Basis().scaled(Vector3.ONE * _marco_e), _marco_base * (1.0 - _marco_e))
	add_child(mi)
	_st = _marco_st
	_nv[0] = _marco_nv
	_em_marco = false
	return mi


# ======================================================== terreno e água
func _altura_morro(M: Array, x: float, z: float) -> float:
	var c: Vector2 = M[0]
	var d := Vector2(x, z).distance_to(c)
	var raio: float = M[1]
	if d >= raio:
		return 0.0
	var u := 1.0 - d / raio
	# perfil do morro + ondulação grande + cristas (ruído "dobrado")
	var o: float = M[5] * 37.0
	var largo := _n_largo.get_noise_2d(x + o, z - o)
	var crista := 1.0 - abs(_n_crista.get_noise_2d(x - o, z + o)) * 2.0
	var rug: float = M[4] * 1.5
	var f: float = M[3]
	var perfil: float
	if f < 0.0:
		# maciço (fiordes): pé suave, encosta íngreme e topo largo
		var t: float = clamp(u / 0.62, 0.0, 1.0)
		perfil = pow(t * t * (3.0 - 2.0 * t), -f)
	elif f >= 1.0:
		# morro: meio cone, meio arredondado (nada de cone perfeito)
		perfil = lerp(pow(u, f), u * u * (3.0 - 2.0 * u), 0.5)
	else:
		perfil = pow(u, f)          # domo (Pão de Açúcar)
	var forma := 1.0 + rug * (0.9 * largo + 0.6 * crista) * (1.0 - 0.4 * u)
	var borda := clamp(u * 6.0, 0.0, 1.0)
	return max(0.0, M[2] * perfil * forma * borda)


func altura_em(x: float, z: float) -> float:
	var h := 0.0
	for M in _morros:
		h = max(h, _altura_morro(M, x, z))
	return h


## Morro/montanha: base verde (ou rocha), topo, neve acima de "neve" (fração
## da altura; 0 = sem neve), encostas íngremes viram rocha.
func _morro(cx: float, cz: float, raio: float, altura: float, verde: Color, rocha: Color, neve := 0.0, forma := 1.4, rugas := 0.25) -> void:
	var M := [Vector2(cx, cz), raio, altura, forma, rugas, _rng.randf() * TAU]
	_morros.append(M)
	# malha polar densa: altura de cada ponto uma vez só; a normal vem dos
	# vizinhos (relevo liso, com cristas e vales do ruído)
	var aneis := 20 if leve else 30
	var seg := 64 if leve else 96
	var pos := []
	for i in range(aneis + 1):
		var anel := []
		var r := raio * (1.0 - float(i) / aneis)
		for j in range(seg):
			var ang := TAU * j / seg
			var x := cx + cos(ang) * r
			var z := cz + sin(ang) * r
			anel.append(Vector3(x, _altura_morro(M, x, z) - 0.5, z))
		pos.append(anel)
	var base_i := _m_pos.size()
	var pts := []
	for i in range(aneis + 1):
		var anel2 := []
		for j in range(seg):
			var p: Vector3 = pos[i][j]
			var pa: Vector3 = pos[max(i - 1, 0)][j]
			var pb: Vector3 = pos[min(i + 1, aneis)][j]
			var pe: Vector3 = pos[i][(j + seg - 1) % seg]
			var pd: Vector3 = pos[i][(j + 1) % seg]
			var n := (pd - pe).cross(pb - pa)
			if n.length_squared() < 1e-8:
				n = Vector3.UP
			n = n.normalized()
			if n.y < 0.0:
				n = -n
			var hm := (p.y + 0.5) / altura
			# rocha nas encostas íngremes (mais no alto; embaixo a mata segura)
			var k_rocha := clamp((0.82 - n.y) * 2.8, 0.0, 1.0) * clamp(hm * 1.7, 0.2, 1.0)
			var cor := verde.linear_interpolate(rocha, k_rocha)
			cor = cor.linear_interpolate(rocha, clamp(hm * 0.5, 0.0, 0.4))
			if neve > 0.0 and hm > neve:
				cor = cor.linear_interpolate(Color(0.95, 0.96, 0.98), clamp((hm - neve) * 7.0, 0.0, 1.0) * clamp(n.y * 1.6 - 0.2, 0.0, 1.0))
			_m_pos.append(p)
			_m_nor.append(n)
			_m_cor.append(_base(cor))
			anel2.append([p, n])
		pts.append(anel2)
	for i in range(aneis):
		for j in range(seg):
			var j1 := (j + 1) % seg
			var a := base_i + i * seg + j
			var b := base_i + i * seg + j1
			var c := base_i + (i + 1) * seg + j1
			var d := base_i + (i + 1) * seg + j
			_m_idx.append(a)
			_m_idx.append(b)
			_m_idx.append(c)
			_m_idx.append(a)
			_m_idx.append(c)
			_m_idx.append(d)
	# mata nas encostas verdes (nem na rocha, nem na neve, nem nas casas)
	if verde.g > verde.r * 1.15:
		var n_arv := int(min(650.0, PI * raio * raio * 0.0016))
		for _k in range(n_arv):
			var i := 1 + _rng.randi() % (aneis - 1)
			var j := _rng.randi() % seg
			var v: Array = pts[i][j]
			var p: Vector3 = v[0]
			var n: Vector3 = v[1]
			var hm := (p.y + 0.5) / altura
			if n.y < 0.6 or (neve > 0.0 and hm > neve * 0.85) or p.y < 1.5:
				continue
			var jit := Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
			var q := p + jit
			q.y = altura_em(q.x, q.z) - 0.6
			if _ocupado_em(q.x, q.z):
				continue
			var e := _rng.randf_range(0.75, 1.35)
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(e, e * _rng.randf_range(0.9, 1.25), e))
			var tom := _rng.randf_range(0.78, 1.12)
			var tipo_m := "mata_" + _tipo_mata
			if not _i_arvores.has(tipo_m):
				_i_arvores[tipo_m] = []
			_i_arvores[tipo_m].append([Transform(b, q), Color(tom, tom * _rng.randf_range(0.95, 1.05), tom)])


func _agua(r: Rect2, y := 0.4, cor_funda := Color(0.05, 0.22, 0.32)) -> void:
	_aguas.append(r)
	var mi := MeshInstance.new()
	var pm := PlaneMesh.new()
	pm.size = r.size
	mi.mesh = pm
	mi.translation = Vector3(r.position.x + r.size.x * 0.5, y, r.position.y + r.size.y * 0.5)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/agua.shader")
	var funda := cor_funda
	var ceu := Color(0.6, 0.74, 0.9)
	var c_astro := Color(1.0, 0.9, 0.7)
	if noite:
		funda = Color(0.01, 0.03, 0.06)
		ceu = Color(0.06, 0.09, 0.16)
		c_astro = Color(0.75, 0.82, 1.0) * (0.3 if chove else 1.0)
	elif chove:
		funda = Color(0.1, 0.16, 0.2)
		ceu = Color(0.45, 0.5, 0.56)
		c_astro = Color(0.3, 0.3, 0.3)
	sm.set_shader_param("funda", funda)
	sm.set_shader_param("ceu", ceu)
	sm.set_shader_param("cor_astro", c_astro)
	sm.set_shader_param("astro", astro)
	mi.material_override = sm
	add_child(mi)


func _na_agua(x: float, z: float, folga := 6.0) -> bool:
	for r in _aguas:
		if r.grow(folga).has_point(Vector2(x, z)):
			return true
	return false


func _livre(x: float, z: float, raio: float) -> bool:
	if Vector2(x, z).length() < R_ESTADIO + raio:
		return false
	if _na_agua(x, z, raio):
		return false
	return not _bate(Vector2(x, z), raio, 1.0)


## Alguma reserva encosta no círculo (centro, raio)? k encolhe as reservas.
func _bate(p: Vector2, raio: float, k: float) -> bool:
	for o in _ocupado:
		if p.distance_to(o[0]) < o[1] * k + raio:
			return true
	var alcance := int(ceil((raio + R_PEQ) / CEL))
	var c0 := Vector2(floor(p.x / CEL), floor(p.y / CEL))
	for i in range(-alcance, alcance + 1):
		for j in range(-alcance, alcance + 1):
			var lista = _grade_ocup.get(c0 + Vector2(i, j))
			if lista == null:
				continue
			for o in lista:
				if p.distance_to(o[0]) < o[1] * k + raio:
					return true
	return false


## No caminho da câmera da vista da cidade: altura máxima (m) ou 0 = livre.
func _teto_corredor(x: float, z: float) -> float:
	for c in _corredor:
		if Vector2(x, z).distance_to(c[0]) < c[1]:
			return 9.0
	return 0.0


func _ocupado_em(x: float, z: float) -> bool:
	return _bate(Vector2(x, z), 0.0, 0.8)


func _reservar(x: float, z: float, raio: float) -> void:
	if _em_marco:
		var q := _mt(Vector3(x, 0, z))
		x = q.x
		z = q.z
		raio *= _marco_e
	if raio > R_PEQ:
		_ocupado.append([Vector2(x, z), raio])
		return
	var cel := Vector2(floor(x / CEL), floor(z / CEL))
	if not _grade_ocup.has(cel):
		_grade_ocup[cel] = []
	_grade_ocup[cel].append([Vector2(x, z), raio])


## Chão em volta: ruas de asfalto em grade com calçadas e quarteirões perto
## do estádio, campos ao longe (shaders/chao_cidade.shader). quadra = 0:
## sem ruas (só campo).
func _chao(cor: Color, quadra := 80.0, rua := 14.0, raio := 760.0) -> void:
	_q = quadra
	_r_rua = rua
	_raio_cidade = raio
	var mi := MeshInstance.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	mi.mesh = pm
	mi.translation = Vector3(0, -0.2, 0)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/chao_cidade.shader")
	m.set_shader_param("cor_campo", _base(cor))
	m.set_shader_param("cor_quadra", _base(cor.lightened(0.06)))
	m.set_shader_param("quadra", max(quadra, 1.0))
	m.set_shader_param("rua", rua)
	m.set_shader_param("calcada", _calc)
	m.set_shader_param("raio_cidade", raio if quadra > 0.0 else -500.0)
	m.set_shader_param("noite", 1.0 if noite else 0.0)
	m.set_shader_param("chuva", 1.0 if chove else 0.0)
	mi.material_override = m
	add_child(mi)


## Encaixa um prédio (frente w, fundo d) no quarteirão mais perto de (x, z),
## encostado na calçada e de frente para a rua. Devolve [x, z, giro] (ou o
## lugar livre de antes, fora da grade).
func _no_lote(x: float, z: float, w: float, d: float) -> Array:
	if _q <= 0.0 or Vector2(x, z).length() > _raio_cidade - 40.0:
		return [x, z, _rng.randf_range(-0.15, 0.15) + (0.0 if _rng.randf() < 0.5 else PI * 0.5)]
	var m := _r_rua * 0.5 + _calc + 0.6
	var dentro := _q - 2.0 * m
	var x0 := floor(x / _q) * _q + m
	var z0 := floor(z / _q) * _q + m
	var lx: float = clamp(x - x0, 0.0, dentro)
	var lz: float = clamp(z - z0, 0.0, dentro)
	w = min(w, dentro)
	d = min(d, dentro * 0.5)
	var lados := [lx, dentro - lx, lz, dentro - lz]
	var lado := 0
	for i in range(4):
		if lados[i] < lados[lado]:
			lado = i
	var cx: float
	var cz: float
	var giro: float
	if lado < 2:
		# de frente para a rua de x (oeste/leste): fundo ao longo de x
		cx = x0 + (d * 0.5 if lado == 0 else dentro - d * 0.5)
		cz = z0 + clamp(lz, w * 0.5, dentro - w * 0.5)
		giro = PI * 0.5
	else:
		cz = z0 + (d * 0.5 if lado == 2 else dentro - d * 0.5)
		cx = x0 + clamp(lx, w * 0.5, dentro - w * 0.5)
		giro = 0.0
	return [cx, cz, giro]


# ============================================================== bairros
## Prédios espalhados num anel (raio r0..r1), fora da água e do que está
## reservado. paleta: cores das paredes; alt: altura mín/máx; larg: largura.
func _bairro(n: int, r0: float, r1: float, alt: Vector2, larg: Vector2, paleta: Array, telhado := "", janelas := 1.0, setor := Vector2(-PI, PI)) -> void:
	var feitos := 0
	var tent := 0
	while feitos < n and tent < n * 8:
		tent += 1
		var a := _rng.randf_range(setor.x, setor.y)
		var r := sqrt(_rng.randf_range(r0 * r0, r1 * r1))
		var x := cos(a) * r
		var z := sin(a) * r
		var w := _rng.randf_range(larg.x, larg.y)
		var d := _rng.randf_range(larg.x, larg.y)
		var lote := _no_lote(x, z, w, d)
		x = lote[0]
		z = lote[1]
		var giro: float = lote[2]
		if not _livre(x, z, max(w, d) * 0.5):
			continue
		var y0 := altura_em(x, z)
		if y0 > 6.0:
			continue
		_reservar(x, z, max(w, d) * 0.5)
		var h := _rng.randf_range(alt.x, alt.y) * (1.0 + 0.6 * pow(_rng.randf(), 4.0))
		var teto := _teto_corredor(x, z)
		if teto > 0.0:
			h = min(h, _rng.randf_range(teto * 0.6, teto))
		var cor: Color = paleta[_rng.randi() % paleta.size()]
		cor = cor.lightened(_rng.randf_range(-0.08, 0.08)) if _rng.randf() < 0.5 else cor.darkened(_rng.randf_range(0.0, 0.1))
		_predio(Vector3(x, y0 - 1.0, z), Vector3(w, h + 1.0, d), cor, giro, janelas)
		_detalhes_predio(Vector3(x, y0, z), Vector3(w, h, d), cor, giro, telhado == "")
		match telhado:
			"mansarda":
				_tronco(Vector3(x, y0 + h, z), Vector2(w, d), Vector2(w * 0.62, d * 0.62), 4.0, Color(0.36, 0.4, 0.47), giro)
			"telha":
				_tronco(Vector3(x, y0 + h, z), Vector2(w + 0.6, d + 0.6), Vector2(w * 0.25, d + 0.6), 3.5, Color(0.66, 0.33, 0.22), giro)
			"antena":
				if h > 45.0 and _rng.randf() < 0.5:
					_cilindro(Vector3(x, y0 + h, z), 0.4, 0.15, 10.0, 4, Color(0.7, 0.7, 0.72))
					if noite:
						_brilho(Vector3(x, y0 + h + 10.0, z), 3.0, Color(1.0, 0.15, 0.1, 0.9), true)
		feitos += 1


## Quarteirões cheios: em cada quadra da grade (anel r0..r1), prédios lado a
## lado de frente para as quatro ruas (como uma cidade de verdade), com o
## miolo da quadra livre. ocupa: chance de cada lote ter prédio.
func _quarteiroes(r0: float, r1: float, alt: Vector2, larg: Vector2, paleta: Array, telhado := "", janelas := 1.0, ocupa := 0.85, setor := Vector2(-PI, PI)) -> void:
	if _q <= 0.0:
		_bairro(int((r1 * r1 - r0 * r0) / 2400.0), r0, r1, alt, larg, paleta, telhado, janelas, setor)
		return
	var m := _r_rua * 0.5 + _calc + 0.6
	var dentro := _q - 2.0 * m
	var fundo_max: float = min(22.0, dentro * 0.42)
	var n := int(ceil(r1 / _q))
	for kx in range(-n, n):
		for kz in range(-n, n):
			var x0 := kx * _q + m
			var z0 := kz * _q + m
			var centro := Vector2(x0 + dentro * 0.5, z0 + dentro * 0.5)
			var r := centro.length()
			if r < r0 - _q * 0.3 or r > r1:
				continue
			var a := atan2(centro.y, centro.x)
			if a < setor.x or a > setor.y:
				continue
			# mais alto perto do centro, mais baixo na periferia
			var k_alt: float = lerp(1.15, 0.7, clamp((r - r0) / max(r1 - r0, 1.0), 0.0, 1.0))
			for lado in range(4):
				var ao_longo := dentro if lado < 2 else dentro - 2.0 * fundo_max
				var ini := 0.0 if lado < 2 else fundo_max
				var pos := 0.0
				while pos < ao_longo - larg.x * 0.6:
					var w: float = min(_rng.randf_range(larg.x, larg.y), ao_longo - pos)
					var d: float = min(_rng.randf_range(10.0, fundo_max), fundo_max)
					var meio := ini + pos + w * 0.5
					pos += w + _rng.randf_range(0.0, 1.5)
					if _rng.randf() > ocupa:
						continue
					var x: float
					var z: float
					var giro: float
					match lado:
						0:
							x = x0 + d * 0.5
							z = z0 + meio
							giro = PI * 0.5
						1:
							x = x0 + dentro - d * 0.5
							z = z0 + meio
							giro = PI * 0.5
						2:
							x = x0 + meio
							z = z0 + d * 0.5
							giro = 0.0
						_:
							x = x0 + meio
							z = z0 + dentro - d * 0.5
							giro = 0.0
					var tam_w := w - 0.6
					if not _livre(x, z, max(tam_w, d) * 0.45):
						continue
					var y0 := altura_em(x, z)
					if y0 > 6.0:
						continue
					_reservar(x, z, max(tam_w, d) * 0.45)
					var h := _rng.randf_range(alt.x, alt.y) * k_alt * (1.0 + 0.7 * pow(_rng.randf(), 5.0))
					var teto := _teto_corredor(x, z)
					if teto > 0.0:
						h = min(h, _rng.randf_range(teto * 0.6, teto))
					var cor: Color = paleta[_rng.randi() % paleta.size()]
					cor = cor.lightened(_rng.randf_range(-0.08, 0.08)) if _rng.randf() < 0.5 else cor.darkened(_rng.randf_range(0.0, 0.12))
					_predio(Vector3(x, y0 - 1.0, z), Vector3(tam_w, h + 1.0, d), cor, giro, janelas)
					_detalhes_predio(Vector3(x, y0, z), Vector3(tam_w, h, d), cor, giro, telhado == "")
					if telhado in ["mansarda", "telha"]:
						var tt := Vector3(tam_w, 4.0, d) if telhado == "mansarda" else Vector3(tam_w + 0.6, 3.5, d + 0.6)
						var cor_t := Color(0.36, 0.4, 0.47) if telhado == "mansarda" else Color(0.66, 0.33, 0.22).lightened(_rng.randf_range(-0.06, 0.08))
						_i_formas[telhado].append([Transform(Basis(Vector3.UP, giro) * Basis().scaled(tt), Vector3(x, y0 + h, z)), _base(cor_t)])


## Casinhas (telhado de duas águas) espalhadas; de noite, janelas acesas.
func _casas(n: int, r0: float, r1: float, paredes: Array, telhados: Array, tam := Vector2(7, 11), setor := Vector2(-PI, PI), sobe_morro := false) -> void:
	var feitos := 0
	var tent := 0
	while feitos < n and tent < n * 8:
		tent += 1
		var a := _rng.randf_range(setor.x, setor.y)
		var r := sqrt(_rng.randf_range(r0 * r0, r1 * r1))
		var x := cos(a) * r
		var z := sin(a) * r
		var w := _rng.randf_range(tam.x, tam.y)
		if not _livre(x, z, w * 0.6):
			continue
		var y0 := altura_em(x, z)
		if (y0 > 3.0 and not sobe_morro) or y0 > 38.0:
			continue
		_reservar(x, z, w * 0.5)
		var h := _rng.randf_range(4.5, 8.0)
		var giro := _rng.randf() * PI
		_casa(Vector3(x, y0 - 0.8, z), w, w * 0.75, h + 0.8, w * 0.32, paredes[_rng.randi() % paredes.size()], telhados[_rng.randi() % telhados.size()], giro)
		if noite and _rng.randf() < 0.6:
			_ponto_luz(Vector3(x, y0 + h * 0.6, z), 2.2, Color(1.0, 0.75, 0.4, 0.8))
		feitos += 1


## Favela: casinhas de tijolo e coloridas grudadas na encosta do morro.
func _favela(M: Array, n: int, h_min: float, h_max: float, setor: Vector2) -> void:
	var cores := [Color(0.72, 0.42, 0.3), Color(0.78, 0.5, 0.36), Color(0.9, 0.86, 0.78), Color(0.95, 0.75, 0.35),
		Color(0.45, 0.62, 0.8), Color(0.85, 0.45, 0.5), Color(0.6, 0.78, 0.55), Color(0.82, 0.82, 0.86)]
	var c: Vector2 = M[0]
	var feitos := 0
	var tent := 0
	while feitos < n and tent < n * 10:
		tent += 1
		var a := _rng.randf_range(setor.x, setor.y)
		var r = _rng.randf_range(0.15, 0.95) * M[1]
		var x = c.x + cos(a) * r
		var z = c.y + sin(a) * r
		var y := _altura_morro(M, x, z)
		if y < h_min * M[2] or y > h_max * M[2] or Vector2(x, z).length() < R_ESTADIO + 8.0 or _na_agua(x, z):
			continue
		var w := _rng.randf_range(3.5, 6.0)
		var h := _rng.randf_range(3.0, 7.5)
		var cor: Color = cores[_rng.randi() % cores.size()]
		_caixa_i(Vector3(x, y + h * 0.5 - 1.2, z), Vector3(w, h + 1.2, w * _rng.randf_range(0.7, 1.1)), cor, _rng.randf() * PI)
		if noite and _rng.randf() < 0.55:
			_ponto_luz(Vector3(x, y + h * 0.6, z), 1.8, Color(1.0, 0.78, 0.45, 0.85))
		feitos += 1


## Árvores (copa arredondada) e pinheiros/guarda-chuva (Roma).
func _arvores(n: int, r0: float, r1: float, tipo := "copa") -> void:
	var feitos := 0
	var tent := 0
	while feitos < n and tent < n * 6:
		tent += 1
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(r0, r1)
		var x := cos(a) * r
		var z := sin(a) * r
		if _q > 0.0 and r < _raio_cidade - 60.0 and _rng.randf() < 0.7:
			# árvore de calçada: na beira da rua, longe da esquina
			var borda := _r_rua * 0.5 + _calc * 0.5
			var ao_longo := _rng.randf_range(borda + 6.0, _q - borda - 6.0)
			var lado := 1.0 if _rng.randf() < 0.5 else -1.0
			if _rng.randf() < 0.5:
				x = round(x / _q) * _q + lado * borda
				z = floor(z / _q) * _q + ao_longo
			else:
				z = round(z / _q) * _q + lado * borda
				x = floor(x / _q) * _q + ao_longo
		if not _livre(x, z, 3.0):
			continue
		var y := altura_em(x, z)
		var e := _rng.randf_range(0.8, 1.2)
		var tom := _rng.randf_range(0.85, 1.15)
		if not _i_arvores.has(tipo):
			_i_arvores[tipo] = []
		_i_arvores[tipo].append([Transform(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(e, e, e)), Vector3(x, y - 0.2, z)), Color(tom, tom, tom)])
		feitos += 1


func _barcos(n: int, area: Rect2, vela := true) -> void:
	for _i in range(n):
		var x := _rng.randf_range(area.position.x, area.end.x)
		var z := _rng.randf_range(area.position.y, area.end.y)
		var giro := _rng.randf() * PI
		_caixa(Vector3(x, 0.9, z), Vector3(10.0, 1.6, 3.4), Color(0.92, 0.92, 0.94), giro)
		if vela:
			var b := Basis(Vector3.UP, giro)
			var m := Vector3(x, 1.7, z)
			_tri(m + b.xform(Vector3(-0.5, 0, 0)), m + b.xform(Vector3(3.5, 0, 0)), m + Vector3(0, 12, 0), Color(0.98, 0.98, 0.96), m + b.xform(Vector3(0, 6, 1)))
		else:
			_caixa(Vector3(x, 2.6, z), Vector3(4.5, 1.8, 2.8), Color(0.85, 0.3, 0.2), giro)
		if noite:
			_ponto_luz(Vector3(x, 3.0, z), 1.6, Color(1.0, 0.9, 0.7, 0.8))


# =============================================================== lugares
func _rio() -> void:
	_chao(Color(0.36, 0.42, 0.3), 72.0, 14.0, 700.0)
	_varandas = 0.65
	_agua(Rect2(30, -1400, 1500, 1170))
	# areia da praia na beira da baía
	_quad(Vector3(30, 0.3, -232), Vector3(1530, 0.3, -232), Vector3(1530, 0.3, -246), Vector3(30, 0.3, -246), Color(0.9, 0.84, 0.66), Vector3(0, -10, 0))
	var verde := Color(0.2, 0.42, 0.18)
	var rocha := Color(0.44, 0.42, 0.4)
	# Corcovado e o Cristo
	_morro(-120, -430, 230, 235, verde, rocha, 0.0, 1.9, 0.22)
	var topo := Vector3(-120, altura_em(-120, -430) - 1.0, -430)
	_cristo(topo)
	# Pão de Açúcar (rocha nua, arredondada) e o Morro da Urca
	_morro(240, -400, 85, 135, Color(0.3, 0.4, 0.24), Color(0.42, 0.4, 0.38), 0.0, 0.42, 0.08)
	_morro(165, -360, 60, 55, verde, rocha, 0.0, 0.9, 0.1)
	# bondinho: cabo e cabine
	var p1 := Vector3(165, 56, -360)
	var p2 := Vector3(240, 121, -400)
	for k in range(14):
		var u := float(k) / 13.0
		var q := p1.linear_interpolate(p2, u) - Vector3(0, sin(u * PI) * 5.0, 0)
		_caixa(q, Vector3(0.4, 0.4, 0.4), Color(0.2, 0.2, 0.2))
	_caixa(p1.linear_interpolate(p2, 0.45) - Vector3(0, 6.5, 0), Vector3(3.0, 2.6, 2.4), Color(0.85, 0.85, 0.88))
	# Tijuca atrás e morros com favela do lado
	_morro(-380, -620, 260, 150, verde, rocha, 0.0, 1.3, 0.25)
	_morro(70, -720, 300, 135, verde, rocha, 0.0, 1.2, 0.3)
	_morro(500, -820, 300, 120, verde, rocha, 0.0, 1.2, 0.3)
	var M1 := [Vector2(-300, -230), 120.0, 62.0, 1.1, 0.2, 1.0]
	_morro_de(M1, verde, rocha)
	_favela(M1, 240, 0.05, 0.75, Vector2(-PI, PI))
	_favela(_morros[0], 160, 0.04, 0.35, Vector2(0.3, 2.9))
	var M2 := [Vector2(-470, -60), 140.0, 70.0, 1.1, 0.2, 2.0]
	_morro_de(M2, verde, rocha)
	_favela(M2, 200, 0.05, 0.8, Vector2(-PI, PI))
	# prédios da orla e da zona sul
	var claros := [Color(0.94, 0.93, 0.9), Color(0.88, 0.86, 0.8), Color(0.8, 0.84, 0.86), Color(0.92, 0.88, 0.78),
		Color(0.9, 0.78, 0.66), Color(0.78, 0.8, 0.74), Color(0.86, 0.74, 0.7), Color(0.72, 0.76, 0.8)]
	_quarteiroes(R_ESTADIO + 10.0, 420.0, Vector2(14, 34), Vector2(12, 22), claros, "", 1.0, 0.9)
	_bairro(60, 380.0, 700.0, Vector2(20, 45), Vector2(14, 24), claros, "antena", 1.0)
	_arvores(80, R_ESTADIO + 5.0, 260.0)
	_barcos(10, Rect2(60, -900, 700, 560))


func _morro_de(M: Array, verde: Color, rocha: Color) -> void:
	_morro(M[0].x, M[0].y, M[1], M[2], verde, rocha, 0.0, M[3], M[4])
	var ultimo: Array = _morros[_morros.size() - 1]
	M[5] = ultimo[5]


## Cristo Redentor: modelo 3D (modelos/cristo.glb, feito no Blender por
## tools/modelos3d/cristo.py) no alto do Corcovado, de frente para a cidade,
## aumentado como os outros cartões-postais. De noite, iluminado.
func _cristo(topo: Vector3) -> void:
	var e := 2.4
	var c: Spatial = load("res://modelos/cristo.glb").instance()
	c.translation = topo + Vector3(0, 1.5, 0)
	c.scale = Vector3.ONE * e
	# de frente para o estádio (que fica na origem)
	c.rotation.y = atan2(-topo.x, -topo.z) + PI
	add_child(c)
	if noite:
		_iluminar(c, Color(0.6, 0.66, 0.82))
	_reservar(topo.x, topo.z, 14.0 * e)
	postal = {"pos": c.translation, "altura": 38.0 * e, "frente": Vector3(-topo.x, 0, -topo.z).normalized(),
		"nome": "CRISTO REDENTOR  •  CORCOVADO"}
	if noite:
		var b := topo + Vector3(0, 8.0 * e, 0)
		_brilho(b + Vector3(0, 14.0 * e, 0), 70.0 * e, Color(0.75, 0.82, 1.0, 0.3))
		_brilho(b + Vector3(0, 19.0 * e, 0), 24.0 * e, Color(0.9, 0.95, 1.0, 0.42))


## Monumento iluminado por holofotes à noite (brilho próprio no material).
static func _iluminar(n: Node, cor: Color) -> void:
	if n is MeshInstance and n.mesh != null:
		for i in range(n.mesh.get_surface_count()):
			var mt: Material = n.mesh.surface_get_material(i)
			if mt is SpatialMaterial:
				var novo: SpatialMaterial = mt.duplicate()
				novo.emission_enabled = true
				novo.emission = cor
				novo.emission_energy = 0.55
				n.set_surface_material(i, novo)
	for f in n.get_children():
		_iluminar(f, cor)


func _buenos_aires() -> void:
	_chao(Color(0.42, 0.44, 0.38), 100.0, 16.0, 780.0)
	_varandas = 0.45
	_agua(Rect2(-1500, -1500, 3000, 820), 0.4, Color(0.25, 0.22, 0.15))
	# a avenida 9 de Julho e o Obelisco no meio
	var asfalto := Color(0.25, 0.25, 0.27)
	_quad(Vector3(-900, 0.2, -282), Vector3(900, 0.2, -282), Vector3(900, 0.2, -318), Vector3(-900, 0.2, -318), asfalto, Vector3(0, -10, 0))
	_reservar(0, -300, 26)
	for x in range(-880, 900, 40):
		_reservar(float(x), -300, 18)
		if noite:
			_ponto_luz(Vector3(float(x), 9.0, -284), 3.0, Color(1.0, 0.8, 0.5, 0.9))
			_ponto_luz(Vector3(float(x) + 20.0, 9.0, -316), 3.0, Color(1.0, 0.8, 0.5, 0.9))
	var branco := Color(0.93, 0.92, 0.88)
	_marco_ini(Vector3(0, 0, -300), 1.6)
	_tronco(Vector3(0, 0, -300), Vector2(14, 14), Vector2(10, 10), 2.0, Color(0.6, 0.6, 0.6))
	_tronco(Vector3(0, 2.0, -300), Vector2(7.5, 7.5), Vector2(4.6, 4.6), 66.0, branco, 0.0, true)
	_tronco(Vector3(0, 68.0, -300), Vector2(4.6, 4.6), Vector2(0.2, 0.2), 4.5, branco, 0.0, true)
	if noite:
		_brilho(Vector3(0, 36, -300), 50.0, Color(1.0, 0.95, 0.85, 0.3))
	_marco_fim()
	var paleta := [Color(0.85, 0.8, 0.7), Color(0.75, 0.72, 0.68), Color(0.9, 0.88, 0.84), Color(0.7, 0.6, 0.5), Color(0.62, 0.66, 0.7)]
	_quarteiroes(R_ESTADIO + 8.0, 440.0, Vector2(16, 34), Vector2(14, 24), paleta, "", 1.0, 0.92)
	# Puerto Madero: torres de vidro
	_bairro(26, 420.0, 640.0, Vector2(70, 120), Vector2(18, 28), [Color(0.5, 0.6, 0.68), Color(0.62, 0.7, 0.75)], "antena", 1.0, Vector2(-1.5, -0.6))
	_bairro(120, 420.0, 680.0, Vector2(18, 40), Vector2(14, 24), paleta, "", 1.0)
	_arvores(70, R_ESTADIO + 4.0, 300.0)


func _bergen() -> void:
	_chao(Color(0.3, 0.4, 0.26), 60.0, 10.0, 360.0)
	_agua(Rect2(-260, -1600, 520, 1350), 0.4, Color(0.04, 0.16, 0.22))
	var verde := Color(0.17, 0.33, 0.17)
	var rocha := Color(0.27, 0.28, 0.3)
	_tipo_mata = "pinheiro"
	# fiordes: maciços de encosta íngreme e topo largo dos dois lados da água
	_morro(-470, -520, 330, 250, verde, rocha, 1.05, -1.3, 0.28)
	_morro(480, -580, 340, 270, verde, rocha, 1.0, -1.3, 0.28)
	_morro(0, -1150, 520, 360, verde, rocha, 0.95, -1.2, 0.32)
	_morro(-690, -140, 320, 190, verde, rocha, 0.0, -1.4, 0.26)
	_morro(720, -170, 340, 205, verde, rocha, 0.0, -1.4, 0.26)
	_morro(-300, 470, 320, 160, verde, rocha, 0.0, -1.5, 0.26)
	# Bryggen: casas de madeira coloridas lado a lado no cais
	var cores := [Color(0.72, 0.18, 0.15), Color(0.92, 0.75, 0.3), Color(0.94, 0.93, 0.9), Color(0.8, 0.45, 0.2), Color(0.85, 0.6, 0.4)]
	var x := -150.0
	while x < 150.0:
		var w := _rng.randf_range(7.0, 10.0)
		var h := _rng.randf_range(10.0, 15.0)
		var cor: Color = cores[_rng.randi() % cores.size()]
		_casa(Vector3(x + w * 0.5, 0, -238), 16.0, w, h, w * 0.55, cor, cor.darkened(0.35), PI * 0.5)
		if noite:
			_ponto_luz(Vector3(x + w * 0.5, h * 0.55, -230), 2.4, Color(1.0, 0.78, 0.45, 0.85))
		x += w + 0.3
	for k in range(-150, 150, 12):
		_reservar(float(k), -238, 10)
	# centro: sobrados de madeira coloridos (3 a 5 andares) nas quadras
	_quarteiroes(R_ESTADIO + 8.0, 330.0, Vector2(9, 15), Vector2(8, 13), [Color(0.95, 0.94, 0.9), Color(0.75, 0.2, 0.16), Color(0.92, 0.78, 0.4), Color(0.85, 0.6, 0.4), Color(0.6, 0.7, 0.78)], "telha", 0.8, 0.8)
	_casas(170, 330.0, 600.0, [Color(0.95, 0.94, 0.9), Color(0.75, 0.2, 0.16), Color(0.92, 0.78, 0.4)], [Color(0.25, 0.25, 0.28), Color(0.5, 0.2, 0.15)], Vector2(7, 10), Vector2(-PI, PI), true)
	_arvores(140, R_ESTADIO + 5.0, 500.0, "pinheiro")
	_barcos(9, Rect2(-200, -800, 400, 500), false)


func _paris() -> void:
	_chao(Color(0.45, 0.45, 0.4), 78.0, 14.0, 820.0)
	_varandas = 0.2
	# o Sena passando na frente da torre
	_agua(Rect2(-1500, -262, 3000, 34), 0.3, Color(0.12, 0.2, 0.2))
	_eiffel(Vector3(-40, 0, -330))
	# Sacré-Cœur no alto de Montmartre
	_morro(330, -640, 170, 55, Color(0.32, 0.42, 0.26), Color(0.4, 0.4, 0.38), 0.0, 1.0, 0.1)
	var sc := Vector3(330, altura_em(330, -640) - 1.0, -640)
	var branco := Color(0.96, 0.95, 0.9)
	_marco_ini(sc, 1.4)
	_caixa(sc + Vector3(0, 10, 0), Vector3(40, 20, 30), branco, 0.0, null, true)
	_cilindro(sc + Vector3(0, 20, 0), 8.0, 8.0, 10.0, 12, branco, true)
	_esfera(sc + Vector3(0, 30, 0), 8.5, branco, Vector3(1, 1.35, 1), true, true)
	_cilindro(sc + Vector3(0, 41, 0), 1.6, 0.2, 7.0, 8, branco, true)
	for sx in [-1, 1]:
		_cilindro(sc + Vector3(sx * 15.0, 20, 6), 3.5, 3.5, 5.0, 8, branco, true)
		_esfera(sc + Vector3(sx * 15.0, 25, 6), 3.8, branco, Vector3(1, 1.3, 1), true, true)
	_reservar(330, -640, 40)
	_marco_fim()
	var creme := [Color(0.9, 0.85, 0.74), Color(0.86, 0.8, 0.68), Color(0.92, 0.88, 0.8)]
	_quarteiroes(R_ESTADIO + 8.0, 520.0, Vector2(17, 23), Vector2(14, 22), creme, "mansarda", 0.9, 0.95)
	_bairro(18, 640.0, 900.0, Vector2(80, 150), Vector2(20, 30), [Color(0.55, 0.62, 0.7)], "", 1.0, Vector2(-0.6, 0.2))
	_arvores(120, R_ESTADIO + 4.0, 400.0)


func _eiffel(base: Vector3) -> void:
	_marco_ini(base, 1.55)
	var bronze := Color(0.5, 0.42, 0.32)
	var acesa := false
	if noite:
		bronze = Color(1.0, 0.72, 0.35)
	# 4 pernas curvas até a 1ª plataforma, a 2ª e o mastro
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var prev := base + Vector3(sx * 26.0, 0, sz * 26.0)
			for k in range(1, 9):
				var u := float(k) / 8.0
				var y := u * 60.0
				var off: float = lerp(26.0, 7.0, 1.0 - pow(1.0 - u, 1.7))
				var p := base + Vector3(sx * off, y, sz * off)
				var t: float = lerp(8.0, 4.0, u)
				_caixa_entre(prev, p, t, bronze, acesa)
				prev = p
	_caixa(base + Vector3(0, 22, 0), Vector3(42, 3.0, 42), bronze, 0.0, null, acesa)
	_caixa(base + Vector3(0, 52, 0), Vector3(22, 2.6, 22), bronze, 0.0, null, acesa)
	var prev2 := base + Vector3(0, 52, 0)
	for k in range(1, 9):
		var u2 := float(k) / 8.0
		var y2: float = lerp(52.0, 118.0, u2)
		var t2: float = lerp(14.0, 3.0, pow(u2, 0.8))
		_tronco(prev2, Vector2(t2 + 2.0, t2 + 2.0), Vector2(t2, t2), y2 - prev2.y, bronze, 0.0, acesa)
		prev2 = base + Vector3(0, y2, 0)
	_caixa(base + Vector3(0, 116, 0), Vector3(6, 3, 6), bronze, 0.0, null, acesa)
	_cilindro(base + Vector3(0, 117.5, 0), 1.0, 0.25, 14.0, 6, bronze, acesa)
	_reservar(base.x, base.z, 40)
	if noite:
		_brilho(base + Vector3(0, 60, 0), 110.0, Color(1.0, 0.78, 0.4, 0.22))
		for _i in range(26):
			var h := _rng.randf_range(5.0, 125.0)
			var esp: float = lerp(26.0, 2.0, clamp(h / 120.0, 0.0, 1.0))
			_brilho(base + Vector3(_rng.randf_range(-esp, esp), h, _rng.randf_range(-esp, esp) + 3.0), 4.0, Color(1, 1, 1, 0.9), true)
		_brilho(base + Vector3(0, 131, 0), 9.0, Color(1.0, 0.95, 0.8, 1.0), true)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/trelica.shader")
	sm.set_shader_param("noite", 1.0 if noite else 0.0)
	_marco_fim(sm)


## Viga (caixa) ligando dois pontos.
func _caixa_entre(a: Vector3, b: Vector3, t: float, cor: Color, acesa := false) -> void:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.1:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	var c := (a + b) * 0.5
	var h := d.length() * 0.5 + t * 0.15
	var p := []
	for i in range(8):
		var v := x * (t * 0.5 if i & 1 else -t * 0.5) + y * (h if i & 2 else -h) + z * (t * 0.5 if i & 4 else -t * 0.5)
		p.append(c + v)
	for f in FACES:
		_quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], cor, c, acesa)


func _munique() -> void:
	_chao(Color(0.36, 0.44, 0.3), 80.0, 14.0, 700.0)
	_varandas = 0.15
	_tipo_mata = "pinheiro"
	var verde := Color(0.24, 0.38, 0.22)
	var rocha := Color(0.5, 0.52, 0.58)
	# os Alpes ao fundo
	for i in range(7):
		var x := -1200.0 + i * 400.0 + _rng.randf_range(-80, 80)
		_morro(x, -1250.0 + _rng.randf_range(-100, 100), 380.0, _rng.randf_range(260.0, 380.0), verde, rocha, 0.42, 1.0, 0.4)
	# torre olímpica
	var t := Vector3(-150, 0, -330)
	var concreto := Color(0.78, 0.78, 0.76)
	_marco_ini(t, 1.3)
	_cilindro(t, 5.0, 3.6, 150.0, 12, concreto, true)
	_cilindro(t + Vector3(0, 122, 0), 11.0, 13.0, 6.0, 16, concreto, true)
	_cilindro(t + Vector3(0, 128, 0), 13.0, 10.0, 5.0, 16, Color(0.4, 0.5, 0.6), true)
	for k in range(6):
		_cilindro(t + Vector3(0, 150.0 + k * 7.0, 0), 1.2, 1.0, 7.0, 6, Color(0.9, 0.2, 0.15) if k % 2 == 0 else Color(0.95, 0.95, 0.95), true)
	_reservar(t.x, t.z, 20)
	if noite:
		_brilho(t + Vector3(0, 192, 0), 8.0, Color(1.0, 0.15, 0.1, 1.0), true)
		_brilho(t + Vector3(0, 128, 0), 40.0, Color(1.0, 0.9, 0.7, 0.3))
	_marco_fim()
	# Frauenkirche: nave de tijolo e as duas torres de cúpula verde
	var f := Vector3(110, 0, -400)
	var tijolo := Color(0.62, 0.34, 0.24)
	_marco_ini(f, 1.45)
	_caixa(f + Vector3(0, 18, 18), Vector3(34, 36, 50), tijolo, 0.0, null, true)
	_tronco(f + Vector3(0, 36, 18), Vector2(34, 50), Vector2(2, 50), 26.0, Color(0.52, 0.26, 0.2), 0.0, true)
	for sx in [-1, 1]:
		_caixa(f + Vector3(sx * 9.0, 40, -12), Vector3(14, 80, 14), tijolo, 0.0, null, true)
		_cilindro(f + Vector3(sx * 9.0, 80, -12), 7.4, 7.4, 4.0, 10, tijolo, true)
		_esfera(f + Vector3(sx * 9.0, 88, -12), 7.4, Color(0.32, 0.55, 0.45), Vector3(1, 1.5, 1), false, true)
		_cone(f + Vector3(sx * 9.0, 97, -12), 1.6, 7.0, 6, Color(0.85, 0.7, 0.3), true)
	_reservar(f.x, f.z, 40)
	_marco_fim()
	var paleta := [Color(0.92, 0.88, 0.76), Color(0.88, 0.78, 0.55), Color(0.95, 0.93, 0.88), Color(0.82, 0.7, 0.6)]
	_quarteiroes(R_ESTADIO + 8.0, 480.0, Vector2(12, 22), Vector2(14, 24), paleta, "telha", 0.85, 0.9)
	_arvores(160, R_ESTADIO + 4.0, 500.0)


func _sydney() -> void:
	_chao(Color(0.4, 0.44, 0.34), 80.0, 14.0, 700.0)
	_varandas = 0.3
	_agua(Rect2(-1500, -1500, 3000, 1240), 0.4, Color(0.03, 0.2, 0.3))
	# a ponta da Ópera
	var o := Vector3(-70, 0, -320)
	_marco_ini(o, 1.6)
	_caixa(o + Vector3(0, 4, 0), Vector3(90, 8, 56), Color(0.78, 0.66, 0.52), 0.0, null, true)
	var branco := Color(0.97, 0.96, 0.92)
	for fila in [[-18.0, 1.0], [18.0, 0.82]]:
		for k in range(4):
			var esc: float = fila[1] * (1.0 - k * 0.17)
			var px: float = o.x - 28.0 + k * 17.0
			_concha(Vector3(px, 8.0, o.z + fila[0]), 19.0 * esc, branco)
	_reservar(o.x, o.z, 60)
	if noite:
		_brilho(o + Vector3(0, 20, 0), 80.0, Color(1.0, 0.95, 0.85, 0.25))
	_marco_fim()
	# Harbour Bridge: o arco de aço sobre a baía
	var p0 := Vector3(80, 0, -460)
	var p1 := Vector3(380, 0, -460)
	var aco := Color(0.4, 0.42, 0.45)
	var granito := Color(0.72, 0.68, 0.6)
	for p in [p0, p1]:
		for dz in [-9.0, 9.0]:
			_caixa(p + Vector3(0, 22, dz), Vector3(12, 44, 9), granito, 0.0, null, true)
	_caixa((p0 + p1) * 0.5 + Vector3(0, 16, 0), Vector3(p1.x - p0.x + 20.0, 2.5, 24), aco, 0.0, null, true)
	for dz in [-10.0, 10.0]:
		var ant := Vector3()
		for k in range(25):
			var u := float(k) / 24.0
			var x: float = lerp(p0.x + 8.0, p1.x - 8.0, u)
			var y := 16.0 + 62.0 * (1.0 - pow(2.0 * u - 1.0, 2.0))
			var p2 := Vector3(x, y, p0.z + dz)
			if k > 0:
				_caixa_entre(ant, p2, 3.2, aco, true)
				if k % 2 == 0:
					_caixa_entre(Vector3(x, 17, p0.z + dz), p2, 0.8, aco, true)
			ant = p2
	if noite:
		for k in range(16):
			_ponto_luz(Vector3(lerp(p0.x, p1.x, k / 15.0), 18.0, p0.z - 12.0), 3.0, Color(1.0, 0.85, 0.6, 0.9))
	# torres do centro atrás da baía
	var vidros := [Color(0.5, 0.6, 0.7), Color(0.62, 0.7, 0.76), Color(0.7, 0.72, 0.7)]
	_quarteiroes(R_ESTADIO + 8.0, 260.0, Vector2(14, 30), Vector2(14, 22), [Color(0.9, 0.86, 0.8), Color(0.8, 0.78, 0.74)], "", 1.0, 0.9)
	for i in range(30):
		var x2 := _rng.randf_range(-500, 500)
		var z2 := _rng.randf_range(-820, -620)
		_predio(Vector3(x2, 0, z2), Vector3(_rng.randf_range(16, 28), _rng.randf_range(70, 200), _rng.randf_range(16, 28)), vidros[i % 3], 0.0, 1.0)
	_quad(Vector3(-1500, 0.3, -830), Vector3(1500, 0.3, -830), Vector3(1500, 0.3, -600), Vector3(-1500, 0.3, -600), _cor(Color(0.4, 0.42, 0.36), Vector3.UP), Vector3(0, -10, 0))
	_arvores(90, R_ESTADIO + 4.0, 250.0)


## Concha da Ópera: meia esfera alongada, inclinada para a frente.
func _concha(base: Vector3, tam: float, cor: Color) -> void:
	var seg := 10
	var aneis := 6
	var c := base + Vector3(0, tam * 0.4, 0)
	for i in range(aneis):
		for j in range(seg):
			var v := []
			for q in [[i, j], [i, j + 1], [i + 1, j + 1], [i + 1, j]]:
				var a := PI * 0.5 * float(q[0]) / aneis
				var b := PI * float(q[1]) / seg
				var p := Vector3(cos(b) * sin(a) * tam * 0.45, cos(a) * tam * 1.25, sin(b) * sin(a) * tam * 0.9)
				p = Basis(Vector3.RIGHT, -0.45).xform(p)
				v.append(base + p)
			_quad(v[0], v[1], v[2], v[3], cor, c, true)


func _barcelona() -> void:
	_chao(Color(0.48, 0.44, 0.36), 113.0, 18.0, 820.0)
	_varandas = 0.6
	_agua(Rect2(250, -1500, 1300, 1700), 0.4, Color(0.05, 0.25, 0.36))
	_morro(-300, -350, 170, 70, Color(0.3, 0.42, 0.24), Color(0.5, 0.46, 0.4), 0.0, 1.0, 0.15)
	_morro(-150, -950, 420, 190, Color(0.28, 0.38, 0.24), Color(0.45, 0.42, 0.38), 0.0, 1.1, 0.3)
	# Sagrada Família
	var s := Vector3(-20, 0, -330)
	var arenito := Color(0.8, 0.7, 0.54)
	_marco_ini(s, 1.35)
	_caixa(s + Vector3(0, 22, 0), Vector3(70, 44, 36), arenito, 0.0, null, true)
	_tronco(s + Vector3(0, 44, 0), Vector2(70, 36), Vector2(66, 4), 16.0, arenito.darkened(0.1), 0.0, true)
	for i in range(4):
		var x := -21.0 + i * 14.0
		var h := 92.0 if (i == 1 or i == 2) else 82.0
		_cilindro(s + Vector3(x, 0, 21), 4.6, 2.2, h, 10, arenito, true)
		_esfera(s + Vector3(x, h + 2.0, 21), 2.6, Color(0.9, 0.85, 0.5), Vector3.ONE, false, true, 8, 5)
	for k in range(4):
		var a := TAU * k / 4.0 + PI * 0.25
		_cilindro(s + Vector3(cos(a) * 14.0, 40, sin(a) * 10.0), 5.0, 1.6, 95.0, 10, arenito.lightened(0.05), true)
	_cilindro(s + Vector3(0, 40, 0), 7.5, 2.5, 132.0, 12, arenito.lightened(0.08), true)
	_caixa(s + Vector3(0, 174, 0), Vector3(1.2, 10, 1.2), Color(0.95, 0.95, 0.95), 0.0, null, true)
	_caixa(s + Vector3(0, 175, 0), Vector3(7, 1.2, 1.2), Color(0.95, 0.95, 0.95), 0.0, null, true)
	# guindastes da obra (sempre em obra!)
	for g in [[-40.0, 0.4], [38.0, -0.8]]:
		var gb := s + Vector3(g[0], 0, -10)
		var amarelo := Color(0.95, 0.75, 0.15)
		_caixa(gb + Vector3(0, 70, 0), Vector3(2.4, 140, 2.4), amarelo)
		_caixa(gb + Vector3(0, 140, 0) + Basis(Vector3.UP, g[1]).xform(Vector3(14, 0, 0)), Vector3(60, 2.0, 2.0), amarelo, g[1])
		if noite:
			_brilho(gb + Vector3(0, 142, 0), 5.0, Color(1.0, 0.15, 0.1, 1.0), true)
	_reservar(s.x, s.z, 55)
	if noite:
		_brilho(s + Vector3(0, 70, 0), 140.0, Color(1.0, 0.85, 0.6, 0.25))
	_marco_fim()
	# Torre Glòries (o "foguete" de vidro)
	var g2 := Vector3(260, 0, -520)
	_predio(g2, Vector3(24, 120, 24), Color(0.35, 0.45, 0.65), 0.0, 1.0)
	_esfera(g2 + Vector3(0, 120, 0), 12.0, Color(0.35, 0.45, 0.65), Vector3(1, 2.2, 1), true, noite)
	_reservar(g2.x, g2.z, 20)
	# o quadriculado do Eixample (quarteirões de esquina cortada)
	var paleta := [Color(0.9, 0.84, 0.72), Color(0.86, 0.74, 0.6), Color(0.92, 0.9, 0.84), Color(0.8, 0.66, 0.5)]
	for ix in range(-14, 15):
		for iz in range(-14, 15):
			var x2 := ix * 46.0
			var z2 := iz * 46.0
			if not _livre(x2, z2, 22.0) or _rng.randf() < 0.12:
				continue
			_reservar(x2, z2, 20.0)
			_predio(Vector3(x2, 0, z2), Vector3(36, _rng.randf_range(18, 28), 36), paleta[_rng.randi() % paleta.size()], PI * 0.25 if _rng.randf() < 0.0 else 0.0, 0.85)
	_arvores(80, R_ESTADIO + 4.0, 300.0)


func _londres() -> void:
	_chao(Color(0.38, 0.42, 0.34), 74.0, 13.0, 760.0)
	_varandas = 0.1
	_agua(Rect2(-1500, -292, 3000, 52), 0.3, Color(0.12, 0.17, 0.16))
	var pedra := Color(0.8, 0.72, 0.52)
	# o Parlamento ao longo do rio
	var p := Vector3(-120, 0, -315)
	_marco_ini(Vector3(-40, 0, -315), 1.45)
	_caixa(p + Vector3(0, 13, 0), Vector3(200, 26, 26), pedra, 0.0, null, true)
	_tronco(p + Vector3(0, 26, 0), Vector2(200, 26), Vector2(196, 4), 7.0, Color(0.4, 0.42, 0.45), 0.0, true)
	for k in range(26):
		_cone(p + Vector3(-98.0 + k * 7.8, 26, 13), 0.9, 7.0, 4, pedra, true)
	_caixa(p + Vector3(-90, 45, 0), Vector3(22, 90, 22), pedra, 0.0, null, true)
	_tronco(p + Vector3(-90, 90, 0), Vector2(22, 22), Vector2(10, 10), 10.0, Color(0.4, 0.42, 0.45), 0.0, true)
	_reservar(p.x, p.z, 105)
	# Big Ben
	var b := Vector3(10, 0, -310)
	_caixa(b + Vector3(0, 36, 0), Vector3(12, 72, 12), pedra, 0.0, null, true)
	_caixa(b + Vector3(0, 78, 0), Vector3(14, 12, 14), pedra.lightened(0.05), 0.0, null, true)
	for lado in [Vector3(0, 0, 7.1), Vector3(7.1, 0, 0), Vector3(-7.1, 0, 0), Vector3(0, 0, -7.1)]:
		var centro: Vector3 = b + Vector3(0, 78, 0) + lado
		var cor_rel := Color(1.0, 0.95, 0.75) if noite else Color(0.95, 0.93, 0.85)
		_disco(centro, lado.normalized(), 5.0, cor_rel, true)
		if noite:
			_brilho(centro + lado.normalized(), 14.0, Color(1.0, 0.9, 0.6, 0.6))
	_caixa(b + Vector3(0, 88, 0), Vector3(12, 8, 12), Color(0.42, 0.44, 0.46), 0.0, null, true)
	_tronco(b + Vector3(0, 92, 0), Vector2(12, 12), Vector2(0.4, 0.4), 18.0, Color(0.36, 0.38, 0.4), 0.0, true)
	_reservar(b.x, b.z, 14)
	_marco_fim()
	# London Eye girando do outro lado do rio
	_london_eye(Vector3(330, 0, -345))
	# The Shard
	var sh := Vector3(330, 0, -620)
	_tronco(sh, Vector2(34, 34), Vector2(2, 2), 190.0, Color(0.6, 0.7, 0.78), 0.3, noite)
	_reservar(sh.x, sh.z, 26)
	var tijolos := [Color(0.62, 0.36, 0.28), Color(0.85, 0.8, 0.7), Color(0.7, 0.66, 0.6), Color(0.55, 0.5, 0.48)]
	_quarteiroes(R_ESTADIO + 8.0, 480.0, Vector2(14, 30), Vector2(14, 24), tijolos, "", 0.9, 0.9)
	_bairro(20, 600.0, 900.0, Vector2(60, 140), Vector2(20, 30), [Color(0.55, 0.62, 0.7)], "antena", 1.0)
	_arvores(110, R_ESTADIO + 4.0, 400.0)


## Disco (relógio, mostrador) virado para "frente".
func _disco(c: Vector3, frente: Vector3, r: float, cor: Color, acesa := false) -> void:
	var x := frente.cross(Vector3.UP).normalized()
	var y := Vector3.UP
	for i in range(16):
		var a0 := TAU * i / 16.0
		var a1 := TAU * (i + 1) / 16.0
		_tri(c, c + (x * cos(a0) + y * sin(a0)) * r, c + (x * cos(a1) + y * sin(a1)) * r, cor, c - frente, acesa)


func _london_eye(base: Vector3) -> void:
	var e := 1.35
	var roda := Spatial.new()
	roda.translation = base + Vector3(0, 68, 0) * e
	roda.scale = Vector3.ONE * e
	add_child(roda)
	var st_antigo := _st
	_st = _nova()
	var n_antes: int = _nv[0]
	_nv[0] = 0
	var branco := Color(0.92, 0.93, 0.95)
	var r := 60.0
	var ant := Vector3()
	for k in range(49):
		var a := TAU * k / 48.0
		var p := Vector3(cos(a) * r, sin(a) * r, 0)
		if k > 0:
			_caixa_entre(ant, p, 1.6, branco, true)
		ant = p
		if k < 48 and k % 2 == 0:
			_caixa_entre(Vector3.ZERO, p, 0.3, branco, true)
		if k < 48 and k % 3 == 0:
			_esfera(Vector3(cos(a) * (r + 2.5), sin(a) * (r + 2.5), 0), 1.8, Color(0.75, 0.85, 0.95), Vector3(1, 0.8, 1.6), false, true, 8, 4)
	var mi := MeshInstance.new()
	mi.mesh = _st.commit()
	mi.material_override = _mat_vertices()
	roda.add_child(mi)
	_st = st_antigo
	_nv[0] = n_antes
	_anim.append([roda, Vector3.BACK, 0.05])
	_marco_ini(base, e)
	for sx in [-1, 1]:
		_caixa_entre(base + Vector3(sx * 8.0, 0, -14), base + Vector3(0, 68, 0), 2.2, branco, true)
	_reservar(base.x, base.z, 30)
	# a roda é larga: nada de prédio entrando nela
	for dx in [-60.0, 60.0]:
		_reservar(base.x + dx * e, base.z, 32)
	if noite:
		_brilho(base + Vector3(0, 68, 0), 150.0, Color(0.5, 0.6, 1.0, 0.2))
	_marco_fim()


func _roma() -> void:
	_chao(Color(0.46, 0.44, 0.34), 76.0, 13.0, 700.0)
	_varandas = 0.35
	_coliseu(Vector3(-30, 0, -320))
	# São Pedro
	var sp := Vector3(250, 0, -560)
	var travertino := Color(0.9, 0.86, 0.78)
	_marco_ini(sp, 1.4)
	_caixa(sp + Vector3(0, 22, 30), Vector3(110, 44, 30), travertino, 0.0, null, true)
	_caixa(sp + Vector3(0, 25, -20), Vector3(60, 50, 80), travertino, 0.0, null, true)
	_cilindro(sp + Vector3(0, 50, -20), 22.0, 22.0, 22.0, 18, travertino, true)
	_esfera(sp + Vector3(0, 72, -20), 23.0, Color(0.62, 0.7, 0.74), Vector3(1, 1.35, 1), true, true, 18, 10)
	_cilindro(sp + Vector3(0, 102, -20), 4.0, 4.0, 10.0, 8, travertino, true)
	_cone(sp + Vector3(0, 112, -20), 4.4, 8.0, 8, Color(0.62, 0.7, 0.74), true)
	_reservar(sp.x, sp.z - 10.0, 70)
	if noite:
		_brilho(sp + Vector3(0, 80, -20), 90.0, Color(1.0, 0.9, 0.7, 0.25))
	_marco_fim()
	# as colinas
	_morro(-450, -700, 300, 80, Color(0.34, 0.42, 0.26), Color(0.5, 0.46, 0.38), 0.0, 1.0, 0.2)
	_morro(500, -900, 350, 90, Color(0.34, 0.42, 0.26), Color(0.5, 0.46, 0.38), 0.0, 1.0, 0.2)
	var paleta := [Color(0.86, 0.66, 0.42), Color(0.78, 0.48, 0.32), Color(0.92, 0.84, 0.66), Color(0.85, 0.55, 0.35), Color(0.9, 0.78, 0.55)]
	_quarteiroes(R_ESTADIO + 8.0, 480.0, Vector2(12, 22), Vector2(14, 24), paleta, "telha", 0.8, 0.9)
	_arvores(130, R_ESTADIO + 4.0, 520.0, "guarda_chuva")


func _coliseu(c: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := 52.0
	var b := 43.0
	var seg := 80
	var pedra := Color(0.86, 0.78, 0.64)
	for parede in [[1.0, 0], [0.84, 1]]:
		var k: float = parede[0]
		for i in range(seg):
			var t0 := TAU * i / seg
			var t1 := TAU * (i + 1) / seg
			# a parte "em ruína" (mais baixa) de um lado
			var h0 := 44.0 if (cos(t0) < 0.35 or parede[1] == 1) else 34.0
			var h1 := 44.0 if (cos(t1) < 0.35 or parede[1] == 1) else 34.0
			var p0 := c + Vector3(cos(t0) * a * k, 0, sin(t0) * b * k)
			var p1 := c + Vector3(cos(t1) * a * k, 0, sin(t1) * b * k)
			var n := Vector3(cos((t0 + t1) * 0.5) / a, 0, sin((t0 + t1) * 0.5) / b).normalized()
			if parede[1] == 1:
				n = -n
			var sh := _base(pedra)
			var v := [p0, p1, p1 + Vector3(0, h1, 0), p0 + Vector3(0, h0, 0)]
			var uv := [Vector2(i, 0), Vector2(i + 1, 0), Vector2(i + 1, h1 / 11.0), Vector2(i, h0 / 11.0)]
			for q in [0, 1, 2, 0, 2, 3]:
				st.add_color(Color(sh.r, sh.g, sh.b, 1.0 if parede[1] == 0 else 0.0))
				st.add_uv(uv[q])
				st.add_normal(n)
				st.add_vertex(v[q])
	var mi := MeshInstance.new()
	mi.mesh = st.commit()
	var ec := 1.5
	mi.transform = Transform(Basis().scaled(Vector3.ONE * ec), c * (1.0 - ec))
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/arcos.shader")
	sm.set_shader_param("noite", 1.0 if noite else 0.0)
	mi.material_override = sm
	add_child(mi)
	# a arena por dentro (chão de areia)
	_marco_ini(c, ec)
	_esfera(c + Vector3(0, 0.5, 0), 1.0, Color(0.78, 0.66, 0.5), Vector3(a * 0.8, 0.05, b * 0.8), true)
	_reservar(c.x, c.z, 62)
	if noite:
		_brilho(c + Vector3(0, 22, 0), 130.0, Color(1.0, 0.85, 0.55, 0.28))
	_marco_fim()


func _estocolmo() -> void:
	_chao(Color(0.34, 0.42, 0.3), 70.0, 13.0, 600.0)
	_varandas = 0.1
	_tipo_mata = "pinheiro"
	_agua(Rect2(-1500, -1500, 3000, 1240), 0.4, Color(0.04, 0.17, 0.25))
	# ilhas com casas e floresta
	for ilha in [[-420, -560, 160, 30], [380, -420, 120, 22], [60, -820, 220, 40], [-120, -1100, 300, 60], [600, -900, 260, 50]]:
		_morro(ilha[0], ilha[1], ilha[2], ilha[3], Color(0.22, 0.36, 0.22), Color(0.45, 0.43, 0.4), 0.0, 0.8, 0.2)
	# Prefeitura (Stadshuset): tijolo vermelho, torre com as três coroas
	var s := Vector3(-80, 0, -310)
	var tijolo := Color(0.62, 0.3, 0.22)
	_marco_ini(s, 1.5)
	_caixa(s + Vector3(0, 0, 0) + Vector3(0, 13, 0), Vector3(80, 26, 44), tijolo, 0.0, null, true)
	_tronco(s + Vector3(0, 26, 0), Vector2(80, 44), Vector2(76, 6), 8.0, Color(0.3, 0.45, 0.4), 0.0, true)
	var tw := s + Vector3(32, 0, -10)
	_caixa(tw + Vector3(0, 46, 0), Vector3(16, 92, 16), tijolo, 0.0, null, true)
	_tronco(tw + Vector3(0, 92, 0), Vector2(16, 16), Vector2(10, 10), 6.0, Color(0.3, 0.55, 0.45), 0.0, true)
	_cilindro(tw + Vector3(0, 98, 0), 3.4, 0.6, 12.0, 8, Color(0.3, 0.55, 0.45), true)
	var ouro := Color(1.0, 0.82, 0.3)
	for k in range(3):
		var a := TAU * k / 3.0
		_esfera(tw + Vector3(cos(a) * 1.3, 111.0, sin(a) * 1.3), 1.1, ouro, Vector3(1, 0.7, 1), false, true, 8, 4)
	_reservar(s.x, s.z, 50)
	if noite:
		_brilho(tw + Vector3(0, 60, 0), 90.0, Color(1.0, 0.8, 0.55, 0.28))
		_brilho(tw + Vector3(0, 111, 0), 10.0, Color(1.0, 0.9, 0.5, 0.9))
	_marco_fim()
	# Gamla Stan: prédios estreitos coloridos e a agulha de Riddarholmen
	var g := Vector2(260, -560)
	_morro(g.x, g.y, 110, 8, Color(0.4, 0.42, 0.38), Color(0.45, 0.43, 0.4), 0.0, 0.5, 0.05)
	var cores := [Color(0.88, 0.6, 0.3), Color(0.7, 0.3, 0.2), Color(0.95, 0.85, 0.45), Color(0.92, 0.72, 0.6), Color(0.85, 0.82, 0.7)]
	for _i in range(70):
		var x := g.x + _rng.randf_range(-80, 80)
		var z := g.y + _rng.randf_range(-70, 70)
		if Vector2(x, z).distance_to(g) > 85.0:
			continue
		var w := _rng.randf_range(7, 11)
		var h := _rng.randf_range(14, 22)
		var cor: Color = cores[_rng.randi() % cores.size()]
		_casa(Vector3(x, 6.0, z), w, 12.0, h, 5.0, cor, Color(0.4, 0.2, 0.15), _rng.randf() * PI)
		if noite and _rng.randf() < 0.7:
			_ponto_luz(Vector3(x, 6.0 + h * 0.6, z + 6.0), 2.4, Color(1.0, 0.8, 0.5, 0.8))
	_cilindro(Vector3(g.x - 30, 6, g.y + 20), 3.0, 0.3, 80.0, 6, Color(0.2, 0.22, 0.24), true)
	_caixa(Vector3(g.x - 30, 16, g.y + 30), Vector3(14, 20, 40), Color(0.6, 0.32, 0.25), 0.0, null, true)
	_reservar(g.x, g.y, 90)
	var paleta := [Color(0.92, 0.75, 0.45), Color(0.8, 0.45, 0.32), Color(0.95, 0.9, 0.8), Color(0.85, 0.62, 0.48)]
	_quarteiroes(R_ESTADIO + 8.0, 300.0, Vector2(14, 26), Vector2(14, 22), paleta, "telha", 0.85, 0.9)
	_arvores(120, R_ESTADIO + 4.0, 320.0, "pinheiro")
	_barcos(12, Rect2(-500, -1000, 1000, 600), false)


func _peri() -> void:
	_chao(Color(0.4, 0.42, 0.36), 64.0, 12.0, 520.0)
	_varandas = 0.3
	var mata := Color(0.16, 0.36, 0.17)
	var rocha := Color(0.38, 0.4, 0.36)
	# a Serra da Cantareira atrás (mata fechada) e os morros do bairro
	_morro(-420, -820, 380, 230, mata, rocha, 0.0, 1.1, 0.3)
	_morro(120, -900, 420, 260, mata, rocha, 0.0, 1.05, 0.35)
	_morro(620, -760, 360, 200, mata, rocha, 0.0, 1.1, 0.3)
	var M1 := [Vector2(-470, -200), 170.0, 60.0, 1.0, 0.2, 1.2]
	_morro_de(M1, Color(0.3, 0.42, 0.26), rocha)
	_favela(M1, 320, 0.02, 0.85, Vector2(-PI, PI))
	var M2 := [Vector2(420, -230), 160.0, 52.0, 1.0, 0.2, 2.2]
	_morro_de(M2, Color(0.3, 0.42, 0.26), rocha)
	_favela(M2, 280, 0.02, 0.85, Vector2(-PI, PI))
	# A FÁBRICA DA LAZER & SPORT, ao lado do estádio
	var f := Vector3(-200, 0, -300)
	_marco_ini(f, 1.5)
	var parede := Color(0.86, 0.87, 0.9)
	var azul := Color(0.12, 0.2, 0.42)
	var vermelho := Color(0.86, 0.16, 0.2)
	_caixa(f + Vector3(0, 9, 0), Vector3(130, 18, 56), parede, 0.0, Color(0.6, 0.62, 0.66))
	# telhado em dente de serra (sheds com o vidro virado para cima)
	for i in range(10):
		var x0 := f.x - 65.0 + i * 13.0
		var a0 := Vector3(x0, 18, f.z - 28)
		var a1 := Vector3(x0, 18, f.z + 28)
		var b0 := Vector3(x0 + 13.0, 18, f.z - 28)
		var b1 := Vector3(x0 + 13.0, 18, f.z + 28)
		var t0 := Vector3(x0 + 13.0, 24, f.z - 28)
		var t1 := Vector3(x0 + 13.0, 24, f.z + 28)
		var cc := Vector3(x0 + 6.5, 20, f.z)
		_quad(a0, a1, t1, t0, Color(0.55, 0.57, 0.62), cc)
		_quad(b0, b1, t1, t0, Color(0.55, 0.7, 0.85), cc)
		_tri(a0, b0, t0, parede, cc)
		_tri(a1, b1, t1, parede, cc)
	# faixa azul e vermelha na fachada, portões da doca
	_caixa(f + Vector3(0, 15.5, 28.2), Vector3(130, 3.0, 0.6), azul)
	_caixa(f + Vector3(0, 2.0, 28.2), Vector3(130, 0.6, 0.6), vermelho)
	for k in range(4):
		_caixa(f + Vector3(-48 + k * 14.0, 4.5, 28.3), Vector3(9.0, 9.0, 0.4), Color(0.45, 0.47, 0.52))
	_reservar(f.x, f.z, 75)
	_marco_fim()
	# o escritório de vidro na frente e o logo grande na fachada do galpão
	_predio(Vector3(f.x + 120, 0, f.z + 14), Vector3(34, 20, 26), Color(0.92, 0.93, 0.95), 0.0, 1.0)
	_reservar(f.x + 120, f.z + 14, 24)
	var logo := MeshInstance.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(60, 39.8)
	logo.mesh = qm
	var ml := SpatialMaterial.new()
	ml.flags_unshaded = true
	ml.flags_transparent = true
	ml.albedo_texture = load("res://imagens/logo_lazer_sport.png")
	ml.albedo_color = Color(1.15, 1.15, 1.15) if noite else Color(1, 1, 1)
	logo.material_override = ml
	logo.translation = Vector3(f.x, 33.0, f.z + 28.0 * 1.5 + 0.8)
	add_child(logo)
	if noite:
		_brilho(logo.translation + Vector3(0, 0, 2), 70.0, Color(1.0, 0.95, 0.85, 0.3))
		for k in range(8):
			_ponto_luz(Vector3(f.x - 90 + k * 26.0, 14.0, f.z + 48.0), 3.5, Color(1.0, 0.85, 0.55, 0.9))
	# caminhões na doca
	for k in range(3):
		var cx := f.x - 85.0 + k * 19.0
		var cz := f.z + 60.0
		_caixa(Vector3(cx, 3.2, cz), Vector3(5.0, 5.2, 12.0), Color(0.95, 0.95, 0.96))
		_caixa(Vector3(cx, 2.2, cz + 7.6), Vector3(4.6, 3.4, 3.2), [vermelho, azul, Color(1.0, 0.78, 0.15)][k])
		_reservar(cx, cz, 9)
	# o pátio com os brinquedos que a fábrica faz
	var cores := [vermelho, Color(1.0, 0.78, 0.15), Color(0.15, 0.5, 0.95), Color(0.2, 0.7, 0.35), Color(1.0, 0.5, 0.1)]
	var px := f.x + 10.0
	var pz := f.z + 105.0
	for i in range(4):
		var b := Vector3(px + (i % 2) * 34.0, 0, pz - 20.0 + (i / 2) * 34.0)
		var c1: Color = cores[i % cores.size()]
		var c2: Color = cores[(i + 2) % cores.size()]
		# torre com telhadinho, escorregador e escada
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_cilindro(b + Vector3(sx * 3.0, 0, sz * 3.0), 0.35, 0.35, 8.0, 6, Color(0.95, 0.95, 0.95))
		_caixa(b + Vector3(0, 4.2, 0), Vector3(7.0, 0.6, 7.0), c1)
		_tronco(b + Vector3(0, 8.0, 0), Vector2(7.6, 7.6), Vector2(0.3, 0.3), 4.0, c2)
		_caixa_entre(b + Vector3(3.5, 4.4, 0), b + Vector3(12.0, 0.6, 0), 2.2, c2)
		_caixa_entre(b + Vector3(-3.5, 4.4, 0), b + Vector3(-7.0, 0.3, 0), 1.6, Color(0.95, 0.95, 0.95))
		_reservar(b.x, b.z, 14)
	# balanço e gira-gira
	var bl := Vector3(px + 70.0, 0, pz - 6.0)
	for sz in [-1, 1]:
		_caixa_entre(bl + Vector3(-4.0, 0, sz * 6.0), bl + Vector3(0, 6.0, sz * 6.0), 0.5, Color(1.0, 0.78, 0.15))
		_caixa_entre(bl + Vector3(4.0, 0, sz * 6.0), bl + Vector3(0, 6.0, sz * 6.0), 0.5, Color(1.0, 0.78, 0.15))
	_caixa(bl + Vector3(0, 6.0, 0), Vector3(0.6, 0.6, 12.6), Color(1.0, 0.78, 0.15))
	for sz in [-3.0, 0.0, 3.0]:
		_caixa(bl + Vector3(0, 1.4, sz), Vector3(1.0, 0.3, 1.6), vermelho)
	_cilindro(Vector3(px + 70.0, 0, pz + 24.0), 5.0, 5.0, 0.6, 18, Color(0.15, 0.5, 0.95))
	_reservar(px + 60, pz + 5, 30)
	# o bairro em volta (casas e sobradinhos) e alguns prédios
	var casas := [Color(0.92, 0.88, 0.8), Color(0.85, 0.55, 0.4), Color(0.95, 0.85, 0.55), Color(0.8, 0.85, 0.9), Color(0.75, 0.45, 0.35)]
	_casas(260, R_ESTADIO + 10.0, 520.0, casas, [Color(0.6, 0.32, 0.24), Color(0.5, 0.5, 0.52)])
	_bairro(50, 380.0, 700.0, Vector2(18, 45), Vector2(14, 22), [Color(0.88, 0.86, 0.82), Color(0.78, 0.76, 0.72)], "antena", 1.0)
	_arvores(140, R_ESTADIO + 4.0, 560.0)


func _tenda(base: Vector3, r: float, cores: Array) -> void:
	var seg := 16
	var h := r * 0.7
	var topo := base + Vector3(0, h + r * 0.9, 0)
	var c := base + Vector3(0, h * 0.5, 0)
	for i in range(seg):
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := base + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := base + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var cor: Color = cores[i % 2]
		_quad(p0, p1, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0), cor, c, true)
		_tri(p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), topo, cor, c, true)
	_cilindro(topo, 0.3, 0.1, 6.0, 4, Color(0.9, 0.9, 0.9))
	_reservar(base.x, base.z, r + 4.0)
	if noite:
		_brilho(topo + Vector3(0, 6, 0), 5.0, Color(1.0, 0.85, 0.4, 1.0), true)


func _cidade_moderna() -> void:
	_chao(Color(0.38, 0.42, 0.34), 84.0, 16.0, 760.0)
	_varandas = 0.35
	var vidros := [Color(0.5, 0.6, 0.7), Color(0.62, 0.7, 0.76), Color(0.75, 0.75, 0.72), Color(0.45, 0.52, 0.6)]
	for i in range(40):
		var a := _rng.randf_range(-2.4, -0.7)
		var r := _rng.randf_range(280, 520)
		var x := cos(a) * r
		var z := sin(a) * r
		if not _livre(x, z, 16):
			continue
		_reservar(x, z, 14)
		_predio(Vector3(x, 0, z), Vector3(_rng.randf_range(16, 28), _rng.randf_range(60, 170), _rng.randf_range(16, 28)), vidros[i % vidros.size()], 0.0, 1.0)
	_quarteiroes(R_ESTADIO + 8.0, 480.0, Vector2(12, 30), Vector2(14, 22), [Color(0.85, 0.82, 0.76), Color(0.75, 0.72, 0.7), Color(0.9, 0.9, 0.88)], "", 0.9, 0.9)
	_arvores(120, R_ESTADIO + 4.0, 500.0)
	_morro(-600, -900, 420, 160, Color(0.26, 0.4, 0.24), Color(0.45, 0.43, 0.4), 0.0, 1.2, 0.3)
	_morro(500, -1000, 420, 140, Color(0.26, 0.4, 0.24), Color(0.45, 0.43, 0.4), 0.0, 1.2, 0.3)
