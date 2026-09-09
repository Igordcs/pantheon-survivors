extends Node2D

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/gungnir_data.tres")
@export var projectile_scene: PackedScene = preload("res://scenes/weapons/gungnir_projectile.tscn")

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 18.0
var _attack_range: float = 650.0
var _projectile_speed: float = 540.0
var _projectile_count: int = 1
var _pierce_count: int = 2
var _ricochet_count: int = 1


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)
	_apply_level_stats()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"gungnir"


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
	_projectile_count = max(1, level_data.projectile_count)
	_pierce_count = 2
	_ricochet_count = 1
	if level_data.special_effect == &"gungnir_seek":
		_ricochet_count = int(maxf(level_data.special_value, 1.0))
		_pierce_count = max(2, _ricochet_count + 1)
	elif level_data.special_effect == &"gungnir_burst":
		_pierce_count = max(3, int(level_data.special_value))
		_ricochet_count = max(1, _pierce_count - 1)

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(0.1, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	var targets: Array[CharacterBody2D] = _find_closest_enemies(_projectile_count)
	for target in targets:
		_fire_at(target)


func _find_closest_enemies(limit: int) -> Array[CharacterBody2D]:
	var candidates: Array[CharacterBody2D] = []
	var range_squared: float = _attack_range * _attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body: CharacterBody2D = enemy as CharacterBody2D
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
	if not projectile_scene or not is_instance_valid(target):
		return
	var projectile: Area2D = projectile_scene.instantiate() as Area2D
	var wielder: Node2D = get_parent().get_parent() as Node2D
	var origin: Vector2 = global_position
	projectile.global_position = origin
	projectile.rotation = origin.angle_to_point(target.global_position)
	if projectile.has_method("setup"):
		projectile.setup(wielder, target, _projectile_speed, _damage, _attack_range, _pierce_count, _ricochet_count)
	get_tree().current_scene.add_child(projectile)


func _is_valid_target(enemy: CharacterBody2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.visible:
		return false
	var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
	return health == null or health.is_alive()
