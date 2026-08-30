extends Node2D
## Raio de Zeus — escolhe alvos visíveis e derruba raios do céu.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 28.0
var _initial_target_count: int = 1
var _chain_jumps: int = 1
var _chain_range: float = 170.0
var _chain_damage_multiplier: float = 0.7
var _is_attacking: bool = false


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)
	_apply_level_stats()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"zeus_lightning"


func get_current_level() -> int:
	return _current_level


func get_next_upgrade_description() -> String:
	if not weapon_data or _current_level >= weapon_data.max_level:
		return "Nível máximo."
	return weapon_data.get_level_description(_current_level + 1)


func upgrade() -> void:
	if not weapon_data or _current_level >= weapon_data.max_level:
		return
	_current_level += 1
	_apply_level_stats()
	weapon_upgraded.emit(get_weapon_id(), _current_level)


func _apply_level_stats() -> void:
	if not weapon_data:
		return
	var level_data := weapon_data.get_level_data(_current_level)
	if not level_data:
		return

	_damage = weapon_data.base_damage * level_data.damage_multiplier
	_chain_range = weapon_data.area * level_data.area_multiplier
	_initial_target_count = level_data.projectile_count
	_chain_damage_multiplier = level_data.special_value if level_data.special_value > 0.0 else 0.7
	match level_data.special_effect:
		&"zeus_chain_2":
			_chain_jumps = 2
		&"zeus_chain_3":
			_chain_jumps = 3
		&"thunderstorm":
			_chain_jumps = 4
		_:
			_chain_jumps = 1

	_cooldown_timer.wait_time = maxf(0.2, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	if _is_attacking:
		return
	_attack_random_targets()


func _attack_random_targets() -> void:
	_is_attacking = true
	var candidates := _get_candidates()
	if candidates.is_empty():
		_is_attacking = false
		return

	var hit_enemies: Array[Node2D] = []
	var initial_count := mini(_initial_target_count, candidates.size())
	var initial_targets: Array[CharacterBody2D] = []
	for index in range(initial_count):
		initial_targets.append(candidates[index])

	var chain_origins: Array[Vector2] = []
	for target in initial_targets:
		chain_origins.append(await _strike_from_sky(target, _damage, hit_enemies))

	for origin_index in range(chain_origins.size()):
		var origin := chain_origins[origin_index]
		var strike_damage := _damage * _chain_damage_multiplier
		for _jump_index in range(_chain_jumps):
			var target := _find_chain_target(origin, candidates, hit_enemies)
			if not target:
				break
			_strike_target(origin, target, strike_damage, hit_enemies)
			origin = target.global_position
			strike_damage *= _chain_damage_multiplier

	ScreenShake.shake(0.2)
	_is_attacking = false


func _get_candidates() -> Array[CharacterBody2D]:
	var candidates: Array[CharacterBody2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body := enemy as CharacterBody2D
		if not _is_valid_target(enemy_body):
			continue
		if _is_inside_viewport(enemy_body.global_position):
			candidates.append(enemy_body)
	candidates.shuffle()
	return candidates


func _strike_from_sky(
	target: CharacterBody2D,
	strike_damage: float,
	hit_enemies: Array[Node2D]
) -> Vector2:
	var impact_position := target.global_position
	var sky_position := _get_sky_position(impact_position)
	await _play_falling_bolt(sky_position, impact_position)
	if _is_valid_target(target):
		impact_position = target.global_position
		_damage_target(target, strike_damage, hit_enemies)
		_spawn_lightning_vfx(sky_position, impact_position, 8.0, 0.25)
	return impact_position


func _strike_target(
	origin: Vector2,
	target: CharacterBody2D,
	strike_damage: float,
	hit_enemies: Array[Node2D]
) -> void:
	if not _damage_target(target, strike_damage, hit_enemies):
		return
	_spawn_lightning_vfx(origin, target.global_position, 6.0, 0.2)


func _damage_target(
	target: CharacterBody2D,
	strike_damage: float,
	hit_enemies: Array[Node2D]
) -> bool:
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if not health or not health.is_alive():
		return false
	hit_enemies.append(target)
	health.take_damage(strike_damage)
	return true


func _find_chain_target(
	origin: Vector2,
	candidates: Array[CharacterBody2D],
	excluded: Array[Node2D]
) -> CharacterBody2D:
	var closest: CharacterBody2D
	var closest_distance_squared := _chain_range * _chain_range
	for enemy in candidates:
		if enemy in excluded or not _is_valid_target(enemy):
			continue
		var distance_squared := origin.distance_squared_to(enemy.global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest = enemy
	return closest


func _is_valid_target(enemy: CharacterBody2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.visible:
		return false
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	return health == null or health.is_alive()


func _is_inside_viewport(world_position: Vector2) -> bool:
	var screen_position := get_viewport().get_canvas_transform() * world_position
	return get_viewport_rect().has_point(screen_position)


func _get_sky_position(target_position: Vector2) -> Vector2:
	var canvas_transform := get_viewport().get_canvas_transform()
	var target_screen_position := canvas_transform * target_position
	var sky_screen_position := Vector2(target_screen_position.x, 12.0)
	return canvas_transform.affine_inverse() * sky_screen_position


func _play_falling_bolt(from_position: Vector2, to_position: Vector2) -> void:
	var marker := Line2D.new()
	marker.default_color = Color(1.0, 0.85, 0.25, 0.85)
	marker.width = 3.0
	for index in range(17):
		marker.add_point(Vector2.from_angle(TAU * float(index) / 16.0) * 18.0)
	marker.global_position = to_position
	get_tree().current_scene.add_child(marker)

	var bolt := Line2D.new()
	bolt.default_color = Color(0.65, 0.9, 1.0, 1.0)
	bolt.width = 7.0
	bolt.add_point(Vector2(-8.0, -90.0))
	bolt.add_point(Vector2(5.0, -60.0))
	bolt.add_point(Vector2(-4.0, -30.0))
	bolt.add_point(Vector2.ZERO)
	bolt.global_position = from_position
	get_tree().current_scene.add_child(bolt)

	var warning_tween := marker.create_tween()
	warning_tween.tween_property(marker, "modulate:a", 0.35, 0.12)
	await warning_tween.finished
	var fall_tween := bolt.create_tween()
	fall_tween.tween_property(bolt, "global_position", to_position, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall_tween.finished
	marker.queue_free()
	bolt.queue_free()


func _spawn_lightning_vfx(
	from_position: Vector2,
	to_position: Vector2,
	width: float,
	duration: float
) -> void:
	var line := Line2D.new()
	line.default_color = Color(0.55, 0.85, 1.0, 0.95)
	line.width = width
	line.add_point(from_position)
	line.add_point(to_position)
	get_tree().current_scene.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, duration)
	tween.tween_callback(line.queue_free)
