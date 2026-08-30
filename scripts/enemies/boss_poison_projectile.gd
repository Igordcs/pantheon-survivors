extends Node2D
class_name BossPoisonProjectile
## Arcing poison projectile that creates a temporary damaging puddle on impact.

var _player: CharacterBody2D
var _start_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _travel_duration: float = 0.75
var _elapsed: float = 0.0
var _impact_damage: float = 12.0
var _puddle_damage: float = 7.0
var _puddle_radius: float = 68.0


func setup(
	player: CharacterBody2D,
	start_position: Vector2,
	target_position: Vector2,
	impact_damage: float,
	puddle_damage: float,
	puddle_radius: float
) -> void:
	_player = player
	_start_position = start_position
	_target_position = target_position
	_impact_damage = impact_damage
	_puddle_damage = puddle_damage
	_puddle_radius = puddle_radius
	global_position = start_position
	z_index = 5
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / _travel_duration, 0.0, 1.0)
	var arc_height := sin(progress * PI) * 54.0
	global_position = _start_position.lerp(_target_position, progress) + Vector2.UP * arc_height
	if progress >= 1.0:
		_impact()


func _impact() -> void:
	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= 34.0:
		var health := _player.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(_impact_damage, global_position)

	var puddle := BossPoisonPuddle.new()
	get_tree().current_scene.add_child(puddle)
	puddle.global_position = _target_position
	puddle.z_index = 2
	puddle.setup(_player, _puddle_radius, _puddle_damage)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(0.55, 0.95, 0.08, 0.95))
	draw_circle(Vector2.ZERO, 6.0, Color(0.18, 0.38, 0.04, 1.0))
