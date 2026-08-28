extends Node
## EnemySpawner — spawna inimigos ao redor do Player com pooling.

@export var enemy_scene: PackedScene
@export var max_enemies: int = 50
@export var spawn_interval: float = 1.5
@export var min_spawn_radius: float = 400.0
@export var max_spawn_radius: float = 600.0

var _pool: Array[CharacterBody2D] = []
var _active_count: int = 0
var _spawn_timer: Timer
var _player: CharacterBody2D


func _ready() -> void:
	_player = _find_player()

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)


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
	# Reuse from pool
	for e in _pool:
		if is_instance_valid(e) and not e.visible:
			return e

	# Create new
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	_pool.append(enemy)

	# Connect death signal (only once per instance)
	var health := enemy.get_node_or_null("HealthComponent")
	if health:
		health.died.connect(_on_enemy_died.bind(enemy))

	return enemy


func _on_enemy_died(enemy: CharacterBody2D) -> void:
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
