extends Reference

## FÍSICA DA MESA DE BOTÃO (própria, leve e previsível):
## discos deslizando com atrito, choques elásticos entre bola e botões,
## goleiro fixo (cápsula), traves, redes e as placas em volta.
## Cada choque vira um "evento" para as regras (quem tocou na bola, falta).

const Campo = preload("res://scripts/campo.gd")
const Corpo = preload("res://scripts/corpo.gd")

const SUBPASSOS_MAX := 6
const PASSO_MAX := 5.0          # px que a peça mais rápida anda por subpasso
const PARADO := 5.0             # abaixo disso (px/s) a peça para

var corpos := []
var postes := []                # [Vector2]
var segmentos := []             # [[a, b, restituição]]
var eventos := []               # [{a, b, v, tipo}] tipo: "corpo", "trave", "rede", "placa"


func _init() -> void:
	for t in [0, 1]:
		var x := Campo.linha_gol(t)
		var fundo := x - Campo.sentido(t) * Campo.GOL_FUNDO
		var y0 := Campo.CENTRO.y - Campo.GOL_MEIA
		var y1 := Campo.CENTRO.y + Campo.GOL_MEIA
		postes.append(Vector2(x, y0))
		postes.append(Vector2(x, y1))
		segmentos.append([Vector2(x, y0), Vector2(fundo, y0), 0.25])
		segmentos.append([Vector2(x, y1), Vector2(fundo, y1), 0.25])
		segmentos.append([Vector2(fundo, y0), Vector2(fundo, y1), 0.12])


func adicionar(c) -> void:
	corpos.append(c)


func tudo_parado() -> bool:
	for c in corpos:
		if c.ativo and not c.parado():
			return false
	return true


func parar_tudo() -> void:
	for c in corpos:
		c.vel = Vector2.ZERO


## Um passo de física. Os subpassos seguem a peça mais rápida (nenhuma anda
## mais que PASSO_MAX por subpasso, então nada atravessa nada): chute forte
## = até 6, peças devagar = 1. Antes eram sempre 4 (e a conta pesava na TV
## box justo nas jogadas rápidas).
func passo(dt: float) -> void:
	eventos.clear()
	var vmax := 0.0
	for c in corpos:
		if c.ativo and not c.fixo:
			vmax = max(vmax, c.vel.length())
	if vmax <= 0.0:
		return
	var n := int(clamp(ceil(vmax * dt / PASSO_MAX), 1.0, SUBPASSOS_MAX))
	var h := dt / n
	for _s in range(n):
		_mover(h)
		_colisoes()


func _mover(h: float) -> void:
	for c in corpos:
		if not c.ativo or c.fixo:
			continue
		var v: float = c.vel.length()
		if v <= 0.0:
			continue
		var nova = v - (c.atrito + c.amortece * v) * h
		if nova < PARADO:
			c.vel = Vector2.ZERO
			continue
		c.vel = c.vel * (nova / v)
		c.pos += c.vel * h


func _colisoes() -> void:
	# Só quem está andando pode bater em algo, e só em quem está perto: a
	# conta exata (_choque) roda apenas para pares que se tocam na caixa.
	var n := corpos.size()
	var cy := Campo.CENTRO.y
	var gx0 := Campo.CAMPO.position.x
	var gx1 := Campo.CAMPO.end.x
	var m := Campo.MURO
	for i in range(n):
		var a = corpos[i]
		if not a.ativo or a.fixo or (a.vel.x == 0.0 and a.vel.y == 0.0):
			continue
		var alcance: float = a.raio + a.meio
		for j in range(n):
			if j == i:
				continue
			var b = corpos[j]
			if not b.ativo:
				continue
			# par de dois em movimento: resolve uma vez só
			if j < i and not b.fixo and (b.vel.x != 0.0 or b.vel.y != 0.0):
				continue
			var lim: float = alcance + b.raio + b.meio
			var d: Vector2 = b.pos - a.pos
			if abs(d.x) < lim and abs(d.y) < lim:
				_choque(a, b)
		# traves, redes e a boca do gol: só perto de um dos gols
		var p: Vector2 = a.pos
		var perto_x: bool = (p.x < gx0 + alcance + 8.0 and p.x > gx0 - Campo.GOL_FUNDO - alcance - 8.0) \
			or (p.x > gx1 - alcance - 8.0 and p.x < gx1 + Campo.GOL_FUNDO + alcance + 8.0)
		if perto_x and abs(p.y - cy) < Campo.GOL_MEIA + alcance + 8.0:
			for q in postes:
				_choque_estatico(a, q, Campo.RAIO_TRAVE, 0.55, "trave")
			for sg in segmentos:
				var qs := Geometry.get_closest_point_to_segment_2d(a.pos, sg[0], sg[1])
				_choque_estatico(a, qs, 0.0, sg[2], "rede")
			if a.tipo == Corpo.BOTAO:
				_boca_do_gol(a)
		# placas: só quem encostou na borda
		var r: float = a.raio
		p = a.pos
		if p.x < m.position.x + r or p.x > m.end.x - r or p.y < m.position.y + r or p.y > m.end.y - r:
			_placas(a)


