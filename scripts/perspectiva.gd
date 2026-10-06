extends Reference

## PERSPECTIVA: a mesa (1280x720) vira um trapézio na tela, mais estreito em
## cima (longe) e mais largo embaixo (perto), como a câmera da TV.
##   mesa -> tela: para_tela(p);  tela -> mesa: para_mesa(p) (o toque)
## ABRE = quanto a borda de baixo passa da tela de cada lado (0 = sem
## perspectiva). O desenho é feito pelo shaders/perspectiva.shader.

const ABRE := 0.06
const TAM := Vector2(1280, 720)

# homografia (3x3, linhas) do quadrado da mesa (uv) para a tela (uv) e a inversa
const _H := {"m": [], "inv": []}


static func _calcular() -> void:
	if not _H.m.empty():
		return
	# cantos da mesa (0,0) (1,0) (1,1) (0,1) na tela
	var q := [Vector2(0, 0), Vector2(1, 0), Vector2(1 + ABRE, 1), Vector2(-ABRE, 1)]
	var m := _quadrado_para_quad(q)
	var d: Dictionary = _H
	d["m"] = m
	d["inv"] = _inversa(m)


## Heckbert: quadrado unitário -> quadrilátero.
static func _quadrado_para_quad(q: Array) -> Array:
	var x0: float = q[0].x
	var y0: float = q[0].y
	var x1: float = q[1].x
	var y1: float = q[1].y
	var x2: float = q[2].x
	var y2: float = q[2].y
	var x3: float = q[3].x
	var y3: float = q[3].y
	var sx := x0 - x1 + x2 - x3
	var sy := y0 - y1 + y2 - y3
	var dx1 := x1 - x2
	var dx2 := x3 - x2
	var dy1 := y1 - y2
	var dy2 := y3 - y2
	var det := dx1 * dy2 - dx2 * dy1
	var g := (sx * dy2 - dx2 * sy) / det
	var h := (dx1 * sy - sx * dy1) / det
	return [
		[x1 - x0 + g * x1, x3 - x0 + h * x3, x0],
		[y1 - y0 + g * y1, y3 - y0 + h * y3, y0],
		[g, h, 1.0],
	]


static func _inversa(m: Array) -> Array:
	var a: float = m[0][0]
	var b: float = m[0][1]
	var c: float = m[0][2]
	var d: float = m[1][0]
	var e: float = m[1][1]
	var f: float = m[1][2]
	var g: float = m[2][0]
	var h: float = m[2][1]
	var i: float = m[2][2]
	var A := e * i - f * h
	var B := -(d * i - f * g)
	var C := d * h - e * g
	var det := a * A + b * B + c * C
	return [
		[A / det, -(b * i - c * h) / det, (b * f - c * e) / det],
		[B / det, (a * i - c * g) / det, -(a * f - c * d) / det],
		[C / det, -(a * h - b * g) / det, (a * e - b * d) / det],
	]


static func _aplicar(m: Array, p: Vector2) -> Vector2:
	var w: float = m[2][0] * p.x + m[2][1] * p.y + m[2][2]
	return Vector2(m[0][0] * p.x + m[0][1] * p.y + m[0][2], m[1][0] * p.x + m[1][1] * p.y + m[1][2]) / w


static func para_tela(p: Vector2) -> Vector2:
	_calcular()
	return _aplicar(_H.m, p / TAM) * TAM


static func para_mesa(p: Vector2) -> Vector2:
	_calcular()
	return _aplicar(_H.inv, p / TAM) * TAM


## Monta o Viewport (onde a mesa é desenhada reta, na resolução da tela) e
## o quadro que mostra ela em perspectiva. Devolve [viewport, quadro].
static func montar(pai: Node) -> Array:
	_calcular()
	var janela := OS.window_size
	var esc: float = min(janela.x / TAM.x, janela.y / TAM.y)
	# no máximo 1080p (TV 4K: o quadro da mesa não precisa de 4x os pixels)
	esc = clamp(esc, 1.0, 1.5)
	var vp := Viewport.new()
	vp.size = TAM * esc
	vp.usage = Viewport.USAGE_2D
	vp.transparent_bg = false
	vp.render_target_v_flip = true
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	vp.gui_disable_input = true
	pai.add_child(vp)
	vp.canvas_transform = Transform2D().scaled(Vector2(esc, esc))
	var quadro := TextureRect.new()
	var tex := vp.get_texture()
	tex.flags = Texture.FLAG_FILTER
	quadro.texture = tex
	quadro.expand = true
	quadro.rect_size = TAM
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/perspectiva.shader")
	var inv: Array = _H.inv
	mat.set_shader_param("h0", Vector3(inv[0][0], inv[0][1], inv[0][2]))
	mat.set_shader_param("h1", Vector3(inv[1][0], inv[1][1], inv[1][2]))
	mat.set_shader_param("h2", Vector3(inv[2][0], inv[2][1], inv[2][2]))
	quadro.material = mat
	pai.add_child(quadro)
	return [vp, quadro]
