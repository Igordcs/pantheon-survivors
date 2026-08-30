extends Node
class_name EnemySpawner
## Spawns weighted enemy groups around the player while reusing scene pools.

signal kill_scored

@export var enemy_scene: PackedScene
@export var xp_gem_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
@export var max_enemies: int = 50
@export var spawn_interval: float = 1.0
@export var min_spawn_radius: float = 400.0
@export var max_spawn_radius: float = 600.0

var _enemy_scenes: Dictionary[StringName, PackedScene] = {}
var _pools: Dictionary = {}
var _active_by_id: Dictionary[StringName, int] = {}
var _active_count: int = 0
var _gem_pool: Array[Area2D] = []
var _spawn_timer: Timer
var _player: CharacterBody2D
var _current_entries: Array[EnemySpawnEntry] = []
var _threat_budget: float = 0.0
var _threat_per_second: float = 1.0
var _max_batch_size: int = 4
var _world_generator: WorldGenerator


func _ready() -> void:
	_player = _find_player()
	_enemy_scenes[&"melee"] = enemy_scene
	_enemy_scenes[&"bat"] = preload("res://scenes/enemies/bat_enemy.tscn")
	_enemy_scenes[&"tank"] = preload("res://scenes/enemies/tank_enemy.tscn")
	_enemy_scenes[&"ranged"] = preload("res://scenes/enemies/ranged_enemy.tscn")
	_enemy_scenes[&"healer"] = preload("res://scenes/enemies/healer_enemy.tscn")
	_enemy_scenes[&"directional_ranged"] = preload("res://scenes/enemies/directional_ranged_enemy.tscn")
	_enemy_scenes[&"charger"] = preload("res://scenes/enemies/charger_enemy.tscn")

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	_spawn_timer.start()


func apply_wave_data(wave: WaveData) -> void:
	max_enemies = wave.max_enemies
	spawn_interval = wave.spawn_interval
	_threat_per_second = wave.threat_per_second
	_max_batch_size = wave.max_batch_size
	_current_entries = wave.enemies.duplicate()
	_spawn_timer.wait_time = spawn_interval
	_threat_budget = maxf(_threat_budget, _minimum_entry_cost())


func stop_spawning() -> void:
	if _spawn_timer:
		_spawn_timer.stop()


func resume_spawning() -> void:
	if _spawn_timer and _spawn_timer.is_stopped():
		_spawn_timer.start()


func is_spawning() -> bool:
	return is_instance_valid(_spawn_timer) and not _spawn_timer.is_stopped()


func setup_world_generator(world_generator: WorldGenerator) -> void:
	_world_generator = world_generator


func spawn_event(entry: EnemySpawnEntry, count: int) -> void:
	if not entry or not entry.is_valid():
		return
	var available_slots := maxi(max_enemies - _active_count, 0)
	var allowed_count := mini(count, available_slots)
	if entry.max_simultaneous > 0:
		allowed_count = mini(allowed_count, entry.max_simultaneous - _get_active_count(entry))
	_spawn_group(entry, maxi(allowed_count, 0))


func reduce_active_horde(keep_ratio: float = 0.45) -> void:
	var target_count := ceili(float(_active_count) * clampf(keep_ratio, 0.0, 1.0))
	var active_enemies := get_tree().get_nodes_in_group("enemies")
	active_enemies.shuffle()
	for node in active_enemies:
		if _active_count <= target_count:
			break
		var enemy := node as CharacterBody2D
		if enemy and not enemy.is_in_group("bosses") and enemy.visible and enemy.has_meta("spawn_entry_id"):
			_deactivate_enemy(enemy, false)


func _on_spawn_timer_timeout() -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return
	if _active_count >= max_enemies or _current_entries.is_empty():
		return

	_threat_budget += _threat_per_second * spawn_interval
	var spawned_this_tick := 0
	while spawned_this_tick < _max_batch_size and _active_count < max_enemies:
		var entry := _choose_entry(_threat_budget)
		if entry == null:
			break
		var affordable := floori(_threat_budget / entry.threat_cost)
		var group_limit := mini(entry.max_group_size, affordable)
		group_limit = mini(group_limit, _max_batch_size - spawned_this_tick)
		group_limit = mini(group_limit, max_enemies - _active_count)
		if entry.max_simultaneous > 0:
			group_limit = mini(group_limit, entry.max_simultaneous - _get_active_count(entry))
		if group_limit <= 0:
			break
		var group_size := randi_range(mini(entry.min_group_size, group_limit), group_limit)
		var spawned := _spawn_group(entry, group_size)
		if spawned <= 0:
			break
		_threat_budget -= entry.threat_cost * spawned
		spawned_this_tick += spawned


