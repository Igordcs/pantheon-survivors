extends CharacterBody2D
## BasicEnemy — persegue o Player, causa dano de contato.

@export var enemy_data: EnemyData

var _player: CharacterBody2D
var _contact_cooldown: float = 0.0
const CONTACT_COOLDOWN_TIME: float = 0.5

var _knockback_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	_player = _find_player()
	# Sync health from EnemyData
	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		if enemy_data:
			health.max_health = enemy_data.max_health
		health.reset()
		health.damaged.connect(_on_damaged)


func _on_damaged(_amount: float, source_pos: Vector2) -> void:
	# Hit Flash
	var tween = create_tween()
	$AnimatedSprite2D.modulate = Color.WHITE
	tween.tween_property($AnimatedSprite2D, "modulate", Color(1, 0.3, 0.3, 1), 0.15)
	
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
	
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	velocity = (direction * spd) + _knockback_velocity
	
	move_and_slide()

	# Flip sprite to face player
	if direction.x != 0.0:
		$AnimatedSprite2D.flip_h = direction.x < 0.0

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
	# Reset health
	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		if enemy_data:
			health.max_health = enemy_data.max_health
		health.reset()
	# Reset sprite color
	_player = _find_player()


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null
