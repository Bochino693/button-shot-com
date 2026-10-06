extends Control

## CONTROLES. Com UMA PLACA ligada, os dois jogadores ficam nela (manche do
## jogador 1 no conector JOYSTICK, manche do jogador 2 em 4 portas de botão;
## um botão para cada um): CONFIGURAR PLACA pede os 5 do jogador 1 e depois
## os 5 do jogador 2. Com DUAS placas, elas são IGUAIS (1 manche + 1 botão
## cada, ligados nos mesmos pinos) e a ligação gravada vale para as duas:
##   CONFIGURAR PLACA: aperte, em QUALQUER uma das placas, o que o jogo pedir
##     (cima, baixo, esquerda, direita e o botão). Ex.: botão no L3 -> o L3
##     vira o chute/start/confirmar nas duas placas.
##   JOGADOR 1: o jogador 1 aperta o botão da placa dele (a outra é do 2).
##   TESTAR: as luzes de cada jogador acendem com o manche e o botão.
##   PADRÃO: manche (alavanca ou direcional) + qualquer botão.

const UI = preload("res://scripts/ui.gd")
const Cenario = preload("res://scripts/cenario.gd")

const PASSOS := ["cima", "baixo", "esq", "dir", "chute"]
const SAIR_TESTE := 2.0

var _linhas := {}          # acao -> Label com a ligação
var _luzes := {}           # "p1_cima" -> Panel
var _info: Label
var _botoes := []
var _aviso: Label
var _sub: Label
# assistente
var _modo := ""            # "" | "placa" | "jogador1" | "teste"
var _passo := 0
var _novo := {}
var _t := 0.0
var _base_eixos := {}
var _eixo_preso := ""
var _t_segura := 0.0
var _saindo := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var c = Cenario.new()
	c.escurecer = 0.7
	add_child(c)
	var t := UI.label("CONTROLES  •  UMA PLACA, DOIS JOGADORES" if Controles.uma_placa else "CONTROLES  •  DUAS PLACAS IGUAIS", Jogo.fonte("titan", 40, 4), Color.white)
	UI.colocar(t, 0, 14, 1280, 60)
	add_child(t)
	# ligação (molde) das placas
	var p := UI.painel(Jogo.CIANO, Color(0.02, 0.05, 0.12, 0.92), 18, 3, 12)
	UI.colocar(p, 70, 88, 560, 400)
	add_child(p)
	var tp := UI.label("LIGAÇÃO  (J1  /  J2)" if Controles.uma_placa else "LIGAÇÃO (vale para as duas placas)", Jogo.fonte("bungee", 20, 2), Jogo.CIANO)
	UI.colocar(tp, 0, 10, 560, 40)
	p.add_child(tp)
	for i in range(PASSOS.size()):
		var a: String = PASSOS[i]
		var f := UI.painel(Color(1, 1, 1, 0.25), Color(0.06, 0.1, 0.2, 0.9), 10, 1, 0)
		UI.colocar(f, 16, 60 + i * 64, 528, 54)
		p.add_child(f)
		f.set_meta("acao", a)
		var n := UI.label(Controles.NOMES[a], Jogo.fonte("bungee", 20, 2), Color.white, Label.ALIGN_LEFT)
		UI.colocar(n, 16, 0, 160, 54)
		f.add_child(n)
		var v := UI.label("", Jogo.fonte("texto", 15 if Controles.uma_placa else 17, 1), Color(1, 1, 1, 0.85), Label.ALIGN_RIGHT)
		v.clip_text = true
		UI.colocar(v, 170, 0, 344, 54)
		f.add_child(v)
		_linhas[a] = [f, v]
	# as duas placas: de quem é cada uma e as luzes de teste
	var q := UI.painel(Jogo.AMARELO, Color(0.02, 0.05, 0.12, 0.92), 18, 3, 12)
	UI.colocar(q, 650, 88, 560, 400)
	add_child(q)
	var tq := UI.label("PLACAS", Jogo.fonte("bungee", 20, 2), Jogo.AMARELO)
	UI.colocar(tq, 0, 10, 560, 40)
	q.add_child(tq)
	_info = UI.label("", Jogo.fonte("texto", 18, 1), Color(1, 1, 1, 0.85))
	UI.colocar(_info, 20, 50, 520, 60)
	q.add_child(_info)
	for j in [1, 2]:
		var y = 130.0 + (j - 1) * 130.0
		var nj := UI.label("JOGADOR %d" % j, Jogo.fonte("titan", 26, 3), Jogo.CIANO if j == 1 else Color(1, 0.55, 0.5), Label.ALIGN_LEFT)
		UI.colocar(nj, 24, y, 240, 40)
		q.add_child(nj)
		for i in range(PASSOS.size()):
			var a2: String = PASSOS[i]
			var luz := UI.painel(Color(1, 1, 1, 0.4), Color(0.15, 0.15, 0.2), 20, 2, 0)
			UI.colocar(luz, 34 + i * 100, y + 48, 40, 40)
			q.add_child(luz)
			var ln := UI.label(Controles.NOMES[a2], Jogo.fonte("texto", 13, 0), Color(1, 1, 1, 0.7))
			UI.colocar(ln, 4 + i * 100, y + 90, 100, 20)
			q.add_child(ln)
			_luzes["p%d_%s" % [j, a2]] = luz
	var nomes := [["CONFIGURAR PLACA", "_configurar_placa", Jogo.AZUL], ["JOGADOR 1", "_jogador1", Color(0.55, 0.3, 0.05)],
		["TESTAR", "_testar", Color(0.1, 0.5, 0.3)], ["PADRÃO", "_padrao", Color(0.4, 0.3, 0.1)], ["VOLTAR", "_voltar", Color(0.3, 0.1, 0.1)]]
	var larg := [290, 210, 190, 190, 190]
	var x := 70.0
	for i in range(nomes.size()):
		var b := UI.botao(nomes[i][0], nomes[i][2], Jogo.fonte("titan", 22, 2))
		UI.colocar(b, x, 504, larg[i], 64)
		x += larg[i] + 15
		b.connect("pressed", self, nomes[i][1])
		add_child(b)
		_botoes.append(b)
	_aviso = UI.label("", Jogo.fonte("titan", 34, 4), Jogo.AMARELO)
	UI.colocar(_aviso, 0, 584, 1280, 54)
	add_child(_aviso)
	_sub = UI.label("", Jogo.fonte("texto", 19, 1), Color(1, 1, 1, 0.8))
	UI.colocar(_sub, 40, 638, 1200, 60)
	add_child(_sub)
	_sub.autowrap = true
	_mostrar()
	_parado()
	_botoes[4].call_deferred("grab_focus")
	Jogo.musica_fundo(-8.0)


