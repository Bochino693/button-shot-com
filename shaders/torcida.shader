// TORCIDA (Godot 3, GLES2): cada torcedor é uma "célula" da imagem.
// A cor da camisa vem das seleções (metade esquerda = casa, direita = fora)
// e cada um pula no seu ritmo. Nos gols, o lado que comemora pula alto.
// "ids" tem 1 pixel por célula: R = fase do pulo, G = qual camisa, B = pele.
// A fase vem do script já "dando a volta" (a GPU calcula em meia precisão).
shader_type canvas_item;

uniform sampler2D ids;
uniform vec4 casa1 : hint_color = vec4(1.0, 0.82, 0.0, 1.0);
uniform vec4 casa2 : hint_color = vec4(0.0, 0.6, 0.23, 1.0);
uniform vec4 fora1 : hint_color = vec4(0.46, 0.67, 0.86, 1.0);
uniform vec4 fora2 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fase = 0.0;
uniform float pulo_casa = 0.15;
uniform float pulo_fora = 0.15;
uniform float linhas = 60.0;

void fragment() {
	vec4 id = texture(ids, UV);
	float casa = step(UV.x, 0.5);
	float amp = mix(pulo_fora, pulo_casa, casa);
	float onda = sin(fase + id.r * 6.2832);
	float pulo = max(onda, 0.0) * amp;
	vec4 t = texture(TEXTURE, UV + vec2(0.0, pulo * 0.42 / linhas));
	vec3 camisa = vec3(0.86);
	if (id.g < 0.55) {
		camisa = mix(fora1.rgb, casa1.rgb, casa);
	} else if (id.g < 0.86) {
		camisa = mix(fora2.rgb, casa2.rgb, casa);
	}
	vec3 pele = mix(vec3(0.40, 0.25, 0.16), vec3(0.96, 0.80, 0.64), id.b);
	vec3 cor = vec3(0.08, 0.06, 0.05);
	if (t.g > 0.75) {
		cor = camisa;
	} else if (t.g > 0.25) {
		cor = pele;
	}
	COLOR = vec4(cor * t.r * 1.15, t.a);
}
