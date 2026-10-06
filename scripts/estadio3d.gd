extends Spatial

## ESTÁDIO 3D da apresentação da Copa. Montado por código (leve: ~60
## objetos, tudo sem luz de verdade, GLES2):
##   gramado = a imagem do estádio do time (corte da grama e escudo no meio),
##   arquibancadas em 1 ou 2 anéis com a torcida animada (shader), placas de
##   publicidade, gols, os 12 tazos perfilados, bandeirões ondulando com o
##   escudo dos dois times, torres de refletores, cobertura (alguns estádios),
##   céu e clima: DIA (céu azul, sol com brilho, sombra da arquibancada) ou
##   NOITE (céu estrelado, lua cheia, refletores acesos com fachos de luz,
##   flashes de fotos e fogos), cada um com ou sem CHUVA (céu fechado,
##   neblina, chuva caindo). Cada estádio sai diferente.
##   Modo pódio (montar(..., {"podio": [1º, 2º, 3º]})): o pódio com os
##   tazos dos 3 primeiros, a taça, confete e fogos.
## A câmera é guiada por posicionar_camera(t) (preparacao.gd).

const Campo = preload("res://scripts/campo.gd")
const Paisagem = preload("res://scripts/paisagem.gd")
const Qualidade3D = preload("res://scripts/qualidade3d.gd")
const FACHO = preload("res://shaders/facho.shader")
const BRILHOS = preload("res://shaders/brilhos.shader")
const BRILHO = preload("res://imagens/brilho.png")
# sol e lua: DIREÇÕES no céu. Eles andam junto com a câmera (como o próprio
# céu), a D_CEU de distância: nunca chegam perto, dão a profundidade certa.
const SOL := Vector3(-300, 200, -560)
const LUA := Vector3(270, 160, -540)
const D_CEU := 820.0

const ESC := 0.1                      # 1 px da mesa (1280x720) = 0,1 unidade
var HX := 0.0                          # meia largura do gramado (placas)
var HZ := 0.0

var casa := ""
var fora := ""
var clima := "sol"
var camera: Camera
var _chuva: CPUParticles
var _flashes := []          # [posição, tempo restante] (desenhados no _flash_mm)
var _flash_mm: MultiMesh
var _brilhos := []          # [posição, largura, altura, cor]: um desenho só
var _brilhos_ceu := []      # sol e lua (seguem a câmera)
var _ceu_longe: Spatial
var _fogos := []
var _t := 0.0
var _prox_flash := 0.0
var _prox_fogo := 3.0
var _arquibancadas := []      # [ [origem, dir_ao_longo, dir_para_fora, comprimento, prof, alt, h0] ]
var _mat_torcida := []
var _bandeiras := []

# câmera: [t, posição, alvo]
var _quadros := []         # pódio: câmera contínua (spline)
var _chaves := []          # apresentação: voo contínuo [t, posição, alvo, fov]
const T_TV := 12.2         # a câmera chega na posição da TV (entra o confronto)
var t_tv := T_TV
# terço inferior (nome do estádio): entra e sai nesses instantes do voo
var t_terco_ini := 0.7
var t_terco_fim := 5.5
var _i_terco := 0          # chave em que a cidade/estádio aparece
var postal_nome := ""
var leve := false          # perfil TV box (qualidade3d.gd): sem luz real cara
var podio := []
var paisagem
var local := ""            # de quem é o estádio (gramado, arquitetura, cidade)
var intro := false         # abertura Lazer & Sport: só o estádio (sem gramado/gols/tazos/câmera)
var ambiente: Environment
var _cores := []           # cores da torcida no lugar das dos times (abertura)
var _bandeira: Texture
var _giro := []           # peças que giram devagar (tazo do campeão, taça)


func _noite() -> bool:
	return clima.begins_with("noite")


func _chove() -> bool:
	return clima == "chuva" or clima == "noite_chuva"


func montar(c: String, f: String, tempo: String, opcoes := {}) -> void:
	casa = c
	fora = f
	clima = tempo if tempo in ["sol", "chuva", "noite", "noite_chuva"] else "sol"
	podio = opcoes.get("podio", [])
	local = opcoes.get("estadio", c)
	intro = opcoes.get("intro", false)
	_cores = opcoes.get("cores", [])
	_bandeira = opcoes.get("bandeira", null)
	leve = opcoes.get("leve", Qualidade3D.leve())
	HX = Campo.MURO.size.x * ESC * 0.5
	HZ = Campo.MURO.size.y * ESC * 0.5
	var v := _estilo(local)
	_ceu()
	_luzes()
	_chao()
	if not intro:
		_gramado()
		_placas()
		_gols()
		if podio.empty():
			_tazos()
		else:
			_podio()
	_estadio(v)
	_torres(v)
	_bandeiroes()
	_astros()
	if not opcoes.get("sem_paisagem", false):
		paisagem = Paisagem.new()
		paisagem.leve = leve
		paisagem.astro = ((SOL if not _noite() else LUA) - Vector3(0, 0, -300)).normalized()
		add_child(paisagem)
		paisagem.montar(local, clima)
	if _chove():
		_fazer_chuva()
	if _noite() or not podio.empty():
		_fazer_flashes()
		_fazer_fogos()
	_fundir()
	add_child(_multi_brilhos(_brilhos))
	_ceu_longe.add_child(_multi_brilhos(_brilhos_ceu))
	if intro:
		return
	camera = Camera.new()
	camera.fov = 55.0
	camera.far = 2600.0
	camera.near = 0.6        # mais precisão de profundidade: sem "riscos" piscando
	add_child(camera)
	camera.current = true
	if not podio.empty():
		# pódio: a câmera gira em volta e chega perto do campeão
		_quadros = [
			[0.0, Vector3(-70, 46, 70), Vector3(0, 6, 0)],
			[3.0, Vector3(-34, 18, 40), Vector3(0, 7, 0)],
			[6.0, Vector3(0, 11, 36), Vector3(0, 12.5, 0)],
			[9.0, Vector3(20, 10, 29), Vector3(0, 12.5, 0)],
			[15.0, Vector3(-18, 10, 29), Vector3(0, 12.5, 0)],
		]
	else:
		# a apresentação num VOO CONTÍNUO (sem corte nenhum): o cartão-postal
		# da cidade, o mergulho por cima da arquibancada, a torcida e os
		# bandeirões rente ao gramado, os tazos perfilados até a bola e a
		# subida para a câmera da TV. A velocidade nunca dá tranco (curva
		# de Hermite com tangentes pelo tempo). [t, posição, alvo, fov]
		_chaves = [
			[0.0, Vector3(150, 100, 470), Vector3(-25, 44, -300), 50.0],
			[2.8, Vector3(92, 70, 300), Vector3(-24, 32, -290), 46.0],
			[4.3, Vector3(30, 54, 98), Vector3(-10, 10, -40), 50.0],
			[5.3, Vector3(-16, 40, 44), Vector3(-26, 9, -44), 54.0],
			[6.5, Vector3(-44, 8, -16), Vector3(-30, 9, -46), 54.0],
			[8.0, Vector3(16, 12, -15), Vector3(40, 10, -46), 50.0],
			[9.4, Vector3(-50, 3.2, 10), Vector3(-34, 0.8, 0), 48.0],
			[10.8, Vector3(-9, 5.6, 12.5), Vector3(8, 0.6, 0), 44.0],
			[11.5, Vector3(10, 30, 26), Vector3(4, 0, 2), 52.0],
			[T_TV, Vector3(38, 44, HZ + 40), Vector3(0, -2, 4), 55.0],
			[T_TV + 9.0, Vector3(-34, 40, HZ + 38), Vector3(0, -2, 4), 55.0],
		]
		# com cobertura, a câmera da TV fica por baixo do teto
		var zt := -1.0
		if v.forma == "tigela" and v.teto != "":
			zt = _tigela.b + 12.0
		elif v.forma == "caixa" and v.cobertura:
			zt = HZ + 24.0
		if zt > 0.0:
			_chaves[_chaves.size() - 2][1] = Vector3(36, 27, zt)
			_chaves[_chaves.size() - 1][1] = Vector3(-34, 26, zt - 1.0)
		if paisagem != null and not paisagem.postal.empty():
			_abrir_no_postal(paisagem.postal)
		_cronometrar()
	posicionar_camera(0.0)


# ------------------------------------------------------- estilos reais
## Cada seleção joga num estádio no estilo do estádio de verdade dela:
##   "caixa": 4 arquibancadas retas (com ou sem cobertura e cantos)
##   "tigela": um anel contínuo em volta do campo, na curva de uma
##   superelipse de expoente n (2 = oval, 4 = retângulo arredondado, 8 =
##   quase reto), com 1 ou 2 anéis, cobertura e fachada de cada estádio.
const ESTILOS := {
	# Maracanã: oval, dois anéis, o anel branco de cobertura
	"BRA": {"forma": "tigela", "n": 2.2, "aneis": 2, "teto": "anel", "fachada": 0.0},
	# Monumental (Buenos Aires): oval aberto, torres de luz em volta
	"ARG": {"forma": "tigela", "n": 2.0, "aneis": 2, "teto": "", "fachada": 0.0},
	# Olímpico de Roma: oval com pista de atletismo e membrana branca
	"ITA": {"forma": "tigela", "n": 2.0, "aneis": 2, "teto": "membrana", "pista": true, "fachada": 0.0},
	# Stade de France: oval, teto elíptico "flutuando" sobre mastros finos
	"FRA": {"forma": "tigela", "n": 2.4, "aneis": 2, "teto": "disco", "fachada": 0.0},
	# Arena de Munique: retângulo arredondado fechado, almofadas acesas
	"ALE": {"forma": "tigela", "n": 4.0, "aneis": 2, "teto": "anel", "fachada": 1.0},
	# Ullevaal (Oslo): compacto, 4 arquibancadas cobertas, cantos fechados
	"NOR": {"forma": "caixa", "aneis": 2, "cobertura": true, "cantos": true, "altura": 0.9},
	# Friends Arena (Estocolmo): caixa alta arredondada, fachada de metal
	"SUE": {"forma": "tigela", "n": 6.0, "aneis": 2, "teto": "anel", "fachada": 2.0},
	# Stadium Australia (Sydney): oval com os dois grandes arcos do teto
	"AUS": {"forma": "tigela", "n": 2.2, "aneis": 2, "teto": "arcos", "fachada": 0.0},
	# Wembley: retângulo arredondado, cobertura e o grande arco branco
	"ING": {"forma": "tigela", "n": 4.0, "aneis": 2, "teto": "anel", "arco": true, "fachada": 2.0},
	# Bernabéu: quase reto, todo coberto, fachada de lâminas metálicas
	"ESP": {"forma": "tigela", "n": 8.0, "aneis": 2, "teto": "anel", "fachada": 2.0},
}


