extends Control

## A PARTIDA DE FUTEBOL DE BOTÃO.
##
## Jogar: toque no seu botão. O ponto do toque é de onde o dedo "empurra":
## quanto mais na BEIRADA, mais forte. Solte para dar o peteleco.
##
## Regras (futebol de botão, regra de toques):
## • Cada vez, um botão joga. Tocou na bola: joga de novo, até N toques
##   (configuração, padrão 3). Não tocou na bola: a vez passa.
## • Acertou um botão rival SEM encostar na bola: FALTA. Batida forte dá
##   cartão amarelo; muito forte (ou 2º amarelo) dá vermelho e o botão sai.
##   Falta dentro da própria área = PÊNALTI.
## • Bola pela lateral = LATERAL; pela linha de fundo = ESCANTEIO (se o
##   defensor tocou por último) ou TIRO DE META.
## • Goleiro "caixinha": se posiciona sozinho entre a bola e o gol.
## • Dois tempos; na Copa, empate vai para os pênaltis.

const UI = preload("res://scripts/ui.gd")
const Campo = preload("res://scripts/campo.gd")
const Corpo = preload("res://scripts/corpo.gd")
const Fisica = preload("res://scripts/fisica.gd")
const IA = preload("res://scripts/ia.gd")
const Peca = preload("res://scripts/peca.gd")
const Mira = preload("res://scripts/mira.gd")
const Torcida = preload("res://scripts/torcida.gd")
const Bolinhas = preload("res://scripts/bolinhas.gd")
const Clima = preload("res://scripts/clima.gd")
const Perspectiva = preload("res://scripts/perspectiva.gd")
const Qualidade3D = preload("res://scripts/qualidade3d.gd")
const CartaoTazo = preload("res://scripts/cartao_tazo.gd")

enum { PREPARO, VEZ, MOVENDO, EVENTO, FIM }

const VMAX := 1150.0
const VMIN := 90.0
const LATERAL_DENTRO := 40.0       # a bola do lateral fica isso dentro do campo
const TOQUE_ALCANCE := 1.9        # raio do botão x isso = área para pegar o botão
const TOQUE_CANCELA := 2.9        # soltou longe assim = desiste do peteleco
const AMARELO_V := 430.0         # batida forte = amarelo
const VERMELHO_V := 930.0        # muito forte = vermelho direto

var siglas := ["BRA", "ARG"]
var uniformes := [1, 2]
var humano := [true, false]
var controle := [3, 0]              # placa de cada time: 1, 2, 3 = qualquer uma; 0 = CPU
var goleiro_manual := [false, false]  # o dono mexeu no goleiro nesta vez
var forca_time := [85, 85]
var params := [{}, {}]              # atributos do time em jogo (Jogo.parametros)
var embalo := [0.0, 0.0]            # segundos de "EMBALADO" depois de marcar

# manche: botão escolhido, ângulo da mira, barra de força
var sel := [null, null]
var ang := [0.0, 0.0]
var carregando := [false, false]
var t_carga := [0.0, 0.0]
var t_girar := [0.0, 0.0]
var _thread: Thread
var bandeiroes := []
var _fase_bandeira := 0.0
var _forca_bandeira := [1.0, 1.0]
var lbl_agregado: Label
var lbl_embalo := []

var fisica
var bola
var botoes := [[], []]
var goleiros := [null, null]
var pecas := {}

var estado := PREPARO
var vez := 0
var toques := 0
var placar := [0, 0]
var metade := 1
var tempo := 180.0
var relogio_vez := 20.0
var faltas := [0, 0]
var cartoes := [[0, 0], [0, 0]]      # [amarelos, vermelhos] por time
var jogada := {}
var cobranca := ""
var penalti_cobrador = null
var cobrador = null            # quem bate a falta/lateral/escanteio/tiro de meta
var ultimo_toque := -1
var ultimo_botao_bola = null
var disputa := {}
var _t := 0.0
var _t_jogada := 0.0
var _parar_em := -1.0
var _mirando = null
var _cpu := {}
var _som_cooldown := {}
var _primeiro_toque_humano := true
var _pausado := false
var _encerrou := false

# nós
var mesa: Node2D
var torcida
var mira
var clima                          # chuva / sol / noite (clima.gd)
var clima_tipo := "sol"
var perspectiva := false           # mesa vista como na TV (perspectiva.gd)
var _vp_mesa: Viewport             # quadro da mesa (com perspectiva)
var _medidas := []                 # tempos de quadro (qualidade automática)
const ARQ_QUALIDADE := "user://qualidade2d.cfg"
var rastro: Line2D
var poeira: CPUParticles2D
var confete := []
var hud: CanvasLayer
var lbl_gols := []
var lbl_tempo: Label
var lbl_vez := []
var lbl_toques := []
var barra_vez := []
var caixa_time := []
var icones_cartao := []
var banner: Control
var banner_fundo: ColorRect
var banner_txt: Label
var banner_sub: Label
var dica: Label
var flash: ColorRect
var redes := []
var _rede_bal := [-1.0, -1.0]   # segundos desde o gol em cada rede (-1: parada)
var _rede_base := []
var painel_disputa: Control
var lbl_disputa := []


func _ready() -> void:
	# o toque na mesa chega em _unhandled_input: a raiz não pode "segurar"
	mouse_filter = MOUSE_FILTER_IGNORE
	var p: Dictionary = Jogo.partida
	Campo.trocar_lados(false)
	clima_tipo = p.get("clima", "")
	if not clima_tipo in Clima.TIPOS:
		clima_tipo = ["", "sol", "chuva", "noite", "noite_chuva"][clamp(int(Jogo.config.get("clima", 0)), 0, 4)]
	if clima_tipo == "":
		clima_tipo = Clima.sortear()
	siglas = [p.casa, p.fora]
	controle = p.get("controle", [3 if p.humano[0] else 0, 3 if p.humano[1] else 0])
	# dois humanos: cada um na sua placa (1 = casa, 2 = fora)
	if controle[0] > 0 and controle[1] > 0:
		controle = [1, 2]
	humano = [controle[0] > 0, controle[1] > 0]
	uniformes = Jogo.escolher_uniformes(p.casa, p.fora)
	forca_time = [Jogo.selecao(p.casa).controle, Jogo.selecao(p.fora).controle]
	params = [Jogo.parametros(siglas[0]), Jogo.parametros(siglas[1])]
	tempo = float(Jogo.config.minutos) * 60.0
	_montar_mesa()
	_montar_hud()
	_preaquecer()
	_vitrine()
	Jogo.parar_musica()
	Jogo.ambiente(0.55)
	Jogo.som_clima("chuva" if Clima.chove(clima_tipo) else "")
	_intro()


# ================================================================ MONTAGEM
func _montar_mesa() -> void:
	mesa = Node2D.new()
	if int(Jogo.config.get("perspectiva", 1)) == 1:
		# a mesa é desenhada reta num Viewport e mostrada em perspectiva
		var r := Perspectiva.montar(self)
		r[0].add_child(mesa)
		_vp_mesa = r[0]
		perspectiva = true
		if _mesa_leve_salva():
			_mesa_leve()
	else:
		add_child(mesa)
	# o estádio da partida (o do mandante, ou o escolhido no amistoso)
	var local := Jogo.local_da_partida()
	var fundo := TextureRect.new()
	fundo.texture = Jogo.estadio(local, OS.window_size.y < 900)
	fundo.expand = true
	fundo.rect_size = Vector2(1280, 720)
	fundo.mouse_filter = MOUSE_FILTER_IGNORE
	mesa.add_child(fundo)
	if Jogo.selecao(local).get("extra", false):
		_estadio_extra(local)
	torcida = Torcida.new()
	torcida.rect_size = Vector2(1280, 720)
	mesa.add_child(torcida)
	torcida.cores(Jogo.selecao(siglas[0]).torcida, Jogo.selecao(siglas[1]).torcida)
	_montar_bandeiroes()

	fisica = Fisica.new()
	# chão do clima (respingos, graminhas) por BAIXO das peças
	var chao_clima := Node2D.new()
	mesa.add_child(chao_clima)
	var camada_pecas := Node2D.new()
	mesa.add_child(camada_pecas)
	# luz e chuva do clima por cima das peças (e embaixo da mira e do placar)
	clima = Clima.new()
	mesa.add_child(clima)
	clima.montar(clima_tipo, chao_clima)
	var piso := Clima.piso(clima_tipo)
	Campo.definir_piso(piso)
	# bola
	bola = Corpo.new()
	bola.tipo = Corpo.BOLA
	bola.raio = Campo.RAIO_BOLA
	bola.massa = 1.0
	bola.atrito = IA.ATRITO_BOLA * piso
	bola.amortece = IA.AMORTECE_BOLA * (1.0 + (piso - 1.0) * 0.5)
	bola.pos = Campo.CENTRO
	fisica.adicionar(bola)
	# times
	for t in [0, 1]:
		var g = Corpo.new()
		g.tipo = Corpo.GOLEIRO
		g.time = t
		g.numero = 1
		g.fixo = true
		g.raio = Campo.GOLEIRO_RAIO
		g.meio = params[t].goleiro_meio          # defesa melhor = goleiro maior
		g.pos = Vector2(_x_goleiro(t), Campo.CENTRO.y)
		fisica.adicionar(g)
		goleiros[t] = g
		var extra: bool = Jogo.selecao(siglas[t]).get("extra", false)
		var cam := {}
		if extra:
			cam = {"camisa": Jogo.cor_camisa(siglas[t], uniformes[t]), "borda": Jogo.cor_borda(siglas[t], uniformes[t]),
				"logo": Jogo.emblema(siglas[t]), "goleiro": Color(Jogo.selecao(siglas[t]).goleiro)}
		_criar_peca(camada_pecas, g, Jogo.textura_goleiro(siglas[t]), cam)
		for i in range(6):
			var b = Corpo.new()
			b.tipo = Corpo.BOTAO
			b.time = t
			b.numero = [3, 4, 6, 8, 10, 9][i]
			b.raio = Campo.RAIO_BOTAO
			b.massa = params[t].massa             # time forte: botão mais pesado
			b.atrito = IA.ATRITO_BOTAO
			b.pos = Campo.posicao_formacao(t, i)
			fisica.adicionar(b)
			botoes[t].append(b)
			_criar_peca(camada_pecas, b, Jogo.textura_botao(siglas[t], uniformes[t]), cam)
			pecas[b].cor_embalo = Jogo.cor_camisa(siglas[t], uniformes[t]).lightened(0.2)
	rastro = Line2D.new()
	rastro.width = 9.0
	rastro.default_color = Color(1, 1, 1, 0.35)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.45))
	rastro.gradient = grad
	rastro.joint_mode = Line2D.LINE_JOINT_ROUND
	camada_pecas.add_child(rastro)
	camada_pecas.move_child(rastro, 0)
	_criar_peca(camada_pecas, bola, load("res://imagens/bola.png"))
	# redes por cima da bola
	for lado in [0, 1]:
		var r := Sprite.new()
		r.texture = load("res://imagens/rede_%s.png" % ("esq" if lado == 0 else "dir"))
		r.scale = Vector2(0.5, 0.5)
		r.centered = false
		var x := Campo.x_gol_do_lado(lado)
		r.position = Vector2(x - (Campo.GOL_FUNDO + 4) if lado == 0 else x - 4, Campo.CENTRO.y - Campo.GOL_MEIA - 8)
		mesa.add_child(r)
		redes.append(r)
		_rede_base.append(r.position)
	mira = Mira.new()
	mesa.add_child(mira)
	poeira = CPUParticles2D.new()
	poeira.texture = load("res://imagens/faisca.png")
	poeira.amount = 14
	poeira.one_shot = true
	poeira.explosiveness = 0.9
	poeira.lifetime = 0.5
	poeira.emitting = false
	poeira.spread = 180
	poeira.initial_velocity = 90
	poeira.initial_velocity_random = 0.6
	poeira.damping = 120
	poeira.scale_amount = 0.22
	poeira.scale_amount_random = 0.5
	var rp := Gradient.new()
	rp.set_color(0, Color(0.8, 1.0, 0.7, 0.8))
	rp.set_color(1, Color(0.4, 0.8, 0.3, 0.0))
	poeira.color_ramp = rp
	mesa.add_child(poeira)


func _criar_peca(pai: Node, c, tex: Texture, camadas := {}) -> void:
	var p = Peca.new()
	pai.add_child(p)
	p.montar(c, tex, camadas)
	c.no = p
	pecas[c] = p


## Estádio do time do pendrive: o escudo pintado no meio e o nome nas placas.
func _estadio_extra(local: String) -> void:
	var e := Sprite.new()
	e.texture = Jogo.emblema(local)
	if e.texture != null:
		e.scale = Vector2.ONE * 118.0 / max(e.texture.get_width(), e.texture.get_height())
		e.position = Campo.CENTRO
		e.modulate = Color(1, 1, 1, 0.42)
		mesa.add_child(e)
	# placas de publicidade de cima e de baixo com o nome da arena e do time
	var t := Jogo.selecao(local)
	var c1 := Jogo.cor_camisa(local, 1)
	var c2 := Jogo.cor_borda(local, 1)
	var placas := [[t.estadio, c1.darkened(0.15), c2], ["LAZER & SPORT", Color("#0b1e5b"), Color("#ffd21f")],
		[t.nome, c2.darkened(0.1), c1], ["CRAQUE DE BOTÃO", Color("#111111"), Color.white]]
	var m := Campo.MURO
	var larg := m.size.x / 6.0
	var f := Jogo.fonte("bungee", 8)
	for i in range(6):
		for lado in [0, 1]:
			var k: Array = placas[(i + lado) % placas.size()]
			var y := m.position.y - 13.0 if lado == 0 else m.end.y + 2.0
			var pl := ColorRect.new()
			pl.color = k[1]
			pl.rect_position = Vector2(m.position.x + i * larg + 2.0, y)
			pl.rect_size = Vector2(larg - 4.0, 11.0)
			pl.mouse_filter = MOUSE_FILTER_IGNORE
			mesa.add_child(pl)
			var l := UI.label(k[0], f, k[2])
			l.clip_text = true
			UI.colocar(l, m.position.x + i * larg + 2.0, y - 1.0, larg - 4.0, 13.0)
			mesa.add_child(l)


