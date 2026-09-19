extends Area2D
class_name WarlockProjectile

@export var speed: float = 140.0
@export var damage: float = 12.0
@export var lifetime: float = 4.0
@export var freeze_duration: float = 1.2

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(damage, global_position)

	_apply_freeze(body)
	queue_free()


func _apply_freeze(target: Node2D) -> void:
	if target is CharacterBody2D:
		var cb := target as CharacterBody2D
		cb.set_physics_process(false)

		var player_sprite: CanvasItem = cb.get_node_or_null("Sprite2D")
		if player_sprite:
			player_sprite.modulate = Color(0.4, 0.9, 1.5)

		var freeze_timer := cb.get_tree().create_timer(freeze_duration)
		freeze_timer.timeout.connect(func():
			if is_instance_valid(cb):
				cb.set_physics_process(true)
				if player_sprite:
					player_sprite.modulate = Color.WHITE
		)