## O estilo do estádio de cada seleção; os outros (Lazer & Sport, time do
## pendrive) são caixas com variações sorteadas pela sigla.
func _estilo(sigla: String) -> Dictionary:
	var e := _variacao(sigla)
	e["forma"] = "caixa"
	var real: Dictionary = ESTILOS.get(sigla, {})
	for k in real:
		e[k] = real[k]
	return e


func _variacao(sigla: String) -> Dictionary:
	var h := 0
	for ch in sigla:
		h = (h * 31 + ord(ch)) % 1000003
	return {"aneis": 1 + h % 2, "cobertura": (h / 2) % 2 == 1, "altura": 0.9 + float((h / 4) % 4) * 0.1,
		"cantos": (h / 16) % 2 == 1}


# --------------------------------------------------------------- materiais
## Material com LUZ DE VERDADE (sol/lua, refletores, sombras); o que brilha
## (cor acima de 1) ou é transparente fica sem luz.
func _mat_cor(cor: Color, transparente := false) -> SpatialMaterial:
	var m := SpatialMaterial.new()
	m.flags_unshaded = transparente or cor.r > 1.0 or cor.g > 1.0 or cor.b > 1.0
	m.albedo_color = cor
	m.roughness = 0.82
	m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	if transparente:
		m.flags_transparent = true
	return m


func _luz_geral() -> float:
	return {"sol": 1.0, "chuva": 0.74, "noite": 0.42, "noite_chuva": 0.36}[clima]


# ------------------------------------------------------------- geometria
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: Material) -> MeshInstance:
	# a-b: borda da frente (v = 1); d-c: borda de trás (v = 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [[a, Vector2(0, 1)], [b, Vector2(1, 1)], [c, Vector2(1, 0)], [a, Vector2(0, 1)], [c, Vector2(1, 0)], [d, Vector2(0, 0)]]
	var n := (b - a).cross(c - a)
	n = n.normalized() if n.length_squared() > 1e-10 else Vector3.UP
	for p in pts:
		st.add_uv(p[1])
		st.add_normal(n)
		st.add_vertex(p[0])
	var mi := MeshInstance.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	return mi


func _caixa(centro: Vector3, tam: Vector3, mat: Material) -> MeshInstance:
	var mi := MeshInstance.new()
	var cm := CubeMesh.new()
	cm.size = tam
	mi.mesh = cm
	mi.material_override = mat
	mi.translation = centro
	add_child(mi)
	return mi


# ---------------------------------------------------------------- céu e chão
func _ceu() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# o céu vem pronto do Jogo (reflexo calculado uma vez só por clima)
	var ps := Jogo.ceu({"sol": "dia", "chuva": "chuva", "noite": "noite", "noite_chuva": "noite"}[clima])
	env.background_mode = Environment.BG_SKY
	env.background_sky = ps
	env.background_energy = 0.55 if clima == "noite_chuva" else 1.0
	env.fog_enabled = true
	env.fog_depth_enabled = true
	match clima:
		"chuva":
			env.fog_color = Color(0.5, 0.53, 0.58)
			env.fog_depth_begin = 140.0
			env.fog_depth_end = 1500.0
			env.fog_depth_curve = 0.7
		"noite_chuva":
			env.fog_color = Color(0.07, 0.08, 0.12)
			env.fog_depth_begin = 80.0
			env.fog_depth_end = 1000.0
			env.fog_depth_curve = 0.7
		"noite":
			env.fog_color = Color(0.04, 0.05, 0.1)
			env.fog_depth_begin = 300.0
			env.fog_depth_end = 1800.0
		_:
			env.fog_color = Color(0.7, 0.8, 0.93)
			env.fog_depth_begin = 300.0
			env.fog_depth_end = 1900.0
	# brilho (bloom) nas luzes: refletores, lua, sol, fogos (GLES3)
	env.glow_enabled = not leve      # TV box: halos e estrias fazem o brilho
	env.glow_intensity = 0.7 if _noite() else 0.4
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set("glow_levels/3", true)
	env.set("glow_levels/5", true)
	if clima == "sol":
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.12
		env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	ambiente = env


## As luzes: o sol (com sombras) de dia, a lua fraca de noite e os
## refletores do estádio iluminando o gramado; luz ambiente do céu.
func _luzes() -> void:
	var cfg = {"sol": [Color(1.0, 0.95, 0.86), 1.15, Color(0.62, 0.68, 0.8), 0.6],
		"chuva": [Color(0.85, 0.88, 0.95), 0.5, Color(0.72, 0.74, 0.78), 0.8],
		"noite": [Color(0.6, 0.7, 1.0), 0.25, Color(0.36, 0.42, 0.6), 0.5],
		"noite_chuva": [Color(0.6, 0.66, 0.85), 0.15, Color(0.36, 0.4, 0.52), 0.5]}[clima]
	var sol := DirectionalLight.new()
	sol.light_color = cfg[0]
	sol.light_energy = cfg[1]
	sol.transform = Transform().looking_at(Vector3(0.5, -0.78, -0.42).normalized(), Vector3.UP)
	if (clima == "sol" or clima == "chuva") and not leve:
		sol.shadow_enabled = true
		sol.shadow_color = Color(0.25, 0.28, 0.38) if clima == "sol" else Color(0.5, 0.52, 0.56)
		sol.directional_shadow_mode = DirectionalLight.SHADOW_PARALLEL_2_SPLITS
		sol.directional_shadow_max_distance = 420.0
		sol.directional_shadow_normal_bias = 0.6
		sol.shadow_bias = 0.08
	add_child(sol)
	ambiente.ambient_light_color = cfg[2]
	ambiente.ambient_light_energy = cfg[3]
	ambiente.ambient_light_sky_contribution = 0.0
	if _noite() and leve:
		_pocas_de_luz()
	elif _noite():
		# os refletores: quatro fachos fortes no gramado e na arquibancada
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var sp := SpotLight.new()
				sp.light_color = Color(1.0, 0.96, 0.88)
				sp.light_energy = 1.8
				sp.spot_range = 160.0
				sp.spot_angle = 42.0
				sp.spot_attenuation = 1.2
				var de := Vector3(sx * (HX + 20), 49, sz * (HZ + 20))
				sp.transform = Transform().looking_at(Vector3(-sx * 10.0, 0, -sz * 6.0) - de, Vector3.UP)
				sp.translation = de
				add_child(sp)


func _chao() -> void:
	# a esplanada de concreto em volta do estádio (a paisagem faz o resto)
	var m := _mat_cor(Color(0.5, 0.5, 0.48))
	_quad(Vector3(-128, -0.05, 106), Vector3(128, -0.05, 106), Vector3(128, -0.05, -106), Vector3(-128, -0.05, -106), m)


func _gramado() -> void:
	var mi := MeshInstance.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(HX * 2.0, HZ * 2.0)
	mi.mesh = pm
	var m := SpatialMaterial.new()
	m.roughness = 0.95
	m.albedo_texture = Jogo.estadio(local, false)
	var tela := Vector2(1280, 720)
	m.uv1_offset = Vector3(Campo.MURO.position.x / tela.x, Campo.MURO.position.y / tela.y, 0)
	m.uv1_scale = Vector3(Campo.MURO.size.x / tela.x, Campo.MURO.size.y / tela.y, 1)
	# noite: refletores deixam o gramado claro; chuva: mais escuro e frio
	m.albedo_color = {"sol": Color(1.0, 1.0, 0.97), "chuva": Color(0.9, 0.94, 0.98), "noite": Color(1.0, 1.0, 1.0), "noite_chuva": Color(0.92, 0.95, 1.0)}[clima]
	m.flags_use_point_size = false
	if _noite() and leve:
		# TV box: sem refletor de luz real, o gramado brilha como iluminado
		# pelos refletores (emissão com a própria grama, custo zero)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.98, 0.92)
		m.emission_texture = m.albedo_texture
		m.emission_operator = SpatialMaterial.EMISSION_OP_MULTIPLY   # a cor da própria grama, sem véu branco
		m.emission_energy = 0.55 if clima == "noite" else 0.42
	mi.material_override = m
	add_child(mi)
	if _chove():
		# gramado molhado: reflexo leve por cima
		var brilho_agua := _mat_cor(Color(0.75, 0.82, 0.95, 0.12), true)
		_quad(Vector3(-HX, 0.02, HZ), Vector3(HX, 0.02, HZ), Vector3(HX, 0.02, -HZ), Vector3(-HX, 0.02, -HZ), brilho_agua)


