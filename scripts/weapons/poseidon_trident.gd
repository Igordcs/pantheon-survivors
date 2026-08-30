extends Node2D
## Tridente de Poseidon — dispara ondas perfurantes que empurram inimigos.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData
@export var wave_scene: PackedScene

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 22.0
var _attack_range: float = 350.0
var _wave_speed: float = 420.0
var _wave_count: int = 1
var _wave_scale: float = 1.0
var _knockback_force: float = 260.0


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)
	_apply_level_stats()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"poseidon_trident"


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
	_wave_speed = weapon_data.projectile_speed * level_data.speed_multiplier
	_wave_count = level_data.projectile_count
	_wave_scale = 1.0
	_knockback_force = 260.0
	match level_data.special_effect:
		&"wide_wave":
			_wave_scale = level_data.special_value
		&"strong_knockback":
			_wave_scale = 1.2
			_knockback_force *= level_data.special_value
		&"tidal_surge":
			_wave_scale = 1.5
			_knockback_force *= level_data.special_value

	_cooldown_timer.wait_time = maxf(0.2, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	var target := _find_closest_enemy()
	if not target or not wave_scene:
		return
	var base_direction := global_position.direction_to(target.global_position)
	for index in range(_wave_count):
		var centered_index := float(index) - (float(_wave_count - 1) * 0.5)
		_spawn_wave(base_direction.rotated(deg_to_rad(centered_index * 12.0)))


func _find_closest_enemy() -> CharacterBody2D:
	var closest: CharacterBody2D
	var closest_distance_squared := _attack_range * _attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body := enemy as CharacterBody2D
		if not _is_valid_target(enemy_body):
			continue
		var distance_squared := global_position.distance_squared_to(enemy_body.global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest = enemy_body
	return closest


func _spawn_wave(direction: Vector2) -> void:
	var wave := wave_scene.instantiate() as Area2D
	wave.global_position = global_position
	wave.setup(direction, _wave_speed, _damage, _attack_range, _knockback_force, _wave_scale)
	get_tree().current_scene.add_child(wave)


func _is_valid_target(enemy: CharacterBody2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.visible:
		return false
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	return health == null or health.is_alive()
