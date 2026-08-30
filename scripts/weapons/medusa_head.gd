extends Node2D
## Cabeça de Medusa — petrifica inimigos em um cone frontal.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 4.0
var _range: float = 140.0
var _cone_degrees: float = 90.0
var _petrification_duration: float = 1.2


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)
	_apply_level_stats()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"medusa_head"


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
	_range = weapon_data.area * level_data.area_multiplier
	_cone_degrees = 120.0 if level_data.special_effect == &"gorgon_gaze" else 90.0
	_petrification_duration = level_data.special_value if level_data.special_value > 0.0 else 1.2
	_cooldown_timer.wait_time = maxf(0.5, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	var facing_direction := _get_facing_direction()
	var affected_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body := enemy as CharacterBody2D
		if not is_instance_valid(enemy_body) or not enemy_body.visible:
			continue
		if not _is_inside_cone(enemy_body.global_position, facing_direction):
			continue
		var health := enemy_body.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue
		health.take_damage(_damage)
		if enemy_body.has_method("apply_petrification"):
			enemy_body.apply_petrification(_petrification_duration)
			affected_count += 1

	if affected_count > 0:
		_spawn_petrification_vfx(facing_direction)


func _is_inside_cone(target_position: Vector2, facing_direction: Vector2) -> bool:
	var offset := target_position - global_position
	if offset.length_squared() > _range * _range:
		return false
	if offset.is_zero_approx():
		return true
	var minimum_dot := cos(deg_to_rad(_cone_degrees * 0.5))
	return facing_direction.dot(offset.normalized()) >= minimum_dot


func _get_facing_direction() -> Vector2:
	var player := get_parent().get_parent() as CharacterBody2D
	if player and "last_direction" in player and player.last_direction != Vector2.ZERO:
		return player.last_direction.normalized()
	return Vector2.DOWN


func _spawn_petrification_vfx(facing_direction: Vector2) -> void:
	var cone := Polygon2D.new()
	var points := PackedVector2Array([Vector2.ZERO])
	var facing_angle := facing_direction.angle()
	var half_angle := deg_to_rad(_cone_degrees * 0.5)
	for index in range(17):
		var weight := float(index) / 16.0
		var angle := lerpf(-half_angle, half_angle, weight) + facing_angle
		points.append(Vector2.from_angle(angle) * _range)
	cone.polygon = points
	cone.color = Color(0.45, 0.85, 0.55, 0.32)
	add_child(cone)
	var tween := cone.create_tween()
	tween.tween_property(cone, "modulate:a", 0.0, 0.35)
	tween.tween_callback(cone.queue_free)
