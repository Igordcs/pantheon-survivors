extends Node2D

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/khepris_scarab_data.tres")
@export var projectile_scene: PackedScene = preload("res://scenes/weapons/khepris_scarab_projectile.tscn")

var _cooldown_timer: Timer
var _current_level: int = 1

var _damage: float = 3.0
var _projectile_count: int = 1
var _max_jumps: int = 2
var _jump_explosion_damage: float = 0.0
var _jump_explosion_radius: float = 0.0
var _tick_rate: float = 0.5

func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	_apply_level_stats()

func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"khepris_scarab"

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
	_projectile_count = level_data.projectile_count
	
	_max_jumps = 2
	_jump_explosion_damage = 0.0
	_jump_explosion_radius = 0.0
	_tick_rate = 0.5

	if level_data.special_effect == &"jumps":
		_max_jumps = int(level_data.special_value)
	elif level_data.special_effect == &"explosion_jump":
		_max_jumps = 5
		_jump_explosion_damage = _damage * 2.0
		_jump_explosion_radius = 120.0
	elif level_data.special_effect == &"fast_tick":
		_max_jumps = 5
		_jump_explosion_damage = _damage * 3.0
		_jump_explosion_radius = 150.0
		_tick_rate = 0.25

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(0.1, weapon_data.cooldown * level_data.cooldown_multiplier)

func _on_cooldown_timeout() -> void:
	_fire_scarabs()

func _fire_scarabs() -> void:
	if not projectile_scene:
		return

	var wielder := get_parent().get_parent() as Node2D
	if not wielder:
		return

	for i in range(_projectile_count):
		var proj = projectile_scene.instantiate()
		if proj:
			get_tree().current_scene.add_child(proj)
			proj.global_position = global_position
			proj.setup(wielder, _damage, 500.0, _tick_rate, _jump_explosion_damage, _jump_explosion_radius, _max_jumps)
