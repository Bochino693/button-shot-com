shader_type spatial;
render_mode unshaded, cull_disabled;

// PLACAS DE LED em volta do gramado: faixas nas cores da Lazer & Sport
// correndo devagar, com a textura de pontinhos do painel.

uniform vec4 cor1 : hint_color = vec4(0.94, 0.25, 0.38, 1.0);
uniform vec4 cor2 : hint_color = vec4(0.22, 0.72, 0.93, 1.0);
uniform float brilho = 1.5;

void fragment() {
	float u = UV.x * 70.0 - mod(TIME, 1000.0) * 0.5;
	float b = smoothstep(0.45, 0.55, abs(fract(u) - 0.5) * 2.0);
	vec3 c = mix(cor1.rgb, cor2.rgb, b);
	float onda = 0.8 + 0.2 * sin(UV.x * 400.0 + mod(TIME, 100.0) * 3.0);
	ALBEDO = c * brilho * onda;
}
