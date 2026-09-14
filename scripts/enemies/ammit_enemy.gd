extends EnemyBase
## Slow late-run tank with strong knockback resistance.

@export var enemy_data: EnemyData
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _contact_timer := 0.0
var _walk_time := 0.0


func _ready() -> void:
	_player = _find_player()
	health_component.damaged.connect(_on_damaged)
	_apply_data()


func _physics_process(delta: float) -> void:
	if _process_petrification(delta):
		return
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return
	_contact_timer = maxf(_contact_timer - delta, 0.0)
	var direction := global_position.direction_to(_player.global_position)
	_walk_time += delta
	_update_sprite(direction, _walk_time)
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 12.0 * delta)
	velocity = direction * enemy_data.speed + _knockback_velocity
	move_and_slide()
	if _contact_timer <= 0.0 and global_position.distance_squared_to(_player.global_position) <= 42.0 * 42.0:
		var health := _player.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(enemy_data.contact_damage, global_position)
			_contact_timer = 0.8


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_contact_timer = 0.0
	_walk_time = 0.0
	_reset_combat_effects()
	_player = _find_player()
	_apply_data()
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE


func _on_damaged(_amount: float, source_position: Vector2) -> void:
	sprite.modulate = Color(1.0, 0.42, 0.35)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.14)
	if source_position != Vector2.ZERO:
		apply_knockback_from(source_position, 80.0)


func _apply_data() -> void:
	health_component.max_health = enemy_data.max_health
	health_component.reset()
	_update_sprite(Vector2.DOWN)


func _update_sprite(direction: Vector2, animation_time: float = 0.0) -> void:
	var frame_index := int(animation_time * enemy_data.walk_animation_speed)
	var texture := enemy_data.get_walk_frame(direction, frame_index) \
		if enemy_data.has_walk_animation() else enemy_data.get_directional_sprite(direction)
	if not texture:
		return
	sprite.texture = texture
	var largest := maxf(texture.get_width(), texture.get_height())
	if largest > 0.0:
		sprite.scale = Vector2.ONE * enemy_data.visual_size / largest


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
