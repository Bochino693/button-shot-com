shader_type canvas_item;

// Brilho que atravessa o logo uma vez (só onde o logo existe).
uniform float varre = -1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = UV.x + UV.y * 0.45 - varre;
	float faixa = exp(-d * d / 0.003);
	c.rgb += vec3(faixa * 0.6) * c.a;
	COLOR = c * COLOR;
}
