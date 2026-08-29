extends Node2D
## Mjolnir — arma automática com múltiplos alvos e chain lightning.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData
@export var projectile_scene: PackedScene

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 15.0
var _attack_range: float = 250.0
var _projectile_speed: float = 600.0
var _target_count: int = 1
var _chain_jumps: int = 0
var _chain_damage_multiplier: float = 0.6


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)
	_apply_level_stats()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"mjolnir"


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
	_attack_range = weapon_data.area * level_data.area_multiplier
	_projectile_speed = weapon_data.projectile_speed * level_data.speed_multiplier
	_target_count = level_data.projectile_count
	_chain_damage_multiplier = level_data.special_value if level_data.special_value > 0.0 else 0.6
	match level_data.special_effect:
		&"chain_lightning_1":
			_chain_jumps = 1
		&"chain_lightning_2":
			_chain_jumps = 2
		_:
			_chain_jumps = 0

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(0.1, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	for target in _find_closest_enemies(_target_count):
		_fire_at(target)


func _find_closest_enemies(limit: int) -> Array[CharacterBody2D]:
	var candidates: Array[CharacterBody2D] = []
	var range_squared := _attack_range * _attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body := enemy as CharacterBody2D
		if not _is_valid_target(enemy_body):
			continue
		if global_position.distance_squared_to(enemy_body.global_position) <= range_squared:
			candidates.append(enemy_body)

	candidates.sort_custom(func(a: CharacterBody2D, b: CharacterBody2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	if candidates.size() > limit:
		candidates.resize(limit)
	return candidates


func _fire_at(target: CharacterBody2D) -> void:
	if not projectile_scene:
		return
	var projectile := projectile_scene.instantiate() as Area2D
	var direction := global_position.direction_to(target.global_position)
	var distance := global_position.distance_to(target.global_position)
	projectile.global_position = global_position
	projectile.setup(direction, _projectile_speed, _damage, distance + 50.0)
	if projectile.has_signal("hit_enemy"):
		projectile.connect(
			"hit_enemy",
			Callable(self, "_on_projectile_hit").bind(_chain_jumps, _chain_damage_multiplier)
		)
	get_tree().current_scene.add_child(projectile)


func _on_projectile_hit(
	first_enemy: Node2D,
	impact_position: Vector2,
	dealt_damage: float,
	chain_jumps: int,
	chain_multiplier: float
) -> void:
	if chain_jumps <= 0:
		return

	var hit_enemies: Array[Node2D] = [first_enemy]
	var chain_origin := impact_position
	var chain_damage := dealt_damage * chain_multiplier
	for _jump_index in range(chain_jumps):
		var next_target := _find_chain_target(chain_origin, hit_enemies)
		if not next_target:
			break
		var health := next_target.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(chain_damage, chain_origin)
			_spawn_chain_vfx(chain_origin, next_target.global_position)
		hit_enemies.append(next_target)
		chain_origin = next_target.global_position
		chain_damage *= chain_multiplier


func _find_chain_target(origin: Vector2, excluded: Array[Node2D]) -> CharacterBody2D:
	var closest: CharacterBody2D
	var closest_distance_squared := 140.0 * 140.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body := enemy as CharacterBody2D
		if not _is_valid_target(enemy_body) or enemy_body in excluded:
			continue
		var distance_squared := origin.distance_squared_to(enemy_body.global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest = enemy_body
	return closest


func _is_valid_target(enemy: CharacterBody2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.visible:
		return false
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	return health == null or health.is_alive()


func _spawn_chain_vfx(from_position: Vector2, to_position: Vector2) -> void:
	var line := Line2D.new()
	line.default_color = Color(0.3, 0.8, 1.0, 0.9)
	line.width = 5.0
	line.add_point(from_position)
	line.add_point(to_position)
	get_tree().current_scene.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.tween_callback(line.queue_free)
