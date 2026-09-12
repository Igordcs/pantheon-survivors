extends Node2D
## Granada do Punisher — lança granadas explosivas em direção aos inimigos.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData
@export var projectile_scene: PackedScene

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 45.0
var _explosion_radius: float = 80.0
var _throw_range: float = 250.0
var _projectile_speed: float = 350.0
var _grenade_count: int = 1


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)
	_apply_level_stats()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"punisher_grenade"


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
	_explosion_radius = weapon_data.area * level_data.area_multiplier
	_throw_range = 250.0 * level_data.area_multiplier
	_projectile_speed = weapon_data.projectile_speed * level_data.speed_multiplier
	_grenade_count = max(1, level_data.projectile_count)

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(0.3, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	var targets: Array[CharacterBody2D] = _find_closest_enemies(_grenade_count)
	if targets.is_empty():
		return

	for target in targets:
		_throw_grenade_at(target)


func _find_closest_enemies(limit: int) -> Array[CharacterBody2D]:
	var candidates: Array[CharacterBody2D] = []
	var range_squared: float = (_throw_range * 1.5) * (_throw_range * 1.5)
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


func _throw_grenade_at(target: CharacterBody2D) -> void:
	if not projectile_scene or not is_instance_valid(target):
		return
	var grenade: Area2D = projectile_scene.instantiate() as Area2D
	var origin: Vector2 = global_position
	var dir := origin.direction_to(target.global_position)
	var dist := minf(origin.distance_to(target.global_position), _throw_range)

	grenade.global_position = origin
	if grenade.has_method("setup"):
		grenade.setup(dir, _projectile_speed, _damage, _explosion_radius, dist)
	get_tree().current_scene.add_child(grenade)


func _is_valid_target(enemy: CharacterBody2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.visible:
		return false
	var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
	return health == null or health.is_alive()
