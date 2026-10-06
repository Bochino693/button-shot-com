extends Control

## CHAVE DA COPA: quartas, semifinais e final em IDA E VOLTA. Cada confronto
## mostra o agregado (e os pênaltis, se houve). O time do jogador fica em
## destaque. JOGAR abre a preparação da partida (a cutscene) e depois o jogo.
## Campeão: taça, confete e festa, e o título vai para o ranking do time.
## Eliminado: a Copa termina simulada e mostra quem levou a taça.

const UI = preload("res://scripts/ui.gd")
const Cenario = preload("res://scripts/cenario.gd")

const FASES := ["QUARTAS DE FINAL", "SEMIFINAL", "FINAL"]
const CHIP := Vector2(200, 48)

var _cenario
var _linhas: Control
var _t := 0.0
var _trofeu: TextureRect
var _saindo := false
var _atuais := []          # chips do próximo jogo (brilham devagar)
var _fim_para_mim := false   # a Copa acabou e o jogador não é o campeão


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_cenario = Cenario.new()
	_cenario.escurecer = 0.66
	var c: Dictionary = Jogo.copa
	if not c.empty():
		_cenario.sigla = c.humanos[randi() % c.humanos.size()]
	add_child(_cenario)
	if c.empty():
		Jogo.ir_para("res://cenas/menu.tscn")
		return
	if c.eliminado and c.campeao == "":
		Jogo.copa_simular_resto()
	var campeao: String = c.campeao
	if campeao != "" and not c.get("podio_visto", false):
		if Jogo.jogador_de(campeao) > 0:
			# o jogador é o campeão: direto para a cerimônia do pódio em 3D
			c["podio_visto"] = true
			_saindo = true
			Jogo.ir_para("res://cenas/podio.tscn")
			return
		# o jogador ficou pelo caminho: tela de fim (MENU ou ver o pódio)
		_fim_para_mim = true
	var titulo := UI.label("COPA CRAQUE DE BOTÃO", Jogo.fonte("titan", 44, 5), Color.white)
	UI.colocar(titulo, 0, 12, 1280, 60)
	add_child(titulo)
	var fase := ""
	if campeao != "":
		fase = "CAMPEÃO!" if Jogo.jogador_de(campeao) > 0 else "FIM DA COPA"
	else:
		var fz := Jogo.copa_fase()
		fase = "DECISÃO DO 3º LUGAR  •  JOGO ÚNICO" if fz == "terceiro" else "%s  •  %s" % [FASES[int(c.rodada)], "JOGO DE IDA" if int(c.perna) == 0 else "JOGO DE VOLTA"]
	var lf := UI.label(fase, Jogo.fonte("bungee", 26, 2), Jogo.AMARELO)
	UI.colocar(lf, 0, 68, 1280, 36)
	add_child(lf)
	UI.pop(lf, 0.2)

	_linhas = Control.new()
	_linhas.anchor_right = 1
	_linhas.anchor_bottom = 1
	_linhas.mouse_filter = MOUSE_FILTER_IGNORE
	_linhas.connect("draw", self, "_desenhar_linhas")
	add_child(_linhas)

	_trofeu = TextureRect.new()
	_trofeu.texture = load("res://imagens/trofeu.png")
	_trofeu.expand = true
	UI.colocar(_trofeu, 640 - 62, 150, 124, 174)
	_trofeu.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_trofeu)

	_montar_chave()

	var sair := UI.botao("MENU" if campeao != "" else "SAIR DA COPA", Color(0.3, 0.1, 0.1), Jogo.fonte("titan", 24, 2))
	UI.colocar(sair, 40, 626, 230, 64)
	sair.connect("pressed", self, "_sair")
	add_child(sair)
	if campeao != "":
		_festa(campeao)
	else:
		_proximo_jogo()
	Jogo.musica_fundo()
	if _fim_para_mim:
		_tela_fim()


