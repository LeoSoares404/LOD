shader_type canvas_item;
// Preenchimento dinâmico sobre a arte HD da orbe: escurece só o LÍQUIDO
// central (círculo) acima da linha de nível, deixando a moldura intacta.
// fill = 0..1 (fração cheia). orb_center/orb_radius = disco do líquido em UV.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec2 orb_center = vec2(0.5, 0.5);
uniform float orb_radius = 0.31;
uniform float empty_dark = 0.25;  // quão escuro fica o líquido vazio

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float d = distance(UV, orb_center);
	float surface = 1.0 - fill;  // y da superfície do líquido
	if (d < orb_radius && UV.y < surface) {
		tex.rgb *= empty_dark;  // acima do nível: líquido drenado
	}
	// linha de brilho na superfície
	if (d < orb_radius && fill > 0.02 && fill < 0.98 && abs(UV.y - surface) < 0.012) {
		tex.rgb = mix(tex.rgb, vec3(1.0), 0.5);
	}
	COLOR = tex;
}
