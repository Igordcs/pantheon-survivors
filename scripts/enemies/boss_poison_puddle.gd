extends Node2D
class_name BossPoisonPuddle
## Temporary poison hazard that damages the player at a fixed tick rate.

var radius: float = 68.0
var duration: float = 4.5
var tick_interval: float = 0.55
var damage_per_tick: float = 7.0
var _player: CharacterBody2D
var _tick_timer: float = 0.0
var _initial_duration: float = 1.0


func setup(player: CharacterBody2D, puddle_radius: float, puddle_damage: float) -> void:
	_player = player
	radius = puddle_radius
	damage_per_tick = puddle_damage
	_initial_duration = duration
	queue_redraw()


func _process(delta: float) -> void:
	duration -= delta
	_tick_timer -= delta
	if duration <= 0.0:
		queue_free()
		return
	modulate.a = clampf(duration / minf(_initial_duration, 1.2), 0.0, 1.0)
	if _tick_timer > 0.0 or not is_instance_valid(_player):
		return
	_tick_timer = tick_interval
	if global_position.distance_squared_to(_player.global_position) <= radius * radius:
		var health := _player.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(damage_per_tick, global_position)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.3, 0.7, 0.08, 0.42))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.6, 0.95, 0.12, 0.78), 3.0)
