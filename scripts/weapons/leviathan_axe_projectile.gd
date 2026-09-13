extends Area2D

signal returned_to_wielder

var _wielder: Node2D
var _direction := Vector2.RIGHT
var _speed := 340.0
var _damage := 24.0
var _max_distance := 380.0
var _freeze_duration := 1.2
var _distance_traveled := 0.0
var _returning := false
var _hit_enemies: Dictionary = {}


func setup(
	wielder: Node2D,
	target_position: Vector2,
	speed: float,
	damage: float,
	max_distance: float,
	freeze_duration: float
) -> void:
	_wielder = wielder
	_direction = global_position.direction_to(target_position)
	_speed = speed
	_damage = damage
	_max_distance = max_distance
	_freeze_duration = freeze_duration


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_wielder):
		queue_free()
		return
	if _returning:
		_direction = global_position.direction_to(_wielder.global_position)
		global_position += _direction * _speed * 1.25 * delta
		if global_position.distance_to(_wielder.global_position) <= 12.0:
			returned_to_wielder.emit()
			queue_free()
			return
	else:
		global_position += _direction * _speed * delta
		_distance_traveled += _speed * delta
		if _distance_traveled >= _max_distance:
			_returning = true
	rotation += 11.0 * delta
	_hit_overlapping_enemies()


func _hit_overlapping_enemies() -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("enemies") or not body.visible:
			continue
		var enemy := body as Node2D
		if not enemy:
			continue
		var instance_id := enemy.get_instance_id()
		if _hit_enemies.has(instance_id):
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue
		health.take_damage(_damage, global_position)
		if enemy.has_method("apply_freeze"):
			enemy.apply_freeze(_freeze_duration)
		elif enemy.has_method("apply_petrification"):
			enemy.apply_petrification(_freeze_duration)
		_hit_enemies[instance_id] = true
