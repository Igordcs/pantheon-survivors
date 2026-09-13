extends Node2D
## Arma de fogo do Punisher (M4A4) — dispara balas com automira, recuo e efeitos visuais detalhados.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData
@export var projectile_scene: PackedScene

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 18.0
var _attack_range: float = 500.0
var _projectile_speed: float = 700.0
var _projectile_count: int = 1
var _burst_count: int = 1
var _burst_delay: float = 0.08

var _last_aim_dir: Vector2 = Vector2.RIGHT
var _recoil_tween: Tween

@onready var gun_pivot: Node2D = $GunPivot if has_node("GunPivot") else null
@onready var gun_sprite: Sprite2D = $GunPivot/GunSprite if has_node("GunPivot/GunSprite") else null
@onready var muzzle: Marker2D = $GunPivot/Muzzle if has_node("GunPivot/Muzzle") else null

const GUN_REST_X := 8.0


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)
	_apply_level_stats()


func _process(delta: float) -> void:
	_update_gun_aim(delta)


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"punisher_gun"


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
	_projectile_speed = weapon_data.projectile_speed * level_data.speed_multiplier
	_projectile_count = max(1, level_data.projectile_count)

	_burst_count = 1
	if level_data.special_effect == &"gun_burst":
		_burst_count = max(1, int(level_data.special_value))

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(0.1, weapon_data.cooldown * level_data.cooldown_multiplier)


func _update_gun_aim(delta: float) -> void:
	if not gun_pivot:
		return

	var enemies := _find_closest_enemies(1)
	var target_dir := _last_aim_dir
	if not enemies.is_empty() and is_instance_valid(enemies[0]):
		target_dir = global_position.direction_to(enemies[0].global_position)
		_last_aim_dir = target_dir
	else:
		# Se não há inimigo, mira na direção de movimento do player se houver
		var parent_node := get_parent()
		if parent_node and "velocity" in parent_node and parent_node.velocity.length_squared() > 1.0:
			target_dir = parent_node.velocity.normalized()
			_last_aim_dir = target_dir

	var target_angle := target_dir.angle()
	gun_pivot.rotation = lerp_angle(gun_pivot.rotation, target_angle, 14.0 * delta)

	if gun_sprite:
		var normalized_angle := wrapf(gun_pivot.rotation, -PI, PI)
		var is_facing_left := absf(normalized_angle) > (PI * 0.5)
		gun_sprite.flip_v = is_facing_left
		gun_sprite.position.y = -1.0 if is_facing_left else 1.0


func _on_cooldown_timeout() -> void:
	var targets: Array[CharacterBody2D] = _find_closest_enemies(_projectile_count)
	if targets.is_empty():
		return

	if _burst_count <= 1:
		for target in targets:
			_fire_at(target)
	else:
		_fire_burst(targets, _burst_count)


func _fire_burst(targets: Array[CharacterBody2D], bursts_remaining: int) -> void:
	if bursts_remaining <= 0:
		return
	for target in targets:
		_fire_at(target)

	if bursts_remaining > 1:
		var timer := get_tree().create_timer(_burst_delay)
		timer.timeout.connect(func():
			var valid_targets: Array[CharacterBody2D] = []
			for t in targets:
				if _is_valid_target(t):
					valid_targets.append(t)
			if valid_targets.is_empty():
				valid_targets = _find_closest_enemies(_projectile_count)
			_fire_burst(valid_targets, bursts_remaining - 1)
		)


