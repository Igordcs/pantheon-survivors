extends EnemyBase
## Melee pursuit for enemies whose visuals are authored as SpriteFrames.

@export var enemy_data: EnemyData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _contact_cooldown: float = 0.0
const CONTACT_COOLDOWN_TIME := 0.5


func _ready() -> void:
	_player = _find_player()
	_apply_enemy_data()
	health_component.damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	if _process_petrification(delta):
		return
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return

	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * enemy_data.speed + _knockback_velocity
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0
	if sprite.sprite_frames.has_animation(&"RUN"):
		sprite.play(&"RUN")
	move_and_slide()

	_contact_cooldown -= delta
	if _contact_cooldown <= 0.0 and global_position.distance_to(_player.global_position) < 32.0:
		var health := _player.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(enemy_data.contact_damage, global_position)
			_contact_cooldown = CONTACT_COOLDOWN_TIME


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_contact_cooldown = 0.0
	_reset_combat_effects()
	_player = _find_player()
	_apply_enemy_data()
	sprite.modulate = Color.WHITE
	if sprite.sprite_frames.has_animation(&"IDLE"):
		sprite.play(&"IDLE")


func _apply_enemy_data() -> void:
	if enemy_data:
		health_component.max_health = enemy_data.max_health
	health_component.reset()


func _on_damaged(_amount: float, source_pos: Vector2) -> void:
	var tween := create_tween()
	sprite.modulate = Color(1.0, 0.35, 0.35)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if source_pos != Vector2.ZERO:
		apply_knockback_from(source_pos)


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null

