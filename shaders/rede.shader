shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_alpha_prepass;

// REDE DO GOL: malha de 11 cm desenhada no fragmento (suave de perto, média
// de longe, sem cintilar) e o estufar da rede no ponto onde a bola bate.

uniform vec2 ponto = vec2(0.0, 0.0);
uniform float amp = 0.0;
uniform float luz = 1.0;

varying vec2 lp;

void vertex() {
	lp = VERTEX.xy;
	vec2 d = VERTEX.xy - ponto;
	VERTEX.z -= amp * exp(-dot(d, d) / 0.45);
}

void fragment() {
	vec2 g = lp / 0.11;
	vec2 e = 0.5 - abs(fract(g) - 0.5);
	vec2 w = fwidth(g);
	float fio = max(1.0 - smoothstep(0.0, w.x * 1.3 + 0.04, e.x), 1.0 - smoothstep(0.0, w.y * 1.3 + 0.04, e.y));
	float longe = clamp(max(w.x, w.y) * 2.0 - 0.6, 0.0, 1.0);
	ALBEDO = vec3(0.95, 0.96, 0.98) * luz;
	ALPHA = mix(fio * 0.9, 0.28, longe);
}
