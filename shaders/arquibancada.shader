shader_type spatial;
render_mode unshaded, cull_disabled;

// ARQUIBANCADA 3D: uma grade de torcedores (atlas torcedores.png) sobre o
// degrau. Cada célula sorteia (hash) o torcedor, a camisa (cores dos dois
// times), a pele, lugar vazio e o ritmo do pulo. Uma textura pequena só.

uniform sampler2D fans;
uniform sampler2D ruido;              // 64x64, sem filtro, repetindo
uniform vec4 cor1 : hint_color;
uniform vec4 cor2 : hint_color;
uniform vec4 cor_fora : hint_color;
uniform float mistura = 0.2;          // fração da torcida visitante
uniform vec4 assento : hint_color;
uniform vec2 grade = vec2(120.0, 16.0);
uniform float luz = 1.0;
uniform float pulo = 0.6;
uniform float variantes = 16.0;


void fragment() {
	vec2 g = UV * grade;
	// de longe cada torcedor fica menor que um pixel e a grade cintila: aí a
	// arquibancada vira a "média" da torcida (cores dos times), sem piscar
	vec2 fw = fwidth(g);
	float lod = smoothstep(0.22, 0.6, max(fw.x, fw.y));
	vec2 c = floor(g);
	vec4 sorteio = texture(ruido, (c + vec2(0.5)) / 64.0);
	float h = sorteio.r;
	float h2 = sorteio.g;
	float h3 = sorteio.b;
	vec2 l = fract(g);
	float salto = max(0.0, sin(mod(TIME, 62.83) * (4.0 + h2 * 3.0) + h * 6.283)) * pulo * 0.2 * (1.0 - lod);
	l.y = l.y + salto - 0.06;
	vec3 col = assento.rgb * (0.7 + 0.3 * fract(g.y));
	if (h3 > 0.06 && l.y >= 0.0 && l.y <= 1.0) {
		vec2 a = vec2((floor(h * variantes) + clamp(l.x, 0.02, 0.98)) / variantes, l.y);
		vec4 t = texture(fans, a);
		// borda suave (sem serrilhado): mistura com o degrau pelo alfa
		float forma = smoothstep(0.3, 0.7, t.a);
		if (forma > 0.0) {
			vec3 camisa = h2 < mistura ? cor_fora.rgb : (sorteio.a < 0.6 ? cor1.rgb : cor2.rgb);
			vec3 pele = mix(vec3(0.96, 0.8, 0.66), vec3(0.42, 0.28, 0.19), fract(h * 5.0 + h2));
			vec3 cabelo = mix(vec3(0.09, 0.06, 0.05), vec3(0.55, 0.38, 0.2), step(0.8, fract(h * 9.0)));
			float resto = clamp(1.0 - t.g - t.b, 0.0, 1.0);
			vec3 gente = (camisa * t.g + pele * t.b + cabelo * resto) * (0.4 + 0.8 * t.r);
			col = mix(col, gente, forma);
		}
	}
	if (lod > 0.0) {
		vec4 r2 = texture(ruido, UV * grade / 256.0);
		vec3 camisas = mix(mix(cor1.rgb, cor2.rgb, 0.4), cor_fora.rgb, mistura);
		vec3 media = mix(assento.rgb * 0.8, camisas * 0.85 + vec3(0.05), 0.75) * (0.82 + 0.3 * r2.r);
		col = mix(col, media, lod);
	}
	ALBEDO = col * luz;
}
