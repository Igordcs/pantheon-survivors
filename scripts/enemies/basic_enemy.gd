extends CharacterBody2D
## BasicEnemy — persegue o Player, causa dano de contato.

@export var enemy_data: EnemyData

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _contact_cooldown: float = 0.0
const CONTACT_COOLDOWN_TIME: float = 0.5

var _knockback_velocity: Vector2 = Vector2.ZERO
var _fallback_texture: Texture2D
var _fallback_scale: Vector2


func _ready() -> void:
	_fallback_texture = sprite.texture
	_fallback_scale = sprite.scale
	_player = _find_player()
	_apply_enemy_data()

	if health_component:
		health_component.damaged.connect(_on_damaged)


func _on_damaged(_amount: float, source_pos: Vector2) -> void:
	# Hit Flash
	var tween := create_tween()
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	# Knockback
	if source_pos != Vector2.ZERO:
		var dir = source_pos.direction_to(global_position)
		_knockback_velocity = dir * 200.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return

	var spd := enemy_data.speed if enemy_data else 80.0
	var direction := global_position.direction_to(_player.global_position)
	_update_directional_sprite(direction)
	
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	velocity = (direction * spd) + _knockback_velocity
	
	move_and_slide()

	# Contact damage
	_contact_cooldown -= delta
	if _contact_cooldown <= 0.0:
		var distance := global_position.distance_to(_player.global_position)
		if distance < 30.0:
			var player_health := _player.get_node_or_null("HealthComponent") as HealthComponent
			if player_health and player_health.is_alive():
				var dmg := enemy_data.contact_damage if enemy_data else 10.0
				player_health.take_damage(dmg)
				_contact_cooldown = CONTACT_COOLDOWN_TIME


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_contact_cooldown = 0.0
	_player = _find_player()
	_apply_enemy_data()
	sprite.modulate = Color.WHITE

	if is_instance_valid(_player):
		_update_directional_sprite(global_position.direction_to(_player.global_position))


func _apply_enemy_data() -> void:
	if health_component and enemy_data:
		health_component.max_health = enemy_data.max_health
		health_component.reset()

	sprite.flip_h = false
	sprite.modulate = Color.WHITE
	var initial_texture := enemy_data.get_directional_sprite(Vector2.DOWN) if enemy_data else null
	if initial_texture:
		sprite.texture = initial_texture
		_apply_visual_size(initial_texture)
	else:
		sprite.texture = _fallback_texture
		sprite.scale = _fallback_scale


func _update_directional_sprite(direction: Vector2) -> void:
	if not enemy_data:
		return

	var directional_texture := enemy_data.get_directional_sprite(direction)
	if directional_texture and sprite.texture != directional_texture:
		sprite.texture = directional_texture
		_apply_visual_size(directional_texture)


func _apply_visual_size(texture: Texture2D) -> void:
	var source_size := texture.get_size()
	var largest_dimension := maxf(source_size.x, source_size.y)
	if largest_dimension > 0.0:
		var target_size := enemy_data.visual_size if enemy_data else 64.0
		sprite.scale = Vector2.ONE * (target_size / largest_dimension)


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null
