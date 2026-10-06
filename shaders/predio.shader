shader_type spatial;
render_mode cull_disabled;

// PRÉDIOS DA PAISAGEM, com a luz de verdade da cena (sol/lua e sombras).
// Parede com a cor do vértice; a fachada é desenhada em coordenadas do
// mundo, andar por andar (3,4 m):
//   * janelas com moldura clara, peitoril e vidro que reflete o céu;
//   * linha da laje entre os andares;
//   * térreo com vitrines grandes e toldo colorido (acesas à noite);
//   * prédio azulado = torre de vidro (pele de vidro com montantes).
// De noite parte das janelas acende. De longe a fachada vira a média (sem
// cintilar). COLOR.a = densidade de janelas (0 = parede lisa).

uniform float noite = 0.0;
uniform float chuva = 0.0;
uniform vec4 vidro : hint_color = vec4(0.5, 0.6, 0.7, 1.0);
uniform vec4 ceu : hint_color = vec4(0.62, 0.76, 0.92, 1.0);
uniform vec4 acesa : hint_color = vec4(1.0, 0.8, 0.48, 1.0);
uniform vec2 janela = vec2(3.2, 3.4);

varying vec3 w;
varying vec3 nw;

void vertex() {
	w = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nw = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float caixa(vec2 f, vec2 a, vec2 b, float s) {
	return smoothstep(a.x - s, a.x + s, f.x) * (1.0 - smoothstep(b.x - s, b.x + s, f.x))
		* smoothstep(a.y - s, a.y + s, f.y) * (1.0 - smoothstep(b.y - s, b.y + s, f.y));
}

void fragment() {
	vec3 n = normalize(nw);
	vec3 base = COLOR.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
	if (n.y > 0.6) {
		// terraço: manta escura com placas e manchas
		vec2 q = w.xz;
		float pl = step(0.06, min(abs(fract(q.x / 4.0) - 0.5), abs(fract(q.y / 4.0) - 0.5)));
		ALBEDO = mix(vec3(0.3, 0.3, 0.31), base * 0.55, 0.35) * (0.85 + 0.15 * pl) * (0.9 + 0.2 * hash(floor(q / 4.0)));
	} else if (n.y < -0.6) {
		ALBEDO = base * 0.4;
	} else {
		bool em_x = abs(n.x) > 0.5;
		float hc = em_x ? w.z : w.x;
		float vidraca = step(base.r + 0.05, base.b);        // prédio azulado = torre de vidro
		vec2 cel = vec2(hc / janela.x, w.y / janela.y);
		vec2 f = fract(cel);
		vec2 id = floor(cel);
		vec2 fw = fwidth(cel);
		float longe = smoothstep(0.3, 0.85, max(fw.x, fw.y));
		float s = clamp(max(fw.x, fw.y) * 1.5, 0.004, 0.08);
		float terreo = 1.0 - step(1.0, id.y);
		// janela, moldura e peitoril
		float jan = caixa(f, vec2(0.2, 0.3), vec2(0.8, 0.82), s);
		float mold = caixa(f, vec2(0.15, 0.25), vec2(0.85, 0.87), s) - jan;
		float peit = caixa(f, vec2(0.13, 0.2), vec2(0.87, 0.26), s);
		float laje = 1.0 - smoothstep(0.0, 0.05 + s, f.y);
		// térreo: vitrine larga e toldo
		float vit = caixa(f, vec2(0.06, 0.1), vec2(0.94, 0.72), s);
		float toldo = caixa(f, vec2(0.02, 0.76), vec2(0.98, 0.9), s);
		// pele de vidro: montantes finos e faixa da laje
		float mont = max(1.0 - smoothstep(0.0, 0.04 + s, 1.0 - abs(f.x - 0.5) * 2.0), laje * 0.8);
		float h_b = hash(floor(w.xz / 9.0) + id.y * 0.37);
		vec3 parede = base * (0.94 + 0.06 * hash(id)) * (0.72 + 0.28 * clamp(w.y / 10.0, 0.0, 1.0));
		parede = mix(parede, parede * 0.78, laje);
		parede = mix(parede, min(base * 1.22 + 0.05, vec3(1.0)), mold * 0.9);
		parede = mix(parede, base * 1.1, peit * 0.6);
		// vidro: reflexo do céu (mais forte de lado) ou escuro
		float fres = pow(1.0 - clamp(abs(dot(n, VIEW)), 0.0, 1.0), 2.0);
		vec3 v_cor = mix(vidro.rgb * 0.55, ceu.rgb, 0.25 + 0.6 * fres) * (0.8 + 0.4 * hash(id + 3.1));
		v_cor *= 1.0 - 0.8 * noite;
		float m_jan = mix(jan, vit, terreo) * COLOR.a;
		vec3 c = mix(parede, v_cor, m_jan);
		vec3 aw = vec3(0.7, 0.15, 0.12);
		if (h_b > 0.66) aw = vec3(0.1, 0.35, 0.6);
		else if (h_b > 0.33) aw = vec3(0.12, 0.45, 0.22);
		c = mix(c, aw, toldo * terreo * COLOR.a);
		// torre de vidro
		vec3 c_vidro = mix(v_cor * 1.1, base * 0.6, mont);
		c = mix(c, c_vidro, vidraca * COLOR.a);
		float m_vidro = max(m_jan, vidraca * (1.0 - mont) * COLOR.a);
		// de longe: média
		vec3 media = mix(base * 0.85, v_cor, 0.38 * COLOR.a + 0.35 * vidraca);
		c = mix(c, media, longe);
		m_vidro = mix(m_vidro, 0.35, longe);
		ALBEDO = c;
		ROUGHNESS = mix(0.85, 0.08, m_vidro);
		SPECULAR = mix(0.3, 0.9, m_vidro);
		// noite: janelas acesas (algumas), vitrines quase todas
		float hl = hash(id + vec2(floor(w.x * 0.05) * 13.0, floor(w.z * 0.05) * 7.0));
		float lit = mix(step(hl, 0.32), step(hl, 0.75), terreo) * noite;
		lit = mix(lit, 0.3 * noite, longe);
		vec3 a = acesa.rgb * (0.85 + 0.6 * hash(id * 1.37)) * mix(vec3(1.0), vec3(0.85, 0.95, 1.15), step(0.7, hash(id * 2.1)));
		EMISSION = a * lit * m_vidro * 1.5;
	}
}
