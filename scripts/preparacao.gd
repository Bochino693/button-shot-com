extends Control

## PREPARAÇÃO DA PARTIDA (apresentação de TV). O estádio do mandante em 3D
## (estadio3d.gd) e, por cima, os cartões da transmissão.
##
## Entrada sem tela preta: a capa de carregamento aparece no primeiro
## quadro e o estádio é montado uma etapa por quadro atrás dela (a barra
## anda); depois o palco 3D (palco3d.gd) prepara shaders e qualidade, e o
## show começa liso.
##
## Os cartões são NÓS montados uma vez (painéis, textos, polígonos) e a
## animação só mexe em posição, escala e transparência: nada é redesenhado
## quadro a quadro (era isso que fazia os cartões "montarem travando").
## Linha do tempo (_t), câmera num voo contínuo:
##   0     a cidade e o estádio; o cartão do estádio (nome, cidade, lugares,
##         clima) entra como gerador de caracteres de TV e sai
##   C     a câmera da TV: a faixa do confronto (as duas metades nas cores
##         dos times entram dos lados, escudos, "VS", um brilho atravessa)
##   C+0.8 painel de estatísticas (barras crescem); na volta, o placar da ida
##   C+2.8 contagem "A PARTIDA COMEÇA EM 3, 2, 1" e a partida começa (C+5.6)
## O BOTÃO (ou toque) pula direto para o jogo.

const UI = preload("res://scripts/ui.gd")
const Estadio3D = preload("res://scripts/estadio3d.gd")
const Palco3D = preload("res://scripts/palco3d.gd")
const HudTV = preload("res://scripts/hud_tv.gd")
const EscolhaEstadio = preload("res://scripts/escolha_estadio.gd")
const CONFETE = preload("res://imagens/confete.png")

const FASES := {"quartas": "QUARTAS DE FINAL", "semi": "SEMIFINAL", "final": "FINAL", "terceiro": "DECISÃO DO 3º LUGAR"}
const CLIMAS := {"sol": "DIA DE SOL", "chuva": "DIA DE CHUVA", "noite": "NOITE DE LUA", "noite_chuva": "NOITE COM CHUVA"}
const ATRIB := [["chute", "CHUTE"], ["controle", "CONTROLE"], ["defesa", "DEFESA"]]
const Y_CONTA := 676.0             # linha da contagem e da dica (embaixo)
const Y_ESCUDO := 252.0
const TAM_ESCUDO := 168.0
const FAIXA := [150.0, 412.0]      # topo e base da faixa do confronto
const X_ESCUDO := [330.0, 950.0]
const GC_POS := Vector2(60, 500)   # cartão do estádio (gerador de caracteres)
const GC_ALT := 112.0
const GC_BLOCO := 104.0
const GC_MAX := 1160.0             # largura máxima (cabe na tela com margem)
const PAINEL := Rect2(140, 446, 1000, 190)

var C := 12.3               # a câmera chegou na TV: entra o confronto
var FIM_AUTO := C + 5.6
var T_CONTA := C + 2.8
var _d := 0.0               # quando o cartão do estádio entra (o voo diz)
var _t_gc_fim := 5.5
var _t := 0.0
var _vivo := 0.0
var _montado := false
var _comecou := false
var _saindo := false
var _i_vitrine := 0
var _sons := {}
var _casa := ""
var _fora := ""
var _local := ""
var _clima := "sol"

