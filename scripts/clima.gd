extends Node2D

## CLIMA DA PARTIDA: dia ou noite, com ou sem chuva: "sol" (dia), "chuva"
## (dia com chuva), "noite" e "noite_chuva". As camadas de luz e a chuva
## ficam por cima da mesa (embaixo do placar); respingos e graminhas ficam
## no CHÃO, por baixo da bola e dos botões.
##   chuva: céu cinza, riscos de chuva caindo, ondinhas nas poças, respingos
##          quando bola e botões andam (e a bola corre menos: partida.gd).
##   sol:   luz quente e sombra mais comprida; grama seca: graminhas voam.
##   noite: tudo escuro, só o campo iluminado pelos 4 refletores; graminhas.
## explosao(pos, forca) e rastro(corpo) são chamados pela partida.

const Campo = preload("res://scripts/campo.gd")

const REFLETORES := [Vector2(40, 30), Vector2(1240, 30), Vector2(40, 690), Vector2(1240, 690)]
const NOMES := {"sol": "DIA DE SOL", "chuva": "DIA DE CHUVA", "noite": "NOITE", "noite_chuva": "NOITE COM CHUVA"}
const TIPOS := ["sol", "chuva", "noite", "noite_chuva"]

var tipo := "sol"
var _pool := []
var _prox := 0
var _ultimo := {}          # corpo -> tempo do último rastro
var _t := 0.0


static func sortear() -> String:
	return TIPOS[randi() % TIPOS.size()]


static func chove(t: String) -> bool:
	return t == "chuva" or t == "noite_chuva"


static func de_noite(t: String) -> bool:
	return t.begins_with("noite")


## Atrito da bola neste clima (a chuva segura a bola).
static func piso(t: String) -> float:
	return 1.5 if chove(t) else 1.0


var _chao: Node2D


## chao: camada por baixo das peças (respingos e graminhas).
func montar(t: String, chao: Node2D = null) -> void:
	tipo = t
	_chao = chao if chao != null else self
	if de_noite(tipo):
		_camada_mul(load("res://imagens/noite.png"), Color.white)
		if chove(tipo):
			_camada_mul(null, Color(0.8, 0.84, 0.92))
		# os 4 refletores: lâmpada forte, halo, e o facho de luz cruzando o
		# gramado (aditivo, suave): equilibra a luz da noite
		for r in REFLETORES:
			_facho(r)
			# lâmpada sutil: halo curto e fraco (sem "estourar" o canto)
			_luz(r, 1.0, Color(1.0, 0.97, 0.86, 0.62))
			_luz(r, 2.4, Color(1.0, 0.95, 0.8, 0.07))
			_luz(r, 0.36, Color(1.0, 1.0, 1.0, 0.85))
	elif chove(tipo):
		_camada_mul(null, Color(0.66, 0.71, 0.82))
	else:
		# sol: luz quente vinda de um canto
		_luz(Vector2(120, -60), 7.0, Color(1.0, 0.86, 0.55, 0.16))
	if chove(tipo):
		_ondas()
		_chuva()
	# respingos (chuva) ou graminhas (seco): um punhado de emissores prontos
	for _i in range(8):
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 14
		p.lifetime = 0.55
		p.local_coords = false
		p.spread = 180.0
		p.gravity = Vector2.ZERO
		p.damping = 220.0
		if chove(tipo):
			p.texture = load("res://imagens/gota.png")
			p.scale_amount = 0.17
			p.scale_amount_random = 0.6
			p.color = Color(0.8, 0.9, 1.0, 0.6)
			p.initial_velocity = 160.0
		else:
			# grama seca: poucas folhinhas finas, baixinhas, sem exagero
			p.texture = load("res://imagens/graminha.png")
			p.amount = 7
			p.lifetime = 0.42
			p.damping = 300.0
			p.scale_amount = 0.5
			p.scale_amount_random = 0.35
			p.angular_velocity = 360.0
			p.angular_velocity_random = 1.0
			p.angle_random = 1.0
			p.initial_velocity = 70.0
			p.color = Color(0.92, 0.95, 0.8, 0.8) if not de_noite(tipo) else Color(0.62, 0.68, 0.72, 0.7)
		p.initial_velocity_random = 0.6
		var rampa := Gradient.new()
		rampa.set_color(0, Color(1, 1, 1, 1))
		rampa.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = rampa
		_chao.add_child(p)
		_pool.append(p)


