extends Node

## CONTROLES DO FLIPERAMA (autoload "Controles").
##
## Duas placas zero delay IGUAIS ("paralelas"): cada uma tem 1 manche e 1
## botão. A ligação é a mesma nas duas (ex.: botão no L3 das duas placas);
## por isso existe um MOLDE só, que vale para as duas placas. Cada jogador
## usa a sua placa (aparelho = device) e o molde vira as ações do InputMap
## "p1_cima", "p2_chute"...
##
## O BOTÃO faz tudo: chuta na partida, dá START na abertura e confirma nos
## menus (escolher time, jogar...). O manche anda pelos menus e, no jogo,
## troca o botão (cima/baixo) e mira (esq/dir).
##
## Molde padrão (funciona sem configurar): manche em alavanca (analógico) OU
## direcional (digital), e QUALQUER botão da placa = chute. Teclado para
## testes: jogador 1 W A S D + ESPAÇO; jogador 2 setas + ENTER; ESC pausa.
##
## Formato do molde: "b:<botão>", "b:*" (qualquer botão que não seja direção),
## "a:<eixo>:<+1|-1>". Gravado em user://controles.cfg.
##
## Jogador 3 = "qualquer placa" (1 jogador contra a CPU: joga em qualquer uma).
##
## UMA PLACA SÓ (economia, docs\DIAGRAMA_PLACA_UNICA.png): com uma placa
## ligada, os DOIS jogadores ficam nela. Jogador 1: manche no conector
## JOYSTICK + o botão dele (qualquer botão que não seja do jogador 2).
## Jogador 2: manche ligado em 4 portas de botão (padrão K5 cima, K6 baixo,
## K7 esquerda, K8 direita) + o botão K2. A tela CONFIGURAR PLACA grava a
## ligação real dos dois jogadores (user://controles_uma_placa.cfg).

const CAMINHO := "user://controles.cfg"
const CAMINHO_UNICA := "user://controles_uma_placa.cfg"
const ACOES := ["cima", "baixo", "esq", "dir", "chute", "pausa"]
const DIRECOES := ["cima", "baixo", "esq", "dir"]
const NOMES := {"cima": "CIMA", "baixo": "BAIXO", "esq": "ESQUERDA", "dir": "DIREITA", "chute": "BOTÃO", "pausa": "PAUSA"}
const DIRECIONAL := {12: "CIMA", 13: "BAIXO", 14: "ESQ.", 15: "DIR."}
const TECLAS := {
	1: {"cima": [KEY_W], "baixo": [KEY_S], "esq": [KEY_A], "dir": [KEY_D], "chute": [KEY_SPACE], "pausa": [KEY_ESCAPE]},
	2: {"cima": [KEY_UP], "baixo": [KEY_DOWN], "esq": [KEY_LEFT], "dir": [KEY_RIGHT], "chute": [KEY_ENTER, KEY_KP_ENTER], "pausa": [KEY_P]},
}

var molde := {}            # "cima" -> ["a:1:-1", "b:12"], "chute" -> ["b:*"]
var personalizado := false
var placas := [0, 1]       # aparelho (device) do jogador 1 e do jogador 2
var placas_definidas := false   # alguém já disse qual placa é de quem
var uma_placa := false     # uma placa só, com os dois jogadores
var molde_unica := {}      # {1: molde do jogador 1, 2: molde do jogador 2}
var unica_personalizada := false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	molde = padrao()
	var c := ConfigFile.new()
	if c.load(CAMINHO) == OK and c.has_section("molde"):
		for a in c.get_section_keys("molde"):
			molde[a] = c.get_value("molde", a, molde.get(a, []))
		personalizado = true
	molde_unica = padrao_unica()
	var c2 := ConfigFile.new()
	if c2.load(CAMINHO_UNICA) == OK:
		for j in [1, 2]:
			var sec = "jogador%d" % j
			if c2.has_section(sec):
				for a in c2.get_section_keys(sec):
					molde_unica[j][a] = c2.get_value(sec, a, [])
		unica_personalizada = true
	_ordenar_placas()
	Input.connect("joy_connection_changed", self, "_placa_mudou")
	aplicar()


static func padrao() -> Dictionary:
	return {
		"cima": ["a:%d:-1" % JOY_AXIS_1, "b:%d" % JOY_DPAD_UP],
		"baixo": ["a:%d:1" % JOY_AXIS_1, "b:%d" % JOY_DPAD_DOWN],
		"esq": ["a:%d:-1" % JOY_AXIS_0, "b:%d" % JOY_DPAD_LEFT],
		"dir": ["a:%d:1" % JOY_AXIS_0, "b:%d" % JOY_DPAD_RIGHT],
		"chute": ["b:*"],
		"pausa": [],
	}