var _palco
var _estadio
var _hud
var _raiz: Control
var _escuro: ColorRect
var _clarao: ColorRect
var _topo := []
var _postal: Label
var _dica: Label
# cartão do estádio
var _gc: Control
var _gc_bloco: Panel
var _gc_caixa: Panel
var _gc_nome: Label
var _gc_linha: ColorRect
var _gc_sub: Label
# confronto
var _banda: Control
var _metades := []
var _brilho_banda: Polygon2D
var _escudos := []
var _nomes := []
var _papeis := []
var _vs: Label
var _ida: Label
# estatísticas
var _painel: Panel
var _barras := []          # [Panel, k]
var _numeros := []         # Labels
var _rodape := []          # Controls (título + valor)
# contagem
var _chamada: Label
var _anel: TextureProgress
var _num: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var p: Dictionary = Jogo.partida
	_casa = p.casa
	_fora = p.fora
	_local = Jogo.local_da_partida()
	_clima = p.get("clima", "sol")
	# a capa aparece já no primeiro quadro; o estádio vem atrás dela
	_palco = Palco3D.new()
	_palco.criar(self)
	var s_local := Jogo.selecao(_local)
	var cores := [Color(Jogo.selecao(_casa).torcida[0]), Color(Jogo.selecao(_fora).torcida[0])]
	_palco.capa(self, "PREPARANDO O ESTÁDIO", s_local.estadio + "   •   " + EscolhaEstadio.local_texto(_local), [Jogo.emblema(_casa), Jogo.emblema(_fora)], cores)
	_palco.montagem(0.0)
	# o som do estádio: a torcida gravada na frente, o tema da Copa por baixo
	if Jogo.tem_grupo("abertura"):
		Jogo.ambiente(0.25)
		Jogo.tocar_grupo("abertura", "", -1.0)
		Jogo.musica_fundo(-11.0, true)
	else:
		Jogo.ambiente(0.45)
		Jogo.musica_fundo(-3.0, true)
	set_process(false)
	_montar()


## Monta o estádio (uma etapa por quadro) e os cartões, e só então começa o
## preparo escondido do palco.
func _montar() -> void:
	yield(get_tree(), "idle_frame")
	_estadio = Estadio3D.new()
	_palco.vp.add_child(_estadio)
	yield(_estadio.montar_em_partes(_casa, _fora, _clima, {"estadio": _local}, funcref(_palco, "montagem")), "completed")
	if not is_inside_tree():
		return
	C = _estadio.t_tv + 0.1
	FIM_AUTO = C + 5.6
	T_CONTA = C + 2.8
	_d = max(0.45, _estadio.t_terco_ini - 0.6)      # depois que a capa sumiu
	_t_gc_fim = _estadio.t_terco_fim
	_montar_cartoes()
	_palco.capa_por_cima()
	_palco.preparar(_estadio, funcref(_estadio, "posicionar_camera"), _estadio.amostras(), _estadio.medir_em())
	for sg in [_casa, _fora]:
		Jogo.preaquecer(Jogo.fonte("titan", 32, 3), Jogo.selecao(sg).nome)
	_montado = true
	_atualizar()
	set_process(true)


# ================================================================ CARTÕES
func _montar_cartoes() -> void:
	_raiz = Control.new()
	_raiz.mouse_filter = MOUSE_FILTER_IGNORE
	_raiz.rect_size = Vector2(1280, 720)
	add_child(_raiz)
	_escuro = _retangulo(_raiz, Rect2(0, 0, 1280, 720), Color(0.01, 0.02, 0.05, 0.0))
	_montar_gc()
	_montar_confronto()
	_montar_painel()
	_montar_hud()
	_clarao = _retangulo(self, Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0))


static func _retangulo(pai: Node, r: Rect2, cor: Color) -> ColorRect:
	var c := ColorRect.new()
	c.rect_position = r.position
	c.rect_size = r.size
	c.color = cor
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(c)
	return c


static func _estilo(cor: Color, raios := [0, 0, 0, 0]) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.corner_radius_top_left = raios[0]
	s.corner_radius_top_right = raios[1]
	s.corner_radius_bottom_right = raios[2]
	s.corner_radius_bottom_left = raios[3]
	s.anti_aliasing = true
	return s


static func _painel_com(pai: Node, r: Rect2, estilo: StyleBox) -> Panel:
	var p := Panel.new()
	p.add_stylebox_override("panel", estilo)
	p.rect_position = r.position
	p.rect_size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(p)
	return p


## A maior fonte da lista em que o texto cabe na largura.
static func _caber(texto: String, nome: String, tamanhos: Array, contorno: int, largura: float) -> DynamicFont:
	for t in tamanhos:
		var f: DynamicFont = Jogo.fonte(nome, t, contorno)
		if f.get_string_size(texto).x <= largura:
			return f
	return Jogo.fonte(nome, tamanhos[tamanhos.size() - 1], contorno)


