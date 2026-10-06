extends Control

## MENU: AMISTOSO (1 jogador contra a CPU ou 2 jogadores) ou COPA (mata-mata
## de 8 times em ida e volta). CAMPEÕES: quantas Copas cada time ganhou.
## OPÇÕES: tempo de jogo, dificuldade, toques por vez, tempo para jogar,
## volumes e a configuração dos controles (manches).
## Tudo funciona pelo toque ou pelo manche (direções + CHUTE).

const UI = preload("res://scripts/ui.gd")
const Cenario = preload("res://scripts/cenario.gd")

const OPCOES := [
	{"chave": "minutos", "nome": "TEMPO DE CADA TEMPO", "valores": [2, 3, 5, 8], "fmt": "%d min"},
	{"chave": "dificuldade", "nome": "DIFICULDADE DA CPU", "valores": [0, 1, 2], "nomes": ["FÁCIL", "MÉDIO", "DIFÍCIL"]},
	{"chave": "toques", "nome": "TOQUES NA BOLA POR VEZ", "valores": [3, 4, 5, 12], "fmt": "%d"},
	{"chave": "relogio_vez", "nome": "SEGUNDOS PARA JOGAR", "valores": [15, 20, 30, 45], "fmt": "%d s"},
	{"chave": "clima", "nome": "CLIMA DAS PARTIDAS", "valores": [0, 1, 2, 3, 4], "nomes": ["SORTEADO", "DIA DE SOL", "DIA DE CHUVA", "NOITE", "NOITE COM CHUVA"]},
	{"chave": "perspectiva", "nome": "VISÃO DA MESA", "valores": [1, 0], "nomes": ["DE CIMA", "TV (PERSPECTIVA)"]},
	{"chave": "volume_musica", "nome": "VOLUME DA MÚSICA", "valores": [0, 30, 50, 70, 100], "fmt": "%d%%"},
	{"chave": "volume_efeitos", "nome": "VOLUME DOS EFEITOS", "valores": [0, 30, 50, 70, 100], "fmt": "%d%%"},
]

var _camada: Control
var _valores := []
var _nas_opcoes := false
var _segredo := []         # instantes dos últimos toques/ESQUERDAs (time do pendrive)
var _pendrive: Control


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var c = Cenario.new()
	add_child(c)
	var logo := TextureRect.new()
	logo.texture = load("res://imagens/logo.png")
	logo.expand = true
	UI.colocar(logo, 640 - 250, 18, 500, 186)
	logo.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(logo)
	UI.pop(logo, 0.05)
	_camada = Control.new()
	_camada.anchor_right = 1
	_camada.anchor_bottom = 1
	_camada.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_camada)
	_principal()
	Jogo.musica_fundo()
	Jogo.ambiente(0.0)


func _limpar() -> void:
	_nas_opcoes = false
	for n in _camada.get_children():
		n.queue_free()


func _cartao(titulo: String, sub: String, cor: Color, pos: Vector2, icone: Texture, metodo: String, args := []) -> Button:
	var b := UI.botao("", cor, Jogo.fonte("titan", 20))
	UI.colocar(b, pos.x, pos.y, 440, 300)
	b.connect("pressed", self, metodo, args)
	_camada.add_child(b)
	if icone != null:
		var ic := TextureRect.new()
		ic.texture = icone
		ic.expand = true
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		UI.colocar(ic, 20, 18, 400, 140)
		ic.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(ic)
	var t := UI.label(titulo, Jogo.fonte("titan", 44, 4), Color.white)
	UI.colocar(t, 0, 160, 440, 64)
	b.add_child(t)
	var s := UI.label(sub, Jogo.fonte("bungee", 17, 2), Color(1, 1, 1, 0.9))
	UI.colocar(s, 0, 222, 440, 60)
	s.autowrap = false
	b.add_child(s)
	return b


func _principal() -> void:
	_limpar()
	var a := _cartao("AMISTOSO", "1 JOGADOR x CPU\nOU 2 JOGADORES", Color(0.05, 0.55, 0.25), Vector2(160, 230), load("res://imagens/bola.png"), "_amistoso")
	var c := _cartao("COPA", "ATÉ 8 JOGADORES\nIDA E VOLTA • RUMO À TAÇA!", Color(0.75, 0.5, 0.05), Vector2(680, 230), load("res://imagens/trofeu.png"), "_copa")
	UI.deslizar(a, Vector2(-500, 0), 0.1)
	UI.deslizar(c, Vector2(500, 0), 0.15)
	var o := UI.botao("OPÇÕES", Color(0.15, 0.25, 0.45), Jogo.fonte("titan", 28, 2))
	UI.colocar(o, 310, 560, 210, 70)
	o.connect("pressed", self, "_opcoes")
	_camada.add_child(o)
	var cp := UI.botao("CAMPEÕES", Color(0.5, 0.36, 0.05), Jogo.fonte("titan", 28, 2))
	UI.colocar(cp, 535, 560, 210, 70)
	cp.connect("pressed", self, "_campeoes")
	_camada.add_child(cp)
	var v := UI.botao("VOLTAR", Color(0.3, 0.1, 0.1), Jogo.fonte("titan", 28, 2))
	UI.colocar(v, 760, 560, 210, 70)
	v.connect("pressed", self, "_voltar")
	_camada.add_child(v)
	a.call_deferred("grab_focus")