func _placas() -> void:
	var cores := [Color(Jogo.cor_camisa(casa, 1)), Color("#0b1e5b"), Color(Jogo.cor_borda(casa, 1)), Color("#111111")]
	var n := 0
	for lado in [-1, 1]:
		for i in range(8):
			var x := -HX + (i + 0.5) * HX * 2.0 / 8.0
			_caixa(Vector3(x, 0.55, lado * (HZ + 0.4)), Vector3(HX * 2.0 / 8.0 - 0.3, 1.1, 0.25), _mat_cor(cores[n % 4].lightened(0.05)))
			n += 1
		for i in range(4):
			var z := -HZ + (i + 0.5) * HZ * 2.0 / 4.0
			_caixa(Vector3(lado * (HX + 0.4), 0.55, z), Vector3(0.25, 1.1, HZ * 2.0 / 4.0 - 0.3), _mat_cor(cores[n % 4].lightened(0.05)))
			n += 1


func _gols() -> void:
	var branco := _mat_cor(Color(0.96, 0.96, 0.96))
	var rede := _mat_cor(Color(1, 1, 1, 0.28), true)
	var meia := Campo.GOL_MEIA * ESC
	var fundo := Campo.GOL_FUNDO * ESC
	var alt := 2.2
	for lado in [-1, 1]:
		var x = lado * (Campo.CAMPO.size.x * 0.5 * ESC)
		for z in [-meia, meia]:
			_caixa(Vector3(x, alt * 0.5, z), Vector3(0.22, alt, 0.22), branco)
		_caixa(Vector3(x, alt, 0), Vector3(0.22, 0.22, meia * 2.0 + 0.22), branco)
		var xf = x + lado * fundo
		_quad(Vector3(xf, 0, -meia), Vector3(xf, 0, meia), Vector3(xf, alt * 0.8, meia), Vector3(xf, alt * 0.8, -meia), rede)
		_quad(Vector3(x, alt, -meia), Vector3(x, alt, meia), Vector3(xf, alt * 0.8, meia), Vector3(xf, alt * 0.8, -meia), rede)
		for z2 in [-meia, meia]:
			_quad(Vector3(x, 0, z2), Vector3(xf, 0, z2), Vector3(xf, alt * 0.8, z2), Vector3(x, alt, z2), rede)


## Os 12 tazos perfilados no meio-campo e a bola no centro.
func _tazos() -> void:
	var u := Jogo.escolher_uniformes(casa, fora)
	for t in [0, 1]:
		var sg := casa if t == 0 else fora
		var tex := Jogo.textura_botao(sg, u[t])
		for i in range(6):
			var x := -14.0 - i * 6.2 if t == 0 else 14.0 + i * 6.2
			var z := 0.0
			var lado := MeshInstance.new()
			var cil := CylinderMesh.new()
			cil.top_radius = 2.3
			cil.bottom_radius = 2.4
			cil.height = 0.7
			cil.radial_segments = 24
			lado.mesh = cil
			lado.material_override = _mat_cor(Jogo.cor_borda(sg, u[t]).darkened(0.25))
			lado.translation = Vector3(x, 0.35, z)
			add_child(lado)
			var topo := MeshInstance.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(4.8, 4.8)
			topo.mesh = qm
			var m := SpatialMaterial.new()
			m.flags_unshaded = true
			m.flags_transparent = true
			m.params_cull_mode = SpatialMaterial.CULL_DISABLED
			if tex != null:
				m.albedo_texture = tex
			else:
				m.albedo_texture = Jogo.emblema(sg)
			topo.material_override = m
			topo.rotation_degrees = Vector3(-90, 0, 0)
			topo.translation = Vector3(x, 0.72, z)
			add_child(topo)
	var bola := MeshInstance.new()
	var sp := SphereMesh.new()
	sp.radius = 0.9
	sp.height = 1.8
	bola.mesh = sp
	var mb := SpatialMaterial.new()
	mb.flags_unshaded = true
	mb.albedo_texture = load("res://imagens/bola.png")
	bola.material_override = mb
	bola.translation = Vector3(0, 0.9, 0)
	add_child(bola)


# ------------------------------------------------------------- arquibancadas
## Cores da torcida: as do time, ou as da abertura (cores do jogo).
func _visual(sigla: String, i: int) -> Dictionary:
	if _cores.empty():
		return Jogo.selecao(sigla)
	var a: Color = _cores[i % _cores.size()]
	var b: Color = _cores[(i + 1) % _cores.size()]
	return {"torcida": [a.to_html(false), b.to_html(false)]}


func _estadio(v: Dictionary) -> void:
	if v.forma == "tigela":
		_estadio_tigela(v)
	else:
		_estadio_caixa(v)


func _estadio_caixa(v: Dictionary) -> void:
	var sa := _visual(casa, 0)
	var sf := _visual(fora, 2)
	var assento := Color(sa.torcida[1]).darkened(0.55)
	var concreto := _mat_cor(Color(0.55, 0.56, 0.6))
	var concreto_escuro := _mat_cor(Color(0.32, 0.33, 0.37))
	var luz := _luz_geral() + (0.05 if _noite() else 0.0)
	var recuo := 2.6
	var alt: float = v.altura
	# lados: [ponto inicial, direção ao longo, direção para fora, comprimento, visitante?]
	var lados := [
		[Vector3(-HX - recuo, 0, -HZ - recuo), Vector3(1, 0, 0), Vector3(0, 0, -1), HX * 2.0 + recuo * 2.0, 0.12],
		[Vector3(HX + recuo, 0, HZ + recuo), Vector3(-1, 0, 0), Vector3(0, 0, 1), HX * 2.0 + recuo * 2.0, 0.15],
		[Vector3(-HX - recuo, 0, HZ + recuo), Vector3(0, 0, -1), Vector3(-1, 0, 0), HZ * 2.0 + recuo * 2.0, 0.1],
		[Vector3(HX + recuo, 0, -HZ - recuo), Vector3(0, 0, 1), Vector3(1, 0, 0), HZ * 2.0 + recuo * 2.0, 0.85],
	]
	for L in lados:
		var o: Vector3 = L[0]
		var ao_longo: Vector3 = L[1]
		var para_fora: Vector3 = L[2]
		var comp: float = L[3]
		var mistura: float = L[4]
		var h0 := 1.6
		var prof1 := 20.0
		var alt1 := 12.0 * alt
		var a := o
		var b := o + ao_longo * comp
		# mureta da frente
		_quad(a, b, b + Vector3(0, h0, 0), a + Vector3(0, h0, 0), concreto_escuro)
		# 1º anel
		var m1 := _mat_torcida_nova(sa, sf, assento, mistura, luz, Vector2(comp / 0.68, prof1 / 0.95))
		var f1a := a + Vector3(0, h0, 0)
		var f1b := b + Vector3(0, h0, 0)
		var t1a := a + para_fora * prof1 + Vector3(0, h0 + alt1, 0)
		var t1b := b + para_fora * prof1 + Vector3(0, h0 + alt1, 0)
		_quad(f1a, f1b, t1b, t1a, m1)
		_arquibancadas.append([f1a, ao_longo, para_fora, comp, prof1, alt1])
		var topo_a := t1a
		var topo_b := t1b
		if v.aneis == 2:
			# faixa dos camarotes (vidro com janelas acesas) e o 2º anel
			var vidro := _mat_cor(Color(0.12, 0.2, 0.3) if not _noite() else Color(0.95, 0.85, 0.55))
			_quad(t1a, t1b, t1b + Vector3(0, 3.0, 0), t1a + Vector3(0, 3.0, 0), vidro)
			var prof2 := 14.0
			var alt2 := 11.0 * alt
			var f2a := t1a + Vector3(0, 3.0, 0) + para_fora * 1.5
			var f2b := t1b + Vector3(0, 3.0, 0) + para_fora * 1.5
			_quad(t1a + Vector3(0, 3.0, 0), t1b + Vector3(0, 3.0, 0), f2b, f2a, concreto)
			var m2 := _mat_torcida_nova(sa, sf, assento, mistura, luz * 0.92, Vector2(comp / 0.72, prof2 / 1.0))
			topo_a = f2a + para_fora * prof2 + Vector3(0, alt2, 0)
			topo_b = f2b + para_fora * prof2 + Vector3(0, alt2, 0)
			_quad(f2a, f2b, topo_b, topo_a, m2)
		# parede de trás (fecha a arquibancada vista de fora)
		var chao_a := Vector3(topo_a.x, 0, topo_a.z)
		var chao_b := Vector3(topo_b.x, 0, topo_b.z)
		var fachada := ShaderMaterial.new()
		fachada.shader = load("res://shaders/fachada.shader")
		fachada.set_shader_param("cor", Color(0.62, 0.63, 0.66))
		fachada.set_shader_param("faixa", Color(sa.torcida[0]))
		fachada.set_shader_param("tam", Vector2(chao_a.distance_to(chao_b), topo_a.y + 1.2))
		fachada.set_shader_param("noite", 1.0 if _noite() else 0.0)
		fachada.set_shader_param("luz", _luz_geral() + (0.35 if _noite() else 0.0))
		_quad(chao_a, chao_b, topo_b + Vector3(0, 1.2, 0), topo_a + Vector3(0, 1.2, 0), fachada)
		# cobertura
		if v.cobertura:
			# membrana translúcida (dá para ver a torcida por baixo)
			var cor_teto := Color(0.9, 0.92, 0.96)
			var teto := _mat_cor(Color(cor_teto.r, cor_teto.g, cor_teto.b, 0.35), true)
			var frente_a := topo_a + Vector3(0, 7.0, 0) - para_fora * 13.0
			var frente_b := topo_b + Vector3(0, 7.0, 0) - para_fora * 13.0
			_quad(frente_a, frente_b, topo_b + Vector3(0, 5.0, 0), topo_a + Vector3(0, 5.0, 0), teto)
			# vigas
			for k in range(5):
				var p := topo_a.linear_interpolate(topo_b, (k + 0.5) / 5.0)
				_caixa(p + Vector3(0, 2.6, 0), Vector3(0.6, 5.2, 0.6), concreto_escuro)
			if _noite():
				for k in range(9):
					var q := frente_a.linear_interpolate(frente_b, (k + 0.5) / 9.0) + Vector3(0, -0.4, 0)
					_brilho(q, 3.4, Color(1, 0.96, 0.85, 0.5))
	if v.cantos:
		# cantos fechados (torcida também nos cantos)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var c0 := Vector3(sx * (HX + recuo), 1.6, sz * (HZ + recuo))
				var m3 := _mat_torcida_nova(sa, sf, assento, 0.12 if sx < 0 else 0.6, luz, Vector2(20, 20))
				var pa := c0 + Vector3(sx * 20.0, 12.0 * alt, 0)
				var pb := c0 + Vector3(0, 12.0 * alt, sz * 20.0)
				_quad(c0, c0, pb, pa, m3)


