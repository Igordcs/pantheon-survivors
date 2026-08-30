extends EnemyBase
## Ranged pursuit using the same eight-direction visual resources as melee enemies.

@export var enemy_data: EnemyData

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

const FLEE_DISTANCE := 150.0
const PREFERRED_DISTANCE := 300.0
const PROJECTILE_SCENE := preload("res://scenes/weapons/enemy_projectile.tscn")

var _player: CharacterBody2D
var _attack_timer: float = 0.0


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
	var distance := global_position.distance_to(_player.global_position)
	_update_sprite(direction)
	if distance < FLEE_DISTANCE:
		velocity = -direction * enemy_data.speed * 1.2
	elif distance > PREFERRED_DISTANCE + 50.0:
		velocity = direction * enemy_data.speed
	else:
		velocity = Vector2.ZERO
	velocity += _knockback_velocity
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	move_and_slide()

	_attack_timer -= delta
	if _attack_timer <= 0.0 and distance <= enemy_data.attack_range:
		_fire(direction)
		_attack_timer = enemy_data.attack_cooldown


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_reset_combat_effects()
	_player = _find_player()
	_apply_enemy_data()
	sprite.modulate = Color.WHITE


func _apply_enemy_data() -> void:
	health_component.max_health = enemy_data.max_health
	health_component.reset()
	_attack_timer = enemy_data.attack_cooldown
	_update_sprite(Vector2.DOWN)


func _update_sprite(direction: Vector2) -> void:
	var texture := enemy_data.get_directional_sprite(direction)
	if not texture or texture == sprite.texture:
		return
	sprite.texture = texture
	var largest := maxf(texture.get_width(), texture.get_height())
	if largest > 0.0:
		sprite.scale = Vector2.ONE * enemy_data.visual_size / largest


func _fire(direction: Vector2) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Area2D
	projectile.global_position = global_position
	projectile.setup(direction, enemy_data.projectile_speed, enemy_data.projectile_damage, 650.0)
	projectile.set_status_effect(
		enemy_data.projectile_slow_multiplier,
		enemy_data.projectile_slow_duration
	)
	get_tree().current_scene.add_child(projectile)


func _on_damaged(_amount: float, source_pos: Vector2) -> void:
	var tween := create_tween()
	sprite.modulate = Color(1.0, 0.35, 0.35)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if source_pos != Vector2.ZERO:
		apply_knockback_from(source_pos)


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
