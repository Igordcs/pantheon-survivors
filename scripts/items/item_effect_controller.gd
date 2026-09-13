extends Node
class_name ItemEffectController

var _items: Dictionary = {}
var _player: CharacterBody2D
var _health: HealthComponent
var _base_speed := 0.0
var _damage_pause := 0.0
var _regen_accumulator := 0.0
var _shield_timer := 0.0
var _shield_ready := false
var _barrier := 0.0
var _revive_available := false
var _invulnerability := 0.0
var _kill_streak := 0
var _maat_buff := 0.0
var _pickup_count := 0
var _pickup_boost := 0.0
var _attack_count := 0
var _mark_timer := 0.0
var _haste_generation := 0
var _item_levels: Dictionary = {}


func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	for id in SaveManager.get_equipped_items():
		var item := ItemCatalog.get_item(id)
		if item:
			_items[item.effect_id] = item
			_item_levels[item.id] = 1
	apply_items.call_deferred()


func apply_items() -> void:
	_health = _player.get_node_or_null("HealthComponent") as HealthComponent
	_base_speed = float(_player.get("speed"))
	if _items.has(&"max_health") and _health:
		var bonus := _health.max_health * (_items[&"max_health"] as ItemData).value
		_health.max_health += bonus; _health.current_health += bonus
		_health.health_changed.emit(_health.current_health, _health.max_health)
	if _items.has(&"pickup"):
		_set_pickup_scale(1.0 + (_items[&"pickup"] as ItemData).value)
	_revive_available = _items.has(&"revive")
	if _items.has(&"shield"): _shield_timer = (_items[&"shield"] as ItemData).value
	var holder: Node = _player.get_node_or_null("WeaponHolder")
	if holder:
		holder.child_entered_tree.connect(_configure_weapon)
		for weapon in holder.get_children(): _configure_weapon.call_deferred(weapon)
	var experience := _player.get_node_or_null("ExperienceComponent") as ExperienceComponent
	if experience: experience.level_up.connect(_on_level_up)


func _process(delta: float) -> void:
	_damage_pause = maxf(_damage_pause - delta, 0.0)
	_invulnerability = maxf(_invulnerability - delta, 0.0)
	_maat_buff = maxf(_maat_buff - delta, 0.0)
	_pickup_boost = maxf(_pickup_boost - delta, 0.0)
	_mark_timer -= delta
	if _items.has(&"regen") and _damage_pause <= 0.0 and _health and _health.is_alive():
		_regen_accumulator += _health.max_health * (_items[&"regen"] as ItemData).value * delta
		if _regen_accumulator >= 0.1:
			_health.heal(_regen_accumulator); _regen_accumulator = 0.0
	if _items.has(&"shield") and not _shield_ready:
		_shield_timer -= delta
		if _shield_timer <= 0.0: _shield_ready = true
	if _items.has(&"mark") and _mark_timer <= 0.0:
		_mark_nearest_enemy(); _mark_timer = (_items[&"mark"] as ItemData).secondary_value
	_update_speed()


func get_damage_multiplier() -> float:
	var result := 1.0
	if _items.has(&"damage"): result += (_items[&"damage"] as ItemData).value
	if _maat_buff > 0.0: result += 0.12
	return result


func get_xp_multiplier() -> float:
	return 1.0 + ((_items[&"xp"] as ItemData).value if _items.has(&"xp") else 0.0)


func get_luck() -> float:
	return (_items[&"luck"] as ItemData).value if _items.has(&"luck") else 0.0


func get_item_level(item_id: StringName) -> int:
	return int(_item_levels.get(item_id, 0))


func get_active_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in _items.values():
		result.append(item as ItemData)
	return result


func upgrade_item(item_id: StringName) -> bool:
	var item := ItemCatalog.get_item(item_id)
	var current_level := get_item_level(item_id)
	if not item or current_level <= 0 or current_level >= item.max_level:
		return false
	_item_levels[item_id] = current_level + 1
	_update_speed()
	return true


