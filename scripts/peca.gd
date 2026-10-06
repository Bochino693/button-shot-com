extends Node2D

## Desenho de uma peça: sombra, brilho do "embalo", anel de vez/seleção,
## o botão (ou o goleiro caixinha). Times do jogo: textura pronta com o
## escudo. Time do pendrive: camadas brancas pintadas com as cores do logo e
## o logo no centro. A posição segue o corpo da física.

const Campo = preload("res://scripts/campo.gd")
const Corpo = preload("res://scripts/corpo.gd")
const CartaoTazo = preload("res://scripts/cartao_tazo.gd")

var corpo
var sprite: Node2D
var anel: Sprite
var sombra: Sprite
var aura: Sprite
var _t := 0.0
var destaque := false setget _set_destaque          # é a vez do time
var selecionado := false setget _set_selecionado    # o botão que vai jogar
var embalo := false setget _set_embalo
var cor_embalo := Color(1, 0.6, 0.1)
var suave := 0.0          # >0: desliza até a posição (cobrança posicionada)


## tex: textura pronta; ou camadas {camisa, borda, logo, goleiro} (time do pendrive).
func montar(c, tex: Texture, camadas := {}) -> void:
	corpo = c
	position = c.pos
	sombra = Sprite.new()
	sombra.texture = load("res://imagens/sombra.png")
	sombra.position = Vector2(3, 5)
	sombra.modulate = Color(1, 1, 1, 0.55)
	add_child(sombra)
	aura = Sprite.new()
	aura.texture = load("res://imagens/brilho.png")
	var ad := CanvasItemMaterial.new()
	ad.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.material = ad
	aura.visible = false
	add_child(aura)
	anel = Sprite.new()
	anel.texture = load("res://imagens/anel.png")
	anel.visible = false
	add_child(anel)
	if c.tipo == Corpo.GOLEIRO:
		var s := Sprite.new()
		s.texture = tex
		var w := (Campo.GOLEIRO_RAIO + 2.0) * 2.0
		var h: float = (c.meio + Campo.GOLEIRO_RAIO + 2.0) * 2.0
		s.scale = Vector2(w / tex.get_width(), h / tex.get_height())
		if camadas.has("goleiro"):
			s.modulate = camadas.goleiro
		sombra.scale = Vector2(w * 1.4, h * 1.25) / sombra.texture.get_width()
		sprite = s
		add_child(s)
	elif c.tipo == Corpo.BOLA:
		var s2 := Sprite.new()
		s2.texture = tex
		var d: float = c.raio * 2.3
		s2.scale = Vector2.ONE * d / tex.get_width()
		sombra.scale = Vector2.ONE * d * 1.5 / sombra.texture.get_width()
		sombra.position = Vector2(2, 3)
		sprite = s2
		add_child(s2)
	else:
		var d2: float = c.raio * 2.0
		sombra.scale = Vector2.ONE * d2 * 1.55 / sombra.texture.get_width()
		anel.scale = Vector2.ONE * d2 * 1.9 / anel.texture.get_width()
		aura.scale = Vector2.ONE * d2 * 2.6 / aura.texture.get_width()
		if tex != null:
			var s3 := Sprite.new()
			s3.texture = tex
			s3.scale = Vector2.ONE * d2 / tex.get_width()
			sprite = s3
			add_child(s3)
		else:
			sprite = _camadas(d2, camadas)
			add_child(sprite)


func _camadas(d: float, c: Dictionary) -> Node2D:
	var n := Node2D.new()
	for par in [["botao_face", c.get("camisa", Color.white)], ["botao_aro", c.get("borda", Color.gray)]]:
		var s := Sprite.new()
		s.texture = load("res://imagens/%s.png" % par[0])
		s.scale = Vector2.ONE * d / s.texture.get_width()
		s.modulate = par[1]
		n.add_child(s)
	var logo: Texture = c.get("logo")
	if logo != null:
		var l := Sprite.new()
		l.texture = logo
		var k: float = d * 0.66 / max(logo.get_width(), logo.get_height())
		l.scale = Vector2.ONE * k
		n.add_child(l)
	var br := Sprite.new()
	br.texture = load("res://imagens/botao_brilho.png")
	br.scale = Vector2.ONE * d / br.texture.get_width()
	n.add_child(br)
	return n


## Cartão amarelo: um cartãozinho preso na borda do tazo até o fim da
## partida (quem tem amarelo e faz outra falta é expulso).
var cartao: Node2D


func marcar_amarelo() -> void:
	if cartao != null:
		return
	cartao = CartaoTazo.new()
	var r: float = corpo.raio
	cartao.alto = r * 0.95
	cartao.position = Vector2(r * 0.72, -r * 0.72)
	cartao.rotation_degrees = 14.0
	add_child(cartao)
	var tw := Tween.new()
	cartao.add_child(tw)
	tw.interpolate_property(cartao, "scale", Vector2.ONE * 2.4, Vector2.ONE, 0.45, Tween.TRANS_BACK, Tween.EASE_OUT)
	tw.start()


func _set_destaque(v: bool) -> void:
	destaque = v
	_atualizar_anel()


func _set_selecionado(v: bool) -> void:
	selecionado = v
	_atualizar_anel()


func _set_embalo(v: bool) -> void:
	embalo = v
	if aura:
		aura.visible = v


func _atualizar_anel() -> void:
	if anel:
		anel.visible = destaque or selecionado
		anel.modulate = Color(1, 0.9, 0.25) if selecionado else Color(1, 1, 1, 0.5)


func _process(delta: float) -> void:
	if corpo == null:
		return
	if suave > 0.0:
		suave -= delta
		position = position.linear_interpolate(corpo.pos, min(1.0, delta * 10.0))
	else:
		position = corpo.pos
	if corpo.tipo == Corpo.BOLA and corpo.vel.length_squared() > 1.0:
		sprite.rotation += corpo.vel.length() * delta / corpo.raio * sign(corpo.vel.x + 0.001)
	if anel.visible or aura.visible:
		_t += delta
		var base: float = corpo.raio * 2.0 * 1.9 / anel.texture.get_width()
		if selecionado:
			anel.scale = Vector2.ONE * base * (1.08 + sin(_t * 8.0) * 0.1)
		elif destaque:
			anel.scale = Vector2.ONE * base * (1.0 + sin(_t * 5.0) * 0.05)
		if aura.visible:
			aura.modulate = Color(cor_embalo.r, cor_embalo.g, cor_embalo.b, 0.45 + sin(_t * 7.0) * 0.2)