func _parado() -> void:
	_modo = ""
	if Controles.uma_placa:
		_aviso.text = "Uma placa: os dois jogadores nela"
		_sub.text = "J1: manche no conector JOYSTICK + o botão dele. J2: manche em 4 portas de botão (K5 cima, K6 baixo, K7 esq., K8 dir.) + botão K2. Ligou diferente? Toque em CONFIGURAR PLACA e aperte o que o jogo pedir (5 do J1, depois 5 do J2)."
	else:
		_aviso.text = "Cada placa: 1 manche + 1 botão"
		_sub.text = "O BOTÃO chuta, dá START e confirma nos menus. Se as placas usam outro pino (ex.: L3), toque em CONFIGURAR PLACA e aperte o que o jogo pedir, em qualquer uma das placas: as duas ficam iguais."
	for b in _botoes:
		b.disabled = false
	# com uma placa só não há "placa do jogador 1" para escolher
	_botoes[1].disabled = Controles.uma_placa


func _descrever(lista: Array) -> String:
	var partes := []
	for txt in lista:
		partes.append(Controles.descrever(txt))
	return " / ".join(PoolStringArray(partes)) if not partes.empty() else "—"


func _mostrar() -> void:
	if Controles.uma_placa:
		var mu: Dictionary = _novo if _modo == "placa" else Controles.molde_unica
		for a in PASSOS:
			var f: Panel = _linhas[a][0]
			var v: Label = _linhas[a][1]
			# só a ligação principal de cada um (cabe na linha)
			var l1: Array = mu[1].get(a, []) if mu.has(1) else []
			var l2: Array = mu[2].get(a, []) if mu.has(2) else []
			var j1: String = Controles.descrever(l1[0]) if not l1.empty() else "..."
			var j2: String = Controles.descrever(l2[0]) if not l2.empty() else "..."
			v.text = "J1: %s    J2: %s" % [j1, j2]
			var atual: bool = _modo == "placa" and PASSOS[_passo % PASSOS.size()] == a
			UI.cor_painel(f, Jogo.AMARELO if atual else Color(1, 1, 1, 0.25))
		var n1 := Controles.placas_ligadas()
		_info.text = "%d %s  •  os dois jogadores na mesma placa" % [n1, "placa ligada" if n1 == 1 else "placas ligadas"]
		return
	var m: Dictionary = _novo if _modo == "placa" else Controles.molde
	for a in PASSOS:
		var f: Panel = _linhas[a][0]
		var v: Label = _linhas[a][1]
		v.text = _descrever(m.get(a, [])) if m.has(a) else "..."
		UI.cor_painel(f, Jogo.AMARELO if _modo == "placa" and PASSOS[_passo] == a else Color(1, 1, 1, 0.25))
	var nj = Controles.placas_ligadas()
	_info.text = "%d %s  •  jogador 1 = placa %d, jogador 2 = placa %d" % [nj, "placa ligada" if nj == 1 else "placas ligadas", Controles.placas[0] + 1, Controles.placas[1] + 1]


