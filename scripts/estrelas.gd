extends Control

## Força da seleção em estrelas desenhadas (1 a 5).

var cheias := 3
var _lote = preload("res://scripts/traco_suave.gd").new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	_lote.preparar(self)
	var r := rect_size.y * 0.45
	var passo := r * 2.3
	var x0 := rect_size.x / 2 - passo * 2
	for i in range(5):
		var c := Vector2(x0 + i * passo, rect_size.y / 2)
		var pts := PoolVector2Array()
		for k in range(10):
			var a := -PI / 2 + k * PI / 5
			var rr := r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		var cor = Jogo.AMARELO if i < cheias else Color(1, 1, 1, 0.22)
		# estrela = 5 triângulos convexos (pontas) + miolo
		var miolo := PoolVector2Array()
		for k in range(5):
			miolo.append(pts[k * 2 + 1])
		_lote.poligono(miolo, cor)
		for k in range(5):
			_lote.poligono(PoolVector2Array([pts[(k * 2 + 9) % 10], pts[k * 2], pts[k * 2 + 1]]), cor)
	_lote.desenhar(self)
