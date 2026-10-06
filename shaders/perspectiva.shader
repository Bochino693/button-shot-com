shader_type canvas_item;

// PERSPECTIVA DA MESA: a mesa é desenhada reta num Viewport e aqui cada
// ponto da tela busca o ponto da mesa pela homografia inversa (h0, h1, h2),
// como uma câmera de TV olhando o campo de frente e um pouco de cima.

uniform vec3 h0;
uniform vec3 h1;
uniform vec3 h2;
uniform vec4 fundo : hint_color = vec4(0.02, 0.03, 0.05, 1.0);

void fragment() {
	vec3 p = vec3(UV, 1.0);
	float w = dot(h2, p);
	vec2 t = vec2(dot(h0, p), dot(h1, p)) / w;
	if (t.x < 0.0 || t.x > 1.0 || t.y < 0.0 || t.y > 1.0) {
		COLOR = fundo;
	} else {
		COLOR = texture(TEXTURE, t);
	}
}
