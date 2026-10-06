extends Reference

## Uma peça na mesa: bola, botão ou goleiro (cápsula em pé, parado
## durante a jogada, como o goleiro "caixinha" segurado pela mão).

enum { BOLA, BOTAO, GOLEIRO }

var tipo := BOTAO
var time := -1
var numero := 0
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var raio := 31.0
var massa := 3.0
var atrito := 700.0        # desaceleração de deslizar (px/s²)
var amortece := 0.0        # desaceleração proporcional à velocidade (1/s)
var fixo := false          # não é empurrado (goleiro)
var meio := 0.0            # meia altura do segmento (goleiro)
var ativo := true          # expulso = false
var no: Node2D             # desenho na tela
var amarelos := 0


func parado() -> bool:
	return vel.length_squared() < 0.0001


## Ponto do "osso" do corpo mais perto de p (cápsula do goleiro).
func ponto_perto(p: Vector2) -> Vector2:
	if meio <= 0.0:
		return pos
	var y := clamp(p.y, pos.y - meio, pos.y + meio)
	return Vector2(pos.x, y)