# ---------------------------------------------------------- assistentes
func _comecar(modo: String) -> void:
	_modo = modo
	_t = 0.0
	_base_eixos = {}
	for dev in Input.get_connected_joypads():
		for eixo in range(10):
			_base_eixos["%d_%d" % [dev, eixo]] = Input.get_joy_axis(dev, eixo)
	_eixo_preso = ""
	for b in _botoes:
		b.disabled = b != _botoes[4]      # VOLTAR cancela
		b.release_focus()


func _configurar_placa() -> void:
	if _saindo:
		return
	Jogo.tocar("clique")
	_novo = {1: {"pausa": []}, 2: {"pausa": []}} if Controles.uma_placa else {"pausa": []}
	_passo = 0
	_comecar("placa")
	_pedir()


func _pedir() -> void:
	if Controles.uma_placa:
		_pedir_unica()
		return
	if _passo >= PASSOS.size():
		Controles.salvar(_novo)
		Jogo.tocar("confirma")
		_parado()
		_mostrar()
		_aviso.text = "PLACAS CONFIGURADAS!"
		_sub.text = "As duas placas agora funcionam igual. Toque em TESTAR para conferir."
		_botoes[2].call_deferred("grab_focus")
		return
	var a: String = PASSOS[_passo]
	_aviso.text = "APERTE: %s" % ("O BOTÃO" if a == "chute" else "MANCHE PARA " + Controles.NOMES[a])
	_sub.text = "Em qualquer uma das duas placas. O que for gravado vale para as duas."
	UI.pulsar(_aviso, 0.2)
	_mostrar()


## Uma placa: 5 passos do jogador 1 e depois 5 do jogador 2.
func _pedir_unica() -> void:
	if _passo >= PASSOS.size() * 2:
		Controles.salvar_unica(_novo)
		Jogo.tocar("confirma")
		_parado()
		_mostrar()
		_aviso.text = "PLACA CONFIGURADA!"
		_sub.text = "Os dois jogadores estão na mesma placa. Toque em TESTAR para conferir as luzes de cada um."
		_botoes[2].call_deferred("grab_focus")
		return
	var j := 1 + _passo / PASSOS.size()
	var a: String = PASSOS[_passo % PASSOS.size()]
	_aviso.text = "JOGADOR %d, APERTE: %s" % [j, "O SEU BOTÃO" if a == "chute" else "MANCHE PARA " + Controles.NOMES[a]]
	_sub.text = "Jogador 1: manche do conector JOYSTICK. Jogador 2: o manche ligado nas portas de botão." if a != "chute" else "Cada jogador tem o seu botão (chute, START e confirmar)."
	UI.pulsar(_aviso, 0.2)
	_mostrar()


func _capturou(txt: String) -> void:
	if Controles.uma_placa:
		for jj in [1, 2]:
			for a2 in _novo[jj]:
				if txt in _novo[jj][a2]:
					_sub.text = "Esse já é %s do jogador %d. Aperte outro." % [Controles.NOMES[a2], jj]
					Jogo.tocar("apito_falta", -8.0)
					return
		_novo[1 + _passo / PASSOS.size()][PASSOS[_passo % PASSOS.size()]] = [txt]
		Jogo.tocar("clique")
		_passo += 1
		_pedir()
		return
	for a in _novo:
		if txt in _novo[a]:
			_sub.text = "Esse já é %s. Aperte outro." % Controles.NOMES[a]
			Jogo.tocar("apito_falta", -8.0)
			return
	_novo[PASSOS[_passo]] = [txt]
	Jogo.tocar("clique")
	_passo += 1
	_pedir()


