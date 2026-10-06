extends Control

## ESCOLHA DOS TIMES: cartões com escudo, nome, atributos (CHUTE, CONTROLE,
## DEFESA), os dois uniformes e as Copas ganhas.
##   Amistoso 1 jogador: escolhe o seu e depois o adversário (CPU).
##   Amistoso 2 jogadores: jogador 1 e jogador 2 escolhem.
##   Copa: primeiro QUANTOS JOGADORES (1 a 8); cada um escolhe o seu time e
##   o resto da chave é da CPU.
## Manche: direções andam pelos cartões; o BOTÃO escolhe e, apertado de novo
## no mesmo cartão, confirma. (O time do pendrive, se o operador gravou um,
## aparece junto com os outros.)

const UI = preload("res://scripts/ui.gd")
const Cenario = preload("res://scripts/cenario.gd")

const CARTAO := Vector2(190, 246)
const ATRIB := [["chute", "CHUTE"], ["controle", "CONTROLE"], ["defesa", "DEFESA"]]

var _etapa := 0            # quem está escolhendo agora
var _escolha := []         # sigla de cada etapa
var _n := 0                # nº de etapas (0 = a Copa ainda não sabe quantos jogadores)
var _cartoes := []
var _titulo: Label
var _dica: Label
var _confirmar: Button
var _voltar_b: Button
var _cenario
var _quantos: Control      # painel "quantos jogadores" da Copa
var _saindo := false
var _pendrive_b: Button
var _janela_pendrive: Control


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_cenario = Cenario.new()
	_cenario.escurecer = 0.62
	add_child(_cenario)
	_titulo = UI.label("", Jogo.fonte("titan", 44, 5), Color.white)
	UI.colocar(_titulo, 0, 14, 1280, 64)
	add_child(_titulo)
	_dica = UI.label("", Jogo.fonte("texto", 19, 1), Color(1, 1, 1, 0.8))
	UI.colocar(_dica, 0, 72, 1280, 26)
	add_child(_dica)
	_montar_cartoes(true)
	_confirmar = UI.botao("CONFIRMAR", Jogo.VERDE, Jogo.fonte("titan", 32, 3))
	UI.colocar(_confirmar, 880, 632, 300, 74)
	_confirmar.connect("pressed", self, "_confirmar_escolha")
	_confirmar.disabled = true
	add_child(_confirmar)
	_voltar_b = UI.botao("VOLTAR", Color(0.3, 0.1, 0.1), Jogo.fonte("titan", 28, 2))
	UI.colocar(_voltar_b, 100, 636, 220, 66)
	_voltar_b.connect("pressed", self, "_voltar")
	add_child(_voltar_b)
	# o time do pendrive na hora: carregar, trocar ou apagar
	_pendrive_b = UI.botao("PENDRIVE", Color(0.08, 0.3, 0.42), Jogo.fonte("titan", 26, 2))
	UI.colocar(_pendrive_b, 500, 636, 240, 66)
	_pendrive_b.connect("pressed", self, "_abrir_pendrive")
	add_child(_pendrive_b)
	var p: Dictionary = Jogo.partida
	if p.modo == "copa":
		_perguntar_quantos()
	else:
		_comecar(2)
	Jogo.musica_fundo()


## Os cartões dos times. A última vaga é a do TIME DO PENDRIVE: o time
## importado ou, sem time, um cartão vazio que carrega na hora.
func _montar_cartoes(animar: bool) -> void:
	for b in _cartoes:
		b.queue_free()
	_cartoes.clear()
	var lista: Array = Jogo.TIMES
	var por_linha := 6
	var larg := por_linha * CARTAO.x + (por_linha - 1) * 14.0
	var x0 := (1280.0 - larg) / 2.0
	var n := lista.size() + (0 if Jogo.tem_extra() else 1)
	for i in range(n):
		var b: Button = _cartao(lista[i]) if i < lista.size() else _cartao_vazio()
		UI.colocar(b, x0 + (i % por_linha) * (CARTAO.x + 14), 104 + (i / por_linha) * (CARTAO.y + 14), CARTAO.x, CARTAO.y)
		add_child(b)
		if animar:
			UI.pop(b, 0.05 + i * 0.03, 0.4, 0.5)
		_cartoes.append(b)


