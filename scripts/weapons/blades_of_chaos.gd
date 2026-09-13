extends Node2D
## Kratos throws both chained blades overhead, then burns two parallel ground lanes.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData

var _timer: Timer
var _current_level := 1
var _damage := 26.0
var _range := 360.0
var _burn_damage := 6.0
var _active_effects: Array[Node2D] = []

const FIRE_TRAIL_LENGTH := 180.0
const FIRE_CROSS_ANGLE := 14.0


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_attack)
	add_child(_timer)
	_apply_level_stats()
	_timer.start()


func _process(_delta: float) -> void:
	for index in range(_active_effects.size() - 1, -1, -1):
		var effect := _active_effects[index]
		if not is_instance_valid(effect):
			_active_effects.remove_at(index)
			continue
		var chain := effect.get_node_or_null("Chain") as Line2D
		if not chain:
			continue
		var chain_origin: Vector2 = effect.get_meta("chain_origin", effect.global_position)
		var local_origin := effect.to_local(chain_origin)
		var bend := local_origin.orthogonal().normalized() * sin(Time.get_ticks_msec() * 0.018 + index) * 7.0
		chain.points = PackedVector2Array([
			Vector2.ZERO,
			local_origin * 0.34 + bend,
			local_origin * 0.68 - bend * 0.5,
			local_origin,
		])


func _exit_tree() -> void:
	for effect in _active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	_active_effects.clear()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"blades_of_chaos"


func get_current_level() -> int:
	return _current_level


func get_next_upgrade_description() -> String:
	return weapon_data.get_level_description(_current_level + 1) if weapon_data and _current_level < weapon_data.max_level else "Nível máximo."


func upgrade() -> void:
	if not weapon_data or _current_level >= weapon_data.max_level:
		return
	_current_level += 1
	_apply_level_stats()
	weapon_upgraded.emit(get_weapon_id(), _current_level)


func _apply_level_stats() -> void:
	var level := weapon_data.get_level_data(_current_level) if weapon_data else null
	if not level:
		return
	_damage = weapon_data.base_damage * level.damage_multiplier
	_range = weapon_data.area * level.area_multiplier
	_burn_damage = _damage * (0.2 + level.special_value)
	_timer.wait_time = maxf(0.45, weapon_data.cooldown * level.cooldown_multiplier)


func _attack() -> void:
	var owner := get_parent().get_parent() as Node2D
	if not owner:
		return
	var target := _find_nearest_enemy(owner.global_position)
	if not target:
		return
	var direction := owner.global_position.direction_to(target.global_position)
	var perpendicular := direction.orthogonal()
	var target_center := target.global_position
	_launch_blade(
		owner.global_position + perpendicular * 13.0,
		target_center - perpendicular * 10.0,
		direction,
		-1.0
	)
	_launch_blade(
		owner.global_position - perpendicular * 13.0,
		target_center + perpendicular * 10.0,
		direction,
		1.0
	)


func _launch_blade(origin: Vector2, impact: Vector2, attack_direction: Vector2, side: float) -> void:
	var effect := _create_blade_effect(origin, side)
	get_tree().current_scene.add_child(effect)
	_active_effects.append(effect)
	var apex := origin.lerp(impact, 0.48) + Vector2(0.0, -145.0) + origin.direction_to(impact).orthogonal() * side * 22.0
	var rise := effect.create_tween()
	rise.tween_property(effect, "global_position", apex, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(effect, "rotation", side * PI * 1.4, 0.18)
	await rise.finished
	if not is_instance_valid(effect):
		return
	var fall := effect.create_tween()
	fall.tween_property(effect, "global_position", impact, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(effect, "rotation", side * PI * 2.5, 0.2)
	await fall.finished
	if not is_instance_valid(effect):
		return
	_damage_impact(impact, origin)
	var fire_direction := attack_direction.rotated(deg_to_rad(-side * FIRE_CROSS_ANGLE))
	_spawn_fire_trail(impact, fire_direction)
	var burst := effect.create_tween()
	burst.tween_property(effect, "scale", Vector2(1.8, 1.8), 0.08)
	burst.parallel().tween_property(effect, "modulate:a", 0.0, 0.12)
	burst.tween_callback(effect.queue_free)


func _create_blade_effect(origin: Vector2, side: float) -> Node2D:
	var effect := Node2D.new()
	effect.global_position = origin
	effect.set_meta("chain_origin", origin - Vector2(side * 13.0, 0.0))
	effect.z_index = 8
	var chain := Line2D.new()
	chain.name = "Chain"
	chain.width = 3.0
	chain.default_color = Color(0.95, 0.42, 0.12, 0.9)
	chain.points = PackedVector2Array([Vector2.ZERO, Vector2(-side * 8.0, 12.0)])
	effect.add_child(chain)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-16, -6), Vector2(8, -8), Vector2(18, 0),
		Vector2(8, 8), Vector2(-16, 6), Vector2(-10, 0),
	])
	glow.color = Color(1.0, 0.12, 0.01, 0.38)
	glow.scale = Vector2(1.35, 1.35)
	effect.add_child(glow)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(-16, -4), Vector2(8, -6), Vector2(18, 0),
		Vector2(8, 6), Vector2(-16, 4), Vector2(-10, 0),
	])
	blade.color = Color(0.98, 0.58, 0.18)
	effect.add_child(blade)
	var edge := Line2D.new()
	edge.width = 2.0
	edge.default_color = Color(1.0, 0.93, 0.62)
	edge.points = PackedVector2Array([Vector2(-14, -3), Vector2(8, -5), Vector2(17, 0)])
	effect.add_child(edge)
	return effect


func _damage_impact(position: Vector2, source: Vector2) -> void:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		var enemy := candidate as Node2D
		if enemy.global_position.distance_squared_to(position) > 38.0 * 38.0:
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(_damage, source)


func _spawn_fire_trail(impact: Vector2, attack_direction: Vector2) -> void:
	var half_length := FIRE_TRAIL_LENGTH * 0.5
	var fire_start := impact - attack_direction * half_length
	var fire_end := impact + attack_direction * half_length
	var trail := ChaosFireTrail.new()
	get_tree().current_scene.add_child(trail)
	trail.setup(fire_start, fire_end, _burn_damage)


func _find_nearest_enemy(origin: Vector2) -> Node2D:
	var nearest: Node2D
	var nearest_distance := _range * _range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		var enemy := candidate as Node2D
		if not enemy.visible or enemy.is_queued_for_deletion():
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health and not health.is_alive():
			continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest
