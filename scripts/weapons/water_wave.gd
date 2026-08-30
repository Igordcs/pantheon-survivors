extends Area2D
## Onda perfurante do Tridente de Poseidon.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 420.0
var damage: float = 22.0
var max_distance: float = 350.0
var knockback_force: float = 260.0

var _distance_traveled: float = 0.0
var _hit_enemies: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(
	dir: Vector2,
	projectile_speed: float,
	wave_damage: float,
	distance: float,
	push_force: float,
	wave_scale: float
) -> void:
	direction = dir.normalized()
	speed = projectile_speed
	damage = wave_damage
	max_distance = distance
	knockback_force = push_force
	rotation = direction.angle()
	scale = Vector2.ONE * wave_scale


func _physics_process(delta: float) -> void:
	var motion := direction * speed * delta
	position += motion
	_distance_traveled += motion.length()
	if _distance_traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or not body.visible:
		return
	var instance_id := body.get_instance_id()
	if _hit_enemies.has(instance_id):
		return
	_hit_enemies[instance_id] = true

	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(damage)
		if body.has_method("apply_knockback_from"):
			body.apply_knockback_from(global_position - direction * 32.0, knockback_force)
		ScreenShake.shake(0.12)
