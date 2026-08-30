class_name WorldGenerator
extends Node2D
## Infinite deterministic world streamed as a small set of reusable chunks.

signal world_generated(seed: int)
signal chunk_generated(chunk_coordinate: Vector2i)
signal chunk_removed(chunk_coordinate: Vector2i)
signal biome_entered(biome_type: int)

@export_category("World")
@export var world_seed: int = 0
@export var generate_on_ready: bool = true

@export_category("Safe Area")
@export_range(0.0, 2048.0, 16.0) var safe_radius: float = 400.0
@export var initial_spawn_position: Vector2 = Vector2.ZERO

@export_category("Enemy Spawn Queries")
@export_range(0.0, 2048.0, 16.0) var minimum_offscreen_distance: float = 520.0
@export_range(1, 100, 1) var spawn_position_attempts: int = 24
@export_range(0.0, 128.0, 1.0) var spawn_clearance_radius: float = 28.0

@export_category("Debug")
@export var debug_mode: bool = true
@export var draw_chunk_bounds: bool = false
@export var draw_safe_radius: bool = false
@export var draw_obstacle_positions: bool = false

@onready var ground_layer: TileMapLayer = $Ground
@onready var decorations_layer: TileMapLayer = $Decorations
@onready var obstacles_container: Node2D = $Obstacles
@onready var points_container: Node2D = $PointsOfInterest
@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var biome_generator: BiomeGenerator = $BiomeGenerator
@onready var decoration_spawner: DecorationSpawner = $DecorationSpawner
@onready var obstacle_spawner: ObstacleSpawner = $ObstacleSpawner
@onready var point_of_interest_spawner: PointOfInterestSpawner = $PointOfInterestSpawner

var current_seed: int = 0
var obstacle_placements: Array[Dictionary] = []

var _player: Node2D
var _active_chunks: Dictionary = {}
var _chunk_cache: Dictionary = {}
var _cache_order: Array[Vector2i] = []
var _runtime_rng := RandomNumberGenerator.new()
var _current_biome_type: int = -1
var _biome_check_elapsed: float = 0.0


func _ready() -> void:
	add_to_group(&"world_generator")
	set_process(false)
	chunk_manager.chunk_required.connect(generate_chunk)
	chunk_manager.chunk_released.connect(remove_chunk)
	chunk_manager.current_chunk_changed.connect(_on_current_chunk_changed)
	if generate_on_ready:
		generate_world()


func setup(player: Node2D) -> void:
	_player = player
	chunk_manager.setup(player)
	_update_player_biome(player.global_position)
	set_process(true)


func generate_world() -> void:
	_clear_active_chunks()
	_chunk_cache.clear()
	_cache_order.clear()
	ground_layer.clear()
	decorations_layer.clear()
	_current_biome_type = -1
	_biome_check_elapsed = 0.0

	current_seed = _resolve_seed()
	_runtime_rng.seed = current_seed ^ 0x5F3759DF
	if not _validate_configuration():
		return
	biome_generator.configure(current_seed)
	_configure_water_tile()
	chunk_manager.reset_tracking()
	chunk_manager.initialize_at(initial_spawn_position)

	queue_redraw()
	if debug_mode:
		print("WorldGenerator [Phases 2-3] — seed: %d" % current_seed)
		print("WorldGenerator — active chunks: %d" % _active_chunks.size())
	world_generated.emit(current_seed)


func generate_chunk(chunk_coordinate: Vector2i) -> void:
	if _active_chunks.has(chunk_coordinate):
		return

	var chunk_data := _get_or_build_chunk_data(chunk_coordinate)
	var obstacle_container := Node2D.new()
	obstacle_container.name = "Chunk_%d_%d" % [chunk_coordinate.x, chunk_coordinate.y]
	obstacle_container.y_sort_enabled = true
	obstacles_container.add_child(obstacle_container)

	_apply_chunk_tiles(chunk_data)
	obstacle_spawner.instantiate_obstacles(
		obstacle_container,
		chunk_data.obstacle_blueprints
	)
	_active_chunks[chunk_coordinate] = {
		"data": chunk_data,
		"obstacle_container": obstacle_container,
	}
	_rebuild_active_obstacle_placements()
	queue_redraw()
	chunk_generated.emit(chunk_coordinate)


