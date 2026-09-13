extends DirectionalBoss
## Final boss with four telegraphed attacks and a faster second phase.

enum Attack { DEVOURING_CHARGE, GLEIPNIR_RUPTURE, HOWL_OF_RAGNAROK, MOON_HUNT }
enum State { CHASING, TELEGRAPHING, CHARGING, MOON_HUNT, RECOVERING }

@export var charge_damage := 42.0
@export var charge_speed := 440.0
@export var charge_distance := 520.0
@export var attack_cooldown := 3.6

var _state := State.CHASING
var _state_timer := 2.5
var _attack := Attack.DEVOURING_CHARGE
var _last_attack := -1
var _charge_direction := Vector2.DOWN
var _charge_remaining := 0.0
var _telegraphs: Array[CanvasItem] = []
var _hazards: Array[Node] = []
var _moon_targets: Array[Vector2] = []
var _moon_index := 0


func _tick_behavior(delta: float) -> void:
	_state_timer -= delta
	match _state:
		State.CHASING:
			chase_player(1.12 if _is_second_phase() else 1.0)
			if _state_timer <= 0.0:
				_start_attack()
		State.TELEGRAPHING:
			stop_movement()
			if _state_timer <= 0.0:
				_execute_attack()
		State.CHARGING:
			velocity = _charge_direction * charge_speed
			var before := global_position
			move_and_slide()
			_charge_remaining -= before.distance_to(global_position)
			_apply_direction(_charge_direction)
			if _charge_remaining <= 0.0:
				_enter_recovery(0.65)
		State.MOON_HUNT:
			stop_movement()
			if _state_timer <= 0.0:
				_execute_next_moon_jump()
		State.RECOVERING:
			stop_movement()
			if _state_timer <= 0.0:
				_state = State.CHASING
				_state_timer = 3.0 if _is_second_phase() else attack_cooldown


func _start_attack() -> void:
	var maximum := Attack.MOON_HUNT if _is_second_phase() else Attack.HOWL_OF_RAGNAROK
	var next_attack := randi_range(Attack.DEVOURING_CHARGE, maximum)
	while next_attack == _last_attack:
		next_attack = randi_range(Attack.DEVOURING_CHARGE, maximum)
	_attack = next_attack
	_last_attack = next_attack
	_state = State.TELEGRAPHING
	_state_timer = 0.8 if _attack == Attack.MOON_HUNT else (0.9 if _attack == Attack.DEVOURING_CHARGE else 1.15)
	match _attack:
		Attack.DEVOURING_CHARGE: _prepare_charge()
		Attack.GLEIPNIR_RUPTURE: _prepare_gleipnir()
		Attack.HOWL_OF_RAGNAROK: _prepare_howl()
		Attack.MOON_HUNT: _prepare_moon_hunt()


func _prepare_charge() -> void:
	_charge_direction = global_position.direction_to(get_player().global_position)
	_apply_direction(_charge_direction)
	var line := Line2D.new()
	line.width = 90.0
	line.default_color = Color(0.8, 0.12, 0.18, 0.25)
	line.points = PackedVector2Array([global_position, global_position + _charge_direction * charge_distance])
	_add_telegraph(line)


func _prepare_gleipnir() -> void:
	var center := get_player().global_position
	for index in range(6):
		var direction := Vector2.from_angle(TAU * float(index) / 6.0)
		var hazard := FenrirLineHazard.new()
		get_tree().current_scene.add_child(hazard)
		hazard.setup(get_player(), center - direction * 300.0, center + direction * 300.0, 1.15 + index * 0.12)
		_hazards.append(hazard)


func _prepare_howl() -> void:
	var circle := Polygon2D.new()
	circle.polygon = _circle_points(90.0)
	circle.color = Color(0.65, 0.15, 0.8, 0.26)
	circle.global_position = global_position
	_add_telegraph(circle)


func _prepare_moon_hunt() -> void:
	_moon_targets.clear()
	var center := get_player().global_position
	for index in range(3):
		var target := center + Vector2.from_angle(TAU * float(index) / 3.0 + randf_range(-0.25, 0.25)) * 115.0
		_moon_targets.append(target)
		var marker := Polygon2D.new()
		marker.polygon = _circle_points(75.0)
		marker.color = Color(0.72, 0.2, 0.82, 0.3)
		marker.global_position = target
		_add_telegraph(marker)


func _execute_attack() -> void:
	_clear_telegraphs()
	match _attack:
		Attack.DEVOURING_CHARGE:
			_state = State.CHARGING
			_charge_remaining = charge_distance
		Attack.GLEIPNIR_RUPTURE:
			_enter_recovery(0.55)
		Attack.HOWL_OF_RAGNAROK:
			_spawn_howl_waves()
			_enter_recovery(0.65)
		Attack.MOON_HUNT:
			_state = State.MOON_HUNT
			_moon_index = 0
			_state_timer = 0.01


func _execute_next_moon_jump() -> void:
	if _moon_index >= _moon_targets.size():
		_enter_recovery(0.8)
		return
	var target := _moon_targets[_moon_index]
	global_position = target
	if is_player_inside_radius(target, 75.0):
		damage_player(28.0, target)
	_moon_index += 1
	_state_timer = 0.24


func _spawn_howl_waves() -> void:
	var first := FenrirWave.new()
	get_tree().current_scene.add_child(first)
	first.setup(get_player(), global_position, 300.0, 0.0, false)
	_hazards.append(first)
	var second := FenrirWave.new()
	get_tree().current_scene.add_child(second)
	second.setup(get_player(), global_position, 520.0, 0.55, true)
	_hazards.append(second)


func _enter_recovery(duration: float) -> void:
	_state = State.RECOVERING
	_state_timer = duration


func _is_second_phase() -> bool:
	return health_component.current_health <= health_component.max_health * 0.5


func _add_telegraph(item: CanvasItem) -> void:
	item.z_index = 2
	get_tree().current_scene.add_child(item)
	_telegraphs.append(item)


func _clear_telegraphs() -> void:
	for item in _telegraphs:
		if is_instance_valid(item):
			item.queue_free()
	_telegraphs.clear()


func _cleanup_behavior() -> void:
	_clear_telegraphs()
	for hazard in _hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	_hazards.clear()


func _process_contact_damage() -> void:
	if _contact_timer > 0.0 or not is_instance_valid(get_player()):
		return
	if global_position.distance_squared_to(get_player().global_position) > contact_radius * contact_radius:
		return
	damage_player(charge_damage if _state == State.CHARGING else boss_data.contact_damage)
	_contact_timer = contact_cooldown


func _circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(40):
		points.append(Vector2.from_angle(TAU * float(index) / 40.0) * radius)
	return points
