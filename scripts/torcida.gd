extends Control

## TORCIDA ANIMADA em volta do campo. Quatro faixas (em cima, embaixo e
## nos lados) da mesma imagem, só onde tem arquibancada (não pinta o campo).
## pular(time, forca): a torcida daquele lado comemora.

const Campo = preload("res://scripts/campo.gd")

var _mat: ShaderMaterial
var _fase := 0.0
var _pulo := [0.15, 0.15]
var _alvo := [0.15, 0.15]
var _vel := 1.0


func _ready() -> void:
	anchor_right = 1
	anchor_bottom = 1
	mouse_filter = MOUSE_FILTER_IGNORE
	var tex: Texture = load("res://imagens/torcida.png")
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/torcida.shader")
	_mat.set_shader_param("ids", load("res://imagens/torcida_ids.png"))
	var m := Campo.MURO
	# faixas em 1280x720 -> regiões da imagem (1920x1080)
	var faixas := [
		Rect2(0, 0, 1280, m.position.y - 10),
		Rect2(0, m.end.y + 10, 1280, 720 - m.end.y - 10),
		Rect2(0, m.position.y - 10, m.position.x - 10, m.size.y + 20),
		Rect2(m.end.x + 10, m.position.y - 10, 1280 - m.end.x - 10, m.size.y + 20),
	]
	for r in faixas:
		if r.size.x <= 0 or r.size.y <= 0:
			continue
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(r.position * 1.5, r.size * 1.5)
		var tr := TextureRect.new()
		tr.texture = at
		tr.expand = true
		tr.rect_position = r.position
		tr.rect_size = r.size
		tr.material = _mat
		tr.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(tr)


func cores(casa: Array, fora: Array) -> void:
	_mat.set_shader_param("casa1", Color(casa[0]))
	_mat.set_shader_param("casa2", Color(casa[1]))
	_mat.set_shader_param("fora1", Color(fora[0]))
	_mat.set_shader_param("fora2", Color(fora[1]))


## Comemoração: time 0 (casa) ou 1 (fora); forca ~1 = gol.
func pular(time: int, forca: float, dur := 4.0) -> void:
	_alvo[time] = forca
	_vel = 2.6
	get_tree().create_timer(dur, false).connect("timeout", self, "_acalmar")


func _acalmar() -> void:
	_alvo = [0.15, 0.15]
	_vel = 1.0


func _process(delta: float) -> void:
	_fase = fmod(_fase + delta * 5.5 * _vel, TAU)
	for i in range(2):
		_pulo[i] = lerp(_pulo[i], _alvo[i], min(1.0, delta * 4.0))
	_mat.set_shader_param("fase", _fase)
	_mat.set_shader_param("pulo_casa", _pulo[0])
	_mat.set_shader_param("pulo_fora", _pulo[1])
