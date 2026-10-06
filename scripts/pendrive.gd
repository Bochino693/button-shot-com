extends Control

## TIME DO PENDRIVE (escondido: só o operador abre, pelas OPÇÕES — 5 toques
## no título "OPÇÕES" ou ESQUERDA 5 vezes no manche). Lê o logo do pendrive
## (pasta BOTAO), mostra as cores e os uniformes gerados e grava o time.

signal fechou

const UI = preload("res://scripts/ui.gd")
const Selecao = preload("res://scripts/selecao.gd")

var _janela: Control
var _novo := {}


func _ready() -> void:
	anchor_right = 1
	anchor_bottom = 1
	mouse_filter = MOUSE_FILTER_STOP
	_abrir_pendrive()


func _fechar() -> void:
	emit_signal("fechou")
	queue_free()


func _abrir_pendrive() -> void:
	Jogo.tocar("clique")
	_janela = Control.new()
	_janela.anchor_right = 1
	_janela.anchor_bottom = 1
	_janela.mouse_filter = MOUSE_FILTER_STOP
	add_child(_janela)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.7)
	fundo.anchor_right = 1
	fundo.anchor_bottom = 1
	fundo.mouse_filter = MOUSE_FILTER_IGNORE
	_janela.add_child(fundo)
	var p := UI.painel(Jogo.CIANO, Color(0.02, 0.05, 0.12, 0.97), 22, 3, 18)
	UI.colocar(p, 170, 90, 940, 560)
	_janela.add_child(p)
	UI.pop(p, 0.0, 0.35, 0.8)
	var t := UI.label("TIME DO PENDRIVE", Jogo.fonte("titan", 38, 4), Color.white)
	UI.colocar(t, 0, 14, 940, 56)
	p.add_child(t)
	var caminho := Jogo.procurar_logo_pendrive()
	_novo = {}
	if caminho != "":
		_novo = Jogo.preparar_extra(caminho)
	if _novo.empty():
		var msg := "Nenhum logo encontrado.\n\nNo pendrive, crie a pasta BOTAO e coloque o logo do time\n(PNG ou JPG, de preferência com fundo transparente).\nO nome do arquivo vira o nome do time. Ex.: \"TIGRES FC.png\"\n\nDepois ligue o pendrive no aparelho e toque em PROCURAR."
		if caminho != "":
			msg = "Não consegui abrir a imagem:\n%s\n\nUse PNG ou JPG." % caminho.get_file()
		var l := UI.label(msg, Jogo.fonte("texto", 22, 1), Color(1, 1, 1, 0.9))
		UI.colocar(l, 40, 80, 860, 330)
		p.add_child(l)
		l.autowrap = true          # depois de ter largura (senão quebra letra por letra)
		var b1 := _botao_janela(p, "PROCURAR", Jogo.VERDE, Vector2(110, 450), "_procurar_de_novo")
		b1.call_deferred("grab_focus")
		if Jogo.tem_extra():
			_botao_janela(p, "APAGAR TIME", Color(0.55, 0.12, 0.12), Vector2(370, 450), "_remover_extra")
		_botao_janela(p, "FECHAR", Color(0.3, 0.1, 0.1), Vector2(630, 450), "_fechar_pendrive")
		return
	# prévia: logo, nome, cores e os dois uniformes
	var img: Image = _novo._imagem
	var tex := ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
	var lg := TextureRect.new()
	lg.texture = tex
	lg.expand = true
	lg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	UI.colocar(lg, 60, 90, 280, 280)
	lg.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(lg)
	var n := UI.label(_novo.nome, Jogo.fonte("titan", 40, 4), Jogo.AMARELO, Label.ALIGN_LEFT)
	UI.colocar(n, 380, 90, 540, 60)
	p.add_child(n)
	var info := UI.label("%s  •  %s" % [_novo.sigla, _novo.estadio], Jogo.fonte("bungee", 18, 2), Color.white, Label.ALIGN_LEFT)
	UI.colocar(info, 380, 150, 540, 30)
	p.add_child(info)
	var lc := UI.label("CORES DO LOGO", Jogo.fonte("texto", 16, 0), Color(1, 1, 1, 0.7), Label.ALIGN_LEFT)
	UI.colocar(lc, 380, 196, 300, 24)
	p.add_child(lc)
	for i in range(2):
		var sw := Panel.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(_novo.torcida[i])
		st.set_corner_radius_all(8)
		st.border_color = Color(1, 1, 1, 0.7)
		st.set_border_width_all(2)
		sw.add_stylebox_override("panel", st)
		sw.mouse_filter = MOUSE_FILTER_IGNORE
		UI.colocar(sw, 380 + i * 70, 224, 58, 40)
		p.add_child(sw)
	for u in [1, 2]:
		var k: Array = _novo["u%d" % u]
		var m := Selecao.botao_de_cores(Color(k[0]), Color(k[1]), tex, 88.0)
		m.rect_position = Vector2(380 + (u - 1) * 150, 290)
		p.add_child(m)
		var lu := UI.label("TITULAR" if u == 1 else "RESERVA", Jogo.fonte("texto", 16, 0), Color(1, 1, 1, 0.75))
		UI.colocar(lu, 380 + (u - 1) * 150 - 20, 382, 128, 24)
		p.add_child(lu)
	var obs := UI.label("As cores dos uniformes saem do logo. Se o adversário usar cores parecidas, o jogo troca para o reserva.", Jogo.fonte("texto", 16, 0), Color(1, 1, 1, 0.6))
	UI.colocar(obs, 40, 408, 860, 40)
	p.add_child(obs)
	obs.autowrap = true
	var s := _botao_janela(p, "SALVAR TIME", Jogo.VERDE, Vector2(110, 460), "_salvar_extra")
	s.call_deferred("grab_focus")
	if Jogo.tem_extra():
		_botao_janela(p, "APAGAR TIME", Color(0.55, 0.12, 0.12), Vector2(370, 460), "_remover_extra")
	_botao_janela(p, "CANCELAR", Color(0.3, 0.1, 0.1), Vector2(630, 460), "_fechar_pendrive")


func _botao_janela(p: Control, txt: String, cor: Color, pos: Vector2, metodo: String) -> Button:
	var b := UI.botao(txt, cor, Jogo.fonte("titan", 24, 2))
	UI.colocar(b, pos.x, pos.y, 220, 70)
	b.connect("pressed", self, metodo)
	p.add_child(b)
	return b


func _procurar_de_novo() -> void:
	_janela.queue_free()
	_abrir_pendrive()


func _fechar_pendrive() -> void:
	Jogo.tocar("volta")
	_fechar()


func _salvar_extra() -> void:
	if _novo.empty():
		return
	if Jogo.salvar_extra(_novo):
		Jogo.tocar("confirma")
		Jogo.tocar("torcida_gol", -8.0)
	_fechar()


func _remover_extra() -> void:
	Jogo.remover_extra()
	Jogo.tocar("volta")
	_fechar()