## Bandeirões nas arquibancadas dos lados: casa na esquerda, fora na direita,
## com o escudo/logo de cada time que está jogando.
func _montar_bandeiroes() -> void:
	var sh: Shader = load("res://shaders/bandeirao.shader")
	for t in [0, 1]:
		var sig: String = siglas[t]
		var u: Array = Jogo.selecao(sig).torcida
		for k in range(2):
			var tr := TextureRect.new()
			tr.texture = Jogo.emblema(sig)
			tr.expand = true
			tr.mouse_filter = MOUSE_FILTER_IGNORE
			var w := 66.0
			var h := 118.0
			var x := 10.0 if t == 0 else 1280.0 - 10.0 - w
			var y := 170.0 + k * 250.0
			tr.rect_position = Vector2(x, y)
			tr.rect_size = Vector2(w, h)
			var m := ShaderMaterial.new()
			m.shader = sh
			m.set_shader_param("cor1", Color(u[k % 2]))
			m.set_shader_param("cor2", Color(u[(k + 1) % 2]))
			m.set_shader_param("aspecto", w / h)
			tr.material = m
			mesa.add_child(tr)
			bandeiroes.append([t, m, randf() * TAU])


## Deixa tudo pronto antes do jogo começar: letras grandes dos avisos e as
## imagens dos efeitos (antes carregavam na hora do gol e dava travadinha).
## Material aditivo único (faíscas, fogos): um shader só, já compilado.
var _aditivo := _novo_aditivo()


static func _novo_aditivo() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## VITRINE INVISÍVEL (na entrada da partida): desenha uma vez cada tipo de
## efeito que só aparece no meio do jogo (faísca aditiva, partículas normais
## e aditivas, cartão em vetor). No Android o shader de cada tipo é compilado
## no primeiro desenho; assim o tranco acontece aqui, escondido, e não no
## chute forte, no gol ou no cartão.
func _vitrine() -> void:
	var raiz := Node2D.new()
	raiz.modulate = Color(1, 1, 1, 0.012)
	raiz.position = Vector2(640, 360)
	mesa.add_child(raiz)
	var raiz_hud := Node2D.new()
	raiz_hud.modulate = Color(1, 1, 1, 0.012)
	raiz_hud.position = Vector2(640, 360)
	hud.add_child(raiz_hud)
	for pai in [raiz, raiz_hud]:
		var s := Sprite.new()
		s.texture = Jogo._tex("res://imagens/estrela.png")
		s.material = _aditivo
		pai.add_child(s)
		for aditiva in [false, true]:
			var c := CPUParticles2D.new()
			c.texture = Jogo._tex("res://imagens/confete.png" if not aditiva else "res://imagens/estrela.png")
			c.amount = 2
			c.lifetime = 0.5
			c.explosiveness = 1.0
			c.initial_velocity = 0.0
			if aditiva:
				c.material = _aditivo
			pai.add_child(c)
		var cc := CartaoTazo.new()
		cc.alto = 20.0
		pai.add_child(cc)
	get_tree().create_timer(1.2, false).connect("timeout", raiz, "queue_free")
	get_tree().create_timer(1.2, false).connect("timeout", raiz_hud, "queue_free")


func _preaquecer() -> void:
	for f in [Jogo.fonte("titan", 110, 7), Jogo.fonte("titan", 76, 7), Jogo.fonte("titan", 76, 6), Jogo.fonte("bungee", 22, 2),
			Jogo.fonte("titan", 40, 4), Jogo.fonte("titan", 34, 3), Jogo.fonte("titan", 36, 4), Jogo.fonte("titan", 44, 4)]:
		Jogo.preaquecer(f)
	for arq in ["cartao_amarelo", "cartao_vermelho", "estrela", "confete", "brilho"]:
		Jogo._tex("res://imagens/%s.png" % arq)
	# as formas da mira (todos os níveis de força) ficam prontas já na entrada
	mira.call_deferred("preaquecer")


func _x_goleiro(t: int) -> float:
	return Campo.linha_gol(t) + Campo.sentido(t) * (Campo.GOLEIRO_RAIO + 3.0)


func _montar_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	# placar no meio, em cima
	var painel := UI.painel(Color(1, 1, 1, 0.85), Color(0.02, 0.05, 0.12, 0.92), 14, 2, 10)
	UI.colocar(painel, 448, 4, 384, 70)
	hud.add_child(painel)
	var f_sigla = Jogo.fonte("bungee", 24, 2)
	var f_gol := Jogo.fonte("titan", 42, 3)
	for t in [0, 1]:
		var band := TextureRect.new()
		band.texture = Jogo.bandeira(siglas[t])
		band.expand = true
		band.stretch_mode = TextureRect.STRETCH_SCALE
		UI.colocar(band, 12 if t == 0 else 384 - 12 - 51, 8, 51, 34)
		painel.add_child(band)
		var s := UI.label(siglas[t], f_sigla, Color.white)
		UI.colocar(s, 66 if t == 0 else 384 - 66 - 72, 6, 72, 38)
		painel.add_child(s)
		var g := UI.label("0", f_gol, Jogo.AMARELO)
		UI.colocar(g, 140 if t == 0 else 384 - 140 - 44, 0, 44, 50)
		painel.add_child(g)
		lbl_gols.append(g)
	var x := UI.label("x", Jogo.fonte("titan", 26, 2), Color(1, 1, 1, 0.8))
	UI.colocar(x, 172, 2, 40, 46)
	painel.add_child(x)
	lbl_tempo = UI.label("1ºT  03:00", Jogo.fonte("bungee", 17, 2), Color(0.8, 0.95, 1.0))
	UI.colocar(lbl_tempo, 0, 44, 384, 24)
	painel.add_child(lbl_tempo)
	# jogo de volta da Copa: o placar somado com a ida
	lbl_agregado = UI.label("", Jogo.fonte("bungee", 16, 2), Jogo.AMARELO)
	UI.colocar(lbl_agregado, 448, 76, 384, 24)
	hud.add_child(lbl_agregado)
	_atualizar_agregado()
	# caixas dos times (vez, toques, relógio da vez, cartões)
	for t in [0, 1]:
		var cor := Jogo.cor_camisa(siglas[t], uniformes[t])
		var cx := UI.painel(cor, Color(0.02, 0.05, 0.12, 0.88), 14, 2, 8)
		UI.colocar(cx, 10 if t == 0 else 1280 - 10 - 330, 6, 330, 62)
		hud.add_child(cx)
		caixa_time.append(cx)
		var nome := UI.label(Jogo.selecao(siglas[t]).nome, Jogo.fonte("bungee", 17, 2), Color.white, Label.ALIGN_LEFT if t == 0 else Label.ALIGN_RIGHT)
		UI.colocar(nome, 14, 4, 302, 24)
		cx.add_child(nome)
		var v := UI.label("", Jogo.fonte("titan", 18, 2), Jogo.AMARELO, Label.ALIGN_LEFT if t == 0 else Label.ALIGN_RIGHT)
		UI.colocar(v, 14, 28, 200 if t == 0 else 302, 26)
		cx.add_child(v)
		lbl_vez.append(v)
		var tq = Bolinhas.new()
		tq.da_direita = t == 0
		UI.colocar(tq, 214 if t == 0 else 14, 29, 102, 24)
		cx.add_child(tq)
		lbl_toques.append(tq)
		var emb := UI.label("EMBALADO!", Jogo.fonte("titan", 16, 2), Jogo.LARANJA, Label.ALIGN_RIGHT if t == 0 else Label.ALIGN_LEFT)
		UI.colocar(emb, 14, 4, 302, 24)
		emb.visible = false
		cx.add_child(emb)
		lbl_embalo.append(emb)
		var bv := ColorRect.new()
		bv.mouse_filter = MOUSE_FILTER_IGNORE
		bv.color = cor
		UI.colocar(bv, 14, 56, 302, 3)
		cx.add_child(bv)
		barra_vez.append(bv)
		var cartas := HBoxContainer.new()
		cartas.mouse_filter = MOUSE_FILTER_IGNORE
		UI.colocar(cartas, 330 - 90 if t == 0 else 0, 64, 90, 26)
		cartas.alignment = BoxContainer.ALIGN_END if t == 0 else BoxContainer.ALIGN_BEGIN
		cx.add_child(cartas)
		icones_cartao.append(cartas)
	# faixa de aviso (FALTA, ESCANTEIO, GOL...)
	banner = Control.new()
	banner.mouse_filter = MOUSE_FILTER_IGNORE
	UI.colocar(banner, 0, 290, 1280, 150)
	banner.visible = false
	hud.add_child(banner)
	banner_fundo = ColorRect.new()
	banner_fundo.mouse_filter = MOUSE_FILTER_IGNORE
	banner_fundo.color = Color(0, 0, 0, 0.6)
	UI.colocar(banner_fundo, 0, 18, 1280, 114)
	banner.add_child(banner_fundo)
	banner_txt = UI.label("", Jogo.fonte("titan", 76, 6), Color.white)
	UI.colocar(banner_txt, 0, 4, 1280, 110)
	banner.add_child(banner_txt)
	banner_sub = UI.label("", Jogo.fonte("bungee", 22, 2), Color(1, 1, 1, 0.9))
	UI.colocar(banner_sub, 0, 100, 1280, 34)
	banner.add_child(banner_sub)
	dica = UI.label("", Jogo.fonte("titan", 22, 3), Color.white)
	UI.colocar(dica, 140, 644, 1000, 36)
	hud.add_child(dica)
	# pênaltis (disputa)
	painel_disputa = UI.painel(Jogo.AMARELO, Color(0.02, 0.05, 0.12, 0.9), 14, 2, 8)
	UI.colocar(painel_disputa, 448, 78, 384, 64)
	painel_disputa.visible = false
	hud.add_child(painel_disputa)
	for t in [0, 1]:
		var sg := UI.label(siglas[t], Jogo.fonte("bungee", 20, 2), Color.white, Label.ALIGN_LEFT)
		UI.colocar(sg, 14, 4 + t * 29, 80, 28)
		painel_disputa.add_child(sg)
		var l = Bolinhas.new()
		l.raio = 9.0
		l.espaco = 26.0
		UI.colocar(l, 96, 6 + t * 29, 276, 24)
		painel_disputa.add_child(l)
		lbl_disputa.append(l)
	# confete (duas cores: as do time que comemora)
	for i in range(2):
		var c := CPUParticles2D.new()
		c.texture = Jogo._tex("res://imagens/confete.png")
		c.amount = 70
		c.lifetime = 3.2
		c.emitting = false
		c.position = Vector2(640, -20)
		c.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		c.emission_rect_extents = Vector2(660, 10)
		c.direction = Vector2(0, 1)
		c.spread = 25
		c.gravity = Vector2(0, 160)
		c.initial_velocity = 160
		c.initial_velocity_random = 0.6
		c.angular_velocity = 300
		c.angular_velocity_random = 1.0
		c.scale_amount = 0.9
		c.scale_amount_random = 0.5
		hud.add_child(c)
		confete.append(c)
	flash = ColorRect.new()
	flash.anchor_right = 1
	flash.anchor_bottom = 1
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	flash.visible = false
	hud.add_child(flash)
	# pausa
	var bp := Button.new()
	bp.text = "II"
	bp.add_font_override("font", Jogo.fonte("titan", 22, 2))
	bp.flat = false
	UI.colocar(bp, 610, 680, 60, 36)
	bp.focus_mode = Control.FOCUS_NONE
	bp.connect("pressed", self, "_pausar")
	hud.add_child(bp)
	_atualizar_hud()


# ================================================================ FLUXO
func _intro() -> void:
	estado = PREPARO
	# dois jogadores com duas placas: o dono da casa aperta o botão da placa
	# dele (assim ninguém precisa trocar de lugar; a outra placa é do visitante)
	if controle[0] == 1 and controle[1] == 2 and Controles.placas_ligadas() >= 2:
		_pedir_placa()
		return
	_comecar_intro()


var _painel_placa: Control
var _t_placa := 0.0


func _pedir_placa() -> void:
	_painel_placa = UI.painel(Jogo.AMARELO, Color(0.02, 0.05, 0.12, 0.94), 24, 3, 20)
	UI.colocar(_painel_placa, 240, 250, 800, 220)
	hud.add_child(_painel_placa)
	UI.pop(_painel_placa, 0.1)
	var e := TextureRect.new()
	e.texture = Jogo.emblema(siglas[0])
	e.expand = true
	e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UI.colocar(e, 30, 40, 140, 140)
	e.mouse_filter = MOUSE_FILTER_IGNORE
	_painel_placa.add_child(e)
	var t := UI.label("JOGADOR DO %s" % Jogo.selecao(siglas[0]).nome, Jogo.fonte("titan", 36, 4), Color.white, Label.ALIGN_LEFT)
	UI.colocar(t, 190, 36, 590, 60)
	_painel_placa.add_child(t)
	var l := UI.label("APERTE O BOTÃO DA SUA PLACA", Jogo.fonte("titan", 34, 4), Jogo.AMARELO, Label.ALIGN_LEFT)
	UI.colocar(l, 190, 96, 590, 56)
	_painel_placa.add_child(l)
	var s2 := UI.label("a outra placa fica com %s" % Jogo.selecao(siglas[1]).nome, Jogo.fonte("texto", 20, 1), Color(1, 1, 1, 0.8), Label.ALIGN_LEFT)
	UI.colocar(s2, 190, 150, 590, 34)
	_painel_placa.add_child(s2)
	_t_placa = 0.0


