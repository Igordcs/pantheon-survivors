extends SceneTree

const TEST_SEED := 246_813_579
const EPSILON := 0.01

var _failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var world_scene := load("res://scenes/world/world.tscn") as PackedScene
	var world := world_scene.instantiate() as WorldGenerator
	world.generate_on_ready = false
	world.world_seed = TEST_SEED
	world.debug_mode = false
	root.add_child(world)
	await process_frame

	world.generate_world()
	var expected_active_count := int(pow(world.chunk_manager.render_distance * 2 + 1, 2))
	if world.get_active_chunk_count() != expected_active_count:
		_fail("The initial streamed chunk grid has an unexpected size.")

	_validate_safe_area(world)
	_validate_minimum_distance(world)
	_validate_enemy_spawn_queries(world)
	_validate_biome_regions(world)
	_validate_water_slowdown(world)

	var origin_chunk := world.get_chunk_coordinate(Vector2.ZERO)
	var first_snapshot := _snapshot_chunk(world.get_cached_chunk_data(origin_chunk))
	var tracker := Node2D.new()
	root.add_child(tracker)
	world.setup(tracker)

	var distant_position := Vector2(20_000.0, -15_000.0)
	tracker.global_position = distant_position
	world.chunk_manager.refresh_around(distant_position)
	var distant_chunk := world.get_chunk_coordinate(distant_position)
	if not world.is_chunk_active(distant_chunk):
		_fail("The chunk around a distant player position was not generated.")
	var distant_cell := world.ground_layer.local_to_map(
		world.ground_layer.to_local(distant_position)
	)
	if world.ground_layer.get_cell_source_id(distant_cell) < 0:
		_fail("The streamed world has missing ground at a distant player position.")
	if world.get_active_chunk_count() != expected_active_count:
		_fail("Old chunks were not released after streaming to a distant area.")

	tracker.global_position = Vector2.ZERO
	world.chunk_manager.refresh_around(Vector2.ZERO)
	var cached_snapshot := _snapshot_chunk(world.get_cached_chunk_data(origin_chunk))
	if first_snapshot != cached_snapshot:
		_fail("Returning to a cached chunk changed its generated content.")

	world.chunk_manager.max_cached_chunks = 12
	for index in range(12):
		var travel_position := Vector2(index * world.chunk_manager.chunk_size * 2.0, 0.0)
		world.chunk_manager.refresh_around(travel_position)
	if world.get_cached_chunk_count() > world.chunk_manager.max_cached_chunks:
		_fail("The inactive chunk cache exceeded its configured limit.")

	world.generate_world()
	var regenerated_snapshot := _snapshot_chunk(world.get_cached_chunk_data(origin_chunk))
	if first_snapshot != regenerated_snapshot:
		_fail("The same world seed did not reproduce the same chunk.")

	if world.decorations_layer.get_used_cells().is_empty():
		_fail("Phase 2 decorations were not generated in the TileMapLayer.")

	tracker.free()
	world.free()
	if _failures == 0:
		print("WorldGenerator Phase 2-3 tests passed.")
	quit(_failures)


func _validate_safe_area(world: WorldGenerator) -> void:
	for placement: Dictionary in world.obstacle_placements:
		var position: Vector2 = placement["position"]
		var clearance: float = placement["clearance_radius"]
		if position.distance_to(world.initial_spawn_position) + EPSILON < world.safe_radius + clearance:
			_fail("An obstacle was placed inside the initial safe area.")
			return


func _validate_minimum_distance(world: WorldGenerator) -> void:
	var minimum_distance := world.obstacle_spawner.minimum_obstacle_distance
	for first_index in range(world.obstacle_placements.size()):
		var first_position: Vector2 = world.obstacle_placements[first_index]["position"]
		for second_index in range(first_index + 1, world.obstacle_placements.size()):
			var second_position: Vector2 = world.obstacle_placements[second_index]["position"]
			if first_position.distance_to(second_position) + EPSILON < minimum_distance:
				_fail("Two obstacles violate the configured minimum distance.")
				return


func _validate_enemy_spawn_queries(world: WorldGenerator) -> void:
	for _index in range(64):
		var position := world.get_valid_spawn_position_around_player(Vector2.ZERO, 400.0, 600.0)
		if not world.is_position_navigable(position, world.spawn_clearance_radius):
			_fail("Enemy spawn query returned a blocked or deep-water position.")
			return
		if position.length() + EPSILON < world.minimum_offscreen_distance:
			_fail("Enemy spawn query returned a position inside the immediate view radius.")
			return


func _validate_biome_regions(world: WorldGenerator) -> void:
	var found_types: Dictionary = {}
	for sample_x in range(-12_000, 12_001, 400):
		for sample_y in range(-12_000, 12_001, 400):
			found_types[world.biome_generator.get_biome_type_at(Vector2(sample_x, sample_y))] = true
	if not found_types.has(BiomeGenerator.BiomeType.GRASSLAND):
		_fail("FastNoiseLite did not produce grassland regions.")
	if not found_types.has(BiomeGenerator.BiomeType.FOREST):
		_fail("FastNoiseLite did not produce forest regions.")
	if not found_types.has(BiomeGenerator.BiomeType.WATER):
		_fail("FastNoiseLite did not produce water regions.")


func _validate_water_slowdown(world: WorldGenerator) -> void:
	var tile_set := world.ground_layer.tile_set
	var water := world.biome_generator.water_data
	if not water.is_navigable:
		_fail("Water should be navigable.")
	if water.movement_speed_multiplier >= 1.0:
		_fail("Water should reduce player movement speed.")
	var source := tile_set.get_source(water.ground_source_id) as TileSetAtlasSource
	var tile_data := source.get_tile_data(
		water.ground_atlas_coordinates,
		water.ground_alternative_tile
	)
	if tile_set.get_physics_layers_count() > 0 \
			and tile_data.get_collision_polygons_count(0) > 0:
		_fail("Water should not have a collision polygon.")

	var water_position := _find_biome_position(world, BiomeGenerator.BiomeType.WATER)
	if is_nan(water_position.x):
		_fail("No water sample was found for movement validation.")
		return
	if not is_equal_approx(
		world.get_movement_speed_multiplier_at(water_position),
		water.movement_speed_multiplier
	):
		_fail("The world movement modifier does not match the water biome data.")


func _find_biome_position(world: WorldGenerator, biome_type: int) -> Vector2:
	for sample_x in range(-12_000, 12_001, 200):
		for sample_y in range(-12_000, 12_001, 200):
			var position := Vector2(sample_x, sample_y)
			if world.biome_generator.get_biome_type_at(position) == biome_type:
				return position
	return Vector2(NAN, NAN)


func _snapshot_chunk(chunk_data: WorldChunkData) -> Dictionary:
	var positions: Array[Vector2] = []
	for blueprint: Dictionary in chunk_data.obstacle_blueprints:
		positions.append(blueprint["position"])
	return {
		"biome_types": chunk_data.biome_types.duplicate(),
		"decorations": chunk_data.decoration_cells.duplicate(),
		"obstacle_positions": positions,
	}


func _fail(message: String) -> void:
	_failures += 1
	push_error("WorldGenerator test: %s" % message)
