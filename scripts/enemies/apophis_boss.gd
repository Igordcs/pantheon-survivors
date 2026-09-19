extends DirectionalBoss
## Apophis combines poison rain, rotating chaos projectiles and inverse eclipse zones.

enum Attack { VENOM_RAIN, CHAOS_SPIRAL, APOPHIS_ECLIPSE }
enum State { CHASING, TELEGRAPHING, SPIRALING, RAIN_FOLLOWUP, RECOVERING }

@export var attack_cooldown := 4.0
@export var poison_impact_damage := 15.0
@export var poison_tick_damage := 7.0

var _state := State.CHASING
var _state_timer := 2.6
var _attack := Attack.VENOM_RAIN
var _last_attack := -1
var _target_position := Vector2.ZERO
var _telegraphs: Array[CanvasItem] = []
var _hazards: Array[Node] = []
var _spiral_wave := 0
var _spiral_wave_count := 0
var _eclipse_inner_danger := true


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
		State.SPIRALING:
			stop_movement()
			if _state_timer <= 0.0:
				_emit_spiral_wave()
		State.RAIN_FOLLOWUP:
			stop_movement()
			if _state_timer <= 0.0:
				_spawn_poison_volley(get_player().global_position)
				_enter_recovery(0.65)
		State.RECOVERING:
			stop_movement()
			if _state_timer <= 0.0:
				_state = State.CHASING
				_state_timer = 3.1 if _is_second_phase() else attack_cooldown


func _start_attack() -> void:
	var next_attack := randi_range(Attack.VENOM_RAIN, Attack.APOPHIS_ECLIPSE)
	while next_attack == _last_attack:
		next_attack = randi_range(Attack.VENOM_RAIN, Attack.APOPHIS_ECLIPSE)
	_attack = next_attack
	_last_attack = next_attack
	_target_position = get_player().global_position
	_state = State.TELEGRAPHING
	_state_timer = 1.0 if _attack != Attack.APOPHIS_ECLIPSE else 1.2
	match _attack:
		Attack.VENOM_RAIN: _prepare_venom_rain()
		Attack.CHAOS_SPIRAL: _prepare_chaos_spiral()
		Attack.APOPHIS_ECLIPSE: _prepare_eclipse()


func _prepare_venom_rain() -> void:
	var marker := Polygon2D.new()
	marker.polygon = _circle_points(55.0)
	marker.color = Color(0.34, 0.72, 0.08, 0.36)
	marker.global_position = global_position
	_add_telegraph(marker)


func _prepare_chaos_spiral() -> void:
	var marker := Polygon2D.new()
	marker.polygon = _circle_points(78.0)
	marker.color = Color(0.5, 0.08, 0.68, 0.34)
	marker.global_position = global_position
	_add_telegraph(marker)


func _prepare_eclipse() -> void:
	_eclipse_inner_danger = randi() % 2 == 0
	if _eclipse_inner_danger:
		var center := BossAreaHazard.new()
		get_tree().current_scene.add_child(center)
		center.setup(
			get_player(), global_position, 165.0, _state_timer, 41.0, 0.25,
			0.0, 1.0, Color(0.42, 0.04, 0.58, 0.3), Color(0.86, 0.14, 0.92, 0.86)
		)
		_hazards.append(center)
	else:
		var outer := BossRingHazard.new()
		get_tree().current_scene.add_child(outer)
		outer.setup(
			get_player(), global_position, 165.0, 430.0, _state_timer, 41.0,
			Color(0.42, 0.04, 0.58, 0.32)
		)
		_hazards.append(outer)


func _execute_attack() -> void:
	_clear_telegraphs()
	match _attack:
		Attack.VENOM_RAIN:
			_spawn_poison_volley(_target_position)
			if _is_second_phase():
				_state = State.RAIN_FOLLOWUP
				_state_timer = 0.48
			else:
				_enter_recovery(0.6)
		Attack.CHAOS_SPIRAL:
			_state = State.SPIRALING
			_spiral_wave = 0
			_spiral_wave_count = 7 if _is_second_phase() else 5
			_state_timer = 0.01
		Attack.APOPHIS_ECLIPSE:
			_enter_recovery(0.7)


func _spawn_poison_volley(center: Vector2) -> void:
	var count := 4 if _is_second_phase() else 3
	for index in range(count):
		var angle := TAU * float(index) / float(count) + randf_range(-0.18, 0.18)
		var target := center if index == 0 else center + Vector2.from_angle(angle) * (
			105.0 + 25.0 * float(index % 2)
		)
		var projectile := BossPoisonProjectile.new()
		get_tree().current_scene.add_child(projectile)
		projectile.setup(
			get_player(), global_position, target, poison_impact_damage,
			poison_tick_damage, 78.0
		)
		_hazards.append(projectile)


func _emit_spiral_wave() -> void:
	if _spiral_wave >= _spiral_wave_count:
		_enter_recovery(0.75)
		return
	var arms := 4 if _is_second_phase() else 3
	var rotation_offset := float(_spiral_wave) * 0.28
	for index in range(arms):
		var direction := Vector2.from_angle(TAU * float(index) / float(arms) + rotation_offset)
		var projectile := BossMagicProjectile.new()
		get_tree().current_scene.add_child(projectile)
		projectile.setup(
			get_player(), global_position, direction, 255.0, 14.0, 760.0,
			Color(0.78, 0.18, 0.9)
		)
		_hazards.append(projectile)
	_spiral_wave += 1
	_state_timer = 0.18


func _enter_recovery(duration: float) -> void:
	_state = State.RECOVERING
	_state_timer = duration


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
	for index in range(36):
		points.append(Vector2.from_angle(TAU * float(index) / 36.0) * radius)
	return points