func _placa_escolhida(dev: int) -> void:
	if _painel_placa == null:
		return
	if dev >= 0:
		Controles.definir_placa_do_jogador1(dev)
	Jogo.tocar("confirma")
	UI.sumir(_painel_placa, 0.0, 0.25)
	_painel_placa = null
	_comecar_intro()


func _comecar_intro() -> void:
	var ceu: String = {"sol": "DIA DE SOL", "chuva": "DIA DE CHUVA", "noite": "JOGO À NOITE", "noite_chuva": "NOITE COM CHUVA"}[clima_tipo]
	_aviso("%s x %s" % [Jogo.selecao(siglas[0]).nome, Jogo.selecao(siglas[1]).nome], ceu + "  •  QUE COMECE O JOGO!", Color(0.05, 0.25, 0.1, 0.75), 2.2)
	torcida.pular(0, 0.6, 2.5)
	torcida.pular(1, 0.6, 2.5)
	_depois(2.4, "_saida_de_bola", [0])


func _saida_de_bola(time: int) -> void:
	estado = PREPARO
	cobranca = ""
	fisica.parar_tudo()
	for t in [0, 1]:
		var i := 0
		for b in botoes[t]:
			if b.ativo:
				b.pos = Campo.posicao_formacao(t, i)
				pecas[b].suave = 0.7
			i += 1
		goleiros[t].pos = Vector2(_x_goleiro(t), Campo.CENTRO.y)
	bola.pos = Campo.CENTRO
	pecas[bola].suave = 0.5
	var batedor = _mais_perto(time, Campo.CENTRO)
	if batedor != null:
		batedor.pos = Campo.CENTRO - Vector2(Campo.sentido(time) * (Campo.RAIO_BOTAO + Campo.RAIO_BOLA + 3.0), 0)
	_desencavalar()
	Jogo.tocar("apito")
	_aviso("SAÍDA DE BOLA", Jogo.selecao(siglas[time]).nome, _cor_banner(time), 1.3)
	_depois(1.2, "_nova_vez", [time])


func _nova_vez(time: int, manter_toques := false) -> void:
	if _encerrou:
		return
	vez = time
	if not manter_toques:
		toques = 0
	estado = VEZ
	relogio_vez = float(Jogo.config.relogio_vez)
	_mirando = null
	mira.esconder()
	_cpu = {}
	carregando = [false, false]
	goleiro_manual = [false, false]
	for t in [0, 1]:
		for b in botoes[t]:
			var p = pecas[b]
			p.destaque = t == time and humano[t] and _pode_jogar(b)
			p.selecionado = false
	if not humano[time]:
		_cpu = {"t": 0.0, "pensar": rand_range(0.6, 1.0), "decisao": {}}
	else:
		_escolher_inicial(time)
		# o jogador já está segurando o botão quando a vez chega: a barra
		# começa a correr na hora (soltar chuta), nada de "botão morto"
		if controle[time] != 0 and sel[time] != null and Controles.segurando(controle[time], "chute"):
			carregando[time] = true
			t_carga[time] = 0.0
		if _cobrador_fixo() != null and cobranca != "penalti":
			dica.text = "%s: QUEM COBRA É O TAZO DESTACADO  •  ESQ/DIR mira  •  SEGURE o BOTÃO e solte" % cobranca.to_upper()
		elif _primeiro_toque_humano:
			dica.text = "MANCHE CIMA/BAIXO troca o tazo  •  ESQ/DIR mira  •  SEGURE o BOTÃO e solte na força certa"
	_atualizar_hud()


func _passar_vez(de: int) -> void:
	_nova_vez(1 - de)


# ================================================================ MANCHE
## Bola parada com cobrador (falta, lateral, escanteio): só ele joga, nada
## de trocar de tazo (pênalti: só o batedor).
func _cobrador_fixo():
	if cobranca == "penalti":
		return penalti_cobrador
	# só vale para o time que cobra (se a vez passou, cada um joga com todos)
	if cobranca in ["falta", "lateral", "escanteio"] and cobrador != null and cobrador.ativo and cobrador.time == vez:
		return cobrador
	return null


func _pode_jogar(b) -> bool:
	var fixo = _cobrador_fixo()
	return b.ativo and (fixo == null or b == fixo)


## Botões do time na ordem de perto para longe da bola (cima/baixo percorre).
func _lista_escolha(time: int) -> Array:
	var lista := []
	for b in botoes[time]:
		if _pode_jogar(b):
			lista.append(b)
	if lista.empty():
		# nunca fica sem tazo para jogar
		for b in botoes[time]:
			if b.ativo:
				lista.append(b)
	lista.sort_custom(self, "_mais_perto_da_bola")
	return lista


func _mais_perto_da_bola(a, b) -> bool:
	return a.pos.distance_squared_to(bola.pos) < b.pos.distance_squared_to(bola.pos)


## Começo da vez: o botão mais perto da bola, mirando na bola.
func _escolher_inicial(time: int) -> void:
	var lista := _lista_escolha(time)
	if lista.empty():
		return
	# bola parada: começa no cobrador posicionado (não num vizinho)
	if cobranca in ["falta", "lateral", "escanteio", "tiro de meta"] and cobrador != null and cobrador in lista:
		_selecionar(time, cobrador)
		return
	_selecionar(time, lista[0])


func _selecionar(time: int, b) -> void:
	if sel[time] != null and pecas.has(sel[time]):
		pecas[sel[time]].selecionado = false
	sel[time] = b
	pecas[b].selecionado = true
	var alvo: Vector2 = bola.pos
	if cobranca == "penalti":
		alvo = Campo.centro_gol(1 - time)
	ang[time] = (alvo - b.pos).angle()
	carregando[time] = false
	_mostrar_mira_manche(time)


func _trocar_botao(time: int, passo: int) -> void:
	var lista := _lista_escolha(time)
	if lista.size() < 2:
		return
	var i := lista.find(sel[time])
	i = (i + passo + lista.size()) % lista.size()
	_selecionar(time, lista[i])
	Jogo.tocar("clique", -6.0)


## Valor da barra: sobe e desce (0..1..0) enquanto o chute está apertado.
func _valor_barra(time: int) -> float:
	var ciclo: float = Jogo.parametros(siglas[time], embalo[time] > 0.0).ciclo_barra
	var f := fmod(t_carga[time] / ciclo, 2.0)
	return f if f <= 1.0 else 2.0 - f


func _vmax(time: int) -> float:
	return Jogo.parametros(siglas[time], embalo[time] > 0.0).vmax


func _velocidade_da_forca(time: int, f: float) -> float:
	return lerp(VMIN, _vmax(time), pow(clamp(f, 0.04, 1.0), 1.1))


func _mostrar_mira_manche(time: int) -> void:
	var b = sel[time]
	if b == null or _mirando != null:
		return
	var f := _valor_barra(time) if carregando[time] else 0.0
	var dir := Vector2(cos(ang[time]), sin(ang[time]))
	# sem carregar: mostra só a direção (pontilhado de meia força)
	var v := _velocidade_da_forca(time, f) if carregando[time] else _velocidade_da_forca(time, 0.45)
	mira.mostrar(b.pos, dir, f, v, null, carregando[time])


func _input(ev: InputEvent) -> void:
	if _pausado or ev.is_echo():
		return
	if _painel_placa != null:
		if ev is InputEventJoypadButton and ev.pressed:
			get_tree().set_input_as_handled()
			_placa_escolhida(ev.device)
		elif (ev is InputEventKey and ev.pressed) or (ev is InputEventMouseButton and ev.pressed):
			get_tree().set_input_as_handled()
			_placa_escolhida(-1)        # teclado/toque: fica como está
		return
	for t in [0, 1]:
		var p: int = controle[t]
		if p == 0:
			continue
		if estado == FIM:
			# tela final: o botão de qualquer placa confirma o botão em foco
			# (ou CONTINUAR / REVANCHE), mesmo se o foco tiver se perdido
			if Controles.apertou(ev, p, "chute") and _tela_final_pronta:
				get_tree().set_input_as_handled()
				_confirmar_tela_final()
			return
		if Controles.apertou(ev, p, "pausa"):
			_pausar()
			return
		if estado != VEZ or vez != t or sel[t] == null or _mirando != null:
			continue
		# o chute vem direto do evento (sem esperar o quadro): zero atraso
		if Controles.apertou(ev, p, "chute") and not carregando[t]:
			carregando[t] = true
			t_carga[t] = 0.0
			_primeiro_toque_humano = false
			dica.text = ""
		elif Controles.soltou(ev, p, "chute") and carregando[t]:
			_soltar_chute(t)


func _soltar_chute(t: int) -> void:
	carregando[t] = false
	var f := _valor_barra(t)
	var b = sel[t]
	pecas[b].selecionado = false
	sel[t] = null
	_chutar(b, Vector2(cos(ang[t]), sin(ang[t])) * _velocidade_da_forca(t, f))


## Segurar ESQ/DIR gira a mira cada vez mais rápido; a barra corre.
func _manche_segurando(delta: float) -> void:
	var t := vez
	var p: int = controle[t]
	if p == 0 or sel[t] == null or _mirando != null:
		return
	# direções lidas a cada quadro (manche digital ou analógico, sem repetição)
	if Controles.acabou_de_apertar(p, "cima"):
		_trocar_botao(t, -1)
	elif Controles.acabou_de_apertar(p, "baixo"):
		_trocar_botao(t, 1)
	if sel[t] == null:
		return
	if Controles.acabou_de_apertar(p, "esq"):
		ang[t] -= deg2rad(1.5)
		t_girar[t] = 0.0
	elif Controles.acabou_de_apertar(p, "dir"):
		ang[t] += deg2rad(1.5)
		t_girar[t] = 0.0
	var giro := 0
	if Controles.segurando(p, "esq"):
		giro -= 1
	if Controles.segurando(p, "dir"):
		giro += 1
	if giro != 0:
		t_girar[t] += delta
		# devagar no começo (ajuste fino), depois acelera
		var vel_ang := deg2rad(28.0) if t_girar[t] < 0.3 else deg2rad(min(200.0, 28.0 + (t_girar[t] - 0.3) * 320.0))
		ang[t] += giro * vel_ang * delta
	else:
		t_girar[t] = 0.0
	if carregando[t]:
		t_carga[t] += delta
		# ninguém segura o chute para sempre: chuta com a força do momento
		if t_carga[t] > 8.0:
			_soltar_chute(t)
			return
	_mostrar_mira_manche(t)


# ============================================================== O QUADRO
func _process(delta: float) -> void:
	_t += delta
	_medir_quadro(delta)
	_animar_redes(delta)
	if estado == VEZ or estado == MOVENDO:
		if disputa.empty():
			tempo = max(0.0, tempo - delta)
		for t in [0, 1]:
			if embalo[t] > 0.0:
				embalo[t] = max(0.0, embalo[t] - delta)
				if embalo[t] <= 0.0:
					_fim_embalo(t)
	if estado == VEZ:
		_posicionar_goleiros(delta)
		relogio_vez -= delta
		if humano[vez]:
			_manche_segurando(delta)
		else:
			_cpu_pensar(delta)
		var ocupado: bool = _mirando != null or carregando[vez]
		if relogio_vez <= 0.0 and carregando[vez] and sel[vez] != null and _mirando == null:
			# o tempo acabou com o botão apertado: chuta com a força do momento
			_soltar_chute(vez)
		elif relogio_vez <= 0.0 and not ocupado:
			_tempo_esgotado()
		elif relogio_vez <= -4.0:
			# LIMITE DURO: a vez estourou e o botão parece "preso" (o soltar
			# se perdeu) ou a mira de toque ficou aberta: nunca congela
			_log("VEZ PRESA %s: destravando" % siglas[vez])
			if carregando[vez] and sel[vez] != null:
				_soltar_chute(vez)
			else:
				carregando[vez] = false
				_mirando = null
				mira.esconder()
				_tempo_esgotado()
		elif tempo <= 0.0 and disputa.empty() and not ocupado:
			_fim_do_tempo()
	_vigiar(delta)
	if flash.visible:
		flash.color.a -= delta * 2.5
		if flash.color.a <= 0.0:
			flash.visible = false
	_fase_bandeira = fmod(_fase_bandeira + delta * 3.2, TAU)
	for bd in bandeiroes:
		var t2: int = bd[0]
		var m: ShaderMaterial = bd[1]
		m.set_shader_param("fase", fmod(_fase_bandeira * _forca_bandeira[t2] + bd[2], TAU))
		m.set_shader_param("forca", _forca_bandeira[t2])
	_atualizar_rastro()
	_atualizar_hud()


## Quem marcou fica EMBALADO: chute mais forte, barra mais calma, brilho.
func _comecar_embalo(time: int) -> void:
	embalo[time] = 40.0
	embalo[1 - time] = 0.0
	_fim_embalo(1 - time)
	for b in botoes[time]:
		pecas[b].embalo = b.ativo
	lbl_embalo[time].visible = true
	UI.pulsar(lbl_embalo[time], 0.5, 0.5)


