extends Control

## PREPARAÇÃO DA PARTIDA (cutscene). O estádio do mandante em 3D
## (estadio3d.gd), com o clima da partida, e por cima os textos da
## transmissão. Antes do show, o palco 3D (palco3d.gd) prepara tudo atrás da
## capa (shaders, texturas, qualidade certa para a TV box): o show nunca
## engasga. Depois é uma linha do tempo só (_t), com a câmera num VOO
## CONTÍNUO, sem corte nenhum:
##   0.0  a cidade e o estádio (cartão-postal); terço inferior com o nome do
##        estádio, mandante, lugares e clima
##   4.3  mergulho por cima da arquibancada; a torcida e os bandeirões
##   9.4  rente aos tazos perfilados até a bola
##   C    a câmera da TV; faixa do confronto (as duas metades com as cores
##        dos times entram dos lados, escudos firmes, "VS" suave, um brilho
##        atravessa); confete e torcida em festa
##  C+0.9 estatísticas lado a lado num painel de vidro; na volta, a ida
##  C+2.8 contagem em anel "A PARTIDA COMEÇA EM 3, 2, 1" e a partida começa
##        (C+5.6). Tudo entra rápido e firme: nada de montagem arrastada.
## O BOTÃO (ou toque) pula direto para o jogo.

const UI = preload("res://scripts/ui.gd")

const FASES := {"quartas": "QUARTAS DE FINAL", "semi": "SEMIFINAL", "final": "FINAL", "terceiro": "DECISÃO DO 3º LUGAR"}
const CLIMAS := {"sol": "DIA DE SOL", "chuva": "DIA DE CHUVA", "noite": "NOITE DE LUA", "noite_chuva": "NOITE COM CHUVA"}
const ATRIB := [["chute", "CHUTE"], ["controle", "CONTROLE"], ["defesa", "DEFESA"]]
const Y_CONTA := 676.0             # linha da contagem e da dica (embaixo)
const Y_ESCUDO := 252.0
const TAM_ESCUDO := 168.0
const FAIXA := [150.0, 412.0]      # topo e base da faixa do confronto
const X_ESCUDO := [330.0, 950.0]
const Estadio3D = preload("res://scripts/estadio3d.gd")
const Palco3D = preload("res://scripts/palco3d.gd")
const HudTV = preload("res://scripts/hud_tv.gd")
const CONFETE = preload("res://imagens/confete.png")
const EscolhaEstadio = preload("res://scripts/escolha_estadio.gd")

var C := 12.3               # a câmera chegou na TV: entra o confronto
var FIM_AUTO := C + 5.6
var T_CONTA := C + 2.8
var _d := 0.0               # atraso do terço inferior (o voo diz quando a cidade aparece)
var _t_terco_fim := 5.5
var _postal: Label
var _t := 0.0
var _vivo := 0.0
var _comecou := false
var _i_vitrine := 0
var _confete_vitrine: CPUParticles2D
var _saindo := false
var _palco
var _terco: Control
var _caixa_terco: StyleBoxFlat
var _caixa_vidro: StyleBoxFlat
var _caixa_faixa: StyleBoxFlat
var _barra_fundo: StyleBoxFlat
var _barra_cheia: StyleBoxFlat
var _anel: Control
var _num: Label
var _dica: Label
var _emb_local: Texture
var _largura_terco := 900.0
var _sons := {}
var _casa := ""
var _fora := ""

