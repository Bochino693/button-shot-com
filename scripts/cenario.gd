extends Control

## Fundo das telas de menu: o estádio de um time (sorteado, ou o de "sigla")
## com a torcida animada, escurecido, e um facho de luz passando devagar.

const Torcida = preload("res://scripts/torcida.gd")

export var escurecer := 0.55
var sigla := ""            # estádio de qual time ("" = sorteia)
var torcida
var _luz: Sprite
var _t := 0.0


func _ready() -> void:
	anchor_right = 1
	anchor_bottom = 1
	mouse_filter = MOUSE_FILTER_IGNORE
	if sigla == "":
		sigla = Jogo.TIMES[randi() % Jogo.TIMES.size()].sigla
	var fundo := TextureRect.new()
	fundo.texture = Jogo.estadio(sigla, OS.window_size.y < 900)
	fundo.expand = true
	fundo.rect_size = Vector2(1280, 720)
	fundo.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fundo)
	torcida = Torcida.new()
	torcida.rect_size = Vector2(1280, 720)
	add_child(torcida)
	var s1: Dictionary = Jogo.selecao(sigla)
	var s2: Dictionary = Jogo.TIMES[randi() % Jogo.TIMES.size()]
	torcida.cores(s1.torcida, s2.torcida)
	var escuro := ColorRect.new()
	escuro.color = Color(0.02, 0.04, 0.08, escurecer)
	escuro.anchor_right = 1
	escuro.anchor_bottom = 1
	escuro.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(escuro)
	_luz = Sprite.new()
	_luz.texture = load("res://imagens/brilho.png")
	var aditivo := CanvasItemMaterial.new()
	aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_luz.material = aditivo
	_luz.scale = Vector2(2.0, 5.0)
	_luz.rotation = 0.35
	_luz.modulate = Color(1, 0.95, 0.8, 0.10)
	add_child(_luz)


func _process(delta: float) -> void:
	_t += delta
	_luz.position = Vector2(fmod(_t * 90.0, 1800.0) - 260.0, 360)