func _fim_embalo(time: int) -> void:
	for b in botoes[time]:
		pecas[b].embalo = false
	lbl_embalo[time].visible = false


func _physics_process(delta: float) -> void:
	if estado != MOVENDO:
		return
	_t_jogada += delta
	fisica.passo(delta)
	for c in fisica.corpos:
		if c.ativo and not c.fixo:
			clima.rastro(c)
	for ev in fisica.eventos:
		_evento(ev)
	_verificar_bola()
	var fim = fisica.tudo_parado()
	if _parar_em > 0.0 and _t_jogada >= _parar_em:
		fim = true
	if _t_jogada > 9.0:
		fim = true
	if fim:
		fisica.parar_tudo()
		estado = EVENTO
		_resolver()


func _chutar(b, vel: Vector2) -> void:
	jogada = {"botao": b, "time": b.time, "tocou": false, "rival": null, "impacto": 0.0, "local": Vector2.ZERO,
		"gol": -1, "fora": null, "trave": false}
	if humano[b.time]:
		_ociosas = 0
	b.vel = vel
	# LATERAL e ESCANTEIO: a bola sai do meio do cobrador, exatamente na
	# direção da mira (o pontilhado): nada de cobrança torta, fraca ou
	# impossível. O cobrador fica parado; a bola leva a força da barra.
	if cobranca in ["lateral", "escanteio"] and b == cobrador and vel.length() > 1.0:
		var d := vel.normalized()
		bola.pos = b.pos + d * (b.raio + bola.raio + 1.0)
		bola.vel = vel * 1.45
		b.vel = Vector2.ZERO
		jogada.tocou = true
		ultimo_toque = b.time
		ultimo_botao_bola = b
		_som("bola", vel.length(), 0.05)
	estado = MOVENDO
	_t_jogada = 0.0
	_parar_em = -1.0
	mira.esconder()
	dica.text = ""
	carregando = [false, false]
	for t in [0, 1]:
		if sel[t] != null and pecas.has(sel[t]):
			pecas[sel[t]].selecionado = false
		sel[t] = null
		for x in botoes[t]:
			pecas[x].destaque = false
	_log("CHUTE %s nº%d v=%d toques=%d cobranca=%s gk=%d" % [siglas[b.time], b.numero, int(vel.length()), toques, cobranca, int(goleiros[1 - b.time].pos.y)])
	var f := min(1.0, vel.length() / VMAX)
	Jogo.tocar("peteleco", linear2db(0.4 + 0.6 * f), rand_range(0.95, 1.08))
	clima.explosao(b.pos, 0.5 + f)
	Jogo.tocar("respingo" if Clima.chove(clima_tipo) else "grama", linear2db(0.25 + 0.5 * f) - (0.0 if Clima.chove(clima_tipo) else 8.0), rand_range(0.9, 1.1))
	poeira.position = b.pos
	poeira.restart()


func _evento(ev: Dictionary) -> void:
	var a = ev.a
	var b = ev.b
	var v: float = ev.v
	match ev.tipo:
		"corpo":
			var c_bola = null
			var outro = null
			if a == bola:
				c_bola = a
				outro = b
			elif b == bola:
				c_bola = b
				outro = a
			if c_bola != null:
				ultimo_toque = outro.time
				ultimo_botao_bola = outro
				if outro == jogada.botao:
					jogada.tocou = true
				_som("bola", v, 0.05)
			else:
				var j = jogada.botao
				var rival = null
				if a == j and b.time != j.time:
					rival = b
				elif b == j and a.time != j.time:
					rival = a
				# encostadinha não conta: falta é batida de verdade
				if rival != null and not jogada.tocou and jogada.rival == null and v > 60.0:
					jogada.rival = rival
					jogada.impacto = v
					jogada.local = rival.pos
				_som("batida", v, 0.04)
				if v > 500.0:
					_faisca((a.pos + b.pos) * 0.5)
		"trave":
			if a == bola:
				jogada.trave = true
				# o metal na hora; o "UUUUH!" da torcida vem logo depois
				# (nada de vaia na trave)
				_som("trave", max(v, 450.0), 0.3)
				if v > 250.0 and jogada.gol < 0 and _som_cooldown.get("uuu", -1.0) <= _t:
					_som_cooldown["uuu"] = _t + 2.5
					get_tree().create_timer(rand_range(0.18, 0.3), false).connect("timeout", Jogo, "tocar", ["torcida_uuu", -1.0])
					var onde := Vector2(clamp(a.pos.x, 230.0, 1050.0), clamp(a.pos.y, 160.0, 640.0))
					UI.flutuar(hud, "NA TRAVE!", Jogo.fonte("titan", 40, 4), Jogo.AMARELO, _na_tela(onde), _na_tela(onde) + Vector2(0, -70), 1.1)
		"rede":
			if a == bola:
				_som("rede", v, 0.25)
		"placa":
			_som("placa", v, 0.1)


func _som(nome: String, v: float, intervalo: float) -> void:
	if v < 40.0:
		return
	if _som_cooldown.get(nome, -1.0) > _t:
		return
	_som_cooldown[nome] = _t + intervalo
	var vol := clamp(v / 900.0, 0.12, 1.0)
	Jogo.tocar(nome, linear2db(vol), rand_range(0.94, 1.06))


func _verificar_bola() -> void:
	if jogada.gol >= 0 or jogada.fora != null:
		return
	var p: Vector2 = bola.pos
	var r := Campo.RAIO_BOLA
	var c := Campo.CAMPO
	for lado in [0, 1]:
		var dentro_do_gol: bool = abs(p.y - Campo.CENTRO.y) < Campo.GOL_MEIA
		# gol: a bola entrou (o centro passou a linha entre as traves); fora:
		# a bola inteira saiu pela linha de fundo
		var passou: bool
		if dentro_do_gol:
			passou = (p.x < c.position.x) if lado == 0 else (p.x > c.end.x)
		else:
			passou = (p.x < c.position.x - r) if lado == 0 else (p.x > c.end.x + r)
		if not passou:
			continue
		if dentro_do_gol:
			jogada.gol = 1 - Campo.time_do_lado(lado)
			_parar_em = _t_jogada + 1.0
			_rede_balanca(lado)
		else:
			jogada.fora = {"tipo": "fundo", "lado": Campo.time_do_lado(lado), "pos": p}
			_parar_em = _t_jogada + 0.3
		return
	if p.y < c.position.y - r or p.y > c.end.y + r:
		jogada.fora = {"tipo": "lateral", "pos": p}
		_parar_em = _t_jogada + 0.3


# ================================================================ REGRAS
func _resolver() -> void:
	var j := jogada
	if not disputa.empty():
		_resolver_disputa()
		return
	if j.gol >= 0:
		_gol(j.gol)
		return
	var era_penalti := cobranca == "penalti"
	cobranca = ""
	if j.rival != null and not j.tocou:
		_falta(j)
		return
	if tempo <= 0.0:
		_fim_do_tempo()
		return
	if j.fora != null:
		_bola_fora(j.fora)
		return
	if era_penalti:
		_passar_vez(j.time)
		return
	if j.tocou:
		toques += 1
		if toques >= int(Jogo.config.toques):
			var onde2 := Vector2(clamp(bola.pos.x, 230.0, 1050.0), clamp(bola.pos.y, 160.0, 640.0))
			UI.flutuar(hud, "%d TOQUES!" % toques, Jogo.fonte("titan", 34, 3), Color.white, _na_tela(onde2), _na_tela(onde2) + Vector2(0, -60), 1.0)
			_depois(0.5, "_passar_vez", [j.time])
		else:
			_nova_vez(j.time, true)
	else:
		_passar_vez(j.time)


## VIGIA: nenhum estado de passagem fica parado para sempre. Bola tremendo
## sem parar (MOVENDO), evento ou preparo que não termina: para tudo e
## devolve a vez.
var _estado_ant := -1
var _t_estado := 0.0


func _vigiar(delta: float) -> void:
	if estado != _estado_ant:
		_estado_ant = estado
		_t_estado = 0.0
		return
	if _pausado or _encerrou or estado == FIM or estado == VEZ or _painel_placa != null:
		return
	_t_estado += delta
	var limite := 12.0 if estado == MOVENDO else 16.0
	if _t_estado < limite:
		return
	_t_estado = 0.0
	_log("VIGIA: estado %d parado %.0f s, destravando" % [estado, limite])
	fisica.parar_tudo()
	if estado == MOVENDO:
		estado = EVENTO
		_resolver()
	else:
		cobranca = ""
		_nova_vez(vez)


# W.O.: vezes seguidas que um jogador de verdade deixou o tempo acabar sem
# jogar. Dois jogadores parados: 6 (3 de cada); contra a CPU: 4.
var _ociosas := 0
var _vencedor_wo := -1
var _pen_wo := []


func _contar_ociosa() -> void:
	if not humano[vez] or not disputa.empty():
		return
	_ociosas += 1
	var limite := 6 if humano[0] and humano[1] else 4
	if _ociosas == limite - 1:
		UI.flutuar(hud, "SEM JOGADAS: MAIS UMA E É W.O.!", Jogo.fonte("titan", 34, 3), Jogo.AMARELO, Vector2(640, 420), Vector2(640, 360), 2.2)
	if _ociosas >= limite:
		_wo()


## W.O.: ninguém jogou (ou o jogador sumiu contra a CPU): a partida acaba.
## Dois parados: fica o placar; empate em jogo que decide vai no sorteio.
## Contra a CPU: a CPU vence (W.O. de 3 gols).
func _wo() -> void:
	if _encerrou or estado == FIM:
		return
	estado = FIM
	_mirando = null
	mira.esconder()
	fisica.parar_tudo()
	var sub := "NINGUÉM JOGOU  •  PARTIDA ENCERRADA"
	if humano[0] and humano[1]:
		var ag := _agregado()
		var conta: Array = placar if ag.empty() else ag
		if Jogo.partida.penaltis and conta[0] == conta[1]:
			_vencedor_wo = randi() % 2
			_pen_wo = [1, 0] if _vencedor_wo == 0 else [0, 1]
			sub = "EMPATE: SORTEIO PARA %s" % Jogo.selecao(siglas[_vencedor_wo]).nome
	else:
		var cpu := 0 if not humano[0] else 1
		placar[cpu] = max(placar[cpu], placar[1 - cpu] + 3)
		_atualizar_placar_wo()
		sub = "SEM JOGADAS  •  VITÓRIA DE %s" % Jogo.selecao(siglas[cpu]).nome
	_log("W.O. %s %d x %d %s" % [siglas[0], placar[0], placar[1], siglas[1]])
	Jogo.tocar("apito_fim")
	_aviso("W.O.", sub, Color(0.35, 0.05, 0.05, 0.85), 3.0)
	_depois(3.2, "_encerrar", [])


func _atualizar_placar_wo() -> void:
	for t in [0, 1]:
		lbl_gols[t].text = str(placar[t])


func _tempo_esgotado() -> void:
	estado = EVENTO
	_log("TEMPO ESGOTADO %s" % siglas[vez])
	_contar_ociosa()
	if estado == FIM:
		return
	UI.flutuar(hud, "TEMPO!", Jogo.fonte("titan", 44, 4), Jogo.VERMELHO, Vector2(640, 360), Vector2(640, 300), 1.0)
	# o tempo acabou: a cobrança (pênalti, falta, lateral, escanteio) se perde
	cobranca = ""
	_depois(0.8, "_passar_vez", [vez])


func _falta(j: Dictionary) -> void:
	estado = EVENTO
	var faltoso = j.botao
	var time: int = j.time
	faltas[time] += 1
	Jogo.tocar("apito_falta")
	Jogo.tocar("torcida_vaia", -5.0)
	var local: Vector2 = j.local
	local.x = clamp(local.x, Campo.CAMPO.position.x + 14, Campo.CAMPO.end.x - 14)
	local.y = clamp(local.y, Campo.CAMPO.position.y + 14, Campo.CAMPO.end.y - 14)
	var penalti := Campo.na_area(local, time)
	_log("FALTA de %s nº%d impacto=%d penalti=%s" % [siglas[time], faltoso.numero, int(j.impacto), str(penalti)])
	# cartão
	# cartão: batida forte, ou o mesmo botão fazendo a 2ª falta (reincidência)
	var cartao := ""
	var reincidente: bool = faltoso.get_meta("faltas") >= 1 if faltoso.has_meta("faltas") else false
	faltoso.set_meta("faltas", (faltoso.get_meta("faltas") if faltoso.has_meta("faltas") else 0) + 1)
	if j.impacto >= VERMELHO_V:
		cartao = "vermelho"
	elif j.impacto >= AMARELO_V or reincidente:
		cartao = "vermelho" if faltoso.amarelos >= 1 else "amarelo"
	_aviso("PÊNALTI!" if penalti else "FALTA!", "de %s nº %d" % [Jogo.selecao(siglas[time]).nome, faltoso.numero], Color(0.55, 0.05, 0.05, 0.8) if penalti else Color(0.1, 0.1, 0.1, 0.75), 1.6)
	var espera := 1.7
	if cartao != "":
		_depois(1.8, "_mostrar_cartao", [faltoso, cartao])
		espera = 4.1
	if penalti:
		_depois(espera, "_cobranca_penalti", [1 - time])
	else:
		_depois(espera, "_cobranca", ["FALTA", 1 - time, local, (Campo.centro_gol(time) - local).normalized()])


