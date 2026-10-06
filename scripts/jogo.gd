extends Node

## O "cérebro" do Craque de Botão (autoload Jogo): times (dados/times.json + o
## time do pendrive), atributos, uniformes, a partida escolhida, a Copa (ida
## e volta), títulos por time, fontes, sons e troca de tela.

const CAMINHO_CONFIG := "user://botao_config.cfg"
const CAMINHO_TITULOS := "user://titulos.json"
const PASTA_EXTRA := "user://time_extra"

const AMARELO := Color(1.0, 0.84, 0.12)
const VERDE := Color(0.10, 0.75, 0.35)
const AZUL := Color(0.16, 0.45, 1.0)
const CIANO := Color(0.13, 0.88, 1.0)
const VERMELHO := Color(1.0, 0.18, 0.18)
const LARANJA := Color(1.0, 0.55, 0.10)
const FUNDO := Color(0.04, 0.06, 0.10)
const OURO := Color(0.95, 0.78, 0.3)

var TIMES := []            # todos os times (os do jogo + o do pendrive, se houver)

var config := {
	"minutos": 3,          # cada tempo
	"dificuldade": 1,      # 0 fácil, 1 médio, 2 difícil
	"toques": 3,           # toques seguidos na bola por vez
	"relogio_vez": 20,     # segundos para jogar em cada vez
	"volume_musica": 70,
	"volume_efeitos": 100,
	"clima": 0,            # 0 sorteado, 1 dia de sol, 2 dia de chuva, 3 noite, 4 noite com chuva
	"perspectiva": 1,      # 1 = mesa vista como na TV; 0 = de cima
}

## A partida a ser jogada.
##   modo: "amistoso" | "copa";  humano: [bool casa, bool fora]
##   controle: [jogador (1/2) que controla a casa, idem fora] (0 = CPU)
##   casa/fora: sigla;  penaltis: decide empate;  ida: {sigla: gols} (2º jogo)
var partida := {"modo": "amistoso", "casa": "BRA", "fora": "ARG", "humano": [true, false], "controle": [1, 0], "penaltis": false, "ida": {}}
var ultimo_resultado := {}

## Copa: 8 times, mata-mata em ida e volta.
##   rodada 0 quartas, 1 semi, 2 final, 3 acabou; perna 0 ida, 1 volta
##   jogos[r][k] = {a, b, ida: [ga, gb] | [], volta: [ga, gb] | [], pa, pb, v}
##   (ida no estádio de a; volta no estádio de b; placar sempre na ordem a, b)
var copa := {}
var titulos := {}          # sigla -> nº de Copas

var _fontes := {}
var _sons := {}
var _texturas := {}
var _canais := []
var _proximo_canal := 0
var _musica: AudioStreamPlayer
var _musica_nome := ""
var _ambiente: AudioStreamPlayer
var _som_clima: AudioStreamPlayer
var _tween: Tween
var _cortina: ColorRect
var _trocando := false
var _extra_logo: Texture


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	randomize()
	_carregar_times()
	_carregar_config()
	_carregar_titulos()
	for _i in range(14):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_canais.append(p)
	_musica = AudioStreamPlayer.new()
	add_child(_musica)
	_musica.connect("finished", self, "_musica_acabou")
	_ambiente = AudioStreamPlayer.new()
	add_child(_ambiente)
	_som_clima = AudioStreamPlayer.new()
	add_child(_som_clima)
	_tween = Tween.new()
	add_child(_tween)
	var camada := CanvasLayer.new()
	camada.layer = 120
	add_child(camada)
	_cortina = ColorRect.new()
	_cortina.color = FUNDO
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.anchor_right = 1
	_cortina.anchor_bottom = 1
	_cortina.modulate.a = 0
	camada.add_child(_cortina)
	var d := Directory.new()
	if d.open("res://sons") == OK:
		d.list_dir_begin(true, true)
		var f := d.get_next()
		while f != "":
			var nome := f.replace(".import", "")
			if nome.ends_with(".wav") and not _sons.has(nome.get_basename()):
				_sons[nome.get_basename()] = load("res://sons/" + nome)
			f = d.get_next()
	_carregar_grupos()
	_carregar_fundo()
	# Android: pedir a leitura do pendrive (logo do time extra) logo no início
	if OS.get_name() == "Android":
		OS.request_permissions()


# ================================================================ TIMES
func _carregar_times() -> void:
	TIMES.clear()
	var f := File.new()
	if f.open("res://dados/times.json", File.READ) == OK:
		var r := JSON.parse(f.get_as_text())
		f.close()
		if r.error == OK:
			for t in r.result.times:
				TIMES.append(_completar(t))
	_carregar_extra()


func _completar(t: Dictionary) -> Dictionary:
	t.forca = int(round((float(t.chute) + float(t.controle) + float(t.defesa)) / 3.0))
	if not t.has("listras"):
		t.listras = false
	return t


func selecao(sigla: String) -> Dictionary:
	for s in TIMES:
		if s.sigla == sigla:
			return s
	return TIMES[0]


