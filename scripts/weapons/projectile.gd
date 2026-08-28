extends Area2D
## Projétil genérico — voa em direção ao alvo e causa dano no impacto.

var direction: Vector2 = Vector2.ZERO
var speed: float = 600.0
var damage: float = 15.0
var max_distance: float = 500.0
var _distance_traveled: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var motion := direction * speed * delta
	position += motion
	_distance_traveled += motion.length()
	if _distance_traveled >= max_distance:
		queue_free()


func setup(dir: Vector2, spd: float, dmg: float, max_dist: float = 500.0) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	max_distance = max_dist
	rotation = direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if not body.visible:
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(damage)
		_hit_flash(body)
	queue_free()


func _hit_flash(body: Node2D) -> void:
	var sprite := body.get_node_or_null("Sprite2D") as CanvasItem
	if not sprite:
		return
	# Tween bound to body so it survives projectile's queue_free
	var tween := body.create_tween()
	sprite.modulate = Color.WHITE
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.15)