var _estadio                # estádio 3D
var _escuro: ColorRect
var _hud                   # HUD de transmissão (hud_tv.gd)
var _topo := []            # textos nas faixas de cima
var _nome_estadio: Label
var _sub_estadio: Label
var _linha_ouro: ColorRect
var _escudos := []
var _faixa: Control
var _nomes := []
var _papeis := []
var _vs: Label
var _clarao: ColorRect
var _barras: Control
var _ida: Label
var _chamada: Label
var _raiz: Control


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var p: Dictionary = Jogo.partida
	_casa = p.casa
	_fora = p.fora
	# o estádio 3D tem o seu próprio quadro 3D (a tela do jogo é só 2D);
	# o palco prepara tudo escondido antes do show
	_palco = Palco3D.new()
	_palco.criar(self)
	_estadio = Estadio3D.new()
	_palco.vp.add_child(_estadio)
	var local := Jogo.local_da_partida()
	_estadio.montar(_casa, _fora, p.get("clima", "sol"), {"estadio": local})
	C = _estadio.t_tv + 0.1
	FIM_AUTO = C + 5.6
	T_CONTA = C + 2.8
	_d = _estadio.t_terco_ini - 0.7
	_t_terco_fim = _estadio.t_terco_fim
	_raiz = Control.new()
	_raiz.mouse_filter = MOUSE_FILTER_IGNORE
	_raiz.rect_size = Vector2(1280, 720)
	add_child(_raiz)

	_escuro = ColorRect.new()
	_escuro.color = Color(0.01, 0.02, 0.05, 0.0)
	_escuro.rect_size = Vector2(1280, 720)
	_escuro.mouse_filter = MOUSE_FILTER_IGNORE
	_raiz.add_child(_escuro)

	# terço inferior: estádio e fase
	var s_casa = Jogo.selecao(_casa)
	var s_local = Jogo.selecao(local)
	_emb_local = Jogo.emblema(local)
	_terco = Control.new()
	_terco.mouse_filter = MOUSE_FILTER_IGNORE
	_terco.rect_size = Vector2(1280, 720)
	_terco.connect("draw", self, "_desenhar_terco")
	_raiz.add_child(_terco)
	_linha_ouro = ColorRect.new()
	_linha_ouro.color = Jogo.OURO
	_linha_ouro.mouse_filter = MOUSE_FILTER_IGNORE
	_terco.add_child(_linha_ouro)
	_nome_estadio = UI.label(s_local.estadio, Jogo.fonte("titan", 52, 0), Color.white, Label.ALIGN_LEFT)
	_terco.add_child(_nome_estadio)
	var lugares := 28000 + (hash(local) % 420) * 100
	var clima: String = p.get("clima", "sol")
	var ceu: String = CLIMAS.get(clima, "")
	if "chuva" in clima:
		ceu += ": A BOLA CORRE MENOS"
	var onde: String = EscolhaEstadio.local_texto(local)
	_sub_estadio = UI.label("%s   •   MANDANTE: %s   •   %d.%03d LUGARES   •   %s" % [onde, s_casa.nome, lugares / 1000, lugares % 1000, ceu], Jogo.fonte("texto", 19, 0), Color(1, 1, 1, 0.88), Label.ALIGN_LEFT)
	_terco.add_child(_sub_estadio)
	_largura_terco = clamp(max(Jogo.fonte("titan", 52, 0).get_string_size(s_local.estadio).x, Jogo.fonte("texto", 19, 0).get_string_size(_sub_estadio.text).x) + 150.0, 520.0, 1160.0)
	_caixa_terco = _caixa(Color(0.02, 0.04, 0.09, 0.74), 18)
	_caixa_vidro = _caixa(Color(0.02, 0.04, 0.09, 0.62), 20)
	_barra_fundo = _caixa(Color(1, 1, 1, 0.10), 8)
	_barra_cheia = _caixa(Color.white, 8)
	_caixa_faixa = _caixa(Jogo.cor_time(local), 3)   # risco na cor do dono do estádio

	# confronto
	_clarao = ColorRect.new()
	_clarao.rect_size = Vector2(1280, 720)
	_clarao.color = Color(1, 1, 1, 0)
	_clarao.mouse_filter = MOUSE_FILTER_IGNORE
	_faixa = Control.new()
	_faixa.mouse_filter = MOUSE_FILTER_IGNORE
	_faixa.rect_size = Vector2(1280, 720)
	_faixa.connect("draw", self, "_desenhar_faixa")
	_raiz.add_child(_faixa)
	for i in [0, 1]:
		var sg := _casa if i == 0 else _fora
		var s := Jogo.selecao(sg)
		var e := TextureRect.new()
		e.texture = Jogo.emblema(sg)
		e.expand = true
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		e.mouse_filter = MOUSE_FILTER_IGNORE
		e.rect_size = Vector2(TAM_ESCUDO, TAM_ESCUDO)
		e.rect_pivot_offset = e.rect_size / 2
		_raiz.add_child(e)
		_escudos.append(e)
		var n := UI.label(s.nome, Jogo.fonte("titan", 32, 3), Color.white)
		UI.colocar(n, X_ESCUDO[i] - 220, Y_ESCUDO + TAM_ESCUDO / 2 + 2, 440, 44)
		_raiz.add_child(n)
		_nomes.append(n)
		var jn := Jogo.jogador_de(sg)
		var papel := UI.label(("MANDANTE" if i == 0 else "VISITANTE") + "  •  " + (("JOGADOR %d" % jn) if jn > 0 else "CPU"), Jogo.fonte("texto", 17, 1), Color(1, 1, 1, 0.75))
		UI.colocar(papel, X_ESCUDO[i] - 220, Y_ESCUDO + TAM_ESCUDO / 2 + 44, 440, 24)
		_raiz.add_child(papel)
		_papeis.append(papel)
	_vs = UI.label("VS", Jogo.fonte("titan", 72, 4), Jogo.OURO)
	UI.colocar(_vs, 560, Y_ESCUDO - 60, 160, 120)
	_vs.rect_pivot_offset = Vector2(80, 60)
	_raiz.add_child(_vs)

	_barras = Control.new()
	_barras.mouse_filter = MOUSE_FILTER_IGNORE
	_barras.rect_size = Vector2(1280, 720)
	_barras.connect("draw", self, "_desenhar_barras")
	_raiz.add_child(_barras)

	var ida: Dictionary = p.get("ida", {})
	_ida = UI.label("", Jogo.fonte("bungee", 22, 2), Jogo.AMARELO)
	if not ida.empty():
		_ida.text = "IDA  %d x %d" % [int(ida.get(_casa, 0)), int(ida.get(_fora, 0))]
	UI.colocar(_ida, 520, Y_ESCUDO + 62, 240, 40)
	_raiz.add_child(_ida)

	# HUD de transmissão sem faixas pretas: sombra suave e pílulas de vidro
	_hud = HudTV.new()
	add_child(_hud)
	var fase := "AMISTOSO"
	if not Jogo.copa.empty():
		var f_nome: String = p.get("fase", "quartas")
		var perna := "JOGO ÚNICO" if f_nome == "terceiro" else ("JOGO DE IDA" if ida.empty() else "JOGO DE VOLTA")
		fase = "%s  •  %s  •  %s" % [FASES.get(f_nome, "COPA"), perna, CLIMAS.get(clima, "")]
	var marca := UI.label("COPA CRAQUE DE BOTÃO" if not Jogo.copa.empty() else "CRAQUE DE BOTÃO", Jogo.fonte("bungee", 18, 0), Jogo.OURO, Label.ALIGN_LEFT)
	UI.colocar(marca, 60, 24, 600, 40)
	add_child(marca)
	_hud.pilula(marca, Jogo.cor_time(_casa))
	var lf := UI.label(fase, Jogo.fonte("bungee", 18, 0), Color.white, Label.ALIGN_RIGHT)
	UI.colocar(lf, 1280 - 60 - 760, 24, 760, 40)
	add_child(lf)
	_hud.pilula(lf)
	_topo = [marca, lf]
	_chamada = UI.label("A PARTIDA COMEÇA EM", Jogo.fonte("bungee", 22, 0), Jogo.AMARELO, Label.ALIGN_RIGHT)
	UI.colocar(_chamada, 380, Y_CONTA - 24, 420, 48)
	add_child(_chamada)
	_hud.pilula(_chamada, Color(0, 0, 0, 0), 76.0)
	_anel = Control.new()
	_anel.mouse_filter = MOUSE_FILTER_IGNORE
	_anel.rect_size = Vector2(1280, 720)
	_anel.connect("draw", self, "_desenhar_anel")
	add_child(_anel)
	_num = UI.label("3", Jogo.fonte("titan", 28, 0), Color.white)
	UI.colocar(_num, 846 - 30, Y_CONTA - 22, 60, 44)
	add_child(_num)
	_dica = UI.label("APERTE O BOTÃO PARA PULAR", Jogo.fonte("texto", 16, 0), Color(1, 1, 1, 0.8), Label.ALIGN_RIGHT)
	UI.colocar(_dica, 1280 - 60 - 400, Y_CONTA - 18, 400, 36)
	add_child(_dica)
	_hud.pilula(_dica)
	add_child(_clarao)
	# legenda do cartão-postal (o voo abre nele: Cristo Redentor)
	if _estadio.postal_nome != "":
		_postal = UI.label(_estadio.postal_nome, Jogo.fonte("bungee", 22, 0), Color.white, Label.ALIGN_LEFT)
		UI.colocar(_postal, 60, 84, 900, 44)
		add_child(_postal)
		_hud.pilula(_postal, Jogo.cor_time(local))
	_confete_vitrine = CPUParticles2D.new()
	_confete_vitrine.texture = CONFETE
	_confete_vitrine.amount = 2
	_confete_vitrine.lifetime = 0.5
	_confete_vitrine.position = Vector2(640, 360)
	_confete_vitrine.modulate = Color(1, 1, 1, 0.02)
	_raiz.add_child(_confete_vitrine)
	# a capa do preparo (por cima de tudo) e o preparo escondido
	var cores := [Color(Jogo.selecao(_casa).torcida[0]), Color(Jogo.selecao(_fora).torcida[0])]
	_palco.capa(self, "PREPARANDO O ESTÁDIO", s_local.estadio + "   •   " + onde, [Jogo.emblema(_casa), Jogo.emblema(_fora)], cores)
	_palco.preparar(_estadio, funcref(_estadio, "posicionar_camera"), _estadio.amostras(), _estadio.medir_em())

	for sg in [_casa, _fora]:
		for t in [Jogo.fonte("titan", 52, 0), Jogo.fonte("titan", 34, 3)]:
			Jogo.preaquecer(t, Jogo.selecao(sg).estadio + Jogo.selecao(sg).nome)
	# o som do estádio: a torcida gravada na frente, o tema da Copa por baixo
	if Jogo.tem_grupo("abertura"):
		Jogo.ambiente(0.25)
		Jogo.tocar_grupo("abertura", "", -1.0)
		Jogo.musica_fundo(-11.0, true)
	else:
		Jogo.ambiente(0.45)
		Jogo.musica_fundo(-3.0, true)
	_atualizar()


