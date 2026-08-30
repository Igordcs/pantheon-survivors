extends EnemyBase
class_name MythicBoss
## Shared boss state machine with configurable charge or targeted-area attacks.

signal died

enum AttackMode { CHARGE, TARGETED_AREA }
enum State { SPAWNING, CHASING, TELEGRAPHING, ATTACKING, DYING }

@export var boss_data: EnemyData
@export var attack_mode := AttackMode.CHARGE
@export_dir var idle_directory: String
@export_dir var attack_directory: String
@export_dir var death_directory: String
@export var visual_size: float = 112.0
@export var attack_radius: float = 110.0
@export var attack_damage: float = 30.0
@export var attack_cooldown: float = 4.0
@export var telegraph_duration: float = 1.1
@export var charge_speed: float = 430.0
@export var summon_interval: float = 8.0
@export var minion_scenes: Array[PackedScene] = []

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var telegraph: Polygon2D = $Telegraph

var _player: CharacterBody2D
var _state := State.SPAWNING
var _state_timer := 1.5
var _attack_timer := 0.0
var _summon_timer := 0.0
var _target_position := Vector2.ZERO
var _attack_direction := Vector2.ZERO
var _damage_applied := false
var _second_phase := false


func _ready() -> void:
	_build_animations()
	health_component.max_health = boss_data.max_health
	health_component.reset()
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	_player = _find_player()
	telegraph.hide()
	_summon_timer = summon_interval
	sprite.play(&"IDLE")
	var final_scale := scale
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", final_scale, 1.1).set_trans(Tween.TRANS_BACK)
	ScreenShake.shake(0.35)


func _physics_process(delta: float) -> void:
	if _state == State.DYING:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return
	_update_phase()
	_state_timer -= delta
	match _state:
		State.SPAWNING:
			if _state_timer <= 0.0:
				_enter_chasing()
		State.CHASING:
			_process_chasing(delta)
		State.TELEGRAPHING:
			_process_telegraphing()
		State.ATTACKING:
			_process_attack(delta)


func _process_chasing(delta: float) -> void:
	var direction := global_position.direction_to(_player.global_position)
	if boss_data.speed > 0.0:
		velocity = direction * boss_data.speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	if direction.x != 0.0:
		sprite.flip_h = direction.x < 0.0
	sprite.play(&"IDLE")
	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_spawn_minions(2 if _second_phase else 1)
		_summon_timer = summon_interval * (0.75 if _second_phase else 1.0)
	if _state_timer <= 0.0:
		_start_telegraph()


func _start_telegraph() -> void:
	_state = State.TELEGRAPHING
	_state_timer = telegraph_duration
	velocity = Vector2.ZERO
	_target_position = _player.global_position
	_attack_direction = global_position.direction_to(_target_position)
	telegraph.global_position = _target_position
	telegraph.color = Color(0.95, 0.15, 0.08, 0.28)
	telegraph.show()
	sprite.play(&"ATTACK")


func _process_telegraphing() -> void:
	if _state_timer > 0.0:
		return
	_state = State.ATTACKING
	_damage_applied = false
	telegraph.color = Color(1.0, 0.25, 0.1, 0.8)
	if attack_mode == AttackMode.CHARGE:
		_state_timer = maxf(global_position.distance_to(_target_position) / charge_speed, 0.35)
	else:
		_state_timer = 0.35
		_apply_area_damage(_target_position)
	ScreenShake.shake(0.65)


func _process_attack(_delta: float) -> void:
	if attack_mode == AttackMode.CHARGE:
		velocity = _attack_direction * charge_speed
		move_and_slide()
		if not _damage_applied and global_position.distance_to(_player.global_position) <= 48.0:
			_apply_player_damage()
	if _state_timer <= 0.0:
		telegraph.hide()
		_enter_chasing()


func _enter_chasing() -> void:
	_state = State.CHASING
	_state_timer = attack_cooldown * (0.72 if _second_phase else 1.0)
	velocity = Vector2.ZERO


func _apply_area_damage(center: Vector2) -> void:
	if _player.global_position.distance_to(center) <= attack_radius:
		_apply_player_damage()


func _apply_player_damage() -> void:
	var health := _player.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(attack_damage, global_position)
		_damage_applied = true


func _spawn_minions(count: int) -> void:
	if minion_scenes.is_empty():
		return
	for index in count:
		var scene: PackedScene = minion_scenes.pick_random() as PackedScene
		var minion := scene.instantiate() as CharacterBody2D
		get_tree().current_scene.add_child(minion)
		var angle := TAU * float(index) / float(maxi(count, 1)) + randf_range(-0.4, 0.4)
		minion.reset(global_position + Vector2.from_angle(angle) * 90.0)
		var health := minion.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.died.connect(minion.queue_free)


func _update_phase() -> void:
	if not _second_phase and health_component.current_health <= health_component.max_health * 0.5:
		_second_phase = true
		sprite.modulate = Color(1.0, 0.65, 0.65)
		ScreenShake.shake(0.45)


func _on_damaged(_amount: float, _source_pos: Vector2) -> void:
	if _state == State.DYING:
		return
	var base_color := Color(1.0, 0.65, 0.65) if _second_phase else Color.WHITE
	sprite.modulate = Color(1.0, 0.25, 0.25)
	create_tween().tween_property(sprite, "modulate", base_color, 0.12)


func _on_died() -> void:
	if _state == State.DYING:
		return
	_state = State.DYING
	velocity = Vector2.ZERO
	telegraph.hide()
	if sprite.sprite_frames.has_animation(&"DEAD"):
		sprite.play(&"DEAD")
	ScreenShake.shake(1.0)
	var tween := create_tween()
	tween.tween_interval(0.7)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		died.emit()
		queue_free()
	)


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"IDLE", idle_directory, 6.0, true)
	_add_animation(frames, &"ATTACK", attack_directory, 9.0, false)
	_add_animation(frames, &"DEAD", death_directory, 8.0, false)
	sprite.sprite_frames = frames
	if frames.has_animation(&"IDLE") and frames.get_frame_count(&"IDLE") > 0:
		var texture := frames.get_frame_texture(&"IDLE", 0)
		var largest := maxf(texture.get_width(), texture.get_height())
		if largest > 0.0:
			sprite.scale = Vector2.ONE * visual_size / largest


func _add_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	directory_path: String,
	fps: float,
	looped: bool
) -> void:
	if directory_path.is_empty():
		return
	var files := DirAccess.get_files_at(directory_path)
	files.sort()
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, looped)
	for file in files:
		if file.get_extension().to_lower() != "png":
			continue
		if "copy" in file.to_lower() or "-001" in file:
			continue
		var texture := load(directory_path.path_join(file)) as Texture2D
		if texture:
			frames.add_frame(animation_name, texture)


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
