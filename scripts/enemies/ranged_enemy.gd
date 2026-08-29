extends CharacterBody2D
## RangedEnemy — Mantém distância do jogador e dispara projéteis.

@export var enemy_data: EnemyData

var _player: CharacterBody2D
var _contact_cooldown: float = 0.0
const CONTACT_COOLDOWN_TIME: float = 0.5
var _knockback_velocity: Vector2 = Vector2.ZERO
var _attack_timer: float = 0.0

const FLEE_DISTANCE: float = 150.0
const PREFERRED_DISTANCE: float = 300.0

var _projectile_scene: PackedScene = preload("res://scenes/weapons/enemy_projectile.tscn")


func _ready() -> void:
	_player = _find_player()
	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		if enemy_data:
			health.max_health = enemy_data.max_health
		health.reset()
		health.damaged.connect(_on_damaged)
	
	_attack_timer = enemy_data.attack_cooldown if enemy_data else 2.0


func _on_damaged(_amount: float, source_pos: Vector2) -> void:
	var tween = create_tween()
	$AnimatedSprite2D.modulate = Color.WHITE
	tween.tween_property($AnimatedSprite2D, "modulate", Color(0.3, 1.0, 0.3, 1), 0.15)
	
	if source_pos != Vector2.ZERO:
		var dir = source_pos.direction_to(global_position)
		_knockback_velocity = dir * 200.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return

	var dist := global_position.distance_to(_player.global_position)
	var direction := global_position.direction_to(_player.global_position)
	var spd := enemy_data.speed if enemy_data else 60.0
	
	# Foge se muito perto, persegue se muito longe
	if dist < FLEE_DISTANCE:
		velocity = -direction * spd * 1.2
		$AnimatedSprite2D.play("RUN")
	elif dist > PREFERRED_DISTANCE + 50.0:
		velocity = direction * spd
		$AnimatedSprite2D.play("RUN")
	else:
		velocity = Vector2.ZERO
		$AnimatedSprite2D.play("IDLE")
	
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	velocity += _knockback_velocity
	move_and_slide()
	
	# Flip sprite
	if direction.x != 0.0:
		$AnimatedSprite2D.flip_h = direction.x < 0.0
	
	# Atirar
	_attack_timer -= delta
	if _attack_timer <= 0.0 and dist <= (enemy_data.attack_range if enemy_data else 350.0):
		_fire_at_player()
		_attack_timer = enemy_data.attack_cooldown if enemy_data else 2.0


func _fire_at_player() -> void:
	if not _projectile_scene:
		return
	var proj = _projectile_scene.instantiate() as Area2D
	var dir = global_position.direction_to(_player.global_position)
	var dmg = enemy_data.projectile_damage if enemy_data else 8.0
	var spd = enemy_data.projectile_speed if enemy_data else 300.0
	proj.global_position = global_position
	proj.setup(dir, spd, dmg, 600.0)
	get_tree().current_scene.add_child(proj)


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_contact_cooldown = 0.0
	_knockback_velocity = Vector2.ZERO
	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		if enemy_data:
			health.max_health = enemy_data.max_health
		health.reset()
	_player = _find_player()
	_attack_timer = enemy_data.attack_cooldown if enemy_data else 2.0


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null
