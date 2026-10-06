extends Control

## ESCOLHA DO ESTÁDIO (amistoso): a miniatura de cada estádio (a vista da
## cidade dele, como na apresentação), o nome, a cidade e o país, e o cartão
## SORTEAR. Manche anda pelos cartões, o BOTÃO escolhe. Depois vem a
## apresentação 3D no estádio escolhido.

const UI = preload("res://scripts/ui.gd")
const Cenario = preload("res://scripts/cenario.gd")

const CARTAO := Vector2(284, 188)
const SORTEIO := "?"

var _cartoes := []
var _saindo := false
var _info: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var p: Dictionary = Jogo.partida
	var cen = Cenario.new()
	cen.escurecer = 0.7
	cen.sigla = p.get("casa", "BRA")
	add_child(cen)
	var titulo := UI.label("ESCOLHA O ESTÁDIO", Jogo.fonte("titan", 44, 5), Color.white)
	UI.colocar(titulo, 0, 10, 1280, 60)
	add_child(titulo)
	_info = UI.label("Manche escolhe  •  BOTÃO confirma", Jogo.fonte("texto", 19, 1), Color(1, 1, 1, 0.8))
	UI.colocar(_info, 0, 64, 1280, 26)
	add_child(_info)
	var lista := []
	for s in Jogo.TIMES:
		lista.append(s.sigla)
	lista.append(SORTEIO)
	var por_linha := 4
	var linhas := int(ceil(lista.size() / float(por_linha)))
	var k: float = min(1.0, 3.0 / max(3.0, float(linhas)))
	var tam := CARTAO * k
	var larg := por_linha * tam.x + (por_linha - 1) * 14.0
	var x0 := (1280.0 - larg) / 2.0
	var foco = null
	for i in range(lista.size()):
		var b := _cartao(lista[i], tam)
		UI.colocar(b, x0 + (i % por_linha) * (tam.x + 14.0), 100 + (i / por_linha) * (tam.y + 10.0), tam.x, tam.y)
		add_child(b)
		UI.pop(b, 0.04 + i * 0.025, 0.35, 0.6)
		_cartoes.append(b)
		if lista[i] == p.get("casa", ""):
			foco = b
	var voltar := UI.botao("VOLTAR", Color(0.3, 0.1, 0.1), Jogo.fonte("titan", 26, 2))
	UI.colocar(voltar, 24, 18, 170, 50)
	voltar.connect("pressed", self, "_voltar")
	add_child(voltar)
	if foco == null:
		foco = _cartoes[0]
	foco.call_deferred("grab_focus")
	Jogo.musica_fundo()


func _cartao(sigla: String, tam: Vector2) -> Button:
	var b := UI.botao("", Color(0.05, 0.1, 0.2), Jogo.fonte("titan", 20))
	b.connect("pressed", self, "_escolher", [sigla])
	b.connect("focus_entered", self, "_focou", [b, sigla])
	b.connect("mouse_entered", self, "_focou", [b, sigla])
	b.set_meta("sigla", sigla)
	var m := 8.0
	var foto_h := tam.y - 62.0
	if sigla == SORTEIO:
		var q := UI.label("?", Jogo.fonte("titan", 96, 5), Jogo.OURO)
		UI.colocar(q, 0, 4, tam.x, foto_h)
		b.add_child(q)
		var n := UI.label("SORTEAR", Jogo.fonte("bungee", 20, 2), Color.white)
		UI.colocar(n, 0, tam.y - 56, tam.x, 28)
		b.add_child(n)
		var c := UI.label("um estádio qualquer", Jogo.fonte("texto", 15, 1), Color(1, 1, 1, 0.7))
		UI.colocar(c, 0, tam.y - 30, tam.x, 22)
		b.add_child(c)
		return b
	var s := Jogo.selecao(sigla)
	var foto := TextureRect.new()
	var tex: Texture = null
	var arq := "res://imagens/estadios/mini_%s.jpg" % sigla.to_lower()
	if not s.get("extra", false) and ResourceLoader.exists(arq):
		tex = load(arq)
	foto.texture = tex if tex != null else Jogo.estadio(sigla, true)
	foto.expand = true
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UI.colocar(foto, m, m, tam.x - m * 2.0, foto_h - m)
	foto.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(foto)
	var e := TextureRect.new()
	e.texture = Jogo.emblema(sigla)
	e.expand = true
	e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UI.colocar(e, m + 4, m + 4, 34, 34)
	e.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(e)
	var nome: String = s.estadio
	var tam_f := 17 if nome.length() <= 18 else 14
	var n2 := UI.label(nome, Jogo.fonte("bungee", tam_f, 2), Color.white)
	UI.colocar(n2, 4, tam.y - 56, tam.x - 8, 28)
	b.add_child(n2)
	var c2 := UI.label(local_texto(sigla), Jogo.fonte("texto", 15, 1), Jogo.OURO)
	UI.colocar(c2, 4, tam.y - 30, tam.x - 8, 22)
	b.add_child(c2)
	return b


## "RIO DE JANEIRO • BRASIL" (time do pendrive: só o nome do time).
static func local_texto(sigla: String) -> String:
	var s := Jogo.selecao(sigla)
	if s.get("cidade", "") == "":
		return s.nome
	return "%s  •  %s" % [s.cidade, s.pais]


func _focou(b: Button, sigla: String) -> void:
	for c in _cartoes:
		var sim: bool = c == b
		c.rect_pivot_offset = c.rect_size / 2
		c.rect_scale = Vector2(1.05, 1.05) if sim else Vector2.ONE
		if sim:
			c.raise()
		for estilo in ["normal", "hover", "focus"]:
			var st: StyleBoxFlat = c.get_stylebox(estilo)
			st.border_color = Jogo.AMARELO if sim else Color(1, 1, 1, 0.7)
			st.set_border_width_all(5 if sim else 2)
	if sigla == SORTEIO:
		_info.text = "SORTEAR: o jogo escolhe o estádio  •  BOTÃO confirma"
	else:
		_info.text = "%s  —  %s  •  BOTÃO confirma" % [Jogo.selecao(sigla).estadio, local_texto(sigla)]


func _escolher(sigla: String) -> void:
	if _saindo:
		return
	_saindo = true
	Jogo.tocar("confirma")
	if sigla == SORTEIO:
		var lista := []
		for s in Jogo.TIMES:
			lista.append(s.sigla)
		sigla = lista[randi() % lista.size()]
	Jogo.partida["estadio"] = sigla
	Jogo.ir_para("res://cenas/preparacao.tscn")


func _voltar() -> void:
	if _saindo:
		return
	_saindo = true
	Jogo.tocar("volta")
	Jogo.ir_para("res://cenas/selecao.tscn")


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		_voltar()


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_voltar()