func _choose_entry(available_budget: float) -> EnemySpawnEntry:
	var eligible: Array[EnemySpawnEntry] = []
	var total_weight := 0.0
	for entry in _current_entries:
		if not entry or not entry.is_valid() or entry.threat_cost > available_budget:
			continue
		if entry.max_simultaneous > 0 and _get_active_count(entry) >= entry.max_simultaneous:
			continue
		eligible.append(entry)
		total_weight += entry.weight
	if eligible.is_empty():
		return null

	var roll := randf() * total_weight
	for entry in eligible:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return eligible.back()


func _spawn_group(entry: EnemySpawnEntry, count: int) -> int:
	var spawned := 0
	for _index in count:
		var enemy := _get_enemy(entry)
		if enemy == null:
			continue
		if not enemy.is_inside_tree():
			var container := get_tree().current_scene.get_node_or_null("World/Enemies")
			(container if container else get_tree().current_scene).add_child(enemy)
		enemy.set_meta("spawn_entry_id", entry.enemy_data.id)
		enemy.reset(_random_spawn_position())
		enemy.visible = true
		enemy.collision_layer = 2
		enemy.set_physics_process(true)
		_active_count += 1
		_active_by_id[entry.enemy_data.id] = _get_active_count(entry) + 1
		spawned += 1
	return spawned


func _get_enemy(entry: EnemySpawnEntry) -> CharacterBody2D:
	var pool_key := entry.scene_key
	if not _pools.has(pool_key):
		_pools[pool_key] = []
	var pool: Array = _pools[pool_key]
	for pooled_enemy in pool:
		if is_instance_valid(pooled_enemy) and not pooled_enemy.visible:
			pooled_enemy.set("enemy_data", entry.enemy_data)
			return pooled_enemy as CharacterBody2D

	var scene: PackedScene = _enemy_scenes.get(pool_key, enemy_scene) as PackedScene
	if scene == null:
		push_error("EnemySpawner: no scene registered for '%s'." % pool_key)
		return null
	var enemy := scene.instantiate() as CharacterBody2D
	enemy.set("enemy_data", entry.enemy_data)
	pool.append(enemy)
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(_on_enemy_died.bind(enemy))
	return enemy


func _get_active_count(entry: EnemySpawnEntry) -> int:
	return _active_by_id.get(entry.enemy_data.id, 0)


func _minimum_entry_cost() -> float:
	var minimum := INF
	for entry in _current_entries:
		if entry and entry.is_valid():
			minimum = minf(minimum, entry.threat_cost)
	return minimum if minimum < INF else 0.0


func _get_xp_gem() -> Area2D:
	for gem in _gem_pool:
		if is_instance_valid(gem) and not gem.visible:
			return gem
	var gem := xp_gem_scene.instantiate() as Area2D
	_gem_pool.append(gem)
	return gem


func _spawn_xp_gem(pos: Vector2, value: int) -> void:
	var gem := _get_xp_gem()
	if not gem.is_inside_tree():
		var container := get_tree().current_scene.get_node_or_null("World/Items")
		(container if container else get_tree().current_scene).add_child(gem)
	if gem.has_method("setup"):
		gem.setup(pos, value)


func _on_enemy_died(enemy: CharacterBody2D) -> void:
	if not enemy.visible:
		return
	kill_scored.emit()
	var xp_value := 10
	var data := enemy.get("enemy_data") as EnemyData
	if data:
		xp_value = data.score_value
	_spawn_xp_gem.call_deferred(enemy.global_position, xp_value)
	_deactivate_enemy(enemy, true)


func _deactivate_enemy(enemy: CharacterBody2D, clear_metadata: bool) -> void:
	var entry_id := enemy.get_meta("spawn_entry_id", &"") as StringName
	if not entry_id.is_empty():
		_active_by_id[entry_id] = maxi(_active_by_id.get(entry_id, 1) - 1, 0)
	enemy.visible = false
	enemy.set_physics_process(false)
	enemy.collision_layer = 0
	enemy.global_position = Vector2(-9999.0, -9999.0)
	_active_count = maxi(_active_count - 1, 0)
	if clear_metadata:
		enemy.remove_meta("spawn_entry_id")


func _random_spawn_position() -> Vector2:
	if is_instance_valid(_world_generator):
		return _world_generator.get_valid_spawn_position_around_player(
			_player.global_position, min_spawn_radius, max_spawn_radius
		)
	var angle := randf() * TAU
	return _player.global_position + Vector2.from_angle(angle) * randf_range(min_spawn_radius, max_spawn_radius)


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null
