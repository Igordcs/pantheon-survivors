extends DirectionalBoss
## Each health threshold awakens more heads and expands the Hydra's attack patterns.

enum Attack { MANY_HEADED_STRIKE, SWAMP_ERUPTION, HEAD_SWEEP }
enum State { CHASING, CASTING, RECOVERING }

@export var attack_cooldown := 3.7

var _state := State.CHASING
var _state_timer := 2.2
var _last_attack := -1
var _head_tier := 1
var _hazards: Array[Node] = []


func _tick_behavior(delta: float) -> void:
	_update_head_tier()
	_state_timer -= delta
	match _state:
		State.CHASING:
			chase_player(1.0 + 0.06 * float(_head_tier - 1))
			if _state_timer <= 0.0:
				_start_attack()
		State.CASTING, State.RECOVERING:
			stop_movement()
			if _state_timer <= 0.0:
				if _state == State.CASTING:
					_state = State.RECOVERING
					_state_timer = 0.5
				else:
					_state = State.CHASING
					_state_timer = attack_cooldown - 0.35 * float(_head_tier - 1)


func _start_attack() -> void:
	var attack := randi_range(Attack.MANY_HEADED_STRIKE, Attack.HEAD_SWEEP)
	while attack == _last_attack:
		attack = randi_range(Attack.MANY_HEADED_STRIKE, Attack.HEAD_SWEEP)
	_last_attack = attack
	_state = State.CASTING
	match attack:
		Attack.MANY_HEADED_STRIKE:
			_cast_many_headed_strike()
			_state_timer = 1.7
		Attack.SWAMP_ERUPTION:
			_cast_swamp_eruption()
			_state_timer = 1.8
		Attack.HEAD_SWEEP:
			_cast_head_sweep()
			_state_timer = 1.45


func _cast_many_headed_strike() -> void:
	var base_direction := global_position.direction_to(get_player().global_position)
	var count := 2 + _head_tier
	for index in range(count):
		var offset := deg_to_rad((float(index) - float(count - 1) * 0.5) * 16.0)
		var direction := base_direction.rotated(offset)
		var line := BossLineHazard.new()
		get_tree().current_scene.add_child(line)
		line.setup(
			get_player(), global_position, global_position + direction * 470.0,
			0.72 + index * 0.2, 27.0, 34.0,
			Color(0.18, 0.55, 0.24, 0.25), Color(0.48, 1.0, 0.34, 0.9)
		)
		_hazards.append(line)


func _cast_swamp_eruption() -> void:
	var target := get_player().global_position
	var distance := minf(global_position.distance_to(target), 480.0)
	var direction := global_position.direction_to(target)
	var count := 5 + _head_tier
	for index in range(count):
		var progress := float(index + 1) / float(count)
		var position := global_position + direction * distance * progress
		var eruption := BossAreaHazard.new()
		get_tree().current_scene.add_child(eruption)
		eruption.setup(
			get_player(), position, 50.0, 0.5 + index * 0.14, 25.0, 0.25,
			0.0, 1.0, Color(0.1, 0.48, 0.22, 0.25), Color(0.38, 0.92, 0.3, 0.78)
		)
		_hazards.append(eruption)


func _cast_head_sweep() -> void:
	var safe_direction := Vector2.from_angle(TAU * float(randi_range(0, 7)) / 8.0)
	var ring := BossRingHazard.new()
	get_tree().current_scene.add_child(ring)
	ring.setup(
		get_player(), global_position, 82.0, 255.0 + 25.0 * _head_tier,
		1.05, 31.0, Color(0.2, 0.62, 0.3, 0.3), safe_direction, 58.0
	)
	_hazards.append(ring)


func _update_head_tier() -> void:
	var ratio := health_component.current_health / health_component.max_health
	var next_tier := 3 if ratio <= 0.33 else (2 if ratio <= 0.66 else 1)
	if next_tier <= _head_tier:
		return
	_head_tier = next_tier
	sprite.self_modulate = Color(0.5, 1.0, 0.38)
	create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.45)


func _cleanup_behavior() -> void:
	for hazard in _hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()
	_hazards.clear()