# ------------------------------------------------------------- dicas
## Dicas de jogo para os carregamentos e as esperas (vez da CPU, intervalo):
## o jogador aprende as regras e os truques sem ler manual.
const DICAS := [
	"Segure o BOTÃO e solte na força certa: a barra sobe e desce.",
	"Manche CIMA/BAIXO troca o tazo; ESQUERDA/DIREITA ajusta a mira.",
	"Tocou na bola, joga de novo: até 3 toques por vez.",
	"Não tocou na bola? A vez passa para o adversário.",
	"Bateu no tazo rival sem tocar na bola: é falta.",
	"Falta forte dá cartão amarelo; o tazo fica marcado com o cartão.",
	"Segundo amarelo ou batida muito forte: vermelho, e o tazo sai.",
	"Falta dentro da própria área é PÊNALTI.",
	"Na falta, no escanteio e no lateral, só o cobrador destacado bate.",
	"Bola pela linha de fundo: escanteio se o defensor tocou por último.",
	"O goleiro se posiciona sozinho: mire nos cantos do gol.",
	"Na chuva a bola corre menos: capriche na força.",
	"Quem marca fica EMBALADO: chute mais forte e barra mais calma.",
	"Fique de olho no relógio da vez: ele fica vermelho no fim.",
	"Toque na beirada do tazo para um chute mais forte (na tela).",
	"Na Copa, jogo empatado na decisão vai para prorrogação e pênaltis.",
	"Times com mais DEFESA têm goleiro maior; mais CHUTE, bola mais forte.",
	"O time do pendrive entra na última vaga da escolha de times.",
]
var _dicas_fila := []


## Uma dica por vez, sem repetir até passar por todas.
func dica() -> String:
	if _dicas_fila.empty():
		_dicas_fila = DICAS.duplicate()
		_dicas_fila.shuffle()
	return _dicas_fila.pop_back()


func tem_extra() -> bool:
	for s in TIMES:
		if s.get("extra", false):
			return true
	return false


## Atributos que mudam o jogo (0..1 a partir de 70..95).
func nivel(v: float) -> float:
	return clamp((v - 70.0) / 25.0, 0.0, 1.0)


## Parâmetros de jogo de um time (embalo = acabou de fazer gol).
func parametros(sigla: String, embalo := false) -> Dictionary:
	var t := selecao(sigla)
	var ch := nivel(t.chute)
	var co := nivel(t.controle)
	var de := nivel(t.defesa)
	var p := {
		"vmax": 1150.0 * lerp(0.9, 1.06, ch),       # força máxima do peteleco
		"ciclo_barra": lerp(0.72, 1.12, co),        # segundos da barra subir (mais lenta = mais fácil)
		"massa": lerp(2.7, 3.3, (ch + de) * 0.5),   # botão mais pesado ganha as trombadas
		"goleiro_meio": lerp(20.0, 27.0, de),       # tamanho do goleiro caixinha
		"goleiro_vel": lerp(170.0, 270.0, de),      # rapidez do goleiro
		"erro_cpu": lerp(1.35, 0.7, co),            # mira da CPU
	}
	if embalo:
		p.vmax *= 1.08
		p.ciclo_barra *= 1.25
		p.erro_cpu *= 0.7
	return p


# ------------------------------------------------------------- texturas
func _tex(caminho: String) -> Texture:
	if not _texturas.has(caminho):
		_texturas[caminho] = load(caminho)
	return _texturas[caminho]


func emblema(sigla: String) -> Texture:
	if selecao(sigla).get("extra", false):
		return _extra_logo
	return _tex("res://imagens/emblema_%s.png" % sigla.to_lower())


## Bandeira (seleções) ou logo (clubes, time do pendrive): para painéis.
func bandeira(sigla: String) -> Texture:
	if selecao(sigla).get("extra", false):
		return _extra_logo
	return _tex("res://imagens/bandeira_%s.png" % sigla.to_lower())


## Botão pronto (times do jogo). O do pendrive é montado em camadas (peca.gd).
func textura_botao(sigla: String, uniforme: int) -> Texture:
	if selecao(sigla).get("extra", false):
		return null
	return _tex("res://imagens/botao_%s_%d.png" % [sigla.to_lower(), uniforme])


func textura_goleiro(sigla: String) -> Texture:
	if selecao(sigla).get("extra", false):
		return _tex("res://imagens/goleiro_base.png")
	return _tex("res://imagens/goleiro_%s.png" % sigla.to_lower())


## Onde é a partida: o estádio escolhido (amistoso) ou o do mandante.
func local_da_partida() -> String:
	var e: String = partida.get("estadio", "")
	if e == "" or not _existe_time(e):
		e = partida.get("casa", "BRA")
	return e


func _existe_time(sigla: String) -> bool:
	for s in TIMES:
		if s.sigla == sigla:
			return true
	return false


## Céus do 3D (dia, chuva, noite) feitos UMA vez e reaproveitados: montar
## o reflexo do céu é caro (na TV box travava a entrada da apresentação e
## do pódio); reaproveitado, custa zero.
var _ceus := {}


func ceu(nome: String) -> PanoramaSky:
	if not _ceus.has(nome):
		var ps := PanoramaSky.new()
		ps.radiance_size = Sky.RADIANCE_SIZE_32
		ps.panorama = load("res://imagens/ceu_%s.png" % nome)
		_ceus[nome] = ps
	return _ceus[nome]


## Calcula de antemão o reflexo dos céus que faltam (na tela de abertura,
## parada): a apresentação e o pódio entram sem esperar.
func preaquecer_ceus() -> void:
	for nome in ["dia", "chuva", "noite"]:
		if _ceus.has(nome) and _ceus[nome].has_meta("pronto"):
			continue
		var vp := Viewport.new()
		vp.size = Vector2(4, 4)
		vp.own_world = true
		vp.render_target_update_mode = Viewport.UPDATE_ONCE
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		env.background_sky = ceu(nome)
		we.environment = env
		vp.add_child(we)
		add_child(vp)
		ceu(nome).set_meta("pronto", true)
		get_tree().create_timer(1.0).connect("timeout", vp, "queue_free")


