extends Node2D

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/sumarbrander_data.tres")

var _current_level: int = 1
var _damage: float = 14.0
var _orbit_radius: float = 72.0
var _orbit_speed: float = 1.2
var _sword_speed: float = 220.0
var _attack_range: float = 120.0
var _sword_count: int = 1
var _swords: Array[Node2D] = []
var _sword_cooldowns: Array[float] = []
var _phase: float = 0.0


func _ready() -> void:
	_apply_level_stats()


func _process(delta: float) -> void:
	_phase += delta * _orbit_speed
	var owner_position: Vector2 = get_parent().global_position if get_parent() else global_position
	for index in range(_swords.size()):
		var sword: Node2D = _swords[index] as Node2D
		if not is_instance_valid(sword):
			continue
		_sword_cooldowns[index] = maxf(0.0, _sword_cooldowns[index] - delta)
		var target: CharacterBody2D = _find_best_target_for_sword(sword)
		if target:
			var direction: Vector2 = sword.global_position.direction_to(target.global_position)
			sword.global_position += direction * _sword_speed * delta
			if sword.global_position.distance_squared_to(target.global_position) <= 22.0 * 22.0:
				if _sword_cooldowns[index] <= 0.0:
					_deal_damage(target, sword)
					_sword_cooldowns[index] = maxf(0.15, weapon_data.cooldown * 0.4 if weapon_data else 0.25)
				continue
		var orbit_angle: float = _phase + (TAU * float(index) / max(1, _swords.size()))
		sword.global_position = owner_position + Vector2.from_angle(orbit_angle) * (_orbit_radius + float(index) * 12.0)


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"sumarbrander"


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
	_orbit_radius = weapon_data.area * level_data.area_multiplier
	_sword_speed = weapon_data.projectile_speed * level_data.speed_multiplier
	_attack_range = max(120.0, weapon_data.area * level_data.area_multiplier * 0.9)
	_orbit_speed = 1.3 + (float(_current_level) * 0.08)
	_sword_count = max(1, level_data.projectile_count)
	_sync_sword_count()
	for index in range(_swords.size()):
		var sword := _swords[index] as Node2D
		if sword:
			sword.scale = Vector2.ONE * (1.0 + float(index) * 0.08)


func _sync_sword_count() -> void:
	while _swords.size() < _sword_count:
		var sword: Node2D = Node2D.new()
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/weapons/Sumarbrander.webp")
		sprite.scale = Vector2(0.35, 0.35)
		sprite.rotation_degrees = 45.0
		sword.add_child(sprite)
		add_child(sword)
		_swords.append(sword)
		_sword_cooldowns.append(0.0)

	while _swords.size() > _sword_count:
		var removed: Node2D = _swords.pop_back()
		if is_instance_valid(removed):
			removed.queue_free()
		if _sword_cooldowns.size() > 0:
			_sword_cooldowns.pop_back()


func _find_best_target_for_sword(_sword: Node2D) -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_distance_sq: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body: CharacterBody2D = enemy as CharacterBody2D
		if not _is_valid_target(enemy_body):
			continue
		var distance_sq: float = _sword.global_position.distance_squared_to(enemy_body.global_position)
		if distance_sq < _attack_range * _attack_range and distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = enemy_body
	return best


func _deal_damage(target: CharacterBody2D, sword: Node2D) -> void:
	var health: HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(_damage, sword.global_position)


func _is_valid_target(enemy: CharacterBody2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.visible:
		return false
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	return health == null or health.is_alive()
