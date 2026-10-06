extends Node2D

## GUIA DO PETELECO: seta (direção), pontilhado (até onde o botão vai com a
## força atual) e a força: anel em volta do botão e, no manche, a BARRA DE
## FORÇA ao lado (sobe e desce enquanto o chute está apertado; solta na
## altura certa). Pelo toque, o ponto do dedo na beirada do botão.
##
## Enquanto a barra corre, a mira é redesenhada todo quadro. Por isso nada
## aqui é montado vértice a vértice na hora: o anel e a seta (borda suave)
## ficam prontos num cache por nível de força (FORCAS níveis) e só são
## posicionados/girados; o pontilhado é uma textura de bolinha e a barra são
## retângulos do motor. Custo por quadro: praticamente zero.

const Campo = preload("res://scripts/campo.gd")
const TracoSuave = preload("res://scripts/traco_suave.gd")
const ATRITO_BOTAO := 700.0
const FORCAS := 48              # níveis de força desenhados (anel e seta)

var ativo := false
var centro := Vector2.ZERO
var direcao := Vector2.RIGHT
var forca := 0.0            # 0..1
var velocidade := 0.0
var toque = null            # Vector2 onde o dedo está, ou null (manche)
var barra := false          # mostra a barra de força
var _t := 0.0
var _chave := ""
var _ponto: ImageTexture
var _cache := {}            # formas prontas: chave -> [índices, pontos, cores]
var _franja := -1.0         # borda suave usada no cache (muda se a escala mudar)


func mostrar(c: Vector2, dir: Vector2, f: float, v: float, dedo = null, com_barra := false) -> void:
	var chave := "%d_%d_%.3f_%d_%d_%s_%s" % [int(c.x), int(c.y), dir.angle(), _nivel(f), int(v), str(dedo), str(com_barra)]
	ativo = true
	centro = c
	direcao = dir
	forca = f
	velocidade = v
	toque = dedo
	barra = com_barra
	if chave != _chave:
		_chave = chave
		update()


func esconder() -> void:
	if ativo:
		ativo = false
		_chave = ""
		update()


func _process(delta: float) -> void:
	if ativo and toque != null:
		_t += delta
		update()


static func cor_forca(f: float) -> Color:
	if f < 0.5:
		return Color(0.25, 1.0, 0.35).linear_interpolate(Color(1.0, 0.9, 0.1), f * 2.0)
	return Color(1.0, 0.9, 0.1).linear_interpolate(Color(1.0, 0.2, 0.15), (f - 0.5) * 2.0)


static func _nivel(f: float) -> int:
	return int(round(clamp(f, 0.0, 1.0) * FORCAS))


# ------------------------------------------------------------ formas prontas
## Bolinha do pontilhado (feita uma vez).
static func _textura_ponto() -> ImageTexture:
	var tam := 16
	var img := Image.new()
	img.create(tam, tam, false, Image.FORMAT_RGBA8)
	img.lock()
	for y in range(tam):
		for x in range(tam):
			var d := Vector2(x + 0.5 - tam / 2.0, y + 0.5 - tam / 2.0).length()
			img.set_pixel(x, y, Color(1, 1, 1, clamp(tam / 2.0 - 0.8 - d, 0.0, 1.0)))
	img.unlock()
	var t := ImageTexture.new()
	t.create_from_image(img, Texture.FLAG_FILTER)
	return t


func _novo_lote() -> TracoSuave:
	var l := TracoSuave.new()
	l.franja = _franja
	return l


## Anel em volta do botão (fundo escuro + arco da força), centrado em (0, 0).
func _anel(n: int) -> Array:
	var k := "anel%d" % n
	if not _cache.has(k):
		var r := Campo.RAIO_BOTAO + 9.0
		var l := _novo_lote()
		l.linha(l.arco(Vector2.ZERO, r, 0, TAU, 32, false), Color(0, 0, 0, 0.45), 7.0, true)
		if n > 0:
			var a0 := -PI / 2
			var f := float(n) / FORCAS
			l.linha(l.arco(Vector2.ZERO, r, a0, a0 + TAU * f, int(max(3, 32 * f))), cor_forca(f), 5.0)
		_cache[k] = [l.indices, l.pontos, l.cores]
	return _cache[k]


