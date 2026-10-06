shader_type spatial;

// CARROS DA CIDADE (MultiMesh): cada carro anda sozinho pela sua quadra de
// rua, sem custo de CPU. INSTANCE_CUSTOM = (velocidade m/s, comprimento do
// trecho, fase, -). O carro anda no seu -Z local, some encolhendo no fim
// do trecho e reaparece no começo (no cruzamento, sem "pulo").
// Cor da lataria = cor da instância; UV.x marca farol (1) e lanterna (2).

uniform float noite = 0.0;

varying float farol;
varying float lanterna;

void vertex() {
	float vel = INSTANCE_CUSTOM.x;
	float comp = INSTANCE_CUSTOM.y;
	float d = mod(TIME * vel + INSTANCE_CUSTOM.z, comp);
	float k = smoothstep(0.0, 4.0, d) * (1.0 - smoothstep(comp - 4.0, comp, d));
	VERTEX *= k;
	VERTEX.z -= d - comp * 0.5;
	farol = step(0.5, UV.x) * step(UV.x, 1.5);
	lanterna = step(1.5, UV.x);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
	EMISSION = (vec3(1.0, 0.95, 0.8) * farol * 2.5 + vec3(1.0, 0.1, 0.05) * lanterna * 1.5) * noite;
}