func estadio(sigla: String, pequeno: bool) -> Texture:
	var s := "extra" if selecao(sigla).get("extra", false) else sigla.to_lower()
	# sem o cache de _tex: cada estádio pesa vários MB e só um fica na tela
	return load("res://imagens/estadio_%s%s.jpg" % [s, "_720" if pequeno else ""]) as Texture


func uniforme(sigla: String, u: int) -> Array:
	return selecao(sigla)["u%d" % u]


func cor_camisa(sigla: String, u: int) -> Color:
	return Color(uniforme(sigla, u)[0])


## Cor de destaque do time (filetes, riscos ao lado dos textos): a cor
## principal da torcida; se for escura demais para ler no vidro escuro, a
## segunda cor do time.
func cor_time(sigla: String) -> Color:
	var cs: Array = selecao(sigla).get("torcida", ["#F2C74D", "#FFFFFF"])
	var c := Color(cs[0])
	if c.v < 0.28 and cs.size() > 1:
		c = Color(cs[1])
	return c


func cor_borda(sigla: String, u: int) -> Color:
	return Color(uniforme(sigla, u)[1])


## Distância entre cores do jeito que o olho vê (mais peso no verde).
static func diferenca(a: Color, b: Color) -> float:
	return sqrt(2.0 * pow(a.r - b.r, 2) + 4.0 * pow(a.g - b.g, 2) + 3.0 * pow(a.b - b.b, 2)) / 3.0


## Uniformes que não se confundem. Tenta o titular dos dois; se parecer, o
## de fora troca; se ainda parecer, a casa troca também. Nunca iguais.
func escolher_uniformes(casa: String, fora: String) -> Array:
	var melhor := [1, 2]
	var melhor_d := -1.0
	for par in [[1, 1], [1, 2], [2, 1], [2, 2]]:
		var ca := cor_camisa(casa, par[0])
		var cb := cor_camisa(fora, par[1])
		var d := min(diferenca(ca, cb), diferenca(ca, cor_borda(fora, par[1])) + 0.25)
		if d >= 0.33:
			return par
		if d > melhor_d:
			melhor_d = d
			melhor = par
	return melhor


# ----------------------------------------------------- time do pendrive
func _carregar_extra() -> void:
	var f := File.new()
	if not f.file_exists(PASTA_EXTRA + "/time.json"):
		return
	if f.open(PASTA_EXTRA + "/time.json", File.READ) != OK:
		return
	var r := JSON.parse(f.get_as_text())
	f.close()
	if r.error != OK or not (r.result is Dictionary):
		return
	var img := Image.new()
	if img.load(PASTA_EXTRA + "/logo.png") != OK:
		return
	var tex := ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
	_extra_logo = tex
	var t: Dictionary = r.result
	t.extra = true
	TIMES.append(_completar(t))


## Procura o logo no pendrive. Aceita, na raiz ou na pasta BOTAO: um .png ou
## .jpg (o nome do arquivo vira o nome do time, ex.: "Tigres FC.png"), ou
## logo.png/time.png/escudo.png com o nome em nome.txt.
func procurar_logo_pendrive() -> String:
	var raizes := []
	if OS.has_environment("BOTAO_PENDRIVE"):
		raizes.append(OS.get_environment("BOTAO_PENDRIVE"))
	for base in ["/storage", "/mnt/media_rw", "/mnt/usb_storage", "/mnt"]:
		var d := Directory.new()
		if d.open(base) != OK:
			continue
		d.list_dir_begin(true, true)
		var n := d.get_next()
		while n != "":
			if d.current_is_dir() and not (n in ["emulated", "self", "sdcard0", "media_rw", "runtime", "user", "secure", "asec", "obb", "shell", "appfuse", "vendor", "product"]):
				raizes.append(base + "/" + n)
			n = d.get_next()
		d.list_dir_end()
	raizes.append("/sdcard/Download")
	raizes.append(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS))
	for r in raizes:
		for pasta in [r + "/BOTAO", r + "/botao", r]:
			var achado := _logo_na_pasta(pasta)
			if achado != "":
				return achado
	return ""


func _logo_na_pasta(pasta: String) -> String:
	var d := Directory.new()
	if d.open(pasta) != OK:
		return ""
	d.list_dir_begin(true, true)
	var n := d.get_next()
	var achado := ""
	while n != "":
		var l := n.to_lower()
		if not d.current_is_dir() and (l.ends_with(".png") or l.ends_with(".jpg") or l.ends_with(".jpeg")):
			if l.begins_with("logo.") or l.begins_with("time.") or l.begins_with("escudo."):
				achado = pasta + "/" + n
				break
			if achado == "" and pasta.to_lower().ends_with("botao"):
				achado = pasta + "/" + n
		n = d.get_next()
	d.list_dir_end()
	return achado