func debug_grant_item(item: ItemData) -> bool:
	if not item:
		return false
	if _items.has(item.effect_id):
		return upgrade_item(item.id)
	_items[item.effect_id] = item
	_item_levels[item.id] = 1
	match item.effect_id:
		&"max_health":
			var bonus := _health.max_health * item.value
			_health.max_health += bonus; _health.current_health += bonus
			_health.health_changed.emit(_health.current_health, _health.max_health)
		&"pickup": _set_pickup_scale(1.0 + item.value)
		&"revive": _revive_available = true
		&"shield": _shield_timer = item.value
		&"move_speed": _update_speed()
	for weapon in _player.get_node("WeaponHolder").get_children(): _configure_weapon(weapon)
	return true


func absorb_damage(amount: float) -> float:
	_damage_pause = 5.0; _kill_streak = 0
	if _invulnerability > 0.0: return 0.0
	if _shield_ready:
		_shield_ready = false; _shield_timer = (_items[&"shield"] as ItemData).value
		return 0.0
	if _barrier > 0.0:
		var absorbed := minf(_barrier, amount); _barrier -= absorbed; amount -= absorbed
	return amount


func try_revive() -> bool:
	if not _revive_available or not _health: return false
	_revive_available = false
	_health.current_health = _health.max_health * (_items[&"revive"] as ItemData).value
	_invulnerability = (_items[&"revive"] as ItemData).secondary_value
	_health.health_changed.emit(_health.current_health, _health.max_health)
	return true


func add_overheal(amount: float) -> void:
	if _items.has(&"overheal_barrier") and _health:
		_barrier = minf(_barrier + amount, _health.max_health * (_items[&"overheal_barrier"] as ItemData).value)


func notify_enemy_defeated() -> void:
	if not _items.has(&"kill_streak"): return
	_kill_streak += 1
	if _kill_streak >= int((_items[&"kill_streak"] as ItemData).value):
		_kill_streak = 0; _maat_buff = (_items[&"kill_streak"] as ItemData).secondary_value


func notify_pickup() -> void:
	if not _items.has(&"pickup"): return
	_pickup_count += 1
	if _pickup_count >= int((_items[&"pickup"] as ItemData).secondary_value):
		_pickup_count = 0; _pickup_boost = 3.0; _set_pickup_scale(3.0)
		_restore_pickup_after_delay()


func notify_projectile_blocked(solar_disk: Node2D) -> void:
	if not _items.has(&"solar_block"): return
	var count := int(solar_disk.get_meta("horus_blocks", 0)) + 1
	solar_disk.set_meta("horus_blocks", count)
	if count < int((_items[&"solar_block"] as ItemData).value): return
	solar_disk.set_meta("horus_blocks", 0)
	var solar_damage := float(solar_disk.get("_damage")) if solar_disk.get("_damage") != null else 24.0
	_damage_nearby(_player.global_position, 220.0, solar_damage * (_items[&"solar_block"] as ItemData).secondary_value)


func _on_level_up(_level: int) -> void:
	if _items.has(&"level_heal") and _health: _health.heal(_health.max_health * (_items[&"level_heal"] as ItemData).value)
	if _items.has(&"level_haste"): _apply_temporary_haste()


func _configure_weapon(weapon: Node) -> void:
	if not is_instance_valid(weapon): return
	await get_tree().process_frame
	if not is_instance_valid(weapon): return
	var cooldown_multiplier := 1.0 - ((_items[&"cooldown"] as ItemData).value if _items.has(&"cooldown") else 0.0)
	for timer in _weapon_timers(weapon):
		if _items.has(&"cooldown") and not timer.has_meta("item_cooldown_applied"):
			timer.wait_time = maxf(0.05, timer.wait_time * cooldown_multiplier)
			timer.set_meta("item_cooldown_applied", true)
		if _items.has(&"attack_echo") and not timer.has_meta("draupnir_connected"):
			timer.timeout.connect(_on_weapon_attack.bind(weapon))
			timer.set_meta("draupnir_connected", true)
	if _items.has(&"area") and not weapon.has_meta("item_area_applied"):
		for node in weapon.find_children("*", "CollisionShape2D", true, false):
			var collision_shape := node as CollisionShape2D
			if collision_shape:
				collision_shape.scale *= 1.2
		weapon.set_meta("item_area_applied", true)
	if weapon.has_signal("projectile_blocked") and not weapon.has_meta("horus_connected"):
		weapon.connect("projectile_blocked", notify_projectile_blocked.bind(weapon))
		weapon.set_meta("horus_connected", true)
	if weapon.has_signal("weapon_upgraded") and not weapon.has_meta("item_upgrade_connected"):
		weapon.connect("weapon_upgraded", _on_weapon_upgraded.bind(weapon))
		weapon.set_meta("item_upgrade_connected", true)


func _on_weapon_upgraded(_weapon_id: StringName, _new_level: int, weapon: Node) -> void:
	# A arma recalcula seus tempos-base ao subir de nível; reaplica Chronos uma vez.
	for timer in _weapon_timers(weapon):
		if timer.has_meta("item_cooldown_applied"):
			timer.remove_meta("item_cooldown_applied")
	_configure_weapon.call_deferred(weapon)


func _on_weapon_attack(weapon: Node) -> void:
	_attack_count += 1
	if _attack_count < int((_items[&"attack_echo"] as ItemData).value): return
	_attack_count = 0
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(weapon): return
	var target := _nearest_enemy()
	if target:
		var data := weapon.get("weapon_data") as WeaponData
		var damage := (data.base_damage if data else 12.0) * (_items[&"attack_echo"] as ItemData).secondary_value
		var health := target.get_node_or_null("HealthComponent") as HealthComponent
		if health: health.take_damage(damage, _player.global_position)


func _apply_temporary_haste() -> void:
	_haste_generation += 1
	var generation := _haste_generation
	for timer in _weapon_timers(_player.get_node("WeaponHolder")):
		if not timer.has_meta("mead_wait"): timer.set_meta("mead_wait", timer.wait_time)
		timer.wait_time = float(timer.get_meta("mead_wait")) * 0.8
	await get_tree().create_timer((_items[&"level_haste"] as ItemData).secondary_value).timeout
	if generation != _haste_generation: return
	for timer in _weapon_timers(_player.get_node("WeaponHolder")):
		if timer.has_meta("mead_wait"): timer.wait_time = float(timer.get_meta("mead_wait")); timer.remove_meta("mead_wait")


func _weapon_timers(root: Node) -> Array[Timer]:
	var result: Array[Timer] = []
	if root is Timer:
		result.append(root as Timer)
	for node in root.find_children("*", "Timer", true, false):
		var timer := node as Timer
		if timer:
			result.append(timer)
	return result


func _set_pickup_scale(multiplier: float) -> void:
	var shape := _player.get_node_or_null("PickupArea/CollisionShape2D") as CollisionShape2D
	if shape: shape.scale = Vector2.ONE * multiplier


func _restore_pickup_after_delay() -> void:
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree() and _pickup_boost <= 0.0: _set_pickup_scale(1.0 + (_items[&"pickup"] as ItemData).value)


func _update_speed() -> void:
	var multiplier := 1.12 if _maat_buff > 0.0 else 1.0
	if _items.has(&"move_speed"):
		var sandals := _items[&"move_speed"] as ItemData
		multiplier += sandals.get_value_for_level(get_item_level(sandals.id))
	_player.set("speed", _base_speed * multiplier)


func _mark_nearest_enemy() -> void:
	var target := _nearest_enemy()
	if target: target.set_meta("odin_marked_until", Time.get_ticks_msec() + 4000)


func _nearest_enemy() -> Node2D:
	var nearest: Node2D
	var distance := INF
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		var enemy := candidate as Node2D
		if not enemy.visible:
			continue
		var current := _player.global_position.distance_squared_to(enemy.global_position)
		if current < distance:
			distance = current
			nearest = enemy
	return nearest


func _damage_nearby(center: Vector2, radius: float, damage: float) -> void:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		var enemy := candidate as Node2D
		if enemy.global_position.distance_squared_to(center) <= radius * radius:
			var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
			if health:
				health.take_damage(damage, center)