func _jogador1() -> void:
	if _saindo:
		return
	Jogo.tocar("clique")
	_comecar("jogador1")
	_aviso.text = "JOGADOR 1: APERTE O SEU BOTÃO"
	_sub.text = "A placa em que o botão for apertado fica sendo a do jogador 1; a outra, a do jogador 2. (Nas partidas de 2 jogadores o jogo também pergunta.)"


func _input(ev: InputEvent) -> void:
	if _modo == "placa" or _modo == "jogador1":
		var cap := []
		if ev is InputEventJoypadMotion:
			var chave := "%d_%d" % [ev.device, ev.axis]
			var base: float = _base_eixos.get(chave, 0.0)
			if chave == _eixo_preso:
				if abs(ev.axis_value - base) < 0.3:
					_eixo_preso = ""
			elif abs(ev.axis_value) > 0.7 and abs(ev.axis_value - base) > 0.6:
				cap = Controles.capturar(ev)
				if not cap.empty():
					_eixo_preso = chave
		elif ev is InputEventJoypadButton:
			cap = Controles.capturar(ev)
		if ev is InputEventJoypadMotion or ev is InputEventJoypadButton or ev is InputEventKey:
			get_tree().set_input_as_handled()
		if cap.empty():
			return
		if _modo == "placa":
			_capturou(cap[0])
		elif cap[0].begins_with("b:"):
			Controles.definir_placa_do_jogador1(cap[1])
			Jogo.tocar("confirma")
			_parado()
			_mostrar()
			_aviso.text = "JOGADOR 1 = PLACA %d" % (cap[1] + 1)
			_botoes[2].call_deferred("grab_focus")
		return
	if _modo == "teste":
		# no teste o manche só acende as luzes (não mexe nos botões da tela)
		if ev is InputEventJoypadMotion or ev is InputEventJoypadButton or ev is InputEventKey:
			get_tree().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	var segurando := false
	for k in _luzes:
		var aceso: bool = Input.is_action_pressed(k)
		var luz: Panel = _luzes[k]
		var st: StyleBoxFlat = luz.get_stylebox("panel")
		var cor := Jogo.VERDE.lightened(0.3) if aceso else Color(0.15, 0.15, 0.2)
		if st.bg_color != cor:
			st.bg_color = cor
			st.shadow_color = Color(0.3, 1, 0.5, 0.8) if aceso else Color(0, 0, 0, 0)
			st.shadow_size = 12 if aceso else 0
			luz.update()
		if aceso and k.ends_with("_chute"):
			segurando = true
	if _modo == "teste":
		_t_segura = _t_segura + delta if segurando else 0.0
		if _t_segura > SAIR_TESTE:
			_parar_teste()


func _testar() -> void:
	if _saindo:
		return
	Jogo.tocar("clique")
	_modo = "teste"
	_t_segura = 0.0
	_aviso.text = "TESTE: MEXA OS MANCHES E APERTE OS BOTÕES"
	_sub.text = "As luzes do jogador acendem.  Segure o BOTÃO por 2 segundos (ou toque na tela) para sair do teste."
	for b in _botoes:
		b.release_focus()


func _parar_teste() -> void:
	Jogo.tocar("confirma")
	_parado()
	_botoes[2].call_deferred("grab_focus")


func _unhandled_input(ev: InputEvent) -> void:
	if _modo == "teste" and ev is InputEventMouseButton and ev.pressed:
		_parar_teste()


func _padrao() -> void:
	Controles.restaurar_padrao()
	Jogo.tocar("confirma")
	_parado()
	_mostrar()
	_aviso.text = "PADRÃO: MANCHE + QUALQUER BOTÃO"


func _voltar() -> void:
	if _saindo:
		return
	if _modo != "":
		_parado()
		_mostrar()
		return
	_saindo = true
	Jogo.tocar("volta")
	Jogo.ir_para("res://cenas/menu.tscn")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		_voltar()