## Lê o logo, tira as cores e monta o time (sem salvar ainda).
func preparar_extra(caminho: String) -> Dictionary:
	var img := Image.new()
	if img.load(caminho) != OK:
		return {}
	var nome := caminho.get_file().get_basename().to_upper()
	if nome in ["LOGO", "TIME", "ESCUDO"]:
		nome = "MEU TIME"
		var f := File.new()
		var arq_nome := caminho.get_base_dir() + "/nome.txt"
		if f.open(arq_nome, File.READ) == OK:
			var txt := f.get_line().strip_edges().to_upper()
			f.close()
			if txt != "":
				nome = txt
	nome = nome.replace("_", " ").left(16)
	# logo até 256 px (leve para o botão, o bandeirão e os painéis)
	if img.get_width() > 256 or img.get_height() > 256:
		var k := 256.0 / max(img.get_width(), img.get_height())
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var cores := cores_do_logo(img)
	var c1: Color = cores[0]
	var c2: Color = cores[1]
	var claro1 := c1.get_luminance() > 0.6
	# titular: a cor principal do logo; reserva: bem diferente (branco ou a 2ª cor)
	var u1 := [c1, c2, Color.white if not claro1 else Color(0.1, 0.1, 0.1)]
	var reserva := Color.white if not claro1 else (c2 if c2.get_luminance() < 0.6 else Color(0.12, 0.12, 0.2))
	if diferenca(reserva, c1) < 0.35:
		reserva = Color(0.12, 0.12, 0.2) if claro1 else Color.white
	var u2 := [reserva, c1, c1 if reserva.get_luminance() > 0.6 else Color.white]
	var sigla := ""
	for ch in nome:
		if ch >= "A" and ch <= "Z":
			sigla += ch
		if sigla.length() == 3:
			break
	while sigla.length() < 3:
		sigla += "X"
	if selecao(sigla).sigla == sigla and not selecao(sigla).get("extra", false):
		sigla = sigla.left(2) + "Z"
	return {"sigla": sigla, "nome": nome, "chute": 86, "controle": 86, "defesa": 86,
		"u1": [u1[0].to_html(false), u1[1].to_html(false), u1[2].to_html(false)],
		"u2": [u2[0].to_html(false), u2[1].to_html(false), u2[2].to_html(false)],
		"goleiro": "#1B1B1B", "torcida": [c1.to_html(false), c2.to_html(false)],
		"estadio": "ARENA " + nome, "grama": "listras", "emblema": "logo", "_imagem": img}


## Cores principais do logo: as mais frequentes, sem repetir tons parecidos.
static func cores_do_logo(img: Image) -> Array:
	var p := img.duplicate()
	p.resize(40, 40, Image.INTERPOLATE_BILINEAR)
	p.lock()
	var conta := {}
	for y in range(40):
		for x in range(40):
			var c = p.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var chave := "%d_%d_%d" % [int(c.r * 7.99), int(c.g * 7.99), int(c.b * 7.99)]
			if not conta.has(chave):
				conta[chave] = [0, Color(0, 0, 0)]
			conta[chave][0] += 1
			conta[chave][1] += c
	p.unlock()
	var lista := []
	for k in conta:
		var n: int = conta[k][0]
		var soma: Color = conta[k][1]
		var media := Color(soma.r / n, soma.g / n, soma.b / n)
		# cores vivas valem mais que branco/preto de fundo
		var peso := float(n) * (1.0 + 1.5 * media.s)
		lista.append([peso, media])
	lista.sort_custom(OrdemCores.new(), "maior")
	var escolhidas := []
	for item in lista:
		var c: Color = item[1]
		var repetida := false
		for e in escolhidas:
			if diferenca(c, e) < 0.25:
				repetida = true
		if not repetida:
			escolhidas.append(c)
		if escolhidas.size() == 2:
			break
	while escolhidas.size() < 2:
		escolhidas.append(Color.white if escolhidas.empty() or escolhidas[0].get_luminance() < 0.5 else Color(0.1, 0.1, 0.1))
	return escolhidas


class OrdemCores:
	extends Reference
	func maior(a, b) -> bool:
		return a[0] > b[0]
	func maior_titulo(a, b) -> bool:
		return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0])


## Guarda o time do pendrive no aparelho (continua sem o pendrive).
func salvar_extra(t: Dictionary) -> bool:
	var d := Directory.new()
	d.make_dir_recursive(PASTA_EXTRA)
	var img: Image = t._imagem
	if img.save_png(PASTA_EXTRA + "/logo.png") != OK:
		return false
	var dados := t.duplicate()
	dados.erase("_imagem")
	var f := File.new()
	if f.open(PASTA_EXTRA + "/time.json", File.WRITE) != OK:
		return false
	f.store_string(JSON.print(dados))
	f.close()
	_carregar_times()
	return true


func remover_extra() -> void:
	var d := Directory.new()
	for arq in ["time.json", "logo.png"]:
		if d.file_exists(PASTA_EXTRA + "/" + arq):
			d.remove(PASTA_EXTRA + "/" + arq)
	_extra_logo = null
	_carregar_times()


# ------------------------------------------------------------------ copa
## Copa com até 8 JOGADORES: cada um escolhe um time (humanos = [J1, J2...]),
## o resto é da CPU. Jogo de dois jogadores: um em cada placa. Jogo de um
## jogador contra a CPU: qualquer placa. Jogo só de CPU: decidido na hora.
func nova_copa(humanos) -> void:
	if humanos is String:
		humanos = [humanos]
	var outros := []
	for s in TIMES:
		if not s.sigla in humanos:
			outros.append(s.sigla)
	outros.shuffle()
	var times: Array = humanos.duplicate()
	var i := 0
	while times.size() < 8 and i < outros.size():
		times.append(outros[i])
		i += 1
	times.shuffle()
	copa = {"times": times, "humanos": humanos.duplicate(), "jogador": humanos[0], "rodada": 0, "perna": 0,
		"jogos": [], "eliminado": false, "campeao": "", "podio": []}
	_montar_rodada(times)


