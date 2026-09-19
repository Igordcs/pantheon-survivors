extends Node2D
class_name BossAreaHazard
## Circular telegraph that can explode once and optionally remain as a damage zone.

var _player: CharacterBody2D
var _radius := 64.0
var _delay := 1.0
var _duration := 0.2
var _activation_damage := 20.0
var _tick_damage := 0.0
var _tick_interval := 0.6
var _tick_timer := 0.0
var _active := false
var _telegraph_color := Color(0.8, 0.15, 0.8, 0.28)
var _active_color := Color(0.9, 0.2, 1.0, 0.58)


func setup(
	player: CharacterBody2D,
	center: Vector2,
	radius: float,
	delay: float,
	activation_damage: float,
	duration: float = 0.2,
	tick_damage: float = 0.0,
	tick_interval: float = 0.6,
	telegraph_color: Color = Color(0.8, 0.15, 0.8, 0.28),
	active_color: Color = Color(0.9, 0.2, 1.0, 0.58)
) -> void:
	_player = player
	global_position = center
	_radius = radius
	_delay = delay
	_activation_damage = activation_damage
	_duration = maxf(duration, 0.12)
	_tick_damage = tick_damage
	_tick_interval = maxf(tick_interval, 0.1)
	_telegraph_color = telegraph_color
	_active_color = active_color
	z_index = 3
	add_to_group(&"boss_hazards")
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		_delay -= delta
		if _delay <= 0.0:
			_active = true
			_tick_timer = _tick_interval
			_damage_player(_activation_damage)
			queue_redraw()
		return

	_duration -= delta
	_tick_timer -= delta
	if _tick_damage > 0.0 and _tick_timer <= 0.0:
		_tick_timer = _tick_interval
		_damage_player(_tick_damage)
	if _duration <= 0.0:
		queue_free()


func _damage_player(amount: float) -> void:
	if amount <= 0.0 or not is_instance_valid(_player):
		return
	if global_position.distance_squared_to(_player.global_position) > _radius * _radius:
		return
	var health := _player.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(amount, global_position)


func _draw() -> void:
	var color := _active_color if _active else _telegraph_color
	draw_circle(Vector2.ZERO, _radius, color)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, color.lightened(0.35), 3.0)