## Uma placa só, os dois jogadores nela (padrão): jogador 1 no conector do
## manche (alavanca ou direcional) e qualquer botão que não seja do jogador 2;
## jogador 2 com o manche em 4 portas de botão e o seu botão. Cada porta vem
## nas duas numerações (Windows/Linux: K1 = botão 0; Android em placas
## genéricas: K1 = botão 20).
static func padrao_unica() -> Dictionary:
	return {
		1: {"cima": ["a:%d:-1" % JOY_AXIS_1, "b:%d" % JOY_DPAD_UP], "baixo": ["a:%d:1" % JOY_AXIS_1, "b:%d" % JOY_DPAD_DOWN],
			"esq": ["a:%d:-1" % JOY_AXIS_0, "b:%d" % JOY_DPAD_LEFT], "dir": ["a:%d:1" % JOY_AXIS_0, "b:%d" % JOY_DPAD_RIGHT],
			"chute": ["b:*"], "pausa": []},
		2: {"cima": ["b:4", "b:24"], "baixo": ["b:5", "b:25"], "esq": ["b:6", "b:26"], "dir": ["b:7", "b:27"],
			"chute": ["b:1", "b:21"], "pausa": []},
	}


## Placas na ordem em que o aparelho as vê (a menor = jogador 1).
func _ordenar_placas() -> void:
	if placas_definidas:
		return
	var lista := Input.get_connected_joypads()
	lista.sort()
	placas = [lista[0] if lista.size() > 0 else 0, lista[1] if lista.size() > 1 else 1]
	if placas[0] == placas[1]:
		placas[1] = placas[0] + 1


func _placa_mudou(_dev: int, _ligada: bool) -> void:
	placas_definidas = false
	_ordenar_placas()
	aplicar()


## Uma placa ligada (ou nenhuma): modo UMA PLACA, os dois jogadores nela.
func _decidir_modo() -> void:
	uma_placa = Input.get_connected_joypads().size() <= 1


func placas_ligadas() -> int:
	return Input.get_connected_joypads().size()


## A placa "dev" passa a ser do jogador 1 (a outra, do jogador 2).
func definir_placa_do_jogador1(dev: int) -> void:
	if dev != placas[0]:
		var outra: int = placas[0]
		for d in Input.get_connected_joypads():
			if d != dev:
				outra = d
				break
		placas = [dev, outra if outra != dev else dev + 1]
	placas_definidas = true
	aplicar()


# ------------------------------------------------------------- InputMap
func _eventos_da_placa(dev: int, acao: String) -> Array:
	return _eventos(dev, molde, acao, [])


## Botões que um molde usa (para o "qualquer botão" do outro jogador não
## pegar os botões dele).
static func _botoes_do_molde(m: Dictionary) -> Array:
	var r := []
	for a in m:
		for t2 in m[a]:
			if t2.begins_with("b:") and t2 != "b:*":
				r.append(int(t2.split(":")[1]))
	return r


func _eventos(dev: int, m: Dictionary, acao: String, excluir: Array) -> Array:
	var r := []
	for txt in m.get(acao, []):
		var p: PoolStringArray = txt.split(":")
		if p[0] == "b" and p[1] == "*":
			var usados := excluir.duplicate()
			for d in DIRECOES:
				for t2 in m.get(d, []):
					if t2.begins_with("b:") and t2 != "b:*":
						usados.append(int(t2.split(":")[1]))
			# até 64: no Android as placas genéricas mandam BUTTON_1..16, que
			# viram os botões 20 a 35 (o L3 de muitas placas cai aí)
			for b in range(0, 64):
				if not b in usados:
					r.append(_botao(dev, b))
		elif p[0] == "b":
			r.append(_botao(dev, int(p[1])))
		elif p[0] == "a" and p.size() >= 3:
			var mo := InputEventJoypadMotion.new()
			mo.device = dev
			mo.axis = int(p[1])
			mo.axis_value = float(p[2])
			r.append(mo)
	return r


