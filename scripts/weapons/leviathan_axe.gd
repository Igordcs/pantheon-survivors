extends Node2D

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/leviathan_axe_data.tres")
@export var projectile_scene: PackedScene = preload("res://scenes/weapons/leviathan_axe_projectile.tscn")

var _attack_timer: Timer
var _current_level := 1
var _damage := 24.0
var _attack_range := 380.0
var _projectile_speed := 340.0
var _freeze_duration := 1.2
var _axe_active := false


func _ready() -> void:
	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(_throw_axe)
	add_child(_attack_timer)
	_apply_level_stats()
	_attack_timer.start(weapon_data.cooldown)


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"leviathan_axe"


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
	var level_data := weapon_data.get_level_data(_current_level) if weapon_data else null
	if not level_data:
		return
	_damage = weapon_data.base_damage * level_data.damage_multiplier
	_attack_range = weapon_data.area * level_data.area_multiplier
	_projectile_speed = weapon_data.projectile_speed * level_data.speed_multiplier
	_freeze_duration = maxf(level_data.special_value, 0.1)
	if _attack_timer:
		_attack_timer.wait_time = maxf(0.2, weapon_data.cooldown * level_data.cooldown_multiplier)


func _throw_axe() -> void:
	if _axe_active:
		return
	var target := _find_closest_enemy()
	if not target:
		_attack_timer.start()
		return
	var axe := projectile_scene.instantiate() as Area2D
	if not axe:
		_attack_timer.start()
		return
	var wielder := get_parent().get_parent() as Node2D
	axe.global_position = global_position
	axe.setup(wielder, target.global_position, _projectile_speed, _damage, _attack_range, _freeze_duration)
	axe.returned_to_wielder.connect(_on_axe_returned)
	_axe_active = true
	get_tree().current_scene.add_child(axe)


func _on_axe_returned() -> void:
	_axe_active = false
	_attack_timer.start()


func _find_closest_enemy() -> Node2D:
	var nearest: Node2D
	var nearest_distance := _attack_range * _attack_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if not is_instance_valid(enemy) or not enemy.visible:
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health and not health.is_alive():
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest
