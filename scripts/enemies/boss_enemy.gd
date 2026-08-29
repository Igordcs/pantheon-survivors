extends CharacterBody2D
## BossEnemy — Inimigo forte com ataques telegrafados, animações e mecânica única.

signal died

@export var boss_data: EnemyData = preload("res://resources/enemies/boss_data.tres")

enum State { SPAWNING, CHASING, TELEGRAPHING, ATTACKING, DYING }

var _current_state: State = State.SPAWNING
var _state_timer: float = 0.0
var _attack_cooldown: float = 5.0
var _player: CharacterBody2D

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var telegraph_area: ColorRect = $TelegraphArea
@onready var hit_area: Area2D = $TelegraphArea/HitArea


func _ready() -> void:
	if boss_data:
		health_component.max_health = boss_data.max_health
		health_component.current_health = boss_data.max_health
	
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	telegraph_area.hide()
	hit_area.monitoring = false
	
	# Começa com animação de spawn (idle pulsando)
	_current_state = State.SPAWNING
	_state_timer = 2.0
	sprite.play("IDLE")
	
	# Efeito de spawn: cresce de 0 até o tamanho normal
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	ScreenShake.shake(0.5)


func _on_damaged(_amount: float, _source_pos: Vector2) -> void:
	if _current_state == State.DYING:
		return
	var tween = create_tween()
	sprite.modulate = Color.WHITE
	tween.tween_property(sprite, "modulate", Color(0.6, 0.1, 0.9, 1), 0.15)


func reset(pos: Vector2) -> void:
	global_position = pos
	if boss_data:
		health_component.current_health = boss_data.max_health
	_current_state = State.SPAWNING
	_state_timer = 2.0
	telegraph_area.hide()
	hit_area.monitoring = false


func _physics_process(delta: float) -> void:
	if _current_state == State.DYING:
		return
		
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return
			
	match _current_state:
		State.SPAWNING:
			_process_spawning(delta)
		State.CHASING:
			_process_chasing(delta)
		State.TELEGRAPHING:
			_process_telegraphing(delta)
		State.ATTACKING:
			_process_attacking(delta)


func _process_spawning(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_current_state = State.CHASING
		_state_timer = _attack_cooldown


var _minion_healer: PackedScene = preload("res://scenes/enemies/healer_enemy.tscn")
var _minion_ranged: PackedScene = preload("res://scenes/enemies/ranged_enemy.tscn")
var _minion_timer: float = 3.0


func _process_chasing(delta: float) -> void:
	# Boss fica centralizado e parado (sem move_and_slide para não ser empurrado pela física)
	sprite.play("IDLE")
	
	# Continua olhando para o player
	var dir := global_position.direction_to(_player.global_position)
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0
	
	# Lógica de Spawn de Minions
	_minion_timer -= delta
	if _minion_timer <= 0.0:
		_spawn_minion()
		_minion_timer = 4.0
	
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_telegraph()


func _spawn_minion() -> void:
	var scene_to_spawn = _minion_ranged if randf() > 0.5 else _minion_healer
	var minion = scene_to_spawn.instantiate() as CharacterBody2D
	get_tree().current_scene.add_child(minion)
	
	# Spawna ao redor do boss
	var angle = randf() * TAU
	var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * 80.0
	
	if minion.has_method("reset"):
		minion.reset(spawn_pos)
	else:
		minion.global_position = spawn_pos


func _start_telegraph() -> void:
	_current_state = State.TELEGRAPHING
	_state_timer = 1.5
	velocity = Vector2.ZERO
	
	var dir := global_position.direction_to(_player.global_position)
	telegraph_area.rotation = dir.angle()
	telegraph_area.show()
	telegraph_area.color = Color(1, 0, 0, 0.3)
	sprite.play("ATTACK")


func _process_telegraphing(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_attack()


func _start_attack() -> void:
	_current_state = State.ATTACKING
	_state_timer = 0.5
	telegraph_area.color = Color(1, 0, 0, 0.8)
	hit_area.monitoring = true
	ScreenShake.shake(1.0)
	AudioManager.play_sfx("boss_attack")


func _process_attacking(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		telegraph_area.hide()
		hit_area.monitoring = false
		_current_state = State.CHASING
		_state_timer = _attack_cooldown


func _on_hit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var health = body.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.take_damage(50.0, global_position)
			ScreenShake.shake(0.8)


func _on_died() -> void:
	if _current_state == State.DYING:
		return
	_current_state = State.DYING
	velocity = Vector2.ZERO
	telegraph_area.hide()
	hit_area.monitoring = false
	
	# Animação de morte
	sprite.play("DEAD")
	ScreenShake.shake(1.5)
	AudioManager.play_sfx("boss_death")
	
	# Explosão visual
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0, 1), 0.2)
	tween.tween_property(self, "scale", Vector2(3.0, 3.0), 0.3)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		died.emit()
		queue_free()
	)


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null
