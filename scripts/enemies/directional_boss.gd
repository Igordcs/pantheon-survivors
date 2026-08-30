extends EnemyBase
class_name DirectionalBoss
## Shared movement, directional visuals and lifecycle for sprite-based bosses.

signal died

@export var boss_data: EnemyData
@export_dir var sprite_directory: String
@export var visual_height: float = 120.0
@export var contact_radius: float = 44.0
@export var contact_cooldown: float = 0.8

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D

var _player: CharacterBody2D
var _directional_sprites: Dictionary = {}
var _is_dying: bool = false
var _contact_timer: float = 0.0


func _ready() -> void:
	_directional_sprites = DirectionalSpriteHelper.load_directory(sprite_directory)
	_apply_direction(Vector2.DOWN)
	health_component.max_health = boss_data.max_health
	health_component.reset()
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	_player = _find_player()

	var final_scale := scale
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", final_scale, 0.85).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	ScreenShake.shake(0.35)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if _process_petrification(delta):
		return
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			velocity = Vector2.ZERO
			return

	_contact_timer = maxf(_contact_timer - delta, 0.0)
	_tick_behavior(delta)
	_process_contact_damage()


func _tick_behavior(_delta: float) -> void:
	pass


func chase_player(speed_multiplier: float = 1.0) -> void:
	if not is_instance_valid(_player):
		velocity = Vector2.ZERO
		return
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * boss_data.speed * speed_multiplier
	move_and_slide()
	_apply_direction(direction)


func stop_movement() -> void:
	velocity = Vector2.ZERO


func get_player() -> CharacterBody2D:
	return _player


func damage_player(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_player):
		return
	var health := _player.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(amount, source_position if source_position != Vector2.ZERO else global_position)


func is_player_inside_radius(center: Vector2, radius: float) -> bool:
	return is_instance_valid(_player) and _player.global_position.distance_squared_to(center) <= radius * radius


func _apply_direction(direction: Vector2) -> void:
	var texture := DirectionalSpriteHelper.get_sprite(_directional_sprites, direction)
	if texture == null or sprite.texture == texture:
		return
	sprite.texture = texture
	var texture_height := float(texture.get_height())
	if texture_height > 0.0:
		sprite.scale = Vector2.ONE * visual_height / texture_height


func _process_contact_damage() -> void:
	if _contact_timer > 0.0 or not is_instance_valid(_player):
		return
	if global_position.distance_squared_to(_player.global_position) > contact_radius * contact_radius:
		return
	damage_player(boss_data.contact_damage)
	_contact_timer = contact_cooldown


func _on_damaged(_amount: float, _source_position: Vector2) -> void:
	if _is_dying:
		return
	sprite.self_modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.14)


func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	stop_movement()
	_cleanup_behavior()
	ScreenShake.shake(1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "self_modulate", Color(1.0, 0.4, 0.25), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func() -> void:
		died.emit()
		queue_free()
	)


func _cleanup_behavior() -> void:
	pass


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