func _proximo_jogo() -> void:
	var c: Dictionary = Jogo.copa
	var j = Jogo.copa_jogo_do_jogador()
	var unico: bool = j.get("unico", false)
	var ida: bool = int(c.perna) == 0 or unico
	var casa: String = j.a if ida else j.b
	var fora: String = j.b if ida else j.a
	# painel de transmissão: os dois escudos, o jogo, o estádio
	var p := UI.painel(Jogo.OURO, Color(0.02, 0.05, 0.12, 0.94), 16, 2, 14)
	UI.colocar(p, 220, 518, 840, 96)
	add_child(p)
	UI.deslizar(p, Vector2(0, 40), 0.3)
	for i in [0, 1]:
		var sg := casa if i == 0 else fora
		var e := TextureRect.new()
		e.texture = Jogo.emblema(sg)
		e.expand = true
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		UI.colocar(e, 18 if i == 0 else 840 - 18 - 74, 11, 74, 74)
		e.mouse_filter = MOUSE_FILTER_IGNORE
		p.add_child(e)
		var n := UI.label(_com_jogador(sg), Jogo.fonte("bungee", 19, 2), Color.white, Label.ALIGN_LEFT if i == 0 else Label.ALIGN_RIGHT)
		UI.colocar(n, 102 if i == 0 else 840 - 102 - 260, 14, 260, 34)
		p.add_child(n)
	var vs := UI.label("x", Jogo.fonte("titan", 34, 3), Jogo.OURO)
	UI.colocar(vs, 370, 6, 100, 46)
	p.add_child(vs)
	var tipo := "DECISÃO DO 3º LUGAR  •  JOGO ÚNICO" if unico else ("JOGO DE IDA" if ida else "JOGO DE VOLTA  •  IDA %s %d x %d %s" % [j.a, j.ida[0], j.ida[1], j.b])
	var l2 := UI.label("%s  •  %s" % [tipo, Jogo.selecao(casa).estadio], Jogo.fonte("texto", 17, 1), Jogo.CIANO)
	UI.colocar(l2, 0, 56, 840, 30)
	p.add_child(l2)
	var b := UI.botao("JOGAR", Jogo.VERDE, Jogo.fonte("titan", 36, 3))
	UI.colocar(b, 530, 628, 220, 76)
	b.connect("pressed", self, "_jogar")
	add_child(b)
	UI.pop(b, 0.5)
	b.call_deferred("grab_focus")


## "BRASIL (J1)" ou "ARGENTINA (CPU)".
func _com_jogador(sigla: String) -> String:
	var j := Jogo.jogador_de(sigla)
	return "%s (%s)" % [Jogo.selecao(sigla).nome, ("J%d" % j) if j > 0 else "CPU"]


## Posição do chip: rodada r, jogo k, lado 0 (a) / 1 (b). r = 3: 3º lugar.
func _pos(r: int, k: int, lado: int) -> Vector2:
	if r == 0:
		var x := 26.0 if k < 2 else 1280.0 - 26.0 - CHIP.x
		return Vector2(x, 112.0 + (k % 2) * 186.0 + lado * (CHIP.y + 6))
	if r == 1:
		var x2 := 262.0 if k == 0 else 1280.0 - 262.0 - CHIP.x
		return Vector2(x2, 205.0 + lado * (CHIP.y + 6))
	if r == 2:
		return Vector2(640 - CHIP.x - 6 if lado == 0 else 646, 372)
	return Vector2(640 - CHIP.x - 6 if lado == 0 else 646, 452)