## Cartão do estádio: bloco na cor do dono do estádio com o escudo, e a
## caixa de vidro com o nome e uma linha só de informação. A caixa tem o
## tamanho do texto (nunca maior que a tela; a fonte diminui se precisar).
func _montar_gc() -> void:
	var s_local := Jogo.selecao(_local)
	var lugares := 28000 + (hash(_local) % 420) * 100
	var nome: String = s_local.estadio
	var sub := "%s   •   %d.%03d LUGARES   •   %s" % [EscolhaEstadio.local_texto(_local), lugares / 1000, lugares % 1000, CLIMAS.get(_clima, "")]
	var livre := GC_MAX - GC_BLOCO - 52.0
	var f_nome := _caber(nome, "titan", [46, 42, 38, 34, 30], 0, livre)
	var f_sub := _caber(sub, "texto", [19, 18, 17, 16, 15], 0, livre)
	var w: float = clamp(max(f_nome.get_string_size(nome).x, f_sub.get_string_size(sub).x) + 52.0, 420.0, GC_MAX - GC_BLOCO)
	_gc = Control.new()
	_gc.mouse_filter = MOUSE_FILTER_IGNORE
	_gc.rect_position = GC_POS
	_gc.rect_size = Vector2(GC_BLOCO + w, GC_ALT)
	_raiz.add_child(_gc)
	_gc_caixa = _painel_com(_gc, Rect2(GC_BLOCO, 0, w, GC_ALT), _estilo(Color(0.03, 0.05, 0.10, 0.86), [0, 14, 14, 0]))
	_gc_caixa.rect_pivot_offset = Vector2(0, GC_ALT / 2)
	_gc_bloco = _painel_com(_gc, Rect2(0, 0, GC_BLOCO, GC_ALT), _estilo(Jogo.cor_time(_local), [14, 0, 0, 14]))
	_gc_bloco.rect_pivot_offset = Vector2(0, GC_ALT)
	var e := TextureRect.new()
	e.texture = Jogo.emblema(_local)
	e.expand = true
	e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	e.mouse_filter = MOUSE_FILTER_IGNORE
	e.rect_position = Vector2(12, 16)
	e.rect_size = Vector2(80, 80)
	_gc_bloco.add_child(e)
	_gc_nome = UI.label(nome, f_nome, Color.white, Label.ALIGN_LEFT)
	_gc_nome.clip_text = true
	_gc_nome.rect_position = Vector2(24, 8)
	_gc_nome.rect_size = Vector2(w - 48, 60)
	_gc_caixa.add_child(_gc_nome)
	_gc_linha = _retangulo(_gc_caixa, Rect2(26, 70, w - 52, 3), Jogo.OURO)
	_gc_sub = UI.label(sub, f_sub, Color(1, 1, 1, 0.9), Label.ALIGN_LEFT)
	_gc_sub.clip_text = true
	_gc_sub.rect_position = Vector2(26, 76)
	_gc_sub.rect_size = Vector2(w - 52, 30)
	_gc_caixa.add_child(_gc_sub)


