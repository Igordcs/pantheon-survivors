extends Node2D
class_name BossLineHazard
## Configurable delayed line strike used as a building block by unique boss patterns.

var _player: CharacterBody2D
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _delay := 0.9
var _damage := 24.0
var _width := 28.0
var _slow_multiplier := 1.0
var _slow_duration := 0.0
var _active_color := Color.WHITE
var _resolved := false
var _line: Line2D


func setup(
	player: CharacterBody2D,
	from: Vector2,
	to: Vector2,
	delay: float,
	damage: float,
	width: float,
	telegraph_color: Color,
	active_color: Color,
	slow_multiplier: float = 1.0,
	slow_duration: float = 0.0
) -> void:
	_player = player
	_from = from
	_to = to
	_delay = delay
	_damage = damage
	_width = width
	_slow_multiplier = slow_multiplier
	_slow_duration = slow_duration
	_active_color = active_color
	z_index = 3
	add_to_group(&"boss_hazards")
	_line = Line2D.new()
	_line.width = width
	_line.default_color = telegraph_color
	_line.points = PackedVector2Array([from, to])
	add_child(_line)


func _process(delta: float) -> void:
	_delay -= delta
	if _delay > 0.0 or _resolved:
		return
	_resolved = true
	_line.width = _width * 1.25
	_line.default_color = _active_color
	if is_instance_valid(_player):
		var closest := Geometry2D.get_closest_point_to_segment(_player.global_position, _from, _to)
		if closest.distance_squared_to(_player.global_position) <= pow(_line.width * 0.5, 2.0):
			var health := _player.get_node_or_null("HealthComponent") as HealthComponent
			if health and health.is_alive():
				health.take_damage(_damage, closest)
			if _slow_duration > 0.0 and _player.has_method("apply_temporary_slow"):
				_player.apply_temporary_slow(_slow_multiplier, _slow_duration)
	var tween := create_tween()
	tween.tween_property(_line, "modulate:a", 0.0, 0.28)
	tween.tween_callback(queue_free)
