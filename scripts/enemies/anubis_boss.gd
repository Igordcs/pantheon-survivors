extends DirectionalBoss
## Anubis alternates spatial judgment, spectral gates and a slowing burial curse.

enum Attack { WEIGHING_OF_THE_HEART, GATES_OF_DUAT, MUMMIFICATION_SEAL }
enum State { CHASING, TELEGRAPHING, RECOVERING }

@export var attack_cooldown := 3.8
@export var telegraph_duration := 1.1

var _state := State.CHASING
var _state_timer := 2.4
var _attack := Attack.WEIGHING_OF_THE_HEART
var _last_attack := -1
var _target_position := Vector2.ZERO
var _cast_direction := Vector2.DOWN
var _gate_origins: Array[Vector2] = []
var _telegraphs: Array[CanvasItem] = []
var _hazards: Array[Node] = []


func _tick_behavior(delta: float) -> void:
	_state_timer -= delta
	match _state:
		State.CHASING:
			chase_player(1.08 if _is_second_phase() else 1.0)
			if _state_timer <= 0.0:
				_start_attack()
		State.TELEGRAPHING:
			stop_movement()
			if _state_timer <= 0.0:
				_execute_attack()
		State.RECOVERING:
			stop_movement()
			if _state_timer <= 0.0:
				_state = State.CHASING
				_state_timer = 3.0 if _is_second_phase() else attack_cooldown


func _start_attack() -> void:
	var next_attack := randi_range(Attack.WEIGHING_OF_THE_HEART, Attack.MUMMIFICATION_SEAL)
	while next_attack == _last_attack:
		next_attack = randi_range(Attack.WEIGHING_OF_THE_HEART, Attack.MUMMIFICATION_SEAL)
	_attack = next_attack
	_last_attack = next_attack
	_target_position = get_player().global_position
	_cast_direction = global_position.direction_to(_target_position)
	_state = State.TELEGRAPHING
	_state_timer = 1.25 if _attack == Attack.WEIGHING_OF_THE_HEART else telegraph_duration
	match _attack:
		Attack.WEIGHING_OF_THE_HEART: _prepare_weighing()
		Attack.GATES_OF_DUAT: _prepare_gates()
		Attack.MUMMIFICATION_SEAL: _prepare_mummification()


func _prepare_weighing() -> void:
	var side := -1.0 if randi() % 2 == 0 else 1.0
	var safe_center := _target_position + _cast_direction.rotated(PI * 0.5) * 125.0 * side
	var judgment := BossJudgmentHazard.new()
	get_tree().current_scene.add_child(judgment)
	judgment.setup(get_player(), global_position, safe_center, _state_timer, 40.0)
	_hazards.append(judgment)


func _prepare_gates() -> void:
	_gate_origins.clear()
	var count := 6 if _is_second_phase() else 4
	for index in range(count):
		var origin := _target_position + Vector2.from_angle(TAU * float(index) / float(count)) * 330.0
		_gate_origins.append(origin)
		var marker := Polygon2D.new()
		marker.polygon = _circle_points(30.0)
		marker.color = Color(0.72, 0.48, 0.12, 0.36)
		marker.global_position = origin
		_add_telegraph(marker)
	if _is_second_phase():
		_add_mummification_cone(Color(0.55, 0.15, 0.7, 0.2))


func _prepare_mummification() -> void:
	_add_mummification_cone(Color(0.72, 0.55, 0.18, 0.3))


func _add_mummification_cone(color: Color) -> void:
	var cone := Polygon2D.new()
	cone.polygon = _cone_points(330.0, deg_to_rad(17.0))
	cone.rotation = _cast_direction.angle()
	cone.color = color
	cone.global_position = global_position
	_add_telegraph(cone)


func _execute_attack() -> void:
	_clear_telegraphs()
	match _attack:
		Attack.WEIGHING_OF_THE_HEART:
			pass
		Attack.GATES_OF_DUAT:
			_fire_gates()
			if _is_second_phase():
				_execute_mummification(22.0)
		Attack.MUMMIFICATION_SEAL:
			_execute_mummification(34.0)
	_state = State.RECOVERING
	_state_timer = 0.65


func _fire_gates() -> void:
	for origin in _gate_origins:
		var projectile := BossMagicProjectile.new()
		get_tree().current_scene.add_child(projectile)
		projectile.setup(
			get_player(), origin, origin.direction_to(_target_position), 310.0,
			20.0 if _is_second_phase() else 17.0, 720.0, Color(0.95, 0.66, 0.18)
		)
		_hazards.append(projectile)
	_gate_origins.clear()


func _execute_mummification(damage: float) -> void:
	var offset := get_player().global_position - global_position
	var in_range := offset.length_squared() <= 330.0 * 330.0
	var in_cone := offset.is_zero_approx() or _cast_direction.dot(offset.normalized()) >= cos(deg_to_rad(17.0))
	if in_range and in_cone:
		damage_player(damage)
		if get_player().has_method("apply_temporary_slow"):
			get_player().apply_temporary_slow(0.58, 2.0)


func _add_telegraph(item: CanvasItem) -> void:
	item.z_index = 3
	get_tree().current_scene.add_child(item)
	_telegraphs.append(item)


func _clear_telegraphs() -> void:
	for item in _telegraphs:
		if is_instance_valid(item):
			item.queue_free()
	_telegraphs.clear()


func _is_second_phase() -> bool:
	return health_component.current_health <= health_component.max_health * 0.5


func _cleanup_behavior() -> void:
	_clear_telegraphs()
	for hazard in _hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	_hazards.clear()


func _circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(32):
		points.append(Vector2.from_angle(TAU * float(index) / 32.0) * radius)
	return points


func _cone_points(distance: float, half_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(17):
		var angle := lerpf(-half_angle, half_angle, float(index) / 16.0)
		points.append(Vector2.from_angle(angle) * distance)
	return points
