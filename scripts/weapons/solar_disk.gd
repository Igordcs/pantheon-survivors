extends Node2D
## Solar Disk — arma que cria discos que orbitam ao redor do player.

@export var weapon_data: WeaponData = preload("res://resources/weapons/solar_disk_data.tres")

var _current_level: int = 1
var _angle: float = 0.0
var _orbit_radius: float = 100.0
var _rotation_speed: float = 3.0

@onready var disk = $DiskArea


func _ready() -> void:
	if weapon_data:
		_orbit_radius = weapon_data.area
		_rotation_speed = weapon_data.projectile_speed


func _process(delta: float) -> void:
	_angle += _rotation_speed * delta
	if _angle > TAU:
		_angle -= TAU
		
	# Calcula a posição orbital relativa à arma (que está no player)
	var offset = Vector2(cos(_angle), sin(_angle)) * _orbit_radius
	disk.position = offset


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"solar_disk"


func get_current_level() -> int:
	return _current_level


func upgrade() -> void:
	if weapon_data and _current_level < weapon_data.max_level:
		_current_level += 1
		# Aumenta velocidade e raio
		_rotation_speed += 0.5
		_orbit_radius += 10.0


func _on_disk_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
		
	var base_dmg := weapon_data.base_damage if weapon_data else 10.0
	var final_dmg := base_dmg * (1.0 + (_current_level - 1) * 0.2)
	
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(final_dmg)
		_hit_flash(body)


func _hit_flash(body: Node2D) -> void:
	var sprite := body.get_node_or_null("Sprite2D") as CanvasItem
	if not sprite:
		return
	var tween := body.create_tween()
	sprite.modulate = Color.WHITE
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.15)
