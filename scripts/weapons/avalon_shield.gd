extends Node2D
## Avalon Shield — emite uma onda de choque radial que causa dano a todos os inimigos ao redor.
##
## Arma secundária de Arthur. Não depende de direção nem de projéteis: o dano é
## puramente radial, centrado na posição do jogador.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/avalon_shield_data.tres")

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 20.0
var _radius: float = 110.0
var _knockback_force: float = 300.0
var _stun_duration: float = 0.0
var _regen_amount: float = 0.0
var _is_attacking: bool = false


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	add_child(_cooldown_timer)
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	_apply_level_stats()
	_cooldown_timer.start()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data != null else &"avalon_shield"


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
	_radius = weapon_data.area * level_data.area_multiplier
	_knockback_force = 300.0
	_stun_duration = 0.0
	_regen_amount = 0.0

	match level_data.special_effect:
		&"knockback_plus":
			_knockback_force = 500.0
		&"stun":
			_knockback_force = 500.0
			_stun_duration = level_data.special_value
		&"regen_burst":
			_knockback_force = 500.0
			_stun_duration = level_data.special_value
			_regen_amount = level_data.special_value

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(0.5, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	if not _is_attacking:
		_fire_shockwave()


func _fire_shockwave() -> void:
	_is_attacking = true

	if MusicManager.has_method(&"play_avalon_shield_sfx"):
		MusicManager.play_avalon_shield_sfx()

	# Visual: anel que expande a partir do jogador
	var ring := Line2D.new()
	ring.points = _get_ring_points(10.0)
	ring.width = 6.0
	ring.default_color = Color(0.6, 0.85, 1.0, 0.9)
	ring.joint_mode = Line2D.LINE_JOINT_ROUND
	ring.global_position = global_position
	get_tree().current_scene.add_child(ring)

	var scale_target := Vector2(_radius / 10.0, _radius / 10.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", scale_target, 0.32) \
		.from(Vector2(0.05, 0.05)) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.32).from(0.9)

	await tween.finished
	ring.queue_free()

	_damage_enemies_in_radius()

	if _regen_amount > 0.0:
		_heal_player(_regen_amount)

	_is_attacking = false
	_cooldown_timer.start()


func _damage_enemies_in_radius() -> void:
	var radius_sq := _radius * _radius
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as CharacterBody2D
		if enemy == null or not enemy.visible:
			continue
		if global_position.distance_squared_to(enemy.global_position) > radius_sq:
			continue

		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health != null and health.is_alive():
			health.take_damage(_damage, global_position)

		# Knockback
		var push_dir := (enemy.global_position - global_position).normalized()
		if push_dir == Vector2.ZERO:
			push_dir = Vector2.RIGHT
		enemy.velocity += push_dir * _knockback_force

		# Stun (slow extremo)
		if _stun_duration > 0.0 and enemy.has_method(&"apply_temporary_slow"):
			enemy.apply_temporary_slow(0.05, _stun_duration)


func _heal_player(amount: float) -> void:
	var player := _get_player()
	if not player:
		return
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.heal(amount)


func _get_player() -> CharacterBody2D:
	return get_parent().get_parent() as CharacterBody2D


func _get_ring_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(33):
		points.append(Vector2.from_angle(TAU * i / 32.0) * radius)
	return points