func _mostrar_cartao(b, tipo: String) -> void:
	var t: int = b.time
	Jogo.tocar("apito_falta", -4.0)
	Jogo.tocar("cartao")
	var tex: Texture = Jogo._tex("res://imagens/cartao_%s.png" % tipo)
	var cr := TextureRect.new()
	cr.mouse_filter = MOUSE_FILTER_IGNORE
	cr.texture = tex
	UI.colocar(cr, 640 - 60, 360 - 84, 120, 168)
	hud.add_child(cr)
	var tw := Tween.new()
	cr.add_child(tw)
	tw.interpolate_property(cr, "rect_position:y", 760, 280, 0.45, Tween.TRANS_BACK, Tween.EASE_OUT)
	tw.interpolate_property(cr, "rect_rotation", -25, 8, 0.45, Tween.TRANS_BACK, Tween.EASE_OUT)
	tw.interpolate_property(cr, "modulate:a", 1.0, 0.0, 0.35, Tween.TRANS_SINE, Tween.EASE_IN, 1.7)
	tw.interpolate_callback(cr, 2.1, "queue_free")
	tw.start()
	var txt := "CARTÃO AMARELO" if tipo == "amarelo" else ("EXPULSO!" if b.amarelos >= 1 or tipo == "vermelho" else "CARTÃO VERMELHO")
	var l := UI.label(txt + "  nº %d" % b.numero, Jogo.fonte("titan", 36, 4), Jogo.AMARELO if tipo == "amarelo" else Jogo.VERMELHO)
	UI.colocar(l, 0, 470, 1280, 50)
	hud.add_child(l)
	UI.pop(l, 0.3)
	UI.sumir(l, 1.9, 0.3)
	_log("CARTAO %s %s nº%d" % [tipo, siglas[t], b.numero])
	if tipo == "amarelo":
		b.amarelos += 1
		cartoes[t][0] += 1
		if pecas.has(b):
			pecas[b].marcar_amarelo()
	else:
		cartoes[t][1] += 1
		_expulsar(b)
	_atualizar_cartoes()


func _expulsar(b) -> void:
	# nunca menos de 3 botões na mesa
	var ativos := 0
	for x in botoes[b.time]:
		if x.ativo:
			ativos += 1
	if ativos <= 3:
		return
	b.ativo = false
	b.vel = Vector2.ZERO
	var p = pecas[b]
	var tw := Tween.new()
	p.add_child(tw)
	tw.interpolate_property(p, "scale", Vector2.ONE, Vector2(1.6, 1.6), 0.6, Tween.TRANS_SINE, Tween.EASE_OUT, 0.4)
	tw.interpolate_property(p, "modulate:a", 1.0, 0.0, 0.6, Tween.TRANS_SINE, Tween.EASE_IN, 0.4)
	tw.start()


func _atualizar_cartoes() -> void:
	for t in [0, 1]:
		var box: HBoxContainer = icones_cartao[t]
		for c in box.get_children():
			c.queue_free()
		for k in range(cartoes[t][0] + cartoes[t][1]):
			var tr := TextureRect.new()
			tr.texture = Jogo._tex("res://imagens/cartao_%s.png" % ("amarelo" if k < cartoes[t][0] else "vermelho"))
			tr.expand = true
			tr.rect_min_size = Vector2(14, 20)
			tr.mouse_filter = MOUSE_FILTER_IGNORE
			box.add_child(tr)


func _bola_fora(f: Dictionary) -> void:
	estado = EVENTO
	var p: Vector2 = f.pos
	var quem := ultimo_toque if ultimo_toque >= 0 else jogada.time
	_log("FORA %s ultimo=%s" % [f.tipo, siglas[quem]])
	var c := Campo.CAMPO
	if f.tipo == "lateral":
		var time := 1 - quem
		var em_cima := p.y < Campo.CENTRO.y
		# a bola fica um pouco DENTRO do campo e o cobrador ao lado dela, no
		# gramado: nunca encostado nas placas/torcida (jogada cega, travada)
		var pos := Vector2(clamp(p.x, c.position.x + 70, c.end.x - 70), c.position.y + LATERAL_DENTRO if em_cima else c.end.y - LATERAL_DENTRO)
		var dentro := Vector2(0, 1 if em_cima else -1)
		var dir := (dentro * 0.75 + Vector2(Campo.sentido(time), 0)).normalized()
		_cobranca("LATERAL", time, pos, dir)
		return
	var lado: int = f.lado        # time que defende essa linha de fundo
	var em_cima2 := p.y < Campo.CENTRO.y
	if quem == lado:
		var time2 := 1 - lado
		# escanteio: bola perto do canto, mas dentro, e o cobrador no gramado
		var canto := Vector2(Campo.linha_gol(lado) + Campo.sentido(lado) * 34.0, c.position.y + 46.0 if em_cima2 else c.end.y - 46.0)
		var dir2 := (Campo.marca_penalti(lado) - canto).normalized()
		_cobranca("ESCANTEIO", time2, canto, dir2)
	else:
		# bola no bico da pequena área, na altura da trave: o cobrador fica na
		# frente da linha do gol, longe da trave e do goleiro (não trava)
		var pos3 := Vector2(Campo.linha_gol(lado) + Campo.sentido(lado) * (Campo.AREA_G + 22.0), Campo.CENTRO.y + (-1 if em_cima2 else 1) * Campo.GOL_MEIA)
		_cobranca("TIRO DE META", lado, pos3, Vector2(Campo.sentido(lado), 0))


## Bola parada: coloca a bola, o cobrador atrás dela e afasta os rivais.
func _cobranca(tipo: String, time: int, pos_bola: Vector2, dir: Vector2) -> void:
	estado = PREPARO
	cobranca = tipo.to_lower()
	fisica.parar_tudo()
	bola.pos = pos_bola
	pecas[bola].suave = 0.6
	var batedor = _mais_perto(time, pos_bola)
	cobrador = batedor
	if batedor != null:
		# o cobrador fica EXATAMENTE atrás da bola, na linha da mira: a mira
		# inicial (do tazo para a bola) sai na direção certa e acerta a bola
		# em cheio. Sem espaço atrás (canto, placas, linha do gol), a bola e o
		# cobrador entram juntos para o gramado, sem sair da linha.
		var folga := 6.0 if cobranca in ["tiro de meta", "lateral", "escanteio"] else 22.0
		var r := Campo.RAIO_BOTAO
		var atras := pos_bola - dir * (r + Campo.RAIO_BOLA + folga)
		var margem := Vector2(r + 4.0, r + 2.0)
		var livre := Rect2(Campo.CAMPO.position + margem, Campo.CAMPO.size - margem * 2.0)
		var desvio := Vector2(clamp(atras.x, livre.position.x, livre.end.x) - atras.x, clamp(atras.y, livre.position.y, livre.end.y) - atras.y)
		if desvio.length() > 0.0:
			atras += desvio
			pos_bola += desvio
			bola.pos = pos_bola
		batedor.pos = atras
		pecas[batedor].suave = 0.7
	# rivais a ~90 px da bola (distância da barreira); companheiros a ~63 px,
	# e ninguém entre o cobrador e a bola
	for t in [0, 1]:
		var raio_livre := Campo.RAIO_BOTAO + (58.0 if t != time else 32.0)
		for b in botoes[t]:
			if not b.ativo or b == batedor:
				continue
			var d: Vector2 = b.pos - pos_bola
			if d.length() < raio_livre:
				var n := d.normalized() if d.length() > 1.0 else dir.rotated(PI * 0.5)
				if n.dot(-dir) > 0.6:
					n = (n + dir.rotated(PI * 0.5) * sign(n.cross(dir) + 0.01)).normalized()
				b.pos = pos_bola + n * (raio_livre + 2.0)
				b.pos.x = clamp(b.pos.x, Campo.MURO.position.x + b.raio, Campo.MURO.end.x - b.raio)
				b.pos.y = clamp(b.pos.y, Campo.MURO.position.y + b.raio, Campo.MURO.end.y - b.raio)
				pecas[b].suave = 0.7
	# lateral e escanteio: dois companheiros chegam perto para receber o
	# passe ou tabelar (um curto, ao lado; outro mais à frente)
	if cobranca in ["lateral", "escanteio"] and batedor != null:
		var livres := []
		for b in botoes[time]:
			if b.ativo and b != batedor:
				livres.append(b)
		livres.sort_custom(self, "_mais_perto_da_bola")
		var alvos := []
		if cobranca == "escanteio":
			alvos = [pos_bola + dir * 165.0, pos_bola + dir.rotated(0.75 * sign(dir.cross(Campo.CENTRO - pos_bola) + 0.01)) * 100.0]
		else:
			alvos = [pos_bola + dir.rotated(-0.55) * 120.0, pos_bola + dir.rotated(0.55) * 150.0]
		var m := Campo.RAIO_BOTAO + 12.0
		for i in range(min(2, livres.size())):
			var q: Vector2 = alvos[i]
			q.x = clamp(q.x, Campo.CAMPO.position.x + m, Campo.CAMPO.end.x - m)
			q.y = clamp(q.y, Campo.CAMPO.position.y + m, Campo.CAMPO.end.y - m)
			livres[i].pos = q
			pecas[livres[i]].suave = 0.8
	_desencavalar([batedor])
	_aviso(tipo, Jogo.selecao(siglas[time]).nome, _cor_banner(time), 1.3)
	_depois(1.2, "_nova_vez", [time])


func _cobranca_penalti(time: int) -> void:
	estado = PREPARO
	fisica.parar_tudo()
	var def := 1 - time
	var marca := Campo.marca_penalti(def)
	var dir := (Campo.centro_gol(def) - marca).normalized()
	bola.pos = marca
	pecas[bola].suave = 0.6
	var batedor = _mais_perto(time, marca)
	penalti_cobrador = batedor
	if batedor != null:
		batedor.pos = marca - dir * (Campo.RAIO_BOTAO + Campo.RAIO_BOLA + 42.0)
		pecas[batedor].suave = 0.7
	# todo mundo para fora da área
	var borda := Campo.linha_gol(def) + Campo.sentido(def) * (Campo.AREA_P + 30.0)
	for t in [0, 1]:
		for b in botoes[t]:
			if b.ativo and b != batedor and Campo.na_area(b.pos, def):
				b.pos.x = borda
				pecas[b].suave = 0.8
	goleiros[def].pos = Vector2(_x_goleiro(def), Campo.CENTRO.y)
	_desencavalar([batedor])
	cobranca = "penalti"
	Jogo.tocar("rufar", -2.0)
	_aviso("PÊNALTI!", Jogo.selecao(siglas[time]).nome + " vai cobrar", Color(0.55, 0.05, 0.05, 0.8), 1.8)
	_depois(1.9, "_nova_vez", [time])


func _gol(time: int) -> void:
	estado = EVENTO
	placar[time] += 1
	_log("GOL %s  placar %d x %d" % [siglas[time], placar[0], placar[1]])
	# gol contra só quando o próprio time chutou para o seu gol; desvio do
	# goleiro ou de um zagueiro vai na conta de quem chutou
	var chutou = jogada.get("botao")
	var autor := ""
	if chutou != null and chutou.time != time:
		autor = "GOL CONTRA"
	elif chutou != null and jogada.tocou:
		autor = "nº %d" % chutou.numero
	elif ultimo_botao_bola != null and ultimo_botao_bola.time == time and ultimo_botao_bola.numero > 1:
		autor = "nº %d" % ultimo_botao_bola.numero
	Jogo.tocar("rede")
	Jogo.tocar_grupo("gol", "torcida_gol", 2.0)
	# o mandante tomou gol: a torcida da casa vaia
	if time == 1:
		get_tree().create_timer(1.6, false).connect("timeout", Jogo, "tocar_grupo", ["vaia", "torcida_vaia", -2.0])
	else:
		get_tree().create_timer(2.2, false).connect("timeout", Jogo, "tocar_grupo", ["comemoracao", "", -3.0])
	Jogo.tocar("fogos", -4.0)
	get_tree().create_timer(0.5, false).connect("timeout", Jogo, "tocar", ["fogos", -6.0, 1.1])
	get_tree().create_timer(1.1, false).connect("timeout", Jogo, "tocar", ["fogos", -8.0, 0.9])
	_aviso("GOOOOL!", "%s  %s" % [Jogo.selecao(siglas[time]).nome, autor], _cor_banner(time), 3.4, true)
	_flash(Jogo.cor_camisa(siglas[time], uniformes[time]), 0.55)
	_tremer(0.5)
	torcida.pular(time, 1.0, 4.5)
	_soltar_confete(time)
	_fogos(time)
	# os botões de quem fez o gol pulam de alegria
	for b in botoes[time]:
		if b.ativo:
			var p = pecas[b]
			var tw := Tween.new()
			p.add_child(tw)
			tw.connect("tween_all_completed", tw, "queue_free")
			for k in range(3):
				tw.interpolate_property(p, "scale", Vector2.ONE, Vector2(1.25, 1.25), 0.18, Tween.TRANS_SINE, Tween.EASE_OUT, 0.4 + k * 0.4 + randf() * 0.1)
				tw.interpolate_property(p, "scale", Vector2(1.25, 1.25), Vector2.ONE, 0.18, Tween.TRANS_SINE, Tween.EASE_IN, 0.58 + k * 0.4 + randf() * 0.1)
			tw.start()
	lbl_gols[time].text = str(placar[time])
	_atualizar_agregado()
	# quem marcou fica embalado; a torcida e os bandeirões dele vão à loucura
	_comecar_embalo(time)
	Jogo.tocar("embalo", -4.0)
	_forca_bandeira[time] = 2.6
	get_tree().create_timer(5.0, false).connect("timeout", self, "_acalmar_bandeira", [time])
	UI.pulsar(lbl_gols[time], 0.6, 0.5)
	if tempo <= 0.0:
		_depois(4.2, "_fim_do_tempo", [])
	else:
		_depois(4.2, "_saida_de_bola", [1 - time])