func _montar_rodada(vivos: Array, perdedores := []) -> void:
	var jogos := []
	for i in range(0, vivos.size(), 2):
		jogos.append({"a": vivos[i], "b": vivos[i + 1], "ida": [], "volta": [], "pa": -1, "pb": -1, "v": "", "unico": false})
	# depois das semifinais: a decisão do 3º lugar (jogo único) entre quem perdeu
	if perdedores.size() == 2:
		jogos.append({"a": perdedores[0], "b": perdedores[1], "ida": [], "volta": [], "pa": -1, "pb": -1, "v": "", "unico": true})
	copa.jogos.append(jogos)


func copa_vivos() -> Array:
	var r := []
	for j in copa.jogos[copa.jogos.size() - 1]:
		if not j.get("unico", false):
			r.append(j.v)
	return r


func copa_perdedores() -> Array:
	var r := []
	for j in copa.jogos[copa.jogos.size() - 1]:
		if not j.get("unico", false):
			r.append(j.b if j.v == j.a else j.a)
	return r


## Nº do jogador (1..8) dono do time, ou 0 (CPU).
func jogador_de(sigla: String) -> int:
	if copa.empty():
		return 0
	return copa.humanos.find(sigla) + 1


func _tem_humano(j: Dictionary) -> bool:
	return jogador_de(j.a) > 0 or jogador_de(j.b) > 0


func _perna_jogada(j: Dictionary) -> bool:
	if j.get("unico", false):
		return j.v != ""
	return not j.ida.empty() if int(copa.perna) == 0 else not j.volta.empty()


## Ordem dos jogos da rodada: na final, a decisão do 3º lugar vem antes.
func _ordem(rodada: Array) -> Array:
	var r := []
	for j in rodada:
		if j.get("unico", false):
			r.append(j)
	for j in rodada:
		if not j.get("unico", false):
			r.append(j)
	return r


## O próximo jogo com jogador nesta perna da rodada ({} = nenhum).
func copa_jogo_atual() -> Dictionary:
	if copa.empty() or copa.rodada > 2 or copa.campeao != "":
		return {}
	for j in _ordem(copa.jogos[copa.rodada]):
		if _tem_humano(j) and not _perna_jogada(j):
			return j
	return {}


func copa_jogo_do_jogador() -> Dictionary:
	return copa_jogo_atual()


## "quartas", "semi", "final" ou "terceiro" do jogo atual.
func copa_fase() -> String:
	var j := copa_jogo_atual()
	if j.get("unico", false):
		return "terceiro"
	return ["quartas", "semi", "final"][clamp(int(copa.get("rodada", 0)), 0, 2)]


## Monta a próxima partida da Copa (ida: casa = a; volta: casa = b;
## 3º lugar: jogo único, casa = a, com prorrogação e pênaltis).
func copa_preparar_partida() -> void:
	var j := copa_jogo_atual()
	var unico: bool = j.get("unico", false)
	var ida := int(copa.perna) == 0 or unico
	var casa: String = j.a if ida else j.b
	var fora: String = j.b if ida else j.a
	var placar_ida := {}
	if not ida:
		placar_ida = {j.a: j.ida[0], j.b: j.ida[1]}
	var humano := [jogador_de(casa) > 0, jogador_de(fora) > 0]
	var controle := [1, 2] if humano[0] and humano[1] else [3 if humano[0] else 0, 3 if humano[1] else 0]
	partida = {"modo": "copa", "casa": casa, "fora": fora, "humano": humano, "controle": controle,
		"penaltis": unico or not ida, "ida": placar_ida, "clima": escolher_clima(), "fase": copa_fase(), "estadio": casa}


## Registra a perna jogada (gols e pênaltis na ordem casa/fora da partida).
func copa_registrar(g_casa: int, g_fora: int, p_casa: int, p_fora: int) -> void:
	var j := copa_jogo_atual()
	if j.empty():
		return
	# o resultado só vale para a partida que foi preparada (nunca duas vezes)
	var unico: bool = j.get("unico", false)
	var ida := int(copa.perna) == 0 or unico
	if partida.get("modo", "") != "copa" or partida.casa != (j.a if ida else j.b) or partida.fora != (j.b if ida else j.a) \
			or partida.get("registrada", false):
		return
	partida["registrada"] = true
	if unico:
		j.ida = [g_casa, g_fora]
		if p_casa >= 0:
			j.pa = p_casa
			j.pb = p_fora
		j.v = _vencedor(j)
	elif ida:
		j.ida = [g_casa, g_fora]                  # casa = a
	else:
		j.volta = [g_fora, g_casa]                # casa da volta = b
		if p_casa >= 0:
			j.pa = p_fora
			j.pb = p_casa
		j.v = _vencedor(j)
	_avancar()