func _montar_chave() -> void:
	var c: Dictionary = Jogo.copa
	var atual := Jogo.copa_jogo_atual()
	for r in range(3):
		if r >= c.jogos.size():
			# rodada ainda sem jogos: chips vazios
			var n := 4 >> r
			for k in range(n):
				for lado in [0, 1]:
					_chip("", null, 0, _pos(r, k, lado), r, k, false)
			if r == 2:
				for lado in [0, 1]:
					_chip("", null, 0, _pos(3, 0, lado), 3, 0, false)
			continue
		var rodada: Array = c.jogos[r]
		var k := 0
		for j in rodada:
			var rr := 3 if j.get("unico", false) else r
			var kk := 0 if rr == 3 else k
			for lado in [0, 1]:
				_chip(j.a if lado == 0 else j.b, j, lado, _pos(rr, kk, lado), rr, kk, j == atual)
			if rr != 3:
				k += 1
		if r == 2 and rodada.size() == 1:
			for lado in [0, 1]:
				_chip("", null, 0, _pos(3, 0, lado), 3, 0, false)
	var l3 := UI.label("DISPUTA DO 3º LUGAR", Jogo.fonte("bungee", 14, 1), Color(0.85, 0.7, 0.45), Label.ALIGN_CENTER)
	UI.colocar(l3, 440, 428, 400, 22)
	add_child(l3)
	_linhas.update()


## Um time na chave: escudo, sigla, agregado (e pênaltis), e embaixo os gols
## de cada jogo (ida/volta) e o dono (JOGADOR n).
func _chip(sigla: String, j, lado: int, pos: Vector2, r: int, k: int, atual: bool) -> void:
	var eu = sigla != "" and Jogo.jogador_de(sigla) > 0
	var venceu: bool = j != null and j.v != "" and j.v == sigla
	var caiu: bool = j != null and j.v != "" and j.v != sigla
	var cor := Jogo.AMARELO if eu else (Color(0.3, 0.9, 0.5) if venceu else Color(1, 1, 1, 0.35))
	var fundo := Color(0.03, 0.07, 0.15, 0.94) if not caiu else Color(0.03, 0.04, 0.07, 0.85)
	var p := UI.painel(cor, fundo, 10, 3 if (eu or atual) else 2, 12 if atual else (6 if eu else 3))
	UI.colocar(p, pos.x, pos.y, CHIP.x, CHIP.y)
	add_child(p)
	UI.pop(p, 0.06 + r * 0.16 + k * 0.04, 0.35, 0.7)
	if atual:
		_atuais.append(p)
	if sigla == "":
		var l := UI.label("?", Jogo.fonte("bungee", 18, 2), Color(1, 1, 1, 0.35))
		UI.colocar(l, 0, 0, CHIP.x, CHIP.y)
		p.add_child(l)
		return
	var emb := TextureRect.new()
	emb.texture = Jogo.emblema(sigla)
	emb.expand = true
	emb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UI.colocar(emb, 5, 4, 40, 40)
	emb.mouse_filter = MOUSE_FILTER_IGNORE
	emb.modulate = Color(1, 1, 1, 0.45) if caiu else Color.white
	p.add_child(emb)
	var n := UI.label(sigla, Jogo.fonte("bungee", 20, 2), Color.white if not caiu else Color(0.6, 0.65, 0.72), Label.ALIGN_LEFT)
	UI.colocar(n, 52, 2, 80, 28)
	p.add_child(n)
	var sub := ""
	if eu:
		sub = "JOGADOR %d" % Jogo.jogador_de(sigla)
	var detalhe := ""
	if j != null and not j.ida.empty():
		var g_ida: int = j.ida[lado]
		if j.get("unico", false):
			detalhe = "jogo único"
		elif j.volta.empty():
			detalhe = "ida %d" % g_ida
		else:
			detalhe = "ida %d  •  volta %d" % [g_ida, j.volta[lado]]
		var ag := Jogo.agregado(j)
		var txt := str(ag[lado])
		var pen: int = j.pa if lado == 0 else j.pb
		if pen >= 0:
			txt += " (%d)" % pen
		var g := UI.label(txt, Jogo.fonte("titan", 22, 2), Jogo.AMARELO if venceu else Color.white, Label.ALIGN_RIGHT)
		UI.colocar(g, 100, 0, CHIP.x - 108, 32)
		p.add_child(g)
	if sub != "" or detalhe != "":
		var ls := UI.label(sub, Jogo.fonte("texto", 11, 0), Jogo.AMARELO, Label.ALIGN_LEFT)
		UI.colocar(ls, 52, 30, 80, 16)
		p.add_child(ls)
		var ld := UI.label(detalhe, Jogo.fonte("texto", 11, 0), Color(0.75, 0.82, 0.9), Label.ALIGN_RIGHT)
		UI.colocar(ld, 92, 30, CHIP.x - 100, 16)
		p.add_child(ld)


