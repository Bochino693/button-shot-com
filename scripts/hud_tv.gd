extends Control

## HUD DE TRANSMISSÃO (sem faixas pretas): a imagem 3D ocupa a tela inteira.
## Só uma sombra suave em cima e embaixo (para o texto ler bem) e "pílulas"
## de vidro arredondadas atrás dos rótulos (marca, fase, contagem, dicas),
## que acompanham o texto e a transparência de cada rótulo.

var sombra := 1.0                 # força da sombra suave (0..1)
var _pilulas := []                # [Label, cor de destaque, folga extra à direita]
var _caixa: StyleBoxFlat
var _marca: StyleBoxFlat


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	rect_size = Vector2(1280, 720)
	_caixa = StyleBoxFlat.new()
	_caixa.set_corner_radius_all(22)
	_caixa.anti_aliasing = true
	_caixa.border_color = Color(1, 1, 1, 0.12)
	_caixa.set_border_width_all(1)
	_marca = StyleBoxFlat.new()
	_marca.set_corner_radius_all(3)
	_marca.anti_aliasing = true


## Põe uma pílula de vidro atrás do rótulo `l` (uma linha). `destaque`: um
## filete colorido à esquerda; `extra`: espaço a mais à direita (ex.: anel).
func pilula(l: Label, destaque := Color(0, 0, 0, 0), extra := 0.0) -> void:
	_pilulas.append([l, destaque, extra])


func _process(_d: float) -> void:
	update()


func _draw() -> void:
	if sombra > 0.0:
		var a := 0.42 * sombra
		draw_polygon(PoolVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 140), Vector2(0, 140)]),
			PoolColorArray([Color(0, 0, 0, a), Color(0, 0, 0, a), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
		draw_polygon(PoolVector2Array([Vector2(0, 580), Vector2(1280, 580), Vector2(1280, 720), Vector2(0, 720)]),
			PoolColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, a), Color(0, 0, 0, a)]))
	for p in _pilulas:
		var l: Label = p[0]
		if not is_instance_valid(l) or not l.visible or l.text == "":
			continue
		var alfa: float = l.modulate.a * l.self_modulate.a
		if alfa < 0.01:
			continue
		var f: Font = l.get_font("font")
		var w := f.get_string_size(l.text).x
		var h := f.get_height() + 14.0
		var x := l.rect_position.x
		if l.align == Label.ALIGN_RIGHT:
			x = l.rect_position.x + l.rect_size.x - w
		elif l.align == Label.ALIGN_CENTER:
			x = l.rect_position.x + (l.rect_size.x - w) / 2.0
		var y := l.rect_position.y + (l.rect_size.y - h) / 2.0
		var cor: Color = p[1]
		var esq := 20.0 + (10.0 if cor.a > 0.0 else 0.0)
		var r := Rect2(x - esq, y, w + esq + 20.0 + p[2], h)
		_caixa.bg_color = Color(0.02, 0.04, 0.09, 0.62 * alfa)
		_caixa.border_color = Color(1, 1, 1, 0.12 * alfa)
		draw_style_box(_caixa, r)
		if cor.a > 0.0:
			_marca.bg_color = Color(cor.r, cor.g, cor.b, cor.a * alfa)
			draw_style_box(_marca, Rect2(r.position.x + 12, r.position.y + 10, 5, r.size.y - 20))