func _find_closest_enemies(limit: int) -> Array[CharacterBody2D]:
	var candidates: Array[CharacterBody2D] = []
	var range_squared: float = _attack_range * _attack_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body: CharacterBody2D = enemy as CharacterBody2D
		if not _is_valid_target(enemy_body):
			continue
		if global_position.distance_squared_to(enemy_body.global_position) <= range_squared:
			candidates.append(enemy_body)

	candidates.sort_custom(func(a: CharacterBody2D, b: CharacterBody2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	if candidates.size() > limit:
		candidates.resize(limit)
	return candidates


func _fire_at(target: CharacterBody2D) -> void:
	if not projectile_scene or not is_instance_valid(target):
		return

	var aim_dir := global_position.direction_to(target.global_position)
	_last_aim_dir = aim_dir

	if gun_pivot:
		gun_pivot.rotation = aim_dir.angle()

	# Recuo visual na arma
	_apply_gun_recoil(aim_dir)

	# Efeito sonoro
	var music_mgr := get_tree().root.get_node_or_null("MusicManager")
	if music_mgr and music_mgr.has_method("play_punisher_shot_sfx"):
		music_mgr.play_punisher_shot_sfx()

	# Origem do tiro: ponta do cano
	var origin: Vector2 = muzzle.global_position if muzzle else (global_position + aim_dir * 18.0)
	var bullet_dir := aim_dir.rotated(randf_range(-0.035, 0.035))

	var bullet: Area2D = projectile_scene.instantiate() as Area2D
	bullet.global_position = origin
	bullet.rotation = bullet_dir.angle()
	if bullet.has_method("setup"):
		bullet.setup(bullet_dir, _projectile_speed, _damage, _attack_range)
	get_tree().current_scene.add_child(bullet)

	# Efeitos visuais do disparo
	_spawn_muzzle_flash(origin, bullet_dir)
	_spawn_shell_casing(global_position + aim_dir * 4.0, bullet_dir)
	_spawn_smoke_puff(origin, bullet_dir)


func _apply_gun_recoil(aim_dir: Vector2) -> void:
	if not gun_sprite:
		return
	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()

	gun_sprite.position.x = 2.0
	_recoil_tween = gun_sprite.create_tween()
	_recoil_tween.tween_property(gun_sprite, "position:x", GUN_REST_X, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_muzzle_flash(origin: Vector2, dir: Vector2) -> void:
	# Flash principal (estrela pontiaguda de fogo)
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(10, -4), Vector2(22, 0), Vector2(10, 4),
		Vector2(14, -8), Vector2(12, 8), Vector2(5, -6), Vector2(5, 6)
	])
	flash.color = Color(1.0, 0.96, 0.65, 1.0)
	flash.global_position = origin
	flash.rotation = dir.angle()
	flash.z_index = 8
	get_tree().current_scene.add_child(flash)

	# Núcleo incandescente branco
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0, -2), Vector2(10, 0), Vector2(0, 2)
	])
	core.color = Color(1.0, 1.0, 1.0, 1.0)
	core.global_position = origin
	core.rotation = dir.angle()
	core.z_index = 9
	get_tree().current_scene.add_child(core)

	# Halo de luz quente
	var glow := Line2D.new()
	glow.default_color = Color(1.0, 0.7, 0.2, 0.65)
	glow.width = 3.0
	for i in range(10):
		glow.add_point(Vector2.from_angle(TAU * float(i) / 9.0) * 12.0)
	glow.global_position = origin
	glow.z_index = 7
	get_tree().current_scene.add_child(glow)

	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.3, 1.2), 0.04)
	tween.tween_property(flash, "modulate:a", 0.0, 0.06)
	tween.tween_property(core, "modulate:a", 0.0, 0.04)
	tween.tween_property(glow, "scale", Vector2.ONE * 1.8, 0.05)
	tween.tween_property(glow, "modulate:a", 0.0, 0.06)
	tween.chain().tween_callback(func():
		if is_instance_valid(flash): flash.queue_free()
		if is_instance_valid(core): core.queue_free()
		if is_instance_valid(glow): glow.queue_free()
	)


func _spawn_shell_casing(origin: Vector2, dir: Vector2) -> void:
	var casing := Polygon2D.new()
	casing.polygon = PackedVector2Array([
		Vector2(-3, -1.5), Vector2(3, -1.5), Vector2(3, 1.5), Vector2(-3, 1.5)
	])
	casing.color = Color(0.95, 0.8, 0.25, 0.95)
	casing.global_position = origin
	casing.z_index = 4

	var eject_side: float = -1.0 if randf() > 0.3 else 1.0
	var eject_dir := dir.rotated(PI * 0.5 * eject_side)
	get_tree().current_scene.add_child(casing)

	var target_pos := origin + eject_dir * randf_range(16.0, 28.0) + Vector2(0, randf_range(12.0, 24.0))
	var tween := casing.create_tween()
	tween.set_parallel(true)
	tween.tween_property(casing, "global_position", target_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(casing, "rotation", randf_range(-PI * 3.0, PI * 3.0), 0.28)
	tween.tween_property(casing, "modulate:a", 0.0, 0.2).set_delay(0.12)
	tween.chain().tween_callback(casing.queue_free)


func _spawn_smoke_puff(origin: Vector2, dir: Vector2) -> void:
	var smoke := Polygon2D.new()
	smoke.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(0, -4), Vector2(3, -3),
		Vector2(4, 0), Vector2(3, 3), Vector2(0, 4),
		Vector2(-3, 3), Vector2(-4, 0)
	])
	smoke.color = Color(0.8, 0.8, 0.85, 0.35)
	smoke.global_position = origin + dir * 6.0
	smoke.z_index = 5
	get_tree().current_scene.add_child(smoke)

	var tween := smoke.create_tween()
	tween.set_parallel(true)
	tween.tween_property(smoke, "scale", Vector2.ONE * 2.8, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(smoke, "modulate:a", 0.0, 0.25)
	tween.tween_property(smoke, "global_position", smoke.global_position + dir * 12.0 + Vector2(0, -6), 0.25)
	tween.chain().tween_callback(smoke.queue_free)


func _is_valid_target(enemy: CharacterBody2D) -> bool:
	if not is_instance_valid(enemy) or not enemy.visible:
		return false
	var health: HealthComponent = enemy.get_node_or_null("HealthComponent") as HealthComponent
	return health == null or health.is_alive()
