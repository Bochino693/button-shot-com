extends Control

## PÓDIO DA COPA (cena 3D, depois da final). O estádio do campeão em 3D no
## modo pódio (estadio3d.gd): os tazos do 1º, 2º e 3º em pé nos degraus, a
## taça girando, confete e fogos. Por cima, a transmissão revela:
##   1.4  3º LUGAR      3.4  VICE-CAMPEÃO      6.0  CAMPEÃO (com clarão,
##   confete, fogos e o som do título), depois "APERTE O BOTÃO".
## Sozinho, volta para a chave em FIM_AUTO s; o BOTÃO (ou toque) adianta.

const UI = preload("res://scripts/ui.gd")
const Estadio3D = preload("res://scripts/estadio3d.gd")
const Palco3D = preload("res://scripts/palco3d.gd")
const HudTV = preload("res://scripts/hud_tv.gd")

const CONFETE = preload("res://imagens/confete.png")
const FIM_AUTO := 18.0
const T_TERCEIRO := 1.4
const T_VICE := 3.4
const T_CAMPEAO := 6.0

var _t := 0.0
var _palco
var _saindo := false
var _sons := {}
var _podio := []
var _estadio
var _hud                   # HUD de transmissão (hud_tv.gd)
var _topo := []
var _cartoes := []          # [painel, t_entrada, lado]
var _campeao: Control
var _titulo: Label
var _nome: Label
var _dono: Label
var _escudo: TextureRect
var _clarao: ColorRect
var _chamada: Label
var _raiz: Control
var _montado := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var c: Dictionary = Jogo.copa
	var campeao: String = c.get("campeao", "")
	_podio = c.get("podio", [campeao, "", ""])
	if campeao == "" or _podio.empty():
		Jogo.ir_para("res://cenas/chave.tscn")
		set_process(false)
		return
	# a capa aparece já no primeiro quadro; o estádio vem atrás dela
	_palco = Palco3D.new()
	_palco.criar(self)
	var sc := Jogo.selecao(campeao)
	_palco.capa(self, "A FESTA DO CAMPEÃO", "COPA CRAQUE DE BOTÃO   •   " + sc.nome, [Jogo.emblema(campeao)], [Color(sc.torcida[0]), Color(sc.torcida[1])])
	_palco.montagem(0.0)
	Jogo.ambiente(0.35)
	Jogo.parar_musica(0.6)
	set_process(false)
	_montar(campeao)


