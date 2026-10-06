shader_type spatial;
render_mode cull_disabled;

// MORROS E MONTANHAS: a cor do vértice dá a base (grama, rocha nas encostas,
// neve no alto); aqui entram os detalhes de perto: manchas de mata e campo
// na grama, estratos e fendas na rocha, neve com brilho. Tudo em
// coordenadas do mundo; de longe o detalhe some (sem cintilar).

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

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += ruido(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 n = normalize(nw);
	vec3 base = COLOR.rgb;
	float d = length(w - (CAMERA_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	float perto = 1.0 - smoothstep(250.0, 900.0, d);
	// quanto é rocha / neve (pela cor da base)
	float lum = dot(base, vec3(0.3, 0.55, 0.15));
	float neve = smoothstep(0.75, 0.9, lum);
	float verde = clamp((base.g - max(base.r, base.b)) * 6.0, 0.0, 1.0);
	// grama: manchas de mata escura e campo claro
	float m1 = fbm(w.xz * 0.025);
	float m2 = fbm(w.xz * 0.11 + 5.0);
	vec3 grama = base * mix(0.7, 1.18, m1) * mix(0.9, 1.08, m2);
	grama = mix(grama, base * vec3(0.55, 0.75, 0.55), smoothstep(0.55, 0.7, m1) * 0.6);   // mata
	// rocha: estratos (faixas na altura) e fendas
	float estr = fbm(vec2(w.y * 0.35, (w.x + w.z) * 0.02));
	float fenda = smoothstep(0.62, 0.7, fbm(vec2(w.x + w.z, w.y * 2.0) * 0.06));
	vec3 rocha = base * mix(0.75, 1.15, estr) * (1.0 - 0.35 * fenda);
	vec3 c = mix(rocha, grama, verde);
	// neve: branca com azul na sombra
	vec3 c_neve = mix(vec3(0.82, 0.86, 0.95), vec3(0.97), smoothstep(0.2, 0.9, n.y)) * mix(0.93, 1.03, m2);
	c = mix(c, c_neve, neve);
	ALBEDO = mix(base, c, perto * 0.85 + 0.15);
	ROUGHNESS = mix(0.95, 0.55, neve);
	SPECULAR = mix(0.15, 0.45, neve);
}
