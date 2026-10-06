extends Control

## ABERTURA LAZER & SPORT GAMES (primeira tela do jogo), em 2D: a mesa do
## próprio jogo (o estádio da Lazer & Sport em perspectiva, como na partida,
## com a torcida), os tazos das seleções TABELANDO (a bola passa de um para
## o outro pelo campo), o último passe vai para o tazo da LAZER & SPORT, que
## chuta e faz o gol: rede balança, clarão, torcida comemora. Depois a marca
## aparece (anéis do alvo, logo com brilho, LAZER & SPORT GAMES / APRESENTA).
## Leve: nada de 3D na largada (só o que a partida já usa). Qualquer tecla,
## botão ou toque pula para a abertura do jogo.
##
## Linha do tempo (s):
##   0.0  cortina abre, a câmera de TV acompanha a bola
##   0.5  tabela entre as seleções (um passe a cada PASSE s)
##   ...  último passe para o tazo da Lazer & Sport, chute, GOL
##   T_LOGO  a tela escurece e a marca aparece
##   FIM  escurece e vai para a abertura do jogo

const UI = preload("res://scripts/ui.gd")
const Campo = preload("res://scripts/campo.gd")
const Perspectiva = preload("res://scripts/perspectiva.gd")
const Torcida = preload("res://scripts/torcida.gd")

const OURO := Color(1.0, 0.8, 0.14)
const CELESTE := Color(0.78, 0.92, 1.0)
const TEXTO := "LAZER & SPORT GAMES"
const R := Campo.RAIO_BOTAO
const RB := Campo.RAIO_BOLA

# a tabela: seleções do meio para a direita, e o tazo da Lazer & Sport na
# entrada da área, de frente para o gol da direita
const TABELA := [["BRA", Vector2(330, 300)], ["ARG", Vector2(470, 520)], ["ITA", Vector2(610, 290)],
	["FRA", Vector2(750, 510)], ["ALE", Vector2(880, 300)], ["LAZ", Vector2(985, 430)]]
const INICIO := 0.5
const PASSE := 0.5                 # tempo de cada passe
const T_CHUTE := INICIO + 5 * PASSE + 0.3
const VOO_CHUTE := 0.32
const T_GOL := T_CHUTE + VOO_CHUTE
const T_LOGO := T_GOL + 0.9
const FIM := T_LOGO + 4.0
const ALVO_GOL := Vector2(1158, 374)

var _t := 0.0
var _saindo := false
var _sons := {}
var _vp: Viewport
var _mesa: Node2D
var _bola: Sprite
var _sombra_bola: Sprite
var _tazos := []           # [Node2D, posição inicial]
var _rede: Sprite
var _torcida
var _zoom := 1.0
var _foco := Vector2(640, 395)
var _tremor := 0.0

var _escuro: ColorRect
var _clarao: ColorRect
var _alvo: Control
var _logo: TextureRect
var _mat_logo: ShaderMaterial
var _texto: Control
var _cortina: ColorRect
var _brilhos: CPUParticles2D
var _faixas := []
var _gol_txt: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_montar_mesa()
	_montar_tela()
	Jogo.ambiente(0.0)
	_atualizar(0.0)


