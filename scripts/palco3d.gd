extends Node

## PALCO 3D: o quadro 3D das apresentações (estádio da partida, pódio) e o
## preparo dele ESCONDIDO atrás de uma capa de carregamento, para o show
## nunca "ciscar" nem travar na TV box:
##   0. revelar aos poucos: o 3D começa todo escondido e as peças aparecem
##      poucas por quadro. No Android os shaders são compilados na hora do
##      primeiro desenho; assim nenhum quadro compila dezenas de uma vez (o
##      que travava a TV box por segundos e podia até fechar o jogo).
##   1. aquecer: a câmera passa por todos os planos do show (um ou dois
##      quadros cada). O Android compila ali, atrás da capa, todos os shaders
##      e sobe todas as texturas que o show vai usar.
##   2. medir: alguns quadros nos planos mais pesados (a cidade e a câmera da
##      TV). Se a TV box não segura o ritmo, desce um degrau de qualidade
##      (qualidade3d.gd), aquece de novo as variações novas e mede outra vez.
##      Se nem o último degrau segura 60, o show roda a 30 quadros cravados
##      (ritmo igual, sem tranco).
##   3. revelar: a capa some e o show começa com a qualidade travada.
## O quadro 3D é ampliado para a tela com filtro (nunca pixel quadrado).

signal pronto

const UI = preload("res://scripts/ui.gd")
const Qualidade3D = preload("res://scripts/qualidade3d.gd")
const BRILHO = preload("res://imagens/brilho.png")
const MAX_RODADAS := 3
const LOTE := 10                 # peças reveladas por quadro
const LIMITE_PREPARO := 9.0      # s: depois disso (já medido uma vez) revela

var vp: Viewport
var tela: TextureRect
var qualidade
var mundo: Node
var esta_pronto := false

var _posicionar: FuncRef
var _amostras := []          # tempos do show por onde a câmera passa
var _medir_em := []          # tempos dos planos pesados (medida)
var _fila := []              # [tempo, quadros] a aquecer
var _ocultos := []           # peças 3D ainda escondidas (reveladas aos poucos)
var _quadros := 0
var _medidas := []
var _rodadas := 0
var _ult_us := 0
var _relogio := 0.0
var _progresso := 0.0
var _total := 1
var _meia_taxa := false
var _ja_calibrado := false     # esta TV box já foi medida: não mede de novo
var _montagem := 1.0           # 0..1: montagem do estádio (antes do preparo)
const PARTE_MONTAGEM := 0.35   # quanto da barra é a montagem

var _capa: Control
var _barra_fundo: StyleBoxFlat
var _barra_cheia: StyleBoxFlat
var _cores := [Color(0.2, 0.4, 1.0), Color(1.0, 0.3, 0.3)]
var _sumindo := -1.0
var _mostrado := 0.0          # progresso desenhado (segue o real, suave)
var _dica: Label
var _t_dica := 0.0


## Cria o quadro 3D (primeiro filho de `pai`: fica atrás de toda a 2D).
func criar(pai: Control) -> void:
	vp = Viewport.new()
	vp.size = Vector2(1280, 720)
	vp.usage = Viewport.USAGE_3D
	vp.own_world = true
	vp.hdr = true
	vp.render_target_v_flip = true
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	vp.gui_disable_input = true
	pai.add_child(vp)
	tela = TextureRect.new()
	tela.texture = vp.get_texture()
	tela.expand = true
	tela.rect_size = Vector2(1280, 720)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(tela)
	vp.get_texture().flags = Texture.FLAG_FILTER
	pai.add_child(self)


