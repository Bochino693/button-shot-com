shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

// BRILHOS (halos dos refletores, estrias de lente, sol, lua, flashes): todos
// num desenho só (MultiMesh). Cada instância traz no transform a posição e o
// tamanho (largura em X, altura em Y) e no dado próprio a cor (pode passar
// de 1). O quadrado fica sempre de frente para a câmera.

uniform sampler2D textura : hint_albedo;

varying vec4 cor;

void vertex() {
	vec3 centro = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 tam = vec2(length(WORLD_MATRIX[0].xyz), length(WORLD_MATRIX[1].xyz));
	VERTEX = centro + vec3(VERTEX.xy * tam, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	cor = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 t = texture(textura, UV);
	ALBEDO = cor.rgb * t.rgb;
	ALPHA = clamp(cor.a * t.a, 0.0, 1.0);
}