# ------------------------------------------------------------- tigela
const N_TIGELA := 72          # gomos do anel (volta inteira)
var _tigela := {}             # medidas do anel: a, b (dentro), a_fora, b_fora, n, topo


## Ponto da superelipse (x = a·cos, z = b·sen, "achatado" pelo expoente n).
static func _p_tigela(th: float, a: float, b: float, n: float) -> Vector3:
	var c := cos(th)
	var s := sin(th)
	return Vector3(a * sign(c) * pow(abs(c), 2.0 / n), 0.0, b * sign(s) * pow(abs(s), 2.0 / n))


## Direção para fora (no chão) da superelipse no ângulo th.
static func _fora_tigela(th: float, a: float, b: float, n: float) -> Vector3:
	var t := _p_tigela(th + 0.01, a, b, n) - _p_tigela(th - 0.01, a, b, n)
	return Vector3(t.z, 0.0, -t.x).normalized()


## Faixa entre duas linhas de pontos (frente: v = 1, trás: v = 0; u ao longo
## do comprimento). Devolve [nó, comprimento].
func _faixa(frente: Array, tras: Array, mat: Material) -> Array:
	var comp := [0.0]
	for i in range(1, frente.size()):
		comp.append(comp[i - 1] + frente[i].distance_to(frente[i - 1]))
	var total: float = max(comp[comp.size() - 1], 0.01)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(frente.size() - 1):
		var a: Vector3 = frente[i]
		var b: Vector3 = frente[i + 1]
		var c: Vector3 = tras[i + 1]
		var d: Vector3 = tras[i]
		var ua: float = comp[i] / total
		var ub: float = comp[i + 1] / total
		var n := (b - a).cross(c - a)
		n = n.normalized() if n.length_squared() > 1e-10 else Vector3.UP
		for q in [[a, ua, 1.0], [b, ub, 1.0], [c, ub, 0.0], [a, ua, 1.0], [c, ub, 0.0], [d, ua, 0.0]]:
			st.add_uv(Vector2(q[1], q[2]))
			st.add_normal(n)
			st.add_vertex(q[0])
	var mi := MeshInstance.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	return [mi, total]


## Viga reta de "de" até "ate" (mastros, cabos, arcos).
func _viga(de: Vector3, ate: Vector3, esp: float, mat: Material) -> void:
	var d := ate - de
	if d.length() < 0.01:
		return
	var mi := _caixa((de + ate) * 0.5, Vector3(esp, esp, d.length()), mat)
	var cima := Vector3.UP if abs(d.normalized().y) < 0.95 else Vector3.RIGHT
	mi.look_at_from_position(mi.translation, ate, cima)


func _estadio_tigela(v: Dictionary) -> void:
	var sa := _visual(casa, 0)
	var sf := _visual(fora, 2)
	var assento := Color(sa.torcida[1]).darkened(0.55)
	var concreto := _mat_cor(Color(0.55, 0.56, 0.6))
	var concreto_escuro := _mat_cor(Color(0.32, 0.33, 0.37))
	var luz := _luz_geral() + (0.05 if _noite() else 0.0)
	var n: float = v.n
	var alt: float = v.altura
	# anel de dentro: o menor que ainda deixa o campo (e as placas) livres
	var a := HX + 4.0 + 28.0 / n
	var b := HZ / pow(max(0.05, 1.0 - pow(HX / a, n)), 1.0 / n) + 3.0
	if v.get("pista", false):
		a += 8.0
		b += 8.0
	var h0 := 1.6
	var prof1 := 18.0
	var alt1 := 12.0 * alt
	var prof2 := 14.0
	var alt2 := 11.0 * alt
	var dois: bool = v.aneis == 2
	# as linhas do anel, gomo a gomo
	var L := {"chao": [], "mureta": [], "t1": [], "v1": [], "f2": [], "t2": [], "fora": []}
	var ths := []
	for i in range(N_TIGELA + 1):
		var th := TAU * float(i) / N_TIGELA - PI     # começa no meio da ponta x- (costura escondida)
		ths.append(th)
		var p := _p_tigela(th, a, b, n)
		var nr := _fora_tigela(th, a, b, n)
		var t1 := p + nr * prof1 + Vector3(0, h0 + alt1, 0)
		L.chao.append(p)
		L.mureta.append(p + Vector3(0, h0, 0))
		L.t1.append(t1)
		L.v1.append(t1 + Vector3(0, 3.0, 0))
		var f2 := t1 + Vector3(0, 3.0, 0) + nr * 1.5
		L.f2.append(f2)
		var topo: Vector3 = f2 + nr * prof2 + Vector3(0, alt2, 0) if dois else t1
		L.t2.append(topo)
		L.fora.append(Vector3(topo.x, 0, topo.z))
	var topo_y: float = L.t2[0].y
	_tigela = {"a": a, "b": b, "n": n, "a_fora": abs(L.fora[0].x), "b_fora": abs(L.fora[N_TIGELA / 4].z), "topo": topo_y}
	_faixa(L.chao, L.mureta, concreto_escuro)
	# torcida: a ponta x+ (ângulo perto de 0) é a dos visitantes
	var visit := []
	var casa_i := []
	for i in range(ths.size()):
		if abs(ths[i]) <= 0.75:
			visit.append(i)
		else:
			casa_i.append(i)
	for parte in [[casa_i, 0.12], [visit, 0.85]]:
		var idx: Array = parte[0]
		# a parte da casa dá a volta pela ponta x- (fim e começo da lista)
		var seq := idx
		if parte[1] < 0.5:
			seq = []
			for k in idx:
				if ths[k] > 0.0:
					seq.append(k)
			for k in idx:
				if ths[k] < 0.0:
					seq.append(k)
		var fr1 := []
		var tr1 := []
		var fr2 := []
		var tr2 := []
		for k in seq:
			fr1.append(L.mureta[k])
			tr1.append(L.t1[k])
			fr2.append(L.f2[k])
			tr2.append(L.t2[k])
		var r1 := _faixa(fr1, tr1, ShaderMaterial.new())
		r1[0].material_override = _mat_torcida_nova(sa, sf, assento, parte[1], luz, Vector2(r1[1] / 0.68, prof1 / 0.95))
		if dois:
			var r2 := _faixa(fr2, tr2, ShaderMaterial.new())
			r2[0].material_override = _mat_torcida_nova(sa, sf, assento, parte[1], luz * 0.92, Vector2(r2[1] / 0.72, prof2 / 1.0))
	if dois:
		var vidro := _mat_cor(Color(0.12, 0.2, 0.3) if not _noite() else Color(0.95, 0.85, 0.55))
		_faixa(L.t1, L.v1, vidro)
		_faixa(L.v1, L.f2, concreto)
	# em volta do campo até a arquibancada: pista de atletismo (Olímpico) ou
	# grama (os outros); a borda de dentro contorna o campo sem cobri-lo
	var pista: bool = v.get("pista", false)
	var dentro := []
	var borda := []
	for i in range(ths.size()):
		if pista:
			dentro.append(_p_tigela(ths[i], HX + 5.0, HZ + 5.0, 8.0) + Vector3(0, 0.02, 0))
		else:
			dentro.append(_p_tigela(ths[i], HX + 2.0, HZ + 2.0, 16.0) + Vector3(0, 0.02, 0))
		borda.append(L.chao[i] + Vector3(0, 0.02, 0))
	_faixa(dentro, borda, _mat_cor(Color(0.72, 0.25, 0.18) if pista else Color(0.16, 0.42, 0.2)))
	# fachada (vista de fora)
	var topo_fora := []
	for p in L.t2:
		topo_fora.append(p + Vector3(0, 1.2, 0))
	var fach := ShaderMaterial.new()
	fach.shader = load("res://shaders/fachada.shader")
	var cor_fach := Color(0.62, 0.63, 0.66) if v.fachada < 0.5 else Color(0.9, 0.92, 0.95)
	fach.set_shader_param("cor", cor_fach)
	fach.set_shader_param("faixa", Color(sa.torcida[0]))
	fach.set_shader_param("noite", 1.0 if _noite() else 0.0)
	fach.set_shader_param("luz", _luz_geral() + (0.35 if _noite() else 0.0))
	fach.set_shader_param("estilo", v.fachada)
	var rf := _faixa(L.fora, topo_fora, fach)
	fach.set_shader_param("tam", Vector2(rf[1], topo_y + 1.2))
	_arquibancadas_tigela(a, b, n, h0, prof1, alt1)
	_teto_tigela(v, L, ths)