func _acalmar_bandeira(time: int) -> void:
	_forca_bandeira[time] = 1.0


func _fim_do_tempo() -> void:
	if estado == FIM:
		return
	estado = FIM
	_mirando = null
	mira.esconder()
	_log("FIM DO %dº TEMPO  %d x %d" % [metade, placar[0], placar[1]])
	if metade == 1 or metade == 3:
		Jogo.tocar("apito_longo")
		_aviso("INTERVALO" if metade == 1 else "FIM DO 1º TEMPO DA PRORROGAÇÃO", "%s %d x %d %s  •  TROCA DE LADO" % [siglas[0], placar[0], placar[1], siglas[1]], Color(0.05, 0.1, 0.25, 0.8), 3.0)
		_depois(3.4, "_segundo_tempo", [])
	else:
		Jogo.tocar("apito_fim")
		var ag := _agregado()
		var empatou: bool = (placar[0] == placar[1]) if ag.empty() else (ag[0] == ag[1])
		if Jogo.partida.penaltis and empatou and metade == 2:
			# jogo que decide: empate vai para a PRORROGAÇÃO (2 tempos curtos)
			_aviso("PRORROGAÇÃO!", "EMPATE  •  MAIS DOIS TEMPOS", Color(0.45, 0.25, 0.02, 0.85), 3.0)
			Jogo.tocar("torcida_uuu", -4.0)
			_depois(3.4, "_prorrogacao", [])
		elif Jogo.partida.penaltis and empatou:
			_aviso("FIM DA PRORROGAÇÃO", "EMPATE: VAI PARA OS PÊNALTIS!", Color(0.05, 0.1, 0.25, 0.8), 3.0)
			_depois(3.2, "_iniciar_disputa", [])
		else:
			_aviso("FIM DE JOGO", "%s %d x %d %s" % [siglas[0], placar[0], placar[1], siglas[1]], Color(0.05, 0.1, 0.25, 0.8), 2.6)
			_depois(2.8, "_encerrar", [])


func _segundo_tempo() -> void:
	metade += 1
	# os times trocam de lado (goleiros, formação e gols vão junto)
	Campo.trocar_lados(metade == 2)
	tempo = _tempo_do_periodo()
	estado = PREPARO
	_saida_de_bola(1)


## Prorrogação: 2 tempos de 1/3 do tempo normal (no mínimo 1 minuto).
func _tempo_do_periodo() -> float:
	var normal := float(Jogo.config.minutos) * 60.0
	return normal if metade <= 2 else max(60.0, round(normal / 3.0))


func _prorrogacao() -> void:
	metade = 3
	Campo.trocar_lados(false)
	tempo = _tempo_do_periodo()
	estado = PREPARO
	_saida_de_bola(0)


# ======================================================= DISPUTA DE PÊNALTIS
func _iniciar_disputa() -> void:
	disputa = {"gols": [[], []], "vez": 0, "n": 0}
	painel_disputa.visible = true
	lbl_agregado.visible = false
	_atualizar_disputa()
	_proximo_penalti()


func _proximo_penalti() -> void:
	estado = PREPARO
	fisica.parar_tudo()
	var t: int = disputa.vez
	var def := 1 - t
	# só o cobrador e os goleiros na mesa (quem foi expulso não cobra)
	for tt in [0, 1]:
		for b in botoes[tt]:
			if not b.has_meta("na_disputa"):
				b.set_meta("na_disputa", b.ativo)
			b.ativo = false
			pecas[b].visible = false
	var elegiveis := []
	for b in botoes[t]:
		if b.get_meta("na_disputa"):
			elegiveis.append(b)
	var cob = elegiveis[(disputa.gols[t].size()) % elegiveis.size()]
	cob.ativo = true
	pecas[cob].visible = true
	var marca := Campo.marca_penalti(def)
	var dir := (Campo.centro_gol(def) - marca).normalized()
	bola.pos = marca
	pecas[bola].suave = 0.5
	cob.pos = marca - dir * (Campo.RAIO_BOTAO + Campo.RAIO_BOLA + 42.0)
	pecas[cob].position = cob.pos
	goleiros[def].pos = Vector2(_x_goleiro(def), Campo.CENTRO.y)
	penalti_cobrador = cob
	cobranca = "penalti"
	Jogo.tocar("rufar", -3.0)
	_aviso("PÊNALTI", "%s  -  cobrança %d" % [Jogo.selecao(siglas[t]).nome, disputa.gols[t].size() + 1], _cor_banner(t), 1.3)
	_depois(1.4, "_nova_vez", [t])


func _resolver_disputa() -> void:
	var t: int = disputa.vez
	var fez: bool = jogada.gol == t
	disputa.gols[t].append(fez)
	_log("PENALTI DISPUTA %s %s bola=%s gk=%s trave=%s" % [siglas[t], "GOL" if fez else "PERDEU", str(bola.pos), str(goleiros[1 - t].pos.y), str(jogada.trave)])
	if fez:
		placar_disputa_efeito(t)
	else:
		Jogo.tocar("torcida_uuu", -2.0)
		_aviso("PERDEU!", "", Color(0.3, 0.05, 0.05, 0.7), 1.2)
	_atualizar_disputa()
	var decidido := _disputa_decidida()
	disputa.vez = 1 - t
	if decidido >= 0:
		_depois(2.0, "_encerrar", [])
	else:
		_depois(2.0, "_proximo_penalti", [])


func placar_disputa_efeito(t: int) -> void:
	Jogo.tocar("rede")
	Jogo.tocar_grupo("gol", "torcida_gol", -2.0)
	torcida.pular(t, 0.9, 2.0)
	_aviso("GOL!", Jogo.selecao(siglas[t]).nome, _cor_banner(t), 1.3)
	_flash(Jogo.cor_camisa(siglas[t], uniformes[t]), 0.35)


func _gols_disputa(t: int) -> int:
	var n := 0
	for g in disputa.gols[t]:
		if g:
			n += 1
	return n


## -1 = ainda não; 0/1 = quem venceu.
func _disputa_decidida() -> int:
	var a := _gols_disputa(0)
	var b := _gols_disputa(1)
	var na: int = disputa.gols[0].size()
	var nb: int = disputa.gols[1].size()
	if na <= 5 and nb <= 5:
		if a > b + (5 - nb):
			return 0
		if b > a + (5 - na):
			return 1
		if na == 5 and nb == 5 and a != b:
			return 0 if a > b else 1
		return -1
	if na == nb and a != b:
		return 0 if a > b else 1
	return -1


func _atualizar_disputa() -> void:
	for t in [0, 1]:
		var est := []
		for g in disputa.gols[t]:
			est.append(2 if g else -1)
		for _i in range(max(0, 5 - disputa.gols[t].size())):
			est.append(0)
		# morte súbita: mostra só as últimas 10
		while est.size() > 10:
			est.pop_front()
		lbl_disputa[t].estados = est


# ================================================================== FIM
func _encerrar() -> void:
	if _encerrou:
		return
	_encerrou = true
	estado = FIM
	var pa := _gols_disputa(0) if not disputa.empty() else -1
	var pb := _gols_disputa(1) if not disputa.empty() else -1
	if not _pen_wo.empty():
		pa = _pen_wo[0]          # W.O. empatado em jogo que decide: sorteio
		pb = _pen_wo[1]
	var vencedor := -1
	var ag := _agregado()
	var conta: Array = placar if ag.empty() else ag
	if conta[0] != conta[1]:
		vencedor = 0 if conta[0] > conta[1] else 1
	elif pa >= 0:
		vencedor = 0 if pa > pb else 1
	var ida_da_copa: bool = Jogo.partida.modo == "copa" and not Jogo.partida.penaltis
	if ida_da_copa:
		# na ida ninguém é eliminado: vale o placar do jogo para a festa
		vencedor = -1 if placar[0] == placar[1] else (0 if placar[0] > placar[1] else 1)
	Jogo.ultimo_resultado = {"placar": placar.duplicate(), "penaltis": [pa, pb], "vencedor": vencedor}
	_log("RESULTADO %s %d x %d %s  pen %d x %d  faltas %d x %d  cartoes %s" % [siglas[0], placar[0], placar[1], siglas[1], pa, pb, faltas[0], faltas[1], str(cartoes)])
	if vencedor >= 0:
		torcida.pular(vencedor, 1.0, 8.0)
		_soltar_confete(vencedor)
		_fogos(vencedor)
	# fim de jogo: o mandante perdeu -> vaia; ganhou -> comemoração
	var perdeu_casa: bool = vencedor == 1 or (vencedor < 0 and placar[1] > placar[0])
	if perdeu_casa:
		Jogo.tocar_grupo("vaia", "torcida_vaia", 0.0)
	elif vencedor == 0 or placar[0] > placar[1]:
		Jogo.tocar_grupo("comemoracao", "torcida_gol", -2.0)
	Jogo.musica_fundo(-4.0, true)
	_tela_final(vencedor, pa, pb)


func _tela_final(vencedor: int, pa: int, pb: int) -> void:
	_botoes_finais = []
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.anchor_right = 1
	fundo.anchor_bottom = 1
	hud.add_child(fundo)
	var p := UI.painel(Jogo.AMARELO, Color(0.02, 0.05, 0.12, 0.95), 24, 3, 22)
	UI.colocar(p, 290, 110, 700, 500)
	hud.add_child(p)
	UI.pop(p, 0.1)
	var titulo := "EMPATE!"
	var cor := Color.white
	var ag := _agregado()
	var copa: bool = Jogo.partida.modo == "copa"
	var fase: String = Jogo.partida.get("fase", "")
	if copa and Jogo.partida.penaltis and vencedor >= 0:
		var ganhou = {"final": "CAMPEÃO!", "terceiro": "3º LUGAR!"}.get(fase, "CLASSIFICADO!")
		var perdeu = {"final": "VICE-CAMPEÃO", "terceiro": "4º LUGAR"}.get(fase, "ELIMINADO")
		if humano[0] and humano[1]:
			titulo = Jogo.selecao(siglas[vencedor]).nome + " " + {"final": "CAMPEÃO!", "terceiro": "É 3º!"}.get(fase, "PASSA!")
			cor = Jogo.AMARELO
		else:
			var eu := 0 if humano[0] else 1
			titulo = ganhou if vencedor == eu else perdeu
			cor = Jogo.AMARELO if vencedor == eu else Color(1, 0.5, 0.45)
	elif vencedor >= 0:
		if humano[vencedor] and not humano[1 - vencedor]:
			titulo = "VITÓRIA!"
			cor = Jogo.AMARELO
		elif humano[1 - vencedor] and not humano[vencedor]:
			titulo = "DERROTA"
			cor = Color(1, 0.5, 0.45)
		else:
			titulo = Jogo.selecao(siglas[vencedor]).nome + " VENCE!"
			cor = Jogo.AMARELO
	var lt := UI.label(titulo, Jogo.fonte("titan", 64 if titulo.length() <= 13 else 44, 6), cor)
	UI.colocar(lt, 0, 18, 700, 90)
	p.add_child(lt)
	for t in [0, 1]:
		var band := TextureRect.new()
		band.texture = Jogo.bandeira(siglas[t])
		band.expand = true
		band.stretch_mode = TextureRect.STRETCH_SCALE
		UI.colocar(band, 70 if t == 0 else 700 - 70 - 150, 130, 150, 100)
		p.add_child(band)
		var nome := UI.label(Jogo.selecao(siglas[t]).nome, Jogo.fonte("bungee", 20, 2), Color.white)
		UI.colocar(nome, 20 if t == 0 else 700 - 20 - 250, 236, 250, 30)
		p.add_child(nome)
	var pl := UI.label("%d  x  %d" % [placar[0], placar[1]], Jogo.fonte("titan", 72, 6), Color.white)
	UI.colocar(pl, 200, 130, 300, 100)
	p.add_child(pl)
	if pa >= 0:
		var lp := UI.label("pênaltis  %d x %d" % [pa, pb], Jogo.fonte("bungee", 22, 2), Jogo.AMARELO)
		UI.colocar(lp, 200, 226, 300, 34)
		p.add_child(lp)
	var est := UI.label("Faltas  %d x %d     Cartões  %d x %d" % [faltas[0], faltas[1], cartoes[0][0] + cartoes[0][1], cartoes[1][0] + cartoes[1][1]], Jogo.fonte("texto", 20, 1), Color(0.85, 0.9, 1.0))
	UI.colocar(est, 0, 282, 700, 30)
	p.add_child(est)
	if copa:
		var info := ""
		if fase == "terceiro":
			info = "DECISÃO DO 3º LUGAR  •  JOGO ÚNICO"
		elif ag.empty():
			info = "JOGO DE IDA  •  a volta é no %s" % Jogo.selecao(siglas[1]).estadio
		else:
			info = "AGREGADO  %s %d x %d %s" % [siglas[0], ag[0], ag[1], siglas[1]]
		var li := UI.label(info, Jogo.fonte("bungee", 19, 2), Jogo.AMARELO)
		UI.colocar(li, 0, 318, 700, 32)
		p.add_child(li)
	# meio segundo para o aperto que terminou a partida não pular a tela
	get_tree().create_timer(0.8, false).connect("timeout", self, "_liberar_tela_final")
	# totem: se ninguém tocar, volta sozinho para a abertura
	get_tree().create_timer(180.0 if Jogo.partida.modo == "copa" else 60.0, false).connect("timeout", self, "_abandonado")
	if Jogo.partida.modo == "copa":
		_botao(p, "CONTINUAR", Vector2(200, 380), Vector2(300, 80), "_continuar_copa", Jogo.VERDE)
	else:
		_botao(p, "REVANCHE", Vector2(60, 380), Vector2(270, 80), "_revanche", Jogo.VERDE)
		_botao(p, "MENU", Vector2(370, 380), Vector2(270, 80), "_ir_menu", Jogo.AZUL)


