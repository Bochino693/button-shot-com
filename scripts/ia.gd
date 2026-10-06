extends Reference

## CPU DO FUTEBOL DE BOTÃO. Para cada botão e cada ideia de jogada (chute a
## gol, conduzir a bola, afastar do perigo) calcula onde o botão precisa
## bater na bola e com que força, descarta o que acertaria um botão rival
## antes da bola (falta!) e escolhe a melhor. A dificuldade e a força da
## seleção mudam a mira (erro de ângulo e de força).

const Campo = preload("res://scripts/campo.gd")
const Corpo = preload("res://scripts/corpo.gd")

const VMAX := 1150.0
const VMIN := 90.0
const ATRITO_BOTAO := 700.0
const ATRITO_BOLA := 260.0
const AMORTECE_BOLA := 0.35
const GANHO_BOLA := 1.335        # (1 + e) * m_botao / (m_botao + m_bola)


## Distância que a bola anda saindo com velocidade v.
static func distancia_bola(v: float) -> float:
	var piso: float = Campo.ESTADO.piso          # chuva: a bola corre menos
	var k := AMORTECE_BOLA * (1.0 + (piso - 1.0) * 0.5)
	var a := ATRITO_BOLA * piso
	return v / k - (a / (k * k)) * log(1.0 + k * v / a)


## Velocidade para a bola andar d.
static func velocidade_bola(d: float) -> float:
	var lo := 0.0
	var hi := 4000.0
	for _i in range(24):
		var m := (lo + hi) * 0.5
		if distancia_bola(m) < d:
			lo = m
		else:
			hi = m
	return hi


## Para mandar a bola na direção d: em que direção lançar o botão?
## Traça o caminho do botão até o ponto exato em que ele encosta na bola
## (a bola sai na direção da linha entre os centros nesse instante) e
## procura o ângulo de lançamento que faz a bola sair em d.
## Retorna {u, D (distância até o contato), cos (quanto da força passa), erro}.
static func mirar(b: Vector2, bola: Vector2, d: Vector2, rb: float) -> Dictionary:
	var contato := bola - d * rb
	var base := (contato - b)
	var ang0 := base.angle() if base.length() > 2.0 else d.angle()
	# busca grossa (de 5 em 5 graus) e depois fina (de 1 em 1) em volta
	var melhor := _testar_angulos(b, bola, d, rb, ang0, deg2rad(5.0), 12, {})
	if not melhor.empty():
		melhor = _testar_angulos(b, bola, d, rb, melhor.ang, deg2rad(1.0), 5, melhor)
	return melhor


static func _testar_angulos(b: Vector2, bola: Vector2, d: Vector2, rb: float, centro: float, passo: float, n: int, melhor: Dictionary) -> Dictionary:
	var melhor_erro: float = melhor.erro if not melhor.empty() else 9.0
	var m := b - bola
	var cc := m.dot(m) - rb * rb
	for i in range(-n, n + 1):
		var ang := centro + i * passo
		var u := Vector2(cos(ang), sin(ang))
		var bb := m.dot(u)
		var disc := bb * bb - cc
		if disc < 0.0:
			continue
		var s := -bb - sqrt(disc)
		if s < -0.5:
			continue
		var ponto := b + u * max(s, 0.0)
		var nrm := (bola - ponto) / rb
		var erro: float = abs(nrm.angle_to(d))
		if erro < melhor_erro:
			melhor_erro = erro
			melhor = {"u": u, "D": max(s, 0.0), "cos": u.dot(nrm.normalized()), "erro": erro, "ang": ang}
	return melhor


## Algo no caminho do segmento a->b (raio r)? ignorar: corpos que não contam.
static func bloqueado(corpos: Array, a: Vector2, b: Vector2, r: float, ignorar: Array) -> Object:
	for c in corpos:
		if not c.ativo or c in ignorar:
			continue
		var q: Vector2
		if c.meio > 0.0:
			var pts := Geometry.get_closest_points_between_segments_2d(a, b, c.pos - Vector2(0, c.meio), c.pos + Vector2(0, c.meio))
			q = pts[1]
			if pts[0].distance_to(q) < r + c.raio:
				return c
			continue
		q = Geometry.get_closest_point_to_segment_2d(c.pos, a, b)
		if q.distance_to(c.pos) < r + c.raio:
			return c
	return null


