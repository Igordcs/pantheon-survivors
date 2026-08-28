extends Node
## EnemySpawner — spawna inimigos ao redor do Player com pooling.
## Também gerencia os drops de XP Gems dos inimigos mortos.

signal kill_scored

@export var enemy_scene: PackedScene
@export var xp_gem_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
@export var max_enemies: int = 50
@export var spawn_interval: float = 1.5
@export var min_spawn_radius: float = 400.0
@export var max_spawn_radius: float = 600.0

var _pool: Array[CharacterBody2D] = []
var _gem_pool: Array[Area2D] = []
var _active_count: int = 0
var _spawn_timer: Timer
var _player: CharacterBody2D
var _current_allowed_enemies: Array[EnemyData] = []


func _ready() -> void:
	_player = _find_player()

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)


func apply_wave_data(wave: WaveData) -> void:
	max_enemies = wave.max_enemies
	_spawn_timer.wait_time = wave.spawn_interval
	_current_allowed_enemies = wave.allowed_enemies
	# Default to basic enemy data if empty to prevent crashes
	if _current_allowed_enemies.is_empty():
		var fallback = load("res://resources/enemies/basic_enemy_data.tres")
		if fallback:
			_current_allowed_enemies.append(fallback)


func _on_spawn_timer_timeout() -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return

	if _active_count >= max_enemies:
		return

	var enemy := _get_enemy()
	var spawn_pos := _random_spawn_position()

	if not enemy.is_inside_tree():
		var enemies_container := get_tree().current_scene.get_node_or_null("World/Enemies")
		if enemies_container:
			enemies_container.add_child(enemy)
		else:
			get_tree().current_scene.add_child(enemy)

	enemy.reset(spawn_pos)
	enemy.visible = true
	enemy.collision_layer = 2
	enemy.set_physics_process(true)
	_active_count += 1


func _get_enemy() -> CharacterBody2D:
	# Escolhe um tipo aleatório da wave atual
	var chosen_data: EnemyData = null
	if not _current_allowed_enemies.is_empty():
		chosen_data = _current_allowed_enemies.pick_random()

	# Reuse from pool (só se o data for igual, para simplificar vamos achar o primeiro inativo e forçar o data)
	for e in _pool:
		if is_instance_valid(e) and not e.visible:
			if chosen_data and "enemy_data" in e:
				e.enemy_data = chosen_data
			return e

	# Create new
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	if chosen_data and "enemy_data" in enemy:
		enemy.enemy_data = chosen_data
	_pool.append(enemy)

	# Connect death signal (only once per instance)
	var health := enemy.get_node_or_null("HealthComponent")
	if health:
		health.died.connect(_on_enemy_died.bind(enemy))

	return enemy


func _get_xp_gem() -> Area2D:
	# Reuse from pool
	for gem in _gem_pool:
		if is_instance_valid(gem) and not gem.visible:
			return gem
			
	# Create new
	var gem := xp_gem_scene.instantiate() as Area2D
	_gem_pool.append(gem)
	return gem


func _spawn_xp_gem(pos: Vector2, value: int) -> void:
	var gem := _get_xp_gem()
	if not gem.is_inside_tree():
		var items_container := get_tree().current_scene.get_node_or_null("World/Items")
		if items_container:
			items_container.add_child(gem)
		else:
			get_tree().current_scene.add_child(gem)
	if gem.has_method("setup"):
		gem.setup(pos, value)


func _on_enemy_died(enemy: CharacterBody2D) -> void:
	kill_scored.emit()
	var pos = enemy.global_position
	# Pega o score_value do EnemyData para ser o valor da XP
	var xp_value := 10
	if "enemy_data" in enemy and enemy.enemy_data:
		xp_value = enemy.enemy_data.score_value
		
	# Spawn gem first before moving enemy
	_spawn_xp_gem(pos, xp_value)

	enemy.visible = false
	enemy.set_physics_process(false)
	enemy.collision_layer = 0
	enemy.global_position = Vector2(-9999, -9999)
	_active_count -= 1


func _random_spawn_position() -> Vector2:
	var angle := randf() * TAU
	var radius := randf_range(min_spawn_radius, max_spawn_radius)
	return _player.global_position + Vector2(cos(angle), sin(angle)) * radius


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null
