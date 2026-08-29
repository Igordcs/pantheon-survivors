extends Node2D
## Excalibur — arma melee direcional com sequência de golpes em níveis altos.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/excalibur_data.tres")

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 30.0
var _arc_degrees: float = 90.0
var _secondary_attack_multiplier: float = 0.0
var _applies_knockback: bool = false
var _active_attack_multiplier: float = 1.0
var _is_attacking: bool = false

@onready var _hitbox: Area2D = $Hitbox


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	_hitbox.monitoring = false
	_hitbox.visible = false
	_hitbox.body_entered.connect(_on_body_entered)
	_apply_level_stats()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"excalibur"


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
	_hitbox.scale = Vector2.ONE * level_data.area_multiplier
	_arc_degrees = 90.0
	_secondary_attack_multiplier = 0.0
	_applies_knockback = false
	match level_data.special_effect:
		&"double_slash":
			_secondary_attack_multiplier = level_data.special_value
		&"double_slash_knockback":
			_secondary_attack_multiplier = level_data.special_value
			_applies_knockback = true
		&"royal_slash":
			_secondary_attack_multiplier = level_data.special_value
			_applies_knockback = true
			_arc_degrees = 150.0

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(0.2, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	if not _is_attacking:
		_attack_sequence()


func _attack_sequence() -> void:
	_is_attacking = true
	await _play_slash(false, 1.0)
	if _secondary_attack_multiplier > 0.0:
		await get_tree().create_timer(0.08, false).timeout
		await _play_slash(true, _secondary_attack_multiplier)
	_is_attacking = false


func _play_slash(reverse: bool, damage_multiplier: float) -> void:
	var player := get_parent().get_parent() as CharacterBody2D
	var direction := Vector2.RIGHT
	if player and "last_direction" in player:
		direction = player.last_direction

	var half_arc := _arc_degrees * 0.5
	var start_offset := half_arc if reverse else -half_arc
	var end_offset := -half_arc if reverse else half_arc
	_hitbox.rotation = direction.angle() + deg_to_rad(start_offset)
	_active_attack_multiplier = damage_multiplier
	_hitbox.monitoring = true
	_hitbox.visible = true

	var tween := create_tween()
	tween.tween_property(
		_hitbox,
		"rotation",
		direction.angle() + deg_to_rad(end_offset),
		0.2
	)
	await tween.finished
	_hitbox.monitoring = false
	_hitbox.visible = false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or not body.visible:
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		var source_position := global_position if _applies_knockback else Vector2.ZERO
		health.take_damage(_damage * _active_attack_multiplier, source_position)