## Faixa do confronto: duas metades (polígonos prontos) nas cores dos times,
## corte inclinado no meio, filetes dourados e um brilho que atravessa.
func _montar_confronto() -> void:
	var y0: float = FAIXA[0]
	var alt: float = FAIXA[1] - FAIXA[0]
	_banda = Control.new()
	_banda.mouse_filter = MOUSE_FILTER_IGNORE
	_banda.rect_position = Vector2(0, y0)
	_banda.rect_size = Vector2(1280, alt)
	_banda.rect_clip_content = true
	_raiz.add_child(_banda)
	var inc := 46.0
	var ouro := Color(Jogo.OURO.r, Jogo.OURO.g, Jogo.OURO.b, 0.9)
	for i in [0, 1]:
		var cor := Color(Jogo.selecao(_casa if i == 0 else _fora).torcida[0])
		var fora_c := Color(cor.r * 0.75, cor.g * 0.75, cor.b * 0.75, 0.92)
		var dentro := Color(0.02, 0.03, 0.07, 0.86)
		var pts: PoolVector2Array
		var cores: PoolColorArray
		if i == 0:
			pts = PoolVector2Array([Vector2(0, 0), Vector2(612 + inc / 2, 0), Vector2(612 - inc / 2, alt), Vector2(0, alt)])
			cores = PoolColorArray([fora_c, dentro, dentro, fora_c])
		else:
			pts = PoolVector2Array([Vector2(668 + inc / 2, 0), Vector2(1280, 0), Vector2(1280, alt), Vector2(668 - inc / 2, alt)])
			cores = PoolColorArray([dentro, fora_c, fora_c, dentro])
		var m := Node2D.new()
		_banda.add_child(m)
		var poli := Polygon2D.new()
		poli.polygon = pts
		poli.vertex_colors = cores
		poli.antialiased = true
		m.add_child(poli)
		# reflexo de vidro na metade de cima
		var meio := alt / 2.0
		var vidro := Polygon2D.new()
		vidro.polygon = PoolVector2Array([pts[0], pts[1], Vector2(lerp(pts[1].x, pts[2].x, 0.5), meio), Vector2(lerp(pts[0].x, pts[3].x, 0.5), meio)])
		vidro.vertex_colors = PoolColorArray([Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)])
		m.add_child(vidro)
		# filetes dourados em cima e embaixo
		for borda in [[pts[0], pts[1]], [pts[3], pts[2]]]:
			var a: Vector2 = borda[0]
			var b: Vector2 = borda[1]
			var dy := 0.0 if a.y == 0.0 else -3.0
			var fil := Polygon2D.new()
			fil.polygon = PoolVector2Array([Vector2(a.x, a.y + dy), Vector2(b.x, b.y + dy), Vector2(b.x, b.y + dy + 3.0), Vector2(a.x, a.y + dy + 3.0)])
			fil.color = ouro
			m.add_child(fil)
		_metades.append(m)
	_brilho_banda = Polygon2D.new()
	_brilho_banda.polygon = PoolVector2Array([Vector2(0, 0), Vector2(90, 0), Vector2(30, alt), Vector2(-60, alt)])
	_brilho_banda.vertex_colors = PoolColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
	var aditivo := CanvasItemMaterial.new()
	aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_brilho_banda.material = aditivo
	_brilho_banda.modulate.a = 0.0
	_banda.add_child(_brilho_banda)
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
		e.rect_position = Vector2(X_ESCUDO[i] - TAM_ESCUDO / 2, Y_ESCUDO - 14.0 - TAM_ESCUDO / 2)
		_raiz.add_child(e)
		_escudos.append(e)
		var n := UI.label(s.nome, _caber(s.nome, "titan", [32, 28, 24], 3, 430.0), Color.white)
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
	_raiz.add_child(_vs)
	var ida: Dictionary = Jogo.partida.get("ida", {})
	_ida = UI.label("", Jogo.fonte("bungee", 22, 2), Jogo.AMARELO)
	if not ida.empty():
		_ida.text = "IDA  %d x %d" % [int(ida.get(_casa, 0)), int(ida.get(_fora, 0))]
	UI.colocar(_ida, 520, Y_ESCUDO + 62, 240, 40)
	_raiz.add_child(_ida)