## Linhas da chave: o caminho de quem passou fica dourado.
func _desenhar_linhas() -> void:
	var c: Dictionary = Jogo.copa
	for r in range(2):
		var n := 4 >> r
		for k in range(n):
			var jogo = null
			if r < c.jogos.size():
				var lista := []
				for jj in c.jogos[r]:
					if not jj.get("unico", false):
						lista.append(jj)
				if k < lista.size():
					jogo = lista[k]
			var esquerda := k < n / 2
			for lado in [0, 1]:
				var p := _pos(r, k, lado) + Vector2(0, CHIP.y / 2)
				var x_saida := p.x + CHIP.x if esquerda else p.x
				var x_meio := x_saida + (18.0 if esquerda else -18.0)
				var passou: bool = jogo != null and jogo.v != "" and jogo.v == (jogo.a if lado == 0 else jogo.b)
				var cor := Jogo.OURO if passou else Color(1, 1, 1, 0.25)
				var esp := 4.0 if passou else 2.0
				_linhas.draw_line(Vector2(x_saida, p.y), Vector2(x_meio, p.y), cor, esp, true)
				var meio_y := (_pos(r, k, 0).y + _pos(r, k, 1).y) / 2 + CHIP.y / 2
				_linhas.draw_line(Vector2(x_meio, p.y), Vector2(x_meio, meio_y), cor, esp, true)
				if passou or lado == 0:
					var alvo: Vector2
					var x_alvo := 0.0
					if r == 0:
						alvo = _pos(1, k / 2, k % 2) + Vector2(0, CHIP.y / 2)
						x_alvo = alvo.x if esquerda else alvo.x + CHIP.x
						_linhas.draw_line(Vector2(x_meio, meio_y), Vector2(x_meio, alvo.y), cor, esp, true)
						_linhas.draw_line(Vector2(x_meio, alvo.y), Vector2(x_alvo, alvo.y), cor, esp, true)
					else:
						alvo = _pos(2, 0, k) + Vector2(CHIP.x / 2, 0)
						_linhas.draw_line(Vector2(x_meio, meio_y), Vector2(alvo.x, meio_y), cor, esp, true)
						_linhas.draw_line(Vector2(alvo.x, meio_y), Vector2(alvo.x, alvo.y), cor, esp, true)


