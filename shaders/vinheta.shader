shader_type canvas_item;

// Vinheta de cinema (cantos escuros).
uniform float forca = 0.6;

void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.25, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.32, 0.85, length(d)) * forca);
}