## Vaga vazia do time do pendrive: tocar abre o pendrive e carrega o logo.
func _cartao_vazio() -> Button:
	var b := UI.botao("", Color(0.04, 0.08, 0.16), Jogo.fonte("titan", 20))
	b.set_meta("sigla", "")
	b.connect("pressed", self, "_abrir_pendrive")
	for estilo in ["normal", "hover", "focus"]:
		var st: StyleBoxFlat = b.get_stylebox(estilo)
		st.border_color = Color(1, 1, 1, 0.35) if estilo != "focus" else Jogo.CIANO
		st.bg_color = Color(0.04, 0.08, 0.16, 0.75)
	var mais := UI.label("+", Jogo.fonte("titan", 84, 0), Color(1, 1, 1, 0.55))
	UI.colocar(mais, 0, 16, CARTAO.x, 96)
	b.add_child(mais)
	var n := UI.label("TIME DO\nPENDRIVE", Jogo.fonte("bungee", 17, 2), Color.white)
	UI.colocar(n, 0, 112, CARTAO.x, 56)
	b.add_child(n)
	var d := UI.label("VAZIO  •  TOQUE PARA\nCARREGAR O LOGO", Jogo.fonte("texto", 13, 0), Color(1, 1, 1, 0.65))
	UI.colocar(d, 0, 176, CARTAO.x, 44)
	b.add_child(d)
	return b


func _abrir_pendrive() -> void:
	if _saindo or _janela_pendrive != null:
		return
	_janela_pendrive = load("res://scripts/pendrive.gd").new()
	_janela_pendrive.connect("fechou", self, "_pendrive_fechou")
	add_child(_janela_pendrive)


func _pendrive_fechou() -> void:
	_janela_pendrive = null
	# o time pode ter entrado, mudado ou saído: refaz os cartões na hora
	for i in range(_escolha.size()):
		var sg: String = _escolha[i]
		if sg != "" and not _existe(sg):
			_escolha[i] = ""
	_montar_cartoes(false)
	if _n > 0:
		_mostrar_etapa()
	else:
		for b in _cartoes:
			b.visible = false
	var foco: Button = _cartoes[_cartoes.size() - 1]
	foco.call_deferred("grab_focus")


func _existe(sigla: String) -> bool:
	for t in Jogo.TIMES:
		if t.sigla == sigla:
			return true
	return false


func _comecar(n: int) -> void:
	_n = n
	_etapa = 0
	_escolha = []
	for _i in range(n):
		_escolha.append("")
	_mostrar_etapa()
	if not _cartoes.empty():
		_cartoes[0].call_deferred("grab_focus")


# ----------------------------------------------------- Copa: quantos jogadores
func _perguntar_quantos() -> void:
	_n = 0
	_titulo.text = "COPA: QUANTOS JOGADORES?"
	_dica.text = "Cada jogador escolhe um time. Jogo de dois jogadores: um em cada placa. O resto da chave é da CPU."
	for b in _cartoes:
		b.visible = false
	_confirmar.visible = false
	_pendrive_b.visible = false
	_quantos = Control.new()
	_quantos.anchor_right = 1
	_quantos.anchor_bottom = 1
	_quantos.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_quantos)
	for i in range(8):
		var b := UI.botao(str(i + 1), Jogo.AZUL if i > 0 else Jogo.VERDE, Jogo.fonte("titan", 64, 4))
		UI.colocar(b, 150 + (i % 4) * 250, 170 + (i / 4) * 210, 220, 180)
		b.connect("pressed", self, "_escolheu_quantos", [i + 1])
		_quantos.add_child(b)
		var l := UI.label("JOGADOR" if i == 0 else "JOGADORES", Jogo.fonte("bungee", 18, 2), Color(1, 1, 1, 0.85))
		UI.colocar(l, 0, 130, 220, 34)
		b.add_child(l)
		UI.pop(b, 0.05 + i * 0.04, 0.4, 0.6)
		if i == 0:
			b.call_deferred("grab_focus")


func _escolheu_quantos(n: int) -> void:
	Jogo.tocar("confirma")
	_quantos.queue_free()
	_quantos = null
	for b in _cartoes:
		b.visible = true
	_confirmar.visible = true
	_pendrive_b.visible = true
	_comecar(n)


