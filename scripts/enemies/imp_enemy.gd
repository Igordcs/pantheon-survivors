extends EnemyBase
class_name ImpEnemy
## Inimigo voador que persegue o jogador à distância e atira bolas de fogo com queimadura.

@export var enemy_data: EnemyData
@export var projectile_scene: PackedScene = preload("res://scenes/enemies/imp_fireball.tscn")
@export var attack_cooldown: float = 3.2
@export var preferred_distance: float = 145.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _attack_timer: float = 1.2
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _flight_sine_timer: float = 0.0

# Sequências de animação dedicadas por direção
const FRAMES_FRONT: Array[int] = [0, 1, 2, 3]
const FRAMES_BACK: Array[int] = [12, 13, 14, 15]
const FRAMES_LEFT: Array[int] = [4, 6, 10]
const FRAMES_RIGHT: Array[int] = [5, 8]


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

	# Manutenção de distância de voo
	var move_dir := Vector2.ZERO
	if dist > preferred_distance + 20.0:
		move_dir = dir
	elif dist < preferred_distance - 30.0:
		move_dir = -dir * 0.75

	# Flutuação vertical de bater de asas
	_flight_sine_timer += delta * 6.5
	sprite.position.y = sin(_flight_sine_timer) * 2.0

	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	var move_speed := enemy_data.speed if enemy_data else 65.0
	velocity = move_dir * move_speed + _knockback_velocity
	move_and_slide()

	_animate(dir, delta)

	# Disparo de bola de fogo
	_attack_timer -= delta
	if _attack_timer <= 0.0 and dist <= 300.0:
		_shoot_fireball(dir)
		_attack_timer = attack_cooldown


func _shoot_fireball(target_dir: Vector2) -> void:
	if not projectile_scene:
		return

	var proj := projectile_scene.instantiate()
	var container := get_tree().current_scene.get_node_or_null("World/Projectiles")
	if not container:
		container = get_tree().current_scene
	container.add_child(proj)
	
	proj.global_position = global_position + Vector2(0.0, -4.0)

	if proj.has_method("launch"):
		proj.launch(target_dir)
	elif "direction" in proj:
		proj.set("direction", target_dir)

	sprite.modulate = Color(1.8, 0.6, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_attack_timer = randf_range(1.0, 2.0)
	_reset_combat_effects()
	_player = _find_player()
	_apply_data()
	sprite.position = Vector2.ZERO
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
	# Não usamos flip_h: a folha já traz os desenhos de cada perfil
	sprite.flip_h = false

	# 1. Movimento Lateral
	if absf(dir_vector.x) > absf(dir_vector.y) * 0.6:
		if dir_vector.x < 0.0:
			# Esquerda: frames [4, 6, 10]
			_anim_timer += delta * 7.5
			if _anim_timer >= 1.0:
				_anim_timer = 0.0
				_anim_frame = (_anim_frame + 1) % FRAMES_LEFT.size()
			sprite.frame = FRAMES_LEFT[_anim_frame % FRAMES_LEFT.size()]
		else:
			# Direita: frames [5, 8]
			_anim_timer += delta * 6.0
			if _anim_timer >= 1.0:
				_anim_timer = 0.0
				_anim_frame = (_anim_frame + 1) % FRAMES_RIGHT.size()
			sprite.frame = FRAMES_RIGHT[_anim_frame % FRAMES_RIGHT.size()]

	# 2. Voo para Cima / Costas (Linha 3)
	elif dir_vector.y < 0.0:
		_anim_timer += delta * 8.5
		if _anim_timer >= 1.0:
			_anim_timer = 0.0
			_anim_frame = (_anim_frame + 1) % FRAMES_BACK.size()
		sprite.frame = FRAMES_BACK[_anim_frame % FRAMES_BACK.size()]

	# 3. Voo para Baixo / Frente (Linha 0)
	else:
		_anim_timer += delta * 8.5
		if _anim_timer >= 1.0:
			_anim_timer = 0.0
			_anim_frame = (_anim_frame + 1) % FRAMES_FRONT.size()
		sprite.frame = FRAMES_FRONT[_anim_frame % FRAMES_FRONT.size()]


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