func remove_chunk(chunk_coordinate: Vector2i) -> void:
	if not _active_chunks.has(chunk_coordinate):
		return
	var record: Dictionary = _active_chunks[chunk_coordinate]
	var chunk_data: WorldChunkData = record["data"]
	_erase_chunk_tiles(chunk_data)
	var obstacle_container := record["obstacle_container"] as Node2D
	if is_instance_valid(obstacle_container):
		obstacle_container.free()
	_active_chunks.erase(chunk_coordinate)
	_rebuild_active_obstacle_placements()
	queue_redraw()
	chunk_removed.emit(chunk_coordinate)


func get_valid_spawn_position_around_player(
		player_position: Vector2,
		minimum_distance: float = 400.0,
		maximum_distance: float = 600.0
) -> Vector2:
	var effective_minimum := maxf(minimum_distance, minimum_offscreen_distance)
	var effective_maximum := maxf(maximum_distance, effective_minimum)
	for _attempt in range(spawn_position_attempts):
		var angle := _runtime_rng.randf_range(0.0, TAU)
		var radius := _runtime_rng.randf_range(effective_minimum, effective_maximum)
		var candidate := player_position + Vector2.from_angle(angle) * radius
		if is_position_navigable(candidate, spawn_clearance_radius):
			return candidate

	for step in range(64):
		var angle := TAU * step / 64.0
		var candidate := player_position + Vector2.from_angle(angle) * effective_maximum
		if is_position_navigable(candidate, spawn_clearance_radius):
			return candidate
	return player_position


func is_position_navigable(
		world_position: Vector2,
		clearance_radius: float = 0.0
) -> bool:
	var biome := get_biome_at(world_position)
	if biome == null or not biome.is_navigable:
		return false
	return obstacle_spawner.is_position_clear(
		world_position,
		clearance_radius,
		obstacle_placements
	)


func get_biome_at(world_position: Vector2) -> BiomeData:
	if world_position.distance_squared_to(initial_spawn_position) < safe_radius * safe_radius:
		return biome_generator.grassland_data
	return biome_generator.get_biome_at(world_position)


func get_movement_speed_multiplier_at(world_position: Vector2) -> float:
	var biome := get_biome_at(world_position)
	if biome == null:
		return 1.0
	return biome.movement_speed_multiplier


func get_chunk_coordinate(world_position: Vector2) -> Vector2i:
	return chunk_manager.get_chunk_coordinate(world_position)


func get_current_seed() -> int:
	return current_seed


func get_active_chunk_count() -> int:
	return _active_chunks.size()


func is_chunk_active(chunk_coordinate: Vector2i) -> bool:
	return _active_chunks.has(chunk_coordinate)


func get_cached_chunk_count() -> int:
	return _chunk_cache.size()


func get_cached_chunk_data(chunk_coordinate: Vector2i) -> WorldChunkData:
	return _chunk_cache.get(chunk_coordinate) as WorldChunkData


func _get_or_build_chunk_data(chunk_coordinate: Vector2i) -> WorldChunkData:
	if _chunk_cache.has(chunk_coordinate):
		_touch_cache_entry(chunk_coordinate)
		return _chunk_cache[chunk_coordinate] as WorldChunkData

	var chunk_data := _build_chunk_data(chunk_coordinate)
	_chunk_cache[chunk_coordinate] = chunk_data
	_touch_cache_entry(chunk_coordinate)
	_trim_cache()
	return chunk_data


