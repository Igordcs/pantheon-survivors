extends EnemyBase
class_name WarlockEnemy

@export var enemy_data: EnemyData
@export var projectile_scene: PackedScene = preload("res://scenes/enemies/warlock_projectile.tscn")
@export var attack_cooldown: float = 3.2
@export var preferred_distance: float = 160.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var _player: CharacterBody2D
var _attack_timer: float = 1.0
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _is_casting: bool = false
var _facing_right: bool = true

const ROW_FRONT := 0
const ROW_BACK := 1
const ROW_SIDE := 2
const ROW_CAST := 3


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

	# IA de Distanciamento: aproxima se estiver longe, recua se o jogador colar
	var move_dir := Vector2.ZERO
	if not _is_casting:
		if dist > preferred_distance + 20.0:
			move_dir = dir
		elif dist < preferred_distance - 40.0:
			move_dir = -dir * 0.6

	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	var move_speed := enemy_data.speed if enemy_data else 55.0
	velocity = move_dir * move_speed + _knockback_velocity
	move_and_slide()

	_animate(move_dir, delta)

	# Disparo triplo de gelo
	_attack_timer -= delta
	if _attack_timer <= 0.0 and dist <= 300.0:
		_cast_triple_shot(dir)
		_attack_timer = attack_cooldown


func _cast_triple_shot(target_dir: Vector2) -> void:
	if not projectile_scene:
		return

	_is_casting = true
	sprite.position.y = 0.0
	sprite.flip_h = false
	sprite.frame = ROW_CAST * 4 + 2 # Frame erguendo o cajado com magia

	var spread_angles := [0.0, -deg_to_rad(22.0), deg_to_rad(22.0)]
	var spawn_pos := global_position + Vector2(0.0, -8.0)

	for angle_offset in spread_angles:
		var proj: Node2D = projectile_scene.instantiate()
		if not proj:
			continue
		if "direction" in proj:
			proj.set("direction", target_dir.rotated(angle_offset))
		get_tree().current_scene.add_child(proj)
		proj.global_position = spawn_pos

	var cast_timer := get_tree().create_timer(0.35)
	cast_timer.timeout.connect(func():
		_is_casting = false
	)


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_attack_timer = randf_range(1.0, 2.0)
	_is_casting = false
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
		apply_knockback_from(source_position, 90.0)


func _apply_data() -> void:
	if not enemy_data:
		return
	if health_component:
		health_component.max_health = enemy_data.max_health
		health_component.reset()


func _animate(dir_vector: Vector2, delta: float) -> void:
	if _is_casting:
		return

	var is_moving := dir_vector.length_squared() > 0.01

	if is_moving:
		_anim_timer += delta * 7.0
		if _anim_timer >= 1.0:
			_anim_timer = 0.0
			_anim_frame = (_anim_frame + 1) % 4
	else:
		_anim_frame = 0
		sprite.position.y = 0.0

	# 1. Movimento Horizontal predominante
	if absf(dir_vector.x) > absf(dir_vector.y) * 0.5:
		_facing_right = dir_vector.x > 0.0
		sprite.flip_h = not _facing_right
		sprite.frame = (ROW_SIDE * 4) + _anim_frame
		# Oscilação vertical sutil para simular o passo do manto
		sprite.position.y = -1.0 if (_anim_frame % 2 == 1 and is_moving) else 0.0

	# 2. Movimento Vertical para Cima (Costas)
	elif dir_vector.y < 0.0:
		sprite.position.y = 0.0
		sprite.flip_h = false
		sprite.frame = (ROW_BACK * 4) + _anim_frame

	# 3. Movimento Vertical para Baixo (Frente)
	else:
		sprite.position.y = 0.0
		sprite.flip_h = false
		sprite.frame = (ROW_FRONT * 4) + _anim_frame


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
