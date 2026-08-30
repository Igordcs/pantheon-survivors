class_name ObstacleSpawner
extends Node
## Generates deterministic obstacle blueprints independently for each chunk.

@export_category("Placement")
@export_range(32.0, 256.0, 1.0) var minimum_obstacle_distance: float = 96.0
@export_range(1, 100, 1) var max_placement_attempts: int = 20
@export_range(1, 256, 1) var maximum_obstacles_per_chunk: int = 48

@export_category("Navigability")
@export_range(128.0, 1024.0, 16.0) var density_region_size: float = 512.0
@export_range(1, 64, 1) var max_obstacles_per_region: int = 10
@export_range(0.0, 128.0, 1.0) var bounds_margin: float = 48.0


func generate_chunk_blueprints(
		bounds: Rect2,
		safe_center: Vector2,
		safe_radius: float,
		biome_generator: BiomeGenerator,
		rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	var spatial_cells: Dictionary = {}
	var density_counts: Dictionary = {}
	var maximum_density := biome_generator.get_max_obstacle_density()
	if maximum_density <= 0.0:
		return placements

	var placement_slot_area := minimum_obstacle_distance * minimum_obstacle_distance
	var estimated_slots := floori(bounds.get_area() / placement_slot_area)
	var target_count := mini(
		roundi(estimated_slots * maximum_density),
		maximum_obstacles_per_chunk
	)

	for _index in range(target_count):
		for _attempt in range(max_placement_attempts):
			var candidate := _random_position_in_bounds(bounds, rng)
			var biome := biome_generator.get_biome_at(candidate)
			if biome == null or not biome.is_navigable or biome.obstacle_entries.is_empty():
				continue
			if rng.randf() > biome.obstacle_density / maximum_density:
				continue

			var entry := _choose_entry(biome.obstacle_entries, rng)
			if entry == null or entry.scene == null:
				continue
			if not _can_place(
					candidate,
					entry.clearance_radius,
					safe_center,
					safe_radius,
					spatial_cells,
					density_counts
			):
				continue

			_register_placement(
				candidate,
				entry.clearance_radius,
				spatial_cells,
				density_counts
			)
			placements.append({
				"position": candidate,
				"clearance_radius": entry.clearance_radius,
				"entry": entry,
			})
			break
	return placements


func instantiate_obstacles(container: Node2D, blueprints: Array[Dictionary]) -> void:
	for blueprint: Dictionary in blueprints:
		var entry: WorldObjectData = blueprint["entry"]
		if entry == null or entry.scene == null:
			continue
		var obstacle := entry.scene.instantiate() as Node2D
		if obstacle == null:
			continue
		container.add_child(obstacle)
		obstacle.global_position = blueprint["position"]


func is_position_clear(
		world_position: Vector2,
		clearance_radius: float,
		active_placements: Array[Dictionary]
) -> bool:
	for placement: Dictionary in active_placements:
		var obstacle_position: Vector2 = placement["position"]
		var obstacle_radius: float = placement["clearance_radius"]
		if world_position.distance_squared_to(obstacle_position) < pow(
				clearance_radius + obstacle_radius, 2.0
		):
			return false
	return true


func _can_place(
		position: Vector2,
		clearance_radius: float,
		safe_center: Vector2,
		safe_radius: float,
		spatial_cells: Dictionary,
		density_counts: Dictionary
) -> bool:
	if position.distance_squared_to(safe_center) < pow(safe_radius + clearance_radius, 2.0):
		return false
	var density_cell := _get_density_cell(position)
	if int(density_counts.get(density_cell, 0)) >= max_obstacles_per_region:
		return false
	return _has_minimum_center_distance(position, spatial_cells)


func _register_placement(
		position: Vector2,
		clearance_radius: float,
		spatial_cells: Dictionary,
		density_counts: Dictionary
) -> void:
	var spatial_cell := _get_spatial_cell(position)
	if not spatial_cells.has(spatial_cell):
		spatial_cells[spatial_cell] = []
	var cell_entries: Array = spatial_cells[spatial_cell]
	cell_entries.append({
		"position": position,
		"clearance_radius": clearance_radius,
	})
	var density_cell := _get_density_cell(position)
	density_counts[density_cell] = int(density_counts.get(density_cell, 0)) + 1


func _has_minimum_center_distance(position: Vector2, spatial_cells: Dictionary) -> bool:
	var center_cell := _get_spatial_cell(position)
	for offset_x in range(-1, 2):
		for offset_y in range(-1, 2):
			var key := center_cell + Vector2i(offset_x, offset_y)
			var cell_entries: Array = spatial_cells.get(key, [])
			for placement: Dictionary in cell_entries:
				var obstacle_position: Vector2 = placement["position"]
				if position.distance_squared_to(obstacle_position) < pow(
						minimum_obstacle_distance, 2.0
				):
					return false
	return true


func _random_position_in_bounds(bounds: Rect2, rng: RandomNumberGenerator) -> Vector2:
	var effective_margin := maxf(bounds_margin, minimum_obstacle_distance * 0.5)
	var usable_bounds := bounds.grow(-effective_margin)
	return Vector2(
		rng.randf_range(usable_bounds.position.x, usable_bounds.end.x),
		rng.randf_range(usable_bounds.position.y, usable_bounds.end.y)
	)


func _choose_entry(
		entries: Array[WorldObjectData],
		rng: RandomNumberGenerator
) -> WorldObjectData:
	var total_weight := 0.0
	var last_valid_entry: WorldObjectData
	for entry in entries:
		if entry != null and entry.scene != null:
			total_weight += maxf(entry.weight, 0.0)
			last_valid_entry = entry
	if total_weight <= 0.0:
		return null

	var roll := rng.randf() * total_weight
	for entry in entries:
		if entry == null or entry.scene == null:
			continue
		roll -= maxf(entry.weight, 0.0)
		if roll <= 0.0:
			return entry
	return last_valid_entry


func _get_spatial_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / minimum_obstacle_distance),
		floori(position.y / minimum_obstacle_distance)
	)


func _get_density_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / density_region_size),
		floori(position.y / density_region_size)
	)
