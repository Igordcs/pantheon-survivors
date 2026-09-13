extends Area2D
## Granada do Punisher — viaja até o alvo em arco parabólico e detona causando dano em área com VFX.

const EXPLOSION_SPRITESHEET = preload("res://assets/vfx/explosion_.png")
const EXPLOSION_FRAMES := 9
const EXPLOSION_FRAME_SIZE := 40

var direction: Vector2 = Vector2.RIGHT
var speed: float = 350.0
var damage: float = 45.0
var explosion_radius: float = 80.0
var target_distance: float = 200.0

var _distance_traveled: float = 0.0
var _exploded: bool = false
var _visual: Node2D


func _ready() -> void:
	_visual = $GrenadeVisual if has_node("GrenadeVisual") else null


func _physics_process(delta: float) -> void:
	if _exploded:
		return

	var step := speed * delta
	global_position += direction * step
	_distance_traveled += step

	# Simula arco parabólico e rotação da granada no ar
	if _visual:
		var progress := clampf(_distance_traveled / maxf(target_distance, 1.0), 0.0, 1.0)
		var arc_height := sin(progress * PI) * 0.6
		_visual.position.y = -arc_height * 32.0
		_visual.scale = Vector2.ONE * (1.0 + arc_height * 0.3)
		_visual.rotation += 12.0 * delta

	if _distance_traveled >= target_distance:
		_explode()


func setup(dir: Vector2, spd: float, dmg: float, radius: float, target_dist: float) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	explosion_radius = radius
	target_distance = target_dist
	_distance_traveled = 0.0
	_exploded = false


func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	# Esconde o visual da granada
	if _visual:
		_visual.visible = false

	# Som da explosão
	var music_mgr := get_tree().root.get_node_or_null("MusicManager")
	if music_mgr and music_mgr.has_method("play_grenade_explosion_sfx"):
		music_mgr.play_grenade_explosion_sfx()

	# Dano em área
	_deal_area_damage()

	# VFX de explosão com spritesheet
	_spawn_explosion_vfx()

	# Onda de choque e partículas
	_spawn_shockwave_vfx()
	_spawn_blast_particles()

	# Remove a granada após a animação
	var cleanup_timer := get_tree().create_timer(1.0)
	cleanup_timer.timeout.connect(queue_free)


func _deal_area_damage() -> void:
	var radius_squared := explosion_radius * explosion_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_body := enemy as CharacterBody2D
		if not enemy_body or not enemy_body.visible:
			continue
		if global_position.distance_squared_to(enemy_body.global_position) > radius_squared:
			continue
		var health := enemy_body.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue

		# Dano diminui com distância (centro = 100%, borda = 50%)
		var dist_ratio := global_position.distance_to(enemy_body.global_position) / explosion_radius
		var damage_multiplier := lerpf(1.0, 0.5, dist_ratio)
		health.take_damage(damage * damage_multiplier, global_position)


func _spawn_explosion_vfx() -> void:
	var explosion := Sprite2D.new()
	explosion.texture = EXPLOSION_SPRITESHEET
	explosion.hframes = EXPLOSION_FRAMES
	explosion.vframes = 1
	explosion.frame = 0
	explosion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	explosion.z_index = 12
	explosion.global_position = global_position

	var frame_pixel_size := float(EXPLOSION_FRAME_SIZE)
	var desired_size := explosion_radius * 2.2
	var scale_factor := desired_size / frame_pixel_size
	explosion.scale = Vector2.ONE * scale_factor
	get_tree().current_scene.add_child(explosion)

	# Anima frame por frame
	var tween := explosion.create_tween()
	for frame_index in range(EXPLOSION_FRAMES):
		tween.tween_callback(func():
			if is_instance_valid(explosion):
				explosion.frame = frame_index
		)
		tween.tween_interval(0.05)
	tween.tween_property(explosion, "modulate:a", 0.0, 0.12)
	tween.tween_callback(explosion.queue_free)


func _spawn_shockwave_vfx() -> void:
	var ring := Line2D.new()
	ring.default_color = Color(1.0, 0.7, 0.2, 0.85)
	ring.width = 4.0
	for i in range(17):
		ring.add_point(Vector2.from_angle(TAU * float(i) / 16.0) * 10.0)
	ring.global_position = global_position
	ring.z_index = 11
	get_tree().current_scene.add_child(ring)

	var tween := ring.create_tween()
	tween.set_parallel(true)
	var max_scale: float = explosion_radius / 10.0
	tween.tween_property(ring, "scale", Vector2.ONE * max_scale, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.28)
	tween.tween_property(ring, "width", 1.0, 0.28)
	tween.chain().tween_callback(ring.queue_free)


func _spawn_blast_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 22
	particles.lifetime = 0.4
	particles.speed_scale = 1.6
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 160.0
	particles.gravity = Vector2(0, 150)
	particles.color = Color(1.0, 0.75, 0.2, 1.0)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 3.5
	particles.global_position = global_position
	particles.z_index = 10
	get_tree().current_scene.add_child(particles)

	var timer := get_tree().create_timer(0.7)
	timer.timeout.connect(particles.queue_free)
