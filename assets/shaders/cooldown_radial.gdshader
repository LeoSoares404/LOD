shader_type canvas_item;
// Overlay de cooldown radial (sentido horário a partir do topo).
// progress = fração RESTANTE do cooldown (1 = acabou de usar, 0 = pronto).

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float ang = atan(p.x, -p.y);            // 0 no topo, cresce em sentido horário
	float t = ang < 0.0 ? ang + TAU : ang;
	t /= TAU;
	float a = (progress > 0.001 && t < progress) ? 0.65 : 0.0;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
