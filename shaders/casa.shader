shader_type spatial;
render_mode cull_disabled;

// CASAS INSTANCIADAS (MultiMesh) da paisagem: a cor da parede vem da cor da
// instância e a do telhado de INSTANCE_CUSTOM; UV.x = 1 marca o telhado.

varying vec3 telhado;
varying float eh_telhado;

void vertex() {
	telhado = INSTANCE_CUSTOM.rgb;
	eh_telhado = UV.x;
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, telhado, eh_telhado);
	ROUGHNESS = mix(0.85, 0.7, eh_telhado);
}
