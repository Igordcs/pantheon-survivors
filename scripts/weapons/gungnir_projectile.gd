extends Area2D

signal returned_to_wielder

var direction: Vector2 = Vector2.RIGHT
var speed: float = 360.0
var damage: float = 18.0
var max_distance: float = 650.0

var _wielder: Node2D
var _target: CharacterBody2D
var _pierce_count: int = 2
var _ricochet_count: int = 1
var _hit_enemies: Array[int] = []
var _distance_traveled: float = 0.0
var _returning: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_wielder):
		queue_free()
		return

	if _returning:
		_return_to_wielder(delta)
		return

	if is_instance_valid(_target) and _target.visible:
		var target_direction := global_position.direction_to(_target.global_position)
		if target_direction.length_squared() > 0.0:
			direction = direction.lerp(target_direction, 0.2).normalized()
	else:
		_target = _find_next_target()
		if not is_instance_valid(_target):
			_returning = true
			return
		direction = global_position.direction_to(_target.global_position)

	global_position += direction * speed * delta
	_distance_traveled += speed * delta
	_damage_overlapping_enemies()
	rotation = direction.angle()

	if _distance_traveled >= max_distance:
		_returning = true

	if global_position.distance_to(_wielder.global_position) > max_distance * 1.4 and not _returning:
		_returning = true


func setup(
	wielder: Node2D,
	target: CharacterBody2D,
	spd: float,
	dmg: float,
	max_dist: float,
	pierce_count: int,
	ricochet_count: int
) -> void:
	_wielder = wielder
	_target = target
	speed = spd
	damage = dmg
	max_distance = max_dist
	_pierce_count = max(1, pierce_count)
	_ricochet_count = max(0, ricochet_count)
	direction = global_position.direction_to(target.global_position) if is_instance_valid(target) else Vector2.RIGHT
	_hit_enemies.clear()
	_distance_traveled = 0.0
	_returning = false


func _return_to_wielder(delta: float) -> void:
	if not is_instance_valid(_wielder):
		queue_free()
		return
	var to_wielder := global_position.direction_to(_wielder.global_position)
	global_position += to_wielder * speed * 1.2 * delta
	rotation = to_wielder.angle()
	if global_position.distance_to(_wielder.global_position) < 8.0:
		returned_to_wielder.emit()
		queue_free()


func _damage_overlapping_enemies() -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("enemies") or not body.visible:
			continue
		var enemy := body as CharacterBody2D
		if not is_instance_valid(enemy):
			continue
		var instance_id := enemy.get_instance_id()
		if _hit_enemies.has(instance_id):
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue
		health.take_damage(damage, global_position)
		_hit_enemies.append(instance_id)
		if _hit_enemies.size() >= _pierce_count + _ricochet_count:
			_returning = true
			break
		_target = _find_next_target()
		if not is_instance_valid(_target):
			_returning = true
			break


func _find_next_target() -> CharacterBody2D:
	var best: CharacterBody2D
	var best_distance_squared := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_body := enemy as CharacterBody2D
		if not is_instance_valid(enemy_body) or not enemy_body.visible:
			continue
		if _hit_enemies.has(enemy_body.get_instance_id()):
			continue
		var health := enemy_body.get_node_or_null("HealthComponent") as HealthComponent
		if health and not health.is_alive():
			continue
		var distance_squared := global_position.distance_squared_to(enemy_body.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best = enemy_body
	return best
