extends SceneTree
## Roda a bateria completa de geração em cada mapa do catálogo.

const TEST_SEED := 246_813_579
const EPSILON := 0.01

var _failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if MapCatalog.get_maps().size() < 2:
		_fail("The catalog should expose at least the field and the snow maps.")
	if MapCatalog.get_map(&"nao_existe").map_id != MapCatalog.DEFAULT_MAP_ID:
		_fail("An unknown map id should fall back to the default map.")

	for map_data in MapCatalog.get_maps():
		await _test_map(map_data)

	if _failures == 0:
		print("WorldGenerator Phase 2-3 tests passed.")
	quit(_failures)


func _test_map(map_data: MapData) -> void:
	var world_scene := load("res://scenes/world/world.tscn") as PackedScene
	var world := world_scene.instantiate() as WorldGenerator
	world.generate_on_ready = false
	world.map_data = map_data
	world.world_seed = TEST_SEED
	world.debug_mode = false
	root.add_child(world)
	await process_frame

	world.generate_world()
	if world.active_map != map_data:
		_fail("%s: the generator did not use the requested map." % map_data.map_id)
	if world.ground_layer.tile_set != map_data.tile_set:
		_fail("%s: the ground layer did not receive the map tileset." % map_data.map_id)

	var expected_active_count := int(pow(world.chunk_manager.render_distance * 2 + 1, 2))
	if world.get_active_chunk_count() != expected_active_count:
		_fail("%s: the initial streamed chunk grid has an unexpected size." % map_data.map_id)

	_validate_safe_area(world)
	_validate_minimum_distance(world)
	_validate_enemy_spawn_queries(world)
	_validate_biome_regions(world)
	_validate_ground_tiles(world)
	_validate_speed_biomes(world)

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
		_fail("%s: the chunk around a distant player position was not generated." % map_data.map_id)
	var distant_cell := world.ground_layer.local_to_map(
		world.ground_layer.to_local(distant_position)
	)
	if world.ground_layer.get_cell_source_id(distant_cell) < 0:
		_fail("%s: the streamed world has missing ground far from spawn." % map_data.map_id)
	if world.get_active_chunk_count() != expected_active_count:
		_fail("%s: old chunks were not released after streaming away." % map_data.map_id)

	tracker.global_position = Vector2.ZERO
	world.chunk_manager.refresh_around(Vector2.ZERO)
	var cached_snapshot := _snapshot_chunk(world.get_cached_chunk_data(origin_chunk))
	if first_snapshot != cached_snapshot:
		_fail("%s: returning to a cached chunk changed its content." % map_data.map_id)

	world.chunk_manager.max_cached_chunks = 12
	for index in range(12):
		var travel_position := Vector2(index * world.chunk_manager.chunk_size * 2.0, 0.0)
		world.chunk_manager.refresh_around(travel_position)
	if world.get_cached_chunk_count() > world.chunk_manager.max_cached_chunks:
		_fail("%s: the inactive chunk cache exceeded its limit." % map_data.map_id)

	world.generate_world()
	var regenerated_snapshot := _snapshot_chunk(world.get_cached_chunk_data(origin_chunk))
	if first_snapshot != regenerated_snapshot:
		_fail("%s: the same seed did not reproduce the same chunk." % map_data.map_id)

	if world.decorations_layer.get_used_cells().is_empty():
		_fail("%s: no decorations were generated in the TileMapLayer." % map_data.map_id)

	tracker.free()
	world.free()


func _validate_safe_area(world: WorldGenerator) -> void:
	for placement: Dictionary in world.obstacle_placements:
		var position: Vector2 = placement["position"]
		var clearance: float = placement["clearance_radius"]
		if position.distance_to(world.initial_spawn_position) + EPSILON < world.safe_radius + clearance:
			_fail("%s: an obstacle was placed inside the initial safe area." % world.active_map.map_id)
			return


