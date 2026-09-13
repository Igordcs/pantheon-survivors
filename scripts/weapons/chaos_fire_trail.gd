extends Node2D
class_name ChaosFireTrail
## One-second burning corridor left by a Blade of Chaos impact.

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _damage := 6.0
var _duration := 1.0
var _tick_timer := 0.0
var _width := 34.0


func setup(from: Vector2, to: Vector2, damage: float, width: float = 34.0) -> void:
	_from = from
	_to = to
	_damage = damage
	_width = width
	z_index = 2
	queue_redraw()


func _process(delta: float) -> void:
	_duration -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = 0.25
		_damage_enemies()
	queue_redraw()
	if _duration <= 0.0:
		queue_free()


func _damage_enemies() -> void:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		var enemy := candidate as Node2D
		if not enemy.visible or enemy.is_queued_for_deletion():
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, _from, _to)
		if closest.distance_squared_to(enemy.global_position) > (_width * 0.5) ** 2:
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(_damage, closest)


func _draw() -> void:
	var alpha := clampf(_duration, 0.0, 1.0)
	var time := Time.get_ticks_msec() * 0.001
	# Scorched ground, outer heat and a bright molten center create depth.
	draw_line(_from, _to, Color(0.08, 0.015, 0.008, 0.62 * alpha), _width * 1.18)
	draw_line(_from, _to, Color(0.55, 0.035, 0.008, 0.42 * alpha), _width)
	draw_line(_from, _to, Color(1.0, 0.16, 0.015, 0.74 * alpha), _width * 0.58)
	draw_line(_from, _to, Color(1.0, 0.72, 0.12, 0.9 * alpha), 3.0)
	var length := _from.distance_to(_to)
	var direction := _from.direction_to(_to)
	var perpendicular := direction.orthogonal()
	var flame_count := maxi(3, int(length / 22.0))
	for index in range(flame_count):
		var progress := (float(index) + 0.5) / float(flame_count)
		var lateral := sin(float(index) * 2.37 + time * 7.0) * _width * 0.24
		var base := _from.lerp(_to, progress) + perpendicular * lateral
		var sway := sin(time * 11.0 + float(index) * 1.71) * 5.0
		var flame_height := 14.0 + sin(time * 8.0 + float(index) * 2.1) * 5.0
		var outer_flame := PackedVector2Array([
			base - perpendicular * 7.0,
			base + perpendicular * 7.0,
			base - Vector2(0.0, flame_height * 0.58) + perpendicular * sway,
			base - Vector2(0.0, flame_height),
		])
		draw_colored_polygon(outer_flame, Color(0.95, 0.12, 0.015, 0.82 * alpha))
		var inner_flame := PackedVector2Array([
			base - perpendicular * 3.5,
			base + perpendicular * 3.5,
			base - Vector2(0.0, flame_height * 0.67) + perpendicular * sway * 0.35,
		])
		draw_colored_polygon(inner_flame, Color(1.0, 0.72, 0.12, 0.94 * alpha))
		# Rising embers alternate sides and fade before the flame disappears.
		var ember := base - Vector2(0.0, flame_height + 7.0 + fmod(time * 28.0 + index * 5.0, 13.0))
		ember += perpendicular * sin(time * 5.0 + index) * 8.0
		draw_circle(ember, 1.5, Color(1.0, 0.84, 0.32, 0.85 * alpha))
