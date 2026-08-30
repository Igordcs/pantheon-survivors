class_name BiomeGenerator
extends Node
## Selects continuous biome regions from world-space FastNoiseLite values.

enum BiomeType {
	GRASSLAND,
	FOREST,
	WATER,
	RUINS,
}

@export var grassland_data: BiomeData
@export var forest_data: BiomeData
@export var water_data: BiomeData

@export_category("Noise")
@export_range(0.0001, 0.02, 0.0001) var noise_frequency: float = 0.0001
@export_range(-1.0, 1.0, 0.01) var water_threshold: float = -0.45
@export_range(-1.0, 1.0, 0.01) var forest_threshold: float = 0.4
@export_range(1, 8, 1) var fractal_octaves: int = 3
@export_range(0.0, 1.0, 0.01) var fractal_gain: float = 0.5

var _noise := FastNoiseLite.new()


func configure(world_seed: int) -> void:
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = fractal_octaves
	_noise.fractal_gain = fractal_gain


func get_biome_at(world_position: Vector2) -> BiomeData:
	return get_biome_by_type(get_biome_type_at(world_position))


func get_biome_type_at(world_position: Vector2) -> BiomeType:
	var noise_value := get_noise_value(world_position)
	if noise_value < water_threshold:
		return BiomeType.WATER
	if noise_value > forest_threshold:
		return BiomeType.FOREST
	return BiomeType.GRASSLAND


func get_biome_by_type(biome_type: int) -> BiomeData:
	match biome_type:
		BiomeType.FOREST:
			return forest_data
		BiomeType.WATER:
			return water_data
		_:
			return grassland_data


func get_noise_value(world_position: Vector2) -> float:
	return _noise.get_noise_2d(world_position.x, world_position.y)


func get_max_obstacle_density() -> float:
	var result := 0.0
	for biome in [grassland_data, forest_data, water_data]:
		if biome != null:
			result = maxf(result, biome.obstacle_density)
	return result
