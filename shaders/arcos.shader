shader_type spatial;
render_mode cull_disabled;

// COLISEU com luz de verdade: a parede de fora com os 3 andares de arcos e
// o ático de janelinhas; à noite os arcos acendem por dentro e a pedra fica
// iluminada pelos refletores. UV.x = vão, UV.y = andar; COLOR.a = 1 fora.

uniform float noite = 0.0;

void fragment() {
	vec3 c = COLOR.rgb;
	float vao_aceso = 0.0;
	ROUGHNESS = 0.9;
	if (COLOR.a > 0.5) {
		float andar = floor(UV.y);
		vec2 f = fract(UV);
		float topo = 0.6 + 0.2 * sqrt(max(0.0, 1.0 - pow((f.x - 0.5) / 0.3, 2.0)));
		float arco = step(0.2, f.x) * step(f.x, 0.8) * step(0.06, f.y) * step(f.y, topo);
		if (andar >= 3.0) {
			arco = step(0.42, f.x) * step(f.x, 0.58) * step(0.4, f.y) * step(f.y, 0.62);
		}
		float cornija = step(0.93, f.y);
		vec2 fw = fwidth(UV);
		float longe = smoothstep(0.3, 0.8, max(fw.x, fw.y));
		float a = mix(arco, 0.4, longe);
		c = mix(c, c * 0.28, a * (1.0 - noite));
		c = mix(c, c * 1.12, cornija * (1.0 - longe));
		vao_aceso = a * noite;
	}
	ALBEDO = c * (1.0 - 0.5 * noite);
	EMISSION = mix(c * 0.55 * noite, vec3(1.0, 0.72, 0.38) * 1.2, vao_aceso);
}
