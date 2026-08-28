extends CharacterBody2D
## BasicEnemy — persegue o Player, causa dano de contato.

@export var enemy_data: EnemyData

var _player: CharacterBody2D
var _contact_cooldown: float = 0.0
const CONTACT_COOLDOWN_TIME: float = 0.5


func _ready() -> void:
	_player = _find_player()
	# Sync health from EnemyData
	if enemy_data:
		var health := get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.max_health = enemy_data.max_health
			health.reset()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return

	var spd := enemy_data.speed if enemy_data else 80.0
	var direction := global_position.direction_to(_player.global_position)
	velocity = direction * spd
	move_and_slide()

	# Flip sprite to face player
	if direction.x != 0.0:
		$Sprite2D.flip_h = direction.x < 0.0

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
	$Sprite2D.modulate = Color(1, 0.3, 0.3, 1)
	_player = _find_player()


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null