## Acabaram os jogos com jogador desta perna: a CPU decide os outros e a
## Copa anda (ida -> volta -> próxima rodada). Sem jogador vivo: termina.
func _avancar() -> void:
	while copa.campeao == "" and copa_jogo_atual().empty():
		var rodada: Array = copa.jogos[copa.rodada]
		if int(copa.perna) == 0:
			for o in rodada:
				if o.get("unico", false):
					if o.v == "":
						_simular_unico(o)
				elif o.ida.empty():
					o.ida = [_gols(selecao(o.a).forca + 3, selecao(o.b).forca), _gols(selecao(o.b).forca, selecao(o.a).forca + 3)]
			copa.perna = 1
			continue
		for o in rodada:
			if o.v == "":
				_simular_volta(o)
		copa.perna = 0
		copa.rodada += 1
		if copa.rodada <= 2:
			_montar_rodada(copa_vivos(), copa_perdedores() if copa.rodada == 2 else [])
			var algum := false
			for o in copa.jogos[copa.rodada]:
				if _tem_humano(o):
					algum = true
			if not algum:
				copa.eliminado = true
				copa_simular_resto()
		else:
			_fechar_copa()


func _fechar_copa() -> void:
	var final_: Dictionary = {}
	var terceiro: Dictionary = {}
	for o in copa.jogos[2]:
		if o.get("unico", false):
			terceiro = o
		else:
			final_ = o
	copa.campeao = final_.v
	copa.podio = [final_.v, final_.b if final_.v == final_.a else final_.a, terceiro.get("v", "")]
	registrar_titulo(copa.campeao)


func agregado(j: Dictionary) -> Array:
	var a := 0
	var b := 0
	if not j.ida.empty():
		a += j.ida[0]
		b += j.ida[1]
	if not j.volta.empty():
		a += j.volta[0]
		b += j.volta[1]
	return [a, b]


func _vencedor(j: Dictionary) -> String:
	var ag := agregado(j)
	if ag[0] != ag[1]:
		return j.a if ag[0] > ag[1] else j.b
	return j.a if j.pa > j.pb else j.b


func _simular_volta(o: Dictionary) -> void:
	if o.ida.empty():
		o.ida = [_gols(selecao(o.a).forca + 3, selecao(o.b).forca), _gols(selecao(o.b).forca, selecao(o.a).forca + 3)]
	var fa: float = selecao(o.a).forca
	var fb: float = selecao(o.b).forca + 3
	o.volta = [_gols(fa, fb), _gols(fb, fa)]
	var ag := agregado(o)
	if ag[0] == ag[1]:
		o.pa = 3 + randi() % 3
		o.pb = o.pa
		while o.pb == o.pa:
			o.pb = 2 + randi() % 4
	o.v = _vencedor(o)


## Nenhum jogador vivo: o resto da Copa é decidido na hora.
func copa_simular_resto() -> void:
	while copa.rodada <= 2:
		for o in copa.jogos[copa.rodada]:
			if o.v == "":
				if o.get("unico", false):
					_simular_unico(o)
				else:
					_simular_volta(o)
		copa.rodada += 1
		if copa.rodada <= 2:
			_montar_rodada(copa_vivos(), copa_perdedores() if copa.rodada == 2 else [])
	copa.perna = 0
	if copa.campeao == "":
		_fechar_copa()


func _simular_unico(o: Dictionary) -> void:
	var fa: float = selecao(o.a).forca
	var fb: float = selecao(o.b).forca
	o.ida = [_gols(fa, fb), _gols(fb, fa)]
	if o.ida[0] == o.ida[1]:
		o.pa = 3 + randi() % 3
		o.pb = o.pa
		while o.pb == o.pa:
			o.pb = 2 + randi() % 4
	o.v = _vencedor(o)


func _gols(f: float, contra: float) -> int:
	var media := 1.3 + (f - contra) * 0.06
	var g := 0
	for _i in range(6):
		if randf() < clamp(media / 6.0, 0.03, 0.6):
			g += 1
	return g


## Clima da próxima partida: o das OPÇÕES, ou sorteado.
func escolher_clima() -> String:
	var c: String = ["", "sol", "chuva", "noite", "noite_chuva"][clamp(int(config.get("clima", 0)), 0, 4)]
	return c if c != "" else ["sol", "sol", "chuva", "noite", "noite", "noite_chuva"][randi() % 6]


# --------------------------------------------------------------- títulos
func _carregar_titulos() -> void:
	var f := File.new()
	if f.open(CAMINHO_TITULOS, File.READ) != OK:
		return
	var r := JSON.parse(f.get_as_text())
	f.close()
	if r.error == OK and r.result is Dictionary:
		titulos = r.result


func registrar_titulo(sigla: String) -> void:
	titulos[sigla] = int(titulos.get(sigla, 0)) + 1
	var f := File.new()
	if f.open(CAMINHO_TITULOS, File.WRITE) == OK:
		f.store_string(JSON.print(titulos))
		f.close()


## [[sigla, títulos]] do mais campeão para o menos (só quem tem título).
func ranking_titulos() -> Array:
	var r := []
	for s in titulos:
		if int(titulos[s]) > 0 and selecao(s).sigla == s:
			r.append([s, int(titulos[s])])
	r.sort_custom(OrdemCores.new(), "maior_titulo")
	return r


func zerar_titulos() -> void:
	titulos = {}
	var d := Directory.new()
	if d.file_exists(CAMINHO_TITULOS):
		d.remove(CAMINHO_TITULOS)


# --------------------------------------------------------------- config
func _carregar_config() -> void:
	var c := ConfigFile.new()
	if c.load(CAMINHO_CONFIG) != OK:
		return
	for k in config.keys():
		config[k] = c.get_value("jogo", k, config[k])


func salvar_config() -> void:
	var c := ConfigFile.new()
	for k in config.keys():
		c.set_value("jogo", k, config[k])
	c.save(CAMINHO_CONFIG)
	aplicar_volumes()