## A capa de carregamento (por cima de tudo em `pai`): fundo escuro com o
## brilho das cores dos times, escudos, título e a barra de progresso.
func capa(pai: Control, titulo: String, sub: String, escudos: Array, cores: Array) -> void:
	if cores.size() >= 2:
		_cores = cores
	_capa = Control.new()
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.rect_size = Vector2(1280, 720)
	_capa.connect("draw", self, "_desenhar_capa")
	pai.add_child(_capa)
	var n := escudos.size()
	for i in range(n):
		var e := TextureRect.new()
		e.texture = escudos[i]
		e.expand = true
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var x := 640.0 + (i - (n - 1) / 2.0) * 300.0
		UI.colocar(e, x - 76, 196, 152, 152)
		_capa.add_child(e)
	if n == 2:
		var vs := UI.label("VS", Jogo.fonte("titan", 44, 3), Jogo.OURO)
		UI.colocar(vs, 560, 232, 160, 80)
		_capa.add_child(vs)
	var t := UI.label(titulo, Jogo.fonte("bungee", 28, 0), Color.white)
	UI.colocar(t, 0, 400, 1280, 44)
	_capa.add_child(t)
	var s := UI.label(sub, Jogo.fonte("texto", 20, 0), Color(1, 1, 1, 0.7))
	UI.colocar(s, 0, 446, 1280, 30)
	_capa.add_child(s)
	# dica de jogo embaixo da barra (troca a cada poucos segundos)
	_dica = UI.label("DICA  •  " + Jogo.dica(), Jogo.fonte("texto", 19, 0), Color(1, 1, 1, 0.85))
	UI.colocar(_dica, 140, 540, 1000, 34)
	_capa.add_child(_dica)
	_barra_fundo = StyleBoxFlat.new()
	_barra_fundo.bg_color = Color(1, 1, 1, 0.12)
	_barra_fundo.set_corner_radius_all(4)
	_barra_fundo.anti_aliasing = true
	_barra_cheia = StyleBoxFlat.new()
	_barra_cheia.bg_color = Jogo.OURO
	_barra_cheia.set_corner_radius_all(4)
	_barra_cheia.anti_aliasing = true


## Montagem do estádio em andamento (0..1): a barra anda já nessa fase.
func montagem(f: float) -> void:
	_montagem = clamp(f, 0.0, 1.0)


## A capa fica por cima de tudo que a tela criou depois dela.
func capa_por_cima() -> void:
	if _capa != null and _capa.get_parent() != null:
		_capa.get_parent().move_child(_capa, _capa.get_parent().get_child_count() - 1)


## Começa o preparo. `posicionar` = função(t) da câmera do show; `amostras`
## = tempos do show (um por plano, começo/meio/fim); `medir_em` = tempos
## dos planos mais pesados.
func preparar(mundo_: Node, posicionar: FuncRef, amostras: Array, medir_em: Array) -> void:
	mundo = mundo_
	_posicionar = posicionar
	_amostras = amostras
	_medir_em = medir_em
	qualidade = Qualidade3D.aplicar(get_parent(), vp, mundo)
	_esconder(mundo)
	_ocultos.invert()           # o que foi montado primeiro aparece primeiro
	print("Palco3D: %d peças 3D" % _ocultos.size())
	# já calibrada antes: um quadro por plano basta (o Android compila no
	# primeiro desenho) e a medida é pulada; o show continua vigiado
	_ja_calibrado = Qualidade3D.calibrado()
	_encher_fila(1 if _ja_calibrado else 2)
	if _ja_calibrado:
		_medir_em = []
	_total = _fila.size() + _medir_em.size() * 2 + int(ceil(_ocultos.size() / float(LOTE)))
	_posicionar.call_func(_amostras[0])
	_ult_us = OS.get_ticks_usec()


func _esconder(no: Node) -> void:
	for f in no.get_children():
		_esconder(f)
	if no is GeometryInstance and no.visible:
		no.visible = false
		_ocultos.append(no)


func _encher_fila(quadros: int) -> void:
	_fila.clear()
	for t in _amostras:
		_fila.append([t, quadros])
	_fila[0][1] += 1