func _amistoso() -> void:
	Jogo.tocar("clique")
	_limpar()
	var t := UI.label("AMISTOSO", Jogo.fonte("titan", 50, 5), Color.white)
	UI.colocar(t, 0, 200, 1280, 70)
	_camada.add_child(t)
	var a := _cartao("1 JOGADOR", "VOCÊ CONTRA\nO COMPUTADOR", Color(0.1, 0.4, 0.8), Vector2(160, 280), load("res://imagens/botao_bra_1.png"), "_comecar_amistoso", [1])
	var b := _cartao("2 JOGADORES", "UM CONTRA O OUTRO\nNA MESMA TELA", Color(0.7, 0.15, 0.2), Vector2(680, 280), load("res://imagens/botao_arg_1.png"), "_comecar_amistoso", [2])
	a.rect_size.y = 280
	b.rect_size.y = 280
	UI.pop(a, 0.05)
	UI.pop(b, 0.12)
	var v := UI.botao("VOLTAR", Color(0.3, 0.1, 0.1), Jogo.fonte("titan", 28, 2))
	UI.colocar(v, 545, 600, 190, 66)
	v.connect("pressed", self, "_principal_som")
	_camada.add_child(v)
	a.call_deferred("grab_focus")


func _principal_som() -> void:
	Jogo.tocar("volta")
	_principal()


func _comecar_amistoso(jogadores: int) -> void:
	Jogo.tocar("confirma")
	Jogo.partida = {"modo": "amistoso", "jogadores": jogadores, "casa": "BRA", "fora": "ARG", "humano": [true, jogadores == 2],
		"controle": [1, 2] if jogadores == 2 else [3, 0], "penaltis": false, "ida": {}}
	Jogo.ir_para("res://cenas/selecao.tscn")


func _copa() -> void:
	Jogo.tocar("confirma")
	Jogo.partida = {"modo": "copa", "jogadores": 1, "casa": "BRA", "fora": "ARG", "humano": [true, false], "controle": [1, 0], "penaltis": false, "ida": {}}
	Jogo.copa = {}
	Jogo.ir_para("res://cenas/selecao.tscn")


func _voltar() -> void:
	Jogo.tocar("volta")
	Jogo.ir_para("res://cenas/abertura.tscn")


# ---------------------------------------------------------------- opções
func _opcoes() -> void:
	Jogo.tocar("clique")
	_limpar()
	var p := UI.painel(Jogo.CIANO, Color(0.02, 0.05, 0.12, 0.94), 22, 3, 16)
	UI.colocar(p, 190, 200, 900, 510)
	_camada.add_child(p)
	UI.pop(p, 0.02, 0.35, 0.8)
	var t := UI.label("OPÇÕES  (toque para mudar)", Jogo.fonte("titan", 30, 3), Color.white)
	UI.colocar(t, 0, 10, 900, 50)
	p.add_child(t)
	# acesso escondido do operador: 5 toques no título (ou ESQUERDA 5 vezes)
	var seg := Button.new()
	seg.flat = true
	seg.focus_mode = Control.FOCUS_NONE
	seg.modulate.a = 0.0
	UI.colocar(seg, 250, 6, 400, 50)
	seg.connect("pressed", self, "_toque_segredo")
	p.add_child(seg)
	_nas_opcoes = true
	_valores.clear()
	for i in range(OPCOES.size()):
		var o: Dictionary = OPCOES[i]
		var b := UI.botao("", Color(0.08, 0.16, 0.3), Jogo.fonte("titan", 20))
		UI.colocar(b, 30, 60 + i * 46, 840, 40)
		b.connect("pressed", self, "_mudar", [i])
		p.add_child(b)
		if i == 0:
			b.call_deferred("grab_focus")
		var n := UI.label(o.nome, Jogo.fonte("bungee", 20, 2), Color.white, Label.ALIGN_LEFT)
		UI.colocar(n, 22, 0, 560, 40)
		b.add_child(n)
		var v := UI.label("", Jogo.fonte("titan", 26, 2), Jogo.AMARELO, Label.ALIGN_RIGHT)
		UI.colocar(v, 560, 0, 258, 40)
		b.add_child(v)
		_valores.append(v)
	_mostrar_valores()
	var ctl := UI.botao("CONFIGURAR CONTROLES", Color(0.15, 0.25, 0.45), Jogo.fonte("titan", 22, 2))
	UI.colocar(ctl, 150, 440, 340, 56)
	ctl.connect("pressed", self, "_controles")
	p.add_child(ctl)
	var ok := UI.botao("PRONTO", Jogo.VERDE, Jogo.fonte("titan", 28, 2))
	UI.colocar(ok, 530, 440, 220, 56)
	ok.connect("pressed", self, "_salvar_opcoes")
	p.add_child(ok)


