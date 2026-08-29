extends Area2D
## EnemyProjectile — Projétil disparado por inimigos ranged. Atinge o Player.

var direction: Vector2 = Vector2.ZERO
var speed: float = 300.0
var damage: float = 8.0
var max_distance: float = 600.0
var _distance_traveled: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var motion := direction * speed * delta
	position += motion
	_distance_traveled += motion.length()
	if _distance_traveled >= max_distance:
		queue_free()


func setup(dir: Vector2, spd: float, dmg: float, max_dist: float = 600.0) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	max_distance = max_dist
	rotation = direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(damage, global_position)
	queue_free()