func _caixa(cor: Color, raio: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = cor
	b.set_corner_radius_all(raio)
	b.anti_aliasing = true
	return b


func _process(delta: float) -> void:
	_vivo += delta
	if not _palco.esta_pronto:
		_vitrine()
		return
	if not _comecou:
		# primeiro quadro do show: o relógio parte do zero (o último quadro
		# do preparo não conta), a câmera parte parada e acelera suave
		_comecou = true
		_t = 0.0
		if _confete_vitrine != null:
			_confete_vitrine.queue_free()
			_confete_vitrine = null
		_atualizar()
		# as camadas desenhadas na vitrine voltam ao estado do começo
		for camada in [_faixa, _barras, _anel, _terco]:
			camada.update()
		return
	# tempo real (sem câmera lenta); só um engasgo grande é aparado
	_t += min(delta, 0.1)
	_sons_na_hora()
	_atualizar()
	if _t >= FIM_AUTO:
		_comecar()


## VITRINE (durante o preparo, escondida atrás da capa): passa a linha do
## tempo pelos momentos em que cada texto e painel aparece (nome do estádio,
## faixa do confronto, estatísticas, contagem). O Android prepara letras,
## painéis e efeitos agora, e não no meio do show.
func _vitrine() -> void:
	var momentos := [1.6 + _d, C + 1.0, C + 1.8, T_CONTA + 0.6]
	_t = momentos[_i_vitrine % momentos.size()]
	_i_vitrine += 1
	_atualizar()
	_postal_vitrine()


func _postal_vitrine() -> void:
	if _postal != null:
		_postal.modulate.a = 1.0


func _sons_na_hora() -> void:
	if _t >= C + 0.5 and not _sons.has("festa"):
		_sons["festa"] = true
		_estadio.festa(1.0)
		_confete()
	var lista := [[0.05, "swoosh", -8.0], [0.8, "brilho", -10.0], [C, "swoosh", -4.0],
			[C + 0.5, "impacto", -4.0], [C + 0.8, "brilho", -10.0], [T_CONTA, "clique", -4.0],
			[T_CONTA + 1.0, "clique", -4.0], [T_CONTA + 2.0, "clique", -4.0]]
	for ev in lista:
		if _t >= ev[0] and not _sons.has(ev[0]):
			_sons[ev[0]] = true
			Jogo.tocar(ev[1], ev[2])


func _confete() -> void:
	for i in range(2):
		var cf := CPUParticles2D.new()
		cf.texture = CONFETE
		cf.amount = 40
		cf.lifetime = 3.2
		cf.one_shot = true
		cf.explosiveness = 0.4
		cf.position = Vector2(640, -20)
		cf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		cf.emission_rect_extents = Vector2(660, 10)
		cf.direction = Vector2(0, 1)
		cf.spread = 25
		cf.gravity = Vector2(0, 160)
		cf.initial_velocity = 160
		cf.initial_velocity_random = 0.6
		cf.angular_velocity = 300
		cf.angular_velocity_random = 1.0
		cf.color = Color(Jogo.selecao(_casa if i == 0 else _fora).torcida[0])
		_raiz.add_child(cf)


## 0..1 dentro do trecho [a, a + d] com saída suave (expo).
static func _e(t: float, a: float, d: float) -> float:
	var u := clamp((t - a) / d, 0.0, 1.0)
	return 1.0 if u >= 1.0 else 1.0 - pow(2.0, -10.0 * u)


static func _lin(t: float, a: float, d: float) -> float:
	return clamp((t - a) / d, 0.0, 1.0)


func _atualizar() -> void:
	var t := _t
	# a câmera do estádio 3D (planos: cidade -> torcida -> gramado -> TV)
	if _palco.esta_pronto:
		_estadio.posicionar_camera(t)
	_escuro.color.a = 0.42 * _e(t, C - 0.1, 0.8)
	# faixas de cinema
	_hud.sombra = _e(t, 0.0, 0.7)
	for l in _topo:
		l.modulate.a = _e(t, 0.5, 0.6)
	_dica.modulate.a = _e(t, 1.2, 0.6) * (1.0 - _e(t, T_CONTA - 0.4, 0.3))
	if _postal != null:
		_postal.modulate.a = _e(t, 0.4, 0.6) * (1.0 - _e(t, 2.3, 0.4))
		_postal.rect_position.x = 64 - 30.0 * (1.0 - _e(t, 0.4, 0.8))
	# terço inferior (vidro): entra deslizando da esquerda e sai para a esquerda
	var ent := _e(t, 0.7 + _d, 0.8)
	var sai := _e(t, _t_terco_fim, 0.45)
	_terco.rect_position = Vector2(-50.0 * (1.0 - ent) - 70.0 * sai, 0)
	_terco.modulate.a = ent * (1.0 - sai)
	_terco.update()
	var x0 := 60.0 + 112.0
	var y0 := 488.0
	UI.colocar(_nome_estadio, x0, y0 + 10 + 10.0 * (1.0 - _e(t, 0.85 + _d, 0.7)), 1000, 66)
	_nome_estadio.modulate.a = _e(t, 0.85 + _d, 0.6)
	UI.colocar(_sub_estadio, x0 + 2, y0 + 78 + 8.0 * (1.0 - _e(t, 1.15 + _d, 0.7)), 1060, 30)
	_sub_estadio.modulate.a = _e(t, 1.15 + _d, 0.6)
	_linha_ouro.rect_position = Vector2(x0 + 2, y0 + 74)
	_linha_ouro.rect_size = Vector2((_largura_terco - 150.0) * _e(t, 1.0 + _d, 1.0), 2)
	# faixa do confronto: metades entram dos lados; escudos firmes (sem pulsar)
	if t > C - 0.1 and t < C + 1.6:
		_faixa.update()
	for i in [0, 1]:
		var lado := -1.0 if i == 0 else 1.0
		var u := _e(t, C + 0.06 * i, 0.55)
		var x: float = X_ESCUDO[i] + lado * 140.0 * (1.0 - u)
		var e: TextureRect = _escudos[i]
		e.rect_position = Vector2(round(x - TAM_ESCUDO / 2), Y_ESCUDO - 14.0 - TAM_ESCUDO / 2)
		e.modulate.a = _e(t, C + 0.12 + 0.06 * i, 0.4)
		_nomes[i].rect_position.x = X_ESCUDO[i] - 220 + lado * 60.0 * (1.0 - _e(t, C + 0.3 + 0.06 * i, 0.45))
		_nomes[i].modulate.a = _e(t, C + 0.3 + 0.06 * i, 0.4)
		_papeis[i].modulate.a = _e(t, C + 0.45 + 0.06 * i, 0.4)
	# VS: aparece suave (sem bater nem tremer) e um clarão leve
	var v := _e(t, C + 0.5, 0.35)
	_vs.modulate.a = v
	_vs.rect_scale = Vector2.ONE * lerp(1.12, 1.0, v)
	_clarao.color.a = 0.22 * (1.0 - _lin(t, C + 0.5, 0.4)) if t >= C + 0.5 else 0.0
	_ida.modulate.a = _e(t, C + 1.3, 0.4)
	# atributos num painel de vidro
	_barras.modulate.a = _e(t, C + 0.8, 0.3)
	if t > C + 0.7 and t < C + 2.3:
		_barras.update()
	# contagem em anel para a partida (começa sozinha)
	var c := _e(t, T_CONTA, 0.35)
	_chamada.modulate.a = c
	_num.modulate.a = c
	_anel.modulate.a = c
	if t >= T_CONTA:
		_num.text = str(int(clamp(ceil(FIM_AUTO - t), 1.0, 3.0)))
		_anel.update()


## O terço inferior: painel de vidro arredondado, filete na cor do mandante
## e o escudo do dono do estádio.
func _desenhar_terco() -> void:
	var r := Rect2(60, 488, _largura_terco, 124)
	_terco.draw_style_box(_caixa_terco, r)
	_terco.draw_style_box(_caixa_faixa, Rect2(r.position.x + 14, r.position.y + 18, 6, r.size.y - 36))
	_terco.draw_texture_rect(_emb_local, Rect2(r.position.x + 30, r.position.y + 22, 80, 80), false)


## A contagem: anel dourado que se fecha a cada segundo.
func _desenhar_anel() -> void:
	var centro := Vector2(846, Y_CONTA)
	_anel.draw_arc(centro, 25, 0, TAU, 64, Color(1, 1, 1, 0.16), 4.0, true)
	var f := 1.0 - fmod(max(0.0, FIM_AUTO - _t), 1.0)
	_anel.draw_arc(centro, 25, -PI / 2, -PI / 2 + TAU * f, 64, Jogo.OURO, 4.0, true)


## As duas metades da faixa (cor do time por fora, escura por dentro), o
## corte inclinado no meio onde fica o VS, filetes dourados e um brilho que
## atravessa uma vez.
func _desenhar_faixa() -> void:
	var t := _t
	var y0: float = FAIXA[0]
	var y1: float = FAIXA[1]
	var inc := 46.0
	for i in [0, 1]:
		var u := _e(t, C + 0.06 * i, 0.55)
		if u <= 0.0:
			continue
		var cor := Color(Jogo.selecao(_casa if i == 0 else _fora).torcida[0])
		var fora := Color(cor.r * 0.75, cor.g * 0.75, cor.b * 0.75, 0.92)
		var dentro := Color(0.02, 0.03, 0.07, 0.86)
		var pts: PoolVector2Array
		if i == 0:
			var d := -700.0 * (1.0 - u)
			pts = PoolVector2Array([Vector2(d, y0), Vector2(612 + inc / 2 + d, y0), Vector2(612 - inc / 2 + d, y1), Vector2(d, y1)])
		else:
			var d := 700.0 * (1.0 - u)
			pts = PoolVector2Array([Vector2(668 + inc / 2 + d, y0), Vector2(1280 + d, y0), Vector2(1280 + d, y1), Vector2(668 - inc / 2 + d, y1)])
		var cores := PoolColorArray([fora, dentro, dentro, fora]) if i == 0 else PoolColorArray([dentro, fora, fora, dentro])
		_faixa.draw_polygon(pts, cores, PoolVector2Array(), null, null, true)
		# filetes dourados em cima e embaixo
		var ouro := Color(Jogo.OURO.r, Jogo.OURO.g, Jogo.OURO.b, 0.9)
		_faixa.draw_line(pts[0], pts[1], ouro, 3.0, true)
		_faixa.draw_line(pts[3], pts[2], ouro, 3.0, true)
		# reflexo de vidro na metade de cima
		var meio := (y0 + y1) / 2.0
		var vidro := PoolVector2Array([pts[0], pts[1], Vector2(lerp(pts[1].x, pts[2].x, 0.5), meio), Vector2(lerp(pts[0].x, pts[3].x, 0.5), meio)])
		_faixa.draw_polygon(vidro, PoolColorArray([Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]), PoolVector2Array(), null, null, true)
	# o brilho que passa uma vez pela faixa
	var b := _lin(t, C + 0.7, 0.6)
	if b > 0.0 and b < 1.0:
		var x := -200.0 + 1680.0 * b
		var br := PoolVector2Array([Vector2(x, y0), Vector2(x + 90, y0), Vector2(x + 30, y1), Vector2(x - 60, y1)])
		var a := 0.22 * sin(b * PI)
		_faixa.draw_polygon(br, PoolColorArray([Color(1, 1, 1, a), Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, a)]), PoolVector2Array(), null, null, true)


