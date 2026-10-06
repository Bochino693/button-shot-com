shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// FACHO DE LUZ DO REFLETOR (cone aditivo): bordas que somem suaves (o lado
// visto de raspão quase não soma), forte perto da lâmpada e sumindo antes
// do chão, sem a "tampa" do cone. Nada de contorno duro cortando a tela.

uniform vec4 cor : hint_color = vec4(0.95, 0.92, 0.82, 1.0);
uniform float forca = 0.05;
uniform float altura = 50.0;          // comprimento do cone (malha em pé, centrada)

varying float v;                     // 0 no chão, 1 na lâmpada

void vertex() {
	v = clamp(VERTEX.y / altura + 0.5, 0.0, 1.0);
}

void fragment() {
	float frente = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = forca * frente * frente;
	a *= (0.3 + 0.7 * v) * smoothstep(0.0, 0.35, v) * (1.0 - smoothstep(0.93, 1.0, v));
	// perto da câmera (ou com ela dentro do cone) o facho some: sem véu na tela
	a *= smoothstep(25.0, 90.0, length(VERTEX));
	ALBEDO = cor.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