func _toque_segredo() -> void:
	var agora := OS.get_ticks_msec()
	_segredo.append(agora)
	while not _segredo.empty() and agora - _segredo[0] > 3000:
		_segredo.pop_front()
	if _segredo.size() >= 5 and _pendrive == null:
		_segredo.clear()
		_pendrive = preload("res://scripts/pendrive.gd").new()
		_pendrive.connect("fechou", self, "_pendrive_fechou")
		add_child(_pendrive)


func _pendrive_fechou() -> void:
	_pendrive = null
	_opcoes()


func _input(ev: InputEvent) -> void:
	if _nas_opcoes and _pendrive == null and ev.is_action_pressed("ui_left") and not ev.is_echo():
		_toque_segredo()


func _mostrar_valores() -> void:
	for i in range(OPCOES.size()):
		var o: Dictionary = OPCOES[i]
		var x = Jogo.config[o.chave]
		if o.has("nomes"):
			_valores[i].text = o.nomes[int(x)]
		else:
			_valores[i].text = o.fmt % x


func _mudar(i: int) -> void:
	var o: Dictionary = OPCOES[i]
	var vals: Array = o.valores
	var idx := vals.find(Jogo.config[o.chave])
	Jogo.config[o.chave] = vals[(idx + 1) % vals.size()]
	Jogo.tocar("clique")
	_mostrar_valores()
	UI.pulsar(_valores[i], 0.25)
	if o.chave.begins_with("volume"):
		Jogo.salvar_config()


func _controles() -> void:
	Jogo.salvar_config()
	Jogo.tocar("confirma")
	Jogo.ir_para("res://cenas/controles.tscn")


# -------------------------------------------------------------- campeões
func _campeoes() -> void:
	Jogo.tocar("clique")
	_limpar()
	var p := UI.painel(Jogo.OURO, Color(0.02, 0.05, 0.12, 0.94), 22, 3, 16)
	UI.colocar(p, 240, 206, 800, 494)
	_camada.add_child(p)
	UI.pop(p, 0.02, 0.35, 0.8)
	var t := UI.label("CAMPEÕES DA COPA", Jogo.fonte("titan", 34, 3), Jogo.OURO)
	UI.colocar(t, 0, 8, 800, 52)
	p.add_child(t)
	var ranking = Jogo.ranking_titulos()
	if ranking.empty():
		var l := UI.label("Nenhuma Copa decidida ainda.\nSeja o primeiro campeão!", Jogo.fonte("bungee", 24, 2), Color(1, 1, 1, 0.85))
		UI.colocar(l, 0, 120, 800, 200)
		p.add_child(l)
	for i in range(min(ranking.size(), 12)):
		var sg: String = ranking[i][0]
		var n: int = ranking[i][1]
		var col := i / 6
		var lin := i % 6
		var x := 30.0 + col * 380.0
		var y := 68.0 + lin * 56.0
		var pos := UI.label("%dº" % (i + 1), Jogo.fonte("bungee", 20, 2), Jogo.OURO if i == 0 else Color.white, Label.ALIGN_RIGHT)
		UI.colocar(pos, x, y, 40, 48)
		p.add_child(pos)
		var e := TextureRect.new()
		e.texture = Jogo.emblema(sg)
		e.expand = true
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		UI.colocar(e, x + 48, y + 2, 44, 44)
		e.mouse_filter = MOUSE_FILTER_IGNORE
		p.add_child(e)
		var nm := UI.label(Jogo.selecao(sg).nome, Jogo.fonte("bungee", 18, 2), Color.white, Label.ALIGN_LEFT)
		UI.colocar(nm, x + 100, y, 180, 48)
		p.add_child(nm)
		var taca := TextureRect.new()
		taca.texture = load("res://imagens/trofeu.png")
		taca.expand = true
		UI.colocar(taca, x + 282, y + 8, 22, 31)
		taca.mouse_filter = MOUSE_FILTER_IGNORE
		p.add_child(taca)
		var q := UI.label("%d" % n, Jogo.fonte("titan", 28, 3), Jogo.OURO, Label.ALIGN_LEFT)
		UI.colocar(q, x + 310, y, 50, 48)
		p.add_child(q)
		UI.pop(e, 0.1 + i * 0.05)
	var v := UI.botao("VOLTAR", Jogo.AZUL, Jogo.fonte("titan", 26, 2))
	UI.colocar(v, 430, 418, 200, 58)
	v.connect("pressed", self, "_principal_som")
	p.add_child(v)
	v.call_deferred("grab_focus")
	if not ranking.empty():
		var z := UI.botao("ZERAR", Color(0.4, 0.1, 0.1), Jogo.fonte("titan", 22, 2))
		UI.colocar(z, 170, 418, 200, 58)
		z.connect("pressed", self, "_zerar", [z])
		p.add_child(z)


func _zerar(b: Button) -> void:
	# dois toques: o primeiro pede confirmação
	if b.text != "CONFIRMAR?":
		b.text = "CONFIRMAR?"
		Jogo.tocar("clique")
		return
	Jogo.zerar_titulos()
	Jogo.tocar("volta")
	_campeoes()


func _salvar_opcoes() -> void:
	Jogo.salvar_config()
	Jogo.tocar("confirma")
	_principal()


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_voltar()
