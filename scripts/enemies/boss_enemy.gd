extends CharacterBody2D
## BossEnemy — Inimigo forte com ataques telegrafados e mecânica única.

signal died

@export var boss_data: EnemyData = preload("res://resources/enemies/boss_data.tres")

enum State { CHASING, TELEGRAPHING, ATTACKING }

var _current_state: State = State.CHASING
var _state_timer: float = 0.0
var _attack_cooldown: float = 5.0
var _player: CharacterBody2D

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var telegraph_area: ColorRect = $TelegraphArea
@onready var hit_area: Area2D = $TelegraphArea/HitArea


func _ready() -> void:
	if boss_data:
		health_component.max_health = boss_data.max_health
		health_component.current_health = boss_data.max_health
	
	health_component.died.connect(_on_died)
	telegraph_area.hide()
	hit_area.monitoring = false


func reset(pos: Vector2) -> void:
	global_position = pos
	if boss_data:
		health_component.current_health = boss_data.max_health
	_current_state = State.CHASING
	_state_timer = _attack_cooldown
	telegraph_area.hide()
	hit_area.monitoring = false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return
			
	match _current_state:
		State.CHASING:
			_process_chasing(delta)
		State.TELEGRAPHING:
			_process_telegraphing(delta)
		State.ATTACKING:
			_process_attacking(delta)


func _process_chasing(delta: float) -> void:
	var dir := global_position.direction_to(_player.global_position)
	velocity = dir * (boss_data.speed if boss_data else 80.0)
	move_and_slide()
	
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_telegraph()


func _start_telegraph() -> void:
	_current_state = State.TELEGRAPHING
	_state_timer = 1.5 # Tempo para desviar
	velocity = Vector2.ZERO
	
	# Aponta o telegraph para onde o player está no momento
	var dir := global_position.direction_to(_player.global_position)
	telegraph_area.rotation = dir.angle()
	telegraph_area.show()
	telegraph_area.color = Color(1, 0, 0, 0.3)


func _process_telegraphing(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_attack()


func _start_attack() -> void:
	_current_state = State.ATTACKING
	_state_timer = 0.5 # Tempo do dano ativo
	telegraph_area.color = Color(1, 0, 0, 0.8)
	hit_area.monitoring = true


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
			health.take_damage(50.0) # Dano fixo do ataque pesado


func _on_died() -> void:
	died.emit()
	queue_free() # Boss não usa pool, deletamos


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null