## As 4 "arquibancadas" retas aproximadas no meio de cada lado (onde ficam
## os bandeirões e os flashes), na ordem das da caixa: z-, z+, x-, x+.
func _arquibancadas_tigela(a: float, b: float, n: float, h0: float, prof1: float, alt1: float) -> void:
	for lado in [[-PI / 2.0, 0.45], [PI / 2.0, 0.45], [PI, 0.32], [0.0, 0.32]]:
		var p0 := _p_tigela(lado[0] - lado[1], a, b, n)
		var p1 := _p_tigela(lado[0] + lado[1], a, b, n)
		var nr := _fora_tigela(lado[0], a, b, n)
		_arquibancadas.append([p0 + Vector3(0, h0, 0), (p1 - p0).normalized(), nr, p0.distance_to(p1), prof1, alt1])


func _teto_tigela(v: Dictionary, L: Dictionary, ths: Array) -> void:
	var tipo: String = v.teto
	var branco := _mat_cor(Color(0.93, 0.94, 0.96))
	var aco := _mat_cor(Color(0.78, 0.8, 0.84))
	var a: float = _tigela.a
	var b: float = _tigela.b
	var n: float = _tigela.n
	var dentro := []
	var fora_l := []
	var luzes := []          # beirada de dentro do teto (refletores)
	for i in range(ths.size()):
		var th: float = ths[i]
		var nr := _fora_tigela(th, a, b, n)
		var topo: Vector3 = L.t2[i]
		var coberto := true
		if tipo == "arcos":
			# só os lados compridos ficam cobertos (debaixo dos arcos)
			coberto = abs(sin(th)) > 0.62
		match tipo:
			"anel", "membrana", "arcos":
				dentro.append(topo + Vector3(0, 6.0, 0) - nr * (16.0 if coberto else 0.5))
				fora_l.append(topo + Vector3(0, 4.5, 0) + nr * 1.0)
			"disco":
				dentro.append(topo + Vector3(0, 11.0, 0) - nr * 20.0)
				fora_l.append(topo + Vector3(0, 13.0, 0) + nr * 6.0)
		if i % 4 == 0 and dentro.size() > 0 and (coberto or tipo != "arcos"):
			luzes.append(dentro[dentro.size() - 1] - Vector3(0, 0.6, 0))
	if tipo == "":
		return
	if tipo == "membrana":
		_faixa(dentro, fora_l, _mat_cor(Color(0.95, 0.96, 0.98, 0.82), true))
		# mastros por fora e os cabos que seguram a membrana
		for i in range(0, ths.size() - 1, 6):
			var nr2 := _fora_tigela(ths[i], a, b, n)
			var pe: Vector3 = L.fora[i] + nr2 * 3.0
			var alto := pe + Vector3(0, _tigela.topo + 16.0, 0)
			_viga(pe, alto, 0.6, aco)
			_viga(alto, dentro[i], 0.18, aco)
	elif tipo == "disco":
		_faixa(dentro, fora_l, branco)
		for i in range(0, ths.size() - 1, 4):
			var nr3 := _fora_tigela(ths[i], a, b, n)
			var pe2: Vector3 = L.fora[i] + nr3 * 4.0
			_viga(pe2, Vector3(pe2.x, _tigela.topo + 12.0, pe2.z), 0.45, aco)
	else:
		_faixa(dentro, fora_l, branco)
	if tipo == "arcos":
		# os dois grandes arcos do Stadium Australia, sobre os lados compridos
		for sz in [-1.0, 1.0]:
			var z: float = sz * (_tigela.b_fora - 8.0)
			var ant := Vector3(-_tigela.a * 0.95, 0, z)
			for k in range(1, 21):
				var u := float(k) / 20.0
				var x: float = lerp(-_tigela.a * 0.95, _tigela.a * 0.95, u)
				var y: float = (_tigela.topo + 24.0) * sin(u * PI)
				var p := Vector3(x, y, z)
				_viga(ant, p, 1.3, branco)
				ant = p
	if v.get("arco", false):
		# o grande arco de Wembley, inclinado sobre a arquibancada de trás
		var z0: float = -_tigela.b_fora * 0.55
		var ant2 := Vector3(-_tigela.a_fora - 6.0, 0, z0)
		for k in range(1, 25):
			var u2 := float(k) / 24.0
			var x2: float = lerp(-_tigela.a_fora - 6.0, _tigela.a_fora + 6.0, u2)
			var arco := sin(u2 * PI)
			var p2 := Vector3(x2, 72.0 * arco, z0 + 14.0 * arco)
			_viga(ant2, p2, 1.6, branco)
			ant2 = p2
	if _noite():
		for q in luzes:
			_brilho(q, 3.6, Color(1, 0.96, 0.85, 0.55))
			_brilho(q, 10.0, Color(1, 0.95, 0.8, 0.07))


func _mat_torcida_nova(sa: Dictionary, sf: Dictionary, assento: Color, mistura: float, luz: float, grade: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arquibancada.shader")
	m.set_shader_param("fans", load("res://imagens/torcedores.png"))
	m.set_shader_param("ruido", load("res://imagens/ruido.png"))
	m.set_shader_param("cor1", Color(sa.torcida[0]))
	m.set_shader_param("cor2", Color(sa.torcida[1]))
	m.set_shader_param("cor_fora", Color(sf.torcida[0]))
	m.set_shader_param("mistura", mistura)
	m.set_shader_param("assento", assento)
	m.set_shader_param("grade", grade)
	m.set_shader_param("luz", luz)
	m.set_shader_param("pulo", 0.55)
	_mat_torcida.append(m)
	return m


## Ponto na superfície de um anel (u ao longo 0..1, w da frente 0..1 para trás).
func _ponto_arquibancada(i: int, u: float, w: float) -> Array:
	var A: Array = _arquibancadas[i]
	var f: Vector3 = A[0]
	var ao_longo: Vector3 = A[1]
	var para_fora: Vector3 = A[2]
	var p: Vector3 = f + ao_longo * A[3] * u + para_fora * A[4] * w + Vector3(0, A[5] * w, 0)
	var subida = (para_fora * A[4] + Vector3(0, A[5], 0)).normalized()
	return [p, ao_longo, subida]


# ------------------------------------------------------------ refletores
func _torres(v: Dictionary) -> void:
	var bases := []
	if v.forma == "tigela":
		if v.teto != "":
			return         # as luzes ficam na beirada do teto
		for k in range(4):
			var th := PI / 4.0 + k * PI / 2.0
			bases.append(_p_tigela(th, _tigela.a_fora + 8.0, _tigela.b_fora + 8.0, _tigela.n))
	else:
		if v.cobertura:
			return         # cobertura tem a fileira de refletores na beirada
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				bases.append(Vector3(sx * (HX + 20), 0, sz * (HZ + 20)))
	var poste := _mat_cor(Color(0.6, 0.62, 0.66))
	var lampada := _mat_cor(Color(1.6, 1.55, 1.4) if _noite() else Color(0.85, 0.87, 0.9))
	for base in bases:
		var sx: float = sign(base.x)
		var sz: float = sign(base.z)
		_caixa(base + Vector3(0, 24, 0), Vector3(1.2, 48, 1.2), poste)
		var cabeca := _caixa(base + Vector3(0, 49, 0), Vector3(9, 6, 1), lampada)
		cabeca.look_at_from_position(cabeca.translation, Vector3(0, 0, 0), Vector3.UP)
		if _noite():
			# luz sutil: núcleo pequeno, halo curto e fraco, estria discreta
			_brilho(base + Vector3(0, 49, 0), 16.0, Color(1, 0.96, 0.85, 0.42))
			_brilho(base + Vector3(0, 49, 0), 6.0, Color(1.15, 1.13, 1.05, 0.9))
			_brilho(base + Vector3(0, 49, 0), 38.0, Color(1, 0.95, 0.8, 0.08))
			_estria(base + Vector3(0, 49, 0), 44.0, Color(1, 0.96, 0.86, 0.18))
			_facho(base + Vector3(0, 48, 0), Vector3(-sx * 22.0, 0, -sz * 12.0))


# ------------------------------------------------------------- fusão
## Junta as peças paradas que se desenham do mesmo jeito (cor sólida, ou a
## mesma textura) numa malha só, com a cor de cada peça nos vértices. Na TV
## box cada peça é uma chamada de desenho: o estádio tinha ~150 e a cidade
## engasgava; fundidas, sobram poucas dezenas.
func _fundir() -> void:
	var grupos := {}
	for f in get_children():
		if not (f is MeshInstance) or f.mesh == null or f.get_child_count() > 0 or f in _giro:
			continue
		var m = f.material_override
		if not (m is SpatialMaterial) or not _pode_fundir(m):
			continue
		var tex: Texture = m.albedo_texture
		var chave := "%s|%s|%d|%s" % [m.flags_unshaded, m.flags_transparent, m.params_blend_mode, str(tex.get_rid().get_id()) if tex != null else "-"]
		if not grupos.has(chave):
			grupos[chave] = [m, []]
		grupos[chave][1].append(f)
	for g in grupos.values():
		var pecas: Array = g[1]
		if pecas.size() < 2:
			continue
		var mat: SpatialMaterial = g[0].duplicate()
		mat.albedo_color = Color.white
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		var mi := MeshInstance.new()
		mi.mesh = _malha_unica(pecas)
		mi.material_override = mat
		add_child(mi)
		for f in pecas:
			# sai da cena agora e é apagada depois (apagar na hora força o
			# motor a esperar o desenho: travava a montagem)
			remove_child(f)
			f.queue_free()


func _pode_fundir(m: SpatialMaterial) -> bool:
	return m.params_billboard_mode == SpatialMaterial.BILLBOARD_DISABLED and not m.emission_enabled \
		and not m.normal_enabled and not m.flags_fixed_size and not m.flags_no_depth_test \
		and m.uv1_scale == Vector3.ONE and m.uv1_offset == Vector3.ZERO


## Uma malha com todas as peças (já na posição de cada uma). As contas vão
## em bloco (transformar, juntar listas): rápido até na TV box.
func _malha_unica(pecas: Array) -> ArrayMesh:
	var vs := PoolVector3Array()
	var ns := PoolVector3Array()
	var uvs := PoolVector2Array()
	var cs := PoolColorArray()
	var idx := PoolIntArray()
	for p in pecas:
		var cor: Color = p.material_override.albedo_color
		var xf: Transform = p.transform
		var giro := Transform(xf.basis, Vector3.ZERO)
		for s in range(p.mesh.get_surface_count()):
			var a: Array = p.mesh.surface_get_arrays(s)
			var av: PoolVector3Array = a[Mesh.ARRAY_VERTEX]
			var n := av.size()
			var base := vs.size()
			vs.append_array(xf.xform(av))
			if a[Mesh.ARRAY_NORMAL] != null:
				ns.append_array(giro.xform(a[Mesh.ARRAY_NORMAL]))
			else:
				ns.append_array(_repetir_v3(Vector3.UP, n))
			if a[Mesh.ARRAY_TEX_UV] != null:
				uvs.append_array(a[Mesh.ARRAY_TEX_UV])
			else:
				var zeros := PoolVector2Array()
				zeros.resize(n)
				uvs.append_array(zeros)
			cs.append_array(_repetir_cor(cor, n))
			var ai: PoolIntArray = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else _sequencia(n)
			if base > 0:
				for k in range(ai.size()):
					ai[k] += base
			idx.append_array(ai)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	# cor em float: lâmpadas acima de 1 continuam brilhando
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], Mesh.ARRAY_COMPRESS_DEFAULT & ~Mesh.ARRAY_COMPRESS_COLOR)
	return am


