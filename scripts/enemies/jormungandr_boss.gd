extends DirectionalBoss
## Jormungandr uses emerging bites, poison puddles and a radial magic barrage.

enum AttackType { EMERGING_BITE, POISON_SPIT, RADIAL_MAGIC }
enum State { CHASING, TELEGRAPHING, RECOVERING }

const RADIAL_PROJECTILE_COUNT: int = 36
const RADIAL_ANGLE_STEP_DEGREES: float = 10.0

@export var attack_cooldown: float = 3.8
@export var telegraph_duration: float = 1.05
@export var bite_damage: float = 45.0
@export var bite_radius: float = 115.0
@export var poison_projectile_count: int = 3
@export var poison_impact_damage: float = 14.0
@export var poison_tick_damage: float = 8.0
@export var poison_puddle_radius: float = 92.0
@export var poison_spread_radius: float = 130.0
@export var radial_magic_damage: float = 12.0
@export var radial_magic_speed: float = 280.0
@export var radial_magic_range: float = 720.0

var _state := State.CHASING
var _state_timer: float = 2.8
var _attack_type := AttackType.EMERGING_BITE
var _target_position := Vector2.ZERO
var _telegraph: Polygon2D
var _magic_projectiles: Array[BossMagicProjectile] = []


func _tick_behavior(delta: float) -> void:
	_state_timer -= delta
	match _state:
		State.CHASING:
			chase_player(1.15 if health_component.current_health <= health_component.max_health * 0.5 else 1.0)
			if _state_timer <= 0.0:
				_start_attack()
		State.TELEGRAPHING:
			stop_movement()
			if _state_timer <= 0.0:
				_execute_attack()
		State.RECOVERING:
			stop_movement()
			if _state_timer <= 0.0:
				_state = State.CHASING
				_state_timer = attack_cooldown


func _start_attack() -> void:
	_state = State.TELEGRAPHING
	_state_timer = telegraph_duration
	_attack_type = randi_range(AttackType.EMERGING_BITE, AttackType.RADIAL_MAGIC)
	_target_position = get_player().global_position

	match _attack_type:
		AttackType.EMERGING_BITE:
			_create_bite_telegraph()
			sprite.self_modulate = Color(0.65, 0.8, 1.0, 0.35)
		AttackType.POISON_SPIT:
			_create_spit_telegraph()
		AttackType.RADIAL_MAGIC:
			_create_radial_magic_telegraph()


func _execute_attack() -> void:
	match _attack_type:
		AttackType.EMERGING_BITE:
			_execute_emerging_bite()
		AttackType.POISON_SPIT:
			_execute_poison_spit()
		AttackType.RADIAL_MAGIC:
			_execute_radial_magic()
	_state = State.RECOVERING
	_state_timer = 0.5
	ScreenShake.shake(0.75)


func _create_bite_telegraph() -> void:
	_telegraph = Polygon2D.new()
	_telegraph.polygon = _build_circle_polygon(bite_radius)
	_telegraph.color = Color(0.18, 0.48, 0.72, 0.32)
	_telegraph.z_index = 3
	get_tree().current_scene.add_child(_telegraph)
	_telegraph.global_position = _target_position


func _create_spit_telegraph() -> void:
	_telegraph = Polygon2D.new()
	_telegraph.polygon = _build_circle_polygon(42.0)
	_telegraph.color = Color(0.42, 0.85, 0.08, 0.38)
	_telegraph.z_index = 3
	get_tree().current_scene.add_child(_telegraph)
	_telegraph.global_position = global_position


func _create_radial_magic_telegraph() -> void:
	_telegraph = Polygon2D.new()
	_telegraph.polygon = _build_circle_polygon(72.0)
	_telegraph.color = Color(0.18, 0.55, 1.0, 0.34)
	_telegraph.z_index = 3
	get_tree().current_scene.add_child(_telegraph)
	_telegraph.global_position = global_position


func _execute_emerging_bite() -> void:
	global_position = _target_position
	sprite.self_modulate = Color.WHITE
	if is_player_inside_radius(_target_position, bite_radius):
		damage_player(bite_damage, _target_position)
	_release_telegraph(Color(0.35, 0.8, 1.0, 0.78), 0.5)


func _execute_poison_spit() -> void:
	for index in range(poison_projectile_count):
		var angle := TAU * float(index) / float(maxi(poison_projectile_count, 1))
		var offset := Vector2.from_angle(angle) * poison_spread_radius
		var projectile := BossPoisonProjectile.new()
		get_tree().current_scene.add_child(projectile)
		projectile.setup(
			get_player(), global_position, _target_position + offset,
			poison_impact_damage, poison_tick_damage, poison_puddle_radius
		)
	_release_telegraph(Color(0.55, 1.0, 0.1, 0.8), 0.35)


func _execute_radial_magic() -> void:
	for index in range(RADIAL_PROJECTILE_COUNT):
		var angle := deg_to_rad(float(index) * RADIAL_ANGLE_STEP_DEGREES)
		var projectile := BossMagicProjectile.new()
		get_tree().current_scene.add_child(projectile)
		projectile.setup(
			get_player(),
			global_position,
			Vector2.from_angle(angle),
			radial_magic_speed,
			radial_magic_damage,
			radial_magic_range
		)
		_magic_projectiles.append(projectile)
	_release_telegraph(Color(0.38, 0.78, 1.0, 0.9), 0.45)


func _release_telegraph(final_color: Color, fade_duration: float) -> void:
	if not is_instance_valid(_telegraph):
		return
	var effect := _telegraph
	_telegraph = null
	effect.color = final_color
	var tween := effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(effect.queue_free)


func _cleanup_behavior() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null
	for projectile in _magic_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	_magic_projectiles.clear()


func _build_circle_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(32):
		points.append(Vector2.from_angle(TAU * float(index) / 32.0) * radius)
	return points
