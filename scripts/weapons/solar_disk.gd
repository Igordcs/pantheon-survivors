extends Node2D
## Disco Solar — causa dano e bloqueia projéteis hostis com até três orbitadores.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/solar_disk_data.tres")

var _current_level: int = 1
var _angle: float = 0.0
var _orbit_radius: float = 100.0
var _rotation_speed: float = 3.0
var _damage: float = 10.0
var _disk_scale: float = 1.0
var _pulse_damage_multiplier: float = 0.0
var _disks: Array[Area2D] = []

const MAX_DISK_COUNT: int = 3
const PROJECTILE_BLOCK_RADIUS: float = 22.0

# Controle de frequência para o áudio não estourar em hordas cheias
var _last_hit_sound_time: float = 0.0
const SFX_COOLDOWN: float = 0.08

@onready var _disk_template: Area2D = $DiskArea


func _ready() -> void:
	_disks.append(_disk_template)
	
	# Garante que o disco inicial também esteja conectado ao evento de colisão
	var hit_callback := Callable(self, "_on_disk_area_body_entered")
	if not _disk_template.body_entered.is_connected(hit_callback):
		_disk_template.body_entered.connect(hit_callback)
		
	_apply_level_stats()


func _physics_process(delta: float) -> void:
	_angle += _rotation_speed * delta
	if _angle >= TAU:
		_angle = fmod(_angle, TAU)
		if _pulse_damage_multiplier > 0.0:
			_emit_solar_pulse()

	var disk_count := _disks.size()
	for index in range(disk_count):
		var disk_angle := _angle + (TAU * float(index) / float(disk_count))
		_disks[index].position = Vector2.from_angle(disk_angle) * _orbit_radius

	_block_enemy_projectiles()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"solar_disk"


func get_current_level() -> int:
	return _current_level


func get_disk_count() -> int:
	return _disks.size()


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
	_orbit_radius = weapon_data.area * level_data.area_multiplier
	_rotation_speed = weapon_data.projectile_speed * level_data.speed_multiplier
	_disk_scale = 1.0
	if _current_level >= 6:
		_disk_scale = 1.25
	elif _current_level >= 3:
		_disk_scale = 1.1
	_pulse_damage_multiplier = (
		level_data.special_value if level_data.special_effect == &"solar_pulse" else 0.0
	)

	_sync_disk_count(level_data.projectile_count)
	for disk in _disks:
		disk.scale = Vector2.ONE * _disk_scale


func _sync_disk_count(target_count: int) -> void:
	target_count = clampi(target_count, 1, MAX_DISK_COUNT)
	while _disks.size() < target_count:
		var new_disk := _disk_template.duplicate() as Area2D
		add_child(new_disk)
		var hit_callback := Callable(self, "_on_disk_area_body_entered")
		if not new_disk.body_entered.is_connected(hit_callback):
			new_disk.body_entered.connect(hit_callback)
		_disks.append(new_disk)

	while _disks.size() > target_count:
		var removed_disk: Area2D = _disks.pop_back()
		removed_disk.queue_free()


func _block_enemy_projectiles() -> void:
	var block_radius_squared := PROJECTILE_BLOCK_RADIUS * PROJECTILE_BLOCK_RADIUS
	for projectile_node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		var projectile := projectile_node as Node2D
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		for disk in _disks:
			if disk.global_position.distance_squared_to(projectile.global_position) \
					> block_radius_squared:
				continue
			if projectile.has_method(&"block"):
				projectile.call(&"block")
			else:
				projectile.queue_free()
			_play_hit_sound_throttled()
			break


func _on_disk_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or not body.visible:
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(_damage, global_position)
		_play_hit_sound_throttled()


func _play_hit_sound_throttled() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _last_hit_sound_time >= SFX_COOLDOWN:
		_last_hit_sound_time = current_time
		MusicManager.play_solar_disk_sfx()


func _emit_solar_pulse() -> void:
	var pulse_radius := _orbit_radius + 40.0
	var pulse_damage := _damage * _pulse_damage_multiplier
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body := enemy as CharacterBody2D
		if not is_instance_valid(enemy_body) or not enemy_body.visible:
			continue
		if global_position.distance_squared_to(enemy_body.global_position) > pulse_radius * pulse_radius:
			continue
		var health := enemy_body.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(pulse_damage, global_position)

	# Efeito sonoro acompanhando o pulso em anel
	MusicManager.play_solar_disk_sfx()
	_spawn_pulse_vfx(pulse_radius)


func _spawn_pulse_vfx(radius: float) -> void:
	var ring := Line2D.new()
	ring.default_color = Color(1.0, 0.7, 0.1, 0.8)
	ring.width = 4.0
	for index in range(33):
		var point_angle := TAU * float(index) / 32.0
		ring.add_point(Vector2.from_angle(point_angle) * radius)
	add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ring.queue_free)