# =============================================================== a mesa
func _montar_mesa() -> void:
	var r := Perspectiva.montar(self)
	_vp = r[0]
	_mesa = Node2D.new()
	_vp.add_child(_mesa)
	var fundo := TextureRect.new()
	fundo.texture = Jogo.estadio("LAZ", OS.window_size.y < 900)
	fundo.expand = true
	fundo.rect_size = Vector2(1280, 720)
	fundo.mouse_filter = MOUSE_FILTER_IGNORE
	_mesa.add_child(fundo)
	_torcida = Torcida.new()
	_torcida.rect_size = Vector2(1280, 720)
	_mesa.add_child(_torcida)
	var tc: Array = Jogo.selecao("LAZ").torcida
	_torcida.cores(tc, tc)
	# rede do gol da direita (balança no gol)
	_rede = Sprite.new()
	_rede.texture = load("res://imagens/rede_dir.png")
	_rede.centered = false
	_rede.scale = Vector2(0.5, 0.5)         # o mesmo gol da partida
	_rede.position = Vector2(Campo.CAMPO.end.x - 4, Campo.CENTRO.y - Campo.GOL_MEIA - 8)
	_mesa.add_child(_rede)
	# os tazos: sombra + tazo (textura pronta de cada seleção)
	var sombra_tex: Texture = load("res://imagens/sombra.png")
	for item in TABELA:
		var n := Node2D.new()
		n.position = item[1]
		var s := Sprite.new()
		s.texture = sombra_tex
		s.position = Vector2(3, 5)
		s.modulate = Color(1, 1, 1, 0.55)
		s.scale = Vector2.ONE * R * 2.0 * 1.55 / sombra_tex.get_width()
		n.add_child(s)
		var tex: Texture = Jogo.textura_botao(item[0], 1)
		var b := Sprite.new()
		b.texture = tex
		b.scale = Vector2.ONE * R * 2.0 / tex.get_width()
		n.add_child(b)
		_mesa.add_child(n)
		_tazos.append([n, item[1]])
	_sombra_bola = Sprite.new()
	_sombra_bola.texture = sombra_tex
	_sombra_bola.modulate = Color(1, 1, 1, 0.5)
	_sombra_bola.scale = Vector2.ONE * RB * 2.0 * 1.5 / sombra_tex.get_width()
	_mesa.add_child(_sombra_bola)
	_bola = Sprite.new()
	_bola.texture = load("res://imagens/bola.png")
	_bola.scale = Vector2.ONE * RB * 2.3 / _bola.texture.get_width()
	_mesa.add_child(_bola)


## Onde a bola encosta no tazo i, vindo da direção do ponto "de".
func _contato(i: int, de: Vector2) -> Vector2:
	var p: Vector2 = TABELA[i][1]
	return p + (de - p).normalized() * (R + RB + 1.0)


## Saída rápida e freada no fim (bola rolando na mesa).
static func _sai(u: float) -> float:
	return 1.0 - pow(1.0 - clamp(u, 0.0, 1.0), 2.4)


## Posição da bola no tempo s (passes e chute).
func _posicao_bola(s: float) -> Vector2:
	if s < INICIO:
		return _contato(0, TABELA[1][1])
	for i in range(5):
		var t0 := INICIO + i * PASSE
		if s < t0 + PASSE:
			var de := _contato(i, TABELA[i + 1][1])
			var prox: Vector2 = TABELA[i + 2][1] if i + 2 < TABELA.size() else ALVO_GOL
			var ate := _contato(i + 1, TABELA[i][1].linear_interpolate(prox, 0.5))
			return de.linear_interpolate(ate, _sai((s - t0) / (PASSE * 0.9)))
	var pronto := _contato(5, TABELA[4][1].linear_interpolate(ALVO_GOL, 0.5))
	if s < T_CHUTE:
		return pronto
	var u := (s - T_CHUTE) / VOO_CHUTE
	if u < 1.0:
		return pronto.linear_interpolate(ALVO_GOL, u)
	# na rede: afunda um pouco e para
	return ALVO_GOL + Vector2(18, 4) * _sai((s - T_GOL) / 0.4)


## Empurrãozinho do tazo que toca a bola (vai e volta), e o chute forte.
func _posicao_tazo(i: int, s: float) -> Vector2:
	var base: Vector2 = TABELA[i][1]
	var t0 := INICIO + i * PASSE if i < 5 else T_CHUTE
	var alvo: Vector2 = TABELA[i + 1][1] if i < 5 else ALVO_GOL
	var dir := (alvo - base).normalized()
	var u := s - t0 + 0.08
	if u < 0.0:
		return base
	var ida := 22.0 if i < 5 else 34.0
	if u < 0.08:
		return base + dir * ida * (u / 0.08)
	return base + dir * ida * (1.0 - _sai((u - 0.08) / 0.5) * 0.7)


