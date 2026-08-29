extends Node2D
## Disco Solar — mantém orbitadores igualmente espaçados ao redor do Player.

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

@onready var _disk_template: Area2D = $DiskArea


func _ready() -> void:
	_disks.append(_disk_template)
	_apply_level_stats()


func _process(delta: float) -> void:
	_angle += _rotation_speed * delta
	if _angle >= TAU:
		_angle = fmod(_angle, TAU)
		if _pulse_damage_multiplier > 0.0:
			_emit_solar_pulse()

	var disk_count := _disks.size()
	for index in range(disk_count):
		var disk_angle := _angle + (TAU * float(index) / float(disk_count))
		_disks[index].position = Vector2.from_angle(disk_angle) * _orbit_radius


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"solar_disk"


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


func _on_disk_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or not body.visible:
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(_damage, global_position)


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

	_spawn_pulse_vfx(pulse_radius)
	ScreenShake.shake(0.25)


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
