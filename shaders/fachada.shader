shader_type spatial;
render_mode unshaded, cull_disabled;

// FACHADA DO ESTÁDIO (vista de fora). UV: x ao longo da parede, y = 1
// embaixo, 0 em cima. Três estilos:
//   0 = concreto: pilares a cada 6 m e as aberturas das rampas (acesas por
//       dentro à noite), faixa de LED na cor do time no alto (Maracanã...)
//   1 = almofadas em losango que acendem na cor do time (Arena de Munique)
//   2 = lâminas metálicas horizontais com filetes de LED (Bernabéu, Wembley)

uniform vec4 cor : hint_color = vec4(0.6, 0.62, 0.66, 1.0);
uniform vec4 faixa : hint_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec2 tam = vec2(100.0, 30.0);
uniform float noite = 0.0;
uniform float luz = 1.0;
uniform float estilo = 0.0;

void fragment() {
	vec2 p = vec2(UV.x * tam.x, (1.0 - UV.y) * tam.y);
	vec2 fw = fwidth(p);
	float longe = smoothstep(0.6, 2.0, max(fw.x, fw.y));
	vec3 base = cor.rgb * luz;
	vec3 c;
	if (estilo > 1.5) {
		float f = fract(p.y / 1.4);
		float lamina = smoothstep(0.0, 0.12, f) * (1.0 - smoothstep(0.55, 0.68, f));
		vec3 metal = mix(base * 0.62, base, lamina);
		metal = mix(metal, base * 0.82, longe);
		float led = step(0.9, fract(p.y / 5.6)) * step(2.0, p.y);
		c = mix(metal, faixa.rgb * (0.7 + 0.8 * noite), led * (0.35 + 0.65 * noite));
	} else if (estilo > 0.5) {
		vec2 q = vec2(p.x + p.y, p.x - p.y) / 5.0;
		vec2 cel = abs(fract(q) - 0.5);
		float almofada = 1.0 - smoothstep(0.36, 0.5, max(cel.x, cel.y));
		almofada = mix(almofada, 0.8, longe);
		vec3 dia = base * (0.72 + 0.28 * almofada);
		vec3 acesa = faixa.rgb * (0.45 + 0.75 * almofada);
		c = mix(dia, acesa, 0.15 + 0.8 * noite);
	} else {
		float pil = step(0.8, fract(p.x / 6.0));
		float fy = fract(p.y / 4.2);
		float vao = step(0.18, fy) * step(fy, 0.72) * (1.0 - pil) * step(3.5, p.y) * step(p.y, tam.y - 4.5);
		float led = step(tam.y - 3.6, p.y) * step(p.y, tam.y - 1.2);
		c = base * (0.88 + 0.22 * pil);
		vec3 dentro = mix(base * 0.3, vec3(1.0, 0.82, 0.55) * 0.9, noite);
		c = mix(c, dentro, vao * 0.9);
		c = mix(c, mix(c, dentro, 0.45), longe);
		c = mix(c, faixa.rgb * (0.85 + 0.7 * noite), led);
	}
	ALBEDO = c;
}
