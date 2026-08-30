shader_type canvas_item;

uniform vec4 damage_color : source_color = vec4(0.72, 0.025, 0.035, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float edge_start : hint_range(0.0, 1.0) = 0.72;


void fragment() {
	vec2 distance_from_center = abs(UV - vec2(0.5)) * 2.0;
	float nearest_edge = max(distance_from_center.x, distance_from_center.y);
	float soft_border = smoothstep(edge_start, 1.0, nearest_edge);
	soft_border = pow(soft_border, 1.35);
	COLOR = vec4(damage_color.rgb, damage_color.a * soft_border * intensity);
}