func _process(delta: float) -> void:
	_relogio += delta
	if _capa != null and _dica != null:
		_t_dica += delta
		if _t_dica > 5.0:
			_t_dica = 0.0
			_dica.text = "DICA  •  " + Jogo.dica()
	if _capa != null:
		var preparo: float = clamp(_progresso / max(1.0, float(_total)), 0.0, 1.0) if _posicionar != null else 0.0
		var alvo: float = PARTE_MONTAGEM * _montagem + (1.0 - PARTE_MONTAGEM) * preparo
		var novo: float = lerp(_mostrado, alvo, min(1.0, min(delta, 0.05) * 6.0))
		if abs(novo - _mostrado) > 0.0005:
			_mostrado = novo
			_capa.update()
	if _sumindo >= 0.0:
		_sumindo += delta
		var u: float = clamp(_sumindo / 0.3, 0.0, 1.0)
		if _capa != null:
			_capa.modulate.a = 1.0 - u * u * (3.0 - 2.0 * u)
		if u >= 1.0:
			if _capa != null:
				_capa.queue_free()
				_capa = null
			set_process(false)
		return
	if _posicionar == null or esta_pronto:
		return
	var agora := OS.get_ticks_usec()
	var dt := (agora - _ult_us) / 1000000.0
	_ult_us = agora
	# 0. revelar aos poucos (poucos shaders novos por quadro)
	if not _ocultos.empty():
		for _i in range(LOTE):
			if _ocultos.empty():
				break
			var g = _ocultos.pop_back()
			if is_instance_valid(g):
				g.visible = true
		_progresso += 1.0
		if _ocultos.empty() and mundo.has_method("aquecer"):
			mundo.aquecer()
		return
	# 1. aquecer: cada amostra fica alguns quadros na tela (escondida)
	if not _fila.empty():
		var f: Array = _fila[0]
		if _quadros == 0:
			_posicionar.call_func(f[0])
		_quadros += 1
		f[1] -= 1
		if f[1] <= 0:
			_fila.pop_front()
			_quadros = 0
			_progresso += 1.0
		return
	if _relogio > LIMITE_PREPARO and _rodadas > 0:
		_revelar()
		return
	if _ja_calibrado:
		_revelar()
		return
	# 2. medir nos planos pesados: 3 quadros para assentar, 12 medidos
	var i := int(_medidas.size() / 12)
	if i >= _medir_em.size():
		_avaliar()
		return
	if _quadros == 0:
		_posicionar.call_func(_medir_em[i])
	_quadros += 1
	if _quadros > 3:
		_medidas.append(dt)
		if _medidas.size() % 12 == 0:
			_quadros = 0
			_progresso += 2.0


func _avaliar() -> void:
	var lista := _medidas.duplicate()
	lista.sort()
	var mediana: float = lista[lista.size() / 2] if not lista.empty() else 0.0
	_medidas.clear()
	_quadros = 0
	print("Palco3D: nível %d mediana %.1f ms" % [qualidade.nivel, mediana * 1000.0])
	var lim60 := Qualidade3D.limite()
	if mediana <= lim60:
		_revelar()                  # segura 60: show a 60
		return
	if _rodadas >= MAX_RODADAS:
		_meia_taxa = true
		_revelar()
		return
	_rodadas += 1
	if mediana > lim60 * 2.2:
		qualidade.descer()          # muito longe: pula um degrau a mais
	if not qualidade.descer():
		_meia_taxa = true
		_revelar()
		return
	# as variações novas (sem sombra, sem brilho...) aquecem de novo
	_encher_fila(1)
	_total += _fila.size() + _medir_em.size() * 2


func _revelar() -> void:
	esta_pronto = true
	qualidade.confirmar()
	qualidade.travado = true
	if _meia_taxa:
		qualidade._salvar(qualidade.nivel, false)   # no limite: mede sempre
		# nem o último degrau segura 60: 30 cravados (ritmo sempre igual)
		Engine.target_fps = 30
		print("Palco3D: show a 30 quadros")
	_progresso = float(_total)
	_sumindo = 0.0
	emit_signal("pronto")


func _exit_tree() -> void:
	if _meia_taxa:
		Engine.target_fps = 0


func _desenhar_capa() -> void:
	if _capa == null:
		return
	var c := _capa
	var fundo := Jogo.FUNDO
	var baixo := Color(fundo.r * 0.5, fundo.g * 0.5, fundo.b * 0.6)
	c.draw_polygon(PoolVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
		PoolColorArray([fundo, fundo, baixo, baixo]))
	# brilho suave das cores dos times dos dois lados (não na saída: dois
	# brilhos de tela inteira por cima do 3D pesariam justo no começo do show)
	for i in ([0, 1] if _sumindo < 0.0 else []):
		var cor: Color = _cores[i]
		var x := 160.0 if i == 0 else 1120.0
		var tam := 1100.0
		c.draw_texture_rect(BRILHO, Rect2(x - tam / 2, 272 - tam / 2, tam, tam), false, Color(cor.r, cor.g, cor.b, 0.32))
	# filetes dourados finos
	c.draw_rect(Rect2(440, 386, 400, 2), Color(Jogo.OURO.r, Jogo.OURO.g, Jogo.OURO.b, 0.6))
	# barra de progresso arredondada: enche suave (nada correndo na tela
	# que mostre os quadros pesados do preparo)
	var r := Rect2(440, 500, 400, 8)
	c.draw_style_box(_barra_fundo, r)
	var w: float = max(8.0, r.size.x * (0.06 + 0.94 * _mostrado))
	c.draw_style_box(_barra_cheia, Rect2(r.position, Vector2(w, r.size.y)))
