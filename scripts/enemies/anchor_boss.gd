extends DirectionalBoss
class_name AnchorBoss
## Comportamento compartilhado pelos bosses direcionais adicionados à campanha.
## Eles perseguem o jogador e descarregam uma onda circular bem telegrafada.

enum State { CHASING, TELEGRAPHING, RECOVERING }

@export var attack_cooldown: float = 3.8
@export var telegraph_duration: float = 0.9
@export var pulse_damage: float = 30.0
@export var pulse_radius: float = 140.0
@export var chase_speed_multiplier: float = 1.0

var _state := State.CHASING
var _state_timer: float = 2.0
var _telegraph: Polygon2D


func _tick_behavior(delta: float) -> void:
	_state_timer -= delta
	match _state:
		State.CHASING:
			chase_player(chase_speed_multiplier)
			if _state_timer <= 0.0:
				_start_pulse()
		State.TELEGRAPHING:
			stop_movement()
			if _state_timer <= 0.0:
				_execute_pulse()
		State.RECOVERING:
			stop_movement()
			if _state_timer <= 0.0:
				_state = State.CHASING
				_state_timer = attack_cooldown


func _start_pulse() -> void:
	_state = State.TELEGRAPHING
	_state_timer = telegraph_duration
	_telegraph = Polygon2D.new()
	_telegraph.polygon = _build_circle_polygon(pulse_radius)
	_telegraph.color = Color(0.9, 0.2, 0.12, 0.28)
	_telegraph.z_index = 3
	get_tree().current_scene.add_child(_telegraph)
	_telegraph.global_position = global_position


func _execute_pulse() -> void:
	if is_player_inside_radius(global_position, pulse_radius):
		damage_player(pulse_damage)
	if is_instance_valid(_telegraph):
		_telegraph.color = Color(1.0, 0.35, 0.12, 0.82)
		var tween := _telegraph.create_tween()
		tween.tween_property(_telegraph, "modulate:a", 0.0, 0.4)
		tween.tween_callback(_telegraph.queue_free)
	_telegraph = null
	_state = State.RECOVERING
	_state_timer = 0.55


func _cleanup_behavior() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _build_circle_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(32):
		points.append(Vector2.from_angle(TAU * float(index) / 32.0) * radius)
	return points
