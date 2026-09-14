extends EnemyBase
class_name MedusaEnemy
## Caçadora corpo a corpo que ocasionalmente petrifica o jogador em um cone curto.

enum State { CHASING, TELEGRAPHING, RECOVERING }

const CONE_COLOR := Color(0.25, 0.95, 0.55, 0.42)
const CONE_ANGLE_DEGREES := 55.0
const CONE_RANGE := 105.0
const TELEGRAPH_DURATION := 0.5
const RECOVERY_DURATION := 0.45

@export var enemy_data: EnemyData

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _state := State.CHASING
var _state_timer := 0.0
var _power_cooldown := 0.0
var _contact_cooldown := 0.0
var _locked_direction := Vector2.DOWN


func _ready() -> void:
	_player = _find_player()
	health_component.damaged.connect(_on_damaged)
	_apply_data()


func _physics_process(delta: float) -> void:
	if _process_petrification(delta):
		return
	if not is_instance_valid(_player):
		_player = _find_player()
		if not _player:
			return
	_power_cooldown = maxf(_power_cooldown - delta, 0.0)
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	_state_timer -= delta
	match _state:
		State.CHASING:
			_chase_player(delta)
			if _power_cooldown <= 0.0 and global_position.distance_to(_player.global_position) <= CONE_RANGE:
				_begin_petrifying_gaze()
		State.TELEGRAPHING:
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_release_petrifying_gaze()
		State.RECOVERING:
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_state = State.CHASING
	_damage_player_on_contact()


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_reset_combat_effects()
	_player = _find_player()
	_state = State.CHASING
	_state_timer = 0.0
	_contact_cooldown = 0.0
	_apply_data()
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE


func _apply_data() -> void:
	health_component.max_health = enemy_data.max_health
	health_component.reset()
	_power_cooldown = enemy_data.attack_cooldown
	_update_sprite(Vector2.DOWN)


func _chase_player(delta: float) -> void:
	var direction := global_position.direction_to(_player.global_position)
	_locked_direction = direction if not direction.is_zero_approx() else _locked_direction
	velocity = direction * enemy_data.speed + _knockback_velocity
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	move_and_slide()
	_update_sprite(direction)


func _begin_petrifying_gaze() -> void:
	_state = State.TELEGRAPHING
	_state_timer = TELEGRAPH_DURATION
	_locked_direction = global_position.direction_to(_player.global_position)
	velocity = Vector2.ZERO
	_spawn_cone(CONE_COLOR)


func _release_petrifying_gaze() -> void:
	MusicManager.play_medusa_sfx()
	if _is_player_inside_cone():
		var health := _player.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(enemy_data.projectile_damage, global_position)
		if _player.has_method("apply_petrification"):
			_player.apply_petrification(enemy_data.projectile_slow_duration)
	_spawn_cone(Color(0.4, 1.0, 0.65, 0.72), 0.2)
	_power_cooldown = enemy_data.attack_cooldown
	_state = State.RECOVERING
	_state_timer = RECOVERY_DURATION


func _is_player_inside_cone() -> bool:
	var offset := _player.global_position - global_position
	if offset.length_squared() > CONE_RANGE * CONE_RANGE:
		return false
	if offset.is_zero_approx():
		return true
	var minimum_dot := cos(deg_to_rad(CONE_ANGLE_DEGREES * 0.5))
	return _locked_direction.dot(offset.normalized()) >= minimum_dot


func _spawn_cone(color: Color, duration: float = TELEGRAPH_DURATION) -> void:
	var cone := Polygon2D.new()
	var points := PackedVector2Array([Vector2.ZERO])
	var facing_angle := _locked_direction.angle()
	var half_angle := deg_to_rad(CONE_ANGLE_DEGREES * 0.5)
	for index in range(11):
		var angle := lerpf(-half_angle, half_angle, float(index) / 10.0) + facing_angle
		points.append(Vector2.from_angle(angle) * CONE_RANGE)
	cone.polygon = points
	cone.color = color
	cone.z_index = 3
	add_child(cone)
	var tween := cone.create_tween()
	tween.tween_property(cone, "modulate:a", 0.0, duration)
	tween.tween_callback(cone.queue_free)


func _damage_player_on_contact() -> void:
	if _contact_cooldown > 0.0 or global_position.distance_to(_player.global_position) > 28.0:
		return
	var health := _player.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(enemy_data.contact_damage, global_position)
		_contact_cooldown = 0.6


func _update_sprite(direction: Vector2) -> void:
	var texture := enemy_data.get_directional_sprite(direction)
	if not texture or texture == sprite.texture:
		return
	sprite.texture = texture
	var largest := maxf(texture.get_width(), texture.get_height())
	if largest > 0.0:
		sprite.scale = Vector2.ONE * enemy_data.visual_size / largest


func _on_damaged(_amount: float, source_position: Vector2) -> void:
	sprite.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if source_position != Vector2.ZERO and _state == State.CHASING:
		apply_knockback_from(source_position)