## Painel de vidro com os atributos lado a lado: as barras são painéis
## prontos que só crescem (escala), os números já vêm escritos.
func _montar_painel() -> void:
	var a := Jogo.selecao(_casa)
	var b := Jogo.selecao(_fora)
	_painel = _painel_com(_raiz, PAINEL, _estilo(Color(0.02, 0.04, 0.09, 0.62), [20, 20, 20, 20]))
	var fundo := _estilo(Color(1, 1, 1, 0.10), [8, 8, 8, 8])
	var f_nome := Jogo.fonte("bungee", 17, 0)
	var f_num := Jogo.fonte("titan", 22, 2)
	for k in range(ATRIB.size()):
		var chave: String = ATRIB[k][0]
		var y := 20.0 + k * 34.0
		var nome := UI.label(ATRIB[k][1], f_nome, Color(1, 1, 1, 0.85))
		nome.rect_position = Vector2(420, y)
		nome.rect_size = Vector2(160, 22)
		_painel.add_child(nome)
		for i in [0, 1]:
			var v: float = a[chave] if i == 0 else b[chave]
			var outro: float = b[chave] if i == 0 else a[chave]
			var cor := Jogo.OURO if v > outro else (Color(0.85, 0.9, 1.0) if v == outro else Color(0.55, 0.62, 0.75))
			var comp: float = 300.0 * Jogo.nivel(v) * 0.85 + 45.0
			var x_ini := 415.0 if i == 0 else 585.0
			_painel_com(_painel, Rect2(x_ini - 345.0 if i == 0 else x_ini, y + 3, 345, 16), fundo)
			var cheia := _painel_com(_painel, Rect2(x_ini - comp if i == 0 else x_ini, y + 3, comp, 16), _estilo(cor, [8, 8, 8, 8]))
			cheia.rect_pivot_offset = Vector2(comp if i == 0 else 0.0, 8)
			_barras.append([cheia, k])
			var num := UI.label(str(int(round(v))), f_num, cor, Label.ALIGN_RIGHT if i == 0 else Label.ALIGN_LEFT)
			num.rect_position = Vector2(0, y - 4) if i == 0 else Vector2(944, y - 4)
			num.rect_size = Vector2(56, 30)
			_painel.add_child(num)
			_numeros.append(num)
	var linhas := [["TÍTULOS", int(Jogo.titulos.get(_casa, 0)), int(Jogo.titulos.get(_fora, 0))],
		["GOLS NA COPA", _gols_na_copa(_casa), _gols_na_copa(_fora)],
		["FORÇA GERAL", int(a.forca), int(b.forca)]]
	for k in range(linhas.size()):
		var x := 140.0 + k * 360.0
		var c := Control.new()
		c.mouse_filter = MOUSE_FILTER_IGNORE
		c.rect_position = Vector2(x - 150, 112)
		c.rect_size = Vector2(300, 70)
		_painel.add_child(c)
		var t := UI.label(linhas[k][0], f_nome, Color(1, 1, 1, 0.8))
		UI.colocar(t, 0, 4, 300, 26)
		c.add_child(t)
		var v2 := UI.label("%d  x  %d" % [linhas[k][1], linhas[k][2]], f_num, Jogo.OURO)
		UI.colocar(v2, 0, 32, 300, 32)
		c.add_child(v2)
		_rodape.append(c)


## Faixas de cima (marca e fase), legenda do cartão-postal, a dica de pular
## e a contagem (anel pronto, só o valor muda).
func _montar_hud() -> void:
	_hud = HudTV.new()
	add_child(_hud)
	var fase := "AMISTOSO"
	if not Jogo.copa.empty():
		var f_nome: String = Jogo.partida.get("fase", "quartas")
		var ida: Dictionary = Jogo.partida.get("ida", {})
		var perna := "JOGO ÚNICO" if f_nome == "terceiro" else ("JOGO DE IDA" if ida.empty() else "JOGO DE VOLTA")
		fase = "%s  •  %s" % [FASES.get(f_nome, "COPA"), perna]
	var marca := UI.label("COPA CRAQUE DE BOTÃO" if not Jogo.copa.empty() else "CRAQUE DE BOTÃO", Jogo.fonte("bungee", 18, 0), Jogo.OURO, Label.ALIGN_LEFT)
	UI.colocar(marca, 60, 24, 600, 40)
	add_child(marca)
	_hud.pilula(marca, Jogo.cor_time(_casa))
	var lf := UI.label(fase, Jogo.fonte("bungee", 18, 0), Color.white, Label.ALIGN_RIGHT)
	UI.colocar(lf, 1280 - 60 - 760, 24, 760, 40)
	add_child(lf)
	_hud.pilula(lf)
	_topo = [marca, lf]
	if _estadio.postal_nome != "":
		_postal = UI.label(_estadio.postal_nome, Jogo.fonte("bungee", 22, 0), Color.white, Label.ALIGN_LEFT)
		UI.colocar(_postal, 60, 84, 900, 44)
		add_child(_postal)
		_hud.pilula(_postal, Jogo.cor_time(_local))
	_chamada = UI.label("A PARTIDA COMEÇA EM", Jogo.fonte("bungee", 22, 0), Jogo.AMARELO, Label.ALIGN_RIGHT)
	UI.colocar(_chamada, 380, Y_CONTA - 24, 420, 48)
	add_child(_chamada)
	_hud.pilula(_chamada, Color(0, 0, 0, 0), 76.0)
	_anel = TextureProgress.new()
	_anel.texture_under = _textura_anel(Color(1, 1, 1, 0.16))
	_anel.texture_progress = _textura_anel(Jogo.OURO)
	_anel.fill_mode = TextureProgress.FILL_CLOCKWISE
	_anel.max_value = 1.0
	_anel.step = 0.0
	_anel.rect_position = Vector2(846 - 28, Y_CONTA - 28)
	_anel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_anel)
	_num = UI.label("3", Jogo.fonte("titan", 28, 0), Color.white)
	UI.colocar(_num, 846 - 30, Y_CONTA - 22, 60, 44)
	add_child(_num)
	_dica = UI.label("APERTE O BOTÃO PARA PULAR", Jogo.fonte("texto", 16, 0), Color(1, 1, 1, 0.8), Label.ALIGN_RIGHT)
	UI.colocar(_dica, 1280 - 60 - 400, Y_CONTA - 18, 400, 36)
	add_child(_dica)
	_hud.pilula(_dica)