# --------------------------------------------------------------- fontes
## Fonte em cache. nome: "titan" (títulos), "bungee" (placares), "texto".
func fonte(nome: String, tamanho: int, contorno: int = 0, cor_contorno: Color = Color(0, 0, 0, 0.85)) -> DynamicFont:
	var chave := "%s_%d_%d_%s" % [nome, tamanho, contorno, cor_contorno.to_html()]
	if _fontes.has(chave):
		return _fontes[chave]
	var f := DynamicFont.new()
	var arquivos := {"titan": "res://fontes/titan.ttf", "bungee": "res://fontes/bungee.ttf", "texto": "res://fontes/opensans.ttf"}
	f.font_data = load(arquivos.get(nome, arquivos.texto))
	if nome != "texto":
		f.add_fallback(load(arquivos.texto))
	f.size = tamanho
	f.use_filter = true
	if contorno > 0:
		f.outline_size = contorno
		f.outline_color = cor_contorno
	_fontes[chave] = f
	return f


## Desenha as letras antes da hora (a 1ª vez de cada letra grande custa um
## tempinho no Android: era uma das "travadinhas" no gol).
func preaquecer(f: Font, texto := "ABCDEFGHIJKLMNOPQRSTUVWXYZÁÂÃÉÊÍÓÔÕÚÇ0123456789!:.-&º ") -> void:
	f.get_string_size(texto)


# ----------------------------------------------------------------- sons
# --------------------------------------------- sons da torcida (do usuário)
## Os sons gravados ficam em sons/torcida, com o MOMENTO no começo do nome:
##   gol_*.ogg|wav|mp3          gol (qualquer time)
##   grito_*                    gritos da torcida (chance perdida, trave...)
##   comemoracao_*              festa (fim de jogo, campeão, gol do mandante)
##   vaia_*                     vaia (o mandante tomou gol ou perdeu; falta)
##   abertura_*                 som da apresentação 3D do estádio
## Vários do mesmo momento: o jogo sorteia. Sem nenhum: usa o som sintetizado.
var _grupos := {}          # "gol" -> [AudioStream]
var _canais_torcida := []


func _carregar_grupos() -> void:
	for _i in range(3):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_canais_torcida.append(p)
	var d := Directory.new()
	if d.open("res://sons/torcida") != OK:
		return
	d.list_dir_begin(true, true)
	var f := d.get_next()
	var vistos := {}
	while f != "":
		var nome := f.replace(".import", "")
		var ext := nome.get_extension().to_lower()
		if ext in ["ogg", "wav", "mp3"] and not vistos.has(nome):
			vistos[nome] = true
			var st = load("res://sons/torcida/" + nome)
			if st is AudioStream:
				if st is AudioStreamOGGVorbis:
					st.loop = false
				var grupo := nome.get_basename().to_lower()
				var corte := grupo.find("_")
				if corte > 0:
					grupo = grupo.substr(0, corte)
				grupo = grupo.rstrip("0123456789 -")
				if not _grupos.has(grupo):
					_grupos[grupo] = []
				_grupos[grupo].append(st)
		f = d.get_next()
	d.list_dir_end()


func tem_grupo(grupo: String) -> bool:
	return _grupos.has(grupo) and not _grupos[grupo].empty()


## Toca um som gravado do momento (sorteado) ou, sem nenhum, o sintetizado.
func tocar_grupo(grupo: String, reserva := "", volume_db := 0.0) -> void:
	if not tem_grupo(grupo):
		if reserva != "":
			tocar(reserva, volume_db)
		return
	var lista: Array = _grupos[grupo]
	var p: AudioStreamPlayer = _canais_torcida[0]
	for c in _canais_torcida:
		if not c.playing:
			p = c
			break
	p.stream = lista[randi() % lista.size()]
	p.volume_db = volume_db + _db(config.volume_efeitos)
	p.play()


## Abaixa e para os sons gravados da torcida (ao sair de uma cena).
func parar_grupos(tempo: float = 0.5) -> void:
	for c in _canais_torcida:
		if c.playing:
			_tween.interpolate_property(c, "volume_db", c.volume_db, -50.0, tempo)
			_tween.interpolate_callback(c, tempo, "stop")
	_tween.start()


func tocar(nome: String, volume_db: float = 0.0, tom: float = 1.0) -> void:
	if not _sons.has(nome):
		return
	var p: AudioStreamPlayer = _canais[_proximo_canal]
	_proximo_canal = (_proximo_canal + 1) % _canais.size()
	p.stream = _sons[nome]
	p.volume_db = volume_db + _db(config.volume_efeitos)
	p.pitch_scale = tom
	p.play()


func musica(nome: String, volume_db: float = 0.0, repetir := true) -> void:
	if nome == _musica_nome and _musica.playing:
		return
	_musica_nome = nome
	var st: AudioStream = load("res://musicas/%s.ogg" % nome)
	if st is AudioStreamOGGVorbis:
		st.loop = repetir
	_musica.stream = st
	_musica.volume_db = -40.0
	_musica.play()
	_tween.interpolate_property(_musica, "volume_db", -40.0, volume_db + _db(config.volume_musica), 0.8, Tween.TRANS_SINE, Tween.EASE_OUT)
	_tween.start()


