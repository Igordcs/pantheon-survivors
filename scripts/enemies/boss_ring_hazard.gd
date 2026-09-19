extends Node2D
class_name BossRingHazard
## Delayed annular attack. An optional angular opening provides a readable escape route.

var _player: CharacterBody2D
var _inner_radius := 90.0
var _outer_radius := 240.0
var _delay := 1.0
var _damage := 28.0
var _safe_angle := 0.0
var _safe_half_angle := 0.0
var _color := Color(0.7, 0.15, 0.85, 0.3)
var _resolved := false


func setup(
	player: CharacterBody2D,
	center: Vector2,
	inner_radius: float,
	outer_radius: float,
	delay: float,
	damage: float,
	color: Color,
	safe_direction: Vector2 = Vector2.ZERO,
	safe_arc_degrees: float = 0.0
) -> void:
	_player = player
	global_position = center
	_inner_radius = inner_radius
	_outer_radius = outer_radius
	_delay = delay
	_damage = damage
	_color = color
	_safe_angle = safe_direction.angle()
	_safe_half_angle = deg_to_rad(safe_arc_degrees) * 0.5
	z_index = 3
	add_to_group(&"boss_hazards")
	queue_redraw()


func _process(delta: float) -> void:
	_delay -= delta
	if _delay > 0.0 or _resolved:
		return
	_resolved = true
	if _is_player_in_danger():
		var health := _player.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(_damage, global_position)
	_color = Color(_color.r, _color.g, _color.b, 0.9)
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.32)
	tween.tween_callback(queue_free)


func _is_player_in_danger() -> bool:
	if not is_instance_valid(_player):
		return false
	var offset := _player.global_position - global_position
	var distance := offset.length()
	if distance < _inner_radius or distance > _outer_radius:
		return false
	if _safe_half_angle <= 0.0:
		return true
	return absf(wrapf(offset.angle() - _safe_angle, -PI, PI)) > _safe_half_angle


func _draw() -> void:
	var middle_radius := (_inner_radius + _outer_radius) * 0.5
	var width := _outer_radius - _inner_radius
	if _safe_half_angle <= 0.0:
		draw_arc(Vector2.ZERO, middle_radius, 0.0, TAU, 80, _color, width)
	else:
		var start := _safe_angle + _safe_half_angle
		var end := _safe_angle - _safe_half_angle + TAU
		draw_arc(Vector2.ZERO, middle_radius, start, end, 72, _color, width)
	draw_arc(Vector2.ZERO, _inner_radius, 0.0, TAU, 64, _color.lightened(0.35), 3.0)
	draw_arc(Vector2.ZERO, _outer_radius, 0.0, TAU, 64, _color.lightened(0.35), 3.0)