var _tela_final_pronta := false
var _botoes_finais := []


func _confirmar_tela_final() -> void:
	for b in _botoes_finais:
		if is_instance_valid(b) and b.has_focus():
			b.emit_signal("pressed")
			return
	if not _botoes_finais.empty() and is_instance_valid(_botoes_finais[0]):
		_botoes_finais[0].emit_signal("pressed")


func _liberar_tela_final() -> void:
	_tela_final_pronta = true


func _botao(pai: Control, txt: String, pos: Vector2, tam: Vector2, metodo: String, cor: Color) -> Button:
	var b := UI.botao(txt, cor, Jogo.fonte("titan", 32, 3))
	b.rect_position = pos
	b.rect_size = tam
	b.connect("pressed", self, metodo)
	pai.add_child(b)
	_botoes_finais.append(b)
	# o primeiro botão já vem escolhido (manche: CHUTE confirma)
	if pai.get_meta("focou") if pai.has_meta("focou") else false:
		return b
	pai.set_meta("focou", true)
	b.call_deferred("grab_focus")
	return b


var _saiu_da_tela_final := false


func _continuar_copa() -> void:
	# UMA vez só: apertar duas vezes (ou as duas placas juntas) registrava o
	# resultado de novo e a Copa contava como o jogo de volta
	if _saiu_da_tela_final:
		return
	_saiu_da_tela_final = true
	Jogo.tocar("confirma")
	var r: Dictionary = Jogo.ultimo_resultado
	# a Copa guarda casa/fora desta partida (ida ou volta)
	Jogo.copa_registrar(r.placar[0], r.placar[1], r.penaltis[0], r.penaltis[1])
	Jogo.ir_para("res://cenas/chave.tscn")


func _abandonado() -> void:
	if not Jogo.trocando() and is_inside_tree():
		Jogo.ambiente(0.0)
		Jogo.copa = {}
		Jogo.ir_para("res://cenas/abertura.tscn")


func _revanche() -> void:
	if _saiu_da_tela_final:
		return
	_saiu_da_tela_final = true
	Jogo.tocar("confirma")
	Jogo.ir_para("res://cenas/partida.tscn")


func _ir_menu() -> void:
	if _saiu_da_tela_final:
		return
	_saiu_da_tela_final = true
	Jogo.tocar("volta")
	Jogo.ambiente(0.0)
	Jogo.ir_para("res://cenas/menu.tscn")


# ================================================================ PAUSA
func _pausar() -> void:
	if _pausado or _encerrou:
		return
	_pausado = true
	Jogo.tocar("clique")
	get_tree().paused = true
	var camada := CanvasLayer.new()
	camada.layer = 50
	camada.pause_mode = Node.PAUSE_MODE_PROCESS
	camada.name = "Pausa"
	add_child(camada)
	var f := ColorRect.new()
	f.color = Color(0, 0, 0, 0.6)
	f.anchor_right = 1
	f.anchor_bottom = 1
	camada.add_child(f)
	var p := UI.painel(Jogo.CIANO, Color(0.02, 0.05, 0.12, 0.95), 24, 3, 18)
	UI.colocar(p, 390, 180, 500, 360)
	camada.add_child(p)
	var l := UI.label("PAUSA", Jogo.fonte("titan", 60, 5), Color.white)
	UI.colocar(l, 0, 16, 500, 80)
	p.add_child(l)
	_botao(p, "CONTINUAR", Vector2(80, 120), Vector2(340, 84), "_despausar", Jogo.VERDE)
	_botao(p, "SAIR DO JOGO", Vector2(80, 230), Vector2(340, 84), "_sair_da_partida", Jogo.VERMELHO)


func _despausar() -> void:
	Jogo.tocar("clique")
	var c := get_node_or_null("Pausa")
	if c:
		c.queue_free()
	get_tree().paused = false
	_pausado = false


func _sair_da_partida() -> void:
	get_tree().paused = false
	_pausado = false
	Jogo.ambiente(0.0)
	Jogo.tocar("volta")
	if Jogo.partida.modo == "copa":
		Jogo.copa = {}
	Jogo.ir_para("res://cenas/menu.tscn")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST or what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		_pausar()


# ================================================================ TOQUE
## QUALIDADE AUTOMÁTICA DA PARTIDA: se a TV box não segura ~48 quadros por
## segundo, o quadro da mesa passa a ser desenhado em 720p (menos da metade
## dos pixels) e a escolha fica salva para as próximas partidas.
func _medir_quadro(delta: float) -> void:
	if _vp_mesa == null or _t < 2.5 or _medidas.size() > 60:
		return
	_medidas.append(delta)
	if _medidas.size() == 60:
		var lista := _medidas.duplicate()
		lista.sort()
		var mediana: float = lista[30]
		if mediana > Qualidade3D.limite() and _vp_mesa.size.x > Perspectiva.TAM.x:
			_mesa_leve()
			var c := ConfigFile.new()
			c.set_value("2d", "mesa_leve", true)
			c.save(ARQ_QUALIDADE)
			_log("QUALIDADE mesa em 720p (quadro %.1f ms)" % (mediana * 1000.0))


func _mesa_leve() -> void:
	_vp_mesa.size = Perspectiva.TAM
	_vp_mesa.canvas_transform = Transform2D()


static func _mesa_leve_salva() -> bool:
	var c := ConfigFile.new()
	return c.load(ARQ_QUALIDADE) == OK and bool(c.get_value("2d", "mesa_leve", false))


## Toque na tela -> ponto da mesa (com perspectiva, desfaz a câmera).
func _na_mesa(p: Vector2) -> Vector2:
	return Perspectiva.para_mesa(p) if perspectiva else p


## Ponto da mesa -> tela (textos que sobem em cima da jogada).
func _na_tela(p: Vector2) -> Vector2:
	return Perspectiva.para_tela(p) if perspectiva else p


func _unhandled_input(ev: InputEvent) -> void:
	if _pausado:
		return
	if ev is InputEventMouseButton and ev.button_index == BUTTON_LEFT:
		if ev.pressed:
			_toque_inicio(_na_mesa(ev.position))
		else:
			_toque_fim(_na_mesa(ev.position))
	elif ev is InputEventMouseMotion and _mirando != null:
		_toque_mover(_na_mesa(ev.position))
	elif ev is InputEventKey and ev.pressed and ev.scancode == KEY_ESCAPE:
		_pausar()


func _toque_inicio(p: Vector2) -> void:
	if estado != VEZ or not humano[vez]:
		return
	var melhor = null
	var md := Campo.RAIO_BOTAO * TOQUE_ALCANCE
	for b in botoes[vez]:
		if not _pode_jogar(b):
			continue
		var d: float = b.pos.distance_to(p)
		if d < md:
			md = d
			melhor = b
	if melhor == null:
		return
	# o toque manda: a seleção do manche passa para o botão tocado
	carregando[vez] = false
	if sel[vez] != null and pecas.has(sel[vez]):
		pecas[sel[vez]].selecionado = false
	sel[vez] = melhor
	pecas[melhor].selecionado = true
	_mirando = melhor
	_toque_mover(p)


func _forca_do_toque(b, p: Vector2) -> Array:
	var o: Vector2 = p - b.pos
	var dist := o.length()
	var f := clamp(dist / Campo.RAIO_BOTAO, 0.0, 1.0)
	var dir := -o / dist if dist > 0.5 else Vector2(Campo.sentido(b.time), 0)
	var v: float = lerp(VMIN, _vmax(b.time), pow(f, 1.25))
	return [dir, f, v, dist]


func _toque_mover(p: Vector2) -> void:
	if _mirando == null:
		return
	var r := _forca_do_toque(_mirando, p)
	if r[3] > Campo.RAIO_BOTAO * TOQUE_CANCELA:
		mira.esconder()
		dica.text = "Solte aqui para desistir"
		return
	dica.text = ""
	mira.mostrar(_mirando.pos, r[0], r[1], r[2], p)


func _toque_fim(p: Vector2) -> void:
	if _mirando == null:
		return
	var b = _mirando
	_mirando = null
	var r := _forca_do_toque(b, p)
	if r[3] > Campo.RAIO_BOTAO * TOQUE_CANCELA or estado != VEZ:
		mira.esconder()
		dica.text = ""
		if estado == VEZ and humano[vez] and b.ativo:
			_selecionar(vez, b)          # desistiu: volta a mira do manche
		return
	_primeiro_toque_humano = false
	_chutar(b, r[0] * r[2])


# =================================================================== CPU
func _cpu_pensar(delta: float) -> void:
	if _cpu.empty():
		return
	_cpu.t += delta
	# 1) a conta da jogada roda noutra linha de execução (a tela não para)
	if not _cpu.has("rodando"):
		# a conta de uma vez anterior (a vez mudou no meio) ainda rodando: espera
		if _thread != null:
			if _thread.is_alive():
				# conta antiga ainda rodando: espera no máximo 1,2 s e joga o simples
				if _cpu.t > 1.2:
					_cpu.rodando = true
					_cpu.decisao = _decisao_simples()
					_log("CPU: conta antiga presa, jogada simples")
				return
			_thread.wait_to_finish()
			_thread = null
		var ctx := {"time": vez, "bola": bola, "corpos": fisica.corpos, "toques_restantes": int(Jogo.config.toques) - toques,
			"dificuldade": int(Jogo.config.dificuldade), "forca": forca_time[vez], "vmax": _vmax(vez),
			"erro": Jogo.parametros(siglas[vez], embalo[vez] > 0.0).erro_cpu,
			"penalti": penalti_cobrador if cobranca == "penalti" else null,
			"fixo": _cobrador_fixo() if cobranca != "penalti" else null}
		if not disputa.empty():
			ctx.dificuldade = max(1, ctx.dificuldade)
		if cobranca == "penalti":
			# a CPU mira onde o goleiro NÃO vai estar quando a bola chegar
			ctx["goleiro_y"] = _goleiro_penalti_y(_t + max(0.0, _cpu.pensar - _cpu.t) + 1.45)
		_cpu.rodando = true
		_cpu.t0 = OS.get_ticks_usec()
		_thread = Thread.new()
		if _thread.start(self, "_pensar_em_paralelo", ctx) != OK:
			_cpu.decisao = IA.decidir(ctx)
			_thread = null
		else:
			_cpu.minha = true          # a conta desta vez
		return
	if _cpu.has("minha") and _thread != null and not _thread.is_alive():
		_cpu.decisao = _thread.wait_to_finish()
		_thread = null
		_cpu.erase("minha")
		_log("CPU pensou em %.1f ms" % ((OS.get_ticks_usec() - _cpu.t0) / 1000.0))
		if not _cpu.decisao.empty():
			_log("CPU decide %s alvo=%s vel=%s" % [_cpu.decisao.tipo, str(_cpu.decisao.alvo), str(_cpu.decisao.vel)])
	if _cpu.has("minha") and _cpu.t > _cpu.pensar + 1.2:
		# a conta está demorando (TV box ocupada): joga o simples e o resultado
		# atrasado é descartado (a vez não espera)
		_cpu.erase("minha")
		_cpu.decisao = _decisao_simples()
		_log("CPU: conta lenta, jogada simples")
	if _cpu.has("minha") or _cpu.t < _cpu.pensar:
		return
	var d: Dictionary = _cpu.decisao
	if d.empty() or not is_instance_valid(d.botao) or not d.botao.ativo:
		d = _decisao_simples()
		_cpu.decisao = d
	if d.empty():
		_cpu = {}
		_depois(0.3, "_passar_vez", [vez])
		return
	# 2) mostra a jogada como um jogador: escolhe, gira a seta, enche a barra
	if not _cpu.has("inicio_mira"):
		_cpu.inicio_mira = _cpu.t
		pecas[d.botao].selecionado = true
		_cpu.ang0 = (bola.pos - d.botao.pos).angle()
		Jogo.tocar("clique", -10.0)
	var k: float = _cpu.t - _cpu.inicio_mira
	var v: Vector2 = d.vel
	var vmax := _vmax(vez)
	var f := clamp(pow(max(v.length() - VMIN, 0.0) / (vmax - VMIN), 1.0 / 1.1), 0.0, 1.0)
	var giro: float = clamp(k / 0.4, 0.0, 1.0)
	var a := lerp_angle(_cpu.ang0, v.angle(), giro)
	var carga: float = clamp((k - 0.4) / 0.8, 0.0, 1.0) * f
	mira.mostrar(d.botao.pos, Vector2(cos(a), sin(a)), carga, _velocidade_da_forca(vez, max(carga, 0.04)) if k > 0.4 else lerp(VMIN, vmax, 0.45), null, k > 0.4)
	if k >= 1.2:
		pecas[d.botao].selecionado = false
		_cpu = {}
		_chutar(d.botao, v)


func _pensar_em_paralelo(ctx: Dictionary) -> Dictionary:
	return IA.decidir(ctx)


