extends Reference

## MEDIDAS DO CAMPO (em 1280x720, as mesmas de tools/gerar_arte.py).
## O time 0 (casa) começa defendendo o gol da ESQUERDA; no 2º tempo troca.

const MURO := Rect2(96, 88, 1088, 614)          # placas: ninguém passa
const CAMPO := Rect2(140, 110, 1000, 570)       # linhas do campo
const CENTRO := Vector2(640, 395)
const GOL_MEIA := 78.0                          # meia boca do gol (62 → 78 na build 17)
const GOL_FUNDO := 38.0
const AREA_P := 172.0
const AREA_MEIA := 192.0
const AREA_G := 64.0
const AREA_G_MEIA := 104.0
const MARCA_PEN := 114.0
const RAIO_CIRCULO := 87.0

const RAIO_BOTAO := 31.0          # tazo (21 → 24 na build 3 → 31 na build 8)
const RAIO_BOLA := 9.0
const GOLEIRO_MEIO := 24.0      # meia altura do segmento do goleiro (cápsula)
const GOLEIRO_RAIO := 10.0
const RAIO_TRAVE := 4.0


## TROCA DE LADO: no 1º tempo a casa (time 0) defende a esquerda; no 2º tempo
## os times trocam de lado (ESTADO.trocado; o dicionário constante é o único
## "estado" deste script de funções estáticas). Tudo que depende do lado passa
## por aqui, então física, regras e CPU trocam juntas.
const ESTADO := {"trocado": false, "piso": 1.0}


static func trocar_lados(sim: bool) -> void:
	var e: Dictionary = ESTADO
	e["trocado"] = sim


## Atrito da bola no clima da partida (1 = seco; chuva segura a bola).
static func definir_piso(k: float) -> void:
	var e: Dictionary = ESTADO
	e["piso"] = k


static func lado(time: int) -> int:
	return (1 - time) if ESTADO.trocado else time


## Qual time defende o gol daquele lado da tela (0 = esquerda).
static func time_do_lado(l: int) -> int:
	return (1 - l) if ESTADO.trocado else l


static func x_gol_do_lado(l: int) -> float:
	return CAMPO.position.x if l == 0 else CAMPO.end.x


## x da linha de fundo do gol que o time defende.
static func linha_gol(time: int) -> float:
	return x_gol_do_lado(lado(time))


## Para onde o time ataca (+1 direita, -1 esquerda).
static func sentido(time: int) -> float:
	return 1.0 if lado(time) == 0 else -1.0


static func centro_gol(time_que_defende: int) -> Vector2:
	return Vector2(linha_gol(time_que_defende), CENTRO.y)


static func marca_penalti(time_que_defende: int) -> Vector2:
	return Vector2(linha_gol(time_que_defende) + sentido(time_que_defende) * MARCA_PEN, CENTRO.y)


## Está dentro da grande área que o time defende?
static func na_area(p: Vector2, time_que_defende: int) -> bool:
	var x0 := linha_gol(time_que_defende)
	var dx := (p.x - x0) * sentido(time_que_defende)
	return dx >= -4.0 and dx <= AREA_P and abs(p.y - CENTRO.y) <= AREA_MEIA


static func dentro_do_campo(p: Vector2, folga := 0.0) -> bool:
	return p.x >= CAMPO.position.x - folga and p.x <= CAMPO.end.x + folga and p.y >= CAMPO.position.y - folga and p.y <= CAMPO.end.y + folga


## Posições de saída (2 zagueiros, 2 meias, 2 atacantes) do time, em
## frações do campo para o time 0; espelhadas para o time 1.
const FORMACAO := [
	Vector2(0.14, 0.30), Vector2(0.14, 0.70),
	Vector2(0.30, 0.22), Vector2(0.30, 0.78),
	Vector2(0.43, 0.38), Vector2(0.43, 0.62),
]


static func posicao_formacao(time: int, i: int) -> Vector2:
	var f: Vector2 = FORMACAO[i]
	var x := CAMPO.position.x + f.x * CAMPO.size.x
	if lado(time) == 1:
		x = CAMPO.end.x - f.x * CAMPO.size.x
	return Vector2(x, CAMPO.position.y + f.y * CAMPO.size.y)