func _build_chunk_data(chunk_coordinate: Vector2i) -> WorldChunkData:
	var result := WorldChunkData.new(chunk_coordinate)
	var tile_size := ground_layer.tile_set.tile_size
	var cells_per_axis := floori(chunk_manager.chunk_size / float(tile_size.x))
	var start_cell := _get_chunk_start_cell(chunk_coordinate, tile_size)

	for local_y in range(cells_per_axis):
		for local_x in range(cells_per_axis):
			var cell := start_cell + Vector2i(local_x, local_y)
			var world_position := ground_layer.to_global(ground_layer.map_to_local(cell))
			result.biome_types.append(_get_biome_type_for_tile(world_position, tile_size))

	var chunk_seed := chunk_manager.get_chunk_seed(current_seed, chunk_coordinate)
	var decoration_rng := RandomNumberGenerator.new()
	decoration_rng.seed = chunk_seed ^ 0x2C9277B5
	result.decoration_cells = decoration_spawner.generate_chunk_decorations(
		result.biome_types,
		cells_per_axis,
		biome_generator,
		decoration_rng
	)

	var obstacle_rng := RandomNumberGenerator.new()
	obstacle_rng.seed = chunk_seed ^ 0x68E31DA4
	result.obstacle_blueprints = obstacle_spawner.generate_chunk_blueprints(
		chunk_manager.get_chunk_bounds(chunk_coordinate),
		initial_spawn_position,
		safe_radius,
		biome_generator,
		obstacle_rng
	)
	return result


func _apply_chunk_tiles(chunk_data: WorldChunkData) -> void:
	var tile_size := ground_layer.tile_set.tile_size
	var cells_per_axis := floori(chunk_manager.chunk_size / float(tile_size.x))
	var start_cell := _get_chunk_start_cell(chunk_data.coordinate, tile_size)
	for cell_index in range(chunk_data.biome_types.size()):
		var local_cell := Vector2i(
			cell_index % cells_per_axis,
			floori(cell_index / float(cells_per_axis))
		)
		var biome := biome_generator.get_biome_by_type(chunk_data.biome_types[cell_index])
		ground_layer.set_cell(
			start_cell + local_cell,
			biome.ground_source_id,
			biome.ground_atlas_coordinates,
			biome.ground_alternative_tile
		)

	for data_index in range(0, chunk_data.decoration_cells.size(), 5):
		var local_cell := Vector2i(
			chunk_data.decoration_cells[data_index],
			chunk_data.decoration_cells[data_index + 1]
		)
		decorations_layer.set_cell(
			start_cell + local_cell,
			chunk_data.decoration_cells[data_index + 2],
			Vector2i(
				chunk_data.decoration_cells[data_index + 3],
				chunk_data.decoration_cells[data_index + 4]
			)
		)


func _erase_chunk_tiles(chunk_data: WorldChunkData) -> void:
	var tile_size := ground_layer.tile_set.tile_size
	var cells_per_axis := floori(chunk_manager.chunk_size / float(tile_size.x))
	var start_cell := _get_chunk_start_cell(chunk_data.coordinate, tile_size)
	for local_y in range(cells_per_axis):
		for local_x in range(cells_per_axis):
			ground_layer.erase_cell(start_cell + Vector2i(local_x, local_y))
	for data_index in range(0, chunk_data.decoration_cells.size(), 5):
		decorations_layer.erase_cell(
			start_cell + Vector2i(
				chunk_data.decoration_cells[data_index],
				chunk_data.decoration_cells[data_index + 1]
			)
		)


func _get_chunk_start_cell(chunk_coordinate: Vector2i, tile_size: Vector2i) -> Vector2i:
	var chunk_origin := chunk_manager.get_chunk_origin(chunk_coordinate)
	return Vector2i(
		floori(chunk_origin.x / tile_size.x),
		floori(chunk_origin.y / tile_size.y)
	)


func _get_biome_type_for_tile(world_position: Vector2, tile_size: Vector2i) -> int:
	var safe_tile_margin := Vector2(tile_size).length() * 0.5
	if world_position.distance_squared_to(initial_spawn_position) < pow(
			safe_radius + safe_tile_margin, 2.0
	):
		return BiomeGenerator.BiomeType.GRASSLAND
	return biome_generator.get_biome_type_at(world_position)


func _configure_water_tile() -> void:
	var water_data := biome_generator.water_data
	var tile_set := ground_layer.tile_set
	if water_data == null or tile_set == null:
		return
	var atlas_source := tile_set.get_source(water_data.ground_source_id) as TileSetAtlasSource
	if atlas_source == null:
		return
	var tile_data := atlas_source.get_tile_data(
		water_data.ground_atlas_coordinates,
		water_data.ground_alternative_tile
	)
	if tile_data == null:
		return
	tile_data.modulate = Color(0.3, 0.62, 0.9, 1.0)
	if tile_set.get_physics_layers_count() > 0:
		while tile_data.get_collision_polygons_count(0) > 0:
			tile_data.remove_collision_polygon(0, 0)