func _festa(campeao: String) -> void:
	var c: Dictionary = Jogo.copa
	var eu: bool = Jogo.jogador_de(campeao) > 0
	var s := Jogo.selecao(campeao)
	_cenario.torcida.cores(s.torcida, s.torcida)
	_cenario.torcida.pular(0, 1.0, 30.0)
	_cenario.torcida.pular(1, 1.0, 30.0)
	# o pódio: 2º, 1º (mais alto) e 3º
	var podio: Array = c.get("podio", [campeao, "", ""])
	var p := UI.painel(Jogo.OURO, Color(0.02, 0.05, 0.12, 0.94), 16, 2, 14)
	UI.colocar(p, 300, 518, 680, 100)
	add_child(p)
	UI.deslizar(p, Vector2(0, 40), 0.3)
	var ordem := [[1, 120.0, "2º"], [0, 340.0, "1º"], [2, 560.0, "3º"]]
	for o in ordem:
		var sg: String = podio[o[0]] if podio.size() > o[0] else ""
		if sg == "":
			continue
		var e := TextureRect.new()
		e.texture = Jogo.emblema(sg)
		e.expand = true
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tam := 70.0 if o[0] == 0 else 52.0
		UI.colocar(e, o[1] - tam / 2, 8 + (70.0 - tam), tam, tam)
		e.mouse_filter = MOUSE_FILTER_IGNORE
		p.add_child(e)
		var l := UI.label("%s  %s" % [o[2], Jogo.selecao(sg).nome], Jogo.fonte("bungee", 14 if o[0] else 16, 1), Jogo.OURO if o[0] == 0 else Color.white)
		UI.colocar(l, o[1] - 110, 76, 220, 22)
		p.add_child(l)
	var quem = ("%s CAMPEÃO!" % s.nome) if not eu else ("JOGADOR %d CAMPEÃO: %s!" % [Jogo.jogador_de(campeao), s.nome] if c.humanos.size() > 1 else "VOCÊ É CAMPEÃO!")
	var titulo := UI.label(quem, Jogo.fonte("titan", 34, 4), Jogo.AMARELO)
	UI.colocar(titulo, 0, 470, 1280, 46)
	add_child(titulo)
	UI.pop(titulo, 0.6)
	var n := int(Jogo.titulos.get(campeao, 0))
	var lt := UI.label("%s: %d %s" % [s.nome, n, "TÍTULO" if n == 1 else "TÍTULOS"], Jogo.fonte("bungee", 16, 2), Color.white)
	UI.colocar(lt, 0, 436, 1280, 30)
	add_child(lt)
	if eu:
		Jogo.tocar_grupo("comemoracao", "torcida_gol")
		Jogo.tocar("fogos")
		for i in range(2):
			var cf := CPUParticles2D.new()
			cf.texture = load("res://imagens/confete.png")
			cf.amount = 90
			cf.lifetime = 3.5
			cf.position = Vector2(640, -20)
			cf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			cf.emission_rect_extents = Vector2(660, 10)
			cf.direction = Vector2(0, 1)
			cf.spread = 25
			cf.gravity = Vector2(0, 150)
			cf.initial_velocity = 150
			cf.initial_velocity_random = 0.6
			cf.angular_velocity = 300
			cf.angular_velocity_random = 1.0
			cf.color = Color(s.torcida[i])
			add_child(cf)
	var nova := UI.botao("NOVA COPA", Jogo.VERDE, Jogo.fonte("titan", 30, 3))
	UI.colocar(nova, 530, 630, 220, 72)
	nova.connect("pressed", self, "_nova_copa")
	add_child(nova)
	nova.call_deferred("grab_focus")


func _process(delta: float) -> void:
	_t += delta
	if _trofeu:
		_trofeu.rect_rotation = sin(_t * 1.4) * 2.0
		_trofeu.rect_pivot_offset = Vector2(62, 174)
	for p in _atuais:
		if is_instance_valid(p):
			UI.cor_painel(p, Jogo.AMARELO.linear_interpolate(Color.white, 0.5 + 0.5 * sin(_t * 3.0)))