# ============================================================ a tela por cima
func _montar_tela() -> void:
	var vinheta := ColorRect.new()
	vinheta.rect_size = Vector2(1280, 720)
	vinheta.mouse_filter = MOUSE_FILTER_IGNORE
	var mv := ShaderMaterial.new()
	mv.shader = load("res://shaders/vinheta.shader")
	vinheta.material = mv
	add_child(vinheta)
	_gol_txt = UI.label("GOOOL!", Jogo.fonte("titan", 120, 8), OURO)
	UI.colocar(_gol_txt, 0, 230, 1280, 160)
	_gol_txt.modulate.a = 0.0
	add_child(_gol_txt)
	_escuro = ColorRect.new()
	_escuro.rect_size = Vector2(1280, 720)
	_escuro.color = Color(0.02, 0.05, 0.14, 0)
	_escuro.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_escuro)
	_alvo = Control.new()
	_alvo.rect_size = Vector2(1280, 720)
	_alvo.mouse_filter = MOUSE_FILTER_IGNORE
	_alvo.connect("draw", self, "_desenhar_alvo")
	add_child(_alvo)
	_brilhos = CPUParticles2D.new()
	_brilhos.texture = load("res://imagens/brilho.png")
	var ad := CanvasItemMaterial.new()
	ad.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_brilhos.material = ad
	_brilhos.amount = 46
	_brilhos.lifetime = 2.6
	_brilhos.emitting = false
	_brilhos.position = Vector2(640, 300)
	_brilhos.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_brilhos.emission_rect_extents = Vector2(330, 210)
	_brilhos.direction = Vector2(0, -1)
	_brilhos.spread = 30
	_brilhos.gravity = Vector2.ZERO
	_brilhos.initial_velocity = 22
	_brilhos.initial_velocity_random = 0.6
	_brilhos.scale_amount = 0.07
	_brilhos.scale_amount_random = 0.7
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1, 1, 1, 0))
	rampa.add_point(0.3, Color(1, 1, 1, 0.9))
	rampa.set_color(rampa.get_point_count() - 1, Color(1, 1, 1, 0))
	_brilhos.color_ramp = rampa
	add_child(_brilhos)
	_logo = TextureRect.new()
	_logo.texture = load("res://imagens/logo_lazer_sport.png")
	_logo.expand = true
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = MOUSE_FILTER_IGNORE
	UI.colocar(_logo, 640 - 250, 92, 500, 332)
	_logo.rect_pivot_offset = Vector2(250, 166)
	_logo.modulate.a = 0.0
	_mat_logo = ShaderMaterial.new()
	_mat_logo.shader = load("res://shaders/logo_brilho.shader")
	_logo.material = _mat_logo
	add_child(_logo)
	_texto = Control.new()
	_texto.rect_size = Vector2(1280, 720)
	_texto.mouse_filter = MOUSE_FILTER_IGNORE
	_texto.connect("draw", self, "_desenhar_texto")
	add_child(_texto)
	_clarao = ColorRect.new()
	_clarao.rect_size = Vector2(1280, 720)
	_clarao.color = Color(1, 1, 1, 0)
	_clarao.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_clarao)
	for i in [0, 1]:
		var f := ColorRect.new()
		f.color = Color(0, 0, 0, 1)
		f.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(f)
		_faixas.append(f)
	_cortina = ColorRect.new()
	_cortina.rect_size = Vector2(1280, 720)
	_cortina.color = Color(0, 0, 0, 1)
	_cortina.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_cortina)
	Jogo.preaquecer(Jogo.fonte("bungee", 44, 0), TEXTO)
	Jogo.preaquecer(Jogo.fonte("titan", 120, 8), "GOOOL!")


static func _e(t: float, a: float, d: float) -> float:
	var u := clamp((t - a) / d, 0.0, 1.0)
	return 1.0 if u >= 1.0 else 1.0 - pow(2.0, -10.0 * u)


