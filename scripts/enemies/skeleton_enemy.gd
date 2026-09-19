extends EnemyBase
class_name SkeletonEnemy
## Inimigo esqueleto básico (horda) usando frames manuais da sprite sheet 8x8.

@export var enemy_data: EnemyData
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _contact_timer: float = 0.0
var _anim_timer: float = 0.0
var _walk_index: int = 0

# Mapeamento estrito dos frames da folha 8x8
const FRAME_IDLE_DOWN: int = 0
const FRAMES_WALK_DOWN: Array[int] = [8, 16]

const FRAME_IDLE_UP: int = 26
const FRAMES_WALK_UP: Array[int] = [24, 25]

const FRAMES_WALK_SIDE: Array[int] = [44, 45]


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

	_contact_timer = maxf(_contact_timer - delta, 0.0)
	var direction := global_position.direction_to(_player.global_position)
	
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 12.0 * delta)
	var move_speed := enemy_data.speed if enemy_data else 65.0
	velocity = direction * move_speed + _knockback_velocity
	move_and_slide()

	_animate_walk(direction, delta)

	# Dano de contato
	if _contact_timer <= 0.0 and global_position.distance_squared_to(_player.global_position) <= 32.0 * 32.0:
		var health := _player.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			var damage := enemy_data.contact_damage if enemy_data else 8.0
			health.take_damage(damage, global_position)
			_contact_timer = 0.6


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_contact_timer = 0.0
	_anim_timer = 0.0
	_walk_index = 0
	_reset_combat_effects()
	_player = _find_player()
	_apply_data()
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE


func _on_damaged(_amount: float, source_position: Vector2) -> void:
	sprite.modulate = Color(1.0, 0.4, 0.35)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if source_position != Vector2.ZERO:
		apply_knockback_from(source_position, 100.0)


func _apply_data() -> void:
	if not enemy_data:
		return
	if health_component:
		health_component.max_health = enemy_data.max_health
		health_component.reset()


func _animate_walk(direction: Vector2, delta: float) -> void:
	var is_moving := velocity.length() > 5.0

	if is_moving:
		_anim_timer += delta * 6.5
		if _anim_timer >= 1.0:
			_anim_timer = 0.0
			_walk_index = (_walk_index + 1) % 2
	else:
		_walk_index = 0

	# 1. Movimento Lateral
	if absf(direction.x) > absf(direction.y) * 0.7:
		# Frames 44 e 45 estão voltados para a ESQUERDA no sprite sheet:
		# Para andar para a direita, espelha (flip_h = true).
		# Para andar para a esquerda, usa o original (flip_h = false).
		sprite.flip_h = direction.x > 0.0
		
		if is_moving:
			sprite.frame = FRAMES_WALK_SIDE[_walk_index]
		else:
			sprite.frame = FRAMES_WALK_SIDE[0]

	# 2. Subir / Costas
	elif direction.y < 0.0:
		sprite.flip_h = false
		if is_moving:
			sprite.frame = FRAMES_WALK_UP[_walk_index]
		else:
			sprite.frame = FRAME_IDLE_UP

	# 3. Descer / Frente
	else:
		sprite.flip_h = false
		if is_moving:
			sprite.frame = FRAMES_WALK_DOWN[_walk_index]
		else:
			sprite.frame = FRAME_IDLE_DOWN

func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