## Decide a jogada. contexto: {time, bola, corpos, toques_restantes,
## dificuldade (0..2), forca (70..95), penalti: botão cobrador ou null}
static func decidir(ctx: Dictionary) -> Dictionary:
	var time: int = ctx.time
	var bola = ctx.bola
	var corpos: Array = ctx.corpos
	var restantes: int = ctx.toques_restantes
	var vmax: float = ctx.get("vmax", VMAX)
	var adv := 1 - time
	var gx := Campo.linha_gol(adv)
	var sent := Campo.sentido(time)
	var goleiro_adv = null
	for c in corpos:
		if c.tipo == Corpo.GOLEIRO and c.time == adv:
			goleiro_adv = c
	var candidatos := []
	var meus := []
	for c in corpos:
		if c.ativo and c.time == time and c.tipo == Corpo.BOTAO:
			# bola parada com cobrador (falta, lateral, escanteio): só ele
			if ctx.get("fixo") != null and ctx.fixo != c:
				continue
			if ctx.get("penalti") == null or ctx.penalti == c:
				meus.append(c)

	# ideias de para onde mandar a bola: [direção, distância desejada, tipo]
	var ideias := []
	var dist_gol = bola.pos.distance_to(Vector2(gx, Campo.CENTRO.y))
	for fy in [-0.72, -0.4, 0.0, 0.4, 0.72]:
		var alvo := Vector2(gx + sent * 20.0, Campo.CENTRO.y + fy * Campo.GOL_MEIA)
		ideias.append([(alvo - bola.pos).normalized(), bola.pos.distance_to(alvo) + 120.0, "chute", alvo])
	if restantes > 1 and ctx.get("penalti") == null:
		var frente := Vector2(sent, 0)
		for ang in [0.0, 0.35, -0.35, 0.7, -0.7]:
			for d in [150.0, 240.0]:
				var dir := frente.rotated(ang)
				ideias.append([dir, d, "conduzir", bola.pos + dir * d])
	# bola perto do próprio gol: afastar para os lados/frente
	var perigo := Campo.na_area(bola.pos, time) or abs(bola.pos.x - Campo.linha_gol(time)) < 260.0
	if perigo:
		for ang in [0.6, -0.6, 0.3, -0.3]:
			var dir2 := Vector2(sent, 0).rotated(ang)
			ideias.append([dir2, 520.0, "afastar", bola.pos + dir2 * 520.0])

	var rb: float = Campo.RAIO_BOTAO + Campo.RAIO_BOLA
	for b in meus:
		for ideia in ideias:
			var d: Vector2 = ideia[0]
			var m := mirar(b.pos, bola.pos, d, rb)
			if m.empty():
				continue
			var u: Vector2 = m.u
			var D: float = m.D
			var cosang: float = m.cos
			var contato: Vector2 = b.pos + u * D
			if cosang < 0.2 or m.erro > 0.06:
				continue
			var obst = bloqueado(corpos, b.pos, contato, Campo.RAIO_BOTAO, [b, bola])
			if obst != null:
				continue            # acertaria outro botão (se for rival: falta)
			var alvo: Vector2 = ideia[3]
			var destino_ok = Campo.dentro_do_campo(alvo, -8.0) or ideia[2] == "chute"
			if not destino_ok:
				continue
			var v_bola := velocidade_bola(ideia[1])
			if ideia[2] == "chute":
				v_bola = max(v_bola * 1.15, 700.0)
			var v_contato := v_bola / (GANHO_BOLA * cosang)
			var v0 := sqrt(v_contato * v_contato + 2.0 * ATRITO_BOTAO * D)
			var fraco := 0.0
			if v0 > vmax:
				fraco = (v0 - vmax) / vmax
				v0 = vmax
			var nota := 0.0
			match ideia[2]:
				"chute":
					var ignorar := [bola, b]
					if ctx.has("goleiro_y"):
						ignorar.append(goleiro_adv)
					var livre = bloqueado(corpos, bola.pos, alvo, Campo.RAIO_BOLA, ignorar)
					nota = 70.0 - dist_gol * 0.06
					if livre != null:
						nota -= 45.0 if livre != goleiro_adv else 35.0
					if ctx.has("goleiro_y") and abs(alvo.y - ctx.goleiro_y) < 44.0:
						nota -= 40.0
					if restantes <= 1:
						nota += 18.0
					nota -= fraco * 90.0
				"conduzir":
					var avanco: float = (alvo.x - bola.pos.x) * sent
					nota = 28.0 + avanco * 0.06
					var perto := 999.0
					for c in corpos:
						if c.ativo and c.time == adv:
							perto = min(perto, c.pos.distance_to(alvo))
					nota += min(perto, 160.0) * 0.12
					nota -= fraco * 60.0
				"afastar":
					nota = 40.0 + (22.0 if perigo else 0.0) - fraco * 40.0
			nota -= (1.0 - cosang) * 25.0 + D * 0.02
			candidatos.append({"botao": b, "vel": u * v0, "nota": nota, "tipo": ideia[2], "alvo": alvo})

	if candidatos.empty():
		return _reposicionar(ctx, meus)
	candidatos.sort_custom(Ordem.new(), "maior")
	var dif: int = ctx.dificuldade
	# fácil às vezes pega a 2ª ou 3ª melhor ideia
	var idx := 0
	if dif == 0 and candidatos.size() > 2 and randf() < 0.45:
		idx = 1 + randi() % 2
	elif dif == 1 and candidatos.size() > 1 and randf() < 0.2:
		idx = 1
	var esc: Dictionary = candidatos[idx]
	return _errar(esc, ctx)


