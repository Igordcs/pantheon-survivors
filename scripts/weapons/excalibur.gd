extends Node2D
## Excalibur — ataque amplo que se estende a partir do personagem como um chicote.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/excalibur_data.tres")

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 30.0
var _front_strikes: int = 1
var _rear_strikes: int = 0
var _life_steal_ratio: float = 0.0
var _is_attacking: bool = false

@onready var _hitbox: Area2D = $Hitbox
@onready var _attack_visual: Node2D = $Hitbox/AttackVisual
@onready var _sweep_blade: Node2D = $Hitbox/AttackVisual/SweepBlade


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	_hitbox.monitoring = false
	_hitbox.visible = false
	_apply_level_stats()
	_cooldown_timer.start()


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
	_front_strikes = 1
	_rear_strikes = 0
	_life_steal_ratio = 0.0
	match level_data.special_effect:
		&"front_rear_combo":
			_rear_strikes = 1
		&"double_front_rear_combo":
			_front_strikes = 2
			_rear_strikes = 1
		&"double_rear_front_combo":
			_front_strikes = 1
			_rear_strikes = 2
		&"royal_life_steal_combo":
			_front_strikes = 1
			_rear_strikes = 2
			_life_steal_ratio = level_data.special_value

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(0.2, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	if not _is_attacking:
		_attack_sequence()


func _attack_sequence() -> void:
	_is_attacking = true
	var player := _get_player()
	var front_direction := _get_attack_direction(player)

	for index in range(_front_strikes):
		await _play_strike(front_direction)
		if index < _front_strikes - 1 or _rear_strikes > 0:
			await get_tree().create_timer(0.08, false).timeout

	for index in range(_rear_strikes):
		await _play_strike(-front_direction)
		if index < _rear_strikes - 1:
			await get_tree().create_timer(0.08, false).timeout

	_is_attacking = false
	_cooldown_timer.start()


func _play_strike(direction: Vector2) -> void:
	_hitbox.rotation = direction.angle()
	_hitbox.modulate = Color.WHITE
	_attack_visual.scale = Vector2.ONE * 0.82
	_sweep_blade.rotation = deg_to_rad(-55.0)
	_hitbox.visible = true
	_hitbox.monitoring = true

	# A lâmina percorre o arco de cima para baixo, simulando uma espadada rápida.
	var swing_tween := _sweep_blade.create_tween()
	swing_tween.tween_property(_sweep_blade, "rotation", deg_to_rad(55.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	swing_tween.parallel().tween_property(_attack_visual, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await swing_tween.finished
	_damage_overlapping_enemies()

	var tween := create_tween()
	tween.tween_property(_hitbox, "modulate:a", 0.0, 0.12)
	await tween.finished
	_hitbox.monitoring = false
	_hitbox.visible = false


func _damage_overlapping_enemies() -> void:
	var damage_dealt := 0.0
	for body in _hitbox.get_overlapping_bodies():
		if not body.is_in_group("enemies") or not body.visible:
			continue
		var health := body.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue
		damage_dealt += minf(_damage, health.current_health)
		health.take_damage(_damage)

	if damage_dealt > 0.0:
		ScreenShake.shake(0.15)
		_apply_life_steal(damage_dealt)


func _apply_life_steal(damage_dealt: float) -> void:
	if _life_steal_ratio <= 0.0:
		return
	var player := _get_player()
	if not player:
		return
	var player_health := player.get_node_or_null("HealthComponent") as HealthComponent
	if player_health and player_health.is_alive():
		player_health.heal(damage_dealt * _life_steal_ratio)


func _get_player() -> CharacterBody2D:
	return get_parent().get_parent() as CharacterBody2D


func _get_attack_direction(player: CharacterBody2D) -> Vector2:
	if player and "last_direction" in player and player.last_direction != Vector2.ZERO:
		return player.last_direction.normalized()
	return Vector2.RIGHT