## Anel da contagem (feito uma vez, com borda lisa).
static func _textura_anel(cor: Color) -> ImageTexture:
	var tam := 112
	var img := Image.new()
	img.create(tam, tam, false, Image.FORMAT_RGBA8)
	img.lock()
	var c := tam / 2.0
	for y in range(tam):
		for x in range(tam):
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
			var a: float = clamp(1.0 - abs(d - 50.0) / 4.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(cor.r, cor.g, cor.b, cor.a * a))
	img.unlock()
	img.resize(56, 56, Image.INTERPOLATE_BILINEAR)
	var t := ImageTexture.new()
	t.create_from_image(img, Texture.FLAG_FILTER)
	return t


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


# ================================================================ TEMPO
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
		_atualizar()
		return
	# tempo real (sem câmera lenta); só um engasgo grande é aparado
	_t += min(delta, 0.1)
	_sons_na_hora()
	_atualizar()
	if _t >= FIM_AUTO:
		_comecar()


## VITRINE (durante o preparo, escondida atrás da capa): passa a linha do
## tempo pelos momentos em que cada cartão aparece. O Android prepara
## letras e painéis agora, e não no meio do show.
func _vitrine() -> void:
	var momentos := [_d + 0.8, C + 1.0, C + 1.8, T_CONTA + 0.6]
	_t = momentos[_i_vitrine % momentos.size()]
	_i_vitrine += 1
	_atualizar()
	if _postal != null:
		_postal.modulate.a = 1.0