# ------------------------------------------------------------- cartões
func _cartao(s: Dictionary) -> Button:
	var b := UI.botao("", Color(0.06, 0.12, 0.24), Jogo.fonte("titan", 20))
	b.connect("pressed", self, "_tocar_cartao", [s.sigla])
	b.set_meta("sigla", s.sigla)
	var emb := TextureRect.new()
	emb.texture = Jogo.emblema(s.sigla)
	emb.expand = true
	emb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UI.colocar(emb, (CARTAO.x - 96) / 2, 10, 96, 96)
	emb.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(emb)
	var tam := 18 if s.nome.length() <= 10 else (15 if s.nome.length() <= 13 else 13)
	var n := UI.label(s.nome, Jogo.fonte("bungee", tam, 2), Color.white)
	UI.colocar(n, 0, 106, CARTAO.x, 30)
	b.add_child(n)
	for k in range(ATRIB.size()):
		_barra(b, ATRIB[k][1], float(s[ATRIB[k][0]]), 140 + k * 18)
	for u in [1, 2]:
		var m := mini_botao(s.sigla, u, 34.0)
		m.rect_position = Vector2(CARTAO.x / 2 - 40 + (u - 1) * 46, 198)
		b.add_child(m)
	var tit := int(Jogo.titulos.get(s.sigla, 0))
	if tit > 0:
		var taca := TextureRect.new()
		taca.texture = load("res://imagens/trofeu.png")
		taca.expand = true
		UI.colocar(taca, CARTAO.x - 46, 10, 20, 28)
		taca.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(taca)
		var lt := UI.label(str(tit), Jogo.fonte("titan", 20, 2), Jogo.OURO, Label.ALIGN_LEFT)
		UI.colocar(lt, CARTAO.x - 24, 10, 22, 28)
		b.add_child(lt)
	return b


func _barra(pai: Control, nome: String, valor: float, y: float) -> void:
	var l := UI.label(nome, Jogo.fonte("texto", 12, 0), Color(1, 1, 1, 0.75), Label.ALIGN_LEFT)
	UI.colocar(l, 12, y - 2, 80, 16)
	pai.add_child(l)
	var fundo := ColorRect.new()
	fundo.color = Color(1, 1, 1, 0.12)
	UI.colocar(fundo, 86, y + 3, 70, 8)
	fundo.mouse_filter = MOUSE_FILTER_IGNORE
	pai.add_child(fundo)
	var nv := 0.12 + 0.88 * Jogo.nivel(valor)
	var cheio := ColorRect.new()
	cheio.color = Color(0.3, 0.9, 0.45).linear_interpolate(Jogo.OURO, Jogo.nivel(valor))
	UI.colocar(cheio, 86, y + 3, 70 * nv, 8)
	cheio.mouse_filter = MOUSE_FILTER_IGNORE
	pai.add_child(cheio)
	var num := UI.label(str(int(valor)), Jogo.fonte("bungee", 12, 0), Color.white, Label.ALIGN_RIGHT)
	UI.colocar(num, 150, y - 2, 30, 16)
	pai.add_child(num)


## O botãozinho de um uniforme (textura pronta ou cores do time do pendrive).
static func mini_botao(sigla: String, u: int, d: float) -> Control:
	var tex = Jogo.textura_botao(sigla, u)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand = true
		tr.rect_size = Vector2(d, d)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	return botao_de_cores(Jogo.cor_camisa(sigla, u), Jogo.cor_borda(sigla, u), Jogo.emblema(sigla), d)


static func botao_de_cores(camisa: Color, borda: Color, logo: Texture, d: float) -> Control:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = camisa
	s.border_color = borda
	s.set_border_width_all(int(max(2.0, d * 0.08)))
	s.set_corner_radius_all(int(d / 2))
	s.anti_aliasing = true
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 3
	p.add_stylebox_override("panel", s)
	p.rect_size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if logo != null:
		var l := TextureRect.new()
		l.texture = logo
		l.expand = true
		l.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		l.rect_position = Vector2(d * 0.17, d * 0.17)
		l.rect_size = Vector2(d * 0.66, d * 0.66)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
	return p