## Monta o estádio (uma etapa por quadro) e os cartões, e só então começa o
## preparo escondido do palco.
func _montar(campeao: String) -> void:
	yield(get_tree(), "idle_frame")
	_estadio = Estadio3D.new()
	_palco.vp.add_child(_estadio)
	var outro: String = _podio[1] if _podio.size() > 1 and _podio[1] != "" else campeao
	yield(_estadio.montar_em_partes(campeao, outro, "noite", {"podio": _podio}, funcref(_palco, "montagem")), "completed")
	if not is_inside_tree():
		return

	_raiz = Control.new()
	_raiz.mouse_filter = MOUSE_FILTER_IGNORE
	_raiz.rect_size = Vector2(1280, 720)
	add_child(_raiz)

	# cartões do 3º (direita) e do 2º (esquerda), embaixo
	_cartao(2, 1280 - 40 - 380, T_TERCEIRO, 1.0)
	_cartao(1, 40, T_VICE, -1.0)

	# o campeão no meio
	_campeao = Control.new()
	_campeao.mouse_filter = MOUSE_FILTER_IGNORE
	_campeao.rect_size = Vector2(1280, 720)
	_raiz.add_child(_campeao)
	_escudo = TextureRect.new()
	_escudo.texture = Jogo.emblema(campeao)
	_escudo.expand = true
	_escudo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_escudo.mouse_filter = MOUSE_FILTER_IGNORE
	UI.colocar(_escudo, 640 - 48, 84, 96, 96)
	_campeao.add_child(_escudo)
	_titulo = UI.label("CAMPEÃO!", Jogo.fonte("titan", 70, 5, Color(0.25, 0.12, 0, 0.9)), Jogo.OURO)
	UI.colocar(_titulo, 0, 176, 1280, 84)
	_titulo.rect_pivot_offset = Vector2(640, 42)
	_campeao.add_child(_titulo)
	var s := Jogo.selecao(campeao)
	_nome = UI.label(s.nome, Jogo.fonte("titan", 34, 3), Color.white)
	UI.colocar(_nome, 0, 252, 1280, 46)
	_campeao.add_child(_nome)
	var jn := Jogo.jogador_de(campeao)
	var titulos := int(Jogo.titulos.get(campeao, 0))
	var txt := ("JOGADOR %d" % jn) if jn > 0 else "CPU"
	if titulos > 0:
		txt += "  •  %d %s" % [titulos, "TÍTULO" if titulos == 1 else "TÍTULOS"]
	_dono = UI.label(txt, Jogo.fonte("bungee", 19, 2), Jogo.AMARELO)
	UI.colocar(_dono, 0, 294, 1280, 30)
	_campeao.add_child(_dono)

	_clarao = ColorRect.new()
	_clarao.color = Color(1, 0.95, 0.8, 0)
	_clarao.rect_size = Vector2(1280, 720)
	_clarao.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_clarao)

	# HUD de transmissão sem faixas pretas: sombra suave e pílulas de vidro
	_hud = HudTV.new()
	add_child(_hud)
	var marca := UI.label("COPA CRAQUE DE BOTÃO", Jogo.fonte("bungee", 18, 0), Jogo.OURO, Label.ALIGN_LEFT)
	UI.colocar(marca, 60, 24, 600, 40)
	add_child(marca)
	_hud.pilula(marca, Jogo.cor_time(campeao))
	var lf := UI.label("PÓDIO  •  OS TRÊS PRIMEIROS", Jogo.fonte("bungee", 18, 0), Color.white, Label.ALIGN_RIGHT)
	UI.colocar(lf, 1280 - 60 - 700, 24, 700, 40)
	add_child(lf)
	_hud.pilula(lf)
	_topo = [marca, lf]
	_chamada = UI.label("APERTE O BOTÃO PARA CONTINUAR", Jogo.fonte("bungee", 20, 0), Jogo.AMARELO)
	UI.colocar(_chamada, 0, 652, 1280, 48)
	add_child(_chamada)
	_hud.pilula(_chamada)

	for t in [Jogo.fonte("titan", 34, 3), Jogo.fonte("titan", 30, 2)]:
		for sg in _podio:
			if sg != "":
				Jogo.preaquecer(t, Jogo.selecao(sg).nome)
	_palco.capa_por_cima()
	_palco.preparar(_estadio, funcref(_estadio, "posicionar_camera"), _estadio.amostras(), _estadio.medir_em())
	_montado = true
	_atualizar()
	set_process(true)


## Cartão de colocação (2º ou 3º): escudo, posição e nome.
func _cartao(lugar: int, x: float, t0: float, lado: float) -> void:
	var sg: String = _podio[lugar] if _podio.size() > lugar else ""
	if sg == "":
		return
	var cor_lugar := Color(0.8, 0.82, 0.88) if lugar == 1 else Color(0.85, 0.55, 0.32)
	var p := UI.painel(cor_lugar, Color(0.02, 0.03, 0.08, 0.86), 14, 3, 12)
	UI.colocar(p, x, 520, 380, 104)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	_raiz.add_child(p)
	var e := TextureRect.new()
	e.texture = Jogo.emblema(sg)
	e.expand = true
	e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	e.mouse_filter = MOUSE_FILTER_IGNORE
	UI.colocar(e, 14, 12, 80, 80)
	p.add_child(e)
	var pos := UI.label("VICE-CAMPEÃO" if lugar == 1 else "3º LUGAR", Jogo.fonte("bungee", 20, 1), cor_lugar, Label.ALIGN_LEFT)
	UI.colocar(pos, 108, 14, 260, 30)
	p.add_child(pos)
	var n := UI.label(Jogo.selecao(sg).nome, Jogo.fonte("titan", 30, 2), Color.white, Label.ALIGN_LEFT)
	UI.colocar(n, 108, 44, 264, 46)
	p.add_child(n)
	_cartoes.append([p, t0, lado, x])


func _process(delta: float) -> void:
	if not _montado or not _palco.esta_pronto:
		return
	# tempo real (sem câmera lenta); só um engasgo grande é aparado
	_t += min(delta, 0.1)
	_sons_na_hora()
	_atualizar()
	if _t >= FIM_AUTO:
		_sair()