func _rebuild_active_obstacle_placements() -> void:
	obstacle_placements.clear()
	for record: Dictionary in _active_chunks.values():
		var chunk_data: WorldChunkData = record["data"]
		obstacle_placements.append_array(chunk_data.obstacle_blueprints)


func _clear_active_chunks() -> void:
	var coordinates: Array = _active_chunks.keys()
	for coordinate: Vector2i in coordinates:
		remove_chunk(coordinate)
	_active_chunks.clear()
	obstacle_placements.clear()


func _touch_cache_entry(chunk_coordinate: Vector2i) -> void:
	_cache_order.erase(chunk_coordinate)
	_cache_order.append(chunk_coordinate)


func _trim_cache() -> void:
	var attempts := _cache_order.size()
	while _chunk_cache.size() > chunk_manager.max_cached_chunks and attempts > 0:
		var oldest: Vector2i = _cache_order.pop_front()
		if _active_chunks.has(oldest):
			_cache_order.append(oldest)
			attempts -= 1
			continue
		_chunk_cache.erase(oldest)


func _resolve_seed() -> int:
	if world_seed != 0:
		return world_seed
	var random_seed_generator := RandomNumberGenerator.new()
	random_seed_generator.randomize()
	return random_seed_generator.randi_range(1, 2_147_483_647)


func _validate_configuration() -> bool:
	if ground_layer.tile_set == null:
		push_error("WorldGenerator: Ground requires a TileSet.")
		return false
	var tile_size := ground_layer.tile_set.tile_size
	if tile_size.x <= 0 or tile_size.x != tile_size.y:
		push_error("WorldGenerator: Phase 3 currently requires square ground tiles.")
		return false
	if chunk_manager.chunk_size % tile_size.x != 0:
		push_error("WorldGenerator: chunk_size must be divisible by the ground tile size.")
		return false
	if biome_generator.grassland_data == null \
			or biome_generator.forest_data == null \
			or biome_generator.water_data == null:
		push_error("WorldGenerator: grassland, forest and water BiomeData are required.")
		return false
	if biome_generator.water_threshold >= biome_generator.forest_threshold:
		push_error("WorldGenerator: water_threshold must be below forest_threshold.")
		return false
	return true


func _on_current_chunk_changed(chunk_coordinate: Vector2i) -> void:
	if debug_mode:
		print(
			"WorldGenerator — current chunk: %s | active: %d | cached: %d"
			% [chunk_coordinate, _active_chunks.size(), _chunk_cache.size()]
		)
	if is_instance_valid(_player):
		_update_player_biome(_player.global_position)
	queue_redraw()


func _update_player_biome(world_position: Vector2) -> void:
	var next_biome_type := biome_generator.get_biome_type_at(world_position)
	if world_position.distance_squared_to(initial_spawn_position) < safe_radius * safe_radius:
		next_biome_type = BiomeGenerator.BiomeType.GRASSLAND
	if next_biome_type == _current_biome_type:
		return
	_current_biome_type = next_biome_type
	if debug_mode:
		var biome := biome_generator.get_biome_by_type(next_biome_type)
		print("WorldGenerator — player biome: %s" % biome.display_name)
	biome_entered.emit(next_biome_type)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_biome_check_elapsed += delta
	if _biome_check_elapsed < 0.25:
		return
	_biome_check_elapsed = 0.0
	_update_player_biome(_player.global_position)


func _draw() -> void:
	if not debug_mode:
		return
	if draw_chunk_bounds:
		for chunk_coordinate: Vector2i in _active_chunks:
			draw_rect(
				chunk_manager.get_chunk_bounds(chunk_coordinate),
				Color(0.2, 0.8, 1.0, 0.45),
				false,
				2.0
			)
	if draw_safe_radius:
		draw_arc(
			initial_spawn_position,
			safe_radius,
			0.0,
			TAU,
			64,
			Color(0.2, 1.0, 0.4, 0.7),
			3.0
		)
	if draw_obstacle_positions:
		for placement: Dictionary in obstacle_placements:
			draw_circle(placement["position"], 5.0, Color(1.0, 0.35, 0.2, 0.8))
