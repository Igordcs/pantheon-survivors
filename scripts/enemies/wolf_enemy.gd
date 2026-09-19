extends EnemyBase
class_name WolfEnemy

@export var enemy_data: EnemyData

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _anim_timer: float = 0.0
var _anim_frame: int = 0

const ROW_FRONT := 0
const ROW_BACK := 1
const ROW_SIDE := 2
const ROW_AGGRESSIVE_SIDE := 3


func _ready() -> void:
	_player = _find_player()
	if health_component:
		health_component.damaged.connect(_on_damaged)
	_apply_data()


func _physics_process(delta: float) -> void:
	if _process_petrification(delta):
		return

	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return

	var to_player := _player.global_position - global_position
	var dir := to_player.normalized()

	_animate_walk(dir, delta)

	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	var move_speed := enemy_data.speed if enemy_data else 85.0
	velocity = dir * move_speed + _knockback_velocity
	move_and_slide()


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_reset_combat_effects()
	_player = _find_player()
	_apply_data()
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE


func _on_damaged(_amount: float, source_position: Vector2) -> void:
	sprite.modulate = Color(1.0, 0.4, 0.35)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if source_position != Vector2.ZERO:
		apply_knockback_from(source_position, 80.0)


func _apply_data() -> void:
	if not enemy_data:
		return
	if health_component:
		health_component.max_health = enemy_data.max_health
		health_component.reset()


func _animate_walk(direction: Vector2, delta: float) -> void:
	_anim_timer += delta * 10.0
	if _anim_timer >= 1.0:
		_anim_timer = 0.0
		_anim_frame = (_anim_frame + 1) % 4

	var base_row := ROW_FRONT

	if absf(direction.x) > absf(direction.y):
		base_row = ROW_AGGRESSIVE_SIDE
		sprite.flip_h = direction.x < 0.0
	elif direction.y < 0.0:
		base_row = ROW_BACK
		sprite.flip_h = false
	else:
		base_row = ROW_FRONT
		sprite.flip_h = false

	sprite.frame = (base_row * 4) + _anim_frame


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