## Seta apontando para +X a partir de (0, 0) (o desenho gira para a direção).
func _seta(n: int) -> Array:
	var k := "seta%d" % n
	if not _cache.has(k):
		var r := Campo.RAIO_BOTAO
		var f := float(n) / FORCAS
		var cor := cor_forca(f)
		var base := Vector2(r + 6.0, 0)
		var ponta := Vector2(r + 26.0 + 60.0 * max(f, 0.25), 0)
		var l := _novo_lote()
		l.linha(PoolVector2Array([base, ponta]), Color(0, 0, 0, 0.5), 11.0)
		l.linha(PoolVector2Array([base, ponta]), cor, 6.0)
		l.poligono(PoolVector2Array([ponta + Vector2(14, 0), ponta + Vector2(-4, 11), ponta + Vector2(-4, -11)]), cor)
		_cache[k] = [l.indices, l.pontos, l.cores]
	return _cache[k]


## Monta todas as formas de uma vez (na entrada da partida, atrás do
## letreiro do confronto): segurar o botão nunca monta nada na hora.
func preaquecer() -> void:
	if not is_inside_tree():
		return
	var medidor := TracoSuave.new()
	medidor.preparar(self)
	_franja = medidor.franja
	_cache.clear()
	for n in range(FORCAS + 1):
		_anel(n)
		_seta(n)
	if _ponto == null:
		_ponto = _textura_ponto()


func _por(forma: Array, pos: Vector2, giro := 0.0) -> void:
	draw_set_transform(pos, giro, Vector2.ONE)
	VisualServer.canvas_item_add_triangle_array(get_canvas_item(), forma[0], forma[1], forma[2])


# ------------------------------------------------------------------ desenho
func _draw() -> void:
	if not ativo:
		return
	if _ponto == null:
		_ponto = _textura_ponto()
	# a borda suave depende da escala na tela: se mudar, refaz o cache
	var medidor := TracoSuave.new()
	medidor.preparar(self)
	if abs(medidor.franja - _franja) > 0.001:
		_franja = medidor.franja
		_cache.clear()
	var r := Campo.RAIO_BOTAO
	var n := _nivel(forca)
	# trajetória prevista (pontilhado até onde o botão para, sem choques)
	var dist := velocidade * velocidade / (2.0 * ATRITO_BOTAO)
	var d := r + 16.0
	var i := 0
	while d < dist and i < 60:
		var p := centro + direcao * d
		if not Campo.MURO.has_point(p):
			break
		var alfa := 0.85 * (1.0 - d / max(dist, 1.0)) + 0.1
		draw_texture_rect(_ponto, Rect2(p - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), false, Color(1, 1, 1, alfa))
		d += 18.0
		i += 1
	# anel e seta (formas prontas, só posicionadas)
	_por(_anel(n), centro)
	_por(_seta(n), centro, direcao.angle())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# barra de força ao lado do botão (do lado oposto à seta, para não cobrir)
	if barra:
		var lado_barra := 1.0 if direcao.x <= 0.0 else -1.0
		var bx := centro.x + lado_barra * (r + 30.0)
		var by0 := centro.y + 38.0
		var alt := 76.0
		var larg := 14.0
		draw_rect(Rect2(bx - larg / 2 - 3, by0 - alt - 3, larg + 6, alt + 6), Color(0, 0, 0, 0.7))
		var fatias := 12
		var cheio := int(ceil(forca * fatias))
		for k in range(fatias):
			var y1 := by0 - alt * float(k + 1) / fatias + 1.0
			var c := cor_forca(float(k) / (fatias - 1))
			if k >= cheio:
				c = Color(c.r, c.g, c.b, 0.18)
			draw_rect(Rect2(bx - larg / 2, y1, larg, alt / fatias - 1.0), c)
		var ny := by0 - alt * forca
		draw_colored_polygon(PoolVector2Array([Vector2(bx - larg / 2 - 7, ny - 4), Vector2(bx - larg / 2 - 1, ny), Vector2(bx - larg / 2 - 7, ny + 4)]), Color.white)
		draw_colored_polygon(PoolVector2Array([Vector2(bx + larg / 2 + 7, ny - 4), Vector2(bx + larg / 2 + 1, ny), Vector2(bx + larg / 2 + 7, ny + 4)]), Color.white)
	# onde o dedo está (toque na tela)
	if toque != null:
		var l := _novo_lote()
		l.brilho_redondo(toque, 16.0, Color(1, 1, 1, 0.5 + 0.2 * sin(_t * 8.0)))
		l.circulo(toque, 5.0, Color(1, 1, 1, 0.95), 16)
		l.desenhar(self)
