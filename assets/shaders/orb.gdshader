shader_type canvas_item;
// Orbe de vida/mana estilo Diablo: círculo com "líquido" que enche de baixo
// pra cima conforme o fill (0..1). Cores configuráveis por material.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 liquid_color : source_color = vec4(0.7, 0.1, 0.12, 1.0);
uniform vec4 back_color : source_color = vec4(0.05, 0.07, 0.09, 0.9);
uniform vec4 rim_color : source_color = vec4(0.18, 0.3, 0.32, 1.0);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p);
	if (d > 0.5) {
		discard;
	}
	vec4 col = back_color;
	float surface = 1.0 - fill;
	if (UV.y > surface) {
		col = liquid_color;
		// mais escuro no fundo do líquido (volume)
		col.rgb *= 1.0 - (UV.y - surface) * 0.35;
	}
	// linha de brilho na superfície do líquido
	if (fill > 0.01 && fill < 0.99 && abs(UV.y - surface) < 0.025) {
		col.rgb = mix(col.rgb, vec3(1.0), 0.55);
	}
	// reflexo no vidro (canto superior esquerdo)
	if (distance(UV, vec2(0.35, 0.3)) < 0.08) {
		col.rgb = mix(col.rgb, vec3(1.0), 0.18);
	}
	// aro
	if (d > 0.44) {
		col = rim_color;
	}
	COLOR = col;
}
