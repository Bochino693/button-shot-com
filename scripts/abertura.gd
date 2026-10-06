extends Control

## TELA DE ABERTURA: estádio com a torcida, o logo pulando, os botões dos
## times girando em roda, os campeões da Copa (quantos títulos cada time tem)
## e "TOQUE PARA JOGAR" (ou qualquer botão do manche). Batucada ao fundo.

const UI = preload("res://scripts/ui.gd")
const Cenario = preload("res://scripts/cenario.gd")

var _logo: TextureRect
var _chamada: Label
var _roda := []
var _bola: Sprite
var _t := 0.0
var _saindo := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var c = Cenario.new()
	c.escurecer = 0.5
	add_child(c)

	# botões das seleções em roda (atrás do logo)
	var n := 0
	for s in Jogo.TIMES:
		if Jogo.textura_botao(s.sigla, 1) != null:
			n += 1
	for s in Jogo.TIMES:
		var tex = Jogo.textura_botao(s.sigla, 1)
		if tex == null:
			continue
		var sp := Sprite.new()
		sp.texture = tex
		sp.scale = Vector2.ONE * 80.0 / tex.get_width()
		var sombra := Sprite.new()
		sombra.texture = load("res://imagens/sombra.png")
		var k: float = tex.get_width() / 128.0
		sombra.position = Vector2(8, 12) * k
		sombra.scale = Vector2.ONE * 192.0 * k / sombra.texture.get_width()
		sombra.modulate.a = 0.6
		sombra.show_behind_parent = true
		sp.add_child(sombra)
		add_child(sp)
		_roda.append(sp)
	_bola = Sprite.new()
	_bola.texture = load("res://imagens/bola.png")
	_bola.scale = Vector2(0.9, 0.9)
	add_child(_bola)

	_logo = TextureRect.new()
	_logo.texture = load("res://imagens/logo.png")
	_logo.expand = true
	UI.colocar(_logo, 640 - 430, 120, 860, 320)
	_logo.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_logo)
	UI.pop(_logo, 0.2, 0.8, 0.1)

	_chamada = UI.label("APERTE O BOTÃO PARA JOGAR", Jogo.fonte("titan", 54, 6), Jogo.AMARELO)
	UI.colocar(_chamada, 0, 560, 1280, 80)
	add_child(_chamada)
	UI.pop(_chamada, 0.9)
	_campeoes()

	var marca := TextureRect.new()
	marca.texture = load("res://imagens/logo_lazer_sport.png")
	marca.expand = true
	marca.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UI.colocar(marca, 1100, 640, 160, 72)
	marca.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(marca)

	Jogo.ambiente(0.0)
	Jogo.musica_fundo()
	Jogo.preaquecer_ceus()


## Faixa dos campeões: escudo + taça + nº de títulos, do mais campeão.
func _campeoes() -> void:
	var r := Jogo.ranking_titulos()
	if r.empty():
		return
	var n := int(min(r.size(), 8))
	var passo := 116.0
	var larg := n * passo + 150.0
	var x0 := (1280.0 - larg) / 2.0
	var p := UI.painel(Jogo.OURO, Color(0.02, 0.04, 0.1, 0.8), 16, 2, 10)
	UI.colocar(p, x0, 452, larg, 64)
	add_child(p)
	UI.pop(p, 1.1, 0.4, 0.7)
	var t := UI.label("CAMPEÕES", Jogo.fonte("bungee", 18, 2), Jogo.OURO)
	UI.colocar(t, 8, 0, 134, 64)
	p.add_child(t)
	for i in range(n):
		var x := 150.0 + i * passo
		var e := TextureRect.new()
		e.texture = Jogo.emblema(r[i][0])
		e.expand = true
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		UI.colocar(e, x, 8, 48, 48)
		e.mouse_filter = MOUSE_FILTER_IGNORE
		p.add_child(e)
		var taca := TextureRect.new()
		taca.texture = load("res://imagens/trofeu.png")
		taca.expand = true
		UI.colocar(taca, x + 52, 16, 20, 28)
		taca.mouse_filter = MOUSE_FILTER_IGNORE
		p.add_child(taca)
		var q := UI.label(str(r[i][1]), Jogo.fonte("titan", 24, 2), Color.white, Label.ALIGN_LEFT)
		UI.colocar(q, x + 76, 0, 40, 64)
		p.add_child(q)


func _process(delta: float) -> void:
	_t += delta
	var n := _roda.size()
	for i in range(n):
		var a := _t * 0.35 + TAU * i / n
		var sp: Sprite = _roda[i]
		sp.position = Vector2(640, 300) + Vector2(cos(a) * 520, sin(a) * 250)
		# os da frente ficam maiores e por cima
		var frente := (sin(a) + 1.0) * 0.5
		sp.scale = Vector2.ONE * (0.42 + 0.3 * frente) * 128.0 / sp.texture.get_width()
		sp.z_index = -1 if frente < 0.5 else 1
		sp.modulate = Color(1, 1, 1, 0.55 + 0.45 * frente)
	var ab := _t * 1.3
	_bola.position = Vector2(640 + sin(ab) * 380, 520 + abs(sin(ab * 2.0)) * -40)
	_bola.rotation += delta * 4.0 * cos(ab)
	_logo.rect_rotation = sin(_t * 1.5) * 1.5
	_chamada.modulate.a = 0.55 + abs(sin(_t * 2.5)) * 0.45


func _unhandled_input(ev: InputEvent) -> void:
	if _saindo:
		return
	var tocou = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventKey and ev.pressed and not ev.echo) \
		or (ev is InputEventJoypadButton and ev.pressed) or ev.is_action_pressed("ui_accept")
	if tocou and _t > 0.6:
		_saindo = true
		Jogo.tocar("game_start")
		Jogo.parar_musica(0.4)
		Jogo.ir_para("res://cenas/menu.tscn")
