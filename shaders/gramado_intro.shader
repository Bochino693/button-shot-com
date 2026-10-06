shader_type spatial;
render_mode unshaded;

// GRAMADO da abertura Lazer & Sport: faixas de corte, ruído suave, linhas
// oficiais (área, pequena área, meia-lua, marca do pênalti) desenhadas com
// borda suave, luz dos refletores e sombras de contato do jogador e da bola.

uniform vec4 sombra_jog = vec4(0.0, 0.0, 0.6, 0.0);    // x, z, raio, força
uniform vec4 sombra_bola = vec4(0.0, 0.0, 0.2, 0.0);
uniform float luz = 1.0;

varying vec3 mundo;

void vertex() {
	mundo = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

float linha(float d) {
	float f = fwidth(d);
	return 1.0 - smoothstep(0.06 - f, 0.06 + f, abs(d));
}

void fragment() {
	vec2 p = mundo.xz;
	float faixa = mod(floor((p.y + 18.0) / 5.5), 2.0);
	vec3 g = mix(vec3(0.09, 0.33, 0.11), vec3(0.13, 0.43, 0.15), faixa);
	float n = ruido(p * 1.7) * 0.45 + ruido(p * 0.23) * 0.55;
	g *= 0.82 + 0.34 * n;
	float L = 0.0;
	L = max(L, linha(p.y + 18.0) * step(abs(p.x), 28.5));
	L = max(L, linha(p.y + 1.5) * step(abs(p.x), 20.16));
	L = max(L, linha(abs(p.x) - 20.16) * step(-18.0, p.y) * step(p.y, -1.5));
	L = max(L, linha(p.y + 12.5) * step(abs(p.x), 9.16));
	L = max(L, linha(abs(p.x) - 9.16) * step(-18.0, p.y) * step(p.y, -12.5));
	L = max(L, linha(abs(p.x) - 28.5) * step(-18.0, p.y) * step(p.y, 82.0));
	L = max(L, linha(p.y - 32.0) * step(abs(p.x), 28.5));
	L = max(L, linha(length(p - vec2(0.0, 32.0)) - 9.15));
	L = max(L, 1.0 - smoothstep(0.12, 0.16, length(p - vec2(0.0, 32.0))));
	float dc = length(p - vec2(0.0, -7.0));
	L = max(L, linha(dc - 9.15) * step(-1.5, p.y));
	L = max(L, 1.0 - smoothstep(0.1, 0.13, dc));
	g = mix(g, vec3(0.9, 0.92, 0.9), L * 0.92);
	vec2 c = p - vec2(0.0, -6.0);
	float ilum = 0.92 + 0.12 * exp(-dot(c, c) / 700.0);
	vec2 dj = p - sombra_jog.xy;
	vec2 db = p - sombra_bola.xy;
	float s = 1.0 - 0.6 * sombra_jog.w * exp(-dot(dj, dj) / (sombra_jog.z * sombra_jog.z))
		- 0.7 * sombra_bola.w * exp(-dot(db, db) / (sombra_bola.z * sombra_bola.z));
	ALBEDO = g * ilum * s * luz;
}