static func _repetir_cor(c: Color, n: int) -> PoolColorArray:
	var r := PoolColorArray()
	r.resize(n)
	for i in range(n):
		r[i] = c
	return r


static func _repetir_v3(v: Vector3, n: int) -> PoolVector3Array:
	var r := PoolVector3Array()
	r.resize(n)
	for i in range(n):
		r[i] = v
	return r


static func _sequencia(n: int) -> PoolIntArray:
	var r := PoolIntArray()
	r.resize(n)
	for i in range(n):
		r[i] = i
	return r


## Brilho (halo) sempre de frente para a câmera: entra na lista e sai
## desenhado junto com todos os outros (_multi_brilhos).
func _brilho(p: Vector3, tam: float, cor: Color) -> void:
	_brilhos.append([p, tam, tam, cor])


## Todos os brilhos de uma lista num MultiMesh (uma chamada de desenho).
func _multi_brilhos(lista: Array) -> MultiMeshInstance:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT
	mm.mesh = QuadMesh.new()
	mm.instance_count = lista.size()
	for i in range(lista.size()):
		var b: Array = lista[i]
		mm.set_instance_transform(i, Transform(Basis().scaled(Vector3(b[1], b[2], 1.0)), b[0]))
		mm.set_instance_custom_data(i, b[3])
	var mmi := MultiMeshInstance.new()
	mmi.multimesh = mm
	mmi.material_override = _mat_brilhos()
	mmi.extra_cull_margin = 80.0       # o quadrado vira para a câmera: sem sumir na borda
	return mmi


func _mat_brilhos() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BRILHOS
	m.set_shader_param("textura", BRILHO)
	return m


# ------------------------------------------------------------- bandeirões
func _bandeiroes() -> void:
	if _arquibancadas.empty():
		return
	# casa: arquibancada de trás (3) e a da esquerda (1); visitante: a da direita (2)
	var lista := [[0, 0.2, casa], [0, 0.5, casa], [0, 0.8, casa], [2, 0.5, casa], [3, 0.3, fora], [3, 0.7, fora]]
	var k := 0
	for b in lista:
		var r := _ponto_arquibancada(b[0], b[1], 0.42)
		var p: Vector3 = r[0]
		var ao_longo: Vector3 = r[1]
		var subida: Vector3 = r[2]
		var normal := ao_longo.cross(subida).normalized()
		if normal.y < 0.0:
			# a frente do pano sempre para cima/para o gramado (sem espelhar)
			normal = -normal
			ao_longo = -ao_longo
		var w := 15.0 if b[0] < 2 else 11.0
		var h := 8.0
		var mi := MeshInstance.new()
		mi.mesh = _malha_grade(w, h, 28, 14)
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/bandeirao3d.shader")
		var s := _visual(b[2], 0 if b[2] == casa else 1)
		m.set_shader_param("emblema", _bandeira if _bandeira != null else Jogo.emblema(b[2]))
		m.set_shader_param("cor1", Color(s.torcida[0]))
		m.set_shader_param("cor2", Color(s.torcida[1]))
		m.set_shader_param("fase", k * 1.7)
		m.set_shader_param("aspecto", w / h)
		m.set_shader_param("luz", {"sol": 1.05, "chuva": 0.8, "noite": 0.78, "noite_chuva": 0.68}[clima])
		mi.material_override = m
		# um pouco acima da torcida: a onda do pano nunca entra nela
		mi.transform = Transform(Basis(ao_longo, subida, normal), p + normal * 0.9)
		add_child(mi)
		_bandeiras.append(m)
		k += 1


func _malha_grade(w: float, h: float, nx: int, ny: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(ny):
		for i in range(nx):
			var u0 := float(i) / nx
			var u1 := float(i + 1) / nx
			var v0 := float(j) / ny
			var v1 := float(j + 1) / ny
			for q in [[u0, v0], [u1, v0], [u1, v1], [u0, v0], [u1, v1], [u0, v1]]:
				st.add_uv(Vector2(q[0], 1.0 - q[1]))
				st.add_vertex(Vector3((q[0] - 0.5) * w, (q[1] - 0.5) * h, 0))
	return st.commit()


# ---------------------------------------------------------------- clima
func _fazer_chuva() -> void:
	# chuva sobre o estádio inteiro (GPU, milhares de pingos), já caindo
	# desde o primeiro quadro, e outra bem perto da câmera (pingos nítidos)
	var gp := Particles.new()
	gp.amount = 9000
	gp.lifetime = 1.3
	gp.preprocess = 2.0
	gp.visibility_aabb = AABB(Vector3(-220, -100, -200), Vector3(440, 120, 400))
	var pm := ParticlesMaterial.new()
	pm.emission_shape = ParticlesMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(210, 1, 190)
	pm.direction = Vector3(0.12, -1, 0)
	pm.spread = 3.0
	pm.gravity = Vector3(0, -20, 0)
	pm.initial_velocity = 70.0
	gp.process_material = pm
	var qg := QuadMesh.new()
	qg.size = Vector2(0.14, 3.4)
	var mg := SpatialMaterial.new()
	mg.flags_unshaded = true
	mg.flags_transparent = true
	mg.albedo_color = Color(0.85, 0.9, 1.0, 0.28) if not _noite() else Color(0.8, 0.85, 1.0, 0.36)
	mg.params_billboard_mode = SpatialMaterial.BILLBOARD_FIXED_Y
	mg.params_billboard_keep_scale = true
	qg.material = mg
	gp.draw_pass_1 = qg
	gp.translation = Vector3(0, 95, 0)
	gp.set_meta("chuva", true)
	add_child(gp)
	_chuva = CPUParticles.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 2.2)
	var m := SpatialMaterial.new()
	m.flags_unshaded = true
	m.flags_transparent = true
	m.albedo_color = Color(0.88, 0.92, 1.0, 0.42)
	m.params_billboard_mode = SpatialMaterial.BILLBOARD_FIXED_Y
	qm.material = m
	_chuva.mesh = qm
	_chuva.amount = 900
	_chuva.lifetime = 0.8
	_chuva.preprocess = 1.0
	_chuva.local_coords = false
	_chuva.emission_shape = CPUParticles.EMISSION_SHAPE_BOX
	_chuva.emission_box_extents = Vector3(45, 2, 45)
	_chuva.direction = Vector3(0.12, -1, 0)
	_chuva.spread = 4.0
	_chuva.gravity = Vector3.ZERO
	_chuva.initial_velocity = 60.0
	_chuva.set_meta("chuva", true)
	add_child(_chuva)


func _fazer_flashes() -> void:
	var lista := []
	for _i in range(18):
		_flashes.append([Vector3.ZERO, 0.0])
		lista.append([Vector3.ZERO, 2.2, 2.2, Color(1, 1, 1, 0.0)])
	var mmi := _multi_brilhos(lista)
	mmi.extra_cull_margin = 400.0      # os flashes andam pela torcida toda
	_flash_mm = mmi.multimesh
	add_child(mmi)


func _fazer_fogos() -> void:
	var cores := [Color(Jogo.selecao(casa).torcida[0]), Color(Jogo.selecao(fora).torcida[0]), Color(1, 0.85, 0.3)]
	for i in range(3):
		var p := CPUParticles.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.9, 0.9)
		var m := SpatialMaterial.new()
		m.flags_unshaded = true
		m.flags_transparent = true
		m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
		m.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
		m.albedo_texture = load("res://imagens/brilho.png")
		m.vertex_color_use_as_albedo = true
		qm.material = m
		p.mesh = qm
		p.amount = 90
		p.lifetime = 1.6
		p.one_shot = true
		p.explosiveness = 1.0
		p.emitting = false
		p.spread = 180.0
		p.initial_velocity = 22.0
		p.initial_velocity_random = 0.4
		p.gravity = Vector3(0, -9, 0)
		p.damping = 6.0
		p.color = cores[i % cores.size()]
		var rampa := Gradient.new()
		rampa.set_color(0, Color(1, 1, 1, 1))
		rampa.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = rampa
		add_child(p)
		_fogos.append(p)


