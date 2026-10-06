shader_type spatial;
render_mode unshaded, cull_disabled;

// BANDEIRÃO 3D estendido na arquibancada: faixas nas cores do time, o escudo
// no meio e o pano ondulando (o vértice sobe e desce).

uniform sampler2D emblema;
uniform vec4 cor1 : hint_color;
uniform vec4 cor2 : hint_color;
uniform float fase = 0.0;
uniform float aspecto = 1.6;
uniform float luz = 1.0;
uniform float forca = 1.0;

varying float onda;

void vertex() {
	onda = sin(UV.x * 7.0 + TIME * 2.6 + fase) * 0.6 + sin(UV.y * 5.0 + TIME * 1.9 + fase * 1.7) * 0.4;
	// o pano só ondula para FORA (para o gramado): nunca entra na torcida
	VERTEX.z += (onda * 0.5 + 0.5) * 0.6 * forca;
}

void fragment() {
	vec3 c = mix(cor1.rgb, cor2.rgb, step(0.5, fract(UV.y * 2.5)));
	vec2 e = (UV - vec2(0.5)) * vec2(aspecto, 1.0) / 0.8 + vec2(0.5);
	if (e.x > 0.0 && e.x < 1.0 && e.y > 0.0 && e.y < 1.0) {
		vec4 t = texture(emblema, e);
		c = mix(c, t.rgb, t.a);
	}
	ALBEDO = c * (0.78 + 0.22 * onda) * luz;
}
