extends Node2D
class_name BossJudgmentHazard
## Anubis damages the judgment field while a marked golden circle remains safe.

var _player: CharacterBody2D
var _outer_radius := 410.0
var _safe_center := Vector2.ZERO
var _safe_radius := 82.0
var _delay := 1.25
var _damage := 38.0
var _resolved := false


func setup(
	player: CharacterBody2D,
	center: Vector2,
	safe_center: Vector2,
	delay: float,
	damage: float
) -> void:
	_player = player
	global_position = center
	_safe_center = safe_center
	_delay = delay
	_damage = damage
	z_index = 3
	add_to_group(&"boss_hazards")
	queue_redraw()


func _process(delta: float) -> void:
	_delay -= delta
	if _delay > 0.0 or _resolved:
		return
	_resolved = true
	if is_instance_valid(_player):
		var inside_field := global_position.distance_to(_player.global_position) <= _outer_radius
		var outside_safety := _safe_center.distance_to(_player.global_position) > _safe_radius
		if inside_field and outside_safety:
			var health := _player.get_node_or_null("HealthComponent") as HealthComponent
			if health and health.is_alive():
				health.take_damage(_damage, global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, _outer_radius, Color(0.36, 0.08, 0.42, 0.2))
	draw_arc(Vector2.ZERO, _outer_radius, 0.0, TAU, 80, Color(0.7, 0.2, 0.75, 0.65), 4.0)
	var local_safe := to_local(_safe_center)
	draw_circle(local_safe, _safe_radius, Color(0.95, 0.72, 0.16, 0.38))
	draw_arc(local_safe, _safe_radius, 0.0, TAU, 40, Color(1.0, 0.9, 0.4, 0.92), 4.0)