func _sons_na_hora() -> void:
	for ev in [[0.05, "swoosh", -8.0], [T_TERCEIRO, "swoosh", -6.0], [T_TERCEIRO + 0.25, "brilho", -8.0],
			[T_VICE, "swoosh", -6.0], [T_VICE + 0.25, "brilho", -8.0], [T_CAMPEAO - 0.6, "rufar", -4.0],
			[T_CAMPEAO, "fogos", -2.0], [T_CAMPEAO + 1.2, "fogos", -5.0]]:
		if _t >= ev[0] and not _sons.has(ev[0]):
			_sons[ev[0]] = true
			Jogo.tocar(ev[1], ev[2])
	if _t >= T_CAMPEAO and not _sons.has("campeao"):
		_sons["campeao"] = true
		Jogo.musica("campeao", 0.0, false)
		Jogo.tocar_grupo("comemoracao", "torcida_gol", -6.0)
		_estadio.festa(1.0)
		_confete()


func _confete() -> void:
	var cores := [Color(Jogo.selecao(_podio[0]).torcida[0]), Color(Jogo.selecao(_podio[0]).torcida[1]), Jogo.OURO]
	for c in cores:
		var cf := CPUParticles2D.new()
		cf.texture = CONFETE
		cf.amount = 60
		cf.lifetime = 4.0
		cf.one_shot = true
		cf.explosiveness = 0.5
		cf.position = Vector2(640, -20)
		cf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		cf.emission_rect_extents = Vector2(660, 10)
		cf.direction = Vector2(0, 1)
		cf.spread = 25
		cf.gravity = Vector2(0, 140)
		cf.initial_velocity = 150
		cf.initial_velocity_random = 0.6
		cf.angular_velocity = 300
		cf.angular_velocity_random = 1.0
		cf.color = c
		_raiz.add_child(cf)


static func _e(t: float, a: float, d: float) -> float:
	var u := clamp((t - a) / d, 0.0, 1.0)
	return 1.0 if u >= 1.0 else 1.0 - pow(2.0, -10.0 * u)


static func _lin(t: float, a: float, d: float) -> float:
	return clamp((t - a) / d, 0.0, 1.0)


func _atualizar() -> void:
	var t := _t
	_estadio.posicionar_camera(t)
	_hud.sombra = _e(t, 0.0, 0.7)
	for l in _topo:
		l.modulate.a = _e(t, 0.5, 0.6)
	# cartões entram de lado, suaves
	for c in _cartoes:
		var u := _e(t, c[1], 0.8)
		var p: Panel = c[0]
		p.rect_position.x = c[3] + c[2] * 460.0 * (1.0 - u)
		p.modulate.a = u
	# campeão: escudo e nome aparecem sem pulsar; o título cresce de leve
	var v := _e(t, T_CAMPEAO, 0.7)
	_escudo.modulate.a = v
	_escudo.rect_position.y = 84 - 30.0 * (1.0 - v)
	_titulo.modulate.a = v
	_titulo.rect_scale = Vector2.ONE * lerp(1.15, 1.0, v)
	_nome.modulate.a = _e(t, T_CAMPEAO + 0.4, 0.6)
	_dono.modulate.a = _e(t, T_CAMPEAO + 0.8, 0.6)
	_clarao.color.a = 0.35 * (1.0 - _lin(t, T_CAMPEAO, 0.5)) if t >= T_CAMPEAO else 0.0
	_chamada.modulate.a = _e(t, 9.0, 0.6) * (0.7 + 0.3 * cos((t - 9.0) * 2.0)) if t >= 9.0 else 0.0


func _unhandled_input(ev: InputEvent) -> void:
	if not _montado or _t < 2.0 or _saindo:
		return
	var tocou = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
	if tocou or ev.is_action_pressed("ui_accept") or ev.is_action_pressed("p1_chute") or ev.is_action_pressed("p2_chute"):
		get_tree().set_input_as_handled()
		if _t < T_CAMPEAO - 0.6:
			# primeiro aperto: vai direto ao campeão (sem soltar os sons pulados)
			for k in [0.05, T_TERCEIRO, T_TERCEIRO + 0.25, T_VICE, T_VICE + 0.25]:
				_sons[k] = true
			_t = T_CAMPEAO - 0.6
		else:
			_sair()


func _sair() -> void:
	if _saindo:
		return
	_saindo = true
	set_process(false)
	Jogo.parar_grupos(0.8)
	Jogo.ir_para("res://cenas/chave.tscn")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST and _montado:
		_sair()