## MÚSICAS DE FUNDO (musicas/fundo: todas as que estiverem lá entram no
## sorteio). nova = true sorteia outra (nunca a mesma da vez anterior): cada
## partida/apresentação tem a sua; nos menus a música continua tocando. Quando
## uma acaba, entra outra sorteada.
var _fundo := []
var _fundo_ultima := ""
var _fundo_vol := 0.0


func _carregar_fundo() -> void:
	var d := Directory.new()
	if d.open("res://musicas/fundo") != OK:
		return
	d.list_dir_begin(true, true)
	var f := d.get_next()
	while f != "":
		var nome := f.replace(".import", "")
		if nome.get_extension().to_lower() == "ogg" and not (nome.get_basename() in _fundo):
			_fundo.append(nome.get_basename())
		f = d.get_next()
	d.list_dir_end()
	_fundo.sort()


func musica_fundo(volume_db: float = 0.0, nova := false) -> void:
	if _fundo.empty():
		return
	if not nova and _musica_nome.begins_with("fundo/") and _musica.playing:
		if abs(volume_db - _fundo_vol) > 0.5:
			_fundo_vol = volume_db
			_tween.interpolate_property(_musica, "volume_db", _musica.volume_db, volume_db + _db(config.volume_musica), 0.8)
			_tween.start()
		return
	var opcoes := []
	for n in _fundo:
		if n != _fundo_ultima or _fundo.size() == 1:
			opcoes.append(n)
	var escolha: String = opcoes[randi() % opcoes.size()]
	_fundo_ultima = escolha
	_fundo_vol = volume_db
	_musica_nome = ""
	musica("fundo/" + escolha, volume_db, false)


func _musica_acabou() -> void:
	if _musica_nome.begins_with("fundo/"):
		musica_fundo(_fundo_vol, true)


func parar_musica(tempo: float = 0.6) -> void:
	_musica_nome = ""
	_tween.interpolate_property(_musica, "volume_db", _musica.volume_db, -50.0, tempo)
	_tween.interpolate_callback(_musica, tempo, "stop")
	_tween.start()


## Torcida de fundo (murmúrio em loop). forca 0 = desliga.
func ambiente(forca: float) -> void:
	if forca <= 0.0:
		_tween.interpolate_property(_ambiente, "volume_db", _ambiente.volume_db, -60.0, 0.8)
		_tween.interpolate_callback(_ambiente, 0.8, "stop")
		_tween.start()
		return
	if not _ambiente.playing:
		var st: AudioStream = load("res://sons/torcida.ogg")
		if st is AudioStreamOGGVorbis:
			st.loop = true
		_ambiente.stream = st
		_ambiente.volume_db = -40.0
		_ambiente.play()
	_tween.interpolate_property(_ambiente, "volume_db", _ambiente.volume_db, linear2db(forca) + _db(config.volume_efeitos) - 4.0, 0.6)
	_tween.start()


## Som de fundo do clima (chuva em loop). "" = desliga.
func som_clima(nome: String) -> void:
	if nome == "":
		_som_clima.stop()
		return
	var st: AudioStream = load("res://sons/%s.ogg" % nome)
	if st is AudioStreamOGGVorbis:
		st.loop = true
	_som_clima.stream = st
	_som_clima.volume_db = -6.0 + _db(config.volume_efeitos)
	_som_clima.play()


func aplicar_volumes() -> void:
	if _musica.playing:
		_musica.volume_db = _db(config.volume_musica)


func _db(porcento) -> float:
	var p := clamp(float(porcento) / 100.0, 0.0, 1.0)
	return -80.0 if p <= 0.001 else linear2db(p)


# ---------------------------------------------------------- troca de tela
func ir_para(cena: String) -> void:
	if _trocando:
		return
	_trocando = true
	_tween.interpolate_property(_cortina, "modulate:a", _cortina.modulate.a, 1.0, 0.28, Tween.TRANS_SINE, Tween.EASE_IN)
	_tween.start()
	yield(_tween, "tween_all_completed")
	get_tree().paused = false
	Engine.time_scale = 1.0
	# a tela só troca se carregar inteira (script sem erro): uma tela que
	# não abre (arquivo faltando no APK) nunca prende no lobby. A
	# apresentação cai direto na partida, o pódio na chave; o resto
	# recarrega a tela atual (o botão volta a funcionar).
	var reserva := {"res://cenas/preparacao.tscn": "res://cenas/partida.tscn",
		"res://cenas/podio.tscn": "res://cenas/chave.tscn"}
	var ps := _cena_boa(cena)
	if ps == null and reserva.has(cena):
		push_error("Falha ao abrir %s; indo para %s" % [cena, reserva[cena]])
		ps = _cena_boa(reserva[cena])
	if ps != null:
		get_tree().change_scene_to(ps)
	else:
		push_error("Falha ao abrir %s" % cena)
		get_tree().reload_current_scene()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	_tween.interpolate_property(_cortina, "modulate:a", 1.0, 0.0, 0.45, Tween.TRANS_SINE, Tween.EASE_OUT)
	_tween.start()
	_trocando = false


## A cena carregada e com o script inteiro (null se faltar algo).
func _cena_boa(cena: String) -> PackedScene:
	var ps = load(cena) if ResourceLoader.exists(cena) else null
	if not ps is PackedScene or not ps.can_instance():
		return null
	var n: Node = ps.instance()
	if n == null:
		return null
	var sc = n.get_script()
	var ok: bool = sc == null or sc.can_instance()
	n.free()
	return ps if ok else null


func trocando() -> bool:
	return _trocando
