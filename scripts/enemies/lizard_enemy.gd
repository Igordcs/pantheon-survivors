extends EnemyBase
class_name LizardEnemy
## Inimigo terrestre veloz. Morde de mandíbula aberta quando desce na direção do jogador.

@export var enemy_data: EnemyData
@export var bite_distance: float = 38.0
@export var bite_cooldown: float = 2.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _facing_right: bool = true
var _is_biting: bool = false
var _bite_timer: float = 0.0
var _contact_damage_timer: float = 0.0

const ROW_FRONT := 0
const ROW_BACK := 1
const ROW_SIDE := 2
const ROW_BITE := 3
const CONTACT_DAMAGE_INTERVAL := 0.5


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
	var dist := to_player.length()
	var dir := to_player.normalized()

	_bite_timer = maxf(_bite_timer - delta, 0.0)
	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)

	# Só desfere a mordidela se estiver a descer (dir.y > 0.4) e próximo
	var is_heading_down := dir.y > 0.4 and absf(dir.x) < 0.75
	if not _is_biting and _bite_timer <= 0.0 and dist <= bite_distance and is_heading_down:
		_start_bite()

	var move_speed := enemy_data.speed if enemy_data else 75.0
	if _is_biting:
		move_speed *= 0.35

	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	velocity = dir * move_speed + _knockback_velocity
	move_and_slide()

	# Aplica dano contínuo ao encostar
	_check_contact_damage()

	_animate(dir, delta)


func _check_contact_damage() -> void:
	if _contact_damage_timer > 0.0:
		return

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider() as Node2D
		if collider and collider.is_in_group("player"):
			_deal_damage_to(collider)
			_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
			break


func _start_bite() -> void:
	_is_biting = true
	_bite_timer = bite_cooldown
	_anim_frame = 0
	_anim_timer = 0.0

	# Causa dano no momento do bote caso o jogador continue no alcance
	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= bite_distance:
		_deal_damage_to(_player)

	var bite_duration := 0.42
	var timer := get_tree().create_timer(bite_duration)
	timer.timeout.connect(func():
		_is_biting = false
	)


func _deal_damage_to(target: Node2D) -> void:
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		var dmg := enemy_data.contact_damage if enemy_data else 10.0
		health.take_damage(dmg, global_position)


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_is_biting = false
	_bite_timer = 0.5
	_contact_damage_timer = 0.0
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


func _animate(dir_vector: Vector2, delta: float) -> void:
	# 1. Mordidela frontal (Linha 3)
	if _is_biting:
		sprite.flip_h = false
		_anim_timer += delta * 10.0
		var bite_frame := mini(int(_anim_timer), 3)
		sprite.frame = (ROW_BITE * 4) + bite_frame
		return

	var is_moving := velocity.length() > 5.0
	if is_moving:
		_anim_timer += delta * 7.5
		if _anim_timer >= 1.0:
			_anim_timer = 0.0
			_anim_frame = (_anim_frame + 1) % 4
	else:
		_anim_frame = 0

	# 2. Movimento Lateral (Linha 2, desenhada para a DIREITA)
	if absf(dir_vector.x) > absf(dir_vector.y) * 0.6:
		if absf(dir_vector.x) > 0.05:
			_facing_right = dir_vector.x > 0.0

		sprite.flip_h = not _facing_right
		sprite.frame = (ROW_SIDE * 4) + _anim_frame

	# 3. Subir / Costas (Linha 1)
	elif dir_vector.y < 0.0:
		sprite.flip_h = false
		sprite.frame = (ROW_BACK * 4) + _anim_frame

	# 4. Descer / Frente (Linha 0)
	else:
		sprite.flip_h = false
		sprite.frame = (ROW_FRONT * 4) + _anim_frame


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