## Sem jogada boa: leva um botão para perto da bola (entre ela e o gol).
static func _reposicionar(ctx: Dictionary, meus: Array) -> Dictionary:
	var bola = ctx.bola
	var time: int = ctx.time
	var melhor = null
	var md := 1e9
	for b in meus:
		var d: float = b.pos.distance_to(bola.pos)
		if d < md:
			md = d
			melhor = b
	if melhor == null:
		return {}
	var meu_gol := Campo.centro_gol(time)
	var alvo: Vector2 = bola.pos + (meu_gol - bola.pos).normalized() * 70.0
	var dir: Vector2 = (alvo - melhor.pos)
	var dist := dir.length()
	if dist < 5.0:
		dir = Vector2(Campo.sentido(time), 0)
		dist = 60.0
	var v0: float = clamp(sqrt(2.0 * ATRITO_BOTAO * dist * 0.9), VMIN, VMAX * 0.7)
	return _errar({"botao": melhor, "vel": dir.normalized() * v0, "nota": 0.0, "tipo": "posicionar", "alvo": alvo}, ctx)


static func _errar(esc: Dictionary, ctx: Dictionary) -> Dictionary:
	var dif: int = ctx.dificuldade
	var forca: float = ctx.forca
	var erro_ang: float = [0.075, 0.035, 0.014][dif]
	var erro_v: float = [0.16, 0.08, 0.035][dif]
	var fator: float = ctx.get("erro", lerp(1.35, 0.75, clamp((forca - 75.0) / 20.0, 0.0, 1.0)))
	var v: Vector2 = esc.vel
	v = v.rotated(_gauss() * erro_ang * fator)
	v *= 1.0 + _gauss() * erro_v * fator
	var vmax: float = ctx.get("vmax", VMAX)
	if v.length() > vmax:
		v = v.normalized() * vmax
	esc.vel = v
	return esc


static func _gauss() -> float:
	return clamp((randf() + randf() + randf() - 1.5) * 1.4, -2.2, 2.2)


class Ordem:
	extends Reference
	func maior(a, b) -> bool:
		return a.nota > b.nota