static func _botao(dev: int, b: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = b
	return e


static func _tecla(k: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.scancode = k
	return e


## Monta o InputMap (jogadores e navegação dos menus).
func aplicar() -> void:
	_decidir_modo()
	for p in [1, 2]:
		for a in ACOES:
			var nome := "p%d_%s" % [p, a]
			if InputMap.has_action(nome):
				InputMap.action_erase_events(nome)
			else:
				InputMap.add_action(nome, 0.5)
			var evs: Array
			if uma_placa:
				# os dois jogadores na mesma placa (a primeira ligada)
				evs = _eventos(placas[0], molde_unica[p], a, _botoes_do_molde(molde_unica[3 - p]))
			else:
				evs = _eventos_da_placa(placas[p - 1], a)
			for ev in evs:
				InputMap.action_add_event(nome, ev)
			for k in TECLAS[p][a]:
				InputMap.action_add_event(nome, _tecla(k))
	# menus: as duas placas navegam e o BOTÃO de qualquer uma confirma
	var ui := {"ui_up": "cima", "ui_down": "baixo", "ui_left": "esq", "ui_right": "dir", "ui_accept": "chute"}
	for u in ui:
		for ev in InputMap.get_action_list(u):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(u, ev)
		for p in [1, 2]:
			for ev in InputMap.get_action_list("p%d_%s" % [p, ui[u]]):
				if not InputMap.action_has_event(u, ev):
					InputMap.action_add_event(u, ev)


## Para a tela de configuração: o que foi apertado agora, sem o aparelho.
## Devolve [molde, aparelho] ou [] se não serve.
func capturar(ev: InputEvent) -> Array:
	if ev is InputEventJoypadButton and ev.pressed:
		return ["b:%d" % ev.button_index, ev.device]
	if ev is InputEventJoypadMotion and abs(ev.axis_value) > 0.7:
		return ["a:%d:%d" % [ev.axis, 1 if ev.axis_value > 0 else -1], ev.device]
	return []


static func descrever(txt: String) -> String:
	var p := txt.split(":")
	match p[0]:
		"b":
			if p[1] == "*":
				return "QUALQUER BOTÃO"
			var b := int(p[1])
			if DIRECIONAL.has(b):
				return "DIRECIONAL " + DIRECIONAL[b]
			if b == JOY_L3:
				return "BOTÃO L3"
			if b == JOY_R3:
				return "BOTÃO R3"
			if b == JOY_START:
				return "START"
			if b == JOY_SELECT:
				return "SELECT"
			return "BOTÃO %d" % (b + 1)
		"a":
			var eixo := int(p[1])
			var mais := p[2] == "1"
			if eixo == JOY_AXIS_0 or eixo == JOY_AXIS_2:
				return "ALAVANCA " + ("DIR." if mais else "ESQ.")
			if eixo == JOY_AXIS_1 or eixo == JOY_AXIS_3:
				return "ALAVANCA " + ("BAIXO" if mais else "CIMA")
			return "EIXO %d %s" % [eixo, "+" if mais else "-"]
	return txt


## Grava o molde feito na tela de configuração (vale para as duas placas).
func salvar(novo: Dictionary) -> void:
	molde = novo
	personalizado = true
	var c := ConfigFile.new()
	for a in molde:
		c.set_value("molde", a, molde[a])
	c.save(CAMINHO)
	aplicar()


## Grava a ligação da placa única (jogador 1 e jogador 2).
func salvar_unica(novo: Dictionary) -> void:
	molde_unica = novo
	unica_personalizada = true
	var c := ConfigFile.new()
	for j in [1, 2]:
		for a in molde_unica[j]:
			c.set_value("jogador%d" % j, a, molde_unica[j][a])
	c.save(CAMINHO_UNICA)
	aplicar()


func restaurar_padrao() -> void:
	molde = padrao()
	personalizado = false
	molde_unica = padrao_unica()
	unica_personalizada = false
	var d := Directory.new()
	for arq in [CAMINHO, CAMINHO_UNICA]:
		if d.file_exists(arq):
			d.remove(arq)
	aplicar()


# ------------------------------------------------------------ consultas
## p: 1, 2 ou 3 (= qualquer placa).
static func _jogadores(p: int) -> Array:
	return [1, 2] if p == 3 else [p]


func segurando(p: int, acao: String) -> bool:
	for j in _jogadores(p):
		if Input.is_action_pressed("p%d_%s" % [j, acao]):
			return true
	return false


func acabou_de_apertar(p: int, acao: String) -> bool:
	for j in _jogadores(p):
		if Input.is_action_just_pressed("p%d_%s" % [j, acao]):
			return true
	return false


## O evento é "apertou agora" desta ação do jogador p?
func apertou(ev: InputEvent, p: int, acao: String) -> bool:
	if ev.is_echo():
		return false
	for j in _jogadores(p):
		if ev.is_action_pressed("p%d_%s" % [j, acao]):
			return true
	return false


func soltou(ev: InputEvent, p: int, acao: String) -> bool:
	for j in _jogadores(p):
		if ev.is_action_released("p%d_%s" % [j, acao]):
			# jogador 3: só solta de verdade quando nenhuma das placas segura
			return p != 3 or not segurando(3, acao)
	return false


## Qual jogador (1/2) apertou algo neste evento (0 = nenhum).
func quem(ev: InputEvent) -> int:
	for p in [1, 2]:
		for a in ACOES:
			if ev.is_action_pressed("p%d_%s" % [p, a]):
				return p
	return 0
