extends Control

## Marcadores redondos desenhados (toques da vez, pênaltis da disputa).
## estados: 1 = cheio, 0 = vazio, 2 = gol (verde), -1 = perdeu (X vermelho)

var estados := [] setget definir
var cor := Color.white
var raio := 8.0
var espaco := 22.0
var da_direita := false
var _lote = preload("res://scripts/traco_suave.gd").new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func definir(v: Array) -> void:
	if v == estados:
		return
	estados = v.duplicate()
	update()


func _draw() -> void:
	if estados.empty():
		return
	_lote.preparar(self)
	var y := rect_size.y / 2
	for i in range(estados.size()):
		var x := raio + 2 + i * espaco
		if da_direita:
			x = rect_size.x - raio - 2 - i * espaco
		var c := Vector2(x, y)
		var e: int = estados[i]
		match e:
			1:
				_lote.circulo(c, raio, cor, 20)
			2:
				_lote.circulo(c, raio, Color(0.25, 0.95, 0.4), 20)
			-1:
				_lote.circulo(c, raio, Color(0.35, 0.05, 0.05, 0.9), 20)
				_lote.linha(PoolVector2Array([c + Vector2(-5, -5), c + Vector2(5, 5)]), Color(1, 0.3, 0.3), 3.0)
				_lote.linha(PoolVector2Array([c + Vector2(5, -5), c + Vector2(-5, 5)]), Color(1, 0.3, 0.3), 3.0)
			_:
				_lote.linha(_lote.arco(c, raio - 1.0, 0, TAU, 20, false), Color(cor.r, cor.g, cor.b, 0.7), 2.5, true)
	_lote.desenhar(self)
