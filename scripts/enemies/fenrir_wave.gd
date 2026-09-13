extends Node2D
class_name FenrirWave
## Expanding ring hazard; the hollow center remains safe after the ring passes.

var _player: CharacterBody2D
var _radius := 90.0
var _max_radius := 300.0
var _speed := 330.0
var _thickness := 32.0
var _damage := 20.0
var _delay := 0.0
var _slow_multiplier := 1.0
var _slow_duration := 0.0
var _hit := false


func setup(player: CharacterBody2D, center: Vector2, max_radius: float, delay: float, apply_slow: bool) -> void:
	_player = player
	global_position = center
	_max_radius = max_radius
	_delay = delay
	if apply_slow:
		_slow_multiplier = 0.85
		_slow_duration = 1.5
	z_index = 4
	queue_redraw()


func _process(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		return
	_radius += _speed * delta
	queue_redraw()
	if not _hit and is_instance_valid(_player):
		var distance := global_position.distance_to(_player.global_position)
		if absf(distance - _radius) <= _thickness * 0.5:
			_hit = true
			var health := _player.get_node_or_null("HealthComponent") as HealthComponent
			if health and health.is_alive():
				health.take_damage(_damage, global_position)
			if _slow_duration > 0.0 and _player.has_method("apply_temporary_slow"):
				_player.apply_temporary_slow(_slow_multiplier, _slow_duration)
	if _radius >= _max_radius:
		queue_free()


func _draw() -> void:
	if _delay > 0.0:
		return
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 72, Color(0.72, 0.2, 0.86, 0.72), _thickness)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 72, Color(1.0, 0.78, 0.24, 0.9), 5.0)