# ---------------------------------------------------------------- câmera
static func _suave(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func posicionar_camera(t: float) -> void:
	if camera == null:
		return
	if not _chaves.empty():
		_no_voo(t)
	elif not _quadros.empty():
		_no_podio(t)
	# o céu (sol, lua) acompanha a câmera: fica sempre lá no fundo
	_ceu_longe.translation = camera.translation


func _no_podio(t: float) -> void:
	var n := _quadros.size()
	var i := 0
	while i < n - 2 and t > _quadros[i + 1][0]:
		i += 1
	var a: Array = _quadros[i]
	var b: Array = _quadros[i + 1]
	var u := _suave(clamp((t - a[0]) / (b[0] - a[0]), 0.0, 1.0))
	if i == n - 2:
		u = clamp((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)      # último trecho: deriva constante
	var pa: Array = _quadros[max(i - 1, 0)]
	var pb: Array = _quadros[min(i + 2, n - 1)]
	var pos: Vector3 = a[1].cubic_interpolate(b[1], pa[1], pb[1], u)
	var alvo: Vector3 = a[2].cubic_interpolate(b[2], pa[2], pb[2], u)
	camera.look_at_from_position(pos, alvo, Vector3.UP)


## O voo começa de frente para o cartão-postal (o Cristo de braços abertos),
## gira devagar em volta dele e depois desce sobre a cidade até o estádio.
func _abrir_no_postal(p: Dictionary) -> void:
	var c: Vector3 = p.pos
	var h: float = p.altura
	var f: Vector3 = p.frente
	var lado := f.cross(Vector3.UP).normalized()
	var alvo := c + Vector3(0, h * 0.62, 0)
	# depois do Cristo, um sobrevoo do estádio (do lado dele) emenda no
	# mergulho por cima da arquibancada: nada de atravessar a cidade correndo
	var resto := _chaves.slice(2, _chaves.size() - 1)
	_chaves = [
		[0.0, c + f * (h * 1.7) + lado * (h * 0.7) + Vector3(0, h * 0.5, 0), alvo, 42.0],
		[0.0, c + f * (h * 1.25) - lado * (h * 0.45) + Vector3(0, h * 0.8, 0), alvo + Vector3(0, h * 0.05, 0), 40.0, 2.8],
		[0.0, Vector3(-40, 95, -190), Vector3(0, 5, 0), 50.0],
	] + resto
	_i_terco = 2
	postal_nome = p.get("nome", "")


## O tempo de cada trecho do voo sai da distância e do giro da câmera:
## velocidade quase constante (sem acelerar de repente nem "puxar" a
## imagem), mais devagar onde a câmera gira mais. A última chave (deriva da
## câmera da TV) fica com 9 s.
const V_POS := 62.0         # m/s da câmera perto do chão (mais alto, mais rápido)
const V_ALVO := 185.0      # m/s do ponto para onde ela olha
const V_GIRO := 54.0        # graus/s do olhar
func _cronometrar() -> void:
	var t := 0.0
	var n := _chaves.size()
	for i in range(n):
		if i > 0:
			var a: Array = _chaves[i - 1]
			var b: Array = _chaves[i]
			var dt: float
			if i == n - 1:
				dt = 9.0
			else:
				var da: Vector3 = (a[2] - a[1]).normalized()
				var db: Vector3 = (b[2] - b[1]).normalized()
				var giro := rad2deg(acos(clamp(da.dot(db), -1.0, 1.0)))
				var altura: float = (a[1].y + b[1].y) * 0.5
				var v := V_POS + 0.9 * max(0.0, altura - 40.0)
				var minimo: float = b[4] if b.size() > 4 else 1.0
				dt = max(max(a[1].distance_to(b[1]) / v, a[2].distance_to(b[2]) / V_ALVO), max(giro / V_GIRO, minimo))
			t += dt
		_chaves[i][0] = t
	t_tv = _chaves[n - 2][0]
	t_terco_ini = _chaves[_i_terco][0] + 0.5
	t_terco_fim = max(t_terco_ini + 3.0, _chaves[_i_terco + 2][0])


## Tangente da chave i (k = 1 posição, 2 alvo, 3 fov), em unidades por
## segundo: a câmera passa por cada chave sem parar nem dar tranco.
func _tangente(i: int, k: int):
	var n := _chaves.size()
	if i == 0:
		return _chaves[0][k] * 0.0          # parte parada e acelera suave
	if i == n - 1:
		return (_chaves[n - 1][k] - _chaves[n - 2][k]) / (_chaves[n - 1][0] - _chaves[n - 2][0])
	return (_chaves[i + 1][k] - _chaves[i - 1][k]) / (_chaves[i + 1][0] - _chaves[i - 1][0])


func _no_voo(t: float) -> void:
	var n := _chaves.size()
	t = clamp(t, 0.0, _chaves[n - 1][0])
	var i := 0
	while i < n - 2 and t > _chaves[i + 1][0]:
		i += 1
	var a: Array = _chaves[i]
	var b: Array = _chaves[i + 1]
	var dt: float = b[0] - a[0]
	var s: float = clamp((t - a[0]) / dt, 0.0, 1.0)
	var h00 := 2.0 * s * s * s - 3.0 * s * s + 1.0
	var h10 := s * s * s - 2.0 * s * s + s
	var h01 := -2.0 * s * s * s + 3.0 * s * s
	var h11 := s * s * s - s * s
	var r := []
	for k in [1, 2, 3]:
		r.append(a[k] * h00 + _tangente(i, k) * (h10 * dt) + b[k] * h01 + _tangente(i + 1, k) * (h11 * dt))
	camera.fov = r[2]
	camera.look_at_from_position(r[0], r[1], Vector3.UP)


## Tempos por onde a câmera passa no preparo escondido (palco3d.gd).
func amostras() -> Array:
	var r := []
	if not _chaves.empty():
		for i in range(_chaves.size()):
			r.append(_chaves[i][0])
			if i + 1 < _chaves.size():
				r.append((_chaves[i][0] + _chaves[i + 1][0]) / 2.0)
	else:
		for i in range(_quadros.size()):
			r.append(_quadros[i][0])
			if i + 1 < _quadros.size():
				r.append((_quadros[i][0] + _quadros[i + 1][0]) / 2.0)
	return r


## Os planos mais pesados (onde o preparo mede o ritmo).
func medir_em() -> Array:
	if not _chaves.empty():
		return [0.4, t_tv + 2.0]
	if _quadros.empty():
		return [0.0]
	return [_quadros[0][0], _quadros[_quadros.size() - 1][0]]


## Preparo escondido: solta todos os fogos e flashes uma vez (os shaders
## deles compilam agora, não no meio do show).
func aquecer() -> void:
	for p in _fogos:
		p.translation = Vector3(rand_range(-HX, HX), rand_range(48, 70), rand_range(-HZ - 40, -HZ - 10))
		p.restart()
		p.emitting = true
	_prox_fogo = 2.0


func _process(delta: float) -> void:
	_t += delta
	for g in _giro:
		g.rotation.y += delta * 0.6
	if _chuva != null and camera != null:
		_chuva.translation = camera.translation + Vector3(0, 18, 0) - camera.global_transform.basis.z * 20.0
	# flashes de máquina fotográfica na torcida (noite)
	if not _flashes.empty() and not _arquibancadas.empty():
		_prox_flash -= delta
		while _prox_flash <= 0.0:
			_prox_flash += rand_range(0.03, 0.12)
			var r := _ponto_arquibancada(randi() % _arquibancadas.size(), randf(), rand_range(0.1, 0.95))
			var k := randi() % _flashes.size()
			_flashes[k] = [r[0] + Vector3(0, 0.8, 0), 0.12]
			_flash_mm.set_instance_transform(k, Transform(Basis().scaled(Vector3(2.2, 2.2, 1.0)), _flashes[k][0]))
		for i in range(_flashes.size()):
			var f: Array = _flashes[i]
			if f[1] > 0.0:
				f[1] = max(0.0, f[1] - delta)
				_flash_mm.set_instance_custom_data(i, Color(1, 1, 1, f[1] / 0.12))
	if not _fogos.empty():
		_prox_fogo -= delta
		if _prox_fogo <= 0.0:
			_prox_fogo = rand_range(0.7, 1.6)
			var p: CPUParticles = _fogos[randi() % _fogos.size()]
			p.translation = Vector3(rand_range(-HX, HX), rand_range(48, 70), rand_range(-HZ - 40, -HZ - 10))
			p.restart()
			p.emitting = true


## Torcida e bandeirões mais animados (no VS).
func festa(k: float) -> void:
	for m in _mat_torcida:
		m.set_shader_param("pulo", 0.55 + 0.45 * k)
	for m in _bandeiras:
		m.set_shader_param("forca", 1.0 + 0.4 * k)


# ------------------------------------------------------------ céu: sol e lua
## Sol e lua vão no "céu longe": um nó que acompanha a câmera, então eles
## ficam sempre à mesma distância (como estrelas de verdade), pequenos e
## lá no fundo, sem crescer quando a câmera anda.
func _astros() -> void:
	_ceu_longe = Spatial.new()
	add_child(_ceu_longe)
	if not _noite():
		if _chove():
			return
		var p := SOL.normalized() * D_CEU
		_brilhos_ceu.append([p, 300.0, 300.0, Color(1.0, 0.9, 0.65, 0.42)])
		_brilhos_ceu.append([p, 96.0, 96.0, Color(1.0, 0.97, 0.85, 0.9)])
		_brilhos_ceu.append([p, 34.0, 34.0, Color(1.8, 1.75, 1.6, 1.0)])
		_brilhos_ceu.append([p, 480.0, 480.0 * 0.05, Color(1.0, 0.92, 0.75, 0.22)])
		return
	# lua cheia (na noite com chuva, apagada atrás das nuvens)
	var pl := LUA.normalized() * D_CEU
	var k := 0.3 if _chove() else 1.0
	_brilhos_ceu.append([pl, 210.0, 210.0, Color(0.55, 0.65, 0.9, 0.32 * k)])
	_brilhos_ceu.append([pl, 76.0, 76.0, Color(0.8, 0.86, 1.0, 0.4 * k)])
	var mi := MeshInstance.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(38, 38)
	mi.mesh = qm
	var m := SpatialMaterial.new()
	m.flags_unshaded = true
	m.flags_transparent = true
	m.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
	m.albedo_texture = load("res://imagens/lua.png")
	m.albedo_color = Color(1.25, 1.25, 1.3, k)
	mi.material_override = m
	mi.translation = pl
	_ceu_longe.add_child(mi)


## Estria de luz horizontal (como a lente de uma câmera de TV vê um
## refletor): um brilho achatado sempre de frente para a câmera.
func _estria(p: Vector3, larg: float, cor: Color) -> void:
	_brilhos.append([p, larg, larg * 0.07, cor])


## Poças de luz dos refletores no gramado (perfil TV box: no lugar das luzes
## de verdade, um brilho suave somado ao chão, sem custo de iluminação).
func _pocas_de_luz() -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var c := Vector3(-sx * 20.0, 0.07, -sz * 10.0)
			var mi := MeshInstance.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(HX * 1.5, HZ * 1.5)
			mi.mesh = qm
			var m := SpatialMaterial.new()
			m.flags_unshaded = true
			m.flags_transparent = true
			m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
			m.albedo_texture = BRILHO
			m.albedo_color = Color(1.0, 0.95, 0.82, 0.04 if not _chove() else 0.03)
			mi.material_override = m
			mi.rotation_degrees = Vector3(-90, 0, 0)
			mi.translation = c
			add_child(mi)


## Facho de luz do refletor até o gramado (cone aditivo bem leve).
func _facho(de: Vector3, ate: Vector3) -> void:
	var d := ate - de
	var mi := MeshInstance.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.0
	cm.bottom_radius = 26.0
	cm.height = d.length()
	cm.radial_segments = 24
	cm.rings = 4
	mi.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = FACHO
	m.set_shader_param("altura", d.length())
	m.set_shader_param("forca", 0.035 if not _chove() else 0.055)
	mi.material_override = m
	# o cilindro em pé (eixo Y) apontado de "de" para "ate"
	var y := -d.normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length() < 0.1:
		x = Vector3.RIGHT
	var z := x.cross(y).normalized()
	mi.transform = Transform(Basis(x, y, z), de + d * 0.5)
	add_child(mi)


# ------------------------------------------------------------------ pódio
## O pódio no centro do gramado: 2º (esquerda), 1º (meio, mais alto), 3º
## (direita), cada um com o tazo do time em pé; a taça em cima do campeão.
func _podio() -> void:
	var u := ["", "", ""]
	var lugares := [[0, 0.0, 5.0], [1, -9.5, 3.4], [2, 9.5, 2.2]]
	var corpo := _mat_cor(Color(0.08, 0.1, 0.2))
	var faixa := _mat_cor(Color(1.3, 1.05, 0.45))
	for L in lugares:
		var sg: String = podio[L[0]] if podio.size() > L[0] else ""
		var x: float = L[1]
		var alt: float = L[2]
		_caixa(Vector3(x, alt * 0.5, 0), Vector3(8.6, alt, 8.6), corpo)
		_caixa(Vector3(x, alt - 0.08, 4.35), Vector3(8.6, 0.16, 0.1), faixa)
		_caixa(Vector3(x, alt * 0.55, 4.31), Vector3(2.4, 2.4 if L[0] == 0 else 1.8, 0.05), _mat_cor(Color(0.95, 0.78, 0.3) if L[0] == 0 else (Color(0.8, 0.82, 0.86) if L[0] == 1 else Color(0.78, 0.5, 0.3))))
		if sg == "":
			continue
		var tex := Jogo.textura_botao(sg, 1)
		var base := Spatial.new()
		base.translation = Vector3(x, alt + 3.3, 0)
		add_child(base)
		var lado := MeshInstance.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 3.0
		cil.bottom_radius = 3.0
		cil.height = 0.9
		cil.radial_segments = 32
		lado.mesh = cil
		lado.material_override = _mat_cor(Jogo.cor_borda(sg, 1).darkened(0.2))
		lado.rotation_degrees = Vector3(90, 0, 0)
		base.add_child(lado)
		for frente in [1, -1]:
			var topo := MeshInstance.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(6.1, 6.1)
			topo.mesh = qm
			var m := SpatialMaterial.new()
			m.flags_unshaded = true
			m.flags_transparent = true
			m.albedo_texture = tex if tex != null else Jogo.emblema(sg)
			topo.material_override = m
			topo.translation = Vector3(0, 0, 0.47 * frente)
			if frente < 0:
				topo.rotation_degrees = Vector3(0, 180, 0)
			base.add_child(topo)
		if L[0] == 0:
			_giro.append(base)
	_taca(Vector3(0, 5.0 + 6.8, 0))
	# luz do pódio (refletor)
	_brilho(Vector3(0, 9, 3), 26.0, Color(1, 0.95, 0.8, 0.25))
	# confete caindo sobre o pódio
	var cores := [Color(Jogo.selecao(podio[0]).torcida[0]), Color(Jogo.selecao(podio[0]).torcida[1]), Color(1, 0.85, 0.25)]
	for c in cores:
		var p := CPUParticles.new()
		var qm2 := QuadMesh.new()
		qm2.size = Vector2(0.35, 0.22)
		var m2 := SpatialMaterial.new()
		m2.flags_unshaded = true
		m2.params_cull_mode = SpatialMaterial.CULL_DISABLED
		m2.vertex_color_use_as_albedo = true
		qm2.material = m2
		p.mesh = qm2
		p.amount = 160
		p.lifetime = 5.0
		p.preprocess = 3.0
		p.emission_shape = CPUParticles.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(26, 1, 18)
		p.translation = Vector3(0, 28, 0)
		p.direction = Vector3(0, -1, 0)
		p.spread = 20.0
		p.gravity = Vector3(0, -3.0, 0)
		p.initial_velocity = 3.0
		p.angular_velocity = 300.0
		p.angular_velocity_random = 1.0
		p.flag_rotate_y = true
		p.color = c
		add_child(p)


## A taça (peças simples douradas, com luz própria para o brilho do ouro).
func _taca(pos: Vector3) -> void:
	var t := Spatial.new()
	t.translation = pos
	add_child(t)
	var ouro := SpatialMaterial.new()
	ouro.albedo_color = Color(1.0, 0.78, 0.25)
	ouro.metallic = 1.0
	ouro.roughness = 0.25
	ouro.emission_enabled = true
	ouro.emission = Color(0.35, 0.22, 0.02)
	var verde := SpatialMaterial.new()
	verde.albedo_color = Color(0.08, 0.3, 0.15)
	verde.roughness = 0.4
	var pecas := [
		[CylinderMesh, {"top_radius": 1.1, "bottom_radius": 1.3, "height": 1.0}, Vector3(0, -3.3, 0), verde],
		[CylinderMesh, {"top_radius": 1.15, "bottom_radius": 1.15, "height": 0.18}, Vector3(0, -2.75, 0), ouro],
		[CylinderMesh, {"top_radius": 0.32, "bottom_radius": 0.62, "height": 1.8}, Vector3(0, -1.8, 0), ouro],
		[SphereMesh, {"radius": 0.62, "height": 1.24}, Vector3(0, -0.75, 0), ouro],
		[CylinderMesh, {"top_radius": 1.55, "bottom_radius": 0.55, "height": 2.4}, Vector3(0, 0.55, 0), ouro],
		[CylinderMesh, {"top_radius": 1.62, "bottom_radius": 1.62, "height": 0.16}, Vector3(0, 1.78, 0), ouro],
	]
	for pc in pecas:
		var mi := MeshInstance.new()
		var mesh = pc[0].new()
		for k in pc[1]:
			mesh.set(k, pc[1][k])
		if mesh is CylinderMesh:
			mesh.radial_segments = 32
		mi.mesh = mesh
		mi.material_override = pc[3]
		mi.translation = pc[2]
		t.add_child(mi)
	for lado in [-1, 1]:
		for k in range(3):
			var al := MeshInstance.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.14
			cap.mid_height = 0.8
			al.mesh = cap
			al.material_override = ouro
			var a := -0.9 + k * 0.9
			al.translation = Vector3(lado * (1.65 + 0.35 * cos(a)), 0.7 + 0.55 * sin(a), 0)
			al.rotation = Vector3(0, 0, a * lado)
			t.add_child(al)
	var luz := OmniLight.new()
	luz.omni_range = 16.0
	luz.light_energy = 2.2
	luz.light_color = Color(1, 0.95, 0.85)
	luz.translation = Vector3(3, 4, 6)
	t.add_child(luz)
	var dl := DirectionalLight.new()
	dl.light_energy = 1.0
	dl.rotation_degrees = Vector3(-40, 30, 0)
	add_child(dl)
	_brilho(pos + Vector3(0, 0.5, 0), 12.0, Color(1, 0.85, 0.4, 0.3))
	_giro.append(t)