func _camada_mul(tex: Texture, cor: Color) -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	var c: CanvasItem
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand = true
		tr.rect_size = Vector2(1280, 720)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c = tr
	else:
		var cr := ColorRect.new()
		cr.color = cor
		cr.rect_size = Vector2(1280, 720)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c = cr
	c.material = m
	add_child(c)


func _luz(pos: Vector2, escala: float, cor: Color) -> void:
	var s := Sprite.new()
	s.texture = load("res://imagens/brilho.png")
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	s.position = pos
	s.scale = Vector2.ONE * escala
	s.modulate = cor
	add_child(s)


## Facho de um refletor: um leque de luz do canto para o meio do campo.
func _facho(de: Vector2) -> void:
	var alvo := Vector2(640, 395)
	var eixo := (alvo - de).normalized()
	var lado := eixo.rotated(PI * 0.5)
	var comp := de.distance_to(alvo) * 1.15
	var pg := Polygon2D.new()
	pg.polygon = PoolVector2Array([de + lado * 10.0, de - lado * 10.0,
		de + eixo * comp - lado * comp * 0.42, de + eixo * comp + lado * comp * 0.42])
	var forte := Color(1.0, 0.97, 0.88, 0.15)
	var fraco := Color(1.0, 0.97, 0.88, 0.0)
	pg.vertex_colors = PoolColorArray([forte, forte, fraco, fraco])
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pg.material = m
	add_child(pg)


func _chuva() -> void:
	var p := CPUParticles2D.new()
	p.texture = load("res://imagens/chuva_risco.png")
	p.amount = 240
	p.lifetime = 0.55
	p.preprocess = 1.0
	p.position = Vector2(560, -60)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(820, 10)
	p.direction = Vector2(0.28, 1.0)
	p.spread = 3.0
	p.gravity = Vector2.ZERO
	p.initial_velocity = 1450.0
	p.initial_velocity_random = 0.2
	p.rotation = 0.0
	p.angle = -15.0
	p.scale_amount = 1.0
	p.scale_amount_random = 0.4
	p.color = Color(0.9, 0.95, 1.0, 0.38)
	add_child(p)


func _ondas() -> void:
	var p := CPUParticles2D.new()
	p.texture = load("res://imagens/onda.png")
	p.amount = 36
	p.lifetime = 0.9
	p.preprocess = 1.0
	p.position = Campo.CAMPO.position + Campo.CAMPO.size / 2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Campo.CAMPO.size / 2
	p.gravity = Vector2.ZERO
	p.initial_velocity = 0.0
	p.scale_amount = 0.22
	var c := Curve.new()
	c.add_point(Vector2(0, 0.15))
	c.add_point(Vector2(1, 1))
	p.scale_amount_curve = c
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.9, 0.95, 1.0, 0.55))
	rampa.set_color(1, Color(0.9, 0.95, 1.0, 0.0))
	p.color_ramp = rampa
	add_child(p)


## Bola/botão saindo forte: respingo (chuva) ou graminhas (seco).
func explosao(pos: Vector2, forca: float) -> void:
	if _pool.empty():
		return
	var p: CPUParticles2D = _pool[_prox]
	_prox = (_prox + 1) % _pool.size()
	p.position = pos
	var f := clamp(forca, 0.2, 1.4)
	p.initial_velocity = (160.0 if chove(tipo) else 70.0) * f
	p.restart()
	p.emitting = true


## Peça andando rápido: um rastro de respingos/graminhas de vez em quando.
func rastro(corpo) -> void:
	var v: float = corpo.vel.length()
	if v < 260.0:
		return
	var agora := _t
	if not chove(tipo) and v < 420.0:
		return
	if agora - float(_ultimo.get(corpo, -1.0)) < (0.07 if chove(tipo) else 0.2):
		return
	_ultimo[corpo] = agora
	explosao(corpo.pos, v / 900.0)


func _process(delta: float) -> void:
	_t += delta