func _desenhar_barras() -> void:
	var a := Jogo.selecao(_casa)
	var b := Jogo.selecao(_fora)
	var fonte := Jogo.fonte("bungee", 17, 0)
	var fonte_n := Jogo.fonte("titan", 22, 2)
	_barras.draw_style_box(_caixa_vidro, Rect2(140, 446, 1000, 190))
	for k in range(ATRIB.size()):
		var chave: String = ATRIB[k][0]
		var y := 466.0 + k * 34.0
		var u := _e(_t, C + 0.9 + 0.1 * k, 0.5)
		var va: float = a[chave]
		var vb: float = b[chave]
		var nome: String = ATRIB[k][1]
		var w := fonte.get_string_size(nome).x
		_barras.draw_string(fonte, Vector2(640 - w / 2, y + 16), nome, Color(1, 1, 1, 0.85))
		for i in [0, 1]:
			var v := va if i == 0 else vb
			var outro := vb if i == 0 else va
			var comp := 300.0 * Jogo.nivel(v) * 0.85 + 45.0
			comp *= u
			var cor := Jogo.OURO if v > outro else (Color(0.85, 0.9, 1.0) if v == outro else Color(0.55, 0.62, 0.75))
			var x_ini := 555.0 if i == 0 else 725.0
			var rect := Rect2(x_ini - comp, y + 3, comp, 16) if i == 0 else Rect2(x_ini, y + 3, comp, 16)
			_barras.draw_style_box(_barra_fundo, Rect2(x_ini - 345.0 if i == 0 else x_ini, y + 3, 345, 16))
			if comp >= 16.0:
				_barra_cheia.bg_color = cor
				_barras.draw_style_box(_barra_cheia, rect)
			var txt := str(int(round(v * u)))
			var tw := fonte_n.get_string_size(txt).x
			var xn := x_ini - 345.0 - 14.0 - tw if i == 0 else x_ini + 345.0 + 14.0
			_barras.draw_string(fonte_n, Vector2(xn, y + 21), txt, cor)
	# números: títulos, gols na Copa e força geral
	var linhas := [["TÍTULOS", int(Jogo.titulos.get(_casa, 0)), int(Jogo.titulos.get(_fora, 0))],
		["GOLS NA COPA", _gols_na_copa(_casa), _gols_na_copa(_fora)],
		["FORÇA GERAL", int(a.forca), int(b.forca)]]
	var alfa := _e(_t, C + 1.3, 0.4)
	for k in range(linhas.size()):
		var L: Array = linhas[k]
		var x := 280.0 + k * 360.0
		var y := 578.0
		var nome2: String = L[0]
		var w2 := fonte.get_string_size(nome2).x
		_barras.draw_string(fonte, Vector2(x - w2 / 2, y), nome2, Color(1, 1, 1, 0.8 * alfa))
		var txt2 := "%d  x  %d" % [L[1], L[2]]
		var w3 := fonte_n.get_string_size(txt2).x
		_barras.draw_string(fonte_n, Vector2(x - w3 / 2, y + 30), txt2, Color(Jogo.OURO.r, Jogo.OURO.g, Jogo.OURO.b, alfa))


func _gols_na_copa(sigla: String) -> int:
	var g := 0
	if Jogo.copa.empty():
		return 0
	for rodada in Jogo.copa.jogos:
		for j in rodada:
			for perna in ["ida", "volta"]:
				var pl: Array = j[perna]
				if pl.empty():
					continue
				if j.a == sigla:
					g += int(pl[0])
				elif j.b == sigla:
					g += int(pl[1])
	return g


func _unhandled_input(ev: InputEvent) -> void:
	if _vivo < 0.6 or _saindo:
		return
	var tocou = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
	if tocou or ev.is_action_pressed("ui_accept") or ev.is_action_pressed("p1_chute") or ev.is_action_pressed("p2_chute"):
		get_tree().set_input_as_handled()
		_comecar()


func _comecar() -> void:
	if _saindo:
		return
	_saindo = true
	Jogo.parar_musica(0.4)
	Jogo.parar_grupos(0.6)
	Jogo.ir_para("res://cenas/partida.tscn")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_comecar()
