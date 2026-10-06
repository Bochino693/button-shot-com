shader_type spatial;

// CHÃO DA CIDADE em volta do estádio 3D: ruas de asfalto em grade (faixa
// tracejada no meio, faixa de pedestre perto dos cruzamentos), calçadas,
// quarteirões (grama e piso) e, longe do centro, campos e mato. De noite,
// os postes deixam poças de luz amarela nas calçadas; na chuva o asfalto
// fica molhado (brilha). Tudo em coordenadas do mundo (sem textura).
// De longe a grade vira a cor média (sem cintilar).

uniform vec4 cor_campo : hint_color = vec4(0.36, 0.42, 0.3, 1.0);
uniform vec4 cor_quadra : hint_color = vec4(0.42, 0.46, 0.36, 1.0);
uniform float quadra = 80.0;          // distância entre ruas (m)
uniform float rua = 14.0;             // largura do asfalto
uniform float calcada = 3.5;
uniform float raio_cidade = 760.0;    // até onde vai a grade de ruas
uniform float noite = 0.0;
uniform float chuva = 0.0;

varying vec3 w;

void vertex() {
	w = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

float fbm(vec2 p) {
	return ruido(p) * 0.55 + ruido(p * 2.1 + 3.7) * 0.3 + ruido(p * 4.3 + 9.1) * 0.15;
}

void fragment() {
	vec2 p = w.xz;
	// distância até o eixo da rua mais perto em x e em z
	vec2 g = p / quadra;
	vec2 dq = abs(fract(g + 0.5) - 0.5) * quadra;     // 0 = no eixo da rua
	vec2 id = floor(g + 0.5);
	float meia = rua * 0.5;
	float aa = max(fwidth(p.x), fwidth(p.y));
	float longe = smoothstep(1.5, 6.0, aa);
	// é rua? é calçada?
	float na_rua = 1.0 - smoothstep(meia - aa, meia + aa, min(dq.x, dq.y));
	float na_calc = (1.0 - smoothstep(meia + calcada - aa, meia + calcada + aa, min(dq.x, dq.y))) * (1.0 - na_rua);
	// a grade some ao longe da cidade (bordas irregulares)
	float r = length(p) + (fbm(p * 0.004) - 0.5) * 260.0;
	float cidade = 1.0 - smoothstep(raio_cidade - 120.0, raio_cidade + 60.0, r);
	// asfalto com remendos
	vec3 asfalto = vec3(0.16, 0.165, 0.175) * (0.85 + 0.3 * fbm(p * 0.35));
	// faixa tracejada no meio da rua (fora do cruzamento) e faixa de pedestre
	float cruz = step(min(dq.x, dq.y), meia) * step(max(dq.x, dq.y), meia);   // cruzamento
	float eixo_z = step(dq.x, 0.18) * step(0.5, fract(p.y / 7.0));             // rua ao longo de z
	float eixo_x = step(dq.y, 0.18) * step(0.5, fract(p.x / 7.0));
	float faixa = max(eixo_z * step(meia + 4.0, dq.y), eixo_x * step(meia + 4.0, dq.x));
	float zebra_z = step(dq.x, meia - 0.8) * step(meia + 0.6, dq.y) * step(dq.y, meia + 3.4) * step(0.5, fract(p.x / 1.2));
	float zebra_x = step(dq.y, meia - 0.8) * step(meia + 0.6, dq.x) * step(dq.x, meia + 3.4) * step(0.5, fract(p.y / 1.2));
	float pintura = max(faixa, max(zebra_z, zebra_x)) * (1.0 - cruz) * (1.0 - longe);
	vec3 c_rua = mix(asfalto, vec3(0.86, 0.84, 0.74), pintura * 0.85);
	// calçada (concreto com juntas)
	vec2 junta = abs(fract(p / 2.0) - 0.5);
	vec3 c_calc = vec3(0.6, 0.59, 0.56) * (0.92 + 0.08 * step(0.06, min(junta.x, junta.y)));
	// miolo do quarteirão: grama, terra e piso misturados por quarteirão
	float h = hash(id * 1.31 + 0.7);
	vec3 grama = cor_quadra.rgb * (0.82 + 0.3 * fbm(p * 0.08));
	vec3 piso = vec3(0.55, 0.53, 0.5) * (0.9 + 0.15 * fbm(p * 0.2));
	vec3 c_quadra = mix(grama * 0.85, piso * 0.85, step(0.75, h) * 0.7);
	vec3 urbano = mix(mix(c_quadra, c_calc, na_calc), c_rua, na_rua);
	// média de longe (sem cintilar)
	vec3 media = mix(c_quadra, asfalto, 0.32);
	urbano = mix(urbano, media, longe);
	// campos fora da cidade: retalhos de plantação e mato
	vec2 lote = floor(p / vec2(110.0, 70.0));
	float hl = hash(lote);
	vec3 campo = cor_campo.rgb * (0.78 + 0.35 * fbm(p * 0.01)) * (0.85 + 0.3 * hl);
	campo = mix(campo, campo * vec3(1.15, 1.05, 0.7), step(0.7, hl));
	vec3 cor = mix(campo, urbano, cidade);
	float rua_final = na_rua * cidade * (1.0 - longe);
	// chuva: asfalto molhado escuro e brilhante
	cor *= 1.0 - 0.25 * chuva * rua_final;
	ALBEDO = cor;
	ROUGHNESS = mix(0.95, mix(0.75, 0.18, chuva), rua_final);
	SPECULAR = mix(0.2, 0.6, rua_final * chuva);
	// noite: poças de luz dos postes ao longo das calçadas
	if (noite > 0.0) {
		vec2 ao_longo = vec2(fract(p.y / 28.0) - 0.5, fract(p.x / 28.0) - 0.5) * 28.0;
		float poste_z = exp(-pow(dq.x - meia, 2.0) / 30.0 - ao_longo.x * ao_longo.x / 40.0);
		float poste_x = exp(-pow(dq.y - meia, 2.0) / 30.0 - ao_longo.y * ao_longo.y / 40.0);
		float luz = max(poste_z, poste_x) * cidade;
		luz = mix(luz, 0.18 * cidade, longe);
		EMISSION = vec3(1.0, 0.72, 0.38) * luz * 0.55 * noite;
	}
}
