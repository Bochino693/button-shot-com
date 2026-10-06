// BANDEIRÃO DA TORCIDA: pano nas cores do time com o escudo/logo no meio,
// balançando (onda no tecido + luz e sombra das dobras). TEXTURE = escudo.
// "fase" vem do script dando a volta (a GPU calcula em meia precisão).
shader_type canvas_item;

uniform vec4 cor1 : hint_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform vec4 cor2 : hint_color = vec4(0.0, 0.6, 0.2, 1.0);
uniform float fase = 0.0;
uniform float forca = 1.0;
uniform float aspecto = 0.6;   // largura / altura do bandeirão

void fragment() {
	float onda = sin(UV.y * 9.0 - fase + UV.x * 2.5);
	vec2 uv = UV + vec2(onda * 0.025 * forca, cos(UV.y * 7.0 - fase) * 0.01 * forca);
	vec3 pano = cor1.rgb;
	float faixa = step(0.86, uv.y) + step(uv.y, 0.14);
	pano = mix(pano, cor2.rgb, clamp(faixa, 0.0, 1.0));
	// escudo no meio (quadrado com o lado de 80% da largura)
	vec2 e = vec2((uv.x - 0.5) / 0.8 + 0.5, (uv.y - 0.5) * (1.0 / aspecto) / 0.8 + 0.5);
	vec4 esc = texture(TEXTURE, e);
	float dentro = step(0.0, e.x) * step(e.x, 1.0) * step(0.0, e.y) * step(e.y, 1.0);
	pano = mix(pano, esc.rgb, esc.a * dentro);
	float luz = 0.82 + 0.28 * onda * forca;
	float borda = step(0.02, uv.x) * step(uv.x, 0.98);
	COLOR = vec4(pano * luz, borda);
}
