extends Node2D
class_name BossMagicProjectile
## Linear magic projectile used by radial boss attacks.

var direction := Vector2.RIGHT
var speed: float = 280.0
var damage: float = 12.0
var max_distance: float = 720.0
var hit_radius: float = 14.0

var _player: CharacterBody2D
var _distance_traveled: float = 0.0


func setup(
	player: CharacterBody2D,
	start_position: Vector2,
	travel_direction: Vector2,
	projectile_speed: float,
	projectile_damage: float,
	travel_distance: float
) -> void:
	_player = player
	global_position = start_position
	direction = travel_direction.normalized()
	speed = projectile_speed
	damage = projectile_damage
	max_distance = travel_distance
	rotation = direction.angle()
	z_index = 6


func _ready() -> void:
	add_to_group("boss_magic_projectiles")
	queue_redraw()


func _physics_process(delta: float) -> void:
	var previous_position := global_position
	var motion := direction * speed * delta
	global_position += motion
	_distance_traveled += motion.length()
	if _hits_player_between(previous_position, global_position):
		_damage_player()
		queue_free()
		return
	if _distance_traveled >= max_distance:
		queue_free()


func _hits_player_between(from: Vector2, to: Vector2) -> bool:
	if not is_instance_valid(_player):
		return false
	var closest_point := Geometry2D.get_closest_point_to_segment(_player.global_position, from, to)
	return closest_point.distance_squared_to(_player.global_position) <= hit_radius * hit_radius


func _damage_player() -> void:
	var health := _player.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(damage, global_position)


func _draw() -> void:
	draw_line(Vector2(-15.0, 0.0), Vector2(2.0, 0.0), Color(0.25, 0.7, 1.0, 0.45), 7.0)
	draw_circle(Vector2.ZERO, 8.0, Color(0.25, 0.65, 1.0, 0.42))
	draw_circle(Vector2.ZERO, 5.0, Color(0.72, 0.92, 1.0, 1.0))