# ---------------------------------------------------------------- escolha
func _mostrar_etapa() -> void:
	var p: Dictionary = Jogo.partida
	var dois: bool = p.get("jogadores", 1) == 2
	if p.modo == "copa":
		_titulo.text = "COPA: ESCOLHA SEU TIME" if _n == 1 else "COPA  •  JOGADOR %d: ESCOLHA SEU TIME" % (_etapa + 1)
	elif _etapa == 0:
		_titulo.text = "JOGADOR 1: ESCOLHA SEU TIME" if dois else "ESCOLHA SEU TIME"
	else:
		_titulo.text = "JOGADOR 2: ESCOLHA O TIME" if dois else "ESCOLHA O ADVERSÁRIO (CPU)"
	var atual: String = _escolha[_etapa]
	_dica.text = "Manche escolhe o time, o BOTÃO confirma (aperte duas vezes)." if atual == "" else "%s escolhido  •  aperte o BOTÃO de novo (ou CONFIRMAR)" % Jogo.selecao(atual).nome
	UI.pop(_titulo, 0.0, 0.35, 0.6)
	for b in _cartoes:
		var sg: String = b.get_meta("sigla")
		if sg == "":
			continue
		var dono := _escolha.find(sg)
		b.disabled = dono >= 0 and dono < _etapa
		_destacar(b, sg == atual)
	_confirmar.disabled = atual == ""


func _destacar(b: Button, sim: bool) -> void:
	for estilo in ["normal", "hover", "focus"]:
		var s: StyleBoxFlat = b.get_stylebox(estilo)
		if estilo != "focus":
			s.border_color = Jogo.AMARELO if sim else Color(1, 1, 1, 0.85)
			s.set_border_width_all(6 if sim else 3)
		s.bg_color = Color(0.12, 0.3, 0.5) if sim else (Color(0.1, 0.2, 0.36) if estilo == "focus" else Color(0.06, 0.12, 0.24))
	b.rect_scale = Vector2(1.05, 1.05) if sim else Vector2.ONE
	b.rect_pivot_offset = b.rect_size / 2


func _tocar_cartao(sigla: String) -> void:
	if _saindo or _n == 0:
		return
	if _escolha[_etapa] == sigla:
		_confirmar_escolha()
		return
	_escolha[_etapa] = sigla
	Jogo.tocar("clique")
	_cenario.torcida.cores(Jogo.selecao(sigla).torcida, Jogo.selecao(sigla).torcida)
	_cenario.torcida.pular(0, 0.7, 1.2)
	_cenario.torcida.pular(1, 0.7, 1.2)
	_mostrar_etapa()


func _confirmar_escolha() -> void:
	if _saindo or _n == 0 or _escolha[_etapa] == "":
		return
	Jogo.tocar("confirma")
	if _etapa < _n - 1:
		_etapa += 1
		if _escolha[_etapa] in _escolha.slice(0, _etapa - 1):
			_escolha[_etapa] = ""
		_mostrar_etapa()
		# o foco vai para o primeiro cartão livre
		for b in _cartoes:
			if not b.disabled:
				b.grab_focus()
				break
		return
	_saindo = true
	var p: Dictionary = Jogo.partida
	if p.modo == "copa":
		Jogo.nova_copa(_escolha)
		Jogo.ir_para("res://cenas/chave.tscn")
		return
	var dois: bool = p.get("jogadores", 1) == 2
	p.casa = _escolha[0]
	p.fora = _escolha[1]
	p.controle = [1, 2] if dois else [3, 0]
	p.humano = [true, dois]
	p.penaltis = false
	p.ida = {}
	p.clima = Jogo.escolher_clima()
	p.estadio = p.casa
	# amistoso: escolhe o estádio (ou sorteia) e tem a apresentação 3D
	Jogo.ir_para("res://cenas/estadio_escolha.tscn")


func _voltar() -> void:
	if _saindo:
		return
	Jogo.tocar("volta")
	if _n > 0 and _etapa > 0:
		_etapa -= 1
		_mostrar_etapa()
		return
	if _n > 0 and Jogo.partida.modo == "copa":
		_perguntar_quantos()
		return
	_saindo = true
	Jogo.ir_para("res://cenas/menu.tscn")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_voltar()
