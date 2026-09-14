extends Node2D

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/horusfeather_data.tres")
@export var projectile_scene: PackedScene = preload("res://scenes/weapons/horusfeather_projectile.tscn")

var _cooldown_timer: Timer
var _current_level: int = 1

var _damage: float = 14.0
var _projectile_speed: float = 450.0
var _attack_range: float = 800.0
var _projectile_count: int = 1
var _pierce_count: int = 0
var _knockback_force: float = 0.0

var _angle_spacing: float = 15.0


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	_apply_level_stats()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"horusfeather"


func get_current_level() -> int:
	return _current_level


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
	_projectile_count = level_data.projectile_count

	_pierce_count = 0
	_knockback_force = 0.0

	match level_data.special_effect:
		&"pierce_1":
			_pierce_count = 1

		&"pierce_infinite":
			_pierce_count = -1

		&"knockback_light":
			_knockback_force = level_data.special_value

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(
			0.1,
			weapon_data.cooldown * level_data.cooldown_multiplier
		)


func _on_cooldown_timeout() -> void:
	var target := _find_closest_enemy()

	if not target:
		return

	_fire_projectiles(target)


func _fire_projectiles(target: CharacterBody2D) -> void:
	if not projectile_scene:
		return

	var wielder := get_parent().get_parent() as Node2D

	if not wielder:
		return

	var base_direction := global_position.direction_to(target.global_position)
	var base_angle := base_direction.angle()

	for i in range(_projectile_count):
		var angle_offset_deg := 0.0
		if _projectile_count > 1:
			var start_angle := -((_projectile_count - 1) * _angle_spacing) / 2.0
			angle_offset_deg = start_angle + (i * _angle_spacing)

		var final_direction := Vector2.RIGHT.rotated(base_angle + deg_to_rad(angle_offset_deg))
		
		_fire_projectile(
			wielder,
			final_direction,
			Vector2.ZERO
		)


func _fire_projectile(
	wielder: Node2D,
	direction: Vector2,
	spawn_offset: Vector2
) -> void:
	var projectile := projectile_scene.instantiate() as Area2D

	if not projectile:
		return

	projectile.global_position = global_position + spawn_offset

	projectile.setup(
		wielder,
		direction,
		_projectile_speed,
		_damage,
		_attack_range,
		_pierce_count,
		_knockback_force
	)

	get_tree().current_scene.add_child(projectile)


func _find_closest_enemy() -> CharacterBody2D:
	var closest: CharacterBody2D = null
	var closest_distance_squared := _attack_range * _attack_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body := enemy as CharacterBody2D

		if not _is_valid_target(enemy_body):
			continue

		var distance_squared := global_position.distance_squared_to(
			enemy_body.global_position
		)

		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest = enemy_body

	return closest


func _is_valid_target(enemy: CharacterBody2D) -> bool:
	if not is_instance_valid(enemy):
		return false

	if not enemy.visible:
		return false

	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent

	if health == null:
		return true

	return health.is_alive()