extends Node2D
class_name FenrirLineHazard
## One delayed Gleipnir rupture with a visible safe telegraph.

var _player: CharacterBody2D
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _delay := 1.15
var _damage := 24.0
var _resolved := false
var _line: Line2D


func setup(player: CharacterBody2D, from: Vector2, to: Vector2, delay: float) -> void:
	_player = player
	_from = from
	_to = to
	_delay = delay
	z_index = 3
	_line = Line2D.new()
	_line.width = 22.0
	_line.default_color = Color(0.76, 0.52, 0.12, 0.3)
	_line.points = PackedVector2Array([from, to])
	add_child(_line)


func _process(delta: float) -> void:
	_delay -= delta
	if _delay > 0.0 or _resolved:
		return
	_resolved = true
	_line.width = 30.0
	_line.default_color = Color(0.9, 0.25, 1.0, 0.92)
	if is_instance_valid(_player):
		var closest := Geometry2D.get_closest_point_to_segment(_player.global_position, _from, _to)
		if closest.distance_squared_to(_player.global_position) <= 15.0 * 15.0:
			var health := _player.get_node_or_null("HealthComponent") as HealthComponent
			if health and health.is_alive():
				health.take_damage(_damage, closest)
	var tween := create_tween()
	tween.tween_property(_line, "modulate:a", 0.0, 0.28)
	tween.tween_callback(queue_free)
