extends EnemyBase
## Heavy enemy that periodically winds up and charges through the player.

enum State { CHASING, WINDUP, CHARGING }

@export var enemy_data: EnemyData

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _state := State.CHASING
var _state_timer := 0.0
var _charge_direction := Vector2.ZERO
var _contact_cooldown := 0.0


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

	_state_timer -= delta
	match _state:
		State.CHASING:
			var direction := global_position.direction_to(_player.global_position)
			_update_sprite(direction)
			velocity = direction * enemy_data.speed + _knockback_velocity
			if _state_timer <= 0.0:
				_state = State.WINDUP
				_state_timer = enemy_data.charge_windup
				velocity = Vector2.ZERO
				sprite.modulate = Color(1.0, 0.55, 0.25)
		State.WINDUP:
			velocity = Vector2.ZERO
			_charge_direction = global_position.direction_to(_player.global_position)
			if _state_timer <= 0.0:
				_state = State.CHARGING
				_state_timer = 0.65
				sprite.modulate = Color.WHITE
		State.CHARGING:
			velocity = _charge_direction * enemy_data.charge_speed
			if _state_timer <= 0.0:
				_state = State.CHASING
				_state_timer = enemy_data.charge_cooldown
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	move_and_slide()
	_damage_player(delta)


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_reset_combat_effects()
	_player = _find_player()
	_state = State.CHASING
	_state_timer = enemy_data.charge_cooldown
	_contact_cooldown = 0.0
	sprite.modulate = Color.WHITE
	_apply_enemy_data()


func _apply_enemy_data() -> void:
	health_component.max_health = enemy_data.max_health
	health_component.reset()
	_update_sprite(Vector2.DOWN)


func _update_sprite(direction: Vector2) -> void:
	var texture := enemy_data.get_directional_sprite(direction)
	if texture:
		sprite.texture = texture
		var largest := maxf(texture.get_width(), texture.get_height())
		if largest > 0.0:
			sprite.scale = Vector2.ONE * enemy_data.visual_size / largest


func _damage_player(delta: float) -> void:
	_contact_cooldown -= delta
	if _contact_cooldown > 0.0 or global_position.distance_to(_player.global_position) >= 38.0:
		return
	var health := _player.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		var damage := enemy_data.charge_damage if _state == State.CHARGING else enemy_data.contact_damage
		health.take_damage(damage, global_position)
		_contact_cooldown = 0.6


func _on_damaged(_amount: float, source_pos: Vector2) -> void:
	if source_pos != Vector2.ZERO and _state != State.CHARGING:
		apply_knockback_from(source_pos)


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