## FIM DA COPA PARA O JOGADOR: a colocação dele e duas saídas: VOLTAR AO
## MENU (o lobby) ou VER O PÓDIO (a festa do campeão em 3D). O manche só
## anda entre esses dois botões; o BOTÃO confirma.
func _tela_fim() -> void:
	var c: Dictionary = Jogo.copa
	var veu := ColorRect.new()
	veu.color = Color(0.0, 0.02, 0.06, 0.78)
	veu.anchor_right = 1
	veu.anchor_bottom = 1
	veu.mouse_filter = MOUSE_FILTER_STOP
	add_child(veu)
	var p := UI.painel(Jogo.OURO, Color(0.03, 0.06, 0.15, 0.97), 22, 3, 24)
	UI.colocar(p, 240, 150, 800, 420)
	veu.add_child(p)
	UI.pop(p, 0.05, 0.35, 0.7)
	var eu: String = c.humanos[0]
	var colocacao := _colocacao(eu)
	var t := UI.label("FIM DA COPA", Jogo.fonte("titan", 54, 5), Color.white)
	UI.colocar(t, 0, 22, 800, 70)
	p.add_child(t)
	var e := TextureRect.new()
	e.texture = Jogo.emblema(eu)
	e.expand = true
	e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	e.mouse_filter = MOUSE_FILTER_IGNORE
	UI.colocar(e, 400 - 55, 100, 110, 110)
	p.add_child(e)
	var l := UI.label("%s  •  %s" % [Jogo.selecao(eu).nome, colocacao], Jogo.fonte("bungee", 26, 2), Jogo.AMARELO)
	UI.colocar(l, 0, 218, 800, 40)
	p.add_child(l)
	var camp := UI.label("CAMPEÃO: %s" % Jogo.selecao(c.campeao).nome, Jogo.fonte("texto", 22, 1), Color(1, 1, 1, 0.85))
	UI.colocar(camp, 0, 258, 800, 32)
	p.add_child(camp)
	var menu := UI.botao("VOLTAR AO MENU", Jogo.AZUL, Jogo.fonte("titan", 28, 3))
	UI.colocar(menu, 60, 310, 320, 80)
	menu.connect("pressed", self, "_sair")
	p.add_child(menu)
	var ver := UI.botao("VER O PÓDIO", Jogo.VERDE, Jogo.fonte("titan", 28, 3))
	UI.colocar(ver, 420, 310, 320, 80)
	ver.connect("pressed", self, "_ver_podio")
	p.add_child(ver)
	# o foco fica preso nos dois botões (nada atrás do véu é escolhido)
	for b in [menu, ver]:
		var outro: Button = ver if b == menu else menu
		for lado in ["left", "right", "top", "bottom"]:
			b.set("focus_neighbour_" + lado, b.get_path_to(outro) if lado in ["left", "right"] else NodePath("."))
		b.focus_next = b.get_path_to(outro)
		b.focus_previous = b.get_path_to(outro)
	menu.call_deferred("grab_focus")


func _colocacao(sigla: String) -> String:
	var c: Dictionary = Jogo.copa
	var podio: Array = c.get("podio", [])
	var i := podio.find(sigla)
	if i == 1:
		return "VICE-CAMPEÃO"
	if i == 2:
		return "3º LUGAR"
	var r := 0
	for rodada in c.jogos:
		for j in rodada:
			if j.a == sigla or j.b == sigla:
				if j.get("unico", false):
					return "4º LUGAR"
		r += 1
	for k in range(c.jogos.size()):
		for j in c.jogos[k]:
			if (j.a == sigla or j.b == sigla) and j.v != "" and j.v != sigla and not j.get("unico", false):
				return ["ELIMINADO NAS QUARTAS", "ELIMINADO NA SEMIFINAL", "VICE-CAMPEÃO"][clamp(k, 0, 2)]
	return "ELIMINADO"


func _ver_podio() -> void:
	if _saindo:
		return
	_saindo = true
	Jogo.tocar("confirma")
	Jogo.copa["podio_visto"] = true
	Jogo.ir_para("res://cenas/podio.tscn")


func _jogar() -> void:
	if _saindo:
		return
	_saindo = true
	Jogo.tocar("confirma")
	Jogo.copa_preparar_partida()
	Jogo.ir_para("res://cenas/preparacao.tscn")


func _nova_copa() -> void:
	if _saindo:
		return
	_saindo = true
	Jogo.tocar("confirma")
	Jogo.partida.modo = "copa"
	Jogo.copa = {}
	Jogo.ir_para("res://cenas/selecao.tscn")


func _sair() -> void:
	if _saindo:
		return
	_saindo = true
	Jogo.tocar("volta")
	Jogo.copa = {}
	Jogo.ir_para("res://cenas/menu.tscn")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_sair()