## Botão não entra no gol: uma "parede" invisível na linha entre as traves
## só para os botões (a bola passa). Botão parado dentro do gol impedia gols.
func _boca_do_gol(a) -> void:
	var r: float = a.raio
	var dy: float = abs(a.pos.y - Campo.CENTRO.y)
	if dy > Campo.GOL_MEIA + r:
		return               # longe da boca: as traves e as placas cuidam
	for l in [0, 1]:
		var x := Campo.x_gol_do_lado(l)
		var para_dentro := 1.0 if l == 0 else -1.0     # direção do campo
		# na boca: não passa da linha; junto da trave, por dentro da rede
		# (encostado na rede lateral): sai para a frente, nunca fica preso
		var limite := r if dy <= Campo.GOL_MEIA else 0.0
		if (a.pos.x - x) * para_dentro < limite and (a.pos.x - x) * para_dentro > -Campo.GOL_FUNDO - r:
			a.pos.x = x + para_dentro * r
			if a.vel.x * para_dentro < 0.0:
				var vn: float = abs(a.vel.x)
				a.vel.x = -a.vel.x * 0.35
				eventos.append({"a": a, "b": null, "v": vn, "tipo": "placa"})


func _choque(a, b) -> void:
	var pa: Vector2 = a.ponto_perto(b.pos)
	var pb: Vector2 = b.ponto_perto(pa)
	pa = a.ponto_perto(pb)
	var d := pb - pa
	var minimo: float = a.raio + b.raio
	var dist2 := d.length_squared()
	if dist2 >= minimo * minimo:
		return
	var dist := sqrt(dist2)
	var nrm := d / dist if dist > 0.0001 else Vector2.RIGHT
	var inv_a: float = 0.0 if a.fixo else 1.0 / a.massa
	var inv_b: float = 0.0 if b.fixo else 1.0 / b.massa
	var soma := inv_a + inv_b
	if soma <= 0.0:
		return
	var sobra := minimo - dist
	a.pos -= nrm * sobra * inv_a / soma
	b.pos += nrm * sobra * inv_b / soma
	var rel: float = (b.vel - a.vel).dot(nrm)
	if rel >= 0.0:
		return
	var e := 0.82
	if a.tipo == Corpo.BOLA or b.tipo == Corpo.BOLA:
		e = 0.78
	if a.fixo or b.fixo:
		e = 0.45
	var j := -(1.0 + e) * rel / soma
	a.vel -= nrm * j * inv_a
	b.vel += nrm * j * inv_b
	eventos.append({"a": a, "b": b, "v": -rel, "tipo": "corpo"})


func _choque_estatico(a, q: Vector2, raio_q: float, e: float, tipo: String) -> void:
	var d: Vector2 = a.pos - q
	var minimo: float = a.raio + raio_q
	var dist2 := d.length_squared()
	if dist2 >= minimo * minimo:
		return
	var dist := sqrt(dist2)
	var nrm := d / dist if dist > 0.0001 else Vector2.UP
	a.pos = q + nrm * minimo
	var vn: float = a.vel.dot(nrm)
	if vn < 0.0:
		a.vel -= nrm * vn * (1.0 + e)
		if tipo == "rede":
			a.vel *= 0.6
		eventos.append({"a": a, "b": null, "v": -vn, "tipo": tipo})


func _placas(a) -> void:
	var r: float = a.raio
	var m := Campo.MURO
	var bateu := 0.0
	if a.pos.x < m.position.x + r:
		a.pos.x = m.position.x + r
		if a.vel.x < 0:
			bateu = -a.vel.x
			a.vel.x = -a.vel.x * 0.45
	elif a.pos.x > m.end.x - r:
		a.pos.x = m.end.x - r
		if a.vel.x > 0:
			bateu = a.vel.x
			a.vel.x = -a.vel.x * 0.45
	if a.pos.y < m.position.y + r:
		a.pos.y = m.position.y + r
		if a.vel.y < 0:
			bateu = max(bateu, -a.vel.y)
			a.vel.y = -a.vel.y * 0.45
	elif a.pos.y > m.end.y - r:
		a.pos.y = m.end.y - r
		if a.vel.y > 0:
			bateu = max(bateu, a.vel.y)
			a.vel.y = -a.vel.y * 0.45
	if bateu > 0.0:
		eventos.append({"a": a, "b": null, "v": bateu, "tipo": "placa"})
