shader_type spatial;
render_mode unshaded;

// MAR / RIO / FIORDE: cor funda, reflexo do céu na borda (fresnel), ondas
// mexendo e o brilho do sol (ou da lua) refletido na água.

uniform vec4 funda : hint_color = vec4(0.04, 0.2, 0.3, 1.0);
uniform vec4 ceu : hint_color = vec4(0.55, 0.7, 0.85, 1.0);
uniform vec4 cor_astro : hint_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform vec3 astro = vec3(0.0, 0.3, -1.0);
uniform float brilho = 1.0;

varying vec3 w;

void vertex() {
	w = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cam = CAMERA_MATRIX[3].xyz;
	vec3 v = normalize(w - cam);
	float t = mod(TIME, 600.0);
	vec3 n = normalize(vec3(sin(w.x * 0.21 + t * 0.9) * 0.04 + sin(w.z * 0.37 - t * 1.3) * 0.03,
		1.0, cos(w.z * 0.18 + t * 0.7) * 0.04 + sin((w.x + w.z) * 0.5 + t * 1.7) * 0.02));
	float fres = pow(1.0 - abs(v.y), 3.0);
	vec3 r = reflect(v, n);
	float g = pow(max(dot(r, normalize(astro)), 0.0), 90.0);
	vec3 c = mix(funda.rgb, ceu.rgb, clamp(fres * 0.85 + 0.1, 0.0, 1.0));
	c += cor_astro.rgb * g * 2.5 * brilho;
	ALBEDO = c;
}
