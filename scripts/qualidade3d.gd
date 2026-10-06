extends Node

## QUALIDADE DO 3D (para nunca engasgar e nunca ficar "quadrado").
## Cada cena 3D (apresentação do estádio, pódio) tem o seu quadro 3D
## (Viewport). O degrau de qualidade é escolhido ANTES do show, escondido
## atrás da capa de carregamento (palco3d.gd mede os quadros e desce degraus
## até a TV box segurar o ritmo). Durante o show a qualidade fica TRAVADA:
## trocar sombra ou brilho no meio obrigaria o Android a compilar shaders de
## novo (é isso que fazia a apresentação "ciscar"). Se mesmo assim o show
## ficar lento, o degrau seguinte fica salvo para a próxima vez.
## O quadro 3D é sempre ampliado com filtro (nunca pixel "quadrado") e,
## sem MSAA, liga o FXAA (bordas lisas).

const ARQUIVO := "user://qualidade3d_b18.cfg"
const NIVEIS := [
	# k = tamanho do quadro 3D em relação a 1280x720 (limitado pela tela)
	# PC / placa forte: HDR, brilho real, sombras, MSAA
	{"k": 1.5, "hdr": true, "msaa": Viewport.MSAA_4X, "fxaa": false, "sombra": true, "brilho": true, "chuva": 1.0},
	{"k": 1.5, "hdr": true, "msaa": Viewport.MSAA_2X, "fxaa": false, "sombra": true, "brilho": true, "chuva": 0.8},
	{"k": 1.25, "hdr": true, "msaa": Viewport.MSAA_2X, "fxaa": false, "sombra": true, "brilho": true, "chuva": 0.6},
	# TV BOX (perfil leve, começa aqui no Android): sem HDR, sem sombra em
	# tempo real, sem pós-brilho; a luz vem dos halos e fachos (baratos) e o
	# FXAA alisa as bordas. Começa na resolução da TV (1080p = nítido) e
	# nunca desce de 720p: se nem assim segurar, o show roda a 30 quadros
	# cravados (liso e nítido) em vez de borrado.
	{"k": 1.5, "hdr": false, "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "sombra": false, "brilho": false, "chuva": 0.6},
	{"k": 1.25, "hdr": false, "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "sombra": false, "brilho": false, "chuva": 0.5},
	{"k": 1.0, "hdr": false, "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "sombra": false, "brilho": false, "chuva": 0.35},
]
const NIVEL_LEVE := 3        # deste degrau para baixo: perfil TV box
const JANELA := 45           # quadros por medida durante o show
# mediana do quadro acima disso = lento (80% da taxa da tela; TV em 60 Hz
# -> 48 qps; em 50 Hz -> 40 qps; desconhecida -> 48)
static func limite() -> float:
	var hz := 60.0
	if OS.has_method("get_screen_refresh_rate"):
		var r: float = OS.call("get_screen_refresh_rate")
		if r > 20.0:
			hz = r
	return 1.0 / clamp(hz * 0.8, 24.0, 48.0)

var vp: Viewport
var mundo: Node
var nivel := 0
var travado := false          # true durante o show (só mede)
var _deltas := []
var _base := {}              # quantidade original de pingos de cada emissor
var _lento := 0              # medidas lentas durante o show


## Liga a qualidade num quadro 3D. `mundo` é o nó raiz da cena 3D.
static func aplicar(pai: Node, vp_: Viewport, mundo_: Node) -> Node:
	var q = load("res://scripts/qualidade3d.gd").new()
	q.name = "Qualidade3D"
	q.vp = vp_
	q.mundo = mundo_
	q.nivel = nivel_salvo()
	pai.add_child(q)
	q._ajustar()
	return q


## Perfil leve (TV box): o estádio já é montado mais leve (cidade menos
## densa, sem refletores de luz real; poças de luz e halos no lugar).
static func leve() -> bool:
	return nivel_salvo() >= NIVEL_LEVE


static func nivel_salvo() -> int:
	var c := ConfigFile.new()
	# BOTAO_TVBOX=1 (testes no PC): começa como na TV box
	var inicial := NIVEL_LEVE if (OS.has_feature("mobile") or OS.has_environment("BOTAO_TVBOX")) else 0
	if c.load(ARQUIVO) == OK:
		inicial = int(c.get_value("3d", "nivel", inicial))
	return int(clamp(inicial, 0, NIVEIS.size() - 1))


func _salvar(n: int, calibrado := false) -> void:
	var c := ConfigFile.new()
	c.set_value("3d", "nivel", int(clamp(n, 0, NIVEIS.size() - 1)))
	c.set_value("3d", "calibrado", calibrado)
	c.save(ARQUIVO)


## Já mediu esta TV box e o degrau salvo segurou o show: a próxima capa de
## carregamento não precisa medir de novo (abre bem mais rápido).
static func calibrado() -> bool:
	var c := ConfigFile.new()
	return c.load(ARQUIVO) == OK and bool(c.get_value("3d", "calibrado", false))


func no_fundo() -> bool:
	return nivel >= NIVEIS.size() - 1


## Calibragem (atrás da capa): desce um degrau. Devolve false no último.
func descer() -> bool:
	if no_fundo():
		return false
	nivel += 1
	_ajustar()
	_salvar(nivel)
	print("Qualidade3D: calibragem, nível %d" % nivel)
	return true


## Fim da calibragem: o degrau que segurou fica salvo.
func confirmar() -> void:
	_salvar(nivel, true)
	_deltas.clear()


func _process(delta: float) -> void:
	if not travado:
		return
	if VisualServer.get_render_info(VisualServer.INFO_SHADER_COMPILES_IN_FRAME) > 0:
		return                  # quadro de compilação não diz nada da TV box
	_deltas.append(delta)
	if _deltas.size() < JANELA:
		return
	var lista := _deltas.duplicate()
	lista.sort()
	var mediana: float = lista[lista.size() / 2]
	_deltas.clear()
	var alvo := limite()
	if Engine.target_fps > 0:
		alvo = max(alvo, 1.0 / Engine.target_fps)
	if mediana > alvo * 1.15:
		_lento += 1
		if _lento == 2 and not no_fundo():
			# não mexe agora (recompilaria shaders no meio do show)
			_salvar(nivel + 1)
			print("Qualidade3D: show lento (%.1f ms), próximo nível %d" % [mediana * 1000.0, nivel + 1])


func _ajustar() -> void:
	if vp == null or not is_instance_valid(vp):
		return
	var n: Dictionary = NIVEIS[nivel]
	var tela: Vector2 = OS.window_size
	var k_tela: float = clamp(min(tela.x / 1280.0, tela.y / 720.0), 1.0, 1.5)
	var k: float = min(n.k, k_tela)
	vp.size = (Vector2(1280, 720) * k).round()
	vp.hdr = n.hdr
	vp.msaa = n.msaa
	vp.fxaa = n.fxaa
	# ampliado para a tela com filtro: nada de pixel "quadrado"
	vp.get_texture().flags = Texture.FLAG_FILTER
	if mundo == null or not is_instance_valid(mundo):
		return
	_percorrer(mundo, n)


func _percorrer(no: Node, n: Dictionary) -> void:
	if no is DirectionalLight or no is SpotLight or no is OmniLight:
		if not no.has_meta("sombra_original"):
			no.set_meta("sombra_original", no.shadow_enabled)
		no.shadow_enabled = no.get_meta("sombra_original") and n.sombra
	elif no is WorldEnvironment and no.environment != null:
		var env: Environment = no.environment
		if not env.has_meta("brilho_original"):
			env.set_meta("brilho_original", env.glow_enabled)
		env.glow_enabled = env.get_meta("brilho_original") and n.brilho
	elif (no is Particles or no is CPUParticles) and no.has_meta("chuva"):
		if not _base.has(no):
			_base[no] = no.amount
		var qtd := int(max(40, _base[no] * n.chuva))
		if no.amount != qtd:
			no.amount = qtd
	for f in no.get_children():
		_percorrer(f, n)