func _validate_minimum_distance(world: WorldGenerator) -> void:
	var minimum_distance := world.obstacle_spawner.minimum_obstacle_distance
	for first_index in range(world.obstacle_placements.size()):
		var first_position: Vector2 = world.obstacle_placements[first_index]["position"]
		for second_index in range(first_index + 1, world.obstacle_placements.size()):
			var second_position: Vector2 = world.obstacle_placements[second_index]["position"]
			if first_position.distance_to(second_position) + EPSILON < minimum_distance:
				_fail("%s: two obstacles violate the minimum distance." % world.active_map.map_id)
				return


func _validate_enemy_spawn_queries(world: WorldGenerator) -> void:
	for _index in range(64):
		var position := world.get_valid_spawn_position_around_player(Vector2.ZERO, 400.0, 600.0)
		if not world.is_position_navigable(position, world.spawn_clearance_radius):
			_fail("%s: enemy spawn query returned a blocked position." % world.active_map.map_id)
			return
		if position.length() + EPSILON < world.minimum_offscreen_distance:
			_fail("%s: enemy spawn query returned a position inside the view." % world.active_map.map_id)
			return


## Cada bioma declarado pelo mapa precisa realmente aparecer no ruído.
func _validate_biome_regions(world: WorldGenerator) -> void:
	var found: Dictionary = {}
	for sample_x in range(-12_000, 12_001, 400):
		for sample_y in range(-12_000, 12_001, 400):
			found[world.biome_generator.get_biome_index_at(Vector2(sample_x, sample_y))] = true
	for index in range(world.biome_generator.get_biome_count()):
		if not found.has(index):
			_fail("%s: biome \"%s\" never appears in the world." % [
				world.active_map.map_id,
				world.biome_generator.get_biome_by_index(index).biome_id,
			])


## Todo bioma precisa apontar para um tile que exista no tileset do mapa.
func _validate_ground_tiles(world: WorldGenerator) -> void:
	var tile_set := world.ground_layer.tile_set
	for biome in world.biome_generator.biomes:
		var source := tile_set.get_source(biome.ground_source_id) as TileSetAtlasSource
		if source == null or not source.has_tile(biome.ground_atlas_coordinates):
			_fail("%s: biome \"%s\" points at a missing ground tile." % [
				world.active_map.map_id, biome.biome_id,
			])
			continue
		if not biome.is_navigable or tile_set.get_physics_layers_count() == 0:
			continue
		var tile_data := source.get_tile_data(
			biome.ground_atlas_coordinates, biome.ground_alternative_tile
		)
		if tile_data and tile_data.get_collision_polygons_count(0) > 0:
			_fail("%s: navigable biome \"%s\" still blocks movement." % [
				world.active_map.map_id, biome.biome_id,
			])


## O terreno que altera a velocidade precisa ser atravessável e reportar o multiplicador.
func _validate_speed_biomes(world: WorldGenerator) -> void:
	var checked := 0
	for index in range(world.biome_generator.get_biome_count()):
		var biome := world.biome_generator.get_biome_by_index(index)
		if is_equal_approx(biome.movement_speed_multiplier, 1.0):
			continue
		checked += 1
		if not biome.is_navigable:
			_fail("%s: biome \"%s\" changes speed but blocks movement." % [
				world.active_map.map_id, biome.biome_id,
			])
			continue
		var position := _find_biome_position(world, index)
		if is_nan(position.x):
			_fail("%s: no sample found for biome \"%s\"." % [
				world.active_map.map_id, biome.biome_id,
			])
			continue
		if not is_equal_approx(
			world.get_movement_speed_multiplier_at(position),
			biome.movement_speed_multiplier
		):
			_fail("%s: the world speed modifier does not match biome \"%s\"." % [
				world.active_map.map_id, biome.biome_id,
			])
	if checked == 0:
		_fail("%s: the map has no terrain that changes movement speed." % world.active_map.map_id)


func _find_biome_position(world: WorldGenerator, biome_index: int) -> Vector2:
	for sample_x in range(-12_000, 12_001, 200):
		for sample_y in range(-12_000, 12_001, 200):
			var position := Vector2(sample_x, sample_y)
			if world.biome_generator.get_biome_index_at(position) == biome_index:
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
