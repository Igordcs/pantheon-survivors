extends Area2D
## Bala do Punisher — viaja em alta velocidade com rastro brilhante e impacto visceral.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 18.0
var max_distance: float = 600.0

var _distance_traveled: float = 0.0
var _hit: bool = false
var _trail: Line2D
var _trail_points: Array[Vector2] = []
const TRAIL_LENGTH := 7

@onready var bullet_visual: Node2D = $BulletVisual if has_node("BulletVisual") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null


func _ready() -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.global_position = Vector2.ZERO
	_trail.width = 4.5
	_trail.default_color = Color(1.0, 0.85, 0.35, 0.75)
	_trail.z_index = 2
	
	# Gradiente de cor no rastro: quente na cabeça, desvanecendo na cauda
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.4, 0.1, 0.0),
		Color(1.0, 0.85, 0.3, 0.6),
		Color(1.0, 0.98, 0.7, 0.9)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_trail.gradient = grad
	
	add_child(_trail)


func _physics_process(delta: float) -> void:
	if _hit:
		return

	var step := speed * delta
	global_position += direction * step
	_distance_traveled += step
	rotation = direction.angle()

	# Atualiza pontos do rastro
	_trail_points.push_front(global_position)
	if _trail_points.size() > TRAIL_LENGTH:
		_trail_points.pop_back()
	_trail.points = PackedVector2Array(_trail_points)

	if _distance_traveled >= max_distance:
		_fade_and_free()
		return

	_check_hits()


func setup(dir: Vector2, spd: float, dmg: float, max_dist: float) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	max_distance = max_dist
	_distance_traveled = 0.0
	_hit = false


func _check_hits() -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("enemies") or not body.visible:
			continue
		var enemy := body as CharacterBody2D
		if not is_instance_valid(enemy):
			continue
		var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue

		health.take_damage(damage, global_position)
		_hit = true
		_on_bullet_impact(enemy)
		return


func _on_bullet_impact(enemy: CharacterBody2D) -> void:
	# Efeitos visuais do impacto
	_spawn_impact_vfx()

	# Flash rápido no inimigo atingido
	_flash_enemy(enemy)

	# Desativa visual e colisão da bala
	if bullet_visual:
		bullet_visual.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Rastro some de forma suave
	if _trail:
		var tween := create_tween()
		tween.tween_property(_trail, "modulate:a", 0.0, 0.08)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func _flash_enemy(enemy: CharacterBody2D) -> void:
	if not is_instance_valid(enemy):
		return
	var sprite := enemy.get_node_or_null("Sprite2D") as CanvasItem
	if not sprite:
		sprite = enemy.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sprite:
		var original_modulate := sprite.modulate
		sprite.modulate = Color(2.0, 1.8, 1.2, 1.0) # Flash incandescente
		var flash_tween := sprite.create_tween()
		flash_tween.tween_property(sprite, "modulate", original_modulate, 0.1)


func _spawn_impact_vfx() -> void:
	# Faíscas que saltam do ponto de impacto na direção oposta ao tiro
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.22
	particles.speed_scale = 1.8
	particles.direction = -direction
	particles.spread = 55.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 220.0
	particles.gravity = Vector2(0, 300)
	particles.color = Color(1.0, 0.9, 0.35, 1.0)
	particles.scale_amount_min = 1.8
	particles.scale_amount_max = 2.8
	particles.global_position = global_position
	get_tree().current_scene.add_child(particles)

	# Flash circular de impacto que expande rapidamente
	var ring := Line2D.new()
	ring.default_color = Color(1.0, 0.95, 0.6, 0.9)
	ring.width = 3.5
	for i in range(11):
		ring.add_point(Vector2.from_angle(TAU * float(i) / 10.0) * 8.0)
	ring.global_position = global_position
	ring.z_index = 6
	get_tree().current_scene.add_child(ring)

	var ring_tween := ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2.ONE * 2.2, 0.08)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.08)
	ring_tween.chain().tween_callback(ring.queue_free)

	# Limpeza das partículas
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(particles.queue_free)


func _fade_and_free() -> void:
	_hit = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.tween_callback(queue_free)
