extends DirectionalBoss
## Amheh controls the battlefield with persistent circles of purple gravefire.

enum Attack { DEVOURER_FLAMES, FUNERAL_CONSTELLATION, CONSUMED_HORIZON }
enum State { CHASING, CASTING, RECOVERING }

@export var attack_cooldown := 3.4
@export var gravefire_damage := 18.0
@export var gravefire_tick_damage := 6.0

var _state := State.CHASING
var _state_timer := 2.0
var _last_attack := -1
var _hazards: Array[Node] = []


func _tick_behavior(delta: float) -> void:
	_state_timer -= delta
	match _state:
		State.CHASING:
			chase_player(1.12 if _is_second_phase() else 1.0)
			if _state_timer <= 0.0:
				_start_attack()
		State.CASTING, State.RECOVERING:
			stop_movement()
			if _state_timer <= 0.0:
				if _state == State.CASTING:
					_state = State.RECOVERING
					_state_timer = 0.45
				else:
					_state = State.CHASING
					_state_timer = 2.7 if _is_second_phase() else attack_cooldown


func _start_attack() -> void:
	var attack := randi_range(Attack.DEVOURER_FLAMES, Attack.CONSUMED_HORIZON)
	while attack == _last_attack:
		attack = randi_range(Attack.DEVOURER_FLAMES, Attack.CONSUMED_HORIZON)
	_last_attack = attack
	_state = State.CASTING
	match attack:
		Attack.DEVOURER_FLAMES:
			_cast_devourer_flames()
			_state_timer = 1.45
		Attack.FUNERAL_CONSTELLATION:
			_cast_funeral_constellation()
			_state_timer = 1.7
		Attack.CONSUMED_HORIZON:
			_cast_consumed_horizon()
			_state_timer = 1.55


func _cast_devourer_flames() -> void:
	var center := get_player().global_position
	var count := 7 if _is_second_phase() else 5
	for index in range(count):
		var position := center if index == 0 else center + Vector2.from_angle(
			TAU * float(index - 1) / float(maxi(count - 1, 1))
		) * 125.0
		_spawn_gravefire(position, 0.85 + index * 0.06, 54.0)


func _cast_funeral_constellation() -> void:
	var center := get_player().global_position
	var slot_count := 10 if _is_second_phase() else 8
	var safe_slot := randi_range(0, slot_count - 1)
	for index in range(slot_count):
		if index == safe_slot:
			continue
		var radius := 155.0 if index % 2 == 0 else 215.0
		var position := center + Vector2.from_angle(TAU * float(index) / float(slot_count)) * radius
		_spawn_gravefire(position, 1.0 + (index % 3) * 0.12, 48.0)


func _cast_consumed_horizon() -> void:
	var ring := BossRingHazard.new()
	get_tree().current_scene.add_child(ring)
	ring.setup(
		get_player(), global_position, 105.0, 320.0, 1.05, 34.0,
		Color(0.62, 0.08, 0.82, 0.34)
	)
	_hazards.append(ring)
	# The center ignites after the ring resolves, leaving time to escape the inverse blast.
	_spawn_gravefire(global_position, 1.5, 82.0)


func _spawn_gravefire(position: Vector2, delay: float, radius: float) -> void:
	var fire := BossAreaHazard.new()
	get_tree().current_scene.add_child(fire)
	fire.setup(
		get_player(), position, radius, delay, gravefire_damage, 3.4,
		gravefire_tick_damage, 0.65,
		Color(0.48, 0.04, 0.68, 0.27), Color(0.82, 0.08, 1.0, 0.52)
	)
	_hazards.append(fire)


func _is_second_phase() -> bool:
	return health_component.current_health <= health_component.max_health * 0.5


func _cleanup_behavior() -> void:
	for hazard in _hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	_hazards.clear()