static func _sv(a: float, b: float, x: float) -> float:
	var u := clamp((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Anéis do alvo (como o logo) saindo do centro do alvo.
func _desenhar_alvo() -> void:
	var c := Vector2(640, 92 + 300.0 * 332.0 / 849.0)
	for i in range(4):
		var t0 := T_LOGO + 0.1 * i
		if _t < t0:
			continue
		var u := clamp((_t - t0) / 1.3, 0.0, 1.0)
		if u >= 1.0:
			continue
		var r := 30.0 + 760.0 * (1.0 - pow(1.0 - u, 3.0))
		var cor := OURO if i % 2 == 0 else Color(1, 1, 1)
		cor.a = pow(1.0 - u, 1.6) * 0.85
		_alvo.draw_arc(c, r, 0.0, TAU, 96, cor, 3.0 + 14.0 * (1.0 - u), true)


## "LAZER & SPORT GAMES" letra por letra, espaçado, e os filetes.
func _desenhar_texto() -> void:
	var f := Jogo.fonte("bungee", 44, 0)
	var esp := 7.0
	var larg := 0.0
	for ch in TEXTO:
		larg += f.get_string_size(ch).x + esp
	larg -= esp
	var x := 640.0 - larg / 2.0
	var y := 500.0
	var t0 := T_LOGO + 0.85
	for i in range(TEXTO.length()):
		var ch: String = TEXTO[i]
		var a := _e(_t, t0 + 0.035 * i, 0.45)
		var cor := Color(1, 1, 1)
		if ch == "&" or i >= TEXTO.find("GAMES"):
			cor = OURO
		cor.a = a
		if a > 0.0:
			_texto.draw_string(f, Vector2(x, y + 18.0 * (1.0 - a)), ch, cor)
		x += f.get_string_size(ch).x + esp
	var l := _e(_t, t0 + 0.5, 0.9)
	if l > 0.0:
		var meio := larg / 2.0 + 24.0
		var comp := 150.0 * l
		_texto.draw_line(Vector2(640 - meio - comp, y - 16), Vector2(640 - meio, y - 16), Color(OURO.r, OURO.g, OURO.b, l), 3.0, true)
		_texto.draw_line(Vector2(640 + meio, y - 16), Vector2(640 + meio + comp, y - 16), Color(CELESTE.r, CELESTE.g, CELESTE.b, l), 3.0, true)
	var sub := _e(_t, t0 + 1.0, 0.7)
	if sub > 0.0:
		var f2 := Jogo.fonte("texto", 20, 0)
		var txt := "APRESENTA"
		var w := 0.0
		for ch in txt:
			w += f2.get_string_size(ch).x + 9.0
		var x2 := 640.0 - (w - 9.0) / 2.0
		for ch in txt:
			_texto.draw_string(f2, Vector2(x2, y + 46), ch, Color(1, 1, 1, 0.7 * sub))
			x2 += f2.get_string_size(ch).x + 9.0


# ============================================================ linha do tempo
func _process(delta: float) -> void:
	var d := min(delta, 0.05)
	_t += d
	_atualizar(d)
	_sons_na_hora()
	if _t >= FIM:
		_sair()


func _atualizar(d: float) -> void:
	var s := _t
	# bola e tazos
	var b := _posicao_bola(s)
	var b_ant: Vector2 = _bola.position
	_bola.position = b
	_sombra_bola.position = b + Vector2(2, 3)
	_bola.rotation += (b - b_ant).length() / RB * sign(b.x - b_ant.x + 0.001)
	for i in range(_tazos.size()):
		_tazos[i][0].position = _posicao_tazo(i, s)
	# rede: estufa e balança no gol
	var u := s - T_GOL
	var bal := 0.0
	if u > 0.0:
		bal = max(exp(-u * 3.0) * cos(u * 12.0), -0.2)
	_rede.scale.x = 0.5 * (1.0 + 0.35 * bal)   # as traves ficam no lugar
	# câmera de TV: aproxima e acompanha a bola; no chute vai para o gol
	var alvo_zoom := 1.28
	var alvo_foco := b.linear_interpolate(Vector2(640, 395), 0.35)
	if s > T_CHUTE - 0.2:
		alvo_foco = Vector2(1010, 395)
		alvo_zoom = 1.45
	if s > T_LOGO - 0.3:
		alvo_zoom = 1.2
	var k: float = 1.0 if d <= 0.0 else min(1.0, 4.0 * d)
	_zoom = lerp(_zoom, alvo_zoom, k)
	_foco = _foco.linear_interpolate(alvo_foco, k)
	var tam := Vector2(1280, 720)
	var meia := tam / (2.0 * _zoom)
	var f := Vector2(clamp(_foco.x, meia.x, tam.x - meia.x), clamp(_foco.y, meia.y, tam.y - meia.y))
	_tremor = max(0.0, _tremor - d * 30.0)
	var treme := Vector2(rand_range(-1, 1), rand_range(-1, 1)) * _tremor
	# (o quadro da mesa já amplia para a resolução da tela)
	_mesa.position = tam / 2.0 - f * _zoom + treme
	_mesa.scale = Vector2.ONE * _zoom
	# GOOOL!
	var g := s - T_GOL
	if g > 0.0 and g < 1.2:
		_gol_txt.modulate.a = clamp(g / 0.1, 0.0, 1.0) * (1.0 - _sv(0.8, 1.2, g))
		_gol_txt.rect_pivot_offset = Vector2(640, 80)
		_gol_txt.rect_scale = Vector2.ONE * lerp(1.6, 1.0, _e(g, 0.0, 0.25))
	else:
		_gol_txt.modulate.a = 0.0
	# faixas de cinema durante o lance; somem quando entra a marca
	var h := 70.0 * (1.0 - _e(s, T_LOGO, 0.9))
	_faixas[0].rect_position = Vector2.ZERO
	_faixas[0].rect_size = Vector2(1280, h)
	_faixas[1].rect_position = Vector2(0, 720 - h)
	_faixas[1].rect_size = Vector2(1280, h)
	_cortina.color.a = max(1.0 - clamp(s / 0.35, 0.0, 1.0), _sv(FIM - 0.6, FIM, s))
	var cl := 0.0
	if s >= T_GOL and s < T_GOL + 0.4:
		cl = 0.55 * (1.0 - (s - T_GOL) / 0.4)
	if s >= T_LOGO:
		cl = max(cl, 0.85 * (1.0 - clamp((s - T_LOGO) / 0.55, 0.0, 1.0)))
	_clarao.color.a = cl
	_escuro.color.a = 0.66 * _e(s, T_LOGO + 0.1, 1.0)
	var lg := _e(s, T_LOGO + 0.2, 0.9)
	_logo.modulate.a = lg
	_logo.rect_scale = Vector2.ONE * lerp(0.86, 1.0, lg)
	_mat_logo.set_shader_param("varre", lerp(-0.6, 2.0, clamp((s - T_LOGO - 0.9) / 0.9, 0.0, 1.0)))
	if s >= T_LOGO + 0.3 and not _brilhos.emitting:
		_brilhos.emitting = true
	if s > T_LOGO - 0.1 and s < T_LOGO + 1.6:
		_alvo.update()
	if s > T_LOGO + 0.7 and s < T_LOGO + 3.0:
		_texto.update()


func _sons_na_hora() -> void:
	var lista := []
	for i in range(5):
		lista.append([INICIO + i * PASSE - 0.02, "peteleco", -6.0])
		lista.append([INICIO + i * PASSE, "bola", -4.0])
	lista += [[T_CHUTE - 0.02, "peteleco", 0.0], [T_CHUTE, "bola", 2.0], [T_CHUTE + 0.01, "impacto", -6.0],
		[T_GOL, "rede", 2.0], [T_LOGO, "brilho", -2.0], [T_LOGO + 0.9, "swoosh", -8.0]]
	for ev in lista:
		if _t >= ev[0] and not _sons.has(ev[0]):
			_sons[ev[0]] = true
			Jogo.tocar(ev[1], ev[2])
	if _t >= T_GOL and not _sons.has("gol"):
		_sons["gol"] = true
		_tremor = 9.0
		Jogo.tocar_grupo("gol", "torcida_gol", 0.0)
		_torcida.pular(0, 1.0, 3.0)
		_torcida.pular(1, 1.0, 3.0)
	if _t >= T_GOL + 1.7 and not _sons.has("festa"):
		_sons["festa"] = true
		Jogo.tocar_grupo("comemoracao", "", -3.0)


func _unhandled_input(ev: InputEvent) -> void:
	if _t < 0.3 or _saindo:
		return
	var tocou = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed) \
		or (ev is InputEventJoypadButton and ev.pressed) or (ev is InputEventKey and ev.pressed and not ev.echo)
	if tocou or ev.is_action_pressed("ui_accept") or ev.is_action_pressed("p1_chute") or ev.is_action_pressed("p2_chute"):
		get_tree().set_input_as_handled()
		_sair()


func _sair() -> void:
	if _saindo:
		return
	_saindo = true
	set_process(false)
	Jogo.parar_grupos(0.6)
	Jogo.ir_para("res://cenas/abertura.tscn")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_sair()