func _sons_na_hora() -> void:
	if _t >= C + 0.5 and not _sons.has("festa"):
		_sons["festa"] = true
		_estadio.festa(1.0)
		_confete()
	var lista := [[0.05, "swoosh", -8.0], [max(0.1, _d), "swoosh", -10.0], [C, "swoosh", -4.0],
			[C + 0.5, "impacto", -4.0], [C + 0.7, "brilho", -10.0], [T_CONTA, "clique", -4.0],
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


## 0..1 dentro do trecho [a, a + d] com saída suave (expo), como os
## geradores de caracteres da TV: rápido no começo, assenta macio.
static func _e(t: float, a: float, d: float) -> float:
	var u := clamp((t - a) / d, 0.0, 1.0)
	return 1.0 if u >= 1.0 else 1.0 - pow(2.0, -10.0 * u)


static func _lin(t: float, a: float, d: float) -> float:
	return clamp((t - a) / d, 0.0, 1.0)


## Tudo é posição, escala e transparência de nós prontos (nada redesenha).
func _atualizar() -> void:
	var t := _t
	if _palco.esta_pronto:
		_estadio.posicionar_camera(t)
	_escuro.color.a = 0.42 * _e(t, C - 0.1, 0.8)
	_hud.sombra = _e(t, 0.0, 0.7)
	for l in _topo:
		l.modulate.a = _e(t, 0.5, 0.6)
	_dica.modulate.a = _e(t, 1.2, 0.6) * (1.0 - _e(t, T_CONTA - 0.4, 0.3))
	if _postal != null:
		_postal.modulate.a = _e(t, 0.4, 0.6) * (1.0 - _e(t, 2.3, 0.4))
		_postal.rect_position.x = 60 - 30.0 * (1.0 - _e(t, 0.4, 0.8))
	_atualizar_gc(t)
	_atualizar_confronto(t)
	_atualizar_painel(t)
	# contagem (começa sozinha)
	var c := _e(t, T_CONTA, 0.35)
	_chamada.modulate.a = c
	_num.modulate.a = c
	_anel.modulate.a = c
	if t >= T_CONTA:
		_num.text = str(int(clamp(ceil(FIM_AUTO - t), 1.0, 3.0)))
		_anel.value = 1.0 - fmod(max(0.0, FIM_AUTO - t), 1.0)


## Cartão do estádio: o bloco sobe, a caixa abre da esquerda, o nome
## desliza, a linha dourada corre e a informação aparece; sai para a
## esquerda.
func _atualizar_gc(t: float) -> void:
	var te := t - _d
	var sai := _e(t, _t_gc_fim, 0.3)
	_gc.visible = te >= 0.0 and sai < 1.0
	if not _gc.visible:
		return
	_gc.modulate.a = 1.0 - sai
	_gc.rect_position.x = GC_POS.x - 50.0 * sai
	_gc_bloco.rect_scale = Vector2(1.0, max(0.01, _e(te, 0.0, 0.25)))
	_gc_caixa.rect_scale = Vector2(0.04 + 0.96 * _e(te, 0.08, 0.35), 1.0)
	var n := _e(te, 0.2, 0.35)
	_gc_nome.modulate.a = n
	_gc_nome.rect_position.x = 24.0 - 18.0 * (1.0 - n)
	_gc_linha.rect_scale = Vector2(max(0.001, _e(te, 0.28, 0.5)), 1.0)
	var s := _e(te, 0.36, 0.35)
	_gc_sub.modulate.a = s
	_gc_sub.rect_position.x = 26.0 - 12.0 * (1.0 - s)


## Faixa do confronto: metades dos lados, escudos firmes, VS suave, um
## clarão leve e o brilho que atravessa uma vez.
func _atualizar_confronto(t: float) -> void:
	_banda.visible = t > C - 0.1
	for i in [0, 1]:
		var lado := -1.0 if i == 0 else 1.0
		var u := _e(t, C + 0.06 * i, 0.55)
		_metades[i].position.x = lado * 700.0 * (1.0 - u)
		var e: TextureRect = _escudos[i]
		e.rect_position.x = X_ESCUDO[i] - TAM_ESCUDO / 2 + lado * 140.0 * (1.0 - u)
		e.modulate.a = _e(t, C + 0.12 + 0.06 * i, 0.4)
		e.rect_scale = Vector2.ONE * lerp(1.08, 1.0, _e(t, C + 0.12, 0.5))
		_nomes[i].rect_position.x = X_ESCUDO[i] - 220 + lado * 60.0 * (1.0 - _e(t, C + 0.3 + 0.06 * i, 0.45))
		_nomes[i].modulate.a = _e(t, C + 0.3 + 0.06 * i, 0.4)
		_papeis[i].modulate.a = _e(t, C + 0.45 + 0.06 * i, 0.4)
	var v := _e(t, C + 0.5, 0.35)
	_vs.modulate.a = v
	_vs.rect_scale = Vector2.ONE * lerp(1.12, 1.0, v)
	_clarao.color.a = 0.18 * (1.0 - _lin(t, C + 0.5, 0.4)) if t >= C + 0.5 else 0.0
	_ida.modulate.a = _e(t, C + 1.3, 0.4)
	var b := _lin(t, C + 0.7, 0.6)
	_brilho_banda.modulate.a = 0.22 * sin(b * PI) if b > 0.0 and b < 1.0 else 0.0
	_brilho_banda.position.x = -200.0 + 1680.0 * b


func _atualizar_painel(t: float) -> void:
	_painel.modulate.a = _e(t, C + 0.8, 0.3)
	_painel.visible = _painel.modulate.a > 0.0
	if not _painel.visible:
		return
	for par in _barras:
		var u := _e(t, C + 0.9 + 0.1 * par[1], 0.5)
		par[0].rect_scale = Vector2(max(0.001, u), 1.0)
	var n := _e(t, C + 1.0, 0.4)
	for l in _numeros:
		l.modulate.a = n
	var r := _e(t, C + 1.3, 0.4)
	for c in _rodape:
		c.modulate.a = r


# ================================================================ SAÍDA
func _unhandled_input(ev: InputEvent) -> void:
	if _vivo < 0.6 or _saindo or not _montado:
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
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST and _montado:
		_comecar()
