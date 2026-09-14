extends EnemyBase
## Mobile late-run elite with a locked, clearly telegraphed charge.

enum State { CHASING, WINDUP, CHARGING, RECOVERING }

@export var enemy_data: EnemyData
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _state := State.CHASING
var _state_timer := 0.0
var _charge_direction := Vector2.DOWN
var _contact_timer := 0.0
var _telegraph: Line2D
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
	_state_timer -= delta
	_contact_timer = maxf(_contact_timer - delta, 0.0)
	match _state:
		State.CHASING:
			var direction := global_position.direction_to(_player.global_position)
			_walk_time += delta
			_update_sprite(direction, _walk_time)
			velocity = direction * enemy_data.speed + _knockback_velocity
			if _state_timer <= 0.0:
				_start_windup(direction)
		State.WINDUP:
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_clear_telegraph()
				_state = State.CHARGING
				_state_timer = 0.65
				sprite.modulate = Color.WHITE
		State.CHARGING:
			velocity = _charge_direction * enemy_data.charge_speed
			if _state_timer <= 0.0:
				_state = State.RECOVERING
				_state_timer = 0.45
		State.RECOVERING:
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_state = State.CHASING
				_state_timer = enemy_data.charge_cooldown
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 12.0 * delta)
	move_and_slide()
	_damage_player()


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_reset_combat_effects()
	_clear_telegraph()
	_player = _find_player()
	_state = State.CHASING
	_state_timer = enemy_data.charge_cooldown
	_contact_timer = 0.0
	_walk_time = 0.0
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE
	_apply_data()


func _start_windup(direction: Vector2) -> void:
	_state = State.WINDUP
	_state_timer = enemy_data.charge_windup
	_charge_direction = direction.normalized()
	velocity = Vector2.ZERO
	sprite.modulate = Color(0.82, 0.38, 1.0)
	_telegraph = Line2D.new()
	_telegraph.width = 38.0
	_telegraph.default_color = Color(0.75, 0.12, 0.9, 0.28)
	_telegraph.z_index = 2
	get_tree().current_scene.add_child(_telegraph)
	_telegraph.points = PackedVector2Array([global_position, global_position + _charge_direction * 320.0])


func _damage_player() -> void:
	if _contact_timer > 0.0 or global_position.distance_squared_to(_player.global_position) > 38.0 * 38.0:
		return
	var health := _player.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(enemy_data.charge_damage if _state == State.CHARGING else enemy_data.contact_damage, global_position)
		_contact_timer = 0.7


func _on_damaged(_amount: float, source_position: Vector2) -> void:
	if source_position != Vector2.ZERO and _state != State.CHARGING:
		apply_knockback_from(source_position)


func _apply_data() -> void:
	health_component.max_health = enemy_data.max_health
	health_component.reset()
	_update_sprite(Vector2.DOWN)


func _update_sprite(direction: Vector2, animation_time: float = 0.0) -> void:
	var frame_index := int(animation_time * enemy_data.walk_animation_speed)
	var texture := enemy_data.get_walk_frame(direction, frame_index) \
		if enemy_data.has_walk_animation() else enemy_data.get_directional_sprite(direction)
	if texture:
		sprite.texture = texture
		var largest := maxf(texture.get_width(), texture.get_height())
		if largest > 0.0:
			sprite.scale = Vector2.ONE * enemy_data.visual_size / largest


func _clear_telegraph() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
