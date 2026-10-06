extends Node2D

## CARTÃO AMARELO PRESO NO TAZO, desenhado em vetor (nítido em 1080p e em
## qualquer escala): sombra, o cartão com bordas arredondadas, filete claro
## e um reflexo de plástico.

var alto := 30.0
var _caixa: StyleBoxFlat
var _sombra: StyleBoxFlat


func _ready() -> void:
	_caixa = StyleBoxFlat.new()
	_caixa.bg_color = Color(1.0, 0.82, 0.08)
	_caixa.border_color = Color(1.0, 0.95, 0.6)
	_caixa.set_border_width_all(int(max(1.0, alto * 0.05)))
	_caixa.set_corner_radius_all(int(max(2.0, alto * 0.12)))
	_caixa.anti_aliasing = true
	_caixa.anti_aliasing_size = 1
	_sombra = _caixa.duplicate()
	_sombra.bg_color = Color(0, 0, 0, 0.45)
	_sombra.border_color = Color(0, 0, 0, 0)
	update()


func _draw() -> void:
	var w := alto * 0.7
	var r := Rect2(-w / 2.0, -alto / 2.0, w, alto)
	draw_style_box(_sombra, Rect2(r.position + Vector2(alto * 0.1, alto * 0.13), r.size))
	draw_style_box(_caixa, r)
	# reflexo: faixa clara na diagonal de cima
	var a := r.position + Vector2(w * 0.18, alto * 0.08)
	draw_polygon(PoolVector2Array([a, a + Vector2(w * 0.5, 0), a + Vector2(w * 0.18, alto * 0.42), a + Vector2(-w * 0.04, alto * 0.42)]),
		PoolColorArray([Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.22)]), PoolVector2Array(), null, null, true)
