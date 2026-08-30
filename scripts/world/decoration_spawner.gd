class_name DecorationSpawner
extends Node
## Produces compact TileMap decoration data instead of one Node per object.


func generate_chunk_decorations(
		biome_types: PackedByteArray,
		cells_per_axis: int,
		biome_generator: BiomeGenerator,
		rng: RandomNumberGenerator
) -> PackedInt32Array:
	var result := PackedInt32Array()
	for cell_index in range(biome_types.size()):
		var biome_type: int = biome_types[cell_index]
		var biome := biome_generator.get_biome_by_type(biome_type)
		if biome == null or biome.decoration_atlas_coordinates.is_empty():
			continue
		if rng.randf() > biome.decoration_density:
			continue

		var atlas_coordinates: Vector2i
		var use_rare_decoration := (
			not biome.rare_decoration_atlas_coordinates.is_empty()
			and rng.randf() < biome.rare_decoration_chance
		)
		if use_rare_decoration:
			atlas_coordinates = biome.rare_decoration_atlas_coordinates[
				rng.randi_range(0, biome.rare_decoration_atlas_coordinates.size() - 1)
			]
		else:
			atlas_coordinates = biome.decoration_atlas_coordinates[
				rng.randi_range(0, biome.decoration_atlas_coordinates.size() - 1)
			]
		result.append(cell_index % cells_per_axis)
		result.append(floori(cell_index / float(cells_per_axis)))
		result.append(biome.decoration_source_id)
		result.append(atlas_coordinates.x)
		result.append(atlas_coordinates.y)
	return result
