shader_type spatial;
render_mode cull_disabled;

// TRELIÇA DE FERRO (Torre Eiffel), com luz de verdade: vazados em
// diagonal, que de longe viram ferro "cheio" (sem cintilar). À noite a
// torre acende dourada (brilho próprio).

uniform float noite = 0.0;

varying vec3 w;

void vertex() {
	w = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 a = vec2(w.x + w.y, w.z - w.y) / 2.2;
	vec2 b = vec2(w.x - w.y, w.z + w.y) / 2.2;
	vec2 g = abs(fract(a) - 0.5);
	vec2 h = abs(fract(b) - 0.5);
	float fio = max(max(step(0.34, g.x), step(0.34, g.y)), max(step(0.34, h.x), step(0.34, h.y)));
	vec2 fw = fwidth(a);
	float longe = smoothstep(0.2, 0.6, max(fw.x, fw.y));
	if (fio < 0.5 && longe < 0.5) {
		discard;
	}
	vec3 c = COLOR.rgb * mix(1.0, 0.88, longe);
	ALBEDO = c * (1.0 - 0.6 * noite);
	ROUGHNESS = 0.55;
	METALLIC = 0.35;
	EMISSION = c * noite * 0.85;
}