## Jogada de reserva da CPU (instantânea): o cobrador (ou o tazo mais perto
## da bola) bate na bola na direção do gol adversário, com força média.
func _decisao_simples() -> Dictionary:
	var b = _cobrador_fixo()
	if b == null:
		var lista := _lista_escolha(vez)
		if lista.empty():
			return {}
		b = lista[0]
	var gol := Campo.centro_gol(1 - vez)
	var para_gol: Vector2 = (gol - bola.pos).normalized()
	# encosta atrás da bola, do lado contrário ao gol
	var ponto: Vector2 = bola.pos - para_gol * (Campo.RAIO_BOLA + Campo.RAIO_BOTAO) * 0.6
	var dir: Vector2 = (ponto - b.pos).normalized()
	if dir == Vector2.ZERO:
		dir = para_gol
	var v: float = lerp(VMIN, _vmax(vez), 0.62)
	return {"tipo": "simples", "botao": b, "vel": dir * v, "alvo": bola.pos}


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
	Campo.trocar_lados(false)
	Campo.definir_piso(1.0)
	Jogo.som_clima("")


# ============================================================ GOLEIROS
func _posicionar_goleiros(delta: float) -> void:
	for t in [0, 1]:
		var g = goleiros[t]
		var lim: float = Campo.GOL_MEIA - g.meio * 0.55
		var antes: float = g.pos.y
		var vel: float = params[t].goleiro_vel
		var mov := 0.0
		if t != vez and humano[t]:
			if Controles.segurando(controle[t], "cima"):
				mov -= 1.0
			if Controles.segurando(controle[t], "baixo"):
				mov += 1.0
			if mov != 0.0:
				goleiro_manual[t] = true
		if goleiro_manual[t]:
			# o adversário controla o próprio goleiro na vez do outro (CIMA/BAIXO);
			# soltou: ele fica onde foi deixado (quem só usa o toque tem o automático)
			if mov == 0.0:
				continue
			g.pos.y = clamp(g.pos.y + mov * vel * 1.25 * delta, Campo.CENTRO.y - lim, Campo.CENTRO.y + lim)
		elif cobranca == "penalti" and t != vez:
			# CPU no pênalti: o goleiro fica balançando (acerte o canto na hora certa!)
			g.pos.y = _goleiro_penalti_y(_t)
			continue
		else:
			var alvo_y: float = Campo.CENTRO.y + clamp((bola.pos.y - Campo.CENTRO.y) * 0.5, -lim, lim)
			g.pos.y = move_toward(g.pos.y, alvo_y, vel * delta)
		# não entra por cima da bola nem de botões
		for c in fisica.corpos:
			if c == g or not c.ativo:
				continue
			if g.ponto_perto(c.pos).distance_to(c.pos) < g.raio + c.raio:
				g.pos.y = antes
				break


## Onde o goleiro balançando do pênalti está no instante "quando".
func _goleiro_penalti_y(quando: float) -> float:
	var vel := 1.5 + float(Jogo.config.dificuldade) * 0.35
	return Campo.CENTRO.y + sin(quando * vel) * (Campo.GOL_MEIA - 16.0) * 0.85


# ============================================================== AJUDAS
func _mais_perto(time: int, p: Vector2):
	var melhor = null
	var md := 1e9
	for b in botoes[time]:
		if not b.ativo:
			continue
		var d: float = b.pos.distance_to(p)
		if d < md:
			md = d
			melhor = b
	return melhor


## Nenhum tazo dentro do gol: o que ficou atrás da linha, entre as redes,
## vai para a frente da boca do gol (senão ficava preso lá dentro).
func _fora_do_gol(b) -> bool:
	if not b.ativo or b.tipo != Corpo.BOTAO:
		return false
	var r: float = b.raio
	if abs(b.pos.y - Campo.CENTRO.y) > Campo.GOL_MEIA + r + Campo.RAIO_TRAVE:
		return false
	for l in [0, 1]:
		var x := Campo.x_gol_do_lado(l)
		var para_dentro := 1.0 if l == 0 else -1.0
		var fundo: float = (b.pos.x - x) * para_dentro
		if fundo < (r if abs(b.pos.y - Campo.CENTRO.y) <= Campo.GOL_MEIA else 0.0) and fundo > -Campo.GOL_FUNDO - r - 8.0:
			b.pos.x = x + para_dentro * (r + 3.0)
			b.vel = Vector2.ZERO
			if pecas.has(b):
				pecas[b].suave = 0.7
			return true
	return false


## Separa peças que ficaram umas em cima das outras depois de posicionar.
func _desencavalar(fixos := []) -> void:
	for t in [0, 1]:
		for b in botoes[t]:
			_fora_do_gol(b)
	for _it in range(12):
		var mexeu := false
		for a in fisica.corpos:
			if not a.ativo or a.tipo == Corpo.GOLEIRO:
				continue
			for b in fisica.corpos:
				if a == b or not b.ativo:
					continue
				var q: Vector2 = b.ponto_perto(a.pos)
				var d: Vector2 = a.pos - q
				var minimo: float = a.raio + b.raio + 2.0
				if d.length() < minimo:
					if a == bola or a in fixos:
						continue
					var n := d.normalized() if d.length() > 0.5 else Vector2(0, 1).rotated(randf() * TAU)
					a.pos = q + n * minimo
					a.pos.x = clamp(a.pos.x, Campo.MURO.position.x + a.raio, Campo.MURO.end.x - a.raio)
					a.pos.y = clamp(a.pos.y, Campo.MURO.position.y + a.raio, Campo.MURO.end.y - a.raio)
					if pecas.has(a):
						pecas[a].suave = 0.7
					mexeu = true
		if not mexeu:
			break
	for t in [0, 1]:
		for b in botoes[t]:
			_fora_do_gol(b)


## Registro de eventos para os testes automáticos (só com BOTAO_LOG).
func _log(m: String) -> void:
	if OS.has_environment("BOTAO_LOG"):
		print("[JOGO %5.1f] %s" % [_t, m])


func _depois(seg: float, metodo: String, args := []) -> void:
	var tm := get_tree().create_timer(seg, false)
	tm.connect("timeout", self, metodo, args)


func _cor_banner(time: int) -> Color:
	var c := Jogo.cor_camisa(siglas[time], uniformes[time])
	return Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, 0.82)


func _aviso(txt: String, sub: String, cor: Color, dur: float, grande := false) -> void:
	banner.visible = true
	banner_txt.text = txt
	banner_sub.text = sub
	banner_fundo.color = cor
	banner_txt.add_font_override("font", Jogo.fonte("titan", 110 if grande else 76, 7))
	banner.rect_pivot_offset = Vector2(640, 75)
	var tw := Tween.new()
	banner.add_child(tw)
	tw.connect("tween_all_completed", tw, "queue_free")
	tw.interpolate_property(banner, "rect_scale", Vector2(1.0, 0.0), Vector2.ONE, 0.25, Tween.TRANS_BACK, Tween.EASE_OUT)
	tw.interpolate_property(banner, "modulate:a", 0.0, 1.0, 0.15)
	tw.interpolate_property(banner_txt, "rect_scale", Vector2(1.6, 1.6), Vector2.ONE, 0.4, Tween.TRANS_BACK, Tween.EASE_OUT)
	banner_txt.rect_pivot_offset = Vector2(640, 55)
	tw.interpolate_property(banner, "modulate:a", 1.0, 0.0, 0.25, Tween.TRANS_SINE, Tween.EASE_IN, dur)
	tw.interpolate_callback(self, dur + 0.26, "_esconder_banner", txt)
	tw.start()
	Jogo.tocar("swoosh", -8.0)


func _esconder_banner(txt: String) -> void:
	if banner_txt.text == txt:
		banner.visible = false


func _flash(cor: Color, forca: float) -> void:
	flash.color = Color(cor.r, cor.g, cor.b, forca)
	flash.visible = true


func _tremer(dur: float) -> void:
	var tw := Tween.new()
	mesa.add_child(tw)
	tw.connect("tween_all_completed", tw, "queue_free")
	var passos := 8
	for i in range(passos):
		var k := 1.0 - float(i) / passos
		tw.interpolate_property(mesa, "position", mesa.position, Vector2(rand_range(-9, 9), rand_range(-7, 7)) * k, dur / passos, Tween.TRANS_SINE, Tween.EASE_OUT, i * dur / passos)
	tw.interpolate_property(mesa, "position", Vector2.ZERO, Vector2.ZERO, 0.01, Tween.TRANS_LINEAR, Tween.EASE_IN, dur)
	tw.start()


## A rede estufa para fora com a bola e balança até parar (como na abertura).
func _rede_balanca(lado: int) -> void:
	_rede_bal[lado] = 0.0


func _animar_redes(delta: float) -> void:
	for lado in [0, 1]:
		if _rede_bal[lado] < 0.0:
			continue
		var u: float = _rede_bal[lado] + delta
		var bal := 0.0
		if u < 1.8:
			bal = max(exp(-u * 3.0) * cos(u * 12.0), -0.2)
			_rede_bal[lado] = u
		else:
			_rede_bal[lado] = -1.0
		var r: Sprite = redes[lado]
		r.scale.x = 0.5 * (1.0 + 0.35 * bal)
		# estufa para fora do campo: as traves (a boca do gol) ficam no lugar
		r.position.x = _rede_base[lado].x
		if lado == 0:
			r.position.x -= r.texture.get_width() * (r.scale.x - 0.5)


func _soltar_confete(time: int) -> void:
	var u: Array = Jogo.selecao(siglas[time]).torcida
	for i in range(2):
		var c: CPUParticles2D = confete[i]
		c.color = Color(u[i])
		c.emitting = true
	get_tree().create_timer(2.5, false).connect("timeout", self, "_parar_confete")


func _parar_confete() -> void:
	for c in confete:
		c.emitting = false


func _fogos(time: int) -> void:
	var u: Array = Jogo.selecao(siglas[time]).torcida
	for k in range(6):
		var f := CPUParticles2D.new()
		f.texture = Jogo._tex("res://imagens/estrela.png")
		f.material = _aditivo
		f.amount = 28
		f.one_shot = true
		f.explosiveness = 0.95
		f.lifetime = 1.1
		f.spread = 180
		f.gravity = Vector2(0, 60)
		f.initial_velocity = 170
		f.initial_velocity_random = 0.4
		f.damping = 60
		f.scale_amount = 0.22
		f.scale_amount_random = 0.4
		f.color = Color(u[k % 2]).lightened(0.2)
		var lado := 0 if time == 0 else 1
		var x := rand_range(60, 600) if lado == 0 else rand_range(680, 1220)
		f.position = Vector2(x, rand_range(20, 70))
		f.emitting = false
		hud.add_child(f)
		get_tree().create_timer(0.15 + k * 0.35, false).connect("timeout", f, "restart")
		get_tree().create_timer(3.0 + k * 0.35, false).connect("timeout", f, "queue_free")


func _faisca(p: Vector2) -> void:
	var s := Sprite.new()
	s.texture = Jogo._tex("res://imagens/estrela.png")
	s.material = _aditivo
	s.position = p
	s.scale = Vector2(0.45, 0.45)
	mesa.add_child(s)
	var tw := Tween.new()
	s.add_child(tw)
	tw.interpolate_property(s, "scale", Vector2(0.2, 0.2), Vector2(0.6, 0.6), 0.2)
	tw.interpolate_property(s, "modulate:a", 1.0, 0.0, 0.25)
	tw.interpolate_callback(s, 0.26, "queue_free")
	tw.start()


func _atualizar_rastro() -> void:
	var v: float = bola.vel.length()
	if v > 260.0 and estado == MOVENDO:
		rastro.add_point(bola.pos)
		while rastro.get_point_count() > 12:
			rastro.remove_point(0)
	elif rastro.get_point_count() > 0:
		rastro.remove_point(0)


func _agregado() -> Array:
	var ida: Dictionary = Jogo.partida.get("ida", {})
	if ida.empty():
		return []
	return [placar[0] + int(ida.get(siglas[0], 0)), placar[1] + int(ida.get(siglas[1], 0))]


func _atualizar_agregado() -> void:
	var ag := _agregado()
	lbl_agregado.visible = not ag.empty()
	if not ag.empty():
		lbl_agregado.text = "AGREGADO  %s %d x %d %s" % [siglas[0], ag[0], ag[1], siglas[1]]


func _atualizar_hud() -> void:
	if lbl_tempo == null:
		return
	if disputa.empty():
		var s := int(ceil(tempo))
		var per := ("%dºT" % metade) if metade <= 2 else ("PR%d" % (metade - 2))
		lbl_tempo.text = "%s   %02d:%02d" % [per, s / 60, s % 60]
	else:
		lbl_tempo.text = "PÊNALTIS"
	for t in [0, 1]:
		var minha: bool = (estado == VEZ or estado == MOVENDO) and vez == t
		var txt := ""
		if estado == VEZ and vez == t:
			if humano[t]:
				txt = "SUA VEZ!" if not (humano[0] and humano[1]) else "VEZ DO %s" % ("JOGADOR 1" if t == 0 else "JOGADOR 2")
			else:
				txt = "CPU JOGANDO..."
		lbl_vez[t].text = txt
		var est2 := []
		if minha and disputa.empty() and cobranca != "penalti":
			for i in range(int(Jogo.config.toques)):
				est2.append(1 if i < toques else 0)
		lbl_toques[t].estados = est2
		var bv: ColorRect = barra_vez[t]
		if estado == VEZ and vez == t:
			var k: float = clamp(relogio_vez / float(Jogo.config.relogio_vez), 0.0, 1.0)
			bv.rect_size.x = 302.0 * k
			bv.visible = true
			bv.color = Jogo.cor_camisa(siglas[t], uniformes[t]) if relogio_vez > 5.0 else Jogo.VERMELHO
		else:
			bv.visible = false
		caixa_time[t].modulate.a = 1.0 if minha else 0.6
